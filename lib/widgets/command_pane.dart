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
import 'package:seeksparks/utils/command_draft.dart';
import 'package:seeksparks/utils/command_query.dart';
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
  const CommandPane(
      {super.key, this.focusNode, this.onVerseOpened, this.onEditScope});

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_undoSelectAllEcho);
    _loadRecents();
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
    final running = wb.runSearch(raw);
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
    if (wb.commandIssue == null) await _commitRecent(raw);
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

  /// `nas`, `NASB`, `kjv`… → that version's code. Matches the internal
  /// code and the short label, case-insensitively; returns null for
  /// anything else so the token falls through to reference-parsing and
  /// then to search.
  String? _matchVersion(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty || q.contains(' ')) return null;
    for (final v in bibleVersions) {
      if (v.value.toLowerCase() == q ||
          v.shortLabel.toLowerCase() == q) {
        return v.value;
      }
    }
    return null;
  }

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

  /// Tap a result: scroll the center reader to the verse (pendingJump
  /// handshake, drained by the reader's next frame) and focus it in
  /// the analysis pane.
  void _openVerse(Verse verse) {
    final wb = context.read<WorkbenchProvider>();
    jumper.prepareJumpToVerse(verse, wb.mainProvider);
    wb.focusVerse(verse);
    widget.onVerseOpened?.call();
  }

  Future<void> _copyAllStrongsRefs(
      WorkbenchProvider wb, AppSettings settings, List<ConcordanceRef> refs) async {
    final mp = wb.mainProvider;
    final lines = <String>[wb.strongsQueryLabel ?? '', ''];
    for (final r in refs) {
      final displayBook =
          localeAwareBookName(r.englishBook, settings.locale, mp.currentVersion);
      final clean =
          _cleanPreview(wb.verseByRef['${r.englishBook}-${r.chapter}-${r.verse}']
                  ?.text ??
              '');
      lines.add('$displayBook ${r.chapter}:${r.verse}  $clean'.trim());
    }
    await ClipboardHelper.copyWithFeedback(
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
    final lines = <String>[wb.lastQuery, ''];
    for (final v in results) {
      final displayBook =
          localeAwareBookName(v.book, settings.locale, mp.currentVersion);
      lines.add('$displayBook ${v.chapter}:${v.verseLabel}  '
          '${sanitizeForSearch(v.text)}'.trim());
    }
    await ClipboardHelper.copyWithFeedback(
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
    final draft = analyseCommandDraft(_controller.text);
    final dim = !draft.combinersApply;
    String tip(String key, String fallback) =>
        (uiStrings[key]?[locale] ?? fallback)
            .replaceAll('{n}', '$_nearDistance');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              _OperatorButton(
                  label: '.',
                  tooltip: tip('cmdOpTipAll', '. every word, one verse'),
                  onTap: () => _setControl('.')),
              _OperatorButton(
                  label: '/',
                  tooltip: tip('cmdOpTipAny', '/ any of the words'),
                  onTap: () => _setControl('/')),
              _OperatorButton(
                  label: "'",
                  tooltip:
                      tip('cmdOpTipPhrase', "' the words in that order"),
                  onTap: () => _setControl("'")),
              _OperatorButton(
                label: '!',
                tooltip: tip('cmdOpTipNot',
                    '! excludes the word it is glued to (also G25 !G26)'),
                onTap: () => _insertToken('!', trailingSpace: false),
              ),
              _OperatorButton(
                label: '*',
                tooltip: tip('cmdOpTipStar',
                    '✶ after a word it is a wildcard; alone it is a word gap'),
                onTap: _insertWildcard,
              ),
              _OperatorButton(
                label: 'AND',
                dimmed: dim,
                tooltip: tip('searchOpAndTip', 'Verses with BOTH'),
                onTap: () => _insertToken('AND'),
              ),
              _OperatorButton(
                label: 'OR',
                dimmed: dim,
                tooltip: tip('searchOpOrTip', 'Verses with EITHER'),
                onTap: () => _insertToken('OR'),
              ),
              _OperatorButton(
                label: 'NOT',
                dimmed: dim,
                tooltip: tip(
                    'searchOpNotTip', 'Verses with the first but not the second'),
                onTap: () => _insertToken('NOT'),
              ),
              _OperatorButton(
                label: 'NEAR$_nearDistance',
                dimmed: dim,
                tooltip: tip('searchOpNearTip',
                    'Within {n} words of each other, either order'),
                onTap: _insertNear,
              ),
              _OperatorButton(
                label: '?',
                tooltip: uiStrings['cmdSyntaxToggle']?[locale] ?? 'Syntax help',
                selected: _showSyntax,
                onTap: () => setState(() => _showSyntax = !_showSyntax),
              ),
            ],
          ),
        ),
        if (draft.showsHint) _draftHint(draft, locale),
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
      return Container(
        width: double.infinity,
        color: wbc.chromeBg,
        padding: const EdgeInsets.fromLTRB(6, 3, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                describeCommandDraft(draft, locale) ?? '',
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
      );
    });
  }

  /// The syntax reference, one line per operator, with a real example
  /// in the reader's own language rather than a metasyntax.
  Widget _syntaxCard(String locale) {
    return Builder(builder: (context) {
      final wbc = WbColors.of(context);
      final t = WbType.of(context);
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
              for (final k in keys)
                Padding(
                  padding: const EdgeInsets.only(top: 1.5),
                  child: Text(
                    uiStrings[k]?[locale] ?? '',
                    style: TextStyle(
                      fontSize: t.chrome,
                      color: wbc.mutedText,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildResults(BuildContext context, WorkbenchProvider wb,
      AppSettings settings, ColorScheme scheme, String locale) {
    // A search limit silently removes hits, so it has to be visible
    // wherever the hits are. BibleWorks shows the active limit on the
    // command line; here it is a strip above the results, and tapping
    // it lifts the limit.
    final notice = wb.verbNotice;
    if (wb.hasSearchLimit || notice != null) {
      return Column(
        children: [
          if (notice != null) _verbNoticeStrip(wb, scheme, notice),
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
  Widget _verbNoticeStrip(
      WorkbenchProvider wb, ColorScheme scheme, String notice) {
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
                    fontSize: 11.5,
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
                    fontSize: 11.5,
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
    final cq = wb.commandQuery;
    return cq == null ? wb.lastQuery : describeCommandQuery(cq, locale);
  }

  /// The nudge shown when a search that looks like several words finds
  /// nothing, because the plain scan is a substring match and `love god`
  /// is not a substring of any verse. Names the query that WOULD work.
  String? _tryAndHint(WorkbenchProvider wb, String locale) {
    final cq = wb.commandQuery;
    final String words;
    if (cq != null) {
      // A phrase that missed: the same words without the order.
      if (cq.kind != CommandKind.phrase) return null;
      words = [for (final t in cq.terms) t.source].join(' ');
    } else {
      // A plain multi-word query, which cannot match by construction.
      if (!wb.lastQuery.contains(' ')) return null;
      words = wb.lastQuery;
    }
    if (words.trim().isEmpty) return null;
    return (uiStrings['cmdTryAndHint']?[locale] ??
            'No verse has that exact run of words. '
                'Try ".{q}" for verses containing all of them.')
        .replaceAll('{q}', words);
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
      return _noResults(settings, scheme, locale);
    }
    // 2026-08-06: the distribution goes ABOVE the list. BibleWorks puts
    // search statistics in their own window, which on a pad would mean
    // a second surface for something you want to read alongside the
    // hits, not instead of them.
    final distribution = buildDistribution(
      hitBooks: refs.map((r) => r.englishBook),
      bookOrder: const [...canonicalOtBooks, ...canonicalNtBooks],
      oldTestamentBooks: oldTestamentBooks,
    );
    return Column(
      children: [
        _resultHeader(
          _summary(wb.strongsQueryLabel ?? wb.lastQuery, refs.length, locale),
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
              return _ResultRow(
                reference: '$displayBook ${ref.chapter}:${ref.verse}',
                text: preview,
                onTap: () {
                  final verse = wb.verseForRef(ref);
                  if (verse != null) _openVerse(verse);
                },
                onLongPress: () => ClipboardHelper.copyWithFeedback(context,
                    '$displayBook ${ref.chapter}:${ref.verse}  $preview'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextResults(BuildContext context, WorkbenchProvider wb,
      AppSettings settings, ColorScheme scheme, String locale) {
    final results = wb.textResults;
    if (results.isEmpty) {
      // The one place the model earns its keep: the literal scan has
      // said the words are not there, so "describe what you mean
      // instead" is the next thing to try rather than a competing mode.
      return _noResults(settings, scheme, locale,
          message: _tryAndHint(wb, locale), aiQuery: wb.lastQuery);
    }
    return Column(
      children: [
        _resultHeader(
          _summary(_queryLabel(wb, locale), results.length, locale),
          () => _copyAllTextResults(settings, results),
          settings,
          locale,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final v = results[index];
              final displayBook = localeAwareBookName(
                  v.book, locale, wb.mainProvider.currentVersion);
              final clean = sanitizeForSearch(v.text);
              return _ResultRow(
                reference: '$displayBook ${v.chapter}:${v.verseLabel}',
                text: clean,
                onTap: () => _openVerse(v),
                onLongPress: () => ClipboardHelper.copyWithFeedback(context,
                    '$displayBook ${v.chapter}:${v.verseLabel}  $clean'),
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
  Widget _noResults(AppSettings settings, ColorScheme scheme, String locale,
      {String? message, String? aiQuery, String? byokNotice}) {
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
                            fontSize: t.chrome - 1, color: wbc.mutedText),
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
  });

  final String reference;
  final String text;
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
              TextSpan(
                  text: widget.text, style: TextStyle(color: wbc.text)),
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
