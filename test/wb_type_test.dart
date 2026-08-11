import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart'
    show kFontSizeMax, kFontSizeMin, kMenuScaleMax, kMenuScaleMin;

/// The workbench used to hardcode every size, so Settings drove nothing
/// there. These pin the mapping: a setting must MOVE the workbench, and
/// must not move it so far the three-pane layout stops working.
void main() {
  WbType at({double font = 20, double line = 1.5, double menu = 1.0}) =>
      WbType.resolve(fontSize: font, lineSpacing: line, menuScale: menu);

  test('app defaults reproduce the original constants exactly', () {
    final t = at();
    expect(t.text, WbMetrics.text);
    expect(t.chrome, WbMetrics.chrome);
    expect(t.original, WbMetrics.original);
    expect(t.lineHeight, closeTo(WbMetrics.lineHeight, 1e-9));
  });

  test('Font Size moves body and original text', () {
    expect(at(font: 30).text, greaterThan(at(font: 20).text));
    expect(at(font: 30).original, greaterThan(at(font: 20).original));
  });

  // 2026-08-11 (#315). Until now `original` scaled all the way down with
  // Font Size, and 12 pt gave it 9 px. Pointed Hebrew and accented Greek
  // are not Latin: at 9 px a qamats and a patach are the same grey mark,
  // and tsere's two dots and segol's three are uncountable — so the app
  // was stating a different word than the text has, silently. Density is
  // a legitimate request; an unreadable diacritic is not what it asks
  // for.
  group('the originals floor', () {
    test('it holds at every stop the Font Size slider offers', () {
      for (double f = kFontSizeMin; f <= kFontSizeMax; f += 1) {
        expect(
            at(font: f).original, greaterThanOrEqualTo(WbMetrics.originalFloor),
            reason: 'pointed Hebrew fell to ${at(font: f).original} px '
                'at $f pt');
      }
    });

    test('it does not cap the reader who wants BIGGER originals', () {
      expect(
          at(font: kFontSizeMax).original, greaterThan(at(font: 20).original));
      expect(at(font: 20).original, WbMetrics.original);
    });

    test('it is above the Latin size at the same setting, not below', () {
      // The whole point is that the two scripts need different floors.
      for (double f = kFontSizeMin; f <= kFontSizeMax; f += 1) {
        expect(at(font: f).original, greaterThan(at(font: f).text),
            reason: 'originals lost their boost at $f pt');
      }
    });

    test('scaledOriginal floors a call site the same way', () {
      final dense = at(font: kFontSizeMin);
      expect(dense.scaledOriginal(17),
          greaterThanOrEqualTo(WbMetrics.originalFloor));
      expect(at(font: kFontSizeMax).scaledOriginal(17),
          closeTo(17 * kFontSizeMax / 20, 1e-9));
    });

    test('scaled and scaledChrome answer the two scales they are named for',
        () {
      expect(at(font: 40).scaled(10), closeTo(20, 1e-9));
      expect(at(font: 40).scaledChrome(10), closeTo(10, 1e-9));
      expect(at(menu: kMenuScaleMax).scaledChrome(10),
          closeTo(10 * kMenuScaleMax, 1e-9));
      expect(at(menu: kMenuScaleMax).scaled(10), closeTo(10, 1e-9));
    });

    test('every Font Size stop moves a scaled() call site', () {
      final sizes = <double>[
        for (double f = kFontSizeMin; f <= kFontSizeMax; f += 1)
          at(font: f).scaled(13),
      ];
      expect(sizes.length, 29);
      expect(sizes.toSet().length, sizes.length, reason: 'an inert stop');
    });

    test('every Menu Size stop moves a scaledChrome() call site', () {
      final sizes = <double>[
        for (var i = 0; i <= 8; i++)
          at(menu: kMenuScaleMin + i * 0.1).scaledChrome(11.5),
      ];
      expect(sizes.length, 9);
      expect(sizes.toSet().length, sizes.length, reason: 'an inert stop');
    });
  });

  test('Font Size does NOT move the chrome', () {
    // Menu bars and status bars are not reading text; tying them to
    // Font Size makes the frame lurch when a reader wants bigger verses.
    expect(at(font: 30).chrome, at(font: 20).chrome);
  });

  test('Menu Size moves the chrome and the bar heights', () {
    expect(at(menu: 1.3).chrome, greaterThan(at(menu: 1.0).chrome));
    expect(at(menu: 1.3).menuBarHeight, greaterThan(WbMetrics.menuBarHeight));
    expect(at(menu: 0.9).statusBarHeight, lessThan(WbMetrics.statusBarHeight));
  });

  test('Menu Size does NOT move body text', () {
    expect(at(menu: 1.4).text, at(menu: 1.0).text);
  });

  test('Line Spacing moves leading in the reader\'s direction', () {
    expect(at(line: 1.9).lineHeight, greaterThan(at(line: 1.5).lineHeight));
    expect(at(line: 1.1).lineHeight, lessThan(at(line: 1.5).lineHeight));
  });

  test('the workbench stays denser than the reader', () {
    // A reader on 1.9 line spacing should not get 1.9 here — the
    // workbench keeps its own tighter rhythm, shifted.
    expect(at(line: 1.9).lineHeight, lessThan(1.9));
  });

  test('out-of-range settings are clamped to the slider\'s own ends', () {
    // The clamp is a guard against a hand-edited or imported value, not
    // a design bound — so it lands exactly on what Settings offers.
    expect(at(font: 60).text, at(font: kFontSizeMax).text);
    expect(at(font: 4).text, at(font: kFontSizeMin).text);
    expect(at(menu: 9).chrome, at(menu: kMenuScaleMax).chrome);
    expect(at(menu: 0.1).chrome, at(menu: kMenuScaleMin).chrome);
    expect(at(line: 9).lineHeight, lessThanOrEqualTo(1.9));
  });

  // The defect this pins (#311, 2026-08-11): the clamps were NARROWER
  // than the sliders, so dragging Font Size from 32 to 40 pt changed the
  // label and nothing else — 11 of 29 stops, and 2 of the menu
  // slider's 9, were inert. Every earlier test here passed throughout,
  // because they all asked "does SOME change move it" and none asked
  // "does EVERY stop the reader is offered move it".
  test('every stop the Font Size slider offers moves the workbench', () {
    final sizes = <double>[
      for (double f = kFontSizeMin; f <= kFontSizeMax; f += 1) at(font: f).text,
    ];
    expect(sizes.length, 29);
    expect(sizes.toSet().length, sizes.length, reason: 'a stop that is inert');
    for (var i = 1; i < sizes.length; i++) {
      expect(sizes[i], greaterThan(sizes[i - 1]));
    }
  });

  test('every stop the Menu Size slider offers moves the chrome', () {
    final steps = <double>[
      for (var i = 0; i <= 8; i++) kMenuScaleMin + i * 0.1,
    ];
    final heights = [for (final m in steps) at(menu: m).menuBarHeight];
    expect(steps.last, closeTo(kMenuScaleMax, 1e-9));
    expect(heights.toSet().length, heights.length);
    for (var i = 1; i < heights.length; i++) {
      expect(heights[i], greaterThan(heights[i - 1]));
    }
  });

  test('the workbench spans the same ratio the slider advertises', () {
    // 12 -> 40 pt is 3.33x. The workbench used to move only 2.13x across
    // that drag, which is what "跳动很小" was describing.
    expect(
      at(font: kFontSizeMax).text / at(font: kFontSizeMin).text,
      closeTo(kFontSizeMax / kFontSizeMin, 1e-9),
    );
  });

  test('an empty font family resolves to null, not an empty string', () {
    // '' would make Flutter look up a font literally named "".
    expect(
        WbType.resolve(
                fontSize: 20, lineSpacing: 1.5, menuScale: 1, fontFamily: '')
            .fontFamily,
        isNull);
    expect(
        WbType.resolve(
                fontSize: 20,
                lineSpacing: 1.5,
                menuScale: 1,
                fontFamily: 'Noto Serif')
            .fontFamily,
        'Noto Serif');
  });
}
