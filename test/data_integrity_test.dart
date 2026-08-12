// Standing data-integrity guards over the shipped corpus (task #304).
//
// The premise, in the user's words: "accuracy is the most critical and
// important thing". The rest of the suite proves the code RUNS. These
// tests prove the DATA is internally consistent, which is a different
// claim and the one a reader of an exegesis tool is actually relying on.
//
// Each of these was written after `tools/audit_data_integrity.py` found
// a real disagreement, or found zero and the zero was worth freezing.
// The audit script is the wide sweep; this file is the subset cheap
// enough to run on every commit.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/book_names.dart';
import 'package:seeksparks/services/versification.dart';
import 'package:seeksparks/utils/morphology.dart';
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/verse_list.dart' show applySearchLimit;
import 'package:seeksparks/utils/verse_text_absence.dart';

/// Editions bundled in `pubspec.yaml` as flat verse lists. The two
/// Eagle's View NASB derivatives are deliberately absent: they are
/// licensed and must never ship.
const _versions = <String>[
  'kjv',
  'kjvs',
  'bsb',
  'leb',
  'nasb',
  'lxxwh',
  'cuvs-yhwh',
  'cuvs-yhwh-tr',
  'cuvs-plus',
  'biblexg-v2',
  'biblexg-v2-tr',
];

final _bookField = RegExp(r'"book":\s*"([^"]+)"');

/// Verses numbered past the end of a KJV chapter that are a real
/// versification decision rather than a defect, each checked by hand:
/// modern editions split 3 John 14 into 14-15 and restore Revelation
/// 12:18.
///
/// 使徒行傳 8:41 was here too, on the belief that the edition split 8:40
/// the way it splits others "遵从最新希腊文新约底本 NA28、UBS5". It did
/// not. No versification tradition gives Acts 8 more than forty verses,
/// the whole chapter carries no NA28 note, and the row numbered 40
/// stopped mid-clause at 「腓利卻出現在亞鎖城，」 with the rest of the
/// verse under 41 — a converter's off-by-one, repaired in v1.6.118 by
/// `tools/repair_verse_numbering.py`. That is exactly the reason this
/// set is written by hand and kept short: a reference the canon does
/// not have is compared against nothing, so a defect can sit in it
/// wearing a plausible explanation.
const _knownBeyondCanon = <String>{
  '3 John 1:15',
  'Revelation 12:18',
};

/// Code points that must not appear in scripture because they render as
/// nothing: C0/C1 controls and the invisible formatting characters. A
/// verse carrying one looks correct and fails an exact-phrase search
/// that should match it, which is the hardest defect class to notice.
bool _isInvisible(int cp) =>
    (cp < 0x09) ||
    (cp > 0x0A && cp < 0x20) ||
    (cp >= 0x7F && cp <= 0xA0) ||
    cp == 0xAD ||
    (cp >= 0x200B && cp <= 0x200F) ||
    (cp >= 0x202A && cp <= 0x202E) ||
    (cp >= 0x2060 && cp <= 0x2064) ||
    cp == 0xFEFF ||
    (cp >= 0xE000 && cp <= 0xF8FF) ||
    cp == 0xFFFD;

/// Unicode blocks that cannot occur in a correctly encoded Chinese Bible.
/// Each one is a defect class #304 actually found, not a hypothesis.
const _suspectBlocks = <List<int>>[
  [0x00A1, 0x00FF], // GBK bytes decoded as Latin-1 — whole-verse mojibake
  [0x2500, 0x257F], // Box Drawing
  [0x25A0, 0x25FF], // Geometric Shapes — the stray □ inside 神
  [0x3100, 0x312F], // Bopomofo — ㄤ standing in for 现
  [0x3400, 0x4DBF], // CJK Extension A — 䍁 standing in for 繸
  [0x20000, 0x2FFFF], // CJK Extension B — 𨱔 standing in for 鐏
];

/// The two characters from those blocks the editions genuinely print:
/// 和合本 sets its long dash with U+2500 and 圣经新译本 separates
/// transliterated names with U+00B7 (本丢·彼拉多).
const _repertoireExceptions = <int>{0x2500, 0x00B7};

const _chineseVersions = <String>[
  'cuvs-yhwh',
  'cuvs-yhwh-tr',
  'cuvs-plus',
  'biblexg-v2',
  'biblexg-v2-tr',
];

final _mergeMarker = RegExp(
    r'^(?:<note:\s*)?[〔\[（(]?\s*(?:见上节|見上節|见下节|見下節)\s*[〕\]）)]?>?$');

List<Map<dynamic, dynamic>> _edition(String code) =>
    (jsonDecode(File('assets/$code.json').readAsStringSync()) as List)
        .cast<Map<dynamic, dynamic>>();

String _ref(Map<dynamic, dynamic> v) =>
    '${bookNameToEnglish[v['book']] ?? v['book']} '
    '${v['chapter']}:${v['verse']}';

void main() {
  test('no edition numbers a verse past the end of its chapter', () {
    // 2026-08-10 (#304): assets/cuvs-plus.json filed 1 Chronicles 22:1
    // as 21:31 and shifted the rest of the chapter down, so chapter 21
    // held 31 verses and 22 held 18. The tagged layer carried the same
    // shift, but assets/originals (the Hebrew corpus) is canonical —
    // so a 和简+ reader's Word Study pane showed the Hebrew of the NEXT
    // verse for all of 1 Chronicles 22. Nothing threw and no count
    // looked odd; the chapter simply read one verse out of step with
    // every commentary and cross-reference pointing into it.
    final chapterLength = <String, int>{};
    for (final v in jsonDecode(File('assets/kjv.json').readAsStringSync())
        as List) {
      final m = v as Map;
      final key = '${m['book']} ${m['chapter']}';
      final n = int.parse(m['verse'] as String);
      if (n > (chapterLength[key] ?? 0)) chapterLength[key] = n;
    }

    final failures = <String>[];
    for (final code in _versions) {
      for (final v
          in jsonDecode(File('assets/$code.json').readAsStringSync()) as List) {
        final m = v as Map;
        final en = bookNameToEnglish[m['book']];
        if (en == null) continue; // reported by the book-name test
        final n = int.tryParse(m['verse'].toString());
        final max = chapterLength['$en ${m['chapter']}'];
        if (n == null || max == null || n <= max) continue;
        final ref = '$en ${m['chapter']}:$n';
        if (!_knownBeyondCanon.contains(ref)) failures.add('$code: $ref');
      }
    }
    expect(failures, isEmpty, reason: failures.take(20).join('\n'));
  });

  test('every edition files its verses under a resolvable book name', () {
    // 2026-08-10 (#304): `assets/leb.json` labelled Micah "Mic" and
    // Nahum "Nah", and `assets/cuvs-yhwh-tr.json` labelled 2 Timothy
    // 提摩太后書 — simplified 后 in an otherwise traditional name. None
    // of the three is a key in [bookNameToEnglish], and `Verse.id` is
    // `bookNameToEnglish[book] ?? book`, so a highlight made on LEB
    // Micah was keyed `Mic-1-1` and never matched the same verse under
    // any other edition — exactly the cross-version persistence the id
    // exists to provide. Nothing threw; the books simply fell out of
    // every name-keyed lookup in the app.
    final failures = <String>[];
    for (final code in _versions) {
      final file = File('assets/$code.json');
      expect(file.existsSync(), isTrue, reason: 'assets/$code.json missing');
      final names = <String>{};
      for (final m in _bookField.allMatches(file.readAsStringSync())) {
        names.add(m.group(1)!);
      }
      expect(names, isNotEmpty, reason: '$code has no book names');
      for (final name in names) {
        final en = bookNameToEnglish[name];
        if (en == null) {
          failures.add('$code: "$name" is not in bookNameToEnglish');
        } else if (!standardBookOrder.contains(en)) {
          failures.add('$code: "$name" maps to "$en", not a canonical book');
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('every edition carries every book of the canon it covers', () {
    // 2026-08-10: `assets/leb.json` shipped from the initial commit with
    // Judges and Obadiah ABSENT — 64 books, 30,552 verses. Nothing threw:
    // the book list is built from the verses present, so the two books
    // simply were not offered, and a reader comparing Judges 5 across
    // editions saw LEB silently drop out of the comparison. Repaired in
    // v1.6.91 from an independently authorized copy of the same edition.
    final failures = <String>[];
    for (final code in _versions) {
      final present = <String>{};
      for (final m in _bookField
          .allMatches(File('assets/$code.json').readAsStringSync())) {
        final en = bookNameToEnglish[m.group(1)!];
        if (en != null) present.add(en);
      }
      // The two 圣经新译本 editions are New Testament only by design.
      final expected = present.contains('Genesis')
          ? standardBookOrder
          : standardBookOrder.sublist(standardBookOrder.indexOf('Matthew'));
      final missing = expected.where((b) => !present.contains(b));
      if (missing.isNotEmpty) failures.add('$code: missing ${missing.join(', ')}');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('no book ends with the name of the book that follows it', () {
    // 2026-08-10: eight of LEB's books ended with the NEXT book's title
    // glued to their last verse — Romans 16:24 closed "...Amen. Corinthians",
    // 1 Peter 5:14 closed "...in Christ. Peter". A scrape had swallowed the
    // heading of the following page. This reads as scripture and is not,
    // which is the worst failure mode the corpus has: a reader quoting the
    // verse quotes a word that no edition contains.
    final leadingNumeral = RegExp(r'^\d+\s*');
    final failures = <String>[];
    for (final code in _versions) {
      final order = <String>[];
      final last = <String, Map>{};
      for (final v
          in jsonDecode(File('assets/$code.json').readAsStringSync()) as List) {
        final m = v as Map;
        final b = m['book'] as String;
        if (!last.containsKey(b)) order.add(b);
        last[b] = m;
      }
      for (var i = 0; i < order.length - 1; i++) {
        final next = order[i + 1].replaceFirst(leadingNumeral, '');
        final text = (last[order[i]]!['text'] as String)
            .trim()
            .replaceAll(RegExp(r'[.。!?"”]+$'), '');
        if (text.endsWith(next)) {
          failures.add('$code: ${order[i]} ends with "$next"');
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('the LEB repair of v1.6.91 stays repaired', () {
    // Spot checks on the five defect classes `tools/repair_leb.py` fixed,
    // one verse each, so a re-scrape or a revert cannot quietly undo them.
    final byRef = <String, String>{};
    final counts = <String, int>{};
    for (final v in jsonDecode(File('assets/leb.json').readAsStringSync())
        as List) {
      final m = v as Map;
      counts[m['book'] as String] = (counts[m['book'] as String] ?? 0) + 1;
      byRef['${m['book']} ${m['chapter']}:${m['verse']}'] = m['text'] as String;
    }
    expect(counts['Judges'], 618); // R1: restored book
    expect(counts['Obadiah'], 21); // R1: restored book
    // R2: Hebrews 1:9-10 were one record, so 1:10 did not exist and every
    // reference to it resolved to the wrong verse or to nothing.
    expect(byRef['Hebrews 1:10'], startsWith('And, "You, Lord'));
    // R3: a clause was lost, not misplaced — no other verse held it.
    expect(byRef['Mark 6:6']?.trim(), endsWith('villages teaching.'));
    // R4: the glued next-book name.
    expect(byRef['1 Peter 5:14']?.trim(), endsWith('who are in Christ.'));
    // R5: three records were filed under the book label "The".
    expect(counts.containsKey('The'), isFalse);
  });

  test('no shipped verse carries an invisible character', () {
    // 2026-08-10 (#304): three U+00AD SOFT HYPHENs sat inside
    // `assets/biblexg-v2.json` — 启示录 20:2 read 「他捉住龙<AD>，」. It
    // renders as nothing and cannot be typed, so the verse silently
    // failed an exact-phrase search for text it plainly contains. These
    // were the only ones in the whole corpus, which makes zero the
    // honest bound: any new one is an import defect.
    final failures = <String>[];
    for (final code in _versions) {
      for (final v in _edition(code)) {
        for (final cp in (v['text'] as String).runes) {
          if (_isInvisible(cp)) {
            failures.add('$code ${_ref(v)}: '
                'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')}');
          }
        }
      }
    }
    expect(failures, isEmpty, reason: failures.take(20).join('\n'));
  });

  test('Chinese scripture stays inside its character repertoire', () {
    // 2026-08-10 (#304): the check that would have caught every
    // single-character corruption in the corpus, and the only one that
    // would. A wrong character throws nothing and breaks no key — and
    // it RENDERS, because CanvasKit only drops a glyph it has no font
    // for and the bundled subsets cover every code point we ship. So
    // 申命记 28:52 drew "他们必将你困在你各³ÇÀï£¬Ö±µ½" perfectly
    // legibly, a whole verse of Deuteronomy replaced by GBK bytes that
    // had been decoded as Latin-1. Four more classes hid the same way:
    // □ inside 神, ㄤ for 现, 𨱔 for 鐏, 䍁 for 繸.
    final failures = <String>[];
    for (final code in _chineseVersions) {
      for (final v in _edition(code)) {
        for (final cp in (v['text'] as String).runes) {
          if (_repertoireExceptions.contains(cp)) continue;
          for (final b in _suspectBlocks) {
            if (cp >= b[0] && cp <= b[1]) {
              failures.add('$code ${_ref(v)}: '
                  'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')} '
                  '${String.fromCharCode(cp)}');
              break;
            }
          }
        }
      }
    }
    expect(failures, isEmpty, reason: failures.take(20).join('\n'));
  });

  test('all three 和合本 editions carry every merged-verse marker', () {
    // 和合本 combines 71 verses into a neighbour and prints 見上節 in the
    // verse-number column. cuvs-yhwh and cuvs-yhwh-tr ship that marker
    // at all 71; before v1.6.93 cuvs-plus shipped it at NONE. 60 of the
    // references simply did not exist in the file and the other 11 held
    // junk in six phrasings — three of them the bare letter "a", two of
    // them mojibake. A 和简+ reader on 民数记 1:21 got a blank where the
    // printed edition says "see the previous verse", and cannot tell
    // that from the app having failed to load.
    final byCode = {
      for (final code in ['cuvs-yhwh', 'cuvs-yhwh-tr', 'cuvs-plus'])
        code: {for (final v in _edition(code)) _ref(v): v['text'] as String}
    };
    final sites = byCode['cuvs-yhwh']!.entries
        .where((e) => _mergeMarker.hasMatch(e.value.trim()))
        .map((e) => e.key)
        .toList();
    expect(sites.length, 71);

    final failures = <String>[];
    byCode.forEach((code, verses) {
      for (final ref in sites) {
        final text = verses[ref];
        if (text == null) {
          failures.add('$code $ref: reference absent');
        } else if (!_mergeMarker.hasMatch(text.trim())) {
          failures.add('$code $ref: "${text.trim()}"');
        }
      }
    });
    expect(failures, isEmpty, reason: failures.take(20).join('\n'));
  });

  test('the two 圣经新译本 editions cover the same references', () {
    // The simplified and traditional files are one edition, so they should
    // agree on every reference. Four of the eight that once disagreed were
    // never missing text at all — the traditional file had 马太福音 16:13
    // filed under 16:3, 以弗所书 3:16's number swallowed into a footnote,
    // and 彼得前书 3:11-12 merged into 3:10 — so `tools/repair_biblexg.py`
    // put them back and this side is now empty. 马可福音 6:8-11 really are
    // absent from the simplified file and stay frozen below: restoring them
    // needs a 繁→简 conversion this repo will not invent. Verse boundaries
    // are held by test/biblexg_verse_boundary_test.dart; see
    // docs/DATA-INTEGRITY.md.
    const knownSimplifiedOnly = <String>{};
    const knownTraditionalOnly = {
      'Mark 6:8',
      'Mark 6:9',
      'Mark 6:10',
      'Mark 6:11',
    };
    final simplified = {for (final v in _edition('biblexg-v2')) _ref(v)};
    final traditional = {for (final v in _edition('biblexg-v2-tr')) _ref(v)};
    expect(simplified.difference(traditional), knownSimplifiedOnly);
    expect(traditional.difference(simplified), knownTraditionalOnly);
  });

  test('concordance per-book counts sum to the stated total', () {
    // The Analysis pane prints one number ("G2962 · 64 处") and the
    // per-book breakdown prints another set; if they disagree the
    // reader is told two different things about the same word.
    final conc = jsonDecode(
        File('assets/strongs/concordance.json').readAsStringSync()) as Map;
    expect(conc.length, greaterThan(14000));
    final bad = <String>[];
    conc.forEach((key, value) {
      final e = value as Map;
      final books = (e['b'] as Map).values.cast<num>();
      final sum = books.fold<int>(0, (a, b) => a + b.toInt());
      if (sum != (e['n'] as num).toInt()) {
        bad.add('$key: b sums to $sum, n is ${e['n']}');
      }
    });
    expect(bad, isEmpty, reason: bad.take(10).join('\n'));
  });

  group('the concordance verse list is a census, not a prefix', () {
    // Until v1.6.96 `r` stopped at 500 entries. Because it is in canonical
    // order a capped entry was not a sample of the word but a PREFIX OF
    // THE CANON: H3068's 500 listed verses ended inside Leviticus, so `l
    // jer` then `H3068` answered zero in a book that carries the divine
    // name 712 times. Every consumer that filters or intersects `r` — the
    // search limit, the AND/OR/NEAR set algebra, the book distribution —
    // read that prefix as the whole and said so confidently.
    late Map<dynamic, dynamic> conc;

    setUpAll(() {
      conc = jsonDecode(
          File('assets/strongs/concordance.json').readAsStringSync()) as Map;
    });

    String bookOf(String ref) => ref.substring(0, ref.lastIndexOf(' '));

    test('every entry lists a verse in every book it claims a hit in', () {
      // The general ratchet, and the one that would have caught the cap
      // the day it landed: `b` is uncapped, `r` was not, so the two
      // disagreed about 123 words without either being self-inconsistent.
      // Set equality in both directions — a book in `r` but not `b` means
      // the tally is wrong, a book in `b` but not `r` means the list is
      // short.
      final bad = <String>[];
      conc.forEach((key, value) {
        final e = value as Map;
        final listed = {for (final r in e['r'] as List) bookOf(r as String)};
        final tallied = (e['b'] as Map).keys.cast<String>().toSet();
        final missing = tallied.difference(listed);
        final extra = listed.difference(tallied);
        if (missing.isNotEmpty) {
          bad.add('$key: counted in ${missing.length} books it lists no '
              'verse in (${missing.take(3).join(', ')})');
        }
        if (extra.isNotEmpty) {
          bad.add('$key: lists verses in ${extra.take(3).join(', ')} but '
              'counts none there');
        }
      });
      expect(bad, isEmpty, reason: bad.take(10).join('\n'));
    });

    test('a word is listed in no more verses than it has occurrences', () {
      // The two units are not interchangeable and neither is redundant:
      // G25 is 143 occurrences in 110 verses. But a verse cannot carry
      // fewer than one hit, so verses > occurrences is arithmetically
      // impossible and means the units got crossed somewhere upstream.
      final bad = <String>[];
      conc.forEach((key, value) {
        final e = value as Map;
        final verses = (e['r'] as List).length;
        final occurrences = (e['n'] as num).toInt();
        if (verses > occurrences) {
          bad.add('$key: $verses verses but only $occurrences occurrences');
        }
      });
      expect(bad, isEmpty, reason: bad.take(10).join('\n'));
    });

    test('no entry stops at a round number', () {
      // A cap does not announce itself; it looks like a word that happens
      // to appear exactly 500 times. What gives it away is that many
      // words do. Under the old cap 123 entries shared the length 500.
      final lengths = <int, int>{};
      conc.forEach((_, value) {
        final n = ((value as Map)['r'] as List).length;
        lengths[n] = (lengths[n] ?? 0) + 1;
      });
      final suspicious = [
        for (final e in lengths.entries)
          if (e.key >= 200 && e.value > 20) '${e.value} entries of ${e.key}'
      ];
      expect(suspicious, isEmpty,
          reason: 'a shared long list length is a cap, not a coincidence: '
              '${suspicious.join('; ')}');
    });

    test('the two words that reached the cap now run to the last book', () {
      // Named because they are the ones the audit measured. H3068's list
      // used to end at Leviticus 2:14 and G3588's inside Matthew.
      final divineName = conc['H3068'] as Map;
      expect((divineName['r'] as List).length, 5522);
      expect(divineName['n'], 6521);
      expect((divineName['r'] as List).last, startsWith('Malachi '));

      final article = conc['G3588'] as Map;
      expect((article['r'] as List).length, 6977);
      expect(article['n'], 19859);
      expect((article['r'] as List).last, startsWith('Revelation '));
    });

    test('a search limited to Jeremiah finds the divine name there', () {
      // The reported defect, run the way the search runs it: `l jer`
      // snapshots a key per verse of Jeremiah and `applySearchLimit`
      // keeps the refs falling inside. The answer used to be zero,
      // stated without qualification, because the list stopped 27 books
      // earlier — in a book carrying the divine name 712 times.
      //
      // The limit is built from the book's extent rather than from `r`,
      // so a list that shrinks again cannot drag the expectation with it.
      final limit = {
        for (var c = 1; c <= 52; c++)
          for (var v = 1; v <= 64; v++) 'Jeremiah-$c-$v'
      };
      final refs = [
        for (final r in ((conc['H3068'] as Map)['r'] as List).cast<String>())
          (
            book: bookOf(r),
            chapter: int.parse(r.split(' ').last.split(':').first),
            verse: int.parse(r.split(':').last),
          )
      ];
      final inJeremiah = applySearchLimit(
        refs,
        limit,
        (r) => '${r.book}-${r.chapter}-${r.verse}',
      );
      expect(inJeremiah.length, 614);
      // Fewer verses than occurrences, because a verse can say it twice.
      expect(inJeremiah.length,
          lessThan((conc['H3068'] as Map)['b']['Jeremiah'] as int));
    });
  });

  group('assets/originals corpus', () {
    late List<MapEntry<String, List<dynamic>>> books;

    setUpAll(() {
      books = Directory('assets/originals')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .map((f) => MapEntry(
                f.uri.pathSegments.last,
                (jsonDecode(f.readAsStringSync()) as Map).values.toList(),
              ))
          .toList();
    });

    test('every morphology code decodes to a human parse', () {
      // A code the decoder cannot read falls through to the raw string,
      // so the reader sees "HNcfsa" where a parsing line should be. The
      // audit found zero of these across 4,037 distinct codes; this
      // freezes that, because the corpus is merged offline by
      // `tools/merge_morphology.py` and a scheme change upstream would
      // otherwise land silently.
      final undecodable = <String>{};
      for (final book in books) {
        for (final verse in book.value) {
          for (final w in verse as List) {
            final code = (w as Map)['m'] as String?;
            if (code == null || code.trim().isEmpty) continue;
            final out = describeMorphology(code, 'en');
            if (out == null || out == code.trim()) undecodable.add(code);
          }
        }
      }
      expect(undecodable, isEmpty,
          reason: 'undecodable morphology codes: '
              '${undecodable.take(20).join(', ')}');
    });

    test('the parsing gap is only the received text\'s own readings', () {
      // Before v1.6.92 this was 2,203 words, and the reason was an
      // artefact: OSHB hangs the Qere off a <note> that the merge never
      // read, so every Ketiv/Qere slot went blank. Closing that took the
      // Hebrew Bible to zero, which makes zero the only honest floor —
      // any Hebrew word without a parse now means the merge broke.
      //
      // What remains is Greek and is NOT an artefact: the shipped text
      // is a received-text edition, SBLGNT is a critical one, and a
      // reading SBLGNT does not carry has no parse to borrow. If that
      // count falls, lower the bound; if it rises, something regressed.
      const nt = {
        'matthew', 'mark', 'luke', 'john', 'acts', 'romans',
        '1_corinthians', '2_corinthians', 'galatians', 'ephesians',
        'philippians', 'colossians', '1_thessalonians', '2_thessalonians',
        '1_timothy', '2_timothy', 'titus', 'philemon', 'hebrews', 'james',
        '1_peter', '2_peter', '1_john', '2_john', '3_john', 'jude',
        'revelation',
      };
      final hebrew = <String>[];
      var greek = 0;
      for (final f in Directory('assets/originals')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))) {
        final book = f.uri.pathSegments.last.replaceAll('.json', '');
        (jsonDecode(f.readAsStringSync()) as Map).forEach((ref, words) {
          for (final w in words as List) {
            final code = (w as Map)['m'] as String?;
            if (code != null && code.trim().isNotEmpty) continue;
            if (nt.contains(book)) {
              greek++;
            } else {
              hebrew.add('$book $ref ${w['w']}');
            }
          }
        });
      }
      // The one survivor is not a merge failure: 2 Samuel 18:20 prints
      // the unpointed Ketiv and the pointed Qere as two consecutive
      // words, so the Hebrew reads "כי על על כן" and only one of the pair
      // has a counterpart to align with. Three more verses double a word
      // the same way — see docs/DATA-INTEGRITY.md.
      expect(hebrew, ['2_samuel 18:20 עַל'],
          reason: 'a Hebrew word lost its parse — check that '
              'tools/merge_morphology.py still reads the Qere');
      expect(greek, lessThanOrEqualTo(868));
    });

    test('only the two bracketed passages are wholly unparsed', () {
      // SBLGNT prints neither John 7:53-8:11 nor the Romans doxology, so
      // those verses have no parse at all. Naming them is what keeps a
      // whole chapter from going quietly blank and reading as normal.
      final blank = <String>[];
      for (final f in Directory('assets/originals')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))) {
        final book = f.uri.pathSegments.last.replaceAll('.json', '');
        (jsonDecode(f.readAsStringSync()) as Map).forEach((ref, words) {
          final w = words as List;
          if (w.isNotEmpty &&
              w.every((x) =>
                  ((x as Map)['m'] as String?)?.trim().isNotEmpty != true)) {
            blank.add('$book $ref');
          }
        });
      }
      expect(blank.toSet(), {
        'john 7:53',
        for (var v = 1; v <= 11; v++) 'john 8:$v',
        'romans 16:25', 'romans 16:26', 'romans 16:27',
      });
    });

    test('every Strong\'s number resolves to a lexicon entry', () {
      // 76 numbers legitimately have none: extended-MorphGNT numbers
      // above the Strong's range (G6000+), covering 86 words. They are
      // enumerated rather than pattern-matched so that a 77th cannot
      // appear unnoticed — a word whose lexicon entry is missing shows
      // an empty Word Study pane, which reads as a loading failure.
      final lex = <String>{
        ...(jsonDecode(File('assets/strongs/greek.json').readAsStringSync())
                as Map)
            .keys
            .cast<String>(),
        ...(jsonDecode(File('assets/strongs/hebrew.json').readAsStringSync())
                as Map)
            .keys
            .cast<String>(),
      };
      final missing = <String>{};
      for (final book in books) {
        for (final verse in book.value) {
          for (final w in verse as List) {
            final s = (w as Map)['s'] as String?;
            if (s == null || s.isEmpty) continue;
            if (!lex.contains(s)) missing.add(s);
          }
        }
      }
      final unexpected = missing.where((s) {
        final n = int.tryParse(s.substring(1)) ?? 0;
        return !(s.startsWith('G') && n >= 6000);
      }).toSet();
      expect(unexpected, isEmpty,
          reason: 'Strong\'s numbers with no lexicon entry: '
              '${unexpected.take(20).join(', ')}');
      expect(missing.length, 76,
          reason: 'the count of lexicon-less numbers changed: '
              '${missing.length} (was 76)');
    });
  });

  // ── Check 14 ────────────────────────────────────────────────────
  // Check 12 proves the merge markers are PRESENT in all three 和合本
  // editions. These prove the app RECOGNISES every one of them, plus
  // lxxwh's OMIT and the one empty record — because a marker the
  // recogniser misses is rendered to the reader in scripture type,
  // which is the defect v1.6.93 exists to fix.
  group('references that carry no scripture', () {
    test('the corpus census is exactly what v1.6.93 measured', () {
      final census = <String, int>{};
      var records = 0;
      for (final code in _versions) {
        for (final v in _edition(code)) {
          records++;
          final kind = verseAbsenceOf(v['text'] as String? ?? '');
          if (kind != null) census['$code/${kind.name}'] = (census['$code/${kind.name}'] ?? 0) + 1;
        }
      }
      // +7 over v1.6.93: tools/repair_biblexg.py split seven merged verse
      // boundaries back apart (4 traditional, 3 shared by both files).
      // −2 in v1.6.98: 腓立比書 1:1 was printed as two blocks and the
      // second was numbered 2, in both biblexg files. See check 20.
      // +2 in v1.6.117: Numbers 10:34 and Deuteronomy 23:24 were holes
      // in assets/lxxwh.json, each beside a record holding two Greek
      // verses at once. See check 29.
      // −2 in v1.6.118: 使徒行傳 8:40 was cut across two rows in both
      // biblexg files, the second numbered 8:41, a reference no
      // versification tradition has. See check 30.
      expect(records, 295532);
      expect(census, {
        'cuvs-yhwh/merged': 71,
        'cuvs-yhwh/mergedNext': 1,
        'cuvs-yhwh-tr/merged': 71,
        'cuvs-yhwh-tr/mergedNext': 1,
        'cuvs-plus/merged': 71,
        'cuvs-plus/mergedNext': 1,
        // 馬可福音 9:44 and 9:46, emptied in v1.6.98 when the halves of
        // 9:43 and 9:45 they were holding went back to those verses. The
        // note the sibling editions print there is theirs, in their house
        // style, so it was not copied across — see check 20.
        'cuvs-plus/blank': 2,
        // The one biblexg-v2-tr blank record is gone: it was the husk left
        // where the converter cut 馬太福音 16:13's number into 16:1 + 16:3.
        'lxxwh/omitted': 16,
      });
    });

    test('no near-miss phrasing slips past the recogniser', () {
      // The census above would still pass if an edition started storing
      // a marker in a NEW phrasing — the count would move and someone
      // would update the number. This catches it as what it is instead:
      // any short verse that talks about the verse above or below, or
      // says OMIT, and is not classified. Deliberately wider than
      // `kVerseAbsenceMarkers` so drift shows up as a failure rather
      // than as scripture on the reader's screen.
      final suspicious = RegExp(r'上[节節]|下[节節]|并入|並入|OMIT');
      final failures = <String>[];
      for (final code in _versions) {
        for (final v in _edition(code)) {
          final text = v['text'] as String? ?? '';
          if (verseAbsenceOf(text) != null) continue;
          final t = text.trim();
          if (t.length <= 24 && suspicious.hasMatch(t)) {
            failures.add('$code ${_ref(v)}: "$t"');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.take(20).join('\n'));
    });

    test('every merged reference resolves to a verse that has words', () {
      // The rendering says "Printed with verse N". If N were itself a
      // marker the reader would be sent from one placeholder to another,
      // and if it were unresolvable they would get the vaguer sentence.
      // Neither happens in the shipped corpus, and 詩篇 8:8 is why this
      // is not obvious: 8:7 is ALSO a marker, so the chain has to be
      // walked. Asserted rather than assumed — the code comment in
      // verse_text_absence.dart claims it.
      var resolved = 0;
      final failures = <String>[];
      for (final code in ['cuvs-yhwh', 'cuvs-yhwh-tr', 'cuvs-plus']) {
        final chapters = <String, Map<int, String>>{};
        for (final v in _edition(code)) {
          final key = '${v['book']} ${v['chapter']}';
          final n = int.tryParse('${v['verse']}');
          if (n == null) continue;
          (chapters[key] ??= {})[n] = v['text'] as String? ?? '';
        }
        chapters.forEach((key, verses) {
          final heads = mergedVerseHeads(verses);
          for (final entry in verses.entries) {
            if (verseAbsenceOf(entry.value) != VerseAbsence.merged) continue;
            final head = heads[entry.key];
            if (head == null) {
              failures.add('$code $key:${entry.key}: no head resolved');
            } else if (verseAbsenceOf(verses[head] ?? '') != null) {
              failures.add('$code $key:${entry.key}: head $head is itself '
                  'a placeholder');
            } else {
              resolved++;
            }
          }
        });
      }
      expect(failures, isEmpty, reason: failures.take(20).join('\n'));
      expect(resolved, 213);
    });

    test('every reference an edition lacks sits in a chapter it has', () {
      // What the Browse window's absence row rests on. It prints "this
      // edition has no verse here" for a reference the edition does not
      // carry, and that is only the right sentence when the edition is
      // otherwise present in the chapter — an edition that stops before
      // a whole book is not "missing" its verses one at a time, and a
      // rule that thought so would print the sentence 1,533 times down
      // Genesis for every New-Testament-only edition on screen.
      //
      // 424 absences across six editions, and all 424 are interior. The
      // day one is not, this fails rather than the reader being told
      // something misleading. See check 29.
      final canon = <String>{};
      final canonChapters = <String>{};
      for (final v in _edition('kjv')) {
        canon.add(_ref(v));
        canonChapters.add('${v['book']} ${v['chapter']}');
      }
      final absentByEdition = <String, int>{};
      final outside = <String>[];
      for (final code in _versions) {
        final refs = <String>{};
        final books = <String>{};
        final chapters = <String>{};
        for (final v in _edition(code)) {
          final book = bookNameToEnglish[v['book']] ?? v['book'];
          refs.add(_ref(v));
          books.add('$book');
          chapters.add('$book ${v['chapter']}');
        }
        var absent = 0;
        for (final ref in canon) {
          if (refs.contains(ref)) continue;
          final chapter = ref.substring(0, ref.lastIndexOf(':'));
          if (!books.contains(chapter.substring(0, chapter.lastIndexOf(' ')))) {
            continue; // a book this edition does not claim to carry
          }
          absent++;
          if (!chapters.contains(chapter)) outside.add('$code $ref');
        }
        if (absent > 0) absentByEdition[code] = absent;
      }
      expect(outside, isEmpty, reason: outside.take(20).join('\n'));
      expect(absentByEdition, {
        'bsb': 16,
        'leb': 21,
        'nasb': 13,
        'lxxwh': 302,
        'biblexg-v2': 38,
        'biblexg-v2-tr': 34,
      });
      // Unused otherwise, but it is the count the docs quote.
      expect(absentByEdition.values.reduce((a, b) => a + b), 424);
    });

    test('the two transposed Septuagint passages stay repaired', () {
      // Both had the same three-part shape: a hole, a record holding
      // two Greek verses at once, and a neighbour holding the wrong
      // verse. The last is the one that matters — real Septuagint text
      // under an English reference that means something else, in the
      // column a reader cannot check against anything but us.
      final lxx = <String, String>{
        for (final v in _edition('lxxwh')) _ref(v): v['text'] as String,
      };
      // The cloud, "Rise up", "Return" — in the English order, each
      // carrying the Septuagint's own number for itself.
      expect(lxx['Numbers 10:34'], startsWith('<vs:10:36>'));
      expect(lxx['Numbers 10:35'], startsWith('<vs:10:34>'));
      expect(lxx['Numbers 10:36'], startsWith('<vs:10:35>'));
      expect(lxx['Numbers 10:34'], contains('νεφελη'));
      expect(lxx['Numbers 10:35'], contains('εξεγερθητι'));
      expect(lxx['Numbers 10:36'], contains('επιστρεφε'));
      // The vineyard at 23:24 and the standing corn at 23:25, which is
      // the English order and the reverse of the Greek one.
      expect(lxx['Deuteronomy 23:23'], startsWith('<vs:23:24>'));
      expect(lxx['Deuteronomy 23:24'], startsWith('<vs:23:26>'));
      expect(lxx['Deuteronomy 23:24'], contains('αμπελωνα'));
      expect(lxx['Deuteronomy 23:25'], contains('αμητον'));
      // No record in either chapter holds two Greek verses any more.
      final marker = RegExp(r'<vs:\d+:\d+>');
      for (final ref in ['Numbers 10', 'Deuteronomy 23']) {
        for (var n = 1; n <= 36; n++) {
          final text = lxx['$ref:$n'];
          if (text == null) continue;
          expect(marker.allMatches(text).length, lessThan(2),
              reason: '$ref:$n holds more than one Greek verse');
        }
      }
    });
  });

  // ── Check 30: why each absent reference is absent ─────────────────
  //
  // Check 29 counted the absences and proved each sits in a chapter its
  // edition otherwise carries. It could not say WHY any of them is
  // absent, so all 424 got the same weakest-true sentence — "this
  // edition has no verse here" — including the ones the app can prove
  // are on the page a line higher.
  //
  // Three derivations answer it, none of them a list: the publisher's
  // own `verseLabel` range, the reader keys the original has no words
  // for, and the pairs of reader keys that render ONE original verse.
  // What no derivation reaches is the residue, and the residue is the
  // number that must not grow — every one of those is either a known
  // loss or something nobody has looked at yet.
  group('every absent reference is classified', () {
    // Editions in the English versification frame. lxxwh is excluded on
    // purpose: its 302 absences are a different canon in a different
    // base text, answered by check 29 against an independent LXX
    // witness, and an English-tradition rule over them would report 302
    // defects that are not defects.
    const classified = <String>[
      'bsb',
      'leb',
      'nasb',
      'biblexg-v2',
      'biblexg-v2-tr',
    ];

    late final Versification versification = Versification.fromJson(
      jsonDecode(File('assets/versification.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    /// The references [code] does not carry, in books it does, split
    /// into the three explained classes and the residue.
    Map<String, List<String>> classify(String code) {
      final canon = _canon();
      final present = <String, Map<int, Set<int>>>{};
      final labels = <String, Map<int, Map<int, String>>>{};
      for (final v in _edition(code)) {
        final book = bookNameToEnglish[v['book']] ?? v['book'] as String;
        final c = int.tryParse(v['chapter'].toString());
        final n = int.tryParse(v['verse'].toString());
        if (c == null || n == null) continue;
        (present.putIfAbsent(book, () => {}).putIfAbsent(c, () => {})).add(n);
        labels.putIfAbsent(book, () => {}).putIfAbsent(c, () => {})[n] =
            v['verseLabel']?.toString() ?? '';
      }
      final out = {
        'range': <String>[],
        'notInOriginal': <String>[],
        'sharedOriginal': <String>[],
        'unexplained': <String>[],
      };
      for (final book in present.keys) {
        final chapters = canon[book];
        if (chapters == null) continue;
        for (final entry in chapters.entries) {
          final c = entry.key;
          final have = present[book]?[c] ?? const <int>{};
          if (have.isEmpty) continue;
          final absent = <int>{
            for (var n = 1; n <= entry.value; n++)
              if (!have.contains(n)) n,
          };
          if (absent.isEmpty) continue;
          final ranged = rangeLabelHeads(labels[book]![c]!);
          final rest = absent.where((n) => !ranged.containsKey(n)).toSet();
          final missing = rest
              .where((n) => !versification.isAbsentFromOriginal(book, c, n))
              .toSet();
          final shared = sharedOriginalHeads(missing, have,
              (n) => versification.originalKeys(book, c, n));
          for (final n in absent) {
            final where = !rest.contains(n)
                ? 'range'
                : !missing.contains(n)
                    ? 'notInOriginal'
                    : shared.containsKey(n)
                        ? 'sharedOriginal'
                        : 'unexplained';
            out[where]!.add('$book $c:$n');
          }
        }
      }
      for (final list in out.values) {
        list.sort();
      }
      return out;
    }

    test('the counts are the ones check 30 measured', () {
      final totals = <String, Map<String, int>>{};
      for (final code in classified) {
        totals[code] = {
          for (final e in classify(code).entries) e.key: e.value.length,
        };
      }
      expect(totals, {
        // Both BSB and NASB are absences ONLY where the original has no
        // words. Two editions arriving at that independently is why the
        // row is allowed to say why it is empty.
        'bsb': {
          'range': 0,
          'notInOriginal': 16,
          'sharedOriginal': 0,
          'unexplained': 0,
        },
        'nasb': {
          'range': 0,
          'notInOriginal': 13,
          'sharedOriginal': 0,
          'unexplained': 0,
        },
        // LEB's two merges are 2 Corinthians 13:13 and Acts 19:41, both
        // of which its own notes also declare. The three unexplained
        // are Romans 16:25-27: the doxology is in the edition, inside
        // the note at 16:24, but nothing in the data says so in a form
        // this repository can derive, so it stays unexplained rather
        // than assumed.
        'leb': {
          'range': 0,
          'notInOriginal': 16,
          'sharedOriginal': 2,
          'unexplained': 3,
        },
        // 21 of the 梁家鏗譯本 absences are the publisher's own printed
        // ranges — the largest single class in the corpus and the only
        // one where the edition itself supplies the evidence.
        'biblexg-v2': {
          'range': 21,
          'notInOriginal': 11,
          'sharedOriginal': 1,
          'unexplained': 5,
        },
        'biblexg-v2-tr': {
          'range': 21,
          'notInOriginal': 11,
          'sharedOriginal': 1,
          'unexplained': 1,
        },
      });
    });

    test('the residue is only the losses already named', () {
      final residue = <String>{};
      for (final code in classified) {
        residue.addAll(classify(code)['unexplained']!);
      }
      expect(residue.toList()..sort(), [
        // Simplified only, needing a 繁→简 conversion this repository
        // will not invent. Already frozen in
        // test/biblexg_verse_boundary_test.dart.
        'Mark 6:10',
        'Mark 6:11',
        'Mark 6:8',
        'Mark 6:9',
        // Both 梁家鏗譯本 files: 1:1 ends on a dangling 「：」 and the
        // grace-and-peace greeting is nowhere. A real loss, and the only
        // one this classification found that was not already known.
        'Philippians 1:2',
        // LEB prints the doxology inside its note at 16:24.
        'Romans 16:25',
        'Romans 16:26',
        'Romans 16:27',
      ]);
    });
  });

  // ── Check 30's two repairs ────────────────────────────────────────
  //
  // Both were found while classifying the absences above, and both are
  // the one defect class that outranks everything: a reference that
  // answers with a DIFFERENT verse. A reader comparing columns cannot
  // detect either, because both look like ordinary text.
  group('a reference holds its own verse, not its neighbour\'s', () {
    test('the grace benediction is at 2 Corinthians 13:14', () {
      // The critical text prints the chapter in thirteen verses, joining
      // what the English tradition numbers 12 and 13, so the grace is
      // its verse 13. Three editions follow that numbering and the app
      // keys every edition by the English reference — so until v1.6.118
      // their 13:13 answered with 13:14's words, beside a KJV column
      // reading "All the saints salute you" and nothing to say the two
      // were different verses. 13:12 is untouched and needs no repair:
      // it holds canonical 12 AND 13, which is a superset, not a
      // displacement, and `sharedOriginalHeads` is what tells the reader
      // 13:13 is up there.
      const grace = <String, List<String>>{
        'leb': ['grace', 'love of God', 'fellowship'],
        'biblexg-v2': ['恩', '爱', '圣灵'],
        'biblexg-v2-tr': ['恩', '愛', '聖靈'],
      };
      const salute = <String, List<String>>{
        'leb': ['holy kiss', 'saints greet you'],
        'biblexg-v2': ['亲吻', '全体圣徒'],
        'biblexg-v2-tr': ['親吻', '全體聖徒'],
      };
      for (final code in grace.keys) {
        final byRef = {
          for (final v in _edition(code)) _ref(v): v['text'] as String,
        };
        expect(byRef['2 Corinthians 13:13'], isNull, reason: code);
        for (final token in grace[code]!) {
          expect(byRef['2 Corinthians 13:14'], contains(token), reason: code);
        }
        for (final token in salute[code]!) {
          expect(byRef['2 Corinthians 13:12'], contains(token), reason: code);
        }
      }
    });

    test('使徒行傳 8:40 is one whole verse', () {
      // The row stopped at a comma — 「腓利卻出現在亞鎖城，」 — with the
      // rest under a reference no versification tradition has, so a
      // reader saw Philip appear at Azotus and the sentence end there.
      // The join added no character; the comma was already the clause
      // separator.
      const tails = {'biblexg-v2': '凯撒利亚', 'biblexg-v2-tr': '凱撒利亞'};
      for (final code in tails.keys) {
        final byRef = {
          for (final v in _edition(code)) _ref(v): v['text'] as String,
        };
        expect(byRef['Acts 8:41'], isNull, reason: code);
        expect(byRef['Acts 8:40'], contains(tails[code]!), reason: code);
        expect(byRef['Acts 8:40'], isNot(endsWith('，')), reason: code);
      }
    });
  });

  // Two ingest steps summarised where they were meant to convert and to
  // translate, and in both cases the output ends with a proper closing
  // line — so nothing looked broken and nobody noticed. The relative
  // sizes are the only witness, so the sizes are what gets frozen.
  // `tools/repair_sermon_corpus.py` is the wide version of these.
  group('the sermon corpus says as much in Chinese as it does in English',
      () {
    final sermons = (json.decode(
      File('assets/sermons/index.json').readAsStringSync(),
    ) as List)
        .cast<Map<String, dynamic>>();

    int han(String s) =>
        s.runes.where((r) => r >= 0x4E00 && r <= 0x9FFF).length;

    test('no Traditional body is shorter than the Simplified it came from',
        () {
      // zh-TW is a script conversion of zh-CN, so a faithful pair is 1:1
      // in Han characters. Three scored 0.35 / 0.43 / 0.74 because the
      // proofreading step rewrote the sermon short. Every other pair
      // scores >= 0.995 and the band between is empty, so 0.85 cannot
      // fire on a legitimate file.
      final failures = <String>[];
      for (final s in sermons) {
        final id = s['id'] as String;
        final cn = File('assets/sermons/zh-CN/$id.txt');
        final tw = File('assets/sermons/zh-TW/$id.txt');
        if (!cn.existsSync() || !tw.existsSync()) continue;
        final c = han(cn.readAsStringSync());
        if (c == 0) continue;
        final ratio = han(tw.readAsStringSync()) / c;
        if (ratio < 0.85) {
          failures.add(
              '$id: zh-TW holds ${(ratio * 100).toStringAsFixed(1)}% of zh-CN');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('every summarised Chinese body is marked, and only those', () {
      // Ten sermons were translated at ~0.1 Han characters per English
      // word against a corpus median of 1.40 — a summary wearing the
      // sermon's title. They cannot be repaired without re-translating,
      // so the app tells the reader instead; this asserts the marking
      // still matches the measurement in BOTH directions, so neither a
      // new summary nor a repaired one can drift out of sync with it.
      final measured = <String>{};
      for (final s in sermons) {
        final id = s['id'] as String;
        final cn = File('assets/sermons/zh-CN/$id.txt');
        final en = File('assets/sermons/en/$id.txt');
        if (!cn.existsSync() || !en.existsSync()) continue;
        final words = en
            .readAsStringSync()
            .split(RegExp(r'\s+'))
            .where((w) => w.contains(RegExp(r'[A-Za-z]')))
            .length;
        if (words < 100) continue;
        if (han(cn.readAsStringSync()) / words < 0.5) measured.add(id);
      }
      final marked = {
        for (final s in sermons)
          if ((s['condensed'] as List? ?? const []).isNotEmpty)
            s['id'] as String,
      };
      expect(measured, marked);
      expect(measured, hasLength(10));
      for (final s in sermons) {
        if (!marked.contains(s['id'])) continue;
        // zh-TW is derived from zh-CN, so a summarised Simplified body
        // makes a summarised Traditional one too. Marking only one would
        // leave 繁體 readers unwarned.
        expect(s['condensed'], ['zh-CN', 'zh-TW'], reason: '${s['id']}');
      }
    });
  });

  test('every reference the app shows resolves to a verse that exists',
      _checkReferenceCorpus);
}

// ── Check 25: every reference the app SHOWS resolves ────────────────
//
// The tests above check the references the TEXT is keyed by. These
// check the ones the app puts in front of a reader as a tappable
// string: the two synopsis tables, the section headings, the family
// tree, the timeline, the archaeology gallery, the king list. A string
// naming a verse that does not exist is the same class of defect as a
// wrong transliteration — it states something untrue about the text,
// and the reader has no way to check it.
//
// Canon frame is KJV versification, the frame check 4 used. The wide
// sweep with per-asset counts lives in
// `tools/audit_reference_assets.py`; this is the part cheap enough to
// run on every commit.

/// English book -> chapter -> last verse, from the KJV.
Map<String, Map<int, int>> _canon() {
  final canon = <String, Map<int, int>>{};
  for (final v in jsonDecode(File('assets/kjv.json').readAsStringSync())
      as List) {
    final m = v as Map;
    final book = m['book'] as String;
    final c = int.parse(m['chapter'].toString());
    final n = int.parse(m['verse'].toString());
    final chapters = canon.putIfAbsent(book, () => <int, int>{});
    if (n > (chapters[c] ?? 0)) chapters[c] = n;
  }
  return canon;
}

/// Why a reference fails, or null when every verse it names exists.
String? _resolve(Map<String, Map<int, int>> canon, String book, int c1,
    int? v1, int c2, int? v2) {
  final chapters = canon[book];
  if (chapters == null) return 'no such book: $book';
  if (!chapters.containsKey(c1)) return '$book has no chapter $c1';
  if (!chapters.containsKey(c2)) return '$book has no chapter $c2';
  if (c2 < c1) return 'end chapter $c2 precedes start chapter $c1';
  if (v1 != null && (v1 < 1 || v1 > chapters[c1]!)) {
    return '$book $c1 has ${chapters[c1]} verses, not $v1';
  }
  if (v2 != null && (v2 < 1 || v2 > chapters[c2]!)) {
    return '$book $c2 has ${chapters[c2]} verses, not $v2';
  }
  if (c1 == c2 && v1 != null && v2 != null && v2 < v1) {
    return 'end verse $v2 precedes start verse $v1';
  }
  return null;
}

/// A range whose end precedes its start, spotted BEFORE parsing.
///
/// `parseReference` clamps such a range to its start verse, because a
/// reader still has to be sent somewhere. That clamp is right for
/// navigation and fatal for an audit: it is why `2Ki 23:35-24`, a
/// cross-chapter range truncated at import, read as healthy for five
/// days. Matches "12:5-3" but not "12:5-13:3".
final _backwards = RegExp(r'(\d+)\s*:\s*(\d+)\s*[-–—]\s*(\d+)\s*$');

String? _backwardsRange(String segment) {
  final m = _backwards.firstMatch(segment.trim());
  if (m == null) return null;
  final start = int.parse(m.group(2)!);
  final end = int.parse(m.group(3)!);
  return end < start ? 'end verse $end precedes start verse $start' : null;
}

/// References the corpus states as prose rather than as a citation.
/// Each is listed with the reason it is not a defect.
const _notCitations = <String, String>{
  // The Cairo Genizah's find is Ben Sira, which is outside the canon
  // every edition we ship uses. Naming it is honest.
  'Ecclesiasticus (Sirach) 39:1': 'deuterocanonical, not a shipped book',
  // Strabo's Geography corroborates NT geography generally; the entry
  // does not claim a specific verse.
  'Various NT references': 'prose, not a citation',
};

void _checkReferenceCorpus() {
  final canon = _canon();
  final failures = <String>[];

  /// Split "Isaiah 53; Psalm 22" and "John 18:31-33, 37-38" into parts,
  /// carrying the book (and, for a bare "37-38", the chapter) forward.
  /// Production navigates to the first part only; a reader reads all of
  /// them, so all of them are checked.
  void check(String asset, String where, String? rawOrNull) {
    final raw = rawOrNull?.trim();
    if (raw == null || raw.isEmpty) return;
    BibleReference? carry;
    for (final chunk in raw.split(';')) {
      for (final piece in chunk.split(',')) {
        final segment = piece.trim();
        if (segment.isEmpty) continue;
        if (_notCitations.containsKey(segment)) continue;

        final backwards = _backwardsRange(segment);
        if (backwards != null) {
          failures.add('$asset  $where  "$raw" — $backwards');
          continue;
        }

        // A part with no book of its own inherits the previous one.
        // "Numbers only" rather than "does not begin with a letter",
        // because thirteen books begin with a digit.
        var text = segment;
        if (carry != null && RegExp(r'^[\d:\s–—-]+$').hasMatch(segment)) {
          text = segment.contains(':')
              ? '${carry.englishBook} $segment'
              : '${carry.englishBook} ${carry.chapter}:$segment';
        }

        final ref = parseReference(text);
        if (ref == null) {
          failures.add('$asset  $where  "$raw" — cannot parse "$segment"');
          continue;
        }
        carry = ref;
        final why = _resolve(canon, ref.englishBook, ref.chapter,
            ref.verseStart, ref.endChapter ?? ref.chapter,
            ref.endVerse ?? ref.verseEnd);
        if (why != null) failures.add('$asset  $where  "$raw" — $why');
      }
    }
  }

  Map<String, dynamic> load(String name) =>
      jsonDecode(File('assets/$name').readAsStringSync())
          as Map<String, dynamic>;

  // ot_synopsis — structured, so checked field by field rather than
  // through a formatted string that could hide a lost end chapter.
  for (final g in load('ot_synopsis.json')['groups'] as List) {
    final group = g as Map<String, dynamic>;
    for (final r in group['refs'] as List) {
      final m = r as Map<String, dynamic>;
      final chapter = m['chapter'] as int;
      final endChapter = (m['endChapter'] as int?) ?? chapter;
      final why = _resolve(canon, m['book'] as String, chapter,
          m['start'] as int, endChapter, m['end'] as int);
      if (why != null) {
        failures.add('ot_synopsis.json  group ${group['id']} '
            '${group['en']} — $why');
      }
    }
  }

  for (final e in load('gospel_synopsis.json')['events'] as List) {
    final m = e as Map<String, dynamic>;
    (m['refs'] as Map).forEach((gospel, raw) =>
        check('gospel_synopsis.json', '${m['id']} / $gospel', raw as String?));
  }

  for (final p in load('family_tree.json')['people'] as List) {
    final m = p as Map<String, dynamic>;
    for (final raw in (m['refs'] as List? ?? const [])) {
      check('family_tree.json', m['id'] as String, raw as String?);
    }
  }

  for (final e in load('bible_timeline.json')['events'] as List) {
    final m = e as Map<String, dynamic>;
    for (final raw in (m['refs'] as List? ?? const [])) {
      check('bible_timeline.json', m['id'] as String, raw as String?);
    }
  }

  for (final e in load('bible_evidence.json')['evidences'] as List) {
    final m = e as Map<String, dynamic>;
    check('bible_evidence.json', m['id'] as String,
        m['scriptureReference'] as String?);
  }

  for (final k in load('hebrew_kings.json')['kings'] as List) {
    final m = k as Map<String, dynamic>;
    for (final field in ['kingsRef', 'chroniclesRef', 'accessionRef']) {
      check('hebrew_kings.json', '${m['id']} / $field',
          m[field] as String?);
    }
  }

  (load('section_titles.json')['sets'] as Map).forEach((set, books) {
    (books as Map).forEach((book, chapters) {
      (chapters as Map).forEach((chapter, titles) {
        for (final t in titles as List) {
          final m = t as Map<String, dynamic>;
          check('section_titles.json', '$set / ${m['title']}',
              '$book $chapter:${m['verse']}');
        }
      });
    });
  });

  expect(failures, isEmpty,
      reason: '${failures.length} reference(s) name a verse that does '
          'not exist:\n${failures.join('\n')}');
}
