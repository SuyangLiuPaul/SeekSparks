/// 2026-09-05 (SeekSparks): the Modern Concordance, opened from Resources.
///
/// **Why it exists.** `assets/concordance/` — 341 topics, 1,645 sections,
/// 370 files, 4.8 MB — has shipped since `34bef43` (2026-08-07), and
/// there was exactly one door into it: sit on a New Testament verse and
/// read the Topics tab. That answers "what is THIS verse filed under"
/// and nothing else. `ModernConcordanceService.topics()`, the call that
/// returns the whole index, had **no caller anywhere in `lib/`** for a
/// month — the data was imported, declared, parsed, and unreachable.
///
/// This is the same defect Nave's had and the same fix: *a database you
/// CONSULT needs a door of its own* (`naves_page.dart`,
/// `workbench_page.dart`'s Resources menu, `docs/PARITY-BACKLOG.md` item
/// 3, which closed Nave's as "both halves"). The two topical indexes sit
/// side by side in the Topics tab; only one of them had both halves.
///
/// **The gap was narrower than "no browse page", and sharper.** The
/// Topics tab does open a topic — but `_TopicDetail` in
/// `analysis_tabs.dart` filters it to the single Greek word that cited
/// the reader's verse, with good reason ("a topic can run to dozens of
/// words; showing all of them would bury the one the reader's verse
/// actually uses"). So two things were unreachable, not one: entry by
/// topic NAME, and a topic's OTHER Greek words. This page is the
/// unfiltered view, which is why it prints every section.
///
/// **Why it is shaped like this.** Three measurements taken before any
/// widget was written:
///
/// 1. 341 rows, not Nave's 5,322. That is about eight flings, so there
///    is no A–Z jump strip: it would cost a row of chrome on a phone to
///    save four flings. `concordance_browse.dart` says the same thing
///    from the logic side.
/// 2. **239 of the 341 names are compounds** — `Catch - Seize - Steal`,
///    `Abyss - Hades - Hell`. Nave's whole-headword prefix rule answers
///    `seize` with nothing here, so the search ranks per SEGMENT. That
///    rule and its counter-example are in `concordance_browse.dart`.
/// 3. Sections per topic: median 4, max 19 (`Destroy - 毁`), and 62
///    topics have exactly one. So a topic prints flat — every section,
///    every word — rather than collapsing: the median entry is four
///    headings long, and an accordion over four rows is chrome charging
///    rent. `Destroy` is the one that scrolls, and it scrolls.
///
/// **What this page knowingly gets wrong.** `ConcordanceTopic.label`
/// hands 繁體 readers the Simplified gloss, because the source has one
/// Chinese column and it is Simplified — the service says so and calls
/// it the lesser of two wrongs. On the Topics tab that shows up a few
/// rows at a time; here it is 341 rows of it. The fix is a converted
/// column in the asset, which is an import change, not a UI change.
///
/// Matching and ordering live in `lib/utils/concordance_browse.dart`,
/// pure and under test. This file is layout, and holds
/// `workbench_theme.dart`'s rule: square corners, 1px hairlines, no
/// shadows, no cards.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/modern_concordance_service.dart';
import 'package:seeksparks/utils/concordance_browse.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/jump_to_reference.dart';
import 'package:seeksparks/utils/navigate_to_reader.dart';
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/wb_surfaces.dart';

class ModernConcordancePage extends StatefulWidget {
  const ModernConcordancePage({super.key, this.initialTopicId});

  /// Open straight onto a topic. Used by tests and by any future caller
  /// that already knows which topic it wants; the reader arriving from
  /// the Resources menu lands on the index.
  final int? initialTopicId;

  @override
  State<ModernConcordancePage> createState() => _ModernConcordancePageState();
}

class _ModernConcordancePageState extends State<ModernConcordancePage> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _indexScroll = ScrollController();

  List<ConcordanceTopic>? _topics;
  String _query = '';

  int? _openId;
  List<ConcordanceSection>? _sections;
  bool _sectionsLoading = false;

  /// Transliterations for the words on the open topic, filled in as the
  /// topic loads. `BDELUGMA` is the reason a reader can say the word at
  /// all — the asset carries Greek in a font this app does not ship for
  /// body text.
  final Map<String, String> _translit = <String, String>{};

  @override
  void initState() {
    super.initState();
    ModernConcordanceService.topics().then((t) {
      if (!mounted) return;
      setState(() => _topics = t);
      final id = widget.initialTopicId;
      if (id != null) _open(id);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _indexScroll.dispose();
    super.dispose();
  }

  String _s(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? fallback;

  /// English needs a singular and Chinese does not, but carries one
  /// anyway so a lookup never falls through to the English form. 62 of
  /// the 341 topics have exactly one section, so "1 sections" would be
  /// on screen for nearly a fifth of the work.
  String _sn(String key, String many, String one, int n, String locale) =>
      n == 1
          ? _s('${key}One', one, locale)
          : _s(key, many, locale).replaceAll('{n}', '$n');

  // ── Navigation ────────────────────────────────────────────────────

  void _open(int id) {
    setState(() {
      _openId = id;
      _sections = null;
      _sectionsLoading = true;
      _translit.clear();
    });
    ModernConcordanceService.sections(id).then((s) async {
      if (!mounted || _openId != id) return;
      // Transliterations are a second file. Pull them for the words on
      // this topic only — `greek.json` is 5,175 entries and a topic
      // uses a handful.
      for (final section in s) {
        for (final e in section.entries) {
          final t = await ModernConcordanceService.transliteration(e.strongs);
          if (t != null && t.isNotEmpty) _translit[e.strongs] = t;
        }
      }
      if (!mounted || _openId != id) return;
      setState(() {
        _sections = s;
        _sectionsLoading = false;
      });
    });
  }

  void _backToIndex() => setState(() {
        _openId = null;
        _sections = null;
        _sectionsLoading = false;
      });

  Future<void> _openRef(String englishBook, int chapter, int verse) async {
    final mp = context.read<MainProvider>();
    final result = await resolveAndPrepareJump(
      reference: BibleReference(
        englishBook: englishBook,
        chapter: chapter,
        verseStart: verse,
        verseEnd: verse,
      ),
      mp: mp,
    );
    if (!mounted) return;
    if (!await showJumpResultSnackBar(context, result)) return;
    if (!mounted) return;
    navigateToReader(context);
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final c = WbColors.of(context);
    final topics = _topics;

    return Scaffold(
      backgroundColor: c.paneBg,
      appBar: AppBar(
        leading: _openId == null
            ? const LocalizedBackButton()
            : BackButton(onPressed: _backToIndex),
        title: Text(_s('modernConcordanceTitle', 'Modern Concordance (NT)',
            locale)),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: topics == null
          ? const Center(child: CircularProgressIndicator())
          : topics.isEmpty
              ? _message(
                  c,
                  _s(
                    'modernConcordanceUnavailable',
                    'The Modern Concordance is not bundled in this build.',
                    locale,
                  ),
                )
              : _openId == null
                  ? _indexView(c, topics, locale)
                  : _topicView(c, topics, locale),
    );
  }

  // ── The index ─────────────────────────────────────────────────────

  Widget _indexView(WbColors c, List<ConcordanceTopic> topics, String locale) {
    final searching = _query.trim().isNotEmpty;
    final hits = searching
        ? matchTopics([for (final t in topics) (t.en, t.zh)], _query)
        : const <TopicHit>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: _searchField(c, locale),
        ),
        _countHeader(
          c,
          searching
              ? _sn('concordanceTopicsMatching', '{n} topics match',
                  '1 topic matches', hits.length, locale)
              : _s('concordanceTopicsAll', '{n} topics', locale)
                  .replaceAll('{n}', '${topics.length}'),
        ),
        Divider(height: WbMetrics.hairline, color: c.border),
        Expanded(
          child: searching
              ? (hits.isEmpty
                  ? _message(
                      c,
                      _s('concordanceNoTopic',
                              'No topic is named “{q}”.', locale)
                          .replaceAll('{q}', _query.trim()))
                  : _list(c, topics, locale,
                      [for (final h in hits) (topics[h.index], h)]))
              : _list(c, topics, locale,
                  [for (final t in topics) (t, null)]),
        ),
        _attribution(c),
      ],
    );
  }

  Widget _list(
    WbColors c,
    List<ConcordanceTopic> topics,
    String locale,
    List<(ConcordanceTopic, TopicHit?)> rows,
  ) {
    final t = WbType.of(context);
    return ListView.builder(
      controller: _indexScroll,
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (topic, hit) = rows[i];
        return _topicRow(c, t, topic, hit, locale);
      },
    );
  }

  Widget _topicRow(
    WbColors c,
    WbType t,
    ConcordanceTopic topic,
    TopicHit? hit,
    String locale,
  ) {
    final primary = topic.label(locale);
    // The name the reader did NOT type, shown only when the other column
    // is what answered. A Chinese reader who searched 爱 and got `Spare`
    // has no way to see why without 饶恕 beside it.
    final reading = locale.startsWith('zh');
    final other = reading ? topic.en : topic.zh;
    final showOther = hit != null &&
        other.isNotEmpty &&
        other != primary &&
        (reading
            ? hit.matched == TopicMatch.english
            : hit.matched == TopicMatch.chinese);

    return InkWell(
      onTap: () => _open(topic.id),
      hoverColor: c.hoverBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    primary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: t.text,
                      color: c.text,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                  if (showOther)
                    Text(
                      other,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: t.chrome,
                        color: c.mutedText,
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            WbTag(text: '${topic.sectionCount}', color: c.mutedText),
          ],
        ),
      ),
    );
  }

  Widget _searchField(WbColors c, String locale) {
    final t = WbType.of(context);
    return TextField(
      controller: _search,
      onChanged: (v) => setState(() => _query = v),
      style: TextStyle(
        fontSize: t.text,
        color: c.text,
        fontFamilyFallback: kCjkFontFallback,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: c.paneAltBg,
        hintText: _s('concordanceSearchHint',
            'Search topics — English or 中文', locale),
        hintStyle: TextStyle(
          fontSize: t.text,
          color: c.mutedText,
          fontFamilyFallback: kCjkFontFallback,
        ),
        prefixIcon: Icon(Icons.search, size: t.text + 3, color: c.mutedText),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 30, minHeight: 30),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, size: t.text + 1, color: c.mutedText),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c.border, width: WbMetrics.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c.border, width: WbMetrics.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c.text, width: WbMetrics.hairline),
        ),
      ),
    );
  }

  // ── One topic, unfiltered ─────────────────────────────────────────

  Widget _topicView(
      WbColors c, List<ConcordanceTopic> topics, String locale) {
    final t = WbType.of(context);
    final topic = topics.firstWhere((x) => x.id == _openId,
        orElse: () => topics.first);
    final sections = _sections;

    if (_sectionsLoading || sections == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final words = sections.fold<int>(0, (a, s) => a + s.entries.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.label(locale),
                style: TextStyle(
                  fontSize: t.text * 1.25,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
              // The name in the other language, always — on a topic page
              // it is not a search artefact, it is half the entry.
              Text(
                locale.startsWith('zh') ? topic.en : topic.zh,
                style: TextStyle(
                  fontSize: t.chrome,
                  color: c.mutedText,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ],
          ),
        ),
        _countHeader(
          c,
          _sn('concordanceSections', '{n} sections', '1 section',
              sections.length, locale),
        ),
        Divider(height: WbMetrics.hairline, color: c.border),
        Expanded(
          child: ListView.builder(
            itemCount: sections.length + 1,
            itemBuilder: (context, i) {
              if (i == sections.length) return _attribution(c);
              return _section(c, t, sections[i], locale);
            },
          ),
        ),
      ],
    ).withWordCountSemantics(words);
  }

  Widget _section(
      WbColors c, WbType t, ConcordanceSection section, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          color: c.chromeBg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            section.label(locale),
            style: TextStyle(
              fontSize: t.chrome,
              fontWeight: FontWeight.w700,
              color: c.mutedText,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
        ),
        for (final e in section.entries) _entry(c, t, e, locale),
      ],
    );
  }

  Widget _entry(
      WbColors c, WbType t, ConcordanceEntry e, String locale) {
    final translit = _translit[e.strongs];
    final nt = e.totals['nt'] ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WbTag(text: e.strongs, color: c.mutedText),
              const SizedBox(width: 6),
              if (translit != null)
                Expanded(
                  child: Text(
                    translit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: t.text,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (nt > 0)
                Text(
                  _sn('concordanceNtTotal', '{n}× in the NT', '1× in the NT',
                      nt, locale),
                  style: TextStyle(
                    fontSize: t.chrome,
                    color: c.mutedText,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              e.label(locale),
              style: TextStyle(
                fontSize: t.text,
                color: c.text,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
          ),
          // Every reference the concordance files under this word, each
          // one a jump. Uncapped: the longest list on the work is short
          // enough to print, and a capped list of references is a WHERE
          // clause the reader cannot see.
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (book, ch, v) in e.refs)
                WbTag(
                  text: '${localeAwareBookName(book, locale, context.read<MainProvider>().currentVersion)} $ch:$v',
                  color: c.mutedText,
                  onTap: () => _openRef(book, ch, v),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Chrome ────────────────────────────────────────────────────────

  Widget _countHeader(WbColors c, String text) {
    final t = WbType.of(context);
    return Container(
      width: double.infinity,
      color: c.chromeBg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: t.chrome,
          fontWeight: FontWeight.w700,
          color: c.mutedText,
          fontFamilyFallback: kCjkFontFallback,
        ),
      ),
    );
  }

  Widget _message(WbColors c, String text) {
    final t = WbType.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: t.text,
            color: c.mutedText,
            height: 1.5,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      ),
    );
  }

  /// The permission this data ships under is conditional on naming its
  /// source, so the credit travels with the page — the same rule as
  /// `naves_page.dart` and the Topics tab.
  Widget _attribution(WbColors c) {
    final t = WbType.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 20),
      child: Text(
        ModernConcordanceService.attribution,
        style: TextStyle(
          fontSize: t.chrome,
          height: 1.35,
          color: c.mutedText,
          fontFamilyFallback: kCjkFontFallback,
        ),
      ),
    );
  }
}

extension _Semantics on Widget {
  /// The word count is not drawn — the topic header already states the
  /// section count, and a second number beside it reads as noise. It is
  /// carried as a semantics label so a test (and a screen reader) can
  /// still ask how much of the topic arrived.
  Widget withWordCountSemantics(int words) =>
      Semantics(value: 'concordance-words:$words', child: this);
}
