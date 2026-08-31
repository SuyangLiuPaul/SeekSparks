/// The Places tab and the map canvas, mounted against the REAL gazetteer.
///
/// `places_service_test.dart` pins the inversion and `place_geo_test.dart`
/// pins the projection. Neither mounts anything, and the two ways this
/// feature breaks in practice are both layout: the list overflowing the
/// 320 px Analysis pane, and the map painting nothing because the
/// projection was never built.
///
/// 2026-08-09: the map moved out of the centre pane and into `AtlasPage`
/// (DELETION-REVIEW §4), so the pane now hands its loaded places to the
/// caller instead of naming a lens, and the canvas is driven by tokens
/// rather than by whether its lists changed identity.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/book_name_mapping.dart' show BookScript;
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/services/journeys_service.dart';
import 'package:seeksparks/services/places_service.dart';
import 'package:seeksparks/utils/place_geo.dart' show BaseMap;
import 'package:seeksparks/utils/travel_time.dart';
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
    await JourneysService.all();
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
          onOpenAtlas: (_, __) {},
          onOpenJourney: (_) {},
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

    testWidgets('tapping a place asks for the Atlas, with that place and '
        'the passage it came from', (tester) async {
      String? asked;
      List<BiblePlace>? handed;
      var calls = 0;
      await tester.pumpWidget(host(PlacesPane(
        englishBook: 'Jonah',
        chapter: 1,
        verse: 3,
        locale: 'en',
        script: BookScript.english,
        onOpenAtlas: (places, id) {
          asked = id;
          handed = places;
          calls++;
        },
        onOpenJourney: (_) {},
      )));
      await settle(tester);

      await tester.tap(find.text('Joppa'));
      await settle(tester);
      expect(calls, 1);
      expect(asked, isNotNull);
      expect(asked, contains('Joppa'));
      // The pane hands over what it already loaded, so the Atlas opens
      // framed on the passage rather than on the whole ancient world.
      expect(handed, isNotNull);
      expect(handed!.map((p) => p.name), contains('Tarshish'));

      // The header button opens the Atlas without preselecting anything.
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
        onOpenAtlas: _ignore,
        onOpenJourney: _ignoreJourney,
      )));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('names no place'), findsOneWidget);
    });
  });

  group('PlacesPane journeys', () {
    testWidgets(
        'the chapter the first journey opens in says so, and says which '
        'stop this verse is', (tester) async {
      await tester.pumpWidget(host(PlacesPane(
        englishBook: 'Acts',
        chapter: 13,
        verse: 4,
        locale: 'en',
        script: BookScript.english,
        onOpenAtlas: _ignore,
        onOpenJourney: _ignoreJourney,
      )));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Journeys through this passage'), findsOneWidget);
      expect(find.text("Paul's first journey"), findsOneWidget);
      expect(find.textContaining('This verse: Stop 2'), findsOneWidget);
      expect(find.textContaining('7 stops in this chapter'), findsOneWidget);
    });

    testWidgets('a chapter no journey touches shows no journey section',
        (tester) async {
      await tester.pumpWidget(host(PlacesPane(
        englishBook: 'Jonah',
        chapter: 1,
        verse: 3,
        locale: 'en',
        script: BookScript.english,
        onOpenAtlas: _ignore,
        onOpenJourney: _ignoreJourney,
      )));
      await settle(tester);

      expect(find.byKey(const Key('places-journeys')), findsNothing);
      expect(find.textContaining('Journeys through'), findsNothing);
    });

    testWidgets('tapping a journey asks for the Atlas with that route',
        (tester) async {
      String? opened;
      var calls = 0;
      var atlasCalls = 0;
      await tester.pumpWidget(host(PlacesPane(
        englishBook: 'Acts',
        chapter: 13,
        verse: 4,
        locale: 'en',
        script: BookScript.english,
        onOpenAtlas: (_, __) => atlasCalls++,
        onOpenJourney: (id) {
          opened = id;
          calls++;
        },
      )));
      await settle(tester);

      await tester.tap(find.text("Paul's first journey"));
      await settle(tester);
      expect(calls, 1);
      expect(opened, 'paul-1');
      expect(atlasCalls, 0);
    });

    testWidgets('a Chinese reader sees the header and count in Chinese',
        (tester) async {
      await tester.pumpWidget(host(PlacesPane(
        englishBook: 'Acts',
        chapter: 13,
        verse: 4,
        locale: 'zh-Hans',
        script: BookScript.simplified,
        onOpenAtlas: _ignore,
        onOpenJourney: _ignoreJourney,
      )));
      await settle(tester);

      expect(find.text('经过本段的行程'), findsOneWidget);
      expect(find.textContaining('本章共 7 站'), findsOneWidget);
    });
  });

  group('PlaceMapView', () {
    Widget map({
      String? selectedId,
      ValueChanged<String?>? onSelect,
      VoidCallback? onClose,
      int fitToken = 0,
      int focusToken = 0,
      TravelBand band = kDefaultTravelBand,
    }) =>
        PlaceMapView(
          title: 'Jonah 1:3',
          emphasised: jonah1.where((p) => p.name == 'Joppa').toList(),
          muted: jonah1.where((p) => p.name != 'Joppa').toList(),
          baseMap: baseMap,
          script: BookScript.english,
          locale: 'en',
          selectedId: selectedId,
          onSelect: onSelect ?? (_) {},
          onClose: onClose ?? () {},
          fitToken: fitToken,
          focusToken: focusToken,
          attribution: PlacesService.attribution,
          travelBand: band,
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
      // The ruler used to print one unsourced figure and hedge it with
      // the word "about". The hedge is now a real one and rides in a
      // tooltip, because it is three clauses long and the footer is two
      // lines; a band with no basis beside it would be the same defect
      // wearing a range.
      final tip = tester.widget<Tooltip>(find.ancestor(
        of: find.textContaining('Joppa →'),
        matching: find.byType(Tooltip),
      ));
      expect(tip.message, contains('ORBIS'));
      expect(tip.message, contains('straight'));
      expect(find.textContaining('about '), findsNothing);
    });

    testWidgets('an empty passage falls back to the Levant instead of '
        'painting nothing', (tester) async {
      await tester.pumpWidget(host(
        PlaceMapView(
          title: 'Philemon 1:1',
          emphasised: const <BiblePlace>[],
          muted: const <BiblePlace>[],
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

    testWidgets('no close button when the map IS the surface',
        (tester) async {
      await tester.pumpWidget(host(
        PlaceMapView(
          title: 'Atlas',
          emphasised: jonah1,
          muted: const <BiblePlace>[],
          baseMap: baseMap,
          script: BookScript.english,
          locale: 'en',
          selectedId: null,
          onSelect: (_) {},
        ),
        width: 900,
        height: 600,
      ));
      await settle(tester);

      expect(tester.takeException(), isNull);
      // A "Close map" that pops the page the reader is standing on is
      // the back button with a worse name.
      expect(find.text('Close map'), findsNothing);
      expect(find.text('Atlas'), findsOneWidget);
    });

    // The two tokens are the whole reason the view stopped comparing its
    // own lists: the Atlas rebuilds on every keystroke and hands over
    // fresh list instances, so an identity check re-fitted the map out
    // from under a reader mid-pan.
    testWidgets('the focus token moves the view and the fit token '
        'restores it', (tester) async {
      final joppa = jonah1.firstWhere((p) => p.name == 'Joppa');

      await tester.pumpWidget(
          host(map(selectedId: joppa.id), width: 900, height: 600));
      await settle(tester);
      // "Fit" only exists once the view has been moved off its default,
      // which makes it the observable proxy for "the map was touched".
      expect(find.text('Fit'), findsNothing);

      await tester.pumpWidget(host(
          map(selectedId: joppa.id, focusToken: 1),
          width: 900,
          height: 600));
      await settle(tester);
      expect(find.text('Fit'), findsOneWidget);

      // A merely-rebuilt widget must NOT re-frame the map.
      await tester.pumpWidget(host(
          map(selectedId: joppa.id, focusToken: 1),
          width: 900,
          height: 600));
      await settle(tester);
      expect(find.text('Fit'), findsOneWidget);

      await tester.pumpWidget(host(
          map(selectedId: joppa.id, focusToken: 1, fitToken: 1),
          width: 900,
          height: 600));
      await settle(tester);
      expect(find.text('Fit'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // #317: the ruler's days are computed at the reader's chosen band,
    // but the citation under them used to always be `kBandOnFoot`'s —
    // a source vouching for an arithmetic it did not make.
    group("the ruler's pace (#317)", () {
      testWidgets('the citation names the band that made the number',
          (tester) async {
        final joppa = jonah1.firstWhere((p) => p.name == 'Joppa');

        for (final band in [kBandCarts, kBandVehicle]) {
          await tester.pumpWidget(host(
              map(selectedId: joppa.id, band: band),
              width: 900,
              height: 600));
          await settle(tester);

          final tip = tester.widget<Tooltip>(find.ancestor(
            of: find.textContaining('Joppa →'),
            matching: find.byType(Tooltip),
          ));
          // For a non-default band the message is two paragraphs: the
          // band's own arithmetic citation, then `travelBandNotOurs`
          // explaining why the DEFAULT is what SeekSparks recommends —
          // and that explanation legitimately names the default's own
          // "20–30" range (Deut 1:2's eleven days only fits at 20–30).
          // So the "not the default's range" check belongs to the first
          // paragraph only; the message as a whole is allowed to mention
          // 20-30 in its second paragraph without that being the defect
          // this test guards against.
          final arithmeticCitation = tip.message!.split('\n\n').first;
          if (band == kBandCarts) {
            expect(arithmeticCitation, contains('12–20'));
            expect(arithmeticCitation, isNot(contains('20–30')));
          } else {
            expect(arithmeticCitation, contains('30–36'));
            expect(arithmeticCitation, isNot(contains('20–30')));
          }
        }
      });

      testWidgets("the default band's citation is unchanged", (tester) async {
        final joppa = jonah1.firstWhere((p) => p.name == 'Joppa');
        await tester.pumpWidget(
            host(map(selectedId: joppa.id), width: 900, height: 600));
        await settle(tester);

        final tip = tester.widget<Tooltip>(find.ancestor(
          of: find.textContaining('Joppa →'),
          matching: find.byType(Tooltip),
        ));
        expect(tip.message, contains('20–30'));
        expect(tip.message, contains('ORBIS'));
        expect(tip.message, contains('straight'));
      });

      testWidgets(
          'a non-default pace says so where a touch reader can read it',
          (tester) async {
        final joppa = jonah1.firstWhere((p) => p.name == 'Joppa');

        await tester.pumpWidget(host(
            map(selectedId: joppa.id, band: kBandCarts),
            width: 900,
            height: 600));
        await settle(tester);
        expect(find.byKey(const Key('places-map-band')), findsOneWidget);
        final label = tester
            .widget<Text>(find.byKey(const Key('places-map-band')))
            .data;
        expect(label, travelBandLabel(kBandCarts, 'en'));

        await tester.pumpWidget(
            host(map(selectedId: joppa.id), width: 900, height: 600));
        await settle(tester);
        expect(find.byKey(const Key('places-map-band')), findsNothing);
      });

      testWidgets('the added line does not eat the map', (tester) async {
        final joppa = jonah1.firstWhere((p) => p.name == 'Joppa');
        await tester.pumpWidget(host(
            map(selectedId: joppa.id, band: kBandCarts),
            width: 320,
            height: 400));
        await settle(tester);

        expect(tester.takeException(), isNull);
        final painter = find.byWidgetPredicate((w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString().contains('_MapPainter'));
        final height = tester.getSize(painter).height;
        // Three measured heights for this canvas at 320x400, so the
        // number below is a baseline and not a tolerance nobody can
        // re-derive:
        //   293.0  before #317's band footer existed (measured by the
        //          #317 iteration via a scratch test)
        //   276.0  with the band footer, its rows at `t.chrome - 1`
        //   267.0  with those rows raised to `t.chrome`, the app's own
        //          `WbMetrics.smallPrintFloor` — measured 2026-08-31
        // The floor repair cost 9px, not the ~1px one line suggests:
        // `_footer` is a stack of ~7 text rows (place_map.dart:523-793)
        // and each gained ~1-1.5px. Nothing wrapped and nothing
        // overflowed — the `takeException` check above is what guards
        // that, and the map still holds 267 of 400px.
        // 255.0 is chosen so this still fires if someone adds ANOTHER
        // footer line (~15px at 11px type would land near 252) while
        // not firing on a sub-pixel type change.
        expect(height, greaterThan(255.0),
            reason: 'the map canvas at the 320x400 pane floor was 293.0 '
                'before the band footer, 276.0 with it, and 267.0 once '
                'its rows reached the small-print floor. Below 255 means '
                'a whole new line has been added to the footer, not a '
                'type-size change — give it back to the map.');
      });
    });
  });

  // #319: the "muted" list is the exact complement of the host's filter,
  // so a map that always draws it answers a different question from the
  // list beside it. Hidden has to mean hidden from the eye, the finger
  // AND the count — a layer that is invisible but still hit-tested gives
  // a dot that answers a tap nobody can see they are making.
  group('PlaceMapView context layer', () {
    const ashkelon = BiblePlace(
      id: 'ashkelon-1',
      name: 'Ashkelon',
      ordinal: null,
      simplified: null,
      traditional: null,
      lat: 31.67,
      lon: 34.57,
      refs: <PlaceRef>[PlaceRef('Judges', 1, 18)],
    );
    const tarshish = BiblePlace(
      id: 'tarshish-1',
      name: 'Tarshish',
      ordinal: null,
      simplified: null,
      traditional: null,
      lat: null,
      lon: null,
      refs: <PlaceRef>[PlaceRef('Jonah', 1, 3)],
    );

    Widget ctx({
      required bool showContext,
      ValueChanged<String?>? onSelect,
      VoidCallback? onToggle,
    }) =>
        PlaceMapView(
          title: 'Atlas',
          emphasised: const <BiblePlace>[],
          muted: const <BiblePlace>[ashkelon, tarshish],
          baseMap: baseMap,
          script: BookScript.english,
          locale: 'en',
          selectedId: null,
          onSelect: onSelect ?? (_) {},
          showContext: showContext,
          onToggleContext: onToggle ?? () {},
        );

    // The map fits itself to the only located place, so its marker lands
    // on the canvas centre and a tap there is a tap on it.
    final canvas = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onScaleStart != null);

    testWidgets('shown: the context layer answers a tap and is counted',
        (tester) async {
      var calls = 0;
      String? got;
      await tester.pumpWidget(host(
          ctx(showContext: true, onSelect: (id) {
            got = id;
            calls++;
          }),
          width: 900,
          height: 600));
      await settle(tester);

      await tester.tapAt(tester.getCenter(canvas));
      await settle(tester);
      expect(calls, 1);
      expect(got, ashkelon.id);
      expect(find.textContaining('1 more named here'), findsOneWidget);
    });

    testWidgets('hidden: nothing to tap, and the footer stops describing '
        'places the reader cannot see', (tester) async {
      var calls = 0;
      String? got = 'unset';
      await tester.pumpWidget(host(
          ctx(showContext: false, onSelect: (id) {
            got = id;
            calls++;
          }),
          width: 900,
          height: 600));
      await settle(tester);

      await tester.tapAt(tester.getCenter(canvas));
      await settle(tester);
      expect(calls, 1);
      expect(got, isNull);
      // Tarshish has no coordinates and is now not on this map at all,
      // so counting it would make the footer a claim about nothing.
      expect(find.textContaining('more named here'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the toggle prints the count, so it can be checked against '
        'the index', (tester) async {
      var flips = 0;
      await tester.pumpWidget(host(ctx(showContext: false, onToggle: () => flips++),
          width: 900, height: 600));
      await settle(tester);

      // Not an eye icon alone: on a tablet there is no hover to reveal a
      // tooltip (#299), and "2 others" is a fact that adds up against the
      // index header's own "n / total".
      expect(find.text('Show 2 others'), findsOneWidget);
      await tester.tap(find.text('Show 2 others'));
      await settle(tester);
      expect(flips, 1);

      await tester.pumpWidget(host(ctx(showContext: true), width: 900, height: 600));
      await settle(tester);
      expect(find.text('Hide 2 others'), findsOneWidget);
    });

    testWidgets('no toggle when there is nothing being left out',
        (tester) async {
      await tester.pumpWidget(host(
        PlaceMapView(
          title: 'Atlas',
          emphasised: jonah1,
          muted: const <BiblePlace>[],
          baseMap: baseMap,
          script: BookScript.english,
          locale: 'en',
          selectedId: null,
          onSelect: (_) {},
          onToggleContext: () {},
        ),
        width: 900,
        height: 600,
      ));
      await settle(tester);

      // A control that changes nothing is chrome.
      expect(find.textContaining('others'), findsNothing);
    });
  });
}

void _ignore(List<BiblePlace> places, String? id) {}
void _ignoreJourney(String id) {}
