/// THE ONE PLACE THIS CHART CONTRADICTS ITSELF IN ARITHMETIC A READER
/// CAN DO.
///
/// Three numbers ship, and two of them cannot both be read as fixing a
/// year:
///
///     tiberius_emperor   AD 14   Tiberius succeeds Augustus
///     pilate_prefect     AD 26   Pilate takes office
///     jesus_baptized     AD 26   the baptism
///
/// Luke 3:1 dates John's ministry by BOTH the fifteenth year of
/// Tiberius and the governorship of Pilate. Counted from AD 14 the
/// fifteenth year is AD 28 or 29; Pilate's prefecture begins in AD 26.
/// So the verse brackets the ministry — 26 at the earliest, 28/29 on
/// the reign count — and this chart places the baptism at the early end
/// of that bracket.
///
/// The years are NOT changed here. `jesus_baptized` is `conventional`
/// and `approximate`, it has been AD 26 since the initial commit, and
/// re-dating a shipped scripture-adjacent event on the strength of one
/// reading is not a repair. What was wrong was the SILENCE: the
/// Tiberius record invited the subtraction in its own description and
/// then left the reader holding a number the chart contradicts three
/// records away.
///
/// So this file pins the disclosure, in all three scripts, on every
/// record that carries one of the numbers. If someone shortens one of
/// those sentences the contradiction goes quiet again, and quiet is the
/// only state it must never be in.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['en', 'zh-Hans', 'zh-Hant'];

/// The years, and the arithmetic that makes them a problem. Computed
/// rather than written, so the day one of them moves this file says
/// what the new bracket is instead of asserting a stale one.
void main() {
  late final Map<String, dynamic> wheel;
  late final Map<String, dynamic> timeline;
  late final int accession;
  late final int baptism;
  late final int pilate;

  setUpAll(() {
    wheel = jsonDecode(File('assets/wheel_history.json').readAsStringSync())
        as Map<String, dynamic>;
    timeline =
        jsonDecode(File('assets/bible_timeline.json').readAsStringSync())
            as Map<String, dynamic>;
    Map<String, dynamic> wheelEvent(String id) =>
        (wheel['events'] as List).cast<Map<String, dynamic>>().firstWhere(
            (e) => e['id'] == id);
    accession = wheelEvent('tiberius_emperor')['year'] as int;
    pilate = wheelEvent('pilate_prefect')['year'] as int;
    baptism = ((timeline['events'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['id'] == 'jesus_baptized')['year']) as int;
  });

  test('the numbers still disagree, which is why the disclosure is owed', () {
    expect(accession, 14);
    expect(pilate, 26);
    expect(baptism, 26);
    // The fifteenth year of a reign begun in `accession`, inclusive and
    // exclusive — the two ways Rome counted, which is why the chart
    // says "28 or 29" rather than picking one.
    final inclusive = accession + 14;
    final exclusive = accession + 15;
    expect([inclusive, exclusive], [28, 29]);
    expect(baptism, lessThan(inclusive),
        reason: 'the chart no longer contradicts itself here, so the '
            'sentences this file pins may be describing a problem that '
            'has gone away — check before deleting them');
    // The other clause of the same verse: the baptism cannot precede
    // Pilate, and on this chart it does not.
    expect(baptism, greaterThanOrEqualTo(pilate));
  });

  test('the Tiberius record states where its own fifteenth year lands', () {
    final desc = ((wheel['events'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['id'] == 'tiberius_emperor')['desc']
        as Map<String, dynamic>);
    for (final locale in _locales) {
      final text = desc[locale] as String;
      expect(text, contains('28'), reason: '$locale: the year the '
          'fifteenth year comes to is not stated');
      expect(text, contains('26'),
          reason: '$locale: the chart\'s own baptism year is not named');
      expect(text.contains('Pilate') || text.contains('彼拉多'), isTrue,
          reason: '$locale: the clause that fixes the early end is missing');
    }
  });

  test('the baptism record says which end of the bracket it sits at', () {
    final e = (timeline['events'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((x) => x['id'] == 'jesus_baptized');
    for (final field in ['descEn', 'descZhHans', 'descZhHant']) {
      final text = e[field] as String;
      expect(text, contains('28'), reason: field);
      expect(text.contains('Tiberius') || text.contains('提比留'), isTrue,
          reason: field);
      expect(text.contains('Pilate') || text.contains('彼拉多'), isTrue,
          reason: field);
    }
    // And the verse that creates the tension is one the reader can open
    // from the record that discusses it.
    expect((e['refs'] as List).cast<String>(), contains('Luke 3:1'));
  });

  test('John the Baptist\'s span explains itself without a document', () {
    final note = ((wheel['ministries'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((m) => m['id'] == 'john_the_baptist')['note']
        as Map<String, dynamic>);
    for (final locale in _locales) {
      final text = note[locale] as String;
      expect(text, contains('28'), reason: locale);
      // It used to end "see the inconsistency flagged in section 1",
      // pointing at a working document no reader will ever hold. A note
      // that sends the reader somewhere unreachable is worse than one
      // that says nothing.
      expect(text.toLowerCase(), isNot(contains('section 1')), reason: locale);
      expect(text, isNot(contains('第1节')), reason: locale);
    }
  });
}
