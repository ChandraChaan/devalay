import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:home_widget/home_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../core/app_care.dart';
import '../core/audio.dart';
import '../core/calendar_reminders.dart';
import '../core/firebase.dart';
import '../core/i18n.dart';
import '../core/notifications.dart';
import '../core/push.dart';
import '../core/retention.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Calendar alarms are laid a few weeks ahead from cached data; top them up on every start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      refreshCalendarReminders(ref).then((_) {
        if (mounted) reportRetentionProperties(ref.read(prefsProvider));
      });
      // A tap on a reminder that started the app opens its screen once the first route has settled.
      Notifications.launchKind().then(
        (kind) => _openFromNotification(kind, coldStart: true),
        onError: (Object e) => debugPrint('Notification launch not read: $e'),
      );
      checkForAppUpdate(context, ref);
      // A quiet moment after the first screen settles; Play decides whether to show the card.
      Future.delayed(const Duration(seconds: 20), maybeAskForReview);
    });
    // Tapping a home-screen widget opens its screen (devalay://calendar, devalay://calendar/day/2026-11-13, ...).
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      // On a cold start the first route is still settling; open the calendar after the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFromWidget(uri));
    }, onError: (_) {});
    _widgetTaps = HomeWidget.widgetClicked.listen(_openFromWidget, onError: (_) {});
    _notificationTaps = Notifications.taps.listen((kind) => _openFromNotification(kind, coldStart: false));
    // Pushes from the admin screen, tapped in the tray while the app was closed or in the background.
    if (FirebaseServices.enabled) {
      FirebaseMessaging.instance.getInitialMessage().then((m) {
        if (m != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openFromPush(m.data, coldStart: true));
      }, onError: (Object _) {});
      _pushTaps = FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFromPush(m.data, coldStart: false));
    }
    // A track that can't be streamed (offline, server busy) gets a message instead of silence.
    _audioErrors = ref.read(audioProvider).errors.listen((_) {
      if (mounted) toast(context, tr(ref, 'error'));
    });
  }

  StreamSubscription<Uri?>? _widgetTaps;
  StreamSubscription<String>? _notificationTaps;
  StreamSubscription<RemoteMessage>? _pushTaps;
  StreamSubscription<Object>? _audioErrors;

  void _openFromWidget(Uri? uri) {
    final path = widgetRoute(uri);
    if (!mounted || path == null) return;
    logWidgetTap(uri!, path);
    _show(path);
  }

  /// Opens [path] on top, or replaces it when it is already the top screen, so a tap on today's
  /// Panchang while yesterday's is open shows today's instead of stacking a second copy.
  void _show(String path) {
    final router = GoRouter.of(context);
    if (screenPattern(router.routerDelegate.currentConfiguration) == path) {
      router.pushReplacement(path);
    } else {
      router.push(path);
    }
  }

  void _openFromPush(Map<String, dynamic> data, {required bool coldStart}) {
    if (!mounted) return;
    logPushOpen('${data['c'] ?? ''}', coldStart: coldStart);
    _openLink('${data['link'] ?? ''}');
  }

  /// A push's link: an app screen (devalay://panchang), or a web page opened in the browser.
  void _openLink(String link) {
    if (link.startsWith('https://')) {
      unawaited(launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication));
      return;
    }
    final path = pushRoute(link);
    if (path == null) return;
    const tabs = {'/home', '/listen', '/mandir', '/read', '/more'};
    tabs.contains(path) ? context.go(path) : _show(path);
  }

  void _openFromNotification(String? kind, {required bool coldStart}) {
    if (kind == null || !mounted) return;
    // A push shown while the app was open, then tapped.
    if (parsePushPayload(kind) case final push?) {
      logPushOpen(push.campaign, coldStart: coldStart);
      _openLink(push.link);
      return;
    }
    logNotificationOpen(kind, coldStart: coldStart);
    final path = Notifications.routeFor(kind);
    if (path == null) return;
    path == '/listen' ? context.go(path) : _show(path);
  }

  @override
  void dispose() {
    _widgetTaps?.cancel();
    _notificationTaps?.cancel();
    _pushTaps?.cancel();
    _audioErrors?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    // City, language or birth star changes rewrite the morning messages and the widget text.
    ref.listen(prefsProvider.select((p) => (p.cityId, p.language, p.birthStar)), (_, _) {
      refreshCalendarReminders(ref);
    });
    final items = [
      (Icons.home_outlined, Icons.home_rounded, 'home'),
      (Icons.headphones_outlined, Icons.headphones_rounded, 'listen'),
      (Icons.temple_hindu_outlined, Icons.temple_hindu_rounded, 'mandir'),
      (Icons.menu_book_outlined, Icons.menu_book_rounded, 'read'),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, 'more'),
    ];
    final destinations = [for (final (icon, selected, key) in items) (Icon(icon), Icon(selected), tr(ref, key))];
    void go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
    // Tablets and landscape phones get a side rail; content stays at a comfortable reading width.
    if (MediaQuery.sizeOf(context).width >= Breakpoints.rail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.6,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('🛕', style: TextStyle(fontSize: 32)),
              ),
              destinations: [
                for (final (icon, selected, label) in destinations)
                  NavigationRailDestination(icon: icon, selectedIcon: selected, label: Text(label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: Breakpoints.content),
                        child: shell,
                      ),
                    ),
                  ),
                  const MiniPlayer(),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: go,
            destinations: [
              for (final (icon, selected, label) in destinations)
                NavigationDestination(icon: icon, selectedIcon: selected, label: label),
            ],
          ),
        ],
      ),
    );
  }
}

/// The screen a home-screen widget link opens, or null for links the widgets never send.
String? widgetRoute(Uri? uri) {
  if (uri == null || uri.scheme != 'devalay') return null;
  final path = '/${uri.host}${uri.path}'.replaceFirst(RegExp(r'(?<=.)/+$'), '');
  final ok = path == '/calendar' || path == '/panchang' || RegExp(r'^/calendar/day/\d{4}-\d{2}-\d{2}$').hasMatch(path);
  return ok ? path : null;
}
