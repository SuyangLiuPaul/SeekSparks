import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/version_mapper.dart';

void main() {
  group('localizedReferenceLabel', () {
    test('single verse, English locale passes through unchanged', () {
      expect(localizedReferenceLabel('2 Samuel 5:9', 'en'), '2 Samuel 5:9');
    });

    test('single verse, Simplified Chinese locale translates the book', () {
      expect(localizedReferenceLabel('2 Samuel 5:9', 'zh-Hans'),
          '撒母耳记下 5:9');
    });

    test('single verse, Traditional Chinese locale translates the book', () {
      expect(localizedReferenceLabel('2 Samuel 5:9', 'zh-Hant'),
          '撒母耳記下 5:9');
    });

    test('verse range is preserved after localization', () {
      expect(localizedReferenceLabel('Genesis 1:1-3', 'zh-Hans'),
          '创世纪 1:1-3');
    });

    test('whole-chapter reference (no verse) is preserved', () {
      expect(localizedReferenceLabel('John 3', 'zh-Hans'), '约翰福音 3');
    });

    test('currentVersion overrides locale-driven book naming', () {
      // Traditional-script version name should win even under a
      // Simplified locale, matching localeAwareBookName's own
      // currentVersion precedence.
      expect(
          localizedReferenceLabel('Genesis 1:1', 'zh-Hans', 'cuvs-tr'),
          '創世紀 1:1');
    });

    test('multi-book reference localizes each segment', () {
      expect(
          localizedReferenceLabel(
              'Matthew 5:3-12; Luke 6:20-23', 'zh-Hans'),
          '马太福音 5:3-12; 路加福音 6:20-23');
    });

    test('unparseable segment falls back to the raw text unchanged', () {
      expect(localizedReferenceLabel('Multiple Books', 'zh-Hans'),
          'Multiple Books');
    });

    test('empty locale-independent default (no locale-specific mapping) keeps English', () {
      expect(localizedReferenceLabel('Genesis 1:1', 'fr'), 'Genesis 1:1');
    });
  });

  // A label may not claim less than the data said, nor more.
  //
  // `parseReference` keeps a landing place and discards the rest,
  // which is right for navigation and wrong for a printed label.
  // Re-rendering from the parse printed 79 references across
  // `bible_timeline.json`, `family_tree.json` and `bible_evidence.json`
  // narrower than they were written — and printed "Leviticus 1" for a
  // record that had said only "Leviticus", a chapter nobody claimed.
  group('the label never narrows the reference', () {
    test('a chapter range keeps both ends', () {
      expect(localizedReferenceLabel('Genesis 6-9', 'en'), 'Genesis 6-9');
      expect(localizedReferenceLabel('Genesis 6-9', 'zh-Hans'), '创世纪 6-9');
      expect(localizedReferenceLabel('Isaiah 1-66', 'zh-Hant'), '以賽亞書 1-66');
    });

    test('a range that crosses a chapter keeps the far end', () {
      expect(localizedReferenceLabel('2 Kings 9:2–10:36', 'zh-Hans'),
          '列王纪下 9:2–10:36');
      expect(localizedReferenceLabel('1 Kings 11:43-12:24', 'en'),
          '1 Kings 11:43-12:24');
    });

    test('a second, non-adjacent range is not dropped', () {
      expect(localizedReferenceLabel('Luke 1:5-25, 57-80', 'zh-Hans'),
          '路加福音 1:5-25, 57-80');
    });

    test('a bare book stays a bare book', () {
      expect(localizedReferenceLabel('Leviticus', 'en'), 'Leviticus');
      expect(localizedReferenceLabel('Leviticus', 'zh-Hans'), '利未记');
    });

    // The guard is on narrowing only. A one-chapter book states a
    // verse, not a chapter, and saying so is a correction rather than
    // an invention — this must keep going through the ordinary path.
    test('Jude 11 still becomes Jude 1:11', () {
      expect(localizedReferenceLabel('Jude 11', 'en'), 'Jude 1:11');
      expect(localizedReferenceLabel('Jude 14-15', 'zh-Hans'), '犹大书 1:14-15');
    });

    test('an abbreviation is still expanded', () {
      expect(localizedReferenceLabel('1 Cor 13', 'en'), '1 Corinthians 13');
    });

    // The sweep, so a new asset cannot quietly reintroduce the class.
    // Every reference in every shipped asset must print an extent with
    // the same digits it was written with, except where a one-chapter
    // book supplies the chapter.
    test('no shipped reference is printed narrower than it was written',
        () {
      const oneChapter = {'Jude', 'Obadiah', 'Philemon', '2 John', '3 John'};
      final tail = RegExp(r'[\d:,–\-\s]+$');
      final offenders = <String>[];
      for (final raw in _shippedReferences()) {
        final en = localizedReferenceLabel(raw, 'en');
        if (oneChapter.any(raw.startsWith)) continue;
        String digits(String s) =>
            (tail.firstMatch(s)?.group(0) ?? '').replaceAll(RegExp(r'\D'), '');
        if (digits(en) != digits(raw)) offenders.add('$raw -> $en');
      }
      expect(offenders, isEmpty);
    });
  });
}

/// Every reference-shaped string in every shipped asset.
Iterable<String> _shippedReferences() sync* {
  const keys = {'ref', 'refs', 'datingRefs', 'reference', 'scriptureReference'};
  final out = <String>[];
  void walk(Object? node) {
    if (node is Map) {
      for (final e in node.entries) {
        if (keys.contains(e.key)) {
          if (e.value is String) out.add(e.value as String);
          if (e.value is List) out.addAll((e.value as List).whereType<String>());
        } else {
          walk(e.value);
        }
      }
    } else if (node is List) {
      for (final v in node) {
        walk(v);
      }
    }
  }

  for (final f in Directory('assets')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))) {
    try {
      walk(json.decode(f.readAsStringSync()));
    } on FormatException {
      continue;
    }
  }
  yield* out;
}
