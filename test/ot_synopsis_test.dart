/// The Old Testament half of the synopsis, on the same surface as the
/// gospel harmony.
///
/// Checked through SynopsisService rather than against the asset,
/// because the point of the change is that ONE service answers for both
/// testaments — a reader in 2 Chronicles 26 should be told about 2 Kings
/// 15 exactly the way a reader in Matthew 5 is told about Luke 6.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/synopsis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an OT chapter with a parallel returns it', () async {
    // Uzziah's reign: 2 Chronicles 26, 2 Kings 15, Isaiah 1.
    final events = await SynopsisService.byChapter('2 Chronicles', 26);
    expect(events, isNotEmpty,
        reason: '2 Chronicles 26 is one of the best-attested OT '
            'parallels; an empty result means the book index is not '
            'being built or byChapter is not falling through to it');
    final titles = events.map((e) => e.localizedTitle('en')).join(' | ');
    expect(titles.toLowerCase(), contains('uzziah'));
  });

  test('the parallel names the other books, not just this one', () async {
    final events = await SynopsisService.byChapter('2 Chronicles', 26);
    final uzziah = events.firstWhere(
        (e) => e.localizedTitle('en').toLowerCase().contains('uzziah'));
    // A group that only names the book you are already reading tells
    // you nothing — that was the failure mode when refs were keyed
    // wrongly.
    expect(uzziah.rawRef('2 Kings'), isNotNull);
    expect(uzziah.referenceFor('2 Kings')?.englishBook, '2 Kings');
  });

  test('titles carry both languages', () async {
    final events = await SynopsisService.byChapter('Exodus', 12);
    expect(events, isNotEmpty);
    final e = events.first;
    expect(e.localizedTitle('en'), isNotEmpty);
    expect(e.localizedTitle('zh-Hans'), isNotEmpty);
    expect(e.localizedTitle('zh-Hans'), isNot(e.localizedTitle('en')));
  });

  test('hasSynopsis covers both testaments, and declines the rest',
      () async {
    expect(await SynopsisService.hasSynopsis('Matthew'), isTrue);
    expect(await SynopsisService.hasSynopsis('2 Chronicles'), isTrue);
    // Philemon has neither a gospel harmony nor an OT parallel.
    expect(await SynopsisService.hasSynopsis('Philemon'), isFalse);
  });

  test('the credit travels with the data', () async {
    await SynopsisService.byChapter('2 Chronicles', 26);
    expect(SynopsisService.otAttribution, contains("Eagle's View"));
  });

  test('a group naming one book twice keeps both passages', () async {
    // "Benjamin's Descendants" is 1 Chronicles 8:1-9:1 AND 9:34-44.
    // Keying passages by book kept only the second, which is how 37 of
    // the 313 passages went missing.
    final events = await SynopsisService.byChapter('1 Chronicles', 8);
    final benjamin = events.firstWhere(
        (e) => e.localizedTitle('en').toLowerCase().contains('benjamin'));
    final inChronicles = benjamin.passages
        .where((p) => p.book == '1 Chronicles')
        .toList();
    expect(inChronicles.length, 2,
        reason: 'both 1 Chronicles passages must survive, not just the '
            'last one read');
    expect(inChronicles.map((p) => p.raw),
        containsAll(['1 Chronicles 8:1-9:1', '1 Chronicles 9:34-44']));
  });

  test('a group is listed once even when two of its passages match',
      () async {
    // Chapter 9 falls inside 8:1-9:1 and inside 9:34-44. The reader
    // should see the group once.
    final events = await SynopsisService.byChapter('1 Chronicles', 9);
    final ids = events.map((e) => e.id).toList();
    expect(ids.length, ids.toSet().length, reason: 'duplicate entries');
  });

  test('a passage that crosses a chapter covers the far chapter',
      () async {
    // Zedekiah's reign is 2 Kings 24:18-25:30. Before endChapter
    // existed this was stored as 24:18-30 and a reader in chapter 25
    // was told nothing.
    final ch25 = await SynopsisService.byChapter('2 Kings', 25);
    expect(ch25.map((e) => e.localizedTitle('en')).join(' | ').toLowerCase(),
        contains('zedekiah'));
    final v = await SynopsisService.byVerse('2 Kings', 25, 30);
    expect(v.map((e) => e.localizedTitle('en')).join(' | ').toLowerCase(),
        contains('zedekiah'));
  });

  test('a span does not swallow verses before it starts', () async {
    // 2 Kings 24:18-25:30 starts at verse 18; verse 17 is outside it.
    final inside = await SynopsisService.byVerse('2 Kings', 24, 18);
    final before = await SynopsisService.byVerse('2 Kings', 24, 17);
    bool zedekiah(List<SynopsisEvent> l) => l
        .any((e) => e.localizedTitle('en').toLowerCase().contains('zedekiah'));
    expect(zedekiah(inside), isTrue);
    expect(zedekiah(before), isFalse);
  });

  test('the gospel harmony spans chapters too', () async {
    // "John 18:28-19:16" — the trial before Pilate. Indexed as the
    // single verse John 18:28 until endChapter existed.
    final events = await SynopsisService.byVerse('John', 19, 16);
    expect(events, isNotEmpty,
        reason: 'John 19:16 is the last verse of the trial before '
            'Pilate and must find the entry that covers it');
  });

  test('every OT passage carries the book it names', () async {
    // The chip label strips the book name off the front of `raw`; a
    // passage whose raw does not start with its book would render as
    // the untouched string.
    final events = await SynopsisService.byChapter('2 Chronicles', 26);
    for (final e in events) {
      for (final p in e.passages) {
        expect(p.raw, startsWith(p.book));
        expect(p.reference?.englishBook, p.book);
      }
    }
  });
}
