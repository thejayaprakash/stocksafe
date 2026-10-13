// Mints offline activation vouchers.
//
//   dart run tool/mint_voucher.dart KIRANA0001 KIRANA0002
//   dart run tool/mint_voucher.dart --count 10 --prefix DIWALI
//
// For a release, pass the same secret the app was built with:
//
//   dart run --define=STOCKSAFE_VOUCHER_SECRET=... tool/mint_voucher.dart ...
//
// The secret lives in the APK, so a determined reverse engineer can mint
// their own. That is inherent to any offline check — there is no server to
// ask, which is the point of the feature. Vouchers stop casual sharing and
// guessing; Play Billing is the answer to anything more. Mint in small
// batches and keep a record of which serial went where, so a leaked voucher
// can be traced.
import 'dart:io';

import 'package:stocksafe/src/services/license_key.dart';

void main(List<String> args) {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln(_usage);
    return;
  }

  if (LicenseKey.usesDevelopmentSecret) {
    stderr.writeln(
      'WARNING: minting with the development secret. Vouchers produced here '
      'will NOT work in a release built with a real '
      '--dart-define=STOCKSAFE_VOUCHER_SECRET.\n',
    );
  }

  final serials = <String>[];

  final countIndex = args.indexOf('--count');
  if (countIndex != -1 && countIndex + 1 < args.length) {
    final count = int.tryParse(args[countIndex + 1]);
    if (count == null || count < 1) {
      stderr.writeln('--count needs a positive number');
      exitCode = 2;
      return;
    }
    final prefixIndex = args.indexOf('--prefix');
    final prefix = (prefixIndex != -1 && prefixIndex + 1 < args.length)
        ? args[prefixIndex + 1]
        : 'SS';
    final stamp = DateTime.now();
    for (var i = 1; i <= count; i++) {
      serials.add('$prefix${stamp.year}'
          '${stamp.month.toString().padLeft(2, '0')}'
          '${i.toString().padLeft(4, '0')}');
    }
  } else {
    serials.addAll(args.where((a) => !a.startsWith('--')));
  }

  if (serials.isEmpty) {
    stderr.writeln(_usage);
    exitCode = 2;
    return;
  }

  for (final serial in serials) {
    stdout.writeln('${LicenseKey.mint(serial)}   # serial: '
        '${LicenseKey.normalise(serial)}');
  }
}

const _usage = '''
Mint StockSafe offline activation vouchers.

  dart run tool/mint_voucher.dart <serial> [<serial> ...]
  dart run tool/mint_voucher.dart --count <n> [--prefix <text>]

Give each voucher a distinct serial so a leaked one can be traced.
''';
