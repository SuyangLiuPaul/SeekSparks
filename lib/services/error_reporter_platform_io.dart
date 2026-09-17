/// Native platform info for ErrorReporter — iOS / Android /
/// macOS / Linux / Windows. Selected via conditional import in
/// `error_reporter.dart`.
///
/// We deliberately avoid the `device_info_plus` plugin to keep
/// the dependency footprint small. The 3 fields we collect
/// (operating system name, OS version, locale-derived dpr) are
/// already exposed by `dart:io` + `dart:ui`.
library;

import 'dart:io';
import 'dart:ui' as ui;

String get platformName {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  if (Platform.isWindows) return 'windows';
  if (Platform.isFuchsia) return 'fuchsia';
  return 'unknown';
}

/// Whether this process is `flutter test`.
///
/// The test runner sets FLUTTER_TEST, and nothing else does. It is asked
/// here rather than in the reporter so the web build — which has no
/// `Platform.environment` — can answer the same question with a const
/// false. See [ErrorReporter] for why it matters: on 2026-09-18 the
/// owner's inbox took an "Exception: boom" from an Azure runner with an
/// 800x600 screen, which is `error_reporter_test.dart` proving that
/// `report()` does not throw — by mailing him.
bool get isTestRun => Platform.environment.containsKey('FLUTTER_TEST');

Map<String, dynamic> collectDeviceInfo() {
  String screen = '';
  double? dpr;
  try {
    final view = ui.PlatformDispatcher.instance.views.first;
    final w = view.physicalSize.width / view.devicePixelRatio;
    final h = view.physicalSize.height / view.devicePixelRatio;
    screen = '${w.round()}x${h.round()}';
    dpr = view.devicePixelRatio;
  } catch (_) {/* ignore — screen info is best-effort */}
  return {
    'screen': screen,
    'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'dpr': dpr,
    'ua': '', // native has no user-agent equivalent
  };
}
