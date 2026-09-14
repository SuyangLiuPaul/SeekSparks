import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Character widths for the chronology wheel, laid out once and kept.
///
/// 2026-09-15, from 「performance也要快」.
///
/// THE COST THIS REMOVES. The wheel sets its power names and event
/// titles along an arc, which means placing each character individually
/// — there is no way to draw a curved run of text in one call. The way
/// that was written, `_tangentialLabel` built and laid out a
/// `TextPainter` per character to MEASURE the run, and `_charsOnArc`
/// then built and laid out one more per character to DRAW it. A
/// six-character Chinese power name is twelve `TextPainter.layout()`
/// calls; there are 231 powers and 745 events on the chart, and every
/// one of those layouts was repeated on every single frame of a pan or
/// a pinch.
///
/// None of it depends on the frame. 「羅」 at 11 px is the same width
/// this frame that it was last frame, and the chart's vocabulary is
/// small and deeply repetitive — 王, 國, 朝, 帝 recur across dozens of
/// names. So the width is computed once per (character, size, weight)
/// and kept.
///
/// WHY NOT A CACHED `TextPainter`. Caching the laid-out `TextPainter`
/// would save the draw pass too, and is wrong: a `TextPainter` is
/// mutable, carries its own paint state, and is not safe to hand to two
/// canvases — the wheel and the strip are on screen together in a split
/// view. What IS safe is a `ui.Paragraph`: immutable once laid out, and
/// drawable any number of times on any canvas with `drawParagraph`. So
/// both halves are cached — [widthOf] for the measuring pass and
/// [glyphOf] for the drawing pass — and a warm frame lays out nothing
/// at all.
///
/// THE BOUND. The wheel divides its font size by a continuous zoom, so
/// the size key is a float that changes on every pinch frame. Without a
/// cap this would be a leak with extra steps. [maxEntries] is a plain
/// LRU bound; sizes are quantised to a tenth of a pixel first, which is
/// far finer than any visible difference and collapses a pinch's worth
/// of near-identical sizes onto one entry.
class WheelTextMetrics {
  WheelTextMetrics._();

  /// Enough for the whole chart's vocabulary at a dozen sizes: the
  /// dataset holds roughly 1,400 distinct characters across three
  /// locales.
  static const int maxEntries = 20000;

  static final LinkedHashMap<int, double> _widths = LinkedHashMap<int, double>();

  /// One laid-out glyph, ready to draw. Keyed like [_widths] plus the
  /// colour, because colour is baked into a Paragraph and cannot be
  /// changed after the fact the way a Paint can.
  static final LinkedHashMap<int, ui.Paragraph> _glyphs =
      LinkedHashMap<int, ui.Paragraph>();

  static int _layouts = 0;

  /// How many `TextPainter.layout()` calls this cache has actually made.
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
  /// [style] is read for size and weight only — the wheel draws all of
  /// this text in one family, and colour and alpha do not move a glyph.
  static double widthOf(String character, TextStyle style) {
    final size = ((style.fontSize ?? 14) * 10).round();
    final weightValue = (style.fontWeight ?? FontWeight.normal).value;
    final key = Object.hash(character, size, weightValue);

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
    final size = ((style.fontSize ?? 14) * 10).round();
    final weight = (style.fontWeight ?? FontWeight.normal).value;
    final colour = (style.color ?? const Color(0xFF000000)).toARGB32();
    final key = Object.hash(character, size, weight, colour, style.fontFamily);

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
