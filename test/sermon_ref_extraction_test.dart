/// WHAT THE SERMON REFERENCE INDEX MUST NOT DO, and what it had been
/// doing.
///
/// `refs.json` is derived from the corpus by
/// `scripts/extract_sermon_refs.py`. Nothing in Dart re-runs it, so a
/// wrong rule in that script becomes a wrong link on the reader's
/// screen with nothing between. Three defects were fixed on
/// 2026-09-03, and this file pins each one from the shipped asset.
///
///   1. **"Mark 5" was not the Gospel.** Sermon 339 is "Seven Marks of
///      a Regenerated Christian" and its heading enumerated "Mark 5:
///      Does Not Sin (1 John 3:9); Mark 6…; Mark 7…" — the fifth, sixth
///      and seventh MARKS. The index filed the sermon under three
///      chapters of a Gospel it never opens.
///   2. **"Deuteronomy 43 times" was arithmetic.** So was "Is 50%
///      enough?", which is the verb `is` plus a percentage and reached
///      the index as Isaiah 50.
///   3. **A one-chapter book is cited without a chapter.** "2 John,
///      verse 7" is how the only citation form those five books have,
///      and the extractor required digits after the alias — so sermon
///      238, which is built on 2 John, reached the index with NO
///      references at all.
///
/// TWO REPAIRS WERE REJECTED UPSTREAM and are pinned here by example,
/// because a rejected repair that is not written down gets re-derived:
///
///   * "a bare chapter followed by a colon carrying no digit is a
///     label" — it fits 94 matches across the corpus and 91 of them are
///     genuine, because a colon before a quotation is how a preacher
///     cites: "Paul says in Romans 11: 'Note then the goodness…'". It
///     would have cost 44 real pairs to repair 3.
///   * "ignore `#` heading lines" — 19 genuine keys against the same 3.
///
/// The repair that was taken is per-verse and in the DATA: the
/// editorial heading spells its numerals ("Mark five"), so the
/// extractor — which needs digits after a book name — indexes nothing
/// there. No preacher's words were touched.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

late final Map<String, dynamic> refs;
late final Map<String, List<String>> byVerse;
late final Map<String, List<String>> bySermon;

List<String> _strings(Object? v) =>
    (v as List).cast<String>().toList(growable: false);

void main() {
  setUpAll(() {
    refs = jsonDecode(File('assets/sermons/refs.json').readAsStringSync())
        as Map<String, dynamic>;
    byVerse = (refs['byVerse'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, _strings(v)));
    bySermon = (refs['bySermon'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, _strings(v)));
  });

  group('a book name is sometimes an ordinary word', () {
    test('339 is not filed under the Gospel of Mark', () {
      expect(bySermon['339'], isNotNull);
      for (final key in bySermon['339']!) {
        expect(key.startsWith('Mark'), isFalse,
            reason: '339 enumerates seven MARKS of a regenerated '
                'Christian and opens no Gospel; it is filed under $key');
      }
      // ...and it still carries the references it really makes. An
      // over-broad repair would have emptied the sermon instead.
      expect(bySermon['339'], contains('1 John 3:9'));
      expect(bySermon['339'], contains('1 John 5:18'));
      expect(bySermon['339'], contains('1 John 4:7'));
    });

    test('the Gospel of Mark still has the sermons that do open it', () {
      // The other half. A repair that took Mark 5 and 7 away from
      // everybody would pass the test above and be much worse.
      expect(byVerse['Mark 5'], isNotEmpty);
      expect(byVerse['Mark 7'], isNotEmpty);
    });

    test('the enumerated marks are spelled, so the extractor cannot see '
        'them', () {
      // The repair lives in the DATA. If someone re-digitises that
      // heading, the index quietly regains three false chapters, and
      // this is the only place that would notice.
      final body = File('assets/sermons/en/339.txt').readAsStringSync();
      expect(body, contains('Mark one:'));
      expect(body, contains('Mark five:'));
      expect(body, isNot(contains('Mark 5:')));
      expect(body, isNot(contains('Mark 1:')));
    });
  });

  group('a number that belongs to the next word', () {
    test('"Deuteronomy 43 times" and "Is 50% enough" are not citations',
        () {
      expect(bySermon['004'] ?? const <String>[],
          isNot(contains('Deuteronomy 43')));
      expect(bySermon['424'] ?? const <String>[], isNot(contains('Isaiah 50')));
      // Deuteronomy has 34 chapters, so 43 was always impossible; the
      // canon check caught it. Isaiah 50 exists, which is why the guard
      // is needed and the canon check is not enough.
      expect(byVerse.containsKey('Deuteronomy 43'), isFalse);
    });

    test('a real citation next to a number still survives', () {
      // The guard applies only to a BARE chapter. "Isaiah 27:3" is a
      // citation whatever follows it.
      expect(byVerse['Isaiah 53'], isNotEmpty,
          reason: 'the unit guard is eating real references');
    });
  });

  group('a one-chapter book is cited without a chapter', () {
    test('238 is no longer a sermon with no references', () {
      expect(bySermon['238'], isNotNull);
      expect(bySermon['238'], contains('2 John 7'),
          reason: 'the sermon reads "2 John, the Second Letter of John, '
              'verse 7" and was indexed under nothing at all');
    });

    test('the four others found the same way are all real', () {
      // Read back against the corpus one at a time before being pinned
      // here, because a count is not a check.
      expect(bySermon['012'], contains('2 John 3'));
      expect(bySermon['320'], contains('Jude 23'));
      expect(bySermon['367'], contains('Jude 3'));
      expect(bySermon['023'], contains('Jude 7'));
    });

    test('the key is `Book N`, the shape the reader\'s parser re-reads',
        () {
      // `reference_parser.dart`'s `_singleChapterBooks` turns "Jude 14"
      // into chapter 1 verse 14. Emitting `2 John 1:7` here would have
      // been a second spelling for one idea — which is exactly how 42
      // references came to be stored and never shown.
      for (final key in byVerse.keys) {
        for (final book in const [
          'Obadiah', 'Philemon', '2 John', '3 John', 'Jude',
        ]) {
          if (!key.startsWith('$book ')) continue;
          expect(key, isNot(contains(':')),
              reason: '$key uses a chapter:verse shape for a book with '
                  'one chapter');
        }
      }
    });

    test('"Obadiah 21" is not in the index, and that is the point', () {
      // The false positive this rule produced before it required a word
      // boundary after the alias: sermon 034 says "…under the
      // OBligation to forgive… verse 21 or 22, Peter says…", and `Ob`
      // is the abbreviation for Obadiah. Found by reading all five new
      // references back against the corpus rather than trusting that
      // five additions meant five citations.
      expect(bySermon['034'] ?? const <String>[],
          isNot(contains('Obadiah 21')));
    });
  });

  test('no sermon in the corpus is left with no references at all', () {
    // 238 was the last one. If this ever fails again it is the same
    // class of defect: a citation form the extractor cannot see.
    final index = (jsonDecode(
            File('assets/sermons/index.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    final empty = [
      for (final s in index)
        if ((bySermon[s['id'] as String] ?? const <String>[]).isEmpty)
          s['id'] as String
    ];
    expect(empty, isEmpty,
        reason: 'these sermons cite scripture the index cannot see');
  });
}
