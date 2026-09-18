// 2026-09-14: the reading measure, which this app had documented and
// never applied.
//
// `ResponsiveBreakpoints.maxContentWidth` arrived with the port from
// YsWords carrying forty lines of reasoning — Bringhurst's ~75-character
// ceiling, the CJK adjustment that raised the caps because a Han glyph
// is about twice the width of a Latin one, and a reader's report from a
// Xiaomi Pad 7 Ultra — and nothing in `lib/` called it. A rule that is
// written down, argued for, and obeyed by no screen is worse than no
// rule at all: it reads as settled.
//
// Two things are pinned here, and the second matters as much as the
// first. A cap that binds everywhere would be a different bug — it would
// put gutters beside a 400px workbench column — so this also asserts
// that the helper's own numbers leave every pane width this tool
// actually uses untouched.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_sword/utils/responsive.dart';

void main() {
  group('the measure is real', () {
    test('a wide display gets a cap, a phone does not', () {
      // The phone end is not an oversight. A 390px screen is already
      // narrower than any sensible measure, and a cap there could only
      // subtract from a column that has nothing to spare.
      expect(ResponsiveBreakpoints.maxContentWidth(DeviceClass.miniPhone),
          double.infinity);
      expect(ResponsiveBreakpoints.maxContentWidth(DeviceClass.phone),
          double.infinity);
      for (final dc in [DeviceClass.tablet, DeviceClass.desktop,
                        DeviceClass.tv]) {
        expect(ResponsiveBreakpoints.maxContentWidth(dc), lessThan(2000),
            reason: '$dc has no cap, so a verse runs the full width of a '
                'monitor');
        expect(ResponsiveBreakpoints.maxContentWidth(dc).isFinite, isTrue);
      }
    });

    test('the caps rise with the screen and never fall', () {
      // A cap that went DOWN at a larger breakpoint would shrink the
      // column on the bigger display, which is the opposite of what the
      // rationale asks for.
      final ladder = [
        ResponsiveBreakpoints.maxContentWidth(DeviceClass.tablet),
        ResponsiveBreakpoints.maxContentWidth(DeviceClass.desktop),
        ResponsiveBreakpoints.maxContentWidth(DeviceClass.tv),
      ];
      for (var i = 1; i < ladder.length; i++) {
        expect(ladder[i], greaterThanOrEqualTo(ladder[i - 1]));
      }
    });
  });

  group('it binds where the line is too long, and nowhere else', () {
    // The Workbench draws three columns side by side. If the cap could
    // bind on one of those, the fix would be worse than the defect —
    // that is the case this group exists to hold.
    //
    // Measured, not assumed: the widths below are what a 1920 window
    // leaves a centre column once the left and right panes and their dividers
    // are taken out, and what a laptop leaves it.
    const paneWidths = <String, double>{
      'three panes on a 1920 monitor': 900,
      'three panes on a 1440 laptop': 640,
      'two panes on a 1280 laptop': 820,
      'the analysis column': 420,
    };

    test('no workbench column is ever narrowed by it', () {
      final cap = ResponsiveBreakpoints.maxContentWidth(DeviceClass.desktop);
      paneWidths.forEach((what, width) {
        expect(width, lessThan(cap),
            reason: '$what is ${width}px, which the ${cap}px measure '
                'would cut — the cap is meant to be invisible until a '
                'column is genuinely too wide to read');
      });
    });

    test('the Reader at full width on a large display IS narrowed', () {
      // The one surface the cap exists for: centre mode with both side
      // panes collapsed, which is the app at its widest.
      const readerAt1920 = 1880.0;
      final cap = ResponsiveBreakpoints.maxContentWidth(DeviceClass.desktop);
      expect(readerAt1920, greaterThan(cap),
          reason: 'if this ever stops being true the cap has stopped '
              'doing anything and the helper is dead code again');
    });
  });

  test('the reading pane actually consults it', () {
    // The failure this file was written for is not a wrong number, it is
    // a right number nobody reads. Asserted against the source because
    // the alternative — rendering the pane at 1920 and measuring a
    // RichText — needs a loaded corpus, a chapter index and a settled
    // ScrollablePositionedList; that test would be measuring five other
    // things at once.
    final src =
        File('lib/widgets/bible_reading_pane.dart').readAsStringSync();
    expect(src, contains('ResponsiveBreakpoints.maxContentWidth('),
        reason: 'the verse column no longer reads the measure, so '
            'maxContentWidth is back to being forty lines of rationale '
            'that nothing obeys');
  });
}
