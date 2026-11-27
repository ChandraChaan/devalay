import 'package:devalay/core/admin_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// The admin screen's numbers, from a small hand-made usage log.
void main() {
  final now = DateTime(2026, 11, 27, 18);
  DateTime day(int ago, [int hour = 9]) => DateTime(2026, 11, 27 - ago, hour);

  // a: installed 8 days ago, back on day 1 and day 7 · b: installed 2 days ago, back on day 1
  // c: installed 2 days ago, never back · d: installed today · e: an old 1.5.4 install (no traits)
  final installs = [
    InstallRow(
      uid: 'a',
      firstSeen: day(8),
      lastSeen: day(1),
      lang: 'te',
      state: 'AP',
      sessions: 4,
      features: {'home': 3},
      cityChosen: true,
      morning: 'on',
      widgets: 1,
      hasToken: true,
      device: 'OPPO CPH2689',
      sdk: 36,
      ramMb: 7800,
    ),
    InstallRow(
      uid: 'b',
      firstSeen: day(2),
      lastSeen: day(1),
      lang: 'te',
      sessions: 2,
      features: {'home': 1},
      cityChosen: false,
      morning: 'off',
      widgets: 0,
      hasToken: true,
      device: 'Samsung SM-A155F',
      sdk: 34,
      ramMb: 3800,
    ),
    InstallRow(
      uid: 'c',
      firstSeen: day(2),
      lastSeen: day(2),
      lang: 'en',
      sessions: 1,
      features: {'onboarding': 1},
      cityChosen: false,
      morning: 'off',
      widgets: 0,
    ),
    InstallRow(
      uid: 'd',
      firstSeen: day(0),
      lastSeen: day(0),
      lang: 'te',
      state: 'TG',
      sessions: 1,
      features: {'home': 1},
      cityChosen: true,
      morning: 'on',
      widgets: 0,
      hasToken: true,
    ),
    InstallRow(
      uid: 'e',
      firstSeen: day(20),
      lastSeen: day(0),
      lang: 'hi',
      state: 'DL',
      version: '1.5.4',
      sessions: 9,
      features: {'home': 9},
    ),
  ];
  final activity = [
    ActivityRow('a', 'screen', 'panchang', day(7)),
    ActivityRow('a', 'screen', 'panchang', day(1)),
    ActivityRow('a', 'audio_play', '1', day(1)),
    ActivityRow('b', 'screen', 'home', day(1)),
    ActivityRow('b', 'screen', 'panchang', day(1, 10)),
    ActivityRow('d', 'app_open', null, day(0)),
    ActivityRow('e', 'reminder_open', 'panchang', day(0)),
  ];
  final s = AdminStats.compute(installs, activity, now: now);

  test('headline numbers', () {
    expect(s.installs, 5);
    expect(s.newToday, 1);
    expect(s.new7, 3); // b, c, d
    expect(s.activeToday, 2); // d, e
    expect(s.active7, 5);
    expect(s.oneSession, 2 / 5);
    expect(s.reachable, 3);
  });

  test('D1 and D7 count only installs old enough', () {
    // D1 eligible: a, b, c, e (d is today). Back next day: a (day 7), b. e's day after install has no record.
    expect(s.d1, 2 / 4);
    // D7 eligible: a, e. a was back on day 1 (its 7th day after install).
    expect(s.d7, 1 / 2);
  });

  test('cohort rows leave future days empty', () {
    final two = s.cohorts.firstWhere((c) => c.day == DateTime(2026, 11, 25));
    expect(two.size, 2);
    expect(two.returned[0], 1); // b
    expect(two.returned[1], 0); // day 2 = today: nobody of b, c today
    expect(two.returned[2], isNull);
    expect(two.rate(1), 0.5);
  });

  test('funnel over the last 30 days of installs', () {
    expect([for (final f in s.funnel) f.count], [5, 4, 2, 2, 2]);
  });

  test('top screens and actions of the week', () {
    expect(s.screens.first.name, 'panchang');
    expect(s.screens.first.users, 2);
    expect(s.screens.first.times, 2); // a's view 7 days ago is outside the week
    expect([for (final a in s.actions) a.name], containsAll(['audio_play', 'reminder_open']));
    expect(s.actions.map((a) => a.name), isNot(contains('app_open')));
  });

  test('trait shares ignore installs that do not report them yet', () {
    expect(s.morningOn, 2 / 4);
    expect(s.widgetOn, 1 / 4);
    // a, d chose. e (an older app) reports DL from the default city but never set one.
    expect(s.cityChosen, 2 / 5);
  });

  test('device splits', () {
    expect(installs.first.brand, 'OPPO');
    expect(installs.first.android, 'Android 16');
    expect(installs.first.ram, '8 GB');
    expect(installs[1].ram, '4 GB');
    expect(splitBy(installs, (i) => i.lang).first, isA<MapEntry<String, int>>().having((e) => e.key, 'key', 'te'));
  });

  test('user filters', () {
    expect(const UserFilter(lang: 'te').apply(installs, now: now).map((i) => i.uid), ['a', 'b', 'd']);
    expect(const UserFilter(inactiveDays: 2).apply(installs, now: now).map((i) => i.uid), ['c']);
    expect(const UserFilter(morningOn: true, reachable: true).apply(installs, now: now).map((i) => i.uid), ['a', 'd']);
    expect(const UserFilter(query: 'samsung').apply(installs, now: now).map((i) => i.uid), ['b']);
    expect(const UserFilter().any, isFalse);
  });

  test('reads Firestore maps, including events batches', () {
    final i = InstallRow.fromMap('x', {
      'firstSeen': DateTime(2026, 11, 20),
      'lang': 'te',
      'f': {'home': 2},
      'dev': 'Vivo V2207',
      'os': 33,
      'ram': 5900,
      'np': 'blocked',
      'nw': 2,
      't': 'token',
    });
    expect(i.hasToken, isTrue);
    expect(i.morning, 'blocked');
    expect(i.ram, '6 GB');
    final rows = ActivityRow.fromBatch({
      'uid': 'x',
      'items': [
        {'k': 'screen', 'n': 'panchang', 't': DateTime(2026, 11, 27, 6).millisecondsSinceEpoch},
        {'k': 'app_open', 't': 0},
        'junk',
      ],
    });
    expect(rows.length, 2);
    expect(rows.first.item, 'panchang');
  });
}
