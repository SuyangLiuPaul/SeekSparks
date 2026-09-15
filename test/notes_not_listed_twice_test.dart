// The edition carries every 「N節註」 twice; the reader shows it once.
//
// 2026-09-15, photographed with the whole block circled: 羅馬書 8:1-11
// in 梁家鏗 listed thirteen notes, of which five were the first eight
// over again — ⑨ was ①, ⑩ was ③, ⑪ was ⑥, ⑫ was ⑧, ⑬ was ④.
//
// Neither renderer was wrong on its own. Each 「N節註」 appears INLINE at
// its own position, and again in the `blockNotes` of the paragraph's
// last verse; the readers concatenate the two lists because
// `blockNotes` is where several editions keep apparatus that belongs to
// no single verse. For this edition it is mostly a second copy.
//
// This file works on the ASSET, so it measures the actual overlap
// rather than trusting a fixture — and it pins the part that makes the
// fix non-obvious: the two copies differ by whitespace, so nothing
// byte-exact finds them.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/widgets/verse_notes_block.dart' show dedupeNotes;

final _note = RegExp(r'<note:(.*?)>', dotAll: true);
String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

List<Map<String, dynamic>> _load(String code) =>
    (jsonDecode(File('assets/$code.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

void main() {
  late List<Map<String, dynamic>> ljk;

  setUpAll(() => ljk = _load('biblexg-v3'));

  test('the overlap is real, and it is most of the block notes', () {
    // The premise. If a future import stops doubling them this drops to
    // zero, and the dedupe becomes harmless rather than necessary —
    // worth knowing either way.
    final inlineByChapter = <String, Set<String>>{};
    for (final v in ljk) {
      inlineByChapter
          .putIfAbsent('${v['book']}|${v['chapter']}', () => <String>{})
          .addAll(_note.allMatches(v['text'] as String).map(
                (m) => _squash(m.group(1)!),
              ));
    }

    var total = 0;
    var duplicated = 0;
    for (final v in ljk) {
      for (final b in (v['blockNotes'] as List? ?? const [])) {
        total++;
        if (inlineByChapter['${v['book']}|${v['chapter']}']!
            .contains(_squash(b as String))) {
          duplicated++;
        }
      }
    }

    expect(total, greaterThan(500), reason: 'the edition lost its block notes');
    expect(duplicated / total, greaterThan(0.8),
        reason: 'only $duplicated of $total block notes are also inline — '
            'the doubling this fix exists for has changed shape');
    expect(total - duplicated, greaterThan(0),
        reason: 'if EVERY block note were a duplicate, the honest fix '
            'would be to stop reading `blockNotes` for this edition '
            'rather than to dedupe');
  });

  test('羅馬書 8:1-11 lists eight notes, not thirteen', () {
    // The exact block in the photograph.
    final group = [
      for (final v in ljk)
        if ((v['book'] == '罗马书' || v['book'] == '羅馬書') &&
            '${v['chapter']}' == '8' &&
            int.parse('${v['verse']}') <= 11)
          v,
    ];
    expect(group, isNotEmpty);

    final inline = <String>[
      for (final v in group)
        ..._note.allMatches(v['text'] as String).map((m) => m.group(1)!),
    ];
    final blocks = <String>[
      for (final v in group) ...(v['blockNotes'] as List? ?? const []).cast(),
    ];

    expect(inline, hasLength(8), reason: 'the verses themselves carry eight');
    expect(blocks, hasLength(5), reason: 'and five arrive again as apparatus');
    expect(inline.length + blocks.length, 13,
        reason: 'thirteen is the number that was on screen');
    expect(dedupeNotes([...inline, ...blocks]), hasLength(8),
        reason: 'the reader should show the eight that exist');
  });

  test('a note is not dropped just because another note contains it', () {
    // The failure mode a sloppier rule would introduce: 「参6.6。」 is a
    // substring of plenty of longer notes, and must survive on its own.
    expect(
      dedupeNotes(['参6.6。', '9节注：详见参6.6。以及其他。']),
      hasLength(2),
    );
  });
}
