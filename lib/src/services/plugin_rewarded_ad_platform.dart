import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'rewarded_ad_platform.dart';

/// [RewardedAdPlatform] implementation powered by Google Mobile Ads SDK (AdMob).
class PluginRewardedAdPlatform implements RewardedAdPlatform {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  @override
  bool get isAdReady => _rewardedAd != null;

  @override
  Future<bool> isSupported() async {
    return true;
  }

  @override
  Future<bool> loadAd({required String adUnitId}) async {
    if (_rewardedAd != null) return true;
    if (_isLoading) return false;
    _isLoading = true;

    final completer = Completer<bool>();
    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isLoading = false;
            completer.complete(true);
          },
          onAdFailedToLoad: (LoadAdError error) {
            _rewardedAd = null;
            _isLoading = false;
            completer.complete(false);
          },
        ),
      );
    } catch (_) {
      _isLoading = false;
      return false;
    }
    return completer.future;
  }

  @override
  Future<RewardAdShowResult> showAd() async {
    final ad = _rewardedAd;
    if (ad == null) {
      return const RewardAdShowResult(
        status: RewardAdShowStatus.notReady,
        errorMessage: 'Rewarded ad is not ready to display.',
      );
    }
    _rewardedAd = null;

    final completer = Completer<RewardAdShowResult>();
    bool rewardEarned = false;
    int grantedAmount = 2;
    String? txId;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) {
          if (rewardEarned && txId != null) {
            completer.complete(
              RewardAdShowResult(
                status: RewardAdShowStatus.rewardGranted,
                transactionId: txId,
                rewardAmount: grantedAmount,
              ),
            );
          } else {
            completer.complete(
              const RewardAdShowResult(
                status: RewardAdShowStatus.dismissedWithoutReward,
                errorMessage: 'Ad closed before completion',
              ),
            );
          }
        }
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(
            RewardAdShowResult(
              status: RewardAdShowStatus.failedToShow,
              errorMessage: error.message,
            ),
          );
        }
      },
    );

    ad.show(
      onUserEarnedReward: (AdWithoutView adWithoutView, RewardItem reward) {
        rewardEarned = true;
        grantedAmount = reward.amount.toInt() > 0 ? reward.amount.toInt() : 2;
        txId = 'admob_${DateTime.now().microsecondsSinceEpoch}';
      },
    );

    return completer.future;
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isLoading = false;
  }
}
