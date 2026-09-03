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

  group('containment on the power bands', () {
    // The power bands (`_buildArcs` on the wheel page) do not pack like
    // the lives above: every power in a stream shares ONE ring, so a
    // tap inside the Crusader Kingdom of Jerusalem can land inside a
    // pope's or a crusade's arc too. `nearestArcAt`'s old rule — nearest
    // centre, normalised by each arc's own half-width — answered that
    // wrong far more often than right: a pope's `own` is a few years
    // against the kingdom's few centuries, so almost any tap not dead
    // in the pope's middle scored lower for the KINGDOM.
    const r = 240.0; // a band radius, roughly, at 900 px

    test('a tap inside a nested arc reaches the nested arc, not its container',
        () {
      const kingdom = (a0: 0.0, a1: 1.0); // wide: the containing power
      const pope = (a0: 0.45, a1: 0.55); // narrow: nested well inside it
      final list = [kingdom, pope];

      // Not at the pope's own centre — near his edge, where the old
      // nearest-centre rule answered KINGDOM instead.
      final pick = nearestArcAt(0.53, r, list);
      expect(pick!.index, 1,
          reason: 'a tap inside the narrow nested arc must return it, '
              'even off-centre, not the wide arc containing it');
    });

    test('a tap outside the nested arc but inside the container reaches the '
        'container', () {
      const kingdom = (a0: 0.0, a1: 1.0);
      const pope = (a0: 0.45, a1: 0.55);
      final list = [kingdom, pope];

      final pick = nearestArcAt(0.1, r, list);
      expect(pick!.index, 0,
          reason: 'outside the nested arc entirely, the container is the '
              'only thing that truly contains the tap');
    });

    test('identical spans: the score ties too, and the first in the list '
        'wins, deterministically', () {
      // Kingdom of Moab and Kingdom of Ammon, both -1200..-582 in the
      // `world` stream — a real pair on the shipped corpus, not a
      // contrived one. See the test below for the asset check.
      const moab = (a0: 0.2, a1: 0.6);
      const ammon = (a0: 0.2, a1: 0.6); // byte-identical span

      // Kept clear of the exact edges: 0.2 and 0.6 are not exactly
      // representable in binary floating point, so a tap placed AT the
      // boundary can round to a score fractionally over 1 and be
      // rejected by both arcs — a real hazard for a real tap, but not
      // the one this test exists to pin.
      for (final angle in [0.22, 0.35, 0.4, 0.45, 0.58]) {
        final pick = nearestArcAt(angle, r, [moab, ammon]);
        expect(pick!.index, 0,
            reason: 'two identical spans compute identical scores for any '
                'tap; nothing here can break that tie, so index 0 — the '
                "first in the caller's own order — must win at angle=$angle");
        // And reversing which one is first reverses the answer, which is
        // the point: the tie is broken by ORDER, not by anything about
        // the arcs themselves.
        final reversed = nearestArcAt(angle, r, [ammon, moab]);
        expect(reversed!.index, 0);
      }
    });

    test('the real Moab/Ammon pair really does tie on span', () {
      // The premise the test above stands on. If this ever stops being
      // true the identical-span test is exercising a pair that no
      // longer exists.
      final w = jsonDecode(File('assets/wheel_history.json').readAsStringSync())
          as Map<String, dynamic>;
      final data = WheelHistoryData.fromJson(w);
      final moab = data.powers.firstWhere((p) => p.id == 'kingdom-of-moab');
      final ammon = data.powers.firstWhere((p) => p.id == 'kingdom-of-ammon');
      expect(moab.stream, ammon.stream,
          reason: 'the tie only matters if they share a ring');
      expect(moab.start, ammon.start);
      expect(moab.endFor(9999), ammon.endFor(9999));
    });
  });
}
