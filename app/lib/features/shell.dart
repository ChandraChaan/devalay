import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import '../core/app_care.dart';
import '../core/calendar_reminders.dart';
import '../core/i18n.dart';
import '../core/storage.dart';
import '../core/theme.dart';
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
      refreshCalendarReminders(ref);
      checkForAppUpdate(context, ref);
      // A quiet moment after the first screen settles; Play decides whether to show the card.
      Future.delayed(const Duration(seconds: 20), maybeAskForReview);
    });
    // Tapping the home-screen Panchang widget opens the calendar.
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      // On a cold start the first route is still settling; open the calendar after the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFromWidget(uri));
    }, onError: (_) {});
    _widgetTaps = HomeWidget.widgetClicked.listen(_openFromWidget, onError: (_) {});
  }

  StreamSubscription<Uri?>? _widgetTaps;

  void _openFromWidget(Uri? uri) {
    if (!mounted || uri?.host != 'calendar') return;
    context.push('/calendar');
  }

  @override
  void dispose() {
    _widgetTaps?.cancel();
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
