/// Task #308 — what a search-statistic COUNTS, and when it may be drawn.
///
/// The defect this covers is not a missing label. `concordance.json`
/// describes each word twice: an uncapped per-book map of OCCURRENCES,
/// and a VERSE list the build pipeline stops at 500 entries in canonical
/// order. The command pane tallied the second one, so for the 123 words
/// that reach the cap it drew the cap rather than the word — H3068 came
/// out as three books peaking in Exodus where the truth is 36 books
/// peaking in Jeremiah.
///
/// So these tests are about which of the two sources is a CENSUS, and
/// they freeze the H3068 numbers on both sides of that choice: the wrong
/// shape must not be reachable, and the right one must not drift.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/book_groups.dart' show oldTestamentBooks;
import 'package:seeksparks/utils/command_verb.dart' show LimitRange, LimitSpec;
import 'package:seeksparks/utils/search_scope.dart'
    show kScopeAllBooks, wholeBookScope;
import 'package:seeksparks/utils/search_stats.dart';

/// H3068 (יהוה) as `concordance.json` holds it, abridged to the books
/// that matter for the assertions below. The full map has 36 books and
/// sums to 6,521.
///
/// The paired [_yhwhListedBooks] is the entry as it was BEFORE v1.6.96,
/// when the verse list stopped inside Leviticus. That cap is gone from
/// the data, but it remains the sharpest available fixture for what a
/// tally of an incomplete list does, which is what these tests are
/// about: the two answers differ by 33 books and name different peaks.
const _yhwhByBook = {
  'Genesis': 163,
  'Exodus': 397,
  'Leviticus': 311,
  'Psalms': 687,
  'Jeremiah': 712,
};

/// The books the 500-verse prefix reaches, in the proportions it reaches
/// them: Genesis 141, Exodus 341, and eighteen verses of Leviticus before
/// the list is cut. Nothing after that exists as far as the strip is
/// concerned — Jeremiah, where the name actually peaks, is not in it.
List<String> _yhwhListedBooks() => [
      for (var i = 0; i < 141; i++) 'Genesis',
      for (var i = 0; i < 341; i++) 'Exodus',
      for (var i = 0; i < 18; i++) 'Leviticus',
    ];

void main() {
  group('a distribution declares its unit', () {
    test('the secondary count is named as the other unit', () {
      final d = buildDistributionFromCounts(
        counts: const {'John': 27},
        secondaryCounts: const {'John': 37},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
        unit: HitUnit.verses,
      );
      expect(d.unit, HitUnit.verses);
      expect(d.secondaryUnit, HitUnit.occurrences);
      expect(d.hasSecondary, isTrue);
      // The pair the ticket was opened over: G25 in John is 27 verses and
      // 37 occurrences, and a surface showing "27" alone is read as a
      // frequency by anyone arriving from software that plots one.
      expect(d.books.single.count, 27);
      expect(d.books.single.secondary, 37);
    });

    test('no secondary map means no second number to print', () {
      final d = buildDistribution(
        hitBooks: const ['John', 'John'],
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
        unit: HitUnit.verses,
      );
      expect(d.hasSecondary, isFalse);
      expect(d.books.single.secondary, isNull);
    });

    test('a distribution is complete unless it says otherwise', () {
      final d = buildDistribution(
        hitBooks: const ['John'],
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
        unit: HitUnit.verses,
      );
      expect(d.partial, isFalse);
    });
  });

  group('strongsDistribution draws whichever source is a census', () {
    test('a whole list is charted by verse, with occurrences beside it', () {
      final d = strongsDistribution(
        listedBooks: const ['John', 'John', '1 John'],
        occurrencesByBook: const {'John': 37, '1 John': 5},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      // bwh23's default plot, and what the list under the chart holds.
      expect(d.unit, HitUnit.verses);
      expect(d.partial, isFalse);
      expect(d.books.first.count, 2);
      expect(d.books.first.secondary, 37);
    });

    test('an incomplete list is charted by occurrence instead', () {
      // No caller reaches this since v1.6.96: the only remaining cause
      // of truncation is a cut wildcard, and a wildcard spans many
      // numbers so no single per-book map exists for it. The branch is
      // kept because it is the honest answer to the inputs, and the
      // function's contract is to answer all four combinations.
      final d = strongsDistribution(
        listedBooks: _yhwhListedBooks(),
        occurrencesByBook: _yhwhByBook,
        listTruncated: true,
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      expect(d.unit, HitUnit.occurrences);
      // Drawable: the occurrence map has no cap in it.
      expect(d.partial, isFalse);
      expect(booksByCount(d).first.englishBook, 'Jeremiah');
      expect(d.peak, 712);
      expect(d.bookCount, _yhwhByBook.length);
    });

    test('the capped VERSE tally, if it were drawn, would be wrong', () {
      // Not a defence of the old behaviour — a proof that the two answers
      // genuinely differ, so the branch above is load-bearing rather than
      // decorative. This is the shape the strip used to draw.
      final wrong = buildDistribution(
        hitBooks: _yhwhListedBooks(),
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
        unit: HitUnit.verses,
      );
      expect(booksByCount(wrong).first.englishBook, 'Exodus');
      expect(wrong.peak, 341);
      expect(wrong.bookCount, 3);
    });

    test('a composed expression over capped lists is drawn as nothing', () {
      // `H3068 AND H430`: set algebra over two prefixes, with no uncapped
      // total anywhere to fall back on. Neither unit is a census, so the
      // surface is told to say so rather than chart a sample.
      final d = strongsDistribution(
        listedBooks: _yhwhListedBooks(),
        listTruncated: true,
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      expect(d.partial, isTrue);
    });

    test('a scoped result never borrows the whole-Bible occurrence map', () {
      // The map describes 66 books; the listed verses describe the ones
      // the limit left. Printing them side by side is the unit mixing
      // this function exists to stop.
      final d = strongsDistribution(
        listedBooks: const ['John', 'John'],
        occurrencesByBook: const {'John': 37, 'Genesis': 165},
        scoped: true,
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      expect(d.unit, HitUnit.verses);
      expect(d.hasSecondary, isFalse);
      expect(d.bookCount, 1);
    });

    test('a scoped result over a capped entry is a sample, and says so', () {
      final d = strongsDistribution(
        listedBooks: const ['Genesis', 'Genesis'],
        occurrencesByBook: _yhwhByBook,
        listTruncated: true,
        scoped: true,
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      expect(d.partial, isTrue);
    });
  });

  group('wholeBookScope', () {
    test('whole books resolve, so the count can come from the map', () {
      final spec = LimitSpec(
        const [LimitRange('Jeremiah'), LimitRange('Isaiah')],
        'Jeremiah, Isaiah',
      );
      expect(wholeBookScope(spec), {'Jeremiah', 'Isaiah'});
    });

    test('a chapter range does not, because the map cannot be cut', () {
      final spec = LimitSpec(
        const [LimitRange('Jeremiah', firstChapter: 1, lastChapter: 5)],
        'Jeremiah 1–5',
      );
      expect(wholeBookScope(spec), isNull);
    });

    test('one chapter range spoils the whole set', () {
      final spec = LimitSpec(
        const [LimitRange('Isaiah'), LimitRange('Jeremiah', firstChapter: 3)],
        'Isaiah, Jeremiah 3',
      );
      expect(wholeBookScope(spec), isNull);
    });

    test('a Verse List Manager limit has no spec at all', () {
      expect(wholeBookScope(null), isNull);
    });
  });
}
