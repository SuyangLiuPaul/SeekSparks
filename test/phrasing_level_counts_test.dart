/// #312 item 7: the four level chips offered Biblearc's vocabulary with
/// no hint of what it does.
///
/// The fix is not a tooltip. The level control is ours — BibleWorks'
/// diagrammer (`bwh25`) is a symbol canvas with no granularity setting —
/// so a reader has no model of it from any other tool, and the only way
/// to find out what `+ Verbals` does was to tap it, which replaces the
/// page they were reading. [phrasingLevelLineCounts] measures each level
/// through the widgets' own path so the chip can say it in advance.
///
/// The tests that earn their keep are the corpus ones at the bottom.
/// They pin the measurement that motivated the widget rather than
/// leaving it in a commit message, and they PROVE the claim the note
/// prints — that two equal counts mean two identical pages — instead of
/// asserting it in prose.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/pages/phrasing_page.dart'
    show phrasingLevelChips, phrasingLevelName, phrasingLevelNote;
import 'package:seeksparks/utils/phrasing.dart';

PhrasingWord w(String text,
        {String morph = '', String strongs = '', int verse = 1}) =>
    PhrasingWord(
      text: text,
      strongs: strongs,
      verse: verse,
      morph: morph.isEmpty ? null : morph,
    );

Phrasing at(List<PhrasingWord> words, {int? start, int? end}) {
  final verses = ({for (final x in words) x.verse}.toList()..sort());
  return Phrasing(
    version: 'v',
    book: 'john',
    chapter: 1,
    startVerse: start ?? verses.first,
    endVerse: end ?? verses.last,
  );
}

/// The whole tagged Greek/Hebrew corpus, chapter by chapter.
Map<int, List<PhrasingWord>> _chapters(File f) {
  final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final out = <int, List<PhrasingWord>>{};
  for (final entry in raw.entries) {
    final parts = entry.key.split(':');
    if (parts.length != 2) continue;
    final ch = int.tryParse(parts[0]);
    final v = int.tryParse(parts[1]);
    if (ch == null || v == null) continue;
    for (final word in entry.value as List) {
      final m = word as Map<String, dynamic>;
      (out[ch] ??= []).add(PhrasingWord(
        text: '${m['w'] ?? ''}',
        strongs: '${m['s'] ?? ''}',
        verse: v,
        morph: m['m'] as String?,
      ));
    }
  }
  return out;
}

void main() {
  // A Greek fixture with one of each joint, spread over three verses.
  // Morph codes are exactly ten characters — an eight-character one
  // falls through to the Semitic branch and parses as garbage rather
  // than failing, which cost seven red tests once already.
  List<PhrasingWord> greek() => [
        w('Ἐν', morph: 'P---------', strongs: 'G1722', verse: 1),
        w('ἀρχῇ', morph: 'N-----DSF-', verse: 1),
        w('ἦν', morph: 'V--IAI3S--', verse: 1),
        w('καὶ', morph: 'C---------', strongs: 'G2532', verse: 2),
        w('ὁ', morph: 'RA----NSM-', verse: 2),
        w('λέγων', morph: 'V--PAPNSM-', verse: 2),
        w('εἰς', morph: 'P---------', strongs: 'G1519', verse: 3),
        w('τὸν', morph: 'RA----ASM-', verse: 3),
      ];

  group('phrasingLevelLineCounts', () {
    test('rises with the level, because the levels are monotone supersets',
        () {
      final words = greek();
      final counts = phrasingLevelLineCounts(at(words), words);
      expect(counts.keys, PhrasingLevel.values,
          reason: 'this fixture carries morphology, so all four apply');
      var previous = 0;
      for (final level in PhrasingLevel.values) {
        expect(counts[level]!, greaterThanOrEqualTo(previous),
            reason: 'a finer level can only ADD breaks, never merge them');
        previous = counts[level]!;
      }
      expect(counts[PhrasingLevel.phrases]!,
          greaterThan(counts[PhrasingLevel.verses]!));
    });

    test('offers no count for a level the text cannot support', () {
      // No morphology and no Strong's: verse breaks are all there is.
      final words = [w('a'), w('b', verse: 2), w('c', verse: 3)];
      final counts = phrasingLevelLineCounts(at(words), words);
      expect(counts.keys, [PhrasingLevel.verses]);
      expect(counts[PhrasingLevel.verses], 3);
    });

    test('counts the WINDOW, not the chapter', () {
      // #308's rule: a count must never be ambiguous about what it
      // counted. The word list a Phrasing resolves against is always the
      // whole chapter — only the window decides what is on screen — so a
      // count taken over the chapter would be a different quantity
      // wearing the same label.
      final words = greek();
      final whole = phrasingLevelLineCounts(at(words), words);
      final narrow =
          phrasingLevelLineCounts(at(words, start: 1, end: 1), words);
      expect(narrow[PhrasingLevel.verses], 1);
      expect(whole[PhrasingLevel.verses], 3);
      expect(narrow[PhrasingLevel.phrases]!,
          lessThan(whole[PhrasingLevel.phrases]!));
    });

    test('includes the reader\'s own breaks, because that is the page they get',
        () {
      final words = greek();
      final plain = at(words);
      final before = phrasingLevelLineCounts(plain, words);
      final after = phrasingLevelLineCounts(plain.copyWith(added: {2}), words);
      expect(after[PhrasingLevel.verses]!, before[PhrasingLevel.verses]! + 1);
    });

    test('a break the reader removed is subtracted from every level', () {
      final words = greek();
      final auto = autoBreakPoints(words, PhrasingLevel.clauses);
      // Verse 2 starts at index 3 and the proposal breaks there.
      expect(auto, contains(3));
      final before = phrasingLevelLineCounts(at(words), words);
      final after =
          phrasingLevelLineCounts(at(words).copyWith(removed: {3}), words);
      expect(after[PhrasingLevel.clauses]!,
          before[PhrasingLevel.clauses]! - 1);
    });
  });

  group('coarserPhrasingLevel', () {
    test('the coarsest level has nothing above it', () {
      expect(
          coarserPhrasingLevel(
              PhrasingLevel.verses, PhrasingLevel.values.toSet()),
          isNull);
    });

    test('skips a level this text never offered', () {
      // A Strong's-tagged translation supports {verses, clauses,
      // phrases}: mood is not recoverable from a Strong's number, so
      // `verbals` is absent. Comparing `+ Phrases` against `+ Verbals`
      // would explain the page by a chip that is not on it.
      const available = {
        PhrasingLevel.verses,
        PhrasingLevel.clauses,
        PhrasingLevel.phrases,
      };
      expect(coarserPhrasingLevel(PhrasingLevel.phrases, available),
          PhrasingLevel.clauses);
      expect(coarserPhrasingLevel(PhrasingLevel.phrases, {PhrasingLevel.verses}),
          PhrasingLevel.verses);
    });

    test('matches what a tagged translation actually reports', () {
      final translation = [
        w('In', strongs: 'G1722', verse: 1),
        w('the', verse: 1),
        w('beginning', verse: 1),
        w('and', strongs: 'G2532', verse: 2),
        w('the', verse: 2),
      ];
      final available = availablePhrasingLevels(translation);
      expect(available, isNot(contains(PhrasingLevel.verbals)));
      expect(coarserPhrasingLevel(PhrasingLevel.phrases, available),
          PhrasingLevel.clauses);
    });
  });

  // The web build is skwasm: rendered text is not in the DOM, so a
  // screenshot cannot read this copy back. These assertions are the only
  // instrument that can.
  group('phrasingLevelNote', () {
    test('names the level, the count and the window, in each locale', () {
      final words = greek();
      final p = at(words).copyWith(level: PhrasingLevel.phrases);
      final counts = phrasingLevelLineCounts(p, words);
      final en = phrasingLevelNote(p, counts, 'en')!;
      expect(en, startsWith('+ Phrases: ${counts[PhrasingLevel.phrases]} '
          'lines in verses 1–3 — also cut at prepositions'));
      final zh = phrasingLevelNote(p, counts, 'zh-Hans')!;
      expect(zh, contains('1–3 节共 ${counts[PhrasingLevel.phrases]} 行'));
      expect(zh, isNot(contains('{')), reason: 'every slot must be filled');
    });

    test('says nothing at all about a level this edition cannot support', () {
      // #299: the app never describes a page it cannot draw. `verbals` is
      // disabled on a Strong\'s-tagged translation, so it gets no note.
      final words = [w('In', strongs: 'G1722'), w('and', strongs: 'G2532')];
      final p = at(words).copyWith(level: PhrasingLevel.verbals);
      expect(phrasingLevelNote(p, phrasingLevelLineCounts(p, words), 'en'),
          isNull);
    });

    test('prints "same lines as" on the passage that motivated it', () {
      final chapters = _chapters(File('assets/originals/john.json'));
      final words = chapters[1]!;
      final p = at(words, start: 1, end: 5)
          .copyWith(level: PhrasingLevel.verbals);
      final counts = phrasingLevelLineCounts(p, words);
      final note = phrasingLevelNote(p, counts, 'en')!;
      expect(note, contains('Same lines as Clauses'));
      // And the coarser level itself must not accuse the level above it.
      final clauses = p.copyWith(level: PhrasingLevel.clauses);
      expect(phrasingLevelNote(clauses, counts, 'en'),
          isNot(contains('Same lines as')));
    });

    test('reassures only a reader who has something to lose', () {
      final words = greek();
      final p = at(words);
      final counts = phrasingLevelLineCounts(p, words);
      expect(phrasingLevelNote(p, counts, 'en'),
          isNot(contains('keeps your own breaks')));
      expect(phrasingLevelNote(p.copyWith(added: {2}), counts, 'en'),
          contains('keeps your own breaks'));
    });

    test('every chip and every phrase is translated in both scripts', () {
      // A missing key falls back to English silently, which would ship a
      // Chinese pane with an English chip on it.
      for (final locale in ['zh-Hans', 'zh-Hant']) {
        for (final e in phrasingLevelChips) {
          expect(phrasingLevelName(e.$1, locale), isNot(e.$3),
              reason: '${e.$2} has no $locale');
        }
      }
    });
  });

  group('the corpus — what the chips will actually say', () {
    test('John 1:1-5 gives + Verbals nothing to do, and it is not alone', () {
      final chapters = _chapters(File('assets/originals/john.json'));
      final words = chapters[1]!;
      final counts =
          phrasingLevelLineCounts(at(words, start: 1, end: 5), words);
      // The instance that started this: five famous verses in which
      // `+ Verbals` draws the identical page to `Clauses`. Before the
      // count, a reader tapped it, saw nothing move, and learned that
      // the tool was broken.
      expect(counts[PhrasingLevel.verbals], counts[PhrasingLevel.clauses],
          reason: 'John 1:1-5 begins no unit at a participle or infinitive '
              'that Clauses had not already broken');
      expect(counts[PhrasingLevel.verses], 5);
      expect(counts[PhrasingLevel.phrases]!,
          greaterThan(counts[PhrasingLevel.verbals]!));
    });

    test('a level draws nothing new often enough to be worth printing', () {
      // The measurement that motivated the widget, frozen rather than
      // quoted in a commit message. Swept over every three-verse window
      // of the bundled original-language corpus.
      //
      // `availablePhrasingLevels` cannot see any of these: it asks
      // whether the EDITION carries a parse, not whether this PASSAGE
      // has a participle in it.
      var windows = 0;
      final dead = {
        PhrasingLevel.clauses: 0,
        PhrasingLevel.verbals: 0,
        PhrasingLevel.phrases: 0,
      };
      var equalPagesChecked = 0;
      for (final f
          in Directory('assets/originals').listSync().whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        for (final entry in _chapters(f).entries) {
          final words = entry.value;
          final verses = ({for (final x in words) x.verse}.toList()..sort());
          for (var i = 0; i + 2 < verses.length; i += 3) {
            final p = Phrasing(
              version: 'v',
              book: f.path,
              chapter: entry.key,
              startVerse: verses[i],
              endVerse: verses[i + 2],
            );
            final counts = phrasingLevelLineCounts(p, words);
            windows++;
            for (final level in dead.keys) {
              final coarser =
                  coarserPhrasingLevel(level, counts.keys.toSet());
              if (coarser == null || counts[level] != counts[coarser]) continue;
              dead[level] = dead[level]! + 1;
              // The note prints "same lines as {b}" as a statement of
              // fact, so prove it: equal counts must mean the identical
              // set of line starts, not merely the same number of them.
              List<int> starts(PhrasingLevel l) => [
                    for (final line in visiblePhrasingLines(
                        layoutPhrasing(p.copyWith(level: l), words),
                        words,
                        p.startVerse,
                        p.endVerse))
                      line.start,
                  ];
              expect(starts(level), starts(coarser),
                  reason: 'equal line counts must mean an identical page — '
                      '${f.path} ${entry.key}:${verses[i]} at $level');
              equalPagesChecked++;
            }
          }
        }
      }
      expect(windows, 9982, reason: 'three-verse windows in the corpus');
      // One tap in five on `+ Verbals` moved nothing, and the reader had
      // no way to know before making it.
      expect(dead[PhrasingLevel.verbals], 2087);
      expect(dead[PhrasingLevel.clauses], 236);
      expect(dead[PhrasingLevel.phrases], 356);
      expect(equalPagesChecked, 2679);
    });
  });
}
