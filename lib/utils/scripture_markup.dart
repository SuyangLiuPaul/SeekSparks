/// 2026-08-06 (SeekSparks): the editorial apparatus inside verse text.
///
/// Several bundled translations carry their publisher's markup inline
/// and SeekSparks was printing it raw. LEB's Genesis 1:2 rendered as
///
///     Now<note: Or "And"> the earth was formless … darkness [was] over
///
/// which is not a reading experience. It is not rare either: `<note:…>`
/// appears in 14,515 of LEB's 30,552 verses — 48% of the translation —
/// plus 1,247 verses of 和合本雅伟版 and 999 of 梁家铿译本.
///
/// Two different things are tangled together and they deserve opposite
/// treatments:
///
///   * `<note: …>` is a TRANSLATOR'S FOOTNOTE. It is commentary about
///     the text, not the text, so it leaves the reading flow entirely
///     and becomes a marker the reader can open.
///   * `[was]` is SUPPLIED WORDS — text with no counterpart in the
///     Hebrew or Greek, added so the English reads. It IS the text, and
///     printed Bibles have marked it for centuries. It stays, set apart
///     visually rather than deleted.
///
/// 2026-08-07: a square bracket is not always a supplied word, and in
/// 和合本雅伟版 it is almost never one. `主[雅伟]` does not mean the
/// editor ADDED 雅伟; it means the 主 printed here is Yahweh — the
/// received text had the Name and the CUV translated it away, and this
/// edition exists to say so. The arrow points the opposite way from a
/// supplied word: supplied = the target has more than the source, gloss
/// = the source had something the target lost. Rendering the Name in
/// the italic reserved for a translator's insertion states the reverse
/// of what the edition is claiming.
///
/// The convention is closed and was counted, not guessed: across
/// `cuvs-yhwh` and `cuvs-yhwh-tr` every bracket in the whole Bible is
/// one of two tokens — 212 × `[雅伟]`/`[雅偉]` and 17 × `[基督]`. The
/// second is the same device pointing at the Messiah rather than the
/// Name (Matthew 22:44 carries both in one verse, which is why they
/// cannot be told apart by styling one of them as an insertion).
///
/// Pure parsing. The widget decides what italic and muted look like.
library;

/// What a run of verse text is.
enum ScriptureSpanKind {
  /// The translation itself.
  plain,

  /// Words the translator supplied, bracketed in the source.
  supplied,

  /// A translator's footnote, lifted out of the flow.
  note,

  /// The divine name, restored where the translation rendered it away.
  /// `主[雅伟]` — the 主 printed here is Yahweh.
  divineName,

  /// The same editorial device naming a different referent: `主[基督]`,
  /// this κύριος is the Messiah.
  gloss,
}

/// Divine-name tokens, in every form the bundled assets use.
///
/// `耶和华`/`耶和華` are here because a bracket carrying them is the
/// same claim in a non-restored edition, even though no shipped asset
/// currently writes one.
const Set<String> _divineNameTokens = {
  '雅伟',
  '雅偉',
  '雅威',
  'Yahweh',
  'YHWH',
  'YHVH',
  '耶和华',
  '耶和華',
};

/// Referent glosses that are not the divine name.
const Set<String> _referentTokens = {
  '基督',
  'Christ',
  'Messiah',
  '弥赛亚',
  '彌賽亞',
};

/// What a bracketed body IS.
///
/// Anything outside the two closed sets is a supplied word, which is
/// the right default: BSB alone brackets 18,744 runs and every one of
/// them is a genuine insertion.
ScriptureSpanKind bracketSpanKind(String body) {
  final b = body.trim();
  if (_divineNameTokens.contains(b)) return ScriptureSpanKind.divineName;
  if (_referentTokens.contains(b)) return ScriptureSpanKind.gloss;
  return ScriptureSpanKind.supplied;
}

/// Whether a bracketed body is an editorial referent gloss rather than
/// a supplied word — the two kinds that keep their brackets.
bool isReferentGloss(String body) =>
    bracketSpanKind(body) != ScriptureSpanKind.supplied;

class ScriptureSpan {
  const ScriptureSpan(this.text, this.kind);

  final String text;
  final ScriptureSpanKind kind;

  @override
  String toString() => '${kind.name}:$text';

  @override
  bool operator ==(Object other) =>
      other is ScriptureSpan && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);
}

// `<note: Or "And">` — the body may contain quotes and punctuation but
// never a closing angle bracket, so a non-greedy scan to `>` is exact.
final RegExp _noteRe = RegExp(r'<note:\s*([^>]*)>');

// `[was]`. Deliberately does NOT match across `]` so two adjacent
// insertions stay two spans.
final RegExp _suppliedRe = RegExp(r'\[([^\]]*)\]');

/// Display noise: marks that belong to a printed page, not to a
/// verse-per-line reader.
///
/// Only the pilcrow. NASB uses `¶` to mark where a paragraph starts —
/// 965 verses carry one — which means nothing in a reader that already
/// begins each verse on its own line, and shows up as a stray symbol
/// before the first word.
///
/// Deliberately NOT stripped, having checked what they actually are:
///   * `─` (1,456× in 和合本雅伟版) is the Chinese appositive dash —
///     雅伟─他神. It is content; removing it would maim the apposition
///     in every verse that uses one.
///   * `䍁` (9×) is a real character: 䍁子, the tassels of 民数记 15:38.
///   * `\u2009` (608× in NASB) is a thin space holding nested quote
///     marks apart so `.’ ”` does not collide.
///
/// A blunt "strip odd characters" pass would have deleted all three.
final RegExp _displayNoiseRe = RegExp(r'¶\s*');

String _stripNoise(String s) => s.replaceAll(_displayNoiseRe, '');

/// Split verse text into typed spans.
///
/// Notes are returned in place so a caller that wants a marker knows
/// WHERE it belongs; a caller that wants them gone can filter by kind.
List<ScriptureSpan> parseScripture(String raw) {
  if (raw.isEmpty) return const [];
  final out = <ScriptureSpan>[];

  void addPlain(String raw) {
    final s = _stripNoise(raw);
    if (s.isEmpty) return;
    // Merge with a preceding plain span so callers never see the text
    // arbitrarily chopped where a note happened to sit.
    if (out.isNotEmpty && out.last.kind == ScriptureSpanKind.plain) {
      out[out.length - 1] =
          ScriptureSpan(out.last.text + s, ScriptureSpanKind.plain);
    } else {
      out.add(ScriptureSpan(s, ScriptureSpanKind.plain));
    }
  }

  // One pass over whichever marker comes first.
  var rest = raw;
  while (rest.isNotEmpty) {
    final note = _noteRe.firstMatch(rest);
    final sup = _suppliedRe.firstMatch(rest);
    if (note == null && sup == null) {
      addPlain(rest);
      break;
    }
    final noteAt = note?.start ?? 1 << 30;
    final supAt = sup?.start ?? 1 << 30;
    if (noteAt <= supAt) {
      addPlain(rest.substring(0, note!.start));
      final body = (note.group(1) ?? '').trim();
      if (body.isNotEmpty) {
        out.add(ScriptureSpan(body, ScriptureSpanKind.note));
      }
      rest = rest.substring(note.end);
    } else {
      addPlain(rest.substring(0, sup!.start));
      final body = sup.group(1) ?? '';
      if (body.isNotEmpty) {
        out.add(ScriptureSpan(body, bracketSpanKind(body)));
      }
      rest = rest.substring(sup.end);
    }
  }
  return out;
}

/// The verse as it should READ — notes gone, supplied words kept
/// without their brackets, referent glosses kept WITH theirs.
///
/// The asymmetry is the point. A supplied word reads as part of the
/// sentence, so unbracketing it yields the sentence. A gloss does not:
/// unbracketing `主[雅伟]` yields `主雅伟`, a divine title the verse
/// does not contain, and the reader has no way to tell it was never
/// there. The bracket is the only thing separating the edition's claim
/// from the text it is a claim about.
///
/// This is what search, copy-to-clipboard and text-to-anything should
/// use. A reader copying John 1:1 wants the verse, not the apparatus.
String scriptureReadingText(String raw) {
  final buf = StringBuffer();
  for (final s in parseScripture(raw)) {
    switch (s.kind) {
      case ScriptureSpanKind.note:
        continue;
      case ScriptureSpanKind.divineName:
      case ScriptureSpanKind.gloss:
        buf.write('[${s.text}]');
      case ScriptureSpanKind.plain:
      case ScriptureSpanKind.supplied:
        buf.write(s.text);
    }
  }
  // Lifting a note out can leave a doubled space or a space before
  // punctuation; neither is visible in the source but both are in the
  // result.
  return buf
      .toString()
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      // replaceAll does NOT interpolate $1 in Dart — it inserts the
      // literal two characters. Must be replaceAllMapped.
      .replaceAllMapped(RegExp(r' ([,.;:!?])'), (m) => m.group(1)!)
      .trim();
}

/// Every footnote in a verse, in order.
List<String> scriptureNotes(String raw) => [
      for (final s in parseScripture(raw))
        if (s.kind == ScriptureSpanKind.note) s.text,
    ];

/// Whether a verse carries any apparatus at all — lets a caller skip
/// span rendering entirely for the ~half of verses that are plain.
bool hasScriptureMarkup(String raw) =>
    raw.contains('<note:') || raw.contains('[');

// ── Lexicon entries ──────────────────────────────────────────────────

// The bundled Hebrew/Greek lexicons came from e-Sword/MySword modules
// and kept that format's reference syntax: `(# 創 10:4|)`. It appears
// ~14k times in each of hebrew.json and greek.json, and rendered raw it
// is the "weird symbols" a reader sees in the word study pane.
final RegExp _lexRefRe = RegExp(r'\(#\s*([^)|]*?)\s*\|?\s*\)');

/// Clean a lexicon definition for display.
///
/// `(# 創 10:4|)` → `(創 10:4)`, and stray pipes go. The reference is
/// kept — it is useful — only its module syntax is dropped.
String cleanLexiconText(String raw) {
  if (raw.isEmpty) return raw;
  var s = raw.replaceAllMapped(_lexRefRe, (m) {
    final ref = (m.group(1) ?? '').trim();
    return ref.isEmpty ? '' : '($ref)';
  });
  // Bare pipes are module field separators, never content.
  s = s.replaceAll('|', ' ');
  return s
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAllMapped(
          RegExp(r' ([,.;:!?，。；：！？])'), (m) => m.group(1)!)
      .trim();
}
