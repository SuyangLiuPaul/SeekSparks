/// 2026-08-25 (#315, the ninth shape): the smallest text a surface
/// actually PAINTS, measured, at both ends of the Font Size slider.
///
/// The source ratchet in `font_size_reach_ratchet_test.dart` proves that
/// no `fontSize:` is *written* below [WbMetrics.smallPrintFloor]. That
/// is a claim about the number, and it is not the same claim as this
/// one. A design size of 11 still paints 6.6 px if something above it
/// scales the subtree, and a size raised in one file can be overrun by a
/// container declared in another — the eighth pass of this ticket lost a
/// grid to exactly that.
///
/// So this measures the rendered spans, and it makes the DEFAULT the
/// headline case. Every earlier pass of #315 was about the reader having
/// moved the slider; the sites this one repairs were under the floor
/// with the slider untouched, which is why nine passes walked past them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/widgets/context_pane.dart';

void _ignoreVerse(int chapter, int verse) {}

/// Every painted span on screen, as (text, px).
///
/// Two traps, both paid for by earlier passes of this ticket and both
/// avoided here rather than rediscovered:
///
///  * an `Icon` is a `RichText` in the `MaterialIcons` family whose
///    `fontSize` is the GLYPH size, so an unfiltered sweep reports a
///    placeholder icon and never looks at text at all;
///  * a child `TextSpan` with no style of its own inherits its parent's,
///    so reading `span.style?.fontSize` alone silently drops it.
List<(String, double)> paintedSpans(WidgetTester tester) {
  final out = <(String, double)>[];
  void walk(InlineSpan span, double? inherited, String? family) {
    if (span is TextSpan) {
      final px = span.style?.fontSize ?? inherited;
      final fam = span.style?.fontFamily ?? family;
      final text = span.text;
      if (text != null && text.trim().isNotEmpty && px != null) {
        if (fam != 'MaterialIcons') out.add((text, px));
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child, px, fam);
      }
    }
  }

  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    walk(rt.text, null, null);
  }
  return out;
}

/// The claim this pass makes, stated so it can be checked at any stop of
/// the slider: no text is DESIGNED below [WbMetrics.smallPrintFloor], so
/// nothing paints below the floor carried down by the reader's own
/// scale. At the default that is the bare 11 px; at 12 pt it is 6.6.
///
/// It is deliberately not the stronger claim that nothing ever paints
/// below 11 px. That would require flooring every subordinate size in
/// the app, not just the ones that started under the floor, and the
/// floor would then eat the type ramp: at 12 pt every design size from
/// 11 to 18.3 collapses onto the same 11 px. [WbType.scaledSmall] exists
/// for text that is small print BY DESIGN and stops there; it is not a
/// policy for a surface's whole type scale. What that costs is real and
/// measured — see the note at the foot of this file.
void expectNothingUnderTheFloor(
    WidgetTester tester, String where, double scale) {
  final floor = WbMetrics.smallPrintFloor * scale;
  final under = [
    for (final (text, px) in paintedSpans(tester))
      // Sub-pixel: the scale is a division, and 11 * (12/20) lands a
      // few ulps either side of 6.6.
      if (px < floor - 0.001) '"$text" at ${px}px',
  ];
  expect(under, isEmpty,
      reason: '$where paints text below the app\'s own smallest size '
          'carried down by the reader\'s scale (${floor}px). '
          'WbMetrics.smallPrintFloor says small print "may reach it and '
          'stop; it may not go under it":\n${under.join('\n')}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChronologyData chronology;
  setUpAll(() async {
    chronology = await ChronologyService.instance.load();
  });

  // The Analysis pane's Context tab, against the real originals and the
  // real lexicon, at the narrowest width the pane is ever given.
  //
  // `runAsync` rather than `pumpAndSettle`: the pane loads from the
  // asset bundle and its spinner would keep a settle pumping until it
  // timed out. Lifted from `context_tab_test.dart`, which is where this
  // surface's harness was worked out.
  Future<AppSettings> pumpContext(WidgetTester tester, double fontSize) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettings();
    settings.setFontSize(fontSize);
    await tester.runAsync(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: MaterialApp(
          theme: workbenchTheme(
            ThemeData.light(),
            textScale: WbType.scaleFor(fontSize),
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              child: ContextPane(
                englishBook: 'John',
                chapter: 1,
                verse: 1,
                locale: 'en',
                version: 'kjv',
                onOpenVerse: _ignoreVerse,
              ),
            ),
          ),
        ),
      ));
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
    });
    // `setFontSize` notifies, and `AppSettings.notifyListeners` arms a
    // 600 ms debounce to write the prefs blob. Pumping past it here, in
    // fake time, keeps a second pump of the same surface from leaving
    // two of them for the teardown to trip over.
    await tester.pump(const Duration(milliseconds: 700));
    return settings;
  }

  Future<void> pumpChronology(WidgetTester tester, double fontSize) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 900);
    final settings = AppSettings();
    settings.setFontSize(fontSize);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          theme: workbenchTheme(
            ThemeData.light(),
            textScale: WbType.scaleFor(fontSize),
          ),
          home: const ChronologyPage(),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('the Context tab', () {
    testWidgets('paints nothing under the floor at the default setting',
        (tester) async {
      await pumpContext(tester, kFontSizeDefault);
      // The pane must actually be up; an empty screen passes any floor.
      expect(paintedSpans(tester).length, greaterThan(5));
      expectNothingUnderTheFloor(tester, 'the Context tab at the default',
          WbType.scaleFor(kFontSizeDefault));
    });

    testWidgets('and at both ends of the slider', (tester) async {
      await pumpContext(tester, kFontSizeMin);
      expectNothingUnderTheFloor(tester, 'the Context tab at $kFontSizeMin pt',
          WbType.scaleFor(kFontSizeMin));
      await pumpContext(tester, kFontSizeMax);
      expect(tester.takeException(), isNull);
    });
  });

  group('the chronology chart', () {
    // The axis labels are laid out by a `TextPainter` inside a private
    // `CustomPainter`, so they are NOT `RichText` and [paintedSpans] is
    // blind to them — this test passed against the pre-fix commit while
    // the axis was still drawing at 10 px. The size the painter was
    // handed is reachable, though, so read that instead of a span.
    //
    // The axis is chrome, not body text: `_axisFont` is `scaledChrome`,
    // and this harness never touches the Menu Size slider, so the
    // chrome scale here is 1 and the floor is the bare 11.
    testWidgets('the axis strip clears the floor at the default',
        (tester) async {
      await pumpChronology(tester, kFontSizeDefault);
      expect(chronology.patriarchs, isNotEmpty);
      final axis = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('chronologyAxis')));
      final painter = axis.painter! as dynamic;
      expect(painter.fontSize as double,
          greaterThanOrEqualTo(WbMetrics.smallPrintFloor),
          reason: 'the chronology axis draws its year ticks below the '
              "app's own smallest size");
      expectNothingUnderTheFloor(tester, 'the chronology chart at the default',
          WbType.scaleFor(kFontSizeDefault));
    });

    // The axis STRIP is measured from the axis font by `_axisHeight`,
    // through a `TextPainter` — raising the font raises the strip. That
    // is the property that made the font safe to raise, so it is the
    // property worth pinning: if someone replaces the measurement with
    // a pixel count, the labels start colliding with the bars and no
    // exception is thrown.
    testWidgets('and does not overflow at the largest setting',
        (tester) async {
      await pumpChronology(tester, kFontSizeMax);
      expect(tester.takeException(), isNull);
    });
  });
}

// WHAT THE RESTRAINT ABOVE COSTS, measured rather than guessed.
//
// At 12 pt the scale is 0.6, so this file's floor is 6.6 px and the
// Context tab passes while painting, on the same screen:
//
//   * a Thayer gloss at 6.9 px  (`scaled(11.5)`)
//   * an occurrence count at 8.4 px  (`scaled(14)`)
//   * `only here` and `/ 4` at 6.6 px  (`scaled(11)`)
//
// That is not residue from this pass — it is the setting working as
// designed. 183 of the app's 188 `fontSize: *.scaled(n >= 11)` sites
// paint under 11 px somewhere below the default, because the reader
// asked for smaller text and got it.
//
// Whether 12 pt should bottom out higher is a question about the
// SETTING'S RANGE, not about any one call site, and it cannot be
// answered by flooring sizes one at a time: a floor applied to some
// sites and not others inverts their rank at the bottom of the slider,
// which is worse than small text that is at least still ordered. If it
// is ever taken up, the lever is [kFontSizeMin] — one number, 29 stops,
// no rank to invert.

