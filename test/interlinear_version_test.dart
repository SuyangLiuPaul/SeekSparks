/// 2026-09-08 (SeekSparks): the Exegesis panel's interlinear and the
/// picker that chooses its edition.
///
/// 「这个原文的时候现在是一个个单词翻译 但是我想好像微读圣经一样可以选译本
/// 我提供这么多 然后这样看也容易些」. Four things are worth pinning and
/// they are the four groups below: which editions may be offered, what
/// happens to a reader whose own Bible has none, that the line actually
/// renders the asset's own words and numbers, and that it survives a
/// phone.
///
/// The Genesis 1:2 expectations were read off `assets/tagged/cuvs-yhwh/
/// genesis.json` by hand before they were written here, run by run, and
/// they match what 精读圣经 prints for the same verse:
///
///     地<0776>是<01961>空虚<08414>混沌<0922>，渊<08415>面<06440>黑暗<02822>；
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/word_study_style.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/tagged_text_service.dart';
import 'package:seeksparks/utils/interlinear_editions.dart';
import 'package:seeksparks/widgets/interlinear_verse_text.dart';
import 'package:seeksparks/widgets/originals_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the picker offers the tagged editions that actually ship', () {
    test('it lists exactly the six, in catalog order', () {
      // 2026-09-08: five became seven. `bsb-yhwh` and `asv-yhwh` are
      // tagged and visible, so `interlinearEditions` — which is
      // `availableVersions` intersected with
      // `TaggedTextService.taggedVersions` — picks them up with no code
      // change at all. Written out in full rather than derived, because
      // the thing worth pinning is the ORDER a reader sees, and that
      // comes from the catalog rather than from either input set.
      //
      // 2026-09-08, later the same day: seven became SIX. `bsb` led
      // this list and was dropped when it joined `disabledVersions`
      // (「bsbs 不用，就 bsb yahweh 版本导入」) — again with no code
      // change, which is the intersection earning its keep twice in one
      // day. `assets/tagged/bsb/` is untouched and still loads; see
      // `test/bsb_tagged_test.dart`. Note that `bsb-yhwh` does NOT take
      // the vacated first position: it stays where the catalog puts it,
      // after `kjvs`.
      expect(interlinearEditions, <String>[
        'csb',
        'kjvs',
        'bsb-yhwh',
        'asv-yhwh',
        'lxxwh',
        'cuvs-yhwh',
      ]);
    });

    test('nsn-plus is never offered, because the app does not contain it', () {
      // `assets/tagged/nsn-plus/` exists on a developer's disk, is
      // gitignored, and is in no build. A picker row for it would open
      // an asset the shipped app has never had.
      expect(interlinearEditions, isNot(contains('nsn-plus')));
      expect(TaggedTextService.taggedVersions, isNot(contains('nsn-plus')));
    });

    test('cuvs-plus is tagged and bundled and is still not offered', () {
      // The one that only the intersection catches: it IS in
      // taggedVersions, so a list built from tagging alone would show
      // it. 「有雅+ 就不用和合本+了」 — it is hidden everywhere else in
      // the app and must be hidden here by the same decision, not by a
      // second copy of it.
      expect(TaggedTextService.taggedVersions, contains('cuvs-plus'));
      expect(disabledVersions, contains('cuvs-plus'));
      expect(interlinearEditions, isNot(contains('cuvs-plus')));
    });

    test('every offered edition is one a reader can also read', () {
      final available = availableVersions.map((v) => v.value).toSet();
      for (final code in interlinearEditions) {
        expect(available, contains(code));
        expect(TaggedTextService.supports(code), isTrue);
      }
    });
  });

  group('which edition the panel opens on', () {
    test('a reader on a tagged Bible gets their own', () {
      // 2026-09-08: was `bsb`, which is hidden now and therefore not
      // "a tagged Bible a reader can be on" any more. `bsb-yhwh` is
      // tagged, visible, and the English edition that replaced it.
      final choice = resolveInterlinearEdition(currentVersion: 'bsb-yhwh');
      expect(choice.version, 'bsb-yhwh');
      expect(choice.source, InterlinearSource.current);
    });

    test('a reader on an untagged Chinese Bible is given the tagged one',
        () {
      // 梁家铿译本 ships no alignment; 和合本雅伟版(简体) is the tagged
      // edition in the same script.
      final choice = resolveInterlinearEdition(currentVersion: 'biblexg-v2');
      expect(choice.version, 'cuvs-yhwh');
      expect(choice.source, InterlinearSource.substituted,
          reason: 'the panel has to say this out loud');
    });

    test('a 繁體 reader is given the simplified tagging, not English', () {
      // There is no traditional tagged set and no 简→繁 converter. The
      // wrong answer here is BSB, which is what a strict language match
      // would return.
      final choice =
          resolveInterlinearEdition(currentVersion: 'cuvs-yhwh-tr');
      expect(choice.version, 'cuvs-yhwh');
      expect(choice.source, InterlinearSource.substituted);
    });

    test('an untagged English Bible gets an English tagged one', () {
      // 2026-09-08, and it took two passes. `bsb` held this slot;
      // hiding it handed the slot to `csb` on catalog order alone,
      // which meant an English reader who had chosen nothing was
      // quietly given a LICENSED text, copy-capped at 500 verses, in
      // the same change that made the public-domain Yahweh editions
      // this app's defaults. Nobody decided that — catalog order did.
      //
      // The substitute now asks [localeDefaultVersion] first. That is
      // not the hand-ordered ranking `interlinear_editions.dart`
      // rejects: it is a decision the catalog already makes, in one
      // place, about which edition a reader of a given language gets
      // when they have expressed no preference — the same question
      // being asked here. Only English moves; Chinese was already
      // getting `cuvs-yhwh` out of catalog order.
      final choice = resolveInterlinearEdition(currentVersion: 'kjv');
      expect(choice.version, 'bsb-yhwh');
      expect(choice.version, localeDefaultVersion('en'),
          reason: 'the substitute must track the locale default rather '
              'than restate it, or the two drift');
      expect(choice.source, InterlinearSource.substituted);
    });

    test("the reader's own pick beats the Bible they are reading", () {
      final choice = resolveInterlinearEdition(
          chosen: 'cuvs-yhwh', currentVersion: 'bsb');
      expect(choice.version, 'cuvs-yhwh');
      expect(choice.source, InterlinearSource.chosen);
    });

    test('a stored pick for an edition that has since been hidden lapses',
        () {
      // `cuvs-plus` was offerable until it was disabled today. A reader
      // who picked it then must not be shown a blank panel now.
      //
      // 2026-09-08: the Bible being read was `bsb`, which is now hidden
      // itself — that would have tested two lapses at once and told us
      // which neither. `bsb-yhwh` is a live tagged edition, so the only
      // thing lapsing here is the stored pick.
      final choice = resolveInterlinearEdition(
          chosen: 'cuvs-plus', currentVersion: 'bsb-yhwh');
      expect(choice.version, 'bsb-yhwh');
      expect(choice.source, InterlinearSource.current);
      // ...and `bsb` is now a second stored pick that has to lapse the
      // same way, for the same reason and by the same one line of code.
      final afterBsb = resolveInterlinearEdition(
          chosen: 'bsb', currentVersion: 'bsb-yhwh');
      expect(afterBsb.version, 'bsb-yhwh');
      expect(afterBsb.source, InterlinearSource.current);
    });
  });

  group('Genesis 1:2 renders the words and numbers the asset holds', () {
    late List<TaggedRun> runs;

    setUpAll(() async {
      runs = (await TaggedTextService.forVerse(
        version: 'cuvs-yhwh',
        englishBook: 'Genesis',
        chapter: 1,
        verse: 2,
      ))!;
    });

    Future<void> pumpLine(
      WidgetTester tester, {
      bool showNumbers = true,
      String? highlight,
      void Function(TaggedRun)? onTapRun,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return InterlinearVerseText(
              runs: runs,
              style: WordStudyStyle.resolve(
                embedded: false,
                scheme: Theme.of(context).colorScheme,
                wb: WbColors.of(context),
                type: WbType.of(context),
              ),
              showNumbers: showNumbers,
              highlightStrongs: highlight,
              onTapRun: onTapRun,
            );
          }),
        ),
      )));
    }

    testWidgets('the twelve runs are the twelve the file records',
        (tester) async {
      // Read off the asset by hand: 地/是/空虚/混沌，/渊/面/黑暗；/神的/
      // 灵/运行/在水/面上。
      expect(runs.map((r) => r.text).toList(), <String>[
        '地', '是', '空虚', '混沌，', '渊', '面',
        '黑暗；', '神的', '灵', '运行', '在水', '面上。',
      ]);
      expect(runs.map((r) => r.strongs).toList(), <String>[
        'H776', 'H1961', 'H8414', 'H922', 'H8415', 'H6440',
        'H2822', 'H430', 'H7307', 'H7363', 'H4325', 'H5921',
      ]);
      await pumpLine(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each word carries its own number, in reading order',
        (tester) async {
      await pumpLine(tester);
      // The whole point of the feature: the sentence is readable as a
      // sentence, and every word states the lemma behind it.
      for (final pair in const [
        ('地', 'H776'),
        ('是', 'H1961'),
        ('空虚', 'H8414'),
        ('渊', 'H8415'),
        ('黑暗', 'H2822'),
      ]) {
        expect(find.textContaining(pair.$1, findRichText: true), findsWidgets,
            reason: 'the word ${pair.$1} should be on screen');
        expect(find.textContaining(pair.$2, findRichText: true), findsWidgets,
            reason: '${pair.$1} should carry ${pair.$2}');
      }
    });

    testWidgets("the comma baked into 混沌， prints after the number",
        (tester) async {
      // `splitTrailingCjkPunctuation`: the CUV's own comma has no
      // Hebrew behind it, so 混沌 H922， is right and 混沌，H922 is a
      // number that appears to tag a comma.
      await pumpLine(tester);
      final text = _renderedText(tester);
      expect(text, contains('混沌 H922'));
      expect(text, isNot(contains('混沌，H922')));
    });

    testWidgets('the grammar code on 是 prints beside its lexical number',
        (tester) async {
      // H1961 is הָיָה; H8804 is the perfect stem. Two different kinds
      // of fact, and the line has to carry both.
      expect(runs[1].grammar, <String>['H8804']);
      await pumpLine(tester);
      expect(_renderedText(tester), contains('是 H1961 H8804'));
    });

    testWidgets('an implied number is parenthesised, never bare',
        (tester) async {
      // 面 renders H6440 (פָּנִים); the H5921 (עַל) beside it is in the
      // Hebrew and not in the Chinese, so it may not read as this
      // word's own identity.
      expect(runs[5].implied, <String>['H5921']);
      await pumpLine(tester);
      final text = _renderedText(tester);
      expect(text, contains('(H5921)'));
      expect(text, contains('面 (H5921) H6440'));
    });

    testWidgets('turning Strong\'s numbers off leaves the sentence whole',
        (tester) async {
      await pumpLine(tester, showNumbers: false);
      final text = _renderedText(tester);
      expect(text, contains('地'));
      expect(text, contains('黑暗'));
      expect(text, isNot(contains('H776')));
    });

    testWidgets('tapping a run reports that run, number and all',
        (tester) async {
      TaggedRun? tapped;
      await pumpLine(tester, onTapRun: (r) => tapped = r);
      await tester.tap(find.textContaining('空虚', findRichText: true).first);
      await tester.pump();
      expect(tapped, isNotNull);
      expect(tapped!.strongs, 'H8414');
    });

    testWidgets('the highlighted number is marked wherever it renders',
        (tester) async {
      // H5921 (עַל) is the last run's own number AND the implied number
      // on 面. Only the run that RENDERS it may be marked.
      await pumpLine(tester, highlight: 'H5921');
      final marked = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(InterlinearVerseText),
            matching: find.byType(Container),
          ))
          .where((c) => c.decoration != null)
          .length;
      expect(marked, 1);
    });
  });

  group('the panel on a phone', () {
    const verses = [
      Verse(book: 'Genesis', chapter: 1, verse: 2, text: '地是空虚混沌'),
    ];

    Future<void> pumpPanel(WidgetTester tester, double width,
        {String currentVersion = 'cuvs-yhwh', String chosen = ''}) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 780);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) {
            final s = AppSettings();
            if (chosen.isNotEmpty) s.setInterlinearVersion(chosen);
            return s;
          },
          child: MaterialApp(
            home: Scaffold(
              body: OriginalsSheet(
                verses: verses,
                locale: 'zh-Hans',
                currentVersion: currentVersion,
                embedded: true,
              ),
            ),
          ),
        ),
      );
      // The panel reads three asset families off disk (originals,
      // Strong's, tagged). Those are real file I/O, so they need
      // `runAsync` — a fixed pump advances the fake clock and never
      // lets them land, and `pumpAndSettle` never returns because the
      // spinner they are behind animates forever.
      // Interleaved rather than one long wait: the loads are a CHAIN
      // (originals → Strong's glosses → the tagged edition, each
      // started by the frame the previous one landed in), so real time
      // has to be given back between pumps or only the first link
      // resolves.
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
      }
      // AppSettings debounces its settings write-back; without letting
      // that timer fire the test tears down with one pending.
      await tester.pump(const Duration(seconds: 1));
    }

    // 375 is the iPhone SE / 13 mini and the narrowest phone the app
    // supports; 402 is the iPhone 16. The app was found to have layout
    // defects visible only between them.
    //
    // Both editions, because the label lengths are not comparable and
    // the short one proves nothing: 「和合本雅伟版(简体)」 is nine
    // glyphs and fits beside its own caption at 375 pt whatever the
    // row is built out of, while "Berean Standard Bible · 2020 /
    // public domain" is 42 characters and is the string that actually
    // decides whether the control row can be a Row. It cannot.
    for (final width in const [375.0, 390.0, 402.0]) {
      // 2026-09-08: was `'bsb'`. The English member of this pair is
      // here for its LABEL LENGTH (see the note above), and a chosen
      // code that is no longer offerable would lapse to `csb` and
      // quietly stop testing the long string. `bsb-yhwh`'s label is
      // longer still.
      for (final chosen in const ['cuvs-yhwh', 'bsb-yhwh']) {
        testWidgets('lays out $chosen with no overflow at ${width.toInt()} pt',
            (tester) async {
          addTearDown(tester.view.reset);
          await pumpPanel(tester, width, chosen: chosen);
          expect(tester.takeException(), isNull);
          expect(find.byType(InterlinearVerseText), findsOneWidget);
        });
      }
    }

    testWidgets('the picker opens and lists every offered edition',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpPanel(tester, 375);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (final code in interlinearEditions) {
        expect(find.text(fullBibleVersionLabel(code)), findsWidgets,
            reason: '$code should be a row in the menu');
      }
      expect(find.text(fullBibleVersionLabel('cuvs-plus')), findsNothing);
    });

    testWidgets('a reader on an untagged Bible is told whose text this is',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpPanel(tester, 375, currentVersion: 'biblexg-v2');
      // Nothing narrows in silence: both editions named, in the
      // reader's own locale.
      expect(
          find.textContaining(fullBibleVersionLabel('biblexg-v2'),
              findRichText: true),
          findsWidgets);
      expect(find.textContaining('没有原文编号对照', findRichText: true),
          findsOneWidget);
    });

    testWidgets("the reader's own pick is what the panel opens on",
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpPanel(tester, 375,
          currentVersion: 'cuvs-yhwh', chosen: 'bsb-yhwh');
      // Their Bible is tagged and would have been the default; the
      // pick overrides it, and the panel says so by name.
      // 2026-09-08: was `'bsb'`, which no longer survives the
      // "still offerable" gate and so could not demonstrate a pick
      // WINNING over anything.
      expect(find.text(fullBibleVersionLabel('bsb-yhwh')), findsOneWidget);
      expect(find.text(fullBibleVersionLabel('cuvs-yhwh')), findsNothing);
    });
  });

  group('the pick outlives the panel', () {
    test('it is written to disk and read back', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final first = AppSettings();
      expect(first.interlinearVersion, '',
          reason: 'never picked means follow the Bible being read');
      await first.setInterlinearVersion('kjvs');

      final second = AppSettings();
      await second.loadSettings();
      expect(second.interlinearVersion, 'kjvs');
    });
  });
}

/// Every string the widget tree actually painted, joined in tree order.
///
/// `find.text` cannot see inside a `TextSpan` tree, and the assertions
/// that matter here are about ADJACENCY — that a number lands between a
/// word and its comma, that an implied number keeps its parentheses.
String _renderedText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join(' ');
