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
}
