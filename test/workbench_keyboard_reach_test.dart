import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/workbench_chrome.dart';

/// The Workbench can be driven from the keyboard.
///
/// Its library doc calls it "a dense, flat, neutral, KEYBOARD-DRIVEN
/// desktop tool". On 2026-09-14 a measurement said otherwise: of 499
/// tappable nodes on the Browse screen only 41 were in the tab order,
/// and the entire top strip — Next chapter, Search, Analysis, Choose
/// versions, Command line, Copy Center, Settings — was outside it.
///
/// One widget draws all of that chrome, and it was a `MouseRegion` over
/// a `GestureDetector`: no focus node, so nothing to focus. This pins
/// the fix at the only place it can be undone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const seed = [
    Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'),
    Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'seed 2'),
  ];

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()..setVerses(seed)),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: const MaterialApp(home: WorkbenchPage()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the chrome buttons are in the tab order', (tester) async {
    await pump(tester);

    // Every focus node the tool icons own, counted through the widget
    // that draws them rather than through a guess at how many there are.
    final detectors = find.descendant(
      of: find.byType(WbToolIcon),
      matching: find.byType(FocusableActionDetector),
    );
    expect(detectors, findsWidgets,
        reason: 'the shared chrome affordance has no focus handling, so '
            'none of the toolbar is reachable by keyboard');

    // And the ENABLED ones are really focusable. A greyed control —
    // "Previous verse" at Genesis 1:1 — is deliberately not a tab stop:
    // tabbing onto something that cannot be activated is a dead end,
    // and the toolbar greys rather than hides so the reader can see the
    // command exists.
    final enabled = tester
        .widgetList<FocusableActionDetector>(detectors)
        .where((d) => d.enabled)
        .length;
    expect(enabled, greaterThan(0),
        reason: 'every chrome button is disabled, or none is focusable');
  });

  testWidgets('a focused chrome button paints a ring, and Enter fires it',
      (tester) async {
    var fired = 0;
    await tester.pumpWidget(ChangeNotifierProvider<AppSettings>(
      create: (_) => AppSettings(),
      child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: WbToolIcon(
            button: WbToolButton(
              icon: Icons.search,
              tooltip: 'Search',
              onPressed: () => fired++,
            ),
          ),
        ),
      ),
    )));
    await tester.pump();

    final detector = find.descendant(
      of: find.byType(WbToolIcon),
      matching: find.byType(FocusableActionDetector),
    );
    expect(detector, findsOneWidget);

    // Tab in.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(
      find
          .descendant(of: detector, matching: find.byType(Container))
          .first,
    );
    expect(container.foregroundDecoration, isNotNull,
        reason: 'a focused control must say so — the ring is painted as '
            'a FOREGROUND decoration so focusing cannot resize it');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(fired, 1, reason: 'Enter must activate a focused button');
  });

  testWidgets('hovering a button that is ON does not paint it off',
      (tester) async {
    // The only signal a toggle is on is its fill. Hover used to REPLACE
    // that fill with the ordinary hover colour, so an ON toggle and an
    // OFF one looked identical under the pointer — the state vanished
    // at the moment the reader was aiming at it.
    //
    // So the claim is not "hover changes something". It is that a
    // hovered ON button and a hovered OFF button still differ.
    await tester.pumpWidget(ChangeNotifierProvider<AppSettings>(
      create: (_) => AppSettings(),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WbToolIcon(
                  key: const ValueKey('on'),
                  button: WbToolButton(
                    icon: Icons.numbers,
                    tooltip: "Hide Strong's numbers",
                    active: true,
                    onPressed: () {},
                  ),
                ),
                WbToolIcon(
                  key: const ValueKey('off'),
                  button: WbToolButton(
                    icon: Icons.search,
                    tooltip: 'Search',
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    Color? fillOf(String key) => tester
        .widgetList<Container>(find.descendant(
            of: find.byKey(ValueKey(key)), matching: find.byType(Container)))
        .map((c) => c.color)
        .firstWhere((c) => c != null, orElse: () => null);

    final onResting = fillOf('on');
    expect(onResting, isNotNull, reason: 'an active button has a fill');
    expect(fillOf('off'), isNull, reason: 'an inactive one does not');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);

    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('off'))));
    await tester.pumpAndSettle();
    final offHovered = fillOf('off');
    expect(offHovered, isNotNull, reason: 'hover must be visible at all');

    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('on'))));
    await tester.pumpAndSettle();
    final onHovered = fillOf('on');

    expect(onHovered, isNot(offHovered),
        reason: 'an ON toggle under the pointer looks exactly like an OFF '
            'one — which is the defect: hover replaced the active fill '
            'instead of stepping from it');
    expect(onHovered, isNot(onResting), reason: 'and hover is still visible');
  });
}
