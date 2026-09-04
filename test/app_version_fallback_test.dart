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

  test('pubspec carries a versionCode, derived from the semver', () {
    // Android refuses an update whose versionCode is not GREATER than
    // the installed one, and `flutter.versionCode` — which
    // android/app/build.gradle.kts passes through — is pubspec's
    // `+build` suffix. This project never set one, so every release
    // built as versionCode 1. `adb install -r` does not care, which is
    // why it went unnoticed across 235 patch releases, but nothing
    // resembling a real update channel would install one build over
    // another.
    //
    // Derived rather than counted, so it cannot drift from the version
    // beside it and no state has to travel between machines. The one
    // property that matters is that it never goes BACKWARDS: a lower
    // versionCode is unrecoverable in the field, since the only way past
    // it is an uninstall, and this app has no cloud sync to restore
    // from.
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final field = line.split(':')[1].trim();
    expect(field, contains('+'),
        reason: 'pubspec.yaml must carry a +build suffix — without one '
            'flutter.versionCode is 1 for every release ever shipped');

    final semver = field.split('+').first;
    final code = int.parse(field.split('+').last);
    final parts = semver.split('.').map(int.parse).toList();
    expect(parts, hasLength(3));
    final (major, minor, patch) = (parts[0], parts[1], parts[2]);

    expect(code, major * 1000000 + minor * 10000 + patch,
        reason: 'tools/bump_version.sh derives the code this way; if the '
            'two disagree, one of them was edited by hand');
    // The bounds the scheme rests on, asserted rather than assumed.
    expect(minor, lessThan(100),
        reason: 'minor >= 100 would carry into the major digits and the '
            'code could go backwards on the next major release');
    expect(patch, lessThan(10000),
        reason: 'patch >= 10000 would carry into the minor digits');
    expect(code, lessThan(2100000000), reason: "Android's own cap");
  });
}
