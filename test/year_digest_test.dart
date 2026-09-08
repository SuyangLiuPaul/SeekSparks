/// What one year holds, measured on hand-built lanes rather than the
/// real corpus.
///
/// `strip_lanes_test.dart` deliberately measures the lane model against
/// the 22-stream asset, because the thing under test there IS the
/// asset's shape. `buildYearDigest` is the opposite case: it is a pure
/// classifier over whatever lanes it is handed, and every rule it owns
/// — which of the four moments a year is to a span, which list the span
/// lands in, and the two sort orders — is invisible in a 800-event
/// haystack. So the unit tests below build three-span lanes by hand,
/// where an expected order can be written out in full and read.
///
/// One test at the bottom does load the real corpus, to pin that the
/// classifier and `buildStripLanes` still agree about a year that has a
/// known answer.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/strip_lanes.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/strip_chronology_layout.dart';
import 'package:seeksparks/utils/year_digest.dart';

StripSpan _span(
  String id, {
  required int startYear,
  required int endYear,
  StripLaneKind kind = StripLaneKind.events,
  String? line,
  bool ongoing = false,
}) =>
    StripSpan(
      id: id,
      kind: kind,
      startYear: startYear,
      endYear: endYear,
      line: line,
      ongoing: ongoing,
    );

/// One packed row, shaped the way `_packGroup` shapes it — the digest
/// reads `kind` and `spans` and nothing else, so `subLane` may stay 0.
StripLane _lane(StripLaneKind kind, List<StripSpan> spans, {int subLane = 0}) =>
    StripLane(
      id: '${kind.name}:$subLane',
      kind: kind,
      subLane: subLane,
      spans: spans,
    );

List<String> _ids(List<YearDigestItem> items) => [for (final i in items) i.id];

void main() {
  group('a span that begins and ends in the same year', () {
    // The corpus case this rule was written for: four reigns (Zimri,
    // Ahaziah of Judah, Jehoahaz of Judah, Shallum of Israel) start and
    // stop inside one year, and reporting one as a beginning AND as an
    // end is the same reign counted twice.
    test('is reported exactly once, as happened, never as both edges', () {
      final digest = buildYearDigest(
        year: -885,
        lanes: [
          _lane(StripLaneKind.kings, [
            _span('king:zimri',
                kind: StripLaneKind.kings, startYear: -885, endYear: -885),
          ]),
        ],
      );

      expect(digest.ongoing, isEmpty);
      expect(digest.happened, hasLength(1));
      expect(
          [...digest.happened, ...digest.ongoing]
              .where((i) => i.id == 'king:zimri'),
          hasLength(1));
      expect(digest.happened.single.moment, YearMoment.happened);
    });

    test('runs for one year, not zero', () {
      final digest = buildYearDigest(
        year: -885,
        lanes: [
          _lane(StripLaneKind.kings, [
            _span('king:zimri',
                kind: StripLaneKind.kings, startYear: -885, endYear: -885),
          ]),
        ],
      );

      expect(digest.happened.single.years, 1);
    });
  });

  group('the three positions a year can hold in a multi-year span', () {
    final lanes = [
      _lane(StripLaneKind.kings, [
        _span('king:jehoshaphat',
            kind: StripLaneKind.kings,
            startYear: -872,
            endYear: -848,
            line: 'judah'),
      ]),
    ];

    test('the first year of a span is began', () {
      final digest = buildYearDigest(year: -872, lanes: lanes);
      expect(digest.ongoing, isEmpty);
      expect(digest.happened.single.moment, YearMoment.began);
    });

    test('the last year of a span is ended', () {
      final digest = buildYearDigest(year: -848, lanes: lanes);
      expect(digest.ongoing, isEmpty);
      expect(digest.happened.single.moment, YearMoment.ended);
    });

    // The split between the two lists is the whole point of the
    // classification: a reign merely under way is context, not news, and
    // must not be printed alongside what actually happened.
    test(
        'a year strictly inside is ongoing, and lands in ongoing rather '
        'than happened', () {
      final digest = buildYearDigest(year: -860, lanes: lanes);
      expect(digest.happened, isEmpty);
      expect(digest.ongoing.single.moment, YearMoment.ongoing);
      expect(digest.ongoing.single.id, 'king:jehoshaphat');
    });

    test('a year outside the span reports nothing at all', () {
      expect(buildYearDigest(year: -873, lanes: lanes).isEmpty, isTrue);
      expect(buildYearDigest(year: -847, lanes: lanes).isEmpty, isTrue);
    });

    test('the classified item carries the span\'s own line and years', () {
      final item = buildYearDigest(year: -860, lanes: lanes).ongoing.single;
      expect(item.line, 'judah');
      expect(item.kind, StripLaneKind.kings);
      expect(item.years, 25);
    });
  });

  group('the order happened reads in', () {
    // Moment before kind, and the fixture is rigged so the two orders
    // disagree: the happened span sits on the LAST kind in the reading
    // order and the began span on the FIRST, so ranking kind first would
    // reverse this list.
    test(
        'a record that IS this year outranks one that merely began in '
        'it, even from a lower lane', () {
      final digest = buildYearDigest(
        year: -586,
        lanes: [
          _lane(StripLaneKind.events, [
            _span('exile_begins',
                kind: StripLaneKind.events, startYear: -586, endYear: -538),
          ]),
          _lane(StripLaneKind.stream, [
            _span('babylon_sack',
                kind: StripLaneKind.stream, startYear: -586, endYear: -586),
          ]),
        ],
      );

      expect(_ids(digest.happened), ['babylon_sack', 'exile_begins'],
          reason: 'happened (stream lane) must precede began (events '
              'lane); the reverse would mean kind was ranked above '
              'moment');
    });

    test('within one moment, the lane reading order decides', () {
      final digest = buildYearDigest(
        year: 0,
        lanes: [
          _lane(StripLaneKind.ministries, [
            _span('a_ministry',
                kind: StripLaneKind.ministries, startYear: 0, endYear: 10),
          ]),
          _lane(StripLaneKind.kings, [
            _span('m_king',
                kind: StripLaneKind.kings, startYear: 0, endYear: 10),
          ]),
          _lane(StripLaneKind.lives, [
            _span('z_life',
                kind: StripLaneKind.lives, startYear: 0, endYear: 10),
          ]),
        ],
      );

      expect(_ids(digest.happened), ['z_life', 'm_king', 'a_ministry'],
          reason: 'lives, then kings, then ministries — the ids are in '
              'the opposite order on purpose, so an id-first sort would '
              'fail here');
    });

    test('within one moment and one kind, the id decides', () {
      final digest = buildYearDigest(
        year: 0,
        lanes: [
          _lane(StripLaneKind.events, [
            _span('b_event', startYear: 0, endYear: 10),
            _span('a_event', startYear: 0, endYear: 10),
          ]),
        ],
      );

      expect(_ids(digest.happened), ['a_event', 'b_event']);
    });

    test('began comes before ended', () {
      final digest = buildYearDigest(
        year: 0,
        lanes: [
          _lane(StripLaneKind.events, [
            _span('ends_here', startYear: -10, endYear: 0),
            _span('starts_here', startYear: 0, endYear: 10),
          ]),
        ],
      );

      expect(_ids(digest.happened), ['starts_here', 'ends_here']);
    });
  });

  group('the order ongoing reads in', () {
    // Longest first, because at a cursor in the middle of nowhere the
    // 969-year lifespan is the answer to "what is going on here" and a
    // reign that started last year is not.
    test('kind first, then the longest-running, then the id', () {
      final digest = buildYearDigest(
        year: 0,
        lanes: [
          _lane(StripLaneKind.kings, [
            _span('king_x',
                kind: StripLaneKind.kings, startYear: -10, endYear: 10),
          ]),
          _lane(StripLaneKind.lives, [
            _span('life_c',
                kind: StripLaneKind.lives, startYear: -100, endYear: 100),
            _span('life_b',
                kind: StripLaneKind.lives, startYear: -50, endYear: 50),
            _span('life_a',
                kind: StripLaneKind.lives, startYear: -100, endYear: 100),
          ]),
        ],
      );

      expect(_ids(digest.ongoing), ['life_a', 'life_c', 'life_b', 'king_x'],
          reason: 'life_a and life_c are the same 201 years and break to '
              'id; life_b is shorter; king_x is on a later lane kind '
              'whatever its length');
    });

    test(
        'kind outranks length: a short lifespan still precedes a long '
        'reign', () {
      final digest = buildYearDigest(
        year: 0,
        lanes: [
          _lane(StripLaneKind.kings, [
            _span('long_reign',
                kind: StripLaneKind.kings, startYear: -500, endYear: 500),
          ]),
          _lane(StripLaneKind.lives, [
            _span('short_life',
                kind: StripLaneKind.lives, startYear: -1, endYear: 1),
          ]),
        ],
      );

      expect(_ids(digest.ongoing), ['short_life', 'long_reign']);
    });
  });

  group('counting rather than reciting', () {
    final lanes = [
      _lane(StripLaneKind.lives, [
        _span('life_a',
            kind: StripLaneKind.lives, startYear: -100, endYear: 100),
        _span('life_b', kind: StripLaneKind.lives, startYear: -50, endYear: 50),
      ]),
      _lane(StripLaneKind.kings, [
        _span('king_ongoing',
            kind: StripLaneKind.kings, startYear: -10, endYear: 10),
        // Begins on the cursor year, so it is news, not context — and
        // must not be counted among the ongoing reigns.
        _span('king_begins',
            kind: StripLaneKind.kings, startYear: 0, endYear: 10),
      ]),
    ];

    test('ongoingOf counts only the ongoing records of that kind', () {
      final digest = buildYearDigest(year: 0, lanes: lanes);
      expect(digest.ongoingOf(StripLaneKind.lives), 2);
      expect(digest.ongoingOf(StripLaneKind.kings), 1);
      expect(digest.ongoingOf(StripLaneKind.ministries), 0);
      expect(digest.happened, hasLength(1));
    });

    test('isEmpty is true only when both lists are empty', () {
      expect(buildYearDigest(year: 0, lanes: lanes).isEmpty, isFalse);
      expect(buildYearDigest(year: 5, lanes: lanes).isEmpty, isFalse,
          reason: 'nothing happened in 5, but four records are under way');
      expect(buildYearDigest(year: 5000, lanes: lanes).isEmpty, isTrue);
      expect(buildYearDigest(year: 0, lanes: const []).isEmpty, isTrue);
    });
  });

  group('what the walk refuses to double-count or read at all', () {
    // A caller may concatenate two lane lists — the wheel builds its own
    // — and a record named twice reads as two records.
    test('the same span id present in two lanes is reported once', () {
      final digest = buildYearDigest(
        year: 0,
        lanes: [
          _lane(StripLaneKind.kings, [
            _span('king:dup',
                kind: StripLaneKind.kings, startYear: -5, endYear: 5),
          ]),
          _lane(StripLaneKind.lives, [
            _span('king:dup',
                kind: StripLaneKind.lives, startYear: -5, endYear: 5),
          ]),
        ],
      );

      expect([...digest.happened, ...digest.ongoing], hasLength(1));
      expect(digest.ongoing.single.kind, StripLaneKind.kings,
          reason: 'the first lane to claim the id wins');
    });

    // The ruler is the axis's own scale, not data — `buildStripLanes`
    // never emits one, but the page draws it in the same vocabulary, so
    // a caller could hand one over.
    test('a ruler lane is skipped whole', () {
      final digest = buildYearDigest(
        year: 0,
        lanes: [
          _lane(StripLaneKind.ruler, [
            _span('tick:0',
                kind: StripLaneKind.ruler, startYear: -100, endYear: 100),
          ]),
        ],
      );

      expect(digest.isEmpty, isTrue);
    });
  });

  // BC years count downward, so a caller (or a future asset) can hand
  // over a span whose start is numerically the larger of the two.
  group('a span stored with its years the wrong way round', () {
    final lanes = [
      _lane(StripLaneKind.stream, [
        _span('backwards',
            kind: StripLaneKind.stream, startYear: 100, endYear: 50),
      ]),
    ];

    test('reads its earlier year as began and its later year as ended', () {
      expect(buildYearDigest(year: 50, lanes: lanes).happened.single.moment,
          YearMoment.began);
      expect(buildYearDigest(year: 100, lanes: lanes).happened.single.moment,
          YearMoment.ended);
      expect(buildYearDigest(year: 75, lanes: lanes).ongoing.single.moment,
          YearMoment.ongoing);
    });

    test('hands back the normalised pair, not the stored one', () {
      final item = buildYearDigest(year: 75, lanes: lanes).ongoing.single;
      expect(item.startYear, 50);
      expect(item.endYear, 100);
      expect(item.years, 51);
    });
  });

  // The one test worth the asset load: the unit fixtures above prove the
  // classifier, and this proves it is still classifying the lanes
  // `strip_chronology_page.dart` actually hands it.
  group('against the real corpus', () {
    test(
        'a year inside the divided monarchy reports its reigns as '
        'ongoing, not as news', () {
      Map<String, dynamic> jsonAt(String path) =>
          json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

      final base =
          WheelHistoryData.fromJson(jsonAt('assets/wheel_history.json'));
      final timeline = [
        for (final r in (jsonAt('assets/bible_timeline.json')['events'] as List)
            .cast<Map<String, dynamic>>())
          TimelineEvent.fromJson(r)
      ];
      final wheel = WheelHistoryData(
        streams: base.streams,
        nations: base.nations,
        powers: base.powers,
        ministries: base.ministries,
        omissions: base.omissions,
        meta: base.meta,
        events: [...base.events, ...bibleNarrativeEvents(timeline)]
          ..sort((a, b) => a.year.compareTo(b.year)),
      );
      final kings = (jsonAt('assets/hebrew_kings.json')['kings'] as List)
          .cast<Map<String, dynamic>>()
          .map(HebrewKing.fromJson)
          .toList();
      final chron = ChronologyData.fromJson(jsonAt('assets/chronology.json'));
      final familyTree = (jsonAt('assets/family_tree.json')['people'] as List)
          .cast<Map<String, dynamic>>()
          .map(BiblicalPerson.fromJson)
          .toList();
      final creation = ((jsonAt('assets/bible_timeline.json')['_meta']
              as Map<String, dynamic>)['creation']
          as Map<String, dynamic>)['year'] as int;

      final lanes = buildStripLanes(
        wheel: wheel,
        kings: kings,
        patriarchs: chron.patriarchs,
        familyTreePeople: familyTree,
        tradition: 'mt',
        creationYear: creation,
        pxPerYear: kStripZoomSteps.first,
      );

      // -850 sits strictly inside Jehoshaphat, Jehoram of Judah and
      // Joram of Israel — three reigns, no reign edge, in the middle of
      // the two-kingdom stretch the strip exists to make readable.
      final digest = buildYearDigest(year: -850, lanes: lanes);
      final reigns = digest.ongoing
          .where((i) => i.kind == StripLaneKind.kings)
          .map((i) => i.id)
          .toSet();

      expect(reigns, contains('${kStripKingPrefix}jehoshaphat'));
      expect(reigns.length, greaterThanOrEqualTo(2),
          reason: 'the divided monarchy means two thrones at once');
      expect(digest.ongoingOf(StripLaneKind.kings), reigns.length);
      expect(digest.happened.map((i) => i.id), isNot(contains(reigns.first)),
          reason: 'an ongoing reign must never also be listed as news');
    });
  });

  // The first cut of `buildYearDigest` read `endYear` and ignored
  // `StripSpan.ongoing`, and `strip_lanes.dart` gives an open-ended
  // power an `endYear` of `kStripMaxYear` so its BAR reaches the edge
  // of the axis. A cursor on the last year of the axis therefore
  // announced that the State of Israel, the Order of Malta and the
  // current papacy had all ended in 2026. There is no year in this
  // corpus at which that reading is right, so the flag decides.
  group('a record with no recorded end', () {
    List<StripLane> lanes() => [
          _lane(StripLaneKind.stream, [
            _span('state-of-israel',
                kind: StripLaneKind.stream,
                startYear: 1948,
                endYear: kStripMaxYear,
                ongoing: true),
          ]),
        ];

    test('does not end on the year its painted bar happens to stop', () {
      final d = buildYearDigest(year: kStripMaxYear, lanes: lanes());
      expect(_ids(d.happened), isEmpty);
      expect(d.ongoing.single.id, 'state-of-israel');
      expect(d.ongoing.single.moment, YearMoment.ongoing);
    });

    test('still begins on the year it begins', () {
      final d = buildYearDigest(year: 1948, lanes: lanes());
      expect(d.happened.single.moment, YearMoment.began);
    });

    test('says so, so a caller can tell the sentinel from a real end', () {
      final d = buildYearDigest(year: 2000, lanes: lanes());
      expect(d.ongoing.single.openEnded, isTrue);
      expect(
        buildYearDigest(
          year: 0,
          lanes: [
            _lane(StripLaneKind.stream, [
              _span('rome',
                  kind: StripLaneKind.stream, startYear: -500, endYear: 476),
            ]),
          ],
        ).ongoing.single.openEnded,
        isFalse,
      );
    });

    // The degenerate pair: a span that starts on the axis end AND has
    // no end. Reporting it as `happened` would be the zero-length rule
    // firing on two sentinels rather than on a real one-year record.
    test('beginning on the last year of the axis is a beginning', () {
      final d = buildYearDigest(
        year: kStripMaxYear,
        lanes: [
          _lane(StripLaneKind.stream, [
            _span('brand-new',
                kind: StripLaneKind.stream,
                startYear: kStripMaxYear,
                endYear: kStripMaxYear,
                ongoing: true),
          ]),
        ],
      );
      expect(d.happened.single.moment, YearMoment.began);
    });
  });
}
