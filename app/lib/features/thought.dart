import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n.dart';
import '../core/thoughts.dart';
import '../core/theme.dart';
import 'status_maker.dart';

/// "— Vemana · Vemana Shatakam 12" in the reader's script where the data has it.
String thoughtByline(Thought t) => [
  '— ${t.authorNative}',
  if (t.work.isNotEmpty) [t.work, t.ref].where((s) => s.isNotEmpty).join(' '),
].join(' · ');

/// The thought of the day on Home: a verse from the reader's own language's classics, with its
/// meaning, a toggle for the English meaning, and sharing as a status image.
class ThoughtOfDayCard extends ConsumerStatefulWidget {
  const ThoughtOfDayCard({super.key});
  @override
  ConsumerState<ThoughtOfDayCard> createState() => _ThoughtOfDayCardState();
}

class _ThoughtOfDayCardState extends ConsumerState<ThoughtOfDayCard> {
  bool _english = false;

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final thought = ref.watch(thoughtsProvider).value?.of(lang, DateTime.now());
    if (thought == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final showEnglish = _english && thought.meaningEn != thought.meaning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🪷', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t3(lang, 'Thought of the day', 'आज का विचार', 'నేటి సూక్తి'),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    tooltip: t3(lang, 'Share as image', 'चित्र के रूप में शेयर करें', 'చిత్రంగా షేర్ చేయండి'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StatusComposer(
                          text: '${thought.text}\n\n${thoughtByline(thought)}',
                          footnote: thought.meaning,
                          deity: 'general',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.share_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SelectableText(thought.text, style: scriptureStyle(context, size: 18)),
              ),
              Text(
                thoughtByline(thought),
                style: TextStyle(color: primary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  showEnglish ? thought.meaningEn : thought.meaning,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
              Row(
                children: [
                  if (thought.meaningEn != thought.meaning)
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() => _english = !_english),
                      child: Text(
                        showEnglish
                            ? t3(lang, 'Meaning in my language', 'हिन्दी में अर्थ', 'తెలుగులో అర్థం')
                            : t3(lang, 'Meaning in English', 'अंग्रेज़ी में अर्थ', 'ఇంగ్లీషులో అర్థం'),
                      ),
                    ),
                  const Spacer(),
                  if (thought.source.startsWith('http'))
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: () => launchUrl(Uri.parse(thought.source), mode: LaunchMode.externalApplication),
                      child: Text(t3(lang, 'Source', 'स्रोत', 'మూలం')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 150.ms);
  }
}
