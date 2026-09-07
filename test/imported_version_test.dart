/// bwh47 — the reader's own Bible, `docs/PARITY-BACKLOG.md` §3.7.
///
/// The row was BLOCKED on a question and the owner answered it on
/// 2026-09-07: build the plain local importer. These are the guards on
/// the two things the row warned about — that it must not shadow a
/// bundled edition, and that it must not let the app assert a licence it
/// does not have — plus the validation, which is the part that decides
/// whether a bad file is a message or a corrupted app.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/book_names.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/version_attribution.dart';
import 'package:seeksparks/utils/imported_version.dart';

String fileOf(List<Map<String, Object>> rows) => json.encode(rows);

final oneVerse = fileOf([
  {'book': 'Genesis', 'chapter': '1', 'verse': '1', 'text': 'In the beginning'},
]);

void main() {
  group('an import can never be mistaken for a shipped edition', () {
    test('every code carries the prefix', () {
      expect(importedVersionCode('My Bible'), startsWith('user-'));
      expect(isImportedVersion(importedVersionCode('My Bible')), isTrue);
    });

    test('and no bundled edition uses it', () {
      // The invariant the prefix exists for. If a catalog row ever took
      // it, imported and shipped texts would be indistinguishable by
      // code, which is the only thing several surfaces have to go on.
      expect(bundledCodesAvoidImportedPrefix(), isTrue);
    });

    test('naming an import "KJV" does not shadow the KJV', () {
      final code = importedVersionCode('KJV');
      expect(code, 'user-kjv');
      expect(isKnownVersion(code), isFalse);
      expect(isKnownVersion('kjv'), isTrue);
      final r = parseImportedVersion(oneVerse, 'KJV');
      expect(r.ok, isTrue);
      expect(r.version!.code, 'user-kjv');
    });

    test('two imports cannot take the same code', () {
      final r = parseImportedVersion(oneVerse, 'My Bible',
          existingCodes: {'user-my-bible'});
      expect(r.ok, isFalse);
      expect(r.problem, ImportProblem.nameTaken);
    });

    test('a name of only punctuation still yields a usable code', () {
      expect(importedVersionCode('!!!'), 'user-text');
    });
  });

  group('the licence is disclaimed, never asserted', () {
    test('the disclaimer string exists in all three locales', () {
      // `version_attribution.dart`: a future edition must "fail by
      // omitting a line rather than by asserting a licence it does not
      // have". An imported text has no licence this app can verify, so
      // what it carries is a disclaimer.
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final v = uiStrings[kImportedAttributionKey]?[locale];
        expect(v, isNotNull, reason: locale);
        expect(v!.trim(), isNotEmpty, reason: locale);
      }
    });

    test('an imported code is not in the unrestricted-copy set', () {
      // The 500-verse ceiling applies. Copying an unknown text in
      // unlimited quantity is the one outcome worse than not importing
      // it.
      expect(unrestrictedCopyVersions.contains('user-my-bible'), isFalse);
      for (final code in unrestrictedCopyVersions) {
        expect(isImportedVersion(code), isFalse, reason: code);
      }
    });
  });

  group('validation refuses far more than it accepts', () {
    test('a good file parses', () {
      final r = parseImportedVersion(oneVerse, 'My Bible');
      expect(r.ok, isTrue);
      expect(r.version!.verseCount, 1);
      expect(r.version!.label, 'My Bible');
      expect(r.version!.books, {'Genesis'});
    });

    test('an empty name and an empty file are told apart', () {
      expect(parseImportedVersion(oneVerse, '  ').problem,
          ImportProblem.nameEmpty);
      expect(parseImportedVersion('   ', 'x').problem, ImportProblem.empty);
    });

    test('not JSON, and JSON that is not a list', () {
      expect(parseImportedVersion('{oh dear', 'x').problem,
          ImportProblem.notJson);
      expect(parseImportedVersion('{"a":1}', 'x').problem,
          ImportProblem.notAList);
      expect(parseImportedVersion('[]', 'x').problem, ImportProblem.noVerses);
    });

    test('a row that is not a record says WHICH row', () {
      final r = parseImportedVersion('[1,2,3]', 'x');
      expect(r.problem, ImportProblem.badRecord);
      expect(r.detail, 'row 0');
    });

    test('a text field that is not a string is refused', () {
      // The one that would otherwise reach the reading pane and render
      // as `{}` — or crash it.
      final r = parseImportedVersion(
        fileOf([
          {'book': 'Genesis', 'chapter': '1', 'verse': '1', 'text': 42}
        ]),
        'x',
      );
      expect(r.problem, ImportProblem.badRecord);
    });

    test('chapter and verse must be positive numbers', () {
      for (final bad in const ['0', '-1', 'one', '']) {
        final r = parseImportedVersion(
          fileOf([
            {'book': 'Genesis', 'chapter': bad, 'verse': '1', 'text': 't'}
          ]),
          'x',
        );
        expect(r.problem, ImportProblem.badRecord, reason: bad);
      }
    });

    test('a book outside the canon is refused, and named', () {
      // Not pedantry: a book this app cannot navigate to would appear as
      // an edition whose chapters the reader can never reach.
      final r = parseImportedVersion(
        fileOf([
          {'book': 'Hezekiah', 'chapter': '1', 'verse': '1', 'text': 't'}
        ]),
        'x',
      );
      expect(r.problem, ImportProblem.unknownBook);
      expect(r.detail, 'Hezekiah');
    });

    test('the script is recorded from the file\'s own book names', () {
      // Found by testing on dev, not by the suite: an English import
      // showed 創世紀 beside its English text, because a version code
      // outside the const English set falls through to Chinese in
      // `bookScriptFor`. The validator already had to match every book
      // against a canon, so it knows which one answered — recording it
      // is free and guessing is not.
      expect(parseImportedVersion(oneVerse, 'x').version!.script, 'en');
      final zh = parseImportedVersion(
        fileOf([
          {'book': '创世记', 'chapter': '1', 'verse': '1', 'text': '起初'}
        ]),
        'x',
      );
      expect(zh.version!.script, 'zh-Hans');
    });

    test('a Chinese book name is accepted', () {
      // The feature would be English-only otherwise, in an app whose
      // first audience reads 和合本.
      final r = parseImportedVersion(
        fileOf([
          {'book': '创世记', 'chapter': '1', 'verse': '1', 'text': '起初'}
        ]),
        'x',
      );
      expect(r.ok, isTrue);
    });

    test('the same reference twice is refused', () {
      // A duplicate would give the reading pane two verse 1s and the
      // second would silently win.
      final r = parseImportedVersion(
        fileOf([
          {'book': 'Genesis', 'chapter': '1', 'verse': '1', 'text': 'a'},
          {'book': 'Genesis', 'chapter': '1', 'verse': '1', 'text': 'b'},
        ]),
        'x',
      );
      expect(r.problem, ImportProblem.duplicateReference);
      expect(r.detail, 'Genesis 1:1');
    });

    test('a file larger than any Bible is refused before it is decoded', () {
      // The parse runs on the UI isolate; an unbounded decode is a hang,
      // not an error message.
      final huge = 'x' * (kMaxImportChars + 1);
      expect(parseImportedVersion(huge, 'x').problem, ImportProblem.tooLarge);
    });
  });

  group('the accepted book names agree with the app\'s own canon', () {
    test('every English name the validator takes is a book the app knows',
        () {
      // The drift this stops: the validator holding its own list that
      // slowly stops matching the one navigation resolves against, so an
      // import is accepted and then unreachable.
      final r = parseImportedVersion(
        fileOf([
          for (final b in bookNameToEnglish.values.toSet())
            {'book': b, 'chapter': '1', 'verse': '1', 'text': 't'}
        ]),
        'x',
      );
      expect(r.ok, isTrue,
          reason: r.ok ? '' : '${r.problem} ${r.detail}');
      expect(r.version!.books, hasLength(66));
    });
  });
}


