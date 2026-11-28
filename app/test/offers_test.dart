import 'package:devalay/core/offers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Free trial and discount offers, as Google Play lists them.
void main() {
  PricingPhaseWrapper phase(int rupees, String period, {int cycles = 0}) => PricingPhaseWrapper(
    billingCycleCount: cycles,
    billingPeriod: period,
    formattedPrice: rupees == 0 ? 'Free' : '₹$rupees',
    priceAmountMicros: rupees * 1000000,
    priceCurrencyCode: 'INR',
    recurrenceMode: cycles == 0 ? RecurrenceMode.infiniteRecurring : RecurrenceMode.finiteRecurring,
  );

  /// The yearly plan with a base plan and one offer: 7 days free, then ₹299 for the first year, then ₹499.
  List<GooglePlayProductDetails> yearly({bool withOffer = true}) => GooglePlayProductDetails.fromProductDetails(
    ProductDetailsWrapper(
      description: '',
      name: 'Premium',
      productId: 'devalay_premium_yearly',
      productType: ProductType.subs,
      title: 'Premium',
      subscriptionOfferDetails: [
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'yearly',
          offerTags: const [],
          offerIdToken: 'base',
          pricingPhases: [phase(499, 'P1Y')],
        ),
        if (withOffer)
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'yearly',
            offerId: 'launch',
            offerTags: const [],
            offerIdToken: 'launch-token',
            pricingPhases: [phase(0, 'P7D', cycles: 1), phase(299, 'P1Y', cycles: 1), phase(499, 'P1Y')],
          ),
      ],
    ),
  );

  test('billing periods in days', () {
    expect(isoPeriodDays('P7D'), 7);
    expect(isoPeriodDays('P1W'), 7);
    expect(isoPeriodDays('P1M'), 30);
    expect(isoPeriodDays('P1Y'), 365);
    expect(isoPeriodDays('bad'), 0);
  });

  test('a launch offer reads as 7 days free, then ₹299 the first year (40% off), then ₹499', () {
    final o = describeOffer(yearly()[1]);
    expect(o.trialDays, 7);
    expect(o.hasIntro, isTrue);
    expect(o.payNow, '₹299');
    expect(o.basePrice, '₹499');
    expect(o.introPercentOff, 40);
  });

  test('the best offer the user can get is kept, with its offer token', () {
    final best = bestOffers(yearly());
    final chosen = best['devalay_premium_yearly']! as GooglePlayProductDetails;
    expect(chosen.offerToken, 'launch-token');
  });

  test('without an offer (already used the trial), the base plan is shown as is', () {
    final best = bestOffers(yearly(withOffer: false));
    final o = describeOffer(best['devalay_premium_yearly']!);
    expect(o.hasTrial, isFalse);
    expect(o.hasIntro, isFalse);
    expect(o.payNow, '₹499');
  });

  test('a product that is not a Play subscription uses its own price', () {
    final p = ProductDetails(id: 'x', title: 'x', description: '', price: '₹49', rawPrice: 49, currencyCode: 'INR');
    expect(describeOffer(p).payNow, '₹49');
  });
}
