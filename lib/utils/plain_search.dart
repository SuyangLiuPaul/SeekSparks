/// 2026-09-05 (SeekSparks): what a plain search — a command line with no
/// control character — is allowed to match.
///
/// Until now it was a substring scan over the verse key with **every
/// space taken out**, on both sides. That rule is right for Chinese and
/// wrong for every other script this app ships, and the wrongness is not
/// a corner case. Measured on the KJV (31,102 verses), before this file
/// and after it:
///
///     query     before    after    rows that only ever held a word gap
///     forth      3,419      877    2,542   ("for the")
///     asa        1,301      207    1,094   ("as a")
///     heirs        369       24      345   ("their shoulders")
///     end        1,524    1,205      319   ("seven days")
///     oar          237      117      120   ("also a righteous")
///     for the    2,029    2,020        9   ("bringeth forth evil")
///
/// The `forth` and `asa` columns land on the 2,542 and 1,094 that
/// `docs/PARITY-BACKLOG.md` measured when it recorded this defect, which
/// is the check that this is the same bug and not a neighbouring one.
/// The last row is the direction nobody expects: stripping spaces let a
/// query that HAS a space match text that does not, so `for the` was
/// over-counting by 9 as well.
///
/// Nothing in those rows is markable — `search_highlight.dart` marks the
/// query's literal, and the literal is not in the text — so the reader
/// is handed a verse with a hit they cannot find. That is the whole
/// defect: **a match that steps over a word gap the reader never typed.**
///
/// ## The rule
///
/// A plain query matches where its characters occur in the verse in
/// order and next to each other, with two deliberate exceptions:
///
///   1. **Whitespace the reader typed absorbs any amount of whitespace
///      in the verse, including none.** This is what the old space
///      strip was really buying and it is kept: `the lord` still reaches
///      a verse that sets those words across a line break, `爱 神` still
///      reaches 爱神, and `in deed` still reaches "indeed".
///   2. **Whitespace in the verse may be stepped over only where Han
///      characters stand on both sides of it.** Chinese does not put
///      spaces between words, so a space inside a run of Han characters
///      carries no boundary and is noise — of which the 和合本 has
///      exactly 14 verses' worth (`cuvs-yhwh.json`, e.g. 玛拉基书 2:1
///      「这 诫命」 and 历代志上 21:20 「就和他 四个儿子」). Scripture
///      text is frozen, so the search layer steps over them rather than
///      the asset being edited — and those two verses are the proof the
///      exception is load-bearing rather than theoretical: without it
///      这诫命 falls from 4 verses to 3 and 就和他四个儿子 from 1 to 0.
///
/// Nine Chinese probes over both editions (爱, 神, 爱神, 起初, 神爱世人,
/// 这诫命, 就和他四个儿子, 「起初 神」, 雅伟) return an identical count
/// before and after this change; so do four Greek probes over `lxxwh`,
/// accented and unaccented. Only the space-separated false positives
/// moved.
///
/// Exception 2 is the entire script-awareness, and it is stated as a
/// property of the characters rather than of a mode the reader selects:
/// there is no Chinese branch and no locale check, and a verse mixing
/// 和合本 text with a Latin proper name gets the Latin rule at the Latin
/// seam and the Han rule at the Han seam, within one verse.
///
/// **What this deliberately does NOT change:** a match still may sit
/// inside a word. `walk` still finds "walked" — 390 verses before and
/// 390 after, where `.walk` read as a whole word finds 203 — and
/// `shalom` still finds "Jehovahshalom", 3 before and 3 after.
/// `docs/PARITY-BACKLOG.md` separates the two cases and
/// calls the within-word one "arguably wanted"; it is also the only
/// prefix search a reader who has never heard of `*` will ever perform.
/// A hit inside a word is markable and a hit across a gap is not, which
/// is the line this file draws.
///
/// Hebrew and Greek take the alphabetic rule. Both are set with spaces,
/// and both arrive here with their points and accents already folded
/// away by `foldDiacritics` (#321), so pointed and unpointed spellings
/// reduce to the same consonants before any boundary is looked at. The
/// Hebrew maqqef `־` is NOT whitespace and is not treated as one: it
/// joins its two words into a single run here exactly as it already does
/// in `related_verses.dart`'s tokenizer, so nothing about `כָּל־הָאָרֶץ`
/// changes in either direction.
///
/// Pure string work: no Flutter, no assets, no I/O.
library;

import 'package:seeksparks/utils/related_verses.dart' show isCjkChar;

/// Whether [c] separates words rather than belonging to one.
///
/// `sanitizeForSearch` keeps `\n` — it is inert in a search index and
/// load-bearing in the poetry the same function feeds elsewhere — so the
/// corpus key really does carry line breaks, and the old strip removed
/// only U+0020. A reader typing a phrase that the edition happens to set
/// across two lines was therefore already failing before this file, and
/// treating every whitespace alike fixes that in passing. U+3000 is the
/// ideographic space, which is whitespace a Chinese edition can actually
/// contain.
bool isSearchSpace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0 || c == 0x3000;

/// Normalize whitespace for the plain-search comparison.
///
/// Every whitespace run becomes one U+0020, except a run with Han
/// characters on both sides, which is removed outright. Leading and
/// trailing whitespace goes.
///
/// Both sides of the comparison go through here — the corpus by way of
/// `searchCorpusKey`, the query by way of [plainSearchSegments] — so the
/// two can never disagree about what a boundary is. The last time a
/// probe re-implemented a sanitiser instead of calling it, the probe was
/// the thing that was wrong.
String collapseSearchSpaces(String text) {
  final n = text.length;
  final buf = StringBuffer();
  var i = 0;
  // Skip leading whitespace.
  while (i < n && isSearchSpace(text.codeUnitAt(i))) {
    i++;
  }
  while (i < n) {
    final c = text.codeUnitAt(i);
    if (!isSearchSpace(c)) {
      buf.writeCharCode(c);
      i++;
      continue;
    }
    var j = i;
    while (j < n && isSearchSpace(text.codeUnitAt(j))) {
      j++;
    }
    if (j >= n) break; // trailing run
    // The seam is Han-only when the character before the run and the
    // character after it are both Han. `i > 0` holds because leading
    // whitespace was already skipped.
    final han = isCjkChar(text.codeUnitAt(i - 1)) && isCjkChar(text.codeUnitAt(j));
    if (!han) buf.writeCharCode(0x20);
    i = j;
  }
  return buf.toString();
}

/// Split a plain query into the runs that must sit next to each other.
///
/// Folded and lower-cased here and nowhere else on the query side, which
/// is the other half of the comparison `searchCorpusKey` builds. An
/// empty list means the query cannot match anything — it was blank, or
/// nothing but whitespace.
List<String> plainSearchSegments(String foldedLowerQuery) {
  final key = collapseSearchSpaces(foldedLowerQuery);
  return [
    for (final s in key.split(' '))
      if (s.isNotEmpty) s
  ];
}

/// The one segment a whole-corpus scan can reject a verse on cheaply.
///
/// Every segment is a necessary condition, so the longest is the most
/// selective; callers that hold a `List<String>` of keys use this to
/// skip the [plainSearchMatches] walk for most of the corpus.
String plainSearchPrefilter(List<String> segments) {
  var best = '';
  for (final s in segments) {
    if (s.length > best.length) best = s;
  }
  return best;
}

/// Whether [key] holds [segments] contiguously, separated only by
/// whitespace the reader typed.
///
/// [key] must be a `searchCorpusKey` — folded, lower-cased and passed
/// through [collapseSearchSpaces]. The single-segment case, which is
/// almost every search anyone runs, is one `String.contains` and costs
/// exactly what the old space-stripped scan cost.
bool plainSearchMatches(String key, List<String> segments) {
  if (segments.isEmpty) return false;
  final first = segments.first;
  if (segments.length == 1) return key.contains(first);
  var from = 0;
  while (true) {
    final start = key.indexOf(first, from);
    if (start < 0) return false;
    var pos = start + first.length;
    var ok = true;
    for (var s = 1; s < segments.length; s++) {
      // Zero or more, so `in deed` still reaches "indeed" — exception 1.
      while (pos < key.length && key.codeUnitAt(pos) == 0x20) {
        pos++;
      }
      if (!key.startsWith(segments[s], pos)) {
        ok = false;
        break;
      }
      pos += segments[s].length;
    }
    if (ok) return true;
    from = start + 1;
  }
}
