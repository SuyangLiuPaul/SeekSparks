// The reference column, measured against the faces the app actually
// ships rather than against the model that sizes it.
//
// Every other test of `referenceGutterWidth` compares the character
// model to itself: it asserts that a longer name asks for a wider
// column, that the width follows the slider, that the gap is a
// constant. All of that can be true while the model is simply wrong
// about the font — and the model is the only thing standing between a
// reader and the ragged column reported on 2026-08-17 (#322,
// 「不要不协调，要 harmony」).
//
// So this file loads `Roboto-VariableFont` and `NotoSansSC-Sub` out of
// `assets/fonts/` and lays the references out for real. `flutter test`
// otherwise renders every glyph in a fixed-width stand-in face, which
// would make a width test pass while proving nothing — the controls
// below exist to catch exactly that.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/book_name_mapping.dart'
    show BookScript, bookNameInScript;
import 'package:seeksparks/constants/book_names.dart' show standardBookOrder;
import 'package:seeksparks/constants/workbench_theme.dart' show workbenchTheme;
import 'package:seeksparks/widgets/browse_window.dart'
    show kBrowseReferenceLetterSpacing;
import 'package:seeksparks/utils/version_gutter.dart'
    show referenceGutterWidth;

/// The reference is painted in Roboto for its Latin and NotoSansSC-Sub
/// for its Han: `t.fontFamily` is null for the default "system" option,
/// and on web CanvasKit can resolve nothing else — the other two picker
/// entries (`PingFang SC`, `SimSun`) are OS faces it has no access to.
/// Pinning the family here is what makes the loaded face get used;
/// with a null family `flutter_test` resolves to its own stand-in and
/// never consults the fallback chain.
const _family = 'Roboto';
const _fallback = ['NotoSansSC-Sub'];

Future<void> _load(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

double _paintedWidth(String s, double size, {double? letterSpacing}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: letterSpacing,
        fontFamily: _family,
        fontFamilyFallback: _fallback,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return tp.width;
}

/// Every reference a reader can reach: one book name per script, and
/// the verse-number forms that bracket the real range (`1:1` through
/// Psalm 119's `119:176`).
Iterable<String> _allReferences() sync* {
  for (final script in BookScript.values) {
    for (final en in standardBookOrder) {
      final name = bookNameInScript(en, script);
      for (final n in ['1:1', '9:9', '12:34', '5:28', '119:176']) {
        yield '$name $n';
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _load(_family, 'assets/fonts/Roboto-VariableFont_wdth,wght.ttf');
    await _load('NotoSansSC-Sub', 'assets/fonts/NotoSansSC-Sub.otf');
  });

  group('the instrument', () {
    test('is a real proportional face, not the fixed-width stand-in', () {
      // If this fails, every width assertion below is meaningless: the
      // stand-in charges one em to `i` and to `m` alike, so a model that
      // was wildly wrong would still "fit".
      final narrow = _paintedWidth('iiiiiiiiii', 100);
      final wide = _paintedWidth('mmmmmmmmmm', 100);
      expect(wide, greaterThan(narrow * 2),
          reason: 'font did not load — measurements would be fiction');
    });

    test('honours the variable weight axis the reference is set in', () {
      // The model is calibrated at wght=600. If the axis were ignored
      // the harness would be measuring the 400 master, which is
      // narrower, and would report margins the shipped app never has.
      const s = 'Song of Solomon 8:14';
      final w400 = TextPainter(
        text: TextSpan(
            text: s,
            style: const TextStyle(
                fontSize: 100,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                fontFamily: _family,
                fontFamilyFallback: _fallback)),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(_paintedWidth(s, 100, letterSpacing: 0),
          greaterThan(w400.width),
          reason: 'wght axis not applied; the 600 master is wider');
    });

    test('a Han glyph really is the one em the model charges it', () {
      // The model charges full-width runes exactly 1.0 em with no
      // margin at all, unlike Latin which it deliberately rounds up.
      // That is only safe while the face agrees.
      for (final s in ['歷', '歷代志下', '帖撒羅尼迦前書']) {
        expect(_paintedWidth(s, 100, letterSpacing: 0) / 100,
            closeTo(s.runes.length.toDouble(), 0.01));
      }
    });
  });

  group('the column is straight', () {
    // The property that matters. `BrowseVerseRow` gives the reference a
    // `ConstrainedBox(minWidth: referenceWidth)`, so every row in the
    // chapter starts its verse text at the same x *provided* no
    // reference paints wider than the width computed for it. One that
    // does pushes its own row out and nothing else — which is the
    // ragged column a reader sees.
    test('no reachable reference outgrows the width computed for it', () {
      final failures = <String>[];
      var checked = 0;
      for (final size in [10.0, 13.0, 15.0, 20.0, 28.0]) {
        for (final ref in _allReferences()) {
          checked++;
          final granted = referenceGutterWidth(
            [ref],
            size,
            letterSpacing: kBrowseReferenceLetterSpacing,
          );
          final painted =
              _paintedWidth(ref, size, letterSpacing: kBrowseReferenceLetterSpacing);
          if (painted > granted) {
            failures.add('$ref @$size: painted $painted > granted $granted');
          }
        }
      }
      // 66 books × 3 scripts × 5 verse forms × 5 sizes. Stated so a
      // silently-empty generator cannot pass this as a clean sweep.
      expect(checked, 4950);
      expect(failures, isEmpty,
          reason: '${failures.length} of $checked references overflow');
    });

    test('the model alone covers the text, before the gap is spent', () {
      // Stricter, and the one that actually failed before this change.
      // The gap exists to separate the reference from the verse, not to
      // absorb the model's error. Until 2026-08-24 the model ignored
      // the 0.25 letterSpacing the reference inherits, and the only
      // reason nothing looked broken was that the 8px gap was bigger
      // than the shortfall.
      final failures = <String>[];
      for (final size in [10.0, 15.0, 28.0]) {
        for (final ref in _allReferences()) {
          // The production function with its gap spent to nothing, so
          // what is left is the model's own claim about the text.
          final modelText = referenceGutterWidth(
            [ref],
            size,
            letterSpacing: kBrowseReferenceLetterSpacing,
            gap: 0,
          );
          final painted = _paintedWidth(ref, size,
              letterSpacing: kBrowseReferenceLetterSpacing);
          if (painted > modelText) {
            failures.add('$ref @$size: painted $painted > model $modelText');
          }
        }
      }
      expect(failures, isEmpty,
          reason: '${failures.length} references exceed the model itself');
    });
  });

  group('the painted style and the measured model are the same number', () {
    testWidgets('the reference inherits exactly the tracking it is sized with',
        (tester) async {
      // The defect this guards is not arithmetic, it is a merge. A
      // `Text` folds its style onto the ambient `DefaultTextStyle`, and
      // under a `Scaffold` that is `bodyMedium` — which carries 0.25.
      // If a future theme changes that number and the reference style
      // stops stating its own, the column silently goes back to being
      // measured with one value and painted with another.
      late TextStyle ambient;
      await tester.pumpWidget(MaterialApp(
        theme: workbenchTheme(ThemeData.light()),
        home: Scaffold(
          body: Builder(builder: (context) {
            ambient = DefaultTextStyle.of(context).style;
            return const SizedBox();
          }),
        ),
      ));
      // Stating it explicitly is what makes the merge irrelevant: this
      // is the value that survives whatever the ambient style says.
      final merged = ambient.merge(
          const TextStyle(letterSpacing: kBrowseReferenceLetterSpacing));
      expect(merged.letterSpacing, kBrowseReferenceLetterSpacing);
    });
  });
}
