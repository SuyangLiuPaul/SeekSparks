import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/utils/word_list.dart';
import 'package:seeksparks/utils/word_list_compare.dart';

WordListEntry e(String strongs, int count, {String? form, String? lemma}) =>
    WordListEntry(
      strongs: strongs,
      form: form ?? strongs,
      count: count,
      lemma: lemma,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('compareWordLists', () {
    test('buckets a word by which side has it', () {
      final c = compareWordLists(
        [e('G1', 2), e('G2', 1)],
        [e('G2', 3), e('G3', 1)],
        sort: WordCompareSort.number,
      );
      expect(c.rows.map((r) => r.strongs), ['G1', 'G2', 'G3']);
      expect(c.rows[0].bucket, WordCompareBucket.onlyA);
      expect(c.rows[1].bucket, WordCompareBucket.both);
      expect(c.rows[2].bucket, WordCompareBucket.onlyB);
      expect(c.bothCount, 1);
      expect(c.onlyACount, 1);
      expect(c.onlyBCount, 1);
    });

    test('an absent side counts zero, and combined adds both', () {
      final c = compareWordLists([e('G1', 2)], [e('G1', 5)]);
      expect(c.rows.single.countA, 2);
      expect(c.rows.single.countB, 5);
      expect(c.rows.single.combined, 7);
    });

    test('the row is headed by the lemma, not by either book\'s form', () {
      // The two scopes inflect the same verb differently; heading with
      // either form would print one book's inflection as the shared word.
      final c = compareWordLists(
        [e('G25', 1, form: 'ἠγάπησεν', lemma: 'ἀγαπάω')],
        [e('G25', 1, form: 'ἀγαπῶντες', lemma: 'ἀγαπάω')],
      );
      final r = c.rows.single;
      expect(r.headword, 'ἀγαπάω');
      expect(r.formA, 'ἠγάπησεν');
      expect(r.formB, 'ἀγαπῶντες');
    });

    test('with no lemma the headword falls back to a form, never empty', () {
      final c = compareWordLists([], [e('G6001', 1, form: 'χ')]);
      expect(c.rows.single.headword, 'χ');
      expect(compareWordLists([e('G6001', 1, form: '')], []).rows.single.headword,
          'G6001');
    });

    test('nowhereElse is true only when the two scopes hold every '
        'occurrence in the Bible', () {
      final c = compareWordLists(
        [e('G1', 2), e('G2', 1)],
        [e('G1', 1), e('G2', 1)],
        corpusTotals: {'G1': 3, 'G2': 9},
      );
      final byNum = {for (final r in c.rows) r.strongs: r};
      expect(byNum['G1']!.nowhereElse, isTrue);
      expect(byNum['G2']!.nowhereElse, isFalse);
      expect(c.nowhereElseCount, 1);
    });

    test('no corpus total means the claim is not made', () {
      // Unknown must not read as "occurs nowhere else".
      final c = compareWordLists([e('G1', 2)], [e('G1', 1)]);
      expect(c.rows.single.corpusTotal, isNull);
      expect(c.rows.single.nowhereElse, isFalse);
    });

    test('both totals are carried so neither count stands alone', () {
      final c = compareWordLists(
        [e('G1', 3), e('G2', 1)],
        [e('G1', 1)],
      );
      expect(c.totalA, 4);
      expect(c.totalB, 1);
      expect(c.distinctA, 2);
      expect(c.distinctB, 1);
    });

    test('a Hebrew scope against a Greek one does not share a language', () {
      // The empty intersection there is a property of the numbering, not
      // a finding about the two passages.
      final c = compareWordLists([e('H1', 1)], [e('G1', 1)]);
      expect(c.sharesLanguage, isFalse);
      expect(c.bothCount, 0);
    });

    test('an empty scope is empty, not foreign', () {
      expect(compareWordLists([], [e('G1', 1)]).sharesLanguage, isTrue);
      expect(compareWordLists([e('H1', 1)], []).sharesLanguage, isTrue);
      expect(compareWordLists([], []).sharesLanguage, isTrue);
    });

    test('a scope mixing both prefixes shares a language with either', () {
      final c = compareWordLists([e('H1', 1), e('G1', 1)], [e('G2', 1)]);
      expect(c.sharesLanguage, isTrue);
    });

    test('strongsPrefixes reports the letters used', () {
      expect(strongsPrefixes([e('g1', 1), e('H2', 1)]), {'G', 'H'});
      expect(strongsPrefixes([e('', 1)]), isEmpty);
    });
  });

  group('sortComparison', () {
    List<WordComparisonRow> rows(WordCompareSort s) => compareWordLists(
          [e('G100', 1, lemma: 'beta'), e('G20', 5, lemma: 'alpha')],
          [e('G100', 1, lemma: 'beta'), e('H3', 2, lemma: 'gamma')],
          sort: s,
          corpusTotals: {'G20': 900, 'G100': 2},
        ).rows;

    test('rarity leads with the rarest in the whole Bible', () {
      expect(rows(WordCompareSort.corpusRarity).first.strongs, 'G100');
    });

    test('a number with no corpus total sorts last, not first', () {
      // "Unknown" is not "rare"; heading the list with the rows we know
      // least about would answer a question nobody asked.
      expect(rows(WordCompareSort.corpusRarity).last.strongs, 'H3');
    });

    test('combined leads with the commonest across the pair', () {
      expect(rows(WordCompareSort.combined).first.strongs, 'G20');
    });

    test('number sorts Hebrew before Greek and numerically', () {
      expect(rows(WordCompareSort.number).map((r) => r.strongs),
          ['G20', 'G100', 'H3']);
    });

    test('alphabetical sorts by the headword', () {
      expect(rows(WordCompareSort.alphabetical).map((r) => r.headword),
          ['alpha', 'beta', 'gamma']);
    });

    test('every sort is total — equal rows keep the number order', () {
      for (final s in WordCompareSort.values) {
        final a = compareWordLists(
          [e('G5', 1), e('G4', 1), e('G3', 1)],
          [e('G5', 1), e('G4', 1), e('G3', 1)],
          sort: s,
        ).rows.map((r) => r.strongs).toList();
        final b = compareWordLists(
          [e('G3', 1), e('G5', 1), e('G4', 1)],
          [e('G4', 1), e('G3', 1), e('G5', 1)],
          sort: s,
        ).rows.map((r) => r.strongs).toList();
        expect(a, b, reason: '$s must not depend on input order');
      }
    });
  });

  group('on the corpus', () {
    // The "nowhere else in the Bible" claim adds the two scope counts and
    // compares them with the concordance's corpus total. That is only
    // true if `assets/originals` and `concordance.json` count the same
    // things — same tokens, Ketiv/Qere included. DATA-INTEGRITY check 3b
    // measures the agreement over all 14,040 numbers; these two pin the
    // claim itself to the corpus so a re-import cannot quietly break it.

    Future<List<WordListEntry>> listFor(String book) async =>
        buildWordList(await OriginalsService.forBook(book));

    test('Jude and 2 Peter share exactly three words found nowhere else',
        () async {
      final a = await listFor('Jude');
      final b = await listFor('2 Peter');
      final totals = await ConcordanceService.totalsFor(
          {...a.map((e) => e.strongs), ...b.map((e) => e.strongs)});
      final c = compareWordLists(a, b, corpusTotals: totals);

      expect(c.sharesLanguage, isTrue);
      final shared = c.rows
          .where((r) => r.bucket == WordCompareBucket.both && r.nowhereElse)
          .map((r) => r.strongs)
          .toSet();
      // συνευωχέομαι, ὑπέρογκος, ἐμπαίκτης — the words the commentaries
      // cite for the literary relationship between the two letters.
      expect(shared, {'G4910', 'G5246', 'G1703'});

      // Every corpus total must be at least the pair's own tally, or the
      // two sources are counting differently and the claim is unsound.
      for (final r in c.rows) {
        final t = r.corpusTotal;
        if (t != null) {
          expect(r.combined, lessThanOrEqualTo(t), reason: r.strongs);
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a Hebrew book against a Greek one says so instead of printing 0',
        () async {
      final c = compareWordLists(await listFor('Genesis'), await listFor('John'));
      expect(c.sharesLanguage, isFalse);
      expect(c.bothCount, 0);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
