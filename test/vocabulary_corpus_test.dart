import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/vocabulary.dart';

/// The Vocabulary Flashcard core (bwh40) against the real bundled data —
/// 14,039 Strong's numbers, 13,963 of them with glosses, over a
/// 438,821-word tagged corpus.
///
/// `vocabulary_test.dart` pins the mechanics on hand-built input. It
/// cannot tell you whether the tool is any good, because a five-word
/// deck has no shape. These pin the claims the feature actually makes
/// and that the library doc comment states out loud: that the frequency
/// presets land where the published curricula say they land, that the
/// collation covers every character we ship, and that the Example Verse
/// Finder returns something a student could really sit down and read.
///
/// These are the assertions that would break silently if the lexicon,
/// the concordance or the tagged text were ever regenerated.
void main() {
  late List<VocabWord> all;
  late Map<String, int> freq;

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  setUpAll(() {
    all = vocabularyFromAssets(
      concordance: readJson('assets/strongs/concordance.json'),
      hebrewLexicon: readJson('assets/strongs/hebrew.json'),
      greekLexicon: readJson('assets/strongs/greek.json'),
    );
    freq = {for (final w in all) w.strongs: w.corpusCount};
  });

  /// `"chapter:verse"` → that verse's Strong's numbers, from the tagged
  /// original-language text.
  Map<String, List<String>> book(String slug) {
    final raw = readJson('assets/originals/$slug.json');
    return <String, List<String>>{
      for (final e in raw.entries)
        e.key: <String>[
          for (final w in e.value as List)
            ((w as Map<String, dynamic>)['s'] ?? '').toString(),
        ]..removeWhere((s) => s.isEmpty),
    };
  }

  group('the bundled vocabulary', () {
    test('every card has a lemma and a gloss on the back', () {
      expect(all.length, greaterThan(13000));
      expect(all.where((w) => w.lemma.isEmpty), isEmpty);
      expect(all.where((w) => w.gloss.isEmpty), isEmpty);
    });

    test('Strong\'s numbers with no lexicon entry are dropped, not blank',
        () {
      // G6xxx / G9xxx extended tags — 76 of them carry no lexicon entry.
      expect(all.map((w) => w.strongs), isNot(contains('G9992')));
    });

    test('Chinese glosses are used when asked for, English as fallback',
        () {
      final zh = vocabularyFromAssets(
        concordance: readJson('assets/strongs/concordance.json'),
        hebrewLexicon: readJson('assets/strongs/hebrew.json'),
        greekLexicon: readJson('assets/strongs/greek.json'),
        locale: 'zh-Hans',
      );
      final theos = zh.firstWhere((w) => w.strongs == 'G2316');
      expect(theos.gloss, isNotEmpty);
      expect(theos.gloss, isNot(contains('deity')));
      // Twelve entries have no Chinese gloss; they must fall back
      // rather than come out blank.
      expect(zh.where((w) => w.gloss.isEmpty), isEmpty);
    });
  });

  group('collation covers everything we ship', () {
    test('every character of every lemma folds to a letter we can sort',
        () {
      // This is the guard the library comment promises. A lexicon update
      // that introduced an unfoldable character would otherwise sort it
      // silently to the bottom of the A–Z list.
      final unfoldable = <String>{};
      for (final w in all) {
        for (final r in foldForSort(w.lemma).runes) {
          final greek = r >= 0x03B1 && r <= 0x03C9;
          final hebrew = r >= 0x05D0 && r <= 0x05EA;
          if (!greek && !hebrew) unfoldable.add(String.fromCharCode(r));
        }
      }
      expect(unfoldable, isEmpty,
          reason: 'unfoldable characters in shipped lemmas: $unfoldable');
    });

    test('A–Z over the whole Greek lexicon runs alpha to omega', () {
      final deck = buildDeck(
        words: all,
        filter: const VocabFilter(language: VocabLanguage.greek),
        sort: VocabSort.alphabetical,
      );
      expect(deck.first.sortKey[0], 'α');
      expect(deck.last.sortKey[0], 'ω');
      // And the raw order really is broken — this is why the fold is here.
      final raw = [for (final w in deck) w.lemma]..sort();
      expect(raw.first.substring(0, 1), isNot('ἀ'),
          reason: 'raw code-point order does not start at alpha');
    });

    test('A–Z over the whole Hebrew lexicon runs aleph to tav', () {
      final deck = buildDeck(
        words: all,
        filter: const VocabFilter(language: VocabLanguage.hebrew),
        sort: VocabSort.alphabetical,
      );
      expect(deck.first.sortKey[0], 'א');
      expect(deck.last.sortKey[0], 'ת');
    });
  });

  group('the frequency presets land where the curricula say', () {
    int sizeOf(VocabLanguage lang, int floor) => buildDeck(
          words: all,
          filter: VocabFilter(language: lang, minFrequency: floor),
        ).length;

    test('Greek 50x is Mounce\'s first year (~320 words)', () {
      expect(sizeOf(VocabLanguage.greek, 50), 312);
    });

    test('Greek 10x is Metzger\'s Lexical Aids (~1,067 words)', () {
      expect(sizeOf(VocabLanguage.greek, 10), 1130);
    });

    test('Hebrew 70x is Pratico & Van Pelt\'s first year', () {
      expect(sizeOf(VocabLanguage.hebrew, 70), 574);
    });

    test('Hebrew 50x covers ~80% of the OT, as the Vocabulary Guide says',
        () {
      // The lemma COUNT differs from their 641 because Strong's splits
      // entries a lexicon keeps together. The coverage is the check that
      // actually says our corpus counts are right, and they publish it.
      expect(sizeOf(VocabLanguage.hebrew, 50), 751);

      final hebrew = all.where((w) => w.isHebrew);
      final total = hebrew.fold<int>(0, (n, w) => n + w.corpusCount);
      final covered = hebrew
          .where((w) => w.corpusCount >= 50)
          .fold<int>(0, (n, w) => n + w.corpusCount);
      expect(covered / total, closeTo(0.82, 0.02));
    });

    test('every preset is a floor somebody is actually assigned', () {
      for (final lang in VocabLanguage.values) {
        for (final floor in frequencyPresetsFor(lang)) {
          expect(sizeOf(lang, floor), greaterThan(0));
        }
      }
    });
  });

  group('the Example Verse Finder on real Greek', () {
    /// The Strong's numbers a student knows after learning every Greek
    /// word occurring [floor] times or more.
    Set<String> vocabularyAt(int floor) => {
          for (final w in all)
            if (!w.isHebrew && w.corpusCount >= floor) w.strongs,
        };

    int readableVersesIn(String slug, int floor) => findExampleVerses(
          versesByRef: book(slug),
          known: vocabularyAt(floor),
          minListWords: 3,
          maxNonListWords: 0,
          limit: 1 << 20,
        ).length;

    test('first-year Greek really does open a fifth of John', () {
      // 312 words — Mounce's first year — and 179 of John's 878 verses
      // contain nothing else. This is the claim the feature makes.
      expect(readableVersesIn('john', 50), 179);
    });

    test('Metzger\'s 10x list opens most of John', () {
      final readable = readableVersesIn('john', 10);
      expect(readable, 541);
      expect(readable / 878, greaterThan(0.6));
    });

    test('John is the beginner\'s Gospel, and the finder can show it', () {
      // Everyone tells first-year students to start with John rather
      // than Mark. Measured on the same 312-word vocabulary, John is
      // more than three times as open: 20.4% of its verses against 6.7%.
      final john = readableVersesIn('john', 50) / 878;
      final mark = readableVersesIn('mark', 50) / 673;
      expect(john, greaterThan(3 * mark));
    });

    test('1 John 4:8 needs nothing past first-year vocabulary', () {
      // ὁ μὴ ἀγαπῶν οὐκ ἔγνω τὸν θεόν, ὅτι ὁ θεὸς ἀγάπη ἐστίν.
      final hits = findExampleVerses(
        versesByRef: book('1_john'),
        known: vocabularyAt(50),
        minListWords: 3,
        maxNonListWords: 0,
        limit: 1 << 20,
      );
      final refs = [for (final h in hits) h.ref];
      expect(refs, contains('4:8'));
      final v = hits.firstWhere((h) => h.ref == '4:8');
      expect(v.nonListWords, 0);
      expect(v.coverage, 1.0);
    });

    test('tightening the unknown budget can only shrink the result', () {
      final known = vocabularyAt(50);
      final verses = book('mark');
      var previous = 1 << 30;
      for (final budget in [3, 2, 1, 0]) {
        final n = findExampleVerses(
          versesByRef: verses,
          known: known,
          minListWords: 3,
          maxNonListWords: budget,
          limit: 1 << 20,
        ).length;
        expect(n, lessThanOrEqualTo(previous));
        previous = n;
      }
      expect(previous, greaterThan(0));
    });
  });

  group('scoping a deck to a passage', () {
    test('a chapter deck is a fraction of the corpus deck', () {
      final mark = book('mark');
      final chapter = versesInChapter(mark, 1);
      expect(chapter, isNotEmpty);
      final tally = tallyStrongs(chapter);

      final scoped = buildDeck(
        words: [
          for (final w in all)
            if (tally.containsKey(w.strongs))
              w.withScopeCount(tally[w.strongs]!),
        ],
        sort: VocabSort.scopeFrequency,
      );
      // Mark 1 is 45 verses; a few hundred distinct lemmas, not 5,399.
      expect(scoped.length, lessThan(500));
      expect(scoped.length, greaterThan(100));
      // Sorted by scope count, the top of a Greek chapter is the article.
      expect(scoped.first.strongs, 'G3588');
      expect(scoped.first.scopeCount, greaterThan(scoped.last.scopeCount));
    });

    test('scope counts sum to the tokens actually in the passage', () {
      final chapter = versesInChapter(book('mark'), 1);
      final tokens =
          chapter.values.fold<int>(0, (n, ws) => n + ws.length);
      final tallied =
          tallyStrongs(chapter).values.fold<int>(0, (n, c) => n + c);
      expect(tallied, tokens);
    });

    test('a scoped word keeps its corpus frequency for filtering', () {
      // The whole point of splitting the two counts: a word can be rare
      // in the language and common in this chapter.
      final tally = tallyStrongs(versesInChapter(book('mark'), 1));
      final scoped = [
        for (final w in all)
          if (tally.containsKey(w.strongs))
            w.withScopeCount(tally[w.strongs]!),
      ];
      final locallyHeavy = scoped
          .where((w) => w.scopeCount >= 3 && w.corpusCount < 50)
          .toList();
      expect(locallyHeavy, isNotEmpty,
          reason: 'Mark 1 leans on words no syllabus teaches in year one');
      // ...and the 50x filter still excludes them, by corpus count.
      expect(
        buildDeck(words: locallyHeavy,
            filter: const VocabFilter(minFrequency: 50)),
        isEmpty,
      );
    });
  });

  test('the concordance and the lexicons agree on what exists', () {
    // A drift here would show up as cards with counts but no glosses.
    expect(freq['G2316'], greaterThan(1000)); // θεός
    expect(freq['G3588'], greaterThan(19000)); // the article
    expect(freq['H3068'], greaterThan(6000)); // YHWH
    expect(all.where((w) => w.corpusCount <= 0), isEmpty);
  });
}
