/// 2026-09-01 (SeekSparks, #317): which journeys run through a passage.
///
/// `place_journeys.dart` answers "which routes name THIS PLACE" for a
/// reader standing in the Atlas. This answers the question a reader
/// standing in the TEXT arrives with, which is the one the ticket was
/// actually about — 「圣经里面很多不同的路线，以及对应的章节」, the routes
/// and the chapters they correspond to. Acts 13 is the first journey;
/// until now the pane beside that chapter said only that the gazetteer
/// knows Seleucia.
///
/// **Two tiers, and they are the pane's own two tiers.** `PlacesPane`
/// already splits what the verse names from what the chapter names
/// (`PlacesService.forPassage`), because most verses name nowhere and a
/// verse-only pane would read as broken. A journey section that used a
/// different split would give the reader two grammars on one screen.
///
/// **The chapter tier is a COUNT, never a list.** Numbers 33 puts 42
/// stops in one chapter; 42 rows would bury the pane and would bury the
/// gazetteer list underneath it. The verse tier is a list because it is
/// bounded — the shipped asset's worst verse carries three stops.
///
/// It states no more than the itinerary does, and invents no vocabulary:
/// an aside keeps its null ordinal, a stop the gazetteer cannot place is
/// reported without one, and a provisional stop stays provisional. The
/// three shipped tags are the words for all of that.
library;

import 'package:seeksparks/utils/journey_route.dart';

/// One journey, and what THIS passage contributes to it.
class JourneyHere {
  const JourneyHere({
    required this.journey,
    required this.verseRows,
    required this.chapterRows,
  });

  final ResolvedJourney journey;

  /// Stops the focused verse itself cites, in narrative order. Empty is
  /// ordinary and is not a reason to drop the journey: Acts 18:23 puts
  /// no stop of the SECOND journey on the page, but the second journey
  /// ends in Acts 18 and a reader there should be told so.
  final List<ItineraryRow> verseRows;

  /// Every stop this chapter cites, [verseRows] INCLUDED, in narrative
  /// order.
  ///
  /// Included rather than subtracted so the printed count is exactly
  /// true with no qualifier: "7 stops in this chapter" needs no reader
  /// to work out whether the one above it was counted. The alternative —
  /// mirroring `PassagePlaces`, which does lift the verse's places out
  /// of the chapter list — was rejected because it forces the label to
  /// say "more" or "other", and "6 more stops" is wrong the moment the
  /// verse tier is empty, which it is for most verses of every cited
  /// chapter.
  final List<ItineraryRow> chapterRows;

  String get id => journey.id;
}

/// The journeys whose itineraries cite [englishBook] [chapter], in the
/// order the asset lists them.
///
/// Asset order, not "most stops first" — the same argument
/// [journeysNaming] makes: the file's order is a curatorial decision
/// already made, and re-sorting here would give a reader two different
/// orders for the same six routes on one screen.
List<JourneyHere> journeysThrough(
  String englishBook,
  int chapter,
  int verse,
  List<ResolvedJourney> journeys,
) {
  final out = <JourneyHere>[];
  for (final j in journeys) {
    final inChapter = <ItineraryRow>[
      for (final r in j.itineraryRows)
        if (r.stop.englishBook == englishBook && r.stop.chapter == chapter) r,
    ];
    if (inChapter.isEmpty) continue;
    out.add(JourneyHere(
      journey: j,
      verseRows: <ItineraryRow>[
        for (final r in inChapter)
          if (r.stop.verse == verse) r,
      ],
      chapterRows: inChapter,
    ));
  }
  return out;
}
