import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/compound_query.dart';

/// #295's second pass: every operator in bwh16 driven once, and the three
/// answers that were wrong.
///
/// `search_audit_295_test.dart` pins what the first pass found by driving
/// the deployed build over CDP. This file pins the grammar sweep that
/// followed it — the full table lives in `docs/SEARCH-AUDIT.md`, and what
/// is here is the part a machine can check.
///
/// The three defects share a shape worth naming, because it is the shape
/// the ticket was written to hunt: none of them threw. Each returned a
/// number, the reader had no way to tell the number was wrong, and 447
/// passing search tests did not tell them either. So these expectations
/// are absolute counts. `isNotEmpty` would have passed on every one of
/// the bugs below.
void main() {
  late List<String> texts;
  late List<String> keys;
  late List<String> books;
  late List<String> refs;

  setUpAll(() {
    final list = jsonDecode(File('assets/kjv.json').readAsStringSync()) as List;
    texts = [for (final v in list) sanitizeForSearchKey(v['text'] as String)];
    keys = [for (final v in list) searchCorpusKey(v['text'] as String)];
    books = [for (final v in list) v['book'] as String];
    refs = [for (final v in list) '${v['book']} ${v['chapter']}:${v['verse']}'];
  });

  CommandSearchResult run(String raw) {
    final parse = parseCommandQuery(raw);
    expect(parse.query, isNotNull, reason: '"$raw" was refused: ${parse.issue}');
    return runCommandQuery(
        query: parse.query!, texts: texts, searchKeys: keys, books: books);
  }

  int count(String raw) => run(raw).indices.length;

  List<String> hits(String raw) => [for (final i in run(raw).indices) refs[i]];

  CommandIssue? issueOf(String raw) => parseCommandQuery(raw).issue;

  group('the sweep, with the counts it produced', () {
    test('the two wildcards move the count in opposite directions', () {
      // bwh16: `?` is exactly one character and `*` is zero or more, so
      // one can only narrow and the other can only widen. A regression
      // that swapped them would still return plausible verses.
      expect(count('.heaven'), 550);
      expect(count('.heaven?'), 127);
      expect(count('.faith'), 231);
      expect(count('.faith*'), 336);
    });

    test('the three spellings of a character set agree to the verse', () {
      expect(count('.wom?n'), 503);
      expect(count('.wom[ae]n'), 503);
      expect(count('.wom{ae}n'), 503);
    });

    test('search is blind to case', () {
      expect(count('.GOD'), 3877);
      expect(count('.God'), 3877);
      expect(count('.god'), 3877);
    });

    test('a named gap width is honoured, not approximated', () {
      expect(count("'faith * christ"), 6);
      expect(count("'faith *3 christ"), 10);
      expect(count("'jesus * * christ"), 3);
      expect(count("'* and * of god"), 9);
      expect(hits("'grace *5 faith"), ['Ephesians 2:8']);
    });

    test('bwh16\'s own verse-context example answers as documented', () {
      final found = hits(';the earth and the earth;2');
      expect(found, hasLength(3));
      expect(found.first, 'Genesis 1:1');
    });

    test('a context widens an AND and an exclusion narrows it', () {
      expect(count('.paul silas'), 10);
      expect(count('.paul silas;10'), 35);
      expect(count('.paul silas !barnabas'), 9);
    });

    test('a regex metacharacter is never compiled', () {
      // The grammar is `*` `?` `[]` `{}` and nothing else. The rest of
      // regex is punctuation, and punctuation is transparent to the
      // tokenizer on BOTH sides — the corpus token behind `God,` is
      // `god`, so a query term is read the same way. That makes these
      // equal to the bare word rather than zero, which is the answer a
      // reader who pasted a trailing bracket wanted anyway.
      expect(count(r'.god$'), 3877);
      expect(count('.(god)'), 3877);
      expect(count(r'.^god'), 3877);
      expect(count('.god+'), 3877);
    });

    test('punctuation inside a word splits it, and does not vanish', () {
      // The other half of transparency: dropped at the edges, but a term
      // is still a run of word characters, so an interior symbol cannot
      // be quietly deleted to make a word that was never typed.
      expect(count(r'.g$d'), 0);
      expect(count('.go+d'), 0);
      expect(count(r'.\bgod'), 0, reason: 'the b fuses into "bgod"');
    });

    test('an empty character set matches nothing, and does not throw', () {
      expect(count('.[]'), 0);
      expect(count('.{}'), 0);
      expect(count('.g[]d'), 0);
    });
  });

  group('an apostrophe at a word\'s edge is not part of the word', () {
    // `phraseTokens` strips edge apostrophes when it builds a corpus
    // token, so the token behind the printed word `sons'` is `sons`. The
    // query side kept its apostrophe, so the two could never meet:
    // `.sons'` returned 0 for a word the KJV prints in 212 verses. The
    // same silence covered 214 verses of `kjvs`, 428 of `nasb`, 936 of
    // `nasb-ev` and `nsn-plus`, 158 of `leb` and 82 of `bsb`.
    test('a plural possessive finds its verses', () {
      expect(count(".sons'"), 956);
      expect(count(".daughters'"), 224);
    });

    test('and finds exactly the verses its stem does', () {
      // Not a widening: the corpus token IS `sons`, so the 212 verses
      // were always inside this set and were being withheld.
      expect(hits(".sons'"), hits('.sons'));
      expect(hits(".sons'"), contains('Genesis 6:2'));
    });

    test('an apostrophe inside a word still is one', () {
      // The trim is edges only. Trimming everywhere would collapse the
      // singular possessive into its stem and quietly widen these.
      expect(count(".god's"), 25);
      expect(count(".lord's"), 26);
    });

    test('a zero that is the truth stays zero', () {
      // Neither string is anywhere in the KJV; the fix must not invent a
      // hit to prove itself.
      expect(count(".don't"), 0);
      expect(count(".sons'x"), 0);
    });
  });

  group('a gap wide enough to cross a real verse', () {
    // The old `*N` ceiling was 50, applied by clamping rather than
    // refusing — the one operator in the grammar that answered a
    // different question than the one asked and said nothing.
    test('the clamp lost Esther 8:9; naming the true distance finds it', () {
      // 90 tokens, `then` at 0 and `language` at 89: the longest verse in
      // the KJV, and 782 others are longer than the old ceiling.
      expect(hits("'then *50 language"), isNot(contains('Esther 8:9')));
      final far = hits("'then *89 language");
      expect(far, contains('Esther 8:9'));
      expect(far.length, greaterThan(hits("'then *50 language").length));
    });

    test('the ceiling is the longest verse in any shipped edition', () {
      // `lxxwh` 1 Kings 16:28 is 202 tokens. Past that the number cannot
      // change an answer, so it is refused by name instead of rewritten.
      expect(kMaxWordGap, 202);
      expect(issueOf("'a *202 b"), isNull);
      expect(issueOf("'a *203 b"), CommandIssue.gapTooLarge);
    });

    test('width is free, which is why the ceiling can be the real one', () {
      // `_matchFrom` clamps every gap to the tokens actually remaining in
      // the verse, so a wide gap does not buy work — it buys reach.
      final sw = Stopwatch()..start();
      run("'the *202 and *202 of");
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'took ${sw.elapsedMilliseconds}ms');
    });
  });

  group('a refused query says why', () {
    // These reached `int.parse` with more digits than an int can hold.
    // On the Dart VM that throws, and the throw escapes
    // `WorkbenchProvider.runSearch` — which has a `finally` and no
    // `catch` — leaving `searchPerformed` true, the result list empty and
    // no issue to explain it: the reader is told "no results" about a
    // search that never ran. Compiled to JS the same call returns 1e20
    // rather than throwing, so the shipped web build was already
    // answering most of these politely. `tryParse` makes the two targets
    // agree and closes the native hole.
    test('an out-of-range verse context', () {
      expect(issueOf(';a b;177'), CommandIssue.contextTooLarge);
      expect(issueOf(';a b;99999999999999999999'), CommandIssue.contextTooLarge);
    });

    test('an out-of-range word gap', () {
      expect(issueOf("'a *99999999999999999999 b"), CommandIssue.gapTooLarge);
    });

    test('an out-of-range compound join distance', () {
      expect(parseCompoundQuery('(.a).177(.b)').issue,
          CommandIssue.contextTooLarge);
      expect(parseCompoundQuery('(.a).99999999999999999999(.b)').issue,
          CommandIssue.contextTooLarge);
    });

    test('an operator with nothing after it', () {
      for (final q in <String>['.', "'", ';', '/']) {
        expect(issueOf(q), CommandIssue.emptyBody, reason: 'for "$q"');
      }
    });

    test('an unsupported operator is refused by name, not ignored', () {
      // BibleWorks has these and we do not. Silently searching for the
      // literal `~` would be the worse answer: it returns nothing and
      // looks like the word is absent.
      expect(issueOf('~word'), CommandIssue.regexUnsupported);
      expect(issueOf('=word'), CommandIssue.fuzzyUnsupported);
      // `@` is a tag *within* a word list, so it is caught in the body of
      // a command. A bare `@G25` never was a command and is left to the
      // substring scan, same as any other line that starts with a symbol.
      expect(issueOf('.@G25'), CommandIssue.strongsTagUnsupported);
      expect(issueOf('@G25'), CommandIssue.notACommand);
    });

    test('! inverts one position in a phrase, and refuses to guess which', () {
      // `'the !god word` is fine: one token, one position to invert.
      expect(issueOf("'the !god word"), isNull);
      // Two Han characters are two tokens, so there is no single slot the
      // `!` could mean. Picking one would silently change the question.
      expect(issueOf("'a !神爱 b"), CommandIssue.phraseNotMultiToken);
    });

    test('a malformed compound names which part is malformed', () {
      expect(parseCompoundQuery('(.a').issue, CommandIssue.compoundUnclosed);
      expect(parseCompoundQuery('(.a)(.b)').issue,
          CommandIssue.compoundSeparator);
      expect(parseCompoundQuery('(a b).(.c)').issue,
          CommandIssue.compoundGroupOperator);
      expect(parseCompoundQuery('(.a).(.b).(.c).(.d).(.e).(.f).(.g)').issue,
          CommandIssue.compoundTooManyGroups);
    });

    test('every issue has a finished sentence in all three locales', () {
      // A refusal the reader cannot read is the same as no refusal. The
      // `{max}` check catches the failure mode that shipped `gapTooLarge`
      // in the first place: a placeholder that no locale substitutes.
      for (final issue in CommandIssue.values) {
        for (final locale in <String>['en', 'zh-Hans', 'zh-Hant']) {
          final s = describeCommandIssue(issue, locale);
          if (issue == CommandIssue.notACommand) {
            // The one deliberate null: the line was never a command, so
            // there is nothing to refuse and the substring scan takes it.
            expect(s, isNull, reason: '$issue in $locale');
            continue;
          }
          expect(s, isNotNull, reason: '$issue in $locale');
          expect(s, isNotEmpty, reason: '$issue in $locale');
          expect(s, isNot(contains('{')), reason: '$issue in $locale');
        }
      }
    });
  });
}
