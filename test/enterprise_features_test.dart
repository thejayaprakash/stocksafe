import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/backup_service.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/app_localization.dart';
import 'package:stocksafe/src/services/csv_import_service.dart';
import 'package:stocksafe/src/services/voice_assistant_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Enterprise Stocktake Audit & Discrepancy Reconciliation', () {
    test('Session lifecycle: create, count, verify variance, and atomic reconcile', () async {
      // 1. Create test products
      final now = DateTime.now();
      final p1 = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Parle-G 100g',
          category: const drift.Value('Biscuits'),
          unit: const drift.Value('pkt'),
          buyPrice: const drift.Value(8.0),
          sellPrice: const drift.Value(10.0),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final p2 = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Aavin Milk 500ml',
          category: const drift.Value('Dairy'),
          unit: const drift.Value('pkt'),
          buyPrice: const drift.Value(22.0),
          sellPrice: const drift.Value(25.0),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Record initial movements
      await db.movementDao.recordMovement(productId: p1, qtyDelta: 50, reason: 'opening_stock');
      await db.movementDao.recordMovement(productId: p2, qtyDelta: 20, reason: 'opening_stock');

      expect((await db.productDao.getById(p1))!.stockQty, 50);
      expect((await db.productDao.getById(p2))!.stockQty, 20);

      // 2. Create Audit Session
      final sessionId = await db.auditDao.createSession(
        name: 'Weekly Shelf Count',
        auditMode: 'transparent',
      );
      final session = await db.auditDao.getSession(sessionId);
      expect(session, isNotNull);
      expect(session!.status, 'in_progress');

      // 3. Record physical counts:
      // p1: 45 counted (shortage of -5)
      // p2: 22 counted (surplus of +2)
      await db.auditDao.recordCount(
        sessionId: sessionId,
        productId: p1,
        countedQty: 45,
        expectedQty: 50,
      );
      await db.auditDao.recordCount(
        sessionId: sessionId,
        productId: p2,
        countedQty: 22,
        expectedQty: 20,
      );

      final items = await db.auditDao.getSessionItems(sessionId);
      expect(items.length, 2);

      final item1 = items.firstWhere((i) => i.productId == p1);
      expect(item1.difference, -5);
      expect(item1.isReconciled, isFalse);

      final item2 = items.firstWhere((i) => i.productId == p2);
      expect(item2.difference, 2);
      expect(item2.isReconciled, isFalse);

      // 4. Reconcile Session
      await db.auditDao.reconcileSession(sessionId);

      // 5. Verify Ledger Movements
      final p1Movements = await db.movementDao.watchForProduct(p1).first;
      expect(p1Movements.first.qtyDelta, -5);
      expect(p1Movements.first.reason, 'stocktake_adjustment');
      expect(p1Movements.first.auditSessionId, sessionId);

      final p2Movements = await db.movementDao.watchForProduct(p2).first;
      expect(p2Movements.first.qtyDelta, 2);
      expect(p2Movements.first.reason, 'stocktake_adjustment');

      // 6. Verify Updated Stock Caches
      expect((await db.productDao.getById(p1))!.stockQty, 45);
      expect((await db.productDao.getById(p2))!.stockQty, 22);

      // 7. Verify Completed Session State
      final updatedSession = await db.auditDao.getSession(sessionId);
      expect(updatedSession!.status, 'completed');
      expect(updatedSession.completedAt, isNotNull);
      // Net valuation impact: (-5 * 8) + (2 * 22) = -40 + 44 = +4.0
      expect(updatedSession.netDiscrepancyValue, 4.0);

      // 8. Prevent duplicate reconciliation attempt
      expect(
        () => db.auditDao.reconcileSession(sessionId),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Category and Batch Tracking', () {
    test('Category filtering and distinct category list', () async {
      final now = DateTime.now();
      await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Butter 100g',
          category: const drift.Value('Dairy'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Cheese Slice',
          category: const drift.Value('Dairy'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Turmeric Powder',
          category: const drift.Value('Spices'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final categories = await db.productDao.getCategories();
      expect(categories, ['Dairy', 'Spices']);

      final dairyProducts = await db.productDao.watchAll(category: 'Dairy').first;
      expect(dairyProducts.length, 2);

      final spicesProducts = await db.productDao.watchAll(category: 'Spices').first;
      expect(spicesProducts.length, 1);
      expect(spicesProducts.first.name, 'Turmeric Powder');
    });

    test('BatchDao tracks batches and identifies expiring stock', () async {
      final now = DateTime.now();
      final prodId = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Curd 500g',
          category: const drift.Value('Dairy'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Expiring in 5 days
      await db.batchDao.insertBatch(
        productId: prodId,
        batchNumber: 'B101',
        expiryDate: now.add(const Duration(days: 5)),
        initialStock: 25,
      );

      // Expiring in 60 days
      await db.batchDao.insertBatch(
        productId: prodId,
        batchNumber: 'B102',
        expiryDate: now.add(const Duration(days: 60)),
        initialStock: 50,
      );

      final expiringSoon = await db.batchDao.getExpiringBatches(within: const Duration(days: 10));
      expect(expiringSoon.length, 1);
      expect(expiringSoon.first.batchNumber, 'B101');
      expect(expiringSoon.first.stockQty, 25);
    });

    test('MovementDao atomically records movements and updates batch stock', () async {
      final now = DateTime.now();
      final pId = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Bread 400g',
          buyPrice: const drift.Value(30.0),
          sellPrice: const drift.Value(40.0),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 1. Create a batch with getOrCreateBatch
      final bId = await db.batchDao.getOrCreateBatch(
        productId: pId,
        batchNumber: 'LOT-999',
        expiryDate: now.add(const Duration(days: 4)),
      );

      // 2. Stock In with batchId
      await db.movementDao.recordMovement(
        productId: pId,
        qtyDelta: 30,
        reason: 'Stock in',
        batchId: bId,
      );

      var batch = await db.batchDao.getBatchById(bId);
      expect(batch!.stockQty, 30);
      expect((await db.productDao.getById(pId))!.stockQty, 30);

      // 3. Stock Out with batchId
      await db.movementDao.recordMovement(
        productId: pId,
        qtyDelta: -10,
        reason: 'Stock out',
        batchId: bId,
      );

      batch = await db.batchDao.getBatchById(bId);
      expect(batch!.stockQty, 20);
      expect((await db.productDao.getById(pId))!.stockQty, 20);

      // 4. Verify movement audit trail includes batchId
      final movements = await db.movementDao.watchForProduct(pId).first;
      expect(movements.first.batchId, bId);
    });

    test('ProductDao computes live inventory valuation metrics accurately', () async {
      final now = DateTime.now();
      final p1 = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Item A',
          buyPrice: const drift.Value(10.0),
          sellPrice: const drift.Value(15.0),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final p2 = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Item B',
          buyPrice: const drift.Value(50.0),
          sellPrice: const drift.Value(80.0),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.movementDao.recordMovement(productId: p1, qtyDelta: 10, reason: 'Stock in'); // cost: 100, retail: 150
      await db.movementDao.recordMovement(productId: p2, qtyDelta: 2, reason: 'Stock in');  // cost: 100, retail: 160

      final valuation = await db.productDao.getInventoryValuation();
      expect(valuation.totalProducts, 2);
      expect(valuation.totalUnits, 12);
      expect(valuation.totalCostValue, 200.0);
      expect(valuation.totalRetailValue, 310.0);
      expect(valuation.potentialProfit, 110.0);
      expect(valuation.marginPercent, closeTo(55.0, 0.01));
    });
  });

  group('Streaming CSV Catalog Importer', () {
    test('Imports products and generates opening stock movements atomically', () async {
      final importer = CsvImportService(db);
      const csv = '''
Product Name,Category,Barcode,Buy Price,Sell Price,Initial Stock,Unit
Tata Tea Gold 250g,Beverages,8901052002145,120,150,40,pkt
Maggi Noodles,Snacks,8901058852331,12,14,100,pack
Sugar 1kg,Groceries,,42,48,200,kg
''';

      final result = await importer.importFromCsvString(csv);

      expect(result.totalRows, 3);
      expect(result.importedCount, 3);
      expect(result.skippedCount, 0);
      expect(result.errors.isEmpty, isTrue);

      final products = await db.productDao.getAllForExport();
      expect(products.length, 3);

      final tea = products.firstWhere((p) => p.name.contains('Tata Tea'));
      expect(tea.category, 'Beverages');
      expect(tea.barcode, '8901052002145');
      expect(tea.stockQty, 40);

      // Verify opening stock was recorded in immutable ledger
      final movements = await db.movementDao.watchForProduct(tea.id).first;
      expect(movements.length, 1);
      expect(movements.first.reason, 'opening_stock');
      expect(movements.first.qtyDelta, 40);
    });

    test('Gracefully handles empty CSV or missing name column', () async {
      final importer = CsvImportService(db);

      final emptyResult = await importer.importFromCsvString('');
      expect(emptyResult.importedCount, 0);
      expect(emptyResult.errors.first, contains('empty'));

      final missingNameResult = await importer.importFromCsvString('Price,Stock\n100,10');
      expect(missingNameResult.importedCount, 0);
      expect(missingNameResult.errors.first, contains('Name'));
    });
  });

  group('Cryptographic Backup Integrity Verification', () {
    test('Verifies valid SQLite header and detects invalid/corrupted file bytes', () async {
      final backup = BackupService(db);
      final tempDir = Directory.systemTemp.createTempSync('stocksafe_test_');

      // Create a dummy file that does not have SQLite magic bytes (> 100 bytes)
      final badFile = File('${tempDir.path}/corrupt.db');
      await badFile.writeAsString('THIS IS NOT A SQLITE DATABASE FILE AT ALL AND IT IS CORRUPT ' * 5);

      final isCorruptValid = await backup.verifySnapshotIntegrity(badFile.path);
      expect(isCorruptValid, isFalse);

      // A corrupt file is refused before anything is touched.
      await expectLater(
        backup.assertRestorable(badFile.path),
        throwsA(isA<FormatException>()),
      );

      tempDir.deleteSync(recursive: true);
    });
  });

  group('Bilingual Localization Engine', () {
    test('Provides English and Tamil strings reactively', () {
      AppLocale.instance.setLanguage(AppLanguage.english);
      expect(AppLocale.tr('products'), 'Products');
      expect(AppLocale.tr('low_stock'), 'Low Stock');
      expect(AppLocale.tr('stock_audit'), 'Stocktake Audit');

      AppLocale.instance.setLanguage(AppLanguage.tamil);
      expect(AppLocale.tr('products'), 'பொருட்கள்');
      expect(AppLocale.tr('low_stock'), 'குறைந்த இருப்பு');
      expect(AppLocale.tr('stock_audit'), 'இருப்பு தணிக்கை');

      // Reset back to English
      AppLocale.instance.setLanguage(AppLanguage.english);
    });
  });

  group('Voice Assistant Command Parser (Bilingual English & Tamil)', () {
    test('Parses English retail queries accurately', () {
      final lowStock = VoiceAssistantService.parseCommand('Which items are low stock?');
      expect(lowStock.intent, VoiceIntentType.navigateLowStock);

      final expiring = VoiceAssistantService.parseCommand('Show me expiring items');
      expect(expiring.intent, VoiceIntentType.navigateExpiring);

      final valuation = VoiceAssistantService.parseCommand('What is my inventory valuation?');
      expect(valuation.intent, VoiceIntentType.navigateValuation);

      final stockIn = VoiceAssistantService.parseCommand('Add 15 Parle-G');
      expect(stockIn.intent, VoiceIntentType.quickStockMovement);
      expect(stockIn.isStockIn, isTrue);
      expect(stockIn.quantity, 15);
      expect(stockIn.productName, contains('parle-g'));

      final search = VoiceAssistantService.parseCommand('Find Tata Tea');
      expect(search.intent, VoiceIntentType.search);
      expect(search.searchQuery, 'tata tea');
    });

    test('Parses Tamil (தமிழ்) retail voice queries accurately', () {
      final lowStock = VoiceAssistantService.parseCommand('குறைந்த இருப்பு பொருட்கள் என்ன');
      expect(lowStock.intent, VoiceIntentType.navigateLowStock);

      final expiring = VoiceAssistantService.parseCommand('காலாவதி பொருட்கள் காட்டு');
      expect(expiring.intent, VoiceIntentType.navigateExpiring);

      final valuation = VoiceAssistantService.parseCommand('மொத்த மதிப்பு என்ன');
      expect(valuation.intent, VoiceIntentType.navigateValuation);

      final audit = VoiceAssistantService.parseCommand('இருப்பு தணிக்கை தொடங்கு');
      expect(audit.intent, VoiceIntentType.navigateAudit);

      final stockOut = VoiceAssistantService.parseCommand('விற்பனை 5 ஆவின் பால்');
      expect(stockOut.intent, VoiceIntentType.quickStockMovement);
      expect(stockOut.isStockIn, isFalse);
      expect(stockOut.quantity, 5);
      expect(stockOut.productName, contains('ஆவின் பால்'));
    });
  });

  group('Backup Hygiene and Overdue Detection', () {
    test('Correctly identifies overdue backups', () async {
      final backup = BackupService(db);
      // Initially overdue since never backed up
      final isOverdueInitial = await backup.isBackupOverdue();
      expect(isOverdueInitial, isTrue);
    });
  });
}
