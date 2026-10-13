// What the paid tier actually buys on a printed slip.
//
// The upsell is "remove StockSafe's name from the slips you hand out", not
// "pay to put your own shop name on them". A free slip must therefore still
// be a usable slip - correct shop name, correct contents - and differ from a
// paid one only by the vendor mark.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/esc_pos_service.dart';

void main() {
  late AppDatabase db;
  late Product product;

  const shop = 'SRI LAKSHMI STORES';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final now = DateTime.now();
    final id = await db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: 'Rice, Basmati 5kg',
        sellPrice: const Value(520),
        createdAt: now,
        updatedAt: now,
      ),
    );
    product = (await db.productDao.getById(id))!;
  });
  tearDown(() => db.close());

  /// Every slip the app can print, as readable text, at both paper widths.
  Future<List<String>> allSlips({required bool proUnlocked}) async {
    final session = await db.auditDao.createSession(name: 'Evening count');
    await db.auditDao.recordCount(
      sessionId: session, productId: product.id, countedQty: 8, expectedQty: 10);
    final auditSession = (await db.auditDao.getSession(session))!;
    final items = [
      StockAuditItemWithProduct(
        item: (await db.auditDao.getSessionItems(session)).first,
        product: product,
      ),
    ];
    final entries = [
      LowStockSlipEntry(product: product, suggestedOrderQty: 24),
    ];

    final out = <String>[];
    for (final width in ThermalPaperWidth.values) {
      out.addAll([
        EscPosService.buildAuditDiscrepancyText(
          session: auditSession, items: items, shopName: shop,
          paperWidth: width, proUnlocked: proUnlocked),
        EscPosService.buildDeliverySlipText(
          product: product, quantity: 12, reason: 'purchase', shopName: shop,
          paperWidth: width, proUnlocked: proUnlocked),
        EscPosService.buildLowStockReorderText(
          entries: entries, shopName: shop,
          paperWidth: width, proUnlocked: proUnlocked),
        // Byte output is latin1, so it reads back as text for assertions.
        latin1.decode(EscPosService.buildAuditDiscrepancySlipBytes(
          session: auditSession, items: items, shopName: shop,
          paperWidth: width, proUnlocked: proUnlocked)),
        latin1.decode(EscPosService.buildDeliverySlipBytes(
          product: product, quantity: 12, reason: 'purchase', shopName: shop,
          paperWidth: width, proUnlocked: proUnlocked)),
        latin1.decode(EscPosService.buildLowStockReorderSlipBytes(
          entries: entries, shopName: shop,
          paperWidth: width, proUnlocked: proUnlocked)),
      ]);
    }
    return out;
  }

  group('Free tier', () {
    test('every slip carries the vendor name', () async {
      final slips = await allSlips(proUnlocked: false);
      expect(slips, hasLength(12));
      for (final slip in slips) {
        expect(slip, contains('StockSafe'),
            reason: 'a free slip is the only distribution this app has');
      }
    });

    test('the full mark reaches the printer', () async {
      // The text preview centres each line and truncates anything wider than
      // the paper, so at 58mm the 40-character delivery mark is clipped. The
      // byte stream is not centred, so the printer still gets it whole.
      final bytes = latin1.decode(EscPosService.buildDeliverySlipBytes(
        product: product, quantity: 1, reason: 'purchase', shopName: shop));
      expect(bytes, contains(EscPosService.brandingDelivery));
    });

    test('the shop name is still the shop name', () async {
      // The whole point: identity is not the thing being sold.
      for (final slip in await allSlips(proUnlocked: false)) {
        expect(slip, contains(shop));
      }
    });
  });

  group('Pro tier', () {
    test('the vendor name appears nowhere on any slip', () async {
      final slips = await allSlips(proUnlocked: true);
      expect(slips, hasLength(12));
      for (final slip in slips) {
        // Stronger than checking the three known marks: this also catches a
        // mark that was truncated to fit the paper, and any new one added
        // later without a gate.
        expect(slip.contains('StockSafe'), isFalse,
            reason: 'this is the whole of what the paid tier buys');
      }
    });

    test('nothing else about the slip changes', () async {
      final free = await allSlips(proUnlocked: false);
      final pro = await allSlips(proUnlocked: true);

      for (var i = 0; i < free.length; i++) {
        expect(_withoutBranding(free[i]), _withoutBranding(pro[i]),
            reason: 'paying must not change the content of the slip');
      }
    });

    test('the shop name survives', () async {
      for (final slip in await allSlips(proUnlocked: true)) {
        expect(slip, contains(shop));
      }
    });
  });

  group('Failing safe', () {
    test('a call site that forgets the flag still prints the mark', () async {
      // Default is false, so the mark is only ever dropped deliberately.
      final slip = EscPosService.buildLowStockReorderText(
        entries: [LowStockSlipEntry(product: product, suggestedOrderQty: 5)],
        shopName: shop,
      );
      expect(slip, contains(EscPosService.brandingReorder));
    });

    test('the three marks are distinct, so one gate cannot mask another', () {
      expect(EscPosService.brandingLines.toSet(), hasLength(3));
    });

    test('a vendor mark fits the narrowest paper', () {
      // _center clips anything wider than the roll. A clipped mark is the
      // free tier's advertisement printed broken, on the width most of these
      // shops actually use.
      final narrowest = ThermalPaperWidth.values
          .map((w) => w.charactersPerLine)
          .reduce((a, b) => a < b ? a : b);
      for (final mark in EscPosService.brandingLines) {
        expect(mark.length, lessThanOrEqualTo(narrowest), reason: mark);
      }
    });
  });
}

/// The slip with every vendor line removed, and with digits and whitespace
/// dropped so two slips printed a millisecond apart compare equal.
String _withoutBranding(String slip) => const LineSplitter()
    .convert(slip)
    .where((line) => !line.contains('StockSafe'))
    .join('|')
    .replaceAll(RegExp(r'[0-9\s]+'), '');
