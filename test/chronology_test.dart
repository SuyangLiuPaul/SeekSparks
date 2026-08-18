import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/utils/chronology_layout.dart';

/// The chart is arithmetic on ages the Bible states, so the tests that
/// matter are about the arithmetic and about the asset, not about
/// widgets. A widget test would pass just as happily on wrong numbers.
void main() {
  group('sharedYears', () {
    test('lives that never met share nothing', () {
      expect(sharedYears(0, 100, 200, 300), 0);
      expect(sharedYears(200, 300, 0, 100), 0);
    });

    test('a bare touch is zero, not negative', () {
      expect(sharedYears(0, 100, 100, 200), 0);
    });

    test('the overlap is the shorter of the two containments', () {
      expect(sharedYears(0, 100, 50, 150), 50);
      expect(sharedYears(50, 150, 0, 100), 50);
      // One life wholly inside another.
      expect(sharedYears(0, 900, 100, 200), 100);
    });
  });

  test('aliveAt includes both endpoints', () {
    expect(aliveAt(10, 20, 9), isFalse);
    expect(aliveAt(10, 20, 10), isTrue);
    expect(aliveAt(10, 20, 20), isTrue);
    expect(aliveAt(10, 20, 21), isFalse);
  });

  group('xForYear', () {
    test('maps the ends of the axis onto the ends of the width', () {
      expect(xForYear(0, 0, 100, 200), 0);
      expect(xForYear(100, 0, 100, 200), 200);
      expect(xForYear(50, 0, 100, 200), 100);
    });

    test('degenerate axes do not divide by zero', () {
      expect(xForYear(5, 10, 10, 200), 0);
      expect(xForYear(5, 0, 100, 0), 0);
    });
  });

  group('axisTicks', () {
    test('ticks are round numbers inside the range', () {
      final ticks = axisTicks(0, 2000, 800);
      expect(ticks, isNotEmpty);
      expect(ticks.first, greaterThanOrEqualTo(0));
      expect(ticks.last, lessThanOrEqualTo(2000));
      for (final t in ticks) {
        expect(t % 100, 0);
      }
    });

    test('a narrow chart uses a coarser step rather than crowding', () {
      final wide = axisTicks(0, 3000, 1600);
      final narrow = axisTicks(0, 3000, 300);
      expect(narrow.length, lessThan(wide.length));
    });

    test('no ticks for a degenerate range', () {
      expect(axisTicks(0, 0, 500), isEmpty);
      expect(axisTicks(0, 100, 0), isEmpty);
    });
  });

  group('contemporaries', () {
    final lives = <String, (int, int)>{
      'a': (0, 100),
      'b': (50, 150),
      'c': (90, 200),
      'far': (900, 1000),
    };

    test('excludes the subject and anyone who never overlapped', () {
      final out = contemporaries('a', 0, 100, lives);
      expect(out.map((e) => e.id), isNot(contains('a')));
      expect(out.map((e) => e.id), isNot(contains('far')));
    });

    test('sorted by overlap, longest first', () {
      final out = contemporaries('a', 0, 100, lives);
      expect(out.map((e) => e.id).toList(), ['b', 'c']);
      expect(out.first.years, 50);
    });

    test('bornDuring and diedDuring describe the right end', () {
      final out = contemporaries('a', 0, 100, lives);
      final b = out.firstWhere((e) => e.id == 'b');
      expect(b.bornDuring, isTrue, reason: 'b was born while a lived');
      expect(b.diedDuring, isFalse, reason: 'b outlived a');
    });
  });

  group('assets/chronology.json', () {
    late ChronologyData data;

    setUpAll(() {
      final raw = File('assets/chronology.json').readAsStringSync();
      data = ChronologyData.fromJson(
          json.decode(raw) as Map<String, dynamic>);
    });

    test('holds both texts we ship, and neither is empty', () {
      expect(data.traditions.map((t) => t.id).toList(), ['mt', 'lxx']);
      expect(data.inTradition('mt'), isNotEmpty);
      expect(data.inTradition('lxx'), isNotEmpty);
    });

    test('every figure is internally consistent', () {
      for (final p in data.patriarchs) {
        for (final entry in p.figures.entries) {
          final f = entry.value;
          expect(f.deathAm - f.birthAm, f.lifespan,
              reason: '${p.id} (${entry.key}) span disagrees with lifespan');
          final begat = f.begatAt;
          final after = f.livedAfter;
          // The two halves of a life exist together or not at all: they
          // are missing only for the last man in the chain, who has no
          // next generation to divide his life at.
          expect(begat == null, after == null,
              reason: '${p.id} (${entry.key}) has half a division');
          if (begat != null && after != null) {
            expect(begat + after, f.lifespan,
                reason: '${p.id} (${entry.key}) does not add up');
            expect(begat, greaterThan(0), reason: p.id);
            expect(after, greaterThan(0), reason: p.id);
          }
        }
      }
    });

    // A life is divided at the birth of the next man only where the text
    // states that age. Joseph ends the Genesis chain, and Moses and
    // Aaron are dated by their own ages rather than by fathering anyone,
    // so those three rows are undivided — and no others may be, because
    // anywhere else a null would mean the parser stopped finding a
    // figure the formula does state.
    test('exactly the three men the text leaves undivided are undivided', () {
      for (final t in ['mt', 'lxx']) {
        final open = [
          for (final p in data.inTradition(t))
            if (p.figures[t]!.begatAt == null) p.id
        ];
        expect(open, ['joseph', 'aaron', 'moses'], reason: t);
      }
    });

    test('every figure carrying a verse carries a real one', () {
      final ref =
          RegExp(r'^(Genesis|Exodus|Numbers|Deuteronomy) \d+:\d+$');
      for (final p in data.patriarchs) {
        for (final f in p.figures.values) {
          for (final e in f.refs.entries) {
            expect(['begatAt', 'livedAfter', 'lifespan'], contains(e.key),
                reason: p.id);
            expect(ref.hasMatch(e.value), isTrue,
                reason: '${p.id} ${e.key} = ${e.value}');
          }
        }
      }
    });

    // Genesis 5 and 11 state the begetting age in a formula, so a
    // missing verse there would mean the parser stopped finding it.
    // Genesis 12-50 does not, which is why the rule is scoped to the
    // lines rather than applied to the whole asset.
    test('the formulaic genealogies cite every begetting age', () {
      for (final p in data.patriarchs) {
        if (p.line == 'abraham' || p.line == 'levi') continue;
        for (final f in p.figures.values) {
          expect(f.refs['begatAt'], isNotNull, reason: p.id);
          expect(f.refs['begatAt'], startsWith('Genesis '), reason: p.id);
        }
      }
    });

    test('generations run forward: each son is born after his father', () {
      for (final t in ['mt', 'lxx']) {
        final people = data.inTradition(t);
        for (var i = 1; i < people.length; i++) {
          final prev = people[i - 1].figures[t]!;
          final cur = people[i].figures[t]!;
          expect(cur.birthAm, greaterThan(prev.birthAm),
              reason: '${people[i].id} is not born after ${people[i - 1].id} '
                  'in $t');
        }
      }
    });

    // The two figures every reference work gives for these genealogies.
    // They are asserted here so that a change to the parser, the source
    // texts or the verse table cannot quietly move the flood.
    test('the flood lands where each text puts it', () {
      final flood = data.epochs.firstWhere((e) => e.id == 'flood');
      expect(flood.years['mt'], 1656);
      expect(flood.years['lxx'], 2242);
    });

    test('Adam fathers Seth at 130 in the Hebrew and 230 in the Greek', () {
      final adam = data.byId('adam')!;
      expect(adam.figures['mt']!.begatAt, 130);
      expect(adam.figures['lxx']!.begatAt, 230);
      // Both texts agree on the total, which is why the difference
      // compounds only through the begetting ages.
      expect(adam.figures['mt']!.lifespan, 930);
      expect(adam.figures['lxx']!.lifespan, 930);
    });

    test('Kainan is in the Septuagint\'s Genesis 11 and not the Hebrew\'s',
        () {
      final kainan = data.byId('kainan2');
      expect(kainan, isNotNull);
      expect(kainan!.figures.containsKey('lxx'), isTrue);
      expect(kainan.figures.containsKey('mt'), isFalse);
      expect(data.inTradition('lxx').length,
          data.inTradition('mt').length + 1);
    });

    // The chart's headline fact, and the reason the page exists.
    test('Methuselah dies in the flood year on the Hebrew figures', () {
      final flood = data.epochs.firstWhere((e) => e.id == 'flood');
      expect(data.byId('methuselah')!.figures['mt']!.deathAm,
          flood.years['mt']);
    });

    // The best-known claim made from these genealogies — that Adam was
    // still alive when Noah's father was born — and it holds only on the
    // Hebrew figures. On the Greek ones Adam has been dead 524 years by
    // then, because each Septuagint begetting age is about a century
    // later and nine of them compound. This is the sharpest reason the
    // chart offers a choice of text instead of picking one, so it is
    // pinned here in both directions.
    test('Adam outlives Lamech\'s birth on the Hebrew figures only', () {
      final adamMt = data.byId('adam')!.figures['mt']!;
      final lamechMt = data.byId('lamech')!.figures['mt']!;
      expect(aliveAt(adamMt.birthAm, adamMt.deathAm, lamechMt.birthAm), isTrue);

      final adamLxx = data.byId('adam')!.figures['lxx']!;
      final lamechLxx = data.byId('lamech')!.figures['lxx']!;
      expect(
          aliveAt(adamLxx.birthAm, adamLxx.deathAm, lamechLxx.birthAm), isFalse,
          reason: 'the Septuagint spaces the generations a century wider');
    });

    // Faithful to the Greek text and easily mistaken for a bug, so the
    // asset must carry the sentence that explains it. If the arithmetic
    // ever stops showing it the note must go too, which is why the
    // generator emits it conditionally.
    test('the Septuagint note about Methuselah matches the numbers', () {
      final flood = data.epochs.firstWhere((e) => e.id == 'flood');
      final death = data.byId('methuselah')!.figures['lxx']!.deathAm;
      final over = death - flood.years['lxx']!;
      final notes = data.notesFor('lxx');
      if (over > 0) {
        expect(notes.map((n) => n.id), contains('methuselah_flood'));
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          final text = notes
              .firstWhere((n) => n.id == 'methuselah_flood')
              .textFor(locale);
          expect(text, contains('$over'), reason: locale);
        }
      } else {
        expect(notes.map((n) => n.id), isNot(contains('methuselah_flood')));
      }
      expect(data.notesFor('mt').map((n) => n.id),
          isNot(contains('methuselah_flood')));
    });

    test('every name and note is in all three locales', () {
      for (final p in data.patriarchs) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(p.names[locale], isNotNull, reason: '${p.id} $locale');
          expect(p.names[locale], isNotEmpty, reason: '${p.id} $locale');
        }
      }
      for (final t in data.traditions) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(t.names[locale], isNotNull, reason: '${t.id} $locale');
          expect(t.longNames[locale], isNotNull, reason: '${t.id} $locale');
        }
      }
    });

    // Every year in this asset is Anno Mundi. Turning AM into BC takes an
    // absolute anchor the text never gives, so no BC year may appear as
    // data — and if one is ever added it has to arrive with the system
    // that produced it named, as `hebrew_kings.json` names Thiele. Prose
    // is exempt: the unit note mentions Ussher's 4004 BC precisely in
    // order to say it is not adopted.
    test('no year in the asset is a BC year', () {
      for (final p in data.patriarchs) {
        for (final f in p.figures.values) {
          expect(f.birthAm, greaterThanOrEqualTo(0), reason: p.id);
          expect(f.deathAm, greaterThan(0), reason: p.id);
        }
      }
      for (final e in data.epochs) {
        for (final y in e.years.values) {
          expect(y, greaterThan(0), reason: e.id);
        }
      }
      for (final t in data.traditions) {
        expect(t.floodAm, greaterThan(0));
        expect(t.endAm, greaterThan(t.floodAm));
      }
      // And the note says which frame these are in, so a reader is never
      // left to assume.
      expect(data.unitNote, contains('Anno Mundi'));
    });

    test('the second witness still agrees', () {
      expect(data.secondWitness, contains('23 of 23'));
      expect(data.sumsChecked, 24);
    });

    test('the chart runs to Moses in both texts', () {
      for (final t in ['mt', 'lxx']) {
        expect(data.inTradition(t).last.id, 'moses', reason: t);
      }
      final joseph = data.byId('joseph')!;
      for (final f in joseph.figures.values) {
        expect(f.lifespan, 110);
        expect(f.refs['lifespan'], 'Genesis 50:26');
        // The Genesis chain ends: these figures do not exist rather than
        // being unknown, and the panel omits their rows on that basis.
        expect(f.begatAt, isNull);
        expect(f.livedAfter, isNull);
      }
    });

    // The one span on this chart assembled from three books, and the
    // only one outside Genesis 5 whose parse a third stated number
    // confirms.
    // Exodus 7:7 gives the two ages before Pharaoh, Numbers 14:33 the
    // forty years, and the lifetimes are stated separately in
    // Deuteronomy 34:7 and Numbers 33:39 — so 80 + 40 == 120 and
    // 83 + 40 == 123 check the parse of all five figures at once.
    test('Moses and Aaron span the wilderness, checked across three books',
        () {
      final exodus = data.epochs.firstWhere((e) => e.id == 'exodus');
      final death = data.epochs.firstWhere((e) => e.id == 'moses_death');
      for (final t in ['mt', 'lxx']) {
        final moses = data.byId('moses')!.figures[t]!;
        final aaron = data.byId('aaron')!.figures[t]!;
        expect(moses.lifespan, 120, reason: t);
        expect(aaron.lifespan, 123, reason: t);
        expect(moses.refs['lifespan'], 'Deuteronomy 34:7', reason: t);
        expect(aaron.refs['lifespan'], 'Numbers 33:39', reason: t);
        expect(moses.checked, isTrue, reason: t);
        expect(aaron.checked, isTrue, reason: t);
        // Both are dated from their age at Exodus 7:7, so the exodus year
        // must fall 80 and 83 years after their births.
        expect(exodus.years[t]! - moses.birthAm, 80, reason: t);
        expect(exodus.years[t]! - aaron.birthAm, 83, reason: t);
        // And the forty years of Numbers 14:33 close both lives.
        expect(death.years[t]! - exodus.years[t]!, 40, reason: t);
        expect(moses.deathAm, death.years[t], reason: t);
      }
    });

    // The two texts state the same 430 years over different ground, and
    // the whole extension past the descent rests on reading each one on
    // its own terms rather than choosing. Pinned in years, because the
    // sentence that describes it could drift and the years cannot.
    test('Exodus 12:40 starts at the descent in the Hebrew and at Haran '
        'in the Greek', () {
      final exodus = data.epochs.firstWhere((e) => e.id == 'exodus');
      final descent = data.epochs.firstWhere((e) => e.id == 'descent');
      final haran = data.epochs.firstWhere((e) => e.id == 'haran');
      expect(exodus.ref, 'Exodus 12:40');
      expect(exodus.years['mt']! - descent.years['mt']!, 430);
      expect(exodus.years['lxx']! - haran.years['lxx']!, 430);
      // The Greek's start is the one year on this axis that had to be
      // supplied rather than read, so its note has to say so.
      final note =
          data.notesFor('lxx').firstWhere((n) => n.id == 'sojourn_430');
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(note.textFor(locale), contains('430'), reason: locale);
      }
      expect(note.textFor('en'), contains('not stated'));
    });

    // Genesis 12-50 states no begetting ages, so Jacob's is derived from
    // four verses: Joseph is 30 in 41:46, seven years of plenty pass in
    // 41:53, five of seven famine years remain in 45:6, and Jacob is 130
    // at the descent in 47:9. The arithmetic is the module's most
    // exposed inference, so it is pinned to the year rather than to the
    // sentence that describes it.
    test('Jacob was 91 when Joseph was born, and the descent checks it', () {
      final descent = data.epochs.firstWhere((e) => e.id == 'descent');
      expect(descent.ref, 'Genesis 47:9');
      for (final t in ['mt', 'lxx']) {
        final jacob = data.byId('jacob')!.figures[t]!;
        final joseph = data.byId('joseph')!.figures[t]!;
        expect(jacob.begatAt, 91, reason: t);
        expect(joseph.birthAm - jacob.birthAm, 91, reason: t);
        // 47:9's 130 and 47:28's 17 years in Egypt against the 147 that
        // same verse states — the only self-check this section offers.
        expect(descent.years[t]! - jacob.birthAm, 130, reason: t);
        expect(jacob.deathAm - descent.years[t]!, 17, reason: t);
        expect(jacob.lifespan, 147, reason: t);
        expect(jacob.checked, isTrue, reason: t);
        expect(jacob.refs['lifespan'], 'Genesis 47:28', reason: t);
        // Joseph is 39 at the descent on both sets of figures.
        expect(descent.years[t]! - joseph.birthAm, 39, reason: t);
      }
    });

    test('Abram leaves Haran at 75 in both texts', () {
      final haran = data.epochs.firstWhere((e) => e.id == 'haran');
      expect(haran.ref, 'Genesis 12:4');
      for (final t in ['mt', 'lxx']) {
        final abraham = data.byId('abraham')!.figures[t]!;
        expect(haran.years[t]! - abraham.birthAm, 75, reason: t);
      }
    });

    // The finding the second section was worth drawing for: the choice
    // of text moves the genealogies and leaves the patriarchs where they
    // are. Computed here rather than quoted, so the sentence the asset
    // ships cannot drift away from the numbers.
    test('the texts differ through Genesis 5 and 11 and agree after it', () {
      var genSame = 0, genBoth = 0, abrSame = 0, abrBoth = 0;
      for (final p in data.patriarchs) {
        final mt = p.figures['mt'];
        final lxx = p.figures['lxx'];
        if (mt == null || lxx == null) continue;
        final same =
            mt.begatAt == lxx.begatAt && mt.lifespan == lxx.lifespan;
        if (p.line == 'abraham') {
          abrBoth++;
          if (same) abrSame++;
        } else if (p.line != 'levi') {
          genBoth++;
          if (same) genSame++;
        }
      }
      expect([genSame, genBoth], [4, 19]);
      expect([abrSame, abrBoth], [4, 4]);
      // Moses and Aaron are outside the comparison because the texts
      // state identical figures for them: the divergence is a feature of
      // the two genealogies, and counting agreement where there was
      // never a difference would flatter it.
      for (final id in ['moses', 'aaron']) {
        final p = data.byId(id)!;
        expect(p.figures['mt']!.lifespan, p.figures['lxx']!.lifespan,
            reason: id);
      }
    });

    // A judgement, and the note is how the reader is told it was made.
    // Genesis 11:26 gives Terah 70 at the begetting of three sons and
    // the chart takes that year for Abram; Acts 7:4 implies a later
    // birth. The note carries the gap and the alternative year, both
    // computed from 11:26, 11:32 and 12:4, so it cannot state a number
    // the chart does not.
    test('the Terah/Abram conflict is disclosed, with its arithmetic', () {
      for (final t in ['mt', 'lxx']) {
        final note = data
            .notesForPerson(t, 'abraham')
            .firstWhere((n) => n.id == 'abram_birth');
        final terah = data.byId('terah')!.figures[t]!;
        final abraham = data.byId('abraham')!.figures[t]!;
        final haran = data.epochs.firstWhere((e) => e.id == 'haran');
        final gap = terah.deathAm - haran.years[t]!;
        final later = abraham.birthAm + gap;
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          final text = note.textFor(locale);
          expect(text, contains('$gap'), reason: '$t $locale');
          expect(text, contains('$later'), reason: '$t $locale');
          expect(text, contains('11:26'), reason: '$t $locale');
          expect(text, contains('11:32'), reason: '$t $locale');
          expect(text, contains('12:4'), reason: '$t $locale');
        }
      }
    });

    test('what the 430 years cover is said on the chart, in both texts', () {
      for (final t in ['mt', 'lxx']) {
        final note =
            data.notesFor(t).firstWhere((n) => n.id == 'sojourn_430');
        // Not about one man, so it stays in the header only.
        expect(note.personId, isNull);
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(note.textFor(locale), contains('12:40'), reason: '$t $locale');
          expect(note.textFor(locale), contains('430'), reason: '$t $locale');
        }
      }
    });

    // Why the chart ends after Moses, said on the chart rather than only
    // in the source: 1 Kings 6:1 states its year as an ordinal that the
    // generator's number-reader cannot read in either language. It carries
    // no person because it is about the chart, not about Moses, and the
    // header prints exactly the notes that carry no person.
    test('why the chart stops is said on the chart, in both texts', () {
      for (final t in ['mt', 'lxx']) {
        final note = data.notesFor(t).firstWhere((n) => n.id == 'chart_end');
        expect(note.personId, isNull);
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(note.textFor(locale), contains('6:1'), reason: '$t $locale');
        }
      }
    });

    // Exodus 6:18 and 6:20 cap the years between the descent and the
    // exodus, and which way that cap falls is the substance of the
    // argument over Exodus 12:40. Recomputed here from the asset's own
    // years so the note cannot outlive the numbers behind it.
    test('the Levite generations are measured against the gap, both ways',
        () {
      final exodus = data.epochs.firstWhere((e) => e.id == 'exodus');
      final descent = data.epochs.firstWhere((e) => e.id == 'descent');
      // The Hebrew puts all 430 after the descent; the Greek 215.
      expect(exodus.years['mt']! - descent.years['mt']!, 430);
      expect(exodus.years['lxx']! - descent.years['lxx']!, 215);
      for (final t in ['mt', 'lxx']) {
        final note = data
            .notesForPerson(t, 'moses')
            .firstWhere((n) => n.id == 'levi_ceiling');
        final gap = exodus.years[t]! - descent.years[t]!;
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(note.textFor(locale), contains('$gap'),
              reason: '$t $locale');
        }
      }
      // 133 + 137 + 80 = 350, which is 80 short of 430; 130 + 132 + 80 =
      // 342, which covers 215 with room. The verdicts are opposite and
      // the notes must not read the same way.
      expect(
          data
              .notesForPerson('mt', 'moses')
              .firstWhere((n) => n.id == 'levi_ceiling')
              .textFor('en'),
          contains('350'));
      expect(
          data
              .notesForPerson('lxx', 'moses')
              .firstWhere((n) => n.id == 'levi_ceiling')
              .textFor('en'),
          contains('342'));
    });

    // The header prints the notes that carry no person and only names
    // the men who carry one, so a note about a man is read by selecting
    // his bar. If he has no bar in that tradition there is nothing to
    // select and the caveat is unreachable — which is why this asserts
    // he is in the tradition, not merely in the file.
    test('a note about a man is reachable from that man', () {
      for (final t in ['mt', 'lxx']) {
        final personal = data.notesFor(t).where((n) => n.personId != null);
        expect(personal, isNotEmpty, reason: t);
        final onChart = data.inTradition(t).map((p) => p.id).toSet();
        for (final n in personal) {
          expect(onChart, contains(n.personId), reason: '${n.id} in $t');
          expect(data.notesForPerson(t, n.personId!).map((e) => e.id),
              contains(n.id));
        }
        // And a man with no note gets none.
        expect(data.notesForPerson(t, 'adam'), isEmpty, reason: t);
      }
    });

    test('every epoch is named in all three locales and cites a verse', () {
      expect(data.epochs.map((e) => e.id).toList(),
          ['flood', 'haran', 'descent', 'exodus', 'moses_death']);
      for (final e in data.epochs) {
        expect(e.ref, isNotNull, reason: e.id);
        expect(e.years.keys.toSet(), {'mt', 'lxx'}, reason: e.id);
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(e.names[locale], isNotNull, reason: '${e.id} $locale');
          expect(e.names[locale], isNotEmpty, reason: '${e.id} $locale');
        }
      }
      // Epochs run in the order the text puts them, in both texts.
      for (final t in ['mt', 'lxx']) {
        final years = [for (final e in data.epochs) e.years[t]!];
        final sorted = [...years]..sort();
        expect(years, sorted, reason: t);
      }
    });

    test('every note is written in all three locales', () {
      for (final n in data.notes) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(n.textFor(locale), isNotEmpty, reason: '${n.id} $locale');
        }
      }
    });
  });
}
