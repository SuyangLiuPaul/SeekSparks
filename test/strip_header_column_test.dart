/// The strip's lane-header column, at the width a phone reads it at.
///
/// `stripHeaderColumnWidth` clamped the column to 0.30 of the viewport
/// and `StripLaneHeaderPainter` laid its headings out with NO maxWidth
/// at all — natural width, painted from an 8 px inset, cut by wherever
/// the canvas edge happened to fall. At 375 px the clamp is 112 and
/// 犹大与以色列列王 wants 104 + 26 of padding, so the heading reached a
/// phone reader as 犹大与以色列列3: a character cut down its middle,
/// which is not even a truncation a reader can recognise as one.
///
/// Two things are pinned, and the order matters.
///
/// THE FIX is the column: 0.40 of a narrow viewport instead of 0.30,
/// which at 375 px is 150 against the 130 the widest Chinese heading
/// actually wants — so in both Chinese locales, the app's own default
/// among them, every heading is drawn whole with room to spare.
///
/// THE NET is the painter's ellipsis, and English needs it: `Genesis
/// lifespans` wants 221 px, 59% of a 375 px screen on its own, and no
/// column share that leaves a chart worth reading can hold it. So it
/// truncates — but to `Genesis life…`, which a reader can see is a
/// truncation, rather than to half a letterform. Shortening the English
/// heading itself would fix it properly and is a wording decision, not
/// a layout one, so it is left alone and written down here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/strip_strings.dart';
import 'package:seeksparks/widgets/strip_chronology_painter.dart';

void main() {
  double measure(String text, double size) => (TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: size)),
        textDirection: TextDirection.ltr,
      )..layout())
          .width;

  // Every heading the painter can draw, not a sample: the column is
  // only honest if the WIDEST of them is accounted for.
  const keys = [
    'stripLaneEvents',
    'stripLaneLifespans',
    'stripLaneKings',
    'stripLaneMinistries',
    'stripLaneStreams',
  ];
  const headingFontPx = 13.0;

  double columnAt(String locale, double viewportWidth) =>
      stripHeaderColumnWidth(
        locale: locale,
        headingFontPx: headingFontPx,
        viewportWidth: viewportWidth,
        measure: measure,
      );

  String headingFor(String key, String locale) =>
      stripStrings[key]?[locale] ?? stripStrings[key]!['en']!;

  for (final locale in const ['zh-Hans', 'zh-Hant']) {
    test('every lane heading is drawn whole at 375 px in $locale', () {
      final column = columnAt(locale, 375);
      // The painter insets by 8 a side before it lays the text out.
      final room = column - 16;
      for (final key in keys) {
        final text = headingFor(key, locale);
        expect(measure(text, headingFontPx), lessThanOrEqualTo(room),
            reason: '"$text" must fit the header column whole at 375 px — '
                'under the old 0.30 clamp it was painted past the column '
                'and cut mid-glyph by the canvas edge');
      }
    });
  }

  test('English truncates rather than fits, and that is the honest read',
      () {
    final column = columnAt('en', 375);
    final room = column - 16;
    // Not an aspiration — a measurement, so that if the heading is ever
    // shortened this test says so instead of quietly passing.
    expect(measure(headingFor('stripLaneLifespans', 'en'), headingFontPx),
        greaterThan(room),
        reason: 'Genesis lifespans wants 221 px of a 375 px screen; if '
            'this now fits, the heading was shortened and the ellipsis '
            'note in this file and in the painter should go');
  });

  test('no heading can be cut mid-glyph, whatever it is', () {
    // The net, exercised the way the painter exercises it: laid out to
    // the room it actually has, with an ellipsis, the result never
    // exceeds that room. Without `maxWidth` — how this shipped — the
    // same layout returns the full 221 and paints straight past.
    final room = columnAt('en', 375) - 16;
    final tp = TextPainter(
      text: TextSpan(
          text: headingFor('stripLaneLifespans', 'en'),
          style: const TextStyle(fontSize: headingFontPx)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: room);
    expect(tp.width, lessThanOrEqualTo(room));
    expect(tp.didExceedMaxLines, isTrue,
        reason: 'and it is a real truncation, not a coincidence of fit');
  });

  test('a desktop viewport keeps the narrower 0.30 share', () {
    // The wider share is for phones only; a desktop reader has room to
    // spare across the axis and should not pay 40% of it for a column
    // whose text already fits inside 30.
    expect(columnAt('zh-Hans', 1440), lessThanOrEqualTo(1440 * 0.30));
    expect(columnAt('en', 1440), lessThanOrEqualTo(1440 * 0.30));
  });
}
