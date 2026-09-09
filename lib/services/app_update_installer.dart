// 2026-09-09: installing the update from inside the app.
//
// From the owner: 「sword没有按键直接更新的」 — and before that, the
// question behind it: 「pianowithrosa 都是可以在 APP 里面就更新完但是
// words sword 要跳出去，可以只在 app 里面吗」.
//
// **The honest answer, by platform, because it is not the same
// answer.** A website updates itself because it is fetched every time
// it is opened; that is why 雅伟的话 and pianowithrosa feel seamless,
// and it is not something a native build can copy. So:
//
//   * **Android** — yes, and this file is it. The APK is downloaded
//     here and handed to the system installer. Android still shows its
//     own "install an update to this app?" screen and always will:
//     that dialog is the OS's security boundary, not a step this code
//     forgot to skip. What goes away is everything around it — the
//     browser, the Downloads folder, the file manager.
//   * **iOS** — no, and no amount of work changes it. An app cannot
//     install an app. Without the App Store or TestFlight the only
//     route is the web app, which is what the release page says.
//   * **Windows / macOS / Linux** — the download can happen here, but
//     replacing a running application is the platform's business and
//     the reader's. They keep the browser route.
//   * **Web** — nothing to install. A reload IS the update.
//
// So [isSupported] is Android alone, and every other platform keeps the
// link it already had rather than being shown a button that would have
// to apologise.

import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:http/http.dart' as http;

/// The four bytes every APK (and every other zip) starts with.
///
/// Checked before the file is offered to the installer because the
/// failure it catches is silent and confusing: a captive-portal login
/// page, a GitHub outage page or an HTML redirect all arrive with a
/// 200 and a plausible length, and Android's response to being handed
/// one is "There was a problem parsing the package" — which reads to
/// the reader as *this app's update is broken*, not *your hotel wifi
/// interfered*.
const List<int> kZipMagic = <int>[0x50, 0x4B, 0x03, 0x04];

/// What happened to an attempt to install.
enum UpdateInstallOutcome {
  /// Android's installer was launched. Whether the reader went through
  /// with it is not knowable from here — the installer is a separate
  /// task and reports nothing back. The app finds out the way anyone
  /// else would: by being restarted as the new version.
  launched,

  /// The reader has not allowed this app to install packages. The UI
  /// sends them to the OS switch rather than reporting a failure.
  permissionNeeded,

  /// The download did not finish, or finished as something that is not
  /// an APK.
  downloadFailed,

  /// The reader pressed Cancel. Nothing to report: they know.
  ///
  /// 2026-09-09 (review finding 1): its own outcome rather than a
  /// flavour of [downloadFailed], because the UI's response to a
  /// failure is a dialog offering the browser, and a reader who just
  /// said "stop" should not be asked a second question.
  cancelled,

  /// The platform cannot do this at all. Never returned on Android.
  unsupported,
}

/// A handle the UI holds to stop a download it started.
///
/// 2026-09-09 (review finding 1): before this the only way out of the
/// progress dialog was the Android Back button, which closed the
/// dialog and left the download running unseen — and a second "Update
/// now" opened a second write stream on the same `update.apk`. The
/// token is checked between chunks, and [whenCancelled] is raced
/// against the connect and the next chunk so a stalled connection
/// cannot delay the reader's Cancel by the length of a timeout.
class UpdateCancelToken {
  final Completer<void> _done = Completer<void>();

  bool get isCancelled => _done.isCompleted;

  /// Completes when [cancel] is called; never completes otherwise.
  Future<void> get whenCancelled => _done.future;

  void cancel() {
    if (!_done.isCompleted) _done.complete();
  }
}

class AppUpdateInstaller {
  AppUpdateInstaller._();

  static const MethodChannel _channel = MethodChannel('yswords/apk_installer');

  /// How long a download may go without a byte before it is given up.
  ///
  /// 2026-09-09 (review finding 2): a connection that stalls after the
  /// headers — a train tunnel, a wifi hand-off — used to freeze the
  /// progress dialog forever, with nothing on screen the reader could
  /// press. Thirty seconds is long enough for a slow link to breathe
  /// and short enough that the failed dialog arrives while the reader
  /// is still looking.
  static const Duration defaultIdleTimeout = Duration(seconds: 30);

  /// How long to wait for the response headers.
  static const Duration defaultConnectTimeout = Duration(seconds: 30);

  static Future<String?>? _packageName;

  /// The applicationId this build is running as, or null where the
  /// platform side cannot say.
  ///
  /// 2026-09-09 (review finding 7): asked once and remembered. The
  /// answer decides which release asset is an update for THIS app —
  /// `.cn` and the international build are different packages, and
  /// Android would install the wrong one as a second app rather than
  /// refuse it. Only [UpdateService] reads this; it is the one place
  /// that picks assets.
  static Future<String?> packageName() {
    if (!isSupported) return Future<String?>.value(null);
    return _packageName ??= () async {
      try {
        return await _channel.invokeMethod<String>('packageName');
      } on PlatformException {
        return null;
      } on MissingPluginException {
        return null;
      }
    }();
  }

  /// Forget the remembered [packageName], so a test can answer it
  /// differently. Never needed in the app: a package cannot change
  /// its own name while running.
  @visibleForTesting
  static void resetPackageNameCache() => _packageName = null;

  /// Android only. See the file header for why every other platform
  /// keeps the browser route rather than getting a button.
  ///
  /// `defaultTargetPlatform` rather than `Platform.isAndroid`, and the
  /// `kIsWeb` line above it is what makes that safe: a mobile browser
  /// reports `TargetPlatform.android` too, so the order here is the
  /// whole correctness argument and not a style choice. The reason to
  /// prefer it is that it can be overridden in a test, and everything
  /// this class does is behind this gate — with `Platform.isAndroid`
  /// the download's truncation and content checks could only ever be
  /// exercised on a device, which is to say never.
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Whether the reader has already allowed this app to install
  /// packages. False is not an error — it is the ordinary first-time
  /// state, and the caller's job is to offer [requestPermission].
  static Future<bool> canInstall() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Send the reader to the OS switch for this app, and report whether
  /// they came back with it on.
  ///
  /// 2026-09-09 (review finding 4): the platform side now answers only
  /// when the settings screen has closed (`onActivityResult`), so the
  /// value here is "granted NOW", after the reader's trip — not "the
  /// screen opened". A false is either a reader who declined or a ROM
  /// without the screen, and both leave them exactly where they were.
  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Download [url] into the app's cache and hand it to the installer.
  ///
  /// [onProgress] is called with a 0..1 fraction, or with null while
  /// the server has not said how big the file is — a progress bar that
  /// invents a denominator is worse than one that admits it is
  /// indeterminate, because the reader plans around it.
  ///
  /// The download is streamed rather than buffered. A release APK is
  /// ~90 MB and this runs on a mid-range tablet; `http.get` would hold
  /// the whole thing in memory before a single byte reached disk.
  ///
  /// [cancelToken] lets the UI stop it (finding 1); [idleTimeout] and
  /// [connectTimeout] stop it when the network does not (finding 2).
  /// Both timeouts are [downloadFailed] — the reader sees the same
  /// "did not finish" dialog with the browser as the way out.
  static Future<UpdateInstallOutcome> downloadAndInstall(
    String url, {
    void Function(double? fraction)? onProgress,
    http.Client? client,
    UpdateCancelToken? cancelToken,
    Duration idleTimeout = defaultIdleTimeout,
    Duration connectTimeout = defaultConnectTimeout,
  }) async {
    if (!isSupported) return UpdateInstallOutcome.unsupported;
    if (!await canInstall()) return UpdateInstallOutcome.permissionNeeded;
    if (cancelToken?.isCancelled ?? false) {
      return UpdateInstallOutcome.cancelled;
    }

    final String dir;
    try {
      dir = await _channel.invokeMethod<String>('updateDir') ?? '';
    } catch (_) {
      return UpdateInstallOutcome.downloadFailed;
    }
    if (dir.isEmpty) return UpdateInstallOutcome.downloadFailed;

    final owned = client == null;
    final http$ = client ?? http.Client();
    File? file;
    try {
      // Raced against the token so a Cancel pressed while the server
      // is still thinking returns at once rather than after the
      // connect timeout.
      final response = await _unlessCancelled(
        http$
            .send(http.Request('GET', Uri.parse(url)))
            .timeout(connectTimeout),
        cancelToken,
      );
      if (response == null) return UpdateInstallOutcome.cancelled;
      if (response.statusCode != 200) {
        return UpdateInstallOutcome.downloadFailed;
      }
      final total = response.contentLength;

      // One fixed name, overwritten every time. Keeping a file per
      // version would leave a cache full of 90 MB installers that
      // nothing ever deletes — and the only copy that matters is the
      // one being installed right now.
      file = File('$dir/update.apk');
      final sink = file.openWrite();
      var received = 0;
      var head = <int>[];
      try {
        // A subscription rather than `await for`, because a Cancel has
        // to be able to stop the reading — `await for` can only look
        // at the token once the next chunk has arrived, and the chunk
        // that never arrives is the case Cancel exists for.
        final done = Completer<void>();
        final sub = response.stream.timeout(idleTimeout).listen(
          (chunk) {
            sink.add(chunk);
            received += chunk.length;
            if (head.length < kZipMagic.length) {
              head = [...head, ...chunk].take(kZipMagic.length).toList();
            }
            onProgress?.call(
                total == null || total == 0 ? null : received / total);
          },
          onError: (Object e, StackTrace st) {
            if (!done.isCompleted) done.completeError(e, st);
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
        cancelToken?.whenCancelled.then((_) {
          sub.cancel();
          if (!done.isCompleted) done.complete();
        });
        await done.future;
      } finally {
        await sink.close();
      }
      if (cancelToken?.isCancelled ?? false) {
        await _discard(file);
        return UpdateInstallOutcome.cancelled;
      }

      // Both halves matter and they catch different lies. A truncated
      // download has the right magic and the wrong length; a login
      // page has a plausible length and the wrong magic.
      if (total != null && total > 0 && received != total) {
        await _discard(file);
        return UpdateInstallOutcome.downloadFailed;
      }
      if (head.length < kZipMagic.length ||
          !_startsWithZipMagic(head)) {
        await _discard(file);
        return UpdateInstallOutcome.downloadFailed;
      }

      await _channel.invokeMethod<bool>('install', {'path': file.path});
      return UpdateInstallOutcome.launched;
    } catch (_) {
      if (file != null) await _discard(file);
      return UpdateInstallOutcome.downloadFailed;
    } finally {
      if (owned) http$.close();
    }
  }

  /// [future]'s value, or null the moment [token] is cancelled first.
  /// `Future.any` listens to both, so a late error from the abandoned
  /// future is not an unhandled one.
  static Future<T?> _unlessCancelled<T>(
    Future<T> future,
    UpdateCancelToken? token,
  ) {
    if (token == null) return future;
    return Future.any<T?>([future, token.whenCancelled.then((_) => null)]);
  }

  static bool _startsWithZipMagic(List<int> head) {
    for (var i = 0; i < kZipMagic.length; i++) {
      if (head[i] != kZipMagic[i]) return false;
    }
    return true;
  }

  /// Remove a download that is not going to be installed, so a failed
  /// attempt does not leave most of an APK in the cache.
  static Future<void> _discard(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The cache is the OS's to reclaim; a file we could not remove
      // is not a reason to fail the caller differently.
    }
  }
}
