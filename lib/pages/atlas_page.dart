/// 2026-08-09 (SeekSparks): the Atlas — the ONE map surface, opened from
/// Resources.
///
/// **Why this page exists rather than a second map.** `DELETION-REVIEW`
/// §4 found the app growing two of them: a lens over the workbench's
/// centre pane, and the #277 Places tab's "Show on map". The user's
/// decision on 2026-08-08 was one map surface, reached from Resources
/// the way the family tree is, with the gazetteer feeding it — the
/// verse-linked question ("what does this passage name?") stays in the
/// Analysis pane, but the MAP moves out of the reading column. That is
/// also bwh07's own filing: a map is a reference database you CONSULT,
/// not a tool that operates on the text in front of you.
///
/// **What it is, in one line.** The index at the back of a printed
/// atlas, wired to the plate: type a name, see where it is, and read the
/// list of every verse that names it.
///
/// **Where BibleWorks stops.** bwh33's Find Place window locates a site
/// by name and then offers exactly one route back to scripture: a
/// right-click that runs a *text search* for the word. That is weaker
/// than it sounds, in two ways this page fixes.
///
///   1. It cannot tell Syrian Antioch from Pisidian Antioch. They are
///      500 km apart and spelled identically, so the search returns both
///      cities' verses under one pin, at one set of coordinates. The
///      gazetteer keeps them as two entries with two locations, and this
///      page draws both.
///
///      It does NOT divide the verses between them, and this file used
///      to say it did. Measured: of the gazetteer's 80 ordinal groups,
///      66 carry byte-identical reference lists — `Antioch 1` and
///      `Antioch 2` have the same 18 — and all 14 of the rest overlap.
///      Not one is a clean partition. The ordinal separates the SITES;
///      the reference list is shared, and saying otherwise was a claim
///      read off the shape of the data rather than out of it. See
///      `docs/DATA-INTEGRITY.md` check 38.
///   2. It is English-only, because the maps database is indexed in
///      English. A reader in CUVS gets nothing. Here the index searches
///      English, Simplified and Traditional names at once whatever the
///      reading version is, and *prints* the name in the reading
///      version's script (#283).
///
/// The book scope (#280) is the third thing BibleWorks' map has no
/// equivalent of: scoped to Acts, the index stops being a gazetteer and
/// becomes the itinerary of Acts, ordered by how much of Acts happens
/// there.
///
/// Ranking, scoping, grouping and the label budget are all in
/// `utils/atlas_index.dart`, which is pure and under test. This file is
/// layout.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/book_name_mapping.dart'
    show BookScript, bookScriptFor;
import 'package:seeksparks/constants/journey_style.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/bible_journey.dart' show JourneyLeg;
import 'package:seeksparks/models/bible_map.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/pages/map_viewer_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/journeys_service.dart';
import 'package:seeksparks/services/map_service.dart';
import 'package:seeksparks/services/places_service.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/utils/atlas_index.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/journey_route.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/navigate_to_reader.dart';
import 'package:seeksparks/utils/place_geo.dart' show BaseMap;
import 'package:seeksparks/utils/place_illustrations.dart';
import 'package:seeksparks/utils/reference_parser.dart' show parseReference;
import 'package:seeksparks/utils/search_scope.dart'
    show limitSpecForBooks, scopeDisplayName, scopedCountLabel;
import 'package:seeksparks/utils/travel_time.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/illustration_image.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/place_map.dart';
import 'package:seeksparks/widgets/search_scope_sheet.dart';

/// Below this the map cannot sit beside the index and goes above it.
///
/// 880 = a 336 px index plus a map still wide enough to hold the Levant
/// and its labels. Narrower than that the map is a strip, and a strip is
/// worse than a map with a list under it.
const double _mapBesideIndexMin = 880;

/// Below this the selected place's detail arrives as a sheet instead of
/// as a third column — a 320 px panel taken out of anything less leaves
/// the map too narrow to be the reason the page exists.
const double _detailColumnMin = 1180;

const double _indexPanelWidth = 336;
const double _detailPanelWidth = 320;

/// The one map surface. Everything is optional, because the page has to
/// stand alone when opened cold from the Resources menu.
class AtlasPage extends StatefulWidget {
  const AtlasPage({
    super.key,
    this.subjectPlaces,
    this.subjectLabel,
    this.initialPlaceId,
  });

  /// Places to open on — the passage's, when the Analysis pane sent the
  /// reader here. The index is filtered to them and the header says so,
  /// and the filter is DISMISSIBLE: an atlas that could only ever show
  /// one chapter would not be an atlas.
  final List<BiblePlace>? subjectPlaces;

  /// What [subjectPlaces] is, printed in the filter chip — a reference,
  /// normally.
  final String? subjectLabel;

  /// Selected and centred on open.
  final String? initialPlaceId;

  @override
  State<AtlasPage> createState() => _AtlasPageState();
}

class _AtlasPageState extends State<AtlasPage> {
  final TextEditingController _search = TextEditingController();

  List<BiblePlace>? _all;
  BaseMap _base = BaseMap.empty();

  String _query = '';
  Set<String>? _scopeBooks;
  AtlasSort _sort = AtlasSort.references;
  String? _selectedId;

  /// Whether the map also draws what the filter left out.
  ///
  /// Off, so that the map answers the same question the index does. It
  /// is sticky once turned on — a reader who asked for the surrounding
  /// names should not have to ask again after every keystroke.
  bool _showContext = false;

  /// #317 / bwh33. Session-only, deliberately: #280 settled that a
  /// filter which silently persists is worse than one the reader re-sets,
  /// and a persisted pace would quietly re-word every estimate on a later
  /// launch with no visible cause.
  TravelBand _band = kDefaultTravelBand;

  /// The ids of [AtlasPage.subjectPlaces] while the filter is up, null
  /// once it is dismissed or superseded.
  Set<String>? _subjectIds;

  int _fitToken = 0;
  int _focusToken = 0;

  /// What the next re-fit should frame, when the layers would get it
  /// wrong. See [PlaceMapView.fitPoints]. Cleared by every other kind of
  /// question, so it never outlives the toggle that set it.
  List<(double, double)>? _fitPoints;

  /// Every journey in the asset. Empty until it lands, so the block
  /// simply is not there rather than flashing an empty header.
  List<ResolvedJourney> _journeys = const <ResolvedJourney>[];

  /// The ids switched on, in asset order when drawn.
  final Set<String> _onRoutes = <String>{};

  /// The one whose itinerary is open in the detail column.
  String? _readingRouteId;

  /// The single leg the reader clicked, if any.
  ///
  /// Held here rather than inside the panel because it is a fact about
  /// the MAP and the panel at once: the halo and the card are two views
  /// of one selection, and two copies of it would be free to disagree.
  ({String routeId, int index})? _selectedLeg;

  /// Which of the two things the detail column is currently about.
  ///
  /// Last-picked wins, rather than one silently outranking the other: a
  /// reader clicking a dot wants the place, and a reader clicking a
  /// journey wants the itinerary, and both are one click away in the
  /// index column at all times.
  bool _detailIsJourney = false;

  List<ResolvedJourney> get _activeRoutes => <ResolvedJourney>[
        for (final j in _journeys)
          if (_onRoutes.contains(j.id)) j,
      ];

  ResolvedJourney? get _readingRoute {
    final id = _readingRouteId;
    if (id == null) return null;
    for (final j in _journeys) {
      if (j.id == id) return j;
    }
    return null;
  }

  /// The picture database (#320). Null until it lands, which is a state
  /// the panel must be able to tell from "this place has no plates" —
  /// hence a nullable list rather than an empty one.
  List<BibleMap>? _plates;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialPlaceId;
    final subject = widget.subjectPlaces;
    if (subject != null && subject.isNotEmpty) {
      _subjectIds = <String>{for (final p in subject) p.id};
    }
    PlacesService.all().then((places) {
      if (!mounted) return;
      setState(() => _all = places);
      // The map is 110 KB and only this page draws it, so it is fetched
      // after the index rather than with it: the list is readable a
      // frame earlier, and the map has nothing to draw until the
      // gazetteer has landed anyway.
      PlacesService.baseMap().then((m) {
        if (!mounted) return;
        setState(() => _base = m);
        if (_selectedId != null) _focusToken++;
        // 52 KB, and it resolves against the gazetteer that has just
        // landed, so it cannot be fetched any earlier than this.
        JourneysService.all().then((js) {
          if (!mounted) return;
          setState(() => _journeys = js);
        });
        // Last of the four: `maps_index.json` is 1 MB and nothing on
        // this page needs it until a place is selected.
        MapService.loadMaps().then((plates) {
          if (!mounted) return;
          setState(() => _plates = plates);
        });
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _s(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? fallback;

  /// The index, filtered by the subject chip, the query and the scope.
  List<BiblePlace> _results(List<BiblePlace> all) {
    final subject = _subjectIds;
    final base = subject == null
        ? all
        : <BiblePlace>[
            for (final p in all)
              if (subject.contains(p.id)) p,
          ];
    return atlasIndex(base,
        query: _query, scopeBooks: _scopeBooks, sort: _sort);
  }

  /// A new question re-frames the map; a new answer to the same question
  /// does not. Typing, scoping and dropping the subject chip all change
  /// the question.
  void _questionChanged(VoidCallback change, {List<(double, double)>? fitTo}) =>
      setState(() {
        change();
        // Always assigned, never merely set: a stale route framing left
        // behind by an earlier toggle would swallow the next search.
        _fitPoints = fitTo;
        _fitToken++;
      });

  /// Switch a route on or off. Turning one on also opens its itinerary
  /// and frames it — a checkbox that draws a line somewhere off screen
  /// has not answered the reader.
  void _toggleRoute(ResolvedJourney j) {
    final turningOn = !_onRoutes.contains(j.id);
    _questionChanged(
      () {
        if (turningOn) {
          _onRoutes.add(j.id);
          _readingRouteId = j.id;
          _detailIsJourney = true;
        } else {
          _onRoutes.remove(j.id);
          if (_readingRouteId == j.id) {
            _readingRouteId = null;
            _detailIsJourney = false;
          }
        }
        // A leg of a route that is no longer drawn has nothing to point
        // at, and a leg of a route just switched on was not chosen.
        if (_selectedLeg?.routeId == j.id || turningOn) _selectedLeg = null;
      },
      fitTo: turningOn ? _pointsOf(j) : null,
    );
  }

  /// Open a route's itinerary, switching it on if it was off.
  void _readRoute(ResolvedJourney j, BuildContext context, String locale,
      BookScript script, double width) {
    _questionChanged(
      () {
        _onRoutes.add(j.id);
        _readingRouteId = j.id;
        _detailIsJourney = true;
        _selectedLeg = null;
      },
      fitTo: _pointsOf(j),
    );
    if (width < _detailColumnMin) _showJourneySheet(context, locale, script);
  }

  /// A leg on the map opens its own route's itinerary and points at the
  /// stretch that was clicked.
  ///
  /// **This is the direction that was missing.** The itinerary could
  /// always be read forwards — pick a route, walk its stops, open a verse
  /// — but a reader looking at the drawing and asking "what says they
  /// went THAT way" had no way back into the text except to read both end
  /// labels and hunt for the second in a list of twenty. bwh33's map
  /// lines answer nothing at all: BibleWorks lets you click a line only
  /// in Edit mode, and what it gives you then is curve tension and stroke
  /// colour. The only route it offers from a map back to scripture is a
  /// right-click on a SITE that runs a text search for its name.
  ///
  /// Clearing the place selection is deliberate. The two are different
  /// objects and the detail column shows one thing at a time; leaving a
  /// marker lit while the panel talks about a leg would be the same
  /// disagreement between two views of one state that #319 was.
  void _selectLeg(({String routeId, int index}) leg, BuildContext context,
      String locale, BookScript script, double width) {
    setState(() {
      _selectedLeg = leg;
      _readingRouteId = leg.routeId;
      _detailIsJourney = true;
      _selectedId = null;
    });
    if (width < _detailColumnMin) _showJourneySheet(context, locale, script);
  }

  /// The clicked leg, or null when nothing is selected or the selection
  /// no longer names a leg that exists.
  ///
  /// Resolved on every build rather than stored: the segment list is
  /// rebuilt from the gazetteer, and holding a [RouteSegment] would be
  /// holding one from a list that has since been replaced.
  RouteSegment? get _selectedSegment {
    final leg = _selectedLeg;
    if (leg == null) return null;
    final route = _readingRoute;
    if (route == null || route.id != leg.routeId) return null;
    if (leg.index < 0 || leg.index >= route.segments.length) return null;
    return route.segments[leg.index];
  }

  static List<(double, double)> _pointsOf(ResolvedJourney j) =>
      <(double, double)>[
        for (final s in j.stops) (s.place.lat!, s.place.lon!),
      ];

  void _selectFromIndex(String id, BuildContext context, String locale,
      BookScript script, double width) {
    setState(() {
      _selectedId = id;
      _detailIsJourney = false;
      _selectedLeg = null;
      _focusToken++;
    });
    if (width < _detailColumnMin) _showDetailSheet(context, locale, script);
  }

  Future<void> _pickScope(BuildContext context, String locale) async {
    final version = context.read<MainProvider>().currentVersion;
    final books = _scopeBooks;
    final chosen = await showSearchScopeSheet(
      context: context,
      locale: locale,
      version: version,
      activeSpec:
          (books == null || books.isEmpty) ? null : limitSpecForBooks(books),
      activeFallbackLabel: null,
    );
    // Null is a cancel; an EMPTY set is a real answer meaning "no
    // limit". See `showSearchScopeSheet`.
    if (chosen == null || !mounted) return;
    _questionChanged(() => _scopeBooks = chosen.isEmpty ? null : chosen);
  }

  Future<void> _jump(BuildContext context, PlaceRef ref) async {
    final parsed =
        parseReference('${ref.englishBook} ${ref.chapter}:${ref.verse}');
    if (parsed == null) return;
    final mp = context.read<MainProvider>();
    final result =
        await jumper.resolveAndPrepareJump(reference: parsed, mp: mp);
    if (!context.mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    navigateToReader(context);
  }

  BiblePlace? _selected(List<BiblePlace> all) {
    final id = _selectedId;
    if (id == null) return null;
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The active scope, named the way the filter button names it — or
  /// null when there is none. A message about a filter that will not say
  /// WHICH filter is barely a message (#280).
  String? _scopeLabelFor(String locale, String version) {
    final books = _scopeBooks;
    if (books == null || books.isEmpty) return null;
    return scopeDisplayName(
      spec: limitSpecForBooks(books),
      locale: locale,
      version: version,
    );
  }

  Future<void> _showDetailSheet(
      BuildContext context, String locale, BookScript script) async {
    final all = _all;
    final place = all == null ? null : _selected(all);
    if (place == null) return;
    final version = context.read<MainProvider>().currentVersion;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      // Square: a sheet is a window edge here, not a card.
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        // The sheet is built once by the Navigator, so the page's own
        // setState cannot reach inside it: without this, clearing the
        // filter from in here would change the map behind the sheet and
        // leave the sheet still saying the place is out of scope.
        builder: (sheetCtx, controller) => StatefulBuilder(
          builder: (_, setSheetState) => _DetailPanel(
            place: place,
            locale: locale,
            script: script,
            plates: _plates,
            scopeBooks: _scopeBooks,
            scopeLabel: _scopeLabelFor(locale, version),
            onClearScope: _scopeBooks == null
                ? null
                : () {
                    _questionChanged(() => _scopeBooks = null);
                    setSheetState(() {});
                  },
            scrollController: controller,
            onJump: (ref) => _jump(sheetCtx, ref),
          ),
        ),
      ),
    );
  }

  /// The itinerary, where there is no third column to put it in.
  Future<void> _showJourneySheet(
      BuildContext context, String locale, BookScript script) async {
    final j = _readingRoute;
    if (j == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => _JourneyPanel(
          journey: j,
          locale: locale,
          script: script,
          selectedPlaceId: _selectedId,
          // The narrow layout has no detail column, so the sheet is
          // where the clicked leg has to be answered. Read once as the
          // sheet opens: the sheet does not rebuild with the page, and a
          // leg selected behind it is not a thing that can happen.
          selectedLegIndex:
              _selectedSegment == null ? null : _selectedLeg!.index,
          scrollController: controller,
          onSelectStop: (id) => setState(() {
            _selectedId = id;
            _selectedLeg = null;
            _focusToken++;
          }),
          onJump: (ref) => _jump(sheetCtx, ref),
          band: _band,
          onSelectBand: (b) => setState(() => _band = b),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final version =
        context.select<MainProvider, String>((m) => m.currentVersion);
    final script = bookScriptFor(locale, version);
    final c = WbColors.of(context);
    final all = _all;

    return Scaffold(
      backgroundColor: c.paneBg,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(_s('atlasTitle', 'Bible Atlas', locale)),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, box) {
                final results = _results(all);
                final selected = _selected(all);
                final resultIds = <String>{for (final p in results) p.id};
                final map = PlaceMapView(
                  title: _mapTitle(results, selected, locale, script),
                  emphasised: results,
                  travelBand: _band,
                  // Exactly what the index left out — `atlasIndex` caps
                  // nothing, so this is the filter's complement and not
                  // "the geography around it". Hidden unless the reader
                  // asks, because a map that draws 1,259 places the list
                  // beside it has just excluded is answering a question
                  // nobody asked (#319).
                  muted: <BiblePlace>[
                    for (final p in all)
                      if (!resultIds.contains(p.id)) p,
                  ],
                  showContext: _showContext,
                  onToggleContext: () =>
                      setState(() => _showContext = !_showContext),
                  baseMap: _base,
                  script: script,
                  locale: locale,
                  selectedId: _selectedId,
                  routes: _activeRoutes,
                  selectedRouteId: _readingRouteId,
                  fitPoints: _fitPoints,
                  selectedLeg: _selectedLeg,
                  onSelectLeg: (leg) =>
                      _selectLeg(leg, context, locale, script, box.maxWidth),
                  onSelect: (id) {
                    setState(() {
                      _selectedId = id;
                      if (id != null) _detailIsJourney = false;
                      // Including the null case: a tap on empty water
                      // means "nothing", and leaving a haloed leg behind
                      // would make it mean "nothing, except that".
                      _selectedLeg = null;
                    });
                    // Below the detail column there is nowhere for the
                    // answer to go, and a dot that lights up and says
                    // nothing is the same dead end as the blank panel.
                    if (id != null && box.maxWidth < _detailColumnMin) {
                      _showDetailSheet(context, locale, script);
                    }
                  },
                  fitToken: _fitToken,
                  focusToken: _focusToken,
                  attribution: _attribution,
                );

                final index = _indexColumn(
                    context, c, locale, version, script, results, all.length,
                    width: box.maxWidth);

                if (box.maxWidth < _mapBesideIndexMin) {
                  return Column(
                    children: [
                      SizedBox(
                        // Enough to be a map and not so much that the
                        // index below it becomes a peep-hole.
                        height: (box.maxHeight * 0.42).clamp(180.0, 340.0),
                        child: map,
                      ),
                      Divider(height: WbMetrics.hairline, color: c.border),
                      Expanded(child: index),
                    ],
                  );
                }

                final journey = _detailIsJourney ? _readingRoute : null;
                final detail = journey != null
                    ? _JourneyPanel(
                        journey: journey,
                        locale: locale,
                        script: script,
                        selectedPlaceId: _selectedId,
                        selectedLegIndex: _selectedSegment == null
                            ? null
                            : _selectedLeg!.index,
                        onSelectStop: (id) => setState(() {
                          _selectedId = id;
                          _selectedLeg = null;
                          _focusToken++;
                        }),
                        onJump: (ref) => _jump(context, ref),
                        band: _band,
                        onSelectBand: (b) => setState(() => _band = b),
                        onClose: () => setState(() {
                          _detailIsJourney = false;
                          _selectedLeg = null;
                        }),
                      )
                    : selected == null
                        ? null
                        : _DetailPanel(
                            place: selected,
                            locale: locale,
                            script: script,
                            plates: _plates,
                            scopeBooks: _scopeBooks,
                            scopeLabel: _scopeLabelFor(locale, version),
                            onClearScope: _scopeBooks == null
                                ? null
                                : () =>
                                    _questionChanged(() => _scopeBooks = null),
                            onJump: (ref) => _jump(context, ref),
                          );

                final showDetailColumn =
                    box.maxWidth >= _detailColumnMin && detail != null;

                return Row(
                  children: [
                    SizedBox(width: _indexPanelWidth, child: index),
                    VerticalDivider(width: WbMetrics.hairline, color: c.border),
                    Expanded(child: map),
                    if (showDetailColumn) ...[
                      VerticalDivider(
                          width: WbMetrics.hairline, color: c.border),
                      SizedBox(width: _detailPanelWidth, child: detail),
                    ],
                  ],
                );
              },
            ),
    );
  }

  String get _attribution => <String>[
        PlacesService.attribution,
        PlacesService.geoAttribution,
      ].where((e) => e.isNotEmpty).join(' · ');

  /// What the map is of. The selected place wins, because a reader who
  /// picked one is looking at it; otherwise the question that produced
  /// the current set.
  String _mapTitle(List<BiblePlace> results, BiblePlace? selected,
      String locale, BookScript script) {
    if (selected != null) {
      final n = selected.displayName(script);
      return selected.ordinal == null ? n : '$n ${selected.ordinal}';
    }
    if (_subjectIds != null && widget.subjectLabel != null) {
      return widget.subjectLabel!;
    }
    if (_query.isNotEmpty) return _query;
    return _s('atlasTitle', 'Bible Atlas', locale);
  }

  // ── The index column ──────────────────────────────────────────────

  Widget _indexColumn(
    BuildContext context,
    WbColors c,
    String locale,
    String version,
    BookScript script,
    List<BiblePlace> results,
    int total, {
    required double width,
  }) {
    final t = WbType.of(context);
    // The journeys block is the one child here that grows with the DATA:
    // every route added to the asset costs it another row, and it is not
    // the flexible child, so on a short pane it ate the place list and
    // then overflowed. Six routes is where that first showed. Capping it
    // against the pane's own height means route seven costs nothing.
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: _searchField(c, t, locale),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: _controls(context, c, t, locale, version),
          ),
          if (_subjectIds != null && widget.subjectLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: _subjectChip(c, t, locale),
            ),
          if (_journeys.isNotEmpty)
            _journeysBlock(context, c, t, locale, script,
                width: width,
                maxHeight: box.hasBoundedHeight
                    ? box.maxHeight * 0.42
                    : double.infinity),
          _countHeader(c, t, locale, results.length, total),
          Divider(height: WbMetrics.hairline, color: c.border),
          Expanded(
            child: results.isEmpty
                ? _empty(c, t, locale)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    itemCount: results.length,
                    itemBuilder: (context, i) => _row(
                      context,
                      c,
                      t,
                      locale,
                      script,
                      results[i],
                      width: width,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(WbColors c, WbType t, String locale) => TextField(
        controller: _search,
        style: TextStyle(
          fontSize: t.text,
          color: c.text,
          fontFamilyFallback: kCjkFontFallback,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: c.paneAltBg,
          hintText: _s('atlasSearchHint', 'Search a place name', locale),
          hintStyle: TextStyle(
            fontSize: t.text,
            color: c.mutedText,
            fontFamilyFallback: kCjkFontFallback,
          ),
          prefixIcon: Icon(Icons.search, size: t.text + 3, color: c.mutedText),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 30, minHeight: 30),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: t.text + 1, color: c.mutedText),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _search.clear();
                    _questionChanged(() => _query = '');
                  },
                ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: c.border, width: WbMetrics.hairline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: c.border, width: WbMetrics.hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: c.text, width: WbMetrics.hairline),
          ),
        ),
        onChanged: (v) => _questionChanged(() => _query = v),
      );

  Widget _controls(BuildContext context, WbColors c, WbType t, String locale,
      String version) {
    final books = _scopeBooks;
    final scopeLabel = (books == null || books.isEmpty)
        ? _s('scopeWholeBible', 'Whole Bible', locale)
        : scopeDisplayName(
            spec: limitSpecForBooks(books),
            locale: locale,
            version: version,
          );
    return Row(
      children: [
        Expanded(
          child: _flatButton(
            c,
            t,
            icon: Icons.filter_alt_outlined,
            label: scopeLabel,
            active: books != null && books.isNotEmpty,
            onTap: () => _pickScope(context, locale),
          ),
        ),
        const SizedBox(width: 4),
        _flatButton(
          c,
          t,
          label: _s('atlasSortRefs', 'Refs', locale),
          active: _sort == AtlasSort.references,
          onTap: () => setState(() => _sort = AtlasSort.references),
        ),
        const SizedBox(width: 3),
        _flatButton(
          c,
          t,
          label: _s('atlasSortName', 'A–Z', locale),
          active: _sort == AtlasSort.name,
          onTap: () => setState(() => _sort = AtlasSort.name),
        ),
      ],
    );
  }

  Widget _flatButton(
    WbColors c,
    WbType t, {
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
  }) =>
      Material(
        color: active ? c.selectionBg : c.paneBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: active ? c.text : c.border,
            width: WbMetrics.hairline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          hoverColor: c.hoverBg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: t.chrome + 1, color: active ? c.text : c.mutedText),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: t.chrome,
                      height: 1.0,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? c.text : c.mutedText,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _subjectChip(WbColors c, WbType t, String locale) => Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 3, 3),
        decoration: BoxDecoration(
          color: c.selectionBg,
          border: Border.all(color: c.text, width: WbMetrics.hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _s('atlasSubjectFilter', 'Showing {name}', locale)
                    .replaceAll('{name}', widget.subjectLabel ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: t.chrome + 2, color: c.mutedText),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              tooltip: _s('atlasSubjectClear', 'Show every place', locale),
              onPressed: () => _questionChanged(() => _subjectIds = null),
            ),
          ],
        ),
      );

  /// The overlay switches (#317).
  ///
  /// bwh33's Overlays window is the model: a list of transparent sheets,
  /// each with its own check-box, stacked in whatever combination the
  /// reader wants. It sits above the place count rather than below the
  /// list because it does not narrow the list — it is a different layer,
  /// and putting it inside the index would say otherwise.
  Widget _journeysBlock(
    BuildContext context,
    WbColors c,
    WbType t,
    String locale,
    BookScript script, {
    required double width,
    required double maxHeight,
  }) {
    final anyOn = _onRoutes.isNotEmpty;
    return Container(
      key: const Key('atlas-journeys-block'),
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.border, width: WbMetrics.hairline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _s('journeysHeader', 'Journeys', locale),
              style: TextStyle(
                fontSize: t.chrome,
                fontWeight: FontWeight.w700,
                color: c.mutedText,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
            const SizedBox(height: 2),
            for (final j in _journeys)
              _journeyRow(context, c, t, locale, script, j, width: width),
            if (anyOn) ...[
              const SizedBox(height: 4),
              // The caution is printed whenever a line is on screen, not
              // tucked inside the itinerary panel: the drawing is what
              // overclaims, so the correction belongs beside the switch
              // that produced it.
              _fineprint(c, t, _s('journeysCaution', '', locale)),
              const SizedBox(height: 3),
              _fineprint(c, t, _s('journeysKey', '', locale)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fineprint(WbColors c, WbType t, String text) => Text(
        text,
        style: TextStyle(
          fontSize: t.chrome,
          color: c.mutedText,
          height: 1.35,
          fontFamilyFallback: kCjkFontFallback,
        ),
      );

  Widget _journeyRow(
    BuildContext context,
    WbColors c,
    WbType t,
    String locale,
    BookScript script,
    ResolvedJourney j, {
    required double width,
  }) {
    final on = _onRoutes.contains(j.id);
    final reading = _readingRouteId == j.id && _detailIsJourney;
    final style = journeyStyleFor(c, j.journey.style, j.journey.mark);
    final subtitle = <String>[
      j.journey.localizedRange(locale),
      _s('journeyStops', '{n} stops', locale)
          .replaceAll('{n}', '${j.journey.waypointCount}'),
      _s('journeyMarkers', '{n} markers', locale)
          .replaceAll('{n}', '${j.markers.length}'),
      if (j.journey.provisionalCount > 0)
        _s('journeyProvisionalCount', '{n} provisional', locale)
            .replaceAll('{n}', '${j.journey.provisionalCount}'),
      if (j.journey.asideCount > 0)
        _s('journeyAsideCount', '{n} named, not reached', locale)
            .replaceAll('{n}', '${j.journey.asideCount}'),
    ].where((e) => e.isNotEmpty).join(' · ');

    return InkWell(
      onTap: () => _readRoute(j, context, locale, script, width),
      hoverColor: c.hoverBg,
      child: Container(
        color: reading ? c.selectionBg : null,
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Its own tap target: switching a sheet on and reading its
            // itinerary are different asks, and a reader comparing two
            // routes on the map should not have to open one to see it.
            InkWell(
              onTap: () => _toggleRoute(j),
              child: Padding(
                padding: const EdgeInsets.only(top: 1, right: 5),
                child: Tooltip(
                  message: _s('journeyShowTip', 'Draw this route', locale),
                  child: Icon(
                    on ? Icons.check_box : Icons.check_box_outline_blank,
                    size: t.text + 2,
                    color: on ? style.colour : c.mutedText,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 5),
              child: JourneySwatch(style: style, lit: on),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    j.journey.localizedName(locale),
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: t.text,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? c.text : c.mutedText,
                      height: 1.25,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: t.chrome,
                        color: c.mutedText,
                        height: 1.3,
                        fontFamilyFallback: kCjkFontFallback,
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

  /// bwh23's parenthesised denominator: a narrowed count with no total
  /// is the ambiguity the filter itself creates.
  Widget _countHeader(
          WbColors c, WbType t, String locale, int shown, int total) =>
      Container(
        width: double.infinity,
        color: c.chromeBg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          _s('atlasCount', '{n} places', locale)
              .replaceAll('{n}', scopedCountLabel(shown, total)),
          style: TextStyle(
            fontSize: t.chrome,
            fontWeight: FontWeight.w700,
            color: c.mutedText,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      );

  Widget _empty(WbColors c, WbType t, String locale) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _s('atlasNoMatch', 'No place in the gazetteer matches.', locale),
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

  Widget _row(
    BuildContext context,
    WbColors c,
    WbType t,
    String locale,
    BookScript script,
    BiblePlace p, {
    required double width,
  }) {
    final selected = p.id == _selectedId;
    final display = p.displayName(script);
    // The English name stays beside a Chinese one rather than being
    // replaced by it: every atlas, lexicon and commentary the reader
    // might reach for next is indexed in English.
    final showEnglish = display != p.name;

    return InkWell(
      onTap: () => _selectFromIndex(p.id, context, locale, script, width),
      hoverColor: c.hoverBg,
      child: Container(
        color: selected ? c.selectionBg : null,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                p.located ? Icons.place : Icons.help_outline,
                size: t.text,
                color: selected ? c.link : c.mutedText,
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
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: c.text,
                            fontFamilyFallback: kCjkFontFallback,
                          ),
                        ),
                      ),
                      // Antioch 1 is Syrian and Antioch 2 is Pisidian,
                      // 500 km apart. A list that printed both as
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
                      const Spacer(),
                      // Under a scope this is `2 / 755`, not `755`: the
                      // row sits beneath a header that has just said
                      // `12 / 1271`, and a bare whole-Bible total there
                      // reads as the count for the book in the filter.
                      // Scoped to Esther it claimed 755 for a city the
                      // book names once (#308's rule, third outing).
                      Text(
                        scopedCountLabel(
                          refCountInBooks(p, _scopeBooks),
                          p.refs.length,
                        ),
                        style: TextStyle(
                          fontSize: t.chrome,
                          color: c.mutedText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (showEnglish || !p.located)
                    Text(
                      [
                        if (showEnglish) p.name,
                        if (!p.located)
                          _s('placesUnlocated', 'location unknown', locale),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: t.chrome,
                        color: c.mutedText,
                        fontFamilyFallback: kCjkFontFallback,
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

/// One place: what it is called, where it is, and every verse that names
/// it — grouped by book so 755 references read as a shape rather than as
/// a wall.
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.place,
    required this.locale,
    required this.script,
    required this.plates,
    required this.scopeBooks,
    required this.scopeLabel,
    required this.onClearScope,
    required this.onJump,
    this.scrollController,
  });

  final BiblePlace place;
  final String locale;
  final BookScript script;

  /// The picture database, or null while it is still loading. Both draw
  /// no strip, and neither states anything — the strip's absence is
  /// silence, not the claim that no plate names this place.
  final List<BibleMap>? plates;

  final Set<String>? scopeBooks;

  /// [scopeBooks] as the reader saw it named on the filter button.
  final String? scopeLabel;

  /// Drops the scope. Null when there is none to drop.
  final VoidCallback? onClearScope;

  final void Function(PlaceRef) onJump;
  final ScrollController? scrollController;

  String _s(String key, String fallback) => uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    final parts = partitionRefsByScope(place.refs, scopeBooks: scopeBooks);
    final groups = parts.inScope;
    final inScope = parts.inScopeCount;
    final display = place.displayName(script);
    final scope = scopeLabel;

    return ColoredBox(
      color: c.paneBg,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
        children: [
          Text(
            place.ordinal == null ? display : '$display ${place.ordinal}',
            style: TextStyle(
              fontSize: t.text + 3,
              fontWeight: FontWeight.w700,
              color: c.text,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
          if (display != place.name)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                place.name,
                style: TextStyle(fontSize: t.chrome, color: c.mutedText),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            place.located
                ? _coordinates(place)
                // Not a data gap to be papered over: Eden, Nod and the
                // Pishon are unlocated because nobody knows where they
                // are, and inventing coordinates would be a lie.
                : _s('atlasUnlocatedNote',
                    'Scripture names this place but its site is unidentified.'),
            style: TextStyle(
              fontSize: t.chrome,
              color: c.mutedText,
              height: 1.4,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
          // Above the references, not below: Jerusalem carries 755 of
          // them, and a strip under that is a strip nobody reaches.
          _illustrations(context, c, t),
          const SizedBox(height: 10),
          Container(
            color: c.chromeBg,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              _s('atlasRefsHeader', '{n} references').replaceAll(
                  '{n}', scopedCountLabel(inScope, place.refs.length)),
              style: TextStyle(
                fontSize: t.chrome,
                fontWeight: FontWeight.w700,
                color: c.mutedText,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
          ),
          if (groups.isEmpty && scope != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _s('atlasNotNamedInScope', 'Not named in {scope}.')
                    .replaceAll('{scope}', scope),
                style: TextStyle(
                  fontSize: t.chrome,
                  color: c.mutedText,
                  height: 1.4,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
          for (final g in groups) _book(context, c, t, g),
          // The references the scope holds back. Printed rather than
          // dropped: the reader picked THIS place, and a panel that says
          // "0 / 1" and then shows nothing has told them the verse
          // exists and refused to say where — which is how a 320 px
          // column came to be a blank rectangle.
          if (parts.elsewhere.isNotEmpty && scope != null) ...[
            const SizedBox(height: 14),
            Container(
              color: c.chromeBg,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _s('atlasRefsElsewhere', '{n} more outside {scope}')
                          .replaceAll('{n}', '${parts.elsewhereCount}')
                          .replaceAll('{scope}', scope),
                      style: TextStyle(
                        fontSize: t.chrome,
                        fontWeight: FontWeight.w700,
                        color: c.mutedText,
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  ),
                  if (onClearScope != null)
                    InkWell(
                      onTap: onClearScope,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        child: Text(
                          _s('atlasClearScope', 'Clear the filter'),
                          style: TextStyle(
                            fontSize: t.chrome,
                            color: c.link,
                            fontFamilyFallback: kCjkFontFallback,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (final g in parts.elsewhere)
              _book(context, c, t, g, subdued: true),
          ],
        ],
      ),
    );
  }

  /// The plates that name this place (#320), or nothing at all.
  ///
  /// "Naming it" is the whole claim, and the header says so rather than
  /// calling them pictures OF the place: the join is a caption match
  /// gated by chapter, and the gazetteer's ordinal cannot survive it
  /// because 66 of its 80 ordinal groups share one reference list. See
  /// `utils/place_illustrations.dart` for the measurement.
  ///
  /// Absent when the join found nothing, because 1,192 of 1,271 places
  /// have no plate and an apology on each of them is not a feature. But
  /// a scope that empties the strip prints the header alone reading
  /// `0 / n`: 56 of the 79 joined places have a book under which every
  /// plate falls away, and vanishing there would tell the reader "there
  /// are no pictures of this place" when there are n of them.
  Widget _illustrations(BuildContext context, WbColors c, WbType t) {
    final all = plates;
    if (all == null) return const SizedBox.shrink();
    final found = placeIllustrations(place, all, scopeBooks: scopeBooks);
    if (found.total == 0) return const SizedBox.shrink();
    final title = _s('atlasIllusHeader', '{n} illustrations naming it')
        .replaceAll('{n}', scopedCountLabel(found.inScope.length, found.total));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          color: c.chromeBg,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            title,
            style: TextStyle(
              fontSize: t.chrome,
              fontWeight: FontWeight.w700,
              color: c.mutedText,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
        ),
        if (found.inScope.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: found.inScope.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => _plate(c, found.inScope, i, title),
            ),
          ),
        ],
      ],
    );
  }

  /// One thumbnail. The caption and the #300 credit are in the viewer it
  /// opens, which is where a plate can be read rather than glanced at.
  Widget _plate(WbColors c, List<BibleMap> strip, int i, String stripTitle) {
    final m = strip[i];
    return Tooltip(
      message: m.localizedTitle(locale),
      child: Material(
        color: c.paneAltBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: c.border, width: WbMetrics.hairline),
        ),
        child: InkWell(
          onTap: () => pushPage(MapViewerPage(
            map: m,
            locale: locale,
            // The arrow keys walk this place's plates, not the whole
            // corpus, and the viewer's title says which list that is.
            relatedMaps: strip,
            stripTitle: stripTitle,
          )),
          hoverColor: c.hoverBg,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: SizedBox(
            width: 98,
            child: IllustrationImage(
              map: m,
              thumb: true,
              fit: BoxFit.cover,
              // Same reasoning as the Illustrations grid: the bundled
              // survey plates are up to 2.4 MB each and several share
              // this strip.
              cacheWidth: 220,
              errorBuilder: (_) => Icon(Icons.image_not_supported_outlined,
                  size: 18, color: c.mutedText),
            ),
          ),
        ),
      ),
    );
  }

  /// `31.78° N, 35.23° E`. Hemisphere letters rather than a minus sign:
  /// every biblical site is north and east, so a lone `-` would read as
  /// a typo rather than as a hemisphere.
  String _coordinates(BiblePlace p) {
    final lat = p.lat!;
    final lon = p.lon!;
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lon >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(2)}° $ns, '
        '${lon.abs().toStringAsFixed(2)}° $ew';
  }

  /// [subdued] is the out-of-scope half: still legible, still tappable —
  /// a reference the reader can see and not reach would be worse than
  /// hiding it — but visibly not the answer to what they asked.
  Widget _book(BuildContext context, WbColors c, WbType t, PlaceRefGroup g,
          {bool subdued = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localeAwareBookName(g.englishBook, locale,
                  context.read<MainProvider>().currentVersion),
              style: TextStyle(
                fontSize: t.chrome,
                fontWeight: subdued ? FontWeight.w600 : FontWeight.w700,
                color: subdued ? c.mutedText : c.text,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: [
                for (final r in g.refs)
                  Material(
                    color: c.paneBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                      side: BorderSide(
                          color: c.border, width: WbMetrics.hairline),
                    ),
                    child: InkWell(
                      onTap: () => onJump(r),
                      hoverColor: c.hoverBg,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        child: Text(
                          '${r.chapter}:${r.verse}',
                          style: TextStyle(
                            fontSize: t.chrome,
                            height: 1.0,
                            color: c.link,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}

/// One itinerary, stop by stop, with the verse that puts each stop on it.
///
/// **This panel is the point of the feature, not the line on the map.**
/// A printed atlas draws Paul's journeys as three coloured arcs and
/// leaves the reader to take them on trust; bwh33 does the same, and its
/// route overlays carry no references at all. Here every row names its
/// verse and every row is a jump into the reader — so a route is a claim
/// that can be checked, one stop at a time, which is the difference
/// between an illustration and a study tool.
class _JourneyPanel extends StatelessWidget {
  const _JourneyPanel({
    required this.journey,
    required this.locale,
    required this.script,
    required this.selectedPlaceId,
    required this.selectedLegIndex,
    required this.onSelectStop,
    required this.onJump,
    required this.band,
    required this.onSelectBand,
    this.onClose,
    this.scrollController,
  });

  final ResolvedJourney journey;
  final String locale;
  final BookScript script;

  /// The pace the reader has chosen for this session (#317).
  final TravelBand band;

  /// Set it. The panel is stateless; the Atlas owns the choice because
  /// the ruler on the map has to move with it.
  final ValueChanged<TravelBand> onSelectBand;

  /// Lit in the list so the map and the panel agree on where the reader
  /// is in the itinerary.
  final String? selectedPlaceId;

  /// The leg clicked on the map, as an index into [journey]'s segments.
  final int? selectedLegIndex;

  final ValueChanged<String> onSelectStop;
  final void Function(PlaceRef) onJump;

  /// Returns the column to the selected place. Absent in the sheet, which
  /// is dismissed instead.
  final VoidCallback? onClose;

  final ScrollController? scrollController;

  String _s(String key, String fallback) => uiStrings[key]?[locale] ?? fallback;

  String _legWord(JourneyLeg leg) => switch (leg) {
        JourneyLeg.sea => _s('journeyLegSea', 'by sea'),
        JourneyLeg.land => _s('journeyLegLand', 'by land'),
        JourneyLeg.unknown => _s('journeyLegUnknown', 'the way is not given'),
        JourneyLeg.start => '',
      };

  /// The gazetteer's disambiguating ordinal included, always. Without it
  /// a leg reads `Antioch → Antioch` for two cities 500 km apart.
  String _placeName(ResolvedStop s) => s.place.ordinal == null
      ? s.place.displayName(script)
      : '${s.place.displayName(script)} ${s.place.ordinal}';

  /// The leg the reader clicked, or null if nothing is selected or the
  /// index no longer names one.
  RouteSegment? get _leg {
    final i = selectedLegIndex;
    if (i == null || i < 0 || i >= journey.segments.length) return null;
    return journey.segments[i];
  }

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    final style =
        journeyStyleFor(c, journey.journey.style, journey.journey.mark);
    final version = context.read<MainProvider>().currentVersion;
    final basis = journey.journey.localizedBasis(locale);
    // Lit by stop INDEX, not by place id. Lystra is stops 8 and 10 of the
    // first journey, so lighting by place would light both ends of a leg
    // that only touches one of them.
    final leg = _leg;
    final litIndices =
        leg == null ? const <int>{} : <int>{leg.from.index, leg.to.index};
    // Which rows the note about shared points is actually ABOUT. A count
    // with no locator tells a reader that 27 stops are merged and leaves
    // them unable to find out whether the one they are reading is one of
    // them.
    final sharedIndices = <int>{
      for (final run in journey.collapsedRuns)
        for (final s in run.stops) s.index,
    };

    return ColoredBox(
      color: c.paneBg,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 6),
                child: JourneySwatch(style: style, lit: true),
              ),
              Expanded(
                child: Text(
                  journey.journey.localizedName(locale),
                  style: TextStyle(
                    fontSize: t.text + 2,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    height: 1.25,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: Icon(Icons.close, size: t.text + 2, color: c.mutedText),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: _s('journeyClose', 'Close the itinerary'),
                  onPressed: onClose,
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            journey.journey.localizedRange(locale),
            style: TextStyle(
              fontSize: t.chrome,
              color: c.mutedText,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
          const SizedBox(height: 8),
          // The answer to the click comes before the route's own
          // furniture. A reader who pointed at one line and got a page
          // about the whole journey has been answered with a different
          // question, which is the shape of defect #319 was.
          if (leg != null) ...[
            _legCard(c, t, version, leg),
            const SizedBox(height: 10),
          ],
          // The two cautions the drawing cannot make for itself, and the
          // per-route provenance underneath them.
          _note(c, t, _s('journeysCaution', '')),
          const SizedBox(height: 4),
          _note(
            c,
            t,
            _s('journeyStraightLine', '{n} km in straight lines')
                .replaceAll('{n}', '${journey.straightLineKm.round()}'),
          ),
          ..._travelNotes(c, t, travelOf(journey)),
          _bandPicker(c, t),
          if (journey.unresolved.isNotEmpty) ...[
            const SizedBox(height: 4),
            _note(
              c,
              t,
              _s('journeyUnresolved', '{n} stops have no location')
                  .replaceAll('{n}', '${journey.unresolved.length}'),
            ),
          ],
          // The failure that looks like success. A stop the gazetteer
          // cannot place at all breaks the line, and the note above says
          // so; a stop it places on top of its neighbour draws perfectly
          // and says nothing, and 27 of the wilderness itinerary's 42
          // stations do exactly that. Without this line the map shows one
          // dot where the text names eleven camps.
          if (journey.collapsedRuns.isNotEmpty) ...[
            const SizedBox(height: 4),
            _note(
              c,
              t,
              _s('journeyCollapsed', '{n} stops share a point, in {p} groups')
                  .replaceAll('{n}', '${journey.collapsedStopCount}')
                  .replaceAll('{p}', '${journey.collapsedRuns.length}'),
            ),
          ],
          if (basis.isNotEmpty) ...[
            const SizedBox(height: 10),
            _header(c, t, _s('journeyBasisHeader', 'Basis')),
            const SizedBox(height: 4),
            _note(c, t, basis),
          ],
          const SizedBox(height: 10),
          _header(
            c,
            t,
            // Counted over the track only, with the asides said out loud
            // beside it. One number covering both would answer "how many
            // stops" with a figure that includes a harbour they missed —
            // the ambiguous-count defect of #308 in a new place.
            <String>[
              _s('journeyStops', '{n} stops')
                  .replaceAll('{n}', '${journey.journey.waypointCount}'),
              if (journey.journey.asideCount > 0)
                _s('journeyAsideCount', '{n} named, not reached')
                    .replaceAll('{n}', '${journey.journey.asideCount}'),
            ].join(' · '),
          ),
          for (final row in journey.itineraryRows)
            row.placed != null
                ? _stop(c, t, style, version, row.placed!, litIndices,
                    sharedIndices)
                : _unplacedStop(c, t, style, version, row.unplaced!),
        ],
      ),
    );
  }

  Widget _header(WbColors c, WbType t, String text) => Container(
        width: double.infinity,
        color: c.chromeBg,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          text,
          style: TextStyle(
            fontSize: t.chrome,
            fontWeight: FontWeight.w700,
            color: c.mutedText,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      );

  Widget _note(WbColors c, WbType t, String text) => Text(
        text,
        style: TextStyle(
          fontSize: t.chrome,
          color: c.mutedText,
          height: 1.4,
          fontFamilyFallback: kCjkFontFallback,
        ),
      );

  /// The reader's choice of pace (#317, bwh33's Travel Speed Window).
  ///
  /// Three tap targets rather than a dropdown: there are exactly three
  /// and they form a scale, so showing all three at once is also the
  /// only place the reader can see what the alternatives ARE. The chosen
  /// one is bold and unlinked; the others are `c.link`, which on this
  /// page means "tapping this changes what you are looking at".
  Widget _bandPicker(WbColors c, WbType t) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _note(c, t, _s('travelBandPicker', 'Estimate at:')),
            for (final b in kTravelBands)
              InkWell(
                onTap: b == band ? null : () => onSelectBand(b),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Text(
                    travelBandLabel(b, locale),
                    style: TextStyle(
                      fontSize: t.chrome,
                      height: 1.4,
                      fontWeight:
                          b == band ? FontWeight.w700 : FontWeight.w400,
                      color: b == band ? c.text : c.link,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  /// The straight-line total broken down by how the text says they went,
  /// and a day band over the part that can carry one.
  ///
  /// **The order is deliberate: what was estimated, then what was not.**
  /// Every non-zero bucket is named, with no threshold — the voyage to
  /// Rome is 2,803 of its 2,996 km at sea, so a panel that printed a
  /// walking band for its three land legs and stopped would have told a
  /// reader that Paul walked to Rome in a week and a half.
  List<Widget> _travelNotes(WbColors c, WbType t, JourneyTravel travel) {
    final out = <Widget>[];
    void add(String text) {
      out.add(const SizedBox(height: 4));
      out.add(_note(c, t, text));
    }

    String km(double v) => '${v.round()}';

    if (travel.landKm > 0) {
      add(_s('journeyLandKm', '{n} km of that by land')
          .replaceAll('{n}', km(travel.landKm)));
    }
    if (travel.seaKm > 0) {
      add(_s('journeySeaKm', '{n} km by sea')
          .replaceAll('{n}', km(travel.seaKm)));
    }
    if (travel.unknownKm > 0) {
      add(_s('journeyUnknownKm',
              '{n} km where the text does not say how they went')
          .replaceAll('{n}', km(travel.unknownKm)));
    }
    final walk = travel.walk(band: band);
    if (walk != null) {
      add(formatTravelDays(walk, locale));
      add(travelBandBasis(band, locale));
      if (band != kDefaultTravelBand) add(_s('travelBandNotOurs', ''));
    }
    if (travel.seaKm > 0) add(_s('travelNoEstimateSea', ''));
    if (travel.unknownKm > 0) add(_s('travelNoEstimateUnknown', ''));
    return out;
  }

  /// The same estimate for ONE leg, which needs no breakdown — the card
  /// has already printed the leg's kilometres and its mode, so repeating
  /// them under a different label would just be the same fact twice.
  List<Widget> _legTravelNotes(WbColors c, WbType t, RouteSegment leg) {
    final out = <Widget>[];
    void add(String text) {
      out.add(const SizedBox(height: 5));
      out.add(_note(c, t, text));
    }

    switch (leg.leg) {
      case JourneyLeg.land:
        final walk = walkingDaysFor(leg.km, band: band);
        if (walk != null) {
          add(formatTravelDays(walk, locale));
          add(travelBandBasis(band, locale));
          if (band != kDefaultTravelBand) add(_s('travelBandNotOurs', ''));
        }
      case JourneyLeg.sea:
        add(_s('travelNoEstimateSea', ''));
      case JourneyLeg.start:
      case JourneyLeg.unknown:
        add(_s('travelNoEstimateUnknown', ''));
    }
    return out;
  }

  /// A reference, and a way into it. A stop or a leg whose verse the
  /// reader cannot open is an assertion.
  Widget _refChip(WbColors c, WbType t, String version, PlaceRef r) {
    final label = '${localeAwareBookName(r.englishBook, locale, version)}'
        ' ${r.chapter}:${r.verse}';
    return Material(
      color: c.paneBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: c.border, width: WbMetrics.hairline),
      ),
      child: InkWell(
        onTap: () => onJump(r),
        hoverColor: c.hoverBg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Text(
            label,
            style: TextStyle(
              fontSize: t.chrome,
              height: 1.0,
              color: c.link,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
        ),
      ),
    );
  }

  /// A bordered word — "Provisional", "Named, not reached".
  Widget _tag(WbColors c, WbType t, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: c.mutedText, width: WbMetrics.hairline),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: t.chrome,
            height: 1.0,
            color: c.mutedText,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      );

  /// What one leg of the drawing rests on.
  ///
  /// **Everything here is a claim the stop list cannot make.** A row in
  /// that list is about a PLACE; a leg is about the stretch between two
  /// of them, and three of its facts belong to the stretch alone:
  ///
  ///   * whether the LEG is provisional. [RouteSegment.attested] is true
  ///     only when the text places the travellers at both ends, so the
  ///     line out of a provisional stop is provisional even though its
  ///     destination is named — and no row says so, because no row is
  ///     about that line.
  ///   * the chord. The panel gives the route's total; a reader asking
  ///     why one leg looks so much longer than the rest is asking about
  ///     this one, and BibleWorks' own Ruler mode (bwh33) exists because
  ///     that is a question readers of a route map actually have. Named
  ///     as a straight line, because that is all it is — and unlike
  ///     BibleWorks this does not go on to compute a travel TIME, which
  ///     would need a speed nobody can source.
  ///   * what the narrative names on the stretch without putting them
  ///     there. See [ResolvedJourney.asidesOn].
  Widget _legCard(WbColors c, WbType t, String version, RouteSegment leg) {
    final manner = _legWord(leg.leg);
    final asides = journey.asidesOn(leg);
    final note = leg.to.stop.localizedNote(locale);

    // Which end the text will not vouch for. Said as a name rather than
    // as a bare "provisional", because "they may not have been there" is
    // only useful once you know WHERE.
    final unvouched = <String>[
      if (!leg.from.stop.attested) _placeName(leg.from),
      if (!leg.to.stop.attested) _placeName(leg.to),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.border, width: WbMetrics.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(c, t, _s('journeyLegHeader', 'The leg you clicked')),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wrapped, never ellipsised: these are place names, and a
                // clipped Chinese name is unreadable rather than merely
                // shortened (#297).
                Text(
                  '${_placeName(leg.from)} → ${_placeName(leg.to)}',
                  style: TextStyle(
                    fontSize: t.text,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    height: 1.3,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (manner.isNotEmpty)
                      Text(
                        manner,
                        style: TextStyle(
                          fontSize: t.chrome,
                          color: c.mutedText,
                          height: 1.0,
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                    if (!leg.attested)
                      _tag(c, t, _s('journeyProvisionalTag', 'Provisional')),
                  ],
                ),
                const SizedBox(height: 5),
                _note(
                  c,
                  t,
                  _s('journeyLegKm', '{n} km in a straight line')
                      .replaceAll('{n}', '${leg.km.round()}'),
                ),
                // The leg is where the mode is known most precisely, so
                // it is where the estimate — or the refusal — belongs.
                // The refusal is not silence: a sea leg says why it has
                // no number, because a leg that simply omitted one would
                // be indistinguishable from a leg we forgot.
                ..._legTravelNotes(c, t, leg),
                if (unvouched.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _note(
                    c,
                    t,
                    _s(
                            'journeyLegUnattested',
                            'The text does not place them at {p}, so this '
                                'leg is drawn provisionally.')
                        .replaceAll('{p}', unvouched.join(' · ')),
                  ),
                ],
                for (final a in asides) ...[
                  const SizedBox(height: 5),
                  _note(
                    c,
                    t,
                    _s(
                            'journeyLegAside',
                            '{p} is named on this stretch and was not '
                                'reached.')
                        .replaceAll('{p}', _placeName(a)),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _refChip(
                        c,
                        t,
                        version,
                        PlaceRef(
                            a.stop.englishBook, a.stop.chapter, a.stop.verse),
                      ),
                      _tag(c, t, _s('journeyAsideTag', 'Named, not reached')),
                    ],
                  ),
                ],
                const SizedBox(height: 7),
                _note(
                  c,
                  t,
                  _s('journeyLegWarrant', 'What puts {p} on the itinerary')
                      .replaceAll('{p}', _placeName(leg.to)),
                ),
                const SizedBox(height: 3),
                _refChip(
                  c,
                  t,
                  version,
                  PlaceRef(leg.to.stop.englishBook, leg.to.stop.chapter,
                      leg.to.stop.verse),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _note(c, t, note),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stop(
    WbColors c,
    WbType t,
    JourneyStyle style,
    String version,
    ResolvedStop s,
    Set<int> litIndices,
    Set<int> sharedIndices,
  ) {
    final lit = s.place.id == selectedPlaceId || litIndices.contains(s.index);
    final display = _placeName(s);
    final note = s.stop.localizedNote(locale);
    // An aside was never travelled TO, so it has no manner of travel and
    // printing one would answer a question the row does not raise.
    final leg = s.isAside ? '' : _legWord(s.stop.leg);
    final ref = PlaceRef(s.stop.englishBook, s.stop.chapter, s.stop.verse);

    return InkWell(
      onTap: () => onSelectStop(s.place.id),
      hoverColor: c.hoverBg,
      child: Container(
        color: lit ? c.selectionBg : null,
        padding: const EdgeInsets.fromLTRB(0, 5, 0, 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The same badge the map draws, so a reader can carry a
            // number from one to the other. Its own ordinal only — the
            // map's joined `8,10` belongs on a marker that has to stand
            // for two stops at one coordinate, and this list does not.
            Container(
              margin: const EdgeInsets.only(top: 1, right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              // Hollow for an aside, matching the hollow ring on the map,
              // and holding an en dash where the number would be so the
              // column does not ripple around a blank.
              decoration: s.isAside
                  ? BoxDecoration(
                      border: Border.all(
                          color: style.colour, width: WbMetrics.hairline))
                  : BoxDecoration(
                      color: s.stop.attested
                          ? style.colour
                          : style.colour.withValues(alpha: 0.45)),
              child: Text(
                s.ordinal == null ? '–' : '${s.ordinal}',
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: s.isAside ? style.colour : style.onColour,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
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
                            fontWeight: FontWeight.w600,
                            color: c.text,
                            fontFamilyFallback: kCjkFontFallback,
                          ),
                        ),
                      ),
                      if (leg.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Text(
                          leg,
                          style: TextStyle(
                            fontSize: t.chrome,
                            color: c.mutedText,
                            fontFamilyFallback: kCjkFontFallback,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // A Wrap, not a Row. Three chips of translated text in
                  // a panel the reader can drag narrow is the overflow
                  // this app has shipped before; wrapping costs a line of
                  // height in the worst case and nothing in the common
                  // one.
                  Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _refChip(c, t, version, ref),
                      if (s.isAside || !s.stop.attested)
                        _tag(
                          c,
                          t,
                          s.isAside
                              ? _s('journeyAsideTag', 'Named, not reached')
                              : _s('journeyProvisionalTag', 'Provisional'),
                        ),
                      // On every row of the run, not just its first: a
                      // reader stopped at Rissah is asking about Rissah,
                      // and a marker that appeared once at the top of a
                      // group would be invisible to them.
                      if (sharedIndices.contains(s.index))
                        _tag(
                            c,
                            t,
                            _s(
                                'journeySharedPointTag',
                                'One point with its '
                                    'neighbour')),
                    ],
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    _note(c, t, note),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The gazetteer's name where we have a record, the itinerary's own id
  /// where we do not. Never blank: the row exists to say this camp was
  /// named, and a row with no name says nothing.
  String _unplacedName(UnplacedStop u) {
    final p = u.place;
    if (p == null) return u.stop.placeId;
    return p.ordinal == null
        ? p.displayName(script)
        : '${p.displayName(script)} ${p.ordinal}';
  }

  /// A stop the text names but the gazetteer cannot put on the map — see
  /// [UnplacedStop]. Not an [InkWell]: [onSelectStop] lights a marker on
  /// the map, and there is no marker here to jump to.
  Widget _unplacedStop(
    WbColors c,
    WbType t,
    JourneyStyle style,
    String version,
    UnplacedStop u,
  ) {
    final display = _unplacedName(u);
    final note = u.stop.localizedNote(locale);
    final leg = u.stop.isAside ? '' : _legWord(u.stop.leg);
    final ref = PlaceRef(u.stop.englishBook, u.stop.chapter, u.stop.verse);

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 5, 0, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1, right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              border:
                  Border.all(color: style.colour, width: WbMetrics.hairline),
            ),
            child: Text(
              '–',
              style: TextStyle(
                fontSize: t.chrome,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: style.colour,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
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
                          fontWeight: FontWeight.w600,
                          color: c.text,
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                    ),
                    if (leg.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Text(
                        leg,
                        style: TextStyle(
                          fontSize: t.chrome,
                          color: c.mutedText,
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _refChip(c, t, version, ref),
                    _tag(c, t,
                        _s('journeyNoLocationTag', 'No location on our map')),
                    if (!u.stop.attested)
                      _tag(c, t, _s('journeyProvisionalTag', 'Provisional')),
                  ],
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _note(c, t, note),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
