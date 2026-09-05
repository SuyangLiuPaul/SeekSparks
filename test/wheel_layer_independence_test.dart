/// EACH ARC LAYER ANSWERS FOR ITSELF.
///
/// The annulus carries three separate claims — the Genesis lifespans,
/// the 42 reigns and the 44 ministries — and the filter sheet offers a
/// separate switch for each, with a comment saying why: "separate
/// switches because they are separate kinds of claim".
///
/// Until 2026-09-05 that was not what happened. `_buildLifespans`
/// returned early the moment the LIFESPAN layer was hidden, before it
/// had even gathered the kings, so `_packBand` never saw them.
/// Unchecking "Genesis lifespans" therefore also erased 42 reign arcs,
/// 44 ministry arcs and — because the genealogy rail sizes itself from
/// the arc rings — all 107 rail marks, while the three checkboxes for
/// those layers went on rendering as ticked. The reader was told three
/// layers were on and shown none of them.
///
/// It reached production because the coupling is invisible from either
/// side: `wheel_lineage_rail_test.dart` is entirely pure and never
/// opens the filter sheet, and `wheel_lifespans_test.dart` only ever
/// toggles the lifespan layer while looking at lifespans.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show packWheelBand, kKingArcPrefix, kMinistryArcPrefix;
import 'package:seeksparks/services/hebrew_kings_service.dart'
    show HebrewKingsData;
import 'package:seeksparks/utils/radial_chronology_layout.dart';

late final ChronologyData chron;
late final List<HebrewKing> kings;
late final List<WheelMinistry> ministries;
late final int creation;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    chron = ChronologyData.fromJson(
        jsonDecode(File('assets/chronology.json').readAsStringSync())
            as Map<String, dynamic>);
    kings = HebrewKingsData.fromJson(
            jsonDecode(File('assets/hebrew_kings.json').readAsStringSync())
                as Map<String, dynamic>)
        .kings;
    ministries =
        ((jsonDecode(File('assets/wheel_history.json').readAsStringSync())
                    as Map<String, dynamic>)['ministries'] as List)
            .cast<Map<String, dynamic>>()
            .map(WheelMinistry.fromJson)
            .toList();
    creation = ((jsonDecode(
                File('assets/bible_timeline.json').readAsStringSync())
            as Map<String, dynamic>)['_meta'] as Map<String, dynamic>)['creation']
        ['year'] as int;
  });

  List<LifeArc> band({required bool patriarchs}) => packWheelBand(
        chron: chron,
        creationYear: creation,
        kings: kings,
        ministries: ministries,
        includePatriarchs: patriarchs,
      );

  int countWith(List<LifeArc> arcs, String prefix) =>
      arcs.where((a) => a.id.startsWith(prefix)).length;

  test('hiding the patriarchs leaves every reign and every ministry', () {
    final all = band(patriarchs: true);
    final without = band(patriarchs: false);

    expect(countWith(all, kKingArcPrefix), greaterThan(0),
        reason: 'the fixture has no reigns — the test proves nothing');
    expect(countWith(all, kMinistryArcPrefix), greaterThan(0),
        reason: 'the fixture has no ministries — the test proves nothing');

    expect(countWith(without, kKingArcPrefix), countWith(all, kKingArcPrefix),
        reason: 'reign arcs vanished with the patriarch layer');
    expect(countWith(without, kMinistryArcPrefix),
        countWith(all, kMinistryArcPrefix),
        reason: 'ministry arcs vanished with the patriarch layer');
  });

  test('hiding the patriarchs removes the patriarch arcs and only those', () {
    final without = band(patriarchs: false);
    expect(without, isNotEmpty,
        reason: 'the whole annulus went empty — this is the 2026-09-05 bug');
    for (final a in without) {
      final isLayered = a.id.startsWith(kKingArcPrefix) ||
          a.id.startsWith(kMinistryArcPrefix);
      expect(isLayered, isTrue,
          reason: '${a.id} is a patriarch arc drawn while that layer is off');
    }
  });

  test('the rail can still size itself when the patriarchs are hidden', () {
    // The rail derives its ring from the arcs that ARE drawn. With the
    // patriarchs off it must still find some, or 107 marks disappear
    // for a reason nothing on screen explains.
    expect(lifeArcRingCount(band(patriarchs: false)), greaterThan(0));
  });

  test('with the patriarchs on, nothing about the old packing moved', () {
    // Defence against fixing the layer bug by repacking the band: the
    // arcs a reader already knows must stay exactly where they were.
    final all = band(patriarchs: true);
    expect(all.length,
        countWith(all, kKingArcPrefix) + countWith(all, kMinistryArcPrefix) + 25,
        reason: 'the 25 Genesis lifespans plus the two layered sets is the '
            'whole annulus; a different total means the packing changed');
  });
}
