/// Unit tests for the BibleWorks command-line query language
/// (`lib/utils/command_query.dart`, help topic bwh16).
///
/// Hand-built corpora, so every expectation can be read off the fixture.
/// `command_query_corpus_test.dart` runs the same engine against the real
/// 31,102-verse KJV, where the claim is about results rather than
/// mechanics.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/diacritics.dart';

/// Six verses of English and four of Chinese, arranged so that the verse
/// context tests have a book boundary to run into.
const _texts = <String>[
  'In the beginning God created the heaven and the earth.', // 0  Gen 1:1
  'And the earth was without form, and void.', // 1  Gen 1:2
  'And God said, Let there be light: and there was light.', // 2  Gen 1:3
  'And God saw the light, that it was good.', // 3  Gen 1:4
  'Paul and Silas prayed, and sang praises unto God.', // 4  Acts 16:25
  'And Barnabas departed, and Silas remained.', // 5  Acts 16:26
];
const _books = <String>[
  'Genesis',
  'Genesis',
  'Genesis',
  'Genesis',
  'Acts',
  'Acts',
];

const _cjkTexts = <String>[
  '起初神创造天地。', // 0
  '神说、要有光、就有了光。', // 1
  '神看光是好的、就把光暗分开了。', // 2
  '神爱世人、甚至将他的独生子赐给他们。', // 3
];
const _cjkBooks = <String>['创世记', '创世记', '创世记', '约翰福音'];

/// The contract `runCommandQuery` is handed: folded, lower-cased,
/// whitespace-stripped. Mirrors `MainProvider.searchKeys` — if that
/// stops folding, these tests stop describing the shipped pipeline.
List<String> _keys(List<String> texts) => [
      for (final t in texts) foldDiacritics(t).replaceAll(' ', '').toLowerCase()
    ];

List<int> _run(String raw,
    {List<String> texts = _texts, List<String> books = _books}) {
  final parse = parseCommandQuery(raw);
  expect(parse.query, isNotNull,
      reason: 'expected "$raw" to parse; got ${parse.issue}');
  return runCommandQuery(
    query: parse.query!,
    texts: texts,
    searchKeys: _keys(texts),
    books: books,
  ).indices;
}

CommandIssue _issue(String raw) {
  final parse = parseCommandQuery(raw);
  expect(parse.query, isNull, reason: '"$raw" should not have parsed');
  return parse.issue!;
}

void main() {
  group('what is and is not a command', () {
    test('text with no control character is left alone', () {
      // The single most important negative: SeekSparks readers who have
      // never heard of a control character must keep their search box.
      for (final input in ['love god', '约翰福音 3:16', 'G25 AND G26', 'kjv']) {
        expect(parseCommandQuery(input).issue, CommandIssue.notACommand,
            reason: '"$input" must fall through to the existing handling');
      }
    });

    test('an empty line is not a command', () {
      expect(parseCommandQuery('').issue, CommandIssue.notACommand);
      expect(parseCommandQuery('   ').issue, CommandIssue.notACommand);
    });

    test('a lone operator is a typo, not a query', () {
      expect(_issue('.'), CommandIssue.emptyBody);
      expect(_issue("'"), CommandIssue.emptyBody);
      expect(_issue('.  '), CommandIssue.emptyBody);
    });

    test('unsupported syntax is named rather than half-run', () {
      // `(` belongs to the compound grammar in `compound_query.dart`, so
      // this parser has no claim on it — the caller tries that one first.
      expect(_issue('(.grace work)/(.faith)'), CommandIssue.notACommand);
      expect(_issue('~And God said'), CommandIssue.regexUnsupported);
      expect(_issue('=.faith works'), CommandIssue.fuzzyUnsupported);
      expect(_issue('.man@444'), CommandIssue.strongsTagUnsupported);
    });

    test('a verse context beyond the longest chapter is refused', () {
      expect(_issue('.paul silas;999'), CommandIssue.contextTooLarge);
      expect(parseCommandQuery('.paul silas;176').query?.verseContext, 176);
    });
  });

  group('control characters pick the search', () {
    test('. is AND — every term, one verse', () {
      expect(_run('.god light'), [2, 3]);
      expect(_run('.god earth'), [0]);
    });

    test('/ is OR — any term', () {
      expect(_run('/silas barnabas'), [4, 5]);
    });

    test("' is a phrase — the words in order and adjacent", () {
      expect(_run("'and god said"), [2]);
      expect(_run("'god and said"), isEmpty,
          reason: 'order is the whole point of a phrase');
    });

    test('; is the same phrase, scanned linearly', () {
      expect(_run(';and god said'), _run("'and god said"));
    });

    test('a phrase steps over punctuation', () {
      // "And God said, Let there be light" — the comma occupies no
      // token position, so the phrase runs straight through it.
      expect(_run("'said let there be light"), [2]);
    });
  });

  group('! means two different things', () {
    test('in an AND search it excludes the verse', () {
      expect(_run('.silas !barnabas'), [4]);
      expect(_run('.silas'), [4, 5]);
    });

    test('in an OR search it still excludes', () {
      expect(_run('/silas paul !barnabas'), [4]);
    });

    test('in a phrase it fills one position with anything else', () {
      // `!x` is a POSITION: one word, which must not be x. It does not
      // remove the position, and it does not exclude the verse.
      expect(_run("'!the god created"), [0],
          reason: '"...beginning God created..." — beginning is not "the"');
      expect(_run("'!beginning god created"), isEmpty,
          reason: 'the word in that slot IS beginning');
      expect(_run("'in !the beginning"), isEmpty);
      expect(_run("'and !there was"), isEmpty,
          reason: '"there was" only ever follows "and"');
    });

    test('a phrase ! in front of a multi-token term is refused', () {
      // 爱神 is two positions; there is no single one to invert, and
      // picking one silently would change the question.
      expect(_issue("'!爱神 世人"), CommandIssue.phraseNotMultiToken);
    });
  });

  group('wildcards', () {
    test('* is zero or more characters, inside a word', () {
      final m = TokenMatcher.compile('faith*');
      expect(m.matches('faith'), isTrue);
      expect(m.matches('faithful'), isTrue);
      expect(m.matches('faithfulness'), isTrue);
      expect(m.matches('unfaithful'), isFalse);
    });

    test('* works in the middle and at the front', () {
      final m = TokenMatcher.compile('*belie*');
      expect(m.matches('belief'), isTrue);
      expect(m.matches('unbelieving'), isTrue);
      expect(m.matches('believe'), isTrue);
      expect(m.matches('faith'), isFalse);
    });

    test('? is exactly one character', () {
      final m = TokenMatcher.compile('wom?n');
      expect(m.matches('woman'), isTrue);
      expect(m.matches('women'), isTrue);
      expect(m.matches('womn'), isFalse);
      // BibleWorks' own example of why ? and * differ.
      expect(TokenMatcher.compile('heaven?').matches('heavens'), isTrue);
      expect(TokenMatcher.compile('heaven?').matches('heaven'), isFalse);
    });

    test('both bracket styles are a character range', () {
      for (final src in ['wom{ae}n', 'wom[ae]n']) {
        final m = TokenMatcher.compile(src);
        expect(m.matches('woman'), isTrue, reason: src);
        expect(m.matches('women'), isTrue, reason: src);
        expect(m.matches('womin'), isFalse, reason: src);
      }
    });

    test('matching ignores case', () {
      expect(TokenMatcher.compile('GOD').matches('god'), isTrue);
      expect(_run('.GOD LIGHT'), [2, 3]);
    });

    test('the literal core is the longest plain run', () {
      expect(TokenMatcher.compile('faith*').literalCore, 'faith');
      expect(TokenMatcher.compile('wom?n').literalCore, 'wom');
      expect(TokenMatcher.compile('*belie*').literalCore, 'belie');
      expect(TokenMatcher.compile('*').literalCore, '');
    });

    test('a wildcard term finds the whole family', () {
      expect(_run('.creat*'), [0]);
      expect(_run('.prais*'), [4]);
    });
  });

  group('gaps inside a phrase', () {
    test('a bare * is exactly one word', () {
      expect(_run("'god * the"), [0, 3]); // "God created the", "God saw the"
      expect(_run("'in * beginning"), [0]); // "In the beginning"
      expect(_run("'in * * beginning"), isEmpty);
    });

    test('*N is N words or fewer, including none', () {
      expect(_run("'paul *2 silas"), [4]); // "Paul and Silas"
      expect(_run("'paul *1 silas"), [4]);
      expect(_run("'paul *0 silas"), isEmpty);
      expect(_run("'and *3 void"), [1]);
    });

    test('a gap really is unconstrained — the documented trap', () {
      // BibleWorks' forum failure case (`'!your *5 house`): the gap will
      // happily swallow the very word the ! was written to exclude, so
      // the query returns exactly what the reader meant to filter out.
      // Pinned so the echo's job — making this visible — is never a lie.
      expect(_run("'!and silas"), isEmpty,
          reason: 'with no gap, "and silas" is all there is');
      expect(_run("'!and *2 silas"), [4, 5],
          reason: 'the *2 matches the very "and" the ! was meant to rule out');
    });

    test('a phrase of nothing but gaps is refused', () {
      expect(_issue("'* *2"), CommandIssue.emptyBody);
    });
  });

  group(';N verse context', () {
    test('0 by default — all terms in one verse', () {
      expect(parseCommandQuery('.paul silas').query!.verseContext, 0);
      expect(_run('.paul barnabas'), isEmpty);
    });

    test('widens an AND search to a window, and lists both verses', () {
      // Paul is in verse 4, Barnabas in verse 5.
      expect(_run('.paul barnabas;1'), [4, 5]);
      expect(_run('.paul barnabas;0'), isEmpty);
    });

    test('a window never crosses a book boundary', () {
      // "earth" is Genesis 1:1-2, "Silas" is Acts. Indices 3 and 4 are
      // adjacent in the array but in different books.
      expect(_run('.god silas;4'), [4, 5],
          reason: 'both Acts verses are inside the window, and both hold a term');
      expect(_run('.beginning silas;10'), isEmpty,
          reason: 'Genesis 1:1 is four verses from Acts 16:25 in the array, '
              'and no window may span the two books');
    });

    test('a NOT term still excludes on the verse, not the window', () {
      // Barnabas is one verse from Paul; the context must not quietly
      // subtract the Paul verse as it widens.
      expect(_run('.paul silas !barnabas;5'), [4]);
    });

    test('a context on an OR search is dropped, not applied', () {
      final q = parseCommandQuery('/paul barnabas;5').query!;
      expect(q.verseContext, 0,
          reason: 'every verse qualifies alone, so there is no window');
    });

    test('a linear phrase may cross a verse boundary', () {
      // "…sang praises unto God." / "And Barnabas departed…"
      expect(_run(';god and barnabas;1'), [4]);
      expect(_run(';god and barnabas'), isEmpty,
          reason: 'without a context it must stay inside one verse');
    });

    test('a cross-verse phrase is reported at the verse it starts in', () {
      expect(_run(';praises unto god and barnabas;2'), [4]);
    });
  });

  group('Chinese, which BibleWorks never answered', () {
    List<int> runCjk(String raw) =>
        _run(raw, texts: _cjkTexts, books: _cjkBooks);

    test('a one-character term is that character anywhere', () {
      expect(runCjk('.光'), [1, 2]);
    });

    test('two characters written together are a run, not two terms', () {
      expect(runCjk('.世人'), [3]);
      expect(runCjk('.起初'), [0]);
    });

    test('two characters written apart are two independent terms', () {
      expect(runCjk('.神 光'), [1, 2]);
      expect(runCjk('.神光'), isEmpty,
          reason: '神光 never occurs as a run');
    });

    test('a Chinese phrase is an exact character run', () {
      expect(runCjk("'神说要有光"), [1]);
      expect(runCjk("'要有光神说"), isEmpty);
    });

    test('a Chinese phrase steps over the ideographic comma', () {
      // 神说、要有光 — the 、 occupies no token position.
      expect(runCjk("'说要有光"), [1]);
    });

    test('a wildcard between characters is a gap, not a letter pattern', () {
      // English wildcards live inside a word; Chinese has no inside, so
      // `*` and `?` glued between Han characters can only mean positions.
      expect(runCjk("'神*光"), [1, 2]); // 神…光, any distance
      expect(runCjk("'神?光"), [2], reason: '神看光 — exactly one between');
    });

    test('a lone ? is a one-letter word, not a wildcard slot', () {
      // The counterpart of the rule above: outside a CJK term a bare `?`
      // must stay an ordinary pattern. Reading it as "any word" would
      // make `.?` match every verse in the Bible.
      expect(_run('.?'), isEmpty, reason: 'no one-letter words in the fixture');
      expect(_run('.i'), isEmpty);
      expect(_run('.?n', texts: const ['In the beginning'], books: const ['Genesis']),
          [0]);
    });

    test('! excludes a Chinese term too', () {
      expect(runCjk('.神 !光'), [0, 3]);
    });

    test('the prefilter does not lose a hit across punctuation', () {
      // The regression this guards: concatenating a term's per-character
      // literals into "光暗" and testing `contains` would pass here, but
      // would fail the moment punctuation sat between the characters.
      // 就把光暗分开了 has them adjacent; 光、暗 would not.
      expect(runCjk('.光暗'), [2]);
      expect(
          _run('.光暗',
              texts: const ['神把光、暗分开了。'], books: const ['创世记']),
          [0],
          reason: 'tokens are adjacent even when the characters are not');
    });
  });

  group('the echo says what the query means', () {
    String echo(String raw, [String locale = 'en']) =>
        describeCommandQuery(parseCommandQuery(raw).query!, locale);

    test('AND lists the words', () {
      expect(echo('.love god'), 'All of: love, god');
    });

    test('OR says either', () {
      expect(echo('/faith works'), 'Any of: faith, works');
    });

    test('a phrase reads in order', () {
      expect(echo("'and god said"), 'In order: and · god · said');
    });

    test('the gap is spelled out, which is the whole point', () {
      expect(echo("'love *3 god"),
          'In order: love · any 3 or fewer words · god');
      expect(echo("'jesus * christ"), 'In order: jesus · any 1 words · christ');
    });

    test('a phrase ! is read as the slot it fills', () {
      expect(echo("'!the god"), 'In order: any word but the · god');
    });

    test('an AND ! is read as an exclusion', () {
      expect(echo('.jesus !christ'), 'All of: jesus · without: christ');
    });

    test('the verse context is stated', () {
      expect(echo('.paul silas;10'), 'All of: paul, silas · within 10 verses');
    });

    test('it is localised', () {
      // Only the frame is localised; the terms are echoed exactly as the
      // reader typed them, which is the point of an echo.
      expect(echo('.爱 神', 'zh-Hans'), '同时包含：爱、神');
      expect(echo('.保罗 西拉;10', 'zh-Hant'), '同時包含：保罗、西拉 · 相隔 10 節以內');
    });
  });

  group('issues are explained, and only real ones', () {
    test('notACommand has nothing to say', () {
      expect(describeCommandIssue(CommandIssue.notACommand, 'en'), isNull);
    });

    test('every other issue has text in all three locales', () {
      for (final issue in CommandIssue.values) {
        if (issue == CommandIssue.notACommand) continue;
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          final text = describeCommandIssue(issue, locale);
          expect(text, isNotNull, reason: '$issue / $locale');
          expect(text, isNotEmpty, reason: '$issue / $locale');
        }
      }
    });

    test('the context ceiling quotes the real limit', () {
      expect(describeCommandIssue(CommandIssue.contextTooLarge, 'en'),
          contains('$kMaxVerseContext'));
    });
  });

  group('diacritics drop out of the comparison', () {
    // BibleWorks' default too: "vowel point sensitive searching" is a
    // setting you turn on, not one you turn off.
    test('a pointed Hebrew query matches unpointed text and vice versa', () {
      const pointed = 'בְּרֵאשִׁית בָּרָא אֱלֹהִים';
      const bare = 'בראשית ברא אלהים';
      expect(foldDiacritics(pointed), bare);
      expect(
          _run('.בְּרֵאשִׁית', texts: const [bare], books: const ['Genesis']), [0]);
      expect(
          _run('.בראשית', texts: const [pointed], books: const ['Genesis']),
          [0]);
    });

    // #321. The app's Greek edition is set without accents; every Greek
    // word the app SHOWS carries them. Typed as displayed, `ὁ θεός` used
    // to find nothing at all.
    test('an accented Greek query matches unaccented text', () {
      const bare = ['εν αρχη εποιησεν ο θεος τον ουρανον και την γην'];
      const books = ['Genesis'];
      expect(_run("'ὁ θεός", texts: bare, books: books), [0]);
      expect(_run('.ἐποίησεν', texts: bare, books: books), [0]);
      expect(_run('.οὐρανὸν', texts: bare, books: books), [0]);
    });

    test('an unaccented Greek query still matches accented text', () {
      const accented = ['Ἐν ἀρχῇ ἐποίησεν ὁ θεὸς τὸν οὐρανὸν καὶ τὴν γῆν'];
      const books = ['Genesis'];
      expect(_run("'ο θεος", texts: accented, books: books), [0]);
      expect(_run("'ὁ θεὸς", texts: accented, books: books), [0]);
    });

    test('the accented and unaccented queries return the SAME verses', () {
      // The claim the fix is actually making. Both spellings, both
      // corpora, one answer.
      const corpora = <List<String>>[
        ['εν αρχη εποιησεν ο θεος τον ουρανον', 'και ειπεν ο θεος γενηθητω φως'],
        ['Ἐν ἀρχῇ ἐποίησεν ὁ θεὸς τὸν οὐρανὸν', 'καὶ εἶπεν ὁ θεός γενηθήτω φῶς'],
      ];
      for (final texts in corpora) {
        final books = [for (final _ in texts) 'Genesis'];
        expect(_run("'ὁ θεός", texts: texts, books: books),
            _run("'ο θεος", texts: texts, books: books));
        expect(_run("'ὁ θεός", texts: texts, books: books), [0, 1]);
      }
    });

    test('Latin accents fold too', () {
      const texts = ['the word is agápē', 'the word is agape'];
      const books = ['John', 'John'];
      expect(_run('.agape', texts: texts, books: books), [0, 1]);
      expect(_run('.agápē', texts: texts, books: books), [0, 1]);
    });

    test('the echo still quotes the accents the reader typed', () {
      // The fold lives in the comparison layer. `source` is what the UI
      // prints back, and it must not lose a breathing.
      final q = parseCommandQuery("'ὁ θεός").query!;
      expect(q.terms.map((t) => t.source), ['ὁ', 'θεός']);
      expect(q.terms.first.elements.length, 1);
    });

    test('folding cannot invent a hit across a word it does not contain', () {
      const texts = ['and God created', 'and god saw'];
      const books = ['Genesis', 'Genesis'];
      expect(_run('.θεος', texts: texts, books: books), isEmpty);
    });
  });

  group('the prefilter never costs a hit', () {
    test('a term with no literal still scans everything', () {
      // `.*` has nothing to prefilter on, so every verse must be tried.
      expect(_run('.*'), [0, 1, 2, 3, 4, 5]);
    });

    test('it does cut the work when it can', () {
      final parse = parseCommandQuery('.beginning');
      final result = runCommandQuery(
        query: parse.query!,
        texts: _texts,
        searchKeys: _keys(_texts),
        books: _books,
      );
      expect(result.indices, [0]);
      expect(result.tokenized, 1,
          reason: 'five of six verses rejected without tokenizing');
    });
  });
}
