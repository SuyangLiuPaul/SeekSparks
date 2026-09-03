import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show kMinYear, kMaxYear;
import 'package:seeksparks/utils/radial_chronology_layout.dart';

/// The owner's report: 「按也很难按到，打也打不开」 — many arcs on the wheel
/// are a line, hard to press, and pressing opens nothing.
///
/// It was not a matter of degree. The hit test asked for exact angular
/// containment while every other target on the page converts a finger
/// into radians, so an arc's target was its painted width and nothing
/// more — and most arcs are painted thinner than a finger.
void main() {
  List<(String, int, int)> spans() {
    final w = jsonDecode(File('assets/wheel_history.json').readAsStringSync())
        as Map<String, dynamic>;
    final kings =
        ((jsonDecode(File('assets/hebrew_kings.json').readAsStringSync())
                as Map<String, dynamic>)['kings'] as List)
            .cast<Map<String, dynamic>>()
            .map(HebrewKing.fromJson)
            .toList();
    final mins = (w['ministries'] as List)
        .cast<Map<String, dynamic>>()
        .map(WheelMinistry.fromJson)
        .toList();
    return [
      for (final k in kings) (k.id, k.reignStart, k.reignEnd),
      for (final m in mins) (m.id, m.start, m.end),
    ];
  }

  ({double a0, double a1}) arcOf((String, int, int) s) => (
        a0: angleForSpan(s.$2, kMinYear, kMaxYear),
        a1: angleForSpan(s.$3, kMinYear, kMaxYear),
      );

  test('the corpus really is full of arcs thinner than a finger', () {
    // The guard on the guard. If this collapses, the tests below are
    // proving something about a corpus that no longer exists.
    final all = spans();
    for (final side in [700.0, 900.0, 1400.0]) {
      final r = (scriptureLabelBase(side * 0.285) + side * 0.445) / 2;
      final thin = all.where((s) {
        final a = arcOf(s);
        return (a.a1 - a.a0).abs() * r < 9;
      }).length;
      expect(thin, greaterThan(30),
          reason: '${side.toInt()}px: only $thin of ${all.length} arcs are '
              'thinner than a finger — measured 61/55/39 at 700/900/1400');
    }
    final zero = all.where((s) => s.$2 == s.$3).map((s) => s.$1).toSet();
    expect(zero, containsAll(<String>{'zimri', 'ahaziah_judah'}),
        reason: 'the zero-width arcs this exists for');
  });

  test('a zero-width arc can be opened at all', () {
    // Zimri reigned seven days. His arc paints 0.00 px of sweep, so
    // under exact containment the only angle that could open him was
    // the single exact double his own start year produces — a target no
    // finger has ever hit. He is the whole case in one record.
    final all = spans();
    final zimri = all.firstWhere((s) => s.$1 == 'zimri');
    final arc = arcOf(zimri);
    expect((arc.a1 - arc.a0).abs(), 0,
        reason: 'if Zimri gains a sweep this test is measuring the wrong man');

    const r = 331.0; // the life annulus at 900 px
    final hit = nearestArcAt(arc.a0 + fingerHalfWidth(r) * 0.6, r, [arc]);
    expect(hit, isNotNull,
        reason: 'a tap half a finger away from a zero-width arc must reach it');
    expect(hit!.index, 0);

    // And not from across the wheel.
    expect(nearestArcAt(arc.a0 + fingerHalfWidth(r) * 4, r, [arc]), isNull);
  });

  test('a long reign keeps its own extent, and does not swallow its neighbours',
      () {
    // Manasseh reigned 55 years — the long arc in the owner's
    // screenshot. A tap inside him must reach him, and a tap on the
    // hairline beside him must NOT be answered by him.
    final all = spans();
    final manasseh = arcOf(all.firstWhere((s) => s.$1 == 'manasseh'));
    final amon = arcOf(all.firstWhere((s) => s.$1 == 'amon'));
    const r = 331.0;
    final list = [manasseh, amon];

    final inside = nearestArcAt((manasseh.a0 + manasseh.a1) / 2, r, list);
    expect(inside!.index, 0, reason: 'a tap in the middle of a 55-year reign');

    final onAmon = nearestArcAt((amon.a0 + amon.a1) / 2, r, list);
    expect(onAmon!.index, 1,
        reason: "Amon's two years must not be answered by Manasseh's fifty-five");
  });

  test('the finger is a real size, not an angle', () {
    // The bug this replaces used one fixed angle everywhere. Same arc,
    // two radii: the angular slack must shrink as the radius grows, so
    // the PHYSICAL target stays the same.
    final near = fingerHalfWidth(100);
    final far = fingerHalfWidth(400);
    expect(far, lessThan(near));
    expect(near * 100, closeTo(far * 400, 0.001),
        reason: 'the same number of pixels at both radii');
  });
}
