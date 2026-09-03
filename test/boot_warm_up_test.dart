/// WHAT THE SPLASH WARMS, AND FOR WHOM.
///
/// Two boot lists, and both had gone stale in the same way — a Bible
/// was hidden from the interface, taken out of a list on that ground,
/// and not put back when it returned.
///
///   * `assets/leb.json` left `_bibleUrls` in the offline pack and the
///     eager-preload candidates on 2026-09-02, correctly: nothing could
///     open it. The LEB was back on offer the same afternoon and
///     neither list followed until 2026-09-03.
///   * `assets/nasb.json` is still hidden and stays out of both, which
///     is the control: this is not "put everything back", it is "the
///     lists follow `disabledVersions`".
///
/// The wheel warm-up is the other half. `wheel_history.json` is 131 KB
/// and its service also awaits the timeline, the family tree, the kings
/// and the chronology; on a cold `#/wheel` none of that starts until
/// the route is pushed, so the reader who followed a shared link sees
/// Genesis 1 first. Warming it for everyone would be the obvious fix
/// and the wrong one — most readers never open the wheel — so the boot
/// URL decides, through the same `pageForUrlPath` the router uses.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/utils/page_links.dart';

late final String mainSrc;
late final String offlineSrc;

void main() {
  setUpAll(() {
    mainSrc = File('lib/main.dart').readAsStringSync();
    offlineSrc =
        File('lib/services/offline_pack_service.dart').readAsStringSync();
  });

  test('the preload candidates follow disabledVersions, both ways', () {
    // The block is small enough to read as text, and reading it as text
    // is the point: a test that imported the list would pass on a list
    // that had drifted from the catalog.
    final start = mainSrc.indexOf('const candidates = <String>[');
    expect(start, isNot(-1));
    final block = mainSrc.substring(start, mainSrc.indexOf('];', start));

    for (final hidden in disabledVersions) {
      expect(block, isNot(contains("'$hidden'")),
          reason: '$hidden is hidden from the interface, so every second '
              'spent parsing it on the splash is spent on nothing');
    }
    // ...and the one that came back is warmed like any other edition a
    // reader can choose.
    expect(block, contains("'leb'"),
        reason: 'the LEB is on offer again and is not preloaded');
    expect(block, contains("'bsb'"));
    expect(block, contains("'kjv'"));
  });

  test('the offline pack agrees with the same list', () {
    // Two lists, one rule. They drifted apart for a day and this is
    // what would have caught it.
    for (final hidden in disabledVersions) {
      expect(offlineSrc, isNot(contains("'assets/$hidden.json'")),
          reason: '$hidden is hidden and would be downloaded anyway');
    }
    expect(offlineSrc, contains("'assets/leb.json'"));
  });

  test('the wheel is warmed only when the boot URL asks for a page', () {
    // The guard is `pageForUrlPath`, the router's own function, so the
    // warm-up cannot fire for a path the router would not open — or
    // miss one it would.
    expect(mainSrc, contains('WheelHistoryService.instance.load()'));
    final at = mainSrc.indexOf('WheelHistoryService.instance.load()');
    final before = mainSrc.substring(0, at);
    expect(before.lastIndexOf('pageForUrlPath'), greaterThan(
        before.lastIndexOf('warmWorkbenchFirstPaint')),
        reason: 'the wheel warm-up is not behind the page-path check, so '
            'every reader pays 131 KB for a page most never open');

    // And the function it is guarded by really does distinguish them.
    expect(pageForUrlPath('/wheel'), isNotNull);
    expect(pageForUrlPath('/genesis/1:1'), isNull);
    expect(pageForUrlPath(null), isNull);
    expect(pageForUrlPath(''), isNull);
  });
}
