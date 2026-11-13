import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/api.dart';
import '../core/auth.dart';
import '../core/config.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Optional Google Play subscription. Prices come from Play itself, the plan is
/// cancellable anytime in Play, and every devotional feature stays free.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products = const [];
  Map? _plans;
  bool _storeAvailable = false;
  bool _loading = true;
  bool _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) => setState(() => _note = '$e'));
    _load();
  }

  Future<void> _load() async {
    try {
      _plans = await ref.read(apiProvider).get('/premium/plans') as Map;
    } catch (_) {}
    _storeAvailable = await _iap.isAvailable();
    if (_storeAvailable) {
      final r = await _iap.queryProductDetails(AppConfig.premiumProductIds);
      _products = r.productDetails..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      if (r.notFoundIDs.isNotEmpty && _products.isEmpty) {
        _note = t3(
          appLang,
          'Subscriptions are not yet published on Google Play for this build.',
          'इस संस्करण के लिए सदस्यताएँ अभी Google Play पर उपलब्ध नहीं हैं।',
          'ఈ వెర్షన్‌కు సబ్‌స్క్రిప్షన్లు ఇంకా Google Playలో అందుబాటులో లేవు.',
        );
      }
    } else {
      _note = t3(
        appLang,
        'Google Play billing is not available on this device.',
        'इस फ़ोन पर Google Play से भुगतान उपलब्ध नहीं है।',
        'ఈ ఫోన్‌లో Google Play బిల్లింగ్ అందుబాటులో లేదు.',
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.pending) {
        setState(
          () => _note = t3(
            appLang,
            'Payment pending. Premium unlocks once Google Play confirms.',
            'भुगतान बाकी है। Google Play की पुष्टि होते ही प्रीमियम खुल जाएगा।',
            'చెల్లింపు పెండింగ్‌లో ఉంది. Google Play నిర్ధారించగానే ప్రీమియం మొదలవుతుంది.',
          ),
        );
        continue;
      }
      if (p.status == PurchaseStatus.error) {
        setState(
          () => _note = p.error?.message ?? t3(appLang, 'Purchase failed', 'खरीद नहीं हो सकी', 'కొనుగోలు విఫలమైంది'),
        );
      }
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        try {
          await ref
              .read(apiProvider)
              .post(
                '/premium/verify',
                data: {'product_id': p.productID, 'purchase_token': p.verificationData.serverVerificationData},
              );
          await ref.read(authProvider.notifier).refreshProfile();
          if (mounted) {
            toast(
              context,
              t3(
                appLang,
                'Premium unlocked. Thank you for supporting Devalay 🙏',
                'प्रीमियम शुरू हो गया। देवालय का साथ देने के लिए धन्यवाद 🙏',
                'ప్రీమియం మొదలైంది. దేవాలయంకు అండగా నిలిచినందుకు ధన్యవాదాలు 🙏',
              ),
            );
          }
        } on ApiException catch (e) {
          setState(() => _note = e.message);
        }
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _buy(ProductDetails product) async {
    if (!ref.read(authProvider).signedIn) {
      toast(
        context,
        t3(
          appLang,
          'Please sign in first so Premium is linked to your account.',
          'पहले साइन इन करें, ताकि प्रीमियम आपके खाते से जुड़ जाए।',
          'ముందుగా సైన్ ఇన్ చేయండి, అప్పుడు ప్రీమియం మీ ఖాతాకు జతవుతుంది.',
        ),
      );
      context.push('/login');
      return;
    }
    setState(() => _busy = true);
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final benefits =
        (_plans?['benefits'] as List?)?.cast<String>() ??
        [
          l3(ref, 'Unlimited offline downloads', 'असीमित ऑफ़लाइन डाउनलोड', 'అపరిమిత ఆఫ్‌లైన్ డౌన్‌లోడ్లు'),
          l3(
            ref,
            '100 AI status and Gita answers a day',
            'रोज़ 100 AI स्टेटस और गीता के उत्तर',
            'రోజుకు 100 AI స్టేటస్‌లు, గీతా సమాధానాలు',
          ),
          l3(
            ref,
            'Support an ad-free devotional app',
            'विज्ञापन-मुक्त भक्ति ऐप का साथ दें',
            'ప్రకటనలు లేని భక్తి యాప్‌కు అండగా నిలవండి',
          ),
        ];
    final terms =
        _plans?['terms'] ??
        l3(
          ref,
          'Billed by Google Play. Cancel anytime in Play Store > Subscriptions.',
          'भुगतान Google Play से होता है। Play Store > Subscriptions में जाकर कभी भी रद्द करें।',
          'చెల్లింపు Google Play ద్వారా జరుగుతుంది. Play Store > Subscriptionsలో ఎప్పుడైనా రద్దు చేయవచ్చు.',
        );
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
                  auth.isPremium
                      ? l3(ref, 'You are Premium', 'आप प्रीमियम सदस्य हैं', 'మీరు ప్రీమియం సభ్యులు')
                      : l3(ref, 'Devalay Premium', 'देवालय प्रीमियम', 'దేవాలయం ప్రీమియం'),
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  l3(
                    ref,
                    'Every aarti, mantra, scripture, Panchang and the Mandir are free forever. '
                        'Premium adds conveniences and keeps the app ad-free.',
                    'हर आरती, मंत्र, शास्त्र, पंचांग और मंदिर हमेशा मुफ़्त हैं। '
                        'प्रीमियम कुछ सुविधाएँ जोड़ता है और ऐप को विज्ञापन-मुक्त रखता है।',
                    'ప్రతి హారతి, మంత్రం, గ్రంథం, పంచాంగం, మందిరం ఎప్పటికీ ఉచితమే. '
                        'ప్రీమియం కొన్ని సౌకర్యాలు జోడిస్తుంది, యాప్‌ను ప్రకటనలు లేకుండా ఉంచుతుంది.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final b in benefits)
            ListTile(
              leading: const Icon(Icons.check_circle_rounded, color: Colors.green),
              title: Text(b),
            ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (!auth.isPremium) ...[
            for (final p in _products)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    title: Text(
                      p.title.replaceAll(RegExp(r'\s*\(.*\)$'), ''),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(p.description),
                    trailing: FilledButton(onPressed: _busy ? null : () => _buy(p), child: Text(p.price)),
                  ),
                ),
              ),
            if (_products.isEmpty && _plans != null)
              for (final plan in (_plans!['plans'] as List).cast<Map>())
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text('${plan['title']}'),
                    subtitle: Text(
                      l3(
                        ref,
                        '${plan['display_price_hint']} (indicative)',
                        '${plan['display_price_hint']} (अनुमानित)',
                        '${plan['display_price_hint']} (సుమారుగా)',
                      ),
                    ),
                  ),
                ),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_note!, textAlign: TextAlign.center),
              ),
            TextButton(
              onPressed: _storeAvailable ? () => _iap.restorePurchases() : null,
              child: Text(l3(ref, 'Restore purchases', 'खरीदारी वापस लाएँ', 'కొనుగోళ్లను పునరుద్ధరించండి')),
            ),
          ],
          const SizedBox(height: 8),
          Text('$terms', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
