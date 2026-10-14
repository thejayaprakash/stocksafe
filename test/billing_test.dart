// Google Play Billing, driven through a fake platform.
//
// Billing is the one path where a bug costs money in both directions: unlock
// without payment and the app is free, refuse a completed payment and the
// shopkeeper has paid for nothing. Neither is findable by hand without a Play
// Console, a signed build and a real card — so the plugin sits behind
// BillingPlatform and the states are driven directly.
//
// The case that matters most here is `pending`. In India a large share of
// purchases settle through UPI or net-banking, which are asynchronous: Play
// reports the purchase as pending and sends another event when the money
// actually moves, sometimes hours later.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/billing_service.dart';
import 'package:stocksafe/src/services/license_service.dart';

class _FakePlatform implements BillingPlatform {
  _FakePlatform({
    this.available = true,
    this.hasProduct = true,
    this.buyThrows = false,
    this.buyReturnsFalse = false,
  });

  final bool available;
  final bool hasProduct;
  final bool buyThrows;
  final bool buyReturnsFalse;

  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <String>[];
  int restoreCalls = 0;
  int buyCalls = 0;

  /// What Play would push onto the stream in response to a buy or a restore.
  List<PurchaseDetails> Function()? onBuy;
  List<PurchaseDetails> Function()? onRestore;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    return ProductDetailsResponse(
      productDetails: hasProduct
          ? [
              ProductDetails(
                id: ids.first,
                title: 'StockSafe Pro',
                description: 'Lifetime unlock',
                price: '₹499.00',
                rawPrice: 499,
                currencyCode: 'INR',
              ),
            ]
          : const [],
      notFoundIDs: hasProduct ? const [] : ids.toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls++;
    if (buyThrows) throw StateError('billing unavailable');
    if (buyReturnsFalse) return false;
    final emit = onBuy;
    if (emit != null) {
      scheduleMicrotask(() => _controller.add(emit()));
    }
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
    final emit = onRestore;
    if (emit != null) {
      scheduleMicrotask(() => _controller.add(emit()));
    }
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.purchaseID ?? 'unknown');
  }

  Future<void> close() => _controller.close();
}

PurchaseDetails _purchase(
  PurchaseStatus status, {
  String id = 'GPA.1234-5678',
  String product = kProProductId,
  bool needsCompletion = true,
  IAPError? error,
}) {
  return PurchaseDetails(
    purchaseID: id,
    productID: product,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'google_play',
    ),
    transactionDate: null,
    status: status,
  )
    ..pendingCompletePurchase = needsCompletion
    ..error = error;
}

void main() {
  late AppDatabase db;
  late LicenseService licence;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    licence = LicenseService(db);
  });

  tearDown(() async => db.close());

  group('buying', () {
    test('a completed purchase unlocks and records the order id', () async {
      final platform = _FakePlatform()
        ..onBuy = () => [_purchase(PurchaseStatus.purchased)];
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      final result = await licence.purchasePro(billing);

      expect(result.outcome, BillingOutcome.purchased);
      expect(await licence.isProUnlocked(), isTrue);
      expect(
        await db.settingDao.get(LicenseService.keyLicenseCode),
        'GPA.1234-5678',
      );
      expect(
        await db.settingDao.get(LicenseService.keyUnlockMethod),
        'play_billing',
      );
    });

    test('a completed purchase is acknowledged', () async {
      // Play refunds automatically if a purchase is not acknowledged within
      // its window — the shopkeeper pays, gets the unlock, then loses both.
      final platform = _FakePlatform()
        ..onBuy = () => [_purchase(PurchaseStatus.purchased)];
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      await licence.purchasePro(billing);

      expect(platform.completed, ['GPA.1234-5678']);
    });

    test('a PENDING purchase does not unlock', () async {
      // The UPI case. Money has not moved; unlocking here hands the app to
      // anyone who starts a payment and abandons it.
      final platform = _FakePlatform()
        ..onBuy = () => [_purchase(PurchaseStatus.pending)];
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      final result = await licence.purchasePro(billing);

      expect(result.outcome, BillingOutcome.pending);
      expect(result.grantsUnlock, isFalse);
      expect(await licence.isProUnlocked(), isFalse);
    });

    test('a pending purchase is not acknowledged', () async {
      // Acknowledging an unsettled purchase tells Play it was delivered.
      final platform = _FakePlatform()
        ..onBuy = () => [_purchase(PurchaseStatus.pending)];
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      await licence.purchasePro(billing);

      expect(platform.completed, isEmpty);
    });

    test('a pending purchase that later settles unlocks', () async {
      // Play sends a second event when the money arrives. This is the shape
      // of a successful UPI payment.
      final platform = _FakePlatform()
        ..onBuy = () => [_purchase(PurchaseStatus.pending)];
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      expect(
        (await licence.purchasePro(billing)).outcome,
        BillingOutcome.pending,
      );
      expect(await licence.isProUnlocked(), isFalse);

      platform.onBuy = () => [_purchase(PurchaseStatus.purchased)];
      final second = await licence.purchasePro(billing);

      expect(second.outcome, BillingOutcome.purchased);
      expect(await licence.isProUnlocked(), isTrue);
    });

    test('cancelling leaves the app on the free tier', () async {
      final platform = _FakePlatform()
        ..onBuy = () => [_purchase(PurchaseStatus.canceled)];
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      final result = await licence.purchasePro(billing);

      expect(result.outcome, BillingOutcome.cancelled);
      expect(await licence.isProUnlocked(), isFalse);
    });

    test('a store error does not unlock', () async {
      final platform = _FakePlatform()
        ..onBuy = () => [
              _purchase(
                PurchaseStatus.error,
                error: IAPError(
                  source: 'google_play',
                  code: 'BILLING_UNAVAILABLE',
                  message: 'Billing unavailable',
                ),
              ),
            ];
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      final result = await licence.purchasePro(billing);

      expect(result.outcome, BillingOutcome.failed);
      expect(result.message, 'Billing unavailable');
      expect(await licence.isProUnlocked(), isFalse);
    });

    test('a flow that never launches is treated as cancelled', () async {
      // buyNonConsumable returns false when Play declines to show the sheet.
      // No event ever arrives, so without this the future would never settle
      // and the spinner would run forever.
      final platform = _FakePlatform(buyReturnsFalse: true);
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      final result = await licence.purchasePro(billing);

      expect(result.outcome, BillingOutcome.cancelled);
      expect(await licence.isProUnlocked(), isFalse);
    });

    test('a throwing platform call is reported, not swallowed', () async {
      final platform = _FakePlatform(buyThrows: true);
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      final result = await licence.purchasePro(billing);

      expect(result.outcome, BillingOutcome.failed);
      expect(result.message, contains('billing unavailable'));
      expect(await licence.isProUnlocked(), isFalse);
    });

    test('an event for another product is ignored', () async {
      final platform = _FakePlatform()
        ..onBuy = () => [
              _purchase(PurchaseStatus.purchased, product: 'something_else'),
              _purchase(PurchaseStatus.canceled),
            ];
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      final result = await licence.purchasePro(billing);

      expect(result.outcome, BillingOutcome.cancelled);
      expect(await licence.isProUnlocked(), isFalse);
    });
  });

  group('availability', () {
    test('no Play Services means unavailable, not failed', () async {
      final platform = _FakePlatform(available: false);
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      final result = await licence.purchasePro(billing);

      expect(result.outcome, BillingOutcome.unavailable);
      expect(await licence.isProUnlocked(), isFalse);
    });

    test('a missing product id means unavailable', () async {
      // The id is wrong, inactive, or the build was never uploaded to a track.
      final platform = _FakePlatform(hasProduct: false);
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      expect(
        (await licence.purchasePro(billing)).outcome,
        BillingOutcome.unavailable,
      );
    });

    test('the price comes from Play, not from a hardcoded string', () async {
      // Play localises and converts. A literal in the UI is wrong everywhere
      // but India and stale the moment the Console price changes.
      final platform = _FakePlatform();
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      await billing.start();

      expect(billing.displayPrice, '₹499.00');
    });
  });

  group('restoring', () {
    test('an owned purchase unlocks on a fresh install', () async {
      // The answer to "I reinstalled, do I pay again?"
      final platform = _FakePlatform()
        ..onRestore = () => [_purchase(PurchaseStatus.restored)];
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      expect(await licence.isProUnlocked(), isFalse);

      final result = await licence.restoreFromPlay(billing);

      expect(result.outcome, BillingOutcome.restored);
      expect(await licence.isProUnlocked(), isTrue);
      expect(
        await db.settingDao.get(LicenseService.keyUnlockMethod),
        'play_restore',
      );
    });

    test('an account that owns nothing does not unlock', () async {
      // Play says nothing at all in this case, so the service waits and then
      // answers rather than spinning forever.
      final platform = _FakePlatform();
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      final result = await licence.restoreFromPlay(billing);

      expect(result.outcome, BillingOutcome.nothingToRestore);
      expect(await licence.isProUnlocked(), isFalse);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('a device that already holds Pro does not ask the store', () async {
      await licence.unlockLifetime(method: 'voucher', code: 'SERIAL-1');
      final platform = _FakePlatform();
      addTearDown(platform.close);
      final billing = BillingService(platform: platform);
      addTearDown(billing.dispose);

      final result = await licence.restoreFromPlay(billing);

      expect(result.grantsUnlock, isTrue);
      expect(platform.restoreCalls, 0);
    });
  });
}
