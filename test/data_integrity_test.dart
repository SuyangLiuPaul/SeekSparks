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
}
