import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/app_palette.dart';

/// Everything the catalogue is narrowed by, apart from the search text.
///
/// Held as one value so the screen can hand the whole set of filters to a
/// sheet, take back whatever the user settled on, and count what is active
/// without interrogating half a dozen separate fields.
class ProductFilters {
  const ProductFilters({
    this.categories = const {},
    this.supplierId,
    this.status = ProductStockStatus.any,
    this.favouritesOnly = false,
  });

  final Set<String> categories;
  final int? supplierId;
  final ProductStockStatus status;
  final bool favouritesOnly;

  /// How many filters are on, for the badge on the filter button.
  ///
  /// Categories count as one however many are ticked: the badge answers
  /// "how much am I hiding", and six ticked categories is still one
  /// decision the user made.
  int get activeCount =>
      (categories.isEmpty ? 0 : 1) +
      (supplierId == null ? 0 : 1) +
      (status == ProductStockStatus.any ? 0 : 1) +
      (favouritesOnly ? 1 : 0);

  bool get isEmpty => activeCount == 0;

  /// Value equality, so a rebuild that produces the same filters does not
  /// look like a change. The catalogue reopens its query whenever these
  /// differ, and comparing by identity would tear down and re-run the query
  /// every time the page rebuilt for an unrelated reason.
  @override
  bool operator ==(Object other) =>
      other is ProductFilters &&
      other.supplierId == supplierId &&
      other.status == status &&
      other.favouritesOnly == favouritesOnly &&
      other.categories.length == categories.length &&
      other.categories.containsAll(categories);

  @override
  int get hashCode => Object.hash(
        supplierId,
        status,
        favouritesOnly,
        // Order must not matter: the same categories picked in a different
        // order are the same filter.
        Object.hashAllUnordered(categories),
      );

  ProductFilters copyWith({
    Set<String>? categories,
    int? supplierId,
    bool clearSupplier = false,
    ProductStockStatus? status,
    bool? favouritesOnly,
  }) {
    return ProductFilters(
      categories: categories ?? this.categories,
      // A null supplierId is a legitimate value — "any supplier" — so it
      // cannot be told apart from "not passed" without this flag.
      supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
      status: status ?? this.status,
      favouritesOnly: favouritesOnly ?? this.favouritesOnly,
    );
  }
}

/// The filter sheet: categories with their counts, a supplier, and a reset.
///
/// Returns the filters the user settled on, or null if they backed out, so
/// a dismissed sheet changes nothing.
Future<ProductFilters?> showProductFilterSheet({
  required BuildContext context,
  required AppDatabase db,
  required ProductFilters current,
}) {
  return showModalBottomSheet<ProductFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FilterSheet(db: db, initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.db, required this.initial});

  final AppDatabase db;
  final ProductFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ProductFilters _filters = widget.initial;

  /// Opened once. Building these in `build` would hand each StreamBuilder a
  /// new stream every time a box is ticked, dropping the subscription and
  /// passing back through "no data yet" — so the list would blink to a
  /// spinner on every tick.
  late final Stream<Map<String, int>> _categoryCounts =
      widget.db.productDao.watchCategoryCounts();

  /// Every live product, including the ones with no category at all.
  ///
  /// The "All categories" row has to show this rather than the sum of the
  /// rows beneath it. Clearing the filter shows uncategorised products too,
  /// so a total that left them out promised one number and delivered
  /// another — visible as "All categories 5" directly beneath a chip
  /// reading "All 9".
  late final Stream<int> _liveProductCount =
      widget.db.productDao.watchStatusCounts().map((counts) => counts.all);
  late final Stream<List<Supplier>> _suppliers =
      widget.db.supplierDao.watchAll();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        // Never taller than most of the screen: the list of categories grows
        // with the shop, and a sheet that fills the display hides what it is
        // filtering.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _filters.isEmpty
                        ? null
                        : () => setState(() => _filters = const ProductFilters()),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.border),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                children: [
                  _Heading('Category'),
                  const SizedBox(height: 8),
                  _CategoryPicker(
                    counts: _categoryCounts,
                    liveProductCount: _liveProductCount,
                    selected: _filters.categories,
                    onChanged: (categories) => setState(
                      () => _filters = _filters.copyWith(categories: categories),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Heading('Supplier'),
                  const SizedBox(height: 8),
                  _SupplierPicker(
                    suppliers: _suppliers,
                    selected: _filters.supplierId,
                    onChanged: (id) => setState(
                      () => _filters = id == null
                          ? _filters.copyWith(clearSupplier: true)
                          : _filters.copyWith(supplierId: id),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _filters),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _filters.isEmpty
                        ? 'Show all products'
                        : 'Apply ${_filters.activeCount} '
                            '${_filters.activeCount == 1 ? 'filter' : 'filters'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: context.palette.textPrimary,
        ),
      );
}

/// Tickable categories, each with how many products carry it.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.counts,
    required this.liveProductCount,
    required this.selected,
    required this.onChanged,
  });

  final Stream<Map<String, int>> counts;
  final Stream<int> liveProductCount;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return StreamBuilder<Map<String, int>>(
      stream: counts,
      builder: (context, snapshot) {
        final counts = snapshot.data;
        if (counts == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (counts.isEmpty) {
          return Text(
            'No categories yet. Give a product one and it appears here.',
            style: TextStyle(fontSize: 12.5, color: palette.textTertiary),
          );
        }

        // The sum of the rows below is not the answer: products with no
        // category are shown when the filter is cleared but belong to none
        // of them.
        final categorised = counts.values.fold<int>(0, (a, b) => a + b);

        return Column(
          children: [
            StreamBuilder<int>(
              stream: liveProductCount,
              builder: (context, totalSnapshot) => _CheckRow(
                label: 'All categories',
                count: totalSnapshot.data ?? categorised,
                // Nothing ticked is the same thing as everything shown, and
                // the row says so rather than leaving the list looking
                // unset.
                checked: selected.isEmpty,
                onTap: () => onChanged(const {}),
              ),
            ),
            for (final entry in counts.entries)
              _CheckRow(
                label: entry.key,
                count: entry.value,
                checked: selected.contains(entry.key),
                onTap: () {
                  final next = Set<String>.from(selected);
                  if (!next.remove(entry.key)) next.add(entry.key);
                  onChanged(next);
                },
              ),
          ],
        );
      },
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.count,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (_) => onTap(),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: palette.textPrimary),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(fontSize: 12.5, color: palette.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// One supplier, or any.
class _SupplierPicker extends StatelessWidget {
  const _SupplierPicker({
    required this.suppliers,
    required this.selected,
    required this.onChanged,
  });

  final Stream<List<Supplier>> suppliers;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return StreamBuilder<List<Supplier>>(
      stream: suppliers,
      builder: (context, snapshot) {
        final suppliers = snapshot.data ?? const <Supplier>[];
        if (suppliers.isEmpty) {
          return Text(
            'No suppliers yet. Add one from More › Suppliers & Vendors.',
            style: TextStyle(fontSize: 12.5, color: palette.textTertiary),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SupplierChip(
              label: 'Any supplier',
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
            for (final supplier in suppliers)
              _SupplierChip(
                label: supplier.name,
                selected: selected == supplier.id,
                // Tapping the one already chosen clears it, so the filter
                // can be undone without hunting for "Any".
                onTap: () =>
                    onChanged(selected == supplier.id ? null : supplier.id),
              ),
          ],
        );
      },
    );
  }
}

class _SupplierChip extends StatelessWidget {
  const _SupplierChip({
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
    final radius = BorderRadius.circular(18);

    return Material(
      color: selected ? palette.primary : palette.elevatedSurface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The filter button that opens the sheet, carrying a count when any filter
/// is on.
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.activeCount,
    required this.onPressed,
  });

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = activeCount > 0;
    final radius = BorderRadius.circular(9);

    return Tooltip(
      message: active ? '$activeCount filters applied' : 'Filter products',
      child: Material(
        color: active ? palette.primary : palette.cardSurface,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: active ? palette.primary : palette.border,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: active ? Colors.white : palette.textSecondary,
                ),
                if (active) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
