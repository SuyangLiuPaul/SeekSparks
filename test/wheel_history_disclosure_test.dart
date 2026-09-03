import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/version_mapper.dart'
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
    final fromScripture =
        data.powers.where((p) => p.basis != 'conventional').toList();
    expect(fromScripture.map((p) => p.id).toSet(),
        <String>{'israel-united-monarchy', 'kingdom-of-israel', 'kingdom-of-judah'},
        reason: 'the three the sheet used to deny scripture for');
    for (final p in fromScripture) {
      expect(p.refs, isNotEmpty,
          reason: '${p.id} claims basis "${p.basis}" and cites no verse — it '
              'would be drawn on the scripture baseline on the strength of '
              'nothing');
    }
    // And the converse, so this cannot be satisfied by marking everything
    // conventional again.
    // 149 since 2026-09-03: 59, plus 57 church-history spans (42
    // pontificates, 8 Byzantine reigns, 5 crusades, the Latin Empire and
    // the Order of Saint John), plus 30 Roman and Greek, plus Moab,
    // Ammon and Edom. Every one is conventional and none could be
    // anything else: scripture dates no pope and no emperor, and gives
    // no regnal years for Israel's neighbours either.
    expect(data.powers.where((p) => p.basis == 'conventional').length, 149);
  });

  test('both spellings of a power reference reach the model', () {
    // 13 records spell it `ref`, 14 spell it `refs`. The model reads
    // both into one list; if it ever stopped reading one, exactly one of
    // these counts would drop to zero and nothing else would fail. The
    // three that joined on 2026-09-03 — Moab, Ammon and Edom — all took
    // the singular, which is why this half moved and the other did not.
    final singular = records('powers')
        .where((p) => (p['ref'] as String?)?.isNotEmpty ?? false)
        .toList();
    final plural =
        records('powers').where((p) => (p['refs'] as List?)?.isNotEmpty ?? false);
    expect(singular.length, 13);
    expect(plural.length, 14);
    for (final p in singular) {
      final parsed = data.powers.firstWhere((q) => q.id == p['id']);
      expect(parsed.refs, contains(p['ref']), reason: p['id'] as String);
    }
    final carried = data.powers.where((p) => p.refs.isNotEmpty).length;
    expect(carried, 27);
    expect(data.powers.fold<int>(0, (n, p) => n + p.refs.length), 45);
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
    expect(byCarrier['event']!.length, 65);
    expect(byCarrier['nation']!.length, 82);
    expect(byCarrier['power']!.length, 45);

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
