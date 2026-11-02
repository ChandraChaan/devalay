import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/storage.dart';
import '../core/theme.dart';

class _Turn {
  _Turn.user(this.text) : verses = const [], provider = null, mine = true;
  _Turn.answer(this.text, this.verses, this.provider) : mine = false;
  final String text;
  final List<Verse> verses;
  final String? provider;
  final bool mine;
}

class AskGitaScreen extends ConsumerStatefulWidget {
  const AskGitaScreen({super.key});
  @override
  ConsumerState<AskGitaScreen> createState() => _AskGitaScreenState();
}

class _AskGitaScreenState extends ConsumerState<AskGitaScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <_Turn>[];
  bool _loading = false;

  static const _suggestions = [
    'How do I stay calm when I am angry?',
    'What does the Gita say about doing my duty?',
    'How can I overcome fear of failure?',
    'What happens to the soul after death?',
  ];

  Future<void> _ask(String q) async {
    if (q.trim().length < 3 || _loading) return;
    _input.clear();
    setState(() {
      _turns.add(_Turn.user(q.trim()));
      _loading = true;
    });
    _toBottom();
    try {
      final r =
          await ref
                  .read(apiProvider)
                  .post('/ai/ask', data: {'question': q.trim(), 'language': ref.read(prefsProvider).language})
              as Map;
      setState(
        () => _turns.add(
          _Turn.answer(
            '${r['answer']}',
            (r['verses'] as List).map((v) => Verse(v as Map)).toList(),
            r['provider'] as String?,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _turns.add(_Turn.answer(e.message, const [], null)));
    } finally {
      if (mounted) setState(() => _loading = false);
      _toBottom();
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'ask_gita'))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                if (_turns.isEmpty) ...[
                  const SizedBox(height: 24),
                  const Center(child: Text('🪈', style: TextStyle(fontSize: 56))),
                  const SizedBox(height: 12),
                  Text(
                    'Ask a question about life, duty or the mind. Answers draw only on verses of the Bhagavad Gita.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  for (final s in _suggestions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ActionChip(label: Text(s), onPressed: () => _ask(s)),
                    ),
                ],
                for (final t in _turns)
                  Align(
                    alignment: t.mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.mine ? scheme.primary : (context.isDark ? Palette.nightCard : Colors.white),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.text,
                            style: TextStyle(color: t.mine ? Colors.white : null, fontSize: 16, height: 1.5),
                          ),
                          for (final v in t.verses)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: InkWell(
                                onTap: () => context.push('/gita/${v.chapter}?verse=${v.verse}'),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Palette.marigold.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        v.ref,
                                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(v.translation, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _ask,
                      decoration: const InputDecoration(hintText: 'Ask the Gita…', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: () => _ask(_input.text), icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
