
import 'package:flutter/material.dart';

import '../data/database.dart';
import 'money_format.dart';
import 'movement_reason.dart';
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
      return AppBar(
        toolbarHeight: 58,
        title: Text(
          AppLocale.tr('products'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 21),
        ),
        actions: [
          _HeaderIconButton(
            icon: selectionModeIcon,
            tooltip: 'Select products',
            onPressed: _matchingCount == 0
                ? null
                : () => setState(() => _selectionMode = true),
          ),
          _HeaderIconButton(
            icon: Icons.qr_code_scanner_rounded,
            tooltip: 'Scan a barcode',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScannerPage()),
            ),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(102),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _ProductSearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  onVoice: _openVoiceAssistant,
                ),
              ),
              _CategoryFilterBar(
                db: _db,
                selected: _filters.categories,
                onToggle: (category) {
                  final next = Set<String>.from(_filters.categories);
                  if (category == null) {
                    next.clear();
                  } else if (!next.remove(category)) {
                    next.add(category);
                  }
                  setState(() => _filters = _filters.copyWith(categories: next));
                },
              ),
              const SizedBox(height: 8),
            ],
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
      body: _buildBody(),
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

/// Category chip selector under search bar.
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.db,
    required this.selected,
    required this.onToggle,
  });

  final AppDatabase db;

  /// Empty means every category, which is what the "All" chip shows.
  final Set<String> selected;

  /// Null toggles "All", clearing the set.
  final ValueChanged<String?> onToggle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: db.productDao.watchCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];
        if (categories.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _CategoryChip(
                label: AppLocale.tr('all_categories'),
                selected: selected.isEmpty,
                onTap: () => onToggle(null),
              ),
              for (final cat in categories)
                _CategoryChip(
                  label: cat,
                  selected: selected.contains(cat),
                  onTap: () => onToggle(cat),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One category pill.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(17);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? palette.primary : palette.elevatedSurface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : palette.textSecondary,
                ),
              ),
            ),
          ),
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
                  onClearFilters: widget.filters.isEmpty
                      ? null
                      : () => widget.onFiltersChanged(const ProductFilters()),
                );
              }

              return Column(
                children: [
                  // Hidden while selecting: the valuation covers the whole
                  // shop and says nothing about the rows being picked.
                  if (unfiltered && !widget.selectionMode)
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
                    child: widget.grid && !widget.selectionMode
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
                          ),
                  ),
                ],
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
    (ProductStockStatus.any, 'All', null),
    (ProductStockStatus.inStock, 'In Stock', Icons.check_circle_outline),
    (ProductStockStatus.low, 'Low Stock', Icons.warning_amber_rounded),
    (
      ProductStockStatus.outOfStock,
      'Out of Stock',
      Icons.remove_circle_outline,
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
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            children: [
              for (final (value, label, icon) in _options)
                _StatusChip(
                  label: label,
                  icon: icon,
                  // Null while the first count is in flight, rather than a
                  // zero that would read as "none of these exist".
                  count: counts?.forStatus(value),
                  accent: _accentFor(value, palette),
                  selected: status == value,
                  onTap: () => onChanged(value),
                ),
              // Favourites sits alongside the stock filters rather than
              // among them: it narrows by what the shopkeeper pinned, not by
              // what is on the shelf, and the two combine.
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
    final radius = BorderRadius.circular(18);
    final foreground = selected ? accent : palette.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? accent.withValues(alpha: isDark ? 0.22 : 0.13)
            : palette.cardSurface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.5)
                    : palette.border,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: foreground),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: foreground.withValues(alpha: 0.7),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                color: palette.cardSurface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label(sort),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: palette.textTertiary,
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

    Widget button(IconData icon, bool isGrid, String tooltip) {
      final selected = grid == isGrid;
      return Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: () => onChanged(isGrid),
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              width: 36,
              height: 30,
              child: Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : palette.textTertiary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.view_list_rounded, false, 'List view'),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: products.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= products.length) return const _LoadingMoreFooter();
        final p = products[index];
        return _ProductTile(
          product: p,
          onTap: () => onOpen(p),
          onActions: () => onActions(p),
        );
      },
    );
  }
}

/// The colour a stock level is shown in: out, low, or fine.
({Color accent, Color surface}) _stockTone(BuildContext context, Product p) {
  final palette = context.palette;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final accent = p.stockQty <= 0
      ? palette.error
      : (p.lowStockLevel > 0 && p.stockQty <= p.lowStockLevel
          ? palette.warning
          : palette.success);
  return (
    accent: accent,
    surface: accent.withValues(alpha: isDark ? 0.18 : 0.12),
  );
}

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

/// The stock quantity badge.
class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product, this.compact = false});

  final Product product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tone = _stockTone(context, product);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${product.stockQty}',
        style: TextStyle(
          fontSize: compact ? 12.5 : 14,
          fontWeight: FontWeight.w700,
          color: tone.accent,
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
    final details = [
      if (p.sku != null && p.sku!.trim().isNotEmpty) 'SKU: ${p.sku}',
      p.unit,
    ].join(' · ');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? palette.primary.withValues(alpha: isDark ? 0.16 : 0.08)
            : palette.cardSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress ?? onActions,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? palette.primary : palette.border,
              ),
            ),
            padding: EdgeInsets.fromLTRB(selectionMode ? 2 : 10, 10, 6, 10),
            child: Row(
              children: [
                if (selectionMode)
                  SelectionCheckbox(
                    selected: selected,
                    onChanged: (_) => onTap(),
                  ),
                ProductAvatar(product: p),
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
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.textTertiary,
                        ),
                      ),
                      if (p.category != null && p.category!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: _CategoryTag(p.category!),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StockBadge(product: p),
                    if (p.sellPrice > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'MRP ${formatRupees(p.sellPrice)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!selectionMode)
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    color: palette.textTertiary,
                    tooltip: 'Stock actions',
                    onPressed: onActions,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One product, as a grid tile.
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onActions,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = product;

    return Material(
      color: palette.cardSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onActions,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductAvatar(product: p, size: 52),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FavouriteButton(product: p, size: 18),
                      const SizedBox(height: 4),
                      _StockBadge(product: p, compact: true),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                p.unit,
                style: TextStyle(fontSize: 11, color: palette.textTertiary),
              ),
              const Spacer(),
              Row(
                children: [
                  if (p.category != null && p.category!.trim().isNotEmpty)
                    Flexible(child: _CategoryTag(p.category!)),
                  const Spacer(),
                  if (p.sellPrice > 0)
                    Text(
                      formatRupees(p.sellPrice),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the catalogue has nothing to show.
class _EmptyCatalogue extends StatelessWidget {
  const _EmptyCatalogue({required this.filtered, this.onClearFilters});

  final bool filtered;

  /// Offered when the catalogue is non-empty but the filters hide all of it.
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: palette.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? 'No products match this search' : 'No products yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            if (!filtered)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Tap + to add your first product, or scan a barcode.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: palette.textTertiary),
                ),
              ),
            if (onClearFilters != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Clear filters'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Live inventory valuation, expanding to the retail value and margin behind
/// it. Shown above the catalogue when nothing is filtered out, because the
/// number only means anything when it covers everything.
class _InventoryValuationCard extends StatefulWidget {
  const _InventoryValuationCard({required this.db});

  final AppDatabase db;

  @override
  State<_InventoryValuationCard> createState() =>
      _InventoryValuationCardState();
}

class _InventoryValuationCardState extends State<_InventoryValuationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(14);

    return StreamBuilder<InventoryValuationSummary>(
      stream: widget.db.productDao.watchInventoryValuation(),
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (value == null || value.totalProducts == 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Material(
            color: palette.primary.withValues(alpha: isDark ? 0.12 : 0.07),
            borderRadius: radius,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: radius,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: palette.primary.withValues(alpha: 0.22),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '₹',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Stat(
                            label: AppLocale.tr('inventory_valuation'),
                            value: formatRupees(value.totalCostValue),
                          ),
                        ),
                        _Stat(
                          label: AppLocale.tr('total_units'),
                          value: '${value.totalUnits}',
                          alignEnd: true,
                        ),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 20,
                          color: palette.textTertiary,
                        ),
                      ],
                    ),
                    if (_expanded) ...[
                      Divider(height: 20, color: palette.border),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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

        // ── 1. WHAT NEEDS MY ATTENTION? ──
        StreamBuilder<List<Product>>(
          stream: db.productDao.watchLowStock(),
          builder: (context, snapshot) {
            final lowStock = snapshot.data ?? const <Product>[];
            if (lowStock.isEmpty) {
              return _StatusCard(
                icon: Icons.check_circle_rounded,
                accent: palette.success,
                title: 'All stock levels optimal',
                subtitle: 'Zero critical shortages',
                onTap: onNavigateToLowStock,
              );
            }
            final outOfStock = lowStock.where((p) => p.stockQty <= 0).length;
            return _StatusCard(
              icon: Icons.warning_amber_rounded,
              accent: outOfStock > 0 ? palette.error : palette.warning,
              title: '${lowStock.length} '
                  '${lowStock.length == 1 ? 'product needs' : 'products need'} '
                  'reordering',
              subtitle: outOfStock > 0
                  ? '$outOfStock out of stock · tap to review restock quantities'
                  : 'Below reorder threshold · tap to review restock quantities',
              onTap: onNavigateToLowStock,
            );
          },
        ),
        const SizedBox(height: 22),

        // ── 2. WHAT CAN I DO RIGHT NOW? ──
        const _SectionTitle('Quick Actions'),
        const SizedBox(height: 10),
        // Intrinsic height so the two tiles match even when one subtitle
        // wraps to a second line — stretch alone has no height to stretch to
        // inside a scroll view.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.qr_code_scanner_rounded,
                  accent: palette.primary,
                  title: 'Scan & Adjust',
                  subtitle: 'Single-SKU Barcode',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScannerPage()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.check_box_outlined,
                  accent: palette.secondary,
                  title: 'Physical Audit',
                  subtitle: 'Cycle-Count · Reconcile',
                  onTap: onNavigateToAudit,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _WideActionCard(
          icon: Icons.add_rounded,
          title: AppLocale.tr('add_product') != 'add_product'
              ? AppLocale.tr('add_product')
              : 'Add New Product',
          subtitle: 'Enter barcode or manual SKU for unbarcoded goods',
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
        const SizedBox(height: 24),

        // ── 3. WHAT JUST HAPPENED? ──
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
                      productName:
                          productSnapshot.data?.name ?? 'Product #${m.productId}',
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

/// One of the two tinted action tiles under "Quick Actions".
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(14);

    return Material(
      color: accent.withValues(alpha: isDark ? 0.13 : 0.08),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: accent.withValues(alpha: isDark ? 0.3 : 0.2)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.24 : 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 21, color: accent),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: palette.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full-width "Add New Product" card.
class _WideActionCard extends StatelessWidget {
  const _WideActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(14);

    return Material(
      color: palette.cardSurface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: palette.border),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 21, color: Colors.white),
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
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
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

/// One row of the recent movement stream.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.movement, required this.productName});

  final Movement movement;
  final String productName;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = movement.qtyDelta > 0;
    final accent = isPositive ? palette.success : palette.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPositive
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
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
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${readableMovementReason(movement.reason)}'
                  ' · ${_relativeTime(movement.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: palette.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isPositive ? '+${movement.qtyDelta}' : '${movement.qtyDelta}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
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
