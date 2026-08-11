// Map provenance, pinned to the shipped archive (task #300).
//
// The defect this file guards was not a crash: 40 Sweet Publishing
// plates ship under CC BY-SA 3.0 with `AttributionRequired = true`, and
// the app named nobody. A licence breach is invisible to every other
// test in the suite, because the code runs perfectly while doing it.
//
// So the assertions are mostly about the DATA: that every plate resolves
// to a record, that every record states its licence out loud, and that a
// record demanding attribution carries the words that satisfy it. The
// counts are frozen too, because the About page prints them and a page
// that says "40 plates" over a data file that grew to 60 is lying.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/bible_map.dart';
import 'package:seeksparks/models/map_provenance.dart';

List<Map<String, dynamic>> _readJsonList(String path, [String? key]) {
  final raw = jsonDecode(File(path).readAsStringSync());
  final list = key == null ? raw as List : (raw as Map<String, dynamic>)[key] as List;
  return list.cast<Map<String, dynamic>>();
}

void main() {
  final entries = _readJsonList('assets/maps_index.json');
  final records = {
    for (final r in _readJsonList('assets/maps_provenance.json', 'collections'))
      r['id'] as String: MapProvenance.fromJson(r),
  };

  group('the provenance asset', () {
    test('every plate names a collection that has a record', () {
      final missing = <String>{};
      for (final e in entries) {
        final id = e['collection'] as String?;
        if (id == null || !records.containsKey(id)) missing.add('$id');
      }
      expect(missing, isEmpty,
          reason: 'plates naming a collection nobody recorded: $missing');
    });

    test('every record states a licence explicitly, unknown included', () {
      // An absent licence means "not checked" and an `unknown` one means
      // "checked, and the answer is nobody knows". Writing the second as
      // the first is the whole failure this task existed to fix.
      for (final r in records.values) {
        expect(r.license, isNotEmpty, reason: r.id);
      }
      final unknown = records.values.where((r) => !r.isKnown).map((r) => r.id);
      expect(unknown, containsAll(<String>['scene-topups', 'bundled-maps']));
    });

    test('a licence claim carries the basis it was made on', () {
      // "public domain because the artist died in 1902" and "public
      // domain because the description said so" are not the same claim.
      for (final r in records.values) {
        if (r.isKnown) {
          expect(r.licenseBasis, isNot(LicenseBasis.notRecorded), reason: r.id);
        } else {
          expect(r.licenseBasis, LicenseBasis.notRecorded, reason: r.id);
        }
      }
    });

    test('a record that demands attribution supplies the credit', () {
      final demanding = records.values.where((r) => r.mustCredit).toList();
      expect(demanding, isNotEmpty,
          reason: 'the Sweet plates require it; an empty set means the '
              'flag was lost, not that the obligation went away');
      for (final r in demanding) {
        expect(r.credit, isNotNull, reason: r.id);
        expect(r.credit!.trim(), isNotEmpty, reason: r.id);
        expect(r.licenseUrl, isNotNull, reason: r.id);
      }
    });

    test('the Sweet credit names the author the licence requires', () {
      final sweet = records['sweet']!;
      expect(sweet.license, 'cc-by-sa-3.0');
      expect(sweet.mustCredit, isTrue);
      expect(sweet.credit, contains('Jim Padgett'));
      expect(sweet.credit, contains('Sweet Publishing'));
    });

    test('the About page and the viewer print the SAME credit', () {
      // The About page reads `kSweetCredit`, the viewer reads the asset.
      // A licence satisfied on one screen and paraphrased on the other
      // is not satisfied.
      expect(records['sweet']!.credit, kSweetCredit);
    });

    test('public-domain records do not claim a credit is required', () {
      for (final r in records.values.where((r) => r.license == 'public-domain')) {
        expect(r.mustCredit, isFalse, reason: r.id);
      }
    });

    test('every record is named in all three reading locales', () {
      for (final r in records.values) {
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(r.name[locale], isNotNull, reason: '${r.id} / $locale');
          expect(r.name[locale], isNotEmpty, reason: '${r.id} / $locale');
        }
      }
    });
  });

  group('the counts the About page prints', () {
    Iterable<Map<String, dynamic>> inCollection(String id) =>
        entries.where((e) => e['collection'] == id);

    test('40 Sweet plates, each with the file page it came from', () {
      final sweet = inCollection('sweet').toList();
      expect(sweet.length, 40);
      for (final e in sweet) {
        expect(e['sourceUrl'], isNotNull, reason: e['id'] as String);
        expect(e['sourceUrl'] as String,
            startsWith('https://commons.wikimedia.org/'));
      }
    });

    test('151 plates whose origin is not recorded', () {
      final unrecorded = entries.where((e) {
        final r = records[e['collection']];
        return r == null || !r.isKnown;
      });
      expect(unrecorded.length, 151);
    });

    test('the archive is still 1,192 plates', () {
      expect(entries.length, 1192);
    });
  });

  group('BibleMap.fromJson', () {
    test('an entry with no provenance keys still parses', () {
      // The archive is regenerated by tooling and a plate added by hand
      // must not take the viewer down with it.
      final m = BibleMap.fromJson(const <String, dynamic>{
        'id': 'x',
        'title': <String, dynamic>{'en': 'X'},
        'file': 'x.jpg',
      });
      expect(m.collection, 'unrecorded');
      expect(m.sourceUrl, isNull);
    });

    test('collection and sourceUrl round-trip', () {
      final m = BibleMap.fromJson(const <String, dynamic>{
        'id': 'x',
        'title': <String, dynamic>{'en': 'X'},
        'file': 'x.jpg',
        'collection': 'sweet',
        'sourceUrl': 'https://example.invalid/x',
      });
      expect(m.collection, 'sweet');
      expect(m.sourceUrl, 'https://example.invalid/x');
    });
  });

  group('mapCreditLine', () {
    const unknownLabel = 'Source not recorded';

    test('an unrecorded plate SAYS so rather than printing nothing', () {
      // Drawing nothing would be indistinguishable from a public-domain
      // plate that needs no credit, and the two are opposites.
      expect(mapCreditLine(MapProvenance.unrecorded, 'en',
              unknownLabel: unknownLabel),
          unknownLabel);
    });

    test('a required credit is printed verbatim, not summarised', () {
      final line =
          mapCreditLine(records['sweet']!, 'en', unknownLabel: unknownLabel);
      expect(line, records['sweet']!.credit);
    });

    test('a courtesy credit is printed even where none is required', () {
      // Tissot is public domain and owes nobody anything. Naming the
      // painter is still the more useful line to a reader looking at a
      // painting, so the function does not gate the credit on the
      // obligation.
      final tissot = records['tissot']!;
      expect(tissot.mustCredit, isFalse);
      expect(mapCreditLine(tissot, 'en', unknownLabel: unknownLabel),
          tissot.credit);
    });

    test('every known collection carries a credit to print', () {
      // Otherwise the bar below a painting reads as a category label.
      for (final r in records.values.where((r) => r.isKnown)) {
        expect(r.credit, isNotNull, reason: r.id);
        expect(r.credit!.trim(), isNotEmpty, reason: r.id);
      }
    });

    const creditless = MapProvenance(
      id: 'x',
      name: {'en': 'Some collection', 'zh-Hant': '某個系列'},
      license: 'public-domain',
      licenseBasis: LicenseBasis.authorDeath,
    );

    test('a record with no credit falls back to the collection name', () {
      expect(mapCreditLine(creditless, 'en', unknownLabel: unknownLabel),
          'Some collection');
    });

    test('the fallback follows the reading locale', () {
      expect(mapCreditLine(creditless, 'zh-Hant', unknownLabel: ''), '某個系列');
    });

    test('an unlocalised name falls back to English, not to the id', () {
      expect(mapCreditLine(creditless, 'zh-Hans', unknownLabel: ''),
          'Some collection');
    });
  });
}
