import 'package:flutter/foundation.dart';

import '../database.dart';

/// Builds a fresh [AppDatabase] over a fresh connection.
typedef AppDatabaseFactory = AppDatabase Function();

/// Owns the live [AppDatabase] instance.
///
/// Nothing owned it before: `main()` constructed one, captured it in a closure
/// and passed it down the widget tree, so there was no way to close it. That is
/// why restore currently copies a snapshot over the database file while SQLite
/// still has it open (audit C-02) — the code had no means to do anything else.
///
/// [withDatabaseClosed] is the missing primitive. It guarantees the connection
/// is closed for the duration of an operation and reopened afterwards, even if
/// that operation throws, so the app is never left without a database.
class DatabaseHost extends ChangeNotifier {
  DatabaseHost(this._create) : _db = _create();

  final AppDatabaseFactory _create;

  AppDatabase _db;
  bool _isOpen = true;
  bool _disposed = false;

  /// The current database. Do not retain this across a [withDatabaseClosed]
  /// call — the instance is replaced, and the old one is closed.
  AppDatabase get db {
    if (!_isOpen) {
      throw StateError(
        'The database is closed for a restore. Read `db` again after the '
        'operation completes rather than holding a reference across it.',
      );
    }
    return _db;
  }

  /// Whether a connection is currently available.
  bool get isOpen => _isOpen;

  /// Closes the connection, runs [action], then opens a fresh one.
  ///
  /// The reopen is in a `finally`, so a failed restore still leaves the app
  /// with a working database. Listeners are notified after the swap so the
  /// widget tree rebuilds against the new instance.
  Future<T> withDatabaseClosed<T>(Future<T> Function() action) async {
    if (!_isOpen) {
      throw StateError('The database is already closed.');
    }

    _isOpen = false;
    try {
      await _db.close();
      return await action();
    } finally {
      _db = _create();
      _isOpen = true;
      if (!_disposed) notifyListeners();
    }
  }

  /// Closes and immediately reopens — used after an external change to the
  /// database file to discard any cached pages.
  Future<void> reopen() => withDatabaseClosed(() async {});

  @override
  Future<void> dispose() async {
    if (_disposed) return; // idempotent: the owning State may dispose twice
    _disposed = true;
    super.dispose();
    if (_isOpen) {
      _isOpen = false;
      await _db.close();
    }
  }
}
