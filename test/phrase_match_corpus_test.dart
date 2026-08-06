import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/phrase_match.dart';

/// Phrase matching against the real 31,102-verse KJV, rather than the
/// hand-built corpora in `phrase_match_test.dart`.
///
/// Those unit tests pin the *mechanics* — the gap, the dropped word, the
/// grouping. They cannot tell you whether the tool is any good, because a
/// six-verse corpus has no noise in it. These pin the *result*: for four
/// passages whose New Testament quotation is not in dispute, the quoting
/// verse must come out on top of 31,101 others. That is the claim the
/// feature actually makes, and the one that would break silently if the
/// tokenizer, the ordering or the noise cutoff drifted.
void main() {
  late List<String> corpus;
  late List<String> refs;

  setUpAll(() {
    final list =
        jsonDecode(File('assets/kjv.json').readAsStringSync()) as List;
    corpus = [for (final v in list) (v['text'] as String).trim()];
    refs = [
      for (final v in list) '${v['book']} ${v['chapter']}:${v['verse']}',
    ];
  });

  int indexOf(String ref) {
    final i = refs.indexOf(ref);
    expect(i, greaterThanOrEqualTo(0), reason: 'missing $ref');
    return i;
  }

  /// The references the tool ranks highest for [base], best first.
  List<String> top(String base, {int gap = 0, int take = 5}) {
    final index = buildPhraseMatchIndex(
      corpus: corpus,
      baseIndex: indexOf(base),
      phraseLength: 3,
      maxGap: gap,
    );
    final groups =
        groupPhraseHitsByVerse(index, defaultEnabledPhrases(index));
    return [for (final g in groups.take(take)) refs[g.verseIndex]];
  }

  test('Isaiah 7:14 finds the Matthew quotation ahead of the whole Bible', () {
    expect(top('Isaiah 7:14').first, 'Matthew 1:23');
  });

  test('Jeremiah 31:33 finds both Hebrews quotations, in Hebrews order', () {
    final hits = top('Jeremiah 31:33', gap: 1);
    expect(hits[0], 'Hebrews 8:10');
    expect(hits[1], 'Hebrews 10:16');
  });

  test('Psalm 22:1 finds the cry from the cross in both gospels', () {
    final hits = top('Psalms 22:1', gap: 1);
    expect(hits.take(2), containsAll(<String>['Matthew 27:46', 'Mark 15:34']));
  });

  test('a verse with no quotation still surfaces its real parallels', () {
    // Genesis 1:1 is quoted by nobody. What it has is other verses that
    // speak of "the heaven and the earth" — a true phrase match, not a
    // failure. The tool must neither invent a quotation nor return nothing.
    final hits = top('Genesis 1:1');
    expect(hits, isNotEmpty);
    expect(hits, contains('Jeremiah 32:17'));
    expect(hits, isNot(contains('Matthew 1:23')));
  });

  test('the commonest phrases in the Bible arrive unchecked', () {
    final index = buildPhraseMatchIndex(
      corpus: corpus,
      baseIndex: indexOf('Jeremiah 31:33'),
      phraseLength: 3,
      maxGap: 1,
    );
    final enabled = defaultEnabledPhrases(index);
    for (var i = 0; i < index.phrases.length; i++) {
      final phrase = index.phrases[i];
      // "the house of" is in 13,389 verses. Left on, it buries everything.
      if (phrase.display.toLowerCase() == 'the house of') {
        expect(enabled, isNot(contains(i)),
            reason: 'a phrase in ${phrase.verseCount} verses must start off');
      }
    }
    expect(enabled, isNotEmpty);
    expect(enabled.length, lessThan(index.phrases.length));
  });

  test('the longest verse in the Bible scans in reasonable time', () {
    // Esther 8:9 at gap 2 is the worst case the tool can be given: the most
    // tokens, hence the most phrases, each with the widest search. Measured
    // at ~320ms; the bound is loose enough not to flake on a slow machine
    // but tight enough to catch a return to exponential search.
    final sw = Stopwatch()..start();
    final index = buildPhraseMatchIndex(
      corpus: corpus,
      baseIndex: indexOf('Esther 8:9'),
      phraseLength: 3,
      maxGap: 2,
    );
    sw.stop();
    expect(index.hits, isNotEmpty);
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)),
        reason: 'took ${sw.elapsedMilliseconds}ms');
  });
}
