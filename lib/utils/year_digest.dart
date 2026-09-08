/// What a single year holds — the readout behind the year cursor on both
/// chronology forms.
///
/// WHY THIS EXISTS. Both the wheel and the strip could always be *read*
/// — a reader could find a bar and follow it back to the ruler — and
/// neither could be *interrogated*. There was no line and no year under
/// the pointer, so the honest report of the owner's own complaint was
/// exact: 「没有线根本不知道哪一年」. A cursor answers the first half of
/// that ("which year"); this file answers the second half ("and what
/// happened in it"), which is the part a ruler cannot draw.
///
/// WHY IT TAKES LANES AND NOT THE CORPUS. `buildStripLanes` already
/// resolved every question this file would otherwise have to re-answer:
/// which tradition anchors the patriarchs, which layers the reader has
/// switched off, how a king with two reigns becomes two spans, and what
/// a lineage cohort's year is. Reading its output means the digest can
/// never disagree with the picture — if a lane is hidden, its records
/// are absent from both. The wheel has no lanes of its own, so it calls
/// `buildStripLanes` for this purpose alone; that is a pure function of
/// a corpus it already holds, and paying it once per corpus load is the
/// price of the two forms agreeing about a year.
///
/// THE FOUR MOMENTS ARE NOT DECORATION. A reader asking "what happened
/// in 586 BC" does not mean "list everything that was in progress" —
/// Methuselah being alive is not news, and 700 lifespans would bury the
/// fall of Jerusalem. So a span is sorted by what the year IS to it:
/// [YearMoment.happened] for a record that occupies exactly that year,
/// [YearMoment.began] and [YearMoment.ended] for its two edges, and
/// [YearMoment.ongoing] for the long middle. Only the first three are
/// events in the reader's sense; [YearDigest.ongoing] is offered as
/// context underneath, and is counted rather than recited when it runs
/// long.
///
/// AN OPEN-ENDED SPAN NEVER ENDS, WHATEVER ITS END YEAR SAYS.
/// `strip_lanes.dart` gives a `WheelPower` with no recorded end an
/// `endYear` of `kStripMaxYear` and flags it `ongoing` — the year is
/// there so the BAR reaches the edge of the axis, and the flag is there
/// because writing a real end year would be a lie. The first cut of
/// this file read that painted sentinel as a real end and would have
/// reported, at the cursor's last year, that the State of Israel, the
/// Order of Malta and the current papacy all ended in 2026. So the flag
/// is carried through as [YearDigestItem.openEnded] and the last year
/// of such a span is [YearMoment.ongoing], never [YearMoment.ended].
///
/// A ZERO-LENGTH SPAN IS [YearMoment.happened], NOT "began and ended".
/// Four reigns in this corpus (Zimri, Huldah, Ahaziah of Judah,
/// Jehoahaz of Judah) begin and end in the same year, and the strip's
/// own rule 1 — painted width is duration — leaves them 0.00 px wide at
/// every zoom. They are exactly the records a cursor is for, and
/// reporting one twice, once as a beginning and once as an end, would
/// be the same record counted two ways.
///
/// Kept free of widgets, and of locale: an id and a moment is all a
/// caller needs to look up its own label in the map it already built.
library;

import 'package:seeksparks/models/strip_lanes.dart'
    show StripLane, StripLaneKind, StripSpan;

/// What the cursor's year is to one record.
enum YearMoment {
  /// The record occupies this year and no other — an event tick, or a
  /// span whose start and end are both here.
  happened,

  /// The record's first year, and it runs on past it.
  began,

  /// The record's last year, and it started before it.
  ended,

  /// The year falls strictly inside the record: neither edge is here.
  ongoing,
}

/// One record the cursor's year touches.
class YearDigestItem {
  const YearDigestItem({
    required this.id,
    required this.kind,
    required this.moment,
    required this.startYear,
    required this.endYear,
    this.line,
    this.openEnded = false,
  });

  /// The selection id the two pages already agree on — prefixed exactly
  /// as `strip_lanes.dart` prefixes it, so tapping a digest row can
  /// open the same sheet a tap on the chart opens.
  final String id;

  final StripLaneKind kind;
  final YearMoment moment;
  final int startYear;
  final int endYear;

  /// The colour key ([StripSpan.line]), carried through so a digest row
  /// can wear the same hue its bar does.
  final String? line;

  /// True when [endYear] is the axis end standing in for "no recorded
  /// end" ([StripSpan.ongoing]) rather than a year anything is claimed
  /// to have happened in.
  final bool openEnded;

  /// How many years the record runs, counting both ends. A zero-length
  /// span is one year, not zero — it happened.
  ///
  /// For an [openEnded] record this is years-so-far against the end of
  /// the axis, not a claim about a duration: the record has no end to
  /// measure to.
  int get years => endYear - startYear + 1;
}

/// Everything one year holds, split into what happened in it and what
/// was merely under way.
class YearDigest {
  const YearDigest({
    required this.year,
    required this.happened,
    required this.ongoing,
  });

  final int year;

  /// Records that began, ended, or fell entirely in this year.
  ///
  /// Sorted by what the year IS to each — wholly this year first, then
  /// beginnings, then endings — and only WITHIN one of those by the
  /// reading order the two forms already use (events, lifespans,
  /// reigns, ministries, the genealogy rail, the streams' own bands).
  /// See [_momentRank] for why the moment outranks the lane.
  final List<YearDigestItem> happened;

  /// Records under way but with neither edge here. Long, and meant to
  /// be counted before it is recited.
  final List<YearDigestItem> ongoing;

  bool get isEmpty => happened.isEmpty && ongoing.isEmpty;

  /// How many ongoing records are of [kind] — the counts a compact
  /// readout prints instead of a list of seven hundred lifespans.
  int ongoingOf(StripLaneKind kind) =>
      ongoing.where((i) => i.kind == kind).length;
}

/// The order both forms already draw these in, so the digest reads down
/// the page in the order the chart reads down the screen.
const List<StripLaneKind> _kKindOrder = [
  StripLaneKind.events,
  StripLaneKind.lives,
  StripLaneKind.kings,
  StripLaneKind.ministries,
  StripLaneKind.rail,
  StripLaneKind.stream,
];

int _kindRank(StripLaneKind kind) {
  final i = _kKindOrder.indexOf(kind);
  return i < 0 ? _kKindOrder.length : i;
}

/// Sort what happened first by the moment a reader cares about most —
/// a record that is wholly this year, then one that started, then one
/// that ended — and only then by kind and id.
///
/// Moment before kind, deliberately: 「当年发生什么事情」 asks what
/// happened, and an event that IS this year outranks a reign that
/// merely began in it, whatever lane each is drawn on.
int _momentRank(YearMoment m) => switch (m) {
      YearMoment.happened => 0,
      YearMoment.began => 1,
      YearMoment.ended => 2,
      YearMoment.ongoing => 3,
    };

/// What [year] holds, read off the same lanes the chart is drawing.
///
/// [lanes] is `buildStripLanes`' output — hidden layers already absent,
/// so the digest and the picture cannot disagree. Ids repeat across
/// lanes only for a record packed into more than one row, which the
/// packer does not do, but the dedup is kept anyway: a caller may
/// concatenate two lane lists (the strip's rows do not, the wheel's
/// might) and a record named twice reads as two records.
YearDigest buildYearDigest({
  required int year,
  required List<StripLane> lanes,
}) {
  final happened = <YearDigestItem>[];
  final ongoing = <YearDigestItem>[];
  final seen = <String>{};

  for (final lane in lanes) {
    if (lane.kind == StripLaneKind.ruler) continue;
    for (final StripSpan span in lane.spans) {
      final lo = span.startYear <= span.endYear ? span.startYear : span.endYear;
      final hi = span.startYear <= span.endYear ? span.endYear : span.startYear;
      if (year < lo || year > hi) continue;
      if (!seen.add(span.id)) continue;

      // Zero-length first: a span that begins and ends here happened
      // here, and must not be reported as both edges. Open-ended next,
      // because its `hi` is a painted sentinel and reporting an end
      // there is the one thing the flag exists to prevent.
      final moment = (lo == hi && !span.ongoing)
          ? YearMoment.happened
          : year == lo
              ? YearMoment.began
              : (year == hi && !span.ongoing)
                  ? YearMoment.ended
                  : YearMoment.ongoing;

      final item = YearDigestItem(
        id: span.id,
        kind: span.kind,
        moment: moment,
        startYear: lo,
        endYear: hi,
        line: span.line,
        openEnded: span.ongoing,
      );
      (moment == YearMoment.ongoing ? ongoing : happened).add(item);
    }
  }

  happened.sort((a, b) {
    final m = _momentRank(a.moment).compareTo(_momentRank(b.moment));
    if (m != 0) return m;
    final k = _kindRank(a.kind).compareTo(_kindRank(b.kind));
    if (k != 0) return k;
    return a.id.compareTo(b.id);
  });
  ongoing.sort((a, b) {
    final k = _kindRank(a.kind).compareTo(_kindRank(b.kind));
    if (k != 0) return k;
    // Longest-running first: at a cursor in 1000 BC, "Methuselah, 969
    // years" is the answer to "what is going on here", and a reign that
    // started last year is not.
    final len = b.years.compareTo(a.years);
    if (len != 0) return len;
    return a.id.compareTo(b.id);
  });

  return YearDigest(year: year, happened: happened, ongoing: ongoing);
}
