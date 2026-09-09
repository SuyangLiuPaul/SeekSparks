// 2026-06-16 (v1.3.88): free, GitHub-backed in-app update check.
//
// There is no app store in the loop — native builds (Android / Windows /
// macOS / Linux / iOS) are published as assets on the project's GitHub
// Releases. This service asks the GitHub Releases API for the LATEST
// release, compares its tag (e.g. `v1.3.88`) to the running `kAppVersion`,
// and — if newer — hands back the download URL of the asset for the
// current platform (falling back to the release page). The UI
// (`UpdateCheckTile`) opens that URL via `LinkOpener`; the OS / browser
// then downloads it and the user installs (Android: tap the .apk;
// desktop: unzip/run). It is intentionally NOT a silent auto-installer —
// that needs an app store. Fully free, no developer account.
//
// Web returns null: the PWA always serves the latest build on reload, so
// there is nothing to "update".

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'package:seeksparks/constants/app_version.dart';
import 'package:seeksparks/services/app_update_installer.dart';

/// Result of an update check. [updateAvailable] is the only thing the UI
/// branches on; the URLs are pre-resolved for the current platform.
class UpdateInfo {
  final bool updateAvailable;
  final String currentVersion; // e.g. "1.3.87"
  final String latestVersion; // e.g. "1.3.88"
  final String downloadUrl; // platform asset, or the release page
  final String releaseUrl; // the release's html page

  const UpdateInfo({
    required this.updateAvailable,
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseUrl,
  });

  /// Whether [downloadUrl] is an APK the app can install itself, or
  /// only the release page.
  ///
  /// 2026-09-09 (review finding 3): the Android workflow can lag the
  /// tag by several minutes, and in that window the latest release has
  /// no `.apk` asset yet, so [downloadUrl] is the release's HTML page.
  /// "Update now" then downloaded that page and reported "did not
  /// finish". Decided HERE, on the resolved URL, so the widgets ask one
  /// question instead of each re-parsing the name. The path rather than
  /// the whole string, so a query string could not hide the extension.
  bool get hasApk =>
      (Uri.tryParse(downloadUrl)?.path ?? '').toLowerCase().endsWith('.apk');
}

class UpdateService {
  UpdateService._();

  static const String repo = 'SuyangLiuPaul/SeekSparks';
  static const String _latestApi =
      'https://api.github.com/repos/$repo/releases/latest';
  static const String releasesPage =
      'https://github.com/$repo/releases/latest';

  /// True only on the native platforms where a downloadable release asset
  /// makes sense. Web (PWA auto-updates) returns false, so the UI hides
  /// the tile.
  static bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid ||
          Platform.isWindows ||
          Platform.isMacOS ||
          Platform.isLinux ||
          Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Hits the GitHub Releases API and compares to the running version.
  /// Returns null on web, on network/parse error, or on timeout — the UI
  /// treats null as "couldn't check" (never an exception).
  static Future<UpdateInfo?> checkForUpdate() async {
    if (!isSupported) return null;
    try {
      final resp = await http.get(
        Uri.parse(_latestApi),
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (body['tag_name'] as String?) ?? '';
      final latest = stripV(tag);
      if (latest.isEmpty) return null;

      final current = kAppVersion;
      final releaseUrl = (body['html_url'] as String?) ?? releasesPage;
      final assets = (body['assets'] as List?) ?? const [];
      final downloadUrl =
          _assetUrlForPlatform(assets, cnFlavour: await _isCnFlavour()) ??
              releaseUrl;

      return UpdateInfo(
        updateAvailable: isNewer(latest, current),
        currentVersion: current,
        latestVersion: latest,
        downloadUrl: downloadUrl,
        releaseUrl: releaseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Strip a leading "v" from a release tag ("v1.3.88" → "1.3.88").
  static String stripV(String tag) =>
      tag.startsWith('v') ? tag.substring(1) : tag;

  /// Numeric semver compare: true iff [latest] > [current]. Tolerant of
  /// missing segments and any non-digit suffix on a segment.
  static bool isNewer(String latest, String current) {
    final l = _parse(latest);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (l[i] != c[i]) return l[i] > c[i];
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.');
    return List<int>.generate(3, (i) {
      if (i >= parts.length) return 0;
      final digits = parts[i].replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digits) ?? 0;
    });
  }

  /// The suffix `build.gradle.kts` gives the China flavour's
  /// applicationId, and the marker a release asset built for it
  /// carries in its name.
  static const String cnPackageSuffix = '.cn';
  static const String cnAssetMarker = '-cn';

  /// Whether the running build is the `.cn` flavour, asked of the
  /// platform once per check. Only Android has flavours; everywhere
  /// else the answer is no without a channel round-trip.
  static Future<bool> _isCnFlavour() async {
    try {
      if (!Platform.isAndroid) return false;
    } catch (_) {
      return false;
    }
    final pkg = await AppUpdateInstaller.packageName();
    return pkg != null && pkg.endsWith(cnPackageSuffix);
  }

  /// The APK for THIS flavour, or null when the release has none.
  ///
  /// 2026-09-09 (review finding 7): the `.cn` flavour has a different
  /// applicationId, so handing it the international APK would not
  /// update it — Android would install a SECOND app beside it. So a
  /// cn build takes only an asset whose name carries [cnAssetMarker],
  /// and an intl build refuses one that does; either way "no matching
  /// asset" is null, and the caller falls back to the release page —
  /// which [UpdateInfo.hasApk] then reports as "browser only". One
  /// place, and public so it can be exercised with fake asset lists.
  static String? androidAssetUrl(
    List<dynamic> assets, {
    required bool cnFlavour,
  }) {
    for (final a in assets) {
      if (a is! Map) continue;
      final name = ((a['name'] as String?) ?? '').toLowerCase();
      final url = (a['browser_download_url'] as String?) ?? '';
      if (url.isEmpty || !name.endsWith('.apk')) continue;
      if (name.contains(cnAssetMarker) == cnFlavour) return url;
    }
    return null;
  }

  /// Pick the release asset whose name matches the current platform, by
  /// the substrings the release-build workflows use in their filenames
  /// (`SeekSparks-Android-…apk`, `…Windows…zip`, `…macOS…zip`, `…Linux…tar.gz`).
  /// iOS has no directly-installable asset, so it returns null → the UI
  /// falls back to the release page.
  static String? _assetUrlForPlatform(
    List<dynamic> assets, {
    required bool cnFlavour,
  }) {
    String? needle;
    try {
      if (Platform.isAndroid) {
        return androidAssetUrl(assets, cnFlavour: cnFlavour);
      } else if (Platform.isWindows) {
        needle = 'Windows';
      } else if (Platform.isMacOS) {
        needle = 'macOS';
      } else if (Platform.isLinux) {
        needle = 'Linux';
      } else {
        return null; // iOS / unknown → release page
      }
    } catch (_) {
      return null;
    }
    for (final a in assets) {
      if (a is! Map) continue;
      final name = (a['name'] as String?) ?? '';
      final url = (a['browser_download_url'] as String?) ?? '';
      if (url.isNotEmpty && name.contains(needle)) return url;
    }
    return null;
  }
}
