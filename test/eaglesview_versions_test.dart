// The three Eagle's View imports (v1.6.18) and the Greek language group
// they introduced.
//
// The catalog is data, so the interesting assertions are the ones a
// careless edit would break: that Greek actually reaches the picker (it
// is the first non-en/zh language the app has ever had), that every new
// code is registered as tagged, and that the assets those codes name
// exist on disk with the shape the loader expects.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/services/tagged_text_service.dart';

void main() {
  const imported = ['kjvs', 'lxxwh', 'cuvs-plus'];

  group("Eagle's View versions", () {
    test('all three are in the catalog and enabled', () {
      final codes = availableVersions.map((v) => v.value).toSet();
      for (final c in imported) {
        expect(codes, contains(c), reason: '$c missing from the picker');
      }
    });

    test('all three are registered as Strong\'s-tagged', () {
      for (final c in imported) {
        expect(TaggedTextService.supports(c), isTrue, reason: c);
      }
    });

    test('Greek is its own language group, ordered last', () {
      expect(bibleLanguageOrder, contains('grc'));
      expect(bibleLanguageOrder.last, 'grc',
          reason: 'Greek is a study column, not a default reading language');
      expect(versionsForLanguage('grc').map((v) => v.value), ['lxxwh']);
      expect(bibleVersionLanguage('lxxwh'), 'grc');
    });

    test('KJV+S is distinct from the bundled KJV', () {
      // They are different editions of one translation. Collapsing them
      // would silently attach EV's word tagging to text it was not
      // aligned against.
      expect(availableVersions.map((v) => v.value), containsAll(['kjv', 'kjvs']));
      expect(shortBibleVersionLabel('kjvs'), isNot(shortBibleVersionLabel('kjv')));
    });

    test('a Greek primary pane gets a non-Greek comparison pane', () {
      // Only one Greek edition exists, so same-language would duplicate.
      final secondary = defaultSecondaryVersion('lxxwh');
      expect(secondary, isNot('lxxwh'));
      expect(bibleVersionLanguage(secondary), isNot('grc'));
    });

    test('all three cover the whole canon, so none needs a fallback', () {
      for (final c in imported) {
        expect(bibleVersionFullCanonFallback(c), isNull, reason: c);
      }
    });
  });

  group("Eagle's View assets", () {
    for (final code in imported) {
      test('$code.json is a flat verse list with Genesis and Revelation', () {
        final file = File('assets/$code.json');
        expect(file.existsSync(), isTrue, reason: 'assets/$code.json missing');
        final data = jsonDecode(file.readAsStringSync()) as List;
        expect(data.length, greaterThan(30000));
        final first = data.first as Map<String, dynamic>;
        expect(first.keys,
            containsAll(['book', 'chapter', 'verse', 'text', 'id']));
        expect(first['id'], '001001001');
        expect((first['text'] as String).trim(), isNotEmpty);
        expect((data.last as Map)['id'], startsWith('066'));
      });

      test('$code tagged runs carry Strong\'s numbers', () {
        final file = File('assets/tagged/$code/john.json');
        expect(file.existsSync(), isTrue);
        final verses = jsonDecode(file.readAsStringSync()) as Map;
        final runs = (verses['3:16'] as List)
            .map((j) => TaggedRun.fromJson(j as Map<String, dynamic>))
            .toList();
        expect(runs, isNotEmpty);
        // NT text must carry Greek numbers, never Hebrew ones — the
        // prefix is chosen per book, and getting it wrong is the exact
        // bug an earlier pass shipped.
        final tagged = runs.where((r) => r.isTagged).toList();
        expect(tagged, isNotEmpty);
        expect(tagged.every((r) => r.strongs.startsWith('G')), isTrue,
            reason: 'John is Greek: ${tagged.map((r) => r.strongs).take(6)}');
        expect(runs.map((r) => r.text).join(), isNotEmpty);
      });
    }

    test('Genesis tagging uses Hebrew numbers', () {
      final verses = jsonDecode(
          File('assets/tagged/kjvs/genesis.json').readAsStringSync()) as Map;
      final runs = (verses['1:1'] as List)
          .map((j) => TaggedRun.fromJson(j as Map<String, dynamic>))
          .toList();
      final tagged = runs.where((r) => r.isTagged).toList();
      expect(tagged.every((r) => r.strongs.startsWith('H')), isTrue);
      // H7225 rê'shîyth "beginning" opens the verse.
      expect(tagged.first.strongs, 'H7225');
    });

    test('tagged run text reassembles into the verse text', () {
      // The loader renders runs, the search pane reads plain text. If
      // the two disagree the same verse looks different in two panes.
      final plain = <String, String>{
        for (final r in jsonDecode(File('assets/kjvs.json').readAsStringSync())
            as List)
          (r as Map)['id'] as String: r['text'] as String,
      };
      final verses = jsonDecode(
          File('assets/tagged/kjvs/john.json').readAsStringSync()) as Map;
      for (final entry in (verses as Map<String, dynamic>).entries.take(50)) {
        final parts = (entry.key).split(':');
        final id = '043${parts[0].padLeft(3, '0')}${parts[1].padLeft(3, '0')}';
        final joined = (entry.value as List)
            .map((j) => (j as Map)['w'] as String)
            .join();
        expect(joined, plain[id], reason: 'John ${entry.key}');
      }
    });
  });
}
