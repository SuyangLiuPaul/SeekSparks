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

    test('the first line is bounded by maxPhrasingDepth, not by zero', () {
      // Until v1.6.98 line one was pinned at 0. It has no predecessor to
      // clamp against, so it gets a stop of its own instead.
      final words = plain(4);
      final p = bare(words).copyWith(depths: {0: 4});
      expect(layoutPhrasing(p, words).first.depth, 4);
      expect(
        layoutPhrasing(p.copyWith(depths: {0: 99}), words).first.depth,
        maxPhrasingDepth,
      );
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

  group('phrasingTokens — a translation split into breakable units', () {
    test('joining the tokens reproduces the verse exactly', () {
      const inputs = [
        'Grace to you, and peace from God our Father.',
        '「我实实在在地告诉你们，」他说。',
        'Paul, an apostle — not from men —',
      ];
      for (final s in inputs) {
        expect(phrasingTokens(s).join(), s,
            reason: 'a line that has lost its punctuation is not the text');
      }
    });

    test('one token per Han character, punctuation carried on the left', () {
      expect(phrasingTokens('神爱世人，'), ['神', '爱', '世', '人，']);
    });

    test('one token per alphabetic run, the space carried after the word', () {
      expect(phrasingTokens('in the beginning'), ['in ', 'the ', 'beginning']);
    });

    test('leading punctuation attaches to the first word, never stands '
        'alone', () {
      // An opening quotation mark that can be broken away from the word
      // it opens is a line the reader cannot repair.
      expect(phrasingTokens('“And God said'), ['“And ', 'God ', 'said']);
    });

    test('text with no word characters at all is kept as one token', () {
      expect(phrasingTokens('— ?'), ['— ?']);
      expect(phrasingTokens('   '), isEmpty);
      expect(phrasingTokens(''), isEmpty);
    });
  });

  group('availablePhrasingLevels', () {
    test('a bare text offers only verses', () {
      expect(availablePhrasingLevels(plain(3)), {PhrasingLevel.verses});
      expect(availablePhrasingLevels(const []), {PhrasingLevel.verses});
    });

    test('a tagged translation offers everything except verbals', () {
      // Mood is not recoverable from a Strong's number, so offering
      // `+ Verbals` here would be a control that does nothing.
      final tagged = [
        PhrasingWord(text: 'For ', strongs: 'G1063', verse: 1),
        PhrasingWord(text: 'God ', strongs: 'G2316', verse: 1),
      ];
      expect(availablePhrasingLevels(tagged), {
        PhrasingLevel.verses,
        PhrasingLevel.clauses,
        PhrasingLevel.phrases,
      });
    });

    test('a parsed original offers all four', () {
      expect(availablePhrasingLevels([g('θεός', 'N-----NSM-')]),
          PhrasingLevel.values.toSet());
    });

    test('an empty morph field does not count as a parse', () {
      final blank = [
        PhrasingWord(text: 'x', strongs: '', verse: 1, morph: ''),
        PhrasingWord(text: 'y', strongs: '', verse: 1, morph: '  '),
      ];
      expect(availablePhrasingLevels(blank), {PhrasingLevel.verses});
    });
  });

  group('breaks from a Strong\'s number alone — the translation proposal', () {
    /// An English run out of `assets/tagged/bsb/*.json`: a number, no
    /// morph code.
    PhrasingWord t(String text, String strongs, {int verse = 1}) =>
        PhrasingWord(text: text, strongs: strongs, verse: verse);

    test('a conjunction breaks a clause even with no parse', () {
      final words = [
        t('I ', 'G1473'),
        t('write ', 'G1125'),
        t('that ', 'G2443'), //  ἵνα
        t('you ', 'G4771'),
      ];
      expect(autoBreakPoints(words, PhrasingLevel.clauses), {0, 2});
    });

    test('a preposition waits for the phrases level, as with a parse', () {
      final words = [
        t('grace ', 'G5485'),
        t('in ', 'G1722'), // ἐν
        t('Christ', 'G5547'),
      ];
      expect(autoBreakPoints(words, PhrasingLevel.clauses), {0});
      expect(autoBreakPoints(words, PhrasingLevel.verbals), {0});
      expect(autoBreakPoints(words, PhrasingLevel.phrases), {0, 1});
    });

    test('a relative pronoun breaks, and an ordinary word does not', () {
      final words = [
        t('the ', 'G3588'),
        t('who ', 'G3739'), // ὅς
        t('God', 'G2316'),
      ];
      expect(autoBreakPoints(words, PhrasingLevel.clauses), {0, 1});
    });

    test('a Chinese OT run carries its HOST word\'s number, so the waw is '
        'invisible', () {
      // Not a defect to be fixed by guessing: the prefixed conjunction
      // has no Strong's of its own. A smaller proposal, not a wrong one.
      final words = [
        t('耶和华', 'H3068'),
        t('说', 'H559'), // וַיֹּאמֶר — the waw is inside this word
      ];
      expect(autoBreakPoints(words, PhrasingLevel.phrases), {0});
    });

    test('a parse still wins where there is one', () {
      // The Strong's fallback must not displace the morphology: this
      // participle has no conjunction number and still breaks.
      final words = [g('θεός', 'N-----NSM-'), g('λέγων', 'V--PAPNSM-')];
      expect(autoBreakPoints(words, PhrasingLevel.verbals), {0, 1});
    });
  });

  group('the first line indents too', () {
    test('line one takes a depth instead of being pinned at zero', () {
      final words = plain(4);
      final p = bare(words, level: PhrasingLevel.verses);
      expect(layoutPhrasing(p, words).first.depth, 0);
      final indented = indentPhrasingLine(p, words, 0);
      expect(layoutPhrasing(indented, words).first.depth, 1);
    });

    test('line one stops at maxPhrasingDepth — held down, it cannot push '
        'the text off screen', () {
      final words = plain(4);
      var p = bare(words, level: PhrasingLevel.verses);
      for (var i = 0; i < maxPhrasingDepth + 5; i++) {
        p = indentPhrasingLine(p, words, 0);
      }
      expect(layoutPhrasing(p, words).first.depth, maxPhrasingDepth);
    });

    test('an indented first line still bounds the second', () {
      // Every other line is clamped to prevDepth + 1, and line one being
      // deep must not let line two jump past it.
      final words = [
        PhrasingWord(text: 'a', strongs: '', verse: 1),
        PhrasingWord(text: 'b', strongs: '', verse: 2),
      ];
      final p = bare(words, level: PhrasingLevel.verses)
          .copyWith(depths: {0: 3, 1: 9});
      final lines = layoutPhrasing(p, words);
      expect(lines.map((l) => l.depth), [3, 4]);
    });

    test('the indent survives export', () {
      final words = [
        PhrasingWord(text: 'In', strongs: '', verse: 1),
        PhrasingWord(text: 'was', strongs: '', verse: 2),
      ];
      final p = bare(words, level: PhrasingLevel.verses).copyWith(
        depths: {0: 1},
      );
      final out =
          exportPhrasing(p, words, label: (r) => r.name, indentUnit: '  ');
      expect(out, '  (1) In\n(2) was\n');
    });
  });

  group('phrasingIsRtl — decided by the script, not the Strong\'s prefix', () {
    test('Hebrew text is right to left', () {
      expect(phrasingIsRtl([h('בְּרֵאשִׁית', 'HNcfsa')]), isTrue);
    });

    test('a CHINESE verse tagged with H-numbers is not', () {
      // The bug this replaced: keying on strongs.startsWith('H') mirrored
      // the whole diagram for anyone phrasing Genesis in a translation.
      final words = [
        PhrasingWord(text: '起初', strongs: 'H7225', verse: 1),
        PhrasingWord(text: '神', strongs: 'H430', verse: 1),
      ];
      expect(phrasingIsRtl(words), isFalse);
    });

    test('Greek and empty passages are left to right', () {
      expect(phrasingIsRtl([g('ἀρχῇ', 'N-----DSF-')]), isFalse);
      expect(phrasingIsRtl(const []), isFalse);
    });
  });

  group('phrasingIsCjk — Chinese is drawn without word gaps', () {
    List<PhrasingWord> of(List<String> texts) => [
          for (final t in texts) PhrasingWord(text: t, strongs: '', verse: 1),
        ];

    test('a per-character Chinese chapter is CJK', () {
      expect(phrasingIsCjk(of(['神', '爱', '世', '人'])), isTrue);
    });

    test('a tagged Chinese chapter, cut into multi-character runs, is too', () {
      expect(phrasingIsCjk(of(['起初', '神', '创造', '天', '地'])), isTrue);
    });

    test('English, Greek and Hebrew keep their gaps', () {
      expect(phrasingIsCjk(of(['In', 'the', 'beginning'])), isFalse);
      expect(phrasingIsCjk([g('ἀρχῇ', 'N-----DSF-')]), isFalse);
      expect(phrasingIsCjk([h('בְּרֵאשִׁית', 'HNcfsa')]), isFalse);
      expect(phrasingIsCjk(const []), isFalse);
    });

    test('a mostly-English verse with a stray Chinese note is not CJK', () {
      expect(phrasingIsCjk(of(['In', 'the', '和', 'beginning'])), isFalse);
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
        'phrasingSourceVersion',
        'phrasingSourceOriginals',
        'phrasingNoParse',
        'phrasingNoTags',
        'phrasingUnpin',
        'phrasingGlossShow',
        'phrasingGlossHide',
        'phrasingGlossFrom',
        'phrasingGlossLexicon',
        'phrasingGlossItalic',
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
