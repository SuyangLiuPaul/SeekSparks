import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ONE FACT, ONE YEAR.
///
/// Three assets date the Hebrew monarchy, and none of them shares an id
/// with another: `hebrew_kings.json` files by king and epoch,
/// `bible_timeline.json` by event, `wheel_history.json` by power. Nothing
/// joined them, so nothing could notice when they drifted — and they had.
/// The division of the kingdom was stated eight times across the three
/// files, five times as 931 BC and three times as 930 BC, and a reader who
/// opened Resources → Bible Chronology and then Resources → World History
/// Wheel was given two different years for the same event by the same app.
///
/// The wheel was the outlier and it was the one claiming the most: all
/// three of its records carry `basis: "scripture+thiele"`, which
/// `wheel_history.json`'s own `_meta.basisValues` defines as "scripture
/// states the interval; the absolute year follows Thiele's
/// reconstruction". `hebrew_kings.json` is the app's Thiele chart —
/// `"system": "thiele"` at its root — and it says 931. So the label was
/// false by the file's own definition, not by any outside authority's.
///
/// THAT IS WHY THIS TEST NEEDS NO CHRONOLOGIST. It does not ask which
/// year is right; picking between 931 and 930 is a question about Thiele,
/// and #292 (a citable Thiele source) is still open. It asks only that
/// the app not state one fact two ways. A disagreement is a defect
/// whichever side is correct.
///
/// The join is written out by hand because there is no key to join on.
/// That makes it the thing most likely to rot, so the first test below
/// resolves every path and fails on any that no longer lands — a renamed
/// record must break this file loudly rather than quietly shrink it to
/// nothing.
void main() {
  Map<String, dynamic> load(String p) =>
      json.decode(File(p).readAsStringSync()) as Map<String, dynamic>;

  final assets = <String, Map<String, dynamic>>{
    'hebrew_kings': load('assets/hebrew_kings.json'),
    'bible_timeline': load('assets/bible_timeline.json'),
    'wheel_history': load('assets/wheel_history.json'),
  };

  /// `asset/list/id/field` — e.g. `hebrew_kings/kings/solomon/reignEnd`.
  int? stated(String path) {
    final p = path.split('/');
    final list = (assets[p[0]]?[p[1]] as List?)?.cast<Map<String, dynamic>>();
    if (list == null) return null;
    for (final r in list) {
      if (r['id'] == p[2]) return (r[p[3]] as num?)?.toInt();
    }
    return null;
  }

  /// Every place the app states each of these facts. Grown, not pruned:
  /// a new asset that dates one of them belongs here.
  const facts = <String, List<String>>{
    'the kingdom divides': [
      'hebrew_kings/epochs/division/year',
      'hebrew_kings/kings/solomon/reignEnd',
      'hebrew_kings/kings/jeroboam_i/reignStart',
      'hebrew_kings/kings/rehoboam/reignStart',
      'bible_timeline/events/kingdom_divided/year',
      'wheel_history/powers/israel-united-monarchy/end',
      'wheel_history/powers/kingdom-of-israel/start',
      'wheel_history/powers/kingdom-of-judah/start',
    ],
    'Samaria falls and Israel ends': [
      'hebrew_kings/epochs/samaria/year',
      'hebrew_kings/kings/hoshea/reignEnd',
      'bible_timeline/events/israel_falls/year',
      'wheel_history/powers/kingdom-of-israel/end',
    ],
    'Jerusalem falls and Judah ends': [
      'hebrew_kings/epochs/jerusalem/year',
      'hebrew_kings/kings/zedekiah/reignEnd',
      'bible_timeline/events/judah_falls/year',
      'wheel_history/powers/kingdom-of-judah/end',
    ],
    'David becomes king': [
      'hebrew_kings/kings/david/reignStart',
      'bible_timeline/events/david_king/year',
    ],
    'Solomon becomes king': [
      'hebrew_kings/kings/david/reignEnd',
      'hebrew_kings/kings/solomon/reignStart',
      'bible_timeline/events/solomon_king/year',
    ],
    // Not monarchy and not Thiele — carried so that the detector is not
    // quietly a one-era instrument, and because these two records are the
    // only pair the wheel and the timeline both hold outright.
    'Jerusalem and the temple fall to Rome': [
      'bible_timeline/events/temple_destroyed/year',
      'wheel_history/events/jerusalem_destroyed/year',
    ],
  };

  test('the join still lands on every record it names', () {
    final missing = <String>[
      for (final paths in facts.values)
        for (final p in paths)
          if (stated(p) == null) p
    ];
    expect(missing, isEmpty,
        reason: 'these paths no longer resolve, so the agreement check '
            'below is silently not checking them:\n${missing.join("\n")}');

    // A floor on the instrument, not a pin on the data. Adding a fact is
    // meant to raise this; losing one has to fail.
    final statements = facts.values.fold<int>(0, (n, p) => n + p.length);
    expect(statements, greaterThanOrEqualTo(23));
    expect(facts.length, greaterThanOrEqualTo(6));
    // Three assets must actually be represented, or this is one file
    // agreeing with itself.
    final assetsSeen = <String>{
      for (final paths in facts.values)
        for (final p in paths) p.split('/').first
    };
    expect(assetsSeen, assets.keys.toSet());
  });

  test('no fact is stated at two different years', () {
    final disagreements = <String>[];
    for (final entry in facts.entries) {
      final byYear = <int, List<String>>{};
      for (final p in entry.value) {
        byYear.putIfAbsent(stated(p)!, () => <String>[]).add(p);
      }
      if (byYear.length > 1) {
        final shown = byYear.entries
            .map((e) => '${e.key}: ${e.value.join(", ")}')
            .join('\n    ');
        disagreements.add('  "${entry.key}" is stated as '
            '${byYear.keys.length} different years\n    $shown');
      }
    }
    expect(disagreements, isEmpty,
        reason: 'the app gives a reader two years for one event:\n'
            '${disagreements.join("\n")}');
  });
}
