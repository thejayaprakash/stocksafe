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
        child: Stack(
          children: [
            Container(
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
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
                              size: 54,
                              radiusFactor: 0.26,
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
                          FavouriteButton(product: product, size: 20),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusStyle.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${product.stockQty}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: statusStyle.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Product Name (2 lines max) ─────────────────────────
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.22,
                      color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // ── SKU ─────────────────────────────────────────────────
                  Text(
                    'SKU: $skuText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Stock Status Dot + Label ────────────────────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusStyle.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          statusStyle.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
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
                    height: 14,
                    thickness: 0.8,
                    color: isDark
                        ? const Color(0xFF334155).withValues(alpha: 0.5)
                        : palette.border,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 13.5,
                        color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          product.unit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
                          ),
                        ),
                      ),
                      if (effectivePrice > 0)
                        Text(
                          formatRupees(effectivePrice),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: statusStyle.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
