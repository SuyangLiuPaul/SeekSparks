import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the app's brand marks against the failure that produced this
/// test: the mark changed and only some of the files carrying it were
/// regenerated.
///
/// The Yahweh's Swords drawing reached the shipped launcher icons in
/// dc146fc, and its hilt was fixed in b6d9859, but neither commit
/// touched `assets/app_icon.png` — the file pubspec's `flutter_icons`
/// block and both icon generators name as the master. So the loading
/// screen went on showing the retired SeekSparks mark for as long as
/// the app has been called Yahweh's Swords, the macOS and Windows
/// builds still carried it, the "Dark" alternate icon installed it onto
/// the home screen of anyone who picked it, and the in-app icon picker
/// previewed six variants of a drawing the app no longer used.
///
/// None of that failed anything. The generators ran, the build
/// succeeded, and the wrong picture shipped. Hence a test: the marks are
/// derived, so a derived file that no longer matches a fresh render of
/// its master is a defect, and this is where it surfaces.
void main() {
  Future<ProcessResult> check(String script) => Process.run(
        'python3',
        ['tools/$script', '--check'],
        workingDirectory: Directory.current.path,
      );

  Future<bool> hasPillow() async {
    final probe = await Process.run('python3', ['-c', 'import PIL']);
    return probe.exitCode == 0;
  }

  test('every derived brand mark still matches its master', () async {
    if (!await hasPillow()) {
      markTestSkipped('python3 with Pillow is not available here');
      return;
    }
    for (final script in const [
      'generate_brand_marks.py',
      'generate_themed_icons.py',
    ]) {
      final result = await check(script);
      expect(
        result.exitCode,
        0,
        reason: 'tools/$script reports a derived icon has drifted from its '
            'master. Regenerate with:\n\n'
            '    python3 tools/$script\n\n'
            '${result.stdout}${result.stderr}',
      );
    }
  });

  test('the master is the drawing the app actually ships', () async {
    // A cheap, dependency-free tripwire for the specific regression:
    // the retired mark is a dark ground, the current one is pale blue.
    // If the master is ever replaced by something dark again, this
    // fails even where Pillow is missing.
    final master = File('assets/app_icon.png');
    expect(master.existsSync(), isTrue);

    final loading = File('assets/loading.png');
    expect(loading.existsSync(), isTrue);
    expect(
      loading.readAsBytesSync(),
      master.readAsBytesSync(),
      reason: 'the loading screen must show the same mark as the app icon — '
          'it showed a different one for the whole of the rename',
    );
  });
}
