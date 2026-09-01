// The reverse join (#317): which journeys name a given place. Measured
// against the shipped assets, not fixtures — the numbers here are the
// same ones the Atlas prints.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/bible_journey.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/journey_route.dart';
import 'package:seeksparks/utils/place_journeys.dart';

void main() {
  final places = parseGazetteer(
    json.decode(File('assets/bible_places.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final doc = json.decode(File('assets/bible_journeys.json').readAsStringSync())
      as Map<String, dynamic>;
  final resolved = resolveJourneys(parseJourneys(doc), places);

  test('a place on three journeys names all three, in asset order', () {
    expect(journeysNaming('Antioch 1', resolved).map((e) => e.id),
        ['paul-1', 'paul-2', 'paul-3']);
  });

  test('a place the itinerary returns to keeps both stops', () {
    final onOne = journeysNaming('Perga', resolved);
    expect(onOne, hasLength(1));
    expect(onOne.single.rows, hasLength(2));
    expect(onOne.single.rows.map((r) => r.placed?.ordinal), [5, 13]);

    final onAntioch = journeysNaming('Antioch 1', resolved);
    final byId = {for (final e in onAntioch) e.id: e};
    expect(byId['paul-1']!.rows.map((r) => r.placed?.ordinal), [1, 15]);
    expect(byId['paul-2']!.rows.map((r) => r.placed?.ordinal), [1, 19]);
    expect(byId['paul-3']!.rows.map((r) => r.placed?.ordinal), [1]);
  });

  test('an aside is reported without an ordinal', () {
    final on = journeysNaming('Phoenix', resolved);
    expect(on, hasLength(1));
    expect(on.single.id, 'paul-rome');
    expect(on.single.rows, hasLength(1));
    final row = on.single.rows.single;
    expect(row.stop.isAside, isTrue);
    expect(row.placed?.ordinal, isNull);
    expect(row.stop.reference, 'Acts 27:12');
  });

  test('a stop the map cannot draw gets no invented number', () {
    final on = journeysNaming('Pi-hahiroth', resolved);
    expect(on, hasLength(1));
    expect(on.single.id, 'exodus-wilderness');
    expect(on.single.rows, hasLength(1));
    final row = on.single.rows.single;
    expect(row.placed, isNull);
    expect(row.unplaced, isNotNull);
    expect(row.stop.reference, 'Numbers 33:7');
  });

  test('a provisional stop stays provisional', () {
    final on = journeysNaming('Iconium', resolved);
    expect(on.map((e) => e.id), ['paul-1', 'paul-2']);
    final onTwo = on.firstWhere((e) => e.id == 'paul-2');
    expect(onTwo.rows, hasLength(1));
    expect(onTwo.rows.single.placed?.ordinal, 4);
    expect(onTwo.rows.single.stop.attested, isFalse);
  });

  test('a place on no route answers with nothing', () {
    expect(journeysNaming('Babylon', resolved), isEmpty);
  });

  test('no row anywhere carries an ordinal the map has no badge for', () {
    var maxWilderness = 0;
    for (final p in places) {
      for (final e in journeysNaming(p.id, resolved)) {
        for (final r in e.rows) {
          if (r.placed == null) {
            expect(r.unplaced, isNotNull);
          } else if (e.id == 'exodus-wilderness') {
            final n = r.placed!.ordinal;
            if (n != null && n > maxWilderness) maxWilderness = n;
          }
        }
      }
    }
    expect(maxWilderness, 40);
    final wilderness = resolved.firstWhere((j) => j.id == 'exodus-wilderness');
    expect(wilderness.journey.waypointCount, 42);
  });

  test('the reverse join covers 122 places', () {
    final covered = <String>{
      for (final p in places)
        if (journeysNaming(p.id, resolved).isNotEmpty) p.id,
    };
    expect(covered, hasLength(122));
  });

  test('16 places are on more than one route', () {
    final onSeveral = <String>{
      for (final p in places)
        if (journeysNaming(p.id, resolved).length > 1) p.id,
    };
    expect(onSeveral, hasLength(16));
    expect(onSeveral, {
      'Antioch 1', 'Beersheba', 'Bethel 1', 'Caesarea', 'Derbe', 'Ephesus',
      'Haran', 'Iconium', 'Jerusalem', 'Lystra', 'Mamre', 'Philippi',
      'Shechem', 'Sidon', 'Troas', 'Tyre',
    });
  });
}
