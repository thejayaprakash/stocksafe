import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_palette.dart';

/// One destination in a [FloatingWaveNavBar].
class WaveNavItem {
  const WaveNavItem({
    required this.icon,
    required this.label,
    IconData? selectedIcon,
    this.tooltip,
  }) : selectedIcon = selectedIcon ?? icon;

  /// Shown while the destination is not selected.
  final IconData icon;

  /// Shown while the destination is selected — usually the filled variant.
  final IconData selectedIcon;

  final String label;
  final String? tooltip;
}

/// A floating, modern bottom navigation bar.
///
/// The bar itself is a sleek rounded card that hovers above the bottom edge.
/// The selected destination is smoothly marked by an elegant sliding capsule pill
/// and top accent line inside the bar card, eliminating awkward external crests.
///
/// Both themes are driven from [AppPalette], so the bar follows light and dark
/// without the caller passing any colours.
class FloatingWaveNavBar extends StatefulWidget {
  const FloatingWaveNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.margin = defaultMargin,
  }) : assert(items.length >= 2, 'a navigation bar needs at least two items');

  static const EdgeInsets defaultMargin = EdgeInsets.fromLTRB(12, 0, 12, 10);

  final List<WaveNavItem> items;

  /// Index of the highlighted destination. Items that open a route rather than
  /// switching tabs (the scanner, for instance) simply never become the
  /// selected index — the wave stays where it is.
  final int selectedIndex;

  final ValueChanged<int> onDestinationSelected;

  /// Space between the bar and the screen edges. The bottom inset of the
  /// device is added to the bottom value.
  final EdgeInsets margin;

  /// Height of the bar card.
  static const double barHeight = 64;

  /// Retained for layout backwards compatibility. Set to 0 because the indicator
  /// is now cleanly integrated inside the bar rather than protruding out as an awkward hump.
  static const double crestHeight = 0;

  /// Total height the bar occupies, so a scrolling body can pad itself clear
  /// of it — the bar floats over the content rather than displacing it.
  static double totalHeight(
    BuildContext context, {
    EdgeInsets margin = defaultMargin,
  }) =>
      barHeight +
      crestHeight +
      margin.vertical +
      MediaQuery.viewPaddingOf(context).bottom;

  @override
  State<FloatingWaveNavBar> createState() => _FloatingWaveNavBarState();
}

class _FloatingWaveNavBarState extends State<FloatingWaveNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  /// Where the crest sat before the current journey started, in index space.
  late double _from;

  /// Where it is heading.
  late double _to;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.selectedIndex.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1,
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant FloatingWaveNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      // Start from wherever the crest actually is, not from the previous
      // destination: tapping twice in quick succession should bend the wave
      // onward rather than snap it back.
      _from = _position;
      _to = widget.selectedIndex.toDouble();
      _controller
        ..value = 0
        ..forward();
    }
  }

  /// The crest's live position in index space.
  double get _position => _from + (_to - _from) * _curve.value;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    HapticFeedback.selectionClick();
    widget.onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    const radius = BorderRadius.all(Radius.circular(22));

    return Padding(
      padding: widget.margin.copyWith(bottom: widget.margin.bottom + bottomInset),
      child: SizedBox(
        height: FloatingWaveNavBar.barHeight + FloatingWaveNavBar.crestHeight,
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, _) {
            // A bell over the journey: zero at both ends, one in the middle.
            final distance = (_to - _from).abs();
            final bell = math.sin(math.pi * _controller.value) *
                math.min(1, distance / 2);

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // ── The bar card ────────────────────────────────────────
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.cardSurface,
                      borderRadius: radius,
                      border: Border.all(
                        color: isDark
                            ? palette.border.withValues(alpha: 0.6)
                            : palette.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.45)
                              : palette.textPrimary.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── The sliding indicator pill & top accent line ────────
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: radius,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = constraints.maxWidth / widget.items.length;
                        final centerX = itemWidth * (_position + 0.5);
                        final pillWidth = math.min(itemWidth * 0.72 * (1 + 0.12 * bell), 58.0);
                        return CustomPaint(
                          size: Size(constraints.maxWidth, constraints.maxHeight),
                          painter: _PillIndicatorPainter(
                            centerX: centerX,
                            pillWidth: pillWidth,
                            color: palette.primary,
                            isDark: isDark,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── The destinations ────────────────────────────────────
                Positioned.fill(
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.items.length; i++)
                        Expanded(
                          child: _WaveNavDestination(
                            item: widget.items[i],
                            emphasis:
                                (1 - (_position - i).abs()).clamp(0.0, 1.0),
                            onTap: () => _handleTap(i),
                          ),
                        ),
                    ],
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

/// A single icon-and-label destination.
class _WaveNavDestination extends StatelessWidget {
  const _WaveNavDestination({
    required this.item,
    required this.emphasis,
    required this.onTap,
  });

  final WaveNavItem item;
  final double emphasis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = emphasis > 0.5;

    final active = palette.primary;
    final idle = palette.textTertiary;
    final color = Color.lerp(idle, active, emphasis)!;

    final child = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 1.0 + 0.08 * emphasis,
          child: Icon(
            selected ? item.selectedIcon : item.icon,
            size: 22,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.1,
            fontWeight: emphasis > 0.5 ? FontWeight.w600 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );

    return Semantics(
      selected: selected,
      button: true,
      label: item.tooltip ?? item.label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: active.withValues(alpha: 0.10),
          highlightColor: active.withValues(alpha: 0.05),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Draws the sleek active indicator inside the navigation bar card.
class _PillIndicatorPainter extends CustomPainter {
  const _PillIndicatorPainter({
    required this.centerX,
    required this.pillWidth,
    required this.color,
    required this.isDark,
  });

  final double centerX;
  final double pillWidth;
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (pillWidth <= 0) return;

    // 1. Sleek top accent line sliding at the top border inside the card
    const topLineWidth = 24.0;
    final topLineRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, 1.5),
        width: topLineWidth,
        height: 3.0,
      ),
      const Radius.circular(2),
    );

    if (isDark) {
      canvas.drawRRect(
        topLineRect,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawRRect(
      topLineRect,
      Paint()..color = color,
    );

    // 2. Soft ambient background pill sliding behind the active icon
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, size.height * 0.38),
        width: pillWidth,
        height: 32.0,
      ),
      const Radius.circular(16),
    );

    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = color.withValues(alpha: isDark ? 0.20 : 0.12),
    );
  }

  @override
  bool shouldRepaint(covariant _PillIndicatorPainter old) =>
      old.centerX != centerX ||
      old.pillWidth != pillWidth ||
      old.color != color ||
      old.isDark != isDark;
}
