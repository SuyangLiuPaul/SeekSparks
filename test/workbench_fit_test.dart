import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/workbench_fit.dart';

/// The whole small-screen advisory reduces to `adviceFor`. Everything
/// interesting is a boundary, so every boundary is pinned here.
void main() {
  WorkbenchAdvice advice(double w, double h, {bool dismissed = false}) =>
      WorkbenchFit.adviceFor(width: w, height: h, dismissed: dismissed);

  group('pane arithmetic matches the layout it is quoting', () {
    test('the constants are the sum of the panes, not round numbers', () {
      expect(WorkbenchFit.twoPaneMinWidth, 736);
      expect(WorkbenchFit.threePaneMinWidth, 1072);
    });

    test('paneCountFor steps exactly at the two thresholds', () {
      expect(WorkbenchFit.paneCountFor(735), 1);
      expect(WorkbenchFit.paneCountFor(736), 2);
      expect(WorkbenchFit.paneCountFor(1071), 2);
      expect(WorkbenchFit.paneCountFor(1072), 3);
    });
  });

  // 2026-08-07: this group used to assert "the gate is the short edge,
  // never the width" and passed happily — while the shipped app told a
  // portrait phone that rotating would buy a second column and then, once
  // rotated, insisted the screen "does not reach two columns in EITHER
  // direction" beside the printed numbers 844 x 390 and "two need 736".
  // The tests were green because they encoded the same contradiction the
  // spec did. What is asserted now is the promise the UI actually makes.
  group('the gate is the current width, because that is what the panes use',
      () {
    test('phone portrait is advised — 390 carries one column', () {
      expect(advice(390, 844), WorkbenchAdvice.rotate);
    });

    test('the SAME phone rotated is fine — 844 carries two', () {
      // The bug in one line: this returned largerDisplay, so turning the
      // phone changed nothing and the advice contradicted itself.
      expect(WorkbenchFit.paneCountFor(844), 2);
      expect(advice(844, 390), WorkbenchAdvice.none);
    });

    test('the boundary is the two-pane minimum, in either orientation', () {
      expect(advice(735, 400), WorkbenchAdvice.largerDisplay);
      expect(advice(736, 400), WorkbenchAdvice.none);
      expect(advice(400, 735), WorkbenchAdvice.largerDisplay);
      expect(advice(400, 736), WorkbenchAdvice.rotate);
    });

    test('a tall narrow window is judged on its width, not its short edge',
        () {
      expect(advice(479, 900), WorkbenchAdvice.rotate);
      expect(advice(900, 479), WorkbenchAdvice.none);
    });
  });

  group('rotation is only offered when it actually buys a column', () {
    test('390x844 rotates into two panes', () {
      expect(WorkbenchFit.paneCountFor(844), 2);
      expect(advice(390, 844), WorkbenchAdvice.rotate);
    });

    test('360x640 does not — 640 wide leaves the reader under 480', () {
      expect(WorkbenchFit.paneCountFor(640), 1);
      expect(advice(360, 640), WorkbenchAdvice.largerDisplay);
    });

    test('the long edge threshold is the two-pane minimum', () {
      expect(advice(400, 735), WorkbenchAdvice.largerDisplay);
      expect(advice(400, 736), WorkbenchAdvice.rotate);
    });

    test('a landscape screen is never told to rotate', () {
      // Wide enough already — nothing to advise.
      expect(advice(844, 390), WorkbenchAdvice.none);
      expect(advice(1000, 400), WorkbenchAdvice.none);
      // Too narrow even sideways — say so, do not offer a rotation that
      // would not help.
      expect(advice(700, 400), WorkbenchAdvice.largerDisplay);
    });

    test('square counts as landscape — there is nothing to turn', () {
      expect(advice(400, 400), WorkbenchAdvice.largerDisplay);
    });
  });

  group('real devices', () {
    test('iPad mini clears the gate in both orientations', () {
      expect(advice(744, 1133), WorkbenchAdvice.none);
      expect(advice(1133, 744), WorkbenchAdvice.none);
    });

    test('iPad Pro 11 landscape carries all three panes', () {
      expect(advice(1194, 834), WorkbenchAdvice.none);
      expect(WorkbenchFit.paneCountFor(1194), 3);
    });

    test('1024x768 iPad falls to two panes but is not advised', () {
      expect(advice(1024, 768), WorkbenchAdvice.none);
      expect(WorkbenchFit.paneCountFor(1024), 2);
    });

    test('1280x800 laptop is comfortable', () {
      expect(advice(1280, 800), WorkbenchAdvice.none);
      expect(1280, greaterThanOrEqualTo(WorkbenchFit.comfortableWidth));
    });
  });

  group('dismissal', () {
    test('overrules every state — no is an answer', () {
      expect(advice(390, 844, dismissed: true), WorkbenchAdvice.none);
      expect(advice(844, 390, dismissed: true), WorkbenchAdvice.none);
      expect(advice(320, 480, dismissed: true), WorkbenchAdvice.none);
    });

    test('does not invent an advisory on a screen that never had one', () {
      expect(advice(1400, 900, dismissed: true), WorkbenchAdvice.none);
    });
  });
}
