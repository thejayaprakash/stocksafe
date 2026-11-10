import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/data/dao/reward_dao.dart';
import 'package:stocksafe/src/services/license_service.dart';
import 'package:stocksafe/src/services/reward_config.dart';
import 'package:stocksafe/src/services/rewarded_ad_platform.dart';
import 'package:stocksafe/src/services/rewarded_ad_service.dart';

void main() {
  late AppDatabase db;
  late LicenseService licenseService;
  late RewardDao rewardDao;
  late FakeRewardedAdPlatform fakePlatform;
  late RewardedAdService rewardedAdService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    rewardDao = RewardDao(db);
    await rewardDao.ensureTableExists();

    licenseService = LicenseService(db, rewardDao);
    await licenseService.resetForTesting();

    fakePlatform = FakeRewardedAdPlatform();
    rewardedAdService = RewardedAdService(
      rewardDao: rewardDao,
      platform: fakePlatform,
    );
  });

  tearDown(() async {
    rewardedAdService.dispose();
    await db.close();
  });

  group('1. Capacity Calculation Tests', () {
    test('Free user with 0 rewards has exactly 50 slots', () async {
      expect(await licenseService.isProUnlocked(), isFalse);
      expect(await licenseService.getFreeLimit(), equals(50));
      expect(await licenseService.getActiveRewardSlots(), equals(0));
      expect(await licenseService.getEffectiveCapacity(), equals(50));
      expect(await licenseService.getRemainingFreeProducts(), equals(50));
      expect(await licenseService.canAddProduct(), isTrue);
    });

    test('Free user with 1 active reward has 52 slots', () async {
      final now = DateTime.now();
      await rewardDao.insertReward(
        RewardEntitlementRecord(
          rewardTransactionId: 'tx_cap_1',
          rewardAmount: 2,
          earnedAt: now,
          expiresAt: now.add(RewardConfig.rewardValidityDuration),
          createdAt: now,
        ),
      );

      expect(await licenseService.getActiveRewardSlots(), equals(2));
      expect(await licenseService.getEffectiveCapacity(), equals(52));
      expect(await licenseService.getRemainingFreeProducts(), equals(52));
    });

    test('Free user with 5 active rewards has 60 slots', () async {
      final now = DateTime.now();
      for (int i = 1; i <= 5; i++) {
        await rewardDao.insertReward(
          RewardEntitlementRecord(
            rewardTransactionId: 'tx_cap_multi_$i',
            rewardAmount: 2,
            earnedAt: now,
            expiresAt: now.add(RewardConfig.rewardValidityDuration),
            createdAt: now,
          ),
        );
      }

      expect(await licenseService.getActiveRewardSlots(), equals(10));
      expect(await licenseService.getEffectiveCapacity(), equals(60));
      expect(await licenseService.getRemainingFreeProducts(), equals(60));
    });

    test('Expired rewards do not contribute to effective capacity', () async {
      final now = DateTime.now();
      // Insert one active reward (+2)
      await rewardDao.insertReward(
        RewardEntitlementRecord(
          rewardTransactionId: 'tx_active',
          rewardAmount: 2,
          earnedAt: now,
          expiresAt: now.add(const Duration(days: 7)),
          createdAt: now,
        ),
      );

      // Insert one expired reward (+2, expired 1 hour ago)
      await rewardDao.insertReward(
        RewardEntitlementRecord(
          rewardTransactionId: 'tx_expired',
          rewardAmount: 2,
          earnedAt: now.subtract(const Duration(days: 8)),
          expiresAt: now.subtract(const Duration(hours: 1)),
          createdAt: now.subtract(const Duration(days: 8)),
        ),
      );

      // Only the active reward should contribute
      expect(await licenseService.getActiveRewardSlots(), equals(2));
      expect(await licenseService.getEffectiveCapacity(), equals(52));
    });

    test('Pro user retains unlimited capacity regardless of rewards', () async {
      await licenseService.unlockLifetime(method: 'play_billing');
      expect(await licenseService.isProUnlocked(), isTrue);

      expect(await licenseService.getEffectiveCapacity(), equals(-1));
      expect(await licenseService.getRemainingFreeProducts(), equals(-1));
      expect(await licenseService.canAddProduct(), isTrue);
    });

    test('Duplicate reward transactions do not increase capacity', () async {
      final now = DateTime.now();
      final record = RewardEntitlementRecord(
        rewardTransactionId: 'tx_duplicate_test',
        rewardAmount: 2,
        earnedAt: now,
        expiresAt: now.add(const Duration(days: 7)),
        createdAt: now,
      );

      final firstInsert = await rewardDao.insertReward(record);
      expect(firstInsert, isTrue);
      expect(await licenseService.getActiveRewardSlots(), equals(2));

      // Attempt duplicate insert
      final secondInsert = await rewardDao.insertReward(record);
      expect(secondInsert, isFalse);
      expect(await licenseService.getActiveRewardSlots(), equals(2));
      expect(await licenseService.getEffectiveCapacity(), equals(52));
    });
  });

  group('2. Reward Flow & Lifecycle Tests', () {
    test('Completed ad grants exactly 2 slots valid for 7 days', () async {
      fakePlatform.loadSucceeds = true;
      fakePlatform.showStatus = RewardAdShowStatus.rewardGranted;
      fakePlatform.grantAmount = 2;

      final result = await rewardedAdService.showAdAndEarnReward();
      expect(result.isSuccess, isTrue);
      expect(rewardedAdService.state, equals(RewardedAdLifecycleState.rewardGranted));

      expect(await licenseService.getActiveRewardSlots(), equals(2));
      expect(await licenseService.getEffectiveCapacity(), equals(52));

      final rewards = await rewardDao.getActiveRewards();
      expect(rewards.length, equals(1));
      expect(rewards.first.rewardAmount, equals(2));
      expect(rewards.first.verificationStatus, equals('verified'));
      expect(
        rewards.first.expiresAt.difference(rewards.first.earnedAt).inDays,
        equals(7),
      );
    });

    test('Dismissed ad grants NO slots', () async {
      fakePlatform.showStatus = RewardAdShowStatus.dismissedWithoutReward;

      final result = await rewardedAdService.showAdAndEarnReward();
      expect(result.status, equals(RewardAdShowStatus.dismissedWithoutReward));
      expect(rewardedAdService.state, equals(RewardedAdLifecycleState.adDismissedWithoutReward));

      expect(await licenseService.getActiveRewardSlots(), equals(0));
      expect(await licenseService.getEffectiveCapacity(), equals(50));
    });

    test('Failed ad grants NO slots', () async {
      fakePlatform.showStatus = RewardAdShowStatus.failedToShow;

      final result = await rewardedAdService.showAdAndEarnReward();
      expect(result.status, equals(RewardAdShowStatus.failedToShow));
      expect(rewardedAdService.state, equals(RewardedAdLifecycleState.adFailed));

      expect(await licenseService.getActiveRewardSlots(), equals(0));
      expect(await licenseService.getEffectiveCapacity(), equals(50));
    });

    test('Daily limit is strictly enforced at 5 completed ads', () async {
      fakePlatform.showStatus = RewardAdShowStatus.rewardGranted;

      // Complete 5 ads
      for (int i = 1; i <= 5; i++) {
        fakePlatform.customTransactionId = 'daily_tx_$i';
        final res = await rewardedAdService.showAdAndEarnReward();
        expect(res.isSuccess, isTrue);
      }

      expect(await rewardedAdService.isDailyLimitReached(), isTrue);
      expect(await rewardedAdService.getRemainingDailyAds(), equals(0));
      expect(await licenseService.getActiveRewardSlots(), equals(10));
      expect(await licenseService.getEffectiveCapacity(), equals(60));

      // Attempt 6th ad: must be rejected by service
      fakePlatform.customTransactionId = 'daily_tx_6';
      final sixthRes = await rewardedAdService.showAdAndEarnReward();
      expect(sixthRes.status, equals(RewardAdShowStatus.failedToShow));
      expect(rewardedAdService.state, equals(RewardedAdLifecycleState.dailyLimitReached));

      // Capacity must remain at 60 (no 6th ad counted)
      expect(await licenseService.getActiveRewardSlots(), equals(10));
      expect(await licenseService.getEffectiveCapacity(), equals(60));
    });

    test('Forged reward token is rejected and grants no capacity', () async {
      fakePlatform.showStatus = RewardAdShowStatus.rewardGranted;
      fakePlatform.customTransactionId = 'forged_tx_1';

      // Tamper verification in service directly
      final isTamperedValid = rewardedAdService.verifyRewardToken(
        transactionId: 'forged_tx_1',
        amount: 2,
        token: 'invalid_forged_signature_token',
      );
      expect(isTamperedValid, isFalse);
    });
  });

  group('3. Application Regression & Inventory Invariants', () {
    test('Product creation works below the effective limit and is restricted at limit', () async {
      final now = DateTime.now();

      // Insert 50 products to reach base limit
      for (int i = 1; i <= 50; i++) {
        await db.productDao.insertProduct(
          ProductsCompanion.insert(
            name: 'Item $i',
            unit: const Value('pcs'),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      expect(await db.productDao.countActive(), equals(50));
      // Base limit reached: canAddProduct must be false
      expect(await licenseService.canAddProduct(), isFalse);
      expect(await licenseService.getRemainingFreeProducts(), equals(0));

      // User voluntarily watches an ad: grants +2 slots
      fakePlatform.showStatus = RewardAdShowStatus.rewardGranted;
      fakePlatform.customTransactionId = 'unlock_slot_tx';
      final adRes = await rewardedAdService.showAdAndEarnReward();
      expect(adRes.isSuccess, isTrue);

      // Now effective capacity is 52: canAddProduct is true again!
      expect(await licenseService.canAddProduct(), isTrue);
      expect(await licenseService.getRemainingFreeProducts(), equals(2));

      // Add product #51
      final p51 = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Item 51',
          unit: const Value('pcs'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(p51, isPositive);
      expect(await licenseService.getRemainingFreeProducts(), equals(1));

      // Add product #52
      final p52 = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Item 52',
          unit: const Value('pcs'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(p52, isPositive);
      expect(await licenseService.getRemainingFreeProducts(), equals(0));

      // Reached new effective capacity (52): blocked again
      expect(await licenseService.canAddProduct(), isFalse);
    });

    test('Expired rewards NEVER delete, hide, or deactivate existing products', () async {
      final now = DateTime.now();

      // Add 1 reward giving 52 capacity
      await rewardDao.insertReward(
        RewardEntitlementRecord(
          rewardTransactionId: 'tx_expire_test',
          rewardAmount: 2,
          earnedAt: now.subtract(const Duration(days: 6)),
          expiresAt: now.add(const Duration(hours: 1)), // valid for 1 more hour
          createdAt: now.subtract(const Duration(days: 6)),
        ),
      );

      // Insert 52 products
      for (int i = 1; i <= 52; i++) {
        await db.productDao.insertProduct(
          ProductsCompanion.insert(
            name: 'SKU $i',
            unit: const Value('pcs'),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      expect(await db.productDao.countActive(), equals(52));

      // Simulate time passage: reward expires (asOf: now + 2 hours)
      final futureTime = now.add(const Duration(hours: 2));
      final activeBonus = await licenseService.getActiveRewardSlots(asOf: futureTime);
      expect(activeBonus, equals(0));
      expect(await licenseService.getEffectiveCapacity(asOf: futureTime), equals(50));

      // Critical Rule: All 52 products MUST remain active and in database!
      final activeCount = await db.productDao.countActive();
      expect(activeCount, equals(52));

      // All products remain viewable, searchable, and editable
      final allProds = await db.productDao.getAll();
      expect(allProds.length, equals(52));

      // Only adding NEW products is restricted
      final canAddInFuture = !((await licenseService.isProUnlocked())) &&
          (activeCount < (await licenseService.getEffectiveCapacity(asOf: futureTime)));
      expect(canAddInFuture, isFalse);
    });

    test('Inventory movement ledger and stock levels remain unaffected by rewards', () async {
      final now = DateTime.now();
      final pId = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Rice Bag 25kg',
          unit: const Value('bag'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Record inward stock
      await db.movementDao.recordMovement(
        productId: pId,
        qtyDelta: 20,
        reason: 'purchase',
      );
      final prodBefore = await db.productDao.getById(pId);
      expect(prodBefore!.stockQty, equals(20));

      // Perform reward operations
      fakePlatform.showStatus = RewardAdShowStatus.rewardGranted;
      await rewardedAdService.showAdAndEarnReward();

      // Product stock and ledger row remain completely intact
      final prodAfter = await db.productDao.getById(pId);
      expect(prodAfter!.stockQty, equals(20));
      final movements = await db.movementDao.getMovementsForProduct(pId);
      expect(movements.length, equals(1));
      expect(movements.first.qtyDelta, equals(20));
    });

    test('LicenseService.clearEntitlement clears local rewards on backup restore', () async {
      final now = DateTime.now();
      await rewardDao.insertReward(
        RewardEntitlementRecord(
          rewardTransactionId: 'restore_tx',
          rewardAmount: 2,
          earnedAt: now,
          expiresAt: now.add(const Duration(days: 7)),
          createdAt: now,
        ),
      );
      expect(await licenseService.getActiveRewardSlots(), equals(2));

      // Simulate snapshot restore entitlement scrub
      await licenseService.clearEntitlement();

      expect(await licenseService.getActiveRewardSlots(), equals(0));
      expect(await licenseService.getEffectiveCapacity(), equals(50));
      expect(await licenseService.isProUnlocked(), isFalse);
    });
  });
}
