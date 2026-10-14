import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/support_bundle.dart';

/// The privacy promise, made executable.
///
/// `docs/privacy_policy.md` tells shopkeepers their products, prices, stock
/// levels and supplier details never leave the phone, and
/// `docs/data_safety_form_guide.md` certifies the same to Google. A support
/// bundle is the one artefact assembled specifically to be sent somewhere, so
/// it is the single most likely place for that promise to quietly stop being
/// true — one well-meaning "include the product that failed" and it is gone.
///
/// These tests seed a database with distinctive, searchable values and assert
/// that none of them appear anywhere in the serialised output. A failure here
/// is a privacy failure, not a test failure.
void main() {
  late AppDatabase db;

  // Chosen to be unmistakable in a diff and impossible to collide with JSON
  // keys or log text.
  const productName = 'ZZQX-Maggi-Masala-Noodles';
  const productSku = 'ZZQX-SKU-7781';
  const barcode = '8901030895421';
  const supplierName = 'ZZQX-Balaji-Distributors';
  const supplierPhone = '+919876543210';
  const gstin = '33ZZQXA1234B1Z5';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final now = DateTime.now();

    final productId = await db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: productName,
        sku: const Value(productSku),
        barcode: const Value(barcode),
        category: const Value('ZZQX-Groceries'),
        unit: const Value('pcs'),
        buyPrice: const Value(11.5),
        sellPrice: const Value(17.25),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.movementDao.recordMovement(
      productId: productId,
      qtyDelta: 42,
      reason: 'ZZQX-opening-stock',
      createdAt: now,
    );

    await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(
        name: supplierName,
        phone: supplierPhone,
        gstin: const Value(gstin),
        notes: const Value('ZZQX-pays-on-tuesdays'),
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async => db.close());

  Future<String> buildJson({String description = 'Scanner stopped beeping'}) async {
    final bundle = await SupportBundle.build(
      db: db,
      area: SupportArea.scanning,
      when: SupportWhen.justNow,
      description: description,
      platform: const {'os': 'android', 'osVersion': '29', 'locale': 'ta_IN'},
    );
    return bundle.json;
  }

  group('inventory data never reaches the bundle', () {
    test('no product, supplier or price detail appears anywhere', () async {
      final json = await buildJson();

      for (final secret in [
        productName,
        productSku,
        barcode,
        supplierName,
        supplierPhone,
        gstin,
        'ZZQX-Groceries',
        'ZZQX-opening-stock',
        'ZZQX-pays-on-tuesdays',
        '17.25',
        '11.5',
      ]) {
        expect(
          json,
          isNot(contains(secret)),
          reason: 'The bundle leaked "$secret". The privacy policy says '
              'product and supplier data never leaves the phone.',
        );
      }

      // Nothing from the seeded fixtures at all, caught generically in case a
      // new field is added above and forgotten below.
      expect(json, isNot(contains('ZZQX')));
    });

    test('scale is reported as counts, which are not contents', () async {
      final json = await buildJson();
      final scale = (jsonDecode(json) as Map)['scale'] as Map;

      expect(scale['products'], 1);
      expect(scale['movements'], 1);
      expect(scale['suppliers'], 1);
      expect(scale['isPro'], isFalse);
      expect(scale['freeLimit'], isA<int>());
    });
  });

  group('the bundle carries what is needed to act on a report', () {
    test('includes the reference, the report and health indicators', () async {
      final bundle = await SupportBundle.build(
        db: db,
        area: SupportArea.backup,
        when: SupportWhen.earlier,
        description: 'Restore said the file was from a newer version',
        platform: const {'os': 'android'},
      );
      final map = jsonDecode(bundle.json) as Map<String, dynamic>;

      expect(map['reference'], bundle.reference);
      expect(map['report']['area'], 'backup');
      expect(map['report']['when'], 'earlier');
      expect(map['report']['description'], contains('newer version'));
      expect(map['health']['schemaVersion'], db.schemaVersion);
      expect(map['health']['databaseIntegrity'], 'ok');
      expect(map['health']['ledgerMismatches'], 0);
    });

    test('survives a completely empty install', () async {
      final empty = AppDatabase(NativeDatabase.memory());
      addTearDown(empty.close);

      final bundle = await SupportBundle.build(
        db: empty,
        area: SupportArea.other,
        when: SupportWhen.always,
        description: '',
        platform: const {'os': 'android'},
      );

      final scale = (jsonDecode(bundle.json) as Map)['scale'] as Map;
      expect(scale['products'], 0);
      expect(scale['movements'], 0);
    });
  });

  group('the reference', () {
    test('matches the documented shape', () async {
      final ref = SupportBundle.newReference(DateTime(2026, 10, 13));
      expect(ref, matches(RegExp(r'^SS-261013-[0-9A-F]{8}$')));
    });

    test('draws from the full eight-character space', () {
      // The deterministic half of the guarantee, and the one that catches a
      // regression: shortening the suffix fails here immediately. Collision
      // probability is a consequence of this, so this is what to assert.
      for (var i = 0; i < 200; i++) {
        expect(
          SupportBundle.newReference(DateTime(2026, 10, 13)),
          matches(RegExp(r'^SS-261013-[0-9A-F]{8}$')),
        );
      }
    });

    test('collisions stay within what the birthday bound allows', () {
      final seen = <String>{};
      for (var i = 0; i < 5000; i++) {
        seen.add(SupportBundle.newReference(DateTime(2026, 10, 13)));
      }

      // Asserting zero collisions here was wrong, and flaked. Same-day
      // references share a prefix, so only the 16^8 suffix varies, and the
      // birthday bound gives ~0.003 expected collisions in 5000 draws — about
      // a 0.3% chance of at least one. Over a suite that runs on every push
      // that is roughly one spurious red in 300, which teaches people to
      // re-run rather than read.
      //
      // Zero was never a property of the code; it was a probable outcome
      // asserted as a certainty. The property worth pinning is that the
      // generator is not degenerate — a broken or seeded RNG collapses the
      // space and fails this by a wide margin, while honest luck cannot.
      expect(seen.length, greaterThanOrEqualTo(4995));
    });
  });

  group('size', () {
    test('a long description cannot push the logs out', () async {
      final json = await buildJson(description: 'x' * 50000);
      expect(utf8.encode(json).length, lessThanOrEqualTo(SupportBundle.maxBytes));

      final map = jsonDecode(json) as Map<String, dynamic>;
      // Clipped rather than dropped, so the shopkeeper's words survive.
      expect((map['report']['description'] as String).length, lessThan(2100));
    });

    test('stays within the budget WhatsApp will accept', () async {
      final json = await buildJson();
      expect(utf8.encode(json).length, lessThanOrEqualTo(SupportBundle.maxBytes));
    });
  });
}
