/// THE PROPHETS AND APOSTLES, AS MINISTRY ARCS.
///
/// Thirty-nine spans in `wheel_history.json`'s `ministries` array, drawn
/// in the same annulus as the Genesis lifespans and the reigns.
///
/// A MINISTRY IS NOT A LIFE. Scripture gives a prophet a birth or a
/// death almost never; what it gives is the reigns he prophesied under
/// (Isaiah 1:1) or a regnal year it dates a word to (Jeremiah 1:2,
/// Ezekiel 1:2). So the span is a ministry, not a lifespan, and the
/// note on each record says how it was reached — which is why the sheet
/// prints the note ABOVE the references rather than below them.
///
/// What this file is really for is the field that looks like a formula
/// and is not. `anchorKings` names the reigns a span was reached from,
/// and it is tempting to assert that every span is the union of them.
/// It is not: six are, one (Amos) is the intersection, and nine are
/// neither — Ezekiel runs to the twenty-seventh year of his own exile,
/// fifteen years past the last reign he names, and Huldah is one day in
/// Josiah's eighteenth. Asserting the union would fail nine correct
/// rows. So the strong claim is made only where the data makes it, and
/// the claim that holds everywhere is the weaker, true one: the span
/// OVERLAPS the reigns it cites.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show
        kMinistryArcPrefix,
        kKingArcPrefix,
        kMinYear,
        kMaxYear,
        ministryArcColor,
        ministrySpans,
        packWheelBand;
import 'package:seeksparks/services/hebrew_kings_service.dart'
    show HebrewKingsData;
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/reference_parser.dart';

late final List<WheelMinistry> ministries;
late final Map<String, HebrewKing> kingsById;
late final List<HebrewKing> kings;
late final ChronologyData chron;
late final Map<String, dynamic> wheelJson;
late final int creation;

/// The rows whose own note says the span is the union of the reigns it
/// names. Listed rather than detected, because a note is prose and a
/// test that parsed it would be asserting the prose.
const _unionRows = <String>[
  'isaiah_prophet',
  'hosea_prophet',
  'jonah_prophet',
  'micah_prophet',
  'zephaniah_prophet',
  'ahijah_shilonite',
];

/// Amos 1:1 names Uzziah and Jeroboam II CONCURRENTLY — "in the days of
/// Uzziah king of Judah, and in the days of Jeroboam" — so this row is
/// the intersection, and it is the only one.
const _intersectionRow = 'amos_prophet';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    wheelJson =
        jsonDecode(File('assets/wheel_history.json').readAsStringSync())
            as Map<String, dynamic>;
    ministries = (wheelJson['ministries'] as List)
        .cast<Map<String, dynamic>>()
        .map(WheelMinistry.fromJson)
        .toList();
    kings = HebrewKingsData.fromJson(
      jsonDecode(File('assets/hebrew_kings.json').readAsStringSync())
          as Map<String, dynamic>,
    ).kings;
    kingsById = {for (final k in kings) k.id: k};
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

  group('the asset', () {
    test('forty-two ministries, every field read', () {
      // 39 on 2026-09-02; three more with the Israel section on
      // 2026-09-03 — Joshua son of Nun, Eli the priest, and Alexander
      // Jannaeus.
      expect(ministries.length, 42);
      // Every KEY in the asset is parsed by the model. The disclosure
      // test makes this rule for the file as a whole; restated here so
      // a field added to a ministry row and never read fails in the
      // file that owns the row.
      const known = {
        'id', 'start', 'end', 'region', 'stream', 'approximate', 'basis',
        'refs', 'anchorKings', 'name', 'note',
      };
      for (final raw in (wheelJson['ministries'] as List)
          .cast<Map<String, dynamic>>()) {
        expect(raw.keys.toSet().difference(known), isEmpty,
            reason: '${raw['id']} carries a key nothing reads');
      }
    });

    test('no id collides with anything else the wheel draws', () {
      final existing = <String>{
        for (final k in ['events', 'powers', 'nations', 'streams'])
          for (final r in (wheelJson[k] as List).cast<Map<String, dynamic>>())
            r['id'] as String,
        for (final p in chron.patriarchs) p.id,
        ...kingsById.keys,
      };
      for (final m in ministries) {
        expect(existing.contains(m.id), isFalse, reason: m.id);
      }
      expect(ministries.map((m) => m.id).toSet().length, ministries.length);
    });

    test('never `scripture` on a span, and every basis is a stated one', () {
      // `_meta.basisValues` defines `scripture` as "the text states it".
      // The text states no BC year for anyone, so a span can never
      // carry it — a ministry is at best an interval scripture gives
      // against a reign whose ABSOLUTE year is Thiele's.
      final allowed =
          ((wheelJson['_meta'] as Map<String, dynamic>)['basisValues']
                  as Map<String, dynamic>)
              .keys
              .toSet();
      for (final m in ministries) {
        expect(allowed.contains(m.basis), isTrue, reason: m.id);
        expect(m.basis, isNot('scripture'),
            reason: '${m.id} claims scripture states its years');
      }
      expect(ministries.where((m) => m.basis == 'scripture+thiele').length, 14);
      expect(ministries.where((m) => m.basis == 'conventional').length, 28);
    });

    test('every span is ordered, inside the axis, and named in three scripts',
        () {
      for (final m in ministries) {
        expect(m.start, lessThanOrEqualTo(m.end), reason: m.id);
        expect(m.start, greaterThanOrEqualTo(kMinYear), reason: m.id);
        expect(m.end, lessThanOrEqualTo(kMaxYear), reason: m.id);
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(m.nameFor(locale), isNotEmpty, reason: '${m.id} $locale');
          expect(m.noteFor(locale), isNotEmpty, reason: '${m.id} $locale');
        }
      }
    });

    test('every reference parses, so every chip can be tapped', () {
      for (final m in ministries) {
        for (final ref in m.refs) {
          expect(parseReference(ref), isNotNull,
              reason: '${m.id} cites "$ref", which the reader cannot open');
        }
      }
    });
  });

  group('anchorKings is evidence, not arithmetic', () {
    ({int start, int end}) hull(List<String> ids) => (
          start: ids.map((i) => kingsById[i]!.reignStart).reduce(_lower),
          end: ids.map((i) => kingsById[i]!.reignEnd).reduce(_upper),
        );

    test('every anchor names a king this app ships', () {
      for (final m in ministries) {
        for (final id in m.anchorKings) {
          expect(kingsById.containsKey(id), isTrue,
              reason: '${m.id} anchors on "$id", which is not in the chart');
        }
      }
    });

    test('the claim that holds everywhere: the span overlaps its anchors', () {
      for (final m in ministries) {
        if (m.anchorKings.isEmpty) continue;
        final h = hull(m.anchorKings);
        expect(m.start <= h.end && h.start <= m.end, isTrue,
            reason: '${m.id} (${m.start}..${m.end}) does not touch the '
                'reigns it cites (${h.start}..${h.end})');
      }
    });

    test('the six rows whose note says UNION are the union', () {
      for (final id in _unionRows) {
        final m = ministries.firstWhere((x) => x.id == id);
        final h = hull(m.anchorKings);
        expect(m.start, h.start, reason: id);
        expect(m.end, h.end, reason: id);
      }
    });

    test('Amos is the intersection, and is the only one', () {
      final m = ministries.firstWhere((x) => x.id == _intersectionRow);
      final starts = m.anchorKings.map((i) => kingsById[i]!.reignStart);
      final ends = m.anchorKings.map((i) => kingsById[i]!.reignEnd);
      expect(m.start, starts.reduce(_upper));
      expect(m.end, ends.reduce(_lower));
    });

    test('nine anchored rows are NEITHER, and that is correct', () {
      // The falsification of the obvious test. If this count ever drops
      // to zero someone has "fixed" the data to fit a formula, and rows
      // like Ezekiel — whose last date is his own twenty-seventh year
      // of exile, fifteen years after the last reign he names — will
      // have been silently re-dated.
      var neither = 0;
      for (final m in ministries) {
        if (m.anchorKings.isEmpty) continue;
        final h = hull(m.anchorKings);
        final starts = m.anchorKings.map((i) => kingsById[i]!.reignStart);
        final ends = m.anchorKings.map((i) => kingsById[i]!.reignEnd);
        final isUnion = m.start == h.start && m.end == h.end;
        final isInter = m.start == starts.reduce(_upper) &&
            m.end == ends.reduce(_lower);
        if (!isUnion && !isInter) neither++;
      }
      expect(neither, 9);
    });
  });

  group('drawn in the band', () {
    test('every ministry becomes one arc, prefixed and packed with the rest',
        () {
      final spans = ministrySpans(ministries);
      expect(spans.length, ministries.length);
      for (final s in spans) {
        expect(s.id.startsWith(kMinistryArcPrefix), isTrue);
        expect(s.line, 'ministry');
      }

      final arcs = packWheelBand(
        chron: chron,
        creationYear: creation,
        kings: kings,
        ministries: ministries,
      );
      // 25 lives (kainan2 has no Masoretic figures), 42 reigns, 42
      // ministries.
      expect(arcs.length, 109);
      for (final m in ministries) {
        final arc = arcs
            .firstWhere((a) => a.id == '$kMinistryArcPrefix${m.id}');
        expect(arc.birthYear, m.start);
        expect(arc.deathYear, m.end);
      }
      // No id is drawn twice, across all three layers.
      expect(arcs.map((a) => a.id).toSet().length, arcs.length);
      // ...and a ministry can never be read as a king.
      for (final a in arcs) {
        expect(
            a.id.startsWith(kMinistryArcPrefix) &&
                a.id.startsWith(kKingArcPrefix),
            isFalse);
      }
    });

    test('no two arcs in one sub-ring overlap in angle', () {
      final arcs = packWheelBand(
        chron: chron,
        creationYear: creation,
        kings: kings,
        ministries: ministries,
      );
      final byRing = <int, List<LifeArc>>{};
      for (final a in arcs) {
        byRing.putIfAbsent(a.ring, () => []).add(a);
      }
      for (final entry in byRing.entries) {
        final ring = entry.value..sort((a, b) => a.a0.compareTo(b.a0));
        for (var i = 1; i < ring.length; i++) {
          expect(ring[i].a0, greaterThanOrEqualTo(ring[i - 1].a1),
              reason: 'ring ${entry.key}: ${ring[i].id} overprints '
                  '${ring[i - 1].id}');
        }
      }
    });

    test('the ministries have their own hue, not one of Shem\'s three', () {
      final ministry = HSLColor.fromColor(ministryArcColor()).hue;
      // Shem's arc is 10..64; the lifespans sit at its middle and the
      // two kingdoms at its ends. A ministry is a third kind of claim
      // and must not land inside that family.
      expect(ministry < 5 || ministry > 70, isTrue,
          reason: 'the ministries were given a Semitic hue, which says '
              'their years are the same sort of number as the reigns');
    });
  });
}

int _lower(int a, int b) => a < b ? a : b;
int _upper(int a, int b) => a > b ? a : b;
