import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Offline activation vouchers.
///
/// The previous check accepted **any** string beginning `STOCKSAFE` with at
/// least twelve characters, so `STOCKSAFE123` unlocked the app, alongside
/// three hardcoded codes readable in the APK because R8 is disabled. Anyone
/// who tried one guess got in.
///
/// A voucher is now `STOCKSAFE-<serial>-<signature>`, where the signature is
/// an HMAC-SHA256 of the serial truncated to eight characters. Without the
/// secret a forger has to find a preimage for a 40-bit tag, which is not
/// something a shopkeeper does by guessing.
///
/// ## What this is and is not
///
/// The secret is embedded in the app, so anyone who extracts it can mint
/// vouchers. That is unavoidable for any offline check — there is no server
/// to ask, which is the whole point of the feature.
///
/// Be concrete about how exposed it is: Dart is compiled ahead of time into
/// `libapp.so`, and its string literals survive intact. Byte-searching a
/// release APK finds this secret in plain UTF-8. R8 does not help — it
/// obfuscates Java and Kotlin bytecode, not the Dart snapshot — and
/// `--obfuscate` renames Dart symbols but not literals. So this is a speed
/// bump against sharing and guessing, not a secret. Play Billing is the
/// defence against a determined attacker; this sits alongside it rather than
/// replacing it.
///
/// Because the secret is only as private as the APK, it must not be reused
/// for anything else, and vouchers should be minted in small batches.
class LicenseKey {
  const LicenseKey._();

  static const String prefix = 'STOCKSAFE';
  static const int _signatureLength = 8;

  /// Replaced at build time for a release. Kept in source only so the scheme
  /// is testable; rotating it invalidates every voucher already issued.
  static const String _secret = String.fromEnvironment(
    'STOCKSAFE_VOUCHER_SECRET',
    defaultValue: 'stocksafe-dev-voucher-secret-do-not-ship',
  );

  /// Whether a release build is still using the placeholder secret.
  static bool get usesDevelopmentSecret =>
      _secret == 'stocksafe-dev-voucher-secret-do-not-ship';

  /// Normalises user input: vouchers are read off paper and typed by hand, so
  /// case, spaces and dashes must not matter.
  static String normalise(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

  /// Signature for [serial], uppercase hex, truncated.
  static String signatureFor(String serial) {
    final mac = Hmac(sha256, utf8.encode(_secret));
    return mac
        .convert(utf8.encode(normalise(serial)))
        .toString()
        .toUpperCase()
        .substring(0, _signatureLength);
  }

  /// Builds a voucher for [serial]. Used by the issuing tool and by tests.
  static String mint(String serial) {
    final clean = normalise(serial);
    return '$prefix-$clean-${signatureFor(clean)}';
  }

  /// Whether [input] is a voucher this build will accept.
  ///
  /// Compared in constant time. The timing of a local string compare is not a
  /// realistic attack here, but a variable-time compare on a secret-derived
  /// value is the kind of thing that gets copied into somewhere it matters.
  static bool isValid(String input) {
    final clean = normalise(input);
    if (!clean.startsWith(prefix)) return false;

    final payload = clean.substring(prefix.length);
    if (payload.length <= _signatureLength) return false;

    final serial = payload.substring(0, payload.length - _signatureLength);
    final provided = payload.substring(payload.length - _signatureLength);
    if (serial.isEmpty) return false;

    return _constantTimeEquals(provided, signatureFor(serial));
  }

  /// The serial inside a valid voucher, for recording which one was used.
  static String? serialOf(String input) {
    if (!isValid(input)) return null;
    final payload = normalise(input).substring(prefix.length);
    return payload.substring(0, payload.length - _signatureLength);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
