import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/services/tagged_text_service.dart';

void main() {
  late List<dynamic> plain;
  late Map<String, String> textById;

  setUpAll(() {
    plain = jsonDecode(File('assets/cuv-yhwd.json').readAsStringSync()) as List;
    textById = {
      for (final row in plain.cast<Map<String, dynamic>>())
        row['id'] as String: row['text'] as String,
    };
  });

  test('CUV YahwehDeHua is registered as a tagged Simplified edition', () {
    final info = bibleVersions.singleWhere((v) => v.value == 'cuv-yhwd');
    expect(info.language, 'zh-Hans');
    expect(info.menuLabel, contains("Strong's"));
    expect(TaggedTextService.supports(info.value), isTrue);
  });

  test('full export has one unique record for every canonical verse', () {
    expect(plain.length, 31102);
    expect(textById.length, 31102);
    expect(textById['001001001'], '起初，神创造天地。');
    expect(textById['019023001'], '（大卫的诗。）雅伟是我的牧者，我必不致缺乏。');
    expect(textById['019119105'], '你的话是我脚前的灯，是我路上的光。');
    expect(textById['043003016'], contains('独生子'));
    expect(textById['043003016'], contains('不至灭亡'));
    expect(textById['066022021'], '愿主耶稣的恩惠常与众圣徒同在。阿们！');
  });

  test('Genesis, Psalms and Greek NT tags reassemble to displayed text', () {
    final samples = <(String, String, String)>[
      ('genesis', '1:1', '001001001'),
      ('psalms', '23:1', '019023001'),
      ('psalms', '119:105', '019119105'),
      ('john', '3:16', '043003016'),
      ('romans', '8:1', '045008001'),
    ];
    for (final (book, ref, id) in samples) {
      final verses = jsonDecode(
          File('assets/tagged/cuv-yhwd/$book.json').readAsStringSync()) as Map;
      final runs = (verses[ref] as List).cast<Map<String, dynamic>>();
      expect(runs.map((r) => r['w']).join(), textById[id],
          reason: '$book $ref');
      final prefix = int.parse(id.substring(0, 3)) >= 40 ? 'G' : 'H';
      expect(
        runs.where((r) => (r['s'] as String).isNotEmpty).every(
              (r) => (r['s'] as String).startsWith(prefix),
            ),
        isTrue,
        reason: '$book $ref must carry $prefix numbers',
      );
    }
  });

  test('all 66 tagged book files exist', () {
    expect(Directory('assets/tagged/cuv-yhwd').listSync().whereType<File>(),
        hasLength(66));
  });
}
