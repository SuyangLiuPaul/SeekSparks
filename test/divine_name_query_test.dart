/// 耶和华 must find the verses that hold it.
///
/// The corpus key is built by `searchCorpusKey`, which rewrites the
/// Tetragrammaton to 雅伟 / 雅偉 — so the shipped Chinese editions hold
/// **zero** occurrences of the spelling every printed Chinese Bible uses,
/// and until 2026-09-08 nothing did the same to the query. A reader who
/// typed the name got an empty list and no reason for it.
///
/// The tests below are deliberately written against the REAL assets: the
/// defect was a disagreement between two transforms over the shipped
/// text, and a fixture cannot disagree the same way.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/text_patterns.dart'
    show normalizeDivineNamesInQuery, searchCorpusKey;
import 'package:seeksparks/utils/search_highlight.dart';

List<String> _keys(String path) {
  final raw = json.decode(File(path).readAsStringSync());
  final rows = raw is List ? raw : (raw['verses'] as List);
  return [
    for (final r in rows) searchCorpusKey((r as Map)['text'] as String? ?? '')
  ];
}

void main() {
  test(
      'the spelling in every printed Chinese Bible is absent from the '
      'corpus this app searches', () {
    // Not a complaint about the edition — 和合本雅伟版 renames the name on
    // purpose. It is the premise: the query has to be told.
    final keys = _keys('assets/cuvs-yhwh.json');
    expect(keys.where((k) => k.contains('耶和华')), isEmpty);
    expect(keys.where((k) => k.contains('雅伟')).length, greaterThan(6000));
  });

  test('typing 耶和华 reaches the verses that spell it 雅伟', () {
    final keys = _keys('assets/cuvs-yhwh.json');
    final q = normalizeDivineNamesInQuery('耶和华');
    expect(keys.where((k) => k.contains(q)).length, greaterThan(6000),
        reason: 'the query must be normalised the same way the corpus was');
  });

  test('and 耶和華 reaches 雅偉 in the Traditional edition', () {
    final keys = _keys('assets/cuvs-yhwh-tr.json');
    final q = normalizeDivineNamesInQuery('耶和華');
    expect(keys.where((k) => k.contains(q)).length, greaterThan(6000));
  });

  test('the reader can SEE the hit, not just be handed the verse', () {
    // Half a fix is worse than none here: a verse whose match cannot be
    // found on the page reads as a wrong result.
    final h = highlightsForQuery('耶和华');
    expect(h.textTerms, contains('雅伟'));
    expect(h.textTerms, isNot(contains('耶和华')));
  });

  test('mixed-case Lord is left alone, because it is a different name', () {
    // `_normalizeDivineNames` only ever rewrote the ALL-CAPS LORD; a
    // query is lower-cased downstream, so the English side was already
    // symmetric and the Adonai / kyrios distinction survives.
    expect(normalizeDivineNamesInQuery('Lord'), 'Lord');
    expect(normalizeDivineNamesInQuery('lord'), 'lord');
  });

  test('a query with no divine name in it is returned untouched', () {
    for (final q in const ['love', '爱', 'in the beginning', '起初 神']) {
      expect(normalizeDivineNamesInQuery(q), q);
    }
  });
}
