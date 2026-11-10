import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/app_palette.dart';
import '../product_detail_page.dart';
import 'product_avatar.dart';

/// Horizontally scrollable Top Products carousel for the home dashboard.
class DashboardTopProducts extends StatelessWidget {
  const DashboardTopProducts({
    super.key,
    required this.products,
    required this.onViewAll,
    required this.onAddProduct,
  });

  final List<Product> products;
  final VoidCallback onViewAll;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Top Products',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: palette.textPrimary,
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: palette.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'View All',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Carousel or Empty State
        if (products.isEmpty)
          _EmptyProductsBanner(onAddProduct: onAddProduct, isDark: isDark)
        else
          SizedBox(
            height: 158,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: products.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final product = products[index];
                return _TopProductCard(
                  product: product,
                  isDark: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(productId: product.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Single compact product card in the horizontal carousel.
class _TopProductCard extends StatelessWidget {
  const _TopProductCard({
    required this.product,
    required this.isDark,
    required this.onTap,
  });

  final Product product;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final isOutOfStock = product.stockQty <= 0;
    final isLow = !isOutOfStock &&
        product.lowStockLevel > 0 &&
        product.stockQty <= product.lowStockLevel;

    final Color badgeBg;
    final Color badgeText;

    if (isOutOfStock) {
      badgeBg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
      badgeText = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    } else if (isLow) {
      badgeBg = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      badgeText = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    } else {
      badgeBg = isDark ? const Color(0xFF063321) : const Color(0xFFDCFCE7);
      badgeText = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    }

    final unitLabel = product.unit.trim().isNotEmpty
        ? product.unit.trim()
        : 'pcs';

    return Container(
      width: 118,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E2E) : palette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155).withValues(alpha: 0.7)
              : palette.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Product Photo / Avatar
                Hero(
                  tag: 'product_img_${product.id}',
                  child: ProductAvatar(
                    product: product,
                    size: 54,
                    radiusFactor: 0.28,
                  ),
                ),

                const SizedBox(height: 6),

                // Product Title
                Expanded(
                  child: Center(
                    child: Text(
                      product.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Stock Quantity Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: badgeText.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${product.stockQty} $unitLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback banner when no products exist yet.
class _EmptyProductsBanner extends StatelessWidget {
  const _EmptyProductsBanner({
    required this.onAddProduct,
    required this.isDark,
  });

  final VoidCallback onAddProduct;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E2E) : palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : palette.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 32,
            color: palette.textTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            'No products added yet',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your items to see top inventory right here.',
            style: TextStyle(fontSize: 11.5, color: palette.textTertiary),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAddProduct,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add First Product', style: TextStyle(fontSize: 12.5)),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
