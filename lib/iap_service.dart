import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

class IapService {
  static const String premiumProductId = 'mytree_premium_unlock';

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  ProductDetails? _premiumProduct;
  bool _storeAvailable = false;
  bool _initialized = false;

  ProductDetails? get premiumProduct => _premiumProduct;
  bool get storeAvailable => _storeAvailable;
  bool get isInitialized => _initialized;

  Future<void> init({
    required Future<void> Function() onPremiumUnlocked,
    required void Function(String message) onError,
    void Function(String message)? onInfo,
  }) async {
    if (_initialized) return;

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      onError('Store is not available on this device.');
      return;
    }

    final ProductDetailsResponse response =
        await _iap.queryProductDetails({premiumProductId});

    if (response.error != null) {
      onError('Failed to load product: ${response.error!.message}');
    } else if (response.productDetails.isEmpty) {
      onError('Product not found: $premiumProductId');
    } else {
      _premiumProduct = response.productDetails.first;
    }

    _purchaseSub = _iap.purchaseStream.listen(
      (List<PurchaseDetails> purchases) async {
        for (final purchase in purchases) {
          if (purchase.productID != premiumProductId) continue;

          switch (purchase.status) {
            case PurchaseStatus.pending:
              onInfo?.call('Purchase pending…');
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              try {
                await onPremiumUnlocked();
              } catch (e) {
                onError('Unlock failed: $e');
              }
            case PurchaseStatus.error:
              onError(purchase.error?.message ?? 'Purchase failed.');
            case PurchaseStatus.canceled:
              onInfo?.call('Purchase canceled.');
          }

          if (purchase.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchase);
            } catch (e) {
              onError('Complete purchase failed: $e');
            }
          }
        }
      },
      onError: (Object error) => onError('Purchase stream error: $error'),
    );

    _initialized = true;
    onInfo?.call('IAP initialized. Product: ${_premiumProduct?.price ?? 'not loaded'}');
  }

  Future<void> buyPremium() async {
    final product = _premiumProduct;
    if (product == null) throw Exception('Premium product not loaded.');
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    _initialized = false;
  }
}
