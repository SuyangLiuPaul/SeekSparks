// The atlas ruler's decision about what it may say (#317).
//
// `rulerReadingFor` is the whole defect: a place on the SELECTED place's
// own gazetteer coordinate is not a distance of zero, it is the absence
// of a distance, and the two must never share one string.

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/services/places_service.dart';
import 'package:seeksparks/utils/place_ruler.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rulerReadingFor', () {
    test('a place on the selected place\'s own point is not a distance of zero', () {
      final selected = _place('jerusalem', 31.77, 35.23);
      final samePoint = _place('dung-gate', 31.77, 35.23);
      final measured = _place('jericho', 31.70, 35.20);
      final reading = rulerReadingFor(selected, [samePoint, measured]);

      expect(reading.measured.length, 1);
      expect(reading.samePoint.length, 1);
      expect(reading.measured.single.km, greaterThan(0));
      expect(reading.samePoint.single.id, 'dung-gate');
    });

    test(
        "Nehemiah 3 separates the wall's own gates from the towns that "
        'sent workers', () async {
      // Neh 3 names both Jerusalem's own gates/towers/walls (all on
      // Jerusalem's single gazetteer point — 19 of them, measured
      // against the live asset) AND real outside towns whose men helped
      // build (Jericho, Gibeon, Beth-haccherem, Beth-zur, Keilah, Mizpah,
      // Zanoah — each at its own distinct coordinate). The ruler must
      // keep those two groups apart rather than declaring the whole
      // chapter unmeasurable.
      final chapter = await PlacesService.forChapter('Nehemiah', 3);
      final jerusalem = chapter.firstWhere((p) => p.name == 'Jerusalem');
      final reading = rulerReadingFor(jerusalem, chapter);

      expect(reading.samePoint.length, greaterThanOrEqualTo(15));
      final samePointNames = reading.samePoint.map((p) => p.name).toSet();
      expect(samePointNames, contains('Dung Gate'));
      expect(samePointNames, contains('Broad Wall'));
      expect(samePointNames, isNot(contains('Jericho')));
      expect(samePointNames, isNot(contains('Gibeon')));

      expect(reading.measured, isNotEmpty);
      final measuredNames = reading.measured.map((e) => e.place.name).toSet();
      expect(measuredNames.intersection(samePointNames), isEmpty);
    });

    test('the selection itself never appears', () {
      final selected = _place('jerusalem', 31.77, 35.23);
      final same = _place('jerusalem', 31.77, 35.23);
      final reading = rulerReadingFor(selected, [same]);

      expect(reading.measured, isEmpty);
      expect(reading.samePoint, isEmpty);
    });

    test('an unlocated candidate is neither measured nor co-located', () {
      final selected = _place('jerusalem', 31.77, 35.23);
      final unlocated = _place('unknown', null, null);
      final reading = rulerReadingFor(selected, [unlocated]);

      expect(reading.measured, isEmpty);
      expect(reading.samePoint, isEmpty);
    });
  });

  group('rulerKmLabel', () {
    test('a distance under half a kilometre still prints a number', () {
      expect(rulerKmLabel(0.4), '0.4');
      expect(rulerKmLabel(9.9), '9.9');
      expect(rulerKmLabel(10.4), '10');
    });
  });

  group('placesMapSamePoint string', () {
    test('the string names the count and the names', () {
      final row = uiStrings['placesMapSamePoint'];
      expect(row, isNotNull);
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final value = row![locale];
        expect(value, isNotNull, reason: locale);
        expect(value, isNotEmpty, reason: locale);
        expect(value, contains('{n}'), reason: locale);
        expect(value, contains('{names}'), reason: locale);
        expect(value, isNot(contains('0 km')), reason: locale);
        expect(value, isNot(contains('0')), reason: locale);
      }
    });

    test('the singular has its own string, in all three locales', () {
      final row = uiStrings['placesMapSamePointOne'];
      expect(row, isNotNull);
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final value = row![locale];
        expect(value, isNotNull, reason: locale);
        expect(value, isNotEmpty, reason: locale);
        expect(value, contains('{name}'), reason: locale);
        expect(value, isNot(contains('{n}')), reason: locale);
        expect(value, isNot(contains('{names}')), reason: locale);
      }
    });
  });

  group('samePointSentence', () {
    test('one co-located place reads as one — the 63.8% case', () {
      final result = samePointSentence(['Dung Gate'], 'en');
      expect(result, contains('Dung Gate'));
      expect(result, isNot(contains(' in all')));
      expect(result, isNot(contains('{')));
      expect(result, isNot(contains('、')));
      expect(result, isNot(contains('0 km')));
    });

    test('an English reader never sees the ideographic comma', () {
      final result = samePointSentence(['Dung Gate', 'Broad Wall'], 'en');
      expect(result, contains('Dung Gate, Broad Wall'));
      expect(result, isNot(contains('、')));
    });

    test('a Chinese reader gets the Chinese separator', () {
      final simplified = samePointSentence(['汲水门', '宽墙'], 'zh-Hans');
      expect(simplified, contains('汲水门、宽墙'));
      expect(simplified, isNot(contains(', ')));
      expect(simplified, isNot(contains('{')));

      final traditional = samePointSentence(['汲水門', '寬牆'], 'zh-Hant');
      expect(traditional, contains('汲水門、寬牆'));
      expect(traditional, isNot(contains(', ')));
      expect(traditional, isNot(contains('{')));
    });

    test(
        'more names than the footer holds still report the true count', () {
      final names = List.generate(19, (i) => 'Place$i');
      final result = samePointSentence(names, 'en');
      expect(result, contains('19'));
      expect(result, contains('Place0'));
      expect(result, contains('Place3'));
      expect(result, isNot(contains('Place4')));
      expect(result, isNot(contains('{')));
    });

    test('nothing co-located, nothing said', () {
      expect(samePointSentence(const [], 'en'), isNull);
    });

    test('the sentence Nehemiah 3 actually produces names no distance',
        () async {
      final chapter = await PlacesService.forChapter('Nehemiah', 3);
      final jerusalem = chapter.firstWhere((p) => p.name == 'Jerusalem');
      final reading = rulerReadingFor(jerusalem, chapter);
      final names = reading.samePoint.map((p) => p.name).toList();
      final result = samePointSentence(names, 'en');

      expect(result, isNotNull);
      expect(result, isNot(contains(' km')));
      expect(result, isNot(contains('{')));
      expect(result, contains('${reading.samePoint.length}'));
    });
  });
}
