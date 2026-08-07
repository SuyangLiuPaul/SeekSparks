/// 2026-08-08 (SeekSparks): the passage map.
///
/// This is the half of the Places feature that a 320 px column cannot
/// do. The Analysis tab answers *which* places a passage names; a list
/// can do that. It cannot answer *where*, and "where" is most of what
/// coordinates are for — that Joppa and Nineveh sit at opposite ends of
/// the known world is the entire narrative premise of Jonah, and no list
/// of two names will ever say it.
///
/// So the map takes the centre pane, where there is room for it, and it
/// is deliberately **not** a fourth `WbCentreMode`. The three centre
/// modes are persisted, and a persisted map mode would mean an app that
/// reopens onto a coastline instead of onto scripture. This is a lens
/// the reader holds up and puts down: opened from the Places tab, closed
/// back to whatever text mode was underneath.
library;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';

import 'package:seeksparks/constants/book_name_mapping.dart' show BookScript;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/place_geo.dart';

/// The passage map: base geography, the places the passage names, and a
/// ruler between them.
class PlaceMapView extends StatefulWidget {
  const PlaceMapView({
    super.key,
    required this.title,
    required this.inVerse,
    required this.inChapter,
    required this.baseMap,
    required this.script,
    required this.locale,
    required this.selectedId,
    required this.onSelect,
    required this.onClose,
    this.attribution = '',
  });

  /// The reference this map is of — printed in the header so a map
  /// detached from the text still says what it is a map of.
  final String title;

  /// Places named in the focused verse. Drawn emphasised.
  final List<BiblePlace> inVerse;

  /// Places named elsewhere in the chapter. Drawn muted, because they
  /// are context rather than the subject.
  final List<BiblePlace> inChapter;

  final BaseMap baseMap;
  final BookScript script;
  final String locale;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onClose;
  final String attribution;

  @override
  State<PlaceMapView> createState() => _PlaceMapViewState();
}

class _PlaceMapViewState extends State<PlaceMapView> {
  /// Null until the pane has been measured — the projection depends on
  /// the size it is drawn into, so it cannot be built in `initState`.
  MapProjection? _proj;
  Size _size = Size.zero;

  /// Set when the reader pans or zooms. Until then the projection
  /// re-fits itself as the passage changes; afterwards it stays where
  /// they put it, because silently yanking the view back to a default
  /// is the fastest way to make a map feel broken.
  bool _touched = false;

  double? _scaleStartPpd;
  Offset? _panStart;
  double? _panStartLat;
  double? _panStartLon;

  List<BiblePlace> get _located => <BiblePlace>[
        for (final p in widget.inVerse)
          if (p.located) p,
        for (final p in widget.inChapter)
          if (p.located) p,
      ];

  int get _unlocatedCount =>
      widget.inVerse.where((p) => !p.located).length +
      widget.inChapter.where((p) => !p.located).length;

  @override
  void didUpdateWidget(PlaceMapView old) {
    super.didUpdateWidget(old);
    if (old.inVerse != widget.inVerse || old.inChapter != widget.inChapter) {
      _touched = false;
      _proj = null;
    }
  }

  /// Fit the passage, or fall back to the Levant.
  ///
  /// The fallback matters: a chapter can name only unlocated places, and
  /// an empty bounding box would otherwise project at infinite zoom and
  /// paint a blank pane that looks like a crash.
  MapProjection _fitted(Size size) {
    final pts = <(double, double)>[
      for (final p in _located) (p.lat!, p.lon!),
    ];
    final bounds = boundsOf(pts)?.padded() ??
        const GeoBounds(29.0, 32.0, 35.0, 39.0);
    return MapProjection.fit(bounds, size);
  }

  MapProjection _projectionFor(Size size) {
    if (_proj == null || _size != size) {
      final next = _proj == null
          ? _fitted(size)
          : _proj!.copyWith(size: size);
      _proj = next;
      _size = size;
      // The projection can only be built once the pane has been
      // measured, which happens AFTER the footer is built — so the scale
      // bar would otherwise stay blank until some unrelated rebuild.
      // One extra frame on open, and only on open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    return _proj!;
  }

  void _zoomBy(double factor, Offset focal) {
    final p = _proj;
    if (p == null) return;
    final (lat, lon) = p.unproject(focal);
    final next = p.copyWith(
      pixelsPerDegreeLat: (p.pixelsPerDegreeLat * factor).clamp(0.6, 8000.0),
    );
    // Keep the point under the cursor under the cursor — the difference
    // between zooming a map and rescaling a picture.
    final after = next.project(lat, lon);
    final moved = next.copyWith(
      centreLat: next.centreLat + (after.dy - focal.dy) / next.pixelsPerDegreeLat,
      centreLon: next.centreLon - (after.dx - focal.dx) / _lonScaleOf(next),
    );
    setState(() {
      _touched = true;
      _proj = moved;
    });
  }

  static double _lonScaleOf(MapProjection p) =>
      p.project(p.centreLat, p.centreLon + 1).dx -
      p.project(p.centreLat, p.centreLon).dx;

  void _tapAt(Offset local) {
    final p = _proj;
    if (p == null) return;
    BiblePlace? best;
    var bestD = 22.0;
    for (final place in _located) {
      final o = p.project(place.lat!, place.lon!);
      final d = (o - local).distance;
      if (d < bestD) {
        bestD = d;
        best = place;
      }
    }
    // Tapping empty water clears the selection rather than keeping a
    // marker lit that the reader has visibly moved away from.
    widget.onSelect(best?.id);
  }

  BiblePlace? get _selected {
    final id = widget.selectedId;
    if (id == null) return null;
    for (final p in _located) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    return ColoredBox(
      color: c.paneBg,
      child: Column(
        children: [
          _header(context, c, t),
          Divider(height: WbMetrics.hairline, color: c.border),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                if (size.width < 8 || size.height < 8) {
                  return const SizedBox.shrink();
                }
                final proj = _projectionFor(size);
                return Listener(
                  onPointerSignal: (s) {
                    if (s is PointerScrollEvent) {
                      _zoomBy(s.scrollDelta.dy > 0 ? 0.88 : 1.14, s.localPosition);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _tapAt(d.localPosition),
                    onScaleStart: (d) {
                      _scaleStartPpd = proj.pixelsPerDegreeLat;
                      _panStart = d.localFocalPoint;
                      _panStartLat = proj.centreLat;
                      _panStartLon = proj.centreLon;
                    },
                    onScaleUpdate: (d) {
                      final base = _scaleStartPpd;
                      final start = _panStart;
                      if (base == null || start == null) return;
                      final zoomed = proj.copyWith(
                        pixelsPerDegreeLat:
                            (base * d.scale).clamp(0.6, 8000.0),
                      );
                      final dx = d.localFocalPoint.dx - start.dx;
                      final dy = d.localFocalPoint.dy - start.dy;
                      setState(() {
                        _touched = true;
                        _proj = zoomed.copyWith(
                          centreLat: _panStartLat! +
                              dy / zoomed.pixelsPerDegreeLat,
                          centreLon: _panStartLon! - dx / _lonScaleOf(zoomed),
                        );
                      });
                    },
                    child: CustomPaint(
                      size: size,
                      painter: _MapPainter(
                        base: widget.baseMap,
                        inVerse: widget.inVerse,
                        inChapter: widget.inChapter,
                        selectedId: widget.selectedId,
                        projection: proj,
                        script: widget.script,
                        colors: c,
                        labelSize: t.chrome,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(height: WbMetrics.hairline, color: c.border),
          _footer(context, c, t),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, WbColors c, WbType t) {
    final s = _mapString;
    return Container(
      height: t.paneTitleHeight + 4,
      color: c.chromeBg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(Icons.public, size: t.chrome + 2, color: c.mutedText),
          const SizedBox(width: 6),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: t.chrome,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              s('placesMapHint', 'Scroll to zoom, drag to pan.'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: t.chrome - 1.5, color: c.mutedText),
            ),
          ),
          const SizedBox(width: 8),
          if (_touched) ...[
            _flatButton(
              context,
              c,
              t,
              s('placesMapFit', 'Fit'),
              () => setState(() {
                _touched = false;
                _proj = _fitted(_size);
              }),
            ),
            const SizedBox(width: 4),
          ],
          _flatButton(
            context,
            c,
            t,
            s('placesMapClose', 'Close map'),
            widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _flatButton(BuildContext context, WbColors c, WbType t, String label,
          VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: c.border, width: WbMetrics.hairline),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: t.chrome - 0.5, color: c.text),
          ),
        ),
      );

  /// Scale bar, ruler readout, the unlocated count, and the credits.
  ///
  /// The ruler is BibleWorks' idea (bwh33's Travel Speed Window) turned
  /// verse-linked: BibleWorks makes you draw a line between two points
  /// you chose, this measures from the selected place to the others the
  /// passage itself names, which is the comparison the text is already
  /// asking for.
  Widget _footer(BuildContext context, WbColors c, WbType t) {
    final s = _mapString;
    final proj = _proj;
    final sel = _selected;
    final km = proj == null ? null : niceScaleKm(proj.kmPerPixel, 90);
    final barPx = (proj == null || km == null) ? 0.0 : km / proj.kmPerPixel;

    final others = <(BiblePlace, double)>[];
    if (sel != null) {
      for (final p in _located) {
        if (p.id == sel.id) continue;
        final d = sel.distanceKmTo(p);
        if (d != null) others.add((p, d));
      }
      others.sort((a, b) => a.$2.compareTo(b.$2));
    }

    return Container(
      color: c.chromeBg,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (km != null) ...[
                Container(
                  width: barPx.clamp(10.0, 260.0),
                  height: 5,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: c.text, width: 1),
                      right: BorderSide(color: c.text, width: 1),
                      bottom: BorderSide(color: c.text, width: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  km >= 1 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km',
                  style: TextStyle(fontSize: t.chrome - 1, color: c.mutedText),
                ),
              ],
              const Spacer(),
              if (_unlocatedCount > 0)
                Flexible(
                  child: Text(
                    s('placesMapUnlocatedCount',
                            '{n} more named here have no known location')
                        .replaceAll('{n}', '$_unlocatedCount'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: t.chrome - 1, color: c.mutedText),
                  ),
                ),
            ],
          ),
          if (sel != null && others.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              // The ruler. Nearest three, because a chapter can name a
              // dozen places and the far end of that list is noise.
              others.take(3).map((e) {
                final name = e.$1.displayName(widget.script);
                final days = s('placesMapDays', 'about {n} days on foot')
                    .replaceAll('{n}', '${daysOnFootFor(e.$2)}');
                return '${sel.displayName(widget.script)} → $name  '
                    '${e.$2.round()} km · $days';
              }).join('    '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.chrome - 1,
                color: c.text,
                height: 1.35,
              ),
            ),
          ],
          if (widget.attribution.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              widget.attribution,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.chrome - 2,
                color: c.mutedText,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _mapString(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;
}

/// Draws the base geography and the passage's markers.
class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.base,
    required this.inVerse,
    required this.inChapter,
    required this.selectedId,
    required this.projection,
    required this.script,
    required this.colors,
    required this.labelSize,
  });

  final BaseMap base;
  final List<BiblePlace> inVerse;
  final List<BiblePlace> inChapter;
  final String? selectedId;
  final MapProjection projection;
  final BookScript script;
  final WbColors colors;
  final double labelSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    // Cleared per frame, not per painter: a painter instance can be
    // asked to paint more than once, and a stale claim list would make
    // labels disappear on the second frame.
    _claimed.clear();
    // Water is the ground, land is drawn on top of it. The other way
    // round would need a polygon for every sea.
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.paneAltBg);

    final land = Paint()
      ..style = PaintingStyle.fill
      ..color = colors.paneBg;
    final coast = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = colors.border;
    final water = Paint()
      ..style = PaintingStyle.fill
      ..color = colors.paneAltBg;
    final river = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = colors.mutedText.withValues(alpha: 0.55);

    for (final run in base.land) {
      canvas.drawPath(_path(run, close: true), land);
    }
    for (final run in base.lakes) {
      canvas.drawPath(_path(run, close: true), water);
    }
    for (final run in base.coast) {
      canvas.drawPath(_path(run), coast);
    }
    for (final run in base.rivers) {
      canvas.drawPath(_path(run), river);
    }

    // Chapter context first, so the verse's own places are never
    // painted over by their background.
    _markers(canvas, size, inChapter, emphasised: false);
    _markers(canvas, size, inVerse, emphasised: true);
  }

  Path _path(List<double> run, {bool close = false}) {
    final path = Path();
    for (var i = 0; i + 1 < run.length; i += 2) {
      // The asset stores longitude first — it is GeoJSON order, and the
      // gazetteer's own `ll` is the other way round, which is exactly
      // the kind of thing that silently mirrors a map.
      final o = projection.project(run[i + 1], run[i]);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    if (close) path.close();
    return path;
  }

  /// Label rectangles already claimed, so labels do not overprint.
  final List<Rect> _claimed = <Rect>[];

  void _markers(Canvas canvas, Size size, List<BiblePlace> places,
      {required bool emphasised}) {
    for (final p in places) {
      if (!p.located) continue;
      final o = projection.project(p.lat!, p.lon!);
      if (o.dx < -40 || o.dy < -40 || o.dx > size.width + 40 ||
          o.dy > size.height + 40) {
        continue;
      }
      final isSel = p.id == selectedId;
      final r = isSel ? 5.0 : (emphasised ? 3.5 : 2.5);
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = isSel
            ? colors.link
            : (emphasised ? colors.text : colors.mutedText);

      // A ring under the dot lifts it off a busy coastline without
      // needing a shadow, which the workbench does not use.
      canvas.drawCircle(
          o, r + 1.6, Paint()..color = colors.paneBg.withValues(alpha: 0.9));
      canvas.drawCircle(o, r, fill);

      final label = p.displayName(script);
      if (label.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: p.ordinal == null ? label : '$label ${p.ordinal}',
          style: TextStyle(
            fontSize: emphasised || isSel ? labelSize : labelSize - 1,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel ? colors.link : colors.text,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      final at = Offset(o.dx + r + 3, o.dy - tp.height / 2);
      final rect = Rect.fromLTWH(at.dx - 1, at.dy, tp.width + 2, tp.height);
      // Unlabelled beats overprinted: two names stacked on each other
      // are less readable than one name and a bare dot.
      if (!isSel && _claimed.any((q) => q.overlaps(rect))) continue;
      _claimed.add(rect);

      canvas.drawRect(
          rect, Paint()..color = colors.paneBg.withValues(alpha: 0.72));
      tp.paint(canvas, at);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.projection.centreLat != projection.centreLat ||
      old.projection.centreLon != projection.centreLon ||
      old.projection.pixelsPerDegreeLat != projection.pixelsPerDegreeLat ||
      old.projection.size != projection.size ||
      old.selectedId != selectedId ||
      old.inVerse != inVerse ||
      old.inChapter != inChapter ||
      old.script != script;
}
