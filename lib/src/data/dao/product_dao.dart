import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'product_dao.g.dart';

/// How the product list is ordered.
///
/// Every option ends in an ascending id so the order is total. The list pages
/// by re-querying a growing window rather than by offset, and two rows that
/// compare equal could otherwise swap places between pages and be shown twice
/// or not at all.
enum ProductSort {
  /// Alphabetical. The only order the partial name index can serve directly.
  nameAsc,

  /// Most recently touched first — what a shopkeeper usually wants after a
  /// delivery or a stock count.
  recentlyUpdated,

  /// Emptiest shelf first.
  stockLowFirst,

  /// Most money sitting on the shelf first.
  valueHigh,
}

/// Which shelves the catalogue is narrowed to.
///
/// "Low" deliberately excludes zero: a product that has run out and one that
/// is about to are different problems, and a shopkeeper filtering for "low"
/// is looking for the things still worth reordering before they run dry.
/// [ProductStockStatus.outOfStock] covers the rest.
enum ProductStockStatus { any, inStock, low, outOfStock }

/// Products are soft-deleted only. Every query here filters `deletedAt`,
/// so a user who taps the wrong button can be restored later.
@DriftAccessor(tables: [Products, Movements])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(super.db);

  /// Paged, indexed product list with optional category and search query.
  Stream<List<Product>> watchAll({
    String query = '',
    String? category,
    Set<String> categories = const {},
    int? supplierId,
    ProductStockStatus status = ProductStockStatus.any,
    bool favouritesOnly = false,
    ProductSort sort = ProductSort.nameAsc,
    int limit = 100,
    int offset = 0,
  }) {
    final q = select(products)
      ..where((p) => _filters(
            query: query,
            category: category,
            categories: categories,
            supplierId: supplierId,
            status: status,
            favouritesOnly: favouritesOnly,
          ))
      ..orderBy([..._ordering(sort), (p) => OrderingTerm.asc(p.id)])
      ..limit(limit, offset: offset);

    return q.watch();
  }

  /// Everything but the ordering and the window.
  ///
  /// Shared so the list and [idsMatching] cannot disagree about what the
  /// filters mean — "select all" picking up a product the user cannot see is
  /// the kind of bug that only shows up after a bulk delete.
  Expression<bool> _filters({
    required String query,
    required String? category,
    required int? supplierId,
    required ProductStockStatus status,
    Set<String> categories = const {},
    bool favouritesOnly = false,
  }) {
    var predicate = products.deletedAt.isNull();

    // `category` and `categories` are one filter with two spellings: the
    // single one is what a tapped chip passes, the set is what the filter
    // sheet passes. Combined rather than one overriding the other, so a
    // caller cannot silently lose a filter it set.
    final wanted = <String>{
      if (category != null && category.trim().isNotEmpty) category.trim(),
      ...categories.map((c) => c.trim()).where((c) => c.isNotEmpty),
    };
    if (wanted.length == 1) {
      predicate = predicate & products.category.equals(wanted.first);
    } else if (wanted.length > 1) {
      // Several categories is a union: "show me Dairy and Spices", not
      // "show me rows that are somehow both".
      predicate = predicate & products.category.isIn(wanted.toList());
    }
    if (supplierId != null) {
      predicate = predicate & products.supplierId.equals(supplierId);
    }
    if (favouritesOnly) {
      predicate = predicate & products.isFavourite.equals(true);
    }
    predicate = predicate & _statusPredicate(products, status);
    if (query.isNotEmpty) {
      final like = '%${_escapeLike(query)}%';
      predicate = predicate &
          (products.name.lower().like(like, escapeChar: r'\') |
              products.sku.lower().like(like, escapeChar: r'\') |
              products.barcode.lower().like(like, escapeChar: r'\'));
    }
    return predicate;
  }

  /// The stock-level half of the where clause.
  ///
  /// `lowStockLevel` is 0 when the shopkeeper never set a threshold, and 0 is
  /// not a threshold — without excluding it every product in the shop counts
  /// as low the moment it is not in stock.
  Expression<bool> _statusPredicate(
    $ProductsTable p,
    ProductStockStatus status,
  ) {
    switch (status) {
      case ProductStockStatus.any:
        return const Constant(true);
      case ProductStockStatus.inStock:
        return p.stockQty.isBiggerThanValue(0);
      case ProductStockStatus.low:
        return p.stockQty.isBiggerThanValue(0) &
            p.lowStockLevel.isBiggerThanValue(0) &
            p.stockQty.isSmallerOrEqual(p.lowStockLevel);
      case ProductStockStatus.outOfStock:
        return p.stockQty.isSmallerOrEqualValue(0);
    }
  }

  /// How many products each status covers right now, for the filter chips.
  ///
  /// Counted in one pass rather than four queries: the chips are all on
  /// screen together and a shop with a large catalogue would otherwise scan
  /// the table once per chip on every keystroke.
  Stream<ProductStatusCounts> watchStatusCounts() {
    return (select(products)..where((p) => p.deletedAt.isNull()))
        .watch()
        .map((rows) {
      var inStock = 0;
      var low = 0;
      var out = 0;
      for (final p in rows) {
        if (p.stockQty <= 0) {
          out++;
        } else {
          inStock++;
          if (p.lowStockLevel > 0 && p.stockQty <= p.lowStockLevel) low++;
        }
      }
      return ProductStatusCounts(
        all: rows.length,
        inStock: inStock,
        low: low,
        outOfStock: out,
      );
    });
  }

  List<OrderClauseGenerator<$ProductsTable>> _ordering(ProductSort sort) {
    switch (sort) {
      case ProductSort.nameAsc:
        return [(p) => OrderingTerm.asc(p.name)];
      case ProductSort.recentlyUpdated:
        return [(p) => OrderingTerm.desc(p.updatedAt)];
      case ProductSort.stockLowFirst:
        return [
          (p) => OrderingTerm.asc(p.stockQty),
          (p) => OrderingTerm.asc(p.name),
        ];
      case ProductSort.valueHigh:
        return [
          (p) => OrderingTerm.desc(p.stockQty.cast<double>() * p.buyPrice),
          (p) => OrderingTerm.asc(p.name),
        ];
    }
  }

  /// Pins or unpins one product.
  ///
  /// Returns the value now stored, so a caller that toggled optimistically
  /// can settle on the truth rather than its own guess.
  Future<bool> setFavourite(int id, bool isFavourite) async {
    await (update(products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        isFavourite: Value(isFavourite),
        // Deliberately not touching updatedAt: pinning a product is a view
        // preference, and letting it reorder "Recently Updated" would push
        // whatever the shopkeeper just favourited to the top of a list that
        // is supposed to mean "recently changed".
      ),
    );
    return isFavourite;
  }

  /// How many products are pinned, for the Favourites chip.
  Stream<int> watchFavouriteCount() {
    final count = countAll(
      filter: products.deletedAt.isNull() & products.isFavourite.equals(true),
    );
    final q = selectOnly(products)..addColumns([count]);
    return q.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// The ids of every product the given filters match.
  ///
  /// For "select all", which has to mean everything behind the filters and
  /// not merely the page the list has scrolled far enough to load. Only the
  /// id column is read: the selection needs nothing else, and a catalogue of
  /// several thousand products should not be hydrated into memory to tick
  /// some boxes.
  Future<List<int>> idsMatching({
    String query = '',
    String? category,
    Set<String> categories = const {},
    int? supplierId,
    ProductStockStatus status = ProductStockStatus.any,
    bool favouritesOnly = false,
  }) async {
    final rows = await (selectOnly(products)
          ..addColumns([products.id])
          ..where(_filters(
            query: query,
            category: category,
            categories: categories,
            supplierId: supplierId,
            status: status,
            favouritesOnly: favouritesOnly,
          ))
          ..orderBy([OrderingTerm.asc(products.id)]))
        .get();
    return rows.map((row) => row.read(products.id)).whereType<int>().toList();
  }

  /// Get distinct non-empty categories from active products.
  Future<List<String>> getCategories() async {
    final catCol = products.category;
    final q = selectOnly(products, distinct: true)
      ..addColumns([catCol])
      ..where(products.deletedAt.isNull() & catCol.isNotNull());
    final rows = await q.get();
    return rows
        .map((r) => r.read(catCol))
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .toList()
      ..sort();
  }

  /// Each category and how many live products carry it.
  ///
  /// One pass rather than a query per row of the filter sheet: the counts
  /// are all shown together, and a shop with a long category list would
  /// otherwise scan the table once per line.
  Stream<Map<String, int>> watchCategoryCounts() {
    return (select(products)..where((p) => p.deletedAt.isNull()))
        .watch()
        .map((rows) {
      final counts = <String, int>{};
      for (final product in rows) {
        final category = product.category?.trim();
        if (category == null || category.isEmpty) continue;
        counts[category] = (counts[category] ?? 0) + 1;
      }
      // Alphabetical, so the sheet does not reshuffle as stock moves.
      return Map.fromEntries(
        counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
    });
  }

  /// Stream distinct categories.
  Stream<List<String>> watchCategories() {
    final catCol = products.category;
    final q = selectOnly(products, distinct: true)
      ..addColumns([catCol])
      ..where(products.deletedAt.isNull() & catCol.isNotNull());
    return q.watch().map((rows) => rows
        .map((r) => r.read(catCol))
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .toList()
      ..sort());
  }

  /// Insert multiple products in a batch (used by CSV importer).
  Future<void> batchInsert(List<ProductsCompanion> entries) async {
    await batch((b) {
      b.insertAll(products, entries);
    });
  }

  Future<Product?> getById(int id) =>
      (select(products)..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
          .getSingleOrNull();

  Future<Product?> getByBarcode(String barcode) =>
      (select(products)
            ..where((p) => p.barcode.equals(barcode) & p.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  Stream<Product?> watchById(int id) =>
      (select(products)..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
          .watchSingleOrNull();

  Future<int> insertProduct(ProductsCompanion entry) =>
      into(products).insert(entry);

  Future<bool> updateProduct(int id, ProductsCompanion entry) async {
    final count = await (update(products)..where((p) => p.id.equals(id)))
        .write(entry.copyWith(updatedAt: Value(DateTime.now())));
    return count > 0;
  }

  Future<void> softDelete(int id) async {
    final now = DateTime.now();
    await (update(products)..where((p) => p.id.equals(id)))
        .write(ProductsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  /// Soft-deletes several products at once.
  ///
  /// One transaction, so a bulk delete that fails halfway leaves the
  /// catalogue exactly as it was rather than half-removed. Nothing is
  /// dropped: `deletedAt` is set, the ledger behind each product is
  /// untouched, and [restore] brings any of them back.
  Future<void> softDeleteMany(Iterable<int> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return;
    final now = DateTime.now();
    await transaction(() async {
      await (update(products)..where((p) => p.id.isIn(list))).write(
        ProductsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  /// Moves several products into one category.
  ///
  /// A null or blank [category] clears it, which is how a mis-imported
  /// category gets undone.
  Future<void> setCategoryMany(Iterable<int> ids, String? category) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return;
    final trimmed = category?.trim();
    await transaction(() async {
      await (update(products)..where((p) => p.id.isIn(list))).write(
        ProductsCompanion(
          category: Value(
            trimmed == null || trimmed.isEmpty ? null : trimmed,
          ),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Sets the same selling price on several products.
  ///
  /// Only the sell price: the buy price is what each product actually cost,
  /// which is per-product history and never the same across a selection.
  Future<void> setSellPriceMany(Iterable<int> ids, double sellPrice) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return;
    if (sellPrice < 0) {
      throw ArgumentError.value(sellPrice, 'sellPrice', 'must not be negative');
    }
    await transaction(() async {
      await (update(products)..where((p) => p.id.isIn(list))).write(
        ProductsCompanion(
          sellPrice: Value(sellPrice),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> restore(int id) =>
      (update(products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<int> countActive() async {
    final c = countAll(filter: products.deletedAt.isNull());
    final q = selectOnly(products)..addColumns([c]);
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  }

  /// Rebuild one product's cached stock from the ledger.
  Future<void> rebuildStockCache(int productId) async {
    final sum = movements.qtyDelta.sum();
    final q = selectOnly(movements)
      ..addColumns([sum])
      ..where(movements.productId.equals(productId));
    final row = await q.getSingle();
    final total = row.read(sum) ?? 0;
    await (update(products)..where((p) => p.id.equals(productId)))
        .write(ProductsCompanion(stockQty: Value(total)));
  }

  /// Low-stock products: stock at or below alert level, excluding products
  /// whose alert is disabled (level = 0).
  Stream<List<Product>> watchLowStock({int limit = 200}) {
    final q = select(products)
      ..where((p) =>
          p.deletedAt.isNull() &
          p.lowStockLevel.isBiggerThanValue(0) &
          p.stockQty.isSmallerOrEqual(p.lowStockLevel))
      ..orderBy([(p) => OrderingTerm.asc(p.stockQty)])
      ..limit(limit);
    return q.watch();
  }

  /// All active products, every column — for CSV/Excel export.
  /// The spec demands every column in exports.
  Future<List<Product>> getAllForExport() =>
      (select(products)
            ..where((p) => p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .get();

  /// Calculate live total inventory valuation (cost price, retail price, margin, units).
  Future<InventoryValuationSummary> getInventoryValuation() =>
      _valuationQuery().getSingle().then(_readValuation);

  /// Watch live inventory valuation reactively.
  ///
  /// Aggregated in SQL rather than by loading the catalogue into Dart. The
  /// valuation card sits on the home screen, so the previous version
  /// materialised every active product on every change to the table — a full
  /// catalogue load after each stock movement.
  Stream<InventoryValuationSummary> watchInventoryValuation() =>
      _valuationQuery().watchSingle().map(_readValuation);

  Selectable<QueryRow> _valuationQuery() => customSelect(
        '''
        SELECT
          COUNT(*)                                            AS total_products,
          COALESCE(SUM(CASE WHEN stock_qty > 0 THEN stock_qty END), 0)
                                                              AS total_units,
          COALESCE(SUM(CASE WHEN stock_qty > 0
                            THEN stock_qty * buy_price END), 0.0)
                                                              AS total_cost,
          COALESCE(SUM(CASE WHEN stock_qty > 0
                            THEN stock_qty * sell_price END), 0.0)
                                                              AS total_retail
        FROM product
        WHERE deleted_at IS NULL
        ''',
        readsFrom: {products},
      );

  static InventoryValuationSummary _readValuation(QueryRow row) {
    final totalCost = row.read<double>('total_cost');
    final totalRetail = row.read<double>('total_retail');
    final potentialProfit = totalRetail - totalCost;

    return InventoryValuationSummary(
      totalProducts: row.read<int>('total_products'),
      totalUnits: row.read<int>('total_units'),
      totalCostValue: totalCost,
      totalRetailValue: totalRetail,
      potentialProfit: potentialProfit,
      marginPercent: totalCost > 0 ? (potentialProfit / totalCost) * 100 : 0.0,
    );
  }


  static String _escapeLike(String input) =>
      input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}

/// Snapshot of inventory valuation for small retailers.
class InventoryValuationSummary {
  final int totalProducts;
  final int totalUnits;
  final double totalCostValue;
  final double totalRetailValue;
  final double potentialProfit;
  final double marginPercent;

  const InventoryValuationSummary({
    required this.totalProducts,
    required this.totalUnits,
    required this.totalCostValue,
    required this.totalRetailValue,
    required this.potentialProfit,
    required this.marginPercent,
  });
}

/// How many products sit behind each filter chip.
class ProductStatusCounts {
  const ProductStatusCounts({
    required this.all,
    required this.inStock,
    required this.low,
    required this.outOfStock,
  });

  final int all;
  final int inStock;

  /// In stock, but at or below a threshold the shopkeeper actually set.
  final int low;

  final int outOfStock;

  int forStatus(ProductStockStatus status) => switch (status) {
        ProductStockStatus.any => all,
        ProductStockStatus.inStock => inStock,
        ProductStockStatus.low => low,
        ProductStockStatus.outOfStock => outOfStock,
      };
}
