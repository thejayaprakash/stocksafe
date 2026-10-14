import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/services/theme_service.dart';

void main() {
  group('AppPalette Design System', () {
    test('Light mode palette matches exact specification tokens', () {
      const p = AppPalette.light;

      // Primary / Brand
      expect(p.primary, equals(const Color(0xFF1A73E8)));
      expect(p.primaryLight, equals(const Color(0xFFE8F0FE)));
      expect(p.primaryDark, equals(const Color(0xFF1557D6)));
      expect(p.secondary, equals(const Color(0xFF7C3AED)));
      expect(p.secondaryLight, equals(const Color(0xFFF3E8FF)));
      expect(p.brandSuccess, equals(const Color(0xFF10B981)));

      // Semantic
      expect(p.success, equals(const Color(0xFF10B981)));
      expect(p.successLight, equals(const Color(0xFFD1FAE5)));
      expect(p.warning, equals(const Color(0xFFF59E0B)));
      expect(p.warningLight, equals(const Color(0xFFFEF3C7)));
      expect(p.error, equals(const Color(0xFFEF4444)));
      expect(p.errorLight, equals(const Color(0xFFFEE2E2)));
      expect(p.info, equals(const Color(0xFF3B82F6)));

      // Neutral
      expect(p.textPrimary, equals(const Color(0xFF0F172A)));
      expect(p.textSecondary, equals(const Color(0xFF334155)));
      expect(p.textTertiary, equals(const Color(0xFF64748B)));
      expect(p.textDisabled, equals(const Color(0xFF94A3B8)));
      expect(p.border, equals(const Color(0xFFE2E8F0)));
      expect(p.divider, equals(const Color(0xFFF1F5F9)));
      expect(p.surfaceCard, equals(const Color(0xFFFFFFFF)));

      // Background & Surface
      expect(p.appBackground, equals(const Color(0xFFF8FAFC)));
      expect(p.cardSurface, equals(const Color(0xFFFFFFFF)));
      expect(p.elevatedSurface, equals(const Color(0xFFF1F5F9)));
      expect(p.inputBackground, equals(const Color(0xFFE5E7EB)));

      // Gradients
      expect(p.primaryGradient.colors, equals([const Color(0xFFE8F0FE), const Color(0xFFC7D2FE)]));
      expect(p.secondaryGradient.colors, equals([const Color(0xFFF3E8FF), const Color(0xFFEDE9FE)]));
    });

    test('Dark mode palette matches exact specification tokens', () {
      const p = AppPalette.dark;

      // Primary / Brand
      expect(p.primary, equals(const Color(0xFF3B82F6)));
      expect(p.primaryDark, equals(const Color(0xFF1D4EDB)));
      expect(p.primaryLight, equals(const Color(0xFF93C5FD)));
      expect(p.secondary, equals(const Color(0xFFA78BFA)));
      expect(p.secondaryDark, equals(const Color(0xFF7C3AED)));
      expect(p.brandSuccess, equals(const Color(0xFF34D399)));

      // Semantic
      expect(p.success, equals(const Color(0xFF22C55E)));
      expect(p.successDark, equals(const Color(0xFF14532D)));
      expect(p.warning, equals(const Color(0xFFF59E0B)));
      expect(p.warningDark, equals(const Color(0xFF78350F)));
      expect(p.error, equals(const Color(0xFFEF4444)));
      expect(p.errorDark, equals(const Color(0xFF7F1D1D)));
      expect(p.info, equals(const Color(0xFF60A5FA)));

      // Neutral
      expect(p.textPrimary, equals(const Color(0xFFF8FAFC)));
      expect(p.textSecondary, equals(const Color(0xFFCBD5E1)));
      expect(p.textTertiary, equals(const Color(0xFF94A3B8)));
      expect(p.textDisabled, equals(const Color(0xFF64748B)));
      expect(p.border, equals(const Color(0xFF334155)));
      expect(p.divider, equals(const Color(0xFF1E293B)));
      expect(p.surfaceCard, equals(const Color(0xFF0F172A)));

      // Background & Surface
      expect(p.appBackground, equals(const Color(0xFF0B1220)));
      expect(p.cardSurface, equals(const Color(0xFF111827)));
      expect(p.elevatedSurface, equals(const Color(0xFF1F2937)));
      expect(p.inputBackground, equals(const Color(0xFF374151)));

      // Gradients
      expect(p.primaryGradient.colors, equals([const Color(0xFF1E3A8A), const Color(0xFF2563EB)]));
      expect(p.secondaryGradient.colors, equals([const Color(0xFF4C1D95), const Color(0xFF7C3AED)]));
    });

    test('ThemeData exposes AppPalette via extension', () {
      final lightTheme = ThemeService.lightTheme;
      final darkTheme = ThemeService.darkTheme;

      final lightExt = lightTheme.extension<AppPalette>();
      final darkExt = darkTheme.extension<AppPalette>();

      expect(lightExt, isNotNull);
      expect(darkExt, isNotNull);
      expect(lightExt!.primary, equals(const Color(0xFF1A73E8)));
      expect(darkExt!.primary, equals(const Color(0xFF3B82F6)));

      // Verify scaffoldBackgroundColor alignment
      expect(lightTheme.scaffoldBackgroundColor, equals(const Color(0xFFF8FAFC)));
      expect(darkTheme.scaffoldBackgroundColor, equals(const Color(0xFF0B1220)));

      // Verify card color
      expect(lightTheme.cardTheme.color, equals(const Color(0xFFFFFFFF)));
      expect(darkTheme.cardTheme.color, equals(const Color(0xFF111827)));
    });

    test('AppPalette copyWith and lerp operate cleanly', () {
      const p = AppPalette.light;
      final modified = p.copyWith(primary: const Color(0xFF000000));
      expect(modified.primary, equals(const Color(0xFF000000)));
      expect(modified.secondary, equals(p.secondary));

      final lerped = p.lerp(AppPalette.dark, 0.5);
      expect(lerped.primary, isNotNull);
      expect(lerped.primary, isNot(equals(p.primary)));
    });

    testWidgets('context.palette provides correct palette in tree', (tester) async {
      late AppPalette extractedPalette;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          themeMode: ThemeMode.light,
          home: Builder(
            builder: (context) {
              extractedPalette = context.palette;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(extractedPalette.primary, equals(const Color(0xFF1A73E8)));
    });
  });
}
