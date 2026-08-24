// 2026-08-24 (#315): the sizes no detector in the repo could see.
//
// Three source detectors already police the Font Size slider's reach —
// a literal, a saturating clamp, and a correct size inside a FittedBox.
// This pass found two more mechanisms that all three were blind to, and
// both of them lived inside files the ratchet certified as FINISHED:
//
//   6. a design constant wearing a principled name.
//      `fontSize: WbMetrics.text` names the app's own type scale, so it
//      reviews as the fix. `WbMetrics` is where the sizes AT THE
//      DEFAULT are written down; only `WbType` multiplies them by what
//      the reader chose. Five of the fourteen sites were the
//      workbench's own empty states.
//
//   7. a literal on the far side of a question mark.
//      `fontSize: _st.dense ? _st.body : 13`. The ratchet's regex
//      anchored the number to the colon, so one token of distance hid
//      it, and the clamp detector required a NUMERIC offset, so
//      `(settings.fontSize - (compact ? 4 : 2)).clamp(11, 15)` hid too.
//
// The ratchet was upgraded to see both, and each new detector was
// confirmed to FIRE by reverting the site it was written for. That
// proves the source is clean. It does not prove the reader's slider
// moves anything, because a source rule cannot distinguish a size that
// travels from one that is immediately overwritten — so the claim is
// measured here, on the painted tree, at both ends of the slider.
//
// Why these three surfaces:
//
//   * `_analysisHint` is the placeholder for ELEVEN analysis tabs and
//     is called from thirteen places. It is the FIRST text in the pane
//     — a reader who has not yet tapped a verse sees nothing else, and
//     it is the sentence telling them what to tap. At 40 pt it was 12
//     px, which is the reported defect at its most literal.
//   * `ContactLine` is the only route in the app to a human, and it
//     sits at the bottom of the page the slider itself lives on.
//   * `ConfidenceBadge` is the one that saturated on BOTH branches of
//     its ternary, so no setting and no call site ever moved it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/confidence_badge.dart';
import 'package:seeksparks/widgets/contact_line.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every painted size in the tree, keyed by the text it painted.
  ///
  /// This reads what the tree PRODUCED rather than what some
  /// `TextStyle` in the source says — but it has to descend to do it.
  /// `Text.rich(span)` does not paint `span`: it builds
  /// `RichText(text: TextSpan(style: <the DefaultTextStyle>, children:
  /// [span]))`, so the root style is whatever the theme inherited and
  /// the size the widget actually asked for is one level down. Reading
  /// `richText.text.style.fontSize` reports Material's default 14 for
  /// every `Text.rich` in the app, at every setting — this instrument
  /// said the repaired `ContactLine` was frozen at 14.0 at 12, 20 AND
  /// 40 pt, which is a false negative in the shape of the very defect
  /// under test.
  Map<String, double> painted(WidgetTester tester) {
    final out = <String, double>{};
    void visit(InlineSpan span, double? inherited) {
      if (span is! TextSpan) return;
      final size = span.style?.fontSize ?? inherited;
      final text = span.text;
      if (text != null && text.trim().isNotEmpty && size != null) {
        out[text] = size;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, size);
      }
    }

    for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
      visit(w.text, null);
    }
    return out;
  }

  // `AppSettings` takes its locale from the platform, so the strings
  // these surfaces paint are looked up rather than typed — on this
  // machine the workbench hint is 「在中间的经文面板点选一节…」, not the
  // English fallback in the source.
  var locale = 'en';

  double sizeOf(Map<String, double> m, String needle) {
    for (final e in m.entries) {
      if (e.key.contains(needle)) return e.value;
    }
    fail('no painted text containing "$needle" — tree rendered '
        '${m.keys.toList()}');
  }

  /// A widget with nothing above it but the providers it needs.
  Future<Map<String, double>> sizesOf(
      WidgetTester tester, Widget child, double fontSize) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    final settings = AppSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: MaterialApp(home: Scaffold(body: Center(child: child))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    settings.setFontSize(fontSize);
    // `setFontSize` debounces its write to prefs, and MaterialApp wraps
    // its theme in an AnimatedTheme — a single pump reads the tree
    // mid-lerp and leaves the timer pending. Settle past both.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    locale = settings.locale;
    return painted(tester);
  }

  group('the workbench empty states obey the slider', () {
    /// The workbench at [fontSize], wide enough for all three panes.
    ///
    /// Fixed pumps rather than `pumpAndSettle`: the reader kicks off
    /// async loads whose spinners never settle, which is the same
    /// reason `workbench_page_test.dart` does it this way.
    Future<Map<String, double>> workbenchAt(
        WidgetTester tester, double fontSize) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);
      final settings = AppSettings();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) {
              final mp = MainProvider();
              mp.setVerses(const [
                Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'),
              ]);
              mp.setCurrentChapter(book: 'Genesis', chapter: 1);
              return mp;
            }),
            ChangeNotifierProvider<AppSettings>.value(value: settings),
          ],
          child: const MaterialApp(home: WorkbenchPage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      settings.setFontSize(fontSize);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      locale = settings.locale;
      return painted(tester);
    }

    testWidgets('the analysis hint travels with the reader', (tester) async {
      // 12.0 is `WbMetrics.text`, and it is what this hint painted at
      // EVERY stop of the slider before the repair. The three numbers
      // below are the same 12 on the reader's scale.
      final small = await workbenchAt(tester, 12);
      final mid = await workbenchAt(tester, 20);
      final big = await workbenchAt(tester, 40);

      final needle = uiStrings['analysisEmptyHint']![locale]!;
      // The default is untouched: a repair a reader can see is a
      // redesign, and this is not one.
      expect(sizeOf(mid, needle), WbMetrics.text);
      expect(sizeOf(big, needle), WbMetrics.text * 2,
          reason: 'the top of the slider is where the defect lived');
      expect(sizeOf(small, needle), closeTo(WbMetrics.text * 0.6, 0.01));
    });
  });

  testWidgets('the contact line travels with the reader', (tester) async {
    // `(fontSize - 2).clamp(11, 15)` was already pinned at 15 at the
    // 20 pt default, so the slider moved this line only DOWNWARD and
    // only below 17 pt — 24 of its 29 stops did nothing.
    const needle = 'Paul Liu';
    final mid = await sizesOf(tester, const ContactLine(), 20);
    final big = await sizesOf(tester, const ContactLine(), 40);
    final small = await sizesOf(tester, const ContactLine(), 12);

    expect(sizeOf(mid, needle), 15.0, reason: 'the shipped default');
    expect(sizeOf(big, needle), 30.0);
    // Floored rather than allowed to stop being print: 15 × 0.6 is 9.
    expect(sizeOf(small, needle), WbMetrics.smallPrintFloor);
  });

  testWidgets('the confidence badge travels with the reader', (tester) async {
    // Both branches of `(fontSize - (prominent ? 1 : 3)).clamp(10, 16)`
    // saturated at 16 from 19 pt up, so list card and detail page
    // painted the same 16 px at every stop from below the default.
    for (final prominent in <bool>[false, true]) {
      Widget badge() => ConfidenceBadge(
          level: 'Strong', color: Colors.teal, prominent: prominent);
      // The badge paints exactly one string, and which string depends
      // on the platform locale — so it is read by being the only one
      // rather than by being named.
      double only(Map<String, double> m) {
        expect(m, hasLength(1), reason: 'the badge painted ${m.keys.toList()}');
        return m.values.single;
      }

      expect(only(await sizesOf(tester, badge(), 20)), 16.0,
          reason: 'the shipped default, kept for both branches: this pill '
              'shares a Row with the evidence title (prominent: $prominent)');
      expect(only(await sizesOf(tester, badge(), 40)), 32.0,
          reason: 'prominent: $prominent');
      // 16 × 0.6 is 9.6; small print stays print.
      expect(only(await sizesOf(tester, badge(), 12)),
          WbMetrics.smallPrintFloor,
          reason: 'prominent: $prominent');
    }
  });
}
