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

/// How one word should be drawn. Four states, and every pair of them has
/// to be told apart at a glance or the reader will not trust any of them.
enum WordMark {
  none,

  /// The active search matches this word.
  hit,

  /// The pointer is on it right now.
  hover,

  /// The reader clicked it, and the Analysis pane is held on it.
  pinned,
}

/// What the Analysis pane is looking at.
///
/// Two independent facts: which occurrence the pointer is over
/// ([hoverKey], which keeps tracking even while pinned, so the text
/// never feels dead under the mouse), and which occurrence the reader
/// committed to ([pinnedKey]).
class AnalysisFocus {
  const AnalysisFocus({this.pinnedKey, this.hoverKey});

  static const empty = AnalysisFocus();

  final String? pinnedKey;
  final String? hoverKey;

  bool get isPinned => pinnedKey != null;

  /// True when a hover event is allowed to replace what the Analysis
  /// pane is describing.
  ///
  /// A pin outranks Shift: Shift is a transient brake, the pin is a
  /// standing decision, and releasing Shift must not quietly discard it.
  bool acceptsHoverUpdate({required bool shiftHeld}) =>
      !isPinned && !shiftHeld;

  /// The pointer moved. [key] is null when it left the text entirely.
  AnalysisFocus withHover(String? key) =>
      key == hoverKey ? this : AnalysisFocus(pinnedKey: pinnedKey, hoverKey: key);

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
      );

  /// Esc, the pane's Unpin button, or a click on empty space.
  AnalysisFocus unpinned() =>
      isPinned ? AnalysisFocus(hoverKey: hoverKey) : this;

  /// True when [withTap] on [key] would release rather than move the
  /// pin. Callers need this *before* applying the tap, because
  /// releasing must not also drag the Analysis pane to another tab.
  bool tapWouldUnpin(String key) => pinnedKey == key;

  /// How to draw the word identified by [key].
  ///
  /// Precedence is pinned > hover > hit, and it is deliberate. Hovering
  /// the pinned word must not blink its marker off — the pin is the
  /// stronger claim and the reader is checking that it is still there.
  /// A hit is standing state and loses to both live signals.
  WordMark markFor(String key, {bool hit = false}) {
    if (key == pinnedKey) return WordMark.pinned;
    if (key == hoverKey) return WordMark.hover;
    return hit ? WordMark.hit : WordMark.none;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalysisFocus &&
          other.pinnedKey == pinnedKey &&
          other.hoverKey == hoverKey);

  @override
  int get hashCode => Object.hash(pinnedKey, hoverKey);

  @override
  String toString() =>
      'AnalysisFocus(pinned: $pinnedKey, hover: $hoverKey)';
}
