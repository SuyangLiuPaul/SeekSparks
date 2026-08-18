/// 2026-08-17 (SeekSparks): joining a journey to the gazetteer.
///
/// Pure, so the joins can be tested without a map. Everything the painter
/// and the panel need is decided here: which stops resolved, which
/// segments may be drawn, which of them are provisional, and how far the
/// whole thing is in straight lines.
///
/// **The join can fail, and failing loudly is the point.** A stop names a
/// gazetteer id; if the gazetteer has no such place, or has it without
/// coordinates, the stop cannot be drawn. The wrong answers are to guess
/// a coordinate and to quietly skip the stop and join its neighbours —
/// the second invents a leg nobody claimed, which is the same lie as the
/// first with better manners. So an unresolved stop BREAKS the line and
/// is counted, and the panel says how many broke.
library;

import 'package:seeksparks/models/bible_journey.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/place_geo.dart' show haversineKm;

/// A stop that found its place.
class ResolvedStop {
  const ResolvedStop({
    required this.index,
    required this.stop,
    required this.place,
    required this.ordinal,
  });

  /// Position in the stop LIST, zero-based — narrative order, asides
  /// included. Not the number shown to a reader.
  final int index;
  final JourneyStop stop;
  final BiblePlace place;

  /// The number the reader sees, one-based over the track only.
  ///
  /// Null for an aside. Numbering asides alongside waypoints would make
  /// Phoenix stop 9 of the voyage to Rome, which says the ship called
  /// there; it did not, and the whole of Acts 27 turns on its not having
  /// done so. A null here is a claim, not a gap.
  final int? ordinal;

  bool get isAside => stop.isAside;
}

/// One drawable leg, from one resolved stop to the next.
class RouteSegment {
  const RouteSegment({
    required this.from,
    required this.to,
    required this.leg,
    required this.attested,
  });

  final ResolvedStop from;
  final ResolvedStop to;
  final JourneyLeg leg;

  /// True only when the text places the travellers at BOTH ends. A leg
  /// out of a provisional stop is itself provisional — drawing it solid
  /// because its destination happens to be named would launder the
  /// uncertainty one hop down the line.
  final bool attested;

  double get km =>
      haversineKm(from.place.lat!, from.place.lon!, to.place.lat!, to.place.lon!);
}

/// A journey joined to the gazetteer, ready to draw.
class ResolvedJourney {
  const ResolvedJourney({
    required this.journey,
    required this.stops,
    required this.segments,
    required this.unresolved,
  });

  final BibleJourney journey;

  /// Every stop that found a located place, in itinerary order.
  final List<ResolvedStop> stops;

  final List<RouteSegment> segments;

  /// Stops whose place is absent from the gazetteer or has no
  /// coordinates. Their ids, in order, so a message can name them.
  final List<String> unresolved;

  String get id => journey.id;

  bool get isEmpty => stops.isEmpty;

  /// Sum of the straight lines between consecutive stops.
  ///
  /// **Not the distance travelled**, and no surface may print it as one:
  /// roads bend, ships tack, and every segment here is a chord between
  /// two points rather than a route. It is offered as a scale — Paul's
  /// first journey is a two-thousand-kilometre object, not a day out —
  /// and the string that prints it says what it is.
  double get straightLineKm =>
      segments.fold(0.0, (sum, s) => sum + s.km);

  /// Which ordinals each place carries, in itinerary order.
  ///
  /// Lystra is stops 8 and 10 of the first journey, so its marker reads
  /// `8,10`. One marker per place rather than per stop: two badges at one
  /// coordinate overprint into an unreadable smudge, and the doubling
  /// back is worth *saying* rather than hiding.
  ///
  /// An aside contributes nothing, so a place that is ONLY an aside is
  /// absent from this map rather than present with an empty list — the
  /// painter reads a missing key as "draw no badge".
  Map<String, List<int>> get ordinalsByPlace {
    final out = <String, List<int>>{};
    for (final s in stops) {
      final n = s.ordinal;
      if (n == null) continue;
      (out[s.place.id] ??= <int>[]).add(n);
    }
    return out;
  }

  /// One entry per place, first appearance order — what the painter walks
  /// to draw markers.
  ///
  /// Where a place is both an aside and a waypoint, the waypoint wins
  /// however the file orders them: a place they DID reach must not be
  /// drawn as one they only aimed at because the narrative happened to
  /// mention it first.
  List<ResolvedStop> get markers {
    final at = <String, int>{};
    final out = <ResolvedStop>[];
    for (final s in stops) {
      final seen = at[s.place.id];
      if (seen == null) {
        at[s.place.id] = out.length;
        out.add(s);
      } else if (out[seen].isAside && !s.isAside) {
        out[seen] = s;
      }
    }
    return out;
  }
}

/// Join [journey] to [byId], keeping the itinerary's order and breaks.
ResolvedJourney resolveJourney(
    BibleJourney journey, Map<String, BiblePlace> byId) {
  final stops = <ResolvedStop>[];
  final segments = <RouteSegment>[];
  final unresolved = <String>[];

  // Null after a stop that did not resolve, which is what breaks the line
  // rather than bridging the gap.
  ResolvedStop? previous;
  JourneyStop? previousRaw;
  var ordinal = 0;

  for (var i = 0; i < journey.stops.length; i++) {
    final raw = journey.stops[i];
    final place = byId[raw.placeId];
    if (place == null || !place.located) {
      unresolved.add(raw.placeId);
      // An aside is beside the track, so losing it costs a marker and
      // nothing else. Only a missing WAYPOINT breaks the line, because
      // only a waypoint was holding it together.
      if (!raw.isAside) {
        previous = null;
        previousRaw = null;
      }
      continue;
    }
    final here = ResolvedStop(
      index: i,
      stop: raw,
      place: place,
      ordinal: raw.isAside ? null : ++ordinal,
    );
    stops.add(here);

    // An aside joins to nothing and interrupts nothing: the leg that
    // passes it — Fair Havens to Cauda, straight through the Phoenix
    // they never made — is drawn from the waypoints on either side.
    if (raw.isAside) continue;

    if (previous != null && previousRaw != null &&
        raw.leg != JourneyLeg.start) {
      segments.add(RouteSegment(
        from: previous,
        to: here,
        leg: raw.leg,
        attested: raw.attested && previousRaw.attested,
      ));
    }
    previous = here;
    previousRaw = raw;
  }

  return ResolvedJourney(
    journey: journey,
    stops: stops,
    segments: segments,
    unresolved: unresolved,
  );
}

/// Which lane, in pixels either side of the chord, each segment draws in.
///
/// Outer list parallel to [journeys], inner parallel to that journey's
/// segments.
///
/// **Without this the return leg is invisible.** Paul's first journey
/// walks Antioch→Iconium→Lystra and then walks the whole of it back;
/// drawn on the same chord the return overprints the outbound exactly and
/// a there-and-back itinerary reads as a one-way trip. The second journey
/// retraces the first through Galatia, so the same is true between
/// routes, where it would also hide one colour under another.
///
/// A corridor is an unordered pair of places, and its legs are spread
/// symmetrically about the chord — so a corridor carrying one leg is
/// drawn exactly where it always was, and the device costs nothing on the
/// common case.
///
/// **The sign convention is the part that is easy to get backwards.** The
/// number is an offset along the perpendicular of the segment's OWN
/// direction of travel, and that direction reverses on the way home, so
/// an out-and-back pair is handed the SAME number and the reversal is
/// what puts the two legs on opposite sides. Handing them opposite
/// numbers — the obvious thing to do — would cancel against the reversal
/// and stack them right back on top of each other.
List<List<double>> corridorLanes(
  List<ResolvedJourney> journeys, {
  double spacing = 3.4,
}) {
  final counts = <String, int>{};
  for (final j in journeys) {
    for (final s in j.segments) {
      final k = _corridorKey(s);
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  final taken = <String, int>{};
  final out = <List<double>>[];
  for (final j in journeys) {
    final lanes = <double>[];
    for (final s in j.segments) {
      final k = _corridorKey(s);
      final n = counts[k]!;
      final i = taken[k] = (taken[k] ?? -1) + 1;
      final offset = (i - (n - 1) / 2) * spacing;
      lanes.add(_reversed(s) ? -offset : offset);
    }
    out.add(lanes);
  }
  return out;
}

bool _reversed(RouteSegment s) =>
    s.from.place.id.compareTo(s.to.place.id) > 0;

String _corridorKey(RouteSegment s) => _reversed(s)
    ? '${s.to.place.id}|${s.from.place.id}'
    : '${s.from.place.id}|${s.to.place.id}';

/// Join every journey, dropping any that resolved to nothing at all.
List<ResolvedJourney> resolveJourneys(
    List<BibleJourney> journeys, List<BiblePlace> places) {
  final byId = <String, BiblePlace>{for (final p in places) p.id: p};
  final out = <ResolvedJourney>[];
  for (final j in journeys) {
    final r = resolveJourney(j, byId);
    if (!r.isEmpty) out.add(r);
  }
  return out;
}
