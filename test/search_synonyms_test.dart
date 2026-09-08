/// 2026-09-08: the provenance of every table in `search_synonyms.dart`,
/// re-established from scratch on every run.
///
/// This is not a test of a constant against itself. Two of the three
/// tables are DERIVED from `assets/cuvs-yhwh.json` and
/// `assets/cuvs-yhwh-tr.json`, and this file re-derives them from those
/// two files and fails if the constants no longer say what the shipped
/// scripture says. That is what makes "derived from data we already own"
/// a checkable claim rather than a comment.
///
/// The third table, the synonym groups, is hand-authored — so each group
/// is checked against the in-repo evidence its own `evidence` field
/// cites: a verse, a measurement, or the alias table in
/// `strongs_service.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/search_synonyms.dart';
import 'package:seeksparks/constants/text_patterns.dart' show searchCorpusKey;
import 'package:seeksparks/utils/chinese_segmentation.dart' show isHanChar;

void main() {
  late List<String> simplified;
  late List<String> traditional;

  List<Map<String, dynamic>> load(String asset) => [
        for (final e in jsonDecode(File(asset).readAsStringSync()) as List)
          (e as Map).cast<String, dynamic>(),
      ];

  setUpAll(() {
    final s = load('assets/cuvs-yhwh.json');
    final t = load('assets/cuvs-yhwh-tr.json');
    expect(s.length, t.length);
    for (var i = 0; i < s.length; i++) {
      expect(s[i]['id'], t[i]['id'], reason: 'the two editions must align');
    }
    simplified = [for (final v in s) v['text'] as String];
    traditional = [for (final v in t) v['text'] as String];
  });

  group('the Simplified-Traditional table, re-derived from the two shipped '
      'editions', () {
    test('every verse pair is the same length, which is what makes the '
        'correspondence derivable at all', () {
      var mismatches = 0;
      for (var i = 0; i < simplified.length; i++) {
        if (simplified[i].length != traditional[i].length) mismatches++;
      }
      expect(mismatches, 0);
    });

    test('the shipped table is exactly the correspondence the text shows',
        () {
      final counts = <String, Map<String, int>>{};
      for (var i = 0; i < simplified.length; i++) {
        final a = simplified[i];
        final b = traditional[i];
        for (var j = 0; j < a.length; j++) {
          final s = a.codeUnitAt(j);
          final t = b.codeUnitAt(j);
          if (s == t) continue;
          if (!isHanChar(s) || !isHanChar(t)) continue;
          final row = counts.putIfAbsent(String.fromCharCode(s), () => {});
          final key = String.fromCharCode(t);
          row[key] = (row[key] ?? 0) + 1;
        }
      }
      final expectedS = StringBuffer();
      final expectedT = StringBuffer();
      for (final s in counts.keys.toList()..sort()) {
        final forms = counts[s]!.entries.toList()
          ..sort((a, b) {
            final byCount = b.value.compareTo(a.value);
            return byCount != 0 ? byCount : b.key.compareTo(a.key);
          });
        for (final form in forms) {
          expectedS.write(s);
          expectedT.write(form.key);
        }
      }
      expect(kCuvSimplifiedChars, expectedS.toString());
      expect(kCuvTraditionalChars, expectedT.toString());
      // 1,107 until 2026-09-08, when repairing the Traditional
      // edition's one-to-many collapses gave four Simplified characters
      // a second Traditional form they had never had here (松→鬆, 胡→鬍,
      // 谷→穀, 采→採 were each opposite themselves before) and gave four
      // more a second entry (发→髮, 仑→崙, 墙→牆, 须→鬚). Regenerate
      // with tools/build_cuv_char_table.py rather than hand-patching.
      expect(kCuvSimplifiedChars.length, 1115);
    });

    test('no Traditional character stands opposite two Simplified ones, so '
        'that direction has no choice to make', () {
      final back = <String, Set<String>>{};
      for (var i = 0; i < kCuvSimplifiedChars.length; i++) {
        back
            .putIfAbsent(kCuvTraditionalChars[i], () => {})
            .add(kCuvSimplifiedChars[i]);
      }
      expect(back.values.where((v) => v.length > 1), isEmpty);
    });

    test('the six Simplified characters with two Traditional forms list the '
        'commoner one first', () {
      // 众 → 眾 1,892 times and 衆 4. Whichever way that tie is broken
      // decides what `simplifiedToTraditional` produces, so it is
      // pinned rather than left to map iteration order.
      final firstSeen = <String, String>{};
      for (var i = 0; i < kCuvSimplifiedChars.length; i++) {
        firstSeen.putIfAbsent(
            kCuvSimplifiedChars[i], () => kCuvTraditionalChars[i]);
      }
      expect(firstSeen['众'], '眾');
      expect(firstSeen['么'], '麽');
      expect(firstSeen['干'], '乾');
      expect(firstSeen['鉴'], '鑒');
      expect(firstSeen['签'], '簽');
      expect(firstSeen['尝'], '嘗');
    });
  });

  group('the common-character list, re-derived the same way', () {
    test('is exactly the Han characters in more than a fifth of the verses',
        () {
      final documentFrequency = <String, int>{};
      for (final text in simplified) {
        for (final c in text.split('').toSet()) {
          if (!isHanChar(c.codeUnitAt(0))) continue;
          documentFrequency[c] = (documentFrequency[c] ?? 0) + 1;
        }
      }
      final threshold = (simplified.length * 0.20).floor();
      final over = documentFrequency.entries
          .where((e) => e.value > threshold)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      expect(over.map((e) => e.key).join(), kCuvCommonHanChars);
      expect(kCuvCommonHanChars.length, 17);
    });

    test('holds 的, which is in four verses out of five', () {
      expect(kCuvCommonHanChars, contains('的'));
    });
  });

  group('each synonym group against the evidence it cites', () {
    test('every group states its evidence and holds at least two spellings',
        () {
      for (final group in kSearchSynonymGroups) {
        expect(group.forms.length, greaterThanOrEqualTo(2),
            reason: group.forms.join('/'));
        expect(group.evidence.trim(), isNotEmpty,
            reason: group.forms.join('/'));
      }
    });

    test('no spelling belongs to two groups, or a rewrite would depend on '
        'which was found first', () {
      final seen = <String>{};
      for (final group in kSearchSynonymGroups) {
        for (final form in group.forms) {
          expect(seen.add(form), isTrue, reason: form);
        }
      }
    });

    test('the verse that licenses 彼得 and 矶法 says both of them', () {
      // 约翰福音 1:42, quoted in that group's evidence field. Found by
      // its words rather than by an index, so the check survives a
      // versification change and fails loudly if the sentence does not.
      final witness = simplified.firstWhere(
          (t) => t.contains('矶法翻出来就是彼得'),
          orElse: () => '');
      expect(witness, isNotEmpty,
          reason: 'the synonym group cites a verse the edition must contain');
      expect(witness, contains('彼得'));
    });

    test('the verse that licenses 基督 and 弥赛亚 says both of them', () {
      final witness = simplified.firstWhere(
          (t) => t.contains('弥赛亚') && t.contains('基督'),
          orElse: () => '');
      expect(witness, isNotEmpty);
    });

    test('the numbers the divine-name group quotes are the numbers the '
        'search key really holds', () {
      final keys = [for (final t in simplified) searchCorpusKey(t)];
      int hits(String w) => keys.where((k) => k.contains(w)).length;
      // The whole argument for the group: the index says 雅伟, and the
      // spelling every Chinese Bible in print uses reaches nothing.
      expect(hits('雅伟'), 6102);
      expect(hits('耶和华'), 0);
      // And for the 神 / 上帝 group.
      expect(hits('神'), 3994);
      expect(hits('上帝'), 0);
    });

    test('the divine name agrees with the alias table in strongs_service, '
        'which is the table this one will eventually be merged into', () {
      // Read as source rather than called, because `_aliasToStrongs` is
      // private and this is a guard against the two DRIFTING, not a
      // test of lookup behaviour. `search_synonyms.dart` records why
      // they are still two tables.
      final source =
          File('lib/services/strongs_service.dart').readAsStringSync();
      final divine = kSearchSynonymGroups.first;
      expect(divine.forms, contains('雅伟'));
      for (final form in divine.forms) {
        expect(source, contains("'$form': 'H3068'"),
            reason: '$form is in the fuzzy divine-name group but is not '
                'pinned to H3068 in strongs_service.dart');
      }
    });
  });
}
