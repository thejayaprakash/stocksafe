import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';

import '../data/database.dart';
import 'diagnostic_service.dart';
import 'license_service.dart';

/// Which part of the app a report is about. A closed list, not free text, so
/// reports can be grouped without reading them.
enum SupportArea {
  products('Products & catalogue'),
  scanning('Scanning'),
  stock('Stock in / out'),
  audit('Stocktake'),
  backup('Backup & restore'),
  printing('Printing & labels'),
  licence('Payment & activation'),
  other('Something else');

  const SupportArea(this.label);

  final String label;
}

/// Roughly when it happened. Precise timestamps are not worth asking a
/// shopkeeper for, and the diagnostic log already carries them.
enum SupportWhen {
  justNow('Just now'),
  today('Earlier today'),
  earlier('Before today'),
  always('It has always done this');

  const SupportWhen(this.label);

  final String label;
}

/// A diagnostic report the shopkeeper sends, assembled on the device.
///
/// **The app does not transmit this.** It is handed to WhatsApp or email
/// through the share sheet, from the shopkeeper's own account, after they have
/// seen exactly what it contains. That is what keeps the manifest free of the
/// INTERNET permission, and keeps `docs/privacy_policy.md`,
/// `docs/data_safety_form_guide.md` and the store listing true without edits.
///
/// **Counts, never contents.** "143 products" tells us the shop is past the
/// free tier and that paging matters. The product names tell us what they sell,
/// which is theirs and not ours. `test/support_bundle_test.dart` enforces this
/// by seeding distinctive names and asserting none of them appear in the
/// output; treat a failure there as a privacy failure, not a test failure.
class SupportBundle {
  const SupportBundle({required this.reference, required this.json});

  /// Shown to the shopkeeper and embedded in the payload, so a WhatsApp
  /// message can be matched to a report without a ticketing system.
  final String reference;

  /// The payload, pretty-printed. What the preview screen shows verbatim.
  final String json;

  /// A bundle WhatsApp will refuse to paste is a bundle that never arrives.
  static const int maxBytes = 64 * 1024;

  static final _random = Random.secure();

  /// `SS-YYMMDD-XXXXXXXX`. Generated on device; needs no server.
  ///
  /// Eight hex characters, not six. Six is 24 bits, and the birthday bound
  /// makes a collision roughly even money by a few thousand references — which
  /// sounds remote until you remember every install generates these from the
  /// same small space, and two shops colliding on the same day is exactly the
  /// case where support confuses one report for another. Eight costs two
  /// characters and removes the question.
  static String newReference([DateTime? now]) {
    final d = now ?? DateTime.now();
    final date = '${(d.year % 100).toString().padLeft(2, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
    final suffix = List.generate(
      8,
      (_) => '0123456789ABCDEF'[_random.nextInt(16)],
    ).join();
    return 'SS-$date-$suffix';
  }

  /// Builds a bundle from the live database and diagnostic state.
  ///
  /// [packageInfo] and [platform] are injected so this is testable without a
  /// platform channel or a real device.
  static Future<SupportBundle> build({
    required AppDatabase db,
    required SupportArea area,
    required SupportWhen when,
    required String description,
    PackageInfo? packageInfo,
    Map<String, Object?>? platform,
    DiagnosticService? diagnostics,
    DateTime? now,
  }) async {
    final diag = diagnostics ?? DiagnosticService.instance;
    final reference = newReference(now);

    final payload = <String, Object?>{
      'reference': reference,
      'generatedAt': (now ?? DateTime.now()).toIso8601String(),
      'report': {
        'area': area.name,
        'when': when.name,
        // The only free text in the bundle, and the shopkeeper wrote it
        // knowingly. Bounded so a pasted novel cannot push out the logs.
        'description': _clip(description.trim(), 2000),
      },
      'app': {
        'version': packageInfo?.version,
        'buildNumber': packageInfo?.buildNumber,
        'packageName': packageInfo?.packageName,
      },
      'device': platform ?? _describePlatform(),
      'health': {
        'schemaVersion': db.schemaVersion,
        'crashFreeRate': diag.crashFreeRate.toStringAsFixed(1),
        'sessionCount': diag.sessionCount,
        'errorCount': diag.errorCount,
        'databaseIntegrity': await _integrity(db, diag),
        'ledgerMismatches': (await diag.auditLedgerIntegrity(db)).length,
      },
      'scale': await _scale(db),
      'previousSessionLog': await _previousSessionLog(diag),
      'logs': diag.logs.reversed.take(50).map((l) => l.toJson()).toList(),
    };

    return SupportBundle(
      reference: reference,
      json: _encodeWithinBudget(payload),
    );
  }

  /// Counts only. There is deliberately no path here that reads a product
  /// name, barcode, price, supplier or batch.
  static Future<Map<String, Object?>> _scale(AppDatabase db) async {
    final license = LicenseService(db);
    return {
      'products': await db.productDao.countActive(),
      'movements': await db.movementDao.count(),
      'suppliers': await db.supplierDao.countActive(),
      'isPro': await license.isProUnlocked(),
      'freeLimit': await license.getFreeLimit(),
    };
  }

  static Future<String> _integrity(
    AppDatabase db,
    DiagnosticService diag,
  ) async {
    try {
      return await diag.verifyDatabaseIntegrity(db) ? 'ok' : 'failed';
    } catch (_) {
      return 'unknown';
    }
  }

  /// The most valuable field here: it survives a crash, so it describes the
  /// run that went wrong rather than the one reporting it.
  static Future<List<String>> _previousSessionLog(DiagnosticService diag) async {
    try {
      final lines = await diag.previousSessionLog();
      return lines.length <= 80 ? lines : lines.sublist(lines.length - 80);
    } catch (_) {
      return const [];
    }
  }

  static Map<String, Object?> _describePlatform() {
    try {
      return {
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
      };
    } catch (_) {
      return const {'os': 'unknown'};
    }
  }

  /// Serialises, then drops logs oldest-first until it fits.
  ///
  /// Trimming is recorded in the payload rather than done quietly: a truncated
  /// log that does not say it was truncated sends someone looking for an event
  /// that was dropped rather than absent.
  static String _encodeWithinBudget(Map<String, Object?> payload) {
    const encoder = JsonEncoder.withIndent('  ');
    var out = encoder.convert(payload);
    if (utf8.encode(out).length <= maxBytes) return out;

    final logs = List<Object?>.from(payload['logs'] as List);
    final previous = List<Object?>.from(payload['previousSessionLog'] as List);

    while (utf8.encode(out).length > maxBytes && (logs.isNotEmpty || previous.isNotEmpty)) {
      // Drop the ordinary log before the previous session's: the latter is
      // what survived a crash, and is usually the reason for the report.
      if (logs.isNotEmpty) {
        logs.removeLast();
      } else {
        previous.removeAt(0);
      }
      payload['logs'] = logs;
      payload['previousSessionLog'] = previous;
      payload['trimmed'] = 'Logs were trimmed to fit the ${maxBytes ~/ 1024}KB limit.';
      out = encoder.convert(payload);
    }
    return out;
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}
