import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/app_icon_service.dart';

/// Regression guard for the forward-migration in
/// `AppSettings.loadSettings` — untested until now, which is how the
/// SECOND generation of it (kLegacyPrimaryColor2, added 2026-08-25 when
/// the icon's actual ink was measured and kDefaultPrimaryColor moved
/// again) could be added with no test proving the chain still works.
///
/// The bug this exists to prevent: a reader who never touched the
/// colour picker gets silently stuck on a shipped default that no
/// longer describes the app's own icon, because the stored value
/// equality check only matched ONE retired default and the new one
/// slipped past it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Color> loadedColorFor(int? stored) async {
    SharedPreferences.setMockInitialValues(
        stored == null ? {} : {'primaryColor': stored});
    final s = AppSettings();
    await s.loadSettings();
    return s.primaryColor;
  }

  test('a reader with no stored colour gets today\'s default', () async {
    final c = await loadedColorFor(null);
    expect(c.toARGB32(), AppIconService.kDefaultPrimaryColor.toARGB32());
  });

  test(
      'the original (2026-08-06 and earlier) shipped default migrates '
      'forward', () async {
    final c =
        await loadedColorFor(AppIconService.kLegacyPrimaryColor.toARGB32());
    expect(c.toARGB32(), AppIconService.kDefaultPrimaryColor.toARGB32());
  });

  test(
      'the interim (2026-08-06 to 2026-08-25) shipped default also '
      'migrates forward', () async {
    final c =
        await loadedColorFor(AppIconService.kLegacyPrimaryColor2.toARGB32());
    expect(c.toARGB32(), AppIconService.kDefaultPrimaryColor.toARGB32());
  });

  test('a colour the reader actually picked is left alone', () async {
    final c = await loadedColorFor(Colors.pink.toARGB32());
    expect(c.toARGB32(), Colors.pink.toARGB32());
  });
}
