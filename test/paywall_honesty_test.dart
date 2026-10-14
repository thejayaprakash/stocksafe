// The paywall must only promise things the app actually withholds.
//
// It advertised "Bluetooth Thermal Slip Printing", "Barcode Sticker Sheet
// Printing" and "Bilingual Voice Assistant" as Pro while all three were fully
// available free. Someone paying ₹499 for thermal printing already had it,
// and the upgrade screen was selling almost nothing.
//
// These are source-level tests on purpose. The failure mode is not a wrong
// value at runtime - it is a row added to the sheet, or a gate quietly
// removed, with nothing to notice the two have drifted apart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String paywall;

  setUpAll(() {
    paywall = File('lib/src/ui/widgets/paywall_sheet.dart').readAsStringSync();
  });

  /// Every benefit the upgrade sheet claims, by localisation key.
  Set<String> advertisedFeatures() => RegExp(r"AppLocale\.tr\('(feature_[a-z_]+)'\)")
      .allMatches(paywall)
      .map((m) => m.group(1)!)
      .where((k) => !k.endsWith('_desc'))
      .toSet();

  /// Each claim, and the gate that makes it true. Adding a row to the sheet
  /// without adding it here fails the test below, which is the point.
  const backedBy = <String, String>{
    // LicenseService.canAddProduct, checked before every product insert.
    'feature_unlimited_products': 'lib/src/services/license_service.dart',
    // requirePro on every entry point into BarcodeLabelPrintPage.
    'feature_barcode_stickers': 'lib/src/ui/pro_gate.dart',
    // requirePro before VoiceAssistantDialog.
    'feature_voice_assistant': 'lib/src/ui/pro_gate.dart',
    // proUnlocked drops the vendor mark from printed slips.
    'feature_own_branding': 'lib/src/services/esc_pos_service.dart',
  };

  test('every advertised benefit names a gate that exists', () {
    for (final key in advertisedFeatures()) {
      expect(backedBy.containsKey(key), isTrue,
          reason: 'the paywall promises "$key" with nothing withholding it');
      expect(File(backedBy[key]!).existsSync(), isTrue,
          reason: 'gate file for "$key" is missing');
    }
  });

  test('nothing gated is left unadvertised', () {
    // The mirror mistake: charging for something and never saying so.
    final advertised = advertisedFeatures();
    for (final key in backedBy.keys) {
      expect(advertised, contains(key),
          reason: '"$key" is withheld from free users but never mentioned');
    }
  });

  test('thermal slip printing is not advertised as Pro', () {
    // It is free, deliberately: a free slip carries the StockSafe mark, so
    // every one handed to a customer advertises the app. Gating it would
    // remove the only distribution this app has - and the branding feature
    // would become pointless, because free users would never print.
    expect(paywall.contains('feature_thermal'), isFalse);
  });

  group('The gates are really there', () {
    // Derived, not hard-coded: the navigation rework moved sticker printing
    // out of the home overflow menu and into MorePage, and a list written by
    // hand would have kept asserting against a route that no longer exists
    // while the new one went ungated.
    List<String> stickerEntryPoints() => Directory('lib/src/ui')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('barcode_label_print_page.dart'))
        .where((f) => f.readAsStringSync().contains('BarcodeLabelPrintPage('))
        .map((f) => f.path)
        .toList();

    test('every route into sticker printing checks Pro first', () {
      final routes = stickerEntryPoints();
      expect(routes, isNotEmpty, reason: 'found no sticker routes to check');
      for (final path in routes) {
        expect(File(path).readAsStringSync(), contains('requirePro('),
            reason: '$path opens sticker printing without a gate');
      }
    });

    test('every route into the voice assistant checks Pro first', () {
      final routes = Directory('lib/src/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('VoiceAssistantDialog.show'))
          .toList();
      expect(routes, isNotEmpty, reason: 'found no voice routes to check');
      for (final f in routes) {
        expect(f.readAsStringSync(), contains('requirePro('),
            reason: '${f.path} opens the voice assistant without a gate');
      }
    });

    test('slip printing is left ungated', () {
      // stock_audit_page prints slips and nothing else chargeable, so it is
      // the one print path that must stay free.
      final audit = File('lib/src/ui/stock_audit_page.dart').readAsStringSync();
      expect(audit, contains('EscPosService.buildAuditDiscrepancy'));
      expect(audit.contains('requirePro('), isFalse,
          reason: 'printing an audit slip must stay free');
    });
  });
}
