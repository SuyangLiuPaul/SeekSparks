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
/// THE YEAR CURSOR, AND WHY IT IS A `Listener` AND NOT A TAP. Added
/// 2026-09-08 on the owner's report, which named the defect exactly:
/// 「没有线根本不知道哪一年，然后那一年也要显示当年发生什么事情」. The
/// axis only exists at the TOP of this page, so once a reader scrolls
/// down the lanes there is genuinely nothing on screen saying which
/// year a bar's edge is at. A press anywhere — the lanes or the sticky
/// ruler — commits `_cursorYear` on pointer UP within `kTouchSlop`, and
/// the shared `YearDigestBar` below says what that year holds.
///
/// The gesture is inherited whole from yswords' `chronology_chart.dart`
/// including the reason it is not a `GestureDetector`: a
/// `TapGestureRecognizer` fires `onTapDown` when it WINS the arena or
/// when 100 ms elapse, so `onTapDown` gave a chart where press-and-hold
/// worked and a quick tap did nothing — and no widget test could see it,
/// because `tapAt` sends down and up with nothing in between. A
/// `Listener` is not in the arena, so it coexists with this page's own
/// tap handler rather than competing with it: one press opens an
/// event's sheet AND lands the cursor on its year.
/// `test/year_cursor_test.dart` pins the drag half, and that test has
/// been mutation-checked — moving the commit to `onPointerDown` turns
/// it red and nothing else.
///
/// TWO ZOOMS, NOT ONE. `_pxPerYear` walks `kStripZoomSteps` (now up to
/// 96 px/year — the scale at which the corpus's densest window, AD
/// 1559-2008, can name every record it holds) and `_laneZoom` walks
/// `kStripLaneZoomSteps`, which multiplies the type size and the lane
/// height. Keeping them apart is this page's whole argument; the wheel
/// cannot, and that is why the wheel still crowds however far in it
/// goes.
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

import 'package:flutter/gestures.dart' show PointerDeviceKind, kTouchSlop;
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
import 'package:seeksparks/services/chart_symbol_service.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/services/url_sync_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show canvasTextStyle;
import 'package:seeksparks/utils/strip_chronology_layout.dart';
import 'package:seeksparks/utils/strip_viewport.dart';
import 'package:seeksparks/utils/strip_paint_text.dart';
import 'package:seeksparks/utils/strip_event_cards.dart';
import 'package:seeksparks/utils/strip_depth_layout.dart';
import 'package:seeksparks/widgets/chronology_depth_toggle.dart';
import 'package:seeksparks/widgets/chronology_filter_sheet.dart';
import 'package:seeksparks/widgets/chronology_explorer.dart';
import 'package:seeksparks/widgets/overflow_hint_scroll.dart';
import 'package:seeksparks/utils/year_digest.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/utils/wheel_search.dart';
import 'package:seeksparks/utils/chronology_explorer.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/strip_chronology_painter.dart';
import 'package:seeksparks/widgets/wheel_chrome_bar.dart';
import 'package:seeksparks/widgets/year_digest_bar.dart';
import 'package:seeksparks/utils/wheel_default_streams.dart';

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
/// The strip's own name, shared with the menu entry that opens it.
const Map<String, String> kStripPageTitle = _kPageTitle;

const Map<String, String> _kPageTitle = {
  'zh-Hans': '世界历史时间条',
  'zh-Hant': '世界歷史時間條',
  'en': 'World History Strip',
};

class StripChronologyPage extends StatefulWidget {
  const StripChronologyPage(
      {super.key,
      this.initialPeriod,
      this.initialHiddenStreams,
      this.initialStacked = true});

  /// Switching forms keeps the reader's range and layer choices. Each
  /// route still owns its controller, so replacing one cannot dispose
  /// the incoming page's navigation state.
  final ChronologyPeriod? initialPeriod;
  final Set<String>? initialHiddenStreams;
  final bool initialStacked;

  @override
  State<StripChronologyPage> createState() => _StripChronologyPageState();
}

class _StripChronologyPageState extends State<StripChronologyPage>
    with WheelSheets<StripChronologyPage> {
  Future<WheelHistoryData>? _future;
  final _explorer = ChronologyExplorerController();

  double _pxPerYear = kStripInitialPxPerYear;
  String? _selectedId;
  late bool _stacked;

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

  /// Whether the opening set has been chosen. One-shot, like the
  /// wheel's: a rebuild must not switch the reader's own choices back
  /// on.
  bool _defaultsApplied = false;

  /// Fill [_hidden] with the lanes the strip does not open on.
  ///
  /// 2026-09-15, 「strip wheel都是 而且一开始filter不要全部都有 这样
  /// loading很慢 一些主要的和圣经里面有的就行」.
  ///
  /// The strip is not capacity-bound the way the wheel is — lanes stack
  /// and it scrolls, so twenty-two of them fit in a way twenty-two rings
  /// never can. The ceiling here is the reader's eye rather than the
  /// geometry: a categorical palette stops being discriminable past
  /// about a dozen hues, which is also roughly where a first screen
  /// stops being a chart and starts being a texture. So the strip opens
  /// on the same twelve the widest wheel shows, in the same order, and
  /// the other ten are one tap away in the filter.
  void _applyDefaultHidden(WheelHistoryData data) {
    if (_defaultsApplied) return;
    _defaultsApplied = true;
    // 12 → [kOpeningStreams], 2026-09-15. 「filter limit应该apply strip
    // 和 wheel上面吧一起」.
    //
    // I argued against this and was overruled, which is worth recording
    // accurately: the case I made was that a strip lane stacks
    // vertically and prints its own name, so a reader here is reading
    // labels rather than matching hues, and twelve lanes stay legible
    // where twelve rings do not. The owner's answer is that the two
    // charts are one product and a limit that means different things on
    // each is a limit a reader has to learn twice. That is the stronger
    // argument about the thing that actually matters, so the ceiling is
    // shared — and the count is still what is DRAWN, never what exists.
    final keep = defaultVisibleStreams(
            data.streams.map((s) => s.id), kOpeningStreams)
        .toSet();
    for (final s in data.streams) {
      if (!keep.contains(s.id)) _hidden.add(s.id);
    }
  }

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

  /// The year the cursor rests on, or null before the reader has put it
  /// anywhere. Null is a real state and not "year zero": an untouched
  /// strip shows no rule and no readout, because a line drawn where
  /// nobody pointed is a claim about a year the reader did not choose.
  int? _cursorYear;

  /// Where the current press started, in GLOBAL coordinates — the slop
  /// test for [_placeCursor]. See the `Listener` in [_body] for why the
  /// cursor commits on UP rather than DOWN, and why global is the right
  /// frame for the question "did the finger travel".
  Offset? _pressOrigin;

  /// The SECOND zoom, and the reason this page exists.
  ///
  /// The strip's whole argument is that time and lanes are separate
  /// axes (`strip_chronology_layout.dart`'s library doc), and until now
  /// only one of the two had a control: `_pxPerYear` bought more room
  /// along the axis while every label stayed at the reader's Font Size.
  /// The owner reported exactly that — 「就算 zoom in 之后字也没有相应
  /// 变大」 — and the fix is not to fold the two axes back together
  /// (that is the wheel's defect, where `InteractiveViewer` magnifies a
  /// seven-day reign and Methuselah's 969 years by the same factor).
  /// It is to expose the axis that was designed and never wired up.
  double _laneZoom = 1;

  @override
  void initState() {
    super.initState();
    _stacked = widget.initialStacked;
    if (widget.initialPeriod case final period?) {
      _explorer.selectPeriod(period);
    }
    if (widget.initialHiddenStreams case final hidden?) {
      _hidden.addAll(hidden);
      _defaultsApplied = true;
    }
    // The strip does not draw the symbols, but it opens the same filter
    // sheet, and that sheet is where the set is learned. Without this a
    // reader who reached Filter from the strip would get plain colour
    // chips while the same sheet from the wheel showed the marks.
    if (ChartSymbolService.instance.cached.isEmpty) {
      ChartSymbolService.instance.load().then((_) {
        if (mounted) setState(() {});
      });
    }

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
    _explorer.dispose();
    super.dispose();
  }

  void _select(String? id) => setState(() => _selectedId = id);

  Iterable<StripDepthRowExtent> _rowExtents(List<StripRow> rows) =>
      rows.map((row) => (
            id: row.headingKey ?? row.lane!.id,
            top: row.top,
            height: row.height
          ));

  int _depthRevision = 0;

  void _setDepth(bool value) {
    if (_stacked == value) return;
    final anchor = stripDepthScrollAnchor(
        _rowExtents(_rowsCache ?? []), _vCtl.hasClients ? _vCtl.offset : 0);
    final revision = ++_depthRevision;
    setState(() => _stacked = value);
    // Row heights change, but the reader's location is a row plus a
    // fraction of that row. Retaining only pixels would silently jump
    // to a different country's records when the raised faces collapse.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _depthRevision || !_vCtl.hasClients) return;
      final offset =
          stripDepthOffsetForAnchor(_rowExtents(_rowsCache ?? []), anchor);
      if (offset != null) {
        _vCtl.jumpTo(offset.clamp(0.0, _vCtl.position.maxScrollExtent));
      }
    });
  }

  void _zoomStep(int delta) {
    final next = stripNextScale(_pxPerYear, delta, _viewportW);
    final offset = stripZoomOffset(
      offset: _hCtl.hasClients ? _hCtl.offset : 0,
      viewportWidth: _viewportW,
      oldScale: _pxPerYear,
      newScale: next,
    );
    _setTimeViewport(next, offset);
  }

  void _setTimeViewport(double scale, double offset) {
    final revision = ++_viewportRevision;
    setState(() => _pxPerYear = scale);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _viewportRevision || !_hCtl.hasClients) {
        return;
      }
      _hCtl.jumpTo(offset.clamp(0.0, _hCtl.position.maxScrollExtent));
    });
  }

  int _viewportRevision = 0;

  void _fitAll() => _explorer.showAll();

  void _browseRange(int start, int end) {
    if (_viewportW <= 0) return;
    final scale = pxPerYearToFit(start, end, _viewportW)
        .clamp(stripFitScale(_viewportW), kStripZoomSteps.last);
    _setTimeViewport(
        scale, stripOffsetForYear((start + end) / 2, _viewportW, scale));
    setState(() {
      _selectedId = null;
      _cursorYear = null;
    });
  }

  void _laneZoomStep(int delta) {
    final i = kStripLaneZoomSteps.indexOf(_laneZoom);
    final next =
        (i < 0 ? 1 : i + delta).clamp(0, kStripLaneZoomSteps.length - 1);
    setState(() => _laneZoom = kStripLaneZoomSteps[next]);
  }

  /// Put the cursor on a year, WITHOUT scrolling.
  ///
  /// Ported whole from yswords' `chronology_chart.dart` `_placeCursor`,
  /// including the reason it does not scroll: moving the view out from
  /// under the thing the reader just pointed at is the classic way a
  /// crosshair becomes unusable.
  void _placeCursor(int year) =>
      setState(() => _cursorYear = year.clamp(kStripMinYear, kStripMaxYear));

  /// The same, from a content-x — what a press on the lanes or on the
  /// ruler means.
  void _placeCursorAtX(double x) =>
      _placeCursor(yearForX(x, _pxPerYear).round());

  /// `stripStrings`' own lookup — `s()` (from [WheelSheets]) reads
  /// `uiStrings`/`wheelStrings`, neither of which carries this page's
  /// vocabulary.
  String ss(String key, String locale) =>
      stripStrings[key]?[locale] ?? stripStrings[key]?['en'] ?? key;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final wb = WbColors.of(context);
    // The ground, read once and remembered, because the scene and the
    // palette below are cached: a cache keyed on everything EXCEPT the
    // ground is how a reader who switches to dark mode keeps the light
    // palette until something unrelated happens to invalidate it.
    _dark = wb.isDark;

    return Scaffold(
      backgroundColor: wb.paneBg,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: wheelChromeTitle(
            context,
            _kPageTitle[locale] ?? _kPageTitle['en']!,
            MediaQuery.sizeOf(context).width),
        titleSpacing: wheelChromeTitleSpacing(MediaQuery.sizeOf(context).width),
        // Same three, same order, same tooltips as the wheel's own
        // toolbar (`radial_chronology_page.dart`'s `build`) — a
        // reader switching forms should find Find/Filter/About in
        // the same place they left them. Below `kWheelNarrowPaneWidth`
        // they fold into one sheet — see `wheelChromeActions`'s own
        // doc (`widgets/wheel_chrome_bar.dart`) for the 0.0 px title
        // this page rendered at 375 px before the fold, measured the
        // same way the wheel's own AppBar comment cites.
        actions: wheelChromeActions(
          context: context,
          locale: locale,
          paneWidth: MediaQuery.sizeOf(context).width,
          s: (key, fallback) => s(key, fallback, locale),
          onFind: () => _showSearch(context, locale),
          onFilter: () => _showFilter(context, locale),
          onAbout: () => _showAbout(context, locale),
          viewSwitch: _viewSwitch(context, locale),
        ),
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
          // Resolve the initial set before either the chart or the browser
          // sees the data: a post-frame default painted all 22 streams first.
          _applyDefaultHidden(data);
          final textScale = WbType.of(context).textScale;
          return ChronologyExplorer(
            controller: _explorer,
            data: data,
            locale: locale,
            hiddenStreams: Set.of(_hidden),
            streamColors: colorsFor(data, dark: _dark),
            selectedId: _selectedId,
            onFind: () => _showSearch(context, locale),
            onFilter: () => _showFilter(context, locale),
            onRange: _browseRange,
            onEvent: (event) {
              _placeCursor(event.year);
              _reveal(
                  context,
                  WheelHit(
                    kind: WheelHitKind.event,
                    via: WheelHitVia.title,
                    id: event.id,
                    streamId: event.stream,
                    title: event.titleFor(locale),
                    year: event.year,
                    matched: '',
                    rank: 0,
                    streamHidden: _hidden.contains(event.stream),
                  ),
                  data,
                  HebrewKingsService.instance.cached?.kings ?? const [],
                  ChronologyService.instance.cached?.patriarchs ?? const [],
                  locale,
                  textScale);
            },
            chart: _body(context, data, locale),
          );
        },
      ),
    );
  }

  /// The mirror of the wheel's own `SegmentedButton` — same strings,
  /// same shape, opposite default selection, and since 2026-09-04 the
  /// SAME widget (`wheelViewSwitch`, `widgets/wheel_chrome_bar.dart`)
  /// rather than a second hand-typed copy — see that file's doc for
  /// why. Tapping the already-selected 'strip' segment is a no-op,
  /// exactly as tapping 'wheel' is one on the wheel's side.
  Widget _viewSwitch(BuildContext context, String locale) => wheelViewSwitch(
        locale: locale,
        narrow: MediaQuery.sizeOf(context).width < kWheelNarrowPaneWidth,
        ss: (key, fallback) => ss(key, locale),
        selected: const {'strip'},
        onSelectionChanged: (selected) {
          if (selected.first != 'wheel') return;
          context.read<AppSettings>().setChronologyView('wheel');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
                builder: (_) => RadialChronologyPage(
                      initialStacked: _stacked,
                      initialPeriod: _explorer.period,
                      initialHiddenStreams: Set.unmodifiable(_hidden),
                    )),
          );
        },
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

    // Both zooms, applied where each belongs: `_pxPerYear` decides how
    // much axis a year buys, `_laneZoom` decides how big the type on
    // that axis is. Neither touches the other.
    final laneFontPx = t.scaledSmall(12) * _laneZoom;
    final headingFontPx = laneFontPx * 1.15;
    final tickFontPx = t.scaledChrome(11) * _laneZoom;

    final palette = _paletteFor(data, kings, patriarchs, locale);

    return LayoutBuilder(builder: (context, box) {
      final headerW = stripHeaderColumnWidth(
        locale: locale,
        headingFontPx: headingFontPx,
        viewportWidth: box.maxWidth,
        measure: _measureText,
      );
      _viewportW = box.maxWidth - headerW;
      final rows = _currentRows(data, kings, patriarchs, t.textScale);
      final contentW = stripContentWidth(_pxPerYear);
      final contentH = rows.isEmpty ? 0.0 : rows.last.top + rows.last.height;
      final rulerH = tickFontPx * WbMetrics.lineHeight * 2 + 6;

      final visibleX0 = _hCtl.hasClients ? _hCtl.offset : 0.0;
      final visibleY0 = _vCtl.hasClients ? _vCtl.offset : 0.0;
      final visibleY1 = visibleY0 +
          (_vCtl.hasClients ? _vCtl.position.viewportDimension : box.maxHeight);
      final visibleX1 = visibleX0 +
          (_hCtl.hasClients ? _hCtl.position.viewportDimension : _viewportW);

      // The readout is a row BELOW everything, and the zoom controls
      // and the scroll-edge indicators are pinned inside the part
      // above it. All three were in one Stack when the readout first
      // landed, and `Positioned(bottom: 10)` then put the zoom cluster
      // on top of the readout it was meant to sit above.
      return Column(children: [
        SizedBox(
          height: 48,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ChronologyDepthToggle(
                  is3D: _stacked,
                  onChanged: _setDepth,
                  locale: locale,
                  keyPrefix: 'stripDepth'),
            ),
          ),
        ),
        Expanded(
            child: Stack(children: [
          Column(children: [
            Row(children: [
              SizedBox(width: headerW, height: rulerH),
              Expanded(
                child: ClipRect(
                  // THE PAINTER IS A SIBLING OF THE SCROLL VIEW, not its
                  // child — see `strip_chronology_painter.dart`'s
                  // `contentWidth` doc. The scroll view still owns the
                  // extent and the press; it simply has nothing in it
                  // that paints.
                  child: Stack(children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: StripRulerPainter(
                            pxPerYear: _pxPerYear,
                            locale: locale,
                            wb: wb,
                            tickFontPx: tickFontPx,
                            visibleX0: visibleX0,
                            visibleX1: visibleX1,
                          ),
                        ),
                      ),
                    ),
                    // In viewport coordinates now, because it is no
                    // longer inside the thing that scrolls.
                    if (_cursorYear case final int y)
                      Positioned(
                        left: xForYear(y, _pxPerYear) -
                            visibleX0 -
                            _kCursorHalfWidth,
                        top: 0,
                        bottom: 0,
                        width: _kCursorHalfWidth * 2,
                        child: IgnorePointer(
                          child: ColoredBox(color: wb.accent),
                        ),
                      ),
                    SingleChildScrollView(
                      controller: _rulerHCtl,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      key: const ValueKey('stripRulerHScroll'),
                      // The ruler answers a press too. It is the one row
                      // on the page that is ONLY about the year, so it
                      // is where a reader who wants "which year is this"
                      // points first, and a ruler that ignored the press
                      // would be the odd one out.
                      //
                      // `opaque`, because the box it wraps is empty now:
                      // a Listener defers to its child by default, and
                      // an empty SizedBox hit-tests nothing.
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) => _pressOrigin = e.position,
                        onPointerUp: (e) => _commitPress(e, () {
                          _placeCursorAtX(e.localPosition.dx);
                        }),
                        onPointerCancel: (_) => _pressOrigin = null,
                        child: SizedBox(width: contentW, height: rulerH),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
            Expanded(
              child: Row(children: [
                SizedBox(
                  width: headerW,
                  child: ClipRect(
                    child: Stack(children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: StripLaneHeaderPainter(
                              rows: rows,
                              locale: locale,
                              wb: wb,
                              laneFontPx: laneFontPx,
                              headingFontPx: headingFontPx,
                              palette: palette,
                              symbols: ChartSymbolService.instance.cached,
                              visibleY0: visibleY0,
                              visibleY1: visibleY1,
                            ),
                          ),
                        ),
                      ),
                      // Extent only. This column is never wider than a
                      // phone, so its canvas was never the problem — it
                      // moves out with the other two because a column
                      // that scrolls by repainting and a chart that
                      // scrolls by translating would drift apart on
                      // every future change to either.
                      SingleChildScrollView(
                        controller: _headerVCtl,
                        physics: const NeverScrollableScrollPhysics(),
                        key: const ValueKey('stripHeaderVScroll'),
                        child: SizedBox(width: headerW, height: contentH),
                      ),
                    ]),
                  ),
                ),
                Expanded(
                  // A MOUSE DRAGS THIS. Flutter's default scroll behaviour
                  // gives a mouse the wheel and nothing else, and the
                  // gesture for a HORIZONTAL scroll view is shift-wheel,
                  // which nobody guesses — the same defect yswords fixed
                  // on its own chart after the owner asked for it in
                  // as many words. Touch could always swipe; the mouse
                  // now grabs, and the cursor says so before anyone tries.
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: ScrollConfiguration(
                      behavior: const _PanByMouseScrollBehavior(),
                      // THE CHART IS PAINTED HERE, beside the scroll
                      // views rather than inside them — see
                      // `strip_chronology_painter.dart`'s `contentWidth`
                      // doc for the 597,696 px canvas this replaces.
                      // The scroll views below keep the extent, the
                      // gestures and the hit testing; what they no
                      // longer keep is a picture the size of history.
                      child: Stack(children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: StripLanesPainter(
                              // From `codex/wheel-strip-redesign`: the
                              // raised mode. It moved here with the
                              // painter, which that branch had left
                              // inside the scroll view.
                              is3D: _stacked,
                              rows: rows,
                              pxPerYear: _pxPerYear,
                              locale: locale,
                              selectedId: _selectedId,
                              wb: wb,
                              laneFontPx: laneFontPx,
                              palette: palette,
                              visibleX0: visibleX0,
                              visibleX1: visibleX1,
                              visibleY0: visibleY0,
                              visibleY1: visibleY1,
                              contentWidth: contentW,
                              contentHeight: contentH,
                            ),
                          ),
                        ),
                      ),
                      // Keep the year rule visible through the data
                      // lanes, but below opaque callouts: a selection
                      // must not strike through the words the reader
                      // just chose. In viewport coordinates now.
                      if (_cursorYear case final int y)
                        Positioned(
                          key: const ValueKey('stripYearCursor'),
                          left: xForYear(y, _pxPerYear) -
                              visibleX0 -
                              _kCursorHalfWidth,
                          top: 0,
                          bottom: 0,
                          width: _kCursorHalfWidth * 2,
                          child: IgnorePointer(
                            child: ColoredBox(color: wb.accent),
                          ),
                        ),
                      SingleChildScrollView(
                        controller: _hCtl,
                        scrollDirection: Axis.horizontal,
                        key: const ValueKey('stripHScroll'),
                        child: SingleChildScrollView(
                          controller: _vCtl,
                          key: const ValueKey('stripVScroll'),
                          // WHY A RAW `Listener` AROUND THE TAP DETECTOR,
                          // and not a second `onTapDown`. Inherited whole
                          // from yswords' chronology chart, where the bug
                          // was found on a device and could not be
                          // reproduced in a widget test: a
                          // `TapGestureRecognizer` fires `onTapDown` when
                          // it WINS the arena or when 100 ms elapse,
                          // whichever comes first — so press-and-hold set
                          // the cursor and a quick tap did nothing at all,
                          // because the arena resolved first and an inner
                          // recogniser took the press. `tapAt` sends down
                          // and up with nothing between, so both paths
                          // pass in a test.
                          //
                          // A `Listener` is not in the arena, so nothing
                          // can take the press away from it. Committing on
                          // UP within `kTouchSlop` is what keeps a scroll
                          // drag from dragging the cursor along with it,
                          // and is why this COEXISTS with the tap detector
                          // below rather than competing: tapping an event
                          // opens its sheet AND lands the cursor on that
                          // year, which is what a reader means by pointing
                          // at something.
                          child: Listener(
                            onPointerDown: (e) => _pressOrigin = e.position,
                            onPointerUp: (e) => _commitPress(e, () {
                              final card = _eventCardAt(e.localPosition, rows);
                              if (card == null) {
                                final depthHit = _stacked
                                    ? _depthSpanAt(e.localPosition, rows)
                                    : null;
                                if (depthHit == null) {
                                  _placeCursorAtX(e.localPosition.dx);
                                } else {
                                  _placeCursor(
                                      yearForX(e.localPosition.dx, _pxPerYear)
                                          .round()
                                          .clamp(depthHit.span.startYear,
                                              depthHit.span.endYear));
                                }
                              } else if (card.firstYear == card.lastYear) {
                                _placeCursor(card.firstYear);
                              }
                            }),
                            onPointerCancel: (_) => _pressOrigin = null,
                            child: GestureDetector(
                              key: const ValueKey('chronologyStrip'),
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (e) => _handleTap(
                                  context,
                                  e.localPosition,
                                  data,
                                  kings,
                                  patriarchs,
                                  locale,
                                  rows),
                              child: SizedBox(
                                width: contentW,
                                height: contentH,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ]),
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
            // Read off the position once there is one. The computed form
            // (`contentH - (box.maxHeight - rulerH)`) assumed the ruler
            // was the only other row in this Column, and stopped being
            // true the moment the year readout became a second one — it
            // would have claimed more scroll room than there is and left
            // the "more below" arrow showing at the bottom of the stack.
            // The fallback stays for the FIRST frame, where a
            // `ScrollPosition` does not exist yet and `.position` throws.
            maxScrollY: _vCtl.hasClients
                ? _vCtl.position.maxScrollExtent
                : math.max(0.0, contentH - (box.maxHeight - rulerH)),
          ),
        ])),
        _zoomControls(locale, t, wb),
        // Always, not only once a year is picked — see [YearDigestBar]'s
        // own doc: a row that appears on the first tap takes its height
        // out of the chart at the moment the reader is looking at it.
        _digestBar(context, _cursorYear, data, kings, patriarchs, locale, rows),
      ]);
    });
  }

  Object? _paletteKey;
  StripPalette? _paletteCache;

  /// Which ground this chart is painted on; see the wheel page's own
  /// field for why it is remembered rather than looked up per call.
  bool _dark = false;

  StripPalette _paletteFor(WheelHistoryData data, List<HebrewKing> kings,
      List<Patriarch> patriarchs, String locale) {
    final key = (data, kings, patriarchs, locale, _dark);
    if (_paletteKey == key && _paletteCache != null) return _paletteCache!;
    final streamColors = colorsFor(data, dark: _dark);
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
        streamColors: streamColors,
        eventById: eventById,
        spanLabel: spanLabel,
        dark: _dark);

    _paletteKey = key;
    return _paletteCache = palette;
  }

  /// Sort the lanes into rows, one heading per kind block. `buildStrip
  /// Lanes` already emits its lanes grouped by kind in a fixed order —
  /// events, lives, kings, ministries, then every stream in turn — so a
  /// heading only has to go in front of the first lane of a new kind;
  /// the 22 streams share one heading because their [StripLane.kind]
  /// never changes across them (`docs/strip-painter-spec.md` §5: the
  /// streams are homogeneous, unlike kings/lifespans/ministries).
  List<StripRow> _buildRows(
      List<StripLane> lanes, double textScale, StripEventCards events) {
    final laneH = stripLaneHeightPx(textScale);
    final headH = stripHeadingHeightPx(textScale);
    final rows = <StripRow>[];
    var y = 0.0;
    if (events.rows.isNotEmpty) {
      rows.add(StripRow.heading('stripLaneEvents', top: y, height: headH));
      y += headH;
      for (var i = 0; i < events.rows.length; i++) {
        final cards = events.rows[i];
        // Retain every point in the lane model for the selected-year
        // digest and search reveal; the card is the reading geometry.
        final lane = StripLane(
            id: 'eventCards:$i',
            kind: StripLaneKind.events,
            subLane: i,
            spans: [
              for (final card in cards)
                for (final event in card.events)
                  StripSpan(
                      id: event.id,
                      kind: StripLaneKind.events,
                      startYear: event.year,
                      endYear: event.year),
            ]);
        rows.add(StripRow.events(lane,
            eventCards: cards,
            top: y,
            height: events.rowHeights[i],
            depthShapes: _stacked
                ? [
                    for (final card in cards)
                      stripDepthPrism(
                          id: card.events.first.id,
                          front: Rect.fromLTWH(
                              card.x, y + 8, card.width, card.height))
                  ]
                : const []));
        y += events.rowHeights[i];
      }
    }
    StripLaneKind? lastKind;
    for (final lane in lanes) {
      if (lane.kind == StripLaneKind.events) continue;
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
      final rowH = _stacked ? stripDepthRowHeight(laneH, lane.subLane) : laneH;
      rows.add(StripRow.lane(lane,
          top: y,
          height: rowH,
          depthShapes: _stacked
              ? [
                  for (final span in lane.spans)
                    layoutStripDepthSpan(
                        id: span.id,
                        x0: xForYear(span.startYear, _pxPerYear),
                        x1: xForYear(span.endYear, _pxPerYear),
                        rowTop: y,
                        rowHeight: rowH,
                        flatHeight: laneH,
                        tier: lane.subLane,
                        cohortSize: span.cohortSize)
                ]
              : const []));
      y += rowH;
    }
    return rows;
  }

  ({StripRow row, StripSpan span})? _depthSpanAt(
      Offset pos, List<StripRow> rows) {
    final candidates =
        rows.where((row) => !row.isHeading && row.eventCards.isEmpty);
    final shape =
        hitStripDepthShapes(candidates.expand((row) => row.depthShapes), pos);
    if (shape == null) return null;
    for (final row in candidates) {
      for (final span in row.lane!.spans) {
        if (span.id == shape.id) return (row: row, span: span);
      }
    }
    return null;
  }

  StripEventCard? _eventCardAt(Offset pos, List<StripRow> rows) {
    if (_stacked) {
      final candidates = rows.where((row) => row.eventCards.isNotEmpty);
      final shape =
          hitStripDepthShapes(candidates.expand((row) => row.depthShapes), pos);
      if (shape == null) return null;
      for (final row in candidates) {
        for (final card in row.eventCards) {
          if (card.events.first.id == shape.id) return card;
        }
      }
      return null;
    }
    for (final row in rows) {
      if (pos.dy < row.top || pos.dy >= row.top + row.height) continue;
      for (final card in row.eventCards) {
        if (card.contains(pos.dx, pos.dy - row.top)) return card;
      }
    }
    return null;
  }

  void _openEventCard(BuildContext context, StripEventCard card,
      WheelHistoryData data, String locale) {
    final range = stripEventCardZoomRange(card,
        currentScale: _pxPerYear, viewportWidth: _viewportW);
    if (range != null) {
      _browseRange(range.start, range.end);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _vCtl.hasClients) _vCtl.jumpTo(0);
      });
      return;
    }
    _select(card.events.first.id);
    _placeCursor(card.events.first.year);
    if (card.isGroup) {
      showCluster(context, card.events, data, locale, (id) {
        _select(id);
        final event = find(card.events, (event) => event.id == id);
        if (event != null) _placeCursor(event.year);
      });
    } else {
      showEvent(context, card.events.single, data, locale);
    }
  }

  /// Raised records resolve against the same front, roof and side
  /// polygons the painter uses, in reverse paint order. Flat records
  /// retain the row-and-time target from [nearestSpanAt]. Either route
  /// returns the original span id to the existing detail sheet.
  void _handleTap(
    BuildContext context,
    Offset pos,
    WheelHistoryData data,
    List<HebrewKing> kings,
    List<Patriarch> patriarchs,
    String locale,
    List<StripRow> rows,
  ) {
    final depthHit = _stacked ? _depthSpanAt(pos, rows) : null;
    StripRow? hit = depthHit?.row;
    for (final row in rows) {
      if (hit != null) break;
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
    if (lane.kind == StripLaneKind.events) {
      final card = _eventCardAt(pos, rows);
      if (card != null) {
        _openEventCard(context, card, data, locale);
      } else if (_selectedId != null) {
        _select(null);
      }
      return;
    }

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
    final pick = _stacked ? null : nearestSpanAt(pos.dx, targets);
    final span = _stacked
        ? depthHit?.span
        : (pick == null ? null : lane.spans[pick.index]);
    if (span == null) {
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

    switch (span.kind) {
      case StripLaneKind.events:
        // Event callouts were resolved against their rectangles above.
        return;
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
        final year =
            int.tryParse(span.id.substring(kStripLineagePrefix.length));
        if (year == null) return;
        final visible = _visibleInputs(data, kings, patriarchs);
        final drawn = <String>{
          for (final p in visible.patriarchs) p.id,
          for (final k in visible.kings) k.id,
          for (final e in visible.data.events)
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

  // Panning changes only the visible rectangle. Repacking every row
  // on every scroll notification made text caching only half a saving.
  // Include the hidden-set VALUES: the filter mutates its Set in place.
  Object? _rowsKey;
  List<StripRow>? _rowsCache;

  List<StripRow> _currentRows(
    WheelHistoryData data,
    List<HebrewKing> kings,
    List<Patriarch> patriarchs,
    double textScale,
  ) {
    final locale = context.read<AppSettings>().locale;
    final key = (
      data,
      kings,
      patriarchs,
      locale,
      _viewportW,
      FamilyTreeService.instance.cached,
      creationYear,
      _pxPerYear,
      textScale,
      _laneZoom,
      _stacked,
      (_hidden.toList()..sort()).join(',')
    );
    if (_rowsKey == key && _rowsCache != null) return _rowsCache!;
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
    _rowsKey = key;
    final events = buildStripEventCards(
      events: visible.data.events,
      pxPerYear: _pxPerYear,
      viewportWidth: _viewportW,
      laneFontPx:
          math.max(12 * textScale, WbMetrics.smallPrintFloor) * _laneZoom,
      locale: locale,
      measureHeight: measureStripEventTextHeight,
    );
    return _rowsCache = _buildRows(lanes, textScale * _laneZoom, events);
  }

  Future<void> _showFilter(BuildContext context, String locale) async {
    final data = await _future;
    if (!mounted || !context.mounted || data == null) return;
    final result = await showChronologyFilterSheet(
      context: context,
      locale: locale,
      data: data,
      hidden: _hidden,
      streamColors: colorsFor(data, dark: _dark),
      layerColors: {
        kLifespanLayerId: lineColor('shem', dark: _dark),
        kReignLayerId: kingdomArcColor(Kingdom.judah, dark: _dark),
        kMinistryLayerId: ministryArcColor(dark: _dark),
        kLineageLayerId: lineageRailColor(dark: _dark),
      },
      text: (key, fallback) => s(key, fallback, locale),
      keyPrefix: 'stripFilter',
      streamCeiling: kMaxVisibleStreams,
    );
    if (!mounted || result == null) return;
    setState(() => _hidden
      ..clear()
      ..addAll(result));
  }

  // ── about ──────────────────────────────────────────────────────────

  void _showAbout(BuildContext context, String locale) {
    final wb = WbColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
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
      isScrollControlled: true,
      builder: (sheet) => FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (c, snap) {
          final data = snap.data;
          if (data == null) return const SizedBox(height: 120);
          final t = WbType.of(c);
          final colors = colorsFor(data, dark: _dark);
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
                                          lineColor('none', dark: _dark)),
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
    // The newly revealed stream can add rows beyond the old scroll
    // extent. Wait for those rows before clamping to the viewport.
    final revision = ++_viewportRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _viewportRevision) return;
      _scrollToHit(hit, data, kings, patriarchs, textScale);
    });
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

  /// Run [go] only if the pointer that just lifted never travelled —
  /// the test that separates a point from a drag, and the reason the
  /// year cursor and the scroll views can share one pointer.
  ///
  /// The distance is measured in GLOBAL coordinates. The reason first
  /// written for that in yswords was wrong and is worth recording so
  /// nobody re-derives it: it LOOKS as though a pan would carry the
  /// scrolling content along with the pointer and leave `localPosition`
  /// unchanged, making a 300 pt drag measure as a stationary press. It
  /// does not — Flutter routes every event of a pointer through the
  /// hit-test result captured at DOWN, transforms included. Global
  /// stays because it is the frame the question is actually about.
  void _commitPress(PointerUpEvent e, VoidCallback go) {
    final origin = _pressOrigin;
    _pressOrigin = null;
    if (origin == null) return;
    if ((e.position - origin).distance > kTouchSlop) return;
    go();
  }

  /// The readout under the line — the shared [YearDigestBar], given
  /// this page's own vocabulary for the records it names.
  ///
  /// Built from `rows`, not from the corpus, so a lane the reader has
  /// filtered away is absent from the readout too: the digest and the
  /// picture are the same list read two ways.
  Widget _digestBar(
    BuildContext context,
    int? year,
    WheelHistoryData data,
    List<HebrewKing> kings,
    List<Patriarch> patriarchs,
    String locale,
    List<StripRow> rows,
  ) =>
      YearDigestBar(
        digest: year == null
            ? null
            : buildYearDigest(
                year: year,
                lanes: [
                  for (final r in rows)
                    if (r.lane case final StripLane lane) lane
                ],
              ),
        yearText: year == null ? '' : yearLabel(year, locale),
        hint: s('chronoYearHint', 'Tap the chart to read off a year', locale),
        label: (item) => digestLabel(item, data, kings, patriarchs, locale),
        onOpen: (item) => openDigestRecord(
            context, item, data, kings, patriarchs, locale, _select),
        onClear: () => setState(() => _cursorYear = null),
        s: (key, fallback) => s(key, fallback, locale),
        fill: (key, fallback, values) => fill(key, fallback, locale, values),
        onYear: _placeCursor,
        minYear: kStripMinYear,
        maxYear: kStripMaxYear,
      );

  /// The TWO zoom axes this page has, which is the whole difference
  /// between a strip and a wheel: `kStripZoomSteps` decides how much
  /// axis a year buys, `kStripLaneZoomSteps` decides how big the type
  /// on it is, and neither touches the other. The wheel's single
  /// `InteractiveViewer` scale cannot separate them.
  Widget _zoomControls(String locale, WbType t, WbColors wb) {
    Widget btn(IconData icon, String tip, VoidCallback? go) => IconButton(
          onPressed: go,
          tooltip: tip,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: const EdgeInsets.all(8),
          icon: Icon(icon, size: t.scaledChrome(18)),
        );
    final j = kStripLaneZoomSteps.indexOf(_laneZoom);
    final years = (_viewportW / _pxPerYear).round();
    final rangeLabel = locale == 'en' ? '$years yr / view' : '$years 年 / 屏';
    return Container(
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border: Border(top: BorderSide(color: wb.border)),
      ),
      child: OverflowHintScroll(
        fadeColor: wb.chromeBg,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          btn(
              Icons.remove,
              ss('stripZoomOut', locale),
              _pxPerYear > stripFitScale(_viewportW) + 0.000001
                  ? () => _zoomStep(-1)
                  : null),
          Text(rangeLabel,
              style:
                  TextStyle(color: wb.mutedText, fontSize: t.scaledChrome(11))),
          btn(Icons.add, ss('stripZoomIn', locale),
              _pxPerYear < kStripZoomSteps.last ? () => _zoomStep(1) : null),
          btn(Icons.fit_screen, ss('stripFitAll', locale), _fitAll),
          Container(width: 1, height: 18, color: wb.border),
          btn(Icons.text_decrease, ss('stripTypeSmaller', locale),
              j > 0 ? () => _laneZoomStep(-1) : null),
          btn(
              Icons.text_increase,
              ss('stripTypeBigger', locale),
              j < kStripLaneZoomSteps.length - 1
                  ? () => _laneZoomStep(1)
                  : null),
        ]),
      ),
    );
  }
}

/// Half the painted width of the year rule, in logical pixels.
///
/// Two pixels total, the same as yswords' own scrub cursor. Wider reads
/// as a band — a claim about a stretch of years — and this is a claim
/// about exactly one.
const double _kCursorHalfWidth = 1;

/// A mouse may drag this chart, not only wheel it.
///
/// Flutter's default gives a mouse the wheel and nothing else, and the
/// gesture for a HORIZONTAL scroll view is shift-wheel, which nobody
/// guesses. Identical to yswords' own `_PanByMouseScrollBehavior` — the
/// same fix for the same report, kept as two small classes rather than
/// a shared package because five lines are cheaper to read twice than
/// to depend on across two apps.
class _PanByMouseScrollBehavior extends MaterialScrollBehavior {
  const _PanByMouseScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}

/// The height of a scroll-edge banner, so the zoom cluster can sit
/// above one instead of on it. Mirrors `banner`'s own box: an icon plus
/// 2 px of padding top and bottom.
double stripScrollBannerHeight(WbType t) => t.scaledChrome(14) + 4;

double _measureText(String text, double size) => StripPaintTextCache.layout(
        text: text, style: canvasTextStyle(fontSize: size))
    .width;
