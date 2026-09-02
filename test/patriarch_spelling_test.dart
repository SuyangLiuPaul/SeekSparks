/// One man, one spelling — and the older spelling still finds him.
///
/// THE DEFECT. The wheel drew a birth spoke labelled "Birth of Kenan",
/// out of `bible_timeline.json`, immediately beside a lifespan arc
/// labelled "Cainan", out of `chronology.json`. The same man, twice, in
/// two spellings, touching on screen. The owner's ruling was the modern
/// form — 现代的这样看得懂 — so `chronology.json` and the table of
/// nations now read Enosh, Kenan, Mahalalel and Shelah like every other
/// asset here.
///
/// WHY THIS FILE EXISTS RATHER THAN A FIND-AND-REPLACE. Two things
/// could go wrong afterwards and neither shows up in `flutter analyze`:
///
///   1. THE FIVE ASSETS DRIFTING APART AGAIN. `chronology.json`,
///      `family_tree.json`, `bible_timeline.json` and
///      `wheel_history.json` each print a name for these men, and they
///      are joined by year rather than by id — the ids still disagree
///      (`cainan` vs `kenan`) and unifying them was deliberately left
///      alone. Nothing but this file compares the STRINGS a reader
///      sees. Group 1 does it record by record.
///
///   2. THE KJV READER LOSING HIM. This app ships the KJV and
///      `kjvs.json`. A reader with Genesis 5:9 open sees "Cainan", and
///      that is the only spelling they have ever had; a search box that
///      answers "nothing" is telling them the app has never heard of a
///      man it is drawing on screen. That is a worse bug than the one
///      being fixed, and it is invisible unless something asks. Group 3
///      asks, through the app's real search functions.
///
/// NOTHING HERE IS ASSERTED FROM MEMORY. Every spelling this file
/// mentions is first proved to be what a shipped edition actually reads
/// at the verse the record itself cites (group 2), so a wrong expected
/// value in the table below fails rather than freezing an invention.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart' show kMaxYear;
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/utils/wheel_search.dart';

/// The four men, and the two forms each answers to.
///
/// [chronId] and [treeId] differ because the ids were never unified —
/// `chronology.json` keyed itself on the Authorised Version's spelling
/// and `family_tree.json` on the modern one, and both are join keys in
/// shipped code. Naming both here is what lets this file compare the
/// records rather than assume a shared key it does not have.
class _Man {
  const _Man({
    required this.chronId,
    required this.treeId,
    required this.timelineId,
    required this.modern,
    required this.kjv,
    required this.zhHans,
    required this.zhHant,
    required this.witness,
  });

  final String chronId;
  final String treeId;
  final String timelineId;
  final String modern;
  final String kjv;
  final String zhHans;
  final String zhHant;

  /// A verse every one of the records for this man cites, and where
  /// both spellings are read from in group 2.
  final String witness;
}

const _men = <_Man>[
  _Man(
    chronId: 'enos',
    treeId: 'enosh',
    timelineId: 'enosh_born',
    modern: 'Enosh',
    kjv: 'Enos',
    zhHans: '以挪士',
    zhHant: '以挪士',
    witness: 'Genesis 5:6',
  ),
  _Man(
    chronId: 'cainan',
    treeId: 'kenan',
    timelineId: 'kenan_born',
    modern: 'Kenan',
    kjv: 'Cainan',
    zhHans: '该南',
    zhHant: '該南',
    witness: 'Genesis 5:9',
  ),
  _Man(
    chronId: 'mahalaleel',
    treeId: 'mahalalel',
    timelineId: 'mahalalel_born',
    modern: 'Mahalalel',
    kjv: 'Mahalaleel',
    zhHans: '玛勒列',
    zhHant: '瑪勒列',
    witness: 'Genesis 5:12',
  ),
  _Man(
    chronId: 'salah',
    treeId: 'shelah',
    timelineId: 'shelah_born',
    modern: 'Shelah',
    kjv: 'Salah',
    zhHans: '沙拉',
    zhHant: '沙拉',
    // The sharpest of the four, and the only one that is also a band on
    // the wheel: this is the verse the `salah` nation cites, and the
    // KJV reads "Salah" in it while the BSB, NASB and LEB read
    // "Shelah".
    witness: 'Genesis 10:24',
  ),
];

/// The editions the app ships that group 2 will accept as a witness.
const _modernEditions = <String>['bsb', 'nasb', 'leb'];
const _kjvEditions = <String>['kjv', 'kjvs'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> treeRaw;
  late Map<String, dynamic> timelineRaw;
  late Map<String, dynamic> chronRaw;

  late ChronologyData chron;
  late WheelHistoryData wheel;
  late int creation;

  setUpAll(() async {
    treeRaw = json.decode(File('assets/family_tree.json').readAsStringSync())
        as Map<String, dynamic>;
    timelineRaw =
        json.decode(File('assets/bible_timeline.json').readAsStringSync())
            as Map<String, dynamic>;
    chronRaw = json.decode(File('assets/chronology.json').readAsStringSync())
        as Map<String, dynamic>;
    // The app's own load path, so what the groups below read is what a
    // page would read.
    wheel = await WheelHistoryService.instance.load();
    chron = await ChronologyService.instance.load();
    await FamilyTreeService.instance.loadAll();
    creation = TimelineService.instance.meta.creation!.year;
  });

  Map<String, dynamic> chronRecord(String id) =>
      (chronRaw['patriarchs'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['id'] == id);

  Map<String, dynamic> treeRecord(String id) => (treeRaw['people'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['id'] == id);

  Map<String, dynamic> timelineRecord(String id) =>
      (timelineRaw['events'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['id'] == id);

  // ── 1. one spelling per man, on every surface a reader sees ────────

  group('one man, one spelling', () {
    test('there are four men to check and each is in all four assets', () {
      // The vacuity guard. A `firstWhere` that stopped finding anything
      // would throw here rather than in a group that had quietly
      // narrowed to nothing.
      expect(_men, hasLength(4));
      for (final m in _men) {
        expect(chronRecord(m.chronId), isNotNull, reason: m.chronId);
        expect(treeRecord(m.treeId), isNotNull, reason: m.treeId);
        expect(timelineRecord(m.timelineId), isNotNull, reason: m.timelineId);
      }
    });

    test('the chronology chart prints the modern name', () {
      for (final m in _men) {
        final name = (chronRecord(m.chronId)['name'] as Map)
            .cast<String, dynamic>();
        expect(name['en'], m.modern, reason: m.chronId);
        expect(name['zh-Hans'], m.zhHans, reason: m.chronId);
        expect(name['zh-Hant'], m.zhHant, reason: m.chronId);
      }
    });

    test('the family tree prints the same name', () {
      for (final m in _men) {
        final p = treeRecord(m.treeId);
        expect(p['name'], m.modern, reason: m.treeId);
        expect(p['nameZhHans'], m.zhHans, reason: m.treeId);
        expect(p['nameZhHant'], m.zhHant, reason: m.treeId);
      }
    });

    test('the birth spoke on the wheel prints the same name', () {
      for (final m in _men) {
        final e = timelineRecord(m.timelineId);
        expect(e['titleEn'], contains(m.modern), reason: m.timelineId);
        // "Enos" IS a substring of "Enosh", so the absence can only be
        // asserted for the three where the two forms are genuinely
        // different strings. Asserting it for Enosh would be asserting
        // something about spelling that is really about substrings.
        if (!m.modern.contains(m.kjv)) {
          expect(e['titleEn'], isNot(contains(m.kjv)), reason: m.timelineId);
        }
        expect(e['titleZhHans'], contains(m.zhHans), reason: m.timelineId);
        expect(e['titleZhHant'], contains(m.zhHant), reason: m.timelineId);
      }
    });

    /// THE ONE THE OWNER ACTUALLY SAW. The spoke and the arc are drawn
    /// on the same wheel, inches apart, and until this change they
    /// disagreed. Asserted against the loaded models rather than the
    /// files, because a field lost at a constructor call is exactly as
    /// wrong as a field lost in the asset — and this repository has
    /// shipped that three times.
    test('the arc and the spoke agree, as the wheel loads them', () {
      final byId = {for (final p in chron.patriarchs) p.id: p};
      final spokes = {
        for (final e in wheel.events) e.id: e,
      };
      for (final m in _men) {
        final arc = byId[m.chronId];
        expect(arc, isNotNull, reason: m.chronId);
        final spoke = spokes['$kBibleEventIdPrefix${m.timelineId}'];
        expect(spoke, isNotNull,
            reason: '${m.timelineId} did not survive the merge');
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(spoke!.titleFor(locale), contains(arc!.nameFor(locale)),
              reason: 'the $locale spoke and arc disagree for ${m.chronId}');
        }
      }
    });

    /// The band the wheel draws for Shelah among the nations of Genesis
    /// 10 — the record whose own citation reads "Salah" in the KJV, and
    /// the reason `nameKjv` exists at all.
    test('the table of nations agrees too', () {
      final band = wheel.nations.firstWhere((n) => n.id == 'salah');
      expect(band.nameFor('en'), 'Shelah');
      expect(band.nameFor('zh-Hans'), '沙拉');
      expect(band.nameKjv, 'Salah');
      // The tension is held in prose rather than left for the reader to
      // reconcile: the note names the verse and says what each edition
      // reads in it.
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(band.noteFor(locale), isNotEmpty, reason: locale);
        expect(band.noteFor(locale), contains('Salah'), reason: locale);
        expect(band.noteFor(locale), contains('Shelah'), reason: locale);
      }
    });

    /// The four are the whole of it. If a fifth divergence appears —
    /// someone modernises another name in one asset and not the others
    /// — this fails, and that is the point: the sweep is the guard, not
    /// the four examples.
    test('no other patriarch is spelled two ways across the assets', () {
      final treeNames = {
        for (final p in (treeRaw['people'] as List).cast<Map<String, dynamic>>())
          p['id'] as String: p['name'] as String,
      };
      // The chart's ids are the AV's and the tree's are the modern
      // ones, so the join is written out. Never guessed from the
      // spelling: the tree holds both `nahor_elder` (Terah's father,
      // who is on the chart) and `nahor_younger` (Abram's brother, who
      // is not), and a prefix match would compare the wrong man.
      const alias = <String, String>{
        'enos': 'enosh',
        'cainan': 'kenan',
        'mahalaleel': 'mahalalel',
        'salah': 'shelah',
        'nahor': 'nahor_elder',
      };
      final disagree = <String>[];
      var compared = 0;
      for (final p in chron.patriarchs) {
        final treeName = treeNames[alias[p.id] ?? p.id];
        if (treeName == null) continue; // not in the tree; nothing to compare
        compared++;
        // The tree tags two men of one name — "Nahor (the elder)" — and
        // the tag is a disambiguator, not a spelling.
        final head =
            treeName.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
        if (head != p.nameFor('en')) {
          disagree.add('${p.id}: chart "${p.nameFor('en')}" vs tree "$head"');
        }
      }
      // The sweep really swept. A join that silently stopped resolving
      // — which is the exact defect the alias table above was written
      // to fix in `build_chronology.py` — would leave this at zero and
      // report agreement about nothing.
      expect(compared, greaterThanOrEqualTo(20));
      expect(disagree, isEmpty,
          reason: 'two assets print two spellings of one man\n'
              '${disagree.join('\n')}');
    });
  });

  // ── 2. neither spelling is invented ────────────────────────────────

  group('both spellings are read off the shipped text', () {
    late Map<String, Map<String, String>> text; // edition -> "Book|c|v"

    setUpAll(() {
      text = <String, Map<String, String>>{};
      for (final ed in [..._modernEditions, ..._kjvEditions]) {
        final rows = <String, String>{};
        for (final r
            in json.decode(File('assets/$ed.json').readAsStringSync())
                as List) {
          final row = r as Map<String, dynamic>;
          // Psalm superscriptions carry `title` where a verse number
          // belongs. Not verses, and nothing here cites one.
          final v = int.tryParse('${row['verse']}');
          if (v == null) continue;
          rows['${row['book']}|${int.parse('${row['chapter']}')}|$v'] =
              row['text'] as String;
        }
        text[ed] = rows;
      }
    });

    String verse(String edition, String ref) {
      final m = RegExp(r'^(.+) (\d+):(\d+)$').firstMatch(ref)!;
      return text[edition]!['${m.group(1)}|${m.group(2)}|${m.group(3)}'] ?? '';
    }

    test('the fixture really loaded five different English Bibles', () {
      for (final ed in [..._modernEditions, ..._kjvEditions]) {
        expect(text[ed], isNotEmpty, reason: ed);
        expect(verse(ed, 'Genesis 10:24'), isNotEmpty, reason: ed);
      }
      // And they are not the same file five times, which is the only
      // way the two assertions below could both pass vacuously.
      expect(verse('kjv', 'Genesis 10:24'),
          isNot(verse('bsb', 'Genesis 10:24')));
    });

    test('the modern spelling is what the modern versions read', () {
      final missing = <String>[];
      for (final m in _men) {
        for (final ed in _modernEditions) {
          if (!verse(ed, m.witness).contains(m.modern)) {
            missing.add('$ed ${m.witness} does not read "${m.modern}"');
          }
        }
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    });

    test('the KJV spelling is what the KJV reads', () {
      final missing = <String>[];
      for (final m in _men) {
        for (final ed in _kjvEditions) {
          if (!verse(ed, m.witness).contains(m.kjv)) {
            missing.add('$ed ${m.witness} does not read "${m.kjv}"');
          }
        }
        // And the modern form really is absent there — otherwise there
        // would be no divergence to carry and this whole mechanism
        // would be dead weight.
        expect(verse('kjv', m.witness), isNot(contains(m.modern)),
            reason: m.chronId);
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    });

    test('every asset that carries a KJV form carries the right one', () {
      for (final m in _men) {
        expect(chronRecord(m.chronId)['nameKjv'], m.kjv, reason: m.chronId);
        expect(treeRecord(m.treeId)['nameKjv'], m.kjv, reason: m.treeId);
      }
      // And through the models, which is what the app actually reads.
      final byId = {for (final p in chron.patriarchs) p.id: p};
      for (final m in _men) {
        expect(byId[m.chronId]!.nameKjv, m.kjv, reason: m.chronId);
        expect(FamilyTreeService.instance.byId(m.treeId)!.nameKjv, m.kjv,
            reason: m.treeId);
      }
    });
  });

  // ── 3. the KJV reader still finds him ──────────────────────────────

  group('the spelling the app no longer prints still finds the man', () {
    WheelSearchResult find(String q, {String locale = 'en'}) => searchWheel(
          data: wheel,
          query: q,
          locale: locale,
          axisEnd: kMaxYear,
          patriarchs: chron.patriarchs,
          creationYear: creation,
        );

    test('typing the KJV spelling reaches his lifespan arc', () {
      for (final m in _men) {
        final r = find(m.kjv);
        expect(
          r.hits.any(
              (h) => h.kind == WheelHitKind.patriarch && h.id == m.chronId),
          isTrue,
          reason: 'the wheel draws ${m.modern} and cannot be asked for '
              '"${m.kjv}", which is the only spelling a KJV reader has',
        );
      }
    });

    test('and it reaches him in Chinese too, where nothing changed', () {
      for (final m in _men) {
        final r = find(m.zhHans, locale: 'zh-Hans');
        expect(
          r.hits.any(
              (h) => h.kind == WheelHitKind.patriarch && h.id == m.chronId),
          isTrue,
          reason: m.chronId,
        );
      }
    });

    /// The row has to SAY why it is in the list. "Cainan" does not
    /// appear in "Kenan", so a hit with no reason printed beside it
    /// reads as a wrong result — which is how a correct answer gets
    /// mistaken for a bug.
    test('the row says which edition spells him that way', () {
      final hit = find('Cainan')
          .hits
          .firstWhere((h) => h.kind == WheelHitKind.patriarch);
      expect(hit.via, WheelHitVia.otherSpelling);
      expect(hit.matched, 'Cainan');
      expect(hit.title, 'Kenan');
    });

    test('the KJV spelling reaches the table-of-nations band as well', () {
      final r = find('Salah');
      expect(
        r.hits.any((h) => h.kind == WheelHitKind.nation && h.id == 'salah'),
        isTrue,
      );
      // And it is claimed as a NAME, above the prose — the note also
      // contains the word, and a hit filed under "in the description"
      // would rank the right record below every record whose title
      // matched.
      final band =
          r.hits.firstWhere((h) => h.kind == WheelHitKind.nation);
      expect(band.via, WheelHitVia.otherSpelling);
    });

    /// The modern spelling was always going to work; asserting it is
    /// what proves the alias tier did not shadow the real one.
    test('the modern spelling still ranks above the KJV one', () {
      for (final m in _men) {
        final modern = find(m.modern)
            .hits
            .firstWhere((h) => h.id == m.chronId && h.kind == WheelHitKind.patriarch);
        final old = find(m.kjv)
            .hits
            .firstWhere((h) => h.id == m.chronId && h.kind == WheelHitKind.patriarch);
        expect(modern.rank, lessThanOrEqualTo(old.rank), reason: m.chronId);
      }
    });

    /// The person chips the wheel prints on a narrative event, and the
    /// same haystack the timeline page searches. Both read
    /// `WheelPersonLink.allNames` / `BiblicalPerson.nameKjv`, so a link
    /// that lost the field would fail here rather than on screen.
    test('the person links on the birth events answer to it too', () {
      for (final m in _men) {
        final e = wheel.events
            .firstWhere((e) => e.id == '$kBibleEventIdPrefix${m.timelineId}');
        expect(e.people, isNotEmpty, reason: m.timelineId);
        final link = e.people.firstWhere((p) => p.id == m.treeId);
        expect(link.nameKjv, m.kjv, reason: m.treeId);
        expect(link.allNames, contains(m.kjv), reason: m.treeId);
        expect(link.nameFor('en'), m.modern, reason: m.treeId);
      }
    });

    /// The family tree's own search runs over `p.name`, the two Chinese
    /// names and `p.nameKjv`. The page's filter is private, so this
    /// asserts the field the filter reads — the one thing that can go
    /// missing — record by record.
    test('the family tree record carries the spelling its search needs', () {
      for (final m in _men) {
        final p = FamilyTreeService.instance.byId(m.treeId)!;
        expect(
          [p.name, p.nameZhHans, p.nameZhHant, p.nameKjv]
              .map((s) => (s ?? '').toLowerCase()),
          contains(m.kjv.toLowerCase()),
          reason: '"${m.kjv}" typed into the family tree would find nobody',
        );
      }
    });
  });
}
