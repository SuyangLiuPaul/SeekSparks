/// The Places tab and the map lens, mounted against the REAL gazetteer.
///
/// `places_service_test.dart` pins the inversion and `place_geo_test.dart`
/// pins the projection. Neither mounts anything, and the two ways this
/// feature breaks in practice are both layout: the list overflowing the
/// 320 px Analysis pane, and the map painting nothing because the
/// projection was never built.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/book_name_mapping.dart' show BookScript;
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/services/places_service.dart';
import 'package:seeksparks/utils/place_geo.dart' show BaseMap;
import 'package:seeksparks/widgets/place_map.dart';
import 'package:seeksparks/widgets/places_pane.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `testWidgets` runs in a fake-async zone where real disk I/O never
  // completes, so the pane would sit on its spinner forever. Warming the
  // caches here turns its awaits into microtasks `pump` can drive.
  late BaseMap baseMap;
  late List<BiblePlace> jonah1;
  setUpAll(() async {
    await PlacesService.all();
    baseMap = await PlacesService.baseMap();
    jonah1 = await PlacesService.forChapter('Jonah', 1);
  });

  Widget host(Widget child, {double width = 320, double height = 700}) =>
      ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: width, height: height, child: child),
            ),
          ),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  group('PlacesPane', () {
    Widget pane(String locale, BookScript script) => PlacesPane(
          englishBook: 'Jonah',
          chapter: 1,
          verse: 3,
          locale: locale,
          script: script,
          selectedId: null,
          onOpenMap: (_) {},
        );

    for (final width in const [320.0, 560.0]) {
      testWidgets('no overflow at ${width.toInt()} px', (tester) async {
        await tester.pumpWidget(
            host(pane('en', BookScript.english), width: width));
        await settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Joppa'), findsOneWidget);
        expect(find.text('Tarshish'), findsOneWidget);
        // Both tiers, because a one-tier pane would be empty on most
        // verses and read as broken.
        expect(find.text('Named in this verse'), findsOneWidget);
        expect(find.text('Elsewhere in this chapter'), findsOneWidget);
        // The permission this data ships under is conditional on credit.
        expect(find.textContaining('Eagle'), findsWidgets);
      });
    }

    testWidgets('a Chinese reader gets Chinese names with the English kept',
        (tester) async {
      await tester
          .pumpWidget(host(pane('zh-Hans', BookScript.simplified)));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('约帕'), findsOneWidget);
      // The English stays beside it: every atlas and commentary the
      // reader might reach for is indexed in English.
      expect(find.textContaining('Joppa'), findsOneWidget);
      expect(find.text('本节地名'), findsOneWidget);
    });

    testWidgets('tapping a place asks for the map, with that place',
        (tester) async {
      String? asked;
      var calls = 0;
      await tester.pumpWidget(host(PlacesPane(
        englishBook: 'Jonah',
        chapter: 1,
        verse: 3,
        locale: 'en',
        script: BookScript.english,
        selectedId: null,
        onOpenMap: (id) {
          asked = id;
          calls++;
        },
      )));
      await settle(tester);

      await tester.tap(find.text('Joppa'));
      await settle(tester);
      expect(calls, 1);
      expect(asked, isNotNull);
      expect(asked, contains('Joppa'));

      // The header button opens the map without preselecting anything.
      await tester.tap(find.text('Show on map'));
      await settle(tester);
      expect(calls, 2);
      expect(asked, isNull);
    });

    testWidgets('a chapter that names nowhere says so rather than showing '
        'an empty list', (tester) async {
      await tester.pumpWidget(host(const PlacesPane(
        englishBook: 'Philemon',
        chapter: 1,
        verse: 1,
        locale: 'en',
        script: BookScript.english,
        selectedId: null,
        onOpenMap: _ignore,
      )));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('names no place'), findsOneWidget);
    });
  });

  group('PlaceMapView', () {
    Widget map({String? selectedId, ValueChanged<String?>? onSelect}) =>
        PlaceMapView(
          title: 'Jonah 1:3',
          inVerse: jonah1.where((p) => p.name == 'Joppa').toList(),
          inChapter: jonah1.where((p) => p.name != 'Joppa').toList(),
          baseMap: baseMap,
          script: BookScript.english,
          locale: 'en',
          selectedId: selectedId,
          onSelect: onSelect ?? (_) {},
          onClose: () {},
          attribution: PlacesService.attribution,
        );

    testWidgets('draws, and the scale bar appears on the first open',
        (tester) async {
      await tester.pumpWidget(host(map(), width: 900, height: 600));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Jonah 1:3'), findsOneWidget);
      expect(find.text('Close map'), findsOneWidget);
      // The projection is only computable after layout, so a scale bar
      // that needs an interaction to appear is the regression here.
      expect(find.textContaining(' km'), findsWidgets);
    });

    testWidgets('a selected place gets a ruler to the places the passage '
        'itself names', (tester) async {
      final joppa = jonah1.firstWhere((p) => p.name == 'Joppa');
      await tester.pumpWidget(
          host(map(selectedId: joppa.id), width: 900, height: 600));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Joppa →'), findsOneWidget);
      expect(find.textContaining('days on foot'), findsOneWidget);
    });

    testWidgets('an empty passage falls back to the Levant instead of '
        'painting nothing', (tester) async {
      await tester.pumpWidget(host(
        PlaceMapView(
          title: 'Philemon 1:1',
          inVerse: const <BiblePlace>[],
          inChapter: const <BiblePlace>[],
          baseMap: baseMap,
          script: BookScript.english,
          locale: 'en',
          selectedId: null,
          onSelect: (_) {},
          onClose: () {},
        ),
        width: 900,
        height: 600,
      ));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining(' km'), findsWidgets);
    });

    testWidgets('narrow and short still lays out', (tester) async {
      await tester.pumpWidget(host(map(), width: 360, height: 320));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}

void _ignore(String? id) {}
