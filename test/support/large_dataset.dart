// Reusable large-dataset fixture.
//
// The dev plan sets the bar explicitly: "Fill 5,000 products and 50,000
// movements, then time backup, restore and list scroll. That last test is the
// one people skip. A shop with three years of movements is your best customer
// and the one most likely to hit a wall."
//
// Phase B (restore), Phase C (zip export) and Phase D (indexes) all need to be
// measured against the same data, so the generator lives here rather than in
// any one test.
import 'package:drift/drift.dart';
import 'package:stocksafe/src/data/database.dart';

/// Default scale from the dev plan's own acceptance test.
const int kPlanProductCount = 5000;
const int kPlanMovementCount = 50000;

/// Categories and units drawn from the target market, so string lengths and
/// cardinality resemble a real kirana catalogue rather than `item_1..item_n`.
const List<String> _categories = [
  'Rice & Grains', 'Pulses', 'Oils & Ghee', 'Spices', 'Snacks',
  'Biscuits', 'Beverages', 'Dairy', 'Soaps & Detergents', 'Stationery',
];

const List<String> _units = ['pcs', 'kg', 'g', 'ltr', 'ml', 'pkt', 'bag'];

const List<String> _reasons = [
  'sale', 'purchase', 'damage', 'return', 'opening_stock', 'stocktake_adjustment',
];

/// Seeds [db] with [productCount] products and [movementCount] ledger rows.
///
/// Writes go through `batch` inserts rather than `MovementDao.recordMovement`,
/// because that method recomputes `SUM(qty_delta)` per call — which is the very
/// cost under measurement, and would make seeding quadratic. The product cache
/// is reconciled once at the end via [AppDatabase.rebuildAllStockCaches], so
/// the resulting database is in exactly the state the app maintains.
Future<LargeDatasetStats> seedLargeDataset(
  AppDatabase db, {
  int productCount = kPlanProductCount,
  int movementCount = kPlanMovementCount,
  int seed = 20261013,
}) async {
  final rand = _Lcg(seed);
  final now = DateTime.now();
  final threeYearsAgo = now.subtract(const Duration(days: 365 * 3));
  final spanSeconds = now.difference(threeYearsAgo).inSeconds;

  // ── Products ────────────────────────────────────────────────────
  await db.batch((b) {
    for (var i = 1; i <= productCount; i++) {
      final category = _categories[rand.next(_categories.length)];
      final buy = 10 + rand.next(49000) / 100.0;
      b.insert(
        db.products,
        ProductsCompanion.insert(
          name: '${category.split(' ').first} item $i',
          sku: Value('SKU-${i.toString().padLeft(6, '0')}'),
          // 13-digit EAN-like codes, unique per product.
          barcode: Value('890${(1000000000 + i).toString().padLeft(10, '0')}'),
          category: Value(category),
          unit: Value(_units[rand.next(_units.length)]),
          buyPrice: Value(double.parse(buy.toStringAsFixed(2))),
          sellPrice: Value(double.parse((buy * 1.18).toStringAsFixed(2))),
          lowStockLevel: Value(rand.next(20)),
          stockQty: const Value(0),
          createdAt: threeYearsAgo,
          updatedAt: now,
        ),
      );
    }
  });

  // ── Movements ───────────────────────────────────────────────────
  // Every product gets one opening stock row; the remainder are distributed
  // with a long tail, so a few fast movers carry most of the ledger — which is
  // what makes an unindexed `WHERE product_id = ?` scan hurt.
  var written = 0;
  const chunk = 5000;

  await db.batch((b) {
    for (var i = 1; i <= productCount && written < movementCount; i++) {
      b.insert(
        db.movements,
        MovementsCompanion.insert(
          productId: i,
          qtyDelta: 20 + rand.next(200),
          reason: 'opening_stock',
          note: const Value('seeded fixture'),
          createdAt: threeYearsAgo,
        ),
      );
      written++;
    }
  });

  while (written < movementCount) {
    final remaining = movementCount - written;
    final size = remaining < chunk ? remaining : chunk;

    await db.batch((b) {
      for (var i = 0; i < size; i++) {
        // Skewed towards low product ids: squaring a uniform draw gives a
        // realistic "20% of SKUs move 80% of the time" shape.
        final r = rand.next(1000) / 1000.0;
        final productId = 1 + (r * r * (productCount - 1)).floor();
        final outward = rand.next(100) < 70;
        final qty = 1 + rand.next(12);

        b.insert(
          db.movements,
          MovementsCompanion.insert(
            productId: productId,
            qtyDelta: outward ? -qty : qty,
            reason: _reasons[rand.next(_reasons.length)],
            note: const Value('seeded fixture'),
            createdAt: threeYearsAgo.add(Duration(seconds: rand.next(spanSeconds))),
          ),
        );
      }
    });

    written += size;
  }

  // Bring the cache into the state the app guarantees.
  await db.rebuildAllStockCaches();

  return LargeDatasetStats(productCount: productCount, movementCount: written);
}

class LargeDatasetStats {
  const LargeDatasetStats({
    required this.productCount,
    required this.movementCount,
  });

  final int productCount;
  final int movementCount;

  @override
  String toString() => '$productCount products, $movementCount movements';
}

/// Deterministic linear congruential generator.
///
/// `dart:math`'s Random is seedable too, but pinning the algorithm here means
/// a performance regression can be reproduced byte-for-byte across machines
/// and across Dart SDK upgrades.
class _Lcg {
  _Lcg(this._state);

  int _state;

  int next(int max) {
    if (max <= 0) return 0;
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state % max;
  }
}
