/// 2026-08-17 (#313): the Related Sermons tab's classification.
///
/// The defect these guard is not a crash, it is a claim. The sermon
/// match is chapter-wide on purpose — a sermon expounding Genesis 1:1-5
/// is relevant when the reader is on Genesis 1:7 — but the old list
/// returned both kinds of hit in one undifferentiated run, so a reader
/// on Romans 8:1 was handed 49 sermons with nothing saying that most of
/// them are about some other verse. Sort order is not a label.
///
/// The last group measures the real shipped asset rather than a fixture,
/// because the number that justifies the whole tier split is a property
/// of the corpus, not of the code.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/passage_sermons.dart';

/// A hand-written reverse index in the shape `SermonRefs.byVerse` has:
/// canonical `"Book C"` / `"Book C:V"` keys to sermon ids.
const _fixture = <String, List<String>>{
  'Romans 8:1': ['a', 'b'],
  'Romans 8:5': ['b'],
  'Romans 8:6': ['b'],
  'Romans 8:28': ['c'],
  'Romans 8': ['d'],
  'Romans 9:1': ['e'],
  'Psalms 1:1': ['p1'],
  'Psalms 119:1': ['p119'],
  'Psalms 119': ['p119b'],
};

List<SermonCitation> _at(String book, int chapter, int verse) =>
    citationsInChapter(
      byVerse: _fixture,
      englishBook: book,
      chapter: chapter,
      verse: verse,
    );

void main() {
  group('which sermons the chapter turns up', () {
    test('a neighbouring chapter is not swept in', () {
      final ids = _at('Romans', 8, 1).map((c) => c.sermonId).toSet();
      expect(ids, {'a', 'b', 'c', 'd'});
      expect(ids, isNot(contains('e')));
    });

    test('the colon is what keeps Psalm 1 out of Psalm 119', () {
      // The trap a prefix match walks into: "Psalms 119:1" begins with
      // "Psalms 1" and would join every result for Psalm 1.
      final one = _at('Psalms', 1, 1).map((c) => c.sermonId).toSet();
      expect(one, {'p1'});
      final oneOneNine = _at('Psalms', 119, 1).map((c) => c.sermonId).toSet();
      expect(oneOneNine, {'p119', 'p119b'});
    });
  });

  group('what each row is allowed to claim', () {
    test('only the sermons citing the focused verse say so', () {
      final byId = {for (final c in _at('Romans', 8, 1)) c.sermonId: c};
      expect(byId['a']!.citesFocusedVerse, isTrue);
      expect(byId['b']!.citesFocusedVerse, isTrue);
      expect(byId['c']!.citesFocusedVerse, isFalse);
      expect(byId['d']!.citesFocusedVerse, isFalse);
    });

    test('moving the focused verse moves the claim', () {
      final byId = {for (final c in _at('Romans', 8, 28)) c.sermonId: c};
      expect(byId['c']!.citesFocusedVerse, isTrue);
      expect(byId['a']!.citesFocusedVerse, isFalse);
    });

    test('the verses a sermon cites are its own, ascending', () {
      final byId = {for (final c in _at('Romans', 8, 1)) c.sermonId: c};
      expect(byId['b']!.verses, [1, 5, 6]);
      expect(byId['a']!.verses, [1]);
    });

    test('a chapter-level citation names no verse and says which it is', () {
      final byId = {for (final c in _at('Romans', 8, 1)) c.sermonId: c};
      expect(byId['d']!.verses, isEmpty);
      expect(byId['d']!.citesWholeChapter, isTrue);
      expect(byId['a']!.citesWholeChapter, isFalse);
    });

    test('verse 0 is "no verse was asked about", not verse zero', () {
      // The chapter-scoped entry point. Nothing may claim to preach the
      // focused verse, because there is not one.
      final all = _at('Romans', 8, 0);
      expect(all.map((c) => c.sermonId).toSet(), {'a', 'b', 'c', 'd'});
      expect(all.every((c) => !c.citesFocusedVerse), isTrue);
    });
  });

  group('the order is the chapter\'s order, and it is stable', () {
    test('sermons on the focused verse come first', () {
      final ids = _at('Romans', 8, 28).map((c) => c.sermonId).toList();
      expect(ids.first, 'c');
    });

    test('then by the earliest verse each cites, chapter-only last', () {
      final ids = _at('Romans', 8, 1).map((c) => c.sermonId).toList();
      // a and b cite v1 (a before b on id), c cites v28, d cites no
      // verse at all and therefore has nothing to sort by.
      expect(ids, ['a', 'b', 'c', 'd']);
    });

    test('the same passage gives the same list twice', () {
      expect(_at('Romans', 8, 1).map((c) => c.sermonId).toList(),
          _at('Romans', 8, 1).map((c) => c.sermonId).toList());
    });
  });

  group('the label a row prints', () {
    SermonCitation cite(List<int> vs) => SermonCitation(
          sermonId: 'x',
          verses: vs,
          citesFocusedVerse: false,
          citesWholeChapter: false,
        );

    test('single verses are listed', () {
      expect(citedVerseLabel(cite([3])), '3');
      expect(citedVerseLabel(cite([3, 7])), '3, 7');
    });

    test('a consecutive run folds into a span', () {
      expect(citedVerseLabel(cite([1, 2, 3, 4])), '1-4');
      expect(citedVerseLabel(cite([1, 2, 9])), '1-2, 9');
      expect(citedVerseLabel(cite([1, 5, 6])), '1, 5-6');
    });

    test('no verses returns null so the caller can say something else', () {
      // Not the empty string: "cites v" with nothing after it is worse
      // than the chapter-level phrase this null selects.
      expect(citedVerseLabel(cite(const [])), isNull);
    });
  });

  group('the count line agrees with its own numbers', () {
    // v1.6.135 shipped "1 of them cite Romans 8:1" — visible on the very
    // case the feature was designed for, because one template was doing
    // duty for two independent verb agreements.
    test('a single sermon on the verse gets a singular verb', () {
      expect(sermonCountKey(total: 49, onVerse: 1),
          'sermonsCountWithVerseOne');
      expect(sermonCountKey(total: 49, onVerse: 2), 'sermonsCountWithVerse');
    });

    test('a chapter with one sermon does not say "1 sermons"', () {
      expect(sermonCountKey(total: 1, onVerse: 0), 'sermonsCountChapterOne');
      expect(sermonCountKey(total: 5, onVerse: 0), 'sermonsCountChapter');
    });

    test('the lone sermon that is also on the verse gets its own sentence',
        () {
      // "1 sermon cites Romans 8 — 1 of them cites Romans 8:1" is
      // grammatical and still reads badly; "of them" needs a them.
      expect(sermonCountKey(total: 1, onVerse: 1), 'sermonsCountOnlyOne');
    });

    test('every key it can name is a real string in all three locales', () {
      // The selector returning a key nothing defines would fall through
      // to the English default silently, in Chinese.
      for (var total = 0; total <= 3; total++) {
        for (var onVerse = 0; onVerse <= total; onVerse++) {
          final key = sermonCountKey(total: total, onVerse: onVerse);
          final entry = uiStrings[key];
          expect(entry, isNotNull, reason: '$key ($total/$onVerse) undefined');
          for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
            expect(entry![locale], isNotNull,
                reason: '$key has no $locale');
          }
        }
      }
    });
  });

  group('against the shipped corpus', () {
    late Map<String, List<String>> byVerse;

    setUpAll(() {
      final raw = File('assets/sermons/refs.json').readAsStringSync();
      final j = json.decode(raw) as Map<String, dynamic>;
      byVerse = {
        for (final e in (j['byVerse'] as Map<String, dynamic>).entries)
          e.key: (e.value as List).cast<String>(),
      };
    });

    test('Romans 8:1 is the case that justifies the split', () {
      final all = citationsInChapter(
        byVerse: byVerse,
        englishBook: 'Romans',
        chapter: 8,
        verse: 1,
      );
      // The whole point: a big list, of which a small part is actually
      // about the verse in front of the reader. If this ever inverts,
      // the tier headings are lying and should be revisited.
      expect(all.length, greaterThan(20));
      final onVerse = all.where((c) => c.citesFocusedVerse).length;
      expect(onVerse, greaterThan(0));
      expect(onVerse, lessThan(all.length));
    });

    test('every verse-level key finds its own sermon on its own verse', () {
      // The tier is not decorative: for every reference the corpus
      // records, asking at that reference must put the citing sermon in
      // the verse tier. A book-name or key-shape drift breaks this.
      var checked = 0;
      for (final entry in byVerse.entries) {
        final key = entry.key;
        final colon = key.indexOf(':');
        if (colon < 0) continue;
        final head = key.substring(0, colon);
        final space = head.lastIndexOf(' ');
        final book = head.substring(0, space);
        final chapter = int.parse(head.substring(space + 1));
        final verse = int.parse(key.substring(colon + 1));
        final hits = citationsInChapter(
          byVerse: byVerse,
          englishBook: book,
          chapter: chapter,
          verse: verse,
        );
        final onVerse =
            hits.where((c) => c.citesFocusedVerse).map((c) => c.sermonId);
        for (final id in entry.value) {
          expect(onVerse, contains(id), reason: '$key lost sermon $id');
        }
        checked++;
      }
      // Printed rather than assumed — a loop that checked nothing would
      // pass just as quietly.
      expect(checked, greaterThan(900),
          reason: 'expected ~946 verse-level keys, walked $checked');
    });

    test('no citation claims a verse it does not carry', () {
      final hits = citationsInChapter(
        byVerse: byVerse,
        englishBook: 'Matthew',
        chapter: 24,
        verse: 30,
      );
      for (final c in hits) {
        expect(c.citesFocusedVerse, c.verses.contains(30));
      }
    });
  });
}
