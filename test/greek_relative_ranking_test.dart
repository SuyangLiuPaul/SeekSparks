/// What the Eagle's View per-book pair actually is, and the labels that
/// have to keep it straight.
///
/// The asset stores `"Revelation": [3, 6]` for βδέλυγμα. From 2026-08-07
/// the Stats pane rendered that as `Rev 3 ·#6` — "third commonest in
/// Revelation, ranked sixth" — and the second half was never true. The
/// word ranks 343rd of Revelation's 907. 6 is its 3 occurrences rescaled
/// to Luke's length, because Luke is 2.0 times the length of Revelation.
///
/// Every assertion below is against the REAL asset, and the numbers were
/// established from the asset before any of this was written, not read
/// off the code. The three that settle it are stated as tests rather
/// than as a comment:
///
///   1. in Luke the two figures are IDENTICAL for every word, which no
///      rank could be — Luke is the baseline, so the scale factor is 1;
///   2. outside Luke the scaled figure routinely exceeds the number of
///      distinct words in the book (ἀγάπη scores 171 in a Philemon with
///      140 distinct words), which no rank could be either;
///   3. the real rank, computed here from the counts, disagrees with it
///      by two orders of magnitude.
///
/// Anything that swaps the two — a `$1` for a `$2`, a sort key, a
/// heading — moves at least one of those three.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/greek_stats_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/greek_relative_ranking.dart';

/// βδέλυγμα — 6 occurrences, three of them in Revelation. The word the
/// service's own doc comment has used as its example since the import,
/// and the one the false rank was most visible on.
const String kBdelugma = 'G946';

/// ἀγάπη — spread over 24 books, so the two orders have room to
/// disagree with each other.
const String kAgape = 'G26';

/// καί — 8,970 occurrences. In Luke, where the scale factor is 1.
const String kKai = 'G2532';

/// Ἀβαδδών — a hapax legomenon, in Revelation, and Johannine.
const String kAbaddon = 'G3';

/// שָׁמַיִם — Hebrew, so the Westcott-Hort profile is silent and right.
const String kShamayim = 'H8064';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GreekWordStats agape;

  setUpAll(() async {
    // `testWidgets` runs in a fake-async zone where real bundle I/O
    // never completes, so every cache a pumped widget will await is
    // filled here first.
    await GreekStatsService.books();
    await GreekStatsService.lukeRunningWords();
    await GreekStatsService.lengthRatioVsLuke('John');
    await GreekStatsService.rankingIn('John');
    await GreekStatsService.rankingIn('Luke');
    await GreekStatsService.rankingIn('Revelation');
    agape = (await GreekStatsService.lookup(kAgape))!;
    await ConcordanceService.lookup(kAgape);
    await ConcordanceService.lookup(kShamayim);
    await StrongsService.lookup(kAgape);
    await StrongsService.lookup(kShamayim);
  });

  group('the second figure in each book pair is a scaled count', () {
    test('in Luke it equals the raw count, which no rank could', () async {
      final kai = (await GreekStatsService.lookup(kKai))!;
      final luke = kai.books['Luke']!;
      expect(luke.count, 1463);
      expect(luke.scaledToLuke, 1463,
          reason: 'Luke is the baseline, so its scale factor is 1');

      // The same word in a book that is not the baseline, to show the
      // figure moves with length rather than with position.
      final revelation = kai.books['Revelation']!;
      expect(revelation.count, 1119);
      expect(revelation.scaledToLuke, 2238,
          reason: 'Luke is about twice the length of Revelation, so the '
              'same 1,119 occurrences score 2,238 against the baseline');
    });

    test('it can exceed the book\'s entire vocabulary', () {
      // Philemon has 140 distinct words in this profile. A rank of 171
      // in a 140-word book is not a rank.
      expect(agape.books['Philemon']!.count, 3);
      expect(agape.books['Philemon']!.scaledToLuke, 171);
    });

    test('the real rank disagrees with it by two orders of magnitude',
        () async {
      final bdelugma = (await GreekStatsService.lookup(kBdelugma))!;
      final inRevelation = bdelugma.books['Revelation']!;
      expect(inRevelation.count, 3);
      expect(inRevelation.scaledToLuke, 6);

      final ranking = (await GreekStatsService.rankingIn('Revelation'))!;
      expect(ranking.rankOf(kBdelugma), 343);
      expect(ranking.rankedWords, 907);
      expect(ranking.rankOf(kBdelugma), isNot(inRevelation.scaledToLuke),
          reason: 'the pane printed the scaled count AS the rank');
    });
  });

  group('the two orders are different orders', () {
    // The swap guard. Sorting `byDensity` on the raw count — the
    // one-character mistake — makes these two lists identical, and this
    // is the assertion that notices.
    test('the commonest book and the densest book are not the same book',
        () {
      expect(agape.byFrequency.first.key, '1 John');
      expect(agape.byDensity.first.key, 'Philemon');
    });

    test('by raw count 1 John leads; scaled to Luke, Philemon does', () {
      expect(
        [for (final e in agape.byFrequency.take(3)) e.key],
        ['1 John', '1 Corinthians', 'Romans'],
      );
      expect(
        [for (final e in agape.byDensity.take(3)) e.key],
        ['Philemon', '1 John', '2 John'],
      );
      // Philemon's 3 occurrences against 1 Corinthians' 13: the whole
      // point of normalising, in one comparison.
      expect(agape.books['Philemon']!.count,
          lessThan(agape.books['1 Corinthians']!.count));
      expect(agape.books['Philemon']!.scaledToLuke,
          greaterThan(agape.books['1 Corinthians']!.scaledToLuke!));
    });
  });

  group('a rank is computed, and carries its population', () {
    test('kai is the second commonest word in Luke', () async {
      final ranking = (await GreekStatsService.rankingIn('Luke'))!;
      expect(ranking.rankOf(kKai), 2, reason: 'only the article is above it');
      expect(ranking.rankedWords, 2033);
    });

    test('a hapax ranks low and is still ranked', () async {
      final ranking = (await GreekStatsService.rankingIn('Revelation'))!;
      expect(ranking.rankOf(kAbaddon), 604);
      final abaddon = (await GreekStatsService.lookup(kAbaddon))!;
      expect(abaddon.nt, 1);
      expect(abaddon.books.keys, ['Revelation']);
      expect(abaddon.books['Revelation'], (1, 2));
    });

    test('a word absent from the book has no rank there', () async {
      final ranking = (await GreekStatsService.rankingIn('Luke'))!;
      expect(ranking.rankOf(kAbaddon), isNull);
    });
  });

  group('the baseline is available to be printed', () {
    test('Luke is 19,457 running words and its own ratio is 1', () async {
      expect(await GreekStatsService.lukeRunningWords(), 19457);
      expect(await GreekStatsService.lengthRatioVsLuke('Luke'), 1);
      expect(await GreekStatsService.lengthRatioVsLuke('Jude'), 42.7);
    });
  });

  group('the four author totals overlap and must say so', () {
    test('they add up to more than the New Testament total', () {
      expect(agape.totals['gospelsActs'], 9);
      expect(agape.totals['paul'], 73);
      expect(agape.totals['john'], 30);
      expect(agape.totals['otherAuthors'], 9);
      expect(agape.nt, 114);
      // 121, because the Fourth Gospel is inside both `gospelsActs`
      // and `john`.
      expect(9 + 73 + 30 + 9, greaterThan(agape.nt));
    });
  });

  // Recorded rather than assumed: the importer reads `R(A)` and `R(R)`
  // and both columns export blank, so the corpus-wide ranks the source
  // program had are simply not in the asset. If a re-import ever fills
  // them this fails, which is the point — a new field should be noticed
  // and given a label, not silently rendered.
  test('the asset carries no corpus-wide rank for any word', () async {
    for (final s in [kAgape, kKai, kBdelugma, kAbaddon]) {
      expect((await GreekStatsService.lookup(s))!.ranks, isEmpty);
    }
  });

  group('there is no Hebrew equivalent, and nothing pretends otherwise',
      () {
    test('a Hebrew number, an Old Testament book and a typo all return null',
        () async {
      expect(await GreekStatsService.lookup(kShamayim), isNull);
      expect(await GreekStatsService.lookup('H430'), isNull);
      expect(await GreekStatsService.rankingIn('Genesis'), isNull);
      expect(await GreekStatsService.lengthRatioVsLuke('Genesis'), isNull);
      expect(await GreekStatsService.rankingIn('Luke of Acts'), isNull);
    });
  });

  group('the pane', () {
    Widget host(Widget child) => ChangeNotifierProvider(
          create: (_) => AppSettings(),
          child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
        );

    testWidgets('collapsed, it prints counts and no rank sign', (t) async {
      await t.pumpWidget(host(
        GreekRelativeRanking(stats: agape, locale: 'en', currentBook: 'John'),
      ));
      await t.pumpAndSettle();

      expect(find.text('1Jo 18'), findsOneWidget);
      expect(find.textContaining('#'), findsNothing,
          reason: 'the old chip read "1Jo 18 ·#164" and 164 was not a rank');
      expect(find.textContaining('Scaled'), findsNothing,
          reason: 'the scaled order costs a corpus load and is opt-in');
    });

    testWidgets('expanded, each order is under its own heading', (t) async {
      await t.pumpWidget(host(
        GreekRelativeRanking(stats: agape, locale: 'en', currentBook: 'John'),
      ));
      await t.pumpAndSettle();
      await t.tap(find.text('Relative ranking'));
      await t.pumpAndSettle();

      expect(find.text('Times it occurs'), findsOneWidget);
      expect(find.text("Scaled to Luke's length"), findsOneWidget);
      // The scaled figures wear a mark the raw counts do not, so the
      // two are still distinguishable if the headings scroll away.
      // `findRichText` because each figure is a two-span line: the book
      // in body colour, the number in the colour of its own order.
      expect(find.textContaining('≈171', findRichText: true), findsOneWidget);
      expect(find.textContaining('1Jo 18', findRichText: true),
          findsWidgets,
          reason: 'the same word under the raw heading, unmarked');
    });

    testWidgets('expanded, it names the baseline and the book it is reading',
        (t) async {
      await t.pumpWidget(host(
        GreekRelativeRanking(stats: agape, locale: 'en', currentBook: 'John'),
      ));
      await t.pumpAndSettle();
      await t.tap(find.text('Relative ranking'));
      await t.pumpAndSettle();

      expect(find.textContaining('Baseline: Luke, 19457'), findsOneWidget);
      expect(find.textContaining('about 1.2× the length of John'),
          findsOneWidget);
      expect(find.textContaining('#245 of 1014 words'), findsOneWidget,
          reason: 'ἀγάπη is the 245th commonest of the 1,014 words John uses');
    });

    testWidgets('expanded, all four author totals show, zeros included',
        (t) async {
      final bdelugma = (await GreekStatsService.lookup(kBdelugma))!;
      await t.pumpWidget(host(GreekRelativeRanking(
          stats: bdelugma, locale: 'en', currentBook: 'Revelation')));
      await t.pumpAndSettle();
      await t.tap(find.text('Relative ranking'));
      await t.pumpAndSettle();

      // βδέλυγμα is absent from Paul entirely, and that IS the fact.
      expect(find.textContaining('Paul 0'), findsOneWidget);
      expect(find.textContaining('do not add up to the 6'), findsOneWidget);
    });

    testWidgets('an Old Testament verse says the corpus stops at the NT',
        (t) async {
      await t.pumpWidget(host(
        const SizedBox(),
      ));
      await t.pumpWidget(ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            body: WordStatsPane(
              words: const [OriginalWord(text: 'שָׁמַיִם', strongs: kShamayim)],
              locale: 'en',
              onOpenStrongs: (_) {},
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();

      expect(find.textContaining('no Hebrew equivalent'), findsOneWidget);
    });

    testWidgets('a Greek verse gets the ranking, not the Hebrew note',
        (t) async {
      await t.pumpWidget(ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            body: WordStatsPane(
              words: const [OriginalWord(text: 'ἀγάπη', strongs: kAgape)],
              locale: 'en',
              onOpenStrongs: (_) {},
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();

      expect(find.textContaining('no Hebrew equivalent'), findsNothing);
      expect(find.text('Relative ranking'), findsOneWidget);
    });
  });
}
