/// Hover proposes, a click commits.
///
/// BibleWorks' Analysis window follows the mouse, and its own manual
/// admits what that costs: "If you hold down the Shift key as you move
/// the mouse cursor the content of the Word Analysis Window will not
/// change with mouse movements. This allows you to freeze the contents
/// of the window while you move the mouse cursor to the Word Analysis
/// Window to use the scroll bar or to select text for copying."
/// (bwh10a). Without that brake, a pointer-driven readout destroys
/// itself: the reader moves toward the pane to read what appeared, the
/// pointer crosses every word between here and there, and the thing
/// they were reaching for is gone before they arrive.
///
/// Shift-freeze answers it badly. It needs a keyboard (this app is
/// blocked below 1072px precisely so it can live on tablets, where
/// there is no Shift and no hover at all); it must be *held* while the
/// hand is also moving; and it freezes the PANE rather than naming a
/// WORD, so nothing on screen tells you which word you froze. That last
/// one is why BibleWorks' own Browse window shows no mark for it.
///
/// So: a click PINS a word. A pin is an identity, not a mode — it names
/// one occurrence, it is drawn in the text, and while it stands the
/// pointer can go anywhere without changing the subject. Shift-freeze
/// stays, because it is free and a BibleWorks reader will try it.
library;

/// A stable identity for one printed occurrence of a word.
///
/// Book and chapter are in the key, not just verse and index, because a
/// pin outlives navigation: without them, pinning word 2 of verse 3 in
/// John 1 would light up word 2 of verse 3 in John 2 the moment the
/// reader turned the page.
///
/// [versionCode] is the gutter label, so the same Greek word printed on
/// the originals line and on a tagged translation are different
/// occurrences — which is correct. They are different marks on screen.
String browseWordKey({
  required String prefix,
  required String versionCode,
  required int verse,
  required int index,
}) =>
    '$prefix|$versionCode|$verse|$index';

/// The book-and-chapter half of a [browseWordKey]. The Browse window
/// builds it once and hands it to every row, so the format lives here
/// alone rather than being re-spelled at each of the two line builders.
String browseKeyPrefix(String book, int chapter) => '$book|$chapter';

/// How one word should be drawn. Five states, and every pair of them has
/// to be told apart at a glance or the reader will not trust any of them.
///
/// Listed in increasing precedence, which is also the order [markFor]
/// tests them in.
enum WordMark {
  none,

  /// The active search matches this word.
  hit,

  /// Another printed occurrence of the same lexical Strong's number as
  /// the word under study — the same Greek or Hebrew word, landing
  /// somewhere else on screen, usually in another translation.
  sibling,

  /// The pointer is on it right now.
  hover,

  /// The reader clicked it, and the Analysis pane is held on it.
  pinned,
}

/// The lexical Strong's number whose other printed occurrences should
/// light up, or `''` for none.
///
/// The subject is whichever word the Analysis pane is currently
/// describing — pinned if there is a pin, otherwise the last one hovered.
/// Deriving the lit set from that one value rather than re-deciding it
/// here is what keeps the green words and the pane in agreement: they
/// cannot disagree because there is only one answer. It also means the
/// echoes stay lit while the reader moves off the text to read the pane,
/// which is the entire point of the pin.
///
/// [keyPrefix] is the `book|chapter` of the text on screen NOW, and the
/// gate matters: a pin outlives navigation, so without it, pinning
/// γίνομαι in John 1 and turning the page would light up every γίνομαι
/// in John 2 — with no pinned word visible anywhere to explain the
/// colour, because the pin's own key names a chapter that is no longer
/// printed.
///
/// The trailing separator in the comparison is load-bearing: `John|1` is
/// a prefix of `John|11`, so testing the bare prefix would leak chapter
/// 1's pin into chapters 10 through 19.
String siblingStrongs({
  required String? subjectKey,
  required String subjectStrongs,
  required String keyPrefix,
}) =>
    (subjectKey != null &&
            subjectKey.startsWith('$keyPrefix|') &&
            subjectStrongs.isNotEmpty)
        ? subjectStrongs
        : '';

/// What the Analysis pane is looking at.
///
/// Two independent facts: which occurrence is the pane's current
/// SUBJECT ([hoverKey]), and which occurrence the reader committed to
/// ([pinnedKey]).
///
/// [hoverKey] is read at two levels, and the distinction is what keeps
/// the marks from flickering. The Browse window threads down the
/// *latched* subject — the word the pane is describing right now — and
/// each word widget overrides it with [withHover] only while the
/// pointer is physically inside that word. So the subject keeps its
/// mark while the pointer crosses the 5px gap between two words, and a
/// word under the pointer still lights up even when the subject is
/// frozen by a pin or by Shift, so the text never feels dead.
///
/// Threading the pointer position alone would flash: in the gap no word
/// is hovered, the latched subject would fall through to
/// [WordMark.sibling] against its own [litStrongs], and every word the
/// reader swept past would blink green on the way out.
class AnalysisFocus {
  const AnalysisFocus({
    this.pinnedKey,
    this.hoverKey,
    this.litStrongs = '',
  });

  static const empty = AnalysisFocus();

  final String? pinnedKey;
  final String? hoverKey;

  /// The lexical Strong's number being studied — see [siblingStrongs].
  /// Every OTHER word carrying it is drawn as a [WordMark.sibling].
  /// Empty when nothing is under study.
  final String litStrongs;

  bool get isPinned => pinnedKey != null;

  /// True when a hover event is allowed to replace what the Analysis
  /// pane is describing.
  ///
  /// A pin outranks Shift: Shift is a transient brake, the pin is a
  /// standing decision, and releasing Shift must not quietly discard it.
  bool acceptsHoverUpdate({required bool shiftHeld}) =>
      !isPinned && !shiftHeld;

  /// The pointer moved. [key] is null when it left the text entirely.
  AnalysisFocus withHover(String? key) => key == hoverKey
      ? this
      : AnalysisFocus(
          pinnedKey: pinnedKey, hoverKey: key, litStrongs: litStrongs);

  /// A word was clicked.
  ///
  /// Clicking the pinned word again releases it — that is the unpin a
  /// reader finds without being told. Clicking a *different* word moves
  /// the pin rather than being swallowed, which is the single most
  /// important case: on a touch screen there is no hover, so a tap is
  /// the only way to look at anything, and a pin that refused to move
  /// would strand a tablet reader on the first word they ever touched.
  AnalysisFocus withTap(String key) => AnalysisFocus(
        pinnedKey: pinnedKey == key ? null : key,
        hoverKey: hoverKey,
        litStrongs: litStrongs,
      );

  /// Esc, the pane's Unpin button, or a click on empty space.
  AnalysisFocus unpinned() => isPinned
      ? AnalysisFocus(hoverKey: hoverKey, litStrongs: litStrongs)
      : this;

  /// True when [withTap] on [key] would release rather than move the
  /// pin. Callers need this *before* applying the tap, because
  /// releasing must not also drag the Analysis pane to another tab.
  bool tapWouldUnpin(String key) => pinnedKey == key;

  /// How to draw the word identified by [key].
  ///
  /// Precedence is pinned > hover > sibling > hit, and it is deliberate.
  /// Hovering the pinned word must not blink its marker off — the pin is
  /// the stronger claim and the reader is checking that it is still
  /// there. A hit is standing state and loses to every live signal.
  ///
  /// [strongs] is this word's own lexical number. The word under study
  /// is drawn as pinned or hovered rather than as a sibling of itself:
  /// the pointer is already on it, so what the reader needs colour for
  /// is the occurrences they are NOT looking at. That also makes the
  /// count honest — the number of green words is the number of other
  /// places this same original word landed.
  ///
  /// The subject keeps its own mark even after the pointer leaves the
  /// text, because the Browse window threads the latched subject in as
  /// [hoverKey] rather than the live pointer position. Letting it fall
  /// through to [WordMark.sibling] instead would read as "one word in
  /// four translations", which is the yahwehdehua.net picture and
  /// tempting — but it costs the reader the one thing colour is for
  /// here, which is knowing which of the four they are actually being
  /// told about, and it makes the mark blink every time the pointer
  /// crosses the gap between two words.
  WordMark markFor(String key, {String strongs = '', bool hit = false}) {
    if (key == pinnedKey) return WordMark.pinned;
    if (key == hoverKey) return WordMark.hover;
    if (litStrongs.isNotEmpty && strongs == litStrongs) {
      return WordMark.sibling;
    }
    return hit ? WordMark.hit : WordMark.none;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalysisFocus &&
          other.pinnedKey == pinnedKey &&
          other.hoverKey == hoverKey &&
          other.litStrongs == litStrongs);

  @override
  int get hashCode => Object.hash(pinnedKey, hoverKey, litStrongs);

  @override
  String toString() =>
      'AnalysisFocus(pinned: $pinnedKey, hover: $hoverKey, lit: $litStrongs)';
}
