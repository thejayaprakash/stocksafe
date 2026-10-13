import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against the silent-failure pattern coming back.
///
/// Three buttons shipped as `if (await canLaunchUrl(uri)) { launchUrl(uri); }`
/// with no `else`, and a fourth called `launchUrl` with no check at all. On a
/// device where the URI does not resolve — which under Android 11+ package
/// visibility means any manifest missing the right `<queries>` entry — the
/// shopkeeper taps "Call Supplier" and nothing happens. No error, no
/// explanation.
///
/// That is not hypothetical: it is how tap-to-call shipped broken once
/// already (M-01), and nothing in the suite noticed.
///
/// These are source-level assertions rather than widget tests because the
/// failure is structural. A widget test would need the url_launcher platform
/// channel faked, and would still only cover the call sites someone remembered
/// to write a test for. What matters is that no page reaches for the launcher
/// directly, so handling failure is not something a future call site can
/// forget.
void main() {
  late final Map<String, String> uiSources;

  setUpAll(() {
    final dir = Directory('lib/src/ui');
    expect(dir.existsSync(), isTrue, reason: 'Run from the package root.');

    uiSources = {
      for (final f in dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')))
        f.path.replaceAll(r'\', '/'): f.readAsStringSync(),
    };
  });

  group('external app launching', () {
    test('no UI page calls the launcher directly', () {
      final offenders = <String>[];

      uiSources.forEach((path, source) {
        if (path.endsWith('widgets/external_app.dart')) return; // the one place
        if (RegExp(r'\b(launchUrl|canLaunchUrl)\s*\(').hasMatch(source)) {
          offenders.add(path);
        }
      });

      expect(
        offenders,
        isEmpty,
        reason: 'These pages call url_launcher directly, so they each decide '
            'for themselves what happens when it fails — and the answer has '
            'historically been "nothing, silently". Use ExternalApp instead.',
      );
    });

    test('the one place that does handles failure', () {
      final helper = File('lib/src/ui/widgets/external_app.dart');
      expect(helper.existsSync(), isTrue);
      final source = helper.readAsStringSync();

      // A failure the shopkeeper is told about...
      expect(
        source,
        contains('showSnackBar'),
        reason: 'A launch that fails must say so.',
      );
      // ...and can act on. A message that only says "cannot" leaves them
      // stuck; the number on the clipboard means they can still call.
      expect(
        source,
        contains('Clipboard.setData'),
        reason: 'Offer the number, so a failed launch is recoverable by hand.',
      );
      // canLaunchUrl being true does not promise launchUrl will succeed.
      expect(
        source,
        contains('catch'),
        reason: 'launchUrl can throw PlatformException even after a '
            'successful canLaunchUrl check.',
      );
    });

    test('the manifest still declares what tap-to-call resolves through', () {
      // url_launcher resolves every URI with ACTION_VIEW, so an ACTION_DIAL
      // query does not match and canLaunchUrl('tel:') returns false under
      // Android 11+ package visibility. manifest_test.dart covers this too;
      // repeated here because it is the root cause of the behaviour above.
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android.intent.action.VIEW'));
      expect(manifest, contains('android:scheme="tel"'));
    });
  });
}
