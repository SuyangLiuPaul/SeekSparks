/// bwh17, "Including Vowel Points in Hebrew Searches and Accents in
/// Greek" — `docs/PARITY-BACKLOG.md` §3.1.
///
/// The entry said the app had "a hardcoded asymmetry": Hebrew stripped,
/// Greek not. That was true when it was written and false four days
/// later — #321 folded both. What was actually missing is the CHOICE,
/// and these are its guards.
///
/// The failure this is really written against is not a wrong result, it
/// is a HALF-APPLIED switch: fold the corpus and not the query, or the
/// query and not the highlighter, and the search quietly finds nothing.
/// So the assertions are about the two sides agreeing, not about one
/// function's output.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/text_patterns.dart'
    show searchCorpusKey;
import 'package:seeksparks/utils/diacritics.dart' show foldDiacritics;
import 'package:seeksparks/utils/plain_search.dart';
import 'package:seeksparks/constants/ui_strings.dart'
    show uiStrings;
import 'package:seeksparks/utils/search_folding.dart';

void main() {
  // Genesis 1:1, pointed, as `assets/originals/genesis.json` holds it.
  const pointedCreated = 'בָּרָ֣א';
  const bareCreated = 'ברא';
  const accentedGod = 'θεός';
  const bareGod = 'θεος';

  tearDown(resetSearchFoldingForTest);

  group('the default is what #321 shipped', () {
    test('both scripts fold, and they fold the same way', () {
      // The asymmetry the backlog entry described. Asserted in both
      // directions so that reintroducing it on either side fails here.
      expect(searchIgnoresPointing, isTrue);
      expect(foldSearchMarks(pointedCreated), bareCreated);
      expect(foldSearchMarks(accentedGod), bareGod);
    });

    test('a pointed query reaches an unpointed corpus and back', () {
      // Aunty Rosa's search, which is why the fold exists: `ὁ θεός`
      // against a corpus set `ο θεος`.
      final corpus = searchCorpusKey('καὶ θεὸς ἦν ὁ λόγος');
      expect(plainSearchMatches(corpus, plainSearchSegments(
              foldSearchMarks('θεός').toLowerCase())),
          isTrue);
      final pointedCorpus = searchCorpusKey('בְּרֵאשִׁ֖ית בָּרָ֣א');
      expect(plainSearchMatches(pointedCorpus,
              plainSearchSegments(foldSearchMarks(bareCreated))),
          isTrue);
    });
  });

  group('turning it off makes the pointing count', () {
    test('the fold becomes the identity, for both scripts', () {
      setSearchIgnoresPointing(false);
      expect(foldSearchMarks(pointedCreated), pointedCreated);
      expect(foldSearchMarks(accentedGod), accentedGod);
      // And `foldDiacritics` itself is untouched — collation and
      // transliteration do not change because a reader wants a pointed
      // search.
      expect(foldDiacritics(pointedCreated), bareCreated);
    });

    test('two words that share consonants stop being one word', () {
      // The whole point of the setting. בָּרָא (created) and בָּרָה
      // (ate/chose) reduce to the same three consonants; a search that
      // cannot tell them apart cannot answer a question about
      // vocalisation.
      const created = 'בָּרָא';
      const ate = 'בָּרָה';
      expect(foldDiacritics(created), isNot(foldDiacritics(ate)),
          reason: 'the final letter differs, so the fold alone still '
              'separates these two — the test below is the one that '
              'needs the setting');
      setSearchIgnoresPointing(false);
      final corpus = searchCorpusKey(created);
      expect(plainSearchMatches(corpus, plainSearchSegments(created)),
          isTrue);
      expect(plainSearchMatches(corpus, plainSearchSegments(bareCreated)),
          isFalse,
          reason: 'with pointing on, the unpointed spelling is a '
              'different string and must not match');
    });

    test('both sides move together, which is the actual risk', () {
      // A half-applied switch is the defect this file exists for: the
      // corpus key and the query fold are two different functions in two
      // different files, and if only one of them honoured the setting
      // the search would return nothing at all.
      setSearchIgnoresPointing(false);
      final corpus = searchCorpusKey('καὶ θεὸς ἦν');
      expect(corpus.contains('θεὸς'), isTrue,
          reason: 'the corpus key kept its accents');
      expect(
          plainSearchMatches(
              corpus, plainSearchSegments(foldSearchMarks('θεὸς'))),
          isTrue,
          reason: 'and the query side kept them too, so they still meet');
    });
  });

  group('the generation counter', () {
    test('moves only on a real change', () {
      final start = searchFoldingGeneration;
      expect(setSearchIgnoresPointing(true), isFalse,
          reason: 'already true — nothing to invalidate');
      expect(searchFoldingGeneration, start);
      expect(setSearchIgnoresPointing(false), isTrue);
      expect(searchFoldingGeneration, greaterThan(start));
    });

    test('it exists because one cache holds folded text', () {
      // `MainProvider.searchKeys` compares against this. Without it a
      // reader who turns pointing on searches a corpus that is still
      // folded, finds nothing, and has no way to tell a stale cache from
      // a broken search.
      final before = searchCorpusKey(pointedCreated);
      setSearchIgnoresPointing(false);
      final after = searchCorpusKey(pointedCreated);
      expect(before, isNot(after),
          reason: 'if these were equal the cache would not need '
              'invalidating and this counter would be dead code');
    });
  });

  group('the aligned fold keeps its contract in both states', () {
    // The highlighter slices the ORIGINAL string by `sourceIndex`, so an
    // identity fold that returned a short index list would draw the mark
    // in the wrong place — or throw.
    void checkContract(String s) {
      final f = foldSearchMarksAligned(s);
      expect(f.sourceIndex.length, f.folded.length + 1,
          reason: 'one entry per folded char, plus the trailing length');
      expect(f.sourceIndex.last, s.length);
      for (var i = 0; i < f.folded.length; i++) {
        expect(f.sourceIndex[i], lessThan(s.length));
        expect(f.sourceIndex[i], greaterThanOrEqualTo(i == 0 ? 0 : 0));
      }
    }

    test('folding on', () {
      checkContract(pointedCreated);
      checkContract(accentedGod);
      checkContract('plain english');
    });

    test('folding off — the identity is still a FoldedText', () {
      setSearchIgnoresPointing(false);
      checkContract(pointedCreated);
      checkContract(accentedGod);
      checkContract('plain english');
      final f = foldSearchMarksAligned(pointedCreated);
      expect(f.folded, pointedCreated);
    });
  });

  test('the reader is told, in all three locales', () {
    for (final k in const [
      'searchIgnoresPointing',
      'searchIgnoresPointingSubtitle',
    ]) {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final v = uiStrings[k]?[locale];
        expect(v, isNotNull, reason: '$k [$locale]');
        expect((v as String).trim(), isNotEmpty, reason: '$k [$locale]');
      }
    }
  });
}
