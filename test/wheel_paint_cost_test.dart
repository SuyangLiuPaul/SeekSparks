// What one frame of the wheel costs, measured rather than guessed.
//
// 2026-09-15. 「performance也要快而且看这些也方便不同device」. Before
// changing anything, this establishes what a paint actually costs, so
// the change can be shown to have worked rather than asserted to.
//
// The suspected cost is text. `_tangentialLabel` lays out one
// `TextPainter` PER CHARACTER to measure the run, and `_charsOnArc`
// then lays out one more per character to draw it — so a six-character
// Chinese power name is twelve `TextPainter.layout()` calls, and there
// are 231 powers and 745 events. None of that depends on the frame: the
// width of 「羅」 at 11 px is the same width it was last frame.
//
// This test does not assert a wall-clock budget — a CI runner's timing
// is not the device's. It asserts the COUNT of text layouts, which is
// the thing the code controls and the thing a cache changes.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_sword/utils/wheel_text_metrics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(WheelTextMetrics.resetStatsForTest);

  test('the per-character cache answers a repeated character without '
      'laying it out again', () {
    const style = TextStyle(fontSize: 12);
    // A Chinese name whose characters repeat, which is the common case:
    // 「王」 and 「國」 recur across dozens of power names.
    for (final ch in '西周東周春秋戰國'.characters) {
      WheelTextMetrics.widthOf(ch, style);
    }
    final first = WheelTextMetrics.layoutsForTest;
    expect(first, 7,
        reason: 'eight characters, one of which repeats (周) — seven '
            'distinct layouts');

    for (final ch in '西周東周春秋戰國'.characters) {
      WheelTextMetrics.widthOf(ch, style);
    }
    expect(WheelTextMetrics.layoutsForTest, first,
        reason: 'a second pass over the same characters laid out nothing '
            'new — this is the whole point of the cache, and the wheel '
            'repaints this text on every pan frame');
  });

  test('a different size is a different entry, because it is', () {
    WheelTextMetrics.widthOf('周', const TextStyle(fontSize: 12));
    WheelTextMetrics.widthOf('周', const TextStyle(fontSize: 24));
    expect(WheelTextMetrics.layoutsForTest, 2,
        reason: 'a cache keyed on the character alone would return a '
            '12 px width for 24 px text and the chart would overlap '
            'itself');
  });

  test('the cache does not grow without bound', () {
    // The wheel divides its font size by a continuous zoom, so without
    // a bound every pinch frame would mint a new size key and the cache
    // would be a leak with extra steps.
    for (var i = 0; i < 5000; i++) {
      WheelTextMetrics.widthOf(
          String.fromCharCode(0x4E00 + (i % 500)),
          TextStyle(fontSize: 8 + (i % 40) * 0.5));
    }
    expect(WheelTextMetrics.entriesForTest,
        lessThanOrEqualTo(WheelTextMetrics.maxEntries));
  });

  test('over the real dataset, a second frame lays out nothing', () async {
    // The end-to-end number, measured on the real vocabulary rather than
    // through the page — the page is behind an asset future that a
    // widget test cannot drain, and this measures the thing that
    // actually costs: every power name and event title the wheel sets
    // along an arc, at the sizes it sets them.
    final raw = File('assets/wheel_history.json').readAsStringSync();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final names = <String>[
      for (final p in data['powers'] as List)
        ((p as Map)['name'] as Map)['zh-Hant'] as String,
      for (final e in data['events'] as List)
        ((e as Map)['title'] as Map?)?['zh-Hant'] as String? ?? '',
    ].where((n) => n.isNotEmpty).toList();
    expect(names.length, greaterThan(500),
        reason: 'the dataset did not load — this test is measuring '
            'nothing');

    // Frame one: cold. Both halves of what a frame does — measure the
    // run, then draw it glyph by glyph.
    const style = TextStyle(fontSize: 11, color: Color(0xFF222222));
    var characters = 0;
    for (final n in names) {
      characters += n.characters.length;
      WheelTextMetrics.runWidth(n, style);
      for (final ch in n.characters) {
        WheelTextMetrics.glyphOf(ch, style);
      }
    }
    final cold = WheelTextMetrics.layoutsForTest;

    // Frame two: the same work, warm. This is the frame a reader gets
    // while panning, and before the cache it cost exactly as much as
    // frame one — twice over, because the draw pass measured again.
    WheelTextMetrics.zeroCounterForTest();
    for (final n in names) {
      WheelTextMetrics.runWidth(n, style);
      for (final ch in n.characters) {
        WheelTextMetrics.glyphOf(ch, style);
      }
    }
    expect(WheelTextMetrics.layoutsForTest, 0,
        reason: 'a warm frame still laid out '
            '\${WheelTextMetrics.layoutsForTest} runs');

    // And the size of the win, stated rather than implied: the wheel
    // used to lay out one TextPainter per character per pass.
    expect(cold, lessThan(characters / 2),
        reason: 'cold cost \$cold layouts for \$characters characters — '
            'the vocabulary repeats far more than that, so either the '
            'cache is not keyed as intended or the data changed shape');
  });
}
