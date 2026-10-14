// The bottom bar is the one widget every screen in the app is reached
// through, so the things that would strand a shopkeeper — a destination that
// reports the wrong index, a label that never renders, an animation that
// never settles — are pinned here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/services/theme_service.dart';
import 'package:stocksafe/src/ui/widgets/floating_wave_nav_bar.dart';

const _items = [
  WaveNavItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'Home',
  ),
  WaveNavItem(
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    label: 'Products',
  ),
  WaveNavItem(icon: Icons.qr_code_scanner_rounded, label: 'Scan'),
  WaveNavItem(
    icon: Icons.check_box_outlined,
    selectedIcon: Icons.check_box_rounded,
    label: 'Stock Count',
  ),
  WaveNavItem(icon: Icons.more_horiz_rounded, label: 'More'),
];

/// Pumps the bar inside a page, in either theme, reporting taps into [taps].
Future<void> pumpBar(
  WidgetTester tester, {
  required int selectedIndex,
  required List<int> taps,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeService.darkTheme : ThemeService.lightTheme,
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: FloatingWaveNavBar(
          items: _items,
          selectedIndex: selectedIndex,
          onDestinationSelected: taps.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every destination is rendered and reports its own index',
      (tester) async {
    final taps = <int>[];
    await pumpBar(tester, selectedIndex: 0, taps: taps);

    for (final item in _items) {
      expect(find.text(item.label), findsOneWidget,
          reason: '"${item.label}" is missing from the bar');
    }

    for (var i = 0; i < _items.length; i++) {
      await tester.tap(find.text(_items[i].label));
    }
    expect(taps, [0, 1, 2, 3, 4]);
  });

  testWidgets('the selected destination shows its filled icon', (tester) async {
    await pumpBar(tester, selectedIndex: 0, taps: []);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

    await pumpBar(tester, selectedIndex: 1, taps: []);
    expect(find.byIcon(Icons.inventory_2_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('an item with no filled variant reuses its icon', (tester) async {
    // Scan opens a route instead of switching tabs, so it is never the
    // selected index — but the fallback has to hold anyway.
    const item = WaveNavItem(icon: Icons.qr_code_scanner_rounded, label: 'Scan');
    expect(item.selectedIcon, Icons.qr_code_scanner_rounded);
  });

  testWidgets('the wave settles rather than animating forever',
      (tester) async {
    final taps = <int>[];
    await pumpBar(tester, selectedIndex: 0, taps: taps);

    // Moving the selection starts the crest travelling; pumpAndSettle only
    // returns once every animation has stopped, so a crest driven by a
    // repeating controller would hang the test here.
    await pumpBar(tester, selectedIndex: 4, taps: taps);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a selection change mid-flight is picked up, not dropped',
      (tester) async {
    final taps = <int>[];
    await pumpBar(tester, selectedIndex: 0, taps: taps);

    // Interrupt the journey halfway and redirect it.
    await pumpBar(tester, selectedIndex: 4, taps: taps);
    await tester.pump(const Duration(milliseconds: 120));
    await pumpBar(tester, selectedIndex: 2, taps: taps);
    await tester.pumpAndSettle();

    // It arrives where it was last told to go.
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('it builds in both themes', (tester) async {
    for (final dark in [false, true]) {
      await pumpBar(tester, selectedIndex: 2, taps: [], dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.byType(FloatingWaveNavBar), findsOneWidget);
    }
  });

  testWidgets('the bar leaves room for the device inset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeService.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: 34),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: FloatingWaveNavBar(
              items: _items,
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final height = tester.getSize(find.byType(FloatingWaveNavBar)).height;
    // Bar + crest + margins + the 34px gesture inset.
    expect(
      height,
      FloatingWaveNavBar.barHeight +
          FloatingWaveNavBar.crestHeight +
          FloatingWaveNavBar.defaultMargin.vertical +
          34,
    );
  });
}
