// The passage→event join (#318 phase 25): which dated events in
// assets/bible_timeline.json narrate a chapter. Measured against the
// shipped asset, not fixtures — the numbers here are what the pane
// prints.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/utils/passage_events.dart';

/// Book names are the trivial half of a ref (everything before the first
/// whitespace-then-digit); extracting them is not the algorithm under
/// test — the risk `passage_events.dart` exists to guard is what happens
/// to the REST of the string. Extracted here only so the census below can
/// drive the real `eventsIn` over every candidate chapter instead of
/// re-implementing the parser a second time.
Set<String> _candidateBooks(List<TimelineEvent> events) {
  final bookSplit = RegExp(r'\s(?=\d)');
  final books = <String>{};
  for (final e in events) {
    for (final ref in e.refs) {
      final m = bookSplit.firstMatch(ref);
      if (m != null) books.add(ref.substring(0, m.start));
    }
  }
  return books;
}

// No book of the Bible has more than 150 chapters (Psalms).
const _maxChapter = 150;

void main() {
  final doc = json.decode(
    File('assets/bible_timeline.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final all = (doc['events'] as List)
      .whereType<Map<String, dynamic>>()
      .map(TimelineEvent.fromJson)
      .toList()
    ..sort((a, b) => a.year.compareTo(b.year));

  final books = _candidateBooks(all);

  test('the parser never turns a verse range into a chapter range', () {
    final gen15 = eventsIn('Genesis', 15, all).map((e) => e.id).toSet();
    expect(gen15, {'abrahamic_covenant', 'israel_oppressed'});
    expect(gen15.contains('eden'), isFalse);

    final matt5 = eventsIn('Matthew', 5, all).map((e) => e.id).toSet();
    expect(matt5, {'sermon_mount'});
    expect(matt5.contains('jesus_born'), isFalse);
  });

  test('a comma continuation adds no chapters', () {
    // Luke has 24 chapters; a naive reading of 'Luke 1:5-25, 57-80'
    // would put an event in chapter 57.
    expect(eventsIn('Luke', 57, all), isEmpty);
  });

  test('the census of covered chapters', () {
    final pairs = <(String, int)>{};
    final perChapterCount = <(String, int), int>{};
    for (final book in books) {
      for (var chapter = 1; chapter <= _maxChapter; chapter++) {
        final here = eventsIn(book, chapter, all);
        if (here.isEmpty) continue;
        final key = (book, chapter);
        pairs.add(key);
        perChapterCount[key] = here.length;
      }
    }
    expect(pairs, hasLength(324));
    expect(pairs.map((p) => p.$1).toSet(), hasLength(31));

    final dist = <int, int>{};
    for (final count in perChapterCount.values) {
      dist[count] = (dist[count] ?? 0) + 1;
    }
    expect(dist[1], 304);
    expect(dist[2], 20);
    expect(dist.keys.where((k) => k >= 3), isEmpty);
  });

  test('five events cite no scripture and that is correct', () {
    final reachable = <String>{};
    for (final book in books) {
      for (var chapter = 1; chapter <= _maxChapter; chapter++) {
        for (final e in eventsIn(book, chapter, all)) {
          reachable.add(e.id);
        }
      }
    }
    final unreachable =
        all.where((e) => !reachable.contains(e.id)).map((e) => e.id).toSet();
    expect(unreachable, {
      'greek_period',
      'intertestamental',
      'maccabees',
      'rome_judea',
      'septuagint',
    });
    for (final id in unreachable) {
      final e = all.firstWhere((e) => e.id == id);
      expect(e.refs, isEmpty);
    }
  });

  test('the bare book name contributes no chapter, and loses nothing', () {
    final tabernacle = all.firstWhere((e) => e.id == 'tabernacle');
    expect(tabernacle.refs, contains('Leviticus'));
    // No chapter of Leviticus reaches tabernacle through the bare ref.
    for (var chapter = 1; chapter <= 27; chapter++) {
      expect(
        eventsIn('Leviticus', chapter, all).map((e) => e.id),
        isNot(contains('tabernacle')),
      );
    }
    // Still reachable, via its Exodus ref.
    expect(
      eventsIn('Exodus', 25, all).map((e) => e.id),
      contains('tabernacle'),
    );
  });

  test('spot rows', () {
    expect(eventsIn('Genesis', 7, all).map((e) => e.id), ['flood']);
    expect(eventsIn('2 Kings', 17, all).map((e) => e.id), ['israel_falls']);
    expect(
      eventsIn('Exodus', 12, all).map((e) => e.id),
      ['plagues', 'exodus'],
    );
    expect(eventsIn('Genesis', 1, all).map((e) => e.id), ['creation']);
    expect(eventsIn('Joshua', 1, all), isEmpty);
    expect(eventsIn('Luke', 24, all), isEmpty);
  });

  test('refsHere names only refs that reach this chapter', () {
    final on = eventsIn('Genesis', 7, all);
    expect(on, hasLength(1));
    expect(on.single.refsHere, ['Genesis 6-9']);
  });
}
