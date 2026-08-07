/// No two shipping editions may be the same text under two names.
///
/// This exists because `cuv-yhwd` (yahwehdehua.net) was imported, tagged,
/// committed and deployed before anyone compared it to what was already
/// in the catalog — at which point it turned out to be `cuvs-yhwh`. Same
/// 31,102 references, same wording, same Strong's tagging; the only
/// differences were how translator's notes were bracketed. It cost 22 MB
/// and put two rows in the version picker that no reader could tell
/// apart.
///
/// Nothing in the suite noticed, because every test that touched it
/// asserted the edition was *internally* consistent — the verses parse,
/// the runs reassemble, the book count is 66. All true, and all true of
/// a duplicate.
///
/// So the check is comparative, not internal: sample the same references
/// out of every pair of editions in a language and look at the ones that
/// read alike.
///
/// Similarity alone is NOT the rule, and the first draft of this test got
/// that wrong — it flagged `kjv` against `kjvs`, which agree on 97.3% of
/// a sample, *more* than the duplicate it was written to catch (94.6%).
/// That pair is deliberate and documented: one translation in two
/// editions, 1769 spelling against modernised, kept apart because
/// word-level tagging has to travel with the exact text it was aligned
/// against.
///
/// What separates the two cases is what the second row *adds*. `kjvs`
/// brings Strong's numbers `kjv` does not have, so a reader has a reason
/// to pick it. `cuvs-yhwh` was already tagged, so `cuv-yhwd` brought
/// nothing — same words, same numbers, coarser splits.
///
/// Hence: near-identical text is allowed only when exactly one of the
/// pair is tagged. Both tagged, or neither, and the second row is dead
/// weight.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/services/tagged_text_service.dart';

/// Strip what varies between *editions* of one text — punctuation style,
/// quote marks, and the two note conventions in use (`<note: 原文作：质>`
/// against `〔原文作："质"〕`) — so that what remains is wording alone.
String _wording(String s) => s
    .replaceAll(RegExp(r'<note:.*?>'), '')
    .replaceAll(RegExp(r'[〔〕\[\]（）()"“”\x27‘’—─,，。；;：:！!？?、·\s]'), '');

Map<String, String>? _load(String version) {
  final f = File('assets/$version.json');
  // Editions we hold locally but do not redistribute (the Eagle's View
  // NASB modules) have no asset in a clean checkout. Skipping is right:
  // absent means not shipping, which is what this test is about.
  if (!f.existsSync()) return null;
  final rows = jsonDecode(f.readAsStringSync()) as List;
  return {
    for (final r in rows.cast<Map<String, dynamic>>())
      '${r['book']}|${r['chapter']}|${r['verse']}': (r['text'] ?? '') as String,
  };
}

void main() {
  test('no two shipping editions of a language are the same text', () {
    for (final language in bibleLanguageOrder) {
      final editions = <String, Map<String, String>>{};
      for (final v in versionsForLanguage(language)) {
        final loaded = _load(v.value);
        if (loaded != null) editions[v.value] = loaded;
      }
      final codes = editions.keys.toList();

      for (var i = 0; i < codes.length; i++) {
        for (var j = i + 1; j < codes.length; j++) {
          final a = editions[codes[i]]!, b = editions[codes[j]]!;
          final shared = a.keys.where(b.containsKey).toList()..sort();
          if (shared.length < 100) continue; // different canons; not a pair

          // Spread the sample across the whole canon rather than taking a
          // prefix — Genesis agreeing proves less than Genesis, Psalms and
          // Revelation all agreeing.
          final step = shared.length ~/ 400;
          var same = 0, n = 0;
          for (var k = 0; k < shared.length; k += (step < 1 ? 1 : step)) {
            final ref = shared[k];
            n++;
            if (_wording(a[ref]!) == _wording(b[ref]!)) same++;
          }
          final pct = same / n * 100;
          if (pct < 90.0) continue; // genuinely different translations

          // Same text under two names. Allowed only if the second row
          // earns its place by carrying tagging the first lacks.
          final taggedA = TaggedTextService.supports(codes[i]);
          final taggedB = TaggedTextService.supports(codes[j]);
          expect(taggedA ^ taggedB, isTrue,
              reason: '${codes[i]} and ${codes[j]} agree on '
                  '${pct.toStringAsFixed(1)}% of a $n-verse sample after '
                  'normalising punctuation and note markup, and '
                  '${taggedA && taggedB ? "both are tagged" : "neither is tagged"}'
                  ' — so the second row adds nothing the first does not '
                  'already give the reader. It costs a picker row nobody '
                  'can distinguish, a Split View that compares a text '
                  'against itself, and the size of the assets. Either drop '
                  'one, or establish what it adds. See the removal note at '
                  'the end of lib/constants/bible_versions.dart.');
        }
      }
    }
  });
}
