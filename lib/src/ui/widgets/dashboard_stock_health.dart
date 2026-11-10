import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/app_palette.dart';

/// Stock Health banner displayed at the top of the dashboard.
///
/// Features dynamic health status, 3D box illustration, and direct navigation
/// to the low stock review screen.
class DashboardStockHealthCard extends StatelessWidget {
  const DashboardStockHealthCard({
    super.key,
    required this.lowStock,
    required this.totalProducts,
    required this.onTap,
  });

  final List<Product> lowStock;
  final int totalProducts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isOptimal = lowStock.isEmpty;
    final outOfStockCount = lowStock.where((p) => p.stockQty <= 0).length;

    // Determine colors based on status urgency
    final Color primaryColor;
    final Color badgeBg;
    final List<Color> gradientColors;
    final Color borderColor;
    final String title;
    final String subtitle;
    final IconData statusIcon;

    if (isOptimal) {
      primaryColor = const Color(0xFF22C55E); // Green
      badgeBg = const Color(0xFF10B981).withValues(alpha: 0.22);
      gradientColors = isDark
          ? [const Color(0xFF063321), const Color(0xFF0B462F)]
          : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)];
      borderColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.45);
      title = 'All stock levels optimal';
      subtitle = totalProducts > 0
          ? '$totalProducts products · No critical shortages'
          : 'Zero critical shortages';
      statusIcon = Icons.check_circle_rounded;
    } else if (outOfStockCount > 0) {
      primaryColor = const Color(0xFFEF4444); // Red
      badgeBg = const Color(0xFFEF4444).withValues(alpha: 0.22);
      gradientColors = isDark
          ? [const Color(0xFF3B0B0B), const Color(0xFF5A1414)]
          : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)];
      borderColor = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.35 : 0.45);
      title = '${lowStock.length} ${lowStock.length == 1 ? 'product needs' : 'products need'} reordering';
      subtitle = '$outOfStockCount out of stock · Critical shortage';
      statusIcon = Icons.error_outline_rounded;
    } else {
      primaryColor = const Color(0xFFF59E0B); // Amber
      badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.22);
      gradientColors = isDark
          ? [const Color(0xFF381E05), const Color(0xFF522E0A)]
          : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)];
      borderColor = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.45);
      title = '${lowStock.length} ${lowStock.length == 1 ? 'product needs' : 'products need'} reordering';
      subtitle = 'Below reorder threshold · Tap to review';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : borderColor).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                // Status Badge Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    color: primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Health Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? primaryColor.withValues(alpha: 0.9)
                              : palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Isometric Box Graphics + Chevron
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IsometricBoxesIcon(color: isOptimal ? const Color(0xFFF59E0B) : primaryColor),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact isometric 3D-styled stacked boxes graphic.
class _IsometricBoxesIcon extends StatelessWidget {
  const _IsometricBoxesIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Base right box
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
          // Base left box
          Positioned(
            left: 2,
            bottom: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 5,
                  height: 1.5,
                  color: Colors.black.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          // Top stacked box
          Positioned(
            left: 10,
            top: 0,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
