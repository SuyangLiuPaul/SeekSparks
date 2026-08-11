/// 2026-08-07 (SeekSparks): the Context tab's three pure cores —
/// part-of-speech classification, pericope ranges, and keyness.
///
/// The morphology cases below are all real codes lifted from
/// `assets/originals/`, not invented ones. They are here because the two
/// tagging schemes assign OPPOSITE meanings to `R` and `P`, and because
/// the head morpheme of a Hebrew code is at neither a fixed start nor a
/// fixed end — a plausible implementation of either rule passes a
/// hand-written test and mislabels Genesis 1:1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/context_pane.dart';
import 'package:seeksparks/utils/context_words.dart';
import 'package:seeksparks/utils/pericope.dart';
import 'package:seeksparks/utils/word_pos.dart';

void _ignoreVerse(int chapter, int verse) {}

/// Both panes below size their type from the reader's Font Size setting
/// (#315), so both need the settings they read. Not a test convenience:
/// `WbType.of` deliberately has no no-provider fallback, because a
/// fallback is how a pane silently goes back to fixed sizes.
Widget _settingsHost(Widget child) {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return ChangeNotifierProvider<AppSettings>.value(
    value: AppSettings(),
    child: child,
  );
}

OriginalWord w(String text, String strongs, [String? morph]) =>
    OriginalWord(text: text, strongs: strongs, morph: morph);

void main() {
  group('posOf — Greek (CCAT/Nestle)', () {
    test('reads the head letter', () {
      expect(posOf('G746', 'N-----DSF-'), WordPos.noun);
      expect(posOf('G1510', 'V-3IAI-S--'), WordPos.verb);
      expect(posOf('G3956', 'A-----NPN-'), WordPos.adjective);
      expect(posOf('G3761', 'D---------'), WordPos.adverb);
      expect(posOf('G2532', 'C---------'), WordPos.conjunction);
      expect(posOf('G3756', 'X---------'), WordPos.particle);
      expect(posOf('G2400', 'I---------'), WordPos.interjection);
    });

    test('RA is the article, every other R is a pronoun', () {
      expect(posOf('G3588', 'RA----NSM-'), WordPos.article);
      expect(posOf('G846', 'RP----GSM-'), WordPos.pronoun);
      expect(posOf('G3778', 'RD----NSM-'), WordPos.pronoun);
      expect(posOf('G3739', 'RR----NSN-'), WordPos.pronoun);
      expect(posOf('G5101', 'RI----NSM-'), WordPos.pronoun);
    });

    test('Greek P is a PREPOSITION, not a pronoun', () {
      // ἐν. The same letter is a pronoun in the Hebrew scheme; getting
      // this backwards silently reclassifies every Greek preposition.
      expect(posOf('G1722', 'P---------'), WordPos.preposition);
    });
  });

  group('posOf — Hebrew / Aramaic (OSHB)', () {
    test('bare codes, language marker stripped', () {
      expect(posOf('H430', 'HNcmpa'), WordPos.noun); // אֱלֹהִים
      expect(posOf('H1254', 'HVqp3ms'), WordPos.verb); // בָּרָא
      expect(posOf('H2896', 'HAamsa'), WordPos.adjective); // טוֹב
      expect(posOf('H3651', 'HD'), WordPos.adverb); // כֵּן
      expect(posOf('H3588', 'HC'), WordPos.conjunction); // כִּי
    });

    test('Hebrew R is a PREPOSITION and P is a PRONOUN', () {
      expect(posOf('H5921', 'HR'), WordPos.preposition); // עַל
      expect(posOf('H428', 'HPdxcp'), WordPos.pronoun); // אֵלֶּה
    });

    test('article PREFIX: the head is the later segment', () {
      // הַשָּׁמַיִם — Td is the definite article, Ncmpa is the noun the
      // Strong's number names.
      expect(posOf('H8064', 'HTd/Ncmpa'), WordPos.noun);
      expect(posOf('H1419', 'HTd/Aampa'), WordPos.adjective);
    });

    test('article SUFFIX (Aramaic): the head is the earlier segment', () {
      // מַלְכָּא, Daniel. Determined state, article last — the mirror
      // image of the Hebrew case above, which is why neither "first
      // segment" nor "last segment" can be the rule.
      expect(posOf('H4430', 'ANcmsd/Td'), WordPos.noun);
    });

    test('pronominal suffixes are never the head', () {
      // לְמִינוֹ — preposition + noun + 3ms suffix. The suffix is last.
      expect(posOf('H4327', 'HR/Ncmsc/Sp3ms'), WordPos.noun);
      expect(posOf('H3051', 'HVqv2ms/Sh'), WordPos.verb);
      expect(posOf('H4191', 'HVqi2mp/Sn'), WordPos.verb);
      expect(posOf('H4605', 'HR/R/D/Sd'), WordPos.adverb);
    });

    test('all-function chains take the LAST non-suffix segment', () {
      // וְאֵת — conjunction prefix on the object marker. Taking the
      // first segment would call H853 a conjunction.
      expect(posOf('H853', 'HC/To'), WordPos.particle);
      expect(posOf('H853', 'HTo'), WordPos.particle);
      expect(posOf('H996', 'HC/R'), WordPos.preposition); // וּבֵין
      expect(posOf('H3808', 'HC/Tn'), WordPos.particle); // וְלֹא
      expect(posOf('H1931', 'HTd/Pp3fs'), WordPos.pronoun); // הַהִוא
    });

    test('a bare adjective code is not mistaken for Aramaic', () {
      // `A` opens both an Aramaic code and an adjective tag. Stripping
      // it unconditionally would leave `amsa` and lose the word.
      expect(posOf('H2896', 'Aamsa'), WordPos.adjective);
      expect(posOf('H430', 'Ncmpa'), WordPos.noun);
    });
  });

  group('posOf — failure cases', () {
    test('no morphology is unknown, and unknown counts as content', () {
      expect(posOf('G3056', null), WordPos.unknown);
      expect(posOf('G3056', ''), WordPos.unknown);
      expect(kContentPos.contains(WordPos.unknown), isTrue);
    });

    test('no Strong\'s prefix means no scheme to read the code with', () {
      expect(posOf('', 'N-----DSF-'), WordPos.unknown);
      expect(posOf('3056', 'N-----DSF-'), WordPos.unknown);
    });

    test('content and function buckets partition the enum', () {
      expect(kContentPos.intersection(kFunctionPos), isEmpty);
      expect(kContentPos.union(kFunctionPos).length, WordPos.values.length);
    });
  });

  group('pericopeAt', () {
    final john1 = <BookHeading>[
      const BookHeading(chapter: 1, verse: 1, title: 'The Word'),
      const BookHeading(chapter: 1, verse: 19, title: 'John the Baptist'),
      const BookHeading(chapter: 1, verse: 35, title: 'First Disciples'),
      const BookHeading(chapter: 2, verse: 1, title: 'Cana'),
    ];
    const lastVerse = {1: 51, 2: 25};

    test('finds the span a verse falls in', () {
      final p = pericopeAt(
        headings: john1,
        chapter: 1,
        verse: 3,
        lastVerseByChapter: lastVerse,
      )!;
      expect(p.title, 'The Word');
      expect(p.startVerse, 1);
      expect(p.endVerse, 18);
      expect(p.label, '1:1-18');
      expect(p.contains(1, 18), isTrue);
      expect(p.contains(1, 19), isFalse);
    });

    test('a heading verse belongs to its own span, not the previous', () {
      final p = pericopeAt(
        headings: john1,
        chapter: 1,
        verse: 19,
        lastVerseByChapter: lastVerse,
      )!;
      expect(p.title, 'John the Baptist');
      expect(p.startVerse, 19);
      expect(p.endVerse, 34);
    });

    test('a span ending at a chapter boundary runs to the last verse', () {
      // 1:35 → next heading is 2:1, so this ends at 1:51, not at 1:0.
      final p = pericopeAt(
        headings: john1,
        chapter: 1,
        verse: 40,
        lastVerseByChapter: lastVerse,
      )!;
      expect(p.endChapter, 1);
      expect(p.endVerse, 51);
      expect(p.spansChapters, isFalse);
    });

    test('the last span runs to the end of the book', () {
      final p = pericopeAt(
        headings: john1,
        chapter: 2,
        verse: 9,
        lastVerseByChapter: lastVerse,
      )!;
      expect(p.endChapter, 2);
      expect(p.endVerse, 25);
    });

    test('a pericope may cross a chapter boundary', () {
      final headings = <BookHeading>[
        const BookHeading(chapter: 1, verse: 1, title: 'A'),
        const BookHeading(chapter: 2, verse: 5, title: 'B'),
      ];
      final p = pericopeAt(
        headings: headings,
        chapter: 1,
        verse: 30,
        lastVerseByChapter: const {1: 31, 2: 25},
      )!;
      expect(p.spansChapters, isTrue);
      expect(p.endChapter, 2);
      expect(p.endVerse, 4);
      expect(p.label, '1:1-2:4');
      expect(p.contains(2, 4), isTrue);
      expect(p.contains(2, 5), isFalse);
    });

    test('a verse before the first heading opens the book, untitled', () {
      final headings = <BookHeading>[
        const BookHeading(chapter: 1, verse: 5, title: 'Later'),
      ];
      final p = pericopeAt(
        headings: headings,
        chapter: 1,
        verse: 2,
        lastVerseByChapter: const {1: 31},
      )!;
      expect(p.title, isNull);
      expect(p.startChapter, 1);
      expect(p.startVerse, 1);
      expect(p.endVerse, 4);
    });

    test('no headings and no chapter lengths yield nothing', () {
      expect(
        pericopeAt(
          headings: const [],
          chapter: 1,
          verse: 1,
          lastVerseByChapter: const {1: 31},
        ),
        isNull,
      );
      expect(
        pericopeAt(
          headings: [const BookHeading(chapter: 1, verse: 1, title: 'A')],
          chapter: 1,
          verse: 1,
          lastVerseByChapter: const {},
        ),
        isNull,
      );
    });

    test('a gap in the chapter map is walked back over', () {
      // Chapter 2 has no text loaded; a span ending at 3:1 must fall
      // back to the end of chapter 1 rather than key a missing chapter.
      final headings = <BookHeading>[
        const BookHeading(chapter: 1, verse: 1, title: 'A'),
        const BookHeading(chapter: 3, verse: 1, title: 'B'),
      ];
      final p = pericopeAt(
        headings: headings,
        chapter: 1,
        verse: 1,
        lastVerseByChapter: const {1: 31, 3: 24},
      )!;
      expect(p.endChapter, 1);
      expect(p.endVerse, 31);
    });
  });

  group('logLikelihood', () {
    test('a word at the same rate in both corpora is not distinctive', () {
      final g2 = logLikelihood(a: 10, c: 1000, b: 100, d: 10000)!;
      expect(g2, closeTo(0, 1e-9));
    });

    test('over-representation is positive, under-representation negative', () {
      expect(logLikelihood(a: 20, c: 1000, b: 100, d: 10000)!, greaterThan(0));
      expect(logLikelihood(a: 2, c: 1000, b: 100, d: 10000)!, lessThan(0));
    });

    test('the bigger the departure, the bigger the statistic', () {
      final mild = logLikelihood(a: 15, c: 1000, b: 100, d: 10000)!;
      final strong = logLikelihood(a: 40, c: 1000, b: 100, d: 10000)!;
      expect(strong, greaterThan(mild));
    });

    test('empty corpora and absent words have no ratio', () {
      expect(logLikelihood(a: 1, c: 0, b: 1, d: 10), isNull);
      expect(logLikelihood(a: 1, c: 10, b: 1, d: 0), isNull);
      expect(logLikelihood(a: 0, c: 10, b: 0, d: 10), isNull);
    });
  });

  group('buildContextWordList', () {
    // Two occurrences of λόγος in a four-word scope, against a book in
    // which it is otherwise rare.
    final scope = [
      w('λόγος', 'G3056', 'N-----NSM-'),
      w('λόγον', 'G3056', 'N-----ASM-'),
      w('ὁ', 'G3588', 'RA----NSM-'),
      w('καί', 'G2532', 'C---------'),
    ];
    final book = [
      ...scope,
      for (var i = 0; i < 40; i++) w('ὁ', 'G3588', 'RA----NSM-'),
      for (var i = 0; i < 30; i++) w('καί', 'G2532', 'C---------'),
      for (var i = 0; i < 8; i++) w('θεός', 'G2316', 'N-----NSM-'),
    ];

    test('counts by Strong\'s, and prints the commonest surface form', () {
      final list = buildContextWordList(scopeWords: scope, bookWords: book);
      final logos = list.entries.singleWhere((e) => e.strongs == 'G3056');
      expect(logos.count, 2);
      expect(logos.bookCount, 2);
      // Both forms occur once; the tie resolves to the first seen so the
      // list is stable between rebuilds.
      expect(logos.form, 'λόγος');
    });

    test('the default filter drops the article and the conjunction', () {
      final list = buildContextWordList(scopeWords: scope, bookWords: book);
      expect(list.entries.map((e) => e.strongs), ['G3056']);
      // …but the corpus size is unfiltered: keyness must not move when
      // the reader toggles the filter.
      expect(list.scopeTokens, 4);
      expect(list.scopeDistinct, 3);
    });

    test('function words come back when asked for', () {
      final list = buildContextWordList(
        scopeWords: scope,
        bookWords: book,
        include: {...kContentPos, ...kFunctionPos},
      );
      expect(list.entries.length, 3);
    });

    test('a word confined to the scope is marked exclusive', () {
      final list = buildContextWordList(scopeWords: scope, bookWords: book);
      final logos = list.entries.single;
      expect(logos.isExclusive, isTrue);
      expect(logos.keyness, isNotNull);
      expect(logos.keyness, greaterThan(0));
    });

    test('scope == book leaves no baseline, so keyness is null', () {
      final list = buildContextWordList(scopeWords: book, bookWords: book);
      expect(list.hasBaseline, isFalse);
      expect(list.entries.every((e) => e.keyness == null), isTrue);
    });

    test('an empty scope is not a crash', () {
      final list = buildContextWordList(scopeWords: const [], bookWords: book);
      expect(list.entries, isEmpty);
      expect(list.scopeTokens, 0);
      expect(list.hasBaseline, isFalse);
    });

    test('untagged words are skipped — no identity, nothing to look up', () {
      final list = buildContextWordList(
        scopeWords: [w('—', ''), ...scope],
        bookWords: book,
      );
      expect(list.scopeTokens, 4);
    });

    test('frequency and rarity are opposite ends of the same list', () {
      final byFreq = buildContextWordList(
        scopeWords: scope,
        bookWords: book,
        include: {...kContentPos, ...kFunctionPos},
        sort: ContextSort.frequency,
      ).entries;
      final byRare = buildContextWordList(
        scopeWords: scope,
        bookWords: book,
        include: {...kContentPos, ...kFunctionPos},
        sort: ContextSort.rarity,
      ).entries;
      expect(byFreq.first.strongs, 'G3056');
      expect(byRare.last.strongs, 'G3056');
    });

    test('distinctive ranks the local word above the frequent one', () {
      // ὁ occurs 41× in the book and once here; λόγος occurs twice, both
      // here. Frequency ranks ὁ nowhere near the top of the scope, but
      // this is the case the sort exists for: a raw list of a longer
      // scope would bury λόγος under the article.
      final list = buildContextWordList(
        scopeWords: [...scope, w('ὁ', 'G3588', 'RA----NSM-')],
        bookWords: book,
        include: {...kContentPos, ...kFunctionPos},
        sort: ContextSort.distinctive,
      ).entries;
      expect(list.first.strongs, 'G3056');
      expect(list.map((e) => e.strongs), contains('G3588'));
      expect(
        list.singleWhere((e) => e.strongs == 'G3588').keyness,
        lessThan(list.first.keyness!),
      );
    });

    test('unmeasurable rows sink under distinctive, they do not sort as 0', () {
      final entries = [
        const ContextWordEntry(
          strongs: 'G1',
          form: 'a',
          pos: WordPos.noun,
          count: 1,
          bookCount: 1,
          keyness: null,
        ),
        const ContextWordEntry(
          strongs: 'G2',
          form: 'b',
          pos: WordPos.noun,
          count: 1,
          bookCount: 1,
          keyness: -5,
        ),
      ];
      sortContextWords(entries, ContextSort.distinctive);
      expect(entries.first.strongs, 'G2');
    });
  });

  // Rendered against the real assets, at both ends of the width the
  // Analysis pane is actually given. The controls row carries a
  // three-way SegmentedButton, three sort chips and a filter switch, and
  // 320 px is where that either wraps or overflows.
  group('ContextPane renders at the pane widths', () {
    Widget host(double width) => _settingsHost(MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: const ContextPane(
                englishBook: 'John',
                chapter: 1,
                verse: 1,
                locale: 'en',
                version: 'kjv',
                onOpenVerse: _ignoreVerse,
              ),
            ),
          ),
        ));

    for (final width in const [320.0, 560.0]) {
      testWidgets('no overflow at ${width.toInt()} px', (tester) async {
        // `runAsync`, not `pumpAndSettle`: the pane reads the originals,
        // the outline and the lexicon off the real asset bundle, and its
        // spinner would keep a settle pumping until it timed out.
        await tester.runAsync(() async {
          await tester.pumpWidget(host(width));
          for (var i = 0; i < 40; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            await tester.pump();
            if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
              break;
            }
          }
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // The pericope is read off the outline as a RANGE, which is the
        // one scope the shipped Word List Manager cannot express.
        expect(find.textContaining('1:1-18'), findsOneWidget);
        expect(find.textContaining('83 distinct'), findsOneWidget);
        // And the head of the list is the prologue's own vocabulary
        // rather than ὁ / καί / αὐτοῦ, which is the entire point.
        expect(find.text('χάρις'), findsOneWidget);
        expect(find.text('μονογενής'), findsOneWidget);
        expect(find.text('ὁ'), findsNothing);
      });
    }
  });

  // The eleventh tab is what forced this: eleven bare icons no longer
  // fit across a 320 px Analysis pane, and the strip used to answer
  // that by clipping them. It now wraps to a second row.
  group('AnalysisTabStrip at a full strip', () {
    Widget host(double width) => _settingsHost(MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: Column(
                children: [
                  AnalysisTabStrip(
                    current: AnalysisTab.context,
                    onChanged: (_) {},
                    locale: 'en',
                  ),
                ],
              ),
            ),
          ),
        ));

    testWidgets(
        'wraps rather than clipping at 320 px, and every tab is '
        'still reachable', (tester) async {
      await tester.pumpWidget(host(320));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Every tab is laid out — a scrolling strip would have hidden the
      // ones past the fold, and the selected tab is the last of them.
      expect(find.byType(Tooltip), findsNWidgets(AnalysisTab.values.length));
      expect(find.byIcon(Icons.segment_rounded), findsOneWidget);
      expect(find.text('Context'), findsNothing);
      final rows = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((t) => tester.getTopLeft(find.byWidget(t)).dy)
          .toSet();
      expect(rows, hasLength(2));
    });

    testWidgets('stays on one row when there is room for one', (tester) async {
      // Room for one row is a MEASUREMENT, not a constant: it depends
      // on the locale's widest label and on the font in use, and the
      // test font is not the shipping one (task #297). A hard-coded
      // width here silently tested a strip too narrow for its own
      // labels and asserted about the wrong thing.
      final wide = analysisStripMinLabelledWidth(analysisTabLabels('en')) *
              AnalysisTab.values.length +
          16 +
          8;
      // The test surface would otherwise clamp the SizedBox and the
      // assertion would again be about a width nobody asked for.
      tester.view.physicalSize = Size(wide + 200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(wide));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Context'), findsOneWidget);
      final rows = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((t) => tester.getTopLeft(find.byWidget(t)).dy)
          .toSet();
      expect(rows, hasLength(1));
    });
  });
}
