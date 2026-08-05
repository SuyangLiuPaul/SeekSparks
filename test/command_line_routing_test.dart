/// 2026-08 (SeekSparks): pins the command line's navigate-vs-search
/// decision.
///
/// The Workbench command line is modelled on BibleWorks': one box that
/// both navigates and searches. `parseReference` is the discriminator —
/// anything it resolves is treated as navigation, everything else falls
/// through to search. That makes its behaviour on ambiguous input a
/// user-visible contract, so it is worth locking down.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/reference_parser.dart';

void main() {
  group('command line routes to NAVIGATE', () {
    for (final input in [
      'Gen 1:1',
      'Genesis 1:1',
      'John 3:16',
      'John 3',
      '1 Corinthians 13:4',
      'Rev 22:21',
    ]) {
      test('"$input" parses as a reference', () {
        expect(parseReference(input), isNotNull,
            reason: '"$input" should navigate, not search');
      });
    }

    test('a chapter-only reference resolves without a verse', () {
      final ref = parseReference('John 3');
      expect(ref, isNotNull);
      expect(ref!.englishBook, 'John');
      expect(ref.chapter, 3);
      expect(ref.verseStart, isNull,
          reason: 'chapter-only means the whole chapter');
    });

    test('a verse range keeps both ends', () {
      final ref = parseReference('John 3:16-18');
      expect(ref, isNotNull);
      expect(ref!.verseStart, 16);
      expect(ref.verseEnd, 18);
    });

    test('Chinese book names navigate too', () {
      final ref = parseReference('约翰福音 3:16');
      expect(ref, isNotNull);
      expect(ref!.englishBook, 'John',
          reason: 'book is canonicalised to English for lexicon lookups');
      expect(ref.chapter, 3);
      expect(ref.verseStart, 16);
    });
  });

  group('command line routes to SEARCH', () {
    // Deliberate product call: a bare word is far more likely to be
    // something the reader wants FOUND than a request to jump to that
    // book's first chapter. Requiring a chapter number makes the
    // navigate intent explicit.
    for (final input in [
      'love',
      'faith hope love',
      'in the beginning',
      'G25',
      'G25 AND G26',
      'righteousness',
    ]) {
      test('"$input" is not a reference', () {
        expect(parseReference(input), isNull,
            reason: '"$input" should search, not navigate');
      });
    }
  });

  group('degenerate input is safe', () {
    for (final input in ['', '   ', ':', '::', '1:1', '999']) {
      test('"$input" does not throw', () {
        expect(() => parseReference(input), returnsNormally);
      });
    }
  });
}
