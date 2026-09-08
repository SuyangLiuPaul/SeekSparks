/// `assets/bsb-yhwh.json` and `assets/asv-yhwh.json`, with their tagged
/// sets — the two divine-name editions imported 2026-09-08 from the
/// 雅伟的话 project's own exported SQLite by
/// `tools/import_yahwehdehua_texts.py`.
///
/// Licence and the reasoning: `docs/permissions/README.md`. Both base
/// translations are public domain and in both the Yahweh reading is the
/// ministry's own editorial work, so neither needs a document on file —
/// but both credit that work, and neither may be copied out without a
/// limit.
///
/// A third text was looked at in the same pass and NOT imported: the
/// database's `hcsbs`, "CSB (Yahweh)". The last group in this file is
/// what makes that finding a check rather than a claim in a comment.
///
/// The source database is not in this repository — it is 174 MB and it
/// belongs to the other project — so the assertions that need it are
/// guarded on its presence. Everything else holds on a clean checkout.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/book_name_mapping.dart';
import 'package:seeksparks/constants/section_title_map.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/version_attribution.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show translateBookName;
import 'package:seeksparks/services/tagged_text_service.dart';

/// The exported SQLite these two editions were built from. Absent on a
/// clean machine, which is why nothing here fails when it is missing —
/// but when it IS there, the counts below are checked against the
/// source rather than against the last time somebody ran the importer.
const _sourceDb =
    'Yahwehdehua/app/build/bible.db';

String? _dbPath() {
  final home = Platform.environment['HOME'];
  if (home == null) return null;
  final p = '$home/Documents/CodingProject/$_sourceDb';
  return File(p).existsSync() ? p : null;
}

/// One column of one query, or null when `sqlite3` is not on the path.
List<String>? _query(String db, String sql) {
  final r = Process.runSync('sqlite3', [db, sql]);
  if (r.exitCode != 0) return null;
  return (r.stdout as String)
      .split('\n')
      .where((l) => l.isNotEmpty)
      .toList();
}

/// The 16 Received-Text verses the critical text does not carry. Both
/// modules store them empty and the importer omits them, which is what
/// `assets/bsb.json` has always done with the same sixteen.
const _receivedTextOnly = <String>[
  '040017021', '040018011', '040023014', // Matt 17:21, 18:11, 23:14
  '041007016', '041009044', '041009046', // Mark 7:16, 9:44, 9:46
  '041011026', '041015028', //             Mark 11:26, 15:28
  '042017036', '042023017', //             Luke 17:36, 23:17
  '043005004', //                          John 5:4
  '044008037', '044015034', '044024007', // Acts 8:37, 15:34, 24:7
  '044028029', //                          Acts 28:29
  '045016024', //                          Rom 16:24
];

final _noteRe = RegExp(r'<note: [^>]*>');

/// A verse with its translator's footnotes taken out.
///
/// Counting the divine name without this overstates it by 14 in
/// `bsb-yhwh`: the module's own footnotes say things like "Yahweh in
/// Hebrew", and a population count that includes the apparatus is
/// counting the editor rather than the text.
String _body(String text) => text.replaceAll(_noteRe, '');

void main() {
  late Map<String, List<Map<String, dynamic>>> editions;
  late List<Map<String, dynamic>> kjv;
  late List<Map<String, dynamic>> bsb;

  List<Map<String, dynamic>> load(String p) =>
      (json.decode(File(p).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  setUpAll(() {
    editions = {
      'bsb-yhwh': load('assets/bsb-yhwh.json'),
      'asv-yhwh': load('assets/asv-yhwh.json'),
    };
    kjv = load('assets/kjv.json');
    bsb = load('assets/bsb.json');
  });

  Map<String, String> byId(String code) =>
      {for (final r in editions[code]!) r['id'] as String: r['text'] as String};

  Map<String, dynamic> taggedBook(String code, String book) => json.decode(
      File('assets/tagged/$code/${book.toLowerCase().replaceAll(' ', '_')}'
              '.json')
          .readAsStringSync()) as Map<String, dynamic>;

  group('each edition is a whole Bible, versified like the ones already here',
      () {
    for (final code in const ['bsb-yhwh', 'asv-yhwh']) {
      test('$code carries all 66 books and every reference the BSB carries',
          () {
        final rows = editions[code]!;
        expect(rows, hasLength(31086));
        expect(rows.map((r) => r['book']).toSet(), hasLength(66));

        // Against `assets/bsb.json` rather than a typed-in list: the
        // importer maps book names by canonical POSITION out of
        // `kjv.json`, so two canons ordered alike but versified
        // differently would file every verse after the disagreement
        // under the wrong reference while the count still looked right.
        expect(rows.map((r) => r['id']).toList(),
            bsb.map((r) => r['id']).toList());
        expect(rows.map((r) => r['book']).toList(),
            bsb.map((r) => r['book']).toList());
      });

      test('$code omits exactly the sixteen verses the critical text drops',
          () {
        // Not "omits sixteen verses" — WHICH sixteen. A count would be
        // satisfied by losing sixteen verses of Isaiah.
        final ids = byId(code).keys.toSet();
        final absent = kjv
            .map((r) => r['id'] as String)
            .where((id) => !ids.contains(id))
            .toList();
        expect(absent, _receivedTextOnly);
      });

      test('$code has no verse that lost its text on the way in', () {
        // The importer drops empty rows rather than writing empty
        // strings, so an empty one here means a verse was emptied by
        // the markup pass, not by the source.
        final blank =
            editions[code]!.where((r) => (r['text'] as String).trim().isEmpty);
        expect(blank, isEmpty);
      });
    }
  });

  group('the counts answer to the source database, not to the last import',
      () {
    // These are the assertions the task asked for by name, and they are
    // the only ones here that can go stale silently: every other check
    // reads two files that ship together. Skipped rather than faked
    // when the other project is not checked out beside this one.
    final db = _dbPath();

    for (final entry
        in const {'bsb-yhwh': 'bsbys', 'asv-yhwh': 'asvs'}.entries) {
      test('${entry.key} holds every verse of ${entry.value} that has text',
          () {
        final rows = _query(db!,
            "select count(*) from verses where version='${entry.value}';");
        final empty = _query(db,
            "select count(*) from verses where version='${entry.value}' "
            "and trim(text)='';");
        expect(rows, isNotNull, reason: 'sqlite3 is not on the path');
        expect(int.parse(rows!.single), 31102);
        expect(int.parse(empty!.single), 16);
        expect(editions[entry.key], hasLength(31102 - 16));
      },
          skip: db == null
              ? 'the 雅伟的话 export is not checked out beside this repo'
              : null);

      test('${entry.key} agrees with ${entry.value} book by book, not just in '
          'total', () {
        // A total can be right while two books have swapped verses
        // between them, which is precisely the failure the positional
        // book map could produce.
        final rows = _query(db!,
            'select b.name_en, count(*) from verses v join books b '
            "on b.code = v.book where v.version='${entry.value}' "
            "and trim(v.text) <> '' group by b.seq order by b.seq;");
        expect(rows, isNotNull);
        final source = <String, int>{
          for (final line in rows!)
            line.split('|')[0]: int.parse(line.split('|')[1]),
        };
        final mine = <String, int>{};
        for (final r in editions[entry.key]!) {
          mine[r['book'] as String] = (mine[r['book'] as String] ?? 0) + 1;
        }
        expect(mine, source);
      },
          skip: db == null
              ? 'the 雅伟的话 export is not checked out beside this repo'
              : null);
    }
  });

  group('the divine name reads the way each edition claims it does', () {
    test('BSB-Y prints Yahweh where the plain BSB prints the small-caps LORD',
        () {
      final y = byId('bsb-yhwh');
      final plain = {for (final r in bsb) r['id'] as String: r['text'] as String};
      // Deuteronomy 6:4, the Shema, and Exodus 6:3, where the name is
      // the subject of the sentence rather than a title in it.
      expect(y['005006004'], 'Hear, O Israel: Yahweh our God, Yahweh is One.');
      expect(plain['005006004'], contains('The LORD our God'));
      expect(y['002006003'], contains('by My name Yahweh I did not make'));
      expect(plain['002006003'], contains('by My name the LORD'));
    });

    test('BSB-Y keeps Adonai and YHWH apart where the plain BSB writes '
        '"Lord GOD"', () {
      // 299 verses. This is one of the two things the app's own
      // render-time LORD→Yahweh rewrite cannot do, because it does not
      // touch `GOD` — so without this edition the distinction is not
      // available to an English reader at all.
      final y = byId('bsb-yhwh');
      final plain = {for (final r in bsb) r['id'] as String: r['text'] as String};
      expect(y['001015002'], contains('“O Lord Yahweh, what can You give me'));
      expect(plain['001015002'], contains('“O Lord GOD, what can You give me'));
      expect(y['010007018'], contains('Lord Yahweh')); // 2 Samuel 7:18
    });

    test('BSB-Y prints the short form Yah rather than flattening it to the '
        'name', () {
      // 27 verses, and the app's rewrite would have produced "Yahweh"
      // in all of them from the plain BSB's "the LORD". Exodus 15:2
      // opens the Song of the Sea; Psalm 68:4 is the verse the form is
      // usually quoted from.
      final y = byId('bsb-yhwh');
      expect(y['002015002'], startsWith('Yah is my strength and my song'));
      expect(y['019068004'], contains('His name is Yah'));
    });

    test('BSB-Y is the only edition here that says anything about the name in '
        'the New Testament', () {
      // `Lord [Yahweh]` — and the bracket is not a new convention
      // invented for this import. `bracketSpanKind` already types that
      // exact token as `ScriptureSpanKind.divineName`, which is how
      // 和合本雅伟版 writes 主[雅伟]: "the Lord printed here is Yahweh".
      final y = byId('bsb-yhwh');
      expect(y['040001020'], contains('an angel of the Lord [Yahweh]'));
      expect(y['046001031'], contains('boast in the Lord [Yahweh]'));
      final glossed =
          y.values.where((t) => _body(t).contains('[Yahweh]')).length;
      expect(glossed, 187);
      expect(y.values.where((t) => _body(t).contains('Lord*')).length, 109,
          reason: 'the asterisk is the edition\'s own softer marker, used '
              'where it flags a κύριος rather than restoring it');
    });

    test('ASV-Y respells the name the 1901 translators had already printed',
        () {
      // The ASV is the one major English Bible that printed the divine
      // name outright, as Jehovah. So this edition is not restoring
      // anything — it is respelling — and that is a smaller claim,
      // which `aboutLicenseAsvYhwh` makes in different words from
      // BSB-Y's line for exactly this reason.
      final y = byId('asv-yhwh');
      expect(y['005006004'], 'Hear, O Israel: Yahweh our God is one Yahweh:');
      expect(y['002006003'], contains('by my name Yahweh I was not known'));
      final withName =
          y.values.where((t) => _body(t).contains('Yahweh')).length;
      expect(withName, 5787);
    });

    test('ASV-Y leaves the four all-caps JEHOVAH inscriptions exactly as '
        'found', () {
      // "HOLY TO JEHOVAH" is engraved on the high priest's medallion and
      // on the bells of the horses; the source rewrote the mixed-case
      // form and left the small-caps one alone. So does the importer —
      // tidying a text on the way in is how an edition stops being the
      // edition it says it is.
      final y = byId('asv-yhwh');
      final caps = y.entries
          .where((e) => e.value.contains('JEHOVAH'))
          .map((e) => e.key)
          .toList()
        ..sort();
      expect(caps, <String>[
        '002028036', // Exodus 28:36
        '002039030', // Exodus 39:30
        '005028058', // Deuteronomy 28:58
        '038014020', // Zechariah 14:20
      ]);
      expect(y['002028036'], endsWith('HOLY TO JEHOVAH.'));
    });

    test('the two editions do not agree with each other, which is the point '
        'of shipping both', () {
      final b = byId('bsb-yhwh'), a = byId('asv-yhwh');
      var same = 0;
      for (final id in b.keys) {
        if (b[id] == a[id]) same++;
      }
      // 113 of 31,086 — 0.4%, and every one of them is a verse too
      // short to translate two ways: Genesis 1:1, "So the people rested
      // on the seventh day", the tally of kings in Joshua 12. Written
      // as a proportion rather than as 113 exactly, because the number
      // that means anything here is "almost none" and pinning the exact
      // figure would make a one-verse punctuation change look like a
      // finding.
      expect(same / b.length, lessThan(0.01),
          reason: 'BSB 2020 and ASV 1901 are different translations; if they '
              'read alike, one of the two imports read the wrong table '
              '(identical in $same of ${b.length})');
    });
  });

  group('the source markup became this app\'s markup, and nothing else', () {
    for (final code in const ['bsb-yhwh', 'asv-yhwh']) {
      test('$code carries no tag the source wrote and this app cannot read',
          () {
        // `<WH1254>`, `<CL>`, `<i>`, `<cite>`, `<fnote>` and friends.
        // The only angle bracket that may survive is `<note: …>`, which
        // is this app's own.
        for (final r in editions[code]!) {
          final leftover = _body(r['text'] as String);
          expect(leftover, isNot(contains('<')),
              reason: '${r['id']} still has source markup in it');
        }
      });
    }

    test('BSB-Y footnotes became markers the reader can open, not text', () {
      // The source's `plain` column concatenates the footnote BODY into
      // the running text — Psalm 104:35 reads "HallelujahHallelujah
      // (H1984+H3050) is literally…" there — which is why the importer
      // does not use that column. This is the same verse from the other
      // side.
      final y = byId('bsb-yhwh');
      expect(y['019104035'], contains('Bless Yahweh, O my soul. Hallelujah'));
      expect(y['019104035'],
          contains('<note: Hallelujah (H1984+H3050) is literally'));
      expect(_body(y['019104035']!), endsWith('Hallelujah!'));
      expect(y.values.where((t) => t.contains('<note: ')).length, 224);
    });

    test('ASV-Y italics became supplied words, bracketed the way LEB and BSB '
        'bracket theirs', () {
      // In a 1901 Bible italics mean text with no counterpart in the
      // Hebrew or Greek. `scripture_markup.dart` renders `[…]` set
      // apart rather than deleting it, which is what a printed Bible
      // has done with these words for centuries.
      final y = byId('asv-yhwh');
      expect(y['001001011'], contains('yielding seed, [and] fruit-trees'));
      expect(y.values.where((t) => t.contains('[')).length, 3655);
    });

    test('ASV-Y keeps the Psalm superscriptions as text rather than calling '
        'them a footnote', () {
      // The source wraps them in `<cite>`. They are canonical Hebrew —
      // the ASV translated them — so typing them as a translator's
      // remark or as a supplied word would each state the opposite of
      // what they are.
      expect(byId('asv-yhwh')['019003001'],
          startsWith('A Psalm of David, when he fled from Absalom his son.'));
    });

    test('ASV-Y drops the one orphaned bracket the source left behind', () {
      // The ASV brackets John 7:53-8:11 as doubtful and the module kept
      // the closing `]]` while losing the opening `[[` five verses
      // earlier. Left in, it prints as two literal brackets.
      expect(byId('asv-yhwh')['043008011'], endsWith('sin no more.'));
    });
  });

  group('the tagged layer', () {
    for (final code in const ['bsb-yhwh', 'asv-yhwh']) {
      test('$code tags every book, and the app and the build both know it',
          () {
        expect(Directory('assets/tagged/$code').listSync(), hasLength(66));
        expect(TaggedTextService.supports(code), isTrue);
        expect(File('pubspec.yaml').readAsStringSync(),
            contains('assets/tagged/$code/'),
            reason: 'an undeclared directory is tagging that 404s at runtime');
      });

      test('$code\'s runs ARE the verse, book for book', () {
        // The invariant the importer is arranged around: whitespace is
        // normalised per run and never on the joined string, so the
        // plain asset and the tagged asset are two views of one thing.
        // If this fails, a reader hovering a word is being shown text
        // the page is not printing.
        final text = byId(code);
        final order = <String>[];
        for (final r in editions[code]!) {
          if (!order.contains(r['book'])) order.add(r['book'] as String);
        }
        var checked = 0;
        for (var i = 0; i < order.length; i++) {
          final book = taggedBook(code, order[i]);
          book.forEach((ref, runs) {
            final parts = ref.split(':');
            final id = '${(i + 1).toString().padLeft(3, '0')}'
                '${parts[0].padLeft(3, '0')}${parts[1].padLeft(3, '0')}';
            final joined = (runs as List)
                .map((r) => (r as Map<String, dynamic>)['w'] as String)
                .join();
            expect(joined, text[id], reason: '$code $id');
            checked++;
          });
        }
        expect(checked, greaterThan(30000));
      });

      test('$code numbers nothing outside Strong\'s own range', () {
        // The CSB module this app also ships is full of H9900-H9999
        // placeholders for English words that render a Hebrew particle,
        // and `import_csb.py` drops them. Neither of these two writes a
        // single one, which is a property of the SOURCE — pinned so a
        // re-import that starts emitting them has to be looked at
        // rather than shipped.
        final valid = RegExp(r'^[HG]\d+$');
        var seen = 0;
        for (final book in ['Genesis', 'Psalms', 'Matthew', 'Revelation']) {
          (taggedBook(code, book)).forEach((_, runs) {
            for (final r in (runs as List).cast<Map<String, dynamic>>()) {
              for (final n in [
                if ((r['s'] as String).isNotEmpty) r['s'] as String,
                ...((r['i'] as List?) ?? const []).cast<String>(),
              ]) {
                expect(valid.hasMatch(n), isTrue, reason: n);
                final v = int.parse(n.substring(1));
                expect(v, lessThanOrEqualTo(n[0] == 'H' ? 8674 : 5624),
                    reason: '$n is above the Strong\'s ceiling');
                seen++;
              }
            }
          });
        }
        expect(seen, greaterThan(50000));
      });
    }

    test('the eighteen verses with no tagged record are named, not counted',
        () {
      // A verse gets no tagged record when its source row carries no
      // Strong's tag at all. Eighteen do, and they are frozen by name so
      // that a re-import which loses tagging somewhere ELSE cannot be
      // cancelled out by one of these gaining it — the same reason
      // `tagged_layer_coverage_test.dart` freezes `_lxxwhUntagged` by
      // name rather than by count.
      //
      // Psalm 91:7-16 is ten consecutive verses, which is what an
      // untagged BLOCK looks like rather than a scattering, and the
      // BSB's Exodus 38:28 and Judges 16:14 are the same two verses
      // `_bsbDepartures` already names in the plain `bsb` layer — two
      // separate imports of two separate modules disagreeing with their
      // own tagging in the same places.
      final untagged = <String>{};
      for (final code in const ['bsb-yhwh', 'asv-yhwh']) {
        final order = <String>[];
        for (final r in editions[code]!) {
          if (!order.contains(r['book'])) order.add(r['book'] as String);
        }
        final books = {for (final b in order) b: taggedBook(code, b)};
        for (final r in editions[code]!) {
          final ref = '${r['chapter']}:${r['verse']}';
          if (!books[r['book']]!.containsKey(ref)) {
            untagged.add('$code ${r['book']} $ref');
          }
        }
      }
      expect(untagged, <String>{
        'bsb-yhwh Exodus 38:28',
        'bsb-yhwh Judges 16:14',
        'bsb-yhwh Nehemiah 7:68',
        'asv-yhwh Numbers 3:39',
        'asv-yhwh 1 Chronicles 18:5',
        'asv-yhwh 2 Chronicles 22:1',
        'asv-yhwh Psalms 91:7',
        'asv-yhwh Psalms 91:8',
        'asv-yhwh Psalms 91:9',
        'asv-yhwh Psalms 91:10',
        'asv-yhwh Psalms 91:11',
        'asv-yhwh Psalms 91:12',
        'asv-yhwh Psalms 91:13',
        'asv-yhwh Psalms 91:14',
        'asv-yhwh Psalms 91:15',
        'asv-yhwh Psalms 91:16',
        'asv-yhwh Luke 18:19',
        'asv-yhwh Romans 8:34',
      });
    });

    test('BSB-Y puts the source\'s x-suffixed numbers where they belong', () {
      // `eat<WH398><WH4480x>` — H4480 is מִן, "from", which is in the
      // Hebrew and has no English word of its own here. It is an
      // IMPLIED number, and reading it as the run's own would attach a
      // preposition's lemma to the verb before it. Genesis 1:1 is the
      // shortest witness: "God" carries H430 and implies H853, the
      // direct-object marker.
      final gen = taggedBook('bsb-yhwh', 'Genesis')['1:1'] as List;
      final god = gen.cast<Map<String, dynamic>>()
          .firstWhere((r) => (r['w'] as String).trim() == 'God');
      expect(god['s'], 'H430');
      expect((god['i'] as List).cast<String>(), <String>['H853']);
    });

    test('ASV-Y carries no implied numbers at all, because its source writes '
        'none', () {
      // The two sources differ here and the difference is real: the ASV
      // module has no `x` suffix anywhere. An `i` list appearing in it
      // would mean the importer had invented one.
      var withImplied = 0;
      for (final book in ['Genesis', 'Psalms', 'Matthew']) {
        (taggedBook('asv-yhwh', book)).forEach((_, runs) {
          for (final r in (runs as List).cast<Map<String, dynamic>>()) {
            if (((r['i'] as List?) ?? const []).isNotEmpty) withImplied++;
          }
        });
      }
      expect(withImplied, 0);
    });

    test('the runs-are-the-verse check would actually notice if they were '
        'not', () {
      // Mutation test. Every assertion above is only worth what it
      // catches, and "the runs join back to the text" is the one that
      // would quietly pass if it were comparing a string to itself —
      // which is exactly what an earlier draft did, by rebuilding the
      // expected text from the same runs it was checking.
      //
      // So: take a real verse, break its runs three ways, and require
      // the comparison to fail on each. A check that survives this is
      // reading the plain asset, not the tagged one.
      final text = byId('bsb-yhwh')['001001001']!;
      final runs = (taggedBook('bsb-yhwh', 'Genesis')['1:1'] as List)
          .cast<Map<String, dynamic>>();
      String join(List<Map<String, dynamic>> rs) =>
          rs.map((r) => r['w'] as String).join();

      expect(join(runs), text, reason: 'the control: unmutated, it passes');

      // A dropped run — the failure a re-import is most likely to
      // produce, because it is what an over-eager whitespace pass does.
      final dropped = [...runs]..removeAt(2);
      expect(join(dropped), isNot(text));

      // Two runs swapped: same characters, same count, wrong sentence.
      final swapped = [...runs];
      final t = swapped[0];
      swapped[0] = swapped[1];
      swapped[1] = t;
      expect(join(swapped), isNot(text));

      // One character changed inside a run — the smallest possible
      // divergence, and the one a length or count check cannot see.
      final edited = [
        for (final r in runs)
          {...r, 'w': (r['w'] as String).replaceFirst('God', 'god')}
      ];
      expect(join(edited), isNot(text));
    });
  });

  group('both editions are wired into everything that keys off the catalog',
      () {
    for (final entry in const {
      'bsb-yhwh': 'BSB-Y',
      'asv-yhwh': 'ASV-Y',
    }.entries) {
      final code = entry.key, label = entry.value;

      test('$code is registered, offered, English and coloured', () {
        final info = bibleVersions.where((v) => v.value == code).toList();
        expect(info, hasLength(1));
        expect(info.single.language, 'en');
        expect(info.single.shortLabel, label);
        expect(info.single.menuLabel, isNotEmpty);
        expect(info.single.editionYear, isNotEmpty);
        expect(disabledVersions.contains(code), isFalse);
        expect(isKnownVersion(code), isTrue);
        expect(kVersionTagColors.containsKey(code), isTrue,
            reason: 'without a colour it falls through to the HSL hash');
        expect(File('pubspec.yaml').readAsStringSync(),
            contains('assets/$code.json'),
            reason: 'an undeclared asset is a version that 404s at runtime');
      });

      test('$code\'s book names are read as English', () {
        // The trap `book_name_mapping.dart` records at length: bsb,
        // kjvs and lxxwh entered the catalog without joining
        // `_englishVersionCodes`, the reading pane filtered an English
        // corpus by a Chinese book name, and the pane rendered BLANK on
        // production with no error at all.
        expect(bookScriptFor('zh-Hans', code), BookScript.english);
        expect(translateBookName('Genesis', code), 'Genesis');
      });

      test('$code renders section headings like the other English editions',
          () {
        // Nothing else tests this map, so an omission is silent: the
        // edition simply shows no headings and nobody is told why.
        expect(sectionTitleSetByVersion[code], 'english-classic');
      });

      test('$code can be taken offline, like every edition a reader can pick',
          () {
        expect(File('lib/services/offline_pack_service.dart').readAsStringSync(),
            contains("'assets/$code.json'"),
            reason: 'a visible edition the pack does not fetch is an edition '
                'that will not open once the reader is offline');
      });

      test('copying $code out carries its own licence line and is capped', () {
        // Two different lines, deliberately. The BSB is public domain
        // by its publisher's dedication and the ASV by age, and in both
        // the divine-name reading is the ministry's editorial work —
        // which travels on the clipboard, unlike Eagle's View's Strong's
        // alignment, and is why neither is in `unrestrictedCopyVersions`.
        final key = attributionKeyFor(code);
        expect(key, isNotNull);
        expect(unrestrictedCopyVersions.contains(code), isFalse);
        expect(copyIsRestricted([code]), isTrue);
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          final line = uiStrings[key]?[locale];
          expect(line, isNotNull, reason: '$key has no $locale');
          // The ministry is credited in every locale — spelt out in
          // English, and as 雅伟的话 / 雅偉的話 in the two Chinese ones.
          expect(line, anyOf(contains('Yahweh De Hua'), contains('雅')));
        }
      });
    }

    test('the two licence lines are not the same sentence', () {
      // A shared "public domain" line would say neither true thing:
      // that the BSB was dedicated and the ASV merely aged out, and
      // that one edition restores a name while the other respells one.
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(uiStrings['aboutLicenseBsbYhwh']?[locale],
            isNot(uiStrings['aboutLicenseAsvYhwh']?[locale]));
      }
    });

    test('the About screen names both by the badge the gutter prints', () {
      // An attribution a reader cannot match to the text it covers is
      // doing half its job — the rule `version_label_scheme_test.dart`
      // already holds the older rows to.
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(uiStrings['aboutVerBsbYhwh']?[locale], startsWith('BSB-Y'));
        expect(uiStrings['aboutVerAsvYhwh']?[locale], startsWith('ASV-Y'));
      }
      final about = File('lib/pages/about_page.dart').readAsStringSync();
      expect(about, contains('aboutVerBsbYhwh'));
      expect(about, contains('aboutVerAsvYhwh'));
    });
  });

  group('the CSB that was NOT imported', () {
    test('there is exactly one CSB in the catalog, and it is the licensed '
        'one', () {
      // `docs/permissions/README.md` records why the database's
      // "CSB (Yahweh)" is not a second row: it is the same module
      // `assets/csb.json` was built from, one repair pass behind.
      // Shipping both would present ONE licensed text as two editions,
      // and the second would be the one that spells the divine name two
      // ways.
      final csbRows =
          bibleVersions.where((v) => v.value.startsWith('csb')).toList();
      expect(csbRows.map((v) => v.value), <String>['csb']);
      expect(Directory('assets').listSync().map((e) => e.path),
          isNot(contains('assets/csb-yhwh.json')));
    });

    test('the CSB credit line Holman requires is still there, word for word',
        () {
      // Unchanged by this import, and asserted here rather than assumed
      // because this change edited the same About table the line lives
      // in. Quoted in full: a paraphrase is a breach of the grant, and
      // a test that checked a fragment would not notice one.
      const credit =
          'Scripture quotations marked CSB®, are taken from the '
          'Christian Standard Bible®, Copyright © 2017 by Holman '
          'Bible Publishers. Used by permission. Christian Standard '
          'Bible®, and CSB® are federally registered trademarks '
          'of Holman Bible Publishers.';
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(uiStrings['aboutLicenseCsb']?[locale], credit,
            reason: 'the grant names this sentence and requires it verbatim '
                'in every locale');
      }
      expect(attributionKeyFor('csb'), 'aboutLicenseCsb');
    });

    test('the database still holds no CSB reading the bundled CSB lacks', () {
      // The finding, recomputed rather than quoted. If this ever
      // stops being true — if the other project restores the name
      // somewhere this app does not — then "hcsbs is the same edition"
      // has become false and the decision in
      // `docs/permissions/README.md` has to be taken again.
      final db = _dbPath()!;
      final rows = _query(db,
          "select b.seq, v.chapter, v.verse, v.plain from verses v "
          "join books b on b.code = v.book where v.version='hcsbs' "
          "and v.plain like '%Yahweh%';");
      expect(rows, isNotNull, reason: 'sqlite3 is not on the path');
      final csb = {
        for (final r in load('assets/csb.json'))
          r['id'] as String: r['text'] as String
      };
      var dbReadsMore = 0;
      for (final line in rows!) {
        final f = line.split('|');
        final id = '${f[0].padLeft(3, '0')}${f[1].padLeft(3, '0')}'
            '${f[2].padLeft(3, '0')}';
        final here = csb[id];
        if (here == null) continue;
        final inDb = 'Yahweh'.allMatches(f.sublist(3).join('|')).length;
        final inApp = 'Yahweh'.allMatches(here).length;
        if (inDb > inApp) dbReadsMore++;
      }
      expect(dbReadsMore, 0,
          reason: 'the export now reads Yahweh somewhere assets/csb.json does '
              'not — re-run tools/import_yahwehdehua_texts.py --audit-csb and '
              'adjudicate before trusting docs/permissions/README.md');
    },
        skip: _dbPath() == null
            ? 'the 雅伟的话 export is not checked out beside this repo'
            : null);
  });
}
