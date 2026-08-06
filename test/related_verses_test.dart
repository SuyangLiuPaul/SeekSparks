import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/related_verses.dart';
import 'package:seeksparks/utils/search_highlight.dart' show HighlightSpan;

void main() {
  group('tokenizeForRelatedVerses — alphabetic', () {
    test('splits English on punctuation and lower-cases', () {
      expect(
        tokenizeForRelatedVerses(
            'In the beginning God created the heaven and the earth.'),
        ['in', 'the', 'beginning', 'god', 'created', 'the', 'heaven', 'and',
            'the', 'earth'],
      );
    });

    test('keeps an apostrophe inside a word but not around it', () {
      expect(tokenizeForRelatedVerses("God's own"), ["god's", 'own']);
      expect(tokenizeForRelatedVerses("'quoted' word"), ['quoted', 'word']);
      expect(tokenizeForRelatedVerses('don’t'), ['don’t']);
    });

    test('keeps digits, drops bare punctuation', () {
      expect(tokenizeForRelatedVerses('lived 600 years -- and died.'),
          ['lived', '600', 'years', 'and', 'died']);
    });

    test('keeps Greek and pointed Hebrew as single words', () {
      expect(tokenizeForRelatedVerses('ἐν αρχῇ'),
          ['ἐν', 'αρχῇ']);
      // בְּרֵאשִׁית — consonants plus niqqud must stay one token.
      expect(
          tokenizeForRelatedVerses(
              'בְּרֵאשִׁ'
              'ית'),
          hasLength(1));
    });
  });

  group('tokenizeForRelatedVerses — Chinese', () {
    test('emits overlapping bigrams within a run', () {
      expect(
        tokenizeForRelatedVerses('起初神创造天地'),
        ['起初', '初神', '神创', '创造',
            '造天', '天地'],
      );
    });

    test('never bridges punctuation between two runs', () {
      // 天地。神说 — 地神 must not appear.
      final t = tokenizeForRelatedVerses(
          '天地。神说');
      expect(t, ['天地', '神说']);
      expect(t, isNot(contains('地神')));
    });

    test('a lone ideograph is still a token', () {
      expect(tokenizeForRelatedVerses('神。'), ['神']);
    });

    test('mixes scripts without losing either', () {
      expect(tokenizeForRelatedVerses('神说 Amen'),
          ['神说', 'amen']);
    });
  });

  group('buildRelatedVersesIndex', () {
    // 0 is the base verse throughout.
    final corpus = <String>[
      'the word was god',       // 0
      'the word was with god',  // 1
      'god made the light',     // 2
      'a psalm of david',       // 3
      'the word',               // 4
    ];

    test('candidates are the base verse words, deduped, in order', () {
      final ix = buildRelatedVersesIndex(corpus: corpus, baseIndex: 0);
      expect([for (final t in ix.terms) t.term],
          ['the', 'word', 'was', 'god']);
    });

    test('postings never contain the base verse', () {
      final ix = buildRelatedVersesIndex(corpus: corpus, baseIndex: 0);
      for (final p in ix.postings.values) {
        expect(p, isNot(contains(0)));
      }
      expect(ix.postings['word'], {1, 4});
      expect(ix.postings['god'], {1, 2});
      expect(ix.postings['the'], {1, 2, 4});
    });

    test('document frequency counts the base verse too', () {
      final ix = buildRelatedVersesIndex(corpus: corpus, baseIndex: 0);
      // 'god' is in verses 0, 1 and 2.
      expect(ix.terms.firstWhere((t) => t.term == 'god').documentFrequency, 3);
      expect(ix.corpusSize, 5);
    });

    test('an added word is tokenized and marked as not from the verse', () {
      final ix = buildRelatedVersesIndex(
          corpus: corpus, baseIndex: 0, extraTerms: ['David', 'the']);
      final david = ix.terms.firstWhere((t) => t.term == 'david');
      expect(david.fromBaseVerse, isFalse);
      expect(ix.postings['david'], {3});
      // 'the' was already a candidate; adding it must not duplicate it.
      expect(ix.terms.where((t) => t.term == 'the'), hasLength(1));
    });

    test('an added Chinese word becomes the right bigrams', () {
      final ix = buildRelatedVersesIndex(
        corpus: ['神爱世人', '世人都犯了'],
        baseIndex: 0,
        extraTerms: ['世人'],
      );
      expect(ix.postings.containsKey('世人'), isTrue);
      expect(ix.postings['世人'], {1});
    });

    test('an out-of-range base verse yields the empty index', () {
      expect(buildRelatedVersesIndex(corpus: corpus, baseIndex: 99).isEmpty,
          isTrue);
      expect(buildRelatedVersesIndex(corpus: const [], baseIndex: 0).isEmpty,
          isTrue);
    });

    test('a verse with no tokens yields no candidates', () {
      final ix = buildRelatedVersesIndex(corpus: const ['。。', 'a b'],
          baseIndex: 0);
      expect(ix.terms, isEmpty);
      expect(ix.corpusSize, 2);
    });
  });

  group('the fast scan agrees with the reference tokenizer', () {
    // buildRelatedVersesIndex does not tokenize the corpus the way
    // tokenizeForRelatedVerses does — it screens candidates on length
    // and initial, and compares Chinese bigrams as packed integers, to
    // keep a whole-Bible scan under about a tenth of a second. Two
    // implementations of one rule drift. This pins them together: a
    // verse must land in a term's postings exactly when the reference
    // tokenizer finds that term in it.
    const corpus = <String>[
      "In the beginning God created the heaven and the earth.",
      '起初，神创造天地。',
      "God's own Son, whom He gave — don’t forget.",
      'The LORD God formed man; 神说：要有光。',
      'Amen, Amen; 我实实在在地告诉你们 600 times.',
      'nothing in common here at all',
      'ἐν ἀρχῇ ἦν ὁ λόγος',
      'GOD CREATED — shouting, and Earth.',
    ];

    for (var base = 0; base < corpus.length; base++) {
      test('base verse $base', () {
        final ix = buildRelatedVersesIndex(
          corpus: corpus,
          baseIndex: base,
          extraTerms: const ['light', '天地', 'λόγος'],
        );
        for (final t in ix.terms) {
          final expected = <int>{
            for (var i = 0; i < corpus.length; i++)
              if (i != base &&
                  tokenizeForRelatedVerses(corpus[i]).contains(t.term))
                i,
          };
          expect(ix.postings[t.term], expected,
              reason: 'postings for "${t.term}" with base $base');
        }
      });
    }

    test('an uppercase word is found by its lower-cased candidate', () {
      final ix = buildRelatedVersesIndex(corpus: corpus, baseIndex: 0);
      // 'created' appears capitalised in verse 7.
      expect(ix.postings['created'], contains(7));
      expect(ix.postings['god'], contains(7));
    });
  });

  group('defaultEnabledTerms', () {
    test('unchecks closed-class English words, keeps content words', () {
      final ix = buildRelatedVersesIndex(
        corpus: ['the word was god', 'nothing', 'nothing', 'nothing',
            'nothing'],
        baseIndex: 0,
      );
      final on = defaultEnabledTerms(ix);
      expect(on, contains('word'));
      expect(on, contains('god'));
      expect(on, isNot(contains('the')));
      expect(on, isNot(contains('was')));
    });

    test('unchecks any word occurring in more than a fifth of the corpus', () {
      // 'lord' is in 3 of 10 verses (30%) and is not a function word.
      final corpus = <String>[
        'lord shepherd',
        'lord alpha',
        'lord omega',
        for (var i = 0; i < 7; i++) 'filler$i',
      ];
      final ix = buildRelatedVersesIndex(corpus: corpus, baseIndex: 0);
      final on = defaultEnabledTerms(ix);
      expect(on, isNot(contains('lord')), reason: '30% of the corpus');
      expect(on, contains('shepherd'), reason: '10% of the corpus');
    });

    test('the frequency cap is adjustable', () {
      final corpus = <String>[
        'lord shepherd', 'lord alpha', 'lord omega',
        for (var i = 0; i < 7; i++) 'filler$i',
      ];
      final ix = buildRelatedVersesIndex(corpus: corpus, baseIndex: 0);
      expect(defaultEnabledTerms(ix, maxDocumentFrequency: 0.5),
          contains('lord'));
    });
  });

  group('defaultRelatedThreshold', () {
    test('is a third of the checked words, never below two', () {
      expect(defaultRelatedThreshold(0), 1);
      expect(defaultRelatedThreshold(1), 1);
      expect(defaultRelatedThreshold(2), 2);
      expect(defaultRelatedThreshold(3), 2);
      expect(defaultRelatedThreshold(6), 2);
      expect(defaultRelatedThreshold(9), 3);
      expect(defaultRelatedThreshold(12), 4);
      expect(defaultRelatedThreshold(30), 10);
    });
  });

  group('scoreRelatedVerses', () {
    final corpus = <String>[
      'the word was god',       // 0 — base
      'the word was with god',  // 1 — shares word, was, god
      'god made the light',     // 2 — shares god
      'a psalm of david',       // 3 — shares nothing
      'the word',               // 4 — shares word
    ];
    final ix = buildRelatedVersesIndex(corpus: corpus, baseIndex: 0);

    test('counts distinct shared words and orders by them', () {
      final hits = scoreRelatedVerses(
        index: ix,
        enabled: {'word', 'was', 'god'},
        threshold: 1,
      );
      expect([for (final h in hits) h.verseIndex], [1, 2, 4]);
      expect(hits.first.hits, 3);
      expect(hits.first.matchedTerms, ['word', 'was', 'god']);
    });

    test('the threshold drops the thin matches', () {
      final hits = scoreRelatedVerses(
        index: ix,
        enabled: {'word', 'was', 'god'},
        threshold: 2,
      );
      expect([for (final h in hits) h.verseIndex], [1]);
    });

    test('an emphasized word counts as three', () {
      final hits = scoreRelatedVerses(
        index: ix,
        enabled: {'god'},
        emphasized: {'god'},
        threshold: 1,
      );
      expect(hits.first.hits, kRelatedVersesEmphasisWeight);
      // Weighting one word can lift a verse above another.
      final lifted = scoreRelatedVerses(
        index: ix,
        enabled: {'word', 'god'},
        emphasized: {'god'},
        threshold: 1,
      );
      expect(lifted.first.verseIndex, 1); // word + god×3 = 4
      expect(lifted.first.hits, 4);
      expect(lifted[1].verseIndex, 2); // god×3 = 3, beats 'word' alone
      expect(lifted[1].hits, 3);
    });

    test('unchecked words do not count', () {
      final hits = scoreRelatedVerses(
        index: ix,
        enabled: {'god'},
        threshold: 1,
      );
      expect([for (final h in hits) h.verseIndex], [1, 2]);
      expect([for (final h in hits) h.matchedTerms], [
        ['god'],
        ['god'],
      ]);
    });

    test('sorting by reference is corpus order', () {
      final hits = scoreRelatedVerses(
        index: ix,
        enabled: {'the', 'word', 'god'},
        threshold: 1,
        sort: RelatedVersesSort.reference,
      );
      expect([for (final h in hits) h.verseIndex], [1, 2, 4]);
    });

    test('ties keep canonical order rather than hash order', () {
      final hits = scoreRelatedVerses(
        index: ix,
        enabled: {'the'},
        threshold: 1,
      );
      expect([for (final h in hits) h.verseIndex], [1, 2, 4]);
    });

    test('the limit caps the list', () {
      final hits = scoreRelatedVerses(
        index: ix,
        enabled: {'the', 'word', 'god'},
        threshold: 1,
        limit: 2,
      );
      expect(hits, hasLength(2));
    });

    test('nothing checked means nothing returned', () {
      expect(
          scoreRelatedVerses(index: ix, enabled: const {}, threshold: 1),
          isEmpty);
      expect(
          scoreRelatedVerses(
              index: RelatedVersesIndex.empty,
              enabled: {'god'},
              threshold: 1),
          isEmpty);
    });
  });

  group('groupRelatedByHits', () {
    test('bands equally-scoring verses under one count', () {
      final bands = groupRelatedByHits(const [
        RelatedVerseHit(verseIndex: 1, hits: 3, matchedTerms: []),
        RelatedVerseHit(verseIndex: 2, hits: 2, matchedTerms: []),
        RelatedVerseHit(verseIndex: 5, hits: 2, matchedTerms: []),
        RelatedVerseHit(verseIndex: 9, hits: 1, matchedTerms: []),
      ]);
      expect([for (final b in bands) b.hits], [3, 2, 1]);
      expect([for (final v in bands[1].verses) v.verseIndex], [2, 5]);
    });

    test('an empty list bands into nothing', () {
      expect(groupRelatedByHits(const []), isEmpty);
    });
  });

  group('highlightRelatedTerms', () {
    test('marks whole words only', () {
      final spans = highlightRelatedTerms('sin and since', {'sin'});
      expect(spans, const [
        HighlightSpan('sin', true),
        HighlightSpan(' and since', false),
      ]);
    });

    test('marks a Chinese phrase as one run, not alternating characters', () {
      // 神创造 is covered by the overlapping bigrams 神创 and 创造.
      final spans = highlightRelatedTerms(
        '起初神创造天地',
        {'神创', '创造'},
      );
      expect(spans, const [
        HighlightSpan('起初', false),
        HighlightSpan('神创造', true),
        HighlightSpan('天地', false),
      ]);
    });

    test('leaves text alone when nothing matches', () {
      expect(highlightRelatedTerms('a b c', {'zzz'}),
          const [HighlightSpan('a b c', false)]);
      expect(highlightRelatedTerms('a b c', const {}),
          const [HighlightSpan('a b c', false)]);
      expect(highlightRelatedTerms('', {'a'}), isEmpty);
    });

    test('marks a match that ends the string', () {
      expect(highlightRelatedTerms('in the beginning', {'beginning'}),
          const [
            HighlightSpan('in the ', false),
            HighlightSpan('beginning', true),
          ]);
    });
  });
}
