import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/search_highlight.dart';

/// bwh16's `~` search, over the shipped editions, in absolute counts.
///
/// Absolute and not `isNotEmpty`, for the reason
/// `command_grammar_audit_test.dart` states in its own header: the
/// defects this grammar has shipped did not throw. Each returned a
/// number, and a number the reader cannot check is indistinguishable
/// from the right one.
void main() {
  late List<String> texts;
  late List<String> keys;
  late List<String> books;
  late List<String> refs;

  late List<String> zhTexts;
  late List<String> zhKeys;
  late List<String> zhBooks;

  ({List<String> texts, List<String> keys, List<String> books}) load(
      String asset) {
    final list = jsonDecode(File(asset).readAsStringSync()) as List;
    return (
      texts: [for (final v in list) sanitizeForSearchKey(v['text'] as String)],
      keys: [for (final v in list) searchCorpusKey(v['text'] as String)],
      books: [for (final v in list) v['book'] as String],
    );
  }

  setUpAll(() {
    final kjv = load('assets/kjv.json');
    texts = kjv.texts;
    keys = kjv.keys;
    books = kjv.books;
    final list = jsonDecode(File('assets/kjv.json').readAsStringSync()) as List;
    refs = [for (final v in list) '${v['book']} ${v['chapter']}:${v['verse']}'];
    final zh = load('assets/cuvs-yhwh.json');
    zhTexts = zh.texts;
    zhKeys = zh.keys;
    zhBooks = zh.books;
  });

  CommandSearchResult run(String raw,
      {List<String>? t, List<String>? k, List<String>? b}) {
    final parse = parseCommandQuery(raw);
    expect(parse.query, isNotNull, reason: '"$raw" was refused: ${parse.issue}');
    return runCommandQuery(
      query: parse.query!,
      texts: t ?? texts,
      searchKeys: k ?? keys,
      books: b ?? books,
    );
  }

  int count(String raw,
          {List<String>? t, List<String>? k, List<String>? b}) =>
      run(raw, t: t, k: k, b: b).indices.length;

  CommandIssue? issueOf(String raw) => parseCommandQuery(raw).issue;

  group('the regression guard: nothing that worked before moved', () {
    // `~` joined `kCommandControls` and `CommandKind` gained a fourth
    // value in the same change. Both are read by files this change does
    // not otherwise touch — `search_broadening.dart`,
    // `fuzzy_result_label.dart`, `compound_query.dart` — so the first
    // thing to pin is that the four token operators answer exactly what
    // `command_grammar_audit_test.dart` recorded before any of it.
    test('the four token operators return the counts they returned', () {
      expect(count('.heaven'), 550);
      expect(count('.heaven?'), 127);
      expect(count('.faith'), 231);
      expect(count('.faith*'), 336);
      expect(count('.faith works'), 15);
      expect(count('.faith* work*'), 23);
      expect(count('.love god'), 72);
    });

    test('a tilde anywhere but the first character is still ordinary text',
        () {
      // A control character is a property of first position only, and
      // making `~` one of them must not turn a stray tilde mid-line into
      // an operator.
      expect(parseCommandQuery('god ~ world').issue, CommandIssue.notACommand);
      expect(parseCommandQuery('.god~world').query?.kind, CommandKind.and);
    });
  });

  group('what bwh16 promises a tilde does', () {
    test("the manual's own example finds the letters it names", () {
      // bwh16: "if you enter the Command Line <~And God said> a search
      // will be made for all verses that contain the 12 letters".
      expect(count('~And God said'), 27);
      final where = [for (final i in run('~And God said').indices) refs[i]];
      expect(where.first, 'Genesis 1:3');
    });

    test('a regular expression search is case sensitive, as bwh16 says', () {
      // The paragraph's second half: "If, for example, you wanted to
      // find all occurrences of 'god' (with a lower case 'g') you could
      // enter <~god>". Two different searches, two different answers —
      // which is only true because the pattern runs against `wordKeys`
      // and not against the lower-cased `searchKeys`.
      final upper = count('~God');
      final lower = count('~god');
      expect(lower, lessThan(upper));
      expect(lower, greaterThan(0));
      // And the ordinary grammar, whose corpus IS lower-cased, cannot
      // tell them apart. That is the reconciliation, stated as a test.
      expect(count('.God'), count('.god'));
    });

    test('the whole operator table works over the real corpus', () {
      expect(count(r'~^In the beginning'), 4);
      // The KJV never spells it "god said" with a small g, so the class
      // adds nothing here — which is itself the check worth writing,
      // because it is exact and a `greaterThan` would not have been.
      expect(count('~[Gg]od said'),
          count('~God said') + count('~god said'));
      expect(count('~god said'), 0);
      // An alternation is a UNION of verse sets, not a sum of counts:
      // 58 verses hold one of the two trees and 60 is what you get by
      // adding the branches up, because two verses hold both (Judges
      // 9's parable is one). A test that asserted the sum would have
      // been asserting a bug.
      expect(count('~(fig|olive) tree'), 58);
      expect(count('~fig tree') + count('~olive tree'), 60);
      expect(count('~lov(ed|est) me'),
          count('~loved me') + count('~lovest me'));
    });
  });

  group('Han text, which BibleWorks says its engine cannot do', () {
    // "It is at present implemented only for English text" (bwh16). That
    // is a fact about an engine that indexes whitespace-delimited words,
    // not about regular expressions, and this one matches the string.
    test('a dot counts one Han character', () {
      final adjacent = count('~神说', t: zhTexts, k: zhKeys, b: zhBooks);
      final oneApart = count('~神.说', t: zhTexts, k: zhKeys, b: zhBooks);
      expect(adjacent, greaterThan(0));
      expect(oneApart, greaterThan(0));
      // Different questions, so different answers: "神 then 说" and "神,
      // one character, 说" cannot be the same set.
      expect(oneApart, isNot(adjacent));
    });

    test('a class reaches what the token grammar cannot express at all', () {
      // `_compileTerm` splits a Han term one character per position
      // before it ever sees a `[`, so `[神主]的` has no spelling in the
      // `.` / `'` grammar — this is the only route to it.
      final klass = count('~[神主]的', t: zhTexts, k: zhKeys, b: zhBooks);
      final shen = count('~神的', t: zhTexts, k: zhKeys, b: zhBooks);
      final zhu = count('~主的', t: zhTexts, k: zhKeys, b: zhBooks);
      expect(klass, greaterThan(shen));
      expect(klass, greaterThan(zhu));
      // A verse may hold both, so the union is at most the sum.
      expect(klass, lessThanOrEqualTo(shen + zhu));
    });

    test('the divine name is rewritten on both sides or on neither', () {
      // The corpus key has already turned 耶和华 into 雅伟, so a pattern
      // that was not rewritten too could only find nothing.
      // `_parseRegex` runs `normalizeDivineNamesInQuery` for exactly the
      // reason `TokenMatcher.compile` does.
      final typed = count('~耶和华', t: zhTexts, k: zhKeys, b: zhBooks);
      final stored = count('~雅伟', t: zhTexts, k: zhKeys, b: zhBooks);
      expect(typed, stored);
      expect(typed, greaterThan(6000));
    });
  });

  group('the prefilter is weaker than it could be and cannot be wrong', () {
    test('the filter is a space-free run, not the whole required literal',
        () {
      // `~And God said` filters on "said". A literal with a space in it
      // is not safe to test against `searchKeys`, because
      // `collapseSearchSpaces` removes the gap between two Han
      // characters — so `神 说` is present in `wordKeys` and absent from
      // `searchKeys`, and a filter on the whole literal would throw the
      // verse away before the pattern ever saw it.
      expect(parseCommandQuery('~And God said').query!.regex!.requiredLiteral,
          'And God said');
      final r = run('~And God said');
      // 3,626 verses opened out of 31,102 — the filter did its job — and
      // 27 of them matched.
      expect(r.tokenized, 3626);
      expect(r.indices.length, 27);
    });

    test('a whitespace run that the corpus key collapses is not filtered on',
        () {
      // The rule stated as its own corpus, because the shipped editions
      // do not happen to contain the shape that breaks it and a rule
      // only kept by luck is not kept.
      //
      // `wordKeys` keeps whitespace as it stands; `searchKeys` runs
      // `collapseSearchSpaces`, which turns a run into one space and
      // deletes it outright between two Han characters. So a required
      // literal containing whitespace can be present in the corpus the
      // pattern matches against and absent from the corpus the
      // prefilter tests — and a prefilter that is merely weak costs
      // time, while one that is wrong loses the hit in silence.
      final t = <String>['God  said, Let there be light', '神 说', '爱'];
      final k = <String>[
        for (final v in t) searchCorpusKey(v),
      ];
      final b = <String>['Genesis', 'Genesis', 'Genesis'];
      // Both keys really do disagree, or the test proves nothing.
      expect(k[0], 'god said, let there be light');
      expect(k[1], '神说');

      expect(count('~God  said', t: t, k: k, b: b), 1);
      expect(count('~神 说', t: t, k: k, b: b), 1);
    });

    test('a pattern with no fixed run at all still opens every verse', () {
      final r = run(r'~^[A-Z]');
      expect(r.tokenized, texts.length);
      expect(r.indices.length, greaterThan(30000));
    });
  });

  group('the budget, checked before the scan and not during it', () {
    const wide = '~(alpha|bravo|charlie|delta|echo|foxtrot|golf|hotel|'
        'india|juliet|kilo|lima|mike|november|oscar|papa|quebec|romeo|'
        'sierra|tango)';

    test('a twenty-way alternation over the whole corpus is refused by name',
        () {
      // 143 states with no literal to prefilter on: a 1,171 M-step
      // ceiling, measured at 2.1 s. Refused — and refused as a FLAG
      // rather than as a short list, because a short list looks like an
      // answer.
      final parse = parseCommandQuery(wide);
      expect(parse.query, isNotNull, reason: 'the pattern itself is fine');
      expect(parse.query!.regex!.size, 143);
      final r = runCommandQuery(
          query: parse.query!, texts: texts, searchKeys: keys, books: books);
      expect(r.regexBudgetExceeded, isTrue);
      expect(r.indices, isEmpty);
    });

    test('the same alternation with a plain word in front of it runs', () {
      // What the refusal tells the reader to do, done: the literal
      // prefilter cuts the candidate set, the ceiling falls with it, and
      // the search that was refused becomes cheap.
      final r = run('~said (alpha|bravo|charlie|delta|echo|foxtrot|golf|'
          'hotel|india|juliet|kilo|lima|mike|november|oscar|papa|quebec|'
          'romeo|sierra|tango)');
      expect(r.regexBudgetExceeded, isFalse);
      expect(r.tokenized, lessThan(texts.length ~/ 4));
    });

    test('the ceiling is the arithmetic the budget is checked against', () {
      final p = parseCommandQuery('~(cat|dog)').query!.regex!;
      expect(p.size, 9);
      var chars = 0;
      for (final t in texts) {
        chars += t.length;
      }
      expect(chars, 4094632);
      // 9 x (4,094,632 + 1) x 2 = 73,703,394, under the 600 M budget and
      // measured at 158 ms.
      expect(p.stepCeilingFor(chars), 73703394);
      expect(p.stepCeilingFor(chars), lessThan(kRegexStepBudget));
      expect(count('~(cat|dog)'), 524);
    });
  });

  group('what the reader is told when the pattern cannot run', () {
    test('every refusal is named, and none of them is an empty list', () {
      expect(issueOf('~'), CommandIssue.emptyBody);
      expect(issueOf('~(unclosed'), CommandIssue.regexSyntax);
      expect(issueOf(r'~\d+'), CommandIssue.regexUnsupportedOperator);
      expect(issueOf('~go{2,3}d'), CommandIssue.regexUnsupportedOperator);
      expect(issueOf('~${'a' * (kMaxRegexProgram + 1)}'),
          CommandIssue.regexTooComplex);
    });

    test('the echo says the one thing about this search that surprises', () {
      final q = parseCommandQuery('~And God said').query!;
      final echo = describeCommandQuery(q, 'en');
      expect(echo, contains('And God said'));
      expect(echo, contains('case'));
    });
  });

  group('what a regex hit highlights', () {
    test('the required literal is marked, without the highlighter knowing',
        () {
      // `search_highlight.dart` never learns that `CommandKind.regex`
      // exists: it reads `positiveTerms`, and the parse puts one
      // synthetic term there carrying the required literal. That is why
      // `~And God said` marks its words in the text pane and the browse
      // pane alike, with no edit to either.
      expect(highlightsForQuery('~And God said').textTerms,
          <String>['and god said']);
      expect(highlightsForQuery(r'~a\*b').textTerms, <String>['a*b']);
    });

    test('a pattern with nothing fixed marks nothing rather than guessing',
        () {
      // Under-marking is the safe direction — the same bargain
      // `.faith*` already takes, where "faith" is marked inside
      // "faithfulness" and the rest of the word is not.
      expect(highlightsForQuery('~(cat|dog)s').textTerms, <String>['s']);
      expect(highlightsForQuery(r'~^[A-Z]').textTerms, isEmpty);
    });
  });
}
