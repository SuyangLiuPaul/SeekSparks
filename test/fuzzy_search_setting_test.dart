/// The switch that makes the fuzzy rungs reachable by a reader.
///
/// `fuzzy_search.dart` carries the switch and `AppSettings` carries the
/// persisted half — the same split `searchIgnoresPointing` has with
/// `search_folding.dart`. What is worth a test is not the getter but the
/// two things that split can get wrong: the default, and whether the
/// value reaches the switch the search actually reads.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/utils/fuzzy_search.dart' as fuzzy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => fuzzy.setFuzzySearchEnabled(false));

  test('a reader who has never touched it gets exact search', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.loadSettings();
    expect(s.fuzzySearch, isFalse);
    expect(fuzzy.fuzzySearchEnabled, isFalse,
        reason: 'the persisted half must push its default into the switch '
            'too, or the first search of a session reads a stale global');
  });

  test(
      'turning it on reaches the switch the search reads, not just the '
      'settings page', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.loadSettings();
    await s.setFuzzySearch(true);
    expect(fuzzy.fuzzySearchEnabled, isTrue);
    await s.setFuzzySearch(false);
    expect(fuzzy.fuzzySearchEnabled, isFalse);
  });

  test('it survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = AppSettings();
    await first.loadSettings();
    await first.setFuzzySearch(true);

    final second = AppSettings();
    await second.loadSettings();
    expect(second.fuzzySearch, isTrue);
    expect(fuzzy.fuzzySearchEnabled, isTrue);
  });

  test('reset puts it back off, and puts the switch back with it', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.loadSettings();
    await s.setFuzzySearch(true);
    await s.resetAllSettings();
    expect(s.fuzzySearch, isFalse);
    expect(fuzzy.fuzzySearchEnabled, isFalse);
  });
}
