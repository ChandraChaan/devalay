import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../core/app_care.dart';
import '../core/billing.dart';
import '../core/i18n.dart';
import '../core/perks.dart';
import '../core/telugu.dart';
import '../core/sfx.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/mandala.dart';
import '../core/usage.dart';

const _mantras = [
  ('ॐ नमः शिवाय', 'Om Namah Shivaya'),
  ('राम', 'Ram'),
  ('हरे कृष्ण', 'Hare Krishna'),
  ('राधे राधे', 'Radhe Radhe'),
  ('ॐ गं गणपतये नमः', 'Om Gan Ganapataye Namah'),
  ('ॐ नमो भगवते वासुदेवाय', 'Om Namo Bhagavate Vasudevaya'),
  ('ॐ', 'Om'),
  ('गायत्री मंत्र', 'Gayatri Mantra'),
];

/// Digital japa mala: 108 beads per round, haptic tick per bead and a bell on
/// completing a round. Counts are stored on the device only.
class JapaScreen extends ConsumerStatefulWidget {
  const JapaScreen({super.key});
  @override
  ConsumerState<JapaScreen> createState() => _JapaScreenState();
}

class _JapaScreenState extends ConsumerState<JapaScreen> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  int _mantra = Boxes.stats.get('japa_mantra', defaultValue: 0) as int;
  int _count = Boxes.stats.get('japa_count', defaultValue: 0) as int;
  int _rounds = Boxes.stats.get('japa_rounds', defaultValue: 0) as int;
  bool _sound = Boxes.stats.get('japa_sound', defaultValue: true) as bool;
  MalaStyle _malaChoice = Perks.mala;
  int _sizeChoice = Perks.malaSize;

  bool get _premium => ref.read(premiumProvider);
  MalaStyle get _mala =>
      unlocked(_malaChoice, isPremiumItem: _malaChoice.premium, premium: _premium, free: MalaStyle.rudraksha);
  int get _size => unlocked(_sizeChoice, isPremiumItem: malaSizePremium(_sizeChoice), premium: _premium, free: 108);

  String get _todayKey {
    final now = DateTime.now();
    return 'japa_day_${now.year}-${now.month}-${now.day}';
  }

  int get _today => Boxes.stats.get(_todayKey, defaultValue: 0) as int;
  int get _lifetime => Boxes.stats.get('japa_total', defaultValue: 0) as int;

  void _tap() {
    _pulse.forward(from: 0);
    setState(() {
      _count++;
      if (_count >= _size) {
        _count = 0;
        _rounds++;
        Usage.record('japa_round');
        HapticFeedback.heavyImpact();
        // A finished mala is a good moment; Play's own limits decide whether the card shows.
        Future.delayed(const Duration(seconds: 3), () => maybeAskForReview(happy: true));
        if (_sound) Sfx.play('temple-bell');
      } else {
        HapticFeedback.selectionClick();
      }
    });
    Boxes.stats.putAll({
      'japa_count': _count,
      'japa_rounds': _rounds,
      _todayKey: _today + 1,
      'japa_total': _lifetime + 1,
    });
  }

  void _reset() {
    setState(() {
      _count = 0;
      _rounds = 0;
    });
    Boxes.stats.putAll({'japa_count': 0, 'japa_rounds': 0});
  }

  Future<void> _openMalaSheet() async {
    final premium = _premium;
    final lang = ref.read(prefsProvider).language;
    final picked = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF24110A),
      builder: (_) => _MalaSheet(lang: lang, premium: premium, mala: _mala, size: _size),
    );
    if (picked == null || !mounted) return;
    final locked = switch (picked) {
      MalaStyle m => m.premium,
      int n => malaSizePremium(n),
      _ => false,
    };
    if (locked && !premium) {
      context.push('/premium?from=japa');
      return;
    }
    if (picked is MalaStyle) {
      Usage.record('mala_set', item: picked.name);
      setState(() => _malaChoice = picked);
      unawaited(Perks.setMala(picked));
    } else if (picked is int) {
      Usage.record('mala_size_set', item: '$picked');
      unawaited(Perks.setMalaSize(picked));
      // A shorter round starts afresh rather than finishing at once.
      setState(() {
        _sizeChoice = picked;
        if (_count >= picked) _count = 0;
      });
      Boxes.stats.put('japa_count', _count);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider).language;
    ref.watch(premiumProvider);
    final (mantraHi, mantraEn) = _mantras[_mantra];
    final mala = _mala;
    final size = _size;
    return Scaffold(
      backgroundColor: const Color(0xFF1B0D06),
      appBar: AppBar(
        foregroundColor: Colors.white,
        systemOverlayStyle: lightBars,
        title: Text(tr(ref, 'japa'), style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: _openMalaSheet,
            tooltip: t3(lang, 'Mala', 'माला', 'మాల'),
            icon: const Icon(Icons.blur_circular_rounded),
          ),
          IconButton(
            onPressed: () {
              setState(() => _sound = !_sound);
              Boxes.stats.put('japa_sound', _sound);
            },
            icon: Icon(_sound ? Icons.volume_up_rounded : Icons.volume_off_rounded),
          ),
          IconButton(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _mantras.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(t3(lang, _mantras[i].$2, _mantras[i].$1, toTeluguScript(_mantras[i].$1))),
                  selected: _mantra == i,
                  onSelected: (_) {
                    setState(() => _mantra = i);
                    Boxes.stats.put('japa_mantra', i);
                  },
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tap,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Mandala(size: 340, color: Palette.gold, opacity: 0.12),
                    SizedBox(width: 320, height: 320, child: CustomPaint(painter: _MalaPainter(_count, size, mala))),
                    ScaleTransition(
                      scale: Tween(
                        begin: 1.0,
                        end: 0.94,
                      ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mantraHi,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: scriptureFont, color: Palette.gold, fontSize: 22),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$_count',
                            style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.w700),
                          ),
                          Text('/ $size', style: const TextStyle(color: Colors.white54)),
                          const SizedBox(height: 4),
                          Text(
                            t3(lang, 'Rounds: $_rounds', 'माला: $_rounds', 'మాలలు: $_rounds'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                t3(
                  lang,
                  'Tap anywhere for each chant of "$mantraEn"',
                  'जाप करते हुए स्क्रीन पर कहीं भी टैप करें',
                  'ప్రతి జపానికి స్క్రీన్‌పై ఎక్కడైనా తాకండి',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _Stat(label: t3(lang, 'Today', 'आज', 'ఈ రోజు'), value: '$_today'),
                  _Stat(label: t3(lang, 'Lifetime', 'कुल', 'మొత్తం'), value: '$_lifetime'),
                  _Stat(label: t3(lang, 'Rounds', 'माला', 'మాలలు'), value: '$_rounds'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        Text(label, style: const TextStyle(color: Colors.white54)),
      ],
    ),
  );
}

class _MalaPainter extends CustomPainter {
  _MalaPainter(this.count, this.beads, this.style);
  final int count, beads;
  final MalaStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 10;
    final radius = beads > 60 ? 4.5 : 6.5;
    for (var i = 0; i < beads; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / beads;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      final done = i < count;
      final current = i == count;
      canvas.drawCircle(
        p,
        current ? radius + 2 : radius,
        Paint()
          ..color = current
              ? Palette.gold
              : done
              ? style.done
              : style.bead,
      );
    }
    // Meru (guru) bead at the top.
    canvas.drawCircle(c + Offset(0, -r - 14), 9, Paint()..color = Palette.gold);
  }

  @override
  bool shouldRepaint(_MalaPainter old) => old.count != count || old.beads != beads || old.style != style;
}

/// Mala beads and round length; Premium ones carry a crown.
class _MalaSheet extends StatelessWidget {
  const _MalaSheet({required this.lang, required this.premium, required this.mala, required this.size});
  final String lang;
  final bool premium;
  final MalaStyle mala;
  final int size;

  @override
  Widget build(BuildContext context) {
    Widget crown(bool locked) => locked && !premium ? const Text(' 👑') : const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t3(lang, 'Mala beads', 'माला के मनके', 'మాల పూసలు'),
              style: const TextStyle(color: Palette.gold, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in MalaStyle.values)
                  ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: m.done, radius: 8),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text(t3(lang, m.en, m.hi, m.te)), crown(m.premium)],
                    ),
                    selected: m == mala,
                    onSelected: (_) => Navigator.pop(context, m),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              t3(lang, 'Beads per round', 'एक माला में मनके', 'ఒక మాలలో పూసలు'),
              style: const TextStyle(color: Palette.gold, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final n in malaSizes)
                  ChoiceChip(
                    label: Row(mainAxisSize: MainAxisSize.min, children: [Text('$n'), crown(malaSizePremium(n))]),
                    selected: n == size,
                    onSelected: (_) => Navigator.pop(context, n),
                  ),
              ],
            ),
            if (!premium) ...[
              const SizedBox(height: 14),
              Text(
                t3(
                  lang,
                  '👑 malas and shorter rounds come with Premium.',
                  '👑 वाली मालाएँ और छोटी माला प्रीमियम के साथ मिलती हैं।',
                  '👑 ఉన్న మాలలు, చిన్న మాలలు ప్రీమియంతో వస్తాయి.',
                ),
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
