import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shaped runs and curved-label glyphs reused by the chronology wheel.
///
/// Both planning and painting use this cache. A width-only cache in the
/// painter left every arc fitting pass laying out the same characters
/// again, and radial titles and axis labels still built fresh painters.
/// Immutable paragraphs can be drawn repeatedly and are disposed on LRU
/// eviction. Exact text/style keys avoid hash collisions and preserve
/// small canvas sizes: a tenth of a canvas pixel becomes 12 screen
/// pixels at the wheel's 120x zoom, so size rounding is not harmless.
class WheelTextMetrics {
  WheelTextMetrics._();

  /// Enough for the whole chart's vocabulary at a dozen sizes: the
  /// dataset holds roughly 1,400 distinct characters across three
  /// locales.
  static const int maxEntries = 20000;

  static final LinkedHashMap<(String, TextStyle), double> _widths =
      LinkedHashMap<(String, TextStyle), double>();

  /// A paragraph owns its paint colour as well as its shaped metrics.
  /// The complete style therefore participates in its cache key.
  static final LinkedHashMap<(String, TextStyle), ui.Paragraph> _glyphs =
      LinkedHashMap<(String, TextStyle), ui.Paragraph>();

  static int _layouts = 0;

  /// How many text layouts (TextPainter or Paragraph) the cache made.
  /// Read by `test/wheel_paint_cost_test.dart`; the wheel never uses it.
  static int get layoutsForTest => _layouts;
  static int get entriesForTest => _widths.length;
  static void resetStatsForTest() {
    _layouts = 0;
    _widths.clear();
    for (final g in _glyphs.values) {
      g.dispose();
    }
    _glyphs.clear();
  }

  /// Zero the counter and KEEP the cache — the only way to measure what
  /// a second frame costs given a warm first one.
  static void zeroCounterForTest() => _layouts = 0;

  /// The advance width of one character in [style].
  ///
  /// Text and the complete style form the key, including the CJK fallback.
  /// This also accepts a whole shaped run for radial and axis labels.
  static double widthOf(String character, TextStyle style) {
    final key = (character, style);

    final hit = _widths.remove(key);
    if (hit != null) {
      // Re-inserting is what makes this an LRU rather than a
      // first-in-first-out: the characters the chart draws constantly
      // stay, and a size the reader pinched past once falls out.
      _widths[key] = hit;
      return hit;
    }

    // The style arrives from `canvasTextStyle`, which sets
    // `fontFamilyFallback: kCjkFontFallback` — measuring without it
    // would return a tofu-box width and the arc would be laid out for
    // glyphs the device never draws.
    final painter = TextPainter(
      text: TextSpan(text: character, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _layouts++;
    final width = painter.width;
    painter.dispose();

    if (_widths.length >= maxEntries) {
      _widths.remove(_widths.keys.first);
    }
    _widths[key] = width;
    return width;
  }

  /// The total advance of [text] in [style], character by character —
  /// which is what an arc run measures, since it is placed one glyph at
  /// a time and never kerned.
  static double runWidth(String text, TextStyle style) {
    var total = 0.0;
    for (final ch in text.characters) {
      total += widthOf(ch, style);
    }
    return total;
  }

  /// The kerning-aware width of a horizontal or radial text run.
  static double shapedWidth(String text, TextStyle style) =>
      widthOf(text, style);

  /// A whole line uses the same paragraph cache as a curved-label glyph.
  static ui.Paragraph paragraphOf(String text, TextStyle style) =>
      glyphOf(text, style);

  /// One character, laid out and ready for `canvas.drawParagraph`.
  ///
  /// The draw half of the saving. `_charsOnArc` places a curved run one
  /// glyph at a time — there is no call that draws text along an arc —
  /// so this is called once per character per label per frame, which is
  /// about 8,000 times on this chart. Building a `TextPainter` each time
  /// was most of a frame's budget.
  ///
  /// Returned Paragraphs are owned by this cache and must NOT be
  /// disposed by the caller; they are disposed on eviction.
  static ui.Paragraph glyphOf(String character, TextStyle style) {
    final key = (character, style);

    final hit = _glyphs.remove(key);
    if (hit != null) {
      _glyphs[key] = hit;
      return hit;
    }

    // The fallback rides on the pushed `ui.TextStyle`, not on the
    // `ui.ParagraphStyle` — `ParagraphStyle` has no such parameter, and
    // `style.getTextStyle()` carries the family AND the
    // `fontFamilyFallback` the caller set — which for this chart is
    // `kCjkFontFallback`, and without it every Han character on the
    // wheel would draw as a tofu box on a device whose default face has
    // no CJK coverage. `test/canvas_cjk_fallback_ratchet_test.dart`
    // censuses every canvas painter in the app for exactly this, and
    // this cache is one of them.
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: style.fontFamily,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    ))
      ..pushStyle(style.getTextStyle())
      ..addText(character);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
    _layouts++;

    if (_glyphs.length >= maxEntries) {
      final oldest = _glyphs.keys.first;
      _glyphs.remove(oldest)?.dispose();
    }
    _glyphs[key] = paragraph;
    return paragraph;
  }
}
