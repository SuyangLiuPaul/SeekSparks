// 2026-06-14 (v1.3.70): guards the iOS/Android/macOS themed-icon mapping.
//
// Regression: variantForColor used `color == Colors.red` (identity).
// The picker passes a MaterialColor const, but the colour restored from
// SharedPreferences on every launch is a plain `Color` whose `==` against
// a MaterialColor is false — so the startup icon re-apply mapped every
// colour to "no variant" and silently reverted the icon to primary.
// The fix compares by ARGB value, which must work for BOTH forms.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/app_icon_service.dart';

void main() {
  group('AppIconService.variantForColor', () {
    test('maps MaterialColor consts (the picker path)', () {
      expect(AppIconService.variantForColor(Colors.red), 'Red');
      expect(AppIconService.variantForColor(Colors.deepOrange), 'Red');
      expect(AppIconService.variantForColor(Colors.orange), 'Orange');
      expect(AppIconService.variantForColor(Colors.teal), 'Green');
      expect(AppIconService.variantForColor(Colors.indigo), 'Purple');
      expect(AppIconService.variantForColor(Colors.pink), 'Pink');
      expect(AppIconService.variantForColor(Colors.grey), 'Dark');
    });

    test('maps plain Colors restored from prefs (the startup path)', () {
      // Simulate SharedPreferences round-trip: store toARGB32(), reload
      // as a plain Color. This is what broke before the value-compare fix.
      Color restored(Color c) => Color(c.toARGB32());
      expect(AppIconService.variantForColor(restored(Colors.red)), 'Red');
      expect(AppIconService.variantForColor(restored(Colors.amber)), 'Orange');
      expect(AppIconService.variantForColor(restored(Colors.green)), 'Green');
      expect(
          AppIconService.variantForColor(restored(Colors.deepPurple)), 'Purple');
      expect(AppIconService.variantForColor(restored(Colors.pink)), 'Pink');
      expect(AppIconService.variantForColor(restored(Colors.blueGrey)), 'Dark');
    });

    // 2026-09-13. This test used to assert the opposite — that the blue
    // family fell through to "no variant" — and that rule was wrong in
    // this fork. It is inherited from YsWords, where THE DEFAULT ICON IS
    // BLUE, so "blue → default" put a blue mark on a blue theme. This
    // app's default icon has been RED since 2026-08-31, so the same line
    // handed every blue-themed reader a red logo. The owner reported it
    // as 「为什么这个 logo 颜色没有跟着主题颜色变」: indigo app name,
    // red mark.
    test('the blue family lands on the nearest mark, not the red default',
        () {
      expect(AppIconService.variantForColor(Colors.lightBlue), 'Purple');
      expect(AppIconService.variantForColor(Colors.blue), 'Purple');
      // Cyan is on the green side of the band edge, which is where a
      // reader would put it if asked to choose between these six.
      expect(AppIconService.variantForColor(Colors.cyan), 'Green');
      // Plain-Color form too.
      expect(AppIconService.variantForColor(Color(Colors.blue.toARGB32())),
          'Purple');
    });

    test('a colour no swatch can produce still follows the theme', () {
      // The case that made this visible: an indigo restored from an
      // older build, which no current swatch can produce and which the
      // exact-match list therefore sent to the default icon.
      expect(AppIconService.variantForColor(const Color(0xFF3730A3)),
          'Purple');
      // And one from nowhere near the palette at all.
      expect(AppIconService.variantForColor(const Color(0xFF00FF7F)), 'Green');
    });

    test('the neutrals are the mark with no hue in it', () {
      // brown 0.25, blueGrey 0.18, grey 0.00 — all under the saturation
      // floor; `Colors.green` at 0.39 is the least saturated colour that
      // must still read as its own hue, and it does.
      for (final c in [Colors.brown, Colors.grey, Colors.blueGrey]) {
        expect(AppIconService.variantForColor(c), 'Dark', reason: '$c');
      }
      expect(AppIconService.variantForColor(Colors.green), 'Green');
    });

    // SeekSparks fork: the app's own brand blue (swatch 0 / the default
    // AppSettings.primaryColor) must also fall through to "no variant" —
    // it's a distinct value from Colors.indigo (which maps to 'Purple'),
    // so this isn't automatically covered by the existing indigo case
    // above and is worth its own regression guard.
    test('SeekSparks default brand colour maps to the primary icon', () {
      expect(AppIconService.variantForColor(AppIconService.kDefaultPrimaryColor),
          isNull);
      expect(
          AppIconService.variantForColor(
              Color(AppIconService.kDefaultPrimaryColor.toARGB32())),
          isNull);
    });
  });
}
