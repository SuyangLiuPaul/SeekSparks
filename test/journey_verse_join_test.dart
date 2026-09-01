// The join between a journey stop's place name and the verse it cites,
// against the shipped English editions (#317).
//
// `journey_asset_test.dart` guards this asset against the gazetteer: every
// stop resolves to a place, every provisional stop says why. It never opens
// a Bible. The place name and the verse text share no key, so the one
// question #317 actually asks — does the verse this stop cites name this
// stop? — has never been guarded at all.
//
// The answer is not always "fix the citation". Of 127 stops, three cite a
// verse that names them in none of `kjv.json`, `bsb.json` or `leb.json`, and
// the three are three different things: a spelling difference between the
// gazetteer and the text, an inference the row already discloses, and one
// real undisclosed gap — a route's own starting marker citing a verse that
// names no city at all. The first two are legitimate and are enumerated
// below, verified in both directions so the exception itself stays honest
// rather than merely being allowed to exist. The third is the repair this
// file exists to have forced.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _editionPaths = <String>[
  'assets/kjv.json',
  'assets/bsb.json',
  'assets/leb.json',
];

/// Strips a trailing gazetteer ordinal, so `Antioch 1` searches for `Antioch`.
String _bare(String place) => place.replaceAll(RegExp(r'\s+\d+$'), '');

// A stop the editions spell differently from the gazetteer. The value is
// the form that IS in the text — enumerated so that the exception is
// itself checked, not merely asserted.
const spelled = <String, String>{
  'paul-2/14': 'Cenchrea', // gazetteer 'Cenchreae'; KJV, BSB and LEB all
  // print 'Cenchrea' at Acts 18:18.
  'abraham/4': 'Negev', // gazetteer 'Negeb'; BSB and LEB print 'Negev'
  'abraham/6': 'Negev', // at 12:9 and 13:1, and KJV says only 'the south'.
};

// A stop the cited verse genuinely does not name. Allowed only where the
// row SAYS SO. The value is a substring the English note must contain, so
// that the disclosure cannot be quietly deleted while the exception stays.
const unnamed = <String, String>{
  'paul-2/0': '15:35', // Acts 15:40 names no city; 15:35 does.
  'jesus-mark/2': 'hometown', // Mark 6:1 is 'his hometown'; Mark names
  // Nazareth only at 1:9 and 1:24.
  'ark/7': 'city of David', // 2 Samuel 6:12 brings the ark up "into the
  // city of David" and no shipped edition names Jerusalem anywhere in
  // 2 Samuel 6; 1 Chronicles 15:3 is the parallel account and does.
};

void main() {
  final editions = <String, Map<String, String>>{};
  for (final path in _editionPaths) {
    final raw = json.decode(File(path).readAsStringSync()) as List<dynamic>;
    final byRef = <String, String>{};
    for (final row in raw) {
      final rec = row as Map<String, dynamic>;
      final chapter = int.tryParse('${rec['chapter']}');
      final verse = int.tryParse('${rec['verse']}');
      if (chapter == null || verse == null) continue;
      byRef['${rec['book']} $chapter:$verse'] = '${rec['text']}';
    }
    editions[path] = byRef;
  }

  final doc =
      json.decode(File('assets/bible_journeys.json').readAsStringSync())
          as Map<String, dynamic>;
  final journeys = doc['journeys'] as List<dynamic>;

  final stops = <({String journeyId, int index, String place, String ref})>[];
  for (final j in journeys) {
    final journey = j as Map<String, dynamic>;
    final journeyStops = journey['stops'] as List<dynamic>;
    for (var i = 0; i < journeyStops.length; i++) {
      final s = journeyStops[i] as Map<String, dynamic>;
      final ref = '${s['book']} ${s['chapter']}:${s['verse']}';
      stops.add((
        journeyId: journey['id'] as String,
        index: i,
        place: s['place'] as String,
        ref: ref,
      ));
    }
  }

  String? noteEn(String journeyId, int index) {
    final journey =
        journeys.firstWhere((j) => (j as Map<String, dynamic>)['id'] == journeyId)
            as Map<String, dynamic>;
    final s = (journey['stops'] as List<dynamic>)[index] as Map<String, dynamic>;
    final note = s['note'] as Map<String, dynamic>?;
    return note?['en'] as String?;
  }

  Map<String, dynamic>? noteAll(String journeyId, int index) {
    final journey =
        journeys.firstWhere((j) => (j as Map<String, dynamic>)['id'] == journeyId)
            as Map<String, dynamic>;
    final s = (journey['stops'] as List<dynamic>)[index] as Map<String, dynamic>;
    return s['note'] as Map<String, dynamic>?;
  }

  bool named(String place, String ref) {
    final bare = _bare(place).toLowerCase();
    for (final byRef in editions.values) {
      final text = byRef[ref];
      if (text != null && text.toLowerCase().contains(bare)) return true;
    }
    return false;
  }

  group('the join between a stop and the verse it cites', () {
    test('every stop cites a verse the shipped English editions actually have',
        () {
      final missing = <String>[
        for (final s in stops)
          if (!editions.values.every((byRef) => byRef.containsKey(s.ref)))
            '${s.journeyId}/${s.index} ${s.place} (${s.ref})',
      ];
      expect(missing, isEmpty,
          reason: 'a citation is mistyped or versification has moved');
    });

    test('every stop is named by the verse it cites, or is enumerated below',
        () {
      final unguarded = <String>[];
      for (final s in stops) {
        final key = '${s.journeyId}/${s.index}';
        if (named(s.place, s.ref)) continue;
        if (spelled.containsKey(key)) continue;
        if (unnamed.containsKey(key)) continue;
        final kjvText = editions['assets/kjv.json']![s.ref];
        unguarded.add(
          '$key ${s.place} (${s.ref}) — KJV: $kjvText',
        );
      }
      expect(unguarded, isEmpty,
          reason:
              'a stop cites a verse naming neither it nor an enumerated exception');
    });

    test('every enumerated spelling really is the form in the text', () {
      for (final entry in spelled.entries) {
        final parts = entry.key.split('/');
        final journeyId = parts[0];
        final index = int.parse(parts[1]);
        final s = stops.firstWhere(
            (s) => s.journeyId == journeyId && s.index == index);
        expect(named(s.place, s.ref), isFalse,
            reason:
                '${entry.key}: this now resolves under the gazetteer spelling — the exception is stale');
        final foundInSome = editions.values.any((byRef) {
          final text = byRef[s.ref];
          return text != null &&
              text.toLowerCase().contains(entry.value.toLowerCase());
        });
        expect(foundInSome, isTrue,
            reason:
                '${entry.key}: "${entry.value}" is not in any edition at ${s.ref}');
      }
    });

    test('every stop the text does not name says so on its own row', () {
      for (final entry in unnamed.entries) {
        final parts = entry.key.split('/');
        final journeyId = parts[0];
        final index = int.parse(parts[1]);
        final s = stops.firstWhere(
            (s) => s.journeyId == journeyId && s.index == index);
        expect(named(s.place, s.ref), isFalse,
            reason:
                '${entry.key}: this now resolves — the exception is stale');
        final note = noteAll(journeyId, index);
        expect(note, isNotNull, reason: '${entry.key} has no note at all');
        for (final locale in const <String>['en', 'zh-Hans', 'zh-Hant']) {
          final text = note![locale] as String?;
          expect(text, isNotNull, reason: '${entry.key} note $locale');
          expect(text, isNotEmpty, reason: '${entry.key} note $locale');
        }
        final en = noteEn(journeyId, index);
        expect(en, isNotNull, reason: '${entry.key} has no English note');
        expect(en!.contains(entry.value), isTrue,
            reason:
                '${entry.key}: note does not contain "${entry.value}" — the disclosure is missing');
      }
    });

    test('the tables name only stops that exist', () {
      final keys = <String>{for (final s in stops) '${s.journeyId}/${s.index}'};
      for (final key in [...spelled.keys, ...unnamed.keys]) {
        expect(keys.contains(key), isTrue,
            reason: '$key does not resolve to a real stop — a stale exception');
      }
    });
  });
}
