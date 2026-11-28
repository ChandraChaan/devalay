import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/sections.dart';

const premiumGold = [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFE65100)];

/// The small badge on a Premium item: a crown when it is unlocked, a lock when it is not.
class LockBadge extends StatelessWidget {
  const LockBadge({super.key, required this.locked, this.compact = false});
  final bool locked;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: premiumGold),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.lock_rounded : Icons.workspace_premium_rounded,
            size: compact ? 12 : 14,
            color: const Color(0xFF4E1A00),
          ),
          if (!compact) ...[
            const SizedBox(width: 3),
            const Text(
              'PREMIUM',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Color(0xFF4E1A00)),
            ),
          ],
        ],
      ),
    );
  }
}

/// A preview of a locked item: the item itself, readable, under a light diagonal "Devalay Premium"
/// pattern, so the user sees exactly what they would get, but the preview is not worth screenshotting.
class PremiumWatermark extends StatelessWidget {
  const PremiumWatermark({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _WatermarkPainter())),
        ),
      ],
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: '👑 DEVALAY PREMIUM   ',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.28),
          fontSize: math.max(12, size.width / 22),
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 6);
    final diag = math.sqrt(size.width * size.width + size.height * size.height);
    final rowGap = tp.height * 3.2;
    var row = 0;
    for (var y = -diag / 2; y < diag / 2; y += rowGap, row++) {
      final offset = row.isEven ? 0.0 : tp.width / 2;
      for (var x = -diag / 2 - offset; x < diag / 2; x += tp.width) {
        tp.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The call to action under a locked preview. Logs premium_lock_tap with the item and opens Premium.
class UnlockButton extends ConsumerWidget {
  const UnlockButton({super.key, required this.item, this.expanded = true});
  final SectionItem item;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: premiumGold),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF3E1500),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        onPressed: () => openPremiumFor(context, item, log: false),
        icon: const Icon(Icons.workspace_premium_rounded),
        label: Text(
          t3(lang, 'Unlock with Premium', 'प्रीमियम से अनलॉक करें', 'ప్రీమియంతో అన్‌లాక్ చేయండి'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// "Premium collection" heading with a crown, used at the top of each section.
class PremiumCollectionHeader extends ConsumerWidget {
  const PremiumCollectionHeader({super.key, required this.premium});
  final bool premium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(colors: premiumGold).createShader(r),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              t3(lang, 'Premium collection', 'प्रीमियम संग्रह', 'ప్రీమియం కలెక్షన్'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (!premium)
            Text(
              t3(lang, 'Top 5 · Premium', 'टॉप 5 · प्रीमियम', 'టాప్ 5 · ప్రీమియం'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
