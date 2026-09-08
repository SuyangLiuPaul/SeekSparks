/// 2026-09-08: the looser reading of a search — that it is off, that
/// turning it off puts the engine back exactly where it was, and that
/// every row it adds can be told from a row the reader typed.
///
/// Every count in this file was measured against the shipped editions,
/// through the same two functions the real scan calls. If one moves, the
/// engine changed and the tables in `fuzzy_search.dart` and
/// `search_synonyms.dart` are now lies as well.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/utils/fuzzy_result_label.dart';
import 'package:seeksparks/utils/fuzzy_search.dart';
import 'package:seeksparks/utils/plain_search.dart';
import 'package:seeksparks/utils/search_folding.dart';

void main() {
  late List<String> kjv;
  late List<String> cuvs;
  late Map<String, String> cuvsById;

  List<String> keysOf(String asset) {
    final list = jsonDecode(File(asset).readAsStringSync()) as List;
    return [for (final v in list) searchCorpusKey(v['text'] as String)];
  }

  setUpAll(() {
    kjv = keysOf('assets/kjv.json');
    cuvs = keysOf('assets/cuvs-yhwh.json');
    final list =
        jsonDecode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List;
    cuvsById = {for (final v in list) v['id'] as String: v['text'] as String};
  });

  tearDown(resetFuzzySearchForTest);

  /// The query rule, called rather than re-implemented: a probe that
  /// spells out a sanitiser by hand is the thing that ends up wrong.
  List<String> seg(String query) =>
      plainSearchSegments(foldSearchMarks(query).toLowerCase());

  int hits(List<String> keys, String query) {
    final s = seg(query);
    return keys.where((k) => plainSearchMatches(k, s)).length;
  }

  Map<FuzzyMatch, int> byKind(List<String> keys, String query) {
    final s = seg(query);
    final out = <FuzzyMatch, int>{};
    for (final key in keys) {
      final kind = plainSearchMatchKind(key, s);
      if (kind == FuzzyMatch.none) continue;
      out[kind] = (out[kind] ?? 0) + 1;
    }
    return out;
  }

  group('the switch', () {
    test('is off, and stays off until something turns it on', () {
      expect(fuzzySearchEnabled, isFalse);
    });

    test('reports whether it actually moved, so a caller can skip an '
        'invalidation it does not need', () {
      final start = fuzzySearchGeneration;
      expect(setFuzzySearchEnabled(false), isFalse);
      expect(fuzzySearchGeneration, start);
      expect(setFuzzySearchEnabled(true), isTrue);
      expect(fuzzySearchGeneration, greaterThan(start));
    });
  });

  group('with the switch off, the engine is the engine it was', () {
    test('every verse of the KJV gets the same answer as the literal '
        'matcher, for queries of every shape', () {
      for (final query in const [
        'love',
        'loved',
        'yahweh',
        'in the beginning',
        'for the',
        'forth',
        'jehovah',
        'faith',
      ]) {
        final s = seg(query);
        for (var i = 0; i < kjv.length; i++) {
          expect(plainSearchMatches(kjv[i], s),
              plainSearchMatchesLiteral(kjv[i], s),
              reason: '$query at verse $i');
        }
      }
    });

    test('the counts in plain_search.dart\'s own table still come out', () {
      // The six probes that file measured when the word-gap rule landed.
      // They are the regression guard for this change as much as for
      // that one: a broadening that leaked into the default would move
      // every one of them.
      expect(hits(kjv, 'forth'), 877);
      expect(hits(kjv, 'asa'), 207);
      expect(hits(kjv, 'heirs'), 24);
      expect(hits(kjv, 'end'), 1205);
      expect(hits(kjv, 'oar'), 117);
      expect(hits(kjv, 'for the'), 2020);
    });

    test('the Chinese probes that file measured are untouched too', () {
      expect(hits(cuvs, '爱'), 822);
      expect(hits(cuvs, '爱神'), 12);
      expect(hits(cuvs, '这诫命'), 4);
      expect(hits(cuvs, '雅伟'), 6102);
    });

    test('the prefilter is still the longest segment', () {
      expect(plainSearchPrefilter(seg('in the beginning')), 'beginning');
    });
  });

  group('with the switch on', () {
    setUp(() => setFuzzySearchEnabled(true));

    test('the prefilter stands down, because every rung exists to match a '
        'verse that does not contain what was typed', () {
      expect(plainSearchPrefilter(seg('in the beginning')), '');
    });

    test('the spelling every Chinese Bible in print uses stops finding '
        'nothing', () {
      // The defect this whole feature exists for. The corpus key says
      // 雅伟 because `_normalizeDivineNames` rewrote it at index time;
      // nothing rewrites the query, so 耶和华 found zero verses of a
      // book it is on almost every page of.
      expect(byKind(cuvs, '耶和华'), {FuzzyMatch.synonym: 6102});
    });

    test('the 上帝版 reader reaches the 神版 this app ships', () {
      expect(byKind(cuvs, '上帝'), {FuzzyMatch.synonym: 3994});
    });

    test('a Traditional query reaches a Simplified edition, by script '
        'first and by synonym after', () {
      // 磯法 shares no character with 矶法, so no prefilter and no
      // substring rule could ever have found it. The script rung finds
      // the 9 verses that spell it, the synonym rung the 176 that call
      // the same man 彼得, and the order is what the labels report.
      expect(byKind(cuvs, '磯法'),
          {FuzzyMatch.script: 9, FuzzyMatch.synonym: 175});
      expect(byKind(cuvs, '愛'), {FuzzyMatch.script: 822});
    });

    test('an English query reaches the other forms of its own verb', () {
      // `loved` found 198 verses and missed the 546 that say "love",
      // because a substring scan reaches forwards and not back.
      expect(byKind(kjv, 'loved'),
          {FuzzyMatch.literal: 198, FuzzyMatch.stem: 350});
    });

    test('a verb form sharing no substring with the query is reachable at '
        'last', () {
      // "loving" does not hold the letters l-o-v-e in a row, so no
      // substring rule was ever going to reach it from `love`. This is
      // the case that killed the first version of the stem rung, which
      // skipped the stemmed pass whenever stemming left the QUERY
      // unchanged — as it does for `love`, whose stem is itself.
      //
      // Two verses, not more, and the shortfall is worth knowing: the
      // KJV says "loving" 32 times and 29 of them are inside
      // "lovingkindness", which Porter stems to `lovingkind` because it
      // is a compound and not an inflection. The two are 箴言 22:1
      // ("loving favour") and 以赛亚书 56:10 ("loving to slumber"); the
      // third bare "loving", 箴言 5:19, is already a literal hit
      // because the same verse says "love".
      expect(byKind(kjv, 'love'),
          {FuzzyMatch.literal: 546, FuzzyMatch.stem: 2});
    });

    test('a Chinese phrase in no verse falls back to its own words, apart',
        () {
      // The loosest rung, and the only one that drops adjacency.
      expect(byKind(cuvs, '信心的祷告'), {FuzzyMatch.segmented: 4});
    });

    test('a query with nothing looser about it is left exactly alone', () {
      expect(byKind(kjv, 'faith'), {FuzzyMatch.literal: 338});
      expect(byKind(cuvs, '神'), {FuzzyMatch.literal: 3994});
    });

    test('turning it on only ever ADDS rows: every literal hit is still a '
        'hit, and is still labelled literal', () {
      for (final probe in const [
        ('kjv', 'loved'),
        ('kjv', 'love'),
        ('cuvs', '爱'),
        ('cuvs', '矶法'),
        ('cuvs', '这诫命'),
      ]) {
        final keys = probe.$1 == 'kjv' ? kjv : cuvs;
        final s = seg(probe.$2);
        for (final key in keys) {
          if (!plainSearchMatchesLiteral(key, s)) continue;
          expect(plainSearchMatchKind(key, s), FuzzyMatch.literal,
              reason: probe.$2);
        }
      }
    });
  });

  group('what the result row says', () {
    String label(String query, String verseId) => fuzzyLabelledReference(
          '约翰福音 1:42',
          query: query,
          scriptureText: cuvsById[verseId]!,
          locale: 'zh-Hans',
        );

    test('says nothing at all while the switch is off', () {
      // 马太福音 4:18 says 彼得 and does not say 矶法, so this row would
      // be labelled if anything were going to be.
      expect(label('矶法', '040004018'), '约翰福音 1:42');
    });

    test('says nothing on a row that holds what the reader typed', () {
      setFuzzySearchEnabled(true);
      expect(label('彼得', '040004018'), '约翰福音 1:42');
    });

    test('names the rung that found a row the reader did not type', () {
      setFuzzySearchEnabled(true);
      expect(label('矶法', '040004018'), '约翰福音 1:42 · 同名异写');
      expect(label('磯法', '043001042'), '约翰福音 1:42 · 异体字');
    });

    test('says nothing about a row that came from another engine', () {
      // A command-grammar or Strong's result never went through the
      // plain matcher, so this file has nothing to say about its rows.
      // 约翰一书 4:16 is the trap: it holds both 爱 and 神, so without
      // the control-character guard the loosest rung would label a
      // command result with a reading nobody ran.
      setFuzzySearchEnabled(true);
      expect(cuvsById['062004016'], contains('爱'));
      expect(cuvsById['062004016'], contains('神'));
      expect(label('.爱 神', '062004016'), '约翰福音 1:42');
      expect(label("'爱 神", '062004016'), '约翰福音 1:42');
    });
  });

  group('the pure layer, which is going into another repository', () {
    test('imports nothing but dart and its own four files', () {
      // The portability claim in `fuzzy_search.dart`'s header, made
      // checkable. `fuzzy_result_label.dart` is deliberately not in this
      // list: it is the SeekSparks glue, and it is a separate file so
      // that this list can stay short.
      const portable = [
        'lib/utils/fuzzy_search.dart',
        'lib/utils/porter_stemmer.dart',
        'lib/utils/chinese_segmentation.dart',
        'lib/constants/search_synonyms.dart',
        'lib/constants/fuzzy_search_strings.dart',
      ];
      const allowed = {
        'package:seeksparks/constants/search_synonyms.dart',
        'package:seeksparks/utils/chinese_segmentation.dart',
        'package:seeksparks/utils/porter_stemmer.dart',
        'package:seeksparks/utils/fuzzy_search.dart',
      };
      final importLine = RegExp(r"^import '([^']+)'", multiLine: true);
      for (final path in portable) {
        for (final m in importLine.allMatches(File(path).readAsStringSync())) {
          final uri = m.group(1)!;
          expect(uri.startsWith('dart:') || allowed.contains(uri), isTrue,
              reason: '$path imports $uri, which does not travel');
        }
      }
    });
  });
}
