/// THE GENEALOGY RAIL: 198 people the wheel drew nowhere, as 107 marks.
///
/// The owner asked for the family tree's remaining people on the wheel
/// after being told what their years rest on, which is nothing:
/// **every one of the 198 has an empty `datingRefs`** — 197 of them
/// `approximate`, one a reign, and not a single verse between them.
/// So they are drawn, and drawn as what they are.
///
/// A COHORT, NOT A PERSON. The 198 share only 107 distinct years, and
/// one year holds 44 of them: the sons and grandsons of Jacob who went
/// down into Egypt, whom Genesis 46 lists together and dates not at
/// all, so `family_tree.json` gives them one nominal year. Drawing 198
/// marks would print 198 datings the asset does not make. Drawing 107,
/// each saying how many stand behind it, prints what is actually there.
///
/// A MARK, NOT A SPAN. Four of the 198 carry a death year and 194 do
/// not, so nothing here may be an arc: an arc from a birth to an
/// invented end is exactly the false precision this layer exists to
/// avoid.
///
/// THE RAIL OWNS THE INNERMOST SUB-RING OUTRIGHT. A cohort has no
/// angular width, so first-fit would have put all 107 in ring 0 beside
/// Adam, Seth and Enosh. The ring is reserved instead — inside
/// `packWheelBand`, so no caller can apply the shift and no caller can
/// forget it, which is a mistake this file's neighbour has already
/// caught twice in one day.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show lineageCohorts, packWheelBand;
import 'package:seeksparks/services/hebrew_kings_service.dart'
    show HebrewKingsData;
import 'package:seeksparks/utils/radial_chronology_layout.dart';

late final List<BiblicalPerson> people;
late final ChronologyData chron;
late final List<HebrewKing> kings;
late final List<WheelMinistry> ministries;
late final Set<String> drawnIds;
late final int creation;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    people = ((jsonDecode(File('assets/family_tree.json').readAsStringSync())
            as Map<String, dynamic>)['people'] as List)
        .cast<Map<String, dynamic>>()
        .map(BiblicalPerson.fromJson)
        .toList();
    chron = ChronologyData.fromJson(
        jsonDecode(File('assets/chronology.json').readAsStringSync())
            as Map<String, dynamic>);
    kings = HebrewKingsData.fromJson(
            jsonDecode(File('assets/hebrew_kings.json').readAsStringSync())
                as Map<String, dynamic>)
        .kings;
    final wheelJson =
        jsonDecode(File('assets/wheel_history.json').readAsStringSync())
            as Map<String, dynamic>;
    ministries = (wheelJson['ministries'] as List)
        .cast<Map<String, dynamic>>()
        .map(WheelMinistry.fromJson)
        .toList();
    final timeline =
        (jsonDecode(File('assets/bible_timeline.json').readAsStringSync())
            as Map<String, dynamic>);
    creation = ((timeline['_meta'] as Map<String, dynamic>)['creation']
        as Map<String, dynamic>)['year'] as int;
    drawnIds = <String>{
      for (final p in chron.patriarchs) p.id,
      for (final k in kings) k.id,
      for (final e in (timeline['events'] as List).cast<Map<String, dynamic>>())
        ...((e['personIds'] as List?) ?? const []).cast<String>(),
    };
  });

  group('what the layer contains', () {
    test('198 people, 107 years, and one year holding 44', () {
      // The exclusion is BY ID, not by name — a person whose name only
      // occurs in an event's prose has no record on the wheel to reach,
      // so dropping him here would remove the only way to reach him.
      // That rule is why this is 198 and not the 192 an earlier
      // name-matching count gave.
      final cohorts = lineageCohorts(people: people, drawnIds: drawnIds);
      expect(cohorts.length, 107);
      expect(cohorts.fold<int>(0, (n, c) => n + c.people.length), 198);
      final biggest = cohorts.reduce(
          (a, b) => a.people.length >= b.people.length ? a : b);
      expect(biggest.people.length, 44);
      expect(biggest.year, -1690);
    });

    test('not one of them has a verse for its year', () {
      // The sentence the sheet prints, verified against the asset
      // rather than believed. If this ever fails, some of these people
      // gained a reference and deserve better than a grey tick.
      for (final c in lineageCohorts(people: people, drawnIds: drawnIds)) {
        for (final p in c.people) {
          expect(p.datingRefs, isEmpty,
              reason: '${p.id} now cites ${p.datingRefs} for its year');
          expect(p.datingKind, isNot('stated'), reason: p.id);
        }
      }
    });

    test('nobody is drawn twice', () {
      final cohorts = lineageCohorts(people: people, drawnIds: drawnIds);
      final ids = [for (final c in cohorts) for (final p in c.people) p.id];
      expect(ids.toSet().length, ids.length);
      // ...and nobody already on another layer is here at all.
      for (final id in ids) {
        expect(drawnIds.contains(id), isFalse, reason: '$id is drawn twice');
      }
      // The exclusion really excludes: David and Solomon are kings,
      // Abraham is an arc, and none of the three may appear.
      for (final id in const ['david', 'solomon', 'abraham', 'noah']) {
        expect(ids.contains(id), isFalse, reason: id);
      }
    });

    test('only BC-dated people, and years in ascending order', () {
      final cohorts = lineageCohorts(people: people, drawnIds: drawnIds);
      for (var i = 1; i < cohorts.length; i++) {
        expect(cohorts[i].year, greaterThan(cohorts[i - 1].year));
      }
      for (final c in cohorts) {
        for (final p in c.people) {
          expect(p.yearSystem, 'bc', reason: p.id);
          expect(p.birthYear, c.year, reason: p.id);
        }
      }
      // The Anno Mundi people are the arcs' business, not this layer's.
      expect(
        lineageCohorts(
          people: people.where((p) => p.yearSystem == 'am').toList(),
          drawnIds: const <String>{},
        ),
        isEmpty,
      );
    });

    test('a person with no birth year is not placed', () {
      final invented = <BiblicalPerson>[];
      final cohorts =
          lineageCohorts(people: invented, drawnIds: const <String>{});
      expect(cohorts, isEmpty);
      // And nobody in the real set slipped through without one.
      for (final c in lineageCohorts(people: people, drawnIds: drawnIds)) {
        for (final p in c.people) {
          expect(p.birthYear, isNotNull, reason: p.id);
        }
      }
    });
  });

  group('the reserved ring', () {
    List<LifeArc> band({required int reserved}) => packWheelBand(
          chron: chron,
          creationYear: creation,
          kings: kings,
          ministries: ministries,
          reservedInnerRings: reserved,
        );

    test('ring 0 is empty when the rail is on, and used when it is off', () {
      final withRail = band(reserved: 1);
      final withoutRail = band(reserved: 0);
      expect(withRail.any((a) => a.ring == 0), isFalse,
          reason: 'an arc is drawn in the ring the rail owns');
      expect(withoutRail.any((a) => a.ring == 0), isTrue);
      expect(lifeArcRingCount(withRail), lifeArcRingCount(withoutRail) + 1);
    });

    test('the shift moves every arc by exactly one, and nothing else', () {
      final withRail = {for (final a in band(reserved: 1)) a.id: a};
      for (final a in band(reserved: 0)) {
        final shifted = withRail[a.id]!;
        expect(shifted.ring, a.ring + 1, reason: a.id);
        // The angles and the years are untouched — a reserved ring is a
        // radial decision and must not become a chronological one.
        expect(shifted.a0, a.a0, reason: a.id);
        expect(shifted.a1, a.a1, reason: a.id);
        expect(shifted.birthYear, a.birthYear, reason: a.id);
        expect(shifted.deathYear, a.deathYear, reason: a.id);
        expect(shifted.line, a.line, reason: a.id);
      }
    });

    test('no two arcs in one sub-ring overlap, rail on or off', () {
      for (final reserved in const [0, 1]) {
        final byRing = <int, List<LifeArc>>{};
        for (final a in band(reserved: reserved)) {
          byRing.putIfAbsent(a.ring, () => []).add(a);
        }
        for (final entry in byRing.entries) {
          final ring = entry.value..sort((a, b) => a.a0.compareTo(b.a0));
          for (var i = 1; i < ring.length; i++) {
            expect(ring[i].a0, greaterThanOrEqualTo(ring[i - 1].a1),
                reason: 'reserved=$reserved ring ${entry.key}');
          }
        }
      }
    });

    test('the rail sits inside every arc', () {
      // `lifeArcRadii` counts ring 0 innermost, so the rail's radius
      // must be under the innermost arc's. Checked rather than assumed,
      // because `ringRadii` counts the other way for the stream bands
      // and the two conventions have been confused before.
      const inner = 204.5; // scriptureLabelBase at a 700 px canvas
      const rRim = 311.5;
      final arcs = band(reserved: 1);
      final rings = lifeArcRingCount(arcs);
      final rail = lifeArcRadii(0, rings, inner, rRim);
      for (final a in arcs) {
        final r = lifeArcRadii(a.ring, rings, inner, rRim);
        expect(rail.centre, lessThan(r.centre), reason: a.id);
      }
    });
  });
}
