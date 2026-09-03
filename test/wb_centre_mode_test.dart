/// #276 — the centre pane's three modes, and the rules that keep a saved
/// preference from putting an unrenderable pane on screen.
///
/// All of this is pure by design: the alternative is a bool threaded
/// through an 8000-line widget, where "does split fit here" gets answered
/// three times in three places and drifts. None of these failures are
/// visible in a screenshot — a mode that silently reverts, or a migration
/// that quietly resets everyone's centre pane, looks exactly like working
/// software until someone notices their setting did not stick.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/wb_centre_mode.dart';
import 'package:seeksparks/utils/responsive.dart';

void main() {
  group('resolveCentreMode', () {
    test('reads back every mode it can write', () {
      for (final mode in WbCentreMode.values) {
        expect(resolveCentreMode(stored: centreModeToStorage(mode)), mode);
      }
    });

    test('persists by name, not by index', () {
      // Index would mean inserting a fourth mode anywhere but the end
      // silently repoints every saved preference at a different pane.
      expect(centreModeToStorage(WbCentreMode.reader), 'reader');
      expect(centreModeToStorage(WbCentreMode.browse), 'browse');
      expect(centreModeToStorage(WbCentreMode.split), 'split');
    });

    test('honours the legacy bool once, for readers who chose the reader',
        () {
      // workbench.browseMode.v2 == false meant "chapter reader". Losing
      // that on upgrade would move the pane out from under them.
      expect(resolveCentreMode(legacyParallel: false), WbCentreMode.reader);
      expect(resolveCentreMode(legacyParallel: true), WbCentreMode.browse);
    });

    test('the new key wins over the legacy bool once both exist', () {
      // After the first write there are two values on disk and only the
      // string is being maintained.
      expect(
        resolveCentreMode(stored: 'split', legacyParallel: false),
        WbCentreMode.split,
      );
      expect(
        resolveCentreMode(stored: 'reader', legacyParallel: true),
        WbCentreMode.reader,
      );
    });

    test('a fresh install lands on Browse', () {
      expect(resolveCentreMode(), WbCentreMode.browse);
    });

    test('a value from a future build falls back rather than throwing', () {
      // A reader who runs a newer build and then downgrades has a mode
      // name this binary has never heard of sitting in preferences.
      expect(resolveCentreMode(stored: 'quadview'), WbCentreMode.browse);
      expect(resolveCentreMode(stored: ''), WbCentreMode.browse);
      expect(resolveCentreMode(stored: '2'), WbCentreMode.browse);
    });
  });

  group('splitFitsIn', () {
    test('is two reading columns plus one divider, not a guessed number', () {
      expect(
        kMinCentreWidthForSplit,
        ResponsiveBreakpoints.minReadingPaneWidth * 2 + kSplitDividerWidth,
      );
    });

    test('admits the exact minimum and refuses one pixel less', () {
      expect(splitFitsIn(kMinCentreWidthForSplit), isTrue);
      expect(splitFitsIn(kMinCentreWidthForSplit - 1), isFalse);
    });

    test('the concrete boundary the View menu greys on', () {
      expect(splitFitsIn(976), isTrue);
      expect(splitFitsIn(975), isFalse);
    });

    test('a centre pane narrower than one column is never close', () {
      expect(splitFitsIn(0), isFalse);
      expect(splitFitsIn(480), isFalse);
    });
  });

  group('effectiveCentreMode', () {
    WbCentreMode effective(WbCentreMode preferred,
            {double centre = 1200, bool threePane = true}) =>
        effectiveCentreMode(
          preferred: preferred,
          centreWidth: centre,
          threePane: threePane,
        );

    test('renders each mode as asked when there is room', () {
      for (final mode in WbCentreMode.values) {
        expect(effective(mode), mode);
      }
    });

    test('the chapter reader always renders — it is the floor', () {
      expect(effective(WbCentreMode.reader, centre: 200, threePane: false),
          WbCentreMode.reader);
    });

    test('Browse does NOT fall back — it never needed the three-pane width',
        () {
      // This test asserted the opposite until 2026-09-03, and the rule
      // it pinned was wrong on its own terms. The reason given was
      // "three editions of a verse read as fragments" — which is
      // split's reasoning, about side-by-side COLUMNS, applied to a
      // layout that has none. `BrowseWindow` builds one ROW per (verse,
      // edition) in a single vertical list, so every edition already
      // gets the full width of the pane and narrowing the pane narrows
      // one column of prose rather than slicing it into three.
      //
      // Nobody could see it while `SmallScreenGate` refused every
      // viewport under that width anyway. The day the gate came off,
      // the toolbar's Browse button was dead on a phone — pressed, and
      // the centre stayed on the reader. Reported within the hour.
      expect(effective(WbCentreMode.browse, threePane: false),
          WbCentreMode.browse);
      expect(effective(WbCentreMode.browse, threePane: true),
          WbCentreMode.browse);
      // And at a phone's centre width, which is what actually changed.
      expect(effective(WbCentreMode.browse, threePane: false, centre: 375),
          WbCentreMode.browse);
    });

    test('split still falls back, because split really does need columns',
        () {
      // The control. If the repair above had been "stop refusing
      // anything", this is the test that would have caught it: split's
      // rule is measured — two reading columns at the app's own minimum
      // width — and it stands.
      expect(effective(WbCentreMode.split, threePane: false, centre: 375),
          WbCentreMode.reader);
    });

    test('split falls back to the reader in a narrow centre', () {
      expect(
        effective(WbCentreMode.split, centre: kMinCentreWidthForSplit - 1),
        WbCentreMode.reader,
      );
    });

    test('split does not need three panes — closing one is how you fit it',
        () {
      // Collapsing the Analysis rail is precisely how a reader buys the
      // width for two columns, so requiring three panes here would make
      // the control unreachable at exactly the moment it becomes usable.
      expect(effective(WbCentreMode.split, threePane: false),
          WbCentreMode.split);
    });

    test('the result is always a mode the same rules would keep', () {
      // The status bar labels — and the status bar's tap cycle starts
      // from — whatever this returns. If it could hand back a mode that
      // does not fit, the one field whose job is to say what is on
      // screen would be the field that lies about it.
      for (final preferred in WbCentreMode.values) {
        for (final centre in const [0.0, 480.0, 975.0, 976.0, 1400.0]) {
          for (final threePane in const [true, false]) {
            final got = effectiveCentreMode(
              preferred: preferred,
              centreWidth: centre,
              threePane: threePane,
            );
            expect(
              effectiveCentreMode(
                preferred: got,
                centreWidth: centre,
                threePane: threePane,
              ),
              got,
              reason: '$preferred @ $centre/$threePane resolved to $got, '
                  'which does not survive its own rules',
            );
          }
        }
      }
    });

    test('a fallback never rewrites the preference it fell back from', () {
      // The wish survives the narrow window: same preferred value, a
      // wider centre, and split is back without the reader re-picking it.
      expect(effective(WbCentreMode.split, centre: 600), WbCentreMode.reader);
      expect(effective(WbCentreMode.split, centre: 1200), WbCentreMode.split);
    });
  });
}
