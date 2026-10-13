import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/catalog_enrichment_service.dart';
import 'package:stocksafe/src/services/label_ocr_service.dart';
import 'package:stocksafe/src/services/restock_analytics_service.dart';

void main() {
  group('CatalogEnrichmentService', () {
    test('displayName combines brand and name cleanly without duplication', () {
      const info1 = CatalogProductInfo(
        barcode: '8901030895421',
        name: 'Classic Masala Noodles',
        brand: 'Maggi',
      );
      expect(info1.displayName, 'Maggi Classic Masala Noodles');

      const info2 = CatalogProductInfo(
        barcode: '8901030895422',
        name: 'Maggi 2-Minute Noodles',
        brand: 'Maggi',
      );
      expect(info2.displayName, 'Maggi 2-Minute Noodles');
    });

    test('lookupBarcode queries Open Food Facts API and maps response fields', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('8901030895421')) {
          return http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'product_name': 'Classic Noodles',
                'brands': 'Maggi, Nestle',
                'quantity': '70 g',
                'categories': 'Groceries, Noodles',
                'image_front_small_url': 'https://images.example.com/front.jpg',
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'status': 0}), 404);
      });

      final service = CatalogEnrichmentService(client: mockClient);
      final info = await service.lookupBarcode('8901030895421');

      expect(info, isNotNull);
      expect(info!.barcode, '8901030895421');
      expect(info.name, 'Classic Noodles');
      expect(info.brand, 'Maggi');
      expect(info.unit, '70 g');
      expect(info.category, 'Groceries');
      expect(info.displayName, 'Maggi Classic Noodles');
    });

    test('lookupBarcode returns null gracefully on network failure or 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not found', 404);
      });

      final service = CatalogEnrichmentService(client: mockClient);
      final info = await service.lookupBarcode('9999999999999');
      expect(info, isNull);
    });
  });

  group('LabelOcrService parsing', () {
    final ocr = LabelOcrService();

    test('extracts MRP, Expiry, Batch, and Quantity from packaging text', () {
      const sampleText = '''
NESTLE INDIA LTD
MAGGI 2-MINUTE NOODLES
BATCH NO: B2940X
MFD: 10/2026
EXP: 10/2027
NET QTY: 70g
MRP: Rs. 14.00
INCL OF ALL TAXES
''';

      final result = ocr.parseText(sampleText);

      expect(result.hasAnyExtractedField, isTrue);
      expect(result.mrp, 14.0);
      expect(result.batchNumber, 'B2940X');
      expect(result.expiryDate, '10/2027');
      expect(result.netQuantity?.toLowerCase(), contains('70g'));
      expect(result.suggestedName, 'NESTLE INDIA LTD');
    });

    test('handles INR symbol and alternate formatting gracefully', () {
      const sampleText = '''
SUNFEAST DARK FANTASY
LOT: DFK99
BEST BEFORE: 24/12/2026
NET WT: 300g
M.R.P. ₹ 150.00
''';

      final result = ocr.parseText(sampleText);

      expect(result.hasAnyExtractedField, isTrue);
      expect(result.mrp, 150.0);
      expect(result.batchNumber, 'DFK99');
      expect(result.expiryDate, '24/12/2026');
      expect(result.netQuantity?.toLowerCase(), contains('300g'));
    });

    test('returns empty attributes when given blank text', () {
      final result = ocr.parseText('');
      expect(result.hasAnyExtractedField, isFalse);
      expect(result.mrp, isNull);
      expect(result.expiryDate, isNull);
    });
  });

  group('RestockAnalyticsService', () {
    late AppDatabase db;
    late RestockAnalyticsService analyticsService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      analyticsService = RestockAnalyticsService(db);
    });

    tearDown(() async => db.close());

    test('computes velocity and suggested reorders accurately based on movements', () async {
      final now = DateTime.now();

      // Product 1: Fast moving product (42 units sold over last 14 days -> 3.0/day)
      final p1Id = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Basmati Rice 5kg',
          lowStockLevel: const Value(15),
          createdAt: now,
          updatedAt: now,
        ),
      );
      // Inward initial stock: 50
      await db.movementDao.recordMovement(productId: p1Id, qtyDelta: 50, reason: 'Initial stock', createdAt: now.subtract(const Duration(days: 10)));
      // Outward sales: 42
      await db.movementDao.recordMovement(productId: p1Id, qtyDelta: -42, reason: 'Sales', createdAt: now.subtract(const Duration(days: 2)));

      // Current stock is 8, which is <= lowStockLevel (15)

      // Product 2: Well-stocked slow-moving product (100 in stock, lowStockLevel 5, 0 sold)
      final p2Id = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Premium Saffron 1g',
          lowStockLevel: const Value(5),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.movementDao.recordMovement(productId: p2Id, qtyDelta: 100, reason: 'Initial stock', createdAt: now);

      final recommendations = await analyticsService.getRecommendations(daysToAnalyze: 14);

      // Only p1 should be in recommendations because p2 is well-stocked
      expect(recommendations.length, 1);
      final r1 = recommendations.first;
      expect(r1.product.id, p1Id);
      expect(r1.currentStock, 8);
      expect(r1.dailyConsumptionRate, 3.0);
      expect(r1.velocityLabel, 'Fast-moving');
      // Days remaining: 8 / 3.0 = ~2.67 days
      expect(r1.daysOfStockRemaining, closeTo(2.67, 0.1));
      // Target = (3.0 * 14) + 15 = 42 + 15 = 57; Suggested order = 57 - 8 = 49
      expect(r1.recommendedOrderQty, 49);
    });
  });
}
