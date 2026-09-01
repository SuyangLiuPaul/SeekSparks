/// #304 / check 54: folding the gazetteer's five exact-duplicate ordinal
/// pairs, and the fence that keeps it from widening to Antioch.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/bible_place.dart';

BiblePlace _p(
  String name, {
  required int? ordinal,
  double? lat,
  double? lon,
  String? simplified,
  String? traditional,
  List<PlaceRef> refs = const [],
}) =>
    BiblePlace(
      id: ordinal == null ? name : '$name $ordinal',
      name: name,
      ordinal: ordinal,
      simplified: simplified,
      traditional: traditional,
      lat: lat,
      lon: lon,
      refs: refs,
    );

void main() {
  group('mergeIdenticalPlaces', () {
    test('folds two records that agree in every field', () {
      final refs = [const PlaceRef('Joshua', 19, 44)];
      final a = _p('Baalath',
          ordinal: 1, lat: 31.92, lon: 35.05, simplified: '巴拉', refs: refs);
      final b = _p('Baalath',
          ordinal: 2, lat: 31.92, lon: 35.05, simplified: '巴拉', refs: refs);
      final out = mergeIdenticalPlaces([a, b]);
      expect(out.length, 1);
      expect(out.single.id, 'Baalath 1');
    });

    test('keeps two records that differ only in coordinate', () {
      final refs = [const PlaceRef('Acts', 13, 14)];
      final syrian = _p('Antioch', ordinal: 1, lat: 36.20, lon: 36.16, refs: refs);
      final pisidian = _p('Antioch', ordinal: 2, lat: 38.30, lon: 31.19, refs: refs);
      final out = mergeIdenticalPlaces([syrian, pisidian]);
      expect(out.length, 2);
    });

    test('keeps two records that differ only in references', () {
      final base = [const PlaceRef('Genesis', 1, 1)];
      final superset = [
        const PlaceRef('Genesis', 1, 1),
        const PlaceRef('Genesis', 2, 1),
      ];
      final a = _p('Egypt', ordinal: 1, lat: 30.0, lon: 31.0, refs: base);
      final b = _p('Egypt', ordinal: 2, lat: 30.0, lon: 31.0, refs: superset);
      final out = mergeIdenticalPlaces([a, b]);
      expect(out.length, 2);
    });

    test('the lower ordinal survives', () {
      final refs = [const PlaceRef('Numbers', 20, 1)];
      final three = _p('Zin', ordinal: 3, lat: 30.68, lon: 34.49, refs: refs);
      final two = _p('Zin', ordinal: 2, lat: 30.68, lon: 34.49, refs: refs);
      final out = mergeIdenticalPlaces([three, two]);
      expect(out.length, 1);
      expect(out.single.id.endsWith('2'), isTrue);
    });
  });

  group('the gazetteer', () {
    late List<BiblePlace> places;

    setUpAll(() {
      places = parseGazetteer(
        jsonDecode(File('assets/bible_places.json').readAsStringSync())
            as Map<String, dynamic>,
      );
    });

    String key(BiblePlace p) => '${p.name}|${p.lat}|${p.lon}|'
        '${p.simplified}|${p.traditional}|'
        '${(<String>[for (final r in p.refs) r.key]..sort()).join(',')}';

    test('no two places share a name, a coordinate and a reference list', () {
      final groups = <String, List<BiblePlace>>{};
      for (final p in places) {
        (groups[key(p)] ??= <BiblePlace>[]).add(p);
      }
      final dupes = groups.values.where((g) => g.length > 1).toList();
      expect(dupes, isEmpty,
          reason: 'duplicate groups: '
              '${dupes.map((g) => g.map((p) => p.id).toList())}');
    });

    test('the five folded ids are gone and their survivors remain', () {
      final ids = places.map((p) => p.id).toSet();
      for (final gone in [
        'Baalath 2',
        'Cabul 2',
        'Chinnereth 2',
        'Jezreel 3',
        'Zin 2',
      ]) {
        expect(ids.contains(gone), isFalse, reason: gone);
      }
      for (final kept in [
        'Baalath 1',
        'Cabul 1',
        'Chinnereth 1',
        'Jezreel 2',
        'Zin 1',
      ]) {
        expect(ids.contains(kept), isTrue, reason: kept);
      }
    });

    test('Joshua 19:44 names Baalath once', () {
      const refKey = 'Joshua|19|44';
      final hits = places.where((p) =>
          p.name == 'Baalath' && p.refs.any((r) => r.key == refKey));
      expect(hits.length, 1);
    });

    test('Antioch is still two places', () {
      final antiochs = places.where((p) => p.name == 'Antioch').toList();
      expect(antiochs.length, 2);
      expect(antiochs[0].lat != antiochs[1].lat, isTrue);
    });
  });
}
