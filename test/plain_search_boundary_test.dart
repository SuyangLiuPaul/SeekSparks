/// 2026-09-05: the plain-search word-boundary rule, pinned against the
/// real editions.
///
/// A plain command line (no control character) was a substring scan over
/// a corpus with its spaces removed, so KJV `forth` listed the 2,542
/// verses that say "for the" and marked nothing in any of them. The fix
/// is in `lib/utils/plain_search.dart`; this file is the evidence that
/// it bites in English and that it does not touch Chinese.
///
/// Every count here was measured, not chosen. If one moves, the engine
/// changed and the number in `plain_search.dart`'s header is now a lie
/// as well.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/search_service.dart';
import 'package:seeksparks/utils/plain_search.dart';
import 'package:seeksparks/utils/psalm_superscription.dart';

void main() {
  List<Map<String, dynamic>> records(String asset) => [
        for (final e in json.decode(File(asset).readAsStringSync()) as List)
          (e as Map).cast<String, dynamic>(),
      ];

  MainProvider corpus(String asset) {
    final folded = foldSuperscriptions(records(asset));
    final verses = <Verse>[];
    for (final m in folded.records) {
      if (int.tryParse(m['verse']?.toString() ?? '') == null) continue;
      verses.add(Verse.fromJson(m));
    }
    return MainProvider()..setVerses(verses);
  }

  List<Verse> plain(MainProvider mp, String q) => SearchService.scanText(
        verses: mp.verses,
        searchKeys: mp.searchKeys,
        query: q,
        bookOrder: mp.bookOrder,
        searchAll: true,
      ).matches;

  // ── The rule, without a corpus ────────────────────────────────────

  group('collapseSearchSpaces', () {
    test('keeps one space per alphabetic gap', () {
      expect(collapseSearchSpaces('for  the\nlord'), 'for the lord');
    });

    test('drops a gap that has Han characters on both sides', () {
      expect(collapseSearchSpaces('这 诫命'), '这诫命');
      expect(collapseSearchSpaces('起初　神'), '起初神');
    });

    test('keeps a gap where only one side is Han', () {
      // A Latin proper name beside Han text is a real word boundary and
      // stays one, inside the same string as a Han seam that does not.
      expect(collapseSearchSpaces('主 jesus 爱 神'), '主 jesus 爱神');
    });

    test('trims the ends', () {
      expect(collapseSearchSpaces('  god  '), 'god');
    });
  });

  group('plainSearchMatches', () {
    final key = searchCorpusKey('And he went forth for the second time');

    test('a query with no space may not cross one', () {
      expect(plainSearchMatches(key, plainSearchSegments('forthe')), isFalse);
    });

    test('a query with a space matches across the gap', () {
      expect(plainSearchMatches(key, plainSearchSegments('for the')), isTrue);
    });

    test('a query may still sit inside a word', () {
      expect(plainSearchMatches(key, plainSearchSegments('econd')), isTrue);
    });

    test("a query's space absorbs no space at all", () {
      // `in deed` still reaches "indeed" — the half of the old space
      // strip that was doing real work.
      final indeed = searchCorpusKey('Verily indeed it is so');
      expect(plainSearchMatches(indeed, plainSearchSegments('in deed')), isTrue);
    });

    test('segments must be contiguous, not merely both present', () {
      expect(plainSearchMatches(key, plainSearchSegments('forth second')),
          isFalse);
    });
  });

  // ── English: the defect itself ────────────────────────────────────

  group('KJV', () {
    late MainProvider kjv;
    setUpAll(() => kjv = corpus('assets/kjv.json'));

    test('`forth` no longer lists the verses that say "for the"', () {
      final hits = plain(kjv, 'forth');
      expect(hits.length, 877,
          reason: 'was 3,419 — 2,542 of them "for the" and nothing else');

      // The count alone would pass for a rule that happened to keep 877
      // of the wrong verses. This is the property that actually matters:
      // every listed verse holds a "forth" the reader can be shown.
      for (final v in hits) {
        expect(searchCorpusKey(v.scriptureText), contains('forth'),
            reason: '${v.book} ${v.chapter}:${v.verse} was listed for '
                '`forth` with no "forth" in it');
      }
    });

    test('a real word-boundary hit still matches', () {
      final refs = {
        for (final v in plain(kjv, 'forth'))
          '${v.book} ${v.chapter}:${v.verse}'
      };
      expect(refs, contains('Genesis 1:12'));
      expect(refs, contains('Genesis 1:24'));
    });

    test('the whole phrase `for the` still works, and is 9 tighter', () {
      expect(plain(kjv, 'for the').length, 2020,
          reason: 'was 2,029; the 9 lost held "forth e…", never "for the"');
    });

    test('a match inside a word is deliberately kept', () {
      // `docs/PARITY-BACKLOG.md` calls this a different thing from the
      // defect and "arguably wanted"; it is also markable, which the
      // boundary-spanning rows never were.
      expect(plain(kjv, 'walk').length, 390);
      expect(plain(kjv, 'shalom').length, 3);
    });

    test('the other four words the backlog measured', () {
      expect(plain(kjv, 'asa').length, 207); // was 1,301
      expect(plain(kjv, 'heirs').length, 24); // was 369
      expect(plain(kjv, 'end').length, 1205); // was 1,524
      expect(plain(kjv, 'oar').length, 117); // was 237
    });
  });

  // ── Chinese: the thing that must not move ─────────────────────────

  group('和合本 (cuvs-yhwh)', () {
    late MainProvider zh;
    setUpAll(() => zh = corpus('assets/cuvs-yhwh.json'));

    test('a Han query is still a substring search', () {
      expect(plain(zh, '爱').length, 822);
      expect(plain(zh, '神').length, 3994);
      expect(plain(zh, '爱神').length, 12);
      expect(plain(zh, '起初').length, 37);
      expect(plain(zh, '神爱世人').length, 1);
      expect(plain(zh, '雅伟').length, 6102);
    });

    test('a Han query typed with a space still reaches the run', () {
      expect(plain(zh, '起初 神').length, 1);
    });

    test('a Han query steps over a space the edition happens to hold', () {
      // The edition sets 玛拉基书 2:1 as 「这 诫命」 and 历代志上 21:20 as
      // 「就和他 四个儿子」. Scripture is frozen, so the reader who types
      // the words without the stray space still has to reach them —
      // which is exception 2 in `plain_search.dart`, and the reason the
      // boundary rule cannot be script-blind. Without that exception
      // these two counts fall to 3 and 0.
      expect(plain(zh, '这诫命').length, 4);
      expect(plain(zh, '就和他四个儿子').length, 1);
    });
  });

  // ── Greek: spaces, and accents already folded ─────────────────────

  group('lxxwh', () {
    late MainProvider lxx;
    setUpAll(() => lxx = corpus('assets/lxxwh.json'));

    test('accented and unaccented both still find the word', () {
      expect(plain(lxx, 'θεος').length, 1623);
      expect(plain(lxx, 'ὁ θεός').length, 1486);
      expect(plain(lxx, 'αγαπη').length, 248);
    });

    test('a two-word Greek query keeps its gap', () {
      expect(plain(lxx, 'εν αρχη').length, 29);
    });
  });
}
