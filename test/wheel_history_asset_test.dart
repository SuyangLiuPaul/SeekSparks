import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/wheel_history.dart';

/// Guards `assets/wheel_history.json` — the chronology wheel's dataset.
///
/// The first of these exists because an ongoing power was written with
/// `"end": null` while the model still declared `final int end`, and
/// `(j['end'] as num).toInt()` on null throws: the asset became
/// unloadable and the whole wheel page would have rendered blank. The
/// data was right and the model was wrong — a power that has not ended
/// has no end year, and writing this year in would have read as "the
/// state of Israel ended in 2026" and gone stale every January.
void main() {
  late Map<String, dynamic> raw;
  late WheelHistoryData data;

  setUpAll(() {
    raw = json.decode(File('assets/wheel_history.json').readAsStringSync())
        as Map<String, dynamic>;
    data = WheelHistoryData.fromJson(raw);
  });

  test('the asset parses at all — every power, every event', () {
    expect(data.powers, isNotEmpty);
    expect(data.events, isNotEmpty);
    expect(data.powers.length, (raw['powers'] as List).length,
        reason: 'a power was silently dropped while parsing');
    expect(data.events.length, (raw['events'] as List).length,
        reason: 'an event was silently dropped while parsing');
  });

  test('an ongoing power carries no end year and is drawn to the axis end',
      () {
    final ongoing = data.powers.where((p) => p.ongoing).toList();
    expect(ongoing, isNotEmpty,
        reason: 'at least the modern state of Israel has not ended');
    for (final p in ongoing) {
      expect(p.end, isNull);
      expect(p.endFor(2026), 2026);
    }
  });

  test('no power ends before it starts', () {
    for (final p in data.powers) {
      if (p.end == null) continue;
      expect(p.end!, greaterThanOrEqualTo(p.start), reason: p.id);
    }
  });

  test('every entry names a stream the file declares', () {
    final declared = {
      for (final s in (raw['streams'] as List).cast<Map<String, dynamic>>())
        s['id'] as String
    };
    expect(declared, isNotEmpty);
    for (final key in ['nations', 'powers', 'events']) {
      for (final e in (raw[key] as List).cast<Map<String, dynamic>>()) {
        expect(declared, contains(e['stream']),
            reason: '$key/${e['id']} points at an undeclared stream');
      }
    }
  });

  test('every nation carries the verse it was read from', () {
    for (final n in (raw['nations'] as List).cast<Map<String, dynamic>>()) {
      final ref = n['ref'] as String?;
      expect(ref, isNotNull, reason: '${n['id']} has no verse');
      expect(ref, matches(RegExp(r'^Genesis 1[01]:\d')),
          reason: '${n['id']} cites $ref, which is not in the table of '
              'nations or the line of Shem');
    }
  });

  test('the streams, the nations and their descent all parse', () {
    expect(data.streams.length, greaterThanOrEqualTo(20),
        reason: 'the wheel draws one band per stream');
    expect(data.nations.length, greaterThanOrEqualTo(80),
        reason: 'the table of nations is the whole of Genesis 10');
    // Every father named must itself be a nation in the table, or the
    // descent tree has a dangling branch.
    final ids = {for (final n in data.nations) n.id};
    for (final n in data.nations) {
      if (n.father.isEmpty) continue;
      expect(ids, contains(n.father),
          reason: '${n.id} descends from ${n.father}, which is not in the table');
    }
  });

  test('a band can be asked for its nations, powers and events', () {
    final withNations =
        data.streams.where((s) => data.nationsOf(s.id).isNotEmpty);
    expect(withNations, isNotEmpty);
    final egypt = data.nationsOf('egypt');
    expect(egypt.map((n) => n.id), contains('mizraim'),
        reason: 'Egypt descends from Mizraim, Genesis 10:6');
    expect(data.powersOf('rome'), isNotEmpty);
    expect(data.eventsOf('church'), isNotEmpty);
  });

  // ── the scripture events must actually align with scripture ──
  //
  // The wheel prints a verse beside an event and aligns that event on
  // the scripture baseline. Both are claims, and a chart whose rule is
  // "never guess at scripture" has to be able to prove them.

  test('an event dated FROM scripture cites scripture', () {
    for (final e in (raw['events'] as List).cast<Map<String, dynamic>>()) {
      final basis = e['basis'] as String;
      if (basis == 'conventional') continue;
      final refs = (e['refs'] as List?) ?? const [];
      expect(refs, isNotEmpty,
          reason: '${e['id']} claims basis "$basis" but cites no verse — it '
              'would be drawn on the scripture baseline on the strength of '
              'nothing');
    }
  });

  test('every verse cited resolves to a book and chapter that exist', () {
    final kjv = (json.decode(File('assets/kjv.json').readAsStringSync())
            as List)
        .cast<Map<String, dynamic>>();
    final have = <String>{
      for (final v in kjv) '${v['book']}|${v['chapter']}'
    };
    final books = {for (final v in kjv) v['book'] as String};

    final pattern = RegExp(r'^([1-3]?\s?[A-Za-z ]+?)\s+(\d+)(?::|\b)');
    final unresolved = <String>[];
    for (final e in (raw['events'] as List).cast<Map<String, dynamic>>()) {
      for (final r in ((e['refs'] as List?) ?? const []).cast<String>()) {
        final m = pattern.firstMatch(r.trim());
        if (m == null) {
          unresolved.add('${e['id']}: "$r" is not a reference this app parses');
          continue;
        }
        final book = m.group(1)!.trim();
        if (!books.contains(book)) {
          unresolved.add('${e['id']}: "$r" names no book called "$book"');
          continue;
        }
        if (!have.contains('$book|${m.group(2)}')) {
          unresolved.add('${e['id']}: "$r" — $book has no chapter ${m.group(2)}');
        }
      }
    }
    expect(unresolved, isEmpty,
        reason: 'the wheel would print a verse nobody can look up:\n'
            '${unresolved.join("\n")}');
  });

  test('a Thiele-dated record sits inside the reign it belongs to', () {
    // hebrew_kings.json is the app's Thiele reconstruction. Where a
    // record says its year comes from Thiele, that year must fall
    // inside the span of the kings that reconstruction gives — the two
    // datasets cannot be allowed to drift apart in silence.
    //
    // They drifted anyway, and this is the test that let them. It swept
    // `events` while the drift was in `powers`, so the carrier holding
    // all three offending records was never read; and its ±60 years of
    // slack are 60 times the size of the error, which was one year on
    // the division of the kingdom. A range check and an agreement check
    // catch different things, so both are kept: this asks whether a
    // record belongs to the era at all, and
    // `cross_asset_year_agreement_test.dart` asks whether the app
    // states one fact one way.
    final kings = (json.decode(
                File('assets/hebrew_kings.json').readAsStringSync())
            as Map<String, dynamic>)['kings'] as List;
    final spans = [
      for (final k in kings.cast<Map<String, dynamic>>())
        (
          (k['reignStart'] as num).toInt(),
          (k['reignEnd'] as num).toInt(),
        )
    ];
    final earliest = spans.map((s) => s.$1).reduce((a, b) => a < b ? a : b);
    final latest = spans.map((s) => s.$2).reduce((a, b) => a > b ? a : b);

    // Every year on every carrier that claims Thiele: an event's `year`,
    // and a power's `start` and `end` both, since a band claims its whole
    // span.
    final claims = <(String, int)>[
      for (final e in (raw['events'] as List).cast<Map<String, dynamic>>())
        if (e['basis'] == 'scripture+thiele')
          ('event ${e['id']}', (e['year'] as num).toInt()),
      for (final p in (raw['powers'] as List).cast<Map<String, dynamic>>())
        if (p['basis'] == 'scripture+thiele') ...[
          ('power ${p['id']} start', (p['start'] as num).toInt()),
          if (p['end'] != null)
            ('power ${p['id']} end', (p['end'] as num).toInt()),
        ],
    ];
    // The sweep reached both carriers, so an emptied one cannot pass.
    expect(claims.where((c) => c.$1.startsWith('event')), isNotEmpty);
    expect(claims.where((c) => c.$1.startsWith('power')), isNotEmpty);

    for (final (who, y) in claims) {
      expect(y, greaterThanOrEqualTo(earliest - 60),
          reason: '$who at $y claims a Thiele year, but Thiele\'s own '
              'reconstruction in this app does not reach back that far '
              '(earliest reign starts $earliest)');
      expect(y, lessThanOrEqualTo(latest + 60),
          reason: '$who at $y claims a Thiele year past the end of the '
              'reconstruction (latest reign ends $latest)');
    }
  });

  test('every event sits inside the axis the wheel draws', () {
    for (final e in (raw['events'] as List).cast<Map<String, dynamic>>()) {
      final y = (e['year'] as num).toInt();
      expect(y, inInclusiveRange(-4000, 2026),
          reason: '${e['id']} at $y would be clamped onto the rim and read as '
              'a year it is not');
    }
  });

  /// THE SAME QUESTION, ASKED OF EVERY KIND THAT ANSWERS IT.
  ///
  /// This check used to run over `events` alone, and `powers` and
  /// `nations` carry `basis` and `approximate` too. Nothing read them.
  /// An unrecognised value on a power would have parsed, loaded,
  /// rendered, and passed every test in this file — and then fallen
  /// through the default arm of `_basisText`
  /// (`radial_chronology_page.dart`) to tell the reader "a conventional
  /// date, not stated in scripture" about a date that might be neither.
  ///
  /// That is not a hypothetical. `wheel_history_disclosure_test.dart`
  /// exists because a field of this asset once reached the screen
  /// saying the wrong thing about the three Israelite kingdoms. A
  /// vocabulary guarded on one record kind and not its siblings is the
  /// same shape of hole.
  ///
  /// All three kinds are legal today — `nations` are all `scripture`,
  /// `powers` and `events` divide between `conventional` and
  /// `scripture+thiele`. So this test defends the state of the file
  /// rather than repairing it, which is what a guard is for.
  test('every dated record says what its date rests on, and says it '
      'explicitly', () {
    const allowed = {'scripture', 'scripture+thiele', 'conventional'};
    const kinds = ['events', 'powers', 'nations'];
    final seen = <String>{};
    var checked = 0;
    for (final kind in kinds) {
      final rows = (raw[kind] as List).cast<Map<String, dynamic>>();
      expect(rows, isNotEmpty, reason: '$kind stopped being swept');
      for (final r in rows) {
        expect(allowed, contains(r['basis']), reason: '$kind ${r['id']}');
        expect(r['approximate'], isA<bool>(),
            reason: '$kind ${r['id']} leaves approximate absent — absence '
                'has to mean something, so it is written on every entry');
        seen.add(r['basis'] as String);
        checked++;
      }
    }
    // The guard on the guard: a sweep that saw one record, or one
    // vocabulary word, would pass everything above and prove nothing.
    expect(checked, 711,
        reason: '567 events + 62 powers + 82 nations; if this moved, the '
            'corpus grew and the count should move with it');
    expect(seen, {'scripture', 'scripture+thiele', 'conventional'},
        reason: 'all three words are in use, so the closed set is doing '
            'work rather than admitting the only value there is');
  });
}
