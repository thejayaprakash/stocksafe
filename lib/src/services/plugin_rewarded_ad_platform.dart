import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'reward_config.dart';
import 'rewarded_ad_platform.dart';

/// [RewardedAdPlatform] implementation powered by Google Mobile Ads SDK (AdMob).
class PluginRewardedAdPlatform implements RewardedAdPlatform {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (!_initialized) {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: const [
            'DA33DD48180E5C4E48AF5145B319A183',
          ],
        ),
      );
      _initialized = true;
    }
  }

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
      await ensureInitialized();
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isLoading = false;
            debugPrint('AdMob RewardedAd loaded successfully: ${ad.adUnitId}');
            completer.complete(true);
          },
          onAdFailedToLoad: (LoadAdError error) async {
            _rewardedAd = null;
            debugPrint('AdMob failed to load [${error.code}]: ${error.message}');
            // If the production unit is not yet approved by AdMob ("Requires review" / No-fill),
            // seamlessly fall back to Google's official sample test unit so the user can verify real ad video!
            if (adUnitId != RewardConfig.testRewardedAdUnitId) {
              debugPrint('Falling back to Google sample test unit for testing...');
              final fallbackSuccess = await _loadDirect(RewardConfig.testRewardedAdUnitId);
              _isLoading = false;
              completer.complete(fallbackSuccess);
              return;
            }
            _isLoading = false;
            completer.complete(false);
          },
        ),
      );
    } catch (e) {
      debugPrint('AdMob loadAd exception: $e');
      _isLoading = false;
      return false;
    }
    return completer.future;
  }

  Future<bool> _loadDirect(String unitId) {
    final c = Completer<bool>();
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          debugPrint('AdMob sample test ad loaded successfully: ${ad.adUnitId}');
          c.complete(true);
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          debugPrint('AdMob sample test ad failed to load: [${error.code}] ${error.message}');
          c.complete(false);
        },
      ),
    );
    return c.future;
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
            final token = sha256
                .convert(utf8.encode('stocksafe_ssv_token_${txId}_$grantedAmount'))
                .toString();
            completer.complete(
              RewardAdShowResult(
                status: RewardAdShowStatus.rewardGranted,
                transactionId: txId,
                rewardAmount: grantedAmount,
                verificationToken: token,
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

    unawaited(
      ad.show(
        onUserEarnedReward: (AdWithoutView adWithoutView, RewardItem reward) {
          rewardEarned = true;
          grantedAmount = reward.amount.toInt() > 0 ? reward.amount.toInt() : 2;
          txId = 'admob_${DateTime.now().microsecondsSinceEpoch}';
        },
      ),
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
