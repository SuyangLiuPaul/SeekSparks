// 2026-09-09 (review findings 3 and 7): which release asset, if any,
// is an update for THIS build.
//
// Two ways to hand a reader the wrong file, and both used to be
// possible. A release whose Android workflow is still running has no
// APK yet, and the fallback URL — the release's HTML page — was
// downloaded and offered to the installer. And the `.cn` flavour is a
// different applicationId, so the international APK is not an update
// for it: Android installs it as a second app beside the first.
//
// The decision is made in one place, `UpdateService.androidAssetUrl`,
// on fake asset lists shaped like the GitHub API's, and the widgets
// read the answer through `UpdateInfo.hasApk`.

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/update_service.dart';

Map<String, String> _asset(String name) => {
      'name': name,
      'browser_download_url': 'https://github.invalid/dl/$name',
    };

const _intl = 'SeekSparks-Android-v1.6.272.apk';
const _cn = 'SeekSparks-Android-cn-v1.6.272.apk';
const _win = 'SeekSparks-Windows-v1.6.272.zip';

UpdateInfo _info(String downloadUrl) => UpdateInfo(
      updateAvailable: true,
      currentVersion: '1.6.271',
      latestVersion: '1.6.272',
      downloadUrl: downloadUrl,
      releaseUrl: 'https://github.invalid/releases/v1.6.272',
    );

void main() {
  group('UpdateService.androidAssetUrl', () {
    test('the international build takes the plain APK, even when the cn '
        'one is listed first', () {
      final url = UpdateService.androidAssetUrl(
        [_asset(_win), _asset(_cn), _asset(_intl)],
        cnFlavour: false,
      );
      expect(url, endsWith(_intl));
    });

    test('the cn build takes the cn APK, even when the plain one is '
        'listed first', () {
      final url = UpdateService.androidAssetUrl(
        [_asset(_intl), _asset(_cn)],
        cnFlavour: true,
      );
      expect(url, endsWith(_cn));
    });

    test('the cn build gets NOTHING when the release has no cn APK — '
        'the international one would install as a second app', () {
      expect(
        UpdateService.androidAssetUrl([_asset(_intl)], cnFlavour: true),
        isNull,
      );
    });

    test('the international build gets nothing when only a cn APK exists',
        () {
      expect(
        UpdateService.androidAssetUrl([_asset(_cn)], cnFlavour: false),
        isNull,
      );
    });

    test('a desktop archive is never an Android asset', () {
      expect(
        UpdateService.androidAssetUrl([_asset(_win)], cnFlavour: false),
        isNull,
      );
    });

    test('the extension is matched without regard to case', () {
      final url = UpdateService.androidAssetUrl(
        [_asset('SeekSparks-Android-v1.6.272.APK')],
        cnFlavour: false,
      );
      expect(url, isNotNull);
    });

    test('an asset without a download URL is skipped', () {
      expect(
        UpdateService.androidAssetUrl(
          [
            {'name': _intl}
          ],
          cnFlavour: false,
        ),
        isNull,
      );
    });
  });

  group('UpdateInfo.hasApk', () {
    test('is true for an APK asset', () {
      expect(_info('https://github.invalid/dl/$_intl').hasApk, isTrue);
    });

    test('is true regardless of the extension’s case', () {
      expect(_info('https://github.invalid/dl/App.APK').hasApk, isTrue);
    });

    test('is false for the release page the URL falls back to', () {
      expect(
        _info('https://github.invalid/releases/tag/v1.6.272').hasApk,
        isFalse,
      );
    });

    test('reads the path, so a query string cannot fake or hide it', () {
      expect(_info('https://x.invalid/dl/a.apk?token=1').hasApk, isTrue);
      expect(_info('https://x.invalid/releases?name=a.apk').hasApk, isFalse);
    });
  });
}
