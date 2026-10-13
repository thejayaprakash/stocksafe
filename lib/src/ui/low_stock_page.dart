import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../services/app_localization.dart';
import '../services/esc_pos_service.dart';
import '../services/restock_analytics_service.dart';
import 'product_detail_page.dart';
import 'stock_movement_page.dart';
import 'suppliers_page.dart';
import 'widgets/thermal_slip_preview_sheet.dart';
import '../app_scope.dart';
import 'widgets/external_app.dart';

/// Low-stock & Expiry screen:
/// 1. Products where stock_qty <= low_stock_level with restock recommendations.
/// 2. Direct "Call Supplier" action and supplier assignment.
/// 3. Bluetooth Thermal Reorder Slip (ESC/POS) generation for wholesale buying.
/// 4. Expiring soon batches requiring clearance or vendor return.
class LowStockPage extends StatefulWidget {
  const LowStockPage({super.key});

  @override
  State<LowStockPage> createState() => _LowStockPageState();
}

class _LowStockPageState extends State<LowStockPage> with SingleTickerProviderStateMixin {
  /// The live database, read through the scope rather than passed in.
  /// Uses [AppScope.read] so it is safe to call from initState; widgets that
  /// must rebuild when the connection is replaced should call AppScope.of in
  /// build instead.
  AppDatabase get _db => AppScope.read(context).db;

  late final RestockAnalyticsService _analyticsService =
      RestockAnalyticsService(_db);
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
      stream: _db.productDao.watchLowStock(),
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
            final recMap = <int, RestockRecommendation>{
              for (final r in (recSnapshot.data ?? const <RestockRecommendation>[])) r.product.id: r,
            };

            return Column(
              children: [
                // Top Operational Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Row(
                    children: [
                      Text(
                        '${products.length} Items Need Restock',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      // Print Reorder Slip (ESC/POS)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Reorder Slip'),
                        onPressed: () => _printReorderSlip(products, recMap),
                      ),
                      const SizedBox(width: 6),
                      // Suppliers Directory button
                      IconButton(
                        icon: const Icon(Icons.contact_phone_outlined, size: 20),
                        tooltip: 'Suppliers Directory',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SuppliersPage()),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
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
                            builder: (_) => ProductDetailPage(productId: p.id),
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

                              // SUPPLIER & TAP-TO-CALL SECTION
                              const SizedBox(height: 8),
                              _buildSupplierActionRow(theme, p),

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
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSupplierActionRow(ThemeData theme, Product product) {
    if (product.supplierId == null) {
      return Row(
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            icon: const Icon(Icons.person_add_alt, size: 15),
            label: Text(AppLocale.tr('assign_supplier'), style: const TextStyle(fontSize: 12)),
            onPressed: () => _showAssignSupplierDialog(product),
          ),
        ],
      );
    }

    return FutureBuilder<Supplier?>(
      future: _db.supplierDao.getById(product.supplierId!),
      builder: (context, snap) {
        final supplier = snap.data;
        if (supplier == null) {
          return Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.person_add_alt, size: 15),
                label: Text(AppLocale.tr('assign_supplier'), style: const TextStyle(fontSize: 12)),
                onPressed: () => _showAssignSupplierDialog(product),
              ),
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.store_outlined, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${supplier.name} (${supplier.phone})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.phone, size: 14),
                label: Text(AppLocale.tr('call_supplier'), style: const TextStyle(fontSize: 11)),
                onPressed: () => _callSupplier(supplier.phone),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
                tooltip: 'Change Supplier',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showAssignSupplierDialog(product),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _callSupplier(String phone) =>
      ExternalApp.dial(context, phone);

  Future<void> _showAssignSupplierDialog(Product product) async {
    final suppliers = await _db.supplierDao.getAll();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Assign Supplier for "${product.name}"'),
        content: SizedBox(
          width: double.maxFinite,
          child: suppliers.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No suppliers in directory yet.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add New Supplier'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SuppliersPage()),
                        );
                      },
                    ),
                  ],
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: suppliers.length + 1,
                  itemBuilder: (_, index) {
                    if (index == suppliers.length) {
                      return ListTile(
                        leading: const Icon(Icons.person_add, color: Colors.blue),
                        title: const Text('Add New Supplier...', style: TextStyle(color: Colors.blue)),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SuppliersPage()),
                          );
                        },
                      );
                    }
                    final s = suppliers[index];
                    return ListTile(
                      leading: const Icon(Icons.store_outlined),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(s.phone),
                      trailing: product.supplierId == s.id ? const Icon(Icons.check, color: Colors.green) : null,
                      onTap: () async {
                        await _db.productDao.updateProduct(
                          product.id,
                          ProductsCompanion(supplierId: Value(s.id)),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Assigned "${s.name}" to ${product.name}')),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          if (product.supplierId != null)
            TextButton(
              onPressed: () async {
                await _db.productDao.updateProduct(
                  product.id,
                  const ProductsCompanion(supplierId: Value(null)),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Unassign', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _printReorderSlip(List<Product> products, Map<int, RestockRecommendation> recMap) async {
    final entries = <LowStockSlipEntry>[];
    for (final p in products) {
      final rec = recMap[p.id];
      final deficit = p.lowStockLevel - p.stockQty;
      final suggested = rec?.recommendedOrderQty ?? (deficit > 0 ? deficit : 10);
      Supplier? s;
      if (p.supplierId != null) {
        s = await _db.supplierDao.getById(p.supplierId!);
      }
      entries.add(LowStockSlipEntry(
        product: p,
        suggestedOrderQty: suggested,
        supplier: s,
      ));
    }

    final shopName = await _db.settingDao.get('shop_name') ?? 'STOCKSAFE KIRANA';

    final bytes58 = EscPosService.buildLowStockReorderSlipBytes(
      entries: entries,
      shopName: shopName,
      paperWidth: ThermalPaperWidth.mm58,
    );
    final bytes80 = EscPosService.buildLowStockReorderSlipBytes(
      entries: entries,
      shopName: shopName,
      paperWidth: ThermalPaperWidth.mm80,
    );
    final text58 = EscPosService.buildLowStockReorderText(
      entries: entries,
      shopName: shopName,
      paperWidth: ThermalPaperWidth.mm58,
    );
    final text80 = EscPosService.buildLowStockReorderText(
      entries: entries,
      shopName: shopName,
      paperWidth: ThermalPaperWidth.mm80,
    );

    if (mounted) {
      await ThermalSlipPreviewSheet.show(
        context,
        title: AppLocale.tr('print_reorder_slip'),
        slipBytes58: bytes58,
        slipBytes80: bytes80,
        slipText58: text58,
        slipText80: text80,
        fileNamePrefix: 'reorder_slip',
      );
    }
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
            future: _db.batchDao.getExpiringBatches(within: Duration(days: _expiryWindowDays)),
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
                    future: _db.productDao.getById(b.productId),
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
                                builder: (_) => ProductDetailPage(productId: prod.id),
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
