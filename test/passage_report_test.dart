/// The Report Generator's shaping half — bwh28,
/// `docs/PARITY-BACKLOG.md` §3.5, whose entry read: *"a genuinely good
/// idea we have all the parts for … and no assembly."*
///
/// The assertions worth having are about the two things a report can get
/// wrong in a way nobody notices: **a filtered list that looks like a
/// short passage**, and **a gloss borrowed from a word that is not the
/// one printed**.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/passage_report.dart';

ReportWord word(
  String surface, {
  String strongs = 'H1',
  String? gloss,
  String? parse,
  String? pos,
  int? count,
}) =>
    ReportWord(
      surface: surface,
      strongs: strongs,
      gloss: gloss,
      parse: parse,
      pos: pos,
      corpusCount: count,
    );

PassageReport report(
  List<ReportVerse> verses, {
  ReportOptions options = const ReportOptions(),
  int before = 0,
  String? licence,
}) =>
    PassageReport(
      title: 'Genesis 1:1',
      versionLabel: 'KJV',
      verses: verses,
      options: options,
      licence: licence,
      wordsBeforeFilter: before,
    );

void main() {
  test('every string the sheet and the menu need exists', () {
    for (final k in const [
      'reportTitle',
      'reportVerseText',
      'reportWords',
      'reportParsing',
      'reportFrequency',
      'reportRarity',
      'reportEveryWord',
      'reportWordCount',
      'copiedPlain',
    ]) {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final v = uiStrings[k]?[locale];
        expect(v, isNotNull, reason: '$k [$locale]');
        expect((v as String).trim(), isNotEmpty, reason: '$k [$locale]');
      }
    }
    for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
      expect(uiStrings['reportWordCount']![locale]!, contains('{n}'),
          reason: locale);
    }
  });

  group('the filters are the feature', () {
    final words = [
      word('and', strongs: 'H9999', count: 50000, pos: 'C'),
      word('beginning', strongs: 'H7225', count: 51, pos: 'N'),
      word('created', strongs: 'H1254', count: 48, pos: 'V'),
    ];

    test('the default is a rare-word report, not everything', () {
      // A report on Romans 8 that prints a lexicon entry for every καί
      // is a phone book. The default keeps what a reader works from.
      final kept = filterWords(words, const ReportOptions());
      expect(kept.map((w) => w.surface), ['created']);
    });

    test('rarerThan 0 turns the filter off', () {
      expect(
        filterWords(words, const ReportOptions(rarerThan: 0)).length,
        3,
      );
    });

    test('a word we could not count is KEPT', () {
      // The filter promises "the rare ones". Dropping a word because the
      // concordance had no entry would answer a different question, and
      // answer it silently.
      final kept = filterWords(
        [word('x', strongs: 'H0', count: null)],
        const ReportOptions(rarerThan: 10),
      );
      expect(kept, hasLength(1));
    });

    test('part of speech narrows independently', () {
      final kept = filterWords(
        words,
        const ReportOptions(rarerThan: 0, partsOfSpeech: {'N', 'V'}),
      );
      expect(kept.map((w) => w.surface), ['beginning', 'created']);
    });

    test('a word with no parse cannot satisfy a part-of-speech filter', () {
      expect(
        filterWords(
          [word('x', pos: null, count: 1)],
          const ReportOptions(partsOfSpeech: {'N'}),
        ),
        isEmpty,
      );
    });
  });

  group('a filtered list must not read as a short passage', () {
    test('both renderers say how many of how many', () {
      // The defect this guards: 3 words printed from a chapter of 700,
      // with nothing on the page to say so, reads as a report on a
      // passage that has three words in it.
      final r = report(
        [
          ReportVerse(
            reference: 'Genesis 1:1',
            text: 'In the beginning',
            words: [word('created', count: 48)],
          )
        ],
        before: 7,
      );
      expect(reportToMarkdown(r), contains('1 of 7 words'));
      expect(reportToHtml(r), contains('1 of 7 words'));
    });

    test('and say nothing when nothing was filtered', () {
      final r = report(
        [
          ReportVerse(
            reference: 'Genesis 1:1',
            text: 'In the beginning',
            words: [word('created', count: 48)],
          )
        ],
        before: 1,
      );
      expect(reportToMarkdown(r), isNot(contains('of 1 words')));
    });
  });

  group('nothing is invented', () {
    test('a word the lexicon does not know prints no gloss', () {
      // Not an empty dash, and above all not the neighbour's gloss.
      final r = report([
        ReportVerse(reference: 'Gen 1:1', text: 't', words: [
          word('א', strongs: 'H9999', gloss: null, count: 1),
        ])
      ], options: const ReportOptions(rarerThan: 0));
      final md = reportToMarkdown(r);
      expect(md, contains('H9999'));
      expect(md, isNot(contains('—')));
    });

    test('the licence travels with the text', () {
      // A report is the moment publisher text lands on someone else's
      // page — the same reason `version_attribution.dart` exists for the
      // clipboard.
      final r = report(
        [ReportVerse(reference: 'Gen 1:1', text: 't')],
        licence: 'Used by permission.',
      );
      expect(reportToMarkdown(r), contains('Used by permission.'));
      expect(reportToHtml(r), contains('Used by permission.'));
    });

    test('and is simply absent when the edition has none', () {
      final r = report([ReportVerse(reference: 'Gen 1:1', text: 't')]);
      expect(reportToMarkdown(r), isNot(contains('---')));
      expect(reportToHtml(r), isNot(contains('<hr>')));
    });
  });

  group('the HTML is a fragment that survives a paste', () {
    test('no document wrapper — it is going INTO a page', () {
      final html = reportToHtml(
          report([ReportVerse(reference: 'Gen 1:1', text: 'x')]));
      expect(html, isNot(contains('<html')));
      expect(html, isNot(contains('<body')));
      expect(html, startsWith('<h1>'));
    });

    test('markup in the text is escaped, not rendered', () {
      // A verse containing `<` is rare in scripture and certain in a
      // user note or a Chinese edition's `<note:>` residue. Pasting a
      // report that swallowed the rest of the passage into a stray tag
      // is a silent loss.
      final html = reportToHtml(report([
        ReportVerse(reference: 'Gen 1:1', text: 'a < b & c > d'),
      ]));
      expect(html, contains('a &lt; b &amp; c &gt; d'));
    });

    test('styles are inline, because a class name means nothing there', () {
      final html = reportToHtml(
        report(
          [
            ReportVerse(reference: 'Gen 1:1', text: 't', words: [
              word('x', count: 3, parse: 'noun')
            ])
          ],
          before: 9,
        ),
      );
      expect(html, contains('style="color:#666"'));
      expect(html, isNot(contains('class=')));
    });
  });

  group('what each option actually removes', () {
    final v = ReportVerse(
      reference: 'Gen 1:1',
      text: 'In the beginning',
      words: [word('בָּרָא', count: 48, parse: 'verb qal perfect')],
    );

    test('verse text off leaves the words', () {
      final md = reportToMarkdown(report([v],
          options: const ReportOptions(verseText: false, rarerThan: 0)));
      expect(md, isNot(contains('In the beginning')));
      expect(md, contains('בָּרָא'));
    });

    test('morphology off drops the parse but not the count', () {
      final md = reportToMarkdown(report([v],
          options: const ReportOptions(morphology: false, rarerThan: 0)));
      expect(md, isNot(contains('verb qal perfect')));
      expect(md, contains('×48'));
    });

    test('frequency off drops the count but not the parse', () {
      final md = reportToMarkdown(report([v],
          options: const ReportOptions(frequency: false, rarerThan: 0)));
      expect(md, contains('verb qal perfect'));
      expect(md, isNot(contains('×48')));
    });
  });
}
