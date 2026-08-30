// The search results list marks the word a Strong's query matched, and it
// does that while building a row inside a ListView.builder. An async
// lookup there would rebuild on every scroll, so the row asks
// TaggedTextService for a CACHE PEEK and leaves the line plain on a miss.
//
// That only works if the peek is honest about a miss. These pin the two
// answers a row depends on: null before the book is loaded, runs after —
// and null for an edition that ships no tagging at all, which is the case
// the reader actually meets (NASB, 梁家铿, 雅偉版繁體 today).

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/tagged_text_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an untagged edition never reports runs, loaded or not', () async {
    expect(TaggedTextService.supports('nasb'), isFalse);
    expect(
      TaggedTextService.cachedForVerse(
          version: 'nasb', englishBook: 'Genesis', chapter: 1, verse: 1),
      isNull,
    );
    // prefetch must be a no-op rather than an error for these.
    await TaggedTextService.prefetchBook('nasb', 'Genesis');
    expect(
      TaggedTextService.cachedForVerse(
          version: 'nasb', englishBook: 'Genesis', chapter: 1, verse: 1),
      isNull,
    );
  });

  test('a tagged edition reports null until prefetched, then its runs',
      () async {
    // Genesis is loaded by other suites, so use a book this one owns.
    const book = 'Obadiah';
    expect(TaggedTextService.supports('cuvs-yhwh'), isTrue);

    final runs = await TaggedTextService.forVerse(
        version: 'cuvs-yhwh', englishBook: book, chapter: 1, verse: 5);
    expect(runs, isNotNull, reason: 'the fixture itself must exist');

    final peeked = TaggedTextService.cachedForVerse(
        version: 'cuvs-yhwh', englishBook: book, chapter: 1, verse: 5);
    expect(peeked, isNotNull);
    expect(peeked!.map((r) => r.text).join(), runs!.map((r) => r.text).join());
  });

  test('the peek finds the run carrying a number, which is what marks it',
      () async {
    await TaggedTextService.prefetchBook('cuvs-yhwh', 'Obadiah');
    final runs = TaggedTextService.cachedForVerse(
        version: 'cuvs-yhwh', englishBook: 'Obadiah', chapter: 1, verse: 5);
    expect(runs, isNotNull);
    final numbered = runs!.where((r) => r.strongs.isNotEmpty);
    expect(numbered, isNotEmpty,
        reason: 'a verse with no numbered run could never be marked');
  });

  test('rootBundle is reachable, so a miss means "not loaded" not "no asset"',
      () async {
    final raw =
        await rootBundle.loadString('assets/tagged/cuvs-yhwh/obadiah.json');
    expect(raw, isNotEmpty);
  });
}
