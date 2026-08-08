// `ai <question>` as the workbench sees it.
//
// `ai_ref_resolution_test.dart` pins the join between the model's
// answer and the loaded edition. These pin everything AROUND that
// call, which is where the failures are quiet: an AI answer that
// leaves the previous Strong's hits on screen under a new header, a
// spinner that never stops because the service threw, a search limit
// the AI path forgot to honour, or an answer that never reaches the
// verse list the Copy Center and "limit to these results" read from.

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/services/ai_bible_search_service.dart';

const _seed = [
  Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning'),
  Verse(book: 'Philippians', chapter: 4, verse: 6, text: 'Be careful for nothing'),
  Verse(book: 'Philippians', chapter: 4, verse: 7, text: 'And the peace of God'),
  Verse(book: 'Matthew', chapter: 6, verse: 25, text: 'Take no thought'),
];

AiBibleRef _ref(String book, int chapter, int start, [int? end]) => AiBibleRef(
      book: book,
      chapter: chapter,
      verseStart: start,
      verseEnd: end ?? start,
      reason: 'because',
    );

WorkbenchProvider _wb({
  Future<AiBibleSearchResult> Function(String query)? ask,
}) {
  final mp = MainProvider()
    ..setVerses(_seed)
    ..currentVersion = 'kjv';
  return WorkbenchProvider(mainProvider: mp)..aiAsk = ask;
}

void main() {
  test('the answer becomes the ordinary result list too', () async {
    // Everything downstream — the Verse List Manager, "limit to these
    // results", copy-all — reads textResults. An AI answer that lives
    // only in its own field is a second-class result set.
    final wb = _wb(
        ask: (_) async => AiBibleSearchResult(
            refs: [_ref('Philippians', 4, 6, 7)], hits: 1));
    addTearDown(wb.dispose);
    await wb.runAiSearch(question: 'anxiety', locale: 'en');
    expect(wb.textResults.map((v) => v.verse), [6, 7]);
    expect(wb.aiRefs, hasLength(1));
    expect(wb.aiQuery, 'anxiety');
    expect(wb.searchPerformed, isTrue);
    expect(wb.aiBusy, isFalse);
  });

  test('a reference the edition lacks stays listed, marked', () async {
    final wb = _wb(
        ask: (_) async => AiBibleSearchResult(
            refs: [_ref('Philippians', 4, 6), _ref('Tobit', 4, 7)], hits: 2));
    addTearDown(wb.dispose);
    await wb.runAiSearch(question: 'anxiety', locale: 'en');
    expect(wb.aiRefs, hasLength(2), reason: 'never silently edit the answer');
    expect(wb.aiUnresolved, {'Tobit 4:7'});
    expect(wb.aiNotice, contains('1'));
  });

  test('an active search limit scopes the AI answer and says so', () async {
    final wb = _wb(
        ask: (_) async => AiBibleSearchResult(
            refs: [_ref('Philippians', 4, 6), _ref('Matthew', 6, 25)],
            hits: 2));
    addTearDown(wb.dispose);
    await wb.setSearchLimit({'Philippians-4-6', 'Philippians-4-7'}, 'Phil 4');
    await wb.runAiSearch(question: 'anxiety', locale: 'en');
    expect([for (final r in wb.aiRefs!) r.book], ['Philippians']);
    expect(wb.aiNotice, contains('outside'));
  });

  test('the answer replaces the previous results rather than joining them',
      () async {
    final wb = _wb(
        ask: (_) async =>
            AiBibleSearchResult(refs: [_ref('Philippians', 4, 6)], hits: 1));
    addTearDown(wb.dispose);
    await wb.runSearch('beginning');
    expect(wb.textResults, isNotEmpty);
    await wb.runAiSearch(question: 'anxiety', locale: 'en');
    expect(wb.strongsRefs, isNull);
    expect(wb.commandQuery, isNull);
    expect(wb.textResults.single.book, 'Philippians');
  });

  test('a plain search afterwards clears the AI answer', () async {
    final wb = _wb(
        ask: (_) async =>
            AiBibleSearchResult(refs: [_ref('Philippians', 4, 6)], hits: 1));
    addTearDown(wb.dispose);
    await wb.runAiSearch(question: 'anxiety', locale: 'en');
    await wb.runSearch('beginning');
    expect(wb.hasAiResults, isFalse);
    expect(wb.aiNotice, isNull);
  });

  test('an unavailable service reports why, and stops spinning', () async {
    final wb = _wb(
        ask: (_) async => AiBibleSearchResult.unavailable('quota exhausted'));
    addTearDown(wb.dispose);
    await wb.runAiSearch(question: 'anxiety', locale: 'en');
    expect(wb.aiRefs, isEmpty);
    expect(wb.aiNotice, 'quota exhausted');
    expect(wb.aiBusy, isFalse);
    expect(wb.searchPerformed, isTrue,
        reason: 'otherwise the reason renders behind the empty state');
  });

  test('a thrown exception still clears the busy flag', () async {
    // The pane shows a spinner while aiBusy; a stuck flag is a dead
    // search box with no way back short of a reload.
    final wb = _wb(ask: (_) async => throw StateError('boom'));
    addTearDown(wb.dispose);
    await expectLater(
        wb.runAiSearch(question: 'anxiety', locale: 'en'), throwsStateError);
    expect(wb.aiBusy, isFalse);
    expect(wb.searchPerformed, isTrue);
  });
}
