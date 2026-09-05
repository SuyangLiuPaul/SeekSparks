/// A LAYER'S SEARCH HIT MUST CARRY THE LAYER'S ID.
///
/// The rule is stated at [kLifespanLayerId]: a patriarch hit carries
/// the layer id "so the page's existing 'un-hide what you found' step
/// needs no special case". `_reveal` is that step — it does
/// `_hidden.remove(hit.streamId)` and nothing else.
///
/// The ministries did not follow the rule. Their hits carried the BAND
/// id, so searching out a ministry while its layer was switched off
/// un-hid the band — which was never hidden — left the layer off, and
/// then `_panTo` rebuilt the annulus without ministries, found no arc
/// and returned in silence. The reader got the sheet and a wheel that
/// did not move. Worse, `streamHidden` reported the band's state, so
/// the result row did not even warn that the layer was off.
///
/// This is the same shape as the defect the comment at
/// `wheel_search.dart:658` was written about, where the ministries
/// shipped a day before the search knew of them.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show kMaxYear;
import 'package:seeksparks/utils/wheel_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WheelHistoryData data;
  setUpAll(() async {
    data = await WheelHistoryService.instance.load();
  });

  List<WheelHit> hits(String q, {Set<String> hidden = const {}}) => searchWheel(
        data: data,
        query: q,
        locale: 'en',
        axisEnd: kMaxYear,
        hiddenStreams: hidden,
      ).hits;

  test('the fixture actually has ministries to find', () {
    expect(data.ministries, isNotEmpty,
        reason: 'no ministries in the asset — every assertion below would '
            'pass without testing anything');
  });

  test('every ministry hit names the ministry LAYER, not its band', () {
    // The bare wildcard returns every record of every kind, so this
    // covers all of them rather than the ones a chosen name happens to
    // reach.
    final ms = hits('*').where((h) => h.kind == WheelHitKind.ministry);
    expect(ms, isNotEmpty, reason: 'no ministry hits — nothing was tested');
    for (final h in ms) {
      expect(h.streamId, kMinistryLayerId,
          reason: '${h.id} carries "${h.streamId}" — `_reveal` would '
              'un-hide that instead of the ministries layer');
    }
  });

  test('with the layer off, the hit says so', () {
    final m = data.ministries.first;
    final off = hits(m.nameFor('en'), hidden: {kMinistryLayerId})
        .where((h) => h.kind == WheelHitKind.ministry && h.id == m.id);
    expect(off, isNotEmpty, reason: 'a hidden layer must still be findable');
    for (final h in off) {
      expect(h.streamHidden, isTrue,
          reason: 'the layer is off and the result row does not warn');
    }
    // And hiding the ministry's BAND must not be mistaken for hiding the
    // layer — that confusion is the defect itself.
    final bandOff = hits(m.nameFor('en'), hidden: {m.stream})
        .where((h) => h.kind == WheelHitKind.ministry && h.id == m.id);
    for (final h in bandOff) {
      expect(h.streamHidden, isFalse,
          reason: 'the ministries layer is on; only its band was hidden');
    }
  });

  // The patriarch half of this rule is already pinned next door, in
  // `wheel_lifespans_test.dart` ("the lives are searchable…"), which
  // asserts `streamId == kLifespanLayerId` outright. Not repeated here.
}
