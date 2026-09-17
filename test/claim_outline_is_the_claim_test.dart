/// The outline drawn on hover must BE the shape that was claimed.
///
/// 2026-09-17 「这些是什么 为什么很多没有做好」, of a screenshot at 332%
/// with a 270-pixel ring sitting over blank paper.
///
/// A picture of the claim that is not the claim is worse than no
/// picture: it is the same lie the plate used to tell, now drawn on the
/// chart, and it is drawn with more authority than a word.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/radial_chronology_layout.dart';

void main() {
  const c = Offset(200, 200);

  test('a band is outlined as the band', () {
    final path = claimOutlinePath(
      centre: c,
      a0: 0,
      a1: math.pi / 2,
      radius: 100,
      halfDepth: 10,
      zoom: 4,
    );
    final b = path.getBounds();
    // A quarter turn from due east to due south, 90 to 110 out: it
    // should span that quadrant and no more.
    expect(b.width, closeTo(110, 2));
    expect(b.height, closeTo(110, 2));
  });

  test('a tick is outlined along its own bearing, not as a disc', () {
    // THE DEFECT, AS ARITHMETIC. An event whose label is drawn reports a
    // halfDepth of half that label's radial run — 40 units here. Drawn
    // as a circle of that radius it is 80 units across, which at 332% is
    // 265 screen pixels of ring over empty paper. Drawn as what it is,
    // it is a 80-unit line one bearing wide.
    final path = claimOutlinePath(
      centre: c,
      a0: 0,
      a1: 0,
      radius: 100,
      halfDepth: 40,
      zoom: 3.32,
    );
    final b = path.getBounds();
    expect(b.height, lessThan(1),
        reason: 'a claim with no angular sweep has no angular extent; '
            'height ${b.height} means it was drawn as a disc again');
    expect(b.width, closeTo(80, 1),
        reason: 'and its radial extent is exactly the depth it claims');
  });

  test('a mark with no extent gets the pointer, not nothing and not more',
      () {
    for (final zoom in [1.0, 10.0, 40.0]) {
      final path = claimOutlinePath(
        centre: c,
        a0: 0,
        a1: 0,
        radius: 100,
        halfDepth: 0,
        zoom: zoom,
      );
      final b = path.getBounds();
      // Constant on the SCREEN, which is the whole lesson of this file:
      // a 14-unit ring at 40x would be 560 pixels.
      expect(b.width * zoom, closeTo(14, 0.5));
    }
  });
}
