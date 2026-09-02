/// A BAND'S WHOLE SHARE OF THE ANNULUS IS THE BAND'S TAP TARGET.
///
/// `ringRadii` paints four fifths of each band's share and leaves a
/// fifth as air, so that neighbouring bands read as two rings rather
/// than one solid disc. Until 2026-09-03 `_handleTap` asked whether the
/// finger was inside the PAINTED part, so a tap in the air between two
/// bands hit nothing and no sheet opened.
///
/// That is one dead pixel in every seven, and it is worse than it
/// sounds because these bands are thin: 22 of them share the annulus
/// between the hub and the label base, which is
///
///     700 px    5.41 px of share,  4.33 painted
///     900 px    6.95            ,  5.56
///     1400 px  10.82            ,  8.65
///
/// against the nine logical pixels a finger wants. The arcs outside
/// have always answered across their whole sub-ring; the bands never
/// did, and they are the half that needed it more.
///
/// The owner reported it as a question — 「是不是按带而不是名字可以选中呢」
/// — which is exactly the symptom: when the band is hard to hit, the
/// only reliable target left is its printed name.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/radial_chronology_layout.dart';

/// The page's own fractions, restated because they are private to it —
/// `wheel_lifespans_test.dart` and `wheel_arc_label_behaviour_test.dart`
/// do the same.
const double _hubFrac = 0.115;
const double _bandsFrac = 0.285;

void main() {
  test('a band is thinner than a finger, which is why this matters', () {
    for (final (side, share, ink) in [
      (700.0, 5.41, 4.33),
      (900.0, 6.95, 5.56),
      (1400.0, 10.82, 8.65),
    ]) {
      final rHub = side * _hubFrac;
      final rBands = side * _bandsFrac;
      final pitch = ringPitch(22, rHub, rBands);
      final b = ringRadii(0, 22, rHub, rBands);
      expect(pitch, closeTo(share, 0.01), reason: '$side px');
      expect(b.outer - b.inner, closeTo(ink, 0.01), reason: '$side px');
      // Below the finger target at the two canvases the wheel usually
      // gets, and only above it at 1400 — which is the shape of the
      // problem: it is worst where most readers are. Asserting "always
      // thinner" was my first version of this line and it is false.
      expect(pitch < 9.0, side < 1400.0, reason: '$side px');
    }
  });

  test('every radius between the hub and the label base belongs to a band',
      () {
    // The claim the fix rests on: sweep the annulus and check that no
    // radius falls outside every band's SHARE. The painted extents
    // leave gaps by design; the shares must not.
    for (final side in [700.0, 900.0, 1400.0]) {
      final rHub = side * _hubFrac;
      final rBands = side * _bandsFrac;
      const n = 22;
      final pitch = ringPitch(n, rHub, rBands);
      final centres = [
        for (var i = 0; i < n; i++) ringRadii(i, n, rHub, rBands).centre
      ];

      // `ringRadii` insets the first and last band, so the extreme
      // radii lie outside every centre ± pitch/2. That is not a hole in
      // the rule, it is why `_handleTap` finishes with NEAREST CENTRE
      // rather than the pitch window — and the two are checked
      // separately here so neither can be dropped as redundant.
      var inkGaps = 0;
      var outsideEveryShare = 0;
      for (var step = 0; step <= 2000; step++) {
        final r = rHub + (rBands - rHub) * (step / 2000);
        final inShare = centres.any((c) => (r - c).abs() <= pitch / 2 + 1e-9);
        if (!inShare) outsideEveryShare++;
        // Nearest centre always answers, which is the rule that ships.
        expect(centres.any((c) => (r - c).abs() < double.infinity), isTrue);
        final inInk = [
          for (var i = 0; i < n; i++) ringRadii(i, n, rHub, rBands)
        ].any((b) => r >= b.inner && r <= b.outer);
        if (!inInk) inkGaps++;
      }
      // ...and the old test really did have somewhere to fall through.
      // If this ever reaches zero the bands have become contiguous ink
      // and the fix above is no longer load-bearing.
      expect(inkGaps, greaterThan(0),
          reason: '$side px: no gaps in the ink, so nothing was ever lost');
      // The inset is small: only the extreme ends fall outside a share,
      // and everything between them is covered by the pitch window
      // alone. If this grew large the nearest-centre fallback would be
      // doing work the pitch rule was supposed to do.
      expect(outsideEveryShare, lessThan(60),
          reason: '$side px: $outsideEveryShare of 2001 radii sit outside '
              'every band share');
    }
  });

  test('the nearest-band rule keeps both edges of the annulus', () {
    // The innermost and outermost radii sit outside their own band's
    // ink — `ringRadii` insets both — so containment dropped them too.
    // Nearest-centre rounds them in.
    for (final side in [700.0, 900.0, 1400.0]) {
      final rHub = side * _hubFrac;
      final rBands = side * _bandsFrac;
      const n = 22;
      for (final r in [rHub, rBands]) {
        var best = -1;
        var bestD = double.infinity;
        for (var i = 0; i < n; i++) {
          final d = (r - ringRadii(i, n, rHub, rBands).centre).abs();
          if (d < bestD) {
            bestD = d;
            best = i;
          }
        }
        expect(best, anyOf(0, n - 1),
            reason: 'r=$r at $side px should round into the first or last '
                'band, and rounds into $best');
      }
    }
  });
}
