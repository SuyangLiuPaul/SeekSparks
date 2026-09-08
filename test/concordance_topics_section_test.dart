/// The Modern Concordance block on a Strong's entry, as a reader sees it.
///
/// `concordance_reverse_index_test.dart` proves the relation is read
/// correctly off the asset. Nothing there can tell you the difference
/// between "same sense" and "same word family" survives to the screen,
/// which is the only reason the distinction is worth deriving — nor that
/// the credit the data ships under is actually drawn.
///
/// Built against literal filings rather than the real asset on purpose:
/// the two tests answer different questions, and a widget test that also
/// loads 341 files would fail for reasons that have nothing to do with
/// the widget.
///
/// Asserted in CHINESE first, as `modern_concordance_page_test.dart` is
/// and for the same reason: `AppSettings` defaults to zh-Hans, so that
/// is what a default reader sees, and an English-only assertion would
/// never touch the strings most likely to be wrong.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/concordance_reverse_index.dart';
import 'package:seeksparks/widgets/concordance_topics_section.dart';

const _attribution = "Eagle's View (eaglesviewsoftware.com), following "
    'Modern Concordance to the New Testament '
    '(Darton, Longman & Todd, 1976). Used by permission.';

ConcordanceFiling filing({
  List<ConcordanceNeighbour> neighbours = const [],
  int occurrences = 6,
}) =>
    ConcordanceFiling(
      topicId: 1,
      topicEn: 'Abomination',
      topicZh: '亵渎',
      sectionId: 1,
      sectionEn: 'Abomination: BDELUGMA',
      sectionZh: '亵渎：BDELUGMA',
      headings: const [('Abomination = Sacrilege', '亵渎 = 可憎')],
      occurrences: occurrences,
      neighbours: neighbours,
    );

ConcordanceNeighbour sense(String g) =>
    ConcordanceNeighbour(strongs: g, relation: ConcordanceRelation.sameSense);

ConcordanceNeighbour family(String g) =>
    ConcordanceNeighbour(strongs: g, relation: ConcordanceRelation.sameFamily);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final opened = <int>[];

  Widget host(
    List<ConcordanceFiling> filings, {
    String locale = 'zh-Hans',
    Widget? Function(String)? chipFor,
    int maxNeighbours = 12,
  }) =>
      ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConcordanceTopicsSection(
                title: const Text('现代汇编主题'),
                filings: filings,
                attribution: _attribution,
                locale: locale,
                chipFor: chipFor ?? (_) => null,
                onOpenTopic: opened.add,
                maxNeighbours: maxNeighbours,
              ),
            ),
          ),
        ),
      );

  testWidgets('a Chinese reader gets the topic, the section and both '
      'relation labels in Chinese', (tester) async {
    await tester.pumpWidget(host([
      filing(neighbours: [sense('G947'), family('G4021')]),
    ]));
    await tester.pump();

    expect(find.text('亵渎'), findsOneWidget);
    expect(find.text('亵渎：BDELUGMA'), findsOneWidget);
    expect(find.text('亵渎 = 可憎'), findsOneWidget);
    expect(find.text('同一义项'), findsOneWidget);
    expect(find.text('同一词族'), findsOneWidget);
  });

  testWidgets('the same block in English names the same two relations',
      (tester) async {
    await tester.pumpWidget(host([
      filing(neighbours: [sense('G947'), family('G4021')]),
    ], locale: 'en'));
    await tester.pump();

    expect(find.text('Abomination'), findsOneWidget);
    expect(find.text('Same sense'), findsOneWidget);
    expect(find.text('Same word family'), findsOneWidget);
  });

  testWidgets('a relation with no neighbours is absent, not an empty '
      'heading', (tester) async {
    await tester.pumpWidget(host([filing(neighbours: [sense('G947')])]));
    await tester.pump();

    expect(find.text('同一义项'), findsOneWidget);
    expect(find.text('同一词族'), findsNothing);
  });

  testWidgets('the credit the data ships under is drawn verbatim',
      (tester) async {
    await tester.pumpWidget(host([filing()]));
    await tester.pump();
    expect(find.text(_attribution), findsOneWidget);
  });

  testWidgets('nothing on screen calls this a semantic-domain lexicon',
      (tester) async {
    // The gap this feature was mistaken for is Louw-Nida, which is under
    // a licence this app does not hold. The wording rule is only real if
    // something checks the WORDS, and the words are what is rendered —
    // not what the source file says about them.
    await tester.pumpWidget(host([
      filing(neighbours: [sense('G947'), family('G4021')]),
    ], locale: 'en'));
    await tester.pump();
    await tester.pumpWidget(host([
      filing(neighbours: [sense('G947'), family('G4021')]),
    ]));
    await tester.pump();

    final onScreen = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .join('\n');
    for (final claim in const [
      'louw',
      'nida',
      'semantic domain',
      'semantic-domain',
      '语义域',
      '語義域',
    ]) {
      expect(onScreen.contains(claim), isFalse, reason: 'said "$claim"');
    }
  });

  testWidgets('a section with more neighbours than fit says how many were '
      'left off', (tester) async {
    await tester.pumpWidget(host([
      filing(neighbours: [for (var i = 1; i <= 15; i++) sense('G$i')]),
    ], maxNeighbours: 12));
    await tester.pump();

    expect(find.text('G12'), findsOneWidget);
    expect(find.text('G13'), findsNothing);
    expect(find.text('… +3'), findsOneWidget);
  });

  testWidgets('a neighbour the lexicon cannot open is still named',
      (tester) async {
    // Dropping it would make the concordance look like it files fewer
    // words than it does.
    await tester.pumpWidget(host([filing(neighbours: [sense('G947')])]));
    await tester.pump();
    expect(find.text('G947'), findsOneWidget);
  });

  testWidgets('the page\'s own chip is used when the lexicon has the word',
      (tester) async {
    await tester.pumpWidget(host(
      [filing(neighbours: [sense('G947')])],
      chipFor: (g) => Text('chip:$g'),
    ));
    await tester.pump();
    expect(find.text('chip:G947'), findsOneWidget);
    expect(find.text('G947'), findsNothing);
  });

  testWidgets('tapping the topic opens that topic', (tester) async {
    opened.clear();
    await tester.pumpWidget(host([filing()]));
    await tester.pump();
    await tester.tap(find.text('亵渎'));
    expect(opened, [1]);
  });

  testWidgets('a word the concordance does not file draws nothing at all',
      (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pump();
    expect(find.text(_attribution), findsNothing);
    expect(find.text('现代汇编主题'), findsNothing);
  });
}
