/// Split View's second column, seeded across a language boundary.
///
/// THE DEFECT THIS PINS, reproduced 2026-09-05 by reading the code and
/// the assets together. `home_page.dart::_activateSplitView` seeded the
/// second column with
///
///     sp.verses.firstWhere(
///       (v) => v.book == primary.currentBook && v.chapter == …,
///       orElse: () => sp.verses.first)
///
/// — a RAW string comparison between two editions' book names. Measured
/// on the shipped assets: `cuvs-yhwh.json` keys its 31,102 verses on
/// 创世纪 / 约翰福音, `bsb.json` (31,086), `kjv.json` (31,102) and
/// `leb.json` (31,199) key theirs on Genesis / John. So the comparison
/// found nothing whenever the two columns were in different languages —
/// which is the case Split View exists for, since
/// `defaultSecondaryVersion` deliberately seeds a different edition and
/// the reader's own saved pick (`secondary_version`) may be in any
/// language at all. The `orElse` then answered with the first verse of
/// the corpus, so a reader on 约翰福音 3 opened a second column on
/// Genesis 1, and `scrollToVerseNumInChapter` scrolled it to Genesis
/// 1:16.
///
/// The workbench's own second column had already fixed this in
/// `_followPrimary` (v1.6.47); this surface kept the old shape. Both now
/// call the functions below, so there is one rule rather than two.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/utils/chapter_across_editions.dart';

void main() {
  Verse v(String book, int chapter, int verse) =>
      Verse(book: book, chapter: chapter, verse: verse, text: '$book $chapter:$verse');

  // An English-keyed corpus, in canonical order, the way `bsb.json`
  // and `kjv.json` actually store their books.
  final english = <Verse>[
    v('Genesis', 1, 1),
    v('Genesis', 1, 2),
    v('John', 3, 1),
    v('John', 3, 16),
    v('John', 4, 1),
  ];

  group('firstVerseOfChapterAcrossEditions', () {
    test('finds an English-keyed chapter asked for by its Chinese name', () {
      final hit = firstVerseOfChapterAcrossEditions(english, '约翰福音', 3);
      expect(hit, isNotNull);
      expect(hit!.book, 'John');
      expect(hit.chapter, 3);
      // The FIRST verse of the chapter, not merely a verse in it — the
      // caller lands the column here and then restores the reader's own
      // verse number on top of it.
      expect(hit.verse, 1);
    });

    test('the raw comparison it replaced finds nothing on the same data', () {
      // Not a re-implementation of the fix: the OLD rule, stated so the
      // defect stays reproducible after the code that had it is gone.
      final rawHit = english
          .where((x) => x.book == '约翰福音' && x.chapter == 3)
          .toList();
      expect(rawHit, isEmpty,
          reason: 'if this ever matches, the two editions have stopped '
              'disagreeing about book names and this whole file is moot');
    });

    test('traditional forms map as well as simplified', () {
      expect(firstVerseOfChapterAcrossEditions(english, '約翰福音', 3)?.book,
          'John');
    });

    test('matches an English name against a Chinese-keyed corpus too', () {
      final chinese = <Verse>[
        v('创世纪', 1, 1),
        v('约翰福音', 3, 1),
        v('约翰福音', 3, 16),
      ];
      expect(firstVerseOfChapterAcrossEditions(chinese, 'John', 3)?.verse, 1);
    });

    test('an edition that does not carry the chapter answers null', () {
      // LJK V2 is Matthew only; a partial canon is the real case. Null
      // is the answer that keeps the pane on the missing chapter so its
      // version-gap empty state can explain it — the `orElse` that
      // answered `verses.first` is what put the column on Genesis 1.
      expect(firstVerseOfChapterAcrossEditions(english, '约翰福音', 21), isNull);
      expect(firstVerseOfChapterAcrossEditions(english, 'Revelation', 1), isNull);
      expect(firstVerseOfChapterAcrossEditions(const <Verse>[], 'John', 3),
          isNull);
    });

    test('a null or empty book is not a match for anything', () {
      expect(firstVerseOfChapterAcrossEditions(english, null, 3), isNull);
      expect(firstVerseOfChapterAcrossEditions(english, '', 3), isNull);
      expect(firstVerseOfChapterAcrossEditions(english, 'John', null), isNull);
    });

    test('a book name in neither mapping is compared as itself', () {
      final odd = <Verse>[v('Enoch', 1, 1)];
      expect(firstVerseOfChapterAcrossEditions(odd, 'Enoch', 1)?.verse, 1);
      expect(firstVerseOfChapterAcrossEditions(odd, 'Jubilees', 1), isNull);
    });
  });

  group('seedChapterForNewColumn', () {
    test('lands on the passage when the edition has it', () {
      final seed = seedChapterForNewColumn(english, '约翰福音', 3);
      expect(seed!.book, 'John');
      expect(seed.chapter, 3);
      expect(seed.verse, 1);
    });

    test('falls back to the start of a canon that cannot carry it', () {
      // LJK V2 is Matthew only; a reader in Genesis asking for it is the
      // real case. A column being CONSTRUCTED has nowhere to be left —
      // its provider's currentBook is still null and FetchVerses does
      // not set it — so it opens at the start of what the edition has.
      final ntOnly = <Verse>[v('Matthew', 1, 1), v('Matthew', 1, 2)];
      expect(seedChapterForNewColumn(ntOnly, 'Genesis', 1)?.book, 'Matthew');
    });

    test('an edition that failed to load answers null, it does not throw',
        () {
      // `sp.verses.firstWhere(…, orElse: () => sp.verses.first)` threw a
      // StateError here.
      expect(seedChapterForNewColumn(const <Verse>[], 'John', 3), isNull);
    });

    test('the fallback does not stand in for a language mismatch', () {
      // The distinction the whole fix rests on: an edition that HAS the
      // chapter under another spelling must reach the chapter, not the
      // fallback. Before, both looked identical from the outside — a
      // second column on Genesis 1 — and only one of them was honest.
      expect(seedChapterForNewColumn(english, '约翰福音', 3)?.book, 'John');
      expect(seedChapterForNewColumn(english, '约翰福音', 3)?.chapter, 3);
    });
  });

  group('sameChapterAcrossEditions', () {
    test('two spellings of one chapter are the same chapter', () {
      expect(
          sameChapterAcrossEditions(
              bookA: 'John', chapterA: 3, bookB: '约翰福音', chapterB: 3),
          isTrue);
    });

    test('the same book at a different chapter is not', () {
      expect(
          sameChapterAcrossEditions(
              bookA: 'John', chapterA: 4, bookB: '约翰福音', chapterB: 3),
          isFalse);
    });

    test('different books at the same chapter are not', () {
      expect(
          sameChapterAcrossEditions(
              bookA: 'Genesis', chapterA: 3, bookB: '约翰福音', chapterB: 3),
          isFalse);
    });

    test('a null book only equals another null book', () {
      expect(
          sameChapterAcrossEditions(
              bookA: null, chapterA: 3, bookB: 'John', chapterB: 3),
          isFalse);
      expect(
          sameChapterAcrossEditions(
              bookA: null, chapterA: null, bookB: null, chapterB: null),
          isTrue);
    });
  });

  // ── What the two split surfaces are wired to ────────────────────
  //
  // A pure function nothing calls fixes nothing. The defect was never
  // in a util — it was inline in a page, in the one of the two split
  // surfaces that had not been visited since v1.6.47.
  //
  // WHAT THIS GROUP IS, said accurately. It reads two source files and
  // matches text. It CANNOT prove behaviour: the seeding lives in a
  // widget path that needs SharedPreferences, two parsed corpora and a
  // layout pass to reach. It used to be called a wiring test and to
  // claim it pinned the wiring; on 2026-09-06 the Split View defect was
  // put back with its operands reversed — `pb == v.book` instead of
  // `v.book == primary.currentBook` — and one mention of the shared
  // function left in a comment, and all three assertions went green
  // with the defect live. Measured, not argued: the mutation was run.
  //
  // A NEGATIVE MATCH ON EXACT OLD TEXT IS NOT ALLOWED HERE, and should
  // not be written anywhere else in this suite. It is a blacklist of
  // one item out of an infinite set, defeated by reordering operands,
  // renaming a local, or running the formatter. It reads like a
  // regression pin and is worth nothing. What replaces it:
  //
  //   1. comments are STRIPPED before matching, so prose naming a
  //      function cannot stand in for a call to it;
  //   2. every call is anchored in an ASSIGNMENT — the value the
  //      surface actually uses has to come from the shared function,
  //      not merely appear somewhere in the file;
  //   3. the one negative left is structural rather than textual:
  //      neither file may scan another edition's verse list by hand at
  //      all. `firstWhere(` occurs zero times in either file today, and
  //      every hand-rolled cross-edition search this project has
  //      written was one. It is still a blacklist — a `for` loop
  //      defeats it — and is kept only because it is cheap. The real
  //      pin for behaviour would be a test that drives
  //      `_activateSplitView`; it does not exist.
  group('the two split surfaces call the shared seeding functions', () {
    // Source with comments removed, so that a sentence naming a
    // function cannot be mistaken for a call to it.
    //
    // String literals are LEFT ALONE: one assertion below is about a
    // literal (`'secondary_version'`), and a stripper that ate string
    // bodies would make it pass for the wrong reason. So the scanner
    // tracks quotes, in order to know that the `//` inside a string
    // like an https URL does not start a comment.
    String stripComments(String src) {
      final out = StringBuffer();
      var i = 0;
      String? quote;
      while (i < src.length) {
        final c = src[i];
        if (quote != null) {
          if (c == r'\' && i + 1 < src.length) {
            out.write(c);
            out.write(src[i + 1]);
            i += 2;
            continue;
          }
          out.write(c);
          i++;
          if (c == quote) quote = null;
          continue;
        }
        if (c == "'" || c == '"') {
          quote = c;
          out.write(c);
          i++;
          continue;
        }
        if (src.startsWith('//', i)) {
          while (i < src.length && src[i] != '\n') {
            i++;
          }
          continue;
        }
        if (src.startsWith('/*', i)) {
          final end = src.indexOf('*/', i + 2);
          i = end == -1 ? src.length : end + 2;
          continue;
        }
        out.write(c);
        i++;
      }
      return out.toString();
    }

    String read(String path) => stripComments(File(path).readAsStringSync());

    // THE STRIPPER IS PART OF THE ASSERTION, so it is tested rather
    // than trusted. Every case here is one this group depends on: a
    // call inside a comment must vanish, a call in code must survive,
    // and a `//` inside a string must not eat the rest of the line.
    test('the comment stripper this group depends on actually strips', () {
      expect(stripComments('// call foo(1);\nbar(2);\n'), '\nbar(2);\n');
      expect(stripComments('/* foo(1); */ bar(2);'), ' bar(2);');
      expect(stripComments("var u = 'https://x/y'; foo(1);"),
          "var u = 'https://x/y'; foo(1);");
      expect(stripComments("var s = 'a // b'; foo(1);"),
          "var s = 'a // b'; foo(1);");
      expect(stripComments('/// doc seedChapterForNewColumn(\ncode();'),
          '\ncode();');
      // An escaped quote must not be read as the end of the string.
      expect(stripComments("var s = 'it\\'s // fine'; foo(1);"),
          "var s = 'it\\'s // fine'; foo(1);");

      // AND `read` MUST ACTUALLY USE IT. A stripper that exists beside
      // an unstripped `read` is the same defect one level up, and it
      // was reachable: unwiring `read` from `stripComments` was the one
      // mutation of the twelve run against this work that no test
      // caught. Both files are heavily commented, so a `//` surviving
      // into `read`'s answer means nothing was stripped.
      // A line that BEGINS with `//` is unambiguously a comment; a
      // bare `//` would also match inside a URL string literal, which
      // `read` deliberately leaves alone.
      final commentLine = RegExp(r'^\s*//', multiLine: true);
      for (final path in const [
        'lib/pages/home_page.dart',
        'lib/pages/workbench_page.dart',
      ]) {
        final raw = File(path).readAsStringSync();
        expect(commentLine.hasMatch(raw), isTrue, reason: path);
        expect(commentLine.hasMatch(read(path)), isFalse, reason: path);
        expect(read(path).length, lessThan(raw.length), reason: path);
      }
    });

    test('Split View assigns its seed from seedChapterForNewColumn', () {
      // Two entry points on purpose: a column being constructed needs a
      // landing place when the edition cannot carry the passage, and a
      // column already on a chapter must be left there instead.
      //
      // Anchored to `= seedChapterForNewColumn(` rather than to the
      // bare name, so that the value the column is actually opened on
      // has to be the shared function's answer.
      expect(
        RegExp(r'=\s*seedChapterForNewColumn\s*\(')
            .hasMatch(read('lib/pages/home_page.dart')),
        isTrue,
        reason: 'Split View constructs its column, so it takes the '
            'variant with the partial-canon fallback — and it must take '
            'the RESULT of it',
      );
    });

    test('the workbench column follows through the shared search', () {
      expect(
        RegExp(r'=\s*firstVerseOfChapterAcrossEditions\s*\(')
            .hasMatch(read('lib/pages/workbench_page.dart')),
        isTrue,
        reason: 'the workbench column already has a chapter and must '
            'take the variant that answers null rather than moving it',
      );
    });

    test("neither surface scans another edition's verses by hand", () {
      // Structural, not textual: the defect was not one spelling of one
      // comparison, it was a hand-rolled linear search across a
      // language boundary. Both files do zero of those now.
      for (final path in const [
        'lib/pages/home_page.dart',
        'lib/pages/workbench_page.dart',
      ]) {
        expect(read(path).contains('firstWhere('), isFalse,
            reason: '$path: a cross-edition search belongs in '
                'utils/chapter_across_editions.dart, where it round-trips '
                'through bookNameToEnglish, not inline over verses that '
                'name their books in another language');
      }
    });

    test('Split View asks resolveSecondaryVersion which edition to open', () {
      final src = read('lib/pages/home_page.dart');
      expect(
        RegExp(r'=\s*resolveSecondaryVersion\s*\(').hasMatch(src),
        isTrue,
        reason: 'the workbench column and the boot warm-up both do; a '
            'third answer here warms one Bible and opens another',
      );
      // The one textual negative that is not a blacklist of an old
      // revision: the constant exists so that this literal appears
      // nowhere, and there is no other way to spell it.
      expect(src.contains("'secondary_version'"), isFalse,
          reason: 'use kSecondaryVersionKey, so the three readers of this '
              'preference cannot drift apart on its spelling');
    });
  });
}
