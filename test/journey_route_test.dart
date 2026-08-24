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
import 'package:seeksparks/constants/ui_strings.dart';
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
      expect(r.ordinalsByMarker[markerKeyFor(byId['A']!)], <int>[1, 3]);
      expect(r.markers.length, 2, reason: 'one marker per POSITION');
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
      expect(r.ordinalsByMarker.containsKey(markerKeyFor(byId['B']!)), isFalse,
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

  group('stations the gazetteer cannot tell apart', () {
    // Three DIFFERENT places — three names in the text, three ids — that
    // the gazetteer answers with one and the same point. This is not a
    // hypothetical: eleven of Numbers 33's camps do exactly this.
    final byId = <String, BiblePlace>{
      'A': _place('A', 36.0, 36.0),
      'Same1': _place('Same1', 30.0, 34.0),
      'Same2': _place('Same2', 30.0, 34.0),
      'Same3': _place('Same3', 30.0, 34.0),
      'Z': _place('Z', 31.5, 35.5),
      'Nowhere': _place('Nowhere', null, null),
    };

    ResolvedJourney run() => resolveJourney(
          _journey(<JourneyStop>[
            _stop('A', JourneyLeg.start),
            _stop('Same1', JourneyLeg.land),
            _stop('Same2', JourneyLeg.land),
            _stop('Same3', JourneyLeg.land),
            _stop('Z', JourneyLeg.land),
          ]),
          byId,
        );

    test('no leg is drawn between two camps at one point', () {
      final r = run();
      // The naive answer emits five stops and four legs, two of which are
      // zero kilometres long: invisible, unhittable, and counted in the
      // total the panel prints.
      expect(r.stops.length, 5, reason: 'every camp the text names is kept');
      expect(r.segments.length, 2);
      expect(r.segments.map((s) => s.from.place.id), <String>['A', 'Same3']);
      expect(r.segments.map((s) => s.to.place.id), <String>['Same1', 'Z']);
      for (final s in r.segments) {
        expect(s.km, greaterThan(1.0));
      }
    });

    test('a run is entered at its first camp and left from its last', () {
      // The three camps are one position, so this changes no geometry —
      // but the leg card names both ends, and Numbers 33's own sentence
      // is "they departed from X and camped at Y". Arriving is what the
      // run's FIRST camp records and departing is what its LAST one
      // records, so those are the two the legs must name.
      final r = run();
      expect(r.segments.first.to.place.id, 'Same1');
      expect(r.segments.last.from.place.id, 'Same3');
    });

    test('the run is one marker carrying every ordinal in it', () {
      final r = run();
      expect(r.markers.length, 3, reason: 'A, the shared point, Z');
      expect(r.ordinalsByMarker[markerKeyFor(byId['Same2']!)], <int>[2, 3, 4]);
    });

    test('the collapse is counted, so a surface can say it plainly', () {
      final r = run();
      expect(r.runs.length, 3);
      expect(r.collapsedRuns.length, 1);
      expect(r.collapsedRuns.single.stops.map((s) => s.place.id),
          <String>['Same1', 'Same2', 'Same3']);
      expect(r.collapsedStopCount, 3);
    });

    test('a place LEFT and returned to is not a run', () {
      // The difference that matters: Same1→Same2 is two names our data
      // cannot separate, while A→Z→A is a journey that went somewhere and
      // came back. Grouping the second would delete the trip.
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('Z', JourneyLeg.land),
          _stop('A', JourneyLeg.land),
        ]),
        byId,
      );
      expect(r.collapsedRuns, isEmpty);
      expect(r.segments.length, 2);
    });

    test('an unresolved camp breaks the run as well as the line', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('Same1', JourneyLeg.start),
          _stop('Nowhere', JourneyLeg.land),
          _stop('Same2', JourneyLeg.land),
        ]),
        byId,
      );
      // Same1 and Same2 share a point, but a camp the gazetteer cannot
      // place stands between them. Running them together would say the
      // travellers never moved, when in fact we do not know that they
      // did not travel a hundred miles and come back.
      expect(r.collapsedRuns, isEmpty);
      expect(r.segments, isEmpty);
      expect(r.unresolved, <String>['Nowhere']);
    });

    test('a run carries doubt at its ends and nowhere else', () {
      final middle = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('Same1', JourneyLeg.land),
          _stop('Same2', JourneyLeg.land, attested: false),
          _stop('Same3', JourneyLeg.land),
          _stop('Z', JourneyLeg.land),
        ]),
        byId,
      );
      // Both legs are supported at both of THEIR ends — A to Same1, and
      // Same3 to Z — and the doubtful camp is an end of neither. Dotting
      // them because of it would print "the text does not say they went
      // from here to Z" over a leg the text gives in full.
      expect(middle.segments.map((s) => s.attested), <bool>[true, true]);

      final edge = resolveJourney(
        _journey(<JourneyStop>[
          _stop('A', JourneyLeg.start),
          _stop('Same1', JourneyLeg.land),
          _stop('Same2', JourneyLeg.land),
          _stop('Same3', JourneyLeg.land, attested: false),
          _stop('Z', JourneyLeg.land),
        ]),
        byId,
      );
      // The same doubt at the camp the run is LEFT from is an end, and
      // the outgoing leg is provisional exactly as it would be without
      // any merging at all.
      expect(edge.segments.map((s) => s.attested), <bool>[true, false]);
    });
  });

  group('the numbers on a merged badge', () {
    test('a single stop is just its number', () {
      expect(formatOrdinals(<int>[7]), '7');
    });

    test('a consecutive run collapses to its ends', () {
      expect(formatOrdinals(<int>[18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28]),
          '18–28');
    });

    test('a gap is NEVER written as a range', () {
      // Lystra is stops 8 and 10 of the first journey, with Derbe between
      // them. `8–10` would say they were at this point for three stops
      // running, which is a claim about the itinerary and a false one.
      expect(formatOrdinals(<int>[8, 10]), '8,10');
    });

    test('mixed input keeps both forms', () {
      expect(formatOrdinals(<int>[1, 2, 3, 7, 9]), '1–3,7,9');
    });

    test('even a pair of two takes the dash', () {
      // `2–3` is no shorter than `2,3`, so this is not about width: the
      // dash means consecutive and the comma means a gap, and a badge that
      // switched notation at some length threshold would make the reader
      // learn two rules to read one map.
      expect(formatOrdinals(<int>[2, 3]), '2–3');
    });

    test('nothing to say is said with nothing', () {
      expect(formatOrdinals(const <int>[]), '');
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

  group('what a leg passes without calling at', () {
    final byId = <String, BiblePlace>{
      'FairHavens': _place('FairHavens', 34.9, 24.8),
      'Phoenix': _place('Phoenix', 35.2, 24.0),
      'Cauda': _place('Cauda', 34.8, 24.1),
      'Malta': _place('Malta', 35.9, 14.4),
    };

    ResolvedJourney voyage() => resolveJourney(
          _journey(<JourneyStop>[
            _stop('FairHavens', JourneyLeg.start),
            _aside('Phoenix'),
            _stop('Cauda', JourneyLeg.sea),
            _stop('Malta', JourneyLeg.sea),
          ]),
          byId,
        );

    test('the aside belongs to the leg that steps over it', () {
      final r = voyage();
      // Acts 27:12 — they set out for Phoenix, and this is the leg the
      // northeaster made of it. A reader who clicks the open-sea line
      // has no other way to learn that.
      expect(r.asidesOn(r.segments[0]).map((s) => s.place.id), <String>[
        'Phoenix',
      ]);
    });

    test('a leg the narrative steps over nothing on carries nothing', () {
      final r = voyage();
      expect(r.asidesOn(r.segments[1]), isEmpty);
    });

    test('an aside outside the leg is not borrowed by it', () {
      final r = resolveJourney(
        _journey(<JourneyStop>[
          _stop('FairHavens', JourneyLeg.start),
          _stop('Cauda', JourneyLeg.sea),
          _aside('Phoenix'),
          _stop('Malta', JourneyLeg.sea),
        ]),
        byId,
      );
      // Same three legs' worth of stops, one place moved. The wrong
      // answer puts Phoenix on both legs, or on the earlier one.
      expect(r.asidesOn(r.segments[0]), isEmpty);
      expect(r.asidesOn(r.segments[1]).map((s) => s.place.id), <String>[
        'Phoenix',
      ]);
    });
  });

  group('pointing at a leg', () {
    // A projection with no curvature and no inversion, so the arithmetic
    // below is readable as pixels: x is longitude, y is latitude.
    (double, double) project(double lat, double lon) => (lon, lat);

    BiblePlace at(String id, double x, double y) => _place(id, y, x);

    /// A route running from (0,0) to (100,0) in projected pixels.
    ResolvedJourney line(String id, double y) => resolveJourney(
          _journey(<JourneyStop>[
            _stop('$id.a', JourneyLeg.start),
            _stop('$id.b', JourneyLeg.land),
          ], id: id),
          <String, BiblePlace>{
            '$id.a': at('$id.a', 0, y),
            '$id.b': at('$id.b', 100, y),
          },
        );

    JourneyLegHit? hit(
      List<ResolvedJourney> routes,
      double x,
      double y, {
      List<List<double>>? lanes,
      String? selected,
    }) =>
        hitJourneyLeg(
          routes: routes,
          lanes: lanes ?? <List<double>>[for (final _ in routes) <double>[0.0]],
          project: project,
          x: x,
          y: y,
          selectedRouteId: selected,
        );

    test('a tap near the line finds it', () {
      expect(hit(<ResolvedJourney>[line('j', 0)], 50, 2),
          const JourneyLegHit(0, 0));
    });

    test('a tap nowhere near it finds nothing', () {
      // The whole point of returning null rather than the closest leg:
      // a tap on open water must be able to mean "deselect".
      expect(hit(<ResolvedJourney>[line('j', 0)], 50, 40), isNull);
    });

    test('the tolerance is the feature, not a rounding error', () {
      // A 2.2px stroke cannot be hit by a fingertip, so the target is
      // deliberately wider than the ink — but bounded, or every tap in
      // the Mediterranean lands on the voyage to Rome.
      final j = <ResolvedJourney>[line('j', 0)];
      expect(hit(j, 50, 9), isNotNull);
      expect(hit(j, 50, 9.5), isNull);
    });

    test('the nearer of two legs wins', () {
      final routes = <ResolvedJourney>[line('j', 0), line('k', 6)];
      expect(hit(routes, 50, 5), const JourneyLegHit(1, 0));
      expect(hit(routes, 50, 1), const JourneyLegHit(0, 0));
    });

    test('the target moves with the lane the painter drew in', () {
      // The lanes are passed in rather than recomputed precisely so this
      // cannot drift from the drawing: a leg shifted 10px off its chord
      // to clear an out-and-back partner must be hit where it is DRAWN,
      // not where its coordinates are.
      final routes = <ResolvedJourney>[line('j', 0)];
      final lanes = <List<double>>[
        <double>[10.0]
      ];
      expect(hit(routes, 50, 10, lanes: lanes), isNotNull);
      expect(hit(routes, 50, 0, lanes: lanes), isNull);
    });

    test('a tap past the end of a leg misses its infinite line', () {
      // Without the clamp, a tap 100px beyond Cauda would select the leg
      // that ends at Cauda, because it sits on that leg's projection.
      expect(hit(<ResolvedJourney>[line('j', 0)], 200, 0), isNull);
    });

    test('at a crossing the route being read is the one you get', () {
      // Ties resolve the way the drawing resolves them: the selected
      // route is painted last, so it is the one on top.
      final routes = <ResolvedJourney>[line('j', 0), line('k', 0)];
      expect(hit(routes, 50, 0), const JourneyLegHit(1, 0),
          reason: 'last painted wins when nothing is selected');
      expect(hit(routes, 50, 0, selected: 'j'), const JourneyLegHit(0, 0));
    });

    test('no routes, and short lanes, are not crashes', () {
      expect(hit(<ResolvedJourney>[], 50, 0), isNull);
      expect(
        hitJourneyLeg(
          routes: <ResolvedJourney>[line('j', 0)],
          lanes: <List<double>>[<double>[]],
          project: project,
          x: 50,
          y: 0,
        ),
        const JourneyLegHit(0, 0),
        reason: 'a missing lane means the chord, not an exception',
      );
    });
  });

  group('what the overlay says, in every locale it says it in', () {
    // Each `_s(key, fallback)` in the Atlas carries an English default, so
    // a key that is missing or half-translated does not throw, does not
    // fail a widget test, and ships an English sentence to a Chinese
    // reader. The only thing that catches it is counting the table.
    final keys = uiStrings.keys.where((k) => k.startsWith('journey'));

    test('every journey string exists in all three locales', () {
      for (final k in keys) {
        for (final l in const <String>['en', 'zh-Hans', 'zh-Hant']) {
          expect(uiStrings[k]![l], isNotNull, reason: '$k has no $l');
          expect(uiStrings[k]![l], isNotEmpty, reason: '$k is blank in $l');
        }
      }
    });

    test('a placeholder kept in one locale is kept in all of them', () {
      // Worse than a missing translation: "{n} km" becomes a Chinese
      // sentence with no number in it, and reads as a finished string.
      for (final k in keys) {
        final en = uiStrings[k]!['en']!;
        for (final p in const <String>['{n}', '{p}']) {
          if (!en.contains(p)) continue;
          for (final l in const <String>['zh-Hans', 'zh-Hant']) {
            expect(uiStrings[k]![l], contains(p),
                reason: '$k drops $p in $l');
          }
        }
      }
    });

    test('the leg card has a string for every claim it makes', () {
      // Named one by one rather than counted, so that deleting a key the
      // card still calls fails here instead of on someone's screen.
      for (final k in const <String>[
        'journeyLegHeader',
        'journeyLegKm',
        'journeyLegUnattested',
        'journeyLegAside',
        'journeyLegWarrant',
      ]) {
        expect(uiStrings.containsKey(k), isTrue, reason: '$k is missing');
      }
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

    test('the palette holds a hue for every journey that ships', () {
      // The wrap below is a safety net, not a plan: five routes against a
      // four-hue palette would silently draw the wilderness itinerary in
      // the first journey's amber, and the two overlap across Sinai.
      for (final c in <WbColors>[WbColors.light, WbColors.dark]) {
        final p = journeyPalette(c);
        expect(p.length, greaterThanOrEqualTo(5));
        expect(p.map((s) => s.colour.toARGB32()).toSet().length, p.length,
            reason: 'two routes inked the same');
      }
    });

    test('a style slot beyond the palette wraps rather than crashing', () {
      final p = journeyPalette(WbColors.light);
      expect(journeyStyleFor(WbColors.light, p.length).colour, p.first.colour);
      expect(journeyStyleFor(WbColors.light, -1).colour, p[1 % p.length].colour);
    });
  });
}
