import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/cbol_references.dart';

/// Check 28 (docs/DATA-INTEGRITY.md), frozen.
///
/// The Chinese lexicon cites scripture in a `#…|` notation. Every count
/// below was measured over the four bundled assets; the test exists so
/// that a re-import cannot quietly widen the hole. A number moving DOWN
/// is an improvement and should be pinned to its new value; a number
/// moving UP means new unreadable references reached the reader.
void main() {
  /// Every string in an entry that a reader can end up looking at.
  Iterable<String> userFacing(Map<String, dynamic> entry) sync* {
    for (final key in const [
      'glossZh', 'defZh', 'glossZhTw', 'defZhTw', // greek/hebrew
      'l', 't', 'e', 'u', // bdb_zh/thayer_zh
    ]) {
      final v = entry[key];
      if (v is String && v.isNotEmpty) yield v;
    }
    for (final v in (entry['s'] as List?) ?? const []) {
      if (v is String && v.isNotEmpty) yield v;
    }
  }

  Map<String, dynamic> load(String name) => json
      .decode(File('assets/strongs/$name.json').readAsStringSync())
      as Map<String, dynamic>;

  test('the lexicon\'s citations are readable and resolvable', () {
    var strings = 0;
    var citations = 0;
    var unreadable = 0;
    final unreadableEntries = <String>{};

    for (final name in const ['greek', 'hebrew', 'bdb_zh', 'thayer_zh']) {
      for (final e in load(name).entries) {
        for (final s in userFacing(e.value as Map<String, dynamic>)) {
          if (!s.contains('#') && !s.contains('|')) continue;
          strings++;
          final runs = parseCbolRuns(s);
          citations +=
              runs.where((r) => r.kind == CbolRunKind.reference).length;
          final left = runs
              .where((r) => r.kind == CbolRunKind.text)
              .fold<int>(0, (n, r) => n + '#'.allMatches(r.text).length);
          if (left > 0) {
            unreadable += left;
            unreadableEntries.add('$name/${e.key}');
          }
        }
      }
    }

    // 46,727 citations across the four assets resolve to a book,
    // chapter and verse the reader can navigate to. It was 46,052 until
    // check 44f rebuilt `glossZh`/`glossZhTw` from the whole of sense 1:
    // 675 of these sit past the line break the old gloss stopped at, so
    // they were only ever reachable from the definition body.
    expect(citations, 46727);

    // 60 `#` sites — 36 distinct, the rest the same defect repeated in
    // the Traditional column — do not parse. They are defects in the
    // source data, catalogued in check 28: a missing book token, a `:`
    // where a chapter should be, prose behind the hash, a doubled book
    // token, or an abbreviation (`代`, `撒`) that is genuinely ambiguous
    // between two books. Each is passed through verbatim rather than
    // guessed at.
    expect(unreadable, 60);
    expect(unreadableEntries.length, 32);
    expect(strings, greaterThan(30000));
  });

  test('nothing readable reaches the reader still wearing its delimiters',
      () {
    for (final name in const ['greek', 'hebrew', 'bdb_zh', 'thayer_zh']) {
      for (final e in load(name).entries) {
        for (final s in userFacing(e.value as Map<String, dynamic>)) {
          if (!s.contains('#') && !s.contains('|')) continue;
          final plain = cbolPlainText(s);
          // A '|' only survives where the '#' before it did — i.e. in
          // one of the 673 sites the parser refuses to read.
          if (!plain.contains('#')) {
            expect(plain.contains('|'), isFalse,
                reason: '$name/${e.key}: $s');
          }
        }
      }
    }
  });

  // ── check 44f: the gloss that stopped where the page broke ─────────
  //
  // `glossZh` is the row summary in the Lexicon Browser and the gloss in
  // word study. It was built from the first physical LINE of CBOL's
  // sense 1, and CBOL wraps a long sense at its own column width, so 488
  // entries shipped a fragment — H204 ended on a comma with the clause
  // naming it as Potiphera's home town on line two.
  //
  // The risk in the repair is the opposite error: CBOL uses one newline
  // for a wrap and for a deliberate break, so joining everything invents
  // readings. G749's `祭司长, 大祭司` sits on a 17-column line in a
  // 90-column entry and the next line opens a new article; joining them
  // gave `大祭司在祭司中最大的一`, which is in no lexicon. Both halves
  // are pinned below.

  group('the Chinese gloss is the whole of sense 1', () {
    Iterable<({String num, String key, String gloss, String body})> glosses() sync* {
      for (final name in const ['greek', 'hebrew']) {
        for (final e in load(name).entries) {
          final entry = e.value as Map<String, dynamic>;
          for (final pair in const [
            ('glossZh', 'defZh'),
            ('glossZhTw', 'defZhTw'),
          ]) {
            final g = entry[pair.$1];
            final b = entry[pair.$2];
            if (g is String && g.isNotEmpty) {
              yield (
                num: e.key,
                key: pair.$1,
                gloss: g,
                body: b is String ? b : '',
              );
            }
          }
        }
      }
    }

    test('a wrapped sense arrives whole', () {
      final hebrew = load('hebrew');
      // H204 אֹן On/Heliopolis — the worked example.
      expect(hebrew['H204']['glossZh'], endsWith('居住之地'));
      expect(hebrew['H204']['glossZhTw'], endsWith('居住之地'));
      // H218 אוּר Ur — the second line names Terah and the migration.
      expect(hebrew['H218']['glossZh'], contains('亚伯拉罕父亲他拉的家乡'));
      // G4102 πίστις — five lines, and the shipped gloss kept one.
      expect(load('greek')['G4102']['glossZh'], contains('信靠的观念'));
      // H1374 closed a parenthesis mid-sentence, so a bracket alone must
      // not read as the end: the village is between the ridges of
      // Anathoth and Nob, not at Anathoth.
      expect(hebrew['H1374']['glossZh'], contains('和挪伯城所在的山脊之间'));
    });

    test('a deliberate break is not joined across', () {
      final greek = load('greek');
      // G749 ἀρχιερεύς — the over-join this rule exists to prevent.
      expect(greek['G749']['glossZh'], '祭司长, 大祭司');
      // G5208 ὕλη — the next line is the heading `经文以外的意思`.
      expect(greek['G5208']['glossZh'], isNot(contains('经文以外')));
      // A gloss that ends in a colon is a stub CBOL continues on its own
      // terms; `StrongsEntry.localizedGloss` has a path for those and it
      // must keep firing.
      expect(greek['G1537']['glossZh'], endsWith(':'));
    });

    test('no gloss ends mid-clause', () {
      final dangling = [
        for (final g in glosses())
          if (RegExp(r'[,，、;；]\s*$').hasMatch(g.gloss)) '${g.num}/${g.key}',
      ];
      expect(dangling, isEmpty,
          reason: 'a gloss ending on a separator is a sentence cut short');
    });

    test('every gloss is text the module actually printed', () {
      // The join reflows CBOL's own lines, so a gloss must still be a
      // contiguous run of its definition body once the line breaks are
      // taken out. This is what separates reflowing from paraphrasing,
      // and it holds for all 28,368 glosses, not only the repaired ones.
      final ws = RegExp(r'\s+');
      var checked = 0;
      for (final g in glosses()) {
        if (g.body.isEmpty) continue;
        checked++;
        expect(g.body.replaceAll(ws, ''), contains(g.gloss.replaceAll(ws, '')),
            reason: '${g.num}/${g.key} says something the body does not');
      }
      expect(checked, 28368);
    });
  });
}
