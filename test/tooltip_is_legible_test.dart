/// A tooltip a reader can read, in BOTH themes.
///
/// 2026-09-16 「看不清」, with the chronology chart's own 「拖动图表 · 点
/// 事件查看依据」 photographed on a phone in dark mode as pale grey text
/// on a near-white pill.
///
/// The theme set the tooltip's TEXT to white and left its background to
/// Material, whose default is `Colors.grey[700]` in a light theme and
/// `Colors.white` at 90% opacity in a dark one. So in dark mode every
/// tooltip in the app was white on white — not the chart's bug, and not
/// one tooltip.
///
/// The contrast is computed the way WCAG computes it rather than
/// eyeballed, because "these two are different colours" is exactly the
/// assertion that would have passed on white-on-white-at-90%.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/workbench_theme.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  ThemeData themeFor({required bool dark, bool paper = false}) =>
      workbenchTheme(
          ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light),
          paper: paper);

  for (final variant in const [
    (name: 'light', dark: false, paper: false),
    (name: 'dark', dark: true, paper: false),
    (name: 'paper', dark: false, paper: true),
  ]) {
    final name = variant.name;

    test('a tooltip in the $name theme clears the text contrast floor', () {
      final theme = themeFor(dark: variant.dark, paper: variant.paper);
      final tip = theme.tooltipTheme;
      final text = tip.textStyle?.color;
      expect(text, isNotNull, reason: 'the tooltip must state its colour');

      final box = tip.decoration;
      expect(box, isA<BoxDecoration>(),
          reason: 'leaving the decoration to Material is the defect: its '
              'dark default is a near-white pill');
      final fill = (box! as BoxDecoration).color;
      expect(fill, isNotNull);

      final ratio = _contrast(text!, fill!);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'tooltip text on its own background is only '
              '${ratio.toStringAsFixed(2)}:1 in the $name theme');
    });

    test('and the $name tooltip is opaque, so nothing shows through', () {
      final box = themeFor(dark: variant.dark, paper: variant.paper)
          .tooltipTheme
          .decoration! as BoxDecoration;
      expect(box.color!.a, 1.0,
          reason: 'a translucent tooltip takes its contrast from whatever '
              'it happens to be floating over');
    });
  }
}
