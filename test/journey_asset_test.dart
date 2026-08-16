// The shipped journey overlays, against the shipped gazetteer (#317).
//
// `parseJourneys` skips a malformed entry rather than throwing, because
// one bad row in a hand-maintained asset should cost one route and not
// the whole Atlas. This file is what makes that safe: it fails the build
// when a stop does not resolve, so a typo cannot reach a reader as a
// route that quietly went missing — or worse, as a line that silently
// skipped a city.
//
// It also holds the claims the drawing makes to the standard #317 set:
// every stop names a verse, every stop the text does not support says so
// on its own row, and no coordinate is ever invented.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/bible_journey.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/journey_route.dart';
import 'package:seeksparks/utils/place_geo.dart' show haversineKm;

void main() {
  final places = parseGazetteer(
    json.decode(File('assets/bible_places.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final doc = json.decode(File('assets/bible_journeys.json').readAsStringSync())
      as Map<String, dynamic>;
  final journeys = parseJourneys(doc);
  final resolved = resolveJourneys(journeys, places);
  final byId = <String, BiblePlace>{for (final p in places) p.id: p};

  group('the asset parses to what it says it holds', () {
    test('every journey in the file survived parsing', () {
      final raw = (doc['journeys'] as List<dynamic>).length;
      expect(journeys.length, raw,
          reason: 'a skipped journey is a silently missing route');
    });

    test('journeys ship, and Paul\'s first is one of them', () {
      expect(journeys, isNotEmpty);
      expect(journeys.map((j) => j.id), contains('paul-1'));
    });

    test('ids are unique', () {
      expect(journeys.map((j) => j.id).toSet().length, journeys.length);
    });

    test('every journey is named and dated in all three locales', () {
      for (final j in journeys) {
        for (final locale in const <String>['en', 'zh-Hans', 'zh-Hant']) {
          expect(j.name[locale], isNotNull, reason: '${j.id} name $locale');
          expect(j.range[locale], isNotNull, reason: '${j.id} range $locale');
          // #317: every route names its source.
          expect(j.basis[locale], isNotNull, reason: '${j.id} basis $locale');
        }
      }
    });
  });

  group('every stop resolves against the gazetteer', () {
    test('nothing is unresolved', () {
      final broken = <String>[
        for (final r in resolved)
          for (final id in r.unresolved) '${r.id}: $id',
      ];
      expect(broken, isEmpty,
          reason: 'a stop the gazetteer cannot place breaks the line');
    });

    test('every stop is a gazetteer id with coordinates', () {
      for (final j in journeys) {
        for (final s in j.stops) {
          final p = byId[s.placeId];
          expect(p, isNotNull, reason: '${j.id}: ${s.placeId} not in gazetteer');
          expect(p!.located, isTrue, reason: '${j.id}: ${s.placeId} unlocated');
        }
      }
    });

    test('nothing carries a coordinate of its own', () {
      // The schema has no place for one, and that is the point: a route
      // that could name a latitude could invent a location.
      for (final raw in doc['journeys'] as List<dynamic>) {
        for (final s in (raw as Map<String, dynamic>)['stops'] as List<dynamic>) {
          final keys = (s as Map<String, dynamic>).keys.toSet();
          expect(keys.intersection(<String>{'lat', 'lon', 'll', 'coords'}),
              isEmpty);
        }
      }
    });
  });

  group('every stop carries its warrant', () {
    test('a book, a chapter and a verse on every row', () {
      for (final j in journeys) {
        for (final s in j.stops) {
          expect(s.englishBook, isNotEmpty);
          expect(s.chapter, greaterThan(0));
          expect(s.verse, greaterThan(0));
        }
      }
    });

    test('the reference is in the book the range names', () {
      for (final j in journeys) {
        final books = j.stops.map((s) => s.englishBook).toSet();
        expect(books.length, 1,
            reason: '${j.id} reads out of ${books.join(', ')}');
      }
    });

    test('a provisional stop always says WHY, in all three locales', () {
      for (final j in journeys) {
        for (final s in j.stops) {
          if (s.attested) continue;
          expect(s.note, isNotNull,
              reason: '${j.id}/${s.placeId} is provisional and silent');
          for (final locale in const <String>['en', 'zh-Hans', 'zh-Hant']) {
            expect(s.note![locale], isNotNull,
                reason: '${j.id}/${s.placeId} note $locale');
          }
        }
      }
    });

    test('a note, wherever there is one, is written in all three', () {
      for (final j in journeys) {
        for (final s in j.stops) {
          final note = s.note;
          if (note == null) continue;
          for (final locale in const <String>['en', 'zh-Hans', 'zh-Hant']) {
            expect(note[locale], isNotNull,
                reason: '${j.id}/${s.placeId} note $locale');
          }
        }
      }
    });
  });

  group('the itineraries themselves', () {
    ResolvedJourney route(String id) => resolved.firstWhere((r) => r.id == id);

    test('each opens with a start leg and nothing else does', () {
      for (final j in journeys) {
        expect(j.stops.first.leg, JourneyLeg.start, reason: j.id);
        for (final s in j.stops.skip(1)) {
          expect(s.leg, isNot(JourneyLeg.start), reason: j.id);
        }
      }
    });

    test('the first journey opens and closes at Syrian Antioch', () {
      // Acts 13:1 sends them out from there and 14:26 sails them back to
      // it. A route that dropped the return would delete half of Acts 14.
      final r = route('paul-1');
      expect(r.stops.first.place.id, 'Antioch 1');
      expect(r.stops.last.place.id, 'Antioch 1');
    });

    test('the first journey is entirely attested', () {
      expect(route('paul-1').journey.provisionalCount, 0);
    });

    test('Lystra is stop 8 and stop 10, on one marker', () {
      final r = route('paul-1');
      expect(r.ordinalsByPlace['Lystra'], <int>[8, 10]);
      expect(r.markers.where((m) => m.place.id == 'Lystra').length, 1);
    });

    test('the two Antiochs are kept apart by their ordinals', () {
      // 500 km apart on the gazetteer's own coordinates, and both are on
      // the first journey. A route that dropped the numeral would draw a
      // nonsense.
      final ids = route('paul-1').stops.map((s) => s.place.id).toSet();
      expect(ids, containsAll(<String>['Antioch 1', 'Antioch 2']));
      final a = byId['Antioch 1']!;
      final b = byId['Antioch 2']!;
      expect(haversineKm(a.lat!, a.lon!, b.lat!, b.lon!), closeTo(500, 5));
    });

    test('a sea leg is only claimed where the itinerary says so', () {
      // Paphos→Perga is Acts 13:13's ἀπέπλευσαν. If the asset ever loses
      // the distinction this is the row that notices.
      final r = route('paul-1');
      final perga = r.segments.firstWhere((s) => s.to.place.id == 'Perga');
      expect(perga.leg, JourneyLeg.sea);
      final derbe = r.segments.firstWhere((s) => s.to.place.id == 'Derbe');
      expect(derbe.leg, JourneyLeg.land);
    });

    test('every drawn journey has more than one drawable leg', () {
      for (final r in resolved) {
        expect(r.segments.length, greaterThan(1), reason: r.id);
      }
    });

    test('the style slots are in the data and distinct', () {
      // In the DATA so that inserting a journey mid-file cannot silently
      // recolour the ones after it.
      final slots = journeys.map((j) => j.style).toList();
      expect(slots.toSet().length, slots.length);
      for (final raw in doc['journeys'] as List<dynamic>) {
        expect((raw as Map<String, dynamic>)['style'], isA<num>());
      }
    });

    test('the straight-line totals are the scale they are offered as', () {
      // Sanity, not precision: these are sums of chords. If one comes out
      // an order of magnitude off, a coordinate has moved.
      for (final r in resolved) {
        expect(r.straightLineKm, greaterThan(500), reason: r.id);
        expect(r.straightLineKm, lessThan(20000), reason: r.id);
      }
    });
  });
}
