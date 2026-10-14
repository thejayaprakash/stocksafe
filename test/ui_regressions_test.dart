// Four defects found by sweeping the app on a device after the navigation
// rework, pinned here so they do not return the way two of them already have.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/services/theme_service.dart';
import 'package:stocksafe/src/ui/movement_reason.dart';

void main() {
  group('Reason codes never reach the shopkeeper', () {
    test('every code this app writes has a label', () {
      for (final code in knownMovementReasons) {
        final label = readableMovementReason(code);
        expect(label, isNot(contains('_')),
            reason: '"$code" still reads as an identifier');
        expect(label, isNot(equals(code)));
      }
    });

    test('the two that actually leaked', () {
      // transfer_in/transfer_out leaked into the movement history, were
      // fixed there, and then opening_stock leaked into the new home
      // dashboard because the mapping was private to one file.
      expect(readableMovementReason('opening_stock'), 'Opening stock');
      expect(readableMovementReason('transfer_in'), 'Moved in');
      expect(readableMovementReason('transfer_out'), 'Moved out');
    });

    test('free text a user typed is left alone', () {
      expect(readableMovementReason('Damaged in transit'), 'Damaged in transit');
      expect(readableMovementReason(''), '');
    });

    test('no screen formats a raw reason itself', () {
      // The mapper is only useful if the list screens call it. Anything
      // interpolating `.reason` straight into a string is the bug returning.
      final offenders = <String>[];
      for (final file in Directory('lib/src/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          // The mapper's own doc comment quotes the pattern it exists to
          // prevent. Worth keeping, and it is not a call site.
          .where((f) => !f.path.endsWith('movement_reason.dart'))) {
        final src = file.readAsStringSync();
        if (src.contains(r'${m.reason}') ||
            src.contains(r'${movement.reason}')) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'these print the ledger code verbatim: $offenders');
    });
  });

  group('Settings is a route, so it needs its own Scaffold', () {
    // It was a tab body inside HomePage's Scaffold until the navigation
    // rework pushed it as a MaterialPageRoute. Without a Scaffold its text
    // rendered in Flutter's unparented style, the first row drew under the
    // status bar, and everything below the first section was not painted -
    // taking Rebuild Stock Cache, Verify Ledger Integrity, the PRAGMA check
    // and the diagnostic export with it.
    test('SettingsPage builds a Scaffold', () {
      final src = File('lib/src/ui/settings_page.dart').readAsStringSync();
      expect(src, contains('return Scaffold('),
          reason: 'a pushed route with no Scaffold renders unparented');
    });

    test('every pushed page provides one', () {
      final pushed = <String>{};
      for (final file in Directory('lib/src/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        for (final m in RegExp(r'builder: \(_\) => (?:const )?(\w+Page)\(')
            .allMatches(file.readAsStringSync())) {
          pushed.add(m.group(1)!);
        }
      }
      expect(pushed, isNotEmpty, reason: 'found no pushed pages to check');

      final missing = <String>[];
      for (final page in pushed) {
        final snake = page
            .replaceAllMapped(RegExp('(?<=[a-z])[A-Z]'), (m) => '_${m[0]}')
            .toLowerCase();
        final file = File('lib/src/ui/$snake.dart');
        if (!file.existsSync()) continue;
        if (!file.readAsStringSync().contains('Scaffold(')) missing.add(page);
      }
      expect(missing, isEmpty, reason: 'pushed without a Scaffold: $missing');
    });
  });

  group('The status bar stays readable', () {
    test('each theme asks for icons that contrast with it', () {
      final light = ThemeService.lightTheme.appBarTheme.systemOverlayStyle;
      final dark = ThemeService.darkTheme.appBarTheme.systemOverlayStyle;
      expect(light?.statusBarIconBrightness, Brightness.dark,
          reason: 'light page needs dark icons');
      expect(dark?.statusBarIconBrightness, Brightness.light,
          reason: 'dark page needs light icons');
    });

    test('it is also set app-wide, not only where there is an app bar', () {
      // The home dashboard draws its own header, so AppBarTheme never
      // applies there - which is exactly where the unreadable bar was seen.
      final src = File('lib/main.dart').readAsStringSync();
      expect(src, contains('AnnotatedRegion<SystemUiOverlayStyle>'));
    });
  });

  group('One honest number for the product limit', () {
    // Free was 100, the More page said "Unlock 200+", the paywall said
    // "10,000+", and Pro is actually unlimited. "200+" reads as a ceiling.
    test('no copy puts a ceiling on Pro', () {
      final files = Directory('lib/src')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final offenders = <String>[];
      for (final f in files) {
        final src = f.readAsStringSync();
        if (src.contains('200+') || src.contains('10,000+')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'these state a number Pro does not enforce: $offenders');
    });

    test('the More page does not sell what free users already have', () {
      // Label printing and reports are not withheld from free users.
      final src = File('lib/src/ui/more_page.dart').readAsStringSync();
      expect(src.contains('label printing & reports'), isFalse);
    });
  });
}
