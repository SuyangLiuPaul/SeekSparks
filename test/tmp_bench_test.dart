import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/book_groups.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/morph_search_service.dart';
import 'package:seeksparks/utils/morphology.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('naive vs correct', () async {
    var correct = 0, naive = 0;
    final examples = <String>[];
    for (final b in canonicalOtBooks) {
      final verses = await OriginalsService.versesOfBook(b);
      for (final ws in verses.values) {
        for (final w in ws) {
          final p = MorphSearchService.parse(w.morph);
          if (p == null) continue;
          final ok = p.morphemes.any((m) =>
              m.pos == 'V' && m.slots[MorphSlot.gender] == 'f');
          final loose = p.morphemes.any((m) => m.pos == 'V') &&
              p.morphemes.any((m) => m.slots[MorphSlot.gender] == 'f');
          if (ok) correct++;
          if (loose) naive++;
          if (loose && !ok && examples.length < 4) examples.add(w.morph!);
        }
      }
    }
    // ignore: avoid_print
    print('NAIVE correct=$correct naive=$naive examples=$examples');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
