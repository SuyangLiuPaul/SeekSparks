/// 2026-08-06 (SeekSparks): the Chinese BDB/Thayer lexicon.
///
/// Unlike the Browse window, this service reads straight from the asset
/// bundle, which `flutter test` serves — so these assertions are real,
/// not smoke.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/services/chinese_lexicon_service.dart';

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
}
