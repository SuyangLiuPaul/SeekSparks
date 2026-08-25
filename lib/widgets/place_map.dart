/// 2026-08-08 (SeekSparks): the map canvas.
///
/// This is the half of the Places feature that a 320 px column cannot
/// do. The Analysis tab answers *which* places a passage names; a list
/// can do that. It cannot answer *where*, and "where" is most of what
/// coordinates are for — that Joppa and Nineveh sit at opposite ends of
/// the known world is the entire narrative premise of Jonah, and no list
/// of two names will ever say it.
///
/// 2026-08-09: it shipped as a lens over the workbench's centre pane and
/// now has exactly one host, `AtlasPage` — the user's decision on
/// DELETION-REVIEW §4 is that there is **one** map surface and it opens
/// from Resources, the shape `bwh07` files maps under too. So the two
/// place lists are named for what they do to the drawing rather than for
/// where a passage put them: [emphasised] is whatever the reader is
/// asking about (a passage's places, or a search's hits), [muted] is the
/// geography around it.
///
/// The view is driven by two tokens rather than by comparing the lists
/// it was handed. A host that rebuilds — and this one rebuilds on every
/// keystroke — hands over fresh list instances every time, so an identity
/// check would re-fit the map out from under a reader mid-pan. The host
/// says when to re-fit ([fitToken]) and when to recentre ([focusToken]),
/// and says nothing the rest of the time.
library;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';

import 'package:seeksparks/constants/book_name_mapping.dart' show BookScript;
import 'package:seeksparks/constants/journey_style.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/atlas_index.dart' show labelPriority;
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/journey_route.dart';
import 'package:seeksparks/utils/place_geo.dart';
import 'package:seeksparks/utils/travel_time.dart';

/// Base geography, the places asked about, and a ruler between them.
class PlaceMapView extends StatefulWidget {
  const PlaceMapView({
    super.key,
    required this.title,
    required this.emphasised,
    required this.muted,
    required this.baseMap,
    required this.script,
    required this.locale,
    required this.selectedId,
    required this.onSelect,
    this.onClose,
    this.showContext = true,
    this.onToggleContext,
    this.routes = const <ResolvedJourney>[],
    this.selectedRouteId,
    this.selectedLeg,
    this.onSelectLeg,
    this.fitToken = 0,
    this.focusToken = 0,
    this.fitPoints,
    this.attribution = '',
  });

  /// What this map is of — printed in the header so a map detached from
  /// the text still says what it is showing.
  final String title;

  /// What the reader asked about: the passage's places, or a search's
  /// hits. Drawn larger, labelled first, and what the map fits itself to.
  final List<BiblePlace> emphasised;

  /// Everything the host's current question left out. Drawn small and
  /// labelled faint, and only when [showContext].
  ///
  /// **Not "the geography around it", which is what this used to claim.**
  /// The Atlas hands over the exact complement of its own filter — the
  /// index applies no cap — so under a scope of Obadiah this list is the
  /// 1,259 places Obadiah never names. Drawing them by default is how
  /// the map came to disagree with the list beside it (#319).
  final List<BiblePlace> muted;

  final BaseMap baseMap;
  final BookScript script;
  final String locale;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  /// Absent when the map is the surface rather than a lens over one.
  final VoidCallback? onClose;

  /// Whether [muted] is drawn at all.
  ///
  /// bwh33's own model: every layer of a BibleWorks map is an overlay
  /// with a check-box, and its 66 per-book views draw that book's sites
  /// rather than the whole database dimmed. A filtered map that quietly
  /// keeps drawing what the filter removed is not a dimmer version of
  /// the answer, it is a different answer.
  final bool showContext;

  /// Flips [showContext]. Null hides the control — as it should be when
  /// [muted] is empty, because with no filter there is nothing to leave
  /// out and a toggle that changes nothing is chrome.
  final VoidCallback? onToggleContext;

  /// Bump to re-fit the view to [emphasised] (or to [muted] when nothing
  /// is emphasised). The host bumps it when the *question* changes — a
  /// new search, a new scope — and not when the answer is merely
  /// re-rendered.
  /// The journeys currently switched on, in draw order.
  ///
  /// An OVERLAY in bwh33's sense — a transparent sheet stacked over the
  /// map, not a filter on it. So a route draws its own stops whether or
  /// not the index's filter kept them: #319's rule is that the map must
  /// not quietly redraw what a filter removed, and a layer the reader
  /// switched on by name is not quiet.
  final List<ResolvedJourney> routes;

  /// The one being read. The others are held back rather than hidden, so
  /// a crossing can still be seen for what it is.
  final String? selectedRouteId;

  /// The single leg the reader is asking about, as a route id and an index
  /// into that route's segments. Drawn with a halo and nothing else.
  final ({String routeId, int index})? selectedLeg;

  /// Called when a tap lands on a leg rather than on a place.
  ///
  /// Null leaves the lines inert, which is what every host but the Atlas
  /// wants: a map embedded as a lens over a passage has nowhere to put an
  /// itinerary, and a line that lights up with no panel to explain it is
  /// the dead end #319 was about.
  final void Function(({String routeId, int index}))? onSelectLeg;

  final int fitToken;

  /// What the next fit should frame, when the host knows better than the
  /// layers do — the stops of a journey just switched on, normally.
  ///
  /// Null hands the decision back to [emphasised] and [muted]. It has to
  /// be the host's call because only the host knows which question
  /// changed: with no search running the Atlas emphasises the entire
  /// gazetteer, and fitting that would answer a route toggle with a view
  /// of three continents.
  final List<(double, double)>? fitPoints;

  /// Bump to bring [selectedId] into view without otherwise disturbing
  /// the reader's pan and zoom.
  ///
  /// Separate from the selection itself because the two directions are
  /// not symmetric: picking a name out of the index means "show me where
  /// this is", while tapping a dot on the map means "tell me about the
  /// thing already under my finger" — and recentring on the second would
  /// snatch the map away from the point that was just clicked.
  final int focusToken;

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

  /// The context layer as far as the rest of this widget is concerned.
  ///
  /// One getter rather than a check at each site on purpose: hiding a
  /// layer that is still hit-tested gives an invisible dot that answers
  /// a tap, and a layer that is still counted makes the footer describe
  /// places the reader cannot see.
  List<BiblePlace> get _context =>
      widget.showContext ? widget.muted : const <BiblePlace>[];

  /// Every place an active route stops at, first appearance first.
  ///
  /// Deduplicated across routes as well as within one: Syrian Antioch
  /// opens and closes both of the shipped journeys.
  List<BiblePlace> get _routePlaces {
    final seen = <String>{};
    return <BiblePlace>[
      for (final r in widget.routes)
        for (final m in r.markers)
          if (seen.add(m.place.id)) m.place,
    ];
  }

  /// Everything drawn and locatable, each place once.
  ///
  /// Deduplicated because a route's stops overlap the layers underneath
  /// it, and a place counted twice would appear twice in the footer's
  /// ruler as its own nearest neighbour at 0 km.
  List<BiblePlace> get _located {
    final seen = <String>{};
    return <BiblePlace>[
      for (final p in <BiblePlace>[
        ...widget.emphasised,
        ..._context,
        ..._routePlaces,
      ])
        if (p.located && seen.add(p.id)) p,
    ];
  }

  int get _unlocatedCount =>
      widget.emphasised.where((p) => !p.located).length +
      _context.where((p) => !p.located).length;

  @override
  void didUpdateWidget(PlaceMapView old) {
    super.didUpdateWidget(old);
    if (old.fitToken != widget.fitToken) {
      _touched = false;
      _proj = null;
    } else if (old.focusToken != widget.focusToken) {
      _focusOnSelection();
    }
  }

  /// Bring the selected place into view at a scale where "where is it"
  /// has an answer.
  ///
  /// Zoom is raised to a regional view but never lowered: a reader who
  /// has zoomed into the Shephelah and then picks a name out of the index
  /// wants that name, not their work undone.
  void _focusOnSelection() {
    final p = _proj;
    final sel = _selected;
    if (p == null || sel == null) return;
    setState(() {
      _touched = true;
      _proj = p.copyWith(
        centreLat: sel.lat!,
        centreLon: sel.lon!,
        pixelsPerDegreeLat:
            p.pixelsPerDegreeLat < _regionalPpd ? _regionalPpd : null,
      );
    });
  }

  /// Pixels per degree of latitude for "a region, not a continent" —
  /// about 15° across in a 600 px pane, which is Galilee-to-Sinai.
  static const double _regionalPpd = 40.0;

  /// Fit what the reader asked about, or the geography around it, or
  /// fall back to the Levant.
  ///
  /// [PlaceMapView.emphasised] wins when it has anything located in it,
  /// and that ordering is the feature: searching `Antioch` should frame
  /// both Antiochs, not the whole gazetteer they sit in.
  ///
  /// The final fallback matters: a chapter can name only unlocated
  /// places, and an empty bounding box would otherwise project at
  /// infinite zoom and paint a blank pane that looks like a crash.
  MapProjection _fitted(Size size) {
    final told = widget.fitPoints;
    final asked = told == null ? null : boundsOf(told);
    if (asked != null) return MapProjection.fit(asked.padded(), size);
    final subject = <(double, double)>[
      for (final p in widget.emphasised)
        if (p.located) (p.lat!, p.lon!),
    ];
    final pts = subject.isNotEmpty
        ? subject
        : <(double, double)>[
            for (final p in _context)
              if (p.located) (p.lat!, p.lon!),
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

  /// **Places first, then legs, then nothing.**
  ///
  /// The order is not a preference, it is a correctness requirement. Every
  /// stop's dot sits exactly on the end of the leg that arrives at it and
  /// the leg that leaves it, so a line-first test would swallow the tap at
  /// every junction on the route and leave the dots — the smaller, harder
  /// targets — unreachable. A place has a 22 px radius against a leg's 9,
  /// which settles the overlap in the same direction.
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
    if (best != null) {
      widget.onSelect(best.id);
      return;
    }

    final onLeg = widget.onSelectLeg;
    if (onLeg != null && widget.routes.isNotEmpty) {
      final hit = hitJourneyLeg(
        routes: widget.routes,
        // Recomputed rather than shared with the painter because the
        // painter is rebuilt every frame and holding a reference to its
        // lanes would be holding a reference to a dead one. It is pure
        // and cheap, and both callers derive it from the same list.
        lanes: corridorLanes(widget.routes),
        project: (lat, lon) {
          final o = p.project(lat, lon);
          return (o.dx, o.dy);
        },
        x: local.dx,
        y: local.dy,
        selectedRouteId: widget.selectedRouteId,
      );
      if (hit != null) {
        onLeg((
          routeId: widget.routes[hit.route].id,
          index: hit.segment,
        ));
        return;
      }
    }

    // Tapping empty water clears the selection rather than keeping a
    // marker lit that the reader has visibly moved away from.
    widget.onSelect(null);
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
                        emphasised: widget.emphasised,
                        muted: _context,
                        routes: widget.routes,
                        selectedRouteId: widget.selectedRouteId,
                        selectedLeg: widget.selectedLeg,
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
    final left = widget.muted.length;
    final canToggle = left > 0 && widget.onToggleContext != null;
    return Container(
      height: t.paneTitleHeight + 4,
      color: c.chromeBg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, box) {
          // The pan/zoom hint yields first. It is a courtesy; the layer
          // control is the line that says what the map is currently
          // showing, and an ellipsised Chinese label is its own defect
          // (#297) so the choice is print it whole or not at all.
          final roomForHint = box.maxWidth >= (canToggle ? 640 : 420);
          return Row(
            children: [
              Icon(Icons.public, size: t.chrome + 2, color: c.mutedText),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.chrome,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              const Spacer(),
              if (roomForHint) ...[
                Flexible(
                  child: Text(
                    s('placesMapHint', 'Scroll to zoom, drag to pan.'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style:
                        TextStyle(fontSize: t.chrome - 1.5, color: c.mutedText),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (canToggle) ...[
                _contextToggle(c, t, left),
                const SizedBox(width: 4),
              ],
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
              if (widget.onClose != null)
                _flatButton(
                  context,
                  c,
                  t,
                  s('placesMapClose', 'Close map'),
                  widget.onClose!,
                ),
            ],
          );
        },
      ),
    );
  }

  /// The one control that says out loud what the filter did to the map.
  ///
  /// It prints the COUNT rather than an eye icon alone: "1259 others" is
  /// a fact the reader can check against the index header's own
  /// `12 / 1271`, and the two numbers adding up is what makes the map and
  /// the list legibly one filter. A bare icon would teach nothing on a
  /// tablet, where there is no hover to reveal a tooltip (#299).
  Widget _contextToggle(WbColors c, WbType t, int n) {
    final shown = widget.showContext;
    final label = (shown
            ? _mapString('atlasContextHide', 'Hide {n} others')
            : _mapString('atlasContextShow', 'Show {n} others'))
        .replaceAll('{n}', '$n');
    return Tooltip(
      message: _mapString('atlasContextTip',
              '{n} places the current filter leaves out, drawn faint.')
          .replaceAll('{n}', '$n'),
      child: Material(
        color: shown ? c.selectionBg : c.chromeBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: shown ? c.text : c.border,
            width: WbMetrics.hairline,
          ),
        ),
        child: InkWell(
          onTap: widget.onToggleContext,
          hoverColor: c.hoverBg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  shown ? Icons.layers : Icons.layers_outlined,
                  size: t.chrome,
                  color: shown ? c.text : c.mutedText,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: t.chrome - 0.5,
                    fontWeight: shown ? FontWeight.w700 : FontWeight.w400,
                    color: shown ? c.text : c.mutedText,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            // The basis rides in a tooltip because it is three clauses
            // long and the footer is two lines. It used to be carried by
            // the word "about", which was doing none of the work: the
            // speed had no source, the distance was a chord, and the unit
            // was never named.
            Tooltip(
              message: s('travelDaysBasis',
                  'At 20–30 km a day on foot (ORBIS, Stanford, 2012), over '
                  'straight lines — so the real journey is longer. Days on '
                  'the road, not the time the journey took.'),
              child: Text(
                // The ruler. Nearest three, because a chapter can name a
                // dozen places and the far end of that list is noise.
                others.take(3).map((e) {
                  final name = e.$1.displayName(widget.script);
                  final days = walkingDaysFor(e.$2);
                  final walk = days == null
                      ? ''
                      : ' · ${formatTravelDays(days, widget.locale)}';
                  return '${sel.displayName(widget.script)} → $name  '
                      '${e.$2.round()} km$walk';
                }).join('    '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: t.chrome - 1,
                  color: c.text,
                  height: 1.35,
                ),
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

/// Draws the base geography and the markers over it.
class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.base,
    required this.emphasised,
    required this.muted,
    required this.routes,
    required this.selectedRouteId,
    required this.selectedLeg,
    required this.selectedId,
    required this.projection,
    required this.script,
    required this.colors,
    required this.labelSize,
  })  : _labelOrder = _orderLabels(emphasised, muted, routes, selectedId),
        _lanes = corridorLanes(routes),
        _routeSig = routes.map((r) => r.id).join(',');

  final BaseMap base;
  final List<BiblePlace> emphasised;
  final List<BiblePlace> muted;
  final List<ResolvedJourney> routes;
  final String? selectedRouteId;
  final ({String routeId, int index})? selectedLeg;

  /// Perpendicular offset per segment. See [corridorLanes].
  final List<List<double>> _lanes;

  /// Which routes are on, as a value rather than a list identity — the
  /// host rebuilds this widget on every keystroke and hands over a fresh
  /// list each time, so an identity check would repaint on nothing.
  final String _routeSig;

  /// Who gets a label first. See [labelPriority].
  final List<BiblePlace> _labelOrder;

  /// Route stops first, then [labelPriority]'s order.
  ///
  /// A stop the reader has switched a route on to see must not lose its
  /// name to a place that merely has more references — which is what
  /// would happen under the reference ranking alone, since the routes
  /// pass through a good many small towns.
  static List<BiblePlace> _orderLabels(
    List<BiblePlace> emphasised,
    List<BiblePlace> muted,
    List<ResolvedJourney> routes,
    String? selectedId,
  ) {
    final out = <BiblePlace>[];
    final seen = <String>{};
    for (final r in routes) {
      for (final m in r.markers) {
        if (seen.add(m.place.id)) out.add(m.place);
      }
    }
    for (final p in labelPriority(emphasised, muted, selectedId: selectedId)) {
      if (seen.add(p.id)) out.add(p);
    }
    return out;
  }

  /// How many labels the painter will *attempt* per frame.
  ///
  /// The cap counts attempts rather than labels drawn, and that is the
  /// load-bearing detail: `TextPainter.layout` runs before the collision
  /// test can reject a label, so counting only survivors would still lay
  /// out all 1,228 names on a world view where nearly every one of them
  /// collides. 220 attempts costs well under a frame and yields more
  /// surviving labels than a map this size can legibly carry.
  static const int _labelAttempts = 220;

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

    // Context first, so the subject is never painted over by its own
    // background. Dots and labels are separate passes because which
    // labels a crowded map keeps has to be decided across the whole set:
    // drawing each layer complete meant the context layer claimed its
    // label rectangles first and could take the name off the very place
    // the reader was asking about.
    // Lines under the dots, badges over them: a route passes THROUGH a
    // place, and a line drawn across a marker says it passes over one.
    _routeLines(canvas, size);
    _dots(canvas, size, muted, strong: false);
    _dots(canvas, size, emphasised, strong: true);
    _routeMarkers(canvas, size);
    _labels(canvas, size, <String>{
      for (final p in emphasised) p.id,
      // A stop reads as strongly as anything else the reader asked for.
      // Its name in context grey beside a full-strength badge would say
      // the two were different answers.
      for (final r in routes)
        for (final m in r.markers) m.place.id,
    });
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

  /// True when the marker would land outside the pane. Generous by 40 px
  /// so a label anchored just past the edge still resolves.
  bool _offPane(Offset o, Size size) =>
      o.dx < -40 || o.dy < -40 || o.dx > size.width + 40 ||
      o.dy > size.height + 40;

  double _radiusFor(BiblePlace p, bool strong) =>
      p.id == selectedId ? 5.0 : (strong ? 3.5 : 2.5);

  void _dots(Canvas canvas, Size size, List<BiblePlace> places,
      {required bool strong}) {
    for (final p in places) {
      if (!p.located) continue;
      final o = projection.project(p.lat!, p.lon!);
      if (_offPane(o, size)) continue;
      final isSel = p.id == selectedId;
      final r = _radiusFor(p, strong);
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color =
            isSel ? colors.link : (strong ? colors.text : colors.mutedText);

      // A ring under the dot lifts it off a busy coastline without
      // needing a shadow, which the workbench does not use.
      canvas.drawCircle(
          o, r + 1.6, Paint()..color = colors.paneBg.withValues(alpha: 0.9));
      canvas.drawCircle(o, r, fill);
    }
  }

  /// Every route's legs, the one being read drawn last so a crossing
  /// resolves in its favour.
  void _routeLines(Canvas canvas, Size size) {
    for (var i = 0; i < routes.length; i++) {
      if (routes[i].id != selectedRouteId) _legsOf(canvas, size, i);
    }
    for (var i = 0; i < routes.length; i++) {
      if (routes[i].id == selectedRouteId) _legsOf(canvas, size, i);
    }
  }

  void _legsOf(Canvas canvas, Size size, int index) {
    final r = routes[index];
    final lanes = _lanes[index];
    final style = journeyStyleFor(colors, r.journey.style);
    final selected = r.id == selectedRouteId;
    final dimmed = selectedRouteId != null && !selected;

    for (var i = 0; i < r.segments.length; i++) {
      final s = r.segments[i];
      final a0 = projection.project(s.from.place.lat!, s.from.place.lon!);
      final b0 = projection.project(s.to.place.lat!, s.to.place.lon!);
      final span = b0 - a0;
      final length = span.distance;
      if (length < 0.01) continue;
      // Shifted off the chord only where the chord is shared. See
      // [corridorLanes].
      final lane =
          Offset(-span.dy / length, span.dx / length) * lanes[i];
      final a = a0 + lane;
      final b = b0 + lane;

      final ink = style.colour.withValues(
          alpha: journeyOpacity(attested: s.attested, dimmed: dimmed));
      final width =
          journeyStrokeWidth(attested: s.attested, selected: selected);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = width
        ..color = ink;
      final dash = journeyDash(s.leg, attested: s.attested);

      // The leg the reader asked about, marked without touching a single
      // channel that means something.
      //
      // Colour is route identity, dash is the text's claim and stroke
      // width already carries provisional-versus-attested; spending any
      // of the three on "you clicked this" would make the drawing say
      // something about the itinerary that the itinerary does not. So the
      // halo is NEUTRAL ink — no route is ever drawn in the foreground
      // colour, so a grey band cannot be misread as a leg — and it repeats
      // the leg's OWN dash pattern rather than running solid underneath
      // it. A solid halo under a dotted provisional leg would put a
      // continuous band where the text supports nothing, which is the one
      // thing this whole file is arranged to prevent.
      if (selectedLeg != null &&
          selectedLeg!.routeId == r.id &&
          selectedLeg!.index == i) {
        _dashedLine(
          canvas,
          size,
          a,
          b,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.butt
            ..strokeWidth = width + 5
            ..color = colors.text.withValues(alpha: 0.22),
          dash,
        );
      }

      _dashedLine(canvas, size, a, b, paint, dash);
      _arrowhead(canvas, size, a, b, ink, selected);
    }
  }

  /// One leg, clipped to the pane and then dashed.
  ///
  /// Clipping FIRST is not an optimisation detail. At a city-block zoom a
  /// leg is millions of pixels long, and a dash loop that walked all of
  /// it would hang the frame; the alternative of drawing long lines solid
  /// past some threshold is worse than slow, because solid means "the
  /// text says they went by land" and the drawing would be lying at
  /// exactly the zoom the reader looks closest at.
  void _dashedLine(Canvas canvas, Size size, Offset a, Offset b, Paint paint,
      List<double> pattern) {
    final total = (b - a).distance;
    final visible = _visibleRange(a, b, size);
    if (visible == null) return;
    final (from, to) = (visible.$1 * total, visible.$2 * total);
    final dir = (b - a) / total;

    if (pattern.isEmpty) {
      canvas.drawLine(a + dir * from, a + dir * to, paint);
      return;
    }
    final period = pattern[0] + pattern[1];
    if (period <= 0) return;
    // Phase is measured from the leg's own start rather than from the
    // clip, so the dashes do not crawl along the line as the reader pans.
    var t = (from / period).floorToDouble() * period;
    while (t < to) {
      final on0 = t < from ? from : t;
      final on1 = t + pattern[0];
      if (on1 > on0) {
        canvas.drawLine(
            a + dir * on0, a + dir * (on1 > to ? to : on1), paint);
      }
      t += period;
    }
  }

  /// Which stretch of `a`→`b`, as a fraction of its length, is on screen.
  /// Null when none of it is. Liang–Barsky.
  (double, double)? _visibleRange(Offset a, Offset b, Size size) {
    final r = Rect.fromLTWH(-8, -8, size.width + 16, size.height + 16);
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    var t0 = 0.0;
    var t1 = 1.0;
    for (final (p, q) in <(double, double)>[
      (-dx, a.dx - r.left),
      (dx, r.right - a.dx),
      (-dy, a.dy - r.top),
      (dy, r.bottom - a.dy),
    ]) {
      if (p == 0) {
        if (q < 0) return null;
        continue;
      }
      final t = q / p;
      if (p < 0) {
        if (t > t1) return null;
        if (t > t0) t0 = t;
      } else {
        if (t < t0) return null;
        if (t < t1) t1 = t;
      }
    }
    return (t0, t1);
  }

  /// A small filled triangle at the midpoint of the visible stretch,
  /// pointing the way they travelled.
  ///
  /// bwh33 offers "Draw arrowhead" on a polyline and it is worth having
  /// for the same reason: a numbered marker says the ORDER of the stops,
  /// but only where the numbers are legible, and at a zoom where two of
  /// them are off screen the arrow is the only thing left saying which
  /// way the leg runs.
  void _arrowhead(
      Canvas canvas, Size size, Offset a, Offset b, Color ink, bool selected) {
    final total = (b - a).distance;
    final visible = _visibleRange(a, b, size);
    if (visible == null) return;
    final from = visible.$1 * total;
    final to = visible.$2 * total;
    // Under about 18 px there is no room for a head that would not
    // swallow the leg it sits on.
    if (to - from < 18) return;
    final dir = (b - a) / total;
    final at = a + dir * ((from + to) / 2);
    final n = Offset(-dir.dy, dir.dx);
    final h = selected ? 5.2 : 4.4;
    final w = h * 0.6;
    final tail = at - dir * (h * 0.45);
    canvas.drawPath(
      Path()
        ..moveTo(at.dx + dir.dx * h * 0.55, at.dy + dir.dy * h * 0.55)
        ..lineTo(tail.dx + n.dx * w, tail.dy + n.dy * w)
        ..lineTo(tail.dx - n.dx * w, tail.dy - n.dy * w)
        ..close(),
      Paint()
        ..style = PaintingStyle.fill
        ..color = ink,
    );
  }

  /// A dot and a numbered badge at each POSITION.
  ///
  /// The badge carries every ordinal that position holds on that route —
  /// Lystra reads `8,10` — because two badges at one coordinate overprint
  /// into a smudge, and because the doubling back is the thing worth
  /// saying. Badges from different routes stack upwards rather than
  /// overprint, so a place on both journeys shows both itineraries'
  /// numbering.
  ///
  /// 2026-08-24 (#317): "at one coordinate" used to be implemented as "of
  /// one place", which is the same thing only while every coordinate
  /// belongs to one place. It does not — 909 of the gazetteer's 1,228
  /// located places share a point — and the wilderness itinerary put
  /// eleven distinct stations on one, so the smudge this comment warns
  /// about was being drawn. The key is [markerKeyFor] now, and the
  /// numerals are range-compressed, because `17,18,19,20,21,22,23,24,25,
  /// 26,27` in a badge is its own kind of illegible.
  void _routeMarkers(Canvas canvas, Size size) {
    for (var i = 0; i < routes.length; i++) {
      final r = routes[i];
      final style = journeyStyleFor(colors, r.journey.style, r.journey.mark);
      final faded =
          selectedRouteId != null && r.id != selectedRouteId ? 0.5 : 1.0;
      final ordinals = r.ordinalsByMarker;

      for (final m in r.markers) {
        final o = projection.project(m.place.lat!, m.place.lon!);
        if (_offPane(o, size)) continue;

        // The halo takes the mark's own silhouette too. A round halo
        // under a diamond leaves four pale ears sticking out past its
        // points, which at this size reads as a second, blurrier marker.
        paintJourneyMark(canvas, o, 4.8,
            Paint()..color = colors.paneBg.withValues(alpha: 0.9 * faded),
            style.mark);

        // A place the travellers never reached is drawn HOLLOW and takes
        // no badge. Both halves matter: the ring says "not a stop" at the
        // glance a filled dot would have claimed one, and the missing
        // number says it again in the channel that carries the order —
        // Phoenix cannot be given a place in a sequence the ship never
        // put it in. The label layer still names it, which is the whole
        // reason it is on the map.
        if (m.isAside) {
          paintJourneyMark(
            canvas,
            o,
            3.4,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = style.colour.withValues(alpha: faded),
            style.mark,
          );
          continue;
        }

        paintJourneyMark(canvas, o, 3.2,
            Paint()..color = style.colour.withValues(alpha: faded), style.mark);

        final tp = TextPainter(
          text: TextSpan(
            text: formatOrdinals(ordinals[markerKeyFor(m.place)] ?? const <int>[]),
            style: TextStyle(
              fontSize: labelSize - 2,
              fontWeight: FontWeight.w700,
              color: style.onColour.withValues(alpha: faded),
              height: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        final w = tp.width + 6;
        final h = tp.height + 3;
        final rect = Rect.fromLTWH(
          o.dx - w / 2,
          o.dy - 8 - h - i * (h + 2),
          w,
          h,
        );
        canvas.drawRect(
            rect, Paint()..color = style.colour.withValues(alpha: faded));
        tp.paint(canvas, Offset(rect.left + 3, rect.top + 1.5));
        // Claimed so a passing name does not print over the numbers. The
        // stop's own label sits to the RIGHT at the dot's height, clear
        // of a badge that sits above it, so this never costs the stop its
        // own name.
        _claimed.add(rect.inflate(1));
      }
    }
  }

  void _labels(Canvas canvas, Size size, Set<String> emphasisedIds) {
    var attempts = 0;
    for (final p in _labelOrder) {
      if (attempts >= _labelAttempts) break;
      if (!p.located) continue;
      final o = projection.project(p.lat!, p.lon!);
      if (_offPane(o, size)) continue;
      final label = p.displayName(script);
      if (label.isEmpty) continue;

      final isSel = p.id == selectedId;
      final strong = isSel || emphasisedIds.contains(p.id);
      attempts++;

      final tp = TextPainter(
        text: TextSpan(
          text: p.ordinal == null ? label : '$label ${p.ordinal}',
          style: TextStyle(
            fontSize: strong ? labelSize : labelSize - 1,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            // The context layer was drawn in the SAME ink as the answer
            // and one pixel smaller, which is no distinction at all: a
            // reader scoped to Obadiah read Capernaum in full black and
            // concluded the filter had been ignored. bwh33 does the same
            // thing from the other end — its Auto-dim exists so black
            // labels can be read over an overlay.
            color: isSel
                ? colors.link
                : (strong ? colors.text : colors.mutedText),
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      final r = _radiusFor(p, strong);
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
      old.emphasised != emphasised ||
      old.muted != muted ||
      old._routeSig != _routeSig ||
      old.selectedRouteId != selectedRouteId ||
      old.selectedLeg != selectedLeg ||
      old.script != script;
}
