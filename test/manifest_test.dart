import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the Android permission set.
///
/// Every permission here is a line on the Play listing and an answer on the
/// Data Safety form, and `docs/data_safety_form_guide.md` certifies to Google
/// that this app transmits nothing. That certification is only true while the
/// manifest stays exactly as it is: adding `INTERNET` — as the deleted catalog
/// enrichment feature needed — silently makes the published declaration false,
/// and a Data Safety form that does not match observed traffic is grounds for
/// suspension.
///
/// So this test exists to fail when someone adds a permission, and to make
/// updating the declaration part of the same change rather than a thing
/// remembered later.
void main() {
  late final String manifest;

  setUpAll(() {
    final file = File('android/app/src/main/AndroidManifest.xml');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Run this from the package root; ${file.path} was not found.',
    );
    manifest = file.readAsStringSync();
  });

  group('AndroidManifest', () {
    test('requests exactly the permissions the app can justify', () {
      final requested = RegExp(r'<uses-permission\s+android:name="([^"]+)"')
          .allMatches(manifest)
          .map((m) => m.group(1))
          .toSet();

      expect(
        requested,
        unorderedEquals(<String>{
          // Barcode scanning and on-device label OCR.
          'android.permission.CAMERA',
          // Hold-to-speak voice queries, processed on-device.
          'android.permission.RECORD_AUDIO',
          // Network access for Google Play Billing and voluntary AdMob rewarded ads
          'android.permission.INTERNET',
        }),
        reason: 'Changing this set changes what must be declared in '
            'docs/data_safety_form_guide.md and docs/privacy_policy.md. '
            'Update those in the same commit, then update this test.',
      );
    });

    test('explicitly declares necessary permissions for offline & ads', () {
      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('android.permission.CAMERA'));
      expect(manifest, contains('android.permission.RECORD_AUDIO'));
    });

    test('keeps Android cloud backup off', () {
      // H-01. The database and its snapshots must not be copied to Google's
      // servers by the OS.
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:fullBackupContent="false"'));
    });

    test('declares the intent queries tap-to-call depends on', () {
      // M-01. url_launcher resolves every URI with ACTION_VIEW, so an
      // ACTION_DIAL query does not match and canLaunchUrl('tel:') returns
      // false under Android 11+ package visibility — tapping a supplier's
      // number silently did nothing.
      expect(manifest, contains('android.intent.action.VIEW'));
      expect(manifest, contains('android:scheme="tel"'));
    });
  });
}
