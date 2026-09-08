/// The Modern Concordance read backwards, against the REAL shipped
/// asset.
///
/// The task this file guards was described as surfacing five typed
/// relations — R1 synonym, R2 biological relation, R3 geographical
/// relation, R4 antonym, WF word family. They are not in the shipped
/// data: `index.json` declares the vocabulary and nothing assigns it,
/// so the index restates co-membership instead (see the library doc on
/// `concordance_reverse_index.dart`). Two tests here hold that finding
/// still: one pins the asset's actual shape so a rebuild that STARTS
/// carrying types fails loudly instead of shipping them unread, and one
/// pins both derived relations so a refactor cannot quietly collapse
/// them into a single undifferentiated list of neighbours.
///
/// The expectations are hand-verified against the files, not recorded
/// from a run: G946 with G947 and G948 is the example
/// `tools/build_concordance_assets.py` itself uses to explain why
/// StrongGk belongs in the join key, and G25/G26/G27 under "Love:
/// AGAPAO" is checkable by eye in `assets/concordance/t/179.json`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/services/concordance_reverse_index.dart';
import 'package:seeksparks/services/modern_concordance_service.dart';

/// Real topic files, read through dart:io so the pure function can be
/// exercised without a binding or a warmed service.
Map<String, dynamic> topicFile(int id) =>
    jsonDecode(File('assets/concordance/t/$id.json').readAsStringSync())
        as Map<String, dynamic>;

List<String> numbersOf(ConcordanceFiling f, ConcordanceRelation r) => [
      for (final n in f.neighbours)
        if (n.relation == r) n.strongs,
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    ConcordanceReverseIndex.resetForTest();
    ModernConcordanceService.resetForTest();
  });

  group('the pure function, over real topic files', () {
    test('G946 is filed under Abomination beside G947 and G948', () {
      final filings = filingsInTopic(topicFile(1), 'G946');
      expect(filings, hasLength(1));
      final f = filings.single;
      expect(f.topicEn, 'Abomination');
      expect(f.sectionEn, 'Abomination: BDELUGMA');
      expect(numbersOf(f, ConcordanceRelation.sameSense), ['G947', 'G948']);
      expect(numbersOf(f, ConcordanceRelation.sameFamily), isEmpty);
      // Two senses under one section: the sacrilege of Matthew 24:15 and
      // the general "detestable". Both are the word's, and collapsing
      // the section to one line must not lose the second.
      expect(f.headingLabels('en'), hasLength(2));
      expect(f.headingLabels('en').first, 'Abomination = Sacrilege');
      // Six verse links, which is what orders this filing against the
      // others once a word has more than one.
      expect(f.occurrences, 6);
    });

    test('G25 and G26 are read as the same sense, not merely the same '
        'section', () {
      final agape = filingsInTopic(topicFile(179), 'G26').single;
      expect(agape.sectionEn, 'Love: AGAPAO');
      expect(numbersOf(agape, ConcordanceRelation.sameSense), ['G25', 'G27']);
      expect(numbersOf(agape, ConcordanceRelation.sameFamily), isEmpty);
      // The relation is symmetric, and a one-sided index would be a
      // different claim about the data than the one being made.
      final agapao = filingsInTopic(topicFile(179), 'G25').single;
      expect(numbersOf(agapao, ConcordanceRelation.sameSense),
          contains('G26'));
    });

    test('the Chinese labels come back for a Chinese reader, and the '
        'section falls back to English when the source has no Chinese', () {
      final f = filingsInTopic(topicFile(1), 'G946').single;
      expect(f.topicLabel('zh-Hans'), '亵渎');
      expect(f.topicLabel('zh-Hant'), '亵渎',
          reason: 'the source is Simplified only; a 繁體 reader is better '
              'served by that than by an English fallback');
      expect(f.topicLabel('en'), 'Abomination');
    });

    test('rows are grouped by the subsection id and part, not by the '
        'heading text', () {
      // 45 of the 3,886 heading groups in the shipped asset disagree with
      // themselves on capitalisation, and grouping on the label would
      // split those synonyms apart for no reason a reader could see.
      // This fixture is that defect, minimised.
      final f = filingsInTopic(<String, dynamic>{
        'id': 900,
        'en': 'Fixture',
        'zh': '',
        'sections': [
          {
            'id': 1,
            'en': 'Fixture: ONE',
            'zh': '',
            'subsections': [
              {'id': 1, 'part': 1, 'en': 'the Beloved', 'g': 'G25'},
              {'id': 1, 'part': 1, 'en': 'The Beloved', 'g': 'G26'},
              {'id': 2, 'part': 1, 'en': 'Something else', 'g': 'G27'},
            ],
          },
        ],
      }, 'G25').single;
      expect(numbersOf(f, ConcordanceRelation.sameSense), ['G26']);
      expect(numbersOf(f, ConcordanceRelation.sameFamily), ['G27']);
    });

    test('a missing subsection id means zero rather than a group of its '
        'own', () {
      // The builder drops zeros to halve the payload, so 2,752 of the
      // 7,758 rows carry no `id` at all. Reading absence as "unknown"
      // would put every one of them in a private group and delete the
      // sameSense relation for a third of the work.
      final f = filingsInTopic(<String, dynamic>{
        'id': 901,
        'en': 'Fixture',
        'zh': '',
        'sections': [
          {
            'id': 1,
            'en': 'Fixture: TWO',
            'zh': '',
            'subsections': [
              {'part': 1, 'g': 'G1'},
              {'id': 0, 'part': 1, 'g': 'G2'},
            ],
          },
        ],
      }, 'G1').single;
      expect(numbersOf(f, ConcordanceRelation.sameSense), ['G2']);
    });
  });

  group('the service, over the whole shipped asset', () {
    test('G26 is filed under two topics, busiest first, and carries both '
        'relations', () async {
      final filings = await ConcordanceReverseIndex.filings('G26');
      expect(filings, hasLength(2));

      // 109 verse links under Love against 1 under the love feast; the
      // order is the claim that a reader is shown the topic where the
      // word does its work first.
      expect(filings.first.topicEn, 'Love');
      expect(filings.first.sectionEn, 'Love: AGAPAO');
      expect(numbersOf(filings.first, ConcordanceRelation.sameSense),
          ['G25', 'G27']);

      final feast = filings[1];
      expect(feast.topicEn, 'Eat - Food - Drink');
      expect(feast.sectionEn, 'Dinner, supper - Banquet, feast');
      expect(feast.headingLabels('en'),
          ['Love feast - Community meal: AGAPE']);
      expect(numbersOf(feast, ConcordanceRelation.sameSense), ['G4910']);
      // Same section, different heading — the meal words, not AGAPE's
      // own sense. Numeric order, because G1172 after G712 is what a
      // reader who knows the numbering expects.
      expect(numbersOf(feast, ConcordanceRelation.sameFamily),
          ['G709', 'G712', 'G1172', 'G1173']);
    });

    test('G444 ANTHROPOS leads with Man - People - Woman across its three '
        'topics', () async {
      final filings = await ConcordanceReverseIndex.filings('G444');
      expect(filings.map((f) => f.topicEn).toList(),
          ['Man - People - Woman', 'Magic', 'Son - Daughter']);
      final man = filings.first;
      expect(man.sectionEn, 'Man, men - People: ANTHROPOS');
      expect(numbersOf(man, ConcordanceRelation.sameSense),
          ['G441', 'G442', 'G443', 'G5363', 'G5364']);
      // Nine senses under one section, stated once with the neighbours
      // beside them rather than as nine rows of identical chips.
      expect(man.headingLabels('en').length, greaterThan(5));
    });

    test('a number the concordance does not carry comes back empty '
        'instead of throwing', () async {
      // Hebrew is not a gap in the data: the Modern Concordance is a New
      // Testament Greek work, and H430 must cost nothing to ask about.
      expect(await ConcordanceReverseIndex.filings('H430'), isEmpty);
      // G33 is one of the 449 numbers below G5624 the concordance simply
      // does not file. The empty case is an answer, not a failure.
      expect(await ConcordanceReverseIndex.filings('G33'), isEmpty);
      expect(await ConcordanceReverseIndex.filings(''), isEmpty);
    });

    test('the permission credit travels with the data', () async {
      await ConcordanceReverseIndex.filings('G26');
      expect(ConcordanceReverseIndex.attribution, contains("Eagle's View"));
      expect(ConcordanceReverseIndex.attribution,
          contains('Modern Concordance'));
    });
  });

  group('the relations the asset does and does not carry', () {
    test('both derived relations survive the index — neither is silently '
        'collapsed into the other', () async {
      // The cheapest way to break this feature is to stop distinguishing
      // "shares this word's heading" from "shares only the section" and
      // render one flat list of neighbours. Nothing about the layout
      // would look wrong; the only relation this data carries would be
      // gone. So both are asserted over real words that have each.
      final seen = <ConcordanceRelation>{};
      for (final number in const ['G26', 'G444', 'G32', 'G946']) {
        for (final f in await ConcordanceReverseIndex.filings(number)) {
          seen.addAll(f.neighbours.map((n) => n.relation));
        }
      }
      expect(seen, ConcordanceRelation.values.toSet(),
          reason: 'a relation the index used to produce has stopped '
              'appearing; see ConcordanceRelation');
    });

    test('the shipped asset still assigns none of its five word types, so '
        'there is still none to surface', () {
      // index.json declares R1 synonym, R2 biological relation, R3
      // geographical relation, R4 antonym and WF word family — and
      // assigns them to nothing. This test is the tripwire for that
      // changing: if a rebuild of assets/concordance/ starts carrying a
      // type per word or per row, the reverse index must carry it too,
      // and this failing is how anyone finds out.
      final index =
          jsonDecode(File('assets/concordance/index.json').readAsStringSync())
              as Map<String, dynamic>;
      expect((index['wordTypes'] as Map).keys.map((k) => '$k').toSet(),
          {'R1', 'R2', 'R3', 'R4', 'WF'});

      final greek =
          jsonDecode(File('assets/concordance/greek.json').readAsStringSync())
              as Map<String, dynamic>;
      final assigned = {for (final v in greek.values) '${(v as List)[1]}'};
      expect(assigned, {'RX'},
          reason: 'greek.json now assigns a real word type — carry it '
              'through ConcordanceReverseIndex instead of dropping it');

      // And nothing under t/ carries one either. Pinning the whole key
      // set rather than looking for a name, because the name a future
      // build would use is not knowable from here.
      final keys = <String>{};
      for (final f
          in Directory('assets/concordance/t').listSync().whereType<File>()) {
        final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        for (final s in j['sections'] as List) {
          for (final row in (s as Map)['subsections'] as List) {
            keys.addAll((row as Map).keys.map((k) => '$k'));
          }
        }
      }
      expect(keys, {'id', 'part', 'en', 'zh', 'g', 'refs', 'stats'},
          reason: 'a subsection row grew or lost a field — if it is a '
              'relation type, ConcordanceReverseIndex must stop deriving '
              'and start reading it');
    });

    test('the source files 33 rows under two topics at once, and no more '
        'than that', () {
      // A DEFECT this feature makes visible rather than one it causes:
      // topic 181 "Magic" carries, verbatim, most of topic 182 "Man -
      // People - Woman" — which is why a reader on G444 is told the
      // concordance also files it under Magic. It is 21 of the 33
      // duplicated rows in the whole work, and it is upstream of this
      // repo's assets. Filtering it here would be inventing an editorial
      // judgement; a ceiling that cannot rise is the honest instrument
      // until the import is revisited.
      final byRow = <String, Set<int>>{};
      for (final f
          in Directory('assets/concordance/t').listSync().whereType<File>()) {
        final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        for (final s in j['sections'] as List) {
          for (final row in (s as Map)['subsections'] as List) {
            final r = row as Map;
            final key = jsonEncode(
                [r['id'] ?? 0, r['part'], r['g'], r['en'], r['refs']]);
            (byRow[key] ??= <int>{}).add(j['id'] as int);
          }
        }
      }
      final shared = byRow.values.where((t) => t.length > 1).length;
      expect(shared, lessThanOrEqualTo(33),
          reason: 'more rows are now filed under two topics at once than '
              'when this was measured');
    });
  });
}
