import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';
import '../../services/expiry_parser.dart';

part 'batch_dao.g.dart';

/// Data Access Object for batch and expiry tracking.
@DriftAccessor(tables: [Batches, Products])
class BatchDao extends DatabaseAccessor<AppDatabase> with _$BatchDaoMixin {
  BatchDao(super.db);

  /// Add a new batch.
  Future<int> insertBatch({
    required int productId,
    required String batchNumber,
    DateTime? expiryDate,
    int initialStock = 0,
  }) {
    final now = DateTime.now();
    return into(batches).insert(
      BatchesCompanion.insert(
        productId: productId,
        batchNumber: batchNumber,
        expiryDate: Value(expiryDate),
        stockQty: Value(initialStock),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Watch all batches for a specific product, ordered by expiry date (FIFO).
  Stream<List<ProductBatch>> watchBatchesForProduct(int productId) {
    return (select(batches)
          ..where((b) => b.productId.equals(productId) & b.deletedAt.isNull())
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .watch();
  }

  /// Get active batches for a product.
  Future<List<ProductBatch>> getBatchesForProduct(int productId) {
    return (select(batches)
          ..where((b) => b.productId.equals(productId) & b.deletedAt.isNull())
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .get();
  }

  /// Find batches expiring within the specified number of days.
  Future<List<ProductBatch>> getExpiringBatches({Duration within = const Duration(days: 30)}) {
    final cutoff = DateTime.now().add(within);
    return (select(batches)
          ..where((b) => b.deletedAt.isNull() & b.expiryDate.isNotNull() & b.expiryDate.isSmallerOrEqualValue(cutoff) & b.stockQty.isBiggerThanValue(0))
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .get();
  }

  /// Recomputes a batch's cached quantity from the ledger.
  ///
  /// Replaces the old `adjustBatchStock`, which added a delta and clamped the
  /// result at zero. Clamping silently discarded the overflow: deducting 10
  /// from a batch holding 3 left 0 and erased the fact that 7 units were
  /// unaccounted for, while the product-level ledger recorded -10 in full. The
  /// two then disagreed permanently, with nothing able to detect or repair it.
  ///
  /// Deriving the value instead means a batch can read negative — which is
  /// information, not a bug. It says the counted stock and the recorded stock
  /// disagree, which is exactly what the audit screen exists to surface.
  Future<void> rebuildBatchStock(int batchId) async {
    final sum = db.movements.qtyDelta.sum();
    final q = db.selectOnly(db.movements)
      ..addColumns([sum])
      ..where(db.movements.batchId.equals(batchId));
    final row = await q.getSingle();
    final total = row.read(sum) ?? 0;

    await (update(batches)..where((b) => b.id.equals(batchId))).write(
      BatchesCompanion(
        stockQty: Value(total),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Recomputes every batch's cached quantity from the ledger.
  ///
  /// Batches created before this was ledger-derived carry an opening figure
  /// with no matching movement rows, so [preserveUnledgered] leaves those
  /// alone rather than zeroing stock the user really has.
  /// Deliberately does not filter on `deleted_at`: rebuilding a soft-deleted
  /// batch from its own movements is harmless, and referencing that column
  /// would couple this repair routine to schema v4+. `beforeOpen` calls it
  /// during upgrades, when the database may still be at an older version.
  Future<void> rebuildAllBatchStocks({bool preserveUnledgered = true}) async {
    final guard = preserveUnledgered
        ? 'WHERE EXISTS (SELECT 1 FROM movement WHERE movement.batch_id = batch.id)'
        : '';
    await db.customStatement('''
      UPDATE batch SET stock_qty = COALESCE(
        (SELECT SUM(qty_delta) FROM movement WHERE movement.batch_id = batch.id),
        0
      ) $guard
    ''');
  }

  /// Get batch by its primary ID.
  Future<ProductBatch?> getBatchById(int id) {
    return (select(batches)..where((b) => b.id.equals(id) & b.deletedAt.isNull())).getSingleOrNull();
  }

  /// Find batch by product and batch number string.
  Future<ProductBatch?> getBatchByNumber(int productId, String batchNumber) {
    return (select(batches)
          ..where((b) => b.productId.equals(productId) & b.batchNumber.equals(batchNumber) & b.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  /// Retrieve existing batch or create a new one atomically.
  Future<int> getOrCreateBatch({
    required int productId,
    required String batchNumber,
    DateTime? expiryDate,
    int initialStock = 0,
  }) async {
    final trimmedNumber = batchNumber.trim();
    final existing = await getBatchByNumber(productId, trimmedNumber);
    if (existing != null) {
      if (expiryDate != null && existing.expiryDate == null) {
        await (update(batches)..where((b) => b.id.equals(existing.id))).write(
          BatchesCompanion(
            expiryDate: Value(expiryDate),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      return existing.id;
    }
    return insertBatch(
      productId: productId,
      batchNumber: trimmedNumber,
      expiryDate: expiryDate,
      initialStock: initialStock,
    );
  }

  /// Records what a label scan found, as a batch.
  ///
  /// The OCR feature is advertised as reading "MRP, Expiry, Pack". The expiry
  /// used to be joined into the product's SKU string, which put a date into
  /// the field used for search and CSV export and meant a scanned expiry
  /// never reached [getExpiringBatches] - so the "Expiring Soon" tab stayed
  /// empty for exactly the products the user had scanned.
  ///
  /// Idempotent on (product, batch number) via [getOrCreateBatch], so saving
  /// the same product twice updates one batch rather than piling up copies.
  ///
  /// The schema requires a batch number. When a label carries only an expiry,
  /// the date names the batch - it is what distinguishes this stock from the
  /// rest, and it reads correctly in the batch list.
  ///
  /// Returns the batch id, or null when there was nothing to record. An
  /// expiry string that cannot be parsed still yields a batch, with a null
  /// expiry date: better no date than a guessed one.
  Future<int?> recordScannedLabel({
    required int productId,
    String? batchNumber,
    String? expiryText,
  }) async {
    final parsedExpiry = parseLabelExpiry(expiryText);
    final number = batchNumber?.trim();
    final hasNumber = number != null && number.isNotEmpty;
    if (!hasNumber && parsedExpiry == null) return null;

    final label = hasNumber ? number : 'EXP ${expiryText?.trim() ?? ''}'.trim();
    if (label.isEmpty) return null;

    return getOrCreateBatch(
      productId: productId,
      batchNumber: label,
      expiryDate: parsedExpiry,
    );
  }

  /// Soft-deletes a batch. The ledger keeps `batch_id` references forever, so
  /// dropping the row would orphan movements that are, by design, never
  /// deleted. Nothing is removed.
  Future<void> softDeleteBatch(int batchId) async {
    await (update(batches)..where((b) => b.id.equals(batchId))).write(
      BatchesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Restores a soft-deleted batch.
  Future<void> restoreBatch(int batchId) async {
    await (update(batches)..where((b) => b.id.equals(batchId))).write(
      BatchesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
