// docs/DATA-INTEGRITY.md check 31b: the 116 psalm titles the loader
// threw away.
//
// `assets/leb.json` numbers a superscription `title` instead of an
// integer, and `FetchVerses` filtered every non-numeric verse out at
// load, so no reader had ever seen one. The words were in the asset the
// whole time — the same shape as check 25b, where 139 Old-Testament
// synopsis groups existed and nothing could open them.
//
// Two things are asserted here, and they fail for different reasons.
// The fold is unit-tested because it is the logic; the asset is tested
// because the count is a claim about the data, and a future import that
// dropped four titles would leave the logic passing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/psalm_superscription.dart';

Map<String, dynamic> rec(String book, String ch, String vs, String text) =>
    {'book': book, 'chapter': ch, 'verse': vs, 'text': text};

void main() {
  group('foldSuperscriptions', () {
    test('attaches a title to verse 1 of its own chapter', () {
      final out = foldSuperscriptions([
        rec('Psalms', '3', 'title', 'A psalm of David.'),
        rec('Psalms', '3', '1', 'O Yahweh, how many are my foes!'),
        rec('Psalms', '3', '2', 'Many are saying of me,'),
      ]);
      expect(out.attached, 1);
      expect(out.orphans, isEmpty);
      expect(out.records, hasLength(2));
      expect(out.records.first['superscription'], 'A psalm of David.');
      expect(out.records.first['text'], 'O Yahweh, how many are my foes!');
      expect(out.records.last.containsKey('superscription'), isFalse);
    });

    test('does not attach across chapters or books', () {
      final out = foldSuperscriptions([
        rec('Psalms', '3', 'title', 'A psalm of David.'),
        rec('Psalms', '4', '1', 'Answer me when I call,'),
        rec('Proverbs', '3', '1', 'My child, do not forget my teaching,'),
      ]);
      expect(out.attached, 0);
      expect(out.orphans, ['Psalms 3']);
      expect(out.records.every((m) => !m.containsKey('superscription')), isTrue);
    });

    test('a title whose chapter has no verse 1 is counted, not guessed at', () {
      final out = foldSuperscriptions([
        rec('Psalms', '3', 'title', 'A psalm of David.'),
        rec('Psalms', '3', '2', 'Many are saying of me,'),
      ]);
      expect(out.attached, 0);
      expect(out.orphans, ['Psalms 3']);
      expect(out.records, hasLength(1));
    });

    test('leaves an edition with no titles exactly as it found it', () {
      final input = [
        rec('Genesis', '1', '1', 'In the beginning'),
        rec('Genesis', '1', 'x', 'not a verse number'),
      ];
      final out = foldSuperscriptions(input);
      expect(out.attached, 0);
      expect(out.orphans, isEmpty);
      // Identity, not just equality: the caller's own non-numeric filter
      // must still see the record this function chose not to claim.
      expect(identical(out.records, input), isTrue);
    });

    test('two titles for one chapter keep both, in order', () {
      final out = foldSuperscriptions([
        rec('Psalms', '3', 'title', 'First.'),
        rec('Psalms', '3', 'title', 'Second.'),
        rec('Psalms', '3', '1', 'O Yahweh,'),
      ]);
      expect(out.attached, 1);
      expect(out.records.first['superscription'], 'First. Second.');
    });
  });

  group('assets/leb.json', () {
    late List<Map<String, dynamic>> raw;

    setUpAll(() {
      raw = (json.decode(File('assets/leb.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
    });

    test('ships 116 superscriptions, every one of them a psalm', () {
      final titles = raw
          .where((m) => m['verse'].toString() == kSuperscriptionVerseToken)
          .toList();
      expect(titles, hasLength(116));
      expect(titles.map((m) => m['book']).toSet(), {'Psalms'});
    });

    test('the 34 psalms with no title are the 34 that have none', () {
      final titled = raw
          .where((m) => m['verse'].toString() == kSuperscriptionVerseToken)
          .map((m) => int.parse(m['chapter'].toString()))
          .toSet();
      final untitled = [
        for (var c = 1; c <= 150; c++)
          if (!titled.contains(c)) c
      ];
      // The traditional list of psalms that carry no Hebrew superscription
      // — an outside witness to the import's completeness that costs
      // nothing, since a dropped title would show up here as an extra
      // number rather than as a silence.
      expect(untitled, [
        1, 2, 10, 33, 43, 71, 91, 93, 94, 95, 96, 97, 99, 104, 105, 106, 107,
        111, 112, 113, 114, 115, 116, 117, 118, 119, 135, 136, 137, 146, 147,
        148, 149, 150,
      ]);
    });

    test('every one of them finds a home on verse 1', () {
      final out = foldSuperscriptions(raw);
      expect(out.attached, 116);
      expect(out.orphans, isEmpty);
      expect(out.records, hasLength(raw.length - 116));
      // The loader's filter runs after the fold; nothing non-numeric may
      // survive it, or the fold has widened what the app accepts.
      final nonNumeric = out.records
          .where((m) => int.tryParse(m['verse'].toString()) == null)
          .toList();
      expect(nonNumeric, isEmpty);
    });

    test('Psalm 51 carries the title a reader would look for', () {
      final out = foldSuperscriptions(raw);
      final ps51 = out.records.firstWhere((m) =>
          m['book'] == 'Psalms' && m['chapter'] == '51' && m['verse'] == '1');
      expect(ps51['superscription'], contains('Nathan the prophet'));
    });
  });

  test('no other edition writes a non-numeric verse number', () {
    // If a second one ever appears, the fold is the wrong place to learn
    // about it — it would attach silently and the edition's own convention
    // would go unexamined.
    const others = <String>[
      'assets/biblexg-v2-tr.json',
      'assets/biblexg-v2.json',
      'assets/bsb.json',
      'assets/cuvs-plus.json',
      'assets/cuvs-yhwh-tr.json',
      'assets/cuvs-yhwh.json',
      'assets/kjv.json',
      'assets/kjvs.json',
      'assets/lxxwh.json',
      'assets/nasb.json',
    ];
    final offenders = <String>[];
    for (final asset in others) {
      final verses = (json.decode(File(asset).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      for (final v in verses) {
        if (int.tryParse(v['verse'].toString()) == null) {
          offenders.add('$asset ${v['book']} ${v['chapter']}:${v['verse']}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(5).toString());
  });
}
