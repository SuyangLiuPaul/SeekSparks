// Check 50 — the two 和合本雅伟版 editions witness each other.
//
// assets/cuvs-yhwh.json (Simplified) and assets/cuvs-yhwh-tr.json
// (Traditional) are the same edition in two scripts, regenerated together
// by 49af9be. Nothing had ever asked them to agree. Deriving a
// traditional->simplified character map from the corpus itself (every
// equal-length verse pair, majority vote per character) and converting
// every traditional verse found 7 of 31,102 disagreeing:
//
//   038001003 撒迦利亞書 1:3   a lone 說 inside the Simplified Bible,
//       against 9,538 说 elsewhere in the same file — a singleton, not a
//       recension: repaired.
//   040025020 馬太福音 25:20  那另外的的五來 — 的 doubled, 千 dropped, in
//       the Traditional file: repaired.
//   023033009 023040007 023040008 059001011 060001024  凋 (simplified) /
//       雕 (traditional) — systematic at 83 against 5, the traditional
//       edition's own orthography. Left alone; repairing would fabricate
//       a house-style spelling onto the other script.
//
// See tools/repair_cuvs_yhwh_editions.py and docs/DATA-INTEGRITY.md,
// check 50.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

const _leftDeliberately = <String>[
  '023033009',
  '023040007',
  '023040008',
  '059001011',
  '060001024',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> simplified;
  late Map<String, String> traditional;

  setUpAll(() async {
    final s = json.decode(await rootBundle.loadString('assets/cuvs-yhwh.json'))
        as List<dynamic>;
    final t = json.decode(
            await rootBundle.loadString('assets/cuvs-yhwh-tr.json'))
        as List<dynamic>;
    simplified = {
      for (final r in s.cast<Map<String, dynamic>>())
        r['id'] as String: r['text'] as String,
    };
    traditional = {
      for (final r in t.cast<Map<String, dynamic>>())
        r['id'] as String: r['text'] as String,
    };
  });

  test('the two editions carry the same 31,102 verses, verse for verse', () {
    expect(simplified, hasLength(31102));
    expect(traditional, hasLength(31102));
    expect(simplified.keys.toSet(), traditional.keys.toSet());

    final lengthMismatches = simplified.keys
        .where((id) => simplified[id]!.length != traditional[id]!.length)
        .toList();
    expect(lengthMismatches, isEmpty,
        reason: 'a verse pair whose lengths differ cannot be compared '
            'character-for-character; offenders: $lengthMismatches');
  });

  test("neither edition carries the other's script", () {
    final traditionalCharInSimplified =
        simplified.values.fold<int>(0, (n, v) => n + '說'.allMatches(v).length);
    final simplifiedCharInTraditional = traditional.values
        .fold<int>(0, (n, v) => n + '说'.allMatches(v).length);

    expect(traditionalCharInSimplified, 0,
        reason: 'assets/cuvs-yhwh.json (Simplified) should never carry 說; '
            'found $traditionalCharInSimplified occurrence(s)');
    expect(simplifiedCharInTraditional, 0,
        reason: 'assets/cuvs-yhwh-tr.json (Traditional) should never carry '
            '说; found $simplifiedCharInTraditional occurrence(s)');
  });

  test(
      'the traditional edition converts back to the simplified one, '
      'except at five named sites', () {
    // Derive a traditional->simplified map from the corpus itself: for
    // every equal-length verse pair, vote per character position, then
    // take the majority simplified character for each traditional one.
    final votes = <String, Map<String, int>>{};
    for (final id in simplified.keys) {
      final s = simplified[id]!;
      final t = traditional[id]!;
      if (s.length != t.length) continue;
      for (var i = 0; i < s.length; i++) {
        final tChar = t[i];
        final sChar = s[i];
        final counts = votes.putIfAbsent(tChar, () => {});
        counts[sChar] = (counts[sChar] ?? 0) + 1;
      }
    }
    final map = <String, String>{
      for (final entry in votes.entries)
        entry.key: entry.value.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key,
    };

    final disagreeing = simplified.keys.where((id) {
      final converted = traditional[id]!
          .split('')
          .map((c) => map[c] ?? c)
          .join();
      return converted != simplified[id];
    }).toList()
      ..sort();

    expect(disagreeing, _leftDeliberately,
        reason: 'these five verses are left deliberately: the traditional '
            'edition writes 雕 systematically (83 sites) where the '
            'simplified edition writes 凋 at these five (5 sites) — the '
            "traditional edition's own orthography, not a defect. A new "
            'id appearing here is a defect in one of the two files and '
            'must be investigated, not added to this list.');
  });
}
