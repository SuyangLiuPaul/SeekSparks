// 2026-08-25 (task #315): the Bible Evidence resource obeys the Font
// Size slider, and an artefact's own name stays above its description.
//
// #315 has been paid down seven times by finding new ways to WRITE a
// size the slider cannot move. This pass found the same defect in a
// shape one of those earlier passes explicitly ruled out. On 2026-08-24
// `sermon_detail_page.dart` was fixed for carrying "the only true
// inversion in the app", and that claim was measured with the LITERAL
// detector: a heading written as `fontSize: 22` above a body of
// `settings.fontSize` reverses rank once the body passes 22.
//
// A ceiling does exactly the same thing and was never checked for it.
// `evidence_detail_page.dart` sets its title to
// `(fs + 6).clamp(20.0, 32.0)` — the correct shape, wired to the
// setting, travelling for most of the slider — over a summary,
// description and correlation of a bare `fs`. It saturates at 32 when
// the reader reaches 26 pt, and the body walks past it:
//
//     20 pt  title 26  body 20   1.30x   the design
//     26 pt  title 32  body 26   1.23x   ceiling reached
//     32 pt  title 32  body 32   1.00x   equal
//     40 pt  title 32  body 40   0.80x   inverted
//
// Nine of the slider's 29 stops render the artefact's name at or below
// the size of the paragraph describing it. The floor distorts the other
// end for free: at 12 pt the title is pinned at 20, a ratio of 1.67
// where 1.30 was designed.
//
// So a "ceiling" and a "literal" are not two severities of the same
// bug. Both freeze; either can INVERT, and only a pumped page can see
// it, because the two sizes are written in different expressions and
// neither is wrong on its own.
//
// Measured, never asserted from source. The ratchet in
// `font_size_reach_ratchet_test.dart` can prove a size is not frozen;
// only this can prove two sizes still stand in the right order.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/bible_evidence.dart';
import 'package:seeksparks/pages/evidence_detail_page.dart';
import 'package:seeksparks/pages/evidence_page.dart';
import 'package:seeksparks/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A real-shaped record: the summary, description and correlation are
  // the three bodies the title has to stay above, and the academic
  // source is the line that carries the claim's authority.
  const evidence = BibleEvidence(
    id: 'test-detail',
    category: 'Manuscripts',
    bibleBooks: <String>['Isaiah'],
    timeline: '3rd Century BCE - 1st Century CE',
    discoveryDate: '1946-1956',
    location: 'Shrine of the Book, Jerusalem',
    scriptureReference: 'Isaiah 40:8',
    images: <String>[],
    academicSources: <String>['Tov, Textual Criticism of the Hebrew Bible'],
    confidenceLevel: 'Definitive',
    icon: 'x',
    title: <String, String>{'en': 'The Great Isaiah Scroll'},
    summary: <String, String>{'en': 'A summary of the find.'},
    description: <String, String>{'en': 'A description of the find.'},
    scripturalCorrelation: <String, String>{'en': 'How it meets the text.'},
  );

  /// Every painted size on the page, keyed by the string it painted.
  Future<Map<String, double>> sizesAt(WidgetTester tester, double fontSize)
      async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    // Tall enough that the ListView builds the correlation panel and the
    // academic sources at 40 pt. At 900 px they are below the fold and
    // `sizeOf` fails with "no painted text" — which looks like a missing
    // widget and is really a lazily-built one.
    tester.view.physicalSize = const Size(1280, 6000);
    addTearDown(tester.view.reset);

    final settings = AppSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: const MaterialApp(
          home: EvidenceDetailPage(evidence: evidence),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    settings.setFontSize(fontSize);
    // MaterialApp wraps its theme in an AnimatedTheme, so a single pump
    // reads the tree mid-lerp — the trap recorded in
    // `theme_font_size_behaviour_test.dart`.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    // Scoped to the ListView, not the whole tree. The `AppBar` prints
    // the artefact's title too, so a map keyed on the painted string
    // collapses the two and returns whichever came last — it reported
    // the hero title as 22 px, which is `titleLarge`, and would have
    // made the fix look like it had not landed.
    final out = <String, double>{};
    final body = find.descendant(
        of: find.byType(ListView), matching: find.byType(RichText));
    for (final w in tester.widgetList<RichText>(body)) {
      final label = w.text.toPlainText();
      final size = w.text.style?.fontSize;
      if (label.trim().isEmpty || size == null) continue;
      out[label] = size;
    }
    return out;
  }

  double sizeOf(Map<String, double> m, String needle) {
    for (final e in m.entries) {
      if (e.key.contains(needle)) return e.value;
    }
    fail('no painted text containing "$needle" — page rendered '
        '${m.keys.toList()}');
  }

  testWidgets('the artefact title never falls below its own description',
      (tester) async {
    // 33 is the first inverted stop and 32 the first equal one, so both
    // are named rather than relying on the endpoints to catch it.
    for (final pt in <double>[12, 20, 26, 32, 33, 40]) {
      final m = await sizesAt(tester, pt);
      final title = sizeOf(m, 'The Great Isaiah Scroll');
      for (final body in <String>[
        'A summary of the find.',
        'A description of the find.',
        'How it meets the text.',
      ]) {
        expect(title, greaterThan(sizeOf(m, body)),
            reason: 'at $pt pt the title is $title px over a "$body" of '
                '${sizeOf(m, body)} px — the name of the artefact is not '
                'allowed to shrink under the paragraph about it');
      }
    }
  });

  testWidgets('the title holds one ratio to the body at every stop',
      (tester) async {
    // A ceiling does not merely stop; it changes the proportion at
    // every stop on the way. The additive `fs + 6` never held a ratio
    // either — 1.5x at 12 pt, 1.15x at 40 — so the repair is a factor,
    // not a smaller offset.
    for (final pt in <double>[12, 20, 40]) {
      final m = await sizesAt(tester, pt);
      final ratio = sizeOf(m, 'The Great Isaiah Scroll') /
          sizeOf(m, 'A summary of the find.');
      expect(ratio, closeTo(1.3, 0.001),
          reason: 'at $pt pt the title/body ratio is $ratio');
    }
  });

  testWidgets('the default is untouched, and the top of the slider moves',
      (tester) async {
    final mid = await sizesAt(tester, 20);
    // A repair a reader who never moved the slider can SEE is a
    // redesign, and this is not one.
    expect(sizeOf(mid, 'The Great Isaiah Scroll'), 26.0);
    expect(sizeOf(mid, 'Tov, Textual Criticism'), 17.0);
    expect(sizeOf(mid, 'Shrine of the Book'), 15.0);

    final big = await sizesAt(tester, 40);
    expect(sizeOf(big, 'The Great Isaiah Scroll'), 52.0);
    // The academic source is the line that says WHY the reader should
    // believe the entry. It was frozen at 17 px from 19 pt upward.
    expect(sizeOf(big, 'Tov, Textual Criticism'), 34.0);
    expect(sizeOf(big, 'Shrine of the Book'), 30.0);
  });

  // ---------------------------------------------------------------
  // The archive grid the detail page is reached from.
  //
  // Its card is a FIXED 240 px tile, and all three of its sizes were
  // clamped — the title's ceiling of 18 was already reached AT the
  // default, so the card had stopped moving before the reader touched
  // anything. That is why the tile never overflowed and why the
  // comment on `mainAxisExtent` claiming "headroom for larger font
  // scales" survived: no larger scale ever arrived.
  //
  // Unfreezing the text makes the tile the frozen number, so it has to
  // be measured in the same pass. Both ends bite, in opposite ways:
  // above the default the text outgrows a fixed tile, and below it the
  // small-print floor holds the text still while a proportional tile
  // shrinks out from under it.
  // ---------------------------------------------------------------

  /// Pump the archive grid, which loads its 225 entries from a bundled
  /// asset — hence `runAsync`, since fake-async pumps never let the
  /// bundle read complete and the grid renders empty. An empty grid
  /// silently passes every assertion below, so the entry count is
  /// checked first.
  Future<void> pumpGrid(WidgetTester tester, double fontSize) async {
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
        child: const MaterialApp(home: EvidencePage()),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump(const Duration(milliseconds: 100));
    settings.setFontSize(fontSize);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(GridView), findsOneWidget);
  }

  /// Every vertical [RenderFlex] asking for more height than it was
  /// given, as a human-readable list.
  List<String> overflowingColumns(WidgetTester tester) {
    final out = <String>[];
    void walk(RenderObject o) {
      if (o is RenderFlex &&
          !o.debugNeedsLayout &&
          o.direction == Axis.vertical) {
        var wants = 0.0;
        var child = o.firstChild;
        while (child != null) {
          wants += child.size.height;
          child = o.childAfter(child);
        }
        if (wants > o.size.height + 0.5) {
          out.add('wants ${wants.toStringAsFixed(0)} '
              'got ${o.size.height.toStringAsFixed(0)}');
        }
      }
      o.visitChildren(walk);
    }

    final root = tester.binding.rootElement?.renderObject;
    if (root != null) walk(root);
    return out;
  }

  testWidgets('the archive card never outgrows its tile', (tester) async {
    for (final pt in <double>[12, 16, 20, 26, 32, 40]) {
      await pumpGrid(tester, pt);
      expect(overflowingColumns(tester), isEmpty,
          reason: 'at $pt pt the evidence card overflows its tile');
      expect(tester.takeException(), isNull,
          reason: 'at $pt pt the evidence grid threw while laying out');
    }
  });

  /// The size the first card painted its artefact's name at, and the
  /// largest size anything else in the grid was painted at.
  ///
  /// The title is found structurally rather than by string, because the
  /// grid's 225 entries come from a refreshable asset and naming one of
  /// them would tie this test to the corpus. In tree order the first
  /// `w700` run inside the grid is the card's title: the confidence
  /// badge beside it is `w600`, the summary under it carries no weight,
  /// and the scripture-reference row — also `w700` — is painted after.
  ///
  /// The rival arm skips [Icon]s, which are `RichText`s in the
  /// `MaterialIcons` family whose `fontSize` is the glyph's size. An
  /// unfiltered maximum reports the card's 32 px placeholder icon at
  /// every setting and never looks at text at all.
  (double, double) titleAndLoudestRival(WidgetTester tester) {
    var title = -1.0;
    var rival = 0.0;
    final inGrid = find.descendant(
        of: find.byType(GridView), matching: find.byType(RichText));
    for (final w in tester.widgetList<RichText>(inGrid)) {
      final style = w.text.style;
      if (style?.fontFamily == 'MaterialIcons') continue;
      final size = style?.fontSize;
      if (size == null) continue;
      if (title < 0 && style?.fontWeight == FontWeight.w700) {
        title = size;
      } else if (size > rival) {
        rival = size;
      }
    }
    if (title < 0) {
      fail('no bold run inside the grid — the archive asset probably did '
          'not load, and an empty grid passes every assertion here '
          'without measuring anything');
    }
    return (title, rival);
  }

  testWidgets('the archive card title moves with the slider', (tester) async {
    await pumpGrid(tester, 20);
    // Unchanged: 18 is what `(fontSize - 1).clamp(13, 18)` rendered at
    // the default, and also what it rendered at every stop above it.
    expect(titleAndLoudestRival(tester).$1, 18.0);

    await pumpGrid(tester, 40);
    expect(titleAndLoudestRival(tester).$1, 36.0,
        reason: 'the card title was frozen at 18 from the default upward');

    await pumpGrid(tester, 12);
    // The small-print floor, not the scale: 18 × 0.6 is 10.8, which
    // would sit below the 11 px its own summary is held at.
    expect(titleAndLoudestRival(tester).$1, WbMetrics.smallPrintFloor);
  });

  testWidgets('nothing on the card shouts louder than the artefact',
      (tester) async {
    // The second inversion in this card, and it did not come from a
    // clamp of its own. `ConfidenceBadge` was repaired in an earlier
    // #315 pass and now runs to 32 px at the top of the slider; the
    // title beside it was still frozen at 18. A reader at 40 pt saw the
    // word "Definitive" at DOUBLE the size of the name of the artefact
    // it was describing.
    //
    // So a repair can create an inversion in a neighbour it never
    // touched, and a per-site ratchet cannot see it — only a rank
    // measured across the whole card can.
    for (final pt in <double>[12, 20, 40]) {
      await pumpGrid(tester, pt);
      final (title, rival) = titleAndLoudestRival(tester);
      expect(title, greaterThanOrEqualTo(rival),
          reason: 'at $pt pt the card paints its title at $title px and '
              'something else at $rival px');
    }
  });
}
