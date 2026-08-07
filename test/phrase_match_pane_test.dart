import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/phrase_match_pane.dart';

/// Isaiah 7:14 and the verse that quotes it, plus a verse that shares
/// vocabulary but no phrase, plus filler.
///
/// The filler is not decoration. `defaultEnabledPhrases` unchecks any
/// phrase found in more than 1% of what was scanned, with a floor of 3
/// verses, so a four-verse corpus would behave nothing like a Bible.
List<Verse> _corpusVerses() => [
      const Verse(
          book: 'Isaiah',
          chapter: 7,
          verse: 14,
          text: 'Behold, a virgin shall conceive, and bear a son, and '
              'shall call his name Immanuel.'),
      const Verse(
          book: 'Matthew',
          chapter: 1,
          verse: 23,
          text: 'Behold, a virgin shall be with child, and shall bring '
              'forth a son, and they shall call his name Emmanuel.'),
      // Every content word of the base verse, none of its phrases. This
      // is the verse a bag-of-words tool returns and a phrase tool must
      // not — the whole reason bwh51 exists beside bwh50.
      const Verse(
          book: 'Psalms',
          chapter: 99,
          verse: 1,
          text: 'His name is a son; conceive the virgin, and bear, and '
              'behold, they shall call.'),
      for (var i = 0; i < 60; i++)
        Verse(
          book: 'Proverbs',
          chapter: 1 + i ~/ 20,
          verse: 1 + i % 20,
          text: 'A wise son heareth instruction number$i but a scorner '
              'heareth not rebuke',
        ),
    ];

Widget _host(Widget child, {double width = 320}) => ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, height: 640, child: child),
          ),
        ),
      ),
    );

PhraseMatchPane _pane(
  List<Verse> verses, {
  Set<int>? scope,
  String? scopeLabel,
  void Function(Verse)? onOpenVerse,
}) =>
    PhraseMatchPane(
      corpus: [for (final v in verses) v.text],
      verses: verses,
      baseIndex: 0,
      locale: 'en',
      scope: scope,
      scopeLabel: scopeLabel,
      onOpenVerse: onOpenVerse,
    );

/// The phrase list is bounded and scrolls inside itself, so a chip can
/// be present but out of view. Scroll it in before tapping.
///
/// A missing chip is a failure, not a skip: a chip label is the raw
/// slice of the base verse, punctuation and capitals intact, and
/// quietly skipping the ones that did not match made a test pass while
/// tapping nothing at all.
Future<void> _tapChip(WidgetTester tester, String label) async {
  final chip = find.text(label);
  expect(chip, findsWidgets, reason: 'no phrase chip "$label"');
  await tester.ensureVisible(chip.first);
  await tester.pumpAndSettle();
  await tester.tap(chip.first);
  await tester.pumpAndSettle();
}

/// The `[n]` a result row prints — the first Text in the row.
int _rowCount(WidgetTester tester, String ref) {
  final row =
      find.ancestor(of: find.text(ref), matching: find.byType(Row)).first;
  final text = tester
      .widget<Text>(find.descendant(of: row, matching: find.byType(Text)).first);
  return int.parse(text.data!.replaceAll(RegExp(r'[^0-9]'), ''));
}

void main() {
  group('PhraseMatchPane', () {
    testWidgets('finds the quotation and not the vocabulary lookalike',
        (tester) async {
      final verses = _corpusVerses();
      await tester.pumpWidget(_host(_pane(verses)));
      await tester.pumpAndSettle();

      expect(find.text('Mat 1:23'), findsOneWidget);
      expect(find.text('Ps 99:1'), findsNothing);
    });

    testWidgets('unchecking every phrase empties the results',
        (tester) async {
      final verses = _corpusVerses();
      await tester.pumpWidget(_host(_pane(verses)));
      await tester.pumpAndSettle();
      expect(find.text('Mat 1:23'), findsOneWidget);

      // Chip labels are the base verse's own text, commas and all.
      for (final label in const [
        'Behold, a virgin',
        'a virgin shall',
        'a son, and',
        'shall call his',
        'call his name',
      ]) {
        await _tapChip(tester, label);
      }
      expect(find.text('Mat 1:23'), findsNothing);
      expect(find.textContaining('No other verse repeats'), findsOneWidget);
    });

    testWidgets('tapping a hit opens its text inline rather than navigating',
        (tester) async {
      final verses = _corpusVerses();
      Verse? opened;
      await tester.pumpWidget(
          _host(_pane(verses, onOpenVerse: (v) => opened = v)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mat 1:23'));
      await tester.pumpAndSettle();
      expect(opened, isNull);
      expect(find.textContaining('bring forth a son', findRichText: true),
          findsOneWidget);
    });

    testWidgets('the arrow navigates, and the row tap did not', (tester) async {
      final verses = _corpusVerses();
      Verse? opened;
      await tester.pumpWidget(
          _host(_pane(verses, onOpenVerse: (v) => opened = v)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_forward).first);
      await tester.pumpAndSettle();
      expect(opened?.book, 'Matthew');
    });

    testWidgets('widening the gap finds a match that exact matching missed',
        (tester) async {
      final verses = _corpusVerses();
      await tester.pumpWidget(_host(_pane(verses)));
      await tester.pumpAndSettle();

      // "and shall call" is not in Matthew, which reads "and they shall
      // call". One inserted word is exactly what the gap is for, so
      // Matthew must come back carrying strictly more phrases.
      final before = _rowCount(tester, 'Mat 1:23');

      // Two steppers in tree order: Len, then Gap.
      await tester.tap(find.byIcon(Icons.add).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Mat 1:23'), findsOneWidget);
      expect(_rowCount(tester, 'Mat 1:23'), greaterThan(before));
    });

    testWidgets('the phrase view is a different shape, not a re-sort',
        (tester) async {
      final verses = _corpusVerses();
      await tester.pumpWidget(_host(_pane(verses), width: 560));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Phrase'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Phrase bands carry the phrase and its total, with verses under.
      expect(find.textContaining('· '), findsWidgets);
      expect(find.text('Mat 1:23'), findsWidgets);
    });

    testWidgets('the scope chip appears only when there is a limit',
        (tester) async {
      final verses = _corpusVerses();
      await tester.pumpWidget(_host(_pane(verses), width: 560));
      await tester.pumpAndSettle();
      expect(find.text('Psalms only'), findsNothing);

      // Limited to a range that excludes Matthew: the quotation must go.
      await tester.pumpWidget(_host(
        _pane(verses, scope: const {2}, scopeLabel: 'Psalms only'),
        width: 560,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Psalms only'), findsOneWidget);
      expect(find.text('Mat 1:23'), findsNothing);
    });

    testWidgets('turning the scope chip off restores the whole Bible',
        (tester) async {
      final verses = _corpusVerses();
      await tester.pumpWidget(_host(
        _pane(verses, scope: const {2}, scopeLabel: 'Psalms only'),
        width: 560,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Mat 1:23'), findsNothing);

      await tester.tap(find.text('Psalms only'));
      await tester.pumpAndSettle();
      expect(find.text('Mat 1:23'), findsOneWidget);
    });

    testWidgets('renders without overflow at 320 and 560', (tester) async {
      final verses = _corpusVerses();
      for (final w in const [320.0, 560.0]) {
        await tester.pumpWidget(_host(_pane(verses), width: w));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'at $w px');
      }
    });

    testWidgets('a verse shorter than the phrase length says so',
        (tester) async {
      const verses = [
        Verse(book: 'John', chapter: 11, verse: 35, text: 'Jesus wept.'),
        Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'and the earth'),
      ];
      await tester.pumpWidget(_host(PhraseMatchPane(
        corpus: [for (final v in verses) v.text],
        verses: verses,
        baseIndex: 0,
        locale: 'en',
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('shorter than the phrase length'),
          findsOneWidget);
    });

    testWidgets('the phrase list collapses to make room for results',
        (tester) async {
      final verses = _corpusVerses();
      await tester.pumpWidget(_host(_pane(verses)));
      await tester.pumpAndSettle();
      expect(find.text('call his name'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();
      expect(find.text('call his name'), findsNothing);
      expect(find.text('Mat 1:23'), findsOneWidget);
    });
  });

  group('AnalysisTabStrip with the seventh tab', () {
    testWidgets('seven tabs fit at 320 px by dropping their labels',
        (tester) async {
      await tester.pumpWidget(_host(
        Column(children: [
          AnalysisTabStrip(
            current: AnalysisTab.phrases,
            onChanged: (_) {},
            locale: 'en',
          ),
        ]),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Phrases'), findsNothing);
      expect(find.byIcon(Icons.format_quote_rounded), findsOneWidget);
    });

    testWidgets('labels come back when there is room', (tester) async {
      await tester.pumpWidget(_host(
        Column(children: [
          AnalysisTabStrip(
            current: AnalysisTab.phrases,
            onChanged: (_) {},
            locale: 'en',
          ),
        ]),
        // A labelled tab needs 66 px and there are now nine of them,
        // so the threshold is 594 — it moves every time a tab is added.
        width: 620,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Phrases'), findsOneWidget);
    });

    testWidgets('the tab keeps its index, so persisted ones still resolve',
        (tester) async {
      // The tab is stored by index. Anything but "appended" silently
      // moves every existing reader to a different tab.
      //
      // Pinning the INDEX rather than `values.last`: lastness is not the
      // invariant, and asserting it broke the moment bwh40 was appended
      // — which is the one operation this test exists to bless.
      expect(AnalysisTab.values.indexOf(AnalysisTab.phrases), 6);
      expect(AnalysisTab.values.indexOf(AnalysisTab.wordStudy), 0);
      expect(AnalysisTab.values.indexOf(AnalysisTab.verseLists), 5);
    });
  });
}
