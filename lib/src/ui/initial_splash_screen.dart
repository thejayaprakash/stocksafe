import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_page.dart';

/// Initial animated loading and splash screen for StockSafe.
///
/// Features:
/// - Signature deep navy brand background (`#0B1220`).
/// - Choreographed entrance animations:
///   1. Shield logo scale, fade-in, and ambient radial glow pulse.
///   2. Formatted "StockSafe" wordmark slide-up and fade.
///   3. Subtitle and micro-caption tracking.
///   4. Smooth progress gradient indicator simulating ledger readiness.
/// - Seamless cross-fade transition into [HomePage].
class InitialSplashScreen extends StatefulWidget {
  const InitialSplashScreen({
    super.key,
    this.animationDuration = const Duration(milliseconds: 1400),
    this.skipAnimation = false,
  });

  /// Total duration of the choreographed entrance animation.
  final Duration animationDuration;

  /// If true, immediately displays [HomePage] without running splash animation.
  /// Useful for automated integration and widget testing.
  final bool skipAnimation;

  @override
  State<InitialSplashScreen> createState() => _InitialSplashScreenState();
}

class _InitialSplashScreenState extends State<InitialSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shieldScale;
  late final Animation<double> _shieldOpacity;
  late final Animation<double> _glowOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _progressValue;

  bool _isTransitionReady = false;

  @override
  void initState() {
    super.initState();

    if (widget.skipAnimation) {
      _isTransitionReady = true;
      return;
    }

    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    // 1. Shield logo entrance (0% -> 55%)
    _shieldScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _shieldOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
      ),
    );

    // 2. Ambient radial glow pulse behind shield (20% -> 75%)
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.75, curve: Curves.easeInOut),
      ),
    );

    // 3. Brand Wordmark slide up & fade (30% -> 75%)
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.70, curve: Curves.easeOut),
      ),
    );

    // 4. Subtitle fade (45% -> 85%)
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
      ),
    );

    // 5. Progress bar track fill (50% -> 98%)
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.98, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _isTransitionReady = true);
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    if (!widget.skipAnimation) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.skipAnimation || _isTransitionReady) {
      return const HomePage();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0B1220),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Ambient background soft radial glow
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: _glowOpacity.value * 0.45,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0080FF).withValues(alpha: 0.35),
                              blurRadius: 90,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Main Brand Content (Logo + Typography)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shield Mark with scale & fade
                      Opacity(
                        opacity: _shieldOpacity.value,
                        child: Transform.scale(
                          scale: _shieldScale.value,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0080FF).withValues(
                                    alpha: _glowOpacity.value * 0.4,
                                  ),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo_shield_dark.png',
                              width: 88,
                              height: 98,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.shield_rounded,
                                size: 84,
                                color: Color(0xFF0080FF),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Brand Wordmark: "StockSafe"
                      SlideTransition(
                        position: _titleSlide,
                        child: Opacity(
                          opacity: _titleOpacity.value,
                          child: Text.rich(
                            TextSpan(
                              text: 'Stock',
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontWeight: FontWeight.w800,
                              ),
                              children: const [
                                TextSpan(
                                  text: 'Safe',
                                  style: TextStyle(
                                    color: Color(0xFF0080FF),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle: "Offline Inventory & Audit"
                      Opacity(
                        opacity: _subtitleOpacity.value,
                        child: const Text(
                          'Offline Inventory & Audit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom loading progress & ledger security caption
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 64,
                  child: Opacity(
                    opacity: _subtitleOpacity.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sleek glowing progress capsule
                        Container(
                          width: 150,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 150 * _progressValue.value,
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF0080FF),
                                  Color(0xFF38BDF8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0080FF).withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Micro caption
                        const Text(
                          '100% OFFLINE · DATA SOVEREIGNTY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
