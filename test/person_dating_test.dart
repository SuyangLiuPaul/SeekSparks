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

    test('an unsourced year is hedged, in both scripts', () {
      final rebekah = _person(kind: 'approximate', birth: -2030, death: -1900);
      expect(rebekah.displayYears('en'), 'c. 2030 BC – 1900 BC');
      expect(rebekah.displayYears('zh-Hant'), '约 公元前 2030 年 – 公元前 1900 年');
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
      const bases = {'scripture', 'thiele', 'conventional'};
      for (final e in events) {
        expect(bases, contains(e['basis']), reason: e['id'] as String);
        expect(e['approximate'], e['basis'] == 'conventional',
            reason: e['id'] as String);
      }
    });

    test('the creation and the flood are not presented as fixed by the text',
        () async {
      // Genesis's own chain puts 1656 years between them; the file has
      // 1652, because -4000 is a rounding of Ussher's 4004 while -2348 is
      // Ussher's flood taken as printed. Neither is scriptural, and the
      // asset must not say otherwise.
      final doc = jsonDecode(await rootBundle.loadString(
          'assets/bible_timeline.json')) as Map<String, dynamic>;
      final events = {
        for (final e in (doc['events'] as List).cast<Map<String, dynamic>>())
          e['id'] as String: e,
      };
      expect(events['creation']!['approximate'], isTrue);
      expect(events['flood']!['approximate'], isTrue);
      // The exodus and the temple, by contrast, are derived and exact.
      expect(events['exodus']!['basis'], 'scripture');
      expect(events['exodus']!['year'], -1446);
      expect(events['temple_built']!['basis'], 'scripture');
    });
  });
}
