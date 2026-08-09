import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/morph_search_service.dart';
import 'package:seeksparks/utils/morph_query.dart';
import 'package:seeksparks/utils/morphology.dart';

const _gk = MorphScheme.greek;
const _sem = MorphScheme.semitic;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(MorphSearchService.clearCache);

  group('against the shipped corpus', () {
    test('Genesis 1:1 בָּרָא is found by "Qal perfect"', () async {
      const q = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'V'},
        MorphSlot.stem: {'q'},
        MorphSlot.conjugation: {'p'},
      });
      final r = await MorphSearchService.run(q, books: ['Genesis']);
      expect(r.total, 698);
      final first = r.hits.first;
      expect(first.chapter, 1);
      expect(first.verse, 1);
      expect(first.word.strongs, 'H1254'); // בָּרָא
      expect(first.morphemeIndex, 0);
    });

    test('Matthew 2:8 is the NT\'s first aorist active imperative',
        () async {
      const q = MorphQuery(scheme: _gk, constraints: {
        MorphSlot.pos: {'V-'},
        MorphSlot.tense: {'A'},
        MorphSlot.voice: {'A'},
        MorphSlot.mood: {'D'},
      });
      final r = await MorphSearchService.run(
        q,
        books: MorphSearchService.booksFor(MorphScope.testament, '', _gk),
      );
      expect(r.total, 602);
      expect(r.hits.first.book, 'Matthew');
      expect(r.hits.first.chapter, 2);
      expect(r.hits.first.verse, 8);
    });

    test('the per-morpheme rule changes the answer by 892 words',
        () async {
      // "feminine verb". A word like HC/Vqv2mp/Sp3fs is a MASCULINE
      // imperative with a feminine object suffix; treating the code as
      // one bag of features would call it a hit. This is the single
      // correctness claim the whole matcher rests on, so it is pinned
      // against the real text rather than a fixture.
      const q = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'V'},
        MorphSlot.gender: {'f'},
      });
      final r = await MorphSearchService.run(
        q,
        books: MorphSearchService.booksFor(MorphScope.testament, '', _sem),
        limit: 1,
      );
      // Both figures rose in v1.6.92, when reading the Qere gave 1,334
      // more words a parse: 6,129 -> 6,192 hits over 299,556 -> 300,807
      // parsed words. They are measurements of the shipped corpus, so
      // they move whenever its coverage does.
      expect(r.total, 6192);
      expect(r.scanned, 300807);

      var naive = 0;
      for (final code in ['HC/Vqv2mp/Sp3fs', 'HR/Vqc/Sp3fs']) {
        final w = MorphSearchService.parse(code)!;
        expect(q.match(w), -1);
        if (w.morphemes.any((m) => m.pos == 'V') &&
            w.morphemes.any((m) => m.slots[MorphSlot.gender] == 'f')) {
          naive++;
        }
      }
      expect(naive, 2, reason: 'both would be false positives');
    });

    test('Aramaic Aphel verbs exist and live where Aramaic does',
        () async {
      // Aphel has no Hebrew counterpart; before the Aramaic stem table
      // these 24 words showed a verb with no binyan at all.
      const q = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'V'},
        MorphSlot.stem: {'a'},
      });
      final r = await MorphSearchService.run(
        q,
        books: MorphSearchService.booksFor(MorphScope.testament, '', _sem),
      );
      expect(r.total, 24);
      expect(r.hits.map((h) => h.book).toSet(), {'Ezra', 'Daniel'});
      expect(r.hits.every((h) => h.parsed.aramaic), isTrue);
    });

    test('scope narrows the scan', () async {
      const q = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'V'},
      });
      final book = await MorphSearchService.run(q, books: ['Genesis']);
      final chapter =
          await MorphSearchService.run(q, books: ['Genesis'], chapter: 1);
      expect(chapter.total, lessThan(book.total));
      expect(chapter.hits.every((h) => h.chapter == 1), isTrue);
    });

    test('results are in canonical order, not string order', () async {
      const q = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'V'},
      });
      final r = await MorphSearchService.run(q, books: ['Genesis'],
          limit: 100000);
      // A string sort puts "10:1" before "9:1"; a reader would notice.
      var last = 0;
      for (final h in r.hits) {
        final key = h.chapter * 1000 + h.verse;
        expect(key, greaterThanOrEqualTo(last));
        last = key;
      }
      expect(r.hits.any((h) => h.chapter > 9), isTrue);
    });

    test('the cap limits the list but not the count', () async {
      const q = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'V'},
      });
      final r =
          await MorphSearchService.run(q, books: ['Genesis'], limit: 5);
      expect(r.hits, hasLength(5));
      expect(r.total, greaterThan(5));
      expect(r.truncated, isTrue);
    });

    test('facets over the real text agree with re-running the query',
        () async {
      const q = MorphQuery(scheme: _sem, constraints: {
        MorphSlot.pos: {'V'},
        MorphSlot.stem: {'q'},
        MorphSlot.conjugation: {'p'},
      });
      final r = await MorphSearchService.run(q, books: ['Genesis']);
      expect(r.facets.hits, r.total);

      // The facet promises what switching one slot would yield; check it
      // by actually switching that slot.
      final promised = r.facets.countOf(MorphSlot.conjugation, 'i');
      final actual = await MorphSearchService.run(
        q.withSlot(MorphSlot.conjugation, {'i'}),
        books: ['Genesis'],
      );
      expect(promised, actual.total);
      expect(promised, greaterThan(0));
    });

    test('a Greek query finds nothing in the Hebrew Bible', () async {
      const q = MorphQuery(scheme: _gk, constraints: {
        MorphSlot.pos: {'V-'},
      });
      final r = await MorphSearchService.run(q, books: ['Genesis']);
      expect(r.total, 0);
      expect(r.scanned, 0);
    });
  });
}
