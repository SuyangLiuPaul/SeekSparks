// Check 53 — the atlas's traditional place names, witnessed by our own
// CUV pair.
//
// assets/bible_places.json's `s`/`t` fields were produced by an opencc
// profile that does Taiwan-idiom substitution, not plain script
// conversion — correct for UI vocabulary, wrong for proper nouns. It
// wrote 穀 (grain) where these place names need 谷 (valley), and
// transliterated a handful of English headwords
// (埃布尔 for "Abel") instead of using the CUV's own 亞伯. Deriving a
// simplified<->traditional character map from assets/cuvs-yhwh.json and
// assets/cuvs-yhwh-tr.json (31,102 verse pairs, all equal length) and
// checking every place name against it found 51 disagreeing; 46 were
// repaired by attestation, 5 left because neither script's name is
// attested in our corpus at all — see docs/DATA-INTEGRITY.md, check 53.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

// Places whose s/t pair the corpus cannot settle, left deliberately. A
// name disappearing from this set (because it was repaired) must be
// removed here too; a new name appearing means a new defect, not an
// addition to this list.
const _leftDeliberately = <String>{
  'Cyprus', // neither attested — CUV says 居比路; mainland vs Taiwan modern names
  'Italy', // s=意大利 is correct standard mainland Chinese; CUV-simplified
  // writes 义大利 only as a mechanical t2s of 義大利 — the corpus
  // witness is itself the artifact here, "repairing" would regress it
  'Malta', // neither attested — CUV says 米利大; regional variants
  'Geder', // both attested (基德 x1 simplified, 吉德 x4 traditional) — ambiguous
  'Neapolis', // neither attested — CUV says 尼亞波利; 裏/裡/里 not decidable
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> places;
  late Map<String, Set<String>> variantSets;

  setUpAll(() async {
    final raw = json.decode(
      await rootBundle.loadString('assets/bible_places.json'),
    ) as Map<String, dynamic>;
    places = (raw['places'] as List<dynamic>).cast<Map<String, dynamic>>();

    final s = json.decode(
      await rootBundle.loadString('assets/cuvs-yhwh.json'),
    ) as List<dynamic>;
    final t = json.decode(
      await rootBundle.loadString('assets/cuvs-yhwh-tr.json'),
    ) as List<dynamic>;
    final simplified = {
      for (final r in s.cast<Map<String, dynamic>>())
        r['id'] as String: r['text'] as String,
    };
    final traditional = {
      for (final r in t.cast<Map<String, dynamic>>())
        r['id'] as String: r['text'] as String,
    };

    // Build a simplified->traditional character map from every
    // equal-length verse pair; a pair is entered if the traditional
    // text ever contains that character at the same position as the
    // simplified one.
    final map = <String, Set<String>>{};
    for (final id in simplified.keys) {
      final sv = simplified[id]!;
      final tv = traditional[id];
      if (tv == null || sv.length != tv.length) continue;
      for (var i = 0; i < sv.length; i++) {
        map.putIfAbsent(sv[i], () => {}).add(tv[i]);
      }
    }
    variantSets = map;
  });

  test('every s/t place-name pair has equal character length', () {
    final mismatches = places
        .where((r) => r['s'] != null && r['t'] != null)
        .where((r) => (r['s'] as String).length != (r['t'] as String).length)
        .map((r) => r['n'] as String)
        .toList();
    expect(mismatches, isEmpty,
        reason: 'a place name pair whose lengths differ cannot be the '
            'same name in two scripts; offenders: $mismatches');
  });

  test(
      'every differing character in a place name pair is witnessed by '
      'the CUV edition pair, except at five named sites', () {
    final failing = <String>{};
    for (final r in places) {
      final s = r['s'] as String?;
      final t = r['t'] as String?;
      if (s == null || t == null || s.length != t.length) continue;
      for (var i = 0; i < s.length; i++) {
        final sc = s[i];
        final tc = t[i];
        if (sc == tc) continue;
        final witnessed = variantSets[sc]?.contains(tc) ?? false;
        if (!witnessed) {
          failing.add(r['n'] as String);
          break;
        }
      }
    }
    expect(failing, _leftDeliberately,
        reason: 'these five place names are left deliberately because '
            "neither script's form is attested anywhere in our CUV "
            'corpus (see the comment list above for each reason); a '
            'different failing set means either a new defect or a '
            'repair that must be removed from the allow-list: $failing');
  });

  // CORRECTED 2026-09-08. This test is right and its original reason was
  // not, so the reason is restated rather than the assertion changed.
  //
  // Check 53 argued 穀 is wrong in a place name because "the traditional
  // CUV always writes 谷" — measured as 谷 244 / 穀 0 across the 31,102
  // verses of assets/cuvs-yhwh-tr.json. That zero is not a fact about the
  // 和合本. It is a fact about OUR conversion: cuvs-yhwh-tr.json was made
  // from the Simplified edition by a pass that resolved each ambiguous
  // Simplified character once and for all, and Simplified 谷 is either 谷
  // (valley) or 穀 (grain). The zero is the collapse, not a convention —
  // the same file reads 「因為谷不可勝數」 at 創世紀 41:49, where Joseph
  // stores grain, not terrain.
  //
  // The measurement that settles it: yswords carries an independently
  // repaired copy of this same edition, in which the split was restored.
  // There 穀 occurs 68 times and every one is grain (五穀, 踹穀, 穀種,
  // 炒穀) — while the place names are spelt exactly as check 53 wrote
  // them: 亞割谷 x5, 欣嫩子谷 x10, 谷門 x4, and no 亞割穀 / 欣嫩子穀 /
  // 穀門 anywhere. So the 46 repairs were substantively correct and stay.
  //
  // The reason they are correct is semantic, not statistical: the Valley
  // of Achor, the Valley of Hinnom and the Valley Gate are valleys. Do
  // not re-derive this rule from a character frequency in our own
  // Traditional asset — that asset cannot witness the 谷/穀 distinction,
  // because it is the file that lost it.
  test('valley place names are spelt 谷 because they are valleys, not '
      'because our Traditional asset happens to lack 穀', () {
    final offenders = places
        .where((r) => r['t'] != null && (r['t'] as String).contains('穀'))
        .map((r) => r['n'] as String)
        .toList();
    expect(offenders, isEmpty,
        reason: 'every place name carrying 谷 in this atlas is a valley '
            '(亞割谷, 欣嫩子谷, 谷門, 汲淪谷); 穀 is grain and cannot be '
            'right in any of them. NB: do NOT justify this from '
            'assets/cuvs-yhwh-tr.json, whose 穀 count of 0 is an artifact '
            'of our own Simplified-to-Traditional collapse; offenders: '
            '$offenders');
  });
}
