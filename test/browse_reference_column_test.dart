import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/version_gutter.dart';
import 'package:seeksparks/widgets/browse_window.dart' show BrowseVerseRow;

/// Share of a tagged edition's runs that carry a leading or trailing
/// space, and the token count it was measured over.
({int runs, double spaced}) _spacing(String dir) {
  var runs = 0;
  var spaced = 0;
  for (final f in Directory(dir).listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    for (final verse in (jsonDecode(f.readAsStringSync()) as Map).values) {
      for (final run in verse as List) {
        final w = (run as Map)['w'];
        if (w is! String) continue;
        runs++;
        if (w.startsWith(' ') || w.endsWith(' ')) spaced++;
      }
    }
  }
  return (runs: runs, spaced: runs == 0 ? 0 : spaced / runs);
}

/// Advance widths of `Roboto-VariableFont_wdth,wght.ttf` at `wght=600`,
/// in ems, read out of the shipped font's `hmtx` table with fontTools.
///
/// The reference column is measured by a character model rather than by
/// a `TextPainter` (see `version_gutter.dart` for why), and a model that
/// UNDER-estimates would clip a verse reference — which is not a
/// blemish but a lie about which verse the reader is looking at. This
/// table is what makes "the model never under-estimates" a testable
/// claim rather than an intention.
const _roboto600 = <String, double>{
  ' ': 0.2485, '0': 0.5713, '1': 0.5713, '2': 0.5713, '3': 0.5713,
  '4': 0.5713, '5': 0.5713, '6': 0.5713, '7': 0.5713, '8': 0.5713,
  '9': 0.5713, ':': 0.2725, 'A': 0.6675, 'C': 0.6538, 'D': 0.6514,
  'E': 0.5640, 'G': 0.6816, 'H': 0.7080, 'I': 0.2876, 'J': 0.5571,
  'K': 0.6338, 'L': 0.5405, 'M': 0.8750, 'N': 0.7075, 'O': 0.6895,
  'P': 0.6416, 'R': 0.6353, 'S': 0.6104, 'T': 0.6147, 'Z': 0.6050,
  'a': 0.5371, 'b': 0.5625, 'c': 0.5215, 'd': 0.5630, 'e': 0.5381,
  'f': 0.3555, 'g': 0.5688, 'h': 0.5581, 'i': 0.2598, 'k': 0.5278,
  'l': 0.2598, 'm': 0.8687, 'n': 0.5586, 'o': 0.5659, 'p': 0.5625,
  'r': 0.3599, 's': 0.5142, 't': 0.3359, 'u': 0.5581, 'v': 0.5010,
  'w': 0.7383, 'x': 0.5059, 'y': 0.4966, 'z': 0.5059,
};

/// Every English book name the app can put in front of a verse number.
const _englishBooks = <String>[
  '1 Chronicles', '1 Corinthians', '1 John', '1 Kings', '1 Peter',
  '1 Samuel', '1 Thessalonians', '1 Timothy', '2 Chronicles',
  '2 Corinthians', '2 John', '2 Kings', '2 Peter', '2 Samuel',
  '2 Thessalonians', '2 Timothy', '3 John', 'Acts', 'Amos',
  'Colossians', 'Daniel', 'Deuteronomy', 'Ecclesiastes', 'Ephesians',
  'Esther', 'Exodus', 'Ezekiel', 'Ezra', 'Galatians', 'Genesis',
  'Habakkuk', 'Haggai', 'Hebrews', 'Hosea', 'Isaiah', 'James',
  'Jeremiah', 'Job', 'Joel', 'John', 'Jonah', 'Joshua', 'Jude',
  'Judges', 'Lamentations', 'Leviticus', 'Luke', 'Malachi', 'Mark',
  'Matthew', 'Micah', 'Nahum', 'Nehemiah', 'Numbers', 'Obadiah',
  'Philemon', 'Philippians', 'Proverbs', 'Psalms', 'Revelation',
  'Romans', 'Ruth', 'Song of Solomon', 'Titus', 'Zechariah',
  'Zephaniah',
];

double _measuredEms(String s) {
  var total = 0.0;
  for (final c in s.split('')) {
    final w = _roboto600[c];
    expect(w, isNotNull, reason: 'no measurement for "$c"');
    total += w!;
  }
  return total;
}

void main() {
  group('the reference column is never narrower than the reference', () {
    test('the model over-estimates all 66 English book names', () {
      // Psalm 119:176 is the longest chapter:verse in the canon, so
      // this is the widest each book name can ever get.
      final overruns = <String, double>{};
      for (final book in _englishBooks) {
        final reference = '$book 119:176';
        final model = referenceLabelEms(reference);
        final measured = _measuredEms(reference);
        expect(model, greaterThanOrEqualTo(measured),
            reason: '"$reference" would clip: model $model < real $measured');
        overruns[book] = model / measured - 1;
      }
      // And it does not over-estimate so far that the column eats the
      // reading width — the flat 0.78-em model it replaced ran +45%.
      final worst = overruns.values.reduce((a, b) => a > b ? a : b);
      expect(worst, lessThan(0.20));
    });

    test('a Han character is charged a full em', () {
      // A CJK glyph is exactly one em, so 歷代志下 is charged 4.0 — and
      // the Chinese reference therefore comes out NARROWER than
      // `2 Chronicles`, which is twelve Latin characters. Worth pinning
      // because the intuition runs the other way: an ideograph is wider
      // than a letter, but a book name is fewer of them.
      expect(referenceLabelEms('歷代志下'), closeTo(4.0, 0.001));
      expect(referenceLabelEms('歷代志下 1:1'),
          lessThan(referenceLabelEms('2 Chronicles 1:1')));
      // Per character, though, it is charged the most of anything.
      expect(referenceLabelEms('歷'), greaterThan(referenceLabelEms('M')));
    });
  });

  group('one width for the whole chapter', () {
    test('is at least the widest reference in it, plus the gap', () {
      final refs = [for (var v = 1; v <= 176; v++) 'Psalms 119:$v'];
      final width = referenceGutterWidth(refs, 15);
      for (final r in refs) {
        expect(width, greaterThanOrEqualTo(referenceLabelEms(r) * 15));
      }
      expect(width, referenceLabelEms('Psalms 119:176') * 15 + 8);
    });

    test('follows the font-size slider', () {
      final small = referenceGutterWidth(['John 3:16'], 10);
      final large = referenceGutterWidth(['John 3:16'], 20);
      // The gap is a constant, so the text part is what doubles.
      expect(large - 8, closeTo((small - 8) * 2, 0.001));
    });

    test('is sized to the book on screen, not to the canon', () {
      // A reader in Obadiah does not pay for Song of Solomon existing.
      expect(referenceGutterWidth(['Obadiah 1:21'], 15),
          lessThan(referenceGutterWidth(['Song of Solomon 8:14'], 15)));
    });

    test('an empty chapter asks for no column at all', () {
      expect(referenceGutterWidth(const [], 15), 0);
    });
  });

  group('who owns the space between two words', () {
    // `kBrowseWordGap` is applied to the originals `Wrap` and NOT to the
    // tagged one, which reads like an oversight and is not. These are
    // the measurements that decide it, frozen here because the assets
    // are regenerated offline: a generator that started emitting bare
    // runs for the BSB, or spaced ones for the originals, would jam or
    // double-space the Browse pane with every test still green.

    test('an originals token is bare, so the gap is required', () {
      final o = _spacing('assets/originals');
      expect(o.runs, greaterThan(400000));
      // Not "almost none" — exactly none, across the whole corpus.
      expect(o.spaced, 0.0,
          reason: 'assets/originals now carries its own spacing; '
              'kBrowseWordGap would double it');
    });

    test('a tagged edition brings its own, so the gap must NOT be', () {
      // Three conventions, one conclusion. The floors sit well under the
      // measured values so ordinary editorial churn does not trip them;
      // a generator CHANGING CONVENTION moves these by ~70 points.
      const spaceSeparated = {'bsb': 0.80, 'kjvs': 0.55, 'lxxwh': 0.85};
      for (final e in spaceSeparated.entries) {
        final dir = Directory('assets/tagged/${e.key}');
        // nsn-plus and friends are deliberately not in the repo.
        if (!dir.existsSync()) continue;
        final m = _spacing(dir.path);
        expect(m.spaced, greaterThan(e.value),
            reason: '${e.key} runs no longer carry their own spacing, so '
                'the Browse pane will print its words jammed together');
      }
    });

    test('Chinese has no word gap to carry, and must not be given one', () {
      // The reason the gap cannot simply be moved onto the tagged path:
      // 亚当生塞特 is one run per word and nothing separates them, so a
      // 5px gap would open holes inside a Chinese sentence.
      for (final code in const ['cuvs-plus', 'cuvs-yhwh']) {
        final dir = Directory('assets/tagged/$code');
        if (!dir.existsSync()) continue;
        expect(_spacing(dir.path).spaced, lessThan(0.01), reason: code);
      }
    });
  });

  group('BrowseVerseRow: the verse text starts on the same x', () {
    const style = TextStyle(fontSize: 14);

    Widget host(List<Widget> rows) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows,
              ),
            ),
          ),
        );

    // Wide enough that the column, not the reference's own intrinsic
    // width, is the binding constraint — the headless test font draws
    // about one em per character, so a 160px column would be pushed
    // open by `2 Chronicles 1:1` and the fixed-width claim would go
    // untested.
    const columnWidth = 400.0;

    testWidgets('across a text flow, a Wrap and an RTL Wrap', (tester) async {
      // The three render paths of the Browse pane, in the shapes they
      // actually take: an untagged edition is one text flow, a tagged
      // translation is a Wrap of word widgets, and the originals are
      // that inside an RTL scope. Before 2026-08-17 each built its own
      // reference cell and the three disagreed.
      await tester.pumpWidget(host([
        BrowseVerseRow(
          reference: '2 Chronicles 1:1',
          referenceWidth: columnWidth,
          referenceStyle: style,
          child: const Text('Solomon son of David established himself',
              key: ValueKey('untagged')),
        ),
        BrowseVerseRow(
          reference: '2 Chronicles 1:1',
          referenceWidth: columnWidth,
          referenceStyle: style,
          child: const Wrap(
            key: ValueKey('tagged'),
            children: [Text('Solomon '), Text('son ')],
          ),
        ),
        BrowseVerseRow(
          reference: '2 Chronicles 1:1',
          referenceWidth: columnWidth,
          referenceStyle: style,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              key: ValueKey('originals'),
              spacing: 5,
              children: [Text('וַיִּתְחַזֵּק'), Text('שְׁלֹמֹה')],
            ),
          ),
        ),
      ]));

      final xs = [
        for (final k in ['untagged', 'tagged', 'originals'])
          tester.getTopLeft(find.byKey(ValueKey(k))).dx
      ];
      expect(xs[0], xs[1]);
      expect(xs[1], xs[2]);
      // And it is the column width, not wherever this row's own
      // reference happened to end.
      expect(xs[0], columnWidth);
    });

    testWidgets('a longer verse number does not move the text',
        (tester) async {
      await tester.pumpWidget(host([
        BrowseVerseRow(
          reference: 'Psalms 119:1',
          referenceWidth: columnWidth,
          referenceStyle: style,
          child: const Text('x', key: ValueKey('short')),
        ),
        BrowseVerseRow(
          reference: 'Psalms 119:176',
          referenceWidth: columnWidth,
          referenceStyle: style,
          child: const Text('x', key: ValueKey('long')),
        ),
      ]));
      expect(tester.getTopLeft(find.byKey(const ValueKey('short'))).dx,
          tester.getTopLeft(find.byKey(const ValueKey('long'))).dx);
    });

    testWidgets('a reference wider than the column pushes, never clips',
        (tester) async {
      // The deliberate failure mode. If the reader's font is wider than
      // the model was calibrated on, the column goes ragged — which is
      // a blemish — rather than cutting the reference short, which
      // would misname the verse.
      await tester.pumpWidget(host([
        BrowseVerseRow(
          reference: 'Song of Solomon 8:14',
          referenceWidth: 0,
          referenceStyle: style,
          child: const Text('x', key: ValueKey('pushed')),
        ),
      ]));
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(find.byKey(const ValueKey('pushed'))).dx,
          greaterThan(0));
    });
  });
}
