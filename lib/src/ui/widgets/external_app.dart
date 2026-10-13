import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands a URI to another app, and says something useful when that fails.
///
/// Three buttons used to do this themselves, and two of them did it like this:
///
/// ```dart
/// if (await canLaunchUrl(uri)) { await launchUrl(uri); }
/// ```
///
/// With no `else`, a shopkeeper who taps "Call Supplier" on a phone where the
/// URI will not resolve sees the button depress and nothing happen. No error,
/// no explanation — the app simply looks broken, and the most likely reaction
/// is to tap it harder.
///
/// That is not hypothetical here. `canLaunchUrl` resolves through
/// `ACTION_VIEW`, so under Android 11+ package visibility it returns false
/// unless the manifest declares a matching `<queries>` entry. Getting that
/// wrong is invisible in debug and silent in release — which is exactly how
/// tap-to-call shipped broken once already (M-01).
///
/// So failure is handled in one place, and it does two things: it says what
/// went wrong in words a shopkeeper can act on, and it puts the number on the
/// clipboard so they can still make the call by hand. A message that only says
/// "cannot" leaves them stuck; a number in the clipboard does not.
class ExternalApp {
  const ExternalApp._();

  /// Opens the phone dialler with [phone] filled in.
  static Future<void> dial(BuildContext context, String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return _open(
      context,
      Uri.parse('tel:$clean'),
      whenUnavailable: 'No phone app could be opened.',
      copyable: clean,
      copyLabel: 'Copy number',
    );
  }

  /// Opens a WhatsApp conversation with [phone], pre-filled with [message].
  ///
  /// `wa.me` is an https link, so this resolves to a browser when WhatsApp is
  /// absent — which is the desired fallback, not a failure.
  static Future<void> whatsApp(
    BuildContext context,
    String phone, {
    required String message,
  }) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return _open(
      context,
      Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(message)}'),
      mode: LaunchMode.externalApplication,
      whenUnavailable: 'WhatsApp could not be opened.',
      copyable: clean,
      copyLabel: 'Copy number',
    );
  }

  static Future<void> _open(
    BuildContext context,
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
    required String whenUnavailable,
    String? copyable,
    String? copyLabel,
  }) async {
    // Captured before the first await. The call sites sit inside a modal
    // bottom sheet, and holding its BuildContext across an async gap would
    // break if the sheet closed while the platform channel was in flight.
    final messenger = ScaffoldMessenger.of(context);

    try {
      // canLaunchUrl being true does not promise launchUrl will succeed — the
      // resolving app can disappear between the two calls, or refuse the
      // intent — so the result is checked rather than assumed.
      if (await canLaunchUrl(uri) && await launchUrl(uri, mode: mode)) {
        return;
      }
    } catch (_) {
      // PlatformException from the channel. Falls through to the same message:
      // the distinction matters to us, not to the shopkeeper.
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          copyable == null ? whenUnavailable : '$whenUnavailable $copyable',
        ),
        action: copyable == null
            ? null
            : SnackBarAction(
                label: copyLabel ?? 'Copy',
                onPressed: () => Clipboard.setData(ClipboardData(text: copyable)),
              ),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}
