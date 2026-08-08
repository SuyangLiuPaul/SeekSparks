// 2026-08-08 (task #280): the scope picker's contract, which the pure
// model cannot pin.
//
// The sheet is STAGED — it owns a draft and hands it back on Apply,
// because applying re-runs the last search and 66 live checkboxes would
// be 66 searches. That makes the return value load-bearing in a way a
// bottom sheet usually is not: null means CANCEL and an EMPTY SET means
// "no limit, search everything". Confusing the two either discards a
// reader's scope or silently widens it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/book_groups.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/utils/command_verb.dart' show LimitRange, LimitSpec;
import 'package:seeksparks/utils/search_scope.dart' show limitSpecForBooks;
import 'package:seeksparks/widgets/search_scope_sheet.dart';

/// What the sheet handed back, and whether it has handed anything back
/// at all — null alone cannot tell "cancelled" from "still open".
class _Outcome {
  Set<String>? books;
  bool returned = false;
}

Future<_Outcome> _openSheet(
  WidgetTester tester, {
  LimitSpec? activeSpec,
  String? fallbackLabel,
  String locale = 'en',
}) async {
  final outcome = _Outcome();
  // AppSettings is required: WbType.of() resolves the type scale from
  // the reader's font-size and line-spacing settings.
  await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(
        theme: workbenchTheme(ThemeData.light(useMaterial3: true)),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  outcome.books = await showSearchScopeSheet(
                    context: context,
                    locale: locale,
                    version: 'bsb',
                    activeSpec: activeSpec,
                    activeFallbackLabel: fallbackLabel,
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

void main() {
  testWidgets('a group chip is a three-state control, not an add-only tap',
      (tester) async {
    await _openSheet(tester);
    expect(find.text('No limit — the whole Bible'), findsOneWidget);

    await tester.tap(find.text('Pentateuch'));
    await tester.pump();
    expect(find.text('5 books selected'), findsOneWidget);

    await tester.tap(find.text('Pentateuch'));
    await tester.pump();
    expect(find.text('No limit — the whole Bible'), findsOneWidget);
  });

  testWidgets('Apply hands back exactly the drafted books', (tester) async {
    final outcome = await _openSheet(tester);
    await tester.tap(find.text('Pentateuch'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(outcome.returned, isTrue);
    expect(outcome.books, otPentateuch.toSet());
  });

  testWidgets('dismissing is a CANCEL — the active scope is untouched',
      (tester) async {
    final outcome =
        await _openSheet(tester, activeSpec: limitSpecForBooks(otPentateuch));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(outcome.returned, isTrue);
    expect(outcome.books, isNull);
  });

  testWidgets('Clear all then Apply is an EMPTY answer, not a cancel',
      (tester) async {
    final outcome =
        await _openSheet(tester, activeSpec: limitSpecForBooks(otPentateuch));
    // Seeded from the active scope, so the reader edits what they have.
    expect(find.text('5 books selected'), findsOneWidget);

    await tester.tap(find.text('Clear all'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(outcome.returned, isTrue);
    expect(outcome.books, isNotNull);
    expect(outcome.books, isEmpty);
  });

  testWidgets('a chapter range says it cannot be drawn, rather than widening',
      (tester) async {
    // `l matt 5-7`: flattening this to "Matthew" would hand back a
    // scope four times the size of the one the reader set.
    await _openSheet(
      tester,
      activeSpec: LimitSpec(
        [LimitRange('Matthew', firstChapter: 5, lastChapter: 7)],
        'Matthew 5-7',
      ),
    );
    expect(
        find.textContaining('is not a whole-book selection'), findsOneWidget);
    expect(find.text('No limit — the whole Bible'), findsOneWidget);
  });

  testWidgets('a verse-list limit is named by the list, not by books',
      (tester) async {
    await _openSheet(tester, fallbackLabel: 'Servant Songs');
    expect(find.textContaining('Servant Songs'), findsOneWidget);
  });
}
