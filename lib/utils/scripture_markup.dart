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
}

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

/// Split verse text into typed spans.
///
/// Notes are returned in place so a caller that wants a marker knows
/// WHERE it belongs; a caller that wants them gone can filter by kind.
List<ScriptureSpan> parseScripture(String raw) {
  if (raw.isEmpty) return const [];
  final out = <ScriptureSpan>[];

  void addPlain(String s) {
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
        out.add(ScriptureSpan(body, ScriptureSpanKind.supplied));
      }
      rest = rest.substring(sup.end);
    }
  }
  return out;
}

/// The verse as it should READ — notes gone, supplied words kept
/// without their brackets.
///
/// This is what search, copy-to-clipboard and text-to-anything should
/// use. A reader copying John 1:1 wants the verse, not the apparatus.
String scriptureReadingText(String raw) {
  final buf = StringBuffer();
  for (final s in parseScripture(raw)) {
    if (s.kind == ScriptureSpanKind.note) continue;
    buf.write(s.text);
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
