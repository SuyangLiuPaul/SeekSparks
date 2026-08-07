/// The gazetteer read verse-first, against the REAL bundled asset.
///
/// A parser test on a hand-written fixture proves the parser; it does not
/// prove that `assets/bible_places.json` actually yields anything when the
/// app asks for a verse. Since the whole point of task #277 is that the
/// file shipped in the repo for months without ever being loaded, the
/// tests that matter here are the ones that load it for real.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/services/places_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PlacesService.resetForTest);

  test('the bundled gazetteer loads and is not trivially small', () async {
    final places = await PlacesService.all();
    expect(places.length, greaterThan(500));
    expect(PlacesService.attribution, isNotEmpty);
  });

  test('Jonah 1:2 names Nineveh — the repaired `nah` code', () async {
    final places = await PlacesService.forVerse('Jonah', 1, 2);
    expect(places.map((p) => p.name), contains('Nineveh'));
  });

  test('Jonah 1:3 names Joppa and Tarshish', () async {
    final names =
        (await PlacesService.forVerse('Jonah', 1, 3)).map((p) => p.name);
    expect(names, contains('Joppa'));
    expect(names, contains('Tarshish'));
  });

  test('Nahum 1:1 is not filed under Jonah', () async {
    final jonah = (await PlacesService.forVerse('Jonah', 1, 1)).map((p) => p.name);
    expect(jonah, isNot(contains('Elkosh')));
    final nahum = (await PlacesService.forVerse('Nahum', 1, 1)).map((p) => p.name);
    expect(nahum, contains('Elkosh'));
  });

  test('a chapter lists each place once, however often it is named',
      () async {
    final chapter = await PlacesService.forChapter('Jonah', 1);
    final ids = chapter.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('the passage split does not list a verse place twice', () async {
    final data = await PlacesService.forPassage('Jonah', 1, 3);
    final verseIds = data.verse.map((p) => p.id).toSet();
    for (final p in data.chapter) {
      expect(verseIds.contains(p.id), isFalse,
          reason: '${p.id} is in both tiers');
    }
    expect(data.all.length, data.verse.length + data.chapter.length);
    expect(data.isEmpty, isFalse);
  });

  test('a verse naming no place still gets its chapter', () async {
    // Genesis 1:1 names nowhere, but Genesis 2 does (Eden, Havilah,
    // Cush, Assyria) — the second tier is what keeps the pane from
    // reading as broken.
    final data = await PlacesService.forPassage('Genesis', 2, 1);
    expect(data.verse, isEmpty);
    expect(data.chapter, isNotEmpty);
    expect(data.isEmpty, isFalse);
  });

  test('the base map loads with land and coastline', () async {
    final map = await PlacesService.baseMap();
    expect(map.isEmpty, isFalse);
    expect(map.land, isNotEmpty);
    expect(map.coast, isNotEmpty);
    // Every run is a flat lon/lat list, so an odd length would mean the
    // painter reads one coordinate off the end of every subsequent run.
    for (final run in [...map.land, ...map.coast, ...map.lakes, ...map.rivers]) {
      expect(run.length.isEven, isTrue);
    }
  });

  test('located places carry coordinates in a plausible range', () async {
    final places = await PlacesService.all();
    final located = places.where((p) => p.located).toList();
    expect(located.length, greaterThan(300));
    for (final p in located) {
      expect(p.lat!, inInclusiveRange(-90, 90));
      expect(p.lon!, inInclusiveRange(-180, 180));
    }
  });
}
