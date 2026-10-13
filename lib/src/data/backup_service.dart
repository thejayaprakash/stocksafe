import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

/// Describes a snapshot: what produced it and what it should contain.
///
/// Written alongside every snapshot so a restore can answer three questions
/// the raw file cannot: is it intact, was it made by a build whose schema this
/// one understands, and does it hold what it claims to.
class SnapshotManifest {
  const SnapshotManifest({
    required this.schemaVersion,
    required this.createdAt,
    required this.sha256,
    required this.rowCounts,
  });

  final int schemaVersion;
  final DateTime createdAt;
  final String sha256;
  final Map<String, int> rowCounts;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toIso8601String(),
        'sha256': sha256,
        'rowCounts': rowCounts,
      };

  static SnapshotManifest? tryParse(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final created = DateTime.tryParse(map['createdAt'] as String? ?? '');
      final version = map['schemaVersion'];
      final hash = map['sha256'];
      if (created == null || version is! int || hash is! String) return null;
      return SnapshotManifest(
        schemaVersion: version,
        createdAt: created,
        sha256: hash,
        rowCounts: <String, int>{
          for (final e in (map['rowCounts'] as Map? ?? {}).entries)
            e.key.toString(): (e.value as num).toInt(),
        },
      );
    } catch (_) {
      return null;
    }
  }
}

/// Local backup, verification and restore.
///
/// File work only — this class never decides *when* it is safe to swap the
/// database. [swapInSnapshot] requires the connection to be closed first, which
/// is `BackupRepository`'s job via `DatabaseHost.withDatabaseClosed`.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const int maxSnapshots = 7;
  static const int maxSafetyArchives = 3;
  static const String _snapshotDir = 'stocksafe_backups';
  static const String _safetyPrefix = 'safety_pre_restore_';
  static final DateFormat _fileDateFmt = DateFormat('yyyy-MM-dd_HHmmss');

  /// Sidecar files SQLite keeps beside the main database. They belong to the
  /// database that created them, so they must go when that file is replaced.
  static const List<String> sidecarSuffixes = ['-wal', '-shm', '-journal'];

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

    // 3. Write the manifest: the checksum plus what restore needs to know
    //    before it is willing to swap this file in.
    final manifest = SnapshotManifest(
      schemaVersion: _db.schemaVersion,
      createdAt: DateTime.now(),
      sha256: hash,
      rowCounts: await _currentRowCounts(),
    );
    await File(manifestPathFor(dest.path))
        .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest.toJson()));

    // 4. Persist timestamp in settings for hygiene tracking
    await _db.settingDao.set('last_backup_at', DateTime.now().toIso8601String());

    // 5. Prune old snapshots beyond retention ceiling
    await _pruneOldSnapshots(dir);

    return dest.path;
  }

  /// Path of the manifest belonging to [snapshotPath].
  static String manifestPathFor(String snapshotPath) => '$snapshotPath.json';

  /// Rolling snapshots only. Pre-restore safety archives share the directory
  /// and the `.db` extension, but they are an escape route rather than a
  /// backup — listing them would offer the user a confusing extra entry, and
  /// pruning them would delete the thing that makes restore reversible.
  static bool _isSnapshotFile(File f) {
    final name = p.basename(f.path);
    return name.endsWith('.db') && !name.startsWith(_safetyPrefix);
  }

  /// Reads the manifest for a snapshot, or null when there is none or it is
  /// unreadable. Snapshots created before manifests existed return null.
  Future<SnapshotManifest?> readManifest(String snapshotPath) async {
    final file = File(manifestPathFor(snapshotPath));
    if (!await file.exists()) return null;
    return SnapshotManifest.tryParse(await file.readAsString());
  }

  Future<Map<String, int>> _currentRowCounts() async {
    Future<int> countOf(String table) async {
      final row = await _db
          .customSelect('SELECT COUNT(*) AS c FROM "$table"')
          .getSingle();
      return row.read<int>('c');
    }

    return {
      'product': await countOf('product'),
      'movement': await countOf('movement'),
      'supplier': await countOf('supplier'),
      'batch': await countOf('batch'),
    };
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
        .where(_isSnapshotFile)
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

      // A recorded checksum is required. Previously its absence was treated as
      // success, so any SQLite file dropped into the folder was reported
      // "SHA-256 OK" — the UI asserted an integrity check that never ran.
      final recordedHash = await _recordedHashFor(snapshotPath);
      if (recordedHash == null) return false;

      final bytes = await file.readAsBytes();
      final actualHash = sha256.convert(bytes).toString();
      return recordedHash == actualHash;
    } catch (_) {
      return false;
    }
  }

  /// The checksum recorded for a snapshot, from the manifest or the older
  /// `.sha256` sidecar. Null when neither exists.
  Future<String?> _recordedHashFor(String snapshotPath) async {
    final manifest = await readManifest(snapshotPath);
    if (manifest != null) return manifest.sha256;

    final hashFile = File('$snapshotPath.sha256');
    if (await hashFile.exists()) {
      return (await hashFile.readAsString()).trim();
    }
    return null;
  }

  /// Checks a snapshot is safe to restore, before anything is touched.
  ///
  /// Throws rather than returning a bool so the caller cannot ignore it, and
  /// so the message reaches the user unchanged.
  Future<void> assertRestorable(String snapshotPath, {bool force = false}) async {
    final source = File(snapshotPath);
    if (!await source.exists()) {
      throw ArgumentError('Snapshot file does not exist: $snapshotPath');
    }

    if (!force && !await verifySnapshotIntegrity(snapshotPath)) {
      throw const FormatException(
        'Snapshot failed integrity verification, or has no recorded checksum.',
      );
    }

    // A snapshot from a newer build carries a schema this one has no migration
    // for. Drift would open it and find columns its generated code does not
    // know about; refusing is the only safe answer.
    final manifest = await readManifest(snapshotPath);
    if (manifest != null && manifest.schemaVersion > _db.schemaVersion) {
      throw StateError(
        'This backup was made by a newer version of StockSafe '
        '(database v${manifest.schemaVersion}, this build understands '
        'v${_db.schemaVersion}). Update the app, then restore.',
      );
    }
  }

  /// Copies the live database aside before it is replaced, timestamped so a
  /// second restore cannot destroy the escape route left by the first.
  /// Keeps the most recent [maxSafetyArchives].
  Future<File?> archiveCurrentDatabase() async {
    final target = await resolveDatabaseFile();
    if (target == null || !await target.exists()) return null;

    final dir = await _backupDir();
    final stamp = _fileDateFmt.format(DateTime.now());
    final archive = File(p.join(dir.path, '$_safetyPrefix$stamp.db'));
    await target.copy(archive.path);

    final archives = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith(_safetyPrefix))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in archives.skip(maxSafetyArchives)) {
      await old.delete();
    }

    return archive;
  }

  /// Replaces the active database file with [snapshotPath].
  ///
  /// **The connection must already be closed.** SQLite keeps page-cache state
  /// and a write-ahead log bound to the file it opened; replacing that file
  /// underneath an open connection lets stale WAL frames be applied over the
  /// restored pages, which either silently reverts the restore or corrupts the
  /// database. Callers go through [BackupRepository.restoreFromSnapshot],
  /// which wraps this in `DatabaseHost.withDatabaseClosed`.
  Future<void> swapInSnapshot(String snapshotPath) async {
    final source = File(snapshotPath);
    if (!await source.exists()) {
      throw ArgumentError('Snapshot file does not exist: $snapshotPath');
    }

    final target = await resolveDatabaseFile(orExpected: true);
    if (target == null) {
      throw StateError('Cannot locate the active database file.');
    }

    // Sidecars belong to the database being replaced. Leaving them is what
    // lets a stale WAL overwrite the snapshot after reopen.
    for (final suffix in sidecarSuffixes) {
      final sidecar = File('${target.path}$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }

    await source.copy(target.path);
  }

  /// Keep only the most recent [maxSnapshots] backups.
  Future<void> _pruneOldSnapshots(Directory dir) async {
    final files = dir
        .listSync()
        .whereType<File>()
        .where(_isSnapshotFile)
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    if (files.length > maxSnapshots) {
      for (final old in files.sublist(maxSnapshots)) {
        await old.delete();
        for (final sidecar in [
          File('${old.path}.sha256'),
          File(manifestPathFor(old.path)),
        ]) {
          if (await sidecar.exists()) await sidecar.delete();
        }
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

  Future<File?> _dbFile() => resolveDatabaseFile();

  /// Locates the active database file.
  ///
  /// With [orExpected] set, returns the path drift would use even when no file
  /// is there yet — restoring into a fresh install has nothing to find, but
  /// still needs somewhere to put the snapshot.
  Future<File?> resolveDatabaseFile({bool orExpected = false}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final primary = File(p.join(appDir.path, 'stocksafe.sqlite'));
    if (await primary.exists()) return primary;

    final supportDir = await getApplicationSupportDirectory();
    final alt = File(p.join(supportDir.path, 'stocksafe.sqlite'));
    if (await alt.exists()) return alt;

    // `driftDatabase(name: 'stocksafe')` resolves to the documents directory.
    return orExpected ? primary : null;
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
