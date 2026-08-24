import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';

/// Regression tests for the 2026-07-10 prod crash
/// `PlatformException(copy_fail, Clipboard.setData failed.)` (iOS
/// Safari rejecting the async Clipboard API). The contract under test:
/// [ClipboardHelper.copyText] NEVER throws — it returns false when the
/// platform clipboard write fails (on VM there is no web fallback), so
/// no copy path can escalate to the Zone error handler again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('copyText returns true when the platform accepts the write',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    expect(await ClipboardHelper.copyText('hello'), isTrue);
  });

  test(
      'copyText returns false (does NOT throw) when the platform '
      'rejects the write — the iOS Safari copy_fail crash class',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(
            code: 'copy_fail', message: 'Clipboard.setData failed.');
      }
      return null;
    });
    // Must complete with false — an unhandled throw here fails the test.
    expect(await ClipboardHelper.copyText('hello'), isFalse);
  });

  _localeGroup();
}

/// 2026-08-24 (owner-reported): after switching the app to 中文 the
/// copy toast still said "Copied!".
///
/// The cause was not a missing translation — `uiStrings['copied']` has
/// carried zh-Hans and zh-Hant all along. `_localeFor` read Flutter's
/// `Localizations.maybeLocaleOf(context)`, and `GetMaterialApp` in
/// `main.dart` sets no `locale:`/`supportedLocales`/
/// `localizationsDelegates`, so that value is the DEVICE language and
/// the in-app 🌐 switcher could never move it. On an English device it
/// returned 'en' permanently while the rest of the UI was Chinese.
///
/// This pumps the real widget, flips only `AppSettings.locale`, and
/// reads the painted snackbar — a source check could not see it,
/// because the lookup expression was correct at every call site.
void _localeGroup() {
  group('the copy toast follows the app locale, not the device', () {
    Future<String> toastTextFor(WidgetTester tester, String locale) async {
      final settings = AppSettings();
      settings.setLocale(locale);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);

      late BuildContext ctx;
      await tester.pumpWidget(
        ChangeNotifierProvider<AppSettings>.value(
          value: settings,
          child: MaterialApp(
            // Deliberately English, and deliberately the ONLY locale
            // Flutter knows about — this is the device-language half
            // of the bug. The toast must ignore it.
            locale: const Locale('en'),
            home: Scaffold(
              body: Builder(builder: (c) {
                ctx = c;
                return const SizedBox.shrink();
              }),
            ),
          ),
        ),
      );

      await ClipboardHelper.copyWithFeedback(ctx, 'text');
      await tester.pump();
      final text = tester.widget<Text>(
        find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
      );
      // Drain the snackbar's own auto-dismiss timer, or the binding
      // fails the test for a pending timer after teardown.
      await tester.pumpAndSettle(const Duration(seconds: 3));
      return text.data ?? '';
    }

    testWidgets('简体', (tester) async {
      expect(await toastTextFor(tester, 'zh-Hans'), '已复制！');
    });

    testWidgets('繁體', (tester) async {
      expect(await toastTextFor(tester, 'zh-Hant'), '已複製！');
    });

    testWidgets('English', (tester) async {
      expect(await toastTextFor(tester, 'en'), 'Copied!');
    });
  });
}
