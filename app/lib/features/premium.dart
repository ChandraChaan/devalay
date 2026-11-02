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
        _note = 'Subscriptions are not yet published on Google Play for this build.';
      }
    } else {
      _note = 'Google Play billing is not available on this device.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.pending) {
        setState(() => _note = 'Payment pending. Premium unlocks once Google Play confirms.');
        continue;
      }
      if (p.status == PurchaseStatus.error) {
        setState(() => _note = p.error?.message ?? 'Purchase failed');
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
          if (mounted) toast(context, 'Premium unlocked. Thank you for supporting Devalay 🙏');
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
      toast(context, 'Please sign in first so Premium is linked to your account.');
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
        const [
          'Unlimited offline downloads',
          '100 AI status and Gita answers a day',
          'Support an ad-free devotional app',
        ];
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
                  auth.isPremium ? 'You are Premium' : 'Devalay Premium',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Every aarti, mantra, scripture, Panchang and the Mandir are free forever. '
                  'Premium adds conveniences and keeps the app ad-free.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
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
                    subtitle: Text('${plan['display_price_hint']} (indicative)'),
                  ),
                ),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_note!, textAlign: TextAlign.center),
              ),
            TextButton(
              onPressed: _storeAvailable ? () => _iap.restorePurchases() : null,
              child: const Text('Restore purchases'),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${_plans?['terms'] ?? 'Billed by Google Play. Cancel anytime in Play Store > Subscriptions.'}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
