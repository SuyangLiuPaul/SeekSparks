// The search results list marks the word a Strong's query matched.
//
// This is the half that could not be checked by eye: driving the version
// picker in a canvas-rendered app under synthetic clicks did not work, so
// the marking is pinned here instead — which is the better place for it
// anyway, because it also fails if someone later removes the marking.

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/search_highlight.dart';

List<({String text, String strongs})> runs(List<List<String>> pairs) =>
    [for (final p in pairs) (text: p[0], strongs: p[1])];

void main() {
  const h430 = SearchHighlight(strongsNumbers: {'H430'});

  test('an untagged edition marks nothing, and says so with null', () {
    expect(
      strongsSnippetSpans(
          preview: 'In the beginning God created the heavens and the earth.',
          runs: null,
          highlight: h430),
      isNull,
    );
  });

  test('a tagged verse marks the run that carries the number', () {
    final spans = strongsSnippetSpans(
      preview: 'In the beginning God created the heavens and the earth.',
      runs: runs([
        ['In the beginning', 'H7225'],
        ['God', 'H430'],
        ['created', 'H1254'],
      ]),
      highlight: h430,
    );
    expect(spans, isNotNull);
    expect(spans!.where((s) => s.isHit).map((s) => s.text), ['God']);
    // The pieces must tile the preview — the row does not re-check this.
    expect(spans.map((s) => s.text).join(),
        'In the beginning God created the heavens and the earth.');
  });

  test('a verse whose runs carry no matching number marks nothing', () {
    expect(
      strongsSnippetSpans(
        preview: 'Then God said',
        runs: runs([
          ['Then', 'H559'],
          ['said', 'H559'],
        ]),
        highlight: h430,
      ),
      isNull,
    );
  });

  test('the known cost: a repeated word marks both occurrences', () {
    final spans = strongsSnippetSpans(
      preview: 'God saw that the light was good, and God separated',
      runs: runs([
        ['God', 'H430'],
        ['saw', 'H7200'],
      ]),
      highlight: h430,
    );
    // Only the first God is the tagged run, but the second reads the same
    // and the preview has no offsets to tell them apart. Marking both is
    // the accepted trade — see strongsSnippetSpans' doc comment.
    expect(spans!.where((s) => s.isHit).length, 2);
  });

  test('a wildcard query marks through the same path', () {
    final spans = strongsSnippetSpans(
      preview: 'God created',
      runs: runs([
        ['God', 'H4300'],
      ]),
      highlight: const SearchHighlight(strongsPrefixes: {'H430'}),
    );
    expect(spans!.where((s) => s.isHit).map((s) => s.text), ['God']);
  });
}
