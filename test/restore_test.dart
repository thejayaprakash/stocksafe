// Restore acceptance tests (roadmap B.2).
//
// Restore is the one path the whole product rests on, and until now it copied
// a snapshot over the database file while SQLite still had it open (audit
// C-02). These tests pin the behaviour that makes it safe: validate before
// touching anything, archive what is being replaced, and perform the swap with
// the connection closed and the stale sidecars gone.
//
// They exercise BackupService and DatabaseHost against real files. The
// path_provider directories BackupService uses are not available in a unit
// test, so the file-level sequence is driven directly — the same sequence
// BackupRepository.restoreFromSnapshot runs in the app.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stocksafe/src/data/backup_service.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/data/repositories/database_host.dart';

void main() {
  late Directory dir;
  late File dbFile;
  late DatabaseHost host;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('stocksafe_restore');
    dbFile = File(p.join(dir.path, 'stocksafe.sqlite'));
    host = DatabaseHost(() => AppDatabase(NativeDatabase(dbFile)));
  });

  tearDown(() async {
    await host.dispose();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<int> addProduct(AppDatabase db, String name, {int qty = 0}) async {
    final now = DateTime.now();
    final id = await db.productDao.insertProduct(
      ProductsCompanion.insert(name: name, createdAt: now, updatedAt: now),
    );
    if (qty != 0) {
      await db.movementDao.recordMovement(
        productId: id,
        qtyDelta: qty,
        reason: 'opening_stock',
      );
    }
    return id;
  }

  /// Takes a checkpointed copy of the live database, with a manifest, exactly
  /// as BackupService.createSnapshot does.
  Future<File> snapshot(String name, {int? schemaVersionOverride}) async {
    await host.db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final snap = File(p.join(dir.path, name));
    await dbFile.copy(snap.path);

    final hash = sha256.convert(await snap.readAsBytes()).toString();
    await File(BackupService.manifestPathFor(snap.path)).writeAsString(
      jsonEncode({
        'schemaVersion': schemaVersionOverride ?? host.db.schemaVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'sha256': hash,
        'rowCounts': <String, int>{},
      }),
    );
    return snap;
  }

  /// The file half of a restore: close, drop stale sidecars, swap, reopen.
  Future<void> restore(File snap) async {
    await host.withDatabaseClosed(() async {
      for (final suffix in BackupService.sidecarSuffixes) {
        final sidecar = File('${dbFile.path}$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }
      await snap.copy(dbFile.path);
    });
  }

  group('Round trip', () {
    test('every row comes back exactly as it was', () async {
      final createdAt = DateTime.utc(2026, 3, 4, 11, 0);
      await host.db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Aachi Chilli Powder 100g',
          sku: const Value('ACP-100'),
          barcode: const Value('8901234567890'),
          category: const Value('Spices'),
          unit: const Value('pkt'),
          buyPrice: const Value(42.5),
          sellPrice: const Value(55.0),
          lowStockLevel: const Value(10),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      for (final delta in [100, -30, -5]) {
        await host.db.movementDao.recordMovement(
          productId: 1,
          qtyDelta: delta,
          reason: delta > 0 ? 'purchase' : 'sale',
        );
      }
      await host.db.settingDao.set('shop_name', 'Sri Lakshmi Stores');

      final before = (await host.db.productDao.getAllForExport()).single;
      final beforeMovements = await host.db.movementDao.getAllForExport();
      final snap = await snapshot('backup.db');

      // Diverge: change everything the restore should undo.
      await host.db.productDao.updateProduct(
        1,
        const ProductsCompanion(name: Value('Renamed'), buyPrice: Value(999)),
      );
      await addProduct(host.db, 'Added after snapshot', qty: 7);
      await host.db.settingDao.set('shop_name', 'Wrong Store');
      expect(await host.db.productDao.countActive(), 2);

      await restore(snap);

      // Row-level diff, not a count.
      final after = (await host.db.productDao.getAllForExport()).single;
      expect(after.id, before.id);
      expect(after.name, before.name);
      expect(after.sku, before.sku);
      expect(after.barcode, before.barcode);
      expect(after.category, before.category);
      expect(after.unit, before.unit);
      expect(after.buyPrice, before.buyPrice);
      expect(after.sellPrice, before.sellPrice);
      expect(after.lowStockLevel, before.lowStockLevel);
      expect(after.stockQty, before.stockQty);
      expect(after.createdAt, before.createdAt);

      final afterMovements = await host.db.movementDao.getAllForExport();
      expect(afterMovements, hasLength(beforeMovements.length));
      for (var i = 0; i < afterMovements.length; i++) {
        expect(afterMovements[i].id, beforeMovements[i].id);
        expect(afterMovements[i].qtyDelta, beforeMovements[i].qtyDelta);
        expect(afterMovements[i].reason, beforeMovements[i].reason);
        expect(afterMovements[i].createdAt, beforeMovements[i].createdAt);
      }

      expect(await host.db.settingDao.get('shop_name'), 'Sri Lakshmi Stores');
      expect(after.stockQty, 65, reason: '100 - 30 - 5 from the restored ledger');
    });

    test('the restored database is structurally sound', () async {
      await addProduct(host.db, 'Rice 5kg', qty: 20);
      final snap = await snapshot('backup.db');
      await addProduct(host.db, 'Noise', qty: 1);

      await restore(snap);

      final check = await host.db.customSelect('PRAGMA integrity_check').getSingle();
      expect(check.data.values.first, 'ok');

      // Nothing from the replaced database may survive beside the new file.
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('${dbFile.path}$suffix');
        if (await sidecar.exists()) {
          expect(await sidecar.length(), lessThanOrEqualTo(32),
              reason: 'a stale $suffix can overwrite restored pages');
        }
      }
    });

    test('writes after a restore land on the restored data', () async {
      await addProduct(host.db, 'Original', qty: 10);
      final snap = await snapshot('backup.db');
      await addProduct(host.db, 'Gone after restore', qty: 3);

      await restore(snap);
      await host.db.movementDao.recordMovement(
        productId: 1,
        qtyDelta: -4,
        reason: 'sale',
      );

      final products = await host.db.productDao.getAllForExport();
      expect(products, hasLength(1));
      expect(products.single.name, 'Original');
      expect(products.single.stockQty, 6, reason: '10 restored, then -4');
    });
  });

  group('Failure handling', () {
    test('an interrupted swap leaves the archive openable', () async {
      await addProduct(host.db, 'Precious', qty: 42);

      // Archive first, exactly as restoreFromSnapshot does.
      await host.db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final archive = File(p.join(dir.path, 'safety_pre_restore_x.db'));
      await dbFile.copy(archive.path);

      // Now fail mid-restore, after the connection is closed.
      await expectLater(
        host.withDatabaseClosed(() async {
          throw const FileSystemException('disk full');
        }),
        throwsA(isA<FileSystemException>()),
      );

      expect(host.isOpen, isTrue, reason: 'the app must never be left without a database');

      // The archive is a complete, openable database.
      final recovered = AppDatabase(NativeDatabase(archive));
      final products = await recovered.productDao.getAllForExport();
      expect(products.single.name, 'Precious');
      expect(products.single.stockQty, 42);
      await recovered.close();
    });

    test('a truncated snapshot is refused before anything is touched', () async {
      await addProduct(host.db, 'Live data', qty: 5);
      final service = BackupService(host.db);

      final broken = File(p.join(dir.path, 'broken.db'));
      await broken.writeAsBytes(List<int>.filled(200, 0x41)); // no SQLite header

      await expectLater(
        service.assertRestorable(broken.path),
        throwsA(isA<FormatException>()),
      );

      // Untouched.
      expect(await host.db.productDao.countActive(), 1);
      expect(host.isOpen, isTrue);
    });

    test('a snapshot from a newer schema is refused', () async {
      await addProduct(host.db, 'Live data', qty: 5);
      final snap = await snapshot(
        'future.db',
        schemaVersionOverride: DatabaseMigrations.currentVersion + 1,
      );

      final service = BackupService(host.db);
      await expectLater(
        service.assertRestorable(snap.path),
        throwsA(isA<StateError>()),
      );
      expect(await host.db.productDao.countActive(), 1);
    });
  });

  group('Integrity verification', () {
    late BackupService service;

    setUp(() => service = BackupService(host.db));

    test('a snapshot with no recorded checksum is NOT verified', () async {
      // Previously the checksum was optional, so any SQLite file dropped into
      // the folder was reported as "SHA-256 OK" (audit H-04).
      await addProduct(host.db, 'Anything');
      final snap = await snapshot('unsigned.db');
      await File(BackupService.manifestPathFor(snap.path)).delete();

      expect(await service.verifySnapshotIntegrity(snap.path), isFalse);
    });

    test('a tampered snapshot fails verification', () async {
      await addProduct(host.db, 'Anything');
      final snap = await snapshot('signed.db');
      expect(await service.verifySnapshotIntegrity(snap.path), isTrue);

      final bytes = await snap.readAsBytes();
      bytes[bytes.length - 1] ^= 0xFF; // flip a bit well past the header
      await snap.writeAsBytes(bytes);

      expect(await service.verifySnapshotIntegrity(snap.path), isFalse);
    });

    test('an intact snapshot verifies and exposes its manifest', () async {
      await addProduct(host.db, 'Anything', qty: 3);
      final snap = await snapshot('signed.db');

      expect(await service.verifySnapshotIntegrity(snap.path), isTrue);
      final manifest = await service.readManifest(snap.path);
      expect(manifest, isNotNull);
      expect(manifest!.schemaVersion, DatabaseMigrations.currentVersion);
    });

    test('force restores a snapshot that failed verification', () async {
      await addProduct(host.db, 'Anything');
      final snap = await snapshot('unsigned.db');
      await File(BackupService.manifestPathFor(snap.path)).delete();

      await expectLater(
        service.assertRestorable(snap.path),
        throwsA(isA<FormatException>()),
      );
      // The user acknowledged the warning; it must still be restorable.
      await service.assertRestorable(snap.path, force: true);
    });
  });
}
