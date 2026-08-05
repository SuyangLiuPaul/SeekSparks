/// BibleWorks-style parallel verse display.
///
/// 2026-08 (SeekSparks): the Browse-window idiom from BibleWorks 10 —
/// one verse shown simultaneously in every selected version, stacked,
/// each row prefixed by a small version code. The original-language row
/// (Hebrew right-to-left, Greek left-to-right) sits with them, its words
/// tappable to drive the Word Study pane, so a reader can compare the
/// translations against the original in one glance.
///
/// This is the layout that makes a study tool feel like a study tool;
/// the existing chapter reader stays available as the other mode.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show shortBibleVersionLabel;
import 'package:seeksparks/constants/book_names.dart' show bookNameToEnglish;
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/fetch_verses.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

/// One row of the stack: a translation, or the original-language line.
class _Row {
  final String code; // version code, or '' for the originals row
  final String label; // short label shown in the gutter (KJV / NAS / WTT)
  final String? text; // translation text
  final List<OriginalWord>? words; // originals row
  final bool rtl;
  const _Row({
    required this.code,
    required this.label,
    this.text,
    this.words,
    this.rtl = false,
  });
}

class ParallelVerseView extends StatefulWidget {
  /// English book name (canonical), e.g. "Genesis".
  final String book;
  final int chapter;
  final int verse;

  /// Translation codes to stack, in display order.
  final List<String> versionCodes;

  /// Fired when an original-language word is tapped.
  final void Function(OriginalWord word)? onWordTap;

  /// Fired when the user asks to change which versions are stacked.
  final VoidCallback? onEditVersions;

  const ParallelVerseView({
    super.key,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.versionCodes,
    this.onWordTap,
    this.onEditVersions,
  });

  @override
  State<ParallelVerseView> createState() => _ParallelVerseViewState();
}

class _ParallelVerseViewState extends State<ParallelVerseView> {
  // Whole-version verse lists are expensive to parse, so keep them for
  // the life of the process — the same handful of versions is stacked
  // over and over as the user walks through a chapter.
  static final Map<String, List<Verse>> _versionCache = {};
  static final Map<String, Future<List<Verse>?>> _inflight = {};

  late Future<List<_Row>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ParallelVerseView old) {
    super.didUpdateWidget(old);
    if (old.book != widget.book ||
        old.chapter != widget.chapter ||
        old.verse != widget.verse ||
        !_sameList(old.versionCodes, widget.versionCodes)) {
      setState(() => _future = _load());
    }
  }

  static bool _sameList(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((e) => e);

  static Future<List<Verse>?> _versionVerses(String code) async {
    final cached = _versionCache[code];
    if (cached != null) return cached;
    final list = await (_inflight[code] ??= FetchVerses.loadVerseList(code));
    if (list != null) _versionCache[code] = list;
    return list;
  }

  Future<List<_Row>> _load() async {
    final rows = <_Row>[];

    for (final code in widget.versionCodes) {
      final verses = await _versionVerses(code);
      if (verses == null) continue;
      // Verse.book may be localized depending on the bundle; compare on
      // the canonical English name the caller passed in.
      Verse? hit;
      for (final v in verses) {
        if (v.chapter != widget.chapter || v.verse != widget.verse) continue;
        // v.book may be localized depending on the bundle; canonicalise.
        if ((bookNameToEnglish[v.book] ?? v.book) != widget.book) continue;
        hit = v;
        break;
      }
      if (hit == null) continue;
      rows.add(_Row(
        code: code,
        label: shortBibleVersionLabel(code),
        text: hit.text,
      ));
    }

    // Original-language row last, mirroring BibleWorks' BGT/WTT placement
    // beneath the translations.
    final words =
        await OriginalsService.forVerse(widget.book, widget.chapter, widget.verse);
    if (words != null && words.isNotEmpty) {
      final isHebrew = words.first.strongs.startsWith('H');
      rows.add(_Row(
        code: '',
        label: isHebrew ? 'WTT' : 'BGT',
        words: words,
        rtl: isHebrew,
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;

    return FutureBuilder<List<_Row>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data ?? const <_Row>[];
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No text available for this verse.',
                style: TextStyle(color: scheme.outline),
              ),
            ),
          );
        }
        final ref = '${localeAwareBookName(widget.book, locale, '')} '
            '${widget.chapter}:${widget.verse}';
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ref,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (widget.onEditVersions != null)
                  TextButton.icon(
                    onPressed: widget.onEditVersions,
                    icon: const Icon(Icons.tune_rounded, size: 15),
                    label: const Text('Versions'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
            const Divider(height: 14),
            for (final r in rows) _buildRow(r, scheme, settings, locale),
          ],
        );
      },
    );
  }

  Widget _buildRow(
    _Row r,
    ColorScheme scheme,
    AppSettings settings,
    String locale,
  ) {
    final isOriginal = r.words != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version code gutter — BibleWorks prints a small raised code
          // ahead of the reference; a tinted pill reads the same way and
          // stays legible at small sizes.
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isOriginal
                      ? scheme.tertiaryContainer.withValues(alpha: 0.55)
                      : scheme.secondary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isOriginal
                        ? scheme.onTertiaryContainer
                        : scheme.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${localeAwareBookName(widget.book, locale, r.code)} '
                '${widget.chapter}:${widget.verse}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (isOriginal)
            _buildOriginalLine(r, scheme, settings)
          else
            Text(
              r.text ?? '',
              style: TextStyle(
                fontSize: settings.fontSize,
                height: settings.lineSpacing,
                color: scheme.onSurface,
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
        ],
      ),
    );
  }

  /// Original-language line. Hebrew renders right-to-left; every word is
  /// tappable so the Word Study pane can follow the reader's eye.
  Widget _buildOriginalLine(
    _Row r,
    ColorScheme scheme,
    AppSettings settings,
  ) {
    return Directionality(
      textDirection: r.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Wrap(
        spacing: 7,
        runSpacing: 5,
        alignment: r.rtl ? WrapAlignment.end : WrapAlignment.start,
        children: [
          for (final w in r.words!)
            InkWell(
              onTap: widget.onWordTap == null
                  ? null
                  : () => widget.onWordTap!(w),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: Text(
                  w.text,
                  style: TextStyle(
                    fontSize: settings.fontSize + 3,
                    height: 1.6,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
