import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/services/catalog_enrichment_service.dart';
import 'package:stocksafe/src/services/label_ocr_service.dart';

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
}
