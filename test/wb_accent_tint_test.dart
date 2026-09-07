// 2026-09-07: the reader's Primary Color reaches the workbench.
//
// SeekSparks already shipped the picker — seven swatches in Settings,
// each mapped to an app-icon variant by `AppIconService.variantForColor`
// — but it stopped at the phone reader. `WbColors` was three const
// palettes, so a reader who picked green got a green icon and the same
// navy workspace. `WbColors.tinted` closes that, and these pin the two
// halves of the contract:
//
//   1. The accent actually ARRIVES (link/selection/hover move, and are
//      recognisably the chosen hue).
//   2. It arrives LEGIBLE. The picker offers `Colors.orange`, which raw
//      is 4.0:1 on white; and the default #B23A32, which raw is 2.6:1 on
//      the dark ground. A theme that lets the reader make their own
//      links unreadable is a bug with a colour picker attached, so the
//      bands in `tinted` are the point of the function, not a detail of
//      it.
//
// And the third half, which is a design claim rather than a measurement:
// only three roles move. Everything that carries a FIXED meaning — the
// Strong's hues, the pin, the sibling fill, the difference mark, every
// neutral — is left exactly where it was.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/services/app_icon_service.dart';

/// Every swatch the picker in `settings_page.dart` actually offers.
/// Keep in lock-step with that list — a swatch that is offered and not
/// tested is a swatch nobody has checked is readable.
const _picker = <Color>[
  AppIconService.kDefaultPrimaryColor,
  Colors.red,
  Colors.orange,
  Colors.green,
  Colors.purple,
  Colors.pink,
  Colors.blueGrey,
];

const _palettes = <String, WbColors>{
  'light': WbColors.light,
  'dark': WbColors.dark,
  'paper': WbColors.paper,
};

void main() {
  group('WbColors.tinted', () {
    test('every picker swatch keeps the link at WCAG AA on every palette',
        () {
      final failures = <String>[];
      _palettes.forEach((name, palette) {
        for (final swatch in _picker) {
          final tinted = palette.tinted(swatch);
          final ratio = _contrast(tinted.link, tinted.paneBg);
          if (ratio < 4.5) {
            failures.add('$name + ${_hex(swatch)}: link is '
                '${ratio.toStringAsFixed(2)}:1 on the pane');
          }
        }
      });
      expect(failures, isEmpty,
          reason: 'A link the reader cannot read is not a theme:\n'
              '  ${failures.join('\n  ')}');
    });

    test('text stays readable ON the tinted selection', () {
      // The selection is a FILL under body text. Getting the link right
      // and the selection wrong would trade one unreadable surface for
      // another — and the selected verse is the one the reader is
      // actually looking at.
      final failures = <String>[];
      _palettes.forEach((name, palette) {
        for (final swatch in _picker) {
          final tinted = palette.tinted(swatch);
          final ratio = _contrast(tinted.text, tinted.selectionBg);
          if (ratio < 4.5) {
            failures.add('$name + ${_hex(swatch)}: text is '
                '${ratio.toStringAsFixed(2)}:1 on the selection');
          }
        }
      });
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('hover is quieter than selection, and both are on the pane side',
        () {
      // A pointer resting on a row must not shout as loudly as a row
      // that is chosen — that is the whole difference between "you are
      // here" and "this is what you picked".
      for (final palette in _palettes.values) {
        for (final swatch in _picker) {
          final t = palette.tinted(swatch);
          final hoverDelta = _distance(t.hoverBg, t.paneBg);
          final selDelta = _distance(t.selectionBg, t.paneBg);
          expect(hoverDelta, lessThan(selDelta),
              reason: 'hover should sit closer to the pane than selection');
        }
      }
    });

    test('the accent is recognisably the hue the reader picked', () {
      // Clamping saturation and lightness is allowed; moving the HUE is
      // not — that would mean the swatch and the workspace disagree
      // about what colour the app is.
      for (final palette in _palettes.values) {
        for (final swatch in _picker) {
          final want = HSLColor.fromColor(swatch);
          // A near-grey swatch (blueGrey) has an unstable hue by
          // definition; the saturation floor is what makes it visible
          // at all, so only check swatches with real chroma.
          if (want.saturation < 0.2) continue;
          final got = HSLColor.fromColor(palette.tinted(swatch).link);
          final delta = (got.hue - want.hue).abs();
          expect(math.min(delta, 360 - delta), lessThan(12),
              reason: '${_hex(swatch)} came back as a different hue');
        }
      }
    });

    test('nothing with a fixed meaning moves', () {
      // The Strong's hues are a convention the reader LEARNS — green is
      // the word's own number, blue is a grammar code. A Strong's number
      // that changed colour with the theme would stop meaning anything.
      // The pin, the sibling fill and the difference mark are each
      // contrast-audited against a specific fill. And re-tinting the
      // neutrals would not make the app greener, it would make it a
      // green-tinted photograph of itself.
      for (final palette in _palettes.values) {
        final t = palette.tinted(Colors.green);
        expect(t.strongsLexical, palette.strongsLexical);
        expect(t.strongsGrammar, palette.strongsGrammar);
        expect(t.pinMark, palette.pinMark);
        expect(t.siblingBg, palette.siblingBg);
        expect(t.diffMark, palette.diffMark);
        expect(t.paneBg, palette.paneBg);
        expect(t.paneAltBg, palette.paneAltBg);
        expect(t.chromeBg, palette.chromeBg);
        expect(t.border, palette.border);
        expect(t.disabledMark, palette.disabledMark);
        expect(t.text, palette.text);
        expect(t.mutedText, palette.mutedText);
      }
    });

    test('two different swatches give two different workspaces', () {
      // The complaint this whole change answers: picking a colour
      // changed the icon and nothing else.
      final green = WbColors.light.tinted(Colors.green);
      final purple = WbColors.light.tinted(Colors.purple);
      expect(green.link, isNot(purple.link));
      expect(green.selectionBg, isNot(purple.selectionBg));
      expect(green.hoverBg, isNot(purple.hoverBg));
    });
  });

  group('workbenchTheme(accent:)', () {
    test('omitting the accent leaves the const palette exactly as it was',
        () {
      // Every other theme test in the suite asserts against the const
      // instances. They stay valid because the tint is opt-in.
      expect(
          workbenchTheme(ThemeData.light(useMaterial3: true))
              .extension<WbColors>(),
          WbColors.light);
      expect(
          workbenchTheme(ThemeData.dark(useMaterial3: true))
              .extension<WbColors>(),
          WbColors.dark);
      expect(
          workbenchTheme(ThemeData.light(useMaterial3: true), paper: true)
              .extension<WbColors>(),
          WbColors.paper);
    });

    test('passing one re-points the whole subtree, paper included', () {
      final themed = workbenchTheme(ThemeData.light(useMaterial3: true),
          accent: Colors.purple);
      expect(themed.extension<WbColors>(), WbColors.light.tinted(Colors.purple));
      // The ColorScheme is seeded from `wb.link`, so the accent reaches
      // every Material component in the subtree too, not just the
      // widgets that read WbColors directly.
      expect(themed.colorScheme.primary,
          WbColors.light.tinted(Colors.purple).link);

      final paper = workbenchTheme(ThemeData.light(useMaterial3: true),
          paper: true, accent: Colors.purple);
      expect(paper.extension<WbColors>(), WbColors.paper.tinted(Colors.purple));
    });
  });
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

/// Euclidean distance in sRGB. Crude, and adequate for "is A nearer to
/// the pane than B is".
double _distance(Color a, Color b) {
  final dr = (a.r - b.r) * 255, dg = (a.g - b.g) * 255, db = (a.b - b.b) * 255;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

/// WCAG contrast ratio, 1..21.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final la = lum(a), lb = lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}
