/// The overlap the owner photographed: three power names printed on top
/// of each other, because `_buildArcs` put every power on its stream's
/// ring with no packing and no overlap check, and `_paintArcs` centred
/// each name on its own arc's full sweep knowing nothing about any
/// neighbour. Measured over `assets/wheel_history.json`: 226 powers
/// across 21 of 22 streams produce 327 overlapping PAIRS OF ARCS, with
/// depth 8 in europe, 6 in church and rome, 5 in greece, 4 in americas
/// and world — the numbers `_buildArcs`'s own doc comment cites for why
/// sub-ringing was rejected (a stream ring is 6.95 canvas units at
/// 900 px; eight sub-rings of it would be 0.87).
///
/// Two placements are mirrored here, both built from the same public
/// primitives `radial_chronology_layout.dart` exports so this file never
/// reaches into the page's private members — the same discipline
/// `wheel_arc_label_behaviour_test.dart` already keeps, with the same
/// risk: a mirror can drift from what ships. `_placeOld` is a literal
/// transcription of what `_paintArcs` did before 2026-09-04 — one
/// `fitArcLabel` call per arc, against that arc's own full sweep, in
/// the file's own data order, each name centred on its own arc with no
/// memory of any other. `_placeNew` is a transcription of `_buildArcs`
/// as it stands after this pass — ring ascending, span descending
/// within the ring, each name asking `arcNameRoom`/`placeArcName` for
/// the widest stretch its OWN arc's neighbours-so-far have not already
/// claimed. Neither mirror touches `nearestArcAt`, `fitArcLabel`,
/// `arcNameRoom`, `placeArcName`, `ringRadii` or `angleForSpan` — every
/// one of those is unmodified by this pass, so `_placeOld`'s answer is
/// the answer `main` gives today, not a guess about it.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';

const _family = 'Roboto';
const _fallback = ['NotoSansSC-Sub'];

// Mirrored from radial_chronology_page.dart: _kHubFrac, _kBandsFrac,
// _kLabelPx (the rim font the page hands `_buildArcs`/`_paintArcs`),
// kMinYear, kMaxYear, and _labelScale. See that file's own comment on
// why -4200 and not -4000.
const double _hubFrac = 0.115;
const double _bandsFrac = 0.285;
const double _rimFont = 10.5;
const int _minYear = -4200;
const int _maxYear = 2026;
double _labelScale(double zoom) => math.sqrt(zoom);

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
/// never the shaped width of the whole string. Same rule, same helper
/// name, as the sibling label-behaviour test.
double _measureChars(String s, double size) {
  var total = 0.0;
  for (final ch in s.characters) {
    total += _paint(ch, size).width;
  }
  return total;
}

/// One placed label: which power, which ring, and the angular span its
/// drawn text actually occupies.
typedef _Placed = ({String id, int ring, double a0, double a1});

/// The pre-2026-09-04 placement: one `fitArcLabel` call per arc against
/// its OWN full sweep, in the data's own order, centred with no memory
/// of any other arc — the exact arithmetic `_tangentialLabel` used to
/// centre a name in `[a0, a0 + sweep]`: `angular = measure(name, size) /
/// radius`, start at `a0 + (sweep - angular) / 2`.
List<_Placed> _placeOld(
  WheelHistoryData data,
  double side,
  String locale,
  double zoom,
) {
  final rHub = side * _hubFrac, rBands = side * _bandsFrac;
  final n = data.streams.length;
  final ringOf = {for (var i = 0; i < n; i++) data.streams[i].id: i};
  final titleSize = _rimFont / _labelScale(zoom);
  final maxEm = ringPitch(n, rHub, rBands) * kArcLabelPitchFraction;

  final out = <_Placed>[];
  for (final p in data.powers) {
    final ring = ringOf[p.stream];
    if (ring == null) continue;
    final band = ringRadii(ring, n, rHub, rBands);
    final a0 = angleForSpan(p.start, _minYear, _maxYear);
    final a1 = angleForSpan(p.endFor(_maxYear), _minYear, _maxYear);
    final name = p.nameFor(locale);
    final size = fitArcLabel(
      text: name,
      radius: band.centre,
      sweep: a1 - a0,
      maxEm: maxEm,
      desiredSize: titleSize,
      zoom: zoom,
      floorPx: kArcLabelFloorPx,
      measure: _measureChars,
    );
    if (size <= 0) continue;
    final angular = _measureChars(name, size) / band.centre;
    final start = a0 + ((a1 - a0) - angular) / 2;
    out.add((id: p.id, ring: ring, a0: start, a1: start + angular));
  }
  return out;
}

/// The fixed placement: [_RadialChronologyPageState._buildArcs] read
/// back into a test. Ring ascending, span descending within the ring —
/// so a long-lived power picks the widest free stretch of its own arc
/// first — then `arcNameRoom`/`placeArcName` place every shorter power
/// after it in whatever the earlier ones left free, all within the same
/// ring's occupied list.
List<_Placed> _placeNew(
  WheelHistoryData data,
  double side,
  String locale,
  double zoom,
) {
  final rHub = side * _hubFrac, rBands = side * _bandsFrac;
  final n = data.streams.length;
  final ringOf = {for (var i = 0; i < n; i++) data.streams[i].id: i};
  final titleSize = _rimFont / _labelScale(zoom);
  final maxEm = ringPitch(n, rHub, rBands) * kArcLabelPitchFraction;

  final geo = <({WheelPower power, int ring, double a0, double a1})>[];
  for (final p in data.powers) {
    final ring = ringOf[p.stream];
    if (ring == null) continue;
    geo.add((
      power: p,
      ring: ring,
      a0: angleForSpan(p.start, _minYear, _maxYear),
      a1: angleForSpan(p.endFor(_maxYear), _minYear, _maxYear),
    ));
  }
  geo.sort((a, b) => a.ring != b.ring
      ? a.ring.compareTo(b.ring)
      : (b.a1 - b.a0).compareTo(a.a1 - a.a0));

  final occupied = <int, List<ArcSpan>>{};
  final out = <_Placed>[];
  for (final arc in geo) {
    final claimed = occupied.putIfAbsent(arc.ring, () => []);
    final band = ringRadii(arc.ring, n, rHub, rBands);
    final name = arc.power.nameFor(locale);
    final room = arcNameRoom(arc.a0, arc.a1, claimed);
    final size = fitArcLabel(
      text: name,
      radius: band.centre,
      sweep: room,
      maxEm: maxEm,
      desiredSize: titleSize,
      zoom: zoom,
      floorPx: kArcLabelFloorPx,
      measure: _measureChars,
    );
    if (size <= 0) continue;
    final needed = _measureChars(name, size) / band.centre;
    final at = placeArcName(arc.a0, arc.a1, claimed, needed);
    if (at == null) continue;
    claimed.add((start: at, end: at + needed));
    out.add((id: arc.power.id, ring: arc.ring, a0: at, a1: at + needed));
  }
  return out;
}

/// Every pair of DRAWN labels, on the same ring, whose angular spans
/// overlap — `[a0, a1)` against `[a0, a1)`, the actual ink each name
/// claims, not the arc underneath it.
List<(String, String)> _overlaps(List<_Placed> placed) {
  final byRing = <int, List<_Placed>>{};
  for (final p in placed) {
    byRing.putIfAbsent(p.ring, () => []).add(p);
  }
  final out = <(String, String)>[];
  for (final ring in byRing.values) {
    ring.sort((a, b) => a.a0.compareTo(b.a0));
    for (var i = 0; i < ring.length; i++) {
      for (var j = i + 1; j < ring.length; j++) {
        if (ring[j].a0 < ring[i].a1 - 1e-9) {
          out.add((ring[i].id, ring[j].id));
        } else {
          break; // sorted by a0, so nothing further left in this ring can
          // overlap ring[i] either — every ring[k] for k>j starts even
          // later.
        }
      }
    }
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;

  setUpAll(() async {
    await _loadFace('Roboto', 'assets/fonts/Roboto-VariableFont_wdth,wght.ttf');
    await _loadFace('NotoSansSC-Sub', 'assets/fonts/NotoSansSC-Sub.otf');
    final raw = await rootBundle.loadString('assets/wheel_history.json');
    data = WheelHistoryData.fromJson(json.decode(raw) as Map<String, dynamic>);
  });

  test('the corpus this file assumes is still the one that ships', () {
    expect(data.powers.length, greaterThan(200),
        reason: 'measured 226 powers; a much smaller corpus would not '
            'exercise the overlap this test guards');
  });

  test(
      'BEFORE THE FIX: centring each name on its own full arc, blind to '
      'its neighbours, prints power names on top of each other — the '
      'defect the owner photographed', () {
    // This is `main`'s own arithmetic, transcribed rather than imported,
    // because `_paintArcs` decided placement inline and left nothing a
    // test could call. It exercises no line this pass changed —
    // `fitArcLabel`, `ringRadii` and `angleForSpan` are exactly as they
    // were — so its answer is `main`'s answer.
    final overlaps = _overlaps(_placeOld(data, 900, 'en', 1));
    // ignore: avoid_print
    print('900px @ rest, en, pre-fix placement: ${overlaps.length} '
        'overlapping label pairs out of '
        '${_placeOld(data, 900, 'en', 1).length} drawn labels');
    expect(overlaps, isNotEmpty,
        reason: 'expected the pre-fix placement to collide at 900px; if '
            'it no longer does, this mirror has drifted from what '
            '`_paintArcs` used to do and needs re-checking against it');
  });

  group('AFTER THE FIX: no two power names ever print over each other', () {
    for (final side in [700.0, 900.0, 1200.0]) {
      for (final locale in ['en', 'zh-Hans']) {
        for (final zoom in [1.0, 2.0]) {
          test('side=$side locale=$locale zoom=$zoom', () {
            final placed = _placeNew(data, side, locale, zoom);
            final overlaps = _overlaps(placed);
            expect(overlaps, isEmpty,
                reason: '${overlaps.length} overlapping pairs: '
                    '${overlaps.take(5)}');
          });
        }
      }
    }
  });

  test('at 900px at rest, how many of the 226 power names are drawn — '
      'before and after', () {
    // Not a pass/fail gate on its own: `expect` here is a hard floor
    // documenting the real cost of no longer letting a short arc's name
    // sit wherever `fitArcLabel` centred it, even when that meant
    // printing through its neighbour. Reported to the owner rather than
    // asserted tightly, because the honest number moves with the corpus
    // and the fonts, not because it does not matter.
    final before = _placeOld(data, 900, 'en', 1).length;
    final after = _placeNew(data, 900, 'en', 1).length;
    // ignore: avoid_print
    print('900px @ rest, en: before=$before after=$after of '
        '${data.powers.length} powers');
    final beforeZh = _placeOld(data, 900, 'zh-Hans', 1).length;
    final afterZh = _placeNew(data, 900, 'zh-Hans', 1).length;
    // ignore: avoid_print
    print('900px @ rest, zh-Hans: before=$beforeZh after=$afterZh of '
        '${data.powers.length} powers');
    expect(after, greaterThan(0));
  });

  test('a dropped name is not a dropped power: every power on a stream '
      'is still findable and still says its own years', () {
    // The recoverability this pass leans on. `showStream` (in
    // `wheel_sheets.dart`) lists every power `data.powersOf(stream.id)`
    // returns, by name and year span, whether or not that power's ring
    // label survived `_buildArcs`'s placement — and the arc itself keeps
    // its own `a0`/`a1` regardless of whether its name drew, so tapping
    // its own stretch of the band still reaches `showPower` through
    // `nearestArcAt`. This test only pins the data-level half of that
    // claim — that the stream/power relationship `showStream` reads is
    // exactly the one `_buildArcs` places arcs from — since the sheet
    // itself is a widget this file does not build.
    for (final s in data.streams) {
      final onStream = data.powers.where((p) => p.stream == s.id);
      for (final p in onStream) {
        expect(p.nameFor('en'), isNotEmpty);
        expect(p.start, isNotNull);
      }
    }
  });
}
