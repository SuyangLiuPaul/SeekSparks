/// 2026-08-09: the Atlas, mounted against the REAL gazetteer.
///
/// `atlas_index_test.dart` pins the ranking, the scope and the label
/// budget as pure functions. What that cannot catch is the thing this
/// page is most likely to get wrong: an index of 1,271 rows and a map of
/// 1,228 dots living in one Row, at a laptop width AND at the 320 px a
/// phone gives it.
///
/// Rendered in the app's shipped default (zh-Hans) for the same reason
/// `hebrew_kings_test.dart` is: `AppSettings.setLocale` leaves a
/// notification-rescheduling timer pending that fails teardown, and the
/// default is the locale most readers see anyway.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/journey_style.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/pages/atlas_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/journeys_service.dart';
import 'package:seeksparks/services/places_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<BiblePlace> jonah1;
  late int total;
  setUpAll(() async {
    total = (await PlacesService.all()).length;
    await PlacesService.baseMap();
    jonah1 = await PlacesService.forChapter('Jonah', 1);
    // Warmed here, like the gazetteer above it, because the page loads it
    // over a real Future while `pump` only advances a FAKE clock. Left
    // cold, whether the overlay switches exist by the eighth frame is a
    // race against how long the asset takes to read — which is a fact
    // about the file's size, not about the page, and it decided these
    // tests differently the day the file grew from 40 KB to 52 KB.
    await JourneysService.all();
  });

  Future<void> pump(WidgetTester tester, Size size,
      {Widget page = const AtlasPage()}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(home: page),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('opens on the whole gazetteer, most-referenced first',
      (tester) async {
    await pump(tester, const Size(1440, 1000));
    expect(tester.takeException(), isNull);

    // The count is the reader's only way to know the index is complete.
    // Read from the asset rather than hard-coded: the number is a fact
    // about the gazetteer, and this test is about the header showing it.
    expect(find.text('$total 个地名'), findsOneWidget);
    // Most-referenced first is the only default order that answers a
    // question, and Jerusalem's 755 references make it the answer.
    expect(find.text('耶路撒冷'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('typing narrows the index and keeps both Antiochs apart',
      (tester) async {
    await pump(tester, const Size(1440, 1000));

    await tester.enterText(find.byType(TextField), 'antioch');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(tester.takeException(), isNull);

    // Syrian and Pisidian Antioch are 500 km apart and share a
    // spelling. bwh33's text search cannot tell them apart; the
    // gazetteer's ordinal can, so BOTH must survive the filter with
    // their numerals showing.
    expect(find.text('安提阿'), findsNWidgets(2));
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('searching in English works while reading in Chinese',
      (tester) async {
    await pump(tester, const Size(1440, 1000));

    // Finding is not reading: the index searches all three scripts
    // whatever the reading version is, so a CUVS reader who knows a site
    // as "Ashkelon" from a commentary can look it up.
    await tester.enterText(find.byType(TextField), 'ashkelon');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('亚实基伦'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a nonsense query says so rather than showing an empty list',
      (tester) async {
    await pump(tester, const Size(1440, 1000));

    await tester.enterText(find.byType(TextField), 'qqqqzz');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(tester.takeException(), isNull);
    expect(find.textContaining('没有匹配'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a passage opens filtered to its own places, dismissibly',
      (tester) async {
    await pump(
      tester,
      const Size(1440, 1000),
      page: AtlasPage(subjectPlaces: jonah1, subjectLabel: '约拿书 1:3'),
    );
    expect(tester.takeException(), isNull);

    expect(find.textContaining('约拿书 1:3'), findsWidgets);
    expect(find.text('${jonah1.length} / $total 个地名'), findsOneWidget);

    // An atlas that could only ever show one chapter would not be an
    // atlas, so the filter has to come off.
    await tester.tap(find.byIcon(Icons.close).first);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text('$total 个地名'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('selecting a place shows its references grouped by book',
      (tester) async {
    final joppa = jonah1.firstWhere((p) => p.name == 'Joppa');
    await pump(
      tester,
      const Size(1440, 1000),
      page: AtlasPage(subjectPlaces: jonah1, initialPlaceId: joppa.id),
    );
    expect(tester.takeException(), isNull);

    // The detail column only exists above 1180 px; below it the same
    // panel arrives as a sheet.
    expect(find.textContaining('经文出处'), findsOneWidget);
    // Grouped by book in CANONICAL order — Joshua, Jonah, then Acts —
    // which is what turns a flat wall of references into a shape.
    expect(find.text('约书亚记'), findsOneWidget);
    expect(find.text('使徒行传'), findsOneWidget);
    // Coordinates, not a guess: Joppa is a real identified site.
    expect(find.textContaining('° N'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('an unlocated place says so instead of inventing a pin',
      (tester) async {
    final all = await PlacesService.all();
    final eden = all.firstWhere((p) => p.name == 'Eden');
    expect(eden.located, isFalse);

    await pump(
      tester,
      const Size(1440, 1000),
      page: AtlasPage(subjectPlaces: <BiblePlace>[eden], initialPlaceId: eden.id),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('今址不详'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the journey overlays are switchable and carry their verses',
      (tester) async {
    await pump(tester, const Size(1440, 1000));
    expect(tester.takeException(), isNull);

    // The switches are present before anything is drawn: an overlay the
    // reader cannot find is not an overlay (bwh33's Overlays window).
    expect(find.text('行程'), findsOneWidget);
    expect(find.text('保罗第一次宣教旅程'), findsOneWidget);
    expect(find.text('保罗第二次宣教旅程'), findsOneWidget);

    // Nothing drawn yet, so the standing caution is not printed either —
    // a warning about a line that is not there teaches nothing.
    expect(find.textContaining('不是他们走过的路'), findsNothing);

    await tester.tap(find.text('保罗第一次宣教旅程'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(tester.takeException(), isNull);

    // #317's non-negotiables, on screen: the caution that a line is not a
    // road, the source the itinerary is read out of, and a verse against
    // every stop.
    expect(find.textContaining('不是他们走过的路'), findsWidgets);
    expect(find.text('这份行程的依据'), findsOneWidget);
    expect(find.textContaining('使徒行传 13:1'), findsWidgets);
    // The straight-line total is offered as a scale and says what it is.
    expect(find.textContaining('不是实际行程'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a provisional stop is labelled rather than drawn as fact',
      (tester) async {
    await pump(tester, const Size(1440, 1000));

    // The second journey is the one with stops the text does not put the
    // travellers at — Iconium in 16:2 and Jerusalem in 18:22.
    await tester.tap(find.text('保罗第二次宣教旅程'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(tester.takeException(), isNull);

    // Kept and marked, not dropped: a reader comparing this against a
    // printed atlas needs to see where the printed atlas got its stop.
    expect(find.text('推定'), findsWidgets);
    // And the tag is never bare: the row says what the text does and does
    // not say, which is the whole reason the stop is kept.
    expect(find.textContaining('并未说他们到过以哥念'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the wilderness route says where our map cannot tell camps apart',
      (tester) async {
    await pump(tester, const Size(1440, 1000));

    // Numbers 33 is the one itinerary scripture gives as a LIST, so the
    // order needs no reconstruction — but 27 of its 42 stations land on
    // six shared points in the gazetteer, and drawn without a word about
    // it the map shows one dot where the text names eleven camps.
    expect(find.text('以色列出埃及与旷野行程'), findsOneWidget);
    await tester.tap(find.text('以色列出埃及与旷野行程'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(tester.takeException(), isNull);

    // The claim, on screen, in the reader's own language — and phrased
    // about the DATA, because a shared point can mean an unidentified
    // site or two places genuinely next door and we cannot tell which.
    expect(find.textContaining('共用同一个坐标'), findsOneWidget);
    // And locatable: a count with no locator leaves a reader at Rissah
    // unable to find out whether Rissah is one of the merged ones.
    expect(find.text('与相邻站共用坐标'), findsWidgets);
    // The two camps the gazetteer cannot place at all are a different
    // claim and keep their own sentence.
    expect(find.textContaining('线在那里断开'), findsOneWidget);
    // Every station still carries the verse that puts it on the list.
    expect(find.textContaining('民数记 33:'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('the journeys block is bounded by the pane, not by the asset',
      (tester) async {
    // The overlay switches are the one part of the index column sized by
    // the DATA rather than by the viewport: every route in the asset is
    // another two-line row, and the block is not the column's flexible
    // child, so it grew at the place list's expense until it pushed the
    // column off the bottom. The sixth route is where that first showed,
    // overflowing a 320x640 pane by 34 px — which made it a bug about
    // the seventh route as much as the sixth.
    //
    // So the height is asserted against the PANE. A cap that holds at
    // six routes holds at ten; a test that only checked for an overflow
    // exception would go quietly green again at five.
    await pump(tester, const Size(320, 640));
    expect(tester.takeException(), isNull);
    final block = tester.getSize(find.byKey(const Key('atlas-journeys-block')));
    expect(block.height, lessThanOrEqualTo(640 * 0.42));

    // One swatch per route, and each of them actually occupying space: a
    // CustomPaint with no child lays out at zero, so the legend would go
    // silently blank without ever failing a layout.
    final swatches = find.byType(JourneySwatch);
    expect(swatches, findsNWidgets(6));
    expect(tester.getSize(swatches.first).height, greaterThan(0));
    expect(tester.getSize(swatches.first).width, greaterThan(0));
    await unmount(tester);
  });

  testWidgets('lays out at the 320 px pane minimum', (tester) async {
    await pump(tester, const Size(320, 640));
    // Below 880 px the map goes above the index instead of beside it;
    // a map squeezed into a strip is worse than a map with a list under
    // it.
    expect(tester.takeException(), isNull);
    expect(find.text('$total 个地名'), findsOneWidget);

    await unmount(tester);
  });
}
