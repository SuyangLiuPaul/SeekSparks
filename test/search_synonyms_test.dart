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
import 'package:yahwehs_sword/constants/search_synonyms.dart';
import 'package:yahwehs_sword/constants/text_patterns.dart' show searchCorpusKey;
import 'package:yahwehs_sword/utils/chinese_segmentation.dart' show isHanChar;

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
      // more a second entry (发→髮, 仑→崙, 墙→牆, 须→鬚). That made it
      // 1,115.
      //
      // 1,114 later the same day: 众 lost its second form. It had 眾
      // 1,892 times and 衆 four, and four is not a variant reading —
      // it is four places the edition contradicted itself, in one
      // verse of scripture and three of the publisher's notes. The
      // official 和合本繁體 prints 眾 and so does this edition
      // everywhere else, so there was nothing to weigh;
      // tools/repair_tr_by_official_cuv.py names the four verses.
      //
      // 么 → 麽 1,230 / 麼 11 is the same shape and is still here on
      // purpose: there the official edition prints 甚麼 and this one
      // prints 什麽, so "be consistent" and "follow the official text"
      // point in opposite directions and the owner has to choose.
      // Regenerate with tools/build_cuv_char_table.py rather than
      // hand-patching.
      // 1,113 later the same day: 壳 left the table. The ONLY place it
      // stood opposite 殼 in 31,102 verses was 以賽亞書 36:17, where the
      // publisher's text promises 「有五壳和新酒之地」 — five shells and
      // new wine. The official 和合本繁體 reads 五穀, grain, and
      // tools/repair_by_official_cuv.py corrects both scripts. With the
      // typo gone there is no 壳/殼 correspondence left to record, which
      // is the right answer: the pair was only ever evidence of a
      // defect.
      // 1,112 later still: 凌 left the table the same way 壳 did, and
      // for the same reason. The only Traditional character it ever
      // stood opposite was 淩 — 淩辱 ×37 — and 淩 is a variant this
      // edition has no business printing: the published 和合本繁體 reads
      // 凌辱 (士師記 19:25), the official conversion reads 凌, and
      // tools/repair_cuv_tr_overconversion.py puts it back. With the
      // over-conversion gone there is no 凌/淩 correspondence left to
      // record, which is right: the pair was only ever evidence of a
      // defect.
      // 1,106 the same day, and this one is a whole class rather than a
      // single defect: the Traditional edition moved to **Hong Kong**
      // forms on the owner's ruling (「按照香港和合本的繁体字吧」, and the
      // publisher's own conversion README: "Hong Kong, at the church's
      // request: 裏, 牀, 着 — not Taiwan's 裡, 床, 著").
      //
      // Six Simplified characters left the table because the Hong Kong
      // form IS the Simplified character — 户, 着, 温, 兑, 悦, 卧 — so
      // there is no longer a correspondence to record for them. 稅→税 and
      // 蔥→葱 are the same shape and were already absent.
      //
      // This is the table doing its job, not losing entries: it records
      // where the two shipped editions actually differ, and after the
      // ruling they differ in six fewer places.
      //
      // 1,145 on 2026-09-14, and this is the table GAINING entries for
      // the first time. 1,111 characters in 1,022 verses moved to the
      // form the published 和合本 prints there
      // (`tools/apply_cuv_tr_hehe_verdicts.py`), settling the 128
      // classes this repo's two conversions had been left disagreeing
      // on. 39 of those are a Traditional form this pair had never
      // shown opposite its Simplified character before — 迹 stood
      // opposite 跡 only and now also stands opposite 蹟, 饥 opposite
      // 饑 and now also 飢, 系 opposite 繫 and now also 係 — so the
      // correspondence has more to record, not less. It is per
      // occurrence: 和合本 prints 槓 at 出埃及記 25:13 and 杆 at 27:10
      // for the same poles, and 茍合 then 苟合 inside 以西結書 23:44,
      // and the table now carries both sides of each.
      //
      // 1,144 later the same day, and the one that left is the point of
      // the exercise. An earlier pass had reverted 藉 → 借 as a CLASS on
      // the strength of 出埃及記 22:14, which is the law about BORROWING
      // — and had thereby rewritten 「耶和華藉摩西吩咐」 151 times. All
      // 638 positions of that pass's five pairs were re-read in the
      // published 和合本 (four independent readings, 381 chapters): 486
      // 對, 152 錯, and 151 of the 152 were 借 for 藉. The 152nd was the
      // edition's single 沈 (馬太福音 14:30), and with it gone 沉 has no
      // second Traditional form left to record. 借 → 藉 went 133 → 284.
      //
      // 2026-09-18, Raymond 牧師's review of the 繁體 list: 什麼 → 甚麼
      // gives 什 a correspondence (什/甚), and 户 卧 着 have one again
      // (戶 臥, and 着 opposite the single 著 of 傳道書 12:12), while 樑
      // 鑑 燬 鏽 are gone, so 梁 leaves the table and 鉴 毁 锈 lose
      // their second forms. The count happens to come out where it was.
      expect(kCuvSimplifiedChars.length, 1144);
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

    test('a Simplified character with more than one Traditional form lists '
        'the commoner one first', () {
      // Whichever way this is ordered decides what
      // `simplifiedToTraditional` produces for that character, so it is
      // pinned rather than left to map iteration order.
      final forms = <String, List<String>>{};
      for (var i = 0; i < kCuvSimplifiedChars.length; i++) {
        forms
            .putIfAbsent(kCuvSimplifiedChars[i], () => [])
            .add(kCuvTraditionalChars[i]);
      }
      final many = forms.entries.where((e) => e.value.length > 1);
      // 20 until 2026-09-14, when following the published 和合本 per
      // occurrence gave 迹, 系 and 锈 a second form they had not had.
      // 19 on 2026-09-18: Raymond 牧師's review ruled 銹 and 鑒
      // throughout, so 锈 and 鉴 are single-form now.
      expect(many.length, 19);

      // The close calls, where the majority is not obvious and a
      // re-derivation could flip it: 锈 is 鏽 5 against 銹 4, 系 is 繫 12
      // against 係 5, 饥 is 饑 99 against 飢 58, 鉴 is 鑒 23 against 鑑 5.
      expect(forms['锈'], ['銹']);
      expect(forms['系']!.first, '繫');
      expect(forms['饥']!.first, '饑');
      expect(forms['鉴'], ['鑒']);
      // 签 flipped on 2026-09-14: 籤 25 against 簽 2, where it had been
      // 簽 first. The 和合本 prints 拈籤/掣籤 for the casting of lots.
      expect(forms['签']!.first, '籤');
      expect(forms['干']!.first, '乾');
      expect(forms['尝']!.first, '嘗');
      // 复 is the only one with three: 復 235, 覆 3, 複 1.
      expect(forms['复'], ['復', '覆', '複']);

      // Two that used to be in this list and are now single-form, which
      // is the point of naming them: 众 had 眾 1,892 and 衆 4, and the
      // four were the edition contradicting itself; 么 had 麽 1,230 and
      // 麼 11, and no OpenCC profile produces 麽 at all.
      expect(forms['众'], ['眾']);
      expect(forms['么'], ['麼']);
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
