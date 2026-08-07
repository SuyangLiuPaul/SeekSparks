import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/book_groups.dart';
import 'package:seeksparks/services/originals_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bench: load a testament and scan every code', () async {
    for (final entry in [
      ('NT', canonicalNtBooks),
      ('OT', canonicalOtBooks),
    ]) {
      final sw = Stopwatch()..start();
      var words = 0;
      var withCode = 0;
      var bytes = 0;
      for (final b in entry.$2) {
        final verses = await OriginalsService.versesOfBook(b);
        for (final ws in verses.values) {
          for (final w in ws) {
            words++;
            if (w.morph != null && w.morph!.isNotEmpty) withCode++;
          }
        }
      }
      final loadMs = sw.elapsedMilliseconds;

      // Scan: naive per-word split, worst case.
      sw.reset();
      var hits = 0;
      for (final b in entry.$2) {
        final verses = await OriginalsService.versesOfBook(b);
        for (final ws in verses.values) {
          for (final w in ws) {
            final c = w.morph;
            if (c == null || c.isEmpty) continue;
            if (c.length == 10 && !c.contains('/')) {
              if (c.codeUnitAt(5) == 0x44) hits++; // imperative mood
            } else {
              for (final m in c.substring(1).split('/')) {
                if (m.isNotEmpty && m.codeUnitAt(0) == 0x56) {
                  hits++;
                  break;
                }
              }
            }
          }
        }
      }
      final scanMs = sw.elapsedMilliseconds;
      // ignore: avoid_print
      print('${entry.$1}: load+parse ${loadMs}ms, words=$words '
          'withCode=$withCode, scan ${scanMs}ms, hits=$hits, b=$bytes');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
