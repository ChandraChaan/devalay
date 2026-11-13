import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/calendar_reminders.dart';
import '../core/i18n.dart';
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
      if (mounted) refreshCalendarReminders(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
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
