/// Task #290 — the word-distribution chart's arithmetic.
///
/// The widgets are checked by screenshot; this file covers the part a
/// screenshot cannot show, and in particular the two facts the feature
/// rests on:
///
///   * the per-book map must be able to carry HEBREW, because the
///     Eagle's View Greek profile the Stats tab already consulted
///     returns null for every Hebrew number and sourcing the chart from
///     it would have meant no chart for half the Bible;
///   * a label-less strip must keep its empty books, or the bars slide
///     left and the canonical ruler they are read against disappears.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/book_groups.dart' show oldTestamentBooks;
import 'package:seeksparks/utils/search_scope.dart' show kScopeAllBooks;
import 'package:seeksparks/utils/search_stats.dart';

void main() {
  group('buildDistributionFromCounts', () {
    test('keeps canonical order regardless of the map\'s iteration order',
        () {
      final d = buildDistributionFromCounts(
        counts: const {'Revelation': 3, 'Genesis': 1, 'John': 2},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      expect(
        d.books.map((b) => b.englishBook),
        ['Genesis', 'John', 'Revelation'],
      );
    });

    test('includeEmpty gives every book a fixed slot', () {
      final d = buildDistributionFromCounts(
        counts: const {'John': 2},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
        includeEmpty: true,
      );
      // The strip's whole legibility depends on this: 66 slots, always,
      // so a bar's position names its book.
      expect(d.books, hasLength(kScopeAllBooks.length));
      expect(d.books[kScopeAllBooks.indexOf('John')].count, 2);
      expect(d.books[kScopeAllBooks.indexOf('Genesis')].count, 0);
      // Empty books must not inflate anything derived from the list.
      expect(d.total, 2);
      expect(d.peak, 2);
      expect(d.bookCount, 1);
    });

    test('omitting the empty books does not change the numbers', () {
      const counts = {'Genesis': 4, 'Matthew': 6};
      final withEmpty = buildDistributionFromCounts(
        counts: counts,
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
        includeEmpty: true,
      );
      final without = buildDistributionFromCounts(
        counts: counts,
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      // "In 2 of 66 books" has to read the same under both renderings —
      // that is why bookCount is counted rather than taken from length.
      expect(withEmpty.bookCount, without.bookCount);
      expect(withEmpty.total, without.total);
      expect(withEmpty.oldTestament, without.oldTestament);
      expect(withEmpty.newTestament, without.newTestament);
      expect(withEmpty.peak, without.peak);
      expect(without.books, hasLength(2));
    });

    test('a Hebrew word distributes across the Hebrew scriptures', () {
      // The case the ticket assumed was impossible. H3068 (יהוה) does
      // not appear in the Greek profile at all; the concordance index
      // has it, so the chart does too.
      final d = buildDistributionFromCounts(
        counts: const {'Genesis': 165, 'Psalms': 695, 'Isaiah': 450},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      expect(d.total, 1310);
      expect(d.oldTestament, 1310);
      expect(d.newTestament, 0);
      expect(d.peak, 695);
      expect(d.books.every((b) => b.isOldTestament), isTrue);
    });

    test('splits a word that crosses both corpora', () {
      final d = buildDistributionFromCounts(
        counts: const {'Genesis': 2, 'John': 5},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      expect(d.oldTestament, 2);
      expect(d.newTestament, 5);
      expect(d.books.first.isOldTestament, isTrue);
      expect(d.books.last.isOldTestament, isFalse);
    });

    test('an unrecognised book name is dropped, not appended', () {
      // A stale or apocryphal reference must not be presented as
      // canonical by landing at the end of the canon.
      final d = buildDistributionFromCounts(
        counts: const {'Genesis': 1, 'Sirach': 9, '': 4},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      expect(d.books.map((b) => b.englishBook), ['Genesis']);
      expect(d.total, 1);
    });

    test('a negative count is treated as absent, not subtracted', () {
      final d = buildDistributionFromCounts(
        counts: const {'Genesis': -5, 'John': 3},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      expect(d.total, 3);
      expect(d.bookCount, 1);
    });

    test('an empty map is empty, and peak stays safe to divide by', () {
      final d = buildDistributionFromCounts(
        counts: const {},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
        includeEmpty: true,
      );
      expect(d.isEmpty, isTrue);
      expect(d.bookCount, 0);
      // The strip guards this itself, but a zero peak reaching a
      // divisor anywhere would paint NaN-height bars.
      expect(d.peak, 0);
    });
  });

  group('booksByCount', () {
    test('ranks heaviest first and never lists a book at zero', () {
      final d = buildDistributionFromCounts(
        counts: const {'Genesis': 4, 'John': 40, 'Acts': 65},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
        includeEmpty: true,
      );
      expect(
        booksByCount(d).map((b) => b.englishBook),
        ['Acts', 'John', 'Genesis'],
      );
    });

    test('ties keep canonical order so the chart does not reshuffle', () {
      final d = buildDistributionFromCounts(
        counts: const {'Mark': 7, 'Matthew': 7, 'Luke': 7},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      expect(
        booksByCount(d).map((b) => b.englishBook),
        ['Matthew', 'Mark', 'Luke'],
      );
    });
  });

  group('buildDistribution still agrees with the count-based form', () {
    test('same answer from a hit list and from a tally', () {
      final fromHits = buildDistribution(
        hitBooks: const ['John', 'John', 'Genesis'],
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      final fromCounts = buildDistributionFromCounts(
        counts: const {'John': 2, 'Genesis': 1},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
      );
      expect(fromHits.total, fromCounts.total);
      expect(fromHits.peak, fromCounts.peak);
      expect(
        fromHits.books.map((b) => '${b.englishBook}:${b.count}'),
        fromCounts.books.map((b) => '${b.englishBook}:${b.count}'),
      );
    });
  });
}
