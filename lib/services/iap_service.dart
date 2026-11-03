import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real Play Billing tip jar for Flow Lines: Tip jar (all content is free and unlocked).
///
/// Product IDs (the user creates these in Play Console):
/// - `flowlinescoffee` — CONSUMABLE tip.
/// - `flowlineschocolate` — CONSUMABLE tip.
///
/// Until the products exist in Play Console (or on any store error) the
/// service exposes [storeReady] = false and the UI shows an honest
/// "available after store setup" state — never a fake buy button.
class StoreService {
  static const coffeeId = 'flowlinescoffee';
  static const chocolateId = 'flowlineschocolate';
  static const starId = 'flowlinesstar';
  static const productIds = {coffeeId, chocolateId};
  /// Platform-gated product set: iOS gets only the Gold Star
  /// non-consumable; Android keeps coffee + chocolate. Pure function.
  static Set<String> productIdsFor(TargetPlatform p) =>
      p == TargetPlatform.iOS ? {starId} : {coffeeId, chocolateId};
  ProductDetails? get proProduct => null; // Pro removed — everything is free

  InAppPurchase? _iap; // lazy: InAppPurchase has no web implementation

  bool available = false;
  bool storeReady = false; // true once real products are queryable
  List<ProductDetails> products = [];
  String? error;
  bool _initialized = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Callbacks the UI wires up.
  final ValueNotifier<String?> lastThanks = ValueNotifier(null);
  final ValueNotifier<bool> proPurchased = ValueNotifier(true); // everything unlocked
  final ValueNotifier<bool> purchaseInProgress = ValueNotifier(false);
  final ValueNotifier<String?> purchaseError = ValueNotifier(null);

  ProductDetails? get coffeeProduct => _byId(coffeeId);
  ProductDetails? get chocolateProduct => _byId(chocolateId);
  ProductDetails? get starProduct => _byId(starId);
  bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  /// Gold Star ownership (iOS only, non-consumable, persisted).
  final ValueNotifier<bool> starOwned = ValueNotifier(false);

  ProductDetails? _byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // No store on web — skip billing entirely (UI shows fallback).
    if (kIsWeb) {
      available = false;
      error = 'Tips unavailable on web';
      return;
    }
    _iap = InAppPurchase.instance;
    try {
      available = await _iap!.isAvailable();
      if (!available) {
        error = 'Store unavailable on this device';
        return;
      }
      _sub = _iap!.purchaseStream.listen(
        _onPurchases,
        onError: (_) {},
        cancelOnError: false,
      );
      final resp = await _iap!.queryProductDetails(productIdsFor(defaultTargetPlatform));
      if (resp.error != null) {
        error = 'Could not reach the store';
        return;
      }
      products = resp.productDetails;
      // Products not yet created in Play Console simply don't appear here;
      // whatever IS queryable is buyable. Fully empty = pre-launch state.
      storeReady = products.isNotEmpty;
      if (!storeReady) error = 'Available after store setup';
      if (isIOS) await _loadStarOwned();
    } catch (_) {
      available = false;
      error = 'Store error';
    }
  }

  Future<void> _loadStarOwned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      starOwned.value = prefs.getBool('gold_star_owned') ?? false;
    } catch (_) {}
  }

  Future<void> _persistStarOwned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('gold_star_owned', true);
    } catch (_) {}
  }

  void _onPurchases(List<PurchaseDetails> list) {
    for (final p in list) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        if (p.productID == starId) {
          starOwned.value = true;
          lastThanks.value = 'Thank you — you have the Gold Star! \u2b50';
          _persistStarOwned();
        } else if (p.productID == chocolateId) {
          lastThanks.value = 'Thank you for the chocolate!';
        } else if (p.productID == coffeeId) {
          lastThanks.value = 'Thank you for the coffee!';
        }
      } else if (p.status == PurchaseStatus.error) {
        purchaseError.value = 'Purchase failed — please try again.';
      } else if (p.status == PurchaseStatus.canceled) {
        purchaseError.value = null;
      }
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored ||
          p.status == PurchaseStatus.canceled ||
          p.status == PurchaseStatus.error) {
        purchaseInProgress.value = false;
      }
      if (p.pendingCompletePurchase) {
        _iap!.completePurchase(p).catchError((_) {});
      }
    }
  }

  
  
  Future<void> buyTip(ProductDetails product) async {
    purchaseError.value = null;
    purchaseInProgress.value = true;
    try {
      await _iap!.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      purchaseInProgress.value = false;
      purchaseError.value = 'Purchase failed — please try again.';
    }
  }

  /// iOS Gold Star: NON-consumable. Never consumed; acknowledged via
  /// completePurchase in _onPurchases. Game stays fully unlocked.
  Future<void> buyStar(ProductDetails product) async {
    purchaseError.value = null;
    purchaseInProgress.value = true;
    try {
      await _iap!.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      purchaseInProgress.value = false;
      purchaseError.value = 'Purchase failed — please try again.';
    }
  }

  /// Restore Pro on a new device. The purchase stream delivers restored
  /// purchases, which flip [proPurchased].
  Future<void> restore() async {
    purchaseError.value = null;
    try {
      await _iap!.restorePurchases();
    } catch (_) {
      purchaseError.value = 'Restore failed — please try again.';
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    lastThanks.dispose();
    purchaseInProgress.dispose();
    purchaseError.dispose();
  }
}
