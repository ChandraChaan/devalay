import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n.dart';
import '../widgets/mini_player.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      (Icons.home_outlined, Icons.home_rounded, 'home'),
      (Icons.headphones_outlined, Icons.headphones_rounded, 'listen'),
      (Icons.temple_hindu_outlined, Icons.temple_hindu_rounded, 'mandir'),
      (Icons.menu_book_outlined, Icons.menu_book_rounded, 'read'),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, 'more'),
    ];
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
            destinations: [
              for (final (icon, selected, key) in items)
                NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: tr(ref, key)),
            ],
          ),
        ],
      ),
    );
  }
}
