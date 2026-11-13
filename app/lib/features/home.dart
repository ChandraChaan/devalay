import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../core/audio.dart';
import '../core/i18n.dart';
import '../core/names.dart';
import '../core/location.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/telugu.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/mandala.dart';
import 'temples.dart';
import 'wishes.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(homeProvider.future),
          child: home.when(
            loading: () => const _HomeSkeleton(),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(homeProvider)),
            data: (data) => _HomeBody(data: data),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.data});
  final Map data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deity = data['deity_of_day'] == null ? null : Deity(data['deity_of_day'] as Map);
    final festivals = (data['upcoming_festivals'] as List).map((f) => Festival(f as Map)).toList();
    final verse = data['verse_of_day'] == null ? null : Verse(data['verse_of_day'] as Map);
    final tracks = (data['featured_tracks'] as List).map((t) => Track(t as Map)).toList();
    final aartis = (data['aartis'] as List).map((t) => TextSummary(t as Map)).toList();
    final walls = (data['wallpapers'] as List).map((w) => Wallpaper(w as Map)).toList();
    final banners = (data['banners'] as List).map((b) => HomeBanner(b as Map)).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Hero(deity: deity, panchang: data['panchang'] as Map),
        ),
        SliverToBoxAdapter(child: _QuickActions()),
        const SliverToBoxAdapter(child: BookingPromoCard()),
        const SliverToBoxAdapter(child: WishesPromoCard()),
        SliverToBoxAdapter(child: _TodaysSongs(serverDeity: deity)),
        if (banners.isNotEmpty) SliverToBoxAdapter(child: _Banners(banners: banners)),
        SliverToBoxAdapter(child: _PanchangCard(p: data['panchang'] as Map)),
        if (festivals.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              tr(ref, 'upcoming_festivals'),
              action: tr(ref, 'calendar'),
              onAction: () => context.push('/calendar'),
            ),
          ),
          SliverToBoxAdapter(child: _FestivalStrip(festivals: festivals)),
        ],
        if (verse != null) SliverToBoxAdapter(child: _VerseCard(verse: verse)),
        SliverToBoxAdapter(
          child: SectionHeader(tr(ref, 'featured'), action: tr(ref, 'see_all'), onAction: () => context.go('/listen')),
        ),
        SliverToBoxAdapter(child: _TrackStrip(tracks: tracks)),
        SliverToBoxAdapter(
          child: SectionHeader(
            tr(ref, 'aartis'),
            action: tr(ref, 'see_all'),
            onAction: () => context.push('/texts/aarti'),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: aartis.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                avatar: const Text('🪔'),
                label: Text(pick(ref, aartis[i].title, aartis[i].titleHi)),
                onPressed: () => context.push('/text/${aartis[i].slug}'),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionHeader(
            tr(ref, 'wallpapers'),
            action: tr(ref, 'see_all'),
            onAction: () => context.push('/wallpapers'),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: walls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => context.push('/wallpaper', extra: walls[i]),
                child: Hero(
                  tag: 'wall-${walls[i].id}',
                  child: SizedBox(
                    width: 140,
                    child: NetImage(walls[i].thumbUrl, radius: 18, color: Palette.hex(walls[i].color)),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

String greetingKey() {
  final h = DateTime.now().hour;
  if (h < 4) return 'good_night';
  if (h < 12) return 'good_morning';
  if (h < 17) return 'good_afternoon';
  if (h < 21) return 'good_evening';
  return 'good_night';
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.deity, required this.panchang});
  final Deity? deity;
  final Map panchang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    final tithi = panchang['tithi'] as Map;
    final month = panchang['lunar_month'] as Map;
    final lang = ref.watch(prefsProvider).language;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: Palette.sunrise, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(right: -70, top: -40, child: Mandala(size: 260, opacity: 0.18)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tr(ref, greetingKey())} 🙏',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/search'),
                    icon: const Icon(Icons.search_rounded, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
                  ),
                ],
              ),
              Text(
                lang == 'te'
                    ? '${teluguVara['${panchang['vara']}'] ?? ''} · ${teluguPaksha[tithi['paksha']] ?? ''} '
                          '${teluguTithi[tithi['name']] ?? ''} · ${teluguMonths[month['index'] as int]} మాసం'
                          '${panchang['samvatsara'] is Map ? ' · ${teluguSamvatsara[(panchang['samvatsara'] as Map)['index'] as int]} నామ సంవత్సరం' : ''}'
                    : lang == 'en'
                    ? '${panchang['vara']} · ${tithi['paksha']} ${tithi['name']} · ${month['name']}'
                          '${month['adhika'] == true ? ' (Adhik)' : ''} · VS ${panchang['vikram_samvat']}'
                    : '${varaIn(lang, '${panchang['vara']}')} · ${pakshaIn(lang, '${tithi['paksha']}')} '
                          '${tithiIn(lang, '${tithi['name']}')} · ${monthIn(lang, month['index'] as int)}'
                          '${panchang['samvatsara'] is Map ? ' · ${samvatsaraIn(lang, (panchang['samvatsara'] as Map)['index'] as int, '${(panchang['samvatsara'] as Map)['name']}')}' : ''}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              if (deity != null)
                GestureDetector(
                  onTap: () => context.go('/mandir'),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'deity-${deity!.slug}',
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Palette.gold, width: 3),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
                          ),
                          child: ClipOval(child: NetImage(deity!.imageUrl)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t3(lang, 'Deity of the day', 'आज के देवता', 'నేటి దైవం'),
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            Text(
                              deity!.label(lang),
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              deity!.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.15),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      ('🪔', 'mandir', '/mandir', true),
      ('🎟️', 'booking', '/temples', false),
      ('📿', 'japa', '/japa', false),
      ('🔮', 'rashifal', '/rashifal', false),
      ('📖', 'gita', '/gita', false),
      ('✨', 'ai_status', '/status', false),
      ('🔔', 'ringtones', '/ringtones', false),
      ('📅', 'calendar', '/calendar', false),
      ('🙋', 'ask_gita', '/ask', false),
      ('🎬', 'videos', '/bhakti-videos', false),
      ('🗓️', 'panchang', '/panchang', false),
      ('🖼️', 'wallpapers', '/wallpapers', false),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: GridView.count(
        padding: EdgeInsets.zero,
        crossAxisCount: (MediaQuery.sizeOf(context).width / 96).floor().clamp(4, 8),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.92,
        children: [
          for (final (i, (emoji, key, route, tab)) in actions.indexed)
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => tab ? context.go(route) : context.push(route),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Palette.marigold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(ref, key),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (40 * i).ms).scale(begin: const Offset(0.9, 0.9)),
        ],
      ),
    );
  }
}

class _Banners extends StatelessWidget {
  const _Banners({required this.banners});
  final List<HomeBanner> banners;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: PageView(
        controller: PageController(viewportFraction: 0.92),
        children: [
          for (final b in banners)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
              child: GradientCard(
                colors: Palette.dusk,
                padding: 16,
                onTap: () => openDeepLink(context, b.deepLink),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            b.title,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            b.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                    const Text('🛕', style: TextStyle(fontSize: 34)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PanchangCard extends ConsumerWidget {
  const _PanchangCard({required this.p});
  final Map p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityProvider);
    final lang = ref.watch(prefsProvider).language;
    Widget cell(String label, String value, IconData icon) => Expanded(
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final tithi = p['tithi'] as Map;
    final nak = p['nakshatra'] as Map;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/panchang'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tr(ref, 'today_panchang'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Icon(Icons.place_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
                    Text(city.label(lang), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    cell(tr(ref, 'tithi'), tithiIn(lang, '${tithi['name']}'), Icons.brightness_3_rounded),
                    cell(tr(ref, 'nakshatra'), nakshatraIn(lang, '${nak['name']}'), Icons.auto_awesome_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    cell(tr(ref, 'sunrise'), hhmm('${p['sunrise']}'), Icons.wb_twilight_rounded),
                    cell(tr(ref, 'sunset'), hhmm('${p['sunset']}'), Icons.nights_stay_outlined),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    cell(
                      tr(ref, 'rahu_kaal'),
                      '${hhmm('${(p['rahu_kaal'] as Map)['starts']}')} – ${hhmm('${(p['rahu_kaal'] as Map)['ends']}')}',
                      Icons.do_not_disturb_on_outlined,
                    ),
                    cell(
                      tr(ref, 'abhijit'),
                      '${hhmm('${(p['abhijit_muhurta'] as Map)['starts']}')} – ${hhmm('${(p['abhijit_muhurta'] as Map)['ends']}')}',
                      Icons.star_outline_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1);
  }
}

class _FestivalStrip extends ConsumerWidget {
  const _FestivalStrip({required this.festivals});
  final List<Festival> festivals;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    return SizedBox(
      height: 124,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: festivals.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final f = festivals[i];
          final days = f.daysFrom(now);
          final when = days == 0
              ? tr(ref, 'today')
              : days == 1
              ? tr(ref, 'tomorrow')
              : '$days ${tr(ref, 'days_left')}';
          return SizedBox(
            width: 200,
            child: GradientCard(
              colors: i.isEven ? Palette.dusk : Palette.sunrise,
              padding: 14,
              onTap: () => context.push('/calendar'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    when,
                    style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    f.label(uiLang(ref)),
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
                  ),
                  Text('${f.date.day}/${f.date.month}/${f.date.year}', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VerseCard extends ConsumerWidget {
  const _VerseCard({required this.verse});
  final Verse verse;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/gita/${verse.chapter}?verse=${verse.verse}'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('📜', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(ref, 'verse_of_day'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${verse.chapter}.${verse.verse}',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      tooltip: l3(ref, 'Listen', 'सुनें', 'వినండి'),
                      onPressed: () => context.push('/gita/${verse.chapter}?verse=${verse.verse}&play=1'),
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(scriptFor(uiLang(ref), verse.sanskrit), style: scriptureStyle(context, size: 18)),
                const SizedBox(height: 10),
                Text(verse.translation, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
}

class _TrackStrip extends ConsumerWidget {
  const _TrackStrip({required this.tracks});
  final List<Track> tracks;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final t = tracks[i];
          return GestureDetector(
            onTap: () => ref.read(audioProvider).playQueue(tracks, index: i),
            child: SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      SizedBox(width: 140, height: 140, child: NetImage(t.artworkUrl, radius: 20)),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.play_arrow_rounded, color: Palette.saffron),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.label(uiLang(ref)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      SizedBox(height: 40),
      SkeletonBox(height: 180),
      SizedBox(height: 16),
      SkeletonBox(height: 160),
      SizedBox(height: 16),
      SkeletonBox(height: 140),
      SizedBox(height: 16),
      SkeletonBox(height: 120),
    ],
  );
}

/// "Monday: Shiva's songs". Each weekday belongs to a deity; Telugu homes keep Saturday for
/// Venkateswara, so Telugu users get that map and everyone else gets the server's deity of the day.
class _TodaysSongs extends ConsumerWidget {
  const _TodaysSongs({required this.serverDeity});
  final Deity? serverDeity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(prefsProvider).language;
    final weekday = DateTime.now().weekday - 1;
    final slug = lang == 'te' ? teluguWeekdayDeity[weekday] : (serverDeity?.slug ?? 'general');
    final deities = ref.watch(deitiesProvider).value ?? const <Deity>[];
    final deity = deities.where((d) => d.slug == slug).firstOrNull ?? serverDeity;
    final tracks = ref.watch(tracksProvider((kind: null, deity: slug))).value ?? const <Track>[];
    if (tracks.isEmpty || deity == null) return const SizedBox.shrink();
    final day = fmtDate(lang, 'EEEE', DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          t3(
            lang,
            '$day · ${deity.label(lang)} songs',
            '$day · ${deity.label(lang)} के भजन',
            '$day · ${deity.label(lang)} పాటలు',
          ),
          action: t3(lang, 'Play all', 'सब चलाएँ', 'అన్నీ ప్లే'),
          onAction: () => ref.read(audioProvider).playQueue(tracks, index: 0),
        ),
        _TrackStrip(tracks: tracks),
      ],
    );
  }
}
