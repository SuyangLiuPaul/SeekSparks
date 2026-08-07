// 2026-08-07 (task #282): the divine name was being printed as a
// translator's insertion.
//
// `主[雅伟]` in 和合本雅伟版 is a REFERENT GLOSS — the 主 printed here is
// Yahweh — but the only bracket rule the app had was "supplied words",
// so the Name rendered in the italic that printed Bibles reserve for
// text with no counterpart in the original, and the clipboard dropped
// its brackets to paste `主雅伟`. Both state the reverse of what the
// edition claims.
//
// Three of these tests are worth more than the rest, because they run
// against the SHIPPED ASSETS rather than a fixture. The bug lived
// through 1,475 green tests precisely because every test used strings a
// human wrote, and the defect was in a file an importer wrote.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/text_patterns.dart'
    show versePreviewText;
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/services/tagged_text_service.dart';
import 'package:seeksparks/utils/copy_format.dart';
import 'package:seeksparks/utils/kwic.dart';
import 'package:seeksparks/utils/scripture_markup.dart';

TaggedRun run(String text, String strongs) =>
    TaggedRun(text: text, strongs: strongs);

void main() {
  group('bracketSpanKind', () {
    test('the divine name is not a supplied word', () {
      expect(bracketSpanKind('雅伟'), ScriptureSpanKind.divineName);
      expect(bracketSpanKind('雅偉'), ScriptureSpanKind.divineName);
      expect(bracketSpanKind('Yahweh'), ScriptureSpanKind.divineName);
    });

    test('the christological gloss is its own kind', () {
      expect(bracketSpanKind('基督'), ScriptureSpanKind.gloss);
    });

    test('everything else stays a supplied word', () {
      // BSB alone brackets 18,744 runs and every one is an insertion.
      expect(bracketSpanKind('was'), ScriptureSpanKind.supplied);
      expect(bracketSpanKind('The sons of'), ScriptureSpanKind.supplied);
      expect(bracketSpanKind(''), ScriptureSpanKind.supplied);
    });
  });

  group('parseScripture', () {
    test('Matthew 22:44 carries both glosses in one verse', () {
      // The verse that makes styling one of them as an insertion
      // impossible to defend: they sit four characters apart.
      const raw = '‘主[雅伟]对我主[基督] 说：你坐在我的右边，';
      final spans = parseScripture(raw);
      expect(spans[0], ScriptureSpan('‘主', ScriptureSpanKind.plain));
      expect(spans[1], ScriptureSpan('雅伟', ScriptureSpanKind.divineName));
      expect(spans[2], ScriptureSpan('对我主', ScriptureSpanKind.plain));
      expect(spans[3], ScriptureSpan('基督', ScriptureSpanKind.gloss));
    });

    test('a supplied word is untouched by the new kinds', () {
      final spans = parseScripture('darkness [was] over the deep.');
      expect(spans[1], ScriptureSpan('was', ScriptureSpanKind.supplied));
    });
  });

  group('scriptureReadingText', () {
    test('a gloss keeps its brackets, a supplied word loses them', () {
      // Unbracketed, the gloss reads as a divine title the verse does
      // not contain and nothing on screen says otherwise.
      expect(scriptureReadingText('有主[雅伟]的使者'), '有主[雅伟]的使者');
      expect(scriptureReadingText('darkness [was] over'),
          'darkness was over');
    });
  });

  group('copyVerseText', () {
    test('turning supplied brackets OFF does not unbracket the Name', () {
      // The option asks "mark the translator's insertions?". Answering
      // no must not fabricate a reading in someone's sermon notes.
      const o = CopyOptions(keepSuppliedBrackets: false);
      expect(copyVerseText('有主[雅伟]的使者', o), '有主[雅伟]的使者');
      expect(copyVerseText('darkness [was] over', o), 'darkness was over');
    });

    test('and turning them ON still brackets both', () {
      const o = CopyOptions(keepSuppliedBrackets: true);
      expect(copyVerseText('主[基督]说', o), '主[基督]说');
      expect(copyVerseText('darkness [was] over', o), 'darkness [was] over');
    });
  });

  group('versePreviewText', () {
    test('a result-list preview does not flatten the gloss', () {
      expect(versePreviewText('这是主[雅伟]所做的'), '这是主[雅伟]所做的');
      expect(versePreviewText('These [are] their genealogies'),
          'These are their genealogies');
      expect(versePreviewText(null), isNull);
    });
  });

  group('reuniteGlossRuns', () {
    test('a gloss split across two runs goes back to the run that '
        'opened it, and takes no Strong\'s with it', () {
      // Verbatim from assets/tagged/cuvs-yhwh/matthew.json 2:13. G32 is
      // ἄγγελος: the tagger gave the divine name the number of the word
      // that happened to follow it, so hovering 雅伟 answered "angel".
      final out = TaggedTextService.reuniteGlossRuns([
        run('有主 [', 'G2962'),
        run('雅伟] 的使者', 'G32'),
      ]);
      expect(out, hasLength(2));
      expect(out[0].text, '有主[雅伟]');
      expect(out[0].strongs, 'G2962');
      expect(out[1].text, '的使者');
      expect(out[1].strongs, 'G32');
    });

    test('an unsplit gloss just loses the importer\'s spacing', () {
      final out = TaggedTextService.reuniteGlossRuns([
        run('主 [雅伟] ', 'G2962'),
        run('的道', 'G3598'),
      ]);
      expect(out[0].text, '主[雅伟]');
      expect(out[1].text, '的道');
    });

    test('a bracket spanning REAL words is left alone', () {
      // LXX/WH marks doubtful text as `[το αυτο]` and every word inside
      // is a genuine word with a genuine number. Reuniting these would
      // destroy tagging rather than repair it — which is why the rule
      // is keyed to a closed token set and not to bracket shape.
      final input = [
        run(' [το', 'G3588'),
        run(' αυτο]', 'G846'),
        run(' πνευματικον', 'G4152'),
      ];
      final out = TaggedTextService.reuniteGlossRuns(input);
      expect(out.map((r) => r.text).toList(),
          [' [το', ' αυτο]', ' πνευματικον']);
      expect(out.map((r) => r.strongs).toList(), ['G3588', 'G846', 'G4152']);
    });

    test('English spacing around a bracket survives', () {
      final out = TaggedTextService.reuniteGlossRuns([
        run('These [are] ', 'H428'),
        run('their genealogies', 'H8435'),
      ]);
      expect(out[0].text, 'These [are] ');
    });

    test('runs with no bracket are returned as-is', () {
      final input = [run('亚伯拉罕', 'G11'), run('的后裔，', 'G5207')];
      expect(identical(TaggedTextService.reuniteGlossRuns(input), input),
          isTrue);
    });
  });

  group('KWIC', () {
    test('the keyword column holds the word, not an orphan bracket', () {
      // What the screenshot showed: `主 [` in the keyword column and
      // `雅伟]` starting the right context, printed with the column gap
      // between them — the `主 [ 雅伟]` the user reported.
      final lines = kwicLinesForVerse(
        reference: '马太福音 2:13',
        runs: TaggedTextService.reuniteGlossRuns([
          run('他们去后，', 'G1161'),
          run('有主 [', 'G2962'),
          run('雅伟] 的使者', 'G32'),
        ]),
        strongs: 'G2962',
      );
      expect(lines, hasLength(1));
      expect(lines.single.keyword, '有主[雅伟]');
      expect(lines.single.right, '的使者');
    });
  });

  group('what actually gets painted', () {
    // The parsing tests above prove the KIND. This proves the render
    // contract that follows from it, which is the half a reader sees.
    testWidgets('the Name prints bracketed and upright', (tester) async {
      final wb = WbColors.light;
      final spans = <InlineSpan>[
        for (final s in parseScripture('有主[雅伟]的使者'))
          if (s.kind == ScriptureSpanKind.divineName ||
              s.kind == ScriptureSpanKind.gloss)
            glossSpan(s, wb)
          else
            TextSpan(
              text: s.text,
              style: s.kind == ScriptureSpanKind.supplied
                  ? const TextStyle(fontStyle: FontStyle.italic)
                  : null,
            ),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Text.rich(TextSpan(children: spans))),
      ));

      final root = tester.widget<Text>(find.byType(Text)).textSpan!;
      // The brackets survive to the screen: without them the line reads
      // 有主雅伟, a title the verse does not contain.
      expect(root.toPlainText(), '有主[雅伟]的使者');

      final italics = <String>[];
      final bracketColours = <Color?>[];
      root.visitChildren((s) {
        if (s is! TextSpan) return true;
        if (s.style?.fontStyle == FontStyle.italic) {
          italics.add(s.text ?? '');
        }
        if (s.text == '[' || s.text == ']') bracketColours.add(s.style?.color);
        return true;
      });
      // Nothing here is a translator's insertion, so nothing is italic.
      expect(italics, isEmpty);
      // Brackets are apparatus, the Name is text.
      expect(bracketColours, [wb.mutedText, wb.mutedText]);
    });
  });

  group('the shipped assets', () {
    // These are the tests that would have caught it. The two above run
    // on strings a human typed; the bug was in a file an importer wrote.

    test('no tagged cuvs-yhwh run is left holding half a gloss', () async {
      final dir = Directory('assets/tagged/cuvs-yhwh');
      expect(dir.existsSync(), isTrue);
      final offenders = <String>[];
      var glossRuns = 0;
      for (final f in dir.listSync().whereType<File>()) {
        final book = json.decode(f.readAsStringSync()) as Map<String, dynamic>;
        for (final entry in book.entries) {
          final runs = TaggedTextService.reuniteGlossRuns([
            for (final r in entry.value as List)
              TaggedRun.fromJson(r as Map<String, dynamic>),
          ]);
          for (final r in runs) {
            if (r.text.contains('[') != r.text.contains(']')) {
              offenders.add('${f.path} ${entry.key}: "${r.text}"');
            }
            if (r.text.contains('[雅伟]')) glossRuns++;
          }
        }
      }
      expect(offenders, isEmpty);
      // 212 in the base text; a handful of verses carry two.
      expect(glossRuns, greaterThan(200));
    });

    test('no run ever OPENS with a gloss', () async {
      // The invariant, stated structurally rather than lexically. An
      // earlier draft asserted the run must carry G2962 and the assets
      // refuted it in twelve places: the bracket glosses whatever word
      // precedes it, and that word is δεσπότης (G1203) at Jude 1:4 and
      // Revelation 6:10, θεός at Acts 16:32, and a preposition phrase
      // that swallowed the 主 at Romans 4:17. All correct. What is
      // never correct is a gloss standing at the HEAD of a run, because
      // then its number belongs to a word printed AFTER it — which is
      // the whole defect.
      final dir = Directory('assets/tagged/cuvs-yhwh');
      final orphans = <String>[];
      for (final f in dir.listSync().whereType<File>()) {
        final book = json.decode(f.readAsStringSync()) as Map<String, dynamic>;
        for (final entry in book.entries) {
          final runs = TaggedTextService.reuniteGlossRuns([
            for (final r in entry.value as List)
              TaggedRun.fromJson(r as Map<String, dynamic>),
          ]);
          for (final r in runs) {
            if (r.text.trimLeft().startsWith(']') ||
                r.text.trimLeft().startsWith('雅伟]')) {
              orphans.add('${f.path} ${entry.key}: "${r.text}"');
            }
          }
        }
      }
      expect(orphans, isEmpty, reason: orphans.take(10).join('\n'));
    });

    test('and the raw asset really does violate that, so the fix bites',
        () async {
      // The premise. If the importer is ever re-run and stops splitting
      // the gloss, this test fails and says so, instead of the repair
      // above quietly becoming a no-op nobody notices.
      final raw = json.decode(
              File('assets/tagged/cuvs-yhwh/matthew.json').readAsStringSync())
          as Map<String, dynamic>;
      final before = [
        for (final r in raw['2:13'] as List)
          TaggedRun.fromJson(r as Map<String, dynamic>),
      ];
      expect(before.any((r) => r.text.endsWith('[')), isTrue);
      final split = before.firstWhere((r) => r.text.startsWith('雅伟]'));
      expect(split.strongs, 'G32'); // ἄγγελος — the wrong answer

      final after = TaggedTextService.reuniteGlossRuns(before);
      final glossed = after.firstWhere((r) => r.text.contains('[雅伟]'));
      expect(glossed.text, '有主[雅伟]');
      expect(glossed.strongs, 'G2962'); // κύριος — the right one
      expect(after.any((r) => r.text.startsWith('雅伟]')), isFalse);
    });

    test('normalisation leaves every other tagged version untouched',
        () async {
      for (final version in ['bsb', 'kjvs', 'lxxwh', 'cuvs-plus']) {
        final dir = Directory('assets/tagged/$version');
        if (!dir.existsSync()) continue;
        for (final f in dir.listSync().whereType<File>()) {
          final book =
              json.decode(f.readAsStringSync()) as Map<String, dynamic>;
          for (final entry in book.entries) {
            final before = [
              for (final r in entry.value as List)
                TaggedRun.fromJson(r as Map<String, dynamic>),
            ];
            final after = TaggedTextService.reuniteGlossRuns(before);
            expect(after.map((r) => r.text).toList(),
                before.map((r) => r.text).toList(),
                reason: '$version ${f.path} ${entry.key}');
          }
        }
      }
    });
  });
}
