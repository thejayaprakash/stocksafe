import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart' show kDebugMode;

import '../data/database.dart';
import 'license_key.dart';

/// Licensing, Free-Tier Limits, and Monetization Engine for StockSafe.
///
/// Rules (from dev plan):
/// 1. Free tier allows up to 100 active products.
/// 2. One-time payment (₹499 / $5.99) unlocks lifetime unlimited products.
/// 3. Never put a paywall in front of data already entered:
///    Viewing, search, stock movements, audit, CSV export, and backups
///    remain 100% free and functional forever.
class LicenseService {
  LicenseService(this._db);

  final AppDatabase _db;

  /// Products a shop may hold before the one-time unlock is required.
  ///
  /// Raised from 50 to 100. A kirana carrying 100-300 SKUs hit the old ceiling
  /// partway through its first stocktake — before it had entered enough of its
  /// catalogue to see whether the app was worth paying for. A paywall that
  /// lands mid-onboarding is measuring patience, not value.
  ///
  /// This is the default. SettingDao.freeLimitKey overrides it, so a changed
  /// limit reaches existing installs without an app update.
  static const int defaultFreeLimit = 100;

  static const String keyProUnlocked = 'is_pro_unlocked';
  static const String keyUnlockedAt = 'pro_unlocked_at';
  static const String keyUnlockMethod = 'pro_unlock_method';
  static const String keyLicenseCode = 'pro_license_code';

  /// Whether the user has unlocked the lifetime unlimited version.
  Future<bool> isProUnlocked() async {
    final val = await _db.settingDao.get(keyProUnlocked);
    return val == 'true';
  }

  /// Get the current free product limit (default 50).
  Future<int> getFreeLimit() async {
    final val = await _db.settingDao.get(SettingDao.freeLimitKey);
    if (val != null) {
      final parsed = int.tryParse(val);
      if (parsed != null && parsed > 0) return parsed;
    }
    return defaultFreeLimit;
  }

  /// Check if the user is allowed to add another product.
  /// Allowed if:
  /// - User has unlocked Pro, OR
  /// - Active product count is less than the free limit.
  Future<bool> canAddProduct() async {
    final unlocked = await isProUnlocked();
    if (unlocked) return true;

    final activeCount = await _db.productDao.countActive();
    final limit = await getFreeLimit();
    return activeCount < limit;
  }

  /// Returns remaining products the user can add before hitting paywall.
  /// Returns -1 if Pro is unlocked (unlimited).
  Future<int> getRemainingFreeProducts() async {
    final unlocked = await isProUnlocked();
    if (unlocked) return -1;

    final activeCount = await _db.productDao.countActive();
    final limit = await getFreeLimit();
    final remaining = limit - activeCount;
    return remaining > 0 ? remaining : 0;
  }

  /// Watch current licence status reactively.
  ///
  /// Driven by the database rather than a timer. This was a `while (true)`
  /// loop running three queries every second, forever, with no cancellation —
  /// battery and CPU spent re-reading values that change a handful of times
  /// in the life of an install.
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
        .map((row) {
      final configured = int.tryParse(row.read<String?>('free_limit') ?? '');
      return LicenseStatus(
        isPro: row.read<String?>('pro_flag') == 'true',
        activeProductCount: row.read<int>('active_count'),
        freeLimit:
            (configured != null && configured > 0) ? configured : defaultFreeLimit,
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
  ///
  /// Returns true only when this device already holds an unlock. It used to
  /// call unlockLifetime() unconditionally, so tapping "Restore Purchases" on
  /// a fresh install granted Pro to anyone — and Play *requires* that button
  /// to exist, so the bypass was one tap away for every user.
  ///
  /// Until Play Billing is integrated (roadmap E.1) there is no receipt to
  /// query, so an honest answer is "nothing to restore" rather than a
  /// simulated success.
  Future<bool> restorePurchases() async {
    return isProUnlocked();
  }

  /// Validates and activates an offline voucher or license key.
  /// Allows Kirana stores with no Google Play account or in offline environments
  /// to unlock the app with a valid 16-character alphanumeric key.
  Future<bool> validateAndActivateOfflineKey(String key) async {
    // Signature-checked. The previous version accepted any string beginning
    // STOCKSAFE with twelve or more characters, plus three hardcoded codes
    // that are readable in the APK because R8 is disabled.
    if (LicenseKey.isValid(key)) {
      await unlockLifetime(
        method: 'offline_voucher',
        code: LicenseKey.serialOf(key),
      );
      return true;
    }

    // Debug builds keep a fixed code so the paywall can be exercised without
    // minting a voucher. kDebugMode is compiled out of release entirely, so
    // this cannot be reached by a shipped build.
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
  }

  /// Drops the entitlement, leaving inventory untouched.
  ///
  /// Called after a restore or an import, because the unlock is four rows in
  /// `setting` — and `setting` lives inside `stocksafe.sqlite`, which
  /// `BackupArchiveService` copies into the zip verbatim and which restore
  /// swaps in wholesale.
  ///
  /// Without this, a backup taken while Pro was active grants Pro to whoever
  /// restores it. One customer's zip forwarded on WhatsApp unlocks the app for
  /// everyone who imports it — and hands over that shop's catalogue with it.
  /// Nothing in the file is bound to a device or an account, so there is no
  /// way to tell the owner's own restore from a stranger's.
  ///
  /// The owner is not locked out. Their voucher still activates, and a Play
  /// purchase restores from the store. Entitlement comes from Play or from a
  /// voucher, never from a file someone was sent.
  Future<void> clearEntitlement() async {
    await _db.settingDao.set(keyProUnlocked, 'false');
    await _db.settingDao.set(keyUnlockedAt, '');
    await _db.settingDao.set(keyUnlockMethod, '');
    await _db.settingDao.set(keyLicenseCode, '');
  }
}

/// Snapshot of current license and usage state.
class LicenseStatus {
  const LicenseStatus({
    required this.isPro,
    required this.activeProductCount,
    required this.freeLimit,
    this.unlockMethod,
  });

  final bool isPro;
  final int activeProductCount;
  final int freeLimit;
  final String? unlockMethod;

  int get remaining => isPro ? -1 : (freeLimit - activeProductCount).clamp(0, freeLimit);
  bool get isAtLimit => !isPro && activeProductCount >= freeLimit;
  double get usageFraction => isPro ? 0.0 : (activeProductCount / freeLimit).clamp(0.0, 1.0);
}
