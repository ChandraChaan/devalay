import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/providers.dart';
import '../core/sections.dart';

/// Deity names for the section filters, in English, Telugu and Hindi.
const sectionDeityNames = <String, (String, String, String)>{
  'venkateswara': ('Venkateswara', 'వేంకటేశ్వర', 'वेंकटेश्वर'),
  'shiva': ('Shiva', 'శివుడు', 'शिव'),
  'lakshmi': ('Lakshmi', 'లక్ష్మి', 'लक्ष्मी'),
  'vishnu': ('Vishnu', 'విష్ణువు', 'विष्णु'),
  'rama': ('Rama', 'శ్రీరాముడు', 'राम'),
  'krishna': ('Krishna', 'శ్రీకృష్ణుడు', 'कृष्ण'),
  'radha-krishna': ('Radha Krishna', 'రాధాకృష్ణులు', 'राधा कृष्ण'),
  'hanuman': ('Hanuman', 'హనుమాన్', 'हनुमान'),
  'ganesha': ('Ganesha', 'గణపతి', 'गणेश'),
  'durga': ('Durga', 'దుర్గమ్మ', 'दुर्गा'),
  'kali': ('Kali', 'కాళీ', 'काली'),
  'saraswati': ('Saraswati', 'సరస్వతి', 'सरस्वती'),
  'surya': ('Surya', 'సూర్యుడు', 'सूर्य'),
  'dattatreya': ('Dattatreya', 'దత్తాత్రేయుడు', 'दत्तात्रेय'),
  'shani': ('Shani', 'శని', 'शनि'),
  'kartikeya': ('Subrahmanya', 'సుబ్రహ్మణ్యుడు', 'कार्तिकेय'),
  'general': ('Devotional', 'భక్తి', 'भक्ति'),
};

String deityName(String slug, String lang) {
  final n = sectionDeityNames[slug];
  if (n == null) return slug;
  return t3(lang, n.$1, n.$3, n.$2);
}

/// Today's tags: the weekday, morning or night, and festivals on today or the next two days (from the
/// home feed when it is cached; the weekday alone otherwise).
final sectionTodayTagsProvider = Provider<Set<String>>((ref) {
  final now = DateTime.now();
  final home = ref.watch(homeProvider).value;
  final today = DateTime(now.year, now.month, now.day);
  final festivals = <String>[
    for (final f in (home?['upcoming_festivals'] as List? ?? const []).cast<Map>())
      if (DateTime.tryParse('${f['date']}') case final d? when !d.isBefore(today) && d.difference(today).inDays <= 2)
        '${f['slug']}',
  ];
  final lunarMonth = ((home?['panchang'] as Map?)?['lunar_month'] as Map?)?['index'];
  return todayTags(now, festivals: [...festivals, if (lunarMonth == 7) 'karthika']);
});

/// The filter values above a section grid: Today, All, Favourites, Downloaded, then each deity.
class SectionFilter {
  static const today = 'today', all = 'all', favourites = 'fav', downloaded = 'downloaded';

  static List<T> apply<T extends SectionItem>(
    List<T> items,
    String filter, {
    required Set<String> todayTags,
    required bool Function(T) isFavourite,
    required bool Function(T) isDownloaded,
  }) => switch (filter) {
    all => items,
    today => forToday(items, todayTags, max: 30),
    favourites => items.where(isFavourite).toList(),
    downloaded => items.where(isDownloaded).toList(),
    _ => items.where((i) => i.deity == filter).toList(),
  };
}

class SectionChips extends ConsumerWidget implements PreferredSizeWidget {
  const SectionChips({
    super.key,
    required this.deities,
    required this.selected,
    required this.onSelected,
    this.extra = const [],
  });
  final List<String> deities;

  /// More filters after Today and All: (value, label, icon).
  final List<(String, String, IconData?)> extra;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final chips = <(String, String, IconData?)>[
      (SectionFilter.today, t3(lang, 'Today', 'आज', 'ఈ రోజు'), Icons.wb_sunny_rounded),
      (SectionFilter.all, t3(lang, 'All', 'सभी', 'అన్నీ'), null),
      ...extra,
      (SectionFilter.favourites, t3(lang, 'Favourites', 'पसंदीदा', 'ఇష్టమైనవి'), Icons.favorite_rounded),
      (SectionFilter.downloaded, t3(lang, 'Downloaded', 'डाउनलोड', 'డౌన్‌లోడ్ అయినవి'), Icons.download_done_rounded),
      for (final d in deities) (d, deityName(d, lang), null),
    ];
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final (value, label, icon) in chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: icon == null ? null : Icon(icon, size: 16),
                label: Text(label),
                selected: selected == value,
                onSelected: (_) => onSelected(value),
              ),
            ),
        ],
      ),
    );
  }
}

/// Deities in the order the items first mention them.
List<String> deitiesOf(Iterable<SectionItem> items) => {for (final i in items) i.deity}.toList();

/// The favourites type of a section item. HD wallpapers get their own type: 'wallpaper' favourites are the
/// older numbered wallpapers of the home feed.
String favouriteType(SectionItem i) => i.section == 'wallpaper' ? 'hd_wallpaper' : i.section;

bool isFavourite(WidgetRef ref, SectionItem i) =>
    ref.watch(favoritesProvider.select((m) => m.containsKey('${favouriteType(i)}:${i.id}')));

FavoriteItem favouriteFor(SectionItem i, String lang, {String image = ''}) =>
    FavoriteItem(type: favouriteType(i), id: i.id, title: i.title.of(lang), image: image);

/// "Raja Ravi Varma · Public domain" with a link to the source page, as CC BY asks.
class CreditLine extends StatelessWidget {
  const CreditLine(this.credit, {super.key, this.light = false, this.prefix = ''});
  final Credit credit;
  final bool light;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: light ? Colors.white70 : null, decoration: TextDecoration.underline);
    return InkWell(
      onTap: credit.source.isEmpty
          ? null
          : () => launchUrl(Uri.parse(credit.source), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          '$prefix${credit.line}${credit.changes.isEmpty ? '' : ' · ${credit.changes}'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}
