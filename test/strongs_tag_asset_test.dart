/// The `@` Strong's tag binding against the SHIPPED assets.
///
/// `strongs_tag_binding_test.dart` proves the mechanics on a fixture
/// small enough to read. This file proves the join: `assets/bsb.json`
/// (the verse text the search engine sees) and
/// `assets/tagged/bsb/genesis.json` (the runs the tagger produced) are
/// two files built by two importers, and a `@` search is only worth
/// anything if their tokens line up. Nothing here would notice if they
/// stopped.
///
/// Genesis alone — 1,533 verses — because that is enough for the join to
/// be real and small enough that the counts below could be recomputed by
/// hand. Every expectation is an ABSOLUTE count for the reason
/// `command_grammar_audit_test.dart` gives: `isNotEmpty` passes on every
/// interesting way this can be wrong.
///
/// The runs are read straight out of the JSON rather than through
/// `TaggedTextService`, which needs a Flutter asset bundle. The one
/// transform that service applies on load — `reuniteGlossRuns` — is a
/// no-op on the BSB by measurement (it rewrites cuvs-yhwh and nothing
/// else), so what this test holds is what the app holds.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/text_patterns.dart'
    show sanitizeForSearchKey, searchCorpusKey;
import 'package:seeksparks/utils/command_query.dart';

void main() {
  late List<String> texts;
  late List<String> keys;
  late List<String> books;
  late List<String> refs;
  late List<List<TaggedToken>?> tagged;

  setUpAll(() {
    final verses = (jsonDecode(File('assets/bsb.json').readAsStringSync())
            as List)
        .cast<Map<String, dynamic>>()
        .where((v) => v['book'] == 'Genesis')
        .toList();
    final runsByVerse =
        jsonDecode(File('assets/tagged/bsb/genesis.json').readAsStringSync())
            as Map<String, dynamic>;

    texts = [for (final v in verses) sanitizeForSearchKey(v['text'] as String)];
    keys = [for (final v in verses) searchCorpusKey(v['text'] as String)];
    books = [for (final v in verses) v['book'] as String];
    refs = [for (final v in verses) 'Genesis ${v['chapter']}:${v['verse']}'];
    tagged = [
      for (final v in verses)
        () {
          final runs = runsByVerse['${v['chapter']}:${v['verse']}'] as List?;
          if (runs == null) return null;
          return taggedRunTokens([
            for (final r in runs.cast<Map<String, dynamic>>())
              (text: (r['w'] ?? '') as String, strongs: (r['s'] ?? '') as String),
          ]);
        }(),
    ];
  });

  CommandSearchResult run(String raw) {
    final parse = parseCommandQuery(raw);
    expect(parse.query, isNotNull, reason: '"$raw" was refused: ${parse.issue}');
    return runCommandQuery(
      query: parse.query!,
      texts: texts,
      searchKeys: keys,
      books: books,
      taggedTokens: parse.query!.usesStrongsTags ? (i) => tagged[i] : null,
    );
  }

  int count(String raw) => run(raw).indices.length;
  List<String> hits(String raw) => [for (final i in run(raw).indices) refs[i]];

  test('the two assets describe the same Genesis', () {
    // The join this whole feature rests on. A verse the tagger skipped
    // would answer every `@` query with silence, which is precisely the
    // failure `CommandSearchResult.candidatesWithoutTagging` exists to
    // make visible — and on the shipped BSB there are none.
    expect(texts.length, 1533);
    expect(tagged.where((t) => t == null), isEmpty);
    expect(run('.*@H430').candidatesWithoutTagging, 0);
  });

  test('Genesis 1:1, checked run by run against the JSON', () {
    // The BSB tags Gen 1:1 as six runs: "In the beginning"/H7225,
    // "God"/H430, "created"/H1254, "the heavens"/H8064, "and"/H853,
    // "the earth."/H776. Every claim below is read straight off that
    // line, and each one fails differently if the alignment slips.
    expect(hits('.beginning@H7225'), contains('Genesis 1:1'));
    expect(hits('.created@H1254'), contains('Genesis 1:1'));
    expect(hits('.earth@H776'), contains('Genesis 1:1'));
    // The wrong number for the right word, and the right number for the
    // wrong word. Both must miss.
    expect(hits('.earth@H8064'), isEmpty);
    expect(hits('.beginning@H1254'), isEmpty);
    // "the heavens" is one run, so both of its tokens answer to H8064 —
    // the run-granularity consequence, on real data.
    expect(hits('.heavens@H8064'), contains('Genesis 1:1'));
    expect(hits('.the@H8064'), contains('Genesis 1:1'));
  });

  test('a tag narrows a word, and a word narrows a tag', () {
    // Counts are VERSES, and they overlap: 199 verses of Genesis hold a
    // tagged "God", 180 of them hold one whose lemma is אֱלֹהִים, and 24
    // hold one whose lemma is something else — El, Yahweh, or a run the
    // tagger gave a different number. Neither `.god` nor a search for
    // H430 alone can tell those apart, which is why this operator
    // exists.
    expect(count('.god@H430'), 180);
    expect(count('.god@!H430'), 24);
    expect(count('.god@*'), 199);
    // And the other direction: H430 rendered by something other than
    // "God" — which in these assets is mostly the *of* of a multi-word
    // "of God" run, not an alternative rendering of the noun.
    expect(count('.*@H430'), 188);
    expect(count('.!god@H430'), 103);
  });

  test('the leading zero is load-bearing on real data', () {
    // `@0430` is Hebrew H430 and `@430` is Greek G430, and Genesis has
    // no Greek in it at all. A build that dropped BibleWorks' zero rule
    // would answer the first question with the second's empty list.
    expect(count('.god@0430'), 180);
    expect(count('.god@H430'), 180);
    expect(count('.god@430'), 0);
  });

  test('@- finds what the translators supplied', () {
    // bwh16's third application: "words that are not found in the
    // original text … supplied in the English translation for stylistic
    // reasons". In BSB Genesis those are overwhelmingly pronouns and
    // prepositions carried over from Hebrew morphology.
    expect(count('.*@-'), 278);
    expect(count('.to@-'), 85);
    // Every "God" in Genesis is tagged, so this is the honest zero — and
    // it is a different zero from the one an untagged EDITION would
    // give, which `WorkbenchProvider` refuses outright.
    expect(count('.god@-'), 0);
  });

  test('*@number lists every word the lemma was rendered by', () {
    // bwh16's headline example, in Hebrew. רֵאשִׁית is tagged in three
    // verses of Genesis; two of them say "beginning" and the third
    // (10:10) says "began", which is exactly the rendering a search for
    // the English word can never reach and a search for the number
    // cannot single out.
    expect(hits('.beginning@H7225'), ['Genesis 1:1', 'Genesis 49:3']);
    expect(hits('.*@H7225'), ['Genesis 1:1', 'Genesis 10:10', 'Genesis 49:3']);
  });

  test('an untagged query over the same corpus is unchanged', () {
    // The tagged token stream replaces the plain one for `@` queries, so
    // the two have to agree about what a word is. If they did not, these
    // three counts would move the day this feature landed.
    expect(count('.beginning'), 3);
    expect(count("'in the beginning"), 1);
    expect(count('.god light'), 5);
  });
}
