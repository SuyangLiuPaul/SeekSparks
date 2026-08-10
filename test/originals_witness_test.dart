// The Greek Strong's repairs of #304 check 24, frozen on the bytes.
//
// `tools/audit_originals_witness.py` is the wide sweep, and it needs 36
// MB of MorphGNT and OSHB that this repo does not vendor. These tests
// are the part that survives without them: the fifteen words whose
// Strong's number named a different word than the one it sat on, and
// the two structural invariants that made them findable.
//
// Why freeze individual words at all, when a general rule is usually
// better. Each of these changes what the app TELLS A READER a verse
// means — Luke 23:53 said "not" where the Greek says "where", 2 Cor 11:1
// said "kill" where it says "bear with me". A rebuild that silently
// reverted one would be invisible, so the specific claim is the thing
// worth asserting.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, List<dynamic>> _book(String slug) {
  final file = File('assets/originals/$slug.json');
  expect(file.existsSync(), isTrue, reason: 'missing assets/originals/$slug.json');
  return (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, v as List<dynamic>));
}

/// (slug, ref, surface form, the number it must now carry, the number it
/// used to carry). The old number is asserted absent as well as the new
/// one present: a rebuild from a stale source would put it back, and
/// only checking the new value would miss a duplicate row.
const _repairs = <List<String>>[
  ['luke', '4:17', 'οὗ', 'G3757', 'G3756'],
  ['luke', '23:53', 'οὗ', 'G3757', 'G3756'],
  ['romans', '9:26', 'οὗ', 'G3757', 'G3756'],
  ['acts', '5:28', 'Οὐ', 'G3756', 'G3757'],
  ['2_corinthians', '11:1', 'ἀνείχεσθέ', 'G430', 'G337'],
  ['acts', '8:2', 'Στέφανον', 'G4736', 'G4735'],
  ['matthew', '5:32', 'ἀπολελυμένην', 'G630', 'G620'],
  ['luke', '16:18', 'ἀπολελυμένην', 'G630', 'G620'],
  ['galatians', '6:15', 'τί', 'G5100', 'G5101'],
  ['titus', '1:6', 'τίς', 'G5100', 'G5101'],
  ['james', '1:25', 'ποιήσει', 'G4162', 'G4160'],
  ['john', '6:23', 'ἀλλὰ', 'G235', 'G243'],
  ['john', '16:15', 'ἐμοῦ', 'G1699', 'G1473'],
  ['acts', '18:23', 'στηρίζων', 'G4741', 'G1991'],
  ['mark', '1:5', 'Ἰουδαία', 'G2453', 'G2449'],
];

void main() {
  test('the fifteen repaired Greek words still carry the right number', () {
    for (final r in _repairs) {
      final words = _book(r[0])[r[1]];
      expect(words, isNotNull, reason: '${r[0]} ${r[1]} is missing');
      final numbers = <String>[
        for (final w in words!)
          if ((w as Map)['w'] == r[2]) (w['s'] as String?) ?? '',
      ];
      expect(numbers, isNotEmpty,
          reason: '${r[0]} ${r[1]}: no word spelled ${r[2]}');
      expect(numbers, contains(r[3]),
          reason: '${r[0]} ${r[1]} ${r[2]} should carry ${r[3]}');
      expect(numbers, isNot(contains(r[4])),
          reason: '${r[0]} ${r[1]} ${r[2]} carries ${r[4]} again — the '
              'repair in tools/repair_originals_strongs.py was reverted');
    }
  });

  // The general form of the defect, so a NEW one is caught rather than
  // only these fifteen. A Strong's number whose morph column says it is
  // a noun everywhere except one place is either a mis-tag or a house
  // convention, and a convention shows up more than once.
  //
  // Interjection and particle are excluded because MorphGNT itself calls
  // ἰδού both, and the adjective/adverb, preposition/adverb and
  // conjunction/adverb boundaries are excluded because Greek uses one
  // lexeme in both roles — τρίτον "a third time" is the neuter of the
  // ordinal. tools/audit_originals_witness.py argues all of this at
  // length; this is the same rule with the same exemptions.
  test('no Greek word is the lone part-of-speech outlier for its number',
      () {
    const gospelsAndRest = <String>[
      'matthew', 'mark', 'luke', 'john', 'acts', 'romans',
      '1_corinthians', '2_corinthians', 'galatians', 'ephesians',
      'philippians', 'colossians', '1_thessalonians', '2_thessalonians',
      '1_timothy', '2_timothy', 'titus', 'philemon', 'hebrews', 'james',
      '1_peter', '2_peter', '1_john', '2_john', '3_john', 'jude',
      'revelation',
    ];
    const decisive = <String>{
      'N-', 'V-', 'A-', 'RA', 'RP', 'RR', 'RI', 'RD', 'C-', 'P-', 'D-',
    };
    const functionPairs = <String>{'A-|D-', 'D-|P-', 'C-|D-', 'C-|P-'};
    // Two editors disagreeing about a category, not a wrong word: our
    // edition accents Eph 2:13 οἵ as a relative pronoun, SBLGNT as an
    // article, and both are nominative plural masculine.
    const adjudicated = <String>{'ephesians 2:13 οἵ'};

    final counts = <String, Map<String, int>>{};
    final rows = <List<String>>[];
    for (final slug in gospelsAndRest) {
      _book(slug).forEach((ref, words) {
        for (final w in words) {
          final morph = ((w as Map)['m'] as String?) ?? '';
          if (morph.length < 2) continue;
          final s = (w['s'] as String?) ?? '';
          final pos = morph.substring(0, 2);
          (counts[s] ??= <String, int>{}).update(pos, (n) => n + 1,
              ifAbsent: () => 1);
          rows.add([slug, ref, w['w'] as String, s, pos]);
        }
      });
    }

    final offenders = <String>[];
    for (final row in rows) {
      final pos = row[4];
      if (!decisive.contains(pos)) continue;
      final byPos = counts[row[3]]!;
      final total = byPos.values.reduce((a, b) => a + b);
      if (total < 10 || byPos[pos] != 1) continue;
      var dominant = pos;
      for (final e in byPos.entries) {
        if (e.value > byPos[dominant]!) dominant = e.key;
      }
      if (dominant == pos || !decisive.contains(dominant)) continue;
      final pair = ([pos, dominant]..sort()).join('|');
      if (functionPairs.contains(pair)) continue;
      final label = '${row[0]} ${row[1]} ${row[2]}';
      if (adjudicated.contains(label)) continue;
      offenders.add('$label ${row[3]} parsed $pos but $dominant elsewhere');
    }
    expect(offenders, isEmpty);
  });

  // The check that needs no outside source at all: the same accented
  // form with the same parse cannot be two different words. Romans 8:24
  // is the one surviving hit and is a base-text question — SBLGNT prints
  // ⸀τίς at that variant point and lemmatises it as the interrogative,
  // so both our columns are right and only our accent follows another
  // edition.
  test('one form with one parse does not carry two Strong\'s numbers', () {
    const adjudicated = <String>{'τις|RI----NSM-|G5101'};
    final tally = <String, Map<String, int>>{};
    for (final slug in <String>['matthew', 'mark', 'luke', 'john', 'acts',
      'romans', '1_corinthians', '2_corinthians', 'galatians', 'ephesians',
      'philippians', 'colossians', '1_thessalonians', '2_thessalonians',
      '1_timothy', '2_timothy', 'titus', 'philemon', 'hebrews', 'james',
      '1_peter', '2_peter', '1_john', '2_john', '3_john', 'jude',
      'revelation']) {
      _book(slug).forEach((_, words) {
        for (final w in words) {
          final morph = ((w as Map)['m'] as String?) ?? '';
          if (morph.isEmpty) continue;
          (tally['${w['w']}|$morph'] ??= <String, int>{})
              .update((w['s'] as String?) ?? '', (n) => n + 1,
                  ifAbsent: () => 1);
        }
      });
    }

    final offenders = <String>[];
    tally.forEach((key, byNumber) {
      if (byNumber.length < 2) return;
      final total = byNumber.values.reduce((a, b) => a + b);
      var dominant = byNumber.keys.first;
      for (final e in byNumber.entries) {
        if (e.value > byNumber[dominant]!) dominant = e.key;
      }
      final dominantN = byNumber[dominant]!;
      if (dominantN < 10) return;
      byNumber.forEach((s, n) {
        if (s == dominant || n > 3 || n / total >= 0.20) return;
        if (adjudicated.contains('$key|$s')) return;
        offenders.add('$key carries $s x$n against $dominant x$dominantN');
      });
    });
    expect(offenders, isEmpty);
  });

  // assets/forms/ is an inverted index over assets/originals, so a word
  // has a parse there only because it has one here. The shipped index
  // was stale: 1,243 of its form entries carried an EMPTY morph code
  // while the corpus had one, because it was built before the check 2a
  // morphology fill and never rebuilt. The Word List showed those words
  // with no parse at all. This is the concordance's check 3b applied to
  // the other derived index.
  test('assets/forms carries the same parse as the corpus it indexes', () {
    final header =
        jsonDecode(File('assets/forms/index.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(header['tokens'], 438821,
        reason: 'the forms index was built from a different corpus');

    final fromCorpus = <String, Set<String>>{};
    for (final file in Directory('assets/originals').listSync()) {
      if (!file.path.endsWith('.json')) continue;
      final book = jsonDecode(File(file.path).readAsStringSync())
          as Map<String, dynamic>;
      for (final words in book.values) {
        for (final w in words as List<dynamic>) {
          final s = ((w as Map)['s'] as String?) ?? '';
          if (s.isEmpty) continue;
          (fromCorpus['$s|${w['w']}'] ??= <String>{})
              .add((w['m'] as String?) ?? '');
        }
      }
    }

    final blanks = <String>[];
    for (final file in Directory('assets/forms/l').listSync()) {
      if (!file.path.endsWith('.json')) continue;
      final shard = jsonDecode(File(file.path).readAsStringSync())
          as Map<String, dynamic>;
      shard.forEach((number, triples) {
        for (final t in triples as List<dynamic>) {
          final form = (t as List<dynamic>)[0] as String;
          final morph = t[1] as String;
          if (morph.isNotEmpty) continue;
          final corpus = fromCorpus['$number|$form'];
          if (corpus != null && !corpus.contains('')) {
            blanks.add('$number $form has no parse but the corpus says '
                '${corpus.join("/")}');
          }
        }
      });
    }
    expect(blanks, isEmpty,
        reason: 'assets/forms is stale — rebuild with '
            'python3 tools/build_forms_index.py --src assets/originals');
  });
}
