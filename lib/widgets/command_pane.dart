import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show bibleVersions;
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/fetch_verses.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/reference_parser.dart' show parseReference;
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
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

  @override
  void dispose() {
    _controller.dispose();
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
  void _insertToken(String token) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final needsSpace = start > 0 && !text.substring(0, start).endsWith(' ');
    final insert = '${needsSpace ? ' ' : ''}$token ';
    _controller.text = text.replaceRange(start, end, insert);
    _controller.selection =
        TextSelection.collapsed(offset: start + insert.length);
  }

  void _clear() {
    _controller.clear();
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
          child: TextField(
            controller: _controller,
            focusNode: widget.focusNode,
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
        // ── Operator buttons (structured Strong's search) ──────────
        // Wrap, not Row: the Search window can be dragged down to 240px
        // and a fixed row of five buttons overflowed it.
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              for (final token in const ['AND', 'OR', 'NOT', 'NEAR5', '*'])
                _OperatorButton(
                  label: token,
                  onTap: () => _insertToken(token),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Results ───────────────────────────────────────────────
        Expanded(child: _buildResults(context, wb, settings, scheme, locale)),
      ],
    );
  }

  Widget _buildResults(BuildContext context, WorkbenchProvider wb,
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
    final strongsRefs = wb.strongsRefs;
    if (strongsRefs != null) {
      return _buildStrongsResults(context, wb, settings, scheme, locale, strongsRefs);
    }
    return _buildTextResults(context, wb, settings, scheme, locale);
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
      return _noResults(settings, scheme, locale);
    }
    return Column(
      children: [
        _resultHeader(
          _summary(wb.lastQuery, results.length, locale),
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

  Widget _noResults(AppSettings settings, ColorScheme scheme, String locale) {
    return Builder(builder: (context) {
      final wbc = WbColors.of(context);
    final t = WbType.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            uiStrings['noResults']?[locale] ?? 'No results found',
            style:
                TextStyle(fontSize: t.text, color: wbc.mutedText),
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

/// AND / OR / NOT / NEAR5 / * — small square buttons, not Material
/// chips, so the operator strip costs one line instead of three.
class _OperatorButton extends StatelessWidget {
  const _OperatorButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wbc = WbColors.of(context);
    final t = WbType.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: wbc.chromeBg,
          border: Border.all(color: wbc.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: t.chrome,
            fontWeight: FontWeight.w600,
            color: wbc.text,
          ),
        ),
      ),
    );
  }
}
