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
import 'package:seeksparks/utils/morphology.dart';
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
/// 12:18, and biblexg-v2's own block note on Acts 8:40 says it splits
/// that verse "遵从最新希腊文新约底本 NA28、UBS5".
const _knownBeyondCanon = <String>{
  '3 John 1:15',
  'Revelation 12:18',
  'Acts 8:41',
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
      expect(records, 295534);
      expect(census, {
        'cuvs-yhwh/merged': 71,
        'cuvs-yhwh/mergedNext': 1,
        'cuvs-yhwh-tr/merged': 71,
        'cuvs-yhwh-tr/mergedNext': 1,
        'cuvs-plus/merged': 71,
        'cuvs-plus/mergedNext': 1,
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
  });
}
