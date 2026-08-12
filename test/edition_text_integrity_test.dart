// Corpus-wide guards on the shape of verse text (check 31c).
//
// `test/kjv_integrity_test.dart` asserted these over three of the eleven
// bundled editions, because check 27 was a KJV investigation. That is
// why `assets/leb.json` shipped 31,199 verses each ending in a newline
// for as long as it has been in the repository: the test that would have
// caught it was pointed at three other files.
//
// The reader never showed the padding — every sanitiser in
// `text_patterns.dart` ends in `.trim()` — but Browse hands the raw
// string to `parseScripture`, which strips markup and nothing else, so
// every LEB row in the compare pane stood a blank line taller than the
// editions beside it. `tools/repair_verse_whitespace.py` repaired it and
// this keeps it repaired, for every edition rather than for three.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every edition of the Bible text committed to this repository.
///
/// `nasb-ev.json` and `nsn-plus.json` are deliberately absent: Eagle's
/// View NASB is licensed, never committed, and a test that named it
/// would fail on any clone but this one.
const kEditionAssets = <String>[
  'assets/biblexg-v2-tr.json',
  'assets/biblexg-v2.json',
  'assets/bsb.json',
  'assets/cuvs-plus.json',
  'assets/cuvs-yhwh-tr.json',
  'assets/cuvs-yhwh.json',
  'assets/kjv.json',
  'assets/kjvs.json',
  'assets/leb.json',
  'assets/lxxwh.json',
  'assets/nasb.json',
];

void main() {
  for (final asset in kEditionAssets) {
    group('$asset text shape', () {
      late List<Map<String, dynamic>> verses;

      setUpAll(() {
        verses = (json.decode(File(asset).readAsStringSync()) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      });

      test('is a non-empty list of verse records', () {
        expect(verses, isNotEmpty);
        expect(verses.first.containsKey('text'), isTrue);
      });

      test('no verse is padded with whitespace', () {
        final offenders = verses
            .where((v) => (v['text'] as String).trim() != v['text'])
            .map((v) => v['id'])
            .toList();
        expect(offenders, hasLength(0),
            reason: 'padding is invisible in the reader, which trims, and '
                'visible in Browse, which does not; '
                '${offenders.length} offenders, first ${offenders.take(3)}');
      });

      test('carries no conversion pipe', () {
        final offenders = verses
            .where((v) => (v['text'] as String).contains('|'))
            .map((v) => v['id'])
            .toList();
        expect(offenders, isEmpty,
            reason: 'a "|" in Bible text is a leftover from conversion, and '
                'two of them landed inside words; offenders: $offenders');
      });
    });
  }

  // Check 27 found `and was sick : and he sent` in the KJV and repaired it.
  // Run over the whole corpus the same pattern finds exactly two more, and
  // neither is that defect — so both are named rather than repaired, and
  // naming them is what keeps a third from arriving unnoticed.
  test('no verse prints a space before its punctuation', () {
    // An ellipsis is a space followed by a dot on purpose, so the dot only
    // counts when it is not one.
    final spaced = RegExp(r'\s(?:\.(?!\.)|[,;:!?)])');
    const known = <String, String>{
      // LEB Judges 14:6 — `( he was bare-handed )`, padding inside the
      // publisher's own parenthesis. Typography, not wording, and there is
      // no external LEB witness in this repository to check a repair
      // against, so it is recorded rather than edited.
      '007014006': 'assets/leb.json',
      // NASB Jeremiah 29:28 — `’ ?” ’ ”`. Those are U+2009 THIN SPACEs
      // holding four nested closing quotes apart, which is correct
      // typesetting; `scripture_markup.dart` already documents the same
      // 608 thin spaces as deliberate.
      '024029028': 'assets/nasb.json',
    };

    final offenders = <String>[];
    for (final asset in kEditionAssets) {
      final verses = (json.decode(File(asset).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      for (final v in verses) {
        if (!spaced.hasMatch(v['text'] as String)) continue;
        final id = v['id']?.toString() ?? '';
        if (known[id] == asset) continue;
        offenders.add('$asset $id');
      }
    }
    expect(offenders, isEmpty,
        reason: 'reads as "and was sick : and he sent"; '
            '${offenders.length} offenders, first ${offenders.take(5)}');
  });
}
