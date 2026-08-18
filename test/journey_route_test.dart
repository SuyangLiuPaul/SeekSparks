// The pure half of the journey overlays (#317).
//
// Everything a route CLAIMS is decided in `utils/journey_route.dart` and
// `constants/journey_style.dart`: which stops resolved, which legs may be
// drawn, which of them the text does not actually support, and how each
// is inked. Those are the parts that can go quietly wrong — a broken
// itinerary that silently bridges its gap draws a leg nobody claimed, and
// looks exactly like a correct one — so they are tested without a map.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/journey_style.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
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

/// Where a lane number actually moves a leg — the painter's own step,
/// taking the perpendicular of the segment's own direction of travel.
(double, double) _shift(RouteSegment s, double lane) {
  final dx = s.to.place.lon! - s.from.place.lon!;
  final dy = s.to.place.lat! - s.from.place.lat!;
  final len = math.sqrt(dx * dx + dy * dy);
  return (-dy / len * lane, dx / len * lane);
}

BibleJourney _journey(List<JourneyStop> stops, {String id = 'j'}) =>
    BibleJourney(
      id: id,
      style: 0,
      name: const <String, String>{'en': 'Test'},
      range: const <String, String>{},
      basis: const <String, String>{},
      stops: stops,
    );

void main() {
  group('resolving against the gazetteer', () {
    final byId = <String, BiblePlace>{
      'A': _place('A', 36.2, 36.16),
      'B': _place('B', 38.31, 31.17),
      'C': _place('C', 37.0, 33.0),
      // Named in scripture, site unidentified. Not missing data.
      'Nowhere': _place('Nowhere', null, null),
    };

    test('consecutive stops become one leg each', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('B', JourneyLeg.land),
          _stop('C', JourneyLeg.sea),
        ]),
        byId,
      );
      expect(r.stops.length, 3);
      expect(r.segments.length, 2);
      expect(r.segments[0].leg, JourneyLeg.land);
      expect(r.segments[1].leg, JourneyLeg.sea);
      expect(r.unresolved, isEmpty);
    });

    test('an unlocated stop BREAKS the line rather than bridging it', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('Nowhere', JourneyLeg.land),
          _stop('C', JourneyLeg.land),
        ]),
        byId,
      );
      // The wrong answer is one A→C leg: it would invent a journey the
      // itinerary never claimed, and draw it solid.
      expect(r.segments, isEmpty);
      expect(r.stops.map((s) => s.place.id), <String>['A', 'C']);
      expect(r.unresolved, <String>['Nowhere']);
    });

    test('a stop absent from the gazetteer is reported, not guessed', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('Atlantis', JourneyLeg.sea),
        ]),
        byId,
      );
      expect(r.unresolved, <String>['Atlantis']);
      expect(r.segments, isEmpty);
    });

    test('a leg out of a provisional stop is itself provisional', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('B', JourneyLeg.land, attested: false),
          _stop('C', JourneyLeg.land),
        ]),
        byId,
      );
      // Both legs touch the provisional stop, so neither may be drawn as
      // an assertion — including the one whose DESTINATION is attested.
      expect(r.segments.map((s) => s.attested), <bool>[false, false]);
    });

    test('the first stop never draws a line into itself', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('B', JourneyLeg.start),
        ]),
        byId,
      );
      expect(r.segments, isEmpty);
    });

    test('a revisited place keeps every ordinal it holds', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('B', JourneyLeg.land),
          _stop('A', JourneyLeg.land),
        ]),
        byId,
      );
      expect(r.ordinalsByPlace['A'], <int>[1, 3]);
      expect(r.markers.length, 2, reason: 'one marker per PLACE');
    });

    test('a journey that resolved to nothing is dropped', () {
      final out = resolveJourneys(
        <BibleJourney>[
          _journey(<JourneyStop>[_stop('Nowhere', JourneyLeg.start)]),
          _journey(<JourneyStop>[_stop('A', JourneyLeg.start)], id: 'k'),
        ],
        byId.values.toList(),
      );
      expect(out.map((r) => r.id), <String>['k']);
    });

    test('an aside is passed, not called at', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _aside('B'),
          _stop('C', JourneyLeg.sea),
        ]),
        byId,
      );
      // The wrong answer is two legs through B: it would draw the detour
      // to Phoenix that the whole of Acts 27 turns on their not making.
      expect(r.segments.length, 1);
      expect(r.segments[0].from.place.id, 'A');
      expect(r.segments[0].to.place.id, 'C');
      expect(r.stops.length, 3, reason: 'still drawn, just joined to nothing');
    });

    test('an aside takes no number and does not spend one', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _aside('B'),
          _stop('C', JourneyLeg.sea),
        ]),
        byId,
      );
      expect(r.stops.map((s) => s.ordinal), <int?>[1, null, 2]);
      expect(r.ordinalsByPlace.containsKey('B'), isFalse,
          reason: 'no badge at a place they never reached');
    });

    test('an UNLOCATED aside costs a marker and nothing else', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _aside('Nowhere'),
          _stop('C', JourneyLeg.land),
        ]),
        byId,
      );
      // Contrast the waypoint case above: only a waypoint was holding the
      // line together, so only a waypoint can break it.
      expect(r.unresolved, <String>['Nowhere']);
      expect(r.segments.length, 1);
    });

    test('a place both aimed at and reached is drawn as reached', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _aside('C'),
          _stop('B', JourneyLeg.sea),
          _stop('C', JourneyLeg.land),
        ]),
        byId,
      );
      final c = r.markers.firstWhere((m) => m.place.id == 'C');
      expect(c.isAside, isFalse, reason: 'the file mentioned it first');
      expect(c.ordinal, 3);
    });

    test('the straight-line total is the sum of the chords', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('B', JourneyLeg.land),
        ]),
        byId,
      );
      // Syrian to Pisidian Antioch on the gazetteer's own coordinates.
      expect(r.straightLineKm, closeTo(500.0, 1.0));
    });
  });

  group('corridor lanes', () {
    final byId = <String, BiblePlace>{
      'A': _place('A', 36.0, 36.0),
      'B': _place('B', 38.0, 32.0),
      'C': _place('C', 37.0, 34.0),
    };

    test('a corridor walked once is drawn on the chord', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('B', JourneyLeg.land),
        ]),
        byId,
      );
      expect(corridorLanes(<ResolvedJourney>[r]), <List<double>>[
        <double>[0.0]
      ]);
    });

    test('an out-and-back pair lands on OPPOSITE sides of the chord', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('B', JourneyLeg.land),
          _stop('A', JourneyLeg.land),
        ]),
        byId,
      );
      final lanes = corridorLanes(<ResolvedJourney>[r])[0];
      expect(lanes.length, 2);
      // Checked as geometry rather than as arithmetic, because the sign
      // convention is exactly the thing that is easy to get backwards:
      // the perpendicular reverses with the direction of travel, so the
      // two legs get the SAME lane number and it is the reversal that
      // separates them. Getting this wrong hides half of Acts 14.
      final out = _shift(r.segments[0], lanes[0]);
      final back = _shift(r.segments[1], lanes[1]);
      expect(out.$1, closeTo(-back.$1, 1e-9));
      expect(out.$2, closeTo(-back.$2, 1e-9));
      expect(out.$1 * out.$1 + out.$2 * out.$2, greaterThan(0.0));
    });

    test('two routes sharing a corridor are separated too', () {
      final one = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('B', JourneyLeg.land),
        ]),
        byId,
      );
      final two = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('B', JourneyLeg.sea),
        ], id: 'k'),
        byId,
      );
      final lanes = corridorLanes(<ResolvedJourney>[one, two]);
      expect(lanes[0][0], isNot(lanes[1][0]));
    });

    test('a corridor nobody else uses is unaffected by a busy one', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('B', JourneyLeg.land),
          _stop('A', JourneyLeg.land),
          _stop('C', JourneyLeg.land),
        ]),
        byId,
      );
      final lanes = corridorLanes(<ResolvedJourney>[r])[0];
      expect(lanes[2], 0.0, reason: 'A→C is walked once');
    });
  });

  group('the visual grammar', () {
    test('sea, land and unknown are three different dashes', () {
      final sea = journeyDash(JourneyLeg.sea, attested: true);
      final land = journeyDash(JourneyLeg.land, attested: true);
      final unknown = journeyDash(JourneyLeg.unknown, attested: true);
      expect(land, isEmpty, reason: 'solid');
      expect(sea, isNot(unknown));
      expect(sea.first, greaterThan(unknown.first));
    });

    test('provisional overrides the manner of travel entirely', () {
      // What the text will not support is drawn as dots whatever the verb
      // would have been: the manner is not the claim in question.
      for (final leg in JourneyLeg.values) {
        expect(journeyDash(leg, attested: false),
            journeyDash(JourneyLeg.land, attested: false));
      }
      expect(journeyDash(JourneyLeg.sea, attested: false), isNotEmpty);
    });

    test('a provisional leg is thin AND faint AND dotted, never one', () {
      expect(journeyStrokeWidth(attested: false, selected: true),
          lessThan(journeyStrokeWidth(attested: true, selected: false)));
      expect(journeyOpacity(attested: false, dimmed: false),
          lessThan(journeyOpacity(attested: true, dimmed: false)));
      expect(journeyDash(JourneyLeg.land, attested: false), isNotEmpty);
    });

    test('the palette differs between light and dark', () {
      final light = journeyPalette(WbColors.light);
      final dark = journeyPalette(WbColors.dark);
      expect(light.length, dark.length);
      for (var i = 0; i < light.length; i++) {
        expect(light[i].colour, isNot(dark[i].colour),
            reason: 'a hue legible on white is invisible on #101A2B');
      }
    });

    test('a style slot beyond the palette wraps rather than crashing', () {
      final p = journeyPalette(WbColors.light);
      expect(journeyStyleFor(WbColors.light, p.length).colour, p.first.colour);
      expect(journeyStyleFor(WbColors.light, -1).colour, p[1 % p.length].colour);
    });
  });
}
