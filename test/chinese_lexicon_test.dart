/// 2026-08-06 (SeekSparks): the Chinese BDB/Thayer lexicon.
///
/// Unlike the Browse window, this service reads straight from the asset
/// bundle, which `flutter test` serves — so these assertions are real,
/// not smoke.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/services/chinese_lexicon_service.dart';

Map<String, dynamic> _raw(String file) =>
    json.decode(File('assets/strongs/$file.json').readAsStringSync())
        as Map<String, dynamic>;

/// Every lexical entry in both Chinese works, grammar codes excluded.
Iterable<MapEntry<String, dynamic>> _lexical() sync* {
  for (final file in const ['bdb_zh', 'thayer_zh']) {
    for (final e in _raw(file).entries) {
      if ((e.value as Map)['p'] == null) yield e;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(ChineseLexiconService.resetForTest);

  test('Hebrew entry carries lemma, senses and KJV counts', () async {
    // H8064 שָׁמַיִם — the "heavens" of Genesis 1:1.
    final e = await ChineseLexiconService.lookup('H8064');
    expect(e, isNotNull, reason: 'bdb_zh.json did not load');
    expect(e!.lemma, contains('שׁמים'));
    expect(e.senses.join(), contains('天'));
    expect(e.usage, contains('钦定本'));
    expect(e.isGrammarCode, isFalse);
  });

  test('Greek entry resolves', () async {
    // G2464 Ἰσαάκ — the name behind 以撒 in Matthew 1:2.
    final e = await ChineseLexiconService.lookup('G2464');
    expect(e, isNotNull, reason: 'thayer_zh.json did not load');
    expect(e!.senses.join(), contains('以撒'));
    expect(e.lemma, contains('Ἰσαάκ'));
  });

  test('Greek lemmas are composed, matching assets/originals', () async {
    // The source module ships Greek DECOMPOSED — 'Ἰ' as Ι + U+0313.
    // assets/originals/ is composed. Lookup is by Strong's number so
    // nothing compares them today, but a Greek text search would
    // silently miss every accented word. The importer normalises to
    // NFC; this pins that so a re-import cannot quietly undo it.
    final e = await ChineseLexiconService.lookup('G2464');
    expect(e!.lemma.runes.toList(), [0x1f38, 0x3c3, 0x3b1, 0x3ac, 0x3ba],
        reason: 'expected composed Ἰσαάκ, got decomposed');
  });

  test('grammar codes decode to a parsing, not a lexical entry', () async {
    // G5656 is the blue number on 生 in Matthew 1:2 — aorist active
    // indicative. Before this service it printed as a bare number with
    // nowhere to look it up.
    final g = await ChineseLexiconService.lookup('G5656');
    expect(g, isNotNull);
    expect(g!.isGrammarCode, isTrue);
    expect(g.parsing.join(' '), contains('时态'));
    expect(g.lemma, isEmpty, reason: 'a code has no headword');

    final h = await ChineseLexiconService.lookup('H8804');
    expect(h, isNotNull);
    expect(h!.isGrammarCode, isTrue);
  });

  test('unknown numbers and junk return null, not an empty shell',
      () async {
    expect(await ChineseLexiconService.lookup('H99999'), isNull);
    expect(await ChineseLexiconService.lookup(''), isNull);
    expect(await ChineseLexiconService.lookup('X1'), isNull);
  });

  test('applies to zh only; Traditional is flagged as Simplified-only',
      () {
    expect(ChineseLexiconService.appliesTo('zh-Hans'), isTrue);
    expect(ChineseLexiconService.appliesTo('zh-Hant'), isTrue);
    expect(ChineseLexiconService.appliesTo('en'), isFalse);

    // The module ships Simplified only. A 繁體 reader must be told that
    // rather than left to assume the conversion silently failed.
    expect(ChineseLexiconService.isSimplifiedOnly('zh-Hant'), isTrue);
    expect(ChineseLexiconService.isSimplifiedOnly('zh-Hans'), isFalse);
  });

  // ── check 44: the fields the importer used to cut in half ──────────
  //
  // The module breaks its prose across <p> elements wherever the printed
  // page broke, and the first importer read those as one <p> per FIELD.
  // Where an etymology ran to two lines it kept the first half, then
  // took the second half to be the KJV usage line, found it was not, and
  // served both halves to the reader as numbered senses. So the reader
  // saw a definition that stopped mid-clause, no usage counts at all,
  // and two fragments presented as senses of the word.
  //
  // These assertions are worth more than they look: the defect renders
  // perfectly, throws nothing, and the suite was green throughout.

  test('an etymology that wraps arrives whole, with its usage', () async {
    // H205 אָוֶן — the worked example. Its etymology broke at
    // `使尽浑身解数` and the remainder became sense 1.
    final e = await ChineseLexiconService.lookup('H205');
    expect(e!.etymology, endsWith('阳性名词'));
    expect(e.etymology, contains('通常是徒劳的'));
    // The usage is a COUNT claim, so a truncated one is worse than an
    // absent one: it reads as the complete KJV tally and is not.
    expect(e.usage, startsWith('钦定本'));
    expect(e.usage, endsWith('; 78'));
    expect(e.senses.first, startsWith('1)'));
  });

  test('G1537 ἐκ keeps the clause that was cut at its bracket', () async {
    final e = await ChineseLexiconService.lookup('G1537');
    expect(e!.etymology, contains('某时间'));
    expect(e.usage, endsWith('; 921'));
  });

  test('G3588 ὁ splits where the module glued usage onto etymology',
      () async {
    // The commonest word in the Greek New Testament, and its whole entry
    // arrived as one line: `定冠词钦定本 - which 413…`. The dash after
    // 钦定本 is what makes the split safe — seven other entries mention
    // the KJV in running prose and none of them is followed by a dash
    // and a count list.
    final e = await ChineseLexiconService.lookup('G3588');
    expect(e!.etymology, '定冠词');
    expect(e.usage, endsWith('; 543'));
  });

  group('across both shipped Chinese works', () {
    test('a usage line is never served as a sense', () {
      // This is the detector, not an example: `钦定本 - ` at the head of
      // a sense is the signature the defect left behind.
      final offenders = [
        for (final e in _lexical())
          if (((e.value['s'] as List?) ?? const [])
              .any((s) => (s as String).startsWith('钦定本 -')))
            e.key,
      ];
      expect(offenders, isEmpty);
    });

    test('the usage field is present and complete where the module has one',
        () {
      var withUsage = 0;
      var endsInTotal = 0;
      for (final e in _lexical()) {
        final u = (e.value['u'] ?? '') as String;
        if (u.isEmpty) continue;
        withUsage++;
        expect(u, startsWith('钦定本'));
        if (RegExp(r'[;,]\s*\d+\s*$').hasMatch(u)) endsInTotal++;
      }
      // 14,197 lexical entries. 8 carry no 钦定本 line at all — damage in
      // the module itself, not in the import, and left alone rather than
      // invented. Before the repair only 13,721 had the field.
      expect(withUsage, 14189);
      // A complete KJV usage ends `; TOTAL`. The 6 that do not are the
      // module's own punctuation slips (`, 2` for a one-word entry, or a
      // proper-name gloss typed onto the same line), not truncation.
      expect(endsInTotal, 14183);
    });
  });
}
