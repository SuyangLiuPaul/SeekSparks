import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/phrase_match.dart';
import 'package:seeksparks/utils/search_highlight.dart' show HighlightSpan;

/// Build an index over [corpus] with `corpus[0]` as the base verse
/// unless told otherwise. Keeps the tests about the matching rules.
PhraseMatchIndex _index(
  List<String> corpus, {
  int base = 0,
  int length = 3,
  int gap = 0,
  Set<int>? scope,
}) =>
    buildPhraseMatchIndex(
      corpus: corpus,
      baseIndex: base,
      phraseLength: length,
      maxGap: gap,
      scope: scope,
    );

/// The corpus indices that matched at all, with every phrase enabled.
Set<int> _matchedVerses(PhraseMatchIndex ix) =>
    {for (final h in ix.hits) h.verseIndex};

Set<int> _allPhrases(PhraseMatchIndex ix) =>
    {for (var i = 0; i < ix.phrases.length; i++) i};

void main() {
  group('phraseTokens', () {
    test('splits English on punctuation and lower-cases', () {
      expect(
        [for (final t in phraseTokens('In the beginning, God created.'))
          t.text],
        ['in', 'the', 'beginning', 'god', 'created'],
      );
    });

    test('reports the range each token occupies', () {
      const text = 'In the beginning';
      final toks = phraseTokens(text);
      expect(text.substring(toks[2].start, toks[2].end), 'beginning');
      expect(text.substring(toks[0].start, toks[2].end), 'In the beginning');
    });

    test('keeps an apostrophe inside a word but not around it', () {
      expect([for (final t in phraseTokens("God's 'own'")) t.text],
          ["god's", 'own']);
    });

    test('emits ONE token per Han character, not bigrams', () {
      // This is the point of departure from related_verses.dart, which
      // emits 起初/初神/神创… for the same string.
      expect(
        [for (final t in phraseTokens('起初神创造')) t.text],
        ['起', '初', '神', '创', '造'],
      );
    });

    test('keeps Greek and pointed Hebrew as single tokens', () {
      expect([for (final t in phraseTokens('ἐν ἀρχῇ ἦν')) t.text],
          ['ἐν', 'ἀρχῇ', 'ἦν']);
      expect(phraseTokens('בְּרֵאשִׁ' 'ית'), hasLength(1));
    });
  });

  group('defaultPhraseLength', () {
    test('three words for an alphabetic verse', () {
      expect(defaultPhraseLength('In the beginning God created'), 3);
    });

    test('four characters for a Chinese verse', () {
      expect(defaultPhraseLength('起初神创造天地'), 4);
    });

    test('follows the majority when the verse is mixed', () {
      expect(defaultPhraseLength('起初神创造天地 in the beginning'), 4);
      expect(defaultPhraseLength('神 in the beginning God created heaven'), 3);
    });

    test('falls back to three when there is nothing to count', () {
      expect(defaultPhraseLength('... --- ...'), 3);
    });
  });

  group('exact matching (gap 0)', () {
    test('finds a verbatim run and nothing else', () {
      final ix = _index([
        'alpha beta gamma delta',
        'nothing here at all',
        'before alpha beta gamma after',
        'gamma beta alpha reversed',
        'alpha and beta and gamma spread out',
      ]);
      expect(_matchedVerses(ix), {2});
    });

    test('a reordered phrase is not a phrase', () {
      final ix = _index(['alpha beta gamma', 'gamma beta alpha']);
      expect(ix.hits, isEmpty);
    });

    test('an inserted word breaks the phrase at gap 0', () {
      final ix = _index(['alpha beta gamma', 'alpha beta X gamma']);
      expect(ix.hits, isEmpty);
    });

    test('punctuation between words does not count as a gap', () {
      final ix = _index(['alpha beta gamma', 'alpha, beta -- gamma!']);
      expect(_matchedVerses(ix), {1});
    });

    test('the base verse never matches itself', () {
      final ix = _index(['alpha beta gamma', 'alpha beta gamma']);
      expect(_matchedVerses(ix), {1});
      expect(_matchedVerses(_index(
        ['alpha beta gamma', 'alpha beta gamma'],
        base: 1,
      )), {0});
    });

    test('retries from a later occurrence of the first word', () {
      // alpha@0 leads nowhere; the match starts at alpha@2.
      final ix = _index(['alpha beta gamma', 'alpha x alpha beta gamma']);
      expect(_matchedVerses(ix), {1});
    });

    test('backtracks rather than committing to the first candidate', () {
      // Two candidates for 'b' sit inside the window. Taking the nearer
      // one (char 2) strands 'c' out of reach; the match is real via the
      // second (char 4). A greedy matcher reports nothing here.
      const verse = 'a b b x y c';
      final ix = _index(['a b c', verse], gap: 2);
      expect(_matchedVerses(ix), {1});
      expect(ix.hits.single.ranges, [0, 1, 4, 5, 10, 11]);
    });
  });

  group('the gap — inserted words', () {
    test('one inserted word needs gap 1', () {
      const corpus = ['alpha beta gamma', 'alpha beta X gamma'];
      expect(_index(corpus, gap: 0).hits, isEmpty);
      expect(_matchedVerses(_index(corpus, gap: 1)), {1});
    });

    test('two inserted words need gap 2', () {
      const corpus = ['alpha beta gamma', 'alpha beta X Y gamma'];
      expect(_index(corpus, gap: 1).hits, isEmpty);
      expect(_matchedVerses(_index(corpus, gap: 2)), {1});
    });

    test('the gap bounds EACH step and is not a budget', () {
      // Two separate one-word insertions. A total budget of 1 would
      // reject this; bwh51 says "maximum SINGLE gap", so gap 1 takes it.
      final ix = _index(
        ['alpha beta gamma', 'alpha X beta Y gamma'],
        gap: 1,
      );
      expect(_matchedVerses(ix), {1});
    });
  });

  group('the gap — a dropped word', () {
    test('an interior word may be dropped once the gap is open', () {
      const corpus = ['alpha beta gamma', 'zero alpha gamma end'];
      expect(_index(corpus, gap: 0).hits, isEmpty);
      expect(_matchedVerses(_index(corpus, gap: 1)), {1});
    });

    test('the FIRST word may not be dropped', () {
      // Otherwise a three-word phrase silently answers as a two-word
      // one, and every "beta gamma" in the Bible comes back.
      final ix = _index(['alpha beta gamma', 'zero beta gamma end'], gap: 3);
      expect(ix.hits, isEmpty);
    });

    test('the LAST word may not be dropped', () {
      final ix = _index(['alpha beta gamma', 'zero alpha beta end'], gap: 3);
      expect(ix.hits, isEmpty);
    });

    test('only ONE word may be dropped', () {
      final ix = _index(
        ['alpha beta gamma delta epsilon', 'alpha delta epsilon'],
        length: 5,
        gap: 3,
      );
      expect(ix.hits, isEmpty);
    });

    test('a two-word phrase has no interior, so nothing can drop', () {
      final ix = _index(['alpha beta', 'alpha X'], length: 2, gap: 3);
      expect(ix.hits, isEmpty);
      expect(ix.allowsDrop, isFalse);
    });
  });

  group('occurrences', () {
    test('counts non-overlapping instances within one verse', () {
      final ix = _index(['alpha beta gamma', 'alpha beta gamma alpha beta gamma']);
      expect(ix.hits.single.occurrences, 2);
      expect(ix.phrases.single.occurrences, 2);
      expect(ix.phrases.single.verseCount, 1);
    });

    test('an overlapping run is one instance, then the next', () {
      final ix = _index(['aa bb', 'aa bb aa bb'], length: 2);
      expect(ix.hits.single.occurrences, 2);
    });

    test('verseCount counts verses and occurrences counts instances', () {
      final ix = _index([
        'alpha beta gamma',
        'alpha beta gamma',
        'alpha beta gamma and again alpha beta gamma',
      ]);
      expect(ix.phrases.single.verseCount, 2);
      expect(ix.phrases.single.occurrences, 3);
    });
  });

  group('the phrases themselves', () {
    test('every overlapping window becomes a phrase', () {
      final ix = _index(['alpha beta gamma delta']);
      expect([for (final p in ix.phrases) p.display],
          ['alpha beta gamma', 'beta gamma delta']);
    });

    test('display keeps the base verse original case and punctuation', () {
      final ix = _index(['In the beginning, God created']);
      expect(ix.phrases.first.display, 'In the beginning');
      expect(ix.phrases[1].display, 'the beginning, God');
      expect(ix.phrases.first.words, ['in', 'the', 'beginning']);
    });

    test('a repeated window is searched for once', () {
      final ix = _index(['a b c x a b c']);
      final displays = [for (final p in ix.phrases) p.words.join(' ')];
      expect(displays.toSet(), hasLength(displays.length));
      expect(displays, contains('a b c'));
    });

    test('a verse shorter than the phrase yields nothing but says so', () {
      final ix = _index(['two words', 'two words here'], length: 3);
      expect(ix.phrases, isEmpty);
      expect(ix.isEmpty, isTrue);
      expect(ix.baseTokenCount, 2);
      expect(ix.phraseLength, 3);
    });

    test('phrase length and gap are clamped to what the tool supports', () {
      final ix = _index(['a b c d'], length: 99, gap: 99);
      expect(ix.phraseLength, kPhraseLengthMax);
      expect(ix.maxGap, kPhraseGapMax);
    });
  });

  group('Chinese', () {
    test('matches a character run in order', () {
      final ix = _index(
        ['起初神创造天地', '论到起初神创造的事'],
        length: 4,
      );
      expect(_matchedVerses(ix), {1});
    });

    test('punctuation is transparent, unlike related_verses bigrams', () {
      // 天地。神说 tokenizes to 天 地 神 说 — the 。 costs no position, so
      // 天地神 IS a phrase here. related_verses.dart deliberately refuses
      // to bridge that boundary because 地神 would be an invented WORD;
      // a phrase crossing a sentence break is the ordinary case.
      final ix = _index(['天地。神说', '天地神说'], length: 3);
      expect([for (final p in ix.phrases) p.words.join()],
          ['天地神', '地神说']);
      expect(_matchedVerses(ix), {1});
    });

    test('a reordered character run is not a match', () {
      final ix = _index(['起初神创', '创神初起'], length: 4);
      expect(ix.hits, isEmpty);
    });
  });

  group('highlighting', () {
    test('marks only the matched tokens, not the word bridged over', () {
      final ix = _index(
        ['alpha beta gamma', 'alpha beta SKIP gamma'],
        gap: 1,
      );
      const text = 'alpha beta SKIP gamma';
      final spans = highlightPhraseRanges(text, ix.hits.single.ranges);
      final marked = [for (final s in spans) if (s.isHit) s.text];
      // Two runs, because SKIP is dark between them — which is what
      // makes a gapped match look different from an exact one.
      expect(marked, ['alpha beta', 'gamma']);
      expect(spans.map((s) => s.text).join(), text);
    });

    test('adjacent matched words read as one run, not as boxed words', () {
      final ix = _index(['alpha beta gamma', 'x alpha beta gamma y']);
      final spans = highlightPhraseRanges(
          'x alpha beta gamma y', ix.hits.single.ranges);
      expect([for (final s in spans) if (s.isHit) s.text],
          ['alpha beta gamma']);
    });

    test('a dropped word leaves only the words that were there', () {
      final ix = _index(['alpha beta gamma', 'alpha gamma'], gap: 1);
      final spans = highlightPhraseRanges('alpha gamma', ix.hits.single.ranges);
      expect([for (final s in spans) if (s.isHit) s.text], ['alpha gamma']);
    });

    test('reassembles the original text exactly', () {
      const text = 'alpha, beta; gamma.';
      final spans = highlightPhraseRanges(text, [0, 5, 7, 11]);
      expect(spans.map((s) => s.text).join(), text);
    });

    test('no ranges means one plain span', () {
      expect(highlightPhraseRanges('abc', const []),
          const [HighlightSpan('abc', false)]);
    });

    test('mergePhraseRanges coalesces and sorts', () {
      expect(mergePhraseRanges([10, 15, 0, 5, 5, 8]), [0, 8, 10, 15]);
      expect(mergePhraseRanges([0, 5]), [0, 5]);
      expect(mergePhraseRanges([0, 6, 2, 4]), [0, 6]);
    });
  });

  group('defaultEnabledPhrases', () {
    test('unchecks a phrase made only of function words', () {
      final ix = _index(['out of the house']);
      final displays = {
        for (var i = 0; i < ix.phrases.length; i++) ix.phrases[i].display: i
      };
      final on = defaultEnabledPhrases(ix);
      expect(on, isNot(contains(displays['out of the'])));
      expect(ix.phrases[displays['out of the']!].allCommon, isTrue);
      expect(ix.phrases[displays['of the house']!].allCommon, isFalse);
    });

    test('unchecks a phrase that is in too much of the corpus', () {
      final corpus = [
        'alpha beta gamma',
        for (var i = 0; i < 500; i++) 'alpha beta gamma filler $i',
      ];
      final ix = buildPhraseMatchIndex(corpus: corpus, baseIndex: 0);
      expect(ix.phrases.single.verseCount, 500);
      expect(defaultEnabledPhrases(ix), isEmpty);
      // Still one tap from being back in: the phrase is listed, with
      // its count on show.
      expect(ix.phrases.single.listed, isTrue);
    });

    test('keeps a phrase that matched only a handful of verses', () {
      final corpus = [
        'alpha beta gamma',
        'alpha beta gamma one',
        for (var i = 0; i < 500; i++) 'unrelated filler $i',
      ];
      final ix = buildPhraseMatchIndex(corpus: corpus, baseIndex: 0);
      expect(defaultEnabledPhrases(ix), {0});
    });

    test('never unchecks on rarity alone on a tiny corpus', () {
      final ix = _index(['alpha beta gamma', 'alpha beta gamma too']);
      expect(defaultEnabledPhrases(ix), {0});
    });

    test('a phrase that matched nothing starts unchecked', () {
      final ix = _index(['alpha beta gamma', 'nothing in common']);
      expect(defaultEnabledPhrases(ix), isEmpty);
    });
  });

  group('scope — bwh51 "use search limits from main window"', () {
    test('restricts the scan and the counts to the scope', () {
      const corpus = [
        'alpha beta gamma',
        'alpha beta gamma one',
        'alpha beta gamma two',
        'alpha beta gamma three',
      ];
      final all = _index(corpus);
      expect(all.scanned, 3);
      expect(all.phrases.single.verseCount, 3);

      final scoped = _index(corpus, scope: {1, 3});
      expect(scoped.scanned, 2);
      expect(_matchedVerses(scoped), {1, 3});
      expect(scoped.phrases.single.verseCount, 2);
    });

    test('the base verse stays excluded even when the scope names it', () {
      final ix = _index(
        ['alpha beta gamma', 'alpha beta gamma again'],
        scope: {0, 1},
      );
      expect(_matchedVerses(ix), {1});
      expect(ix.scanned, 1);
    });
  });

  group('grouping by verse', () {
    late PhraseMatchIndex ix;
    setUp(() {
      ix = _index([
        'alpha beta gamma delta epsilon',
        'alpha beta gamma only',
        'nothing at all here',
        'alpha beta gamma delta epsilon repeated exactly',
      ]);
    });

    test('sorts by how many distinct phrases a verse carries', () {
      final groups = groupPhraseHitsByVerse(ix, _allPhrases(ix));
      expect(groups.first.verseIndex, 3);
      expect(groups.first.phraseIndexes, hasLength(3));
      expect(groups[1].verseIndex, 1);
      expect(groups[1].phraseIndexes, hasLength(1));
    });

    test('sorts by book order when asked', () {
      final groups = groupPhraseHitsByVerse(ix, _allPhrases(ix),
          sort: PhraseMatchSort.reference);
      expect([for (final g in groups) g.verseIndex], [1, 3]);
    });

    test('unchecking a phrase drops the verses that only had it', () {
      final only = groupPhraseHitsByVerse(ix, {1});
      expect([for (final g in only) g.verseIndex], [3]);
    });

    test('merges the ranges of every phrase that hit the verse', () {
      final groups = groupPhraseHitsByVerse(ix, _allPhrases(ix));
      final g = groups.firstWhere((g) => g.verseIndex == 3);
      final spans = highlightPhraseRanges(
          'alpha beta gamma delta epsilon repeated exactly', g.ranges);
      // Three overlapping phrases collapse into one continuous run.
      expect([for (final s in spans) if (s.isHit) s.text],
          ['alpha beta gamma delta epsilon']);
    });

    test('honours the limit', () {
      final corpus = [
        'alpha beta gamma',
        for (var i = 0; i < 50; i++) 'alpha beta gamma $i',
      ];
      final big = buildPhraseMatchIndex(corpus: corpus, baseIndex: 0);
      expect(groupPhraseHitsByVerse(big, _allPhrases(big), limit: 10),
          hasLength(10));
    });
  });

  group('grouping by phrase — bwh51\'s third view', () {
    test('orders the phrases by how often they were found', () {
      final ix = _index([
        'alpha beta gamma delta',
        'alpha beta gamma one',
        'alpha beta gamma two',
        'beta gamma delta only',
      ]);
      final groups = groupPhraseHitsByPhrase(ix, _allPhrases(ix));
      expect([for (final g in groups) ix.phrases[g.phraseIndex].display],
          ['alpha beta gamma', 'beta gamma delta']);
      expect(groups.first.occurrences, 2);
      expect(groups.first.hits, hasLength(2));
      expect(groups[1].occurrences, 1);
    });

    test('lists each phrase\'s verses in book order', () {
      final ix = _index([
        'alpha beta gamma',
        'z alpha beta gamma',
        'y alpha beta gamma',
      ]);
      final g = groupPhraseHitsByPhrase(ix, _allPhrases(ix)).single;
      expect([for (final h in g.hits) h.verseIndex], [1, 2]);
    });

    test('caps the verses shown under one phrase', () {
      final corpus = [
        'alpha beta gamma',
        for (var i = 0; i < 60; i++) 'alpha beta gamma $i',
      ];
      final ix = buildPhraseMatchIndex(corpus: corpus, baseIndex: 0);
      final g =
          groupPhraseHitsByPhrase(ix, _allPhrases(ix), versesPerPhrase: 5)
              .single;
      expect(g.hits, hasLength(5));
      // The count is the truth, not the length of the list shown.
      expect(g.occurrences, 60);
    });

    test('an unchecked phrase disappears from the view', () {
      final ix = _index(['alpha beta gamma delta', 'alpha beta gamma delta x']);
      expect(groupPhraseHitsByPhrase(ix, const <int>{}), isEmpty);
    });
  });

  group('degenerate input', () {
    test('an out-of-range base verse yields the empty index', () {
      expect(_index(['a b c'], base: 9).isEmpty, isTrue);
      expect(_index(['a b c'], base: -1).isEmpty, isTrue);
    });

    test('an empty corpus is not a crash', () {
      expect(buildPhraseMatchIndex(corpus: const [], baseIndex: 0).isEmpty,
          isTrue);
    });

    test('a base verse of pure punctuation yields no phrases', () {
      expect(_index(['. . . -- ;', 'alpha beta gamma']).phrases, isEmpty);
    });

    test('an empty scope scans nothing', () {
      final ix = _index(['a b c', 'a b c d'], scope: const <int>{});
      expect(ix.scanned, 0);
      expect(ix.hits, isEmpty);
    });
  });

  group('what the tool is actually for', () {
    // Public-domain KJV text. The point of the tool is that the shared
    // RUN is the evidence of quotation — a bag of words cannot tell
    // these apart from any verse that merely mentions the same nouns.
    const corpus = <String>[
      // 0 — Isaiah 7:14, the base.
      'Behold, a virgin shall conceive, and bear a son, and shall call his '
          'name Immanuel.',
      // 1 — Matthew 1:23 quotes it.
      'Behold, a virgin shall be with child, and shall bring forth a son, '
          'and they shall call his name Emmanuel.',
      // 2 — same vocabulary, no shared run.
      'The son shall bear the name his mother shall call him, and a virgin '
          'shall behold it.',
      // 3 — unrelated.
      'And God saw the light, that it was good.',
    ];

    test('finds the quotation and not the vocabulary lookalike', () {
      final ix = buildPhraseMatchIndex(corpus: corpus, baseIndex: 0);
      final groups = groupPhraseHitsByVerse(ix, defaultEnabledPhrases(ix));
      expect(groups, isNotEmpty);
      expect(groups.first.verseIndex, 1);
      expect([for (final g in groups) g.verseIndex], isNot(contains(3)));
    });

    test('"shall call his name" survives the reworking', () {
      final ix = buildPhraseMatchIndex(corpus: corpus, baseIndex: 0);
      final on = defaultEnabledPhrases(ix);
      final found = {
        for (final h in ix.hits)
          if (h.verseIndex == 1 && on.contains(h.phraseIndex))
            ix.phrases[h.phraseIndex].display
      };
      expect(found, contains('call his name'));
      expect(found, contains('a virgin shall'));
    });

    test('the gap recovers the run the insertion broke', () {
      // Matthew has "shall BE WITH CHILD, and shall bring forth a son"
      // where Isaiah has "shall conceive, and bear a son" — only a gap
      // reaches "and bear a son" → "and … a son".
      final tight = buildPhraseMatchIndex(corpus: corpus, baseIndex: 0);
      final loose =
          buildPhraseMatchIndex(corpus: corpus, baseIndex: 0, maxGap: 3);
      final tightHits = {
        for (final h in tight.hits)
          if (h.verseIndex == 1) tight.phrases[h.phraseIndex].display
      };
      final looseHits = {
        for (final h in loose.hits)
          if (h.verseIndex == 1) loose.phrases[h.phraseIndex].display
      };
      expect(looseHits.length, greaterThan(tightHits.length));
      expect(looseHits, containsAll(tightHits));
    });
  });
}
