// 2026-08-08 (task #288): the Browse stack's ordered model.
//
// 2026-09-08: every `'bsb'` fixture below became `'bsb-yhwh'` (21 of
// them). Nothing here is ABOUT the BSB — these are order, dedup and
// toggle semantics, and they need a code that survives
// `loadableVersions` unchanged so the assertion reads as an ordering
// claim. `bsb` stopped being one when it was hidden that day and grew
// a successor row, which turned every expectation into a silent test of
// the successor table instead. `bsb-yhwh` is the edition that replaced
// it and maps to itself.
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
      // 2026-09-08: the pair was `['bsb', 'lxxwh']` and is now
      // `['lxxwh', 'bsb-yhwh']` — FLIPPED, not just renamed. `bsb` sat
      // before `lxxwh` in the catalog, so putting `lxxwh` last was the
      // reader disagreeing with the registry; `bsb-yhwh` sits AFTER
      // `lxxwh`, so keeping that same pair would have asserted an order
      // the registry would have produced anyway and this test would
      // have passed on a re-sorting implementation.
      expect(normaliseComparisons(['lxxwh', 'bsb-yhwh'], 'cuvs-yhwh'),
          ['lxxwh', 'bsb-yhwh']);
    });

    test('drops the reading version — it is column one, not a comparison',
        () {
      expect(normaliseComparisons(['bsb-yhwh', 'kjv', 'lxxwh'], 'kjv'),
          ['bsb-yhwh', 'lxxwh']);
    });

    test('de-duplicates, keeping the first position', () {
      expect(normaliseComparisons(['bsb-yhwh', 'lxxwh', 'bsb-yhwh'], 'kjv'),
          ['bsb-yhwh', 'lxxwh']);
    });

    test('drops a code this build cannot load', () {
      expect(normaliseComparisons(['bsb-yhwh', 'not-a-version'], 'kjv'),
          ['bsb-yhwh']);
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
      expect(displayStack(['bsb-yhwh', 'lxxwh'], 'kjv'),
          ['kjv', 'bsb-yhwh', 'lxxwh']);
    });
  });

  group('toggleComparison', () {
    test('adds at the END, where `d nas` puts it', () {
      expect(toggleComparison(['bsb-yhwh', 'lxxwh'], 'kjvs', 'kjv'),
          ['bsb-yhwh', 'lxxwh', 'kjvs']);
    });

    test('removes without disturbing the rest of the order', () {
      expect(toggleComparison(['bsb-yhwh', 'lxxwh', 'kjvs'], 'lxxwh', 'kjv'),
          ['bsb-yhwh', 'kjvs']);
    });

    test('re-adding sends it to the end, not back to where it was', () {
      final once =
          toggleComparison(['bsb-yhwh', 'lxxwh', 'kjvs'], 'bsb-yhwh', 'kjv');
      expect(toggleComparison(once, 'bsb-yhwh', 'kjv'),
          ['lxxwh', 'kjvs', 'bsb-yhwh']);
    });

    test('adding the reading version is a no-op, not a duplicate column', () {
      expect(toggleComparison(['bsb-yhwh'], 'kjv', 'kjv'), ['bsb-yhwh']);
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
