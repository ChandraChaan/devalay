import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/billing.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/usage.dart';
import '../widgets/common.dart';
import 'support.dart';
import 'support_chat.dart';

/// Optional Google Play subscription. Prices come from Play itself, the plan is cancellable anytime
/// in Play, and every devotional feature stays free.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key, this.source = ''});
  final String source;
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  @override
  void initState() {
    super.initState();
    Usage.record('premium_view', item: widget.source.isEmpty ? null : widget.source);
    // Opening the screen is a good moment to make sure the products and status are fresh.
    final billing = ref.read(billingProvider.notifier);
    Future.microtask(() async {
      await billing.start();
      if (ref.read(billingProvider).available && ref.read(billingProvider).products.isEmpty) {
        await billing.loadProducts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    listenBillingNotices(ref, context);
    final lang = uiLang(ref);
    final s = ref.watch(billingProvider);
    final premium = ref.watch(premiumProvider);
    final theme = Theme.of(context);
    final perks = [
      ('🚫', t3(lang, 'No ads, now or ever', 'कभी कोई विज्ञापन नहीं', 'ఎప్పుడూ ప్రకటనలు ఉండవు')),
      (
        '🛕',
        t3(
          lang,
          'Mandir decorations: gold, jasmine, tulasi and Deepotsava',
          'मंदिर की सजावट: स्वर्ण, चमेली, तुलसी और दीपोत्सव',
          'మందిర అలంకరణలు: స్వర్ణ, మల్లెలు, తులసి, దీపోత్సవం',
        ),
      ),
      (
        '📿',
        t3(
          lang,
          'Japa malas: tulsi, sphatik and sandalwood, plus 27 and 54 bead rounds',
          'जप मालाएँ: तुलसी, स्फटिक और चंदन, साथ में 27 और 54 मनकों की माला',
          'జప మాలలు: తులసి, స్ఫటికం, చందనం, ఇంకా 27, 54 పూసల మాలలు',
        ),
      ),
      (
        '🎨',
        t3(
          lang,
          'Three more app colours: Swarna, Neelakantha and Chandan',
          'ऐप के तीन और रंग: स्वर्ण, नीलकंठ और चंदन',
          'యాప్‌కు మరో మూడు రంగులు: స్వర్ణ, నీలకంఠ, చందనం',
        ),
      ),
      (
        '💬',
        t3(
          lang,
          'Chat directly with the developer for help and ideas',
          'मदद और सुझावों के लिए डेवलपर से सीधे बात करें',
          'సహాయం, సూచనల కోసం డెవలపర్‌తో నేరుగా మాట్లాడండి',
        ),
      ),
      (
        '👑',
        t3(
          lang,
          'A Premium badge, and you keep Devalay growing',
          'प्रीमियम बैज, और देवालय आगे बढ़ता रहे',
          'ప్రీమియం బ్యాడ్జ్, దేవాలయం ఎదుగుదలకు మీ తోడ్పాటు',
        ),
      ),
    ];
    final plans = s.premiumPlans();
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'premium'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GradientCard(
            colors: const [Color(0xFFFFB300), Color(0xFFE65100), Palette.maroon],
            child: Column(
              children: [
                const Text('👑', style: TextStyle(fontSize: 48)),
                Text(
                  premium
                      ? t3(lang, 'You are Premium', 'आप प्रीमियम सदस्य हैं', 'మీరు ప్రీమియం సభ్యులు')
                      : t3(lang, 'Devalay Premium', 'देवालय प्रीमियम', 'దేవాలయం ప్రీమియం'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  t3(
                    lang,
                    'Every aarti, mantra, scripture, Panchang and the Mandir are free forever. '
                        'Premium adds a few beautiful extras and keeps the app ad-free.',
                    'हर आरती, मंत्र, शास्त्र, पंचांग और मंदिर हमेशा मुफ़्त हैं। '
                        'प्रीमियम कुछ सुंदर अतिरिक्त चीज़ें जोड़ता है और ऐप को विज्ञापन-मुक्त रखता है।',
                    'ప్రతి హారతి, మంత్రం, గ్రంథం, పంచాంగం, మందిరం ఎప్పటికీ ఉచితమే. '
                        'ప్రీమియం కొన్ని అందమైన అదనపు సౌకర్యాలు జోడిస్తుంది, యాప్‌ను ప్రకటనలు లేకుండా ఉంచుతుంది.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final (emoji, text) in perks)
            ListTile(
              leading: Text(emoji, style: const TextStyle(fontSize: 24)),
              title: Text(text),
            ),
          const SizedBox(height: 12),
          if (premium) ...[const ChatEntryTile(), const SizedBox(height: 8)],
          if (premium)
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://play.google.com/store/account/subscriptions?package=com.chandrachaan.devalay'
                  '${s.premiumProduct == null ? '' : '&sku=${s.premiumProduct}'}',
                ),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.manage_accounts_rounded),
              label: Text(t3(lang, 'Manage subscription', 'सदस्यता प्रबंधित करें', 'సబ్‌స్క్రిప్షన్ నిర్వహించండి')),
            )
          else if (!s.ready)
            const Center(child: CircularProgressIndicator())
          else ...[
            for (final p in plans) _PlanCard(product: p, busy: s.busy),
            if (plans.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  !s.available
                      ? t3(
                          lang,
                          'Google Play payments are not available on this phone.',
                          'इस फ़ोन पर Google Play से भुगतान उपलब्ध नहीं है।',
                          'ఈ ఫోన్‌లో Google Play చెల్లింపులు అందుబాటులో లేవు.',
                        )
                      : t3(
                          lang,
                          'Premium is coming soon on Google Play.',
                          'प्रीमियम जल्द ही Google Play पर।',
                          'ప్రీమియం త్వరలో Google Playలో.',
                        ),
                  textAlign: TextAlign.center,
                ),
              ),
            TextButton(
              onPressed: s.available && !s.busy ? () => ref.read(billingProvider.notifier).restore() : null,
              child: Text(t3(lang, 'Restore purchases', 'खरीदारी वापस लाएँ', 'కొనుగోళ్లను పునరుద్ధరించండి')),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            t3(
              lang,
              'Billed by Google Play and renews automatically. Cancel anytime in Play Store > Payments & subscriptions.',
              'भुगतान Google Play से होता है और अपने-आप नवीनीकृत होता है। Play Store > Payments & subscriptions में कभी भी रद्द करें।',
              'చెల్లింపు Google Play ద్వారా, ఆటోమేటిక్‌గా రెన్యూ అవుతుంది. Play Store > Payments & subscriptionsలో ఎప్పుడైనా రద్దు చేయవచ్చు.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.push('/support?from=premium'),
            child: Text(
              t3(
                lang,
                'Prefer a one-time gift? Support Devalay',
                'एक बार का उपहार देना चाहते हैं? देवालय का साथ दें',
                'ఒకసారి కానుక ఇవ్వాలనుకుంటున్నారా? దేవాలయంకు అండగా నిలవండి',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.product, required this.busy});
  final ProductDetails product;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final yearly = product.id == Products.premiumYearly;
    final perMonth = yearly && product.rawPrice > 0
        ? '${product.currencySymbol}${(product.rawPrice / 12).ceil()}'
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: yearly
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Palette.marigold, width: 2),
              )
            : null,
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          title: Text(
            yearly ? t3(lang, 'Yearly', 'सालाना', 'సంవత్సరానికి') : t3(lang, 'Monthly', 'मासिक', 'నెలకు'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: perMonth == null
              ? null
              : Text(
                  t3(
                    lang,
                    'Best value: about $perMonth a month',
                    'सबसे किफ़ायती: लगभग $perMonth महीना',
                    'అత్యంత లాభం: నెలకు సుమారు $perMonth',
                  ),
                ),
          trailing: FilledButton(
            onPressed: busy ? null : () => ref.read(billingProvider.notifier).buy(product, source: 'premium'),
            child: Text(product.price),
          ),
        ),
      ),
    );
  }
}
