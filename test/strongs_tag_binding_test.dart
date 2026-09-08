/// Unit tests for the command line's `@` Strong's tag binding —
/// `lib/utils/strongs_tag_binding.dart` and the parts of
/// `lib/utils/command_query.dart` that carry it (BibleWorks help topic
/// bwh16, "Doing Searches on Strong's Numbers").
///
/// A hand-built six-verse corpus, tagged the way the shipped assets are
/// tagged — one run of rendered text per original-language word, several
/// tokens to a run — so every expectation below can be read straight off
/// the fixture. `strongs_tag_asset_test.dart` asks the same engine the
/// same questions against the real BSB.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/bible_versions.dart' show bibleVersions;
import 'package:seeksparks/constants/text_patterns.dart'
    show sanitizeForSearchKey, searchCorpusKey;
import 'package:seeksparks/services/tagged_text_service.dart'
    show TaggedTextService;
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/strongs_boolean_search.dart'
    show StrongsOp, parseStrongsBoolean;
import 'package:seeksparks/utils/strongs_tag_binding.dart';

/// Six verses, each as its tagged runs. The verse text is the runs
/// joined, exactly as `assets/tagged/<version>/<book>.json` and
/// `assets/<version>.json` relate in the shipped app.
///
/// Deliberately not uniform: some runs are one word and some are three
/// (`"are the people"`), some are untagged (`""`), and "man" appears
/// four times under four different tags — G444, H120, none, and inside a
/// multi-word run. Every one of those is a case bwh16 spends a bullet on.
const _runs = <List<TaggedRunView>>[
  [ // 0  Genesis
    (text: 'In the beginning ', strongs: 'H7225'),
    (text: 'God ', strongs: 'H430'),
    (text: 'created ', strongs: 'H1254'),
    (text: 'the heavens ', strongs: 'H8064'),
    (text: 'and ', strongs: ''),
    (text: 'the earth.', strongs: 'H776'),
  ],
  [ // 1  Genesis
    (text: 'And ', strongs: ''),
    (text: 'God ', strongs: 'H430'),
    (text: 'said, ', strongs: 'H559'),
    (text: 'Let there be ', strongs: 'H1961'),
    (text: 'light.', strongs: 'H216'),
  ],
  [ // 2  Genesis
    (text: 'The ', strongs: ''),
    (text: 'man ', strongs: 'H120'),
    (text: 'Adam ', strongs: 'H121'),
    (text: 'named ', strongs: 'H7121'),
    (text: 'his wife.', strongs: 'H802'),
  ],
  [ // 3  Romans
    (text: 'The ', strongs: 'G3588'),
    (text: 'man ', strongs: 'G444'),
    (text: 'Christ ', strongs: 'G5547'),
    (text: 'Jesus ', strongs: 'G2424'),
    (text: 'gave himself.', strongs: 'G1325'),
  ],
  [ // 4  Romans
    (text: 'Blessed ', strongs: 'G3107'),
    (text: 'are the people ', strongs: 'G444'),
    (text: 'of God.', strongs: 'G2316'),
  ],
  [ // 5  Romans
    (text: 'A man ', strongs: ''),
    (text: 'of God ', strongs: 'G2316'),
    (text: 'was there.', strongs: 'G1510'),
  ],
];

const _books = <String>[
  'Genesis',
  'Genesis',
  'Genesis',
  'Romans',
  'Romans',
  'Romans',
];

/// One Chinese verse, tagged the way `cuvs-yhwh` tags: a run is a WORD,
/// so 起初 is one run and two tokens.
const _cjkRuns = <List<TaggedRunView>>[
  [
    (text: '起初', strongs: 'H7225'),
    (text: '神', strongs: 'H430'),
    (text: '创造', strongs: 'H1254'),
    (text: '天', strongs: 'H8064'),
    (text: '地。', strongs: 'H776'),
  ],
];
const _cjkBooks = <String>['创世记'];

List<String> _texts(List<List<TaggedRunView>> runs) =>
    [for (final v in runs) sanitizeForSearchKey([for (final r in v) r.text].join())];

List<String> _keys(List<List<TaggedRunView>> runs) =>
    [for (final v in runs) searchCorpusKey([for (final r in v) r.text].join())];

TaggedTokensLookup _lookup(List<List<TaggedRunView>> runs) =>
    (i) => taggedRunTokens(runs[i]);

CommandQuery _parse(String raw) {
  final parse = parseCommandQuery(raw);
  expect(parse.query, isNotNull,
      reason: 'expected "$raw" to parse; got ${parse.issue}');
  return parse.query!;
}

CommandIssue _issue(String raw) {
  final parse = parseCommandQuery(raw);
  expect(parse.query, isNull, reason: '"$raw" should not have parsed');
  return parse.issue!;
}

List<int> _run(String raw,
    {List<List<TaggedRunView>> runs = _runs, List<String> books = _books}) {
  final query = _parse(raw);
  return runCommandQuery(
    query: query,
    texts: _texts(runs),
    searchKeys: _keys(runs),
    books: books,
    taggedTokens: query.usesStrongsTags ? _lookup(runs) : null,
  ).indices;
}

void main() {
  group('reading the number after @', () {
    test('a bare number is Greek and a leading zero is Hebrew', () {
      // bwh16's own examples: `.man@444` is ἄνθρωπος, `'lord of *@06635`
      // is צָבָא. The zero is the only thing telling the two apart on a
      // BibleWorks command line, so dropping it would silently turn
      // every Hebrew search this app inherits into a Greek one.
      expect(normaliseStrongsTag('444'), 'G444');
      expect(normaliseStrongsTag('06635'), 'H6635');
      expect(normaliseStrongsTag('03068'), 'H3068');
    });

    test("SeekSparks' own spelling is accepted alongside it", () {
      // The app prints H430 in the analysis pane, in the concordance and
      // in `G25 AND G26`. A box that refused the spelling it shows the
      // reader everywhere else would be a puzzle, not a shortcut.
      expect(normaliseStrongsTag('G444'), 'G444');
      expect(normaliseStrongsTag('h430'), 'H430');
      // An explicit letter beats the zero rule: the reader said which
      // language they meant.
      expect(normaliseStrongsTag('G0444'), 'G444');
    });

    test('anything that is not a resolvable number is refused', () {
      for (final body in <String>['', '0', '44x', '44*', '[123]*', '9999999']) {
        expect(normaliseStrongsTag(body), isNull, reason: 'for "@$body"');
      }
      // Above the ceiling the other Strong's grammar in the same box
      // uses, so `@6000` and `G6000` are refused the same way.
      expect(normaliseStrongsTag('6000'), isNull);
      expect(normaliseStrongsTag('9000'), isNull, reason: 'Greek by default');
      expect(normaliseStrongsTag('09000'), isNull, reason: 'Hebrew ceiling');
    });

    test('@* is any tag, @- is none, and ! flips either', () {
      const tagged = 'G444';
      const untagged = '';
      expect(parseStrongsTag('*').binding!.matchesTag(tagged), isTrue);
      expect(parseStrongsTag('*').binding!.matchesTag(untagged), isFalse);
      expect(parseStrongsTag('-').binding!.matchesTag(untagged), isTrue);
      expect(parseStrongsTag('-').binding!.matchesTag(tagged), isFalse);
      expect(parseStrongsTag('!-').binding!.matchesTag(tagged), isTrue);
      expect(parseStrongsTag('!444').binding!.matchesTag('G444'), isFalse);
      expect(parseStrongsTag('!444').binding!.matchesTag('G435'), isTrue);
      // bwh16's `.man@!444` finds "verses containing man when it does
      // not translate ἄνθρωπος" — an untagged "man" is one of those.
      expect(parseStrongsTag('!444').binding!.matchesTag(untagged), isTrue);
    });
  });

  group('the six syntax forms bwh16 lists', () {
    test('word@number — the word AND the lemma behind it', () {
      expect(_run('.man@444'), [3]);
      expect(_run('.man@G444'), [3]);
      // The same word, a different lemma. This is the whole point: two
      // questions that `.man` alone cannot tell apart.
      expect(_run('.man@0120'), [2]);
      expect(_run('.man@H120'), [2]);
      // 120 with no leading zero is Greek G120, which nothing here uses.
      expect(_run('.man@120'), isEmpty);
    });

    test('word@!number — the word, NOT that lemma', () {
      // Verse 2 renders H120 as "man" and verse 5 leaves its "man"
      // untagged; neither is G444, and bwh16 counts both.
      expect(_run('.man@!444'), [2, 5]);
    });

    test('!word@number — that lemma, NOT rendered by that word', () {
      // bwh16: "occurrences of ἄνθρωπος that have not been translated as
      // man". Verse 3 tags only "man" G444 and is therefore excluded;
      // verse 4 renders G444 as "are the people".
      expect(_run('.!man@444'), [4]);
      // The `!` here fills a position; it does NOT throw the verse away
      // the way `.paul !barnabas` does. If it did, this would be every
      // verse without the word "man".
      expect(_parse('.!man@444').terms.single.negated, isFalse);
      expect(_parse('.!man@444').terms.single.wordNegated, isTrue);
    });

    test('word@- — the word where nothing tagged it', () {
      expect(_run('.man@-'), [5]);
      expect(_run('.*@-'), [0, 1, 2, 5]);
    });

    test('word@* — the word wherever it carries any tag', () {
      expect(_run('.man@*'), [2, 3]);
    });

    test('*@number — every rendering of the lemma', () {
      // bwh16's "all the different English words used to translate
      // ἄνθρωπος". Both verses, whatever word carried it.
      expect(_run('.*@444'), [3, 4]);
    });
  });

  group('what the shape of a tagged run costs', () {
    test('every token of a multi-word run carries the run’s number', () {
      // "are the people" is ONE run tagged G444, so all three of its
      // tokens answer to G444. This is over-broad next to BibleWorks,
      // which tags word by word — and it is what the shipped assets say,
      // so the alternative would be this engine inventing a head word.
      expect(_run('.the@444'), [4]);
      expect(_run('.are@444'), [4]);
    });

    test('a term’s tag binds every token the term occupies', () {
      // 起初 is two tokens (one per Han character) and one run, H7225.
      // Requiring all of them is the only reading under which a Chinese
      // word can be tag-bound at all.
      expect(_run('.起初@H7225', runs: _cjkRuns, books: _cjkBooks), [0]);
      expect(
          _run('.起初@H1254', runs: _cjkRuns, books: _cjkBooks), isEmpty);
      // 神创 straddles two runs with two different numbers, so no single
      // tag can hold it.
      expect(_run('.神创@H430', runs: _cjkRuns, books: _cjkBooks), isEmpty);
    });
  });

  group('a tag inside the rest of the grammar', () {
    test('AND combines a tagged term with an untagged one', () {
      expect(_run('.man@444 christ'), [3]);
      expect(_run('.man@444 adam'), isEmpty);
    });

    test('OR takes either side', () {
      expect(_run('/man@444 light@H216'), [1, 3]);
    });

    test('a phrase keeps word order and the tag together', () {
      // Verse 3 is "The man …" with "man" tagged G444. Verse 4 has a
      // "the" tagged G444 but no "man" after it, so order still decides.
      expect(_run("'the man@444"), [3]);
      expect(_run("'man@444 the"), isEmpty);
    });

    test('a verse context spreads tagged terms over a window', () {
      // God/H430 is in verses 0 and 1, light/H216 only in verse 1, and
      // both are Genesis — so a two-verse window holds them and both
      // participating verses are reported.
      expect(_run('.god@H430 light@H216;2'), [0, 1]);
      // Verse 3 is Romans, so no window reaches it from Genesis.
      expect(_run('.god@H430 man@444;5'), isEmpty);
    });

    test('the highlighter is never told to mark a word being avoided', () {
      // `search_highlight.dart` marks `literalCore`. For `.!man@444` the
      // verses found are the ones NOT saying "man", so a mark on "man"
      // would point at nothing or, worse, at the wrong word.
      expect(_parse('.man@444').terms.single.literalCore, 'man');
      expect(_parse('.!man@444').terms.single.literalCore, isEmpty);
    });
  });

  group('a query that cannot be answered says so', () {
    test('running a tag query with no tagging asserts rather than empties',
        () {
      // The forbidden outcome is an empty result list, which reads as
      // "this edition never renders ἄνθρωπος as man". `WorkbenchProvider`
      // refuses by name before it gets here; this pins the backstop.
      final query = _parse('.man@444');
      expect(
        () => runCommandQuery(
          query: query,
          texts: _texts(_runs),
          searchKeys: _keys(_runs),
          books: _books,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('the untagged-edition refusal names the editions that can answer',
        () {
      // "Switch to a tagged edition" is a refusal the reader cannot act
      // on. This also keeps the sentence and
      // `TaggedTextService.taggedVersions` from drifting apart: add a
      // seventh tagged edition and this test fails until the message
      // mentions it.
      final tagged = TaggedTextService.taggedVersions;
      expect(tagged, isNotEmpty);
      for (final locale in <String>['en', 'zh-Hans', 'zh-Hant']) {
        final message = describeCommandIssue(
            CommandIssue.strongsTagNoTaggedText, locale)!;
        var remainder = message;
        for (final code in tagged) {
          final label =
              bibleVersions.firstWhere((v) => v.value == code).shortLabel;
          expect(message, contains(label),
              reason: '$locale must name $code as "$label"');
          remainder = remainder.replaceAll(label, '');
        }
        // And must not invite the reader to an edition that cannot
        // answer either. Checked on the remainder so that KJV+S having
        // been named does not make a bare "KJV" look present.
        for (final v in bibleVersions) {
          if (tagged.contains(v.value)) continue;
          expect(remainder, isNot(contains(v.shortLabel)),
              reason: '$locale must not offer ${v.value}, which has no tagging');
        }
      }
    });

    test('a malformed tag is named rather than half-run', () {
      expect(_issue('.@444'), CommandIssue.strongsTagNoWord);
      expect(_issue('.man@'), CommandIssue.strongsTagNumber);
      expect(_issue('.man@!'), CommandIssue.strongsTagNumber);
      expect(_issue('.man@44x'), CommandIssue.strongsTagNumber);
      // bwh16 has `@[1234567890]*`; `@*` says the same thing here in one
      // character, and a partial number is ambiguous under the
      // leading-zero rule, so it is refused instead of guessed at.
      expect(_issue('.man@44*'), CommandIssue.strongsTagNumber);
      expect(_issue('.man@6000'), CommandIssue.strongsTagNumber);
      expect(_issue('.man@444@555'), CommandIssue.strongsTagNumber);
    });

    test('! in front of a tagged term needs a single word', () {
      // Two Han characters are two positions, and "neither 爱 nor 神,
      // both tagged G26" is not a question anyone typed.
      expect(_issue('.!爱神@G26'), CommandIssue.strongsTagNotOneWord);
      // One character is fine, in either mode.
      expect(parseCommandQuery('.!爱@G26').issue, isNull);
      expect(parseCommandQuery("'!man@444 god").issue, isNull);
    });
  });

  group('the other Strong’s grammar in the same box still works', () {
    test('G25 AND G26 is not a command line and still parses as boolean', () {
      // The regression guard for the reason `@` was left out for a
      // month: two Strong's grammars share one text box. They are told
      // apart by the first character, so neither can steal the other's
      // line — and nothing about `@` changed that.
      for (final raw in <String>[
        'G25 AND G26',
        'G25 NEAR5 G26',
        'G25 OR G26',
        'H157 NOT H160',
      ]) {
        expect(parseCommandQuery(raw).issue, CommandIssue.notACommand,
            reason: '"$raw" belongs to parseStrongsBoolean');
        expect(parseStrongsBoolean(raw), isNotNull, reason: raw);
      }
      final boolean = parseStrongsBoolean('G25 AND G26')!;
      expect(boolean.terms.map((t) => t.number), ['G25', 'G26']);
      expect(boolean.ops, [StrongsOp.and]);
    });

    test('a command line carrying no @ is untouched', () {
      final q = _parse('.god light');
      expect(q.usesStrongsTags, isFalse);
      expect(q.terms.every((t) => t.tag == null), isTrue);
      expect(_run('.god light'), [1]);
      expect(_run("'in the beginning"), [0]);
      expect(_run('.god !light'), [0, 4, 5]);
    });
  });

  group('the echo says what the query means', () {
    test('an AND search reads back with both halves of the binding', () {
      expect(describeCommandQuery(_parse('.man@444'), 'en'),
          'All of: man rendering G444');
      expect(describeCommandQuery(_parse('.man@!444'), 'en'),
          'All of: man not rendering G444');
      expect(describeCommandQuery(_parse('.!man@444'), 'en'),
          'All of: any word but man rendering G444');
      expect(describeCommandQuery(_parse('.man@-'), 'en'),
          'All of: man with no original-language tag');
      expect(describeCommandQuery(_parse('.man@*'), 'en'),
          'All of: man with an original-language tag');
    });

    test('a bare * is spoken as "any word", not printed as a star', () {
      // `.*@444` is the form bwh16 uses for "every rendering of the
      // lemma", and a reader who sees `*` echoed back learns nothing.
      expect(describeCommandQuery(_parse('.*@444'), 'en'),
          'All of: any word rendering G444');
      expect(describeCommandQuery(_parse('.*@444'), 'zh-Hans'),
          '同时包含：任意词（原文 G444）');
    });

    test('the normalised number is echoed, not the digits as typed', () {
      // The reader typed BibleWorks' `06635`; what they are told they
      // searched for is what the rest of the app calls that word.
      expect(describeCommandQuery(_parse('.hosts@06635'), 'en'),
          'All of: hosts rendering H6635');
    });

    test('a phrase keeps its parts in order with the tag attached', () {
      expect(describeCommandQuery(_parse("'the man@444"), 'en'),
          'In order: the · man rendering G444');
    });
  });
}
