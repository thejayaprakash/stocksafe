import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../services/app_localization.dart';
import '../services/restock_analytics_service.dart';
import 'product_detail_page.dart';
import 'stock_movement_page.dart';

/// Low-stock & Expiry screen:
/// 1. Products where stock_qty <= low_stock_level with restock recommendations.
/// 2. Expiring soon batches requiring clearance or vendor return.
class LowStockPage extends StatefulWidget {
  const LowStockPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<LowStockPage> createState() => _LowStockPageState();
}

class _LowStockPageState extends State<LowStockPage> with SingleTickerProviderStateMixin {
  late final RestockAnalyticsService _analyticsService =
      RestockAnalyticsService(widget.db);
  late final TabController _tabController = TabController(length: 2, vsync: this);
  int _expiryWindowDays = 30;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Material(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.warning_amber_outlined),
                text: AppLocale.tr('low_stock'),
              ),
              Tab(
                icon: const Icon(Icons.timer_outlined),
                text: AppLocale.tr('expiring_soon'),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLowStockTab(theme),
              _buildExpiringBatchesTab(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockTab(ThemeData theme) {
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

  Widget _buildExpiringBatchesTab(ThemeData theme) {
    final fmt = DateFormat.yMMMd();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Window: $_expiryWindowDays days',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 15, label: Text('15d')),
                  ButtonSegment(value: 30, label: Text('30d')),
                  ButtonSegment(value: 60, label: Text('60d')),
                  ButtonSegment(value: 90, label: Text('90d')),
                ],
                selected: {_expiryWindowDays},
                onSelectionChanged: (s) => setState(() => _expiryWindowDays = s.first),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: FutureBuilder<List<ProductBatch>>(
            future: widget.db.batchDao.getExpiringBatches(within: Duration(days: _expiryWindowDays)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final batches = snapshot.data ?? [];

              if (batches.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 64,
                        color: Colors.green.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No expiring stock!',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All tracked batches are safe beyond $_expiryWindowDays days.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: batches.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final b = batches[index];
                  final now = DateTime.now();
                  final isExpired = b.expiryDate != null && b.expiryDate!.isBefore(now);
                  final daysLeft = b.expiryDate != null
                      ? b.expiryDate!.difference(now).inDays
                      : 0;

                  return FutureBuilder<Product?>(
                    future: widget.db.productDao.getById(b.productId),
                    builder: (context, prodSnap) {
                      final prod = prodSnap.data;
                      final prodName = prod?.name ?? 'Product #${b.productId}';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isExpired
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          child: Icon(
                            isExpired ? Icons.cancel_outlined : Icons.timelapse,
                            color: isExpired ? Colors.red : Colors.orange.shade800,
                          ),
                        ),
                        title: Text(prodName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Batch: #${b.batchNumber}  ·  Remaining: ${b.stockQty} ${prod?.unit ?? 'units'}\n'
                          'Expiry: ${b.expiryDate != null ? fmt.format(b.expiryDate!) : 'N/A'}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : (daysLeft <= 7
                                        ? Colors.deepOrange.withValues(alpha: 0.15)
                                        : Colors.amber.withValues(alpha: 0.15)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isExpired
                                    ? AppLocale.tr('expired')
                                    : '$daysLeft ${AppLocale.tr('days_left')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isExpired
                                      ? Colors.red.shade900
                                      : (daysLeft <= 7 ? Colors.deepOrange.shade900 : Colors.brown),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StockMovementPage(
                                    db: widget.db,
                                    productId: b.productId,
                                    initialDirection: StockDirection.outward,
                                    initialBatchId: b.id,
                                    initialQty: b.stockQty,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Clear Batch >',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          if (prod != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailPage(db: widget.db, productId: prod.id),
                              ),
                            );
                          }
                        },
                      );
                    },
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
