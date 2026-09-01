// Check 53 — the atlas's traditional place names, witnessed by our own
// CUV pair.
//
// assets/bible_places.json's `s`/`t` fields were produced by an opencc
// profile that does Taiwan-idiom substitution, not plain script
// conversion — correct for UI vocabulary, wrong for proper nouns. It
// wrote 穀 (grain) where the Bible's own traditional edition always
// writes 谷 (valley), and transliterated a handful of English headwords
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

  test('no traditional place name contains 穀 — our Bible never uses it',
      () {
    final offenders = places
        .where((r) => r['t'] != null && (r['t'] as String).contains('穀'))
        .map((r) => r['n'] as String)
        .toList();
    expect(offenders, isEmpty,
        reason: 'assets/cuvs-yhwh-tr.json uses 谷 (valley) 244 times and '
            '穀 (grain) 0 times in 31,102 verses; offenders: $offenders');
  });
}
