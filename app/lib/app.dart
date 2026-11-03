import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/firebase.dart';
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
      theme: buildTheme(Brightness.light, prefs.accent),
      darkTheme: buildTheme(Brightness.dark, prefs.accent),
      themeMode: prefs.themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: MediaQuery.of(context).textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.4)),
        child: _UpdateGate(child: child!),
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

/// Blocks the app when Remote Config says this build is too old (see core/firebase.dart).
class _UpdateGate extends ConsumerWidget {
  const _UpdateGate({required this.child});
  final Widget child;

  static const _title = {
    'te': 'కొత్త వెర్షన్ అందుబాటులో ఉంది',
    'hi': 'नया संस्करण उपलब्ध है',
    'en': 'Please update Devalay',
  };
  static const _body = {
    'te': 'దేవాలయం కొనసాగించడానికి దయచేసి తాజా వెర్షన్‌కు అప్‌డేట్ చేయండి.',
    'hi': 'देवालय का उपयोग जारी रखने के लिए कृपया नया संस्करण इंस्टॉल करें।',
    'en': 'This version is no longer supported. Please install the latest version to continue.',
  };
  static const _button = {'te': 'ఇప్పుడే అప్‌డేట్ చేయండి', 'hi': 'अभी अपडेट करें', 'en': 'Update now'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider).value;
    if (update == null || !update.required) return child;
    final lang = ref.watch(prefsProvider.select((p) => p.language));
    final message = update.message[lang] ?? '';
    return Material(
      color: Palette.maroon,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🛕', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              Text(
                _title[lang] ?? _title['en']!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                message.isNotEmpty ? message : (_body[lang] ?? _body['en']!),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Palette.gold, foregroundColor: Palette.maroon),
                onPressed: () => launchUrl(Uri.parse(update.url), mode: LaunchMode.externalApplication),
                child: Text(_button[lang] ?? _button['en']!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
