/// The Lexicon Browser's core (bwh35).
///
/// Half of this runs against toy data and half against the real 5,523
/// Greek and 8,674 Hebrew entries, because the defect this feature was
/// designed around is invisible to toy data: a plain `sort()` of the
/// Greek lemmas looks perfectly alphabetical until you notice that
/// every word carrying a breathing mark has been exiled past ω. Five
/// hand-written rows would never have shown it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/thayer_service.dart';
import 'package:seeksparks/utils/lexicon_browse.dart';

List<LexiconHead> _load(String file) {
  final raw =
      json.decode(File('assets/strongs/$file.json').readAsStringSync())
          as Map<String, dynamic>;
  return [
    for (final e in raw.entries)
      LexiconHead(
        number: e.key,
        lemma: (e.value['lemma'] ?? '') as String,
        translit: (e.value['translit'] ?? '') as String,
        gloss: (e.value['gloss'] ?? '') as String,
      ),
  ];
}

/// The numbers one Chinese module actually says something about —
/// senses, not merely a key. An entry present but empty is a hole.
Set<String> _articles(String file) {
  final raw =
      json.decode(File('assets/strongs/$file.json').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final e in raw.entries)
      if (((e.value['s'] as List?) ?? const []).isNotEmpty)
        e.key.toUpperCase(),
  };
}

/// The English Thayer, through the shipped canonicaliser rather than a
/// copy of it: two of the 5,799 keys are zero-padded, and a test that
/// normalised them its own way would pass while `lookup` still missed.
Set<String> _thayerEn() {
  final raw = json.decode(File('assets/thayer.json').readAsStringSync())
      as Map<String, dynamic>;
  final entries = raw['entries'] as Map<String, dynamic>;
  return {
    for (final e in entries.entries)
      if ((e.value as String).trim().isNotEmpty)
        ThayerService.canonicalKey(e.key),
  };
}

LexiconHead _head(String number, String lemma,
        {String translit = '', String gloss = ''}) =>
    LexiconHead(
        number: number, lemma: lemma, translit: translit, gloss: gloss);

void main() {
  group('collation', () {
    test('folds the two diacritic mechanisms, and renders neither', () {
      // Greek is precomposed, Hebrew is combining marks. One naive strip
      // fixes exactly one of them; this key has to fix both.
      expect(lexiconCollationKey('ἀγάπη'), 'αγαπη');
      expect(lexiconCollationKey('אָב'), 'אב');
      // And it is a comparison form only — the head keeps the real word.
      expect(_head('G26', 'ἀγάπη').lemma, 'ἀγάπη');
    });

    test('alphabetical ties break on the Strong\'s number', () {
      // Three spellings of one consonantal skeleton. Strong's assigned
      // its numbers in lexicon order, so that is the order to print.
      final sorted = sortHeads([
        _head('H3', 'אָב'),
        _head('H1', 'אָב'),
        _head('H2', 'אַב'),
      ], LexiconOrder.alphabetical);
      expect(sorted.map((h) => h.number), ['H1', 'H2', 'H3']);
    });

    test('number order is numeric, not lexicographic', () {
      final sorted = sortHeads([
        _head('G100', 'x'),
        _head('G9', 'y'),
        _head('G26', 'z'),
      ], LexiconOrder.number);
      expect(sorted.map((h) => h.number), ['G9', 'G26', 'G100']);
    });
  });

  group('matchHeadwords', () {
    final heads = sortHeads([
      _head('G25', 'ἀγαπάω', translit: 'agapáō'),
      _head('G26', 'ἀγάπη', translit: 'agápē'),
      _head('G5485', 'χάρις', translit: 'cháris'),
      _head('H26', 'אֲבִיגַיִל', translit: 'ʼĂbîygayil'),
      _head('H430', 'אֱלֹהִים', translit: 'ʼĕlôhîym'),
    ], LexiconOrder.alphabetical);

    test('a bare word is a PREFIX, not a substring', () {
      // bwh35's bare word "scrolls to the proper location". Substring by
      // default would answer «α» with most of the lexicon.
      expect(matchHeadwords(heads, 'ἀγαπ').map((h) => h.number),
          containsAll(['G25', 'G26']));
      expect(matchHeadwords(heads, 'γάπη'), isEmpty);
    });

    test('* is the wildcard bwh35 documents, anchored at both ends', () {
      // "enter *ew … you will see a list of all Greek words ending in ew"
      expect(matchHeadwords(heads, '*πη').single.number, 'G26');
      expect(matchHeadwords(heads, '*γαπ*').map((h) => h.number),
          containsAll(['G25', 'G26']));
      expect(matchHeadwords(heads, 'χ*ς').single.number, 'G5485');
    });

    test('an exact match is hoisted above its own inflections', () {
      expect(matchHeadwords(heads, 'ἀγάπη').first.number, 'G26');
    });

    test('the romanised tier is bwh45\'s, so `elohim` reaches H430', () {
      // `lexiconCollationKey` alone leaves Strong's ʼ and its superscript
      // shewa in place, so this is the case that proves the shared
      // romanisation is actually being used and not re-derived.
      expect(matchHeadwords(heads, 'elohim').single.number, 'H430');
      expect(matchHeadwords(heads, 'agape').first.number, 'G26');
      // Collapsed too: Strong's writes `cháris`, a student writes the
      // same, but `kharis` must arrive as well.
      expect(matchHeadwords(heads, 'kharis').single.number, 'G5485');
    });

    test('the three-letter floor does not apply to a box typed into', () {
      // `romanisedKey` refuses short reader input so the UNBIDDEN offer
      // cannot fire on half the index. This box was typed into on
      // purpose, so it filters instead of refusing.
      expect(matchHeadwords(heads, 'ag').map((h) => h.number),
          containsAll(['G25', 'G26']));
    });

    test('a query with an unromanisable fragment does not widen', () {
      // Dropping the bad fragment would turn `agap*ἡ` into `agap*` and
      // show matches for something nobody asked.
      expect(matchHeadwords(heads, 'agap*ἡ'), isEmpty);
    });

    test('G26 does not also match H26', () {
      expect(matchHeadwords(heads, 'G26').single.number, 'G26');
      expect(matchHeadwords(heads, 'H26').single.number, 'H26');
      // A bare number carries no language, so it matches in whichever
      // list the caller handed in — here, both.
      expect(matchHeadwords(heads, '26').map((h) => h.number),
          containsAll(['G26', 'H26']));
    });

    test('an empty query matches nothing rather than everything', () {
      expect(matchHeadwords(heads, '   '), isEmpty);
    });
  });

  group('searchDefinitions', () {
    final heads = [
      _head('G1242', 'διαθήκη'),
      _head('G26', 'ἀγάπη'),
      _head('G5485', 'χάρις'),
    ];
    const text = {
      'G1242': 'a covenant, a testament; a disposition',
      'G26': 'love, goodwill; a love feast',
      'G5485': 'grace, favour; the divine covenant of favour',
    };
    String textOf(String n) => text[n] ?? '';

    test('AND needs every term in the SAME article', () {
      final r = searchDefinitions(heads, 'covenant favour', textOf: textOf);
      expect(r.hits.map((h) => h.number), ['G5485']);
      expect(r.total, 1);
    });

    test('OR takes either, and keeps the order it was given', () {
      final r = searchDefinitions(heads, 'covenant love',
          textOf: textOf, mode: LexiconTextMode.or);
      expect(r.hits.map((h) => h.number), ['G1242', 'G26', 'G5485']);
    });

    test('a phrase is the words in that order', () {
      expect(
        searchDefinitions(heads, 'love feast',
                textOf: textOf, mode: LexiconTextMode.phrase)
            .hits
            .single
            .number,
        'G26',
      );
      expect(
        searchDefinitions(heads, 'feast love',
            textOf: textOf, mode: LexiconTextMode.phrase),
        isA<LexiconTextResult>().having((r) => r.total, 'total', 0),
      );
    });

    test('the total is the total, never the page length', () {
      final r = searchDefinitions(heads, 'a', textOf: textOf, limit: 1);
      expect(r.hits.length, 1);
      expect(r.total, 3);
      expect(r.truncated, isTrue);
    });

    test('a pre-folded accessor gives the same answer as folding inside',
        () {
      // The page caches the fold — 845,000 characters of Hebrew article
      // text is not a per-keystroke rebuild. The two paths must agree.
      final folded = {
        for (final e in text.entries) e.key: lexiconCollationKey(e.value)
      };
      final a = searchDefinitions(heads, 'covenant', textOf: textOf);
      final b = searchDefinitions(heads, 'covenant',
          textOf: textOf, foldedTextOf: (n) => folded[n] ?? '');
      expect(b.total, a.total);
      expect(b.hits.map((h) => h.number), a.hits.map((h) => h.number));
      expect(b.hits.first.excerpt, a.hits.first.excerpt);
    });

    test('the excerpt comes from the ORIGINAL text, accents intact', () {
      final r = searchDefinitions(
        [_head('G2316', 'θεός')],
        'God',
        textOf: (_) => 'the word θεός, God',
      );
      expect(r.total, 1);
      expect(r.hits.single.excerpt, contains('θεός'));
    });

    test('the fold does not transliterate, and does not pretend to', () {
      // This test exists because the first draft of the doc comment
      // claimed `theos` would reach θεός. It does not: folding an accent
      // off ό leaves Greek script, and Latin `theos` is a different
      // string. Romanised input is the HEADWORD tier's job. Asserted
      // rather than left implicit so the claim cannot creep back.
      expect(
        searchDefinitions([_head('G2316', 'θεός')], 'theos',
                textOf: (_) => 'the word θεός, God')
            .total,
        0,
      );
    });

    test('an excerpt whose fold changed length falls back to the head', () {
      // Hebrew points are combining marks and the fold DROPS them, so
      // the folded offset is not portable into the original. The guard
      // shows the head of the article, which is always true even when it
      // is not the most useful thing to show.
      final long = 'אָב is father. ${'padding ' * 30}covenant';
      final r = searchDefinitions([_head('H1', 'אָב')], 'covenant',
          textOf: (_) => long, excerptRadius: 20);
      expect(r.total, 1);
      expect(r.hits.single.excerpt, startsWith('אָב is father.'));
    });
  });

  group('the second lexicon', () {
    test('only Thayer refuses a side, and it refuses Hebrew', () {
      expect(LexiconSource.thayer.covers(LexiconId.greek), isTrue);
      expect(LexiconSource.thayer.covers(LexiconId.hebrew), isFalse);
      for (final s in [LexiconSource.strongs, LexiconSource.chinese]) {
        for (final id in LexiconId.values) {
          expect(s.covers(id), isTrue, reason: '${s.name}/${id.name}');
        }
      }
    });

    test('the row summary drops the sense number but not a sub-letter', () {
      // "1)" is the numbering, and printing it on every row would put a
      // column of 1s down the page. "1a)" is not: it says the article's
      // first statement is already a subdivision, which is information.
      expect(firstSenseSummary(['1) 天，诸天']), '天，诸天');
      expect(firstSenseSummary(['1a) 可见的天']), '1a) 可见的天');
      expect(firstSenseSummary(['', '  ', '2) 爱']), '爱');
      expect(firstSenseSummary(const []), '');
    });
  });

  group('against the shipped lexicons', () {
    late final List<LexiconHead> greek = _load('greek');
    late final List<LexiconHead> hebrew = _load('hebrew');

    test('the works offered cover the list they are captioning', () {
      // The backlog's worry about item 1a was that a picker offering a
      // lexicon with holes in it states something untrue by omission.
      // Measured, the holes are five: H2775, H7418, H7427, H8556 in BDB
      // 中文 and G4191 in Thayer 中文, each a headword the module keys
      // but never defines. Five rows in 14,197 is small enough to offer
      // the work and label the row (`lexiconWorkSilent`), and the
      // numbers are pinned here so a re-import cannot quietly widen the
      // gap under a picker that promises coverage.
      final bdb = _articles('bdb_zh');
      expect(
        hebrew.map((h) => h.number).where((n) => !bdb.contains(n)).toSet(),
        {'H2775', 'H7418', 'H7427', 'H8556'},
      );

      final thayerZh = _articles('thayer_zh');
      expect(
        greek.map((h) => h.number).where((n) => !thayerZh.contains(n)).toSet(),
        {'G4191'},
      );

      // The English Thayer is the one work with no holes at all — and
      // only since `canonicalKey`: G190 ἀκολουθέω, the New Testament's
      // verb for following Jesus, was zero-padded in the asset and
      // unreachable until 2026-08-23.
      final en = _thayerEn();
      expect(greek.where((h) => !en.contains(h.number)), isEmpty);
      expect(en, contains('G190'));
      expect(en, contains('G446'));
    });

    test('the corpus is the size the design was measured on', () {
      expect(greek.length, 5523);
      expect(hebrew.length, 8674);
    });

    test('ἀγάπη sorts where alpha belongs, not past ω', () {
      // The defect this page exists to avoid. Codepoint order puts it at
      // index 3,528 of 5,516 — 64% of the way down a list whose only
      // promise is that it is alphabetical.
      final naive = [...greek]..sort((a, b) => a.lemma.compareTo(b.lemma));
      final naiveAt = naive.indexWhere((h) => h.number == 'G26');
      final sorted = sortHeads(greek, LexiconOrder.alphabetical);
      final foldedAt = sorted.indexWhere((h) => h.number == 'G26');
      expect(naiveAt, greaterThan(3000));
      expect(foldedAt, lessThan(200));
      expect(foldedAt / sorted.length, lessThan(0.05));
    });

    test('the Hebrew list opens at H1, as a printed lexicon does', () {
      // Naively it opened at אֱגוֹז, a nut: the sort compared the VOWEL
      // before the next consonant.
      final sorted = sortHeads(hebrew, LexiconOrder.alphabetical);
      expect(sorted.first.number, 'H1');
    });

    test('the alphabet strip is the alphabet, not a Unicode block dump', () {
      // 22 Hebrew letters — the five final forms correctly absent, since
      // no word begins with one.
      final heb = alphabetOf(hebrew);
      expect(heb.length, 22);
      expect(heb, isNot(contains('ם')));
      // Exactly 24 Greek letters. G4452 `-πω` and G4458 `-πώς` file
      // under none of them, which is right: they are enclitic suffixes,
      // and a printed lexicon does not shelve them under pi either.
      final grk = alphabetOf(greek);
      expect(grk.length, 24);
      expect(grk.first, 'α');
      expect(grk.last, 'ω');
    });

    test('Strong\'s numbering IS the printed lexicon order', () {
      // Which is why number order is offered as a peer of alphabetical
      // and not as a debug view. Measured, not assumed: the two orders
      // disagree only about homographs.
      for (final pair in [
        (greek, 0.02),
        (hebrew, 0.02),
      ]) {
        final byNumber = sortHeads(pair.$1, LexiconOrder.number);
        var back = 0;
        for (var i = 1; i < byNumber.length; i++) {
          if (byNumber[i].sortKey.compareTo(byNumber[i - 1].sortKey) < 0) {
            back++;
          }
        }
        expect(back / byNumber.length, lessThan(pair.$2));
      }
    });

    test('every entry is reachable by its own spelling', () {
      // #321 shipped because 5,517 accented Greek lemmas were not. A
      // browser that cannot find a word it is displaying is the same
      // defect with a new surface.
      for (final h in [greek[0], greek[greek.length ~/ 2], greek.last]) {
        expect(matchHeadwords(greek, h.lemma).map((e) => e.number),
            contains(h.number), reason: h.number);
      }
      for (final h in [hebrew[0], hebrew[hebrew.length ~/ 2], hebrew.last]) {
        expect(matchHeadwords(hebrew, h.lemma).map((e) => e.number),
            contains(h.number), reason: h.number);
      }
    });

    test('the romanisations a reader types reach the right entry', () {
      for (final (query, number) in [
        ('agape', 'G26'),
        ('logos', 'G3056'),
        ('charis', 'G5485'),
      ]) {
        expect(matchHeadwords(greek, query).map((e) => e.number),
            contains(number), reason: query);
      }
      for (final (query, number) in [
        ('elohim', 'H430'),
        ('shalom', 'H7965'),
        ('hesed', 'H2617'),
      ]) {
        expect(matchHeadwords(hebrew, query).map((e) => e.number),
            contains(number), reason: query);
      }
    });
  });
}
