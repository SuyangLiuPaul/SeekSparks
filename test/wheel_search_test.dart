/// Find on the wheel — the pure core, against the real asset.
///
/// The wheel holds 1029 records and draws 64 labels at rest, so the
/// search box is now the only way most of the corpus can be reached at
/// all. That makes a FALSE ABSENCE the defect that matters here: the
/// app telling a reader it does not know something it does know. Every
/// group below is one way a search box produces one.
///
/// The pins that would catch a silent regression, in order of what they
/// cost the reader:
///
///  * THE ROUND TRIP. `parseWheelYears` must accept everything
///    `yearLabel` prints, for all 671 events and all 62 power spans, in
///    all three locales. Nothing enforces that but this test, and the
///    two functions live in different files.
///  * THE BARE WILDCARD reaches 726 + 155 + 82 + 22 + 44 = 1029 records. Not a
///    round number for its own sake — it is the only assertion that
///    fails if a whole KIND stops being searched, which is exactly what
///    a naive "search the events" version would do.
///  * THE INDEX BAR. Every one of the 1029 records, in all three
///    locales, must come back when its own printed title is typed —
///    2,490 searches, and never below second place. This is the only
///    pin here that grows with the corpus instead of with the examples
///    someone remembered to write down.
///  * THE SCRIPTS. `yearLabel` printed Simplified 主后, and the hedge in
///    front of an unsettled date printed Simplified 约, to Traditional
///    readers until 2026-08-26. Both are pinned here by sweeping the
///    whole corpus rather than one example, because one example is what
///    let it ship. The hedge itself moved to `date_hedge.dart` when it
///    turned out to be the same slip in three files;
///    `date_hedge_test.dart` guards the shape of it.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show kMaxYear, yearLabel;
import 'package:seeksparks/utils/date_hedge.dart';
import 'package:seeksparks/utils/wheel_search.dart';

const _locales = ['en', 'zh-Hans', 'zh-Hant'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WheelHistoryData data;
  setUpAll(() async {
    data = await WheelHistoryService.instance.load();
  });

  WheelSearchResult find(String q,
          {String locale = 'en',
          int axisEnd = kMaxYear,
          Set<String> hidden = const {}}) =>
      searchWheel(
        data: data,
        query: q,
        locale: locale,
        axisEnd: axisEnd,
        hiddenStreams: hidden,
      );

  group('the printed year and the read year are the same year', () {
    /// The floor the whole year feature stands on. A reader types back
    /// what the chart showed them; if the parser does not accept it, the
    /// search says "nothing here matches 主後33" about a record that is
    /// on screen.
    test('every event round-trips through both functions, in every locale',
        () {
      expect(data.events, hasLength(726));
      final broken = <String>[];
      for (final e in data.events) {
        for (final locale in _locales) {
          final printed = yearLabel(e.year, locale);
          if (!parseWheelYears(printed).contains(e.year)) {
            broken.add('$locale ${e.year} → "$printed"');
          }
        }
      }
      expect(broken, isEmpty,
          reason: 'the wheel prints a year the search box cannot read back');
    });

    test('every power span round-trips too', () {
      expect(data.powers, hasLength(155));
      final broken = <String>[];
      for (final p in data.powers) {
        for (final y in [p.start, if (p.end != null) p.end!]) {
          for (final locale in _locales) {
            final printed = yearLabel(y, locale);
            if (!parseWheelYears(printed).contains(y)) {
              broken.add('$locale $y → "$printed"');
            }
          }
        }
      }
      expect(broken, isEmpty);
    });

    /// Not a round trip but the same class of defect, and the reason
    /// this file sweeps rather than samples: the Simplified forms were
    /// being shown to Traditional readers on 382 events and 27 powers,
    /// and every single one looked fine on its own.
    test('a Traditional reader is never shown a Simplified era or hedge', () {
      final years = <int>{
        for (final e in data.events) e.year,
        for (final p in data.powers) ...[p.start, if (p.end != null) p.end!],
      };
      expect(years, isNotEmpty);
      for (final y in years) {
        final hant = yearLabel(y, 'zh-Hant');
        expect(hant.contains('主后'), isFalse, reason: '$y printed "$hant"');
        final hans = yearLabel(y, 'zh-Hans');
        expect(hans.contains('主後'), isFalse, reason: '$y printed "$hans"');
      }
      expect(approximatePrefix('zh-Hant'), '約 ');
      expect(approximatePrefix('zh-Hans'), '约 ');
      expect(approximatePrefix('en'), 'c. ');
    });
  });

  group('parseWheelYears', () {
    test('the four forms the wheel itself prints', () {
      expect(parseWheelYears('586 BC'), [-586]);
      expect(parseWheelYears('AD 33'), [33]);
      expect(parseWheelYears('主前586'), [-586]);
      expect(parseWheelYears('主後33'), [33]);
    });

    test('the forms it does not print but a reader may type', () {
      // BibleWorks' own convention on the Timeline command line.
      expect(parseWheelYears('-46'), [-46]);
      expect(parseWheelYears('586 b.c.'), [-586]);
      expect(parseWheelYears('586 BCE'), [-586]);
      expect(parseWheelYears('33 ce'), [33]);
      expect(parseWheelYears('公元前586'), [-586]);
      expect(parseWheelYears('西元前586'), [-586]);
      expect(parseWheelYears('主后33'), [33], reason: 'the other script');
      expect(parseWheelYears('主前586年'), [-586]);
      expect(parseWheelYears('  AD  33  '), [33]);
    });

    /// The one thing the search must not do is decide for the reader.
    /// This chart runs from 4000 BC to the present and holds both eras,
    /// so a bare number is genuinely two questions.
    test('a bare number is read as both eras, earliest first', () {
      expect(parseWheelYears('586'), [-586, 586]);
      expect(parseWheelYears('70'), [-70, 70]);
    });

    test('what is not a year at all', () {
      expect(parseWheelYears(''), isEmpty);
      expect(parseWheelYears('Babylon'), isEmpty);
      expect(parseWheelYears('公元前'), isEmpty, reason: 'an era with no year');
      expect(parseWheelYears('123456'), isEmpty, reason: 'off the axis');
      expect(parseWheelYears('2 Kings 19'), isEmpty);
    });
  });

  group('wheelMatches', () {
    test('a plain needle is an unanchored substring', () {
      expect(wheelMatches('neo-babylonian empire', 'babylon'), isTrue);
      expect(wheelMatches('neo-babylonian empire', 'assyria'), isFalse);
    });

    test('* stands for anything in between, in order', () {
      expect(wheelMatches('sennacherib', 'sennach*rib'), isTrue);
      expect(wheelMatches('sennacherib', 'rib*sennach'), isFalse);
      expect(wheelMatches('sennacherib', 'senn*'), isTrue);
    });

    /// BibleWorks' command line has two wildcards, not one
    /// (`bwh18_CommandLineExamples`), and `?` is the one that matters
    /// for these names: the reader who cannot recall whether we spell it
    /// Nebuchadnezzar or Nebuchadrezzar can ask for both, and `*` cannot
    /// express "exactly one character" — `nebuchad*ar` would also admit
    /// a name with ten letters there.
    test('? stands for exactly one character', () {
      expect(wheelMatches('nebuchadnezzar ii', 'nebuchadne?zar'), isTrue);
      expect(wheelMatches('nebuchadrezzar ii', 'nebuchadre?zar'), isTrue);
      expect(wheelMatches('sennacherib', 'sen?acherib'), isTrue);
      expect(wheelMatches('sennacherib', 'sen?cherib'), isFalse,
          reason: '? is one character, never zero');
      expect(wheelMatches('sennacherib', 'sen??acherib'), isFalse,
          reason: '? is one character, never two');
    });

    test('the two wildcards combine', () {
      expect(wheelMatches('sennacherib besieges jerusalem', 'sen?ach*rus*'),
          isTrue);
    });

    /// The matcher is called once per field per record — 1029 records
    /// across four fields on every keystroke — so a needle that
    /// compiles a pattern must compile it once. This asserts the
    /// behaviour the cache has to preserve, since a cache that returns
    /// the wrong pattern is worse than no cache.
    test('a repeated wildcard needle keeps answering the same way', () {
      for (var i = 0; i < 3; i++) {
        expect(wheelMatches('sennacherib', 'senn*rib'), isTrue);
        expect(wheelMatches('shalmaneser', 'senn*rib'), isFalse);
        expect(wheelMatches('sennacherib', 'sha?maneser'), isFalse);
        expect(wheelMatches('shalmaneser v', 'sha?maneser'), isTrue);
      }
    });

    /// A wildcard character is not a regex, and a reader typing a name
    /// with a dot or a bracket in it must not be handed a crash or a
    /// silent nonsense match.
    test('regex metacharacters in a needle are literal', () {
      expect(wheelMatches('586 b.c. jerusalem falls', 'b.c.'), isTrue);
      expect(wheelMatches('586 bxcx jerusalem falls', 'b.c.'), isFalse);
      expect(wheelMatches('judah (southern kingdom)', '*(southern*'), isTrue);
      expect(wheelMatches('a+b', 'a+*'), isTrue);
    });

    test('an empty needle matches nothing rather than everything', () {
      expect(wheelMatches('anything', ''), isFalse);
    });
  });

  group('every kind of record is reachable', () {
    /// The single assertion that fails if a whole kind stops being
    /// searched. A version that searched only events would still pass
    /// most of this file.
    test('the bare wildcard returns all 1029 records, of all four kinds', () {
      final r = find('*');
      expect(r.hits, hasLength(1029));
      final byKind = {
        for (final k in WheelHitKind.values)
          k: r.hits.where((h) => h.kind == k).length,
      };
      expect(byKind[WheelHitKind.event], data.events.length);
      expect(byKind[WheelHitKind.power], data.powers.length);
      expect(byKind[WheelHitKind.nation], data.nations.length);
      expect(byKind[WheelHitKind.stream], data.streams.length);
    });

    test('no result row is untitled', () {
      for (final h in find('*').hits) {
        expect(h.title.trim(), isNotEmpty,
            reason: '${h.kind.name} ${h.id} would be an unreadable row');
      }
    });

    test('a nation of Genesis 10 is findable by name', () {
      final r = find('javan');
      expect(r.hits.single.kind, WheelHitKind.nation);
      // The text gives the nations no dates and this app invents none.
      expect(r.hits.single.year, isNull);
    });

    test('a band is findable by name', () {
      expect(
          find('babylon').hits.first,
          isA<WheelHit>()
              .having((h) => h.kind, 'kind', WheelHitKind.stream)
              .having((h) => h.via, 'via', WheelHitVia.title));
    });
  });

  group('the reader typed one locale and the record is in another', () {
    /// Every record carries all three locales, so a reader who reaches
    /// for the English name of something the chart is showing them in
    /// Chinese must still find it — and the row has to SHOW what
    /// matched, or it reads as a wrong result.
    test('an English query finds the record a Chinese reader sees', () {
      final r = find('Magna Carta', locale: 'zh-Hans');
      final hit = r.hits.single;
      expect(hit.kind, WheelHitKind.event);
      expect(hit.via, WheelHitVia.otherLocale);
      expect(hit.title, isNot(contains('Magna')),
          reason: 'the row prints the title the reader is shown');
      expect(hit.matched, contains('Magna Carta'),
          reason: 'and says which string it actually hit');
      expect(hit.year, 1215);
    });

    test('a Simplified query finds the record for a Traditional reader', () {
      final r = find('西拿基立', locale: 'zh-Hant');
      expect(r.hits, isNotEmpty);
      expect(r.hits.first.kind, WheelHitKind.event);
    });
  });

  group('the stream filter marks results, it never swallows them', () {
    /// #280 and #319, on a new surface. A filter the reader set for the
    /// CHART must not silently answer a question they asked the SEARCH.
    test('hiding the band a hit sits on changes the flag, not the list', () {
      final open = find('Magna Carta', locale: 'zh-Hans');
      final shut =
          find('Magna Carta', locale: 'zh-Hans', hidden: const {'europe'});
      expect(shut.hits.map((h) => h.id), open.hits.map((h) => h.id),
          reason: 'a hidden band silently narrowed the answer');
      expect(shut.hits.single.streamHidden, isTrue);
      expect(open.hits.single.streamHidden, isFalse);
    });

    test('hiding every band still returns everything, all flagged', () {
      final all = find('*', hidden: {for (final s in data.streams) s.id});
      expect(all.hits, hasLength(1029));
      expect(all.hits.every((h) => h.streamHidden), isTrue);
    });
  });

  group('a year query', () {
    test('an event dated to the year leads, and says so', () {
      final r = find('AD 1215');
      expect(r.years, [1215]);
      expect(r.hits.first.via, WheelHitVia.yearExact);
      expect(r.hits.first.year, 1215);
    });

    test('powers standing in that year follow, spanning it', () {
      final spans =
          find('AD 1215').hits.where((h) => h.via == WheelHitVia.yearSpan);
      expect(spans, isNotEmpty);
      for (final h in spans) {
        expect(h.kind, WheelHitKind.power);
      }
    });

    /// The corpus is 671 events over 6,026 years, so almost any year a
    /// reader types has nothing on it. The neighbours are what makes the
    /// feature useful — but they are a weaker claim, so they are capped,
    /// counted, and last.
    test('near misses are capped, counted and at the very bottom', () {
      final r = find('AD 1215');
      expect(r.nearestShown, kWheelNearestPerYear);
      final near = r.hits.where((h) => h.via == WheelHitVia.yearNear).toList();
      expect(near, hasLength(kWheelNearestPerYear));
      expect(r.hits.sublist(r.hits.length - near.length), near,
          reason: 'a guess was sorted above an answer');
    });

    test('a bare number takes both eras and counts the neighbours of each',
        () {
      final r = find('586');
      expect(r.years, [-586, 586]);
      expect(r.nearestShown, 2 * kWheelNearestPerYear);
    });

    /// The bug this ordering was written to prevent: the near-miss pass
    /// claims records through the same ledger as everything else, so
    /// running it early filed a record's strongest match under its
    /// weakest.
    test('a record that matches on its own text is never filed as nearby', () {
      for (final q in ['1948', '586', '70', 'AD 1215']) {
        final hits = find(q).hits;
        final firstNear =
            hits.indexWhere((h) => h.via == WheelHitVia.yearNear);
        if (firstNear < 0) continue;
        expect(hits.skip(firstNear).every((h) => h.via == WheelHitVia.yearNear),
            isTrue,
            reason: '"$q" sorted a near miss above a real hit');
      }
    });

    /// An ongoing power has no end year in the data on purpose — writing
    /// one in reads as "the state of Israel ended in 2026". Search has
    /// to take the axis end the painter takes, not a sentinel.
    test('a power with no end runs to the axis end, wherever that is', () {
      final ongoing = data.powers.where((p) => p.ongoing).map((p) => p.id);
      expect(ongoing, isNotEmpty);
      final reached = find('AD 2000', axisEnd: 2026)
          .hits
          .where((h) => h.via == WheelHitVia.yearSpan)
          .map((h) => h.id);
      expect(reached, containsAll(ongoing));
      final short = find('AD 2000', axisEnd: 1990)
          .hits
          .where((h) => h.via == WheelHitVia.yearSpan)
          .map((h) => h.id);
      expect(short.toSet().intersection(ongoing.toSet()), isEmpty,
          reason: 'the span was read past the end of the chart');
    });

    /// A number is a year AND a word, and answering only one of those is
    /// how a search box lies.
    test('the year branch and the term branch are unioned', () {
      final r = find('70');
      expect(r.years, isNotEmpty);
      expect(r.hits.any((h) => h.via == WheelHitVia.yearExact), isTrue);
      expect(r.hits.any((h) => h.rank >= 10 && h.via != WheelHitVia.yearNear),
          isTrue,
          reason: 'reading "70" as a year threw away reading it as a word');
    });
  });

  group('a verse finds what was read out of it', () {
    test('a chapter reference reaches the records that cite it', () {
      final r = find('2 Kings 19');
      expect(r.hits, isNotEmpty);
      expect(r.hits.every((h) => h.via == WheelHitVia.reference), isTrue);
      for (final h in r.hits) {
        expect(h.matched, isNotEmpty,
            reason: 'the row cannot say which verse it hit');
      }
    });
  });

  group('ranking and order', () {
    test('an exact title outranks a title that merely contains the query', () {
      final hits = find('babylon').hits;
      expect(hits.first.title.toLowerCase(), 'babylon');
      expect(hits.first.rank, lessThan(hits[1].rank));
    });

    test('the description tier sits below every title tier', () {
      final hits = find('plague').hits;
      final lastTitle =
          hits.lastIndexWhere((h) => h.via == WheelHitVia.title);
      final firstDesc =
          hits.indexWhere((h) => h.via == WheelHitVia.description);
      expect(lastTitle, greaterThanOrEqualTo(0));
      expect(firstDesc, greaterThan(lastTitle));
    });

    test('within a tier the list reads in the chart\'s own direction', () {
      for (final q in ['rome', 'babylon', '*']) {
        final hits = find(q).hits;
        for (var i = 1; i < hits.length; i++) {
          if (hits[i - 1].rank != hits[i].rank) continue;
          final a = hits[i - 1].year, b = hits[i].year;
          if (a == null || b == null) continue;
          expect(a, lessThanOrEqualTo(b), reason: '"$q" is out of order at $i');
        }
      }
    });

    test('a record the text gives no year sorts after the dated ones', () {
      final hits = find('*').hits;
      for (var i = 1; i < hits.length; i++) {
        if (hits[i - 1].rank != hits[i].rank) continue;
        if (hits[i - 1].year == null) {
          expect(hits[i].year, isNull,
              reason: 'an undated record was given a place on the axis');
        }
      }
    });

    test('a record is listed once, however many ways it matches', () {
      for (final q in ['rome', '586', '70', '*']) {
        final keys = find(q).hits.map((h) => '${h.kind.name}:${h.id}').toList();
        expect(keys.toSet(), hasLength(keys.length), reason: '"$q" duplicated');
      }
    });
  });

  group('nothing typed, nothing found', () {
    test('an empty query is empty rather than everything', () {
      for (final q in ['', '   ']) {
        final r = find(q);
        expect(r.isEmpty, isTrue);
        expect(r.years, isEmpty);
        expect(r.nearestShown, 0);
      }
    });

    test('a query nothing matches returns nothing, not an error', () {
      final r = find('qqzzxx');
      expect(r.isEmpty, isTrue);
      expect(r.years, isEmpty);
    });
  });

  /// A NAME THE RECORD HOLDS (#318 phase 21).
  ///
  /// The wheel's false absences, found by asking the engine about all
  /// 37 people the merged records name rather than about a handful:
  /// five returned nothing in all three scripts. Four of them — Aaron,
  /// Amram, Jochebed, Miriam — appear in no title and no description
  /// anywhere on the wheel, so the search box was answering "no
  /// results" about records that name them.
  ///
  /// The fifth, Jeconiah, is the more interesting one and the reason
  /// this group asserts reachability by NAME rather than by count: the
  /// wheel does carry him, spelled Jehoiachin / 约雅斤 on two other
  /// records. He was unreachable only under the name the family tree
  /// prefers. Linking the people fixes a naming mismatch there, not an
  /// absence, and the test says so.
  group('a name the record holds is a name the wheel can find', () {
    test('every person the merged records name is reachable', () {
      final linked = <String, WheelPersonLink>{};
      for (final e in data.events) {
        for (final p in e.people) {
          linked[p.id] = p;
        }
      }
      expect(linked, hasLength(44));
      for (final locale in _locales) {
        for (final p in linked.values) {
          final name = p.nameFor(locale);
          expect(find(name, locale: locale).hits, isNotEmpty,
              reason: '$locale: the wheel names ${p.id} as "$name" '
                  'and cannot find it');
        }
      }
    });

    // The five that returned nothing before, pinned to the record that
    // actually names them so a future merge that finds them on the
    // wrong event still fails.
    test('the five that the wheel could not find land on their own event',
        () {
      const expected = {
        'Aaron': 'bible:plagues',
        'Amram': 'bible:moses_born',
        'Jochebed': 'bible:moses_born',
        'Miriam': 'bible:wilderness_40',
        'Jeconiah': 'bible:judah_falls',
      };
      expected.forEach((name, id) {
        final hits = find(name).hits;
        expect(hits.map((h) => h.id), contains(id), reason: name);
        expect(hits.first.via, WheelHitVia.person,
            reason: '$name is claimed by some other tier first');
      });
    });

    // Chinese readers had the same absence, and the row must print the
    // name in the script the reader is reading — the chip beside it
    // will.
    test('the Chinese names reach the same records', () {
      const expected = {
        '亚伦': 'bible:plagues',
        '约基别': 'bible:moses_born',
        '米利暗': 'bible:wilderness_40',
      };
      expected.forEach((name, id) {
        final hits = find(name, locale: 'zh-Hans').hits;
        expect(hits.map((h) => h.id), contains(id), reason: name);
        final hit = hits.firstWhere((h) => h.id == id);
        expect(hit.via, WheelHitVia.person, reason: name);
        expect(hit.matched, name,
            reason: 'the row printed "${hit.matched}" to a Simplified reader');
      });
    });

    // The person tier was inserted above `reference`, which pushed that
    // tier's rank from 14 to 15. Measured before the change: exactly
    // one record's chip name also matches its own reference —
    // `bible:ruth` ("Ruth" against `Ruth 1-4`) — and its title claims
    // it first, so no reference row reclassifies.
    test('a subject outranks an address, and no address was displaced', () {
      expect(find('Ruth').hits.first.via, WheelHitVia.title);
      final hits = find('Moses').hits;
      final lastDesc =
          hits.lastIndexWhere((h) => h.via == WheelHitVia.description);
      final firstPerson =
          hits.indexWhere((h) => h.via == WheelHitVia.person);
      expect(firstPerson, greaterThan(lastDesc));
      expect(find('2 Kings 19').hits.every((h) => h.via == WheelHitVia.reference),
          isTrue,
          reason: 'the reference tier stopped answering');
    });
  });

  /// THE INDEX BAR.
  ///
  /// The printed World History Chart this wheel is measured against
  /// carries an index of 885 entries — every entity on the sheet,
  /// alphabetised, addressed by section and line. That is the standard
  /// it sets: any name, found in seconds. The groups above prove the
  /// search box can reach a nation, a band, a person, a verse and a
  /// year, each by example. What none of them proves is the whole
  /// claim, which is not "a record is reachable" but EVERY record is,
  /// by the one string the reader has actually seen — the title the
  /// wheel printed — in whichever of the three languages they are
  /// reading it in.
  ///
  /// So this group asks the corpus itself: 1029 records x 3 locales,
  /// 2,490 searches, each typing a record's own displayed title back
  /// at the search box. It is the only assertion in this file that
  /// scales with the corpus rather than with the examples someone
  /// thought to write down, which means a record added years from now
  /// is covered the day it ships.
  ///
  /// REACHABLE IS NOT THE SAME AS FINDABLE, so both are measured. A
  /// record returned at position 400 satisfies "reachable" and fails
  /// the reader completely. The measured worst position is SECOND, in
  /// all three locales, and the test holds that line rather than a
  /// slack one — see the second test for what the seconds are and why
  /// they are not a defect.
  group('the index bar — every record answers to its own name', () {
    /// (id, kind) -> where it came back, for one locale.
    List<MapEntry<String, int>> ownTitleRank(String locale) {
      final all = find('*', locale: locale).hits;
      return [
        for (final h in all)
          MapEntry(
            '$locale ${h.kind.name} ${h.id} "${h.title}"',
            find(h.title, locale: locale)
                .hits
                .indexWhere((x) => x.id == h.id && x.kind == h.kind),
          ),
      ];
    }

    test('all 1029, in all three locales, come back when typed', () {
      for (final locale in _locales) {
        final ranks = ownTitleRank(locale);
        expect(ranks, hasLength(1029),
            reason: 'the sweep itself stopped seeing the corpus');
        final unreachable =
            ranks.where((e) => e.value < 0).map((e) => e.key).toList();
        expect(unreachable, isEmpty,
            reason: 'the wheel prints these and cannot find them again');
      }
    });

    /// Measured, not assumed: no record is ever pushed past second by
    /// typing its own title, in any locale.
    ///
    /// The seconds are all homonyms, and each is a record the reader
    /// genuinely might have meant — Genesis 10 names two Shebas and
    /// two Havilahs, Nahor is both Abraham's brother and his
    /// grandfather, `asshur` the nation shares its name with the band,
    /// and `great_fire_rome` sits under a band whose own title
    /// contains Rome. A homonym above the record is a second right
    /// answer, not a wrong one, which is why the bound is two and not
    /// one.
    test('and it is never buried: first or second, always', () {
      for (final locale in _locales) {
        final buried = ownTitleRank(locale)
            .where((e) => e.value > 1)
            .map((e) => '${e.key} came back at #${e.value + 1}')
            .toList();
        expect(buried, isEmpty);
      }
    });

    /// The guard against a sweep that passes because it is not
    /// actually exercising anything.
    ///
    /// `foldForWheelSearch` lowercases and strips diacritics on BOTH
    /// sides of the comparison; if it ever stopped doing so on the
    /// corpus side, every title with a capital in it would stop
    /// answering to itself. That is all 1029 of them, so the sweep
    /// above is load-bearing for the case fold.
    ///
    /// The diacritic half is thin and says so: exactly three English
    /// titles carry a non-ASCII Latin letter. If a future edit
    /// removes all three the fold stops being tested at all, and this
    /// assertion is what will say so.
    test('the sweep is not passing vacuously', () {
      final titles = find('*').hits.map((h) => h.title).toList();
      expect(titles.where((t) => RegExp(r'[A-Z]').hasMatch(t)), hasLength(1029),
          reason: 'the case fold is exercised by every record, or was');
      final accented = titles
          .where((t) => RegExp(r'[À-ɏ]').hasMatch(t))
          .toList()
        ..sort();
      expect(accented, hasLength(3));
      expect(accented.join(' | '), contains('Córdoba'));
      expect(accented.join(' | '), contains('Encyclopédie'));
      expect(accented.join(' | '), contains('Lumière'));
    });

    /// Both claims above are worth nothing unless they can fail, so
    /// here they are, failing.
    ///
    /// A title of nothing but spaces folds to an empty needle, and
    /// `wheelMatches` answers false to an empty needle by design —
    /// so the record is printed and cannot be found again. Six
    /// records sharing one name bury the sixth at position six. If
    /// either of these ever stops being detected, the two tests above
    /// have quietly become decoration.
    test('a record that really is unfindable is reported as one', () {
      WheelHistoryData withNations(List<WheelNation> ns) => WheelHistoryData(
            streams: const [],
            nations: ns,
            powers: const [],
            ministries: const [],
            events: const [],
            meta: WheelHistoryMeta.empty,
          );
      WheelNation nation(String id, String name) => WheelNation(
            id: id,
            line: 'none',
            father: '',
            generation: 1,
            stream: 'none',
            ref: 'Genesis 10:1',
            names: {'en': name},
            notes: const {},
          );
      List<WheelHit> hitsIn(WheelHistoryData d, String q) => searchWheel(
            data: d,
            query: q,
            locale: 'en',
            axisEnd: kMaxYear,
            hiddenStreams: const {},
          ).hits;

      final blank = withNations([nation('blank', '   ')]);
      expect(hitsIn(blank, '*'), hasLength(1),
          reason: 'the record is on the wheel');
      expect(hitsIn(blank, hitsIn(blank, '*').single.title), isEmpty,
          reason: 'a title that folds away must read as UNREACHABLE');

      final homonyms = withNations([
        for (var i = 0; i < 6; i++) nation('same_$i', 'Aaa'),
      ]);
      final back = hitsIn(homonyms, 'Aaa');
      expect(back, hasLength(6));
      expect(back.indexWhere((h) => h.id == 'same_5'), greaterThan(1),
          reason: 'the "first or second" bound must be able to fail');
    });
  });
}
