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
          expect(f.begatAt + f.livedAfter, f.lifespan,
              reason: '${p.id} (${entry.key}) does not add up');
          expect(f.deathAm - f.birthAm, f.lifespan,
              reason: '${p.id} (${entry.key}) span disagrees with lifespan');
          expect(f.begatAt, greaterThan(0), reason: p.id);
        }
      }
    });

    test('every stated figure carries the verse it was read from', () {
      for (final p in data.patriarchs) {
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
      expect(data.notesFor('mt'), isEmpty);
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
      expect(data.secondWitness, contains('14 of 14'));
      expect(data.sumsChecked, 18);
    });
  });
}
