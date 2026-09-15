import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;

/// One immutable paragraph, reusable by the strip's three canvases.
class StripPaintText {
  StripPaintText._(this._paragraph, this.width, this.height);

  final ui.Paragraph _paragraph;
  final double width;
  final double height;

  void paint(Canvas canvas, Offset offset) =>
      canvas.drawParagraph(_paragraph, offset);
}

/// Bounded layout cache for straight timeline labels.
///
/// A horizontal pan changes where a title is drawn, not its glyphs.
/// Keeping a Paragraph saves both measuring and painting layouts; a
/// mutable TextPainter would share paint state between the ruler, lane
/// headers and timeline. The key includes the complete style and width,
/// so changing theme, language, size or ellipsis constraints cannot
/// reuse a line prepared for another appearance.
class StripPaintTextCache {
  StripPaintTextCache._();

  static const int maxEntries = 4096;
  static final _entries = <({
    String text,
    TextStyle style,
    double width,
    String? ellipsis,
    int? maxLines,
  }),
      StripPaintText>{};
  static int _layouts = 0;

  static int get layoutsForTest => _layouts;
  static int get entriesForTest => _entries.length;

  static void resetForTest() {
    for (final line in _entries.values) {
      line._paragraph.dispose();
    }
    _entries.clear();
    _layouts = 0;
  }

  static void zeroCounterForTest() => _layouts = 0;

  static StripPaintText layout({
    required String text,
    required TextStyle style,
    double maxWidth = double.infinity,
    String? ellipsis,
    int? maxLines = 1,
  }) {
    // Canvas text has no inherited font chain. Keep the bundled CJK
    // face here too, so a new call site cannot cache missing glyphs.
    final resolved = style.copyWith(fontFamilyFallback: kCjkFontFallback);
    final key = (
      text: text,
      style: resolved,
      width: maxWidth,
      ellipsis: ellipsis,
      maxLines: maxLines,
    );
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: resolved.fontFamily,
      fontSize: resolved.fontSize,
      fontWeight: resolved.fontWeight,
      fontStyle: resolved.fontStyle,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: ellipsis,
    ))
      ..pushStyle(resolved.getTextStyle())
      ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
    _layouts++;
    final line = StripPaintText._(
        paragraph, math.min(paragraph.longestLine, maxWidth), paragraph.height);
    if (_entries.length >= maxEntries) {
      _entries.remove(_entries.keys.first)!._paragraph.dispose();
    }
    _entries[key] = line;
    return line;
  }
}
