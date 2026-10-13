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
                          title: Text(
                            '${m.qtyDelta > 0 ? '+' : ''}${m.qtyDelta} · ${m.reason}',
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
