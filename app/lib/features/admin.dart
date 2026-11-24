import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/firebase.dart';
import '../core/theme.dart';
import '../core/usage.dart';

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

class Install {
  Install(this.uid, Map<String, dynamic> m)
    : firstSeen = (m['firstSeen'] as Timestamp?)?.toDate(),
      lastSeen = (m['lastSeen'] as Timestamp?)?.toDate(),
      lang = '${m['lang'] ?? ''}',
      version = '${m['v'] ?? ''}',
      state = '${m['state'] ?? ''}',
      source = '${m['src'] ?? ''}',
      sessions = (m['sessions'] as num?)?.toInt() ?? 0,
      features = {for (final e in ((m['f'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num?)?.toInt() ?? 0};
  final String uid;
  final DateTime? firstSeen, lastSeen;
  final String lang, version, state, source;
  final int sessions;
  final Map<String, int> features;

  List<MapEntry<String, int>> get topFeatures =>
      features.entries.where((e) => !_ignored.contains(e.key)).toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// Counters that describe navigation rather than a feature.
const _ignored = {'app_open', 'root', 'onboarding'};

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
    _ => '$kind ${item ?? ''}',
  };
}

List<Activity> _flatten(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) => [
  for (final d in docs)
    for (final i in (d.data()['items'] as List?) ?? const [])
      if (i is Map) Activity('${d.data()['uid']}', i),
]..sort((a, b) => b.at.compareTo(a.at));

final _installsProvider = FutureProvider.autoDispose<List<Install>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection('installs')
      .orderBy('lastSeen', descending: true)
      .limit(3000)
      .get();
  return [for (final d in snap.docs) Install(d.id, d.data())];
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

// ---------------------------------------------------------------------------------------------
// Dashboard

class _Dashboard extends StatefulWidget {
  const _Dashboard();

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  @override
  void initState() {
    super.initState();
    Usage.rtdb.goOnline();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Devalay admin'),
          actions: [IconButton(tooltip: 'Sign out', onPressed: _signOut, icon: const Icon(Icons.logout_rounded))],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Live'),
              Tab(text: 'Overview'),
              Tab(text: 'Users'),
              Tab(text: 'Feedback'),
            ],
          ),
        ),
        body: const TabBarView(children: [_LiveTab(), _OverviewTab(), _UsersTab(), _FeedbackTab()]),
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
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _events = FirebaseFirestore.instance
      .collection('events')
      .orderBy('at', descending: true)
      .limit(40)
      .snapshots();
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
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _events,
              builder: (context, ev) {
                if (ev.hasError) return _Problem('${ev.error}');
                if (!ev.hasData) return const LinearProgressIndicator();
                final items = _flatten(ev.data!.docs).take(80).toList();
                if (items.isEmpty) return const _Empty('No activity yet.');
                return Column(children: [for (final a in items) _ActivityTile(a, showUser: true)]);
              },
            ),
            const _Section('Recently seen'),
            for (final p in people.where((p) => !p.online).take(30)) _PresenceTile(p),
          ],
        );
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

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_installsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(_installsProvider.future),
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Problem('$e'),
        data: (all) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          bool since(DateTime? t, DateTime from) => t != null && !t.isBefore(from);
          final week = today.subtract(const Duration(days: 6));
          final month = today.subtract(const Duration(days: 29));
          final features = <String, int>{};
          final usersPer = <String, int>{};
          for (final i in all) {
            for (final e in i.features.entries) {
              if (_ignored.contains(e.key)) continue;
              features[e.key] = (features[e.key] ?? 0) + e.value;
              usersPer[e.key] = (usersPer[e.key] ?? 0) + 1;
            }
          }
          final top = features.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          Map<String, int> split(String Function(Install) key) {
            final m = <String, int>{};
            for (final i in all) {
              final k = key(i).isEmpty ? '—' : key(i);
              m[k] = (m[k] ?? 0) + 1;
            }
            return m;
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Wrap(
                children: [
                  _Stat('Installs', '${all.length}'),
                  _Stat('Active today', '${all.where((i) => since(i.lastSeen, today)).length}'),
                  _Stat('Active 7 d', '${all.where((i) => since(i.lastSeen, week)).length}'),
                  _Stat('Active 30 d', '${all.where((i) => since(i.lastSeen, month)).length}'),
                  _Stat('New today', '${all.where((i) => since(i.firstSeen, today)).length}'),
                  _Stat('New 7 d', '${all.where((i) => since(i.firstSeen, week)).length}'),
                ],
              ),
              const _Section('Most used (times · users)'),
              if (top.isEmpty) const _Empty('No usage reported yet. Data starts with version 1.5.3.'),
              for (final e in top.take(30))
                _Bar(e.key, e.value, top.first.value, trailing: '${e.value} · ${usersPer[e.key]}'),
              _Split('Language', split((i) => i.lang)),
              _Split('State', split((i) => i.state)),
              _Split('Version', split((i) => i.version)),
              _Split('Installed from', split((i) => i.source)),
            ],
          );
        },
      ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_installsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(_installsProvider.future),
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Problem('$e'),
        data: (all) => ListView.builder(
          itemCount: all.length,
          itemBuilder: (context, i) {
            final u = all[i];
            final top = u.topFeatures.take(3).map((e) => e.key).join(', ');
            return ListTile(
              title: Text('User ${short(u.uid)} · ${[u.lang, u.state].where((s) => s.isNotEmpty).join(' · ')}'),
              subtitle: Text(
                '${ago(u.lastSeen)} · ${u.sessions} sessions · v${u.version}${top.isEmpty ? '' : '\n$top'}',
              ),
              isThreeLine: top.isNotEmpty,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => openUser(context, u.uid),
            );
          },
        ),
      ),
    );
  }
}

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();

  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  bool _openOnly = true;
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
        final docs = snap.data!.docs.where((d) => !_openOnly || d.data()['done'] != true).toList();
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SwitchListTile(
              title: Text('Open only (${docs.length})'),
              value: _openOnly,
              onChanged: (v) => setState(() => _openOnly = v),
            ),
            if (docs.isEmpty) const _Empty('No feedback.'),
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

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final at = (m['at'] as Timestamp?)?.toDate();
    final done = m['done'] == true;
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => openUser(context, '${m['uid']}'),
                    child: Text(
                      'User ${short('${m['uid']}')} · ${m['lang'] ?? ''} · v${m['v'] ?? ''} · ${at == null ? '' : clock(at)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => doc.reference.update({'done': !done}),
                  child: Text(done ? 'Reopen' : 'Mark done'),
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

class _UserScreen extends StatelessWidget {
  const _UserScreen({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
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
              final u = Install(uid, data);
              final top = u.topFeatures;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    children: [
                      _Stat('Sessions', '${u.sessions}'),
                      _Stat('First seen', u.firstSeen == null ? '—' : clock(u.firstSeen!)),
                      _Stat('Last seen', ago(u.lastSeen)),
                    ],
                  ),
                  Text(
                    [
                      'Language ${u.lang}',
                      if (u.state.isNotEmpty) u.state,
                      'v${u.version}',
                      if (u.source.isNotEmpty) u.source,
                    ].join(' · '),
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
  const _Stat(this.label, this.value, {this.color});
  final String label, value;
  final Color? color;

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
          SizedBox(width: 130, child: Text(label, overflow: TextOverflow.ellipsis)),
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
  const _Split(this.title, this.counts);
  final String title;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final rows = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
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
