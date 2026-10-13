import 'package:flutter/widgets.dart';

import 'data/database.dart';
import 'data/repositories/backup_repository.dart';
import 'data/repositories/database_host.dart';
import 'data/repositories/inventory_repository.dart';

export 'data/repositories/backup_repository.dart';
export 'data/repositories/database_host.dart' show AppDatabaseFactory, DatabaseHost;
export 'data/repositories/inventory_repository.dart';

/// Makes the database and its repositories available to the whole widget tree.
///
/// Replaces passing `db:` through twenty-one widget constructors. Beyond the
/// boilerplate, prop drilling meant the database instance was fixed for the
/// lifetime of the tree — so nothing could close and reopen it, which is what
/// a safe restore requires.
///
/// A plain [InheritedNotifier] is enough here. The app has one dependency to
/// share and one developer maintaining it; a state-management package would
/// add a concept without removing one. Reactivity still comes from drift's
/// query streams, which remain the source of truth.
class AppScope extends InheritedNotifier<DatabaseHost> {
  AppScope({super.key, required DatabaseHost host, required super.child})
      : inventory = InventoryRepository(host.db),
        backup = BackupRepository(host),
        super(notifier: host);

  final InventoryRepository inventory;
  final BackupRepository backup;

  /// The host owning the connection. Use this to close and reopen the
  /// database; use [db] for ordinary queries.
  DatabaseHost get host => notifier!;

  /// The live database.
  ///
  /// Read it at the point of use rather than storing it in a field: the
  /// instance is replaced whenever the connection is reopened.
  AppDatabase get db => host.db;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found above this widget.');
    return scope!;
  }

  /// Reads the scope without subscribing to reopen notifications. For
  /// callbacks and one-off queries, where rebuilding on reopen is pointless.
  static AppScope read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<AppScope>();
    assert(element != null, 'No AppScope found above this widget.');
    return element!.widget as AppScope;
  }

  /// Convenience for the common case.
  static AppDatabase dbOf(BuildContext context) => of(context).db;

  @override
  bool updateShouldNotify(covariant AppScope oldWidget) {
    return super.updateShouldNotify(oldWidget) ||
        !identical(host.db, oldWidget.host.db);
  }
}

/// Hosts a [DatabaseHost] for the lifetime of the app and rebuilds the tree
/// when the connection is replaced.
class AppScopeHost extends StatefulWidget {
  const AppScopeHost({
    super.key,
    required this.createDatabase,
    required this.builder,
    this.onReady,
    this.splash = const SizedBox.shrink(),
  });

  final AppDatabaseFactory createDatabase;
  final Widget Function(BuildContext context) builder;

  /// Startup work needing the database before the first frame — loading the
  /// persisted theme, for example. Runs once, not on reopen.
  final Future<void> Function(AppDatabase db)? onReady;

  /// Shown while [onReady] is in flight.
  final Widget splash;

  @override
  State<AppScopeHost> createState() => _AppScopeHostState();
}

class _AppScopeHostState extends State<AppScopeHost> {
  late final DatabaseHost _host = DatabaseHost(widget.createDatabase);
  late final Future<void> _ready =
      widget.onReady?.call(_host.db) ?? Future<void>.value();

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      host: _host,
      child: FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return widget.splash;
          }
          return Builder(builder: widget.builder);
        },
      ),
    );
  }
}
