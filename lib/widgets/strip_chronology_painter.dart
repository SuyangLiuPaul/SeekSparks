/// The strip's three canvases — implements `docs/strip-painter-spec.md`
/// against the geometry in `strip_chronology_layout.dart` and the lane
/// model in `strip_lanes.dart`. See that spec for the paint order, the
/// exact colour/alpha expressions and why three painters rather than
/// one (`_StripLanesPainter`/`_StripRulerPainter`/
/// `_StripLaneHeaderPainter` in the spec's own naming — PUBLIC here,
/// unlike the wheel's `_WorldWheelPainter`, because the page that owns
/// them lives in a different file and Dart's `_private` is file-scoped).
///
/// Every span kind here traces to a wheel painter, and the spec names
/// which one for each: kings, ministries and stream powers descend from
/// `_paintArcs` (thick fill, edge hairlines, a selection outline);
/// patriarch lifespans descend from `_paintLifespans` (thin stroke, a
/// softer alpha ladder); events descend from `_paintSpokes` +
/// `_radialLabel`. What the wheel actually draws them THROUGH — kings,
/// ministries and patriarchs all share one annulus, painted by
/// `_paintLifespans`, even though the wheel's own comments call king
/// and ministry ids "arcs" — is not what the spec asks for; the spec
/// is explicit that kings and ministries get the heavier arc-power
/// treatment on the strip, and this file follows the spec's words
/// rather than the wheel's paint-method boundaries. Flagged in the
/// implementing agent's report, not silently resolved either way.
///
/// THE GENEALOGY RAIL is `_paintRail` below, §3.4 — a vertical tick per
/// [StripLaneKind.rail] span, its height (not its width; every one of
/// these years is a point) carrying the same "how many people share
/// this year" fact the wheel's `_Rail` mark carries as a stroke LENGTH.
/// One fixed, muted colour (`lineageRailColor()`), never a stream's or
/// descent hue, because [stripLineageCohorts]'s own doc is the fact
/// this file must not flatten: none of these years rest on a verse.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/strip_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/hebrew_king.dart' show Kingdom;
import 'package:seeksparks/models/strip_lanes.dart';
import 'package:seeksparks/models/wheel_history.dart' show WheelHistoryEvent;
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show
        centuryTickLabel,
        kingdomArcColor,
        lineageRailColor,
        lineColor,
        ministryArcColor,
        yearLabel;
import 'package:seeksparks/utils/font_catalog.dart' show canvasTextStyle;
import 'package:seeksparks/utils/radial_chronology_layout.dart'
    show selectionCovers;
import 'package:seeksparks/utils/strip_chronology_layout.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;

/// The verse beside an event title is set smaller than the title —
/// the wheel's own `_kRefSizeRatio` (`radial_chronology_page.dart:930`),
/// unchanged (`docs/strip-painter-spec.md` §7.2: "not independently
/// floored," the same category as the wheel's own hint text).
const double kStripRefSizeRatio = 0.86;

/// How close two event ticks may be, in ems of the lane's own type,
/// before one stands for both and carries a `+n` badge.
///
/// 1.35 line-heights is the wheel's own heuristic (`_kLabelPx * 1.35`),
/// and it is right for TICKS in either geometry: it is asking how close
/// two marks may be before the eye reads them as one, which has nothing
/// to do with which way the words run. (It is NOT the gate for the
/// words — see `_paintOneEventRow`, where transposing it to the label
/// cost a lane of solid black ink.)
///
/// PUBLIC, AND SHARED WITH THE PAGE ON PURPOSE. The badge is a promise
/// that `n` more records are behind this tick, and the page's tap
/// handler is what has to cash it — so both sides must group by the
/// same rule or the sheet would list a different set from the one the
/// badge counted. One constant is the only way to keep that true.
const double kStripEventClusterEm = 1.35;

/// Row height for one lane at the reader's Font Size, floored so a
/// label's own line box never exceeds the row it sits in.
///
/// `docs/strip-painter-spec.md` §7.1 — the arithmetic, not a guess.
/// `kLaneHeight` and a 12 px label both scale with `textScale`, so they
/// stay proportional everywhere ABOVE the point where the label's own
/// 11 px floor binds (`textScale < 0.917`); below that the label holds
/// at 11 px (line box 14.52 px) while a bare `kLaneHeight * textScale`
/// keeps shrinking, and two stops of the Font Size slider (12, 13 pt)
/// would clip a label into its neighbour without this floor.
double stripLaneHeightPx(double textScale) => math.max(
      kLaneHeight * textScale,
      WbMetrics.smallPrintFloor * WbMetrics.lineHeight,
    );

/// A lane-group heading's own row height — taller than a lane row so a
/// reader scanning the sticky column sees hierarchy, not a flat list
/// (`docs/strip-painter-spec.md` §5).
double stripHeadingHeightPx(double textScale) =>
    stripLaneHeightPx(textScale) * 1.3;

/// The recommended sticky-column width: the longest lane-group heading
/// in the active locale, plus one padding unit, clamped so a verbose
/// heading cannot swallow the content area.
///
/// `docs/strip-painter-spec.md` §5 — quoting `WbType.resolve`'s own
/// reasoning for the Browse pane's title: clamp and ellipsise, never
/// silently shrink the font to make a setting fit.
double stripHeaderColumnWidth({
  required String locale,
  required double headingFontPx,
  required double viewportWidth,
  required double Function(String text, double size) measure,
}) {
  var widest = 0.0;
  for (final key in const [
    'stripLaneEvents',
    'stripLaneLifespans',
    'stripLaneKings',
    'stripLaneMinistries',
    'stripLaneStreams',
  ]) {
    final text = stripStrings[key]?[locale] ?? stripStrings[key]!['en']!;
    widest = math.max(widest, measure(text, headingFontPx));
  }
  final padded = widest + headingFontPx * 2;
  return padded.clamp(headingFontPx * 4, viewportWidth * 0.30);
}

/// One row of the strip's vertical stack — a lane-group heading or one
/// packed [StripLane] — with its own top offset and height in content
/// pixels.
///
/// Built ONCE, by the page, and handed to all three painters plus used
/// for hit-testing (`nearestSpanAt` needs to know which row a tap's y
/// falls in before it can ask which span the x falls on). Composition
/// is the page's job (`docs/strip-painter-spec.md` §1), not something
/// each painter would otherwise re-derive from the same lane list three
/// times over.
class StripRow {
  const StripRow.heading(
    this.headingKey, {
    required this.top,
    required this.height,
  }) : lane = null;

  const StripRow.lane(
    StripLane this.lane, {
    required this.top,
    required this.height,
  }) : headingKey = null;

  /// A key into [stripStrings], non-null only for a heading row.
  final String? headingKey;

  final StripLane? lane;
  final double top;
  final double height;

  bool get isHeading => lane == null;
}

/// Everything a painter needs to name and colour a span, keyed by the
/// span's OWN id — never by kind, because the id space already keeps
/// kings, ministries, powers and patriarchs apart (`kStripKingPrefix`
/// etc., `strip_lanes.dart`'s own doc).
///
/// [streamColors] is `colorsFor(data)`, unchanged: the exact per-stream
/// shade a stream's OWN power bars and its groove use.
/// [eventById] gives events what no [StripSpan] carries — a title, a
/// reference, and the real owning stream (for [selectionCovers], which
/// a colour-family string cannot answer). [spanLabel] gives every other
/// kind (kings, ministries, stream powers, patriarch lifespans) the one
/// thing they are missing the same way: their own localised name.
class StripPalette {
  const StripPalette({
    required this.streamColors,
    required this.eventById,
    required this.spanLabel,
  });

  final Map<String, Color> streamColors;
  final Map<String, WheelHistoryEvent> eventById;
  final Map<String, String> spanLabel;
}

double _measure(String text, double size, {FontWeight? weight}) => (TextPainter(
      text: TextSpan(
          text: text,
          style: canvasTextStyle(fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout())
        .width;

/// A span's fill/stroke colour — never invented, always traced to
/// [WbColors]/[StripPalette] or the wheel's own family palette
/// (`lineColor`/`kingdomArcColor`/`ministryArcColor`, all imported, not
/// reproduced).
Color _spanColor(StripSpan span, StripLane lane, StripPalette palette) {
  switch (span.kind) {
    case StripLaneKind.stream:
      return palette.streamColors[lane.ownerId] ?? lineColor('none');
    case StripLaneKind.events:
      final event = palette.eventById[span.id];
      return event == null
          ? lineColor(span.line ?? 'none')
          : (palette.streamColors[event.stream] ?? lineColor('none'));
    case StripLaneKind.kings:
      return kingdomArcColor(
          span.line == 'israel' ? Kingdom.israel : Kingdom.judah);
    case StripLaneKind.ministries:
      return ministryArcColor();
    case StripLaneKind.lives:
      return lineColor(span.line ?? 'none');
    case StripLaneKind.rail:
      // One fixed shade for every cohort, never `span.line` — see
      // `strip_lanes.dart`'s `stripLineageCohorts` doc: none of these
      // years rest on a verse, so there is no "more confident" cohort
      // to give a stronger colour, and inventing one would print a
      // distinction the data does not support.
      return lineageRailColor();
    case StripLaneKind.ruler:
      // Never produced by `buildStripLanes` — see that file's own doc
      // on why the enum value exists at all.
      return lineColor('none');
  }
}

/// The [selectionCovers] `streamId` argument for one span.
///
/// Only a stream power genuinely belongs to a stream a background tap
/// can select — `lane.ownerId`, exactly what the wheel's `_paintArcs`
/// passes. An event's OWN stream is real too (`WheelHistoryEvent.stream`,
/// not carried on [StripSpan], which only keeps the colour-family
/// `line`) and is read from [StripPalette.eventById] so that selecting a
/// stream still lights that stream's events, as it does on the wheel.
/// Kings, ministries, patriarch lifespans and the genealogy rail belong
/// to no stream — on the wheel the first three are painted by
/// `_paintLifespans` and the rail by its own `_paintRail`, neither of
/// which ever calls `selectionCovers`, so passing an id nothing can
/// equal reproduces that absence of group-lighting rather than
/// inventing one.
String _streamIdFor(StripSpan span, StripLane lane, StripPalette palette) {
  switch (span.kind) {
    case StripLaneKind.stream:
      return lane.ownerId ?? '';
    case StripLaneKind.events:
      return palette.eventById[span.id]?.stream ?? '';
    case StripLaneKind.kings:
    case StripLaneKind.ministries:
    case StripLaneKind.lives:
    case StripLaneKind.rail:
    case StripLaneKind.ruler:
      return '';
  }
}

/// Grooves, bars, lifespans, the genealogy rail, event ticks and the
/// selection cross-hair — the whole scrolling content area.
/// `docs/strip-painter-spec.md` §2's paint order, followed exactly
/// except step 3's "before the spokes" ordering, which collapses here
/// since nothing on the strip needs to dodge a spoke's text the way the
/// wheel's arc names do (`fitBarLabel` truncates instead of searching
/// for room — §7.4).
class StripLanesPainter extends CustomPainter {
  StripLanesPainter({
    required this.rows,
    required this.pxPerYear,
    required this.locale,
    required this.selectedId,
    required this.wb,
    required this.laneFontPx,
    required this.palette,
    required this.visibleX0,
    required this.visibleX1,
  });

  final List<StripRow> rows;
  final double pxPerYear;
  final String locale;
  final String? selectedId;
  final WbColors wb;

  /// `WbType.scaledSmall(12)` at the call site — §7.1: lane content
  /// tracks the reader's Font Size, not the Menu Size chrome slider,
  /// because [kLaneHeight] already does.
  final double laneFontPx;

  final StripPalette palette;

  /// The horizontal window currently on screen, in content px — what
  /// [barLabelX] needs to keep a wide bar's name in view while it
  /// scrolls, and what an event label's own edge-flip is measured
  /// against.
  final double visibleX0;
  final double visibleX1;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrooves(canvas, size.width);
    _paintFilledBars(canvas);
    _paintLifespans(canvas);
    _paintRail(canvas);
    _paintEvents(canvas);
    _paintCrosshair(canvas, size.height);
  }

  double _rowFor(StripSpan span, StripRow row) => row.top + row.height / 2;

  /// One faint fill per lane, the full content width — so an empty
  /// stretch still reads as that lane rather than as blank paper. §3.1,
  /// alpha 0.06 unchanged from the wheel's own `_paintGrooves`.
  void _paintGrooves(Canvas canvas, double width) {
    for (final row in rows) {
      if (row.isHeading) continue;
      final lane = row.lane!;
      final color = lane.kind == StripLaneKind.stream
          ? (palette.streamColors[lane.ownerId] ?? lineColor('none'))
          : (lane.spans.isEmpty
              ? lineColor('none')
              : _spanColor(lane.spans.first, lane, palette));
      canvas.drawRect(
        Rect.fromLTWH(0, row.top, width, row.height),
        Paint()..color = color.withValues(alpha: 0.06),
      );
    }
  }

  /// Kings, ministries and stream powers — §3.2, descended from the
  /// wheel's `_paintArcs`: 86% fill, edge hairlines, a selection
  /// outline round the full row when this span is the selected one.
  void _paintFilledBars(Canvas canvas) {
    for (final row in rows) {
      if (row.isHeading) continue;
      final lane = row.lane!;
      if (lane.kind != StripLaneKind.kings &&
          lane.kind != StripLaneKind.ministries &&
          lane.kind != StripLaneKind.stream) {
        continue;
      }
      for (final span in lane.spans) {
        _paintOneFilledBar(canvas, span, lane, row);
      }
    }
  }

  void _paintOneFilledBar(
      Canvas canvas, StripSpan span, StripLane lane, StripRow row) {
    final x0 = xForYear(span.startYear, pxPerYear);
    final x1 = xForYear(span.endYear, pxPerYear);
    final color = _spanColor(span, lane, palette);
    final sel = span.id == selectedId;
    final lit = selectionCovers(
      selectedId: selectedId,
      ownId: span.id,
      streamId: _streamIdFor(span, lane, palette),
    );
    final dim = selectedId != null && !lit ? 0.35 : 1.0;
    final fillHeight = row.height * 0.86;
    final top = row.top + (row.height - fillHeight) / 2;

    if (x1 - x0 < 0.01) {
      // Rule 1: a zero-length reign keeps its ink — a dot, never a
      // widened bar. Verbatim from the wheel's own dot, `_paintLife
      // spans`' "nameless arc" branch: it is the same mechanism this
      // spec's zero-length example (Zimri, Huldah, Ahaziah of Judah,
      // Jehoahaz of Judah) names.
      canvas.drawCircle(
        Offset(x0, _rowFor(span, row)),
        math.min(1.6, fillHeight * 0.28),
        Paint()
          ..color = color.withValues(alpha: (0.78 * dim * 2.6).clamp(0.0, 1.0)),
      );
      return;
    }

    canvas.drawRect(
      Rect.fromLTRB(x0, top, x1, top + fillHeight),
      Paint()..color = color.withValues(alpha: 0.78 * dim),
    );
    final edge = Paint()
      ..strokeWidth = 0.7
      ..color = wb.paneBg.withValues(alpha: 0.85);
    canvas.drawLine(Offset(x0, top), Offset(x0, top + fillHeight), edge);
    canvas.drawLine(Offset(x1, top), Offset(x1, top + fillHeight), edge);
    if (sel) {
      canvas.drawRect(
        Rect.fromLTRB(x0, row.top, x1, row.top + row.height),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = wb.text.withValues(alpha: 0.85),
      );
    }

    final name = palette.spanLabel[span.id] ?? '';
    if (name.isEmpty) return;
    final visStart = math.max(x0, visibleX0);
    final visEnd = math.min(x1, visibleX1);
    final roomPx = math.max(0.0, visEnd - visStart);
    final fit = fitBarLabel(
        text: name, roomPx: roomPx, size: laneFontPx, measure: _measure);
    if (fit.text.isEmpty) return;
    final labelW = _measure(fit.text, laneFontPx);
    final labelX = barLabelX(
        barX0: x0,
        barX1: x1,
        labelW: labelW,
        viewX0: visibleX0,
        viewX1: visibleX1);
    final tp = TextPainter(
      text: TextSpan(
          text: fit.text,
          style: canvasTextStyle(
              fontSize: laneFontPx,
              color: wb.text.withValues(alpha: 0.98 * dim))),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, Offset(labelX, _rowFor(span, row) - tp.height / 2));
  }

  /// The Genesis lifespans — §3.3, descended from the wheel's
  /// `_paintLifespans`: a thinner stroke, its own softer alpha ladder,
  /// tick hairlines in the span's own colour, no selection-outline
  /// rectangle (the cross-hair, painted last, is what marks a selected
  /// life on this axis).
  void _paintLifespans(Canvas canvas) {
    for (final row in rows) {
      if (row.isHeading || row.lane!.kind != StripLaneKind.lives) continue;
      final lane = row.lane!;
      for (final span in lane.spans) {
        _paintOneLifespan(canvas, span, lane, row);
      }
    }
  }

  void _paintOneLifespan(
      Canvas canvas, StripSpan span, StripLane lane, StripRow row) {
    final x0 = xForYear(span.startYear, pxPerYear);
    final x1 = xForYear(span.endYear, pxPerYear);
    final color = _spanColor(span, lane, palette);
    final sel = span.id == selectedId;
    final has = selectedId != null;
    final alpha = sel ? 0.85 : (has ? 0.22 * 0.35 : 0.22);
    final stroke = row.height * 0.55;
    final y = _rowFor(span, row);

    if (x1 - x0 < 0.01) {
      canvas.drawCircle(
        Offset(x0, y),
        math.min(1.6, stroke * 0.28),
        Paint()..color = color.withValues(alpha: (alpha * 2.6).clamp(0.0, 1.0)),
      );
      return;
    }

    canvas.drawLine(
      Offset(x0, y),
      Offset(x1, y),
      Paint()
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = color.withValues(alpha: alpha),
    );
    final tick = Paint()
      ..strokeWidth = sel ? 1.4 : 0.7
      ..color = color.withValues(alpha: (alpha * 2).clamp(0.0, 1.0));
    canvas.drawLine(
        Offset(x0, y - stroke * 0.62), Offset(x0, y + stroke * 0.62), tick);
    canvas.drawLine(
        Offset(x1, y - stroke * 0.62), Offset(x1, y + stroke * 0.62), tick);

    final name = palette.spanLabel[span.id] ?? '';
    if (name.isEmpty) return;
    final visStart = math.max(x0, visibleX0);
    final visEnd = math.min(x1, visibleX1);
    final roomPx = math.max(0.0, visEnd - visStart);
    final fit = fitBarLabel(
        text: name, roomPx: roomPx, size: laneFontPx, measure: _measure);
    if (fit.text.isEmpty) return;
    final labelW = _measure(fit.text, laneFontPx);
    final labelX = barLabelX(
        barX0: x0,
        barX1: x1,
        labelW: labelW,
        viewX0: visibleX0,
        viewX1: visibleX1);
    final tp = TextPainter(
      text: TextSpan(
          text: fit.text,
          style: canvasTextStyle(
              fontSize: laneFontPx,
              color: color.withValues(alpha: sel ? 1.0 : 0.75))),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, Offset(labelX, y - tp.height / 2));
  }

  /// The genealogy rail — §3.4, descended from the wheel's own
  /// `_paintRail`. A tick, not a bar: a birth year is a point, and none
  /// of these people has a death year the tree is willing to state, the
  /// same reason the wheel draws a mark rather than a span here.
  void _paintRail(Canvas canvas) {
    for (final row in rows) {
      if (row.isHeading || row.lane!.kind != StripLaneKind.rail) continue;
      final lane = row.lane!;
      for (final span in lane.spans) {
        _paintOneRailTick(canvas, span, lane, row);
      }
    }
  }

  void _paintOneRailTick(
      Canvas canvas, StripSpan span, StripLane lane, StripRow row) {
    final x = xForYear(span.startYear, pxPerYear);
    final sel = span.id == selectedId;
    final has = selectedId != null;
    final alpha = sel ? 0.9 : (has ? 0.30 * 0.35 : 0.30);
    // The wheel's own fill formula, unchanged: 1 person is a third of
    // the mark's own share of room, 8 or more fills it, clamped so the
    // 44-person year (Genesis 46's sons and grandsons of Jacob) does
    // not bleed into its neighbours. The wheel spends this fraction on
    // the mark's LENGTH inside its angular pitch; a strip has no
    // angular pitch, so §3.4 spends it on the tick's HEIGHT inside the
    // lane's own row instead — the one substitution, everything else
    // verbatim.
    final count = span.cohortSize ?? 1;
    final fill = (0.34 + 0.66 * ((count - 1) / 7)).clamp(0.34, 1.0);
    final tickHeight = row.height * fill;
    final y = _rowFor(span, row);
    canvas.drawLine(
      Offset(x, y - tickHeight / 2),
      Offset(x, y + tickHeight / 2),
      Paint()
        ..strokeWidth = sel ? 1.8 : 1.0
        ..color = _spanColor(span, lane, palette).withValues(alpha: alpha),
    );
  }

  /// Event ticks and their labels, running rightward — §3.5. Declutter
  /// is per lane row via [clusterByX]: within one row, ticks already
  /// clear `packIntoLanes`' own `minGapPx`, which is far smaller than a
  /// title needs, so several close ticks still fight for the same
  /// stretch of row without this pass.
  void _paintEvents(Canvas canvas) {
    for (final row in rows) {
      if (row.isHeading || row.lane!.kind != StripLaneKind.events) continue;
      _paintOneEventRow(canvas, row);
    }
  }

  void _paintOneEventRow(Canvas canvas, StripRow row) {
    final lane = row.lane!;
    if (lane.spans.isEmpty) return;
    final xs = [for (final s in lane.spans) xForYear(s.startYear, pxPerYear)];
    final minGapPx = laneFontPx * kStripEventClusterEm;
    final pinned = lane.spans.indexWhere((s) => s.id == selectedId);
    final clusters = clusterByX(xs, minGapPx, pinned: pinned);
    final has = selectedId != null;

    // WHY A SECOND, WIDER GATE BELOW. `minGapPx` above is right for the
    // TICKS and wrong for the WORDS, and the reason is the one thing
    // that changes when a chart stops being round.
    //
    // On the wheel an event's title runs along the RADIUS — across the
    // time axis — so the angular room it needs is its LINE HEIGHT, and
    // `_kLabelPx * 1.35` is that line height. `radial_chronology_layout`
    // says so in as many words: "Angular space is scarce... a label
    // running outward occupies an angle no wider than its type."
    //
    // Here the title runs ALONG the axis, so what it occupies is its
    // WIDTH. Measured on the shipped corpus at 1.5 px/year, that gate
    // let clusters 15 px apart each draw a title 60-250 px wide, and the
    // events lane came out as solid black ink wherever the corpus is
    // dense — which is every century after 1500. The heuristic was
    // transposed from the wheel with its dimension unchanged.
    //
    // The gate is per-tick room (see the loop below), which makes ink
    // touching ink impossible by construction rather than by a running
    // cursor. The TICK is never suppressed either way: it is drawn
    // before any label decision, so the event stays visible and stays
    // tappable and its sheet is one tap away. That is the wheel's own
    // rule for a label that will not fit — legible or absent — and it
    // costs less here than there, because on a strip the reader's lever
    // really is free: the same title reappears at the next zoom step
    // without the chart having to give up anything else to show it.

    for (var ci = 0; ci < clusters.length; ci++) {
      final cluster = clusters[ci];
      final repIdx = cluster.representative;
      final repSpan = lane.spans[repIdx];
      final event = palette.eventById[repSpan.id];
      final x = xs[repIdx];
      final sel = repSpan.id == selectedId;
      final lit = selectionCovers(
        selectedId: selectedId,
        ownId: repSpan.id,
        streamId: _streamIdFor(repSpan, lane, palette),
      );
      final dim = has && !lit ? 0.28 : 1.0;
      final color = _spanColor(repSpan, lane, palette);

      canvas.drawLine(
        Offset(x, row.top + row.height * 0.15),
        Offset(x, row.top + row.height * 0.85),
        Paint()
          ..strokeWidth = sel ? 1.5 : 0.8
          ..color = color.withValues(alpha: 0.8 * dim),
      );
      if (event == null) continue;

      // A LABEL BELONGS TO ITS OWN TICK, AND MAY NOT REACH THE NEXT.
      //
      // The first cut of this gate only asked that a title clear the
      // last title DRAWN, which stops ink touching ink and does not
      // stop a title running straight past two or three later ticks.
      // `packIntoLanes` fills a row with whatever fits, so one row
      // carries events from 4200 BC, 490 BC, AD 180 and AD 1170 side by
      // side; with titles crossing ticks the row reads as one nonsense
      // sentence and — worse — there is no way to tell which mark any
      // given name belongs to. Reported as 「你这种要人怎么读」, which is
      // the right question.
      //
      // The room a title actually has is therefore the distance to the
      // NEXT TICK IN THIS ROW, less a gap, and never more. That makes
      // the label unambiguous by construction: every name sits in the
      // clear stretch its own mark owns.
      final nextX = ci + 1 < clusters.length
          ? xs[clusters[ci + 1].representative]
          : xForYear(kStripMaxYear, pxPerYear);
      final room = nextX - x - laneFontPx * 0.75;

      final badge =
          cluster.members.length > 1 ? '+${cluster.members.length - 1}' : '';
      // The order of sacrifice is the wheel's, for the wheel's reason
      // (`fitRadialLabel`): verse, then title, then badge. The badge is
      // the only mark saying other records are behind this tick, so it
      // is the last thing given up.
      final badgeW =
          badge.isEmpty ? 0.0 : _measure('  $badge', laneFontPx * kStripRefSizeRatio);
      final fit = fitBarLabel(
        text: event.titleFor(locale),
        roomPx: room - badgeW,
        size: laneFontPx,
        measure: _measure,
      );
      final title = fit.text;
      var ref = '';
      if (title.isNotEmpty && event.refs.isNotEmpty) {
        final candidate = localizedReferenceLabel(event.refs.first, locale);
        final w = _measure('  $candidate', laneFontPx * kStripRefSizeRatio);
        if (_measure(title, laneFontPx) + w + badgeW <= room) ref = candidate;
      }
      if (title.isEmpty && badge.isEmpty) continue;

      final titleTp = title.isEmpty
          ? null
          : (TextPainter(
              text: TextSpan(
                  text: title,
                  style: canvasTextStyle(
                      fontSize: laneFontPx,
                      color:
                          sel ? wb.text : wb.text.withValues(alpha: 0.95 * dim),
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
              textDirection: TextDirection.ltr,
              maxLines: 1)
            ..layout());
      final refTp = ref.isEmpty
          ? null
          : (TextPainter(
              text: TextSpan(
                  text: '  $ref',
                  style: canvasTextStyle(
                      fontSize: laneFontPx * kStripRefSizeRatio,
                      color: wb.link.withValues(alpha: 0.95 * dim))),
              textDirection: TextDirection.ltr,
              maxLines: 1)
            ..layout());
      final badgeTp = badge.isEmpty
          ? null
          : (TextPainter(
              text: TextSpan(
                  text: title.isEmpty ? badge : '  $badge',
                  style: canvasTextStyle(
                      fontSize: laneFontPx * kStripRefSizeRatio,
                      color: wb.mutedText.withValues(alpha: 0.95 * dim))),
              textDirection: TextDirection.ltr,
              maxLines: 1)
            ..layout());

      // NO RIGHT-EDGE FLIP. An earlier cut pulled a label left so its
      // end stayed inside the viewport, and that is wrong here twice
      // over: it walks the name backwards over the PREVIOUS tick, so
      // the reader cannot tell whose name it is; and it is computed
      // from the visible window, so every label near an edge moves as
      // the reader drags — a chart whose words shuffle while you scroll
      // it. A label now always starts at its own tick and runs right
      // inside the room that tick owns. Near the right edge it is
      // simply clipped, and one drag brings it back, which on a strip
      // costs nothing.
      final labelX = x;
      var penX = labelX;
      final y = row.top + row.height / 2;
      if (titleTp != null) {
        titleTp.paint(canvas, Offset(penX, y - titleTp.height / 2));
        penX += titleTp.width;
      }
      if (refTp != null) {
        refTp.paint(canvas, Offset(penX, y - refTp.height / 2));
        penX += refTp.width;
      }
      badgeTp?.paint(canvas, Offset(penX, y - badgeTp.height / 2));
    }
  }

  /// §3.6 — a full-height vertical rule at the selected span's own
  /// start and end. On the strip this is not a transliteration of the
  /// wheel's polar "contemporaries band," it IS that band, drawn as the
  /// straight line it always conceptually was.
  void _paintCrosshair(Canvas canvas, double totalHeight) {
    if (selectedId == null) return;
    StripSpan? found;
    for (final row in rows) {
      if (row.isHeading) continue;
      for (final s in row.lane!.spans) {
        if (s.id == selectedId) {
          found = s;
          break;
        }
      }
      if (found != null) break;
    }
    if (found == null) return;
    final paint = Paint()
      ..strokeWidth = 0.9
      ..color = wb.text.withValues(alpha: 0.5);
    for (final year in {found.startYear, found.endYear}) {
      final x = xForYear(year, pxPerYear);
      canvas.drawLine(Offset(x, 0), Offset(x, totalHeight), paint);
    }
  }

  @override
  bool shouldRepaint(StripLanesPainter old) =>
      old.rows.length != rows.length ||
      old.pxPerYear != pxPerYear ||
      old.locale != locale ||
      old.selectedId != selectedId ||
      old.laneFontPx != laneFontPx ||
      old.visibleX0 != visibleX0 ||
      old.visibleX1 != visibleX1;
}

/// The sticky ruler — §4, descended from `_paintCenturies` +
/// `_paintAxisEnds`, merged: a dedicated row has no collision to dodge,
/// so the wheel's `onRing` split (three phases fixing what it caused)
/// has nothing to reproduce here.
class StripRulerPainter extends CustomPainter {
  StripRulerPainter({
    required this.pxPerYear,
    required this.locale,
    required this.wb,
    required this.tickFontPx,
  });

  final double pxPerYear;
  final String locale;
  final WbColors wb;

  /// `WbType.scaledChrome(11)` — §7.3: the ruler stays on the Menu Size
  /// scale, unlike lane content, because its own row height is not
  /// committed to `textScale` by anything.
  final double tickFontPx;

  @override
  void paint(Canvas canvas, Size size) {
    final step = rulerStep(pxPerYear);
    final minor = Paint()
      ..color = wb.border.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    final major = Paint()
      ..color = wb.border.withValues(alpha: 0.5)
      ..strokeWidth = 0.9;
    for (final year in rulerTicks(step)) {
      final x = xForYear(year, pxPerYear);
      final isMajor = year % 500 == 0;
      canvas.drawLine(Offset(x, size.height * 0.45), Offset(x, size.height),
          isMajor ? major : minor);
      final tp = TextPainter(
        text: TextSpan(
            text: centuryTickLabel(year, locale),
            style: canvasTextStyle(fontSize: tickFontPx, color: wb.mutedText)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, 2));
    }

    // The two axis ends, brighter — "these two say what the chart's
    // range IS," the wheel's own `_paintAxisEnds` reasoning, unchanged.
    void end(int year, double x, TextAlign align) {
      final tp = TextPainter(
        text: TextSpan(
            text: yearLabel(year, locale),
            style: canvasTextStyle(
                fontSize: tickFontPx,
                color: wb.text,
                fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final dx = align == TextAlign.left ? x : x - tp.width;
      tp.paint(canvas, Offset(dx, size.height - tp.height - 1));
    }

    end(kStripMinYear, 0, TextAlign.left);
    end(kStripMaxYear, size.width, TextAlign.right);
  }

  @override
  bool shouldRepaint(StripRulerPainter old) =>
      old.pxPerYear != pxPerYear || old.locale != locale;
}

/// The sticky lane-header column — §5. New: the wheel's nearest
/// relative, `_paintBandNames`, only ever prints a stream's name once,
/// in a wedge that never scrolls past, which is not the same problem a
/// column that must stay readable through an arbitrary vertical scroll
/// has to solve.
class StripLaneHeaderPainter extends CustomPainter {
  StripLaneHeaderPainter({
    required this.rows,
    required this.locale,
    required this.wb,
    required this.laneFontPx,
    required this.headingFontPx,
    required this.palette,
  });

  final List<StripRow> rows;
  final String locale;
  final WbColors wb;
  final double laneFontPx;
  final double headingFontPx;
  final StripPalette palette;

  static const double _padding = 8;

  @override
  void paint(Canvas canvas, Size size) {
    for (final row in rows) {
      if (row.isHeading) {
        final text = stripStrings[row.headingKey]?[locale] ??
            stripStrings[row.headingKey]!['en']!;
        final tp = TextPainter(
          text: TextSpan(
              text: text,
              style: canvasTextStyle(
                  fontSize: headingFontPx,
                  color: wb.text,
                  fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        tp.paint(
            canvas, Offset(_padding, row.top + (row.height - tp.height) / 2));
        continue;
      }

      final lane = row.lane!;
      // Only a stream's FIRST sub-lane carries the stream's own name —
      // the direct descendant of `_paintBandNames`, which prints a
      // band's name once, not once per sub-ring. Kings, ministries and
      // events routinely need more than one sub-lane for the same
      // reason `packIntoLanes` exists (two spans overlap in time), and
      // that sub-lane is a packing artefact with no name of its own —
      // unlike a stream's, whose id names something real, a
      // `packIntoLanes` row index does not (`strip_lanes.dart`'s own
      // doc: lane assignment is a rendering decision, not a data one).
      if (lane.kind != StripLaneKind.stream || lane.subLane != 0) continue;

      final name = palette.spanLabel[lane.ownerId] ?? lane.ownerId ?? '';
      final color = (palette.streamColors[lane.ownerId] ?? lineColor('none'))
          .withValues(alpha: 0.98);
      final tp = TextPainter(
        text: TextSpan(
            text: name,
            style: canvasTextStyle(
                fontSize: laneFontPx,
                color: color,
                fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      tp.paint(
          canvas, Offset(_padding, row.top + (row.height - tp.height) / 2));

      if (lane.spans.isEmpty) {
        // Rule 2, restated for a lane group: an empty stretch and an
        // EMPTY GROUP look the same to a reader; only one of them is
        // true, and this says which — `stripEmptyLane`.
        final note = stripStrings['stripEmptyLane']?[locale] ??
            stripStrings['stripEmptyLane']!['en']!;
        final noteTp = TextPainter(
          text: TextSpan(
              text: note,
              style:
                  canvasTextStyle(fontSize: laneFontPx, color: wb.mutedText)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        noteTp.paint(
            canvas,
            Offset(_padding + tp.width + 6,
                row.top + (row.height - noteTp.height) / 2));
      }
    }
  }

  @override
  bool shouldRepaint(StripLaneHeaderPainter old) =>
      old.rows.length != rows.length ||
      old.locale != locale ||
      old.laneFontPx != laneFontPx ||
      old.headingFontPx != headingFontPx;
}
