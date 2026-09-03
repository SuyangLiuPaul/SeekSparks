/// The horizontal chronology strip — the wheel's second form.
///
/// WHY THERE ARE TWO FORMS. The wheel is a good poster and a poor
/// instrument, and the reason is geometric rather than aesthetic: its
/// cross axis is bounded by the viewport, so the 22 stream rings get
/// `side x 0.17` between them — **3.01 px each on a 390 px phone**
/// against a 9 px finger — and `InteractiveViewer` scales both axes at
/// once, so magnifying a seven-day reign magnifies Methuselah's 969
/// years off the screen with it. Seven spans on that band are 0.00 px
/// wide at every canvas and every zoom. None of that is a parameter
/// anybody can move.
///
/// This page unbinds the two axes. Time scrolls horizontally and is
/// zoomed on its own (`pxPerYear`); lanes have a height chosen in
/// pixels and scroll vertically. The measurements behind the decision
/// are in `WHEEL-UX-REDESIGN.md`; the geometry is in
/// `strip_chronology_layout.dart`; the paint order is specified in
/// `docs/strip-painter-spec.md`.
///
/// THE DETAIL SHEETS ARE THE WHEEL'S OWN. `WheelSheets` was extracted
/// so this page opens the identical sheet a reader gets from the wheel
/// — same words, same verse links, same behaviour. A second view of one
/// corpus must not grow a second vocabulary for it.
///
/// THREE SCROLL SURFACES, ONE COORDINATE SPACE. `docs/strip-painter-
/// spec.md` §1 asks for a sticky ruler and a sticky lane-header column
/// beside the scrolling content, and the composition is this page's
/// job, not the painters'. Two nested `SingleChildScrollView`s (time
/// outer, lanes inner) carry the real drag; the ruler's own horizontal
/// scroll view and the header's own vertical one are driven
/// programmatically by listening to those two, so all four panes always
/// agree about where the reader is looking.
///
/// THE VIEW SWITCH AND THE URL CLAIM ARE A PAIR. The wheel's own
/// `SegmentedButton` `pushReplacement`s here, and `_UrlRestoreObserver`
/// (`main.dart`) only answers `didPush`/`didPop` — a `pushReplacement`
/// fires `didReplace`, which it does not watch. So the address bar
/// would keep reading `#/wheel` after the switch unless this page
/// claims `#/strip` itself the moment it mounts, exactly as the wheel
/// claims its own path — see `UrlClaim`'s own doc for why `owner: this`
/// is what lets the incoming page's claim survive the outgoing page's
/// `dispose`.
///
/// FIND, FILTER AND ABOUT ARE THE WHEEL'S OWN, NOT A SECOND
/// VOCABULARY. `searchWheel` (`utils/wheel_search.dart`) is a pure
/// function of a `WheelHistoryData` and knows nothing about either
/// form, so it is called unchanged — a name, a verse or a year finds
/// the same records here it finds on the wheel, ranked the same way,
/// and `wheelFindTeach` reports the same `data.events.length` (851:
/// 747 from `wheel_history.json` plus 104 merged from
/// `bible_timeline.json`). `WheelSheets` (`pages/wheel_sheets.dart`)
/// opens the identical detail sheet either page's tap resolves to. Only
/// the RESULT-LIST GLUE — which small label a `WheelHitKind` prints,
/// the status line's wording — could not be shared: `_kindLabel`,
/// `_hitYears`, `_hitVia` and `_searchStatus` live on
/// `_RadialChronologyPageState`, private to that file, and this page
/// may not edit it to lift them out. They are reproduced here reading
/// the SAME `wheelStrings`/`uiStrings` keys through `s()`/`fill()`
/// (`WheelSheets`'s own lookup), so the words never drift even though
/// the four small functions are typed twice. Filter is the same story:
/// `_hidden`, `kLifespanLayerId`/`kReignLayerId`/`kMinistryLayerId`
/// (`wheel_search.dart`, already shared) and the wheel's own filter
/// strings are reused; only the "which lanes does hiding actually
/// remove" plumbing is the strip's own, because a lane is not a ring.
///
/// REVEALING A FOUND RECORD IS `scrollToCentre` PLUS ITS OWN VERTICAL
/// HALF. The horizontal half is the layout file's own
/// `scrollToCentre` — the strip's `focusTranslation`, deliberately
/// never rescaling `_pxPerYear`. There is no wheel equivalent of the
/// vertical half — a ring has no "row" — so `_rowForHit` and the
/// centring math in `_scrollToHit` are new, not a port, and run
/// unconditionally rather than gated on zoom the way the wheel's
/// `_panTo` is: `scrollToCentre` already clamps to 0 when the content
/// fits the viewport, so nothing is lost by always calling it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/strip_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/biblical_person.dart' show BiblicalPerson;
import 'package:seeksparks/models/chronology.dart' show Patriarch;
import 'package:seeksparks/models/hebrew_king.dart' show HebrewKing, Kingdom;
import 'package:seeksparks/models/strip_lanes.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show
        LineageCohort,
        RadialChronologyPage,
        kDrawnTradition,
        kingdomArcColor,
        lineColor,
        lineageRailColor,
        ministryArcColor,
        yearLabel;
import 'package:seeksparks/pages/wheel_sheets.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/services/url_sync_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show canvasTextStyle;
import 'package:seeksparks/utils/strip_chronology_layout.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/utils/wheel_search.dart';
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/strip_chronology_painter.dart';

/// The address this page owns, in the same shape as `kWheelUrlPath`.
///
/// Named here rather than in `page_links.dart` so the routing table
/// depends on the page and not the other way round — the wheel's own
/// path is declared the same way.
const String kStripUrlPath = '/strip';

/// `stripStrings` has no page-title key of its own (it is the painter's
/// and the lane-header column's vocabulary — see that file's own doc).
/// A page needs a title regardless, so this is the strip's small local
/// supplement, the same way `wheelStrings` is `radial_chronology_page
/// .dart`'s own.
const Map<String, String> _kPageTitle = {
  'zh-Hans': '世界历史时间条',
  'zh-Hant': '世界歷史時間條',
  'en': 'World History Strip',
};

class StripChronologyPage extends StatefulWidget {
  const StripChronologyPage({super.key});

  @override
  State<StripChronologyPage> createState() => _StripChronologyPageState();
}

class _StripChronologyPageState extends State<StripChronologyPage>
    with WheelSheets<StripChronologyPage> {
  Future<WheelHistoryData>? _future;

  double _pxPerYear = kStripZoomSteps.first;
  String? _selectedId;

  /// Streams the reader has switched off — the wheel's own field
  /// (`radial_chronology_page.dart`'s `_hidden`), reproduced with the
  /// same contract: empty means all on, and it also carries the three
  /// non-stream layer ids (`kLifespanLayerId`, `kReignLayerId`,
  /// `kMinistryLayerId`, `kLineageLayerId`) the wheel's filter sheet
  /// toggles. All four, since the genealogy rail landed: an earlier
  /// version of this comment said the strip drew no rail and so had
  /// nothing for that id to switch off, which stopped being true the
  /// hour the rail was added.
  final Set<String> _hidden = {};

  /// Kept on the state for the same reason the wheel's is
  /// (`_RadialChronologyPageState._findCtl`'s own doc): a reader who
  /// closes the sheet to look at what it found still has their query
  /// when they reopen it.
  final _findCtl = TextEditingController();

  /// The two REAL, draggable controllers. The ruler's and the header's
  /// own controllers only ever receive `jumpTo` from these two — see
  /// the class doc.
  final _hCtl = ScrollController();
  final _vCtl = ScrollController();
  final _rulerHCtl = ScrollController();
  final _headerVCtl = ScrollController();

  double _viewportW = 0;

  @override
  void initState() {
    super.initState();
    _future = WheelHistoryService.instance.load();
    UrlSyncService.claimUrl(kStripUrlPath, owner: this);
    _hCtl.addListener(_onHScroll);
    _vCtl.addListener(_onVScroll);
  }

  void _onHScroll() {
    if (_rulerHCtl.hasClients && _rulerHCtl.offset != _hCtl.offset) {
      _rulerHCtl.jumpTo(_hCtl.offset);
    }
    // The horizontal scroll-edge fade and a bar label's own pinned
    // position (`barLabelX`) both read the visible window, so a scroll
    // has to repaint even though nothing about the DATA changed.
    setState(() {});
  }

  void _onVScroll() {
    if (_headerVCtl.hasClients && _headerVCtl.offset != _vCtl.offset) {
      _headerVCtl.jumpTo(_vCtl.offset);
    }
    setState(() {});
  }

  @override
  void dispose() {
    UrlSyncService.claimUrl(null, owner: this);
    _hCtl
      ..removeListener(_onHScroll)
      ..dispose();
    _vCtl
      ..removeListener(_onVScroll)
      ..dispose();
    _rulerHCtl.dispose();
    _headerVCtl.dispose();
    _findCtl.dispose();
    super.dispose();
  }

  void _select(String? id) => setState(() => _selectedId = id);

  void _zoomStep(int delta) {
    final i = kStripZoomSteps.indexOf(_pxPerYear);
    final next = (i < 0 ? 0 : i + delta).clamp(0, kStripZoomSteps.length - 1);
    setState(() => _pxPerYear = kStripZoomSteps[next]);
  }

  void _fitAll() {
    if (_viewportW <= 0) return;
    setState(() => _pxPerYear =
        snapZoom(pxPerYearToFit(kStripMinYear, kStripMaxYear, _viewportW)));
  }

  /// `stripStrings`' own lookup — `s()` (from [WheelSheets]) reads
  /// `uiStrings`/`wheelStrings`, neither of which carries this page's
  /// vocabulary.
  String ss(String key, String locale) =>
      stripStrings[key]?[locale] ?? stripStrings[key]?['en'] ?? key;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final wb = WbColors.of(context);

    return Scaffold(
      backgroundColor: wb.paneBg,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(_kPageTitle[locale] ?? _kPageTitle['en']!),
        actions: [
          // Same three, same order, same tooltips as the wheel's own
          // toolbar (`radial_chronology_page.dart`'s `build`) — a
          // reader switching forms should find Find/Filter/About in
          // the same place they left them.
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: s('wheelFind', 'Find', locale),
            onPressed: () => _showSearch(context, locale),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: s('wheelFilter', 'Filter', locale),
            onPressed: () => _showFilter(context, locale),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: s('wheelAbout', 'About this chart', locale),
            onPressed: () => _showAbout(context, locale),
          ),
          _viewSwitch(context, locale),
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
      ),
      body: FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snap.error}',
                    style: TextStyle(color: wb.mutedText)),
              ),
            );
          }
          final data = snap.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _body(context, data, locale);
        },
      ),
    );
  }

  /// The mirror of the wheel's own `SegmentedButton` — same strings,
  /// same shape, opposite default selection. Tapping the already-
  /// selected 'strip' segment is a no-op, exactly as tapping 'wheel'
  /// is one on the wheel's side.
  Widget _viewSwitch(BuildContext context, String locale) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Tooltip(
          message: ss('stripViewSwitch', locale),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              ButtonSegment(
                  value: 'wheel', label: Text(ss('stripViewWheel', locale))),
              ButtonSegment(
                  value: 'strip', label: Text(ss('stripViewStrip', locale))),
            ],
            selected: const {'strip'},
            onSelectionChanged: (selected) {
              if (selected.first != 'wheel') return;
              context.read<AppSettings>().setChronologyView('wheel');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                    builder: (_) => const RadialChronologyPage()),
              );
            },
          ),
        ),
      );

  Widget _body(BuildContext context, WheelHistoryData data, String locale) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final chron = ChronologyService.instance.cached;
    final kings =
        HebrewKingsService.instance.cached?.kings ?? const <HebrewKing>[];
    final creation = creationYear;
    // Honest fallback, the wheel's own rule (class doc, `radial_chronology
    // _page.dart`): if the creation anchor cannot be read, the layer
    // draws NOTHING rather than borrow a stand-in year.
    final patriarchs = creation == null
        ? const <Patriarch>[]
        : (chron?.patriarchs ?? const []);

    final laneFontPx = t.scaledSmall(12);
    final headingFontPx = laneFontPx * 1.15;
    final tickFontPx = t.scaledChrome(11);
    final rows = _currentRows(data, kings, patriarchs, t.textScale);
    final contentW = stripContentWidth(_pxPerYear);
    final contentH = rows.isEmpty ? 0.0 : rows.last.top + rows.last.height;

    final streamColors = colorsFor(data);
    final eventById = {for (final e in data.events) e.id: e};
    final spanLabel = <String, String>{
      for (final k in kings) '$kStripKingPrefix${k.id}': k.nameFor(locale),
      for (final m in data.ministries)
        '$kStripMinistryPrefix${m.id}': m.nameFor(locale),
      for (final p in data.powers) p.id: p.nameFor(locale),
      for (final pa in patriarchs) pa.id: pa.nameFor(locale),
      for (final s in data.streams) s.id: s.nameFor(locale),
    };
    final palette = StripPalette(
        streamColors: streamColors, eventById: eventById, spanLabel: spanLabel);

    return LayoutBuilder(builder: (context, box) {
      final headerW = stripHeaderColumnWidth(
        locale: locale,
        headingFontPx: headingFontPx,
        viewportWidth: box.maxWidth,
        measure: _measureText,
      );
      _viewportW = box.maxWidth - headerW;
      final rulerH = tickFontPx * WbMetrics.lineHeight * 2 + 6;

      final visibleX0 = _hCtl.hasClients ? _hCtl.offset : 0.0;
      final visibleX1 = visibleX0 +
          (_hCtl.hasClients ? _hCtl.position.viewportDimension : _viewportW);

      return Stack(children: [
        Column(children: [
          Row(children: [
            SizedBox(width: headerW, height: rulerH),
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  controller: _rulerHCtl,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  key: const ValueKey('stripRulerHScroll'),
                  child: CustomPaint(
                    size: Size(contentW, rulerH),
                    painter: StripRulerPainter(
                      pxPerYear: _pxPerYear,
                      locale: locale,
                      wb: wb,
                      tickFontPx: tickFontPx,
                    ),
                  ),
                ),
              ),
            ),
          ]),
          Expanded(
            child: Row(children: [
              SizedBox(
                width: headerW,
                child: ClipRect(
                  child: SingleChildScrollView(
                    controller: _headerVCtl,
                    physics: const NeverScrollableScrollPhysics(),
                    key: const ValueKey('stripHeaderVScroll'),
                    child: CustomPaint(
                      size: Size(headerW, contentH),
                      painter: StripLaneHeaderPainter(
                        rows: rows,
                        locale: locale,
                        wb: wb,
                        laneFontPx: laneFontPx,
                        headingFontPx: headingFontPx,
                        palette: palette,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _hCtl,
                  scrollDirection: Axis.horizontal,
                  key: const ValueKey('stripHScroll'),
                  child: SingleChildScrollView(
                    controller: _vCtl,
                    key: const ValueKey('stripVScroll'),
                    child: GestureDetector(
                      key: const ValueKey('chronologyStrip'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (e) => _handleTap(context, e.localPosition, data,
                          kings, patriarchs, locale, rows, laneFontPx),
                      child: SizedBox(
                        width: contentW,
                        height: contentH,
                        child: CustomPaint(
                          painter: StripLanesPainter(
                            rows: rows,
                            pxPerYear: _pxPerYear,
                            locale: locale,
                            selectedId: _selectedId,
                            wb: wb,
                            laneFontPx: laneFontPx,
                            palette: palette,
                            visibleX0: visibleX0,
                            visibleX1: visibleX1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
        ..._scrollIndicators(
          headerW: headerW,
          wb: wb,
          t: t,
          locale: locale,
          maxScrollX: math.max(0.0, contentW - _viewportW),
          maxScrollY: math.max(0.0, contentH - (box.maxHeight - rulerH)),
        ),
        Positioned(right: 10, bottom: 10, child: _zoomControls(locale, t, wb)),
      ]);
    });
  }

  /// Sort the lanes into rows, one heading per kind block. `buildStrip
  /// Lanes` already emits its lanes grouped by kind in a fixed order —
  /// events, lives, kings, ministries, then every stream in turn — so a
  /// heading only has to go in front of the first lane of a new kind;
  /// the 22 streams share one heading because their [StripLane.kind]
  /// never changes across them (`docs/strip-painter-spec.md` §5: the
  /// streams are homogeneous, unlike kings/lifespans/ministries).
  List<StripRow> _buildRows(List<StripLane> lanes, double textScale) {
    final laneH = stripLaneHeightPx(textScale);
    final headH = stripHeadingHeightPx(textScale);
    final rows = <StripRow>[];
    var y = 0.0;
    StripLaneKind? lastKind;
    for (final lane in lanes) {
      if (lane.kind != lastKind) {
        final key = switch (lane.kind) {
          StripLaneKind.events => 'stripLaneEvents',
          StripLaneKind.lives => 'stripLaneLifespans',
          StripLaneKind.kings => 'stripLaneKings',
          StripLaneKind.ministries => 'stripLaneMinistries',
          StripLaneKind.rail => 'stripLaneRail',
          StripLaneKind.stream => 'stripLaneStreams',
          StripLaneKind.ruler => null,
        };
        if (key != null) {
          rows.add(StripRow.heading(key, top: y, height: headH));
          y += headH;
        }
        lastKind = lane.kind;
      }
      rows.add(StripRow.lane(lane, top: y, height: laneH));
      y += laneH;
    }
    return rows;
  }

  /// The events one event tick stands for, in year order, the tapped
  /// one included — so a `+n` badge can be cashed.
  ///
  /// Recomputed rather than carried out of the painter, because a
  /// painter is not a plan: it is handed the same lane and the same
  /// `pxPerYear` this handler has, and `clusterByX` is a pure function
  /// of those. What must NOT drift is the gap, which is why it is the
  /// painter's own `kStripEventClusterEm` and not a second 1.35 written
  /// here — the set listed has to be the set the badge counted.
  ///
  /// Year order, because `showCluster` reads `events.first.year` and
  /// `events.last.year` for its own header range and asserts neither.
  List<WheelHistoryEvent> _eventsUnder(
    int index,
    StripLane lane,
    double laneFontPx,
    WheelHistoryData data,
  ) {
    final xs = [for (final s in lane.spans) xForYear(s.startYear, _pxPerYear)];
    final clusters = clusterByX(xs, laneFontPx * kStripEventClusterEm);
    for (final c in clusters) {
      if (!c.members.contains(index)) continue;
      final out = [
        for (final m in c.members)
          if (find(data.events, (e) => e.id == lane.spans[m].id)
              case final WheelHistoryEvent e)
            e
      ]..sort((a, b) => a.year.compareTo(b.year));
      return out;
    }
    return const [];
  }

  /// Which row [pos.dy] falls in, then which span [pos.dx] falls on
  /// within it — the strip's own `_handleTap`, in the same two-stage
  /// shape as the wheel's (ring, then angle) but simpler: rows do not
  /// overlap, so there is exactly one row per y and [nearestSpanAt]
  /// (not a bespoke scorer) decides the rest.
  void _handleTap(
    BuildContext context,
    Offset pos,
    WheelHistoryData data,
    List<HebrewKing> kings,
    List<Patriarch> patriarchs,
    String locale,
    List<StripRow> rows,
    double laneFontPx,
  ) {
    StripRow? hit;
    for (final row in rows) {
      if (pos.dy >= row.top && pos.dy < row.top + row.height) {
        hit = row;
        break;
      }
    }
    if (hit == null || hit.isHeading) {
      if (_selectedId != null) _select(null);
      return;
    }
    final lane = hit.lane!;

    void openStreamBackground() {
      final stream = find(data.streams, (s) => s.id == lane.ownerId);
      if (stream == null) return;
      _select(stream.id);
      showStream(context, stream, data, locale, _select);
    }

    if (lane.spans.isEmpty) {
      // Only a stream's own `ensureAtLeastOne` lane is ever empty
      // (`strip_lanes.dart`'s own doc) — the empty-lane note IS its
      // sheet, so a tap anywhere on the row still opens the stream.
      if (lane.kind == StripLaneKind.stream) {
        openStreamBackground();
      } else if (_selectedId != null) {
        _select(null);
      }
      return;
    }

    final targets = [
      for (final s in lane.spans)
        (
          x0: xForYear(s.startYear, _pxPerYear),
          x1: xForYear(s.endYear, _pxPerYear)
        )
    ];
    final pick = nearestSpanAt(pos.dx, targets);
    if (pick == null) {
      // The tap missed every span's target — a stream's OWN band still
      // answers, the same fallback the wheel gives an empty stretch of
      // ring; the other kinds have no such background record.
      if (lane.kind == StripLaneKind.stream) {
        openStreamBackground();
      } else if (_selectedId != null) {
        _select(null);
      }
      return;
    }

    final span = lane.spans[pick.index];
    switch (span.kind) {
      case StripLaneKind.events:
        // A TICK MAY STAND FOR SEVERAL EVENTS, AND THE BADGE SAYS SO.
        // Opening only the representative would leave `+3` as a promise
        // the chart never keeps — the reader is told three more records
        // are here and given no way to reach them, which is exactly the
        // silent narrowing #280, #308 and #319 each were. So the same
        // grouping the painter drew is recomputed here (one shared
        // `kStripEventClusterEm`, so the set listed IS the set counted)
        // and a tick standing for more than itself opens the list.
        final members = _eventsUnder(pick.index, lane, laneFontPx, data);
        if (members.length > 1) {
          _select(span.id);
          showCluster(context, members, data, locale, _select);
          return;
        }
        final event = find(data.events, (e) => e.id == span.id);
        if (event == null) return;
        _select(event.id);
        showEvent(context, event, data, locale);
      case StripLaneKind.lives:
        final man = ChronologyService.instance.cached?.byId(span.id);
        if (man == null) return;
        _select(man.id);
        showPatriarch(context, man, locale);
      case StripLaneKind.kings:
        final id = span.id.substring(kStripKingPrefix.length);
        final king = find(kings, (k) => k.id == id);
        if (king == null) return;
        _select(span.id);
        showKing(context, king, locale);
      case StripLaneKind.ministries:
        final id = span.id.substring(kStripMinistryPrefix.length);
        final ministry = find(data.ministries, (m) => m.id == id);
        if (ministry == null) return;
        _select(span.id);
        showMinistry(context, ministry, locale);
      case StripLaneKind.stream:
        final power = find(data.powers, (p) => p.id == span.id);
        if (power == null) return;
        _select(power.id);
        showPower(context, power, data, locale, _select);
      case StripLaneKind.rail:
        // The rail's sheet is the wheel's own `showCohort`, and it must
        // be: the first thing it says is that the year is the
        // genealogy's placement with no verse behind it. That sentence
        // is the whole reason this layer is drawn in a muted style and
        // switched separately, and a strip that opened some other sheet
        // would drop the one qualification the layer exists to carry.
        //
        // `StripLineageCohort` is rebuilt into the wheel's
        // `LineageCohort` rather than the sheet being widened to take
        // both: two types with the same two fields is the smaller
        // duplication, and `showCohort` belongs to neither form.
        final year = int.tryParse(
            span.id.substring(kStripLineagePrefix.length));
        if (year == null) return;
        final drawn = <String>{
          for (final p in patriarchs) p.id,
          for (final k in kings) k.id,
          for (final e in data.events)
            for (final link in e.people) link.id,
        };
        final cohort = find(
          stripLineageCohorts(
            people:
                FamilyTreeService.instance.cached ?? const <BiblicalPerson>[],
            drawnIds: drawn,
          ),
          (c) => c.year == year,
        );
        if (cohort == null) return;
        _select(span.id);
        showCohort(context,
            LineageCohort(year: cohort.year, people: cohort.people), locale);
      case StripLaneKind.ruler:
        break;
    }
  }

  // ── filter ─────────────────────────────────────────────────────────

  /// Which lanes [_hidden] actually removes, applied BEFORE
  /// `buildStripLanes` runs rather than after — so a hidden stream's
  /// row is never produced in the first place (and never falls back to
  /// `ensureAtLeastOne`'s empty placeholder, which would be exactly the
  /// "silently blank row" the wheel's own filter avoids by dropping the
  /// ring entirely — see `_visible`'s doc there).
  ///
  /// A hidden stream also drops its OWN events out of the shared events
  /// group, not just its band: on the wheel an event is a spoke ON its
  /// stream's ring, so switching the ring off already takes the event
  /// with it, and a strip that kept showing "Babylon" events in the
  /// Events lane after the Babylon band vanished would be answering the
  /// filter question two different ways in two lanes. `events`/`powers`
  /// are filtered by their own `.stream`; `ministries` and `streams`
  /// itself are filtered whole, because `kMinistryLayerId` is one
  /// switch for all of them (the wheel's own annulus row) and a stream
  /// with no [WheelStream] entry left cannot get an
  /// `ensureAtLeastOne` lane to begin with.
  ///
  /// Sheets opened from a tap or from search are never given this
  /// filtered copy — they take the page's own, unfiltered `data`, so a
  /// record's own detail sheet always shows everything it owns
  /// regardless of what the chart currently draws, the same split the
  /// wheel keeps between `_visible(data)` (paints) and `data` (sheets).
  ({WheelHistoryData data, List<HebrewKing> kings, List<Patriarch> patriarchs})
      _visibleInputs(
    WheelHistoryData data,
    List<HebrewKing> kings,
    List<Patriarch> patriarchs,
  ) {
    if (_hidden.isEmpty) {
      return (data: data, kings: kings, patriarchs: patriarchs);
    }
    return (
      data: WheelHistoryData(
        streams: data.streams.where((s) => !_hidden.contains(s.id)).toList(),
        nations: data.nations,
        powers: data.powers.where((p) => !_hidden.contains(p.stream)).toList(),
        ministries:
            _hidden.contains(kMinistryLayerId) ? const [] : data.ministries,
        omissions: data.omissions,
        events: data.events.where((e) => !_hidden.contains(e.stream)).toList(),
        meta: data.meta,
      ),
      kings: _hidden.contains(kReignLayerId) ? const <HebrewKing>[] : kings,
      patriarchs:
          _hidden.contains(kLifespanLayerId) ? const <Patriarch>[] : patriarchs,
    );
  }

  /// [_body]'s own row list, and also what a search reveal recomputes
  /// against (`_scrollToHit`) — one function, so a row a filter just
  /// hid cannot be the row a search scrolls to a moment later. Reads
  /// [_hidden] and [_pxPerYear] fresh each call rather than trusting a
  /// cached list, the same reason the wheel's own `_panTo` rebuilds
  /// `_packBand` instead of reusing the last frame's geometry: "a pan
  /// computed over arcs the reader has switched off would land in the
  /// wrong sub-ring."
  List<StripRow> _currentRows(
    WheelHistoryData data,
    List<HebrewKing> kings,
    List<Patriarch> patriarchs,
    double textScale,
  ) {
    final visible = _visibleInputs(data, kings, patriarchs);
    final lanes = buildStripLanes(
      wheel: visible.data,
      kings: visible.kings,
      patriarchs: visible.patriarchs,
      // Switched off as a LAYER, like the lifespans and the reigns, so
      // an empty list is the reader's choice rather than a missing
      // service — `stripLineageCohorts` treats both the same way and
      // builds no lane, which is what the filter is asking for.
      familyTreePeople: _hidden.contains(kLineageLayerId)
          ? const <BiblicalPerson>[]
          : (FamilyTreeService.instance.cached ?? const <BiblicalPerson>[]),
      tradition: kDrawnTradition,
      creationYear: creationYear ?? 0,
      pxPerYear: _pxPerYear,
    );
    return _buildRows(lanes, textScale);
  }

  void _showFilter(BuildContext context, String locale) {
    final wb = WbColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) => FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (c, snap) {
          final t = WbType.of(c);
          final data = snap.data;
          if (data == null) return const SizedBox(height: 120);
          final colors = colorsFor(data);
          return StatefulBuilder(builder: (c, setSheet) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheet).size.height * 0.7),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(s('wheelFilter', 'Filter', locale),
                          style: TextStyle(
                              color: wb.text,
                              fontSize: t.scaled(15),
                              fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () =>
                          setSheet(() => setState(() => _hidden.clear())),
                      child: Text(s('wheelAll', 'All', locale)),
                    ),
                    TextButton(
                      // NOT `kLineageLayerId` — see the class doc and
                      onPressed: () => setSheet(() => setState(() {
                            _hidden.addAll(data.streams.map((s) => s.id));
                            _hidden.add(kLifespanLayerId);
                            _hidden.add(kReignLayerId);
                            _hidden.add(kMinistryLayerId);
                            _hidden.add(kLineageLayerId);
                          })),
                      child: Text(s('wheelNone', 'None', locale)),
                    ),
                  ]),
                  CheckboxListTile(
                    key: const ValueKey('stripFilterLifespans'),
                    dense: true,
                    value: !_hidden.contains(kLifespanLayerId),
                    onChanged: (_) => setSheet(() => setState(() {
                          if (!_hidden.remove(kLifespanLayerId)) {
                            _hidden.add(kLifespanLayerId);
                          }
                        })),
                    title: Text(
                        s('wheelLifespans', 'Genesis lifespans', locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(12.5))),
                    subtitle: Text(
                      s('wheelLifespansNote', '', locale),
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11)),
                    ),
                    secondary: Container(
                        width: t.scaled(12),
                        height: t.scaled(12),
                        color: lineColor('shem')),
                  ),
                  CheckboxListTile(
                    key: const ValueKey('stripFilterReigns'),
                    dense: true,
                    value: !_hidden.contains(kReignLayerId),
                    onChanged: (_) => setSheet(() => setState(() {
                          if (!_hidden.remove(kReignLayerId)) {
                            _hidden.add(kReignLayerId);
                          }
                        })),
                    title: Text(
                        s('wheelReigns', 'Reigns of Judah & Israel', locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(12.5))),
                    subtitle: Text(
                      s('wheelKingsThiele', 'reigns (Thiele)', locale),
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11)),
                    ),
                    secondary: Container(
                        width: t.scaled(12),
                        height: t.scaled(12),
                        color: kingdomArcColor(Kingdom.judah)),
                  ),
                  CheckboxListTile(
                    key: const ValueKey('stripFilterMinistries'),
                    dense: true,
                    value: !_hidden.contains(kMinistryLayerId),
                    onChanged: (_) => setSheet(() => setState(() {
                          if (!_hidden.remove(kMinistryLayerId)) {
                            _hidden.add(kMinistryLayerId);
                          }
                        })),
                    title: Text(
                        s('wheelMinistries', 'Prophets & apostles', locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(12.5))),
                    subtitle: Text(
                      s('wheelMinistriesNote', '', locale),
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11)),
                    ),
                    secondary: Container(
                        width: t.scaled(12),
                        height: t.scaled(12),
                        color: ministryArcColor()),
                  ),
                  CheckboxListTile(
                    key: const ValueKey('stripFilterLineage'),
                    dense: true,
                    value: !_hidden.contains(kLineageLayerId),
                    onChanged: (_) => setSheet(() => setState(() {
                          if (!_hidden.remove(kLineageLayerId)) {
                            _hidden.add(kLineageLayerId);
                          }
                        })),
                    title: Text(s('wheelLineage', 'Genealogy', locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(12.5))),
                    subtitle: Text(
                      s('wheelLineageNote', '', locale),
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11)),
                    ),
                    secondary: Container(
                        width: t.scaled(12),
                        height: t.scaled(12),
                        color: lineageRailColor()),
                  ),
                  for (final stream in data.streams)
                    CheckboxListTile(
                      dense: true,
                      value: !_hidden.contains(stream.id),
                      onChanged: (_) => setSheet(() => setState(() {
                            if (!_hidden.remove(stream.id)) {
                              _hidden.add(stream.id);
                            }
                          })),
                      title: Text(stream.nameFor(locale),
                          style: TextStyle(
                              color: wb.text, fontSize: t.scaled(12.5))),
                      subtitle: Text(
                        '${s('wheelPowers', 'Powers', locale)} '
                        '${data.powersOf(stream.id).length} · '
                        '${s('wheelEvents', 'Events', locale)} '
                        '${data.eventsOf(stream.id).length}',
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(11)),
                      ),
                      secondary: Container(
                          width: t.scaled(12),
                          height: t.scaled(12),
                          color: colors[stream.id] ?? lineColor(stream.line)),
                    ),
                ],
              ),
            );
          });
        },
      ),
    );
  }

  // ── about ──────────────────────────────────────────────────────────

  void _showAbout(BuildContext context, String locale) {
    final wb = WbColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) => FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (c, snap) {
          final t = WbType.of(c);
          final data = snap.data;
          if (data == null) return const SizedBox(height: 120);
          final meta = data.meta;
          Widget section(String heading, String body) => body.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.only(bottom: t.scaled(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(heading,
                          style: TextStyle(
                              color: wb.mutedText,
                              fontSize: t.scaled(12),
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: t.scaled(4)),
                      Text(body,
                          style: TextStyle(
                              color: wb.mutedText, fontSize: t.scaled(12))),
                    ],
                  ),
                );
          return buildSheet(c, [
            Text(s('wheelAbout', 'About this chart', locale),
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(15),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: t.scaled(8)),
            // Read live off the SAME `WheelHistoryMeta` the wheel's own
            // About sheet reads — one asset, one set of facts about
            // provenance, coverage, scope and axis, so the two forms
            // cannot come to state them differently.
            section(
                s('wheelAboutProvenance', 'Where the dates come from', locale),
                meta.provenanceFor(locale)),
            section(s('wheelAboutCoverage', 'What is on the chart', locale),
                meta.coverageFor(locale)),
            section(
                s('wheelAboutScope', 'Where the table of nations stops',
                    locale),
                meta.scopeFor(locale)),
            section(s('wheelAboutAxis', 'Where the axis stops', locale),
                meta.axisFor(locale)),
            // NOTHING IS LISTED HERE AS MISSING, and that is now a
            // fact rather than an omission: this sheet briefly carried
            // a "not yet on this form" section for the genealogy rail,
            // and the rail landed the same day. Both forms draw the
            // same layers. If one ever stops doing so, the honesty
            // owed is the same as a filter's — say what is absent —
            // and this is where it goes.
          ]);
        },
      ),
    );
  }

  // ── find ───────────────────────────────────────────────────────────

  /// The wheel's own `_kindLabel`, reproduced rather than shared — see
  /// the class doc's FIND paragraph for why (`_RadialChronologyPage
  /// State` is private to `radial_chronology_page.dart`, which this
  /// page may not edit). Every string is looked up through the same
  /// `wheelStrings` keys via `s()`, so the words themselves never
  /// diverge even though the switch is typed twice.
  String _kindLabel(WheelHitKind kind, String locale) => switch (kind) {
        WheelHitKind.event => s('wheelKindEvent', 'event', locale),
        WheelHitKind.power => s('wheelKindPower', 'power', locale),
        WheelHitKind.nation => s('wheelKindNation', 'nation', locale),
        WheelHitKind.stream => s('wheelKindBand', 'band', locale),
        WheelHitKind.patriarch => s('wheelKindLife', 'life', locale),
        WheelHitKind.ministry => s('wheelKindMinistry', 'ministry', locale),
        WheelHitKind.omission => s('wheelKindOmission', 'no date', locale),
      };

  /// The wheel's own `_hitYears`.
  String _hitYears(WheelHit hit, WheelHistoryData data, String locale) {
    if (hit.kind == WheelHitKind.power) {
      final p = find(data.powers, (p) => p.id == hit.id);
      if (p != null) {
        final end = p.ongoing
            ? s('wheelPresent', 'present', locale)
            : yearLabel(p.end!, locale);
        return '${yearLabel(p.start, locale)} – $end';
      }
    }
    return hit.year == null ? '' : yearLabel(hit.year!, locale);
  }

  /// The wheel's own `_hitVia`.
  String _hitVia(WheelHit hit, String locale) => switch (hit.via) {
        WheelHitVia.otherLocale => hit.matched,
        WheelHitVia.otherSpelling => fill('wheelNameKjv',
            'King James Version: {name}', locale, {'name': hit.matched}),
        WheelHitVia.description =>
          s('wheelFindInDesc', 'in the description', locale),
        WheelHitVia.person => s('wheelFindPerson', 'names {name}', locale)
            .replaceFirst('{name}', hit.matched),
        WheelHitVia.reference => localizedReferenceLabel(hit.matched, locale),
        WheelHitVia.yearSpan => s('wheelFindSpan', 'spans it', locale),
        WheelHitVia.yearNear => s('wheelFindNear', 'nearby', locale),
        _ => '',
      };

  /// The wheel's own `_searchStatus`. `data.events.length` is what the
  /// FutureBuilder actually loaded — 851 in the shipped corpus (747
  /// from `wheel_history.json` plus 104 `WheelHistoryService.load`
  /// merges in from `bible_timeline.json`) — never the smaller
  /// asset-file count, so a "can search N events" line is never a lie
  /// about what is actually drawn.
  String _searchStatus(String query, WheelSearchResult result,
      WheelHistoryData data, String locale) {
    if (query.trim().isEmpty) {
      return fill('wheelFindTeach', '', locale, {
        'e': data.events.length,
        'p': data.powers.length,
        'm': data.ministries.length,
        'n': data.nations.length,
        'b': data.streams.length,
        'o': data.omissions.length,
      });
    }
    if (result.isEmpty) {
      return fill('wheelFindNone', 'Nothing here matches “{q}”.', locale,
          {'q': query.trim()});
    }
    final parts = <String>[
      if (result.hits.length == 1)
        fill('wheelFindCountOne', '{n} result', locale, {'n': 1})
      else
        fill(
            'wheelFindCount', '{n} results', locale, {'n': result.hits.length}),
      if (result.years.isNotEmpty)
        result.years.map((y) => yearLabel(y, locale)).join(' · '),
      if (result.nearestShown > 0)
        fill('wheelFindNearNote', '', locale, {'n': result.nearestShown}),
    ];
    return parts.join(' · ');
  }

  void _showSearch(BuildContext context, String locale) {
    final wb = WbColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) => FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (c, snap) {
          final data = snap.data;
          if (data == null) return const SizedBox(height: 120);
          final t = WbType.of(c);
          final colors = colorsFor(data);
          final kings = HebrewKingsService.instance.cached?.kings ?? const [];
          final patriarchs =
              ChronologyService.instance.cached?.patriarchs ?? const [];
          return StatefulBuilder(builder: (c, setSheet) {
            final query = _findCtl.text;
            // `searchWheel` itself — the wheel's, unchanged, called the
            // same way: it does not read [_hidden] to narrow, only to
            // mark `WheelHit.streamHidden` (see that function's own
            // library comment, point 3).
            final result = searchWheel(
              data: data,
              query: query,
              locale: locale,
              axisEnd: kStripMaxYear,
              hiddenStreams: _hidden,
              patriarchs: patriarchs,
              creationYear: creationYear,
              tradition: kDrawnTradition,
            );
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheet).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheet).size.height * 0.7),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: TextField(
                      key: const ValueKey('stripFindField'),
                      controller: _findCtl,
                      autofocus: true,
                      style:
                          TextStyle(color: wb.text, fontSize: t.scaled(13.5)),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: t.scaled(17)),
                        prefixIconConstraints: BoxConstraints(
                            minWidth: t.scaled(34), minHeight: t.scaled(20)),
                        hintText: s('wheelFindHint',
                            'A name, a verse or a year', locale),
                        hintStyle: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(13)),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(Icons.close, size: t.scaled(16)),
                                onPressed: () => setSheet(_findCtl.clear),
                              ),
                        border: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: wb.border)),
                      ),
                      onChanged: (_) => setSheet(() {}),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _searchStatus(query, result, data, locale),
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(11)),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      key: const ValueKey('stripFindList'),
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: result.hits.length,
                      itemBuilder: (c, i) {
                        final hit = result.hits[i];
                        final via = _hitVia(hit, locale);
                        return InkWell(
                          key: ValueKey('stripFindHit${hit.id}'),
                          onTap: () {
                            Navigator.of(sheet).pop();
                            _reveal(context, hit, data, kings, patriarchs,
                                locale, t.textScale);
                          },
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: t.scaled(5)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: t.scaled(3)),
                                  child: swatch(
                                      t,
                                      colors[hit.streamId] ??
                                          lineColor('none')),
                                ),
                                SizedBox(width: t.scaled(8)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(hit.title,
                                          style: TextStyle(
                                              color: wb.text,
                                              fontSize: t.scaled(12.5))),
                                      if (via.isNotEmpty ||
                                          hit.streamHidden) ...[
                                        SizedBox(height: t.scaled(1)),
                                        Text(
                                          [
                                            if (via.isNotEmpty) via,
                                            if (hit.streamHidden)
                                              s(
                                                  'wheelFindHiddenBand',
                                                  'band hidden — opening '
                                                      'this shows it again',
                                                  locale),
                                          ].join(' · '),
                                          style: TextStyle(
                                              color: wb.mutedText,
                                              fontSize: t.scaled(11)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(width: t.scaled(8)),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_hitYears(hit, data, locale),
                                        style: TextStyle(
                                            color: wb.mutedText,
                                            fontSize: t.scaled(11))),
                                    Text(_kindLabel(hit.kind, locale),
                                        style: TextStyle(
                                            color: wb.mutedText,
                                            fontSize: t.scaled(11))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
              ),
            );
          });
        },
      ),
    );
  }

  /// The strip's own `_reveal` — same three steps as the wheel's
  /// (`radial_chronology_page.dart`'s own doc on `_reveal`): un-hide
  /// the record's stream so it is actually on the chart, select it,
  /// then take the reader there. "There" is `_scrollToHit` — see that
  /// method's own doc for why it runs unconditionally rather than
  /// gated on zoom the way the wheel's `_panTo` is.
  void _reveal(
    BuildContext context,
    WheelHit hit,
    WheelHistoryData data,
    List<HebrewKing> kings,
    List<Patriarch> patriarchs,
    String locale,
    double textScale,
  ) {
    // An omission takes none of the steps below, for the same reason
    // the wheel's own `_reveal` returns early for one: there is no
    // band to un-hide, no span to select and nowhere on the axis to
    // scroll to. The sheet is the whole answer.
    if (hit.kind == WheelHitKind.omission) {
      final o = data.omissionById(hit.id);
      if (o != null) showOmission(context, o, locale);
      return;
    }
    setState(() {
      _hidden.remove(hit.streamId);
      _selectedId = hit.kind == WheelHitKind.nation ? hit.streamId : hit.id;
    });
    _scrollToHit(hit, data, kings, patriarchs, textScale);
    switch (hit.kind) {
      case WheelHitKind.event:
        final e = find(data.events, (e) => e.id == hit.id);
        if (e != null) showEvent(context, e, data, locale);
      case WheelHitKind.power:
        final p = find(data.powers, (p) => p.id == hit.id);
        if (p != null) showPower(context, p, data, locale, _select);
      case WheelHitKind.nation:
      case WheelHitKind.stream:
        final s = find(data.streams, (s) => s.id == hit.streamId);
        if (s != null) showStream(context, s, data, locale, _select);
      case WheelHitKind.patriarch:
        final man = ChronologyService.instance.cached?.byId(hit.id);
        if (man != null) showPatriarch(context, man, locale);
      case WheelHitKind.ministry:
        final m = data.ministryById(hit.id);
        if (m != null) showMinistry(context, m, locale);
      case WheelHitKind.omission:
        break;
    }
  }

  /// The year a hit's own record centres on, for [_scrollToHit]'s
  /// horizontal half. Not always [WheelHit.year] as-is: a power's own
  /// field is its START (so the status line and the result row can
  /// print it beside its end), but the reveal should centre the whole
  /// span, and a life or a ministry has no [WheelHit.year] at all — the
  /// search indexes a patriarch under his BIRTH year (`wheel_search
  /// .dart`), but centring on the birth would push half his own life
  /// arc's lane content off whichever side the death year falls on.
  /// Null for a kind with no year to centre on, exactly the kinds
  /// [_rowForHit] also cannot place on the x axis.
  int? _yearForHit(WheelHit hit, WheelHistoryData data) {
    switch (hit.kind) {
      case WheelHitKind.event:
        return find(data.events, (e) => e.id == hit.id)?.year;
      case WheelHitKind.power:
        final p = find(data.powers, (p) => p.id == hit.id);
        return p == null
            ? null
            : ((p.start + p.endFor(kStripMaxYear)) / 2).round();
      case WheelHitKind.ministry:
        final m = data.ministryById(hit.id);
        return m == null ? null : ((m.start + m.end) / 2).round();
      case WheelHitKind.patriarch:
        final creation = creationYear;
        final man = ChronologyService.instance.cached?.byId(hit.id);
        final f = man?.figures[kDrawnTradition];
        if (creation == null || f == null) return null;
        return creation + ((f.birthAm + f.deathAm) ~/ 2);
      case WheelHitKind.nation:
      case WheelHitKind.stream:
      case WheelHitKind.omission:
        return null;
    }
  }

  /// Which row of a FRESH `_currentRows` carries [hit] — the strip's
  /// answer to "which ring", built the same way the wheel resolves a
  /// life or a ministry's ring in `_panTo`: by id, against the exact
  /// prefix the lane builder itself uses (`kStripKingPrefix` /
  /// `kStripMinistryPrefix`, `strip_lanes.dart`), never a second copy
  /// of that string. A nation or a band has no single span standing
  /// for it — it names a whole stream, not a moment — so those two
  /// match on [StripLane.ownerId] instead and land on that stream's
  /// first sub-lane.
  StripRow? _rowForHit(WheelHit hit, List<StripRow> rows) {
    final StripLaneKind wantKind;
    String? wantId;
    switch (hit.kind) {
      case WheelHitKind.event:
        wantKind = StripLaneKind.events;
        wantId = hit.id;
      case WheelHitKind.power:
        wantKind = StripLaneKind.stream;
        wantId = hit.id;
      case WheelHitKind.patriarch:
        wantKind = StripLaneKind.lives;
        wantId = hit.id;
      case WheelHitKind.ministry:
        wantKind = StripLaneKind.ministries;
        wantId = '$kStripMinistryPrefix${hit.id}';
      case WheelHitKind.nation:
      case WheelHitKind.stream:
        wantKind = StripLaneKind.stream;
        wantId = null;
      case WheelHitKind.omission:
        return null;
    }
    for (final row in rows) {
      if (row.isHeading) continue;
      final lane = row.lane!;
      if (lane.kind != wantKind) continue;
      if (wantId != null) {
        if (lane.spans.any((s) => s.id == wantId)) return row;
      } else if (lane.ownerId == hit.streamId) {
        return row;
      }
    }
    return null;
  }

  /// Take the reader to what a search found: [scrollToCentre]
  /// horizontally (`strip_chronology_layout.dart`'s own "the strip's
  /// `focusTranslation`" — zoom is never touched, so a search cannot
  /// cost the reader their place), and the found row centred
  /// vertically, which has no wheel equivalent to share (a ring has no
  /// "row") and so is plain, new arithmetic in the same clamped shape.
  ///
  /// Runs UNCONDITIONALLY, never gated on zoom the way the wheel's own
  /// `_panTo` is: the wheel gates because at rest its whole axis is
  /// already on screen and panning would be motion for nothing, but
  /// `scrollToCentre` already returns 0 whenever the content is
  /// narrower than the viewport, so calling it every time costs an
  /// idle reveal nothing and a genuinely off-screen one everything.
  void _scrollToHit(
    WheelHit hit,
    WheelHistoryData data,
    List<HebrewKing> kings,
    List<Patriarch> patriarchs,
    double textScale,
  ) {
    final year = _yearForHit(hit, data);
    if (year != null && _hCtl.hasClients && _viewportW > 0) {
      final target = scrollToCentre(year, _pxPerYear, _viewportW);
      _hCtl.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    final rows = _currentRows(data, kings, patriarchs, textScale);
    final row = _rowForHit(hit, rows);
    if (row != null && _vCtl.hasClients) {
      final viewportH = _vCtl.position.viewportDimension;
      final maxOffset = _vCtl.position.maxScrollExtent;
      final target =
          (row.top + row.height / 2 - viewportH / 2).clamp(0.0, maxOffset);
      _vCtl.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  /// Two axes, two indicator families — `docs/strip-painter-spec.md`
  /// §8. Horizontal is a plain "you have scrolled away from an end,"
  /// gated on the hard content bounds. Vertical is the density signal:
  /// with every lane group stacked into ONE continuous scroll (there is
  /// no per-group clipped sub-viewport on this page), a lane group is
  /// off-screen exactly when the whole stack is scrolled past its top
  /// or short of its bottom — so one top/bottom pair for the stack
  /// answers "is a lane group off-screen" precisely, even though it
  /// does not name WHICH group the way the spec's prose frames it.
  ///
  /// [maxScrollX]/[maxScrollY] are computed by the caller from the
  /// content and viewport sizes it already has (`contentW - viewportW`
  /// etc.), rather than read off `_hCtl.position.maxScrollExtent` here:
  /// a `ScrollController`'s `ScrollPosition` does not exist until its
  /// `Scrollable` has actually mounted, so on the FIRST frame — before
  /// that attachment — `.position` would throw, and nothing after mount
  /// otherwise triggers a rebuild to notice it now can answer. The
  /// current OFFSET is still read off the controller (`_hCtl.offset`,
  /// guarded by `hasClients`), because before attachment it is
  /// genuinely 0 — the one thing a fresh page cannot be wrong about.
  List<Widget> _scrollIndicators({
    required double headerW,
    required WbColors wb,
    required WbType t,
    required String locale,
    required double maxScrollX,
    required double maxScrollY,
  }) {
    final hMoreBefore = _hCtl.hasClients && _hCtl.offset > 0.5;
    final hMoreAfter = maxScrollX > 0.5 &&
        (!_hCtl.hasClients || _hCtl.offset < maxScrollX - 0.5);
    final vMoreAbove = _vCtl.hasClients && _vCtl.offset > 0.5;
    final vMoreBelow = maxScrollY > 0.5 &&
        (!_vCtl.hasClients || _vCtl.offset < maxScrollY - 0.5);

    Widget banner(IconData icon, String label, {required bool top}) =>
        Positioned(
          left: headerW,
          right: 0,
          top: top ? 0 : null,
          bottom: top ? null : 0,
          child: IgnorePointer(
            child: Container(
              color: wb.paneBg.withValues(alpha: 0.85),
              padding: const EdgeInsets.symmetric(vertical: 2),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: t.scaledChrome(14), color: wb.mutedText),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: wb.mutedText, fontSize: t.scaledChrome(11))),
              ]),
            ),
          ),
        );

    return [
      if (vMoreAbove)
        banner(Icons.keyboard_arrow_up, ss('stripMoreAbove', locale),
            top: true),
      if (vMoreBelow)
        banner(Icons.keyboard_arrow_down, ss('stripMoreBelow', locale),
            top: false),
      if (hMoreBefore)
        Positioned(
          left: headerW,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
                width: 20,
                color: wb.paneBg.withValues(alpha: 0.55),
                child: Icon(Icons.chevron_left,
                    size: t.scaledChrome(16), color: wb.mutedText)),
          ),
        ),
      if (hMoreAfter)
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
                width: 20,
                color: wb.paneBg.withValues(alpha: 0.55),
                child: Icon(Icons.chevron_right,
                    size: t.scaledChrome(16), color: wb.mutedText)),
          ),
        ),
    ];
  }

  /// The one zoom axis this page has — `kStripZoomSteps`, unlike the
  /// wheel's shared `InteractiveViewer` zoom, because lane height is a
  /// constant (`kLaneHeight`'s own doc).
  Widget _zoomControls(String locale, WbType t, WbColors wb) {
    Widget btn(IconData icon, String tip, VoidCallback? go) => InkWell(
          onTap: go,
          child: Padding(
            padding: EdgeInsets.all(t.scaled(6)),
            child: Tooltip(
              message: tip,
              child: Icon(icon,
                  size: t.scaled(17),
                  color: go == null
                      ? wb.mutedText.withValues(alpha: 0.4)
                      : wb.text),
            ),
          ),
        );
    final i = kStripZoomSteps.indexOf(_pxPerYear);
    return Container(
      decoration: BoxDecoration(
        color: wb.paneBg.withValues(alpha: 0.94),
        border: Border.all(color: wb.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove, ss('stripZoomOut', locale),
            i > 0 ? () => _zoomStep(-1) : null),
        Container(width: 1, height: t.scaled(18), color: wb.border),
        SizedBox(
          width: t.scaled(60),
          child: Text('${_pxPerYear}px/yr',
              textAlign: TextAlign.center,
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
        ),
        Container(width: 1, height: t.scaled(18), color: wb.border),
        btn(Icons.add, ss('stripZoomIn', locale),
            i < kStripZoomSteps.length - 1 ? () => _zoomStep(1) : null),
        Container(width: 1, height: t.scaled(18), color: wb.border),
        btn(Icons.fit_screen, ss('stripFitAll', locale), _fitAll),
      ]),
    );
  }
}

double _measureText(String text, double size) => (TextPainter(
      text: TextSpan(text: text, style: canvasTextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout())
        .width;
