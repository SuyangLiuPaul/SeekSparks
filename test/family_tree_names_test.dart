// The family tree's names, witnessed by the passages each record cites
// (check 36).
//
// `assets/family_tree.json` prints a name for 277 people and lists the
// verses each one appears in. Check 25 proved those 665 references
// resolve; it never asked whether the passage they resolve to contains
// the name printed over it. For three people it did not, in any of the
// five English editions the app ships — "Melki", "Josek" and the
// non-name "Joshua / Jose", a slash-joined pair of two editions'
// spellings sitting in a field the app prints verbatim.
//
// Four guards, one frozen and three general:
//
//   * the three repaired names, by exact value, so a regenerated asset
//     that forgets tools/repair_family_tree_names.py fails here rather
//     than in the tree;
//   * no displayed name may contain a slash — the shape of the third
//     defect, and cheap;
//   * every English name must appear as a whole word in some shipped
//     edition of some verse the record itself cites. After the repair
//     276 of 277 satisfy this with no help at all: no spelling aliases,
//     no near-miss allowance, no second chance from a verse the record
//     does not point at. The single exemption is listed below with its
//     reason;
//   * a ratchet on the Chinese, which is the half the app's readers
//     actually use. Ten names are absent from the CUV at their own
//     verses, and the set is frozen by id so the debt can shrink but
//     not grow or move.
//
// The references are resolved with the app's own parseReference, not a
// reimplementation of it, so the test asks the question the app would
// ask. See tools/audit_family_tree.py for the wider sweep this file is
// the cheap subset of.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/reference_parser.dart';

/// The names check 36 repaired, frozen at their repaired value.
const _repaired = <String, String>{
  'melki_nt': 'Melchi',
  'josek_lk_26': 'Josech',
  'joshua_lk_29': 'Joshua',
};

/// Editions that count as a witness. Every one is a complete English
/// Bible the app ships.
const _editions = <String>['bsb', 'kjv', 'kjvs', 'nasb', 'leb'];

/// English names a cited passage does not contain, on purpose.
const _conventions = <String>{
  // Matthew 13:55 and Mark 6:3, his only two references, list the
  // brothers of Jesus and spell him "Judas" (bsb, nasb, leb) or "Juda"
  // (kjv, kjv+s). Every English Bible calls the epistle Jude and calls
  // its author Jude; the Gospel lists use the fuller form of the same
  // name. Renaming him "Judas" would put him next to Iscariot.
  'jude_brother',
};

/// People whose Chinese name is absent from the CUV at their own
/// verses. Eight transliterate the modern critical name in a chain
/// where the CUV follows the Textus Receptus and reads a different name
/// altogether, which is an editorial policy rather than an error; two
/// look like slips. Separating them is a translation judgement, so the
/// set is recorded rather than repaired — see check 36 in
/// docs/DATA-INTEGRITY.md, which lists the CUV's reading for each.
const _zhAbsent = <String>{
  'reuben', // 吕便; the CUV reads 流便 85 times and 吕便 never, and
  // hezron_reuben's own name field already says 流便
  'hezron_reuben', // 希斯仑; Genesis 46:9 reads 希斯伦
  'ziphion', // 洗非芬; Genesis 46:16 reads 洗非
  'muppim', // 姆平; Genesis 46:21 reads 母平
  'semein_lk_26', // 西美音; Luke 3:26 reads 西美
  'josek_lk_26', // 约瑟克; Luke 3:26 reads 约瑟
  'joda_lk_26', // 约大; Luke 3:26 reads 犹大
  'elmadam_lk_28', // 以摩太; Luke 3:28 reads 以摩当
  'eliezer_lk_29', // 以列以谢; Luke 3:29 reads 以利以谢, which the CUV
  // uses 14 times and eliezer_son already carries
  'menna_lk_31', // 米拿; Luke 3:31 reads 买南
};

/// The name as the tree prints it, minus the tags that tell two men of
/// the same name apart and the phrases that describe rather than name.
String _head(String name) {
  var s = name.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  s = s.replaceAll(RegExp(r'\s+(of|the)\s+.*$'), '').trim();
  return s;
}

String _zhHead(String name) =>
    name.replaceAll(RegExp(r'[（(][^）)]*[）)]'), '').trim();

void main() {
  final tree = jsonDecode(File('assets/family_tree.json').readAsStringSync())
      as Map<String, dynamic>;
  final people = (tree['people'] as List).cast<Map<String, dynamic>>();

  test('the three repaired names are still repaired', () {
    final byId = {for (final p in people) p['id'] as String: p['name'] as String};
    final wrong = <String>[];
    _repaired.forEach((id, want) {
      final got = byId[id];
      if (got != want) wrong.add('$id: expected "$want", found "$got"');
    });
    expect(wrong, isEmpty,
        reason: 'check 36 repaired these; see '
            'tools/repair_family_tree_names.py\n${wrong.join('\n')}');
  });

  test('every correction the asset claims is recorded', () {
    final fixed = (tree['corrections'] as List)
        .cast<Map<String, dynamic>>()
        .where((c) => c['field'] == 'name')
        .map((c) => c['id'] as String)
        .toSet();
    expect(fixed, equals(_repaired.keys.toSet()),
        reason: 'the asset must say where it differs from what was generated');
  });

  test('no displayed name is two spellings joined by a slash', () {
    final bad = <String>[];
    for (final p in people) {
      for (final field in ['name', 'nameZhHans', 'nameZhHant']) {
        final v = p[field] as String?;
        if (v != null && (v.contains('/') || v.contains('／'))) {
          bad.add('${p['id']}.$field = "$v"');
        }
      }
    }
    expect(bad, isEmpty,
        reason: 'a slash means an editorial note leaked into a field the '
            'app prints verbatim\n${bad.join('\n')}');
  });

  group('names against their own passages', () {
    // Resolve every record's references once, with the app's parser.
    late final Map<String, Set<String>> cited;
    late final Map<String, Map<String, String>> text; // edition -> key -> text
    late final Map<String, String> verseIds; // key -> numeric verse id
    late final Map<String, String> cuv; // verse id -> Chinese text

    setUpAll(() {
      // The verse universe, and the id that joins English to Chinese.
      final chapters = <String, List<int>>{};
      verseIds = <String, String>{};
      final bsb = <String, String>{};
      for (final r in jsonDecode(File('assets/bsb.json').readAsStringSync())
          as List) {
        final m = r as Map<String, dynamic>;
        final v = int.tryParse('${m['verse']}');
        if (v == null) continue; // Psalm superscriptions carry `title`
        final book = m['book'] as String;
        final c = int.parse('${m['chapter']}');
        final key = '$book|$c|$v';
        bsb[key] = m['text'] as String;
        (chapters['$book|$c'] ??= <int>[]).add(v);
        final id = m['id'] as String?;
        if (id != null) verseIds[key] = id;
      }

      cited = <String, Set<String>>{};
      for (final p in people) {
        final keys = <String>{};
        for (final raw in (p['refs'] as List).cast<String>()) {
          final ref = parseReference(raw);
          if (ref == null) continue;
          final last = ref.endChapter ?? ref.chapter;
          for (var c = ref.chapter; c <= last; c++) {
            for (final v in chapters['${ref.englishBook}|$c'] ?? const <int>[]) {
              if (ref.verseStart == null || ref.contains(c, v)) {
                keys.add('${ref.englishBook}|$c|$v');
              }
            }
          }
        }
        cited[p['id'] as String] = keys;
      }

      final wanted = <String>{for (final s in cited.values) ...s};
      text = {'bsb': {for (final k in wanted) if (bsb[k] != null) k: bsb[k]!}};
      for (final tag in _editions) {
        if (tag == 'bsb') continue;
        final keep = <String, String>{};
        for (final r in jsonDecode(File('assets/$tag.json').readAsStringSync())
            as List) {
          final m = r as Map<String, dynamic>;
          final v = int.tryParse('${m['verse']}');
          if (v == null) continue;
          final key = '${m['book']}|${m['chapter']}|$v';
          if (wanted.contains(key)) keep[key] = m['text'] as String;
        }
        text[tag] = keep;
      }

      final wantedIds = {
        for (final k in wanted)
          if (verseIds[k] != null) verseIds[k]!
      };
      cuv = <String, String>{};
      for (final r in jsonDecode(File('assets/cuvs-yhwh.json').readAsStringSync())
          as List) {
        final m = r as Map<String, dynamic>;
        final id = m['id'] as String?;
        if (id != null && wantedIds.contains(id)) cuv[id] = m['text'] as String;
      }
    });

    test('every reference still resolves and names at least one verse', () {
      final empty = <String>[];
      for (final p in people) {
        if ((cited[p['id'] as String] ?? const <String>{}).isEmpty) {
          empty.add('${p['id']} ("${p['name']}") refs=${p['refs']}');
        }
      }
      expect(empty, isEmpty,
          reason: 'a record whose references name no verse cannot be '
              'witnessed by anything\n${empty.join('\n')}');
    });

    test('every English name appears in a passage the record cites', () {
      final failures = <String>[];
      for (final p in people) {
        final id = p['id'] as String;
        if (_conventions.contains(id)) continue;
        final head = _head(p['name'] as String);
        if (head.isEmpty) continue;
        final needle = RegExp('\\b${RegExp.escape(head)}\\b');
        final found = _editions.any((tag) => (cited[id] ?? const <String>{})
            .any((k) => needle.hasMatch(text[tag]?[k] ?? '')));
        if (!found) {
          failures.add('$id: "${p['name']}" is in no shipped edition of '
              '${p['refs']}');
        }
      }
      expect(failures, isEmpty,
          reason: 'the app must not print a name over a passage that does '
              'not contain it\n${failures.join('\n')}');
    });

    test('the Chinese names absent from the CUV are the known set', () {
      // Exact containment only. An edit-distance test over two- and
      // three-character names produces overwhelming noise; either the
      // characters are in the verse or they are not.
      final absent = <String>{};
      for (final p in people) {
        final id = p['id'] as String;
        final zh = _zhHead((p['nameZhHans'] as String?) ?? '');
        if (zh.isEmpty) continue;
        final found = (cited[id] ?? const <String>{}).any((k) {
          final vid = verseIds[k];
          return vid != null && (cuv[vid] ?? '').contains(zh);
        });
        if (!found) absent.add(id);
      }
      expect(absent, equals(_zhAbsent),
          reason: 'the Chinese debt may shrink, but a repair must update '
              'this set and a new one must not slip in\n'
              'unexpected: ${absent.difference(_zhAbsent)}\n'
              'now witnessed: ${_zhAbsent.difference(absent)}');
    });
  });
}
