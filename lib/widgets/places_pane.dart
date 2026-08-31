/// 2026-08-08 (SeekSparks): the Places tab.
///
/// Answers the question BibleWorks' map module cannot be asked: **what
/// places does the passage in front of me name?** bwh33 offers only the
/// reverse — right-click an English word you have already guessed is a
/// place, and a Find Place window opens somewhere else. This is the
/// gazetteer read the other way round, and it costs the reader nothing:
/// the list is simply there, next to the verse.
///
/// Two tiers, and the second is what makes the tab worth opening. Most
/// verses name no place at all, so a pane showing only the focused
/// verse would sit empty most of the time and read as broken. The
/// chapter is the context the reader is already in, so it is the honest
/// fallback — "here, and here is the rest of what this chapter walks
/// through".
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/book_name_mapping.dart' show BookScript;
import 'package:seeksparks/constants/journey_style.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/services/journeys_service.dart';
import 'package:seeksparks/services/places_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/journey_route.dart';
import 'package:seeksparks/utils/passage_journeys.dart';

class PlacesPane extends StatefulWidget {
  const PlacesPane({
    super.key,
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.locale,
    required this.script,
    required this.onOpenAtlas,
    required this.onOpenJourney,
  });

  final String englishBook;
  final int chapter;
  final int verse;
  final String locale;

  /// Place names follow the READING VERSION, not the UI locale — the
  /// same rule as book names (task #283). A reader in CUVS gets
  /// 耶路撒冷 beside 耶路撒冷 in the text, not "Jerusalem".
  final BookScript script;

  /// Opens the Atlas on this passage, focused on `id` when a row rather
  /// than the header button was tapped.
  ///
  /// The pane hands over the places it has ALREADY loaded rather than a
  /// reference for the Atlas to look up again. That is not an
  /// optimisation: it is what keeps the map showing the same set the
  /// list showed, even if the reader moves the verse underneath while
  /// the Atlas is open.
  final void Function(List<BiblePlace> places, String? id) onOpenAtlas;

  /// Opens the Atlas with [journeyId] switched on and its itinerary
  /// open.
  ///
  /// It does NOT carry the passage's places across the way
  /// [onOpenAtlas] does, and that is deliberate: a route spans places
  /// the chapter never names — the first journey touches fifteen — so
  /// framing the Atlas on the chapter while drawing a route through it
  /// would leave most of the line outside the filter. #319's rule is
  /// that the filter must never silently narrow what the map shows;
  /// the honest read of it here is to open the route unfiltered.
  final void Function(String journeyId) onOpenJourney;

  @override
  State<PlacesPane> createState() => _PlacesPaneState();
}

class _PaneData {
  const _PaneData({required this.places, required this.journeys});
  final PassagePlaces places;
  final List<JourneyHere> journeys;
  bool get isEmpty => places.isEmpty && journeys.isEmpty;
}

class _PlacesPaneState extends State<PlacesPane> {
  late Future<_PaneData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(PlacesPane old) {
    super.didUpdateWidget(old);
    if (old.englishBook != widget.englishBook ||
        old.chapter != widget.chapter ||
        old.verse != widget.verse) {
      _future = _load();
    }
  }

  Future<_PaneData> _load() async {
    final places = await PlacesService.forPassage(
        widget.englishBook, widget.chapter, widget.verse);
    // 52 KB, cached process-wide by JourneysService and already loaded
    // by the Atlas in most sessions. Fetched here rather than passed in
    // because the pane is the only thing that knows which passage it is
    // showing.
    List<ResolvedJourney> journeys = const <ResolvedJourney>[];
    try {
      journeys = await JourneysService.all();
    } catch (e) {
      // A route overlay that will not load must cost the routes, never
      // the gazetteer list the reader came for. Same call the base map
      // makes at places_service.dart:177.
      debugPrint('PlacesPane: journeys unavailable ($e)');
    }
    return _PaneData(
      places: places,
      journeys: journeysThrough(
          widget.englishBook, widget.chapter, widget.verse, journeys),
    );
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    return FutureBuilder<_PaneData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final data = snap.data;
        if (data == null || data.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _s('placesNone',
                    'This chapter names no place in the gazetteer.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: t.text,
                  color: c.mutedText,
                  height: 1.5,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
          physics: const BouncingScrollPhysics(),
          children: [
            _mapButton(c, t, data.places),
            _journeys(c, t, data.journeys),
            if (data.places.verse.isNotEmpty) ...[
              _sectionTitle(
                  c, t, _s('placesInThisVerse', 'Named in this verse')),
              for (final p in data.places.verse)
                _row(c, t, p, data.places, emphasised: true),
            ],
            if (data.places.chapter.isNotEmpty) ...[
              _sectionTitle(c, t,
                  _s('placesInThisChapter', 'Elsewhere in this chapter')),
              for (final p in data.places.chapter)
                _row(c, t, p, data.places, emphasised: false),
            ],
            if (PlacesService.attribution.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  PlacesService.attribution,
                  style: TextStyle(
                    fontSize: t.chrome,
                    color: c.mutedText,
                    height: 1.35,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The itineraries this passage is part of.
  ///
  /// Above the place lists rather than below them because it is the
  /// FRAME: the places named in Acts 13 are the stops of the first
  /// journey, and a reader who learns that first reads the list under
  /// it differently.
  Widget _journeys(WbColors c, WbType t, List<JourneyHere> on) {
    if (on.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('places-journeys'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
            c, t, _s('placesJourneysHeader', 'Journeys through this passage')),
        for (final e in on) _journey(c, t, e),
      ],
    );
  }

  Widget _journey(WbColors c, WbType t, JourneyHere e) {
    final j = e.journey.journey;
    final style = journeyStyleFor(c, j.style, j.mark);
    final n = e.chapterRows.length;
    final chapterLine = n == 1
        ? _s('placesJourneyInChapterOne', '1 stop in this chapter')
        : _s('placesJourneyInChapter', '{n} stops in this chapter')
            .replaceAll('{n}', '$n');
    final verseLine = e.verseRows.isEmpty
        ? null
        : _s('placesJourneyThisVerse', 'This verse: {stops}').replaceAll(
            '{stops}',
            e.verseRows.map(_stopLabel).join(' · '),
          );
    return InkWell(
      onTap: () => widget.onOpenJourney(e.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 6),
              // The swatch is the route's identity — hue AND silhouette,
              // never hue alone. It is lit because this list is not a
              // set of toggles: nothing here is switched off.
              child: JourneySwatch(style: style, lit: true),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    j.localizedName(widget.locale),
                    style: TextStyle(
                      fontSize: t.text,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      height: 1.3,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                  if (verseLine != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        verseLine,
                        style: TextStyle(
                          fontSize: t.chrome,
                          color: c.text,
                          height: 1.35,
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      '${j.localizedRange(widget.locale)} · $chapterLine',
                      style: TextStyle(
                        fontSize: t.chrome,
                        color: c.mutedText,
                        height: 1.35,
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One stop of the focused verse: its number where it has one, and the
  /// standing tag where it does not.
  ///
  /// **An unplaced stop gets no number and an aside gets no number** —
  /// the same rule `atlas_page.dart:1573` states and for the same
  /// reason: `resolveJourney` does not spend an ordinal on either, so a
  /// number printed here would be one no marker on the map agrees with.
  String _stopLabel(ItineraryRow r) {
    final ordinal = r.placed?.ordinal;
    final parts = <String>[
      if (ordinal != null)
        _s('atlasPlaceJourneyStop', 'Stop {n}').replaceAll('{n}', '$ordinal'),
      if (r.placed == null) _s('journeyNoLocationTag', 'No location on our map'),
      if (r.stop.isAside) _s('journeyAsideTag', 'Named, not reached'),
      if (!r.stop.isAside && !r.stop.attested)
        _s('journeyProvisionalTag', 'Provisional'),
    ];
    return parts.join(' ');
  }

  Widget _mapButton(WbColors c, WbType t, PassagePlaces data) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => widget.onOpenAtlas(data.all, null),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: c.border, width: WbMetrics.hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public, size: t.text + 1, color: c.link),
                const SizedBox(width: 6),
                Text(
                  _s('placesShowMap', 'Show on map'),
                  style: TextStyle(
                    fontSize: t.text,
                    color: c.link,
                    fontWeight: FontWeight.w600,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _sectionTitle(WbColors c, WbType t, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: t.chrome,
            fontWeight: FontWeight.w700,
            color: c.mutedText,
            letterSpacing: 0.3,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      );

  Widget _row(WbColors c, WbType t, BiblePlace p, PassagePlaces data,
      {required bool emphasised}) {
    final display = p.displayName(widget.script);
    // The English name is kept beside a Chinese one rather than
    // replaced by it: the gazetteer, every atlas and every commentary
    // the reader might reach for are indexed in English, so dropping it
    // would make the pane a dead end.
    final showEnglish = display != p.name;

    return InkWell(
      onTap: () => widget.onOpenAtlas(data.all, p.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.5),
              child: Icon(
                p.located ? Icons.place : Icons.help_outline,
                size: t.text,
                color: p.located
                    ? (emphasised ? c.link : c.mutedText)
                    : c.mutedText,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: t.text,
                            fontWeight: emphasised
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: c.text,
                            fontFamilyFallback: kCjkFontFallback,
                          ),
                        ),
                      ),
                      // The disambiguating numeral, kept visible:
                      // Antioch 1 is Syrian and Antioch 2 is Pisidian,
                      // 500 km apart, and a list that printed both as
                      // "Antioch" would be actively misleading.
                      if (p.ordinal != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Text(
                            '${p.ordinal}',
                            style: TextStyle(
                              fontSize: t.chrome,
                              color: c.mutedText,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        '${p.refs.length} ${_s('placesOccurrences', 'refs')}',
                        style: TextStyle(
                          fontSize: t.chrome,
                          color: c.mutedText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                    ],
                  ),
                  if (showEnglish || !p.located)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        [
                          if (showEnglish) p.name,
                          if (!p.located)
                            _s('placesUnlocated', 'location unknown'),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: t.chrome,
                          color: c.mutedText,
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
