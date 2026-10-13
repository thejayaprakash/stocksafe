import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

/// Enterprise Data Sovereignty & Backup Service.
///
/// Features:
/// 1. **Local Rolling Snapshots** with pre-snapshot WAL flush (`PRAGMA wal_checkpoint(TRUNCATE)`).
/// 2. **Cryptographic Integrity Verification** using SHA-256 hashes and SQLite magic byte headers.
/// 3. **Automatic Pre-Restore Safety Archive** (`safety_pre_restore.db`) to prevent catastrophic data loss.
/// 4. **Comprehensive CSV Exporters** including product catalog, movement ledgers, and audit reports.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const int maxSnapshots = 7;
  static const String _snapshotDir = 'stocksafe_backups';
  static final DateFormat _fileDateFmt = DateFormat('yyyy-MM-dd_HHmmss');

  // SQLite file header magic bytes: "SQLite format 3\x00"
  static const List<int> _sqliteMagicBytes = [
    0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
    0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
  ];

  // ─── Local Rolling Snapshots ──────────────────────────────────────

  Future<Directory> _backupDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _snapshotDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Create a verified snapshot of the current database file.
  /// Flushes SQLite WAL and generates a SHA-256 hash envelope.
  Future<String?> createSnapshot() async {
    // 1. Force flush WAL to ensure database file is completely self-contained
    try {
      await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {
      // Continue if PRAGMA is not supported in test environment
    }

    final sourceFile = await _dbFile();
    if (sourceFile == null || !await sourceFile.exists()) return null;

    final dir = await _backupDir();
    final stamp = _fileDateFmt.format(DateTime.now());
    final dest = File(p.join(dir.path, 'stocksafe_$stamp.db'));

    // Copy database file
    await sourceFile.copy(dest.path);

    // 2. Compute SHA-256 checksum and persist alongside snapshot
    final bytes = await dest.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final hashFile = File('${dest.path}.sha256');
    await hashFile.writeAsString(hash);

    // 3. Persist timestamp in settings for hygiene tracking
    await _db.settingDao.set('last_backup_at', DateTime.now().toIso8601String());

    // 4. Prune old snapshots beyond retention ceiling
    await _pruneOldSnapshots(dir);

    return dest.path;
  }

  /// Checks if backup is overdue (e.g. > 7 days or never backed up).
  Future<bool> isBackupOverdue({int thresholdDays = 7}) async {
    final lastStr = await _db.settingDao.get('last_backup_at');
    if (lastStr == null) return true;
    final lastDate = DateTime.tryParse(lastStr);
    if (lastDate == null) return true;
    return DateTime.now().difference(lastDate).inDays >= thresholdDays;
  }

  /// Lists existing snapshots with verified integrity status, newest first.
  Future<List<SnapshotInfo>> listSnapshots() async {
    final dir = await _backupDir();
    if (!await dir.exists()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    final results = <SnapshotInfo>[];
    for (final f in files) {
      final stat = await f.stat();
      final isVerified = await verifySnapshotIntegrity(f.path);
      results.add(SnapshotInfo(
        path: f.path,
        fileName: p.basename(f.path),
        sizeBytes: stat.size,
        modified: stat.modified,
        isIntegrityVerified: isVerified,
      ));
    }
    return results;
  }

  /// Verifies snapshot integrity: checks file existence, size, SQLite magic bytes,
  /// and SHA-256 checksum.
  Future<bool> verifySnapshotIntegrity(String snapshotPath) async {
    try {
      final file = File(snapshotPath);
      if (!await file.exists()) return false;

      final length = await file.length();
      if (length < 100) return false; // Minimum SQLite file size

      // Check SQLite header magic bytes
      final raf = await file.open(mode: FileMode.read);
      try {
        final header = await raf.read(16);
        if (header.length < 16) return false;
        for (int i = 0; i < 16; i++) {
          if (header[i] != _sqliteMagicBytes[i]) return false;
        }
      } finally {
        await raf.close();
      }

      // Check SHA-256 hash if companion file exists
      final hashFile = File('$snapshotPath.sha256');
      if (await hashFile.exists()) {
        final recordedHash = (await hashFile.readAsString()).trim();
        final bytes = await file.readAsBytes();
        final actualHash = sha256.convert(bytes).toString();
        if (recordedHash != actualHash) return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restore from a snapshot file, replacing the active database.
  /// Validates integrity before restoring and creates a safety backup of the active database.
  Future<void> restoreFromSnapshot(String snapshotPath) async {
    final isValid = await verifySnapshotIntegrity(snapshotPath);
    if (!isValid) {
      throw const FormatException('Snapshot file failed integrity verification or is corrupted.');
    }

    final target = await _dbFile();
    if (target == null) {
      throw StateError('Cannot locate active database file.');
    }

    final source = File(snapshotPath);
    if (!await source.exists()) {
      throw ArgumentError('Snapshot file does not exist: $snapshotPath');
    }

    // Create automatic pre-restore safety archive if target currently exists
    if (await target.exists()) {
      final dir = await _backupDir();
      final safetyBackup = File(p.join(dir.path, 'safety_pre_restore.db'));
      await target.copy(safetyBackup.path);
    }

    // Replace active database
    await source.copy(target.path);
  }

  /// Keep only the most recent [maxSnapshots] backups.
  Future<void> _pruneOldSnapshots(Directory dir) async {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    if (files.length > maxSnapshots) {
      for (final old in files.sublist(maxSnapshots)) {
        await old.delete();
        final shaFile = File('${old.path}.sha256');
        if (await shaFile.exists()) await shaFile.delete();
      }
    }
  }

  // ─── CSV Export ───────────────────────────────────────────────────

  /// Export products to CSV including all standard and enterprise columns.
  Future<String> exportProductsCsv() async {
    final products = await _db.productDao.getAllForExport();
    final rows = <List<dynamic>>[
      [
        'ID', 'Name', 'Category', 'SKU', 'Barcode', 'Unit',
        'Buy Price', 'Sell Price', 'Low Stock Level',
        'Stock Qty', 'Created At', 'Updated At',
      ],
      for (final p in products)
        [
          p.id, p.name, p.category ?? '', p.sku ?? '', p.barcode ?? '', p.unit,
          p.buyPrice, p.sellPrice, p.lowStockLevel,
          p.stockQty, p.createdAt.toIso8601String(), p.updatedAt.toIso8601String(),
        ],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Export movements to CSV — full history with every column.
  Future<String> exportMovementsCsv() async {
    final movements = await _db.movementDao.getAllForExport();
    final rows = <List<dynamic>>[
      ['ID', 'Product ID', 'Qty Delta', 'Reason', 'Note', 'Audit Session ID', 'Created At'],
      for (final m in movements)
        [
          m.id, m.productId, m.qtyDelta, m.reason,
          m.note ?? '', m.auditSessionId ?? '', m.createdAt.toIso8601String(),
        ],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Export an audit session reconciliation report to CSV.
  Future<String> exportAuditSessionCsv(int sessionId) async {
    final session = await _db.auditDao.getSession(sessionId);
    if (session == null) throw ArgumentError('Session not found: $sessionId');

    final items = await _db.auditDao.getSessionItems(sessionId);
    final rows = <List<dynamic>>[
      ['Stocktake Audit Report: ${session.name}'],
      ['Status: ${session.status}', 'Mode: ${session.auditMode}', 'Started: ${session.startedAt.toIso8601String()}'],
      [],
      ['Item ID', 'Product ID', 'Product Name', 'Expected Qty', 'Counted Qty', 'Variance (Difference)', 'Reconciled', 'Notes'],
    ];

    for (final item in items) {
      final prod = await _db.productDao.getById(item.productId);
      rows.add([
        item.id,
        item.productId,
        prod?.name ?? 'Unknown',
        item.expectedQty,
        item.countedQty,
        item.difference,
        item.isReconciled ? 'YES' : 'NO',
        item.notes ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Write CSV exports to temp directory and return file paths.
  Future<List<File>> exportCsvFiles() async {
    final dir = await getTemporaryDirectory();
    final stamp = _fileDateFmt.format(DateTime.now());

    final prodFile = File(p.join(dir.path, 'products_$stamp.csv'));
    await prodFile.writeAsString(await exportProductsCsv());

    final moveFile = File(p.join(dir.path, 'movements_$stamp.csv'));
    await moveFile.writeAsString(await exportMovementsCsv());

    return [prodFile, moveFile];
  }

  // ─── Database file location ───────────────────────────────────────

  Future<File?> _dbFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(appDir.path, 'stocksafe.sqlite');
    final file = File(dbPath);
    if (await file.exists()) return file;

    final supportDir = await getApplicationSupportDirectory();
    final altPath = p.join(supportDir.path, 'stocksafe.sqlite');
    final altFile = File(altPath);
    if (await altFile.exists()) return altFile;
    return null;
  }
}

/// Metadata about a local backup snapshot.
class SnapshotInfo {
  const SnapshotInfo({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.modified,
    required this.isIntegrityVerified,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final DateTime modified;
  final bool isIntegrityVerified;
}
