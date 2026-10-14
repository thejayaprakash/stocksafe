import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// The lifetime unlock, as configured in the Play Console.
///
/// A **non-consumable managed product**, not a subscription: StockSafe is sold
/// once and owned forever, and Play then remembers the entitlement against the
/// buyer's Google account. That is what makes a reinstall, or a new phone,
/// cost nothing — the thing a shopkeeper asks about first.
const String kProProductId = 'stocksafe_pro_lifetime';

/// What a purchase attempt ended as.
enum BillingOutcome {
  /// Paid and owned. Unlock now.
  purchased,

  /// Play returned a purchase this account already owned.
  restored,

  /// Money has not moved yet and may not for hours.
  ///
  /// UPI, net-banking and cash-based methods settle asynchronously. Treating
  /// this as a failure tells a shopkeeper who has already paid that their
  /// payment did not work; treating it as success gives the app away to anyone
  /// who starts a payment and abandons it. It is its own state, and the UI has
  /// to say so.
  pending,

  /// The shopkeeper backed out. Not an error, and not worth a message.
  cancelled,

  /// Asked, and this account owns nothing.
  nothingToRestore,

  /// Billing is unavailable: no Play Services, no product configured, or a
  /// build that has never been uploaded. Ours to fix, not theirs.
  unavailable,

  /// The store returned an error.
  failed,
}

class BillingResult {
  const BillingResult(this.outcome, {this.orderId, this.message});

  final BillingOutcome outcome;

  /// Play's order id, kept so a disputed unlock can be traced.
  final String? orderId;

  final String? message;

  bool get grantsUnlock =>
      outcome == BillingOutcome.purchased || outcome == BillingOutcome.restored;
}

/// The slice of [InAppPurchase] this app uses.
///
/// Exists so the purchase flow can be tested without a Play Console, a signed
/// build, or a device — the three things that make billing bugs expensive to
/// find late.
abstract class BillingPlatform {
  Future<bool> isAvailable();
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

/// [BillingPlatform] backed by the real plugin.
class PluginBillingPlatform implements BillingPlatform {
  PluginBillingPlatform([InAppPurchase? iap])
      : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _iap.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _iap.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases() => _iap.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);
}

/// Buys and restores the lifetime unlock through Google Play.
///
/// **Why this is the primary path, with vouchers as the fallback.** Play binds
/// the purchase to the Google account rather than the device, so it survives
/// uninstalling, factory resets and new phones with no action from us and no
/// server of ours. A signed offline voucher cannot do that: it is a bearer
/// token, and the shop has to keep the card.
///
/// Vouchers remain because a shop with no Google account cannot use Play at
/// all, and because restoring a Play purchase needs a connection once — an odd
/// requirement in an app sold for working without one.
class BillingService {
  BillingService({BillingPlatform? platform, this.productId = kProProductId})
      : _platform = platform ?? PluginBillingPlatform();

  final BillingPlatform _platform;
  final String productId;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<BillingResult>? _pending;
  ProductDetails? _product;
  bool _started = false;

  /// Price as Play reports it, in the shopkeeper's own currency, or null if
  /// the product has not loaded.
  ///
  /// Play localises and converts; hardcoding "₹499" in the UI shows the wrong
  /// number to everyone outside India and goes stale the moment the price
  /// changes in the Console.
  String? get displayPrice => _product?.price;

  /// Connects and loads the product. Safe to call more than once.
  Future<bool> start() async {
    if (_started) return _product != null;
    _started = true;

    if (!await _platform.isAvailable()) return false;

    _subscription ??= _platform.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => _complete(
        BillingResult(BillingOutcome.failed, message: e.toString()),
      ),
    );

    final response = await _platform.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      // The id is wrong, inactive, or the build has never been uploaded to a
      // track. All three are ours to fix.
      return false;
    }
    _product = response.productDetails.first;
    return true;
  }

  /// Starts the purchase flow and waits for the store to settle it.
  Future<BillingResult> buyPro() async {
    if (!await start()) {
      return const BillingResult(
        BillingOutcome.unavailable,
        message: 'In-app purchase is not available on this device.',
      );
    }
    if (_pending != null) {
      return const BillingResult(
        BillingOutcome.failed,
        message: 'A purchase is already in progress.',
      );
    }

    final completer = Completer<BillingResult>();
    _pending = completer;

    try {
      final started = await _platform.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _product!),
      );
      if (!started) {
        _complete(const BillingResult(BillingOutcome.cancelled));
      }
    } catch (e) {
      _complete(BillingResult(BillingOutcome.failed, message: e.toString()));
    }

    return completer.future;
  }

  /// Asks Play what this account already owns.
  ///
  /// Play replays past purchases onto the same stream, so the answer arrives
  /// the same way a fresh purchase does. Nothing arriving means nothing is
  /// owned, which is why this waits briefly rather than hanging.
  Future<BillingResult> restore() async {
    if (!await start()) {
      return const BillingResult(
        BillingOutcome.unavailable,
        message: 'In-app purchase is not available on this device.',
      );
    }
    if (_pending != null) {
      return const BillingResult(
        BillingOutcome.failed,
        message: 'A purchase is already in progress.',
      );
    }

    final completer = Completer<BillingResult>();
    _pending = completer;

    try {
      await _platform.restorePurchases();
    } catch (e) {
      _complete(BillingResult(BillingOutcome.failed, message: e.toString()));
      return completer.future;
    }

    // A silent stream means "you own nothing", which Play never says
    // explicitly. Without a bound, the spinner would run forever.
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _pending = null;
        return const BillingResult(BillingOutcome.nothingToRestore);
      },
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Deliberately not completed and not unlocked. A UPI mandate can sit
          // here for hours; Play will send another event when it settles.
          _complete(const BillingResult(BillingOutcome.pending));

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Acknowledge within Play's window or the purchase is refunded
          // automatically — the shopkeeper pays, gets the unlock, then loses
          // both three days later.
          if (purchase.pendingCompletePurchase) {
            await _platform.completePurchase(purchase);
          }
          _complete(
            BillingResult(
              purchase.status == PurchaseStatus.restored
                  ? BillingOutcome.restored
                  : BillingOutcome.purchased,
              orderId: purchase.purchaseID,
            ),
          );

        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _platform.completePurchase(purchase);
          }
          _complete(const BillingResult(BillingOutcome.cancelled));

        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _platform.completePurchase(purchase);
          }
          _complete(
            BillingResult(
              BillingOutcome.failed,
              message: purchase.error?.message,
            ),
          );
      }
    }
  }

  void _complete(BillingResult result) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(result);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
