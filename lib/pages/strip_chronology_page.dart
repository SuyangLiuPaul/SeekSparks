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
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/strip_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/chronology.dart' show Patriarch;
import 'package:seeksparks/models/hebrew_king.dart' show HebrewKing;
import 'package:seeksparks/models/strip_lanes.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show RadialChronologyPage, kDrawnTradition;
import 'package:seeksparks/pages/wheel_sheets.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/services/url_sync_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show canvasTextStyle;
import 'package:seeksparks/utils/strip_chronology_layout.dart';
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
    final kings = HebrewKingsService.instance.cached?.kings ?? const <HebrewKing>[];
    final creation = creationYear;
    // Honest fallback, the wheel's own rule (class doc, `radial_chronology
    // _page.dart`): if the creation anchor cannot be read, the layer
    // draws NOTHING rather than borrow a stand-in year.
    final patriarchs =
        creation == null ? const <Patriarch>[] : (chron?.patriarchs ?? const []);

    final lanes = buildStripLanes(
      wheel: data,
      kings: kings,
      patriarchs: patriarchs,
      tradition: kDrawnTradition,
      creationYear: creation ?? 0,
      pxPerYear: _pxPerYear,
    );

    final laneFontPx = t.scaledSmall(12);
    final headingFontPx = laneFontPx * 1.15;
    final tickFontPx = t.scaledChrome(11);
    final rows = _buildRows(lanes, t.textScale);
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
                      onTapUp: (e) => _handleTap(
                          context, e.localPosition, data, kings, patriarchs,
                          locale, rows),
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
        Positioned(
            right: 10, bottom: 10, child: _zoomControls(locale, t, wb)),
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
      case StripLaneKind.ruler:
        break;
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

    Widget banner(IconData icon, String label, {required bool top}) => Positioned(
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
        banner(Icons.keyboard_arrow_up, ss('stripMoreAbove', locale), top: true),
      if (vMoreBelow)
        banner(Icons.keyboard_arrow_down, ss('stripMoreBelow', locale), top: false),
      if (hMoreBefore)
        Positioned(
          left: headerW,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(width: 20, color: wb.paneBg.withValues(alpha: 0.55),
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
            child: Container(width: 20, color: wb.paneBg.withValues(alpha: 0.55),
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
                  color: go == null ? wb.mutedText.withValues(alpha: 0.4) : wb.text),
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
