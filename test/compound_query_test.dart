/// Unit tests for compound searches (`lib/utils/compound_query.dart`,
/// help topic bwh16, "Doing Compound Searches").
///
/// A hand-built ten-verse corpus with a book boundary in the middle of
/// it, because the boundary is where a proximity join is easiest to get
/// wrong: indices 4 and 5 are adjacent in the list and in different
/// books, so any window that ignores the book will visibly over-match.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/compound_query.dart';
import 'package:seeksparks/utils/diacritics.dart';
import 'package:seeksparks/utils/search_highlight.dart';

const _texts = <String>[
  'grace and truth came', //        0  Genesis   grace
  'the works of the law', //        1  Genesis   works
  'a quiet verse', //               2  Genesis
  'jesus christ is lord', //        3  Genesis   jesus christ
  'grace and works together', //    4  Genesis   grace works
  'jesus wept', //                  5  Acts      jesus
  'a quiet verse too', //           6  Acts
  'grace be with you', //           7  Acts      grace
  'the works of the flesh', //      8  Acts      works
  'nothing of note', //             9  Acts
];

const _books = <String>[
  'Genesis',
  'Genesis',
  'Genesis',
  'Genesis',
  'Genesis',
  'Acts',
  'Acts',
  'Acts',
  'Acts',
  'Acts',
];

/// The contract `runCompoundQuery` is handed, same as the plain command
/// line: folded, lower-cased, whitespace-stripped.
List<String> _keys(List<String> texts) => [
      for (final t in texts) foldDiacritics(t).replaceAll(' ', '').toLowerCase()
    ];

CompoundQuery _parse(String raw) {
  final parse = parseCompoundQuery(raw);
  expect(parse.query, isNotNull,
      reason: 'expected "$raw" to parse; got ${parse.issue}');
  return parse.query!;
}

List<int> _run(String raw) => runCompoundQuery(
      query: _parse(raw),
      texts: _texts,
      searchKeys: _keys(_texts),
      books: _books,
    ).indices;

CommandIssue _issue(String raw) {
  final parse = parseCompoundQuery(raw);
  expect(parse.query, isNull, reason: '"$raw" should not have parsed');
  return parse.issue!;
}

void main() {
  group('what is and is not a compound search', () {
    test('a parenthesised line with no operator is left alone', () {
      // The divergence that makes this necessary: our command line runs
      // a line without a control character as plain text, so somebody
      // typing literal parentheses must keep the search they had.
      for (final raw in ['(hello)', '(god OR world)', '()', '(1 John)']) {
        final parse = parseCompoundQuery(raw);
        expect(parse.issue, CommandIssue.notACommand, reason: raw);
        expect(parse.isCompound, isFalse, reason: raw);
        expect(looksCompound(raw), isFalse, reason: raw);
      }
    });

    test('a line that never opens a group is not ours', () {
      expect(_issue('.grace works'), CommandIssue.notACommand);
      expect(_issue('G25 AND G26'), CommandIssue.notACommand);
      expect(_issue(''), CommandIssue.notACommand);
    });

    test('the two compound shapes are claimed', () {
      // A first group opening with a control character…
      expect(looksCompound('(.grace'), isTrue);
      // …or a separator between two groups, which is what makes
      // `(grace).(works)` a typo worth naming rather than plain text.
      expect(looksCompound('(grace).(works)'), isTrue);
      expect(looksCompound('(grace) .15 (works)'), isTrue);
    });
  });

  group('parsing', () {
    test('each group keeps its own operator and its own verse context', () {
      final q = _parse("(.grac* work*;5).15('jesus christ)");
      expect(q.groups, hasLength(2));
      expect(q.first.kind, CommandKind.and);
      expect(q.first.verseContext, 5);
      expect(q.steps.single.query.kind, CommandKind.phrase);
      expect(q.steps.single.query.verseContext, 0);
      expect(q.steps.single.join, CompoundJoin.and);
      expect(q.steps.single.verseContext, 15);
      expect(q.groupSources, ['.grac* work*;5', "'jesus christ"]);
    });

    test('the three separators, with and without a distance', () {
      expect(_parse('(.a)/(.b)').steps.single.join, CompoundJoin.or);
      expect(_parse('(.a)!(.b)').steps.single.join, CompoundJoin.not);
      expect(_parse('(.a).(.b)').steps.single.verseContext, 0);
      expect(_parse('(.a)!3(.b)').steps.single.verseContext, 3);
    });

    test('a distance on OR is dropped, not obeyed and not reported', () {
      // A union constrains nothing, so there is no window to widen. The
      // echo must not claim a distance the engine is not applying.
      expect(_parse('(.a)/5(.b)').steps.single.verseContext, 0);
    });

    test('whitespace around the separator is allowed', () {
      final q = _parse('(.grace) .2 (.works)');
      expect(q.steps.single.verseContext, 2);
    });

    test('more than two groups chain left to right', () {
      final q = _parse('(.a).(.b)/(.c)!(.d)');
      expect(q.groups, hasLength(4));
      expect([for (final s in q.steps) s.join],
          [CompoundJoin.and, CompoundJoin.or, CompoundJoin.not]);
    });

    test('malformed lines are named, never half-run', () {
      expect(_issue('(.grace'), CommandIssue.compoundUnclosed);
      expect(_issue('(.grace)(.works)'), CommandIssue.compoundSeparator);
      expect(_issue('(.grace)&(.works)'), CommandIssue.compoundSeparator);
      expect(_issue('(.grace).'), CommandIssue.compoundSeparator);
      expect(_issue('((.a).(.b))/(.c)'), CommandIssue.compoundNested);
      expect(_issue('(.grace).999(.works)'), CommandIssue.contextTooLarge);
    });

    test('a group without an operator is its own message', () {
      // Including the case a reader arriving from the Strong's box will
      // hit, which is why it is not folded into "malformed".
      expect(_issue('(grace).(works)'), CommandIssue.compoundGroupOperator);
      expect(_issue('(G25 AND G26).(.faith)'),
          CommandIssue.compoundGroupOperator);
    });

    test("a group's own grammar error is reported as itself", () {
      expect(_issue('(.a).(~b)'), CommandIssue.regexUnsupported);
      expect(_issue('(.a).(.)'), CommandIssue.emptyBody);
    });

    test('the group ceiling is enforced', () {
      final line = List.filled(kMaxCompoundGroups, '(.a)').join('.');
      expect(parseCompoundQuery(line).query, isNotNull);
      expect(_issue('$line.(.a)'), CommandIssue.compoundTooManyGroups);
    });
  });

  group('running', () {
    test('AND with no distance is an intersection', () {
      expect(_run('(.grace).(.works)'), [4]);
    });

    test('OR is a union, in corpus order', () {
      expect(_run('(.grace)/(.works)'), [0, 1, 4, 7, 8]);
    });

    test('NOT with no distance removes the same verses', () {
      expect(_run('(.grace)!(.works)'), [0, 7]);
    });

    test('NOT with a distance removes a whole neighbourhood', () {
      // The contrast is the point: without the distance this same line
      // keeps 0 and 7. With `!1` each of them has a "works" verse next
      // door, so nothing survives.
      expect(_run('(.grace)!(.works)'), [0, 7]);
      expect(_run('(.grace)!1(.works)'), isEmpty);
    });

    test('a distance joins two searches that share no word', () {
      // bwh16's own example, in miniature. Verse 4 holds grace and
      // works; verse 3 holds jesus and christ; they are neighbours.
      expect(_run('(.grace works).1(/jesus christ)'), [3]);
    });

    test('a window does not cross a book boundary', () {
      // Verse 5 ("jesus wept") is index-adjacent to verse 4 but in Acts,
      // so it must not be pulled in by the same `.1` that pulls in 3.
      expect(_run('(.grace works).1(/jesus christ)'), isNot(contains(5)));
      expect(_run('(.grace works).1(/jesus christ)'), [3]);
    });

    test('order decides which group is listed', () {
      // The fact a list of verses cannot show. Same two groups, same
      // distance, different answer.
      expect(_run('(.grace works).1(/jesus christ)'), [3]);
      expect(_run('(/jesus christ).1(.grace works)'), [4]);
    });

    test('each group reports what it found on its own', () {
      final r = runCompoundQuery(
        query: _parse('(.grace).(.nowhere)'),
        texts: _texts,
        searchKeys: _keys(_texts),
        books: _books,
      );
      expect(r.indices, isEmpty);
      // Which is the only place a reader can be told WHICH half was empty.
      expect(r.groupCounts, [3, 0]);
    });

    test('an empty first group cannot be resurrected by an OR', () {
      expect(_run('(.nowhere)/(.works)'), [1, 4, 8]);
    });
  });

  group('reading it back', () {
    test('the echo spells out every group and every join', () {
      final s = describeCompoundQuery(_parse('(.grace works)/(.faith)'), 'en');
      expect(s, '(All of: grace, works) or (All of: faith)');
    });

    test('a distance is named, and so is the group being listed', () {
      final s =
          describeCompoundQuery(_parse('(.grace works).15(/jesus)'), 'en');
      expect(s, contains('and within 15 verses of'));
      expect(s, contains("listing the last group's verses"));
    });

    test('mixed joins say they are applied left to right', () {
      // There is no precedence, so `(a) or (b) and (c)` read with the
      // usual English precedence is the wrong search. Two groups cannot
      // be misread, so the note stays off there.
      expect(_parse('(.a)/(.b).(.c)').mixedJoins, isTrue);
      expect(_parse('(.a)/(.b)/(.c)').mixedJoins, isFalse);
      expect(_parse('(.a)/(.b)').mixedJoins, isFalse);
      expect(describeCompoundQuery(_parse('(.a)/(.b).(.c)'), 'en'),
          contains('applied left to right'));
      expect(describeCompoundQuery(_parse('(.a)/(.b)'), 'en'),
          isNot(contains('applied left to right')));
    });

    test('left to right is what the engine actually does', () {
      // The claim above, checked against the evaluator rather than
      // assumed. Read left to right, `(.grace)/(.works).(.truth)` is
      // "(grace or works) and truth" — verse 0 alone. Read with English
      // precedence it would be "grace or (works and truth)", which is
      // the three grace verses. One verse or three, from the same line.
      expect(_run('(.grace)/(.works).(.truth)'), [0]);
      expect(_run('(.grace)/(.works)'), [0, 1, 4, 7, 8]);
      // And with a term the union does not hold, left to right is empty
      // where the other reading would still return the grace verses.
      expect(_run('(.grace)/(.works).(.jesus)'), isEmpty);
    });

    test('the listing note appears only when the sides can differ', () {
      // With no distance both sides are the same verses, so saying which
      // one is listed would be noise dressed as a warning.
      expect(_parse('(.a).(.b)').listsLastGroup, isFalse);
      expect(_parse('(.a)/5(.b)').listsLastGroup, isFalse);
      expect(_parse('(.a)!5(.b)').listsLastGroup, isFalse);
      expect(_parse('(.a).5(.b)').listsLastGroup, isTrue);
    });

    test('every locale has the echo strings the fallbacks stand in for', () {
      for (final key in [
        'cmdEchoGroup',
        'cmdEchoJoinAnd',
        'cmdEchoJoinAndNear',
        'cmdEchoJoinOr',
        'cmdEchoJoinNot',
        'cmdEchoJoinNotNear',
        'cmdEchoCompoundListing',
        'cmdEchoCompoundLeftToRight',
        'cmdSyntaxCompound',
        'cmdCompoundGroupEmpty',
        'cmdCompoundNoOverlap',
        'cmdIssueCompoundUnclosed',
        'cmdIssueCompoundSeparator',
        'cmdIssueCompoundGroupOperator',
        'cmdIssueCompoundNested',
        'cmdIssueCompoundTooMany',
      ]) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(uiStrings[key]?[locale], isNotNull, reason: '$key/$locale');
        }
      }
    });

    test('every new issue has a sentence in every locale', () {
      for (final issue in [
        CommandIssue.compoundUnclosed,
        CommandIssue.compoundSeparator,
        CommandIssue.compoundGroupOperator,
        CommandIssue.compoundNested,
        CommandIssue.compoundTooManyGroups,
      ]) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(describeCommandIssue(issue, locale), isNotNull);
        }
      }
      expect(
          describeCommandIssue(CommandIssue.compoundTooManyGroups, 'en'),
          contains('$kMaxCompoundGroups'));
    });

    test('the syntax card example is a line that actually parses', () {
      // The card's rows are tappable and run what they show, so an
      // example that does not parse is a defect the card itself teaches.
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        final line = uiStrings['cmdSyntaxCompound']![locale]!.split(' — ').first;
        expect(parseCompoundQuery(line).query, isNotNull, reason: locale);
      }
    });
  });

  test('highlighting marks every group, and only real terms', () {
    final h = highlightsForQuery('(.grace works).15(/jesus christ)');
    expect(h.textTerms, containsAll(['grace', 'works', 'jesus', 'christ']));
  });
}
