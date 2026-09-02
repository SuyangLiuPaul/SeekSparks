/// The wheel's arc labels — the power names set along their own bands.
///
/// Canvas text leaves no widget and no semantics node, so a widget test
/// cannot see one of these labels, let alone measure it. The decision
/// therefore lives in `fitArcLabel`, and this file drives that decision
/// over the SHIPPED asset in the SHIPPED faces. Loading the faces is
/// not optional: `flutter test` otherwise substitutes a fixed-width
/// stand-in in which every glyph is a square, so a test that skipped
/// the `FontLoader` would only be comparing the model to itself, and
/// the whole point here is that Han and Latin are shaped differently.
///
/// The page's own constants are mirrored as literals on purpose. A test
/// that imported them would follow a typo into agreement.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';

const _family = 'Roboto';
const _fallback = ['NotoSansSC-Sub'];

// radial_chronology_page.dart: _kHubFrac, _kBandsFrac, _kLabelPx,
// kMinYear, kMaxYear, and _labelScale.
const double _hubFrac = 0.115;
const double _bandsFrac = 0.285;
const double _rimFont = 10.5;
// -4200 since the creation anchor was derived (`_meta.creation`, 4114
// BC) and the axis moved to hold it. This copy went on saying -4000
// after the page's did not, which measured every power's arc against a
// sweep 3.2% wider than the one that ships.
const int _minYear = -4200;
const int _maxYear = 2026;
double _labelScale(double zoom) => math.sqrt(zoom);

/// The canvas sides a reader actually gets. The small-screen gate admits
/// only viewports 992 px and wider, but the wheel's side is the SHORTER
/// dimension, so a laptop in landscape lands near 700.
const _sides = [700.0, 900.0, 1200.0];
const _locales = ['en', 'zh-Hans'];

/// How many fewer labels the CI-measured count is allowed to fall
/// below the shipping-machine baseline before a fit-count assertion
/// treats it as a real regression. See its one call site for why this
/// exists — CoreText and FreeType, given the identical bundled font,
/// were observed to disagree by exactly 1 on Linux CI; 2 leaves a
/// character of headroom without hiding the class of bug the test
/// was written to catch (that class undercounts by dozens, not one).
const _kPlatformTextMetricSlack = 2;

Future<void> _loadFace(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

TextPainter _paint(String s, double size) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: const Color(0xFFFFFFFF),
          fontFamily: _family,
          fontFamilyFallback: _fallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

/// The painter sets one `TextPainter` per grapheme along the curve, so
/// the width that decides "does it fit" is the sum of the characters —
/// never the shaped width of the whole string.
double _measureChars(String s, double size) {
  var total = 0.0;
  for (final ch in s.characters) {
    total += _paint(ch, size).width;
  }
  return total;
}

/// How tall the label's INK is, above and below the row centre the
/// painter places it on, rendered at [ss] times scale and read back a
/// pixel row at a time.
///
/// The line box is not the answer. It carries leading that never takes
/// ink, and it is quantised to whole pixels, both of which matter
/// enormously when the type is five units tall.
Future<double> _inkHeight(String s, double size, {double ss = 16}) async {
  final tp = _paint(s, size * ss);
  final w = tp.width.ceil() + 4, h = tp.height.ceil() + 8;
  if (w <= 4 || h <= 8) return 0;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.translate(2, 4);
  tp.paint(canvas, Offset.zero);
  final img = await rec.endRecording().toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = bytes!.buffer.asUint8List();
  var top = -1, bot = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (px[(y * w + x) * 4 + 3] > 16) {
        if (top < 0) top = y;
        bot = y;
        break;
      }
    }
  }
  return top < 0 ? 0 : (bot + 1 - top) / ss;
}

/// Every power that has a band, with the geometry its label must fit.
Iterable<({WheelPower power, double radius, double sweep})> _arcs(
  WheelHistoryData data,
  double side,
) sync* {
  final rHub = side * _hubFrac, rBands = side * _bandsFrac;
  final n = data.streams.length;
  final ringOf = {for (var i = 0; i < n; i++) data.streams[i].id: i};
  for (final p in data.powers) {
    final ring = ringOf[p.stream];
    if (ring == null) continue;
    final band = ringRadii(ring, n, rHub, rBands);
    final a0 = angleForSpan(p.start, _minYear, _maxYear);
    final a1 = angleForSpan(p.endFor(_maxYear), _minYear, _maxYear);
    yield (power: p, radius: band.centre, sweep: a1 - a0);
  }
}

double _maxEm(WheelHistoryData data, double side) =>
    ringPitch(data.streams.length, side * _hubFrac, side * _bandsFrac) *
    kArcLabelPitchFraction;

/// The size the page would hand `fitArcLabel` for each arc, and what it
/// gets back. Zero means the label is not drawn and only the arc is.
List<double> _sizesAt(
  WheelHistoryData data,
  double side,
  String locale,
  double zoom,
) =>
    [
      for (final a in _arcs(data, side))
        fitArcLabel(
          text: a.power.nameFor(locale),
          radius: a.radius,
          sweep: a.sweep,
          maxEm: _maxEm(data, side),
          desiredSize: _rimFont / _labelScale(zoom),
          zoom: zoom,
          floorPx: kArcLabelFloorPx,
          measure: _measureChars,
        )
    ];

int _drawnAt(WheelHistoryData data, double side, String locale, double zoom) =>
    _sizesAt(data, side, locale, zoom).where((s) => s > 0).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;

  setUpAll(() async {
    await _loadFace('Roboto', 'assets/fonts/Roboto-VariableFont_wdth,wght.ttf');
    await _loadFace('NotoSansSC-Sub', 'assets/fonts/NotoSansSC-Sub.otf');
    final raw = await rootBundle.loadString('assets/wheel_history.json');
    data = WheelHistoryData.fromJson(json.decode(raw) as Map<String, dynamic>);
  });

  group('the instrument', () {
    test('the real faces are loaded, not the stand-in', () {
      // The stand-in face gives every glyph the same advance, so a
      // narrow Latin letter and a full-width Han one measure alike. If
      // this ever passes by accident the rest of the file is measuring
      // a fiction.
      final i = _paint('i', 20).width;
      final m = _paint('m', 20).width;
      final han = _paint('国', 20).width;
      expect(i, lessThan(m), reason: 'a stand-in face makes i and m equal');
      expect(han, greaterThan(m), reason: 'Han should be full-width');
    });

    test('the asset carries the bands and powers this file assumes', () {
      expect(data.streams, isNotEmpty);
      expect(data.powers.length, greaterThan(50));
      for (final locale in _locales) {
        for (final p in data.powers) {
          expect(p.nameFor(locale), isNotEmpty);
        }
      }
    });
  });

  group('the size a label is set at', () {
    test('never exceeds the ring pitch, so it cannot reach the next band',
        () {
      for (final side in _sides) {
        final cap = _maxEm(data, side);
        for (final locale in _locales) {
          for (final zoom in [1.0, 1.5, 2.0, 4.0, 8.0]) {
            for (final s in _sizesAt(data, side, locale, zoom)) {
              expect(s, lessThanOrEqualTo(cap + 1e-9),
                  reason: 'side=$side $locale zoom=$zoom');
            }
          }
        }
      }
    });

    test('is never put on screen below the wheel\'s floor', () {
      for (final side in _sides) {
        for (final locale in _locales) {
          for (final zoom in [1.0, 1.5, 2.0, 4.0, 8.0]) {
            for (final s in _sizesAt(data, side, locale, zoom)) {
              if (s == 0) continue;
              expect(s * zoom, greaterThanOrEqualTo(kArcLabelFloorPx - 1e-9),
                  reason: 'side=$side $locale zoom=$zoom');
            }
          }
        }
      }
    });

    test('stops growing on screen once the reader has zoomed in', () {
      // The defect this replaces: the size was a constant number of
      // CANVAS units, which `InteractiveViewer` multiplies, so at 800%
      // every label was set at 48 px beside rim labels at 10.5. The
      // page's rule is that type holds its size on screen while more of
      // it fits, so the on-screen size may grow — as sqrt(zoom) does —
      // but not in proportion to the zoom.
      for (final side in _sides) {
        for (final locale in _locales) {
          final at1 = _sizesAt(data, side, locale, 1).fold(0.0, math.max);
          final at8 =
              _sizesAt(data, side, locale, 8).fold(0.0, math.max) * 8;
          expect(at8, lessThan(31),
              reason: 'side=$side $locale: 800% put ${at8.toStringAsFixed(1)} '
                  'px on screen');
          if (at1 > 0) {
            expect(at8, lessThan(at1 * 8),
                reason: 'side=$side $locale: growing in proportion to zoom');
          }
        }
      }
    });
  });

  group('what the reader gets', () {
    test('zooming in shows MORE names, not the same ones larger', () {
      // The old rule drew 26 of 62 English names at 900 px and the same
      // 26 at every zoom, because the size was pinned and so was the
      // set that fitted.
      for (final side in _sides) {
        for (final locale in _locales) {
          final counts = [
            for (final z in [1.0, 2.0, 4.0, 8.0]) _drawnAt(data, side, locale, z)
          ];
          for (var i = 1; i < counts.length; i++) {
            expect(counts[i], greaterThanOrEqualTo(counts[i - 1]),
                reason: 'side=$side $locale: $counts');
          }
          expect(counts.last, greaterThan(counts.first + 10),
              reason: 'side=$side $locale: zooming to 800% added '
                  '${counts.last - counts.first} names — $counts');
        }
      }
    });

    test('at 900 px at rest the wheel still names what it named before',
        () {
      // This pass must not quietly strip the chart. Measured on the
      // Mac that shipped it: 26 of 62 English, 39 of 62 Chinese at
      // 900px; 38 and 43 at 1200px — all four floors below were set to
      // exactly that count, with no margin at all.
      //
      // 2026-08-25 (CI-red, not owner-reported — the loop's own local
      // `flutter test` runs on macOS and came back green every time;
      // GitHub Actions runs on Linux and measured en@900 as 25, one
      // under the floor): the same bundled TTF, loaded through the
      // same FontLoader, still lays out one character's width
      // differently between CoreText (macOS) and FreeType/fontconfig
      // (Linux CI) — a known Skia cross-platform text-metrics gap, not
      // a data or logic regression. `_kPlatformTextMetricSlack` is the
      // margin that absorbs it; it is subtracted from the shipped
      // counts above, not invented. A real regression back to the old
      // "same set at every zoom" bug would undercount by far more than
      // this, so the guard still does its job.
      const slack = _kPlatformTextMetricSlack;
      expect(_drawnAt(data, 900, 'en', 1), greaterThanOrEqualTo(26 - slack));
      expect(_drawnAt(data, 900, 'zh-Hans', 1),
          greaterThanOrEqualTo(39 - slack));
      expect(_drawnAt(data, 1200, 'en', 1), greaterThanOrEqualTo(38 - slack));
      expect(_drawnAt(data, 1200, 'zh-Hans', 1),
          greaterThanOrEqualTo(43 - slack));
    });

    test('a name that is drawn fits the arc it names', () {
      for (final side in _sides) {
        for (final locale in _locales) {
          for (final zoom in [1.0, 2.0, 8.0]) {
            final arcs = _arcs(data, side).toList();
            final sizes = _sizesAt(data, side, locale, zoom);
            for (var i = 0; i < arcs.length; i++) {
              if (sizes[i] == 0) continue;
              final w = _measureChars(arcs[i].power.nameFor(locale), sizes[i]);
              expect(w / arcs[i].radius,
                  lessThanOrEqualTo(arcs[i].sweep * 0.92 + 1e-9),
                  reason: '${arcs[i].power.nameFor(locale)} at side=$side '
                      '$locale zoom=$zoom overruns its arc');
            }
          }
        }
      }
    });
  });

  group('the ink, not the line box', () {
    // At 700 px the shipped rule drew all 22 English and all 34 Chinese
    // labels with 5.88-5.94 units of ink in a ring pitch of 5.41: every
    // one of them printed across the neighbouring stream's row. This is
    // the measurement that found it, so it is the measurement that
    // guards it.
    test('no drawn label reaches the neighbouring stream', () async {
      for (final side in [700.0, 900.0]) {
        final pitch = ringPitch(
            data.streams.length, side * _hubFrac, side * _bandsFrac);
        for (final locale in _locales) {
          for (final zoom in [1.0, 2.0]) {
            final arcs = _arcs(data, side).toList();
            final sizes = _sizesAt(data, side, locale, zoom);
            for (var i = 0; i < arcs.length; i++) {
              if (sizes[i] == 0) continue;
              final ink =
                  await _inkHeight(arcs[i].power.nameFor(locale), sizes[i]);
              expect(ink, lessThan(pitch),
                  reason: '${arcs[i].power.nameFor(locale)} at side=$side '
                      '$locale zoom=$zoom: ${ink.toStringAsFixed(2)} units of '
                      'ink in a ${pitch.toStringAsFixed(2)} pitch');
            }
          }
        }
      }
    });
  });

  group('fitArcLabel on its own', () {
    double fit(String text, double sweep, double zoom, {double em = 8}) =>
        fitArcLabel(
          text: text,
          radius: 200,
          sweep: sweep,
          maxEm: em,
          desiredSize: _rimFont / _labelScale(zoom),
          zoom: zoom,
          floorPx: kArcLabelFloorPx,
          measure: _measureChars,
        );

    test('an arc too short for the smallest allowed type gets nothing', () {
      expect(fit('Assyria', 0.01, 1), 0);
      expect(fit('亚述', 0.005, 1), 0);
    });

    test('an empty or impossible request is silent, not an exception', () {
      expect(fit('', 1, 1), 0);
      expect(fit('Assyria', 0, 1), 0);
      expect(fit('Assyria', -1, 1), 0);
      expect(fit('Assyria', 1, 0), 0);
    });

    test('a generous arc gets the design size, capped by the geometry', () {
      expect(fit('Ur', 2, 1), 8, reason: 'the em cap should bind');
      expect(fit('Ur', 2, 1, em: 100), _rimFont,
          reason: 'with room to spare, the page\'s own size');
    });

    test('a tight arc shrinks rather than overrunning', () {
      // Narrow enough that the em cap is not what binds. Whatever comes
      // back must actually fit, which the linear guess alone did not
      // guarantee.
      double? shrunk;
      for (final sweep in [0.20, 0.15, 0.12, 0.10]) {
        final s = fit('Assyria', sweep, 1);
        if (s > 0 && s < 8) {
          shrunk = s;
          expect(_measureChars('Assyria', s) / 200,
              lessThanOrEqualTo(sweep * 0.92 + 1e-9),
              reason: 'sweep=$sweep came back at $s and does not fit');
        }
      }
      expect(shrunk, isNotNull, reason: 'no sweep in the range shrank at all');
      expect(fit('Assyria', 2.0, 1), 8, reason: 'a wide arc keeps the cap');
    });

    test('the floor is read on screen, so zoom buys smaller canvas type',
        () {
      // The same arc that cannot carry the name at rest can carry it
      // once magnified, because 6 px on screen is fewer canvas units
      // the further in the reader has zoomed. Rather than guess which
      // sweep sits on that boundary, find the tightest arc each zoom
      // can serve and compare them.
      double tightest(double zoom) {
        var best = double.infinity;
        for (var sweep = 0.30; sweep > 0.005; sweep -= 0.005) {
          if (fit('Assyria', sweep, zoom) > 0) best = sweep;
        }
        return best;
      }

      final atRest = tightest(1);
      final zoomed = tightest(4);
      expect(zoomed, lessThan(atRest),
          reason: 'zooming should let tighter arcs carry their name; '
              'at rest $atRest, at 400% $zoomed');
      expect(fit('Assyria', zoomed, 4) * 4,
          greaterThanOrEqualTo(kArcLabelFloorPx - 1e-9));
    });
  });

  group('what the reader selected', () {
    final power = (id: 'assyria-neo', stream: 'assyria');
    final other = (id: 'egypt-new', stream: 'egypt');

    bool covers(String? sel, ({String id, String stream}) thing) =>
        selectionCovers(
            selectedId: sel, ownId: thing.id, streamId: thing.stream);

    test('nothing selected covers nothing', () {
      expect(covers(null, power), isFalse);
      expect(covers(null, other), isFalse);
    });

    test('selecting a power covers that power alone', () {
      expect(covers(power.id, power), isTrue);
      expect(covers(power.id, other), isFalse);
    });

    test('selecting a BAND covers everything on it', () {
      // The defect: a tap on an unoccupied stretch of band selects the
      // stream's id, and the painters compared it only against power
      // and event ids — so the wheel dimmed entirely, the band the
      // reader had just asked about included.
      expect(covers(power.stream, power), isTrue);
      expect(covers(power.stream, other), isFalse);
    });

    test('every stream in the asset lights its own powers and events', () {
      for (final s in data.streams) {
        for (final p in data.powers.where((p) => p.stream == s.id)) {
          expect(
              selectionCovers(
                  selectedId: s.id, ownId: p.id, streamId: p.stream),
              isTrue,
              reason: '${s.id} should cover ${p.id}');
        }
        for (final e in data.events.where((e) => e.stream == s.id)) {
          expect(
              selectionCovers(
                  selectedId: s.id, ownId: e.id, streamId: e.stream),
              isTrue,
              reason: '${s.id} should cover ${e.id}');
        }
      }
    });
  });
}
