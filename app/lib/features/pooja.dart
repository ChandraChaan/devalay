import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n.dart';
import '../core/pooja.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// The list of pooja vidhanam guides.
class PoojaGuidesScreen extends ConsumerWidget {
  const PoojaGuidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final guides = ref.watch(poojaGuidesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'pooja_guides'))),
      body: guides.when(
        loading: () => const LoadingList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(poojaGuidesProvider)),
        data: (all) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                t3(
                  lang,
                  'Simple step-by-step guides with the items to keep ready and the mantras to chant.',
                  'तैयार रखने वाली सामग्री और जपने वाले मंत्रों के साथ सरल चरण-दर-चरण विधि।',
                  'సిద్ధం చేసుకోవాల్సిన సామగ్రి, జపించాల్సిన మంత్రాలతో సులభమైన దశలవారీ విధానం.',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            for (final (i, g) in all.guides.indexed)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Text(g.emoji, style: const TextStyle(fontSize: 30)),
                  title: Text(g.title(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(g.summary(lang)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/pooja/${g.id}'),
                ),
              ).animate().fadeIn(delay: (40 * i).ms),
          ],
        ),
      ),
    );
  }
}

/// One guide: when to do it, the samagri checklist and the steps with their mantras.
class PoojaGuideScreen extends ConsumerWidget {
  const PoojaGuideScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final guides = ref.watch(poojaGuidesProvider);
    final guide = guides.value?.byId(id);
    if (guide == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(ref, 'pooja_guides'))),
        body: guides.isLoading
            ? const LoadingList()
            : EmptyState(
                icon: Icons.menu_book_rounded,
                title: t3(lang, 'Guide not found', 'विधि नहीं मिली', 'విధానం దొరకలేదు'),
              ),
      );
    }
    final checks = ref.watch(samagriChecksProvider)[guide.id] ?? const <int>{};
    final items = guide.samagri(lang);
    final steps = guide.steps;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(guide.title(lang))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          GradientCard(
            colors: Palette.sunrise,
            child: Row(
              children: [
                Text(guide.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide.summary(lang),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${t3(lang, 'When', 'कब', 'ఎప్పుడు')}: ${guide.when(lang)}',
                        style: const TextStyle(color: Colors.white, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SectionHeader(
            t3(lang, 'Samagri (items)', 'पूजा सामग्री', 'పూజా సామగ్రి'),
            action: checks.isEmpty ? null : t3(lang, 'Clear', 'साफ़ करें', 'తీసివేయండి'),
            onAction: () => ref.read(samagriChecksProvider.notifier).clear(guide.id),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              checks.length == items.length
                  ? t3(lang, 'Everything is ready 🙏', 'सब तैयार है 🙏', 'అంతా సిద్ధం 🙏')
                  : t3(
                      lang,
                      '${checks.length} of ${items.length} ready',
                      '${items.length} में से ${checks.length} तैयार',
                      '${items.length}లో ${checks.length} సిద్ధం',
                    ),
              style: TextStyle(color: primary, fontWeight: FontWeight.w600),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final (i, item) in items.indexed)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: checks.contains(i),
                    title: Text(
                      item,
                      style: checks.contains(i)
                          ? TextStyle(decoration: TextDecoration.lineThrough, color: theme.disabledColor)
                          : null,
                    ),
                    onChanged: (_) {
                      HapticFeedback.selectionClick();
                      ref.read(samagriChecksProvider.notifier).toggle(guide.id, i);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SectionHeader(t3(lang, 'Steps', 'विधि', 'విధానం')),
          for (final (i, s) in steps.indexed)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: primary,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title(lang),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(s.text(lang), style: const TextStyle(height: 1.5)),
                          if (s.mantra case final m?) _MantraBox(mantra: m, lang: lang),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            t3(
              lang,
              'Customs differ between families and regions. Where your elders or priest do it differently, follow them.',
              'परिवारों और क्षेत्रों में रीतियाँ अलग होती हैं। जहाँ आपके बड़े या पुरोहित अलग तरह से करते हों, उन्हीं का पालन करें।',
              'కుటుంబాలు, ప్రాంతాలను బట్టి ఆచారాలు మారుతాయి. మీ పెద్దలు లేదా పురోహితులు వేరేలా చేస్తే, వారినే అనుసరించండి.',
            ),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MantraBox extends StatelessWidget {
  const _MantraBox({required this.mantra, required this.lang});
  final PoojaMantra mantra;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Palette.saffron.withValues(alpha: context.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.saffron.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🕉️ ${mantra.title(lang)}',
            style: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          SelectableText(scriptFor(lang, mantra.sanskrit), style: scriptureStyle(context, size: 18)),
          const SizedBox(height: 6),
          Text(mantra.meaning(lang), style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}
