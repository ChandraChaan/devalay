import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/billing.dart';
import '../core/i18n.dart';
import '../core/storage.dart';
import '../core/support_chat.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';

/// "Chat with the developer": Premium members write to the owner and see the replies here.
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});
  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  late final Future<String?> _uid = ref.read(supportChatStoreProvider).myUid().catchError((Object _) => null);

  @override
  void initState() {
    super.initState();
    Usage.record('chat_open');
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final premium = ref.watch(premiumProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'Chat with the developer', 'डेवलपर से बात करें', 'డెవలపర్‌తో మాట్లాడండి'))),
      body: !premium
          ? const _PremiumOnly()
          : FutureBuilder<String?>(
              future: _uid,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final uid = snap.data;
                if (uid == null) {
                  return _Notice(
                    t3(
                      lang,
                      'Chat needs an internet connection. Please try again in a moment.',
                      'चैट के लिए इंटरनेट चाहिए। थोड़ी देर बाद फिर कोशिश करें।',
                      'చాట్‌కు ఇంటర్నెట్ అవసరం. కాసేపటి తర్వాత మళ్లీ ప్రయత్నించండి.',
                    ),
                  );
                }
                return ChatView(uid: uid, asAdmin: false);
              },
            ),
    );
  }
}

class _PremiumOnly extends ConsumerWidget {
  const _PremiumOnly();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              t3(
                lang,
                'Premium members can chat with the developer directly. Everyone can still send ideas and problems from Send feedback.',
                'प्रीमियम सदस्य डेवलपर से सीधे बात कर सकते हैं। बाकी सभी "सुझाव भेजें" से अपने सुझाव और समस्याएँ भेज सकते हैं।',
                'ప్రీమియం సభ్యులు డెవలపర్‌తో నేరుగా మాట్లాడవచ్చు. మిగతా అందరూ "సూచనలు పంపండి" ద్వారా సూచనలు, సమస్యలు పంపవచ్చు.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/premium?from=chat'),
              child: Text(t3(lang, 'See Premium', 'प्रीमियम देखें', 'ప్రీమియం చూడండి')),
            ),
            TextButton(
              onPressed: () => context.push('/feedback'),
              child: Text(t3(lang, 'Send feedback', 'सुझाव भेजें', 'సూచనలు పంపండి')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

/// The conversation and the box to write in. The member and the owner's admin screen share it;
/// [asAdmin] decides whose messages sit on the right.
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key, required this.uid, required this.asAdmin});
  final String uid;
  final bool asAdmin;
  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _text = TextEditingController();
  late final _store = ref.read(supportChatStoreProvider);
  late final Stream<List<ChatMessage>> _messages = _store.messages(widget.uid);
  bool _sending = false;
  int _seen = -1;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _markRead(List<ChatMessage> messages) {
    final theirs = messages.where((m) => m.fromAdmin != widget.asAdmin).length;
    if (theirs == _seen || theirs == 0) return;
    _seen = theirs;
    unawaited(_store.markRead(widget.uid, asAdmin: widget.asAdmin).catchError((Object _) {}));
  }

  Future<void> _send() async {
    final text = cleanChatText(_text.text);
    if (text == null || _sending) return;
    final lang = ref.read(prefsProvider).language;
    setState(() => _sending = true);
    try {
      String version = '';
      try {
        version = (await PackageInfo.fromPlatform().timeout(const Duration(seconds: 2))).version;
      } catch (_) {}
      await _store.send(
        widget.uid,
        text,
        asAdmin: widget.asAdmin,
        lang: lang,
        version: version,
        premium: ref.read(premiumProvider),
      );
      _text.clear();
      if (widget.asAdmin) {
        unawaited(_store.notifyMember(widget.uid, text).catchError((Object _) {}));
      } else {
        Usage.record('chat_sent');
      }
    } catch (e) {
      if (mounted) {
        toast(
          context,
          t3(
            lang,
            'Could not send. Check your internet connection and try again.',
            'भेजा नहीं जा सका। इंटरनेट जाँचकर फिर कोशिश करें।',
            'పంపలేకపోయాం. ఇంటర్నెట్ చూసి మళ్లీ ప్రయత్నించండి.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _messages,
            builder: (context, snap) {
              if (snap.hasError) {
                return _Notice(
                  t3(
                    lang,
                    'Chat needs an internet connection. Please try again in a moment.',
                    'चैट के लिए इंटरनेट चाहिए। थोड़ी देर बाद फिर कोशिश करें।',
                    'చాట్‌కు ఇంటర్నెట్ అవసరం. కాసేపటి తర్వాత మళ్లీ ప్రయత్నించండి.',
                  ),
                );
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final messages = snap.data!;
              WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(messages));
              if (messages.isEmpty) {
                return _Notice(
                  widget.asAdmin
                      ? 'No messages yet.'
                      : t3(
                          lang,
                          'Write to the developer about anything in Devalay: a question, a problem or an idea. You will get a reply here, usually within a day 🙏',
                          'देवालय के बारे में कुछ भी लिखें: सवाल, समस्या या सुझाव। जवाब यहीं मिलेगा, आमतौर पर एक दिन में 🙏',
                          'దేవాలయం గురించి ఏదైనా రాయండి: ప్రశ్న, సమస్య లేదా సూచన. సమాధానం ఇక్కడే వస్తుంది, సాధారణంగా ఒక రోజులో 🙏',
                        ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final m = messages[messages.length - 1 - i];
                  final mine = m.fromAdmin == widget.asAdmin;
                  return _Bubble(message: m, mine: mine, theme: theme);
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: chatMaxLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: t3(lang, 'Write a message', 'संदेश लिखें', 'సందేశం రాయండి'),
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: t3(lang, 'Send', 'भेजें', 'పంపండి'),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.theme});
  final ChatMessage message;
  final bool mine;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final bg = mine ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest;
    final fg = mine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    final at = message.at;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(message.text, style: TextStyle(color: fg, height: 1.35)),
            if (at != null)
              Text(
                '${at.day}/${at.month} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

/// The member's entry point on Support and Premium screens: opens the chat, with a dot when the
/// developer has replied and it has not been read yet.
class ChatEntryTile extends ConsumerWidget {
  const ChatEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final premium = ref.watch(premiumProvider);
    final unread = premium ? (ref.watch(myChatUnreadProvider).value ?? 0) : 0;
    return Card(
      child: ListTile(
        leading: Badge(
          isLabelVisible: unread > 0,
          label: Text('$unread'),
          child: const Text('💬', style: TextStyle(fontSize: 26)),
        ),
        title: Text(
          t3(lang, 'Chat with the developer', 'डेवलपर से बात करें', 'డెవలపర్‌తో మాట్లాడండి'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          premium
              ? t3(
                  lang,
                  'Ask anything; replies usually within a day',
                  'कुछ भी पूछें; जवाब आमतौर पर एक दिन में',
                  'ఏదైనా అడగండి; సమాధానం సాధారణంగా ఒక రోజులో',
                )
              : t3(lang, 'Comes with Premium 👑', 'प्रीमियम के साथ 👑', 'ప్రీమియంతో 👑'),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: premium ? Palette.saffron : null),
        onTap: () => context.push(premium ? '/support/chat' : '/premium?from=chat'),
      ),
    );
  }
}

/// How many of the developer's replies this member has not read yet.
final myChatUnreadProvider = StreamProvider<int>((ref) async* {
  final store = ref.watch(supportChatStoreProvider);
  String? uid;
  try {
    uid = await store.myUid();
  } catch (_) {}
  if (uid == null) {
    yield 0;
    return;
  }
  yield* store.thread(uid).map((t) => t.unreadUser).handleError((Object _) {});
});
