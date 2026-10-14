// A backup must carry inventory and not entitlement.
//
// The Pro unlock is four rows in `setting`, and `setting` is a table inside
// `stocksafe.sqlite` — the exact file BackupArchiveService copies into the zip
// and restore swaps in wholesale. So a backup taken while Pro was active used
// to grant Pro to whoever restored it: one customer's zip forwarded on
// WhatsApp unlocked the app for everyone who imported it, and handed over that
// shop's catalogue as well.
//
// Nothing in the file is bound to a device or an account, so there is no way
// to tell the owner's own restore from a stranger's. The fix carries the data
// and drops the licence; the owner re-activates with the voucher or Play
// purchase they already hold.
//
// These drive BackupRepository itself rather than reimplementing its sequence,
// so the wiring is covered and not just the helper. path_provider has no
// implementation in a unit test, so the platform interface is faked to point
// at a temp directory.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/data/repositories/backup_repository.dart';
import 'package:stocksafe/src/data/repositories/database_host.dart';
import 'package:stocksafe/src/services/license_service.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late DatabaseHost host;
  late BackupRepository backup;

  Future<void> openIn(Directory d) async {
    PathProviderPlatform.instance = _FakePathProvider(d.path);
    host = DatabaseHost(
      () => AppDatabase(NativeDatabase(File(p.join(d.path, 'stocksafe.sqlite')))),
    );
    backup = BackupRepository(host);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('stocksafe_licence');
    await openIn(dir);
  });

  tearDown(() async {
    await host.dispose();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Future<void> seedInventory(AppDatabase db) async {
    final now = DateTime.now();
    final id = await db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: 'Maggi Masala Noodles',
        unit: const Value('pcs'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.movementDao.recordMovement(
      productId: id,
      qtyDelta: 42,
      reason: 'opening stock',
    );
  }

  test('a snapshot taken while Pro is active does not restore Pro', () async {
    await seedInventory(host.db);
    await LicenseService(host.db)
        .unlockLifetime(method: 'voucher', code: 'SERIAL-1');
    expect(await LicenseService(host.db).isProUnlocked(), isTrue);

    // The file that would be forwarded.
    final snapshot = await backup.createSnapshot();
    expect(snapshot, isNotNull);

    await backup.restoreFromSnapshot(snapshot!);

    // Inventory came back...
    expect(await host.db.productDao.countActive(), 1);
    final products = await host.db.productDao.getAllForExport();
    expect(products.single.name, 'Maggi Masala Noodles');
    expect(products.single.stockQty, 42);

    // ...the entitlement did not.
    expect(
      await LicenseService(host.db).isProUnlocked(),
      isFalse,
      reason: 'A backup that grants Pro is a paywall anyone can bypass by '
          'being sent a file.',
    );
    expect(await host.db.settingDao.get(LicenseService.keyLicenseCode), '');
    expect(await host.db.settingDao.get(LicenseService.keyUnlockMethod), '');
  });

  test('a portable archive taken while Pro is active does not restore Pro',
      () async {
    await seedInventory(host.db);
    await LicenseService(host.db)
        .unlockLifetime(method: 'play_billing', code: 'GPA.1234');

    final zip = await backup.exportArchive(into: dir);
    await backup.importArchive(zip);

    expect(await host.db.productDao.countActive(), 1);
    expect(
      await LicenseService(host.db).isProUnlocked(),
      isFalse,
      reason: 'The zip is the file users actually share, so it matters most.',
    );
  });

  test('importing someone else\'s backup does not unlock a free install',
      () async {
    // The realistic shape: a paying shop sends its backup to one that has not
    // paid. Built in its own directory so it is genuinely a different install.
    final sellerDir = await Directory.systemTemp.createTemp('stocksafe_seller');
    PathProviderPlatform.instance = _FakePathProvider(sellerDir.path);
    final sellerHost = DatabaseHost(
      () => AppDatabase(
        NativeDatabase(File(p.join(sellerDir.path, 'stocksafe.sqlite'))),
      ),
    );
    final sellerBackup = BackupRepository(sellerHost);

    await seedInventory(sellerHost.db);
    await LicenseService(sellerHost.db)
        .unlockLifetime(method: 'voucher', code: 'SERIAL-PAID');
    expect(await LicenseService(sellerHost.db).isProUnlocked(), isTrue);

    final theirZip = await sellerBackup.exportArchive(into: sellerDir);
    final carried = File(p.join(dir.path, 'from_whatsapp.zip'));
    await theirZip.copy(carried.path);
    await sellerHost.dispose();
    if (sellerDir.existsSync()) await sellerDir.delete(recursive: true);

    // Back to the free install.
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
    expect(await LicenseService(host.db).isProUnlocked(), isFalse);

    await backup.importArchive(carried);

    expect(
      await LicenseService(host.db).isProUnlocked(),
      isFalse,
      reason: "Importing someone else's backup must not unlock the app.",
    );
    // They do get the inventory — that is what import is for, and it is the
    // sender's decision to share it.
    expect(await host.db.productDao.countActive(), 1);
  });

  test('the owner can re-activate immediately after restoring', () async {
    // Clearing entitlement must not lock a paying customer out: they still
    // hold the voucher, and it still works.
    await LicenseService(host.db)
        .unlockLifetime(method: 'voucher', code: 'SERIAL-1');
    final snapshot = await backup.createSnapshot();
    await backup.restoreFromSnapshot(snapshot!);

    expect(await LicenseService(host.db).isProUnlocked(), isFalse);

    await LicenseService(host.db)
        .unlockLifetime(method: 'voucher', code: 'SERIAL-1');
    expect(await LicenseService(host.db).isProUnlocked(), isTrue);
  });
}
