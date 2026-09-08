/// The GSE ordering box's punctuation test on the command line —
/// `lib/utils/punctuation_gate.dart`, driven through `%-` and `%+` in
/// `lib/utils/command_query.dart`.
///
/// Every expectation about what the test EXCLUDES is read off a real
/// verse of a shipped asset and cited by reference, because the whole
/// failure mode of a filter is that it returns a shorter list and a
/// shorter list looks like a better one. A test that only asserted
/// `isNotEmpty` would pass on a gate that excluded the wrong half.
///
/// The corpora are built the way `MainProvider` builds them —
/// `sanitizeForSearchKey` for the text (punctuation intact, markup gone)
/// and `searchCorpusKey` for the prefilter — so a change to either
/// pipeline shows up here rather than being papered over by a fixture.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/phrase_match.dart' show phraseTokens;
import 'package:seeksparks/utils/punctuation_gate.dart';

void main() {
  late List<String> texts;
  late List<String> keys;
  late List<String> books;
  late List<String> refs;
  late List<String> cnTexts;
  late List<String> cnKeys;
  late List<String> cnBooks;
  late List<String> cnRefs;

  setUpAll(() {
    final kjv = jsonDecode(File('assets/kjv.json').readAsStringSync()) as List;
    texts = [for (final v in kjv) sanitizeForSearchKey(v['text'] as String)];
    keys = [for (final v in kjv) searchCorpusKey(v['text'] as String)];
    books = [for (final v in kjv) v['book'] as String];
    refs = [for (final v in kjv) '${v['book']} ${v['chapter']}:${v['verse']}'];

    final cuv =
        jsonDecode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List;
    cnTexts = [for (final v in cuv) sanitizeForSearchKey(v['text'] as String)];
    cnKeys = [for (final v in cuv) searchCorpusKey(v['text'] as String)];
    cnBooks = [for (final v in cuv) v['book'] as String];
    cnRefs = [
      for (final v in cuv) '${v['book']} ${v['chapter']}:${v['verse']}'
    ];
  });

  List<String> hits(String raw, {bool chinese = false}) {
    final parse = parseCommandQuery(raw);
    expect(parse.query, isNotNull, reason: '"$raw" was refused: ${parse.issue}');
    final result = runCommandQuery(
      query: parse.query!,
      texts: chinese ? cnTexts : texts,
      searchKeys: chinese ? cnKeys : keys,
      books: chinese ? cnBooks : books,
    );
    return [for (final i in result.indices) (chinese ? cnRefs : refs)[i]];
  }

  CommandIssue? issueOf(String raw) => parseCommandQuery(raw).issue;

  // ── The ratchet ────────────────────────────────────────────────────

  group('the default is exactly what it was before the gate existed', () {
    // These counts were measured against the corpus on 2026-09-08 with
    // the punctuation code absent, and they are the whole promise of this
    // change: a reader who never types % must not be able to tell that
    // anything happened. They are absolute rather than `isNotEmpty` for
    // the reason `command_grammar_audit_test.dart` gives — a filter bug
    // does not throw, it returns a number.
    const before = <String, int>{
      "'in the beginning": 17,
      "'night *5 morning": 10,
      "'day *2 darkness": 6,
      "'the son of man": 94,
      '.faith works': 15,
      '.paul silas;10': 35,
      "'night *5 morning;1": 11,
      '/mercy truth': 461,
    };

    test('every query measured before the change still returns its count',
        () {
      for (final entry in before.entries) {
        expect(hits(entry.key), hasLength(entry.value),
            reason: 'the count for "${entry.key}" moved');
      }
    });

    test('and the Chinese ones do too', () {
      expect(hits("'夜 *1 晚", chinese: true), hasLength(2));
      expect(hits("'晚 *2 早", chinese: true), hasLength(11));
      expect(hits('.爱 神', chinese: true), hasLength(159));
      expect(hits("'神爱世人", chinese: true), ['约翰福音 3:16']);
    });

    test('a query that never mentions punctuation carries an inactive gate',
        () {
      for (final raw in before.keys) {
        final gate = parseCommandQuery(raw).query!.punctuation;
        expect(gate.mode, PunctuationMode.allow, reason: raw);
        expect(gate.isActive, isFalse, reason: raw);
      }
    });

    test('a bare % still means nothing at all, as it always did', () {
      // The mode character is mandatory precisely so that this stays
      // true: `%` on its own is dropped as ordinary punctuation, and
      // `.love %` has always answered the same as `.love`.
      expect(hits('.love %'), hasLength(hits('.love').length));
      expect(hits('.love %'), hasLength(280));
      expect(parseCommandQuery('.love %').query!.punctuation.isActive, isFalse);
    });

    test('and neither does a % in front of anything but a mode character',
        () {
      // `%5`, `%a`, `%%` are not markers, so they fall through to the
      // handling they had yesterday rather than becoming refusals.
      for (final raw in ['.love %5', '.love %a', '.love %%']) {
        expect(parseCommandQuery(raw).issue, isNull, reason: raw);
        expect(parseCommandQuery(raw).query!.punctuation.isActive, isFalse,
            reason: raw);
      }
    });
  });

  // ── English: the sentence boundary that Allow crosses ──────────────

  group('a full stop between two words of an English phrase', () {
    // KJV Genesis 1:5 reads:
    //   "And God called the light Day, and the darkness he called Night.
    //    And the evening and the morning were the first day."
    // "Night" and "morning" are five tokens apart — and, the, evening,
    // and, the — so `*5` reaches from one to the other. What lies between
    // them is a full stop, and two different sentences.
    test('is found in Allow mode, which is what happens today', () {
      expect(hits("'night *5 morning"), contains('Genesis 1:5'));
    });

    test('is excluded in Exclude mode', () {
      expect(hits("'night *5 morning %-"), isNot(contains('Genesis 1:5')));
    });

    test('and Exclude removes that verse and only that verse', () {
      // Exodus 10:13 ("all that night; and when it was morning"),
      // Leviticus 6:9 ("all night unto the morning") and Leviticus 19:13
      // ("all night until the morning") are the same five-word reach
      // inside one sentence, and must survive. A gate that took them too
      // would still have "passed" the test above.
      final allow = hits("'night *5 morning");
      final exclude = hits("'night *5 morning %-");
      expect(allow, hasLength(10));
      expect(exclude, hasLength(9));
      expect(allow.toSet().difference(exclude.toSet()), {'Genesis 1:5'});
      expect(exclude,
          containsAll(['Exodus 10:13', 'Leviticus 6:9', 'Leviticus 19:13']));
    });

    test('is the only thing Require mode keeps', () {
      // The mirror image, which is the check that Exclude is not simply
      // returning everything it was given minus a coincidence.
      expect(hits("'night *5 morning %+"), ['Genesis 1:5']);
    });
  });

  group('the marks the English default deliberately leaves out', () {
    // Genesis 1:5 again, the other half of the same verse: "called the
    // light Day, and the darkness". Day and darkness are two tokens
    // apart and a comma lies between them, inside one sentence.
    test('a comma does not break a phrase', () {
      expect(hits("'day *2 darkness %-"), contains('Genesis 1:5'));
    });

    test('nor does the KJV colon, which is a pause and not a full stop', () {
      // Psalm 139:12: "but the night shineth as the day: the darkness and
      // the light are both alike to thee." The colon there is doing the
      // work a modern text gives a semicolon; treating it as a sentence
      // end would cut a single clause in half.
      expect(hits("'day *2 darkness %-"), contains('Psalms 139:12'));
    });

    test('so Exclude changes nothing for a phrase with no full stop in it',
        () {
      expect(hits("'day *2 darkness %-"), hasLength(6));
    });

    test('until the reader asks for those marks by hand', () {
      // bwh21's "Custom punctuation", which overrides the group. Both
      // verses above go, and they go because the reader said so.
      final custom = hits("'day *2 darkness %-,:;");
      expect(custom, isNot(contains('Genesis 1:5')));
      expect(custom, isNot(contains('Psalms 139:12')));
      expect(custom.length, lessThan(6));
    });
  });

  // ── Chinese ────────────────────────────────────────────────────────

  group('the 和合本, where the default set is not the English one', () {
    // 创世纪 1:5 (assets/cuvs-yhwh.json) reads:
    //   神称光为“昼”，称暗为“夜”。有晚上，有早晨，这是头一日。
    // It carries both cases in one verse. 夜 and 晚 are within one token
    // of each other with 。 between them — two sentences. 晚 and 早 are
    // within two tokens of each other with ，between them — one sentence,
    // and the parallel members of a single Hebrew line.
    test('。 between two characters is a sentence end', () {
      expect(hits("'夜 *1 晚", chinese: true), contains('创世纪 1:5'));
      expect(hits("'夜 *1 晚 %-", chinese: true),
          isNot(contains('创世纪 1:5')));
    });

    test('and 诗篇 127:2 survives it, because 夜晚 is one word', () {
      // 你们清晨早起，夜晚安歇 — the two characters are adjacent, nothing
      // lies between them at all, so the gate has nothing to find.
      expect(hits("'夜 *1 晚 %-", chinese: true), ['诗篇 127:2']);
    });

    test('， is NOT a sentence end, and the same verse proves it', () {
      // 有晚上，有早晨 — 59,017 fullwidth commas over 31,102 verses is
      // 1.9 per verse, so a default that broke on ，would answer a
      // question about sentences with an answer about clauses.
      expect(hits("'晚 *2 早 %-", chinese: true), contains('创世纪 1:5'));
      expect(hits("'晚 *2 早 %-", chinese: true), hasLength(11));
    });

    test('nor is 、, which separates the items of one noun phrase', () {
      // 马太福音 21:14: 在殿里有瞎子、瘸子到耶稣跟前。A rule that broke on
      // 、 would cut a list into pieces. Naming the mark by hand removes
      // the verse, which is what makes the default's silence about it a
      // decision rather than an accident.
      expect(hits("'瞎 *2 瘸 %-", chinese: true), contains('马太福音 21:14'));
      expect(hits("'瞎 *2 瘸 %-、", chinese: true),
          isNot(contains('马太福音 21:14')));
    });

    test('nor is ；, which joins the halves of a parallelism', () {
      // 箴言 4:7: 智慧为首；所以要得智慧。One sentence with two limbs, and
      // 9,318 of them sit in exactly the poetry a proximity search most
      // wants to reach across.
      expect(hits("'首 *2 以 %-", chinese: true), contains('箴言 4:7'));
      expect(hits("'首 *2 以 %-；", chinese: true),
          isNot(contains('箴言 4:7')));
    });

    test('and naming ， by hand does take 创世纪 1:5 away', () {
      // The other half of the same argument: the default leaves ，out on
      // purpose, and a reader who wants clause-tight proximity can have
      // it. 11 hits become 5.
      expect(hits("'晚 *2 早 %-，。", chinese: true), hasLength(5));
      expect(hits("'晚 *2 早 %-，。", chinese: true),
          isNot(contains('创世纪 1:5')));
    });

    test('the corpus contains no 「」 at all, so no rule may assume them',
        () {
      // The measurement the per-script default was written from: this
      // edition punctuates speech with “ ” and ‘ ’, and a set built for
      // 「」 would have been dead code.
      var corner = 0;
      var curly = 0;
      for (final t in cnTexts) {
        for (final ch in const ['「', '」', '『', '』']) {
          corner += ch.allMatches(t).length;
        }
        for (final ch in const ['“', '”']) {
          curly += ch.allMatches(t).length;
        }
      }
      expect(corner, 0);
      expect(curly, greaterThan(10000));
    });
  });

  // ── Crossing a verse boundary ──────────────────────────────────────

  group('a ;N phrase that runs out of its own verse', () {
    test('still knows where the sentence ends', () {
      // The reason this matters more here than it did in BibleWorks: `;1`
      // lets the phrase run on into the next verse, and the join between
      // two verses is almost always a full stop. `'night *5 morning;1`
      // finds Isaiah 21:11 — "Watchman, what of the night?" closing verse
      // 11 and "The morning cometh" opening verse 12 — which
      // `'night *5 morning` does not, because the two words are in
      // different verses AND different sentences.
      final wide = hits("'night *5 morning;1");
      final narrow = hits("'night *5 morning");
      expect(wide, hasLength(11));
      expect(narrow, hasLength(10));
      expect(wide.toSet().difference(narrow.toSet()), {'Isaiah 21:11'});
      expect(hits("'night *5 morning;1 %-"),
          isNot(contains('Isaiah 21:11')),
          reason: 'the verse join carries the end of the previous sentence');
    });

    test('and the nine one-verse hits survive the wider window', () {
      // The guard against the failure that made this group worth writing:
      // widening the window must not lose the verses the narrow search
      // already found. It did, silently, while `;1 %-` was being parsed
      // as the word "morning" followed by the word "1" — the query
      // returned an empty list and every `isNot(contains(...))`
      // expectation passed on the strength of it.
      expect(hits("'night *5 morning;1 %-"), hasLength(9));
      expect(hits("'night *5 morning;1 %-"),
          containsAll(hits("'night *5 morning %-")));
    });

    test('the marker and the verse context may be written in either order',
        () {
      for (final raw in [
        "'night *5 morning;1 %-",
        "'night *5 morning %-;1",
        "'night %- *5 morning;1",
      ]) {
        final q = parseCommandQuery(raw).query!;
        expect(q.verseContext, 1, reason: raw);
        expect(q.punctuation.mode, PunctuationMode.exclude, reason: raw);
        expect(hits(raw), hasLength(9), reason: raw);
      }
    });

    test('and the flags line up one-for-one with the tokens', () {
      // The off-by-one this guards: verse i's trailing boundary and verse
      // i+1's leading boundary are the SAME boundary, so concatenating
      // two flag arrays naively would insert a phantom entry and shift
      // every test after the first join.
      const a = 'And God said, Let there be light: and there was light.';
      const b = 'And God saw the light, that it was good.';
      final ta = phraseTokens(a);
      final tb = phraseTokens(b);
      final ga = punctuationGapFlags(a, ta, PunctuationGate.off);
      final gb = punctuationGapFlags(b, tb, PunctuationGate.off);
      expect(ga, hasLength(ta.length + 1));
      expect(gb, hasLength(tb.length + 1));
      expect(ga.length - 1 + gb.length - 1 + 1, ta.length + tb.length + 1);
    });
  });

  // ── The mechanics of the gate itself ───────────────────────────────

  group('what counts as "between"', () {
    test('a full stop after the last word is not between anything', () {
      // Genesis 1:1 ends "…the heaven and the earth." A phrase that ends
      // a sentence has not crossed one, and a gate that read the trailing
      // boundary would reject every phrase at the end of a verse — which
      // is most of them.
      expect(hits("'in the beginning %-"), contains('Genesis 1:1'));
      expect(hits("'the heaven and the earth %-"), contains('Genesis 1:1'));
    });

    test('and neither is one before the first word', () {
      // Genesis 1:2 opens "And the earth was without form, and void." The
      // preceding verse's full stop is not inside this match.
      expect(hits("'and the earth %-"), contains('Genesis 1:2'));
    });

    test('a one-word span has no interior, so Exclude passes it', () {
      final gaps = [true, true, true];
      expect(PunctuationGate(PunctuationMode.exclude, '.').spanPasses(gaps, 1, 1),
          isTrue);
      expect(PunctuationGate(PunctuationMode.require, '.').spanPasses(gaps, 1, 1),
          isFalse);
    });

    test('an inactive gate passes everything it is shown', () {
      expect(PunctuationGate.off.spanPasses([true, true, true], 0, 2), isTrue);
    });

    test('a gap that could match at several widths is tried at all of them',
        () {
      // The correctness argument for testing punctuation at the END of a
      // match instead of filtering afterwards. `*3` can land on several
      // spans; if only the first were tested, a verse with a clean match
      // and an unclean one would be judged by whichever came first.
      const text = 'alpha. beta gamma delta alpha beta';
      final tokens = [for (final t in phraseTokens(text)) t.text];
      final gate = PunctuationGate(PunctuationMode.exclude, '.');
      final gaps = punctuationGapFlags(text, phraseTokens(text), gate);
      final sequence =
          parseCommandQuery("'alpha *3 beta %-").query!.sequence;
      expect(sequenceOccurs(tokens, sequence, gaps: gaps, gate: gate), isTrue,
          reason: 'the second alpha/beta pair is clean and must be found');
    });
  });

  // ── The syntax cannot be mistaken for anything else ────────────────

  group('the marker', () {
    test('may sit anywhere, because it modifies the whole search', () {
      expect(hits("'night %- *5 morning"), hasLength(9));
      expect(hits("'night *5 morning %-"), hasLength(9));
    });

    test('may not appear twice, because nothing says which one wins', () {
      expect(issueOf("'a *5 b %- %+"), CommandIssue.punctuationRepeated);
    });

    test('takes punctuation and nothing else after the mode', () {
      expect(issueOf("'a *5 b %-and"), CommandIssue.punctuationSetInvalid);
      expect(issueOf("'a *5 b %+神"), CommandIssue.punctuationSetInvalid);
      expect(issueOf("'a *5 b %-1"), CommandIssue.punctuationSetInvalid);
    });

    test('accepts the Hebrew marks bwh21 names, though nothing ships them yet',
        () {
      // sof pasuq and maqqef sit inside the Hebrew Unicode block, which
      // `isWordChar` claims wholesale so that a pointed word does not
      // shred into consonants. Without the carve-out this would be a
      // refusal rather than a query.
      final gate = parseCommandQuery("'a *5 b %-$kHebrewPunctuation")
          .query!
          .punctuation;
      expect(gate.mode, PunctuationMode.exclude);
      expect(gate.characters, kHebrewPunctuation);
    });

    test('needs an ordered search, exactly as the GSE ordering box does', () {
      // A merge box has no punctuation setting in BibleWorks either; a
      // bag of words has no single span for "between" to name.
      expect(issueOf('.love god %-'), CommandIssue.punctuationNeedsPhrase);
      expect(issueOf('/love god %+'), CommandIssue.punctuationNeedsPhrase);
      expect(parseCommandQuery("'love god %-").issue, isNull);
      expect(parseCommandQuery(';love god %-').issue, isNull);
    });

    test("cannot be combined with a Strong's tag, which carries no punctuation",
        () {
      expect(issueOf("'man@444 *3 god %-"),
          CommandIssue.punctuationWithStrongsTag);
    });

    test('survives a ;N verse context written flush against it', () {
      final q = parseCommandQuery("'night *5 morning %-;2").query!;
      expect(q.verseContext, 2);
      expect(q.punctuation.mode, PunctuationMode.exclude);
      expect(q.punctuation.isCustom, isFalse);
    });
  });

  group('the echo says what the gate is doing', () {
    // The results header is the only place a reader learns that a filter
    // subtracted something, so a mode with no sentence is a mode nobody
    // knows is on.
    test('names the concept when the set is the default', () {
      expect(describeCommandQuery(parseCommandQuery("'a *5 b %-").query!, 'en'),
          contains('not crossing a sentence end'));
      expect(describeCommandQuery(parseCommandQuery("'a *5 b %+").query!, 'en'),
          contains('crossing a sentence end'));
    });

    test('names the characters when the reader supplied them', () {
      expect(
          describeCommandQuery(parseCommandQuery("'a *5 b %-,;").query!, 'en'),
          contains(',;'));
    });

    test('says nothing at all when no gate was asked for', () {
      final plain = describeCommandQuery(parseCommandQuery("'a b").query!, 'en');
      expect(plain, isNot(contains('sentence')));
    });

    test('has a finished sentence in all three locales', () {
      for (final raw in ["'a *5 b %-", "'a *5 b %+", "'a *5 b %-,;"]) {
        for (final locale in <String>['en', 'zh-Hans', 'zh-Hant']) {
          final s = describeCommandQuery(parseCommandQuery(raw).query!, locale);
          expect(s, isNot(contains('{')), reason: '$raw in $locale');
          expect(s, isNotEmpty, reason: '$raw in $locale');
        }
      }
    });
  });
}
