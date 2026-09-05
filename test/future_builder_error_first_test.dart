/// A FAILED FUTURE MUST NOT LOOK LIKE A SLOW ONE.
///
/// `AsyncSnapshot` has `hasData == false` while it is waiting AND after
/// it has failed. So a builder shaped like
///
///     if (!snap.hasData) return spinner;
///     if (snap.hasError) return message;   // unreachable
///
/// can never reach its second branch: the localized failure message is
/// dead code, and an asset that fails to load spins for ever with
/// nothing on screen saying anything is wrong.
///
/// Found on 2026-09-05 in THREE pages at once — the timeline, the family
/// tree and the sermons list — each of which had written a careful
/// localized error message that no reader could ever have seen. That is
/// why this is a sweep and not three fixes: the shape is easy to write
/// and its failure is invisible in every screenshot of a working app.
///
/// Read out of the source rather than exercised, because proving it
/// behaviourally needs a way to make each page's future fail, and no
/// page here has that seam. This costs nothing and cannot be satisfied
/// by remembering.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('the sweep actually reads the tree', () {
    expect(dartFiles.length, greaterThan(50),
        reason: 'almost no files were scanned — the walk is broken and '
            'every assertion below would pass vacuously');
  });

  test('no builder checks hasData before hasError', () {
    final offenders = <String>[];
    var sawAnyErrorCheck = false;

    for (final f in dartFiles) {
      final lines = f.readAsStringSync().split('\n');
      final noData = <int>[];
      final hasErr = <int>[];
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'!\s*\w+\.hasData').hasMatch(lines[i])) noData.add(i);
        if (RegExp(r'\w+\.hasError').hasMatch(lines[i])) hasErr.add(i);
      }
      if (hasErr.isNotEmpty) sawAnyErrorCheck = true;
      for (final e in hasErr) {
        // Within a few lines is the same builder; further apart is a
        // different branch and none of this test's business.
        final blocking = noData.where((d) => e - d > 0 && e - d <= 6);
        for (final d in blocking) {
          offenders.add('${f.path}: !hasData at line ${d + 1} shadows '
              'hasError at line ${e + 1}');
        }
      }
    }

    expect(sawAnyErrorCheck, isTrue,
        reason: 'no hasError check found anywhere — the pattern this test '
            'guards has been renamed and the guard is now inert');
    expect(offenders, isEmpty,
        reason: 'a failed future will show an endless spinner:\n'
            '${offenders.join("\n")}');
  });
}
