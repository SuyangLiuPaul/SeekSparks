import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show kMaxYear, kMinYear;

/// ONE CREATION YEAR, AND EVERYTHING ANNO MUNDI ADDED TO IT.
///
/// `chronology.json` counts in Anno Mundi and `bible_timeline.json`
/// counts in BC, and until now NOTHING joined them — the app's only
/// cross-asset year test (`cross_asset_year_agreement_test.dart`)
/// reaches `hebrew_kings.json` and stops. That gap is what let the
/// wheel draw one circle on two calendars: the eight records above
/// Abraham were Ussher's, rounded, while everything below him was
/// counted back from Thiele's Solomon, leaving the two halves 114 years
/// apart at exactly the join a reader is most likely to look at, and
/// the creation-to-flood span 1,652 years where Genesis 5 and 7:6 give
/// 1,656.
///
/// The repair was to carry the app's own chain UPWARD instead of
/// starting a second one: Genesis 12:4 and 11:26 to Terah, Genesis
/// 11:24 down to 11:12 through the fathers, Genesis 11:10 to the flood,
/// Genesis 7:6 to Noah, Genesis 5:28 back to 5:3 to Adam. That is not a
/// new convention; it is the wheel's existing axis, followed further
/// back, and the assertions below are what say so.
///
/// THE IDENTITY THIS FILE EXISTS FOR:
///
///     _meta.creation.year
///       == events['abram_called'].year - epochs['haran'].mt
///
/// Everything else here is a consequence of it. A future edit that
/// re-dates one asset and not the other breaks this line first.
void main() {
  Map<String, dynamic> load(String p) =>
      json.decode(File(p).readAsStringSync()) as Map<String, dynamic>;

  final timeline = load('assets/bible_timeline.json');
  final chronology = load('assets/chronology.json');
  final tree = load('assets/family_tree.json');

  final events = {
    for (final e in (timeline['events'] as List).cast<Map<String, dynamic>>())
      e['id'] as String: e,
  };
  final epochs = {
    for (final e in (chronology['epochs'] as List).cast<Map<String, dynamic>>())
      e['id'] as String: (e['years'] as Map).cast<String, dynamic>(),
  };
  final mt = (chronology['traditions'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((t) => t['id'] == 'mt');
  final people = {
    for (final p in (tree['people'] as List).cast<Map<String, dynamic>>())
      p['id'] as String: p,
  };

  final creation = (timeline['_meta'] as Map)['creation'] as Map?;

  int am(String epoch) => (epochs[epoch]!['mt'] as num).toInt();
  int year(String id) => (events[id]!['year'] as num).toInt();

  test('the asset states a creation year, and what fixes it', () {
    expect(creation, isNotNull,
        reason: 'nothing else may compute this; it is written once');
    expect(creation!['basis'], 'scripture+thiele',
        reason: 'the intervals are stated and the year they are counted '
            'back from is not');
    final refs = (creation['datingRefs'] as List).cast<String>();
    // Six from `abram_called`'s own chain plus nineteen carried up
    // through Genesis 11, Genesis 7:6 and Genesis 5. Long, and honestly
    // so: a shorter list would hide which links the year depends on.
    expect(refs, hasLength(25));
    expect(refs.toSet(), hasLength(25), reason: 'a verse listed twice');
    expect(refs, contains('1 Kings 6:1'), reason: 'the anchor');
    expect(refs, contains('Genesis 5:3'), reason: 'the last link');
    expect(refs, contains('Genesis 11:10'), reason: 'Shem, two years after');
    expect(refs, contains('Genesis 7:6'), reason: 'the flood in Noah\'s 600th');
    expect(refs, containsAll(events['abram_called']!['datingRefs'] as List),
        reason: 'the chain must contain the chain it extends');
  });

  test('the creation year IS the chain, not a second convention', () {
    expect(creation!['year'], year('abram_called') - am('haran'));
    expect(creation['year'], -4114);
  });

  /// The proof that the two halves of the chain meet. These four years
  /// were in the asset before the anchor was extended and are NOT
  /// touched by it: if `creationYear + AM` did not reproduce them, the
  /// upward chain would be a different calendar wearing the same name.
  test('every year below Abraham falls out of the same arithmetic', () {
    final base = (creation!['year'] as num).toInt();
    expect(year('abram_called'), base + am('haran'));
    expect(year('israel_egypt'), base + am('descent'));
    expect(year('exodus'), base + am('exodus'));
    expect(year('moses_dies'), base + am('moses_death'));
  });

  test('the flood is the same year in both assets', () {
    final base = (creation!['year'] as num).toInt();
    expect(year('flood'), base + (mt['floodAm'] as num).toInt());
    expect(year('flood'), base + am('flood'));
    // Genesis 5 + 7:6, which is what the old Ussher block could not do.
    expect(year('flood') - (creation['year'] as int), 1656);
  });

  /// Every birth event added for a man `chronology.json` also carries
  /// must land on that file's own AM figure. This is the assertion that
  /// stops a lifespan arc and its own birth spoke printing two years
  /// for one man.
  test('every birth event equals its patriarch\'s Anno Mundi birth', () {
    final base = (creation!['year'] as num).toInt();
    // A PLAIN LOOKUP ON THE EVENT'S OWN LINK. `chronology.json` used to
    // spell these men as the Authorised Version does while the events'
    // `personIds` name them as `family_tree.json` does, so this join
    // needed the same five-entry alias table three other files each
    // wrote out — and without it four of the eight missed the lookup and
    // were dropped without a word. The chart's ids are the tree's now,
    // so the link IS the key. The count below stays pinned: that is what
    // makes a link quietly dropped fail here instead of shrinking the
    // loop in silence.
    final byId = {
      for (final p
          in (chronology['patriarchs'] as List).cast<Map<String, dynamic>>())
        p['id'] as String: p,
    };
    var checked = 0;
    for (final e in events.values) {
      final id = e['id'] as String;
      if (!id.endsWith('_born')) continue;
      final links = ((e['personIds'] as List?) ?? const []).cast<String>();
      if (links.length != 1) continue;
      final p = byId[links.single];
      if (p == null) continue;
      final figures = (p['figures'] as Map?)?['mt'] as Map?;
      final birthAm = (figures?['birthAm'] as num?)?.toInt();
      if (birthAm == null) continue;
      checked++;
      expect(e['year'], base + birthAm, reason: id);
    }
    // Seth and the seven added for the generations the wheel had no
    // record of. Pinned so a link quietly dropped cannot empty the loop.
    expect(checked, 8);
  });

  test('the family tree agrees with the same arithmetic', () {
    final base = (creation!['year'] as num).toInt();
    for (final row in const [
      ('adam', 0),
      ('noah', 1056),
      ('shem', 1558),
      ('terah', 1878),
    ]) {
      expect(people[row.$1]!['birthYear'], row.$2,
          reason: '${row.$1} is dated in Anno Mundi, not BC');
    }
    // And where the tree DOES carry BC, it is the same axis.
    expect(people['abraham']!['birthYear'], base + 1948);
    expect(people['moses']!['birthYear'], base + 2588);
    expect(people['aaron']!['birthYear'], base + 2585);
    expect(people['aaron']!['deathYear'], base + 2708);
  });

  /// THE AXIS HAS TO START BEFORE THE CREATION AND NOT LONG BEFORE IT.
  /// Below it, `angleForSpan` clamps the creation onto the rim and the
  /// wheel states a year nobody claims. Far below it, the whole chart
  /// pays angular resolution for empty centuries.
  test('the wheel axis holds the creation with room and not too much', () {
    final base = (creation!['year'] as num).toInt();
    expect(base, greaterThan(kMinYear));
    expect(base - kMinYear, lessThan(200));
    for (final e in events.values) {
      expect((e['year'] as num).toInt(), greaterThanOrEqualTo(kMinYear),
          reason: e['id'] as String);
      expect((e['year'] as num).toInt(), lessThanOrEqualTo(kMaxYear),
          reason: e['id'] as String);
    }
  });

  /// THE TEN OF GENESIS 4 GET NOTHING, AND THIS IS WHERE THAT IS KEPT.
  ///
  /// Genesis 4:17-24 gives them begettings, wives, trades and a boast,
  /// and not one age, interval or total. Their `family_tree.json` birth
  /// years (200, 300, 400, 500, 520, 540, 545) are round generational
  /// placeholders the file itself marks `conventional / approximate` —
  /// nothing to count along. So no event may carry one of them, and no
  /// year may be attached to one by any route.
  test('no Cainite reaches the timeline at all', () {
    const cainites = {
      'enoch_cain', 'irad', 'mehujael', 'methushael', 'lamech_cain',
      'adah', 'zillah', 'jabal', 'jubal', 'tubal_cain', 'naamah',
    };
    for (final e in events.values) {
      final links = ((e['personIds'] as List?) ?? const []).cast<String>();
      for (final id in links) {
        expect(cainites, isNot(contains(id)),
            reason: '${e['id']} would put $id on a dated axis');
      }
    }
    // And they are all still IN the app, on the page that needs no year.
    for (final id in cainites) {
      expect(people[id], isNotNull, reason: id);
      expect((people[id]!['dating'] as Map)['kind'], 'approximate',
          reason: id);
      expect(people[id]!['lifespan'], isNull,
          reason: '$id: the text states no figure for him');
    }
  });
}
