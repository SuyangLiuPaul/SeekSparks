/// The Analysis tab strip's row/label rule.
///
/// The regression this guards: the old rule divided the pane width by the
/// TOTAL number of tabs rather than by the number on a row, so every tab
/// added past the eighth pushed the whole strip closer to permanent
/// icon-only mode — even though the strip wraps and two rows of six would
/// have had ample room for the labels.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/widgets/analysis_tabs.dart';

void main() {
  group('analysisStripLayout', () {
    test('a wide pane keeps one labelled row', () {
      final l = analysisStripLayout(900, 12);
      expect(l.showLabels, isTrue);
      expect(l.perRow, 12);
    });

    test('a 420 px pane keeps its labels by wrapping to two rows', () {
      // The exact case the old rule got wrong: 420/12 = 35 px reads as
      // hopeless, 420/6 = 70 px is comfortable.
      final l = analysisStripLayout(420, 12);
      expect(l.showLabels, isTrue);
      expect(l.perRow, 6);
    });

    test('adding a twelfth tab does not cost the eleven their labels', () {
      for (final width in <double>[420, 500, 560]) {
        expect(analysisStripLayout(width, 11).showLabels, isTrue);
        expect(analysisStripLayout(width, 12).showLabels, isTrue,
            reason: 'labels lost at ${width}px when the 12th tab arrived');
      }
    });

    test('the 320 px pane minimum falls back to balanced icon rows', () {
      final l = analysisStripLayout(320, 12);
      expect(l.showLabels, isFalse);
      expect(l.perRow, 6, reason: 'rows must be balanced, not 10+2');
      expect(320 / l.perRow, greaterThanOrEqualTo(30));
    });

    test('labelled rows never exceed two', () {
      for (var w = 100.0; w <= 1200.0; w += 7) {
        final l = analysisStripLayout(w, 12);
        if (l.showLabels) {
          expect((12 / l.perRow).ceil(), lessThanOrEqualTo(2));
        }
      }
    });

    test('every tab always gets at least the bare-icon width, or the '
        'strip is on one row', () {
      for (var w = 60.0; w <= 1200.0; w += 3) {
        final l = analysisStripLayout(w, 12);
        expect(l.perRow, inInclusiveRange(1, 12));
        if (l.perRow > 1) {
          expect(w / l.perRow, greaterThanOrEqualTo(30 - 0.001),
              reason: 'tabs clip at ${w}px');
        }
      }
    });

    test('a labelled row really has room for a label', () {
      for (var w = 60.0; w <= 1200.0; w += 3) {
        final l = analysisStripLayout(w, 12);
        if (l.showLabels) {
          expect(w / l.perRow, greaterThanOrEqualTo(66 - 0.001));
        }
      }
    });

    test('an unbounded width does not crash or claim labels', () {
      final l = analysisStripLayout(double.infinity, 12);
      expect(l.perRow, 12);
      expect(l.showLabels, isFalse);
    });

    test('zero tabs is a single empty row, not a division by zero', () {
      final l = analysisStripLayout(400, 0);
      expect(l.perRow, 1);
      expect(l.showLabels, isFalse);
    });
  });
}
