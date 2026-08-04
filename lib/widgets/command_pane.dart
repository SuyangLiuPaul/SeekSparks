import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

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
  const CommandPane({super.key});

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

  void _submit() {
    context.read<WorkbenchProvider>().runSearch(_controller.text);
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

    return Column(
      children: [
        // ── Command line ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}), // toggle clear button
            style: TextStyle(fontSize: settings.fontSize),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              hintText: uiStrings['commandSearchHint']?[locale] ??
                  "Search text, or Strong's: G25 AND G26",
              hintStyle: TextStyle(fontSize: settings.fontSize - 2),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      tooltip: uiStrings['clear']?[locale] ?? 'Clear',
                      onPressed: _clear,
                    ),
                  IconButton(
                    icon: Icon(Icons.search_rounded,
                        size: 20, color: scheme.primary),
                    tooltip: uiStrings['search']?[locale] ?? 'Search',
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
        // ── Operator chips (BibleWorks-style structured search) ────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final token in const ['AND', 'OR', 'NOT', 'NEAR5'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(token),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _insertToken(token),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: const Text('✶'),
                    tooltip: 'G25*',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _insertToken('*'),
                  ),
                ),
              ],
            ),
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
    return Column(
      children: [
        _resultHeader(
          _summary(wb.strongsQueryLabel ?? wb.lastQuery, refs.length, locale),
          () => _copyAllStrongsRefs(wb, settings, refs),
          settings,
          locale,
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
              return DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).hoverColor),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  onTap: () {
                    final verse = wb.verseForRef(ref);
                    if (verse != null) _openVerse(verse);
                  },
                  onLongPress: () => ClipboardHelper.copyWithFeedback(
                      context, '$displayBook ${ref.chapter}:${ref.verse}  $preview'),
                  title: Text(
                    '$displayBook ${ref.chapter}:${ref.verse}',
                    style: TextStyle(fontSize: settings.fontSize),
                  ),
                  subtitle: preview.isNotEmpty
                      ? Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: settings.fontSize - 2),
                        )
                      : null,
                ),
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
              return DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).hoverColor),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  onTap: () => _openVerse(v),
                  onLongPress: () => ClipboardHelper.copyWithFeedback(context,
                      '$displayBook ${v.chapter}:${v.verseLabel}  ${sanitizeForSearch(v.text)}'),
                  title: Text(
                    '$displayBook ${v.chapter}:${v.verseLabel}',
                    style: TextStyle(fontSize: settings.fontSize),
                  ),
                  subtitle: Text(
                    sanitizeForSearch(v.text),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: settings.fontSize - 2),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _resultHeader(
      String summary, VoidCallback onCopy, AppSettings settings, String locale) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: settings.fontSize - 1,
              ),
            ),
          ),
          IconButton(
            tooltip: uiStrings['copyAllResults']?[locale] ?? 'Copy all results',
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }

  Widget _noResults(AppSettings settings, ColorScheme scheme, String locale) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          uiStrings['noResults']?[locale] ?? 'No results found',
          style: TextStyle(
            fontSize: settings.fontSize,
            color: scheme.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
