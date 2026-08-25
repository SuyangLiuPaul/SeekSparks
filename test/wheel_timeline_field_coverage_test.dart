/// The ratchet on the merge (#318 phase 21).
///
/// `bibleNarrativeEvents` has now shipped the same defect three times:
/// a field declared on `TimelineEvent`, present in the asset, read by
/// `fromJson`, and then dropped on the floor at the `WheelHistoryEvent`
/// constructor because the constructor had no parameter to receive it.
/// It went `basis` (phase 17), then `datingRefs` / `septuagintYear` /
/// `era` (phase 19), then `personIds` (phase 21).
///
/// Nothing could see it. The asset tests pass — the data is there. The
/// timeline page's tests pass — that page reads `TimelineEvent`
/// directly. The wheel's tests pass — they assert about the fields the
/// wheel *does* carry. A dropped field is invisible everywhere except
/// in a diff of the two class declarations, which is exactly what this
/// test does mechanically instead of hoping someone does it by eye.
///
/// It reads the source rather than the objects on purpose: an object
/// whose field was never populated is indistinguishable from an object
/// whose field is legitimately empty, so a runtime check would have to
/// find a record that exercises every field and would go quiet the
/// moment the data thinned.
///
/// Measured reach, by running it against the two commits that shipped
/// the defect: at HEAD~ it reports `personIds`, and at the commit
/// before phase 19 it reports `personIds, datingRefs, septuagintYear`.
/// It does NOT report phase 19's fourth field, `era` — that one was
/// already read to choose a stream while its value went nowhere, and
/// "mentions the field" cannot tell reading from carrying. That blind
/// spot is why the second test below exists.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strips `//` line comments so a field named only in prose — a doc
/// comment explaining why something was dropped, say — cannot satisfy
/// the check.
String _code(String src) => src
    .split('\n')
    .map((l) {
      final i = l.indexOf('//');
      return i < 0 ? l : l.substring(0, i);
    })
    .join('\n');

/// The body of a top-level function, handling both `=> …;` and `{ … }`.
///
/// Two traps, both hit while writing this: the parameter list of a
/// function with named parameters is itself a `{ … }`, so the body must
/// be found after the closing paren, not after the first brace; and
/// this function has been an expression body before, where the first
/// brace encountered is a `${…}` interpolation and matching it returns
/// a fragment that fails every assertion for the wrong reason.
String _bodyOf(String src, String signature) {
  final start = src.indexOf(signature);
  expect(start, greaterThanOrEqualTo(0), reason: 'no $signature in source');
  var paren = 0;
  var afterParams = -1;
  for (var i = src.indexOf('(', start); i < src.length; i++) {
    if (src[i] == '(') paren++;
    if (src[i] == ')') {
      paren--;
      if (paren == 0) {
        afterParams = i;
        break;
      }
    }
  }
  expect(afterParams, greaterThan(0), reason: 'unbalanced parens: $signature');
  final open = afterParams + 1 + src.substring(afterParams + 1).indexOf(
      RegExp(r'\S'));
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    final c = src[i];
    if (c == '{' || c == '(' || c == '[') depth++;
    if (c == '}' || c == ')' || c == ']') {
      depth--;
      if (depth == 0 && src[open] == '{') return src.substring(open, i + 1);
    }
    if (c == ';' && depth == 0) return src.substring(open, i + 1);
  }
  fail('could not find the end of $signature');
}

void main() {
  final model = _code(File('lib/models/timeline_event.dart').readAsStringSync());
  final merge = _code(File('lib/models/wheel_history.dart').readAsStringSync());

  // `final <Type> <name>;` — the declaration form this class uses.
  final fields = RegExp(r'^\s{2}final\s+[\w<>?, ]+\s+(\w+);', multiLine: true)
      .allMatches(model)
      .map((m) => m.group(1)!)
      .toList();

  test('the field list was really found', () {
    // If a refactor changes the declaration style the regex goes empty
    // and every assertion below passes vacuously.
    expect(fields, hasLength(15));
    expect(fields, containsAll(['id', 'year', 'era', 'personIds', 'basis']));
  });

  test('every TimelineEvent field is read by the merge', () {
    final body = _bodyOf(merge, 'List<WheelHistoryEvent> bibleNarrativeEvents');
    final missing = [for (final f in fields) if (!body.contains('e.$f')) f];
    expect(missing, isEmpty,
        reason: 'bibleNarrativeEvents never reads: ${missing.join(', ')} — '
            'the field will be dropped at the WheelHistoryEvent constructor '
            'and no other test in this repo can see it');
  });

  // Reading a field is not carrying it: `era` is read to pick a stream.
  // These are the ones whose value must survive unchanged, so a future
  // edit that reads a field only to make a decision about it still
  // fails here.
  test('the fields that must arrive unchanged are named in the constructor',
      () {
    final body = _bodyOf(merge, 'List<WheelHistoryEvent> bibleNarrativeEvents');
    for (final f in [
      'year',
      'refs',
      'basis',
      'approximate',
      'datingRefs',
      'septuagintYear',
    ]) {
      expect(body, contains('$f: e.$f'), reason: '$f is not passed through');
    }
  });
}
