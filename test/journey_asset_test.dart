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
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/book_names.dart' show standardBookOrder;

/// The books a journey's declared English range names.
///
/// The vocabulary is the canon's own list, matched as substrings, with any
/// hit that is contained in a longer hit dropped — so `1 John 1:1 – 2:2`
/// declares `1 John` and not also `John`. That collision is the only one in
/// the 66: the numbered families (`N John`, `N Kings`, `N Samuel`,
/// `N Corinthians`, …) are the only names that contain another name.
/// `Judges` does not contain `Jude`.
Set<String> booksNamedIn(String range) {
  final hits = <String>{
    for (final b in standardBookOrder)
      if (range.contains(b)) b,
  };
  return <String>{
    for (final b in hits)
      if (!hits.any((o) => o != b && o.contains(b))) b,
  };
}

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

    test('the marker count the row prints is the count the map paints', () {
      // Measured over the shipped assets, and it is the whole reason the
      // row now prints it: a reader who ticks the wilderness box reads
      // "42 stops" and can count 18 dots. `markers` is what
      // `place_map.dart:1201` walks, so this is the drawn number and not
      // a second estimate of it.
      const expected = <String, int>{
        'paul-1': 10,
        'paul-2': 18,
        'paul-3': 20,
        'paul-rome': 16,
        'exodus-wilderness': 18,
        'jesus-mark': 11,
        'jacob': 9,
        'abraham': 13,
        'ark': 7,
      };
      for (final r in resolved) {
        expect(r.markers.length, expected[r.id],
            reason: '${r.id}: the map draws one marker per POSITION');
      }
      // paul-rome draws MORE markers than it has waypoints, because its
      // two asides take hollow markers without being stops. Any wording
      // of the form "only N can be drawn" would be false here.
      final rome = resolved.firstWhere((r) => r.id == 'paul-rome');
      expect(rome.markers.length,
          greaterThan(rome.journey.waypointCount));
    });
  });

  // The stops the gazetteer cannot place, named one by one.
  //
  // A typo in a place id and a genuinely unidentified site arrive here as
  // the same thing — an id that does not resolve — and only a list written
  // by hand can tell a reader which happened. So the guard is two-sided:
  // an id NOT in this map fails the build, and an id in it that starts
  // resolving fails the build too, because that means the list is stale
  // and the route has quietly begun drawing a line it says it refuses to.
  //
  //   * Pi-hahiroth (Num 33:7) — Exodus 14:2 gives it with Migdol and
  //     Baal-zephon, and the gazetteer places none of the three. Where the
  //     line breaks is precisely where the sea crossing is argued about,
  //     which is the right place for it to break.
  //   * Hor-haggidgad (Num 33:32) — named, unlocated, not bridged.
  //   * Mahanaim (Gen 32:2) — Jacob names the place; the gazetteer carries
  //     the name with no coordinate. The break falls on the Jordan
  //     crossing, which is where the route is least certain anyway.
  //   * Kiriath-jearim (1 Sa 7:1) — the ark rests here twenty years and
  //     the gazetteer carries the name with no coordinate. The break
  //     falls on the twenty-year stop, so the line cannot imply the ark
  //     went straight up to Jerusalem.
  const unlocatedByDesign = <String, Set<String>>{
    'exodus-wilderness': <String>{'Pi-hahiroth', 'Hor-haggidgad'},
    'jacob': <String>{'Mahanaim'},
    'ark': <String>{'Kiriath-jearim'},
  };

  group('every stop resolves against the gazetteer', () {
    test('nothing is unresolved but what is enumerated', () {
      final broken = <String>[
        for (final r in resolved)
          for (final id in r.unresolved)
            if (!(unlocatedByDesign[r.id] ?? const <String>{}).contains(id))
              '${r.id}: $id',
      ];
      expect(broken, isEmpty,
          reason: 'a stop the gazetteer cannot place breaks the line');
    });

    test('everything enumerated really is still unresolved', () {
      for (final e in unlocatedByDesign.entries) {
        final r = resolved.firstWhere((r) => r.id == e.key);
        expect(r.unresolved.toSet(), e.value,
            reason: '${e.key}: the exemption list has drifted from the data');
      }
    });

    test('every stop is a gazetteer id, located or knowingly not', () {
      for (final j in journeys) {
        for (final s in j.stops) {
          final p = byId[s.placeId];
          expect(p, isNotNull, reason: '${j.id}: ${s.placeId} not in gazetteer');
          if (p!.located) continue;
          expect(unlocatedByDesign[j.id] ?? const <String>{},
              contains(s.placeId),
              reason: '${j.id}: ${s.placeId} unlocated and unaccounted for');
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

    // The panel's header counts the asset (waypointCount); the list under
    // it must count the same thing, or a stop the gazetteer cannot place
    // reaches no surface at all (#317).
    test('every camp the text names has a row of its own', () {
      for (final r in resolved) {
        expect(r.itineraryRows.length, r.journey.stops.length, reason: r.id);
      }
    });

    test('the two unlocated camps are rows, with their verses', () {
      final r = resolved.firstWhere((r) => r.id == 'exodus-wilderness');
      expect(r.unplaced.map((u) => u.stop.placeId),
          <String>['Pi-hahiroth', 'Hor-haggidgad']);
      expect(r.unplaced.map((u) => u.index), <int>[3, 28]);
      expect(
        r.unplaced.map((u) => (u.stop.chapter, u.stop.verse)),
        <(int, int)>[(33, 7), (33, 32)],
      );
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

    // #317: this test now does what its name says, and did not before.
    //
    // It used to assert `j.stops.map((s) => s.englishBook).toSet().length
    // == 1` and never once looked at `range`. That was a proxy which held
    // only while every shipped range named one book, and it would have
    // passed a journey declaring "Acts 13:1 – 14:28" whose stops all cited
    // John — the exact failure the name claims to catch.
    //
    // `ark` is the first route whose narrative genuinely crosses a book
    // boundary (1 Samuel 4 into 2 Samuel 6), as any Samuel/Kings or
    // Kings/Chronicles route will, so the proxy had to go. The replacement
    // is the claim in the name: a stop may only cite a book its own
    // declared range names.
    //
    // One-directional on purpose. The range is the narrative span; the
    // stops are point citations. A range MAY name a book no stop happens
    // to cite — ark's "2 Samuel 6" is where the arrival is told and only
    // one verse of it is a stop. The direction that matters is the other
    // one: a stop citing a book the route never claimed to be reading is a
    // route reading out of somewhere it did not say.
    //
    // Only the ENGLISH range is scanned: `englishBook` is English, and the
    // localised ranges print localised book names.
    test('the reference is in the book the range names', () {
      for (final j in journeys) {
        final declared = booksNamedIn(j.range['en']!);
        expect(declared, isNotEmpty,
            reason: '${j.id}: the range names no book at all');
        for (final s in j.stops) {
          expect(declared, contains(s.englishBook),
              reason: '${j.id}: a stop cites ${s.englishBook}, '
                  'which "${j.range['en']}" never names');
        }
      }
    });

    test('a range names each of its books, longest form winning', () {
      // The eight shipped ranges and the ninth, read this run.
      expect(booksNamedIn('Acts 13:1 – 14:28'), <String>{'Acts'});
      expect(booksNamedIn('Numbers 33:1 - 49'), <String>{'Numbers'});
      expect(booksNamedIn('1 Samuel 4 – 2 Samuel 6'),
          <String>{'1 Samuel', '2 Samuel'});
      // The one collision in the canon: a numbered book contains the bare
      // one. Without the longest-hit rule this would also declare 'John'.
      expect(booksNamedIn('1 John 1:1 – 2:2'), <String>{'1 John'});
      // And the near-miss that is NOT a collision, so nobody "fixes" it.
      expect(booksNamedIn('Judges 3:1 – 4:24'), <String>{'Judges'});
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
      expect(r.ordinalsByMarker[markerKeyFor(byId['Lystra']!)], <int>[8, 10]);
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

    test('all four Acts itineraries ship', () {
      expect(journeys.map((j) => j.id),
          containsAll(<String>['paul-1', 'paul-2', 'paul-3', 'paul-rome']));
    });

    test('the third journey walks the leg the company sailed', () {
      // Acts 20:13: the ship went round to Assos and Paul went over land
      // (πεζεύειν). One leg, two modes, and the line is drawn for the man
      // the itinerary is about.
      final assos = route('paul-3')
          .segments
          .firstWhere((s) => s.to.place.id == 'Assos');
      expect(assos.leg, JourneyLeg.land);
      expect(assos.from.place.id, 'Troas');
    });

    test('the third journey crosses to Macedonia without saying how', () {
      // Acts 20:1 says he departed for Macedonia and refuses the manner.
      // Drawing it solid would put him on a road the text never gave him.
      final r = route('paul-3');
      final leg =
          r.segments.firstWhere((s) => s.from.place.id == 'Ephesus');
      expect(leg.leg, JourneyLeg.unknown);
      expect(r.ordinalsByMarker[markerKeyFor(byId['Macedonia']!)], <int>[5, 7],
          reason: 'entered twice — 20:1 and again at 20:3, the plot');
    });

    test('the voyage to Rome names two places it never reached', () {
      final r = route('paul-rome');
      final asides =
          r.stops.where((s) => s.isAside).map((s) => s.place.id).toList();
      expect(asides, <String>['Phoenix', 'Syrtis']);
      expect(r.journey.asideCount, 2);
      expect(r.journey.waypointCount, r.journey.stops.length - 2);
    });

    test('no leg is ever drawn to or from an aside', () {
      for (final r in resolved) {
        for (final s in r.segments) {
          expect(s.from.isAside, isFalse, reason: '${r.id} out of an aside');
          expect(s.to.isAside, isFalse, reason: '${r.id} into an aside');
        }
      }
    });

    test('the storm runs Fair Havens straight to Cauda', () {
      // Phoenix sits between them in the file because Acts 27:12 puts it
      // there. If it ever joins the line, the map draws a harbour call
      // that the next sixteen verses exist to say did not happen.
      final r = route('paul-rome');
      final cauda = r.segments.firstWhere((s) => s.to.place.id == 'Cauda');
      expect(cauda.from.place.id, 'Fair Havens');
    });

    test('an aside says on its own row what it is', () {
      for (final j in journeys) {
        for (final s in j.stops) {
          if (!s.isAside) continue;
          expect(s.note, isNotNull,
              reason: '${j.id}/${s.placeId} is an aside and silent');
          for (final locale in const <String>['en', 'zh-Hans', 'zh-Hant']) {
            expect(s.note![locale], isNotNull,
                reason: '${j.id}/${s.placeId} note $locale');
          }
        }
      }
    });

    test('the numbers a reader sees are 1..n with no gaps', () {
      // Asides take no number, so the badges must still run unbroken over
      // the track alone — a gap at 9 would read as a stop gone missing.
      for (final r in resolved) {
        final seen = <int>[
          for (final s in r.stops)
            if (s.ordinal != null) s.ordinal!,
        ];
        expect(seen, List<int>.generate(seen.length, (i) => i + 1),
            reason: r.id);
        // A waypoint the gazetteer cannot place takes no number, because
        // it is never drawn. The badges still have to run unbroken over
        // what IS drawn, so the expected count is the waypoints minus
        // those — computed here rather than hardcoded, so the row keeps
        // working when the exemption list changes.
        final lost = r.journey.stops
            .where((s) => !s.isAside && r.unresolved.contains(s.placeId))
            .length;
        expect(seen.length, r.journey.waypointCount - lost, reason: r.id);
      }
    });

    test('no route draws a leg of no length', () {
      // A zero-length leg is invisible, unhittable, and counted — it pads
      // the segment total a panel prints with lines a reader can neither
      // see nor click. Where two consecutive stations share a point the
      // answer is one marker, not a line from a place to itself.
      for (final r in resolved) {
        for (final s in r.segments) {
          expect(s.km, greaterThan(0.0),
              reason: '${r.id}: ${s.from.place.id} → ${s.to.place.id}');
        }
      }
    });

    test("the Lord's itinerary is one evangelist, not a harmony", () {
      // The whole framing of this route. A harmony of the four Gospels
      // is a reconstruction, and a reconstruction drawn as a line is the
      // thing this feature exists not to do. So the route is Mark's own
      // sequence, and the general one-book rule above is not enough to
      // say so: this row names the book.
      final j = journeys.firstWhere((j) => j.id == 'jesus-mark');
      expect(j.stops.every((s) => s.englishBook == 'Mark'), isTrue);
      expect(j.stops.first.placeId, 'Nazareth');
      expect(j.stops.first.chapter, 1);
      expect(j.stops.first.verse, 9);
      // 11:11 is where the travelling stops, and the route says so on
      // its face rather than trailing off. Everything after it happens
      // inside Jerusalem, where the gazetteer gives Gethsemane and
      // Golgotha Jerusalem's own coordinate.
      expect(j.stops.last.chapter, 11);
      expect(j.stops.last.verse, 11);
    });

    test('the Markan route draws no region that is another place', () {
      // The failure this route was built around: a gazetteer entry for a
      // REGION carries a point, and that point is often a city's. Judea
      // is Jerusalem's own coordinate, the Decapolis is Damascus's,
      // Galilee is Nazareth's, Dalmanutha is Magadan's — Matthew's
      // identification, not Mark's word — and the Jordan is one point
      // for the whole river. Mark names every one of them, and drawing
      // any would put Jesus where the text does not. If one is ever
      // added, this row is what notices.
      final j = journeys.firstWhere((j) => j.id == 'jesus-mark');
      final drawn = j.stops.map((s) => s.placeId).toSet();
      for (final banned in const <String>[
        'Judea', 'Decapolis', 'Galilee', 'Dalmanutha', 'Magadan',
        'Jordan', 'Gethsemane', 'Golgotha',
      ]) {
        expect(drawn, isNot(contains(banned)),
            reason: '$banned carries another place\'s point');
      }
      // Bethany is the same trap from the other side: the gazetteer
      // holds two, with IDENTICAL reference lists, so it cannot pick for
      // us and the ordinal has to be in the data.
      expect(drawn, contains('Bethany 1'));
      expect(drawn, isNot(contains('Bethany')));
    });

    test('Sidon is provisional because our own two editions disagree', () {
      // Mark 7:31 is a textual split, and the app ships both sides of
      // it: the critical text has Jesus going THROUGH Sidon, while the
      // KJV's Byzantine reading has him departing FROM the coasts of
      // Tyre and Sidon, which places him at neither. Drawn as a dotted
      // stop rather than dropped, so a reader comparing a printed atlas
      // can see where its stop came from.
      final j = journeys.firstWhere((j) => j.id == 'jesus-mark');
      final sidon = j.stops.firstWhere((s) => s.placeId == 'Sidon');
      expect(sidon.attested, isFalse);
      expect(sidon.isAside, isFalse);
      expect(j.provisionalCount, 1);
      for (final locale in const <String>['en', 'zh-Hans', 'zh-Hant']) {
        expect(sidon.localizedNote(locale), isNotNull);
      }
    });

    test('no leg of the Markan route claims a voyage', () {
      // Mark is full of boats, and not one crossing can be drawn: every
      // one of them departs from or arrives at a place the gazetteer
      // cannot locate — a solitary place (6:32), the country of the
      // Gerasenes (5:1, absent entirely), Dalmanutha (8:10). A `sea` leg
      // here would be a long dash drawn over dry land between two towns
      // the boat never ran between, so the crossings are dashed as
      // unknown and the basis says why. This row is the guard: if a sea
      // leg ever appears, the coastline has been guessed at.
      final r = route('jesus-mark');
      expect(r.segments.any((s) => s.leg == JourneyLeg.sea), isFalse);
      expect(r.segments.where((s) => s.leg == JourneyLeg.unknown).length, 5);
    });

    test('the wilderness itinerary ships, all 42 stations of it', () {
      // Numbers 33:3-49. The count is asserted because this is the one
      // route in scripture the text itself calls a list: 33:2 says Moses
      // wrote the stages down at the LORD's command, so a missing camp is
      // a dropped verse and not a difference of scholarly opinion.
      final j = journeys.firstWhere((j) => j.id == 'exodus-wilderness');
      expect(j.stops.length, 42);
      expect(j.stops.first.placeId, 'Rameses');
      expect(j.stops.last.placeId, 'Abel-shittim');
      expect(j.stops.every((s) => s.chapter == 33), isTrue);
    });

    test('the stations run down the chapter and never back up it', () {
      final j = journeys.firstWhere((j) => j.id == 'exodus-wilderness');
      var last = 0;
      for (final s in j.stops) {
        expect(s.verse, greaterThanOrEqualTo(last), reason: s.placeId);
        last = s.verse;
      }
      expect(last, lessThanOrEqualTo(49), reason: 'the range says 33:1-49');
    });

    test('the wilderness route knows how much of itself is one point', () {
      // The finding that shaped the whole feature: the uncertainty on this
      // route is not in the ORDER — the text gives that — but in the
      // gazetteer, which answers "where is Rissah?" with a point it also
      // gives to ten other camps. If the collapse ever stops being
      // counted, the map goes back to drawing one dot for eleven names
      // with nothing to say so.
      final r = route('exodus-wilderness');
      expect(r.collapsedRuns.length, greaterThan(1));
      expect(r.collapsedStopCount, greaterThan(20),
          reason: 'measured at 27 of 42 against the shipped gazetteer');
      expect(r.collapsedStopCount, lessThan(r.stops.length),
          reason: 'a route entirely at one point should not be drawn at all');
    });

    test('no provisional camp is buried inside a merged run', () {
      // The one case the drawing has no answer for. A camp strictly
      // INSIDE a run has no leg of its own, so its dotted line has
      // nowhere to be drawn, and `journey_route.dart` deliberately
      // refuses to borrow a neighbouring leg's dash to say it. Nothing
      // that ships is in this state; if something ever is, this row fails
      // and a person decides how the marker should say it, rather than
      // the map quietly presenting a doubtful camp in confident ink.
      for (final r in resolved) {
        for (final run in r.collapsedRuns) {
          for (var i = 1; i < run.stops.length - 1; i++) {
            expect(run.stops[i].stop.attested, isTrue,
                reason: '${r.id}: ${run.stops[i].place.id} is provisional '
                    'and merged out of sight');
          }
        }
      }
    });

    test('every drawn journey has more than one drawable leg', () {
      for (final r in resolved) {
        expect(r.segments.length, greaterThan(1), reason: r.id);
      }
    });

    test('the style slots are in the data', () {
      // In the DATA so that inserting a journey mid-file cannot silently
      // recolour the ones after it.
      for (final raw in doc['journeys'] as List<dynamic>) {
        expect((raw as Map<String, dynamic>)['style'], isA<num>());
        expect((raw)['mark'], isA<String>());
      }
    });

    test('no two routes share an appearance', () {
      // The hue alone used to be the identity, and this row used to
      // demand distinct hues. It cannot any more: the palette holds five
      // hues honestly and Mark's itinerary is the sixth route, so it
      // takes slot 0's amber and separates itself by silhouette. What
      // must stay unique is the PAIR — a repeated hue is a repeated
      // appearance only when the shape repeats too.
      final seen = journeys.map((j) => (j.style, j.mark)).toList();
      expect(seen.toSet().length, seen.length,
          reason: 'two routes would draw identically: $seen');
    });

    test('the straight-line totals are the scale they are offered as', () {
      // These are sums of chords, and the row exists to catch a MOVED
      // COORDINATE. It used to do that with a band of 500..20000 km,
      // which was really a fact about the corpus it was written against:
      // every route in the file was a Mediterranean voyage. Mark's
      // itinerary never leaves Galilee and Judea and totals ~479 km, so
      // the old floor would have rejected it for being the right size.
      //
      // Pinning each route to its own total is the stronger check the
      // comment always claimed: a coordinate that moves now fails the
      // route it moved in, not merely the ones that fall out of a band.
      // The band stays for a route added later with no pin.
      // Sums over the DRAWN segments, so a run of camps collapsed onto
      // one point contributes once — which is why the wilderness total is
      // well under the sum of its 42 rows.
      const expected = <String, double>{
        'paul-1': 1947.6,
        'paul-2': 3691.3,
        'paul-3': 3653.0,
        'paul-rome': 2995.5,
        'exodus-wilderness': 1638.4,
        'jesus-mark': 478.6,
        'jacob': 1189.3,
        'abraham': 3374.8,
        'ark': 122.1,
      };
      for (final r in resolved) {
        expect(r.straightLineKm, greaterThan(100), reason: r.id);
        expect(r.straightLineKm, lessThan(20000), reason: r.id);
        final pin = expected[r.id];
        if (pin == null) continue;
        expect(r.straightLineKm, closeTo(pin, 2), reason: r.id);
      }
      expect(expected.keys.toSet(), resolved.map((r) => r.id).toSet(),
          reason: 'a route was added or renamed without a pinned total');
    });

    group("Jacob's journey", () {
      test('the route ships, twelve stops of Genesis', () {
        final j = journeys.firstWhere((j) => j.id == 'jacob');
        expect(j.stops.length, 12);
        expect(j.stops.first.placeId, 'Beersheba');
        expect(j.stops.last.placeId, 'Goshen 1');
        expect(j.stops.every((s) => s.englishBook == 'Genesis'), isTrue);
      });

      test('it is a round trip, and the map says so once', () {
        final r = route('jacob');
        expect(
          r.ordinalsByMarker[markerKeyFor(byId['Beersheba']!)]?.length,
          2,
        );
        expect(
          r.ordinalsByMarker[markerKeyFor(byId['Bethel 1']!)]?.length,
          2,
        );
      });

      test('the line breaks at Mahanaim and is not bridged', () {
        final r = route('jacob');
        expect(r.unplaced.map((u) => u.stop.placeId), <String>['Mahanaim']);
        expect(r.unplaced.map((u) => u.index), <int>[3]);
        expect(
          r.unplaced.map((u) => (u.stop.chapter, u.stop.verse)),
          <(int, int)>[(32, 2)],
        );
      });

      test('Mount Gilead is refused, and the basis says why', () {
        final r = route('jacob');
        final ids = r.stops.map((s) => s.place.id).toList();
        expect(ids, isNot(contains('Mount Gilead')));
        expect(ids, isNot(contains('Gilead')));
        expect(ids, isNot(contains('Mount Gilboa')));
        final basis = r.journey.basis['en']!;
        expect(basis, contains('Mount Gilead'));
        expect(basis, contains('Mount Gilboa'));
      });

      test('nothing on this route is provisional', () {
        final j = journeys.firstWhere((j) => j.id == 'jacob');
        expect(j.provisionalCount, 0);
        expect(j.asideCount, 0);
      });
    });

    group("The ark's journey", () {
      test('the route ships, eight stops', () {
        final j = journeys.firstWhere((j) => j.id == 'ark');
        expect(j.stops.length, 8);
        expect(j.stops.first.placeId, 'Shiloh');
        expect(j.stops.last.placeId, 'Jerusalem');
        expect(j.style, 4);
        expect(j.mark, JourneyMark.diamond);
      });

      test('nothing on it is provisional and nothing is an aside', () {
        final j = journeys.firstWhere((j) => j.id == 'ark');
        expect(j.provisionalCount, 0);
        expect(j.asideCount, 0);
      });

      test('Kiriath-jearim is named and undrawn, and the line breaks there',
          () {
        final r = route('ark');
        expect(r.unresolved, <String>['Kiriath-jearim']);
        expect(r.stops.length, 7);
        expect(r.segments.length, 5);
        expect(
          r.segments.every((s) =>
              s.from.place.id != 'Jerusalem' && s.to.place.id != 'Jerusalem'),
          isTrue,
          reason: 'Jerusalem must draw no segment — that would bridge the '
              'twenty years at Kiriath-jearim',
        );
      });

      test('the itinerary still shows the stop the map cannot draw', () {
        final r = route('ark');
        expect(r.itineraryRows.length, 8);
        final row = r.itineraryRows[6];
        expect(row.unplaced, isNotNull);
        expect(row.unplaced!.stop.placeId, 'Kiriath-jearim');
        expect(row.unplaced!.absent, isFalse,
            reason: 'the gazetteer has the name and lacks the point — '
                'that is not the same as not having the name at all');
      });

      test('the arrival is cited where the arrival is told', () {
        final j = journeys.firstWhere((j) => j.id == 'ark');
        expect(j.stops.last.englishBook, '2 Samuel');
        expect(j.stops.last.chapter, 6);
        expect(j.stops.last.verse, 12);
        expect(j.stops.last.note!['en']!, contains('city of David'));
      });
    });
  });

  // The legend under the toggles (`journeysKey`, atlas_page.dart:976) is
  // on screen at the same moment as every route's own two counts, so a
  // sentence in it that names a DIRECTION is a claim about numbers the
  // reader can read one line above it.
  group('the legend claims no direction the routes refute', () {
    test('a route draws MORE markers than it has stops', () {
      // paul-rome is the only route carrying asides (2). An aside is not
      // a stop — bible_journey.dart:218 counts it out of waypointCount —
      // but it still takes a hollow marker, so the total goes UP.
      final more = resolved
          .where((r) => r.markers.length > r.journey.waypointCount)
          .map((r) => r.id)
          .toList();
      expect(more, contains('paul-rome'),
          reason: 'the legend may not say markers are always the fewer');
    });

    test('the legend never says the marker count is the smaller one', () {
      // Measured 2026-09-01: paul-rome's row prints
      // "14 站 · 16 个标记" while this legend is on screen beneath it.
      // A directional sentence here contradicts the row above it using
      // the reader's own printed numbers — the same defect class as the
      // small-screen advisory that argued against its own figures.
      expect(uiStrings['journeysKey']!['en']!,
          isNot(contains('fewer marker')));
      expect(uiStrings['journeysKey']!['zh-Hans']!, isNot(contains('少于')));
      expect(uiStrings['journeysKey']!['zh-Hant']!, isNot(contains('少於')));
    });
  });
}
