import 'dart:math' as math;
import 'dart:ui';

import 'package:yahwehs_sword/utils/radial_chronology_layout.dart'
    show ringRadii, startRad, sweepRad;
import 'package:yahwehs_sword/utils/wheel_stack_layout.dart';

/// The existing wheel owns ring order and radii. Depth changes only the
/// height of records on those rings, so switching views cannot move a
/// country to a different radius or turn a date into a different angle.
class ChronologyDepthRingInput {
  const ChronologyDepthRingInput({
    required this.id,
    required this.innerRadius,
    required this.outerRadius,
    required this.depth,
  });

  final String id;
  final double innerRadius;
  final double outerRadius;
  final int depth;

  double get width => outerRadius - innerRadius;
}

/// Use the flat wheel's band arithmetic for callers with one shared
/// annulus. Explicit inputs remain available for the separate arc layers.
List<ChronologyDepthRingInput> chronologyDepthRingInputs({
  required List<String> ringIds,
  required Map<String, int> depthByStream,
  required double hubRadius,
  required double outerRadius,
}) =>
    [
      for (var i = 0; i < ringIds.length; i++)
        ChronologyDepthRingInput(
          id: ringIds[i],
          innerRadius:
              ringRadii(i, ringIds.length, hubRadius, outerRadius).inner,
          outerRadius:
              ringRadii(i, ringIds.length, hubRadius, outerRadius).outer,
          depth: depthByStream[ringIds[i]] ?? 0,
        ),
    ];

class ChronologyDepthRingLayout {
  const ChronologyDepthRingLayout._({
    required this.input,
    required this.tierStep,
    required this.thickness,
    required this.heightBudget,
  });

  final ChronologyDepthRingInput input;
  final double tierStep;
  final double thickness;
  final double heightBudget;

  String get id => input.id;
  double get innerRadius => input.innerRadius;
  double get outerRadius => input.outerRadius;
  int get depth => input.depth;
  double get maxHeight => depth == 0 ? 0 : topHeight(depth - 1);

  double bottomHeight(int tier) {
    if (tier < 0 || tier >= depth) {
      throw RangeError.range(tier, 0, depth - 1, 'tier');
    }
    return tier * tierStep;
  }

  double topHeight(int tier) => bottomHeight(tier) + thickness;
}

/// Height is a local budget, independent of how many other countries
/// happen to be selected. At normal lift, the budget is 60% of the narrower
/// neighbouring band's projected width; even a deep stack cannot become a
/// full-band wall at the front/back of the wheel. A fixed pixel step cannot
/// honour this on the original narrow rings. Their detailed names remain in the
/// explorer and appear on the canvas when magnification gives them room.
///
/// Tier tops leave 30% of each step as air. More simultaneous records
/// divide this same budget instead of moving or widening their rings.
/// This limits occlusion, rather than claiming every surface stays visible
/// at every angle: the shared face/callout planner still checks visibility.
/// An explicit expanded lift above one spends more of this clearance;
/// the fit envelope grows with it, rather than clipping the raised tops.
List<ChronologyDepthRingLayout> planChronologyDepthRings(
  List<ChronologyDepthRingInput> inputs, {
  double tilt = .70,
  double lift = 1,
}) {
  chronologyDepthSquash(tilt: tilt, lift: lift);
  final ids = <String>{};
  for (final input in inputs) {
    if (!ids.add(input.id)) {
      throw ArgumentError.value(input.id, 'inputs', 'Duplicate ring id');
    }
    if (!input.innerRadius.isFinite ||
        !input.outerRadius.isFinite ||
        input.innerRadius < 0 ||
        input.outerRadius <= input.innerRadius ||
        input.depth < 0) {
      throw ArgumentError.value(input.id, 'inputs', 'Invalid ring geometry');
    }
  }
  final radialOrder = inputs.toList()
    ..sort((a, b) => b.outerRadius.compareTo(a.outerRadius));
  final narrowestNeighbour = <String, double>{};
  for (var i = 0; i < radialOrder.length; i++) {
    var width = radialOrder[i].width;
    if (i > 0) width = math.min(width, radialOrder[i - 1].width);
    if (i + 1 < radialOrder.length) {
      width = math.min(width, radialOrder[i + 1].width);
    }
    narrowestNeighbour[radialOrder[i].id] = width;
  }
  return List.unmodifiable([
    for (final input in inputs)
      _ringLayout(input, narrowestNeighbour[input.id]!, tilt, lift),
  ]);
}

ChronologyDepthRingLayout _ringLayout(
  ChronologyDepthRingInput input,
  double neighbourWidth,
  double tilt,
  double lift,
) {
  final budget = input.depth == 0 ? 0.0 : neighbourWidth * tilt * .60 * lift;
  final step = input.depth == 0 ? 0.0 : budget / (input.depth - 1 + .70);
  return ChronologyDepthRingLayout._(
    input: input,
    tierStep: step,
    thickness: step * .70,
    heightBudget: budget,
  );
}

/// One interpolation drives both the ground plane and its elevation.
/// At zero lift every tier has zero height and the projection is exactly
/// the flat wheel, so an animated switch has no different starting scene.
/// Expanded lift above one increases height without tilting past [tilt].
double chronologyDepthSquash({double tilt = .70, double lift = 1}) {
  if (!tilt.isFinite || tilt <= 0 || tilt > 1) {
    throw ArgumentError.value(tilt, 'tilt', 'Must be in (0, 1]');
  }
  if (!lift.isFinite || lift < 0) {
    throw ArgumentError.value(lift, 'lift', 'Must be nonnegative');
  }
  return 1 - (1 - tilt) * math.min(1, lift);
}

/// A fit does not change the original radii. Its transform fits a
/// conservative envelope containing the entire ground disc and all tops.
/// It leaves equal headroom below the ground so the circle's ground centre
/// stays fixed when switching from a centred flat camera to the fit view.
/// Callers reserve controls and axis wording in [contentArea] first.
class ChronologyDepthView {
  ChronologyDepthView({
    required this.projection,
    required this.groundRadius,
    required this.contentArea,
    this.maxHeight = 0,
    this.yaw = 0,
  }) {
    _checkRadius(groundRadius);
    _checkViewport(contentArea);
    if (!maxHeight.isFinite || maxHeight < 0) {
      throw ArgumentError.value(maxHeight, 'maxHeight', 'Must be nonnegative');
    }
    _checkYaw(yaw);
  }

  factory ChronologyDepthView.fit({
    required Rect contentArea,
    required double groundRadius,
    required List<ChronologyDepthRingLayout> rings,
    double squash = .70,
    double yaw = 0,
  }) {
    if (!squash.isFinite || squash <= 0 || squash > 1) {
      throw ArgumentError.value(squash, 'squash', 'Must be in (0, 1]');
    }
    if (rings.any((ring) => ring.outerRadius > groundRadius)) {
      throw ArgumentError.value(
          groundRadius, 'groundRadius', 'Must contain every original ring');
    }
    return ChronologyDepthView(
      projection: WheelStackProjection(squash: squash),
      groundRadius: groundRadius,
      contentArea: contentArea,
      maxHeight: rings.fold(0.0, (h, ring) => math.max(h, ring.maxHeight)),
      yaw: yaw,
    );
  }

  final WheelStackProjection projection;
  final double groundRadius;
  final Rect contentArea;
  final double maxHeight;
  final double yaw;

  Offset projectGround(Offset canonical, {double height = 0}) =>
      projection.project(_rotate(canonical, yaw), height: height);

  Rect get projectedBounds => Rect.fromLTRB(
        projection.centre.dx - groundRadius,
        projection.centre.dy - groundRadius * projection.squash - maxHeight,
        projection.centre.dx + groundRadius,
        projection.centre.dy + groundRadius * projection.squash,
      );

  double get fitScale => math.min(
        contentArea.width / projectedBounds.width,
        contentArea.height /
            (2 * (groundRadius * projection.squash + maxHeight)),
      );

  ChronologyDepthTransform get fitTransform => ChronologyDepthTransform(
        scale: fitScale,
        translation: contentArea.center - projection.centre * fitScale,
      );

  Rect get screenBounds => fitTransform.mapRect(projectedBounds);
}

class ChronologyDepthTransform {
  const ChronologyDepthTransform(
      {required this.scale, required this.translation});

  final double scale;
  final Offset translation;

  Offset toScreen(Offset scene) => scene * scale + translation;
  Offset toScene(Offset screen) => (screen - translation) / scale;

  Rect mapRect(Rect rect) => Rect.fromPoints(
        toScreen(rect.topLeft),
        toScreen(rect.bottomRight),
      );
}

/// The camera remembers which ground point lies under the viewport centre,
/// in units of the wheel radius, and zoom relative to the current fit.
/// Retaining raw translation would lose that place when tilt, canvas size
/// or the fit scale changes. Ground height is deliberately zero: selecting
/// a raised face must not rotate its date or move its country's radius.
class ChronologyDepthCamera {
  const ChronologyDepthCamera({
    this.normalizedGroundCentre = Offset.zero,
    this.zoom = 1,
  });

  factory ChronologyDepthCamera.capture({
    required ChronologyDepthView view,
    required Rect viewport,
    required double scale,
    required Offset translation,
  }) =>
      ChronologyDepthCamera.fromProjection(
        projection: view.projection,
        groundRadius: view.groundRadius,
        viewport: viewport,
        scale: scale,
        translation: translation,
        fitScale: view.fitScale,
        yaw: view.yaw,
      );

  factory ChronologyDepthCamera.fromProjection({
    required WheelStackProjection projection,
    required double groundRadius,
    required Rect viewport,
    required double scale,
    required Offset translation,
    double fitScale = 1,
    double yaw = 0,
  }) {
    _checkRadius(groundRadius);
    _checkViewport(viewport);
    _checkScale(scale);
    _checkScale(fitScale);
    _checkYaw(yaw);
    final point = (viewport.center - translation) / scale;
    return ChronologyDepthCamera(
      normalizedGroundCentre:
          _rotate(projection.unproject(point), -yaw) / groundRadius,
      zoom: scale / fitScale,
    );
  }

  final Offset normalizedGroundCentre;
  final double zoom;

  ChronologyDepthTransform restore({
    required ChronologyDepthView view,
    required Rect viewport,
  }) =>
      toProjection(
        projection: view.projection,
        groundRadius: view.groundRadius,
        viewport: viewport,
        fitScale: view.fitScale,
        yaw: view.yaw,
      );

  ChronologyDepthTransform toProjection({
    required WheelStackProjection projection,
    required double groundRadius,
    required Rect viewport,
    double fitScale = 1,
    double yaw = 0,
  }) {
    _checkRadius(groundRadius);
    _checkViewport(viewport);
    _checkScale(fitScale);
    _checkScale(zoom);
    _checkYaw(yaw);
    final scale = zoom * fitScale;
    final scene = projection.project(
      _rotate(normalizedGroundCentre * groundRadius, yaw),
    );
    return ChronologyDepthTransform(
      scale: scale,
      translation: viewport.center - scene * scale,
    );
  }
}

void _checkRadius(double radius) {
  if (!radius.isFinite || radius <= 0) {
    throw ArgumentError.value(radius, 'groundRadius', 'Must be positive');
  }
}

void _checkScale(double scale) {
  if (!scale.isFinite || scale <= 0) {
    throw ArgumentError.value(scale, 'scale', 'Must be positive');
  }
}

void _checkViewport(Rect viewport) {
  if (!viewport.isFinite || viewport.isEmpty) {
    throw ArgumentError.value(
        viewport, 'viewport', 'Must be finite and nonempty');
  }
}

void _checkYaw(double yaw) {
  if (!yaw.isFinite) {
    throw ArgumentError.value(yaw, 'yaw', 'Must be finite');
  }
}

Offset _rotate(Offset point, double angle) => Offset(
      point.dx * math.cos(angle) - point.dy * math.sin(angle),
      point.dx * math.sin(angle) + point.dy * math.cos(angle),
    );

/// Empty ground picks use the same unrotated date angle as the flat wheel.
/// Raised faces are hit first by the caller; neither the gap wedge nor a
/// click beyond the actual ring annulus invents a date for the digest.
int? chronologyDepthYearAt({
  required Offset point,
  required WheelStackProjection projection,
  required int startYear,
  required int endYear,
  double yaw = 0,
  double innerRadius = 0,
  required double outerRadius,
}) {
  final ground = projection.unproject(point);
  final radius = ground.distance;
  if (radius < innerRadius - 1e-8 ||
      radius > outerRadius + 1e-8 ||
      radius < 1e-8 ||
      endYear <= startYear) {
    return null;
  }
  var angle =
      (math.atan2(ground.dy, ground.dx) - yaw - startRad) % (2 * math.pi);
  if (angle > 2 * math.pi - 1e-10) angle = 0;
  if (angle > sweepRad + 1e-10) return null;
  return (startYear + angle / sweepRad * (endYear - startYear))
      .round()
      .clamp(startYear, endYear);
}
