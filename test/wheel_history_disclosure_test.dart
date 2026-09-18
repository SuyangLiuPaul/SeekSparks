import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/utils/reference_parser.dart';
import 'package:yahwehs_sword/utils/version_mapper.dart'
    show localizedReferenceLabel;

/// A STAMPED ASSET IS NOT A DISCLOSED ONE.
///
/// `assets/wheel_history.json` carried four fields on its power records
/// that `WheelPower` never parsed — `basis`, `ref`, `refs` and `region`.
/// Nothing failed. The asset was well-formed, the page rendered, 3,476
/// tests were green, and 42 scripture references sat in a shipped file
/// with no way for any reader to reach them.
///
/// The severity was not in the omission, it was in the DISTRIBUTION.
/// `WheelNation` drops three fields too, and that is harmless: all 82
/// nations read `approximate: false`, `basis: scripture`, `era: bible`,
/// so a constant tells the reader nothing they are not already shown.
/// `basis` on the powers is not constant — 3 of 62 say
/// `scripture+thiele` — and the page, having no field to consult, said
/// "conventional date, not stated in scripture" over all 62, including
/// the Kingdom of Judah, whose end the same record dates from
/// 2 Kings 25:8-9.
///
/// So an unread field may be excused, but only against its measured
/// constancy, which is asserted here rather than asserted in a comment.
/// The day one of these starts to vary, this test fails and the excuse
/// has to be re-earned.
void main() {
  final raw = json.decode(File('assets/wheel_history.json').readAsStringSync())
      as Map<String, dynamic>;
  final data = WheelHistoryData.fromJson(raw);

  List<Map<String, dynamic>> records(String key) =>
      (raw[key] as List).cast<Map<String, dynamic>>();

  /// Every key the model actually asks the JSON for, read out of the
  /// model's own SOURCE. Derived, not declared: a hand-kept list of
  /// "fields we parse" is one more thing that can drift away from the
  /// code, which is the failure this whole file exists to catch.
  final modelSource =
      File('lib/models/wheel_history.dart').readAsStringSync();
  final classStarts =
      RegExp(r'^class (\w+) \{', multiLine: true).allMatches(modelSource).toList();
  final classBody = <String, String>{};
  for (var i = 0; i < classStarts.length; i++) {
    final end = i + 1 < classStarts.length
        ? classStarts[i + 1].start
        : modelSource.length;
    classBody[classStarts[i].group(1)!] =
        modelSource.substring(classStarts[i].start, end);
  }
  Set<String> keysReadBy(String className) {
    final body = classBody[className];
    expect(body, isNotNull,
        reason: 'the model no longer declares a class called $className — '
            'this detector reads the source, so a rename silently empties '
            'it unless it fails here');
    return RegExp(r"j\['([^']+)'\]")
        .allMatches(body!)
        .map((m) => m.group(1)!)
        .toSet();
  }

  /// The detector fired on nothing would pass. Prove it can see.
  test('the detector reads real keys out of the model source', () {
    expect(keysReadBy('WheelHistoryEvent'),
        containsAll(<String>{'id', 'year', 'basis', 'refs', 'title', 'desc'}));
    expect(keysReadBy('WheelPower'), contains('basis'));
    expect(classBody.keys,
        containsAll(<String>{'WheelStream', 'WheelNation', 'WheelPower'}));
  });

  /// The excuse each unread field has to earn, and the assertion that
  /// earns it. A field may only appear here with a reason that is itself
  /// checked below — never with prose alone.
  test('every field in the asset is either read by the model or excused',
      () {
    final unreadByClass = <String, Set<String>>{};
    for (final (className, listKey) in const [
      ('WheelStream', 'streams'),
      ('WheelNation', 'nations'),
      ('WheelPower', 'powers'),
      ('WheelHistoryEvent', 'events'),
    ]) {
      final present = <String>{for (final r in records(listKey)) ...r.keys};
      unreadByClass[className] = present.difference(keysReadBy(className));
    }

    expect(unreadByClass['WheelStream'], isEmpty);
    expect(unreadByClass['WheelHistoryEvent'], isEmpty);

    // Constant across every record, so nothing is withheld from a reader
    // by not printing it — and every nation's verse is on screen anyway.
    expect(unreadByClass['WheelNation'],
        <String>{'approximate', 'basis', 'era'});
    for (final n in records('nations')) {
      expect(n['approximate'], isFalse, reason: n['id'] as String);
      expect(n['basis'], 'scripture', reason: n['id'] as String);
      expect(n['era'], 'bible', reason: n['id'] as String);
    }

    // `region` USED to be excused here, on the grounds that it was very
    // nearly a function of `stream` — 20 of the 22 streams mapped to
    // exactly one region, so it was a coarser regrouping of what the
    // chart already showed rather than information held back.
    //
    // 2026-09-02 ended that. Adding 42 pontificates and five crusades
    // put the church band through `europe` AND `levant`, which is not a
    // data error — the papacy and the crusades genuinely happened in
    // different places — and took the split streams from two to three.
    // The excuse's own premise had started to fail, so rather than
    // widening the threshold the field was READ: the power sheet prints
    // the region beside the years. `ongoing` stays excused because it
    // is computed from `end`, and is checked to agree with it rather
    // than trusted.
    expect(unreadByClass['WheelPower'], <String>{'ongoing'});
    for (final p in records('powers')) {
      if (p.containsKey('ongoing')) {
        expect(p['ongoing'], p['end'] == null,
            reason: '${p['id']} writes `ongoing` and the model computes it '
                'from `end`; the two must not be able to disagree');
      }
    }
  });

  /// The detector above iterates the four RECORD lists, so the asset's
  /// own header — `_meta` — is outside its reach by construction. This
  /// is that same excuse-or-read discipline applied to the header
  /// (#318 phase 24).
  test('the file header is disclosed too, or excused with its reason', () {
    final meta = (raw['_meta'] as Map).cast<String, dynamic>();
    const readByModel = {'provenance', 'coverage', 'scope', 'axis'};
    final remainder = meta.keys.toSet().difference(readByModel);
    expect(remainder, <String>{'purpose', 'basisValues', 'approximate', 'streams'},
        reason: 'these four are compiler notes and per-record glossaries the '
            'page already prints per record via `_basisText` / '
            '`approximatePrefix` — a NEW `_meta` key appearing here must be '
            'read by the model, not added to this excuse list');
  });

  /// The defect this ticket actually found, stated as the reader saw it.
  test('a power dated from scripture does not say it is not in scripture',
      () {
    // 2026-09-15: `traditional` is excluded alongside `conventional`.
    // The set below is the powers drawn on the SCRIPTURE baseline, and
    // a traditional band is the opposite of that — 夏朝 and 五帝 are
    // dated by 《史記》 and 《竹書紀年》, not by a verse, and the sheet
    // says so in as many words (「傳說紀年 · 非信史」). Lumping them in
    // here would assert they were read out of scripture.
    final fromScripture = data.powers
        .where((p) => p.basis != 'conventional' && p.basis != 'traditional')
        .toList();
    // 2026-09-03: two more joined, both people rather than thrones, and
    // both take their years from the SAME Thiele reckoning the three
    // kingdoms do — Gedaliah from the fall of Jerusalem that made him
    // governor, Jezebel from Ahab's accession to Jehu's coup, every one
    // of those years already on this chart. The set is pinned rather
    // than counted so that a record cannot drift onto the scripture
    // baseline without a human naming it here.
    expect(
        fromScripture.map((p) => p.id).toSet(),
        <String>{
          'israel-united-monarchy',
          'kingdom-of-israel',
          'kingdom-of-judah',
          'gedaliah-governor',
          'jezebel-queen',
        },
        reason: 'the three the sheet used to deny scripture for, and two '
            'people dated from the same reign figures');
    for (final p in fromScripture) {
      expect(p.refs, isNotEmpty,
          reason: '${p.id} claims basis "${p.basis}" and cites no verse — it '
              'would be drawn on the scripture baseline on the strength of '
              'nothing');
    }
    // And the converse, so this cannot be satisfied by marking everything
    // conventional again.
    // 226 since 2026-09-05: 59, plus 57 church-history spans (42
    // pontificates, 8 Byzantine reigns, 5 crusades, the Latin Empire and
    // the Order of Saint John), plus 30 Roman and Greek, plus Moab,
    // Ammon and Edom, plus the Himyarite kingdom, the Liao and the
    // Tibetan empire, plus the 35 spans the chart's own drawn layer
    // turned up, and 34 more from its bands — the Chinese dynasties,
    // the ten kingdoms of the migration, Kassite Babylon —
    // popes the chain had skipped, Visigothic and
    // Vandal kingdoms, the Jin, Songhai, Mali, Wari and the rest.
    // Every one is conventional and none could be
    // anything else: scripture dates no pope and no emperor, and gives
    // no regnal years for Israel's neighbours either.
    // 2026-09-15: 226 → 255, the 32 ancient bands less the three that
    // are `traditional` rather than conventional (五帝, 夏朝, 고조선).
    // 2026-09-16: 255 → 286, the 31 modern and medieval bands that
    // close the other end — 「中国还有很多其他的在清朝之后很多 都missing
    // 了在strip里面」. Every one is conventional, which is the whole
    // reason the Korean three kingdoms are drawn from the fourth
    // century and not from the Samguk Sagi's 57 BC: a founding year out
    // of a traditional chronicle would have had to be `traditional`,
    // and this band is not that.
    expect(data.powers.where((p) => p.basis == 'conventional').length, 297);
    // And the three, named, because a value used by nothing is a value
    // that quietly stopped being applied.
    expect(
        data.powers
            .where((p) => p.basis == 'traditional')
            .map((p) => p.id)
            .toSet(),
        <String>{
          'five-emperors-traditional',
          'xia-dynasty',
          'gojoseon-traditional',
        },
        reason: 'the traditional bands changed — each one is a legend '
            'everybody knows, carried on the chart deliberately and '
            'marked as tradition in its name, its note and its basis');
  });

  test('both spellings of a power reference reach the model', () {
    // 14 records spell it `ref`, 14 spell it `refs`. The model reads
    // both into one list; if it ever stopped reading one, exactly one of
    // these counts would drop to zero and nothing else would fail. The
    // three that joined on 2026-09-03 — Moab, Ammon and Edom — all took
    // the singular, and so did `hasmonean-john-hyrcanus` later the same
    // day, and `judges-of-israel` on 2026-09-05, which is why this half
    // has moved three times and the other has not.
    final singular = records('powers')
        .where((p) => (p['ref'] as String?)?.isNotEmpty ?? false)
        .toList();
    final plural =
        records('powers').where((p) => (p['refs'] as List?)?.isNotEmpty ?? false);
    // 2026-09-15: 17 → 23 and 14 → 17. The ancient additions cite
    // Genesis 10 heavily (Elam, Kush, Mitanni, the Hittite states), and
    // `kush-napata` moved from the singular to the plural when 2 Kings
    // 19:9 was added beside Genesis 10:6 — its note already argued from
    // Tirhakah, and a verse a record argues from belongs in its refs
    // rather than only in its prose.
    expect(singular.length, 23);
    expect(plural.length, 17);
    for (final p in singular) {
      final parsed = data.powers.firstWhere((q) => q.id == p['id']);
      expect(parsed.refs, contains(p['ref']), reason: p['id'] as String);
    }
    // 2026-09-15: 31 → 40 carriers and 49 → 61 references. The ancient
    // bands lean on Genesis 10 — Elam, Kush, Mitanni and the Hittite
    // states are all in the table of nations — which is the chart's own
    // rule working rather than an exception to it.
    final carried = data.powers.where((p) => p.refs.isNotEmpty).length;
    expect(carried, 40);
    expect(data.powers.fold<int>(0, (n, p) => n + p.refs.length), 61);
  });

  /// Extends `wheel_history_asset_test.dart`'s resolvability sweep, which
  /// walks `events` only, to the two carriers it never reached. The power
  /// references had never been checked because nothing rendered them; now
  /// that a reader can tap one, a reference that goes nowhere is a defect
  /// this fix would have introduced.
  test('every reference on every carrier parses and localises', () {
    final byCarrier = <String, List<String>>{
      'event': [for (final e in data.events) ...e.refs],
      'nation': [
        for (final n in data.nations)
          if (n.ref.isNotEmpty) n.ref
      ],
      'power': [for (final p in data.powers) ...p.refs],
    };
    // 67 since 2026-09-03: Nahum 3:8 on the sack of Thebes and
    // 2 Kings 17:3-4 on Hoshea's appeal to So of Egypt.
    // 85 since 2026-09-15: the ancient events cite Genesis 10 and 11
    // for Elam, Cush, Nimrod's Erech and Accad, and Ur of the Chaldees.
    expect(byCarrier['event']!.length, 85);
    expect(byCarrier['nation']!.length, 82);
    expect(byCarrier['power']!.length, 61);

    final bad = <String>[];
    for (final entry in byCarrier.entries) {
      for (final r in entry.value) {
        if (parseReference(r) == null) {
          bad.add('${entry.key}: "$r" is not a reference this app parses');
          continue;
        }
        for (final locale in const ['zh-Hans', 'zh-Hant']) {
          final shown = localizedReferenceLabel(r, locale);
          if (RegExp(r'[A-Za-z]').hasMatch(shown)) {
            bad.add('${entry.key}: "$r" still reads "$shown" in $locale');
          }
        }
      }
    }
    expect(bad, isEmpty,
        reason: 'the wheel prints a verse a reader cannot use:\n'
            '${bad.join("\n")}');
  });
}
