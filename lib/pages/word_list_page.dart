/// 2026-08-06 (SeekSparks): the Word List Manager — BibleWorks bwh26.
///
/// What a passage is MADE of, rather than where a word occurs. Counted
/// by Strong's number so inflections collapse into one entry, sortable
/// by frequency or — the direction BibleWorks does not offer and
/// exegesis actually wants — by rarity, so the hapax legomena surface.
///
/// Scoped to a chapter or a book. Not the whole Bible: that is 66 file
/// loads and ~700k words for a list nobody reads to the end.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:seeksparks/constants/book_names.dart' show bookNameToEnglish;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/pages/strongs_entry_page.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/utils/word_list.dart';

enum _Scope { chapter, book }

class WordListPage extends StatefulWidget {
  const WordListPage({
    super.key,
    required this.book,
    required this.chapter,
    required this.locale,
    required this.version,
  });

  /// Book as the reader sees it (may be localized); mapped to English
  /// for the originals lookup.
  final String book;
  final int chapter;
  final String locale;
  final String version;

  @override
  State<WordListPage> createState() => _WordListPageState();
}

class _WordListPageState extends State<WordListPage> {
  _Scope _scope = _Scope.chapter;
  WordListSort _sort = WordListSort.frequency;
  List<WordListEntry> _entries = const [];
  bool _loading = true;

  String get _englishBook => bookNameToEnglish[widget.book] ?? widget.book;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final words = _scope == _Scope.chapter
        ? await OriginalsService.forChapter(_englishBook, widget.chapter)
        : await OriginalsService.forBook(_englishBook);
    if (!mounted) return;
    setState(() {
      _entries = buildWordList(words, sort: _sort);
      _loading = false;
    });
  }

  void _resort(WordListSort s) {
    setState(() {
      _sort = s;
      // Re-sorting a list already built is cheaper than recounting, but
      // the tie-break map lives in buildWordList, so rebuild from the
      // entries' own order to keep it deterministic.
      final copy = [..._entries];
      sortWordList(copy, s);
      _entries = copy;
    });
  }

  void _copy() {
    final s = wordListSummary(_entries);
    final head = '${_scopeLabel()}  ${s.distinct}/${s.total}';
    final body = _entries
        .map((e) => '${e.strongs}\t${e.form}\t${e.count}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: '$head\n$body'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(uiStrings['kwicCopied']?[widget.locale] ?? 'Copied'),
      duration: const Duration(seconds: 2),
    ));
  }

  String _scopeLabel() {
    final book = localeAwareBookName(widget.book, widget.locale, widget.version);
    return _scope == _Scope.chapter ? '$book ${widget.chapter}' : book;
  }

  String _s(String k, String fallback) =>
      uiStrings[k]?[widget.locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = wordListSummary(_entries);

    return Scaffold(
      appBar: AppBar(
        title: Text(_s('wordListTitle', 'Word List')),
        actions: [
          IconButton(
            tooltip: _s('kwicCopy', 'Copy all'),
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _entries.isEmpty ? null : _copy,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final e in [
                      (_Scope.chapter, 'wordListScopeChapter', 'This chapter'),
                      (_Scope.book, 'wordListScopeBook', 'Whole book'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_s(e.$2, e.$3)),
                          selected: _scope == e.$1,
                          onSelected: (_) {
                            setState(() => _scope = e.$1);
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_scopeLabel()} · ${summary.distinct} '
                  '${_s('wordListDistinct', 'distinct')} / ${summary.total} '
                  '${_s('wordListTotal', 'words')} · ${summary.hapax} '
                  '${_s('wordListHapax', 'used once')}',
                  style: TextStyle(fontSize: 13, color: scheme.outline),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in [
                      (WordListSort.frequency, 'wordListSortFreq', 'Frequency'),
                      (WordListSort.rarity, 'wordListSortRare', 'Rarest'),
                      (WordListSort.number, 'wordListSortNum', 'Number'),
                      (WordListSort.alphabetical, 'wordListSortAlpha',
                          'Alphabetical'),
                    ])
                      ChoiceChip(
                        label: Text(_s(e.$2, e.$3)),
                        selected: _sort == e.$1,
                        onSelected: (_) => _resort(e.$1),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _s('wordListNone',
                                'No original-language data for this passage.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.outline),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) =>
                            _row(_entries[i], summary.total, scheme),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _row(WordListEntry e, int total, ColorScheme scheme) {
    // A bar relative to the commonest word would make everything after
    // the top few invisible; relative to the total makes the long tail
    // legible, which is where the interesting words are.
    final share = total == 0 ? 0.0 : e.count / total;
    return ListTile(
      dense: true,
      onTap: () => pushPage(StrongsEntryPage(number: e.strongs)),
      title: Row(
        children: [
          Expanded(
            child: Text(e.form,
                style: const TextStyle(fontSize: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text('${e.count}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: e.isHapax ? scheme.primary : scheme.onSurface,
              )),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.translit == null || e.translit!.isEmpty
                ? e.strongs
                : '${e.strongs} · ${e.translit}',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
