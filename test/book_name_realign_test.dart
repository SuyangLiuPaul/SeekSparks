/// Switching versions must carry the book across the language boundary.
///
/// Each corpus keys book names in its own language — cuvs-plus/cuvs-yhwh
/// on 创世纪, bsb/kjv on "Genesis". The reading pane filters by
/// `currentBook`, so a Chinese name left in place when the reader moves
/// to an English version matches no verse and the pane renders BLANK:
/// no error, no empty state, toolbar and pickers still showing the right
/// reference. It shipped to prod and took the whole verse-driven Analysis
/// column with it.
///
/// A widget test would not have caught it — this is state, not layout,
/// and the corpora are real assets. So the check is on the provider.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/utils/version_mapper.dart' show translateBookName;

void main() {
  // setVersion persists through saveCurrentState(), which needs a binding
  // and a prefs store. Neither is what is under test here.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  _guard();

  test('setVersion re-expresses the book in the new corpus language', () {
    final mp = MainProvider();

    mp.currentBook = '创世纪';
    mp.setVersion('bsb');
    expect(mp.currentBook, 'Genesis',
        reason: 'a Chinese book name carried into an English corpus '
            'matches no verse — the pane goes blank');

    mp.setVersion('cuvs-plus');
    expect(mp.currentBook, '创世纪',
        reason: 'and back again, or the Chinese corpus goes blank');
  });

  test('round-trips through several switches without drifting', () {
    final mp = MainProvider()..currentBook = '约翰福音';
    for (final v in ['kjv', 'cuvs-yhwh', 'bsb', 'cuvs-plus', 'kjv']) {
      mp.setVersion(v);
      expect(mp.currentBook, isNotEmpty);
    }
    // Ends on an English version, so it must read as English.
    expect(mp.currentBook, 'John');
  });

  test('leaves an unset book alone rather than inventing one', () {
    final mp = MainProvider()..currentBook = null;
    mp.setVersion('bsb');
    expect(mp.currentBook, isNull);
  });
}

/// The set that caused the outage, guarded directly.
///
/// `_englishVersionCodes` in book_name_mapping.dart is hand-maintained,
/// and its own comment warns that a missing entry routes an English
/// version through the Chinese mapping. That warning was there when bsb,
/// kjvs and lxxwh were added to the catalog without being added to it —
/// a comment is not a check. This is the check: every non-Chinese
/// edition in the catalog must round-trip its book name unchanged.
void _guard() {
  test('every non-Chinese version keeps English book names', () {
    for (final v in bibleVersions) {
      if (v.language.startsWith('zh')) continue;
      expect(translateBookName('Genesis', v.value), 'Genesis',
          reason: '${v.value} (${v.language}) is not in '
              '_englishVersionCodes, so toLocale routes it through the '
              'Chinese table. Its corpus keys books in English, so the '
              'reading pane will match no verses and render blank.');
    }
  });
}
