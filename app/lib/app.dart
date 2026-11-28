import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_care.dart';
import 'core/billing.dart';
import 'core/firebase.dart';
import 'core/i18n.dart';
import 'core/languages.dart';
import 'core/models.dart';
import 'core/perks.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'features/admin.dart';
import 'features/ask_gita.dart';
import 'features/backup.dart';
import 'features/bhakti_videos.dart';
import 'features/auth_screens.dart';
import 'features/books.dart';
import 'features/credits.dart';
import 'features/feedback.dart';
import 'features/gita.dart';
import 'features/home.dart';
import 'features/important_days.dart';
import 'features/japa.dart';
import 'features/library.dart';
import 'features/chant.dart';
import 'features/listen.dart';
import 'features/mandir.dart';
import 'features/matching.dart';
import 'features/more.dart';
import 'features/my_events.dart';
import 'features/onboarding.dart';
import 'features/calendar.dart';
import 'features/panchang.dart';
import 'features/player.dart';
import 'features/pooja.dart';
import 'features/premium.dart';
import 'features/profile.dart';
import 'features/support.dart';
import 'features/support_chat.dart';
import 'features/jatakam.dart';
import 'features/rashifal.dart';
import 'features/shubha_muhurtham.dart';
import 'features/read.dart';
import 'features/ringtones.dart';
import 'features/search.dart';
import 'features/settings.dart';
import 'features/shell.dart';
import 'features/ai_status.dart';
import 'features/temples.dart';
import 'features/text_reader.dart';
import 'features/videos.dart';
import 'features/wallpaper_gallery.dart';
import 'features/wallpapers.dart';
import 'features/meditation.dart';
import 'features/movie_songs.dart';
import 'features/whatsapp_status.dart';
import 'features/wishes.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Boxes.prefs.get('onboarded', defaultValue: false) == true ? '/home' : '/onboarding',
    // Safety net: a devalay://calendar link that reaches the router maps to /calendar.
    redirect: (_, state) => state.uri.scheme == 'devalay'
        ? '/${state.uri.host}${state.uri.path}'.replaceFirst(RegExp(r'(?<=.)/+$'), '')
        : null,
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
          autoPlay: s.uri.queryParameters['play'] == '1',
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
      GoRoute(
        path: '/wallpapers',
        builder: (_, s) => WallpaperGalleryScreen(openId: s.uri.queryParameters['id']),
      ),
      GoRoute(
        path: '/wallpaper',
        builder: (_, s) => WallpaperDetailScreen(wallpaper: s.extra! as Wallpaper),
      ),
      GoRoute(path: '/ringtones', builder: (_, _) => const RingtonesScreen()),
      GoRoute(
        path: '/songs',
        builder: (_, s) => ListenBrowseScreen(kind: s.uri.queryParameters['kind']),
      ),
      GoRoute(path: '/chant', builder: (_, _) => const ChantScreen()),
      GoRoute(
        path: '/status',
        builder: (_, s) => StatusMakerScreen(
          template: s.uri.queryParameters['template'],
          variant: int.tryParse(s.uri.queryParameters['variant'] ?? '') ?? 0,
        ),
      ),
      GoRoute(path: '/movie-songs', builder: (_, _) => const MovieSongsScreen()),
      GoRoute(path: '/meditation', builder: (_, _) => const MeditationScreen()),
      GoRoute(
        path: '/whatsapp-status',
        builder: (_, s) => WhatsAppStatusScreen(openId: s.uri.queryParameters['id']),
      ),
      GoRoute(path: '/rashifal', builder: (_, _) => const RashifalScreen()),
      GoRoute(path: '/panchang', builder: (_, _) => const PanchangScreen()),
      GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
      GoRoute(path: '/calendar/important', builder: (_, _) => const ImportantDaysScreen()),
      GoRoute(path: '/calendar/events', builder: (_, _) => const MyEventsScreen()),
      GoRoute(path: '/matching', builder: (_, _) => const MatchingScreen()),
      GoRoute(path: '/jatakam', builder: (_, _) => const JatakamScreen()),
      GoRoute(
        path: '/muhurtham',
        builder: (_, s) => ShubhaMuhurthamScreen(kind: s.uri.queryParameters['kind']),
      ),
      GoRoute(path: '/pooja', builder: (_, _) => const PoojaGuidesScreen()),
      GoRoute(
        path: '/pooja/:id',
        builder: (_, s) => PoojaGuideScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/calendar/day/:date',
        builder: (_, s) =>
            CalendarDayScreen(date: DateTime.tryParse(s.pathParameters['date']!) ?? DateUtils.dateOnly(DateTime.now())),
      ),
      GoRoute(path: '/temples', builder: (_, _) => const TemplesScreen()),
      GoRoute(
        path: '/temples/:id',
        builder: (_, s) => TempleScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/wishes', builder: (_, _) => const WishesScreen()),
      GoRoute(
        path: '/wishes/:id',
        builder: (_, s) => WishEditorScreen(id: s.pathParameters['id']!, themeId: s.uri.queryParameters['theme']),
      ),
      GoRoute(path: '/japa', builder: (_, _) => const JapaScreen()),
      GoRoute(path: '/videos', builder: (_, _) => const VideosScreen()),
      GoRoute(path: '/bhakti-videos', builder: (_, _) => const BhaktiVideosScreen()),
      GoRoute(
        path: '/video',
        builder: (_, s) => VideoPlayerScreen(video: s.extra! as Video),
      ),
      GoRoute(path: '/ask', builder: (_, _) => const AskGitaScreen()),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
      GoRoute(path: '/downloads', builder: (_, _) => const DownloadsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/backup', builder: (_, _) => const BackupScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/premium',
        builder: (_, s) => PremiumScreen(source: s.uri.queryParameters['from'] ?? ''),
      ),
      GoRoute(path: '/support/chat', builder: (_, _) => const SupportChatScreen()),
      GoRoute(
        path: '/support',
        builder: (_, s) => SupportScreen(source: s.uri.queryParameters['from'] ?? 'more'),
      ),
      GoRoute(path: '/credits', builder: (_, _) => const CreditsScreen()),
      GoRoute(path: '/feedback', builder: (_, _) => const FeedbackScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
    ],
  );
  // Screen views for Firebase Analytics. A delegate listener (rather than a NavigatorObserver) also
  // sees switches between the bottom tabs, which StatefulShellRoute keeps in one navigator each.
  void track() {
    final matches = router.routerDelegate.currentConfiguration;
    if (matches.isNotEmpty) FirebaseServices.logScreen(screenPattern(matches));
  }

  router.routerDelegate.addListener(track);
  ref.onDispose(() => router.routerDelegate.removeListener(track));
  return router;
});

class DevalayApp extends ConsumerWidget {
  const DevalayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    // Watching billing here also connects to Google Play once, shortly after start.
    final accent = unlocked(
      prefs.accent,
      isPremiumItem: prefs.accent.premium,
      premium: ref.watch(premiumProvider),
      free: Accent.saffron,
    );
    return MaterialApp.router(
      title: 'Devalay',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, accent),
      darkTheme: buildTheme(Brightness.dark, accent),
      themeMode: prefs.themeMode,
      // Material's own text (date and time pickers, tooltips) follows the app language.
      locale: languageOf(prefs.language).locale,
      supportedLocales: [for (final l in appLanguages) l.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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

/// The route pattern of the screen on top. A pushed screen (context.push('/panchang')) sits in an
/// [ImperativeRouteMatch]; the list's own fullPath still names the tab underneath it, which is why
/// only the five tabs used to be logged.
String screenPattern(RouteMatchList matches) {
  final top = matches.matches.isEmpty ? null : matches.matches.last;
  return top is ImperativeRouteMatch ? screenPattern(top.matches) : matches.fullPath;
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
              const Text('🛕', style: TextStyle(fontSize: 64))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1600.ms),
              const SizedBox(height: 24),
              Text(
                t3(lang, 'Please update Devalay', 'नया संस्करण उपलब्ध है', 'కొత్త వెర్షన్ అందుబాటులో ఉంది'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                message.isNotEmpty
                    ? message
                    : t3(
                        lang,
                        'This version is no longer supported. Please install the latest version to continue.',
                        'देवालय का उपयोग जारी रखने के लिए कृपया नया संस्करण इंस्टॉल करें।',
                        'దేవాలయం కొనసాగించడానికి దయచేసి తాజా వెర్షన్‌కు అప్‌డేట్ చేయండి.',
                      ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Palette.gold, foregroundColor: Palette.maroon),
                onPressed: () => performForcedUpdate(update.url),
                child: Text(t3(lang, 'Update now', 'अभी अपडेट करें', 'ఇప్పుడే అప్‌డేట్ చేయండి')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
