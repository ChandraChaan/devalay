import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../core/admin_stats.dart';
import '../core/storage.dart';
import '../core/theme.dart';

/// The admin screen's Send tab: write a notification in Telugu, English and Hindi (the other
/// languages get the English text), pick who gets it and what a tap opens, check the reach, send it
/// through the sendPush Cloud Function (functions/index.js), and see how each one did.

const _langs = [('te', 'తెలుగు'), ('en', 'English'), ('hi', 'हिन्दी')];

const _links = [
  ('', 'Just open the app'),
  ('devalay://panchang', "Today's Panchang"),
  ('devalay://calendar', 'Calendar & festivals'),
  ('devalay://listen', 'Listen'),
  ('devalay://mandir', 'My Mandir'),
  ('devalay://wishes', 'Festival wishes'),
  ('devalay://muhurtham', 'Muhurtham'),
  ('custom', 'Other link…'),
];

const _audiences = [
  ('all', 'Everyone'),
  ('lang', 'One language'),
  ('state', 'One state'),
  ('version', 'One app version'),
  ('inactive', 'Not seen for some days'),
  ('user', 'One install'),
];

/// Who a campaign went to, in words.
String audienceLabel(Map a) => switch ('${a['type']}') {
  'all' => 'Everyone',
  'lang' => 'Language ${a['value']}',
  'state' => 'State ${a['value']}',
  'version' => 'Version ${a['value']}',
  'inactive' => 'Not seen ${a['value']}+ days',
  'user' => 'Install ${'${a['value']}'.length > 6 ? '${a['value']}'.substring(0, 6) : a['value']}',
  _ => '${a['type']}',
};

/// India time 9 PM to 6 AM, when broadcasts wait (the function refuses them unless forced).
bool quietHoursNow([DateTime? now]) {
  final ist = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 5, minutes: 30));
  return ist.hour >= 21 || ist.hour < 6;
}

class SendTab extends StatefulWidget {
  const SendTab({super.key, required this.installs, this.initialUser});
  final List<InstallRow> installs;
  final String? initialUser;

  @override
  State<SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<SendTab> with AutomaticKeepAliveClientMixin {
  final _name = TextEditingController();
  final _title = {for (final (l, _) in _langs) l: TextEditingController()};
  final _body = {for (final (l, _) in _langs) l: TextEditingController()};
  final _customLink = TextEditingController();
  final _image = TextEditingController();
  final _value = TextEditingController();
  String _link = 'devalay://panchang';
  String _audience = 'user';
  String _preview = 'te';
  int _days = 7;
  bool _force = false;
  bool _busy = false;
  int? _reach;

  /// This phone's own install id (kept from before the admin signed in), for "send to me first".
  final String? _thisPhone = Boxes.prefs.get('usage_first_uid') as String?;

  @override
  void initState() {
    super.initState();
    _value.text = widget.initialUser ?? _thisPhone ?? '';
    for (final c in [..._title.values, ..._body.values]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, ..._title.values, ..._body.values, _customLink, _image, _value]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Map<String, String> _texts(Map<String, TextEditingController> m) => {
    for (final e in m.entries)
      if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
  };

  String get _linkValue => _link == 'custom' ? _customLink.text.trim() : _link;

  String get _audienceValue => switch (_audience) {
    'inactive' => '$_days',
    'all' => '',
    _ => _value.text.trim(),
  };

  Map<String, Object> _request({bool dryRun = false}) => {
    'name': _name.text.trim(),
    'title': _texts(_title),
    'body': _texts(_body),
    'link': _linkValue,
    'image': _image.text.trim(),
    'audience': {'type': _audience, 'value': _audienceValue},
    'dryRun': dryRun,
    'force': _force,
  };

  HttpsCallable get _sendPush => FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('sendPush');

  Future<Map?> _call({required bool dryRun}) async {
    setState(() => _busy = true);
    try {
      final r = await _sendPush.call<Map<String, dynamic>>(_request(dryRun: dryRun));
      return r.data;
    } on FirebaseFunctionsException catch (e) {
      _say(e.message ?? e.code);
      return null;
    } catch (e) {
      _say('$e');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String? get _problem {
    if (_texts(_title).isEmpty) return 'Write a title in at least one language.';
    if (_texts(_body).isEmpty) return 'Write a message in at least one language.';
    if (['state', 'version', 'user', 'lang'].contains(_audience) && _audienceValue.isEmpty) {
      return 'Pick who gets it.';
    }
    return null;
  }

  Future<void> _checkReach() async {
    final r = await _call(dryRun: true);
    if (r != null && mounted) setState(() => _reach = (r['reach'] as num?)?.toInt());
  }

  Future<void> _send() async {
    final problem = _problem;
    if (problem != null) return _say(problem);
    final r = await _call(dryRun: true);
    if (r == null || !mounted) return;
    final reach = (r['reach'] as num?)?.toInt() ?? 0;
    setState(() => _reach = reach);
    final quiet = _audience != 'user' && quietHoursNow();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send this notification?'),
        content: Text(
          [
            '${audienceLabel({'type': _audience, 'value': _audienceValue})} · about $reach install${reach == 1 ? '' : 's'}.',
            if (_audience == 'all' || _audience == 'lang')
              'Sent by topic, so it reaches every phone with Devalay, also those that turned off usage statistics.',
            if (!['all', 'lang'].contains(_audience))
              'Only installs that share usage statistics can be reached one by one.',
            if (quiet && !_force) 'It is quiet hours in India (9 PM–6 AM). Tick "Send anyway" first, or wait.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: quiet && !_force ? null : () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await _call(dryRun: false);
    if (sent == null) return;
    _say('Sent: ${sent['sent']} ok, ${sent['failed']} failed.');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final states = splitBy(widget.installs.where((i) => i.state.isNotEmpty), (i) => i.state).map((e) => e.key).toList();
    final versions = splitBy(widget.installs, (i) => i.version).map((e) => e.key).where((v) => v != '—').toList();
    final quiet = _audience != 'user' && quietHoursNow();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name (for you only, e.g. "Karthika Purnima")'),
        ),
        const SizedBox(height: 12),
        for (final (lang, label) in _langs) ...[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          TextField(
            key: ValueKey('title-$lang'),
            controller: _title[lang],
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            key: ValueKey('body-$lang'),
            controller: _body[lang],
            maxLength: 400,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
        ],
        Text(
          'Tamil, Kannada and the other languages get the English text (or the first one written).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _link,
          decoration: const InputDecoration(labelText: 'A tap opens'),
          items: [for (final (v, l) in _links) DropdownMenuItem(value: v, child: Text(l))],
          onChanged: (v) => setState(() => _link = v ?? ''),
        ),
        if (_link == 'custom')
          TextField(
            controller: _customLink,
            decoration: const InputDecoration(labelText: 'devalay://… or https://…'),
          ),
        TextField(
          controller: _image,
          decoration: const InputDecoration(labelText: 'Picture (optional, https:// link)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _audience,
          decoration: const InputDecoration(labelText: 'Who gets it'),
          items: [for (final (v, l) in _audiences) DropdownMenuItem(value: v, child: Text(l))],
          onChanged: (v) => setState(() {
            _audience = v ?? 'user';
            _reach = null;
            _value.text = switch (_audience) {
              'lang' => 'te',
              'state' => states.firstOrNull ?? '',
              'version' => versions.firstOrNull ?? '',
              'user' => widget.initialUser ?? _thisPhone ?? '',
              _ => '',
            };
          }),
        ),
        switch (_audience) {
          'lang' => DropdownButtonFormField<String>(
            initialValue: _value.text.isEmpty ? 'te' : _value.text,
            decoration: const InputDecoration(labelText: 'Language'),
            items: [
              for (final l in const ['te', 'en', 'hi', 'ta', 'kn', 'ml', 'mr', 'bn', 'gu', 'pa', 'or'])
                DropdownMenuItem(value: l, child: Text(l)),
            ],
            onChanged: (v) => setState(() => _value.text = v ?? 'te'),
          ),
          'state' || 'version' => DropdownButtonFormField<String>(
            initialValue: _value.text.isEmpty ? null : _value.text,
            decoration: InputDecoration(labelText: _audience == 'state' ? 'State' : 'Version'),
            items: [
              for (final v in _audience == 'state' ? states : versions) DropdownMenuItem(value: v, child: Text(v)),
            ],
            onChanged: (v) => setState(() => _value.text = v ?? ''),
          ),
          'inactive' => Row(
            children: [
              const Text('Not seen for'),
              Expanded(
                child: Slider(
                  value: _days.toDouble(),
                  min: 2,
                  max: 30,
                  divisions: 28,
                  label: '$_days days',
                  onChanged: (v) => setState(() => _days = v.round()),
                ),
              ),
              Text('$_days days'),
            ],
          ),
          'user' => Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _value,
                  decoration: const InputDecoration(labelText: 'Install id'),
                ),
              ),
              if (_thisPhone != null)
                TextButton(onPressed: () => setState(() => _value.text = _thisPhone), child: const Text('This phone')),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
        if (quiet)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _force,
            onChanged: (v) => setState(() => _force = v ?? false),
            title: const Text('Send anyway (it is 9 PM–6 AM in India)'),
          ),
        const SizedBox(height: 12),
        _Preview(
          title: _title[_preview]!.text.isNotEmpty ? _title[_preview]!.text : _texts(_title).values.firstOrNull ?? '',
          body: _body[_preview]!.text.isNotEmpty ? _body[_preview]!.text : _texts(_body).values.firstOrNull ?? '',
          lang: _preview,
          onLang: (l) => setState(() => _preview = l),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(onPressed: _busy ? null : _checkReach, child: const Text('Check reach')),
            const SizedBox(width: 12),
            if (_reach != null) Text('about $_reach install${_reach == 1 ? '' : 's'}'),
            const Spacer(),
            FilledButton.icon(
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: const Text('Send'),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text('Sent', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        const CampaignHistory(),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.title, required this.body, required this.lang, required this.onLang});
  final String title, body, lang;
  final ValueChanged<String> onLang;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.temple_hindu_rounded, size: 16, color: Palette.saffron),
                const SizedBox(width: 6),
                Text('Devalay · now', style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [for (final (l, _) in _langs) ButtonSegment(value: l, label: Text(l))],
                  selected: {lang},
                  onSelectionChanged: (s) => onLang(s.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title.isEmpty ? 'Title' : title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(body.isEmpty ? 'Message' : body),
          ],
        ),
      ),
    );
  }
}

/// Past sends with their open rate (opens counted by the app, reach estimated when sent).
class CampaignHistory extends StatefulWidget {
  const CampaignHistory({super.key});

  @override
  State<CampaignHistory> createState() => _CampaignHistoryState();
}

class _CampaignHistoryState extends State<CampaignHistory> {
  late final _stream = FirebaseFirestore.instance
      .collection('campaigns')
      .orderBy('at', descending: true)
      .limit(30)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return Text('${snap.error}', style: const TextStyle(color: Colors.red));
        if (!snap.hasData) return const LinearProgressIndicator();
        if (snap.data!.docs.isEmpty) return const Text('Nothing sent yet.');
        return Column(
          children: [
            for (final d in snap.data!.docs)
              Builder(
                builder: (context) {
                  final m = d.data();
                  final at = (m['at'] as Timestamp?)?.toDate();
                  final title = (m['title'] as Map?)?.values.firstOrNull ?? '';
                  final reach = (m['reach'] as num?)?.toInt() ?? 0;
                  final opens = (m['opens'] as num?)?.toInt() ?? 0;
                  final rate = reach == 0 ? '—' : '${(100 * opens / reach).toStringAsFixed(1)}%';
                  return ListTile(
                    dense: true,
                    title: Text('${(m['name'] as String?)?.isNotEmpty == true ? m['name'] : title}'),
                    subtitle: Text(
                      '${audienceLabel((m['audience'] as Map?) ?? const {})} · '
                      '${at == null ? '' : '${at.day}/${at.month} ${at.hour}:${at.minute.toString().padLeft(2, '0')}'}\n'
                      'sent ${m['sent'] ?? 0}, failed ${m['failed'] ?? 0}, reach ~$reach',
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$opens opens', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(rate, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
