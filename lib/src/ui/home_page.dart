import 'package:flutter/material.dart';

import '../data/backup_service.dart';
import '../data/database.dart';
import '../services/app_localization.dart';
import '../services/license_service.dart';
import '../services/voice_assistant_service.dart';
import 'ask_stocksafe_page.dart';
import 'backup_page.dart';
import 'barcode_label_print_page.dart';
import 'low_stock_page.dart';
import 'product_detail_page.dart';
import 'product_edit_page.dart';
import 'scanner_page.dart';
import 'settings_page.dart';
import 'stock_audit_page.dart';
import 'stock_movement_page.dart';
import 'suppliers_page.dart';
import 'widgets/paywall_sheet.dart';
import 'widgets/voice_assistant_dialog.dart';
import '../app_scope.dart';

/// Navigation shell: three tabs (Products, Low Stock, Settings) with a
/// scanner FAB. Supports real-time category filtering, dual-language localization,
/// voice search & commands, and backup hygiene reminders.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// The live database, read through the scope rather than passed in.
  /// Uses [AppScope.read] so it is safe to call from initState; widgets that
  /// must rebuild when the connection is replaced should call AppScope.of in
  /// build instead.
  AppDatabase get _db => AppScope.read(context).db;

  int _tabIndex = 0;
  String _query = '';
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  bool _backupBannerDismissed = false;
  bool _isBackupOverdue = false;

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChange);
    _checkBackupHygiene();
  }

  Future<void> _checkBackupHygiene() async {
    final overdue = await BackupService(_db).isBackupOverdue();
    if (mounted) setState(() => _isBackupOverdue = overdue);
  }

  @override
  void dispose() {
    _searchController.dispose();
    AppLocale.instance.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  Future<void> _openVoiceAssistant() async {
    final result = await VoiceAssistantDialog.show(context);
    if (result == null || !mounted) return;

    switch (result.intent) {
      case VoiceIntentType.navigateLowStock:
        setState(() => _tabIndex = 1);
        break;
      case VoiceIntentType.navigateExpiring:
        setState(() => _tabIndex = 1);
        break;
      case VoiceIntentType.navigateAudit:
        Navigator.push(context, MaterialPageRoute(builder: (_) => StockAuditPage()));
        break;
      case VoiceIntentType.navigateBackup:
        Navigator.push(context, MaterialPageRoute(builder: (_) => BackupPage()));
        break;
      case VoiceIntentType.navigateValuation:
        setState(() => _tabIndex = 0);
        break;
      case VoiceIntentType.quickStockMovement:
        if (result.productName != null) {
          final prods = await _db.productDao.watchAll(query: result.productName!).first;
          if (prods.isNotEmpty && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StockMovementPage(
                  productId: prods.first.id,
                  initialDirection: result.isStockIn == true ? StockDirection.inward : StockDirection.outward,
                  initialQty: result.quantity,
                ),
              ),
            );
            return;
          }
        }
        final q = result.productName ?? result.searchQuery ?? result.rawTranscript;
        _searchController.text = q;
        setState(() => _query = q.trim());
        break;
      case VoiceIntentType.search:
      case VoiceIntentType.unknown:
        final q = result.searchQuery ?? result.rawTranscript;
        _searchController.text = q;
        setState(() => _query = q.trim());
        break;
    }
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
                builder: (_) => AskStockSafePage(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: AppLocale.tr('stock_audit'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StockAuditPage(),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Operations',
            onSelected: (val) {
              if (val == 'suppliers') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SuppliersPage()),
                );
              } else if (val == 'labels') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BarcodeLabelPrintPage()),
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'suppliers',
                child: Row(
                  children: [
                    const Icon(Icons.contact_phone_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(AppLocale.tr('suppliers')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'labels',
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2, size: 20),
                    const SizedBox(width: 10),
                    Text(AppLocale.tr('barcode_label_printing')),
                  ],
                ),
              ),
            ],
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
                        controller: _searchController,
                        hintText: AppLocale.tr('search_hint'),
                        leading: const Icon(Icons.search),
                        trailing: [
                          IconButton(
                            icon: const Icon(Icons.mic, color: Colors.blue),
                            tooltip: 'Voice Search',
                            onPressed: _openVoiceAssistant,
                          ),
                        ],
                        onChanged: (value) => setState(() => _query = value.trim()),
                      ),
                    ),
                    _CategoryFilterBar(
                      db: _db,
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
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 0:
        return _ProductListBody(
          db: _db,
          query: _query,
          category: _selectedCategory,
          showBackupReminder: _isBackupOverdue && !_backupBannerDismissed,
          onDismissBackupBanner: () => setState(() => _backupBannerDismissed = true),
        );
      case 1:
        return LowStockPage();
      case 2:
        return SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildFab(BuildContext context) {
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
              builder: (_) => ScannerPage(),
            ),
          ),
          child: const Icon(Icons.qr_code_scanner),
        ),
        const SizedBox(height: 8),
        // Add product FAB
        FloatingActionButton(
          heroTag: 'add',
          tooltip: AppLocale.tr('add_product'),
          onPressed: () async {
            final canAdd = await LicenseService(_db).canAddProduct();
            if (!context.mounted) return;
            if (!canAdd) {
              final unlocked = await PaywallSheet.show(context);
              if (unlocked != true) return;
            }
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductEditPage(),
              ),
            );
          },
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
    this.showBackupReminder = false,
    this.onDismissBackupBanner,
  });

  final AppDatabase db;
  final String query;
  final String? category;
  final bool showBackupReminder;
  final VoidCallback? onDismissBackupBanner;

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

        return Column(
          children: [
            if (showBackupReminder && query.isEmpty && category == null)
              _BackupReminderBanner(
                db: db,
                onDismiss: onDismissBackupBanner,
              ),
            if (query.isEmpty && category == null)
              _InventoryValuationCard(db: db),
            Expanded(
              child: ListView.separated(
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
                  builder: (_) => ProductDetailPage(productId: p.id),
                ),
              ),
              onLongPress: () => _showActions(context, p),
            );
          },
        ),
      ),
    ],
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
                    builder: (_) => ProductEditPage(product: p),
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

/// Collapsible Inventory Valuation Banner showing live Cost, MRP and Margin.
class _InventoryValuationCard extends StatefulWidget {
  const _InventoryValuationCard({required this.db});
  final AppDatabase db;

  @override
  State<_InventoryValuationCard> createState() => _InventoryValuationCardState();
}

class _InventoryValuationCardState extends State<_InventoryValuationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<InventoryValuationSummary>(
      stream: widget.db.productDao.watchInventoryValuation(),
      builder: (context, snapshot) {
        final val = snapshot.data;
        if (val == null || val.totalProducts == 0) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          elevation: 0,
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        AppLocale.tr('inventory_valuation'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        '₹${val.totalCostValue.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                    ],
                  ),
                  if (_expanded) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricCol(AppLocale.tr('retail_value'), '₹${val.totalRetailValue.toStringAsFixed(0)}'),
                        _metricCol(AppLocale.tr('est_margin'), '+₹${val.potentialProfit.toStringAsFixed(0)} (${val.marginPercent.toStringAsFixed(1)}%)'),
                        _metricCol(AppLocale.tr('total_units'), '${val.totalUnits}'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _metricCol(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}

/// Subtle actionable reminder for regular backup hygiene.
class _BackupReminderBanner extends StatelessWidget {
  const _BackupReminderBanner({required this.db, this.onDismiss});
  final AppDatabase db;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Colors.orange, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Backup Recommended: Protect data against device damage.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.brown),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BackupPage()),
            ),
            child: const Text('Backup'),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onDismiss,
              tooltip: 'Dismiss',
            ),
        ],
      ),
    );
  }
}
