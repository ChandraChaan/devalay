import 'dart:async';

import 'package:devalay/core/billing.dart';
import 'package:devalay/core/languages.dart';
import 'package:devalay/core/storage.dart';
import 'package:devalay/core/support_chat.dart';
import 'package:devalay/core/theme.dart';
import 'package:devalay/features/admin_chat.dart';
import 'package:devalay/features/support_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'billing_fakes.dart';
import 'helpers.dart';

class FakeChat implements SupportChatStore {
  FakeChat({this.uid = 'member-1'});
  final String? uid;
  final _messages = <String, List<ChatMessage>>{};
  final _threads = <String, ChatThread>{};
  final _msgCtl = StreamController<void>.broadcast();
  final notified = <(String, String)>[];
  final readBy = <bool>[];
  bool failSend = false;

  void seed(String uid, List<ChatMessage> messages, {int unreadUser = 0}) {
    _messages[uid] = messages;
    _threads[uid] = ChatThread(
      uid: uid,
      last: messages.isEmpty ? '' : messages.last.text,
      lastFromAdmin: messages.isNotEmpty && messages.last.fromAdmin,
      unreadUser: unreadUser,
      unreadAdmin: messages.where((m) => !m.fromAdmin).length,
      premium: true,
      lang: 'te',
      version: '1.5.10',
      updated: DateTime(2026, 11, 28, 9, 30),
    );
  }

  @override
  Future<String?> myUid() async => uid;

  @override
  Stream<List<ChatMessage>> messages(String uid) async* {
    yield List.of(_messages[uid] ?? const []);
    await for (final _ in _msgCtl.stream) {
      yield List.of(_messages[uid] ?? const []);
    }
  }

  @override
  Stream<ChatThread> thread(String uid) async* {
    yield _threads[uid] ?? ChatThread(uid: uid);
  }

  @override
  Stream<List<ChatThread>> threads() async* {
    yield _threads.values.toList();
  }

  @override
  Future<void> send(
    String uid,
    String text, {
    required bool asAdmin,
    String lang = '',
    String version = '',
    bool premium = false,
  }) async {
    if (failSend) throw StateError('offline');
    (_messages[uid] ??= []).add(
      ChatMessage(id: '${_messages[uid]!.length}', fromAdmin: asAdmin, text: text, at: DateTime(2026, 11, 28, 10)),
    );
    _msgCtl.add(null);
  }

  @override
  Future<void> markRead(String uid, {required bool asAdmin}) async => readBy.add(asAdmin);

  @override
  Future<void> notifyMember(String uid, String text) async => notified.add((uid, text));
}

void main() {
  setUpAll(() async {
    await initTestStorage();
    PackageInfo.setMockInitialValues(
      appName: 'Devalay',
      packageName: 'com.chandrachaan.devalay',
      version: '1.5.10',
      buildNumber: '10510',
      buildSignature: '',
    );
  });
  setUp(() => Boxes.prefs.put('language', 'en'));

  group('message rules', () {
    test('messages are trimmed, empty ones dropped and long ones cut', () {
      expect(cleanChatText('  hello  '), 'hello');
      expect(cleanChatText('   '), isNull);
      expect(cleanChatText('x' * 1500)!.length, chatMaxLength);
      expect(chatPreview('short'), 'short');
      expect(chatPreview('y' * 300).length, 118);
    });

    test('threads and messages survive missing or odd fields', () {
      final t = ChatThread.fromMap('u', {'unreadAdmin': 2.0, 'lastFrom': 'admin', 'last': 5, 'premium': 'yes'});
      expect(t.unreadAdmin, 2);
      expect(t.lastFromAdmin, isTrue);
      expect(t.last, '');
      expect(t.premium, isFalse);
      expect(ChatThread.fromMap('u', null).unreadUser, 0);
      expect(ChatMessage.fromMap('1', {'from': 'admin', 'text': ''}), isNull);
      expect(ChatMessage.fromMap('1', null), isNull);
      expect(ChatMessage.fromMap('1', {'from': 'user', 'text': 'hi'})!.fromAdmin, isFalse);
    });
  });

  group('screens', () {
    Widget app(Widget home, FakeChat chat, {bool premium = true}) {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => home),
          GoRoute(
            path: '/premium',
            builder: (_, _) => const Scaffold(body: Text('premium page')),
          ),
          GoRoute(
            path: '/feedback',
            builder: (_, _) => const Scaffold(body: Text('feedback page')),
          ),
          GoRoute(path: '/support/chat', builder: (_, _) => const SupportChatScreen()),
        ],
      );
      return ProviderScope(
        overrides: [
          ...billingOverrides(
            FakeStore(owned: premium ? [purchase(Products.premiumYearly, PurchaseStatus.purchased)] : []),
            premium ? cachedPremium() : MemoryCache(),
          ),
          supportChatStoreProvider.overrideWithValue(chat),
        ],
        child: MaterialApp.router(theme: buildTheme(Brightness.light), routerConfig: router),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('without Premium the chat explains and leads to Premium', (tester) async {
      await tester.pumpWidget(app(const SupportChatScreen(), FakeChat(), premium: false));
      await settle(tester);
      expect(find.textContaining('Premium members can chat with the developer'), findsOneWidget);
      await tester.tap(find.text('See Premium'));
      await settle(tester);
      expect(find.text('premium page'), findsOneWidget);
    });

    testWidgets('a member sends a message and sees it in the conversation', (tester) async {
      final chat = FakeChat();
      await tester.pumpWidget(app(const SupportChatScreen(), chat));
      await settle(tester);
      expect(find.textContaining('Write to the developer about anything'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  How do I set my city?  ');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);
      expect(find.text('How do I set my city?'), findsOneWidget);
      expect(chat.notified, isEmpty, reason: 'members never send pushes');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('a failed send keeps the text and says so', (tester) async {
      final chat = FakeChat()..failSend = true;
      await tester.pumpWidget(app(const SupportChatScreen(), chat));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);
      expect(find.textContaining('Could not send'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Hello');
    });

    testWidgets('without Firebase the member is told to try later', (tester) async {
      await tester.pumpWidget(app(const SupportChatScreen(), FakeChat(uid: null)));
      await settle(tester);
      expect(find.textContaining('Chat needs an internet connection'), findsOneWidget);
    });

    testWidgets('the developer replies from the admin tab and the member is notified', (tester) async {
      final chat = FakeChat()
        ..seed('member-1', [const ChatMessage(id: '0', fromAdmin: false, text: 'Panchang shows the wrong city')]);
      await tester.pumpWidget(app(const Scaffold(body: AdminChatTab()), chat));
      await settle(tester);
      expect(find.text('Panchang shows the wrong city'), findsOneWidget);
      expect(find.textContaining('te · v1.5.10'), findsOneWidget);
      await tester.tap(find.text('Panchang shows the wrong city'));
      await settle(tester);
      expect(chat.readBy, contains(true), reason: 'opening the thread marks it read for the admin');
      await tester.enterText(find.byType(TextField), 'Fixed in Settings > City 🙏');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);
      expect(find.text('Fixed in Settings > City 🙏'), findsOneWidget);
      expect(chat.notified, [('member-1', 'Fixed in Settings > City 🙏')]);
    });

    testWidgets('the entry tile shows unread replies and opens the chat', (tester) async {
      final chat = FakeChat()
        ..seed('member-1', [const ChatMessage(id: '0', fromAdmin: true, text: 'Hi!')], unreadUser: 1);
      await tester.pumpWidget(app(const Scaffold(body: ChatEntryTile()), chat));
      await settle(tester);
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.text('Chat with the developer'));
      await settle(tester);
      expect(find.text('Hi!'), findsOneWidget);
      expect(chat.readBy, contains(false), reason: 'the member read the reply');
    });

    testWidgets('chat screens render in all 11 languages', (tester) async {
      final chat = FakeChat()..seed('member-1', [const ChatMessage(id: '0', fromAdmin: true, text: 'नमस्ते')]);
      for (final l in appLanguages) {
        Boxes.prefs.put('language', l.code);
        for (final premium in [true, false]) {
          await tester.pumpWidget(app(const SupportChatScreen(), chat, premium: premium));
          await settle(tester);
          expect(tester.takeException(), isNull, reason: '${l.code} premium=$premium');
        }
      }
      Boxes.prefs.put('language', 'en');
    });
  });
}
