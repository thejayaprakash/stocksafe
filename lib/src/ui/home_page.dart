import 'package:flutter/material.dart';

import '../data/database.dart';
import 'movement_reason.dart';
import 'pro_gate.dart';
import '../services/app_localization.dart';
import '../services/diagnostic_service.dart';
import '../services/license_service.dart';
import '../services/voice_assistant_service.dart';
import 'ask_stocksafe_page.dart';
import 'backup_page.dart';
import 'low_stock_page.dart';
import 'more_page.dart';
import 'product_detail_page.dart';
import 'product_edit_page.dart';
import 'scanner_page.dart';
import 'stock_audit_page.dart';
import 'stock_movement_page.dart';
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
    // Deferred to after the first frame: taking a snapshot copies the whole
    // database file, and nothing about it should delay the app opening.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final backup = AppScope.read(context).backup;

      // Replaces the unconditional cache rebuild that used to block startup:
      // one grouped query, and a repair only if it finds something wrong.
      final mismatches =
          await DiagnosticService.instance.auditLedgerIntegrity(_db);
      if (mismatches.isNotEmpty) {
        DiagnosticService.instance.log(
          'Repairing ${mismatches.length} stock cache mismatches on launch',
          level: 'WARN',
        );
        await _db.rebuildAllStockCaches();
      }

      if (!mounted) return;

      // "On open, if a day has passed" rather than a background scheduler —
      // a shopkeeper opens this app most days, and it needs no WorkManager
      // dependency or background-execution permission.
      await backup.snapshotIfDue();

      if (!mounted) return;
      final overdue = await backup.isBackupOverdue();
      if (mounted) setState(() => _isBackupOverdue = overdue);
    });
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
    if (!await requirePro(context, _db)) return;
    if (!mounted) return;
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

  PreferredSizeWidget? _buildAppBar() {
    if (_tabIndex >= 3) return null; // StockAuditPage and MorePage manage their own AppBars

    if (_tabIndex == 1) {
      return AppBar(
        title: Text(AppLocale.tr('products')),
        bottom: PreferredSize(
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
        ),
      );
    }

    // Tab 0: Home Dashboard
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocale.tr('app_name'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Text(
            'Offline Inventory & Audit',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.auto_awesome, color: Colors.amber),
          tooltip: AppLocale.tr('ask_ai'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AskStockSafePage()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.security_rounded, color: Color(0xFF10B981)),
          tooltip: 'Backup & Restore',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BackupPage()),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScannerPage()),
            );
            return;
          }
          setState(() => _tabIndex = i);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: AppLocale.tr('products'),
          ),
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          const NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Stock Count',
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 0:
        return _DashboardHomeBody(
          db: _db,
          onNavigateToProducts: () => setState(() => _tabIndex = 1),
          onNavigateToAudit: () => setState(() => _tabIndex = 3),
          onNavigateToLowStock: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LowStockPage()),
          ),
          showBackupReminder: _isBackupOverdue && !_backupBannerDismissed,
          onDismissBackupBanner: () => setState(() => _backupBannerDismissed = true),
        );
      case 1:
        return _ProductListBody(
          db: _db,
          query: _query,
          category: _selectedCategory,
          showBackupReminder: false,
          onDismissBackupBanner: () {},
        );
      case 3:
        return const StockAuditPage();
      case 4:
        return const MorePage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildFab(BuildContext context) {
    if (_tabIndex != 1) return null;
    return FloatingActionButton(
      heroTag: 'add_product',
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
            builder: (_) => const ProductEditPage(),
          ),
        );
      },
      child: const Icon(Icons.add),
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
class _ProductListBody extends StatefulWidget {
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
  State<_ProductListBody> createState() => _ProductListBodyState();
}

class _ProductListBodyState extends State<_ProductListBody> {
  /// Rows fetched per step. The list used to call watchAll() with its default
  /// limit of 100 and never advance, so a shop with 400 products saw 100 of
  /// them, alphabetically, with no indication the rest existed — they were in
  /// the database, counted in the valuation, and invisible. For someone who
  /// paid for "unlimited products" that is indistinguishable from the data
  /// loss this app is sold against.
  static const int _pageSize = 60;

  /// A growing window rather than an offset.
  ///
  /// The list is backed by a live query: rows can be inserted or soft-deleted
  /// while the user scrolls, and offset paging over a shifting result set
  /// silently skips and repeats items. Re-querying `0..limit` is always
  /// self-consistent, and with the index on product.name it stays cheap.
  int _limit = _pageSize;

  final ScrollController _scrollController = ScrollController();
  bool _mayHaveMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _ProductListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new search or filter is a new result set; start the window again.
    if (oldWidget.query != widget.query ||
        oldWidget.category != widget.category) {
      _limit = _pageSize;
      _mayHaveMore = true;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_mayHaveMore || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      setState(() => _limit += _pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final query = widget.query;
    final category = widget.category;
    final showBackupReminder = widget.showBackupReminder;
    final onDismissBackupBanner = widget.onDismissBackupBanner;

    return StreamBuilder<List<Product>>(
      stream: db.productDao
          .watchAll(query: query, category: category, limit: _limit),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data ?? const <Product>[];
        // Fewer rows than asked for means the end has been reached.
        _mayHaveMore = products.length >= _limit;

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
                controller: _scrollController,
                // One extra row for the "loading more" footer.
                itemCount: products.length + (_mayHaveMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index >= products.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
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

/// Simplified Beta 1.0 Dashboard: Answers the 3 core operational questions:
/// 1. What needs my attention? (Low-stock count & verified backup hygiene)
/// 2. What stock needs updating? (Recent movement activity stream)
/// 3. What can I do next? (Tactile 48dp Quick Action CTAs)
class _DashboardHomeBody extends StatelessWidget {
  const _DashboardHomeBody({
    required this.db,
    required this.onNavigateToProducts,
    required this.onNavigateToAudit,
    required this.onNavigateToLowStock,
    required this.showBackupReminder,
    required this.onDismissBackupBanner,
  });

  final AppDatabase db;
  final VoidCallback onNavigateToProducts;
  final VoidCallback onNavigateToAudit;
  final VoidCallback onNavigateToLowStock;
  final bool showBackupReminder;
  final VoidCallback onDismissBackupBanner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── 1. WHAT NEEDS MY ATTENTION? ──
        if (showBackupReminder)
          Card(
            color: Colors.amber.shade100,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.shield_outlined, color: Colors.brown),
              title: Text(
                AppLocale.tr('backup_reminder_title'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown),
              ),
              subtitle: Text(
                AppLocale.tr('backup_reminder_body'),
                style: const TextStyle(fontSize: 11, color: Colors.brown),
              ),
              trailing: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupPage())),
                child: Text(AppLocale.tr('backup_now')),
              ),
            ),
          ),

        StreamBuilder<List<Product>>(
          stream: db.productDao.watchLowStock(),
          builder: (context, snapshot) {
            final lowStock = snapshot.data ?? [];
            if (lowStock.isNotEmpty) {
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                color: const Color(0xFFFEF3C7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade400),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.amber.shade200, shape: BoxShape.circle),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 24),
                  ),
                  title: Text(
                    '${lowStock.length} Products Need Reordering',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF78350F)),
                  ),
                  subtitle: Text(
                    'Stock is below reorder threshold. Tap to review restock quantities.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF78350F)),
                  onTap: onNavigateToLowStock,
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All stock levels optimal · Zero critical shortages',
                      style: TextStyle(color: Color(0xFF065F46), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // ── 2. WHAT CAN I DO NEXT? (PRIMARY ACTIONS) ──
        _buildSectionTitle(theme, 'QUICK OPERATIONAL ACTIONS'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context,
                icon: Icons.qr_code_scanner,
                iconColor: Colors.white,
                bgColor: const Color(0xFF0F172A),
                textColor: Colors.white,
                title: 'Scan & Adjust',
                subtitle: 'Single-SKU Barcode',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerPage())),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                context,
                icon: Icons.fact_check_outlined,
                iconColor: const Color(0xFF047857),
                bgColor: const Color(0xFFECFDF5),
                textColor: const Color(0xFF064E3B),
                title: 'Physical Audit',
                subtitle: 'Cycle-Count Reconcile',
                onTap: onNavigateToAudit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildFullWidthAction(
          context,
          icon: Icons.add_circle_outline,
          title: 'Add New Product',
          subtitle: 'Enter barcode or manual SKU for unbarcoded Kirana goods',
          onTap: () async {
            final canAdd = await LicenseService(db).canAddProduct();
            if (!context.mounted) return;
            if (!canAdd) {
              final unlocked = await PaywallSheet.show(context);
              if (unlocked != true) return;
            }
            if (!context.mounted) return;
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductEditPage()));
          },
        ),
        const SizedBox(height: 24),

        // ── 3. WHAT STOCK NEEDS UPDATING? (RECENT ACTIVITY) ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(theme, 'RECENT STOCK ACTIVITY'),
            TextButton(
              onPressed: onNavigateToProducts,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('View All', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        StreamBuilder<List<Movement>>(
          stream: db.movementDao.watchRecent(limit: 5),
          builder: (context, snapshot) {
            final movements = snapshot.data ?? [];
            if (movements.isEmpty) {
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    children: const [
                      Icon(Icons.history_outlined, size: 36, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No movements logged yet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      SizedBox(height: 2),
                      Text(
                        'Scan a barcode or add stock to see movement history here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final m in movements)
                  FutureBuilder<Product?>(
                    future: db.productDao.getById(m.productId),
                    builder: (context, pSnap) {
                      final pName = pSnap.data?.name ?? 'Product #${m.productId}';
                      final isPositive = m.qtyDelta > 0;
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: isPositive
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFFEF4444).withValues(alpha: 0.15),
                            child: Icon(
                              isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              size: 14,
                              color: isPositive ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                            ),
                          ),
                          title: Text(pName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(
                            '${readableMovementReason(m.reason)} · ${_formatTimestamp(m.createdAt)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            isPositive ? '+${m.qtyDelta}' : '${m.qtyDelta}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isPositive ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${dt.day}/${dt.month}';
  }

  static Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        letterSpacing: 0.8,
      ),
    );
  }

  static Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color textColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(height: 10),
              Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildFullWidthAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
