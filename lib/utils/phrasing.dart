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
}

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
bool phrasingIsRtl(List<PhrasingWord> words) {
  for (final w in words) {
    for (var i = 0; i < w.text.length; i++) {
      final c = w.text.codeUnitAt(i);
      // Hebrew block, then Hebrew presentation forms.
      if ((c >= 0x0590 && c <= 0x05FF) || (c >= 0xFB1D && c <= 0xFB4F)) {
        return true;
      }
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

  Phrasing copyWith({
    PhrasingLevel? level,
    Set<int>? added,
    Set<int>? removed,
    Map<int, int>? depths,
    Map<int, PhrasingRelation>? relations,
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
      );

  /// True when the reader has done anything at all. Drives whether the
  /// work is worth persisting.
  bool get isTouched =>
      added.isNotEmpty ||
      removed.isNotEmpty ||
      depths.isNotEmpty ||
      relations.isNotEmpty;

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
    );
  }
}

/// How far the first line may be indented. Every other line is bounded
/// by its predecessor; the first has no predecessor, so it needs a stop
/// of its own or a held-down button pushes the text out of view.
const int maxPhrasingDepth = 8;

/// One rendered line: the words `[start, end)`, at a *clamped* depth.
class PhrasingLine {
  const PhrasingLine({
    required this.start,
    required this.end,
    required this.depth,
    this.relation,
    this.suggested,
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

  int get length => end - start;
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
  final out = <PhrasingLine>[];
  var prevDepth = 0;
  for (var i = 0; i < starts.length; i++) {
    final start = starts[i];
    final end = i + 1 < starts.length ? starts[i + 1] : words.length;
    final raw = p.depths[start] ?? 0;
    // The first line may be indented too. It was pinned to the margin
    // because it has no predecessor to be subordinate TO, but that
    // conflated two things: depth as a grammatical claim, and depth as
    // the margin the whole block hangs from. Readers set the second one
    // by hand on paper all the time, and the reader who asked for this
    // had done exactly that in Word. With no parent above it there is
    // nothing to clamp against, so the only bound is [maxPhrasingDepth],
    // which stops a repeated tap walking the text off the right edge.
    final depth =
        i == 0 ? raw.clamp(0, maxPhrasingDepth) : raw.clamp(0, prevDepth + 1);
    final chosen = p.relations[start];
    out.add(PhrasingLine(
      start: start,
      end: end,
      depth: depth,
      relation: chosen,
      suggested: chosen == null && i > 0
          ? suggestRelations(words[start]).firstOrNull
          : null,
    ));
    prevDepth = depth;
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

/// Render the phrasing as indented plain text, for a paper, a sermon
/// manuscript, or an email.
///
/// [label] turns a relation into the reader's language; the core has no
/// locale, so the caller supplies it. [verseMark] is called for the
/// first word of each verse.
String exportPhrasing(
  Phrasing p,
  List<PhrasingWord> words, {
  required String Function(PhrasingRelation) label,
  String Function(int verse)? verseMark,
  String indentUnit = '    ',
}) {
  final lines = layoutPhrasing(p, words);
  final buf = StringBuffer();
  for (final line in lines) {
    buf.write(indentUnit * line.depth);
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
      if (i < line.end - 1) buf.write(' ');
    }
    buf.writeln();
  }
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
