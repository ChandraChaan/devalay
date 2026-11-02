import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/models.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'features/ask_gita.dart';
import 'features/auth_screens.dart';
import 'features/books.dart';
import 'features/credits.dart';
import 'features/gita.dart';
import 'features/home.dart';
import 'features/japa.dart';
import 'features/library.dart';
import 'features/listen.dart';
import 'features/mandir.dart';
import 'features/more.dart';
import 'features/onboarding.dart';
import 'features/panchang.dart';
import 'features/player.dart';
import 'features/premium.dart';
import 'features/rashifal.dart';
import 'features/read.dart';
import 'features/ringtones.dart';
import 'features/search.dart';
import 'features/settings.dart';
import 'features/shell.dart';
import 'features/status_maker.dart';
import 'features/text_reader.dart';
import 'features/videos.dart';
import 'features/wallpapers.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Boxes.prefs.get('onboarded', defaultValue: false) == true ? '/home' : '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/listen', builder: (_, _) => const ListenScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/mandir', builder: (_, _) => const MandirScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/read', builder: (_, _) => const ReadScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/more', builder: (_, _) => const MoreScreen())],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/player',
        pageBuilder: (_, _) => const MaterialPage(fullscreenDialog: true, child: PlayerScreen()),
      ),
      GoRoute(
        path: '/text/:slug',
        builder: (_, s) => TextReaderScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/texts/:kind',
        builder: (_, s) => TextListScreen(kind: s.pathParameters['kind']!),
      ),
      GoRoute(path: '/gita', builder: (_, _) => const GitaScreen()),
      GoRoute(
        path: '/gita/:chapter',
        builder: (_, s) => GitaChapterScreen(
          chapter: int.parse(s.pathParameters['chapter']!),
          initialVerse: int.tryParse(s.uri.queryParameters['verse'] ?? ''),
        ),
      ),
      GoRoute(path: '/books', builder: (_, _) => const BooksScreen()),
      GoRoute(
        path: '/books/:slug',
        builder: (_, s) => BookScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/books/:slug/:n',
        builder: (_, s) =>
            BookChapterScreen(slug: s.pathParameters['slug']!, number: int.parse(s.pathParameters['n']!)),
      ),
      GoRoute(path: '/wallpapers', builder: (_, _) => const WallpapersScreen()),
      GoRoute(
        path: '/wallpaper',
        builder: (_, s) => WallpaperDetailScreen(wallpaper: s.extra! as Wallpaper),
      ),
      GoRoute(path: '/ringtones', builder: (_, _) => const RingtonesScreen()),
      GoRoute(path: '/status', builder: (_, _) => const StatusMakerScreen()),
      GoRoute(path: '/rashifal', builder: (_, _) => const RashifalScreen()),
      GoRoute(path: '/panchang', builder: (_, _) => const PanchangScreen()),
      GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
      GoRoute(path: '/japa', builder: (_, _) => const JapaScreen()),
      GoRoute(path: '/videos', builder: (_, _) => const VideosScreen()),
      GoRoute(
        path: '/video',
        builder: (_, s) => VideoPlayerScreen(video: s.extra! as Video),
      ),
      GoRoute(path: '/ask', builder: (_, _) => const AskGitaScreen()),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
      GoRoute(path: '/downloads', builder: (_, _) => const DownloadsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/premium', builder: (_, _) => const PremiumScreen()),
      GoRoute(path: '/credits', builder: (_, _) => const CreditsScreen()),
    ],
  );
});

class DevalayApp extends ConsumerWidget {
  const DevalayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    return MaterialApp.router(
      title: 'Devalay',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: prefs.themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: MediaQuery.of(context).textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.4)),
        child: child!,
      ),
    );
  }
}

/// Opens an in-app deep link such as `devalay://mandir` or `devalay://text/hanuman-chalisa`.
void openDeepLink(BuildContext context, String link) {
  if (!link.startsWith('devalay://')) return;
  final path = '/${link.substring('devalay://'.length)}';
  const tabs = {'/home', '/listen', '/mandir', '/read', '/more'};
  tabs.contains(path) ? context.go(path) : context.push(path);
}
