import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/vocabulary.dart';

/// Mechanics of the Vocabulary Flashcard core (bwh40). Behaviour against
/// the real tagged corpus lives in `vocabulary_corpus_test.dart`.

VocabWord w(
  String strongs,
  String lemma, {
  int corpus = 10,
  int? scope,
  String gloss = '',
  String translit = '',
  bool fn = false,
}) =>
    VocabWord(
      strongs: strongs,
      lemma: lemma,
      translit: translit,
      gloss: gloss,
      corpusCount: corpus,
      scopeCount: scope,
      isFunctionWord: fn,
    );

List<String> lemmasOf(List<VocabWord> ws) => [for (final x in ws) x.lemma];
List<String> numbersOf(List<VocabWord> ws) => [for (final x in ws) x.strongs];

void main() {
  group('foldForSort — Greek', () {
    test('folds breathings, accents and iota subscripts to the base letter',
        () {
      expect(foldForSort('ἀγάπη'), 'αγαπη');
      expect(foldForSort('ὥστε'), 'ωστε');
    });

    test('covers the whole block, not just the letters our lemmas use', () {
      // ᾧ occurs in running text but in no bundled headword. A fold map
      // built from the lemmas we ship would miss it and sort it last.
      expect(foldForSort('ᾧ'), 'ω');
      expect(foldForSort('ᾗ'), 'η');
      expect(foldForSort('Ὥ'), 'ω');
    });

    test('folds case and final sigma', () {
      // Note the fold target is medial σ — that is the point.
      expect(foldForSort('Ἰησοῦς'), 'ιησουσ');
      expect(foldForSort('λόγος'), 'λογοσ');
      // Final and medial sigma must collate identically, or every word
      // ending in -ς sorts away from its own stem.
      expect(foldForSort('ς'), foldForSort('σ'));
    });

    test('the Extended-block problem it exists to solve', () {
      // Raw code points put ἀγάπη (U+1F00) after ὠφέλεια (U+1F60) —
      // and after every unaccented letter too.
      expect('ἀγάπη'.compareTo('ὠφέλεια'), lessThan(0),
          reason: 'both are Extended-block, so raw order happens to hold');
      expect('ἀγάπη'.compareTo('ζωή'), greaterThan(0),
          reason: 'this is the bug: alpha sorting after zeta');
      expect(foldForSort('ἀγάπη').compareTo(foldForSort('ζωή')), lessThan(0));
    });

    test('stigma collates with sigma', () {
      // G5516 χξϛ — the numeral 666, the one entry using stigma.
      expect(foldForSort('χξϛ'), 'χξσ');
    });
  });

  group('foldForSort — Hebrew', () {
    test('drops points and cantillation', () {
      expect(foldForSort('אָב'), 'אב');
      expect(foldForSort('דָּבָר'), 'דבר');
      expect(foldForSort('בְּרֵאשִׁית'), 'בראשית');
    });

    test('normalises final forms to their base letter', () {
      expect(foldForSort('מֶלֶךְ'), 'מלכ');
      expect(foldForSort('אֶרֶץ'), 'ארצ');
      // Raw, ץ (U+05E5) sorts before צ (U+05E6) — one place too early.
      expect(foldForSort('ץ'), foldForSort('צ'));
    });

    test('vocalisation does not decide the order', () {
      // Same consonants, different pointing: they must collate equal.
      expect(foldForSort('דָּבָר'), foldForSort('דְּבַר'));
    });

    test('drops maqaf and headword punctuation', () {
      expect(foldForSort('כָּל־'), 'כל');
      expect(foldForSort('a (b)'), 'ab');
    });

    test('keeps anything it does not recognise', () {
      expect(foldForSort('abc'), 'abc');
      expect(foldForSort('日'), '日');
    });
  });

  group('buildDeck — filtering', () {
    final words = [
      w('G1', 'α', corpus: 100),
      w('G2', 'β', corpus: 50),
      w('G3', 'γ', corpus: 9),
      w('H4', 'א', corpus: 60),
      w('G5', 'δ', corpus: 400, fn: true),
    ];

    test('frequency floor and ceiling both test the corpus count', () {
      final deck = buildDeck(
        words: words,
        filter: const VocabFilter(minFrequency: 50),
      );
      expect(numbersOf(deck), <String>['G5', 'G1', 'H4', 'G2']);

      final capped = buildDeck(
        words: words,
        filter: const VocabFilter(minFrequency: 50, maxFrequency: 99),
      );
      expect(numbersOf(capped), <String>['H4', 'G2']);
    });

    test('the frequency filter ignores the scope count', () {
      // A word rare in the language but common in this chapter must
      // still be judged by the language — that is what makes "≥50×"
      // mean the same thing in every scope.
      final scoped = [w('G9', 'ε', corpus: 3, scope: 40)];
      expect(
        buildDeck(
            words: scoped, filter: const VocabFilter(minFrequency: 50)),
        isEmpty,
      );
    });

    test('language', () {
      expect(
        numbersOf(buildDeck(
          words: words,
          filter: const VocabFilter(language: VocabLanguage.hebrew),
        )),
        <String>['H4'],
      );
      expect(
        buildDeck(
          words: words,
          filter: const VocabFilter(language: VocabLanguage.greek),
        ).where((x) => x.isHebrew),
        isEmpty,
      );
    });

    test('function words are separable but present by default', () {
      expect(numbersOf(buildDeck(words: words)), contains('G5'));
      expect(
        numbersOf(buildDeck(
          words: words,
          filter: const VocabFilter(includeFunctionWords: false),
        )),
        isNot(contains('G5')),
      );
    });

    test('learned words stay in the deck unless excluded', () {
      const learnt = {'G1'};
      expect(numbersOf(buildDeck(words: words, learned: learnt)),
          contains('G1'));
      expect(
        numbersOf(buildDeck(
          words: words,
          filter: const VocabFilter(excludeLearned: true),
          learned: learnt,
        )),
        isNot(contains('G1')),
      );
    });

    test('query matches lemma, transliteration or gloss', () {
      final searchable = [
        w('G1', 'ἀγάπη', translit: 'agapē', gloss: 'love'),
        w('G2', 'λόγος', translit: 'logos', gloss: 'a word'),
      ];
      for (final q in ['ἀγάπ', 'agap', 'LOVE']) {
        expect(
          numbersOf(buildDeck(
              words: searchable, filter: VocabFilter(query: q))),
          <String>['G1'],
          reason: q,
        );
      }
    });
  });

  group('buildDeck — sorting', () {
    test('frequency, commonest first', () {
      final deck = buildDeck(
        words: [w('G1', 'α', corpus: 3), w('G2', 'β', corpus: 30)],
      );
      expect(numbersOf(deck), <String>['G2', 'G1']);
    });

    test('scope frequency reorders a corpus-ranked deck', () {
      final words = [
        w('G1', 'α', corpus: 900, scope: 1),
        w('G2', 'β', corpus: 12, scope: 9),
      ];
      expect(numbersOf(buildDeck(words: words)), <String>['G1', 'G2']);
      expect(
        numbersOf(
            buildDeck(words: words, sort: VocabSort.scopeFrequency)),
        <String>['G2', 'G1'],
      );
    });

    test('alphabetical uses the folded key, not code points', () {
      final deck = buildDeck(
        words: [
          w('G1', 'ὠφέλεια'),
          w('G2', 'ἀγάπη'),
          w('G3', 'ζωή'),
        ],
        sort: VocabSort.alphabetical,
      );
      expect(lemmasOf(deck), <String>['ἀγάπη', 'ζωή', 'ὠφέλεια']);
    });

    test('ties break by lemma then by Strong\'s NUMBER, not string', () {
      final deck = buildDeck(
        words: [w('G100', 'α'), w('G80', 'α'), w('G9', 'α')],
        sort: VocabSort.alphabetical,
      );
      expect(numbersOf(deck), <String>['G9', 'G80', 'G100']);
    });

    test('random is reproducible from the seed and input-order-proof', () {
      final words = [
        for (var i = 1; i <= 25; i++) w('G$i', 'w$i', corpus: i),
      ];
      final a = buildDeck(words: words, sort: VocabSort.random, seed: 7);
      final b = buildDeck(
          words: words.reversed, sort: VocabSort.random, seed: 7);
      final c = buildDeck(words: words, sort: VocabSort.random, seed: 8);
      expect(numbersOf(a), numbersOf(b),
          reason: 'a shuffle of an unknown order is not reproducible');
      expect(numbersOf(a), isNot(numbersOf(c)));
      expect(a, hasLength(25));
    });
  });

  test('reviewQueue drops learned cards the deck still shows', () {
    final deck = buildDeck(words: [w('G1', 'α'), w('G2', 'β')]);
    expect(deck, hasLength(2));
    expect(numbersOf(reviewQueue(deck, {'G1'})), <String>['G2']);
    expect(reviewQueue(deck, const {}), same(deck));
  });

  group('frequencyPresetsFor', () {
    test('offers the thresholds each language is actually taught at', () {
      expect(frequencyPresetsFor(VocabLanguage.greek), <int>[50, 10, 1]);
      expect(frequencyPresetsFor(VocabLanguage.hebrew), <int>[70, 50, 10, 1]);
    });

    test('never offers an invented tier', () {
      for (final l in [null, VocabLanguage.greek, VocabLanguage.hebrew]) {
        expect(frequencyPresetsFor(l), isNot(contains(20)));
        expect(frequencyPresetsFor(l), isNot(contains(30)));
      }
    });

    test('every ladder ends at 1 — "no floor" must be reachable', () {
      for (final l in [null, VocabLanguage.greek, VocabLanguage.hebrew]) {
        expect(frequencyPresetsFor(l).last, 1);
      }
    });
  });

  group('scope', () {
    final verses = <String, List<String>>{
      '1:1': ['G1', 'G2', 'G1'],
      '1:2': ['G2'],
      '2:1': ['G3', 'G1'],
    };

    test('tallyStrongs counts tokens, not verses', () {
      expect(tallyStrongs(verses), <String, int>{'G1': 3, 'G2': 2, 'G3': 1});
    });

    test('tallyStrongs ignores blank tags', () {
      expect(tallyStrongs({'1:1': ['G1', '', 'G1']}), <String, int>{'G1': 2});
    });

    test('versesInChapter', () {
      expect(versesInChapter(verses, 1).keys, <String>['1:1', '1:2']);
      expect(versesInChapter(verses, 9), isEmpty);
    });
  });

  group('findExampleVerses', () {
    // 1:1 is fully readable; 1:2 has one unknown token; 1:3 has the
    // same unknown word twice; 1:4 exercises only one list word.
    final verses = <String, List<String>>{
      '1:1': ['G1', 'G2', 'G3'],
      '1:2': ['G1', 'G2', 'G3', 'G9'],
      '1:3': ['G1', 'G2', 'G3', 'G9', 'G9'],
      '1:4': ['G1', 'G1', 'G1'],
    };
    const known = {'G1', 'G2', 'G3'};

    test('zero unknowns means every token is a word you know', () {
      final hits = findExampleVerses(
        versesByRef: verses,
        known: known,
        minListWords: 3,
      );
      expect([for (final h in hits) h.ref], <String>['1:1']);
      expect(hits.single.nonListWords, 0);
      expect(hits.single.listWords, 3);
      expect(hits.single.coverage, 1.0);
    });

    test('the unknown budget counts TOKENS, so a repeat costs twice', () {
      final hits = findExampleVerses(
        versesByRef: verses,
        known: known,
        minListWords: 3,
        maxNonListWords: 1,
      );
      // 1:3 repeats its unknown word and is therefore out at budget 1,
      // even though it has only one unknown *lemma*.
      expect([for (final h in hits) h.ref], <String>['1:1', '1:2']);
      expect(
        findExampleVerses(
          versesByRef: verses,
          known: known,
          minListWords: 3,
          maxNonListWords: 2,
        ).map((h) => h.ref),
        containsAll(<String>['1:3']),
      );
    });

    test('the list-word minimum counts DISTINCT lemmas, so a repeat is one',
        () {
      // 1:4 is three tokens of one known word. It exercises one word.
      final hits = findExampleVerses(
        versesByRef: verses,
        known: known,
        minListWords: 2,
      );
      expect([for (final h in hits) h.ref], isNot(contains('1:4')));
      expect(
        findExampleVerses(
                versesByRef: verses, known: known, minListWords: 1)
            .map((h) => h.ref),
        contains('1:4'),
      );
    });

    test('orders by fewest obstacles, then by most of the list exercised',
        () {
      final hits = findExampleVerses(
        versesByRef: {
          '5:1': ['G1', 'G9'],
          '1:9': ['G1', 'G2', 'G3'],
          '9:9': ['G1', 'G2'],
        },
        known: known,
        minListWords: 1,
        maxNonListWords: 1,
      );
      expect([for (final h in hits) h.ref], <String>['1:9', '9:9', '5:1']);
    });

    test('an empty vocabulary finds nothing rather than everything', () {
      expect(
        findExampleVerses(
            versesByRef: verses, known: const {}, minListWords: 0),
        isEmpty,
      );
    });

    test('respects the limit', () {
      expect(
        findExampleVerses(
          versesByRef: verses,
          known: known,
          minListWords: 1,
          maxNonListWords: 9,
          limit: 2,
        ),
        hasLength(2),
      );
    });

    test('skips malformed refs instead of throwing', () {
      expect(
        findExampleVerses(
          versesByRef: {'nonsense': ['G1', 'G2', 'G3']},
          known: known,
          minListWords: 1,
        ),
        isEmpty,
      );
    });
  });

  group('DrillQueue', () {
    List<VocabWord> cards(int n) =>
        [for (var i = 1; i <= n; i++) w('G$i', 'w$i')];

    test('a correct answer retires the card', () {
      final q = DrillQueue(cards(3));
      expect(q.current!.strongs, 'G1');
      q.answer(correct: true);
      expect(q.current!.strongs, 'G2');
      expect(q.clearedCount, 1);
      expect(q.remaining, 2);
      expect(q.missedCount, 0);
    });

    test('a wrong answer sends the card back, not away', () {
      final q = DrillQueue(cards(10), reinsertAfter: 3);
      q.answer(correct: false); // G1 missed
      expect(q.remaining, 10, reason: 'it is still owed');
      expect([for (var i = 0; i < 4; i++) _next(q)],
          <String>['G2', 'G3', 'G4', 'G1']);
    });

    test('a missed card stays missed even after it comes good', () {
      final q = DrillQueue(cards(2), reinsertAfter: 1);
      q.answer(correct: false); // G1
      q.answer(correct: true); // G2
      q.answer(correct: true); // G1, second time
      expect(q.isDone, isTrue);
      expect(q.missedStrongs, <String>{'G1'});
      expect(q.clearedCount, 2);
    });

    test('the last card missed comes straight back', () {
      final q = DrillQueue(cards(1));
      q.answer(correct: false);
      expect(q.current!.strongs, 'G1');
      expect(q.isDone, isFalse);
      q.answer(correct: true);
      expect(q.isDone, isTrue);
    });

    test('reinsertAfter is clamped so a miss cannot repeat immediately', () {
      final q = DrillQueue(cards(4), reinsertAfter: 0);
      expect(q.reinsertAfter, 1);
      q.answer(correct: false);
      expect(q.current!.strongs, 'G2');
    });

    test('progress tracks cards retired, and finishes at 1', () {
      final q = DrillQueue(cards(4));
      expect(q.progress, 0);
      q.answer(correct: true);
      expect(q.progress, 0.25);
      while (!q.isDone) {
        q.answer(correct: true);
      }
      expect(q.progress, 1);
    });

    test('an empty drill is done, not divided by zero', () {
      final q = DrillQueue(const <VocabWord>[]);
      expect(q.isDone, isTrue);
      expect(q.progress, 1);
      q.answer(correct: true); // must not throw
      expect(q.current, isNull);
    });

    test('skip moves on without recording an answer', () {
      final q = DrillQueue(cards(3));
      q.skip();
      expect(q.current!.strongs, 'G2');
      expect(q.clearedCount, 0);
      expect(q.missedCount, 0);
      expect(q.remaining, 3);
    });

    test('skipping the only card is a no-op rather than a flicker', () {
      final q = DrillQueue(cards(1));
      q.skip();
      expect(q.current!.strongs, 'G1');
    });

    test('a run of wrong answers re-drills the same near window', () {
      // Five wrong answers is NOT five missed cards: with reinsertAfter
      // 2, card 1 is back in front of you by the fourth answer. That is
      // the mechanic working — you stay on what you do not know instead
      // of marching past it.
      final q = DrillQueue(cards(5), reinsertAfter: 2);
      for (var i = 0; i < 5; i++) {
        q.answer(correct: false);
      }
      expect(q.missedStrongs, <String>{'G1', 'G2', 'G3'});
      var guard = 0;
      while (!q.isDone && guard++ < 50) {
        q.answer(correct: true);
      }
      expect(q.isDone, isTrue);
      expect(q.clearedCount, 5);
    });
  });
}

String _next(DrillQueue q) {
  final s = q.current!.strongs;
  q.answer(correct: true);
  return s;
}
