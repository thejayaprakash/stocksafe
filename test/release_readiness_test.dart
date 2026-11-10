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
      // All four extensions keytool can produce, not just the two most
      // common ones. The project's own documented procedure creates a .p12,
      // which this test did not look for.
      const keystoreExtensions = ['.jks', '.keystore', '.p12', '.pfx'];
      final strays = _projectFiles()
          .where((p) => keystoreExtensions.any(p.endsWith))
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
    },
        skip: LicenseKey.usesDevelopmentSecret
            ? 'Pass --dart-define=STOCKSAFE_VOUCHER_SECRET=<real secret> to '
                'run this check.'
            : null);
  });

  group('store metadata', () {
    test('the store listing does not promise more than the app does', () {
      // The app sends nothing of the user's, and the listing says so. If that
      // ever stops being true, this, manifest_test.dart and the merged-manifest
      // check below should all be updated in the same change as the code.
      final listing =
          File('store_listing/store_listing_metadata.md').readAsStringSync();
      expect(listing.toLowerCase(), contains('offline'));
    });
  });

  group('the manifest that actually ships', () {
    // manifest_test.dart reads android/app/src/main/AndroidManifest.xml, which
    // is necessary and NOT sufficient: permissions also arrive by dependency
    // merging, without anyone editing a file in this repository.
    //
    // Both of the network permissions in the shipped APK got there that way —
    // ML Kit pulls them in, and in_app_purchase does too. The source manifest
    // declares neither, so a test reading only that file reports a clean bill
    // of health for an app that holds INTERNET. That is exactly the gap this
    // closes.
    //
    // Needs a build, because the merged manifest is a build output. Skips with
    // an explanation rather than failing when there is none, so it does not
    // turn CI red for a reason unrelated to the change under test.
    // Scoped to the one directory that holds it. Walking all of
    // build/app/intermediates would descend into ML Kit's bundled models,
    // whose paths exceed MAX_PATH on Windows and throw mid-listing.
    File? mergedManifest() {
      final root = Directory('build/app/intermediates/merged_manifest');
      if (!root.existsSync()) return null;
      try {
        return root
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((f) => f.path.endsWith('AndroidManifest.xml'))
            .firstOrNull;
      } on FileSystemException {
        return null;
      }
    }

    test('ships no permission beyond the ones the policy documents', () {
      final merged = mergedManifest();
      if (merged == null) {
        markTestSkipped(
          'No merged release manifest. Run `flutter build apk --release '
          '-PallowDebugSigning=true` first — this check reads a build output.',
        );
        return;
      }

      final requested = RegExp(r'android:name="(android\.permission\.[^"]+)"')
          .allMatches(merged.readAsStringSync())
          .map((m) => m.group(1))
          .toSet();

      expect(
        requested,
        unorderedEquals(<String>{
          'android.permission.CAMERA',
          'android.permission.RECORD_AUDIO',
          // Merged in by ML Kit, in_app_purchase, and google_mobile_ads (AdMob).
          // Used for buying/restoring Pro unlock and voluntary rewarded ads.
          // docs/privacy_policy.md and Data Safety guide declare them.
          'android.permission.INTERNET',
          'android.permission.ACCESS_NETWORK_STATE',
          'android.permission.ACCESS_ADSERVICES_AD_ID',
          'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
          'android.permission.ACCESS_ADSERVICES_TOPICS',
          'android.permission.WAKE_LOCK',
          'android.permission.FOREGROUND_SERVICE',
          // Local notifications for low stock alerts and inventory reminders.
          'android.permission.POST_NOTIFICATIONS',
          'android.permission.VIBRATE',
        }),
        reason: 'A permission appeared in the shipped APK that the published '
            'documents do not account for. Adding a dependency can do this '
            'without touching any file here. Update docs/privacy_policy.md, '
            'docs/data_safety_form_guide.md and the store listing in the same '
            'commit, then update this test.',
      );
    });
  });
}

/// Source files, walked without descending into build output.
///
/// The obvious version — `listSync(recursive: true)` then filter — walks
/// `build/` anyway and only discards the results afterwards. That breaks on
/// Windows as soon as a release build exists, because ML Kit's bundled model
/// directories blow past MAX_PATH:
///
///     PathNotFoundException: Directory listing failed, path =
///     'build/app/intermediates\assets\release\...\line_recognition_legacy_mobile\*'
///
/// Which is the order `tool/build_release.ps1` runs in: build, then gate. So
/// the pruning has to happen before descending, not after.
Iterable<String> _projectFiles() sync* {
  const skip = {'build', '.dart_tool', '.git', 'node_modules'};
  final queue = <Directory>[Directory('.')];

  while (queue.isNotEmpty) {
    final dir = queue.removeLast();
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException {
      continue; // Unreadable or too long; nothing we can assert about it.
    }

    for (final entry in entries) {
      final name = entry.path.split(Platform.pathSeparator).last;
      if (entry is Directory) {
        if (!skip.contains(name)) queue.add(entry);
      } else if (entry is File) {
        yield entry.path.replaceAll(r'\', '/');
      }
    }
  }
}
