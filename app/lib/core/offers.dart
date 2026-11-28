import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// How a Premium plan is offered, read from Google Play: Play lists one entry per base plan and per offer
/// the user is eligible for (a free trial only shows to people who never had one). Prices are never made up
/// here: a struck-through "original" price is always a real Play price (the renewal price after an intro
/// offer, or twelve months of the monthly plan next to the yearly one).
class PlanOffer {
  const PlanOffer({
    required this.product,
    required this.basePrice,
    required this.baseRaw,
    this.trialDays = 0,
    this.introPrice,
    this.introRaw,
    this.introPeriod,
    this.introCycles = 0,
  });

  /// What to buy: carries the offer token, so Play applies the trial or discount.
  final ProductDetails product;

  /// The recurring price after any offer ends.
  final String basePrice;
  final double baseRaw;

  /// Free days at the start (0 = no trial).
  final int trialDays;

  /// A discounted price for the first period(s), e.g. ₹299 for the first year.
  final String? introPrice;
  final double? introRaw;
  final String? introPeriod;
  final int introCycles;

  bool get hasTrial => trialDays > 0;
  bool get hasIntro => introRaw != null && introRaw! < baseRaw;

  /// What the first paid period costs.
  String get payNow => hasIntro ? introPrice! : basePrice;
  double get payNowRaw => hasIntro ? introRaw! : baseRaw;

  /// Percent off the intro price gives, rounded.
  int? get introPercentOff => hasIntro && baseRaw > 0 ? ((1 - introRaw! / baseRaw) * 100).round() : null;

  /// How attractive the offer is, to pick the best one Play lists: a free trial, then a discount.
  int get score => (hasTrial ? 2 : 0) + (hasIntro ? 1 : 0);
}

/// Days in an ISO 8601 billing period: P7D, P1W, P1M, P3M, P1Y.
int isoPeriodDays(String period) {
  final m = RegExp(r'^P(\d+)([DWMY])$').firstMatch(period);
  if (m == null) return 0;
  final n = int.parse(m[1]!);
  return switch (m[2]) {
    'D' => n,
    'W' => n * 7,
    'M' => n * 30,
    _ => n * 365,
  };
}

/// Reads one Play entry (a base plan or an offer) into a [PlanOffer].
PlanOffer describeOffer(ProductDetails p) {
  if (p is GooglePlayProductDetails && p.subscriptionIndex != null) {
    final offer = p.productDetails.subscriptionOfferDetails![p.subscriptionIndex!];
    final phases = offer.pricingPhases;
    final base = phases.last;
    final trial = phases.where((ph) => ph.priceAmountMicros == 0).firstOrNull;
    final intro = phases
        .take(phases.length - 1)
        .where((ph) => ph.priceAmountMicros > 0 && ph.priceAmountMicros < base.priceAmountMicros)
        .firstOrNull;
    return PlanOffer(
      product: p,
      basePrice: base.formattedPrice,
      baseRaw: base.priceAmountMicros / 1e6,
      trialDays: trial == null ? 0 : isoPeriodDays(trial.billingPeriod) * (trial.billingCycleCount.clamp(1, 12)),
      introPrice: intro?.formattedPrice,
      introRaw: intro == null ? null : intro.priceAmountMicros / 1e6,
      introPeriod: intro?.billingPeriod,
      introCycles: intro?.billingCycleCount ?? 0,
    );
  }
  return PlanOffer(product: p, basePrice: p.price, baseRaw: p.rawPrice);
}

/// The best offer for each product id among the entries Play returned: a free trial, then a discount,
/// then the plain base plan.
Map<String, ProductDetails> bestOffers(List<ProductDetails> entries) {
  final best = <String, PlanOffer>{};
  for (final p in entries) {
    final o = describeOffer(p);
    final current = best[p.id];
    if (current == null || o.score > current.score) best[p.id] = o;
  }
  return {for (final e in best.entries) e.key: e.value.product};
}
