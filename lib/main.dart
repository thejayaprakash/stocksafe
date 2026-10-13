import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';

import 'src/app_scope.dart';
import 'src/data/database.dart';
import 'src/services/app_localization.dart';
import 'src/services/diagnostic_service.dart';
import 'src/services/theme_service.dart';
import 'src/ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Route uncaught Flutter errors to DiagnosticService ring buffer
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DiagnosticService.instance.log(
      details.exceptionAsString(),
      level: 'ERROR',
      stackTrace: details.stack?.toString(),
    );
  };

  runApp(const StockSafeApp());
}

class StockSafeApp extends StatelessWidget {
  const StockSafeApp({super.key, this.createDatabase});

  /// Overridable so tests can supply an in-memory database.
  final AppDatabaseFactory? createDatabase;

  static AppDatabase _defaultDatabase() =>
      AppDatabase(driftDatabase(name: 'stocksafe'));

  @override
  Widget build(BuildContext context) {
    return AppScopeHost(
      createDatabase: createDatabase ?? _defaultDatabase,
      onReady: (db) async {
        // No cache rebuild here. It was an unconditional full-table UPDATE
        // with a correlated subquery, awaited before the first frame, so cold
        // start grew with the catalogue and the ledger — and it was defending
        // against a drift the write path makes impossible: recordMovement
        // re-derives the cache inside the same transaction.
        //
        // The cache is still rebuilt where it genuinely can be stale: after a
        // schema upgrade (beforeOpen), after a restore, and on demand from
        // Settings. A consistency check runs after the first frame and repairs
        // only if it actually finds a mismatch — see HomePage.
        await ThemeService.instance.init(db);
      },
      splash: const _Splash(),
      builder: (context) {
        return ListenableBuilder(
          listenable:
              Listenable.merge([ThemeService.instance, AppLocale.instance]),
          builder: (context, _) {
            return MaterialApp(
              title: 'StockSafe',
              debugShowCheckedModeBanner: false,
              theme: ThemeService.lightTheme,
              darkTheme: ThemeService.darkTheme,
              themeMode: ThemeService.instance.mode,
              home: const HomePage(),
            );
          },
        );
      },
    );
  }
}

/// Shown for the moment between the database opening and the theme loading.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeService.lightTheme,
      darkTheme: ThemeService.darkTheme,
      home: const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
