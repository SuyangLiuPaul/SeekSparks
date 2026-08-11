// Regression guard for the bundled English KJV assets (check 27).
//
// `assets/kjv.json` is an Americanised, modernised revision of the King
// James Version, and its orthography is deliberately left alone. What this
// test freezes is the residue that was not orthography: 101 verses where the
// text departed from all three independent KJV witnesses with a *different*
// word, a different number, or a missing one. See
// `tools/repair_kjv_defects.py` and docs/DATA-INTEGRITY.md.
//
// The defects mattered because they were invisible. "Cushy" for the
// messenger Cushi renders perfectly eight times over; "the land of their
// enemies" for "the hand of their enemies" reads without a stumble. Only
// holding the text against an outside witness could find them, so only a
// test that names the readings can keep them from coming back.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Verse id → the reading verified against getbible.net, openbible.com's
  // Pure Cambridge Edition, and scrollmapper, all three agreeing.
  const verified = <String, String>{
    // "Three items in the year all thy males shall appear" — a word that
    // cannot be read, and the only one of these a reader could have caught.
    '002023017':
        'Three times in the year all thy males shall appear before the LORD '
        'God.',
    // "the son Uri" — a genealogy with the preposition gone.
    '002038022':
        'And Bezaleel the son of Uri, the son of Hur, of the tribe of Judah, '
        'made all that the LORD commanded Moses.',
    // The messenger Cushi, spelt as an English adjective at eight sites.
    '010018032':
        'And the king said unto Cushi, Is the young man Absalom safe? And '
        'Cushi answered, The enemies of my lord the king, and all that rise '
        'against thee to do thee hurt, be as that young man is.',
    // "left of the door of the poor of the land" — three words interpolated
    // out of nowhere.
    '012025012':
        'But the captain of the guard left of the poor of the land to be '
        'vinedressers and husbandmen.',
    // "the tribes of Levi" — Levi is one tribe. A number error in a fact.
    '006013014':
        'Only unto the tribe of Levi he gave none inheritance; the sacrifices '
        'of the LORD God of Israel made by fire are their inheritance, as he '
        'said unto them.',
    // "leftest thou them in the land of their enemies" — reads perfectly.
    '016009028':
        'But after they had rest, they did evil again before thee: therefore '
        'leftest thou them in the hand of their enemies, so that they had the '
        'dominion over them: yet when they returned, and cried unto thee, '
        'thou heardest them from heaven; and many times didst thou deliver '
        'them according to thy mercies;',
    // "So they look up Jonah".
    '032001015':
        'So they took up Jonah, and cast him forth into the sea: and the sea '
        'ceased from her raging.',
    // "he that c|alleth for the waters" — a conversion artifact inside a word.
    '030009006':
        'It is he that buildeth his stories in the heaven, and hath founded '
        'his troop in the earth; he that calleth for the waters of the sea, '
        'and poureth them out upon the face of the earth: The LORD is his '
        'name.',
    // The longest verse in the Bible, and the only one this file ever
    // truncated: it stopped at 499 characters, mid-clause.
    '017008009':
        "Then were the king's scribes called at that time in the third month, "
        'that is, the month Sivan, on the three and twentieth day thereof; '
        'and it was written according to all that Mordecai commanded unto the '
        'Jews, and to the lieutenants, and the deputies and rulers of the '
        'provinces which are from India unto Ethiopia, an hundred twenty and '
        'seven provinces, unto every province according to the writing '
        'thereof, and unto every people after their language, and to the Jews '
        'according to their writing, and according to their language.',
  };

  const englishAssets = <String>[
    'assets/kjv.json',
    'assets/kjvs.json',
    'assets/bsb.json',
  ];

  for (final asset in englishAssets) {
    group('$asset integrity', () {
      late List<Map<String, dynamic>> verses;

      setUpAll(() async {
        final raw = await rootBundle.loadString(asset);
        verses = (json.decode(raw) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      });

      test('carries no conversion pipe', () {
        final offenders = verses
            .where((v) => (v['text'] as String).contains('|'))
            .map((v) => v['id'])
            .toList();
        expect(offenders, isEmpty,
            reason: 'a "|" in Bible text is a leftover from conversion, and '
                'two of them landed inside words; offenders: $offenders');
      });

      test('no verse is padded with whitespace', () {
        final offenders = verses
            .where((v) => (v['text'] as String).trim() != v['text'])
            .map((v) => v['id'])
            .toList();
        expect(offenders, hasLength(0),
            reason: 'padding is invisible in the reader but sits inside the '
                'string the app searches, copies and counts; '
                '${offenders.length} offenders');
      });

      test('no verse prints a space before its punctuation', () {
        final spaced = RegExp(r'\s[,;:.!?)]');
        final offenders = verses
            .where((v) => spaced.hasMatch(v['text'] as String))
            .map((v) => v['id'])
            .toList();
        expect(offenders, hasLength(0),
            reason: 'reads as "and was sick : and he sent"; '
                '${offenders.length} offenders');
      });
    });
  }

  group('assets/kjv.json check-27 repairs', () {
    late Map<String, String> byId;

    setUpAll(() async {
      final raw = await rootBundle.loadString('assets/kjv.json');
      byId = {
        for (final v in (json.decode(raw) as List<dynamic>)
            .cast<Map<String, dynamic>>())
          v['id'] as String: v['text'] as String,
      };
    });

    test('has the canonical 31,102 verses', () {
      expect(byId, hasLength(31102));
    });

    test('the messenger Cushi is nowhere spelt Cushy', () {
      final offenders = byId.entries
          .where((e) => e.value.contains('Cushy'))
          .map((e) => e.key)
          .toList();
      expect(offenders, isEmpty, reason: 'offenders: $offenders');
    });

    for (final entry in verified.entries) {
      test('${entry.key} carries the witnessed reading', () {
        expect(byId[entry.key], entry.value);
      });
    }
  });

  // Repairing the plain text and not the tagged layer makes the same verse
  // look different in two panes — the loader renders runs, the search pane
  // reads plain text. The check-27 spacing repair had to be applied to both,
  // and this asserts it across all 66 books rather than 50 verses of John.
  test('every tagged kjvs run reassembles into its plain verse', () {
    final records =
        json.decode(File('assets/kjvs.json').readAsStringSync()) as List;
    final plain = <String, String>{};
    final bookNumbers = <String, String>{};
    for (final r in records.cast<Map<String, dynamic>>()) {
      plain[r['id'] as String] = r['text'] as String;
      bookNumbers.putIfAbsent(
          r['book'] as String, () => (r['id'] as String).substring(0, 3));
    }
    final slugs = {
      for (final e in bookNumbers.entries)
        e.key.toLowerCase().replaceAll(RegExp(r"[ ']"), ''): e.value,
    };

    var compared = 0;
    final offenders = <String>[];
    for (final file in Directory('assets/tagged/kjvs')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      final slug = file.uri.pathSegments.last
          .replaceAll('.json', '')
          .replaceAll(RegExp(r'[_-]'), '');
      final book = slugs[slug];
      expect(book, isNotNull, reason: 'no book number for ${file.path}');
      final verses = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      verses.forEach((ref, runs) {
        final parts = ref.split(':');
        final id = '$book${parts[0].padLeft(3, '0')}${parts[1].padLeft(3, '0')}';
        final joined = (runs as List)
            .map((r) => (r as Map<String, dynamic>)['w'] as String)
            .join();
        compared++;
        if (joined != plain[id]) offenders.add(id);
      });
    }

    expect(compared, 31102);
    expect(offenders, isEmpty,
        reason: '${offenders.length} verses disagree between the tagged layer '
            'and the plain text; first: ${offenders.take(5)}');
  });
}
