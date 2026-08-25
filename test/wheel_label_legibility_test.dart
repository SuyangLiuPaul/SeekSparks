// What the chronology wheel's rim can actually say, measured in the
// faces the app ships.
//
// WHY THIS FILE EXISTS. Every word on the wheel is drawn with a
// `TextPainter` onto a canvas. No widget sweep can see it — there is no
// `RichText` node, no semantics label, nothing a `find.text` can reach —
// so for as long as the painter decided what to draw, the one decision
// that matters (is this label legible?) sat in the one place no test
// could read. It was wrong, and had been since the wheel shipped:
// measured over the real corpus on a 900 px canvas at rest, NOT ONE of
// the 55 English labels was drawn whole, and 46 of the 55 Chinese ones
// were ellipsised — which the standing rule (#297) forbids outright,
// because 莫斯 is not an abbreviation of 莫斯科, it is a different word.
//
// The fix moved the decision out of the painter into `planRadialSpokes`,
// which returns the resolved strings. This file reads them.
//
// `flutter test` otherwise lays every glyph out in a fixed-width
// stand-in face, which would make a fitting test pass while proving
// nothing about the shipped build. The fonts are loaded for real, and
// the control at the bottom fails if that ever stops working.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/related_verses.dart' show isCjkChar;

/// The wheel paints with no family of its own, so Latin resolves to
/// Roboto and Han to the bundled subset. Pinning them here is what
/// makes the loaded faces get used at all.
const _family = 'Roboto';
const _fallback = ['NotoSansSC-Sub'];

const _minYear = -4000;
const _maxYear = 2026;

// Mirrors of the page's own constants. Kept literal rather than
// exported: they are the page's geometry, and a test that imported them
// would agree with the page by construction instead of checking it.
const _hubToBands = 0.285;
const _bandsToRim = 0.445;
const _labelPx = 10.5;

Future<void> _load(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

double _measure(String s, double size) => (TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          fontFamily: _family,
          fontFamilyFallback: _fallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout())
    .width;

/// The page's declutter: an event is kept when it is at least [minGap]
/// clear of the last one kept.
List<WheelHistoryEvent> _declutter(
    List<WheelHistoryEvent> events, double minGap) {
  final kept = <WheelHistoryEvent>[];
  var last = double.negativeInfinity;
  for (final e in events) {
    final a = angleForSpan(e.year, _minYear, _maxYear);
    if (a - last >= minGap) {
      kept.add(e);
      last = a;
    }
  }
  return kept;
}

typedef _Plan = ({
  List<WheelHistoryEvent> kept,
  List<PlannedSpoke> spokes,
  double base,
  double rRim,
});

_Plan _plan(WheelHistoryData data, String locale, double side, double zoom) {
  final rBands = side * _hubToBands;
  final rRim = side * _bandsToRim;
  final titleSize = _labelPx / math.sqrt(zoom);
  final minGap = (_labelPx * 1.35 / math.sqrt(zoom)) / rBands;
  final kept = _declutter(data.events, minGap);
  return (
    kept: kept,
    spokes: planRadialSpokes(
      requests: [
        for (final e in kept)
          SpokeRequest(
            angle: angleForSpan(e.year, _minYear, _maxYear),
            scripture: e.basis != 'conventional',
            title: e.titleFor(locale),
            ref: e.refs.isEmpty ? '' : e.refs.first,
          )
      ],
      rBands: rBands,
      rRim: rRim,
      titleSize: titleSize,
      refSize: titleSize * 0.86,
      measure: _measure,
      minGap: minGap,
      lineHeight: titleSize * 1.35,
    ),
    base: scriptureLabelBase(rBands),
    rRim: rRim,
  );
}

const _locales = ['en', 'zh-Hans', 'zh-Hant'];

/// A 700 px pane is about the smallest the wheel is reachable at (the
/// app admits nothing under 992 px wide); 900 is an ordinary one.
const _sizes = [700.0, 900.0];
const _zooms = [1.0, 2.0, 4.0];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;

  setUpAll(() async {
    await _load('Roboto', 'assets/fonts/Roboto-VariableFont_wdth,wght.ttf');
    await _load('NotoSansSC-Sub', 'assets/fonts/NotoSansSC-Sub.otf');
    final raw = await rootBundle.loadString('assets/wheel_history.json');
    data = WheelHistoryData.fromJson(json.decode(raw) as Map<String, dynamic>);
  });

  test('the control: the real faces are loaded, not the stand-in', () {
    // A stand-in face charges every glyph the same width. Roboto does
    // not, and Han is charged a full em where a Latin letter is about
    // half of one. If either of these ever comes out equal, this whole
    // file has been measuring a fiction.
    expect(_measure('iiii', 20), lessThan(_measure('WWWW', 20)),
        reason: 'Roboto is proportional; a stand-in face is not');
    expect(_measure('王王', 20), greaterThan(_measure('ii', 20) * 2),
        reason: 'Han is charged about an em; a stand-in charges a column');
  });

  test('a Chinese label is whole or absent — never ellipsised (#297)', () {
    var checked = 0;
    for (final locale in ['zh-Hans', 'zh-Hant']) {
      for (final side in _sizes) {
        for (final zoom in _zooms) {
          final p = _plan(data, locale, side, zoom);
          for (final s in p.spokes) {
            checked++;
            if (!s.hasText) continue;
            expect(s.ellipsised, isFalse,
                reason: '$locale ${side.toInt()}px ${zoom}x: '
                    '"${p.kept[s.index].titleFor(locale)}" was cut to '
                    '"${s.title}"');
            expect(s.title, equals(p.kept[s.index].titleFor(locale)),
                reason: 'a drawn Chinese title must be the whole title');
          }
        }
      }
    }
    expect(checked, greaterThan(300), reason: 'the sweep must reach labels');
  });

  test('an English label is cut at a word, never mid-word', () {
    var cut = 0;
    for (final side in _sizes) {
      for (final zoom in _zooms) {
        final p = _plan(data, 'en', side, zoom);
        for (final s in p.spokes) {
          if (!s.ellipsised) continue;
          cut++;
          final full = p.kept[s.index].titleFor('en');
          expect(s.title.endsWith('…'), isTrue);
          final head = s.title.substring(0, s.title.length - 1);
          expect(head, isNotEmpty, reason: 'an ellipsis alone names nothing');
          expect(full.startsWith(head), isTrue,
              reason: '"$head…" is not a prefix of "$full"');
          // The character after the head must be the space the cut was
          // made at — that is what makes "Moscow…" and not "Mosc…".
          expect(full[head.length], equals(' '),
              reason: '"$full" was cut mid-word to "${s.title}"');
        }
      }
    }
    expect(cut, greaterThan(20),
        reason: 'English titles are long; some must be cut, or this '
            'test is asserting nothing');
  });

  test('every drawn label stays inside the annulus', () {
    for (final locale in _locales) {
      for (final side in _sizes) {
        for (final zoom in _zooms) {
          final p = _plan(data, locale, side, zoom);
          for (final s in p.spokes) {
            if (!s.hasText) continue;
            expect(s.label.rStart, greaterThanOrEqualTo(p.base - 0.001),
                reason: '$locale ${side.toInt()}px ${zoom}x ran into '
                    'the bands');
            expect(s.label.rEnd, lessThanOrEqualTo(p.rRim + 0.001),
                reason: '$locale ${side.toInt()}px ${zoom}x ran through '
                    'the rim');
          }
        }
      }
    }
  });

  test('the two groups are flush against opposite ends of the annulus', () {
    final p = _plan(data, 'zh-Hans', 900, 1);
    var scripture = 0, conventional = 0;
    for (final s in p.spokes) {
      if (!s.hasText) continue;
      if (p.kept[s.index].basis == 'conventional') {
        conventional++;
        expect(s.label.rEnd, closeTo(p.rRim, 0.001),
            reason: 'a conventionally-dated label hangs from the rim');
      } else {
        scripture++;
        expect(s.label.rStart, closeTo(p.base, 0.001),
            reason: 'a scripture-dated label rises from the bands');
      }
    }
    // Only 5 of the asset's 491 events carry a scripture-derived date
    // (basis "scripture+thiele", all between -980 and -609), and the
    // declutter keeps exactly one of them at rest and at 400%. So this
    // floor is 1, not a comfortable number: it is the whole visible
    // population of the group, and it is why the two-anchor layout had
    // to stop costing the other 54 labels their words.
    expect(scripture, greaterThanOrEqualTo(1));
    expect(conventional, greaterThan(20));
  });

  test('the rim says enough to be worth drawing', () {
    // Floors, not exact counts — the asset will grow. They exist so a
    // change that quietly empties the wheel, or that goes back to
    // handing every label a constant box, cannot pass. Measured
    // 2026-08-25 at 900 px and rest: 55 kept, 55 whole in Chinese, 31
    // whole plus 24 word-cut in English. Before this work: 9 and 0.
    for (final locale in ['zh-Hans', 'zh-Hant']) {
      final p = _plan(data, locale, 900, 1);
      final whole = p.spokes.where((s) => s.hasText).length;
      expect(whole, greaterThanOrEqualTo(p.spokes.length),
          reason: '$locale at rest: every kept label should fit whole');
    }
    final en = _plan(data, 'en', 900, 1);
    expect(en.spokes.where((s) => s.hasText && !s.ellipsised).length,
        greaterThanOrEqualTo(20),
        reason: 'English at rest: at least 20 labels whole');
    expect(en.spokes.where((s) => !s.hasText).length, isZero,
        reason: 'English at rest: nothing reduced to a bare tick');
  });

  test('the verse reaches the rim, which it never used to', () {
    // `_radialLabel`'s own comment promises the reference rides on the
    // label "once there is room for it: the reference IS the evidence".
    // With a constant box there never was room — 0 of 4 at rest, 1 of 9
    // even at 400%.
    final p = _plan(data, 'zh-Hans', 900, 1);
    final citable = p.kept.where((e) => e.refs.isNotEmpty).length;
    final shown = p.spokes.where((s) => s.ref.isNotEmpty).length;
    expect(citable, greaterThan(0));
    expect(shown, greaterThan(0),
        reason: 'a chart that cites scripture should show the citation');
    expect(shown * 2, greaterThanOrEqualTo(citable),
        reason: 'at rest, most citable labels should carry their verse');
  });

  test('stacking is unreachable once the declutter has run', () {
    // The page's comment used to present stacking as the wheel's
    // headline mechanism — "several events in one year step outward
    // along the same spoke". It cannot happen: the declutter keeps
    // consecutive events at least `minGap` apart and the stacker only
    // stacks within `minGap / 2`. This pins the arithmetic so nobody
    // has to take the comment's word for it.
    for (final side in _sizes) {
      for (final zoom in _zooms) {
        final p = _plan(data, 'en', side, zoom);
        for (final s in p.spokes) {
          final flush = p.kept[s.index].basis == 'conventional'
              ? (s.label.rEnd - p.rRim).abs()
              : (s.label.rStart - p.base).abs();
          expect(flush, lessThan(0.001),
              reason: 'a label was stacked off its baseline, so the '
                  'declutter and the stacker no longer agree');
        }
      }
    }
  });

  group('fitRadialLabel, on a measurer with no fonts in it', () {
    // One unit per character, so the arithmetic is readable.
    double flat(String s, double size) => s.characters.length.toDouble();

    ({String title, String ref, double width, bool ellipsised}) fit(
            String title, String ref, double room) =>
        fitRadialLabel(
            title: title,
            ref: ref,
            room: room,
            titleSize: 1,
            refSize: 1,
            measure: flat);

    test('a title that fits is drawn whole', () {
      expect(fit('Exodus', '', 10).title, 'Exodus');
      expect(fit('Exodus', '', 10).ellipsised, isFalse);
    });

    test('the verse rides along only when it also fits', () {
      expect(fit('Exodus', 'Ex 12:1', 20).ref, 'Ex 12:1');
      expect(fit('Exodus', 'Ex 12:1', 8).ref, isEmpty);
      expect(fit('Exodus', 'Ex 12:1', 8).title, 'Exodus');
    });

    test('Latin falls back to whole words', () {
      // 'Moscow…' is 7 units, 'Moscow Council…' is 15.
      expect(fit('Moscow Council Restores', '', 12).title, 'Moscow…');
      expect(fit('Moscow Council Restores', '', 16).title, 'Moscow Council…');
    });

    test('Latin whose first word will not fit is not drawn', () {
      expect(fit('Influenza Pandemic', '', 5).title, isEmpty);
    });

    test('Han is whole or nothing, at any room', () {
      expect(fit('莫斯科会议', '', 5).title, '莫斯科会议');
      for (final room in [1.0, 2.0, 3.0, 4.0]) {
        expect(fit('莫斯科会议', '', room).title, isEmpty,
            reason: 'room $room must not produce 莫斯…');
      }
    });

    test('a mixed title is treated as Han', () {
      // One ideograph is enough: cutting at a Latin space would still
      // leave the reader half a Chinese phrase.
      expect(fit('Nicaea 尼西亚会议', '', 5).title, isEmpty);
    });

    test('no room is no label', () {
      expect(fit('Exodus', '', 0).title, isEmpty);
      expect(fit('Exodus', '', -3).title, isEmpty);
    });

    test('the guard is real: these strings are ideographs', () {
      expect('莫斯科会议'.runes.any(isCjkChar), isTrue);
      expect('Moscow'.runes.any(isCjkChar), isFalse);
    });
  });
}
