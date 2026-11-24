import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/app_care.dart';
import '../core/firebase.dart';
import '../core/i18n.dart';
import '../core/storage.dart';
import '../core/usage.dart';
import '../widgets/common.dart';

/// Ideas, problems and kind words, straight to the owner's admin inbox (Firestore `feedback`).
/// Users can only add a note, never read anyone's. Without Firebase it opens GitHub issues instead.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _text = TextEditingController();
  String _kind = 'idea';
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final lang = appLang;
    final text = _text.text.trim();
    if (text.length < 3) return;
    setState(() => _sending = true);
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) await auth.signInAnonymously();
      final info = await PackageInfo.fromPlatform();
      await FirebaseFirestore.instance.collection('feedback').add({
        'uid': auth.currentUser!.uid,
        'at': FieldValue.serverTimestamp(),
        'kind': _kind,
        'text': text.length > 2000 ? text.substring(0, 2000) : text,
        'lang': lang,
        'v': info.version,
        'done': false,
      });
      Usage.record('feedback_sent', item: _kind);
      if (!mounted) return;
      toast(
        context,
        t3(
          lang,
          'Thank you! Your note reached us.',
          'धन्यवाद! आपका संदेश हमें मिल गया।',
          'ధన్యవాదాలు! మీ సందేశం మాకు చేరింది.',
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      toast(
        context,
        t3(
          lang,
          'Could not send. Check your connection and try again.',
          'भेजा नहीं जा सका। इंटरनेट जाँचें और फिर कोशिश करें।',
          'పంపలేకపోయాం. ఇంటర్నెట్ చూసి మళ్ళీ ప్రయత్నించండి.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final kinds = [
      ('idea', '💡', t3(lang, 'Idea or feature', 'सुझाव या नई सुविधा', 'ఆలోచన లేదా కొత్త ఫీచర్')),
      ('problem', '🛠️', t3(lang, 'Something is wrong', 'कुछ ठीक नहीं है', 'ఏదో సరిగా లేదు')),
      ('praise', '🙏', t3(lang, 'Something I like', 'जो मुझे पसंद है', 'నాకు నచ్చింది')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'Send feedback', 'सुझाव भेजें', 'సూచనలు పంపండి'))),
      body: !FirebaseServices.enabled
          ? Center(
              child: FilledButton.icon(
                onPressed: sendFeedback,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(t3(lang, 'Open GitHub issues', 'GitHub issues खोलें', 'GitHub issues తెరవండి')),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  t3(
                    lang,
                    'Tell us what to add or fix. We read every note.',
                    'बताइए क्या जोड़ें या ठीक करें। हम हर संदेश पढ़ते हैं।',
                    'ఏమి జోడించాలో లేదా సరిచేయాలో చెప్పండి. ప్రతి సందేశాన్నీ చదువుతాం.',
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in kinds)
                      ChoiceChip(
                        label: Text('${k.$2} ${k.$3}'),
                        selected: _kind == k.$1,
                        onSelected: (_) => setState(() => _kind = k.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _text,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: t3(lang, 'Write here…', 'यहाँ लिखें…', 'ఇక్కడ రాయండి…'),
                  ),
                ),
                Text(
                  t3(
                    lang,
                    'Please do not include phone numbers or other personal details.',
                    'कृपया फ़ोन नंबर या अन्य निजी जानकारी न लिखें।',
                    'దయచేసి ఫోన్ నంబర్ లేదా ఇతర వ్యక్తిగత వివరాలు రాయవద్దు.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _sending || _text.text.trim().length < 3 ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(t3(lang, 'Send', 'भेजें', 'పంపండి')),
                ),
              ],
            ),
    );
  }
}
