/// The lane model that feeds the strip, measured against the real
/// corpus rather than a toy fixture — the same discipline
/// `wheel_king_arcs_test.dart` and `wheel_bible_narrative_test.dart`
/// hold their own layers to.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/strip_lanes.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/strip_chronology_layout.dart';

Map<String, dynamic> _json(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The real, merged corpus, assembled the same way
/// `WheelHistoryService.load()` assembles it (`wheel_bible_narrative_
/// test.dart` uses the identical recipe) — 851 events, not the 747 the
/// raw asset alone holds, because `bibleNarrativeEvents` folds in 104
/// more from `bible_timeline.json` before anything downstream ever
/// sees the list.
WheelHistoryData _loadWheel() {
  final base = WheelHistoryData.fromJson(_json('assets/wheel_history.json'));
  final timeline = [
    for (final r
        in (_json('assets/bible_timeline.json')['events'] as List)
            .cast<Map<String, dynamic>>())
      TimelineEvent.fromJson(r)
  ];
  final injected = bibleNarrativeEvents(timeline);
  return WheelHistoryData(
    streams: base.streams,
    nations: base.nations,
    powers: base.powers,
    ministries: base.ministries,
    omissions: base.omissions,
    meta: base.meta,
    events: [...base.events, ...injected]
      ..sort((a, b) => a.year.compareTo(b.year)),
  );
}

List<HebrewKing> _loadKings() => (_json('assets/hebrew_kings.json')['kings']
        as List)
    .cast<Map<String, dynamic>>()
    .map(HebrewKing.fromJson)
    .toList();

late final WheelHistoryData wheel;
late final List<HebrewKing> kings;
late final ChronologyData chron;
late final int creation;

List<StripLane> build({
  required double pxPerYear,
  List<HebrewKing>? kingsOverride,
  List<Patriarch>? patriarchsOverride,
}) =>
    buildStripLanes(
      wheel: wheel,
      kings: kingsOverride ?? kings,
      patriarchs: patriarchsOverride ?? chron.patriarchs,
      tradition: 'mt',
      creationYear: creation,
      pxPerYear: pxPerYear,
    );

void main() {
  setUpAll(() {
    wheel = _loadWheel();
    kings = _loadKings();
    chron = ChronologyData.fromJson(_json('assets/chronology.json'));
    creation = (((_json('assets/bible_timeline.json'))['_meta']
        as Map<String, dynamic>)['creation'] as Map<String, dynamic>)['year']
        as int;
  });

  test('the corpus really is what the rest of this file assumes', () {
    // Guard on the guards: if these collapse the tests below are
    // proving something about a corpus that no longer exists.
    expect(wheel.streams, hasLength(22));
    expect(wheel.events, hasLength(851),
        reason: '747 from wheel_history.json + 104 merged from '
            'bible_timeline.json, per WheelHistoryService.load()');
    expect(kings, hasLength(42));
  });

  group('every stream gets at least one lane', () {
    test('all 22 streams appear, including the one with zero powers', () {
      for (final zoom in kStripZoomSteps) {
        final lanes = build(pxPerYear: zoom);
        final streamIds = lanes
            .where((l) => l.kind == StripLaneKind.stream)
            .map((l) => l.ownerId)
            .toSet();
        for (final s in wheel.streams) {
          expect(streamIds, contains(s.id),
              reason: 'stream ${s.id} has no lane at ${zoom}px/year');
        }
      }
    });

    test('`scripture` carries no powers and still gets exactly one, '
        'empty, lane — a stream that exists and is empty is '
        'information, not silence', () {
      expect(wheel.powersOf('scripture'), isEmpty,
          reason: 'if this asset ever gains a scripture power the '
              'test below stops being about the empty case');
      final lanes = build(pxPerYear: kStripZoomSteps.first);
      final scriptureLanes = lanes
          .where((l) =>
              l.kind == StripLaneKind.stream && l.ownerId == 'scripture')
          .toList();
      expect(scriptureLanes, hasLength(1));
      expect(scriptureLanes.single.spans, isEmpty);
      expect(scriptureLanes.single.subLane, 0);
    });

    test('a stream with real powers never fabricates an empty lane '
        'alongside the real ones', () {
      final lanes = build(pxPerYear: kStripZoomSteps.first);
      final israelLanes = lanes
          .where((l) => l.kind == StripLaneKind.stream && l.ownerId == 'israel')
          .toList();
      expect(israelLanes, isNotEmpty);
      for (final l in israelLanes) {
        expect(l.spans, isNotEmpty);
      }
    });
  });

  group('lane order, top to bottom', () {
    test('events, then lives, then kings, then ministries, then one '
        'group per stream in the asset\'s own order', () {
      final lanes = build(pxPerYear: kStripZoomSteps.first);
      final kindOrder = <StripLaneKind>[];
      for (final l in lanes) {
        if (kindOrder.isEmpty || kindOrder.last != l.kind) {
          kindOrder.add(l.kind);
        }
      }
      // Each kind's lanes are contiguous, and the block order matches
      // the contract exactly.
      expect(kindOrder.take(4), [
        StripLaneKind.events,
        StripLaneKind.lives,
        StripLaneKind.kings,
        StripLaneKind.ministries,
      ]);
      expect(kindOrder.skip(4).every((k) => k == StripLaneKind.stream),
          isTrue);

      final streamOrder = <String>[];
      for (final l in lanes.where((l) => l.kind == StripLaneKind.stream)) {
        if (streamOrder.isEmpty || streamOrder.last != l.ownerId) {
          streamOrder.add(l.ownerId!);
        }
      }
      expect(streamOrder, wheel.streams.map((s) => s.id).toList());
    });

    test('sub-lanes within one kind are numbered 0, 1, 2, ... with no '
        'gap and no repeat', () {
      final lanes = build(pxPerYear: 6);
      for (final kind in StripLaneKind.values) {
        if (kind == StripLaneKind.ruler) continue;
        final ownerIds = {
          for (final l in lanes.where((l) => l.kind == kind)) l.ownerId
        };
        for (final owner in ownerIds) {
          final subLanes = lanes
              .where((l) => l.kind == kind && l.ownerId == owner)
              .map((l) => l.subLane)
              .toList()
            ..sort();
          expect(subLanes, List.generate(subLanes.length, (i) => i));
        }
      }
    });
  });

  group('StripLaneKind.ruler is never produced', () {
    test('at any zoom step', () {
      for (final zoom in kStripZoomSteps) {
        final lanes = build(pxPerYear: zoom);
        expect(lanes.where((l) => l.kind == StripLaneKind.ruler), isEmpty);
      }
    });
  });

  group('packing correctness across the whole real corpus', () {
    test('no two spans sharing a lane overlap in ink, at every zoom '
        'step, across every lane the builder produces', () {
      for (final zoom in kStripZoomSteps) {
        final lanes = build(pxPerYear: zoom);
        for (final lane in lanes) {
          final spans = lane.spans;
          for (var a = 0; a < spans.length; a++) {
            for (var b = a + 1; b < spans.length; b++) {
              final x0a = xForYear(spans[a].startYear, zoom);
              final x1a = xForYear(spans[a].endYear, zoom);
              final x0b = xForYear(spans[b].startYear, zoom);
              final x1b = xForYear(spans[b].endYear, zoom);
              final overlap = x0a < x1b && x0b < x1a;
              expect(overlap, isFalse,
                  reason: '${lane.id}: ${spans[a].id} and ${spans[b].id} '
                      'paint over each other at ${zoom}px/year');
            }
          }
        }
      }
    });

    test('every span the builder emits is accounted for by kind: the '
        'total across all lanes of one kind matches the input list, '
        'so packing never drops an item — rule 2', () {
      final lanes = build(pxPerYear: kStripZoomSteps.first);
      int countOf(StripLaneKind k) =>
          lanes.where((l) => l.kind == k).fold(0, (n, l) => n + l.spans.length);
      expect(countOf(StripLaneKind.events), 851);
      expect(countOf(StripLaneKind.kings), 42);
      expect(countOf(StripLaneKind.ministries), wheel.ministries.length);
      expect(countOf(StripLaneKind.stream), wheel.powers.length);
    });
  });

  group('zero-width reigns and ministries are real and legal', () {
    test('the four zero-width KINGS are Zimri, Ahaziah of Judah, '
        'Jehoahaz of Judah and Shallum of Israel — NOT Huldah, who is '
        'a ministry, not a king', () {
      final zeroKingIds = kings
          .where((k) => k.reignStart == k.reignEnd)
          .map((k) => k.id)
          .toSet();
      expect(zeroKingIds, {
        'zimri',
        'ahaziah_judah',
        'jehoahaz_judah',
        'shallum_israel',
      });
      expect(kings.where((k) => k.id == 'huldah'), isEmpty,
          reason: 'Huldah is not in hebrew_kings.json at all');
    });

    test('those four kings survive into the kings lane at 0 width, not '
        'dropped and not fattened', () {
      final lanes = build(pxPerYear: kStripZoomSteps.first);
      final kingSpans = [
        for (final l in lanes.where((l) => l.kind == StripLaneKind.kings))
          ...l.spans
      ];
      for (final id in [
        'zimri',
        'ahaziah_judah',
        'jehoahaz_judah',
        'shallum_israel',
      ]) {
        final s = kingSpans.firstWhere((s) => s.id == '$kStripKingPrefix$id');
        expect(s.startYear, s.endYear);
        expect(spanWidth(s.startYear, s.endYear, kStripZoomSteps.first), 0);
      }
    });

    test('Huldah is a zero-width MINISTRY span, on the ministries '
        'lane, not the kings lane', () {
      final lanes = build(pxPerYear: kStripZoomSteps.first);
      final ministrySpans = [
        for (final l
            in lanes.where((l) => l.kind == StripLaneKind.ministries))
          ...l.spans
      ];
      final huldah = ministrySpans
          .firstWhere((s) => s.id == '${kStripMinistryPrefix}huldah_prophet');
      expect(huldah.startYear, huldah.endYear);
      expect(huldah.line, 'ministry');
    });
  });

  group('open-ended powers', () {
    test('a power with a null end is drawn to the axis end and marked '
        'ongoing, never given an invented literal year', () {
      final ongoingIds =
          wheel.powers.where((p) => p.ongoing).map((p) => p.id).toSet();
      expect(ongoingIds, isNotEmpty,
          reason: 'the corpus must still have at least one open band '
              'for this test to mean anything');

      final lanes = build(pxPerYear: kStripZoomSteps.first);
      final allStreamSpans = [
        for (final l in lanes.where((l) => l.kind == StripLaneKind.stream))
          ...l.spans
      ];
      for (final id in ongoingIds) {
        final s = allStreamSpans.firstWhere((s) => s.id == id);
        expect(s.ongoing, isTrue);
        expect(s.endYear, kStripMaxYear,
            reason: '$id must be drawn to the axis end, not a written-in '
                'year that goes stale');
      }
    });

    test('a power that has actually ended is never marked ongoing', () {
      final lanes = build(pxPerYear: kStripZoomSteps.first);
      final allStreamSpans = [
        for (final l in lanes.where((l) => l.kind == StripLaneKind.stream))
          ...l.spans
      ];
      final ended = wheel.powers.where((p) => !p.ongoing).map((p) => p.id);
      for (final id in ended) {
        final s = allStreamSpans.firstWhere((s) => s.id == id);
        expect(s.ongoing, isFalse);
      }
    });
  });

  group('line-of-descent colouring', () {
    test('every event lands with a real line, even one whose stream '
        'defaults to `world` through the bible-narrative merge', () {
      final lanes = build(pxPerYear: kStripZoomSteps.first);
      final eventSpans = [
        for (final l in lanes.where((l) => l.kind == StripLaneKind.events))
          ...l.spans
      ];
      expect(eventSpans, hasLength(851));
      final streamIds = wheel.streams.map((s) => s.id).toSet();
      for (final e in wheel.events) {
        expect(streamIds, contains(e.stream),
            reason: '${e.id} claims stream "${e.stream}", which is not '
                'one of the 22 real streams — its line would be null');
      }
      for (final s in eventSpans) {
        expect(s.line, isNotNull,
            reason: '${s.id} has no line — a paint call would have '
                'nothing to colour it with');
      }
    });

    test('a king\'s line is its kingdom, never a stream id', () {
      final lanes = build(pxPerYear: kStripZoomSteps.first);
      final kingSpans = [
        for (final l in lanes.where((l) => l.kind == StripLaneKind.kings))
          ...l.spans
      ];
      for (final s in kingSpans) {
        expect(s.line, anyOf('israel', 'judah'));
      }
    });

    test('a stream\'s powers all carry that stream\'s own descent line, '
        'not the power\'s own `region`', () {
      final lanes = build(pxPerYear: kStripZoomSteps.first);
      for (final stream in wheel.streams) {
        final streamLanes = lanes.where(
            (l) => l.kind == StripLaneKind.stream && l.ownerId == stream.id);
        for (final l in streamLanes) {
          for (final s in l.spans) {
            expect(s.line, stream.line);
          }
        }
      }
    });
  });

  group('lane assignment moves with zoom, by design', () {
    test('`europe`, whose powers reach 8 genuinely concurrent bands, '
        'never packs into fewer than 8 lanes at any zoom — real time '
        'overlap is not a zoom-dependent fact', () {
      for (final zoom in kStripZoomSteps) {
        final lanes = build(pxPerYear: zoom);
        final europeLanes = lanes
            .where((l) =>
                l.kind == StripLaneKind.stream && l.ownerId == 'europe')
            .length;
        expect(europeLanes, greaterThanOrEqualTo(8),
            reason: 'at ${zoom}px/year europe only used $europeLanes lanes');
      }
    });

    test('the SAME stream needs fewer or equal lanes at high zoom than '
        'at low zoom, because the same minGapPx is a smaller time gap '
        'once each year buys more pixels', () {
      final lowZoomLanes = build(pxPerYear: kStripZoomSteps.first)
          .where((l) => l.kind == StripLaneKind.stream && l.ownerId == 'rome')
          .length;
      final highZoomLanes = build(pxPerYear: kStripZoomSteps.last)
          .where((l) => l.kind == StripLaneKind.stream && l.ownerId == 'rome')
          .length;
      expect(highZoomLanes, lessThanOrEqualTo(lowZoomLanes));
    });
  });

  group('empty inputs produce no lane for that kind, except a stream',
      () {
    test('no kings passed in means no kings lane at all', () {
      final lanes =
          build(pxPerYear: kStripZoomSteps.first, kingsOverride: const []);
      expect(lanes.where((l) => l.kind == StripLaneKind.kings), isEmpty);
      // Streams are unaffected by the kings layer being switched off.
      expect(lanes.where((l) => l.kind == StripLaneKind.stream), isNotEmpty);
    });

    test('no patriarchs passed in means no lives lane at all', () {
      final lanes =
          build(pxPerYear: kStripZoomSteps.first, patriarchsOverride: const []);
      expect(lanes.where((l) => l.kind == StripLaneKind.lives), isEmpty);
    });
  });
}
