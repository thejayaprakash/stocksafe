// The voice assistant used to empty the screen.
//
// Speech recognition reports partial results, so the dialog's onResult fires
// roughly once per word. Each call scheduled its own delayed Navigator.pop,
// so a sentence queued several: the first closed the dialog and the rest
// popped the pages underneath, leaving nothing on screen until the app was
// relaunched. Reported from the field as "say add this product and rate of
// xyz, get a blank screen, restart to recover".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/services/voice_assistant_service.dart';

void main() {
  group('A spoken sentence produces many results, not one', () {
    test('every prefix of a sentence parses, so onResult fires repeatedly', () {
      // This is the input that caused it. Each prefix is a partial result the
      // recogniser delivers, and each one reached the dialog.
      const spoken = 'add this product and rate of xyz';
      final words = spoken.split(' ');

      var deliveries = 0;
      for (var i = 1; i <= words.length; i++) {
        final partial = words.take(i).join(' ');
        // Mirrors the service's condition: anything non-empty is delivered.
        if (partial.trim().isNotEmpty) deliveries++;
      }

      expect(deliveries, greaterThan(1),
          reason: 'the dialog must not treat each delivery as a decision');
      expect(deliveries, words.length);
    });

    test('a recognised intent appears on more than one partial', () {
      // The dialog closes when intent != unknown. If several partials of the
      // same sentence satisfy that, an unlatched dialog schedules several
      // pops - which is precisely what emptied the stack.
      const spoken = 'show me low stock items';
      final words = spoken.split(' ');

      var recognised = 0;
      for (var i = 1; i <= words.length; i++) {
        final parsed =
            VoiceAssistantService.parseCommand(words.take(i).join(' '));
        if (parsed.intent != VoiceIntentType.unknown &&
            parsed.rawTranscript.trim().length > 3) {
          recognised++;
        }
      }

      expect(recognised, greaterThan(1),
          reason: 'more than one partial would have triggered a pop');
    });
  });

  group('The dialog closes itself once, and only itself', () {
    late String src;

    setUpAll(() {
      src = File('lib/src/ui/widgets/voice_assistant_dialog.dart')
          .readAsStringSync();
    });

    test('it latches before scheduling a close', () {
      expect(src, contains('bool _closing = false;'));
      expect(src, contains('if (!_closing &&'),
          reason: 'without the latch each partial result schedules a pop');
      expect(src, contains('_closing = true;'));
    });

    test('nothing pops the navigator directly any more', () {
      // One door out, so a future edit cannot reintroduce a bare pop.
      final bare = RegExp(r'Navigator\.pop\(context').allMatches(src).length;
      expect(bare, 1,
          reason: 'only _close should call Navigator.pop; found $bare');
    });

    test('it refuses to pop a route that is no longer on top', () {
      // mounted is not enough: the later callbacks fire while this route is
      // still animating out, and would take the page underneath with them.
      expect(src, contains('route.isCurrent'));
    });
  });

  group('Voice goes where it says', () {
    late String home;

    setUpAll(() {
      home = File('lib/src/ui/home_page.dart').readAsStringSync();
    });

    test('low stock and expiring open the stock alerts page', () {
      // They set _tabIndex = 1 under the old three-tab layout, where 1 was
      // Low Stock. After the rework 1 is Products, so the command silently
      // opened the catalogue.
      final handler = home.substring(
        home.indexOf('switch (result.intent)'),
        home.indexOf('PreferredSizeWidget? _buildAppBar'),
      );
      final lowStock = handler.substring(
        handler.indexOf('navigateLowStock'),
        handler.indexOf('navigateAudit'),
      );
      expect(lowStock, contains('LowStockPage'));
      expect(lowStock, isNot(contains('_tabIndex = 1')));
    });

    test('no tab index renders an empty screen', () {
      // Case 2 (Scan) was missing and fell through to SizedBox.shrink(),
      // which looks exactly like the crash this whole file is about.
      // Scoped to _buildBody: shrink() is legitimate elsewhere, for an empty
      // category bar or a valuation with nothing to value.
      final body = home.substring(
        home.indexOf('Widget _buildBody()'),
        home.indexOf('Widget? _buildFab('),
      );
      expect(body, contains('default:'));
      expect(body, isNot(contains('SizedBox.shrink()')),
          reason: 'a tab with no body is indistinguishable from a crash');
    });
  });
}
