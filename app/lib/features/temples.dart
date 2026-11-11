import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n.dart';
import '../core/notifications.dart' show clock12;
import '../core/storage.dart';
import '../core/telugu.dart';
import '../core/temples.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Temple booking: every online service of TTD and other major temples, explained, with a button
/// that opens the temple's official site. Bookings and payments happen there, never in Devalay.

const _categoryLabels = {
  'darshan': ('Darshan', 'दर्शन', 'దర్శనం'),
  'seva': ('Sevas and poojas', 'सेवा और पूजा', 'సేవలు, పూజలు'),
  'stay': ('Stay', 'ठहरना', 'వసతి'),
  'donate': ('Donate', 'दान', 'విరాళాలు'),
  'more': ('More services', 'अन्य सेवाएँ', 'ఇతర సేవలు'),
};

const _stateNames = {
  'Andhra Pradesh': ('आंध्र प्रदेश', 'ఆంధ్రప్రదేశ్'),
  'Gujarat': ('गुजरात', 'గుజరాత్'),
  'Jammu & Kashmir': ('जम्मू-कश्मीर', 'జమ్మూ కాశ్మీర్'),
  'Karnataka': ('कर्नाटक', 'కర్ణాటక'),
  'Kerala': ('केरल', 'కేరళ'),
  'Madhya Pradesh': ('मध्य प्रदेश', 'మధ్యప్రదేశ్'),
  'Maharashtra': ('महाराष्ट्र', 'మహారాష్ట్ర'),
  'Tamil Nadu': ('तमिलनाडु', 'తమిళనాడు'),
  'Telangana': ('तेलंगाना', 'తెలంగాణ'),
  'Uttar Pradesh': ('उत्तर प्रदेश', 'ఉత్తరప్రదేశ్'),
  'Uttarakhand': ('उत्तराखंड', 'ఉత్తరాఖండ్'),
};

String _category(String key, String lang) {
  final (en, hi, te) = _categoryLabels[key] ?? _categoryLabels['more']!;
  return t3(lang, en, hi, te);
}

String _state(String state, String lang) {
  final names = _stateNames[state];
  return names == null ? state : t3(lang, state, names.$1, names.$2);
}

String _dayMonth(DateTime d, String lang) =>
    lang == 'te' ? '${d.day} ${teluguGregorianMonths[d.month - 1]}' : DateFormat('d MMM').format(d);

String _monthYear(DateTime d, String lang) =>
    lang == 'te' ? '${teluguGregorianMonths[d.month - 1]} ${d.year}' : DateFormat('MMMM y').format(d);

String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// "Usually opens on the 24th of each month at 10:00 AM IST, for visits 3 months later."
String usualOpening(ReleaseSlot slot, String lang) {
  final time = clock12(slot.hour, slot.minute);
  final n = slot.ahead;
  final visits = switch (n) {
    0 => '',
    1 => t3(lang, ', for visits in the next month', ', अगले महीने की यात्रा के लिए', ', తర్వాతి నెల దర్శనానికి'),
    _ => t3(lang, ', for visits $n months later', ', $n महीने बाद की यात्रा के लिए', ', $n నెలల తర్వాతి దర్శనానికి'),
  };
  return t3(
    lang,
    'Usually opens on the ${_ordinal(slot.day)} of each month at $time IST$visits.',
    'आमतौर पर हर महीने की ${slot.day} तारीख को $time (IST) पर खुलता है$visits।',
    'సాధారణంగా ప్రతి నెల ${slot.day}వ తేదీ $time (IST) కు విడుదలవుతుంది$visits.',
  );
}

/// "24 Nov, 10:00 AM · for February 2027", or "for Feb 2027" when [short].
String nextOpening(ReleaseSlot slot, String lang, {DateTime? now, bool short = false}) {
  final next = slot.next(now ?? istNow());
  final when = '${_dayMonth(next, lang)}, ${clock12(slot.hour, slot.minute)}';
  if (slot.ahead == 0) return when;
  final quota = slot.quotaMonth(next);
  final month = short && lang != 'te' ? DateFormat('MMM y').format(quota) : _monthYear(quota, lang);
  return '$when · ${t3(lang, 'for $month', '$month के लिए', '$month కోసం')}';
}

/// Opens an official booking site in an in-app browser tab, so the user stays in Devalay while
/// the temple's own pages handle login, OTP and payment.
Future<void> openOfficialSite(BuildContext context, String url, String lang) async {
  if (isSafeBookingUrl(url)) {
    final uri = Uri.parse(url);
    for (final mode in const [LaunchMode.inAppBrowserView, LaunchMode.externalApplication]) {
      try {
        if (await launchUrl(uri, mode: mode)) return;
      } catch (_) {
        // No browser for this mode: try the next one.
      }
    }
  }
  if (context.mounted) {
    toast(
      context,
      t3(
        lang,
        'Could not open the site. Check your internet connection.',
        'साइट नहीं खुल सकी। अपना इंटरनेट कनेक्शन जाँचें।',
        'సైట్ తెరుచుకోలేదు. మీ ఇంటర్నెట్ కనెక్షన్ చూడండి.',
      ),
    );
  }
}

List<Color> _gradient(Temple temple) {
  final colors = [for (final c in temple.colors) Palette.hex(c)];
  return colors.length >= 2 ? colors : Palette.sunrise;
}

class TemplesScreen extends ConsumerStatefulWidget {
  const TemplesScreen({super.key});

  @override
  ConsumerState<TemplesScreen> createState() => _TemplesScreenState();
}

class _TemplesScreenState extends ConsumerState<TemplesScreen> {
  String _query = '';
  String? _stateFilter;

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final catalog = ref.watch(templeCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'temple_booking'))),
      body: catalog.when(
        loading: () => const LoadingList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(templeCatalogProvider)),
        data: (data) {
          final filtering = _query.trim().isNotEmpty || _stateFilter != null;
          final shown = data.temples
              .where((t) => t.matches(_query) && (_stateFilter == null || t.state == _stateFilter))
              .toList();
          final featured = filtering ? const <Temple>[] : shown.where((t) => t.featured).toList();
          final rest = shown.where((t) => !featured.contains(t)).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              for (final t in featured)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: _FeaturedCard(temple: t),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: t3(
                      lang,
                      'Search temple, city or state',
                      'मंदिर, शहर या राज्य खोजें',
                      'ఆలయం, ఊరు లేదా రాష్ట్రం వెతకండి',
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    for (final s in [null, ...data.states])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s == null ? tr(ref, 'all') : _state(s, lang)),
                          selected: _stateFilter == s,
                          onSelected: (_) => setState(() => _stateFilter = s),
                        ),
                      ),
                  ],
                ),
              ),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.temple_hindu_outlined,
                    title: t3(lang, 'No temple found', 'कोई मंदिर नहीं मिला', 'ఆలయం దొరకలేదు'),
                    subtitle: t3(
                      lang,
                      'Try the city or the state name.',
                      'शहर या राज्य का नाम आज़माएँ।',
                      'ఊరు లేదా రాష్ట్రం పేరుతో వెతకండి.',
                    ),
                  ),
                ),
              for (final t in rest)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _TempleTile(temple: t),
                ),
              const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 0), child: _OfficialOnlyNote()),
            ],
          );
        },
      ),
    );
  }
}

/// The soonest usual opening among a temple's services, as `(service, slot)`.
(TempleService, ReleaseSlot)? _soonest(Temple temple) {
  final now = istNow();
  (TempleService, ReleaseSlot)? best;
  for (final s in temple.releases) {
    if (best == null || s.release!.next(now).isBefore(best.$2.next(now))) best = (s, s.release!);
  }
  return best;
}

class _FeaturedCard extends ConsumerWidget {
  const _FeaturedCard({required this.temple});
  final Temple temple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final soon = _soonest(temple);
    return GradientCard(
      colors: _gradient(temple),
      onTap: () => context.push('/temples/${temple.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(temple.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      temple.name(lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${temple.deity(lang)} · ${temple.place(lang)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(temple.tagline(lang), style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.35)),
          if (soon != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded, color: Palette.gold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${t3(lang, 'Next', 'अगला', 'తదుపరి')}: ${soon.$1.name(lang)}\n${nextOpening(soon.$2, lang)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                t3(
                  lang,
                  'See all ${temple.services.length} services',
                  'सभी ${temple.services.length} सेवाएँ देखें',
                  'మొత్తం ${temple.services.length} సేవలు చూడండి',
                ),
                style: const TextStyle(color: Palette.gold, fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, color: Palette.gold, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _TempleTile extends ConsumerWidget {
  const _TempleTile({required this.temple});
  final Temple temple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final theme = Theme.of(context);
    final categories = serviceCategories.where((c) => temple.services.any((s) => s.category == c));
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/temples/${temple.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _EmojiBadge(temple.emoji, colors: _gradient(temple)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(temple.name(lang), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      '${temple.place(lang)} · ${_state(temple.state, lang)}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categories.map((c) => _category(c, lang)).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiBadge extends StatelessWidget {
  const _EmojiBadge(this.emoji, {this.colors, this.size = 52});
  final String emoji;
  final List<Color>? colors;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: colors == null ? Palette.marigold.withValues(alpha: 0.14) : null,
      gradient: colors == null
          ? null
          : LinearGradient(colors: colors!, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(size * 0.32),
    ),
    child: Text(emoji, style: TextStyle(fontSize: size * 0.46)),
  );
}

/// Says plainly who takes the booking and the money.
class _OfficialOnlyNote extends ConsumerWidget {
  const _OfficialOnlyNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l3(
                ref,
                'You book and pay only on the temple\'s official site, which opens inside Devalay. '
                    'Devalay is not connected to any temple or government body and never asks you for money.',
                'बुकिंग और भुगतान केवल मंदिर की आधिकारिक साइट पर होता है, जो देवालय के अंदर खुलती है। '
                    'देवालय किसी मंदिर या सरकारी संस्था से जुड़ा नहीं है और आपसे कभी पैसे नहीं माँगता।',
                'బుకింగ్, చెల్లింపు ఆలయ అధికారిక సైట్‌లో మాత్రమే జరుగుతాయి; అది దేవాలయం యాప్‌లోనే తెరుచుకుంటుంది. '
                    'దేవాలయం యాప్‌కు ఏ ఆలయంతోనూ, ప్రభుత్వ సంస్థతోనూ సంబంధం లేదు; మీ నుంచి డబ్బు అడగదు.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class TempleScreen extends ConsumerWidget {
  const TempleScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final catalog = ref.watch(templeCatalogProvider);
    final temple = catalog.value?.byId(id);
    return Scaffold(
      appBar: AppBar(title: Text(temple?.short(lang) ?? tr(ref, 'temple_booking'))),
      body: catalog.when(
        loading: () => const LoadingList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(templeCatalogProvider)),
        data: (data) => temple == null
            ? EmptyState(
                icon: Icons.temple_hindu_outlined,
                title: t3(
                  lang,
                  'This temple is not listed yet',
                  'यह मंदिर अभी सूची में नहीं है',
                  'ఈ ఆలయం ఇంకా జాబితాలో లేదు',
                ),
              )
            : _TempleBody(temple: temple, updated: data.updated),
      ),
    );
  }
}

class _TempleBody extends ConsumerWidget {
  const _TempleBody({required this.temple, required this.updated});
  final Temple temple;
  final DateTime? updated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final theme = Theme.of(context);
    final walkIn = temple.walkIn(lang);
    final steps = temple.steps(lang);
    final tips = temple.tips(lang);
    Widget card(List<Widget> rows) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, row) in rows.indexed) ...[if (i > 0) const Divider(indent: 16, endIndent: 16), row],
          ],
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: GradientCard(
            colors: _gradient(temple),
            child: Row(
              children: [
                Text(temple.emoji, style: const TextStyle(fontSize: 44)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        temple.name(lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(temple.deity(lang), style: const TextStyle(color: Colors.white, height: 1.3)),
                      Text(
                        '${temple.place(lang)} · ${_state(temple.state, lang)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SiteLine(host: temple.portalHost),
                  if (temple.login(lang).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(temple.login(lang), style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => openOfficialSite(context, temple.portalUrl, lang),
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    label: Text(t3(lang, 'Open official site', 'आधिकारिक साइट खोलें', 'అధికారిక సైట్ తెరవండి')),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: _OfficialOnlyNote()),
        if (temple.updatesPath != null) _Announcements(temple: temple, path: temple.updatesPath!),
        if (temple.releases.isNotEmpty) ...[
          SectionHeader(t3(lang, 'Usual booking dates', 'बुकिंग की सामान्य तारीखें', 'సాధారణ బుకింగ్ తేదీలు')),
          _ReleaseDates(temple: temple),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              t3(
                lang,
                'These are the usual dates. The temple confirms the exact date and time each month under '
                    'Latest Updates on its site. Tap the bell for a reminder.',
                'ये सामान्य तारीखें हैं। मंदिर हर महीने सही तारीख और समय अपनी साइट के Latest Updates में बताता है। '
                    'रिमाइंडर के लिए घंटी दबाएँ।',
                'ఇవి సాధారణ తేదీలు. ఖచ్చితమైన తేదీ, సమయాన్ని ఆలయం ప్రతి నెల తన సైట్‌లోని Latest Updates లో ప్రకటిస్తుంది. '
                    'రిమైండర్ కోసం గంట గుర్తు నొక్కండి.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
        for (final category in serviceCategories)
          if (temple.services.any((s) => s.category == category)) ...[
            SectionHeader(_category(category, lang)),
            card([
              for (final s in temple.services.where((s) => s.category == category))
                _ServiceRow(temple: temple, service: s),
            ]),
          ],
        if (walkIn.isNotEmpty) ...[
          SectionHeader(t3(lang, 'Without online booking', 'बिना ऑनलाइन बुकिंग', 'ఆన్‌లైన్ బుకింగ్ లేకుండా')),
          card([
            for (final (name, summary) in walkIn)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const _EmojiBadge('🚶', size: 44),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(summary),
              ),
          ]),
        ],
        if (steps.isNotEmpty) ...[
          SectionHeader(t3(lang, 'How to book', 'बुकिंग कैसे करें', 'బుక్ చేయడం ఎలా')),
          card([
            for (final (i, step) in steps.indexed)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                title: Text(step, style: theme.textTheme.bodyLarge?.copyWith(height: 1.35)),
              ),
          ]),
        ],
        if (tips.isNotEmpty) ...[
          SectionHeader(t3(lang, 'Before you go', 'जाने से पहले', 'వెళ్లే ముందు')),
          card([
            for (final tip in tips)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Icon(Icons.check_circle_outline_rounded, color: theme.colorScheme.primary),
                title: Text(tip, style: theme.textTheme.bodyLarge?.copyWith(height: 1.35)),
              ),
          ]),
        ],
        if (temple.links.isNotEmpty) ...[
          SectionHeader(t3(lang, 'More official links', 'अन्य आधिकारिक लिंक', 'ఇతర అధికారిక లింకులు')),
          card([
            for (final link in temple.links)
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(link.label(lang)),
                subtitle: Text(Uri.tryParse(link.url)?.host ?? ''),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => openOfficialSite(context, link.url, lang),
              ),
          ]),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(
            [
              if (updated != null)
                t3(
                  lang,
                  'Details checked on ${DateFormat('d MMM y').format(updated!)}.',
                  'जानकारी ${DateFormat('d MMM y').format(updated!)} को जाँची गई।',
                  'వివరాలు ${updated!.day} ${teluguGregorianMonths[updated!.month - 1]} ${updated!.year} న సరిచూశాం.',
                ),
              t3(
                lang,
                'Temples change prices, rules and dates. What the official site says is final.',
                'मंदिर कीमतें, नियम और तारीखें बदलते रहते हैं। आधिकारिक साइट पर लिखी बात ही अंतिम है।',
                'ఆలయాలు ధరలు, నియమాలు, తేదీలు మారుస్తుంటాయి. అధికారిక సైట్‌లో ఉన్నదే తుది మాట.',
              ),
            ].join(' '),
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

/// A padlock and the host name, so the user can see which site will open.
class _SiteLine extends StatelessWidget {
  const _SiteLine({required this.host});
  final String host;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.lock_outline_rounded, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            host,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ReminderBell extends ConsumerWidget {
  const _ReminderBell({required this.temple, required this.service});
  final Temple temple;
  final TempleService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final on = ref.watch(templeRemindersProvider.select((r) => r.contains(TempleReminders.keyFor(temple, service))));
    return IconButton(
      tooltip: t3(lang, 'Remind me every month', 'हर महीने याद दिलाएँ', 'ప్రతి నెల గుర్తు చేయండి'),
      isSelected: on,
      icon: const Icon(Icons.notifications_none_rounded),
      selectedIcon: Icon(Icons.notifications_active_rounded, color: Theme.of(context).colorScheme.primary),
      onPressed: () => setReminder(context, ref, temple, service, !on),
    );
  }
}

Future<void> setReminder(BuildContext context, WidgetRef ref, Temple temple, TempleService service, bool on) async {
  final lang = ref.read(prefsProvider).language;
  final ok = await ref.read(templeRemindersProvider.notifier).set(temple, service, on, lang: lang);
  if (!context.mounted) return;
  toast(
    context,
    !ok
        ? t3(
            lang,
            'Allow notifications for Devalay in your phone settings to get reminders.',
            'रिमाइंडर के लिए फोन की सेटिंग में देवालय की सूचनाएँ चालू करें।',
            'రిమైండర్ల కోసం ఫోన్ సెట్టింగ్స్‌లో దేవాలయం నోటిఫికేషన్లను అనుమతించండి.',
          )
        : on
        ? t3(
            lang,
            'Reminder on: the evening before and again before it opens, every month.',
            'रिमाइंडर चालू: हर महीने एक शाम पहले और खुलने से पहले फिर।',
            'రిమైండర్ ఆన్: ప్రతి నెల ముందు రోజు సాయంత్రం, విడుదలకు ముందు మళ్లీ.',
          )
        : t3(lang, 'Reminder off.', 'रिमाइंडर बंद।', 'రిమైండర్ ఆఫ్.'),
  );
}

class _ReleaseRow extends ConsumerWidget {
  const _ReleaseRow({required this.temple, required this.service});
  final Temple temple;
  final TempleService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final theme = Theme.of(context);
    final slot = service.release!;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      onTap: () => showServiceSheet(context, temple, service),
      leading: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '${slot.day}',
          style: TextStyle(color: theme.colorScheme.primary, fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(service.name(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(nextOpening(slot, lang, short: true)),
      trailing: _ReminderBell(temple: temple, service: service),
    );
  }
}

/// A card of rows that shows the first three until the user asks for all of them.
class _ExpandableCard extends ConsumerStatefulWidget {
  const _ExpandableCard({required this.rows, required this.showAll});
  final List<Widget> rows;

  /// Label of the button that reveals every row, such as "Show all 9 dates".
  final String showAll;

  @override
  ConsumerState<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends ConsumerState<_ExpandableCard> {
  static const _collapsed = 3;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final rows = _all ? widget.rows : widget.rows.take(_collapsed).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, row) in rows.indexed) ...[if (i > 0) const Divider(indent: 16, endIndent: 16), row],
            if (widget.rows.length > _collapsed) ...[
              const Divider(indent: 16, endIndent: 16),
              TextButton.icon(
                onPressed: () => setState(() => _all = !_all),
                icon: Icon(_all ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                label: Text(_all ? l3(ref, 'Show fewer', 'कम दिखाएँ', 'తక్కువ చూపించు') : widget.showAll),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The temple's next openings, soonest first.
class _ReleaseDates extends ConsumerWidget {
  const _ReleaseDates({required this.temple});
  final Temple temple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final now = istNow();
    final upcoming = temple.releases..sort((a, b) => a.release!.next(now).compareTo(b.release!.next(now)));
    final n = upcoming.length;
    return _ExpandableCard(
      rows: [for (final s in upcoming) _ReleaseRow(temple: temple, service: s)],
      showAll: t3(lang, 'Show all $n dates', 'सभी $n तारीखें दिखाएँ', 'మొత్తం $n తేదీలు చూపించు'),
    );
  }
}

/// What the temple itself has announced, as republished daily from its official site. Shows
/// nothing when there is no fresh copy.
class _Announcements extends ConsumerWidget {
  const _Announcements({required this.temple, required this.path});
  final Temple temple;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(templeUpdatesProvider(path)).value;
    if (updates == null) return const SizedBox.shrink();
    final lang = uiLang(ref);
    final theme = Theme.of(context);
    final n = updates.items.length;
    final checked = updates.fetched.toLocal();
    final day = _dayMonth(checked, lang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(t3(lang, 'Latest from the temple', 'मंदिर की ताज़ा सूचनाएँ', 'ఆలయ తాజా ప్రకటనలు')),
        _ExpandableCard(
          rows: [
            for (final u in updates.items)
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                onTap: () => openOfficialSite(context, u.url ?? temple.portalUrl, lang),
                title: u.title.isEmpty ? null : Text(u.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(u.text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                trailing: Icon(Icons.open_in_new_rounded, size: 18, color: theme.colorScheme.outline),
              ),
          ],
          showAll: t3(lang, 'Show all $n announcements', 'सभी $n सूचनाएँ दिखाएँ', 'మొత్తం $n ప్రకటనలు చూపించు'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text(
            t3(
              lang,
              'In the temple\'s own words, from ${temple.portalHost}. Checked on $day.',
              'मंदिर के अपने शब्दों में, ${temple.portalHost} से। $day को जाँचा गया।',
              'ఆలయం మాటల్లోనే, ${temple.portalHost} నుంచి. $day న సరిచూశాం.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _ServiceRow extends ConsumerWidget {
  const _ServiceRow({required this.temple, required this.service});
  final Temple temple;
  final TempleService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final theme = Theme.of(context);
    final price = service.price(lang);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => showServiceSheet(context, temple, service),
      leading: _EmojiBadge(service.emoji, size: 46),
      title: Text(service.name(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(service.summary(lang), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (price.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                price,
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
    );
  }
}

/// Details of one service with the button that opens its official booking page.
Future<void> showServiceSheet(BuildContext context, Temple temple, TempleService service) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _ServiceSheet(temple: temple, service: service),
);

class _ServiceSheet extends ConsumerWidget {
  const _ServiceSheet({required this.temple, required this.service});
  final Temple temple;
  final TempleService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final theme = Theme.of(context);
    final slot = service.release;
    final url = temple.urlFor(service);
    final reminderOn = ref.watch(
      templeRemindersProvider.select((r) => r.contains(TempleReminders.keyFor(temple, service))),
    );
    Widget fact(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _EmojiBadge(service.emoji),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name(lang),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                      ),
                      Text(temple.short(lang), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(service.summary(lang), style: theme.textTheme.bodyLarge?.copyWith(height: 1.45)),
            if (service.price(lang).isNotEmpty)
              fact(Icons.payments_outlined, t3(lang, 'Price', 'शुल्क', 'ధర'), service.price(lang)),
            if (service.who(lang).isNotEmpty)
              fact(
                Icons.groups_outlined,
                t3(lang, 'Who can book', 'कौन बुक कर सकता है', 'ఎవరు బుక్ చేయవచ్చు'),
                service.who(lang),
              ),
            if (slot != null) ...[
              fact(
                Icons.event_repeat_rounded,
                t3(lang, 'When booking opens', 'बुकिंग कब खुलती है', 'బుకింగ్ ఎప్పుడు మొదలవుతుంది'),
                usualOpening(slot, lang),
              ),
              fact(
                Icons.event_available_rounded,
                t3(lang, 'Next usual opening', 'अगली सामान्य तारीख', 'తదుపరి సాధారణ తేదీ'),
                nextOpening(slot, lang),
              ),
            ],
            for (final note in service.notes(lang))
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(note, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45))),
                  ],
                ),
              ),
            if (slot != null) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: reminderOn,
                onChanged: (v) => setReminder(context, ref, temple, service, v),
                secondary: Icon(reminderOn ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
                title: Text(
                  t3(lang, 'Remind me every month', 'हर महीने याद दिलाएँ', 'ప్రతి నెల గుర్తు చేయండి'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  t3(
                    lang,
                    'The evening before and again before it opens',
                    'एक शाम पहले और खुलने से पहले फिर',
                    'ముందు రోజు సాయంత్రం, విడుదలకు ముందు మళ్లీ',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SiteLine(host: Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? temple.portalHost),
            if (service.url == null && temple.login(lang).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  t3(
                    lang,
                    '${temple.login(lang)}, then choose this service.',
                    '${temple.login(lang)}, फिर यह सेवा चुनें।',
                    '${temple.login(lang)}, తర్వాత ఈ సేవను ఎంచుకోండి.',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => openOfficialSite(context, url, lang),
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              label: Text(
                t3(lang, 'Book on official site', 'आधिकारिक साइट पर बुक करें', 'అధికారిక సైట్‌లో బుక్ చేయండి'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home screen entry: the main way into temple booking.
class BookingPromoCard extends ConsumerWidget {
  const BookingPromoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final featured = ref.watch(templeCatalogProvider).value?.temples.where((t) => t.featured).firstOrNull;
    final soon = featured == null ? null : _soonest(featured);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GradientCard(
        colors: Palette.dusk,
        padding: 16,
        onTap: () => context.push('/temples'),
        child: Row(
          children: [
            const Text('🎟️', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t3(lang, 'Book darshan tickets', 'दर्शन टिकट बुक करें', 'దర్శన టికెట్లు బుక్ చేయండి'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    soon == null
                        ? t3(
                            lang,
                            'TTD darshan, sevas, rooms and more temples',
                            'टीटीडी दर्शन, सेवा, कमरे और अन्य मंदिर',
                            'టీటీడీ దర్శనం, సేవలు, గదులు, మరిన్ని ఆలయాలు',
                          )
                        : '${featured!.short(lang)}: ${soon.$1.name(lang)}\n'
                              '${t3(lang, 'Next', 'अगला', 'తదుపరి')}: ${nextOpening(soon.$2, lang)}',
                    maxLines: 3,
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
