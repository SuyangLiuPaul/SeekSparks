// 2026-08-09 (task #284): the Word Study tab's two presentations.
//
// `OriginalsSheet` is both a phone bottom sheet and the workbench's
// docked Word Study tab. `WordStudyStyle.resolve` is the one place the
// two columns are written down, so it is the one place worth pinning.
//
// Two things are guarded, and they pull in opposite directions:
//
//   1. The DENSE column obeys workbench_theme.dart:16 — "Square corners
//      and 1px hairline borders. No shadows, no cards." Every radius
//      must be zero, every border must be a hairline, and every font
//      size must come from `WbType` rather than a literal, because the
//      workbench has a font-size setting this pane used to ignore.
//
//   2. The MODAL column's PROPORTIONS must not move. #284 asked for a
//      workbench restyle; every number below is what the phone reader
//      shipped with before `WordStudyStyle` existed, and a change to
//      their ratios is a change to a surface nobody asked us to touch.
//
//      Read each as "n px at the default 20 pt", not as n px. #315 made
//      the column scale with Font Size — the modal was reading the
//      reader's own text-size setting and discarding it — while leaving
//      Menu Size, which is workbench chrome, out of it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/word_study_style.dart';
import 'package:seeksparks/constants/workbench_theme.dart';

const _scheme = ColorScheme.light();

/// The app's defaults for the three settings `WbType` reads, so
/// `_type()` with no arguments is exactly `WbType.fallback`.
WbType _type({double fontSize = 20, double menuScale = 1}) => WbType.resolve(
      fontSize: fontSize,
      lineSpacing: 1.5,
      menuScale: menuScale,
    );

WordStudyStyle _modal({WbType? type}) => WordStudyStyle.resolve(
      embedded: false,
      scheme: _scheme,
      wb: WbColors.light,
      type: type ?? _type(),
    );

WordStudyStyle _dense({WbColors? wb, WbType? type}) => WordStudyStyle.resolve(
      embedded: true,
      scheme: _scheme,
      wb: wb ?? WbColors.light,
      type: type ?? _type(),
    );

void main() {
  group('the docked pane obeys the workbench design language', () {
    test('every corner is square, at every radius a call site asks for', () {
      final st = _dense();
      for (final soft in <double>[2, 4, 6, 8, 10, 12, 16]) {
        expect(st.r(soft), BorderRadius.zero,
            reason: 'r($soft) rounded a corner in the workbench');
      }
    });

    test('borders are hairlines, not the modal 1.5px ring', () {
      expect(_dense().borderWidth, WbMetrics.hairline);
    });

    test('no card fills or washes: the sheet separates by hairline', () {
      final st = _dense();
      // A chip sits on the pane ground; filling forty of them turns a
      // verse into a field of grey boxes at this density.
      expect(st.chipFill, WbColors.light.paneBg);
      expect(st.chipBorder, WbColors.light.border);
      // The parsing line and the AI panel earn emphasis from a hairline
      // and the link colour, the way every other workbench pane does.
      expect(st.accentFill, Colors.transparent);
      // Strong's numbers are coloured numerals here, not a tinted pill.
      expect(st.strongsFill, Colors.transparent);
      expect(st.strongs, WbColors.light.strongsLexical);
    });

    test('colours come from WbColors, so all three palettes work', () {
      for (final wb in <WbColors>[
        WbColors.light,
        WbColors.dark,
        WbColors.paper
      ]) {
        final st = _dense(wb: wb);
        expect(st.blockFill, wb.paneAltBg);
        expect(st.blockBorder, wb.border);
        expect(st.accent, wb.link);
        expect(st.selectedFill, wb.selectionBg);
        // `pinMark`, not the app's gold accent: it is the one marker
        // already contrast-checked against selectionBg in all three
        // themes. In 护眼纸质 the gold measures 1.54:1 and vanishes.
        expect(st.selectedBorder, wb.pinMark);
      }
    });

    test('type scales with the workbench font-size setting', () {
      final small = _dense(type: _type(fontSize: 16, menuScale: 0.8));
      final large = _dense(type: _type(fontSize: 28, menuScale: 1.4));
      expect(large.body, greaterThan(small.body));
      expect(large.lemma, greaterThan(small.lemma));
      expect(large.original, greaterThan(small.original));
      // Nothing may be pinned to a literal: a size that does not move
      // with the scale is a size that ignored the setting.
      expect(large.gloss, greaterThan(small.gloss));
      expect(large.ref, greaterThan(small.ref));
      expect(large.micro, greaterThan(small.micro));
      expect(large.translit, greaterThan(small.translit));
    });

    test('the headword matches WordAnalysisPane at the default scale', () {
      // The tab has two bodies — a hovered word gives WordAnalysisPane,
      // a hovered verse gives this sheet. They must print a lemma the
      // same size or moving the pointer resizes the headword.
      expect(_dense().lemma, WbType.fallback.original + 6);
    });

    test('two chips plus gutters fit the 256px pane floor', () {
      final st = _dense();
      final used =
          st.chipMaxWidth * 2 + 6 + st.listPadding.left + st.listPadding.right;
      expect(used, lessThanOrEqualTo(256));
    });

    test('list padding matches WordAnalysisPane so text does not shift', () {
      // Same reason as the lemma: the two bodies of one tab must not
      // move the left margin as the pointer crosses from word to verse.
      expect(_dense().listPadding, const EdgeInsets.fromLTRB(8, 6, 8, 16));
    });
  });

  group('the phone modal is untouched by #284', () {
    test('at the default setting the type scale is the one that shipped', () {
      final st = _modal();
      expect(st.body, 14);
      expect(st.ref, 12);
      expect(st.gloss, 11);
      expect(st.translit, 10);
      expect(st.micro, 9);
      expect(st.original, 18);
      expect(st.lemma, 22);
    });

    test('corners stay rounded and the selection ring stays 1.5px', () {
      final st = _modal();
      expect(st.r(8), BorderRadius.circular(8));
      expect(st.r(12), BorderRadius.circular(12));
      expect(st.borderWidth, 1.5);
    });

    test('it separates by rounded fill, not by hairline', () {
      final st = _modal();
      expect(st.blockBorder, Colors.transparent);
      expect(st.chipBorder, Colors.transparent);
      expect(
          st.blockFill, _scheme.surfaceContainerHighest.withValues(alpha: 0.4));
      expect(
          st.chipFill, _scheme.surfaceContainerHighest.withValues(alpha: 0.5));
      expect(st.selectedFill, _scheme.primaryContainer);
      expect(st.selectedBorder, _scheme.primary);
      expect(st.accent, _scheme.primary);
      expect(st.accentFill, _scheme.primary.withValues(alpha: 0.07));
      expect(st.strongs, _scheme.secondary);
    });

    test('geometry is the one that shipped', () {
      final st = _modal();
      expect(st.listPadding, const EdgeInsets.fromLTRB(20, 16, 20, 24));
      expect(st.blockPadding, const EdgeInsets.fromLTRB(12, 10, 12, 10));
      expect(st.chipMaxWidth, 118);
    });

    // 2026-08-11 (#315). This test used to assert the opposite — "the
    // modal ignores the workbench font-size setting" — on the argument
    // that the modal is not in the workbench subtree, so a desktop
    // preference must not reach it.
    //
    // The first half of that is right and is kept below. The second half
    // conflated the two sliders. **Menu Size** is workbench chrome and
    // has no business on a phone. **Font Size** is not a workbench
    // preference at all: it is the reader's text size, the same 12–40 pt
    // that sets the verse text on every reader page. The modal was the
    // one surface that read the setting and then ignored it, so a reader
    // who moved the slider to either end saw this sheet at 14 px
    // regardless — which is the reported defect, on a phone.
    test('the modal follows Font Size, because that is the reader\'s own', () {
      final big = _modal(type: _type(fontSize: 40));
      final small = _modal(type: _type(fontSize: 12));
      expect(big.body, greaterThan(_modal().body));
      expect(small.body, lessThan(_modal().body));
      expect(big.body, closeTo(14 * 2, 1e-9));
      // The chip has to grow with the word it contains, or a 36 px
      // Hebrew glyph is clipped by a box sized for an 18 px one.
      expect(big.chipMaxWidth, greaterThan(_modal().chipMaxWidth));
    });

    test('the modal does NOT follow Menu Size', () {
      // Frame furniture for a three-pane desktop is not a phone's
      // business, and this sheet has no frame.
      final st = _modal(type: _type(menuScale: 1.4));
      expect(st.body, 14);
      expect(st.original, 18);
      expect(st.lemma, 22);
    });

    test('the modal\'s originals obey the same floor as the workbench\'s', () {
      // 18 and 22 px of pointed Hebrew at 12 pt would be 10.8 and 13.2 —
      // below the size at which a tsere and a segol can be told apart.
      final small = _modal(type: _type(fontSize: 12));
      expect(small.original, greaterThanOrEqualTo(WbMetrics.originalFloor));
      expect(small.lemma, greaterThanOrEqualTo(WbMetrics.originalFloor));
      // …and the Latin around them is free to shrink. The floor is for
      // the scripts whose diacritics carry meaning, not a global minimum.
      expect(small.body, lessThan(WbMetrics.originalFloor));
    });
  });

  // 2026-08-31 (#315 residue). The source ratchet in
  // `font_size_reach_ratchet_test.dart` lists this file under
  // `finished` — "zero literals, and it stays zero" — and that was true
  // while `translit` and `micro` resolved to 9.0px, the smallest type
  // in the app. The ratchet counts notation. This group counts pixels.
  group('no field in the docked column is designed under the floor', () {
    /// Every field of [WordStudyStyle] that is handed to a `fontSize:`.
    /// Written out rather than reflected over, so adding a size field
    /// and forgetting it here is a visible omission in a diff.
    Map<String, double> fontFields(WordStudyStyle s) => {
          'body': s.body,
          'ref': s.ref,
          'gloss': s.gloss,
          'translit': s.translit,
          'micro': s.micro,
          'original': s.original,
          'lemma': s.lemma,
        };

    test('the workbench column, at the default Menu Size', () {
      final under = <String>[];
      fontFields(_dense()).forEach((name, px) {
        if (px < WbMetrics.smallPrintFloor) {
          under.add('$name resolved to ${px}px');
        }
      });
      expect(under, isEmpty,
          reason: 'WbMetrics.smallPrintFloor is '
              '${WbMetrics.smallPrintFloor}px and this pane is a '
              'workbench resident, where that floor is the rule the '
              'other 88 sites already pay. A size written as an offset '
              'off a resolved WbType field is invisible to the source '
              'ratchet, so this is the only guard that can see it:\n'
              '${under.join('\n')}');
    });

    test('the two smallest fields sit exactly on the floor, not above it',
        () {
      // Not `greaterThanOrEqualTo`: the floor is a floor, and quietly
      // growing these to 12 would be a design change nobody asked for.
      expect(_dense().translit, WbMetrics.smallPrintFloor);
      expect(_dense().micro, WbMetrics.smallPrintFloor);
    });

    test('rank in this column is not carried by size, and never was', () {
      // The stated reason these two were deferred was that raising them
      // collapses four ranks. It does collapse four SIZES — and all six
      // call sites in originals_sheet.dart distinguish these fields by
      // colour, weight, italics or tracking, never by size alone. This
      // asserts the collapse the change actually makes, so a reader of
      // the diff is not left guessing whether it was noticed.
      final st = _dense();
      expect(st.ref, st.gloss);
      expect(st.gloss, st.translit);
      expect(st.translit, st.micro);
    });

    test('the phone modal is UNDER the floor and is deliberately left so',
        () {
      // Not a passing guard — a written exception, so the debt is
      // stated rather than skipped over.
      //
      // The modal's proportions are pinned at :142-143 as "what the
      // phone reader shipped with before WordStudyStyle existed", a
      // decision from #284 that still stands, and
      // WbMetrics.smallPrintFloor's own comment calls it "a comfort
      // bound, not a correctness one" — which does not license
      // overriding a deliberate decision about a different surface.
      // Raising these is an OWNER call, not a loop call.
      final m = _modal();
      expect(m.translit, lessThan(WbMetrics.smallPrintFloor));
      expect(m.micro, lessThan(WbMetrics.smallPrintFloor));
      expect(m.translit, 10);
      expect(m.micro, 9);
    });
  });
}
