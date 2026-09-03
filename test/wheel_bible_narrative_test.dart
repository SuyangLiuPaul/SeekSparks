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
import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show kMaxYear, kMinYear;
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
      expect(injected, hasLength(104));
      expect(merged, hasLength(wheel.events.length + 104));
    });

    /// THE SEVEN THE OWNER SAID WERE MISSING, MEASURED AT THE MERGE.
    ///
    /// The complaint was that the line between Adam and Noah is absent
    /// from the wheel: Genesis 5 walks ten generations and the wheel
    /// drew four of them (Adam in Eden and the Fall, Seth's birth,
    /// Enoch's walk, Noah's flood). Six were nowhere on it in any form,
    /// and Shelah stood on it only as an undated name in the table of
    /// nations, under the KJV's Genesis 10:24 spelling Salah — the band
    /// reads Shelah now and carries the KJV's form as `nameKjv`, so the
    /// spoke and the band no longer disagree on screen.
    ///
    /// Asserted HERE rather than against the asset, because the asset
    /// is not what the reader sees: `bibleNarrativeEvents` is a
    /// constructor call with fourteen arguments and this repository has
    /// shipped a field silently lost at it three times. A record that
    /// exists in the file and does not survive the merge is exactly as
    /// absent as one that was never written.
    test('the seven generations the wheel had no record of arrive', () {
      const added = [
        'enosh_born',
        'kenan_born',
        'mahalalel_born',
        'jared_born',
        'methuselah_born',
        'lamech_born',
        'shelah_born',
      ];
      final byId = {for (final e in injected) e.id: e};
      for (final id in added) {
        final e = byId['$kBibleEventIdPrefix$id'];
        expect(e, isNotNull, reason: '$id did not survive the merge');
        expect(e!.stream, 'world',
            reason: '$id must land on a band the wheel draws');
        expect(e.datingRefs, isNotEmpty, reason: '$id lost its chain');
        expect(e.basis, 'scripture+thiele', reason: id);
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(e.titleFor(locale), isNotEmpty, reason: '$id $locale');
          expect(e.descFor(locale), isNotEmpty, reason: '$id $locale');
        }
        // The Traditional text is not the Simplified text. A copied
        // zh-Hant is the quiet failure this asset is prone to.
        expect(e.titleFor('zh-Hant').isNotEmpty, isTrue, reason: id);
        expect(e.descFor('zh-Hant'), isNot(e.descFor('zh-Hans')),
            reason: '$id: zh-Hant looks copied from zh-Hans');
      }

      // And the whole Genesis 5 line is now on the wheel, in order,
      // which is the thing that was actually missing.
      final line = [
        for (final id in const [
          'eden',
          'seth_born',
          'enosh_born',
          'kenan_born',
          'mahalalel_born',
          'jared_born',
          'methuselah_born',
          'lamech_born',
          'flood',
        ])
          byId['$kBibleEventIdPrefix$id']!.year,
      ];
      expect(line, orderedEquals(List.of(line)..sort()),
          reason: 'the ten generations must read forwards on the axis');
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

    // Nothing sits ON kMinYear any more. Two events used to — the
    // creation and Eden, both -4000 when -4000 was the axis start and
    // Ussher's rounded creation at once. The chain now puts them at
    // -4114, and `kMinYear` moved to -4200 to hold them; an event below
    // the axis start would be clamped onto the rim and read as a year
    // nobody claims. Read from the constant, not from a literal, so the
    // two cannot drift apart again.
    test('no injected year falls outside the wheel axis', () {
      for (final e in injected) {
        expect(e.year, greaterThanOrEqualTo(kMinYear), reason: e.id);
        expect(e.year, lessThanOrEqualTo(kMaxYear), reason: e.id);
      }
      final earliest = injected
          .map((e) => e.year)
          .reduce((a, b) => a < b ? a : b);
      expect(
          injected.firstWhere((e) => e.year == earliest).id,
          '${kBibleEventIdPrefix}creation',
          reason: 'nothing may be drawn before the creation');
      expect(earliest, greaterThan(kMinYear),
          reason: 'the axis must start before the creation, not on it');
    });
  });

  group('every basis reaches the reader as a true sentence', () {
    // `thiele` was unreachable on the wheel until this merge and fell
    // through _basisText's default to "conventional date, not stated
    // in scripture" — false of David's accession, which is counted
    // along reign lengths the text states.
    test('the page has a case for every basis now on the wheel', () {
      // The wheel's detail sheets — including `basisText`'s switch —
      // live in `wheel_sheets.dart`, not in the page itself; both are
      // read here so the assertion still holds after that split.
      final src =
          File('lib/pages/radial_chronology_page.dart').readAsStringSync() +
              File('lib/pages/wheel_sheets.dart').readAsStringSync();
      final bases = merged.map((e) => e.basis).toSet();
      expect(bases, contains('thiele'));
      for (final b in bases) {
        if (b == 'conventional') continue;
        expect(src, contains("'$b' =>"), reason: 'no basisText arm for $b');
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
    test('the dating verses arrive, all 29 of them', () {
      final withDating = injected.where((e) => e.datingRefs.isNotEmpty);
      // 18 counted down from the anchor to Abraham and below; 11 more
      // counted UP from Abraham through Genesis 11 and Genesis 5, which
      // is what closed the seam this group's header used to describe.
      expect(withDating, hasLength(29));
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
      // Fifteen since the six generations Genesis 5 walks between Seth
      // and Noah — Enosh, Kenan, Mahalalel, Jared, Methuselah, Lamech —
      // and Shelah of Genesis 11 were added to the asset.
      expect(ante, hasLength(15));
      expect(ante.map((e) => e.id.substring(kBibleEventIdPrefix.length)),
          containsAll([
            'creation',
            'flood',
            'babel',
            'enosh_born',
            'kenan_born',
            'mahalalel_born',
            'jared_born',
            'methuselah_born',
            'lamech_born',
            'shelah_born',
          ]));
      // `era` cannot answer this question — the merge overwrites it.
      expect(injected.map((e) => e.era).toSet(), {'bible'});
      // ELEVEN OF THE FIFTEEN ARE NOW DERIVED, AND FOUR ARE NOT, AND
      // that split is the whole content of the era note. Until the
      // chain was carried above Abraham all fifteen were
      // reconstructions on Ussher's rounded 4000, 114 years out of step
      // with the Thiele-anchored half of the same circle. The four that
      // stayed behind rest on no stated interval — Genesis gives no
      // number between the creation and Eden, the Fall, Cain's murder,
      // or Babel — so they travel with the anchor and keep their hedge.
      const noStatedInterval = {'eden', 'fall', 'cain_abel', 'babel'};
      for (final e in ante) {
        final id = e.id.substring(kBibleEventIdPrefix.length);
        if (noStatedInterval.contains(id)) {
          expect(e.basis, 'conventional', reason: id);
          expect(e.approximate, isTrue, reason: id);
          expect(e.datingRefs, isEmpty, reason: id);
        } else {
          expect(e.basis, 'scripture+thiele', reason: id);
          expect(e.approximate, isFalse, reason: id);
          expect(e.datingRefs, isNotEmpty, reason: id);
        }
      }
      expect(ante.where((e) => e.basis == 'conventional'), hasLength(4));
    });

    // THE SEAM IS GONE, AND THIS IS THE ASSERTION THAT SAYS SO. It used
    // to read "the seam the note discloses is really 1,652 years" and
    // pinned the shortfall in the era note against the shortfall in the
    // data. Both are now zero: creation to flood is the 1,656 Genesis 5
    // and 7:6 give, and the note no longer claims otherwise. Pinned in
    // the same direction — the arithmetic first, the prose against it —
    // so a regression cannot restore one without the other.
    test('creation to flood is the 1,656 years Genesis states', () {
      int yearOf(String id) =>
          injected.firstWhere((e) => e.id == '$kBibleEventIdPrefix$id').year;
      expect(yearOf('flood') - yearOf('creation'), 1656);
      final note = uiStrings['timelineAntediluvianBasis']!;
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(note[locale]!, isNot(contains('1,652')), reason: locale);
        expect(note[locale]!, isNot(contains('1652')), reason: locale);
        expect(note[locale]!, isNot(contains('Ussher')), reason: locale);
        expect(note[locale]!, contains('4114'), reason: locale);
      }
    });

    test('the wheel renders all four apparatus strings', () {
      // Same split as above: the sheet that prints these keys now
      // lives in `wheel_sheets.dart`.
      final src =
          File('lib/pages/radial_chronology_page.dart').readAsStringSync() +
              File('lib/pages/wheel_sheets.dart').readAsStringSync();
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

  /// THE PEOPLE TRAVEL WITH THE EVENTS (#318 phase 21).
  ///
  /// The last field the merge dropped. `bible_timeline.json` names 37
  /// people across 61 of its events — Aaron on the plagues, Jochebed at
  /// the birth of Moses — and the linear timeline page has rendered
  /// them as chips and searched them since it shipped. The wheel drew
  /// the same 61 records with none of it, so a reader who typed a name
  /// the record holds was told there were no results.
  ///
  /// The names are resolved once at merge and COPIED onto the event
  /// rather than looked up while painting, because
  /// `FamilyTreeService.byId` is synchronous and answers null until its
  /// own load finishes: a chip resolving itself mid-paint would render
  /// empty for a frame, and the search running beside it would agree,
  /// reporting an absence that was really a race.
  group('the people travel with the events', () {
    final tree = (_json('assets/family_tree.json')['people'] as List)
        .cast<Map<String, dynamic>>()
        .map(BiblicalPerson.fromJson)
        .toList();
    final withPeople = bibleNarrativeEvents(timeline, people: tree);
    final links = [for (final e in withPeople) ...e.people];

    test('the links arrive, all 95 of them across 68 events', () {
      expect(withPeople.where((e) => e.people.isNotEmpty), hasLength(68));
      expect(links, hasLength(95));
      expect(links.map((l) => l.id).toSet(), hasLength(44));
      // The seven added for the generations the wheel had no record of
      // each name exactly one man, and the merge must carry him: a chip
      // that cannot open anything is worse than an absent one, and the
      // constructor is where such links have been dropped before.
      final byId = {for (final e in withPeople) e.id: e};
      for (final id in const [
        'enosh_born',
        'kenan_born',
        'mahalalel_born',
        'jared_born',
        'methuselah_born',
        'lamech_born',
        'shelah_born',
      ]) {
        final people = byId['$kBibleEventIdPrefix$id']!.people;
        expect(people, hasLength(1), reason: id);
        expect(people.single.nameFor('zh-Hant'), isNotEmpty, reason: id);
      }
      // The timeline's own count, so a link lost between the two files
      // fails here rather than shrinking a number nobody re-derives.
      expect(links.length,
          timeline.fold<int>(0, (n, e) => n + e.personIds.length));
    });

    test('nothing is linked to a person the family tree does not hold', () {
      final ids = tree.map((p) => p.id).toSet();
      for (final e in timeline) {
        for (final id in e.personIds) {
          expect(ids, contains(id),
              reason: '${e.id} links $id, which is not in the family tree');
        }
      }
    });

    test('every link carries all three scripts', () {
      for (final l in links) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(l.names[locale], isNotNull, reason: '${l.id}/$locale');
          expect(l.nameFor(locale), isNotEmpty, reason: '${l.id}/$locale');
        }
      }
    });

    // Without the `people:` argument the function must still work and
    // still drop nothing else — the wheel's own asset tests call it
    // that way, and a link list silently populated from a singleton
    // would make those tests lie about what the page renders.
    test('the merge is pure: no people in, no people out', () {
      expect(bibleNarrativeEvents(timeline).every((e) => e.people.isEmpty),
          isTrue);
    });

    // Refuted assumption, kept as a guard. Twelve family-tree ids are
    // also wheel record ids — `noah`, `shem`, `judah` and nine more —
    // because both datasets name people after the nations descended
    // from them. Only `noah` is currently linked to an event, so the
    // hazard is live. A person link's id addresses the family tree and
    // nothing else; feeding one to a wheel-record lookup would silently
    // open the nation of Judah instead of the man.
    test('a person id is not a wheel record id', () {
      final wheelIds = {
        ...wheel.events.map((e) => e.id),
        ...wheel.nations.map((n) => n.id),
        ...wheel.powers.map((p) => p.id),
        ...wheel.streams.map((s) => s.id),
      };
      final collisions =
          tree.map((p) => p.id).where(wheelIds.contains).toSet();
      expect(collisions, contains('noah'));
      expect(collisions, contains('judah'));
      expect(collisions.length, greaterThanOrEqualTo(12));
      // Every hit the search returns is still addressed by event id, so
      // the two namespaces never meet in a result.
      final byEventId = {for (final e in withPeople) e.id: e};
      for (final e in withPeople.where((e) => e.people.isNotEmpty)) {
        expect(byEventId[e.id], isNotNull);
        expect(e.id, startsWith(kBibleEventIdPrefix));
      }
    });
  });
}
