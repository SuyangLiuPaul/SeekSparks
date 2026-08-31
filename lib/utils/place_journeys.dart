/// 2026-09-01 (SeekSparks, #317): which journeys name a place.
///
/// `journey_route.dart` answers "what does this route touch". This
/// answers the question a reader actually arrives with — they are
/// looking at Antioch, not at a route — and it is the direction the
/// Atlas has never had. Syrian Antioch is the sending church of all
/// three Pauline journeys and the place two of them come back to, and
/// until now its place record said only that Acts names it.
///
/// **It states no more than the itinerary does.** An aside keeps its
/// null ordinal, a stop the gazetteer cannot place is reported WITHOUT
/// one — `UnplacedStop` has no ordinal by design, so the badge on the
/// map and the number here can never disagree — and a provisional stop
/// stays provisional. The three shipped tags (`journeyProvisionalTag`,
/// `journeyAsideTag`, `journeyNoLocationTag`) are the vocabulary; this
/// file invents none.
library;

import 'package:seeksparks/utils/journey_route.dart';

/// One journey, and every place in it that is THIS place.
class PlaceOnJourney {
  const PlaceOnJourney({required this.journey, required this.rows});

  final ResolvedJourney journey;

  /// Every appearance, in narrative order. More than one is the ordinary
  /// case for an itinerary that doubles back — Perga is stops 5 and 13
  /// of the first journey — and collapsing them to one row would delete
  /// the return leg, which is half of Acts 14.
  final List<ItineraryRow> rows;

  String get id => journey.id;
}

/// The journeys naming [placeId], in the order the asset lists them.
///
/// Asset order, not "most stops first": the file's order is a curatorial
/// decision already made — the three Pauline journeys in sequence — and
/// re-sorting it here would give a reader two different orders for the
/// same six routes on one screen.
List<PlaceOnJourney> journeysNaming(
    String placeId, List<ResolvedJourney> journeys) {
  final out = <PlaceOnJourney>[];
  for (final j in journeys) {
    final rows = <ItineraryRow>[
      for (final r in j.itineraryRows)
        if (r.stop.placeId == placeId) r,
    ];
    if (rows.isNotEmpty) out.add(PlaceOnJourney(journey: j, rows: rows));
  }
  return out;
}
