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
        // Unchanged startup order: rebuild the cache from the ledger, then
        // load the persisted theme. (Dropping the launch-time rebuild is
        // roadmap D.3 — behaviour is deliberately preserved here.)
        await db.rebuildAllStockCaches();
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
