import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/book_groups.dart';
import 'package:seeksparks/constants/book_names.dart' show standardBookOrder;
import 'package:seeksparks/constants/ui_strings.dart';

/// 2026-09-13: 「sword显示book没有分开旧约和新约」.
///
/// The picker already had a testament toggle; what it lacked was any
/// structure INSIDE a testament, so 39 books ran on as one list. Both
/// views now group under the canonical divisions, ported from YsWords.
/// These pin the table itself — every canonical book exactly once, in
/// canonical order — and that both views actually use it.
void main() {
  test('the ten divisions cover the 66 books exactly once, in order', () {
    final seen = <String>[];
    for (final d in kBibleDivisions) {
      seen.addAll(d.books);
    }
    expect(seen.length, 66);
    expect(seen.toSet().length, 66, reason: 'no book in two divisions');
    expect(seen, standardBookOrder.take(66).toList(),
        reason: 'division order is canonical order — a reader scanning '
            'Law → History → Poetry → Prophets must not find Ruth after '
            'Kings');
  });

  test('the OT/NT split of the table agrees with the testament sets', () {
    for (final d in kBibleDivisions) {
      for (final b in d.books) {
        expect(oldTestamentBooks.contains(b), d.oldTestament,
            reason: '$b sits under ${d.id}');
      }
    }
  });

  test('every division has a header string in all three locales', () {
    for (final id in [...kBibleDivisions.map((d) => d.id), 'divOther']) {
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        expect(uiStrings[id]?[locale], isNotNull, reason: '$id / $locale');
      }
    }
    expect(uiStrings['booksUnit']?['en'], isNotNull);
  });

  test('both picker views group through the one table', () {
    final src =
        File('lib/widgets/book_chapter_picker.dart').readAsStringSync();
    // Each view walks `_divisionsFor` and draws a `_divisionHeader`; a
    // view that stopped doing so would silently be the flat list again.
    expect('_divisionsFor(filteredBooks)'.allMatches(src).length, 2,
        reason: 'the list view and the grid view');
    expect(src.contains("out.add(('divOther', unplaced))"), isTrue,
        reason: 'a book the table does not know is still shown');
  });
}
