// Photos are the first user data this app keeps outside the database, so
// the things pinned here are the two ways that goes wrong: a path that does
// not survive moving to another phone, and a backup that quietly leaves the
// pictures behind.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stocksafe/src/data/backup_archive_service.dart';
import 'package:stocksafe/src/services/product_image_service.dart';

void main() {
  late Directory support;
  late ProductImageService images;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('stocksafe_images');
    await ProductImageService.initialise(override: support);
    images = ProductImageService();
  });

  tearDown(() async {
    if (await support.exists()) await support.delete(recursive: true);
  });

  Future<File> sourceImage(String name, [int size = 64]) async {
    final file = File(p.join(support.path, name));
    await file.writeAsBytes(List<int>.filled(size, 7));
    return file;
  }

  group('where a photo is stored', () {
    test('the stored path is relative, never absolute', () async {
      // An absolute path points into one phone's sandbox. Restore the same
      // database onto another device and every photo breaks at once.
      final stored = await images.store(await sourceImage('a.jpg'),
          productId: 12);

      expect(p.isAbsolute(stored), isFalse);
      expect(stored, startsWith(ProductImageService.directoryName));
      expect(stored, contains('p12_'));
    });

    test('it resolves back to a file that exists', () async {
      final stored =
          await images.store(await sourceImage('b.jpg'), productId: 3);

      final file = ProductImageService.resolve(stored);
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
      expect(await file.length(), 64);
    });

    test('resolving the same path under a different base follows the base',
        () async {
      // This is the restore case: same database, different sandbox.
      final stored =
          await images.store(await sourceImage('c.jpg'), productId: 1);
      final first = ProductImageService.resolve(stored)!.path;

      final elsewhere =
          await Directory.systemTemp.createTemp('stocksafe_elsewhere');
      addTearDown(() => elsewhere.delete(recursive: true));
      await ProductImageService.initialise(override: elsewhere);

      final second = ProductImageService.resolve(stored)!.path;
      expect(second, isNot(first));
      expect(second, startsWith(elsewhere.path));
    });

    test('nothing, empty and whitespace all resolve to no photo', () {
      expect(ProductImageService.resolve(null), isNull);
      expect(ProductImageService.resolve(''), isNull);
      expect(ProductImageService.resolve('   '), isNull);
    });

    test('an absolute path already in the database is still usable', () {
      // Defensive: nothing writes one, but a row that holds one should
      // show its photo rather than a path glued onto the base.
      final absolute = p.join(support.path, 'legacy.jpg');
      expect(ProductImageService.resolve(absolute)!.path, absolute);
    });

    test('replacing a photo writes a new file rather than overwriting',
        () async {
      // Overwriting a path the image cache has already decoded shows the
      // previous picture until the cache is evicted, which looks exactly
      // like the new one failing to save.
      final first =
          await images.store(await sourceImage('d1.jpg'), productId: 5);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second =
          await images.store(await sourceImage('d2.jpg'), productId: 5);

      expect(first, isNot(second));
      expect(await ProductImageService.allImages(), hasLength(2));
    });

    test('deleting is forgiving of a file that has already gone', () async {
      final stored =
          await images.store(await sourceImage('e.jpg'), productId: 9);

      await images.delete(stored);
      expect(ProductImageService.resolve(stored)!.existsSync(), isFalse);

      // Again, and with nonsense: neither should throw.
      await images.delete(stored);
      await images.delete('product_images/never_existed.jpg');
      await images.delete(null);
    });

    test('a restored entry cannot be written outside the image directory',
        () async {
      // Zip entry names come from a file the user was sent, so an entry
      // called "../../something" must not escape.
      final written = await ProductImageService.restoreImage(
        '../../escaped.jpg',
        [1, 2, 3],
      );
      expect(
        p.dirname(written.path),
        p.join(support.path, ProductImageService.directoryName),
      );
      expect(p.basename(written.path), 'escaped.jpg');
    });
  });

  group('photos in the backup archive', () {
    late Directory work;
    late File database;

    setUp(() async {
      work = await Directory.systemTemp.createTemp('stocksafe_archive');
      database = File(p.join(work.path, 'stocksafe.sqlite'));
      // Enough of a SQLite header to pass inspection.
      final header = Uint8List(200);
      header.setAll(0, 'SQLite format 3\u0000'.codeUnits);
      await database.writeAsBytes(header);
    });

    tearDown(() async {
      if (await work.exists()) await work.delete(recursive: true);
    });

    test('an exported archive carries the photos', () async {
      final one = await images.store(await sourceImage('x.jpg'), productId: 1);
      final two = await images.store(await sourceImage('y.jpg'), productId: 2);

      final archive = await const BackupArchiveService().writeArchive(
        databaseFile: database,
        destination: File(p.join(work.path, 'out.zip')),
        schemaVersion: 7,
        images: await ProductImageService.allImages(),
      );

      final inspection = await const BackupArchiveService().inspect(archive);
      expect(inspection.isValid, isTrue, reason: inspection.error);
      expect(inspection.imageCount, 2);
      expect(
        inspection.images.keys,
        containsAll([p.basename(one), p.basename(two)]),
      );
      expect(inspection.describe(), contains('2 photos'));
    });

    test('they come back on the other side', () async {
      final stored =
          await images.store(await sourceImage('z.jpg', 128), productId: 4);

      final archive = await const BackupArchiveService().writeArchive(
        databaseFile: database,
        destination: File(p.join(work.path, 'out.zip')),
        schemaVersion: 7,
        images: await ProductImageService.allImages(),
      );

      // Wipe the device, so to speak, and restore into a fresh base.
      final fresh = await Directory.systemTemp.createTemp('stocksafe_fresh');
      addTearDown(() => fresh.delete(recursive: true));
      await ProductImageService.initialise(override: fresh);
      expect(ProductImageService.resolve(stored)!.existsSync(), isFalse);

      final inspection = await const BackupArchiveService().inspect(archive);
      for (final entry in inspection.images.entries) {
        await ProductImageService.restoreImage(entry.key, entry.value);
      }

      // The very same relative path now resolves, on a different device.
      final restored = ProductImageService.resolve(stored)!;
      expect(await restored.exists(), isTrue);
      expect(await restored.length(), 128);
    });

    test('an archive with no photos is still valid', () async {
      final archive = await const BackupArchiveService().writeArchive(
        databaseFile: database,
        destination: File(p.join(work.path, 'out.zip')),
        schemaVersion: 7,
      );

      final inspection = await const BackupArchiveService().inspect(archive);
      expect(inspection.isValid, isTrue, reason: inspection.error);
      expect(inspection.imageCount, 0);
      expect(inspection.describe(), isNot(contains('photo')));
    });

    test('a photo deleted between listing and writing is skipped, not fatal',
        () async {
      final stored =
          await images.store(await sourceImage('gone.jpg'), productId: 6);
      final listed = await ProductImageService.allImages();
      await images.delete(stored);

      final archive = await const BackupArchiveService().writeArchive(
        databaseFile: database,
        destination: File(p.join(work.path, 'out.zip')),
        schemaVersion: 7,
        images: listed,
      );

      final inspection = await const BackupArchiveService().inspect(archive);
      expect(inspection.isValid, isTrue, reason: inspection.error);
      expect(inspection.imageCount, 0);
    });
  });
}
