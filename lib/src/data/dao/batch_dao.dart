import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

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
          ..where((b) => b.productId.equals(productId))
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .watch();
  }

  /// Get active batches for a product.
  Future<List<ProductBatch>> getBatchesForProduct(int productId) {
    return (select(batches)
          ..where((b) => b.productId.equals(productId))
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .get();
  }

  /// Find batches expiring within the specified number of days.
  Future<List<ProductBatch>> getExpiringBatches({Duration within = const Duration(days: 30)}) {
    final cutoff = DateTime.now().add(within);
    return (select(batches)
          ..where((b) => b.expiryDate.isNotNull() & b.expiryDate.isSmallerOrEqualValue(cutoff) & b.stockQty.isBiggerThanValue(0))
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .get();
  }

  /// Adjust stock in a batch by [delta] (positive or negative).
  Future<void> adjustBatchStock(int batchId, int delta) async {
    final now = DateTime.now();
    final batch = await (select(batches)..where((b) => b.id.equals(batchId))).getSingleOrNull();
    if (batch != null) {
      final newQty = (batch.stockQty + delta).clamp(0, 999999999);
      await (update(batches)..where((b) => b.id.equals(batchId))).write(
        BatchesCompanion(
          stockQty: Value(newQty),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Get batch by its primary ID.
  Future<ProductBatch?> getBatchById(int id) {
    return (select(batches)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  /// Find batch by product and batch number string.
  Future<ProductBatch?> getBatchByNumber(int productId, String batchNumber) {
    return (select(batches)
          ..where((b) => b.productId.equals(productId) & b.batchNumber.equals(batchNumber))
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

  /// Delete batch record if necessary.
  Future<int> deleteBatch(int batchId) {
    return (delete(batches)..where((b) => b.id.equals(batchId))).go();
  }
}
