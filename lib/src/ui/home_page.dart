
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import 'money_format.dart';
import 'pro_gate.dart';
import '../services/app_localization.dart';
import '../services/diagnostic_service.dart';
import '../services/license_service.dart';
import '../services/theme_service.dart';
import '../services/voice_assistant_service.dart';
import 'backup_page.dart';
import 'low_stock_page.dart';
import 'more_page.dart';
import 'product_detail_page.dart';
import 'product_edit_page.dart';
import 'scanner_page.dart';
import 'settings_page.dart';
import 'stock_audit_page.dart';
import 'stock_movement_page.dart';
import 'widgets/bulk_actions.dart';
import 'widgets/favourite_button.dart';
import 'widgets/floating_wave_nav_bar.dart';
import 'widgets/product_avatar.dart';
import 'widgets/product_filter_sheet.dart';
import 'widgets/product_grid_card.dart';
import 'widgets/paywall_sheet.dart';
import 'widgets/voice_assistant_dialog.dart';
import 'widgets/admob_native_section.dart';
import 'widgets/dashboard_inventory_overview.dart';
import 'widgets/dashboard_stock_health.dart';
import 'widgets/dashboard_top_products.dart';
import '../services/reward_config.dart';
import '../services/rewarded_ad_platform.dart';
import '../services/rewarded_ad_service.dart';
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

  /// Catalogue view state. It lives here rather than in the list body so the
  /// app bar can switch into selection mode and "select all" can re-run the
  /// very query the list is showing — selecting everything the filters
  /// match, not merely the page that happens to be loaded.
  /// Everything the catalogue is narrowed by, apart from the search text
  /// and the sort order. One value so the filter sheet can be handed the
  /// whole set and give back whatever the user settled on.
  ProductFilters _filters = const ProductFilters();

  ProductSort _sort = ProductSort.recentlyUpdated;
  bool _grid = false;

  final Set<int> _selected = <int>{};
  bool _selectionMode = false;

  /// How many products the current filters match, for "Select all (n)".
  int _matchingCount = 0;
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
      // These indices were written for the old three-tab layout, where 1 was
      // Low Stock. After the rework 1 is Products and low stock is a route,
      // so "show me low stock" quietly opened the catalogue instead.
      case VoiceIntentType.navigateLowStock:
      case VoiceIntentType.navigateExpiring:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LowStockPage()),
        );
        break;
      case VoiceIntentType.navigateAudit:
        Navigator.push(context, MaterialPageRoute(builder: (_) => StockAuditPage()));
        break;
      case VoiceIntentType.navigateBackup:
        Navigator.push(context, MaterialPageRoute(builder: (_) => BackupPage()));
        break;
      case VoiceIntentType.navigateValuation:
        // The valuation card lives on the product list, not the dashboard.
        setState(() => _tabIndex = 1);
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

  Future<void> _openFilterSheet() async {
    final chosen = await showProductFilterSheet(
      context: context,
      db: _db,
      current: _filters,
    );
    // Null means the sheet was dismissed, which must change nothing.
    if (chosen == null || !mounted) return;
    setState(() => _filters = chosen);
  }

  void _enterSelection(int productId) {
    setState(() {
      _selectionMode = true;
      _selected
        ..clear()
        ..add(productId);
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _toggleSelected(int productId) {
    setState(() {
      if (!_selected.remove(productId)) _selected.add(productId);
      // Unticking the last product leaves selection mode rather than a bar
      // of actions that would all do nothing.
      if (_selected.isEmpty) _selectionMode = false;
    });
  }

  Future<void> _toggleSelectAll() async {
    if (_selected.length >= _matchingCount && _matchingCount > 0) {
      setState(() => _selected.clear());
      if (_selected.isEmpty) setState(() => _selectionMode = false);
      return;
    }
    // Everything the filters match, which is not the same as everything on
    // screen: the list pages as it scrolls.
    final all = await _db.productDao.idsMatching(
      query: _query,
      categories: _filters.categories,
      supplierId: _filters.supplierId,
      status: _filters.status,
      favouritesOnly: _filters.favouritesOnly,
    );
    if (!mounted) return;
    setState(() => _selected
      ..clear()
      ..addAll(all));
  }

  /// Runs a bulk action, then reports what it did and leaves selection mode.
  Future<void> _runBulk(
    Future<void> Function(List<int> ids) action,
    String Function(int count) describe,
  ) async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(ids);
      if (!mounted) return;
      _exitSelection();
      showBulkResult(context, describe(ids.length));
    } catch (error) {
      DiagnosticService.instance.log(
        'Bulk action over ${ids.length} products failed: $error',
        level: 'ERROR',
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Could not finish that: $error')),
      );
    }
  }

  Future<void> _bulkAdjustStock() async {
    final adjustment = await askBulkAdjustment(context, _selected.length);
    if (adjustment == null || !mounted) return;
    await _runBulk(
      (ids) => _db.movementDao.recordMovementForAll(
        productIds: ids,
        qtyDelta: adjustment.qtyDelta,
        reason: adjustment.reason,
      ),
      (count) => adjustment.qtyDelta > 0
          ? 'Added ${adjustment.qtyDelta} to $count products'
          : 'Removed ${-adjustment.qtyDelta} from $count products',
    );
  }

  Future<void> _bulkUpdatePrice() async {
    final price = await askBulkPrice(context, _selected.length);
    if (price == null || !mounted) return;
    await _runBulk(
      (ids) => _db.productDao.setSellPriceMany(ids, price),
      (count) => 'Price set on $count products',
    );
  }

  Future<void> _bulkChangeCategory() async {
    final choice = await askBulkCategory(context, _db, _selected.length);
    if (choice == null || !mounted) return;
    await _runBulk(
      (ids) => _db.productDao.setCategoryMany(ids, choice.category),
      (count) => choice.category == null
          ? 'Category cleared on $count products'
          : 'Moved $count products to ${choice.category}',
    );
  }

  Future<void> _bulkDelete() async {
    final confirmed = await confirmBulkDelete(context, _selected.length);
    if (!confirmed || !mounted) return;
    await _runBulk(
      (ids) => _db.productDao.softDeleteMany(ids),
      (count) => 'Deleted $count products',
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_selectionMode) {
      return SelectionAppBar(
        count: _selected.length,
        total: _matchingCount,
        allSelected:
            _matchingCount > 0 && _selected.length >= _matchingCount,
        onCancel: _exitSelection,
        onToggleAll: _toggleSelectAll,
      );
    }

    if (_tabIndex >= 3) return null; // StockAuditPage and MorePage manage their own AppBars

    if (_tabIndex == 1) {
      final palette = context.palette;
      return AppBar(
        toolbarHeight: 64,
        title: StreamBuilder<ProductStatusCounts>(
          stream: _db.productDao.watchStatusCounts(),
          builder: (context, snapshot) {
            final counts = snapshot.data;
            final total = counts?.all ?? 0;
            final low = counts?.low ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocale.tr('products'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 21,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total Products · $low Low Stock',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          _HeaderIconButton(
            icon: Icons.tune_outlined,
            tooltip: 'Filter products',
            onPressed: _openFilterSheet,
          ),
          _HeaderIconButton(
            icon: Icons.qr_code_scanner_rounded,
            tooltip: 'Scan a barcode',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScannerPage()),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ProductSearchField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              onVoice: _openVoiceAssistant,
            ),
          ),
        ),
      );
    }

    // Tab 0: Home Dashboard
    final palette = context.palette;
    return AppBar(
      toolbarHeight: 66,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Stock',
                  style: TextStyle(color: palette.textPrimary),
                ),
                TextSpan(
                  text: 'Safe',
                  style: TextStyle(color: palette.primary),
                ),
              ],
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 21,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            'Offline Inventory & Audit',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
      actions: [
        // The bell carries a dot only when something is genuinely waiting.
        // There is no notification centre behind it: the one thing this app
        // ever needs to raise is "you are about to run out", so it opens the
        // low-stock list and is silent when that list is empty.
        StreamBuilder<List<Product>>(
          stream: _db.productDao.watchLowStock(),
          builder: (context, snapshot) {
            final waiting = snapshot.data?.length ?? 0;
            return _HeaderIconButton(
              icon: Icons.notifications_none_rounded,
              showBadge: waiting > 0,
              tooltip: waiting > 0
                  ? '$waiting products need reordering'
                  : 'Nothing needs attention',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LowStockPage()),
              ),
            );
          },
        ),
        _HeaderIconButton(
          icon: Icons.settings_outlined,
          tooltip: AppLocale.tr('settings'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<int>(_tabIndex),
          child: _buildBody(),
        ),
      ),
      bottomNavigationBar: _selectionMode
          ? BulkActionBar(
              count: _selected.length,
              onAdjustStock: _bulkAdjustStock,
              onUpdatePrice: _bulkUpdatePrice,
              onChangeCategory: _bulkChangeCategory,
              onDelete: _bulkDelete,
            )
          : FloatingWaveNavBar(
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
        items: [
          const WaveNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
          ),
          WaveNavItem(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2_rounded,
            label: AppLocale.tr('products'),
          ),
          const WaveNavItem(
            icon: Icons.qr_code_scanner_rounded,
            selectedIcon: Icons.qr_code_scanner_rounded,
            label: 'Scan',
          ),
          const WaveNavItem(
            icon: Icons.check_box_outlined,
            selectedIcon: Icons.check_box_rounded,
            label: 'Stock Count',
          ),
          const WaveNavItem(
            icon: Icons.more_horiz_rounded,
            selectedIcon: Icons.more_horiz_rounded,
            label: 'More',
          ),
        ],
      ),
      floatingActionButton: _selectionMode ? null : _buildFab(context),
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
          filters: _filters,
          sort: _sort,
          grid: _grid,
          selectionMode: _selectionMode,
          selectedIds: _selected,
          onFiltersChanged: (filters) => setState(() => _filters = filters),
          onOpenFilterSheet: _openFilterSheet,
          onSortChanged: (sort) => setState(() => _sort = sort),
          onLayoutChanged: (grid) => setState(() => _grid = grid),
          onToggleSelected: _toggleSelected,
          onEnterSelection: _enterSelection,
          onMatchingCountChanged: (count) {
            // Reported from the stream during build, so the update waits for
            // the frame to finish rather than calling setState inside it.
            if (count == _matchingCount) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _matchingCount = count);
            });
          },
        );
      case 3:
        return const StockAuditPage();
      case 4:
        return const MorePage();
      default:
        // Scan (index 2) opens as a route rather than a tab, so no index
        // should land here. If one ever does, show the dashboard: an empty
        // box looks exactly like the app has crashed.
        return _DashboardHomeBody(
          db: _db,
          onNavigateToProducts: () => setState(() => _tabIndex = 1),
          onNavigateToAudit: () => setState(() => _tabIndex = 3),
          onNavigateToLowStock: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LowStockPage()),
          ),
          showBackupReminder: false,
          onDismissBackupBanner: () {},
        );
    }
  }

  Widget? _buildFab(BuildContext context) {
    if (_tabIndex != 1) return null;
    final palette = context.palette;
    return FloatingActionButton(
      heroTag: 'add_product',
      tooltip: AppLocale.tr('add_product'),
      backgroundColor: palette.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
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
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
    );
  }
}

/// A circular, softly filled header button, with an optional alert dot.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.showBadge = false,
  });


  final IconData icon;
  final String tooltip;

  /// Null disables the button, which is how the catalogue hides "select
  /// products" while there is nothing to select.
  final VoidCallback? onPressed;

  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: palette.elevatedSurface,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: onPressed == null
                        ? palette.textDisabled
                        : palette.textSecondary,
                  ),
                  if (showBadge)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: palette.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.elevatedSurface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rounded search field at the top of the catalogue.
class _ProductSearchField extends StatelessWidget {
  const _ProductSearchField({
    required this.controller,
    required this.onChanged,
    required this.onVoice,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 14, color: palette.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: palette.elevatedSurface,
        hintText: AppLocale.tr('search_hint'),
        hintStyle: TextStyle(fontSize: 14, color: palette.textTertiary),
        prefixIcon: Icon(Icons.search_rounded, size: 21, color: palette.textTertiary),
        suffixIcon: IconButton(
          icon: Icon(Icons.mic_none_rounded, size: 21, color: palette.primary),
          tooltip: 'Voice search',
          onPressed: onVoice,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
      ),
    );
  }
}


/// The catalogue: a live, paged product list with search, category filter,
/// a sort order and a list/grid switch.
class _ProductListBody extends StatefulWidget {
  const _ProductListBody({
    required this.db,
    required this.query,
    required this.filters,
    required this.sort,
    required this.grid,
    required this.selectionMode,
    required this.selectedIds,
    required this.onFiltersChanged,
    required this.onOpenFilterSheet,
    required this.onSortChanged,
    required this.onLayoutChanged,
    required this.onToggleSelected,
    required this.onEnterSelection,
    required this.onMatchingCountChanged,
  });

  final AppDatabase db;
  final String query;
  final ProductFilters filters;
  final ProductSort sort;
  final bool grid;

  final bool selectionMode;
  final Set<int> selectedIds;

  final ValueChanged<ProductFilters> onFiltersChanged;
  final VoidCallback onOpenFilterSheet;
  final ValueChanged<ProductSort> onSortChanged;
  final ValueChanged<bool> onLayoutChanged;
  final ValueChanged<int> onToggleSelected;
  final ValueChanged<int> onEnterSelection;

  /// How many products the filters currently match, for "Select all (n)".
  final ValueChanged<int> onMatchingCountChanged;

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
  /// self-consistent, and every sort order ends in the row id so it stays
  /// total.
  int _limit = _pageSize;

  final ScrollController _scrollController = ScrollController();
  bool _mayHaveMore = true;

  /// The live query, held rather than rebuilt in `build`.
  ///
  /// Calling `watchAll(...)` from `build` hands StreamBuilder a new stream
  /// object every time anything on the page rebuilds. It drops the old
  /// subscription, opens a fresh one, and passes through `waiting` with no
  /// data on the way — so the catalogue flickers back to a spinner on every
  /// unrelated rebuild, and a rebuild triggered by that spinner never
  /// settles. Recreated only when the query itself changes.
  Stream<List<Product>>? _products;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _openQuery();
  }

  /// Opens the query for the current filters, sort and window.
  void _openQuery() {
    _products = widget.db.productDao.watchAll(
      query: widget.query,
      categories: widget.filters.categories,
      supplierId: widget.filters.supplierId,
      status: widget.filters.status,
      favouritesOnly: widget.filters.favouritesOnly,
      sort: widget.sort,
      limit: _limit,
    );
  }

  @override
  void didUpdateWidget(covariant _ProductListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new search, filter or order is a new result set, so the paging
    // window starts again. Without this the first page would be in the new
    // order and the rest whatever the old one had already fetched.
    if (oldWidget.query != widget.query ||
        oldWidget.filters != widget.filters ||
        oldWidget.sort != widget.sort) {
      _limit = _pageSize;
      _mayHaveMore = true;
      _openQuery();
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
      setState(() {
        _limit += _pageSize;
        _openQuery();
      });
    }
  }

  Future<void> _navigateToAddProduct() async {
    final canAdd = await LicenseService(widget.db).canAddProduct();
    if (!mounted) return;
    if (!canAdd) {
      final unlocked = await PaywallSheet.show(context);
      if (unlocked != true) return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductEditPage()),
    );
  }

  void _navigateToScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unfiltered = widget.query.isEmpty && widget.filters.isEmpty;

    // The status chips stay on screen whatever the list below them shows.
    // Filtering down to nothing and losing the control that did it leaves
    // the user with an empty screen and no way back.
    return Column(
      children: [
        _StatusFilterBar(
          db: widget.db,
          status: widget.filters.status,
          favouritesOnly: widget.filters.favouritesOnly,
          onChanged: (status) => widget.onFiltersChanged(
            widget.filters.copyWith(status: status),
          ),
          onFavouritesOnlyChanged: (only) => widget.onFiltersChanged(
            widget.filters.copyWith(favouritesOnly: only),
          ),
        ),
        const SizedBox(height: 10),
        if (!widget.selectionMode)
          _InventoryValuationCard(db: widget.db),
        if (!widget.selectionMode)
          _ListControls(
            sort: widget.sort,
            onSortChanged: widget.onSortChanged,
            grid: widget.grid,
            onLayoutChanged: widget.onLayoutChanged,
            activeFilterCount: widget.filters.activeCount,
            onOpenFilterSheet: widget.onOpenFilterSheet,
          ),
        Expanded(
          child: StreamBuilder<List<Product>>(
            stream: _products,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = snapshot.data ?? const <Product>[];
              // Fewer rows than asked for means the end has been reached.
              _mayHaveMore = products.length >= _limit;
              widget.onMatchingCountChanged(products.length);

              if (products.isEmpty) {
                return _EmptyCatalogue(
                  filtered: !unfiltered,
                  onClearFilters: widget.filters.isEmpty && widget.query.isEmpty
                      ? null
                      : () => widget.onFiltersChanged(const ProductFilters()),
                  onAddProduct: _navigateToAddProduct,
                  onScanBarcode: _navigateToScanner,
                );
              }

              return widget.grid && !widget.selectionMode
                  ? _ProductGrid(
                      products: products,
                      controller: _scrollController,
                      loadingMore: _mayHaveMore,
                      onOpen: _open,
                      onActions: _showActions,
                    )
                  : _ProductList(
                      products: products,
                      controller: _scrollController,
                      loadingMore: _mayHaveMore,
                      selectionMode: widget.selectionMode,
                      selectedIds: widget.selectedIds,
                      onOpen: _open,
                      onActions: _showActions,
                      onToggleSelected: widget.onToggleSelected,
                      onEnterSelection: widget.onEnterSelection,
                    );
            },
          ),
        ),
      ],
    );
  }

  void _open(Product p) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailPage(productId: p.id)),
      );

  void _showActions(Product p) {
    final palette = context.palette;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${p.stockQty} ${p.unit} in stock'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: palette.success),
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
              leading: Icon(Icons.remove_circle_outline, color: palette.error),
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
                  MaterialPageRoute(builder: (_) => ProductEditPage(product: p)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// In Stock / Low Stock / Out of Stock, each carrying its own count.
class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.db,
    required this.status,
    required this.favouritesOnly,
    required this.onChanged,
    required this.onFavouritesOnlyChanged,
  });

  final AppDatabase db;
  final ProductStockStatus status;
  final bool favouritesOnly;
  final ValueChanged<ProductStockStatus> onChanged;
  final ValueChanged<bool> onFavouritesOnlyChanged;

  static const _options = [
    (ProductStockStatus.any, 'All', Icons.layers_rounded),
    (ProductStockStatus.low, 'Low Stock', Icons.warning_amber_rounded),
    (
      ProductStockStatus.outOfStock,
      'Out of Stock',
      Icons.remove_circle_outline_rounded,
    ),
  ];

  Color _accentFor(ProductStockStatus value, AppPalette palette) =>
      switch (value) {
        ProductStockStatus.any => palette.primary,
        ProductStockStatus.inStock => palette.success,
        ProductStockStatus.low => palette.warning,
        ProductStockStatus.outOfStock => palette.error,
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return StreamBuilder<ProductStatusCounts>(
      stream: db.productDao.watchStatusCounts(),
      builder: (context, snapshot) {
        final counts = snapshot.data;

        return SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            children: [
              for (final (value, label, icon) in _options)
                _StatusChip(
                  label: label,
                  icon: icon,
                  count: counts?.forStatus(value),
                  accent: _accentFor(value, palette),
                  selected: status == value,
                  onTap: () => onChanged(value),
                ),
              StreamBuilder<int>(
                stream: db.productDao.watchFavouriteCount(),
                builder: (context, snapshot) => _StatusChip(
                  label: 'Favourites',
                  icon: favouritesOnly
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  count: snapshot.data,
                  accent: palette.error,
                  selected: favouritesOnly,
                  onTap: () => onFavouritesOnlyChanged(!favouritesOnly),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One status chip.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final int? count;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(20);

    final Color bgColor = selected
        ? palette.primary
        : (isDark ? const Color(0xFF151E2E) : palette.cardSurface);

    final Color fgColor = selected
        ? Colors.white
        : (isDark ? const Color(0xFF94A3B8) : palette.textSecondary);

    final Color iconColor = selected ? Colors.white : accent;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: bgColor,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? palette.primary
                    : (isDark
                        ? const Color(0xFF334155).withValues(alpha: 0.7)
                        : palette.border),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: iconColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fgColor,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    '($count)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.9)
                          : (isDark ? const Color(0xFF94A3B8) : palette.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sort order on the left, list/grid switch on the right.
class _ListControls extends StatelessWidget {
  const _ListControls({
    required this.sort,
    required this.onSortChanged,
    required this.grid,
    required this.onLayoutChanged,
    required this.activeFilterCount,
    required this.onOpenFilterSheet,
  });

  final ProductSort sort;
  final ValueChanged<ProductSort> onSortChanged;
  final bool grid;
  final ValueChanged<bool> onLayoutChanged;
  final int activeFilterCount;
  final VoidCallback onOpenFilterSheet;

  static String label(ProductSort sort) => switch (sort) {
        ProductSort.nameAsc => 'Name (A–Z)',
        ProductSort.recentlyUpdated => 'Recently Updated',
        ProductSort.stockLowFirst => 'Lowest Stock',
        ProductSort.valueHigh => 'Highest Value',
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          PopupMenuButton<ProductSort>(
            initialValue: sort,
            tooltip: 'Sort order',
            onSelected: onSortChanged,
            position: PopupMenuPosition.under,
            itemBuilder: (context) => [
              for (final option in ProductSort.values)
                PopupMenuItem(value: option, child: Text(label(option))),
            ],
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151E2E) : palette.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155).withValues(alpha: 0.7)
                      : palette.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label(sort),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFF8FAFC)
                          : palette.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : palette.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilterButton(
            activeCount: activeFilterCount,
            onPressed: onOpenFilterSheet,
          ),
          const Spacer(),
          _LayoutToggle(grid: grid, onChanged: onLayoutChanged),
        ],
      ),
    );
  }
}

/// The two-button list/grid switch.
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.grid, required this.onChanged});

  final bool grid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget button(IconData icon, bool isGrid, String tooltip) {
      final selected = grid == isGrid;
      return Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => onChanged(isGrid),
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 38,
              height: 32,
              child: Icon(
                icon,
                size: 19,
                color: selected
                    ? Colors.white
                    : (isDark ? const Color(0xFF94A3B8) : palette.textTertiary),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E2E) : palette.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155).withValues(alpha: 0.7)
              : palette.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.view_list_rounded, false, 'List view'),
          const SizedBox(width: 2),
          button(Icons.grid_view_rounded, true, 'Grid view'),
        ],
      ),
    );
  }
}

/// Shared paging footer for both layouts.
class _LoadingMoreFooter extends StatelessWidget {
  const _LoadingMoreFooter();

  @override
  Widget build(BuildContext context) => const Padding(
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

/// The catalogue as rows.
class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.products,
    required this.controller,
    required this.loadingMore,
    required this.onOpen,
    required this.onActions,
    this.selectionMode = false,
    this.selectedIds = const <int>{},
    this.onToggleSelected,
    this.onEnterSelection,
  });

  final List<Product> products;
  final ScrollController controller;
  final bool loadingMore;
  final ValueChanged<Product> onOpen;
  final ValueChanged<Product> onActions;

  final bool selectionMode;
  final Set<int> selectedIds;
  final ValueChanged<int>? onToggleSelected;
  final ValueChanged<int>? onEnterSelection;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: products.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= products.length) return const _LoadingMoreFooter();
        final p = products[index];
        return _ProductRow(
          product: p,
          selectionMode: selectionMode,
          selected: selectedIds.contains(p.id),
          // While selecting, a tap picks the row rather than leaving the
          // screen — opening a product mid-selection would throw the
          // selection away.
          onTap: selectionMode
              ? () => onToggleSelected?.call(p.id)
              : () => onOpen(p),
          onActions: () => onActions(p),
          onLongPress: selectionMode
              ? () => onToggleSelected?.call(p.id)
              : () => onEnterSelection?.call(p.id),
        );
      },
    );
  }
}

/// The catalogue as tiles.
class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.controller,
    required this.loadingMore,
    required this.onOpen,
    required this.onActions,
  });

  final List<Product> products;
  final ScrollController controller;
  final bool loadingMore;
  final ValueChanged<Product> onOpen;
  final ValueChanged<Product> onActions;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.98,
      ),
      itemCount: products.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= products.length) return const _LoadingMoreFooter();
        final p = products[index];
        return ProductGridCard(
          product: p,
          onTap: () => onOpen(p),
          onLongPress: () => onActions(p),
        );
      },
    );
  }
}

/// The colour a stock level is shown in: out, low, or fine.
/// A small outlined category label.
class _CategoryTag extends StatelessWidget {
  const _CategoryTag(this.category);

  final String category;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

/// One product, as a row.
class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onTap,
    required this.onActions,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onActions;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = product;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusStyle = ProductStatusStyle.of(context, p);

    final skuText = (p.sku != null && p.sku!.trim().isNotEmpty)
        ? p.sku!.trim()
        : '-';

    final effectivePrice = p.sellPrice > 0 ? p.sellPrice : p.buyPrice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? palette.primary.withValues(alpha: isDark ? 0.18 : 0.10)
            : (isDark ? const Color(0xFF151E2E) : palette.cardSurface),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress ?? onActions,
          borderRadius: BorderRadius.circular(14),
          child: CustomPaint(
            foregroundPainter: CardAccentBorderPainter(
              color: selected ? palette.primary : statusStyle.color,
              strokeWidth: 2.0,
              radius: 14,
              glow: isDark,
            ),
            child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? palette.primary
                        : (isDark
                            ? const Color(0xFF334155).withValues(alpha: 0.6)
                            : palette.border),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(selectionMode ? 6 : 14, 10, 8, 10),
                child: Row(
                  children: [
                    if (selectionMode)
                      SelectionCheckbox(
                        selected: selected,
                        onChanged: (_) => onTap(),
                      ),
                    Hero(
                      tag: 'product_row_img_${p.id}',
                      child: ProductAvatar(product: p, size: 48, radiusFactor: 0.26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SKU: $skuText · ${p.stockQty} ${p.unit.trim().isEmpty ? 'pcs' : p.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusStyle.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                statusStyle.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusStyle.color,
                                ),
                              ),
                              if (p.category != null && p.category!.trim().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                _CategoryTag(p.category!),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FavouriteButton(product: p, size: 18),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusStyle.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${p.stockQty}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: statusStyle.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (effectivePrice > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              formatRupees(effectivePrice),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!selectionMode)
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
                        tooltip: 'Stock actions',
                        onPressed: onActions,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}


/// Shown when the catalogue has nothing to show.
class _EmptyCatalogue extends StatelessWidget {
  const _EmptyCatalogue({
    required this.filtered,
    this.onClearFilters,
    this.onAddProduct,
    this.onScanBarcode,
  });

  final bool filtered;

  /// Offered when the catalogue is non-empty but the filters hide all of it.
  final VoidCallback? onClearFilters;
  final VoidCallback? onAddProduct;
  final VoidCallback? onScanBarcode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                filtered ? Icons.search_off_rounded : Icons.inventory_2_outlined,
                size: 36,
                color: palette.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              filtered ? 'No products match this search' : 'No products yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Try adjusting your search or filters to find what you\'re looking for.'
                  : 'Add your first product to start tracking stock, value, and movements.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : palette.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (filtered && onClearFilters != null)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.primary,
                  side: BorderSide(color: palette.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            if (!filtered) ...[
              if (onAddProduct != null)
                FilledButton.icon(
                  onPressed: onAddProduct,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('+ Add Product'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (onScanBarcode != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onScanBarcode,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Scan Barcode Instead'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFF94A3B8) : palette.textSecondary,
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : palette.border,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Live inventory valuation and unit totals summary card.
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
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(16);

    return StreamBuilder<InventoryValuationSummary>(
      stream: widget.db.productDao.watchInventoryValuation(),
      builder: (context, snapshot) {
        final value = snapshot.data;
        final totalUnits = value?.totalUnits ?? 0;
        final double valuation = value != null
            ? (value.totalRetailValue > 0 ? value.totalRetailValue : value.totalCostValue)
            : 0.0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Material(
            color: isDark ? const Color(0xFF151E2E) : palette.cardSurface,
            borderRadius: radius,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: radius,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155).withValues(alpha: 0.7)
                        : palette.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Blue circular currency icon
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '₹',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Left metric: Inventory Valuation
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventory Valuation',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : palette.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatRupees(valuation),
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFF8FAFC)
                                      : palette.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Vertical divider line
                        Container(
                          width: 1,
                          height: 34,
                          color: isDark
                              ? const Color(0xFF334155).withValues(alpha: 0.7)
                              : palette.border,
                        ),
                        const SizedBox(width: 14),
                        // Right metric: Total Units
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Units',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : palette.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              NumberFormat('#,##,###').format(totalUnits),
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFFF8FAFC)
                                    : palette.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : palette.textTertiary,
                        ),
                      ],
                    ),
                    if (_expanded && value != null) ...[
                      Divider(
                        height: 20,
                        color: isDark
                            ? const Color(0xFF334155).withValues(alpha: 0.6)
                            : palette.border,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _Stat(
                              label: AppLocale.tr('retail_value'),
                              value: formatRupees(value.totalRetailValue),
                            ),
                          ),
                          Expanded(
                            child: _Stat(
                              label: AppLocale.tr('est_margin'),
                              value: '+${formatRupees(value.potentialProfit)}'
                                  ' (${value.marginPercent.toStringAsFixed(1)}%)',
                            ),
                          ),
                          Expanded(
                            child: _Stat(
                              label: 'Products',
                              value: '${value.totalProducts}',
                              alignEnd: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A small label-over-value pair.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: palette.textTertiary),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// The dashboard. It answers the three questions a shopkeeper opens the app
/// with, in that order:
///
/// 1. What needs my attention? (the status card at the top)
/// 2. What can I do right now? (the quick actions)
/// 3. What just happened? (the recent movement stream)
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
    final palette = context.palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        if (showBackupReminder) ...[
          _StatusCard(
            icon: Icons.shield_outlined,
            accent: palette.warning,
            title: AppLocale.tr('backup_reminder_title'),
            subtitle: AppLocale.tr('backup_reminder_body'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupPage()),
            ),
            onDismiss: onDismissBackupBanner,
          ),
          const SizedBox(height: 10),
        ],

        // ── SECTION 2: STOCK HEALTH ──
        StreamBuilder<List<Product>>(
          stream: db.productDao.watchLowStock(),
          builder: (context, lowSnap) {
            final lowStock = lowSnap.data ?? const <Product>[];
            return StreamBuilder<InventoryValuationSummary>(
              stream: db.productDao.watchInventoryValuation(),
              builder: (context, valSnap) {
                final totalProducts = valSnap.data?.totalProducts ?? 0;
                return DashboardStockHealthCard(
                  lowStock: lowStock,
                  totalProducts: totalProducts,
                  onTap: onNavigateToLowStock,
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),

        // ── SECTION 3: INVENTORY OVERVIEW (4 METRICS) ──
        StreamBuilder<InventoryValuationSummary>(
          stream: db.productDao.watchInventoryValuation(),
          builder: (context, valSnap) {
            final valuation = valSnap.data ??
                const InventoryValuationSummary(
                  totalProducts: 0,
                  totalUnits: 0,
                  totalCostValue: 0,
                  totalRetailValue: 0,
                  potentialProfit: 0,
                  marginPercent: 0,
                );
            return StreamBuilder<List<Product>>(
              stream: db.productDao.watchLowStock(),
              builder: (context, lowSnap) {
                final lowCount = lowSnap.data?.length ?? 0;
                return DashboardInventoryOverview(
                  valuation: valuation,
                  lowStockCount: lowCount,
                  onTapProducts: onNavigateToProducts,
                  onTapLowStock: onNavigateToLowStock,
                );
              },
            );
          },
        ),
        const SizedBox(height: 18),

        // ── SECTION 4: QUICK ACTIONS (2x2 GRID) ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle('Quick Actions'),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Quick action customisation coming soon.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: palette.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'Customize',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _QuickActionGridTile(
                icon: Icons.qr_code_scanner_rounded,
                accent: const Color(0xFF3B82F6),
                title: 'Scan & Adjust',
                subtitle: 'Single-SKU, Barcode',
                hasChevron: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerPage()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionGridTile(
                icon: Icons.check_box_outlined,
                accent: const Color(0xFFA855F7),
                title: 'Physical Audit',
                subtitle: 'Cycle Count · Reconcile',
                hasChevron: false,
                onTap: onNavigateToAudit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickActionGridTile(
                icon: Icons.add_rounded,
                accent: const Color(0xFF22C55E),
                title: 'Add Product',
                subtitle: 'Create or import SKU',
                hasChevron: false,
                onTap: () async {
                  final canAdd = await LicenseService(db).canAddProduct();
                  if (!context.mounted) return;
                  if (!canAdd) {
                    final unlocked = await PaywallSheet.show(context);
                    if (unlocked != true) return;
                  }
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProductEditPage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionGridTile(
                icon: Icons.sync_rounded,
                accent: const Color(0xFFF59E0B),
                title: 'Sync Data',
                subtitle: 'Backup & restore',
                hasChevron: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BackupPage()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── SECTION 5: NATIVE ADVERTISEMENT (GOOGLE ADMOB) ──
        AdMobNativeSection(
          db: db,
          rewardedCard: _DashboardRewardAdCard(db: db),
        ),
        const SizedBox(height: 18),

        // ── SECTION 6: TOP PRODUCTS CAROUSEL ──
        StreamBuilder<List<Product>>(
          stream: db.productDao.watchAll(
            sort: ProductSort.valueHigh,
            limit: 10,
          ),
          builder: (context, snapshot) {
            final products = snapshot.data ?? const <Product>[];
            return DashboardTopProducts(
              products: products,
              onViewAll: onNavigateToProducts,
              onAddProduct: () async {
                final canAdd = await LicenseService(db).canAddProduct();
                if (!context.mounted) return;
                if (!canAdd) {
                  final unlocked = await PaywallSheet.show(context);
                  if (unlocked != true) return;
                }
                if (!context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductEditPage()),
                );
              },
            );
          },
        ),
        const SizedBox(height: 18),

        // ── SECTION 7: RECENT STOCK ACTIVITY ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle('Recent Stock Activity'),
            TextButton(
              onPressed: onNavigateToProducts,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: palette.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'View All',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        StreamBuilder<List<Movement>>(
          stream: db.movementDao.watchRecent(limit: 5),
          builder: (context, snapshot) {
            final movements = snapshot.data ?? const <Movement>[];
            if (movements.isEmpty) return const _NoActivityYet();
            return Column(
              children: [
                for (final m in movements)
                  FutureBuilder<Product?>(
                    future: db.productDao.getById(m.productId),
                    builder: (context, productSnapshot) => _ActivityRow(
                      movement: m,
                      product: productSnapshot.data,
                      productName: productSnapshot.data?.name ??
                          'Product #${m.productId}',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailPage(productId: m.productId),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A dashboard section heading.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: context.palette.textPrimary,
      ),
    );
  }
}

/// The card at the top of the dashboard: one line on whether anything needs
/// doing, tinted by how urgent it is.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onDismiss,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(14);

    return Material(
      color: accent.withValues(alpha: isDark ? 0.12 : 0.09),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Icon(icon, size: 19, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: palette.textTertiary,
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: palette.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact 2-column grid tile under "Quick Actions".
class _QuickActionGridTile extends StatelessWidget {
  const _QuickActionGridTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.hasChevron,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool hasChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E2E) : palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155).withValues(alpha: 0.7)
              : palette.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasChevron)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the recent movement stream.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.movement,
    required this.productName,
    this.product,
    this.onTap,
  });

  final Movement movement;
  final String productName;
  final Product? product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = movement.qtyDelta > 0;
    final accent = isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? const Color(0xFF151E2E) : palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155).withValues(alpha: 0.7)
                    : palette.border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Direction Badge Icon (Green Up for Inward / Red Down for Outward)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPositive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 18,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8),

                // Product Avatar / Thumbnail
                if (product != null) ...[
                  ProductAvatar(
                    product: product!,
                    size: 34,
                    radiusFactor: 0.26,
                  ),
                  const SizedBox(width: 10),
                ],

                // Product name and movement details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isPositive ? 'Stock In' : 'Stock Out'} · ${_relativeTime(movement.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Delta + Chevron
                Text(
                  isPositive ? '+${movement.qtyDelta}' : '${movement.qtyDelta}',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// Shown in place of the activity stream before anything has moved.
class _NoActivityYet extends StatelessWidget {
  const _NoActivityYet();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 34, color: palette.textDisabled),
          const SizedBox(height: 10),
          Text(
            'No movements logged yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Scan a barcode or add stock to see movement history here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: palette.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// An elegant, non-disruptive dashboard card offering rewarded ad bonus slots.
///
/// Disappears completely when Pro is unlocked.
class _DashboardRewardAdCard extends StatefulWidget {
  const _DashboardRewardAdCard({required this.db});

  final AppDatabase db;

  @override
  State<_DashboardRewardAdCard> createState() => _DashboardRewardAdCardState();
}

class _DashboardRewardAdCardState extends State<_DashboardRewardAdCard> {
  late final LicenseService _licenseService;
  late final RewardedAdService _adService;
  bool _isPro = false;
  int _bonusSlots = 0;
  int _completedAdsToday = 0;
  bool _isWatching = false;

  @override
  void initState() {
    super.initState();
    _licenseService = LicenseService(widget.db);
    _adService = RewardedAdService(rewardDao: _licenseService.rewardDao);
    _refreshState();
  }

  @override
  void dispose() {
    _adService.dispose();
    super.dispose();
  }

  Future<void> _refreshState() async {
    final isPro = await _licenseService.isProUnlocked();
    if (isPro) {
      if (mounted) setState(() => _isPro = true);
      return;
    }
    final bonus = await _licenseService.getActiveRewardSlots();
    final today = await _licenseService.rewardDao.getDailyCompletedCount();
    if (mounted) {
      setState(() {
        _isPro = false;
        _bonusSlots = bonus;
        _completedAdsToday = today;
      });
    }
    if (today < RewardConfig.maxDailyAds) {
      unawaited(_adService.preloadAd());
    }
  }

  Future<void> _handleWatchAd() async {
    if (_isWatching) return;
    setState(() => _isWatching = true);

    try {
      final result = await _adService.showAdAndEarnReward();
      if (!mounted) return;

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Reward granted! +${result.rewardAmount} product slots added for 7 days.',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
        await _refreshState();
      } else if (result.status == RewardAdShowStatus.dismissedWithoutReward) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad closed before completion. No slots were earned.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'Sponsored ad is loading. Please try again in a moment.',
            ),
            action: SnackBarAction(
              label: 'Paywall',
              onPressed: () => PaywallSheet.show(context),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load ad. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isWatching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPro) return const SizedBox.shrink();

    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remaining = (RewardConfig.maxDailyAds - _completedAdsToday).clamp(0, RewardConfig.maxDailyAds);
    final canWatch = remaining > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2822) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2D4A3E) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canWatch ? _handleWatchAd : () => PaywallSheet.show(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    canWatch ? Icons.play_circle_filled_rounded : Icons.star_rounded,
                    size: 24,
                    color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Earn Free Product Slots',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)).withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SPONSORED',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        canWatch
                            ? 'Watch 30s ad for +2 slots (7-day validity) · $remaining left today'
                            : 'Daily quota completed ($_completedAdsToday/${RewardConfig.maxDailyAds}) · tap to upgrade',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.textTertiary,
                        ),
                      ),
                      if (_bonusSlots > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Active bonus: +$_bonusSlots slots available',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _isWatching ? null : (canWatch ? _handleWatchAd : () => PaywallSheet.show(context)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: isDark ? const Color(0xFF2D4A3E) : const Color(0xFFDCFCE7),
                    foregroundColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                  ),
                  child: _isWatching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          canWatch ? 'Watch (+2)' : 'Upgrade',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
