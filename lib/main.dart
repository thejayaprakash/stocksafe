import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';

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

  final db = AppDatabase(driftDatabase(name: 'stocksafe'));
  await db.rebuildAllStockCaches();
  await ThemeService.instance.init(db);

  runApp(StockSafeApp(db: db));
}

class StockSafeApp extends StatelessWidget {
  const StockSafeApp({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeService.instance, AppLocale.instance]),
      builder: (context, _) {
        return MaterialApp(
          title: 'StockSafe',
          debugShowCheckedModeBanner: false,
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          themeMode: ThemeService.instance.mode,
          home: HomePage(db: db),
        );
      },
    );
  }
}
