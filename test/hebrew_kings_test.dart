// Guards for the kings-of-Judah-and-Israel resource (#292).
//
// Two things are worth testing here and they are different in kind.
//
// The DATA is a claim about history, and a JSON file of ancient dates is
// indistinguishable by inspection from a file of invented ones. So the
// asset is re-checked against the same invariants
// `scripts/build_hebrew_kings.py` asserts at build time: the throne is
// never vacant between the division and the fall, reigns hand over at a
// single shared year, no two sole reigns overlap. If someone hand-edits
// the asset instead of the generator, these fail.
//
// The LAYOUT is pure geometry with one genuinely hard case — reign
// lengths span four orders of magnitude, from Manasseh's 55 years to
// Zimri's seven days — so the label placer is tested directly rather
// than through a widget.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/pages/hebrew_kings_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/utils/kings_chart_layout.dart';
import 'package:seeksparks/utils/kings_contemporaries.dart';
import 'package:seeksparks/utils/reference_parser.dart';

HebrewKing _king({
  required String id,
  required int start,
  required int end,
  Kingdom kingdom = Kingdom.judah,
}) =>
    HebrewKing(
      id: id,
      kingdom: kingdom,
      house: 'david',
      names: {'en': id},
      spans: [ReignSpan(kind: SpanKind.sole, start: start, end: end)],
      reignStart: start,
      reignEnd: end,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reignsOverlap', () {
    test('touching reigns count as contemporaries', () {
      // Ahaziah of Judah reigned only in 841 BC; Jehu came to Israel's
      // throne in 841 BC and killed him. A half-open test would report
      // the two men who met that year as never having overlapped.
      final ahaziah = _king(id: 'ahaziah_judah', start: -841, end: -841);
      final jehu = _king(
        id: 'jehu',
        start: -841,
        end: -814,
        kingdom: Kingdom.israel,
      );
      expect(reignsOverlap(ahaziah, jehu), isTrue);
      expect(reignsOverlap(jehu, ahaziah), isTrue);
    });

    test('a zero-length reign still overlaps the reign containing it', () {
      // Zimri held Tirzah seven days, which rounds to a single year.
      final zimri = _king(
        id: 'zimri',
        start: -885,
        end: -885,
        kingdom: Kingdom.israel,
      );
      final asa = _king(id: 'asa', start: -911, end: -870);
      expect(reignsOverlap(zimri, asa), isTrue);
    });

    test('separated reigns do not overlap', () {
      final earlier = _king(id: 'a', start: -931, end: -913);
      final later = _king(id: 'b', start: -912, end: -900);
      expect(reignsOverlap(earlier, later), isFalse);
    });
  });

  group('placeLabels', () {
    test('keeps a minimum gap between neighbours', () {
      final out = placeLabels([10, 12, 13, 60], 20, 400);
      for (var i = 1; i < out.length; i++) {
        expect(out[i] - out[i - 1], greaterThanOrEqualTo(20 - 1e-9));
      }
    });

    test('stays inside the chart when the tail would overflow', () {
      final out = placeLabels([90, 92, 94, 96], 20, 100);
      expect(out.first, greaterThanOrEqualTo(-1e-9));
      expect(out.last + 20, lessThanOrEqualTo(100 + 1e-9));
      for (var i = 1; i < out.length; i++) {
        expect(out[i] - out[i - 1], greaterThanOrEqualTo(20 - 1e-9));
      }
    });

    test('leaves already-spaced labels where they are', () {
      final out = placeLabels([0, 40, 80], 20, 200);
      expect(out, [0, 40, 80]);
    });

    test('distributes evenly rather than piling up when they cannot fit', () {
      // Ten labels needing 20px each in 100px: an even overlap is
      // legible, a pile at one end is not.
      final out = placeLabels(List.generate(10, (i) => 0), 20, 100);
      expect(out.length, 10);
      expect(out.first, 0);
      expect(out.last, closeTo(90, 1e-9));
      for (var i = 1; i < out.length; i++) {
        expect(out[i], greaterThan(out[i - 1]));
      }
    });

    test('empty and degenerate inputs are safe', () {
      expect(placeLabels(const [], 20, 100), isEmpty);
      expect(placeLabels([5, 5], 0, 100), [5, 5]);
    });
  });

  group('yForYear', () {
    test('maps the axis ends to the pixel ends', () {
      expect(yForYear(-931, -931, -586, 345), 0);
      expect(yForYear(-586, -931, -586, 345), 345);
      expect(yForYear(-758, -931, -586, 345), closeTo(173, 1));
    });

    test('clamps out-of-range years and degenerate axes', () {
      expect(yForYear(-1000, -931, -586, 345), 0);
      expect(yForYear(-100, -931, -586, 345), 345);
      expect(yForYear(-900, -931, -931, 345), 0);
      expect(yForYear(-900, -931, -586, 0), 0);
    });
  });

  group('assets/hebrew_kings.json', () {
    late HebrewKingsData data;
    late Map<String, dynamic> raw;

    setUpAll(() async {
      final text = await rootBundle.loadString('assets/hebrew_kings.json');
      raw = json.decode(text) as Map<String, dynamic>;
      data = HebrewKingsData.fromJson(raw);
    });

    test('declares the chronology it uses, by name and as a field', () {
      expect(raw['system'], 'thiele');
      expect(data.systemNameFor('en'), 'Thiele');
      expect(data.systemNameFor('zh-Hans'), isNotEmpty);
      expect(data.systemNameFor('zh-Hant'), isNotEmpty);
      expect(data.sources, isNotEmpty);
    });

    test('carries every king of both kingdoms plus the united monarchy', () {
      expect(data.kings.length, 42);
      expect(data.ofKingdom(Kingdom.judah).length, 20);
      expect(data.ofKingdom(Kingdom.israel).length, 20);
      expect(data.ofKingdom(Kingdom.united).length, 2);
      expect(data.kings.map((k) => k.id).toSet().length, data.kings.length);
    });

    test('every king is named in all three locales', () {
      for (final k in data.kings) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(k.names[locale], isNotNull, reason: '${k.id}/$locale');
          expect(k.names[locale], isNotEmpty, reason: '${k.id}/$locale');
        }
      }
    });

    test('spans are well formed and hand over at a shared year', () {
      for (final k in data.kings) {
        expect(k.spans, isNotEmpty, reason: k.id);
        expect(
          k.spans.where((s) => s.kind == SpanKind.sole).length,
          lessThanOrEqualTo(1),
          reason: '${k.id} cannot reign alone twice',
        );
        for (final s in k.spans) {
          expect(s.end, greaterThanOrEqualTo(s.start), reason: k.id);
          expect(s.start, greaterThan(-1100), reason: k.id);
          expect(s.end, lessThan(-500), reason: k.id);
        }
        for (var i = 1; i < k.spans.length; i++) {
          expect(k.spans[i].start, k.spans[i - 1].end, reason: k.id);
        }
        expect(k.reignStart, k.spans.first.start, reason: k.id);
        expect(k.reignEnd, k.spans.last.end, reason: k.id);
      }
    });

    test('the throne is never vacant from the division to the fall', () {
      // Not "sole reigns tile the axis": between 885 and 880 Israel had
      // no single recognised king, Tibni and Omri each claiming it. So
      // the union of sole AND rival spans is what must be unbroken.
      for (final (kingdom, lastYear) in [
        (Kingdom.judah, -586),
        (Kingdom.israel, -722),
      ]) {
        final held = <(int, int, String)>[];
        for (final k in data.ofKingdom(kingdom)) {
          for (final s in k.spans) {
            if (s.kind != SpanKind.coregency) {
              held.add((s.start, s.end, k.id));
            }
          }
        }
        held.sort((a, b) => a.$1.compareTo(b.$1));
        expect(held.first.$1, -931, reason: '$kingdom');
        var reach = held.first.$2;
        for (final (start, end, id) in held.skip(1)) {
          expect(start, lessThanOrEqualTo(reach),
              reason: '$kingdom: throne vacant before $id');
          if (end > reach) reach = end;
        }
        expect(reach, lastYear, reason: '$kingdom');
      }
    });

    test('no two kings of one kingdom reign alone at the same time', () {
      for (final kingdom in [Kingdom.judah, Kingdom.israel]) {
        final sole = data
            .ofKingdom(kingdom)
            .map((k) => (k, k.soleReign))
            .where((e) => e.$2 != null)
            .toList();
        for (var i = 0; i < sole.length; i++) {
          for (var j = i + 1; j < sole.length; j++) {
            final a = sole[i].$2!;
            final b = sole[j].$2!;
            final overlap = a.start < b.end && b.start < a.end;
            expect(overlap, isFalse,
                reason: '${sole[i].$1.id} and ${sole[j].$1.id}');
          }
        }
      }
    });

    test('co-regencies and rival claims are modelled, not flattened', () {
      final coregents = data.kings
          .where((k) => k.spans.any((s) => s.kind == SpanKind.coregency))
          .map((k) => k.id)
          .toSet();
      // Thiele's six Judean co-regencies plus Jeroboam II in Israel.
      expect(
        coregents,
        containsAll([
          'jehoshaphat',
          'jehoram_judah',
          'uzziah',
          'jotham',
          'ahaz',
          'manasseh',
          'jeroboam_ii',
        ]),
      );

      final tibni = data.byId('tibni');
      expect(tibni, isNotNull);
      // Tibni never reigned alone, which is exactly why a reign has to
      // be a list of spans rather than one bar.
      expect(tibni!.isRival, isTrue);
      expect(tibni.soleReign, isNull);
      expect(data.byId('pekah')!.spans.first.kind, SpanKind.rival);
    });

    test('Asa overlaps the northern kings the synchronisms require', () {
      final asa = data.byId('asa')!;
      expect(
        data.contemporariesOf(asa).map((k) => k.id).toList(),
        ['jeroboam_i', 'nadab', 'baasha', 'elah', 'zimri', 'tibni', 'omri',
            'ahab'],
      );
    });

    test('contemporaries are symmetric and cross the border', () {
      for (final k in data.kings.where((e) => e.kingdom != Kingdom.united)) {
        for (final c in data.contemporariesOf(k)) {
          expect(c.kingdom, isNot(k.kingdom), reason: '${k.id}/${c.id}');
          expect(data.contemporariesOf(c).map((e) => e.id), contains(k.id));
        }
      }
      // The united monarchy predates the split, so it has none.
      expect(data.contemporariesOf(data.byId('solomon')!), isEmpty);
    });

    test('Chronicles is cited for Judah only, and Kings for everyone', () {
      for (final k in data.ofKingdom(Kingdom.israel)) {
        expect(k.chroniclesRef, isNull, reason: k.id);
      }
      for (final k in data.ofKingdom(Kingdom.judah)) {
        expect(k.chroniclesRef, isNotNull, reason: k.id);
      }
      for (final k in data.kings) {
        expect(k.kingsRef, isNotNull, reason: k.id);
      }
    });

    test('every cited reference round-trips through the app parser', () {
      for (final k in data.kings) {
        for (final ref in [k.kingsRef, k.chroniclesRef, k.accessionRef]) {
          if (ref == null) continue;
          expect(parseReference(ref), isNotNull, reason: '${k.id}: $ref');
        }
      }
      for (final e in data.epochs) {
        if (e.ref != null) {
          expect(parseReference(e.ref!), isNotNull, reason: e.id);
        }
      }
    });

    test('the epochs the chart marks are present and dated', () {
      final byId = {for (final e in data.epochs) e.id: e};
      expect(byId['division']!.year, -931);
      expect(byId['samaria']!.year, -722);
      expect(byId['jerusalem']!.year, -586);
      for (final e in data.epochs) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(e.names[locale], isNotEmpty, reason: '${e.id}/$locale');
        }
      }
    });

    test('the axis extent spans David to the exile', () {
      final (lo, hi) = data.extent;
      expect(lo, -1010);
      expect(hi, -586);
    });
  });

  // ── The contemporaries derivation ───────────────────────────────
  //
  // ASA IS THE CASE THAT DECIDES THE DESIGN. The eight northern men
  // inside his 911-870 are Jeroboam I, Nadab, Baasha, Elah, Zimri,
  // Tibni, Omri and Ahab, and every plausible way of getting a smaller
  // number is an editorial rule Scripture does not use:
  //
  //   drop Jeroboam I  — he touches only at the edge. But 1 Kings 15:9
  //                      dates Asa's accession to Jeroboam's twentieth
  //                      year and 1 Kings 15:25 dates Nadab's to Asa's
  //                      second, so the shared year is the synchronism
  //                      itself, not a rounding artefact. (~1 year on
  //                      Thiele, ~12 on Albright.)
  //   drop Zimri       — he reigned seven days. But he carries the full
  //                      regnal formula, 1 Kings 16:15-20, and reign
  //                      length is not a criterion the text applies.
  //   drop Tibni       — he is a claimant, and that is true; 1 Kings
  //                      16:21-22 gives him no regnal formula. So he is
  //                      SHOWN AND MARKED, and the tally reports 8 and
  //                      7 rather than choosing.
  //
  // Anything that made 5 or 6 come out of this function would be a
  // threshold invented here. There is no threshold here.
  group('contemporaries derivation', () {
    late HebrewKingsData data;

    setUpAll(() async {
      final text = await rootBundle.loadString('assets/hebrew_kings.json');
      data = HebrewKingsData.fromJson(json.decode(text) as Map<String, dynamic>);
    });

    test('Asa: eight contemporaries, seven of them kings', () {
      final asa = data.byId('asa')!;
      final contemporaries = data.contemporariesOf(asa);

      expect(
        contemporaries.map((k) => k.id).toList(),
        ['jeroboam_i', 'nadab', 'baasha', 'elah', 'zimri', 'tibni', 'omri',
            'ahab'],
      );

      final tally = data.tallyFor(asa);
      expect(tally.total, 8);
      expect(tally.reigning, 7);
      expect(tally.rivals, 1);
      expect(tally.hasRivals, isTrue);
      expect(tally.reigning + tally.rivals, tally.total);

      // The one claimant is Tibni and nobody else.
      expect(
        contemporaries.where((k) => k.isRival).map((k) => k.id).toList(),
        ['tibni'],
      );
    });

    test('Jeroboam I counts although he touches Asa only at the edge', () {
      final asa = data.byId('asa')!;
      final jeroboam = data.byId('jeroboam_i')!;

      // The overlap really is a single boundary year on these figures.
      expect(asa.reignStart, -911);
      expect(jeroboam.reignEnd, -910);
      expect(jeroboam.reignEnd - asa.reignStart, 1);

      expect(reignsOverlap(jeroboam, asa), isTrue);
      expect(data.contemporariesOf(asa), contains(jeroboam));

      // And the synchronism the text gives for that accession is on the
      // record it came from, not asserted here.
      expect(asa.accessionRef, isNotNull);
    });

    test('Zimri counts although his reign starts and ends in one year', () {
      final zimri = data.byId('zimri')!;
      expect(zimri.reignStart, zimri.reignEnd);
      expect(zimri.totalYears, 0);

      // A half-open rule, or any minimum duration, erases him.
      expect(reignsOverlap(zimri, data.byId('asa')!), isTrue);
      expect(data.contemporariesOf(data.byId('asa')!), contains(zimri));

      // He is NOT a claimant: his span is a sole reign, so he is one of
      // the seven, not the eighth.
      expect(zimri.isRival, isFalse);
      expect(zimri.spans.single.kind, SpanKind.sole);
    });

    test('Tibni is counted but marked, and Omri is not marked', () {
      final tibni = data.byId('tibni')!;
      expect(tibni.spans.every((s) => s.kind == SpanKind.rival), isTrue);
      expect(tibni.isRival, isTrue);

      // Omri's first span is the same contest, but it is followed by a
      // sole reign — the four years against Tibni ended with Omri on
      // the throne — so he must not be demoted with him.
      final omri = data.byId('omri')!;
      expect(omri.spans.first.kind, SpanKind.rival);
      expect(omri.isRival, isFalse);

      // Which is what makes 7 the count of kings rather than 6.
      final tally = data.tallyFor(data.byId('asa')!);
      expect(tally.reigning, 7);
    });

    test('Elah, Zimri and Omri all touch 885 and all three are returned',
        () {
      final elah = data.byId('elah')!;
      final zimri = data.byId('zimri')!;
      final omri = data.byId('omri')!;
      expect(elah.reignEnd, -885);
      expect(zimri.reignStart, -885);
      expect(zimri.reignEnd, -885);
      expect(omri.reignStart, -885);

      // A shared endpoint is a handover, and the men who met at it were
      // contemporaries. Elah was killed by Zimri and Zimri died as Omri
      // came against him; a half-open rule would report that none of
      // the three ever coincided.
      expect(reignsOverlap(elah, zimri), isTrue);
      expect(reignsOverlap(zimri, omri), isTrue);
      expect(reignsOverlap(elah, omri), isTrue);

      final in885 = reigningInYear(data.kings, -885, kingdom: Kingdom.israel)
          .map((k) => k.id)
          .toList();
      expect(in885, containsAll(['elah', 'zimri', 'omri']));

      // Asa keeps all three, which is three of his eight.
      final asaIds = data.contemporariesOf(data.byId('asa')!).map((k) => k.id);
      expect(asaIds, containsAll(['elah', 'zimri', 'omri']));
    });

    test('the tally is read off spans, not off a list of names', () {
      // Re-kind every span of Baasha to `rival` and the reigning count
      // must fall by one WITHOUT any name being mentioned anywhere.
      final asa = data.byId('asa')!;
      final real = data.contemporariesOf(asa);
      expect(ContemporaryTally.of(real).reigning, 7);

      final demoted = real
          .map((k) => k.id != 'baasha'
              ? k
              : HebrewKing(
                  id: k.id,
                  kingdom: k.kingdom,
                  house: k.house,
                  names: k.names,
                  spans: k.spans
                      .map((s) => ReignSpan(
                          kind: SpanKind.rival, start: s.start, end: s.end))
                      .toList(),
                  reignStart: k.reignStart,
                  reignEnd: k.reignEnd,
                ))
          .toList();
      final after = ContemporaryTally.of(demoted);
      expect(after.total, 8);
      expect(after.reigning, 6);
      expect(after.rivals, 2);
    });

    test('a king with no spans is not silently demoted to a claimant', () {
      // `every` on an empty list is true, so an unguarded `isRival`
      // would call a king with unparsed spans a claimant and drop him
      // out of every reigning count.
      const empty = HebrewKing(
        id: 'x',
        kingdom: Kingdom.israel,
        house: 'x',
        names: {'en': 'X'},
        spans: [],
        reignStart: -900,
        reignEnd: -890,
      );
      expect(empty.isRival, isFalse);
      expect(ContemporaryTally.of([empty]).reigning, 1);
    });
  });

  // ── Reverse lookup by year ──────────────────────────────────────
  group('reigningInYear', () {
    late HebrewKingsData data;

    setUpAll(() async {
      final text = await rootBundle.loadString('assets/hebrew_kings.json');
      data = HebrewKingsData.fromJson(json.decode(text) as Map<String, dynamic>);
    });

    test('answers for both thrones in a divided year', () {
      final judah = data.reigningIn(-870, kingdom: Kingdom.judah);
      final israel = data.reigningIn(-870, kingdom: Kingdom.israel);
      expect(judah, isNotEmpty);
      expect(israel, isNotEmpty);
      for (final k in judah) {
        expect(k.reignStart <= -870 && -870 <= k.reignEnd, isTrue,
            reason: k.id);
      }
      for (final k in israel) {
        expect(k.reignStart <= -870 && -870 <= k.reignEnd, isTrue,
            reason: k.id);
      }
    });

    test('a boundary year returns both the outgoing and incoming king', () {
      // 841: Jehu came to Israel's throne and killed Ahaziah of Judah.
      final ids = data.reigningIn(-841).map((k) => k.id).toList();
      expect(ids, contains('jehu'));
      expect(ids, contains('ahaziah_judah'));
    });

    test('Israel is empty after Samaria falls, Judah is not', () {
      // The epoch is in the asset; the emptiness is derived from it.
      // Years are negative, so LATER than the fall is fall + 10.
      final fall = data.epochs.firstWhere((e) => e.id == 'samaria').year;
      expect(fall, -722);
      expect(data.reigningIn(fall + 10, kingdom: Kingdom.israel), isEmpty);
      expect(data.reigningIn(fall + 10, kingdom: Kingdom.judah), isNotEmpty);
      // And before it, Israel still has a king.
      expect(data.reigningIn(fall - 10, kingdom: Kingdom.israel), isNotEmpty);
    });

    test('nobody reigns after Jerusalem falls', () {
      final fall = data.epochs.firstWhere((e) => e.id == 'jerusalem').year;
      expect(data.reigningIn(fall + 1), isEmpty);
    });

    test('agrees with contemporariesOf on every year of a reign', () {
      // The two queries share `closedIntervalsOverlap`, and this is the
      // assertion that would catch them being given separate rules: a
      // man in Asa's contemporaries list must be reigning in at least
      // one year Asa was.
      final asa = data.byId('asa')!;
      for (final c in data.contemporariesOf(asa)) {
        final shared = <int>[
          for (var y = asa.reignStart; y <= asa.reignEnd; y++)
            if (data.reigningIn(y, kingdom: c.kingdom).contains(c)) y,
        ];
        expect(shared, isNotEmpty, reason: c.id);
      }
    });

    test('extent covers every reign in the file', () {
      final (lo, hi) = reignExtent(data.kings)!;
      for (final k in data.kings) {
        expect(k.reignStart, greaterThanOrEqualTo(lo));
        expect(k.reignEnd, lessThanOrEqualTo(hi));
      }
      expect(reignExtent(const <HebrewKing>[]), isNull);
    });
  });

  // ── Search ──────────────────────────────────────────────────────
  group('searchKings', () {
    late HebrewKingsData data;

    setUpAll(() async {
      final text = await rootBundle.loadString('assets/hebrew_kings.json');
      data = HebrewKingsData.fromJson(json.decode(text) as Map<String, dynamic>);
    });

    test('finds a king by his name in each of the three languages', () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final asa = data.byId('asa')!;
        final name = asa.nameFor(locale);
        expect(name, isNotEmpty, reason: locale);
        expect(data.search(name, locale).map((k) => k.id), contains('asa'),
            reason: locale);
      }
    });

    test('every king is reachable by his own name in every language', () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        for (final k in data.kings) {
          expect(
            data.search(k.nameFor(locale), locale).map((e) => e.id),
            contains(k.id),
            reason: '${k.id}/$locale',
          );
        }
      }
    });

    test('matches on a scripture reference too', () {
      final withRef = data.kings.firstWhere((k) => k.kingsRef != null);
      expect(
        data.search(withRef.kingsRef!, 'en').map((k) => k.id),
        contains(withRef.id),
      );
    });

    test('an empty query returns everyone, in chronological order', () {
      final all = data.search('   ', 'en');
      expect(all.length, data.kings.length);
      for (var i = 1; i < all.length; i++) {
        expect(all[i].reignStart, greaterThanOrEqualTo(all[i - 1].reignStart));
      }
    });

    test('a query that matches nobody returns empty, not everybody', () {
      expect(data.search('zzzznotaking', 'en'), isEmpty);
    });

    test('results stay in chronological order, not relevance order', () {
      final hits = data.search('jeho', 'en');
      expect(hits.length, greaterThan(1));
      for (var i = 1; i < hits.length; i++) {
        expect(hits[i].reignStart, greaterThanOrEqualTo(hits[i - 1].reignStart));
      }
    });
  });

  // ── The widgets the WHEEL's reign sheet shares with the page ────
  //
  // `wheel_sheets.dart` draws its kings on a Canvas, so a tap on a
  // reign arc cannot be driven from a widget test and canvas text
  // leaves no semantics node to assert on (AGENTS.md, trap 1). What
  // CAN be pinned is the content: the wheel sheet builds its
  // contemporaries block out of these four public helpers, the same
  // objects the page uses, so pumping them proves what that sheet
  // prints even though the arc that opens it cannot be tapped here.
  group('the shared contemporaries widgets', () {
    late HebrewKingsData data;

    setUpAll(() async {
      final text = await rootBundle.loadString('assets/hebrew_kings.json');
      data = HebrewKingsData.fromJson(json.decode(text) as Map<String, dynamic>);
    });

    Future<void> pumpHelpers(WidgetTester tester, String locale) async {
      final tally = data.tallyFor(data.byId('asa')!);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainProvider()),
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    kingsTallyLines(ctx, tally, Kingdom.israel, locale),
                    kingsRivalBadge(ctx, locale),
                    kingsRivalExplanation(ctx, locale),
                    kingsChronologyCaveat(ctx, locale),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('print 7 and 1 for Asa, in every language', (tester) async {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        await pumpHelpers(tester, locale);
        expect(tester.takeException(), isNull, reason: locale);

        String filled(String key, int n) =>
            uiStrings[key]![locale]!.replaceAll('{n}', '$n');

        expect(find.text(filled('kingsTallyReigning', 7)), findsOneWidget,
            reason: locale);
        expect(find.text(filled('kingsTallyRival', 1)), findsOneWidget,
            reason: locale);
        // The rival mark is a real word in this language, not an
        // English literal leaking through a missing key.
        expect(find.text(uiStrings['kingsRivalClaimant']![locale]!),
            findsOneWidget,
            reason: locale);
        expect(find.text(uiStrings['kingsTallyBasis']![locale]!),
            findsOneWidget,
            reason: locale);
        expect(find.text(uiStrings['kingsRivalClaimantWhy']![locale]!),
            findsOneWidget,
            reason: locale);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('the rival line is omitted when there are no claimants',
        (tester) async {
      // Jehoshaphat's northern contemporaries include no claimant, so
      // the panel must not print "Rival claimants · 0".
      final tally = data.tallyFor(data.byId('jehoshaphat')!);
      expect(tally.rivals, 0);
      expect(tally.hasRivals, isFalse);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainProvider()),
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) =>
                    kingsTallyLines(ctx, tally, Kingdom.israel, 'zh-Hans'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('在位的王 · ${tally.reigning}'), findsOneWidget);
      expect(find.textContaining('争位者'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group("the chart's own header", () {
    late HebrewKingsData data;
    late Map<String, dynamic> raw;

    setUpAll(() async {
      final text = await rootBundle.loadString('assets/hebrew_kings.json');
      raw = json.decode(text) as Map<String, dynamic>;
      data = HebrewKingsData.fromJson(raw);
    });

    test('the asset\'s note is trilingual and reaches the model', () {
      expect(data.meta.note.keys.toSet(), {'en', 'zh-Hans', 'zh-Hant'});
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(data.meta.note[locale], isNotEmpty, reason: locale);
      }
      expect(data.meta.noteFor('en'), contains('792/791'));
      expect(data.meta.noteFor('zh-Hans'), contains('792/791'));
    });

    // Four keys the model does not parse, each excused by name: `generator`
    // and `kingCount` are build facts, `yearSign` describes the JSON's
    // minus signs (which no screen shows — the UI always prints "BC"),
    // and `systems` is already stated permanently by `kingsSystemsDiffer`
    // in the header bar (`_Header` at hebrew_kings_page.dart:317-330). A
    // NEW `_meta` key appearing here must be read by the model, not added
    // to this excuse list.
    test(
        "the header's reader-facing fields are all disclosed, "
        'and the rest are excused by name', () {
      final meta = (raw['_meta'] as Map).cast<String, dynamic>();
      expect(
        meta.keys.toSet(),
        <String>{
          'generator',
          'kingCount',
          'yearSign',
          'note',
          'systems',
          'sources',
        },
      );
    });
  });

  // The page's whole reason for existing is that selecting a king shows
  // who stood on the other throne. Rendered at desktop width so the
  // detail panel is present rather than behind a sheet.
  group('HebrewKingsPage', () {
    // Rendered in the app's default zh-Hans: AppSettings only reads the
    // persisted locale from loadSettings(), which nothing calls here, and
    // setLocale() leaves a notification-rescheduling timer pending that
    // fails the widget-tree teardown. Testing the shipped default is
    // worth more than testing English anyway — the ui_strings coverage
    // check below is what guards the other two locales.
    Future<void> pump(WidgetTester tester, Size size) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      // Reading the asset is real I/O, which fake-time pumps do not
      // advance; warming the service cache first makes the FutureBuilder
      // resolve within the pumps below instead of intermittently.
      await tester.runAsync(HebrewKingsService.instance.load);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainProvider()),
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: const MaterialApp(home: HebrewKingsPage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('tapping Asa names the northern kings of his day',
        (tester) async {
      await pump(tester, const Size(1440, 1000));
      expect(tester.takeException(), isNull);

      // Before selection the panel only invites one.
      expect(find.textContaining('同期在另一国的君王'), findsNothing);

      final asa = find.text('亚撒');
      expect(asa, findsWidgets);
      await tester.tapAt(tester.getCenter(asa.first));
      await tester.pump();

      expect(find.textContaining('同期在另一国的君王 · 以色列 · 8'),
          findsOneWidget);
      // Zimri reigned seven days and is still on the chart and in the
      // list; a scale-only layout would have lost him.
      expect(find.text('心利'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    // THE TWO NUMBERS HAVE TO BE ON THE SCREEN, not merely in the
    // function. `contemporaries derivation` above proves 8 and 7 come
    // out of the data; this proves a reader sees both, and sees which
    // of the eight names the difference is.
    testWidgets('Asa\'s panel prints 8, 7 and 1, and marks the claimant',
        (tester) async {
      // TALLER THAN THE OTHER TESTS ON PURPOSE. The detail panel is a
      // ListView, which builds its children lazily, so a row scrolled
      // out of view is not merely invisible — it is absent from the
      // element tree and no finder can reach it. A viewport that seats
      // the whole panel is what lets this test assert about the rows
      // as a reader sees them rather than about a scroll offset.
      await pump(tester, const Size(1440, 1900));

      final asa = find.text('亚撒');
      await tester.tapAt(tester.getCenter(asa.first));
      await tester.pump();

      // 8 in the section heading, 7 and 1 broken out beneath it.
      expect(find.textContaining('同期在另一国的君王 · 以色列 · 8'),
          findsOneWidget);
      expect(find.text('在位的王 · 7'), findsOneWidget);
      expect(find.text('争位者 · 1'), findsOneWidget);

      // The claimant is named and badged, so a reader can see WHICH of
      // the eight the two counts differ over.
      expect(find.text('提比尼'), findsWidgets);
      // The badge's text is exactly '争位者'; the tally line above reads
      // '争位者 · 1', so an exact match can only be the badge.
      expect(find.text('争位者'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('a count of contemporaries carries the chronology caveat',
        (tester) async {
      await pump(tester, const Size(1440, 1900));
      await tester.tapAt(tester.getCenter(find.text('亚撒').first));
      await tester.pump();

      expect(find.textContaining('同期君王的数目取决于所用的年代系统'),
          findsOneWidget);
      // And the claimant's own justification cites the passage the
      // asset stores for him.
      expect(find.textContaining('《列王纪上》16:21-22'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('a contemporary row carries the king\'s own reference',
        (tester) async {
      await pump(tester, const Size(1440, 1900));
      await tester.tapAt(tester.getCenter(find.text('亚撒').first));
      await tester.pump();

      // Ahab's row prints his passage, localised — the row exists so
      // the reader does not have to select each man to find it.
      expect(find.textContaining('16:29'), findsWidgets);
      // And Zimri's, which is the row a duration threshold would have
      // removed from this list altogether.
      expect(find.textContaining('16:15'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('search narrows the page to the kings that match',
        (tester) async {
      await pump(tester, const Size(1440, 1000));

      final box = find.widgetWithText(TextField, '按君王姓名或经文搜索…');
      expect(box, findsOneWidget);

      await tester.enterText(box, '亚哈');
      await tester.pump();

      // Ahab is found; Asa, who was on the chart a moment ago, is not.
      expect(find.text('亚哈'), findsWidgets);
      expect(find.text('亚撒'), findsNothing);

      // Clearing brings the whole chart back.
      await tester.enterText(box, '');
      await tester.pump();
      expect(find.text('亚撒'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    // THE DISCLOSURE MUST NOT SCROLL AWAY WITH THE CHART. Search
    // replaces the chart body, and the header carrying "which
    // chronology, and that others differ" sits above both — so a
    // reader who is looking at a filtered list of reign years is still
    // being told whose years they are.
    testWidgets('the chronology disclosure survives into search mode',
        (tester) async {
      await pump(tester, const Size(1440, 1000));
      final differ = find.textContaining('各年代系统在以尼散月或提斯利月为岁首');
      expect(differ, findsOneWidget);
      expect(find.textContaining('年代系统: 锡尔年代系统'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, '按君王姓名或经文搜索…'), '亚哈');
      await tester.pump();

      expect(differ, findsOneWidget);
      expect(find.textContaining('年代系统: 锡尔年代系统'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('search matches a scripture reference', (tester) async {
      await pump(tester, const Size(1440, 1000));
      final box = find.widgetWithText(TextField, '按君王姓名或经文搜索…');
      await tester.enterText(box, '16:15');
      await tester.pump();
      // Zimri, 1 Kings 16:15-20.
      expect(find.text('心利'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('a query that matches nobody says so', (tester) async {
      await pump(tester, const Size(1440, 1000));
      final box = find.widgetWithText(TextField, '按君王姓名或经文搜索…');
      await tester.enterText(box, 'zzzznotaking');
      await tester.pump();
      expect(find.text('没有符合的君王。'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('the year lookup answers for both thrones, and says BC',
        (tester) async {
      await pump(tester, const Size(1440, 1000));

      await tester.tap(find.text('某一年谁在位'));
      await tester.pumpAndSettle();

      // The sheet is explicit that a bare number means BC.
      expect(find.textContaining('年份一律为公元前'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '年份'), '870');
      await tester.pump();

      // 870 BC: Asa's last year in Judah, Ahab's fifth in Israel.
      expect(find.text('公元前870年'), findsWidgets);
      expect(find.text('犹大'), findsWidgets);
      expect(find.text('以色列'), findsWidgets);
      expect(find.text('亚撒'), findsWidgets);
      expect(find.text('亚哈'), findsWidgets);
      // A year lookup is a claim about dates, so it carries the caveat.
      expect(find.textContaining('同期君王的数目取决于所用的年代系统'),
          findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('the year lookup reports an empty throne after 722',
        (tester) async {
      await pump(tester, const Size(1440, 1000));
      await tester.tap(find.text('某一年谁在位'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '年份'), '700');
      await tester.pump();

      // Judah still has a king in 700 BC; Israel has fallen, and the
      // sheet says "None" rather than omitting the column.
      expect(find.text('无'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('every king is labelled, including the shortest reigns',
        (tester) async {
      await pump(tester, const Size(1440, 1000));
      // Zimri (seven days), Shallum (one month), Jehoahaz and Jehoiachin
      // (three months each) are sub-pixel at any honest scale.
      for (final name in ['心利', '沙龙', '约哈斯', '约雅斤']) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('names the chronology it is drawn on', (tester) async {
      await pump(tester, const Size(1440, 1000));
      expect(find.textContaining('锡尔'), findsWidgets);
      expect(find.textContaining('尼散月'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('a phone-width chart scrolls sideways instead of squeezing',
        (tester) async {
      await pump(tester, const Size(320, 568));
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    // Below _sideBySideMinWidth (900) the detail panel — and the Sources
    // block inside its empty state — is never built at all; the About
    // action is the only route to the citations at this width.
    testWidgets('the About action reaches the sources at a width where '
        'the panel does not', (tester) async {
      await pump(tester, const Size(880, 700));
      expect(tester.takeException(), isNull);

      expect(find.textContaining('Mysterious Numbers'), findsNothing);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Mysterious Numbers'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets(
        'the precision note is on screen once the About sheet is open',
        (tester) async {
      await pump(tester, const Size(880, 700));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('792/791'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  test('every string the page shows exists in all three locales', () {
    // The page falls back to inline English when a key is missing, so a
    // forgotten translation ships silently rather than crashing.
    const keys = [
      'hebrewKings',
      'kingsJudah',
      'kingsIsrael',
      'kingsUnited',
      'kingsSole',
      'kingsCoregency',
      'kingsRival',
      'kingsChronology',
      'kingsSystemsDiffer',
      'kingsSelectHint',
      'kingsSources',
      'kingsAbout',
      'kingsAboutPrecision',
      'kingsAboutSystem',
      'kingsReign',
      'kingsPassages',
      'kingsAccession',
      'kingsInKings',
      'kingsInChronicles',
      'kingsNoChronicles',
      'kingsContemporaries',
      'kingsNoContemporaries',
      'kingsHouseOf',
    ];
    for (final key in keys) {
      final entry = uiStrings[key];
      expect(entry, isNotNull, reason: key);
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(entry![locale], isNotNull, reason: '$key/$locale');
        expect(entry[locale], isNotEmpty, reason: '$key/$locale');
      }
    }
    // The house line is built by substitution, so the placeholder has to
    // survive into every locale or "House of Omri" loses the name.
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      expect(uiStrings['kingsHouseOf']![locale], contains('{name}'));
    }
  });
}
