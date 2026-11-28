import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/translate.dart';
import '../core/usage.dart';

/// The "Translate" button in a reader's app bar. The first tap picks the language (the app language when
/// ML Kit has it) and downloads it once; later taps switch translation on and off everywhere.
class TranslateAction extends ConsumerWidget {
  const TranslateAction({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(translateOnProvider);
    final lang = uiLang(ref);
    return IconButton(
      tooltip: t3(lang, 'Translate', 'अनुवाद', 'అనువాదం'),
      color: color,
      isSelected: on,
      icon: const Icon(Icons.language_rounded),
      selectedIcon: const Icon(Icons.g_translate_rounded),
      onPressed: () => on ? ref.read(translateOnProvider.notifier).set(false) : turnOn(context, ref),
    );
  }

  static Future<void> turnOn(BuildContext context, WidgetRef ref) async {
    final ui = uiLang(ref);
    var target = ref.read(translateTargetProvider);
    if (target == null || !translatableLanguages.containsKey(target)) {
      target = translatableLanguages.containsKey(ui) ? ui : await pickLanguage(context, ui);
    }
    if (target == null || !context.mounted) return;
    if (!await Translation.isReady(target)) {
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _DownloadDialog(lang: target!, ui: ui),
      );
      if (ok != true) return;
    }
    await ref.read(translateTargetProvider.notifier).set(target);
    await ref.read(translateOnProvider.notifier).set(true);
    Usage.record('translate_on', item: target);
  }

  static Future<String?> pickLanguage(BuildContext context, String ui) => showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              t3(ui, 'Translate into', 'किस भाषा में', 'ఏ భాషలోకి'),
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          for (final e in translatableNames.entries)
            ListTile(title: Text(e.value), onTap: () => Navigator.pop(ctx, e.key)),
        ],
      ),
    ),
  );
}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.lang, required this.ui});
  final String lang, ui;
  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await Translation.prepare(widget.lang);
      if (mounted) ok ? Navigator.pop(context, true) : setState(() => _error = 'not available');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    final name = translatableNames[widget.lang] ?? widget.lang;
    return AlertDialog(
      title: Text(t3(ui, 'Translate into $name', '$name में अनुवाद', '$nameలోకి అనువాదం')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t3(
              ui,
              'Devalay translates on your phone, privately and offline. The $name language pack (about 30 MB) downloads once.',
              'देवालय आपके फ़ोन पर ही, निजी रूप से और ऑफ़लाइन अनुवाद करता है। $name भाषा पैक (लगभग 30 MB) एक बार डाउनलोड होगा।',
              'దేవాలయం మీ ఫోన్‌లోనే, ప్రైవేట్‌గా, ఆఫ్‌లైన్‌లో అనువదిస్తుంది. $name భాషా ప్యాక్ (సుమారు 30 MB) ఒక్కసారి డౌన్‌లోడ్ అవుతుంది.',
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                t3(ui, 'Could not download: $_error', 'डाउनलोड नहीं हुआ: $_error', 'డౌన్‌లోడ్ కాలేదు: $_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(t3(ui, 'Cancel', 'रद्द करें', 'రద్దు')),
        ),
        FilledButton(onPressed: _busy ? null : _go, child: Text(t3(ui, 'Download', 'डाउनलोड', 'డౌన్‌లోడ్'))),
      ],
    );
  }
}

/// English text, shown translated while translation is on (with a small note that it is a machine
/// translation), and as written otherwise.
class TranslatedText extends ConsumerWidget {
  const TranslatedText(this.text, {super.key, this.style, this.selectable = false});
  final String text;
  final TextStyle? style;
  final bool selectable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(translateOnProvider);
    final target = ref.watch(translateTargetProvider);
    Widget plain(String t) => selectable ? SelectableText(t, style: style) : Text(t, style: style);
    if (!on || target == null) return plain(text);
    return FutureBuilder<String>(
      key: ValueKey('$target:${text.hashCode}'),
      future: Translation.translate(text, target),
      builder: (context, snap) {
        if (snap.hasError) return plain(text);
        if (!snap.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [plain(text), const SizedBox(height: 6), const LinearProgressIndicator()],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            plain(snap.data!),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.g_translate_rounded, size: 14, color: Theme.of(context).hintColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      t3(
                        uiLang(ref),
                        'Translated on your phone · tap Translate to see the original',
                        'आपके फ़ोन पर अनुवाद · मूल देखने के लिए अनुवाद दबाएँ',
                        'మీ ఫోన్‌లో అనువాదం · అసలు చూడటానికి అనువాదం నొక్కండి',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
