import 'package:flutter/material.dart';

import '../data/database.dart';
import 'low_stock_page.dart';
import 'product_detail_page.dart';
import 'product_edit_page.dart';
import 'scanner_page.dart';
import 'settings_page.dart';
import 'stock_movement_page.dart';

/// Navigation shell: three tabs (Products, Low Stock, Settings) with a
/// scanner FAB. State is restored from the DB on every launch — no
/// in-memory truth anywhere.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StockSafe'),
        bottom: _tabIndex == 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SearchBar(
                    hintText: 'Search name, SKU or barcode',
                    leading: const Icon(Icons.search),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Low Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 0:
        return _ProductListBody(db: widget.db, query: _query);
      case 1:
        return LowStockPage(db: widget.db);
      case 2:
        return SettingsPage(db: widget.db);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildFab() {
    if (_tabIndex != 0) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Scanner FAB
        FloatingActionButton.small(
          heroTag: 'scan',
          tooltip: 'Scan barcode',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScannerPage(db: widget.db),
            ),
          ),
          child: const Icon(Icons.qr_code_scanner),
        ),
        const SizedBox(height: 8),
        // Add product FAB
        FloatingActionButton(
          heroTag: 'add',
          tooltip: 'Add product',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductEditPage(db: widget.db),
            ),
          ),
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// Product list with reactive stream. Extracted so the list survives
/// tab switches without losing scroll position needlessly.
class _ProductListBody extends StatelessWidget {
  const _ProductListBody({required this.db, required this.query});

  final AppDatabase db;
  final String query;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: db.productDao.watchAll(query: query),
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
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  query.isEmpty
                      ? 'No products yet'
                      : 'No products match "$query"',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (query.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Tap + to add your first product, or scan a barcode.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
            final lowStock =
                p.lowStockLevel > 0 && p.stockQty <= p.lowStockLevel;
            return ListTile(
              title: Text(p.name),
              subtitle: Text(
                [
                  if (p.sku != null && p.sku!.isNotEmpty) p.sku!,
                  p.unit,
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lowStock)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.warning_amber,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Text(
                    '${p.stockQty}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: lowStock
                          ? Theme.of(context).colorScheme.error
                          : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProductDetailPage(db: db, productId: p.id),
                ),
              ),
              onLongPress: () => _showActions(context, p),
            );
          },
        );
      },
    );
  }

  void _showActions(BuildContext context, Product p) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Stock in'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockMovementPage(
                      db: db,
                      productId: p.id,
                      initialDirection: StockDirection.inward,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Stock out'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockMovementPage(
                      db: db,
                      productId: p.id,
                      initialDirection: StockDirection.outward,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductEditPage(db: db, product: p),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Delete (recoverable)'),
              onTap: () async {
                Navigator.pop(context);
                await db.productDao.softDelete(p.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Product moved to trash. Restorable from backup.'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
