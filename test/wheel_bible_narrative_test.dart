/// The Bible's own story on the chronology wheel (#318 phase 17).
///
/// The wheel drew 491 events of world history and, on the two bands
/// named for God's people, 18 records that between them held neither
/// the Exodus nor David nor the fall of Jerusalem nor a single verse
/// of the New Testament. `bible_timeline.json` held all of it and the
/// page never loaded the file. These tests pin the join: that every
/// curated event arrives, that each lands on a band the wheel
/// actually draws, that the one fact both assets tell is told once,
/// and that no year and no basis reaches the reader unhandled.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/models/wheel_history.dart';

Map<String, dynamic> _json(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final wheel = WheelHistoryData.fromJson(_json('assets/wheel_history.json'));
  final timeline = [
    for (final r in (_json('assets/bible_timeline.json')['events'] as List)
        .cast<Map<String, dynamic>>())
      TimelineEvent.fromJson(r)
  ];
  final injected = bibleNarrativeEvents(timeline);
  final merged = [...wheel.events, ...injected];

  group('every curated event arrives', () {
    test('injected + excluded accounts for the whole timeline', () {
      final ids = injected
          .map((e) => e.id.substring(kBibleEventIdPrefix.length))
          .toSet();
      expect(ids.union(kTimelineIdsAlreadyOnWheel),
          timeline.map((e) => e.id).toSet());
      expect(ids.intersection(kTimelineIdsAlreadyOnWheel), isEmpty);
    });

    // A rename in either asset must fail loudly, not quietly stop
    // excluding a duplicate or quietly stop applying an override.
    test('every id named in a constant exists in the timeline', () {
      final ids = timeline.map((e) => e.id).toSet();
      expect(ids, containsAll(kTimelineIdsAlreadyOnWheel));
      expect(ids, containsAll(kTimelineStreamOverrides.keys));
    });

    test('the merge adds the whole story and drops one duplicate', () {
      expect(injected, hasLength(timeline.length - 1));
      expect(injected, hasLength(97));
      expect(merged, hasLength(wheel.events.length + 97));
    });

    test('nothing arrives nameless', () {
      for (final e in injected) {
        expect(e.titleFor('en'), isNotEmpty, reason: e.id);
        expect(e.titleFor('zh-Hans'), isNotEmpty, reason: e.id);
        expect(e.titleFor('zh-Hant'), isNotEmpty, reason: e.id);
      }
    });
  });

  group('every event lands on a band the wheel draws', () {
    // The page keeps only events whose stream is in `ringOf`, built
    // from the asset's streams. A typo here would not throw; it would
    // silently drop the Exodus.
    test('every injected stream is a real stream', () {
      final streams = wheel.streams.map((s) => s.id).toSet();
      expect(streams, containsAll(injected.map((e) => e.stream).toSet()));
      expect(streams, containsAll(kTimelineEraStream.values.toSet()));
      expect(streams, containsAll(kTimelineStreamOverrides.values.toSet()));
    });

    test('every timeline era has a mapping', () {
      expect(kTimelineEraStream.keys.toSet(),
          containsAll(timeline.map((e) => e.era).toSet()));
    });

    test('no id collides with a wheel event', () {
      final wheelIds = wheel.events.map((e) => e.id).toSet();
      for (final e in injected) {
        expect(wheelIds.contains(e.id), isFalse, reason: e.id);
      }
      expect(merged.map((e) => e.id).toSet(), hasLength(merged.length));
    });

    test('the story reaches the bands that were missing it', () {
      String bandOf(String id) =>
          injected.firstWhere((e) => e.id == '$kBibleEventIdPrefix$id').stream;
      expect(bandOf('exodus'), 'israel');
      expect(bandOf('temple_built'), 'israel');
      expect(bandOf('kingdom_divided'), 'israel');
      expect(bandOf('israel_falls'), 'israel');
      expect(bandOf('judah_falls'), 'judah');
      expect(bandOf('crucifixion'), 'judah');
      expect(bandOf('creation'), 'world');
    });

    // Two records whose era is right and whose band would not be. Both
    // were found by reading the records rather than the era key.
    test('Job is not on Israel and the Septuagint is not in Judah', () {
      final job = injected
          .firstWhere((e) => e.id == '${kBibleEventIdPrefix}job_trial');
      expect(job.stream, 'world',
          reason: 'the record itself places Job in Uz, outside Israel');
      final lxx = injected
          .firstWhere((e) => e.id == '${kBibleEventIdPrefix}septuagint');
      expect(lxx.stream, 'scripture');
      // It becomes the earliest thing on that band, which had no record
      // of the Greek Old Testament before.
      final band = [...wheel.events, ...injected]
          .where((e) => e.stream == 'scripture')
          .map((e) => e.year);
      expect(lxx.year, band.reduce((a, b) => a < b ? a : b));
    });

    // After 931 BC the `monarchy` era covers two kingdoms; four of its
    // records are southern and would otherwise be drawn on a band
    // whose kingdom had already fallen.
    test('the southern prophets and kings are on Judah', () {
      for (final id in ['hezekiah_reform', 'isaiah', 'jeremiah', 'josiah_reform']) {
        final e = injected.firstWhere((x) => x.id == '$kBibleEventIdPrefix$id');
        expect(e.stream, 'judah', reason: id);
        expect(e.year, lessThan(-586 + 1));
      }
    });

    // Acts 2 is where the church's own history starts. Before the
    // merge the wheel's church band opened in AD 64 with the fire of
    // Rome, which put the martyrs before the Pentecost that sent them.
    test('the church band starts at Pentecost, not the fire of Rome', () {
      final church = injected.where((e) => e.stream == 'church').toList()
        ..sort((a, b) => a.year.compareTo(b.year));
      expect(church.first.id, '${kBibleEventIdPrefix}pentecost');
      final wheelChurch = wheel.events.where((e) => e.stream == 'church');
      expect(church.first.year,
          lessThan(wheelChurch.map((e) => e.year).reduce((a, b) => a < b ? a : b)));
      // Everything through the Ascension happened to Judea.
      for (final id in ['jesus_born', 'sermon_mount', 'crucifixion', 'ascension']) {
        expect(injected.firstWhere((x) => x.id == '$kBibleEventIdPrefix$id').stream,
            'judah',
            reason: id);
      }
    });
  });

  group('the two assets agree where they overlap', () {
    // The only fact both files tell. If a future edit brings it back,
    // the wheel would draw AD 70 twice under two names.
    test('the excluded duplicate is the same year on both sides', () {
      final t = timeline.firstWhere((e) => e.id == 'temple_destroyed');
      final w = wheel.events.firstWhere((e) => e.id == 'jerusalem_destroyed');
      expect(t.year, w.year);
      expect(w.stream, 'judah');
    });

    // Two events sit exactly on kMinYear; a third below it would be
    // drawn off the axis rather than at its start.
    test('no injected year falls outside the wheel axis', () {
      for (final e in injected) {
        expect(e.year, greaterThanOrEqualTo(-4000), reason: e.id);
        expect(e.year, lessThanOrEqualTo(2026), reason: e.id);
      }
    });
  });

  group('every basis reaches the reader as a true sentence', () {
    // `thiele` was unreachable on the wheel until this merge and fell
    // through _basisText's default to "conventional date, not stated
    // in scripture" — false of David's accession, which is counted
    // along reign lengths the text states.
    test('the page has a case for every basis now on the wheel', () {
      final src =
          File('lib/pages/radial_chronology_page.dart').readAsStringSync();
      final bases = merged.map((e) => e.basis).toSet();
      expect(bases, contains('thiele'));
      for (final b in bases) {
        if (b == 'conventional') continue;
        expect(src, contains("'$b' =>"), reason: 'no _basisText arm for $b');
      }
    });

    test('the basis vocabulary is closed', () {
      expect(injected.map((e) => e.basis).toSet().difference(
          {'scripture', 'scripture+thiele', 'thiele', 'conventional'}), isEmpty);
    });

    // The label ring divides scripture-anchored from conventional at
    // `basis != 'conventional'`, and approximate/basis are held in
    // step by the timeline's own audit.
    test('approximate agrees with basis on every injected event', () {
      for (final e in injected) {
        expect(e.approximate, e.basis == 'conventional', reason: e.id);
      }
    });
  });
}
