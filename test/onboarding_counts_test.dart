/// The first numbers a new reader is ever shown, checked against the
/// assets those numbers are about.
///
/// 2026-09-02. This file exists because the same defect shipped twice in
/// one day, and neither time did anything fail.
///
///   * The onboarding slide said the library holds **587** sermons. It
///     holds 289. 587 has no source at all — it is a mis-transcribed
///     part count (the 289 records list 589 audio parts). It survived a
///     pass that corrected the same number in the offline-pack rows,
///     because the pass was written against `offline_pack_service.dart`
///     and these strings live somewhere else. Fixed in `f831a93`.
///   * The same slide said the Bible Timeline holds **98** events. That
///     was true when it was written and stopped being true hours later,
///     when seven Genesis 5 births went into `bible_timeline.json` and
///     took it to 105. Nothing failed then either; the number is prose,
///     and prose is exactly what the rest of this suite cannot see.
///
/// The lesson both times is the same: a count written into a sentence
/// is a claim about an asset, and it goes stale the moment the asset
/// moves. So this file derives every one of them from the asset and
/// compares, rather than pinning a literal that would need the same
/// hand-edit the strings do.
///
/// It deliberately reads the SHIPPED assets off disk rather than any
/// service, because what is on trial is what a reader is told about the
/// files that are actually in the build.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/ui_strings.dart';

/// Every locale the onboarding strings carry, so a count corrected in
/// English but missed in 简 or 繁 still fails.
const _locales = <String>['zh-Hans', 'zh-Hant', 'en'];

int _listLen(String path, [String? key]) {
  final raw = jsonDecode(File(path).readAsStringSync());
  final list = key == null ? raw : (raw as Map<String, dynamic>)[key];
  return (list as List).length;
}

/// The digit groups in [s], as integers — so a sentence can be searched
/// for a number without a regex that also matches "1.6.204" or a year
/// inside a title.
Set<int> _numbersIn(String s) => RegExp(r'\d+')
    .allMatches(s)
    .map((m) => int.parse(m.group(0)!))
    .toSet();

void main() {
  late final int sermons;
  late final int timelineEvents;
  late final int people;
  late final int evidences;

  setUpAll(() {
    sermons = _listLen('assets/sermons/index.json');
    timelineEvents = _listLen('assets/bible_timeline.json', 'events');
    people = _listLen('assets/family_tree.json', 'people');
    evidences = _listLen('assets/bible_evidence.json', 'evidences');
  });

  test('the sermon slide quotes the number of sermons that ship', () {
    for (final locale in _locales) {
      final body = uiStrings['onboardSermonsBody']![locale]!;
      expect(_numbersIn(body), contains(sermons),
          reason: 'the $locale sermon slide does not say $sermons: $body');
      // The old wrong number, named so a revert is loud rather than
      // quiet. 587 is not a count of anything in this repo.
      expect(_numbersIn(body), isNot(contains(587)));
    }
  });

  test('the Discover slide quotes all three counts it claims', () {
    for (final locale in _locales) {
      final body = uiStrings['onboardDiscoverBody']![locale]!;
      final got = _numbersIn(body);
      expect(got, contains(timelineEvents),
          reason: 'the $locale Discover slide does not say $timelineEvents '
              'timeline events: $body');
      expect(got, contains(people),
          reason: 'the $locale Discover slide does not say $people people');
      expect(got, contains(evidences),
          reason: 'the $locale Discover slide does not say $evidences '
              'evidence records');
    }
  });

  test('the dialog\'s own fallback strings say the same thing', () {
    // `onboarding_dialog.dart` repeats each body as a `??` fallback for
    // a locale the map does not hold. They are separate literals and
    // have drifted before, so they are read as text rather than trusted.
    final src = File('lib/widgets/onboarding_dialog.dart').readAsStringSync();
    for (final n in <int>[sermons, timelineEvents, people, evidences]) {
      expect(src, contains('$n'),
          reason: 'no fallback string in onboarding_dialog.dart says $n');
    }
    expect(src, isNot(contains('587')));
    expect(src, isNot(contains('98 events')));
  });
}
