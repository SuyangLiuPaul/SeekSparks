// The itinerary panel must show every stop the text names, not only the
// ones the gazetteer can draw (#317). A stop with no coordinate used to
// vanish from the list as well as the map; this pins that it is kept as
// an [UnplacedStop] and surfaced through [ResolvedJourney.itineraryRows].

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/bible_journey.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/journey_route.dart';

BiblePlace _place(String id, double? lat, double? lon) => BiblePlace(
      id: id,
      name: id,
      ordinal: null,
      simplified: null,
      traditional: null,
      lat: lat,
      lon: lon,
      refs: const <PlaceRef>[],
    );

JourneyStop _stop(
  String place,
  JourneyLeg leg, {
  bool attested = true,
  JourneyStopKind kind = JourneyStopKind.waypoint,
}) =>
    JourneyStop(
      placeId: place,
      englishBook: 'Acts',
      chapter: 13,
      verse: 1,
      leg: leg,
      attested: attested,
      kind: kind,
      note: null,
    );

JourneyStop _aside(String place) =>
    _stop(place, JourneyLeg.unknown, kind: JourneyStopKind.aside);

BibleJourney _journey(List<JourneyStop> stops, {String id = 'j'}) =>
    BibleJourney(
      id: id,
      style: 0,
      mark: JourneyMark.round,
      name: const <String, String>{'en': 'Test'},
      range: const <String, String>{},
      basis: const <String, String>{},
      stops: stops,
    );

void main() {
  final byId = <String, BiblePlace>{
    'A': _place('A', 36.2, 36.16),
    'B': _place('B', 38.31, 31.17),
    'C': _place('C', 37.0, 33.0),
    // Named in scripture, site unidentified. Not missing data.
    'Nowhere': _place('Nowhere', null, null),
    // Not in the gazetteer at all.
  };

  group('ResolvedJourney.unplaced', () {
    test('an unlocated waypoint is kept, not dropped', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('Nowhere', JourneyLeg.land),
          _stop('C', JourneyLeg.land),
        ]),
        byId,
      );
      expect(r.unplaced.length, 1);
      expect(r.unplaced.first.index, 1);
      expect(r.unplaced.first.stop.placeId, 'Nowhere');
      expect(r.unplaced.first.absent, isFalse);
      expect(r.unplaced.first.place, isNotNull);
    });

    test('a stop the gazetteer does not hold is kept as absent', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('Atlantis', JourneyLeg.sea),
        ]),
        byId,
      );
      expect(r.unplaced.single.absent, isTrue);
      expect(r.unplaced.single.place, isNull);
    });

    test('the ids the panel prints are unchanged', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('Nowhere', JourneyLeg.land),
          _stop('C', JourneyLeg.land),
          _stop('Atlantis', JourneyLeg.sea),
        ]),
        byId,
      );
      expect(r.unresolved, <String>['Nowhere', 'Atlantis']);
    });

    test('every stop the text names has a row, in narrative order', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('Nowhere', JourneyLeg.land),
          _stop('C', JourneyLeg.land),
          _stop('Atlantis', JourneyLeg.sea),
        ]),
        byId,
      );
      expect(r.itineraryRows.length, 4);
      expect(r.itineraryRows.map((x) => x.index), <int>[0, 1, 2, 3]);
      expect(
        r.itineraryRows.map((x) => x.stop.placeId),
        <String>['A', 'Nowhere', 'C', 'Atlantis'],
      );
    });

    test('an unlocated aside gets a row too', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _aside('Nowhere'),
          _stop('C', JourneyLeg.land),
        ]),
        byId,
      );
      expect(r.itineraryRows.length, 3);
      expect(r.itineraryRows[1].placed, isNull);
      expect(r.itineraryRows[1].unplaced, isNotNull);
      expect(r.itineraryRows[1].stop.placeId, 'Nowhere');
    });

    test('the numbers a reader sees do not move', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('Nowhere', JourneyLeg.land),
          _stop('C', JourneyLeg.land),
        ]),
        byId,
      );
      expect(r.stops.map((s) => s.ordinal), <int?>[1, 2]);
    });
  });

  group('atlas_page source ratchet', () {
    test('the panel walks the itinerary, not the drawing', () {
      final src = File('lib/pages/atlas_page.dart').readAsStringSync();
      expect(src.contains('for (final s in journey.stops)'), isFalse);
      expect(src.contains('journey.itineraryRows'), isTrue);
    });
  });
}
