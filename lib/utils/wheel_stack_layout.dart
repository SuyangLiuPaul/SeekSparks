import 'dart:math' as math;
import 'dart:ui';

/// The original interval, including a zero-duration record. Tier planning
/// never clips or widens dates; callers resolve an open end against their
/// existing axis before passing it here.
class WheelStackInterval {
  const WheelStackInterval({
    required this.id,
    required this.stream,
    required this.start,
    required this.end,
  });

  final String id;
  final String stream;
  final int start;
  final int end;

  bool get isPoint => start == end;
}

class WheelStackAssignment {
  const WheelStackAssignment({required this.interval, required this.tier});

  final WheelStackInterval interval;
  final int tier;
}

class WheelStackPlan {
  WheelStackPlan._(
      List<WheelStackAssignment> assignments, Map<String, int> depthByStream)
      : assignments = List.unmodifiable(assignments),
        depthByStream = Map.unmodifiable(depthByStream),
        tierById = Map.unmodifiable({
          for (final assignment in assignments)
            assignment.interval.id: assignment.tier,
        });

  final List<WheelStackAssignment> assignments;
  final Map<String, int> depthByStream;
  final Map<String, int> tierById;
}

/// Minimum interval colouring, independently for every stream. Sorting
/// by start, longest first, then id makes source-list permutations give
/// the same result. Reusing the lowest free tier makes the stack compact.
///
/// A duration occupies [start, end), so adjacent reigns may share a tier.
/// A point occupies only its own year: it can reuse a duration ending
/// then, but cannot overwrite another point or a duration active then.
/// This preserves the corpus's zero-year records without inventing a
/// one-year reign merely to make a raised shape wide enough to see.
WheelStackPlan planWheelStackTiers(Iterable<WheelStackInterval> intervals) {
  final sorted = intervals.toList();
  final ids = <String>{};
  for (final interval in sorted) {
    if (interval.end < interval.start) {
      throw ArgumentError.value(interval.id, 'intervals', 'Reversed interval');
    }
    if (!ids.add(interval.id)) {
      throw ArgumentError.value(interval.id, 'intervals', 'Duplicate id');
    }
  }
  sorted.sort((a, b) {
    final stream = a.stream.compareTo(b.stream);
    if (stream != 0) return stream;
    final start = a.start.compareTo(b.start);
    if (start != 0) return start;
    final end = b.end.compareTo(a.end);
    return end != 0 ? end : a.id.compareTo(b.id);
  });
  final assignments = <WheelStackAssignment>[];
  final depths = <String, int>{};
  var stream = '';
  var tierEnds = <int>[];
  var pointYears = <int?>[];
  for (final interval in sorted) {
    if (interval.stream != stream) {
      stream = interval.stream;
      tierEnds = [];
      pointYears = [];
    }
    var tier = 0;
    while (tier < tierEnds.length &&
        (tierEnds[tier] > interval.start ||
            pointYears[tier] == interval.start)) {
      tier++;
    }
    if (tier == tierEnds.length) {
      tierEnds.add(interval.end);
      pointYears.add(interval.isPoint ? interval.start : null);
    } else {
      tierEnds[tier] = interval.end;
      pointYears[tier] = interval.isPoint ? interval.start : null;
    }
    assignments.add(WheelStackAssignment(interval: interval, tier: tier));
    depths[stream] = tierEnds.length;
  }
  return WheelStackPlan._(assignments, depths);
}

/// An affine 2.5D view: time and radius stay in the original flat plane;
/// elevation moves only the display point. Inverse projection therefore
/// recovers the same year angle at every tier.
class WheelStackProjection {
  const WheelStackProjection({this.centre = Offset.zero, this.squash = .64})
      : assert(squash > 0 && squash <= 1);

  final Offset centre;
  final double squash;

  Offset project(Offset flat, {double height = 0}) =>
      centre + Offset(flat.dx, flat.dy * squash - height);

  Offset polar(double radius, double angle, {double height = 0}) =>
      project(Offset(math.cos(angle), math.sin(angle)) * radius,
          height: height);

  Offset unproject(Offset screen, {double height = 0}) =>
      Offset(screen.dx - centre.dx, (screen.dy - centre.dy + height) / squash);

  Rect ellipse(double radius, {double height = 0}) => Rect.fromCenter(
      center: centre - Offset(0, height),
      width: radius * 2,
      height: radius * 2 * squash);
}

/// One annular prism. The top, walls and hit footprint come from the same
/// projected paths, so a shaded side opens the record that painted it.
/// Zero-span intervals have empty faces; render those as point markers,
/// without expanding their historical duration.
class WheelStackPrism {
  WheelStackPrism({
    required this.id,
    required this.projection,
    required this.innerRadius,
    required this.outerRadius,
    required this.startAngle,
    required this.endAngle,
    required this.bottomHeight,
    required this.topHeight,
  })  : assert(innerRadius >= 0 && outerRadius > innerRadius),
        assert(endAngle >= startAngle && endAngle - startAngle <= 2 * math.pi),
        assert(topHeight >= bottomHeight);

  final String id;
  final WheelStackProjection projection;
  final double innerRadius;
  final double outerRadius;
  final double startAngle;
  final double endAngle;
  final double bottomHeight;
  final double topHeight;

  double get middleRadius => (innerRadius + outerRadius) / 2;
  double get middleAngle => (startAngle + endAngle) / 2;
  double get sweep => endAngle - startAngle;

  late final Path topPath = _annularFace(topHeight);
  late final Path bottomPath = _annularFace(bottomHeight);
  late final List<Path> sidePaths = List.unmodifiable(_visibleSides());
  late final Path footprint = () {
    var path = Path.from(topPath);
    for (final side in sidePaths) {
      path = Path.combine(PathOperation.union, path, side);
    }
    return path;
  }();
  Rect get bounds => footprint.getBounds();

  bool contains(Offset screen) => footprint.contains(screen);

  Path _annularFace(double height) {
    final path = Path();
    if (sweep == 0) return path;
    path.arcTo(projection.ellipse(outerRadius, height: height), startAngle,
        sweep, true);
    final innerEnd = projection.polar(innerRadius, endAngle, height: height);
    path.lineTo(innerEnd.dx, innerEnd.dy);
    if (innerRadius > 0) {
      path.arcTo(projection.ellipse(innerRadius, height: height), endAngle,
          -sweep, false);
    }
    return path..close();
  }

  Path _curvedWall(double radius, double from, double to) {
    final end = projection.polar(radius, to, height: bottomHeight);
    return Path()
      ..arcTo(
          projection.ellipse(radius, height: topHeight), from, to - from, true)
      ..lineTo(end.dx, end.dy)
      ..arcTo(projection.ellipse(radius, height: bottomHeight), to, from - to,
          false)
      ..close();
  }

  Path _endWall(double angle) => _polygon([
        projection.polar(innerRadius, angle, height: topHeight),
        projection.polar(outerRadius, angle, height: topHeight),
        projection.polar(outerRadius, angle, height: bottomHeight),
        projection.polar(innerRadius, angle, height: bottomHeight),
      ]);

  Iterable<Path> _visibleSides() sync* {
    if (sweep == 0 || topHeight == bottomHeight) return;
    // The viewer looks toward the rear from positive y. It sees the
    // outer wall on the near half, and the inner wall through the hole
    // on the far half. Hidden rear walls must not become click targets.
    if (innerRadius > 0) {
      for (final range in _halfCircleRanges(startAngle, endAngle, math.pi)) {
        yield _curvedWall(innerRadius, range.$1, range.$2);
      }
    }
    if (sweep < 2 * math.pi) {
      if (math.cos(startAngle) < 0) yield _endWall(startAngle);
      if (math.cos(endAngle) > 0) yield _endWall(endAngle);
    }
    for (final range in _halfCircleRanges(startAngle, endAngle, 0)) {
      yield _curvedWall(outerRadius, range.$1, range.$2);
    }
  }
}

Iterable<(double, double)> _halfCircleRanges(
    double start, double end, double halfStart) sync* {
  final turn = 2 * math.pi;
  final first = ((start - halfStart) / turn).floor();
  final last = ((end - halfStart) / turn).floor();
  for (var cycle = first; cycle <= last; cycle++) {
    final from = math.max(start, halfStart + cycle * turn);
    final to = math.min(end, halfStart + cycle * turn + math.pi);
    if (to > from) yield (from, to);
  }
}

/// Explicit stacks draw lower tiers first; within a tier, the far side
/// precedes the near side. Stable id ties make pointer selection and
/// repaint order independent of source order. Use the returned list for
/// both painting and [hitWheelStackPrism], without re-sorting either one.
List<WheelStackPrism> wheelStackPaintOrder(Iterable<WheelStackPrism> prisms) {
  final sorted = prisms.toList();
  sorted.sort((a, b) {
    final height = a.topHeight.compareTo(b.topHeight);
    if (height != 0) return height;
    final depth = (a.bottomPath.getBounds().bottom + a.bottomHeight)
        .compareTo(b.bottomPath.getBounds().bottom + b.bottomHeight);
    return depth != 0 ? depth : a.id.compareTo(b.id);
  });
  return sorted;
}

/// A point's marker footprint, separate from its empty duration faces.
/// Supply the drawn radius for occlusion and a larger touch radius for
/// hit testing; neither operation changes the interval's year or sweep.
Path wheelStackPointFootprint(WheelStackPrism prism, {double radius = 6}) {
  if (prism.sweep != 0 || radius <= 0) return Path();
  return Path()
    ..addOval(Rect.fromCircle(
        center: prism.projection.polar(prism.middleRadius, prism.middleAngle,
            height: prism.topHeight),
        radius: radius));
}

WheelStackPrism? hitWheelStackPrism(
    List<WheelStackPrism> paintOrder, Offset screen,
    {double pointRadius = 6}) {
  for (final prism in paintOrder.reversed) {
    if (prism.sweep == 0
        ? wheelStackPointFootprint(prism, radius: pointRadius).contains(screen)
        : prism.contains(screen)) {
      return prism;
    }
  }
  return null;
}

class WheelStackLabelPlacement {
  const WheelStackLabelPlacement({
    required this.centre,
    required this.rotation,
    required this.bounds,
    required this.corners,
    this.beyondFace = false,
  });

  final Offset centre;
  final double rotation;
  final Rect bounds;
  final List<Offset> corners;

  /// True when the name could not fit on the record's own face and is
  /// standing just past the end of it instead, on the same ring.
  final bool beyondFace;
}

/// A readable straight tangent on this tier's top face — or, when
/// nothing fits there, just past the end of that face on the same ring.
///
/// Size comes from the actual shaped text. On the face, all of its
/// padded rectangle must fit the annular sector, clear already placed
/// text and avoid the footprints painted in front. Past the end of it,
/// the rectangle must additionally clear every other record in
/// [beside], because a name lying on the next record's face reads as
/// that record's name — which is worse than no name at all.
///
/// Hiding a name never hides the record's prism or its tap target; the
/// event explorer supplies the full wording.
WheelStackLabelPlacement? wheelStackLabelPlacement(
  WheelStackPrism prism,
  Size textSize, {
  double padding = 2,
  double pointRadius = 0,
  Iterable<WheelStackPrism> occluders = const [],
  Iterable<Rect> occupied = const [],
  Iterable<WheelStackPrism> beside = const [],
}) {
  if (textSize.isEmpty || prism.sweep == 0) return null;
  // SEVEN PLACES ALONG THE ARC, NOT THREE.
  //
  // 2026-09-16 「这些放得了放得下的都应该放 这种zoom in后面又有足够位置就
  // 应该把文字放在后面」. A long thin face is exactly the shape that fails
  // at the middle and fits nearer an end, because the top narrows
  // toward the middle of a raised stack and because whatever is in
  // front of it usually covers one part and not the whole. Three
  // attempts threw those away; the search is cheap next to shaping the
  // text, which has already happened by the time we get here.
  for (final fraction in [.5, .25, .75, .12, .88, .37, .63]) {
    final angle = prism.startAngle + prism.sweep * fraction;
    var rotation =
        math.atan2(prism.projection.squash * math.cos(angle), -math.sin(angle));
    if (rotation > math.pi / 2) rotation -= math.pi;
    if (rotation < -math.pi / 2) rotation += math.pi;
    final centre = prism.projection
        .polar(prism.middleRadius, angle, height: prism.topHeight);
    final corners = _labelCorners(centre, rotation, textSize);
    final padded = _labelCorners(centre, rotation,
        Size(textSize.width + padding * 2, textSize.height + padding * 2));
    if (!_quadFitsTop(prism, padded)) continue;
    final paddedPath = _polygon(padded);
    final bounds = _polygon(corners).getBounds();
    if (occupied.any((other) => bounds.inflate(padding).overlaps(other))) {
      continue;
    }
    if (occluders.any((other) => !Path.combine(
            PathOperation.intersect,
            paddedPath,
            other.sweep == 0
                ? wheelStackPointFootprint(other, radius: pointRadius)
                : other.footprint)
        .getBounds()
        .isEmpty)) {
      continue;
    }
    return WheelStackLabelPlacement(
        centre: centre,
        rotation: rotation,
        bounds: bounds,
        corners: List.unmodifiable(corners));
  }

  // NOTHING FITS ON THE FACE. Put the name just past the end of it.
  //
  // 2026-09-16 「如果框框放不下 就放在那个线或者窄框框后面 如果后面有位
  // 置」, and 「这样wheel strip就一致了」 — the strip does the same thing
  // for a bar too narrow to hold its own name, and the two views of one
  // corpus must not disagree about what an unnameable record looks
  // like.
  //
  // The name stays on the record's OWN ring, at its own radius, so
  // which ring it belongs to is never in doubt; it simply starts where
  // the face ends. [beside] is the rest of the chart: a name that lands
  // on the next record's face reads as that record's name, which is
  // worse than no name at all.
  if (prism.middleRadius <= 0) return null;
  final needed = (textSize.width + padding * 2) / prism.middleRadius;
  if (needed > math.pi / 2) return null;
  final angle = prism.endAngle + needed / 2;
  var rotation =
      math.atan2(prism.projection.squash * math.cos(angle), -math.sin(angle));
  if (rotation > math.pi / 2) rotation -= math.pi;
  if (rotation < -math.pi / 2) rotation += math.pi;
  final centre = prism.projection
      .polar(prism.middleRadius, angle, height: prism.topHeight);
  final corners = _labelCorners(centre, rotation, textSize);
  final padded = _labelCorners(centre, rotation,
      Size(textSize.width + padding * 2, textSize.height + padding * 2));
  final paddedPath = _polygon(padded);
  final bounds = _polygon(corners).getBounds();
  if (occupied.any((other) => bounds.inflate(padding).overlaps(other))) {
    return null;
  }
  // Everything painted in front of this record still hides ink past
  // the end of its face, exactly as it does on the face.
  for (final other in [...occluders, ...beside]) {
    if (identical(other, prism) || other.id == prism.id) continue;
    // The cheap rectangle test first — but NOT for a point marker,
    // whose `footprint` is empty and whose bounds are therefore
    // Rect.zero. It has ink all the same.
    if (other.sweep != 0 && !other.bounds.overlaps(bounds)) continue;
    if (!Path.combine(
            PathOperation.intersect,
            paddedPath,
            other.sweep == 0
                ? wheelStackPointFootprint(other, radius: pointRadius)
                : other.footprint)
        .getBounds()
        .isEmpty) {
      return null;
    }
  }
  return WheelStackLabelPlacement(
      centre: centre,
      rotation: rotation,
      bounds: bounds,
      corners: List.unmodifiable(corners),
      beyondFace: true);
}

enum WheelStackCalloutSide { left, right }

class WheelStackCallout {
  const WheelStackCallout({
    required this.id,
    required this.anchor,
    required this.bounds,
    required this.side,
  });

  final String id;
  final Offset anchor;
  final Rect bounds;
  final WheelStackCalloutSide side;

  /// The planner checks this straight leader against every other label.
  Offset get leaderEnd => side == WheelStackCalloutSide.left
      ? bounds.centerRight
      : bounds.centerLeft;
}

/// Names that cannot fit a raised top may use the free banks beside the
/// annulus. [contentArea] is the visible canvas rectangle after controls
/// have been reserved; [measure] returns the caller's shaped, optionally
/// ellipsized single-line size. This function never shrinks text itself.
///
/// Keep the complete [paintOrder], including [excludedIds]: a face with
/// an on-surface name still hides faces behind it. Front records get the
/// first usable slots; leaders start only on visible tops or point marks.
/// A leader may cross the chart, but never another label. Later labels
/// must also clear leaders already admitted, so ordering cannot create
/// a new text collision after an earlier check passed.
List<WheelStackCallout> planWheelStackCallouts({
  required List<WheelStackPrism> paintOrder,
  required Rect contentArea,
  required Size Function(String id) measure,
  double bankWidth = 120,
  double gap = 7,
  double bankInset = 0,
  double leaderGap = 6,
  double pointRadius = 3,
  int maxPerSide = 4,
  Iterable<Rect> occupied = const [],
  Set<String> excludedIds = const {},
}) {
  if (paintOrder.isEmpty ||
      contentArea.isEmpty ||
      bankWidth <= 0 ||
      maxPerSide <= 0) {
    return const [];
  }
  final annulusLeft = paintOrder
      .map((p) => p.projection.centre.dx - p.outerRadius)
      .reduce(math.min);
  final annulusRight = paintOrder
      .map((p) => p.projection.centre.dx + p.outerRadius)
      .reduce(math.max);
  final leftEdge = contentArea.left + bankInset;
  final rightEdge = contentArea.right - bankInset;
  final banks = {
    WheelStackCalloutSide.left: Rect.fromLTRB(
        leftEdge,
        contentArea.top,
        math.min(leftEdge + bankWidth, annulusLeft - leaderGap),
        contentArea.bottom),
    WheelStackCalloutSide.right: Rect.fromLTRB(
        math.max(rightEdge - bankWidth, annulusRight + leaderGap),
        contentArea.top,
        rightEdge,
        contentArea.bottom),
  };
  final result = <WheelStackCallout>[];
  final used = occupied.toList();
  final counts = <WheelStackCalloutSide, int>{};

  for (var i = paintOrder.length - 1; i >= 0; i--) {
    final prism = paintOrder[i];
    if (excludedIds.contains(prism.id)) continue;
    final size = measure(prism.id);
    if (size.isEmpty || !size.isFinite) continue;
    WheelStackCallout? chosen;
    for (final anchor in _calloutAnchors(prism)) {
      if (!contentArea.contains(anchor)) continue;
      if (prism.sweep == 0
          ? pointRadius <= 0
          : !prism.topPath.contains(anchor)) {
        continue;
      }
      final hidden = paintOrder.skip(i + 1).any((nearer) => nearer.sweep == 0
          ? wheelStackPointFootprint(nearer, radius: pointRadius)
              .contains(anchor)
          : nearer.contains(anchor));
      if (hidden) continue;
      final side = anchor.dx < prism.projection.centre.dx
          ? WheelStackCalloutSide.left
          : WheelStackCalloutSide.right;
      if ((counts[side] ?? 0) >= maxPerSide) continue;
      final bank = banks[side]!;
      if (bank.isEmpty ||
          size.width > bank.width ||
          size.height > bank.height) {
        continue;
      }
      final left = side == WheelStackCalloutSide.left
          ? bank.right - size.width
          : bank.left;
      final halfHeight = size.height / 2;
      final minY = bank.top + halfHeight;
      final maxY = bank.bottom - halfHeight;
      final slots = <double>{minY, maxY};
      void addSlot(double y) => slots.add(y.clamp(minY, maxY));
      addSlot(anchor.dy);
      for (final obstacle in used) {
        addSlot(obstacle.top - gap - halfHeight);
        addSlot(obstacle.bottom + gap + halfHeight);
      }
      final step = math.max(1.0, size.height + gap);
      for (var offset = step; offset <= bank.height; offset += step) {
        addSlot(anchor.dy - offset);
        addSlot(anchor.dy + offset);
      }
      final ordered = slots.toList()
        ..sort((a, b) {
          final distance =
              (a - anchor.dy).abs().compareTo((b - anchor.dy).abs());
          return distance != 0 ? distance : a.compareTo(b);
        });
      for (final y in ordered) {
        final bounds =
            Rect.fromLTWH(left, y - halfHeight, size.width, size.height);
        if (used.any((other) => bounds.inflate(gap).overlaps(other))) continue;
        final candidate = WheelStackCallout(
            id: prism.id, anchor: anchor, bounds: bounds, side: side);
        if (used.any((other) => _segmentIntersectsRect(
            anchor, candidate.leaderEnd, other.inflate(gap / 2)))) {
          continue;
        }
        if (result.any((other) => _segmentIntersectsRect(
            other.anchor, other.leaderEnd, bounds.inflate(gap / 2)))) {
          continue;
        }
        chosen = candidate;
        break;
      }
      if (chosen != null) break;
    }
    if (chosen != null) {
      result.add(chosen);
      used.add(chosen.bounds);
      counts[chosen.side] = (counts[chosen.side] ?? 0) + 1;
    }
    if (counts[WheelStackCalloutSide.left] == maxPerSide &&
        counts[WheelStackCalloutSide.right] == maxPerSide) {
      break;
    }
  }
  return result;
}

Iterable<Offset> _calloutAnchors(WheelStackPrism prism) sync* {
  if (prism.sweep == 0) {
    // A point has one marker, not an annular surface. Sampling other
    // radii would invent visible anchors away from the actual dot.
    yield prism.projection
        .polar(prism.middleRadius, prism.middleAngle, height: prism.topHeight);
    return;
  }
  // Liao's centre and quarter points can all sit behind Song while an
  // earlier stretch or the outer edge remains visible. Probe that
  // surface before concluding the record has no place for a leader;
  // every candidate still passes the real top/occlusion checks above.
  for (final angleFraction in [.5, .25, .75, .1, .9]) {
    final angle = prism.startAngle + prism.sweep * angleFraction;
    for (final radialFraction in [.5, .2, .8, .95]) {
      yield prism.projection.polar(
          prism.innerRadius +
              (prism.outerRadius - prism.innerRadius) * radialFraction,
          angle,
          height: prism.topHeight);
    }
  }
}

bool _segmentIntersectsRect(Offset a, Offset b, Rect rect) {
  var from = 0.0;
  var to = 1.0;
  for (final (origin, delta, low, high) in [
    (a.dx, b.dx - a.dx, rect.left, rect.right),
    (a.dy, b.dy - a.dy, rect.top, rect.bottom),
  ]) {
    if (delta.abs() < 1e-12) {
      if (origin < low || origin > high) return false;
      continue;
    }
    var near = (low - origin) / delta;
    var far = (high - origin) / delta;
    if (near > far) {
      final swap = near;
      near = far;
      far = swap;
    }
    from = math.max(from, near);
    to = math.min(to, far);
    if (from > to) return false;
  }
  return true;
}

List<Offset> _labelCorners(Offset centre, double rotation, Size size) {
  final along =
      Offset(math.cos(rotation), math.sin(rotation)) * (size.width / 2);
  final across =
      Offset(-math.sin(rotation), math.cos(rotation)) * (size.height / 2);
  return [
    centre - along - across,
    centre + along - across,
    centre + along + across,
    centre - along + across,
  ];
}

Path _polygon(List<Offset> corners) => Path()..addPolygon(corners, true);

double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

bool _angleInSweep(Offset point, WheelStackPrism prism) {
  final relative =
      (math.atan2(point.dy, point.dx) - prism.startAngle) % (2 * math.pi);
  return relative <= prism.sweep + 1e-9;
}

/// Inverse projection turns the padded text rectangle into a flat quad.
/// The outer disk is convex; the inner-hole clearance is the exact
/// closest point on every edge. Splitting edges at the two year rays
/// also catches a long chord crossing the missing wedge even when all
/// four corners lie on the annulus. Corner-only checks miss both cases.
bool _quadFitsTop(WheelStackPrism prism, List<Offset> projected) {
  final quad = [
    for (final point in projected)
      prism.projection.unproject(point, height: prism.topHeight),
  ];
  if (quad.any((point) =>
      point.distance > prism.outerRadius || !_angleInSweep(point, prism))) {
    return false;
  }
  var allPositive = true;
  var allNegative = true;
  for (var i = 0; i < quad.length; i++) {
    final a = quad[i];
    final b = quad[(i + 1) % quad.length];
    final edge = b - a;
    final side = _cross(edge, -a);
    allPositive = allPositive && side >= 0;
    allNegative = allNegative && side <= 0;
    final length2 = edge.distanceSquared;
    final t = length2 == 0
        ? 0.0
        : (-(a.dx * edge.dx + a.dy * edge.dy) / length2).clamp(0.0, 1.0);
    if ((a + edge * t).distance < prism.innerRadius) return false;
    final cuts = <double>[0, 1];
    for (final angle in [prism.startAngle, prism.endAngle]) {
      final ray = Offset(math.cos(angle), math.sin(angle));
      final denominator = _cross(edge, ray);
      if (denominator.abs() < 1e-12) continue;
      final at = -_cross(a, ray) / denominator;
      final crossing = a + edge * at;
      if (at > 0 && at < 1 && crossing.dx * ray.dx + crossing.dy * ray.dy > 0) {
        cuts.add(at);
      }
    }
    cuts.sort();
    for (var j = 1; j < cuts.length; j++) {
      if (!_angleInSweep(a + edge * ((cuts[j - 1] + cuts[j]) / 2), prism)) {
        return false;
      }
    }
  }
  return prism.innerRadius == 0 || !(allPositive || allNegative);
}

/// How many names the depth view may shape in one frame.
///
/// 2026-09-16 「很多这些地方可以加进去的都没有加」, of a zoomed-in render
/// where most faces carried no name. Sixty was chosen at the resting
/// zoom, where the whole chart is on screen and sixty names is already
/// more than a reader can take in. Zoomed in, the painter has already
/// discarded everything outside the viewport before it counts, so the
/// same sixty is now a cap on a much smaller set — it stops naming
/// faces that have plenty of room, which is the complaint.
///
/// The budget therefore rises with the magnification and stops at four
/// times the resting one, which is the point where the remaining
/// candidates on screen run out before the budget does.
int stackLabelBudget(double scale, double fitScale) {
  if (!scale.isFinite || !fitScale.isFinite || fitScale <= 0) return 60;
  return (60 * (scale / fitScale)).round().clamp(60, 240);
}
