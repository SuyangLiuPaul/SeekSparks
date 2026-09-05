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

  _boot();
}

/// THE SAME BLANK PANE, ONE FRAME EARLIER.
///
/// `setVersion` is not the only thing that moves a reader between
/// corpora. `restoreState` does it twice — the v1.3.46 en-locale
/// migration off `cuvs-yhwh`, and `resolveReadingVersion` substituting a
/// retired code — and it restores the saved BOOK separately. The
/// realign call sat in the version branch, above the line that assigns
/// the book, so it ran with `currentBook` still null and returned on its
/// own first line every single time. The boot path realigned nothing,
/// and the reader who was migrated got the blank pane on launch instead
/// of on a version switch.
///
/// These drive `restoreState` with the prefs an affected device
/// actually holds, which is the only way to see it: the state is set
/// up by one branch and broken by another, so neither half is wrong on
/// its own.
void _boot() {
  test('boot: the v1.3.46 migration does not strand a Chinese book '
      'in an English corpus', () async {
    // What an en-locale device that has never run the migration holds:
    // the pre-v1.3.40 class default, and a book spelled the way that
    // edition spells it.
    SharedPreferences.setMockInitialValues({
      'locale': 'en',
      'version': 'cuvs-yhwh',
      'book': '创世纪',
      'chapter': 1,
    });
    final mp = MainProvider();
    await mp.restoreState();

    expect(mp.currentVersion, localeDefaultVersion('en'),
        reason: 'precondition — the migration is what makes the pair '
            'disagree, so if it stops firing this test proves nothing');
    expect(mp.currentBook, 'Genesis',
        reason: 'the migration moved the reader to an English corpus; a '
            'book left spelled 创世纪 matches no verse in it and the '
            'pane boots BLANK');
  });

  test('boot: a book and version that already agree are left alone',
      () async {
    SharedPreferences.setMockInitialValues({
      'locale': 'zh-Hans',
      'version': 'cuvs-yhwh',
      'book': '创世纪',
      'chapter': 1,
    });
    final mp = MainProvider();
    await mp.restoreState();
    expect(mp.currentVersion, 'cuvs-yhwh');
    expect(mp.currentBook, '创世纪');
  });

  test('boot: a retired code is carried to its successor with its book',
      () async {
    // `cuv` → `cuvs-yhwh`, same language, so this pins that the realign
    // does not MANGLE a book on the substitution path. Every successor
    // row is same-language today; the row that crosses languages is the
    // one this guard is waiting for.
    SharedPreferences.setMockInitialValues({
      'locale': 'zh-Hans',
      'version': 'cuv',
      'book': '约翰福音',
      'chapter': 3,
    });
    final mp = MainProvider();
    await mp.restoreState();
    expect(mp.currentVersion, 'cuvs-yhwh');
    expect(mp.currentBook, '约翰福音');
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
