/// The strip's three canvases share one time axis and lane geometry.
///
/// The original paint specification is `docs/strip-painter-spec.md`.
/// This redesign keeps its data, hit targets and label-fitting rules,
/// while changing the visual hierarchy: neutral section backgrounds,
/// lightly tinted duration bars, and names in the theme's text colour.
/// The raised mode gives every existing row projected record faces;
/// their geometry is shared with the page's tap handler. No country or
/// layer is replaced by a single-country focus view.
///
/// Every painter now rejects work outside its visible axes before
/// laying out text. Event cards group the complete visible event corpus
/// into stable calendar buckets; scrolling cannot change their members.
/// Straight labels share immutable Paragraphs through
/// `StripPaintTextCache`; moving a warm label costs no new layout.
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
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/strip_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/hebrew_king.dart' show Kingdom;
import 'package:seeksparks/models/strip_lanes.dart';
import 'package:seeksparks/utils/chronology_symbols.dart';
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
import 'package:seeksparks/utils/strip_paint_text.dart';
import 'package:seeksparks/utils/strip_event_cards.dart';
import 'package:seeksparks/utils/strip_depth_layout.dart';
import 'package:seeksparks/utils/strip_paint_visibility.dart';

/// Retained as the old tick-cluster threshold for regression measurements.
/// Event navigation now uses dated cards shared by painting and hit-testing.
const double kStripEventClusterEm = 1.35;

/// A readable row keeps at least 32 logical pixels of vertical target.
///
/// The previous 22 px row left only 6.16 px outside a 12 px label's
/// 15.84 px line box. At 32 px that clearance is 16.16 px; the labels
/// stop forming one dense texture and a finger can stay in its lane.
/// Larger type expands the row, while smaller type does not shrink its
/// target. Time positions and the lane assignment stay unchanged; this
/// changes only the displayed row spacing.
double stripLaneHeightPx(double textScale) => math.max(32, 32 * textScale);

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
  // 0.30 of the viewport is generous on a desktop and too tight on a
  // phone, and it was the phone that showed it: at 375 px the clamp is
  // 112 and 犹大与以色列列王 — a heading this chart actually draws, and
  // one of the five measured just above — wants more, so it was painted
  // straight past the column and cut MID-GLYPH by the canvas edge.
  // A narrow viewport gets 0.40 instead. The content column loses about
  // 37 px, which at the opening 1.5 px/year is 25 years out of 250; a
  // row whose name is cut in half costs the reader the whole row.
  final share = viewportWidth < 600 ? 0.40 : 0.30;
  return padded.clamp(headingFontPx * 4, viewportWidth * share);
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
  })  : lane = null,
        eventCards = const [],
        depthShapes = const [];

  const StripRow.lane(
    StripLane this.lane, {
    required this.top,
    required this.height,
    this.depthShapes = const [],
  })  : headingKey = null,
        eventCards = const [];

  const StripRow.events(
    StripLane this.lane, {
    required this.eventCards,
    this.depthShapes = const [],
    required this.top,
    required this.height,
  }) : headingKey = null;

  final List<StripEventCard> eventCards;

  /// These exact faces drive both Canvas paint and pointer resolution.
  final List<StripDepthShape> depthShapes;

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
    required this.dark,
  });

  final Map<String, Color> streamColors;
  final Map<String, WheelHistoryEvent> eventById;
  final Map<String, String> spanLabel;

  /// The ground these colours are for.
  ///
  /// It rides with the palette rather than being looked up here because
  /// this file is a painter: it has no `BuildContext`, and the fallback
  /// shades below (`lineColor('none')` and friends) are chosen for a
  /// span whose stream is missing — exactly the case a reader is least
  /// likely to forgive being invisible.
  final bool dark;
}

double _measure(String text, double size, {FontWeight? weight}) =>
    (StripPaintTextCache.layout(
      text: text,
      style: canvasTextStyle(fontSize: size, fontWeight: weight),
    )).width;

double measureStripEventTextHeight(
        String text, double width, double fontSize, bool bold) =>
    StripPaintTextCache.layout(
      text: text,
      style: canvasTextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
      maxWidth: width,
      maxLines: null,
    ).height;

/// A span's fill/stroke colour — never invented, always traced to
/// [WbColors]/[StripPalette] or the wheel's own family palette
/// (`lineColor`/`kingdomArcColor`/`ministryArcColor`, all imported, not
/// reproduced).
Color _spanColor(StripSpan span, StripLane lane, StripPalette palette) {
  switch (span.kind) {
    case StripLaneKind.stream:
      return palette.streamColors[lane.ownerId] ??
          lineColor('none', dark: palette.dark);
    case StripLaneKind.events:
      final event = palette.eventById[span.id];
      return event == null
          ? lineColor(span.line ?? 'none', dark: palette.dark)
          : (palette.streamColors[event.stream] ??
              lineColor('none', dark: palette.dark));
    case StripLaneKind.kings:
      return kingdomArcColor(
          span.line == 'israel' ? Kingdom.israel : Kingdom.judah,
          dark: palette.dark);
    case StripLaneKind.ministries:
      return ministryArcColor(dark: palette.dark);
    case StripLaneKind.lives:
      return lineColor(span.line ?? 'none', dark: palette.dark);
    case StripLaneKind.rail:
      // One fixed shade for every cohort, never `span.line` — see
      // `strip_lanes.dart`'s `stripLineageCohorts` doc: none of these
      // years rest on a verse, so there is no "more confident" cohort
      // to give a stronger colour, and inventing one would print a
      // distinction the data does not support.
      return lineageRailColor(dark: palette.dark);
    case StripLaneKind.ruler:
      // Never produced by `buildStripLanes` — see that file's own doc
      // on why the enum value exists at all.
      return lineColor('none', dark: palette.dark);
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
/// Paint order keeps labels above their own quiet guides. `fitBarLabel`
/// uses the same width contract as the previous renderer, so changing
/// the surface does not change which records a tap can reach.
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
    this.visibleY0 = 0,
    this.visibleY1 = double.infinity,
    required this.contentWidth,
    required this.contentHeight,
    this.is3D = false,
  });

  final List<StripRow> rows;
  final bool is3D;
  final double pxPerYear;
  final String locale;
  final String? selectedId;
  final WbColors wb;

  /// `WbType.scaledSmall(12)` at the call site — §7.1: lane content
  /// tracks the reader's Font Size, not the Menu Size chrome slider,
  /// because [kLaneHeight] already does.
  final double laneFontPx;

  final StripPalette palette;

  /// The visible content window. Long bars pin their names to this
  /// interval; events retain their fixed text origin and are culled
  /// only after the whole space up to their next tick has left it.
  final double visibleX0;
  final double visibleX1;
  final double visibleY0;
  final double visibleY1;

  /// The size of the WHOLE strip, which since 2026-09-15 is no longer
  /// the size of the canvas.
  ///
  /// THE CANVAS IS THE VIEWPORT NOW. This painter used to sit inside the
  /// scroll views, on a canvas as wide as the entire timeline — at the
  /// top of the zoom ladder, 96 px/year across 6,226 years, that is
  /// **597,696 px**. Skia cannot record a picture that size: it aborts,
  /// and CanvasKit reports `RuntimeError: Aborted()` from inside
  /// `PictureRecorder`, with a `RenderBox was not laid out` beside it.
  /// Both arrived from a reader's browser on 1.6.285.
  ///
  /// Culling the DRAW CALLS — which this painter already did, and which
  /// is what `visibleX0`/`visibleX1` are for — does not help, because
  /// the picture's bounds are the canvas, not the marks. The canvas
  /// itself had to shrink.
  ///
  /// So the painter is now a sibling of the scroll view rather than its
  /// child: its canvas is the visible rectangle, and it translates by
  /// [visibleX0] / [visibleY0] so every coordinate below stays in
  /// CONTENT space and none of the drawing code had to change. What did
  /// have to change is the two places that read `size` as the extent of
  /// the strip — they read these instead.
  final double contentWidth;
  final double contentHeight;

  bool _rowVisible(StripRow row) => stripPaintIntersects(
        start: row.top,
        end: row.top + row.height,
        visibleStart: visibleY0,
        visibleEnd: visibleY1,
      );

  bool _spanVisible(double x0, double x1, {double padding = 2}) =>
      stripPaintIntersects(
        start: x0,
        end: x1,
        visibleStart: visibleX0,
        visibleEnd: visibleX1,
        padding: padding,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Content space, on a viewport-sized canvas. Everything below this
    // line is written in the coordinates the strip has always used.
    //
    // MERGE NOTE, 2026-09-15. Two restructurings of this method landed
    // the same afternoon and both belong: the raised (`is3D`) branch,
    // and the viewport canvas. They compose cleanly because they are
    // about different things — WHAT is drawn, and WHERE the origin is —
    // so the translate wraps both branches and the two `size` reads
    // become the content extent in each.
    canvas.translate(-visibleX0, -visibleY0);
    _paintGrooves(canvas, contentWidth);
    if (is3D) {
      _paintCrosshair(canvas, contentHeight);
      _paintDepthRows(canvas);
    } else {
      _paintFilledBars(canvas);
      _paintLifespans(canvas);
      _paintRail(canvas);
      _paintCrosshair(canvas, contentHeight);
    }
    _paintEvents(canvas);
  }

  Path _depthPath(List<Offset> vertices) => Path()..addPolygon(vertices, true);

  void _paintPrism(Canvas canvas, StripDepthShape shape, Color color,
      {required bool selected}) {
    final front = Color.lerp(wb.paneBg, color, selected ? .23 : .13)!;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 1.8 : .8
      ..color = Color.lerp(wb.paneBg, color, selected ? .95 : .65)!;
    for (final face in [
      (shape.top, Color.lerp(wb.paneBg, color, .07)!),
      (shape.side, Color.lerp(wb.paneBg, color, .32)!),
      (shape.frontFace, front),
    ]) {
      final path = _depthPath(face.$1);
      canvas.drawPath(path, Paint()..color = face.$2);
      canvas.drawPath(path, outline);
    }
  }

  /// All concurrent packed rows stay on the screen. A taller face
  /// separates the later rows without changing any time coordinate.
  /// Names stay horizontal inside their own opaque front; a roof may
  /// pass behind the next prism, but cannot strike through its words.
  void _paintDepthRows(Canvas canvas) {
    for (final row in rows) {
      if (!_rowVisible(row) || row.isHeading || row.eventCards.isNotEmpty) {
        continue;
      }
      final lane = row.lane!;
      for (var i = 0; i < row.depthShapes.length; i++) {
        final shape = row.depthShapes[i];
        if (!_spanVisible(shape.bounds.left, shape.bounds.right)) continue;
        final span = lane.spans[i];
        _paintPrism(canvas, shape, _spanColor(span, lane, palette),
            selected: selectionCovers(
                selectedId: selectedId,
                ownId: span.id,
                streamId: _streamIdFor(span, lane, palette)));
        final name = palette.spanLabel[span.id] ?? '';
        if (name.isEmpty) continue;
        final room = stripDepthLabelArea(shape, visibleX0, visibleX1);
        final fit = room.isEmpty
            ? (text: '', ellipsised: false)
            : fitBarLabel(
                text: name,
                roomPx: room.width,
                size: laneFontPx,
                measure: _measure);
        final fits = fit.text.isNotEmpty;
        if (fits) {
          final text = StripPaintTextCache.layout(
              text: fit.text,
              style: canvasTextStyle(fontSize: laneFontPx, color: wb.text));
          if (text.height <= room.height) {
            text.paint(
                canvas, Offset(room.left, room.center.dy - text.height / 2));
            continue;
          }
        }
        // 2026-09-16 「好像这个其实后面放得下 但是zoom in多一次那个框框就
        // 放得下了 这样就放回框框里」 — inside whenever it fits, which is
        // what the branch above is for, and beside it when it does not.
        // The depth rows are the same picture as the flat bars and were
        // the path this was missing: a seven-year reign drawn as a prism
        // carried no name at all while the lane to its right was empty.
        var nextX0 = double.infinity;
        var previousX1 = double.negativeInfinity;
        for (final other in row.depthShapes) {
          if (identical(other, shape)) continue;
          final left = other.bounds.left;
          final right = other.bounds.right;
          if (left >= shape.bounds.right && left < nextX0) nextX0 = left;
          if (right <= shape.bounds.left && right > previousX1) {
            previousX1 = right;
          }
        }
        final at = trailingLabelX(
          barX1: shape.bounds.right,
          barX0: shape.bounds.left,
          labelW: _measure(name, laneFontPx),
          nextX0: nextX0,
          previousX1: previousX1,
          viewX0: visibleX0,
          viewX1: visibleX1,
        );
        if (at == null) continue;
        final text = StripPaintTextCache.layout(
            text: name,
            style: canvasTextStyle(
                fontSize: laneFontPx, color: wb.text.withValues(alpha: 0.8)));
        final middle = room.isEmpty ? shape.front.center.dy : room.center.dy;
        text.paint(canvas, Offset(at, middle - text.height / 2));
      }
    }
  }

  /// One bar's name: inside the bar when it fits, and immediately AFTER
  /// the bar when it does not.
  ///
  /// 2026-09-16 「如果框框放不下 就放在那个线或者窄框框后面 如果后面有位
  /// 置」. A seven-year reign at the zoom that shows four centuries is
  /// three pixels wide, so [fitBarLabel] answers — correctly — that no
  /// name fits inside it, and the reader was left with a coloured
  /// sliver and no way to learn what it was without tapping it. A lane
  /// is a packing of NON-OVERLAPPING spans, so the room to the right of
  /// that sliver is usually empty for decades.
  ///
  /// The name stops clear of the next span in the lane, because a name
  /// touching the following bar reads as that bar's name.
  ({String text, double x, bool after})? _barLabel(
      StripSpan span, StripLane lane, String name, double x0, double x1) {
    if (name.isEmpty) return null;
    final visStart = math.max(x0, visibleX0);
    final visEnd = math.min(x1, visibleX1);
    final fit = fitBarLabel(
        text: name,
        roomPx: math.max(0.0, visEnd - visStart),
        size: laneFontPx,
        measure: _measure);
    if (fit.text.isNotEmpty) {
      return (
        text: fit.text,
        x: barLabelX(
            barX0: x0,
            barX1: x1,
            labelW: _measure(fit.text, laneFontPx),
            viewX0: visibleX0,
            viewX1: visibleX1),
        after: false,
      );
    }
    var nextX0 = double.infinity;
    var previousX1 = double.negativeInfinity;
    for (final other in lane.spans) {
      if (other.id == span.id) continue;
      final ox = xForYear(other.startYear, pxPerYear);
      final oz = xForYear(other.endYear, pxPerYear);
      if (ox >= x1 && ox < nextX0) nextX0 = ox;
      if (oz <= x0 && oz > previousX1) previousX1 = oz;
    }
    final x = trailingLabelX(
      barX1: x1,
      barX0: x0,
      labelW: _measure(name, laneFontPx),
      nextX0: nextX0,
      previousX1: previousX1,
      viewX0: visibleX0,
      viewX1: visibleX1,
    );
    return x == null ? null : (text: name, x: x, after: true);
  }

  double _rowFor(StripSpan span, StripRow row) => row.top + row.height / 2;

  /// Group headings provide structure without colouring the entire
  /// width of every lane. A quiet guide survives in an empty row; the
  /// stronger colour belongs to the record, where it conveys identity.
  void _paintGrooves(Canvas canvas, double width) {
    final x0 = math.max(0.0, visibleX0);
    final x1 = math.min(width, visibleX1);
    for (final row in rows) {
      if (!_rowVisible(row)) continue;
      if (row.isHeading) {
        canvas.drawRect(
          Rect.fromLTRB(x0, row.top, x1, row.top + row.height),
          Paint()..color = wb.paneAltBg,
        );
        continue;
      }
      if (row.lane!.spans.isEmpty) {
        // The empty note has room in the chart, beside its named lane.
        // Appending it to the sticky column clipped it on a phone.
        final note = StripPaintTextCache.layout(
          text: stripStrings['stripEmptyLane']?[locale] ??
              stripStrings['stripEmptyLane']!['en']!,
          style: canvasTextStyle(fontSize: laneFontPx, color: wb.mutedText),
          maxWidth: math.max(0, x1 - x0 - 16),
          ellipsis: '…',
        );
        note.paint(
            canvas, Offset(x0 + 8, row.top + (row.height - note.height) / 2));
        continue;
      }
      canvas.drawLine(
        Offset(x0, row.top + row.height / 2),
        Offset(x1, row.top + row.height / 2),
        Paint()
          ..strokeWidth = 0.5
          ..color = wb.border.withValues(alpha: 0.36),
      );
    }
  }

  /// Duration keeps its exact x extent. The 68% fill leaves 32% of the
  /// row as breathing room, while a pale interior lets the theme's own
  /// text colour carry the name on both light and dark backgrounds.
  /// A border retains the stream colour without a wall of saturated ink.
  void _paintFilledBars(Canvas canvas) {
    for (final row in rows) {
      if (!_rowVisible(row) || row.isHeading) continue;
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
    if (!_spanVisible(x0, x1)) return;
    final color = _spanColor(span, lane, palette);
    final sel = span.id == selectedId;
    final lit = selectionCovers(
      selectedId: selectedId,
      ownId: span.id,
      streamId: _streamIdFor(span, lane, palette),
    );
    final dim = selectedId != null && !lit ? 0.35 : 1.0;
    final fillHeight = row.height * 0.68;
    final top = row.top + (row.height - fillHeight) / 2;

    if (x1 - x0 < 0.01) {
      // Rule 1: a zero-length reign keeps its ink — a dot, never a
      // widened bar. Verbatim from the wheel's own dot, `_paintLife
      // spans`' "nameless arc" branch: it is the same mechanism this
      // spec's zero-length example (Zimri, Huldah, Ahaziah of Judah,
      // Jehoahaz of Judah) names.
      final dot = math.min(1.6, fillHeight * 0.28);
      canvas.drawCircle(
        Offset(x0, _rowFor(span, row)),
        dot,
        Paint()
          ..color = color.withValues(alpha: (0.78 * dim * 2.6).clamp(0.0, 1.0)),
      );
      // 「就放在那个线或者窄框框后面」 — a zero-length reign is the
      // narrowest case of all, and it is the one a reader is most
      // likely to want named.
      _paintBarName(canvas, span, lane, row, x0, x0 + dot, dim);
      return;
    }

    final shape = RRect.fromRectAndRadius(
      Rect.fromLTRB(x0, top, x1, top + fillHeight),
      Radius.circular(math.min(
          WbMetrics.radiusControl, math.min((x1 - x0) / 2, fillHeight / 2))),
    );
    canvas.drawRRect(
      shape,
      Paint()..color = color.withValues(alpha: (sel ? 0.24 : 0.12) * dim),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sel ? 1.5 : 0.8
        ..color = color.withValues(alpha: (sel ? 0.95 : 0.55) * dim),
    );

    _paintBarName(canvas, span, lane, row, x0, x1, dim);
  }

  void _paintBarName(Canvas canvas, StripSpan span, StripLane lane,
      StripRow row, double x0, double x1, double dim,
      {double alpha = 0.98}) {
    final placed =
        _barLabel(span, lane, palette.spanLabel[span.id] ?? '', x0, x1);
    if (placed == null) return;
    final tp = StripPaintTextCache.layout(
      text: placed.text,
      style: canvasTextStyle(
          fontSize: laneFontPx,
          // A name standing beside its bar rather than on it is a
          // little quieter, so the eye still reads the bars first.
          color: wb.text
              .withValues(alpha: (placed.after ? alpha * 0.8 : alpha) * dim)),
    );
    tp.paint(canvas, Offset(placed.x, _rowFor(span, row) - tp.height / 2));
  }

  /// The Genesis lifespans — §3.3, descended from the wheel's
  /// `_paintLifespans`: a thinner stroke, its own softer alpha ladder,
  /// tick hairlines in the span's own colour, no selection-outline
  /// rectangle (the cross-hair, painted last, is what marks a selected
  /// life on this axis).
  void _paintLifespans(Canvas canvas) {
    for (final row in rows) {
      if (!_rowVisible(row) ||
          row.isHeading ||
          row.lane!.kind != StripLaneKind.lives) {
        continue;
      }
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
    if (!_spanVisible(x0, x1)) return;
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
    final placed = _barLabel(span, lane, name, x0, x1);
    if (placed == null) return;
    final tp = StripPaintTextCache.layout(
      text: placed.text,
      style: canvasTextStyle(
          fontSize: laneFontPx,
          color: wb.text.withValues(
              alpha: (has && !sel ? 0.45 : 0.95) * (placed.after ? 0.8 : 1.0))),
    );
    tp.paint(canvas, Offset(placed.x, y - tp.height / 2));
  }

  /// The genealogy rail — §3.4, descended from the wheel's own
  /// `_paintRail`. A tick, not a bar: a birth year is a point, and none
  /// of these people has a death year the tree is willing to state, the
  /// same reason the wheel draws a mark rather than a span here.
  void _paintRail(Canvas canvas) {
    for (final row in rows) {
      if (!_rowVisible(row) ||
          row.isHeading ||
          row.lane!.kind != StripLaneKind.rail) {
        continue;
      }
      final lane = row.lane!;
      for (final span in lane.spans) {
        _paintOneRailTick(canvas, span, lane, row);
      }
    }
  }

  void _paintOneRailTick(
      Canvas canvas, StripSpan span, StripLane lane, StripRow row) {
    final x = xForYear(span.startYear, pxPerYear);
    if (!_spanVisible(x, x)) return;
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

  /// A card is a callout whose printed range and lower anchor line
  /// identify its date extent. Width is reading space, never duration.
  /// The complete title wraps; the reference and source remain in the
  /// detail sheet reached by the card's explicit action.
  void _paintEvents(Canvas canvas) {
    for (final row in rows) {
      if (!_rowVisible(row) || row.eventCards.isEmpty) continue;
      for (var i = 0; i < row.eventCards.length; i++) {
        final card = row.eventCards[i];
        final bounds = is3D ? row.depthShapes[i].bounds : null;
        if (!_spanVisible(
            bounds?.left ?? card.x, bounds?.right ?? card.x + card.width)) {
          continue;
        }
        _paintEventCard(canvas, row, card);
      }
    }
  }

  void _paintEventCard(Canvas canvas, StripRow row, StripEventCard card) {
    final selected = card.events.any((event) => event.id == selectedId);
    final accent = card.isGroup
        ? wb.link
        : palette.streamColors[card.events.single.stream] ?? wb.link;
    final rect = Rect.fromLTWH(card.x, row.top + 8, card.width, card.height);
    final radius = Radius.circular(WbMetrics.radiusControl + 2);
    final shape = RRect.fromRectAndRadius(rect, radius);
    if (is3D) {
      final depth = row.depthShapes
          .firstWhere((shape) => shape.id == card.events.first.id);
      _paintPrism(canvas, depth, accent, selected: selected);
    } else {
      // An offset backplate supplies a quiet raised edge without a
      // blurred shadow or a texture beneath every line of text.
      canvas.drawRRect(shape.shift(const Offset(0, 3)),
          Paint()..color = wb.text.withValues(alpha: .06));
      canvas.drawRRect(shape, Paint()..color = wb.paneBg);
      canvas.drawRRect(shape, Paint()..color = accent.withValues(alpha: .045));
      canvas.drawRRect(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 1.8 : .8
            ..color = (selected ? accent : wb.text)
                .withValues(alpha: selected ? .9 : .18));
    }
    final titleSize = stripEventCardTitleSize(laneFontPx);
    final metaSize = stripEventCardMetaSize(laneFontPx);
    var y = rect.top + 12;
    void line(String text, double size, Color color, {bool bold = false}) {
      final paragraph = StripPaintTextCache.layout(
        text: text,
        style: canvasTextStyle(
            fontSize: size,
            color: color,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
        maxWidth: card.width - 24,
        maxLines: null,
      );
      paragraph.paint(canvas, Offset(rect.left + 12, y));
    }

    line(card.title, titleSize, wb.text, bold: true);
    y += card.titleHeight + 6;
    line(card.dates, metaSize, wb.mutedText);
    y += card.datesHeight;
    if (card.isGroup) {
      final maximum = card.density.reduce(math.max);
      final binWidth = (card.width - 24) / card.density.length;
      for (var i = 0; i < card.density.length; i++) {
        if (card.density[i] == 0) continue;
        final height = 3 + 9 * card.density[i] / maximum;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(rect.left + 12 + i * binWidth, y + 16 - height,
                    math.max(1, binWidth - 2), height),
                const Radius.circular(WbMetrics.radiusControl / 4)),
            Paint()..color = accent.withValues(alpha: .55));
      }
      y += 22;
    } else {
      y += 8;
    }
    line(card.action, metaSize, wb.link);

    final firstX = xForYear(card.firstYear, pxPerYear);
    final lastX = xForYear(card.lastYear, pxPerYear);
    final anchorY = rect.bottom + 10;
    final anchor = Paint()
      ..color = accent.withValues(alpha: .65)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(firstX, anchorY), Offset(lastX, anchorY), anchor);
    canvas.drawLine(Offset((firstX + lastX) / 2, rect.bottom),
        Offset((firstX + lastX) / 2, anchorY), anchor);
    canvas.drawCircle(Offset(firstX, anchorY), 2, anchor);
    if (firstX != lastX) canvas.drawCircle(Offset(lastX, anchorY), 2, anchor);
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
      if (!_spanVisible(x, x)) continue;
      canvas.drawLine(Offset(x, math.max(0, visibleY0)),
          Offset(x, math.min(totalHeight, visibleY1)), paint);
    }
  }

  @override
  bool shouldRepaint(StripLanesPainter old) =>
      old.is3D != is3D ||
      old.rows != rows ||
      old.wb != wb ||
      old.palette != palette ||
      old.visibleY0 != visibleY0 ||
      old.visibleY1 != visibleY1 ||
      old.pxPerYear != pxPerYear ||
      old.locale != locale ||
      old.selectedId != selectedId ||
      old.laneFontPx != laneFontPx ||
      old.visibleX0 != visibleX0 ||
      old.visibleX1 != visibleX1 ||
      old.contentWidth != contentWidth ||
      old.contentHeight != contentHeight;
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
    this.visibleX0 = 0,
    this.visibleX1 = double.infinity,
  });

  final double pxPerYear;
  final String locale;
  final WbColors wb;

  /// `WbType.scaledChrome(11)` — §7.3: the ruler stays on the Menu Size
  /// scale, unlike lane content, because its own row height is not
  /// committed to `textScale` by anything.
  final double tickFontPx;

  /// The visible content window. Since 2026-09-15 the canvas is the
  /// VIEWPORT rather than the whole timeline (see [StripLanesPainter.
  /// contentWidth] for why), so [visibleX0] is also the origin this
  /// painter translates by. Its HEIGHT is unaffected — the ruler was
  /// always exactly one row tall — which is why there is no
  /// `contentHeight` here.
  final double visibleX0;
  final double visibleX1;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(-visibleX0, 0);
    final step = rulerStep(pxPerYear);
    // A tick label is at most the longer localized endpoint. An em per
    // character deliberately overestimates Latin and retains labels
    // whose centres have just left the viewport.
    final labelPadding = math.max(yearLabel(kStripMinYear, locale).length,
            yearLabel(kStripMaxYear, locale).length) *
        tickFontPx;
    bool visible(double x) => stripPaintIntersects(
          start: x,
          end: x,
          visibleStart: visibleX0,
          visibleEnd: visibleX1,
          padding: labelPadding,
        );
    final minor = Paint()
      ..color = wb.border.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    final major = Paint()
      ..color = wb.border.withValues(alpha: 0.5)
      ..strokeWidth = 0.9;
    var previousLabelEnd = double.negativeInfinity;
    for (final year in rulerTicks(step)) {
      final x = xForYear(year, pxPerYear);
      if (!visible(x)) continue;
      final isMajor = year % 500 == 0;
      canvas.drawLine(Offset(x, size.height * 0.45), Offset(x, size.height),
          isMajor ? major : minor);
      final tp = StripPaintTextCache.layout(
        text: centuryTickLabel(year, locale),
        style: canvasTextStyle(fontSize: tickFontPx, color: wb.mutedText),
      );
      final labelX = x - tp.width / 2;
      // The nice-step ladder is chosen before the locale and actual
      // glyph widths are known. At whole-history fit or large type it
      // can still crowd words, so keep every tick but skip a label
      // that cannot clear the previous one. Both axis ends remain on
      // their own lower row, and tapping any tick reads its exact year.
      if (stripPaintLabelFits(
        labelStart: labelX,
        previousLabelEnd: previousLabelEnd,
      )) {
        tp.paint(canvas, Offset(labelX, 2));
        previousLabelEnd = labelX + tp.width;
      }
    }

    // The two axis ends, brighter — "these two say what the chart's
    // range IS," the wheel's own `_paintAxisEnds` reasoning, unchanged.
    void end(int year, double x, TextAlign align) {
      if (!visible(x)) return;
      final tp = StripPaintTextCache.layout(
        text: yearLabel(year, locale),
        style: canvasTextStyle(
            fontSize: tickFontPx, color: wb.text, fontWeight: FontWeight.w600),
      );
      final dx = align == TextAlign.left ? x : x - tp.width;
      tp.paint(canvas, Offset(dx, size.height - tp.height - 1));
    }

    end(kStripMinYear, 0, TextAlign.left);
    // `stripContentWidth`, not `size.width`. They were the same number
    // while this painter's canvas WAS the whole timeline; since
    // 2026-09-15 the canvas is the viewport, and the last year belongs
    // at the end of the strip rather than at the right edge of whatever
    // happens to be on screen. The two are the same function —
    // `stripContentWidth` is defined as `xForYear(kStripMaxYear)` — so
    // this is the identity that was always meant, spelled out.
    end(kStripMaxYear, stripContentWidth(pxPerYear), TextAlign.right);
  }

  @override
  bool shouldRepaint(StripRulerPainter old) =>
      old.pxPerYear != pxPerYear ||
      old.locale != locale ||
      old.wb != wb ||
      old.tickFontPx != tickFontPx ||
      old.visibleX0 != visibleX0 ||
      old.visibleX1 != visibleX1;
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
    required this.symbols,
    this.visibleY0 = 0,
    this.visibleY1 = double.infinity,
  });

  final List<StripRow> rows;
  final String locale;
  final WbColors wb;
  final double laneFontPx;
  final double headingFontPx;
  final StripPalette palette;

  /// The stream silhouettes, empty until they decode.
  final Map<String, ui.Image> symbols;
  final double visibleY0;
  final double visibleY1;

  static const double _padding = 8;

  @override
  void paint(Canvas canvas, Size size) {
    // Content space on a viewport-sized canvas — see
    // [StripLanesPainter.contentWidth]. This column is only as tall as
    // the strip, never as wide, so it is the vertical axis that had to
    // stop being the canvas; `size.width` below is still the column's
    // real width and stays as it is.
    canvas.translate(0, -visibleY0);
    for (final row in rows) {
      if (!stripPaintIntersects(
        start: row.top,
        end: row.top + row.height,
        visibleStart: visibleY0,
        visibleEnd: visibleY1,
      )) {
        continue;
      }
      if (row.isHeading) {
        canvas.drawRect(
          Rect.fromLTWH(0, row.top, size.width, row.height),
          Paint()..color = wb.paneAltBg,
        );
        final text = stripStrings[row.headingKey]?[locale] ??
            stripStrings[row.headingKey]!['en']!;
        // `maxWidth` and an ellipsis, because `layout()` with neither
        // lays the heading out at its natural width and paints it from
        // `_padding` regardless — the canvas edge then cuts it mid-
        // glyph, which is how 犹大与以色列列王 reached a phone reader as
        // 犹大与以色列列3. The wider clamp in `stripHeaderColumnWidth`
        // is what actually makes the headings fit at 375; this is the
        // net under it, so no future heading, locale or font size can
        // put a half-drawn character on the screen again.
        final tp = StripPaintTextCache.layout(
          text: text,
          style: canvasTextStyle(
              fontSize: headingFontPx,
              color: wb.text,
              fontWeight: FontWeight.w600),
          ellipsis: '…',
          maxWidth: math.max(0, size.width - _padding * 2),
        );
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
      final color = (palette.streamColors[lane.ownerId] ??
              lineColor('none', dark: palette.dark))
          .withValues(alpha: 0.98);
      final tp = StripPaintTextCache.layout(
        text: name,
        style: canvasTextStyle(
            fontSize: laneFontPx, color: wb.text, fontWeight: FontWeight.w500),
        maxWidth: math.max(0, size.width - _padding * 2 - 8),
        ellipsis: '…',
      );
      // THE SAME MARK THE WHEEL DRAWS, where the wheel puts it on the
      // ring. 「包括strip 加label」 — and the point is that the two charts
      // identify a stream the same way, so a reader who learned the
      // crown on one does not have to learn a dot on the other.
      //
      // A stream with no symbol keeps the dot, exactly as it keeps the
      // plain chip in the filter: three of them are left out of the
      // table on purpose.
      final symbol = symbols[symbolForStream(lane.ownerId ?? '')];
      final mid = row.top + row.height / 2;
      if (symbol == null) {
        canvas.drawCircle(Offset(_padding + 2, mid), 2, Paint()..color = color);
      } else {
        final box = Rect.fromCenter(
            center: Offset(_padding + 3, mid),
            width: laneFontPx * 1.1,
            height: laneFontPx * 1.1);
        canvas.drawImageRect(
          symbol,
          Rect.fromLTWH(
              0, 0, symbol.width.toDouble(), symbol.height.toDouble()),
          box,
          Paint()
            ..isAntiAlias = true
            ..filterQuality = FilterQuality.medium
            ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
        );
      }
      tp.paint(canvas,
          Offset(_padding + 10, row.top + (row.height - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(StripLaneHeaderPainter old) =>
      old.rows != rows ||
      old.locale != locale ||
      old.wb != wb ||
      old.symbols != symbols ||
      old.palette != palette ||
      old.visibleY0 != visibleY0 ||
      old.visibleY1 != visibleY1 ||
      old.laneFontPx != laneFontPx ||
      old.headingFontPx != headingFontPx;
}
