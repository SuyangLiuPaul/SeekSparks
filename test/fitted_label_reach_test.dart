// 2026-08-24 (#315, fifth mechanism): the box that did not scale.
//
// The four mechanisms already policed are all ways of writing a NUMBER
// the Font Size slider cannot move — a literal, a deaf Material role, a
// saturating clamp, a theme built from constants. This one is none of
// them. `book_chapter_picker.dart` wrote
//
//     fontSize: settings.fontSize * 1.15
//
// which is the *correct* shape, passes every source ratchet, and moves
// with the reader at every stop. The glyph still did not grow, because
// the text sits in a `FittedBox` inside a grid cell whose width came
// from the MENU scale. `fontSize` then set a ceiling the fit never
// reached, and the painted size was `cellWidth / labelEmWidth` — a
// constant, whatever the reader chose.
//
// A sixth thing turned up while measuring, in the same widget and with
// the same shape: `StrutStyle(height: 1.0, forceStrutHeight: true)`
// carried no `fontSize`, and an unset strut `fontSize` is 14 — it is
// NOT inherited from the text. `forceStrutHeight` then pinned the line
// box to 14 px at every setting while the glyph grew past it, so the
// baseline was placed by a 14 px box and a 46 pt letter sat well above
// the centre of its tile.
//
// THE INSTRUMENT IS THE POINT. `settings_font_size_behaviour_test.dart`
// and its siblings read `RichText.text.style.fontSize`, which is the
// DECLARED size; under a `FittedBox` that number is correct and the
// pixels are not, so those tests would pass on this bug forever. Only
// the painted rect can tell the two apart — `tester.getRect` resolves
// through `localToGlobal`, and so through the fit's transform, where
// `tester.getSize` returns the untransformed render size and agrees
// with the lie. The rect's HEIGHT is what catches the strut.
//
// Both halves are measured here: the arithmetic, in the shipped faces,
// and the widget, pumped across the real slider.

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
import 'package:seeksparks/utils/fitted_label_metrics.dart';
import 'package:seeksparks/widgets/book_chapter_picker.dart';

/// The faces the app actually ships. `flutter test` otherwise lays text
/// out in a fixed-width stand-in where every glyph is 1.0 em, which
/// would make Latin and Han indistinguishable — and half the finding
/// below is that they are not. Same approach as
/// `browse_reference_real_font_test.dart`.
const _family = 'Roboto';
const _fallback = ['NotoSansSC-Sub'];

/// The tile asks for `settings.fontFamily`, whose shipped value on web
/// is the CSS token `-apple-system` (see `resolveFontFamily`). A
/// browser resolves it to the OS UI face; `flutter test` resolves any
/// unregistered name to the stand-in and never walks
/// `fontFamilyFallback` at all, because the stand-in has every glyph.
/// Registering Roboto UNDER that token is what puts real metrics in
/// front of the shipped code path instead of a widget assembled for the
/// test. Without this the widget group below measures 1.0 em per glyph
/// and proves nothing about either script.
const _shipped = '-apple-system';

Future<void> _load(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

List<Verse> _verses(List<String> books) => [
      for (final b in books) Verse(book: b, chapter: 1, verse: 1, text: 'x'),
    ];

List<Book> _books(List<String> names) => [
      for (final b in names)
        Book(title: b, chapters: [
          Chapter(title: 1, verses: [Verse(book: b, chapter: 1, verse: 1, text: 'x')]),
        ]),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const roboto = 'assets/fonts/Roboto-VariableFont_wdth,wght.ttf';
    await _load(_family, roboto);
    await _load(_shipped, roboto);
    await _load('NotoSansSC-Sub', 'assets/fonts/NotoSansSC-Sub.otf');
  });

  group('the metric itself', () {
    test('a Han character is one em and Latin is not', () {
      // This asymmetry is why the widest label has to be measured per
      // script rather than assumed. It also refutes the guess this
      // iteration started from: Chinese looked like the crowded case
      // and Latin is in fact far wider, because five letters beat two
      // ideographs — and the shipped Chinese abbreviations are ONE
      // ideograph, so the gap is wider still.
      final han = labelEmWidth('林前',
          fontFamily: _family,
          fontFamilyFallback: _fallback,
          fontWeight: FontWeight.w700);
      final latin = labelEmWidth('Jonah',
          fontFamily: _family,
          fontFamilyFallback: _fallback,
          fontWeight: FontWeight.w700);
      expect(han, closeTo(2.0, 0.01));
      expect(latin, greaterThan(han));
      expect(latin, closeTo(2.78, 0.05));
    });

    test('it is scale-invariant, which is what makes caching honest', () {
      // The cache stores one number per label and reuses it at every
      // font size. That is only sound because an em width does not
      // depend on the size it was measured at.
      final a = labelEmWidth('Gen', fontFamily: _family);
      final b = labelEmWidth('Gen', fontFamily: _family);
      expect(identical(a, b) || a == b, isTrue);

      final painter = TextPainter(
        text: TextSpan(
          text: 'Gen',
          style: const TextStyle(
              fontSize: 37, letterSpacing: 0, height: 1.0, fontFamily: _family),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(painter.width / 37, closeTo(a, 0.02));
      painter.dispose();
    });

    test('columnsThatFit never returns a column narrower than the label', () {
      const em = 2.78;
      for (final width in <double>[280, 400, 560, 800, 1200]) {
        for (final fontSize in <double>[12, 20, 28, 40]) {
          final n = columnsThatFit(
            available: width,
            widestEm: em,
            fontSize: fontSize * kBookTileFontRatio,
            outerPadding: 24,
            spacing: 8,
            perColumnPadding: kBookTilePadding * 2,
            min: 1,
            max: 10,
          );
          if (n <= 1) continue; // the floor, where nothing is promised
          final tile = (width - 24 - 8 * (n - 1)) / n;
          final inner = tile - kBookTilePadding * 2;
          expect(inner, greaterThanOrEqualTo(em * fontSize * kBookTileFontRatio),
              reason: 'at ${width}px / ${fontSize}pt the solver chose $n '
                  'columns, leaving ${inner.toStringAsFixed(1)}px for a label '
                  'that wants ${(em * fontSize * kBookTileFontRatio).toStringAsFixed(1)}px');
        }
      }
    });
  });

  group('the book grid', () {
    /// The painted rect, which passes through the `FittedBox`'s
    /// transform. `getSize` would return the pre-transform size and
    /// report this bug as fixed while it was live.
    Rect painted(WidgetTester tester, String label) =>
        tester.getRect(find.text(label));

    double declared(WidgetTester tester, String label) => tester
        .widget<RichText>(find
            .descendant(of: find.text(label), matching: find.byType(RichText))
            .first)
        .text
        .style!
        .fontSize!;

    int columns(WidgetTester tester) =>
        (tester.widget<GridView>(find.byType(GridView).first).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount;

    Future<AppSettings> pump(WidgetTester tester, double paneWidth,
        List<String> books) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(paneWidth, 900);
      addTearDown(tester.view.reset);

      final provider = MainProvider()
        ..verses = _verses(books)
        ..books = _books(books);
      final settings = AppSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MainProvider>.value(value: provider),
            ChangeNotifierProvider<AppSettings>.value(value: settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BookChapterPicker(
                currentBook: books.first,
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

    Future<void> settle(WidgetTester tester, AppSettings s, double fs) async {
      s.setFontSize(fs);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('the label grows with the slider in the 280px sidebar',
        (tester) async {
      // The reader sidebar is `ResponsiveBreakpoints.sidebarWidth` =
      // 280. Before the fix the column count was pinned at a minimum of
      // FOUR whatever the font, which left 44px of tile: `Jonah` froze
      // at 13.8 pt and stayed 15.8 px for the whole upper two thirds of
      // the slider.
      final s = await pump(tester, 280, ['Jonah', 'Genesis', 'Exodus']);

      await settle(tester, s, 20);
      final small = painted(tester, 'Jonah').width;
      await settle(tester, s, 40);
      final large = painted(tester, 'Jonah').width;

      expect(large, greaterThan(small * 1.5),
          reason: 'doubling the font size must roughly double the painted '
              'glyph. small=$small large=$large');
    });

    testWidgets('the painted size tracks the declared one', (tester) async {
      // The tightest statement of both mechanisms. The WIDTH catches
      // the fit eating the reader's choice; the HEIGHT catches the
      // strut, which pinned the line box to 14 px and so reported the
      // same number at 12 pt and at 40 pt.
      final s = await pump(tester, 800, ['Jonah', 'Genesis']);
      for (final fs in <double>[12, 20, 28, 40]) {
        await settle(tester, s, fs);
        final d = declared(tester, 'Jonah');
        final p = painted(tester, 'Jonah');
        expect(p.height / d, greaterThan(0.9),
            reason: 'at $fs pt the line box is ${p.height} for a $d pt glyph');
        expect(p.width / (d * 2.78), greaterThan(0.9),
            reason: 'at $fs pt the tile shrank the label to '
                '${p.width / (d * 2.78)} of the size the reader asked for');
      }
    });

    testWidgets('a Chinese grid is not sized by the Latin worst case',
        (tester) async {
      // The widest label is measured from the books actually on screen,
      // so a one-ideograph list keeps more columns than a five-letter
      // one at the same width and size. A global constant would have
      // charged every script for `Jonah`.
      await pump(tester, 800, ['马太福音', '马可福音', '路加福音'])
          .then((s) => settle(tester, s, 28));
      final zh = columns(tester);

      await pump(tester, 800, ['Jonah', 'Genesis', 'Exodus'])
          .then((s) => settle(tester, s, 28));
      final en = columns(tester);

      expect(zh, greaterThan(en),
          reason: 'Chinese abbreviations are one ideograph and Latin ones up '
              'to 2.78 em, so at the same width the Chinese grid should fit '
              'more columns. zh=$zh en=$en');
    });

    testWidgets('the default layout is unchanged for a Chinese reader',
        (tester) async {
      // A repair a reader can see is a redesign, and this is not one.
      // Both surfaces the picker is hosted on keep the column count they
      // had: 10 in the 800px `books_page`, and 4 in the 280px sidebar —
      // the latter is why the floor is capped by the label rather than
      // simply lowered, since a single ideograph fits four columns
      // comfortably and lowering the floor would have thinned the
      // sidebar for no gain in glyph size.
      final wide = await pump(tester, 800, ['马太福音', '马可福音']);
      await settle(tester, wide, 20);
      expect(columns(tester), 10);

      final narrow = await pump(tester, 280, ['马太福音', '马可福音']);
      await settle(tester, narrow, 20);
      expect(columns(tester), 4);
    });
  });
}
