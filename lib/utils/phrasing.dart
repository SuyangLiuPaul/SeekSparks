/// 2026-08-07 (SeekSparks): **Phrasing** — the answer to BibleWorks
/// bwh25, the Diagramming Module.
///
/// bwh25 is a vector CAD canvas: ~60 Reed-Kellogg symbols, drag-to-
/// connect endpoints, resize handles, guide lines, snap-to-grid, undo,
/// page setup. Reproducing it was rejected, and the reason is not
/// effort. Three findings, in order of weight:
///
///  1. **The thing readers valued in bwh25 was not the editor.** It was
///     Randy Leedy's *pre-drawn* Greek NT diagrams, which ship as a
///     BibleWorks database — licensed content we must not copy. Build
///     the editor and you have shipped the half nobody praised.
///  2. **The editor is the half everybody complains about.** Logos'
///     equivalent draws the same reports: "clunky", laggy past a couple
///     of lines, no way to categorise clause types, abandoned by Mac
///     users. Two independent implementations of the same interaction
///     model landing in the same place is a fact about the model.
///  3. **A drag-and-connect canvas is the wrong shape for THIS app.**
///     The workbench is gated to run on tablets, where there is no
///     precise pointer; and half the corpus is right-to-left, which a
///     symbol library has to mirror wholesale (bwh25 has a menu item
///     for exactly that).
///
/// So this module implements the *other* mainstream tradition, the one
/// Biblearc calls **phrasing**: break the text at its grammatical
/// joints, indent what is subordinate, name the relation. Same goal as
/// bwh25 — make the structure of the sentence visible — reached with a
/// data structure instead of a drawing. It is keyboard- and tap-
/// operable, RTL-safe (indentation is a flow direction, not a symbol),
/// exports as text, and, unlike a picture, it is *typed*: every line
/// knows its own relation, which is the thing bwh25's own help says it
/// wanted and never delivered ("Our intention is to allow for the
/// searching of the BibleWorks text databases using the implicit tags
/// defined in diagram files").
///
/// What SeekSparks adds that neither BibleWorks nor Biblearc has: the
/// joints are **proposed from the morphology already bundled** rather
/// than found by hand. See [autoBreakPoints] and [suggestRelations].
///
/// 2026-08-11 (v1.6.98): **phrasing is no longer Greek-only.** The limit
/// was accidental — the model never needed an original language, only
/// the page's loader did — and bwh25 itself is explicit that "the user
/// can access any Bible version in BibleWorks as a source of text to be
/// diagrammed". Confining ours to the originals narrowed it to the
/// smallest possible audience for a discipline that Biblearc, the
/// tradition this follows, is practised in mostly on English.
///
/// A translation carries less than the corpus does, and the levels say
/// so rather than proposing nothing and looking broken — see
/// [availablePhrasingLevels]. What a Strong's-tagged translation DOES
/// carry is the number of the original word behind each run, and a
/// conjunction is identifiable from that number alone, so the clause
/// joints survive the move into English or Chinese. Only the levels
/// that need a parse (participles, infinitives) are genuinely lost.
///
/// This file is Flutter-free on purpose so the whole model is testable.
library;

import 'package:seeksparks/utils/morphology.dart';
import 'package:seeksparks/utils/related_verses.dart'
    show isCjkChar, isWordChar;

/// One word of the passage under study, flattened across verses.
///
/// Index into the flat list is the identity used everywhere below: a
/// break is "a break *before* word i", a depth is "the depth of the
/// line that *starts* at word i". Keying on the start index rather than
/// on a line's ordinal is what lets the break set change underneath the
/// reader — re-running the proposal at a different level — without
/// throwing away the depths and relations they have already assigned.
class PhrasingWord {
  const PhrasingWord({
    required this.text,
    required this.strongs,
    required this.verse,
    this.morph,
    this.translit,
    this.gloss,
    this.glossFromLexicon = false,
  });

  /// Surface form, pointed/accented as the corpus has it.
  final String text;

  /// `G####` / `H####`, or empty when the corpus carries none.
  final String strongs;

  /// Verse number within the chapter. Drives the inline verse mark.
  final int verse;

  /// Raw morphology code (MorphGNT or Open Scriptures), or null.
  final String? morph;

  final String? translit;

  /// The counterpart word, printed under this one: the reader's own
  /// edition under an original, the original under a translation run.
  final String? gloss;

  /// True when [gloss] is the LEXICON's sense for the lemma rather than
  /// what this verse actually says. The two are different claims and a
  /// reader deciding where a clause ends is entitled to know which one
  /// they are looking at — see `#303`, where a per-lemma value printed
  /// beside a per-occurrence one was wrong 8,030 times.
  final bool glossFromLexicon;

  PhrasingWord withGloss(String? gloss, {bool fromLexicon = false}) =>
      PhrasingWord(
        text: text,
        strongs: strongs,
        verse: verse,
        morph: morph,
        translit: translit,
        gloss: gloss,
        glossFromLexicon: gloss == null ? false : fromLexicon,
      );
}

/// Pair one rendering of a verse against another, word by word, using
/// the Strong's numbers both carry.
///
/// Returns one entry per [targetStrongs], holding the [source] text that
/// stands behind it, or null when nothing does.
///
/// **Order of occurrence inside the number, not order in the verse.**
/// A translation reorders words freely — 和合本 puts 这事以后 where the
/// Hebrew has הַדְּבָרִים הָאֵלֶּה — so positional matching across the whole
/// verse would pair the wrong words. Matching the *k*-th target word
/// carrying `H1961` to the *k*-th source word carrying `H1961` is
/// order-independent and cannot pair two different lemmas.
///
/// **A surplus on either side is left unpaired rather than guessed.**
/// 1 Kings 21:1 has H1961 twice in Hebrew (וַיְהִי, הָיָה) and once in
/// 雅简+ (有); the second Hebrew word gets no counterpart, and saying
/// nothing there is the honest answer. The caller may fall back to the
/// lexicon, which is a different and clearly-marked claim.
List<String?> alignByStrongs(
  List<String> targetStrongs,
  List<({String strongs, String text})> source,
) {
  final queues = <String, List<String>>{};
  for (final s in source) {
    final key = s.strongs.trim().toUpperCase();
    final text = s.text.trim();
    if (key.isEmpty || text.isEmpty) continue;
    (queues[key] ??= <String>[]).add(text);
  }
  final taken = <String, int>{};
  final out = <String?>[];
  for (final raw in targetStrongs) {
    final key = raw.trim().toUpperCase();
    final queue = key.isEmpty ? null : queues[key];
    final at = taken[key] ?? 0;
    if (queue == null || at >= queue.length) {
      out.add(null);
      continue;
    }
    taken[key] = at + 1;
    out.add(queue[at]);
  }
  return out;
}

/// Reduce a lexicon entry to something that can stand under one word.
///
/// A Strong's gloss is prose, not a gloss: H1961 is
/// 「是，變爲，發生，存在，有了，產生」 and H5022 is a clause naming who
/// Naboth was and what happened to him. Set under every word of a verse
/// these turn each column into a paragraph, and a diagram whose columns
/// are paragraphs cannot be read as a diagram — which is what shipping
/// v1.6.106 to dev showed on 1 Kings 21:1.
///
/// So: the leading sense only, and never more than [_briefMax]. This is
/// a deliberate loss of information, tolerable only because the gloss is
/// already marked as the lexicon's claim rather than the verse's, and
/// because the reader can reach the entry itself from the word study.
String briefGloss(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  // Everything after the first sense boundary is a further sense.
  for (final sep in const [';', '；', '，', ',', '、', '/']) {
    final i = s.indexOf(sep);
    if (i > 0) s = s.substring(0, i);
  }
  // Parenthetical elaboration is detail, not definition.
  for (final open in const ['(', '（', '[']) {
    final i = s.indexOf(open);
    if (i > 0) s = s.substring(0, i);
  }
  s = s.trim().replaceAll(RegExp(r'[\s.。、：:]+$'), '').trim();
  if (s.length > _briefMax) {
    // Break on a word boundary if there is one; CJK has none, so the
    // ellipsis is the only honest signal that something was dropped.
    final cut = s.lastIndexOf(' ', _briefMax);
    s = '${s.substring(0, cut > 6 ? cut : _briefMax).trimRight()}…';
  }
  return s;
}

/// Long enough for 「所羅門的殿」 and for "burnt offering", short enough
/// that a column stays a column.
const int _briefMax = 14;

/// Split a verse of a translation into the units a line can break at.
///
/// The house rule is `phrase_match.dart`'s — **one token per Han
/// character, one per alphabetic run** — deliberately reused rather than
/// reinvented, because two tokenizers for "where do the words of a
/// Chinese verse begin" would drift apart and there is no third opinion
/// to settle them.
///
/// It differs from `phraseTokens` in the one way display demands:
/// **punctuation is carried, not discarded.** Every token runs to the
/// start of the next, so `tokens.join()` reproduces the verse exactly,
/// commas and all. A phrasing whose lines have lost their punctuation is
/// not the text the reader is studying — `Grace to you and peace` and
/// `Grace to you, and peace` are different claims about where the joint
/// falls, which is the whole subject of the exercise.
///
/// Leading punctuation attaches to the first token rather than becoming
/// a token of its own, so an opening quotation mark cannot be broken
/// away from the word it opens.
List<String> phrasingTokens(String text) {
  final starts = <int>[];
  final n = text.length;
  var i = 0;
  while (i < n) {
    final c = text.codeUnitAt(i);
    if (isCjkChar(c)) {
      starts.add(i);
      i++;
      continue;
    }
    if (isWordChar(c)) {
      starts.add(i);
      while (i < n && isWordChar(text.codeUnitAt(i))) {
        i++;
      }
      continue;
    }
    i++;
  }
  if (starts.isEmpty) {
    final only = text.trim();
    return only.isEmpty ? const [] : [only];
  }
  final out = <String>[];
  for (var k = 0; k < starts.length; k++) {
    final from = k == 0 ? 0 : starts[k];
    final to = k + 1 < starts.length ? starts[k + 1] : n;
    out.add(text.substring(from, to));
  }
  return out;
}

/// True when the passage is written in a right-to-left script.
///
/// Decided from the **text**, not from the Strong's prefix. A tagged
/// Chinese or English Old Testament verse carries H-numbers and reads
/// left to right; keying on the prefix would mirror the whole diagram
/// for every reader who phrased Genesis in 和简+.
bool phrasingIsRtl(List<PhrasingWord> words) =>
    words.any((w) => isRtlText(w.text));

/// True when [s] contains Hebrew. Direction is decided by the script of
/// the text and never by the `H`/`G` prefix of a Strong's number: the
/// gloss line under a Hebrew word may itself be Chinese, and the gloss
/// under a Chinese word may itself be Hebrew.
bool isRtlText(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    // Hebrew block, then Hebrew presentation forms.
    if ((c >= 0x0590 && c <= 0x05FF) || (c >= 0xFB1D && c <= 0xFB4F)) {
      return true;
    }
  }
  return false;
}

/// True when the passage is Chinese and should be drawn without the gap
/// between words that an alphabetic script needs.
///
/// Chinese has no word spaces. A chapter cut one character at a time and
/// then drawn with the spacing Greek requires reads as s p a c e d  o u t
/// text rather than as the verse the reader knows, and the diagram stops
/// looking like Scripture. The words stay individually tappable either
/// way; only the gap changes.
///
/// Measured from the words, not from the interface locale — a reader
/// with a Chinese interface may be phrasing the BSB.
bool phrasingIsCjk(List<PhrasingWord> words) {
  var cjk = 0;
  for (final w in words) {
    if (w.text.isNotEmpty && isCjkChar(w.text.codeUnitAt(0))) cjk++;
  }
  return cjk * 2 > words.length;
}

/// How aggressively [autoBreakPoints] cuts the passage.
///
/// Ordered coarse → fine, and each level is a superset of the one
/// before it, so moving down the list only ever ADDS breaks. That
/// monotonicity is what makes the level safe to change mid-study: a
/// line the reader has already indented and named can be split by a
/// finer level, but never silently merged away.
enum PhrasingLevel {
  /// Verse starts only. No grammatical claim at all — the honest
  /// starting point for a reader who wants to do the whole analysis
  /// themselves, and the fallback for a passage with no morphology.
  verses,

  /// + conjunctions and relative pronouns: the joints between clauses.
  clauses,

  /// + participles and infinitives: subordinate verbal units.
  verbals,

  /// + prepositions: prepositional and (in Hebrew) prefixed phrases.
  /// The finest level, and in Hebrew a very fine one — 52,097 words in
  /// the bundled corpus open with a preposition morpheme.
  phrases,
}

/// The relation a line bears to the line it hangs under.
///
/// Deliberately a fixed, small vocabulary rather than free text. Two
/// reasons: a relation you can only write in prose cannot be counted,
/// filtered or compared across passages; and Logos' Propositional
/// Outlines are reported to fail precisely because their vocabulary is
/// large and linguistic. These eighteen are the labels the phrasing /
/// block-diagramming literature actually uses.
enum PhrasingRelation {
  series,
  progression,
  contrast,
  alternative,
  comparison,
  purpose,
  result,
  ground,
  inference,
  means,
  manner,
  condition,
  concession,
  temporal,
  place,
  content,
  apposition,
  relative,
}

/// Stable string ids for persistence. Never renumber or rename these —
/// they are written into SharedPreferences.
extension PhrasingRelationId on PhrasingRelation {
  String get id => name;
}

PhrasingRelation? phrasingRelationFromId(String? id) {
  if (id == null) return null;
  for (final r in PhrasingRelation.values) {
    if (r.name == id) return r;
  }
  return null;
}

/// The reader's work on one passage.
///
/// Immutable; every operation returns a new value. The break set is
/// stored as a *diff against the proposal* ([added] / [removed]) rather
/// than as a list of lines, so that changing [level] preserves manual
/// intent instead of discarding it.
class Phrasing {
  const Phrasing({
    required this.version,
    required this.book,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
    this.level = PhrasingLevel.clauses,
    this.added = const <int>{},
    this.removed = const <int>{},
    this.depths = const <int, int>{},
    this.relations = const <int, PhrasingRelation>{},
    this.members = const <int>{},
    this.emphasis = const <int>{},
  });

  /// Provenance only. A phrasing is of a *text*, and the same passage
  /// phrased from two editions is two pieces of work.
  final String version;

  /// English book name, as [PhrasingStore] and OriginalsService use.
  final String book;
  final int chapter;
  final int startVerse;
  final int endVerse;

  final PhrasingLevel level;

  /// Breaks the reader added that the proposal did not make.
  final Set<int> added;

  /// Breaks the proposal made that the reader took out.
  final Set<int> removed;

  /// Word index a line starts at → the depth the reader put it at.
  /// Stored *unclamped*; see [layoutPhrasing].
  final Map<int, int> depths;

  final Map<int, PhrasingRelation> relations;

  /// Line starts the reader has marked as PARALLEL MEMBERS — the lines
  /// that get `(a)`, `(b)` in front of them.
  ///
  /// This is not the same claim as [relations], and the difference is
  /// the reason it needs its own field. A relation names how a line
  /// stands to the line above it; a member mark says *these lines are
  /// the same kind of thing*, which is a fact about a SET. Indentation
  /// cannot say it — two lines at one depth may be a series or may
  /// simply be sequential — and the first member of a series carries no
  /// relation at all, so the set would be invisible in the very place a
  /// reader wants to point at it. The letters are also a handle: a
  /// teacher can say "look at (b)".
  ///
  /// The reader marks members; the letters are DERIVED — see
  /// [phrasingMemberLabels]. There is no stored group id, because a
  /// group is already implied by the marks and the depths, and a stored
  /// id could disagree with the picture.
  final Set<int> members;

  /// Line starts the reader has underlined. One weight, deliberately:
  /// emphasis answers "look here", and a palette of colours turns that
  /// into a second notation the diagram would then have to explain.
  final Set<int> emphasis;

  Phrasing copyWith({
    PhrasingLevel? level,
    Set<int>? added,
    Set<int>? removed,
    Map<int, int>? depths,
    Map<int, PhrasingRelation>? relations,
    Set<int>? members,
    Set<int>? emphasis,
    int? startVerse,
    int? endVerse,
  }) =>
      Phrasing(
        version: version,
        book: book,
        chapter: chapter,
        startVerse: startVerse ?? this.startVerse,
        endVerse: endVerse ?? this.endVerse,
        level: level ?? this.level,
        added: added ?? this.added,
        removed: removed ?? this.removed,
        depths: depths ?? this.depths,
        relations: relations ?? this.relations,
        members: members ?? this.members,
        emphasis: emphasis ?? this.emphasis,
      );

  /// True when the reader has done anything at all. Drives whether the
  /// work is worth persisting.
  bool get isTouched =>
      added.isNotEmpty ||
      removed.isNotEmpty ||
      depths.isNotEmpty ||
      relations.isNotEmpty ||
      members.isNotEmpty ||
      emphasis.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'version': version,
        'book': book,
        'chapter': chapter,
        'startVerse': startVerse,
        'endVerse': endVerse,
        'level': level.name,
        'added': added.toList()..sort(),
        'removed': removed.toList()..sort(),
        'depths': {for (final e in depths.entries) '${e.key}': e.value},
        'relations': {
          for (final e in relations.entries) '${e.key}': e.value.id,
        },
        'members': members.toList()..sort(),
        'emphasis': emphasis.toList()..sort(),
      };

  /// Tolerant of anything: a blob written by a future build, a
  /// hand-edited preference, a truncated string. Unreadable parts are
  /// dropped, never thrown — losing one relation label beats losing the
  /// passage.
  static Phrasing? fromJson(Map<String, dynamic> json) {
    final book = json['book'];
    final chapter = json['chapter'];
    if (book is! String || book.isEmpty || chapter is! int) return null;
    Set<int> ints(Object? v) => v is List
        ? {for (final e in v) if (e is int && e > 0) e}
        : const <int>{};
    // Word 0 is excluded from [added]/[removed] because it is always a
    // break and can never be toggled — but it IS a line start, so it
    // can be a member or be emphasised. Reusing the stricter parser
    // here would silently drop the reader's mark on the first line.
    Set<int> lineStarts(Object? v) => v is List
        ? {for (final e in v) if (e is int && e >= 0) e}
        : const <int>{};
    final depths = <int, int>{};
    final rawDepths = json['depths'];
    if (rawDepths is Map) {
      for (final e in rawDepths.entries) {
        final k = int.tryParse('${e.key}');
        final v = e.value;
        if (k != null && k >= 0 && v is int && v >= 0) depths[k] = v;
      }
    }
    final relations = <int, PhrasingRelation>{};
    final rawRel = json['relations'];
    if (rawRel is Map) {
      for (final e in rawRel.entries) {
        final k = int.tryParse('${e.key}');
        final r = phrasingRelationFromId(e.value is String ? e.value as String : null);
        if (k != null && k >= 0 && r != null) relations[k] = r;
      }
    }
    return Phrasing(
      version: json['version'] is String ? json['version'] as String : '',
      book: book,
      chapter: chapter,
      startVerse: json['startVerse'] is int ? json['startVerse'] as int : 1,
      endVerse: json['endVerse'] is int ? json['endVerse'] as int : 1,
      level: PhrasingLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => PhrasingLevel.clauses,
      ),
      added: ints(json['added']),
      removed: ints(json['removed']),
      depths: depths,
      relations: relations,
      members: lineStarts(json['members']),
      emphasis: lineStarts(json['emphasis']),
    );
  }
}

/// How far the first line may be indented. Every other line is bounded
/// by its predecessor; the first has no predecessor, so it needs a stop
/// of its own or a held-down button pushes the text out of view.
const int maxPhrasingDepth = 8;

// ─── The sentence, and where it ends ────────────────────────────────
//
// Phrasing is an argument about a UNIT OF THOUGHT, and the unit is a
// sentence, not a verse. Opening on the cursor verse alone fights the
// exercise every time: measured over all 31,102 verses of four shipped
// editions, **21.5% of BSB, 23.1% of LEB, 26.0% of 和合本雅伟版 and
// 27.9% of KJV verses sit inside a sentence that does not end where the
// verse does** — so between a fifth and a third of the time the old
// default handed the reader half a thought.
//
// Those figures are measured THROUGH `scriptureReadingText`, not off the
// raw JSON, and the difference is the reason to say so: LEB writes its
// footnotes inline as `<note:…>`, and a survey of the bytes put 141 of
// its 1,189 chapters in the middle of a sentence at the chapter break
// and its multi-verse share at 37.5%. Through the pipeline the reader
// actually sees it is **5 chapters and 23.1%**. A punctuation rule
// measured on text the app never renders is measuring the markup.
//
// Ephesians 1 is the case the request itself names, and it also shows
// why the answer has to name its source. The chapter's sentences are:
//     LEB   1-2 · **3-14** · 15-23
//     KJV   1-2 · 3-6 · 7-12 · 13-14 · 15-23
//     BSB   1-2 · 3 · 4-6 · 7-8 · 9-10 · 11-12 · 13-14 · 15-17 · …
// Those are three different editorial judgements about one Greek
// paragraph, and every one of them is its edition's own claim. So the
// window is read off the edition the reader is holding and the pane
// says whose punctuation drew it — never "the sentence is 3-14" as
// though the text settled it.

/// The characters an edition ends a sentence with.
///
/// Deliberately does **not** include `;` or `:`. An English semicolon is
/// a joint inside a sentence, and the KJV leans on it hard — counting it
/// cut Ephesians 1:7-12 into three. U+037E is the Greek question mark,
/// which is a different codepoint from the semicolon precisely so the
/// two can be told apart; U+05C3 is the Hebrew sof pasuq, which ends the
/// verse and so ends whatever sentence was still running.
const Set<String> _sentenceEnders = {
  '.', '!', '?', //
  '。', '！', '？', //
  ';', // ";" GREEK QUESTION MARK
  '׃', // "׃" HEBREW PUNCTUATION SOF PASUQ
};

/// Characters that may stand *after* a full stop without cancelling it.
///
/// Closing quotes and brackets only. A comma, a semicolon or a colon can
/// never follow a terminator, so stripping them would be a way of
/// finding a sentence end that is not there — `he said,` would become
/// `he said` and then be tested against its last letter, which is at
/// best wasted work and at worst, after a bracketed gloss, a false
/// positive. `]` is here because `scriptureReadingText` wraps a divine
/// name or a supplied word in brackets: 和合本 prints 「...说。[雅伟]」.
const Set<String> _sentenceClosers = {
  '"', "'", '”', '’', '»', '›', //
  ')', ']', '}', '）', '］', '｝', //
  '」', '』', '》', '〉', '〕', '‧',
};

/// True when [text] is the end of a sentence as its edition prints it.
///
/// Trailing closers are peeled one at a time rather than in a single
/// pass, because 和合本 ends a quoted question with 「？」」 — two closers
/// over one terminator — and 「...。』」 with three.
bool phrasingEndsSentence(String text) {
  var s = text.trimRight();
  while (s.isNotEmpty && _sentenceClosers.contains(s[s.length - 1])) {
    s = s.substring(0, s.length - 1).trimRight();
  }
  return s.isNotEmpty && _sentenceEnders.contains(s[s.length - 1]);
}

/// Beyond this many verses the window is not a sentence any more.
///
/// Measured before it was chosen, not rounded to something that looked
/// sensible. Sentences run past 12 verses for **155 of LEB's, 175 of
/// 和合本雅伟版's, 182 of KJV's and 218 of BSB's 31,102 verses — 0.50%
/// to 0.70%** — and the ones past it are all *enumerations* rather than
/// periods —
/// Joshua 15:21-62 (42 verses of town names), Ezra 2:3-35 and Nehemiah
/// 7:8-38 (the registries of the returned), 1 Chronicles 11:26-47 (the
/// mighty men), Luke 3:23-38 (the genealogy). None of those is a unit of
/// thought anyone phrases.
///
/// 12 rather than 10 because **LEB's Ephesians 1:3-14 is exactly 12**,
/// and the one passage the request itself is about must not be the first
/// thing the cap refuses.
const int maxPhrasingWindowVerses = 12;

/// Where a [PhrasingWindow]'s bounds came from.
enum PhrasingWindowSource {
  /// The words being phrased carry the punctuation themselves.
  phrased,

  /// They do not, so the bounds were read off the reader's edition and
  /// are ITS claim about where the thought ends. `assets/originals`
  /// carries **zero** sentence punctuation — 0 stops in 438,821 words,
  /// because the import kept the pointing and the accents and dropped
  /// the editors' periods — so this is the only route the Hebrew and
  /// Greek have.
  edition,

  /// Nothing in the chapter stops anywhere. Falls back to the verse.
  none,
}

/// The verse window to open a phrasing on, and why it is that size.
class PhrasingWindow {
  const PhrasingWindow({
    required this.start,
    required this.end,
    required this.sentenceStart,
    required this.sentenceEnd,
    required this.source,
  });

  /// The window to show.
  final int start;
  final int end;

  /// The sentence's real span. Equal to [start]/[end] unless the
  /// sentence was longer than [maxPhrasingWindowVerses], in which case
  /// the window is the cursor verse alone and this is what it is inside.
  /// **A cap that is not printed is a silent WHERE clause**, so the pane
  /// prints this and offers to open it.
  final int sentenceStart;
  final int sentenceEnd;

  final PhrasingWindowSource source;

  /// True when the sentence was too long to open and the reader is being
  /// shown one verse of it.
  bool get capped => sentenceStart != start || sentenceEnd != end;

  /// True when the window says something the verse alone did not.
  bool get widensVerse => end > start;

  @override
  String toString() =>
      'PhrasingWindow($start-$end of $sentenceStart-$sentenceEnd, ${source.name})';
}

/// The smallest verse range containing [verse] whole that does not cut a
/// sentence at either edge.
///
/// [text] is the chapter in reading order as `(verse, text)`; the verse
/// need not be contiguous and repeated verses are joined, so it takes
/// either the phrased words themselves or an edition's verse list.
///
/// **Only a terminator at the END of a verse can close the window**, and
/// that is a decision rather than an approximation: the window is
/// verse-granular, so a full stop in the middle of verse 7 gives no
/// place to cut — the reader would still be shown all of 7. Ignoring it
/// means the range is always *at least* the sentence, never less.
PhrasingWindow phrasingSentenceWindow(
  List<({int verse, String text})> text,
  int verse, {
  int maxVerses = maxPhrasingWindowVerses,
  PhrasingWindowSource source = PhrasingWindowSource.phrased,
}) {
  // Last fragment wins: a verse closes only if its final token does.
  final closes = <int, bool>{};
  final order = <int>[];
  for (final t in text) {
    if (!closes.containsKey(t.verse)) order.add(t.verse);
    closes[t.verse] = phrasingEndsSentence(t.text);
  }
  order.sort();
  if (order.isEmpty) {
    return PhrasingWindow(
      start: verse,
      end: verse,
      sentenceStart: verse,
      sentenceEnd: verse,
      source: PhrasingWindowSource.none,
    );
  }
  final i = order.indexOf(verse);
  if (i < 0 || !closes.values.any((c) => c)) {
    final v = i < 0 ? verse : order[i];
    return PhrasingWindow(
      start: v,
      end: v,
      sentenceStart: v,
      sentenceEnd: v,
      source: PhrasingWindowSource.none,
    );
  }
  var a = i;
  while (a > 0 && !(closes[order[a - 1]] ?? false)) {
    a--;
  }
  var b = i;
  while (b < order.length - 1 && !(closes[order[b]] ?? false)) {
    b++;
  }
  final start = order[a];
  final end = order[b];
  // Counted as verses PRESENT, not as `end - start + 1`: a chapter with
  // a gap in the tagged corpus would otherwise be capped for verses it
  // was never going to draw.
  final tooLong = b - a + 1 > maxVerses;
  return PhrasingWindow(
    start: tooLong ? verse : start,
    end: tooLong ? verse : end,
    sentenceStart: start,
    sentenceEnd: end,
    source: source,
  );
}

/// One rendered line: the words `[start, end)`, at a *clamped* depth.
class PhrasingLine {
  const PhrasingLine({
    required this.start,
    required this.end,
    required this.depth,
    this.relation,
    this.suggested,
    this.memberLabel,
    this.emphasised = false,
  });

  final int start;

  /// Exclusive.
  final int end;

  /// Already clamped by [layoutPhrasing]; render this, do not re-clamp.
  final int depth;

  /// What the reader chose, if anything.
  final PhrasingRelation? relation;

  /// What the grammar proposes, when the reader has chosen nothing.
  /// MUST be drawn differently from [relation] — a guess that looks
  /// like a decision is worse than no guess, because the reader cannot
  /// tell which of their labels are their own.
  final PhrasingRelation? suggested;

  /// `a`, `b`, … when this line is a marked parallel member, else null.
  /// Derived by [phrasingMemberLabels]; never stored.
  final String? memberLabel;

  final bool emphasised;

  int get length => end - start;
}

/// The letter for the [index]-th member of a group: a…z, then aa, ab.
///
/// Bijective base-26, so no group runs out of names. Real groups are
/// two to five members; the overflow exists so that a reader who marks
/// thirty lines gets `ad` rather than a wrong or repeated letter.
String phrasingMemberLetter(int index) {
  var n = index;
  final rev = <int>[];
  while (true) {
    rev.add(97 + n % 26);
    n = n ~/ 26 - 1;
    if (n < 0) break;
  }
  return String.fromCharCodes(rev.reversed);
}

/// Letter every marked line, grouping by the structure already on
/// screen. Returns one entry per line, null where the line is not a
/// member.
///
/// **A group is the run of marked lines at one depth**, and it survives
/// anything *deeper* in between — a member with a subordinate clause
/// under it is still a member. It ends when an UNMARKED line appears at
/// the group's own depth (the series is over) or when the text comes
/// back out shallower than the group (its head has been left behind).
/// Groups therefore nest, which is why this keeps a stack rather than a
/// single open depth: a pair of parallel members inside member (a) must
/// letter itself a…b without stealing (b) from the outer group.
///
/// This is derived rather than stored on purpose. The rule is exactly
/// what indentation already means, so the letters cannot contradict the
/// picture; a stored group id could.
///
/// Computed over the WHOLE chapter, never over the verse window. The
/// window is a viewport, and letters that changed when the reader
/// scrolled would be describing the viewport instead of the text.
List<String?> phrasingMemberLabels(List<int> depths, List<bool> marked) {
  final out = List<String?>.filled(depths.length, null);
  // (depth, members so far) for each open group, outermost first.
  final stack = <List<int>>[];
  for (var i = 0; i < depths.length; i++) {
    final d = depths[i];
    while (stack.isNotEmpty && stack.last[0] > d) {
      stack.removeLast();
    }
    final open = stack.isNotEmpty && stack.last[0] == d ? stack.last : null;
    if (marked[i]) {
      if (open != null) {
        open[1]++;
        out[i] = phrasingMemberLetter(open[1]);
      } else {
        stack.add([d, 0]);
        out[i] = phrasingMemberLetter(0);
      }
    } else if (open != null) {
      stack.removeLast();
    }
  }
  return out;
}

/// The break set actually in force: the proposal for [p.level], plus
/// what the reader added, minus what they took out. Word 0 is always a
/// break and can never be removed — the passage has to start somewhere.
Set<int> effectiveBreaks(Phrasing p, List<PhrasingWord> words) {
  final n = words.length;
  final out = <int>{0};
  if (n == 0) return out;
  for (final i in autoBreakPoints(words, p.level)) {
    if (i > 0 && i < n) out.add(i);
  }
  for (final i in p.added) {
    if (i > 0 && i < n) out.add(i);
  }
  out.removeAll(p.removed.where((i) => i != 0));
  out.add(0);
  return out;
}

/// Resolve a [Phrasing] against its words into renderable lines.
///
/// The one subtlety is depth. Depths are *stored* raw and *clamped*
/// here to `previous + 1`, never deeper. A tree in which a line is two
/// levels below its predecessor has no meaning — there is no parent at
/// the level in between — and allowing it produces diagrams that look
/// deliberate and say nothing.
///
/// Clamping at layout rather than at edit time is what makes outdenting
/// a parent non-destructive: its children are clamped up to follow it,
/// and if the parent is indented again they spring back to the depths
/// the reader originally chose. Storing the clamped value would have
/// flattened them permanently, and the reader would have no way to know
/// their work had been consumed by a gesture aimed at a different line.
List<PhrasingLine> layoutPhrasing(Phrasing p, List<PhrasingWord> words) {
  if (words.isEmpty) return const [];
  final starts = effectiveBreaks(p, words).toList()..sort();
  // The first line may be indented too. It was pinned to the margin
  // because it has no predecessor to be subordinate TO, but that
  // conflated two things: depth as a grammatical claim, and depth as the
  // margin the whole block hangs from. Readers set the second one by
  // hand on paper all the time, and the reader who asked for this had
  // done exactly that in Word. With no parent above it there is nothing
  // to clamp against, so the only bound is [maxPhrasingDepth], which
  // stops a repeated tap walking the text off the right edge.
  final depths = <int>[];
  var prev = 0;
  for (var i = 0; i < starts.length; i++) {
    final raw = p.depths[starts[i]] ?? 0;
    final d = i == 0 ? raw.clamp(0, maxPhrasingDepth) : raw.clamp(0, prev + 1);
    depths.add(d);
    prev = d;
  }
  // Lettering needs every depth on the page before it can group them,
  // so it cannot be folded into the loop below.
  final labels = phrasingMemberLabels(
    depths,
    [for (final s in starts) p.members.contains(s)],
  );
  final out = <PhrasingLine>[];
  for (var i = 0; i < starts.length; i++) {
    final start = starts[i];
    final end = i + 1 < starts.length ? starts[i + 1] : words.length;
    final chosen = p.relations[start];
    out.add(PhrasingLine(
      start: start,
      end: end,
      depth: depths[i],
      relation: chosen,
      suggested: chosen == null && i > 0
          ? suggestRelations(words[start]).firstOrNull
          : null,
      memberLabel: labels[i],
      emphasised: p.emphasis.contains(start),
    ));
  }
  return out;
}

/// Local, private, and on Iterable rather than List — `where()` returns
/// an Iterable, and a List-only extension silently fails to apply
/// there.
/// The lines that fall inside the reader's verse window.
///
/// The word list a [Phrasing] is resolved against is ALWAYS the whole
/// chapter, and [Phrasing.startVerse]/[Phrasing.endVerse] only choose
/// what is on screen. That is not a convenience — it is what keeps the
/// stored work correct. Breaks, depths and relations are all keyed by
/// position in the flattened word list, so if the list were only the
/// windowed verses then widening the window backwards by one verse
/// would shift every index and silently reattach the reader's entire
/// analysis to the wrong words. Chapter-wide ordinals do not move.
///
/// A line is kept when ANY of its words is in the window, so a clause
/// that begins in the verse above is shown whole rather than beheaded —
/// which is also the more truthful picture, since seeing the clause
/// straddle the verse boundary is half the point of phrasing.
List<PhrasingLine> visiblePhrasingLines(
  List<PhrasingLine> lines,
  List<PhrasingWord> words,
  int startVerse,
  int endVerse,
) =>
    [
      for (final l in lines)
        if (_intersects(l, words, startVerse, endVerse)) l,
    ];

bool _intersects(
  PhrasingLine l,
  List<PhrasingWord> words,
  int startVerse,
  int endVerse,
) {
  for (var i = l.start; i < l.end && i < words.length; i++) {
    final v = words[i].verse;
    if (v >= startVerse && v <= endVerse) return true;
  }
  return false;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final e in this) {
      return e;
    }
    return null;
  }
}

// ── Edit operations ──────────────────────────────────────────────────

/// Break the passage before word [index], or — if it is already a break
/// — join that line to the one above. One gesture, its own inverse.
///
/// Word 0 is a no-op rather than an error: it is the only index the
/// reader can point at that has no meaningful toggle, and refusing
/// loudly would be worse than doing nothing visible.
Phrasing togglePhrasingBreak(
  Phrasing p,
  List<PhrasingWord> words,
  int index,
) {
  if (index <= 0 || index >= words.length) return p;
  final auto = autoBreakPoints(words, p.level);
  final isBreak = effectiveBreaks(p, words).contains(index);
  final added = {...p.added};
  final removed = {...p.removed};
  if (isBreak) {
    added.remove(index);
    if (auto.contains(index)) removed.add(index);
  } else {
    removed.remove(index);
    if (!auto.contains(index)) added.add(index);
  }
  return p.copyWith(added: added, removed: removed);
}

/// Indent the line starting at [start] one level, relative to where it
/// is *drawn*. Reading the clamped depth back out of the layout — not
/// the stored one — is what makes the button do what the reader sees:
/// a line stored at depth 7 but drawn at 2 must go to 3, not to 8.
Phrasing indentPhrasingLine(
  Phrasing p,
  List<PhrasingWord> words,
  int start,
) =>
    _setDepth(p, words, start, (d) => d + 1);

/// Outdent one level. Stops at 0.
Phrasing outdentPhrasingLine(
  Phrasing p,
  List<PhrasingWord> words,
  int start,
) =>
    _setDepth(p, words, start, (d) => d - 1);

Phrasing _setDepth(
  Phrasing p,
  List<PhrasingWord> words,
  int start,
  int Function(int) f,
) {
  final lines = layoutPhrasing(p, words);
  final line = lines.where((l) => l.start == start).firstOrNull;
  if (line == null) return p;
  final next = f(line.depth);
  if (next < 0) return p;
  // The first line's stored depth is capped rather than left to run
  // ahead of what is drawn. Everywhere else an over-deep stored value is
  // deliberate — it springs back when an outdented parent is indented
  // again — but line one has no parent, so a stored 9 against a drawn 8
  // would only buy the reader a tap that does nothing.
  if (start == 0 && next > maxPhrasingDepth) return p;
  final depths = {...p.depths}..[start] = next;
  return p.copyWith(depths: depths);
}

/// Name the relation of the line starting at [start]; null clears it,
/// which returns the line to showing the grammar's suggestion.
Phrasing setPhrasingRelation(
  Phrasing p,
  int start,
  PhrasingRelation? relation,
) {
  final relations = {...p.relations};
  if (relation == null) {
    relations.remove(start);
  } else {
    relations[start] = relation;
  }
  return p.copyWith(relations: relations);
}

/// Change how finely the passage is cut, keeping every manual break,
/// depth and label. See [Phrasing.added] for why this is possible.
Phrasing setPhrasingLevel(Phrasing p, PhrasingLevel level) =>
    p.copyWith(level: level);

/// Mark or unmark the line starting at [start] as a parallel member.
/// The letter it ends up with is not stored and not chosen here — see
/// [phrasingMemberLabels].
Phrasing togglePhrasingMember(Phrasing p, int start) {
  final next = {...p.members};
  if (!next.remove(start)) next.add(start);
  return p.copyWith(members: next);
}

/// Underline the line starting at [start], or take the underline off.
Phrasing togglePhrasingEmphasis(Phrasing p, int start) {
  final next = {...p.emphasis};
  if (!next.remove(start)) next.add(start);
  return p.copyWith(emphasis: next);
}

/// Throw away every manual edit, back to the bare proposal.
Phrasing resetPhrasing(Phrasing p) => Phrasing(
      version: p.version,
      book: p.book,
      chapter: p.chapter,
      startVerse: p.startVerse,
      endVerse: p.endVerse,
      level: p.level,
    );

// ── Export ───────────────────────────────────────────────────────────

/// What an export contains: the reader's verse WINDOW, the same lines
/// the screen is showing.
///
/// It used to be the whole chapter under a heading naming the window,
/// so a reader who set 1–3 and copied got fifty verses labelled
/// `1:1-3`. Windowing here is also what makes the lettering right:
/// [phrasingMemberLabels] runs over the chapter, so a group straddling
/// the edge of the window keeps the letters it has on screen instead of
/// being re-lettered from `a` by the act of copying.
List<PhrasingLine> _linesToExport(Phrasing p, List<PhrasingWord> words) =>
    visiblePhrasingLines(
      layoutPhrasing(p, words),
      words,
      p.startVerse,
      p.endVerse,
    );

/// Render the phrasing as indented plain text, for a paper, a sermon
/// manuscript, or an email.
///
/// [label] turns a relation into the reader's language; the core has no
/// locale, so the caller supplies it. [verseMark] is called for the
/// first word of each verse.
///
/// Only a relation the reader CHOSE is written out. The grammar's
/// suggestion is drawn on screen in italic to say it is a guess, and an
/// exported file has no italic to say it with — a guess pasted into a
/// handout as `[purpose]` becomes the reader's own claim the moment it
/// leaves this app.
String exportPhrasing(
  Phrasing p,
  List<PhrasingWord> words, {
  required String Function(PhrasingRelation) label,
  String Function(int verse)? verseMark,
  String indentUnit = '    ',
}) {
  final lines = _linesToExport(p, words);
  // A Chinese text arrives one Han character per token, so joining with
  // spaces prints s p a c e d  o u t scripture. The screen already
  // measures this from the words themselves; deriving it here too means
  // no caller can get the export's spacing wrong.
  final gap = phrasingIsCjk(words) ? '' : ' ';
  final buf = StringBuffer();
  for (final line in lines) {
    buf.write(indentUnit * line.depth);
    if (line.memberLabel != null) {
      buf.write('(${line.memberLabel}) ');
    }
    if (line.relation != null) {
      buf.write('[${label(line.relation!)}] ');
    }
    var lastVerse = line.start > 0 ? words[line.start - 1].verse : -1;
    for (var i = line.start; i < line.end; i++) {
      final w = words[i];
      if (w.verse != lastVerse) {
        buf.write('${verseMark?.call(w.verse) ?? '(${w.verse})'} ');
        lastVerse = w.verse;
      }
      buf.write(w.text);
      if (i < line.end - 1) buf.write(gap);
    }
    buf.writeln();
  }
  return buf.toString();
}

/// Escape for an HTML text node or a double-quoted attribute.
String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Render the phrasing as an HTML fragment, so the diagram survives
/// leaving the app.
///
/// **The artifact is the point.** The team that asked for this works in
/// Word because they teach from the result, print it and hand it out —
/// and a plain-text copy loses everything a phrasing says with
/// typography: an underline has no plain-text spelling at all, and
/// leading spaces in a proportional font are not an indent, they are a
/// ragged edge. This exists so that the notation the reader builds on
/// screen is the notation that lands in the document.
///
/// Units are POINTS, not pixels or ems, because a word processor is the
/// destination and points are the unit it already thinks in; 24pt a
/// level is the tab stop Word ships with.
///
/// Only inline styles are emitted — a pasted `<style>` block is
/// discarded by every editor worth pasting into.
String exportPhrasingHtml(
  Phrasing p,
  List<PhrasingWord> words, {
  required String Function(PhrasingRelation) label,
  required String heading,
  String Function(int verse)? verseMark,
  bool rtl = false,
  double indentPt = 24,
}) {
  final lines = _linesToExport(p, words);
  final gap = phrasingIsCjk(words) ? '' : ' ';
  final dir = rtl ? 'rtl' : 'ltr';
  final buf = StringBuffer()
    ..write('<div dir="$dir" style="font-family:Georgia,serif;'
        'line-height:1.5">');
  if (heading.isNotEmpty) {
    buf.write('<p style="margin:0 0 8pt 0"><b>${_esc(heading)}</b></p>');
  }
  var prevVerse = -1;
  for (final line in lines) {
    final firstVerse =
        line.start < words.length ? words[line.start].verse : prevVerse;
    // A blank line between verses, which is how the request's own
    // document is set. It is spacing rather than a break because a line
    // is allowed to STRADDLE a verse boundary here — seeing a clause run
    // across the versification is half of what phrasing is for — so the
    // verse cannot become the block.
    final lead = prevVerse >= 0 && firstVerse != prevVerse ? 8 : 0;
    buf.write('<p style="margin:${lead}pt 0 0 '
        '${(line.depth * indentPt).toStringAsFixed(0)}pt">');
    if (line.memberLabel != null) {
      buf.write('(${_esc(line.memberLabel!)}) ');
    }
    if (line.relation != null) {
      buf.write('<span style="color:#777">[${_esc(label(line.relation!))}]'
          '</span> ');
    }
    if (line.emphasised) buf.write('<u>');
    var lastVerse = line.start > 0 ? words[line.start - 1].verse : -1;
    for (var i = line.start; i < line.end && i < words.length; i++) {
      final w = words[i];
      if (w.verse != lastVerse) {
        buf.write('<sup>${_esc(verseMark?.call(w.verse) ?? '${w.verse}')}'
            '</sup>$gap');
        lastVerse = w.verse;
      }
      buf.write(_esc(w.text));
      if (i < line.end - 1) buf.write(gap);
    }
    if (line.emphasised) buf.write('</u>');
    buf.write('</p>');
    prevVerse = line.end - 1 < words.length && line.end > line.start
        ? words[line.end - 1].verse
        : firstVerse;
  }
  buf.write('</div>');
  return buf.toString();
}

// ── The proposal: where the joints are ───────────────────────────────

/// Word indices the grammar says a new line should start at.
///
/// Verse starts are ALWAYS included, at every level, and that is a
/// measured decision rather than a tidy one: only **37.3%** of the
/// 7,916 tagged Greek verses begin at a clause joint (60.0% of the
/// 23,204 Semitic ones). Leave verse starts out and, on first open,
/// nearly two thirds of Greek verses run into the line above with
/// nothing on screen to distinguish "the versification cuts this
/// sentence" from "the tool is broken". A break the reader did not ask
/// for costs one click to undo, and the undo is remembered; a missing
/// boundary costs their confidence in the whole pane.
Set<int> autoBreakPoints(List<PhrasingWord> words, PhrasingLevel level) {
  final out = <int>{};
  if (words.isEmpty) return out;
  out.add(0);
  for (var i = 1; i < words.length; i++) {
    if (words[i].verse != words[i - 1].verse) out.add(i);
  }
  if (level == PhrasingLevel.verses) return out;
  for (var i = 1; i < words.length; i++) {
    if (_breaksAt(words[i], level)) out.add(i);
  }
  return out;
}

bool _breaksAt(PhrasingWord w, PhrasingLevel level) {
  final parsed = parseMorphology(w.morph);
  if (parsed == null) return _strongsBreaks(w, level);
  return parsed.scheme == MorphScheme.greek
      ? _greekBreaks(parsed, level)
      : _semiticBreaks(parsed, level);
}

/// The joints a Strong's number alone can find, for a tagged
/// translation, which carries no parse.
///
/// A conjunction is the one part of speech whose Strong's number IS its
/// identity: G2532 is καί wherever it stands, so a run of English or
/// Chinese tagged G2532 marks where the Greek joins two things, and the
/// clause level survives translation intact. The relative pronouns and
/// prepositions below were derived the same way the conjunction tables
/// were — by counting the bundled corpus, not by copying a paradigm —
/// and a number is listed only where the corpus parses it that way in
/// the MAJORITY of its occurrences. That test is what keeps ὡς G5613 out
/// of the prepositions: it is tagged `P-` four times against 504 as a
/// conjunction or adverb, so listing it would have cut a line before
/// every "as" in the New Testament.
///
/// **The Hebrew half is honestly weaker and the reason is structural.**
/// A Semitic conjunction is usually a PREFIX — the waw — with no
/// Strong's number of its own, so a tagged Old Testament run carries the
/// number of its host word and the joint is invisible from here. Only
/// standalone conjunctions (כִּי H3588, אִם H518 …) are found. That is a
/// smaller proposal, not a wrong one, and the reader still has the
/// verse level and their own hands.
bool _strongsBreaks(PhrasingWord w, PhrasingLevel level) {
  final s = w.strongs;
  if (s.isEmpty) return false;
  if (_greekConjunctions.containsKey(s) ||
      _semiticConjunctions.containsKey(s) ||
      _greekRelatives.contains(s)) {
    return true;
  }
  // Verbals are skipped deliberately: mood is not recoverable from a
  // Strong's number, and guessing which of a verb's occurrences are
  // participles would put breaks in places the grammar does not.
  if (level.index >= PhrasingLevel.phrases.index &&
      _greekPrepositions.contains(s)) {
    return true;
  }
  return false;
}

/// Which levels the loaded passage can actually propose, best-effort
/// first.
///
/// Offering a level that has nothing to say is the failure this exists
/// to prevent: a reader who taps `+ Verbals` on an English translation
/// and sees the diagram not change learns that the tool is broken, when
/// the truth is that their text does not carry a parse. The page greys
/// the rest and says why.
///
/// [PhrasingLevel.verses] is always in the set — a passage can always be
/// cut at its verse boundaries, and that is the honest starting point
/// for a reader doing the whole analysis themselves.
Set<PhrasingLevel> availablePhrasingLevels(List<PhrasingWord> words) {
  var hasMorph = false;
  var hasStrongs = false;
  for (final w in words) {
    if (!hasMorph && parseMorphology(w.morph) != null) hasMorph = true;
    if (!hasStrongs && w.strongs.isNotEmpty) hasStrongs = true;
    if (hasMorph && hasStrongs) break;
  }
  return {
    PhrasingLevel.verses,
    if (hasMorph || hasStrongs) PhrasingLevel.clauses,
    if (hasMorph) PhrasingLevel.verbals,
    if (hasMorph || hasStrongs) PhrasingLevel.phrases,
  };
}

/// Greek relative pronouns by Strong's number.
///
/// Four numbers cover 1,671 of the corpus's 1,672 `RR` words. The fifth,
/// ὁποῖος G3697, occurs once as a relative against five times otherwise
/// and fails the majority test.
const Set<String> _greekRelatives = {
  'G3739', // ὅς 1403
  'G3748', // ὅστις 144
  'G3745', // ὅσος 110
  'G3634', // οἷος 14
};

/// Greek prepositions by Strong's number: 43 numbers covering 10,790 of
/// the corpus's 10,852 `P-` words.
const Set<String> _greekPrepositions = {
  'G1722', 'G1519', 'G1537', 'G1909', 'G4314', 'G1223', 'G575', 'G2596',
  'G3326', 'G4012', 'G5259', 'G3844', 'G5228', 'G4862', 'G2193', 'G1799',
  'G4253', 'G1715', 'G891', 'G5565', 'G1752', 'G3694', 'G473', 'G1883',
  'G3360', 'G4008', 'G5270', 'G5484', 'G3342', 'G2713', 'G1726', 'G561',
  'G2714', 'G5231', 'G427', 'G1725', 'G817', 'G2943', 'G3924', 'G495',
  'G1900', 'G481', 'G5238',
};

bool _greekBreaks(MorphWord w, PhrasingLevel level) {
  final m = w.morphemes.first;
  final pos = m.pos;
  if (pos == 'C-' || pos == 'RR') return true;
  if (level.index >= PhrasingLevel.verbals.index && pos == 'V-') {
    final mood = m.slots[MorphSlot.mood];
    // MorphGNT mood letters: P participle, N infinitive. Both open a
    // subordinate verbal unit; the finite moods (I D S O) do not,
    // because a finite verb is the backbone of the clause it is in.
    if (mood == 'P' || mood == 'N') return true;
  }
  if (level.index >= PhrasingLevel.phrases.index && pos == 'P-') return true;
  return false;
}

/// A Semitic word is a stack, and which morpheme you ask matters.
///
/// The conjunction and the preposition are PREFIXES, so they are the
/// FIRST morpheme; the participle/infinitive is the HEAD, which in
/// `HR/Vqc` (לְ + infinitive construct) is the second. Asking the head
/// about conjunctions, or the first morpheme about verb conjugation,
/// finds almost nothing: of the corpus's 7,489 infinitives only 837
/// stand in first position — the other 6,652 sit behind a לְ־ or a וְ־,
/// so a first-morpheme test would miss 89% of them.
bool _semiticBreaks(MorphWord w, PhrasingLevel level) {
  final first = w.morphemes.first;
  if (first.pos == 'C') return true;
  final head = w.morphemes[w.headIndex];
  // Open Scriptures particle subtypes: `r` is the relative (אֲשֶׁר, שֶׁ),
  // 5,228 words in the corpus. The other eight subtypes — definite
  // article, object marker, negative, interrogative … — are not joints.
  if (head.pos == 'T' && head.slots[MorphSlot.subtype] == 'r') return true;
  if (level.index >= PhrasingLevel.verbals.index && head.pos == 'V') {
    final c = head.slots[MorphSlot.conjugation];
    // r/s participle & passive participle, a/c infinitive absolute &
    // construct.
    if (c == 'r' || c == 's' || c == 'a' || c == 'c') return true;
  }
  if (level.index >= PhrasingLevel.phrases.index && first.pos == 'R') {
    return true;
  }
  return false;
}

// ── The proposal: what the relation probably is ──────────────────────

/// Relations the opening word of a line suggests, best first, or empty
/// when the grammar has nothing to say.
///
/// Returning a LIST rather than a single value is the point. ὅτι is
/// causal and content-introducing in roughly comparable numbers; ἵνα is
/// purpose and (in Koine) result; ὡς is comparison and time. Collapsing
/// those to one answer would teach the reader a falsehood in the one
/// place they came for help. The caller shows the head of the list as a
/// *suggestion*, visually distinct from a chosen label, and offers the
/// rest first in the picker.
List<PhrasingRelation> suggestRelations(PhrasingWord word) {
  final parsed = parseMorphology(word.morph);
  if (parsed == null) {
    // A tagged translation. The conjunction tables are keyed by Strong's
    // already, so they answer here unchanged; what is lost is the check
    // that the parser had called the word a conjunction, and with it the
    // safety that note guaranteed for ἕως G2193. Left in anyway: ἕως is
    // temporal in both its roles, so the suggestion is right either way.
    if (_greekRelatives.contains(word.strongs)) {
      return const [PhrasingRelation.relative];
    }
    return _greekConjunctions[word.strongs] ??
        _semiticConjunctions[word.strongs] ??
        const [];
  }
  if (parsed.scheme == MorphScheme.greek) {
    final pos = parsed.morphemes.first.pos;
    if (pos == 'RR') return const [PhrasingRelation.relative];
    if (pos != 'C-') return const [];
    return _greekConjunctions[word.strongs] ?? const [];
  }
  final first = parsed.morphemes.first;
  final head = parsed.morphemes[parsed.headIndex];
  if (head.pos == 'T' && head.slots[MorphSlot.subtype] == 'r') {
    return const [PhrasingRelation.relative];
  }
  if (first.pos != 'C') return const [];
  if (parsed.morphemes.length > 1) {
    // A PREFIXED conjunction. Its Strong's number belongs to the host
    // word, not to the prefix, so it cannot be looked up — but it does
    // not need to be: 50,852 of the corpus's 50,883 prefixed
    // conjunctions (**99.94%**) are the waw, and the 31 exceptions are
    // Aramaic כְּ־ forms. Waw is the least committal connective in the
    // language, so both readings are offered and neither is asserted.
    return const [PhrasingRelation.series, PhrasingRelation.progression];
  }
  return _semiticConjunctions[word.strongs] ?? const [];
}

/// Greek conjunctions by Strong's number.
///
/// Every entry below occurs in the bundled SBLGNT; the list was built
/// by counting the corpus's `C-` words by Strong's and walking down the
/// frequency table, not by copying a grammar's paradigm list. Counts in
/// comments are from that census.
const Map<String, List<PhrasingRelation>> _greekConjunctions = {
  'G2532': [PhrasingRelation.series, PhrasingRelation.progression], // καί 8169
  'G1161': [PhrasingRelation.progression, PhrasingRelation.contrast], // δέ 2760
  'G3754': [PhrasingRelation.content, PhrasingRelation.ground], // ὅτι 1212
  'G1063': [PhrasingRelation.ground], // γάρ 1038
  'G2443': [PhrasingRelation.purpose, PhrasingRelation.result], // ἵνα 637
  'G235': [PhrasingRelation.contrast], // ἀλλά 632
  'G3767': [PhrasingRelation.inference], // οὖν 490
  'G5613': [PhrasingRelation.comparison, PhrasingRelation.temporal], // ὡς 463
  'G1487': [PhrasingRelation.condition], // εἰ 458
  'G2228': [PhrasingRelation.alternative], // ἤ 339
  'G1437': [PhrasingRelation.condition], // ἐάν 267
  'G5037': [PhrasingRelation.series], // τε 213
  'G2531': [PhrasingRelation.comparison], // καθώς 182
  'G3303': [PhrasingRelation.contrast], // μέν 156 (μέν … δέ)
  'G3752': [PhrasingRelation.temporal, PhrasingRelation.condition], // ὅταν 115
  'G3761': [PhrasingRelation.series], // οὐδέ 88
  'G3753': [PhrasingRelation.temporal], // ὅτε 88
  'G3777': [PhrasingRelation.series], // οὔτε 86
  'G5620': [PhrasingRelation.result], // ὥστε 83
  'G1535': [PhrasingRelation.alternative], // εἴτε 65
  'G1352': [PhrasingRelation.inference], // διό 53
  'G3704': [PhrasingRelation.purpose], // ὅπως 51
  'G3366': [PhrasingRelation.series], // μηδέ 51
  'G686': [PhrasingRelation.inference], // ἄρα 46
  'G3699': [PhrasingRelation.place], // ὅπου 42
  'G1893': [PhrasingRelation.ground], // ἐπεί 26
  'G1894': [PhrasingRelation.ground], // ἐπειδή 10
  'G1360': [PhrasingRelation.ground], // διότι 23
  'G5618': [PhrasingRelation.comparison], // ὥσπερ 36
  // ἕως is a preposition 107× and a conjunction 38×. The entry is safe
  // because [suggestRelations] only consults this table for a word the
  // parser has already called `C-`.
  'G2193': [PhrasingRelation.temporal],
  'G4250': [PhrasingRelation.temporal], // πρίν 7
  'G2544': [PhrasingRelation.concession], // καίτοιγε 1
};

/// Hebrew/Aramaic **standalone** conjunctions by Strong's number.
///
/// Only words whose entire morphology is a single conjunction morpheme
/// appear here, because only those own their Strong's number. Counts
/// from the same census; together these are 5,873 of the corpus's
/// 5,864 standalone conjunction tokens' most common forms.
const Map<String, List<PhrasingRelation>> _semiticConjunctions = {
  // כִּי 4375 — the workhorse, and genuinely three-ways ambiguous.
  'H3588': [
    PhrasingRelation.ground,
    PhrasingRelation.content,
    PhrasingRelation.temporal,
  ],
  'H518': [PhrasingRelation.condition], // אִם 789
  'H176': [PhrasingRelation.alternative], // אוֹ 321
  'H6435': [PhrasingRelation.purpose], // פֶּן 128 (negative purpose)
  'H3282': [PhrasingRelation.ground], // יַעַן 96
  'H1768': [PhrasingRelation.relative, PhrasingRelation.content], // דִּי 39 (Aram.)
  'H1115': [PhrasingRelation.purpose], // בִּלְתִּי 22
  'H6903': [PhrasingRelation.ground], // קֳבֵל 22 (Aram.)
  'H3863': [PhrasingRelation.condition], // לוּ 18
  'H2006': [PhrasingRelation.condition], // הֵן 15 (Aram.)
  'H3884': [PhrasingRelation.condition], // לוּלֵא 14
  // Deliberately ABSENT, each verified against the corpus rather than
  // assumed from a lexicon: לְמַעַן H4616, כֵּן H3651 and אֲשֶׁר H834 never
  // occur as a standalone conjunction morpheme (0, 0 and 0 of 5,864),
  // so an entry for any of them would be dead code that reads like
  // coverage. אֲשֶׁר is reached instead through the `Tr` relative
  // particle, which is how Open Scriptures actually tags its 4,809
  // occurrences.
};
