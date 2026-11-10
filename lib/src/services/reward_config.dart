import 'package:flutter/foundation.dart';

/// Centralized configuration for Rewarded Ads & Product Capacity Rewards.
///
/// Policy rules (Beta specification):
/// - Free base capacity: 50 active products
/// - Reward per completed ad: 2 additional product slots
/// - Reward validity: 7 days
/// - Daily reward limit: 5 completed ads
/// - Maximum daily additional capacity: 10 products
/// - Pro capacity: unlimited (preserves existing Pro entitlement)
/// - Reward type: Temporary, non-transferable capacity entitlement
class RewardConfig {
  RewardConfig._();

  /// Default base free product capacity.
  /// Can be overridden by SettingDao.freeLimitKey if configured.
  static const int defaultBaseFreeCapacity = 50;

  /// Number of product slots granted per successfully completed rewarded ad.
  static const int rewardSlotsPerAd = 2;

  /// Duration for which each rewarded slot remains valid.
  static const Duration rewardValidityDuration = Duration(days: 7);

  /// Maximum number of completed rewarded ads allowed per calendar day.
  static const int maxDailyAds = 5;

  /// Maximum bonus product capacity earnable in a single calendar day (5 * 2 = 10).
  static const int maxDailyBonusCapacity = maxDailyAds * rewardSlotsPerAd;

  /// Google AdMob Production Application ID for StockSafe.
  static const String productionAndroidAppId = 'ca-app-pub-8219488680857523~8581680010';

  /// Google AdMob Production Rewarded Ad Unit ID for StockSafe.
  static const String productionRewardedAdUnitId = 'ca-app-pub-8219488680857523/8764019559';

  /// Google AdMob official sample Test Application ID for Android.
  static const String testAndroidAppId = 'ca-app-pub-3940256099942544~3347511713';

  /// Google AdMob official sample Test Rewarded Ad Unit ID for Android.
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  /// Returns the configured Rewarded Ad Unit ID.
  /// Precedence:
  /// 1. `--dart-define=ADMOB_REWARDED_AD_UNIT_ID=...` if provided.
  /// 2. Production Rewarded Ad Unit ID.
  /// 3. In debug mode, if explicitly opting into test ads, [testRewardedAdUnitId].
  static String get rewardedAdUnitId {
    const fromEnv = String.fromEnvironment('ADMOB_REWARDED_AD_UNIT_ID');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return productionRewardedAdUnitId;
  }
}
