// A scanned expiry has to reach the expiry alert, not a text field.
//
// The OCR button is labelled "MRP, Expiry, Pack" and the app has an
// "Expiring Soon" tab driven by batchDao.getExpiringBatches(). Before this,
// a scanned expiry was joined into the SKU string, so the tab stayed empty
// for every scanned product and the SKU carried a date into search and CSV
// export. These tests pin the join between the two.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> newProduct(String name) {
    final now = DateTime.now();
    return db.productDao.insertProduct(
      ProductsCompanion.insert(name: name, createdAt: now, updatedAt: now),
    );
  }

  /// The real code path the OCR "Apply" button runs, not a copy of it.
  Future<void> recordScanned(int productId, String? batch, String? expiry) =>
      db.batchDao.recordScannedLabel(
        productId: productId,
        batchNumber: batch,
        expiryText: expiry,
      );

  test('a scanned expiry reaches the Expiring Soon query once stock is in',
      () async {
    final id = await newProduct('Aachi Sambar Powder 200g');
    final soon = DateTime.now().add(const Duration(days: 12));
    await recordScanned(id, 'B2026A', '${soon.day}/${soon.month}/${soon.year}');

    // getExpiringBatches requires stockQty > 0 - only stock you hold can go
    // to waste. The stock entry page lists the product's batches, so the
    // batch the scan created is what the user picks here.
    final batch = (await db.batchDao.getBatchesForProduct(id)).single;
    await db.movementDao.recordMovement(
      productId: id,
      qtyDelta: 24,
      reason: 'purchase',
      batchId: batch.id,
    );

    final expiring = await db.batchDao.getExpiringBatches(
      within: const Duration(days: 30),
    );
    expect(expiring.map((b) => b.batchNumber), contains('B2026A'));
  });

  test('a scanned batch holding nothing raises no alert', () async {
    // Nothing is at risk until stock is recorded against it. The batch exists
    // and is pickable; it just has nothing to lose yet.
    final id = await newProduct('Aachi Sambar Powder 200g');
    final soon = DateTime.now().add(const Duration(days: 12));
    await recordScanned(id, 'B2026A', '${soon.day}/${soon.month}/${soon.year}');

    final expiring = await db.batchDao.getExpiringBatches(
      within: const Duration(days: 30),
    );
    expect(expiring, isEmpty);
  });

  test('the scanned values do not touch the SKU', () async {
    final id = await newProduct('Aachi Sambar Powder 200g');
    await recordScanned(id, 'B2026A', '11/2027');

    final product = await db.productDao.getById(id);
    // The regression: SKU used to read "B2026A · EXP:11/2027", which the
    // product search and the CSV export both carry.
    expect(product!.sku, isNull);
  });

  test('the batch is visible on the product', () async {
    final id = await newProduct('Aachi Sambar Powder 200g');
    await recordScanned(id, 'B2026A', '11/2027');

    final batches = await db.batchDao.getBatchesForProduct(id);
    expect(batches, hasLength(1));
    expect(batches.single.batchNumber, 'B2026A');
    expect(batches.single.expiryDate, DateTime(2027, 11, 30, 23, 59, 59));
  });

  test('an expiry with no batch number still records', () async {
    final id = await newProduct('Loose Jaggery');
    await recordScanned(id, null, '11/2027');

    final batches = await db.batchDao.getBatchesForProduct(id);
    expect(batches.single.batchNumber, 'EXP 11/2027');
    expect(batches.single.expiryDate, isNotNull);
  });

  test('saving twice updates the one batch rather than duplicating', () async {
    final id = await newProduct('Aachi Sambar Powder 200g');
    await recordScanned(id, 'B2026A', '11/2027');
    await recordScanned(id, 'B2026A', '11/2027');

    expect(await db.batchDao.getBatchesForProduct(id), hasLength(1));
  });

  test('an unreadable date still records the batch, without an expiry', () async {
    final id = await newProduct('Aachi Sambar Powder 200g');
    await recordScanned(id, 'B2026A', 'BEST BEFORE');

    final batches = await db.batchDao.getBatchesForProduct(id);
    expect(batches.single.batchNumber, 'B2026A');
    expect(batches.single.expiryDate, isNull,
        reason: 'better no date than a guessed one');
  });

  test('a scan that found nothing writes no batch', () async {
    final id = await newProduct('Loose Jaggery');
    await recordScanned(id, null, null);
    expect(await db.batchDao.getBatchesForProduct(id), isEmpty);
  });

  test('a far expiry stays out of the 30-day window', () async {
    final id = await newProduct('Aachi Sambar Powder 200g');
    await recordScanned(id, 'B2026A', '11/2027');

    final expiring = await db.batchDao.getExpiringBatches(
      within: const Duration(days: 30),
    );
    expect(expiring.map((b) => b.batchNumber), isNot(contains('B2026A')));
  });
}
