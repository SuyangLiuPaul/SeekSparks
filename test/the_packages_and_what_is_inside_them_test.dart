/// The release packages carry the app's name — outside AND inside.
///
/// 2026-09-18. 「这三个release包可以是Yahweh words Yahweh sword之类的吗而
/// 不是类似于seeksparks.apk之类的」. Renaming the assets is the easy half
/// and it was done first; the half that was missed is that a reader who
/// downloaded `Yahwehs-Sword-Windows-x64-v1.6.315.zip` unzipped a folder
/// called `SeekSparks` with `yswords.exe` inside it, and the macOS zip
/// expanded to `yahwehswords.app` — a third name again, none of them the
/// one on the download button.
///
/// Two contracts are pinned here, because breaking either one is silent:
///
///   * the FILENAME still carries the substring the updater matches on.
///     The matcher never parses the product token, which is exactly what
///     made the rename safe — this test is what keeps that true. Rename
///     `…-macOS-…` to `…-Mac-…` and every macOS reader's in-app update
///     quietly falls back to the release web page.
///
///   * the BINARY inside carries the same name as the package, and the
///     release note tells the reader to run the name the build actually
///     produces. `PRODUCT_NAME` / `BINARY_NAME` and the note are four
///     files apart; nothing but this test reads them together.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/services/update_service.dart';

/// What the app's packages are called. One place, so a future rename
/// fails here loudly rather than in a reader's download folder.
const String kProduct = 'Yahwehs-Sword';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue,
      reason: '$path is gone — this test would otherwise pass by reading '
          'nothing');
  return file.readAsStringSync();
}

/// The one package filename a workflow stages, whether it spells it in
/// bash (`pkg="…"`) or in PowerShell (`$zip = "…"`).
String _packageName(String workflow) {
  final yaml = _read('.github/workflows/$workflow');
  final matches = [
    ...RegExp(r'pkg="([^"]+)"').allMatches(yaml),
    ...RegExp(r'\$zip\s*=\s*"([^"]+)"').allMatches(yaml),
  ].map((m) => m.group(1)!).toSet();
  expect(matches, hasLength(1),
      reason: '$workflow stages $matches — this test can only pin one');
  return matches.single;
}

void main() {
  const needles = <String, String>{
    'release-android.yml': '.apk',
    'release-windows.yml': 'Windows',
    'release-macos.yml': 'macOS',
    'release-linux.yml': 'Linux',
  };

  group('the filename carries what the updater matches on', () {
    for (final entry in needles.entries) {
      test('${entry.key} produces a ${entry.value} asset named for the app',
          () {
        final pkg = _packageName(entry.key);
        expect(pkg, startsWith('$kProduct-'),
            reason: '$pkg is not named for this app');
        expect(pkg, contains(entry.value),
            reason: '$pkg no longer contains "${entry.value}", so the '
                'picker will not find it and the in-app update will fall '
                'back to the release page');
      });
    }

    test('the needles are still the ones the picker uses', () {
      // The other side of the contract. If someone changes the picker to
      // match on `Win64`, the tests above keep passing against a
      // filename no reader's app will ever select.
      final source = _read('lib/services/update_service.dart');
      for (final needle in needles.values) {
        expect(source, contains("'$needle'"),
            reason: 'update_service.dart no longer matches on "$needle"');
      }
    });

    test('androidAssetUrl picks the renamed apk, by flavour', () {
      // Behaviour, not text: the real matcher against the real new
      // filenames. The intl phone must take the plain one and the cn
      // phone the `-cn` one — an app installed with one application id
      // cannot update from an apk built with the other.
      final assets = [
        {
          'name': '$kProduct-Android-v1.6.316-cn.apk',
          'browser_download_url': 'https://example.invalid/cn.apk',
        },
        {
          'name': '$kProduct-Android-v1.6.316.apk',
          'browser_download_url': 'https://example.invalid/intl.apk',
        },
        {
          'name': '$kProduct-Windows-x64-v1.6.316.zip',
          'browser_download_url': 'https://example.invalid/win.zip',
        },
      ];
      expect(UpdateService.androidAssetUrl(assets, cnFlavour: false),
          'https://example.invalid/intl.apk');
      expect(UpdateService.androidAssetUrl(assets, cnFlavour: true),
          'https://example.invalid/cn.apk');
    });

    test('androidAssetUrl takes no apk at all rather than the wrong one', () {
      // The release that carries only the intl build, read by a cn
      // phone. Null sends the reader to the release page; the wrong apk
      // would be a download that ends in 「应用未安装」.
      final intlOnly = [
        {
          'name': '$kProduct-Android-v1.6.316.apk',
          'browser_download_url': 'https://example.invalid/intl.apk',
        },
      ];
      expect(UpdateService.androidAssetUrl(intlOnly, cnFlavour: true), isNull);
    });
  });

  group('the binary inside carries the same name', () {
    test('Windows: the folder, the exe and the note agree', () {
      expect(_read('windows/CMakeLists.txt'),
          contains('set(BINARY_NAME "$kProduct")'));
      final yaml = _read('.github/workflows/release-windows.yml');
      expect(yaml, contains('staging/$kProduct'),
          reason: 'the zip would expand to a folder with another name');
      expect(yaml,
          contains(r'run \`' '$kProduct' r'\\' '$kProduct' r'.exe\`'),
          reason: 'the release note points at an exe this build does not '
              'produce');
    });

    test('Linux: the binary and the note agree', () {
      expect(_read('linux/CMakeLists.txt'),
          contains('set(BINARY_NAME "$kProduct")'));
      expect(_read('.github/workflows/release-linux.yml'),
          contains(r'run \`./' '$kProduct' r'\`'),
          reason: 'the release note points at a binary this build does not '
              'produce');
    });

    test('macOS: the bundle and the note agree', () {
      expect(_read('macos/Runner/Configs/AppInfo.xcconfig'),
          contains('PRODUCT_NAME = $kProduct'));
      expect(_read('.github/workflows/release-macos.yml'),
          contains('com.apple.quarantine $kProduct.app'),
          reason: 'the quarantine command names a bundle this build does '
              'not produce, so it silently clears nothing');
    });

    test('the application identifiers are untouched', () {
      // The rename must never reach these. An install whose application
      // id changes is a different app to the OS, and every reader loses
      // their data. Both of these are the historical spelling and stay
      // wrong forever on purpose.
      expect(_read('macos/Runner/Configs/AppInfo.xcconfig'),
          contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.yahwehswords'));
      expect(_read('linux/CMakeLists.txt'),
          contains('set(APPLICATION_ID "com.example.yswords")'));
    });
  });
}
