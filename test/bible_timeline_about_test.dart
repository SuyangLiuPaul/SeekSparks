// Guards the Bible Timeline's About action and `_meta` parsing (#318
// constraint 2 / #304). This is the fourth and last of the four
// chronology surfaces to get one — `hebrew_kings_page.dart`, the wheel
// and `family_tree_page.dart` all already disclose their asset's own
// `_meta`; this page disclosed each year's basis one row at a time but
// never the shape of the whole chart (75 of 98 years are `conventional`
// reconstructions) or what the axis is counted back from.
//
// Also guards `timelineBasisKeys` against the asset growing a fourth
// `basis` value the map has no sentence for — `tools/audit_dates.py`
// already emits `scripture` for the sibling `family_tree.json`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/bible_timeline_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/utils/timeline_basis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimelineMeta', () {
    test('_meta.anchor and _meta.note are trilingual', () async {
      final events = await TimelineService.instance.loadAll();
      expect(events, isNotEmpty);
      final meta = TimelineService.instance.meta;
      for (final m in [meta.anchor, meta.note]) {
        expect(m.keys.toSet(), {'en', 'zh-Hans', 'zh-Hant'});
        expect(m['en'], isNotEmpty);
        expect(m['zh-Hans'], isNotEmpty);
        expect(m['zh-Hant'], isNotEmpty);
        expect(m['en'], isNot(equals(m['zh-Hans'])));
        expect(m['zh-Hans'], isNot(equals(m['zh-Hant'])));
        expect(m['en'], isNot(equals(m['zh-Hant'])));
      }
    });

    test('the counts in _meta match the events', () async {
      final events = await TimelineService.instance.loadAll();
      final meta = TimelineService.instance.meta;
      final tally = <String, int>{};
      for (final e in events) {
        tally[e.basis] = (tally[e.basis] ?? 0) + 1;
      }
      expect(meta.counts, tally);
      expect(meta.counts.values.fold<int>(0, (a, b) => a + b), 98);
      expect(events.length, 98);
      expect(meta.counts['conventional'], 75);
      expect(meta.counts['scripture+thiele'], 18);
      expect(meta.counts['thiele'], 5);
    });

    test('every basis in the asset has a sentence', () async {
      final events = await TimelineService.instance.loadAll();
      for (final e in events) {
        expect(
          timelineBasisKeys.containsKey(e.basis),
          isTrue,
          reason: 'event ${e.id} carries basis "${e.basis}", which '
              'timelineBasisKeys does not map — it would fall back to '
              '"a commonly published reconstruction" over a date the '
              'text may actually state.',
        );
      }
      for (final key in timelineBasisKeys.values) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(uiStrings[key]?[locale], isNotNull,
              reason: '$key missing $locale');
          expect(uiStrings[key]![locale], isNotEmpty);
        }
      }
    });

    test('8 events carry a Septuagint year', () async {
      final events = await TimelineService.instance.loadAll();
      expect(events.where((e) => e.septuagintYear != null).length, 8);
    });
  });

  group('BibleTimelinePage — About', () {
    Future<void> pump(WidgetTester tester, Size size) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      // Reading the asset is real I/O, which fake-time pumps do not
      // advance; warming the service caches first makes the
      // FutureBuilder resolve within the pumps below instead of
      // intermittently.
      await tester.runAsync(() => Future.wait([
            TimelineService.instance.loadAll(),
            FamilyTreeService.instance.loadAll(),
          ]));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainProvider()),
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: const MaterialApp(home: BibleTimelinePage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('offers an About action and it opens', (tester) async {
      await pump(tester, const Size(1200, 900));
      expect(tester.takeException(), isNull);

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('75'), findsWidgets);
      expect(find.textContaining('Thiele'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    // AppSettings' default locale is already zh-Hans (`_locale =
    // 'zh-Hans'` before any persisted value is restored, and this test
    // never calls restoreState), so the sheet above is already
    // rendering Chinese — no `setLocale` call is needed to reach it,
    // which sidesteps the notification-rescheduling timer several
    // other tests in this repo note `setLocale` leaves pending.
    testWidgets('the About sheet is Chinese in a Chinese locale',
        (tester) async {
      await pump(tester, const Size(1200, 900));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('锡尔'), findsWidgets);
      expect(find.textContaining('各家年代系统'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
