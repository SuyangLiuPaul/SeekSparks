/// #274 — what the workbench warms before its centre pane exists.
///
/// The runner itself touches assets and SharedPreferences, so the part
/// worth pinning is the decision: WHICH corpora the Browse stack will
/// ask for that are not already in memory. Getting that wrong is not a
/// crash — it is either a silent re-parse of a 7 MB file the app is
/// already holding, or several megabytes of mobile data spent on a pane
/// the reader is not looking at. Neither shows up in a screenshot.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/workbench_warmup.dart';

void main() {
  List<String> order({
    bool parallelMode = true,
    String reading = 'nasb',
    List<String> parallel = const ['bsb', 'nasb', 'kjv'],
    Set<String> cached = const {},
  }) =>
      browseWarmupOrder(
        parallelMode: parallelMode,
        readingVersion: reading,
        parallelVersions: parallel,
        isCached: cached.contains,
      );

  group('browseWarmupOrder', () {
    test('warms the comparison editions in the order they are displayed',
        () {
      expect(order(parallel: const ['bsb', 'kjv', 'leb']),
          ['bsb', 'kjv', 'leb']);
    });

    test('never warms the reading version — setVerses already cached it',
        () {
      // The whole point of #274: the Browse window used to re-download
      // and re-parse the edition already on screen.
      expect(order(reading: 'nasb', parallel: const ['bsb', 'nasb', 'kjv']),
          ['bsb', 'kjv']);
    });

    test('is case-insensitive about the reading version', () {
      expect(order(reading: 'NASB', parallel: const ['nasb', 'kjv']),
          ['kjv']);
    });

    test('skips anything already in the corpus cache', () {
      expect(
        order(parallel: const ['bsb', 'kjv', 'leb'], cached: {'kjv'}),
        ['bsb', 'leb'],
      );
    });

    test('does nothing at all when the centre pane is the chapter reader',
        () {
      // That pane renders from MainProvider.verses. Warming comparison
      // editions for it would be exactly the speculative mobile-data
      // cost that v1.3.61 disabled eager preloading to avoid.
      expect(order(parallelMode: false), isEmpty);
    });

    test('asks for each edition once even when listed twice', () {
      expect(order(parallel: const ['bsb', 'bsb', 'kjv']), ['bsb', 'kjv']);
    });

    test('ignores empty entries rather than requesting "assets/.json"', () {
      expect(order(parallel: const ['', 'kjv']), ['kjv']);
    });

    test('an empty stack asks for nothing', () {
      expect(order(parallel: const []), isEmpty);
    });
  });

  group('defaultParallelVersions', () {
    test('matches what the workbench page falls back to per locale', () {
      // These two must agree or the warm-up loads editions the page
      // then does not display, and the pane still starts cold.
      expect(defaultParallelVersions('zh-Hans'),
          const ['cuvs-yhwh', 'biblexg-v2', 'bsb']);
      expect(defaultParallelVersions('zh-Hant'),
          const ['cuvs-yhwh-tr', 'biblexg-v2-tr', 'bsb']);
      expect(defaultParallelVersions('en'), const ['bsb', 'nasb', 'kjv']);
    });

    test('an unknown locale gets the English stack, not an empty one', () {
      expect(defaultParallelVersions('fr'), isNotEmpty);
    });
  });

  group('preference keys', () {
    test('are the exact strings already on disk in existing installs', () {
      // Renaming either of these silently resets every reader's Browse
      // stack. The `.v2` suffix on the mode key is deliberate history —
      // see the comment where WorkbenchPage restores it.
      expect(kWorkbenchParallelModeKey, 'workbench.browseMode.v2');
      expect(kWorkbenchParallelVersionsKey, 'workbench.parallelVersions');
    });
  });
}
