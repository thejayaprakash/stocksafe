import 'dart:io';

import '../backup_service.dart';
import 'database_host.dart';

/// Backup and restore, with access to the database lifecycle.
///
/// [BackupService] does the file work; this class owns the sequencing around
/// it. The distinction matters for restore, which must not run while SQLite
/// has the target file open — see [DatabaseHost.withDatabaseClosed].
class BackupRepository {
  const BackupRepository(this._host);

  final DatabaseHost _host;

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
  }

  /// Copies the live database aside without restoring anything.
  Future<File?> archiveCurrentDatabase() => _service.archiveCurrentDatabase();
}
