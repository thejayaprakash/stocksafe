import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import 'product_edit_page.dart';
import 'stock_movement_page.dart';

/// Product detail: current stock (derived) plus full movement history.
class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.db, required this.productId});

  final AppDatabase db;
  final int productId;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_jm();

    return StreamBuilder<Product?>(
      stream: db.productDao.watchById(productId),
      builder: (context, productSnap) {
        final product = productSnap.data;
        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Product')),
            body: const Center(child: Text('Product not found')),
          );
        }
        final lowStock = product.stockQty <= product.lowStockLevel;

        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductEditPage(db: db, product: product),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${product.stockQty}',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: lowStock
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          product.unit,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (lowStock) ...[
                          const SizedBox(width: 12),
                          Chip(
                            label: const Text('Low stock'),
                            backgroundColor:
                                Theme.of(context).colorScheme.errorContainer,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (product.sku != null) 'SKU: ${product.sku}',
                        if (product.barcode != null) 'Barcode: ${product.barcode}',
                        'Buy: ${product.buyPrice}  ·  Sell: ${product.sellPrice}',
                        'Alert at: ${product.lowStockLevel}',
                      ].join('\n'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Divider(),
              // BATCHES & EXPIRY SECTION
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Batches & Expiry',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockMovementPage(
                            db: db,
                            productId: productId,
                            initialDirection: StockDirection.inward,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Batch'),
                    ),
                  ],
                ),
              ),
              StreamBuilder<List<ProductBatch>>(
                stream: db.batchDao.watchBatchesForProduct(productId),
                builder: (context, batchSnap) {
                  final batches = batchSnap.data ?? [];
                  if (batches.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'No specific batches tracked for this product.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    );
                  }

                  final now = DateTime.now();
                  final dateFmt = DateFormat.yMMMd();

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: batches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final b = batches[index];
                      final isExpired = b.expiryDate != null && b.expiryDate!.isBefore(now);
                      final daysLeft = b.expiryDate?.difference(now).inDays;

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.qr_code_2,
                          color: isExpired ? Colors.red : (daysLeft != null && daysLeft <= 30 ? Colors.orange : Colors.blueGrey),
                        ),
                        title: Text(
                          'Batch #${b.batchNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Qty: ${b.stockQty} ${product.unit}'
                          '${b.expiryDate != null ? " · Exp: ${dateFmt.format(b.expiryDate!)}" : ""}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (b.expiryDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isExpired
                                      ? Colors.red.withValues(alpha: 0.15)
                                      : (daysLeft != null && daysLeft <= 30
                                          ? Colors.orange.withValues(alpha: 0.15)
                                          : Colors.green.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isExpired
                                      ? 'Expired'
                                      : (daysLeft != null && daysLeft <= 30
                                          ? '$daysLeft d left'
                                          : 'Safe'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isExpired
                                        ? Colors.red.shade900
                                        : (daysLeft != null && daysLeft <= 30 ? Colors.deepOrange.shade900 : Colors.green.shade900),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.arrow_outward, size: 18),
                              tooltip: 'Deduct from this batch',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StockMovementPage(
                                    db: db,
                                    productId: productId,
                                    initialDirection: StockDirection.outward,
                                    initialBatchId: b.id,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Movement history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StreamBuilder<List<Movement>>(
                stream: db.movementDao.watchForProduct(productId),
                builder: (context, movementSnap) {
                  final movements = movementSnap.data ?? const <Movement>[];
                  if (movements.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No movements yet.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final m in movements)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            m.qtyDelta > 0
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: m.qtyDelta > 0
                                ? Colors.green
                                : Theme.of(context).colorScheme.error,
                          ),
                          title: Row(
                            children: [
                              Text(
                                '${m.qtyDelta > 0 ? '+' : ''}${m.qtyDelta} · ${m.reason}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (m.auditSessionId != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Audit #${m.auditSessionId}',
                                    style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              if (m.batchId != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Batch',
                                    style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            [
                              fmt.format(m.createdAt),
                              if (m.note != null && m.note!.isNotEmpty) m.note!,
                            ].join(' — '),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'stock_in',
                tooltip: 'Stock in',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockMovementPage(
                      db: db,
                      productId: productId,
                      initialDirection: StockDirection.inward,
                    ),
                  ),
                ),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'stock_out',
                tooltip: 'Stock out',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockMovementPage(
                      db: db,
                      productId: productId,
                      initialDirection: StockDirection.outward,
                    ),
                  ),
                ),
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        );
      },
    );
  }
}
