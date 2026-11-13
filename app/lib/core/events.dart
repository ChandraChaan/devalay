import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'i18n.dart';
import 'muhurta.dart';
import 'names.dart';
import 'providers.dart';
import 'regional.dart';
import 'storage.dart';
import 'telugu.dart';

/// How a personal event comes back.
enum EventRepeat {
  /// Only on the date given.
  once,

  /// Every year on the same English date.
  yearly,

  /// Every year on the same tithi of the same lunar month, the way families keep
  /// birthdays, weddings and remembrance days (taddinam / shraddha).
  tithi,
}

/// A personal day the user keeps in their calendar. Stored on the phone only.
@immutable
class UserEvent {
  const UserEvent({
    required this.id,
    required this.title,
    required this.kind,
    required this.date,
    required this.repeat,
    this.tithi,
    this.lunarMonth,
    this.remind = true,
  });

  final String id;
  final String title;

  /// birthday | anniversary | remembrance | puja | other
  final String kind;

  /// The date it was first added for (for [EventRepeat.tithi], the day the tithi was read from).
  final DateTime date;
  final EventRepeat repeat;

  /// 1–30 (Shukla Pratipada .. Amavasya) and 0–11 (Chaitra .. Phalguna) for [EventRepeat.tithi].
  final int? tithi;
  final int? lunarMonth;
  final bool remind;

  static const kinds = ['birthday', 'anniversary', 'remembrance', 'puja', 'other'];

  String get emoji => emojiFor(kind);

  static String emojiFor(String kind) => switch (kind) {
    'birthday' => '🎂',
    'anniversary' => '💐',
    'remembrance' => '🕯️',
    'puja' => '🛕',
    _ => '🔔',
  };

  static String kindLabel(String lang, String kind) => switch (kind) {
    'birthday' => t3(lang, 'Birthday', 'जन्मदिन', 'పుట్టినరోజు'),
    'anniversary' => t3(lang, 'Anniversary', 'सालगिरह', 'వివాహ వార్షికోత్సవం'),
    'remembrance' => t3(lang, 'Remembrance (Shraddha)', 'श्राद्ध / पुण्यतिथि', 'తద్దినం / ఆబ్దికం'),
    'puja' => t3(lang, 'Puja / Vratam', 'पूजा / व्रत', 'పూజ / వ్రతం'),
    _ => t3(lang, 'Other', 'अन्य', 'ఇతర'),
  };

  /// "Kartika Shukla Panchami" for a tithi event.
  String tithiLabel(String lang) {
    if (tithi == null || lunarMonth == null) return '';
    // Stored the Amanta way; a Purnimanta reader sees a Krishna-paksha day under the next month's name.
    final shown = shownMonth(monthSystemFor(lang), lunarMonth!, krishna: tithi! > 15);
    return '${lunarMonthLabel(lang, shown.index)} ${tithiName(lang, tithi!)}';
  }

  UserEvent copyWith({
    String? title,
    String? kind,
    DateTime? date,
    EventRepeat? repeat,
    int? tithi,
    int? lunarMonth,
    bool? remind,
  }) => UserEvent(
    id: id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    date: date ?? this.date,
    repeat: repeat ?? this.repeat,
    tithi: tithi ?? this.tithi,
    lunarMonth: lunarMonth ?? this.lunarMonth,
    remind: remind ?? this.remind,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'kind': kind,
    'date': '${date.year}-${date.month}-${date.day}',
    'repeat': repeat.name,
    'tithi': tithi,
    'lunar_month': lunarMonth,
    'remind': remind,
  };

  static UserEvent? fromJson(Map j) {
    try {
      final parts = '${j['date']}'.split('-').map(int.parse).toList();
      return UserEvent(
        id: '${j['id']}',
        title: '${j['title']}',
        kind: '${j['kind'] ?? 'other'}',
        date: DateTime(parts[0], parts[1], parts[2]),
        repeat: EventRepeat.values.firstWhere((r) => r.name == j['repeat'], orElse: () => EventRepeat.once),
        tithi: j['tithi'] as int?,
        lunarMonth: j['lunar_month'] as int?,
        remind: j['remind'] != false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Dates this event falls on in [year]. Tithi events need that year's day summaries
  /// ([days], each with tithi_index, lunar_month and adhika) and are skipped without them.
  List<DateTime> occurrencesIn(int year, List<Map> days) {
    switch (repeat) {
      case EventRepeat.once:
        return date.year == year ? [date] : const [];
      case EventRepeat.yearly:
        if (year < date.year) return const [];
        final last = DateUtils.getDaysInMonth(year, date.month);
        return [DateTime(year, date.month, date.day > last ? last : date.day)];
      case EventRepeat.tithi:
        if (tithi == null || lunarMonth == null || year < date.year) return const [];
        return tithiDays(days, lunarMonth!, tithi!).where((d) => d.year == year).toList();
    }
  }
}

/// "Shukla Panchami" / "Krishna Amavasya" for tithi 1–30.
String tithiName(String lang, int tithi) {
  const names = [
    'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami', 'Shashthi', 'Saptami', 'Ashtami', //
    'Navami', 'Dashami', 'Ekadashi', 'Dwadashi', 'Trayodashi', 'Chaturdashi',
  ];
  final shukla = tithi <= 15;
  final name = tithi == 15 ? 'Purnima' : (tithi == 30 ? 'Amavasya' : names[(tithi - 1) % 15]);
  final paksha = shukla ? 'Shukla' : 'Krishna';
  if (lang == 'te') return '${teluguPaksha[paksha] ?? paksha} ${teluguTithi[name] ?? name}';
  if (lang == 'hi') {
    const hi = [
      'प्रतिपदा', 'द्वितीया', 'तृतीया', 'चतुर्थी', 'पंचमी', 'षष्ठी', 'सप्तमी', 'अष्टमी', //
      'नवमी', 'दशमी', 'एकादशी', 'द्वादशी', 'त्रयोदशी', 'चतुर्दशी',
    ];
    final n = tithi == 15 ? 'पूर्णिमा' : (tithi == 30 ? 'अमावस्या' : hi[(tithi - 1) % 15]);
    return '${shukla ? 'शुक्ल' : 'कृष्ण'} $n';
  }
  if (lang == 'en') return '$paksha $name';
  return '${pakshaIn(lang, paksha)} ${tithiIn(lang, name)}';
}

/// Days on which [tithi] of nija [lunarMonth] is observed, by the sunrise rule: the first
/// sunrise it prevails at, or, when it begins and ends between two sunrises (kshaya), the day
/// it falls in. Mirrors festivals._match_days on the server.
List<DateTime> tithiDays(List<Map> days, int lunarMonth, int tithi) {
  final out = <DateTime>[];
  var prevHit = false;
  for (var i = 0; i < days.length; i++) {
    final d = days[i];
    final t = d['tithi_index'] as int?;
    final m = d['lunar_month'] as int?;
    final adhika = d['adhika'] == true;
    final hit = t == tithi && m == lunarMonth && !adhika;
    if (hit && !prevHit) out.add(_date(d));
    prevHit = hit;
    if (!hit && i + 1 < days.length && t == (tithi + 28) % 30 + 1) {
      final n = days[i + 1];
      final nextOk = n['tithi_index'] == tithi % 30 + 1;
      final monthOk = (m == lunarMonth && !adhika) || (n['lunar_month'] == lunarMonth && n['adhika'] != true);
      if (nextOk && monthOk) out.add(_date(d));
    }
  }
  return out;
}

DateTime _date(Map d) => DateTime.parse('${d['date']}');

class EventsNotifier extends Notifier<List<UserEvent>> {
  @override
  List<UserEvent> build() => [
    for (final v in Boxes.events.values)
      if (v is Map) ?UserEvent.fromJson(v),
  ]..sort((a, b) => a.title.compareTo(b.title));

  Future<UserEvent> save(UserEvent e) async {
    await Boxes.events.put(e.id, e.toJson());
    ref.invalidateSelf();
    return e;
  }

  Future<void> remove(String id) async {
    await Boxes.events.delete(id);
    ref.invalidateSelf();
  }

  static String newId() => const Uuid().v4();
}

final eventsProvider = NotifierProvider<EventsNotifier, List<UserEvent>>(EventsNotifier.new);

/// Every day summary of a year (12 month files), in date order. Months that fail to load are
/// left out, so callers get what is available offline.
final yearDaysProvider = FutureProvider.family<List<Map>, int>((ref, year) async {
  final months = await Future.wait([
    for (var m = 1; m <= 12; m++)
      ref.watch(monthProvider((year: year, month: m)).future).then<List<Map>?>((v) => v, onError: (_) => null),
  ]);
  return [for (final m in months) ...?m];
});

/// Personal events by day for a year.
final eventsByDayProvider = Provider.family<Map<DateTime, List<UserEvent>>, int>((ref, year) {
  final events = ref.watch(eventsProvider);
  final needsTithi = events.any((e) => e.repeat == EventRepeat.tithi);
  final days = needsTithi ? (ref.watch(yearDaysProvider(year)).value ?? const <Map>[]) : const <Map>[];
  final out = <DateTime, List<UserEvent>>{};
  for (final e in events) {
    for (final d in e.occurrencesIn(year, days)) {
      out.putIfAbsent(DateUtils.dateOnly(d), () => []).add(e);
    }
  }
  return out;
});

/// The next date (today or later) an event falls on, within this year and next.
DateTime? nextOccurrence(UserEvent e, DateTime today, List<Map> thisYear, List<Map> nextYear) {
  final t = DateUtils.dateOnly(today);
  for (final (year, days) in [(t.year, thisYear), (t.year + 1, nextYear)]) {
    for (final d in e.occurrencesIn(year, days)) {
      if (!d.isBefore(t)) return d;
    }
  }
  return null;
}
