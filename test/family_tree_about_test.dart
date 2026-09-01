// Guards for the Family Tree's About action and the detail sheet's
// "where this year comes from" section (#318 constraint 2 / #304).
//
// The family tree page had no About action at all — `grep -n "About\|
// _showAbout" lib/pages/family_tree_page.dart` returned nothing before
// this change, unlike its two chronology siblings. And 27 exact birth
// years cited verses (`BiblicalPerson.datingRefs`) that nothing outside
// the model ever read. Both are guarded here because a passing widget
// test is the only thing that proves a value reaches the screen; a
// field with no call site is a field with no audit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/pages/family_tree_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/widgets/person_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FamilyTreePage', () {
    Future<void> pump(WidgetTester tester, Size size) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      // Reading the asset is real I/O, which fake-time pumps do not
      // advance; warming the service cache first makes the FutureBuilder
      // resolve within the pumps below instead of intermittently.
      await tester.runAsync(FamilyTreeService.instance.loadAll);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainProvider()),
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: const MaterialApp(home: FamilyTreePage()),
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

      expect(find.textContaining('236'), findsWidgets);
      expect(find.textContaining('Thiele'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('PersonDetailSheet — where the year comes from', () {
    const abraham = BiblicalPerson(
      id: 'test-abraham',
      name: 'Abraham',
      yearSystem: 'bc',
      birthYear: -2166,
      summary: 'A patriarch.',
      datingKind: 'birth',
      datingBasis: 'scripture',
      datingRefs: ['Genesis 21:5', '1 Kings 6:1'],
    );

    Future<void> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) {
              final mp = MainProvider();
              mp.currentVersion = 'kjv';
              return mp;
            }),
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: MaterialApp(
            theme: workbenchTheme(ThemeData.light()),
            home: Scaffold(
              body: PersonDetailSheet(
                person: abraham,
                locale: 'en',
                scrollController: ScrollController(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('prints the verses an exact birth rests on', (tester) async {
      await pump(tester);
      expect(find.text('Genesis 21:5'), findsOneWidget);
      expect(find.text('1 Kings 6:1'), findsOneWidget);
      expect(find.text('Where this year comes from'), findsOneWidget);
    });
  });
}
