// Offline activation vouchers.
//
// The previous scheme accepted any string beginning STOCKSAFE with twelve or
// more characters, plus three hardcoded codes shipped in the APK. One guess
// unlocked the app. These tests pin the properties that replace it.
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/services/license_key.dart';

void main() {
  group('Voucher signing', () {
    test('a minted voucher validates', () {
      expect(LicenseKey.isValid(LicenseKey.mint('KIRANA0001')), isTrue);
    });

    test('different serials produce different signatures', () {
      expect(
        LicenseKey.signatureFor('KIRANA0001'),
        isNot(LicenseKey.signatureFor('KIRANA0002')),
      );
    });

    test('the same serial always produces the same voucher', () {
      expect(LicenseKey.mint('SHOP7'), LicenseKey.mint('shop 7'));
    });

    test('the serial is recoverable, so a voucher can be traced', () {
      final voucher = LicenseKey.mint('BATCH-2026-114');
      expect(LicenseKey.serialOf(voucher), 'BATCH2026114');
      expect(LicenseKey.serialOf('STOCKSAFE-NOPE-00000000'), isNull);
    });
  });

  group('Forgery resistance', () {
    test('every guess that used to work now fails', () {
      for (final guess in [
        'STOCKSAFE123',
        'STOCKSAFE-ABCD-1234',
        'STOCKSAFEAAAAAAAAAAAA',
        'PRO2026',
        'KIRANAUNLIMITED',
        'TESTVIP',
      ]) {
        expect(LicenseKey.isValid(guess), isFalse, reason: '"$guess"');
      }
    });

    test('a voucher with any single character altered fails', () {
      final voucher = LicenseKey.mint('KIRANA0003');
      for (var i = LicenseKey.prefix.length; i < voucher.length; i++) {
        if (voucher[i] == '-') continue;
        final swapped = voucher[i] == 'A' ? 'B' : 'A';
        final tampered =
            voucher.substring(0, i) + swapped + voucher.substring(i + 1);
        if (tampered == voucher) continue;
        expect(LicenseKey.isValid(tampered), isFalse,
            reason: 'altering position $i must invalidate the voucher');
      }
    });

    test('a signature from one serial does not validate another', () {
      final stolen = LicenseKey.signatureFor('KIRANA0001');
      expect(LicenseKey.isValid('STOCKSAFE-KIRANA0002-$stolen'), isFalse);
    });

    test('empty, prefix-only and signature-only inputs are rejected', () {
      for (final junk in ['', 'STOCKSAFE', 'STOCKSAFE-', '--', 'ABCDEFGH']) {
        expect(LicenseKey.isValid(junk), isFalse, reason: '"$junk"');
      }
    });
  });

  group('Typed by hand', () {
    test('case, spaces and dashes do not matter', () {
      final voucher = LicenseKey.mint('SHOP42');
      for (final typed in [
        voucher.toLowerCase(),
        voucher.replaceAll('-', ''),
        voucher.replaceAll('-', ' '),
        '  $voucher  ',
      ]) {
        expect(LicenseKey.isValid(typed), isTrue, reason: '"$typed"');
      }
    });
  });

  group('Build hygiene', () {
    test('flags when a build is still using the placeholder secret', () {
      // Tests run without --dart-define, so this is expected to be true here.
      // Its purpose is to let a release build assert the opposite.
      expect(LicenseKey.usesDevelopmentSecret, isTrue);
    });
  });
}
