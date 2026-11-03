import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/mandala.dart';

const _deityOptions = [
  'shiva',
  'hanuman',
  'rama',
  'krishna',
  'radha-krishna',
  'ganesha',
  'durga',
  'kali',
  'lakshmi',
  'saraswati',
  'vishnu',
  'shani',
  'surya',
  'general',
];
const _occasions = {
  'daily': ('Daily', 'दैनिक', 'రోజువారీ'),
  'good-morning': ('Good morning', 'सुप्रभात', 'శుభోదయం'),
  'good-night': ('Good night', 'शुभ रात्रि', 'శుభ రాత్రి'),
  'monday': ('Monday', 'सोमवार', 'సోమవారం'),
  'tuesday': ('Tuesday', 'मंगलवार', 'మంగళవారం'),
  'saturday': ('Saturday', 'शनिवार', 'శనివారం'),
  'festival': ('Festival', 'त्योहार', 'పండుగ'),
  'birthday': ('Birthday', 'जन्मदिन', 'పుట్టినరోజు'),
  'anniversary': ('Anniversary', 'वर्षगांठ', 'పెళ్లిరోజు'),
  'gratitude': ('Gratitude', 'आभार', 'కృతజ్ఞత'),
  'strength': ('Strength', 'शक्ति', 'శక్తి'),
  'peace': ('Peace', 'शांति', 'శాంతి'),
};

class StatusMakerScreen extends ConsumerStatefulWidget {
  const StatusMakerScreen({super.key});
  @override
  ConsumerState<StatusMakerScreen> createState() => _StatusMakerScreenState();
}

class _StatusMakerScreenState extends ConsumerState<StatusMakerScreen> {
  String _deity = Boxes.prefs.get('ishta', defaultValue: 'general') as String;
  String _occasion = 'daily';
  late String _lang = ref.read(prefsProvider).language;
  final _name = TextEditingController();
  final _festival = TextEditingController();
  bool _loading = false;
  List<Map> _options = const [];
  String? _provider;
  int? _remaining;

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final r =
          await ref
                  .read(apiProvider)
                  .post(
                    '/ai/status',
                    data: {
                      'deity': _deity,
                      'occasion': _occasion,
                      'language': _lang,
                      if (_name.text.trim().isNotEmpty) 'name': _name.text.trim(),
                      if (_occasion == 'festival' && _festival.text.trim().isNotEmpty)
                        'festival': _festival.text.trim(),
                    },
                  )
              as Map;
      setState(() {
        _options = (r['options'] as List).cast<Map>();
        _provider = r['provider'] as String?;
        _remaining = r['remaining_today'] as int?;
      });
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider).language;
    final deities = ref.watch(deitiesProvider).value ?? const <Deity>[];
    String deityName(String slug) {
      final d = deities.where((d) => d.slug == slug).firstOrNull;
      if (slug == 'radha-krishna') return t3(lang, 'Radha Krishna', 'राधा कृष्ण', 'రాధాకృష్ణులు');
      return d == null ? slug : (d.label(lang));
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'ai_status'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t3(lang, 'Deity', 'देवता', 'దైవం'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _deityOptions)
                ChoiceChip(
                  label: Text(deityName(d)),
                  selected: _deity == d,
                  onSelected: (_) => setState(() => _deity = d),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(t3(lang, 'Occasion', 'अवसर', 'సందర్భం'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _occasions.entries)
                ChoiceChip(
                  label: Text(t3(lang, e.value.$1, e.value.$2, e.value.$3)),
                  selected: _occasion == e.key,
                  onSelected: (_) => setState(() => _occasion = e.key),
                ),
            ],
          ),
          if (_occasion == 'festival') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _festival,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: t3(
                  lang,
                  'Festival name, e.g. Diwali',
                  'त्योहार का नाम, जैसे दीपावली',
                  'పండుగ పేరు, ఉదా. దీపావళి',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            maxLength: 40,
            decoration: InputDecoration(
              hintText: t3(lang, 'For whom? (optional)', 'किसके लिए? (वैकल्पिक)', 'ఎవరి కోసం? (ఐచ్ఛికం)'),
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'te', label: Text('తెలుగు')),
              ButtonSegment(value: 'hi', label: Text('हिन्दी')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {_lang},
            onSelectionChanged: (s) => setState(() => _lang = s.first),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(t3(lang, 'Create status', 'स्टेटस बनाएँ', 'స్టేటస్ తయారు చేయండి')),
          ),
          if (_remaining != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_provider == 'claude' ? 'AI' : (t3(lang, 'Offline', 'ऑफ़लाइन', 'ఆఫ్‌లైన్'))} · ${t3(lang, 'left today', 'आज शेष', 'ఈ రోజు మిగిలినవి')}: $_remaining',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          for (final (i, o) in _options.indexed)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                title: Text('${o['text']}', style: const TextStyle(fontSize: 17, height: 1.4)),
                subtitle: Text((o['hashtags'] as List).join(' ')),
                trailing: const Icon(Icons.brush_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StatusComposer(text: '${o['text']}', deity: _deity),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: (120 * i).ms).slideY(begin: 0.15),
        ],
      ),
    );
  }
}

/// Composes the status text over sacred art and exports it as a 1080x1920 image.
class StatusComposer extends ConsumerStatefulWidget {
  const StatusComposer({super.key, required this.text, required this.deity});
  final String text;
  final String deity;
  @override
  ConsumerState<StatusComposer> createState() => _StatusComposerState();
}

class _StatusComposerState extends ConsumerState<StatusComposer> {
  final _boundary = GlobalKey();
  int _bg = 0;
  bool _busy = false;
  static const _gradients = [
    Palette.sunrise,
    Palette.dusk,
    Palette.sky,
    Palette.tulsi,
    [Color(0xFF212121), Color(0xFF5D4037)],
  ];

  Future<File> _render() async {
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final file = File(
      '${(await getTemporaryDirectory()).path}/devalay-status-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    return file.writeAsBytes(bytes);
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final f = await _render();
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: widget.text));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final f = await _render();
      await NativeBridge.saveImage(f.path, f.uri.pathSegments.last);
      HapticFeedback.mediumImpact();
      if (mounted) toast(context, 'Saved to Pictures/Devalay');
    } catch (e) {
      if (mounted) toast(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walls =
        ref
            .watch(
              wallpapersProvider(widget.deity == 'general' || widget.deity == 'radha-krishna' ? null : widget.deity),
            )
            .value ??
        const <Wallpaper>[];
    final backgrounds = [
      for (final g in _gradients) ('g', g, ''),
      for (final w in walls.take(6)) ('w', const <Color>[], w.imageUrl),
    ];
    final current = backgrounds[_bg.clamp(0, backgrounds.length - 1)];
    return Scaffold(
      appBar: AppBar(title: const Text('Status')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: RepaintBoundary(
                  key: _boundary,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (current.$1 == 'g')
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: current.$2,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          )
                        else
                          NetImage(current.$3),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.65)],
                            ),
                          ),
                        ),
                        const Positioned(
                          top: -60,
                          right: -60,
                          child: Mandala(size: 260, color: Palette.gold, opacity: 0.3),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Text(
                                'ॐ',
                                style: TextStyle(fontFamily: scriptureFont, fontSize: 40, color: Palette.gold),
                              ),
                              const Spacer(),
                              Text(
                                    widget.text,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      height: 1.45,
                                      fontWeight: FontWeight.w700,
                                      shadows: [Shadow(blurRadius: 12, color: Colors.black)],
                                    ),
                                  )
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .shimmer(duration: 2400.ms, color: Palette.gold.withValues(alpha: 0.6)),
                              const SizedBox(height: 24),
                              const Text('🪔 Devalay', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: backgrounds.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _bg = i),
                child: Container(
                  width: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: i == _bg ? Palette.saffron : Colors.transparent, width: 3),
                    gradient: backgrounds[i].$1 == 'g' ? LinearGradient(colors: backgrounds[i].$2) : null,
                  ),
                  child: backgrounds[i].$1 == 'w' ? NetImage(backgrounds[i].$3, radius: 7) : null,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
