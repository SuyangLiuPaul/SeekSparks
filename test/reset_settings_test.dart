/// "Reset settings" — 2026-09-18.
///
/// Six search and display preferences were reset in memory but never
/// purged from storage, so they came back on the next launch; and the
/// projector's layout was purged from storage but left on screen until
/// a restart. Both halves are pinned here: after a reset, a fresh load
/// sees the defaults, and the live object already shows them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_sword/constants/projection_setup.dart';
import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/utils/cross_version_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a reset survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.loadSettings();
    await s.setReadingPaperTheme(true);
    await s.setCrossVersionSearchMode(CrossVersionSearchMode.sameLanguage);
    await s.setSearchIgnoresPointing(false);
    await s.setFuzzySearch(true);
    await s.setExcludeKetivFromSearch(true);
    await s.setExcludeQereFromSearch(true);

    await s.resetAllSettings();

    final after = AppSettings();
    await after.loadSettings();
    expect(after.readingPaperTheme, isFalse);
    expect(after.crossVersionSearchMode, CrossVersionSearchMode.currentOnly);
    expect(after.searchIgnoresPointing, isTrue);
    expect(after.fuzzySearch, isFalse);
    expect(after.excludeKetivFromSearch, isFalse);
    expect(after.excludeQereFromSearch, isFalse);
  });

  test('the projector layout resets on screen, not only in storage',
      () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await s.loadSettings();
    await s.setProjectionLayout(ProjectionLayout.devotional);
    expect(s.projectionLayout, ProjectionLayout.devotional);

    await s.resetAllSettings();
    expect(s.projectionLayout, ProjectionLayout.standard);
  });
}
