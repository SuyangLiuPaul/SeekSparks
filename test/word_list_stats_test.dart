import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/utils/search_stats.dart';
import 'package:seeksparks/utils/word_list.dart';

OriginalWord w(String text, String strongs, {String? translit}) =>
    OriginalWord(text: text, strongs: strongs, translit: translit);

void main() {
  group('buildWordList', () {
    test('counts by Strong\'s number, not by surface form', () {
      // The whole point: three inflections of one verb are ONE word.
      final list = buildWordList([
        w('ἠγάπησεν', 'G25'),
        w('ἀγαπᾷ', 'G25'),
        w('ἀγαπῶν', 'G25'),
        w('κόσμον', 'G2889'),
      ]);
      expect(list, hasLength(2));
      expect(list.first.strongs, 'G25');
      expect(list.first.count, 3);
    });

    test('reports the most frequent surface form', () {
      final list = buildWordList([
        w('ἀγαπᾷ', 'G25'),
        w('ἠγάπησεν', 'G25'),
        w('ἠγάπησεν', 'G25'),
      ]);
      expect(list.single.form, 'ἠγάπησεν');
    });

    test('words with no number are skipped', () {
      final list = buildWordList([w('—', ''), w('θεός', 'G2316')]);
      expect(list, hasLength(1));
      expect(list.single.strongs, 'G2316');
    });

    test('number matching is case-insensitive and trimmed', () {
      final list = buildWordList([w('a', 'g25'), w('b', ' G25 ')]);
      expect(list, hasLength(1));
      expect(list.single.count, 2);
    });

    test('minCount filters', () {
      final list = buildWordList(
        [w('a', 'G1'), w('b', 'G2'), w('b2', 'G2')],
        minCount: 2,
      );
      expect(list.map((e) => e.strongs), ['G2']);
    });

    test('frequency sort, commonest first, stable on ties', () {
      final list = buildWordList([
        w('a', 'G1'),
        w('b', 'G2'),
        w('c', 'G3'),
      ], sort: WordListSort.frequency);
      // All count 1 — must stay in textual order.
      expect(list.map((e) => e.strongs), ['G1', 'G2', 'G3']);
    });

    test('rarity sort puts the hapax legomena first', () {
      final list = buildWordList([
        w('a', 'G1'), w('a', 'G1'), w('a', 'G1'),
        w('b', 'G2'),
      ], sort: WordListSort.rarity);
      expect(list.first.strongs, 'G2');
      expect(list.first.isHapax, isTrue);
    });

    test('number sort is numeric, and Hebrew precedes Greek', () {
      final list = buildWordList([
        w('a', 'G100'),
        w('b', 'G25'),
        w('c', 'H1'),
      ], sort: WordListSort.number);
      // String comparison would give G100 < G25; it must not.
      expect(list.map((e) => e.strongs), ['G25', 'G100', 'H1']);
    });

    test('strongsNumericPart pulls the digits out', () {
      expect(strongsNumericPart('G25'), 25);
      expect(strongsNumericPart('H8064'), 8064);
      expect(strongsNumericPart('nonsense'), 0);
    });

    test('summary reports total, distinct and hapax', () {
      final list = buildWordList([
        w('a', 'G1'), w('a', 'G1'),
        w('b', 'G2'),
        w('c', 'G3'),
      ]);
      final s = wordListSummary(list);
      expect(s.total, 4);
      expect(s.distinct, 3);
      expect(s.hapax, 2);
    });

    test('an empty passage yields an empty list, not a crash', () {
      expect(buildWordList(const <OriginalWord>[]), isEmpty);
      final s = wordListSummary(const []);
      expect(s.total, 0);
      expect(s.distinct, 0);
    });
  });

  group('buildDistribution', () {
    const order = ['Genesis', 'Exodus', 'Matthew', 'John', '1 John'];
    const ot = {'Genesis', 'Exodus'};

    test('counts per book in canonical order', () {
      final d = buildDistribution(
        hitBooks: ['John', 'Genesis', 'John', '1 John'],
        bookOrder: order,
        oldTestamentBooks: ot,
      );
      expect(d.books.map((b) => b.englishBook), ['Genesis', 'John', '1 John']);
      expect(d.total, 4);
      expect(d.peak, 2);
    });

    test('books with no hits are omitted, not listed as zero', () {
      final d = buildDistribution(
        hitBooks: ['John'],
        bookOrder: order,
        oldTestamentBooks: ot,
      );
      expect(d.books, hasLength(1));
    });

    test('splits the testaments', () {
      final d = buildDistribution(
        hitBooks: ['Genesis', 'Genesis', 'John'],
        bookOrder: order,
        oldTestamentBooks: ot,
      );
      expect(d.oldTestament, 2);
      expect(d.newTestament, 1);
      expect(d.oldTestamentShare, closeTo(2 / 3, 1e-9));
    });

    test('an unknown book is dropped, not appended', () {
      // A stale reference must not be presented as canonical.
      final d = buildDistribution(
        hitBooks: ['Bel and the Dragon', 'John'],
        bookOrder: order,
        oldTestamentBooks: ot,
      );
      expect(d.books.map((b) => b.englishBook), ['John']);
      expect(d.total, 1);
    });

    test('no hits gives a safe zero, not NaN', () {
      final d = buildDistribution(
        hitBooks: const [],
        bookOrder: order,
        oldTestamentBooks: ot,
      );
      expect(d.isEmpty, isTrue);
      expect(d.peak, 0);
      expect(d.oldTestamentShare, 0);
    });

    test('topBooks is descending and canonical on ties', () {
      final d = buildDistribution(
        hitBooks: ['Genesis', 'John', 'Matthew', 'Matthew'],
        bookOrder: order,
        oldTestamentBooks: ot,
      );
      final top = topBooks(d, limit: 3);
      expect(top.first.englishBook, 'Matthew');
      // Genesis and John both have 1; canonical order wins.
      expect(top.map((b) => b.englishBook), ['Matthew', 'Genesis', 'John']);
    });
  });
}
