// 2026-08-25 (task #315): 冷知识 obeys the Font Size slider.
//
// This page was the largest single item left on #315 — 23 sites in one
// file, budgeted rather than fixed by `font_size_reach_ratchet_test.dart`
// on the grounds that it is "a game rather than a study surface". That
// justification was wrong. The page renders pointed Hebrew
// (בְּרֵאשִׁית, אֱלֹהִים), the 22-letter alphabet, Genesis 1:1 word by
// word with transliteration and gloss, and acrostic verse-count charts.
// It is a study surface, and it was deaf.
//
// Measured before the repair, by pumping the page at three settings:
//
//     site                        12 pt   20 pt   40 pt
//     search field                  13      17      17
//     entry title                   14      19      19
//     entry body                    12      17      17
//     reference beside the title    10      12      12
//     pointed Hebrew word           16      16      16
//     Hebrew letter                 18      18      18
//     romanised letter name          8       8       8
//
// Between 20 pt and 40 pt — half the slider's travel — nothing the page
// SIZED FOR ITSELF changed at all. Five clamps all saturated at or below
// the app's own default (at 17 or 18 pt), so the clamped sites offered 3
// to 6 distinct values across 29 stops and the literals offered one.
//
// Said that carefully, because a first pass here claimed "nothing on the
// page changed" full stop, and that was the harness talking. Eleven
// `Text()` widgets on the page carry no `style:` at all — the AppBar
// title, the segmented-button labels, the Apply button — and those DID
// travel, off `workbenchTheme`'s scaled typography. A probe that pumps
// `MaterialApp` without the app's theme cannot see the difference,
// because it leaves them on stock Material 3.
//
// The headline is the third row from the bottom. `WbMetrics.originalFloor`
// records that below 14 px qamats/patach and tsere/segol collapse into a
// single grey smudge; this page drew pointed Hebrew at a frozen 16, so a
// reader who raised the slider to 40 pt PRECISELY BECAUSE the vowels were
// illegible got 16 px anyway.
//
// Three sizes change at the default setting, all upward, and all because
// they were below the workbench's own 11 px small-print floor: the
// romanised letter name (8), the chapter-chart index (10) and the
// sequence caption (10). Those were the only three fontSize LITERALS
// below 11 anywhere in `lib/` — though not the smallest sizes the app
// renders, since `radial_chronology_page.dart` and `originals_sheet.dart`
// reach 7.5 and 8 px at the default through an unfloored `t.scaled(...)`.
// Those travel with the slider, so they are not this ticket, but they are
// the same legibility question and #315 should look at them next.
//
// Everything else renders at 20 pt exactly as it did before, which the
// last test here asserts site by site.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/bible_trivia_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/wb_surfaces.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pump the page under the app's OWN theme, narrowed to one entry and
  /// with that entry expanded.
  ///
  /// `workbenchTheme` is not decoration here. A bare `MaterialApp` leaves
  /// every chip and segmented button on stock Material 3, which sizes its
  /// labels at a flat 14 px — a probe built that way reported 14 at 12,
  /// 20 and 40 pt and looked exactly like a tenth #315 mechanism. It was
  /// the harness. The component themes have been on the reader's scale
  /// since v1.6.159 (`workbench_theme.dart`, `onScale`).
  ///
  /// The locale is forced to English so the assertions can name the
  /// strings they measure; the sizes under test are locale-independent.
  Future<void> pumpEntry(WidgetTester tester, double fontSize,
      String reference, String tileNeedle) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 2400);
    addTearDown(tester.view.reset);

    final settings = AppSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: Builder(builder: (ctx) {
          final s = ctx.watch<AppSettings>();
          return MaterialApp(
            theme: workbenchTheme(
              ThemeData(fontFamily: s.fontFamily),
              textScale: WbType.scaleFor(s.fontSize),
            ),
            home: const BibleTriviaPage(),
          );
        }),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await settings.setLocale('en');
    settings.setFontSize(fontSize);
    // MaterialApp wraps its theme in an AnimatedTheme, so a single pump
    // reads the tree mid-lerp.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    // The search box matches an entry's reference verbatim, which is the
    // one field that does not change with the locale.
    await tester.enterText(find.byType(TextField).first, reference);
    await tester.pump(const Duration(milliseconds: 300));

    // By the entry's TITLE, not its reference: the tile prints the
    // reference through `localizedReferenceLabel`, which renders the
    // catalogue's 'Psalm 119' as the canonical 'Psalms 119'.
    final tile = find.ancestor(
        of: find.textContaining(tileNeedle), matching: find.byType(WbTile));
    expect(tile, findsWidgets,
        reason: 'no tile for "$reference" — the search filter or the '
            'catalogue changed, and an empty list passes every assertion '
            'below without measuring anything');
    await tester.tap(tile.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Every DECLARED text size on the page, keyed by the string it was
  /// declared on.
  ///
  /// Spans are walked rather than read off the root, because `Text.rich`
  /// WRAPS the span it is given: the root's style is the ambient
  /// `DefaultTextStyle` and the size the widget actually asked for is on
  /// the children. Icons are skipped — an `Icon` is a `RichText` in the
  /// `MaterialIcons` family whose `fontSize` is the glyph's size.
  Map<String, double> declaredSizes(WidgetTester tester) {
    final out = <String, double>{};
    void visit(InlineSpan span) {
      final style = span.style;
      final size = style?.fontSize;
      final label = span.toPlainText(includeSemanticsLabels: false);
      if (size != null &&
          style?.fontFamily != 'MaterialIcons' &&
          label.trim().isNotEmpty) {
        out[label] = size;
      }
      if (span is TextSpan) {
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child);
        }
      }
    }

    for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
      visit(w.text);
    }
    return out;
  }

  double sizeOf(Map<String, double> m, String needle) {
    for (final e in m.entries) {
      if (e.key.contains(needle)) return e.value;
    }
    fail('no text containing "$needle" — the page rendered '
        '${m.keys.take(40).toList()}');
  }

  // Reference (what the search box matches, verbatim from the catalogue)
  // paired with a fragment of the entry's English title (what locates the
  // tile in the tree).
  const alphabet = ('Psalm 119', 'A Hebrew alphabet acrostic');
  const chart = ('Lamentations 3', 'Five poems, four are alphabetic');
  const sequence = ('Matthew 1:17', 'genealogy is built around 14');
  const words = ('Genesis 1:1', 'Seven appears in Hebrew');
  const diagrams = <(String, String)>[alphabet, chart, sequence, words];

  // ---------------------------------------------------------------
  // Reach.
  // ---------------------------------------------------------------

  testWidgets('the alphabet grid reaches the top of the slider',
      (tester) async {
    await pumpEntry(tester, 20, alphabet.$1, alphabet.$2);
    final mid = declaredSizes(tester);
    await pumpEntry(tester, 40, alphabet.$1, alphabet.$2);
    final big = declaredSizes(tester);

    // Half the slider's travel used to move none of these.
    expect(sizeOf(big, 'א'), sizeOf(mid, 'א') * 2,
        reason: 'the Hebrew letter was frozen at 18 px at every setting');
    expect(sizeOf(big, 'Aleph'), sizeOf(mid, 'Aleph') * 2,
        reason: 'the romanised name was frozen at 8 px at every setting');
    expect(sizeOf(big, 'Psalms 119'), sizeOf(mid, 'Psalms 119') * 2,
        reason: 'the reference clamp saturated at 12 px from 17 pt up');
  });

  testWidgets('Genesis 1:1 word by word reaches the top of the slider',
      (tester) async {
    await pumpEntry(tester, 20, words.$1, words.$2);
    final mid = declaredSizes(tester);
    await pumpEntry(tester, 40, words.$1, words.$2);
    final big = declaredSizes(tester);

    expect(sizeOf(mid, 'בְּרֵאשִׁית'), 16.0);
    expect(sizeOf(big, 'בְּרֵאשִׁית'), 32.0,
        reason: 'pointed Hebrew was frozen at 16 px — one pixel above the '
            'floor below which the vowels are a smudge — so a reader who '
            'raised the slider BECAUSE of the vowels got nothing');
    expect(sizeOf(big, 'bereshit'), sizeOf(mid, 'bereshit') * 2);
  });

  // ---------------------------------------------------------------
  // Rank, and the two floors.
  // ---------------------------------------------------------------

  testWidgets('the entry title stays above its body and its reference',
      (tester) async {
    for (final pt in <double>[12, 16, 20, 26, 32, 40]) {
      await pumpEntry(tester, pt, alphabet.$1, alphabet.$2);
      final m = declaredSizes(tester);
      final title = sizeOf(m, 'A Hebrew alphabet acrostic');
      final body = sizeOf(m, 'The longest chapter in the Bible');
      final reference = sizeOf(m, 'Psalms 119');

      expect(title, greaterThan(body),
          reason: 'at $pt pt the title is $title px over a body of $body');
      // Not `greaterThan`: at the bottom of the slider both the body and
      // the reference sit on the 11 px small-print floor and are equal.
      // A floor cannot preserve a ratio it has stopped applying — what it
      // must not do is INVERT, and that is what is asserted.
      expect(body, greaterThanOrEqualTo(reference),
          reason: 'at $pt pt the grey reference label is $reference px over '
              'a body of $body — the metadata is larger than the prose');
    }
  });

  testWidgets('pointed Hebrew never falls under the vowel floor',
      (tester) async {
    for (final pt in <double>[12, 14, 16, 20]) {
      await pumpEntry(tester, pt, words.$1, words.$2);
      expect(sizeOf(declaredSizes(tester), 'בְּרֵאשִׁית'),
          greaterThanOrEqualTo(WbMetrics.originalFloor),
          reason: 'at $pt pt the pointed text is below the floor at which '
              'qamats and patach stop being distinguishable');
    }
  });

  testWidgets('nothing on the page is drawn below the small-print floor',
      (tester) async {
    // The only three fontSize literals below 11 in `lib/` lived on this
    // page: 8.0 and both instances of 10.0.
    for (final entry in diagrams) {
      await pumpEntry(tester, 20, entry.$1, entry.$2);
      declaredSizes(tester).forEach((label, size) {
        expect(size, greaterThanOrEqualTo(WbMetrics.smallPrintFloor),
            reason: '"$label" is drawn at $size px on the ${entry.$1} entry');
      });
    }
  });

  // ---------------------------------------------------------------
  // The containers the type used to outgrow.
  // ---------------------------------------------------------------

  /// Every [RenderFlex] asking for more room than it was given.
  ///
  /// Zero-sized flexes are excluded: `AnimatedCrossFade` keeps BOTH
  /// children in the tree and lays the hidden one out at 0 × 0, so an
  /// unfiltered walk reports about forty "wants 16 got 0" artefacts on
  /// this page and hides the one real answer.
  List<String> overflowing(WidgetTester tester) {
    final out = <String>[];
    void walk(RenderObject o) {
      if (o is RenderFlex &&
          !o.debugNeedsLayout &&
          o.size.height > 0 &&
          o.size.width > 0) {
        final vertical = o.direction == Axis.vertical;
        var wants = 0.0;
        var child = o.firstChild;
        while (child != null) {
          wants += vertical ? child.size.height : child.size.width;
          child = o.childAfter(child);
        }
        final got = vertical ? o.size.height : o.size.width;
        if (wants > got + 0.5) {
          out.add('${o.direction.name} wants ${wants.toStringAsFixed(0)} '
              'got ${got.toStringAsFixed(0)}');
        }
      }
      o.visitChildren(walk);
    }

    final root = tester.binding.rootElement?.renderObject;
    if (root != null) walk(root);
    return out;
  }

  testWidgets('the diagrams fit their boxes at both ends of the slider',
      (tester) async {
    // Unfreezing the text makes every fixed number the frozen one, and
    // both ends bite in opposite directions: above the default the type
    // outgrows a constant, and below it the type stops at a floor while a
    // purely proportional box keeps shrinking out from under it. Hence
    // the `math.max` on the alphabet cell, the ordinal column and the tag
    // strip, and the deletion of the chart's `barAreaHeight + 36`.
    for (final entry in diagrams) {
      for (final pt in <double>[12, 20, 40]) {
        await pumpEntry(tester, pt, entry.$1, entry.$2);
        expect(overflowing(tester), isEmpty,
            reason: 'the ${entry.$1} diagram overflows at $pt pt');
        expect(tester.takeException(), isNull,
            reason: 'the ${entry.$1} diagram threw at $pt pt');
      }
    }
  });

  // ---------------------------------------------------------------
  // What a reader who never moved the slider sees.
  // ---------------------------------------------------------------

  testWidgets('the default setting is unchanged, site by site',
      (tester) async {
    await pumpEntry(tester, 20, alphabet.$1, alphabet.$2);
    final m = declaredSizes(tester);
    expect(sizeOf(m, 'A Hebrew alphabet acrostic'), 19.0);
    expect(sizeOf(m, 'The longest chapter in the Bible'), 17.0);
    expect(sizeOf(m, 'Psalms 119'), 12.0);
    expect(sizeOf(m, 'א'), 18.0);
    // The one deliberate change: 8 px was three below the floor the rest
    // of the workbench holds its small print to, on a ticket whose
    // origin is a photograph and the words 「这些字很难看清楚」.
    expect(sizeOf(m, 'Aleph'), WbMetrics.smallPrintFloor);

    await pumpEntry(tester, 20, words.$1, words.$2);
    final g = declaredSizes(tester);
    expect(sizeOf(g, 'בְּרֵאשִׁית'), 16.0);
    expect(sizeOf(g, 'bereshit'), 12.0);
    expect(sizeOf(g, '1.'), 11.0);
  });
}
