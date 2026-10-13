import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

/// Three layers of data safety (per the spec):
///
/// 1. **Local rolling snapshots** — daily, keep last 7 copies in app storage.
///    Survives a bad update or corruption.
/// 2. **Manual file export** — ZIP the user saves anywhere.
///    Survives everything, including you.
/// 3. Google Drive `appDataFolder` — future phase.
///
/// This service handles layers 1 and 2.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const int maxSnapshots = 7;
  static const String _snapshotDir = 'stocksafe_backups';
  static final DateFormat _fileDateFmt = DateFormat('yyyy-MM-dd_HHmmss');

  // ─── Local Rolling Snapshots ──────────────────────────────────────

  /// Directory where rolling snapshots live.
  Future<Directory> _backupDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _snapshotDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Create a snapshot of the current database file.
  /// Returns the snapshot file path or null if the source doesn't exist.
  Future<String?> createSnapshot() async {
    final sourceFile = await _dbFile();
    if (sourceFile == null || !await sourceFile.exists()) return null;

    final dir = await _backupDir();
    final stamp = _fileDateFmt.format(DateTime.now());
    final dest = File(p.join(dir.path, 'stocksafe_$stamp.db'));

    await sourceFile.copy(dest.path);
    await _pruneOldSnapshots(dir);

    return dest.path;
  }

  /// Lists existing snapshots, newest first.
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
      results.add(SnapshotInfo(
        path: f.path,
        fileName: p.basename(f.path),
        sizeBytes: stat.size,
        modified: stat.modified,
      ));
    }
    return results;
  }

  /// Restore from a snapshot file, replacing the active database.
  /// The caller must close and reopen the database afterwards.
  Future<void> restoreFromSnapshot(String snapshotPath) async {
    final target = await _dbFile();
    if (target == null) {
      throw StateError('Cannot locate the active database file.');
    }
    final source = File(snapshotPath);
    if (!await source.exists()) {
      throw ArgumentError('Snapshot file does not exist: $snapshotPath');
    }
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
      }
    }
  }

  // ─── CSV Export ───────────────────────────────────────────────────

  /// Export products to CSV — **every column**, as the spec demands.
  /// The competitor's export skipped Buy Rate; we never skip anything.
  Future<String> exportProductsCsv() async {
    final products = await _db.productDao.getAllForExport();
    final rows = <List<dynamic>>[
      [
        'ID', 'Name', 'SKU', 'Barcode', 'Unit',
        'Buy Price', 'Sell Price', 'Low Stock Level',
        'Stock Qty', 'Created At', 'Updated At',
      ],
      for (final p in products)
        [
          p.id, p.name, p.sku ?? '', p.barcode ?? '', p.unit,
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
      ['ID', 'Product ID', 'Qty Delta', 'Reason', 'Note', 'Created At'],
      for (final m in movements)
        [
          m.id, m.productId, m.qtyDelta, m.reason,
          m.note ?? '', m.createdAt.toIso8601String(),
        ],
    ];
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
    // drift_flutter stores the DB in the app documents directory by default.
    final dbPath = p.join(appDir.path, 'stocksafe.sqlite');
    final file = File(dbPath);
    if (await file.exists()) return file;
    // Fallback: check the parent app support directory.
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
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final DateTime modified;
}
