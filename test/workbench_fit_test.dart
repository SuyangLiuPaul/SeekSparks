import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/workbench_fit.dart';

/// The whole small-screen advisory reduces to `adviceFor`. Everything
/// interesting is a boundary, so every boundary is pinned here.
void main() {
  WorkbenchAdvice advice(double w, double h, {bool dismissed = false}) =>
      WorkbenchFit.adviceFor(width: w, height: h, dismissed: dismissed);

  group('pane arithmetic matches the layout it is quoting', () {
    test('the constants are the sum of the panes, not round numbers', () {
      expect(WorkbenchFit.twoPaneMinWidth, 720);
      expect(WorkbenchFit.threePaneMinWidth, 992);
    });

    test('paneCountFor steps exactly at the two thresholds', () {
      expect(WorkbenchFit.paneCountFor(719), 1);
      expect(WorkbenchFit.paneCountFor(720), 2);
      expect(WorkbenchFit.paneCountFor(991), 2);
      expect(WorkbenchFit.paneCountFor(992), 3);
    });

    // The gate must stay clear of Chrome for Android's "Request desktop
    // site" viewport, which is a flat 980 CSS px on every device. A
    // threshold at or below it would be defeated by one menu item on any
    // phone, and the three columns would render at a scale nobody can
    // read. This is the reason 992 rather than a rounder 960.
    test('the threshold clears the 980px desktop-site viewport', () {
      expect(WorkbenchFit.paneCountFor(980), 2);
      expect(WorkbenchFit.threePaneMinWidth, greaterThan(980));
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
    test('phone portrait is advised — and rotating will not save it', () {
      expect(advice(390, 844), WorkbenchAdvice.largerDisplay);
    });

    test('a phone sideways is STILL not enough — two columns is not the app',
        () {
      // 844 carries two columns, not three. Owner's call: two is a
      // different, worse product, so the phone is sent to YsWords in
      // both orientations.
      expect(WorkbenchFit.paneCountFor(844), 2);
      expect(advice(844, 390), WorkbenchAdvice.largerDisplay);
      expect(advice(390, 844), WorkbenchAdvice.largerDisplay);
    });

    test('the boundary is the THREE-pane minimum, in either orientation', () {
      expect(advice(991, 800), WorkbenchAdvice.largerDisplay);
      expect(advice(992, 800), WorkbenchAdvice.none);
      expect(advice(800, 991), WorkbenchAdvice.largerDisplay);
      expect(advice(800, 992), WorkbenchAdvice.rotate);
    });

    test('a tall narrow window is judged on its width, not its short edge',
        () {
      expect(advice(479, 1200), WorkbenchAdvice.rotate);
      expect(advice(1200, 479), WorkbenchAdvice.none);
    });
  });

  group('rotation is only offered when it actually buys a column', () {
    test('a tablet that rotates into three panes is told so', () {
      // iPad Pro 11 portrait: 834 wide carries one, but 1194 carries all
      // three, so rotating is a promise the layout can keep.
      expect(WorkbenchFit.paneCountFor(1194), 3);
      expect(advice(834, 1194), WorkbenchAdvice.rotate);
    });

    test('a phone does not, in any orientation', () {
      expect(WorkbenchFit.paneCountFor(640), 1);
      expect(advice(360, 640), WorkbenchAdvice.largerDisplay);
      expect(advice(390, 844), WorkbenchAdvice.largerDisplay);
    });

    test('the long edge threshold is the three-pane minimum', () {
      expect(advice(400, 991), WorkbenchAdvice.largerDisplay);
      expect(advice(400, 992), WorkbenchAdvice.rotate);
    });

    test('a landscape screen is never told to rotate', () {
      expect(advice(1200, 700), WorkbenchAdvice.none);
      expect(advice(844, 390), WorkbenchAdvice.largerDisplay);
      expect(advice(960, 400), WorkbenchAdvice.largerDisplay);
    });

    test('square counts as landscape — there is nothing to turn', () {
      expect(advice(400, 400), WorkbenchAdvice.largerDisplay);
    });
  });

  group('real devices', () {
    test('iPad mini: portrait is asked to rotate, landscape carries three',
        () {
      // 744 wide carries one column; 1133 carries all three.
      expect(advice(744, 1133), WorkbenchAdvice.rotate);
      expect(advice(1133, 744), WorkbenchAdvice.none);
    });

    test('iPad Pro 11 landscape carries all three panes', () {
      expect(advice(1194, 834), WorkbenchAdvice.none);
      expect(WorkbenchFit.paneCountFor(1194), 3);
    });

    test('the classic 1024x768 iPad qualifies with room to spare', () {
      // It used to qualify by exactly zero — 1024 against a 1024
      // threshold, passing only because the comparison is inclusive.
      // Analysis 288->256 bought 32pt of slack, so Split View, a zoomed
      // display setting or a browser scrollbar no longer drops it out.
      expect(WorkbenchFit.paneCountFor(1024), 3);
      expect(1024 - WorkbenchFit.threePaneMinWidth, 32);
      expect(advice(1024, 768), WorkbenchAdvice.none);
      expect(advice(768, 1024), WorkbenchAdvice.rotate);
    });

    test('foldables are blocked on purpose, not by an off-by-a-little', () {
      // Pixel 10 Pro Fold, unfolded, in Chrome: 852 x 720 CSS px. It is
      // the widest phone-class viewport that exists and it is still 140px
      // short of three columns at their minimums. Owner's call
      // 2026-08-08: reaching it would mean cutting reading below 480,
      // which is the one column the workbench cannot afford to squeeze —
      // so the Fold goes to YsWords like every other phone.
      expect(WorkbenchFit.paneCountFor(852), 2);
      expect(advice(852, 720), WorkbenchAdvice.largerDisplay);
      // Folded (outer display) is unambiguous phone territory.
      expect(advice(412, 950), WorkbenchAdvice.largerDisplay);
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
