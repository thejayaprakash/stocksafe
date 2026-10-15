import 'dart:ui' show PlatformDispatcher;

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app_scope.dart';
import 'src/data/database.dart';
import 'src/services/app_localization.dart';
import 'src/services/diagnostic_service.dart';
import 'src/services/product_image_service.dart';
import 'src/services/theme_service.dart';
import 'src/ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DiagnosticService.instance.recordSession();

  // Persist errors before anything else can throw. The buffer was in-memory
  // only, so a crash destroyed the one record worth having.
  try {
    final support = await getApplicationSupportDirectory();
    await DiagnosticService.instance.attachLogFile(support);
    // Product photos are stored relative to this directory, and widgets
    // resolve them during build, which cannot await. Done here so the base
    // is known before the first frame.
    await ProductImageService.initialise(override: support);
  } catch (_) {
    // Diagnostics must never be the reason the app fails to start, and a
    // missing image directory only costs the photos, not the catalogue.
  }

  // Errors raised inside the Flutter framework.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DiagnosticService.instance.log(
      details.exceptionAsString(),
      level: 'ERROR',
      stackTrace: details.stack?.toString(),
    );
  };

  // Errors raised outside it — a failed Future in a callback, a platform
  // channel error. These were previously unobserved entirely.
  PlatformDispatcher.instance.onError = (error, stack) {
    DiagnosticService.instance.log(
      error.toString(),
      level: 'ERROR',
      stackTrace: stack.toString(),
    );
    return true; // handled: logged, and the app keeps running
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
              // The status bar belongs to whatever is behind it, and on the
              // home dashboard that is our own background rather than an app
              // bar - AppBarTheme.systemOverlayStyle never reaches it. In the
              // light theme the clock and battery stayed light on a near-white
              // page and could not be read. Applied here so it holds on every
              // screen, with or without an app bar.
              builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
                value: Theme.of(context).brightness == Brightness.dark
                    ? const SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: Brightness.light,
                        statusBarBrightness: Brightness.dark,
                      )
                    : const SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: Brightness.dark,
                        statusBarBrightness: Brightness.light,
                      ),
                child: child!,
              ),
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
