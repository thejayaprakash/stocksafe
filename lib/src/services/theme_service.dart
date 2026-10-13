import 'package:flutter/material.dart';
import '../data/database.dart';

/// App theme manager supporting System, Light, and Dark modes.
/// Persists the user's choice in SQLite and updates the app dynamically.
class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const String keyThemeMode = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  AppDatabase? _db;

  /// Initialize theme from database settings.
  Future<void> init(AppDatabase db) async {
    _db = db;
    try {
      final saved = await db.settingDao.get(keyThemeMode);
      if (saved == 'light') {
        _mode = ThemeMode.light;
      } else if (saved == 'dark') {
        _mode = ThemeMode.dark;
      } else {
        _mode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {
      // Fallback to system default if setting not yet readable
    }
  }

  /// Change and persist the theme mode.
  Future<void> setThemeMode(ThemeMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();

    if (_db != null) {
      final val = switch (newMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await _db!.settingDao.set(keyThemeMode, val);
    }
  }

  /// StockSafe custom Light Theme (high-contrast, emerald-green brand).
  static ThemeData get lightTheme {
    const seedColor = Color(0xFF1B5E20); // Deep forest emerald
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAF9),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
    );
  }

  /// StockSafe custom Dark Theme (deep neutral slate for OLED battery savings & dark storerooms).
  static ThemeData get darkTheme {
    const seedColor = Color(0xFF10B981); // Crisp emerald
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF1E2228),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF121519),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1B1F24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2C323A), width: 1),
        ),
      ),
    );
  }
}
