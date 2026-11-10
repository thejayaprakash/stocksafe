import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart' show kDebugMode;

import '../data/database.dart';
import '../data/dao/reward_dao.dart';
import 'billing_service.dart';
import 'license_key.dart';
import 'reward_config.dart';

/// Licensing, Free-Tier Limits, and Monetization Engine for StockSafe.
///
/// Rules:
/// 1. Free tier base allows 50 active products (configurable via [RewardConfig.defaultBaseFreeCapacity]).
/// 2. Voluntary rewarded ads grant +2 product capacity slots valid for 7 days (up to 5 ads/day = 10 slots).
/// 3. One-time payment (₹499 / $5.99) unlocks lifetime unlimited products.
/// 4. Never put a paywall in front of data already entered:
///    Viewing, search, stock movements, audit, CSV export, and backups
///    remain 100% free and functional forever.
class LicenseService {
  LicenseService(this._db, [RewardDao? rewardDao])
      : _rewardDao = rewardDao ?? RewardDao(_db);

  final AppDatabase _db;
  final RewardDao _rewardDao;

  /// Products a shop may hold before rewarded ads or one-time unlock is required.
  /// Centralized in [RewardConfig.defaultBaseFreeCapacity].
  static const int defaultFreeLimit = RewardConfig.defaultBaseFreeCapacity;

  static const String keyProUnlocked = 'is_pro_unlocked';
  static const String keyUnlockedAt = 'pro_unlocked_at';
  static const String keyUnlockMethod = 'pro_unlock_method';
  static const String keyLicenseCode = 'pro_license_code';

  RewardDao get rewardDao => _rewardDao;

  /// Whether the user has unlocked the lifetime unlimited version.
  Future<bool> isProUnlocked() async {
    final val = await _db.settingDao.get(keyProUnlocked);
    return val == 'true';
  }

  /// Get the base free product limit (default 50).
  Future<int> getFreeLimit() async {
    final val = await _db.settingDao.get(SettingDao.freeLimitKey);
    if (val != null) {
      final parsed = int.tryParse(val);
      if (parsed != null && parsed > 0) return parsed;
    }
    return defaultFreeLimit;
  }

  /// Total active verified reward slots currently valid.
  Future<int> getActiveRewardSlots({DateTime? asOf}) async {
    return _rewardDao.getActiveRewardSlots(asOf: asOf);
  }

  /// Effective product capacity = Base Free Capacity + Active Verified Reward Slots.
  /// Returns -1 if Pro is unlocked (unlimited).
  Future<int> getEffectiveCapacity({DateTime? asOf}) async {
    final unlocked = await isProUnlocked();
    if (unlocked) return -1;

    final base = await getFreeLimit();
    final bonus = await getActiveRewardSlots(asOf: asOf);
    return base + bonus;
  }

  /// Check if the user is allowed to add another product.
  /// Allowed if:
  /// - User has unlocked Pro, OR
  /// - Active product count is less than the effective capacity (base + active reward slots).
  Future<bool> canAddProduct() async {
    final unlocked = await isProUnlocked();
    if (unlocked) return true;

    final activeCount = await _db.productDao.countActive();
    final effectiveCapacity = await getEffectiveCapacity();
    return activeCount < effectiveCapacity;
  }

  /// Returns remaining products the user can add before hitting paywall.
  /// Returns -1 if Pro is unlocked (unlimited).
  Future<int> getRemainingFreeProducts() async {
    final unlocked = await isProUnlocked();
    if (unlocked) return -1;

    final activeCount = await _db.productDao.countActive();
    final effectiveCapacity = await getEffectiveCapacity();
    final remaining = effectiveCapacity - activeCount;
    return remaining > 0 ? remaining : 0;
  }

  /// Watch current licence status reactively.
  Stream<LicenseStatus> watchLicenseStatus() {
    return _db
        .customSelect(
          '''
          SELECT
            (SELECT value FROM setting WHERE key = ?1)          AS pro_flag,
            (SELECT value FROM setting WHERE key = ?2)          AS unlock_method,
            (SELECT value FROM setting WHERE key = ?3)          AS free_limit,
            (SELECT COUNT(*) FROM product WHERE deleted_at IS NULL)
                                                                AS active_count
          ''',
          variables: [
            Variable<String>(keyProUnlocked),
            Variable<String>(keyUnlockMethod),
            Variable<String>(SettingDao.freeLimitKey),
          ],
          readsFrom: {_db.settings, _db.products},
        )
        .watchSingle()
        .asyncMap((row) async {
      final configured = int.tryParse(row.read<String?>('free_limit') ?? '');
      final rewardSlots = await getActiveRewardSlots();

      return LicenseStatus(
        isPro: row.read<String?>('pro_flag') == 'true',
        activeProductCount: row.read<int>('active_count'),
        freeLimit: (configured != null && configured > 0)
            ? configured
            : defaultFreeLimit,
        rewardSlots: rewardSlots,
        unlockMethod: row.read<String?>('unlock_method'),
      );
    });
  }

  /// One-time unlock via Play Billing or In-App Purchase.
  Future<void> unlockLifetime({String method = 'play_billing', String? code}) async {
    final now = DateTime.now().toIso8601String();
    await _db.settingDao.set(keyProUnlocked, 'true');
    await _db.settingDao.set(keyUnlockedAt, now);
    await _db.settingDao.set(keyUnlockMethod, method);
    if (code != null) {
      await _db.settingDao.set(keyLicenseCode, code);
    }
  }

  /// Restore a previous purchase.
  Future<bool> restorePurchases() async {
    return isProUnlocked();
  }

  /// Buys the lifetime unlock through Google Play.
  Future<BillingResult> purchasePro(BillingService billing) async {
    final result = await billing.buyPro();
    if (result.grantsUnlock) {
      await unlockLifetime(method: 'play_billing', code: result.orderId);
    }
    return result;
  }

  /// Asks Play what this Google account already owns.
  Future<BillingResult> restoreFromPlay(BillingService billing) async {
    if (await isProUnlocked()) {
      return const BillingResult(BillingOutcome.restored);
    }
    final result = await billing.restore();
    if (result.grantsUnlock) {
      await unlockLifetime(method: 'play_restore', code: result.orderId);
    }
    return result;
  }

  /// Validates and activates an offline voucher or license key.
  Future<bool> validateAndActivateOfflineKey(String key) async {
    if (LicenseKey.isValid(key)) {
      await unlockLifetime(
        method: 'offline_voucher',
        code: LicenseKey.serialOf(key),
      );
      return true;
    }

    if (kDebugMode && LicenseKey.normalise(key) == 'DEBUGUNLOCK') {
      await unlockLifetime(method: 'debug_code', code: 'DEBUGUNLOCK');
      return true;
    }

    return false;
  }

  /// Reset license back to free tier (used for testing paywall flow).
  Future<void> resetForTesting() async {
    await _db.settingDao.set(keyProUnlocked, 'false');
    await _db.settingDao.set(keyUnlockMethod, '');
    await _db.settingDao.set(keyLicenseCode, '');
    await _rewardDao.clearAll();
  }

  /// Drops the entitlement, leaving inventory untouched.
  /// Also clears local reward entitlements on restore to prevent transfer.
  Future<void> clearEntitlement() async {
    await _db.settingDao.set(keyProUnlocked, 'false');
    await _db.settingDao.set(keyUnlockedAt, '');
    await _db.settingDao.set(keyUnlockMethod, '');
    await _db.settingDao.set(keyLicenseCode, '');
    await _rewardDao.clearAll();
  }
}

/// Snapshot of current license and usage state.
class LicenseStatus {
  const LicenseStatus({
    required this.isPro,
    required this.activeProductCount,
    required this.freeLimit,
    this.rewardSlots = 0,
    this.unlockMethod,
  });

  final bool isPro;
  final int activeProductCount;
  final int freeLimit;
  final int rewardSlots;
  final String? unlockMethod;

  int get effectiveCapacity => isPro ? -1 : freeLimit + rewardSlots;
  int get remaining => isPro
      ? -1
      : (effectiveCapacity - activeProductCount).clamp(0, effectiveCapacity);
  bool get isAtLimit => !isPro && activeProductCount >= effectiveCapacity;
  double get usageFraction => isPro
      ? 0.0
      : (effectiveCapacity > 0
          ? (activeProductCount / effectiveCapacity).clamp(0.0, 1.0)
          : 1.0);
}
