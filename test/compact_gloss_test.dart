/// 2026-08 (SeekSparks): guards the Strong's chip-label compactor.
///
/// The raw lexicon glosses are full prose. Rendered straight into a
/// word chip they clipped mid-abbreviation — the live Word Study panel
/// showed "a desolation (of surface), i" and "above, over, upon, or
/// against (yet always in…", which reads as a rendering bug rather
/// than a definition. Every case below is a real gloss taken from that
/// screenshot (Genesis 1:2).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/widgets/originals_sheet.dart';

void main() {
  group('compactGloss — Genesis 1:2 regressions', () {
    test('drops the parenthetical elaboration', () {
      expect(compactGloss('a desolation (of surface), i.e. desert'),
          'a desolation');
      expect(compactGloss('an abyss (as a surging mass of water), especially'),
          'an abyss');
      expect(compactGloss('the face (as the part that turns)'), 'the face');
      expect(compactGloss('the earth (at large, or partitively a land)'),
          'the earth');
    });

    test('cuts at "i.e." rather than clipping the abbreviation', () {
      expect(compactGloss('to exist, i.e. be or become'), 'to exist');
      expect(
          compactGloss('a vacuity, i.e. (superficially) an undistinguishable '
              'ruin'),
          'a vacuity');
      // The bug this replaces: a bare truncation left a dangling "i".
      expect(compactGloss('to exist, i.e. be or become'), isNot(endsWith(' i')));
    });

    test('keeps the first sense when senses are ; separated', () {
      expect(compactGloss('the dark; darkness; obscurity'), 'the dark');
    });

    test('long comma lists break on a word boundary, never mid-word', () {
      final s = compactGloss('above, over, upon, or against (yet always in '
          'this last relation with a downward aspect)');
      expect(s.length, lessThanOrEqualTo(29));
      expect(s, startsWith('above, over, upon'));
      // Must not end mid-word.
      expect(s.replaceAll('…', '').trim(), isNot(matches(r'\w-$')));
    });

    test('short glosses pass through untouched', () {
      expect(compactGloss('wind'), 'wind');
      expect(compactGloss('the dark'), 'the dark');
    });

    test('empty / whitespace input is safe', () {
      expect(compactGloss(''), '');
      expect(compactGloss('   '), '');
    });

    test('handles the Chinese gloss punctuation too', () {
      expect(compactGloss('荒废；空虚'), '荒废');
      expect(compactGloss('深渊（如涌动的水体）'), '深渊');
    });

    test('never returns a string longer than the cap', () {
      const long = 'a very long lexicon definition that simply keeps going on '
          'and on without any punctuation to break it up at all';
      expect(compactGloss(long).length, lessThanOrEqualTo(29));
    });
  });
}
