import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/search_service.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/psalm_superscription.dart';
import 'package:seeksparks/utils/romanised_lemma.dart';
import 'package:seeksparks/utils/vocabulary.dart';

/// The gate on the romanised offer, measured through the two search
/// engines it sits between.
///
/// `WorkbenchProvider._measureLemmaOffer` offers `agape` → G26 only
/// when the word occurs in NO verse. Which of the two available
/// answers to "occurs" is used decides whether the feature works at
/// all, and decides whether it can make a false etymological claim.
/// Both are pinned here against the real KJV, because both were wrong
/// once: a plain search is a substring match, so gating on an empty
/// result list would have silenced the offer for the words it exists
/// for, and gating on nothing at all would have offered H905 בַּד next
/// to English verses about bad figs.
void main() {
  List<Map<String, dynamic>> records(String asset) => [
        for (final e in json.decode(File(asset).readAsStringSync()) as List)
          (e as Map).cast<String, dynamic>(),
      ];

  MainProvider corpus(String asset) {
    final folded = foldSuperscriptions(records(asset));
    final verses = <Verse>[];
    for (final m in folded.records) {
      // The superscription fold leaves a non-numeric verse marker the
      // reader's model does not carry.
      if (int.tryParse(m['verse']?.toString() ?? '') == null) continue;
      verses.add(Verse.fromJson(m));
    }
    return MainProvider()..setVerses(verses);
  }

  late MainProvider kjv;
  late RomanisedLemmaIndex index;

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  setUpAll(() {
    kjv = corpus('assets/kjv.json');
    index = RomanisedLemmaIndex.fromWords(vocabularyFromAssets(
      concordance: readJson('assets/strongs/concordance.json'),
      hebrewLexicon: readJson('assets/strongs/hebrew.json'),
      greekLexicon: readJson('assets/strongs/greek.json'),
    ));
  });

  /// What a plain one-word search puts on the page.
  int plain(MainProvider mp, String word) => SearchService.scanText(
        verses: mp.verses,
        searchKeys: mp.searchKeys,
        query: word,
        bookOrder: mp.bookOrder,
        searchAll: true,
      ).matches.length;

  /// What the gate asks: the same word, read as a word, over the whole
  /// corpus.
  ///
  /// This is the same engine call `WorkbenchProvider._measureLemmaOffer`
  /// makes, not a re-implementation of the rule — but it is a corpus
  /// measurement rather than a test of the provider, so the two things
  /// it cannot see are pinned in `workbench_provider_test.dart`: that
  /// the provider consults this at all, and that it does so WITHOUT the
  /// reader's search limit (a scope made 152 of the words below look
  /// absent).
  int asWord(MainProvider mp, String word) {
    final query = parseCommandQuery('.$word').query;
    expect(query, isNotNull, reason: word);
    return runCommandQuery(
      query: query!,
      texts: mp.wordKeys,
      searchKeys: mp.searchKeys,
      books: [for (final v in mp.verses) v.book],
    ).indices.length;
  }

  test('a plain search matches inside words, so an empty page is still '
      'the wrong gate', () {
    // 2026-09-05 REMEASURED, and the reason is worth keeping. These
    // counts used to be 4, 3, 1, 1, 26, and most of that was the plain
    // scan stripping spaces before it matched: `these are`, `the
    // ostrich`, `these days`, `unto Rahab`, `Issachar is` are word gaps
    // the reader never typed, and `plain_search.dart` no longer steps
    // over them. Four of the five now return an empty page.
    //
    // `shalom` does not, and it is the whole argument in one word:
    // Judges 6:24 `Jehovahshalom` and 1 Kings 15:2 / 15:10 `Abishalom`
    // are matches INSIDE a word, which the boundary rule deliberately
    // keeps — they are markable, and a reader searching `shalom` can
    // see why the verse is there. So a gate on `textResults.isEmpty`
    // would still be wrong for שָׁלוֹם, and `_measureLemmaOffer` still
    // has to ask the word engine instead.
    //
    // The honest report: this fix narrowed the gate's necessity from
    // five words to two (`shalom`, and `hesed` below). It did not
    // remove it.
    expect(plain(kjv, 'theos'), 0);
    expect(plain(kjv, 'shalom'), 3);
    expect(plain(kjv, 'charis'), 0);
    expect(plain(kjv, 'torah'), 0);
    expect(plain(kjv, 'nabi'), 0);
  });

  test('read as words, those four occur nowhere, so the offer is made',
      () {
    for (final w in <String>['theos', 'shalom', 'charis', 'torah', 'nabi']) {
      expect(asWord(kjv, w), 0, reason: w);
    }
  });

  test('the cost of the honest gate, stated rather than hidden', () {
    // `hesed` really is an English KJV word — 1 Kings 4:10, "the son of
    // Hesed" — so a reader who types it over the KJV gets the verse and
    // no offer of H2617. That is the gate working: the alternative is
    // an app that claims a word it can see is absent. `chesed` is the
    // same, Genesis 22:22.
    expect(asWord(kjv, 'hesed'), 1);
    expect(asWord(kjv, 'chesed'), 1);
  });

  test('no word the KJV contains can produce an offer — all 1,814 of them',
      () {
    // The safety argument in full, not by sample. Take every distinct
    // KJV word of three letters or more, keep the ones that reach a
    // lexicon entry, and ask the gate about each. If a single one of
    // them read as a word came back zero, the gate would let a false
    // etymology through, and this is the only way to know it does not.
    // (Most of the 1,814 are the KJV's own transliterated names —
    // `abaddon` → G3, `abednego` → H5665 — which resolve correctly and
    // would be no defect. `bad`, `den`, `dove`, `gay` are.)
    final distinct = <String>{};
    for (final key in kjv.wordKeys) {
      for (final w in key.split(RegExp(r'[^A-Za-z]+'))) {
        if (w.length >= 3) distinct.add(w.toLowerCase());
      }
    }
    final resolving = <String>[
      for (final w in distinct)
        if (index.resolve(w).isNotEmpty) w,
    ];
    expect(distinct.length, 12546);
    expect(resolving.length, 1814);
    final absent = <String>[
      for (final w in resolving)
        if (asWord(kjv, w) == 0) w,
    ];
    expect(absent, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('every homograph the index could mis-resolve is a word the KJV has',
      () {
    // The false-etymology class. All three resolve to a Hebrew entry
    // that has nothing to do with the English word, and all three are
    // ordinary KJV words — which is exactly why the gate excludes them.
    for (final w in <String>['bad', 'den', 'dove', 'gay']) {
      expect(index.resolve(w), isNotEmpty, reason: w);
      expect(asWord(kjv, w), greaterThan(0), reason: w);
    }
  });
}
