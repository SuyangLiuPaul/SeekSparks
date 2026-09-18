import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_sword/utils/strip_chronology_layout.dart';
import 'package:yahwehs_sword/utils/strip_viewport.dart';

void main() {
  test('fit contains both ends even in a phone time viewport', () {
    for (final width in [160.0, 216.0, 500.0, 1080.0]) {
      expect(stripContentWidth(stripFitScale(width)), closeTo(width, 1e-8));
      expect(stripOffsetForYear(2026, width, stripFitScale(width)), 0);
    }
  });
  test('zoom keeps the same fractional year at the centre', () {
    const offset = 4712.37;
    const width = 216.0;
    final before = yearForX(offset + width / 2, 1.5);
    final after = stripZoomOffset(
        offset: offset, viewportWidth: width, oldScale: 1.5, newScale: 96);
    expect(yearForX(after + width / 2, 96), closeTo(before, 1e-8));
  });
  test('fit zoom has usable steps in both directions without jumping back', () {
    const width = 216.0;
    final fit = stripFitScale(width);
    expect(stripNextScale(fit, -1, width), fit);
    final firstIn = stripNextScale(fit, 1, width);
    expect(firstIn, greaterThan(fit));
    expect(stripNextScale(firstIn, -1, width), fit);
    expect(stripNextScale(0.8, 1, width), 1.5);
    expect(stripNextScale(0.8, -1, width), 0.6);
    expect(stripNextScale(96, 1, width), 96);
  });
  test('zoom anchors clamp at the time axis edges', () {
    expect(
        stripZoomOffset(
            offset: 0, viewportWidth: 216, oldScale: 1.5, newScale: 0.15),
        0);
    expect(stripOffsetForYear(2026, 216, 96), stripContentWidth(96) - 216);
  });
}
