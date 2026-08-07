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
  group('the five treatments are mutually distinguishable', () {
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

  // ── The same original word, lit everywhere it landed ───────────────
  //
  // BibleWorks does not do this. Its Browse window highlights search
  // hits, differences between same-language versions, and the reader's
  // own selection — nothing lexical (bwh11). Its answer to "where else
  // is this word" is the Use Tab (bwh10l): a LIST in a pane, scoped to
  // the current book, and its own help concedes it "is currently not
  // supported for double byte languages like Chinese" — which is the
  // reader this app exists to serve. Colour in the text answers the
  // question a list cannot. Not "where else does this occur", but
  // "which word over there is THIS word", across four translations at
  // once, without reading any of them.
  group('siblingStrongs — what lights up', () {
    test('the subject number lights while the subject is on screen', () {
      expect(
        siblingStrongs(
            subjectKey: a, subjectStrongs: 'G1096', keyPrefix: 'John|1'),
        'G1096',
      );
    });

    test('nothing under study lights nothing', () {
      expect(
        siblingStrongs(
            subjectKey: null, subjectStrongs: 'G1096', keyPrefix: 'John|1'),
        '',
      );
    });

    // 62,795 word slots in the bundled tagged corpus carry no number at
    // all. If an untagged subject lit "its matches", every one of them
    // would light at once.
    test('an untagged subject lights nothing', () {
      expect(
        siblingStrongs(subjectKey: a, subjectStrongs: '', keyPrefix: 'John|1'),
        '',
      );
    });

    // A pin outlives navigation: the subject can name a chapter that is
    // no longer printed, and lighting words there would put colour on
    // the page with nothing visible to explain it.
    test('a subject in another chapter lights nothing', () {
      expect(
        siblingStrongs(
            subjectKey: a, subjectStrongs: 'G1096', keyPrefix: 'John|2'),
        '',
      );
    });

    test('a subject in another book lights nothing', () {
      expect(
        siblingStrongs(
            subjectKey: a, subjectStrongs: 'G1096', keyPrefix: 'Mark|1'),
        '',
      );
    });

    // 'John|1' is a prefix of 'John|11', so a bare startsWith would leak
    // chapter 1 into chapters 10 through 19.
    test('chapter 1 does not leak into chapter 11', () {
      expect(
        siblingStrongs(
            subjectKey: 'John|11|BGT|3|2',
            subjectStrongs: 'G1096',
            keyPrefix: 'John|1'),
        '',
      );
      expect(
        siblingStrongs(
            subjectKey: 'John|1|BGT|3|2',
            subjectStrongs: 'G1096',
            keyPrefix: 'John|11'),
        '',
      );
    });
  });

  group('markFor — the echoes', () {
    const lit = AnalysisFocus(hoverKey: a, litStrongs: 'G1096');

    test('another word carrying the number is an echo', () {
      expect(lit.markFor(b, strongs: 'G1096'), WordMark.sibling);
    });

    test('a word carrying a different number is not', () {
      expect(lit.markFor(b, strongs: 'G846'), WordMark.none);
    });

    // The empty string must never match the empty string, or every
    // untagged word on screen would echo every other one.
    test('an untagged word never echoes', () {
      expect(lit.markFor(b, strongs: ''), WordMark.none);
    });

    test('the subject is drawn as the subject, not as its own echo', () {
      expect(lit.markFor(a, strongs: 'G1096'), WordMark.hover);
    });

    test('the pinned subject keeps its pin', () {
      const f = AnalysisFocus(pinnedKey: a, hoverKey: a, litStrongs: 'G1096');
      expect(f.markFor(a, strongs: 'G1096'), WordMark.pinned);
    });

    // An echo is a live signal; a hit is standing state left by the last
    // search. Losing the echo under a hit would break the one sequence
    // the feature exists for — search a word, then study it.
    test('an echo outranks a search hit', () {
      expect(lit.markFor(b, strongs: 'G1096', hit: true), WordMark.sibling);
    });

    test('a hit that is not an echo stays a hit', () {
      expect(lit.markFor(b, strongs: 'G846', hit: true), WordMark.hit);
    });

    test('the pointer outranks an echo', () {
      const f = AnalysisFocus(hoverKey: b, litStrongs: 'G1096');
      expect(f.markFor(b, strongs: 'G1096'), WordMark.hover);
    });
  });

  // Found by reasoning about the data flow, not by looking at a screen.
  //
  // The Browse window threads the LATCHED subject down as [hoverKey],
  // and each word overrides it with withHover only while the pointer is
  // physically inside that word. Thread the raw pointer position instead
  // and the marks blink: between two words the pointer is in a 5px gap,
  // no word is hovered, and the subject — which still supplies
  // litStrongs — matches its own number and drops to an echo. Sweeping
  // along a line would flash every word green on the way out of it.
  group('the subject does not blink when the pointer is between words', () {
    test('the latched subject holds its mark with no pointer on it', () {
      const threaded = AnalysisFocus(hoverKey: a, litStrongs: 'G1096');
      expect(threaded.markFor(a, strongs: 'G1096'), WordMark.hover);
    });

    test('threading the pointer alone would have flashed it green', () {
      // The rejected design, kept as a test so the reasoning survives
      // the next person who wonders why the subject is threaded at all.
      const pointerOnly = AnalysisFocus(litStrongs: 'G1096');
      expect(pointerOnly.markFor(a, strongs: 'G1096'), WordMark.sibling);
    });

    test('a word under the pointer still lights while the pane is held', () {
      const held = AnalysisFocus(pinnedKey: a, hoverKey: a, litStrongs: 'G1096');
      expect(held.withHover(b).markFor(b, strongs: 'G846'), WordMark.hover);
      expect(held.withHover(b).markFor(a, strongs: 'G1096'), WordMark.pinned);
    });
  });

  // The echo fill is a claim about pixels, so it is measured. Note what
  // these deliberately do NOT assert: that the echo is separable from
  // the hover fill by LUMINANCE. It is not — the two sit within 1.1:1 of
  // each other, because both are quiet washes under body text and a
  // darker one would fight the scripture. They differ in hue, and hue is
  // exactly what a red-green colour-blind reader cannot depend on, which
  // is why wordMarkUnderline carries the same distinction on a second,
  // non-colour channel.
  group('the echo fill', () {
    for (final (name, wb) in [
      ('light', WbColors.light),
      ('dark', WbColors.dark),
      ('paper', WbColors.paper),
    ]) {
      test('$name: scripture stays readable on it', () {
        final r = _ratio(wb.text, wb.siblingBg);
        expect(r, greaterThanOrEqualTo(4.5),
            reason: '$name: text on the echo fill measures '
                '${r.toStringAsFixed(2)}:1');
      });

      // A translucent fill composites against whatever is behind it, so
      // the same echo would render as two different colours depending on
      // whether its row happened to be the selected one — the defect
      // that made the version pill meaningless.
      test('$name: it is opaque', () {
        expect(wb.siblingBg.a, 1.0);
      });

      test('$name: it is visible against the page', () {
        final r = _ratio(wb.siblingBg, wb.paneBg);
        expect(r, greaterThan(1.2),
            reason: '$name: echo fill measures ${r.toStringAsFixed(3)}:1 '
                'against the pane');
      });

      // Green, not a paler blue — it must not read as the hover wash
      // turned down.
      test('$name: it is a different hue from the hover fill', () {
        final gap = _hueGap(wb.siblingBg, wb.selectionBg);
        expect(gap, greaterThan(45),
            reason: '$name: only ${gap.toStringAsFixed(0)}° of hue between '
                'the echo and the hover fill');
      });
    }
  });

  group('wordMarkUnderline', () {
    test('only the reader\'s own subject is underlined', () {
      expect(wordMarkUnderline(WordMark.hover), TextDecoration.underline);
      expect(wordMarkUnderline(WordMark.pinned), TextDecoration.underline);
      for (final m in [WordMark.none, WordMark.hit, WordMark.sibling]) {
        expect(wordMarkUnderline(m), TextDecoration.none, reason: '$m');
      }
    });

    // The colour-blind guarantee, stated as a test: an echo and the word
    // under the pointer must differ on something that is not hue.
    test('an echo is separable from the pointer without seeing colour', () {
      expect(wordMarkUnderline(WordMark.sibling),
          isNot(wordMarkUnderline(WordMark.hover)));
    });
  });
}

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;

double _lum(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double _ratio(Color x, Color y) {
  final a = _lum(x), b = _lum(y);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

/// The smaller of the two angles between two hues, in degrees.
double _hueGap(Color x, Color y) {
  final d = (HSVColor.fromColor(x).hue - HSVColor.fromColor(y).hue).abs();
  return d > 180 ? 360 - d : d;
}
