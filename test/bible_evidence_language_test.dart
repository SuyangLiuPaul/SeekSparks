/// What the Biblical Evidence Archive says, in the reader's own script.
///
/// `assets/bible_evidence.json` was migrated from a standalone
/// Vite/React/TS project and arrived damaged in three ways, all of them
/// visible on the evidence detail page. `tools/repair_evidence_archive.py`
/// fixed them; these tests are what stop a re-import from undoing that.
///
/// The archive is refreshed from yswords-data at runtime, so a future
/// upstream regeneration can put every one of these back.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/bible_evidence.dart';

void main() {
  late Map<String, dynamic> raw;
  late List<BibleEvidence> entries;
  late String everything;

  setUpAll(() {
    raw = jsonDecode(File('assets/bible_evidence.json').readAsStringSync())
        as Map<String, dynamic>;
    entries = (raw['evidences'] as List)
        .map((e) => BibleEvidence.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    everything = File('assets/bible_evidence.json').readAsStringSync();
  });

  group('mojibake — UTF-8 read back as Latin-1', () {
    // A C1 control is unassigned in every legitimate string, so its
    // presence is proof, not a heuristic. 152 strings carried one.
    final c1 = RegExp('[\u0080-\u009f]');

    test('no string in the asset carries a C1 control', () {
      final bad = <String>[];
      void walk(dynamic node) {
        if (node is String) {
          if (c1.hasMatch(node)) bad.add(node);
        } else if (node is List) {
          node.forEach(walk);
        } else if (node is Map) {
          node.values.forEach(walk);
        }
      }

      walk(raw);
      expect(bad, isEmpty, reason: '${bad.length} strings still mojibake');
    });

    test('the fields the detail page prints as fact read correctly', () {
      final dan = entries.firstWhere((e) => e.id == 'tel_dan_stele');
      expect(dan.timeline, '9th Century BCE');
      final dss = entries.firstWhere((e) => e.id == 'dead_sea_scrolls');
      expect(dss.discoveryDate, '1946–1956');
      expect(dss.timeline, '3rd Century BCE – 1st Century CE');
      // Scholars' names and page ranges — the archive's own sourcing.
      expect(everything, contains('André'));
      expect(everything, isNot(contains('AndrÃ©')));
      expect(dan.academicSources.first, contains('81–98'));
    });
  });

  group('the Chinese has to mean what the English means', () {
    test('Tel Dan is the city of Dan, not the prophet Daniel', () {
      final dan = entries.firstWhere((e) => e.id == 'tel_dan_stele');
      expect(dan.localizedTitle('zh-Hans'), '但丘石碑');
      expect(dan.localizedTitle('zh-Hant'), '但丘石碑');
      expect(everything, isNot(contains('但以理石碑')));
    });

    test('an ossuary holds bones; 骨灰 would mean they were cremated', () {
      // Second Temple Jews did not cremate, and these records say so
      // themselves — 十二具藏骨罐（石制藏骨匣）.
      expect(everything, isNot(contains('骨灰罐')));
      expect(everything, isNot(contains('骨灰盒')));
      final caiaphas = entries.firstWhere((e) => e.id == 'caiaphas_ossuary');
      expect(caiaphas.localizedTitle('zh-Hant'), '該亞法藏骨罐');
    });
  });

  group('zh-Hant is Traditional, not Simplified wearing its label', () {
    test('no record serves the Simplified string in the Hant slot', () {
      // 209 of 225 records used to. Short titles that are identical in
      // both scripts (死海古卷) are legitimate, so the test asks whether
      // the string contains a character that only Simplified uses.
      const simplifiedOnly = '这们发国学东车说读时长门问间见对开会图书汉';
      final bad = <String>[];
      for (final e in entries) {
        for (final s in [
          e.localizedTitle('zh-Hant'),
          e.localizedSummary('zh-Hant'),
          e.localizedDescription('zh-Hant'),
          e.localizedCorrelation('zh-Hant'),
        ]) {
          if (s.split('').any(simplifiedOnly.contains)) bad.add('${e.id}: $s');
        }
      }
      expect(bad, isEmpty, reason: '${bad.length} Hant fields are Simplified');
    });

    test('the words opencc chose wrongly stay corrected', () {
      // Each was refuted by the app's own shipped Traditional editions.
      for (final wrong in [
        '髮掘', '髮生', '昇天', '覆活', '併為給', '幹河', '麵向', '羊皮捲',
        '託房', '繫住昴', '情慾生', '馬裡', '泰勒裡邁', '闡明瞭', '曆史',
        '燒燬', '倖存', '傢俱', '揹著', '一齣會堂', '綵衣', '鉅款',
      ]) {
        expect(everything, isNot(contains(wrong)), reason: wrong);
      }
    });

    test('and the ones opencc got right were not "corrected" back', () {
      // The other half of the rule: 12 classes were left alone because
      // opencc is right, and a future over-eager pass must not undo them.
      for (final right in ['彷彿', '饑荒', '細緻', '鐘乳石', '沖積']) {
        expect(everything, contains(right), reason: right);
      }
      // 髮 and 幹 are correct in their own contexts.
      expect(everything, contains('頭髮'));
      expect(everything, contains('樹幹'));
    });
  });

  test('_meta.confidenceCounts describes the records that are here', () {
    final counts = Map<String, dynamic>.from(
        raw['_meta']['confidenceCounts'] as Map);
    final live = <String, int>{};
    for (final e in entries) {
      live[e.confidenceLevel] = (live[e.confidenceLevel] ?? 0) + 1;
    }
    expect(counts.map((k, v) => MapEntry(k, v as int)), live);
    expect(live.values.reduce((a, b) => a + b), entries.length);
  });
}
