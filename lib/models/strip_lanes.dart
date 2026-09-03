/// The lane model that feeds the horizontal chronology strip.
///
/// `strip_chronology_layout.dart` answers "where on the axis" and "how
/// do spans avoid overlapping in one row"; this file answers "which
/// row". It turns the wheel's own data — `wheel_history.json`,
/// `hebrew_kings.json`, `chronology.json` — into an ordered list of
/// [StripLane]s ready to paint, and nothing else: no widgets, no
/// colours (the page owns the palette, same split as [LifeArc.line] on
/// the wheel), no strings beyond ids.
///
/// THE WHEEL HAS NO EQUIVALENT FILE. `packWheelBand`, `kingReignSpans`
/// and `ministrySpans` live in `radial_chronology_page.dart` itself,
/// because the wheel packs everything that is not a stream band into
/// ONE shared annulus and the page was the only caller. The strip has
/// no annulus — every kind gets its own stack of rows — so the packing
/// now has five callers (events, lives, kings, ministries, each of 22
/// streams) instead of one, and five callers earn a file a widget
/// cannot import.
///
/// WHY LANE ASSIGNMENT MOVES WITH ZOOM, AND WHY THAT IS RIGHT. Two
/// spans "share a lane" here only when they do not overlap in time
/// AND clear each other by [minGapPx] of screen ink — and the second
/// half of that test is a pixel count, not a year count, so it answers
/// differently at 0.15 px/year than at 24. A four-year gap between two
/// reigns is 0.6 px at rest and 96 px at the top of the ladder: the
/// same two kings that must share a lane at rest (0.6 px of clearance
/// cannot hold two bars apart) can afford a lane each once the reader
/// zooms in. That is not a bug to paper over — [kLaneHeight] is a
/// SCREEN constant and minGapPx is a SCREEN gap; both describe what
/// ink needs, not what the calendar says, and freezing the assignment
/// at one zoom would mean either wasting rows at high zoom (bars that
/// could easily stand apart forced to share) or crowding rows at low
/// zoom (bars visually touching because a stale assignment kept them
/// in different lanes for no reason a reader can see). So [pxPerYear]
/// is a required argument here, callers rebuild on every zoom step —
/// eight steps, roughly a thousand items total, cheap — and no span's
/// year, stream or line ever changes when its lane does: only which
/// row it is drawn on, which is exactly the kind of decision that is
/// allowed to be a rendering one rather than a data one.
///
/// WHY THIS FILE DOES NOT CALL [clusterByX]. Packing and clustering
/// solve different problems and this file only owns one of them.
/// [packIntoLanes] answers "which of these already-decided items goes
/// on which row" and is what turns overlapping YEARS into separate
/// ROWS — the vertical axis. [clusterByX] answers "do several of
/// these items, once placed, print their marks on the same few
/// pixels" and merges them into one badge — a horizontal, viewport-
/// dependent declutter of what is already ON one row, the strip's
/// equivalent of `clusterByAngle` in the wheel PAGE, not in the wheel's
/// pure geometry file. The wheel keeps that call in
/// `radial_chronology_page.dart`; the strip's page should do the same,
/// calling [clusterByX] on the x-positions of whatever one lane's
/// events land in the visible window, because that declutter depends
/// on which slice of the axis is actually on screen and this file
/// never knows the viewport (see the library note on
/// `strip_chronology_layout.dart`). Baking clustering in here would
/// also mean baking in a lost-and-found: a merged badge has to say what
/// it stands for, which is exactly the kind of state a pure lane list
/// should not be carrying.
///
/// WHY A SPAN AND A POINT ARE THE SAME TYPE. [StripSpan] has no
/// separate "point" variant; an event is a [StripSpan] whose
/// `startYear` equals its `endYear`. `spanWidth` legitimately returns 0
/// (rule 1 of the layout file), [packIntoLanes] already treats a
/// zero-width start/end pair correctly, and [hitTargetFor] already
/// widens a zero-width target to a finger — so a second type would
/// duplicate every one of those contracts for no reader-visible
/// difference. The events lane therefore packs exactly like every
/// other lane, through the SAME `_packGroup` call, and inherits the
/// same honesty: a year nobody else is standing on gets its own row
/// rather than a silently invented cluster.
///
/// WHY [StripLaneKind.ruler] EXISTS AND IS NEVER PRODUCED HERE. The
/// ruler is not data — it is the axis's own scale, built straight from
/// [rulerStep]/[rulerTicks] — so [buildStripLanes] never emits one.
/// The value is kept on the enum anyway because the page draws the
/// ruler as a sticky row ABOVE the lanes this file returns, and giving
/// it a place in the same vocabulary means the page can switch on one
/// enum for every row it paints, the ruler included, instead of
/// special-casing the one row with no [StripLane] behind it.
///
/// THE 22 STREAMS ALWAYS GET A LANE, EVEN THE ONE WITH NO POWERS.
/// `scripture` carries no [WheelPower] today — it holds events and
/// omissions, never a band — but it is a real stream the wheel already
/// draws a ring for, and a strip that skipped its row would say
/// something the wheel does not: that the stream is not there. Every
/// other lane KIND (events, lives, kings, ministries) is allowed to
/// vanish when its input list is empty, because an empty list there is
/// the CALLER's choice (a layer switched off) rather than a fact about
/// the corpus — see rule 2: the difference is between "nothing was
/// asked for" and "something exists and has nothing to show", and only
/// the second owes the reader a row.
library;

import 'dart:math' as math;

import 'package:seeksparks/models/chronology.dart' show Patriarch;
import 'package:seeksparks/models/hebrew_king.dart'
    show HebrewKing, Kingdom;
import 'package:seeksparks/models/wheel_history.dart'
    show WheelHistoryData, WheelMinistry, WheelPower;
import 'package:seeksparks/utils/radial_chronology_layout.dart'
    show patriarchsAsSpans;
import 'package:seeksparks/utils/strip_chronology_layout.dart'
    show kStripMaxYear, kStripMinYear, packIntoLanes, xForYear;

/// The kind of content one row of the strip carries.
///
/// Shared between [StripLane] and [StripSpan] so a flat list of spans —
/// pulled out of their lanes for hit-testing across the whole strip,
/// say — can still be dispatched on without walking back to the lane
/// that produced it.
enum StripLaneKind { ruler, events, lives, kings, ministries, stream }

/// The same prefixes `radial_chronology_page.dart` puts on king and
/// ministry ids (`kKingArcPrefix`, `kMinistryArcPrefix`), reproduced
/// here rather than imported. The page is not importable from a model
/// — it carries widgets and the wheel's own selection state — and the
/// two constants are six characters each; keeping the STRINGS in step
/// (not the import) is what lets a tap on the wheel's king arc and a
/// tap on the strip's king bar resolve to the same selection id.
const String kStripKingPrefix = 'king:';
const String kStripMinistryPrefix = 'ministry:';

/// One interval or, when [startYear] equals [endYear], one instant —
/// see the library note on why the two are not separate types.
class StripSpan {
  const StripSpan({
    required this.id,
    required this.kind,
    required this.startYear,
    required this.endYear,
    this.line,
    this.ongoing = false,
  });

  /// Stable across zoom and across rebuilds: the underlying record's
  /// own id (a [WheelPower], a [HebrewKing], a [Patriarch], an event),
  /// prefixed exactly as the wheel prefixes it where two id spaces
  /// could otherwise collide.
  final String id;

  final StripLaneKind kind;

  /// Astronomical years, negative for BC — the same convention every
  /// asset behind this file already uses.
  final int startYear;
  final int endYear;

  /// The colour key: a patriarch's line of descent, a king's kingdom
  /// ('israel' / 'judah'), the fixed string 'ministry', or the owning
  /// stream's own `line` for an event or a power. Never a colour
  /// itself — the page decides hues, same split as [LifeArc.line].
  final String? line;

  /// True only for a [WheelPower] whose `end` is null: a band still
  /// running, drawn to the axis end and labelled accordingly. Never
  /// invented for a kind that cannot be open-ended — see
  /// [WheelPower.ongoing] for why a written-in end year would be a
  /// lie that goes stale every January.
  final bool ongoing;

  bool get isPoint => startYear == endYear;
}

/// One row: a kind, which sub-lane of that kind it is, and the spans
/// packed onto it.
class StripLane {
  const StripLane({
    required this.id,
    required this.kind,
    required this.subLane,
    required this.spans,
    this.ownerId,
  });

  /// `'<kind>:<subLane>'`, or `'<kind>:<ownerId>:<subLane>'` for a
  /// stream lane — unique across one [buildStripLanes] call, stable
  /// across zoom, because [subLane] is assigned in an id-tiebroken
  /// order (see `_packGroup`) rather than by whatever order
  /// [packIntoLanes] happens to visit spans in.
  final String id;

  final StripLaneKind kind;

  /// The owning stream's id for a [StripLaneKind.stream] lane, null
  /// for every other kind — there is only one events lane family, one
  /// kings lane family and so on, so nothing disambiguates them.
  final String? ownerId;

  /// 0-based index within this lane's own kind (and, for a stream,
  /// within that one stream) — NOT a position in the page's overall
  /// row order, which is decided by [buildStripLanes]'s own sequence.
  final int subLane;

  final List<StripSpan> spans;
}

/// One item on its way into a lane group, before packing decides which
/// row it lands on.
typedef _Item = ({
  String id,
  StripLaneKind kind,
  int startYear,
  int endYear,
  String? line,
  bool ongoing,
});

String _laneId(StripLaneKind kind, String? ownerId, int subLane) =>
    ownerId == null
        ? '${kind.name}:$subLane'
        : '${kind.name}:$ownerId:$subLane';

/// Sort, place on pixel-x, pack into lanes, and hand back one
/// [StripLane] per lane the packing actually used.
///
/// [ensureAtLeastOne] is what gives every stream a row even when
/// [items] is empty — see the library note. Every other caller leaves
/// it false: an empty events, lives, kings or ministries group means
/// the caller asked for none, and a group nobody asked for earns no
/// row (rule 2 is about hiding what exists, not about inventing a
/// place-holder for what was never requested).
List<StripLane> _packGroup({
  required List<_Item> items,
  required StripLaneKind kind,
  required String? ownerId,
  required double pxPerYear,
  required int minYear,
  required double minGapPx,
  bool ensureAtLeastOne = false,
}) {
  if (items.isEmpty) {
    if (!ensureAtLeastOne) return const [];
    return [
      StripLane(
        id: _laneId(kind, ownerId, 0),
        kind: kind,
        ownerId: ownerId,
        subLane: 0,
        spans: const [],
      ),
    ];
  }

  // packIntoLanes requires its input sorted by start; the id tiebreak
  // makes the packing (and so every lane's contents and every lane's
  // id) deterministic when two items share a start year, rather than
  // resting on whatever order the caller's own list arrived in.
  final sorted = [...items]..sort((a, b) {
      final byYear = a.startYear.compareTo(b.startYear);
      return byYear != 0 ? byYear : a.id.compareTo(b.id);
    });

  final x0 = [
    for (final it in sorted) xForYear(it.startYear, pxPerYear, minYear: minYear)
  ];
  final x1 = [
    for (final it in sorted) xForYear(it.endYear, pxPerYear, minYear: minYear)
  ];
  final laneOf = packIntoLanes(x0, x1, minGapPx: minGapPx);
  final laneCount = laneOf.fold(0, math.max) + 1;

  final bucket = List.generate(laneCount, (_) => <StripSpan>[]);
  for (var i = 0; i < sorted.length; i++) {
    final it = sorted[i];
    bucket[laneOf[i]].add(StripSpan(
      id: it.id,
      kind: it.kind,
      startYear: it.startYear,
      endYear: it.endYear,
      line: it.line,
      ongoing: it.ongoing,
    ));
  }
  return [
    for (var l = 0; l < laneCount; l++)
      StripLane(
        id: _laneId(kind, ownerId, l),
        kind: kind,
        ownerId: ownerId,
        subLane: l,
        spans: bucket[l],
      ),
  ];
}

List<_Item> _eventItems(
  WheelHistoryData wheel,
  Map<String, String> streamLine,
) =>
    [
      for (final e in wheel.events)
        (
          id: e.id,
          kind: StripLaneKind.events,
          startYear: e.year,
          endYear: e.year,
          line: streamLine[e.stream],
          ongoing: false,
        ),
    ];

List<_Item> _lifeItems(
  List<Patriarch> patriarchs,
  String tradition,
  int creationYear,
) =>
    [
      // The Anno Mundi -> BC conversion lives once, in
      // patriarchsAsSpans, which the wheel already uses for the same
      // reason: a second copy is a second place for the creation
      // anchor to be applied inconsistently.
      for (final s in patriarchsAsSpans(patriarchs, tradition, creationYear))
        (
          id: s.id,
          kind: StripLaneKind.lives,
          startYear: s.startYear,
          endYear: s.endYear,
          line: s.line,
          ongoing: false,
        ),
    ];

List<_Item> _kingItems(List<HebrewKing> kings) => [
      for (final k in kings)
        (
          id: '$kStripKingPrefix${k.id}',
          kind: StripLaneKind.kings,
          startYear: k.reignStart,
          endYear: k.reignEnd,
          line: k.kingdom == Kingdom.israel ? 'israel' : 'judah',
          ongoing: false,
        ),
    ];

List<_Item> _ministryItems(List<WheelMinistry> ministries) => [
      for (final m in ministries)
        (
          id: '$kStripMinistryPrefix${m.id}',
          kind: StripLaneKind.ministries,
          startYear: m.start,
          endYear: m.end,
          line: 'ministry',
          ongoing: false,
        ),
    ];

List<_Item> _powerItems(
  List<WheelPower> powers,
  String streamLine,
  int axisEnd,
) =>
    [
      for (final p in powers)
        (
          id: p.id,
          kind: StripLaneKind.stream,
          startYear: p.start,
          endYear: p.endFor(axisEnd),
          line: streamLine,
          ongoing: p.ongoing,
        ),
    ];

/// Every lane the strip draws, top to bottom: events, lives, kings,
/// ministries, then one group per stream in the asset's own order,
/// each stream's powers packed within it alone — a power never shares
/// a lane with another stream's power, because the two are already on
/// different rows by kind and mixing them would say two unrelated
/// bands are the same band.
///
/// [wheel] supplies the streams, powers, ministries and events.
/// [kings] and [patriarchs] arrive separately because they are read
/// from `hebrew_kings.json` and `chronology.json`, two assets
/// [WheelHistoryData] does not and should not hold. [tradition] and
/// [creationYear] are passed straight through to [patriarchsAsSpans]
/// and carry its own contract: there is no default creation year, so a
/// caller that cannot find one must pass an empty [patriarchs] list
/// rather than invent an anchor.
///
/// [pxPerYear] is required, not defaulted, because a lane assignment
/// at the wrong zoom is not a smaller version of the right one — see
/// the library note.
List<StripLane> buildStripLanes({
  required WheelHistoryData wheel,
  required List<HebrewKing> kings,
  required List<Patriarch> patriarchs,
  required String tradition,
  required int creationYear,
  required double pxPerYear,
  int minYear = kStripMinYear,
  int maxYear = kStripMaxYear,
  double minGapPx = 4,
}) {
  final streamLine = {for (final s in wheel.streams) s.id: s.line};

  final out = <StripLane>[
    ..._packGroup(
      items: _eventItems(wheel, streamLine),
      kind: StripLaneKind.events,
      ownerId: null,
      pxPerYear: pxPerYear,
      minYear: minYear,
      minGapPx: minGapPx,
    ),
    ..._packGroup(
      items: _lifeItems(patriarchs, tradition, creationYear),
      kind: StripLaneKind.lives,
      ownerId: null,
      pxPerYear: pxPerYear,
      minYear: minYear,
      minGapPx: minGapPx,
    ),
    ..._packGroup(
      items: _kingItems(kings),
      kind: StripLaneKind.kings,
      ownerId: null,
      pxPerYear: pxPerYear,
      minYear: minYear,
      minGapPx: minGapPx,
    ),
    ..._packGroup(
      items: _ministryItems(wheel.ministries),
      kind: StripLaneKind.ministries,
      ownerId: null,
      pxPerYear: pxPerYear,
      minYear: minYear,
      minGapPx: minGapPx,
    ),
  ];

  for (final stream in wheel.streams) {
    out.addAll(_packGroup(
      items: _powerItems(wheel.powersOf(stream.id), stream.line, maxYear),
      kind: StripLaneKind.stream,
      ownerId: stream.id,
      pxPerYear: pxPerYear,
      minYear: minYear,
      minGapPx: minGapPx,
      ensureAtLeastOne: true,
    ));
  }
  return out;
}
