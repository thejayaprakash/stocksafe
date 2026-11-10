import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/database.dart';
import '../../services/license_service.dart';
import '../../services/plugin_rewarded_ad_platform.dart';
import '../../theme/app_palette.dart';

/// Native Ad & Sponsored section for the Home Dashboard.
///
/// Blends cleanly with the navy dark-mode theme while adhering strictly to
/// Google AdMob attribution and disclosure guidelines.
/// Supports multiple ad items in a controlled carousel with indicator dots.
class AdMobNativeSection extends StatefulWidget {
  const AdMobNativeSection({
    super.key,
    required this.db,
    required this.rewardedCard,
  });

  final AppDatabase db;
  final Widget rewardedCard;

  @override
  State<AdMobNativeSection> createState() => _AdMobNativeSectionState();
}

class _AdMobNativeSectionState extends State<AdMobNativeSection> {
  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;
  int _currentPage = 0;
  final PageController _pageController = PageController();
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _checkLicense();
    _loadNativeAd();
  }

  Future<void> _checkLicense() async {
    final isPro = await LicenseService(widget.db).isProUnlocked();
    if (!mounted) return;
    setState(() => _isPro = isPro);
  }

  void _loadNativeAd() {
    // Avoid running platform channels in unit/widget test environments
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    try {
      PluginRewardedAdPlatform.ensureInitialized();

      // Official Google Sample Native Ad Unit ID
      final adUnitId = Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/2247696110'
          : 'ca-app-pub-3940256099942544/3986624511';

      _nativeAd = NativeAd(
        adUnitId: adUnitId,
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (mounted) {
              setState(() {
                _isNativeAdLoaded = true;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (mounted) {
              setState(() {
                _isNativeAdLoaded = false;
                _nativeAd = null;
              });
            }
          },
        ),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.small,
          mainBackgroundColor: const Color(0xFF151E2E),
          cornerRadius: 14.0,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            backgroundColor: const Color(0xFF3B82F6),
            style: NativeTemplateFontStyle.bold,
            size: 12.0,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: const Color(0xFFF8FAFC),
            style: NativeTemplateFontStyle.bold,
            size: 13.5,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: const Color(0xFF94A3B8),
            style: NativeTemplateFontStyle.normal,
            size: 11.5,
          ),
          tertiaryTextStyle: NativeTemplateTextStyle(
            textColor: const Color(0xFF64748B),
            style: NativeTemplateFontStyle.normal,
            size: 10.5,
          ),
        ),
      )..load();
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPro) return const SizedBox.shrink();

    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [];

    if (_isNativeAdLoaded && _nativeAd != null) {
      pages.add(
        _AdMobSdkNativeContainer(
          nativeAd: _nativeAd!,
          isDark: isDark,
          palette: palette,
        ),
      );
      pages.add(widget.rewardedCard);
    } else {
      pages.add(widget.rewardedCard);
    }

    final totalPages = pages.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 98,
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: pages,
          ),
        ),

        // Carousel Dot Indicators
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            totalPages > 1 ? totalPages : 3,
            (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 4,
                width: isActive ? 14 : 4,
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark ? const Color(0xFF60A5FA) : palette.primary)
                      : (isDark ? const Color(0xFF334155) : palette.border),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Native Ad container hosting the official Google Mobile Ads [AdWidget].
class _AdMobSdkNativeContainer extends StatelessWidget {
  const _AdMobSdkNativeContainer({
    required this.nativeAd,
    required this.isDark,
    required this.palette,
  });

  final NativeAd nativeAd;
  final bool isDark;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E2E) : palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : palette.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AdWidget(ad: nativeAd),
      ),
    );
  }
}
