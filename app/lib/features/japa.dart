import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/sfx.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/mandala.dart';

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
      if (_count >= 108) {
        _count = 0;
        _rounds++;
        HapticFeedback.heavyImpact();
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

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hi = ref.watch(prefsProvider).language == 'hi';
    final (mantraHi, mantraEn) = _mantras[_mantra];
    return Scaffold(
      backgroundColor: const Color(0xFF1B0D06),
      appBar: AppBar(
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(tr(ref, 'japa'), style: const TextStyle(color: Colors.white)),
        actions: [
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
                  label: Text(hi ? _mantras[i].$1 : _mantras[i].$2),
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
                    SizedBox(width: 320, height: 320, child: CustomPaint(painter: _MalaPainter(_count))),
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
                          Text('/ 108', style: const TextStyle(color: Colors.white54)),
                          const SizedBox(height: 4),
                          Text(
                            hi ? 'माला: $_rounds' : 'Rounds: $_rounds',
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
                hi ? 'जाप करते हुए स्क्रीन पर कहीं भी टैप करें' : 'Tap anywhere for each chant of "$mantraEn"',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _Stat(label: hi ? 'आज' : 'Today', value: '$_today'),
                  _Stat(label: hi ? 'कुल' : 'Lifetime', value: '$_lifetime'),
                  _Stat(label: hi ? 'माला' : 'Rounds', value: '$_rounds'),
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
  _MalaPainter(this.count);
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 10;
    const beads = 108;
    for (var i = 0; i < beads; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / beads;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      final done = i < count;
      final current = i == count;
      canvas.drawCircle(
        p,
        current ? 6.5 : 4.5,
        Paint()
          ..color = current
              ? Palette.gold
              : done
              ? const Color(0xFFFF8F00)
              : const Color(0xFF6D4C41),
      );
    }
    // Meru (guru) bead at the top.
    canvas.drawCircle(c + Offset(0, -r - 14), 9, Paint()..color = Palette.gold);
  }

  @override
  bool shouldRepaint(_MalaPainter old) => old.count != count;
}
