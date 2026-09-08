/// 2026-09-08 (SeekSparks): the two refusals a parser cannot make on its
/// own, and the one operator that is still refused on purpose.
///
/// `regex_query_corpus_test.dart` proves the `~` engine answers
/// correctly. This proves the two things only `WorkbenchProvider` can
/// know — that a search is over budget, and that a `~` group is sitting
/// inside a compound — reach the reader as a sentence rather than as an
/// empty list. Every one of these lines is the same failure shape the
/// `@` gate was built against: a list of nothing that reads as an answer.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/command_examples.dart';
import 'package:seeksparks/utils/command_query.dart';

const _seed = [
  Verse(
      book: 'Genesis',
      chapter: 1,
      verse: 1,
      text: 'In the beginning God created the heaven and the earth.'),
  Verse(
      book: 'Genesis',
      chapter: 1,
      verse: 3,
      text: 'And God said, Let there be light: and there was light.'),
  Verse(
      book: 'John',
      chapter: 3,
      verse: 16,
      text: 'For God so loved the world, that he gave his only begotten Son.'),
];

MainProvider _mp() => MainProvider()..setVerses(_seed);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a ~ line reaches the engine and comes back with an echo', () {
    test('the manual\'s example runs and names the verse it found', () async {
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('~And God said');
      expect(wb.commandIssue, isNull);
      expect(wb.commandQuery?.kind, CommandKind.regex);
      expect([for (final v in wb.textResults) '${v.book} ${v.verse}'],
          ['Genesis 3']);
      wb.dispose();
    });

    test('case is the whole difference between two ~ searches', () async {
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('~God');
      expect(wb.textResults.length, 3);
      await wb.runSearch('~god');
      expect(wb.textResults, isEmpty);
      // And not because the line failed: it ran and found nothing, which
      // is a true answer about this three-verse corpus.
      expect(wb.commandIssue, isNull);
      wb.dispose();
    });
  });

  group('the refusals that a parser cannot make', () {
    test('a ~ group inside a compound is refused by name', () async {
      // The pattern parses — `compound_query_test.dart` pins that — so
      // without this gate the compound would run the group, hand back a
      // verse list, and have nowhere to report a budget refusal. "No
      // verse matched (~b)" is the one thing that would not be true.
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('(.god).(~light)');
      expect(wb.commandIssue, CommandIssue.regexUnsupportedHere);
      expect(wb.textResults, isEmpty);
      wb.dispose();
    });

    test('a pattern over the step budget is refused, not half-run', () async {
      // Three verses is not enough corpus to exceed 600 M steps, so the
      // budget is exercised where it actually lives: a program too big
      // for `kMaxRegexProgram` is refused at compile time, and one whose
      // ceiling exceeds the budget is refused before the scan. The
      // corpus-sized case is in `regex_query_corpus_test.dart`; what is
      // checked here is that the provider turns the flag into a sentence
      // rather than into an empty result list.
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('~${'a' * (kMaxRegexProgram + 1)}');
      expect(wb.commandIssue, CommandIssue.regexTooComplex);
      expect(wb.textResults, isEmpty);
      wb.dispose();
    });

    test('every ~ refusal has a finished sentence for the reader', () {
      for (final issue in <CommandIssue>[
        CommandIssue.regexSyntax,
        CommandIssue.regexUnsupportedOperator,
        CommandIssue.regexTooComplex,
        CommandIssue.regexTooCostly,
        CommandIssue.regexUnsupportedHere,
      ]) {
        for (final locale in <String>['en', 'zh-Hans', 'zh-Hant']) {
          final s = describeCommandIssue(issue, locale);
          expect(s, isNotNull, reason: '$issue in $locale');
          expect(s, isNotEmpty, reason: '$issue in $locale');
          expect(s, isNot(contains('{')), reason: '$issue in $locale');
        }
      }
    });
  });

  group('the ? card offers the operator, and the offer runs', () {
    test('the ~ row prefills a pattern that parses, in all three locales',
        () {
      // `command_operator_strip_test.dart` sweeps the card's other rows
      // against their parsers by name; this row arrived after that list
      // was written, and a card line that does not run is the defect
      // #299 was raised about.
      for (final locale in <String>['en', 'zh-Hans', 'zh-Hant']) {
        final line = splitSyntaxLine(uiStrings['cmdSyntaxRegex']![locale]!);
        expect(line.runnable, isNotNull, reason: locale);
        final parse = parseCommandQuery(line.runnable!);
        expect(parse.query?.kind, CommandKind.regex, reason: locale);
      }
    });
  });

  group('= is still refused, and the refusal finally says what for', () {
    test('the operator is named, not silently searched as text', () async {
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('=.faith works');
      expect(wb.commandIssue, CommandIssue.fuzzyUnsupported);
      expect(wb.textResults, isEmpty);
      wb.dispose();
    });

    test('the sentence names link stemming and offers the wildcard line', () {
      // bwh16 binds `=` to LINK stemming and to nothing else — Porter is
      // a right-click mode there, never a control character — so the old
      // wording ("fuzzy stemming searches are not supported") named a
      // feature the operator does not have. The new one names the real
      // obstacle (a hand-edited proprietary word list) and the line that
      // does the same job, which is exactly what BibleWorks' own Porter
      // mode rewrites a query into: `.faith* work*`.
      for (final locale in <String>['en', 'zh-Hans', 'zh-Hant']) {
        final s = describeCommandIssue(CommandIssue.fuzzyUnsupported, locale)!;
        expect(s, contains('.faith* work*'), reason: locale);
      }
      expect(describeCommandIssue(CommandIssue.fuzzyUnsupported, 'en'),
          contains('link-stemming'));
    });
  });
}
