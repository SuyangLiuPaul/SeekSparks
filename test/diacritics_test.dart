/// #321 — the fold that lets a reader find the word the app showed her.
///
/// Reported 2026-08-16 by a reader in Hong Kong: she searched the Greek
/// text for `ὁ θεός`, spelled correctly, and got nothing. The app's only
/// Greek edition is set WITHOUT accents; every Greek word the app puts on
/// her screen — Word Study's parsed forms, the Strong's lemmas — carries
/// them. So the app was displaying 19,555 distinct accented Greek forms
/// of which, typed exactly as displayed, zero could be found.
///
/// Three claims, tested in three registers:
///   * the fold itself, on hand-written strings;
///   * the real 30,800-verse Greek edition, where the numbers are a
///     matter of record and would move silently if the fold drifted;
///   * the invariants that keep the fold OUT of everything the reader
///     sees, which is the price of doing it at all.
///
/// Some pairs in here look identical on screen and are not the same
/// string at all: `ά` is one codepoint, `ά` is two. That
/// difference is the entire subject, so read this file's Greek and
/// Hebrew by its comments rather than by its glyphs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/utils/diacritics.dart';
import 'package:seeksparks/utils/search_highlight.dart';

/// `ὁ θεός` — the query as she typed it.
const kHoTheos = 'ὁ θεός';

/// `ο θεος` — the same words as the edition sets them.
const kHoTheosBare = 'ο θεος';

/// `בְּרֵאשִׁית בָּרָא` pointed, and bare.
const kBereshit = 'בְּרֵאשִׁית בָּרָא';
const kBereshitBare = 'בראשית ברא';

void main() {
  group('the fold', () {
    test('Greek precomposed accents come off', () {
      expect(foldDiacritics(kHoTheos), kHoTheosBare);
      expect(foldDiacritics('Ἐν ἀρχῇ ἐποίησεν'), 'Εν αρχη εποιησεν');
      expect(foldDiacritics('Ἰησοῦς Χριστός'), 'Ιησους Χριστος');
      expect(foldDiacritics('ἀγάπη'), 'αγαπη');
      // Iota subscript is a mark on the letter, not a letter: U+1F85
      // GREEK SMALL LETTER ALPHA WITH DASIA AND OXIA AND YPOGEGRAMMENI.
      expect(foldDiacritics('ᾅ'), 'α');
    });

    test('Hebrew points come off and the consonants survive', () {
      expect(foldDiacritics(kBereshit), kBereshitBare);
      // Shin and sin differ only by which dot they carry, so both fold
      // to a bare shin — U+05C1 and U+05C2 are marks.
      expect(foldDiacritics('שׁ'), 'ש');
      expect(foldDiacritics('שׂ'), 'ש');
    });

    test('Hebrew punctuation is not a point and stays', () {
      // U+05BE MAQAF, U+05C0 PASEQ, U+05C3 SOF PASUQ and U+05C6 NUN
      // HAFUKHA sit in the same block as the points and are not marks.
      // The old lexicon normaliser dropped U+05C3 and U+05C6 as if they
      // were; neither occurs in the shipped lexicon, so nothing moved.
      for (final p in ['־', '׀', '׃', '׆']) {
        expect(foldDiacritics('א$pב'), 'א$pב');
      }
    });

    test('Latin accents come off, case is left alone', () {
      expect(foldDiacritics('agápē'), 'agape');
      expect(foldDiacritics('Agápē'), 'Agape');
      expect(foldDiacritics('ḇāraʼ'), 'baraʼ');
    });

    test('already-decomposed text folds to the same answer', () {
      // Text arriving as base + combining mark rather than precomposed
      // must not survive the fold looking different.
      expect(foldDiacritics('é'), 'e');
      expect(foldDiacritics('ά'), 'α');
      expect(foldDiacritics('ά'), foldDiacritics('ά'));
    });

    test('it is idempotent', () {
      for (final s in [
        kHoTheos,
        kBereshit,
        'agápē',
        '起初神创造天地',
        'In the beginning',
        '',
      ]) {
        expect(foldDiacritics(foldDiacritics(s)), foldDiacritics(s));
      }
    });

    test('nothing to do means no allocation', () {
      const plain = 'In the beginning God created the heaven and the earth.';
      expect(identical(foldDiacritics(plain), plain), isTrue);
      const cjk = '起初神创造天地。';
      expect(identical(foldDiacritics(cjk), cjk), isTrue);
      expect(identical(foldDiacritics(kHoTheosBare), kHoTheosBare), isTrue);
    });

    test('it leaves CJK, digits and punctuation alone', () {
      const s = '神愛世人，甚至將祂的獨生子賜給他們 (John 3:16) — 100%!';
      expect(foldDiacritics(s), s);
    });

    test('modifier letters are NOT diacritics and deliberately stay', () {
      // Strong's Hebrew transliterations carry ʼ (U+02BC, 1,720 of
      // them), ʻ (U+02BB, 1,544) and ᵉ (U+1D49, 1,417). Those are
      // letters in their own right — Lm, not Mn — and NFD does not
      // touch them, so neither does this. A reader typing `abad` still
      // reaches `ʼâbad`, because `ʼabad` CONTAINS `abad`; it ranks as a
      // substring hit rather than an exact one. Recorded here so the
      // next person to look knows this was measured, not missed.
      expect(foldDiacritics('ʼâbad'), 'ʼabad');
      expect(foldDiacritics('bᵉrêʼshîyth'),
          'bᵉreʼshiyth');
    });
  });

  group('the aligned fold', () {
    test('reports where every surviving character came from', () {
      const bara = 'בָּרָא';
      final f = foldDiacriticsAligned(bara);
      expect(f.folded, 'ברא');
      expect(f.sourceIndex.length, f.folded.length + 1);
      expect(f.sourceIndex.last, bara.length);
      // Strictly increasing, so a folded range maps to a real range.
      for (var i = 1; i < f.sourceIndex.length; i++) {
        expect(f.sourceIndex[i], greaterThan(f.sourceIndex[i - 1]));
      }
    });

    test('agrees with the plain fold, everywhere', () {
      for (final s in [
        kHoTheos,
        kBereshit,
        'agápē and ἀγάπη and 愛',
        '',
        'plain ascii',
      ]) {
        expect(foldDiacriticsAligned(s).folded, foldDiacritics(s));
      }
    });

    test('Greek is length-preserving, Hebrew is not', () {
      expect(foldDiacriticsAligned(kHoTheos).folded.length, kHoTheos.length);
      expect(foldDiacriticsAligned(kBereshit).folded.length,
          lessThan(kBereshit.length));
    });
  });

  group('the highlight lands on the accented word', () {
    const accentedVerse = 'Ἐν ἀρχῇ ἐποίησεν ὁ θεὸς τὸν οὐρανὸν';

    test('an unaccented query marks the accented text', () {
      // The other half of the bug: matching without highlighting gives
      // a hit list with nothing marked in it.
      final spans = splitOnTerms(accentedVerse, ['ο θεος']);
      expect(spans.where((s) => s.isHit).map((s) => s.text), ['ὁ θεὸς']);
    });

    test('an accented query marks the accented text', () {
      final h = highlightsForQuery(kHoTheos);
      final spans = splitOnTerms(accentedVerse, h.textTerms);
      expect(spans.where((s) => s.isHit).map((s) => s.text),
          containsAll(<String>['ὁ', 'θεὸς']));
    });

    test('a Hebrew hit takes the points of its letters with it', () {
      // Two hits, not one: bereshit opens with the same three letters
      // that bara is spelled with, so the bare query matches inside the
      // first word as well as on the second. That is what makes this
      // worth testing — the fold is length-REDUCING for Hebrew, so the
      // two hits sit at offsets that do not exist in the original, and
      // each has to come back out of it wearing its own points and
      // nobody else's.
      final spans = splitOnTerms(kBereshit, ['\u05d1\u05e8\u05d0']);
      expect(spans.where((s) => s.isHit).map((s) => s.text), [
        '\u05d1\u05b0\u05bc\u05e8\u05b5\u05d0',
        '\u05d1\u05bc\u05b8\u05e8\u05b8\u05d0',
      ]);
    });

    test('the spans still reassemble into the original, accents and all',
        () {
      for (final text in [accentedVerse, kBereshit, 'In the beginning God',
        'agápē is the word']) {
        for (final terms in [
          <String>['ο θεος'],
          <String>['ברא'],
          <String>['god'],
          <String>['agape'],
          <String>['e'],
        ]) {
          expect(splitOnTerms(text, terms).map((s) => s.text).join(), text,
              reason: '$text / $terms');
        }
      }
    });
  });

  group('the real Greek edition', () {
    late List<String> keys;

    setUpAll(() {
      final list =
          jsonDecode(File('assets/lxxwh.json').readAsStringSync()) as List;
      keys = [for (final v in list) searchCorpusKey(v['text'] as String)];
    });

    /// What `SearchService.scanText` does to the query, against the key
    /// `MainProvider.searchKeys` builds.
    int hits(String query) {
      final q = foldDiacritics(query).replaceAll(' ', '').toLowerCase();
      return keys.where((k) => k.contains(q)).length;
    }

    test('the edition is the size it was measured at', () {
      expect(keys.length, 30800);
    });

    test("the reader's own query finds the verses it always should have",
        () {
      // Every one of these returned 0 before #321, in an edition that
      // contains all of them. None was reachable by the spelling the
      // app itself prints.
      expect(hits(kHoTheos), 1486);
      expect(hits('ἀγάπη'), 248);
      expect(hits('Ἰησοῦς'), 602);
      expect(hits('ἐν ἀρχῇ'), 29);
    });

    test('accented and unaccented queries return the identical answer', () {
      for (final (accented, bare) in const [
        ('ὁ θεός', 'ο θεος'),
        ('ἀγάπη', 'αγαπη'),
        ('Ἰησοῦς', 'ιησους'),
        ('ἐν ἀρχῇ', 'εν αρχη'),
        ('πνεῦμα', 'πνευμα'),
      ]) {
        expect(hits(accented), hits(bare), reason: '$accented vs $bare');
      }
    });

    test('the fold did not invent hits for a word that is not there', () {
      expect(hits('ζζζζ'), 0);
      expect(hits('ξξξξ'), 0);
    });
  });

  group('the English and Chinese editions cannot have moved', () {
    // The fold runs over every corpus, not just the Greek one, so the
    // question to answer before shipping is whether it changes an
    // answer anyone already relies on. It does not alter a single verse
    // of these three.
    for (final asset in const ['bsb.json', 'kjv.json', 'cuvs-yhwh.json']) {
      test('$asset is untouched by the fold', () {
        final list =
            jsonDecode(File('assets/$asset').readAsStringSync()) as List;
        var changed = 0;
        for (final v in list) {
          final t = v['text'] as String;
          if (!identical(foldDiacritics(t), t)) changed++;
        }
        expect(changed, 0);
      });
    }
  });

  group('the lexicon, which had its own broken normaliser', () {
    late Map<String, dynamic> greek;

    setUpAll(() {
      greek = jsonDecode(File('assets/strongs/greek.json').readAsStringSync())
          as Map<String, dynamic>;
    });

    test('G26 is reachable by every spelling its own comment claimed', () {
      final e = greek['G26'] as Map<String, dynamic>;
      expect(e['lemma'], 'ἀγάπη');
      expect(e['translit'], 'agápē');
      String norm(String s) => foldDiacritics(s).toLowerCase().trim();
      // Each of these was NO MATCH before #321: the old normaliser
      // dropped combining marks, and not one character in this lexicon
      // is a combining mark — they are all precomposed.
      expect(norm(e['lemma'] as String), norm('αγαπη'));
      expect(norm(e['lemma'] as String), norm('ἀγάπη'));
      expect(norm(e['translit'] as String), norm('agape'));
      expect(norm(e['translit'] as String), norm('AGAPE'));
    });

    test('every accented Greek lemma folds to bare Greek letters', () {
      var accented = 0;
      for (final e in greek.values) {
        final lemma = (e as Map<String, dynamic>)['lemma'] as String? ?? '';
        if (lemma.isEmpty) continue;
        final folded = foldDiacritics(lemma);
        if (folded != lemma) accented++;
        for (final c in folded.codeUnits) {
          if (c >= 0x1F00 && c <= 0x1FFF) {
            fail('$lemma folded to $folded, still polytonic');
          }
        }
      }
      expect(accented, 5517);
    });
  });
}
