/// Hover = preview, click = commit.
///
/// The defect these guard: hovering a tagged word filled the Analysis
/// pane with statistics, and moving the mouse TOWARD that pane crossed
/// every word in between, so the content the reader was reaching for was
/// gone before they arrived. The feature destroyed itself in the act of
/// being used.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/analysis_focus.dart';

void main() {
  const a = 'John|1|BGT|3|2';
  const b = 'John|1|BGT|3|5';

  group('browseWordKey', () {
    test('separates two occurrences in the same verse', () {
      expect(
        browseWordKey(prefix: 'John|1', versionCode: 'BGT', verse: 3, index: 2),
        isNot(browseWordKey(
            prefix: 'John|1', versionCode: 'BGT', verse: 3, index: 5)),
      );
    });

    test('the same word on two version rows is two occurrences', () {
      expect(
        browseWordKey(prefix: 'John|1', versionCode: 'BGT', verse: 3, index: 2),
        isNot(browseWordKey(
            prefix: 'John|1', versionCode: 'KJV', verse: 3, index: 2)),
      );
    });

    // A pin outlives navigation, so without book and chapter in the key
    // a pin on John 1:3 word 2 would light up John 2:3 word 2 the moment
    // the reader turned the page — the marker pointing at a word nobody
    // chose, in a verse they had never seen.
    test('chapter is part of the key, so a pin cannot bleed across pages', () {
      expect(
        browseWordKey(prefix: browseKeyPrefix('John', 1), versionCode: 'BGT', verse: 3, index: 2),
        isNot(browseWordKey(
            prefix: browseKeyPrefix('John', 2), versionCode: 'BGT', verse: 3, index: 2)),
      );
    });

    test('book is part of the key too', () {
      expect(
        browseWordKey(prefix: browseKeyPrefix('John', 1), versionCode: 'BGT', verse: 3, index: 2),
        isNot(browseWordKey(
            prefix: browseKeyPrefix('Jude', 1), versionCode: 'BGT', verse: 3, index: 2)),
      );
    });
  });

  group('nothing is pinned until something is clicked', () {
    test('the empty focus is not pinned', () {
      expect(AnalysisFocus.empty.isPinned, isFalse);
      expect(AnalysisFocus.empty.pinnedKey, isNull);
    });

    test('hovering alone never pins', () {
      final f = AnalysisFocus.empty.withHover(a).withHover(b).withHover(null);
      expect(f.isPinned, isFalse);
    });

    test('unpinning when nothing is pinned is a no-op', () {
      expect(AnalysisFocus.empty.unpinned(), AnalysisFocus.empty);
    });
  });

  group('the pin is what stops hover destroying the pane', () {
    test('hover updates the pane while nothing is pinned', () {
      expect(
        AnalysisFocus.empty.acceptsHoverUpdate(shiftHeld: false),
        isTrue,
      );
    });

    test('a pin blocks hover updates', () {
      expect(
        AnalysisFocus.empty.withTap(a).acceptsHoverUpdate(shiftHeld: false),
        isFalse,
      );
    });

    test('Shift blocks hover updates on its own — BibleWorks bwh10a', () {
      expect(
        AnalysisFocus.empty.acceptsHoverUpdate(shiftHeld: true),
        isFalse,
      );
    });

    // Shift is a transient brake; the pin is a standing decision.
    // Releasing Shift must not quietly discard the pin.
    test('releasing Shift does not release the pin', () {
      final pinned = AnalysisFocus.empty.withTap(a);
      expect(pinned.acceptsHoverUpdate(shiftHeld: true), isFalse);
      expect(pinned.acceptsHoverUpdate(shiftHeld: false), isFalse);
      expect(pinned.isPinned, isTrue);
    });

    // The whole point: the pointer keeps moving across the text on its
    // way to the pane, and none of it changes the subject.
    test('the pointer may cross the whole line without changing the pin', () {
      var f = AnalysisFocus.empty.withTap(a);
      for (final k in ['John|1|BGT|3|3', 'John|1|BGT|3|4', b, null]) {
        f = f.withHover(k);
        expect(f.pinnedKey, a);
      }
    });
  });

  group('unpinning is always available and never traps', () {
    test('clicking the pinned word again releases it', () {
      final f = AnalysisFocus.empty.withTap(a);
      expect(f.withTap(a).isPinned, isFalse);
    });

    // The single most dangerous failure mode. This app is gated to
    // tablets and desktops, and on a tablet there is no hover at all —
    // a tap is the only way to look at anything. A pin that refused to
    // move would strand a touch reader on the first word they ever
    // touched, with the text apparently dead.
    test('clicking a DIFFERENT word moves the pin rather than being eaten',
        () {
      final f = AnalysisFocus.empty.withTap(a).withTap(b);
      expect(f.pinnedKey, b);
      expect(f.isPinned, isTrue);
    });

    test('tapWouldUnpin distinguishes release from move', () {
      final f = AnalysisFocus.empty.withTap(a);
      expect(f.tapWouldUnpin(a), isTrue);
      expect(f.tapWouldUnpin(b), isFalse);
      expect(AnalysisFocus.empty.tapWouldUnpin(a), isFalse);
    });

    test('unpinned() clears the pin and leaves the hover alone', () {
      final f = AnalysisFocus.empty.withTap(a).withHover(b);
      final out = f.unpinned();
      expect(out.isPinned, isFalse);
      expect(out.hoverKey, b);
    });

    test('a released pin lets hover drive the pane again', () {
      final f = AnalysisFocus.empty.withTap(a).unpinned();
      expect(f.acceptsHoverUpdate(shiftHeld: false), isTrue);
    });
  });

  group('marks', () {
    test('an untouched word is unmarked', () {
      expect(AnalysisFocus.empty.markFor(a), WordMark.none);
    });

    test('a search hit is marked when nothing else claims the word', () {
      expect(AnalysisFocus.empty.markFor(a, hit: true), WordMark.hit);
    });

    test('hover outranks a hit — the pointer is live, the hit is standing',
        () {
      final f = AnalysisFocus.empty.withHover(a);
      expect(f.markFor(a, hit: true), WordMark.hover);
    });

    // Hovering the pinned word must not blink its marker off: the pin is
    // the stronger claim, and the reader is checking it is still there.
    test('pin outranks hover on the same word', () {
      final f = AnalysisFocus.empty.withTap(a).withHover(a);
      expect(f.markFor(a), WordMark.pinned);
    });

    test('pin outranks a hit', () {
      final f = AnalysisFocus.empty.withTap(a);
      expect(f.markFor(a, hit: true), WordMark.pinned);
    });

    // Three live states on screen at once, each on a different word.
    test('pinned, hovered and hit can coexist and stay distinct', () {
      const c = 'John|1|BGT|3|9';
      final f = AnalysisFocus(pinnedKey: a, hoverKey: b);
      expect(f.markFor(a), WordMark.pinned);
      expect(f.markFor(b), WordMark.hover);
      expect(f.markFor(c, hit: true), WordMark.hit);
    });
  });

  group('value equality', () {
    test('two focuses on the same keys are equal', () {
      expect(const AnalysisFocus(pinnedKey: a, hoverKey: b),
          const AnalysisFocus(pinnedKey: a, hoverKey: b));
    });

    test('withHover on the same key returns the same value', () {
      final f = AnalysisFocus.empty.withHover(a);
      expect(f.withHover(a), f);
    });
  });

  // "If a reader cannot tell pinned from hovered they will not trust
  // it." That is a claim about pixels, so it is tested as one — against
  // every palette the app actually ships, because the app's single gold
  // accent (#C9A227) measures 1.54:1 on the paper theme's tan selection
  // fill and would have been an invisible marker for anyone reading in
  // 护眼纸质.
  group('the four treatments are mutually distinguishable', () {
    for (final (name, wb) in [
      ('light', WbColors.light),
      ('dark', WbColors.dark),
      ('paper', WbColors.paper),
    ]) {
      test('$name: no two marks render the same box', () {
        final seen = <BoxDecoration>[];
        for (final m in WordMark.values) {
          final d = wordMarkDecoration(m, wb);
          expect(seen, isNot(contains(d)),
              reason: '$name: $m renders identically to an earlier mark');
          seen.add(d);
        }
        expect(seen, hasLength(WordMark.values.length));
      });

      test('$name: only the pinned mark draws a visible border', () {
        for (final m in WordMark.values) {
          final side = (wordMarkDecoration(m, wb).border as Border).top;
          if (m == WordMark.pinned) {
            expect(side.color, wb.pinMark);
            expect(side.color.a, 1.0);
          } else {
            expect(side.color, Colors.transparent);
          }
        }
      });

      // A border that appeared on click would widen the word and reflow
      // the line under the reader's own pointer.
      test('$name: every mark reserves the same border width', () {
        for (final m in WordMark.values) {
          expect((wordMarkDecoration(m, wb).border as Border).top.width, 1.5);
        }
      });

      test('$name: the pin marker clears 3:1 against the fill it sits on',
          () {
        double lin(double c) =>
            c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
        double lum(Color c) =>
            0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
        final l1 = lum(wb.pinMark), l2 = lum(wb.selectionBg);
        final ratio = (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
        expect(ratio, greaterThanOrEqualTo(3.0),
            reason: '$name pin marker measures ${ratio.toStringAsFixed(2)}:1');
      });
    }
  });
}
