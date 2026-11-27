import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/admin_stats.dart';
import '../core/dev_emulators.dart';
import '../core/firebase.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import 'admin_send.dart';

/// Web OAuth client of the devalay-chandra project: Google returns an ID token for it, which
/// Firebase exchanges for a session. A public identifier, not a secret.
const _webClientId = '729650365531-ch7t62hmm7ahqcla2jfvh5dam18v8msq.apps.googleusercontent.com';

/// Owner console: who is using Devalay right now, what they use most, and their feedback.
///
/// Opened by tapping the version in Settings seven times. Hiding the entry is a convenience, not
/// the control: every read below is allowed by the Firestore and Realtime Database rules only for
/// an account with the `admin` custom claim (or an `admins/{uid}` record), which no app can grant.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirebaseServices.enabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(child: Text('Firebase is not configured in this build.')),
      );
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snap) {
        final user = snap.data;
        if (user == null || user.isAnonymous) return const _SignIn();
        return _AdminGate(user: user);
      },
    );
  }
}

Future<void> _signOut() async {
  try {
    await GoogleSignIn.instance.signOut();
  } catch (_) {}
  await FirebaseAuth.instance.signOut();
}

class _SignIn extends StatefulWidget {
  const _SignIn();

  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> {
  bool _busy = false;
  String? _error;
  static Future<void>? _init;
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Debug builds on the local emulators only (dev_emulators.dart): a test admin made by the seed script.
  Future<void> _emulatorSignIn() async {
    setState(() => _busy = true);
    try {
      await Usage.flush();
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
    } catch (e) {
      _error = 'Emulator sign-in failed: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final g = GoogleSignIn.instance;
      await (_init ??= g.initialize(serverClientId: _webClientId));
      final account = await g.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw StateError('Google returned no ID token');
      // Write what this install has pending under its anonymous id before switching accounts.
      await Usage.flush();
      await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: token));
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) _error = 'Google sign-in failed (${e.code.name}).';
    } catch (e) {
      _error = 'Sign-in failed: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_rounded, size: 72, color: Palette.saffron),
              const SizedBox(height: 16),
              const Text('Owner console', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Sign in with the Google account that has admin access.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login_rounded),
                label: const Text('Sign in with Google'),
              ),
              if (useEmulators) ...[
                const SizedBox(height: 24),
                const Text('Local emulators (debug build)'),
                TextField(
                  key: const ValueKey('emu-email'),
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  key: const ValueKey('emu-password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                TextButton(onPressed: _busy ? null : _emulatorSignIn, child: const Text('Sign in to the emulator')),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Checks the account: the `admin` claim on a fresh token, or an `admins/{uid}` record.
class _AdminGate extends StatefulWidget {
  const _AdminGate({required this.user});
  final User user;

  @override
  State<_AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<_AdminGate> {
  late Future<bool> _isAdmin = _check();

  Future<bool> _check() async {
    final token = await widget.user.getIdTokenResult(true);
    if (token.claims?['admin'] == true) return true;
    try {
      final doc = await FirebaseFirestore.instance.collection('admins').doc(widget.user.uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdmin,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin')),
            body: snap.hasError
                ? Center(child: Text('Could not check access: ${snap.error}'))
                : const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 56),
                  const SizedBox(height: 12),
                  Text('${widget.user.email ?? 'This account'} is not an admin.', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  SelectableText('Account id: ${widget.user.uid}', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: () => setState(() => _isAdmin = _check()),
                        child: const Text('Check again'),
                      ),
                      FilledButton(onPressed: _signOut, child: const Text('Sign out')),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        return const _Dashboard();
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Data

class Presence {
  Presence(this.uid, Map m)
    : online = m['s'] == 'active',
      at = DateTime.fromMillisecondsSinceEpoch((m['t'] as num?)?.toInt() ?? 0),
      screen = '${m['scr'] ?? ''}',
      lang = '${m['lang'] ?? ''}',
      version = '${m['v'] ?? ''}',
      state = '${m['st'] ?? ''}';
  final String uid;
  final bool online;
  final DateTime at;
  final String screen, lang, version, state;
}

/// Counters that describe navigation rather than a feature.
const _ignored = {'app_open', 'root', 'onboarding'};

List<MapEntry<String, int>> _topFeatures(InstallRow u) =>
    u.features.entries.where((e) => !_ignored.contains(e.key)).toList()..sort((a, b) => b.value.compareTo(a.value));

class Activity {
  Activity(this.uid, Map m)
    : kind = '${m['k'] ?? ''}',
      item = m['n'] == null ? null : '${m['n']}',
      at = DateTime.fromMillisecondsSinceEpoch((m['t'] as num?)?.toInt() ?? 0);
  final String uid, kind;
  final String? item;
  final DateTime at;

  String get label => switch (kind) {
    'screen' => 'opened ${item ?? ''}',
    'app_open' => 'opened the app',
    'audio_play' => 'played audio ${item ?? ''}',
    'gita_listen' => 'listened to Gita chapter ${item ?? ''}',
    'panchang_listen' => 'listened to the Panchang',
    'japa_round' => 'finished a japa round',
    'share' => 'shared something',
    'share_app' => 'shared Devalay',
    'city_set' => 'set city ${item ?? ''}',
    'language_set' => 'changed language to ${item ?? ''}',
    'feedback_sent' => 'sent feedback (${item ?? ''})',
    'reminder_open' => 'opened a ${item ?? ''} reminder',
    'widget_tap' => 'tapped the ${item ?? ''} widget',
    'push_open' => 'opened a notification you sent',
    'notification_settings_changed' => 'changed reminders (${item ?? ''})',
    _ => '$kind ${item ?? ''}',
  };
}

List<Activity> _flatten(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) => [
  for (final d in docs)
    for (final i in (d.data()['items'] as List?) ?? const [])
      if (i is Map) Activity('${d.data()['uid']}', i),
]..sort((a, b) => b.at.compareTo(a.at));

final _installsProvider = FutureProvider.autoDispose<List<InstallRow>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection('installs')
      .orderBy('lastSeen', descending: true)
      .limit(5000)
      .get();
  return [for (final d in snap.docs) InstallRow.fromMap(d.id, d.data())];
});

/// The last 14 days of actions, for daily users, retention and top screens.
final _activityProvider = FutureProvider.autoDispose<List<ActivityRow>>((ref) async {
  final since = DateTime.now().subtract(const Duration(days: 15));
  final snap = await FirebaseFirestore.instance
      .collection('events')
      .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .orderBy('at', descending: true)
      .limit(12000)
      .get();
  return [for (final d in snap.docs) ...ActivityRow.fromBatch(d.data())];
});

final _statsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  final installs = await ref.watch(_installsProvider.future);
  final activity = await ref.watch(_activityProvider.future);
  return AdminStats.compute(installs, activity);
});

String short(String uid) => uid.length > 6 ? uid.substring(0, 6) : uid;

String ago(DateTime? t) {
  if (t == null) return '—';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

String clock(DateTime t) =>
    '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String pct(double? v) => v == null ? '—' : '${(v * 100).round()}%';

// ---------------------------------------------------------------------------------------------
// Dashboard

/// Opens the Send tab with one install as the audience (from a user's page).
final _sendTo = NotifierProvider<_SendTo, String?>(_SendTo.new);

class _SendTo extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? uid) => state = uid;
}

class _Dashboard extends ConsumerStatefulWidget {
  const _Dashboard();

  @override
  ConsumerState<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<_Dashboard> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 5, vsync: this);

  @override
  void initState() {
    super.initState();
    Usage.rtdb.goOnline();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(_sendTo, (_, uid) {
      if (uid != null) _tabs.animateTo(3);
    });
    final installs = ref.watch(_installsProvider).value ?? const <InstallRow>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devalay admin'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(_installsProvider);
              ref.invalidate(_activityProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(tooltip: 'Sign out', onPressed: _signOut, icon: const Icon(Icons.logout_rounded)),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Live'),
            Tab(text: 'Overview'),
            Tab(text: 'Users'),
            Tab(text: 'Send'),
            Tab(text: 'Feedback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const _LiveTab(),
          const _OverviewTab(),
          const _UsersTab(),
          SendTab(key: ValueKey(ref.watch(_sendTo)), installs: installs, initialUser: ref.watch(_sendTo)),
          const _FeedbackTab(),
        ],
      ),
    );
  }
}

class _LiveTab extends StatefulWidget {
  const _LiveTab();

  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> with AutomaticKeepAliveClientMixin {
  late final Stream<DatabaseEvent> _presence = Usage.rtdb.ref('status').orderByChild('t').limitToLast(200).onValue;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Repaint "2m ago" labels; no network.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<DatabaseEvent>(
      stream: _presence,
      builder: (context, snap) {
        if (snap.hasError) return _Problem('${snap.error}');
        final raw = snap.data?.snapshot.value;
        final people = <Presence>[
          if (raw is Map)
            for (final e in raw.entries)
              if (e.value is Map) Presence('${e.key}', e.value as Map),
        ]..sort((a, b) => b.at.compareTo(a.at));
        final online = people.where((p) => p.online).toList();
        final hour = people.where((p) => DateTime.now().difference(p.at) < const Duration(hours: 1)).length;
        final today = people.where((p) => DateTime.now().difference(p.at) < const Duration(hours: 24)).length;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                _Stat('Online now', '${online.length}', color: Colors.green),
                _Stat('Last hour', '$hour'),
                _Stat('Last 24 h', '$today'),
              ],
            ),
            const _Section('Online now'),
            if (!snap.hasData) const LinearProgressIndicator(),
            if (snap.hasData && online.isEmpty) const _Empty('Nobody has the app open right now.'),
            for (final p in online) _PresenceTile(p),
            const _Section('Live activity'),
            const _LiveActivity(key: ValueKey('live-activity')),
            const _Section('Recently seen'),
            for (final p in people.where((p) => !p.online).take(30)) _PresenceTile(p),
          ],
        );
      },
    );
  }
}

/// The newest activity across all installs. It owns its Firestore stream: as a list child it is
/// rebuilt whenever the list above it changes length (someone comes online), and a stream kept by
/// the tab would then be listened to a second time ("Stream has already been listened to").
class _LiveActivity extends StatefulWidget {
  const _LiveActivity({super.key});

  @override
  State<_LiveActivity> createState() => _LiveActivityState();
}

class _LiveActivityState extends State<_LiveActivity> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _events = FirebaseFirestore.instance
      .collection('events')
      .orderBy('at', descending: true)
      .limit(40)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _events,
      builder: (context, ev) {
        if (ev.hasError) return _Problem('${ev.error}');
        if (!ev.hasData) return const LinearProgressIndicator();
        final items = _flatten(ev.data!.docs).take(80).toList();
        if (items.isEmpty) return const _Empty('No activity yet.');
        return Column(children: [for (final a in items) _ActivityTile(a, showUser: true)]);
      },
    );
  }
}

class _PresenceTile extends StatelessWidget {
  const _PresenceTile(this.p);
  final Presence p;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(Icons.circle, size: 12, color: p.online ? Colors.green : Colors.grey),
      title: Text('User ${short(p.uid)} · ${p.online ? p.screen : 'offline'}'),
      subtitle: Text([p.lang, p.version, p.state, ago(p.at)].where((s) => s.isNotEmpty).join(' · ')),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => openUser(context, p.uid),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile(this.a, {this.showUser = false});
  final Activity a;
  final bool showUser;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Text(clock(a.at), style: Theme.of(context).textTheme.bodySmall),
      title: Text(showUser ? '${short(a.uid)} ${a.label}' : a.label),
      onTap: showUser ? () => openUser(context, a.uid) : null,
    );
  }
}

/// The numbers that say whether Devalay is growing and keeping people, top to bottom: health,
/// days, retention, funnel, daily habit, what people use, and who they are.
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_statsProvider);
    final installs = ref.watch(_installsProvider).value ?? const <InstallRow>[];
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_installsProvider);
        ref.invalidate(_activityProvider);
        await ref.read(_statsProvider.future);
      },
      child: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Problem('$e'),
        data: (s) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Wrap(
              children: [
                _Stat('New today', '${s.newToday}'),
                _Stat('New 7 days', '${s.new7}'),
                _Stat('Active today', '${s.activeToday}', color: Colors.green),
                _Stat('Active 7 days', '${s.active7}'),
                _Stat('Back next day', pct(s.d1), hint: 'D1 retention'),
                _Stat('Back on day 7', pct(s.d7), hint: 'D7 retention'),
                _Stat('Opened once', pct(s.oneSession), hint: 'of all installs'),
                _Stat('Reachable', '${s.reachable}', hint: 'by a push to one person'),
              ],
            ),
            const _Section('Last 14 days (new · active)'),
            _Daily(s),
            const _Section('Back on day N, by install day'),
            _CohortTable(s.cohorts),
            const _Section('Last 30 days: from install to habit'),
            for (final f in s.funnel)
              _Bar(
                f.label,
                f.count,
                s.funnel.first.count,
                trailing: '${f.count} · ${pct(s.funnel.first.count == 0 ? null : f.count / s.funnel.first.count)}',
              ),
            const _Section('Daily habit'),
            Wrap(
              children: [
                _Stat('Morning Panchang', pct(s.morningOn), hint: 'on, of 1.5.7+'),
                _Stat('Home widget', pct(s.widgetOn), hint: 'placed, of 1.5.7+'),
                _Stat('Chose a city', pct(s.cityChosen)),
              ],
            ),
            const _Section('Screens this week (people · times)'),
            if (s.screens.isEmpty) const _Empty('No screens recorded this week.'),
            for (final u in s.screens.take(15))
              _Bar(u.name, u.users, s.screens.first.users, trailing: '${u.users} · ${u.times}'),
            const _Section('Actions this week (people · times)'),
            for (final u in s.actions.take(15))
              _Bar(u.name, u.users, s.actions.first.users, trailing: '${u.users} · ${u.times}'),
            _Split('Language', splitBy(installs, (i) => i.lang)),
            _Split('State (chosen city)', splitBy(installs.where((i) => i.chose), (i) => i.state)),
            _Split('App version', splitBy(installs, (i) => i.version)),
            _Split('Phone brand', splitBy(installs.where((i) => i.device.isNotEmpty), (i) => i.brand)),
            _Split('Android', splitBy(installs.where((i) => i.sdk > 0), (i) => i.android)),
            _Split('Memory', splitBy(installs.where((i) => i.ramMb > 0), (i) => i.ram)),
            _Split('Installed from', splitBy(installs, (i) => i.source)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Usage starts with 1.5.3; screens other than the five tabs, phones and the daily-habit numbers '
                'start with 1.5.7. Installs that turned off usage statistics are not counted.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Daily extends StatelessWidget {
  const _Daily(this.s);
  final AdminStats s;

  @override
  Widget build(BuildContext context) {
    final most = s.daily.fold<int>(1, (m, d) => d.active > m ? d.active : m);
    return Column(
      children: [
        for (final d in s.daily.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Row(
              children: [
                SizedBox(width: 48, child: Text('${d.day.day}/${d.day.month}')),
                Expanded(
                  child: Column(
                    children: [
                      _Thin(d.added / most, Colors.blue),
                      const SizedBox(height: 2),
                      _Thin(d.active / most, Colors.green),
                    ],
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${d.added} · ${d.active}',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Thin extends StatelessWidget {
  const _Thin(this.value, this.color);
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 6,
      color: color,
      backgroundColor: color.withValues(alpha: 0.1),
    ),
  );
}

class _CohortTable extends StatelessWidget {
  const _CohortTable(this.cohorts);
  final List<Cohort> cohorts;

  @override
  Widget build(BuildContext context) {
    if (cohorts.isEmpty) return const _Empty('No installs in the last 14 days.');
    final small = Theme.of(context).textTheme.bodySmall;
    Widget cell(String text, {Color? color, bool bold = false}) => Container(
      width: 44,
      height: 28,
      alignment: Alignment.center,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: small?.copyWith(fontWeight: bold ? FontWeight.w700 : null)),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              cell('Day', bold: true),
              cell('New', bold: true),
              for (var n = 1; n <= 7; n++) cell('D$n', bold: true),
            ],
          ),
          for (final c in cohorts.reversed)
            Row(
              children: [
                cell('${c.day.day}/${c.day.month}'),
                cell('${c.size}'),
                for (var n = 1; n <= 7; n++)
                  c.rate(n) == null
                      ? cell('')
                      : cell(pct(c.rate(n)), color: Colors.green.withValues(alpha: 0.08 + 0.8 * c.rate(n)!)),
              ],
            ),
        ],
      ),
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> with AutomaticKeepAliveClientMixin {
  UserFilter _filter = const UserFilter();

  @override
  bool get wantKeepAlive => true;

  void _set(UserFilter f) => setState(() => _filter = f);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = ref.watch(_installsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(_installsProvider.future),
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Problem('$e'),
        data: (all) {
          final f = _filter;
          final shown = f.apply(all);
          final langs = splitBy(all, (i) => i.lang).map((e) => e.key).where((k) => k != '—').toList();
          final states = splitBy(all.where((i) => i.chose), (i) => i.state).map((e) => e.key).where((k) => k != '—');
          UserFilter copy({
            Object? lang = _keep,
            Object? state = _keep,
            Object? inactiveDays = _keep,
            Object? morningOn = _keep,
            bool? reachable,
            String? query,
          }) => UserFilter(
            lang: lang == _keep ? f.lang : lang as String?,
            state: state == _keep ? f.state : state as String?,
            inactiveDays: inactiveDays == _keep ? f.inactiveDays : inactiveDays as int?,
            morningOn: morningOn == _keep ? f.morningOn : morningOn as bool?,
            reachable: reachable ?? f.reachable,
            query: query ?? f.query,
          );
          return ListView.builder(
            itemCount: shown.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Install id or phone model',
                        ),
                        onChanged: (q) => _set(copy(query: q)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _PickChip('Language', f.lang, langs, (v) => _set(copy(lang: v))),
                          _PickChip('State', f.state, states.toList(), (v) => _set(copy(state: v))),
                          FilterChip(
                            label: const Text('Away 3+ days'),
                            selected: f.inactiveDays != null,
                            onSelected: (on) => _set(copy(inactiveDays: on ? 3 : null)),
                          ),
                          FilterChip(
                            label: const Text('Morning Panchang on'),
                            selected: f.morningOn == true,
                            onSelected: (on) => _set(copy(morningOn: on ? true : null)),
                          ),
                          FilterChip(
                            label: const Text('Reachable by push'),
                            selected: f.reachable,
                            onSelected: (on) => _set(copy(reachable: on)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${shown.length} of ${all.length} installs', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              }
              final u = shown[i - 1];
              final top = _topFeatures(u).take(3).map((e) => e.key).join(', ');
              return ListTile(
                title: Text(
                  'User ${short(u.uid)} · ${[u.lang, if (u.chose) u.state, u.device].where((s) => s.isNotEmpty).join(' · ')}',
                ),
                subtitle: Text(
                  '${ago(u.lastSeen)} · ${u.sessions} sessions · v${u.version}'
                  '${u.morning == 'on' ? ' · 🌅' : ''}${(u.widgets ?? 0) > 0 ? ' · 🧩' : ''}${u.hasToken ? ' · 🔔' : ''}'
                  '${top.isEmpty ? '' : '\n$top'}',
                ),
                isThreeLine: top.isNotEmpty,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openUser(context, u.uid),
              );
            },
          );
        },
      ),
    );
  }
}

const _keep = Object();

class _PickChip extends StatelessWidget {
  const _PickChip(this.label, this.value, this.options, this.onPick);
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: (v) => onPick(v == '' ? null : v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: '', child: Text('Any')),
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: Chip(
        label: Text(value == null ? label : '$label: $value'),
        avatar: Icon(Icons.arrow_drop_down_rounded, color: value == null ? null : Palette.saffron),
      ),
    );
  }
}

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();

  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

/// Feedback status: new (to read), replied (answered on Play or by mail), fixed (in a release).
String _status(Map m) => '${m['status'] ?? (m['done'] == true ? 'fixed' : 'new')}';

class _FeedbackTabState extends State<_FeedbackTab> {
  String _show = 'new';
  late final _stream = FirebaseFirestore.instance
      .collection('feedback')
      .orderBy('at', descending: true)
      .limit(200)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return _Problem('${snap.error}');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final all = snap.data!.docs;
        int count(String s) => all.where((d) => _status(d.data()) == s).length;
        final docs = all.where((d) => _show == 'all' || _status(d.data()) == _show).toList();
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'new', label: Text('New ${count('new')}')),
                ButtonSegment(value: 'replied', label: Text('Replied ${count('replied')}')),
                ButtonSegment(value: 'fixed', label: Text('Fixed ${count('fixed')}')),
                ButtonSegment(value: 'all', label: Text('All ${all.length}')),
              ],
              selected: {_show},
              onSelectionChanged: (s) => setState(() => _show = s.first),
            ),
            const SizedBox(height: 8),
            if (docs.isEmpty) const _Empty('Nothing here.'),
            for (final d in docs) _FeedbackCard(d),
          ],
        );
      },
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard(this.doc);
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  Future<void> _note(BuildContext context, String current) async {
    final c = TextEditingController(text: current);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Note'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'What was done'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (note != null) await doc.reference.update({'note': note});
  }

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final at = (m['at'] as Timestamp?)?.toDate();
    final status = _status(m);
    final note = '${m['note'] ?? ''}';
    final emoji = switch (m['kind']) {
      'problem' => '🛠️',
      'praise' => '🙏',
      _ => '💡',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('$emoji ${m['text'] ?? ''}', style: const TextStyle(fontSize: 15)),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('📝 $note', style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            InkWell(
              onTap: () => openUser(context, '${m['uid']}'),
              child: Text(
                'User ${short('${m['uid']}')} · ${m['lang'] ?? ''} · v${m['v'] ?? ''} · ${at == null ? '' : clock(at)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final s in const ['new', 'replied', 'fixed'])
                  ChoiceChip(
                    label: Text(s),
                    selected: status == s,
                    onSelected: (_) => doc.reference.update({'status': s, 'done': s != 'new'}),
                  ),
                TextButton.icon(
                  onPressed: () => _note(context, note),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Note'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// One user

void openUser(BuildContext context, String uid) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _UserScreen(uid: uid)));

class _UserScreen extends ConsumerWidget {
  const _UserScreen({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: Text('User ${short(uid)}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          StreamBuilder<DatabaseEvent>(
            stream: Usage.rtdb.ref('status/$uid').onValue,
            builder: (context, snap) {
              final v = snap.data?.snapshot.value;
              if (v is! Map) return const SizedBox.shrink();
              final p = Presence(uid, v);
              return Card(
                child: ListTile(
                  leading: Icon(Icons.circle, color: p.online ? Colors.green : Colors.grey),
                  title: Text(p.online ? 'Online now · ${p.screen}' : 'Offline · last seen ${ago(p.at)}'),
                  subtitle: Text([p.lang, p.version, p.state].where((s) => s.isNotEmpty).join(' · ')),
                ),
              );
            },
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: db.collection('installs').doc(uid).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return _Problem('${snap.error}');
              final data = snap.data?.data();
              if (data == null) return const SizedBox.shrink();
              final u = InstallRow.fromMap(uid, data);
              final top = _topFeatures(u);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    children: [
                      _Stat('Sessions', '${u.sessions}'),
                      _Stat('First seen', u.firstSeen == null ? '—' : '${u.firstSeen!.day}/${u.firstSeen!.month}'),
                      _Stat('Last seen', ago(u.lastSeen)),
                    ],
                  ),
                  Text(
                    [
                      'Language ${u.lang}',
                      if (u.chose && u.state.isNotEmpty) u.state,
                      'v${u.version}',
                      if (u.source.isNotEmpty) u.source,
                    ].join(' · '),
                  ),
                  if (u.device.isNotEmpty)
                    Text([u.device, u.android, if (u.ram.isNotEmpty) '${u.ram} RAM'].join(' · ')),
                  Text(
                    [
                      'Morning Panchang ${u.morning.isEmpty ? '—' : u.morning}',
                      'widgets ${u.widgets ?? '—'}',
                      if (u.notificationsAllowed == false) 'notifications blocked',
                    ].join(' · '),
                  ),
                  if (u.hasToken)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            ref.read(_sendTo.notifier).set(uid);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Send a notification to this install'),
                        ),
                      ),
                    ),
                  const _Section('Uses most'),
                  for (final e in top.take(20)) _Bar(e.key, e.value, top.first.value),
                ],
              );
            },
          ),
          const _Section('Timeline'),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('events')
                .where('uid', isEqualTo: uid)
                .orderBy('at', descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return _Problem('${snap.error}');
              if (!snap.hasData) return const LinearProgressIndicator();
              final items = _flatten(snap.data!.docs);
              if (items.isEmpty) return const _Empty('No activity recorded.');
              return Column(children: [for (final a in items) _ActivityTile(a)]);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Small pieces

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color, this.hint});
  final String label, value;
  final Color? color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              if (hint != null)
                Text(
                  hint!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
  );
}

class _Bar extends StatelessWidget {
  const _Bar(this.label, this.value, this.max, {this.trailing});
  final String label;
  final int value, max;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(label, overflow: TextOverflow.ellipsis)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : value / max,
                minHeight: 10,
                color: Palette.saffron,
                backgroundColor: Palette.saffron.withValues(alpha: 0.12),
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(trailing ?? '$value', textAlign: TextAlign.end, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split(this.title, this.rows);
  final String title;
  final List<MapEntry<String, int>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_Section(title), for (final e in rows.take(15)) _Bar(e.key, e.value, rows.first.value)],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(text, textAlign: TextAlign.center),
  );
}

class _Problem extends StatelessWidget {
  const _Problem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(text, style: const TextStyle(color: Colors.red)),
  );
}
