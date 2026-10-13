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

  /// Restores a snapshot over the active database.
  ///
  /// Behaviour is unchanged from the previous implementation — the file is
  /// still swapped while the connection is open, which is audit finding C-02.
  /// Routing it through here is the structural half of the fix; roadmap B.1
  /// replaces this body with:
  ///
  /// ```dart
  /// await _host.withDatabaseClosed(() async {
  ///   await _service.swapInSnapshot(path);   // + delete stale -wal / -shm
  /// });
  /// ```
  ///
  /// That change is deliberately held for Phase B, which carries the
  /// round-trip and kill-mid-restore tests that make it safe to land.
  Future<void> restoreFromSnapshot(String snapshotPath) =>
      _service.restoreFromSnapshot(snapshotPath);
}
