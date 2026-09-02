/// THE 42 KINGS, ON THE WHEEL AS REIGN ARCS.
///
/// The owner looked at the wheel and said the biblical figures were not
/// on it. The lifespan band answered that for Adam through Joseph and
/// then stopped: after about 1600 BC the annulus was empty, while
/// `assets/hebrew_kings.json` had held 42 dated, cited reigns spanning
/// 1050–586 BC the whole time — read by the wheel only to answer a
/// search box. This layer draws them.
///
/// Three things have to hold, and only the second is obvious.
///
///   1. Every king becomes exactly one arc, and its id cannot be
///      mistaken for a patriarch's.
///   2. THE BAND IS PACKED ONCE. `packIntoRings` is first-fit over
///      whatever list it is given, so packing the patriarchs alone and
///      the kings alone hands BOTH a ring 0 — two arcs printed at one
///      radius, and a search that pans to a radius nothing was drawn
///      at. Nothing about that failure looks like an arithmetic
///      mistake, which is why it is pinned rather than trusted.
///   3. The two kingdoms are told apart by eye, and neither is the
///      patriarchs' colour.
///
/// The arc is the OUTER HULL of a king's reign, `reignStart`..
/// `reignEnd`, not one arc per `ReignSpan` — Thiele's co-regencies
/// would otherwise put seven men on the wheel twice with nothing to
/// show the two arcs are one man. The sheet names the parts instead,
/// and this file pins that the hull contains them.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart'
    show HebrewKingsData;
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show kKingArcPrefix, kingReignSpans, kingdomArcColor, kMinYear, kMaxYear;
import 'package:seeksparks/utils/radial_chronology_layout.dart';

const String _kDrawnTradition = 'mt';

late final List<HebrewKing> kings;
late final ChronologyData chron;
late final int creation;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    kings = HebrewKingsData.fromJson(
      jsonDecode(File('assets/hebrew_kings.json').readAsStringSync())
          as Map<String, dynamic>,
    ).kings;
    chron = ChronologyData.fromJson(
      jsonDecode(File('assets/chronology.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    creation = (((jsonDecode(
                File('assets/bible_timeline.json').readAsStringSync())
            as Map<String, dynamic>)['_meta']
        as Map<String, dynamic>)['creation'] as Map<String, dynamic>)['year']
        as int;
  });

  group('every king becomes one arc', () {
    test('the whole file is converted, and to its own hull', () {
      final spans = kingReignSpans(kings);
      expect(spans.length, kings.length);
      expect(kings.length, 42, reason: 'the asset changed size');

      for (final k in kings) {
        final s = spans.firstWhere((s) => s.id == '$kKingArcPrefix${k.id}');
        expect(s.startYear, k.reignStart);
        expect(s.endYear, k.reignEnd);
        // The hull really is a hull: every ReignSpan lies inside it.
        for (final part in k.spans) {
          expect(part.start, greaterThanOrEqualTo(k.reignStart));
          expect(part.end, lessThanOrEqualTo(k.reignEnd));
        }
      }
    });

    test('a king can never be taken for a patriarch', () {
      final spans = kingReignSpans(kings);
      final patriarchIds = {for (final p in chron.patriarchs) p.id};
      for (final s in spans) {
        expect(s.id.startsWith(kKingArcPrefix), isTrue);
        expect(patriarchIds.contains(s.id), isFalse);
      }
      expect(spans.map((s) => s.id).toSet().length, spans.length,
          reason: 'two kings share an arc id');
    });

    test('the line is the kingdom, and only ever one of two', () {
      for (final s in kingReignSpans(kings)) {
        expect(s.line, anyOf('judah', 'israel'));
      }
      // SAUL IS NOT IN THE ASSET. `hebrew_kings.json` is Thiele's
      // chart of the divided monarchy and its synchronisms, and it
      // begins at David — so the wheel's reign band begins at David
      // too, and the forty years of 1 Samuel are a gap in this layer
      // rather than something it declines to draw. Pinned, because the
      // absence would otherwise look like a bug in this file.
      expect(kings.any((k) => k.id == 'saul'), isFalse);

      // David and Solomon reigned over both houses and are drawn in
      // Judah's shade. That is a drawing decision, not a claim that the
      // united monarchy was Judah, and it is stated so it can be
      // argued with.
      final david = kingReignSpans(kings)
          .firstWhere((s) => s.id == '${kKingArcPrefix}david');
      expect(david.line, 'judah');
      expect(kings.firstWhere((k) => k.id == 'david').kingdom,
          Kingdom.united);
    });
  });

  group('the band is packed once', () {
    List<LifeArc> packedTogether() => buildLifeArcs(
          patriarchs: chron.patriarchs,
          tradition: _kDrawnTradition,
          creationYear: creation,
          minYear: kMinYear,
          maxYear: kMaxYear,
          minGap: 0.02,
          alsoPack: kingReignSpans(kings),
        );

    test('no two arcs in one sub-ring overlap in angle', () {
      final arcs = packedTogether();
      // 26 patriarchs, 42 kings, and ONE patriarch dropped: `kainan2`,
      // the second Cainan of Luke 3:36, has no Masoretic figures
      // because the Masoretic text does not have him. He returns the
      // day a Septuagint tradition is the drawn one, which is the
      // whole reason the filter is on `figures[tradition]` and not on
      // a list of ids.
      final drawnPatriarchs = chron.patriarchs
          .where((p) => p.figures[_kDrawnTradition] != null)
          .length;
      expect(chron.patriarchs.length - drawnPatriarchs, 1);
      expect(
          chron.patriarchs
              .firstWhere((p) => p.figures[_kDrawnTradition] == null)
              .id,
          'kainan2');
      expect(arcs.length, drawnPatriarchs + kings.length);
      final byRing = <int, List<LifeArc>>{};
      for (final a in arcs) {
        byRing.putIfAbsent(a.ring, () => []).add(a);
      }
      for (final entry in byRing.entries) {
        final ring = entry.value..sort((a, b) => a.a0.compareTo(b.a0));
        for (var i = 1; i < ring.length; i++) {
          expect(ring[i].a0, greaterThanOrEqualTo(ring[i - 1].a1),
              reason: 'ring ${entry.key}: ${ring[i].id} starts before '
                  '${ring[i - 1].id} ends');
        }
      }
    });

    test('packing the two sets separately DOES collide — the fault this '
        'guards against is real', () {
      // The falsification, written out rather than described: this is
      // exactly what a well-meant `[...lifeArcs, ...kingArcs]` would
      // produce, and it puts a patriarch and a king in ring 0 together.
      final lives = buildSpanArcs(
        spans: patriarchsAsSpans(chron.patriarchs, _kDrawnTradition, creation),
        minYear: kMinYear,
        maxYear: kMaxYear,
      );
      final reigns = buildSpanArcs(
        spans: kingReignSpans(kings),
        minYear: kMinYear,
        maxYear: kMaxYear,
      );
      expect(lives.any((a) => a.ring == 0), isTrue);
      expect(reigns.any((a) => a.ring == 0), isTrue);
      // ...and in the SINGLE packing, ring 0 holds each id at most once.
      final together = packedTogether().where((a) => a.ring == 0).toList();
      expect(together.map((a) => a.id).toSet().length, together.length);
    });

    test('the reigns land where the kings say, not where the packer likes',
        () {
      final arcs = packedTogether();
      for (final k in kings) {
        final arc =
            arcs.firstWhere((a) => a.id == '$kKingArcPrefix${k.id}');
        expect(arc.birthYear, k.reignStart);
        expect(arc.deathYear, k.reignEnd);
        expect(arc.a0, angleForSpan(k.reignStart, kMinYear, kMaxYear));
        expect(arc.a1, angleForSpan(k.reignEnd, kMinYear, kMaxYear));
      }
    });
  });

  group('the two kingdoms are told apart', () {
    double hue(Color c) => HSLColor.fromColor(c).hue;

    test('Judah and Israel are far apart in hue', () {
      final j = kingdomArcColor(Kingdom.judah);
      final i = kingdomArcColor(Kingdom.israel);
      expect((hue(i) - hue(j)).abs(), greaterThan(30),
          reason: 'the two kingdoms read as one colour');
    });

    test('neither is the patriarchs\' shade', () {
      // The lifespan arcs sit at the MIDDLE of Shem's hue arc; these two
      // at its ends. Three shades of one family is the intent — three
      // families would have been a claim about descent that Genesis 10
      // does not make — so what has to hold is that they separate, not
      // that they differ in kind.
      final patriarch = HSLColor.fromColor(kingdomArcColor(Kingdom.judah));
      final israel = HSLColor.fromColor(kingdomArcColor(Kingdom.israel));
      expect(patriarch.hue, isNot(israel.hue));
      for (final k in const [Kingdom.judah, Kingdom.israel]) {
        final l = HSLColor.fromColor(kingdomArcColor(k)).lightness;
        // The same floor and ceiling the stream bands are held to.
        expect(l, greaterThan(0.30));
        expect(l, lessThan(0.70));
      }
    });
  });
}
