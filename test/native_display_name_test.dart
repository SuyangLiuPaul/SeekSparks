/// The home-screen name, which is carried by seven files and was
/// renamed in five of them.
///
/// `8613b3a` (2026-08-25, "rename: Yahweh's Swords -> Yahweh's Sword
/// (owner-requested, singular)") changed the display name in eleven
/// files and touched **zero** `.lproj` files. So
/// `ios/Runner/en.lproj/InfoPlist.strings` kept the plural, and it is
/// not a dead file: `en` sits in the project's `knownRegions` and in
/// the `InfoPlist.strings` variant group that the Runner target copies
/// in its Resources phase, and a localized `InfoPlist.strings`
/// OVERRIDES `Info.plist`. The result, for eleven days: an English
/// iPhone read "Yahweh's Swords" off the home screen while the Android
/// phone beside it read "Yahweh's Sword", and every document describing
/// the rename said it was done.
///
/// This is the failure `brand_marks_test.dart` exists for, one asset
/// class over — "the mark changed and only some of the files carrying
/// it were regenerated". Same remedy: derive nothing, compare
/// everything.
///
/// NOT asserted here: the bundle id / applicationId. Those are
/// `com.example.yahwehswords` and must STAY — Android treats a changed
/// applicationId as a different app and would orphan every installed
/// copy. See docs/OPEN-ITEMS.md.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Apostrophes are not the subject. Android's `strings.xml` writes
  /// the name with `&#8217;` (U+2019, a typographer's apostrophe) and
  /// the Apple plists write an ASCII `'`; both render as the same word
  /// and neither is wrong. Folding them keeps this test on the
  /// question it is asking — singular or plural — instead of failing
  /// on punctuation nobody can see at 60 px.
  String fold(String s) =>
      s.replaceAll('’', "'").replaceAll('&#8217;', "'").trim();

  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path has moved');
    return f.readAsStringSync();
  }

  /// The value of `key` in an Apple plist, as written.
  String plistString(String path, String key) {
    final src = read(path);
    final m = RegExp('<key>${RegExp.escape(key)}</key>\\s*<string>(.*?)</string>',
            dotAll: true)
        .firstMatch(src);
    expect(m, isNotNull, reason: '$key is missing from $path');
    return fold(m!.group(1)!);
  }

  /// The value of `key` in a `.strings` file.
  String stringsValue(String path, String key) {
    final src = read(path);
    final m = RegExp('"${RegExp.escape(key)}"\\s*=\\s*"(.*?)"\\s*;')
        .firstMatch(src);
    expect(m, isNotNull, reason: '$key is missing from $path');
    return fold(m!.group(1)!);
  }

  /// The value of an Android string resource.
  String androidString(String path, String name) {
    final src = read(path);
    final m = RegExp('<string name="${RegExp.escape(name)}">(.*?)</string>',
            dotAll: true)
        .firstMatch(src);
    expect(m, isNotNull, reason: '$name is missing from $path');
    return fold(m!.group(1)!);
  }

  test('every English carrier of the display name agrees', () {
    final infoPlist = plistString('ios/Runner/Info.plist', 'CFBundleDisplayName');
    final iosEn = stringsValue(
        'ios/Runner/en.lproj/InfoPlist.strings', 'CFBundleDisplayName');
    final android =
        androidString('android/app/src/main/res/values/strings.xml', 'app_name');
    final manifest =
        jsonDecode(read('web/manifest.json')) as Map<String, dynamic>;

    // Pinned rather than merely compared: three files agreeing on the
    // WRONG name is the state this test was written to end, and a
    // pure cross-check would have passed on it.
    expect(infoPlist, "Yahweh's Sword");
    expect(iosEn, infoPlist,
        reason: 'a localized InfoPlist.strings OVERRIDES Info.plist, so an '
            'English device shows THIS one. It carried the pre-8613b3a '
            'plural for eleven days after the rename.');
    expect(android, infoPlist,
        reason: 'the Android launcher label must read the same as the iOS '
            'home screen');
    expect(fold(manifest['name'] as String), infoPlist);
    expect(fold(manifest['short_name'] as String), infoPlist);
  });

  test('the Chinese carriers agree, script by script', () {
    // Simplified: the iOS locale file and every Android bucket that is
    // Simplified. `values-zh` is the legacy catch-all and is Simplified
    // by convention here.
    final iosHans = stringsValue(
        'ios/Runner/zh-Hans.lproj/InfoPlist.strings', 'CFBundleDisplayName');
    for (final path in const [
      'android/app/src/main/res/values-zh-rCN/strings.xml',
      'android/app/src/main/res/values-zh/strings.xml',
    ]) {
      expect(androidString(path, 'app_name'), iosHans, reason: path);
    }

    final iosHant = stringsValue(
        'ios/Runner/zh-Hant.lproj/InfoPlist.strings', 'CFBundleDisplayName');
    for (final path in const [
      'android/app/src/main/res/values-zh-rTW/strings.xml',
      'android/app/src/main/res/values-zh-rHK/strings.xml',
    ]) {
      expect(androidString(path, 'app_name'), iosHant, reason: path);
    }

    // The two scripts must NOT be the same string — a build that
    // shipped Simplified to a 繁體 device would pass every check above.
    expect(iosHans, isNot(iosHant));
  });

  test('the English name is singular, which is what the owner asked for',
      () {
    // The specific regression, named. `8613b3a` is the commit; if the
    // owner ever reverts to the plural this fails and points at the
    // decision rather than looking like a typo.
    for (final path in const [
      'ios/Runner/Info.plist',
      'ios/Runner/en.lproj/InfoPlist.strings',
      'android/app/src/main/res/values/strings.xml',
      'web/manifest.json',
      'web/index.html',
    ]) {
      expect(read(path), isNot(contains("Swords")),
          reason: '$path carries the plural the 2026-08-25 rename removed');
    }
  });

  test('the localized files are actually built into the iOS app', () {
    // Without this the test above is satisfiable by a file that never
    // ships, which would make it a check on a document rather than on
    // the app. `en` must be a known region AND a child of the
    // InfoPlist.strings variant group.
    final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
    final regions = RegExp(r'knownRegions = \(([\s\S]*?)\);').firstMatch(pbx);
    expect(regions, isNotNull);
    for (final r in const ['en', 'zh-Hans', 'zh-Hant']) {
      expect(regions!.group(1), contains(r), reason: '$r is not a known region');
    }
    final group =
        RegExp(r'isa = PBXVariantGroup;[\s\S]*?name = InfoPlist\.strings;')
            .firstMatch(pbx);
    expect(group, isNotNull,
        reason: 'the InfoPlist.strings variant group has gone; the localized '
            'home-screen names are no longer being built');
    for (final r in const ['en', 'zh-Hans', 'zh-Hant']) {
      expect(group!.group(0), contains(r));
    }
  });
}
