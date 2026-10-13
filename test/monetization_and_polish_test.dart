import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode, Brightness;
import 'package:flutter_test/flutter_test.dart';

import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/csv_import_service.dart';
import 'package:stocksafe/src/services/diagnostic_service.dart';
import 'package:stocksafe/src/services/license_key.dart';
import 'package:stocksafe/src/services/license_service.dart';
import 'package:stocksafe/src/services/theme_service.dart';

void main() {
  late AppDatabase db;
  late LicenseService licenseService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    licenseService = LicenseService(db);
    // Ensure clean settings
    await licenseService.resetForTesting();
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 5: Monetization & License Enforcement', () {
    test('Free tier allows up to 50 active products and enforces limit at 50', () async {
      expect(await licenseService.isProUnlocked(), isFalse);
      expect(await licenseService.getFreeLimit(), equals(50));
      expect(await licenseService.canAddProduct(), isTrue);
      expect(await licenseService.getRemainingFreeProducts(), equals(50));

      // Insert 50 products
      final now = DateTime.now();
      for (int i = 1; i <= 50; i++) {
        await db.productDao.insertProduct(
          ProductsCompanion.insert(
            name: 'Product $i',
            unit: const Value('pcs'),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      final count = await db.productDao.countActive();
      expect(count, equals(50));

      // Now at limit: canAddProduct must be false
      expect(await licenseService.canAddProduct(), isFalse);
      expect(await licenseService.getRemainingFreeProducts(), equals(0));
    });

    test('One-time lifetime unlock lifts product count gating', () async {
      final now = DateTime.now();
      for (int i = 1; i <= 50; i++) {
        await db.productDao.insertProduct(
          ProductsCompanion.insert(
            name: 'Product $i',
            unit: const Value('pcs'),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      expect(await licenseService.canAddProduct(), isFalse);

      // Perform one-time lifetime unlock
      await licenseService.unlockLifetime(method: 'play_billing');
      expect(await licenseService.isProUnlocked(), isTrue);
      expect(await licenseService.canAddProduct(), isTrue);
      expect(await licenseService.getRemainingFreeProducts(), equals(-1));

      // Can now add 51st product
      final id51 = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Product 51 (Pro)',
          unit: const Value('pcs'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(id51, isPositive);
      expect(await db.productDao.countActive(), equals(51));
    });

    test('only a correctly signed voucher unlocks', () async {
      // The old check accepted any string starting STOCKSAFE with twelve or
      // more characters, so a single guess got in. These are the guesses.
      for (final guess in [
        'INVALID-KEY',
        '12345',
        'STOCKSAFE123',
        'STOCKSAFE-ABCD-1234',
        'STOCKSAFEAAAAAAAAAAAA',
        'PRO2026',
        'KIRANAUNLIMITED',
        'TESTVIP',
      ]) {
        expect(await licenseService.validateAndActivateOfflineKey(guess), isFalse,
            reason: '"$guess" must not unlock the app');
      }
      expect(await licenseService.isProUnlocked(), isFalse);

      // A minted voucher does.
      final voucher = LicenseKey.mint('KIRANA0001');
      expect(await licenseService.validateAndActivateOfflineKey(voucher), isTrue);
      expect(await licenseService.isProUnlocked(), isTrue);
    });

    test('a voucher survives being read off paper and typed by hand', () async {
      final voucher = LicenseKey.mint('SHOP42');
      for (final typed in [
        voucher.toLowerCase(),
        voucher.replaceAll('-', ' '),
        ' $voucher ',
      ]) {
        await licenseService.resetForTesting();
        expect(await licenseService.validateAndActivateOfflineKey(typed), isTrue,
            reason: 'case, spacing and dashes must not matter');
      }
    });

    test('altering one character of a voucher invalidates it', () async {
      final voucher = LicenseKey.mint('KIRANA0002');
      final tampered = voucher.substring(0, voucher.length - 1) +
          (voucher.endsWith('A') ? 'B' : 'A');

      expect(await licenseService.validateAndActivateOfflineKey(tampered), isFalse);
      expect(await licenseService.isProUnlocked(), isFalse);
    });

    test('restore reports only what this device actually holds', () async {
      // It used to call unlockLifetime() unconditionally, so tapping
      // "Restore Purchases" — a button Play requires — granted Pro to anyone.
      expect(await licenseService.isProUnlocked(), isFalse);
      expect(await licenseService.restorePurchases(), isFalse);
      expect(await licenseService.isProUnlocked(), isFalse,
          reason: 'restore must never create an entitlement');

      await licenseService.unlockLifetime(method: 'offline_voucher');
      expect(await licenseService.restorePurchases(), isTrue);
    });

    test('Rule 5: Existing data operations are NEVER blocked when at or over limit', () async {
      final now = DateTime.now();
      // Insert 50 products
      for (int i = 1; i <= 50; i++) {
        final prodId = await db.productDao.insertProduct(
          ProductsCompanion.insert(
            name: 'Item $i',
            unit: const Value('pcs'),
            sellPrice: Value(10.0 * i),
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Record stock movement
        await db.movementDao.recordMovement(
          productId: prodId,
          qtyDelta: 20,
          reason: 'opening_stock',
          createdAt: now,
        );
      }

      expect(await licenseService.canAddProduct(), isFalse);

      // 1. Viewing & searching works
      final prods = await db.productDao.watchAll().first;
      expect(prods.length, equals(50));

      final search = await db.productDao.watchAll(query: 'Item 25').first;
      expect(search.length, equals(1));
      expect(search.first.name, equals('Item 25'));

      // 2. Stock movements (inward and outward) work without restriction
      await db.movementDao.recordMovement(
        productId: prods.first.id,
        qtyDelta: -5,
        reason: 'sale',
      );
      final updatedFirst = await db.productDao.getById(prods.first.id);
      expect(updatedFirst?.stockQty, equals(15)); // 20 - 5 = 15

      // 3. Inventory valuation works
      final valuation = await db.productDao.getInventoryValuation();
      expect(valuation.totalUnits, isPositive);

      // 4. Full export works
      final exportData = await db.productDao.getAllForExport();
      expect(exportData.length, equals(50));
    });

    test('CsvImportService respects free tier limit and informs user of skipped rows', () async {
      final now = DateTime.now();
      // Pre-fill 48 products
      for (int i = 1; i <= 48; i++) {
        await db.productDao.insertProduct(
          ProductsCompanion.insert(
            name: 'Old Item $i',
            unit: const Value('pcs'),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      expect(await db.productDao.countActive(), equals(48));

      // CSV with 5 new products (would total 53)
      const csvData = '''
Product Name,Unit,Buy Price,MRP,Initial Stock
New Item 1,pcs,10,20,5
New Item 2,pcs,10,20,5
New Item 3,pcs,10,20,5
New Item 4,pcs,10,20,5
New Item 5,pcs,10,20,5
''';

      final importer = CsvImportService(db);
      final result = await importer.importFromCsvString(csvData);

      // Should import 2 (reaching 50), and skip remaining 3 with free limit message
      expect(result.importedCount, equals(2));
      expect(result.skippedCount, equals(3));
      expect(result.hasErrors, isTrue);
      expect(result.errors.first, contains('Free tier limit reached (50 products)'));
      expect(await db.productDao.countActive(), equals(50));

      // Unlock Pro and import the rest
      await licenseService.unlockLifetime();
      const csvDataRemaining = '''
Product Name,Unit,Buy Price,MRP,Initial Stock
New Item 3,pcs,10,20,5
New Item 4,pcs,10,20,5
New Item 5,pcs,10,20,5
''';
      final proResult = await importer.importFromCsvString(csvDataRemaining);
      expect(proResult.importedCount, equals(3));
      expect(await db.productDao.countActive(), equals(53));
    });
  });

  group('Phase 5: Theming, Appearance & Diagnostic Health', () {
    test('ThemeService initializes, toggles, and persists theme modes to SQLite', () async {
      final themeService = ThemeService.instance;
      await themeService.init(db);

      // Default system
      expect(themeService.mode, equals(ThemeMode.system));

      // Switch to Dark Mode
      await themeService.setThemeMode(ThemeMode.dark);
      expect(themeService.mode, equals(ThemeMode.dark));
      expect(await db.settingDao.get(ThemeService.keyThemeMode), equals('dark'));

      // Switch to Light Mode
      await themeService.setThemeMode(ThemeMode.light);
      expect(themeService.mode, equals(ThemeMode.light));
      expect(await db.settingDao.get(ThemeService.keyThemeMode), equals('light'));

      // Validate theme definitions
      final light = ThemeService.lightTheme;
      final dark = ThemeService.darkTheme;
      expect(light.brightness, equals(Brightness.light));
      expect(dark.brightness, equals(Brightness.dark));
    });

    test('DiagnosticService audits movement ledger integrity and detects cache discrepancies', () async {
      final diag = DiagnosticService.instance;
      final now = DateTime.now();

      // Insert product with stock movement
      final prodId = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Audit Oil',
          unit: const Value('L'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.movementDao.recordMovement(
        productId: prodId,
        qtyDelta: 30,
        reason: 'opening_stock',
        createdAt: now,
      );

      // Initial audit: 100% match
      var mismatches = await diag.auditLedgerIntegrity(db);
      expect(mismatches, isEmpty);

      // Simulate an external cache corruption (e.g. directly setting product.stock_qty = 10 instead of 30)
      await (db.update(db.products)..where((p) => p.id.equals(prodId)))
          .write(const ProductsCompanion(stockQty: Value(10)));

      // Audit must detect mismatch
      mismatches = await diag.auditLedgerIntegrity(db);
      expect(mismatches.length, equals(1));
      expect(mismatches.first.cachedStock, equals(10));
      expect(mismatches.first.ledgerStock, equals(30));
      expect(mismatches.first.discrepancy, equals(-20));

      // Rebuild cache restores 100% integrity
      await db.rebuildAllStockCaches();
      mismatches = await diag.auditLedgerIntegrity(db);
      expect(mismatches, isEmpty);
    });

    test('DiagnosticService logs events and calculates crash-free rate', () {
      final diag = DiagnosticService.instance;
      diag.clearLogs();

      diag.log('Test session started');
      diag.log('Scan completed successfully');
      expect(diag.logs.length, equals(2));
      expect(diag.crashFreeRate, equals(100.0));

      final report = diag.exportDiagnosticReport();
      expect(report, contains('Test session started'));
      expect(report, contains('100.0%'));
    });
  });
}
