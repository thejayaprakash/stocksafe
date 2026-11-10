import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Possible outcomes when presenting a rewarded advertisement.
enum RewardAdShowStatus {
  /// User watched the full advertisement and earned the reward.
  rewardGranted,

  /// User dismissed or closed the ad before reaching the reward checkpoint.
  dismissedWithoutReward,

  /// An error occurred while attempting to show the advertisement.
  failedToShow,

  /// Advertisement was not loaded and ready to show.
  notReady,
}

/// Result payload returned following an ad presentation.
class RewardAdShowResult {
  const RewardAdShowResult({
    required this.status,
    this.transactionId,
    this.rewardAmount = 2,
    this.rewardType = 'product_capacity',
    this.verificationToken,
    this.errorMessage,
  });

  final RewardAdShowStatus status;

  /// Unique transaction identifier assigned to this ad completion.
  final String? transactionId;

  /// Number of slots granted (standard: 2).
  final int rewardAmount;

  /// Type identifier for the reward.
  final String rewardType;

  /// Cryptographic or server-side verification token validating this completion.
  final String? verificationToken;

  /// Error details if presentation failed.
  final String? errorMessage;

  bool get isSuccess => status == RewardAdShowStatus.rewardGranted && transactionId != null;
}

/// Abstract interface for rewarded advertisement presentation.
///
/// Follows the same pattern as [BillingPlatform] in `billing_service.dart`,
/// ensuring tests can run in complete isolation without Google Play or native AdMob binaries.
abstract class RewardedAdPlatform {
  Future<bool> isSupported();
  Future<bool> loadAd({required String adUnitId});
  Future<RewardAdShowResult> showAd();
  bool get isAdReady;
  void dispose();
}

/// In-memory fake platform for hermetic testing of rewarded ad lifecycle states.
class FakeRewardedAdPlatform implements RewardedAdPlatform {
  FakeRewardedAdPlatform({
    this.supported = true,
    this.loadSucceeds = true,
    this.showStatus = RewardAdShowStatus.rewardGranted,
    this.grantAmount = 2,
    this.customTransactionId,
  });

  bool supported;
  bool loadSucceeds;
  RewardAdShowStatus showStatus;
  int grantAmount;
  String? customTransactionId;

  bool _isReady = false;
  int loadCalls = 0;
  int showCalls = 0;

  @override
  bool get isAdReady => _isReady;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> loadAd({required String adUnitId}) async {
    loadCalls++;
    if (!supported || !loadSucceeds) {
      _isReady = false;
      return false;
    }
    _isReady = true;
    return true;
  }

  @override
  Future<RewardAdShowResult> showAd() async {
    showCalls++;
    if (!_isReady) {
      return const RewardAdShowResult(
        status: RewardAdShowStatus.notReady,
        errorMessage: 'Ad is not loaded or ready to show',
      );
    }
    _isReady = false; // Consumed

    if (showStatus == RewardAdShowStatus.rewardGranted) {
      final txId = customTransactionId ??
          'tx_test_${DateTime.now().microsecondsSinceEpoch}_$showCalls';
      final token = sha256
          .convert(utf8.encode('stocksafe_ssv_token_${txId}_$grantAmount'))
          .toString();

      return RewardAdShowResult(
        status: RewardAdShowStatus.rewardGranted,
        transactionId: txId,
        rewardAmount: grantAmount,
        verificationToken: token,
      );
    } else if (showStatus == RewardAdShowStatus.dismissedWithoutReward) {
      return const RewardAdShowResult(
        status: RewardAdShowStatus.dismissedWithoutReward,
        errorMessage: 'User closed ad before completion',
      );
    } else {
      return const RewardAdShowResult(
        status: RewardAdShowStatus.failedToShow,
        errorMessage: 'Failed to display ad',
      );
    }
  }

  @override
  void dispose() {
    _isReady = false;
  }
}
