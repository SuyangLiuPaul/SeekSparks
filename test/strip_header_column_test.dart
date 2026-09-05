/// The strip's lane-header column, at the width a phone reads it at.
///
/// `stripHeaderColumnWidth` clamped the column to 0.30 of the viewport
/// and `StripLaneHeaderPainter` laid its headings out with NO maxWidth
/// at all — natural width, painted from an 8 px inset, cut by wherever
/// the canvas edge happened to fall. At 375 px the clamp was 112 and
/// 犹大与以色列列王 wants more, so the heading reached a phone reader as
/// 犹大与以色列列3: a character cut down its middle, which is not even a
/// truncation a reader can recognise as one.
///
/// Three things are pinned, and the order matters.
///
/// THE FIX is the column: 0.40 of a narrow viewport instead of 0.30.
///
/// THE NET is the painter's ellipsis — laid out to the room it has, no
/// string can paint past the column however long it is.
///
/// THE HEADINGS THEMSELVES are measured in a REAL FACE, and that is the
/// part this file got wrong for a day. It used to assert that `Genesis
/// lifespans` "wants 221 px, 59% of a 375 px screen", and passed. The
/// 221 px was an artefact of the Flutter test font, in which every glyph
/// — Latin or Han — is a full em box: `Events` measured 6 × 13 and 事件
/// measured 2 × 13, character count times font size, exactly. That is
/// correct for Han, which really is one em per glyph, so the Chinese
/// assertions below were sound by accident. It is roughly double the
/// truth for Latin. Re-measured 2026-09-05 in the bundled Roboto at the
/// weight and size the painter actually draws, `Genesis lifespans` is
/// 109.6 px and has 24 px to spare; the two headings that genuinely
/// overflowed were `Kings of Judah & Israel` (142.9) and `Peoples &
/// institutions` (135.5), and both were reworded — see
/// `strip_strings.dart` for the wording and its reasons.
///
/// So the real-face group loads the fonts this app ships and measures
/// against them. It cannot be perfect: the app's DEFAULT font setting is
/// the system face (San Francisco, Segoe UI), not Roboto, and the reader
/// can choose another. That is what the margin requirement is for — a
/// heading is only accepted if it clears the column by enough that a
/// somewhat wider face still fits — and the ellipsis net above is the
/// backstop for the rest.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/strip_strings.dart';
import 'package:seeksparks/widgets/strip_chronology_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  // 12 px is `laneFontPx` at the default type setting (20 pt → textScale
  // 1.0) and the heading is `laneFontPx * 1.15` — see
  // `strip_chronology_page.dart`. This file used to measure at a flat
  // 13.0, which is a size the app never draws.
  const headingFontPx = 12.0 * 1.15;

  double columnAt(String locale, double viewportWidth,
          {double Function(String, double)? using}) =>
      stripHeaderColumnWidth(
        locale: locale,
        headingFontPx: headingFontPx,
        viewportWidth: viewportWidth,
        measure: using ?? measure,
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

  test('no heading can be cut mid-glyph, whatever it is', () {
    // The net, exercised the way the painter exercises it: laid out to
    // the room it actually has, with an ellipsis, the result never
    // exceeds that room. Without `maxWidth` — how this shipped — the
    // same layout returns the full natural width and paints straight
    // past the column.
    //
    // The string is deliberately synthetic and absurd rather than one of
    // the five real headings. Every real heading now fits (that is what
    // the real-face group below asserts), so pinning the net to one of
    // them would mean the net's test silently stopped testing the net
    // the moment the wording was fixed.
    const overlong = 'A lane heading nobody would ever actually write';
    final room = columnAt('en', 375) - 16;
    final tp = TextPainter(
      text: const TextSpan(
          text: overlong, style: TextStyle(fontSize: headingFontPx)),
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

  group('measured in the faces this app ships', () {
    // Roboto is the bundled Latin fallback and Noto Sans SC the bundled
    // CJK one (`pubspec.yaml`). Neither is what most readers see —
    // the default setting routes to the system face — so these are a
    // proxy, and the margin below is what makes the proxy safe enough.
    setUpAll(() async {
      Future<void> load(String family, String path) async {
        final bytes = File(path).readAsBytesSync();
        await (FontLoader(family)
              ..addFont(Future.value(ByteData.sublistView(bytes))))
            .load();
      }

      await load('Roboto', 'assets/fonts/Roboto-VariableFont_wdth,wght.ttf');
      await load('NotoCJK', 'assets/fonts/NotoSansSC-Sub.otf');
    });

    /// The painter's own style: `canvasTextStyle(..., FontWeight.w600)`.
    double drawn(String text, double size, String family) => (TextPainter(
          text: TextSpan(
              text: text,
              style: TextStyle(
                  fontSize: size,
                  fontFamily: family,
                  fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout())
            .width;

    /// `_measureText`, which is what sizes the column, does NOT pass a
    /// weight — it measures at w400 while the painter draws at w600.
    double sized(String text, double size, String family) => (TextPainter(
          text: TextSpan(
              text: text,
              style: TextStyle(fontSize: size, fontFamily: family)),
          textDirection: TextDirection.ltr,
        )..layout())
            .width;

    // Enough that a face perhaps 6% wider than the proxy still fits.
    // The tightest real heading clears by 8.7 px in Roboto.
    const marginPx = 8.0;

    for (final entry in const {
      'en': 'Roboto',
      'zh-Hans': 'NotoCJK',
      'zh-Hant': 'NotoCJK',
    }.entries) {
      test('every ${entry.key} heading clears the column at 375 px', () {
        final column = columnAt(entry.key, 375,
            using: (t, s) => sized(t, s, entry.value));
        final room = column - 16;
        for (final key in keys) {
          final text = headingFor(key, entry.key);
          final width = drawn(text, headingFontPx, entry.value);
          expect(width, lessThanOrEqualTo(room - marginPx),
              reason: '"$text" is ${width.toStringAsFixed(1)} px against '
                  '${room.toStringAsFixed(1)} px of room in ${entry.value}. '
                  'A heading that only just fits the bundled face does not '
                  'fit the system face a reader actually sees; shorten it, '
                  'the way `Kings of Judah & Israel` and `Peoples & '
                  'institutions` were shortened on 2026-09-05');
        }
      });
    }

    test('the column is sized at a lighter weight than it is drawn', () {
      // Not a defect today, and recorded so it is not "fixed" into one.
      // `_measureText` omits the weight, so the column is computed from a
      // measurement 1-3 px narrower than the text the painter puts in it.
      // The formula's `+ headingFontPx * 2` of padding (27.6 px at the
      // default size) absorbs that everywhere the clamp does not bind,
      // and where the clamp DOES bind — a phone — the clamp is what
      // decides the width, not the measurement.
      const text = 'Judah & Israel kings';
      final light = sized(text, headingFontPx, 'Roboto');
      final heavy = drawn(text, headingFontPx, 'Roboto');
      expect(heavy, greaterThan(light));
      expect(heavy - light, lessThan(headingFontPx * 2),
          reason: 'the weight difference must stay inside the padding the '
              'column formula adds, or the column has to measure at w600');
    });
  });
}
