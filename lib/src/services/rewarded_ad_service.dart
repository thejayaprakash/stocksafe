import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../data/dao/reward_dao.dart';
import 'reward_config.dart';
import 'rewarded_ad_platform.dart';
import 'plugin_rewarded_ad_platform.dart';

/// Lifecycle and presentation states for rewarded ads.
enum RewardedAdLifecycleState {
  adNotLoaded,
  loadingAd,
  adReady,
  adPlaying,
  adCompleted,
  verificationPending,
  rewardGranted,
  adDismissedWithoutReward,
  adFailed,
  dailyLimitReached,
  duplicateTransaction,
  verificationFailed,
  offlineUnavailable,
}

/// Comprehensive status of the rewarded ad service.
class RewardedAdStatus {
  const RewardedAdStatus({
    required this.lifecycleState,
    required this.dailyAdsCompleted,
    required this.dailyAdsRemaining,
    required this.activeBonusSlots,
    this.message,
    this.latestTransactionId,
  });

  final RewardedAdLifecycleState lifecycleState;
  final int dailyAdsCompleted;
  final int dailyAdsRemaining;
  final int activeBonusSlots;
  final String? message;
  final String? latestTransactionId;

  bool get canWatch =>
      dailyAdsRemaining > 0 &&
      lifecycleState != RewardedAdLifecycleState.loadingAd &&
      lifecycleState != RewardedAdLifecycleState.adPlaying;
}

/// Orchestrates rewarded advertisements, daily frequency capping,
/// cryptographic / SSV verification, and entitlement persistence.
class RewardedAdService {
  RewardedAdService({
    required RewardDao rewardDao,
    RewardedAdPlatform? platform,
    String? adUnitId,
  })  : _rewardDao = rewardDao,
        _platform = platform ?? PluginRewardedAdPlatform(),
        _adUnitId = adUnitId ?? RewardConfig.rewardedAdUnitId;

  final RewardDao _rewardDao;
  final RewardedAdPlatform _platform;
  final String _adUnitId;

  RewardedAdLifecycleState _state = RewardedAdLifecycleState.adNotLoaded;
  RewardedAdLifecycleState get state => _state;

  final _stateController = StreamController<RewardedAdStatus>.broadcast();
  Stream<RewardedAdStatus> get statusStream => _stateController.stream;

  /// Secret key used for local SSV / callback signature validation.
  static const String _ssvSecret = 'stocksafe-reward-verification-key-v1';

  /// Returns whether the daily cap (5 completed ads) has been reached.
  Future<bool> isDailyLimitReached({DateTime? forDate}) async {
    final count = await _rewardDao.getDailyCompletedCount(forDate: forDate);
    return count >= RewardConfig.maxDailyAds;
  }

  /// Returns how many ads can still be completed today.
  Future<int> getRemainingDailyAds({DateTime? forDate}) async {
    final count = await _rewardDao.getDailyCompletedCount(forDate: forDate);
    final remaining = RewardConfig.maxDailyAds - count;
    return remaining < 0 ? 0 : remaining;
  }

  /// Gets the current status snapshot.
  Future<RewardedAdStatus> getStatus() async {
    final completed = await _rewardDao.getDailyCompletedCount();
    final remaining = (RewardConfig.maxDailyAds - completed).clamp(0, RewardConfig.maxDailyAds);
    final activeSlots = await _rewardDao.getActiveRewardSlots();

    if (remaining <= 0 && _state != RewardedAdLifecycleState.rewardGranted) {
      _state = RewardedAdLifecycleState.dailyLimitReached;
    }

    return RewardedAdStatus(
      lifecycleState: _state,
      dailyAdsCompleted: completed,
      dailyAdsRemaining: remaining,
      activeBonusSlots: activeSlots,
    );
  }

  void _notify(RewardedAdLifecycleState newState, {String? message, String? txId}) async {
    _state = newState;
    final status = await getStatus();
    _stateController.add(
      RewardedAdStatus(
        lifecycleState: newState,
        dailyAdsCompleted: status.dailyAdsCompleted,
        dailyAdsRemaining: status.dailyAdsRemaining,
        activeBonusSlots: status.activeBonusSlots,
        message: message,
        latestTransactionId: txId,
      ),
    );
  }

  /// Loads an advertisement if not already loaded, provided daily cap is not exceeded.
  Future<bool> preloadAd() async {
    if (await isDailyLimitReached()) {
      _notify(RewardedAdLifecycleState.dailyLimitReached, message: 'Daily limit reached');
      return false;
    }

    if (_platform.isAdReady) {
      _notify(RewardedAdLifecycleState.adReady);
      return true;
    }

    _notify(RewardedAdLifecycleState.loadingAd);

    try {
      final success = await _platform.loadAd(adUnitId: _adUnitId);
      if (success) {
        _notify(RewardedAdLifecycleState.adReady);
        return true;
      } else {
        _notify(RewardedAdLifecycleState.adFailed, message: 'Ad inventory unavailable');
        return false;
      }
    } catch (e) {
      _notify(RewardedAdLifecycleState.adFailed, message: e.toString());
      return false;
    }
  }

  /// Verifies a completion token to protect against forged reward grants.
  bool verifyRewardToken({
    required String transactionId,
    required int amount,
    required String? token,
  }) {
    if (token == null || token.isEmpty) {
      return false;
    }

    // Check platform token signature
    final expectedRaw = 'stocksafe_ssv_token_${transactionId}_$amount';
    final expectedHash = sha256.convert(utf8.encode(expectedRaw)).toString();

    // Check with internal HMAC if custom secret provided
    final hmac = Hmac(sha256, utf8.encode(_ssvSecret));
    final expectedHmac = hmac.convert(utf8.encode(expectedRaw)).toString();

    return token == expectedHash || token == expectedHmac;
  }

  /// Shows the rewarded ad and awards +2 slots upon validated completion.
  Future<RewardAdShowResult> showAdAndEarnReward() async {
    // 1. Check daily limit
    if (await isDailyLimitReached()) {
      _notify(RewardedAdLifecycleState.dailyLimitReached, message: 'Daily reward limit reached');
      return const RewardAdShowResult(
        status: RewardAdShowStatus.failedToShow,
        errorMessage: 'Daily reward limit reached (5 ads max per day)',
      );
    }

    // 2. Ensure ad is ready
    if (!_platform.isAdReady) {
      _notify(RewardedAdLifecycleState.loadingAd);
      final loaded = await preloadAd();
      if (!loaded) {
        _notify(RewardedAdLifecycleState.adFailed, message: 'Could not load advertisement');
        return const RewardAdShowResult(
          status: RewardAdShowStatus.notReady,
          errorMessage: 'Advertisement not ready',
        );
      }
    }

    // 3. Present the advertisement
    _notify(RewardedAdLifecycleState.adPlaying);
    final result = await _platform.showAd();

    if (result.status == RewardAdShowStatus.dismissedWithoutReward) {
      _notify(
        RewardedAdLifecycleState.adDismissedWithoutReward,
        message: 'Ad dismissed before completion. No slots granted.',
      );
      return result;
    }

    if (result.status != RewardAdShowStatus.rewardGranted || result.transactionId == null) {
      _notify(
        RewardedAdLifecycleState.adFailed,
        message: result.errorMessage ?? 'Ad failed or was not completed.',
      );
      return result;
    }

    // 4. Completed! Verify Server-Side / Cryptographic signature
    _notify(RewardedAdLifecycleState.verificationPending);
    final txId = result.transactionId!;
    final token = result.verificationToken;

    final isTokenValid = verifyRewardToken(
      transactionId: txId,
      amount: result.rewardAmount,
      token: token,
    );

    if (!isTokenValid) {
      _notify(
        RewardedAdLifecycleState.verificationFailed,
        message: 'Reward verification failed: invalid signature.',
      );
      return RewardAdShowResult(
        status: RewardAdShowStatus.failedToShow,
        errorMessage: 'Cryptographic reward verification failed',
      );
    }

    // 5. Anti-Replay: Check if transaction was already processed
    final isDuplicate = await _rewardDao.hasTransaction(txId);
    if (isDuplicate) {
      _notify(
        RewardedAdLifecycleState.duplicateTransaction,
        message: 'Transaction already processed.',
      );
      return RewardAdShowResult(
        status: RewardAdShowStatus.failedToShow,
        errorMessage: 'Duplicate reward transaction detected',
      );
    }

    // 6. Grant Entitlement in SQLite
    final now = DateTime.now();
    final expiresAt = now.add(RewardConfig.rewardValidityDuration);

    final inserted = await _rewardDao.insertReward(
      RewardEntitlementRecord(
        rewardTransactionId: txId,
        rewardType: result.rewardType,
        rewardAmount: result.rewardAmount,
        earnedAt: now,
        expiresAt: expiresAt,
        verificationStatus: 'verified',
        source: 'admob_rewarded',
        createdAt: now,
      ),
    );

    if (!inserted) {
      _notify(
        RewardedAdLifecycleState.duplicateTransaction,
        message: 'Could not record reward: duplicate transaction.',
      );
      return RewardAdShowResult(
        status: RewardAdShowStatus.failedToShow,
        errorMessage: 'Transaction already exists in database',
      );
    }

    // 7. Success
    _notify(
      RewardedAdLifecycleState.rewardGranted,
      message: '🎉 +${result.rewardAmount} product slots granted for 7 days!',
      txId: txId,
    );

    return result;
  }

  void dispose() {
    _platform.dispose();
    _stateController.close();
  }
}
