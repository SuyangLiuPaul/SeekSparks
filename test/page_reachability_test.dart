// A page nobody can open is invisible to every other kind of test.
//
// Task #281 found three of them. `DashboardPage` stopped being the app's
// front door when `main.dart` made `WorkbenchPage` the root — a
// deliberate change — but nothing pointed at the Dashboard afterwards,
// so it and the two pages reachable only through it (`FamilyTreePage`,
// `FeedbackPage`) fell off the navigation graph together. 4,508 lines
// went dark and the suite stayed green, because every test that touches
// those pages constructs them directly.
//
// This test walks the import graph from `lib/main.dart` and asserts that
// the set of unreachable pages is exactly [_knownOrphans]. Import edges
// over-approximate reachability (a file can be imported without its page
// being pushed), which is the safe direction: this test never cries wolf,
// it only catches a page that has become unreachable outright.
//
// Two ways to make it pass, and the difference is the point:
//   • You orphaned a page by accident  -> wire it up, or delete it.
//   • You orphaned one on purpose      -> add it here WITH a reason, and
//     record it in docs/DELETION-REVIEW.md.
// Shrinking [_knownOrphans] to empty is the goal.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pages that are currently unreachable from `main.dart`, and why.
///
/// Every entry is a pending product decision, not an accident. See
/// docs/DELETION-REVIEW.md for the full write-up of each.
const Map<String, String> _knownOrphans = {
  'lib/pages/dashboard_page.dart':
      'The Workbench replaced it as the app root. Keeping or cutting the '
          'home screen is a product decision (task #281).',
  'lib/pages/family_tree_page.dart':
      'Reachable only from the Dashboard. Falls with it.',
  'lib/pages/feedback_page.dart':
      'Reachable only from the Dashboard. Falls with it.',
};

/// Matches a plain import and both halves of a conditional one:
///
///     import 'foo_stub.dart'
///         if (dart.library.io) 'foo_io.dart'
///         if (dart.library.js_interop) 'foo_web.dart';
///
/// Missing the `if (...)` arms would report every platform-split service
/// as an orphan, which is exactly the false alarm that makes a test like
/// this get deleted instead of fixed.
final RegExp _importedPath = RegExp(r"""'((?:package:seeksparks/|\./|\.\./)?[A-Za-z0-9_./]+\.dart)'""");

void main() {
  test('every page is reachable from main.dart', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue,
        reason: 'test must run from the package root');

    final sources = <String, String>{};
    for (final e in lib.listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.dart')) {
        sources[e.path.replaceAll(r'\', '/')] = e.readAsStringSync();
      }
    }

    Set<String> importsOf(String path, String src) {
      final out = <String>{};
      for (final line in src.split('\n')) {
        final trimmed = line.trimLeft();
        // Stop at the first declaration: past that, a quoted `.dart`
        // is a string literal or a doc comment, not an edge.
        if (trimmed.startsWith('class ') || trimmed.startsWith('void main(')) {
          break;
        }
        if (!trimmed.startsWith('import ') &&
            !trimmed.startsWith('export ') &&
            !trimmed.startsWith('if (')) {
          continue;
        }
        for (final m in _importedPath.allMatches(line)) {
          var target = m.group(1)!;
          if (target.startsWith('package:seeksparks/')) {
            target = 'lib/${target.substring('package:seeksparks/'.length)}';
          } else if (target.startsWith('.')) {
            final dir = path.substring(0, path.lastIndexOf('/'));
            target = _normalise('$dir/$target');
          } else {
            continue; // another package
          }
          if (sources.containsKey(target)) out.add(target);
        }
      }
      return out;
    }

    const root = 'lib/main.dart';
    final reached = <String>{root};
    final queue = <String>[root];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final next in importsOf(current, sources[current]!)) {
        if (reached.add(next)) queue.add(next);
      }
    }

    final orphans = sources.keys
        .where((p) => p.startsWith('lib/pages/') && !reached.contains(p))
        .toList()
      ..sort();

    expect(
      orphans,
      _knownOrphans.keys.toList()..sort(),
      reason: 'A page under lib/pages/ is unreachable from main.dart.\n'
          'If that was deliberate, add it to _knownOrphans with a reason '
          'and write it up in docs/DELETION-REVIEW.md.\n'
          'If it was not, something stopped pointing at it — find out what.',
    );
  });

  test('the reachability walk actually reaches the real pages', () {
    // Guards the test above against silently passing because the walk
    // found nothing: a broken regex would report every page as an orphan,
    // and a walk that reached everything would report none. Both are
    // failures of the instrument rather than of the app, so pin a page
    // that is unambiguously live.
    final src = File('lib/main.dart').readAsStringSync();
    expect(src.contains('workbench_page.dart'), isTrue,
        reason: 'main.dart no longer imports the Workbench — if the app '
            'root moved, this test\'s starting point has to move with it.');
  });
}

String _normalise(String path) {
  final parts = <String>[];
  for (final segment in path.split('/')) {
    if (segment == '.' || segment.isEmpty) continue;
    if (segment == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(segment);
  }
  return parts.join('/');
}
