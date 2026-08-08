/// 2026-08-07 (SeekSparks): the OTHER half of the BibleWorks command
/// line — help topics bwh44 ("Command Line Shortcuts") and bwh16
/// ("Miscellaneous Command Line Items").
///
/// v1.6.19 taught this box the query grammar (`.love god`, `'in the
/// beginning`). That is the half everybody screenshots. The half that
/// made BibleWorks *fast* is the other one: the command line is not a
/// search field with commands bolted on, it is the keyboard interface
/// to the whole workspace. A fluent user never touches the mouse —
/// they type `p bsb nas kjv` to restack the Browse window, `l gen` to
/// scope the next search to Genesis, `17` to jump down the chapter.
/// The GUI exists so you can discover those; the command line is how
/// you actually work.
///
///     d nas         add NASB to the Browse stack
///     d -nas        remove it
///     d c           clear the stack back to the search version
///     d english     add every English edition
///     p a b c       replace the stack with exactly a, b, c
///     p             switch the centre pane to Browse
///     l gen         limit searches to Genesis
///     l nt          limit to the New Testament
///     l matt 5-7    limit to a chapter range
///     l             lift the limit
///     3:16          chapter 3 verse 16 OF THE CURRENT BOOK
///     17            verse 17 OF THE CURRENT CHAPTER
///     ai <question> ask for passages by describing them
///
/// ## What a naive reading of "add a command verb" would miss
///
/// * **`d` is not one command, it is a set editor with four arities.**
///   The token after it is polymorphic: a version, a `-`-prefixed
///   version, the literal `c`, or a language name. They cannot be
///   resolved in any order — `c` has to be checked before version
///   lookup or a future edition abbreviated "C" would shadow "clear".
/// * **The search version can never leave the display.** BibleWorks
///   defines `d c` as "clears the display of all versions *except the
///   search version*", which makes it an invariant rather than a
///   default. SeekSparks' Browse frame already enforces it by
///   prepending `currentVersion` to the stack — so a naive `d -kjv`
///   while reading the KJV would remove it from storage, the frame
///   would silently put it back, and the reader would be told nothing.
///   That case is refused by name here instead.
/// * **`p` is not `d` three times.** `d` is incremental, `p` replaces,
///   and `p` carries an ORDER that the versions dialog cannot express
///   (a checkbox list has no order — it re-sorts into registry order).
///   The command line is therefore strictly more expressive than the
///   GUI it shadows, which is the whole point of having one.
/// * **A bare number is a VERSE, not a chapter.** bwh44 is explicit:
///   "Enter verse only → displays the specified verse in the current
///   chapter". It reads wrong until you notice what it is for — you
///   type it while reading, and while reading you are already in the
///   chapter you want.
///
/// ## Deliberately not implemented, and why (detected, not guessed)
///
/// * `d fav` / `o fav` — display "favourites" are named, saved version
///   sets. There is no UI here to create one, and a verb that can only
///   ever fail is worse than no verb. Its absence also removes a real
///   ambiguity: with favourites, `d c` is ambiguous the moment somebody
///   names a favourite "c".
/// * `f c` / `f u` / `f a` — filter results by their check boxes. The
///   results list here has no check boxes; the verb is meaningless
///   until it does.
/// * `t #` — bwh44 calls it "sets the current context tab". BibleWorks'
///   Browse window has a tab strip; SeekSparks' does not, and mapping
///   the number onto the Analysis tabs instead would be inventing a
///   meaning the help does not carry. Left alone rather than guessed
///   at — and the numbers would rot anyway: this app has appended to
///   that tab list eight times.
/// * `l <file>.vls` — verse-list files. SeekSparks already has verse
///   lists, in the Verse List Manager, which can already act as a
///   search limit. Recognised here so the reader is pointed there
///   rather than told "Vls is not a book".
///
/// The division of labour that falls out: **`l` scopes by book and
/// chapter, the Verse List Manager scopes by verse.** So this file
/// deliberately stops at chapter granularity — `l john 3:16` is not
/// accepted, because it would be a second, worse way to do something
/// that already exists.
///
/// Flutter-free on purpose: this parses and validates, nothing else.
library;

import 'package:seeksparks/constants/book_groups.dart'
    show canonicalOtBooks, canonicalNtBooks;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/reference_parser.dart'
    show BibleReference, resolveBookName;

// ── Context ─────────────────────────────────────────────────────────

/// One edition, as much of it as the verb parser needs.
class VerbVersion {
  const VerbVersion({
    required this.code,
    required this.label,
    required this.language,
  });

  /// Internal code (`kjv`, `cuvs-yhwh`).
  final String code;

  /// Short display label (`KJV`, `雅简+`) — also accepted as input.
  /// Tokens split on whitespace only, so the `+` that a Chinese label
  /// ends in survives the tokeniser and `d 雅简+` resolves.
  final String label;

  /// Language group (`en`, `zh-Hans`, `zh-Hant`, `grc`).
  final String language;
}

/// Everything a verb needs to know about the workspace it is addressing.
class VerbContext {
  const VerbContext({
    required this.versions,
    required this.searchVersion,
    required this.displayVersions,
    this.currentEnglishBook,
    this.currentChapter,
  });

  final List<VerbVersion> versions;

  /// The edition being read and searched. SeekSparks does not separate
  /// the two (BibleWorks does); see the note on [CommandVerbKind.displayClear].
  final String searchVersion;

  /// The EFFECTIVE Browse stack — search version first, then the
  /// comparison editions. Not the stored list: the Browse frame
  /// prepends the search version, so validating against storage would
  /// let `d -kjv` "succeed" invisibly.
  final List<String> displayVersions;

  /// Canonical English book name the reader is currently in, for
  /// relative references. Null when nothing is loaded.
  final String? currentEnglishBook;

  final int? currentChapter;

  /// `nas`, `NASB`, `kjv` → that edition's code, else null.
  String? resolveVersion(String token) {
    final q = token.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final v in versions) {
      if (v.code.toLowerCase() == q || v.label.toLowerCase() == q) {
        return v.code;
      }
    }
    return null;
  }

  /// Every edition in a language group, in registry order.
  List<String> versionsInLanguage(String language) =>
      [for (final v in versions) if (v.language == language) v.code];

  String labelFor(String code) {
    for (final v in versions) {
      if (v.code == code) return v.label;
    }
    return code;
  }
}

// ── Search limits ───────────────────────────────────────────────────

/// One contiguous piece of a search limit, at BOOK or CHAPTER
/// granularity. Verse granularity is the Verse List Manager's job.
class LimitRange {
  const LimitRange(this.englishBook, {this.firstChapter, this.lastChapter});

  final String englishBook;

  /// Null means the whole book.
  final int? firstChapter;

  /// Null with a non-null [firstChapter] means that single chapter.
  final int? lastChapter;

  bool covers(String book, int chapter) {
    if (book != englishBook) return false;
    final first = firstChapter;
    if (first == null) return true;
    return chapter >= first && chapter <= (lastChapter ?? first);
  }

  String get label {
    final first = firstChapter;
    if (first == null) return englishBook;
    final last = lastChapter;
    if (last == null || last == first) return '$englishBook $first';
    return '$englishBook $first–$last';
  }
}

/// A whole search limit: several ranges, unioned, plus what to call it.
class LimitSpec {
  const LimitSpec(this.ranges, this.label, {this.labelKey});

  final List<LimitRange> ranges;

  /// Fallback name for the limit banner. Book names are canonical
  /// English and are re-localised where they are displayed.
  final String label;

  /// A `uiStrings` key, set only for the two whole-testament
  /// shorthands, so the banner can say 旧约 rather than "Old Testament".
  /// They are the only limits whose name is not simply a book name.
  final String? labelKey;

  bool covers(String englishBook, int chapter) =>
      ranges.any((r) => r.covers(englishBook, chapter));
}

// ── Verbs ───────────────────────────────────────────────────────────

enum CommandVerbKind {
  /// `d nas` — append editions to the Browse stack.
  displayAdd,

  /// `d -nas` — drop editions from the Browse stack.
  displayRemove,

  /// `d c` — back to the search version alone. Named after BibleWorks'
  /// own wording, "clears the display of all versions except search
  /// version", which is where the always-displayed invariant comes from.
  displayClear,

  /// `p a b c` — replace the stack with exactly these, in this order.
  displaySet,

  /// bare `p` — switch the centre pane to Browse without restacking.
  browseOn,

  /// `l gen` — scope subsequent searches.
  limitSet,

  /// bare `l` — lift the scope.
  limitClear,

  /// `3:16` / `17` — a reference completed from where the reader is.
  goToReference,

  /// `ai 关于焦虑的经文` — describe the passages you want.
  ///
  /// The only verb here with no BibleWorks equivalent, and the only one
  /// whose answer does not come out of the loaded corpus. It sits on the
  /// command line rather than behind a button because the line is
  /// already where the other nine ways of asking a question live, and
  /// because the reader who reaches for it has usually just watched a
  /// literal search return the wrong verses.
  askAi,
}

class CommandVerb {
  const CommandVerb(
    this.kind, {
    this.versions = const [],
    this.limit,
    this.reference,
    this.aiQuery,
  });

  final CommandVerbKind kind;

  /// Resolved edition codes, in the order the reader typed them.
  final List<String> versions;

  final LimitSpec? limit;
  final BibleReference? reference;

  /// Everything after `ai `, verbatim — it is a question in the
  /// reader's own words, so nothing here parses or normalises it.
  final String? aiQuery;
}

/// Why a verb-shaped line was refused.
///
/// Every one of these is a thing the reader should be TOLD, by name.
/// The alternative — falling through to the text search — is the worst
/// outcome available: `d niv` would run a substring scan for "d niv",
/// find nothing, and leave the reader believing the verb does not exist.
enum CommandVerbIssue {
  /// `d` with nothing after it.
  displayNeedsArgument,

  /// A token in a `d` / `p` argument names no bundled edition.
  unknownVersion,

  /// `d -kjv` while the KJV is the version being read.
  cannotRemoveSearchVersion,

  /// `d nas` when NASB is already stacked.
  alreadyDisplayed,

  /// `d -nas` when it is not.
  notDisplayed,

  /// `l <something that is not a book, chapter range or testament>`.
  unknownScope,

  /// `l revelation 30` — parsed fine, matches nothing in the loaded
  /// edition. Raised by the caller, which is the only party that can
  /// see the corpus.
  emptyScope,

  /// `17` with no chapter loaded to complete it from.
  noCurrentPassage,

  /// `l notes.vls` — verse-list files live in the Verse List Manager.
  verseListFileUnsupported,
}

/// Parse outcome. [verb] and [issue] are never both set; both null
/// means "not a verb", and the caller should carry on to references and
/// search exactly as before.
class CommandVerbParse {
  const CommandVerbParse.none()
      : verb = null,
        issue = null,
        detail = '';
  const CommandVerbParse.run(CommandVerb this.verb)
      : issue = null,
        detail = '';
  const CommandVerbParse.refuse(CommandVerbIssue this.issue,
      [this.detail = ''])
      : verb = null;

  final CommandVerb? verb;
  final CommandVerbIssue? issue;

  /// The offending token, echoed back in the message. A refusal that
  /// does not say WHICH word was wrong is barely better than silence.
  final String detail;

  bool get isVerb => verb != null || issue != null;
}

// ── Aliases ─────────────────────────────────────────────────────────

/// `zh` alone is deliberately absent: it does not say which script, and
/// picking one for the reader would be a guess about the thing they are
/// most likely to care about.
const Map<String, String> _languageAliases = {
  'en': 'en',
  'eng': 'en',
  'english': 'en',
  '英文': 'en',
  '英语': 'en',
  '英語': 'en',
  'zh-hans': 'zh-Hans',
  'hans': 'zh-Hans',
  'simplified': 'zh-Hans',
  '简体': 'zh-Hans',
  '简': 'zh-Hans',
  'zh-hant': 'zh-Hant',
  'hant': 'zh-Hant',
  'traditional': 'zh-Hant',
  '繁體': 'zh-Hant',
  '繁体': 'zh-Hant',
  '繁': 'zh-Hant',
  'grc': 'grc',
  'greek': 'grc',
  '希腊文': 'grc',
  '希臘文': 'grc',
};

const Set<String> _otAliases = {
  'ot', 'o.t.', 'old', 'oldtestament', '旧约', '舊約', '旧約',
};

const Set<String> _ntAliases = {
  'nt', 'n.t.', 'new', 'newtestament', '新约', '新約',
};

/// `<book> <chapter>` / `<book> <c1>-<c2>`. The book part is lazy and
/// the number greedy for the same reason `reference_parser` does it
/// that way: "1 Kings 3" must not resolve the leading 1 as the chapter.
final RegExp _bookChapterRe =
    RegExp(r'^(.*?)\s*(\d{1,3})\s*(?:[-–—]\s*(\d{1,3}))?$');

/// A bare verse number. Three digits because Psalm 119 has 176 verses.
final RegExp _bareVerseRe = RegExp(r'^(\d{1,3})$');

/// `3:16` and `3:16-18` — a chapter and verse with the book left off.
final RegExp _chapterVerseRe = RegExp(
    r'^(\d{1,3})\s*[:：.]\s*(\d{1,3})(?:\s*[-–—]\s*(\d{1,3}))?$');

/// Splits `l gen, exo` — both the ASCII comma and the CJK one, because
/// a Chinese reader typing a list gets 、and ，from their IME without
/// asking for them.
final RegExp _listSeparatorRe = RegExp(r'[,，、]');

final RegExp _whitespaceRe = RegExp(r'\s+');

/// `ai <question>`. The argument is mandatory, and that is not a
/// formality: **Ai is a Canaanite city** (Joshua 7–8, Ezra 2:28), so a
/// bare `ai` has to keep reaching the text search or the verb would
/// make a real place unfindable. `ai men of ai` is still taken as a
/// question — the collision is not fully removable while the verb is a
/// word, and this is the shape of it: visible, one Esc from undone, and
/// costing nothing to the far commoner bare lookup.
final RegExp _aiVerbRe = RegExp(r'^ai\s+(.+)$', caseSensitive: false);

// ── Parse ───────────────────────────────────────────────────────────

/// Read [input] as a workbench command verb.
///
/// Returns [CommandVerbParse.none] for anything that is not one, so the
/// caller falls through to its existing version / reference / search
/// handling unchanged. Safe to run FIRST: every verb is either a single
/// ASCII letter followed by whitespace or end-of-line, or a line made
/// only of digits and a colon — and no bundled edition code, book name
/// or control character of the query grammar has either shape.
CommandVerbParse parseCommandVerb(String input, VerbContext ctx) {
  final raw = input.trim();
  if (raw.isEmpty) return const CommandVerbParse.none();

  final ai = _aiVerbRe.firstMatch(raw);
  if (ai != null) {
    return CommandVerbParse.run(
        CommandVerb(CommandVerbKind.askAi, aiQuery: ai.group(1)!.trim()));
  }

  final head = raw.substring(0, 1).toLowerCase();
  // A verb letter must stand alone: `d nas` is a verb, `dog` is a word.
  final headIsWord = raw.length == 1 || _whitespaceRe.hasMatch(raw[1]);
  final rest = raw.substring(1).trim();

  if (headIsWord) {
    switch (head) {
      case 'd':
        return _parseDisplay(rest, ctx);
      case 'p':
        return _parseParallel(rest, ctx);
      case 'l':
        return _parseLimit(rest, ctx);
    }
  }

  return _parseRelativeReference(raw, ctx);
}

CommandVerbParse _parseDisplay(String rest, VerbContext ctx) {
  if (rest.isEmpty) {
    return const CommandVerbParse.refuse(
        CommandVerbIssue.displayNeedsArgument);
  }

  // `c` before version lookup, not after: it is a keyword, and a future
  // edition whose abbreviation is "C" must not be able to shadow it.
  if (rest.toLowerCase() == 'c') {
    return CommandVerbParse.run(
        CommandVerb(CommandVerbKind.displayClear, versions: [ctx.searchVersion]));
  }

  final tokens = rest.split(_whitespaceRe).where((t) => t.isNotEmpty).toList();
  final removing = tokens.first.startsWith('-');
  final codes = <String>[];
  for (final token in tokens) {
    final bare = token.startsWith('-') ? token.substring(1) : token;
    // A line may not mix adding and removing: `d nas -kjv` reads as one
    // intention and is two, and guessing which one wins is how a reader
    // ends up with a stack they did not ask for.
    if (token.startsWith('-') != removing || bare.isEmpty) {
      return CommandVerbParse.refuse(CommandVerbIssue.unknownVersion, token);
    }
    final resolved = _resolveVersionOrLanguage(bare, ctx);
    if (resolved == null) {
      return CommandVerbParse.refuse(CommandVerbIssue.unknownVersion, bare);
    }
    for (final code in resolved) {
      if (!codes.contains(code)) codes.add(code);
    }
  }

  if (removing) {
    if (codes.contains(ctx.searchVersion)) {
      return CommandVerbParse.refuse(CommandVerbIssue.cannotRemoveSearchVersion,
          ctx.labelFor(ctx.searchVersion));
    }
    final present = [for (final c in codes) if (ctx.displayVersions.contains(c)) c];
    if (present.isEmpty) {
      return CommandVerbParse.refuse(
          CommandVerbIssue.notDisplayed, ctx.labelFor(codes.first));
    }
    return CommandVerbParse.run(
        CommandVerb(CommandVerbKind.displayRemove, versions: present));
  }

  final missing = [for (final c in codes) if (!ctx.displayVersions.contains(c)) c];
  if (missing.isEmpty) {
    return CommandVerbParse.refuse(
        CommandVerbIssue.alreadyDisplayed, ctx.labelFor(codes.first));
  }
  return CommandVerbParse.run(
      CommandVerb(CommandVerbKind.displayAdd, versions: missing));
}

CommandVerbParse _parseParallel(String rest, VerbContext ctx) {
  if (rest.isEmpty) {
    return const CommandVerbParse.run(CommandVerb(CommandVerbKind.browseOn));
  }
  final codes = <String>[];
  for (final token in rest.split(_whitespaceRe).where((t) => t.isNotEmpty)) {
    final resolved = _resolveVersionOrLanguage(token, ctx);
    if (resolved == null) {
      return CommandVerbParse.refuse(CommandVerbIssue.unknownVersion, token);
    }
    for (final code in resolved) {
      if (!codes.contains(code)) codes.add(code);
    }
  }
  return CommandVerbParse.run(
      CommandVerb(CommandVerbKind.displaySet, versions: codes));
}

/// A version abbreviation, or a language name standing for all of its
/// editions. Null when the token names neither.
List<String>? _resolveVersionOrLanguage(String token, VerbContext ctx) {
  final code = ctx.resolveVersion(token);
  if (code != null) return [code];
  final language = _languageAliases[token.trim().toLowerCase()];
  if (language != null) {
    final codes = ctx.versionsInLanguage(language);
    if (codes.isNotEmpty) return codes;
  }
  return null;
}

CommandVerbParse _parseLimit(String rest, VerbContext ctx) {
  if (rest.isEmpty) {
    return const CommandVerbParse.run(CommandVerb(CommandVerbKind.limitClear));
  }
  if (rest.toLowerCase().endsWith('.vls')) {
    return CommandVerbParse.refuse(
        CommandVerbIssue.verseListFileUnsupported, rest);
  }

  final ranges = <LimitRange>[];
  final labels = <String>[];
  String? groupKey;

  for (final piece in rest.split(_listSeparatorRe)) {
    final scope = piece.trim();
    if (scope.isEmpty) continue;
    final normalized = scope.toLowerCase().replaceAll(' ', '');

    if (_otAliases.contains(normalized)) {
      ranges.addAll([for (final b in canonicalOtBooks) LimitRange(b)]);
      labels.add('Old Testament');
      groupKey = 'cmdvScopeOt';
      continue;
    }
    if (_ntAliases.contains(normalized)) {
      ranges.addAll([for (final b in canonicalNtBooks) LimitRange(b)]);
      labels.add('New Testament');
      groupKey = 'cmdvScopeNt';
      continue;
    }

    final range = _parseBookScope(scope);
    if (range == null) {
      return CommandVerbParse.refuse(CommandVerbIssue.unknownScope, scope);
    }
    ranges.add(range);
    labels.add(range.label);
  }

  if (ranges.isEmpty) {
    return CommandVerbParse.refuse(CommandVerbIssue.unknownScope, rest);
  }
  final spec = LimitSpec(ranges, labels.join(' · '),
      labelKey: labels.length == 1 ? groupKey : null);
  return CommandVerbParse.run(
      CommandVerb(CommandVerbKind.limitSet, limit: spec));
}

/// `gen`, `matt 5`, `matt 5-7`, `1 john`.
///
/// The whole-book branch is tried FIRST for a reason: "1 John" ends in
/// no digit but "1 Kings" begins with one, and running the
/// book-plus-chapter regex first turns `1 john` into book "" chapter 1.
LimitRange? _parseBookScope(String scope) {
  final whole = resolveBookName(scope);
  if (whole != null) return LimitRange(whole);

  final m = _bookChapterRe.firstMatch(scope);
  if (m == null) return null;
  final bookPart = (m.group(1) ?? '').trim();
  if (bookPart.isEmpty) return null;
  final book = resolveBookName(bookPart);
  if (book == null) return null;
  final first = int.tryParse(m.group(2)!);
  if (first == null || first <= 0) return null;
  final last = m.group(3) == null ? null : int.tryParse(m.group(3)!);
  if (last != null && last < first) return null;
  return LimitRange(book, firstChapter: first, lastChapter: last);
}

/// `3:16` completed with the current book, `17` with the current
/// chapter as well.
///
/// bwh44 gives the bare number to the VERSE, not the chapter, and it is
/// worth being deliberate about because it reads backwards until you
/// notice the use case: you type it while reading, and while reading
/// you are already in the chapter you want. Someone who means a chapter
/// has a two-keystroke way to say so — `3:1`.
CommandVerbParse _parseRelativeReference(String raw, VerbContext ctx) {
  final bare = _bareVerseRe.firstMatch(raw);
  if (bare != null) {
    final book = ctx.currentEnglishBook;
    final chapter = ctx.currentChapter;
    if (book == null || chapter == null) {
      return const CommandVerbParse.refuse(CommandVerbIssue.noCurrentPassage);
    }
    final verse = int.parse(bare.group(1)!);
    if (verse <= 0) return const CommandVerbParse.none();
    return CommandVerbParse.run(CommandVerb(
      CommandVerbKind.goToReference,
      reference: BibleReference(
          englishBook: book, chapter: chapter, verseStart: verse, verseEnd: verse),
    ));
  }

  final cv = _chapterVerseRe.firstMatch(raw);
  if (cv != null) {
    final book = ctx.currentEnglishBook;
    if (book == null) {
      return const CommandVerbParse.refuse(CommandVerbIssue.noCurrentPassage);
    }
    final chapter = int.parse(cv.group(1)!);
    final start = int.parse(cv.group(2)!);
    if (chapter <= 0 || start <= 0) return const CommandVerbParse.none();
    final end = cv.group(3) == null ? null : int.tryParse(cv.group(3)!);
    return CommandVerbParse.run(CommandVerb(
      CommandVerbKind.goToReference,
      reference: BibleReference(
        englishBook: book,
        chapter: chapter,
        verseStart: start,
        verseEnd: (end != null && end >= start) ? end : start,
      ),
    ));
  }

  return const CommandVerbParse.none();
}

// ── Describe ────────────────────────────────────────────────────────

String _s(String key, String locale, String fallback) =>
    uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? fallback;

/// Why the verb was refused, in the reader's own language, naming the
/// token that caused it.
///
/// [available] is the list of edition labels offered when the reader
/// asks for one that is not bundled — the single most likely refusal,
/// and the one where an unhelpful message costs the most: `d niv` is
/// what a BibleWorks reader types on their first day here.
String describeVerbIssue(
  CommandVerbIssue issue,
  String detail,
  String locale, {
  List<String> available = const [],
}) {
  switch (issue) {
    case CommandVerbIssue.displayNeedsArgument:
      return _s('cmdvNeedsArgument', locale,
          'After d, name an edition (d kjv), a language (d english), '
          'a removal (d -kjv) or c to clear.');
    case CommandVerbIssue.unknownVersion:
      final base = _s('cmdvUnknownVersion', locale, 'No edition called "{x}".')
          .replaceAll('{x}', detail);
      if (available.isEmpty) return base;
      return '$base ${_s('cmdvAvailable', locale, 'Available: {list}')
          .replaceAll('{list}', available.join(' · '))}';
    case CommandVerbIssue.cannotRemoveSearchVersion:
      return _s(
              'cmdvCannotRemoveSearch',
              locale,
              '{x} is the edition you are reading and searching, '
                  'so it is always shown.')
          .replaceAll('{x}', detail);
    case CommandVerbIssue.alreadyDisplayed:
      return _s('cmdvAlreadyDisplayed', locale, '{x} is already in the stack.')
          .replaceAll('{x}', detail);
    case CommandVerbIssue.notDisplayed:
      return _s('cmdvNotDisplayed', locale, '{x} is not in the stack.')
          .replaceAll('{x}', detail);
    case CommandVerbIssue.unknownScope:
      return _s(
              'cmdvUnknownScope',
              locale,
              '"{x}" is not a book, a chapter range or a testament. '
                  'Try l gen, l matt 5-7, l nt, or l on its own to clear.')
          .replaceAll('{x}', detail);
    case CommandVerbIssue.emptyScope:
      return _s('cmdvEmptyScope', locale,
              'This edition has no verses in {x}.')
          .replaceAll('{x}', detail);
    case CommandVerbIssue.noCurrentPassage:
      return _s('cmdvNoPassage', locale,
          'Open a chapter first — a bare number is a verse in the chapter '
          'you are reading.');
    case CommandVerbIssue.verseListFileUnsupported:
      return _s('cmdvVlsFile', locale,
          'Verse-list files are not read here. Build the list in the '
          'Verse Lists tab and switch its filter on.');
  }
}

/// The one-line echo shown after a display verb runs: what you are now
/// looking at, in order.
///
/// The same idea as v1.6.19's parse echo. A command whose whole effect
/// is elsewhere on screen still has to say what it did, because the
/// Browse pane is not always visible — it collapses below the
/// three-pane breakpoint — and a command that appears to do nothing is
/// indistinguishable from one that is not implemented.
String describeDisplayStack(List<String> labels, String locale) =>
    _s('cmdvStackNow', locale, 'Browse stack: {list}')
        .replaceAll('{list}', labels.join(' · '));

// ── Apply ───────────────────────────────────────────────────────────

/// The new EFFECTIVE Browse stack after [verb].
///
/// Pure, and separate from the parse on purpose: "what does `d -nas`
/// leave me looking at" is the question worth pinning with tests, and
/// it is not answerable from the parse alone.
///
/// [searchVersion] is always first in the result and can never be
/// removed — BibleWorks' `d c` is defined as "all versions except the
/// search version", which makes that an invariant of the display and
/// not a default anyone may override.
List<String> applyDisplayVerb(
    CommandVerb verb, List<String> current, String searchVersion) {
  final next = <String>[searchVersion];
  void add(Iterable<String> codes) {
    for (final c in codes) {
      if (!next.contains(c)) next.add(c);
    }
  }

  switch (verb.kind) {
    case CommandVerbKind.displayAdd:
      add(current);
      add(verb.versions);
    case CommandVerbKind.displayRemove:
      add(current.where((c) => !verb.versions.contains(c)));
    case CommandVerbKind.displayClear:
      break;
    case CommandVerbKind.displaySet:
      add(verb.versions);
    case CommandVerbKind.browseOn:
    case CommandVerbKind.limitSet:
    case CommandVerbKind.limitClear:
    case CommandVerbKind.goToReference:
    case CommandVerbKind.askAi:
      add(current);
  }
  return next;
}
