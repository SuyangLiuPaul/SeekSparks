// The AI answers with references; the reader has an edition that may
// not contain them. `resolveAiRefs` is the join, and every case below
// is one that used to live inside the standalone SearchPage's build
// method where nothing could reach it.

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/ai_bible_search_service.dart';
import 'package:seeksparks/utils/ai_ref_resolution.dart';

AiBibleRef _ref(String book, int chapter, int start, [int? end]) => AiBibleRef(
      book: book,
      chapter: chapter,
      verseStart: start,
      verseEnd: end ?? start,
      reason: 'because',
    );

Verse _verse(String book, int chapter, int verse) =>
    Verse(book: book, chapter: chapter, verse: verse, text: 'text');

void main() {
  group('resolveAiRefs', () {
    test('resolves a single-verse reference to its verse', () {
      final r = resolveAiRefs(
        refs: [_ref('John', 3, 16)],
        verses: [_verse('John', 3, 15), _verse('John', 3, 16)],
      );
      expect(r.verses.single.verse, 16);
      expect(r.unresolvedDisplays, isEmpty);
      expect(r.outOfScope, 0);
    });

    test('a verse range resolves to every verse in it', () {
      final r = resolveAiRefs(
        refs: [_ref('Matthew', 5, 3, 5)],
        verses: [
          for (var i = 1; i <= 6; i++) _verse('Matthew', 5, i),
        ],
      );
      expect(r.verses.map((v) => v.verse), [3, 4, 5]);
    });

    test('overlapping references do not duplicate a verse', () {
      final verses = [for (var i = 1; i <= 12; i++) _verse('Matthew', 5, i)];
      final r = resolveAiRefs(
        refs: [_ref('Matthew', 5, 3, 12), _ref('Matthew', 5, 9)],
        verses: verses,
      );
      expect(r.verses.length, 10);
      expect(r.kept.length, 2, reason: 'both references stay on screen');
    });

    test('a reference the edition lacks is kept, marked unresolved', () {
      final r = resolveAiRefs(
        refs: [_ref('John', 3, 16), _ref('Tobit', 4, 7)],
        verses: [_verse('John', 3, 16)],
      );
      expect(r.kept.length, 2, reason: 'never silently edit the AI answer');
      expect(r.unresolvedDisplays, {'Tobit 4:7'});
      expect(r.verses.single.book, 'John');
    });

    test('a chapter present but a verse missing is unresolved, not empty', () {
      // Versification: the edition has John 3 but stops at verse 15.
      final r = resolveAiRefs(
        refs: [_ref('John', 3, 16)],
        verses: [_verse('John', 3, 15)],
      );
      expect(r.unresolvedDisplays, {'John 3:16'});
      expect(r.verses, isEmpty);
    });

    test('scope drops out-of-book references and counts them', () {
      final r = resolveAiRefs(
        refs: [_ref('John', 3, 16), _ref('Romans', 5, 8), _ref('Acts', 2, 38)],
        verses: [_verse('John', 3, 16)],
        inScope: (ref) => ref.book == 'John',
      );
      expect(r.kept.map((k) => k.book), ['John']);
      expect(r.outOfScope, 2);
    });

    test('a verse-key limit keeps a range that overlaps it at all', () {
      // The workbench limit is a set of verse keys (`l gen 1-11`), so a
      // reference that straddles the edge has to survive: dropping
      // Matthew 5:3-12 because verse 12 is outside would hide a
      // passage the reader can see most of.
      const limit = {'Matthew-5-10', 'Matthew-5-11'};
      bool covered(AiBibleRef ref) {
        for (var v = ref.verseStart; v <= ref.verseEnd; v++) {
          if (limit.contains('${ref.book}-${ref.chapter}-$v')) return true;
        }
        return false;
      }

      final r = resolveAiRefs(
        refs: [_ref('Matthew', 5, 3, 12), _ref('Matthew', 6, 25)],
        verses: [for (var i = 1; i <= 12; i++) _verse('Matthew', 5, i)],
        inScope: covered,
      );
      expect(r.kept.length, 1);
      expect(r.outOfScope, 1);
    });

    test('a localized edition still matches canonical English books', () {
      // The AI always answers in canonical English; the corpus may be
      // 约翰福音. This is the mapping that makes the feature work at all
      // for a Chinese reader.
      final r = resolveAiRefs(
        refs: [_ref('John', 3, 16)],
        verses: [_verse('约翰福音', 3, 16)],
      );
      expect(r.verses.single.book, '约翰福音');
      expect(r.unresolvedDisplays, isEmpty);
    });

    test('scope matches canonical English against a localized corpus', () {
      final r = resolveAiRefs(
        refs: [_ref('John', 3, 16), _ref('Romans', 5, 8)],
        verses: [_verse('约翰福音', 3, 16), _verse('罗马书', 5, 8)],
        inScope: (ref) => ref.book == 'John',
      );
      expect(r.verses.single.book, '约翰福音');
      expect(r.outOfScope, 1);
    });

    test('an empty answer resolves to nothing without throwing', () {
      final r = resolveAiRefs(refs: const [], verses: [_verse('John', 3, 16)]);
      expect(r.isEmpty, isTrue);
      expect(r.outOfScope, 0);
    });
  });
}
