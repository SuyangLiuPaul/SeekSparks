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
      .toList();
  // Stable, exactly as `TimelineService.loadAll` sorts: four events
  // share -1446 and three share -1406, and only the asset's own order
  // says the plagues came before the departure. `List.sort` is not
  // stable in Dart, so a year-only comparator lets an edit anywhere in
  // the file reshuffle those groups.
  final assetOrder = {for (var i = 0; i < all.length; i++) all[i].id: i};
  all.sort((a, b) {
    final byYear = a.year.compareTo(b.year);
    return byYear != 0
        ? byYear
        : assetOrder[a.id]!.compareTo(assetOrder[b.id]!);
  });

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
    // 326 since 2026-09-02: `jesus_baptized` gained Luke 3:1, the verse
    // that creates the chart's own Tiberius/Pilate tension, so the
    // reader can open it from the record that discusses it. Luke 3 was
    // not reachable from the timeline before. A census is a
    // measurement — when it moves, the reason belongs here.
    expect(pairs, hasLength(326));
    expect(pairs.map((p) => p.$1).toSet(), hasLength(31));

    final dist = <int, int>{};
    for (final count in perChapterCount.values) {
      dist[count] = (dist[count] ?? 0) + 1;
    }
    // 305: the new Luke 3 pairing carries exactly one event, so the
    // whole of the census growth lands in this bucket.
    expect(dist[1], 305);
    expect(dist[2], 19);
    // Two chapters carry more. Genesis 5 IS the register of the line
    // from Adam to Noah, so the six generations added to the asset all
    // cite it, alongside Seth's birth and Enoch's walk. Genesis 4 gains
    // one — 4:26, the verse that dates "men began to call on the name
    // of God" to Enosh's generation. Shelah's birth brings Genesis 10
    // onto the chart for the first time (10:24) and gives Genesis 11 a
    // second record beside Babel.
    expect(perChapterCount[('Genesis', 5)], 8);
    expect(perChapterCount[('Genesis', 4)], 3);
    expect(dist.keys.where((k) => k >= 3).toSet(), {3, 8});
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
