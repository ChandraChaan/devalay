/// The user's data in and out of the phone, with no account and no server: a JSON backup of personal
/// events and settings, an .ics calendar file, "Add to calendar" for one day, and birthdays read from
/// the phone's contacts. The native side is PortabilityPlugin.kt (channel "devalay/portability").
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'calendar_reminders.dart';
import 'events.dart';
import 'i18n.dart';
import 'models.dart';
import 'notifications.dart';
import 'providers.dart';
import 'storage.dart';

class Portability {
  static const _ch = MethodChannel('devalay/portability');

  /// Lets the user pick where to save [text]; true when it was written, null when they cancelled.
  static Future<bool?> saveFile(String name, String text, {String mime = 'application/json'}) =>
      _ch.invokeMethod<bool>('saveFile', {'name': name, 'text': text, 'mime': mime});

  /// The text of a file the user picks, or null when they cancelled.
  static Future<String?> openFile() => _ch.invokeMethod<String>('openFile');

  /// Opens the phone's calendar app on a new all-day event; false when there is no calendar app.
  static Future<bool> addToCalendar({
    required String title,
    required DateTime day,
    String description = '',
    bool yearly = false,
  }) async =>
      await _ch.invokeMethod<bool>('addToCalendar', {
        'title': title,
        'description': description,
        // All-day events are given as UTC midnight.
        'begin': DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch,
        'rrule': yearly ? 'FREQ=YEARLY' : null,
      }) ??
      false;

  static Future<bool> hasContactsPermission() async => await _ch.invokeMethod<bool>('contactsPermission') ?? false;

  static Future<bool> requestContactsPermission() async => await _ch.invokeMethod<bool>('requestContacts') ?? false;

  /// Birthday and anniversary rows from the phone's contacts: {key, name, date, kind}.
  static Future<List<Map>> contactEvents() async => (await _ch.invokeListMethod<Map>('contactEvents')) ?? const <Map>[];
}

/// Shares [text] as a file through the system share sheet (Drive, Gmail, Files, a calendar app...).
Future<void> shareTextFile(String name, String text, String mime, {String? subject}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsString(text);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mime)],
      subject: subject,
    ),
  );
}

// ---------------------------------------------------------------------------
// Backup and restore
// ---------------------------------------------------------------------------

/// The settings a backup carries: language, birth star, rashi, city and reminders.
const backupPrefKeys = [
  'language',
  'birth_star',
  'rashi',
  'ishta',
  'city',
  'daily_reminder',
  'reminder_hour',
  'reminder_minute',
  'festival_reminders',
  'panchang_daily',
  'panchang_hour',
  'panchang_minute',
];

const backupVersion = 1;

/// The backup file's content.
Map<String, Object?> buildBackup(Box prefs, List<UserEvent> events, DateTime now) => {
  'app': 'devalay',
  'kind': 'backup',
  'version': backupVersion,
  'created': now.toUtc().toIso8601String(),
  'prefs': {
    for (final k in backupPrefKeys)
      if (prefs.get(k) != null) k: prefs.get(k),
  },
  'events': [for (final e in events) e.toJson()],
};

String backupFileName(DateTime now) => 'devalay-backup-${DateFormat('yyyy-MM-dd').format(now)}.json';

/// A backup read from a file.
class Backup {
  const Backup({required this.prefs, required this.events, this.created});
  final Map<String, Object> prefs;
  final List<UserEvent> events;
  final DateTime? created;
}

/// Reads a backup file. Throws [FormatException] when it is not a Devalay backup.
Backup parseBackup(String text) {
  final Object? j;
  try {
    j = jsonDecode(text);
  } on FormatException {
    throw const FormatException('Not a Devalay backup');
  }
  if (j is! Map || j['app'] != 'devalay' || j['kind'] != 'backup') {
    throw const FormatException('Not a Devalay backup');
  }
  if ((j['version'] as num? ?? 0) > backupVersion) throw const FormatException('Backup from a newer Devalay');
  final raw = j['prefs'] is Map ? j['prefs'] as Map : const {};
  final prefs = <String, Object>{};
  for (final k in backupPrefKeys) {
    final v = raw[k];
    final ok = switch (k) {
      'language' || 'rashi' || 'ishta' || 'city' => v is String,
      'daily_reminder' || 'festival_reminders' || 'panchang_daily' => v is bool,
      _ => v is int,
    };
    if (ok) prefs[k] = v as Object;
  }
  final events = [
    for (final e in (j['events'] is List ? j['events'] as List : const []))
      if (e is Map && e['id'] != null && '${e['title'] ?? ''}'.isNotEmpty) ?UserEvent.fromJson(e),
  ];
  return Backup(prefs: prefs, events: events, created: DateTime.tryParse('${j['created']}'));
}

/// How a restore changes the user's events: new ids are added, ids already on the phone are updated.
({int added, int updated}) mergeCount(Iterable<UserEvent> existing, Iterable<UserEvent> incoming) {
  final ids = {for (final e in existing) e.id};
  final seen = <String>{};
  var added = 0, updated = 0;
  for (final e in incoming) {
    if (!seen.add(e.id)) continue;
    ids.contains(e.id) ? updated++ : added++;
  }
  return (added: added, updated: updated);
}

/// Restores [backup]: events merged by id (the backup's copy wins), settings replaced, and
/// reminders and widgets laid out again.
Future<void> applyBackup(WidgetRef ref, Backup backup) async {
  for (final e in backup.events) {
    await Boxes.events.put(e.id, e.toJson());
  }
  ref.invalidate(eventsProvider);
  final notifier = ref.read(prefsProvider.notifier);
  for (final MapEntry(:key, :value) in backup.prefs.entries) {
    key == 'language' ? await notifier.setLanguage(value as String) : await notifier.set(key, value);
  }
  final prefs = ref.read(prefsProvider);
  if (prefs.dailyReminder || prefs.festivalReminders || prefs.panchangDaily || backup.events.any((e) => e.remind)) {
    await Notifications.requestPermission();
  }
  if (prefs.dailyReminder) {
    await Notifications.scheduleDaily(prefs.reminderHour, prefs.reminderMinute, lang: prefs.language);
  } else {
    await Notifications.cancelDaily();
  }
  if (prefs.festivalReminders) {
    final now = DateTime.now();
    final all = <Festival>[
      for (final y in [now.year, if (now.month == 12) now.year + 1])
        ...await ref.read(festivalsProvider(y).future).catchError((Object _) => <Festival>[]),
    ];
    await Notifications.scheduleFestivals(all, lang: prefs.language);
  }
  await refreshCalendarReminders(ref);
  await markBackedUp();
}

// ---------------------------------------------------------------------------
// Backup reminder
// ---------------------------------------------------------------------------

/// Events added, edited or removed since the last backup.
int get unsavedEventChanges => Boxes.prefs.get('backup_changes', defaultValue: 0) as int;

DateTime? get lastBackupAt => DateTime.tryParse('${Boxes.prefs.get('backup_at')}');

Future<void> noteEventChange([int n = 1]) => Boxes.prefs.put('backup_changes', unsavedEventChanges + n);

Future<void> markBackedUp() async {
  await Boxes.prefs.put('backup_changes', 0);
  await Boxes.prefs.put('backup_at', DateTime.now().toIso8601String());
}

/// After three or more unsaved changes, suggest a backup, at most once a fortnight.
bool shouldSuggestBackup(DateTime now, {required int changes, DateTime? lastSuggested}) =>
    changes >= 3 && (lastSuggested == null || now.difference(lastSuggested).inDays >= 14);

/// True (and remembered) when it is time to suggest a backup after an event change.
bool takeBackupSuggestion() {
  final now = DateTime.now();
  final last = DateTime.tryParse('${Boxes.prefs.get('backup_suggested_at')}');
  if (!shouldSuggestBackup(now, changes: unsavedEventChanges, lastSuggested: last)) return false;
  Boxes.prefs.put('backup_suggested_at', now.toIso8601String());
  return true;
}

// ---------------------------------------------------------------------------
// Calendar file (.ics)
// ---------------------------------------------------------------------------

String _icsDate(DateTime d) => DateFormat('yyyyMMdd').format(d);

/// RFC 5545 TEXT: backslash, semicolon, comma and newlines escaped.
String icsEscape(String s) => s
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n');

/// Folds a content line at 75 octets without splitting a character (RFC 5545 §3.1).
String icsFold(String line) {
  final out = StringBuffer();
  var size = 0;
  for (final rune in line.runes) {
    final ch = String.fromCharCode(rune);
    final bytes = utf8.encode(ch).length;
    if (size + bytes > 75) {
      out.write('\r\n ');
      size = 1;
    }
    out.write(ch);
    size += bytes;
  }
  return out.toString();
}

/// An .ics calendar of [festivals] and the user's [events]. Date-based events repeat yearly through
/// an RRULE; tithi events move every year, so they are listed for each date in [tithiDays] (each
/// year's day summaries, typically this year and next).
String buildIcs({
  required String lang,
  required Iterable<Festival> festivals,
  required Iterable<UserEvent> events,
  required Map<int, List<Map>> tithiDays,
  required DateTime now,
}) {
  final stamp = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(now.toUtc());
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Devalay//Panchang//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:Devalay',
  ];
  void event(String uid, DateTime day, String summary, {String? description, String? rrule, String? category}) {
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:$uid@devalay.app',
      'DTSTAMP:$stamp',
      'DTSTART;VALUE=DATE:${_icsDate(day)}',
      'DTEND;VALUE=DATE:${_icsDate(DateTime(day.year, day.month, day.day + 1))}',
      if (rrule != null) 'RRULE:$rrule',
      'SUMMARY:${icsEscape(summary)}',
      if (description != null && description.isNotEmpty) 'DESCRIPTION:${icsEscape(description)}',
      if (category != null) 'CATEGORIES:${icsEscape(category)}',
      'TRANSP:TRANSPARENT',
      'END:VEVENT',
    ]);
  }

  final seen = <String>{};
  for (final f in festivals) {
    final uid = 'festival-${f.slug.isEmpty ? f.kind : f.slug}-${_icsDate(f.date)}';
    if (!seen.add(uid)) continue;
    event(
      uid,
      f.date,
      '${f.major ? '🪔' : '🙏'} ${f.label(lang)}',
      description: [if (f.deity.isNotEmpty) f.deityLabel(lang), f.describe(lang)].where((s) => s.isNotEmpty).join('\n'),
      category: t3(lang, 'Festival', 'त्योहार', 'పండుగ'),
    );
  }
  for (final e in events) {
    final kind = UserEvent.kindLabel(lang, e.kind);
    switch (e.repeat) {
      case EventRepeat.once:
        event(e.id, e.date, '${e.emoji} ${e.title}', description: kind, category: kind);
      case EventRepeat.yearly:
        event(e.id, e.date, '${e.emoji} ${e.title}', description: kind, rrule: 'FREQ=YEARLY', category: kind);
      case EventRepeat.tithi:
        for (final MapEntry(key: year, value: days) in tithiDays.entries) {
          for (final d in e.occurrencesIn(year, days)) {
            event(
              '${e.id}-${_icsDate(d)}',
              d,
              '${e.emoji} ${e.title}',
              description: '$kind · ${e.tithiLabel(lang)}',
              category: kind,
            );
          }
        }
    }
  }
  lines.add('END:VCALENDAR');
  return '${lines.map(icsFold).join('\r\n')}\r\n';
}

// ---------------------------------------------------------------------------
// Birthdays from contacts
// ---------------------------------------------------------------------------

/// A contact's birthday or anniversary as stored by the phone: "1990-05-12", "--05-12" (no year),
/// "19900512", "12.05.1990" or a full timestamp. Years before 1800 mean "no year" (some apps store 1604).
({int? year, int month, int day})? parseContactDate(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  RegExpMatch? m;
  int? y;
  int mo, d;
  if ((m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s)) != null ||
      (m = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(s)) != null) {
    y = int.parse(m![1]!);
    mo = int.parse(m[2]!);
    d = int.parse(m[3]!);
  } else if ((m = RegExp(r'^--(\d{1,2})-?(\d{1,2})$').firstMatch(s)) != null) {
    mo = int.parse(m![1]!);
    d = int.parse(m[2]!);
  } else if ((m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(s)) != null) {
    d = int.parse(m![1]!);
    mo = int.parse(m[2]!);
    y = int.parse(m[3]!);
  } else {
    return null;
  }
  if (mo < 1 || mo > 12 || d < 1 || d > DateUtils.getDaysInMonth(y ?? 2024, mo)) return null;
  if (y != null && y < 1800) y = null;
  return (year: y, month: mo, day: d);
}

/// A stable event id for a contact's birthday or anniversary, so importing again updates it.
String contactEventId(String key, String kind) {
  // FNV-1a, 32-bit twice: contact lookup keys can be long, Hive keys cannot.
  var a = 0x811c9dc5, b = 0x01000193 ^ 0x5bd1e995;
  for (final c in utf8.encode('$kind:$key')) {
    a = ((a ^ c) * 0x01000193) & 0xffffffff;
    b = ((b ^ c) * 0x01000193 + 7) & 0xffffffff;
  }
  return 'contact-$kind-${a.toRadixString(16)}${b.toRadixString(16)}';
}

/// One importable contact day.
class ContactDay {
  const ContactDay({required this.id, required this.name, required this.kind, required this.date, this.hasYear = true});
  final String id, name, kind;
  final DateTime date;
  final bool hasYear;

  UserEvent toEvent({required bool remind}) =>
      UserEvent(id: id, title: name, kind: kind, date: date, repeat: EventRepeat.yearly, remind: remind);
}

/// Turns the native rows into importable days, sorted by name, one per contact and kind.
List<ContactDay> contactDays(List<Map> rows, DateTime now) {
  final out = <String, ContactDay>{};
  for (final r in rows) {
    final name = '${r['name'] ?? ''}'.trim();
    final kind = r['kind'] == 'anniversary' ? 'anniversary' : 'birthday';
    final date = parseContactDate(r['date'] as String?);
    if (name.isEmpty || date == null) continue;
    final id = contactEventId('${r['key'] ?? name}', kind);
    out.putIfAbsent(
      id,
      () => ContactDay(
        id: id,
        name: name,
        kind: kind,
        // Without a year the day starts from this year; it repeats yearly either way.
        date: DateTime(date.year ?? now.year, date.month, date.day),
        hasYear: date.year != null,
      ),
    );
  }
  return out.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Saves the chosen contact days as personal events and lays out their reminders.
Future<void> importContactDays(WidgetRef ref, List<ContactDay> days, {required bool remind}) async {
  if (remind) await Notifications.requestPermission();
  for (final d in days) {
    await Boxes.events.put(d.id, d.toEvent(remind: remind).toJson());
  }
  ref.invalidate(eventsProvider);
  await noteEventChange(days.length);
  await refreshCalendarReminders(ref);
}
