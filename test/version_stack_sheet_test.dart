// 2026-08-08 (task #288): the version picker's contract.
//
// Two things the pure model cannot pin. First, the sheet is STAGED, so
// null means CANCEL — the old checkbox list applied on DISMISS and had
// no other way to apply, which meant there was no way to back out of an
// edit at all. Second, the reading version is drawn but inert: it has no
// drag handle and no remove button, because it is column one by
// definition and the command line refuses to remove it too.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/widgets/version_stack_sheet.dart';

class _Outcome {
  List<String>? versions;
  bool returned = false;
}

Future<_Outcome> _openSheet(
  WidgetTester tester, {
  String reading = 'kjv',
  List<String> comparisons = const [],
  String locale = 'en',
}) async {
  final outcome = _Outcome();
  // Tall enough that the whole sheet is on screen. The sheet caps at 78%
  // of the viewport, and at the 600x800 default the Greek group scrolls
  // out of the tree — which would make "is this row present" a test of
  // the scroll offset instead of the feature.
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(
        theme: workbenchTheme(ThemeData.light(useMaterial3: true)),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  outcome.versions = await showVersionStackSheet(
                    context: context,
                    locale: locale,
                    reading: reading,
                    comparisons: comparisons,
                  );
                  outcome.returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      )));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return outcome;
}

/// The order the sheet is currently PAINTING, read off the rows' screen
/// positions rather than off the draft list. Reading the model back
/// would pass even if the list rendered in some other order, and "what
/// is on screen is what gets applied" is the whole claim.
List<String> _shownOrder(WidgetTester tester) {
  const prefix = 'version-stack-';
  final rows = <(double, String)>[];
  final finder = find.byWidgetPredicate((w) {
    final key = w.key;
    if (key is! ValueKey<String>) return false;
    final v = key.value;
    return v.startsWith(prefix) &&
        v != '${prefix}reading' &&
        !v.startsWith('${prefix}available-');
  });
  for (final element in finder.evaluate()) {
    final key = element.widget.key! as ValueKey<String>;
    rows.add((
      tester.getTopLeft(find.byKey(key).first).dy,
      key.value.substring(prefix.length),
    ));
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final r in rows) r.$2];
}

void main() {
  testWidgets('dismissing is a CANCEL — the stack is untouched',
      (tester) async {
    final outcome =
        await _openSheet(tester, comparisons: ['bsb', 'lxxwh']);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(outcome.returned, isTrue);
    expect(outcome.versions, isNull);
  });

  testWidgets('Apply hands back the drafted order', (tester) async {
    final outcome = await _openSheet(tester, comparisons: ['bsb', 'lxxwh']);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(outcome.versions, ['bsb', 'lxxwh']);
  });

  testWidgets('a reorder survives into the applied result', (tester) async {
    final outcome =
        await _openSheet(tester, comparisons: ['bsb', 'lxxwh', 'kjvs']);
    expect(_shownOrder(tester), ['bsb', 'lxxwh', 'kjvs']);

    // Driving the callback rather than simulating the drag: the gesture
    // is Flutter's to get right, the index convention is ours, and it is
    // the convention that was wrong in every downward drag under the
    // deprecated `onReorder`.
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(2, 0);
    await tester.pump();
    expect(_shownOrder(tester), ['kjvs', 'bsb', 'lxxwh']);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(outcome.versions, ['kjvs', 'bsb', 'lxxwh']);
  });

  testWidgets('adding appends to the end, where `d nas` puts it',
      (tester) async {
    final outcome = await _openSheet(tester, comparisons: ['bsb']);
    await tester.tap(find.text('Septuagint + Westcott-Hort'));
    await tester.pump();
    expect(_shownOrder(tester), ['bsb', 'lxxwh']);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(outcome.versions, ['bsb', 'lxxwh']);
  });

  testWidgets('removing a comparison leaves the rest in place',
      (tester) async {
    final outcome =
        await _openSheet(tester, comparisons: ['bsb', 'lxxwh', 'kjvs']);
    // Row order matches the list, so the second remove button is lxxwh's.
    await tester.tap(find.byIcon(Icons.remove_circle_outline).at(1));
    await tester.pump();

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(outcome.versions, ['bsb', 'kjvs']);
  });

  testWidgets('the reading version is shown, locked, and out of the result',
      (tester) async {
    final outcome = await _openSheet(tester, comparisons: ['bsb']);
    expect(find.text('King James Version'), findsOneWidget);
    expect(find.text('reading'), findsOneWidget);
    // One comparison row => exactly one remove button and one grip.
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(outcome.versions, ['bsb']);
  });

  testWidgets('the count is of COLUMNS, so it includes the reading version',
      (tester) async {
    await _openSheet(tester, comparisons: ['bsb', 'lxxwh']);
    expect(find.text('3 versions displayed'), findsOneWidget);
  });

  testWidgets('Remove all empties the comparisons without cancelling',
      (tester) async {
    final outcome =
        await _openSheet(tester, comparisons: ['bsb', 'lxxwh']);
    await tester.tap(find.text('Remove all'));
    await tester.pump();
    expect(find.text('Only the edition you are reading'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(outcome.versions, isNotNull);
    expect(outcome.versions, isEmpty);
  });

  testWidgets('a stale comparison from an older build is dropped on open',
      (tester) async {
    final outcome =
        await _openSheet(tester, comparisons: ['cuv-yhwd', 'bsb']);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    // `cuv-yhwd` was retired; its successor is a real edition and takes
    // its place rather than the row vanishing.
    expect(outcome.versions, ['cuvs-yhwh', 'bsb']);
  });

  testWidgets('the reading version cannot also be offered as available',
      (tester) async {
    await _openSheet(tester, reading: 'bsb');
    expect(find.text('Berean Standard Bible'), findsOneWidget);
  });
}
