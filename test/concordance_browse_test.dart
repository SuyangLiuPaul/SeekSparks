/// The Modern Concordance's browse logic, pinned twice: on hand-written
/// rows that state each rule in isolation, and on the 341 topics the app
/// actually ships.
///
/// The second half is the one that matters. Every rule below was chosen
/// off a measurement of `assets/concordance/index.json`, and a rule
/// justified by a number is only as good as the number — so the numbers
/// are asserted against the real file rather than restated in a comment
/// where they can rot. `modern_concordance_test.dart` pins the asset's
/// shape; this pins what the browse logic makes of it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/concordance_browse.dart';

/// The shipped topic names, `(english, chinese)`, in index order.
List<(String, String)> _shippedNames() {
  final j = jsonDecode(
    File('assets/concordance/index.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return [
    for (final t in j['topics'] as List)
      ((t['en'] ?? '') as String, (t['zh'] ?? '') as String),
  ];
}

void main() {
  group('matchTopics — the rules, stated one at a time', () {
    const rows = <(String, String)>[
      ('Love', '爱'),
      ('Catch - Seize - Steal', '捕 - 抓 - 偷'),
      ('Above - Over', '上面，在…之上'),
      ('Beloved', '蒙爱的'),
    ];

    test('an empty query matches nothing at all', () {
      expect(matchTopics(rows, ''), isEmpty);
      expect(matchTopics(rows, '   '), isEmpty);
    });

    // The rule Nave's cannot supply. 239 of the 341 shipped names are
    // compounds, and a whole-name prefix answers this with nothing.
    test('a middle segment is a prefix hit, not a substring hit', () {
      final hits = matchTopics(rows, 'seize');
      expect(hits.length, 1);
      expect(hits.single.index, 1);
      expect(hits.single.prefix, isTrue,
          reason: 'Seize starts a segment of "Catch - Seize - Steal"; '
              'ranking it below a substring hit would bury it');
      expect(hits.single.matched, TopicMatch.english);
    });

    test('segment prefixes outrank substrings, and both are kept', () {
      final hits = matchTopics(rows, 'love');
      // Love (prefix) before Beloved (substring). Both wanted.
      expect(hits.map((h) => h.index).toList(), [0, 3]);
      expect(hits.first.prefix, isTrue);
      expect(hits.last.prefix, isFalse);
    });

    test('the Chinese column answers, and says that it did', () {
      final hits = matchTopics(rows, '爱');
      expect(hits.map((h) => h.index).toList(), [0, 3]);
      expect(hits.every((h) => h.matched == TopicMatch.chinese), isTrue,
          reason: 'the caller shows the Chinese name only when Chinese '
              'is what matched; mislabelling it hides why a row is there');
    });

    test('a Chinese comma separates segments the way " - " does', () {
      // 在…之上 is the second segment of 上面，在…之上. Without the
      // comma in the separator list this is a substring hit at best.
      final hits = matchTopics(rows, '在');
      expect(hits.single.index, 2);
      expect(hits.single.prefix, isTrue);
    });

    test('a hyphen inside a word is not a separator', () {
      const hyphenated = <(String, String)>[('Twenty-four', '二十四')];
      // "four" is inside the term, not the start of a segment.
      final hits = matchTopics(hyphenated, 'four');
      expect(hits.single.prefix, isFalse);
    });

    test('English wins the label when both columns match', () {
      const both = <(String, String)>[('Amen', 'Amen 阿们')];
      expect(matchTopics(both, 'amen').single.matched, TopicMatch.english);
    });
  });

  group('matchTopics — against the 341 topics actually shipped', () {
    late final List<(String, String)> names = _shippedNames();

    test('the fixture is the whole work', () {
      expect(names.length, 341);
      expect(names.where((n) => n.$2.isEmpty), isEmpty,
          reason: 'every topic carries a Chinese gloss — the bilingual '
              'search rule rests on this and would half-fail without it');
    });

    // The measurement the segment rule was chosen from. If this drops,
    // the rule is over-engineered; if it rises, it is load-bearing.
    test('239 of the names are compounds', () {
      final compound = names.where((n) => n.$1.contains(' - ')).length;
      expect(compound, 239);
    });

    test('"seize" is answerable in the shipped data, and only this way',
        () {
      final hits = matchTopics(names, 'seize');
      expect(hits, isNotEmpty);
      final en = hits.map((h) => names[h.index].$1).toList();
      expect(en, contains('Catch - Seize - Steal'));
      // The whole-name prefix rule this replaced.
      final naveStyle =
          names.where((n) => n.$1.toLowerCase().startsWith('seize')).length;
      expect(naveStyle, 0,
          reason: 'if a topic ever starts with Seize the comparison in '
              'concordance_browse.dart needs rewording, not the rule');
    });

    test('"爱" reaches three topics no English query would find', () {
      final hits = matchTopics(names, '爱');
      expect(hits.length, 3);
      expect(hits.every((h) => h.matched == TopicMatch.chinese), isTrue);
      expect(
        hits.map((h) => names[h.index].$1).toList()..sort(),
        ['Favoritism - Partiality', 'Love', 'Spare'],
      );
    });

    test('a word the concordance does not carry returns nothing', () {
      expect(matchTopics(names, 'photosynthesis'), isEmpty);
    });

    test('every hit index addresses a real topic', () {
      for (final q in ['a', 'love', '神', 'e', '的']) {
        for (final h in matchTopics(names, q)) {
          expect(h.index, inInclusiveRange(0, names.length - 1));
        }
      }
    });
  });
}
