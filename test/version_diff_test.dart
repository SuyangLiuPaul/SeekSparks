/// bwh30 difference highlighting — the pure core.
///
/// Everything here is string and set work, so it is tested without a
/// widget tree. What is deliberately NOT asserted: the ink. The colour
/// role and the underline live in the theme and the Browse pane, and a
/// test that pinned them would only re-state the palette.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/version_diff.dart';

List<String> norms(String s) =>
    [for (final t in versionDiffTokens([s])) t.norm];

void main() {
  group('lcsDifferences', () {
    test('identical rows differ nowhere', () {
      final (a, b) = lcsDifferences(
          norms('In the beginning God created'),
          norms('In the beginning God created'));
      expect(a, isEmpty);
      expect(b, isEmpty);
    });

    test('one substituted word marks one token on each side', () {
      // KJV "heaven" against NASB "heavens" — the classic pair, and the
      // reason the mark has to be per WORD and not per verse.
      final a = norms('God created the heaven and the earth');
      final b = norms('God created the heavens and the earth');
      final (aOut, bOut) = lcsDifferences(a, b);
      expect(aOut.map((i) => a[i]), ['heaven']);
      expect(bOut.map((i) => b[i]), ['heavens']);
    });

    test('an insertion marks only the inserted side', () {
      final a = norms('the LORD said');
      final b = norms('and the LORD said');
      final (aOut, bOut) = lcsDifferences(a, b);
      expect(aOut, isEmpty);
      expect(bOut.map((i) => b[i]), ['and']);
    });

    test('a reordering is seen, which is why LCS and not set difference', () {
      // Same vocabulary, different arrangement. bwh30's other method,
      // Word Occurrence, reports NOTHING here; that is the whole reason
      // its own help says to prefer this one.
      final a = norms('God the LORD');
      final b = norms('the LORD God');
      final (aOut, bOut) = lcsDifferences(a, b);
      expect(aOut, isNotEmpty);
      expect(bOut, isNotEmpty);
    });

    test('an empty side marks the whole of the other', () {
      final b = norms('one two three');
      final (aOut, bOut) = lcsDifferences(const [], b);
      expect(aOut, isEmpty);
      expect(bOut, {0, 1, 2});
    });

    test('Chinese is compared per character, the house tokenisation', () {
      final a = norms('耶和华说');
      final b = norms('雅伟说');
      expect(a, ['耶', '和', '华', '说']);
      final (aOut, bOut) = lcsDifferences(a, b);
      expect(aOut.map((i) => a[i]), ['耶', '和', '华']);
      expect(bOut.map((i) => b[i]), ['雅', '伟']);
    });
  });

  group('versionDiffMarks', () {
    test('fewer than two rows is not a comparison', () {
      expect(versionDiffMarks([norms('anything')]), [<int>{}]);
      expect(versionDiffMarks(const []), isEmpty);
    });

    test('two rows: the base is marked exactly where the other is not', () {
      final a = norms('the heaven');
      final b = norms('the heavens');
      final marks = versionDiffMarks([a, b]);
      expect(marks[0].map((i) => a[i]), ['heaven']);
      expect(marks[1].map((i) => b[i]), ['heavens']);
    });

    test('three rows: the base is marked only where NO other row agrees', () {
      // The documented departure from BibleWorks. `b` carries "alpha",
      // `c` does not — so the base's "alpha" is shared with somebody and
      // stays clean, while "gamma", which nobody else has, is marked.
      // BibleWorks would union the two comparisons and mark both.
      final base = norms('alpha gamma');
      final b = norms('alpha delta');
      final c = norms('beta delta');
      final marks = versionDiffMarks([base, b, c]);
      expect(marks[0].map((i) => base[i]), ['gamma']);
      expect(marks[1].map((i) => b[i]), ['delta']);
    });

    test('rows identical to the base are marked nowhere, base included', () {
      final marks = versionDiffMarks([
        norms('same words here'),
        norms('same words here'),
        norms('same words here'),
      ]);
      expect(marks.every((m) => m.isEmpty), isTrue);
    });
  });

  group('comparableVersionGroups', () {
    test('a lone edition in its language is not a group', () {
      expect(comparableVersionGroups(['kjv']), isEmpty);
    });

    test('English pairs, and the group keeps display order', () {
      final g = comparableVersionGroups(['nasb', 'kjv', 'bsb']);
      expect(g.keys, ['en']);
      expect(g['en'], ['nasb', 'kjv', 'bsb']);
    });

    test('languages are partitioned, and a lone language is dropped', () {
      // The Browse pane's usual stack. `lxxwh` is the only Greek on
      // screen, so Greek forms no group and is never diffed against the
      // English beside it.
      final g = comparableVersionGroups(
          ['lxxwh', 'bsb', 'nasb', 'kjv', 'cuvs-yhwh', 'biblexg-v2']);
      expect(g.keys.toSet(), {'en', 'zh-Hans'});
      expect(g['en'], ['bsb', 'nasb', 'kjv']);
      expect(g['zh-Hans'], ['cuvs-yhwh', 'biblexg-v2']);
    });

    test('简体 and 繁體 are different languages and never compared', () {
      // A true diff and a useless one: nearly every character differs by
      // SCRIPT, which says nothing about the translation.
      final g = comparableVersionGroups(['cuvs-yhwh', 'cuvs-yhwh-tr']);
      expect(g, isEmpty);
    });

    test('the originals pseudo-codes are dropped, not pooled', () {
      // `wtt` and `bgt` are assembled from assets/originals/ rather than
      // loaded from the catalog. Pooling them under an "unknown"
      // language would diff Hebrew against Greek.
      final g = comparableVersionGroups(['wtt', 'bgt']);
      expect(g, isEmpty);
    });
  });

  group('versionDiffTokens', () {
    test('offsets are relative to the unit, not to the row', () {
      final t = versionDiffTokens(['God said', 'let there']);
      expect(t.map((x) => (x.unit, x.norm)),
          [(0, 'god'), (0, 'said'), (1, 'let'), (1, 'there')]);
      // 'let' starts at 0 of ITS OWN string — the renderer holds that
      // string and nothing else, so a row-wide offset would be unusable.
      expect(t[2].start, 0);
      expect(t[3].start, 4);
    });

    test('an empty unit still occupies its index', () {
      // Notes and versification markers are emptied rather than dropped
      // so that unit indices keep matching the renderer's walk.
      final t = versionDiffTokens(['a', '', 'b']);
      expect(t.map((x) => x.unit), [0, 2]);
    });
  });

  group('mergedMarkSpans', () {
    test('adjacent marked tokens become one span', () {
      // Without this a four-character Chinese phrase draws four
      // underlines with hairline gaps, which reads as damage.
      final t = versionDiffTokens(['耶和华说']);
      final spans = mergedMarkSpans(t, {0, 1, 2}, 0);
      expect(spans, [(start: 0, end: 3)]);
    });

    test('a gap in the marks is a gap in the spans', () {
      final t = versionDiffTokens(['one two three']);
      final spans = mergedMarkSpans(t, {0, 2}, 0);
      expect(spans, [(start: 0, end: 3), (start: 8, end: 13)]);
    });

    test('only the requested unit is reported', () {
      final t = versionDiffTokens(['alpha', 'beta']);
      expect(mergedMarkSpans(t, {0, 1}, 1), [(start: 0, end: 4)]);
    });
  });

  group('sliceByMarks', () {
    test('no marks is one unmarked run', () {
      expect(sliceByMarks(0, 5, const []),
          [(start: 0, end: 5, marked: false)]);
    });

    test('a mark inside the range splits it in three', () {
      expect(sliceByMarks(0, 10, [(start: 3, end: 6)]), [
        (start: 0, end: 3, marked: false),
        (start: 3, end: 6, marked: true),
        (start: 6, end: 10, marked: false),
      ]);
    });

    test('a mark straddling the range is clipped to it', () {
      // The search highlighter cuts the same string on its own
      // boundaries, so a difference span routinely begins before the
      // piece being drawn and ends after it.
      expect(sliceByMarks(4, 8, [(start: 2, end: 12)]),
          [(start: 4, end: 8, marked: true)]);
    });

    test('marks entirely outside the range are ignored', () {
      expect(sliceByMarks(4, 8, [(start: 0, end: 4), (start: 8, end: 9)]),
          [(start: 4, end: 8, marked: false)]);
    });

    test('the pieces tile the range exactly, in order', () {
      final out = sliceByMarks(2, 20, [(start: 5, end: 7), (start: 11, end: 15)]);
      expect(out.first.start, 2);
      expect(out.last.end, 20);
      for (var i = 1; i < out.length; i++) {
        expect(out[i].start, out[i - 1].end);
      }
    });
  });
}
