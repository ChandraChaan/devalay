import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase.dart';

/// Premium support chat between a member and the owner. One thread per install, in Firestore
/// `support/{uid}` (a summary the admin list reads) with the messages in `support/{uid}/messages`.
/// Members write as 'user', the owner's admin screen as 'admin'; firestore.rules keep each side to
/// its own role, and the `supportNotify` Cloud Function tells the owner's phone about new messages.
class ChatMessage {
  const ChatMessage({required this.id, required this.fromAdmin, required this.text, this.at});
  final String id;
  final bool fromAdmin;
  final String text;
  final DateTime? at;

  static ChatMessage? fromMap(String id, Map<String, dynamic>? m) {
    if (m == null) return null;
    final text = m['text'];
    if (text is! String || text.isEmpty) return null;
    final at = m['at'];
    return ChatMessage(id: id, fromAdmin: m['from'] == 'admin', text: text, at: at is Timestamp ? at.toDate() : null);
  }
}

class ChatThread {
  const ChatThread({
    required this.uid,
    this.last = '',
    this.lastFromAdmin = false,
    this.unreadAdmin = 0,
    this.unreadUser = 0,
    this.updated,
    this.lang = '',
    this.version = '',
    this.premium = false,
  });
  final String uid;
  final String last;
  final bool lastFromAdmin;
  final int unreadAdmin, unreadUser;
  final DateTime? updated;
  final String lang, version;
  final bool premium;

  static ChatThread fromMap(String uid, Map<String, dynamic>? m) {
    m ??= const {};
    int n(Object? v) => v is num ? v.toInt() : 0;
    final updated = m['updated'];
    return ChatThread(
      uid: uid,
      last: m['last'] is String ? m['last'] as String : '',
      lastFromAdmin: m['lastFrom'] == 'admin',
      unreadAdmin: n(m['unreadAdmin']),
      unreadUser: n(m['unreadUser']),
      updated: updated is Timestamp ? updated.toDate() : null,
      lang: m['lang'] is String ? m['lang'] as String : '',
      version: m['v'] is String ? m['v'] as String : '',
      premium: m['premium'] == true,
    );
  }
}

/// Longest message a member or the owner can send (firestore.rules checks the same).
const chatMaxLength = 1000;

/// A message as stored: trimmed and cut to [chatMaxLength]; null when there is nothing to send.
String? cleanChatText(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  return t.length > chatMaxLength ? t.substring(0, chatMaxLength) : t;
}

/// The short preview kept on the thread for the admin list.
String chatPreview(String text) => text.length > 120 ? '${text.substring(0, 117)}…' : text;

/// The slice of Firestore the chat uses, so tests can stand in a fake.
abstract class SupportChatStore {
  /// This install's id, signing in anonymously if needed; null when Firebase is not available.
  Future<String?> myUid();
  Stream<List<ChatMessage>> messages(String uid);
  Stream<ChatThread> thread(String uid);
  Stream<List<ChatThread>> threads();
  Future<void> send(String uid, String text, {required bool asAdmin, String lang, String version, bool premium});
  Future<void> markRead(String uid, {required bool asAdmin});

  /// Tells the member's phone that the owner replied (admin only).
  Future<void> notifyMember(String uid, String text);
}

class FirestoreSupportChat implements SupportChatStore {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> _thread(String uid) => _db.collection('support').doc(uid);

  @override
  Future<String?> myUid() async {
    if (!FirebaseServices.enabled) return null;
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();
    return auth.currentUser?.uid;
  }

  @override
  Stream<List<ChatMessage>> messages(String uid) => _thread(uid)
      .collection('messages')
      .orderBy('at')
      .limitToLast(300)
      .snapshots()
      .map((s) => [for (final d in s.docs) ?ChatMessage.fromMap(d.id, d.data())]);

  @override
  Stream<ChatThread> thread(String uid) => _thread(uid).snapshots().map((d) => ChatThread.fromMap(uid, d.data()));

  @override
  Stream<List<ChatThread>> threads() => _db
      .collection('support')
      .orderBy('updated', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => [for (final d in s.docs) ChatThread.fromMap(d.id, d.data())]);

  @override
  Future<void> send(
    String uid,
    String text, {
    required bool asAdmin,
    String lang = '',
    String version = '',
    bool premium = false,
  }) async {
    final batch = _db.batch();
    batch.set(_thread(uid).collection('messages').doc(), {
      'from': asAdmin ? 'admin' : 'user',
      'text': text,
      'at': FieldValue.serverTimestamp(),
    });
    batch.set(
      _thread(uid),
      asAdmin
          ? {
              'updated': FieldValue.serverTimestamp(),
              'last': chatPreview(text),
              'lastFrom': 'admin',
              'unreadUser': FieldValue.increment(1),
              'unreadAdmin': 0,
            }
          : {
              'uid': uid,
              'lang': lang,
              'v': version,
              'premium': premium,
              'updated': FieldValue.serverTimestamp(),
              'last': chatPreview(text),
              'lastFrom': 'user',
              'unreadAdmin': FieldValue.increment(1),
              'unreadUser': 0,
            },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  @override
  Future<void> markRead(String uid, {required bool asAdmin}) =>
      _thread(uid).update({asAdmin ? 'unreadAdmin' : 'unreadUser': 0});

  @override
  Future<void> notifyMember(String uid, String text) async {
    await FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('sendPush').call<Object?>({
      'name': 'Chat reply',
      'title': {'en': 'Reply from Devalay 🙏', 'hi': 'देवालय से जवाब 🙏', 'te': 'దేవాలయం నుండి సమాధానం 🙏'},
      'body': {'en': chatPreview(text)},
      'link': 'devalay://support/chat',
      'image': '',
      'audience': {'type': 'user', 'value': uid},
      'dryRun': false,
      'force': true,
    });
  }
}

final supportChatStoreProvider = Provider<SupportChatStore>((_) => FirestoreSupportChat());
