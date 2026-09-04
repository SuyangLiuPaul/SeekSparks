/// THE FALLBACK VERSION IS A VERSION, SO IT HAS TO BE THE RIGHT ONE.
///
/// `kAppVersion` is injected at build time:
///
///     --dart-define=APP_VERSION=$APP_VERSION
///
/// and `tools/release_web.sh` passes it. Nothing else does. A plain
/// `flutter build ios` or `flutter build apk` — which is how the phone,
/// the tablet and the Mi Pad are built — passes no define at all, so
/// `String.fromEnvironment` returns its `defaultValue` and every screen
/// that prints a version prints THAT: the loading page (twice), the
/// workbench footer, Settings and About.
///
/// The literal had been 1.3.113 since June while pubspec had moved on
/// to 1.6.234, so the three native devices all announced a version from
/// three months and a hundred and twenty-one patch releases ago, while
/// Android's own package manager — which reads pubspec through gradle —
/// reported 1.6.234 on the same device. Reported as
/// 「为什么loading page和各个地方的版本号对不上」.
///
/// The empty-string guard beside it is not the problem and stays: a
/// build that ships `--dart-define=APP_VERSION=` with a blank shell
/// variable would otherwise blank the version outright, which happened
/// on the Mi Pad in June. The problem is that the fallback was allowed
/// to go STALE, which turns "never blank" into "confidently wrong" —
/// and a wrong version is worse than a missing one, because nobody
/// doubts it.
///
/// So the fallback is pinned to `pubspec.yaml`. Bumping the version now
/// fails here until both move together, which is the only way a
/// constant that is only read on the path nobody tests can stay true.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/app_version.dart';

void main() {
  test('the fallback in app_version.dart matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    // pubspec allows `1.6.234+7`; the user-visible string is the part
    // before the build number.
    final declared = line.split(':')[1].trim().split('+').first;

    // Read the literal out of the source rather than the constant,
    // because under `flutter test` no define is passed and kAppVersion
    // IS the fallback — comparing it to itself would prove nothing if
    // the test were ever run with a define in place.
    final src = File('lib/constants/app_version.dart').readAsStringSync();
    final matches = RegExp(r"defaultValue:\s*'([0-9]+\.[0-9]+\.[0-9]+)'")
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toSet();
    final guards = RegExp(r"_envAppVersion == '' \? '([0-9.]+)'")
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toSet();

    expect(matches, contains(declared),
        reason: 'app_version.dart\'s APP_VERSION defaultValue is '
            '$matches but pubspec.yaml says $declared — a native build '
            'passes no --dart-define, so every version the app prints '
            'would be the stale literal');
    expect(guards, everyElement(declared),
        reason: 'the empty-string guard beside it must fall back to the '
            'same string, or a blank define prints a different wrong '
            'version from an absent one');

    // And the constant itself, under a test run with no define.
    expect(kAppVersion, declared);
  });
}
