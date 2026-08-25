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

    // `region` survives unread because the wheel draws by STREAM and the
    // region is very nearly a function of it: 20 of the 22 streams map to
    // exactly one region. It is a coarser regrouping of what the chart
    // already shows, not information held back. `ongoing` is computed
    // from `end`, and is checked to agree with it rather than trusted.
    expect(unreadByClass['WheelPower'], <String>{'region', 'ongoing'});
    final regionsOfStream = <String, Set<String>>{};
    for (final p in records('powers')) {
      regionsOfStream
          .putIfAbsent(p['stream'] as String, () => <String>{})
          .add(p['region'] as String);
      if (p.containsKey('ongoing')) {
        expect(p['ongoing'], p['end'] == null,
            reason: '${p['id']} writes `ongoing` and the model computes it '
                'from `end`; the two must not be able to disagree');
      }
    }
    final split = regionsOfStream.entries.where((e) => e.value.length > 1);
    expect(split.length, lessThanOrEqualTo(2),
        reason: 'region is excused for tracking stream; it no longer does: '
            '${split.map((e) => "${e.key}=${e.value}").join(", ")}');
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
    expect(data.powers.where((p) => p.basis == 'conventional').length, 59);
  });

  test('both spellings of a power reference reach the model', () {
    // 10 records spell it `ref`, 14 spell it `refs`. The model reads both
    // into one list; if it ever stopped reading one, exactly one of these
    // counts would drop to zero and nothing else would fail.
    final singular = records('powers')
        .where((p) => (p['ref'] as String?)?.isNotEmpty ?? false)
        .toList();
    final plural =
        records('powers').where((p) => (p['refs'] as List?)?.isNotEmpty ?? false);
    expect(singular.length, 10);
    expect(plural.length, 14);
    for (final p in singular) {
      final parsed = data.powers.firstWhere((q) => q.id == p['id']);
      expect(parsed.refs, contains(p['ref']), reason: p['id'] as String);
    }
    final carried = data.powers.where((p) => p.refs.isNotEmpty).length;
    expect(carried, 24);
    expect(data.powers.fold<int>(0, (n, p) => n + p.refs.length), 42);
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
    expect(byCarrier['event']!.length, 55);
    expect(byCarrier['nation']!.length, 82);
    expect(byCarrier['power']!.length, 42);

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
