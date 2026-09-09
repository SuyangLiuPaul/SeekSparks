// The in-app updater's download, which is the half that can lie.
//
// Handing the file to Android is one `startActivity` and cannot be
// tested off a device. Everything BEFORE that can, and is where the
// failures live: a captive-portal login page and a real APK both
// arrive with a 200, and a truncated download and a complete one look
// identical to a progress bar. Android's response to being given
// either is "There was a problem parsing the package", which the
// reader reads as *this app is broken*.
//
// `AppUpdateInstaller.isSupported` reads `defaultTargetPlatform`
// precisely so this file can exist; see the comment on it.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

import 'package:seeksparks/services/app_update_installer.dart';

/// A real APK's first bytes, followed by filler. Only the magic is
/// checked, so nothing here has to be a valid archive.
Uint8List _apkBytes([int length = 64]) => Uint8List.fromList(
      <int>[...kZipMagic, ...List<int>.filled(length - kZipMagic.length, 7)],
    );

/// What a hotel wifi hands back instead of the file.
final Uint8List _loginPage =
    Uint8List.fromList(utf8.encode('<html><body>Sign in</body></html>'));

/// Serves [body], declaring [declaredLength] bytes.
///
/// **Streaming, and that is the whole reason this helper exists.**
/// `http.Response.bytes` computes its own `contentLength` from the
/// body it was given and ignores a `content-length` header set beside
/// it — so a mock built that way can never produce the case this file
/// most needs, a server that promises more than it delivers. Two tests
/// silently passed against nothing before this was noticed.
///
/// `declaredLength` is a sentinel-free `Object?`: omit it for the
/// truth, pass `null` for a server that declares no length at all.
http.Client _serving(
  Uint8List body, {
  Object? declaredLength = _truth,
  int status = 200,
}) =>
    MockClient.streaming((request, _) async => http.StreamedResponse(
          Stream<List<int>>.value(body),
          status,
          contentLength: identical(declaredLength, _truth)
              ? body.length
              : declaredLength as int?,
        ));

/// Marks "no argument passed", so `declaredLength: null` can mean a
/// server that sent no `Content-Length` rather than a default.
const Object _truth = Object();

void main() {
  late Directory dir;
  late List<MethodCall> calls;
  bool permitted = true;
  String? packageName = 'com.example.yahwehswords';

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AppUpdateInstaller.resetPackageNameCache();
    dir = await Directory.systemTemp.createTemp('update_test');
    calls = <MethodCall>[];
    permitted = true;
    packageName = 'com.example.yahwehswords';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('yswords/apk_installer'),
      (call) async {
        calls.add(call);
        switch (call.method) {
          case 'canInstall':
            return permitted;
          case 'updateDir':
            return dir.path;
          case 'install':
            return true;
          case 'packageName':
            return packageName;
          case 'requestPermission':
            // The platform side answers when the reader comes BACK
            // from settings, with the switch's state at that moment.
            permitted = true;
            return true;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    AppUpdateInstaller.resetPackageNameCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('yswords/apk_installer'), null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File downloaded() => File('${dir.path}/update.apk');

  group('what reaches the installer', () {
    test('a complete APK is written and handed over', () async {
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes()),
      );
      expect(outcome, UpdateInstallOutcome.launched);
      expect(downloaded().existsSync(), isTrue);
      final install = calls.firstWhere((c) => c.method == 'install');
      expect((install.arguments as Map)['path'], downloaded().path);
    });

    test(
        'a login page with a 200 and an honest length is refused — this is '
        'the captive-portal case, and Android would call it a corrupt package',
        () async {
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_loginPage),
      );
      expect(outcome, UpdateInstallOutcome.downloadFailed);
      expect(calls.any((c) => c.method == 'install'), isFalse);
    });

    test('a truncated download is refused even though it starts like an APK',
        () async {
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes(), declaredLength: 4096),
      );
      expect(outcome, UpdateInstallOutcome.downloadFailed);
      expect(calls.any((c) => c.method == 'install'), isFalse);
    });

    test('a refused download leaves nothing behind — a cache holding most of '
        'a 90 MB APK is the reason to check', () async {
      await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_loginPage),
      );
      expect(downloaded().existsSync(), isFalse);
    });

    test('a 404 never becomes a file', () async {
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes(), status: 404),
      );
      expect(outcome, UpdateInstallOutcome.downloadFailed);
      expect(downloaded().existsSync(), isFalse);
    });
  });

  group('the permission the reader has not given yet', () {
    test('is reported as its own outcome, not as a failure — it is the '
        'ordinary first run and the UI sends them to the OS switch',
        () async {
      permitted = false;
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes()),
      );
      expect(outcome, UpdateInstallOutcome.permissionNeeded);
      // And nothing was downloaded: asking first is the point.
      expect(calls.any((c) => c.method == 'updateDir'), isFalse);
      expect(downloaded().existsSync(), isFalse);
    });
  });

  group('which platforms get a button at all', () {
    test('iOS does not — an app cannot install an app, and a button that '
        'said otherwise would have to apologise', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppUpdateInstaller.isSupported, isFalse);
      expect(
        await AppUpdateInstaller.downloadAndInstall('https://example.invalid/a'),
        UpdateInstallOutcome.unsupported,
      );
    });

    test('the desktops do not — replacing a running application is the '
        'platform’s business', () async {
      for (final p in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = p;
        expect(AppUpdateInstaller.isSupported, isFalse, reason: '$p');
      }
    });

    test('Android does', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppUpdateInstaller.isSupported, isTrue);
    });
  });

  group('progress', () {
    test('reports a fraction when the server declared a length', () async {
      final seen = <double?>[];
      await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes(128)),
        onProgress: seen.add,
      );
      expect(seen, isNotEmpty);
      expect(seen.last, 1.0);
      expect(seen.every((f) => f != null && f >= 0 && f <= 1), isTrue);
    });

    test('reports null rather than inventing a denominator when it did not',
        () async {
      final seen = <double?>[];
      await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes(), declaredLength: null),
        onProgress: seen.add,
      );
      expect(seen, isNotEmpty);
      expect(seen.every((f) => f == null), isTrue,
          reason: 'a bar that guesses is worse than one that admits it');
    });
  });

  // 2026-09-09 (review finding 1): the reader's Stop button.
  group('cancelling', () {
    test('mid-download stops the read, discards the partial file and is '
        'its own outcome — not a failure the UI would apologise for',
        () async {
      final body = StreamController<List<int>>();
      final token = UpdateCancelToken();
      final client = MockClient.streaming((request, _) async =>
          http.StreamedResponse(body.stream, 200, contentLength: 4096));
      final seen = <double?>[];
      final pending = AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: client,
        cancelToken: token,
        onProgress: seen.add,
      );
      // Half the file arrives, then the reader presses Stop. The
      // stream is deliberately never closed: a cancel that only took
      // effect at the next chunk would hang here.
      body.add(_apkBytes(2048));
      while (seen.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      token.cancel();
      final outcome = await pending.timeout(const Duration(seconds: 5));
      expect(outcome, UpdateInstallOutcome.cancelled);
      expect(downloaded().existsSync(), isFalse);
      expect(calls.any((c) => c.method == 'install'), isFalse);
      await body.close();
    });

    test('before the connect answers returns at once, not after the '
        'connect timeout', () async {
      final never = Completer<http.StreamedResponse>();
      final token = UpdateCancelToken();
      final client = MockClient.streaming((request, _) => never.future);
      final pending = AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: client,
        cancelToken: token,
        connectTimeout: const Duration(hours: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      token.cancel();
      expect(
        await pending.timeout(const Duration(seconds: 5)),
        UpdateInstallOutcome.cancelled,
      );
    });

    test('a token cancelled before the call downloads nothing', () async {
      final token = UpdateCancelToken()..cancel();
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: _serving(_apkBytes()),
        cancelToken: token,
      );
      expect(outcome, UpdateInstallOutcome.cancelled);
      expect(calls.any((c) => c.method == 'updateDir'), isFalse);
    });
  });

  // 2026-09-09 (review finding 2): a network that stops without
  // saying so used to freeze the progress dialog forever.
  group('a connection that stalls', () {
    test('after some bytes is given up at the idle timeout, and the '
        'partial file with it', () async {
      final body = StreamController<List<int>>();
      final client = MockClient.streaming((request, _) async =>
          http.StreamedResponse(body.stream, 200, contentLength: 4096));
      final pending = AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: client,
        idleTimeout: const Duration(milliseconds: 50),
      );
      body.add(_apkBytes(2048));
      // The rest never comes.
      final outcome = await pending.timeout(const Duration(seconds: 5));
      expect(outcome, UpdateInstallOutcome.downloadFailed);
      expect(downloaded().existsSync(), isFalse);
      await body.close();
    });

    test('before the headers is given up at the connect timeout',
        () async {
      final never = Completer<http.StreamedResponse>();
      final client = MockClient.streaming((request, _) => never.future);
      final outcome = await AppUpdateInstaller.downloadAndInstall(
        'https://example.invalid/app.apk',
        client: client,
        connectTimeout: const Duration(milliseconds: 50),
      ).timeout(const Duration(seconds: 5));
      expect(outcome, UpdateInstallOutcome.downloadFailed);
      expect(downloaded().existsSync(), isFalse);
    });
  });

  // 2026-09-09 (review finding 7): which package this build is.
  group('packageName', () {
    test('is asked of the platform once and remembered', () async {
      expect(await AppUpdateInstaller.packageName(), 'com.example.yahwehswords');
      packageName = 'com.example.yahwehswords.cn';
      expect(await AppUpdateInstaller.packageName(), 'com.example.yahwehswords',
          reason: 'a package cannot change its name while running');
      expect(calls.where((c) => c.method == 'packageName').length, 1);
    });

    test('is null off Android, without a channel round-trip', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await AppUpdateInstaller.packageName(), isNull);
      expect(calls, isEmpty);
    });
  });

  // 2026-09-09 (review finding 4): the trip to settings reports how it
  // ended, so the caller can carry on without another tap.
  group('requestPermission', () {
    test('returns what the platform side saw on the way back', () async {
      permitted = false;
      expect(await AppUpdateInstaller.requestPermission(), isTrue);
      expect(await AppUpdateInstaller.canInstall(), isTrue);
    });
  });
}
