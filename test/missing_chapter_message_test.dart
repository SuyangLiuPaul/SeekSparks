/// 2026-08-08 (task #285, with #283 riding along): the centre pane's
/// "this edition does not have that chapter" screen recommended a
/// version that does not exist.
///
/// It read `请切换到包含此章节的版本（如 CUVS-YHWH / CNV）`. `CNV` was
/// removed from the catalog in 2026-08; `CUVS-YHWH` is an internal code.
/// The screen also printed the raw English book name into a Chinese
/// sentence and answered Traditional readers in Simplified.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/utils/missing_chapter_message.dart';

void main() {
  // The case that actually produces this screen: 梁家铿译本 ships the NT
  // only, so any OT bookmark lands here.
  group('the suggestion names a real, selectable edition', () {
    test('an NT-only Simplified edition points at its Simplified sibling',
        () {
      final msg = missingChapterMessage(
        book: 'Psalms',
        chapter: 23,
        locale: 'zh-Hans',
        currentVersion: 'biblexg-v2',
      );
      expect(msg, contains(shortBibleVersionLabel('cuvs-yhwh'))); // 雅简+
      expect(msg, contains('诗篇'));
    });

    // Script has to survive the recommendation: sending a Traditional
    // reader to a Simplified edition is a worse answer than none.
    test('an NT-only Traditional edition points at its Traditional sibling',
        () {
      final msg = missingChapterMessage(
        book: 'Psalms',
        chapter: 23,
        locale: 'zh-Hant',
        currentVersion: 'biblexg-v2-tr',
      );
      expect(msg, contains(shortBibleVersionLabel('cuvs-yhwh-tr'))); // 雅繁+
      expect(msg, isNot(contains(shortBibleVersionLabel('cuvs-yhwh'))));
    });

    // The bug, stated directly. Neither token may ever come back.
    test('it never prints CNV or a raw internal code', () {
      for (final v in bibleVersions) {
        final msg = missingChapterMessage(
          book: 'Psalms',
          chapter: 23,
          locale: 'zh-Hans',
          currentVersion: v.value,
        );
        expect(msg, isNot(contains('CNV')));
        expect(msg, isNot(contains('CUVS-YHWH')));
        expect(msg, isNot(contains(v.value)));
      }
    });

    // Only NT-only editions have a provable full-canon sibling. For the
    // rest the honest answer is the generic one — inventing a name is
    // exactly how `CNV` got onto the screen.
    test('a full-canon edition gets the generic advice, not a guess', () {
      final msg = missingChapterMessage(
        book: 'Psalms',
        chapter: 23,
        locale: 'zh-Hans',
        currentVersion: 'cuvs-yhwh',
      );
      expect(bibleVersionFullCanonFallback('cuvs-yhwh'), isNull);
      expect(msg, contains('请切换到包含此章节的版本'));
    });
  });

  group('the message is localised', () {
    test('a Traditional reader is not answered in Simplified', () {
      final msg = missingChapterMessage(
        book: 'Psalms',
        chapter: 23,
        locale: 'zh-Hant',
        currentVersion: 'biblexg-v2-tr',
      );
      expect(msg, contains('目前版本沒有'));
      expect(msg, isNot(contains('当前版本')));
    });

    test('English stays English', () {
      final msg = missingChapterMessage(
        book: 'Psalms',
        chapter: 23,
        locale: 'en',
        currentVersion: 'kjv',
      );
      expect(msg, contains('Psalms 23'));
      expect(msg, contains('not available'));
    });
  });

  // #283's rule, which a fix keyed off `locale` alone would break: the
  // READING VERSION picks the book-name script, not the UI language.
  group('the book name follows the reading version', () {
    test('a Chinese UI reading KJV is still told about Psalms', () {
      final msg = missingChapterMessage(
        book: 'Psalms',
        chapter: 23,
        locale: 'zh-Hans',
        currentVersion: 'kjv',
      );
      expect(msg, contains('Psalms'));
      expect(msg, isNot(contains('诗篇')));
    });

    test('a Traditional edition gets the Traditional spelling', () {
      final msg = missingChapterMessage(
        book: 'Psalms',
        chapter: 23,
        locale: 'zh-Hant',
        currentVersion: 'biblexg-v2-tr',
      );
      expect(msg, contains('詩篇'));
    });
  });
}
