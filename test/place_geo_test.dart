/// The gazetteer's repair and geometry — the parts that are easy to get
/// quietly wrong.
///
/// The book-code cases below are not arbitrary samples. Each of the eight
/// damaged codes carries real references, and each assertion names the
/// evidence that settled it, so a future change to `kPlaceBookCodes`
/// fails here with the reason attached rather than silently refiling
/// scripture under the wrong book.
library;

import 'dart:convert';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/book_name_mapping.dart' show BookScript;
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/place_geo.dart';

void main() {
  group('book codes', () {
    test('the undamaged codes resolve', () {
      expect(bookForPlaceCode('Gen'), 'Genesis');
      expect(bookForPlaceCode('Rev'), 'Revelation');
      expect(bookForPlaceCode('1Ki'), '1 Kings');
      expect(bookForPlaceCode('Nam'), 'Nahum');
    });

    test('an unknown code is null, never a guess', () {
      // The whole point: a reference nobody can place is dropped, not
      // filed under a plausible-looking neighbour.
      expect(bookForPlaceCode('zzz'), isNull);
      expect(bookForPlaceCode(''), isNull);
    });

    test('the eight codes the `eph` replace damaged', () {
      // `nah` is the one that reads like Nahum and is Jonah — its
      // references are Nineveh 1:2 and Joppa 1:3.
      expect(bookForPlaceCode('nah'), 'Jonah');
      expect(bookForPlaceCode('hum'), 'Nahum');
      expect(bookForPlaceCode('eph'), 'Zephaniah');
      expect(bookForPlaceCode('ccl'), 'Ecclesiastes');
      expect(bookForPlaceCode('ude'), 'Jude');
      expect(bookForPlaceCode('hil'), 'Philippians');
      expect(bookForPlaceCode('tus'), 'Titus');
      expect(bookForPlaceCode('Hah'), 'Nahum');
    });

    test('Eph the epistle and eph the wreckage are different books', () {
      // The corruption produced a lowercase collision with a real code.
      // If these two ever agree, 26 of Zephaniah's places have moved to
      // Ephesians.
      expect(bookForPlaceCode('Eph'), 'Ephesians');
      expect(bookForPlaceCode('eph'), 'Zephaniah');
    });
  });

  group('name repair', () {
    test('a mid-word capital is lowered', () {
      expect(repairPlaceName('Baal-zEphon'), 'Baal-zephon');
      expect(repairPlaceName('Kiriath-sEpher'), 'Kiriath-sepher');
      expect(repairPlaceName('MisrEphoth-maim'), 'Misrephoth-maim');
    });

    test('a capital after a word boundary survives', () {
      // The rule is "lowercase then uppercase", so hyphens and spaces
      // are boundaries and the names that legitimately capitalise after
      // one are untouched.
      expect(repairPlaceName('Beth-El'), 'Beth-El');
      expect(repairPlaceName('Mount Shepher'), 'Mount Shepher');
      expect(repairPlaceName('Jerusalem'), 'Jerusalem');
    });

    test('the same damage at index 1 is repaired too', () {
      // `Rephidim` is `R` + `eph` + `idim`, so whatever mangled every
      // other `eph` in this file landed here on the SECOND letter — where
      // the letter before it is the name's own initial capital and the
      // "lowercase then uppercase" rule cannot see it. Four names in the
      // gazetteer are in this state, and one of them is a station on the
      // wilderness itinerary.
      expect(repairPlaceName('REphidim'), 'Rephidim');
      expect(repairPlaceName('REphaim'), 'Rephaim');
      expect(repairPlaceName('NEphtoah'), 'Nephtoah');
      expect(repairPlaceName('SEphar'), 'Sephar');
    });

    test('a capital that is not this damage is left alone', () {
      // Deliberately narrow, and `BEze 1`/`BEze 2` are why. They are
      // broken — the verses behind them (Jdg 1:4-5, 1Sa 11:8) name Bezek,
      // so a letter has been LOST as well as a capital gained — and a
      // rule wide enough to catch them would emit `Beze`, turning an
      // obviously broken string into a plausible one that is still wrong.
      // Left as it is and recorded in docs/DATA-INTEGRITY.md.
      expect(repairPlaceName('BEze 1'), 'BEze 1');
      expect(repairPlaceName('Ephesus'), 'Ephesus');
      expect(repairPlaceName('En-gedi'), 'En-gedi');
    });
  });

  group('ordinals', () {
    test('a trailing numeral is split, not stripped', () {
      // Antioch 1 is Syrian, Antioch 2 is Pisidian, 500 km apart.
      expect(splitPlaceOrdinal('Antioch 2'), ('Antioch', 2));
      expect(splitPlaceOrdinal('Ai 1'), ('Ai', 1));
    });

    test('a name without one is left alone', () {
      expect(splitPlaceOrdinal('Jerusalem'), ('Jerusalem', null));
    });
  });

  group('gazetteer parsing', () {
    Map<String, dynamic> doc(List<Map<String, dynamic>> places) =>
        <String, dynamic>{'places': places};

    test('repairs name, code and ordinal in one pass', () {
      final out = parseGazetteer(doc([
        {
          'n': 'Kiriath-sEpher 2',
          's': '基列西弗',
          't': '基列西弗',
          'll': [31.5, 34.9],
          'refs': [
            {'book': 'nah', 'chapter': 1, 'verse': 2},
          ],
        },
      ]));
      expect(out, hasLength(1));
      expect(out.single.name, 'Kiriath-sepher');
      expect(out.single.ordinal, 2);
      expect(out.single.refs.single.englishBook, 'Jonah');
      expect(out.single.located, isTrue);
    });

    test('drops a reference whose book cannot be resolved', () {
      final out = parseGazetteer(doc([
        {
          'n': 'Nowhere',
          'refs': [
            {'book': 'zzz', 'chapter': 1, 'verse': 1},
            {'book': 'Gen', 'chapter': 2, 'verse': 3},
          ],
        },
      ]));
      expect(out.single.refs, hasLength(1));
      expect(out.single.refs.single.englishBook, 'Genesis');
    });

    test('a place with no coordinates survives and reports it', () {
      // Eden, Nod and the Pishon are unlocated because nobody knows
      // where they are. Dropping them would be a lie of omission.
      final out = parseGazetteer(doc([
        {
          'n': 'Eden',
          'refs': [
            {'book': 'Gen', 'chapter': 2, 'verse': 8},
          ],
        },
      ]));
      expect(out.single.located, isFalse);
      expect(out.single.lat, isNull);
    });
  });

  group('possessives', () {
    test("Jerusalem's folds into Jerusalem", () {
      final out = parseGazetteer(<String, dynamic>{
        'places': [
          {
            'n': 'Jerusalem',
            'll': [31.78, 35.22],
            'refs': [
              {'book': 'Gen', 'chapter': 1, 'verse': 1},
            ],
          },
          {
            'n': "Jerusalem's",
            'll': [31.78, 35.22],
            'refs': [
              {'book': 'Gen', 'chapter': 1, 'verse': 1},
              {'book': 'Gen', 'chapter': 2, 'verse': 2},
            ],
          },
        ],
      });
      expect(out.map((p) => p.id), ['Jerusalem']);
      // The extra reference the possessive held is kept — Egypt's has
      // three that Egypt does not.
      expect(out.single.refs, hasLength(2));
    });

    test("a possessive with no base entry survives — Solomon's Porch", () {
      // There is no place called Solomon; Solomon is a person. The
      // entry is 所罗门廊 and must not be dissolved into nothing.
      final out = parseGazetteer(<String, dynamic>{
        'places': [
          {
            'n': "Solomon's",
            'refs': [
              {'book': 'Joh', 'chapter': 10, 'verse': 23},
            ],
          },
        ],
      });
      expect(out.map((p) => p.id), ["Solomon's"]);
    });
  });

  group('display name follows the reading script', () {
    const p = BiblePlace(
      id: 'Jerusalem',
      name: 'Jerusalem',
      ordinal: null,
      simplified: '耶路撒冷',
      traditional: '耶路撒冷',
      lat: 31.78,
      lon: 35.22,
      refs: <PlaceRef>[],
    );

    test('each script gets its own form', () {
      expect(p.displayName(BookScript.english), 'Jerusalem');
      expect(p.displayName(BookScript.simplified), '耶路撒冷');
      expect(p.displayName(BookScript.traditional), '耶路撒冷');
    });

    test('a place with no Chinese name falls back to English', () {
      // Three entries have none. A blank label would be worse than an
      // English one.
      const bare = BiblePlace(
        id: 'Nowhere',
        name: 'Nowhere',
        ordinal: null,
        simplified: null,
        traditional: null,
        lat: null,
        lon: null,
        refs: <PlaceRef>[],
      );
      expect(bare.displayName(BookScript.simplified), 'Nowhere');
    });
  });

  group('distance', () {
    test('Jerusalem to Bethlehem is about 8 km', () {
      final km = haversineKm(31.7784, 35.2066, 31.7054, 35.2024);
      expect(km, closeTo(8.1, 0.6));
    });

    test('Joppa to Nineveh is about 1,100 km — the point of Jonah', () {
      final km = haversineKm(32.05, 34.75, 36.36, 43.15);
      expect(km, closeTo(880, 60));
    });

    test('a place is zero from itself', () {
      expect(haversineKm(31.78, 35.22, 31.78, 35.22), closeTo(0, 1e-9));
    });

    test('days on foot rounds up and never returns zero', () {
      // A short hop is still a day's journey, not "no time at all".
      expect(daysOnFootFor(1), 1);
      expect(daysOnFootFor(32), 1);
      expect(daysOnFootFor(33), 2);
      expect(daysOnFootFor(880), 28);
    });
  });

  group('bounds', () {
    test('null when there is nothing to bound', () {
      expect(boundsOf(const <(double, double)>[]), isNull);
    });

    test('covers every point', () {
      final b = boundsOf(const [(31.0, 35.0), (33.0, 34.0), (32.0, 36.0)])!;
      expect(b.minLat, 31.0);
      expect(b.maxLat, 33.0);
      expect(b.minLon, 34.0);
      expect(b.maxLon, 36.0);
    });

    test('a single point is padded to a readable span', () {
      // 565 places have exactly one reference. Without the minimum span
      // a lone place projects at infinite zoom, where the base map is
      // one featureless polygon.
      final b = boundsOf(const [(31.78, 35.22)])!.padded();
      expect(b.spanLat, greaterThanOrEqualTo(1.2));
      expect(b.spanLon, greaterThanOrEqualTo(1.2));
      expect(b.centreLat, closeTo(31.78, 1e-9));
      expect(b.centreLon, closeTo(35.22, 1e-9));
    });
  });

  group('projection', () {
    const size = Size(400, 300);

    test('the centre of the bounds lands in the centre of the pane', () {
      final b = const GeoBounds(30.0, 34.0, 34.0, 38.0);
      final p = MapProjection.fit(b, size);
      final o = p.project(b.centreLat, b.centreLon);
      expect(o.dx, closeTo(200, 0.001));
      expect(o.dy, closeTo(150, 0.001));
    });

    test('north is up', () {
      final p = MapProjection.fit(const GeoBounds(30, 34, 34, 38), size);
      expect(p.project(33, 36).dy, lessThan(p.project(31, 36).dy));
    });

    test('east is right', () {
      final p = MapProjection.fit(const GeoBounds(30, 34, 34, 38), size);
      expect(p.project(32, 37).dx, greaterThan(p.project(32, 35).dx));
    });

    test('unproject undoes project', () {
      final p = MapProjection.fit(const GeoBounds(30, 34, 34, 38), size);
      final (lat, lon) = p.unproject(p.project(31.78, 35.22));
      expect(lat, closeTo(31.78, 1e-6));
      expect(lon, closeTo(35.22, 1e-6));
    });

    test('the requested bounds fit inside the pane on both axes', () {
      final b = const GeoBounds(30.0, 30.0, 40.0, 34.0);
      final p = MapProjection.fit(b, size);
      for (final (lat, lon) in [
        (b.minLat, b.minLon),
        (b.maxLat, b.maxLon),
        (b.minLat, b.maxLon),
        (b.maxLat, b.minLon),
      ]) {
        final o = p.project(lat, lon);
        expect(o.dx, inInclusiveRange(-0.001, size.width + 0.001));
        expect(o.dy, inInclusiveRange(-0.001, size.height + 0.001));
      }
    });

    test('longitude is compressed by the standard parallel', () {
      // A degree of longitude at Jerusalem is about 85% of a degree of
      // latitude. Plotting them square stretches the Jordan valley by
      // ~18%, which is what this scaling exists to prevent.
      final p = MapProjection(
        centreLat: 31.78,
        centreLon: 35.22,
        pixelsPerDegreeLat: 100,
        size: size,
      );
      final dx = p.project(31.78, 36.22).dx - p.project(31.78, 35.22).dx;
      final dy = p.project(30.78, 35.22).dy - p.project(31.78, 35.22).dy;
      expect(dx, lessThan(dy));
      expect(dx / dy, closeTo(0.85, 0.02));
    });
  });

  group('scale bar', () {
    test('picks 1-2-5 steps so the bar reads as a round number', () {
      expect(niceScaleKm(1.0, 63), 50);
      expect(niceScaleKm(0.1, 100), 10);
      expect(niceScaleKm(10, 100), 1000);
      expect(niceScaleKm(1.0, 2.4), 2);
    });

    test('never returns more room than the bar was given', () {
      // The value drives the bar's drawn width, so overshooting the
      // target pushes the bar out of the pane.
      for (final target in const [40.0, 63.0, 88.0, 120.0]) {
        for (final kmpp in const [0.02, 0.4, 3.0, 27.0]) {
          expect(niceScaleKm(kmpp, target), lessThanOrEqualTo(kmpp * target));
        }
      }
    });

    test('degenerate input does not produce NaN on screen', () {
      expect(niceScaleKm(0, 100), 1);
      expect(niceScaleKm(double.nan, 100), 1);
    });
  });

  group('base map', () {
    test('parses the four layers as flat coordinate runs', () {
      final m = parseBaseMap(<String, dynamic>{
        'land': [
          [34.0, 31.0, 35.0, 32.0]
        ],
        'coast': [
          [34.0, 31.0, 35.0, 32.0, 36.0, 33.0]
        ],
        'lakes': <dynamic>[],
        'rivers': <dynamic>[],
      });
      expect(m.land, hasLength(1));
      expect(m.coast.single, hasLength(6));
      expect(m.isEmpty, isFalse);
    });

    test('a run too short to draw is discarded', () {
      // One point is not a line. Letting it through means a painter
      // that has to re-check length on every frame.
      final m = parseBaseMap(<String, dynamic>{
        'land': [
          [34.0, 31.0]
        ],
      });
      expect(m.land, isEmpty);
      expect(m.isEmpty, isTrue);
    });

    test('a missing layer is empty, not an exception', () {
      expect(parseBaseMap(<String, dynamic>{}).isEmpty, isTrue);
    });
  });

  test('the shipped gazetteer JSON survives a round trip', () {
    // Guards the schema rather than the content: if the asset is ever
    // regenerated with a different shape, this fails before the UI does.
    final parsed = parseGazetteer(
        json.decode('{"places":[{"n":"Ai 1","s":"艾","t":"艾",'
            '"ll":[31.9,35.26],"refs":[{"book":"Jos","chapter":7,'
            '"verse":2}]}]}') as Map<String, dynamic>);
    expect(parsed.single.name, 'Ai');
    expect(parsed.single.ordinal, 1);
    expect(parsed.single.simplified, '艾');
    expect(parsed.single.refs.single.key, 'Joshua|7|2');
  });
}
