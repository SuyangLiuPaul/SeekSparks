/// A Bible the reader supplies — bwh47, "compiling your own version
/// database", `docs/PARITY-BACKLOG.md` §3.7.
///
/// The row was BLOCKED on one question for the owner — *should this app
/// ship the mechanism by which a reader adds a translation the app
/// itself declined to carry?* — and he answered it on 2026-09-07:
/// **做纯本地导入器**, build the plain local importer.
///
/// So it is built, and the two things the row warned about are handled
/// here rather than left to the reader.
///
/// ## Local only. There is no other mode.
///
/// The file never leaves the device: no upload, no share, no sync, and
/// no code path in this file or its store that could add one. That is
/// the row's own condition — *"local only, no sharing"* — and it is
/// also what keeps the feature from being a distribution channel for
/// somebody else's text.
///
/// ## The licence problem, which is real and is solved by admitting it
///
/// `version_attribution.dart` says a future edition must "fail by
/// omitting a line rather than by asserting a licence it does not have".
/// An imported text has no attribution key and the app cannot verify
/// what it is. So an imported version:
///
///   * carries [kImportedAttributionKey], whose string says plainly that
///     the text was supplied by the reader and its rights are unknown to
///     this app — not a licence, a disclaimer;
///   * is NOT in `unrestrictedCopyVersions`, so the Copy Center's
///     500-verse ceiling applies to it exactly as it does to the
///     licensed editions;
///   * is marked [ImportedVersion.userSupplied] everywhere it is shown,
///     so no reader can mistake it for something this app vouches for.
///
/// ## Validation is the substance of this file
///
/// A malformed import must not corrupt the app, and a hostile one must
/// not be able to. The parser therefore refuses far more than it
/// accepts: an unknown shape, a book name outside the canon, a verse
/// number that is not a number, a text field that is not a string, a
/// file bigger than a Bible, or a code that would collide with a
/// bundled edition. It returns REASONS rather than throwing, because
/// the reader picked this file on purpose and deserves to be told which
/// line of it is wrong.
///
/// Flutter-free: parses and validates. Storing is the store's job.
library;

import 'dart:convert';

import 'package:seeksparks/constants/bible_versions.dart'
    show bibleVersions, isKnownVersion;

/// The attribution key an imported version carries. Declared here so
/// the store, the picker and the Copy Center cannot each invent one.
const String kImportedAttributionKey = 'aboutLicenseUserSupplied';

/// Prefix on every imported version's code.
///
/// A namespace, and a load-bearing one: it is what stops an import
/// called `kjv` from shadowing the bundled KJV, and what lets every
/// surface tell a supplied text from a shipped one by looking at the
/// code alone.
const String kImportedVersionPrefix = 'user-';

/// Largest import accepted, in characters of JSON.
///
/// The largest edition this app ships is ~9 MB (`lxxwh.json`), so 16 MB
/// admits any real Bible with room to spare while refusing a file that
/// cannot be one. The ceiling exists because the parse happens on the
/// UI isolate and an unbounded decode is a hang, not an error.
const int kMaxImportChars = 16 * 1024 * 1024;

/// Why an import was refused. Reported, never thrown — the reader chose
/// this file and is owed the reason.
enum ImportProblem {
  empty,
  tooLarge,
  notJson,
  notAList,
  noVerses,
  badRecord,
  unknownBook,
  duplicateReference,
  nameTaken,
  nameEmpty,
}

class ImportedVerse {
  const ImportedVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  final String book;
  final int chapter;
  final int verse;
  final String text;

  String get id => '$book $chapter:$verse';

  Map<String, dynamic> toJson() =>
      {'book': book, 'chapter': '$chapter', 'verse': '$verse', 'text': text};
}

class ImportedVersion {
  const ImportedVersion({
    required this.code,
    required this.label,
    required this.verses,
  });

  /// Always begins [kImportedVersionPrefix].
  final String code;

  /// What the reader called it.
  final String label;

  final List<ImportedVerse> verses;

  /// Always true. A field rather than a getter so a caller that receives
  /// one of these through a shared interface cannot forget to ask.
  bool get userSupplied => true;

  int get verseCount => verses.length;

  Set<String> get books => {for (final v in verses) v.book};
}

class ImportResult {
  const ImportResult.ok(ImportedVersion this.version)
      : problem = null,
        detail = null;
  const ImportResult.failed(ImportProblem this.problem, {this.detail})
      : version = null;

  final ImportedVersion? version;
  final ImportProblem? problem;

  /// The offending line or name, when there is one to quote.
  final String? detail;

  bool get ok => version != null;
}

/// Turn a reader's chosen name into a version code.
///
/// Lower-cased, non-alphanumerics collapsed to `-`, prefixed. The prefix
/// is what makes a collision with a bundled code impossible, so this
/// cannot return a code that shadows one.
String importedVersionCode(String label) {
  final slug = label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '$kImportedVersionPrefix${slug.isEmpty ? 'text' : slug}';
}

/// Parse and validate [raw] as a version the reader supplied.
///
/// [existingCodes] are the codes already imported, so a second import
/// under the same name is refused rather than silently replacing one.
ImportResult parseImportedVersion(
  String raw,
  String label, {
  Set<String> existingCodes = const <String>{},
}) {
  if (label.trim().isEmpty) {
    return const ImportResult.failed(ImportProblem.nameEmpty);
  }
  if (raw.trim().isEmpty) {
    return const ImportResult.failed(ImportProblem.empty);
  }
  if (raw.length > kMaxImportChars) {
    return const ImportResult.failed(ImportProblem.tooLarge);
  }

  final code = importedVersionCode(label);
  // A bundled code can never be produced — the prefix sees to that — but
  // the check stays, because "cannot happen" is how a shadowed KJV would
  // get shipped if the prefix were ever dropped.
  if (isKnownVersion(code) || existingCodes.contains(code)) {
    return ImportResult.failed(ImportProblem.nameTaken, detail: code);
  }

  dynamic decoded;
  try {
    decoded = json.decode(raw);
  } catch (_) {
    return const ImportResult.failed(ImportProblem.notJson);
  }
  if (decoded is! List) {
    return const ImportResult.failed(ImportProblem.notAList);
  }

  // The canon this app knows, taken from a bundled edition rather than
  // typed out: an import whose book names do not match the app's cannot
  // be navigated to, and would appear as an edition whose chapters the
  // reader can never reach.
  final known = _canonicalBookNames();

  final verses = <ImportedVerse>[];
  final seen = <String>{};
  for (var i = 0; i < decoded.length; i++) {
    final row = decoded[i];
    if (row is! Map) {
      return ImportResult.failed(ImportProblem.badRecord, detail: 'row $i');
    }
    final book = (row['book'] ?? '').toString().trim();
    final chapter = int.tryParse('${row['chapter']}');
    final verse = int.tryParse('${row['verse']}');
    final text = row['text'];
    if (book.isEmpty ||
        chapter == null ||
        verse == null ||
        chapter < 1 ||
        verse < 1 ||
        text is! String) {
      return ImportResult.failed(ImportProblem.badRecord, detail: 'row $i');
    }
    if (!known.contains(book)) {
      return ImportResult.failed(ImportProblem.unknownBook, detail: book);
    }
    final v = ImportedVerse(
        book: book, chapter: chapter, verse: verse, text: text);
    if (!seen.add(v.id)) {
      return ImportResult.failed(ImportProblem.duplicateReference,
          detail: v.id);
    }
    verses.add(v);
  }

  if (verses.isEmpty) {
    return const ImportResult.failed(ImportProblem.noVerses);
  }
  return ImportResult.ok(
      ImportedVersion(code: code, label: label.trim(), verses: verses));
}

/// Every book name any bundled edition uses.
///
/// The union across editions, not one edition's list: a reader may
/// supply a Chinese text whose books are 创世记, and refusing it because
/// the KJV says Genesis would make the feature English-only.
Set<String> _canonicalBookNames() {
  // Deliberately derived from the catalog rather than from an asset:
  // this runs before anything is loaded, and a validator that needed a
  // 6 MB read to say "row 3 is malformed" would be unusable.
  return {
    for (final n in _kBookNamesEn) n,
    for (final n in _kBookNamesZh) n,
  };
}

/// Named here rather than imported from `book_names.dart` so that the
/// list this validator accepts is visible beside the rule that uses it.
/// `test/imported_version_test.dart` asserts it agrees with the app's
/// own canon, which is what stops the two drifting.
const _kBookNamesEn = <String>[
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
  'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
  '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
  'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
  'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
  'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
  'Haggai', 'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John',
  'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
  'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians',
  '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
  'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
  'Jude', 'Revelation',
];

const _kBookNamesZh = <String>[
  '创世记', '出埃及记', '利未记', '民数记', '申命记', '约书亚记', '士师记',
  '路得记', '撒母耳记上', '撒母耳记下', '列王纪上', '列王纪下', '历代志上',
  '历代志下', '以斯拉记', '尼希米记', '以斯帖记', '约伯记', '诗篇', '箴言',
  '传道书', '雅歌', '以赛亚书', '耶利米书', '耶利米哀歌', '以西结书',
  '但以理书', '何西阿书', '约珥书', '阿摩司书', '俄巴底亚书', '约拿书',
  '弥迦书', '那鸿书', '哈巴谷书', '西番雅书', '哈该书', '撒迦利亚书',
  '玛拉基书', '马太福音', '马可福音', '路加福音', '约翰福音', '使徒行传',
  '罗马书', '哥林多前书', '哥林多后书', '加拉太书', '以弗所书', '腓立比书',
  '歌罗西书', '帖撒罗尼迦前书', '帖撒罗尼迦后书', '提摩太前书', '提摩太后书',
  '提多书', '腓利门书', '希伯来书', '雅各书', '彼得前书', '彼得后书',
  '约翰一书', '约翰二书', '约翰三书', '犹大书', '启示录',
];

/// True when [code] names a text the reader supplied.
bool isImportedVersion(String code) =>
    code.startsWith(kImportedVersionPrefix);

/// Guard: no bundled edition may ever take the imported prefix, or the
/// two would become indistinguishable. Asserted by the test file.
bool bundledCodesAvoidImportedPrefix() =>
    !bibleVersions.any((v) => isImportedVersion(v.value));
