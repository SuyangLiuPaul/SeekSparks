// 2026-08-24 (#308, third surface): the word-study distribution panel
// names the unit it plots.
//
// #308 was reported by the owner about the search-stats strip: 「the 27
// in John, is it the number of actual word frequency in John or the
// number of 'verses'?」 The strip and the Stats tab were fixed then.
// `WordDistribution` — the panel inside the word-study sheet, and the
// surface a narrow layout falls back to — was not, and it plots the
// OTHER unit: its only caller feeds `ConcordanceResult.byBook`, the
// per-book OCCURRENCE map. So the same word in the same session gave
// John 27 in one place and John 37 in another, and the second number
// carried no label at all.
//
// These tests assert the label is REAL TEXT ON SCREEN, not a property
// that happens to be set. The strip's own defect survived a green suite
// for exactly that reason.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/utils/search_stats.dart' show HitUnit;
import 'package:seeksparks/widgets/word_distribution.dart';

void main() {
  Widget host(Widget child) => ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          theme: workbenchTheme(ThemeData.light(useMaterial3: true)),
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      );

  // G25 in John, the number the ticket was written about: 27 verses,
  // 37 occurrences.
  const byBook = <String, int>{'John': 37, '1 John': 28, 'Luke': 13};

  Future<void> pump(WidgetTester tester, HitUnit unit,
      {String locale = 'en'}) async {
    await tester.pumpWidget(host(
      WordDistribution(byBook: byBook, unit: unit, locale: locale),
    ));
  }

  group('WordDistribution names its unit', () {
    testWidgets('occurrences — what the concordance map actually holds',
        (tester) async {
      await pump(tester, HitUnit.occurrences);
      expect(find.text('Distribution (occurrences)'), findsOneWidget);
    });

    testWidgets('a verse map would say so instead', (tester) async {
      // The unit is a required parameter precisely so a future caller
      // with verse counts cannot inherit the wrong label by omission.
      await pump(tester, HitUnit.verses);
      expect(find.text('Distribution (verses)'), findsOneWidget);
      expect(find.text('Distribution (occurrences)'), findsNothing);
    });

    testWidgets('the bare unlabelled heading is gone', (tester) async {
      // The defect: a heading that reads only 「分布」 / "Distribution"
      // over sixteen numbers in an unstated unit.
      await pump(tester, HitUnit.occurrences);
      expect(find.text('Distribution'), findsNothing);
    });

    testWidgets('both Chinese scripts carry it too', (tester) async {
      // A string that exists three times can be wrong in one language
      // only, which is how #316's advisory contradicted itself.
      await pump(tester, HitUnit.occurrences, locale: 'zh-Hans');
      expect(find.text('分布（按出现次数）'), findsOneWidget);

      await pump(tester, HitUnit.occurrences, locale: 'zh-Hant');
      expect(find.text('分佈（按出現次數）'), findsOneWidget);
    });
  });

  group('the vocabulary is shared, not re-invented', () {
    test('the panel reuses the strip\'s unit names verbatim', () {
      // #308 asks for ONE vocabulary across the charts. If these ever
      // diverge the reader learns two names for one distinction.
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        final template = uiStrings['wordDistributionIn']![locale]!;
        expect(template.contains('{unit}'), isTrue,
            reason: '$locale must interpolate the shared unit name');
        for (final key in ['hitUnitVerses', 'hitUnitOccurrences']) {
          expect(uiStrings[key]![locale], isNotEmpty,
              reason: '$key must exist in $locale');
        }
      }
    });
  });
}
