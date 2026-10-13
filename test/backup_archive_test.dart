// Portable backup archives (roadmap C.1/C.2).
//
// Local snapshots sit in the same sandbox as the database, so losing the
// phone loses the data and every backup at once. The archive is the copy that
// leaves the device — which makes "can it be read back on a different device"
// the test that matters.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stocksafe/src/data/backup_archive_service.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/data/repositories/database_host.dart';

void main() {
  const archives = BackupArchiveService();

  late Directory dir;
  late File dbFile;
  late DatabaseHost host;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('stocksafe_archive');
    dbFile = File(p.join(dir.path, 'stocksafe.sqlite'));
    host = DatabaseHost(() => AppDatabase(NativeDatabase(dbFile)));
  });

  tearDown(() async {
    await host.dispose();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> seed() async {
    final now = DateTime.now();
    final id = await host.db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: 'Aachi Chilli Powder 100g',
        barcode: const Value('8901234567890'),
        buyPrice: const Value(42.5),
        createdAt: now,
        updatedAt: now,
      ),
    );
    for (final delta in [100, -30]) {
      await host.db.movementDao.recordMovement(
        productId: id,
        qtyDelta: delta,
        reason: delta > 0 ? 'purchase' : 'sale',
      );
    }
    await host.db.settingDao.set('shop_name', 'Sri Lakshmi Stores');
    await host.db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  Future<File> export({String name = 'backup.zip'}) async {
    await seed();
    return host.withDatabaseClosed(() async {
      return archives.writeArchive(
        databaseFile: dbFile,
        destination: File(p.join(dir.path, name)),
        schemaVersion: DatabaseMigrations.currentVersion,
        rowCounts: const {'product': 1, 'movement': 2},
      );
    });
  }

  group('Export', () {
    test('produces a zip holding the database, a manifest and a readme',
        () async {
      final zip = await export();
      expect(await zip.exists(), isTrue);

      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, containsAll(<String>[
        BackupArchiveService.databaseEntry,
        BackupArchiveService.manifestEntry,
        BackupArchiveService.readmeEntry,
      ]));

      final manifest = jsonDecode(utf8.decode(
        archive.findFile(BackupArchiveService.manifestEntry)!.readBytes()!,
      )) as Map<String, dynamic>;
      expect(manifest['schemaVersion'], DatabaseMigrations.currentVersion);
      expect(manifest['sha256'], isA<String>());
      expect((manifest['rowCounts'] as Map)['product'], 1);
    });

    test('the readme tells a non-technical user what to do', () async {
      final zip = await export();
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final readme = utf8.decode(
        archive.findFile(BackupArchiveService.readmeEntry)!.readBytes()!,
      );

      expect(readme, contains('Import backup file'));
      expect(readme, contains('SQLite'),
          reason: 'the user should know their data outlives this app');
      expect(readme, contains('not only on your phone'));
    });

    test('the embedded database is a usable SQLite file on its own', () async {
      final zip = await export();
      final inspection = await archives.inspect(zip);
      expect(inspection.isValid, isTrue, reason: inspection.error ?? '');

      // Opened directly, as a recovery tool or a different device would.
      final extracted = File(p.join(dir.path, 'extracted.sqlite'));
      await archives.extractDatabase(inspection, extracted);

      final reopened = AppDatabase(NativeDatabase(extracted));
      final products = await reopened.productDao.getAllForExport();
      expect(products.single.name, 'Aachi Chilli Powder 100g');
      expect(products.single.stockQty, 70);
      expect(await reopened.settingDao.get('shop_name'), 'Sri Lakshmi Stores');
      await reopened.close();
    });
  });

  group('Inspect', () {
    test('reports contents without touching anything', () async {
      final zip = await export();
      final inspection = await archives.inspect(zip);

      expect(inspection.isValid, isTrue);
      expect(inspection.productCount, 1);
      expect(inspection.movementCount, 2);
      expect(inspection.schemaVersion, DatabaseMigrations.currentVersion);
      expect(inspection.describe(), contains('1 products'));
      expect(inspection.describe(), contains('2 stock movements'));

      // The live database is untouched by inspection.
      expect(await host.db.productDao.countActive(), 1);
    });

    test('rejects a file that is not a zip, in plain language', () async {
      final notZip = File(p.join(dir.path, 'notes.txt'));
      await notZip.writeAsString('just some text');

      final inspection = await archives.inspect(notZip);
      expect(inspection.isValid, isFalse);
      expect(inspection.error, contains('not a readable zip'));
    });

    test('rejects a zip that is not a StockSafe backup', () async {
      final strayZip = File(p.join(dir.path, 'holiday.zip'));
      final archive = Archive()..add(ArchiveFile.string('photo.txt', 'hello'));
      await strayZip.writeAsBytes(ZipEncoder().encode(archive));

      final inspection = await archives.inspect(strayZip);
      expect(inspection.isValid, isFalse);
      expect(inspection.error, contains('not a StockSafe backup'));
    });

    test('rejects an archive whose database does not match its checksum',
        () async {
      final zip = await export();
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());

      // Swap in a different database, leaving the original manifest in place.
      final other = File(p.join(dir.path, 'other.sqlite'));
      final otherDb = AppDatabase(NativeDatabase(other));
      await otherDb.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Tampered',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await otherDb.close();

      final rebuilt = Archive()
        ..add(ArchiveFile.bytes(
          BackupArchiveService.databaseEntry,
          await other.readAsBytes(),
        ))
        ..add(ArchiveFile.bytes(
          BackupArchiveService.manifestEntry,
          archive.findFile(BackupArchiveService.manifestEntry)!.readBytes()!,
        ));
      final tampered = File(p.join(dir.path, 'tampered.zip'));
      await tampered.writeAsBytes(ZipEncoder().encode(rebuilt));

      final inspection = await archives.inspect(tampered);
      expect(inspection.isValid, isFalse);
      expect(inspection.error, contains('damaged'));
    });

    test('an archive from a newer schema is recognised as unsupported',
        () async {
      final zip = await export();
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final manifest = jsonDecode(utf8.decode(
        archive.findFile(BackupArchiveService.manifestEntry)!.readBytes()!,
      )) as Map<String, dynamic>;
      manifest['schemaVersion'] = DatabaseMigrations.currentVersion + 5;

      final rebuilt = Archive()
        ..add(ArchiveFile.bytes(
          BackupArchiveService.databaseEntry,
          archive.findFile(BackupArchiveService.databaseEntry)!.readBytes()!,
        ))
        ..add(ArchiveFile.string(
          BackupArchiveService.manifestEntry,
          jsonEncode(manifest),
        ));
      final future = File(p.join(dir.path, 'future.zip'));
      await future.writeAsBytes(ZipEncoder().encode(rebuilt));

      final inspection = await archives.inspect(future);
      // Structurally fine...
      expect(inspection.isValid, isTrue);
      // ...but this build must not open it.
      expect(
        inspection.isSupportedBy(DatabaseMigrations.currentVersion),
        isFalse,
      );
    });
  });

  group('Import round trip', () {
    test('a backup restores onto a different, already-populated database',
        () async {
      final zip = await export();

      // A "different device": its own file, its own unrelated contents.
      final otherDir = await Directory.systemTemp.createTemp('stocksafe_other');
      addTearDown(() => otherDir.delete(recursive: true));
      final otherFile = File(p.join(otherDir.path, 'stocksafe.sqlite'));
      final otherHost =
          DatabaseHost(() => AppDatabase(NativeDatabase(otherFile)));
      addTearDown(otherHost.dispose);

      await otherHost.db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Unrelated local product',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      expect(await otherHost.db.productDao.countActive(), 1);

      final inspection = await archives.inspect(zip);
      final staged = File(p.join(otherDir.path, 'staged.sqlite'));
      await archives.extractDatabase(inspection, staged);

      await otherHost.withDatabaseClosed(() async {
        for (final suffix in ['-wal', '-shm']) {
          final sidecar = File('${otherFile.path}$suffix');
          if (await sidecar.exists()) await sidecar.delete();
        }
        await staged.copy(otherFile.path);
      });

      final restored = await otherHost.db.productDao.getAllForExport();
      expect(restored, hasLength(1));
      expect(restored.single.name, 'Aachi Chilli Powder 100g');
      expect(restored.single.stockQty, 70);
      expect(await otherHost.db.settingDao.get('shop_name'),
          'Sri Lakshmi Stores');
      expect(await otherHost.db.movementDao.getAllForExport(), hasLength(2));

      final check =
          await otherHost.db.customSelect('PRAGMA integrity_check').getSingle();
      expect(check.data.values.first, 'ok');
    });
  });
}
