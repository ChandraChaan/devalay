import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'auth.dart';
import 'offers.dart';
import 'storage.dart';
import 'usage.dart';

/// Google Play products. Premium is a subscription; support and dakshina are consumable one-time
/// products that can be bought again. Prices are set in Play Console and shown as Play returns them.
class Products {
  Products._();
  static const premiumYearly = 'devalay_premium_yearly';
  static const premiumMonthly = 'devalay_premium_monthly';
  static const premium = {premiumYearly, premiumMonthly};

  static const support11 = 'devalay_support_11';
  static const support51 = 'devalay_support_51';
  static const support101 = 'devalay_support_101';
  static const support251 = 'devalay_support_251';

  /// Offered in the Mandir as dakshina: the traditional 11, 51 and 101.
  static const dakshina = [support11, support51, support101];

  /// Offered on the Support Devalay screen.
  static const support = [support11, support51, support101, support251];
  static const all = {...premium, ...support};

  /// The rupee amount in a support product id, for sorting and as a fallback label.
  static int rupees(String id) => int.tryParse(id.split('_').last) ?? 0;
}

/// What a screen shows after a purchase step. [id] grows with each event, so listeners can tell
/// two identical events apart.
enum BillingNotice { thanksPremium, thanksSupport, pending, failed, restored, nothingToRestore }

/// How long Premium stays on from the last successful check when Play can't be reached
/// (no network, Play Store being updated). Play itself keeps purchases cached, so this is rare.
const premiumGrace = Duration(days: 30);

/// Premium from what Play reports, falling back to the cached answer while Play is unreachable.
/// [owned] is null when Play couldn't be asked.
bool premiumFrom({required Set<String>? owned, required bool cached, DateTime? checkedAt, required DateTime now}) {
  if (owned != null) return owned.any(Products.premium.contains);
  if (!cached || checkedAt == null) return false;
  return now.difference(checkedAt) < premiumGrace && !checkedAt.isAfter(now.add(const Duration(days: 1)));
}

class BillingState {
  const BillingState({
    this.ready = false,
    this.available = false,
    this.premium = false,
    this.premiumProduct,
    this.products = const {},
    this.busy = false,
    this.notice,
    this.noticeId = 0,
    this.noticeText,
  });

  /// The store was asked (successfully or not); screens show a spinner until then.
  final bool ready;

  /// Google Play Billing works on this phone.
  final bool available;
  final bool premium;
  final String? premiumProduct;

  /// Products Play knows about, by id. Missing ids are not yet published in Play Console.
  final Map<String, ProductDetails> products;

  /// A purchase is in progress.
  final bool busy;
  final BillingNotice? notice;
  final int noticeId;
  final String? noticeText;

  List<ProductDetails> premiumPlans() {
    final plans = [
      for (final id in [Products.premiumYearly, Products.premiumMonthly])
        if (products[id] != null) products[id]!,
    ];
    return plans;
  }

  List<ProductDetails> supportProducts(List<String> ids) => [
    for (final id in ids)
      if (products[id] != null) products[id]!,
  ];

  BillingState copyWith({
    bool? ready,
    bool? available,
    bool? premium,
    String? premiumProduct,
    Map<String, ProductDetails>? products,
    bool? busy,
    BillingNotice? notice,
    String? noticeText,
  }) => BillingState(
    ready: ready ?? this.ready,
    available: available ?? this.available,
    premium: premium ?? this.premium,
    premiumProduct: premiumProduct ?? this.premiumProduct,
    products: products ?? this.products,
    busy: busy ?? this.busy,
    notice: notice ?? this.notice,
    noticeId: notice == null ? noticeId : noticeId + 1,
    noticeText: notice == null ? this.noticeText : noticeText,
  );
}

/// The slice of Google Play Billing Devalay uses, so tests can stand in a fake store.
abstract class BillingStore {
  Future<bool> isAvailable();
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<List<ProductDetails>> queryProducts(Set<String> ids);

  /// Active subscriptions and unconsumed one-time purchases, or null when Play can't be asked.
  Future<List<PurchaseDetails>?> ownedPurchases();
  Future<bool> buy(ProductDetails product, {required bool consumable});
  Future<void> complete(PurchaseDetails purchase);
  Future<void> consume(PurchaseDetails purchase);
}

class PlayBillingStore implements BillingStore {
  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<List<ProductDetails>> queryProducts(Set<String> ids) async =>
      (await _iap.queryProductDetails(ids)).productDetails;

  @override
  Future<List<PurchaseDetails>?> ownedPurchases() async {
    final addition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final r = await addition.queryPastPurchases();
    if (r.error != null) return null;
    return r.pastPurchases;
  }

  @override
  Future<bool> buy(ProductDetails product, {required bool consumable}) {
    final param = PurchaseParam(productDetails: product);
    // Tips are consumed by [BillingController] itself, so a failed consume never reads as a failed payment.
    return consumable
        ? _iap.buyConsumable(purchaseParam: param, autoConsume: false)
        : _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> complete(PurchaseDetails purchase) => _iap.completePurchase(purchase);

  @override
  Future<void> consume(PurchaseDetails purchase) async {
    await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().consumePurchase(purchase);
  }
}

/// Where the last answer from Play is kept on the phone, so Premium survives a day offline.
class PremiumCache {
  bool get premium => Boxes.prefs.get('premium', defaultValue: false) == true;
  DateTime? get checkedAt => DateTime.tryParse('${Boxes.prefs.get('premium_checked', defaultValue: '')}');
  String? get product {
    final p = Boxes.prefs.get('premium_product');
    return p is String ? p : null;
  }

  void save({required bool premium, required DateTime checkedAt, String? product}) {
    Boxes.prefs.putAll({'premium': premium, 'premium_checked': checkedAt.toIso8601String()});
    if (product != null) {
      Boxes.prefs.put('premium_product', product);
    } else {
      Boxes.prefs.delete('premium_product');
    }
  }

  /// A tip was given: keeps the gentle support card away for a while.
  void gave(DateTime at) => Boxes.stats.put('support_gift_at', at.toIso8601String());
}

final premiumCacheProvider = Provider<PremiumCache>((_) => PremiumCache());

/// Google Play Billing only exists in the Android app.
bool get billingSupported => !kIsWeb && Platform.isAndroid;

final billingStoreProvider = Provider<BillingStore>((_) => PlayBillingStore());

/// Delay before talking to Play at startup, so the first screen is not slowed down.
final billingStartDelayProvider = Provider<Duration>((_) => const Duration(seconds: 3));

/// Whether Play Billing is supported here; tests override it.
final billingSupportedProvider = Provider<bool>((_) => billingSupported);

/// Premium and tips through Google Play Billing, with no server: Play's own purchase records on the
/// phone are the source of truth. At start (and after each purchase) the app asks Play which
/// subscriptions are active; the answer is cached so Premium survives a day without network.
/// Purchases are acknowledged (Play refunds unacknowledged ones after three days) and tips consumed,
/// so they can be given again.
class BillingController extends Notifier<BillingState> {
  StreamSubscription<List<PurchaseDetails>>? _sub;
  String _source = '';
  Future<void>? _start;

  BillingStore get _store => ref.read(billingStoreProvider);
  PremiumCache get _cache => ref.read(premiumCacheProvider);

  @override
  BillingState build() {
    ref.onDispose(() => _sub?.cancel());
    final cache = _cache;
    final premium = premiumFrom(owned: null, cached: cache.premium, checkedAt: cache.checkedAt, now: DateTime.now());
    final product = cache.product;
    if (ref.read(billingSupportedProvider)) {
      final delay = ref.read(billingStartDelayProvider);
      Future.delayed(delay, () {
        if (ref.mounted) start();
      });
    }
    return BillingState(premium: premium, premiumProduct: premium ? product : null);
  }

  /// Connects to Play once: listens for purchases, loads products and checks what is owned. Later
  /// calls wait for the same start.
  Future<void> start() => _start ??= _connect();

  Future<void> _connect() async {
    try {
      final available = await _store.isAvailable();
      if (!ref.mounted) return;
      if (!available) {
        state = state.copyWith(ready: true, available: false);
        return;
      }
      _sub = _store.purchaseStream.listen(_onPurchases, onError: (Object e) => _notify(BillingNotice.failed, '$e'));
      state = state.copyWith(available: true);
      await Future.wait([loadProducts(), refresh()]);
    } catch (e) {
      debugPrint('billing not started: $e');
    } finally {
      if (ref.mounted) state = state.copyWith(ready: true);
    }
  }

  Future<void> loadProducts() async {
    try {
      final list = await _store.queryProducts(Products.all);
      if (!ref.mounted) return;
      // Play lists a subscription once per base plan and offer; keep the best one the user can get.
      state = state.copyWith(products: bestOffers(list));
    } catch (e) {
      debugPrint('products not loaded: $e');
    }
  }

  /// Asks Play what this Google account owns, finishes any purchase left half-done (acknowledge a
  /// subscription, consume a tip) and updates Premium.
  Future<void> refresh() async {
    List<PurchaseDetails>? owned;
    try {
      owned = await _store.ownedPurchases();
    } catch (e) {
      debugPrint('purchases not checked: $e');
    }
    if (!ref.mounted) return;
    final active = owned?.where((p) => p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored);
    if (active != null) {
      for (final p in active) {
        await _finish(p);
      }
    }
    if (!ref.mounted) return;
    _setPremium(active?.map((p) => p.productID).toSet());
  }

  void _setPremium(Set<String>? owned) {
    final now = DateTime.now();
    final cache = _cache;
    final premium = premiumFrom(owned: owned, cached: cache.premium, checkedAt: cache.checkedAt, now: now);
    String? product = state.premiumProduct;
    if (owned != null) {
      product = Products.premium.where(owned.contains).firstOrNull;
      cache.save(premium: premium, checkedAt: now, product: product);
    }
    if (premium != state.premium) Usage.property('premium', premium ? 'yes' : 'no');
    state = BillingState(
      ready: state.ready,
      available: state.available,
      premium: premium,
      premiumProduct: premium ? product : null,
      products: state.products,
      busy: state.busy,
      notice: state.notice,
      noticeId: state.noticeId,
      noticeText: state.noticeText,
    );
  }

  Future<void> _finish(PurchaseDetails p) async {
    try {
      if (Products.support.contains(p.productID)) {
        // A tip that was paid but never consumed (the app closed mid-purchase) blocks buying the same
        // amount again; consuming it frees it.
        await _store.consume(p);
      } else if (p.pendingCompletePurchase) {
        await _store.complete(p);
      }
    } catch (e) {
      debugPrint('purchase not finished: $e');
    }
  }

  /// Starts a purchase. [source] says where it was started ('premium', 'mandir', 'more', 'prompt').
  Future<void> buy(ProductDetails product, {required String source}) async {
    if (state.busy) return;
    _source = source;
    final consumable = Products.support.contains(product.id);
    Usage.record(consumable ? 'support_tap' : 'premium_buy_tap', item: product.id, params: {'source': source});
    state = state.copyWith(busy: true);
    try {
      final started = await _store.buy(product, consumable: consumable);
      if (!started && ref.mounted) state = state.copyWith(busy: false);
    } catch (e) {
      Usage.record('purchase_fail', item: product.id);
      _notify(BillingNotice.failed, '$e');
    }
  }

  Future<void> restore() async {
    Usage.record('premium_restore_tap');
    await refresh();
    _notify(state.premium ? BillingNotice.restored : BillingNotice.nothingToRestore);
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (!ref.mounted) return;
      final premium = Products.premium.contains(p.productID);
      switch (p.status) {
        case PurchaseStatus.pending:
          Usage.record('purchase_pending', item: p.productID);
          _notify(BillingNotice.pending);
        case PurchaseStatus.canceled:
          Usage.record('purchase_cancel', item: p.productID);
          state = state.copyWith(busy: false);
        case PurchaseStatus.error:
          Usage.record('purchase_fail', item: p.productID);
          _notify(BillingNotice.failed, p.error?.message);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (p.status == PurchaseStatus.purchased) {
            Usage.record('purchase_ok', item: p.productID, params: {'source': _source});
          }
          if (premium) {
            _setPremium({...?_ownedPremium(), p.productID});
            if (p.status == PurchaseStatus.purchased) _notify(BillingNotice.thanksPremium);
          } else if (Products.support.contains(p.productID)) {
            await _finish(p);
            if (p.status == PurchaseStatus.purchased) {
              _cache.gave(DateTime.now());
              _notify(BillingNotice.thanksSupport);
            }
            continue; // consumed: nothing left to acknowledge
          }
      }
      if (p.pendingCompletePurchase) {
        try {
          await _store.complete(p);
        } catch (e) {
          debugPrint('purchase not completed: $e');
        }
      }
    }
  }

  Set<String>? _ownedPremium() => state.premiumProduct == null ? null : {state.premiumProduct!};

  void _notify(BillingNotice notice, [String? text]) {
    if (!ref.mounted) return;
    state = state.copyWith(busy: false, notice: notice, noticeText: text);
  }
}

final billingProvider = NotifierProvider<BillingController, BillingState>(BillingController.new);

/// Debug builds started with `--dart-define=DEBUG_PREMIUM=true` act as Premium, to try the member
/// features on an emulator without Google Play. Release builds ignore it ([kDebugMode] is false).
const debugPremium = kDebugMode && bool.fromEnvironment('DEBUG_PREMIUM');

/// Premium from Google Play, or from the account on server builds.
final premiumProvider = Provider<bool>(
  (ref) =>
      debugPremium ||
      ref.watch(billingProvider.select((s) => s.premium)) ||
      ref.watch(authProvider.select((a) => a.isPremium)),
);
