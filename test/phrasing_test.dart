import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/phrasing.dart';

/// A Greek word. Every morph code in this file was checked against
/// `assets/originals/*.json` rather than reconstructed from the scheme,
/// because the Greek codes are exactly ten characters and an eight-
/// character one parses as Semitic garbage instead of failing loudly:
/// `C---------` conjunction (18,175 in the corpus), `P---------`
/// preposition (10,852), `RR----NSM-` relative pronoun (247),
/// `V--PAPNSM-` participle (936), `V--AAN----` infinitive (946).
PhrasingWord g(String text, String morph, {String strongs = '', int verse = 1}) =>
    PhrasingWord(text: text, strongs: strongs, verse: verse, morph: morph);

/// A Hebrew word. `H` + morphemes split on `/`.
PhrasingWord h(String text, String morph, {String strongs = '', int verse = 1}) =>
    PhrasingWord(text: text, strongs: strongs, verse: verse, morph: morph);

/// Plain words with no morphology at all — the fallback corpus.
List<PhrasingWord> plain(int count, {int perVerse = 100}) => [
      for (var i = 0; i < count; i++)
        PhrasingWord(
          text: 'w$i',
          strongs: '',
          verse: 1 + i ~/ perVerse,
        ),
    ];

Phrasing bare(
  List<PhrasingWord> words, {
  PhrasingLevel level = PhrasingLevel.clauses,
}) =>
    Phrasing(
      version: 'sblgnt',
      book: 'John',
      chapter: 1,
      startVerse: 1,
      endVerse: words.isEmpty ? 1 : words.last.verse,
      level: level,
    );

void main() {
  group('autoBreakPoints — the proposal', () {
    test('verse starts break at every level, even with no morphology', () {
      final words = [
        PhrasingWord(text: 'a', strongs: '', verse: 1),
        PhrasingWord(text: 'b', strongs: '', verse: 1),
        PhrasingWord(text: 'c', strongs: '', verse: 2),
        PhrasingWord(text: 'd', strongs: '', verse: 3),
      ];
      for (final level in PhrasingLevel.values) {
        expect(autoBreakPoints(words, level), {0, 2, 3},
            reason: 'verse starts are unconditional at $level');
      }
    });

    test('levels are monotonic supersets — finer only ever ADDS breaks', () {
      // The property the whole added/removed diff design rests on: a
      // reader can change level mid-study and never lose a line.
      final words = [
        g('Ἐν', 'P---------'), //            0 preposition
        g('ἀρχῇ', 'N-----DSF-'), //        1
        g('καὶ', 'C---------'), //           2 conjunction
        g('ὁ', 'RA----NSM-'), //           3
        g('λέγων', 'V--PAPNSM-'), //       4 participle
        g('ἐστιν', 'V-3PAI-S--'), //       5 finite
        g('λῦσαι', 'V--AAN----'), //       6 infinitive
        g('ὃς', 'RR----NSM-'), //          7 relative pronoun
        g('ἐν', 'P---------'), //            8 preposition
      ];
      var previous = autoBreakPoints(words, PhrasingLevel.values.first);
      for (final level in PhrasingLevel.values.skip(1)) {
        final current = autoBreakPoints(words, level);
        expect(current.containsAll(previous), isTrue,
            reason: '$level must be a superset of the level before it');
        previous = current;
      }
    });

    test('Greek: conjunction and relative are clause joints; verbals and '
        'prepositions wait for their own level', () {
      final words = [
        g('ἀρχῇ', 'N-----DSF-'), //   0
        g('καὶ', 'C---------'), //      1 clauses
        g('λέγων', 'V--PAPNSM-'), //  2 verbals
        g('ἐστιν', 'V-3PAI-S--'), //  3 never — finite is the backbone
        g('λῦσαι', 'V--AAN----'), //  4 verbals
        g('ὃς', 'RR----NSM-'), //     5 clauses
        g('ἐν', 'P---------'), //       6 phrases
      ];
      expect(autoBreakPoints(words, PhrasingLevel.verses), {0});
      expect(autoBreakPoints(words, PhrasingLevel.clauses), {0, 1, 5});
      expect(autoBreakPoints(words, PhrasingLevel.verbals), {0, 1, 2, 4, 5});
      expect(
          autoBreakPoints(words, PhrasingLevel.phrases), {0, 1, 2, 4, 5, 6});
    });

    test('Semitic: the conjunction is a PREFIX, the verbal is the HEAD', () {
      // The 89% finding: an infinitive behind לְ־ is the second morpheme,
      // so a first-morpheme test would miss it.
      final words = [
        h('בְּרֵאשִׁית', 'HR/Ncfsa'), //  0 prefixed preposition
        h('וַיֹּאמֶר', 'HC/Vqw3ms'), //   1 prefixed conjunction
        h('אֱלֹהִים', 'HNcmpa'), //       2 plain noun
        h('לֵאמֹר', 'HR/Vqc'), //         3 preposition + infinitive construct
        h('אֲשֶׁר', 'HTr'), //            4 relative particle
        h('בָּאָרֶץ', 'HR/Ncfsa'), //     5 prefixed preposition
      ];
      expect(autoBreakPoints(words, PhrasingLevel.verses), {0});
      // The prefixed conjunction and the relative particle are joints.
      expect(autoBreakPoints(words, PhrasingLevel.clauses), {0, 1, 4});
      // The infinitive is found through the HEAD, not the prefix — a
      // first-morpheme test would see only the לְ־ and miss it.
      expect(autoBreakPoints(words, PhrasingLevel.verbals), {0, 1, 3, 4});
      // Only now does a plain prefixed preposition count.
      expect(autoBreakPoints(words, PhrasingLevel.phrases), {0, 1, 3, 4, 5});
    });

    test('an empty passage proposes nothing', () {
      expect(autoBreakPoints(const [], PhrasingLevel.phrases), isEmpty);
    });
  });

  group('effectiveBreaks — proposal plus the reader', () {
    test('word 0 is always a break and cannot be removed', () {
      final words = plain(5);
      final p = bare(words).copyWith(removed: {0});
      expect(effectiveBreaks(p, words), contains(0));
    });

    test('added and removed are applied, out-of-range indices ignored', () {
      final words = plain(5);
      final p = bare(words).copyWith(added: {2, 99, -3});
      expect(effectiveBreaks(p, words), {0, 2});
    });

    test('a removed auto break really goes away', () {
      final words = [
        g('ἀρχῇ', 'N-----DSF-'),
        g('καὶ', 'C---------'),
        g('θεός', 'N-----NSM-'),
      ];
      final p = bare(words);
      expect(effectiveBreaks(p, words), {0, 1});
      expect(effectiveBreaks(p.copyWith(removed: {1}), words), {0});
    });
  });

  group('togglePhrasingBreak — one gesture, its own inverse', () {
    test('toggling an auto break off records it as removed', () {
      final words = [
        g('ἀρχῇ', 'N-----DSF-'),
        g('καὶ', 'C---------'),
        g('θεός', 'N-----NSM-'),
      ];
      final p = bare(words);
      final off = togglePhrasingBreak(p, words, 1);
      expect(off.removed, contains(1));
      expect(effectiveBreaks(off, words), {0});
      final backOn = togglePhrasingBreak(off, words, 1);
      expect(backOn.removed, isNot(contains(1)));
      expect(effectiveBreaks(backOn, words), {0, 1});
    });

    test('toggling a non-break on records it as added, and back off', () {
      final words = plain(5);
      final p = bare(words);
      final on = togglePhrasingBreak(p, words, 3);
      expect(on.added, contains(3));
      final off = togglePhrasingBreak(on, words, 3);
      expect(off.added, isNot(contains(3)));
      expect(effectiveBreaks(off, words), {0});
    });

    test('index 0 and out-of-range are no-ops, not errors', () {
      final words = plain(4);
      final p = bare(words);
      expect(togglePhrasingBreak(p, words, 0).isTouched, isFalse);
      expect(togglePhrasingBreak(p, words, 4).isTouched, isFalse);
      expect(togglePhrasingBreak(p, words, -1).isTouched, isFalse);
    });
  });

  group('changing level preserves manual intent', () {
    test('a manual break survives a level change', () {
      final words = [
        g('ἀρχῇ', 'N-----DSF-'),
        g('ἦν', 'V-3IAI-S--'),
        g('θεός', 'N-----NSM-'),
        g('ἐν', 'P---------'),
      ];
      var p = bare(words, level: PhrasingLevel.verses);
      p = togglePhrasingBreak(p, words, 2);
      expect(effectiveBreaks(p, words), {0, 2});
      p = setPhrasingLevel(p, PhrasingLevel.phrases);
      // The proposal now adds the preposition at 3; the reader's break
      // at 2 is still there.
      expect(effectiveBreaks(p, words), {0, 2, 3});
    });

    test('a break the reader deleted stays deleted when it is re-proposed',
        () {
      final words = [
        g('ἀρχῇ', 'N-----DSF-'),
        g('λέγων', 'V--PAPNSM-'),
        g('θεός', 'N-----NSM-'),
      ];
      // At `verbals` the participle at 1 is proposed; delete it.
      var p = bare(words, level: PhrasingLevel.verbals);
      p = togglePhrasingBreak(p, words, 1);
      expect(effectiveBreaks(p, words), {0});
      // Coarsen — nothing proposes it — then go back. It must not
      // reappear, or the reader's deletion was a lie.
      p = setPhrasingLevel(p, PhrasingLevel.verses);
      p = setPhrasingLevel(p, PhrasingLevel.verbals);
      expect(effectiveBreaks(p, words), {0});
    });

    test('depths and relations survive a level change', () {
      final words = plain(6);
      var p = bare(words, level: PhrasingLevel.verses);
      p = togglePhrasingBreak(p, words, 3);
      p = indentPhrasingLine(p, words, 3);
      p = setPhrasingRelation(p, 3, PhrasingRelation.ground);
      p = setPhrasingLevel(p, PhrasingLevel.phrases);
      final line = layoutPhrasing(p, words).firstWhere((l) => l.start == 3);
      expect(line.depth, 1);
      expect(line.relation, PhrasingRelation.ground);
    });
  });

  group('layoutPhrasing — depth is clamped at layout, stored raw', () {
    test('a line can never be more than one level below its predecessor', () {
      final words = plain(9);
      final p = bare(words, level: PhrasingLevel.verses).copyWith(
        added: {3, 6},
        depths: {3: 5, 6: 9},
      );
      final lines = layoutPhrasing(p, words);
      expect(lines.map((l) => l.depth), [0, 1, 2]);
    });

    test('the first line is always depth 0', () {
      final words = plain(4);
      final p = bare(words).copyWith(depths: {0: 4});
      expect(layoutPhrasing(p, words).first.depth, 0);
    });

    test('outdenting a parent is non-destructive — children spring back', () {
      // The subtlest promise in the file: clamping at layout rather than
      // at edit time means a gesture aimed at one line cannot silently
      // consume the depths the reader chose for the lines below it.
      final words = plain(9);
      var p = bare(words, level: PhrasingLevel.verses)
          .copyWith(added: {3, 6}, depths: {3: 1, 6: 2});
      expect(layoutPhrasing(p, words).map((l) => l.depth), [0, 1, 2]);

      p = outdentPhrasingLine(p, words, 3);
      // The child at 6 is clamped up to follow its parent …
      expect(layoutPhrasing(p, words).map((l) => l.depth), [0, 0, 1]);
      // … but its stored depth was never overwritten.
      expect(p.depths[6], 2);

      p = indentPhrasingLine(p, words, 3);
      // … so it springs back to what the reader originally chose.
      expect(layoutPhrasing(p, words).map((l) => l.depth), [0, 1, 2]);
    });

    test('indent reads the DRAWN depth, not the stored one', () {
      final words = plain(6);
      // Stored at 7, drawn at 1 (clamped to prev 0 + 1). Indenting must
      // give 2, not 8.
      var p = bare(words, level: PhrasingLevel.verses)
          .copyWith(added: {3}, depths: {3: 7});
      expect(layoutPhrasing(p, words).last.depth, 1);
      p = indentPhrasingLine(p, words, 3);
      expect(p.depths[3], 2);
    });

    test('outdent stops at 0 rather than going negative', () {
      final words = plain(6);
      final p = bare(words, level: PhrasingLevel.verses).copyWith(added: {3});
      expect(outdentPhrasingLine(p, words, 3).depths[3], isNull);
    });

    test('a line spans up to the next break, and the last runs to the end',
        () {
      final words = plain(7);
      final p = bare(words, level: PhrasingLevel.verses).copyWith(added: {2, 5});
      final lines = layoutPhrasing(p, words);
      expect(lines.map((l) => '${l.start}-${l.end}'), ['0-2', '2-5', '5-7']);
    });

    test('an empty passage lays out to nothing', () {
      expect(layoutPhrasing(bare(const []), const []), isEmpty);
    });

    test('a chosen relation suppresses the suggestion', () {
      final words = [
        g('ἀρχῇ', 'N-----DSF-'),
        g('ὅτι', 'C---------', strongs: 'G3754'),
      ];
      final p = bare(words);
      final suggested = layoutPhrasing(p, words).last;
      expect(suggested.relation, isNull);
      expect(suggested.suggested, PhrasingRelation.content);

      final chosen = layoutPhrasing(
        setPhrasingRelation(p, 1, PhrasingRelation.ground),
        words,
      ).last;
      expect(chosen.relation, PhrasingRelation.ground);
      expect(chosen.suggested, isNull,
          reason: 'a guess that looks like a decision is worse than no guess');
    });

    test('the first line is never given a suggestion', () {
      final words = [g('ὅτι', 'C---------', strongs: 'G3754')];
      expect(layoutPhrasing(bare(words), words).single.suggested, isNull);
    });
  });

  group('visiblePhrasingLines — the window never moves an index', () {
    test('a clause straddling the window start is shown whole', () {
      final words = [
        PhrasingWord(text: 'a', strongs: '', verse: 1),
        PhrasingWord(text: 'b', strongs: '', verse: 1),
        PhrasingWord(text: 'c', strongs: '', verse: 2),
        PhrasingWord(text: 'd', strongs: '', verse: 3),
      ];
      // One line 0-3 covering verses 1 and 2, then a line for verse 3.
      final p = bare(words, level: PhrasingLevel.verses)
          .copyWith(removed: {2}, startVerse: 2, endVerse: 2);
      final lines = layoutPhrasing(p, words);
      final visible = visiblePhrasingLines(lines, words, 2, 2);
      expect(visible, hasLength(1));
      expect(visible.single.start, 0,
          reason: 'the clause begins in verse 1 but is shown from its head');
    });

    test('a window with nothing in it yields no lines', () {
      final words = plain(4, perVerse: 2);
      final lines = layoutPhrasing(bare(words), words);
      expect(visiblePhrasingLines(lines, words, 9, 9), isEmpty);
    });
  });

  group('suggestRelations — a list, because the grammar is ambiguous', () {
    test('ὅτι is content-introducing AND causal, in that order', () {
      expect(suggestRelations(g('ὅτι', 'C---------', strongs: 'G3754')),
          [PhrasingRelation.content, PhrasingRelation.ground]);
    });

    test('ἵνα offers purpose and result', () {
      expect(suggestRelations(g('ἵνα', 'C---------', strongs: 'G2443')),
          [PhrasingRelation.purpose, PhrasingRelation.result]);
    });

    test('a Greek relative pronoun is a relative, whatever its Strong\'s', () {
      expect(suggestRelations(g('ὃς', 'RR----NSM-')),
          [PhrasingRelation.relative]);
    });

    test('a word the grammar has nothing to say about returns empty', () {
      expect(suggestRelations(g('θεός', 'N-----NSM-', strongs: 'G2316')),
          isEmpty);
      expect(suggestRelations(g('καί', 'C---------', strongs: 'G9999')), isEmpty,
          reason: 'an unknown conjunction must not be guessed at');
      expect(
          suggestRelations(
              PhrasingWord(text: 'x', strongs: '', verse: 1, morph: null)),
          isEmpty);
    });

    test('a PREFIXED Hebrew conjunction is the waw, and asserts neither '
        'reading', () {
      // Its Strong's belongs to the host word, so it cannot be looked
      // up — but 99.94% of them are the waw.
      expect(suggestRelations(h('וַיֹּאמֶר', 'HC/Vqw3ms', strongs: 'H559')),
          [PhrasingRelation.series, PhrasingRelation.progression]);
    });

    test('a STANDALONE Hebrew conjunction owns its Strong\'s', () {
      expect(suggestRelations(h('כִּי', 'HC', strongs: 'H3588')), [
        PhrasingRelation.ground,
        PhrasingRelation.content,
        PhrasingRelation.temporal,
      ]);
    });

    test('the Hebrew relative particle is reached through Tr', () {
      expect(suggestRelations(h('אֲשֶׁר', 'HTr', strongs: 'H834')),
          [PhrasingRelation.relative]);
    });
  });

  group('exportPhrasing', () {
    test('indents by depth, marks the relation, and numbers each verse', () {
      final words = [
        PhrasingWord(text: 'In', strongs: '', verse: 1),
        PhrasingWord(text: 'beginning', strongs: '', verse: 1),
        PhrasingWord(text: 'was', strongs: '', verse: 2),
        PhrasingWord(text: 'Word', strongs: '', verse: 2),
      ];
      final p = bare(words, level: PhrasingLevel.verses)
          .copyWith(depths: {2: 1}, relations: {2: PhrasingRelation.ground});
      final out = exportPhrasing(
        p,
        words,
        label: (r) => r.name,
        indentUnit: '  ',
      );
      expect(out, '(1) In beginning\n  [ground] (2) was Word\n');
    });

    test('a custom verse mark is used, and the verse is marked once', () {
      final words = [
        PhrasingWord(text: 'a', strongs: '', verse: 3),
        PhrasingWord(text: 'b', strongs: '', verse: 3),
      ];
      final out = exportPhrasing(
        bare(words),
        words,
        label: (r) => r.name,
        verseMark: (v) => 'v$v',
      );
      expect(out, 'v3 a b\n');
    });
  });

  group('persistence round-trip', () {
    test('every field survives toJson/fromJson', () {
      final p = Phrasing(
        version: 'sblgnt',
        book: 'John',
        chapter: 3,
        startVerse: 16,
        endVerse: 18,
        level: PhrasingLevel.verbals,
        added: {4, 9},
        removed: {2},
        depths: {4: 1, 9: 2},
        relations: {4: PhrasingRelation.purpose},
      );
      final back = Phrasing.fromJson(p.toJson())!;
      expect(back.toJson(), p.toJson());
      expect(back.level, PhrasingLevel.verbals);
      expect(back.relations[4], PhrasingRelation.purpose);
    });

    test('a blob without a usable book or chapter is rejected', () {
      expect(Phrasing.fromJson({'book': 'John'}), isNull);
      expect(Phrasing.fromJson({'chapter': 3}), isNull);
      expect(Phrasing.fromJson({'book': '', 'chapter': 3}), isNull);
      expect(Phrasing.fromJson({'book': 'John', 'chapter': '3'}), isNull);
    });

    test('unreadable parts are dropped, never thrown — losing one label '
        'beats losing the passage', () {
      final back = Phrasing.fromJson({
        'book': 'John',
        'chapter': 1,
        'level': 'no-such-level',
        'added': [3, 'x', -1],
        'depths': {'4': 2, 'bad': 1, '5': 'deep'},
        'relations': {'4': 'purpose', '5': 'no-such-relation'},
      })!;
      expect(back.level, PhrasingLevel.clauses, reason: 'safe default');
      expect(back.added, {3});
      expect(back.depths, {4: 2});
      expect(back.relations, {4: PhrasingRelation.purpose});
    });

    test('an unknown relation id resolves to null rather than throwing', () {
      expect(phrasingRelationFromId('ground'), PhrasingRelation.ground);
      expect(phrasingRelationFromId('nope'), isNull);
      expect(phrasingRelationFromId(null), isNull);
    });
  });

  group('reset and isTouched', () {
    test('isTouched is false until the reader does something', () {
      final words = plain(4);
      final p = bare(words);
      expect(p.isTouched, isFalse);
      expect(togglePhrasingBreak(p, words, 2).isTouched, isTrue);
      expect(setPhrasingRelation(p, 0, PhrasingRelation.ground).isTouched,
          isTrue);
    });

    test('reset keeps the passage and the level, drops every edit', () {
      final words = plain(6);
      var p = bare(words, level: PhrasingLevel.verbals);
      p = togglePhrasingBreak(p, words, 3);
      p = indentPhrasingLine(p, words, 3);
      p = setPhrasingRelation(p, 3, PhrasingRelation.result);
      final clean = resetPhrasing(p);
      expect(clean.isTouched, isFalse);
      expect(clean.level, PhrasingLevel.verbals);
      expect(clean.book, 'John');
      expect(clean.chapter, 1);
    });
  });

  group('localisation coverage', () {
    test('every relation has a label in all three locales', () {
      for (final r in PhrasingRelation.values) {
        final key =
            'phrasingRel${r.name[0].toUpperCase()}${r.name.substring(1)}';
        final entry = uiStrings[key];
        expect(entry, isNotNull, reason: '$key is missing from uiStrings');
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(entry![locale], isNotNull,
              reason: '$key has no $locale translation');
          expect(entry[locale], isNotEmpty);
        }
      }
    });

    test('every level and every page string is translated', () {
      const keys = [
        'phrasingTitle',
        'phrasingCopied',
        'phrasingReset',
        'phrasingRange',
        'phrasingNone',
        'phrasingEmptyWindow',
        'phrasingHint',
        'phrasingRelNone',
        'phrasingSuggested',
        'phrasingFooterIdle',
        'phrasingLevelVerses',
        'phrasingLevelClauses',
        'phrasingLevelVerbals',
        'phrasingLevelPhrases',
      ];
      for (final key in keys) {
        final entry = uiStrings[key];
        expect(entry, isNotNull, reason: '$key is missing from uiStrings');
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(entry![locale], isNotNull,
              reason: '$key has no $locale translation');
        }
      }
    });
  });
}
