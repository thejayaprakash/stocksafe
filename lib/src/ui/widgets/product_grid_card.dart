import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/app_palette.dart';
import '../money_format.dart';
import 'bulk_actions.dart';
import 'favourite_button.dart';
import 'product_avatar.dart';

/// Status indicator colors and labels for a [Product].
class ProductStatusStyle {
  const ProductStatusStyle({
    required this.color,
    required this.backgroundColor,
    required this.label,
  });

  final Color color;
  final Color backgroundColor;
  final String label;

  static ProductStatusStyle of(BuildContext context, Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (product.stockQty <= 0) {
      const red = Color(0xFFEF4444);
      return ProductStatusStyle(
        color: red,
        backgroundColor: red.withValues(alpha: isDark ? 0.20 : 0.12),
        label: 'Out of Stock',
      );
    }

    if (product.lowStockLevel > 0 && product.stockQty <= product.lowStockLevel) {
      const orange = Color(0xFFF59E0B);
      return ProductStatusStyle(
        color: orange,
        backgroundColor: orange.withValues(alpha: isDark ? 0.20 : 0.12),
        label: 'Low Stock',
      );
    }

    const green = Color(0xFF22C55E);
    return ProductStatusStyle(
      color: green,
      backgroundColor: green.withValues(alpha: isDark ? 0.20 : 0.12),
      label: 'In Stock',
    );
  }
}

/// A premium, compact product card for 2-column mobile grid view.
///
/// Features:
/// - Distinctive left colored status border (Green / Orange / Red).
/// - Consistent product image thumbnail with rounded corners and initial fallback.
/// - Independent heart favourite toggle and stock quantity badge.
/// - Two-line bold title, SKU secondary label, and stock status dot.
/// - Footer with inventory unit and formatted price.
class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<int>? onToggleSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusStyle = ProductStatusStyle.of(context, product);

    final skuText = (product.sku != null && product.sku!.trim().isNotEmpty)
        ? product.sku!.trim()
        : '-';

    final effectivePrice = product.sellPrice > 0 ? product.sellPrice : product.buyPrice;

    return Material(
      color: selected
          ? palette.primary.withValues(alpha: isDark ? 0.18 : 0.10)
          : (isDark ? const Color(0xFF151E2E) : palette.cardSurface),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: selectionMode
            ? () => onToggleSelected?.call(product.id)
            : onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          foregroundPainter: CardAccentBorderPainter(
            color: selected ? palette.primary : statusStyle.color,
            strokeWidth: 2.0,
            radius: 16,
            glow: isDark,
          ),
          child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? palette.primary
                      : (isDark
                          ? const Color(0xFF334155).withValues(alpha: 0.6)
                          : palette.border),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(11, 9, 9, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Row: Image / Avatar + (Fav & Stock Badge) ────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Hero(
                            tag: 'product_img_${product.id}',
                            child: ProductAvatar(
                              product: product,
                              size: 46,
                              radiusFactor: 0.28,
                            ),
                          ),
                          if (selectionMode)
                            Positioned(
                              top: -4,
                              left: -4,
                              child: SelectionCheckbox(
                                selected: selected,
                                onChanged: (_) => onToggleSelected?.call(product.id),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FavouriteButton(product: product, size: 18),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: statusStyle.backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${product.stockQty}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: statusStyle.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Product Name (2 lines max) ─────────────────────────
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.18,
                      color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // ── SKU ─────────────────────────────────────────────────
                  Text(
                    'SKU: $skuText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ── Stock Status Dot + Label ────────────────────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5.5,
                        height: 5.5,
                        decoration: BoxDecoration(
                          color: statusStyle.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4.5),
                      Flexible(
                        child: Text(
                          statusStyle.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusStyle.color,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── Footer Divider & Info ──────────────────────────────
                  Divider(
                    height: 10,
                    thickness: 0.7,
                    color: isDark
                        ? const Color(0xFF334155).withValues(alpha: 0.5)
                        : palette.border,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 13,
                        color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${product.stockQty} ${product.unit.trim().isEmpty ? 'pcs' : product.unit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
                          ),
                        ),
                      ),
                      Container(
                        width: 0.8,
                        height: 11,
                        color: isDark
                            ? const Color(0xFF334155).withValues(alpha: 0.7)
                            : palette.border,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatRupees(effectivePrice),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                        ),
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

/// Paints a sleek rounded accent border stroke along the left edge and corners of a card.
class CardAccentBorderPainter extends CustomPainter {
  const CardAccentBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.radius = 16.0,
    this.glow = false,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (color == Colors.transparent || color.a == 0) return;

    final h = size.height;
    final r = radius;
    final half = strokeWidth / 2;

    // Corner radius clamped to half height
    final cornerR = math.min(r, h / 2) - half;

    // Trace path:
    // Starts 10px past the top-left curve on the top edge,
    // rounds the top-left corner, runs down the left edge,
    // rounds the bottom-left corner, and ends 10px past bottom-left curve.
    final path = Path()
      ..moveTo(half + cornerR + 10, half)
      ..lineTo(half + cornerR, half)
      ..arcTo(
        Rect.fromLTWH(half, half, cornerR * 2, cornerR * 2),
        -math.pi / 2,
        -math.pi / 2,
        false,
      )
      ..lineTo(half, h - half - cornerR)
      ..arcTo(
        Rect.fromLTWH(half, h - half - cornerR * 2, cornerR * 2, cornerR * 2),
        math.pi,
        -math.pi / 2,
        false,
      )
      ..lineTo(half + cornerR + 10, h - half);

    if (glow) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2.0
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, glowPaint);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color,
          color,
          color.withValues(alpha: 0.15),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, cornerR + 14, h));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CardAccentBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius ||
      oldDelegate.glow != glow;
}
