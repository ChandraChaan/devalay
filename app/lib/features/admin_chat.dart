import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/support_chat.dart';
import '../core/theme.dart';
import 'support_chat.dart';

/// The owner's side of the Premium chat: every thread, newest first, with unread counts. Opening
/// one shows the same conversation view members see, writing as the developer; each reply also
/// reaches the member's phone as a notification (sendPush, one install).
class AdminChatTab extends ConsumerStatefulWidget {
  const AdminChatTab({super.key});
  @override
  ConsumerState<AdminChatTab> createState() => _AdminChatTabState();
}

class _AdminChatTabState extends ConsumerState<AdminChatTab> with AutomaticKeepAliveClientMixin {
  late final Stream<List<ChatThread>> _threads = ref.read(supportChatStoreProvider).threads();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<ChatThread>>(
      stream: _threads,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(padding: const EdgeInsets.all(16), child: Text('Could not load chats: ${snap.error}')),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final threads = snap.data!;
        if (threads.isEmpty) {
          return const Center(child: Text('No chats yet. Premium members can write from Support or Premium.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8).withSystemInsets(context),
          itemCount: threads.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final t = threads[i];
            final when = t.updated;
            return ListTile(
              leading: Badge(
                isLabelVisible: t.unreadAdmin > 0,
                label: Text('${t.unreadAdmin}'),
                child: CircleAvatar(child: Text(t.premium ? '👑' : '🙏')),
              ),
              title: Text(
                t.last.isEmpty ? '(no messages)' : '${t.lastFromAdmin ? 'You: ' : ''}${t.last}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: t.unreadAdmin > 0 ? FontWeight.w700 : FontWeight.w400),
              ),
              subtitle: Text(
                [
                  if (t.lang.isNotEmpty) t.lang,
                  if (t.version.isNotEmpty) 'v${t.version}',
                  if (when != null) '${when.day}/${when.month} ${when.hour}:${when.minute.toString().padLeft(2, '0')}',
                  t.uid.length > 8 ? t.uid.substring(0, 8) : t.uid,
                ].join(' · '),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text('Chat ${t.uid.length > 8 ? t.uid.substring(0, 8) : t.uid}')),
                    body: ChatView(uid: t.uid, asAdmin: true),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
