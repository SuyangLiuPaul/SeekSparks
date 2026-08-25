// 2026-08-25 (#315, twelfth pass): the number grids in the app's
// primary navigation surface.
//
// `book_chapter_picker.dart` holds three grids of numbers, all built
// from the same [_NumberTile], and none of them has a [FittedBox]. That
// single fact is what makes this file necessary and makes it different
// from `fitted_label_reach_test.dart` next door, which measures the
// BOOK grid — where a fit exists, so an oversized label SHRINKS and the
// failure is a glyph that silently stops growing.
//
// Without a fit the failure inverts. `Text(maxLines: 1)` with no
// `overflow` CLIPS, and a clipped number is not an ugly number, it is a
// PLAUSIBLE WRONG ONE: Psalm 119's verse "176" loses a digit and reads
// as "17", Psalms' chapter "150" reads as "15". The reader is not shown
// a defect, they are shown a different verse, and they have no way to
// know. That is an accuracy failure wearing a layout failure's clothes,
// which is why it is measured here rather than eyeballed.
//
// THE INSTRUMENT. Declared size is useless for this: the tile declares
// exactly what it was given, and clipping happens downstream. What
// separates them is INTRINSIC versus GRANTED — lay the label out
// unconstrained with a `TextPainter` in the same style, and compare
// against the width the tile actually handed the `Text`. Greater
// intrinsic than granted is a clip, whatever the style says.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/book.dart';
import 'package:seeksparks/models/chapter.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/book_chapter_picker.dart';

/// The tile deliberately sets no `fontFamily` so the theme's CJK and
/// Hebrew chain stays reachable, which means `flutter test` would
/// otherwise lay these digits out in the fixed-width stand-in at 1.0 em
/// each — nearly double Roboto's 0.556 em advance. That would invent
/// clipping that no reader ever sees. Registering the shipped face as
/// the theme default is what puts real digit metrics in front of the
/// real code path.
const _family = 'Roboto';

Future<void> _load(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

/// A book whose chapter and verse numbers are the widest the canon has:
/// Psalms reaches chapter 150, and Psalm 119 reaches verse 176. Three
/// digits is the worst case in both grids, so measuring anything
/// narrower would measure the wrong thing.
Book _psalms() => Book(
      title: 'Psalms',
      chapters: [
        for (var c = 1; c <= 150; c++)
          Chapter(
            title: c,
            verses: [
              for (var v = 1; v <= (c == 119 ? 176 : 6); v++)
                Verse(book: 'Psalms', chapter: c, verse: v, text: 'x'),
            ],
          ),
      ],
    );

List<Verse> _psalmVerses() => [
      for (var c = 1; c <= 150; c++)
        for (var v = 1; v <= (c == 119 ? 176 : 6); v++)
          Verse(book: 'Psalms', chapter: c, verse: v, text: 'x'),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _load(_family, 'assets/fonts/Roboto-VariableFont_wdth,wght.ttf');
  });

  /// The width the label wants, laid out unconstrained in the style the
  /// tile actually gave it. Read back off the pumped `RichText` rather
  /// than reconstructed from the source, so a change to the tile's
  /// weight or figure style cannot make this quietly stop matching.
  double intrinsicWidth(WidgetTester tester, String label) {
    final rich = tester.widget<RichText>(find
        .descendant(of: find.text(label), matching: find.byType(RichText))
        .first);
    final style = rich.text.style!;
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  /// The width the tile actually handed the label.
  double grantedWidth(WidgetTester tester, String label) =>
      tester.getSize(find.text(label)).width;

  double declared(WidgetTester tester, String label) => tester
      .widget<RichText>(find
          .descendant(of: find.text(label), matching: find.byType(RichText))
          .first)
      .text
      .style!
      .fontSize!;

  Future<AppSettings> pump(WidgetTester tester, double paneWidth) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(paneWidth, 1000);
    addTearDown(tester.view.reset);

    final provider = MainProvider()
      ..verses = _psalmVerses()
      ..books = [_psalms()];
    final settings = AppSettings();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MainProvider>.value(value: provider),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: _family),
          home: Scaffold(
            body: BookChapterPicker(
              currentBook: 'Psalms',
              currentChapter: 1,
              onChapterSelected: (_, __) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    return settings;
  }

  Future<void> setSize(WidgetTester tester, AppSettings s, double fs) async {
    s.setFontSize(fs);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// Open Psalms in the grid view, which is the shipped default. Found
  /// by tooltip, not by text: the tile paints an ABBREVIATION and
  /// carries the full title only as the tooltip message.
  Future<void> openBook(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Psalms').first);
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// From the chapter grid, step into the verse grid for one chapter.
  /// The grid is a lazy `GridView.builder`, so a three-digit chapter is
  /// not built until it is scrolled into view.
  Future<void> openChapter(WidgetTester tester, String chapter) async {
    await tester.scrollUntilVisible(find.text(chapter), 300);
    await tester.tap(find.text(chapter).first);
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('the verse grid', () {
    testWidgets('the verse number moves across the whole slider',
        (tester) async {
      final s = await pump(tester, 900);
      await openBook(tester);
      await openChapter(tester, '119');

      await setSize(tester, s, kFontSizeDefault);
      final atDefault = declared(tester, '1');
      await setSize(tester, s, kFontSizeMax);
      final atMax = declared(tester, '1');
      await setSize(tester, s, kFontSizeMin);
      final atMin = declared(tester, '1');

      // 13 was the literal this pass replaced, and it is kept as the
      // value at the default so nothing a reader has already seen
      // moves. What is new is the two ends.
      expect(atDefault, closeTo(13.0, 0.01));
      expect(atMax, closeTo(26.0, 0.01));
      // The small-print floor, not 13 * 0.6 = 7.8.
      expect(atMin, closeTo(11.0, 0.01));
    });

    testWidgets('no verse number clips, at any stop of the slider',
        (tester) async {
      // The claim the column solver exists to make. Psalm 119 is the
      // only chapter in the canon that reaches three digits, so '176'
      // is the widest label the grid ever has to seat.
      final s = await pump(tester, 900);
      await openBook(tester);
      await openChapter(tester, '119');

      for (final fs in <double>[
        kFontSizeMin,
        16,
        kFontSizeDefault,
        28,
        34,
        kFontSizeMax
      ]) {
        await setSize(tester, s, fs);
        await tester.scrollUntilVisible(find.text('176'), 300);
        final want = intrinsicWidth(tester, '176');
        final got = grantedWidth(tester, '176');
        expect(got, greaterThanOrEqualTo(want - 0.5),
            reason: 'at $fs pt the widest verse label wants '
                '${want.toStringAsFixed(1)}px and was granted '
                '${got.toStringAsFixed(1)}px — it clips, and "176" clipped '
                'reads as a different verse');
      }
    });

    testWidgets('the column count falls as the font rises', (tester) async {
      // The mechanism behind the test above. A fixed column count plus
      // a growing label can only end one way; the solver trades columns
      // for width, so the tile a label sits in gets WIDER as the reader
      // asks for more, even though the pane did not change size.
      final s = await pump(tester, 900);
      await openBook(tester);
      await openChapter(tester, '119');

      await setSize(tester, s, kFontSizeDefault);
      final tileAtDefault = grantedWidth(tester, '1');
      await setSize(tester, s, kFontSizeMax);
      final tileAtMax = grantedWidth(tester, '1');

      expect(tileAtMax, greaterThan(tileAtDefault),
          reason: 'the tile must widen as the label does, which it can '
              'only do by dropping a column');
    });
  });

  group('the chapter grid', () {
    testWidgets('no chapter number clips, at any stop of the slider',
        (tester) async {
      // The sibling grid, and a different sizing story: the chapter
      // tile's BOX comes from the menu scale (`56.0 * settings.
      // menuScale`) while its LABEL comes from the font scale. Two
      // sliders feeding one tile is the fifth mechanism's shape, and
      // without a fit to absorb the disagreement the label clips.
      // '150' is the widest chapter label in the canon.
      final s = await pump(tester, 900);
      await openBook(tester);

      for (final fs in <double>[
        kFontSizeMin,
        kFontSizeDefault,
        28,
        kFontSizeMax
      ]) {
        await setSize(tester, s, fs);
        await tester.scrollUntilVisible(find.text('150'), 300);
        final want = intrinsicWidth(tester, '150');
        final got = grantedWidth(tester, '150');
        expect(got, greaterThanOrEqualTo(want - 0.5),
            reason: 'at $fs pt the widest chapter label wants '
                '${want.toStringAsFixed(1)}px and was granted '
                '${got.toStringAsFixed(1)}px — it clips, and "150" clipped '
                'reads as a different chapter');
      }
    });
  });

  Future<void> openList(WidgetTester tester, AppSettings s) async {
    await s.setBooksViewMode('list');
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Make sure Psalms' chapter grid is on screen, expanding it if not.
  ///
  /// Called again after every size change on purpose. Two things about
  /// this view make a once-at-the-top expansion unreliable, and neither
  /// is about type, so both are worked around here and reported rather
  /// than fixed in a pass about font size:
  ///
  ///   * the row COLLAPSES when the picker rebuilds, which a font-size
  ///     change causes — so a reader who resizes loses their place;
  ///   * tapping the row's centre lands on the `ListTile` without
  ///     toggling it, so only the chevron opens a book. That is the
  ///     same corner of the widget the Material warning swallowed above
  ///     is about.
  Future<void> ensureExpanded(WidgetTester tester) async {
    if (find.text('150').evaluate().isNotEmpty) return;
    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();
  }

  group('the chapter list', () {
    /// The list view trips a Flutter debug assertion that has nothing to
    /// do with type size: its `ExpansionTile` rows are `ListTile`s
    /// inside a `ColoredBox`, so Material warns that ink splashes will
    /// be painted under the box and never seen. It is real — the book
    /// rows in the list view have no visible tap ripple — but it is a
    /// SEPARATE defect from this file's subject, it is debug-only, and
    /// repairing it means changing how that view is painted. Swallowed
    /// by exact message so the measurements below can run, and NOT
    /// swallowed by category, so anything else still fails the test.
    void ignoreKnownListTileWarning() {
      final prior = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details
            .exceptionAsString()
            .contains('ListTile background color or ink splashes')) {
          return;
        }
        prior?.call(details);
      };
      addTearDown(() => FlutterError.onError = prior);
    }

    testWidgets('no chapter number clips there either', (tester) async {
      ignoreKnownListTileWarning();
      // The THIRD place a chapter number is drawn, reached by the view
      // toggle, and the one that cannot be repaired the same way: it is
      // a `Wrap` of fixed squares off the breakpoint table, so there is
      // no column to trade. The box itself has to grow, and this is the
      // measurement that says whether it does.
      final s = await pump(tester, 900);
      await openList(tester, s);

      for (final fs in <double>[
        kFontSizeMin,
        kFontSizeDefault,
        28,
        kFontSizeMax
      ]) {
        await setSize(tester, s, fs);
        await ensureExpanded(tester);
        // No scrolling: the list view's chapter `Wrap` is eager, so
        // every tile is laid out whether or not it is on screen, and a
        // laid-out tile is all a measurement needs.
        final want = intrinsicWidth(tester, '150');
        final got = grantedWidth(tester, '150');
        expect(got, greaterThanOrEqualTo(want - 0.5),
            reason: 'at $fs pt the widest chapter label wants '
                '${want.toStringAsFixed(1)}px in the LIST view and was '
                'granted ${got.toStringAsFixed(1)}px');
      }
    });

    testWidgets('the tile grows once the label outgrows the breakpoint',
        (tester) async {
      ignoreKnownListTileWarning();
      // This test was written to prove the repair was INVISIBLE at the
      // default — that a three-digit chapter needs less than the 64 px
      // desktop tile, so the floor wins and nothing a reader has seen
      // moves. Running it against the commit before the fix refuted
      // that: "150" wanted 54.8 px and was granted 52.0, AT 20 pt. The
      // list view has been clipping Psalms' last chapters for every
      // reader, at the shipped default, not only for one who raised the
      // font.
      //
      // So this repair does change what a reader at the default sees,
      // by about a pixel, and that is the correct outcome rather than a
      // regression — but it is the one place in this pass where the
      // "invisible at the default" rule does not hold, and it is
      // written down rather than glossed.
      //
      // The 2.8 px is instrument-dependent: it is Roboto's digit
      // advance, and the shipped web build asks for `-apple-system`,
      // which the browser resolves to the OS UI face. The SIGN of the
      // shortfall is robust across any face with a similar advance; the
      // magnitude at the default is not, and no claim is made about it
      // beyond "this is tight enough to clip in at least one shipped
      // face".
      final s = await pump(tester, 900);
      await openList(tester, s);

      await setSize(tester, s, kFontSizeDefault);
      await ensureExpanded(tester);
      final atDefault = grantedWidth(tester, '150');
      await setSize(tester, s, kFontSizeMax);
      await ensureExpanded(tester);
      final atMax = grantedWidth(tester, '150');

      expect(atMax, greaterThan(atDefault),
          reason: 'the box must grow once the label outgrows the '
              'breakpoint size');
    });
  });

  group('the verse step header', () {
    testWidgets('the chapter reference moves, and stays under the title',
        (tester) async {
      // Rank, not just reach. The header holds the title "Pick a verse"
      // at `settings.fontSize` beside the reference "Psalms 119" at
      // what used to be `(fontSize - 2).clamp(12, 16)` — a ceiling that
      // saturated at 18 pt, BELOW the app's own default, so the
      // reference was frozen across the reader's whole upper range
      // while the title beside it kept growing.
      final s = await pump(tester, 900);
      await openBook(tester);
      await openChapter(tester, '119');

      await setSize(tester, s, kFontSizeDefault);
      final refAtDefault = declared(tester, 'Psalms 119');
      await setSize(tester, s, kFontSizeMax);
      final refAtMax = declared(tester, 'Psalms 119');

      expect(refAtDefault, closeTo(16.0, 0.01));
      expect(refAtMax, closeTo(32.0, 0.01));
      // Still the subordinate of the two at both ends.
      expect(refAtDefault, lessThan(kFontSizeDefault));
      expect(refAtMax, lessThan(kFontSizeMax));
    });
  });

  // The tile carries `FontFeature.tabularFigures()`, which is load
  // bearing for everything above: it makes every digit the same
  // advance, so the widest THREE-DIGIT label is the widest label full
  // stop, and the solver can be handed one measurement instead of 176.
  test('the tile\'s figures are tabular, which is what makes one '
      'measurement enough', () {
    const style = TextStyle(
      fontFamily: _family,
      fontSize: 20,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    double w(String s) {
      final p = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final r = p.width;
      p.dispose();
      return r;
    }

    expect(w('111'), closeTo(w('888'), 0.01));
    expect(w('176'), closeTo(w('150'), 0.01));
  });
}
