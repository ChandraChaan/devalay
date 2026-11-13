import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/languages.dart';
import '../core/panchang_voice.dart';
import '../core/storage.dart';
import 'common.dart';

/// A speaker button that reads [day]'s Panchang aloud in the app language, or stops reading.
class ReadAloudButton extends ConsumerWidget {
  const ReadAloudButton({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final reading = ref.watch(panchangVoiceProvider.select((s) => s.isReading(day)));
    return IconButton(
      tooltip: reading
          ? t3(lang, 'Stop reading', 'पढ़ना रोकें', 'చదవడం ఆపండి')
          : t3(lang, 'Read aloud', 'पढ़कर सुनाएँ', 'చదివి వినిపించండి'),
      icon: Icon(reading ? Icons.stop_circle_rounded : Icons.volume_up_rounded),
      onPressed: () async {
        final voice = ref.read(panchangVoiceProvider.notifier);
        if (reading) return voice.stop();
        final outcome = await voice.read(
          ref,
          day,
          onEnglishFallback: () {
            if (!context.mounted) return;
            final key = 'tts_hint_$lang';
            if (Boxes.prefs.get(key) == true) {
              toast(context, _fallbackNote(lang));
            } else {
              Boxes.prefs.put(key, true);
              showVoiceHelp(context, lang);
            }
          },
        );
        if (!context.mounted) return;
        switch (outcome) {
          case ReadOutcome.failed:
            toast(
              context,
              t3(
                lang,
                'Could not read aloud on this phone.',
                'इस फ़ोन पर पढ़कर नहीं सुनाया जा सका।',
                'ఈ ఫోన్‌లో చదివి వినిపించలేకపోయాం.',
              ),
            );
          case ReadOutcome.read || ReadOutcome.englishFallback:
            break;
        }
      },
    );
  }
}

String _fallbackNote(String lang) => t3(
  lang,
  'Read in English: this phone has no ${languageOf(lang).english} voice.',
  'अंग्रेज़ी में पढ़ा: इस फ़ोन में ${languageOf(lang).english} आवाज़ नहीं है।',
  'ఇంగ్లీషులో చదివాం: ఈ ఫోన్‌లో ${languageOf(lang).english} వాయిస్ లేదు.',
);

/// Explains how to install a text-to-speech voice for [lang].
Future<void> showVoiceHelp(BuildContext context, String lang) {
  final name = languageOf(lang).native;
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  final steps = ios
      ? t3(
          lang,
          'Open Settings › Accessibility › Spoken Content › Voices, choose $name and download a voice.',
          'सेटिंग्स › एक्सेसिबिलिटी › स्पोकन कंटेंट › वॉइस खोलें, $name चुनें और एक आवाज़ डाउनलोड करें।',
          'సెట్టింగ్స్ › యాక్సెసిబిలిటీ › స్పోకెన్ కంటెంట్ › వాయిసెస్ తెరిచి, $name ఎంచుకుని ఒక వాయిస్ డౌన్‌లోడ్ చేయండి.',
        )
      : t3(
          lang,
          'Open Settings › System › Languages › Text-to-speech output, tap the gear next to Speech Services by Google, '
              'choose Install voice data, then download $name.',
          'सेटिंग्स › सिस्टम › भाषाएँ › टेक्स्ट-टू-स्पीच आउटपुट खोलें, Speech Services by Google के पास गियर दबाएँ, '
              'Install voice data चुनें और $name डाउनलोड करें।',
          'సెట్టింగ్స్ › సిస్టమ్ › భాషలు › టెక్స్ట్-టు-స్పీచ్ అవుట్‌పుట్ తెరిచి, Speech Services by Google పక్కన గేర్ నొక్కి, '
              'Install voice data ఎంచుకుని $name డౌన్‌లోడ్ చేయండి.',
        );
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t3(lang, 'No voice for $name yet', '$name की आवाज़ अभी नहीं है', '$name వాయిస్ ఇంకా లేదు'),
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              t3(
                lang,
                'Your phone has no text-to-speech voice for $name, so we read the day in English. To hear it in $name:',
                'आपके फ़ोन में $name की टेक्स्ट-टू-स्पीच आवाज़ नहीं है, इसलिए हमने अंग्रेज़ी में पढ़ा। $name में सुनने के लिए:',
                'మీ ఫోన్‌లో $name టెక్స్ట్-టు-స్పీచ్ వాయిస్ లేదు, అందుకే ఇంగ్లీషులో చదివాం. $nameలో వినడానికి:',
              ),
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(steps, style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t3(lang, 'OK', 'ठीक है', 'సరే'))),
            ),
          ],
        ),
      ),
    ),
  );
}
