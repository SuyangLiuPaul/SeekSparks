// 2026-09-14: target size, measured on the real screen, on both kinds of
// device.
//
// The audit pumped `WorkbenchPage` at 1280x900 and read the rendered size
// of every `GestureDetector` / `InkWell` / `IconButton` in the tree: 73
// of 105 were under 24px in at least one dimension — the version popups
// 41x21, the tab strip 25x15, the pane chevrons 20x20.
//
// On the desktop that is the brief, not a bug. The library doc calls this
// "a dense, flat, neutral, keyboard-driven desktop tool" and the
// 2026-09-07 modernisation note says in as many words that density did
// not change. WCAG 2.5.8's rationale is touch and tremor; a 21px target
// under a mouse is ordinary desktop software, and growing every control
// to 24 would undo the thing the owner asked for twice.
//
// But the same widgets ship in the Android and iPad builds, where the
// criterion does apply, and nothing in the app varied by input device.
// So this file holds BOTH halves, and the second is the one that will
// catch the regression: touch gets 24, and the desktop is left exactly
// as dense as it was.
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/book.dart';
import 'package:seeksparks/models/chapter.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/workbench_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const seed = [
    Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed one'),
    Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'seed two'),
  ];

  /// Pump the workspace as [platform] and return the rendered size of
  /// every chrome control on screen.
  ///
  /// The platform comes from `debugDefaultTargetPlatformOverride`, not
  /// from `ThemeData(platform:)`, and the difference is the whole reason
  /// this note exists. Setting it on the outer MaterialApp theme looks
  /// like it works and does not: the workbench wraps its content in its
  /// own `Theme`, and a `ThemeData` built without an explicit platform
  /// takes `defaultTargetPlatform` — which under `flutter test` is
  /// **android**. The first draft of this file did that, so its "desktop"
  /// case was measuring a touch device; it passed the touch test and
  /// failed the desktop one, which is the only reason the mistake
  /// surfaced at all.
  ///
  /// Cleared in a `finally` INSIDE the body rather than in a tearDown:
  /// the framework asserts the override is unset when the body returns,
  /// and `addTearDown` runs after that check.
  ///
  /// `WbToolIcon` is the shared affordance — toolbar, pane titles, menu
  /// bar and status bar all draw through the same box — so measuring it
  /// measures the rule rather than one screen's arrangement.
  Future<List<Size>> measure(
      WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()
            ..currentBook = 'Genesis'
            ..currentChapter = 1
            ..setBooks([
              Book(title: 'Genesis',
                  chapters: [Chapter(title: 1, verses: seed)]),
            ])
            ..setVerses(seed)),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: WorkbenchPage()),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      final sizes = <Size>[
        for (final e in find.byType(WbToolIcon).evaluate())
          if (e.renderObject is RenderBox &&
              (e.renderObject as RenderBox).hasSize)
            (e.renderObject as RenderBox).size,
      ];
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      return sizes;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }


  /// Every tappable node on screen, by rendered size — the audit's own
  /// measurement, not just the shared chrome box.
  Future<List<Size>> measureAll(
      WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()
            ..currentBook = 'Genesis'
            ..currentChapter = 1
            ..setBooks([
              Book(title: 'Genesis',
                  chapters: [Chapter(title: 1, verses: seed)]),
            ])
            ..setVerses(seed)),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: WorkbenchPage()),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      final sizes = <Size>[
        for (final type in <Type>[GestureDetector, InkWell, IconButton])
          for (final e in find.byType(type).evaluate())
            if (e.renderObject is RenderBox &&
                (e.renderObject as RenderBox).hasSize)
              (e.renderObject as RenderBox).size,
      ];
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      return sizes;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// A pane divider: a thin strip running the height of the workspace,
  /// dragged rather than tapped. WCAG 2.5.8 exempts a target whose size
  /// is essential, and a divider's size IS its position — widen it and
  /// it stops being a boundary between two panes. 16px of grab strip is
  /// also not a small target in the direction that matters; it is 824
  /// long.
  bool isDivider(Size s) =>
      s.longestSide > 100 && s.shortestSide >= 12;

  testWidgets('on a touch device no chrome control is under 24px',
      (tester) async {
    final targets = await measure(tester, TargetPlatform.android);
    expect(targets, isNotEmpty,
        reason: 'no chrome controls on screen — this test would pass by '
            'measuring nothing');

    final small = targets
        .where((s) => s.width < 24 || s.height < 24)
        .map((s) => '${s.width.toStringAsFixed(1)}x'
            '${s.height.toStringAsFixed(1)}')
        .toList();
    expect(small, isEmpty,
        reason: 'WCAG 2.5.8 asks 24x24 on a device driven by touch, and '
            'these ship in the Android and iPad builds: ${small.join(", ")}');
  });

  testWidgets('on a desktop the density is untouched', (tester) async {
    // The other half, and the one worth having: a well-meant later
    // change that raised the desktop to 24 as well would pass the test
    // above and quietly undo the brief. The workspace is meant to be
    // dense under a mouse.
    final targets = await measure(tester, TargetPlatform.macOS);
    expect(targets, isNotEmpty);

    final dense = targets.where((s) => s.height < 24).length;
    expect(dense, greaterThan(0),
        reason: 'every chrome control is now at least 24px tall on the '
            'desktop too. That is not this tool: "a dense, flat, '
            'neutral, keyboard-driven desktop tool", and density did not '
            'change on 2026-09-07 when everything else did');
  });

  test('the rule itself says 24 on touch and nothing on a pointer', () {
    for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
      expect(WbMetrics.minTarget(p), 24.0, reason: '$p');
    }
    for (final p in [TargetPlatform.macOS, TargetPlatform.windows,
                     TargetPlatform.linux, TargetPlatform.fuchsia]) {
      expect(WbMetrics.minTarget(p), 0.0,
          reason: '$p is pointer-driven; a minimum here would add padding '
              'the brief does not want');
    }
  });


  testWidgets('the whole screen, both ways round', (tester) async {
    // The audit's measurement, repeated as a test, because the shared
    // chrome box is not the only thing a reader taps: the command pane
    // draws its own operator strip and its own mini icons, and neither
    // goes through `_HoverBox`. 73 of 105 nodes were under 24px when
    // this started.
    final touch = await measureAll(tester, TargetPlatform.android);
    final small = <String>[
      for (final size in touch)
        if (!isDivider(size) && (size.width < 24 || size.height < 24))
          '${size.width.toStringAsFixed(0)}x'
              '${size.height.toStringAsFixed(0)}',
    ];
    expect(small, isEmpty,
        reason: 'on a touch device these are under 24px and are not '
            'dividers: ${small.join(", ")}');

    final desktop = await measureAll(tester, TargetPlatform.macOS);
    final dense = desktop
        .where((s) => !isDivider(s))
        .where((s) => s.width < 24 || s.height < 24)
        .length;
    expect(dense, greaterThan(10),
        reason: 'the desktop workspace has lost its density — only '
            '$dense controls are under 24px now. This tool is meant to '
            'be dense under a mouse; the touch floor must not reach it');
  });
}
