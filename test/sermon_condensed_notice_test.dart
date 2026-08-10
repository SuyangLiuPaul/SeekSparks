// Ten sermons hold a Chinese body that is a summary of the English
// rather than a translation of it — roughly a tenth of the length, in
// ordinary prose, ending with a proper closing line. Nothing about them
// reads as broken, which is exactly the problem: a reader quotes a
// summary as the preaching. They cannot be repaired without
// re-translating ~85,000 words, so the app says what the text is.
//
// The sentence is built by a pure function so it can be checked here
// without a widget tree. What it must never do is stay silent on a
// condensed body, or speak up on a complete one.

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/sermon.dart';
import 'package:seeksparks/pages/sermon_detail_page.dart'
    show sermonCondensedNotice, sermonLanguageName;

Sermon _sermon({Set<String> condensed = const {}}) => Sermon(
      id: '126',
      topic: 'The Parables of Jesus',
      topicSlug: 'The Parables of Jesus',
      date: '1981-01-11',
      parts: 'A/B',
      passage: 'Mt 20:1-16',
      title: 'The principle of first and last',
      titles: const {'en': 'The Principle of First and Last'},
      hasEn: true,
      hasZhCn: true,
      hasZhTw: true,
      condensed: condensed,
    );

void main() {
  group('the reader is told when the text is a summary', () {
    test('a complete body says nothing', () {
      final s = _sermon(condensed: const {'zh-CN', 'zh-TW'});
      expect(sermonCondensedNotice(s, 'en', 'en'), isNull);
      expect(sermonCondensedNotice(_sermon(), 'zh-CN', 'zh-Hans'), isNull);
    });

    test('no body selected yet says nothing', () {
      // The page renders once before the first load resolves.
      final s = _sermon(condensed: const {'zh-CN'});
      expect(sermonCondensedNotice(s, null, 'zh-Hans'), isNull);
    });

    test('a condensed body names itself and points at the whole sermon', () {
      final s = _sermon(condensed: const {'zh-CN', 'zh-TW'});
      final zh = sermonCondensedNotice(s, 'zh-CN', 'zh-Hans')!;
      expect(zh, contains('内容摘要'));
      expect(zh, contains('英文'));
      final zht = sermonCondensedNotice(s, 'zh-TW', 'zh-Hant')!;
      expect(zht, contains('內容摘要'));
    });

    test('the sentence follows the UI locale, not the body language', () {
      // Reading the Chinese body with an English interface is normal.
      final s = _sermon(condensed: const {'zh-CN', 'zh-TW'});
      final en = sermonCondensedNotice(s, 'zh-CN', 'en')!;
      expect(en, contains('condensed summary'));
      expect(en, contains('English'));
    });

    test('it does not promise a full text that does not exist', () {
      final s = _sermon(condensed: const {'en', 'zh-CN', 'zh-TW'});
      final only = sermonCondensedNotice(s, 'zh-CN', 'zh-Hans')!;
      expect(only, contains('内容摘要'));
      expect(only, isNot(contains('完整讲道见')));
    });

    test('a Chinese sentence does not end in the word English', () {
      expect(sermonLanguageName('en', 'zh-Hans'), '英文');
      expect(sermonLanguageName('en', 'zh-Hant'), '英文');
      expect(sermonLanguageName('en', 'en'), 'English');
      expect(sermonLanguageName('zh-TW', 'en'), 'Traditional Chinese');
    });
  });

  group('the marker survives the index', () {
    test('an unmarked record parses as complete', () {
      final s = Sermon.fromJson(const {
        'id': '004',
        'topic': 'Baptism',
        'topicSlug': 'Baptism',
        'date': '1979-04-08',
        'title': 'Temptation after baptism (2)',
        'hasEn': true,
        'hasZhCn': true,
        'hasZhTw': true,
      });
      expect(s.condensed, isEmpty);
      expect(s.fullBodyLanguages, ['en', 'zh-CN', 'zh-TW']);
    });

    test('a marked record parses and reports where the sermon is whole', () {
      final s = Sermon.fromJson(const {
        'id': '126',
        'topic': 'The Parables of Jesus',
        'topicSlug': 'The Parables of Jesus',
        'date': '1981-01-11',
        'title': 'The principle of first and last',
        'hasEn': true,
        'hasZhCn': true,
        'hasZhTw': true,
        'condensed': ['zh-CN', 'zh-TW'],
      });
      expect(s.condensed, {'zh-CN', 'zh-TW'});
      expect(s.fullBodyLanguages, ['en']);
    });
  });
}
