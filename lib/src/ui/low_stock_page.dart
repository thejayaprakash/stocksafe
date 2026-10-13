import 'package:flutter/material.dart';

import '../data/database.dart';
import '../services/restock_analytics_service.dart';
import 'product_detail_page.dart';
import 'stock_movement_page.dart';

/// Low-stock screen: products where stock_qty <= low_stock_level,
/// augmented with the Smart Restocking Assistant that calculates
/// consumption velocity and recommends reorder quantities.
class LowStockPage extends StatefulWidget {
  const LowStockPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<LowStockPage> createState() => _LowStockPageState();
}

class _LowStockPageState extends State<LowStockPage> {
  late final RestockAnalyticsService _analyticsService =
      RestockAnalyticsService(widget.db);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<Product>>(
      stream: widget.db.productDao.watchLowStock(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data ?? const <Product>[];

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'All stocked up!',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'No products are below their alert level.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<List<RestockRecommendation>>(
          future: _analyticsService.getRecommendations(),
          builder: (context, recSnapshot) {
            final recMap = {
              for (final r in (recSnapshot.data ?? [])) r.product.id: r,
            };

            return ListView.separated(
              itemCount: products.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = products[index];
                final rec = recMap[p.id];
                final deficit = p.lowStockLevel - p.stockQty;
                final suggestedOrder = rec?.recommendedOrderQty ?? (deficit > 0 ? deficit : 10);

                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailPage(db: widget.db, productId: p.id),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.errorContainer,
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: theme.colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Stock: ${p.stockQty} ${p.unit}  ·  Alert at: ${p.lowStockLevel}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StockMovementPage(
                                    db: widget.db,
                                    productId: p.id,
                                    initialDirection: StockDirection.inward,
                                    initialQty: suggestedOrder,
                                  ),
                                ),
                              ),
                              child: Text('Restock (+$suggestedOrder)'),
                            ),
                          ],
                        ),
                        if (rec != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: rec.dailyConsumptionRate >= 2.0
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : Colors.blue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⚡ ${rec.velocityLabel} (${rec.dailyConsumptionRate.toStringAsFixed(1)} units/day)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: rec.dailyConsumptionRate >= 2.0 ? Colors.deepOrange : Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                rec.daysOfStockRemaining < 900
                                    ? 'Est. runway: ~${rec.daysOfStockRemaining.toStringAsFixed(0)} days'
                                    : 'No recent sales',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
