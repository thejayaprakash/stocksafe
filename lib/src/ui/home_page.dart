import 'package:flutter/material.dart';

import '../data/database.dart';
import '../services/app_localization.dart';
import 'ask_stocksafe_page.dart';
import 'low_stock_page.dart';
import 'product_detail_page.dart';
import 'product_edit_page.dart';
import 'scanner_page.dart';
import 'settings_page.dart';
import 'stock_audit_page.dart';
import 'stock_movement_page.dart';

/// Navigation shell: three tabs (Products, Low Stock, Settings) with a
/// scanner FAB. Supports real-time category filtering and dual-language localization.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex = 0;
  String _query = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChange);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocale.tr('app_name')),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.amber),
            tooltip: AppLocale.tr('ask_ai'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AskStockSafePage(db: widget.db),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: AppLocale.tr('stock_audit'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StockAuditPage(db: widget.db),
              ),
            ),
          ),
        ],
        bottom: _tabIndex == 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(104),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: SearchBar(
                        hintText: AppLocale.tr('search_hint'),
                        leading: const Icon(Icons.search),
                        onChanged: (value) => setState(() => _query = value.trim()),
                      ),
                    ),
                    _CategoryFilterBar(
                      db: widget.db,
                      selectedCategory: _selectedCategory,
                      onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
                    ),
                  ],
                ),
              )
            : null,
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: AppLocale.tr('products'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.warning_amber_outlined),
            selectedIcon: const Icon(Icons.warning_amber),
            label: AppLocale.tr('low_stock'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: AppLocale.tr('settings'),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 0:
        return _ProductListBody(
          db: widget.db,
          query: _query,
          category: _selectedCategory,
        );
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
          tooltip: AppLocale.tr('scan_barcode'),
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
          tooltip: AppLocale.tr('add_product'),
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

/// Category chip selector under search bar.
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.db,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final AppDatabase db;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: db.productDao.watchCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];
        if (categories.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(AppLocale.tr('all_categories')),
                  selected: selectedCategory == null,
                  onSelected: (_) => onCategorySelected(null),
                ),
              ),
              for (final cat in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selectedCategory == cat,
                    onSelected: (selected) => onCategorySelected(selected ? cat : null),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Product list with reactive stream supporting search and category filtering.
class _ProductListBody extends StatelessWidget {
  const _ProductListBody({
    required this.db,
    required this.query,
    this.category,
  });

  final AppDatabase db;
  final String query;
  final String? category;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: db.productDao.watchAll(query: query, category: category),
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
                  query.isEmpty && category == null
                      ? 'No products yet'
                      : 'No products match search/filter',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (query.isEmpty && category == null)
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

        return ListView.separated(
          itemCount: products.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final p = products[index];
            final lowStock = p.lowStockLevel > 0 && p.stockQty <= p.lowStockLevel;
            final isZero = p.stockQty <= 0;

            final subtitleParts = [
              if (p.category != null && p.category!.isNotEmpty) p.category!,
              if (p.sku != null && p.sku!.isNotEmpty) p.sku!,
              p.unit,
              if (p.sellPrice > 0) 'MRP: ₹${p.sellPrice.toStringAsFixed(p.sellPrice == p.sellPrice.roundToDouble() ? 0 : 2)}',
            ];

            return ListTile(
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(subtitleParts.join(' · ')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lowStock)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.warning_amber,
                        size: 20,
                        color: isZero ? Colors.red : Colors.orange,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isZero
                          ? Colors.red.withValues(alpha: 0.12)
                          : (lowStock
                              ? Colors.orange.withValues(alpha: 0.12)
                              : Colors.green.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${p.stockQty}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isZero
                            ? Colors.red
                            : (lowStock ? Colors.orange[800] : Colors.green[800]),
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailPage(db: db, productId: p.id),
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
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Colors.green),
              title: const Text('Stock In'),
              onTap: () {
                Navigator.pop(ctx);
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
              leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
              title: const Text('Stock Out'),
              onTap: () {
                Navigator.pop(ctx);
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
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Details'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductEditPage(db: db, product: p),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
