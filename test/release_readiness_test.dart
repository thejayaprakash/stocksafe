@Tags(['release'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/services/license_key.dart';

/// The launch gate.
///
/// These assert the things that are either permanent once the app is on Play,
/// or that silently produce a build nobody should publish. They are tagged
/// `release` and excluded from the ordinary suite, because some of them are
/// expected to fail until a release is actually being prepared — a red CI on
/// every push to main teaches people to ignore red.
///
/// Run deliberately, with the same parameters as the release build:
///
///     flutter test --tags release \
///       --dart-define=STOCKSAFE_VOUCHER_SECRET="$STOCKSAFE_VOUCHER_SECRET"
///
/// A failure here is the gate doing its job. Each one names what to do.
void main() {
  late final String gradle;

  setUpAll(() {
    final file = File('android/app/build.gradle.kts');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Run this from the package root; ${file.path} was not found.',
    );
    gradle = file.readAsStringSync();
  });

  group('identity — permanent after the first upload', () {
    test('the application ID is not the Flutter template default', () {
      final appId =
          RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)?.group(1);

      expect(appId, isNotNull, reason: 'No applicationId in build.gradle.kts.');
      expect(
        appId,
        isNot(startsWith('com.example')),
        reason: 'Play rejects com.example.*, and the ID cannot be changed '
            'after the first upload — a new ID is a new app, with no installs '
            'and no reviews.',
      );
    });

    test('the namespace matches the application ID', () {
      final appId =
          RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)?.group(1);
      final namespace =
          RegExp(r'namespace\s*=\s*"([^"]+)"').firstMatch(gradle)?.group(1);

      expect(
        namespace,
        appId,
        reason: 'Renaming one means renaming the other and moving '
            'MainActivity.kt to the matching package directory.',
      );
    });
  });

  group('signing', () {
    test('a release build cannot fall back to the debug key unasked', () {
      // Previously this fell back with a logger.warn(). Gradle prints hundreds
      // of lines, CI scrolled past it, and the workflow then published the
      // artifact as "StockSafe-release-aab".
      expect(gradle, contains('allowDebugSigning'));
      expect(
        gradle,
        contains('GradleException'),
        reason: 'Without a hard failure, a keystore-less release build still '
            'produces an artifact signed with the public debug key.',
      );
    });

    test('no keystore is inside the working tree', () {
      final strays = _projectFiles()
          .where((p) => p.endsWith('.jks') || p.endsWith('.keystore'))
          .toList();

      expect(
        strays,
        isEmpty,
        reason: 'A keystore in the tree is one .gitignore mistake away from '
            'being published. Keep it outside the repository entirely.',
      );
    });

    test('key.properties is not committed', () {
      expect(
        File('android/.gitignore').readAsStringSync(),
        contains('key.properties'),
        reason: 'The signing passwords must stay out of version control.',
      );
    });
  });

  group('licensing', () {
    test('the voucher secret is not the development placeholder', () {
      // Built via --dart-define, so this only passes when the gate is run with
      // the same secret the release build uses. That is the point: it catches
      // the release that forgot the define, which would ship an APK whose
      // vouchers anyone can mint from a string visible in the binary.
      expect(
        LicenseKey.usesDevelopmentSecret,
        isFalse,
        reason: 'Build and test with '
            '--dart-define=STOCKSAFE_VOUCHER_SECRET=<the real secret>.',
      );
    });
  });

  group('store metadata', () {
    test('the store listing does not promise more than the app does', () {
      // The app sends nothing, and the listing says so. If that ever stops
      // being true, this and manifest_test.dart should both be updated in the
      // same change as the code.
      final listing =
          File('store_listing/store_listing_metadata.md').readAsStringSync();
      expect(listing.toLowerCase(), contains('offline'));
    });
  });
}

Iterable<String> _projectFiles() => Directory('.')
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .map((f) => f.path.replaceAll(r'\', '/'))
    .where((p) => !p.contains('/build/') && !p.contains('/.dart_tool/'));
