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

    // 46,052 citations across the four assets resolve to a book,
    // chapter and verse the reader can navigate to.
    expect(citations, 46052);

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
}
