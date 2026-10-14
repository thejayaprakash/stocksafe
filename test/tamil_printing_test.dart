// Tamil in printed output (roadmap F.3).
//
// The pdf package falls back to Helvetica and Courier, neither of which has
// Unicode coverage, so a Tamil shop or product name printed as blank boxes —
// in an app that ships Tamil as a differentiator. The test suite made this
// visible all along: every PDF test logged
// "Helvetica-Bold has no Unicode support".
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/barcode_label_service.dart';
import 'package:drift/drift.dart' show Value;

void main() {
  // rootBundle needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  Product tamilProduct() => Product(
    isFavourite: false,
        id: 1,
        name: 'அரிசி ஒரு கிலோ',
        sku: const Value('RICE-1').value,
        barcode: const Value('8901234567890').value,
        unit: 'கிலோ',
        buyPrice: 55,
        sellPrice: 62,
        lowStockLevel: 5,
        stockQty: 40,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('the bundled Unicode font loads from assets', () async {
    BarcodeLabelService.resetFontCache();
    final theme = await BarcodeLabelService.unicodeTheme();
    expect(theme, isNotNull);
  });

  test('a Tamil product name produces a label sheet with the font embedded',
      () async {
    final bytes = await BarcodeLabelService.generateLabelSheet(
      BarcodeLabelConfig(
        product: tamilProduct(),
        shopName: 'ஸ்ரீ லக்ஷ்மி ஸ்டோர்ஸ்',
        count: 4,
      ),
    );

    expect(bytes.length, greaterThan(1000));
    // %PDF header — a real document, not an error placeholder.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    // The embedded font must be the bundled Tamil one, not a built-in base
    // font. If the fallback ever returns, this name disappears from the PDF.
    final asLatin1 = String.fromCharCodes(bytes);
    expect(asLatin1, contains('NotoSansTamil'),
        reason: 'the Tamil font must be embedded in the document');
  });

  test('Latin names still work with the same font', () async {
    final bytes = await BarcodeLabelService.generateLabelSheet(
      BarcodeLabelConfig(
        product: tamilProduct().copyWith(name: 'Aachi Chilli Powder 100g'),
        shopName: 'Sri Lakshmi Stores',
        count: 2,
      ),
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
