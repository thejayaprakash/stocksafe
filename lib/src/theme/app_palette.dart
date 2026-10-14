import 'package:flutter/material.dart';

/// StockSafe Design System Color Palette.
///
/// Clean, modern, professional fintech palette inspired by modern financial apps.
/// Provides both Light and Dark themes with explicit brand, semantic, neutral,
/// and surface tokens.
///
/// Access anywhere via:
/// ```dart
/// final palette = context.palette;
/// // or
/// final palette = AppPalette.of(context);
/// ```
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    // Primary / Brand Colors
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.secondaryLight,
    required this.secondaryDark,
    required this.brandSuccess,

    // Semantic Colors
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.errorContainer,
    required this.info,

    // Neutral Colors
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.border,
    required this.divider,
    required this.surfaceCard,

    // Background & Surface
    required this.appBackground,
    required this.cardSurface,
    required this.elevatedSurface,
    required this.inputBackground,

    // Gradient Accents
    required this.primaryGradient,
    required this.secondaryGradient,
  });

  // ── Primary / Brand Colors ──────────────────────────────────────────
  /// Main key actions, active states, highlights.
  final Color primary;

  /// Background / tint for primary elements.
  final Color primaryLight;

  /// Pressed / focused states for primary buttons.
  final Color primaryDark;

  /// Secondary actions, AI assistant, Pro/Premium badges.
  final Color secondary;

  /// Light secondary background / tint.
  final Color secondaryLight;

  /// Dark secondary surface / tint.
  final Color secondaryDark;

  /// Brand-level positive / success green.
  final Color brandSuccess;

  // ── Semantic Colors ─────────────────────────────────────────────────
  /// Status optimal / success.
  final Color success;

  /// Soft container for success banners / badges (Success Light / Success Dark).
  final Color successContainer;

  /// Low Stock status & warning indicators.
  final Color warning;

  /// Soft container for low-stock cards / badges (Warning Light / Warning Dark).
  final Color warningContainer;

  /// Out of Stock / destructive errors.
  final Color error;

  /// Soft container for out-of-stock banners (Error Light / Error Dark).
  final Color errorContainer;

  /// Informational status indicators.
  final Color info;

  // Semantic Direct Aliases matching design labels exactly:
  Color get successOptimal => success;
  Color get successLight => successContainer;
  Color get successDark => successContainer;
  Color get warningLowStock => warning;
  Color get warningLight => warningContainer;
  Color get warningDark => warningContainer;
  Color get errorOutOfStock => error;
  Color get errorLight => errorContainer;
  Color get errorDark => errorContainer;
  Color get infoInformation => info;

  // ── Neutral Colors ──────────────────────────────────────────────────
  /// Heading and high-emphasis text.
  final Color textPrimary;

  /// Body copy and medium-emphasis text.
  final Color textSecondary;

  /// Hint text, placeholders, metadata.
  final Color textTertiary;

  /// Disabled buttons, text, and icons.
  final Color textDisabled;

  /// Card / container borders.
  final Color border;

  /// Thin row dividers and separators.
  final Color divider;

  /// Base card surface neutral.
  final Color surfaceCard;

  // ── Background & Surface ────────────────────────────────────────────
  /// Main page background.
  final Color appBackground;

  /// Card surface container.
  final Color cardSurface;

  /// Elevated surface (dialogs, sheets, tooltips, chips).
  final Color elevatedSurface;

  /// Text field & input container background.
  final Color inputBackground;

  // ── Gradient Accents ────────────────────────────────────────────────
  /// Subtle decorative primary gradient.
  final LinearGradient primaryGradient;

  /// Subtle decorative secondary (AI / Premium) gradient.
  final LinearGradient secondaryGradient;

  // ── Light Mode Palette ──────────────────────────────────────────────
  /// Clean • Modern • Professional
  /// Inspired by modern fintech apps like Google Pay - light, clean and easy on the eyes.
  static const light = AppPalette(
    // Primary / Brand Colors
    primary: Color(0xFF1A73E8),
    primaryLight: Color(0xFFE8F0FE),
    primaryDark: Color(0xFF1557D6),
    secondary: Color(0xFF7C3AED),
    secondaryLight: Color(0xFFF3E8FF),
    secondaryDark: Color(0xFF7C3AED),
    brandSuccess: Color(0xFF10B981),

    // Semantic Colors
    success: Color(0xFF10B981),
    successContainer: Color(0xFFD1FAE5),
    warning: Color(0xFFF59E0B),
    warningContainer: Color(0xFFFEF3C7),
    error: Color(0xFFEF4444),
    errorContainer: Color(0xFFFEE2E2),
    info: Color(0xFF3B82F6),

    // Neutral Colors
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textTertiary: Color(0xFF64748B),
    textDisabled: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    divider: Color(0xFFF1F5F9),
    surfaceCard: Color(0xFFFFFFFF),

    // Background & Surface
    appBackground: Color(0xFFF8FAFC),
    cardSurface: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFF1F5F9),
    inputBackground: Color(0xFFE5E7EB),

    // Gradient Accents (Optional)
    primaryGradient: LinearGradient(
      colors: [Color(0xFFE8F0FE), Color(0xFFC7D2FE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    secondaryGradient: LinearGradient(
      colors: [Color(0xFFF3E8FF), Color(0xFFEDE9FE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  // ── Dark Mode Palette ───────────────────────────────────────────────
  /// Premium • Modern • Easy on eyes
  /// A refined dark theme with subtle surface contrast and professional color usage.
  static const dark = AppPalette(
    // Primary / Brand Colors
    primary: Color(0xFF3B82F6),
    primaryDark: Color(0xFF1D4EDB),
    primaryLight: Color(0xFF93C5FD),
    secondary: Color(0xFFA78BFA),
    secondaryLight: Color(0xFFA78BFA),
    secondaryDark: Color(0xFF7C3AED),
    brandSuccess: Color(0xFF34D399),

    // Semantic Colors
    success: Color(0xFF22C55E),
    successContainer: Color(0xFF14532D),
    warning: Color(0xFFF59E0B),
    warningContainer: Color(0xFF78350F),
    error: Color(0xFFEF4444),
    errorContainer: Color(0xFF7F1D1D),
    info: Color(0xFF60A5FA),

    // Neutral Colors
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textTertiary: Color(0xFF94A3B8),
    textDisabled: Color(0xFF64748B),
    border: Color(0xFF334155),
    divider: Color(0xFF1E293B),
    surfaceCard: Color(0xFF0F172A),

    // Background & Surface
    appBackground: Color(0xFF0B1220),
    cardSurface: Color(0xFF111827),
    elevatedSurface: Color(0xFF1F2937),
    inputBackground: Color(0xFF374151),

    // Gradient Accents (Optional)
    primaryGradient: LinearGradient(
      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    secondaryGradient: LinearGradient(
      colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? secondary,
    Color? secondaryLight,
    Color? secondaryDark,
    Color? brandSuccess,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? error,
    Color? errorContainer,
    Color? info,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? border,
    Color? divider,
    Color? surfaceCard,
    Color? appBackground,
    Color? cardSurface,
    Color? elevatedSurface,
    Color? inputBackground,
    LinearGradient? primaryGradient,
    LinearGradient? secondaryGradient,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      secondary: secondary ?? this.secondary,
      secondaryLight: secondaryLight ?? this.secondaryLight,
      secondaryDark: secondaryDark ?? this.secondaryDark,
      brandSuccess: brandSuccess ?? this.brandSuccess,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      info: info ?? this.info,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      appBackground: appBackground ?? this.appBackground,
      cardSurface: cardSurface ?? this.cardSurface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      inputBackground: inputBackground ?? this.inputBackground,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      secondaryGradient: secondaryGradient ?? this.secondaryGradient,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryLight: Color.lerp(secondaryLight, other.secondaryLight, t)!,
      secondaryDark: Color.lerp(secondaryDark, other.secondaryDark, t)!,
      brandSuccess: Color.lerp(brandSuccess, other.brandSuccess, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      primaryGradient: LinearGradient.lerp(primaryGradient, other.primaryGradient, t)!,
      secondaryGradient: LinearGradient.lerp(secondaryGradient, other.secondaryGradient, t)!,
    );
  }

  /// Resolves the active [AppPalette] from the nearest [BuildContext].
  static AppPalette of(BuildContext context) {
    return Theme.of(context).extension<AppPalette>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }
}

/// Convenience extension on [BuildContext] to access [AppPalette] directly.
extension AppPaletteBuildContextX on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}

/// Convenience extension on [ThemeData] to access [AppPalette] directly.
extension AppPaletteThemeDataX on ThemeData {
  AppPalette get palette =>
      extension<AppPalette>() ?? (brightness == Brightness.dark ? AppPalette.dark : AppPalette.light);
}

