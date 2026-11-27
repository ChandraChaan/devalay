import 'dart:async';

import 'package:devalay/core/billing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Stand-ins for Google Play Billing in tests.
ProductDetails product(String id, double rupees) => ProductDetails(
  id: id,
  title: id,
  description: '',
  price: '₹${rupees.toStringAsFixed(0)}',
  rawPrice: rupees,
  currencyCode: 'INR',
  currencySymbol: '₹',
);

PurchaseDetails purchase(String id, PurchaseStatus status, {bool acknowledged = false}) => PurchaseDetails(
  productID: id,
  verificationData: PurchaseVerificationData(
    localVerificationData: '{}',
    serverVerificationData: 'token-$id',
    source: 'test',
  ),
  transactionDate: '0',
  status: status,
)..pendingCompletePurchase = !acknowledged;

final allProducts = [
  product(Products.premiumYearly, 299),
  product(Products.premiumMonthly, 49),
  product(Products.support11, 11),
  product(Products.support51, 51),
  product(Products.support101, 101),
  product(Products.support251, 251),
];

class FakeStore implements BillingStore {
  FakeStore({this.available = true, this.owned = const [], List<ProductDetails>? products})
    : products = products ?? allProducts;
  bool available;
  List<PurchaseDetails>? owned;
  List<ProductDetails> products;
  final stream = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <String>[];
  final consumed = <String>[];
  final bought = <(String, bool)>[];

  @override
  Future<bool> isAvailable() async => available;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => stream.stream;
  @override
  Future<List<ProductDetails>> queryProducts(Set<String> ids) async =>
      products.where((p) => ids.contains(p.id)).toList();
  @override
  Future<List<PurchaseDetails>?> ownedPurchases() async => owned;
  @override
  Future<bool> buy(ProductDetails product, {required bool consumable}) async {
    bought.add((product.id, consumable));
    return true;
  }

  @override
  Future<void> complete(PurchaseDetails purchase) async => completed.add(purchase.productID);
  @override
  Future<void> consume(PurchaseDetails purchase) async => consumed.add(purchase.productID);
}

/// Keeps the Play answer in memory: Hive writes started inside a widget test's fake-async zone never
/// finish and would block the box for every later test.
class MemoryCache implements PremiumCache {
  MemoryCache({this.premium = false, this.checkedAt, this.product});
  @override
  bool premium;
  @override
  DateTime? checkedAt;
  @override
  String? product;
  DateTime? giftAt;

  @override
  void save({required bool premium, required DateTime checkedAt, String? product}) {
    this.premium = premium;
    this.checkedAt = checkedAt;
    this.product = product;
  }

  @override
  void gave(DateTime at) => giftAt = at;
}

MemoryCache cachedPremium() => MemoryCache(premium: true, checkedAt: DateTime.now());

List billingOverrides(FakeStore store, [MemoryCache? cache]) => [
  premiumCacheProvider.overrideWithValue(cache ?? MemoryCache()),
  billingStoreProvider.overrideWithValue(store),
  billingSupportedProvider.overrideWithValue(true),
  billingStartDelayProvider.overrideWithValue(Duration.zero),
];
