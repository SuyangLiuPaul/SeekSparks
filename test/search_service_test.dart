/// 2026-08-04 (Workbench): unit tests for `SearchService.scanText` —
/// the text-scan half of the search engine extracted from SearchPage
/// so the standalone SearchPage and the Workbench command pane share
/// one implementation. Pure logic, no assets, no binding.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/search_service.dart';

void main() {
  const verses = [
    Verse(book: 'Exodus', chapter: 20, verse: 3, text: 'no other gods'),
    Verse(
        book: 'Genesis',
        chapter: 1,
        verse: 1,
        text: 'In the beginning God created'),
    Verse(book: 'Genesis', chapter: 1, verse: 3, text: 'Let there be light'),
    Verse(book: 'Genesis', chapter: 2, verse: 1, text: 'It was finished'),
  ];
  // MainProvider precomputes sanitized, lowercased, WHITESPACE-STRIPPED
  // keys per verse; the fixture mirrors that contract exactly.
  final searchKeys =
      verses.map((v) => v.text.replaceAll(' ', '').toLowerCase()).toList();
  const bookOrder = {'Genesis': 1, 'Exodus': 2};

  group('SearchService.scanText', () {
    test('matches sort canonically: book order, then chapter/verse', () {
      final r = SearchService.scanText(
        verses: verses,
        searchKeys: searchKeys,
        query: 'god',
        bookOrder: bookOrder,
        searchAll: true,
      );
      // 'god' hits Genesis 1:1 ('God') and Exodus 20:3 ('gods'); the
      // list order in the fixture is intentionally wrong to prove the
      // canonical re-sort.
      expect(r.matches.map((v) => '${v.book} ${v.chapter}:${v.verse}'),
          ['Genesis 1:1', 'Exodus 20:3']);
      expect(r.bookCounts.keys.toList(), ['Genesis', 'Exodus']);
      expect(r.bookCounts.values.toList(), [1, 1]);
      expect(r.scannedCount, 4);
    });

    test('query normalization strips spaces and case', () {
      final r = SearchService.scanText(
        verses: verses,
        searchKeys: searchKeys,
        query: 'Let There',
        bookOrder: bookOrder,
        searchAll: true,
      );
      expect(r.matches.single.verse, 3);
    });

    test('filterBook scopes the scan (and the scan count)', () {
      final r = SearchService.scanText(
        verses: verses,
        searchKeys: searchKeys,
        query: 'god',
        bookOrder: bookOrder,
        filterBook: 'Exodus',
        searchAll: true,
      );
      expect(r.matches.single.book, 'Exodus');
      expect(r.scannedCount, 1);
    });

    test('currentBook scopes the scan when searchAll is false', () {
      final r = SearchService.scanText(
        verses: verses,
        searchKeys: searchKeys,
        query: 'god',
        bookOrder: bookOrder,
        currentBook: 'Genesis',
      );
      expect(r.matches, hasLength(1));
      expect(r.matches.single.book, 'Genesis');
    });

    test('no match yields empty results but still counts the scan', () {
      final r = SearchService.scanText(
        verses: verses,
        searchKeys: searchKeys,
        query: 'zzz-not-present',
        bookOrder: bookOrder,
        searchAll: true,
      );
      expect(r.matches, isEmpty);
      expect(r.bookCounts, isEmpty);
      expect(r.scannedCount, 4);
    });
  });
}
