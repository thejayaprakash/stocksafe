import 'package:flutter/material.dart';

import '../data/database.dart';
import 'product_detail_page.dart';
import 'stock_movement_page.dart';

/// Low-stock screen: products where stock_qty <= low_stock_level.
/// Helps shopkeepers know what to reorder before they run out.
class LowStockPage extends StatelessWidget {
  const LowStockPage({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: db.productDao.watchLowStock(),
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
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'All stocked up!',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'No products are below their alert level.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final p = products[index];
            final deficit = p.lowStockLevel - p.stockQty;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              title: Text(p.name),
              subtitle: Text(
                'Stock: ${p.stockQty} ${p.unit}  ·  Alert at: ${p.lowStockLevel}'
                '${deficit > 0 ? '  ·  Need $deficit more' : ''}',
              ),
              trailing: FilledButton.tonal(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockMovementPage(
                      db: db,
                      productId: p.id,
                      initialDirection: StockDirection.inward,
                    ),
                  ),
                ),
                child: const Text('Restock'),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailPage(db: db, productId: p.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
