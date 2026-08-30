import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/font_catalog.dart';

void main() {
  test('canvasTextStyle carries the bundled CJK face', () {
    final st = canvasTextStyle(fontSize: 12);
    expect(st.fontFamilyFallback, kCjkFontFallback);
    expect(st.fontFamilyFallback, contains('NotoSansSC-Sub'));
    expect(st.fontFamily, isNull); // the chain, never a pinned family
    expect(st.fontSize, 12);
  });

  test('canvasTextStyle passes colour and weight through', () {
    final st = canvasTextStyle(
        color: const Color(0xFF123456), fontSize: 9, fontWeight: FontWeight.w600);
    expect(st.color, const Color(0xFF123456));
    expect(st.fontWeight, FontWeight.w600);
    expect(st.fontFamilyFallback, kCjkFontFallback);
  });

  test('no TextPainter on the chronology wheel is handed a bare TextStyle',
      () {
    final lines =
        File('lib/pages/radial_chronology_page.dart').readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].contains('TextPainter(')) continue;
      final window = lines.sublist(i, min(i + 15, lines.length)).join('\n');
      // `canvasTextStyle(` itself contains the substring `TextStyle(`, so
      // strip converted sites out before checking for a BARE `TextStyle(`.
      final bare = window.replaceAll('canvasTextStyle(', '');
      expect(bare.contains('TextStyle('), isFalse,
          reason:
              'line ${i + 1}: a TextPainter inherits no theme; use canvasTextStyle');
    }
  });

  test("the wheel's canvas styles all come from canvasTextStyle", () {
    final src = File('lib/pages/radial_chronology_page.dart').readAsStringSync();
    final count = 'canvasTextStyle('.allMatches(src).length;
    expect(count, 8,
        reason:
            'expected 8 canvasTextStyle( call sites (measure, measure-chars, '
            'band name, spoke title, spoke ref, spoke badge, arc text, shared '
            'painter) — a genuine new canvas label should raise this number '
            'in the same commit that adds it');
  });
}
