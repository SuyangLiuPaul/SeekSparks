// The Septuagint's own verse numbers were shipping as scripture.
//
// `assets/lxxwh.json` carried 4,687 markers of the form `(102:12)` in
// 4,541 verses — the edition's own chapter-and-verse for the words that
// follow, printed because the Greek Psalter numbers Psalm 103 as 102
// and Jeremiah barely agrees with the Hebrew at all. A reader saw them
// as part of the verse.
//
// The tagged layer had it worse. The marker was glued onto the first
// word of the run, so `(102:12) καθ ` carried καθ's Strong's number and
// parse: 4,400 of the 4,672 markers answered a lexicon lookup with the
// entry for the word after them. Tapping `(5:27)` in 1 Chronicles 6:1
// returned G5207 υἱοί, a masculine plural noun.
//
// Repaired by `tools/fix_lxx_versification.py`. These tests hold both
// halves down: the parser must type the token as apparatus rather than
// text, and neither asset may carry a bare marker again.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/utils/copy_format.dart';
import 'package:seeksparks/utils/scripture_markup.dart';

// `(1:1)` or `(30:28α)`, anywhere in a string. What must never come
// back into the shipped text.
final _bareMarker = RegExp(r'\(\s*\d+:\d+[α-ω]?\s*\)');
final _wellFormed = RegExp(r'^<vs:\d+:\d+[α-ω]?>$');

const _lxxBooks = <String>[
  'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
  'judges', 'ruth', '1_samuel', '2_samuel', '1_kings', '2_kings',
  '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job',
  'psalms', 'proverbs', 'ecclesiastes', 'song_of_solomon', 'isaiah',
  'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel',
  'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah',
  'haggai', 'zechariah', 'malachi', 'matthew', 'mark', 'luke', 'john',
  'acts', 'romans', '1_corinthians', '2_corinthians', 'galatians',
  'ephesians', 'philippians', 'colossians', '1_thessalonians',
  '2_thessalonians', '1_timothy', '2_timothy', 'titus', 'philemon',
  'hebrews', 'james', '1_peter', '2_peter', '1_john', '2_john',
  '3_john', 'jude', 'revelation',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the token parses as apparatus, not as text', () {
    test('a leading marker is its own span and the Greek is untouched',
        () {
      final spans = parseScripture('<vs:102:12>καθ οσον απεχουσιν');
      expect(spans, hasLength(2));
      expect(spans.first,
          const ScriptureSpan('102:12', ScriptureSpanKind.versification));
      expect(spans.last.kind, ScriptureSpanKind.plain);
      expect(spans.last.text, 'καθ οσον απεχουσιν');
    });

    test('a mid-verse marker splits the verse where the edition does',
        () {
      // 1 Samuel 30:28 holds what the Septuagint numbers 30:28 and
      // 30:28α, so the marker arrives after the first clause.
      final spans =
          parseScripture('και τοις εν εσθιε <vs:30:28α>και τοις εν γεθ');
      expect(spans.map((s) => s.kind), [
        ScriptureSpanKind.plain,
        ScriptureSpanKind.versification,
        ScriptureSpanKind.plain,
      ]);
      expect(spans[1].text, '30:28α');
    });

    test('a sub-verse letter survives, and a footnote is still a footnote',
        () {
      final spans = parseScripture('a<note: Or "b">c<vs:9:2α>d');
      expect(spans.map((s) => '${s.kind.name}:${s.text}'), [
        'plain:a',
        'note:Or "b"',
        'plain:c',
        'versification:9:2α',
        'plain:d',
      ]);
    });

    test('the reference never reaches the reading text', () {
      expect(scriptureReadingText('<vs:102:12>καθ οσον'), 'καθ οσον');
      expect(scriptureVersificationRefs('<vs:102:12>καθ <vs:102:13>οσον'),
          ['102:12', '102:13']);
      expect(hasScriptureMarkup('<vs:102:12>καθ'), isTrue);
      expect(hasScriptureMarkup('καθ οσον'), isFalse);
    });

    test('the reader-side sanitizers strip it from search and clipboard',
        () {
      expect(sanitizeVerseText('<vs:102:12>καθ οσον'), 'καθ οσον');
      expect(sanitizeForSearch('<vs:102:12>καθ οσον'), 'καθ οσον');
    });

    test('a paste carries the reference only when notes were asked for',
        () {
      const raw = '<vs:102:12>καθ οσον';
      expect(
          copyVerseText(raw, const CopyOptions(includeNotes: false)),
          'καθ οσον');
      expect(copyVerseText(raw, const CopyOptions(includeNotes: true)),
          '(102:12) καθ οσον');
    });
  });

  group('the shipped assets', () {
    test('no verse of lxxwh prints a bare (chapter:verse) marker',
        () async {
      final rows = (json.decode(await rootBundle.loadString(
          'assets/lxxwh.json')) as List).cast<Map<String, dynamic>>();
      expect(rows, hasLength(30798));

      final bare = <String>[];
      var tokens = 0;
      var verses = 0;
      for (final row in rows) {
        final text = row['text'] as String;
        if (_bareMarker.hasMatch(text)) {
          bare.add('${row['book']} ${row['chapter']}:${row['verse']}');
        }
        final found = RegExp(r'<vs:[^>]*>').allMatches(text);
        if (found.isNotEmpty) {
          tokens += found.length;
          verses++;
          for (final m in found) {
            expect(_wellFormed.hasMatch(m.group(0)!), isTrue,
                reason: 'malformed marker ${m.group(0)} in '
                    '${row['book']} ${row['chapter']}:${row['verse']}');
          }
        }
      }
      expect(bare, isEmpty);
      expect(tokens, 4687);
      expect(verses, 4541);

      // An unaccented Greek text writes its numerals as letters, so a
      // digit outside a marker cannot be scripture. This is what made
      // the marker safe to detect in the first place, and it must stay
      // true or the next import will need a different method.
      for (final row in rows) {
        final withoutMarkers =
            (row['text'] as String).replaceAll(RegExp(r'<vs:[^>]*>'), '');
        expect(withoutMarkers.contains(RegExp(r'\d')), isFalse,
            reason: 'a digit outside a marker in ${row['book']} '
                '${row['chapter']}:${row['verse']}');
      }
    });

    test('no marker in the tagged layer carries a Strong\'s number',
        () async {
      var markers = 0;
      for (final book in _lxxBooks) {
        final refs = (json.decode(await rootBundle
                .loadString('assets/tagged/lxxwh/$book.json'))
            as Map<String, dynamic>);
        for (final entry in refs.entries) {
          for (final run in (entry.value as List)) {
            final w = (run as Map<String, dynamic>)['w'] as String;
            expect(_bareMarker.hasMatch(w), isFalse,
                reason: 'a bare marker still glued to a word in '
                    '$book ${entry.key}: $w');
            if (!w.startsWith('<vs:')) continue;
            markers++;
            expect(_wellFormed.hasMatch(w), isTrue,
                reason: 'malformed marker in $book ${entry.key}: $w');
            // The whole defect in one assertion: the marker is not a
            // word, so it has no lemma and no parse.
            expect(run['s'], '',
                reason: 'marker carries a Strong\'s in $book '
                    '${entry.key}');
            expect(run['g'], isEmpty,
                reason: 'marker carries a parse in $book ${entry.key}');
            expect(run['i'], isEmpty);
          }
        }
      }
      // 15 fewer than the text layer: Nehemiah 10 is missing 15 of its
      // 39 verses from the tagged import — a pre-existing coverage gap,
      // recorded in docs/DATA-INTEGRITY.md, not a loss from this repair.
      expect(markers, 4672);
    });
  });
}
