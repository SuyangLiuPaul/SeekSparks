import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE CHRONOLOGY AND THE FAMILY TREE NAME THE SAME PEOPLE.
///
/// `bible_timeline.json` carries `personIds` on 68 of its 105 events —
/// 95 links naming 44 people in `family_tree.json`. The field had
/// shipped in the asset and been parsed into [TimelineEvent] since the
/// page was written, and `personIds` appeared at exactly three lines in
/// all of `lib/`, all three inside `lib/models/timeline_event.dart`.
/// Nothing rendered it, so nothing checked it, and the two assets had
/// never compared notes.
///
/// They disagreed. `family_tree` dated Moses -1525..-1405; the timeline
/// dated `moses_born` -1526 and `moses_dies` -1406 — both files stating
/// the year EXACTLY (`approximate: false` / `dating.kind: birth`), on
/// the same `scripture+thiele` basis, citing the same two verses,
/// 1 Kings 6:1 and Exodus 7:7. That is not two reconstructions; it is
/// one derivation written down twice and one of the copies contradicting
/// its own arithmetic. `tools/audit_dates.py` check 32b validates the
/// timeline's chain (exodus -1446, Exodus 7:7's 80 years), and Isaac
/// (-2066) and Jacob (-2006) agree exactly across the two files, so the
/// offset was isolated rather than a convention. `family_tree` was
/// corrected, and `corrections` records both fields.
///
/// ONE FINDING IS LEFT STANDING AND IS NOT CHECKED HERE. Ishmael's
/// birth is -2080 in both files, but the timeline states it exactly on
/// `scripture+thiele` — Genesis 16:16 gives Abram's age outright, which
/// is why `audit_dates.py` promoted it out of `conventional` in
/// v1.6.146 — while the tree still hedges the same year as
/// `conventional` / `approximate`, so the family tree prints "c. 2080
/// BC" for a date the chronology prints as 2080 BC. That is one fact
/// shown at two confidences, not at two years. It is not repaired here
/// because the repair STRENGTHENS a published claim, and the
/// repository's standing instinct is that hedging is the conservative
/// direction and un-hedging is a decision. Named so the next reader
/// does not have to re-find it.
///
/// UNLIKE `cross_asset_year_agreement_test.dart`, THIS JOIN IS NOT
/// HAND-WRITTEN. That test had to enumerate paths because its three
/// assets share no key. Here `personIds` IS the key, so every link can
/// be walked, and the floors below exist to catch the opposite failure:
/// a field quietly emptied would otherwise make this file pass by
/// checking nothing.
void main() {
  Map<String, dynamic> load(String p) =>
      json.decode(File(p).readAsStringSync()) as Map<String, dynamic>;

  final tree = load('assets/family_tree.json');
  final timeline = load('assets/bible_timeline.json');

  final people = (tree['people'] as List).cast<Map<String, dynamic>>();
  final events = (timeline['events'] as List).cast<Map<String, dynamic>>();
  final byId = {for (final p in people) p['id'] as String: p};

  final links = <({String event, String person})>[
    for (final e in events)
      for (final id in ((e['personIds'] as List?) ?? const []).cast<String>())
        (event: e['id'] as String, person: id),
  ];

  test('every personIds entry lands on a person, and the field is not empty',
      () {
    final unresolved = [
      for (final l in links)
        if (!byId.containsKey(l.person)) '${l.event} -> ${l.person}',
    ];
    expect(unresolved, isEmpty,
        reason: 'the timeline names people the family tree does not '
            'hold:\n${unresolved.join("\n")}');

    // Floors on the instrument, not pins on the data. Adding links is
    // meant to raise these; losing them has to fail, because an empty
    // `personIds` would make every other check here vacuously green.
    expect(links.length, greaterThanOrEqualTo(88));
    expect(events.where((e) => ((e['personIds'] as List?) ?? const []).isNotEmpty),
        hasLength(greaterThanOrEqualTo(61)));
    expect({for (final l in links) l.person},
        hasLength(greaterThanOrEqualTo(37)));
  });

  /// A CHIP PRINTS A NAME AND NOTHING ELSE.
  ///
  /// The tree holds two pairs of men who share a name outright:
  /// Manasseh (Joseph's son, `manasseh`) and Manasseh the king
  /// (`manasseh_king`), and two Eleazars. Neither pair is linked from
  /// the timeline today, and the id vocabulary already disambiguates
  /// the near misses in the other direction — `joseph` is the tribe and
  /// the husband of Mary is `joseph_father_of_jesus`, `enoch` is Seth's
  /// line and Cain's son is `enoch_cain`.
  ///
  /// So a link resolving is not a link resolving CORRECTLY. This is the
  /// check that would catch `personIds: ["manasseh"]` added to
  /// `josiah_reform` meaning the king: the reader would be shown a chip
  /// reading "Manasseh" that opens Joseph's son, and no id check can see
  /// that. All three scripts are tested because the chip renders one.
  test('no linked person shares a printed name with anyone else in the tree',
      () {
    final ambiguous = <String>[];
    for (final field in ['name', 'nameZhHans', 'nameZhHant']) {
      final holders = <String, List<String>>{};
      for (final p in people) {
        holders
            .putIfAbsent(p[field] as String, () => <String>[])
            .add(p['id'] as String);
      }
      for (final id in {for (final l in links) l.person}) {
        final name = byId[id]![field] as String;
        if (holders[name]!.length > 1) {
          ambiguous.add('  $field "$name" is held by '
              '${holders[name]!.join(", ")} and $id is linked from the '
              'timeline');
        }
      }
    }
    expect(ambiguous, isEmpty,
        reason: 'a person chip would print a name that names two '
            'people:\n${ambiguous.join("\n")}');
  });

  /// "WAS THE PERSON ALIVE?" IS THE WRONG QUESTION, WHICH IS WHY THIS
  /// IS A LIST AND NOT AN ASSERTION.
  ///
  /// The Transfiguration deliberately puts Moses in an AD 30 scene, and
  /// `wilderness_40` is a forty-year span keyed to its END, so Aaron —
  /// who dies in the fortieth year, Numbers 33:38 — is correctly linked
  /// to a year one after his death. A containment check run as a bare
  /// assertion would call both of those defects and be wrong twice.
  ///
  /// What it CAN do is fix the set. Every pair below is a link whose
  /// event year falls outside the person's shipped lifespan, and each
  /// carries the reason it is allowed. A new one is a defect until
  /// someone writes its reason here.
  ///
  /// `wilderness_40/aaron` WAS HERE AND HAS BEEN DELETED, which is what
  /// the dead-entry assertion at the foot of this file is for. It read
  /// "Aaron dies in the fortieth of them" and existed only because the
  /// tree shipped his death as -1407 against the event's -1406.
  /// `audit_dates.py` now derives him from Exodus 7:7 (83 at the
  /// exodus) and Numbers 33:39 (123 at his death), which puts the death
  /// at -1406 and the link inside his life. Nothing is excused any
  /// more, so nothing is listed.
  ///
  /// THE FIVE JESUS ENTRIES ARE NOT ADJUDICATED, ON PURPOSE. The tree
  /// says c. 4 BC – c. AD 30 and the timeline says -5 and AD 33, and
  /// BOTH sides are `conventional` and marked approximate — two
  /// published reconstructions of a year no chain of stated intervals
  /// reaches, each already hedged to the reader with a "c.". Moses was
  /// correctable because both sides claimed to be exact and one
  /// contradicted its own cited verses; this is the opposite case, and
  /// picking a side here would be this file deciding a chronology. It
  /// is named and left alone. See #292.
  const allowed = <String, String>{
    'transfiguration/moses':
        'Moses dies -1406 and appears in glory at Matthew 17:3. The '
            'scene is the point of the record, not a slip.',
    'jesus_born/jesus':
        'Both sides conventional and approximate: the tree shows c. 4 BC, '
            'the timeline -5. Not adjudicated.',
    'triumphal_entry/jesus': 'AD 33 against the tree\'s c. AD 30. See above.',
    'last_supper/jesus': 'AD 33 against the tree\'s c. AD 30. See above.',
    'crucifixion/jesus': 'AD 33 against the tree\'s c. AD 30. See above.',
    'resurrection/jesus': 'AD 33 against the tree\'s c. AD 30. See above.',
    'ascension/jesus': 'AD 33 against the tree\'s c. AD 30. See above.',
  };

  int yearOf(String eventId) =>
      (events.firstWhere((e) => e['id'] == eventId)['year'] as num).toInt();

  test('no link contradicts a person\'s own dates without a reason', () {
    // AM and BC are not convertible in this app — the repo fixes no
    // creation year, and `family_tree.json`'s own `_meta.yearLegend`
    // says so. Comparing an Anno Mundi person against a BC event year
    // is not a finding, it is a unit error; the 35 `am` people are out
    // of both checks' reach and that is a limit of the instrument.
    // `seth_born` is the one that would trip it: AM 130 against -3870.
    final outside = <String>[];
    final live = <String>{};

    // (1) THE SHARP ONE, AND THE ONLY ONE THAT SEES A DEATH YEAR.
    //
    // An event id `<pid>_born` / `<pid>_dies` whose own `personIds`
    // names `<pid>` is that person's birth or death stated twice, so
    // the two years must be equal — no lifespan, no tolerance. This is
    // derived from the ids rather than tabulated, so a new birth event
    // is checked the day it lands.
    //
    // It is restricted to records BOTH sides state exactly, and that
    // restriction is the whole point rather than a convenience: where
    // one side hedges, the disagreement is between two published
    // reconstructions and this file does not pick one. Where neither
    // hedges, a disagreement is one derivation written twice with one
    // copy wrong, and that is a defect whichever copy it is.
    //
    // The containment check below cannot do this job. Before the Moses
    // repair it saw `moses_born` (-1526 against a shipped birth of
    // -1525) and was blind to `moses_dies` (-1406 against a shipped
    // death of -1405), because a death dated a year EARLY still falls
    // inside the lifespan.
    for (final suffix in const {'_born': 'birthYear', '_dies': 'deathYear'}
        .entries) {
      for (final e in events) {
        final id = e['id'] as String;
        if (!id.endsWith(suffix.key)) continue;
        final pid = id.substring(0, id.length - suffix.key.length);
        if (!((e['personIds'] as List?) ?? const []).contains(pid)) continue;
        final p = byId[pid];
        if (p == null || p['yearSystem'] != 'bc') continue;
        if (e['approximate'] == true) continue;
        if ((p['dating'] as Map?)?['kind'] != 'birth') continue;
        final shipped = (p[suffix.value] as num?)?.toInt();
        final year = (e['year'] as num).toInt();
        if (shipped == year) continue;
        final key = '$id/$pid';
        if (allowed.containsKey(key)) {
          live.add(key);
          continue;
        }
        outside.add('  $key: both files state this exactly and they '
            'disagree — event $year, ${p['name']}.${suffix.value} $shipped');
      }
    }

    // (2) THE BROAD ONE: every link, does the year fall in the life?
    for (final l in links) {
      final p = byId[l.person]!;
      if (p['yearSystem'] != 'bc') continue;
      final birth = (p['birthYear'] as num?)?.toInt();
      final death = (p['deathYear'] as num?)?.toInt();
      if (birth == null || death == null) continue;
      final year = yearOf(l.event);
      if (year >= birth && year <= death) continue;
      final key = '${l.event}/${l.person}';
      if (allowed.containsKey(key)) {
        live.add(key);
        continue;
      }
      outside.add('  $key: event $year, ${p['name']} $birth..$death');
    }

    expect(outside, isEmpty,
        reason: 'the two assets disagree about a person the app links '
            'them by:\n${outside.join("\n")}');

    // An allowlist that has stopped matching anything is a guard that
    // has quietly widened. If a repair makes one of these agree, delete
    // the entry rather than leaving it to cover a future defect.
    final dead = allowed.keys.toSet().difference(live);
    expect(dead, isEmpty,
        reason: 'these exceptions no longer describe a disagreement and '
            'are now blanket permission:\n${dead.join("\n")}');
  });
}
