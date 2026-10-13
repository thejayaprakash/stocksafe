// CSV import from a real supplier file.
//
// Pasting was the only way in, which is unusable for the case this feature
// advertises: a price list is a file, often thousands of rows. These tests
// cover what real exports actually look like — BOMs, CRLF, quoted commas,
// currency symbols — rather than the tidy sample in the hint text.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/csv_import_service.dart';
import 'package:stocksafe/src/services/license_service.dart';

void main() {
  late AppDatabase db;
  late CsvImportService importer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    importer = CsvImportService(db);
  });
  tearDown(() => db.close());

  group('Real-world files', () {
    test('imports a plain supplier list', () async {
      const csv = 'Name,Category,Barcode,Buy Price,Sell Price,Initial Stock\n'
          'Milk 500ml,Dairy,8901234567890,25,30,50\n'
          'Biscuits,Snacks,8909876543210,10,12,100\n';

      final result = await importer.importFromCsvString(csv);

      expect(result.importedCount, 2);
      expect(result.errors, isEmpty);
      final products = await db.productDao.getAllForExport();
      expect(products.map((p) => p.name),
          containsAll(<String>['Milk 500ml', 'Biscuits']));
      // Opening stock becomes a ledger entry, not just a number.
      expect(products.firstWhere((p) => p.name == 'Milk 500ml').stockQty, 50);
      expect(await db.movementDao.getAllForExport(), hasLength(2));
    });

    test('handles CRLF line endings, as every Windows export has', () async {
      const csv = 'Name,Barcode,Initial Stock\r\n'
          'Rice 5kg,8901111111111,20\r\n'
          'Dal 1kg,8902222222222,15\r\n';

      final result = await importer.importFromCsvString(csv);
      expect(result.importedCount, 2);
      expect(result.errors, isEmpty);
    });

    test('a quoted field containing a comma stays one field', () async {
      const csv = 'Name,Category,Initial Stock\n'
          '"Rice, Basmati 5kg",Grains,10\n';

      final result = await importer.importFromCsvString(csv);
      expect(result.importedCount, 1);
      final product = (await db.productDao.getAllForExport()).single;
      expect(product.name, 'Rice, Basmati 5kg');
      expect(product.category, 'Grains');
    });

    test('prices with currency symbols are read', () async {
      const csv = 'Name,Buy Price,Sell Price\n'
          'Ghee 1L,Rs 450.50,520\n';

      final result = await importer.importFromCsvString(csv);
      expect(result.importedCount, 1);
      final product = (await db.productDao.getAllForExport()).single;
      expect(product.buyPrice, 450.50);
      expect(product.sellPrice, 520);
    });

    test('header synonyms from different suppliers all map', () async {
      const csv = 'Product Name,Item Code,EAN,MRP,Opening Stock\n'
          'Sugar 1kg,SUG-1,8903333333333,52,30\n';

      final result = await importer.importFromCsvString(csv);
      expect(result.importedCount, 1, reason: result.errors.join('; '));
      final product = (await db.productDao.getAllForExport()).single;
      expect(product.sku, 'SUG-1');
      expect(product.barcode, '8903333333333');
      expect(product.sellPrice, 52);
      expect(product.stockQty, 30);
    });

    test('blank lines and trailing newlines are ignored', () async {
      const csv = 'Name,Initial Stock\n'
          'Item A,5\n'
          '\n'
          'Item B,6\n'
          '\n';

      final result = await importer.importFromCsvString(csv);
      expect(result.importedCount, 2);
    });
  });

  group('Refusals are explained', () {
    test('a file with no Name column says so', () async {
      const csv = 'Barcode,Price\n8901234567890,20\n';
      final result = await importer.importFromCsvString(csv);

      expect(result.importedCount, 0);
      expect(result.errors.single, contains('Name'));
    });

    test('an empty file says so', () async {
      final result = await importer.importFromCsvString('   \n  \n');
      expect(result.importedCount, 0);
      expect(result.errors.single, contains('empty'));
    });

    test('a row with no name is skipped, the rest still import', () async {
      const csv = 'Name,Initial Stock\n'
          'Good Item,5\n'
          ',7\n'
          'Another Good Item,3\n';

      final result = await importer.importFromCsvString(csv);
      expect(result.importedCount, 2,
          reason: 'one bad row must not sink the file');
      expect(result.skippedCount, 1);
      expect(result.errors.single, contains('Row 3'));
    });
  });

  group('Duplicate barcodes', () {
    test('in-file and catalogue duplicates are reported differently',
        () async {
      // The two cases need different things from the user: one is a bad file,
      // the other means they already stock the item.
      const first = 'Name,Barcode\nRice 5kg,8901234567890\n';
      await importer.importFromCsvString(first);

      const second = 'Name,Barcode\n'
          'Rice again,8901234567890\n'
          'Dal 1kg,8902222222222\n'
          'Dal duplicate,8902222222222\n';
      final result = await importer.importFromCsvString(second);

      expect(result.importedCount, 1, reason: 'only Dal 1kg is new');
      expect(result.skippedCount, 2);
      final joined = result.errors.join(' | ');
      expect(joined, contains('already in your catalogue'));
      expect(joined, contains('repeated earlier in this file'));
    });

    test('re-importing the same file adds nothing', () async {
      const csv = 'Name,Barcode,Initial Stock\n'
          'Rice 5kg,8901234567890,10\n'
          'Dal 1kg,8902222222222,7\n';

      await importer.importFromCsvString(csv);
      final second = await importer.importFromCsvString(csv);

      expect(second.importedCount, 0);
      expect(await db.productDao.countActive(), 2);
    });

    test('the free tier stops at its limit and says why', () async {
      final rows = StringBuffer('Name,Initial Stock\n');
      for (var i = 1; i <= 60; i++) {
        rows.writeln('Item $i,1');
      }

      final result = await importer.importFromCsvString(rows.toString());

      expect(result.importedCount, 50);
      expect(result.skippedCount, 10);
      expect(result.errors.join(' '), contains('Free tier limit'));
      expect(await db.productDao.countActive(), 50);
    });

    test('rows without a barcode never collide with each other', () async {
      const csv = 'Name,Initial Stock\n'
          'Loose rice,5\n'
          'Loose dal,5\n'
          'Loose sugar,5\n';

      final result = await importer.importFromCsvString(csv);
      expect(result.importedCount, 3);
    });
  });

  group('Scale', () {
    test('a thousand-row supplier file imports', () async {
      // The paste box capped this in practice. A real price list does not.
      // Pro first: on the free tier the importer correctly stops at the
      // 50-product limit, which is covered in monetization_and_polish_test.
      await LicenseService(db).unlockLifetime(method: 'test');
      final rows = StringBuffer('Name,Barcode,Buy Price,Initial Stock\n');
      for (var i = 1; i <= 1000; i++) {
        rows.writeln('Item $i,89${10000000000 + i},${i % 90 + 10},${i % 25}');
      }

      final sw = Stopwatch()..start();
      final result = await importer.importFromCsvString(rows.toString());
      sw.stop();

      expect(result.importedCount, 1000,
          reason: result.errors.take(3).join('; '));
      expect(await db.productDao.countActive(), 1000);
      // Not a budget so much as a guard against the per-row query returning.
      expect(sw.elapsed.inSeconds, lessThan(30));
    });
  });
}
