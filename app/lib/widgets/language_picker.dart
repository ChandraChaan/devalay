import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/languages.dart';
import '../core/storage.dart';
import '../core/theme.dart';

/// Every app language as a two-column grid of native names. [onDark] draws it for the saffron
/// onboarding background; otherwise it follows the app theme.
class LanguageGrid extends ConsumerWidget {
  const LanguageGrid({super.key, this.onDark = false, this.onPicked});
  final bool onDark;
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(prefsProvider.select((p) => p.language));
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth > 560 ? 3 : 2;
        final w = (box.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, l) in appLanguages.indexed)
              SizedBox(
                width: w,
                child: _Tile(
                  language: l,
                  selected: l.code == current,
                  onDark: onDark,
                  scheme: scheme,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await ref.read(prefsProvider.notifier).setLanguage(l.code);
                    onPicked?.call();
                  },
                ).animate(delay: (30 * i).ms).fadeIn(duration: 250.ms).slideY(begin: 0.15, curve: Curves.easeOut),
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.language,
    required this.selected,
    required this.onDark,
    required this.scheme,
    required this.onTap,
  });
  final AppLanguage language;
  final bool selected, onDark;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : scheme.onSurface;
    final accent = onDark ? Palette.gold : scheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: selected && !onDark ? const LinearGradient(colors: Palette.sunrise) : null,
        color: selected
            ? (onDark ? Colors.white.withValues(alpha: 0.18) : null)
            : (onDark ? Colors.white.withValues(alpha: 0.06) : scheme.surfaceContainerLow),
        border: Border.all(
          color: selected ? accent : (onDark ? Colors.white24 : scheme.outlineVariant),
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: selected && !onDark
            ? [BoxShadow(color: Palette.saffron.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.native,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: selected && !onDark ? Colors.white : fg,
                        ),
                      ),
                      Text(
                        language.english,
                        style: TextStyle(
                          fontSize: 12,
                          color: (selected && !onDark ? Colors.white : fg).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(Icons.check_circle_rounded, color: onDark ? Palette.gold : Colors.white, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The language picker as a sheet, from Settings.
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) {
  final lang = ref.read(prefsProvider).language;
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t3(lang, 'Language', 'भाषा', 'భాష'),
              style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              t3(
                lang,
                'The whole app, the Panchang and festival names change to your language.',
                'पूरा ऐप, पंचांग और त्योहारों के नाम आपकी भाषा में।',
                'యాప్ మొత్తం, పంచాంగం, పండుగల పేర్లు మీ భాషలో.',
              ),
              style: Theme.of(c).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            LanguageGrid(onPicked: () => Navigator.of(c).pop()),
          ],
        ),
      ),
    ),
  );
}
