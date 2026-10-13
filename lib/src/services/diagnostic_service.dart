import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import '../data/database.dart';

/// Diagnostic error and system health audit record.
class DiagnosticLogEntry {
  const DiagnosticLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.stackTrace,
  });

  final DateTime timestamp;
  final String level; // INFO, WARN, ERROR
  final String message;
  final String? stackTrace;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level,
        'message': message,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };
}

/// Ledger integrity mismatch report for a single product.
class LedgerMismatch {
  const LedgerMismatch({
    required this.productId,
    required this.productName,
    required this.cachedStock,
    required this.ledgerStock,
  });

  final int productId;
  final String productName;
  final int cachedStock;
  final int ledgerStock;

  int get discrepancy => cachedStock - ledgerStock;
}

/// System Health & Diagnostics Engine for StockSafe.
///
/// Provides:
/// - Crash-free session calculation (>99.5% healthy).
/// - Comprehensive Movement Ledger Consistency Audit (comparing cache vs SUM(qty_delta)).
/// - SQLite database PRAGMA integrity check.
/// - In-memory rolling diagnostic log ring-buffer for troubleshooting.
class DiagnosticService {
  DiagnosticService._();
  static final DiagnosticService instance = DiagnosticService._();

  /// A queue rather than a List: the buffer drops its oldest entry on every
  /// write once full, and removeAt(0) on a List is O(n).
  final Queue<DiagnosticLogEntry> _logs = Queue<DiagnosticLogEntry>();
  static const int _maxLogs = 100;

  int _sessionCount = 1;
  int _errorCount = 0;

  /// Where errors are persisted. Set once, on launch.
  File? _logFile;
  static const int _maxLogFileBytes = 256 * 1024;

  /// Points the service at a file so ERROR entries survive the process.
  ///
  /// The buffer was in-memory only, so a crash — the single event worth
  /// diagnosing — destroyed the evidence, and the export action could only
  /// ever report a clean session. Only errors and warnings are written: INFO
  /// is noise, and this runs on the UI isolate.
  Future<void> attachLogFile(Directory directory) async {
    try {
      final file = File('${directory.path}/diagnostics.log');
      if (!await file.exists()) await file.create(recursive: true);
      _logFile = file;
      await _trimLogFile();
    } catch (_) {
      // Diagnostics must never be the reason the app fails to start.
      _logFile = null;
    }
  }

  /// Entries carried over from previous runs, newest last.
  Future<List<String>> previousSessionLog() async {
    final file = _logFile;
    if (file == null || !await file.exists()) return const [];
    try {
      return (await file.readAsLines()).where((l) => l.trim().isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _trimLogFile() async {
    final file = _logFile;
    if (file == null) return;
    try {
      if (await file.length() <= _maxLogFileBytes) return;
      final lines = await file.readAsLines();
      await file.writeAsString('${lines.skip(lines.length ~/ 2).join('\n')}\n');
    } catch (_) {/* best effort */}
  }

  /// Increments total sessions for health telemetry.
  void recordSession() => _sessionCount++;

  /// Records a log event.
  void log(String message, {String level = 'INFO', String? stackTrace}) {
    if (_logs.length >= _maxLogs) {
      _logs.removeFirst();
    }
    if (level == 'ERROR') {
      _errorCount++;
    }
    final entry = DiagnosticLogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      stackTrace: stackTrace,
    );
    _logs.add(entry);

    if (level == 'ERROR' || level == 'WARN') {
      unawaited(_persist(entry));
    }
  }

  Future<void> _persist(DiagnosticLogEntry entry) async {
    final file = _logFile;
    if (file == null) return;
    try {
      await file.writeAsString(
        '${jsonEncode(entry.toJson())}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {/* best effort */}
  }

  /// Recent logs from this session, oldest first.
  List<DiagnosticLogEntry> get logs => List.unmodifiable(_logs);

  /// Error-free session rate.
  ///
  /// The clamp that used to floor this at 90% is gone: a health figure that
  /// cannot report ill health is decoration presented as telemetry. The
  /// denominator was also always 1, because recordSession() was defined and
  /// never called — it is now called on launch.
  double get crashFreeRate {
    if (_sessionCount <= 0) return 100.0;
    final rate = ((_sessionCount - _errorCount) / _sessionCount) * 100.0;
    return rate.clamp(0.0, 100.0);
  }

  /// Sessions counted so far, for display alongside the rate — a percentage
  /// over a handful of sessions should not be read as a trend.
  int get sessionCount => _sessionCount;
  int get errorCount => _errorCount;

  /// Audits the entire movement ledger against cached product stock.
  /// Guarantees that every product's `stock_qty` strictly matches `SELECT SUM(qty_delta)`.
  Future<List<LedgerMismatch>> auditLedgerIntegrity(AppDatabase db) async {
    // One grouped join rather than a SUM query per product. The previous
    // version ran 5,000 queries against a 50,000-row ledger at the dev plan's
    // own target scale — ten seconds behind a modal spinner the user cannot
    // dismiss. The database can do this in a single pass.
    final rows = await db.customSelect(
      '''
      SELECT p.id          AS product_id,
             p.name        AS product_name,
             p.stock_qty   AS cached_stock,
             COALESCE(SUM(m.qty_delta), 0) AS ledger_stock
      FROM product p
      LEFT JOIN movement m ON m.product_id = p.id
      WHERE p.deleted_at IS NULL
      GROUP BY p.id, p.name, p.stock_qty
      HAVING p.stock_qty != COALESCE(SUM(m.qty_delta), 0)
      ORDER BY p.name
      ''',
      readsFrom: {db.products, db.movements},
    ).get();

    final mismatches = [
      for (final row in rows)
        LedgerMismatch(
          productId: row.read<int>('product_id'),
          productName: row.read<String>('product_name'),
          cachedStock: row.read<int>('cached_stock'),
          ledgerStock: row.read<int>('ledger_stock'),
        ),
    ];

    final prodCount = await db.productDao.countActive();

    if (mismatches.isNotEmpty) {
      log('Ledger audit found ${mismatches.length} mismatches', level: 'WARN');
    } else {
      log('Ledger audit passed: 100% consistent across $prodCount products');
    }

    return mismatches;
  }

  /// Runs SQLite PRAGMA integrity_check to detect any physical corruption.
  Future<bool> verifyDatabaseIntegrity(AppDatabase db) async {
    try {
      final result = await db.customSelect('PRAGMA integrity_check;').get();
      if (result.isNotEmpty) {
        final val = result.first.data.values.first?.toString();
        final isOk = val?.toLowerCase() == 'ok';
        log('Database PRAGMA integrity_check: $val');
        return isOk;
      }
      return false;
    } catch (e, st) {
      log('Database integrity check error: $e', level: 'ERROR', stackTrace: st.toString());
      return false;
    }
  }

  /// Exports diagnostic report as JSON string.
  String exportDiagnosticReport() {
    final map = {
      'generatedAt': DateTime.now().toIso8601String(),
      'crashFreeRate': '${crashFreeRate.toStringAsFixed(1)}%',
      'totalLogs': _logs.length,
      'logs': _logs.map((l) => l.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Clear diagnostic logs.
  void clearLogs() {
    _logs.clear();
    _errorCount = 0;
  }
}
