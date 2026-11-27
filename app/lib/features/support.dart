import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/app_care.dart';
import '../core/billing.dart';
import '../core/i18n.dart';
import '../core/sharing.dart';
import '../core/storage.dart';
import '../core/temples.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';
import 'temples.dart';

/// Shows what happened to a purchase started on this screen: thanks, pending or failed.
void listenBillingNotices(WidgetRef ref, BuildContext context) {
  ref.listen(billingProvider.select((s) => s.noticeId), (_, _) {
    // Only the screen on top answers, so a sheet over a screen that also listens shows one message.
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return;
    final s = ref.read(billingProvider);
    final lang = ref.read(prefsProvider).language;
    switch (s.notice) {
      case BillingNotice.thanksSupport:
        showThanks(context, lang);
      case BillingNotice.thanksPremium:
        toast(
          context,
          t3(
            lang,
            'Premium is on. Thank you for supporting Devalay 🙏',
            'प्रीमियम शुरू हो गया। देवालय का साथ देने के लिए धन्यवाद 🙏',
            'ప్రీమియం మొదలైంది. దేవాలయంకు అండగా నిలిచినందుకు ధన్యవాదాలు 🙏',
          ),
        );
      case BillingNotice.pending:
        toast(
          context,
          t3(
            lang,
            'Payment pending. It completes once Google Play confirms it.',
            'भुगतान बाकी है। Google Play की पुष्टि होते ही पूरा हो जाएगा।',
            'చెల్లింపు పెండింగ్‌లో ఉంది. Google Play నిర్ధారించగానే పూర్తవుతుంది.',
          ),
        );
      case BillingNotice.failed:
        toast(
          context,
          t3(
            lang,
            'The payment did not go through. No money was taken.',
            'भुगतान नहीं हो पाया। कोई पैसा नहीं कटा।',
            'చెల్లింపు జరగలేదు. డబ్బు ఏమీ కట్ కాలేదు.',
          ),
        );
      case BillingNotice.restored:
        toast(context, t3(lang, 'Premium restored 👑', 'प्रीमियम वापस आ गया 👑', 'ప్రీమియం తిరిగి వచ్చింది 👑'));
      case BillingNotice.nothingToRestore:
        toast(
          context,
          t3(
            lang,
            'No active Premium found for this Google account.',
            'इस Google खाते पर कोई सक्रिय प्रीमियम नहीं मिला।',
            'ఈ Google ఖాతాలో యాక్టివ్ ప్రీమియం కనిపించలేదు.',
          ),
        );
      case null:
        break;
    }
  });
}

Future<void> showThanks(BuildContext context, String lang) => showDialog<void>(
  context: context,
  builder: (_) => AlertDialog(
    icon: const Text('🙏', style: TextStyle(fontSize: 44)),
    title: Text(t3(lang, 'Thank you', 'धन्यवाद', 'ధన్యవాదాలు'), textAlign: TextAlign.center),
    content: Text(
      t3(
        lang,
        'Your offering keeps Devalay free for every devotee. May the divine bless you and your family.',
        'आपकी भेंट देवालय को हर भक्त के लिए मुफ़्त रखती है। ईश्वर आपको और आपके परिवार को आशीर्वाद दें।',
        'మీ కానుక దేవాలయంను ప్రతి భక్తునికీ ఉచితంగా ఉంచుతుంది. భగవంతుడు మిమ్మల్ని, మీ కుటుంబాన్ని ఆశీర్వదించుగాక.',
      ),
      textAlign: TextAlign.center,
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(t3(lang, 'Close', 'बंद करें', 'మూసివేయండి'))),
    ],
  ),
);

/// Who receives the money, said plainly wherever Devalay asks for any.
String toDeveloperNote(String lang) => t3(
  lang,
  'A one-time payment through Google Play to the Devalay developer. It is not a donation to any temple '
      'and is not tax-deductible.',
  'Google Play से देवालय के डेवलपर को एक बार का भुगतान। यह किसी मंदिर को दान नहीं है '
      'और इस पर कर छूट नहीं मिलती।',
  'Google Play ద్వారా దేవాలయం డెవలపర్‌కు ఒకసారి చెల్లింపు. ఇది ఏ ఆలయానికీ విరాళం కాదు, '
      'దీనికి పన్ను మినహాయింపు ఉండదు.',
);

/// Amount buttons for the support products Play has published, in rupee order.
class SupportAmounts extends ConsumerWidget {
  const SupportAmounts({super.key, required this.ids, required this.source, this.dark = false});
  final List<String> ids;
  final String source;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(billingProvider);
    final lang = uiLang(ref);
    final products = s.supportProducts(ids);
    final muted = TextStyle(color: dark ? Colors.white70 : null);
    if (!s.ready) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!s.available || products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          !s.available
              ? t3(
                  lang,
                  'Google Play payments are not available on this phone.',
                  'इस फ़ोन पर Google Play से भुगतान उपलब्ध नहीं है।',
                  'ఈ ఫోన్‌లో Google Play చెల్లింపులు అందుబాటులో లేవు.',
                )
              : t3(lang, 'Coming soon on Google Play.', 'जल्द ही Google Play पर।', 'త్వరలో Google Playలో.'),
          textAlign: TextAlign.center,
          style: muted,
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final p in products)
          FilledButton.tonal(
            onPressed: s.busy ? null : () => ref.read(billingProvider.notifier).buy(p, source: source),
            style: FilledButton.styleFrom(
              minimumSize: const Size(76, 48),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            child: Text(_price(p)),
          ),
      ],
    );
  }

  static String _price(ProductDetails p) => p.price.isNotEmpty ? p.price : '₹${Products.rupees(p.id)}';
}

/// The official donation pages of major temples (TTD e-Hundi first). Money given there goes to the
/// temple itself; Devalay only opens the temple's own site.
class TempleDonationList extends ConsumerWidget {
  const TempleDonationList({super.key, this.dark = false, this.source = ''});
  final bool dark;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final catalog = ref.watch(templeCatalogProvider).value;
    if (catalog == null) return const SizedBox.shrink();
    final rows = [
      for (final t in catalog.temples)
        for (final s in t.services)
          if (s.category == 'donate') (t, s),
    ];
    final fg = dark ? Colors.white : null;
    return Column(
      children: [
        for (final (t, s) in rows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(s.emoji, style: const TextStyle(fontSize: 26)),
            title: Text(
              '${t.short(lang)} · ${s.name(lang)}',
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              Uri.tryParse(t.urlFor(s))?.host.replaceFirst('www.', '') ?? t.portalHost,
              style: TextStyle(color: dark ? Colors.white60 : null),
            ),
            trailing: Icon(Icons.open_in_new_rounded, size: 20, color: dark ? Colors.white60 : null),
            onTap: () {
              Usage.record('temple_donate_open', item: '${t.id}/${s.id}', params: {'source': source});
              showServiceSheet(context, t, s);
            },
          ),
      ],
    );
  }
}

/// Dakshina from the Mandir: give at a real temple through its official site, or offer dakshina to
/// Devalay through Google Play. The two are kept apart so nobody mistakes one for the other.
Future<void> showDakshinaSheet(BuildContext context) {
  Usage.record('dakshina_open');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF24110A),
    builder: (_) => const _DakshinaSheet(),
  );
}

class _DakshinaSheet extends ConsumerWidget {
  const _DakshinaSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenBillingNotices(ref, context);
    final lang = uiLang(ref);
    const heading = TextStyle(color: Palette.gold, fontSize: 18, fontWeight: FontWeight.w700);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text('🪙', textAlign: TextAlign.center, style: TextStyle(fontSize: 40)),
          Text(
            t3(lang, 'Offer dakshina', 'दक्षिणा अर्पित करें', 'దక్షిణ సమర్పించండి'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Text(t3(lang, 'At a temple', 'मंदिर में', 'ఆలయంలో'), style: heading),
          const SizedBox(height: 4),
          Text(
            t3(
              lang,
              "Give directly to the temple on its official site. The money goes to the temple; Devalay never handles it.",
              'मंदिर की आधिकारिक साइट पर सीधे मंदिर को दें। पैसा मंदिर को जाता है; देवालय उसे कभी नहीं छूता।',
              'ఆలయ అధికారిక సైట్‌లో నేరుగా ఆలయానికే ఇవ్వండి. డబ్బు ఆలయానికే చేరుతుంది; దేవాలయం దాన్ని ఎప్పుడూ తాకదు.',
            ),
            style: const TextStyle(color: Colors.white70),
          ),
          const TempleDonationList(dark: true, source: 'mandir'),
          const Divider(color: Colors.white24, height: 32),
          Text(t3(lang, 'To Devalay', 'देवालय को', 'దేవాలయంకు'), style: heading),
          const SizedBox(height: 4),
          Text(
            t3(
              lang,
              'If this Mandir is part of your daily prayer, a small dakshina keeps Devalay free and growing.',
              'अगर यह मंदिर आपकी रोज़ की पूजा का हिस्सा है, तो छोटी सी दक्षिणा देवालय को मुफ़्त और आगे बढ़ता रखती है।',
              'ఈ మందిరం మీ రోజువారీ పూజలో భాగమైతే, చిన్న దక్షిణ దేవాలయంను ఉచితంగా, ఎదుగుతూ ఉంచుతుంది.',
            ),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          const SupportAmounts(ids: Products.dakshina, source: 'mandir', dark: true),
          const SizedBox(height: 10),
          Text(
            toDeveloperNote(lang),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Support Devalay: tip the developer, see Premium, or help for free (rate, share).
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key, this.source = 'more'});
  final String source;
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  @override
  void initState() {
    super.initState();
    Usage.record('support_view', item: widget.source);
  }

  @override
  Widget build(BuildContext context) {
    listenBillingNotices(ref, context);
    final lang = uiLang(ref);
    final premium = ref.watch(premiumProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'Support Devalay', 'देवालय का साथ दें', 'దేవాలయంకు అండగా నిలవండి'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GradientCard(
            colors: Palette.sunrise,
            child: Column(
              children: [
                const Text('🙏', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 6),
                Text(
                  t3(
                    lang,
                    'Devalay is made by one developer, free for every devotee. If it helps your daily prayer, '
                        'a small gift pays for new features, more bhajans and the servers.',
                    'देवालय एक डेवलपर ने बनाया है, हर भक्त के लिए मुफ़्त। अगर यह आपकी रोज़ की पूजा में काम आता है, '
                        'तो एक छोटा सा उपहार नई सुविधाओं, और भजनों और सर्वर का खर्च उठाता है।',
                    'దేవాలయంను ఒక్క డెవలపర్ తయారు చేశారు, ప్రతి భక్తునికీ ఉచితం. మీ రోజువారీ పూజకు ఇది ఉపయోగపడితే, '
                        'చిన్న కానుక కొత్త ఫీచర్లు, మరిన్ని భజనలు, సర్వర్ ఖర్చులకు సహాయపడుతుంది.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SupportAmounts(ids: Products.support, source: widget.source),
          const SizedBox(height: 10),
          Text(toDeveloperNote(lang), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          if (!premium)
            Card(
              child: ListTile(
                leading: const Text('👑', style: TextStyle(fontSize: 26)),
                title: Text(
                  t3(lang, 'Devalay Premium', 'देवालय प्रीमियम', 'దేవాలయం ప్రీమియం'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(premiumPitch(lang)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/premium?from=support'),
              ),
            ),
          SectionHeader(t3(lang, 'Free ways to help', 'मदद के मुफ़्त तरीके', 'ఉచితంగా సహాయపడే మార్గాలు')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.star_rounded, color: Colors.amber),
                  title: Text(
                    t3(
                      lang,
                      'Rate Devalay on Google Play',
                      'Google Play पर देवालय को रेट करें',
                      'Google Playలో దేవాలయంకు రేటింగ్ ఇవ్వండి',
                    ),
                  ),
                  onTap: () {
                    Usage.record('support_rate');
                    rateApp();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: Colors.green),
                  title: Text(
                    t3(
                      lang,
                      'Share with family and friends',
                      'परिवार और दोस्तों से साझा करें',
                      'కుటుంబం, స్నేహితులతో పంచుకోండి',
                    ),
                  ),
                  onTap: () {
                    Usage.record('support_share');
                    shareApp(lang);
                  },
                ),
              ],
            ),
          ),
          SectionHeader(t3(lang, 'Give to a temple', 'मंदिर को दान दें', 'ఆలయానికి విరాళం ఇవ్వండి')),
          Text(
            t3(
              lang,
              "These open the temple's own official site. The money goes to the temple.",
              'ये मंदिर की अपनी आधिकारिक साइट खोलते हैं। पैसा मंदिर को जाता है।',
              'ఇవి ఆలయపు సొంత అధికారిక సైట్‌ను తెరుస్తాయి. డబ్బు ఆలయానికే చేరుతుంది.',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const TempleDonationList(source: 'support'),
        ],
      ),
    );
  }
}

/// One line on what Premium adds, for cards that link to it.
String premiumPitch(String lang) => t3(
  lang,
  'No ads ever, Mandir decorations, japa malas and extra app colours.',
  'कभी विज्ञापन नहीं, मंदिर की सजावट, जप मालाएँ और ऐप के नए रंग।',
  'ఎప్పుడూ ప్రకటనలు లేవు, మందిర అలంకరణలు, జప మాలలు, యాప్‌కు అదనపు రంగులు.',
);

/// Whether to show the one gentle "support Devalay" card: after a 7-day Mandir streak (or longer),
/// never to Premium members, at most once every 60 days, and never within 180 days of a gift.
bool shouldShowSupportPrompt({
  required int streak,
  required bool premium,
  required DateTime now,
  DateTime? lastShown,
  DateTime? lastGift,
}) {
  if (premium || streak < 7) return false;
  if (lastShown != null && now.difference(lastShown) < const Duration(days: 60)) return false;
  if (lastGift != null && now.difference(lastGift) < const Duration(days: 180)) return false;
  return true;
}

class SupportPrompt {
  SupportPrompt._();
  static DateTime? _date(String key) => DateTime.tryParse('${Boxes.stats.get(key, defaultValue: '')}');

  static bool due({required int streak, required bool premium}) => shouldShowSupportPrompt(
    streak: streak,
    premium: premium,
    now: DateTime.now(),
    lastShown: _date('support_prompt_at'),
    lastGift: _date('support_gift_at'),
  );

  static void shown() {
    Boxes.stats.put('support_prompt_at', DateTime.now().toIso8601String());
    Usage.record('support_prompt_shown');
  }
}
