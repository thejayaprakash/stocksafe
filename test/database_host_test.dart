// DatabaseHost is the primitive a safe restore needs: a guarantee that the
// connection is closed for the duration of a file swap and reopened after,
// whatever happens in between. Roadmap B.1 builds on it, so it is tested on
// its own first.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/data/repositories/database_host.dart';

void main() {
  late Directory dir;
  late File dbFile;
  late DatabaseHost host;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('stocksafe_host');
    dbFile = File(p.join(dir.path, 'stocksafe.sqlite'));
    host = DatabaseHost(() => AppDatabase(NativeDatabase(dbFile)));
  });

  tearDown(() async {
    await host.dispose();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<int> seedProduct(AppDatabase db, String name) {
    final now = DateTime.now();
    return db.productDao.insertProduct(
      ProductsCompanion.insert(name: name, createdAt: now, updatedAt: now),
    );
  }

  test('starts open and serves a working database', () async {
    expect(host.isOpen, isTrue);
    await seedProduct(host.db, 'Before');
    expect(await host.db.productDao.countActive(), 1);
  });

  test('withDatabaseClosed closes for the action and reopens after', () async {
    await seedProduct(host.db, 'Persisted');

    var wasClosedDuringAction = false;
    await host.withDatabaseClosed(() async {
      wasClosedDuringAction = !host.isOpen;
    });

    expect(wasClosedDuringAction, isTrue,
        reason: 'the connection must be closed while the action runs');
    expect(host.isOpen, isTrue, reason: 'and reopened afterwards');

    // The reopened connection sees the data that was there before.
    expect(await host.db.productDao.countActive(), 1);
  });

  test('the database instance is replaced, not reused', () async {
    final before = host.db;
    await host.reopen();
    final after = host.db;

    expect(identical(before, after), isFalse,
        reason: 'a closed drift database cannot be reopened; it must be rebuilt');
    expect(await after.productDao.countActive(), 0);
  });

  test('reopens even when the action throws', () async {
    await seedProduct(host.db, 'Survivor');

    await expectLater(
      host.withDatabaseClosed(() async => throw const FileSystemException('swap failed')),
      throwsA(isA<FileSystemException>()),
    );

    expect(host.isOpen, isTrue,
        reason: 'a failed restore must never leave the app without a database');
    expect(await host.db.productDao.countActive(), 1,
        reason: 'and the original data must still be there');
  });

  test('reading db while closed fails loudly rather than silently', () async {
    await host.withDatabaseClosed(() async {
      expect(() => host.db, throwsStateError);
    });
  });

  test('notifies listeners when the connection is replaced', () async {
    var notifications = 0;
    host.addListener(() => notifications++);

    await host.reopen();

    expect(notifications, 1,
        reason: 'the widget tree must rebuild against the new instance');
  });

  test('rejects a nested close', () async {
    await host.withDatabaseClosed(() async {
      await expectLater(
        host.withDatabaseClosed(() async {}),
        throwsStateError,
      );
    });
    expect(host.isOpen, isTrue);
  });

  test('survives a file swap performed while closed', () async {
    // The shape of a real restore: write a snapshot, change the live data,
    // then swap the snapshot back in with the connection closed.
    await seedProduct(host.db, 'Original');
    final snapshot = File(p.join(dir.path, 'snapshot.sqlite'));
    await host.withDatabaseClosed(() async {
      await dbFile.copy(snapshot.path);
    });

    await seedProduct(host.db, 'Added after snapshot');
    expect(await host.db.productDao.countActive(), 2);

    await host.withDatabaseClosed(() async {
      // Stale sidecars belong to the database being replaced.
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('${dbFile.path}$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }
      await snapshot.copy(dbFile.path);
    });

    expect(await host.db.productDao.countActive(), 1,
        reason: 'the restored snapshot must win, not the stale page cache');
    final products = await host.db.productDao.getAllForExport();
    expect(products.single.name, 'Original');
  });
}
