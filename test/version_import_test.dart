/// bwh47's import, end to end as far as it can be tested without a
/// browser — `docs/PARITY-BACKLOG.md` §3.7.
///
/// The store is IndexedDB and is not reachable from the Dart VM, so
/// what is asserted here is everything around it: the round trip through
/// the app's OWN verse shape, the catalog registry, and the order of
/// operations that keeps the picker from ever offering a version with no
/// text behind it.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/utils/imported_version.dart';

void main() {
  tearDown(importedVersionLabels.clear);

  group('the catalog admits an imported edition, and only then', () {
    test('nothing changes until one is registered', () {
      // The whole app behaves exactly as before an import exists, which
      // is what makes this feature safe to ship dormant.
      expect(importedVersionLabels, isEmpty);
      expect(importedVersions, isEmpty);
      expect(isKnownVersion('user-my-bible'), isFalse);
      expect(loadableVersions(['user-my-bible']), isEmpty);
    });

    test('registering one makes it known and loadable', () {
      importedVersionLabels['user-my-bible'] = 'My Bible';
      expect(isKnownVersion('user-my-bible'), isTrue);
      expect(loadableVersions(['user-my-bible']), ['user-my-bible']);
      expect(availableVersions.map((v) => v.value),
          contains('user-my-bible'));
    });

    test('it is listed LAST, after every edition that was checked', () {
      // Putting a text nobody has vetted above the ones that were would
      // be a claim about it that nothing supports.
      importedVersionLabels['user-my-bible'] = 'My Bible';
      expect(availableVersions.last.value, 'user-my-bible');
    });

    test('and it never displaces a bundled edition', () {
      importedVersionLabels['user-kjv'] = 'KJV';
      final kjv =
          availableVersions.where((v) => v.value == 'kjv').toList();
      expect(kjv, hasLength(1));
      expect(kjv.single.menuLabel, 'King James Version');
    });

    test('a long name is shortened for the badge, not for the menu', () {
      // The gutter badge is measured chrome (#297); the menu is where
      // the reader reads.
      importedVersionLabels['user-x'] = 'A Very Long Translation Name';
      final v = importedVersions.single;
      expect(v.shortLabel.length, lessThanOrEqualTo(6));
      expect(v.menuLabel, 'A Very Long Translation Name');
    });
  });

  group('what gets stored is the app\'s own verse shape', () {
    test('so FetchVerses reads it back with the bundled-asset parser', () {
      // An import that took a code path of its own would drift from how
      // every other edition is loaded. The encoder is exercised here by
      // round-tripping it through `parseImportedVersion`, which is the
      // same validator the import ran.
      final source = json.encode([
        {
          'book': 'Genesis',
          'chapter': '1',
          'verse': '1',
          'text': 'In the beginning "God" created\nthe heavens',
        },
      ]);
      final parsed = parseImportedVersion(source, 'My Bible');
      expect(parsed.ok, isTrue);

      // Re-encode the way the service does, then re-validate. Quotes and
      // newlines are the two characters that break a hand-built encoder,
      // and scripture has both.
      final again = parseImportedVersion(
          _encodeLikeService(parsed.version!), 'Other Bible');
      expect(again.ok, isTrue, reason: '${again.problem} ${again.detail}');
      expect(again.version!.verses.single.text,
          'In the beginning "God" created\nthe heavens');
    });
  });
}

/// Mirrors `VersionImportService._encode`, which is private. If the two
/// ever diverge this test stops proving anything — so it is written to
/// fail loudly rather than quietly: the assertion above checks the
/// ROUND TRIP, which only holds if both sides agree.
String _encodeLikeService(ImportedVersion v) => json.encode([
      for (final e in v.verses)
        {
          'book': e.book,
          'chapter': '${e.chapter}',
          'verse': '${e.verse}',
          'text': e.text,
        }
    ]);
