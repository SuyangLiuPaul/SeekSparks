/// 投影 — the passage on the wall at the front of the room.
///
/// 精读圣经 shipped this in 0.4.1; neither YouVersion nor 微读 has it, and
/// until now neither did SeekSparks. It is not a reading surface. The
/// person driving it is standing at a laptop at the back of a hall with
/// their hands on the arrow keys and their eyes on the congregation, and
/// the people it is FOR are forty feet away and cannot touch it at all.
/// Every decision below falls out of that one sentence.
///
/// ## THE SECOND DISPLAY, AND WHY THIS VERSION IS ONE WINDOW
///
/// The obvious ask is "put the passage on the projector and keep the
/// controls on the laptop", and on the web the obvious answer is a
/// `window.open` popout. It was investigated and rejected, and this is
/// the reasoning rather than a shrug:
///
///   * **A popout is a second APP, not a second view.** A new browser
///     window is a new document, so it boots its own Flutter engine and
///     its own Dart isolate. Nothing in this repo is shared across that
///     boundary — not `MainProvider`, not the corpus, not the LRU in
///     `MainProvider._versesCache`. The popout would cold-boot the whole
///     app: `assets/bsb.json` is 5.9 MB and `cuvs-yhwh` 5.3 MB, and
///     `workbench_warmup.dart`'s own measurements put a cold workbench
///     at ~11.4 s. The congregation would watch a splash screen.
///
///   * **Syncing them is a subsystem, not a page.** Two documents can
///     talk over `BroadcastChannel` or a `storage` event, and this app
///     has neither — `link_opener_web.dart` is the entire extent of its
///     cross-window interop, and it only opens a link. A real channel
///     needs a message protocol, a decision about which window owns the
///     cursor, a join handshake (the popout boots seconds late and must
///     ask for the current state rather than start at Genesis 1),
///     recovery when the operator closes or reloads either window, and a
///     truce with `UrlSyncService`, which already owns the address bar
///     in both. The brief said not to half-build it. That is the half.
///
///   * **Flutter's own multi-view embedding does not cross a window.**
///     It renders one app into several host elements of the SAME
///     document; the engine binds pointer input, DPR and lifecycle to
///     the opener's `window`, so a view adopted into a popup is not a
///     supported configuration — and turning multi-view on at all is a
///     change to how `main()` boots, which is not a new page.
///
///   * **The browser APIs that sound relevant are not.** The
///     Presentation API addresses a casting receiver, not an attached
///     monitor. Chrome's Window Management API (`getScreenDetails`) can
///     place a window on a chosen screen — which is the easy half. It
///     does nothing about state, which is the hard half, and it is
///     Chromium-only behind a permission prompt.
///
/// So: **this version is single-window, deliberately.** The operator
/// drags the SeekSparks window onto the projector's display and drives
/// it from the laptop keyboard. Keyboard focus stays with that window
/// wherever the window is, so every key below works with the operator
/// looking at the room instead of at the screen. That is why the
/// keyboard is the mechanism here and not a convenience, why the
/// reference sits in a corner instead of in a header the operator would
/// have to lean in to read, and why the blank key exists at all.
/// [projectionStrings]'s `projectionOneWindowNote` says this to the
/// operator in one line, because a design decision nobody is told about
/// reads as a missing feature.
///
/// ## THE TYPE SCALE IS THE ROOM'S, NOT THE READER'S
///
/// [kProjectionTypeSteps] is a separate ladder and does not consult
/// `AppSettings.fontSize` at any point. Those are answers to two
/// different questions — "how big do I like my text on this laptop" and
/// "how far away is the back row" — and a reader who studies at 14 pt
/// does not want a 17 px verse on the wall. The smallest step here (32)
/// is above the largest size the reading slider can produce in the
/// workbench (`WbMetrics.text` at `kFontSizeMax`, i.e. 24), which is the
/// property `projection_cursor_test.dart` pins: the two scales do not
/// merely differ, they do not overlap. `projection_page_test.dart` pins
/// the other half behaviourally — the reader's slider driven from one
/// end to the other while the wall does not move, in the DECLARED size
/// and in the painted rect, because a `FittedBox` can make the first
/// true and the second false.
///
/// The chosen step is a CEILING, not a fixed size. The passage sits in a
/// `BoxFit.scaleDown` fit at the full usable width, so a long verse
/// shrinks to fit the wall rather than running off it, and a short one
/// is drawn at exactly the size the operator asked for. Clipping a verse
/// in front of a congregation is not a degradation, it is a wrong text.
///
/// ## THE PALETTE IS DARK, INCLUDING THE READER'S, AND THE GROUND IS
/// NOW CHOSEN FROM A SET OF DARKS
///
/// Every other surface in the app follows the reader — light, dark, or
/// 护眼纸质 — and this one does not, because the surface is not the
/// reader's desk. A projector adds light: white pixels wash a room, dark
/// pixels are the closest thing a projector has to "off", and the blank
/// key is only honest if blanking lands on the same dark ground the
/// passage was already sitting on. Blanking a cream page to black is a
/// flash across the whole wall.
///
/// 2026-09-09 — 「背景也不能set」 — the ground is a CHOICE, and the two
/// sentences above are what bounds the choice rather than what forbids
/// it. Every option in [ProjectionGround] is dark, the blank state
/// paints whichever one is chosen rather than cutting to black, and
/// `projection_setup_test.dart` holds both to numbers: a luminance
/// ceiling on any colour a ground paints and a contrast floor for
/// scripture against it. There is no light ground and no photographic
/// one; `projection_setup.dart`'s library doc argues why, since that is
/// where the next person will look for the rule.
///
/// The claim this paragraph used to make — "no new colour is
/// introduced" — is retired with it, and it was always narrower than it
/// sounded: the wall is now `black`, a warm near-black or a two-stop
/// gradient when the operator says so. Everything else is unchanged and
/// still the design system's own ladder: `paneBg` for the control
/// strip, `border` for its hairline, `text` for scripture, `mutedText`
/// for the reference. The one addition is `accent` on the chip of a
/// chosen ground or edition, which is the palette's own "this one" and
/// which no congregation sees for more than the four seconds the strip
/// is up.
///
/// ## THE SETUP PERSISTS; THE BLANK DOES NOT
///
/// 2026-09-09. The type step, the second edition and whether it is on,
/// and the ground are `AppSettings` — one `_kProjection…` key each, all
/// new, none of them a rename or a reuse of an existing preference. The
/// operator who drives this weekly sets it up once.
///
/// `blank` stays a State field on this page and is deliberately not
/// persisted: someone who blacked the wall out and left does not want
/// to reopen onto a black wall, and the room stopped looking at the
/// wall the moment it went dark, so nobody is watching a stale blank to
/// notice it is wrong. A shutter is not a preference.
///
/// ## WHAT THIS DELIBERATELY IS NOT
///
/// Not a slide editor and not a song module. It is a live view over the
/// passage the reader is already on: it takes its starting reference
/// from `MainProvider` when it opens and gives nothing back when it
/// closes, which is why `projection_page_test.dart` can assert that
/// leaving restores the reader exactly where they were. The operator
/// advancing forty verses on the wall has not moved anybody's study.
///
/// That claim is about the CURSOR and it is unchanged. What the page
/// now stores is the operator's own setup, which belongs to the
/// projection and to nothing else — no setting here reaches the
/// reader's workspace, and the second edition in particular no longer
/// reads Split View's (see [_loadSecond]).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show
        availableVersions,
        bibleVersionLanguage,
        kSecondaryVersionKey,
        menuBibleVersionLabel,
        resolveSecondaryVersion,
        shortBibleVersionLabel;
import 'package:seeksparks/constants/book_names.dart' show bookNameToEnglish;
import 'package:seeksparks/constants/projection_setup.dart';
import 'package:seeksparks/constants/projection_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart'
    show WbColors, WbMetrics, WbType;
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/projection_agenda.dart';
import 'package:seeksparks/services/projection_broadcast.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/url_sync_service.dart';
import 'package:seeksparks/widgets/overflow_hint_scroll.dart';
import 'package:seeksparks/widgets/projection_stage.dart';

/// The type ladder, the grounds and the preset codec moved to
/// `constants/projection_setup.dart` on 2026-09-09, because
/// `AppSettings` persists them now and a settings model reaching into a
/// page for a constant is the wrong direction. Re-exported so every
/// caller that already says `kProjectionTypeSteps` off this page — the
/// two projection tests among them — keeps working, and so there is
/// still one obvious door to the projection's vocabulary.
export 'package:seeksparks/constants/projection_setup.dart';

/// The URL this page owns while it is open — see `page_links.dart` for
/// the two doors a page path arrives through, and `UrlClaim` for why the
/// claim carries an owner.
const String kProjectionUrlPath = '/project';

/// How long the on-screen controls linger after the pointer stops.
///
/// The brief asks for the chrome to be gone, and the operator still
/// needs buttons on a tablet where there is no keyboard at all. Both are
/// satisfied by controls that answer the pointer and then get out of the
/// way. Four seconds is long enough to move from one button to the next
/// and short enough that a bar left on the wall is measured in seconds.
const Duration kProjectionControlsLinger = Duration(seconds: 4);

/// The countdown lengths offered, in minutes.
///
/// A short list rather than a picker: the operator is choosing before a
/// service, not scheduling, and five values cover what a church actually
/// counts down — the last song, the last few minutes, and the quarter
/// hour a hall takes to fill.
const List<int> kProjectionCountdownMinutes = <int>[1, 3, 5, 10, 15];

/// How long the controls take to fade in and out.
///
/// Short, and a fade rather than a cut: the controls are on the wall too
/// (see the library doc — this is one window), and something that
/// appears and disappears instantly in a congregation's peripheral
/// vision reads as a fault.
const Duration kProjectionControlsFade = Duration(milliseconds: 180);

/// One thing the operator can ask the projection to do.
///
/// An enum rather than a set of callbacks so [projectionCommandFor] can
/// be tested without a widget, and so the on-screen buttons and the
/// keyboard dispatch through one switch instead of two — the defect
/// `keyboard_shortcuts.dart` was written to prevent, one surface along.
enum ProjectionCommand {
  nextVerse,
  previousVerse,
  nextChapter,
  previousChapter,

  /// Kill the wall without leaving the view.
  blank,

  biggerType,
  smallerType,

  /// Add or drop the second edition.
  toggleSecondVersion,

  /// Step to the next dark ground without opening anything.
  ///
  /// The one setup change that is a MID-SERVICE action — a room turns
  /// out to be brighter than the ground assumed and the operator wants
  /// the next one now, with their eyes on the congregation. Everything
  /// else in the setup opens a strip and is chosen by looking.
  cycleBackground,

  /// Open (or close) the strip of grounds.
  openBackgrounds,

  /// Open (or close) the strip of editions — the second edition's own
  /// picker, which is the thing 「两个经文也不能调整」 was about.
  openSecondVersionPicker,

  /// Open (or close) the strip of saved setups.
  openPresets,

  /// Open (or close) the order of service.
  openAgenda,

  /// Put the NEXT agenda item on the wall.
  agendaNext,

  /// Put the PREVIOUS agenda item on the wall.
  agendaPrevious,

  /// Open (or close) the countdown strip — or take a running countdown
  /// down, which is what it does while one is up.
  countdown,

  /// Open the follower window — `web/stage.html` on a BroadcastChannel.
  /// Web only; the button and the key are absent elsewhere. See
  /// `projection_broadcast.dart`.
  openStage,

  /// Leave, and put the operator back where they were.
  leave,
}

/// The command [key] means, or null when the projection does not answer
/// that key.
///
/// The bindings are the ones a person who has driven ANY presentation
/// tool already has in their fingers — space and the arrows advance,
/// PageUp/PageDown are the wireless clicker's two buttons, `B` blanks
/// (Keynote, PowerPoint and ProPresenter all use it), Esc leaves. Making
/// a room-facing tool invent its own is how an operator ends up reading
/// a cheatsheet during the sermon.
///
/// Deliberately unmodified keys only. `keyboard_shortcuts.dart` records
/// which Ctrl/Cmd chords the browser answers before the app ever sees
/// them; taking none of them is the simplest way to be sure this handler
/// never fights the browser it is running in.
///
/// Up and Down are verse keys rather than chapter keys because a
/// clicker's two buttons already are the chapter keys, and because the
/// arrows are what a hand finds without looking: all four should move
/// the same unit, in the direction they point.
ProjectionCommand? projectionCommandFor(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter) {
    return ProjectionCommand.nextVerse;
  }
  if (key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.backspace) {
    return ProjectionCommand.previousVerse;
  }
  if (key == LogicalKeyboardKey.pageDown) {
    return ProjectionCommand.nextChapter;
  }
  if (key == LogicalKeyboardKey.pageUp) {
    return ProjectionCommand.previousChapter;
  }
  if (key == LogicalKeyboardKey.keyB || key == LogicalKeyboardKey.period) {
    return ProjectionCommand.blank;
  }
  // Both faces of the two keys, because a keyboard prints `+` on the key
  // the operator presses and reports `=` unless they are holding Shift,
  // and a numeric keypad reports neither.
  if (key == LogicalKeyboardKey.equal ||
      key == LogicalKeyboardKey.add ||
      key == LogicalKeyboardKey.numpadAdd) {
    return ProjectionCommand.biggerType;
  }
  if (key == LogicalKeyboardKey.minus ||
      key == LogicalKeyboardKey.numpadSubtract) {
    return ProjectionCommand.smallerType;
  }
  if (key == LogicalKeyboardKey.keyP) {
    return ProjectionCommand.toggleSecondVersion;
  }
  // 2026-09-09, the setup keys. Mnemonic rather than positional — G for
  // ground, V for version, R for recall — because the whole argument
  // above is that an operator should not have to learn this page's own
  // scheme, and a letter that stands for the word is the closest a new
  // control gets to a binding somebody already has.
  //
  // G cycles rather than opening, for the reason `cycleBackground`
  // records: it is the one setup change worth making without looking.
  // V and R open a strip, because picking an edition out of fifteen or
  // a preset out of six is a thing you do by reading.
  if (key == LogicalKeyboardKey.keyG) {
    return ProjectionCommand.cycleBackground;
  }
  if (key == LogicalKeyboardKey.keyV) {
    return ProjectionCommand.openSecondVersionPicker;
  }
  // The order of service: A opens it, and the two brackets step it —
  // the pair a presentation tool uses for previous / next slide, and
  // neither of them a browser chord. C is the countdown; bare, so it
  // never fights Cmd+C, which kBrowserOwnedChords names and the
  // modifier guard in _onKey already lets through.
  if (key == LogicalKeyboardKey.keyA) {
    return ProjectionCommand.openAgenda;
  }
  if (key == LogicalKeyboardKey.bracketRight) {
    return ProjectionCommand.agendaNext;
  }
  if (key == LogicalKeyboardKey.bracketLeft) {
    return ProjectionCommand.agendaPrevious;
  }
  if (key == LogicalKeyboardKey.keyC) {
    return ProjectionCommand.countdown;
  }
  // D for display. Not a browser chord (kBrowserOwnedChords names C V X
  // F P S T W N L K R); a bare letter the operator hits once, at the
  // start, to put the wall up on the second screen.
  if (key == LogicalKeyboardKey.keyD) {
    return ProjectionCommand.openStage;
  }
  if (key == LogicalKeyboardKey.keyR) {
    return ProjectionCommand.openPresets;
  }
  if (key == LogicalKeyboardKey.escape) {
    return ProjectionCommand.leave;
  }
  return null;
}

/// Where the projection is pointing: a chapter, by its index in
/// `MainProvider.chapterList`, and a verse by its index within that
/// chapter.
///
/// Indices rather than a `(book, chapter, verse)` triple because the
/// question the movement keys ask is "what comes next", and only the
/// corpus's own order can answer it — Malachi is followed by Matthew and
/// no arithmetic on a chapter number knows that.
@immutable
class ProjectionCursor {
  const ProjectionCursor(this.chapter, this.verse, {this.count = 1})
      : assert(count >= 1);

  final int chapter;
  final int verse;

  /// How many verses, from [verse], are on the wall at once. One for
  /// everything the keys do; more when the projection was opened from a
  /// selection in the reader — 「可以按一个或者多个 然后就project」. A
  /// key press then moves on from the END of the block as a single
  /// verse: the selection was what the operator wanted shown, and what
  /// follows it is ordinary reading.
  final int count;

  /// The last verse of the block — where "next" continues from.
  ProjectionCursor get tail => ProjectionCursor(chapter, verse + count - 1);

  @override
  bool operator ==(Object other) =>
      other is ProjectionCursor &&
      other.chapter == chapter &&
      other.verse == verse &&
      other.count == count;

  @override
  int get hashCode => Object.hash(chapter, verse, count);

  @override
  String toString() => 'ProjectionCursor($chapter, $verse, count: $count)';
}

/// Where a projection opened from a SELECTION starts: the first selected
/// verse, and as many verses after it as are selected contiguously in
/// the same chapter. Verses in other chapters, or after a gap, are not
/// lost — they are simply where the next key press goes, one at a time.
///
/// Pure, so the tests can drive it without a corpus. [chapterIndexOf]
/// and [verseIndexOf] are the two lookups the page has and a test can
/// fake.
ProjectionCursor? projectionCursorFromSelection(
  List<Verse> selected, {
  required int? Function(String book, int chapter) chapterIndexOf,
  required int Function(int chapterIndex, Verse verse) verseIndexOf,
}) {
  if (selected.isEmpty) return null;
  final sorted = [...selected]..sort((a, b) {
      if (a.book != b.book) return 0;
      if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
      return a.verse.compareTo(b.verse);
    });
  final first = sorted.first;
  final chapter = chapterIndexOf(first.book, first.chapter);
  if (chapter == null) return null;
  final start = verseIndexOf(chapter, first);
  if (start < 0) return null;
  var count = 1;
  for (var i = 1; i < sorted.length; i++) {
    final v = sorted[i];
    if (v.book != first.book || v.chapter != first.chapter) break;
    if (v.verse != sorted[i - 1].verse + 1) break;
    count++;
  }
  return ProjectionCursor(chapter, start, count: count);
}

/// The cursor one verse either side of [from], rolling over the chapter
/// boundary.
///
/// [delta] is +1 or -1. [versesIn] answers how many verses a chapter
/// index holds; it is a callback rather than a list so a caller with
/// 1,189 chapters pays for the two it actually asks about, and so a test
/// can describe a three-chapter corpus in one line.
///
/// Returns [from] unchanged at either end of the corpus. Refusing to
/// move is the right answer to "next verse" at Revelation 22:21 — the
/// alternative is wrapping round to Genesis 1:1 in front of a
/// congregation, which looks like a crash.
///
/// Empty chapters are stepped OVER rather than landed on. Nothing in the
/// bundled corpora ships one, but a cursor resting on a chapter with no
/// verse to draw is a blank wall the operator cannot get off by pressing
/// the same key again.
ProjectionCursor projectionVerseStep(
  ProjectionCursor from,
  int delta, {
  required int chapterCount,
  required int Function(int chapterIndex) versesIn,
}) {
  assert(delta == 1 || delta == -1, 'a verse key moves exactly one verse');
  final next = from.verse + delta;
  if (next >= 0 && next < versesIn(from.chapter)) {
    return ProjectionCursor(from.chapter, next);
  }
  var chapter = from.chapter + delta;
  while (chapter >= 0 && chapter < chapterCount) {
    final count = versesIn(chapter);
    if (count > 0) {
      return ProjectionCursor(chapter, delta > 0 ? 0 : count - 1);
    }
    chapter += delta;
  }
  return from;
}

/// The head of the chapter [delta] away from [from].
///
/// Both directions land on the chapter's FIRST verse, including
/// backwards. "Previous chapter" from Genesis 2:14 means Genesis 1:1 and
/// not Genesis 1:31: the operator is moving to a passage, and a passage
/// starts at the top. (Pressing the verse key backwards from Genesis 2:1
/// still lands on Genesis 1:31, which is the other question, asked with
/// the other key.)
ProjectionCursor projectionChapterStep(
  ProjectionCursor from,
  int delta, {
  required int chapterCount,
  required int Function(int chapterIndex) versesIn,
}) {
  assert(delta == 1 || delta == -1, 'a chapter key moves exactly one chapter');
  var chapter = from.chapter + delta;
  while (chapter >= 0 && chapter < chapterCount) {
    if (versesIn(chapter) > 0) return ProjectionCursor(chapter, 0);
    chapter += delta;
  }
  return from;
}

/// Which strip of choices is open under the button bar, if any.
///
/// One at a time, and inline rather than in a popup menu. An overlay
/// would float over the passage — this is one window, so the
/// congregation is looking at whatever the operator opens — and it
/// would sit outside the bar's own fade, so the strip would still be on
/// the wall after the bar it belongs to had gone. A second row inside
/// the same fading band is the same information without either problem,
/// and it keeps every target in the band the operator's hand is already
/// in.
enum ProjectionPanel { grounds, editions, presets, agenda, countdown }


/// The language family of an edition code, for the companion pairing —
/// `zh-Hans` for anything the catalogue does not know, the same fallback
/// the picker uses, so the wall never asks for a companion of nothing.
String projectionLanguageOf(String code) => bibleVersionLanguage(code);

/// The edition the second block should be showing for [primary]: the
/// companion the operator set in Settings for the passage's language,
/// else the last edition chosen on this page, else nothing (the caller
/// falls back to the seed and the language default).
String? projectionCompanionPick(AppSettings settings, String primary) {
  final byLanguage =
      settings.projectionCompanionFor(projectionLanguageOf(primary));
  if (byLanguage != null && byLanguage.isNotEmpty) return byLanguage;
  final last = settings.projectionSecondVersion;
  return last.isEmpty ? null : last;
}

class ProjectionPage extends StatefulWidget {
  const ProjectionPage({super.key, this.verses});

  /// Verses to open ON, from the reader's selection bar. Null or empty
  /// means the reader's current position, as before. See
  /// [projectionCursorFromSelection] for what a multi-verse selection
  /// becomes.
  final List<Verse>? verses;

  @override
  State<ProjectionPage> createState() => _ProjectionPageState();
}

class _ProjectionPageState extends State<ProjectionPage> {
  final FocusNode _focus = FocusNode(debugLabel: 'projection');

  /// Where the operator has driven the projection to, or null while it
  /// is still sitting on the reference the reader was already at.
  ///
  /// Null is a real state and the reason the reader's own position is
  /// never written back: until the first key is pressed the projection
  /// simply RENDERS `MainProvider`'s reference, and after it there is a
  /// cursor of its own that nothing else reads. Neither branch touches
  /// the reader, which is what makes leaving a no-op.
  ProjectionCursor? _cursor;

  /// The wall is dark and the passage is gone.
  ///
  /// The one piece of projection state that is NOT persisted, and the
  /// library doc says why at length: an operator who blanked the wall
  /// and closed the page does not want to reopen onto a blank wall, and
  /// nobody in the room is looking at a dark wall to notice that it is
  /// stale. A shutter is not a preference.
  bool _blank = false;

  bool _controlsVisible = true;
  Timer? _controlsTimer;

  /// The strip of choices open under the buttons, or null.
  ProjectionPanel? _panel;

  /// The settings this page reads outside `build`. `listen: false`
  /// because every caller here is a command handler, not a builder —
  /// `build` watches them itself.
  AppSettings get _settings =>
      Provider.of<AppSettings>(context, listen: false);

  /// When the countdown runs out, or null when none is running. An END
  /// TIME rather than a remaining duration: a timer that ticks a number
  /// down drifts, and one paused by a suspended tab comes back wrong.
  /// Wall-clock arithmetic on every build cannot.
  DateTime? _countdownEnd;
  Timer? _countdownTicker;

  /// Time left, floored at zero, or null when nothing is counting.
  Duration? get _countdownLeft {
    final end = _countdownEnd;
    if (end == null) return null;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Where in the agenda the wall is, or null when it is simply
  /// following the reader. Not persisted: an order of service survives
  /// the week, but the place you had reached in it is this morning's.
  int? _agendaAt;

  /// The second edition's code once it has been resolved, and its text
  /// indexed as `'<English book>|<chapter>'` → verse number → text.
  ///
  /// Indexed at load rather than scanned at paint: the raw list is
  /// ~31,000 verses and the alternative is a linear scan of a whole
  /// Bible on every frame the wall draws.
  String? _secondCode;
  Map<String, Map<int, String>>? _secondIndex;
  bool _secondLoading = false;

  /// The stored preference the resident [_secondIndex] answers.
  ///
  /// Not the same string as [_secondCode]: the setting can hold `''`
  /// (never picked) or a retired code, and both RESOLVE to something
  /// else. Comparing the resolved code against the setting would never
  /// match in either case, and [_syncSecond] — which runs on every
  /// build — would reload a Bible every frame.
  String? _secondFrom;

  @override
  void initState() {
    super.initState();
    UrlSyncService.claimUrl(kProjectionUrlPath, owner: this);
    _restartControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    UrlSyncService.claimUrl(null, owner: this);
    _countdownTicker?.cancel();
    ProjectionBroadcast.close();
    _focus.dispose();
    super.dispose();
  }

  // ── the cursor ────────────────────────────────────────────────────

  /// The reference the reader is on, as a cursor, or null when the
  /// corpus has not finished loading.
  ///
  /// Recomputed on every build while [_cursor] is null, which is exactly
  /// the window in which it can change: a cold open at `#/project` puts
  /// this page on the initial route stack (see `page_links.dart`), so
  /// the first frames genuinely have no corpus and the reference arrives
  /// later.
  ProjectionCursor? _readerCursor(MainProvider mp) {
    final selected = widget.verses;
    if (selected != null && selected.isNotEmpty) {
      final seeded = projectionCursorFromSelection(
        selected,
        chapterIndexOf: (book, chapter) => mp.findChapterIndex(book, chapter),
        verseIndexOf: (chapterIndex, v) => _versesAt(mp, chapterIndex)
            .indexWhere((x) => x.verse == v.verse),
      );
      if (seeded != null) return seeded;
    }
    final chapter = mp.findChapterIndex(mp.currentBook, mp.currentChapter);
    if (chapter == null) return null;
    final verses = _versesAt(mp, chapter);
    if (verses.isEmpty) return null;
    final at = mp.currentVerse;
    // Book as well as chapter and verse: the workspace cursor can be
    // left behind in another book entirely (see
    // `MainProvider._settleCursorInCurrentChapter` on how that happens),
    // and `Genesis 3:16` matching `John 3:16` by number would open the
    // projection on a verse nobody chose.
    final index = at == null
        ? 0
        : verses.indexWhere((v) =>
            v.book == at.book && v.chapter == at.chapter && v.verse == at.verse);
    return ProjectionCursor(chapter, index < 0 ? 0 : index);
  }

  List<Verse> _versesAt(MainProvider mp, int chapterIndex) {
    final list = mp.chapterList;
    if (chapterIndex < 0 || chapterIndex >= list.length) return const [];
    final at = list[chapterIndex];
    return mp.versesInChapter(at.book, at.chapter);
  }

  void _move(ProjectionCommand command, MainProvider mp) {
    final from = _cursor ?? _readerCursor(mp);
    if (from == null) return;
    final chapterCount = mp.chapterList.length;
    int versesIn(int i) => _versesAt(mp, i).length;
    final to = switch (command) {
      ProjectionCommand.nextVerse => projectionVerseStep(from.tail, 1,
          chapterCount: chapterCount, versesIn: versesIn),
      ProjectionCommand.previousVerse => projectionVerseStep(from, -1,
          chapterCount: chapterCount, versesIn: versesIn),
      ProjectionCommand.nextChapter => projectionChapterStep(from, 1,
          chapterCount: chapterCount, versesIn: versesIn),
      ProjectionCommand.previousChapter => projectionChapterStep(from, -1,
          chapterCount: chapterCount, versesIn: versesIn),
      _ => from,
    };
    setState(() => _cursor = to);
  }

  // ── the commands ──────────────────────────────────────────────────

  /// Carry out one command, from a key or from a button.
  ///
  /// One switch for both, so the bar and the keyboard cannot drift apart
  /// — the defect `keyboard_shortcuts.dart` was written to prevent one
  /// surface along, where a sheet listing the shortcuts was maintained
  /// separately from the handler that dispatched them.
  ///
  /// Every command wakes the controls first. A key press is the operator
  /// saying they are here, and the bar they are about to want should
  /// already be on screen rather than one press behind.
  /// Every setup command writes to [AppSettings] rather than to a field
  /// here, and the page re-reads it on the rebuild the notification
  /// causes. There is no local mirror of a persisted value: a mirror is
  /// how a setting comes back different the next time the page is
  /// opened, which is the bug this whole change is about.
  ///
  /// The writes are deliberately not awaited. Each setter notifies
  /// SYNCHRONOUSLY and only then touches SharedPreferences, so the wall
  /// has already changed by the time this method returns; awaiting the
  /// disk write would mean an operator's key press waited on storage.
  void _run(ProjectionCommand command, MainProvider mp, AppSettings settings) {
    _wakeControls();
    switch (command) {
      case ProjectionCommand.nextVerse:
      case ProjectionCommand.previousVerse:
      case ProjectionCommand.nextChapter:
      case ProjectionCommand.previousChapter:
        _move(command, mp);
      case ProjectionCommand.blank:
        setState(() => _blank = !_blank);
      case ProjectionCommand.biggerType:
        unawaited(settings.setProjectionTypeStep(
            projectionTypeStep(settings.projectionTypeStep, 1)));
      case ProjectionCommand.smallerType:
        unawaited(settings.setProjectionTypeStep(
            projectionTypeStep(settings.projectionTypeStep, -1)));
      case ProjectionCommand.toggleSecondVersion:
        unawaited(
            settings.setProjectionSecondOn(!settings.projectionSecondOn));
      case ProjectionCommand.cycleBackground:
        final grounds = ProjectionGround.values;
        unawaited(settings.setProjectionGround(
            grounds[(settings.projectionGround.index + 1) % grounds.length]));
      case ProjectionCommand.openBackgrounds:
        _togglePanel(ProjectionPanel.grounds);
      case ProjectionCommand.openSecondVersionPicker:
        _togglePanel(ProjectionPanel.editions);
      case ProjectionCommand.openPresets:
        _togglePanel(ProjectionPanel.presets);
      case ProjectionCommand.openAgenda:
        _togglePanel(ProjectionPanel.agenda);
      case ProjectionCommand.agendaNext:
        _stepAgenda(mp, 1);
      case ProjectionCommand.agendaPrevious:
        _stepAgenda(mp, -1);
      case ProjectionCommand.countdown:
        // While one is running the button takes it down rather than
        // asking how long again: one key, both directions, which is
        // what an operator with their eyes on the room needs.
        if (_countdownEnd != null) {
          _stopCountdown();
        } else {
          _togglePanel(ProjectionPanel.countdown);
        }
      case ProjectionCommand.openStage:
        if (ProjectionBroadcast.isSupported) ProjectionBroadcast.openStage();
      case ProjectionCommand.leave:
        Navigator.of(context).maybePop();
    }
  }

  /// Open [panel], or close it if it is already the open one.
  ///
  /// The same button both ways: an operator who opened the wrong strip
  /// in front of a congregation needs the way out to be the control
  /// their hand is already on.
  void _togglePanel(ProjectionPanel panel) {
    setState(() => _panel = _panel == panel ? null : panel);
    // An open strip suspends the auto-hide, and closing one re-arms it
    // — see `_restartControlsTimer`.
    _restartControlsTimer();
  }

  KeyEventResult _onKey(
      FocusNode node, KeyEvent event, MainProvider mp, AppSettings settings) {
    // Key-up would fire a second time for every press, and a held key
    // legitimately repeats — an operator scrolling back through a psalm
    // holds the left arrow.
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // A chord is never ours. The map below is of BARE keys, and the
    // page's own doc says so — "deliberately unmodified keys only" — but
    // the map cannot see a modifier, so `V` matched Cmd+V and `R`
    // matched Cmd+R, and because this handler answers `handled` (which
    // on the web is `preventDefault`) the operator lost paste and reload
    // to a picker. Shift is allowed through: nothing binds a shifted
    // letter today, and a range-extending Shift+arrow is the obvious
    // next binding.
    final hk = HardwareKeyboard.instance;
    if (hk.isMetaPressed || hk.isControlPressed || hk.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final command = projectionCommandFor(event.logicalKey);
    // Ignored, not handled: a key this page has no use for stays the
    // browser's and the framework's. Consuming everything would be the
    // easy way to stop the passage scrolling under a space bar, and it
    // would also swallow the operator's Cmd+R.
    if (command == null) return KeyEventResult.ignored;
    _run(command, mp, settings);
    return KeyEventResult.handled;
  }

  // ── the second edition ────────────────────────────────────────────

  /// Load whichever edition the operator's own setting names, if the
  /// resident one is not already it.
  ///
  /// Called from `build`, so it must be cheap and must not `setState`
  /// synchronously — hence the guard chain and the post-frame hop.
  void _syncSecond(MainProvider mp, AppSettings settings) {
    if (!settings.projectionSecondOn) return;
    if (_secondLoading) return;
    // Compare against the SETTING, not the resolved code. See
    // `_secondFrom`.
    final want = projectionCompanionPick(settings, mp.currentVersion) ??
        settings.projectionSecondVersion;
    if (_secondFrom == want && _secondIndex != null) {
      return;
    }
    if (_secondFrom == want && _secondCode != null) {
      // Already answered this setting; the edition simply had no text
      // to give (a load failure, or an unbundled asset). Retrying every
      // frame would be a Bible parse per frame.
      return;
    }
    _secondFrom = want;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadSecond(mp, settings));
    });
  }

  /// Which edition the second block shows — **the projection's own
  /// answer**, not Split View's.
  ///
  /// Until 2026-09-09 this read `kSecondaryVersionKey` directly, which
  /// is the second column of the READER's split view. Two jobs were
  /// sharing one preference invisibly: changing the reader's second
  /// column silently changed what a church projected, and there was no
  /// control on either surface that said so. 「两个经文也不能调整」 is
  /// what that felt like from the operator's end — the second edition
  /// could be turned on and off and never chosen.
  ///
  /// So the projection has [AppSettings.projectionSecondVersion]. It is
  /// SEEDED from Split View's key the first time it is needed and
  /// stops following it after that, which is what makes this change
  /// invisible to an operator who already had the pairing they wanted:
  /// they get the same edition they were getting, and now it is theirs.
  ///
  /// `resolveSecondaryVersion` stays the resolver either way, so a code
  /// that has been retired between releases lands on its successor and
  /// an unknown one on the catalog's default rather than on an empty
  /// wall — the case a stored PRESET makes ordinary rather than
  /// hypothetical.
  Future<void> _loadSecond(MainProvider mp, AppSettings settings) async {
    setState(() => _secondLoading = true);
    final stored = settings.projectionSecondVersion;
    // Settings' per-language companion first, then this page's last
    // choice, then the split-view seed — see `projectionCompanionPick`.
    var pick = projectionCompanionPick(settings, mp.currentVersion) ?? '';
    if (pick.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      pick = prefs.getString(kSecondaryVersionKey) ?? '';
    }
    final code =
        resolveSecondaryVersion(primaryVersion: mp.currentVersion, stored: pick);
    // The seed, written back exactly once: after this the setting is
    // non-empty and the branch above is never taken again.
    if (stored.isEmpty) unawaited(settings.setProjectionSecondVersion(code));
    await mp.preloadVersion(code);
    final verses = mp.peekCachedVersion(code);
    if (!mounted) return;
    setState(() {
      _secondLoading = false;
      // The seed changed the setting under us, so record what the
      // resident index now answers rather than what it was asked.
      // Without this the notification from the seed would send
      // `_syncSecond` round a second time for the same edition.
      _secondFrom = projectionCompanionPick(settings, mp.currentVersion) ??
          (stored.isEmpty ? code : stored);
      _secondCode = code;
      _secondIndex = verses == null ? null : _indexVerses(verses);
    });
  }

  static Map<String, Map<int, String>> _indexVerses(List<Verse> verses) {
    final out = <String, Map<int, String>>{};
    for (final v in verses) {
      final book = bookNameToEnglish[v.book] ?? v.book;
      (out['$book|${v.chapter}'] ??= <int, String>{})[v.verse] = v.text;
    }
    return out;
  }

  // ── the controls, and their way out of the way ─────────────────────

  void _wakeControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _restartControlsTimer();
  }

  void _restartControlsTimer() {
    _controlsTimer?.cancel();
    // An open strip is the operator READING — a list of editions, a
    // list of presets — and four seconds is not long enough to read a
    // list and decide. So the auto-hide is suspended while a strip is
    // open and re-armed by the press that closes it. The bar is still
    // one press from gone, and it cannot be left up by accident because
    // choosing anything in the strip closes it.
    if (_panel != null) return;
    _controlsTimer = Timer(kProjectionControlsLinger, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MainProvider>();
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final cursor = _cursor ?? _readerCursor(mp);
    final verses =
        cursor == null ? const <Verse>[] : _versesAt(mp, cursor.chapter);
    final shown = cursor == null || cursor.verse >= verses.length
        ? const <Verse>[]
        : verses.sublist(
            cursor.verse,
            (cursor.verse + cursor.count).clamp(0, verses.length),
          );
    // The second edition is a persisted setting now, so the page can
    // OPEN with it already on — the load can no longer hang off the
    // toggle. This reconciles the resident corpus with the setting on
    // every build and schedules work only when they disagree.
    _syncSecond(mp, settings);
    final ground = settings.projectionGround;
    if (ProjectionBroadcast.isSupported) {
      final frame = _frame(mp, settings, ground, shown);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ProjectionBroadcast.post(frame);
      });
    }

    return Scaffold(
      // Under the stage, which fills the window — visible only in the
      // frame between a resize and the stage's repaint. The ground's
      // DARKEST colour, so that sliver is never brighter than the wall.
      backgroundColor: projectionGroundPaintFor(ground).base,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (node, event) => _onKey(node, event, mp, settings),
        child: MouseRegion(
          onHover: (_) => _wakeControls(),
          child: Listener(
            onPointerDown: (_) => _wakeControls(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ProjectionStage(
                    verses: shown,
                    reference: _referenceFor(shown),
                    versionCode: mp.currentVersion,
                    typeSize:
                        kProjectionTypeSteps[settings.projectionTypeStep],
                    blank: _blank,
                    locale: locale,
                    ground: ground,
                    secondOn: settings.projectionSecondOn,
                    secondTexts:
                        _secondTextsFor(shown, settings.projectionSecondOn),
                    secondCode: _secondCode,
                    secondLoading: _secondLoading,
                    countdownRemaining: _countdownLeft,
                  ),
                ),
                // THE CONTROLS SIT AT THE TOP, AND THE REFERENCE AT THE
                // BOTTOM, so the two can never occupy the same pixels.
                // The bar comes and goes; the reference is what the room
                // is following along by and must be legible in every
                // frame it is meant to be in. A bar that occludes it
                // four seconds at a time is a reference that is missing
                // exactly when the operator is doing something.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1 : 0,
                      duration: kProjectionControlsFade,
                      child: _controls(context, locale, mp, settings),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The second edition's text for the verse on screen, or null when the
  /// second block is off, still loading, or has nothing to say here.
  /// The second edition's text for each verse on the wall, aligned by
  /// position; null when the block is off or the corpus is not here.
  List<String?>? _secondTextsFor(List<Verse> verses, bool secondOn) {
    if (!secondOn || verses.isEmpty) return null;
    final index = _secondIndex;
    if (index == null) return null;
    return [
      for (final v in verses)
        index['${bookNameToEnglish[v.book] ?? v.book}|${v.chapter}']?[v.verse],
    ];
  }

  /// The corner reference, in the reading edition's own book-name
  /// language — `Verse.book` already carries it, so nothing has to be
  /// translated back and forth, and the reference cannot end up naming a
  /// book in a language the text beside it is not in.
  ///
  /// `verseLabel` rather than `verse`, because that is the number the
  /// EDITION prints: where a publisher merges two references into one
  /// block it reads `1-2`, and a room told `1` would be looking for a
  /// verse that is not separately printed in front of them.
  /// What the follower window paints — the same things the stage does,
  /// already resolved, so the follower needs no corpus and no Flutter.
  ProjectionFrame _frame(MainProvider mp, AppSettings settings,
      ProjectionGround ground, List<Verse> shown) {
    String hex(Color c) =>
        '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    final secondOn = settings.projectionSecondOn && shown.isNotEmpty;
    final texts = _secondTextsFor(shown, settings.projectionSecondOn);
    String? note;
    if (secondOn) {
      if (_secondLoading) {
        note = _s('projectionSecondVersionLoading',
            'Loading the second edition', settings.locale);
      } else if (texts == null || texts.every((t) => t == null)) {
        note = _s('projectionSecondVersionMissing',
            'This edition has no text here', settings.locale);
      }
    }
    final paint = projectionGroundPaintFor(ground);
    const wb = WbColors.dark;
    final left = _countdownLeft;
    return ProjectionFrame(
      blank: _blank,
      countdown: left == null ? null : formatProjectionCountdown(left),
      countdownLabel: left == null
          ? null
          : _s(
              left == Duration.zero
                  ? 'projectionCountdownNow'
                  : 'projectionCountdownSoon',
              left == Duration.zero
                  ? 'We are beginning'
                  : 'The service begins in',
              settings.locale),
      typeSize: kProjectionTypeSteps[settings.projectionTypeStep],
      reference: _referenceFor(shown),
      tags: [
        shortBibleVersionLabel(mp.currentVersion),
        if (secondOn && _secondCode != null)
          shortBibleVersionLabel(_secondCode!),
      ],
      verses: [
        for (final v in shown) {'label': v.verseLabel, 'text': v.text},
      ],
      second: secondOn && note == null && texts != null
          ? [
              for (var i = 0; i < shown.length; i++)
                {'label': shown[i].verseLabel, 'text': texts[i]},
            ]
          : null,
      secondNote: note,
      groundColors: [for (final c in paint.stops) hex(c)],
      radial: !paint.isFlat,
      ink: hex(wb.text),
      muted: hex(wb.mutedText),
    );
  }

  /// `创世纪 1:1`, or `创世纪 1:1–3` for a block. The range is spelled
  /// with the labels, not the numbers, so a merged verse keeps its
  /// `4-5` and the reference cannot claim a verse the wall is not
  /// showing.
  String _referenceFor(List<Verse> verses) {
    if (verses.isEmpty) return '';
    final first = verses.first;
    final head = '${first.book} ${first.chapter}:${first.verseLabel}';
    return verses.length == 1 ? head : '$head–${verses.last.verseLabel}';
  }

  /// The operator's buttons, for the configurations where the keyboard
  /// is not the answer — a mirrored laptop display, or a tablet, where
  /// there is no key to press.
  ///
  /// Sized off [WbType], which is to say the reader's own Menu Size,
  /// while the stage above is sized off the ROOM. That split is the
  /// whole type story of this page in one line: chrome belongs to the
  /// person operating it and scales with their settings; scripture on a
  /// wall belongs to the back row and does not.
  Widget _controls(BuildContext context, String locale, MainProvider mp,
      AppSettings settings) {
    final wb = WbColors.dark;
    final t = WbType.of(context);
    final secondOn = settings.projectionSecondOn;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: t.scaledChrome(12)),
        _strip(
          wb,
          t,
          locale,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // MOVEMENT FIRST, and in the same order and the same
              // place it has always been. Three controls arrived on
              // this bar in 2026-09; not one of them may cost the
              // operator the muscle memory for "next verse", so they
              // are appended in their own group and nothing above them
              // moved a pixel.
              _button(t, Icons.first_page, 'projectionPreviousChapter',
                  'Previous chapter', locale, ProjectionCommand.previousChapter,
                  mp, settings),
              _button(t, Icons.chevron_left, 'projectionPreviousVerse',
                  'Previous verse', locale, ProjectionCommand.previousVerse, mp,
                  settings),
              _button(t, Icons.chevron_right, 'projectionNextVerse',
                  'Next verse', locale, ProjectionCommand.nextVerse, mp,
                  settings),
              _button(t, Icons.last_page, 'projectionNextChapter',
                  'Next chapter', locale, ProjectionCommand.nextChapter, mp,
                  settings),
              _divider(wb, t),
              _button(
                  t,
                  _blank ? Icons.visibility : Icons.visibility_off,
                  _blank ? 'projectionUnblank' : 'projectionBlank',
                  _blank ? 'Show the passage' : 'Black out',
                  locale,
                  ProjectionCommand.blank,
                  mp,
                  settings),
              _divider(wb, t),
              _button(t, Icons.text_decrease, 'projectionTypeSmaller',
                  'Smaller type', locale, ProjectionCommand.smallerType, mp,
                  settings),
              _button(t, Icons.text_increase, 'projectionTypeBigger',
                  'Larger type', locale, ProjectionCommand.biggerType, mp,
                  settings),
              _divider(wb, t),
              _button(
                  t,
                  secondOn ? Icons.layers_clear : Icons.layers,
                  secondOn
                      ? 'projectionSecondVersionHide'
                      : 'projectionSecondVersionShow',
                  secondOn ? 'One edition only' : 'Add a second edition',
                  locale,
                  ProjectionCommand.toggleSecondVersion,
                  mp,
                  settings),
              // The picker sits NEXT TO the on/off switch rather than
              // inside a settings screen, because "which edition" is
              // the question an operator asks in the same breath as
              // "two editions" — 「两个经文也不能调整」 was that button
              // existing with no answer beside it.
              _button(t, Icons.translate, 'projectionSecondVersionPick',
                  'Choose the second edition', locale,
                  ProjectionCommand.openSecondVersionPicker, mp, settings,
                  active: _panel == ProjectionPanel.editions),
              _divider(wb, t),
              _button(t, Icons.gradient, 'projectionBackground', 'Background',
                  locale, ProjectionCommand.openBackgrounds, mp, settings,
                  active: _panel == ProjectionPanel.grounds),
              _button(t, Icons.bookmarks_outlined, 'projectionPresets',
                  'Saved setups', locale, ProjectionCommand.openPresets, mp,
                  settings, active: _panel == ProjectionPanel.presets),
              _divider(wb, t),
              _button(
                  t,
                  _countdownEnd == null
                      ? Icons.timer_outlined
                      : Icons.timer_off_outlined,
                  'projectionCountdown',
                  'Countdown',
                  locale,
                  ProjectionCommand.countdown,
                  mp,
                  settings,
                  active: _panel == ProjectionPanel.countdown),
              _button(t, Icons.list_alt_outlined, 'projectionAgenda',
                  'Order of service', locale, ProjectionCommand.openAgenda, mp,
                  settings, active: _panel == ProjectionPanel.agenda),
              if (ProjectionBroadcast.isSupported)
                _button(t, Icons.open_in_new, 'projectionOpenStage',
                    'Open the projector window', locale,
                    ProjectionCommand.openStage, mp, settings),
              _divider(wb, t),
              _button(t, Icons.close, 'projectionLeave', 'Leave projection',
                  locale, ProjectionCommand.leave, mp, settings),
            ],
          ),
        ),
        if (_panel != null) ...[
          SizedBox(height: t.scaledChrome(4)),
          _strip(wb, t, locale, _panelRow(wb, t, locale, mp, settings)),
        ],
        SizedBox(height: t.scaledChrome(6)),
        // Both lines are for the operator and both fade with the bar.
        // The keys line is how a mirrored setup learns the bindings; the
        // one-window line is the answer to the question the operator is
        // about to ask, said before they ask it rather than in a
        // release note nobody reads.
        // What is coming, for the person driving. A projector operator
        // reads one item ahead of the room; before this the only way to
        // know what `]` would do was to press it and find out in front
        // of everybody. Shown only when there IS an order of service.
        if (_nextAgendaLabel(locale) != null)
          _hint(
              wb,
              t,
              (_s('projectionAgendaNext', 'Next: {item}', locale))
                  .replaceAll('{item}', _nextAgendaLabel(locale)!)),
        _hint(wb, t, _s('projectionKeysHint', 'Arrows change verse', locale)),
        _hint(
            wb,
            t,
            _s('projectionOneWindowNote',
                'One window: put this window on the projector display.',
                locale)),
        SizedBox(height: t.scaledChrome(10)),
      ],
    );
  }

  /// One row of controls: a bordered pill that hugs its contents, and
  /// scrolls — with a fade and a chevron on whichever edge has more
  /// behind it — when the window cannot hold the whole row.
  ///
  /// This replaces a `FittedBox(BoxFit.scaleDown)`, which was the right
  /// answer at ten buttons and the wrong one at fourteen. Shrinking is
  /// not free on a strip whose whole premise is that it can be hit
  /// without looking: on a phone the icons had already been scaled to
  /// about two thirds, and four more would have taken them under a
  /// fingertip. `OverflowHintScroll` keeps every target full size and
  /// says which way the rest of them are — its own doc records the
  /// report it was written for, 「不往右划根本不知道」, which is exactly
  /// the failure a silently-clipped strip would have here.
  ///
  /// [OverflowHintScroll.minWidth] is the viewport, so a row that FITS
  /// is centred by its own `MainAxisAlignment.center` instead of
  /// hugging the left edge the way a bare scroll view would, and a row
  /// that does not fit exceeds the minimum and scrolls. The fade is
  /// `paneBg` because the only time a fade is drawn is when the pill is
  /// wider than the window, and then the pill is what is under it.
  Widget _strip(WbColors wb, WbType t, String locale, Widget row) =>
      LayoutBuilder(
        builder: (context, box) => OverflowHintScroll(
          fadeColor: wb.paneBg,
          minWidth: box.maxWidth,
          moreLabel: _s('projectionMoreControls', 'More controls', locale),
          backLabel:
              _s('projectionPreviousControls', 'Previous controls', locale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: wb.paneBg,
                  border:
                      Border.all(color: wb.border, width: WbMetrics.hairline),
                  borderRadius: BorderRadius.circular(WbMetrics.radiusSurface),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: row,
              ),
            ],
          ),
        ),
      );

  /// The open strip's contents.
  Widget _panelRow(WbColors wb, WbType t, String locale, MainProvider mp,
      AppSettings settings) {
    switch (_panel!) {
      case ProjectionPanel.grounds:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final ground in ProjectionGround.values)
              _chip(
                wb,
                t,
                _groundLabel(ground, locale),
                selected: settings.projectionGround == ground,
                onTap: () {
                  unawaited(settings.setProjectionGround(ground));
                  _closePanel();
                },
              ),
          ],
        );
      case ProjectionPanel.editions:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Full names, not the four-character gutter tags: 「BGT BSB
            // 雅简这些别人看简写不知道什么意思」, and this list is read
            // from further away than the gutter ever is.
            for (final code in _secondChoices(mp))
              _chip(
                wb,
                t,
                menuBibleVersionLabel(code),
                selected: _secondCode == code,
                onTap: () {
                  unawaited(settings.setProjectionSecondVersion(code));
                  // And as the companion for THIS language, so the
                  // choice made at the wall is the one Settings shows,
                  // and holds the next time a passage in this language
                  // goes up.
                  unawaited(settings.setProjectionCompanion(
                      projectionLanguageOf(mp.currentVersion), code));
                  // Choosing an edition also turns the block on. An
                  // operator who opened this strip has already decided
                  // there are two texts on the wall, and making them
                  // press a second button to see the one they just
                  // picked is the feature being unfinished again.
                  unawaited(settings.setProjectionSecondOn(true));
                  _closePanel();
                },
              ),
          ],
        );
      case ProjectionPanel.countdown:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in kProjectionCountdownMinutes)
              _chip(
                wb,
                t,
                (_s('projectionCountdownMinutes', '{n} minutes', locale))
                    .replaceAll('{n}', '$m'),
                selected: false,
                icon: Icons.timer_outlined,
                onTap: () {
                  _startCountdown(m);
                  _closePanel();
                },
              ),
          ],
        );
      case ProjectionPanel.agenda:
        final items = settings.projectionAgenda;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip(
              wb,
              t,
              _s('projectionAgendaAddCurrent', 'Add what is on the wall',
                  locale),
              selected: false,
              icon: Icons.add,
              onTap: () {
                final item = _currentAsAgendaItem(mp);
                if (item == null) return;
                unawaited(
                    settings.setProjectionAgenda([...items, item]));
              },
            ),
            _chip(
              wb,
              t,
              _s('projectionAgendaAddBlank', 'Add a blank', locale),
              selected: false,
              icon: Icons.visibility_off_outlined,
              onTap: () => unawaited(settings
                  .setProjectionAgenda([...items, const AgendaItem.blank()])),
            ),
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.scaledChrome(8)),
                child: Text(
                  _s('projectionAgendaNone', 'No order of service yet',
                      locale),
                  style: TextStyle(color: wb.mutedText, fontSize: t.chrome),
                ),
              ),
            for (var i = 0; i < items.length; i++)
              _chip(
                wb,
                t,
                items[i].label,
                selected: i == _agendaAt,
                onTap: () {
                  _showAgendaItem(mp, i);
                  _closePanel();
                },
                onRemove: () {
                  final next = [...items]..removeAt(i);
                  // The place in the list moves with the list, or goes
                  // away with it.
                  if (_agendaAt != null) {
                    if (_agendaAt == i) {
                      _agendaAt = null;
                    } else if (_agendaAt! > i) {
                      _agendaAt = _agendaAt! - 1;
                    }
                  }
                  unawaited(settings.setProjectionAgenda(next));
                },
                removeLabel:
                    _s('projectionAgendaRemove', 'Remove', locale),
              ),
          ],
        );
      case ProjectionPanel.presets:
        final presets = settings.projectionPresets;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip(
              wb,
              t,
              _s('projectionPresetSave', 'Save this setup', locale),
              selected: false,
              icon: Icons.add,
              onTap: () => _savePreset(context, locale, settings, t),
            ),
            if (presets.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.scaledChrome(8)),
                child: Text(
                  _s('projectionPresetNone', 'No saved setups yet', locale),
                  style: TextStyle(color: wb.mutedText, fontSize: t.chrome),
                ),
              ),
            for (final preset in presets)
              _chip(
                wb,
                t,
                preset.name,
                selected: false,
                onTap: () => _recallPreset(preset, mp, settings),
                onRemove: () => _deletePreset(preset, settings),
                removeLabel:
                    _s('projectionPresetDelete', 'Delete this setup', locale),
              ),
          ],
        );
    }
  }

  /// The editions the second block may show.
  ///
  /// The reading edition is left out: a wall carrying the same text
  /// twice is the one outcome worse than a wall carrying it once, which
  /// is the same judgement `resolveSecondaryVersion` records for Split
  /// View's column.
  List<String> _secondChoices(MainProvider mp) => <String>[
        for (final v in availableVersions)
          if (v.value != mp.currentVersion) v.value,
      ];

  String _groundLabel(ProjectionGround ground, String locale) =>
      switch (ground) {
        ProjectionGround.deep =>
          _s('projectionGroundDeep', 'Deep navy', locale),
        ProjectionGround.black => _s('projectionGroundBlack', 'Black', locale),
        ProjectionGround.warm =>
          _s('projectionGroundWarm', 'Warm dark', locale),
        ProjectionGround.vignette =>
          _s('projectionGroundVignette', 'Gradient', locale),
      };

  // ── the countdown ─────────────────────────────────────────────────

  /// Start a countdown of [minutes].
  ///
  /// The ticker only exists to repaint: the number is computed from
  /// [_countdownEnd] on every build, so a dropped or throttled tick
  /// shows a stale frame at worst and never a wrong time. It stops
  /// itself at zero — the wall keeps saying 「就要开始了」 until the
  /// operator takes it down, which is the state the room is in.
  void _startCountdown(int minutes) {
    _countdownTicker?.cancel();
    setState(() {
      _blank = false;
      _countdownEnd = DateTime.now().add(Duration(minutes: minutes));
    });
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownLeft == Duration.zero) timer.cancel();
      setState(() {});
    });
  }

  void _stopCountdown() {
    _countdownTicker?.cancel();
    _countdownTicker = null;
    setState(() => _countdownEnd = null);
  }

  // ── the order of service ──────────────────────────────────────────
  //
  // See `projection_agenda.dart` for why the rows are references rather
  // than copies of the text, and why there is no per-item styling.

  /// Put agenda row [index] on the wall.
  ///
  /// A row whose book the loaded edition does not have moves the cursor
  /// nowhere and leaves the wall as it was. Silently: the operator is
  /// mid-service, and an error dialog on a projector is worse than a
  /// passage that did not change.
  void _showAgendaItem(MainProvider mp, int index) {
    final items = _settings.projectionAgenda;
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    setState(() => _agendaAt = index);
    if (item.kind == AgendaKind.blank) {
      setState(() => _blank = true);
      return;
    }
    final chapter = mp.findChapterIndex(item.book, item.chapter);
    if (chapter == null) return;
    final verses = _versesAt(mp, chapter);
    // By printed number, not by position: an edition that merges 4-5
    // into one row would otherwise put a different verse on the wall
    // than the agenda names.
    final at = verses.indexWhere((v) => v.verse == item.verse);
    if (at < 0) return;
    setState(() {
      _blank = false;
      _cursor = ProjectionCursor(chapter, at, count: item.count);
    });
  }

  /// `]` and `[`. From nowhere, `]` starts at the top — which is what an
  /// operator pressing it at the start of a service means.
  void _stepAgenda(MainProvider mp, int delta) {
    final items = _settings.projectionAgenda;
    if (items.isEmpty) return;
    final at = _agendaAt;
    final next = at == null ? (delta > 0 ? 0 : items.length - 1) : at + delta;
    if (next < 0 || next >= items.length) return;
    _showAgendaItem(mp, next);
  }

  /// The passage on the wall right now, as an agenda row.
  AgendaItem? _currentAsAgendaItem(MainProvider mp) {
    final cursor = _cursor ?? _readerCursor(mp);
    if (cursor == null) return null;
    final verses = _versesAt(mp, cursor.chapter);
    if (cursor.verse >= verses.length) return null;
    final v = verses[cursor.verse];
    return AgendaItem(
      kind: AgendaKind.passage,
      book: v.book,
      chapter: v.chapter,
      verse: v.verse,
      count: cursor.count,
    );
  }

  /// The label of the row `]` would put up next, or null when there is
  /// no order of service. From nowhere it names the FIRST row, because
  /// that is what `]` does from nowhere — the hint describes the key,
  /// not the list.
  String? _nextAgendaLabel(String locale) {
    final items = _settings.projectionAgenda;
    if (items.isEmpty) return null;
    final at = _agendaAt;
    final next = at == null ? 0 : at + 1;
    if (next >= items.length) {
      return _s('projectionAgendaEnd', 'end of the order', locale);
    }
    return items[next].label;
  }

  void _closePanel() {
    setState(() => _panel = null);
    _restartControlsTimer();
  }

  /// Put a saved setup back on the wall.
  ///
  /// The stored edition goes through `resolveSecondaryVersion` FIRST —
  /// the same resolver [_loadSecond] uses — so a preset naming an
  /// edition this build no longer ships lands on its successor, or on
  /// the catalog's default, instead of on a second block with nothing
  /// in it. That is the ordinary case rather than the defensive one: a
  /// preset is the oldest thing in this feature and can easily name a
  /// version retired two releases after it was saved.
  void _recallPreset(
      ProjectionPreset preset, MainProvider mp, AppSettings settings) {
    final resolved = resolveSecondaryVersion(
      primaryVersion: mp.currentVersion,
      stored: preset.setup.secondVersion,
    );
    unawaited(settings
        .applyProjectionSetup(preset.setup.copyWith(secondVersion: resolved)));
    _closePanel();
  }

  void _deletePreset(ProjectionPreset preset, AppSettings settings) {
    unawaited(settings.setProjectionPresets(
        removeProjectionPreset(settings.projectionPresets, preset.name)));
    _wakeControls();
  }

  /// Name and save the setup that is on the wall right now.
  ///
  /// A dialog, and the one place on this page where one is right:
  /// naming is a before-service action, not a mid-service one, and a
  /// name cannot be entered from a strip of icons. While it is open the
  /// page's `Focus` does not have focus, so the operator can type a
  /// name containing `b` without blacking out the wall — and the focus
  /// is asked for again on the way out, because a projection whose
  /// arrow keys have stopped answering is a projection that is broken.
  Future<void> _savePreset(BuildContext context, String locale,
      AppSettings settings, WbType t) async {
    _controlsTimer?.cancel();
    final name = await showDialog<String>(
      context: context,
      // A StatefulWidget rather than a closure holding a controller: a
      // `TextEditingController` disposed the moment `showDialog`'s
      // future completes is disposed while the route is still animating
      // OUT, and the TextField rebuilds against it on the next frame.
      // The dialog owns its own controller so the two lifetimes are the
      // same lifetime.
      builder: (ctx) => _PresetNameDialog(locale: locale, type: t),
    );
    if (!mounted) return;
    _focus.requestFocus();
    _wakeControls();
    final trimmed = name == null ? '' : normalizeProjectionPresetName(name);
    // An empty name is a cancel. A preset chip with no label on it is a
    // control the operator cannot tell from the one beside it.
    if (trimmed.isEmpty) return;
    await settings.setProjectionPresets(upsertProjectionPreset(
      settings.projectionPresets,
      ProjectionPreset(name: trimmed, setup: settings.projectionSetup),
    ));
  }

  Widget _hint(WbColors wb, WbType t, String text) => Padding(
        padding: EdgeInsets.symmetric(horizontal: t.scaledChrome(24)),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: wb.mutedText, fontSize: t.chrome),
        ),
      );

  Widget _divider(WbColors wb, WbType t) => Container(
        width: WbMetrics.hairline,
        height: t.scaledChrome(16),
        margin: EdgeInsets.symmetric(horizontal: t.scaledChrome(4)),
        color: wb.border,
      );

  /// One choice in an open strip.
  ///
  /// A word, not an icon. The bar above says WHAT is being set with a
  /// glyph the operator learns once; a strip says WHICH, and "which
  /// edition" and "which saved setup" are not things a glyph can carry
  /// — the app has fifteen editions and the operator names their own
  /// presets. [selected] is carried on two axes at once, fill and
  /// border, for the reason `wordBoxFor` gives in `workbench_theme.dart`:
  /// one cue is one thing that can fail on a badly-calibrated projector.
  Widget _chip(
    WbColors wb,
    WbType t,
    String label, {
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    VoidCallback? onRemove,
    String? removeLabel,
  }) =>
      Padding(
        padding: EdgeInsets.symmetric(horizontal: t.scaledChrome(2)),
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: t.scaledChrome(9), vertical: t.scaledChrome(6)),
              decoration: BoxDecoration(
                color: selected ? wb.selectionBg : wb.chromeBg,
                border: Border.all(
                    color: selected ? wb.accent : wb.border,
                    width: WbMetrics.hairline),
                borderRadius: BorderRadius.circular(WbMetrics.radiusControl),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: t.scaledChrome(14), color: wb.text),
                    SizedBox(width: t.scaledChrome(4)),
                  ],
                  Text(label,
                      style: TextStyle(color: wb.text, fontSize: t.chrome)),
                  if (onRemove != null) ...[
                    SizedBox(width: t.scaledChrome(6)),
                    Semantics(
                      button: true,
                      label: removeLabel,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onRemove,
                        child: Icon(Icons.close,
                            size: t.scaledChrome(13), color: wb.mutedText),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  Widget _button(WbType t, IconData icon, String labelKey, String fallback,
      String locale, ProjectionCommand command, MainProvider mp,
      AppSettings settings,
      {bool active = false}) {
    final label = _s(labelKey, fallback, locale);
    return IconButton(
      // A button that OPENS a strip says so while the strip is open, in
      // the palette's own "this one" colour. Without it the three new
      // buttons are three ways to make a second row appear and no way
      // to tell which one put it there.
      icon: Icon(icon, color: active ? WbColors.dark.accent : WbColors.dark.text),
      iconSize: t.scaledChrome(20),
      tooltip: label,
      onPressed: () => _run(command, mp, settings),
    );
  }
}

/// "Name this setup", and nothing else.
///
/// Its own widget so it owns its [TextEditingController] — see
/// `_savePreset`. Pops the name, or pops nothing on cancel; an empty
/// name is treated as a cancel by the caller, because a preset chip
/// with no label on it is a control the operator cannot tell from the
/// one beside it.
class _PresetNameDialog extends StatefulWidget {
  const _PresetNameDialog({required this.locale, required this.type});

  final String locale;
  final WbType type;

  @override
  State<_PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<_PresetNameDialog> {
  late final TextEditingController _controller = TextEditingController(
      text: _s('projectionPresetDefaultName', 'Service', widget.locale));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.dark;
    final t = widget.type;
    final locale = widget.locale;
    return AlertDialog(
      backgroundColor: wb.paneBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WbMetrics.radiusSurface),
        side: BorderSide(color: wb.border, width: WbMetrics.hairline),
      ),
      title: Text(
        _s('projectionPresetSaveTitle', 'Name this setup', locale),
        style: TextStyle(color: wb.text, fontSize: t.text),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: kProjectionPresetNameLimit,
        style: TextStyle(color: wb.text, fontSize: t.text),
        cursorColor: wb.accent,
        decoration: InputDecoration(
          counterStyle: TextStyle(color: wb.mutedText, fontSize: t.chrome),
          enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: wb.border, width: WbMetrics.hairline)),
          focusedBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: wb.accent, width: WbMetrics.hairline)),
        ),
        // Return saves, because the operator's hands are already on the
        // keyboard — reaching for a button they cannot see from where
        // they are standing is the whole problem with a dialog here.
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            _s('projectionPresetCancel', 'Cancel', locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.chrome),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(
            _s('projectionPresetSave', 'Save this setup', locale),
            style: TextStyle(color: wb.text, fontSize: t.chrome),
          ),
        ),
      ],
    );
  }
}

/// `projectionStrings`, with English as the fallback locale before the
/// caller's own literal.
///
/// Named `_s` so `ui_string_keys_test.dart` recognises the lookups and
/// holds this file to all three languages — the same treatment the
/// wheel's own local string map gets.
String _s(String key, String fallback, String locale) =>
    projectionStrings[key]?[locale] ??
    projectionStrings[key]?['en'] ??
    fallback;
