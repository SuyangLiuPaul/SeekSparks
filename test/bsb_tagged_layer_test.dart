// The BSB interlinear was printing the translation table's markup as
// scripture, and answering nearly every word tap with the wrong lexicon
// entry.
//
// 311,267 of its 386,063 runs — 80.6% — carried a Strong's number that
// was the first digit of the right one: H7225 בְּרֵאשִׁית "in the
// beginning" shipped as H7, H6870 Zeruiah as H6. The importer read the
// tables' numeric cells through the helper that groups thousands for the
// counts the Bible prints (74,600), so 7225 became "7,225" and the digit
// scan stopped at the comma. The same helper fed the column that orders
// the original words, where the grouped string failed int() and fell
// back to 0 — so the walk that decides which word an untranslated
// original attaches to was running on 970,285 identical keys.
//
// Nothing caught it because a truncated number is still a real number:
// all 432,859 of them resolved against `assets/strongs/`, and H7 has an
// entry to show. The check that does catch it is the second witness —
// `assets/tagged/cuvs-yhwh/` is an independent alignment of the same
// originals, and the two agreed on 13.36% of each verse's numbers.
// They now agree on 92.79%.
//
// `assets/tagged/bsb/` is what the Browse pane draws and what a lexicon
// tap reads. It carried 25,357 runs that are not words: 20,508 `. . .`
// and 4,849 `vvv` — the tables' two ways of saying "this original word
// is folded into a neighbouring English phrase" — plus 726 raw HTML
// tags, mostly the source's verse-number anchor. 24,586 of those runs
// also carried a Strong's number, so tapping one answered with the
// lexicon entry for a word that was never printed there.
//
// The suite stayed green through all of it, because nothing had ever
// asked the tagged layer to agree with the printed text. That is the
// question these tests ask, and it is the cheapest one available: the
// two assets are two renderings of the same verse, so any disagreement
// is a defect in one of them.
//
// 30,838 of 31,086 verses reconstruct the printed text exactly. The
// remainder is enumerated in docs/DATA-INTEGRITY.md, check 22, and
// bounded here so it cannot quietly grow.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

// Anything angle-bracketed. The tagged layer has no legitimate use for
// one — `<note:>` and `<vs:>` belong to the text layer.
final _markup = RegExp(r'<[^<>]{0,200}>');

// The three ways the tables say "no English of its own". `-` never
// reached the shipped data; the other two did.
final _placeholder = RegExp(r'\bvvv\b|\. \. \.');

// Supplied words are marked, and that is deliberate — BSB italicises
// what it adds. The printed text drops the marks, so a comparison must
// too.
String _asPrinted(String s) =>
    s.replaceAll('[', '').replaceAll(']', '').replaceAll(RegExp(r'\s+'), ' ').trim();

String _slug(String book) => book.toLowerCase().replaceAll(' ', '_');

Set<String> _numbers(List<dynamic> runs) {
  final out = <String>{};
  for (final run in runs.cast<Map<String, dynamic>>()) {
    final s = run['s'] as String?;
    if (s != null && s.isNotEmpty) out.add(s);
    for (final i in (run['i'] as List<dynamic>? ?? const [])) {
      out.add(i as String);
    }
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Map<String, String>> printed;
  late Map<String, Map<String, List<dynamic>>> tagged;

  setUpAll(() async {
    printed = <String, Map<String, String>>{};
    final text = jsonDecode(await rootBundle.loadString('assets/bsb.json'))
        as List<dynamic>;
    for (final v in text.cast<Map<String, dynamic>>()) {
      printed
          .putIfAbsent(_slug(v['book'] as String), () => <String, String>{})
          .putIfAbsent('${v['chapter']}:${v['verse']}', () => v['text'] as String);
    }

    tagged = <String, Map<String, List<dynamic>>>{};
    for (final book in printed.keys) {
      final raw = await rootBundle.loadString('assets/tagged/bsb/$book.json');
      tagged[book] = (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as List<dynamic>));
    }
  });

  test('no run carries the table\'s markup or its placeholders', () {
    final offenders = <String>[];
    for (final book in tagged.keys) {
      tagged[book]!.forEach((ref, runs) {
        for (final run in runs.cast<Map<String, dynamic>>()) {
          final w = run['w'] as String;
          if (_markup.hasMatch(w) || _placeholder.hasMatch(w)) {
            offenders.add('$book $ref ${jsonEncode(w)}');
          }
        }
      });
    }
    expect(offenders, isEmpty,
        reason: 'the tagged layer is printed as scripture and answers '
            'lexicon taps; ${offenders.length} runs are not words');
  });

  test('every verse of the printed text is tagged, and no more', () {
    for (final book in printed.keys) {
      expect(tagged[book]!.keys.toSet(), printed[book]!.keys.toSet(),
          reason: 'tagged and printed disagree about which verses $book has');
    }
  });

  test('the runs reconstruct the printed verse', () {
    var exact = 0;
    var total = 0;
    for (final book in printed.keys) {
      printed[book]!.forEach((ref, expected) {
        total++;
        final joined = tagged[book]![ref]!
            .cast<Map<String, dynamic>>()
            .map((r) => r['w'] as String)
            .join();
        if (_asPrinted(joined) == _asPrinted(expected)) exact++;
      });
    }
    expect(total, 31086);
    // Was 8,269 before the tables were re-read. The residue is 248
    // verses, every one of them listed in docs/DATA-INTEGRITY.md; this
    // bound fails if a future import gives any of them back.
    expect(exact, greaterThanOrEqualTo(30838),
        reason: 'only $exact of $total verses reconstruct the printed text');
  });

  test('a verse that lost punctuation with its untranslated row is whole',
      () {
    // The `)` sat on the row for מִשָּׁם, which renders no English, so it
    // was discarded with the row.
    final joined = tagged['1_chronicles']!['1:12']!
        .cast<Map<String, dynamic>>()
        .map((r) => r['w'] as String)
        .join();
    expect(_asPrinted(joined), contains('the Philistines came), and'));
  });

  test('the numbers agree with the independent Chinese alignment', () async {
    // Two alignments of the same originals, made by different people from
    // different sides: the BSB tables in English, a hand-edited MySword
    // module in Chinese. Neither is derived from the other, so where they
    // agree about a verse's Strong's numbers they are two witnesses, and
    // a systematic corruption of either shows up here as a collapse.
    var shared = 0;
    var union = 0;
    var verses = 0;
    for (final book in tagged.keys) {
      final zh = (jsonDecode(
                  await rootBundle.loadString('assets/tagged/cuvs-yhwh/$book.json'))
              as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as List<dynamic>));
      tagged[book]!.forEach((ref, runs) {
        final other = zh[ref];
        if (other == null) return;
        final a = _numbers(runs);
        final b = _numbers(other);
        if (a.isEmpty || b.isEmpty) return;
        verses++;
        shared += a.intersection(b).length;
        union += a.union(b).length;
      });
    }
    expect(verses, greaterThan(30000));
    final agreement = 100.0 * shared / union;
    // Was 13.36% while every number above 999 was truncated to its first
    // digit. The residue is genuine alignment difference — the two
    // editions disagree about which word an article or a particle rides
    // on — and it does not move without a change to one of the imports.
    expect(agreement, greaterThan(92.0),
        reason: 'the two alignments agree on only '
            '${agreement.toStringAsFixed(2)}% of each verse\'s numbers');
  });

  test('a word above the first thousand keeps all its digits', () {
    // The truncation was invisible because H7 exists. These are the
    // verse and the word the app opens on.
    final runs = tagged['genesis']!['1:1']!.cast<Map<String, dynamic>>();
    expect(runs.first['w'], startsWith('In the beginning'));
    expect(runs.first['s'], 'H7225');
  });

  test('a folded original keeps its number as an implied one', () {
    // עֲשָׂה־אֵל is two rows and one name: the second renders "and
    // Asahel", the first rendered `vvv` and used to print it.
    final runs = tagged['1_chronicles']!['2:16']!.cast<Map<String, dynamic>>();
    final asahel = runs.lastWhere((r) => (r['w'] as String).contains('Asahel'));
    expect(asahel['s'], 'H6214');
    expect(asahel['i'], contains('H6214'));
  });
}
