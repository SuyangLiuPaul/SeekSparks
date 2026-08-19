import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/compound_query.dart';

/// The command line against the real 31,102-verse KJV.
///
/// `command_query_test.dart` pins the *mechanics* on a six-verse fixture,
/// where every expectation can be read off the corpus by eye. It cannot
/// tell you whether the grammar answers a real question, because a corpus
/// with no noise in it cannot be over- or under-matched.
///
/// These pin the *answers*: phrases whose occurrences in the KJV are a
/// matter of record, and which would break silently if the tokenizer, the
/// gap arithmetic, the window clipping or — most likely of all — the
/// prefilter drifted. The prefilter is the dangerous one: it is an
/// optimisation that decides which verses are never looked at, so a bug in
/// it does not throw, it just quietly returns fewer verses.
void main() {
  late List<String> texts;
  late List<String> keys;
  late List<String> books;
  late List<String> refs;

  setUpAll(() {
    final list =
        jsonDecode(File('assets/kjv.json').readAsStringSync()) as List;
    texts = [for (final v in list) sanitizeForSearch(v['text'] as String)];
    keys = [for (final t in texts) t.replaceAll(' ', '').toLowerCase()];
    books = [for (final v in list) v['book'] as String];
    refs = [
      for (final v in list) '${v['book']} ${v['chapter']}:${v['verse']}',
    ];
  });

  CommandSearchResult run(String raw) {
    final parse = parseCommandQuery(raw);
    expect(parse.query, isNotNull, reason: '"$raw": ${parse.issue}');
    return runCommandQuery(
        query: parse.query!, texts: texts, searchKeys: keys, books: books);
  }

  List<String> hits(String raw) =>
      [for (final i in run(raw).indices) refs[i]];

  test('the corpus is the whole KJV', () {
    expect(texts, hasLength(31102));
  });

  group('a phrase finds the phrase, and only the phrase', () {
    test('a formula nobody disputes', () {
      final found = hits("'in the beginning");
      expect(found, hasLength(17));
      // The three that open a book, plus Judges 7:19 to show the phrase
      // is not being anchored to the start of a verse.
      expect(found,
          containsAll(<String>['Genesis 1:1', 'John 1:1', 'Judges 7:19']));
    });

    test('word order is the whole difference between . and \'', () {
      // The bag of words is common; the sequence is not. If these two
      // ever returned the same thing the phrase operator would be dead
      // code and nobody would notice.
      final phrase = hits("'the son of man");
      final and = hits('.the son of man');
      expect(phrase, hasLength(94));
      expect(and, hasLength(244));
      expect(and, containsAll(phrase));
      expect(phrase, contains('Matthew 8:20'));
      expect(and, contains('Numbers 27:18'),
          reason: '"son of Nun" — the four words, not the phrase');
    });

    test('a phrase steps over punctuation, which is why it is tokens', () {
      // Ecclesiastes 1:2 prints "Vanity of vanities, saith the Preacher,
      // vanity of vanities; all is vanity." The comma and the semicolon
      // sit inside the phrase and must occupy no position.
      expect(hits("'saith the preacher vanity of vanities"),
          ['Ecclesiastes 1:2']);
    });
  });

  group('the gap is the reason the phrase operator earns its keep', () {
    test('an inserted word does not break the quotation', () {
      // Isaiah 7:14 "shall call his name Immanuel" is quoted by Matthew
      // 1:23 as "shall call his name Emmanuel" — but the KJV Isaiah reads
      // "and shall call", Matthew "and they shall call".
      expect(hits("'and *1 shall call his name"),
          containsAll(<String>['Isaiah 7:14', 'Matthew 1:23']));
      expect(hits("'and shall call his name"), isNot(contains('Matthew 1:23')));
    });

    test('a gap of zero is not the same as no gap at all', () {
      // `*0` still admits the adjacent case; it is a ceiling, not a floor.
      expect(hits("'the lord *0 god"), hits("'the lord god"));
    });
  });

  group('the verse context finds what a single verse cannot', () {
    test('two names that never share a verse', () {
      // Melchizedek blesses Abram across Genesis 14:18-19: the priest is
      // named in one verse and the man he blesses in the next, so the
      // single-verse search cannot see the encounter at all.
      expect(hits('.melchizedek abram'), isEmpty);
      expect(hits('.melchizedek abram;2'), ['Genesis 14:18', 'Genesis 14:19'],
          reason: 'and both verses are reported, not just the first');
    });

    test('a window never leaves its book', () {
      // Malachi 4:6 is the last verse of the Old Testament and Matthew
      // 1:1 the first of the New — adjacent in the array, 400 years and
      // two testaments apart in fact. Malachi 4:6 ends "with a curse";
      // Matthew 1:1 is "the book of the generation". A three-verse
      // context would join them if the book name were not re-checked.
      final malachi = refs.indexOf('Malachi 4:6');
      expect(books[malachi + 1], 'Matthew');
      expect(hits('.curse generation'), isEmpty);
      final near = hits('.curse generation;3');
      expect(near, isNotEmpty, reason: 'the context does find real pairs');
      expect(near, isNot(contains('Malachi 4:6')));
      expect(near, isNot(contains('Matthew 1:1')));
    });
  });

  group('the prefilter never costs a hit', () {
    // Every claim here is "the fast path agrees with the slow one". The
    // slow one is the same engine with the context set to something that
    // forces per-term scanning, or a term whose literal is empty.
    test('a wildcard term agrees with its expansion', () {
      final wild = hits('.faith*').toSet();
      final plain = <String>{
        ...hits('.faith'),
        ...hits('.faithful'),
        ...hits('.faithfully'),
        ...hits('.faithfulness'),
        ...hits('.faithless'),
      };
      expect(wild, containsAll(plain));
    });

    test('a leading wildcard still has something to filter on', () {
      // The literal core is the longest PLAIN RUN, not a prefix, so
      // `*eous` is still filtered by `contains("eous")`. Worth pinning:
      // the obvious implementation (take the prefix up to the first
      // metacharacter) would degrade this query to a full scan.
      final r = run('.*eous');
      expect(r.tokenized, lessThan(1000));
      expect([for (final i in r.indices) refs[i]], contains('Genesis 7:1'),
          reason: '"thee have I seen righteous before me"');
    });

    test('a term with no literal at all is still scanned in full', () {
      // `?` is one character, and one character is no substring to test.
      // The assertion is that the empty-core branch falls back to the
      // whole corpus rather than silently returning nothing.
      final r = run('.?');
      expect(r.tokenized, 31102, reason: 'nothing to prefilter on');
      expect(r.indices, hasLength(11538));
      expect([for (final i in r.indices) refs[i]], contains('Genesis 1:6'),
          reason: '"a firmament" — the one-letter word is real');
    });

    test('a literal core cuts the work by orders of magnitude', () {
      final r = run('.melchizedek');
      // The KJV spells the New Testament occurrences "Melchisedec", so
      // this is two verses and not eleven.
      expect([for (final i in r.indices) refs[i]],
          ['Genesis 14:18', 'Psalms 110:4']);
      expect(r.tokenized, lessThan(50),
          reason: 'the whole point of the prefilter');
    });
  });

  group('compound searches over the whole KJV (bwh16)', () {
    // bwh16's own worked example, run against the corpus it was written
    // about. These numbers are the record: the feature's entire claim is
    // that a distance between two SEARCHES finds passages that no single
    // verse could, and only a real corpus can show that it does.
    List<int> compound(String raw) {
      final p = parseCompoundQuery(raw);
      expect(p.query, isNotNull, reason: '"$raw": ${p.issue}');
      return runCompoundQuery(
              query: p.query!, texts: texts, searchKeys: keys, books: books)
          .indices;
    }

    test('a distance finds far more than the same verse does', () {
      // 24 verses hold grace-and-works AND jesus-or-christ. 159 lie
      // within fifteen verses of such a passage. Those extra 135 are the
      // feature: they share no word with the other group.
      expect(compound('(.grac* work*;5).(/jesus christ)'), hasLength(24));
      expect(compound('(.grac* work*;5).15(/jesus christ)'), hasLength(159));
    });

    test('swapping the groups changes the answer', () {
      // The fact no list of verses can show, and the reason the echo
      // says which side it is listing. Same two searches, same distance.
      expect(compound('(.grac* work*;5).15(/jesus christ)'), hasLength(159));
      expect(compound('(/jesus christ).15(.grac* work*;5)'), hasLength(82));
    });

    test('the union is exactly the two groups minus their overlap', () {
      // An independent check on both set operations at once: if the
      // union double-counted, or the intersection were approximate, this
      // identity would not hold to the verse.
      final left = compound('(.grac* work*;5)/(.nonexistentword)');
      final right = compound('(/jesus christ)/(.nonexistentword)');
      final union = compound('(.grac* work*;5)/(/jesus christ)');
      final both = compound('(.grac* work*;5).(/jesus christ)');
      expect(left, hasLength(116));
      expect(right, hasLength(1208));
      expect(union, hasLength(left.length + right.length - both.length));
      expect(union, hasLength(1300));
    });

    test('every group reports its own count, so an empty half is nameable', () {
      final r = runCompoundQuery(
        query: parseCompoundQuery('(.grace).(.nonexistentword)').query!,
        texts: texts,
        searchKeys: keys,
        books: books,
      );
      // 159 VERSES, not the 170 OCCURRENCES a concordance reports for
      // "grace" in the KJV. A group count is a verse count, like every
      // other number the command line prints.
      expect(r.groupCounts, [159, 0]);
      expect(r.indices, isEmpty);
    });

    test('a compound stays interactive', () {
      // Every group is a separate pass, which is why there is a ceiling
      // on how many a line may hold. The measured worst case above is
      // two passes plus a join at ~140ms.
      final sw = Stopwatch()..start();
      compound('(.grac* work*;5).15(/jesus christ)');
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'took ${sw.elapsedMilliseconds}ms');
    });
  });

  test('the worst realistic query stays interactive', () {
    // Three common words, a wildcard, and a ten-verse context — the
    // shape that makes every operator do work at once.
    final sw = Stopwatch()..start();
    run('.lord god israel*;10');
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(3000),
        reason: 'took ${sw.elapsedMilliseconds}ms');
  });
}
