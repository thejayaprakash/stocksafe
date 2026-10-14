import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../backup_archive_service.dart';
import '../backup_service.dart';
import '../../services/license_service.dart';
import 'database_host.dart';

/// Backup and restore, with access to the database lifecycle.
///
/// [BackupService] does the file work; this class owns the sequencing around
/// it. The distinction matters for restore, which must not run while SQLite
/// has the target file open — see [DatabaseHost.withDatabaseClosed].
class BackupRepository {
  const BackupRepository(this._host);

  final DatabaseHost _host;

  static const BackupArchiveService _archives = BackupArchiveService();

  /// Built per call rather than cached: [DatabaseHost.db] is replaced whenever
  /// the connection is reopened, and a [BackupService] holding the old
  /// instance would write to a closed database.
  BackupService get _service => BackupService(_host.db);

  Future<String?> createSnapshot() => _service.createSnapshot();

  Future<List<SnapshotInfo>> listSnapshots() => _service.listSnapshots();

  Future<bool> verifySnapshotIntegrity(String path) =>
      _service.verifySnapshotIntegrity(path);

  Future<bool> isBackupOverdue({int thresholdDays = 7}) =>
      _service.isBackupOverdue(thresholdDays: thresholdDays);

  /// Key controlling whether snapshots are taken automatically.
  static const String autoSnapshotKey = 'auto_snapshot_enabled';

  /// Whether automatic snapshots are on. Defaults to **on** — a backup the
  /// user has to remember is a backup that will be a week stale on the day
  /// they need it.
  Future<bool> isAutoSnapshotEnabled() async {
    final value = await _host.db.settingDao.get(autoSnapshotKey);
    return value != 'false';
  }

  Future<void> setAutoSnapshotEnabled(bool enabled) =>
      _host.db.settingDao.set(autoSnapshotKey, enabled ? 'true' : 'false');

  /// Takes a snapshot if one is due, and reports whether it did.
  ///
  /// Called on launch rather than from a background scheduler: a shopkeeper
  /// opens this app most days, so "on open if a day has passed" covers the
  /// realistic usage pattern without a WorkManager dependency, a wake-lock or
  /// a background-execution permission. Failures are swallowed — a backup
  /// that cannot be written must never stop the app from starting.
  Future<bool> snapshotIfDue({Duration interval = const Duration(days: 1)}) async {
    try {
      if (!await isAutoSnapshotEnabled()) return false;
      if (!await _service.isBackupOverdue(thresholdDays: interval.inDays)) {
        return false;
      }
      return await _service.createSnapshot() != null;
    } catch (_) {
      return false;
    }
  }

  /// When the last snapshot was taken, or null if there has never been one.
  Future<DateTime?> lastBackupAt() async {
    final raw = await _host.db.settingDao.get('last_backup_at');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<String> exportProductsCsv() => _service.exportProductsCsv();

  Future<String> exportMovementsCsv() => _service.exportMovementsCsv();

  Future<String> exportAuditSessionCsv(int sessionId) =>
      _service.exportAuditSessionCsv(sessionId);

  Future<List<File>> exportCsvFiles() => _service.exportCsvFiles();

  /// The manifest recorded with a snapshot, if it has one.
  Future<SnapshotManifest?> readManifest(String path) =>
      _service.readManifest(path);

  /// Restores a snapshot over the active database.
  ///
  /// The order matters and is the whole point of this method:
  ///
  /// 1. **Validate first**, while nothing has been touched — a corrupt or
  ///    future-schema snapshot must fail before the live database is closed.
  /// 2. **Archive the current database**, timestamped, so the restore is
  ///    reversible even if it is the wrong snapshot.
  /// 3. **Close the connection**, swap the file, delete the stale `-wal` and
  ///    `-shm`, then reopen. SQLite binds page-cache state and a write-ahead
  ///    log to the file it opened; replacing that file underneath an open
  ///    connection lets stale frames be applied over the restored pages,
  ///    silently reverting the restore or corrupting the database outright.
  ///    This was audit finding C-02.
  ///
  /// Reopening runs the normal `beforeOpen` path, so an older snapshot is
  /// migrated forward and the stock cache is rebuilt from the ledger.
  ///
  /// Set [force] to restore a snapshot that failed verification — the user has
  /// to confirm that explicitly, and the safety archive is still written.
  Future<void> restoreFromSnapshot(
    String snapshotPath, {
    bool force = false,
  }) async {
    // Captured while the connection is still open: `_service` resolves
    // `_host.db`, which deliberately throws once the database is closed.
    // `swapInSnapshot` is pure file work and needs no connection.
    final service = _service;

    await service.assertRestorable(snapshotPath, force: force);
    await service.archiveCurrentDatabase();

    await _host.withDatabaseClosed(() async {
      await service.swapInSnapshot(snapshotPath);
    });

    await _clearRestoredEntitlement();
  }

  /// Copies the live database aside without restoring anything.
  Future<File?> archiveCurrentDatabase() => _service.archiveCurrentDatabase();

  // ─── Portable archives ──────────────────────────────────────────
  //
  // Local snapshots survive a bad update. They do not survive the phone,
  // because they sit in the same sandbox as the database. These two methods
  // are the backup that leaves the device.

  /// Writes a portable `.zip` the user can store anywhere, and returns it.
  ///
  /// Takes a fresh snapshot first so the archived database is quiescent —
  /// zipping a file that is being written to captures a torn page. Falls back
  /// to the live file with the connection closed if no snapshot can be made.
  Future<File> exportArchive({Directory? into}) async {
    final service = _service;
    final counts = <String, int>{
      'product': await _host.db.productDao.countActive(),
      'movement': (await _host.db.movementDao.getAllForExport()).length,
    };
    final schemaVersion = _host.db.schemaVersion;

    final snapshotPath = await service.createSnapshot();
    final destination = File(p.join(
      (into ?? await getTemporaryDirectory()).path,
      BackupArchiveService.suggestedFileName(),
    ));

    if (snapshotPath != null) {
      return _archives.writeArchive(
        databaseFile: File(snapshotPath),
        destination: destination,
        schemaVersion: schemaVersion,
        rowCounts: counts,
      );
    }

    // No snapshot (no database file yet, or the directory is unavailable):
    // archive the live file with the connection closed so it is consistent.
    return _host.withDatabaseClosed(() async {
      final live = await service.resolveDatabaseFile();
      if (live == null) {
        throw StateError('There is no database to back up yet.');
      }
      return _archives.writeArchive(
        databaseFile: live,
        destination: destination,
        schemaVersion: schemaVersion,
        rowCounts: counts,
      );
    });
  }

  /// Reads an archive and reports what it holds, changing nothing.
  Future<ArchiveInspection> inspectArchive(File archiveFile) =>
      _archives.inspect(archiveFile);

  /// Replaces the active database with the one inside [archiveFile].
  ///
  /// Validates and archives the current database before anything is closed,
  /// then runs the same close → swap → reopen sequence as snapshot restore.
  Future<void> importArchive(File archiveFile) async {
    final inspection = await _archives.inspect(archiveFile);
    if (!inspection.isValid) {
      throw FormatException(inspection.error ?? 'Unreadable backup file.');
    }
    if (!inspection.isSupportedBy(_host.db.schemaVersion)) {
      throw StateError(
        'This backup was made by a newer version of StockSafe '
        '(database v${inspection.schemaVersion}, this build understands '
        'v${_host.db.schemaVersion}). Update the app, then import.',
      );
    }

    final service = _service;
    await service.archiveCurrentDatabase();

    final staged = File(p.join(
      (await getTemporaryDirectory()).path,
      'stocksafe_import_${DateTime.now().millisecondsSinceEpoch}.sqlite',
    ));
    await _archives.extractDatabase(inspection, staged);

    try {
      await _host.withDatabaseClosed(() async {
        await service.swapInSnapshot(staged.path);
      });
    } finally {
      if (await staged.exists()) await staged.delete();
    }

    await _clearRestoredEntitlement();
  }

  /// Both restore paths swap in a whole database file, and the Pro unlock is
  /// four rows inside it. Carrying those across would mean a backup grants the
  /// entitlement it was taken with — so one customer's zip, forwarded on
  /// WhatsApp, unlocks the app for everyone who imports it.
  ///
  /// Runs after the connection has been reopened, so it writes to the restored
  /// database rather than the one being replaced. Inventory is untouched; only
  /// the licence rows are cleared, and the owner re-activates with the voucher
  /// or Play purchase they already have.
  Future<void> _clearRestoredEntitlement() =>
      LicenseService(_host.db).clearEntitlement();
}
