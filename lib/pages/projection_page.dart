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
/// ## THE PALETTE IS FIXED DARK, INCLUDING THE READER'S
///
/// Every other surface in the app follows the reader — light, dark, or
/// 护眼纸质 — and this one does not, because the surface is not the
/// reader's desk. A projector adds light: white pixels wash a room, dark
/// pixels are the closest thing a projector has to "off", and the blank
/// key is only honest if blanking lands on the same dark ground the
/// passage was already sitting on. Blanking a cream page to black is a
/// flash across the whole wall.
///
/// It is still the design system's own ladder — `WbColors.dark`'s
/// `groundBg` for the wall, `paneBg` for the control strip, `text` for
/// scripture, `mutedText` for the reference — and no new colour is
/// introduced. The reader's chosen accent is not applied: nothing here
/// is clickable-in-the-accent-sense, and `WbColors.tinted`'s four roles
/// (link, accent, selection, hover) have no occurrence on a wall.
///
/// ## WHAT THIS DELIBERATELY IS NOT
///
/// Not a slide editor, not a song module, and it stores no presentation
/// state. It is a live view over the passage the reader is already on:
/// it takes its starting reference from `MainProvider` when it opens and
/// gives nothing back when it closes, which is why
/// `projection_page_test.dart` can assert that leaving restores the
/// reader exactly where they were. The operator advancing forty verses
/// on the wall has not moved anybody's study.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show kSecondaryVersionKey, resolveSecondaryVersion;
import 'package:seeksparks/constants/book_names.dart' show bookNameToEnglish;
import 'package:seeksparks/constants/projection_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart'
    show WbColors, WbMetrics, WbType;
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/url_sync_service.dart';
import 'package:seeksparks/widgets/projection_stage.dart';

/// The URL this page owns while it is open — see `page_links.dart` for
/// the two doors a page path arrives through, and `UrlClaim` for why the
/// claim carries an owner.
const String kProjectionUrlPath = '/project';

/// The sizes the operator steps through, in logical pixels.
///
/// A ladder rather than a slider: an operator adjusting this is doing it
/// mid-service with a room watching, and "press the key twice more" is a
/// thing you can do without looking.
///
/// The steps are a roughly constant RATIO (1.14–1.25, mean 1.17) rather
/// than a constant increment, because that is what a press being "the
/// same amount bigger" means to an eye. A fixed +8 would run 32→40, a
/// quarter larger and unmistakable, and 152→160, a twentieth and
/// invisible — the same key doing two different jobs at the two ends of
/// its own range.
///
/// The floor of 32 is not arbitrary. `WbMetrics.text` (12) at the
/// reading slider's maximum (`kFontSizeMax` / `kFontSizeDefault` = 2x)
/// is 24 px, so the smallest projection size is still a third larger
/// than the biggest size the reading setting can produce. The two scales
/// do not overlap, which is the whole point of there being two.
const List<double> kProjectionTypeSteps = <double>[
  32,
  40,
  48,
  56,
  64,
  76,
  88,
  104,
  120,
  140,
  160,
];

/// Where a freshly-opened projection starts on [kProjectionTypeSteps].
///
/// 64 px, the middle of the ladder, so the first adjustment the operator
/// makes has room to go either way. Starting at the bottom would make
/// "bigger" the only useful key and cost a press or four every time.
const int kProjectionTypeDefaultStep = 4;

/// How long the on-screen controls linger after the pointer stops.
///
/// The brief asks for the chrome to be gone, and the operator still
/// needs buttons on a tablet where there is no keyboard at all. Both are
/// satisfied by controls that answer the pointer and then get out of the
/// way. Four seconds is long enough to move from one button to the next
/// and short enough that a bar left on the wall is measured in seconds.
const Duration kProjectionControlsLinger = Duration(seconds: 4);

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
  const ProjectionCursor(this.chapter, this.verse);

  final int chapter;
  final int verse;

  @override
  bool operator ==(Object other) =>
      other is ProjectionCursor &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(chapter, verse);

  @override
  String toString() => 'ProjectionCursor($chapter, $verse)';
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

/// The step index [current] moves to for [delta], clamped to the ladder.
int projectionTypeStep(int current, int delta) =>
    (current + delta).clamp(0, kProjectionTypeSteps.length - 1);

class ProjectionPage extends StatefulWidget {
  const ProjectionPage({super.key});

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

  int _typeStep = kProjectionTypeDefaultStep;
  bool _blank = false;
  bool _second = false;
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  /// The second edition's code once it has been resolved, and its text
  /// indexed as `'<English book>|<chapter>'` → verse number → text.
  ///
  /// Indexed at load rather than scanned at paint: the raw list is
  /// ~31,000 verses and the alternative is a linear scan of a whole
  /// Bible on every frame the wall draws.
  String? _secondCode;
  Map<String, Map<int, String>>? _secondIndex;
  bool _secondLoading = false;

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
      ProjectionCommand.nextVerse => projectionVerseStep(from, 1,
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
  void _run(ProjectionCommand command, MainProvider mp) {
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
        setState(() => _typeStep = projectionTypeStep(_typeStep, 1));
      case ProjectionCommand.smallerType:
        setState(() => _typeStep = projectionTypeStep(_typeStep, -1));
      case ProjectionCommand.toggleSecondVersion:
        _toggleSecondVersion(mp);
      case ProjectionCommand.leave:
        Navigator.of(context).maybePop();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, MainProvider mp) {
    // Key-up would fire a second time for every press, and a held key
    // legitimately repeats — an operator scrolling back through a psalm
    // holds the left arrow.
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final command = projectionCommandFor(event.logicalKey);
    // Ignored, not handled: a key this page has no use for stays the
    // browser's and the framework's. Consuming everything would be the
    // easy way to stop the passage scrolling under a space bar, and it
    // would also swallow the operator's Cmd+R.
    if (command == null) return KeyEventResult.ignored;
    _run(command, mp);
    return KeyEventResult.handled;
  }

  // ── the second edition ────────────────────────────────────────────

  /// Which edition the second block shows: the same one Split View's
  /// second column shows, resolved by the same function
  /// (`resolveSecondaryVersion`) against the same stored key.
  ///
  /// The app already answers "what is the other edition beside the one I
  /// am reading" in one place, and a projection that answered it
  /// differently would put an edition on the wall that the operator's
  /// own screen does not have open.
  Future<void> _loadSecond(MainProvider mp) async {
    setState(() => _secondLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final code = resolveSecondaryVersion(
      primaryVersion: mp.currentVersion,
      stored: prefs.getString(kSecondaryVersionKey),
    );
    await mp.preloadVersion(code);
    final verses = mp.peekCachedVersion(code);
    if (!mounted) return;
    setState(() {
      _secondLoading = false;
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

  void _toggleSecondVersion(MainProvider mp) {
    final on = !_second;
    setState(() => _second = on);
    if (on && _secondIndex == null && !_secondLoading) _loadSecond(mp);
  }

  // ── the controls, and their way out of the way ─────────────────────

  void _wakeControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _restartControlsTimer();
  }

  void _restartControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(kProjectionControlsLinger, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MainProvider>();
    final locale = context.watch<AppSettings>().locale;
    final cursor = _cursor ?? _readerCursor(mp);
    final verses =
        cursor == null ? const <Verse>[] : _versesAt(mp, cursor.chapter);
    final verse = cursor != null && cursor.verse < verses.length
        ? verses[cursor.verse]
        : null;

    return Scaffold(
      backgroundColor: WbColors.dark.groundBg,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (node, event) => _onKey(node, event, mp),
        child: MouseRegion(
          onHover: (_) => _wakeControls(),
          child: Listener(
            onPointerDown: (_) => _wakeControls(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ProjectionStage(
                    verse: verse,
                    reference: _referenceFor(verse),
                    versionCode: mp.currentVersion,
                    typeSize: kProjectionTypeSteps[_typeStep],
                    blank: _blank,
                    locale: locale,
                    secondOn: _second,
                    secondText: _secondTextFor(verse),
                    secondCode: _secondCode,
                    secondLoading: _secondLoading,
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
                      child: _controls(context, locale, mp),
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
  String? _secondTextFor(Verse? verse) {
    if (!_second || verse == null) return null;
    final index = _secondIndex;
    if (index == null) return null;
    final book = bookNameToEnglish[verse.book] ?? verse.book;
    return index['$book|${verse.chapter}']?[verse.verse];
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
  String _referenceFor(Verse? verse) =>
      verse == null ? '' : '${verse.book} ${verse.chapter}:${verse.verseLabel}';

  /// The operator's buttons, for the configurations where the keyboard
  /// is not the answer — a mirrored laptop display, or a tablet, where
  /// there is no key to press.
  ///
  /// Sized off [WbType], which is to say the reader's own Menu Size,
  /// while the stage above is sized off the ROOM. That split is the
  /// whole type story of this page in one line: chrome belongs to the
  /// person operating it and scales with their settings; scripture on a
  /// wall belongs to the back row and does not.
  Widget _controls(BuildContext context, String locale, MainProvider mp) {
    final wb = WbColors.dark;
    final t = WbType.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: t.scaledChrome(12)),
        // Ten buttons is wider than a phone, and a projection driven
        // from a phone is a real if unusual configuration — the
        // alternative to shrinking here is a RenderFlex overflow, which
        // is a yellow-and-black stripe on a church wall. `scaleDown`
        // only ever shrinks, so on the laptop this is meant for the bar
        // is drawn at exactly the size below.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            decoration: BoxDecoration(
              color: wb.paneBg,
              border: Border.all(color: wb.border, width: WbMetrics.hairline),
              borderRadius: BorderRadius.circular(WbMetrics.radiusSurface),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _button(t, Icons.first_page, 'projectionPreviousChapter',
                  'Previous chapter', locale, ProjectionCommand.previousChapter,
                  mp),
              _button(t, Icons.chevron_left, 'projectionPreviousVerse',
                  'Previous verse', locale, ProjectionCommand.previousVerse, mp),
              _button(t, Icons.chevron_right, 'projectionNextVerse',
                  'Next verse', locale, ProjectionCommand.nextVerse, mp),
              _button(t, Icons.last_page, 'projectionNextChapter',
                  'Next chapter', locale, ProjectionCommand.nextChapter, mp),
              _divider(wb, t),
              _button(
                  t,
                  _blank ? Icons.visibility : Icons.visibility_off,
                  _blank ? 'projectionUnblank' : 'projectionBlank',
                  _blank ? 'Show the passage' : 'Black out',
                  locale,
                  ProjectionCommand.blank,
                  mp),
              _divider(wb, t),
              _button(t, Icons.text_decrease, 'projectionTypeSmaller',
                  'Smaller type', locale, ProjectionCommand.smallerType, mp),
              _button(t, Icons.text_increase, 'projectionTypeBigger',
                  'Larger type', locale, ProjectionCommand.biggerType, mp),
              _divider(wb, t),
              _button(
                  t,
                  _second ? Icons.layers_clear : Icons.layers,
                  _second
                      ? 'projectionSecondVersionHide'
                      : 'projectionSecondVersionShow',
                  _second ? 'One edition only' : 'Add a second edition',
                  locale,
                  ProjectionCommand.toggleSecondVersion,
                  mp),
              _divider(wb, t),
              _button(t, Icons.close, 'projectionLeave', 'Leave projection',
                  locale, ProjectionCommand.leave, mp),
              ],
            ),
          ),
        ),
        SizedBox(height: t.scaledChrome(6)),
        // Both lines are for the operator and both fade with the bar.
        // The keys line is how a mirrored setup learns the bindings; the
        // one-window line is the answer to the question the operator is
        // about to ask, said before they ask it rather than in a
        // release note nobody reads.
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

  Widget _button(WbType t, IconData icon, String labelKey, String fallback,
      String locale, ProjectionCommand command, MainProvider mp) {
    final label = _s(labelKey, fallback, locale);
    return IconButton(
      icon: Icon(icon, color: WbColors.dark.text),
      iconSize: t.scaledChrome(20),
      tooltip: label,
      onPressed: () => _run(command, mp),
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
