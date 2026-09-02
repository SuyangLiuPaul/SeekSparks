// Guards for what a year on a person actually claims (check 32).
//
// `family_tree.json` used to put a Thiele accession year in a field named
// `birthYear` for thirteen kings of Judah, and the UI printed it in the
// same slot it printed Abraham's birth. A reader was told Asa was born in
// 911 BC; 911 is the year he came to the throne. Nothing about the file
// made that visible — the number was well-formed, in range, and wrong in
// kind.
//
// So two things are tested, and they are different in kind. The FORMATTER
// is pure and is tested directly, because every screen that shows a year
// funnels through `displayYears` and the rule is worth stating once. The
// ASSET is a claim about history that no one can check by inspection, so
// it is re-checked against the invariants `tools/audit_dates.py` asserts
// when it writes the file: every record says what its year rests on, a
// reign never renders a birth, and the spans agree with the file that
// cites Thiele.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/utils/reference_parser.dart';

BiblicalPerson _person({
  required String kind,
  int? birth,
  int? death,
  int? reignStart,
  int? reignEnd,
  String yearSystem = 'bc',
  int? lifespan,
}) =>
    BiblicalPerson(
      id: 'x',
      name: 'X',
      yearSystem: yearSystem,
      birthYear: birth,
      deathYear: death,
      lifespan: lifespan,
      summary: '',
      datingKind: kind,
      reignStart: reignStart,
      reignEnd: reignEnd,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('displayYears says which kind of year it is showing', () {
    test('a reign shows the reign and never the birth year', () {
      // Asa: -911 sat in `birthYear` and is his accession.
      final asa = _person(
          kind: 'reign', birth: -911, reignStart: -911, reignEnd: -870);
      expect(asa.displayYears('en'), 'reigned 911 BC – 870 BC');
      expect(asa.displayYears('zh-Hans'), '在位 公元前 911 年 – 公元前 870 年');
      // The point of the whole change: the word "born" is never implied
      // and the number is framed as a reign.
      expect(asa.displayYears('en').contains('reigned'), isTrue);
    });

    test('a birth is shown exactly, with no hedge', () {
      final abraham =
          _person(kind: 'birth', birth: -2166, death: -1991, lifespan: 175);
      expect(abraham.displayYears('en'), '2166 BC – 1991 BC  (175 years)');
      expect(abraham.displayYears('en').startsWith('c.'), isFalse);
    });

    /// "In both scripts" used to mean one string handed to both, and
    /// this assertion said so out loud: it passed `zh-Hant` and expected
    /// 约, which is the Simplified form. The hedge is a different word
    /// in each script; see `test/date_hedge_test.dart`.
    test('an unsourced year is hedged, in both scripts', () {
      final rebekah = _person(kind: 'approximate', birth: -2030, death: -1900);
      expect(rebekah.displayYears('en'), 'c. 2030 BC – 1900 BC');
      expect(rebekah.displayYears('zh-Hans'), '约 公元前 2030 年 – 公元前 1900 年');
      expect(rebekah.displayYears('zh-Hant'), '約 公元前 2030 年 – 公元前 1900 年');
    });

    test('Anno Mundi records are unaffected by the hedge', () {
      final adam = _person(
          kind: 'birth', yearSystem: 'am', birth: 0, death: 930, lifespan: 930);
      expect(adam.displayYears('en'), 'AM 0 – AM 930  (930 years)');
    });

    test('a reign with no recorded end says so rather than inventing one', () {
      final k = _person(kind: 'reign', birth: -931, reignStart: -931);
      expect(k.displayYears('en'), 'acceded 931 BC');
    });

    test('a reign kind with no span falls back rather than showing nothing',
        () {
      // Defensive: if the asset ever carries `reign` without a span, the
      // reader should still see something, not a blank.
      final k = _person(kind: 'reign', birth: -931);
      expect(k.displayYears('en'), isNotEmpty);
    });
  });

  group('family_tree.json — every year says what it rests on', () {
    late List<Map<String, dynamic>> people;
    late Map<String, dynamic> meta;
    late Map<String, Map<String, dynamic>> kings;

    setUpAll(() async {
      final doc = jsonDecode(await rootBundle.loadString(
          'assets/family_tree.json')) as Map<String, dynamic>;
      meta = doc['_meta'] as Map<String, dynamic>;
      people = (doc['people'] as List).cast<Map<String, dynamic>>();
      final hk = jsonDecode(await rootBundle
          .loadString('assets/hebrew_kings.json')) as Map<String, dynamic>;
      kings = {
        for (final k in (hk['kings'] as List).cast<Map<String, dynamic>>())
          k['id'] as String: k,
      };
    });

    test('no record is left without a basis', () {
      const kinds = {'birth', 'reign', 'approximate'};
      const bases = {'scripture', 'scripture+thiele', 'thiele', 'conventional'};
      final missing = people.where((p) => p['dating'] == null).toList();
      expect(missing, isEmpty,
          reason: '${missing.length} people carry a year with no dating');
      for (final p in people) {
        final d = p['dating'] as Map<String, dynamic>;
        expect(kinds, contains(d['kind']), reason: 'id=${p['id']}');
        expect(bases, contains(d['basis']), reason: 'id=${p['id']}');
      }
    });

    test('a birth cites the verses it is derived from', () {
      for (final p in people) {
        final d = p['dating'] as Map<String, dynamic>;
        if (d['kind'] != 'birth') continue;
        expect((d['refs'] as List), isNotEmpty,
            reason: '${p['id']} claims an exact birth with no reference');
      }
    });

    test('a reign carries a span, and it is the one hebrew_kings cites', () {
      var checked = 0;
      for (final p in people) {
        final d = p['dating'] as Map<String, dynamic>;
        if (d['kind'] != 'reign') continue;
        expect(p['reignStart'], isNotNull,
            reason: '${p['id']} is a reign with no reign');
        final id = p['id'] == 'manasseh_king' ? 'manasseh' : p['id'];
        final k = kings[id];
        if (k == null) continue;
        expect(p['reignStart'], k['reignStart'], reason: p['id'] as String);
        expect(p['reignEnd'], k['reignEnd'], reason: p['id'] as String);
        checked++;
      }
      expect(checked, greaterThan(0));
    });

    test('nothing that reached the reader as a birth is an accession year',
        () {
      // The defect in one line: a person whose birthYear equals a reign
      // start in hebrew_kings must not be showing it as a birth.
      final offenders = <String>[];
      for (final p in people) {
        final d = p['dating'] as Map<String, dynamic>;
        if (d['kind'] != 'birth') continue;
        final id = p['id'] == 'manasseh_king' ? 'manasseh' : p['id'];
        final k = kings[id];
        if (k == null) continue;
        for (final s in (k['spans'] as List).cast<Map<String, dynamic>>()) {
          if (p['birthYear'] == s['start']) offenders.add(p['id'] as String);
        }
      }
      expect(offenders, isEmpty);
    });

    test('the legend no longer names a chronology the file does not follow',
        () {
      // The file used to credit Ussher for the patriarchs. Ussher puts
      // Abraham's birth at 1996 BC; this file says 2166, which is the
      // figure the 1 Kings 6:1 chain gives. Naming him was simply wrong.
      final legend = jsonEncode(meta['yearLegend']);
      expect(legend.contains('Ussher'), isFalse);
      final abraham = people.firstWhere((p) => p['id'] == 'abraham');
      expect(abraham['birthYear'], -2166);
      expect((abraham['dating'] as Map)['kind'], 'birth');
    });

    test('the counts in _meta match the records', () {
      final counts =
          (meta['dating'] as Map<String, dynamic>)['counts'] as Map;
      for (final kind in counts.keys) {
        final actual = people
            .where((p) => (p['dating'] as Map)['kind'] == kind)
            .length;
        expect(actual, counts[kind], reason: 'kind=$kind');
      }
    });
  });

  group('bible_timeline.json — an event says whether the text fixes it', () {
    test('every event carries a basis, and its count is honest', () async {
      final doc = jsonDecode(await rootBundle.loadString(
          'assets/bible_timeline.json')) as Map<String, dynamic>;
      final events = (doc['events'] as List).cast<Map<String, dynamic>>();
      expect((doc['_meta'] as Map)['count'], events.length);
      const bases = {'scripture+thiele', 'thiele', 'conventional'};
      for (final e in events) {
        expect(bases, contains(e['basis']), reason: e['id'] as String);
        expect(e['approximate'], e['basis'] == 'conventional',
            reason: e['id'] as String);
      }
    });

    // WHAT THE 85/13 SPLIT ACTUALLY WAS. Thirteen ids typed into
    // tools/audit_dates.py, which never looked at a year. Nine events it
    // called `conventional` — which the page prints as a reconstruction
    // nothing fixes — have years the text's own arithmetic reproduces
    // exactly. The basis is derived now, and these guard the derivation
    // rather than the list it replaced.
    test('a derived event carries the verses it was counted along',
        () async {
      final doc = jsonDecode(await rootBundle.loadString(
          'assets/bible_timeline.json')) as Map<String, dynamic>;
      final events = (doc['events'] as List).cast<Map<String, dynamic>>();
      var derived = 0;
      for (final e in events) {
        final refs = (e['datingRefs'] as List?)?.cast<String>() ?? const [];
        if (e['basis'] != 'scripture+thiele') {
          expect(refs, isEmpty, reason: e['id'] as String);
          continue;
        }
        derived++;
        expect(refs, isNotEmpty, reason: e['id'] as String);
        // Every chain reaches the anchor, and the anchor is one verse.
        expect(refs, contains('1 Kings 6:1'), reason: e['id'] as String);
        for (final r in refs) {
          expect(parseReference(r), isNotNull,
              reason: '${e['id']} cannot parse "$r"');
        }
      }
      expect(derived, 29);
    });

    // The Septuagint reads Exodus 12:40's 430 years as covering Egypt
    // AND Canaan, so everything reached THROUGH that verse sits 215
    // years later. The flag must ride the chain: an event whose chain
    // does not pass through the verse must carry no alternative, or the
    // page offers a Greek year for an event the Greek does not move.
    //
    // AND A CHAIN MAY RUN THROUGH THAT VERSE AND STILL CARRY NONE. When
    // the anchor was carried above Abraham, eleven more events joined
    // the chain, and the chain reaches them THROUGH Exodus 12:40 — but
    // it also runs on through Genesis 11 and Genesis 5, where the Greek
    // states different begetting ages for the same men. Their Greek
    // year is therefore not `+215`; it is a different number for every
    // one of them, and the sentence the page prints beside a Septuagint
    // year explains only the 430. A figure that landed under a sentence
    // which does not describe it would be worse than none, so the
    // pre-Abraham block carries none and this test says which rule each
    // event falls under rather than testing one rule twice.
    test('the Septuagint alternative appears exactly on the chain that '
        'runs through Exodus 12:40 and no further', () async {
      final doc = jsonDecode(await rootBundle.loadString(
          'assets/bible_timeline.json')) as Map<String, dynamic>;
      final events = (doc['events'] as List).cast<Map<String, dynamic>>();
      var shifted = 0;
      var declined = 0;
      for (final e in events) {
        final refs = (e['datingRefs'] as List?)?.cast<String>() ?? const [];
        final viaLxx = refs.contains('Exodus 12:40');
        final viaGenealogy =
            refs.any((r) => r.startsWith('Genesis 5:') ||
                r.startsWith('Genesis 11:'));
        expect(e.containsKey('septuagintYear'), viaLxx && !viaGenealogy,
            reason: e['id'] as String);
        if (!viaLxx) continue;
        if (viaGenealogy) {
          declined++;
          continue;
        }
        shifted++;
        expect(e['septuagintYear'], (e['year'] as int) + 215,
            reason: e['id'] as String);
      }
      expect(shifted, 8);
      expect(declined, 11);
    });

    // Not derived, and each for a reason the text itself supplies.
    // Genesis 37:2's "seventeen" attaches to tending the flock, not to
    // the sale in 37:28; the plagues straddle a year boundary on Exodus
    // 12:2's calendar; Jacob's ages rest on Genesis 30:25/31:41, which
    // do not say Joseph was born at the end of the fourteen years.
    test('events the text does not reach are still reconstructions',
        () async {
      final doc = jsonDecode(await rootBundle.loadString(
          'assets/bible_timeline.json')) as Map<String, dynamic>;
      final events = {
        for (final e in (doc['events'] as List).cast<Map<String, dynamic>>())
          e['id'] as String: e,
      };
      for (final id in ['joseph_sold', 'plagues', 'red_sea', 'burning_bush',
                        'isaac_offered', 'lot_separates', 'jacob_blessing',
                        'jacobs_ladder', 'jacob_marries',
                        'abrahamic_covenant']) {
        expect(events[id]!['basis'], 'conventional', reason: id);
      }
      // abrahamic_covenant is the one the derivation abstained on rather
      // than merely never reached: it ships at -2080, Abram's 86th year,
      // while its own Genesis 17 ref states 99 — which would be -2067.
      // Moving a published date is a decision, so the tool reports it.
      expect(events['abrahamic_covenant']!['year'], -2080);
      expect(events['ishmael_born']!['year'], -2080);
    });

    // THIS TEST HAS BEEN INVERTED, AND THE REASON MATTERS. It used to
    // read "the creation and the flood are not presented as fixed by
    // the text", because -4000 was a rounding of Ussher's 4004 and
    // -2348 was Ussher's flood as printed, leaving 1,652 years where
    // Genesis 5 and 7:6 give 1,656. Neither number was scriptural and
    // the asset was forbidden to say otherwise. The chain now reaches
    // both — Genesis 11:26 up to 11:10, Genesis 7:6, Genesis 5:28 up
    // to 5:3 — so the interval between them IS the 1,656 the text
    // states, and the year they hang from is Thiele's, exactly as for
    // the exodus. What must still be false is that anything here rests
    // on scripture ALONE: `scripture` is not a value this asset may
    // carry, because scripture states no BC year.
    test('the creation and the flood are now derived, and say so',
        () async {
      final doc = jsonDecode(await rootBundle.loadString(
          'assets/bible_timeline.json')) as Map<String, dynamic>;
      final events = {
        for (final e in (doc['events'] as List).cast<Map<String, dynamic>>())
          e['id'] as String: e,
      };
      expect(events['creation']!['approximate'], isFalse);
      expect(events['flood']!['approximate'], isFalse);
      expect(events['creation']!['basis'], 'scripture+thiele');
      expect(events['flood']!['basis'], 'scripture+thiele');
      expect((events['flood']!['year'] as int) -
          (events['creation']!['year'] as int), 1656);
      for (final e in (doc['events'] as List).cast<Map<String, dynamic>>()) {
        expect(e['basis'], isNot('scripture'), reason: e['id'] as String);
      }
      // Eden, the Fall, Cain and Abel and Babel rest on no stated
      // interval and did NOT move into the derived column with them.
      for (final id in ['eden', 'fall', 'cain_abel', 'babel']) {
        expect(events[id]!['basis'], 'conventional', reason: id);
        expect(events[id]!['approximate'], isTrue, reason: id);
      }
      // The exodus and the temple, by contrast, are derived and exact.
      expect(events['exodus']!['basis'], 'scripture+thiele');
      expect(events['exodus']!['year'], -1446);
      expect(events['temple_built']!['basis'], 'scripture+thiele');
    });
  });

  // The half of check 32 that never reached a reader. The asset was
  // stamped and the asset was tested — by the group above, which passed
  // for eight months — while `TimelineEvent.fromJson` silently dropped
  // both fields, so the page printed all 98 years in one voice. An
  // asset-only guard cannot see that: the file was right the whole time.
  group('TimelineEvent — the parse carries the basis to the screen', () {
    TimelineEvent parse(String basis) => TimelineEvent.fromJson({
          'id': 'x',
          'year': -4000,
          'basis': basis,
          'approximate': basis == 'conventional',
        });

    test('fromJson reads basis and approximate', () {
      expect(parse('scripture+thiele').basis, 'scripture+thiele');
      expect(parse('scripture+thiele').approximate, isFalse);
      expect(parse('conventional').basis, 'conventional');
      expect(parse('conventional').approximate, isTrue);
    });

    // The same lesson as `basis` itself, one version later: a field
    // added to the asset so a reader will see it is not disclosed until
    // fromJson reads it.
    test('fromJson reads the dating verses and the Septuagint year', () {
      final e = TimelineEvent.fromJson({
        'id': 'x',
        'year': -2080,
        'basis': 'scripture+thiele',
        'approximate': false,
        'datingRefs': ['Genesis 16:16', '1 Kings 6:1'],
        'septuagintYear': -1865,
      });
      expect(e.datingRefs, ['Genesis 16:16', '1 Kings 6:1']);
      expect(e.septuagintYear, -1865);
      expect(e.displaySeptuagintYear('en'), '1865 BC');
      expect(e.displaySeptuagintYear('zh-Hans'), '公元前 1865 年');
      // The MT year is still the one the page shows in the year column.
      expect(e.displayYear('en'), '2080 BC');
    });

    test('an event with no Septuagint year offers none', () {
      final e = TimelineEvent.fromJson({'id': 'x', 'year': -1446});
      expect(e.septuagintYear, isNull);
      expect(e.displaySeptuagintYear('en'), isNull);
      expect(e.datingRefs, isEmpty);
    });

    // An event with neither field is a reconstruction until something
    // says otherwise, which is the safe direction to fail in.
    test('an unstamped event defaults to the weakest claim', () {
      final e = TimelineEvent.fromJson({'id': 'x', 'year': -4000});
      expect(e.basis, 'conventional');
      expect(e.approximate, isTrue);
      expect(e.displayYear('en'), startsWith('c. '));
    });

    test('the hedge is worded exactly as the family tree words it', () {
      // Same generator, same two surfaces, same vocabulary — a reader
      // moving between them must not have to learn a second one. What
      // that does NOT mean is one Chinese string for both scripts,
      // which is what these two lines used to assert.
      expect(parse('conventional').displayYear('en'), 'c. 4000 BC');
      expect(parse('conventional').displayYear('zh-Hans'), '约 公元前 4000 年');
      expect(parse('conventional').displayYear('zh-Hant'), '約 公元前 4000 年');
      expect(parse('scripture+thiele').displayYear('en'), '4000 BC');
      expect(parse('scripture+thiele').displayYear('zh-Hans'), '公元前 4000 年');
    });

    test('AD years hedge in the same place as BC years', () {
      TimelineEvent ad(int y, String basis) => TimelineEvent.fromJson({
            'id': 'x',
            'year': y,
            'basis': basis,
            'approximate': basis == 'conventional',
          });
      expect(ad(95, 'conventional').displayYear('en'), 'c. AD 95');
      expect(ad(95, 'conventional').displayYear('zh-Hans'), '约 公元 95 年');
      expect(ad(30, 'scripture+thiele').displayYear('en'), 'AD 30');
    });

    test('every event in the asset renders hedged iff it is a reconstruction',
        () async {
      final doc = jsonDecode(await rootBundle.loadString(
          'assets/bible_timeline.json')) as Map<String, dynamic>;
      final events = (doc['events'] as List)
          .cast<Map<String, dynamic>>()
          .map(TimelineEvent.fromJson)
          .toList();
      expect(events, hasLength(105));
      var hedged = 0;
      for (final e in events) {
        final en = e.displayYear('en');
        final zh = e.displayYear('zh-Hans');
        expect(en.startsWith('c. '), e.approximate, reason: '${e.id} en');
        expect(zh.startsWith('约 '), e.approximate, reason: '${e.id} zh');
        if (e.approximate) hedged++;
      }
      // 71 reconstructions, 34 not (29 counted from the anchor along
      // stated intervals, 5 Thiele's outright). The numbers are pinned
      // rather than merely counted so that a generator run which quietly
      // promoted a guess to a derivation has to be argued for here. The
      // block above Abraham moved into the derived column when the
      // chain was carried up through Genesis 11 and Genesis 5; the four
      // records there that rest on no stated interval — Eden, the Fall,
      // Cain and Abel, Babel — did not, and are still hedged.
      expect(hedged, 71);
      expect(events.length - hedged, 34);
    });
  });
}
