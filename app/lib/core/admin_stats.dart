import 'package:cloud_firestore/cloud_firestore.dart';

/// The numbers on the owner's admin screen, worked out from the usage log (Firestore `installs`
/// summaries and `events` batches, see usage.dart). Pure functions over plain rows, so they are
/// tested without Firebase (test/admin_stats_test.dart).

DateTime? _time(Object? v) => switch (v) {
  final Timestamp t => t.toDate(),
  final DateTime d => d,
  final num n => DateTime.fromMillisecondsSinceEpoch(n.toInt()),
  _ => null,
};

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// One install's summary document.
class InstallRow {
  InstallRow({
    required this.uid,
    this.firstSeen,
    this.lastSeen,
    this.lang = '',
    this.state = '',
    this.version = '',
    this.source = '',
    this.sessions = 0,
    this.features = const {},
    this.device = '',
    this.sdk = 0,
    this.ramMb = 0,
    this.cityChosen,
    this.morning = '',
    this.notificationsAllowed,
    this.widgets,
    this.hasToken = false,
  });

  factory InstallRow.fromMap(String uid, Map<String, dynamic> m) => InstallRow(
    uid: uid,
    firstSeen: _time(m['firstSeen']),
    lastSeen: _time(m['lastSeen']),
    lang: '${m['lang'] ?? ''}',
    state: '${m['state'] ?? ''}',
    version: '${m['v'] ?? ''}',
    source: '${m['src'] ?? ''}',
    sessions: (m['sessions'] as num?)?.toInt() ?? 0,
    features: {for (final e in ((m['f'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num?)?.toInt() ?? 0},
    device: '${m['dev'] ?? ''}',
    sdk: (m['os'] as num?)?.toInt() ?? 0,
    ramMb: (m['ram'] as num?)?.toInt() ?? 0,
    cityChosen: m['cc'] as bool?,
    morning: '${m['np'] ?? ''}',
    notificationsAllowed: m['na'] as bool?,
    widgets: (m['nw'] as num?)?.toInt(),
    hasToken: m['t'] is String && (m['t'] as String).isNotEmpty,
  );

  final String uid;
  final DateTime? firstSeen, lastSeen;
  final String lang, state, version, source, device, morning;
  final int sessions, sdk, ramMb;
  final Map<String, int> features;
  final bool? cityChosen, notificationsAllowed;
  final int? widgets;
  final bool hasToken;

  /// Before 1.5.7 the city was not reported as chosen, and the state came from the default city
  /// (New Delhi → DL) too, so older installs count as having chosen only if they recorded a city_set.
  bool get chose => cityChosen ?? (features['city_set'] ?? 0) > 0;
  bool get onboarded => (features['home'] ?? 0) > 0 || sessions > 1;
  String get brand => device.isEmpty ? '' : device.split(' ').first;
  String get android => androidName(sdk);
  String get ram => ramClass(ramMb);
}

/// One recorded action ("screen" with the route as item, or a named action).
class ActivityRow {
  ActivityRow(this.uid, this.kind, this.item, this.at);
  final String uid, kind;
  final String? item;
  final DateTime at;

  /// The items of an `events` batch document.
  static List<ActivityRow> fromBatch(Map<String, dynamic> doc) => [
    for (final i in (doc['items'] as List?) ?? const [])
      if (i is Map)
        ActivityRow(
          '${doc['uid']}',
          '${i['k'] ?? ''}',
          i['n'] == null ? null : '${i['n']}',
          DateTime.fromMillisecondsSinceEpoch((i['t'] as num?)?.toInt() ?? 0),
        ),
  ];
}

String androidName(int sdk) => switch (sdk) {
  0 => '',
  >= 36 => 'Android 16',
  35 => 'Android 15',
  34 => 'Android 14',
  33 => 'Android 13',
  31 || 32 => 'Android 12',
  30 => 'Android 11',
  29 => 'Android 10',
  _ => 'Android 9 or older',
};

String ramClass(int mb) => switch (mb) {
  <= 0 => '',
  < 3500 => '≤3 GB',
  < 5000 => '4 GB',
  < 7000 => '6 GB',
  < 10000 => '8 GB',
  _ => '12 GB+',
};

/// D1..D7 for one install-day cohort; null where that day has not come yet.
class Cohort {
  Cohort(this.day, this.size, this.returned);
  final DateTime day;
  final int size;
  final List<int?> returned; // index 0 = D1

  double? rate(int n) => returned[n - 1] == null || size == 0 ? null : returned[n - 1]! / size;
}

class FunnelStep {
  const FunnelStep(this.label, this.count);
  final String label;
  final int count;
}

class Usage7 {
  const Usage7(this.name, this.times, this.users);
  final String name;
  final int times, users;
}

class AdminStats {
  AdminStats._({
    required this.installs,
    required this.newToday,
    required this.new7,
    required this.activeToday,
    required this.active7,
    required this.active30,
    required this.d1,
    required this.d7,
    required this.oneSession,
    required this.daily,
    required this.cohorts,
    required this.funnel,
    required this.screens,
    required this.actions,
    required this.morningOn,
    required this.widgetOn,
    required this.cityChosen,
    required this.reachable,
  });

  final int installs, newToday, new7, activeToday, active7, active30;

  /// Share of installs back exactly 1 / 7 days after their first day (eligible installs only).
  final double? d1, d7;
  final double oneSession;

  /// Last 14 days, oldest first: (day, new installs, active installs).
  final List<({DateTime day, int added, int active})> daily;
  final List<Cohort> cohorts;
  final List<FunnelStep> funnel;
  final List<Usage7> screens, actions;

  /// Shares among installs that report the trait (1.5.6+ / 1.5.7+), null when none do yet.
  final double? morningOn, widgetOn;
  final double cityChosen;

  /// Installs a push can reach one by one (they sent a token).
  final int reachable;

  static AdminStats compute(List<InstallRow> all, List<ActivityRow> activity, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final days = <String, Set<DateTime>>{};
    void seen(String uid, DateTime? t) {
      if (t != null) days.putIfAbsent(uid, () => {}).add(_day(t));
    }

    for (final i in all) {
      seen(i.uid, i.firstSeen);
      seen(i.uid, i.lastSeen);
    }
    for (final a in activity) {
      seen(a.uid, a.at);
    }
    bool activeOn(String uid, DateTime d) => days[uid]?.contains(d) ?? false;
    bool activeSince(String uid, DateTime from) => days[uid]?.any((d) => !d.isBefore(from)) ?? false;
    int ago(DateTime d) => today.difference(d).inDays;

    final first = {
      for (final i in all)
        if (i.firstSeen != null) i.uid: _day(i.firstSeen!),
    };
    double? returnRate(int n) {
      final eligible = first.entries.where((e) => ago(e.value) >= n).toList();
      if (eligible.isEmpty) return null;
      final back = eligible.where((e) => activeOn(e.key, e.value.add(Duration(days: n)))).length;
      return back / eligible.length;
    }

    final cohorts = <Cohort>[];
    for (var k = 13; k >= 0; k--) {
      final day = today.subtract(Duration(days: k));
      final members = [
        for (final e in first.entries)
          if (e.value == day) e.key,
      ];
      if (members.isEmpty) continue;
      cohorts.add(
        Cohort(day, members.length, [
          for (var n = 1; n <= 7; n++)
            ago(day) < n ? null : members.where((u) => activeOn(u, day.add(Duration(days: n)))).length,
        ]),
      );
    }

    final recent = [
      for (final i in all)
        if (i.firstSeen != null && ago(_day(i.firstSeen!)) <= 29) i,
    ];
    final backNextDay = recent.where((i) {
      final d = _day(i.firstSeen!);
      return ago(d) >= 1 && activeOn(i.uid, d.add(const Duration(days: 1)));
    }).length;

    List<Usage7> tally(Iterable<ActivityRow> rows, String Function(ActivityRow) name) {
      final times = <String, int>{};
      final users = <String, Set<String>>{};
      for (final a in rows) {
        final n = name(a);
        if (n.isEmpty) continue;
        times[n] = (times[n] ?? 0) + 1;
        users.putIfAbsent(n, () => {}).add(a.uid);
      }
      return [for (final e in times.entries) Usage7(e.key, e.value, users[e.key]!.length)]
        ..sort((a, b) => b.users != a.users ? b.users.compareTo(a.users) : b.times.compareTo(a.times));
    }

    final week = today.subtract(const Duration(days: 6));
    final lastWeek = activity.where((a) => !a.at.isBefore(week));
    double? share(Iterable<InstallRow> reporting, bool Function(InstallRow) yes) {
      final r = reporting.toList();
      return r.isEmpty ? null : r.where(yes).length / r.length;
    }

    return AdminStats._(
      installs: all.length,
      newToday: first.values.where((d) => d == today).length,
      new7: first.values.where((d) => ago(d) <= 6).length,
      activeToday: all.where((i) => activeOn(i.uid, today)).length,
      active7: all.where((i) => activeSince(i.uid, week)).length,
      active30: all.where((i) => activeSince(i.uid, today.subtract(const Duration(days: 29)))).length,
      d1: returnRate(1),
      d7: returnRate(7),
      oneSession: all.isEmpty ? 0 : all.where((i) => i.sessions <= 1).length / all.length,
      daily: [
        for (var k = 13; k >= 0; k--)
          (
            day: today.subtract(Duration(days: k)),
            added: first.values.where((d) => d == today.subtract(Duration(days: k))).length,
            active: all.where((i) => activeOn(i.uid, today.subtract(Duration(days: k)))).length,
          ),
      ],
      cohorts: cohorts,
      funnel: [
        FunnelStep('Installed (30 d)', recent.length),
        FunnelStep('Finished setup', recent.where((i) => i.onboarded).length),
        FunnelStep('Chose a city', recent.where((i) => i.chose).length),
        FunnelStep('Morning Panchang on', recent.where((i) => i.morning == 'on').length),
        FunnelStep('Came back next day', backNextDay),
      ],
      screens: tally(lastWeek.where((a) => a.kind == 'screen'), (a) => a.item ?? ''),
      actions: tally(lastWeek.where((a) => a.kind != 'screen' && a.kind != 'app_open'), (a) => a.kind),
      morningOn: share(all.where((i) => i.morning.isNotEmpty), (i) => i.morning == 'on'),
      widgetOn: share(all.where((i) => i.widgets != null), (i) => (i.widgets ?? 0) > 0),
      cityChosen: all.isEmpty ? 0 : all.where((i) => i.chose).length / all.length,
      reachable: all.where((i) => i.hasToken).length,
    );
  }
}

/// Counts of installs by [key] ('—' for none), largest first.
List<MapEntry<String, int>> splitBy(Iterable<InstallRow> all, String Function(InstallRow) key) {
  final m = <String, int>{};
  for (final i in all) {
    final k = key(i).isEmpty ? '—' : key(i);
    m[k] = (m[k] ?? 0) + 1;
  }
  return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// The Users tab's filters.
class UserFilter {
  const UserFilter({this.lang, this.state, this.inactiveDays, this.morningOn, this.reachable = false, this.query = ''});
  final String? lang, state;
  final int? inactiveDays;
  final bool? morningOn;
  final bool reachable;
  final String query;

  bool get any =>
      lang != null || state != null || inactiveDays != null || morningOn != null || reachable || query.isNotEmpty;

  List<InstallRow> apply(List<InstallRow> all, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: inactiveDays ?? 0));
    final q = query.trim().toLowerCase();
    return all.where((i) {
      if (lang != null && i.lang != lang) return false;
      if (state != null && i.state != state) return false;
      if (inactiveDays != null && (i.lastSeen == null || i.lastSeen!.isAfter(cutoff))) return false;
      if (morningOn != null && (i.morning == 'on') != morningOn) return false;
      if (reachable && !i.hasToken) return false;
      if (q.isNotEmpty && !i.uid.toLowerCase().startsWith(q) && !i.device.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }
}
