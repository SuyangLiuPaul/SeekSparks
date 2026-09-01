import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show bibleVersions, shortBibleVersionLabel;
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/wb_centre_mode.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/settings_page.dart'
    show SettingsPage, SettingsSection;
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/services/ai_bible_search_service.dart'
    show AiBibleRef;
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/fetch_verses.dart';
import 'package:seeksparks/services/recent_searches_service.dart';
import 'package:seeksparks/utils/ai_markdown.dart' show parseAiMarkdown;
import 'package:seeksparks/utils/app_nav.dart' show pushPage;
import 'package:seeksparks/utils/atomic_text_edit.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:seeksparks/utils/copy_marking.dart'
    show markHits, markVerseHits;
import 'package:seeksparks/services/tagged_text_service.dart';
import 'package:seeksparks/utils/search_highlight.dart';
import 'package:seeksparks/utils/command_draft.dart';
import 'package:seeksparks/utils/command_examples.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/compound_query.dart';
import 'package:seeksparks/utils/command_verb.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/reference_parser.dart' show parseReference;
import 'package:seeksparks/utils/relative_time.dart' show relativeTime;
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localeAwareBookName, toEnglish;
import 'package:seeksparks/constants/book_groups.dart'
    show oldTestamentBooks, canonicalOtBooks, canonicalNtBooks;
import 'package:seeksparks/utils/search_scope.dart' show scopeDisplayName;
import 'package:seeksparks/utils/search_stats.dart';
import 'package:seeksparks/utils/strongs_absence.dart';
import 'package:seeksparks/utils/strongs_result_counts.dart';
import 'package:seeksparks/utils/version_abbreviation.dart';
import 'package:seeksparks/widgets/search_stats_strip.dart';

/// The Workbench's left pane: a BibleWorks-style command line (text, a
/// bare Strong's number, or a structured `G25 AND G26` / `NEAR5` query)
/// with its results verse list below.
///
/// All computation lives in [WorkbenchProvider] / `SearchService`; this
/// widget is presentation + wiring only. Tapping a result scrolls the
/// center reader to the verse (the reader's pendingJump handshake — no
/// navigation, the reader is right beside us) and focuses it in the
/// analysis pane.
class CommandPane extends StatefulWidget {
  const CommandPane({
    super.key,
    this.focusNode,
    this.onVerseOpened,
    this.onEditScope,
    this.onOpenWordList,
  });

  /// Supplied by the Workbench so View ▸ Command line and the toolbar's
  /// search button can put the caret here — a desktop tool's command
  /// line is always one keystroke away.
  final FocusNode? focusNode;

  /// Called after a result has been opened. The Workbench leaves this
  /// null: the reader is the pane next door and the jump is already
  /// visible. `CommandSearchPage` passes a pop, because there the
  /// reader is the route underneath and a tap that changed nothing on
  /// screen reads as a dead list.
  final VoidCallback? onVerseOpened;

  /// Opens the scope picker. Owned by the Workbench because the same
  /// sheet is reached from the Search menu and the status bar, and
  /// three copies of "open the limits window" is how two of them end up
  /// behaving differently. Null leaves the limit banner a readout with
  /// a clear button, which is what it was.
  final VoidCallback? onEditScope;

  /// Opens the Word List for the passage in view.
  ///
  /// The `?` card documents `G25 AND G26` and the strip has four buttons
  /// that only work on numbers, but nothing anywhere said where a reader
  /// gets a G25 in the first place. The Word List is the answer and it
  /// already exists under Tools; this hands it to the two places that
  /// raise the question. Null (the standalone `CommandSearchPage`) drops
  /// the link rather than showing one that goes nowhere.
  final VoidCallback? onOpenWordList;

  @override
  State<CommandPane> createState() => _CommandPaneState();
}

class _CommandPaneState extends State<CommandPane> {
  final TextEditingController _controller = TextEditingController();

  /// Everything submitted this session, oldest first. BibleWorks keeps a
  /// command history on ↑/↓ (bwh44) and it matters more here than it
  /// looks: the grammar rewards small edits to a query you already
  /// typed — widen the context, drop a term, add a wildcard — and
  /// retyping `.paul silas;10` to change the 10 is the friction that
  /// stops people exploring.
  final List<String> _history = [];

  /// Position in [_history] while cycling; `_history.length` means "back
  /// at the line you were typing".
  int _historyAt = 0;

  /// Whether the syntax card is open. A grammar whose operators are
  /// punctuation is undiscoverable — the single most common complaint
  /// about the BibleWorks command line is that nobody knew it was
  /// there — so the reference is one keystroke away rather than in a
  /// manual.
  bool _showSyntax = false;

  /// Used when the Workbench did not supply one (the pane is embeddable
  /// on its own). The chips and the shortcuts both need a node they can
  /// put the caret back into, and reaching into the TextField's private
  /// one is not an option.
  final FocusNode _ownFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _ownFocus;

  /// Persisted successful queries, newest first, shown in place of the
  /// empty state.
  ///
  /// Deliberately NOT the same thing as [_history]. bwh09 keeps two
  /// lists and the difference is the point: "Entries are not added to
  /// this list until they are executed without any error messages",
  /// while "the UP and DOWN arrows cycle through previous Command Line
  /// entries regardless of whether or not they were successful". So ↑
  /// is for fixing the typo you just made, and this list is for
  /// re-asking a question that worked — a week ago, on another device.
  List<RecentSearchEntry> _recents = const [];

  /// The word distance the NEAR button inserts, and the number it shows.
  ///
  /// The parser has always taken any `NEAR<n>`; only the button was
  /// pinned to 5, so the one adjustable thing on the strip looked fixed.
  /// Session state, not a setting: it belongs to the query being built.
  int _nearDistance = 5;

  /// The line the last button wrote, held until the platform stops
  /// arguing about where the caret is. See [_undoSelectAllEcho].
  String? _caretGuardText;
  int _caretGuardOffset = 0;

  /// What the operator button the reader last TAPPED does, shown in the
  /// hint row until they type again.
  ///
  /// Task #294 gave every button a `Tooltip`, and a tooltip is a hover
  /// affordance. This app is tablet-first and the reports come from a
  /// tablet: there is no hover, so on the device where the strip is most
  /// confusing the explanations were unreachable. Long-press does open
  /// them, but nothing on screen suggests long-pressing a button you
  /// have already learned to tap.
  ///
  /// So the tap itself answers the question. The button still inserts —
  /// that behaviour is pinned by a test and was never broken — and the
  /// row underneath says what it just inserted, which is the reading a
  /// hovering mouse would have got for free.
  String? _tappedOpTip;

  /// The line as it stood when [_tappedOpTip] was set. The explanation is
  /// about the token that was just inserted, so it expires the moment the
  /// line stops being that.
  String? _tipLineText;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_undoSelectAllEcho);
    _controller.addListener(_clearOpTipOnEdit);
    _loadRecents();
  }

  void _clearOpTipOnEdit() {
    if (_tappedOpTip == null) return;
    if (_controller.text == _tipLineText) return;
    setState(() {
      _tappedOpTip = null;
      _tipLineText = null;
    });
  }

  /// Run an operator button's insertion, then say what it did.
  ///
  /// Order matters: the insertion changes the line, which is exactly the
  /// signal [_clearOpTipOnEdit] watches for.
  void _tapOperator(String tip, VoidCallback insert) {
    insert();
    setState(() {
      _tappedOpTip = tip;
      _tipLineText = _controller.text;
    });
  }

  /// Put [text] on the command line as if the reader had typed it.
  ///
  /// Every button on the strip goes through here, because the caret is
  /// the whole difficulty. Tapping a chip blurs the browser's hidden
  /// `<input>`; putting the focus back makes the browser SELECT ALL of
  /// it, and that select-all is echoed into the framework as the new
  /// editing state. The reader then types the second half of the query
  /// the button just helped them start and it replaces the first half:
  /// `G25` → tap `NEAR5` → type `G26` → the line reads `G26`. Pressing
  /// Enter on that gets a lexicon entry, not a proximity search, which
  /// is precisely "I clicked on it and nothing happens".
  void _writeLine(String text, {int? caret}) {
    final offset = (caret ?? text.length).clamp(0, text.length);
    _controller.setTextAtomic(text, caret: offset);
    _caretGuardText = text;
    _caretGuardOffset = offset;
    _focus.requestFocus();
    setState(() {});
  }

  /// Undo exactly the echo described in [_writeLine] and nothing else:
  /// the same text we just wrote, wholly selected, once. A selection the
  /// reader made themselves does not match, because by then either the
  /// text has changed or the guard is spent.
  void _undoSelectAllEcho() {
    final written = _caretGuardText;
    if (written == null) return;
    if (_controller.text != written) {
      _caretGuardText = null;
      return;
    }
    final sel = _controller.selection;
    if (written.isEmpty ||
        sel.baseOffset != 0 ||
        sel.extentOffset != written.length) {
      return;
    }
    _caretGuardText = null;
    _controller.selection = TextSelection.collapsed(offset: _caretGuardOffset);
  }

  Future<void> _loadRecents() async {
    final entries = await RecentSearchesService.listWithTimestamps();
    if (!mounted) return;
    setState(() => _recents = entries);
  }

  /// Record a command line that ran cleanly. See [_recents] for why
  /// this is gated on success and ↑/↓ is not.
  Future<void> _commitRecent(String raw) async {
    await RecentSearchesService.add(raw);
    await _loadRecents();
  }

  @override
  void dispose() {
    _controller.dispose();
    _ownFocus.dispose();
    super.dispose();
  }

  /// BibleWorks' defining interaction: ONE box that does two jobs.
  /// Type a reference and it navigates; type anything else and it
  /// searches. In BibleWorks the command line is the primary control —
  /// you rarely touch the mouse — and until now this box could only
  /// search, so `Gen 1:1` ran a *text search* for those words instead
  /// of going there.
  ///
  /// A bare book name ("John") deliberately still searches: it is far
  /// more likely to be a word the reader wants found than a request to
  /// jump to John 1, and the ambiguity is not worth the surprise. A
  /// chapter number makes the intent explicit ("John 3", "约翰福音 3").
  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    if (_history.isEmpty || _history.last != raw) _history.add(raw);
    _historyAt = _history.length;

    // Verbs first (bwh44). They are the narrowest thing on the line —
    // a single letter followed by whitespace, or a bare number — so
    // testing them first costs nothing, and testing them LAST would
    // cost everything: `d nas` is a perfectly good text search that
    // finds nothing, which reads exactly like an unimplemented feature.
    final parse = parseCommandVerb(raw, _verbContext());
    if (parse.isVerb) {
      await _runVerb(parse);
      return;
    }

    // A bare version abbreviation switches the reading version, before
    // anything else is tried. From the manual: "The easiest way to do
    // this is to type the BibleWorks abbreviation for the version on
    // the Command Line … and pressing the Return key." Checked first
    // because these tokens are short and would otherwise be swallowed
    // by the text search.
    final versionCode = _matchVersion(raw);
    if (versionCode != null) {
      final mp = context.read<MainProvider>();
      if (versionCode != mp.currentVersion) {
        mp.setVersion(versionCode);
        await FetchVerses.execute(mainProvider: mp);
      }
      if (!mounted) return;
      _controller.clear();
      setState(() {});
      return;
    }

    final ref = parseReference(raw);
    if (ref != null) {
      final mp = context.read<MainProvider>();
      final res = await jumper.resolveAndPrepareJump(reference: ref, mp: mp);
      if (!mounted) return;
      if (res.ready) {
        // The workbench centre pane is a BibleReadingPane on this same
        // provider, so preparing the jump is enough — no navigation.
        final wb = context.read<WorkbenchProvider>();
        wb.clearResults();
        // Focus the verse we landed on. Without this the reader scrolls
        // but any PREVIOUS selection still owns the Browse and Word
        // Study panes, so they keep showing the verse you navigated
        // away from.
        final landed = mp.currentVerse;
        if (landed != null) wb.focusVerse(landed);
        _controller.clear();
        setState(() {});
        return;
      }
      // Reference parsed but the verse is not in any available canon
      // (e.g. an OT reference while on an NT-only version with no
      // fallback). Fall through to search rather than failing silently.
    }
    if (!mounted) return;
    final wb = context.read<WorkbenchProvider>();
    final running = wb.runSearch(raw,
        locale: context.read<AppSettings>().locale);
    // Keep the caret here. `TextInputAction.search` unfocuses the field
    // by default, which is right for a one-shot search box and wrong for
    // a command line: after a search you refine it — widen the context,
    // drop a term — and both ↑ and Esc are dead the moment focus leaves.
    // Navigation does NOT do this; there your attention moves to the text.
    _focus.requestFocus();
    await running;
    if (!mounted) return;
    // A query the grammar refused never reaches the history. Zero hits
    // does: "no verse says that" is an answer, and it is one you come
    // back to widen.
    //
    // `wb.commandIssue` is not enough on its own. A line like
    // `yahweh NEAR5 god` raises no issue at all — it is not a command
    // and not a Strong's expression, so it falls through to a literal
    // text scan for "yahwehnear5god", finds nothing, and gets filed as a
    // search that worked. It then sits in Recents inviting the reader to
    // run it again forever.
    final refused =
        analyseCommandDraft(raw, nearDistance: _nearDistance).willNotRunAsWritten;
    if (wb.commandIssue == null && !refused) await _commitRecent(raw);
  }

  /// Everything the verb grammar needs to know about where the reader
  /// currently is. Rebuilt per submission rather than cached: the
  /// version, the chapter and the Browse stack all change underneath
  /// this pane from the reader's other hand.
  VerbContext _verbContext() {
    final mp = context.read<MainProvider>();
    final wb = context.read<WorkbenchProvider>();
    final book = mp.currentBook;
    return VerbContext(
      versions: [
        for (final v in bibleVersions)
          VerbVersion(code: v.value, label: v.shortLabel, language: v.language),
      ],
      searchVersion: mp.currentVersion,
      displayVersions: wb.displayVersions,
      currentEnglishBook: book == null ? null : (toEnglish(book) ?? book),
      currentChapter: mp.currentChapter,
    );
  }

  /// Carry out a parsed verb, then say what happened.
  ///
  /// Every branch ends in either a notice or a visible move, because a
  /// verb's whole effect lands somewhere other than the pane you typed
  /// it in — the Browse stack, the limit banner, the centre reader —
  /// and below the three-pane breakpoint some of those are not even on
  /// screen.
  Future<void> _runVerb(CommandVerbParse parse) async {
    final settings = context.read<AppSettings>();
    final locale = settings.locale;
    final wb = context.read<WorkbenchProvider>();

    if (parse.issue != null) {
      wb.showVerbNotice(describeVerbIssue(
        parse.issue!,
        parse.detail,
        locale,
        available: parse.issue == CommandVerbIssue.unknownVersion
            ? [for (final v in bibleVersions) v.shortLabel]
            : const [],
      ));
      _controller.clear();
      setState(() {});
      _focus.requestFocus();
      return;
    }

    final verb = parse.verb!;
    switch (verb.kind) {
      case CommandVerbKind.displayAdd:
      case CommandVerbKind.displayRemove:
      case CommandVerbKind.displayClear:
      case CommandVerbKind.displaySet:
        final mp = context.read<MainProvider>();
        final stack =
            applyDisplayVerb(verb, wb.displayVersions, mp.currentVersion);
        // The search version is implicit in the stack everywhere else in
        // the app, so it is not part of the parallel list.
        wb.setParallelVersions(
            stack.where((c) => c != mp.currentVersion).toList());
        wb.setCentreMode(WbCentreMode.browse);
        wb.showVerbNotice(describeDisplayStack(
            [for (final c in stack) shortBibleVersionLabel(c)], locale));
      case CommandVerbKind.askAi:
        // Clear before awaiting, not after: the request takes seconds
        // and every other verb empties the line the instant it runs.
        // Leaving the question sitting there under a spinner reads as
        // a field that stopped accepting input.
        final raw = _controller.text.trim();
        _controller.clear();
        setState(() {});
        _focus.requestFocus();
        await wb.runAiSearch(
          question: verb.aiQuery!,
          locale: locale,
          userApiKey:
              settings.geminiApiKey.isEmpty ? null : settings.geminiApiKey,
          aiModel: settings.aiModel,
        );
        if (!mounted) return;
        // The whole line, `ai ` and all, so tapping the recent re-asks
        // the model rather than text-searching the question.
        if (wb.aiRefs?.isNotEmpty ?? false) await _commitRecent(raw);
        return;
      case CommandVerbKind.browseOn:
        wb.setCentreMode(WbCentreMode.browse);
        wb.showVerbNotice(
            uiStrings['cmdvBrowseOn']?[locale] ?? 'Browse view.');
      case CommandVerbKind.limitSet:
        final spec = verb.limit!;
        final label = scopeDisplayName(
          spec: spec,
          locale: locale,
          version: context.read<MainProvider>().currentVersion,
          maxNames: 3,
        );
        final applied = await wb.setSearchLimitFromSpec(spec, label);
        if (!mounted) return;
        wb.showVerbNotice(applied
            ? null
            : describeVerbIssue(
                CommandVerbIssue.emptyScope, label, locale));
      case CommandVerbKind.limitClear:
        await wb.setSearchLimit(null, null);
        if (!mounted) return;
        wb.showVerbNotice(null);
      case CommandVerbKind.goToReference:
        final mp = context.read<MainProvider>();
        final res = await jumper.resolveAndPrepareJump(
            reference: verb.reference!, mp: mp);
        if (!mounted) return;
        if (res.ready) {
          wb.clearResults();
          final landed = mp.currentVerse;
          if (landed != null) wb.focusVerse(landed);
        } else {
          wb.showVerbNotice(res.errorMessage);
        }
    }
    if (!mounted) return;
    _controller.clear();
    setState(() {});
    _focus.requestFocus();
  }

  /// `nas`, `NASB`, `kjv`… → that version's code. Exact code or short
  /// label first, then an unambiguous 3-character-or-longer prefix; null
  /// for anything else, so the token falls through to reference-parsing
  /// and then to search.
  String? _matchVersion(String raw) => matchVersionAbbreviation(
        raw,
        {for (final v in bibleVersions) v.value: v.shortLabel},
      );

  /// Insert an operator/wildcard token at the caret (used by the
  /// operator chips under the command line).
  ///
  /// [trailingSpace] is false for `!`, which negates the word it is
  /// glued to. `!barnabas` excludes Barnabas; `! barnabas` is a stray
  /// `!` and a term, and the parser would silently drop the `!` and
  /// return the opposite of what was asked for.
  void _insertToken(String token, {bool trailingSpace = true}) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final needsSpace = start > 0 && !text.substring(0, start).endsWith(' ');
    final insert = '${needsSpace ? ' ' : ''}$token${trailingSpace ? ' ' : ''}';
    _writeLine(text.replaceRange(start, end, insert),
        caret: start + insert.length);
  }

  /// `✶` glues to the word in front of the caret when there is one, and
  /// stands alone when there is not.
  ///
  /// One rule, three documented meanings, all of them right:
  ///   `G25`   + ✶ → `G25*`     prefix wildcard over Strong's numbers
  ///   `.faith`+ ✶ → `.faith*`  character wildcard
  ///   `'信心 ` + ✶ → `'信心 * ` a word gap inside a phrase
  ///
  /// Before this the button always produced the third form, so the very
  /// query the help documents — `G25✶` — was the one it could not make.
  /// `G25 * ` does not parse as a Strong's expression at all; it fell
  /// through to a text search for the literal string and found nothing.
  void _insertWildcard() {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final glued = start > 0 && !text.substring(0, start).endsWith(' ');
    if (!glued) {
      _insertToken('*');
      return;
    }
    _writeLine(text.replaceRange(start, end, '*'), caret: start + 1);
  }

  /// Insert the NEAR operator at the strip's current distance.
  void _insertNear() => _insertToken('NEAR$_nearDistance');

  /// Widen or narrow the word distance, rewriting the token already on
  /// the line so the number in the query and the number on the button
  /// never disagree.
  ///
  /// A delta read off the LIVE line, not an absolute read off the last
  /// build: two quick taps on `−` must step twice, and a handler that
  /// closes over the distance it was built with steps once.
  void _stepNearDistance(int delta) {
    final text = _controller.text;
    final near = analyseCommandDraft(text).near;
    final next = ((near?.distance ?? _nearDistance) + delta)
        .clamp(kMinNearDistance, kMaxNearDistance);
    _nearDistance = next;
    if (near != null) {
      _writeLine(withNearDistance(text, near, next));
    } else {
      setState(() {});
      _focus.requestFocus();
    }
  }

  /// Replace the leading control character, or add one.
  ///
  /// Not [_insertToken]: a control character is a property of the whole
  /// line and only means anything in first position, so tapping `/`
  /// after `.` must SWITCH the search from all-of to any-of rather than
  /// bury a stray slash mid-query. That also makes the chips a way to
  /// re-ask the same question a different way, which is the thing a
  /// reader actually wants after seeing the answer.
  void _setControl(String control) {
    var text = _controller.text.trimLeft();
    if (text.isNotEmpty && kCommandControls.contains(text[0])) {
      text = text.substring(1);
    }
    _writeLine('$control$text');
  }

  /// Step through [_history]; -1 is older, +1 is newer.
  void _recall(int step) {
    if (_history.isEmpty) return;
    final next = (_historyAt + step).clamp(0, _history.length);
    if (next == _historyAt) return;
    _historyAt = next;
    // Stepping past the newest entry returns the empty line rather than
    // sticking on the last command, so ↓ is a way out and not a trap.
    _writeLine(next == _history.length ? '' : _history[next]);
  }

  void _clear() {
    _controller.clear();
    _historyAt = _history.length;
    context.read<WorkbenchProvider>().clearResults();
    setState(() {}); // hide the clear button
  }

  String _cleanPreview(String raw) => versePreviewText(raw) ?? '';

  String _summary(String queryLabel, int count, String locale) =>
      (uiStrings['booleanSearchHeader']?[locale] ?? '{query} — {count} verses')
          .replaceAll('{query}', queryLabel)
          .replaceAll('{count}', count.toString());

  /// The Strong's header. Reports verses AND occurrences when both are
  /// known, and says outright when the bundled verse list stopped at the
  /// pipeline cap — see `strongs_result_counts.dart` for why silence
  /// there was a lie (H3068 read "500 verses" against 6,521 hits).
  String _strongsSummary(
      String queryLabel, StrongsResultCounts counts, String locale) {
    // Incompleteness is checked before the counts, because the one thing
    // that still causes it — a cut wildcard expansion — arrives on the
    // boolean path, which never has an occurrence total to print.
    if (counts.truncated) {
      return (uiStrings['strongsHeaderPartial']?[locale] ??
              '{query} — at least {count} verses; the wildcard matched '
                  'more numbers than were searched')
          .replaceAll('{query}', queryLabel)
          .replaceAll('{count}', groupThousands(counts.verses));
    }
    final hits = counts.occurrences;
    if (hits == null) return _summary(queryLabel, counts.verses, locale);
    return (uiStrings['strongsHeaderWithHits']?[locale] ??
            '{query} — {count} verses · {hits} occurrences')
        .replaceAll('{query}', queryLabel)
        .replaceAll('{count}', groupThousands(counts.verses))
        .replaceAll('{hits}', groupThousands(hits));
  }

  /// Tap a result: scroll the center reader to the verse (pendingJump
  /// handshake, drained by the reader's next frame) and focus it in
  /// the analysis pane.
  /// `version/book` pairs whose tagging has been asked for already —
  /// see [_warmTaggingForRow].
  final Set<String> _tagRequested = {};
  final Set<String> _tagPending = {};
  bool _tagFlushScheduled = false;

  void _openVerse(Verse verse) {
    final wb = context.read<WorkbenchProvider>();
    jumper.prepareJumpToVerse(verse, wb.mainProvider);
    wb.focusVerse(verse);
    widget.onVerseOpened?.call();
  }

  Future<void> _copyAllStrongsRefs(
      WorkbenchProvider wb, AppSettings settings, List<ConcordanceRef> refs) async {
    final mp = wb.mainProvider;
    final hl = highlightsForQuery(wb.lastQuery);
    // A Strong's number cannot be located in a verse without that
    // book's tagging, so a copy of the whole result set loads the whole
    // result set's books — the reader asked for every match, and half a
    // document marked is worse than either alternative.
    //
    // This awaits before writing to the clipboard, which on web can
    // cost the user-activation window the rich `text/html` flavour
    // rides on. That is an acceptable trade only because the plain
    // flavour now carries the mark too: the worst case is 【神】 in
    // brackets instead of a yellow wash, not an unmarked document.
    if (TaggedTextService.supports(mp.currentVersion)) {
      final books = <String>{for (final r in refs) r.englishBook};
      await Future.wait(books
          .map((b) => TaggedTextService.prefetchBook(mp.currentVersion, b)));
      if (!mounted) return;
    }
    final lines = <String>[wb.strongsQueryLabel ?? '', ''];
    for (final r in refs) {
      final displayBook =
          localeAwareBookName(r.englishBook, settings.locale, mp.currentVersion);
      final clean =
          _cleanPreview(wb.verseByRef['${r.englishBook}-${r.chapter}-${r.verse}']
                  ?.text ??
              '');
      // Every book in the copy is loaded first (above), so a copy of
      // 22 books is marked in all 22 — not in the handful the reader
      // happened to scroll past.
      final runs = TaggedTextService.cachedForVerse(
        version: mp.currentVersion,
        englishBook: r.englishBook,
        chapter: r.chapter,
        verse: r.verse,
      );
      final marked = markVerseHits(
        clean,
        highlight: hl,
        runs: runs?.map((x) => (text: x.text, strongs: x.strongs)).toList(),
      );
      lines.add('$displayBook ${r.chapter}:${r.verse}  $marked'.trim());
    }
    await ClipboardHelper.copyMarkedWithFeedback(
      context,
      lines.join('\n'),
      messageOverride: (uiStrings['copyAllResultsToast']?[settings.locale] ??
              'Copied {n} matches')
          .replaceAll('{n}', refs.length.toString()),
    );
  }

  Future<void> _copyAllTextResults(
      AppSettings settings, List<Verse> results) async {
    final wb = context.read<WorkbenchProvider>();
    final mp = wb.mainProvider;
    final hl = highlightsForQuery(wb.lastQuery);
    final lines = <String>[wb.lastQuery, ''];
    for (final v in results) {
      final displayBook =
          localeAwareBookName(v.book, settings.locale, mp.currentVersion);
      // A text query carries its own terms, so unlike the Strong's list
      // above this marks every line regardless of edition — there is no
      // tagging to be missing.
      final marked = markHits(sanitizeForSearch(v.scriptureText),
          splitOnTerms(sanitizeForSearch(v.scriptureText), hl.textTerms));
      lines.add('$displayBook ${v.chapter}:${v.verseLabel}  $marked'.trim());
    }
    await ClipboardHelper.copyMarkedWithFeedback(
      context,
      lines.join('\n'),
      messageOverride: (uiStrings['copyAllResultsToast']?[settings.locale] ??
              'Copied {n} matches')
          .replaceAll('{n}', results.length.toString()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final wb = context.watch<WorkbenchProvider>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;

    final wbc = WbColors.of(context);
    final t = WbType.of(context);
    return Column(
      children: [
        // ── Command line ──────────────────────────────────────────
        // BibleWorks puts this at the very top of the Search window as
        // a single hairline box, not a padded pill.
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 3),
          // Esc and ↑/↓ belong to the command line, not to the text
          // field: a single-line field does nothing with them, and
          // BibleWorks readers reach for them without looking. Bound
          // here rather than at the app level so they are closer to the
          // focused field than Flutter's own editing shortcuts and
          // therefore win the lookup.
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape): _clear,
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _recall(-1),
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _recall(1),
            },
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() {}), // toggle clear button
              style: TextStyle(
                  fontSize: t.text, height: t.lineHeight),
              decoration: InputDecoration(
                hintText: uiStrings['commandSearchHint']?[locale] ??
                    "Search text, or Strong's: G25 AND G26",
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 20, minHeight: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty)
                      _MiniIcon(
                        icon: Icons.close,
                        tooltip: uiStrings['clear']?[locale] ?? 'Clear',
                        onTap: _clear,
                      ),
                    _MiniIcon(
                      icon: Icons.search,
                      tooltip: uiStrings['search']?[locale] ?? 'Search',
                      onTap: _submit,
                      color: wbc.link,
                    ),
                    const SizedBox(width: 3),
                  ],
                ),
              ),
            ),
          ),
        ),
        // ── Operator buttons ──────────────────────────────────────
        // Wrap, not Row: the Search window can be dragged down to 240px
        // and a fixed row of five buttons overflowed it.
        //
        // The control characters come first because they are the ones
        // nobody can guess. BibleWorks shipped "Code Insertion Buttons"
        // for exactly this reason and they are the only part of its
        // command line that reviewers describe as discoverable.
        _operatorStrip(locale),
        if (_showSyntax) _syntaxCard(locale),
        const Divider(height: 1),
        // ── Results ───────────────────────────────────────────────
        Expanded(child: _buildResults(context, wb, settings, scheme, locale)),
      ],
    );
  }

  /// The operator strip, and under it one line of plain language about
  /// what the line still needs.
  ///
  /// The strip carries two grammars — `. / ' ! ✶` build a TEXT search,
  /// `AND OR NOT NEARn` combine STRONG'S NUMBERS — and nothing said so.
  /// The combining four are therefore dimmed until the line actually
  /// holds a number, but stay tappable: a button that disappears as you
  /// type cannot be learned from, and tapping a dim one is answered by
  /// the hint row rather than by silence.
  Widget _operatorStrip(String locale) {
    final draft =
        analyseCommandDraft(_controller.text, nearDistance: _nearDistance);
    final dim = !draft.combinersApply;
    String tip(String key, String fallback) =>
        (uiStrings[key]?[locale] ?? fallback)
            .replaceAll('{n}', '$_nearDistance');
    // Each button carries its explanation twice over: as the hover
    // tooltip a mouse gets, and — through [_tapOperator] — as a line in
    // the hint row, which is the only one of the two a touch device can
    // reach. Same string, so they cannot drift apart.
    Widget op(String label, String tipText, VoidCallback insert,
            {bool dimmed = false}) =>
        _OperatorButton(
          label: label,
          tooltip: tipText,
          dimmed: dimmed,
          onTap: () => _tapOperator(tipText, insert),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              op('.', tip('cmdOpTipAll', '. every word, one verse'),
                  () => _setControl('.')),
              op('/', tip('cmdOpTipAny', '/ any of the words'),
                  () => _setControl('/')),
              op("'", tip('cmdOpTipPhrase', "' the words in that order"),
                  () => _setControl("'")),
              op(
                  '!',
                  tip('cmdOpTipNot',
                      '! excludes the word it is glued to (also G25 !G26)'),
                  () => _insertToken('!', trailingSpace: false)),
              op(
                  '*',
                  tip('cmdOpTipStar',
                      '✶ after a word it is a wildcard; alone it is a word gap'),
                  _insertWildcard),
              op('AND', tip('searchOpAndTip', 'Verses with BOTH'),
                  () => _insertToken('AND'),
                  dimmed: dim),
              op('OR', tip('searchOpOrTip', 'Verses with EITHER'),
                  () => _insertToken('OR'),
                  dimmed: dim),
              op(
                  'NOT',
                  tip('searchOpNotTip',
                      'Verses with the first but not the second'),
                  () => _insertToken('NOT'),
                  dimmed: dim),
              op(
                  'NEAR$_nearDistance',
                  tip('searchOpNearTip',
                      'Within {n} words of each other, either order'),
                  _insertNear,
                  dimmed: dim),
              _OperatorButton(
                label: '?',
                tooltip: uiStrings['cmdSyntaxToggle']?[locale] ?? 'Syntax help',
                selected: _showSyntax,
                onTap: () => setState(() => _showSyntax = !_showSyntax),
              ),
            ],
          ),
        ),
        if (draft.showsHint || _tappedOpTip != null) _draftHint(draft, locale),
      ],
    );
  }

  /// What the half-typed line still needs, plus — when it holds a
  /// `NEARn` — the one control that makes the distance adjustable.
  ///
  /// The pane already reads a FINISHED query back in words. This is that
  /// idea moved earlier: "tapped NEAR5, pressed Enter, nothing happened"
  /// is a failure that completes before there is a query to echo.
  Widget _draftHint(CommandDraft draft, String locale) {
    return Builder(builder: (context) {
      final wbc = WbColors.of(context);
      final t = WbType.of(context);
      final near = draft.near;
      final said = describeCommandDraft(draft, locale);
      final fix = draft.suggestion;
      // The reader is being told a number is needed; the Word List is
      // where numbers come from. Offering it only here, where the
      // question has actually been raised, keeps the row from turning
      // into a second toolbar.
      final needsNumber = draft.hint == CommandDraftHint.needsSecondNumber ||
          draft.hint == CommandDraftHint.combinerWithoutNumber ||
          draft.hint == CommandDraftHint.notAStrongsExpression;
      final tip = _tappedOpTip;
      return Container(
        width: double.infinity,
        color: wbc.chromeBg,
        padding: const EdgeInsets.fromLTRB(6, 3, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tip != null)
              Text(
                tip,
                style: TextStyle(
                  fontSize: t.chrome,
                  color: wbc.text,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            if (said != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      said,
                      style: TextStyle(
                        fontSize: t.chrome,
                        color: wbc.mutedText,
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  ),
                  if (near != null) ...[
                    _MiniIcon(
                      icon: Icons.remove,
                      tooltip: uiStrings['cmdDraftNearFewer']?[locale] ??
                          'Narrower window',
                      onTap: () => _stepNearDistance(-1),
                    ),
                    _MiniIcon(
                      icon: Icons.add,
                      tooltip: uiStrings['cmdDraftNearWider']?[locale] ??
                          'Wider window',
                      onTap: () => _stepNearDistance(1),
                    ),
                  ],
                ],
              ),
            // A rewrite the reader can run, rather than a description of
            // one they would have to retype. Prefill, never auto-run:
            // the phrase form of NEAR is ORDERED where NEAR is not, so
            // this is a near-miss offered for inspection, not an answer.
            if (fix != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: _HintAction(
                  label: fix,
                  tooltip:
                      uiStrings['cmdDraftUseInstead']?[locale] ?? 'Use this',
                  onTap: () => _writeLine(fix),
                ),
              ),
            if (needsNumber && widget.onOpenWordList != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: _HintAction(
                  label: uiStrings['cmdDraftFindNumber']?[locale] ??
                      'Find a number',
                  icon: Icons.list_alt,
                  onTap: widget.onOpenWordList!,
                ),
              ),
          ],
        ),
      );
    });
  }

  /// The syntax reference, one line per operator, with a real example
  /// in the reader's own language rather than a metasyntax — and, since
  /// task #299, an example you can RUN.
  ///
  /// Every line on this card was already a working query, printed as
  /// dead text two centimetres above the field it belongs in. The reader
  /// had to read it, remember it and retype it, which on a tablet is the
  /// difference between a reference and a feature. Now the whole row is
  /// the target and tapping it fills the command line.
  ///
  /// It fills but does not RUN. Three reasons, in order of weight: `ai
  /// verses about anxiety` is the only command that leaves the device
  /// and must never be sent because someone was reading the help;
  /// `.love god` is a stand-in for the reader's own words, so a run
  /// would answer a question they did not ask; and prefilling leaves the
  /// caret on a line they can edit, which is how the grammar is learned.
  Widget _syntaxCard(String locale) {
    return Builder(builder: (context) {
      final wbc = WbColors.of(context);
      final t = WbType.of(context);
      // Examples follow the TEXT BEING SEARCHED, prose follows the
      // reader. A Chinese interface over the BSB that offers `.爱 神`
      // teaches that the card is broken: the query is well-formed, it
      // just cannot match an English text.
      final exampleLocale = exampleLocaleFor(
        versionLanguage: _searchVersionLanguage(),
        uiLocale: locale,
      );
      // Grouped, because the strip's own grammar split is the fact the
      // card was missing. Before task #294 it listed only the TEXT rules,
      // so pressing `?` to ask what the NEAR5 button was returned ten
      // lines about `.love god` and no mention of NEAR at all.
      const sections = <(String, List<String>)>[
        (
          'cmdSyntaxSectionText',
          [
            'cmdSyntaxAnd',
            'cmdSyntaxOr',
            'cmdSyntaxPhrase',
            'cmdSyntaxNot',
            'cmdSyntaxWild',
            'cmdSyntaxGap',
            'cmdSyntaxContext',
            'cmdSyntaxCompound',
          ]
        ),
        (
          'cmdSyntaxSectionStrongs',
          [
            'cmdSyntaxStrongsBool',
            'cmdSyntaxStrongsNear',
            'cmdSyntaxStrongsWild',
          ]
        ),
        (
          'cmdSyntaxSectionCommands',
          ['cmdSyntaxVerbs', 'cmdSyntaxAi', 'cmdSyntaxHistory']
        ),
      ];
      return Container(
        width: double.infinity,
        color: wbc.chromeBg,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiStrings['cmdSyntaxTitle']?[locale] ?? 'Command line syntax',
              style: TextStyle(
                fontSize: t.chrome,
                fontWeight: FontWeight.w700,
                color: wbc.text,
              ),
            ),
            for (final (heading, keys) in sections) ...[
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 1),
                child: Text(
                  uiStrings[heading]?[locale] ?? '',
                  style: TextStyle(
                    fontSize: t.chrome,
                    fontWeight: FontWeight.w700,
                    color: wbc.link,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ),
              for (final k in keys) _syntaxRow(k, locale, exampleLocale),
              // The `?` card names Strong's numbers eleven times without
              // ever saying where one comes from, and the strip has four
              // buttons that do nothing without one. The Word List for
              // the chapter in view is the answer.
              if (heading == 'cmdSyntaxSectionStrongs' &&
                  widget.onOpenWordList != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: _HintAction(
                    label: uiStrings['cmdSyntaxFindNumber']?[locale] ??
                        "Where do the numbers come from? "
                            "Open this chapter's Word List →",
                    icon: Icons.list_alt,
                    onTap: widget.onOpenWordList!,
                  ),
                ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                uiStrings['cmdSyntaxTapHint']?[locale] ??
                    'Tap any line to put that example on the command line.',
                style: TextStyle(
                  fontSize: t.chrome,
                  color: wbc.mutedText,
                  fontStyle: FontStyle.italic,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// One line of the syntax card.
  ///
  /// The example is read from [exampleLocale] and the explanation from
  /// [locale] — see [_syntaxCard]. A line with no example (the verb
  /// summary, the ↑/↓ line) is several commands at once, so there is
  /// nothing single to prefill and it stays untappable rather than
  /// picking one of them arbitrarily.
  Widget _syntaxRow(String key, String locale, String exampleLocale) {
    return Builder(builder: (context) {
      final wbc = WbColors.of(context);
      final t = WbType.of(context);
      final strings = uiStrings[key];
      final prose = splitSyntaxLine(strings?[locale] ?? '');
      final shown = splitSyntaxLine(strings?[exampleLocale] ?? '');
      final example = shown.example ?? prose.example;
      final runnable = shown.runnable ?? prose.runnable;
      final line = example == null
          ? prose.prose
          : '$example$kSyntaxExampleSeparator${prose.prose}';
      final text = Text(
        line,
        style: TextStyle(
          fontSize: t.chrome,
          color: wbc.mutedText,
          fontFamilyFallback: kCjkFontFallback,
        ),
      );
      if (runnable == null) {
        return Padding(
          padding: const EdgeInsets.only(top: 1.5),
          child: text,
        );
      }
      return InkWell(
        onTap: () => _writeLine(runnable),
        // Whole-row target. On a tablet the example alone is a 12px run
        // of text, which is not something a finger can hit.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: text,
        ),
      );
    });
  }

  /// The language of the edition being SEARCHED, which is the language
  /// the card's examples have to be written in.
  String _searchVersionLanguage() {
    final code = context.read<MainProvider>().currentVersion;
    for (final v in bibleVersions) {
      if (v.value == code) return v.language;
    }
    return 'en';
  }

  Widget _buildResults(BuildContext context, WorkbenchProvider wb,
      AppSettings settings, ColorScheme scheme, String locale) {
    // A search limit silently removes hits, so it has to be visible
    // wherever the hits are. BibleWorks shows the active limit on the
    // command line; here it is a strip above the results, and tapping
    // it lifts the limit.
    final notice = wb.verbNotice;
    if (wb.hasSearchLimit || notice != null) {
      final t = WbType.of(context);
      return Column(
        children: [
          if (notice != null) _verbNoticeStrip(wb, scheme, notice, t),
          if (wb.hasSearchLimit) _limitBanner(context, wb, scheme, locale),
          Expanded(child: _buildResultsBody(context, wb, settings, scheme, locale)),
        ],
      );
    }
    return _buildResultsBody(context, wb, settings, scheme, locale);
  }

  /// What the last verb did, above the results rather than instead of
  /// them: `d nas` must not throw away a hit list you spent three
  /// commands building.
  Widget _verbNoticeStrip(WorkbenchProvider wb, ColorScheme scheme,
      String notice, WbType t) {
    return Material(
      color: scheme.secondaryContainer,
      child: InkWell(
        onTap: () => wb.showVerbNotice(null),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.terminal,
                  size: 14, color: scheme.onSecondaryContainer),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  notice,
                  style: TextStyle(
                    fontSize: t.scaled(11.5),
                    fontWeight: FontWeight.w600,
                    color: scheme.onSecondaryContainer,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ),
              Icon(Icons.close_rounded,
                  size: 14, color: scheme.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  /// The active scope, above the hits it removed.
  ///
  /// Tapping the strip now OPENS the picker rather than clearing the
  /// limit, and the × clears — bwh12's convention (double-click the
  /// Limits status area to open the window) and the safer default: a
  /// reader who means to narrow further should not lose the scope they
  /// have by aiming at the wrong pixel.
  Widget _limitBanner(BuildContext context, WorkbenchProvider wb,
      ColorScheme scheme, String locale) {
    final t = WbType.of(context);
    final name = scopeDisplayName(
      spec: wb.searchLimitSpec,
      fallbackLabel: wb.searchLimitLabel,
      locale: locale,
      version: context.read<MainProvider>().currentVersion,
      maxNames: 3,
    );
    final label = (uiStrings['vlmLimitBanner']?[locale] ??
            'Limited to {name} ({count})')
        .replaceAll('{name}',
            name.isEmpty ? (uiStrings['vlmMain']?[locale] ?? 'Main') : name)
        .replaceAll('{count}', '${wb.searchLimit?.length ?? 0}');
    return Material(
      color: scheme.tertiaryContainer,
      child: InkWell(
        onTap: widget.onEditScope,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.filter_alt, size: 14, color: scheme.onTertiaryContainer),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.scaled(11.5),
                    fontWeight: FontWeight.w600,
                    color: scheme.onTertiaryContainer,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ),
              _MiniIcon(
                icon: Icons.close_rounded,
                tooltip: uiStrings['clear']?[locale] ?? 'Clear',
                onTap: () => wb.setSearchLimit(null, null),
                color: scheme.onTertiaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsBody(BuildContext context, WorkbenchProvider wb,
      AppSettings settings, ColorScheme scheme, String locale) {
    if (wb.aiBusy) {
      // Named, unlike the plain search spinner: an AI round-trip takes
      // seconds, not milliseconds, and an unlabelled spinner that long
      // reads as a hang.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2)),
            const SizedBox(height: 10),
            Text(
              uiStrings['aiSearching']?[locale] ?? 'SeekSparks AI searching…',
              style: TextStyle(
                fontSize: settings.fontSize - 2,
                color: scheme.outline,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
          ],
        ),
      );
    }
    if (wb.searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!wb.searchPerformed) {
      return _emptyState(settings, scheme, locale);
    }
    final issue = wb.commandIssue;
    if (issue != null) {
      // The query was written in the grammar and the grammar refused it.
      // Naming the part that is unsupported beats returning nothing:
      // "regular expressions are not supported here" is actionable and
      // an empty list is not.
      return _noResults(settings, scheme, locale,
          message: describeCommandIssue(issue, locale));
    }
    final aiRefs = wb.aiRefs;
    if (aiRefs != null) {
      return _buildAiResults(context, wb, settings, scheme, locale, aiRefs);
    }
    final strongsRefs = wb.strongsRefs;
    if (strongsRefs != null) {
      return _buildStrongsResults(context, wb, settings, scheme, locale, strongsRefs);
    }
    return _buildTextResults(context, wb, settings, scheme, locale);
  }

  /// What the header calls the query: the parse read back in words when
  /// there is one, the raw line otherwise.
  ///
  /// This is the part with no equivalent in BibleWorks, Logos or
  /// Accordance — all three run the query and none says what it
  /// understood. With punctuation for operators that is where the whole
  /// day goes: `'!your *5 house` looks like it excludes "your" and does
  /// not, and there is no way to find that out from a list of verses.
  String _queryLabel(WorkbenchProvider wb, String locale) {
    final compound = wb.compoundQuery;
    if (compound != null) return describeCompoundQuery(compound, locale);
    final cq = wb.commandQuery;
    return cq == null ? wb.lastQuery : describeCommandQuery(cq, locale);
  }

  /// The looser reading of the query, offered with the count it really
  /// returns — or nothing at all.
  ///
  /// This replaced a hint that named `.{words}` without ever running it.
  /// The distinction is the whole feature: the reader who reported this
  /// was handed `.ὁ θεός` by that hint, tapped it, and arrived at a
  /// second empty page. [WorkbenchProvider.broadening] is null unless
  /// the query behind it was measured and beat the one she ran, so a row
  /// that appears is a row worth tapping.
  ///
  /// It fills AND runs, where the `?` card's examples only fill. An
  /// example is a stand-in for words the reader has yet to choose; this
  /// is her own line with one constraint dropped, and its answer is
  /// already known.
  Widget? _broadenOffer(WorkbenchProvider wb, String locale,
      {required CrossAxisAlignment align}) {
    final b = wb.broadening;
    if (b == null) return null;
    return Builder(builder: (context) {
      final wbc = WbColors.of(context);
      final t = WbType.of(context);
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _controller.setTextAtomic(b.line);
            _submit();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: align,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  uiStrings['cmdBroadenLead']?[locale] ??
                      'The same words in one verse, in any order:',
                  textAlign: align == CrossAxisAlignment.center
                      ? TextAlign.center
                      : TextAlign.start,
                  style: TextStyle(
                    fontSize: t.chrome,
                    color: wbc.mutedText,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _summary(b.line, b.verses, locale),
                  textAlign: align == CrossAxisAlignment.center
                      ? TextAlign.center
                      : TextAlign.start,
                  style: TextStyle(
                    fontSize: t.chrome,
                    fontWeight: FontWeight.w600,
                    color: wbc.link,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// The Strong's entries a romanised Greek or Hebrew word reaches, when
  /// no verse of the translation uses the word.
  ///
  /// The rows are separate taps rather than one auto-resolved answer,
  /// because the romanisation collides: `torah` reaches three entries
  /// and `ruach` three, and picking silently would put a claim about
  /// which lemma the reader meant behind a search she thought she wrote.
  /// Each row's count is measured under her scope, so tapping one lands
  /// on exactly the number it advertised.
  Widget? _romanisedOffer(WorkbenchProvider wb, String locale,
      {required CrossAxisAlignment align}) {
    final offer = wb.lemmaOffer;
    if (offer == null) return null;
    final centred = align == CrossAxisAlignment.center;
    final beside = wb.textResults.isNotEmpty;
    return Builder(builder: (context) {
      final wbc = WbColors.of(context);
      final t = WbType.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (beside
                      ? (uiStrings['cmdRomanisedLeadBeside']?[locale] ??
                          'Those matches are inside other words — no verse '
                              'uses “{word}” on its own. The original does:')
                      : (uiStrings['cmdRomanisedLead']?[locale] ??
                          'No verse uses the word “{word}”, but the '
                              'original does:'))
                  .replaceAll('{word}', offer.query),
              textAlign: centred ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: t.chrome,
                color: wbc.mutedText,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
            for (final hit in offer.hits) ...[
              const SizedBox(height: 3),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _controller.setTextAtomic(hit.candidate.strongs);
                    _submit();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      (uiStrings['cmdRomanisedHit']?[locale] ??
                              '{number} · {lemma} {translit} — {gloss} · '
                                  '{count} verses')
                          .replaceAll('{number}', hit.candidate.strongs)
                          .replaceAll('{lemma}', hit.candidate.word.lemma)
                          .replaceAll('{translit}', hit.candidate.word.translit)
                          .replaceAll('{gloss}', hit.candidate.word.gloss)
                          .replaceAll('{count}', hit.verses.toString()),
                      textAlign: centred ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        fontSize: t.chrome,
                        fontWeight: FontWeight.w600,
                        color: wbc.link,
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  /// Why there are no results, when the answer is a word rather than a
  /// query. Null unless every word was probed.
  String? _missingWords(WorkbenchProvider wb, String locale) {
    // A compound has its own answer, and it is a better one: a combined
    // list of nothing cannot show which of two searches was the empty
    // half, and re-probing single words would blame the wrong thing.
    final compound = wb.compoundQuery;
    final counts = wb.compoundGroupCounts;
    if (compound != null && counts != null) {
      final sources = compound.groupSources;
      for (var i = 0; i < counts.length && i < sources.length; i++) {
        if (counts[i] > 0) continue;
        return (uiStrings['cmdCompoundGroupEmpty']?[locale] ??
                'No verse matched ({group}), so the whole compound found nothing.')
            .replaceAll('{group}', sources[i]);
      }
      return uiStrings['cmdCompoundNoOverlap']?[locale] ??
          'Each group found verses, but none of them fall together as the line asks.';
    }
    final missing = wb.termsMissing;
    if (missing == null) return null;
    final listSep = uiStrings['cmdListSeparator']?[locale] ?? ', ';
    if (missing.absent.isNotEmpty) {
      return (uiStrings['cmdWordNotFound']?[locale] ??
              'This search found no verse containing {words}.')
          .replaceAll('{words}', missing.absent.join(listSep));
    }
    if (missing.allPresentApart) {
      return uiStrings['cmdWordsNeverTogether']?[locale] ??
          'Each of these words occurs, but no one verse holds them all.';
    }
    return null;
  }

  /// Before the first search: the queries that worked, or — for a
  /// reader with no history — what the box can do.
  ///
  /// The recents list is the one thing the standalone search page had
  /// that the command line did not, and it is not decoration: a
  /// punctuation grammar means the query you got right last Tuesday is
  /// worth more than the one you can retype from memory.
  Widget _emptyState(AppSettings settings, ColorScheme scheme, String locale) {
    if (_recents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            uiStrings['commandEmptyState']?[locale] ??
                'Search the text, or combine Strong\'s numbers:\n'
                    'G25 AND G26 · G25 NEAR5 G26 · G25✶',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: settings.fontSize - 1,
              color: scheme.outline,
              height: 1.6,
            ),
          ),
        ),
      );
    }
    return Builder(builder: (context) {
      final wbc = WbColors.of(context);
      final t = WbType.of(context);
      return Column(
        children: [
          Container(
            height: t.paneTitleHeight,
            decoration: BoxDecoration(
              color: wbc.chromeBg,
              border: Border(
                top: BorderSide(color: wbc.border),
                bottom: BorderSide(color: wbc.border),
              ),
            ),
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    uiStrings['recentSearches']?[locale] ?? 'Recent',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: t.chrome,
                      color: wbc.text,
                    ),
                  ),
                ),
                _MiniIcon(
                  icon: Icons.delete_sweep_outlined,
                  tooltip: uiStrings['clearAllRecent']?[locale] ?? 'Clear all',
                  onTap: () async {
                    await RecentSearchesService.clear();
                    await _loadRecents();
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _recents.length,
              itemBuilder: (context, index) {
                final entry = _recents[index];
                return _RecentRow(
                  query: entry.query,
                  when: relativeTime(entry.createdAt, locale),
                  removeTooltip: uiStrings['clear']?[locale] ?? 'Clear',
                  onTap: () {
                    _controller.setTextAtomic(entry.query);
                    _submit();
                  },
                  onDelete: () async {
                    await RecentSearchesService.remove(entry.query);
                    await _loadRecents();
                  },
                );
              },
            ),
          ),
        ],
      );
    });
  }

  /// Hand the current line to the model. Used by the button that
  /// appears when a literal search finds nothing — the moment the
  /// feature is actually for.
  Future<void> _askAi(String question) async {
    final settings = context.read<AppSettings>();
    final wb = context.read<WorkbenchProvider>();
    await wb.runAiSearch(
      question: question,
      locale: settings.locale,
      userApiKey: settings.geminiApiKey.isEmpty ? null : settings.geminiApiKey,
      aiModel: settings.aiModel,
    );
    if (!mounted) return;
    if (wb.aiRefs?.isNotEmpty ?? false) await _commitRecent('ai $question');
  }

  /// Whether the failure the model reported is one the reader can fix
  /// by supplying their own key. Matched on the message because that is
  /// all the service returns; the alternative — offering the key setup
  /// after every failure — teaches readers to ignore it.
  bool _shouldOfferByok(String? notice) {
    if (notice == null) return false;
    final lower = notice.toLowerCase();
    const triggers = [
      'quota',
      'exhausted',
      'rate-limit',
      'rate limit',
      'not configured',
      'gemini_api_key',
      '配额',
      '用完',
      '没有配置',
    ];
    for (final t in triggers) {
      if (lower.contains(t)) return true;
    }
    return false;
  }

  /// The model's answer: references and the sentence that justifies
  /// each one.
  ///
  /// A different list from the other three because the unit is
  /// different — a reference and an argument, not a verse and its
  /// text — and because a reference the loaded edition does not carry
  /// still has to appear. See `resolveAiRefs`.
  Widget _buildAiResults(
      BuildContext context,
      WorkbenchProvider wb,
      AppSettings settings,
      ColorScheme scheme,
      String locale,
      List<AiBibleRef> refs) {
    if (refs.isEmpty) {
      return _noResults(settings, scheme, locale,
          message: wb.aiNotice, byokNotice: wb.aiNotice);
    }
    final wbc = WbColors.of(context);
    final t = WbType.of(context);
    final header = (uiStrings['aiBibleSearchHeader']?[locale] ??
            'SeekSparks AI found {count} passages for "{query}" '
                '(reference only)')
        .replaceAll('{query}', wb.aiQuery ?? '')
        .replaceAll('{count}', '${refs.length}');
    final notice = wb.aiNotice;
    return Column(
      children: [
        _resultHeader(header, () => _copyAllAiRefs(wb, settings, refs),
            settings, locale),
        // The caveat rides above the list, not under it: it qualifies
        // every row and a footer on a scrolling list is unread.
        Container(
          width: double.infinity,
          color: wbc.chromeBg,
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uiStrings['aiReferenceOnly']?[locale] ??
                    'AI is only an aid — verify against Scripture.',
                style: TextStyle(
                  fontSize: t.chrome,
                  color: wbc.mutedText,
                  fontStyle: FontStyle.italic,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
              if (notice != null) ...[
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    children: parseAiMarkdown(
                      notice,
                      base: TextStyle(
                        fontSize: t.chrome,
                        color: wbc.mutedText,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: refs.length,
            itemBuilder: (context, index) {
              final ref = refs[index];
              final unresolved = wb.aiUnresolved.contains(ref.display);
              final displayBook = localeAwareBookName(
                  ref.book, locale, wb.mainProvider.currentVersion);
              final label = ref.verseStart == ref.verseEnd
                  ? '$displayBook ${ref.chapter}:${ref.verseStart}'
                  : '$displayBook ${ref.chapter}:'
                      '${ref.verseStart}-${ref.verseEnd}';
              return _AiRefRow(
                reference: label,
                reason: ref.reason,
                unresolved: unresolved,
                unresolvedTag:
                    uiStrings['aiRefOnlyTag']?[locale] ?? 'reference only',
                onTap: () {
                  if (unresolved) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
                      content: Text(uiStrings['aiRefNotInVersion']?[locale] ??
                          "This passage isn't in your current Bible version."),
                      duration: const Duration(seconds: 3),
                    ));
                    return;
                  }
                  final verse = _firstVerseOf(wb, ref);
                  if (verse != null) _openVerse(verse);
                },
                onLongPress: () => ClipboardHelper.copyWithFeedback(
                    context, '$label  ${ref.reason}'.trim()),
              );
            },
          ),
        ),
      ],
    );
  }

  /// The first verse of [ref] the loaded edition actually has. Not
  /// necessarily `verseStart`: a versification difference can leave a
  /// range starting one verse late.
  Verse? _firstVerseOf(WorkbenchProvider wb, AiBibleRef ref) {
    for (var v = ref.verseStart; v <= ref.verseEnd; v++) {
      final hit = wb.verseByRef['${ref.book}-${ref.chapter}-$v'];
      if (hit != null) return hit;
    }
    return null;
  }

  /// Copies the answer, reasons included — the reasons are the part a
  /// reader pastes into a study document.
  Future<void> _copyAllAiRefs(
      WorkbenchProvider wb, AppSettings settings, List<AiBibleRef> refs) async {
    final locale = settings.locale;
    final lines = <String>[wb.aiQuery ?? '', ''];
    for (final ref in refs) {
      final displayBook = localeAwareBookName(
          ref.book, locale, wb.mainProvider.currentVersion);
      final label = ref.verseStart == ref.verseEnd
          ? '$displayBook ${ref.chapter}:${ref.verseStart}'
          : '$displayBook ${ref.chapter}:${ref.verseStart}-${ref.verseEnd}';
      lines.add('$label  ${ref.reason}'.trim());
    }
    lines
      ..add('')
      ..add(uiStrings['aiReferenceOnly']?[locale] ??
          'AI is only an aid — verify against Scripture.');
    await ClipboardHelper.copyWithFeedback(
      context,
      lines.join('\n'),
      messageOverride: (uiStrings['copyAllResultsToast']?[locale] ??
              'Copied {n} matches')
          .replaceAll('{n}', refs.length.toString()),
    );
  }

  Widget _buildStrongsResults(BuildContext context, WorkbenchProvider wb,
      AppSettings settings, ColorScheme scheme, String locale,
      List<ConcordanceRef> refs) {
    if (refs.isEmpty) {
      // "No results found" alone conflates three different facts — see
      // `strongs_absence.dart`. Name which one this is.
      final label = wb.strongsQueryLabel ?? wb.lastQuery;
      final absence = classifyStrongsAbsence(
        label: label,
        corpusVerses: wb.strongsCorpusVerses,
        shownVerses: refs.length,
        scoped: wb.hasSearchLimit,
      );
      return _noResults(settings, scheme, locale,
          message: absence == null
              ? null
              : describeStrongsAbsence(absence, locale,
                  label: label,
                  corpusVerses: wb.strongsCorpusVerses,
                  corpusOccurrences: wb.strongsCorpusOccurrences,
                  scopeLabel: wb.searchLimitLabel));
    }
    final hl = highlightsForQuery(wb.lastQuery);
    // Warm the books this list will draw from. cachedForVerse is a
    // cache peek and marks nothing on a miss, so without this the first
    // paint of a new search would be unmarked and would stay that way
    // until something else rebuilt the list.
    // 2026-08-06: the distribution goes ABOVE the list. BibleWorks puts
    // search statistics in their own window, which on a pad would mean
    // a second surface for something you want to read alongside the
    // hits, not instead of them.
    //
    // 2026-08-10 (#308): which UNIT it draws is decided by
    // `strongsDistribution`, not by which list happened to be at hand.
    // Tallying the refs is right for every number since v1.6.96 — until
    // then the bundled list stopped at 500 and the tally drew the cap
    // rather than the word.
    final distribution = strongsDistribution(
      listedBooks: refs.map((r) => r.englishBook),
      occurrencesByBook: wb.strongsByBook,
      listTruncated: wb.strongsListTruncated,
      scoped: wb.hasSearchLimit,
      bookOrder: const [...canonicalOtBooks, ...canonicalNtBooks],
      oldTestamentBooks: oldTestamentBooks,
    );
    return Column(
      children: [
        _resultHeader(
          _strongsSummary(
            wb.strongsQueryLabel ?? wb.lastQuery,
            wb.strongsCounts ?? StrongsResultCounts(verses: refs.length),
            locale,
          ),
          () => _copyAllStrongsRefs(wb, settings, refs),
          settings,
          locale,
        ),
        SearchStatsStrip(
          distribution: distribution,
          locale: locale,
          version: wb.mainProvider.currentVersion,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: refs.length,
            itemBuilder: (context, index) {
              final ref = refs[index];
              final displayBook = localeAwareBookName(
                  ref.englishBook, locale, wb.mainProvider.currentVersion);
              final preview = _cleanPreview(
                  wb.verseByRef['${ref.englishBook}-${ref.chapter}-${ref.verse}']
                          ?.text ??
                      '');
              final runs = TaggedTextService.cachedForVerse(
                version: wb.mainProvider.currentVersion,
                englishBook: ref.englishBook,
                chapter: ref.chapter,
                verse: ref.verse,
              );
              if (runs == null) {
                // Not cached yet: ask for this book's tagging and let
                // the row redraw when it lands. An edition that ships
                // none never gets past the supports() check inside.
                _warmTaggingForRow(
                    wb.mainProvider.currentVersion, ref.englishBook);
              }
              // Which WORD carries the number is something only the
              // tagging knows, so an untagged edition (NASB, 梁家铿, and
              // 雅偉版繁體 today) cannot mark a Strong's hit at all —
              // there is nothing that says which word it is. Those fall
              // through to an unmarked line rather than guessing.

              return _ResultRow(
                reference: '$displayBook ${ref.chapter}:${ref.verse}',
                text: preview,
                spans: strongsSnippetSpans(
                  preview: preview,
                  runs: runs
                      ?.map((r) => (text: r.text, strongs: r.strongs))
                      .toList(),
                  highlight: hl,
                ),
                onTap: () {
                  final verse = wb.verseForRef(ref);
                  if (verse != null) _openVerse(verse);
                },
                onLongPress: () => ClipboardHelper.copyMarkedWithFeedback(
                    context,
                    '$displayBook ${ref.chapter}:${ref.verse}  '
                    '${markVerseHits(preview, highlight: hl, runs: runs?.map((x) => (text: x.text, strongs: x.strongs)).toList())}'),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Load the tagging for the book a row needs, the first time a row
  /// from that book is built.
  ///
  /// 2026-08-31 (owner-reported: "why some has highlight while many
  /// don't"): this used to warm the first EIGHT books the result set
  /// touched and stop. A G25 search spans 22 books, so 罗马书 and
  /// 哥林多前书 marked and 加拉太书 and 以弗所书 did not — not a gap in
  /// the tagging, a cap in the loader, and one the reader could only
  /// read as the app being unreliable about its own highlighting.
  ///
  /// The cap existed to stop a 35-book query pulling most of the tagged
  /// layer for rows nobody scrolls to. Warming per ROW keeps that
  /// saving and loses the arbitrariness: a book is fetched when a row
  /// from it is actually built, which is the same "on screen" the old
  /// comment claimed and the prefix never was. Requests are batched to
  /// one round after the frame, so a fling through the list does not
  /// fire a fetch per row.
  void _warmTaggingForRow(String version, String englishBook) {
    if (!TaggedTextService.supports(version)) return;
    final key = '$version/$englishBook';
    if (!_tagRequested.add(key)) return;
    _tagPending.add(key);
    if (_tagFlushScheduled) return;
    _tagFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _tagFlushScheduled = false;
      final batch = _tagPending.toList();
      _tagPending.clear();
      await Future.wait(batch.map((k) {
        final i = k.indexOf('/');
        return TaggedTextService.prefetchBook(k.substring(0, i),
            k.substring(i + 1));
      }));
      if (mounted) setState(() {});
    });
  }

  Widget _buildTextResults(BuildContext context, WorkbenchProvider wb,
      AppSettings settings, ColorScheme scheme, String locale) {
    final results = wb.textResults;
    final hl = highlightsForQuery(wb.lastQuery);
    if (results.isEmpty) {
      // The one place the model earns its keep: the literal scan has
      // said the words are not there, so "describe what you mean
      // instead" is the next thing to try rather than a competing mode.
      // Before that, though, two cheaper answers: a looser query that is
      // known to return verses, or — when there is none — the word that
      // is the reason there are none.
      return _noResults(settings, scheme, locale,
          message: _missingWords(wb, locale),
          below: _broadenOffer(wb, locale, align: CrossAxisAlignment.center) ??
              _romanisedOffer(wb, locale, align: CrossAxisAlignment.center),
          aiQuery: wb.lastQuery);
    }
    // `??` and not a pair: broadening needs two words to have anything
    // to loosen, the romanised offer needs exactly one, so at most one
    // of them is ever non-null. This branch reaches the second only
    // through the substring artefacts — `shalom` finding Jehovahshalom
    // — which is precisely when the reader still wants H7965.
    final offer =
        _broadenOffer(wb, locale, align: CrossAxisAlignment.start) ??
            _romanisedOffer(wb, locale, align: CrossAxisAlignment.start);
    return Column(
      children: [
        _resultHeader(
          _summary(_queryLabel(wb, locale), results.length, locale),
          () => _copyAllTextResults(settings, results),
          settings,
          locale,
        ),
        // Under the count, not over it: the reader asked for this list
        // and it is the answer. The offer is the thing to try next, and
        // it only exists here because the list is short enough to have
        // left room for it.
        if (offer != null)
          Builder(builder: (context) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: WbColors.of(context).border)),
              ),
              child: offer,
            );
          }),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final v = results[index];
              final displayBook = localeAwareBookName(
                  v.book, locale, wb.mainProvider.currentVersion);
              // The preview shows the string the search RAN against: a
              // text scan runs over `Verse.scriptureText` (check 33), so
              // a hit in a psalm title is legible here, where the
              // Strong's list above uses `.text` because the tagged
              // layer holds no title.
              // Not the same as "every row visibly contains the query".
              // A plain search matches over the space-stripped key, so
              // `forth` lists the 2,542 verses that say "for the" and
              // nothing in them is markable. Measured 2026-08-19; see
              // PARITY-BACKLOG §3.1.
              final clean = sanitizeForSearch(v.scriptureText);
              return _ResultRow(
                reference: '$displayBook ${v.chapter}:${v.verseLabel}',
                text: clean,
                // Mark what was found. Without this the hit list is a
                // table of contents — the same argument search_highlight
                // makes for the text pane, which has marked its hits
                // since 2026-08-06 while this list never did.
                spans: splitOnTerms(clean, hl.textTerms),
                onTap: () => _openVerse(v),
                onLongPress: () => ClipboardHelper.copyMarkedWithFeedback(
                    context,
                    '$displayBook ${v.chapter}:${v.verseLabel}  '
                    '${markHits(clean, splitOnTerms(clean, hl.textTerms))}'),
              );
            },
          ),
        ),
      ],
    );
  }

  /// The hit-count strip above the list, e.g. "G25 AND G26 — 14 verses".
  Widget _resultHeader(
      String summary, VoidCallback onCopy, AppSettings settings, String locale) {
    return Builder(builder: (context) {
      final wbc = WbColors.of(context);
    final t = WbType.of(context);
      return Container(
        height: t.paneTitleHeight,
        decoration: BoxDecoration(
          color: wbc.chromeBg,
          border: Border(
            top: BorderSide(color: wbc.border),
            bottom: BorderSide(color: wbc.border),
          ),
        ),
        padding: const EdgeInsets.only(left: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: t.chrome,
                  color: wbc.text,
                ),
              ),
            ),
            _MiniIcon(
              icon: Icons.content_copy_outlined,
              tooltip:
                  uiStrings['copyAllResults']?[locale] ?? 'Copy all results',
              onTap: onCopy,
            ),
            const SizedBox(width: 4),
          ],
        ),
      );
    });
  }

  /// [aiQuery] offers to hand the line to the model; [byokNotice] is
  /// the failure text to test before offering the reader their own API
  /// key. Both are absent for the grammar's own errors — a query the
  /// parser refused is a typo, not a question too hard for a literal
  /// search.
  ///
  /// [below] sits above both buttons: a looser query that is known to
  /// return verses outranks handing the line to a model.
  Widget _noResults(AppSettings settings, ColorScheme scheme, String locale,
      {String? message, Widget? below, String? aiQuery, String? byokNotice}) {
    return Builder(builder: (context) {
      final wbc = WbColors.of(context);
    final t = WbType.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                uiStrings['noResults']?[locale] ?? 'No results found',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: t.text, color: wbc.mutedText),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: parseAiMarkdown(
                      message,
                      base: TextStyle(
                        fontSize: t.text - 1,
                        height: 1.5,
                        color: wbc.mutedText,
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (below != null) ...[
                const SizedBox(height: 10),
                below,
              ],
              if (aiQuery != null && aiQuery.trim().length >= 2) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: Text(
                    uiStrings['askAiForVerses']?[locale] ??
                        'Search with SeekSparks AI (reference only)',
                    style: TextStyle(
                        fontSize: t.chrome,
                        fontFamilyFallback: kCjkFontFallback),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(),
                    side: BorderSide(color: wbc.border),
                    foregroundColor: wbc.link,
                  ),
                  onPressed: () => _askAi(aiQuery),
                ),
              ],
              if (_shouldOfferByok(byokNotice) &&
                  !settings.hasUserGeminiKey) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.key_rounded, size: 14),
                  label: Text(
                    uiStrings['aiOpenByokSettings']?[locale] ??
                        'Set up your own Gemini API key',
                    style: TextStyle(
                        fontSize: t.chrome,
                        fontFamilyFallback: kCjkFontFallback),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(),
                    side: BorderSide(color: wbc.border),
                    foregroundColor: wbc.text,
                  ),
                  onPressed: () => pushPage(
                      const SettingsPage(initialSection: SettingsSection.ai)),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

/// One remembered query. Same one-line density as [_ResultRow] — the
/// recents list sits exactly where the results list will, and a taller
/// row here would make the pane jump when the first search lands.
class _RecentRow extends StatefulWidget {
  const _RecentRow({
    required this.query,
    required this.when,
    required this.removeTooltip,
    required this.onTap,
    required this.onDelete,
  });

  final String query;
  final String when;
  final String removeTooltip;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final wbc = WbColors.of(context);
    final t = WbType.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _hovering ? wbc.hoverBg : null,
          padding: const EdgeInsets.only(
              left: WbMetrics.rowPadH, right: 2, top: 2, bottom: 2),
          child: Row(
            children: [
              Icon(Icons.history, size: 12, color: wbc.mutedText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.text,
                    height: t.lineHeight,
                    color: wbc.text,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.when,
                style: TextStyle(fontSize: t.chrome, color: wbc.mutedText),
              ),
              // Only on hover: a × on every row turns a history list
              // into a row of delete buttons.
              SizedBox(
                width: 20,
                child: _hovering
                    ? _MiniIcon(
                        icon: Icons.close,
                        tooltip: widget.removeTooltip,
                        onTap: widget.onDelete,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One AI suggestion: the reference, then the model's reason for it.
///
/// Two lines rather than [_ResultRow]'s one because the reason IS the
/// result here — a bare list of references from a model is indistinguishable
/// from a list of references from a concordance, and the reader has no
/// way to judge which ones to trust.
class _AiRefRow extends StatefulWidget {
  const _AiRefRow({
    required this.reference,
    required this.reason,
    required this.unresolved,
    required this.unresolvedTag,
    required this.onTap,
    required this.onLongPress,
  });

  final String reference;
  final String reason;
  final bool unresolved;
  final String unresolvedTag;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_AiRefRow> createState() => _AiRefRowState();
}

class _AiRefRowState extends State<_AiRefRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final wbc = WbColors.of(context);
    final t = WbType.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: _hovering ? wbc.hoverBg : null,
            border: Border(bottom: BorderSide(color: wbc.border)),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: WbMetrics.rowPadH, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: t.text,
                        height: t.lineHeight,
                        fontWeight: FontWeight.w600,
                        color: widget.unresolved ? wbc.mutedText : wbc.link,
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  ),
                  if (widget.unresolved) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(border: Border.all(color: wbc.border)),
                      child: Text(
                        widget.unresolvedTag,
                        style: TextStyle(
                            fontSize: t.chrome, color: wbc.mutedText),
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.reason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text.rich(
                    TextSpan(
                      children: parseAiMarkdown(
                        widget.reason,
                        base: TextStyle(
                          fontSize: t.chrome,
                          height: 1.35,
                          color: wbc.mutedText,
                        ),
                      ),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One search hit, printed the way BibleWorks prints it: a single tight
/// line, coloured reference first, verse text after. The card list this
/// replaces cost about four times the vertical space per hit, which
/// meant a 40-hit search showed six results instead of the whole screen
/// full that makes a result list useful.
class _ResultRow extends StatefulWidget {
  const _ResultRow({
    required this.reference,
    required this.text,
    required this.onTap,
    required this.onLongPress,
    this.spans,
  });

  final String reference;
  final String text;

  /// The snippet already split into hit / not-hit pieces. Null means
  /// "nothing to mark" — an empty query, or a Strong's query whose
  /// edition ships no tagging — and the row falls back to [text].
  ///
  /// The pieces must tile [text]; that is the contract splitOnTerms
  /// keeps, and the row does not re-check it.
  final List<HighlightSpan>? spans;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final wbc = WbColors.of(context);
    final t = WbType.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _hovering ? wbc.hoverBg : null,
          padding: const EdgeInsets.symmetric(
              horizontal: WbMetrics.rowPadH, vertical: 2),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '${widget.reference}  ',
                style: TextStyle(
                    color: wbc.link, fontWeight: FontWeight.w600),
              ),
              if (widget.spans == null)
                TextSpan(
                    text: widget.text, style: TextStyle(color: wbc.text))
              else
                for (final s in widget.spans!)
                  TextSpan(
                    text: s.text,
                    style: TextStyle(
                      color: wbc.text,
                      // Same weight the text pane marks a hit with, so a
                      // result and the verse it opens agree on what was
                      // found. See browse_window.dart:1760.
                      fontWeight: s.isHit ? FontWeight.w700 : null,
                    ),
                  ),
            ]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: t.text,
              height: t.lineHeight,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
        ),
      ),
    );
  }
}

/// A 20px square icon button — the only size that fits the chrome.
class _MiniIcon extends StatelessWidget {
  const _MiniIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final wbc = WbColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 14, color: color ?? wbc.mutedText),
        ),
      ),
    );
  }
}

/// One tappable thing in the hint row: the rewrite being offered, or the
/// way out of the question the hint just raised.
///
/// A full-width target rather than a text link. The reports come from a
/// tablet, and a 12px run of text is not a touch target — the whole row
/// is, and it wraps instead of overflowing when the pane is at its 256px
/// minimum and the label is a Chinese sentence.
class _HintAction extends StatelessWidget {
  const _HintAction({
    required this.label,
    required this.onTap,
    this.tooltip,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final String? tooltip;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final wbc = WbColors.of(context);
    final t = WbType.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 26),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: wbc.paneBg,
          border: Border.all(color: wbc.link.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The caption sits ABOVE rather than beside the query: in
            // Chinese both are long, and side by side they either
            // overflow or ellipsise the query — which is the one part of
            // the row the reader has to be able to read before tapping.
            if (tooltip != null)
              Text(
                tooltip!,
                style: TextStyle(
                  fontSize: t.chrome,
                  color: wbc.mutedText,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon ?? Icons.subdirectory_arrow_left,
                      size: 13, color: wbc.link),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: t.chrome,
                      color: wbc.link,
                      fontWeight: FontWeight.w600,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// . / ' ! ✶ AND OR NOT NEARn ? — small square buttons, not Material
/// chips, so the operator strip costs one line instead of three.
class _OperatorButton extends StatelessWidget {
  const _OperatorButton({
    required this.label,
    required this.onTap,
    this.tooltip,
    this.selected = false,
    this.dimmed = false,
  });

  final String label;
  final VoidCallback onTap;
  final String? tooltip;
  final bool selected;

  /// The operator cannot do anything with the line as it stands. Drawn
  /// back rather than disabled — see [_CommandPaneState._operatorStrip].
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final wbc = WbColors.of(context);
    final t = WbType.of(context);
    final button = InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? wbc.hoverBg : wbc.chromeBg,
          border: Border.all(
              color: selected
                  ? wbc.link
                  : dimmed
                      ? wbc.border.withValues(alpha: 0.45)
                      : wbc.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: t.chrome,
            fontWeight: FontWeight.w600,
            color: selected
                ? wbc.link
                : dimmed
                    ? wbc.mutedText.withValues(alpha: 0.55)
                    : wbc.text,
          ),
        ),
      ),
    );
    final message = tooltip;
    return message == null ? button : Tooltip(message: message, child: button);
  }
}
