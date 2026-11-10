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

/// A floating, Google Pay-style bottom navigation bar.
///
/// The bar itself is a rounded card that hovers above the bottom edge. The
/// selected destination is marked by a wave crest that rises above the bar and
/// a matching glow inside it; when the selection moves the crest travels with
/// it, stretching and flattening on the way across so it reads as a fluid
/// wave rather than a sliding block.
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

  /// Height of the bar card, excluding the crest and the safe-area inset.
  static const double barHeight = 62;

  /// How far the crest rises above the bar.
  static const double crestHeight = 18;

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

    const radius = BorderRadius.all(Radius.circular(26));

    return Padding(
      padding: widget.margin.copyWith(bottom: widget.margin.bottom + bottomInset),
      child: SizedBox(
        height: FloatingWaveNavBar.barHeight + FloatingWaveNavBar.crestHeight,
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, _) {
            // A bell over the journey: zero at both ends, one in the middle.
            // Multiplied by the distance travelled so a hop to the neighbour
            // barely deforms while a jump across the bar really sloshes.
            final distance = (_to - _from).abs();
            final bell = math.sin(math.pi * _controller.value) *
                math.min(1, distance / 2);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ── The bar card ────────────────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: FloatingWaveNavBar.barHeight,
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
                              ? Colors.black.withValues(alpha: 0.5)
                              : palette.textPrimary.withValues(alpha: 0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── The glow inside the card, clipped to its corners ─────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: FloatingWaveNavBar.barHeight,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: LayoutBuilder(
                      builder: (context, constraints) => CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _WaveGlowPainter(
                          centerX: _centerX(constraints.maxWidth),
                          spread: _spread(constraints.maxWidth, bell),
                          color: palette.primary,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── The crest riding above the card ─────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: FloatingWaveNavBar.crestHeight,
                  child: IgnorePointer(
                    child: LayoutBuilder(
                      builder: (context, constraints) => CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _WaveCrestPainter(
                          centerX: _centerX(constraints.maxWidth),
                          spread: _spread(constraints.maxWidth, bell),
                          // Flattens subtly as it travels, preserving the fluid crest curve.
                          height: FloatingWaveNavBar.crestHeight *
                              (1 - 0.20 * bell),
                          color: palette.primary,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── The destinations ────────────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: FloatingWaveNavBar.barHeight,
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.items.length; i++)
                        Expanded(
                          child: _WaveNavDestination(
                            item: widget.items[i],
                            // Proximity rather than equality, so the icon and
                            // label colour arrive with the wave instead of
                            // flipping the instant the finger lands.
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

  /// Where the crest sits: dead centre over its destination. The tails fade
  /// out horizontally (see [_WaveCrestPainter]), so the two end destinations
  /// need no nudge inward to stay clear of the card's rounded corners.
  double _centerX(double width) =>
      width / widget.items.length * (_position + 0.5);

  double _spread(double width, double bell) {
    final itemWidth = width / widget.items.length;
    // Stretches subtly while in motion — fluid organic crest without excessive smearing.
    return math.min(itemWidth * 1.08 * (1 + 0.16 * bell), width);
  }
}

/// A single icon-and-label destination.
///
/// [emphasis] runs 0 (fully unselected) to 1 (fully selected) and is driven by
/// the crest's position, so colour, weight and the small lift all interpolate
/// together with the wave.
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
        Transform.translate(
          offset: Offset(0, -3 * emphasis),
          child: Icon(
            selected ? item.selectedIcon : item.icon,
            size: 22 + 1.5 * emphasis,
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
        // The dot that trails the selected label in the design. Kept in the
        // layout at zero opacity so nothing shifts as it fades in.
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active.withValues(alpha: emphasis),
            ),
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
          borderRadius: BorderRadius.circular(18),
          splashColor: active.withValues(alpha: 0.08),
          highlightColor: active.withValues(alpha: 0.05),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Draws the crest that rises above the bar.
class _WaveCrestPainter extends CustomPainter {
  const _WaveCrestPainter({
    required this.centerX,
    required this.spread,
    required this.height,
    required this.color,
    required this.isDark,
  });

  final double centerX;
  final double spread;
  final double height;
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height;
    final top = math.max(0.0, base - height);
    final half = spread / 2;
    if (half <= 0 || height <= 0) return;

    final path = Path()
      ..moveTo(centerX - half, base)
      ..cubicTo(
        centerX - half * 0.34, base,
        centerX - half * 0.66, top,
        centerX, top,
      )
      ..cubicTo(
        centerX + half * 0.66, top,
        centerX + half * 0.34, base,
        centerX + half, base,
      )
      ..close();

    final rect = Rect.fromLTRB(centerX - half, top, centerX + half, base);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: isDark ? 0.10 : 0.06),
          color.withValues(alpha: isDark ? 0.62 : 0.40),
        ],
      ).createShader(rect);

    // Painted into a layer so the tails can be erased horizontally. Without
    // it the crest ended in two visible edges, and the end destinations had
    // to be nudged inward to keep those edges off the rounded corners.
    final layer = Rect.fromLTRB(
      centerX - half - 1,
      top - 1,
      centerX + half + 1,
      base + 1,
    );
    canvas.saveLayer(layer, Paint());

    if (isDark) {
      // A soft bloom under the crest. Dark surfaces swallow a flat fill, and
      // the design shows the wave lit rather than merely tinted.
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawPath(path, paint);

    canvas.drawRect(
      layer,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ).createShader(layer),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaveCrestPainter old) =>
      old.centerX != centerX ||
      old.spread != spread ||
      old.height != height ||
      old.color != color ||
      old.isDark != isDark;
}

/// Draws the tint inside the bar that the crest appears to pour into.
class _WaveGlowPainter extends CustomPainter {
  const _WaveGlowPainter({
    required this.centerX,
    required this.spread,
    required this.color,
    required this.isDark,
  });

  final double centerX;
  final double spread;
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final half = spread / 2;
    if (half <= 0) return;

    // Radial rather than a column: a straight gradient left two hard vertical
    // seams on the surface where the tint stopped.
    final rect = Rect.fromCircle(
      center: Offset(centerX, 0),
      radius: math.max(half, size.height),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.30 : 0.20),
            color.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _WaveGlowPainter old) =>
      old.centerX != centerX ||
      old.spread != spread ||
      old.color != color ||
      old.isDark != isDark;
}
