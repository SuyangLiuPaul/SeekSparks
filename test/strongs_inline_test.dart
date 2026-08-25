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

  group('splitTrailingCjkPunctuation', () {
    // 2026-08-25, owner-reported: {"w":"起初，","s":"H7225"} (Genesis
    // 1:1, cuvs-yhwh) rendered 起初，H7225 — the number after the CUV's
    // own comma, which has no Hebrew behind it. H7225 is רֵאשִׁית.
    test('Genesis 1:1 — one trailing comma comes off the word', () {
      expect(splitTrailingCjkPunctuation('起初，'), ('起初', '，'));
    });

    test('a word with no trailing punctuation is untouched', () {
      expect(splitTrailingCjkPunctuation('神'), ('神', ''));
    });

    // Measured across assets/tagged/cuvs-yhwh/*.json: every trailing
    // mark actually shipped, one test each so a corpus edit that
    // introduces a new one is caught by a failing case, not silence.
    for (final punct in ['，', '。', '；', '：', '！', '？', '、', '）', '〕']) {
      test('splits trailing $punct', () {
        expect(splitTrailingCjkPunctuation('地$punct'), ('地', punct));
      });
    }

    // 1 Chronicles 1:6 and 2:47 in the shipped corpus: more than one
    // closing mark in a row (a doubled comma is itself a known data
    // defect elsewhere in this file — DATA-INTEGRITY.md — but however
    // many trail, all of them belong after the number, not the word).
    test('more than one trailing mark all comes off, in order', () {
      expect(splitTrailingCjkPunctuation('沙亚弗。）'), ('沙亚弗', '。）'));
      expect(splitTrailingCjkPunctuation('的血，，'), ('的血', '，，'));
    });

    // 1 Chronicles 2:3 in the shipped corpus: a LEADING dùn hào opens
    // this run because it continues a list from the previous run. It
    // is not trailing THIS word, so it stays — splitting it would
    // attribute someone else's separator to this word's number.
    test('leading punctuation is left alone', () {
      expect(splitTrailingCjkPunctuation('、俄南'), ('、俄南', ''));
    });

    // 1 Chronicles 1:19: an entire 〔note〕 folded into one run, itself
    // ending mid-clause with no trailing punctuation of its own at
    // this point — nothing to split, and the note's internal 〕 must
    // not be mistaken for a trailing mark since it does not sit at
    // the very end.
    test('an embedded note with nothing trailing is left alone', () {
      expect(splitTrailingCjkPunctuation('居住；法勒的兄弟'),
          ('居住；法勒的兄弟', ''));
    });

    test('a run that is ONLY punctuation splits to an empty stem', () {
      // The "punctuation stands for an unrendered original word" class
      // documented in DATA-INTEGRITY.md (CUV omits a Hebrew word the
      // Strong's number still names) — the number belongs right where
      // the word would have been, ahead of the mark it borrowed.
      expect(splitTrailingCjkPunctuation('，'), ('', '，'));
    });

    test('ASCII punctuation (English tagged editions) is left alone', () {
      // Deliberately out of scope — see the function's own doc comment
      // for why "the same underlying defect" is not "the same fix".
      expect(splitTrailingCjkPunctuation('beginning,'), ('beginning,', ''));
    });
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
