import 'dart:convert';

import 'package:devalay/core/events.dart';
import 'package:devalay/core/home_widget_sync.dart';
import 'package:devalay/core/models.dart';
import 'package:devalay/core/portability.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/features/shell.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Festival _festival(String slug, String date, {bool major = true, String name = 'Diwali'}) =>
    Festival({'slug': slug, 'kind': slug, 'name': name, 'name_hi': '', 'date': date, 'major': major});

void main() {
  setUpAll(initTestStorage);

  final birthday = UserEvent(
    id: 'b1',
    title: 'Amma',
    kind: 'birthday',
    date: DateTime(1960, 5, 12),
    repeat: EventRepeat.yearly,
  );
  final shraddha = UserEvent(
    id: 't1',
    title: 'Tatayya, Shraddha',
    kind: 'remembrance',
    date: DateTime(2020, 9, 1),
    repeat: EventRepeat.tithi,
    tithi: 20,
    lunarMonth: 5,
  );

  group('backup', () {
    test('round-trips events and only the backed-up settings', () async {
      await Boxes.prefs.putAll({'language': 'kn', 'birth_star': 7, 'city': 'mysuru', 'device_id': 'secret'});
      final text = jsonEncode(buildBackup(Boxes.prefs, [birthday, shraddha], DateTime.utc(2026, 11, 13)));
      final backup = parseBackup(text);
      expect(backup.prefs, {'language': 'kn', 'birth_star': 7, 'city': 'mysuru'});
      expect(backup.events.map((e) => e.id), ['b1', 't1']);
      expect(backup.events.last.tithi, 20);
      expect(backup.created, DateTime.utc(2026, 11, 13));
      expect(text, isNot(contains('secret')));
    });

    test('rejects other files and drops settings of the wrong type', () {
      expect(() => parseBackup('not json'), throwsFormatException);
      expect(() => parseBackup('{"app":"other"}'), throwsFormatException);
      expect(() => parseBackup('{"app":"devalay","kind":"backup","version":99}'), throwsFormatException);
      final b = parseBackup(
        '{"app":"devalay","kind":"backup","version":1,"prefs":{"language":3,"daily_reminder":true,"evil":1},'
        '"events":[{"id":"x","title":""},{"id":"y","title":"Ok","date":"2020-1-2"}]}',
      );
      expect(b.prefs, {'daily_reminder': true});
      expect(b.events.map((e) => e.id), ['y']);
    });

    test('merges by id', () {
      final c = mergeCount([birthday], [birthday.copyWith(title: 'Amma garu'), shraddha, shraddha]);
      expect(c.added, 1);
      expect(c.updated, 1);
    });

    test('suggests a backup after three changes, once a fortnight', () {
      final now = DateTime(2026, 11, 13);
      expect(shouldSuggestBackup(now, changes: 2), isFalse);
      expect(shouldSuggestBackup(now, changes: 3), isTrue);
      expect(shouldSuggestBackup(now, changes: 5, lastSuggested: DateTime(2026, 11, 5)), isFalse);
      expect(shouldSuggestBackup(now, changes: 5, lastSuggested: DateTime(2026, 10, 1)), isTrue);
    });
  });

  group('ics', () {
    test('escapes text and folds long lines on character boundaries', () {
      expect(icsEscape('a,b;c\\d\ne'), r'a\,b\;c\\d\ne');
      final folded = icsFold('SUMMARY:${'దీపావళి' * 10}');
      for (final line in folded.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      expect(folded.replaceAll('\r\n ', ''), 'SUMMARY:${'దీపావళి' * 10}');
    });

    test('lists festivals, yearly days with an RRULE and tithi days by date', () {
      final days = [
        {'date': '2026-09-29', 'tithi_index': 19, 'lunar_month': 5},
        {'date': '2026-09-30', 'tithi_index': 20, 'lunar_month': 5},
        {'date': '2026-10-01', 'tithi_index': 21, 'lunar_month': 5},
      ];
      final ics = buildIcs(
        lang: 'en',
        festivals: [_festival('diwali', '2026-11-08'), _festival('diwali', '2026-11-08')],
        events: [birthday, shraddha],
        tithiDays: {2026: days},
        now: DateTime.utc(2026, 11, 13, 10),
      );
      expect(ics, startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
      expect('BEGIN:VEVENT'.allMatches(ics).length, 3);
      expect(ics, contains('UID:festival-diwali-20261108@devalay.app'));
      expect(ics, contains('DTSTART;VALUE=DATE:20261108\r\nDTEND;VALUE=DATE:20261109'));
      expect(ics, contains('DTSTART;VALUE=DATE:19600512\r\nDTEND;VALUE=DATE:19600513\r\nRRULE:FREQ=YEARLY'));
      expect(ics, contains('UID:t1-20260930@devalay.app'));
      expect(ics, contains(r'SUMMARY:🕯️ Tatayya\, Shraddha'));
      expect(ics, contains('DTSTAMP:20261113T100000Z'));
    });
  });

  group('contacts', () {
    test('reads the date formats phones store', () {
      expect(parseContactDate('1990-05-12'), (year: 1990, month: 5, day: 12));
      expect(parseContactDate('--05-12'), (year: null, month: 5, day: 12));
      expect(parseContactDate('19900512'), (year: 1990, month: 5, day: 12));
      expect(parseContactDate('12.05.1990'), (year: 1990, month: 5, day: 12));
      expect(parseContactDate('1604-05-12'), (year: null, month: 5, day: 12));
      expect(parseContactDate('1990-05-12T00:00:00.000Z'), (year: 1990, month: 5, day: 12));
      expect(parseContactDate('--02-29'), (year: null, month: 2, day: 29));
      expect(parseContactDate('2021-02-29'), isNull);
      expect(parseContactDate('May 12'), isNull);
      expect(parseContactDate(null), isNull);
    });

    test('one yearly day per contact and kind, with stable ids', () {
      final rows = [
        {'key': 'k1', 'name': 'Ravi', 'date': '1990-05-12', 'kind': 'birthday'},
        {'key': 'k1', 'name': 'Ravi', 'date': '1990-05-12', 'kind': 'birthday'},
        {'key': 'k1', 'name': 'Ravi', 'date': '--11-20', 'kind': 'anniversary'},
        {'key': 'k2', 'name': 'anu', 'date': 'garbage', 'kind': 'birthday'},
        {'key': 'k3', 'name': 'anu', 'date': '--01-02', 'kind': 'birthday'},
      ];
      final days = contactDays(rows, DateTime(2026, 11, 13));
      expect(days.map((d) => (d.name, d.kind)), [('anu', 'birthday'), ('Ravi', 'birthday'), ('Ravi', 'anniversary')]);
      expect(days.first.date, DateTime(2026, 1, 2));
      expect(days.first.hasYear, isFalse);
      expect(days[1].id, contactEventId('k1', 'birthday'));
      expect(days[1].id, isNot(days[2].id));
      expect(days[1].id.length, lessThan(40));
      final e = days[1].toEvent(remind: false);
      expect((e.repeat, e.date, e.remind), (EventRepeat.yearly, DateTime(1990, 5, 12), false));
    });
  });

  group('home-screen widgets', () {
    test('countdown lists major festivals from today, one per day', () {
      final list = countdownEntries('en', [
        _festival('holi', '2027-03-22', name: 'Holi'),
        _festival('ekadashi', '2026-11-20', major: false, name: 'Ekadashi'),
        _festival('diwali', '2026-11-08', name: 'Diwali'),
        _festival('kartik-purnima', '2026-11-24', name: 'Kartik Purnima'),
        _festival('dev-deepawali', '2026-11-24', name: 'Dev Deepawali'),
      ], DateTime(2026, 11, 13));
      expect(list.map((f) => f['name']), ['Kartik Purnima', 'Holi']);
      expect(list.first['date'], '2026-11-24');
      expect(list.first['emoji'], '🪔');
      expect(list.last['emoji'], '🎨');
    });

    test('now widget periods are epoch times from the city clock', () {
      final day = widgetNowDay('en', DateTime(2026, 11, 13), {
        'sunrise': '2026-11-13T06:24:00+05:30',
        'sunset': '2026-11-13T17:36:00+05:30',
      }, nextSunrise: '2026-11-14T06:25:00+05:30');
      final periods = day['periods']! as List;
      expect(periods, hasLength(16));
      final first = periods.first as List;
      expect(first[0], DateTime.utc(2026, 11, 13, 0, 54).millisecondsSinceEpoch);
      expect((periods.last as List)[1], DateTime.utc(2026, 11, 14, 0, 55).millisecondsSinceEpoch);
      // Friday: the first day Choghadiya is Char, Rahu Kalam the fourth eighth of daylight.
      expect(first[2], 'Char');
      expect(first[3], 'neutral');
      final rahu = day['rahu']! as List;
      expect(rahu[2], '10:36 AM – 12:00 PM');
    });

    test('widget links open only their screens', () {
      expect(widgetRoute(Uri.parse('devalay://calendar')), '/calendar');
      expect(widgetRoute(Uri.parse('devalay://calendar/day/2026-11-13')), '/calendar/day/2026-11-13');
      expect(widgetRoute(Uri.parse('devalay://panchang')), '/panchang');
      expect(widgetRoute(Uri.parse('devalay://settings')), isNull);
      expect(widgetRoute(Uri.parse('https://calendar')), isNull);
      expect(widgetRoute(null), isNull);
    });
  });
}
