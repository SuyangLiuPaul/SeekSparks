// 2026-09-09: the in-app install's dialogs, and the doors into them.
//
// The installer test covers what reaches Android. This covers what
// reaches the reader — the progress dialog that must survive the Back
// button and yield to Stop, the permission trip that must carry on by
// itself, the "Update now" button that must not appear for a release
// with no APK, and the daily bar that must run the same flow as the
// About page. Each was a review finding on 2026-09-09; the group
// comments say which.
//
// The download is real file IO, so those tests run under
// `tester.runAsync`, holding the response stream open by hand to keep
// the dialog on screen long enough to look at.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/app_update_installer.dart';
import 'package:seeksparks/services/update_service.dart';
import 'package:seeksparks/widgets/update_check_tile.dart';

const _hint = 'Android will ask you to confirm the install.';
const _downloading = 'Downloading update…';

Uint8List _apkBytes(int length) => Uint8List.fromList(
      <int>[...kZipMagic, ...List<int>.filled(length - kZipMagic.length, 7)],
    );

UpdateInfo _info({String downloadUrl = 'https://example.invalid/app.apk'}) =>
    UpdateInfo(
      updateAvailable: true,
      currentVersion: '1.6.271',
      latestVersion: '1.6.272',
      downloadUrl: downloadUrl,
      releaseUrl: 'https://example.invalid/releases/v1.6.272',
    );

/// A response whose body the test feeds by hand, so the dialog stays
/// up until the test says otherwise.
http.Client _held(StreamController<List<int>> body, {int length = 64}) =>
    MockClient.streaming((request, _) async =>
        http.StreamedResponse(body.stream, 200, contentLength: length));

/// A complete APK, served at once.
http.Client _complete() => MockClient.streaming((request, _) async =>
    http.StreamedResponse(Stream.value(_apkBytes(64)), 200,
        contentLength: 64));

/// What the Android Back button sends. `handlePopRoute` itself is
/// `@protected`; the platform message is the honest way in and is
/// exactly what the OS does.
Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec
        .encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
}

/// `testWidgets` with the platform override set for the body and
/// restored before the binding checks its invariants — which it does
/// BEFORE `tearDown`, so a reset there is too late.
void _onPlatform(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  TargetPlatform platform = TargetPlatform.android,
}) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

/// Pump frames (and let real IO breathe) until [ready] is true.
Future<void> _until(WidgetTester tester, bool Function() ready,
    {String what = 'condition'}) async {
  for (var i = 0; i < 200; i++) {
    if (ready()) return;
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('timed out waiting for $what');
}

void main() {
  late Directory dir;
  late List<MethodCall> calls;
  late bool permitted;
  late BuildContext host;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    updateInstallInProgress.value = false;
    dir = await Directory.systemTemp.createTemp('update_tile_test');
    calls = <MethodCall>[];
    permitted = true;
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
            return 'com.example.yahwehswords';
          case 'requestPermission':
            // The reader turned the switch on and came back.
            permitted = true;
            return true;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    updateInstallInProgress.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('yswords/apk_installer'), null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File downloaded() => File('${dir.path}/update.apk');
  int count(String method) => calls.where((c) => c.method == method).length;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) {
            host = ctx;
            return const SizedBox.shrink();
          }),
        ),
      ),
    ));
  }

  group('the progress dialog (finding 1)', () {
    _onPlatform(
        'survives the Back button, ignores a second Update now, shows the '
        'hint beside the percentage, and stops when told to',
        (tester) async {
      await pumpHost(tester);
      await tester.runAsync(() async {
        final body = StreamController<List<int>>();
        final client = _held(body);
        final info = _info();
        final pending =
            installUpdateInApp(host, info, locale: 'en', client: client);
        await _until(tester, () => find.text(_downloading).evaluate().isNotEmpty,
            what: 'progress dialog');
        // Half the file: a known length, so the bar has a percentage —
        // the case in which the hint used to vanish.
        body.add(_apkBytes(32));
        await _until(tester, () => find.text('50%').evaluate().isNotEmpty,
            what: '50%');
        expect(find.text(_hint), findsOneWidget,
            reason: 'GitHub always sends a length; a hint shown only '
                'without one is shown to nobody');

        // Android Back: the dialog must stay, because the download does.
        await _pressBack(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(_downloading), findsOneWidget,
            reason: 'Back used to dismiss the dialog and leave the '
                'download running unseen');

        // A second "Update now" while this one runs is a no-op — not a
        // second dialog, and not a second write stream on update.apk.
        unawaited(
            installUpdateInApp(host, info, locale: 'en', client: client));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(_downloading), findsOneWidget);
        expect(count('updateDir'), 1);

        // Stop: the dialog closes, the partial file goes, and nobody is
        // told the download "failed".
        await tester.tap(find.text('Stop download'));
        await _until(tester, () => find.text(_downloading).evaluate().isEmpty,
            what: 'dialog to close');
        await pending.timeout(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text("Couldn't download the update"), findsNothing);
        expect(downloaded().existsSync(), isFalse);
        expect(count('install'), 0);
        expect(updateInstallInProgress.value, isFalse);
        await body.close();
      });
    });
  });

  group('the permission trip (finding 4)', () {
    _onPlatform(
        'carries on by itself when the reader comes back with the switch '
        'on — there is no Update button on the screen they return to',
        (tester) async {
      permitted = false;
      await pumpHost(tester);
      await tester.runAsync(() async {
        final pending = installUpdateInApp(host, _info(),
            locale: 'en', client: _complete());
        await _until(
            tester,
            () => find.text('Allow installing updates').evaluate().isNotEmpty,
            what: 'permission dialog');
        expect(find.textContaining('continues when you come back'),
            findsOneWidget,
            reason: 'the copy must not ask for a press of a button that '
                'is not there');
        expect(count('install'), 0);

        await tester.tap(find.text('Open settings'));
        await _until(tester, () => count('install') == 1,
            what: 'the install intent after returning from settings');
        expect(count('requestPermission'), 1);
        await pending.timeout(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(_downloading), findsNothing);
        expect(find.text("Couldn't download the update"), findsNothing);
      });
    });
  });

  group('the "Update available" dialog (findings 3 and 5)', () {
    _onPlatform('offers Update now with the Android body when the release '
        'has an APK', (tester) async {
      await pumpHost(tester);
      showUpdateAvailableDialog(host, _info(), locale: 'en');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Update now'), findsOneWidget);
      expect(find.textContaining('downloads and installs it here'),
          findsOneWidget);
      expect(find.textContaining('desktop unzips'), findsNothing,
          reason: 'a phone is not told about desktops and iOS above a '
              'button that installs in place');
    });

    _onPlatform('offers only the browser when the release has no APK yet',
        (tester) async {
      await pumpHost(tester);
      showUpdateAvailableDialog(
        host,
        _info(downloadUrl: 'https://example.invalid/releases/v1.6.272'),
        locale: 'en',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Update now'), findsNothing,
          reason: 'the button used to download the HTML release page '
              'and report "did not finish"');
      expect(find.text('Open in browser'), findsOneWidget);
      expect(find.textContaining('desktop unzips'), findsOneWidget);
    });

    _onPlatform('never offers Update now off Android, APK or not',
        platform: TargetPlatform.iOS, (tester) async {
      await pumpHost(tester);
      showUpdateAvailableDialog(host, _info(), locale: 'en');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Update now'), findsNothing);
      expect(find.text('Download'), findsOneWidget);
    });
  });

  group('the daily bar (finding 6)', () {
    _onPlatform('on Android with an APK its action is the in-app install, '
        'the same flow as the About page', (tester) async {
      await pumpHost(tester);
      await tester.runAsync(() async {
        final body = StreamController<List<int>>();
        ScaffoldMessenger.of(host).showSnackBar(
          buildUpdateAvailableBar(host, _info(),
              locale: 'en', client: _held(body)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Version v1.6.272 is available'), findsOneWidget);
        expect(find.text('Update now'), findsOneWidget,
            reason: 'the bar used to hand the URL to LinkOpener, which '
                'on a native build is a stub');
        expect(find.text('Download'), findsNothing);

        await tester.tap(find.text('Update now'));
        await _until(tester, () => find.text(_downloading).evaluate().isNotEmpty,
            what: 'progress dialog from the bar');
        expect(count('updateDir'), 1);

        await tester.tap(find.text('Stop download'));
        await _until(tester, () => find.text(_downloading).evaluate().isEmpty,
            what: 'dialog to close');
        await _until(tester, () => !updateInstallInProgress.value,
            what: 'flow to finish');
        await body.close();
      });
    });

    _onPlatform('with no APK it does not offer the in-app install',
        (tester) async {
      await pumpHost(tester);
      ScaffoldMessenger.of(host).showSnackBar(
        buildUpdateAvailableBar(
          host,
          _info(downloadUrl: 'https://example.invalid/releases/v1.6.272'),
          locale: 'en',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Update now'), findsNothing);
    });
  });

  group('the strings (finding 8, and the new keys)', () {
    test('the zh-Hant switch is named as Android’s zh-TW build names it',
        () {
      final body = uiStrings['updatePermissionBody']!['zh-Hant']!;
      expect(body, contains('安裝不明應用程式'));
      expect(body, isNot(contains('未知應用')),
          reason: '「安裝未知應用」 is Simplified with the characters '
              'swapped; a Traditional reader would look for it in the '
              'settings screen and not find it');
    });

    test('every new key has all three locales', () {
      for (final key in [
        'updateAvailableBodyAndroid',
        'updateCancelDownload',
        'updatePermissionBody',
      ]) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(uiStrings[key]?[locale], isNotNull, reason: '$key/$locale');
          expect(uiStrings[key]![locale]!.trim(), isNotEmpty,
              reason: '$key/$locale');
        }
      }
    });

    test('the permission copy no longer asks for a button that is not '
        'on screen', () {
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        final body = uiStrings['updatePermissionBody']![locale]!;
        expect(body, isNot(contains('再按一次')), reason: locale);
        expect(body, isNot(contains('press Update again')), reason: locale);
      }
    });
  });
}
