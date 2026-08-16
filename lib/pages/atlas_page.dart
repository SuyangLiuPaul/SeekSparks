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
///      800 km apart and spelled identically, so the search returns both
///      cities' verses under either pin. The gazetteer carries a curated
///      per-site reference list with the disambiguating ordinal, so
///      `Antioch 1` and `Antioch 2` answer separately and correctly.
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
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/places_service.dart';
import 'package:seeksparks/utils/atlas_index.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/navigate_to_reader.dart';
import 'package:seeksparks/utils/place_geo.dart' show BaseMap;
import 'package:seeksparks/utils/reference_parser.dart' show parseReference;
import 'package:seeksparks/utils/search_scope.dart'
    show limitSpecForBooks, scopeDisplayName, scopedCountLabel;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/widgets/home_icon_button.dart';
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

  /// The ids of [AtlasPage.subjectPlaces] while the filter is up, null
  /// once it is dismissed or superseded.
  Set<String>? _subjectIds;

  int _fitToken = 0;
  int _focusToken = 0;

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
  void _questionChanged(VoidCallback change) => setState(() {
        change();
        _fitToken++;
      });

  void _selectFromIndex(String id, BuildContext context, String locale,
      BookScript script, double width) {
    setState(() {
      _selectedId = id;
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
      activeSpec: (books == null || books.isEmpty)
          ? null
          : limitSpecForBooks(books),
      activeFallbackLabel: null,
    );
    // Null is a cancel; an EMPTY set is a real answer meaning "no
    // limit". See `showSearchScopeSheet`.
    if (chosen == null || !mounted) return;
    _questionChanged(() => _scopeBooks = chosen.isEmpty ? null : chosen);
  }

  Future<void> _jump(BuildContext context, PlaceRef ref) async {
    final parsed = parseReference('${ref.englishBook} ${ref.chapter}:${ref.verse}');
    if (parsed == null) return;
    final mp = context.read<MainProvider>();
    final result = await jumper.resolveAndPrepareJump(reference: parsed, mp: mp);
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
                  onSelect: (id) {
                    setState(() => _selectedId = id);
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
                        height:
                            (box.maxHeight * 0.42).clamp(180.0, 340.0),
                        child: map,
                      ),
                      Divider(height: WbMetrics.hairline, color: c.border),
                      Expanded(child: index),
                    ],
                  );
                }

                final showDetailColumn =
                    box.maxWidth >= _detailColumnMin && selected != null;

                return Row(
                  children: [
                    SizedBox(width: _indexPanelWidth, child: index),
                    VerticalDivider(
                        width: WbMetrics.hairline, color: c.border),
                    Expanded(child: map),
                    if (showDetailColumn) ...[
                      VerticalDivider(
                          width: WbMetrics.hairline, color: c.border),
                      SizedBox(
                        width: _detailPanelWidth,
                        child: _DetailPanel(
                          place: selected,
                          locale: locale,
                          script: script,
                          scopeBooks: _scopeBooks,
                          scopeLabel: _scopeLabelFor(locale, version),
                          onClearScope: _scopeBooks == null
                              ? null
                              : () => _questionChanged(
                                  () => _scopeBooks = null),
                          onJump: (ref) => _jump(context, ref),
                        ),
                      ),
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
    return Column(
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
                      size: t.chrome + 1,
                      color: active ? c.text : c.mutedText),
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
                      // 800 km apart. A list that printed both as
                      // "Antioch" would be actively misleading.
                      if (p.ordinal != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Text(
                            '${p.ordinal}',
                            style: TextStyle(
                              fontSize: t.chrome - 1,
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
                          fontSize: t.chrome - 1,
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
                        fontSize: t.chrome - 1,
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
    required this.scopeBooks,
    required this.scopeLabel,
    required this.onClearScope,
    required this.onJump,
    this.scrollController,
  });

  final BiblePlace place;
  final String locale;
  final BookScript script;
  final Set<String>? scopeBooks;

  /// [scopeBooks] as the reader saw it named on the filter button.
  final String? scopeLabel;

  /// Drops the scope. Null when there is none to drop.
  final VoidCallback? onClearScope;

  final void Function(PlaceRef) onJump;
  final ScrollController? scrollController;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

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
          const SizedBox(height: 10),
          Container(
            color: c.chromeBg,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              _s('atlasRefsHeader', '{n} references')
                  .replaceAll('{n}', scopedCountLabel(inScope, place.refs.length)),
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
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
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
