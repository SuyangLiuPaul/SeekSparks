// Turning a distance into a time on the road (#317).
//
// The app used to print one confident figure, `ceil(km / 32)`, beside two
// points picked off the gazetteer with a ruler, and printed nothing at
// all on the journeys, where every leg carries the mode of travel the
// text itself uses. This file holds the claims the replacement makes.
//
// Three of them are worth stating out loud, because they are the ones a
// future change could break without breaking anything visible:
//
//  1. The speeds are a QUOTATION, not a preference. Both ends come out of
//     one sentence of ORBIS v1.0, and the test below fails if either
//     drifts off it.
//  2. The estimate is a FLOOR. It is computed over great-circle chords,
//     which are shorter than any road, so the real journey is longer than
//     both ends of the band.
//  3. Sea legs get NO number, and the refusal is stated rather than
//     silent. The voyage to Rome is 93.6% sea; an estimate over its three
//     land legs, printed alone, would say Paul walked to Rome in a week
//     and a half.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/bible_journey.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/journey_route.dart';
import 'package:seeksparks/utils/place_geo.dart' show haversineKm;
import 'package:seeksparks/utils/travel_time.dart';

void main() {
  final places = parseGazetteer(
    json.decode(File('assets/bible_places.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final routes = resolveJourneys(
    parseJourneys(
      json.decode(File('assets/bible_journeys.json').readAsStringSync())
          as Map<String, dynamic>,
    ),
    places,
  );
  ResolvedJourney route(String id) => routes.firstWhere((r) => r.id == id);

  group('the band', () {
    test('both speeds are the ones ORBIS names, and in the right order', () {
      // "20km/day for porters or heavily loaded mules, 30km/day for foot
      // travelers including armies on the march" — ORBIS v1.0 (Scheidel,
      // Meeks and Weiland, Stanford, 2012). Changing either number is a
      // change of SOURCE, not of taste, and has to be made here first.
      expect(kFootSlowKmPerDay, 20.0);
      expect(kFootFastKmPerDay, 30.0);
      expect(kFootSlowKmPerDay, lessThan(kFootFastKmPerDay));
    });

    test('the figure this replaced was outside the band, on the fast side',
        () {
      // 32 km/day, the number the ruler shipped with. It was faster than
      // ORBIS's fastest walking party, so "about N days" was never a
      // midpoint — it was a floor wearing an estimate's clothes. Kept as a
      // test rather than a comment so nobody reintroduces it as a
      // "reasonable average".
      expect(32.0, greaterThan(kFootFastKmPerDay));
    });

    test('rounds up at both ends and never returns zero days', () {
      // A short hop is still a day on the road, not "no time at all".
      final one = walkingDaysFor(1)!;
      expect(one.fewest, 1);
      expect(one.most, 1);
      expect(one.single, isTrue);

      final long = walkingDaysFor(300)!;
      expect(long.fewest, 10);
      expect(long.most, 15);
      expect(long.single, isFalse);

      // Just over a fast day is two days at both ends.
      expect(walkingDaysFor(31), const TravelDays(2, 2));
    });

    test('declines rather than answering zero', () {
      // "0 days" is a statement about a journey and none of these is one.
      expect(walkingDaysFor(0), isNull);
      expect(walkingDaysFor(-5), isNull);
      expect(walkingDaysFor(double.nan), isNull);
      expect(walkingDaysFor(double.infinity), isNull);
    });
  });

  group('the wording', () {
    // The widget suite renders zh-Hans, which does not inflect, so a
    // rendered test cannot see an English "1 days on foot". These read
    // the string table directly, which can.
    test('English inflects on one day', () {
      expect(formatTravelDays(const TravelDays(1, 1), 'en'),
          '1 day on foot');
      expect(formatTravelDays(const TravelDays(2, 2), 'en'),
          '2 days on foot');
    });

    test('a closed band prints one number, not "2–2"', () {
      expect(formatTravelDays(const TravelDays(2, 2), 'en'), isNot(contains('–')));
      expect(formatTravelDays(const TravelDays(9, 13), 'en'),
          '9–13 days on foot');
    });

    test('an open band uses an en dash, never a hyphen', () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final out = formatTravelDays(const TravelDays(9, 13), locale);
        expect(out, contains('–'), reason: locale);
        expect(out, isNot(contains('9-13')), reason: locale);
      }
    });

    test('no placeholder survives into the rendered string', () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        for (final d in const [TravelDays(1, 1), TravelDays(3, 3), TravelDays(9, 13)]) {
          final out = formatTravelDays(d, locale);
          expect(out, isNot(contains('{')), reason: '$locale $d');
          expect(out, isNot(contains('}')), reason: '$locale $d');
        }
      }
    });

    test('every new key carries all three languages', () {
      const keys = [
        'travelDaysOne',
        'travelDaysMany',
        'travelDaysBand',
        'travelDaysBasis',
        'travelNoEstimateSea',
        'travelNoEstimateUnknown',
        'journeyLandKm',
        'journeySeaKm',
        'journeyUnknownKm',
      ];
      for (final k in keys) {
        final row = uiStrings[k];
        expect(row, isNotNull, reason: k);
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(row![locale], isNotNull, reason: '$k / $locale');
          expect(row[locale], isNotEmpty, reason: '$k / $locale');
        }
      }
    });

    test('the basis names its source, its floor and its unit', () {
      // All three hedges are load-bearing and none may be edited away:
      // where the speed comes from, that the distance is a straight line,
      // and that the count is days travelling rather than elapsed time.
      final en = uiStrings['travelDaysBasis']!['en']!;
      expect(en, contains('ORBIS'));
      expect(en, contains('20–30'));
      expect(en, contains('straight'));
      expect(en, contains('road'));
      for (final locale in const ['zh-Hans', 'zh-Hant']) {
        final zh = uiStrings['travelDaysBasis']![locale]!;
        expect(zh, contains('ORBIS'), reason: locale);
        expect(zh, contains('20–30'), reason: locale);
        expect(zh, contains('直'), reason: '$locale: straight-line hedge');
      }
    });

    test('the sea abstention gives its reason, and the right one', () {
      // The defensible claim is not "no ancient sailing speed is known" —
      // several are — but that none can be applied to a straight chord.
      // Acts 27 is the evidence, and it is evidence the app already
      // draws: the ship runs under the lee of Cyprus and Crete, which is
      // not the shortest way.
      final en = uiStrings['travelNoEstimateSea']!['en']!;
      expect(en, contains('Acts 27'));
      expect(en, contains('straight line'));
      // A wrong figure inside a caveat is still a wrong figure. Casson's
      // windward number is under ~2.5 knots made good, not the 1–2 an
      // earlier draft of this string claimed.
      expect(en, isNot(contains('1–2')));
      for (final locale in const ['zh-Hans', 'zh-Hant']) {
        expect(uiStrings['travelNoEstimateSea']![locale]!, contains('27'),
            reason: locale);
      }
    });

    test('the old single-figure string is gone', () {
      // Removing `daysOnFootFor` and leaving its caption behind would let
      // a future caller print an unsourced figure again with a key that
      // already exists.
      expect(uiStrings['placesMapDays'], isNull);
    });
  });

  group('against scripture', () {
    test('Deuteronomy 1:2 — eleven days falls inside the band', () {
      // "There are eleven days' journey from Horeb by the way of mount
      // Seir unto Kadesh-barnea." The one stretch of country scripture
      // itself prices in days, and the only real check available on the
      // speeds: if the band excluded the number the text gives, the band
      // would be wrong.
      //
      // A CONSISTENCY check and not a proof, for three reasons that must
      // stay attached to it:
      //
      //  - "By the way of mount Seir" is a road and is longer than the
      //    chord measured here, so the real pace was higher than 22 km a
      //    day. That pushes it further INTO the band, not out.
      //  - The check presupposes a southern Sinai. Our gazetteer follows
      //    the traditional Jebel Musa, and the north-west Arabian
      //    candidate is near enough equidistant to leave the arithmetic
      //    alone (~239 km, 22 km/day). But the northern candidates would
      //    destroy it rather than shift it: Jebel Halal is about 44 km
      //    from Kadesh and Har Karkom about 50, either of which would
      //    make eleven days absurd. This test is evidence about the
      //    SPEEDS only on the identification the gazetteer already ships.
      //  - Our Kadesh-barnea sits about 7 km from Tell el-Qudeirat's
      //    published coordinates, which is immaterial at this tolerance
      //    but is a gazetteer question, not a travel-time one.
      final horeb = places.firstWhere((p) => p.id == 'Horeb');
      final kadesh = places.firstWhere((p) => p.id == 'Kadesh-barnea');
      final km =
          haversineKm(horeb.lat!, horeb.lon!, kadesh.lat!, kadesh.lon!);
      expect(km, closeTo(244, 3));

      final days = walkingDaysFor(km)!;
      expect(days.fewest, lessThanOrEqualTo(11));
      expect(days.most, greaterThanOrEqualTo(11));

      // And the pace the text implies over the chord sits inside the
      // ORBIS figures rather than at or beyond an end of them.
      final implied = km / 11;
      expect(implied, greaterThan(kFootSlowKmPerDay));
      expect(implied, lessThan(kFootFastKmPerDay));
    });

    test('the same verse rules out the convention we did not adopt', () {
      // The choice of source was not a matter of taste, and this is what
      // decided it. ISBE's "day's journey" is 32-40 km — a real published
      // convention, and near-certainly where the discarded 32 came from,
      // since it is derived from a pack mule at three miles an hour for
      // eight hours. Applied to the same chord it gives 7-8 days for a
      // stretch Deuteronomy 1:2 calls eleven, so it contradicts the verse
      // where ORBIS's figures contain it.
      //
      // Both arithmetics live here so that reverting to a faster speed is
      // a visible act rather than a plausible tidy-up.
      final horeb = places.firstWhere((p) => p.id == 'Horeb');
      final kadesh = places.firstWhere((p) => p.id == 'Kadesh-barnea');
      final km =
          haversineKm(horeb.lat!, horeb.lon!, kadesh.lat!, kadesh.lon!);

      expect((km / 40.0).ceil(), 7);
      expect((km / 32.0).ceil(), 8);
      expect((km / 32.0).ceil(), lessThan(11),
          reason: 'the shipped figure said 8 days where the text says 11');

      expect(walkingDaysFor(km)!.most, greaterThanOrEqualTo(11));
    });
  });

  group('splitting a route by how they went', () {
    test('the buckets sum to the total the panel already prints', () {
      for (final r in routes) {
        final t = travelOf(r);
        expect(t.totalKm, closeTo(r.straightLineKm, 1e-9), reason: r.id);
      }
    });

    test('every segment lands in exactly one bucket', () {
      for (final r in routes) {
        final t = travelOf(r);
        expect(t.landLegs + t.seaLegs + t.unknownLegs, r.segments.length,
            reason: r.id);
      }
    });

    test('no shipped segment carries a start leg', () {
      // `start` opens a route; the resolver never emits a segment for
      // one. `travelOf` files it under the unestimated bucket anyway, so
      // that being wrong costs a missing estimate rather than a claim —
      // but the data should never exercise that arm, and this is what
      // says so.
      for (final r in routes) {
        for (final s in r.segments) {
          expect(s.leg, isNot(JourneyLeg.start), reason: r.id);
        }
      }
    });

    test('the sea routes are mostly sea, and say nothing about days', () {
      // Measured through the resolver, not asserted from the asset. The
      // voyage to Rome is 2,803 km of 2,996 at sea.
      final rome = travelOf(route('paul-rome'));
      expect(rome.seaKm, closeTo(2803, 5));
      expect(rome.landKm, closeTo(192, 5));
      expect(rome.seaKm / rome.totalKm, greaterThan(0.9));
      expect(rome.hasUnestimated, isTrue);

      // Its three land legs DO carry a band — the refusal is per-mode,
      // not per-route — but the panel is obliged to state the sea
      // alongside it, which `hasUnestimated` above is what drives.
      expect(rome.walk, isNotNull);
      expect(rome.walk!.fewest, 7);
      expect(rome.walk!.most, 10);
    });

    test('a route the text will not assign a mode to says so', () {
      // 58% of the route through Mark is `unknown`: the text names where
      // they went and not how. Folding it into the land total would make
      // the estimate look twice as complete as it is.
      final mark = travelOf(route('jesus-mark'));
      expect(mark.unknownKm, closeTo(280, 5));
      expect(mark.landKm, closeTo(199, 5));
      expect(mark.seaKm, 0);
      expect(mark.unknownKm / mark.totalKm, greaterThan(0.5));
      expect(mark.hasUnestimated, isTrue);
    });

    test('the wilderness itinerary is all land, and all estimated', () {
      final exodus = travelOf(route('exodus-wilderness'));
      expect(exodus.seaKm, 0);
      expect(exodus.unknownKm, 0);
      expect(exodus.hasUnestimated, isFalse);
      expect(exodus.landKm, closeTo(1638, 5));
      expect(exodus.walk, const TravelDays(55, 82));
    });

    test('the three missionary journeys split land from sea', () {
      final one = travelOf(route('paul-1'));
      expect(one.landKm, closeTo(959, 5));
      expect(one.seaKm, closeTo(989, 5));
      expect(one.unknownKm, 0);
      expect(one.walk, const TravelDays(32, 48));

      final two = travelOf(route('paul-2'));
      expect(two.landKm, closeTo(1860, 5));
      expect(two.seaKm, closeTo(1521, 5));
      expect(two.unknownKm, closeTo(311, 5));

      final three = travelOf(route('paul-3'));
      expect(three.landKm, closeTo(1699, 5));
      expect(three.seaKm, closeTo(1471, 5));
      expect(three.unknownKm, closeTo(484, 5));
    });

    test('a band is offered for every route with land, and only those', () {
      for (final r in routes) {
        final t = travelOf(r);
        expect(t.walk != null, t.landKm > 0, reason: r.id);
      }
    });
  });
}
