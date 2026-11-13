import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n.dart';
import '../core/names.dart';
import '../core/models.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../core/wishes.dart';
import '../widgets/common.dart';
import '../widgets/wish_card.dart';
import 'status_maker.dart' show renderStatusImage, saveToGallery;

/// Festival wishes: pick a festival, a theme and a layout, add your name and photo, and share the
/// card (usually to WhatsApp status). The photo is read from this phone and never uploaded.

String _from(String lang) => t3(lang, 'With best wishes', 'शुभकामनाओं सहित', 'శుభాకాంక్షలతో');

/// Fills `{year}` in a caption with the year of the celebration.
String fillCaption(String text, DateTime? date, DateTime now) => text.replaceAll('{year}', '${(date ?? now).year}');

/// "Today", "Tomorrow", "In 12 days · 24 Nov"; empty when the date is unknown.
String whenLabel(DateTime? date, DateTime now, String lang) {
  if (date == null) return '';
  final days = daysUntil(date, now);
  if (days < 0) return t3(lang, 'On now', 'जारी है', 'జరుగుతోంది');
  if (days == 0) return trLang(lang, 'today');
  if (days == 1) return trLang(lang, 'tomorrow');
  final day = fmtDate(lang, 'd MMM', date);
  return t3(lang, 'In $days days · $day', '$days दिन में · $day', '$days రోజుల్లో · $day');
}

/// A card with the set's first theme and default words, signed with the remembered name and photo.
WishCardData previewData(WishFestival festival, WishTheme theme, String lang, DateTime now, {DateTime? date}) {
  final photo = WishProfile.photo;
  return WishCardData(
    theme: theme,
    layout: theme.layout,
    caption: fillCaption(festival.captionsFor(now).first.text(lang), date, now),
    name: WishProfile.name,
    fromLabel: _from(lang),
    photo: photo == null ? null : FileImage(photo),
    view: WishProfile.view,
    symbol: festival.symbol,
  );
}

class WishesScreen extends ConsumerWidget {
  const WishesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final catalog = ref.watch(wishCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'wishes'))),
      body: catalog.when(
        loading: () => const LoadingList(count: 4, height: 140),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(wishCatalogProvider)),
        data: (catalog) {
          final now = ref.watch(wishClockProvider)();
          final upcoming = upcomingWishes(catalog, ref.watch(wishCalendarProvider), now);
          final festivals = upcoming.where((w) => w.festival.kind == 'festival' || w.date != null).toList();
          final occasions = upcoming.where((w) => !festivals.contains(w)).toList();
          final first = festivals.where((w) => w.date != null).firstOrNull;
          final daily = catalog.daily;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              if (first != null) _FeaturedWish(wish: first, now: now),
              if (daily != null) ...[const SizedBox(height: 12), _DailyTile(festival: daily, now: now)],
              SectionHeader(t3(lang, 'Festivals', 'त्योहार', 'పండుగలు')),
              _WishGrid(
                wishes: [
                  for (final w in festivals)
                    if (w != first) w,
                ],
                now: now,
              ),
              if (occasions.isNotEmpty) ...[
                SectionHeader(t3(lang, 'Any day', 'किसी भी दिन', 'ఏ రోజైనా')),
                _WishGrid(wishes: occasions, now: now),
              ],
              const SizedBox(height: 20),
              const _PrivacyNote(),
            ],
          );
        },
      ),
    );
  }
}

class _FeaturedWish extends ConsumerWidget {
  const _FeaturedWish({required this.wish, required this.now});
  final DatedWish wish;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final f = wish.festival;
    final theme = f.themes.first;
    return GradientCard(
      colors: theme.colors,
      padding: 16,
      onTap: () => context.push('/wishes/${f.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  whenLabel(wish.date, now, lang),
                  style: TextStyle(color: theme.accent, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${f.emoji} ${f.name(lang)}',
                  style: TextStyle(color: theme.ink, fontSize: 22, fontWeight: FontWeight.w800, height: 1.15),
                ),
                const SizedBox(height: 6),
                Text(
                  t3(
                    lang,
                    'Make a wishes card with your photo and name, and share it on your status.',
                    'अपनी फ़ोटो और नाम के साथ शुभकामना कार्ड बनाएँ और स्टेटस पर लगाएँ।',
                    'మీ ఫోటో, పేరుతో శుభాకాంక్షల కార్డు తయారు చేసి స్టేటస్‌లో పెట్టండి.',
                  ),
                  style: TextStyle(color: theme.ink.withValues(alpha: 0.85), height: 1.3),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: theme.accent.computeLuminance() > 0.4 ? Palette.ink : Colors.white,
                  ),
                  onPressed: () => context.push('/wishes/${f.id}'),
                  icon: const Icon(Icons.brush_rounded),
                  label: Text(t3(lang, 'Make card', 'कार्ड बनाएँ', 'కార్డు చేయండి')),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            height: 171,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _Thumb(festival: f, theme: theme, date: wish.date, now: now),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small card preview with the festival's own painting.
class _Thumb extends ConsumerWidget {
  const _Thumb({required this.festival, required this.theme, required this.now, this.date});
  final WishFestival festival;
  final WishTheme theme;
  final DateTime now;
  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deity = theme.deity ?? festival.deity(now);
    final paintings = deity.isEmpty ? null : ref.watch(wishPaintingsProvider(deity)).value;
    final data = previewData(festival, theme, uiLang(ref), now, date: date);
    return WishCard(
      WishCardData(
        theme: data.theme,
        layout: data.layout,
        caption: data.caption,
        name: data.name,
        fromLabel: data.fromLabel,
        photo: data.photo,
        view: data.view,
        symbol: data.symbol,
        painting: paintings?.firstOrNull?.imageUrl,
      ),
    );
  }
}

class _DailyTile extends ConsumerWidget {
  const _DailyTile({required this.festival, required this.now});
  final WishFestival festival;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final theme = festival.themes.first;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        leading: SizedBox(
          width: 40,
          height: 71,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _Thumb(festival: festival, theme: theme, now: now),
          ),
        ),
        title: Text(festival.captionsFor(now).first.text(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          t3(
            lang,
            "Today's blessing card, with the deity of the day",
            'आज का आशीर्वाद कार्ड, आज के देवता के साथ',
            'నేటి దైవంతో ఈ రోజు ఆశీస్సుల కార్డు',
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/wishes/${festival.id}'),
      ),
    );
  }
}

class _WishGrid extends ConsumerWidget {
  const _WishGrid({required this.wishes, required this.now});
  final List<DatedWish> wishes;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    return LayoutBuilder(
      builder: (context, box) {
        final columns = (box.maxWidth / 170).floor().clamp(2, 5);
        final width = (box.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final w in wishes)
              SizedBox(
                width: width,
                height: 112,
                child: GradientCard(
                  colors: w.festival.themes.first.colors,
                  padding: 12,
                  radius: 20,
                  onTap: () => context.push('/wishes/${w.festival.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.festival.emoji, style: const TextStyle(fontSize: 24)),
                      const Spacer(),
                      Text(
                        w.festival.name(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: w.festival.themes.first.ink, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      Text(
                        w.date == null
                            ? t3(
                                lang,
                                '${w.festival.themes.length} themes',
                                '${w.festival.themes.length} थीम',
                                '${w.festival.themes.length} థీమ్‌లు',
                              )
                            : whenLabel(w.date, now, lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: w.festival.themes.first.ink.withValues(alpha: 0.8), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PrivacyNote extends ConsumerWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 18, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l3(
              ref,
              'Your photo stays on this phone. Devalay never uploads it; only the card you share leaves your phone, '
                  'to the app you choose.',
              'आपकी फ़ोटो इसी फ़ोन में रहती है। देवालय उसे कभी अपलोड नहीं करता; केवल वह कार्ड जिसे आप शेयर करते हैं, '
                  'आपके चुने ऐप तक जाता है।',
              'మీ ఫోటో ఈ ఫోన్‌లోనే ఉంటుంది. దేవాలయం దాన్ని ఎప్పుడూ అప్‌లోడ్ చేయదు; మీరు షేర్ చేసే కార్డు మాత్రమే '
                  'మీరు ఎంచుకున్న యాప్‌కు వెళ్తుంది.',
            ),
            style: TextStyle(color: muted, fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// Edits one card: theme, layout, painting, words and photo; then saves or shares it.
class WishEditorScreen extends ConsumerStatefulWidget {
  const WishEditorScreen({super.key, required this.id, this.themeId});
  final String id;
  final String? themeId;

  @override
  ConsumerState<WishEditorScreen> createState() => _WishEditorScreenState();
}

class _WishEditorScreenState extends ConsumerState<WishEditorScreen> {
  final _boundary = GlobalKey();
  final _caption = TextEditingController();
  final _message = TextEditingController();
  final _name = TextEditingController(text: WishProfile.name);
  final _line2 = TextEditingController();
  late String _lang = ref.read(prefsProvider).language;
  bool _ready = false;
  int _theme = 0;
  WishLayout? _layout;
  int _captionIndex = 0;
  int? _wishIndex = 0;
  String _captionDefault = '', _messageDefault = '';
  File? _photo = WishProfile.photo;
  PhotoView _view = WishProfile.view;
  String? _painting;
  bool _noPainting = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_caption, _message, _name, _line2]) {
      c.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    WishProfile.setName(_name.text);
    for (final c in [_caption, _message, _name, _line2]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Puts the default caption and wish for the chosen language in place, unless the user has
  /// written their own.
  void _applyDefaults(WishFestival f, DateTime? date, DateTime now) {
    final captions = f.captionsFor(now);
    final caption = fillCaption(captions[_captionIndex.clamp(0, captions.length - 1)].text(_lang), date, now);
    if (_caption.text == _captionDefault) _caption.text = caption;
    _captionDefault = caption;
    final wishes = f.wishesFor(now);
    final message = _wishIndex == null || wishes.isEmpty
        ? ''
        : wishes[_wishIndex!.clamp(0, wishes.length - 1)].text(_lang);
    if (_message.text == _messageDefault) _message.text = message;
    _messageDefault = message;
  }

  WishCardData _data(WishFestival f, WishTheme theme, {WishLayout? layout, String? painting}) => WishCardData(
    theme: theme,
    layout: layout ?? _layout ?? theme.layout,
    caption: _caption.text.trim(),
    message: _message.text.trim(),
    name: _name.text.trim(),
    line2: _line2.text.trim(),
    fromLabel: _from(_lang),
    photo: _photo == null ? null : FileImage(_photo!),
    view: _view,
    painting: painting,
    symbol: f.symbol,
  );

  Future<void> _pickPhoto() async {
    try {
      final file = await ref.read(wishPhotoPickerProvider)();
      if (file == null || !mounted) return;
      unawaited(WishProfile.setPhoto(file));
      setState(() {
        _photo = file;
        _view = PhotoView.initial;
      });
    } catch (e) {
      if (mounted) toast(context, t3(_lang, 'Could not open photos', 'फ़ोटो नहीं खुलीं', 'ఫోటోలు తెరవలేకపోయాం'));
    }
  }

  void _removePhoto() {
    unawaited(WishProfile.setPhoto(null));
    setState(() {
      _photo = null;
      _view = PhotoView.initial;
    });
  }

  Future<File?> _render() async {
    FocusScope.of(context).unfocus();
    unawaited(WishProfile.setName(_name.text));
    // Let the preview settle after the keyboard closes.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return null;
    return renderStatusImage(_boundary, prefix: 'devalay-wish');
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final file = await _render();
      if (file != null) {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')]));
      }
    } catch (e) {
      if (mounted) toast(context, t3(appLang, 'Could not share: $e', 'शेयर नहीं हो सका: $e', 'షేర్ కాలేదు: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final file = await _render();
      if (file == null) return;
      await saveToGallery(file);
      HapticFeedback.mediumImpact();
      if (mounted) {
        toast(
          context,
          t3(_lang, 'Saved to Pictures/Devalay', 'Pictures/Devalay में सेव हुआ', 'Pictures/Devalay లో సేవ్ అయింది'),
        );
      }
    } catch (e) {
      if (mounted) toast(context, t3(appLang, 'Could not save: $e', 'सहेजा नहीं जा सका: $e', 'సేవ్ కాలేదు: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = uiLang(ref);
    final catalog = ref.watch(wishCatalogProvider).value;
    final festival = catalog?.byId(widget.id);
    if (catalog == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (festival == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.celebration_rounded,
          title: t3(ui, 'This card is not available', 'यह कार्ड उपलब्ध नहीं है', 'ఈ కార్డు అందుబాటులో లేదు'),
        ),
      );
    }
    final now = ref.watch(wishClockProvider)();
    final date = festival.nextDate(ref.watch(wishCalendarProvider), now);
    if (!_ready) {
      _ready = true;
      _theme = widget.themeId == null ? 0 : festival.themes.indexWhere((t) => t.id == widget.themeId).clamp(0, 999);
      _applyDefaults(festival, date, now);
    }
    _theme = _theme.clamp(0, festival.themes.length - 1);
    final theme = festival.themes[_theme];
    final deity = theme.deity ?? festival.deity(now);
    final own = deity.isEmpty ? const <Wallpaper>[] : ref.watch(wishPaintingsProvider(deity)).value ?? const [];
    // The festival's deity first, then every other painting to choose from.
    final paintings = [
      ...own,
      for (final w in ref.watch(wishPaintingsProvider('')).value ?? const <Wallpaper>[])
        if (!own.any((o) => o.id == w.id)) w,
    ];
    final painting = _noPainting ? null : (_painting ?? own.firstOrNull?.imageUrl);
    final data = _data(festival, theme, painting: painting);

    return Scaffold(
      appBar: AppBar(title: Text(festival.name(ui))),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RepaintBoundary(
                          key: _boundary,
                          child: WishCard(
                            data,
                            onView: (v) => setState(() => _view = v),
                            onViewEnd: () => WishProfile.setView(_view),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            TabBar(
              tabs: [
                Tab(text: t3(ui, 'Design', 'डिज़ाइन', 'డిజైన్')),
                Tab(text: t3(ui, 'Words', 'शब्द', 'అక్షరాలు')),
                Tab(text: t3(ui, 'Photo', 'फ़ोटो', 'ఫోటో')),
              ],
            ),
            Expanded(
              flex: 4,
              child: TabBarView(
                children: [_design(festival, paintings, painting, ui), _words(festival, date, now, ui), _photoTab(ui)],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.download_rounded),
                        label: Text(t3(ui, 'Save', 'सेव', 'సేవ్')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _share,
                        icon: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.share_rounded),
                        label: Text(t3(ui, 'Share to status', 'स्टेटस पर शेयर', 'స్టేటస్‌కు షేర్')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
  );

  Widget _choice({required bool selected, required VoidCallback onTap, required Widget child, String? label}) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 3),
              ),
              child: ClipRRect(borderRadius: BorderRadius.circular(6), child: child),
            ),
          ),
          if (label != null)
            SizedBox(
              width: 84,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _design(WishFestival f, List<Wallpaper> paintings, String? painting, String ui) {
    final theme = f.themes[_theme];
    final layout = _layout ?? theme.layout;
    return ListView(
      key: const ValueKey('wish-design-list'),
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _label(t3(ui, 'Theme', 'थीम', 'థీమ్')),
        SizedBox(
          height: 150,
          child: ListView.separated(
            key: const ValueKey('wish-themes'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: f.themes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(
              width: 76,
              child: _choice(
                selected: i == _theme,
                onTap: () => setState(() => _theme = i),
                label: f.themes[i].name(ui),
                child: WishCard(_data(f, f.themes[i], layout: _layout ?? f.themes[i].layout, painting: painting)),
              ),
            ),
          ),
        ),
        _label(t3(ui, 'Layout', 'लेआउट', 'లేఅవుట్')),
        SizedBox(
          height: 150,
          child: ListView.separated(
            key: const ValueKey('wish-layouts'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: WishLayout.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final l = WishLayout.values[i];
              return SizedBox(
                width: 76,
                child: _choice(
                  selected: l == layout,
                  onTap: () => setState(() => _layout = l),
                  label: l.label(ui),
                  child: WishCard(_data(f, theme, layout: l, painting: painting)),
                ),
              );
            },
          ),
        ),
        _label(t3(ui, 'Picture', 'चित्र', 'చిత్రం')),
        SizedBox(
          height: 96,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: paintings.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return SizedBox(
                  width: 64,
                  child: _choice(
                    selected: painting == null,
                    onTap: () => setState(() {
                      _noPainting = true;
                      _painting = null;
                    }),
                    child: ColoredBox(
                      color: theme.colors.last,
                      child: Center(
                        child: Text(
                          f.symbol,
                          style: TextStyle(fontFamily: scriptureFont, fontSize: 24, color: theme.accent),
                        ),
                      ),
                    ),
                  ),
                );
              }
              final w = paintings[i - 1];
              return SizedBox(
                width: 64,
                child: _choice(
                  selected: painting == w.imageUrl,
                  onTap: () => setState(() {
                    _noPainting = false;
                    _painting = w.imageUrl;
                  }),
                  child: NetImage(w.thumbUrl),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            t3(
              ui,
              'Paintings are public-domain works, such as Raja Ravi Varma prints.',
              'चित्र सार्वजनिक डोमेन की कृतियाँ हैं, जैसे राजा रवि वर्मा के प्रिंट।',
              'చిత్రాలు పబ్లిక్ డొమైన్ కృతులు, రాజా రవివర్మ ప్రింట్ల వంటివి.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _words(WishFestival f, DateTime? date, DateTime now, String ui) {
    final captions = f.captionsFor(now);
    final wishes = f.wishesFor(now);
    return ListView(
      key: const ValueKey('wish-words-list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'en', label: Text('English')),
            ButtonSegment(value: 'hi', label: Text('हिन्दी')),
            ButtonSegment(value: 'te', label: Text('తెలుగు')),
          ],
          selected: {_lang},
          onSelectionChanged: (s) => setState(() {
            _lang = s.first;
            _applyDefaults(f, date, now);
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('wish-caption'),
          controller: _caption,
          maxLength: 60,
          decoration: InputDecoration(labelText: t3(ui, 'Caption', 'शीर्षक', 'శీర్షిక')),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (i, c) in captions.indexed)
              ChoiceChip(
                label: Text(fillCaption(c.text(_lang), date, now)),
                selected: _caption.text == fillCaption(c.text(_lang), date, now),
                onSelected: (_) => setState(() {
                  _captionIndex = i;
                  _caption.text = _captionDefault = fillCaption(c.text(_lang), date, now);
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('wish-name'),
          controller: _name,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: t3(ui, 'Your name', 'आपका नाम', 'మీ పేరు'),
            helperText: t3(
              ui,
              'Remembered on this phone for your next card',
              'अगले कार्ड के लिए इसी फ़ोन में याद रहेगा',
              'తదుపరి కార్డు కోసం ఈ ఫోన్‌లోనే గుర్తుంటుంది',
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('wish-line2'),
          controller: _line2,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: t3(ui, 'Second line (optional)', 'दूसरी पंक्ति (वैकल्पिक)', 'రెండో వరుస (ఐచ్ఛికం)'),
            hintText: t3(ui, '& family', 'एवं परिवार', 'మరియు కుటుంబం'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('wish-message'),
          controller: _message,
          maxLength: 160,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(labelText: t3(ui, 'Message', 'संदेश', 'సందేశం')),
        ),
        Text(
          t3(ui, 'Ready-made wishes', 'तैयार शुभकामनाएँ', 'సిద్ధంగా ఉన్న శుభాకాంక్షలు'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final (i, w) in wishes.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                title: Text(w.text(_lang), style: const TextStyle(height: 1.35)),
                trailing: _message.text == w.text(_lang)
                    ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => setState(() {
                  _wishIndex = i;
                  _message.text = _messageDefault = w.text(_lang);
                }),
              ),
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() {
            _wishIndex = null;
            _message.text = _messageDefault = '';
          }),
          icon: const Icon(Icons.format_clear_rounded),
          label: Text(t3(ui, 'No message', 'कोई संदेश नहीं', 'సందేశం వద్దు')),
        ),
      ],
    );
  }

  Widget _photoTab(String ui) {
    final photo = _photo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        if (photo == null)
          FilledButton.tonalIcon(
            key: const ValueKey('wish-add-photo'),
            onPressed: _pickPhoto,
            icon: const Icon(Icons.add_a_photo_rounded),
            label: Text(t3(ui, 'Add your photo', 'अपनी फ़ोटो जोड़ें', 'మీ ఫోటో జోడించండి')),
          )
        else ...[
          Row(
            children: [
              CircleAvatar(radius: 28, backgroundImage: FileImage(photo)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t3(
                    ui,
                    'Drag or pinch the photo on the card to fit it in its frame.',
                    'फ़्रेम में ठीक बैठाने के लिए कार्ड पर फ़ोटो को खींचें या पिंच करें।',
                    'ఫ్రేమ్‌లో సరిగ్గా కూర్చేందుకు కార్డుపై ఫోటోను లాగండి లేదా పించ్ చేయండి.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.zoom_out_rounded),
              Expanded(
                child: Slider(
                  value: _view.scale,
                  min: 1,
                  max: PhotoView.maxScale,
                  label: t3(ui, 'Zoom', 'ज़ूम', 'జూమ్'),
                  onChanged: (v) => setState(() => _view = _view.copyWith(scale: v)),
                  onChangeEnd: (_) => WishProfile.setView(_view),
                ),
              ),
              const Icon(Icons.zoom_in_rounded),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(t3(ui, 'Change', 'बदलें', 'మార్చండి')),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _view = PhotoView.initial);
                  WishProfile.setView(_view);
                },
                icon: const Icon(Icons.center_focus_strong_rounded),
                label: Text(t3(ui, 'Reset', 'रीसेट', 'రీసెట్')),
              ),
              OutlinedButton.icon(
                onPressed: _removePhoto,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(t3(ui, 'Remove', 'हटाएँ', 'తొలగించండి')),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const _PrivacyNote(),
      ],
    );
  }
}

/// Home: the next festival with a wishes set, or the daily blessing card.
class WishesPromoCard extends ConsumerWidget {
  const WishesPromoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final catalog = ref.watch(wishCatalogProvider).value;
    final now = ref.watch(wishClockProvider)();
    final next = catalog == null
        ? null
        : upcomingWishes(
            catalog,
            ref.watch(wishCalendarProvider),
            now,
          ).where((w) => w.date != null && daysUntil(w.date!, now) <= 21).firstOrNull;
    final title = next == null
        ? tr(ref, 'wishes')
        : t3(
            lang,
            '${next.festival.name(lang)} wishes',
            '${next.festival.name(lang)} की शुभकामनाएँ',
            '${next.festival.name(lang)} శుభాకాంక్షలు',
          );
    final subtitle = next == null
        ? t3(
            lang,
            'Good morning and festival cards with your photo and name',
            'आपकी फ़ोटो और नाम के साथ सुप्रभात और त्योहार कार्ड',
            'మీ ఫోటో, పేరుతో శుభోదయం, పండుగ కార్డులు',
          )
        : '${whenLabel(next.date, now, lang)} · ${t3(lang, 'make a card with your photo', 'अपनी फ़ोटो के साथ कार्ड बनाएँ', 'మీ ఫోటోతో కార్డు చేయండి')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GradientCard(
        colors: const [Color(0xFF880E4F), Color(0xFFC2185B), Color(0xFFFF8F00)],
        padding: 16,
        onTap: () => context.push(next == null ? '/wishes' : '/wishes/${next.festival.id}'),
        child: Row(
          children: [
            Text(next?.festival.emoji ?? '💌', style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
