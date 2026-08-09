// The reader's chapter-and-verse is not the original's (task #304, check 9).
//
// `assets/originals` is numbered in the Masoretic tradition for the Hebrew
// Bible and the critical text for the Greek; every edition we ship is
// numbered in the English one. `OriginalsService` joined them on the
// reader's own key, so English Psalm 3:1 was handed the psalm's heading
// instead of its first line and English Joel 2:28 was handed nothing.
// Measured over the corpus: 1,823 references resolved to another verse,
// 152 to none.
//
// The table these tests guard is DERIVED, not asserted — see
// `tools/derive_versification.py`. So the tests do two separate jobs:
// pin the anchors a reader would notice, and re-prove from the shipped
// text that each mapped row is better supported than the identity it
// replaced. 2,043 tests passed with this defect live; a green suite is
// not evidence about data.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/versification.dart';

Versification _shipped() => Versification.fromJson(
    jsonDecode(File('assets/versification.json').readAsStringSync())
        as Map<String, dynamic>);

String _slug(String book) =>
    book.toLowerCase().replaceAll(' ', '_').replaceAll("'", '');

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _strongs(dynamic verse) => {
      for (final w in verse as List)
        if ((w as Map)['s'] != null) w['s'] as String,
    };

double _dice(Set<String> a, Set<String> b) =>
    (a.isEmpty || b.isEmpty) ? 0 : 2 * a.intersection(b).length / (a.length + b.length);

(int, int) _vkey(String key) {
  final parts = key.split(':');
  return (int.parse(parts[0]), int.parse(parts[1]));
}

void main() {
  group('Versification, as a lookup', () {
    final v11n = Versification.fromJson({
      'map': {
        'Psalms': {
          '3:1': ['3:1', '3:2'],
          '3:2': ['3:3'],
          '13:5': ['13:6'],
        },
      },
      'absent': {
        'Mark': ['9:44'],
      },
    });

    test('a book both traditions number alike is left alone', () {
      expect(v11n.matchesReader('Genesis'), isTrue);
      expect(v11n.originalKeys('Genesis', 1, 1), ['1:1']);
    });

    test('an unmapped verse in a mapped book maps to itself', () {
      expect(v11n.originalKeys('Psalms', 4, 4), ['4:4']);
    });

    test('a merge returns every original verse the reader verse renders', () {
      // English Psalm 3:1 carries the heading and the first line both.
      expect(v11n.originalKeys('Psalms', 3, 1), ['3:1', '3:2']);
    });

    test('a verse the original omits is reported as absent, not missing', () {
      expect(v11n.isAbsentFromOriginal('Mark', 9, 44), isTrue);
      expect(v11n.isAbsentFromOriginal('Mark', 9, 45), isFalse);
    });

    test('the reverse direction names a reference the reader can open', () {
      expect(v11n.readerKey('Psalms', '3:3'), '3:2');
      // Both halves of a merge report the verse that renders them.
      expect(v11n.readerKey('Psalms', '3:2'), '3:1');
    });

    test('re-keying a book is a partition, so counts cannot double', () {
      final out = v11n.rekeyBook('Psalms', {
        '3:1': ['heading'],
        '3:2': ['first line'],
        '3:3': ['second line'],
        '13:6': ['shared'],
        '9:9': ['untouched'],
      });
      // Reader 3:1 renders both the heading and the first line, so it
      // holds both — overwriting instead would drop the heading and
      // leave every count over the book short.
      expect(out['3:1'], ['heading', 'first line']);
      expect(out['3:2'], ['second line']);
      expect(out['13:5'], ['shared']);
      expect(out.containsKey('13:6'), isFalse);
      expect(out['9:9'], ['untouched']);
      expect(out.values.expand((e) => e).length, 5, reason: 'nothing lost');
    });

    test('an entry in the table beats a key the traditions merely share',
        () {
      // 3:2 exists on both sides but means different verses. The table
      // must win, or the collision silently restores the old defect.
      final out = v11n.rekeyBook('Psalms', {
        '3:2': ['masoretic 3:2'],
      });
      expect(out, {
        '3:1': ['masoretic 3:2'],
      });
    });

    test('an unclaimed original verse whose number is spoken for is dropped',
        () {
      // Masoretic Psalm 13:5 belongs to no reference, and reader 13:5
      // renders Masoretic 13:6. Filing it under 13:5 anyway would put
      // the wrong words under a real reference — the very defect this
      // table exists to remove — so it is left out instead.
      final out = v11n.rekeyBook('Psalms', {
        '13:5': ['unclaimed'],
        '13:6': ['what 13:5 renders'],
      });
      expect(out, {
        '13:5': ['what 13:5 renders'],
      });
    });
  });

  group('the shipped table', () {
    final v11n = _shipped();

    test('pins the differences a reader would notice', () {
      // Each of these is a documented Masoretic/English divergence, and
      // each was reproduced independently by the alignment.
      expect(v11n.originalKeys('Genesis', 31, 55), ['32:1']);
      expect(v11n.originalKeys('Leviticus', 6, 1), ['5:20']);
      expect(v11n.originalKeys('Numbers', 16, 36), ['17:1']);
      expect(v11n.originalKeys('1 Kings', 4, 21), ['5:1']);
      expect(v11n.originalKeys('1 Chronicles', 6, 1), ['5:27']);
      expect(v11n.originalKeys('Job', 41, 1), ['40:25']);
      expect(v11n.originalKeys('Joel', 2, 28), ['3:1']);
      expect(v11n.originalKeys('Joel', 3, 1), ['4:1']);
      expect(v11n.originalKeys('Malachi', 4, 1), ['3:19']);
      // The Greek side: NA28 numbers 2 Corinthians 13 with thirteen
      // verses and splits 3 John 14 in two.
      expect(v11n.originalKeys('2 Corinthians', 13, 14), ['13:13']);
      expect(v11n.originalKeys('3 John', 1, 14), ['1:14', '1:15']);
    });

    test('carries the psalm headings, including the two-line ones', () {
      expect(v11n.originalKeys('Psalms', 3, 1), ['3:1', '3:2']);
      expect(v11n.originalKeys('Psalms', 3, 8), ['3:9']);
      for (final psalm in [51, 52, 54, 60]) {
        expect(v11n.originalKeys('Psalms', psalm, 1).length, 3,
            reason: 'Psalm $psalm has a two-line heading');
      }
    });

    test('the Hebrew Bible contributes exactly one omission', () {
      // BHS has no verse for the horses and mules of Nehemiah 7:68; its
      // 7:68 is the camels and donkeys the reader calls 7:69. Left at
      // identity the reader asking for horses was shown the Hebrew for
      // camels, which is the defect this table exists to remove — so it
      // is reported absent instead of guessed at.
      expect(v11n.isAbsentFromOriginal('Nehemiah', 7, 68), isTrue);
      expect(v11n.originalKeys('Nehemiah', 7, 69), ['7:68']);
      final absent = _json('assets/versification.json')['absent']
          as Map<String, dynamic>;
      const greek = {
        'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans', 'Nehemiah',
      };
      expect(absent.keys.toSet().difference(greek), isEmpty,
          reason: 'a new book started omitting verses');
      expect(absent['Nehemiah'], ['7:68']);
    });

    test('names exactly the verses the critical text omits', () {
      // Derived from the data, not typed in: these are the sixteen
      // Received-Text verses, and no others may join them silently.
      const known = {
        'Matthew': ['17:21', '18:11', '23:14'],
        'Mark': ['7:16', '9:44', '9:46', '11:26', '15:28'],
        'Luke': ['17:36', '23:17'],
        'John': ['5:4'],
        'Acts': ['8:37', '15:34', '24:7', '28:29'],
        'Romans': ['16:24'],
      };
      for (final book in known.entries) {
        for (final key in book.value) {
          final (c, v) = _vkey(key);
          expect(v11n.isAbsentFromOriginal(book.key, c, v), isTrue,
              reason: '${book.key} $key');
        }
      }
      expect(v11n.isAbsentFromOriginal('Mark', 9, 45), isFalse);
    });

    test('every target exists, and reader order runs forwards', () {
      final raw = _json('assets/versification.json')['map']
          as Map<String, dynamic>;
      var rows = 0;
      for (final book in raw.entries) {
        final originals =
            _json('assets/originals/${_slug(book.key)}.json');
        final entries = (book.value as Map<String, dynamic>).entries.toList()
          ..sort((a, b) {
            final ka = _vkey(a.key);
            final kb = _vkey(b.key);
            return ka.$1 != kb.$1
                ? ka.$1.compareTo(kb.$1)
                : ka.$2.compareTo(kb.$2);
          });
        (int, int) previous = (0, 0);
        for (final entry in entries) {
          rows++;
          for (final target in entry.value as List) {
            expect(originals.containsKey(target), isTrue,
                reason: '${book.key} ${entry.key} -> $target does not exist');
            final here = _vkey(target as String);
            expect(here.$1 > previous.$1 || here.$2 >= previous.$2, isTrue,
                reason: '${book.key} ${entry.key} -> $target runs backwards');
            previous = here;
          }
        }
      }
      expect(rows, 1991);
    });
  });

  group('the shipped table is better supported by the text than identity', () {
    // The claim these tests defend is not "the map is self-consistent"
    // but "the map is TRUE". So re-derive the evidence: for every row,
    // does the original it now points at share more Strong's numbers
    // with the reader's own tagged verse than the one it pointed at
    // before? A wrong row would show up here as a degradation.
    //
    // Six books, chosen to cover every mechanism: a heading shift, a
    // chapter boundary that moves, a whole book renumbered, and one book
    // where the shift crosses in the other direction.
    const books = ['Psalms', 'Joel', 'Genesis', 'Job', 'Malachi', 'Numbers'];

    for (final layer in ['kjvs', 'bsb']) {
      test('against the $layer tagging', () {
        final table = _json('assets/versification.json')['map']
            as Map<String, dynamic>;
        var improved = 0;
        var degraded = 0;
        for (final book in books) {
          final rows = table[book] as Map<String, dynamic>;
          final originals = _json('assets/originals/${_slug(book)}.json');
          final tagged = _json('assets/tagged/$layer/${_slug(book)}.json');
          for (final row in rows.entries) {
            final reader = tagged[row.key];
            if (reader == null) continue;
            final readerWords = _strongs(reader);
            final now = <String>{};
            for (final t in row.value as List) {
              now.addAll(_strongs(originals[t] ?? const []));
            }
            final before = _strongs(originals[row.key] ?? const []);
            final scoreNow = _dice(readerWords, now);
            final scoreBefore = _dice(readerWords, before);
            if (scoreNow > scoreBefore) improved++;
            if (scoreNow < scoreBefore) degraded++;
          }
        }
        expect(degraded, 0,
            reason: 'a mapped verse resembles the reader\'s verse LESS '
                'than the one it replaced — the row is wrong');
        expect(improved, greaterThan(1000));
      });
    }
  });
}
