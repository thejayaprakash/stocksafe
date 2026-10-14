import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/database.dart';
import '../theme/app_palette.dart';

export '../theme/app_palette.dart';

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

  /// StockSafe Light Theme: Clean • Modern • Professional
  /// Inspired by modern fintech apps like Google Pay - light, clean and easy on the eyes.
  static ThemeData get lightTheme {
    const palette = AppPalette.light;
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: palette.primary,
      onPrimary: Colors.white,
      primaryContainer: palette.primaryLight,
      onPrimaryContainer: palette.primaryDark,
      secondary: palette.secondary,
      onSecondary: Colors.white,
      secondaryContainer: palette.secondaryLight,
      onSecondaryContainer: palette.secondary,
      tertiary: palette.brandSuccess,
      onTertiary: Colors.white,
      tertiaryContainer: palette.successContainer,
      onTertiaryContainer: const Color(0xFF065F46),
      error: palette.error,
      onError: Colors.white,
      errorContainer: palette.errorContainer,
      onErrorContainer: const Color(0xFF7F1D1D),
      surface: palette.cardSurface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.border,
      outlineVariant: palette.divider,
      shadow: Colors.black.withValues(alpha: 0.05),
      scrim: Colors.black54,
      inverseSurface: palette.textPrimary,
      onInverseSurface: palette.appBackground,
      inversePrimary: const Color(0xFF93C5FD),
      surfaceDim: palette.elevatedSurface,
      surfaceBright: palette.cardSurface,
      surfaceContainerLowest: palette.cardSurface,
      surfaceContainerLow: palette.appBackground,
      surfaceContainer: palette.elevatedSurface,
      surfaceContainerHigh: palette.inputBackground,
      surfaceContainerHighest: palette.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.appBackground,
      dividerColor: palette.divider,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.cardSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.primaryLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: palette.primary);
          }
          return IconThemeData(color: palette.textTertiary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.primary);
          }
          return TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: palette.textTertiary);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.elevatedSurface,
        hintStyle: TextStyle(color: palette.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
      ),
      extensions: const [palette],
    );
  }

  /// StockSafe Dark Theme: Premium • Modern • Easy on eyes
  /// A refined dark theme with subtle surface contrast and professional color usage.
  static ThemeData get darkTheme {
    const palette = AppPalette.dark;
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: palette.primary,
      onPrimary: const Color(0xFF0B1220),
      primaryContainer: palette.primaryDark,
      onPrimaryContainer: palette.primaryLight,
      secondary: palette.secondary,
      onSecondary: const Color(0xFF0B1220),
      secondaryContainer: palette.secondaryDark,
      onSecondaryContainer: const Color(0xFFEDE9FE),
      tertiary: palette.brandSuccess,
      onTertiary: const Color(0xFF0B1220),
      tertiaryContainer: palette.successContainer,
      onTertiaryContainer: const Color(0xFFD1FAE5),
      error: palette.error,
      onError: Colors.white,
      errorContainer: palette.errorContainer,
      onErrorContainer: const Color(0xFFFEE2E2),
      surface: palette.cardSurface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.border,
      outlineVariant: palette.divider,
      shadow: Colors.black,
      scrim: Colors.black87,
      inverseSurface: palette.textPrimary,
      onInverseSurface: palette.appBackground,
      inversePrimary: const Color(0xFF1A73E8),
      surfaceDim: palette.appBackground,
      surfaceBright: palette.elevatedSurface,
      surfaceContainerLowest: palette.appBackground,
      surfaceContainerLow: palette.cardSurface,
      surfaceContainer: palette.elevatedSurface,
      surfaceContainerHigh: palette.inputBackground,
      surfaceContainerHighest: palette.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.appBackground,
      dividerColor: palette.divider,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.cardSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.primaryDark,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: palette.primaryLight);
          }
          return IconThemeData(color: palette.textTertiary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.primaryLight);
          }
          return TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: palette.textTertiary);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: const Color(0xFF0B1220),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: const Color(0xFF0B1220),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputBackground,
        hintStyle: TextStyle(color: palette.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
      ),
      extensions: const [palette],
    );
  }
}
