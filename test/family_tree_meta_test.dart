// Guards for the Family Tree's `_meta` legend (#318 constraint 2 / #304).
//
// `assets/family_tree.json` has carried a `yearLegend` and a
// `dating.kinds` legend since the dating audit ran, and nothing in
// `lib/` parsed either — `grep -rn "yearLegend" lib/` returned zero
// lines. Same gap `HebrewKingsMeta` closed for the kings and #318 phase
// 24 closed for the wheel. A stamped asset is not a disclosed one.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/services/family_tree_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the asset\'s legend is trilingual', () {
    test('yearLegend.am and .bc are each en/zh-Hans/zh-Hant', () async {
      final doc = jsonDecode(await rootBundle.loadString(
          'assets/family_tree.json')) as Map<String, dynamic>;
      final meta = doc['_meta'] as Map<String, dynamic>;
      final legend = meta['yearLegend'] as Map<String, dynamic>;
      for (final key in ['am', 'bc']) {
        final entry = legend[key];
        expect(entry, isA<Map>(), reason: 'yearLegend.$key');
        final m = (entry as Map).cast<String, dynamic>();
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(m[locale], isA<String>(), reason: 'yearLegend.$key.$locale');
          expect((m[locale] as String).isNotEmpty, isTrue,
              reason: 'yearLegend.$key.$locale');
        }
      }
    });

    test('dating.kinds.{birth,reign,approximate} are each trilingual',
        () async {
      final doc = jsonDecode(await rootBundle.loadString(
          'assets/family_tree.json')) as Map<String, dynamic>;
      final meta = doc['_meta'] as Map<String, dynamic>;
      final kinds =
          (meta['dating'] as Map<String, dynamic>)['kinds'] as Map<String, dynamic>;
      for (final key in ['birth', 'reign', 'approximate']) {
        final entry = kinds[key];
        expect(entry, isA<Map>(), reason: 'dating.kinds.$key');
        final m = (entry as Map).cast<String, dynamic>();
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(m[locale], isA<String>(), reason: 'dating.kinds.$key.$locale');
          expect((m[locale] as String).isNotEmpty, isTrue,
              reason: 'dating.kinds.$key.$locale');
        }
      }
    });
  });

  test('FamilyTreeMeta reads every field the asset carries', () async {
    final doc = jsonDecode(await rootBundle
            .loadString('assets/family_tree.json')) as Map<String, dynamic>;
    final meta = FamilyTreeMeta.fromJson(
        (doc['_meta'] as Map).cast<String, dynamic>());
    expect(meta.yearLegendAmFor('en'), isNotEmpty);
    expect(meta.yearLegendBcFor('en'), isNotEmpty);
    expect(meta.kindBirthFor('en'), isNotEmpty);
    expect(meta.kindReignFor('en'), isNotEmpty);
    expect(meta.kindApproximateFor('en'), isNotEmpty);
    expect(meta.yearLegendAmFor('zh-Hant'), isNot(meta.yearLegendAmFor('zh-Hans')));
    expect(meta.yearLegendBcFor('zh-Hant'), isNot(meta.yearLegendBcFor('zh-Hans')));
    expect(meta.kindBirthFor('zh-Hant'), isNot(meta.kindBirthFor('zh-Hans')));
    expect(meta.kindReignFor('zh-Hant'), isNot(meta.kindReignFor('zh-Hans')));
    expect(meta.kindApproximateFor('zh-Hant'),
        isNot(meta.kindApproximateFor('zh-Hans')));
    // 28 births since Aaron was derived from Exodus 7:7 and
    // Numbers 33:39 instead of left as a reconstruction.
    expect(meta.counts, {'birth': 28, 'reign': 14, 'approximate': 235});
  });

  test('a bare string still parses as English (old-shape tolerance)', () {
    final meta = FamilyTreeMeta.fromJson({
      'yearLegend': {'am': 'x', 'bc': 'y'},
      'dating': {
        'kinds': {'birth': 'b', 'reign': 'r', 'approximate': 'a'},
        'counts': {'birth': 1, 'reign': 2, 'approximate': 3},
      },
    });
    expect(meta.yearLegendAmFor('en'), 'x');
    expect(meta.yearLegendAmFor('zh-Hans'), 'x');
    expect(meta.yearLegendBcFor('en'), 'y');
    expect(meta.kindBirthFor('en'), 'b');
    expect(meta.kindReignFor('en'), 'r');
    expect(meta.kindApproximateFor('en'), 'a');
    expect(meta.counts, {'birth': 1, 'reign': 2, 'approximate': 3});
  });

  test('the service exposes the meta after loadAll', () async {
    await FamilyTreeService.instance.loadAll();
    expect(FamilyTreeService.instance.meta.counts['approximate'], 235);
  });

  test('the legends do not name a chronology the file does not follow',
      () async {
    final doc = jsonDecode(await rootBundle.loadString(
        'assets/family_tree.json')) as Map<String, dynamic>;
    final meta = doc['_meta'] as Map<String, dynamic>;
    final blob = jsonEncode(meta['yearLegend']) +
        jsonEncode((meta['dating'] as Map)['kinds']);
    expect(blob.contains('Ussher'), isFalse);
    expect(blob.contains('乌雪'), isFalse);
    expect(blob.contains('烏雪'), isFalse);
  });
}
