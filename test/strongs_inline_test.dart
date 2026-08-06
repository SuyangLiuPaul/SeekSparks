/// 2026-08-06 (SeekSparks): what a tagged line prints after each word.
///
/// The expectations here are read off yahwehdehua.net's own rendering of
/// Matthew 1:1-2, which is the presentation this feature is copying.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/strongs_inline.dart';

void main() {
  List<String> printed(List<StrongsNumberToken> t) =>
      t.map((e) => e.text).toList();

  test('a plain lexical word prints one green number', () {
    // 亚伯拉罕 G11
    final t = inlineStrongsNumbers(strongs: 'G11');
    expect(printed(t), ['G11']);
    expect(t.single.kind, StrongsNumberKind.lexical);
  });

  test('a verb prints its lexical number then its TVM code', () {
    // 生 G1080 G5656 — γεννάω, aorist active indicative.
    final t = inlineStrongsNumbers(strongs: 'G1080', grammar: ['G5656']);
    expect(printed(t), ['G1080', 'G5656']);
    expect(t.map((e) => e.kind),
        [StrongsNumberKind.lexical, StrongsNumberKind.grammar]);
  });

  test('an implied word is parenthesised and printed FIRST', () {
    // 以撒 (G3588) G2464 — the article precedes the noun in the Greek,
    // and the printed order has to follow the original, not our parse.
    final t = inlineStrongsNumbers(strongs: 'G2464', implied: ['G3588']);
    expect(printed(t), ['(G3588)', 'G2464']);
    expect(t.first.kind, StrongsNumberKind.implied);
  });

  test('Hebrew object marker behaves the same way', () {
    // 天 (H853) H8064 — אֵת before שָׁמַיִם in Genesis 1:1.
    final t = inlineStrongsNumbers(strongs: 'H8064', implied: ['H853']);
    expect(printed(t), ['(H853)', 'H8064']);
  });

  test('all three kinds keep implied · lexical · grammar order', () {
    final t = inlineStrongsNumbers(
      strongs: 'H8064',
      grammar: ['H8804'],
      implied: ['H853'],
    );
    expect(printed(t), ['(H853)', 'H8064', 'H8804']);
  });

  test('an untagged run prints nothing at all', () {
    // Punctuation and inserted connectives carry no number; printing an
    // empty superscript would put stray marks through the sentence.
    expect(inlineStrongsNumbers(strongs: ''), isEmpty);
    expect(inlineStrongsNumbers(strongs: '', implied: [''], grammar: ['']),
        isEmpty);
  });

  group('pickAnalysisVerse', () {
    // v1.5.4 blanked the entire Workbench: the X-Refs and Stats tabs
    // read `verses.first` unconditionally, and a hovered word could
    // now reach them with nothing selected. `List.first` throws on
    // empty, and a release ErrorWidget is a plain grey rectangle — so
    // the panes vanished while the chrome outside kept painting.
    test('a selection always wins', () {
      expect(pickAnalysisVerse(['sel'], 'hov'), 'sel');
    });

    test('falls back to the hovered verse when nothing is selected', () {
      expect(pickAnalysisVerse(<String>[], 'hov'), 'hov');
    });

    test('returns null rather than throwing when there is neither', () {
      expect(pickAnalysisVerse(<String>[], null), isNull);
    });
  });
}
