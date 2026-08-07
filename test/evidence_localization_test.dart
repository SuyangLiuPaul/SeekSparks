/// 2026-08-08 (#283): the Bible Evidence archive stores every book name
/// and every scripture reference in ENGLISH, because that is the key the
/// data is joined on. Six surfaces across `evidence_page.dart` and
/// `evidence_detail_page.dart` printed that key straight to the reader —
/// including `_ReferenceChip`, the one control on the detail page that
/// takes you back to the text, which had accepted a `locale` parameter
/// since the day it was written and never used it.
///
/// These tests would have caught it. They assert on the rendered text,
/// not on the mapper, because the mapper was always correct — what was
/// missing was the call.
///
/// The rule under test is `bookScriptFor`'s: the READING VERSION picks
/// the spelling, not the UI locale. So a Chinese UI on KJV must still
/// say "Genesis", and that case gets its own test — a naive fix that
/// keys off the locale passes the first two tests and fails this one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/bible_evidence.dart';
import 'package:seeksparks/pages/evidence_detail_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localeAwareBookName, localizedReferenceLabel;

/// No images, so the widget tree never reaches `Image.network` and the
/// test does not need an HTTP override.
const BibleEvidence _tel = BibleEvidence(
  id: 'test-tel-dan',
  category: 'Archaeology',
  bibleBooks: <String>['1 Kings'],
  timeline: '9th Century BCE',
  discoveryDate: '1993',
  location: 'Tel Dan',
  scriptureReference: 'Genesis 1:1',
  images: <String>[],
  academicSources: <String>['Biran & Naveh, IEJ 43 (1993)'],
  confidenceLevel: 'Strong',
  icon: 'x',
  title: <String, String>{'en': 'Tel Dan Stele', 'zh-Hans': '但丘石碑'},
  summary: <String, String>{'en': 'summary', 'zh-Hans': '摘要'},
  description: <String, String>{'en': 'description', 'zh-Hans': '描述'},
  scripturalCorrelation: <String, String>{'en': 'corr', 'zh-Hans': '对应'},
);

Future<void> _mount(
  WidgetTester tester, {
  required String locale,
  required String version,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1280, 900);
  SharedPreferences.setMockInitialValues(<String, Object>{});

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final mp = MainProvider(storagePrefix: 'evidence_l10n_test_');
          mp.currentVersion = version;
          return mp;
        }),
        ChangeNotifierProvider(create: (_) {
          final settings = AppSettings();
          // ignore: unawaited_futures
          settings.setLocale(locale);
          return settings;
        }),
      ],
      child: const MaterialApp(
        home: EvidenceDetailPage(evidence: _tel),
      ),
    ),
  );
  // Real disk I/O never completes under `testWidgets`' fake-async zone,
  // so pump a bounded number of frames instead of `pumpAndSettle`.
  // The window has to clear `AppSettings.notifyListeners`' 600 ms
  // debounce, or the test ends with that timer still pending.
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// `find.textContaining` only reaches `Text` widgets; the reference chip
/// and the category row are both plain `Text`, which is the point.
bool _renders(String needle) =>
    find.textContaining(needle, findRichText: true).evaluate().isNotEmpty;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('detail page prints Simplified book names on a Chinese version',
      (tester) async {
    await _mount(tester, locale: 'zh-Hans', version: 'cuvs-yhwh');

    expect(_renders('创世纪 1:1'), isTrue,
        reason: 'the reference chip must localise the book name');
    expect(_renders('Genesis'), isFalse,
        reason: 'no surface may print the raw English data key');
    expect(_renders('考古'), isTrue, reason: 'category must be localised');
    expect(_renders('Archaeology'), isFalse);
  });

  testWidgets('detail page prints Traditional book names on a -tr version',
      (tester) async {
    await _mount(tester, locale: 'zh-Hant', version: 'cuvs-yhwh-tr');

    expect(_renders('創世紀 1:1'), isTrue);
    expect(_renders('Genesis'), isFalse);
  });

  testWidgets('the reading version wins over the UI locale', (tester) async {
    // A Chinese UI reading KJV: the chip has to agree with the verse
    // text on screen, so it says Genesis.
    await _mount(tester, locale: 'zh-Hans', version: 'kjv');

    expect(_renders('Genesis 1:1'), isTrue);
    expect(_renders('创世纪'), isFalse);
  });

  test('the scoped-archive header has a slot for the book name', () {
    // The header used to be built by concatenating `evidenceForBook`
    // with the raw `filterBook`, because the string had no placeholder
    // to put it in. A template without `{book}` cannot be localised.
    for (final locale in const <String>['zh-Hans', 'zh-Hant', 'en']) {
      final template = uiStrings['evidenceForBook']![locale]!;
      expect(template, contains('{book}'), reason: 'locale $locale');
    }

    expect(
      uiStrings['evidenceForBook']!['zh-Hans']!.replaceAll(
          '{book}', localeAwareBookName('Genesis', 'zh-Hans', 'cuvs-yhwh')),
      '经文实证 — 创世纪',
    );
  });

  test('multi-book references localise every segment', () {
    // `BibleEvidence.scriptureReference` is `;`-separated for finds
    // that touch more than one book; a fix that only handled the first
    // segment would leave English in the middle of the label.
    expect(
      localizedReferenceLabel(
          'Matthew 5:3-12; Luke 6:20-23', 'zh-Hans', 'cuvs-yhwh'),
      '马太福音 5:3-12; 路加福音 6:20-23',
    );
    // Unparseable segments pass through rather than vanish.
    expect(localizedReferenceLabel('Multiple Books', 'zh-Hans', 'cuvs-yhwh'),
        'Multiple Books');
  });
}
