// The OT Synopsis's group titles, witnessed by the passages they label
// (check 35).
//
// `assets/ot_synopsis.json` prints a title over every group of parallel
// Old Testament passages, and seven of the 139 imported from Eagle's
// View misspelled a word. Four were proper names — Jepheth, Johoash,
// Manesseh, Oholiah — and in each case the group's own verses spell the
// name correctly, in the KJV+S and in the CUV both. The app was
// therefore printing a name over a passage that contradicted it.
//
// Two guards, one frozen and one general:
//
//   * the seven repaired titles, by exact value, so a re-import that
//     forgets `TITLE_CORRECTIONS` fails here rather than in the reader;
//   * a standing rule that no title word of five letters or more may be
//     absent from its passages while a word in those passages sits
//     within two edits of it. That is the exact shape of all four name
//     defects, and after the repair only two titles satisfy it — both
//     modern spellings of a name the KJV spells differently, listed
//     below with the reason.
//
// The general rule is the one with a future: it fails on a name nobody
// has thought of yet. See tools/audit_ot_synopsis.py for the wider
// sweep this file is the cheap subset of.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The seven titles check 35 repaired, frozen at their repaired value.
const _repaired = <int, String>{
  17: 'Bezalel and Oholiab',
  27: "Japheth's Descendants",
  57: 'Settlers in Jerusalem after Exile',
  157: "Athaliah's Assassination",
  165: "Jehoash's Death",
  186: "Hezekiah's Illness",
  188: "Manasseh's Reign",
};

/// Title words that are near a passage word on purpose. Both are the
/// spelling every modern version uses for a name the KJV spells with an
/// extra syllable, which is a translation convention and not an error;
/// "correcting" either would be the instrument overruling the editor.
const _conventions = <String>{
  'Bezalel', // KJV "Bezaleel", Exodus 31:2
  'Oholiab', // KJV "Aholiab", Exodus 31:6
};

/// Words a title may use that no passage contains, because they name the
/// book rather than anything inside it.
const _bookWords = <String>{
  'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
  'judges', 'ruth', 'samuel', 'kings', 'chronicles', 'ezra', 'nehemiah',
  'esther', 'psalm', 'psalms', 'proverbs', 'ecclesiastes', 'isaiah',
  'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel',
  'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah',
  'haggai', 'zechariah', 'malachi',
};

int _editDistance(String a, String b, int cap) {
  if ((a.length - b.length).abs() > cap) return cap + 1;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    var best = i;
    for (var j = 1; j <= b.length; j++) {
      final sub = prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, sub].reduce((x, y) => x < y ? x : y);
      if (cur[j] < best) best = cur[j];
    }
    if (best > cap) return cap + 1;
    prev = cur;
  }
  return prev[b.length];
}

void main() {
  final synopsis = jsonDecode(
      File('assets/ot_synopsis.json').readAsStringSync()) as Map<String, dynamic>;
  final groups = (synopsis['groups'] as List).cast<Map<String, dynamic>>();

  test('the seven repaired titles are still repaired', () {
    final byId = {for (final g in groups) g['id'] as int: g['en'] as String};
    final wrong = <String>[];
    _repaired.forEach((id, want) {
      final got = byId[id];
      if (got != want) wrong.add('group $id: expected "$want", found "$got"');
    });
    expect(wrong, isEmpty,
        reason: 'check 35 repaired these; see '
            'tools/repair_ot_synopsis_titles.py\n${wrong.join('\n')}');
  });

  test('every correction the asset claims is recorded', () {
    final titleFixes = (synopsis['corrections'] as List)
        .cast<Map<String, dynamic>>()
        .where((c) => c['field'] == 'en')
        .map((c) => c['group'] as int)
        .toSet();
    expect(titleFixes, equals(_repaired.keys.toSet()),
        reason: 'the asset must say where it differs from Eagle\'s View');
  });

  test('no group title misspells a name its own passages spell', () {
    // The KJV+S text, which is the witness. Chapter lengths come from
    // it too, so a range that runs to the end of a chapter expands
    // correctly without a versification table.
    final text = <String, String>{};
    final chapterLast = <String, int>{};
    for (final r in jsonDecode(File('assets/kjvs.json').readAsStringSync())
        as List) {
      final m = r as Map<String, dynamic>;
      final book = m['book'] as String;
      final c = int.parse('${m['chapter']}');
      final v = int.parse('${m['verse']}');
      text['$book|$c|$v'] = m['text'] as String;
      final key = '$book|$c';
      if (v > (chapterLast[key] ?? 0)) chapterLast[key] = v;
    }

    final word = RegExp(r"[A-Za-z][A-Za-z']*");
    final capital = RegExp(r"[A-Z][a-z']{4,}");
    final failures = <String>[];

    for (final g in groups) {
      final body = StringBuffer();
      for (final r in (g['refs'] as List).cast<Map<String, dynamic>>()) {
        final book = r['book'] as String;
        final c0 = r['chapter'] as int;
        final c1 = (r['endChapter'] as int?) ?? c0;
        for (var c = c0; c <= c1; c++) {
          final first = c == c0 ? r['start'] as int : 1;
          final last = c == c1 ? r['end'] as int : (chapterLast['$book|$c'] ?? 0);
          for (var v = first; v <= last; v++) {
            final t = text['$book|$c|$v'];
            if (t != null) body.write('$t ');
          }
        }
      }
      final passage = body.toString();
      if (passage.isEmpty) continue;
      final lower = passage.toLowerCase();
      final names = capital.allMatches(passage).map((m) => m[0]!).toSet();

      for (final m in word.allMatches(g['en'] as String)) {
        var base = m[0]!;
        if (base.toLowerCase().endsWith("'s")) {
          base = base.substring(0, base.length - 2);
        }
        if (base.length < 5) continue;
        if (base[0].toLowerCase() == base[0]) continue;
        if (_bookWords.contains(base.toLowerCase())) continue;
        if (_conventions.contains(base)) continue;
        if (lower.contains(base.toLowerCase())) continue;
        for (final n in names) {
          if (n.toLowerCase() == base.toLowerCase()) continue;
          final d = _editDistance(base, n, 2);
          if (d <= 2) {
            failures.add('group ${g['id']} "${g['en']}": title says "$base", '
                'the passage says "$n" ($d edit${d > 1 ? 's' : ''})');
            break;
          }
        }
      }
    }

    expect(failures, isEmpty,
        reason: 'a title must not spell a name differently from the passage '
            'it labels\n${failures.join('\n')}');
  });
}
