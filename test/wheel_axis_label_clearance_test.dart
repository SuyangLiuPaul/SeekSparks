// Where the chronology wheel's SCALE is printed, measured in the faces
// the app ships.
//
// WHY THIS FILE EXISTS. The wheel has four families of words and three
// of them already have a guard: the rim labels since phase 11
// (`wheel_label_legibility_test`), the arc labels since phase 12
// (`wheel_arc_label_behaviour_test`), the band names measured and left
// alone in the same pass. The fourth — the century ticks and the two
// axis ends, which are not data but the SCALE — had none, and was
// placed by a bare constant that knew nothing about the string it was
// positioning: `rRim + 11`, alternating with `rRim + 22`, and
// `rRim + 17`.
//
// A constant cannot be right, because a scale label is drawn
// HORIZONTALLY and so is not rotated with the ray it sits on: at twelve
// o'clock only its height points back towards the centre, at nine
// o'clock its whole width does.
//
// WHAT THIS FILE CAUGHT. These assertions were run against the old
// placement before it was replaced — the whole file, with only the two
// constants and `centuryTickLabel` swapped back. Six of the fourteen
// went red, and this is the size of the thing they were red about,
// over 3 locales x 3 sizes x 4 zooms = 504 scale labels:
//
//   * 210 of 504 reached inside the rim; 396 came closer to it than
//     the clearance the fix now guarantees. Worst: 主前2500 at 900 px,
//     12.3 canvas units inside.
//   * 113 pairs of scale-label and event-label ink actually overlapped.
//   * 7 pairs of scale labels overlapped EACH OTHER — every one of them
//     AD 2000 against the AD 2026 axis end, 26 years and 1.4 degrees
//     apart, which is why `kAxisEndSwing` is 0.10 and not the 0.055 it
//     was.
//   * AD 1000 / 主后1000 was CLIPPED off the left edge of the canvas at
//     700 px in all three locales — it sits at 175 degrees, so its
//     whole width points outward along the horizontal.
//   * The origin tick printed `AD 0` / `主后0`, a year the reckoning
//     does not have, and `parseWheelYears` dutifully returned [0].
//
// The photographed instance was 主前3500 printed through 最早的轮式车辆,
// and the reason that pair and not another is arithmetic: an event whose
// year is a multiple of 500 sits at exactly a century tick's own angle.
// Two of the 491 do.
//
// The instrument is a separating-axis test between the two boxes, not a
// radius comparison, because a radius comparison cannot tell a label
// that reaches inside the rim WITH an event under it from one that
// reaches inside the rim with nothing there. Only the first is a defect
// a reader sees; both are worth fixing, and this file asserts both
// separately so a regression says which one came back.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show
        centuryTickLabel,
        kAxisEndSwing,
        kAxisLabelClearance,
        kMaxYear,
        kMinYear,
        yearLabel;
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/wheel_search.dart' show parseWheelYears;

/// The wheel paints with no family of its own, so Latin resolves to
/// Roboto and Han to the bundled subset.
const _family = 'Roboto';
const _fallback = ['NotoSansSC-Sub'];

// Mirrors of the page's private geometry. Kept literal on purpose: a
// test that imported them would agree with the page by construction.
const _hubToBands = 0.285;
const _bandsToRim = 0.445;
const _labelPx = 10.5;
const _endPx = 11.0;

const _locales = ['en', 'zh-Hans', 'zh-Hant'];

/// 700 px is about the smallest pane the wheel is reachable in (the app
/// admits nothing under 992 px wide); 1200 is a large desktop one.
const _sizes = [700.0, 900.0, 1200.0];

/// `InteractiveViewer` on this page runs from 0.8 to 14. 0.8 is the
/// worst case for these labels and not 14: every size is divided by
/// sqrt(zoom), so zooming OUT makes the type larger in canvas units
/// while the rim stays where it is.
const _zooms = [0.8, 1.0, 2.0, 4.0];

Future<void> _load(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

TextPainter _tp(String s, double size) => TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: size,
              fontFamily: _family,
              fontFamilyFallback: _fallback)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

double _measure(String s, double size) => _tp(s, size).width;

// ── boxes ────────────────────────────────────────────────────────────

/// A horizontal label's four corners.
List<Offset> _axisBox(Offset centre, double w, double h) => [
      centre + Offset(-w / 2, -h / 2),
      centre + Offset(w / 2, -h / 2),
      centre + Offset(w / 2, h / 2),
      centre + Offset(-w / 2, h / 2),
    ];

/// A run rotated to lie along a ray or a tangent: [along] is the
/// direction its width runs in, [centre] where its middle sits.
List<Offset> _rotatedBox(Offset centre, double along, double w, double h) {
  final u = Offset(math.cos(along), math.sin(along));
  final v = Offset(-math.sin(along), math.cos(along));
  return [
    centre - u * (w / 2) + v * (h / 2),
    centre + u * (w / 2) + v * (h / 2),
    centre + u * (w / 2) - v * (h / 2),
    centre - u * (w / 2) - v * (h / 2),
  ];
}

/// An event label: it occupies `[rStart, rEnd]` along its own ray.
List<Offset> _rayBox(
    Offset c, double angle, double rStart, double rEnd, double h) {
  final u = Offset(math.cos(angle), math.sin(angle));
  final v = Offset(-math.sin(angle), math.cos(angle));
  return [
    c + u * rStart + v * (h / 2),
    c + u * rEnd + v * (h / 2),
    c + u * rEnd - v * (h / 2),
    c + u * rStart - v * (h / 2),
  ];
}

/// Do two convex quads share any area? Separating-axis test: if any
/// edge normal of either separates their projections, they do not.
bool _overlap(List<Offset> a, List<Offset> b) {
  for (final poly in [a, b]) {
    for (var i = 0; i < poly.length; i++) {
      final p = poly[i], q = poly[(i + 1) % poly.length];
      final n = Offset(-(q.dy - p.dy), q.dx - p.dx);
      double lo1 = double.infinity, hi1 = -double.infinity;
      double lo2 = double.infinity, hi2 = -double.infinity;
      for (final o in a) {
        final d = o.dx * n.dx + o.dy * n.dy;
        lo1 = math.min(lo1, d);
        hi1 = math.max(hi1, d);
      }
      for (final o in b) {
        final d = o.dx * n.dx + o.dy * n.dy;
        lo2 = math.min(lo2, d);
        hi2 = math.max(hi2, d);
      }
      if (hi1 <= lo2 || hi2 <= lo1) return false;
    }
  }
  return true;
}

double _nearestToCentre(Offset c, List<Offset> box) {
  // The nearest point of a convex polygon to a point outside it is on
  // its boundary, so sampling the edges densely is exact enough at the
  // 0.001 the assertions use.
  var best = double.infinity;
  for (var i = 0; i < box.length; i++) {
    final p = box[i], q = box[(i + 1) % box.length];
    for (var t = 0; t <= 40; t++) {
      final o = Offset(p.dx + (q.dx - p.dx) * t / 40,
          p.dy + (q.dy - p.dy) * t / 40);
      best = math.min(best, (o - c).distance);
    }
  }
  return best;
}

double _farthestFromCentre(Offset c, List<Offset> box) {
  var best = 0.0;
  for (final o in box) {
    best = math.max(best, (o - c).distance);
  }
  return best;
}

// ── the page's own plan, at one size ─────────────────────────────────

typedef _Cell = ({
  Offset centre,
  double rRim,
  double side,
  List<({List<Offset> box, String text, int year, bool onRing})> axis,
  List<({List<Offset> box, String text})> events,
});

_Cell _cell(
    WheelHistoryData data, String locale, double side, double zoom) {
  final rBands = side * _hubToBands;
  final rRim = side * _bandsToRim;
  final c = Offset(side / 2, side / 2);
  final titleSize = _labelPx / math.sqrt(zoom);
  final endSize = _endPx / math.sqrt(zoom);
  final minGap = (_labelPx * 1.35 / math.sqrt(zoom)) / rBands;

  final clusters = clusterByAngle(
      [for (final e in data.events) angleForSpan(e.year, kMinYear, kMaxYear)],
      minGap);
  final kept = [for (final k in clusters) data.events[k.representative]];
  final spokes = planRadialSpokes(
    requests: [
      for (var i = 0; i < clusters.length; i++)
        SpokeRequest(
          angle: angleForSpan(kept[i].year, kMinYear, kMaxYear),
          scripture: kept[i].basis != 'conventional',
          title: kept[i].titleFor(locale),
          ref: kept[i].refs.isEmpty ? '' : kept[i].refs.first,
          badge: clusters[i].hidden == 0 ? '' : '+${clusters[i].hidden}',
        )
    ],
    rBands: rBands,
    rRim: rRim,
    titleSize: titleSize,
    refSize: titleSize * 0.86,
    measure: _measure,
    minGap: minGap,
    lineHeight: titleSize * 1.35,
  );

  final events = <({List<Offset> box, String text})>[];
  for (final s in spokes) {
    if (!s.hasText && s.badge.isEmpty) continue;
    final text = s.title.isEmpty ? s.badge : s.title;
    events.add((
      box: _rayBox(c, s.label.angle, s.label.rStart, s.label.rEnd,
          _tp(text, titleSize).height),
      text: text,
    ));
  }

  final axis = <({List<Offset> box, String text, int year, bool onRing})>[];
  for (final l in planAxisLabels(
    minYear: kMinYear,
    maxYear: kMaxYear,
    tickLabel: (y) => centuryTickLabel(y, locale),
    endLabel: (y) => yearLabel(y, locale),
    endSwing: kAxisEndSwing,
  )) {
    final tp = _tp(l.text, l.onRing ? titleSize : endSize);
    final List<Offset> box;
    if (l.onRing) {
      final r = ringLabelRadius(
          rRim: rRim, clearance: kAxisLabelClearance, height: tp.height);
      // The painter flips on the lower half so the run reads with its
      // top outward; a flipped box occupies the same area, so the box
      // is built from the unflipped tangent either way.
      box = _rotatedBox(
          c + Offset(math.cos(l.angle), math.sin(l.angle)) * r,
          l.angle + math.pi / 2,
          tp.width,
          tp.height);
    } else {
      final r = axialLabelRadius(
        angle: l.angle,
        rRim: rRim,
        width: tp.width,
        height: tp.height,
        clearance: kAxisLabelClearance,
      );
      box = _axisBox(c + Offset(math.cos(l.angle), math.sin(l.angle)) * r,
          tp.width, tp.height);
    }
    axis.add((box: box, text: l.text, year: l.year, onRing: l.onRing));
  }

  return (centre: c, rRim: rRim, side: side, axis: axis, events: events);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;

  setUpAll(() async {
    await _load('Roboto', 'assets/fonts/Roboto-VariableFont_wdth,wght.ttf');
    await _load('NotoSansSC-Sub', 'assets/fonts/NotoSansSC-Sub.otf');
    data = await WheelHistoryService.instance.load();
  });

  test('the control: the real faces are loaded, not the stand-in', () {
    expect(_measure('iiii', 20), lessThan(_measure('WWWW', 20)),
        reason: 'Roboto is proportional; a stand-in face is not');
    expect(_measure('王王', 20), greaterThan(_measure('ii', 20) * 2),
        reason: 'Han is charged about an em; a stand-in charges a column');
  });

  test('the control: the instrument can see an overlap at all', () {
    final a = _axisBox(const Offset(100, 100), 40, 12);
    expect(_overlap(a, _axisBox(const Offset(110, 100), 40, 12)), isTrue);
    expect(_overlap(a, _axisBox(const Offset(200, 100), 40, 12)), isFalse);
    // A rotated run through the same point must still register.
    expect(
        _overlap(a, _rotatedBox(const Offset(100, 100), 1.0, 40, 12)), isTrue);
  });

  group('axialLabelRadius is the support function, not a margin', () {
    test('it agrees with a brute-force projection of the box', () {
      final rnd = math.Random(4004);
      for (var i = 0; i < 400; i++) {
        final angle = rnd.nextDouble() * 4 * math.pi - 2 * math.pi;
        final w = 4 + rnd.nextDouble() * 90;
        final h = 4 + rnd.nextDouble() * 30;
        const rRim = 400.0;
        const clearance = 9.0;
        final r = axialLabelRadius(
            angle: angle,
            rRim: rRim,
            width: w,
            height: h,
            clearance: clearance);
        final centre =
            Offset(math.cos(angle), math.sin(angle)) * r + const Offset(0, 0);
        // Every corner, projected onto the ray, must be at or beyond
        // rRim + clearance — and the nearest one must sit exactly on it,
        // or the function is padding rather than measuring.
        var nearest = double.infinity;
        for (final o in _axisBox(centre, w, h)) {
          nearest = math.min(
              nearest, o.dx * math.cos(angle) + o.dy * math.sin(angle));
        }
        expect(nearest, closeTo(rRim + clearance, 1e-9));
      }
    });

    test('the old constant was smaller than the reach it had to cover', () {
      // The label the photograph caught, at the size and canvas it was
      // photographed on. This is the defect stated as a number.
      final tp = _tp('主前2500', _labelPx);
      final angle = angleForSpan(-2500, kMinYear, kMaxYear);
      const rRim = 900.0 * _bandsToRim;
      final needed = axialLabelRadius(
          angle: angle,
          rRim: rRim,
          width: tp.width,
          height: tp.height,
          clearance: 0);
      expect(needed - rRim, greaterThan(11.0),
          reason: 'the constant it replaced was 11 units');
      expect(needed - rRim, greaterThan(22.0),
          reason: 'and 22 on the staggered ring, which did not save it '
              'either — the stagger was never the fix');
    });
  });

  group('ringLabelRadius keeps the run clear both ways', () {
    test('its inner edge is exactly the clearance asked for', () {
      final rnd = math.Random(1215);
      for (var i = 0; i < 400; i++) {
        final angle = rnd.nextDouble() * 4 * math.pi - 2 * math.pi;
        final w = 4 + rnd.nextDouble() * 90;
        final h = 4 + rnd.nextDouble() * 30;
        const rRim = 400.0;
        const clearance = 9.0;
        final r =
            ringLabelRadius(rRim: rRim, clearance: clearance, height: h);
        final centre = Offset(math.cos(angle), math.sin(angle)) * r;
        final box =
            _rotatedBox(centre, angle + math.pi / 2, w, h);
        expect(_nearestToCentre(Offset.zero, box),
            greaterThanOrEqualTo(rRim + clearance - 0.01));
        expect(_farthestFromCentre(Offset.zero, box),
            closeTo(ringLabelOuterReach(radius: r, width: w, height: h), 0.5));
      }
    });

    test('lying along the ring is what makes it fit at all', () {
      // The claim in `ringLabelRadius`'s own comment, checked rather
      // than asserted in prose: a horizontal 主后1000 does not fit
      // outside this rim at an ordinary canvas size, and the run laid
      // along the ring does, with room to spare.
      const side = 900.0;
      const rRim = side * _bandsToRim;
      final tp = _tp('主后1000', _labelPx);
      final angle = angleForSpan(1000, kMinYear, kMaxYear);
      final c = const Offset(side / 2, side / 2);

      final horizontal = _axisBox(
          c +
              Offset(math.cos(angle), math.sin(angle)) *
                  axialLabelRadius(
                      angle: angle,
                      rRim: rRim,
                      width: tp.width,
                      height: tp.height,
                      clearance: kAxisLabelClearance),
          tp.width,
          tp.height);
      expect(_farthestFromCentre(c, horizontal), greaterThan(side / 2),
          reason: 'horizontal placement runs off the square the Stack '
              'clips to — which is why the century labels lie along '
              'the ring instead');

      final r = ringLabelRadius(
          rRim: rRim, clearance: kAxisLabelClearance, height: tp.height);
      final onRing = _rotatedBox(
          c + Offset(math.cos(angle), math.sin(angle)) * r,
          angle + math.pi / 2,
          tp.width,
          tp.height);
      expect(_farthestFromCentre(c, onRing), lessThan(side / 2 - 10),
          reason: 'and the ring run fits with room left over');
    });
  });

  test('no scale label prints through an event label', () {
    var pairs = 0;
    var checked = 0;
    final worst = <String>[];
    for (final locale in _locales) {
      for (final side in _sizes) {
        for (final zoom in _zooms) {
          final cell = _cell(data, locale, side, zoom);
          for (final a in cell.axis) {
            for (final e in cell.events) {
              checked++;
              if (_overlap(a.box, e.box)) {
                pairs++;
                if (worst.length < 6) {
                  worst.add('$locale ${side.toInt()}px ${zoom}x: '
                      '"${a.text}" through "${e.text}"');
                }
              }
            }
          }
        }
      }
    }
    expect(checked, greaterThan(20000),
        reason: 'the sweep must actually reach both families');
    expect(pairs, isZero, reason: worst.join('\n'));
  });

  test('no scale label reaches inside the rim', () {
    var checked = 0;
    for (final locale in _locales) {
      for (final side in _sizes) {
        for (final zoom in _zooms) {
          final cell = _cell(data, locale, side, zoom);
          for (final a in cell.axis) {
            checked++;
            expect(_nearestToCentre(cell.centre, a.box),
                greaterThanOrEqualTo(cell.rRim + kAxisLabelClearance - 0.05),
                reason: '$locale ${side.toInt()}px ${zoom}x: "${a.text}" '
                    'reaches inside the rim');
          }
        }
      }
    }
    // 13 since `kMinYear` moved to -4200 to hold a creation the chain
    // now puts at -4114: the tick loop skips `kMinYear` itself, so
    // -4000 is a label now where it used to be the axis start.
    expect(checked, equals(_locales.length * _sizes.length * _zooms.length * 15),
        reason: '13 century ticks and 2 axis ends in every cell');
  });

  test('no scale label prints through another one', () {
    var pairs = 0;
    final worst = <String>[];
    for (final locale in _locales) {
      for (final side in _sizes) {
        for (final zoom in _zooms) {
          final cell = _cell(data, locale, side, zoom);
          for (var i = 0; i < cell.axis.length; i++) {
            for (var j = i + 1; j < cell.axis.length; j++) {
              if (_overlap(cell.axis[i].box, cell.axis[j].box)) {
                pairs++;
                if (worst.length < 6) {
                  worst.add('$locale ${side.toInt()}px ${zoom}x: '
                      '"${cell.axis[i].text}" and "${cell.axis[j].text}"');
                }
              }
            }
          }
        }
      }
    }
    // AD 2000 is 26 years from the AD 2026 end, which is 1.4 degrees.
    // That pair is the whole reason `kAxisEndSwing` is 0.10 and not the
    // 0.055 it was.
    expect(pairs, isZero, reason: worst.join('\n'));
  });

  test('no scale label is clipped by the square the Stack draws in', () {
    for (final locale in _locales) {
      for (final side in _sizes) {
        for (final zoom in _zooms) {
          final cell = _cell(data, locale, side, zoom);
          for (final a in cell.axis) {
            for (final o in a.box) {
              expect(o.dx, inInclusiveRange(0, side),
                  reason: '$locale ${side.toInt()}px ${zoom}x: "${a.text}" '
                      'runs off the canvas horizontally');
              expect(o.dy, inInclusiveRange(0, side),
                  reason: '$locale ${side.toInt()}px ${zoom}x: "${a.text}" '
                      'runs off the canvas vertically');
            }
          }
        }
      }
    }
  });

  group('the tick at the origin', () {
    test('does not print a year that never existed', () {
      for (final locale in _locales) {
        final label = centuryTickLabel(0, locale);
        expect(label, isNot(equals(yearLabel(0, locale))),
            reason: 'AD 0 / 主后0 names a year the BC-AD reckoning '
                'does not have');
        expect(label, isNot(contains('0')));
      }
      expect(centuryTickLabel(0, 'en'), equals('BC | AD'));
      expect(centuryTickLabel(0, 'zh-Hans'), equals('主前｜主后'));
      expect(centuryTickLabel(0, 'zh-Hant'), equals('主前｜主後'));
    });

    test('every other tick is still its year, unchanged', () {
      for (final locale in _locales) {
        for (var y = -4000; y <= 2000; y += 500) {
          if (y == 0) continue;
          expect(centuryTickLabel(y, locale), equals(yearLabel(y, locale)));
          expect(parseWheelYears(centuryTickLabel(y, locale)), contains(y),
              reason: 'the parser accepts every YEAR the wheel prints');
        }
      }
    });

    test('and no record anywhere carries year 0', () {
      // This is what makes `yearLabel(0)` unreachable and so leaves it
      // alone. If a record ever does carry 0 this fires, and the
      // question of what that record MEANS has to be answered before
      // the label can be.
      expect([for (final e in data.events) e.year], isNot(contains(0)));
      for (final p in data.powers) {
        expect(p.start, isNot(equals(0)), reason: p.id);
        expect(p.end, isNot(equals(0)), reason: p.id);
      }
    });

    test('the boundary label is deliberately not searchable', () {
      // `wheel_search.dart` promises the parser accepts everything the
      // wheel prints. This is the one exemption, and it is written down
      // in both places rather than discovered by a failing round-trip.
      for (final locale in _locales) {
        expect(parseWheelYears(centuryTickLabel(0, locale)), isEmpty);
      }
    });
  });
}
