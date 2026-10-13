// Measures how often Open Food Facts actually knows a barcode from a real
// shop, so the catalogue-lookup decision rests on a number rather than on an
// assumption.
//
//   dart run tool/measure_catalogue.dart barcodes.txt
//
// barcodes.txt is one barcode per line. Blank lines and lines starting with #
// are ignored, so you can annotate it.
//
// WHY THIS EXISTS
//
// The online catalogue lookup was removed (a344810) because it shipped with no
// consent and the privacy policy promised the app was offline. Bringing it back
// means adding the INTERNET permission, rewriting the Data Safety declaration,
// the privacy policy and the store listing, and re-running review. That is a
// day of work and a permanent change to what the app claims about itself.
//
// All of it rests on one unmeasured assumption: that Open Food Facts knows the
// products an Indian kirana actually stocks. It is a food database, strong on
// packaged national brands and thin on regional and unbranded goods — and a
// kirana also sells soap, batteries and loose grain.
//
// If the hit rate is poor, the catalogue is not worth restoring, and then the
// only remaining reason to request INTERNET is telemetry. That is a much harder
// thing to justify to a user or a reviewer, so this number decides more than it
// looks like it does.
//
// Get the barcodes by scanning a real shop's shelves, not by picking products
// you expect to be found.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Below this, restoring the catalogue is not worth what it costs.
const double _worthwhileThreshold = 30.0;

/// Open Food Facts is run by a non-profit on donated infrastructure. One
/// request per second is slow enough to be a good citizen and fast enough that
/// 100 barcodes take under two minutes.
const Duration _politeDelay = Duration(seconds: 1);

const Duration _timeout = Duration(seconds: 8);

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/measure_catalogue.dart <barcodes.txt>');
    stderr.writeln('       one barcode per line; # starts a comment');
    exit(64);
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('No such file: ${args.first}');
    exit(66);
  }

  final barcodes = file
      .readAsLinesSync()
      .map((l) => l.split('#').first.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  if (barcodes.isEmpty) {
    stderr.writeln('${args.first} contains no barcodes.');
    exit(65);
  }

  stdout.writeln('Checking ${barcodes.length} barcodes against Open Food Facts.');
  stdout.writeln('About ${(barcodes.length * _politeDelay.inSeconds / 60).ceil()} '
      'minute(s), one request per second.\n');

  final client = HttpClient()..connectionTimeout = _timeout;
  final hits = <_Hit>[];
  var misses = 0;
  var errors = 0;

  for (var i = 0; i < barcodes.length; i++) {
    final code = barcodes[i];
    stdout.write('\r[${i + 1}/${barcodes.length}] $code${' ' * 12}');

    final result = await _lookup(client, code);
    switch (result) {
      case final _Hit h:
        hits.add(h);
      case _Miss _:
        misses++;
      case _Error _:
        errors++;
    }

    if (i < barcodes.length - 1) await Future<void>.delayed(_politeDelay);
  }
  // force: true matters. A plain close() waits for keep-alive connections to
  // go idle, which leaves the event loop alive and the process hanging after
  // the report has already printed — it looks like the tool froze when it has
  // in fact finished.
  client.close(force: true);

  stdout.writeln('\r${' ' * 40}\r');
  _report(barcodes.length, hits, misses, errors);
}

void _report(int total, List<_Hit> hits, int misses, int errors) {
  // Errors are excluded from the denominator: a timeout says nothing about
  // whether the catalogue knows the product.
  final answered = total - errors;
  // The rate that matters is the one that saves typing, so brand-only rows
  // are excluded from it. The raw count is still shown above.
  final usableForRate = hits.where((h) => !h.brandOnly).length;
  final rate = answered == 0 ? 0.0 : usableForRate * 100 / answered;

  stdout.writeln('─' * 60);
  stdout.writeln('Barcodes checked      $total');
  final usable = hits.where((h) => !h.brandOnly).length;
  final brandOnly = hits.length - usable;

  stdout.writeln('Found                 ${hits.length}');
  if (brandOnly > 0) {
    stdout.writeln('  with a real name    $usable');
    stdout.writeln('  brand only          $brandOnly  (saves little typing)');
  }
  stdout.writeln('Not in catalogue      $misses');
  if (errors > 0) {
    stdout.writeln('Network errors        $errors  (excluded from the rate)');
  }
  stdout.writeln('');
  stdout.writeln('USABLE HIT RATE       ${rate.toStringAsFixed(1)}%  '
      'of $answered answered');
  stdout.writeln('─' * 60);

  if (hits.isNotEmpty) {
    stdout.writeln('\nWhat it would have filled in:\n');
    for (final h in hits.take(10)) {
      stdout.writeln('  ${h.barcode}  ${h.name}'
          '${h.brandOnly ? '   <- brand only' : ''}');
      if (h.quantity != null) stdout.writeln('${' ' * 16}pack: ${h.quantity}');
    }
    if (hits.length > 10) {
      stdout.writeln('  … and ${hits.length - 10} more');
    }
    stdout.writeln('\nRead those. Brand-only rows are already out of the '
        'rate, but a name\nthat is wrong, truncated or in French still counts '
        'as a hit above and\nwould not actually save anyone typing.');
  }

  stdout.writeln('');
  if (rate >= _worthwhileThreshold) {
    stdout.writeln('ABOVE the ${_worthwhileThreshold.toStringAsFixed(0)}% '
        'threshold. Restoring the catalogue is defensible:');
    stdout.writeln('it saves real typing, and it gives the INTERNET permission '
        'a reason a user');
    stdout.writeln('benefits from. See User Story/online-feature.md for what '
        'to fix while');
    stdout.writeln('bringing it back.');
  } else {
    stdout.writeln('BELOW the ${_worthwhileThreshold.toStringAsFixed(0)}% '
        'threshold. Do not restore the catalogue.');
    stdout.writeln('');
    stdout.writeln('Most scans would still need typing, so it would not earn '
        'the permission,');
    stdout.writeln('the Data Safety rewrite, or the review risk. And without '
        'it, the only');
    stdout.writeln('remaining reason to ask for INTERNET is telemetry — which '
        'is far harder');
    stdout.writeln('to defend to a user or a reviewer.');
    stdout.writeln('');
    stdout.writeln('This is a good outcome. It keeps "no StockSafe server" '
        'true.');
  }
}

Future<_Result> _lookup(HttpClient client, String barcode) async {
  try {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
    );
    final request = await client.getUrl(uri).timeout(_timeout);
    // Open Food Facts asks API clients to identify themselves so they can get
    // in touch about unusual traffic.
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'StockSafe-CatalogueMeasurement/1.0 (one-off coverage check; '
      'https://github.com/thejayaprakash/stocksafe)',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close().timeout(_timeout);
    if (response.statusCode == 404) return const _Miss();
    if (response.statusCode != 200) return const _Error();

    final body = await response.transform(utf8.decoder).join().timeout(_timeout);
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (data['status'] != 1 || data['product'] == null) return const _Miss();

    final product = data['product'] as Map<String, dynamic>;
    final name = (product['product_name'] as String?) ??
        (product['product_name_en'] as String?) ??
        (product['generic_name'] as String?);
    final brand = (product['brands'] as String?)?.split(',').first.trim();

    // A row with no usable name is a miss in practice, whatever the API says.
    final display = [
      if (brand != null && brand.isNotEmpty) brand,
      if (name != null && name.trim().isNotEmpty) name.trim(),
    ].join(' ').trim();
    if (display.isEmpty) return const _Miss();

    return _Hit(
      barcode: barcode,
      name: display,
      quantity: (product['quantity'] as String?)?.trim(),
      // A row carrying a brand and no product name is technically a hit and
      // practically almost none: "Haldiram's" still leaves the shopkeeper
      // typing what the packet actually is. Counted, but counted separately.
      brandOnly: name == null || name.trim().isEmpty,
    );
  } on TimeoutException {
    return const _Error();
  } catch (_) {
    return const _Error();
  }
}

sealed class _Result {
  const _Result();
}

class _Hit extends _Result {
  const _Hit({
    required this.barcode,
    required this.name,
    this.quantity,
    this.brandOnly = false,
  });

  final String barcode;
  final String name;
  final String? quantity;

  /// A brand with no product name behind it.
  final bool brandOnly;
}

class _Miss extends _Result {
  const _Miss();
}

class _Error extends _Result {
  const _Error();
}
