import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show bibleVersions, shortBibleVersionLabel;
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/fetch_verses.dart';
import 'package:seeksparks/utils/atomic_text_edit.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/command_verb.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/reference_parser.dart' show parseReference;
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localeAwareBookName, toEnglish;
import 'package:seeksparks/constants/book_groups.dart'
    show oldTestamentBooks, canonicalOtBooks, canonicalNtBooks;
import 'package:seeksparks/utils/search_stats.dart';
import 'package:seeksparks/widgets/search_stats_strip.dart';

// Hoisted regex — same rationale as search_page.dart's `_kMultiSpaceRe`:
// built once, reused for every preview row during scroll.
final RegExp _kMultiSpaceRe = RegExp(r' {2,}');

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
  const CommandPane({super.key, this.focusNode});

  /// Supplied by the Workbench so View ▸ Command line and the toolbar's
  /// search button can put the caret here — a desktop tool's command
  /// line is always one keystroke away.
  final FocusNode? focusNode;

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
    context.read<WorkbenchProvider>().runSearch(raw);
    // Keep the caret here. `TextInputAction.search` unfocuses the field
    // by default, which is right for a one-shot search box and wrong for
    // a command line: after a search you refine it — widen the context,
    // drop a term — and both ↑ and Esc are dead the moment focus leaves.
    // Navigation does NOT do this; there your attention moves to the text.
    _focus.requestFocus();
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
    final locale = context.read<AppSettings>().locale;
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
        wb.setParallelMode(true);
        wb.showVerbNotice(describeDisplayStack(
            [for (final c in stack) shortBibleVersionLabel(c)], locale));
      case CommandVerbKind.browseOn:
        wb.setParallelMode(true);
        wb.showVerbNotice(
            uiStrings['cmdvBrowseOn']?[locale] ?? 'Browse view.');
      case CommandVerbKind.limitSet:
        final spec = verb.limit!;
        final key = spec.labelKey;
        final label =
            key == null ? spec.label : (uiStrings[key]?[locale] ?? spec.label);
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
    _controller.setTextAtomic(text.replaceRange(start, end, insert),
        caret: start + insert.length);
    _focus.requestFocus();
    setState(() {});
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
    _controller.setTextAtomic('$control$text');
    _focus.requestFocus();
    setState(() {});
  }

  /// Step through [_history]; -1 is older, +1 is newer.
  void _recall(int step) {
    if (_history.isEmpty) return;
    final next = (_historyAt + step).clamp(0, _history.length);
    if (next == _historyAt) return;
    _historyAt = next;
    // Stepping past the newest entry returns the empty line rather than
    // sticking on the last command, so ↓ is a way out and not a trap.
    _controller.setTextAtomic(next == _history.length ? '' : _history[next]);
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    _historyAt = _history.length;
    context.read<WorkbenchProvider>().clearResults();
    setState(() {}); // hide the clear button
  }

  String _cleanPreview(String raw) => raw
      .replaceAll('\n', ' ')
      .replaceAll(notePattern, '')
      .replaceAllMapped(bracePattern, (m) => m.group(1) ?? '')
      .replaceAllMapped(squarePattern, (m) => m.group(1) ?? '')
      .replaceAll(_kMultiSpaceRe, ' ')
      .trim();

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
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              for (final c in const ['.', '/', "'"])
                _OperatorButton(label: c, onTap: () => _setControl(c)),
              _OperatorButton(
                  label: '!', onTap: () => _insertToken('!', trailingSpace: false)),
              for (final token in const ['*', 'AND', 'OR', 'NOT', 'NEAR5'])
                _OperatorButton(
                  label: token,
                  onTap: () => _insertToken(token),
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
        if (_showSyntax) _syntaxCard(locale),
        const Divider(height: 1),
        // ── Results ───────────────────────────────────────────────
        Expanded(child: _buildResults(context, wb, settings, scheme, locale)),
      ],
    );
  }

  /// The syntax reference, one line per operator, with a real example
  /// in the reader's own language rather than a metasyntax.
  Widget _syntaxCard(String locale) {
    return Builder(builder: (context) {
      final wbc = WbColors.of(context);
      final t = WbType.of(context);
      const keys = [
        'cmdSyntaxAnd',
        'cmdSyntaxOr',
        'cmdSyntaxPhrase',
        'cmdSyntaxNot',
        'cmdSyntaxWild',
        'cmdSyntaxGap',
        'cmdSyntaxContext',
        'cmdSyntaxVerbs',
        'cmdSyntaxHistory',
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
            const SizedBox(height: 3),
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
          if (wb.hasSearchLimit) _limitBanner(wb, scheme, locale),
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

  Widget _limitBanner(
      WorkbenchProvider wb, ColorScheme scheme, String locale) {
    final name = wb.searchLimitLabel ?? '';
    final label = (uiStrings['vlmLimitBanner']?[locale] ??
            'Limited to {name} ({count})')
        .replaceAll('{name}',
            name.isEmpty ? (uiStrings['vlmMain']?[locale] ?? 'Main') : name)
        .replaceAll('{count}', '${wb.searchLimit?.length ?? 0}');
    return Material(
      color: scheme.tertiaryContainer,
      child: InkWell(
        onTap: () => wb.setSearchLimit(null, null),
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
                  ),
                ),
              ),
              Icon(Icons.close_rounded,
                  size: 14, color: scheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsBody(BuildContext context, WorkbenchProvider wb,
      AppSettings settings, ColorScheme scheme, String locale) {
    if (wb.searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!wb.searchPerformed) {
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
    final issue = wb.commandIssue;
    if (issue != null) {
      // The query was written in the grammar and the grammar refused it.
      // Naming the part that is unsupported beats returning nothing:
      // "regular expressions are not supported here" is actionable and
      // an empty list is not.
      return _noResults(settings, scheme, locale,
          message: describeCommandIssue(issue, locale));
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
      return _noResults(settings, scheme, locale,
          message: _tryAndHint(wb, locale));
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

  Widget _noResults(AppSettings settings, ColorScheme scheme, String locale,
      {String? message}) {
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
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: t.text - 1,
                    height: 1.5,
                    color: wbc.mutedText,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
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

/// . / ' ! ✶ AND OR NOT NEAR5 ? — small square buttons, not Material
/// chips, so the operator strip costs one line instead of three.
class _OperatorButton extends StatelessWidget {
  const _OperatorButton({
    required this.label,
    required this.onTap,
    this.tooltip,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final String? tooltip;
  final bool selected;

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
          border: Border.all(color: selected ? wbc.link : wbc.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: t.chrome,
            fontWeight: FontWeight.w600,
            color: selected ? wbc.link : wbc.text,
          ),
        ),
      ),
    );
    final message = tooltip;
    return message == null ? button : Tooltip(message: message, child: button);
  }
}
