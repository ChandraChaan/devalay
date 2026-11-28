import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/billing.dart';
import '../core/i18n.dart';
import '../core/sections.dart';
import '../core/sfx.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';
import '../widgets/premium_lock.dart';
import 'section_common.dart';

/// Meditation: pick a soundscape, a length and a breathing rhythm, then sit. A temple bell opens and
/// closes the session; the breathing circle grows and settles with the breath. Soundscapes are Devalay's
/// own seamless loops (CC0); the five Premium ones carry a lock.
class MeditationScreen extends ConsumerStatefulWidget {
  const MeditationScreen({super.key});
  @override
  ConsumerState<MeditationScreen> createState() => _MeditationScreenState();
}

/// Inhale, hold, exhale, hold, in seconds.
typedef BreathPattern = ({String id, String en, String hi, String te, List<int> phases});

const breathPatterns = <BreathPattern>[
  (id: 'calm', en: 'Calm 4·4·6', hi: 'शांत 4·4·6', te: 'ప్రశాంతం 4·4·6', phases: [4, 4, 6, 0]),
  (id: 'box', en: 'Box 4·4·4·4', hi: 'बॉक्स 4·4·4·4', te: 'బాక్స్ 4·4·4·4', phases: [4, 4, 4, 4]),
  (id: 'sleep', en: 'Sleep 4·7·8', hi: 'नींद 4·7·8', te: 'నిద్ర 4·7·8', phases: [4, 7, 8, 0]),
  (id: 'free', en: 'Free', hi: 'मुक्त', te: 'స్వేచ్ఛ', phases: []),
];

const meditationMinutes = [5, 10, 15, 20, 30];

/// The phase (0 inhale, 1 hold, 2 exhale, 3 hold) and how far into it, [elapsed] seconds into a session.
({int phase, double t}) breathPhase(List<int> phases, double elapsed) {
  final cycle = phases.fold<int>(0, (a, b) => a + b);
  if (cycle == 0) return (phase: -1, t: 0);
  var at = elapsed % cycle;
  for (var i = 0; i < phases.length; i++) {
    if (phases[i] == 0) continue;
    if (at < phases[i]) return (phase: i, t: at / phases[i]);
    at -= phases[i];
  }
  return (phase: 0, t: 0);
}

const _soundLooks = <String, (String, List<Color>)>{
  'om-deep': ('🕉️', [Color(0xFF4A148C), Color(0xFFE65100)]),
  'tanpura-sa': ('🪕', [Color(0xFF5D4037), Color(0xFFBF8F00)]),
  'rain-temple-bells': ('🌧️', [Color(0xFF263238), Color(0xFF546E7A)]),
  'river-flute': ('🎶', [Color(0xFF00695C), Color(0xFF26A69A)]),
  'himalaya-om': ('🏔️', [Color(0xFF1A237E), Color(0xFF5C6BC0)]),
  'singing-bowls': ('🔔', [Color(0xFF6D4C41), Color(0xFFFFB300)]),
  'ocean-om': ('🌊', [Color(0xFF01579B), Color(0xFF00ACC1)]),
  'veena-alap': ('🎵', [Color(0xFF880E4F), Color(0xFFF06292)]),
  'night-diya': ('🌙', [Color(0xFF0D0D2B), Color(0xFF3949AB)]),
  'dawn-birds': ('🌅', [Color(0xFFFF7043), Color(0xFFFFCA28)]),
  'flute-dawn': ('🌅', [Color(0xFFFF7043), Color(0xFFFFCA28)]),
};

class _MeditationScreenState extends ConsumerState<MeditationScreen> {
  String? _sound = Boxes.prefs.get('meditation_sound') as String?;
  int _minutes = Boxes.prefs.get('meditation_minutes', defaultValue: 10) as int;
  String _pattern = Boxes.prefs.get('meditation_breath', defaultValue: 'calm') as String;

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final premium = ref.watch(premiumProvider);
    final sounds = ref.watch(sectionsProvider).value?.meditation ?? const <MeditationSound>[];
    final chosen =
        sounds.where((s) => s.id == _sound && !isLocked(s, premium: premium)).firstOrNull ??
        sounds.where((s) => !isLocked(s, premium: premium)).firstOrNull;
    final done = Boxes.stats.get('meditation_minutes_total', defaultValue: 0) as int;
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'ambient'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24).withSystemInsets(context),
        children: [
          GradientCard(
            colors: const [Color(0xFF1A237E), Color(0xFF4A148C), Color(0xFF00838F)],
            child: Row(
              children: [
                const Text('🧘', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t3(
                          lang,
                          'Sit, breathe, be still',
                          'बैठें, साँस लें, शांत हों',
                          'కూర్చోండి, శ్వాస తీసుకోండి, ప్రశాంతంగా ఉండండి',
                        ),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      if (done > 0)
                        Text(
                          t3(lang, '$done minutes so far', 'अब तक $done मिनट', 'ఇప్పటివరకు $done నిమిషాలు'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(t3(lang, 'Soundscape', 'ध्वनि', 'శబ్ద వాతావరణం')),
          if (sounds.isEmpty)
            const SkeletonBox(height: 120)
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                for (final s in sounds)
                  _SoundCard(
                    sound: s,
                    selected: chosen?.id == s.id,
                    locked: isLocked(s, premium: premium),
                    onTap: () {
                      if (isLocked(s, premium: premium)) {
                        openPremiumFor(context, s);
                        return;
                      }
                      setState(() => _sound = s.id);
                      Boxes.prefs.put('meditation_sound', s.id);
                    },
                  ),
              ],
            ),
          SectionHeader(t3(lang, 'Minutes', 'मिनट', 'నిమిషాలు')),
          Wrap(
            spacing: 8,
            children: [
              for (final m in meditationMinutes)
                ChoiceChip(
                  label: Text('$m'),
                  selected: _minutes == m,
                  onSelected: (_) {
                    setState(() => _minutes = m);
                    Boxes.prefs.put('meditation_minutes', m);
                  },
                ),
            ],
          ),
          SectionHeader(t3(lang, 'Breathing', 'श्वास', 'శ్వాస')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in breathPatterns)
                ChoiceChip(
                  label: Text(t3(lang, p.en, p.hi, p.te)),
                  selected: _pattern == p.id,
                  onSelected: (_) {
                    setState(() => _pattern = p.id);
                    Boxes.prefs.put('meditation_breath', p.id);
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: chosen == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => MeditationSession(
                        sound: chosen,
                        minutes: _minutes,
                        pattern: breathPatterns.firstWhere((p) => p.id == _pattern),
                      ),
                    ),
                  ),
            icon: const Icon(Icons.self_improvement_rounded),
            label: Text(
              t3(lang, 'Begin', 'आरंभ करें', 'ప్రారంభించండి'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          if (chosen != null) Padding(padding: const EdgeInsets.only(top: 8), child: CreditLine(chosen.credit)),
        ],
      ),
    );
  }
}

class _SoundCard extends ConsumerWidget {
  const _SoundCard({required this.sound, required this.selected, required this.locked, required this.onTap});
  final MeditationSound sound;
  final bool selected, locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final (emoji, colors) = _soundLooks[sound.id] ?? ('🕉️', Palette.dusk);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 3),
          boxShadow: selected ? const [BoxShadow(color: Colors.black38, blurRadius: 10)] : null,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                sound.title.of(lang),
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.15),
              ),
            ),
            if (sound.isPremium) Positioned(top: 0, right: 0, child: LockBadge(locked: locked, compact: true)),
            if (selected)
              const Positioned(
                bottom: 0,
                right: 0,
                child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

/// The sitting itself: the soundscape on a loop, a bell at the start and the end, and the breath.
class MeditationSession extends ConsumerStatefulWidget {
  const MeditationSession({super.key, required this.sound, required this.minutes, required this.pattern});
  final MeditationSound sound;
  final int minutes;
  final BreathPattern pattern;
  @override
  ConsumerState<MeditationSession> createState() => _MeditationSessionState();
}

class _MeditationSessionState extends ConsumerState<MeditationSession> with SingleTickerProviderStateMixin {
  final _player = ap.AudioPlayer(playerId: 'meditation');
  late final _ticker = createTicker(_tick);
  final _clock = Stopwatch();
  Duration _elapsed = Duration.zero;
  bool _paused = false;
  bool _finished = false;
  String? _error;

  int get _total => widget.minutes * 60;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    unawaited(WakelockPlus.enable());
    unawaited(Sfx.play('temple-bell', volume: 0.8));
    Usage.record('meditation_start', item: '${widget.sound.id}:${widget.minutes}');
    _clock.start();
    _ticker.start();
    try {
      final f = await SectionFiles.get(widget.sound.audio);
      ref.read(sectionDownloadsTick.notifier).bump();
      await _player.setAudioContext(ap.AudioContextConfig(focus: ap.AudioContextConfigFocus.gain).build());
      await _player.setReleaseMode(ap.ReleaseMode.loop);
      await _player.setVolume(0);
      if (!mounted || _finished) return;
      await _player.play(ap.DeviceFileSource(f.path));
      for (var v = 1; v <= 10 && mounted && !_paused; v++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await _player.setVolume(v / 10);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _tick(Duration _) {
    if (_paused || _finished) return;
    setState(() => _elapsed = _clock.elapsed);
    if (_elapsed.inSeconds >= _total) _finish();
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _clock.stop();
        _player.pause();
      } else {
        _clock.start();
        _player.resume();
      }
    });
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _ticker.stop();
    _clock.stop();
    unawaited(Sfx.play('temple-bell'));
    HapticFeedback.mediumImpact();
    final minutes = (_elapsed.inSeconds / 60).round();
    Usage.record('meditation_done', item: '${widget.sound.id}:$minutes');
    await Boxes.stats.put(
      'meditation_minutes_total',
      (Boxes.stats.get('meditation_minutes_total', defaultValue: 0) as int) + minutes,
    );
    for (var v = 9; v >= 0; v--) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _player.setVolume(v / 10);
    }
    await _player.stop();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _player.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final left = Duration(seconds: math.max(0, _total - _elapsed.inSeconds));
    final breath = breathPhase(widget.pattern.phases, _elapsed.inMilliseconds / 1000);
    // Circle size: grows on the in-breath, stays full on the hold, settles on the out-breath.
    final grow = switch (breath.phase) {
      0 => Curves.easeInOut.transform(breath.t),
      1 => 1.0,
      2 => 1 - Curves.easeInOut.transform(breath.t),
      3 => 0.0,
      _ => 0.5 + 0.08 * math.sin(_elapsed.inMilliseconds / 900),
    };
    final cue = switch (breath.phase) {
      0 => t3(lang, 'Breathe in', 'साँस लें', 'శ్వాస తీసుకోండి'),
      1 || 3 => t3(lang, 'Hold', 'रोकें', 'ఆపండి'),
      2 => t3(lang, 'Breathe out', 'साँस छोड़ें', 'శ్వాస వదలండి'),
      _ => '',
    };
    final (_, colors) = _soundLooks[widget.sound.id] ?? ('', Palette.dusk);
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: lightBars,
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: 1.2,
              colors: [colors.first.withValues(alpha: 0.85), Colors.black],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                    const Spacer(),
                    Text(widget.sound.title.of(lang), style: const TextStyle(color: Colors.white70)),
                    const SizedBox(width: 16),
                  ],
                ),
                const Spacer(),
                if (_finished) ...[
                  const Text('🙏', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text(
                    t3(lang, 'Om Shanti Shanti Shantihi', 'ॐ शान्तिः शान्तिः शान्तिः', 'ఓం శాంతిః శాంతిః శాంతిః'),
                    style: const TextStyle(color: Palette.gold, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t3(
                      lang,
                      '${widget.minutes} minutes of stillness',
                      '${widget.minutes} मिनट की शांति',
                      '${widget.minutes} నిమిషాల ప్రశాంతత',
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ] else
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140 + 150 * grow,
                          height: 140 + 150 * grow,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Colors.white.withValues(alpha: 0.35), colors.last.withValues(alpha: 0.15)],
                            ),
                            boxShadow: [
                              BoxShadow(color: colors.last.withValues(alpha: 0.5), blurRadius: 40 + 40 * grow),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cue,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                            Text(formatDuration(left), style: const TextStyle(color: Colors.white70, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      t3(
                        lang,
                        'The soundscape needs the internet the first time. The timer and breath still work.',
                        'पहली बार ध्वनि के लिए इंटरनेट चाहिए। टाइमर और श्वास फिर भी चलेंगे।',
                        'మొదటిసారి శబ్దం కోసం ఇంటర్నెట్ కావాలి. టైమర్, శ్వాస పనిచేస్తాయి.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _finished
                      ? FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(t3(lang, 'Done', 'पूर्ण', 'పూర్తి')),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filledTonal(
                              iconSize: 32,
                              onPressed: _togglePause,
                              icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                            ),
                            const SizedBox(width: 16),
                            TextButton(
                              onPressed: _finish,
                              child: Text(
                                t3(lang, 'End now', 'अभी समाप्त करें', 'ఇప్పుడే ముగించండి'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
