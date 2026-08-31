// The passage→journey join (#317): which journeys run through a chapter,
// and what the focused verse itself contributes. Measured against the
// shipped assets, not fixtures — the numbers here are the same ones the
// pane prints.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/bible_journey.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/journey_route.dart';
import 'package:seeksparks/utils/passage_journeys.dart';

void main() {
  final places = parseGazetteer(
    json.decode(File('assets/bible_places.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final doc = json.decode(File('assets/bible_journeys.json').readAsStringSync())
      as Map<String, dynamic>;
  final resolved = resolveJourneys(parseJourneys(doc), places);

  test('a chapter no journey touches returns nothing', () {
    expect(journeysThrough('Genesis', 1, 1, resolved), isEmpty);
  });

  test('the chapter the first journey opens in names it, with the verse '
      'stop lifted out', () {
    final on = journeysThrough('Acts', 13, 4, resolved);
    expect(on, hasLength(1));
    final e = on.single;
    expect(e.id, 'paul-1');
    expect(e.verseRows, hasLength(1));
    expect(e.verseRows.single.placed?.ordinal, 2);
    expect(e.chapterRows, hasLength(7));
  });

  test('one verse can carry three consecutive stops', () {
    final on = journeysThrough('Acts', 18, 22, resolved);
    expect(on.map((e) => e.id).toList(), ['paul-2', 'paul-3']);
    final paul2 = on.firstWhere((e) => e.id == 'paul-2');
    expect(paul2.verseRows.map((r) => r.placed?.ordinal).toList(),
        [17, 18, 19]);
    expect(paul2.chapterRows, hasLength(6));
  });

  test('a journey with no stop on this verse is still named for the '
      'chapter', () {
    final on = journeysThrough('Acts', 18, 22, resolved);
    final paul3 = on.firstWhere((e) => e.id == 'paul-3');
    expect(paul3.verseRows, isEmpty);
    expect(paul3.chapterRows, hasLength(3));
  });

  test("the chapter count includes the verse's own stops", () {
    final on = journeysThrough('Acts', 18, 22, resolved);
    final paul2 = on.firstWhere((e) => e.id == 'paul-2');
    for (final r in paul2.verseRows) {
      expect(
        paul2.chapterRows.any((c) => identical(c, r)),
        isTrue,
      );
    }
    expect(paul2.chapterRows.length, 6);
    expect(paul2.verseRows.length, 3);
  });

  test('an aside on the focused verse is reported without an ordinal', () {
    final on = journeysThrough('Acts', 27, 12, resolved);
    expect(on, hasLength(1));
    final e = on.single;
    expect(e.id, 'paul-rome');
    expect(e.verseRows, hasLength(1));
    expect(e.verseRows.single.stop.isAside, isTrue);
    expect(e.verseRows.single.placed?.ordinal, isNull);
  });

  test('a stop the map cannot draw still reaches the reader in its own '
      'verse', () {
    final on = journeysThrough('Numbers', 33, 7, resolved);
    expect(on, hasLength(1));
    final e = on.single;
    expect(e.id, 'exodus-wilderness');
    expect(e.verseRows, hasLength(1));
    expect(e.verseRows.single.placed, isNull);
    expect(e.verseRows.single.unplaced, isNotNull);
    expect(e.verseRows.single.stop.reference, 'Numbers 33:7');
    expect(e.chapterRows, hasLength(42));
  });

  test('the provisional stop keeps its verdict', () {
    final on = journeysThrough('Acts', 18, 22, resolved);
    final paul2 = on.firstWhere((e) => e.id == 'paul-2');
    expect(paul2.verseRows[1].stop.attested, isFalse);
    expect(paul2.verseRows[1].stop.placeId, 'Jerusalem');
    expect(paul2.verseRows[0].stop.attested, isTrue);
    expect(paul2.verseRows[2].stop.attested, isTrue);
  });

  test('asset order, not stop count', () {
    final on = journeysThrough('Acts', 18, 22, resolved);
    expect(on.map((e) => e.id).toList(), ['paul-2', 'paul-3']);

    const assetOrder = [
      'paul-1', 'paul-2', 'paul-3', 'paul-rome', 'exodus-wilderness',
      'jesus-mark', 'jacob',
    ];
    final resolvedOrder = resolved.map((j) => j.id).toList();
    expect(resolvedOrder, assetOrder);
    final indices = on.map((e) => resolvedOrder.indexOf(e.id)).toList();
    expect(indices[0], lessThan(indices[1]));
  });
}
