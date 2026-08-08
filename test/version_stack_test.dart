// 2026-08-08 (task #288): the Browse stack's ordered model.
//
// The order is the part that had no test because it had no pointer
// control — `p bsb kjvs lxxwh` set it, the checkbox picker silently
// re-sorted it into registry order, and nothing asserted which of those
// two was right.

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/version_stack.dart';

void main() {
  group('normaliseComparisons', () {
    test('keeps the reader\'s order rather than the registry\'s', () {
      // `lxxwh` sits before `bsb` in the catalog; the reader put it last.
      expect(normaliseComparisons(['bsb', 'lxxwh'], 'cuvs-yhwh'),
          ['bsb', 'lxxwh']);
    });

    test('drops the reading version — it is column one, not a comparison',
        () {
      expect(normaliseComparisons(['bsb', 'kjv', 'lxxwh'], 'kjv'),
          ['bsb', 'lxxwh']);
    });

    test('de-duplicates, keeping the first position', () {
      expect(normaliseComparisons(['bsb', 'lxxwh', 'bsb'], 'kjv'),
          ['bsb', 'lxxwh']);
    });

    test('drops a code this build cannot load', () {
      expect(normaliseComparisons(['bsb', 'not-a-version'], 'kjv'), ['bsb']);
    });

    // The v1.6.64 crash in miniature: a stack persisted before a version
    // was retired must not carry the dead code forward.
    test('maps a retired code to its successor', () {
      expect(normaliseComparisons(['cuv-yhwd'], 'kjv'), ['cuvs-yhwh']);
    });

    test('a retired code that maps ONTO the reading version disappears', () {
      expect(normaliseComparisons(['cuv-yhwd'], 'cuvs-yhwh'), isEmpty);
    });
  });

  group('displayStack', () {
    test('is the reading version, then the comparisons', () {
      expect(displayStack(['bsb', 'lxxwh'], 'kjv'), ['kjv', 'bsb', 'lxxwh']);
    });
  });

  group('toggleComparison', () {
    test('adds at the END, where `d nas` puts it', () {
      expect(toggleComparison(['bsb', 'lxxwh'], 'kjvs', 'kjv'),
          ['bsb', 'lxxwh', 'kjvs']);
    });

    test('removes without disturbing the rest of the order', () {
      expect(toggleComparison(['bsb', 'lxxwh', 'kjvs'], 'lxxwh', 'kjv'),
          ['bsb', 'kjvs']);
    });

    test('re-adding sends it to the end, not back to where it was', () {
      final once = toggleComparison(['bsb', 'lxxwh', 'kjvs'], 'bsb', 'kjv');
      expect(toggleComparison(once, 'bsb', 'kjv'), ['lxxwh', 'kjvs', 'bsb']);
    });

    test('adding the reading version is a no-op, not a duplicate column', () {
      expect(toggleComparison(['bsb'], 'kjv', 'kjv'), ['bsb']);
    });
  });

  group('moveComparison', () {
    test('moves a row down', () {
      expect(moveComparison(['a', 'b', 'c'], 0, 1), ['b', 'a', 'c']);
    });

    test('moves a row up', () {
      expect(moveComparison(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    });

    test('moves a row to the end', () {
      expect(moveComparison(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    });

    test('a move onto itself changes nothing', () {
      expect(moveComparison(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
    });

    test('an out-of-range source is ignored rather than throwing', () {
      expect(moveComparison(['a', 'b'], 5, 0), ['a', 'b']);
    });

    test('a destination past the end clamps to the end', () {
      expect(moveComparison(['a', 'b'], 0, 9), ['b', 'a']);
    });

    test('does not mutate the list it was given', () {
      final original = ['a', 'b', 'c'];
      moveComparison(original, 0, 2);
      expect(original, ['a', 'b', 'c']);
    });
  });
}
