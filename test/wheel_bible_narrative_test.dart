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
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/reference_parser.dart';

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

  /// THE APPARATUS TRAVELS WITH THE YEARS (#318 phase 19).
  ///
  /// Phase 17 brought the years across and left behind the three things
  /// that make a year checkable. The wheel printed "interval from
  /// scripture" over a chip list that states no interval, printed one
  /// year where the timeline page prints two, and drew the eight events
  /// that are NOT counted back from the Thiele anchor on the same axis
  /// as the ones that are, with nothing said about the seam.
  ///
  /// None of it failed anything: `WheelHistoryEvent` had no field to
  /// drop the data into, so it was dropped at the constructor and every
  /// test stayed green. The counts are pinned rather than described,
  /// because a merge that quietly stops carrying one of them looks
  /// exactly like a merge that carries them all.
  group('the apparatus travels with the years', () {
    test('the dating verses arrive, all 18 of them', () {
      final withDating = injected.where((e) => e.datingRefs.isNotEmpty);
      expect(withDating, hasLength(18));
      expect(withDating.length,
          timeline.where((e) => e.datingRefs.isNotEmpty).length);
      for (final e in withDating) {
        final source = timeline
            .firstWhere((t) => '$kBibleEventIdPrefix${t.id}' == e.id);
        expect(e.datingRefs, source.datingRefs, reason: e.id);
      }
    });

    // The five derived events that legitimately have none: their year
    // is Thiele's, not a chain of intervals this app can count, so
    // there are no verses to show and `wheelBasisThieleOnly` says so.
    test('only the Thiele years are derived without dating verses', () {
      final gap = injected
          .where((e) => e.basis != 'conventional' && e.datingRefs.isEmpty);
      expect(gap.map((e) => e.basis).toSet(), {'thiele'});
      expect(gap, hasLength(5));
    });

    // A chip whose reference does not parse is a dead tap: `_refRow`
    // returns early and nothing happens. The narrative refs were
    // already covered; these are a second, differently-authored set.
    test('every dating verse is tappable', () {
      for (final e in injected) {
        for (final r in e.datingRefs) {
          expect(parseReference(r), isNotNull, reason: '${e.id}: $r');
        }
      }
    });

    test('the Septuagint alternative arrives, all 8 of them', () {
      final lxx = injected.where((e) => e.septuagintYear != null).toList();
      expect(lxx, hasLength(8));
      expect(
          lxx.length, timeline.where((e) => e.septuagintYear != null).length);
      // All eight come through Exodus 12:40, which is the one thing
      // `timelineSeptuagintYear` explains. A ninth arriving from the
      // Genesis 5/11 genealogies would need a different sentence, and
      // would land under this one silently.
      for (final e in lxx) {
        expect(e.septuagintYear! - e.year, 215, reason: e.id);
      }
    });

    test('the antediluvian block is identifiable on the wheel', () {
      final ante = injected.where((e) => e.timelineEra == 'antediluvian');
      expect(ante, hasLength(8));
      expect(ante.map((e) => e.id.substring(kBibleEventIdPrefix.length)),
          containsAll(['creation', 'flood', 'babel']));
      // `era` cannot answer this question — the merge overwrites it.
      expect(injected.map((e) => e.era).toSet(), {'bible'});
      // Every one of them is a reconstruction with no chain reaching it,
      // which is what makes the seam note necessary rather than pedantic.
      for (final e in ante) {
        expect(e.basis, 'conventional', reason: e.id);
        expect(e.approximate, isTrue, reason: e.id);
        expect(e.datingRefs, isEmpty, reason: e.id);
      }
    });

    // The seam itself, stated as arithmetic so the disclosure's number
    // cannot drift away from the data it describes.
    test('the seam the note discloses is really 1,652 years', () {
      int yearOf(String id) =>
          injected.firstWhere((e) => e.id == '$kBibleEventIdPrefix$id').year;
      expect(yearOf('creation') - yearOf('flood'), -1652);
      expect(
          uiStrings['timelineAntediluvianBasis']!['en']!, contains('1,652'));
      expect(uiStrings['timelineAntediluvianBasis']!['zh-Hans']!,
          contains('1652'));
    });

    test('the wheel renders all four apparatus strings', () {
      final src =
          File('lib/pages/radial_chronology_page.dart').readAsStringSync();
      for (final key in [
        'timelineDatedBy',
        'timelineSeptuagintYear',
        'timelineAntediluvianBasis',
        'timelineOpenChronology',
      ]) {
        expect(src, contains(key), reason: '$key never reaches the wheel');
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(uiStrings[key]?[locale], isNotNull, reason: '$key/$locale');
          expect(uiStrings[key]![locale]!, isNotEmpty, reason: '$key/$locale');
        }
      }
    });
  });
}
