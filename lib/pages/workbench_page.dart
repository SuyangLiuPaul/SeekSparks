import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show
        kSecondaryVersionKey,
        resolveSecondaryVersion,
        shortBibleVersionLabel;
import 'package:seeksparks/constants/app_version.dart'
    show kAppVersion, formatReleaseTimeLocal;
import 'package:seeksparks/constants/book_name_mapping.dart'
    show bookScriptFor, bookNameInScript;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/reader_analysis_request.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/models/wb_centre_mode.dart';
import 'package:seeksparks/pages/about_page.dart';
import 'package:seeksparks/pages/atlas_page.dart';
import 'package:seeksparks/pages/bible_timeline_page.dart';
import 'package:seeksparks/pages/bible_trivia_page.dart';
import 'package:seeksparks/pages/books_page.dart';
import 'package:seeksparks/pages/evidence_page.dart';
import 'package:seeksparks/pages/family_tree_page.dart';
import 'package:seeksparks/pages/hebrew_kings_page.dart';
import 'package:seeksparks/pages/illustrations_page.dart';
import 'package:seeksparks/pages/library_page.dart';
import 'package:seeksparks/pages/phrasing_page.dart';
import 'package:seeksparks/pages/sermon_detail_page.dart';
import 'package:seeksparks/pages/sermons_page.dart';
import 'package:seeksparks/pages/settings_page.dart';
import 'package:seeksparks/pages/word_list_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/fetch_books.dart';
import 'package:seeksparks/services/fetch_verses.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/workbench_warmup.dart'
    show
        defaultParallelVersions,
        kWorkbenchParallelModeKey,
        kWorkbenchParallelVersionsKey;
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/utils/morphology.dart' show describeMorphology;
import 'package:seeksparks/utils/workbench_fit.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/widgets/bible_reading_pane.dart';
import 'package:seeksparks/widgets/command_pane.dart';
import 'package:seeksparks/widgets/copy_center_sheet.dart'
    show CopyScope, showCopyCenter;
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:seeksparks/pages/strongs_entry_page.dart';
import 'package:seeksparks/utils/analysis_focus.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/utils/strongs_inline.dart';
import 'package:seeksparks/utils/search_highlight.dart';
import 'package:seeksparks/widgets/analysis_pin_bar.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/verse_list_pane.dart';
import 'package:seeksparks/utils/verse_list.dart' show VerseRef, verseListKeys;
import 'package:seeksparks/widgets/kwic_pane.dart';
import 'package:seeksparks/widgets/related_verses_pane.dart';
import 'package:seeksparks/widgets/phrase_match_pane.dart';
import 'package:seeksparks/widgets/vocabulary_pane.dart';
import 'package:seeksparks/widgets/morph_search_pane.dart';
import 'package:seeksparks/widgets/context_pane.dart';
import 'package:seeksparks/widgets/places_pane.dart';
import 'package:seeksparks/widgets/sermons_pane.dart';
import 'package:seeksparks/widgets/word_chart_view.dart';
import 'package:seeksparks/constants/book_groups.dart' show oldTestamentBooks;
import 'package:seeksparks/services/greek_stats_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/utils/search_scope.dart' show kScopeAllBooks;
import 'package:seeksparks/utils/search_stats.dart'
    show HitUnit, SearchDistribution, buildDistributionFromCounts;
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/browse_nav_strip.dart';
import 'package:seeksparks/widgets/browse_window.dart';
import 'package:seeksparks/widgets/word_analysis_pane.dart';
import 'package:seeksparks/utils/command_verb.dart'
    show CommandVerbIssue, describeVerbIssue;
import 'package:seeksparks/utils/search_scope.dart'
    show limitSpecForBooks, scopeDisplayName, wholeBookScope;
import 'package:seeksparks/widgets/search_scope_sheet.dart';
import 'package:seeksparks/widgets/version_stack_sheet.dart';
import 'package:seeksparks/widgets/workbench_chrome.dart';
import 'package:seeksparks/widgets/originals_sheet.dart';

/// SeekSparks' BibleWorks-style pad workspace — three panes on one
/// screen:
///
///   ┌────────────┬──────────────────────┬────────────────┐
///   │ Command    │ Bible reader         │ Analysis       │
///   │ line +     │ (BibleReadingPane,   │ (OriginalsSheet│
///   │ results    │  reused unchanged)   │  embedded)     │
///   └────────────┴──────────────────────┴────────────────┘
///
/// Wiring:
///  * Verse tap in the reader → MainProvider selection →
///    [WorkbenchProvider.analysisVerses] → the analysis pane updates
///    live (BibleWorks' mouseover-analysis, adapted to touch).
///  * Result tap in the command pane → the reader's pendingJump
///    handshake scrolls the center pane; the verse is also focused in
///    the analysis pane.
///
/// Layout rules (pad-first):
///  * ≥1024 px (iPad landscape / desktop): all three panes.
///  * 600–1023 px (iPad portrait): command + reader; analysis falls
///    back to the reader's existing sheet/docked presentation.
///  * <600 px: reader alone. Search there is the SAME command pane,
///    full screen — see `CommandSearchPage`.
///
/// Both side panes resize via their draggable divider (double-tap or
/// fling collapses), and widths/open-state persist in
/// SharedPreferences under `workbench_*` keys.
class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key});

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  static const String _kLeftWidthKey = 'workbench_left_width';
  static const String _kRightWidthKey = 'workbench_right_width';
  static const String _kLeftOpenKey = 'workbench_left_open';
  static const String _kRightOpenKey = 'workbench_right_open';

  static const double _defaultLeftWidth = 320;
  static const double _defaultRightWidth = 420;
  // 2026-08-07: 240 -> 224 and 320 -> 288 (right), in lockstep with
  // WorkbenchFit's pane minimums. These two files MUST agree: the gate
  // decides whether three columns fit and this decides how they are laid
  // out, so a divergence would admit a viewport the layout then
  // overflows. Trimmed 48 px total so the three-column minimum lands on
  // 1024 and a landscape iPad qualifies.
  //
  // 2026-08-08: right 288 -> 256, again in lockstep — see the reasoning
  // on `WorkbenchFit.analysisPaneMin`. The gate is now 992, which gives a
  // 1024 pt iPad 32 pt of slack instead of qualifying by exactly zero.
  static const double _minLeftWidth = 224;
  static const double _maxLeftWidth = 480;
  static const double _minRightWidth = 256;
  static const double _maxRightWidth = 560;
  static const double _dividerWidth = 16;

  /// Width of the rail shown in place of a collapsed pane. Named because
  /// the split-mode fit check has to subtract it.
  static const double _railWidth = 44;

  /// Does this width carry all three panes?
  ///
  /// 2026-08-08: this used to be `ResponsiveBreakpoints.isDesktopOrWider`,
  /// a hardcoded `w >= 1024` living in a THIRD file. That was fine only
  /// while the gate happened to be 1024 too. Moving the gate to 992
  /// exposed it: `SmallScreenGate` would have admitted a 992–1023 px
  /// viewport and this method would then have laid out two panes — the
  /// exact half-product the gate exists to keep off the screen, and a
  /// silent failure at that, since neither number is wrong on its own.
  ///
  /// So the workbench now asks `WorkbenchFit`, which owns the arithmetic.
  /// `ResponsiveBreakpoints.isDesktopOrWider` stays where it is for the
  /// reader and `open_reader`, where 1024 means something else.
  static bool _isThreePane(double width) =>
      width >= WorkbenchFit.threePaneMinWidth;

  /// Owns the workbench state. Created here (not globally in main.dart)
  /// so its MainProvider listener and search state only live while the
  /// workbench is open.
  late final WorkbenchProvider _wb;

  double _leftWidth = _defaultLeftWidth;
  double _rightWidth = _defaultRightWidth;
  bool _leftOpen = true;
  bool _rightOpen = true;

  // 2026-08 (SeekSparks): BibleWorks-style parallel Browse mode — when
  // on, the centre pane stacks the same verse in every selected version
  // plus the original-language line, instead of the chapter reader.
  //
  // 2026-08-07: the mode flag and the stack itself moved to
  // WorkbenchProvider, because the command line addresses them (`d nas`,
  // `p a b c`, bwh44) and the command line is this page's SIBLING, not
  // its child. The page keeps the persistence, which is its job.
  // Deliberately a NEW key. v1.1.0 defaulted this off and persisted the
  // value on any pane interaction, so every existing install had `false`
  // stored and never saw the Browse window even after it became the
  // default. Renaming re-applies the new default exactly once.
  // The key STRINGS live in workbench_warmup.dart: the boot warm-up has
  // to read the same values this page restores, and two copies of a key
  // drift without anything failing.
  static const _kParallelKey = kWorkbenchParallelModeKey;
  static const _kParallelVersionsKey = kWorkbenchParallelVersionsKey;
  static const _kCentreModeKey = kWorkbenchCentreModeKey;

  // ── Split mode: the second reading column ─────────────────────────
  //
  // Its own MainProvider, on its own storage prefix, because a second
  // column is a second *reading position* — its own edition, book,
  // chapter and scroll offset — and MainProvider is where all four
  // live. Sharing the primary's would make the two columns the same
  // column drawn twice.
  //
  // Created on entering split and disposed on leaving rather than
  // living for the page's lifetime: it holds a whole parsed edition
  // (7 MB for the reading version), and a reader who never opens split
  // should not carry one. The version cache underneath is shared, so
  // re-entering is cheap even though the provider is not kept.
  MainProvider? _secondary;

  /// True between asking for split and the second column being ready.
  /// The mode switches immediately and the column says it is loading,
  /// rather than the control appearing dead for the second or two a
  /// cold edition takes to arrive.
  bool _secondaryLoading = false;

  /// Fraction of the centre pane given to the first column.
  double _splitRatio = 0.5;

  /// The stack a first-time reader gets. BibleWorks ships version sets
  /// per language and this is the same idea: pair the reading version
  /// with the two most useful comparisons in that language.
  ///
  /// 2026-08-06: every stack now includes BSB, because it is the only
  /// English translation here that carries Strong's tagging. Before
  /// this the English stack was nasb/kjv/leb — none tagged — so adding
  /// a tagged English version would have changed nothing anyone could
  /// see. With BSB in the stack the English row does what the 和合本
  /// row already did: numbers on the words themselves.
  ///
  /// Only a default. It seeds the stack on first run and a
  /// reader's own selection is persisted over it.
  List<String> _defaultParallelVersions(String locale) =>
      defaultParallelVersions(locale);

  /// Which Analysis tab the right pane is showing. Persisted, because
  /// a reader who works in cross-references expects to still be there
  /// after a reload.
  AnalysisTab _analysisTab = AnalysisTab.wordStudy;
  static const _kAnalysisTabKey = 'workbench.analysisTab';

  /// Whether the reader has asked the Analysis strip for tab NAMES
  /// rather than letting it decide (task #297). Default off: twelve
  /// icons on one row is what the strip picks at the default pane width
  /// in every locale, and it is what the reader who asked for this
  /// toggle said they were happy with.
  bool _analysisTabLabels = false;
  static const _kAnalysisTabLabelsKey = 'workbench.analysisTabLabels';

  /// The Strong's number the distribution chart is drawn for, or null
  /// when the chart is not up. A second lens over the centre pane, on
  /// the same terms as the map: deliberately NOT persisted, because a
  /// reader who glanced at where λόγος falls should reopen tomorrow onto
  /// scripture rather than onto a bar chart.
  ///
  /// Held as the NUMBER rather than as the row that was tapped, so the
  /// chart survives the reader moving the verse underneath it — that is
  /// the whole reason #290 puts it here instead of leaving it in the
  /// 256 px pane it was opened from.
  String? _chartStrongs;

  void _openChart(String strongs) {
    if (strongs.isEmpty) return;
    setState(() => _chartStrongs = strongs);
  }

  void _closeChart() => setState(() => _chartStrongs = null);

  /// Hand the passage's places to the Atlas.
  ///
  /// The map used to be a lens over this pane. It is a Resources window
  /// now (DELETION-REVIEW §4): the verse-linked *list* stays here, where
  /// it costs the reader nothing, and the map opens as its own surface
  /// where it has the width to be a map. The places already loaded by
  /// the Places tab travel with the call, so the Atlas opens framed on
  /// the passage rather than on the whole ancient world.
  void _openAtlas(List<BiblePlace> places, String? focusId, String label) {
    pushPage(AtlasPage(
      subjectPlaces: places,
      subjectLabel: label.isEmpty ? null : label,
      initialPlaceId: focusId,
    ));
  }

  /// The search limit translated from reference keys into corpus
  /// indices, for the Phrase Matching pane.
  ///
  /// Cached on the identity of the key set it came from, and NOT
  /// recomputed per build. The pane treats a new `scope` object as a new
  /// question and rescans the whole Bible; handing it a freshly-built
  /// set every frame would rescan on every frame.
  Set<String>? _phraseScopeSource;
  List<Verse>? _phraseScopeVerses;
  Set<int>? _phraseScopeCache;

  /// What the mouse is over RIGHT NOW. Drives the status bar, which
  /// clears when the pointer leaves the text.
  BrowseHover? _hover;

  /// The word the Analysis window is showing. Unlike [_hover] this is
  /// sticky: BibleWorks keeps the last word up when the pointer leaves
  /// the text, so you can move the mouse onto the pane and read it.
  BrowseHover? _analysisWord;

  /// The occurrence the reader has COMMITTED to, or null.
  ///
  /// Hover is a preview and a click is a commitment. Until this was
  /// here, the Analysis pane's own content was unreachable: it filled
  /// with statistics about the word under the pointer, and the instant
  /// the reader moved toward the pane to read them, the pointer crossed
  /// the rest of the line and replaced the thing they were reaching
  /// for. The feature destroyed itself in the act of being used.
  ///
  /// A pin outlives navigation on purpose. Clicking a reference inside
  /// the Analysis pane moves the Browse window, and if that dropped the
  /// pin the pane would reset — the same defect wearing a hat. The key
  /// carries its book and chapter, so nothing on the new page can be
  /// mistaken for the pinned word; the pin bar is then the only visible
  /// trace of it, which is exactly why the bar is not optional.
  String? _pinnedKey;

  /// True while Shift is held. From the manual: "If you hold down the
  /// Shift key as you move the mouse cursor the content of the Word
  /// Analysis Window will not change." It is the brake that makes a
  /// pointer-driven readout usable — without it you cannot look away
  /// from the text without losing what you were reading about.
  bool _analysisFrozen = false;

  /// Focus for the command line, so View ▸ menu and Ctrl+L can jump to
  /// it the way a desktop tool's command line always can.
  final FocusNode _commandFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _wb = WorkbenchProvider(mainProvider: context.read<MainProvider>());
    _wb.onBrowseStateChanged = _persistPrefs;
    _restorePrefs();
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
  }

  /// Esc releases the pin; Ctrl/Cmd+Shift+C opens the Copy Center.
  ///
  /// Shift is what keeps the Copy Center off plain Ctrl+C. The browser's
  /// own copy is the right tool for a selection the reader has already
  /// made with the mouse, and taking that key away would break it
  /// everywhere in the page for the sake of one dialog.
  ///
  /// A global handler rather than a `Shortcuts` wrapper because Flutter
  /// routes key events from the focused node upward: with nothing
  /// focused — the normal state of a pane you drive with the mouse —
  /// an ancestor `Shortcuts` never sees the key at all, so the one
  /// escape hatch would work only after the reader had clicked into the
  /// command line. Guarded on the route being current so a pushed page
  /// or a dialog keeps its own Esc, and it always returns false: this
  /// observes the key, it does not consume it.
  bool _onGlobalKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    final keys = HardwareKeyboard.instance;
    if (e.logicalKey == LogicalKeyboardKey.keyC &&
        keys.isShiftPressed &&
        (keys.isControlPressed || keys.isMetaPressed)) {
      _openCopyCenter();
      return true;
    }

    if (e.logicalKey != LogicalKeyboardKey.escape) return false;
    if (_pinnedKey == null) return false;
    _unpin();
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    _commandFocus.dispose();
    _closeSecondColumn(notify: false);
    _wb.dispose();
    super.dispose();
  }

  // ── Menu bar / toolbar / status bar ───────────────────────────────

  /// The menu bar. Every entry is wired to something real; a capability
  /// we don't have is left out rather than stubbed, and one we have but
  /// can't use right now is present-and-greyed (a null callback), which
  /// is how a desktop menu communicates state.
  List<WbMenu> _buildMenus(BuildContext context, String locale) {
    final mp = context.read<MainProvider>();
    final settings = context.read<AppSettings>();
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;
    final splitFits =
        splitFitsIn(_paneWidths(MediaQuery.sizeOf(context).width).centre);

    return [
      WbMenu(s('menuFile', 'File'), [
        WbMenuItem(
          s('copyCenterMenu', 'Copy…'),
          _copyScopes(locale).isEmpty ? null : _openCopyCenter,
          shortcut: 'Ctrl+Shift+C',
        ),
        const WbMenuItem.separator(),
        WbMenuItem(s('settings', 'Settings…'),
            () => pushPage(const SettingsPage())),
        // "Exit to reader" used to sit here and replace the whole route
        // with HomePage. There is nothing left to exit to: the reader is
        // the centre pane in three arrangements (View menu, below), and
        // leaving meant losing the command line, the search results and
        // the Analysis pane in order to reach a surface the centre pane
        // was already showing.
      ]),
      WbMenu(s('menuView', 'View'), [
        WbMenuItem(
          s('menuSearchWindow', 'Search window'),
          () => _setLeftOpen(!_leftOpen),
          checked: _leftOpen,
        ),
        WbMenuItem(
          s('menuAnalysisWindow', 'Analysis window'),
          () => _setRightOpen(!_rightOpen),
          checked: _rightOpen,
        ),
        const WbMenuItem.separator(),
        WbMenuItem(
          s('parallelBrowse', 'Browse (parallel versions)'),
          () => _setCentreMode(WbCentreMode.browse),
          checked: _wb.centreMode == WbCentreMode.browse,
        ),
        WbMenuItem(
          s('classicReader', 'Chapter reader'),
          () => _setCentreMode(WbCentreMode.reader),
          checked: _wb.centreMode == WbCentreMode.reader,
        ),
        // Greyed rather than hidden when the centre is too narrow, with
        // the reason in the accelerator column — because the fix is one
        // the reader can act on (close the Analysis pane), and a control
        // that vanishes teaches them nothing.
        WbMenuItem(
          s('splitView', 'Split (two editions side by side)'),
          splitFits ? () => _setCentreMode(WbCentreMode.split) : null,
          checked: _wb.centreMode == WbCentreMode.split,
          shortcut: splitFits ? null : s('splitNeedsWidth', 'needs more width'),
        ),
        const WbMenuItem.separator(),
        WbMenuItem(s('parallelPickVersions', 'Choose versions…'),
            () => _pickParallelVersions(context)),
        const WbMenuItem.separator(),
        WbMenuItem(
          s('menuDarkMode', 'Dark mode'),
          () => settings.setThemeMode(
              settings.themeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark),
          checked: Theme.of(context).brightness == Brightness.dark,
        ),
      ]),
      WbMenu(s('search', 'Search'), [
        WbMenuItem(s('menuFocusCommandLine', 'Command line'), _focusCommandLine,
            shortcut: 'Ctrl+L'),
        // bwh29 reaches the limits window from the Search menu, the
        // command line and the status bar. Until now this app had only
        // the command line, so the scope was a documented feature with
        // no way in.
        WbMenuItem(
          s('scopeMenu', 'Search scope…'),
          () => _openScopeSheet(),
          checked: _wb.hasSearchLimit,
        ),
        const WbMenuItem.separator(),
        // Greyed until there is something to clear — the menu reports
        // state rather than silently doing nothing.
        WbMenuItem(
          s('menuClearResults', 'Clear results'),
          _wb.textResults.isEmpty && _wb.strongsRefs == null
              ? null
              : _wb.clearResults,
        ),
      ]),
      WbMenu(s('menuTools', 'Tools'), [
        WbMenuItem(
          s('wordListTitle', 'Word List'),
          () => pushPage(WordListPage(
            book: mp.currentBook ?? '',
            chapter: mp.currentChapter ?? 1,
            locale: locale,
            version: mp.currentVersion,
          )),
        ),
        WbMenuItem(
          s('phrasingTitle', 'Phrasing'),
          () => pushPage(PhrasingPage(
            book: mp.currentBook ?? '',
            chapter: mp.currentChapter ?? 1,
            verse: mp.currentVerse?.verse ?? 1,
            locale: locale,
            version: mp.currentVersion,
          )),
        ),
        WbMenuItem(s('bibleEvidence', 'Bible Evidence'),
            () => pushPage(const EvidencePage())),
        WbMenuItem(s('timeline', 'Timeline'),
            () => pushPage(const BibleTimelinePage())),
        WbMenuItem(s('trivia', 'Trivia'),
            () => pushPage(const BibleTriviaPage())),
      ]),
      WbMenu(s('menuResources', 'Resources'), [
        WbMenuItem(s('sermons', 'Sermons'),
            () => pushPage(const SermonsPage())),
        // Resources, not Tools: bwh07 splits the two on whether the
        // item OPERATES on the current text (Word List, KWIC, Phrase
        // Matching) or is a reference database you CONSULT (maps,
        // dictionaries, commentaries, the Bible Views picture set).
        // `assets/family_tree.json` is the second kind, and bwh07 files
        // the map module here too — which is the whole argument for the
        // Atlas being a window rather than a lens over the reader.
        WbMenuItem(s('atlasTitle', 'Bible Atlas'),
            () => pushPage(const AtlasPage())),
        // The "Bible Views picture set" named above is the one entry
        // bwh07 stops to describe, and ours had no door: 1,192 plates
        // reachable only by already reading a chapter that matched one.
        WbMenuItem(s('maps', 'Illustrations'),
            () => pushPage(const IllustrationsPage())),
        WbMenuItem(s('familyTree', 'Family Tree'),
            () => pushPage(const FamilyTreePage())),
        // Separate from Family Tree on purpose: the tree is Judah's line
        // of descent, this is both thrones on one time axis.
        WbMenuItem(s('hebrewKings', 'Kings of Judah & Israel'),
            () => pushPage(const HebrewKingsPage())),
        WbMenuItem(s('library', 'Notes & highlights'),
            () => pushPage(const LibraryPage())),
        WbMenuItem(
          s('books', 'Go to book…'),
          () => pushPage(BooksPage(
            bookIdx: mp.currentBook ?? '',
            chapterIdx: mp.currentChapter ?? 1,
          )),
        ),
      ]),
      WbMenu(s('menuHelp', 'Help'), [
        WbMenuItem(s('about', 'About & data sources'),
            () => pushPage(const AboutPage())),
        const WbMenuItem.separator(),
        WbMenuItem(
            '${shortBibleVersionLabel(mp.currentVersion)} · v$kAppVersion',
            null),
      ]),
    ];
  }

  List<List<WbToolButton>> _buildToolbar(BuildContext context) {
    final locale = context.read<AppSettings>().locale;
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;
    return [
      [
        WbToolButton(
          icon: Icons.vertical_split_outlined,
          tooltip: s('menuSearchWindow', 'Search window'),
          active: _leftOpen,
          onPressed: () => _setLeftOpen(!_leftOpen),
        ),
        WbToolButton(
          icon: Icons.analytics_outlined,
          tooltip: s('menuAnalysisWindow', 'Analysis window'),
          active: _rightOpen,
          onPressed: () => _setRightOpen(!_rightOpen),
        ),
      ],
      [
        // Labelled, unlike every other toolbar button: this is the one
        // switch a reader can get stuck on the wrong side of, and two
        // unlabelled book glyphs gave no clue which way was back.
        WbToolButton(
          icon: Icons.view_agenda_outlined,
          label: s('parallelBrowseShort', 'Browse'),
          tooltip: s('parallelBrowse', 'Browse (parallel versions)'),
          active: _wb.centreMode == WbCentreMode.browse,
          onPressed: () => _setCentreMode(WbCentreMode.browse),
        ),
        WbToolButton(
          icon: Icons.menu_book_outlined,
          label: s('classicReaderShort', 'Reader'),
          tooltip: s('classicReader', 'Chapter reader'),
          active: _wb.centreMode == WbCentreMode.reader,
          onPressed: () => _setCentreMode(WbCentreMode.reader),
        ),
        // Absent rather than greyed on a narrow window, because a third
        // LABELLED button is what pushes this toolbar past the width it
        // has on a small screen — and the View menu already carries the
        // greyed version with the reason attached.
        if (splitFitsIn(_paneWidths(MediaQuery.sizeOf(context).width).centre))
          WbToolButton(
            icon: Icons.vertical_split_outlined,
            label: s('splitViewShort', 'Split'),
            tooltip: s('splitView', 'Split (two editions side by side)'),
            active: _wb.centreMode == WbCentreMode.split,
            onPressed: () => _setCentreMode(WbCentreMode.split),
          ),
        WbToolButton(
          icon: Icons.view_column_outlined,
          tooltip: s('parallelPickVersions', 'Choose versions'),
          onPressed: () => _pickParallelVersions(context),
        ),
      ],
      [
        WbToolButton(
          icon: Icons.search,
          tooltip: s('menuFocusCommandLine', 'Command line'),
          onPressed: _focusCommandLine,
        ),
        WbToolButton(
          icon: Icons.copy_all_outlined,
          tooltip: s('copyCenterTitle', 'Copy Center'),
          onPressed: _openCopyCenter,
        ),
        WbToolButton(
          icon: Icons.settings_outlined,
          tooltip: s('settings', 'Settings'),
          onPressed: () => pushPage(const SettingsPage()),
        ),
      ],
    ];
  }

  // ── Copy Center ───────────────────────────────────────────────────

  /// What "copy this" could reasonably mean right now, narrowest first.
  ///
  /// Built fresh on every menu build so the File menu can grey the entry
  /// when the answer is "nothing" — a reader who has not opened a
  /// chapter yet should be told there is nothing to copy by the menu,
  /// not by an empty dialog.
  List<CopyScope> _copyScopes(String locale) {
    final mp = context.read<MainProvider>();
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;
    VerseRef refOf(Verse v) =>
        VerseRef(bookNameToEnglish[v.book] ?? v.book, v.chapter, v.verse);

    final scopes = <CopyScope>[];
    final selected = mp.selectedVerses;
    if (selected.isNotEmpty) {
      scopes.add(CopyScope(
        label: s('copyScopeSelection', 'Selected verses'),
        refs: [for (final v in selected) refOf(v)],
      ));
    } else if (mp.currentVerse != null) {
      scopes.add(CopyScope(
        label: s('copyScopeVerse', 'Current verse'),
        refs: [refOf(mp.currentVerse!)],
      ));
    }
    final book = mp.currentBook;
    final chapter = mp.currentChapter;
    if (book != null && chapter != null) {
      final inChapter = mp.versesInChapter(book, chapter);
      if (inChapter.isNotEmpty) {
        scopes.add(CopyScope(
          label: s('copyScopeChapter', 'This chapter'),
          refs: [for (final v in inChapter) refOf(v)],
        ));
      }
    }
    final results = _searchResultRefs(_wb);
    if (results.isNotEmpty) {
      scopes.add(CopyScope(
        label: s('copyScopeResults', 'Search results'),
        refs: results,
      ));
    }
    return scopes;
  }

  Future<void> _openCopyCenter() async {
    final locale = context.read<AppSettings>().locale;
    final scopes = _copyScopes(locale);
    if (scopes.isEmpty) return;
    final text = await showCopyCenter(
      context,
      scopes: scopes,
      primaryVersion: context.read<MainProvider>().currentVersion,
    );
    if (text == null || !mounted) return;
    await ClipboardHelper.copyWithFeedback(context, text);
  }

  /// The status bar's left-hand readout: whatever the mouse is over.
  /// This is why BibleWorks can be read with the mouse — you never open
  /// a dialog to find out what a word is.
  String _statusMessage(String locale) {
    final h = _hover;
    if (h == null) return '';
    final w = h.word;
    if (w == null) return h.reference;
    final parse = describeMorphology(w.morph, locale);
    return [
      h.reference,
      w.text,
      w.strongs,
      if (parse != null && parse.isNotEmpty) parse,
    ].join('   ');
  }

  /// The status bar's right-hand readouts. Every one is a control:
  /// BibleWorks changes options by double-clicking them here and greys
  /// the ones that are off. Shipping them as plain labels threw away a
  /// whole row of affordances for nothing.
  List<WbStatusField> _statusFields(MainProvider mp, String locale) {
    final settings = context.read<AppSettings>();
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;
    final book = mp.currentBook;
    final chapter = mp.currentChapter;

    return [
      if (book != null && chapter != null)
        WbStatusField(
          '${localeAwareBookName(bookNameToEnglish[book] ?? book, locale, mp.currentVersion)} $chapter',
          onTap: () =>
              pushPage(BooksPage(bookIdx: book, chapterIdx: chapter)),
        ),
      WbStatusField(
        shortBibleVersionLabel(mp.currentVersion),
        onTap: () => _pickParallelVersions(context),
      ),
      // Names the centre mode, and cycles it on tap.
      //
      // Deliberately the EFFECTIVE mode, not the stored preference. A
      // reader who chose split and then narrowed the window is looking
      // at one column; labelling that "Split" would make the one field
      // whose whole job is to say what is on screen the only one that
      // lies. The preference itself is untouched and comes back when
      // the room does.
      WbStatusField(
        switch (effectiveCentreMode(
          preferred: _wb.centreMode,
          centreWidth: _paneWidths(MediaQuery.sizeOf(context).width).centre,
          threePane: _isThreePane(MediaQuery.sizeOf(context).width),
        )) {
          WbCentreMode.browse => s('parallelBrowseShort', 'Browse'),
          WbCentreMode.reader => s('classicReaderShort', 'Reader'),
          WbCentreMode.split => s('splitViewShort', 'Split'),
        },
        onTap: () => _setCentreMode(_nextCentreMode()),
      ),
      // bwh12's Limits field, including the reason it exists: "you may
      // have forgotten that you have search limits set." Greyed when
      // nothing is limiting, and it names the scope when something is,
      // so a narrowed result set can never be a silent one.
      WbStatusField(
        _wb.hasSearchLimit
            ? '${s('scopeStatusField', 'Limits')}: '
                '${scopeDisplayName(
                spec: _wb.searchLimitSpec,
                fallbackLabel: _wb.searchLimitLabel,
                locale: locale,
                version: mp.currentVersion,
                maxNames: 1,
              )}'
            : s('scopeStatusField', 'Limits'),
        enabled: _wb.hasSearchLimit,
        onTap: _openScopeSheet,
      ),
      WbStatusField(
        "Strong's",
        enabled: settings.showStrongsInOriginals,
        onTap: () => settings
            .setShowStrongsInOriginals(!settings.showStrongsInOriginals),
      ),
      WbStatusField(
        s('menuAnalysisWindow', 'Analysis'),
        enabled: _rightOpen,
        onTap: () => _setRightOpen(!_rightOpen),
      ),
      // Which build you are actually looking at, and when it shipped —
      // rendered in the reader's OWN timezone, not the build machine's.
      // Same place BibleWorks keeps its build info: the status bar.
      WbStatusField(
        'v$kAppVersion · ${formatReleaseTimeLocal()}',
        onTap: () => pushPage(const AboutPage()),
      ),
    ];
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _leftWidth = (prefs.getDouble(_kLeftWidthKey) ?? _defaultLeftWidth)
          .clamp(_minLeftWidth, _maxLeftWidth)
          .toDouble();
      _rightWidth = (prefs.getDouble(_kRightWidthKey) ?? _defaultRightWidth)
          .clamp(_minRightWidth, _maxRightWidth)
          .toDouble();
      _leftOpen = prefs.getBool(_kLeftOpenKey) ?? true;
      _rightOpen = prefs.getBool(_kRightOpenKey) ?? true;
      // Assigned rather than set: the setters call back into
      // _persistPrefs, and restoring is not a change worth writing back.
      _wb.centreMode = resolveCentreMode(
        stored: prefs.getString(_kCentreModeKey),
        legacyParallel: prefs.getBool(_kParallelKey),
      );
      final saved = prefs.getStringList(_kParallelVersionsKey);
      _wb.parallelVersions = (saved != null && saved.isNotEmpty)
          ? saved
          : _defaultParallelVersions(context.read<AppSettings>().locale);
      final tab = prefs.getInt(_kAnalysisTabKey);
      if (tab != null && tab >= 0 && tab < AnalysisTab.values.length) {
        _analysisTab = AnalysisTab.values[tab];
      }
      _analysisTabLabels = prefs.getBool(_kAnalysisTabLabelsKey) ?? false;
    });
    if (_wb.centreMode == WbCentreMode.split) _openSecondColumn();
  }

  Future<void> _persistPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLeftWidthKey, _leftWidth);
    await prefs.setDouble(_kRightWidthKey, _rightWidth);
    await prefs.setBool(_kLeftOpenKey, _leftOpen);
    await prefs.setBool(_kRightOpenKey, _rightOpen);
    await prefs.setString(_kCentreModeKey, centreModeToStorage(_wb.centreMode));
    await prefs.setStringList(_kParallelVersionsKey, _wb.parallelVersions);
    await prefs.setInt(_kAnalysisTabKey, _analysisTab.index);
    await prefs.setBool(_kAnalysisTabLabelsKey, _analysisTabLabels);
  }

  // ── Pane geometry ─────────────────────────────────────────────────

  /// How the window's width is divided right now.
  ///
  /// One function rather than the same arithmetic in the layout and
  /// again wherever a control asks "does split fit?". Two copies would
  /// let the View menu offer a mode the layout then refuses, which is
  /// the exact failure the small-screen advisory shipped with in
  /// v1.6.17: a control that promises something the layout will not
  /// honour is worse than one that is simply absent.
  ({double left, double right, double centre}) _paneWidths(double width) {
    final threePane = _isThreePane(width);
    final showLeft = _leftOpen && width >= 600;
    final showRight = _rightOpen && threePane;
    // Cap side panes at 32% of the total width each so the reader never
    // gets squeezed to nothing on a just-barely-desktop screen (e.g.
    // iPad Pro 11" portrait = 1024).
    final maxSide = width * 0.32;
    final left =
        showLeft ? (_leftWidth > maxSide ? maxSide : _leftWidth) : 0.0;
    final right =
        showRight ? (_rightWidth > maxSide ? maxSide : _rightWidth) : 0.0;
    // Everything between the centre and the window edges that is not a
    // side pane: a divider where a pane is open, a collapsed rail where
    // one is closed.
    final gutters =
        (showLeft ? _dividerWidth : (width >= 600 ? _railWidth : 0.0)) +
            (showRight ? _dividerWidth : (threePane ? _railWidth : 0.0));
    return (left: left, right: right, centre: width - left - right - gutters);
  }

  // ── Centre-pane mode ──────────────────────────────────────────────

  /// The next centre mode in the status-bar cycle, skipping any that
  /// the current window cannot render.
  WbCentreMode _nextCentreMode() {
    final width = MediaQuery.sizeOf(context).width;
    final threePane = _isThreePane(width);
    final centre = _paneWidths(width).centre;
    final order = [
      WbCentreMode.browse,
      WbCentreMode.reader,
      if (splitFitsIn(centre)) WbCentreMode.split,
    ]..removeWhere((m) => m == WbCentreMode.browse && !threePane);
    // Cycle from what is on screen, not from what is stored. They differ
    // exactly when a saved mode does not fit, and starting from the
    // stored one would step off a mode the reader cannot see — and would
    // return -1 here, silently restarting the cycle from the top.
    final showing = effectiveCentreMode(
      preferred: _wb.centreMode,
      centreWidth: centre,
      threePane: threePane,
    );
    final at = order.indexOf(showing);
    return order[(at + 1) % order.length];
  }

  /// Switch what the centre pane shows, and bring the second reading
  /// column into or out of existence with it.
  void _setCentreMode(WbCentreMode mode) {
    // Asking for a text mode is asking to see text. Without this, picking
    // "Reader" while the chart lens is up appears to do nothing, because
    // the lens sits in front of whichever mode is underneath.
    if (_chartStrongs != null) {
      setState(() => _chartStrongs = null);
    }
    if (_wb.centreMode == mode) return;
    final wasSplit = _wb.centreMode == WbCentreMode.split;
    _wb.setCentreMode(mode); // notifies; _persistPrefs runs off the callback
    if (mode == WbCentreMode.split) {
      _openSecondColumn();
    } else if (wasSplit) {
      _closeSecondColumn();
    }
  }

  /// Bring up the second reading column: its own provider, seeded with
  /// a DIFFERENT edition and pointed at the passage the first column is
  /// already showing.
  Future<void> _openSecondColumn() async {
    if (_secondary != null || _secondaryLoading) return;
    final primary = _wb.mainProvider;
    setState(() => _secondaryLoading = true);

    final sp = MainProvider(storagePrefix: 'secondary_');
    final prefs = await SharedPreferences.getInstance();
    sp.currentVersion = resolveSecondaryVersion(
      primaryVersion: primary.currentVersion,
      stored: prefs.getString(kSecondaryVersionKey),
    );
    await FetchVerses.execute(mainProvider: sp);
    await FetchBooks.execute(mainProvider: sp);
    await sp.reloadHighlights();

    // Left split while it was loading — the column is no longer wanted,
    // and a provider nobody will mount has to be disposed here or it
    // leaks its listener along with the edition it just parsed.
    if (!mounted || _wb.centreMode != WbCentreMode.split) {
      sp.dispose();
      if (mounted) setState(() => _secondaryLoading = false);
      return;
    }

    // A highlight is a note about a VERSE, not about an edition, so
    // marking one in either column has to show in the other — otherwise
    // the same verse is highlighted on the left and plain on the right.
    primary.onHighlightsMutated = () => _secondary?.syncHighlights(primary.highlights);
    sp.onHighlightsMutated = () => primary.syncHighlights(sp.highlights);

    setState(() {
      _secondary = sp;
      _secondaryLoading = false;
    });
    _followPrimary();
    primary.addListener(_followPrimary);
  }

  /// Tear the second column down. [notify] is false from `dispose`,
  /// where a `setState` would run against a State on its way out.
  void _closeSecondColumn({bool notify = true}) {
    final sp = _secondary;
    if (sp == null) return;
    _secondary = null;
    _wb.mainProvider.removeListener(_followPrimary);
    _wb.mainProvider.onHighlightsMutated = null;
    sp.dispose();
    if (notify) setState(() {});
  }

  /// Keep the second column on the same passage as the first.
  ///
  /// BibleWorks' Parallel Versions Window moves its columns "in unison"
  /// (bwh38) and the Workbench has a stronger reason to: the command
  /// line, the search results and every cross-reference all address ONE
  /// reference, and a second column that ignored them would show the
  /// wrong chapter the moment the reader typed anything.
  ///
  /// Chapter granularity on purpose. Scroll stays independent inside the
  /// chapter, which is the whole point of columns over interleaved rows
  /// — where the two editions disagree about verse boundaries, the
  /// reader aligns them by eye and a scroll-linked column would fight
  /// them for it.
  void _followPrimary() {
    final sp = _secondary;
    if (sp == null) return;
    final primary = _wb.mainProvider;
    final localBook = primary.currentBook;
    final chapter = primary.currentChapter;
    if (localBook == null || chapter == null) return;

    // Matched in English, never on the raw strings. `Verse.book` carries
    // the name the EDITION uses — 创世记 in a Chinese text, Genesis in an
    // English one (v1.6.47) — so comparing them directly across two
    // columns matches nothing whenever the columns are in different
    // languages, which is the normal case: `defaultSecondaryVersion`
    // exists precisely to make the two columns differ.
    final book = bookNameToEnglish[localBook] ?? localBook;
    if ((bookNameToEnglish[sp.currentBook] ?? sp.currentBook) == book &&
        sp.currentChapter == chapter) {
      return;
    }
    final match = sp.verses
        .where((v) =>
            (bookNameToEnglish[v.book] ?? v.book) == book &&
            v.chapter == chapter)
        .toList();
    // The editions can disagree about what exists — a chapter one of
    // them numbers differently, or a book it does not carry. Leaving the
    // column where it was beats blanking it.
    if (match.isEmpty) return;
    sp.setCurrentChapter(book: match.first.book, chapter: chapter);
    sp.updateCurrentVerse(verse: match.first);
  }

  // ── Pane open/collapse ────────────────────────────────────────────

  void _setLeftOpen(bool open) {
    setState(() => _leftOpen = open);
    _persistPrefs();
  }

  /// Every "search" affordance in the workspace lands here — the
  /// toolbar button, the Search menu, and `/` or ⌘F inside the centre
  /// reader. There is one command line and this puts the caret in it.
  /// A collapsed left pane has no [CommandPane] mounted yet, so the
  /// focus request waits for the frame that builds it.
  void _focusCommandLine() {
    if (_leftOpen) {
      _commandFocus.requestFocus();
      return;
    }
    _setLeftOpen(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _commandFocus.requestFocus();
    });
  }

  void _setRightOpen(bool open) {
    setState(() => _rightOpen = open);
    _persistPrefs();
  }

  // ── Analysis-pane concordance navigation ─────────────────────────
  // Tapping a concordance ref inside the embedded OriginalsSheet jumps
  // the CENTER reader (pendingJump handshake — same page, no route
  // change) and focuses the verse so the pane follows along.
  void _onAnalysisNavigateRef(ConcordanceRef ref) {
    final verse = _wb.verseForRef(ref);
    if (verse == null) return;
    jumper.prepareJumpToVerse(verse, _wb.mainProvider);
    _wb.focusVerse(verse);
  }

  /// Same handshake for a cross-reference, which carries a
  /// [BibleReference] (a range) rather than a concordance hit. A
  /// chapter-only reference lands on verse 1.
  void _onCrossRefTap(BibleReference ref) {
    final verse =
        _wb.verseByRef['${ref.englishBook}-${ref.chapter}-${ref.verseStart ?? 1}'];
    if (verse == null) return;
    jumper.prepareJumpToVerse(verse, _wb.mainProvider);
    _wb.focusVerse(verse);
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // The Workbench runs on its own dense, neutral theme. The rest of
    // SeekSparks stays a touch-first reading app; putting BibleWorks'
    // three windows inside Material 3 chrome is what made this read as
    // "a phone app in three columns".
    //
    // 2026-08: 护眼纸质 reaches the workbench now. The reader's paper
    // theme used to stop at BibleReadingPane's content subtree, so the
    // panes/chrome/Browse window stayed on the neutral desktop palette
    // and a paper-mode reader got a cream square in a grey workspace.
    // Watching the setting here rebuilds the whole Theme whenever it
    // flips, so the new palette flows through every WbColors.of context
    // at once.
    final paper = context.watch<AppSettings>().readingPaperTheme;
    return Theme(
      data: workbenchTheme(Theme.of(context), paper: paper),
      child: ChangeNotifierProvider<WorkbenchProvider>.value(
        value: _wb,
        child: Builder(
          builder: (context) => _buildShell(context),
        ),
      ),
    );
  }

  Widget _buildShell(BuildContext context) {
    final wb = WbColors.of(context);
    final mp = context.watch<MainProvider>();
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    // The Browse-mode checkmarks in the menu bar, the toolbar and the
    // status bar all read the provider now, and the command line can
    // change it (`p`, `d nas`) without this page hearing about it any
    // other way.
    context.watch<WorkbenchProvider>();

    // The menu bar and toolbar are desktop affordances: six menu titles
    // plus a version label do not fit a phone, and trying overflowed the
    // Row (the responsive smoke tests caught it at 390 and 768). Below
    // the three-pane breakpoint the workspace keeps only the status bar,
    // and every menu action stays reachable from the reader's own
    // controls.
    final width = MediaQuery.sizeOf(context).width;
    // 2026-08-06: the chrome is present at EVERY width now. Hiding it
    // below 1024 was what made a phone look like a different app — same
    // codebase, but no menu bar, no status bar, nothing identifying the
    // workspace. The bars are 22px and 20px and scale with Menu Size, so
    // they cost little; what they buy is that a phone reads as the same
    // tool with its side panes collapsed, which is the point.
    //
    // `compact` trims what goes IN the bars rather than removing them:
    // the full six-field status line and the whole menu row do not fit
    // in 390px, and an overflowing bar is worse than a shorter one.
    final compact = !_isThreePane(width);

    return Scaffold(
      backgroundColor: wb.chromeBg,
      body: SafeArea(
        child: Column(
          children: [
            ...[
              WorkbenchMenuBar(
                menus: _buildMenus(context, locale),
                // The language switcher only. The build label used to sit
                // here too, above 1200 px, and printed the same version
                // the status bar prints at every width (#314). The status
                // bar keeps it because it is TAPPABLE — it opens About —
                // where this was inert text; and the menu titles get the
                // width back.
                trailing: const SizedBox(
                  height: 26,
                  child: LanguageSwitcherButton(dense: true),
                ),
              ),
              WorkbenchToolbar(groups: _buildToolbar(context)),
            ],
            Expanded(child: _buildPanes(context)),
            WorkbenchStatusBar(
              message: _statusMessage(locale),
              // Reference and version only on a phone — the rest
              // (Browse/Strong's/Analysis state) is desktop detail.
              fields: compact
                  ? _statusFields(mp, locale).take(2).toList()
                  : _statusFields(mp, locale),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanes(BuildContext context) {
    return Builder(
      builder: (context) {
          final width = MediaQuery.sizeOf(context).width;
          final threePane = _isThreePane(width);
          final showLeft = _leftOpen && width >= 600;
          final showRight = _rightOpen && threePane;
          final panes = _paneWidths(width);
          final leftW = panes.left;
          final rightW = panes.right;

          return ColoredBox(
            color: WbColors.of(context).chromeBg,
            child: Row(
                children: [
                  if (showLeft) ...[
                    SizedBox(
                        width: leftW,
                        child: _buildCommandFrame(context)),
                    _buildDivider(context,
                        key: const ValueKey('workbench-divider-left'),
                        isLeft: true),
                  ] else if (width >= 600) ...[
                    _buildCollapsedRail(context,
                        key: const ValueKey('workbench-rail-left'),
                        isLeft: true),
                  ],
                  Expanded(
                    // A persisted mode is a wish, not an instruction:
                    // Browse needs the three-pane width before three
                    // editions of a verse stop reading as fragments,
                    // split needs two reading columns, and where neither
                    // holds the chapter reader always does. The
                    // preference is kept for the next screen that can
                    // honour it — see `effectiveCentreMode`.
                    child: _chartStrongs != null
                        ? _buildChartFrame(context, _chartStrongs!)
                        : switch (effectiveCentreMode(
                            preferred:
                                context.watch<WorkbenchProvider>().centreMode,
                            centreWidth: panes.centre,
                            threePane: threePane,
                          )) {
                            WbCentreMode.browse => _buildParallelFrame(context),
                            WbCentreMode.split => _buildSplitFrame(context),
                            WbCentreMode.reader => _buildReaderFrame(context,
                                splitAvailable: splitFitsIn(panes.centre),
                                analysisAvailable: threePane),
                          },
                  ),
                  if (showRight) ...[
                    _buildDivider(context,
                        key: const ValueKey('workbench-divider-right'),
                        isLeft: false),
                    SizedBox(
                        width: rightW,
                        child: _buildAnalysisFrame(context)),
                  ] else if (threePane) ...[
                    _buildCollapsedRail(context,
                        key: const ValueKey('workbench-rail-right'),
                        isLeft: false),
                  ],
                ],
            ),
          );
        },
      );
  }

  // ── Centre: the chapter reader ────────────────────────────────────

  /// One edition, the whole chapter, running continuously — BibleWorks'
  /// Single Version Browse Mode (bwh11), and the only centre mode that
  /// fits at every width.
  ///
  /// [splitAvailable] hides rather than greys the pane's own split
  /// entry. This popup has no room to say *why* something is
  /// unavailable, and an item that does nothing when tapped is worse
  /// than one that is not there; the View menu and the toolbar, which
  /// can carry a reason, show it greyed with one.
  Widget _buildReaderFrame(BuildContext context,
          {required bool splitAvailable, required bool analysisAvailable}) =>
      BibleReadingPane(
        key: const ValueKey('workbench-reader'),
        showSidebarToggle: false,
        sidebarOpen: false,
        onToggleSidebar: null,
        onToggleSplitView:
            splitAvailable ? () => _setCentreMode(WbCentreMode.split) : null,
        splitViewActive: false,
        onClose: null,
        showSearchAndSettings: true,
        onSearchRequested: _focusCommandLine,
        onOpenParallel: () => _setCentreMode(WbCentreMode.browse),
        onAnalysisRequest: (request) =>
            _takeReaderRequest(request, paneAvailable: analysisAvailable),
        activeAnalysisRequest: analysisAvailable && _rightOpen
            ? requestForAnalysisTab(_analysisTab)
            : null,
      );

  /// A reader-side action asked for content. Answer it in the Analysis
  /// pane when there is one, and say so — returning false sends the
  /// reader back to the bottom sheet it has always used.
  ///
  /// Width decides, not habit. Below [WorkbenchFit.threePaneMinWidth]
  /// there is no Analysis pane to send anything to, and a sheet is then
  /// the only surface the content has; at or above it, covering the
  /// verse to describe the verse is the defect (#313).
  bool _takeReaderRequest(
    ReaderAnalysisRequest request, {
    required bool paneAvailable,
  }) {
    final tab = analysisTabForRequest(request);
    if (!paneAvailable || tab == null) return false;
    setState(() {
      _analysisTab = tab;
      // A pane the reader cannot see is not an answer. Collapsed is a
      // preference about the resting workspace, not a refusal of
      // something explicitly asked for — the same call `_selectWord`
      // makes when a word is pinned in Browse.
      _rightOpen = true;
      // The subject is the SELECTION. Any word still latched from a
      // pointer that passed over the Browse text would otherwise win in
      // `_buildAnalysisBody`, and the reader would be shown a word they
      // did not ask about in the tab they did.
      _pinnedKey = null;
      _analysisWord = null;
      _analysisFrozen = false;
    });
    _persistPrefs();
    return true;
  }

  // ── Centre: the word-distribution chart ───────────────────────────

  /// Where one Strong's number falls across the canon, drawn at a size
  /// that can carry 66 book names — task #290, BibleWorks bwh23.
  ///
  /// The counts come from the concordance index, not from the Eagle's
  /// View Greek profile, and that is the load-bearing choice: the
  /// profile covers the Westcott-Hort New Testament only, so sourcing
  /// from it would have meant no chart at all for any Hebrew word. The
  /// index carries both testaments, and its per-book map is absolute —
  /// it sums exactly to the entry's total, where the reference list
  /// beside it is capped at 500.
  Widget _buildChartFrame(BuildContext context, String strongs) {
    final wb = context.watch<WorkbenchProvider>();
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final mp = wb.mainProvider;
    final version = mp.currentVersion;
    final v = _analysisVerse(mp, wb.analysisVerses);
    final currentBook =
        v == null ? null : (bookNameToEnglish[v.book] ?? v.book);

    return FutureBuilder<_ChartData>(
      key: ValueKey<String>('chart-$strongs'),
      future: _chartDataFor(strongs, locale),
      builder: (context, snap) {
        final data = snap.data;
        return WordChartView(
          strongs: strongs,
          word: data?.lemma ?? '',
          gloss: data?.gloss ?? '',
          distribution: data?.distribution ??
              buildDistributionFromCounts(
                counts: const <String, int>{},
                bookOrder: kScopeAllBooks,
                oldTestamentBooks: oldTestamentBooks,
                unit: HitUnit.occurrences,
              ),
          ranks: data?.ranks ?? const <String, int>{},
          locale: locale,
          version: version,
          currentBook: currentBook,
          scopeName: _activeScopeName(mp, locale),
          onClose: _closeChart,
        );
      },
    );
  }

  Future<_ChartData> _chartDataFor(String strongs, String locale) async {
    final result = await ConcordanceService.lookup(strongs);
    final entry = await StrongsService.lookup(strongs);
    final greek = await GreekStatsService.lookup(strongs);
    return _ChartData(
      lemma: entry?.lemma ?? '',
      gloss: entry?.localizedGloss(locale) ?? '',
      // Empty books dropped: this rendering has labels, so their absence
      // is better stated as "in 24 of 66 books" than drawn as 42 blank
      // rows. bwh23 hides them by default for the same reason.
      distribution: buildDistributionFromCounts(
        counts: result?.byBook ?? const <String, int>{},
        bookOrder: kScopeAllBooks,
        oldTestamentBooks: oldTestamentBooks,
        // `byBook` is the uncapped OCCURRENCE map, not the 500-capped
        // verse list beside it. Naming that is the whole of #308.
        unit: HitUnit.occurrences,
      ),
      ranks: <String, int>{
        for (final e in greek?.books.entries ?? const <String, (int, int?)>{}.entries)
          if (e.value.$2 != null) e.key: e.value.$2!,
      },
    );
  }

  // ── Centre: two editions side by side ─────────────────────────────

  /// Two reading columns, each running continuously, each scrolling on
  /// its own — BibleWorks' Parallel Versions Window (bwh38), which it
  /// ships as a separate floating window because the columns need room
  /// its centre pane does not have.
  ///
  /// This is NOT the Browse stack in a different arrangement. Browse
  /// interleaves, and interleaving assumes the editions agree about
  /// where verses begin; bwh11 says plainly that they do not. Where they
  /// diverge — a Hebrew psalm superscription carrying a verse number the
  /// English folds into a heading, so the whole psalm sits one verse out
  /// — interleaved rows line the wrong text up against itself, and two
  /// columns simply do not have the problem.
  Widget _buildSplitFrame(BuildContext context) {
    final sp = _secondary;
    if (sp == null) return _buildSplitLoading(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - kSplitDividerWidth;
        final firstW = (available * _splitRatio)
            .clamp(available * 0.25, available * 0.75)
            .toDouble();
        return Row(
          children: [
            SizedBox(
              width: firstW,
              child: BibleReadingPane(
                key: const ValueKey('workbench-split-first'),
                showSidebarToggle: false,
                sidebarOpen: false,
                onToggleSidebar: null,
                // Reuses the pane's existing split affordance, so the
                // way out reads "Close split view" in every locale it
                // already spoke.
                onToggleSplitView: () => _setCentreMode(WbCentreMode.reader),
                splitViewActive: true,
                onClose: null,
                showSearchAndSettings: true,
                onSearchRequested: _focusCommandLine,
                onOpenParallel: () => _setCentreMode(WbCentreMode.browse),
              ),
            ),
            _buildSplitDivider(context, available),
            SizedBox(
              width: available - firstW,
              child: ChangeNotifierProvider<MainProvider>.value(
                value: sp,
                child: BibleReadingPane(
                  key: const ValueKey('workbench-split-second'),
                  showSidebarToggle: false,
                  sidebarOpen: false,
                  onToggleSidebar: null,
                  onToggleSplitView: null,
                  splitViewActive: true,
                  onClose: () => _setCentreMode(WbCentreMode.reader),
                  // Deliberately no search or settings in the second
                  // column: both act on the workspace rather than on a
                  // column, and two of each would invite the reader to
                  // believe otherwise.
                  showSearchAndSettings: false,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSplitLoading(BuildContext context) {
    final locale = context.read<AppSettings>().locale;
    return Center(
      child: Text(
        uiStrings['splitLoading']?[locale] ?? 'Opening the second column…',
        style: TextStyle(
          fontSize: WbMetrics.text,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildSplitDivider(BuildContext context, double available) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        key: const ValueKey('workbench-split-divider'),
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => setState(() {
          _splitRatio =
              (_splitRatio + d.delta.dx / available).clamp(0.25, 0.75);
        }),
        onDoubleTap: () => setState(() => _splitRatio = 0.5),
        child: Container(
          width: kSplitDividerWidth,
          height: double.infinity,
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.15),
          child: Center(
            // Square, per workbench_theme's "no rounded corners" — the
            // grab marks on the pane dividers were rounded and are now
            // the same shape as this one.
            child: Container(
              width: 2,
              height: 40,
              color: scheme.outline.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  // ── Centre: BibleWorks-style parallel Browse ──────────────────────

  /// The Browse window: the WHOLE chapter, every selected version
  /// printed one after another for each verse, continuously scrolling —
  /// which is what BibleWorks actually does. The first cut here showed
  /// one verse at a time with a stepper, and that made the pane read as
  /// a flash card rather than as a text you work in.
  Widget _buildParallelFrame(BuildContext context) {
    final mp = context.watch<MainProvider>();
    final wbp = context.watch<WorkbenchProvider>();
    final settings = context.watch<AppSettings>();
    final wb = WbColors.of(context);
    final locale = settings.locale;

    final sel = wbp.analysisVerses.isNotEmpty ? wbp.analysisVerses.first : null;
    // Browse and Analysis share ONE cursor, so this pane has no private
    // pin: it shows whatever verse the workspace is focused on.
    final localBook = sel?.book ?? mp.currentBook;
    final book = localBook == null
        ? null
        : (bookNameToEnglish[localBook] ?? localBook);
    final chapter = sel?.chapter ?? mp.currentChapter;
    final verse = sel?.verse ?? mp.currentVerse?.verse ?? 1;

    // Always the reader's own version first, then the configured
    // comparison stack (deduplicated, order preserved).
    final codes = <String>[
      mp.currentVersion,
      ...wbp.parallelVersions.where((c) => c != mp.currentVersion),
    ];

    return ColoredBox(
      color: wb.paneBg,
      child: Column(
        children: [
          WbPaneTitle(
            title: book == null || chapter == null
                ? (uiStrings['parallelBrowse']?[locale] ?? 'Browse')
                : '${localeAwareBookName(book, locale, mp.currentVersion)} '
                    '$chapter  —  ${codes.map(shortBibleVersionLabel).join(" · ")}',
            // The version list IS the control for changing it — that is
            // where a reader looks first, not at an unlabelled icon.
            onTitleTap: () => _pickParallelVersions(context),
            trailing: [
              // yahwehdehua.net puts this switch at the top right of the
              // chapter, and it is the right place for it: the numbers
              // are a reading mode, not a setting you go hunting for.
              WbToolButton(
                icon: settings.showStrongsInOriginals
                    ? Icons.tag
                    : Icons.tag_outlined,
                label: settings.showStrongsInOriginals
                    ? (uiStrings['wbHideStrongsShort']?[locale] ?? 'G#')
                    : (uiStrings['wbShowStrongsShort']?[locale] ?? 'G#'),
                active: settings.showStrongsInOriginals,
                tooltip: settings.showStrongsInOriginals
                    ? (uiStrings['wbHideStrongs']?[locale] ??
                        'Hide Strong\'s numbers')
                    : (uiStrings['wbShowStrongs']?[locale] ??
                        'Show Strong\'s numbers'),
                onPressed: () => settings.setShowStrongsInOriginals(
                    !settings.showStrongsInOriginals),
              ),
              WbToolButton(
                icon: Icons.view_column_outlined,
                tooltip: uiStrings['parallelPickVersions']?[locale] ??
                    'Choose versions',
                onPressed: () => _pickParallelVersions(context),
              ),
              WbToolButton(
                icon: Icons.menu_book_outlined,
                label: uiStrings['classicReaderShort']?[locale] ?? 'Reader',
                tooltip: uiStrings['classicReader']?[locale] ?? 'Chapter reader',
                onPressed: () => _setCentreMode(WbCentreMode.reader),
              ),
            ],
          ),
          // `NAS ▾ Genesis ▾ 1 ▾ 1 ▾` — how you move in BibleWorks, and
          // the answer to "how do I change verse" that the continuous
          // Browse window otherwise left unanswered.
          if (book != null && chapter != null)
            BrowseNavStrip(
              corpus: mp.verses,
              version: mp.currentVersion,
              localBook: localBook,
              chapter: chapter,
              verse: verse,
              bookLabel: (b) => localeAwareBookName(
                  bookNameToEnglish[b] ?? b, locale, mp.currentVersion),
              onVersion: (v) => _switchVersion(v),
              onBook: (b) => _goTo(book: b, chapter: 1, verse: 1),
              onChapter: (c) => _goTo(book: localBook!, chapter: c, verse: 1),
              onVerse: (n) => _moveBrowseCursor(localBook!, chapter, n),
            ),
          Expanded(
            child: (book == null || chapter == null)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        uiStrings['parallelEmptyHint']?[locale] ??
                            'Open a chapter to compare versions side by side.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: WbMetrics.text, color: wb.mutedText),
                      ),
                    ),
                  )
                : BrowseWindow(
                    key: ValueKey('browse-$book-$chapter-${codes.join(",")}'),
                    book: book,
                    chapter: chapter,
                    versionCodes: codes,
                    focusedVerse: verse,
                    // 2026-08-06: the text marks what the search found.
                    // A hit list without marked hits is a table of
                    // contents — you still have to hunt the line.
                    highlight: highlightsForQuery(_wb.lastQuery),
                    onWordTap: _selectWord,
                    onWordHover: _onWordHover,
                    focus: _browseFocus(book, chapter),
                    // Clicking anywhere in the text that is not a word
                    // is the "click empty space" release. It doubles as
                    // moving the cursor, which is fine: both are the
                    // reader deliberately looking somewhere else.
                    onVerseTap: (n) {
                      _unpin();
                      _moveBrowseCursor(localBook!, chapter, n);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// What the Browse window draws every word against.
  ///
  /// The subject is the LATCHED word rather than the pointer's, because
  /// `_analysisWord` already resolves "the pinned word if there is one,
  /// otherwise the last word hovered" — which is precisely what the
  /// Analysis pane is describing. Deriving the lit set from that single
  /// value is what makes the green words and the pane incapable of
  /// disagreeing: there is one answer and both read it.
  AnalysisFocus _browseFocus(String book, int chapter) {
    final subject = _analysisWord;
    return AnalysisFocus(
      pinnedKey: _pinnedKey,
      hoverKey: subject?.occurrence,
      litStrongs: siblingStrongs(
        subjectKey: subject?.occurrence,
        subjectStrongs: subject?.word?.strongs ?? '',
        keyPrefix: browseKeyPrefix(book, chapter),
      ),
    );
  }

  /// A word was tapped: pin it, or release it if it was already pinned.
  ///
  /// On a pad there is no hover at all, so tap also has to do hover's
  /// whole job — latch the word and bring a tab forward that shows it,
  /// since a readout behind an unselected tab looks broken.
  void _selectWord(BrowseHover h) {
    final focus = AnalysisFocus(pinnedKey: _pinnedKey);
    final key = h.occurrence;
    if (key == null) return;

    // Releasing must ONLY release. Letting the second click also swap
    // tabs would make unpinning cost the reader the pane they were
    // reading, which is the defect this whole feature exists to fix.
    if (focus.tapWouldUnpin(key)) {
      _unpin();
      return;
    }

    setState(() {
      _pinnedKey = key;
      _analysisWord = h;
      _analysisFrozen = false;
      // Only tabs that answer "what is THIS word" get pulled forward,
      // and only when the reader is not already on one. Clicking is now
      // the primary gesture, so yanking someone off KWIC or Morphology
      // every time they pinned a word would be a new defect of exactly
      // the kind we are removing.
      if (!_wordDrivenTabs.contains(_analysisTab)) {
        _analysisTab = AnalysisTab.wordStudy;
      }
      _rightOpen = true;
    });
    _persistPrefs();
  }

  /// Analysis tabs whose subject is the word rather than the verse.
  static const _wordDrivenTabs = {
    AnalysisTab.wordStudy,
    AnalysisTab.kwic,
    AnalysisTab.morphology,
  };

  /// Release the pin. Reachable four ways — clicking the pinned word
  /// again, the pin bar's button, Esc, and clicking anywhere else in
  /// the Browse text — because a reader who cannot find the way out of
  /// a state stops entering it.
  ///
  /// The latched word stays: hover simply resumes, and blanking the
  /// pane on unpin would punish the reader for letting go.
  void _unpin() {
    if (_pinnedKey == null) return;
    setState(() => _pinnedKey = null);
  }

  /// The pointer moved onto (or off) an original-language word.
  ///
  /// One event, two lifetimes: the status bar tracks the pointer exactly
  /// and clears on exit, while the Analysis window latches the last
  /// word. Shift suspends the latch.
  void _onWordHover(BrowseHover? h) {
    final frozen = HardwareKeyboard.instance.isShiftPressed;
    final focus = AnalysisFocus(pinnedKey: _pinnedKey);
    final next = (h != null && focus.acceptsHoverUpdate(shiftHeld: frozen))
        ? h
        : _analysisWord;
    // Occurrence is part of identity, not just the Strong's number: a
    // verse can print the same number twice, and without this the
    // pointer moving from one to the other is treated as no movement.
    bool same(BrowseHover? a, BrowseHover? b) =>
        a?.occurrence == b?.occurrence &&
        a?.word?.strongs == b?.word?.strongs &&
        a?.reference == b?.reference &&
        a?.verse == b?.verse;
    final sameHover = same(_hover, h);
    final sameAnalysis = same(_analysisWord, next);
    if (sameHover && sameAnalysis && frozen == _analysisFrozen) return;
    setState(() {
      _hover = h;
      _analysisWord = next;
      _analysisFrozen = frozen;
    });
  }

  /// The [Verse] object for verse [n] of the chapter now on screen.
  Verse? _verseAt(MainProvider mp, int n) {
    final book = mp.currentBook;
    final chapter = mp.currentChapter;
    if (book == null || chapter == null) return null;
    for (final v in mp.verses) {
      if (v.book == book && v.chapter == chapter && v.verse == n) return v;
    }
    return null;
  }

  /// Change the reading version from the Browse nav strip. Reloads the
  /// corpus, which the Browse window and every pane keys off.
  Future<void> _switchVersion(String code) async {
    final mp = context.read<MainProvider>();
    if (code == mp.currentVersion) return;
    mp.setVersion(code);
    await FetchVerses.execute(mainProvider: mp);
  }

  /// Jump the workspace to a book/chapter/verse chosen in the nav strip.
  void _goTo({required String book, required int chapter, required int verse}) {
    final mp = context.read<MainProvider>();
    mp.setCurrentChapter(book: book, chapter: chapter);
    _moveBrowseCursor(book, chapter, verse);
  }

  /// Step the Browse cursor to verse [target] of the current chapter.
  /// Focusing (rather than pinning a local override) is what keeps the
  /// Browse pane, the reader's selection and the Word Study pane on the
  /// same verse.
  void _moveBrowseCursor(String localBook, int chapter, int target) {
    final mp = context.read<MainProvider>();
    for (final v in mp.verses) {
      if (v.book == localBook && v.chapter == chapter && v.verse == target) {
        mp.updateCurrentVerse(verse: v);
        _wb.focusVerse(v);
        return;
      }
    }
  }

  /// What the active limit is called, or null when nothing is limiting.
  /// Result panes take the null as "print a plain count".
  String? _activeScopeName(MainProvider mp, String locale) =>
      !_wb.hasSearchLimit
          ? null
          : scopeDisplayName(
              spec: _wb.searchLimitSpec,
              fallbackLabel: _wb.searchLimitLabel,
              locale: locale,
              version: mp.currentVersion,
              maxNames: 2,
            );

  /// The one place the scope sheet is opened from, whichever of the
  /// three entry points fired.
  Future<void> _openScopeSheet() async {
    final mp = context.read<MainProvider>();
    final locale = context.read<AppSettings>().locale;
    final books = await showSearchScopeSheet(
      context: context,
      locale: locale,
      version: mp.currentVersion,
      activeSpec: _wb.searchLimitSpec,
      activeFallbackLabel: _wb.searchLimitLabel,
    );
    if (books == null || !mounted) return;
    // False means the selection covers no verse the loaded edition
    // carries — the provider refuses rather than installing a limit
    // that makes every later search silently return nothing. Same
    // refusal, same message, as `l revelation 30` from the command line.
    final applied = await _wb.setSearchLimitFromBooks(books);
    if (!mounted) return;
    _wb.showVerbNotice(applied
        ? null
        : describeVerbIssue(
            CommandVerbIssue.emptyScope,
            scopeDisplayName(
              spec: limitSpecForBooks(books),
              locale: locale,
              version: mp.currentVersion,
            ),
            locale));
  }

  /// Lets the reader choose which translations sit in the parallel stack
  /// — and, since #288, what ORDER they sit in.
  ///
  /// The sheet is staged: null means the reader dismissed it and the
  /// stack is untouched. The old checkbox list applied on dismiss and
  /// had no other way to apply, so there was no way to back out of a
  /// change; there is now, which matters much more once a stray drag can
  /// rearrange the columns.
  Future<void> _pickParallelVersions(BuildContext context) async {
    final mp = context.read<MainProvider>();
    final locale = context.read<AppSettings>().locale;
    final next = await showVersionStackSheet(
      context: context,
      locale: locale,
      reading: mp.currentVersion,
      comparisons: _wb.parallelVersions,
    );
    if (next == null || !mounted) return;
    _wb.setParallelVersions(next);
  }

  // ── Left: command pane ────────────────────────────────────────────

  /// The same Word List the Tools menu opens, for the passage in view.
  ///
  /// Reached from the command pane's syntax card and from the hint that
  /// says a Strong's number is missing — the two places that raise the
  /// question "where would I get one".
  void _openWordList() {
    final mp = context.read<MainProvider>();
    pushPage(WordListPage(
      book: mp.currentBook ?? '',
      chapter: mp.currentChapter ?? 1,
      locale: context.read<AppSettings>().locale,
      version: mp.currentVersion,
    ));
  }

  Widget _buildCommandFrame(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final wb = WbColors.of(context);
    return ColoredBox(
      color: wb.paneBg,
      child: Column(
        children: [
          WbPaneTitle(
            title: uiStrings['search']?[locale] ?? 'Search',
            trailing: [
              WbToolButton(
                icon: Icons.chevron_left,
                tooltip: uiStrings['collapse']?[locale] ?? 'Collapse',
                onPressed: () => _setLeftOpen(false),
              ),
            ],
          ),
          Expanded(
            child: CommandPane(
              focusNode: _commandFocus,
              onEditScope: _openScopeSheet,
              onOpenWordList: _openWordList,
            ),
          ),
        ],
      ),
    );
  }

  // ── Right: analysis pane ──────────────────────────────────────────

  Widget _buildAnalysisFrame(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final wb = context.watch<WorkbenchProvider>();
    final mp = wb.mainProvider;
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final verses = wb.analysisVerses;

    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          // Unconditional since 2026-08-09 (#284). It used to be skipped
          // for the word-study tab, which drew its own sheet header —
          // so the pane's title and collapse chevron appeared and
          // vanished as the pointer moved between a word and a verse.
          WbPaneTitle(
            title: uiStrings['analysisTitle']?[locale] ?? 'Analysis',
            trailing: [
              // Next to the pane's own menu, which is where the reader
              // who asked for this pointed (task #297). Two states, not
              // three: the strip already decides well on its own, so the
              // only question worth a control is "decide for me" versus
              // "I want the names", and that is one tap either way.
              WbToolButton(
                icon: Icons.label_outline,
                tooltip: _analysisTabLabels
                    ? (uiStrings['analysisTabNamesAuto']?[locale] ??
                        'Tab names: automatic')
                    : (uiStrings['analysisTabNamesShow']?[locale] ??
                        'Show tab names'),
                active: _analysisTabLabels,
                onPressed: () {
                  setState(() => _analysisTabLabels = !_analysisTabLabels);
                  _persistPrefs();
                },
              ),
              WbToolButton(
                icon: Icons.chevron_right,
                tooltip: uiStrings['collapse']?[locale] ?? 'Collapse',
                onPressed: () => _setRightOpen(false),
              ),
            ],
          ),
          AnalysisTabStrip(
            current: _analysisTab,
            locale: locale,
            preferLabels: _analysisTabLabels,
            onChanged: (t) {
              setState(() => _analysisTab = t);
              _persistPrefs();
            },
          ),
          // Below the tab strip, not above it: the pin governs what
          // every tab is looking at, so it belongs with the content
          // rather than with the tab chooser.
          if (_pinnedKey != null && _analysisWord != null)
            AnalysisPinBar(
              word: _analysisWord!.word?.text ?? '',
              reference: _analysisWord!.reference,
              locale: locale,
              onUnpin: _unpin,
            ),
          const Divider(height: 1),
          Expanded(
            // The hint is for "nothing to analyse yet" — NOT for "no
            // verse is selected". A hovered or tapped word is something
            // to analyse on its own, and gating on `verses` alone threw
            // that readout away before it could ever be built, which is
            // what made hover and tap both look dead.
            child: verses.isEmpty && _analysisWord == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        uiStrings['analysisEmptyHint']?[locale] ??
                            'Tap a verse in the Bible pane and its '
                                'original-language word study appears here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: settings.fontSize - 1,
                          color: scheme.outline,
                          height: 1.6,
                        ),
                      ),
                    ),
                  )
                : _buildAnalysisBody(context, wb, mp, verses, locale),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisBody(
    BuildContext context,
    WorkbenchProvider wb,
    MainProvider mp,
    List<Verse> verses,
    String locale,
  ) {
    switch (_analysisTab) {
      case AnalysisTab.wordStudy:
        // A hovered word wins. The Analysis window's job is to report
        // the pointer; the verse-wide word grid is what you get before
        // the pointer has been anywhere.
        final hovered = _analysisWord;
        final hoveredWord = hovered?.word;
        if (hovered != null && hoveredWord != null) {
          return WordAnalysisPane(
            word: hoveredWord,
            reference: hovered.reference,
            locale: locale,
            version: mp.currentVersion,
            frozen: _analysisFrozen,
            grammar: hovered.grammar,
            onOpenFullEntry: () =>
                pushPage(StrongsEntryPage(number: hoveredWord.strongs)),
            onOpenRef: (openBook, chapter, verse) => _onCrossRefTap(
              BibleReference(
                englishBook: openBook,
                chapter: chapter,
                verseStart: verse,
                verseEnd: verse,
              ),
            ),
          );
        }
        // Verse-level hover: a translation line. Show that verse's
        // interlinear rather than whatever happens to be selected —
        // the pane still reports the pointer, one grade coarser.
        if (hovered != null) {
          final hv = _verseAt(mp, hovered.verse);
          if (hv != null) {
            return OriginalsSheet(
              key: ValueKey<String>('analysis-hover-${hv.id}'),
              verses: [hv],
              allVerses: mp.verses,
              locale: locale,
              currentVersion: mp.currentVersion,
              embedded: true,
              onNavigateRef: _onAnalysisNavigateRef,
            );
          }
        }
        // Key forces OriginalsSheet to re-run its load Future when the
        // selection changes (the sheet caches its Future in initState,
        // so a bare field swap wouldn't reload).
        return OriginalsSheet(
          key: ValueKey<String>(
              'analysis-${verses.map((v) => v.id).join('|')}'),
          verses: verses,
          allVerses: mp.verses,
          locale: locale,
          currentVersion: mp.currentVersion,
          embedded: true,
          onNavigateRef: _onAnalysisNavigateRef,
        );

      case AnalysisTab.topics:
        final v = _analysisVerse(mp, verses);
        if (v == null) return _analysisHint(context, locale);
        return ConcordanceTopicsPane(
          key: ValueKey<String>('topics-${v.id}'),
          englishBook: bookNameToEnglish[v.book] ?? v.book,
          chapter: v.chapter,
          verse: v.verse,
          locale: locale,
          onOpenRef: _onCrossRefTap,
        );

      case AnalysisTab.crossRefs:
        final v = _analysisVerse(mp, verses);
        if (v == null) return _analysisHint(context, locale);
        return CrossRefsPane(
          englishBook: bookNameToEnglish[v.book] ?? v.book,
          chapter: v.chapter,
          verse: v.verse,
          locale: locale,
          version: mp.currentVersion,
          verseByRef: wb.verseByRef,
          onOpenRef: _onCrossRefTap,
        );

      case AnalysisTab.stats:
        final v = _analysisVerse(mp, verses);
        if (v == null) return _analysisHint(context, locale);
        return FutureBuilder<List<OriginalWord>?>(
          key: ValueKey<String>('stats-${v.id}'),
          future: OriginalsService.forVerse(
            bookNameToEnglish[v.book] ?? v.book,
            v.chapter,
            v.verse,
          ),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final v = _analysisVerse(mp, _wb.analysisVerses);
            return WordStatsPane(
              words: snap.data ?? const <OriginalWord>[],
              locale: locale,
              onOpenStrongs: (n) => pushPage(StrongsEntryPage(number: n)),
              scope: _wb.searchLimit,
              scopeName: _activeScopeName(mp, locale),
              scopeBooks: wholeBookScope(_wb.searchLimitSpec),
              version: mp.currentVersion,
              currentBook:
                  v == null ? null : (bookNameToEnglish[v.book] ?? v.book),
              onOpenChart: _openChart,
            );
          },
        );

      case AnalysisTab.kwic:
        // KWIC reports on a WORD, not a verse — the pointer's word if
        // there is one, otherwise the first tagged word of the focused
        // verse so the tab is never empty just because nobody has
        // hovered yet.
        final number = _analysisWord?.word?.strongs;
        if (number == null || number.isEmpty) {
          return _kwicHint(context, locale);
        }
        return KwicPane(
          key: ValueKey<String>('kwic-$number-${mp.currentVersion}'),
          strongs: number,
          version: mp.currentVersion,
          locale: locale,
          scope: _wb.searchLimit,
          scopeName: _activeScopeName(mp, locale),
          onOpenRef: (book, chapter, verse) => _onCrossRefTap(
            BibleReference(
              englishBook: book,
              chapter: chapter,
              verseStart: verse,
              verseEnd: verse,
            ),
          ),
        );

      case AnalysisTab.related:
        final v = _analysisVerse(mp, verses);
        if (v == null) return _analysisHint(context, locale);
        final base = mp.indexOfVerse(v);
        if (base < 0) return _analysisHint(context, locale);
        return RelatedVersesPane(
          key: ValueKey<String>('related-${v.id}-${mp.currentVersion}'),
          corpus: mp.wordKeys,
          verses: mp.verses,
          baseIndex: base,
          locale: locale,
          version: mp.currentVersion,
          onOpenVerse: (hit) => _onCrossRefTap(
            BibleReference(
              englishBook: bookNameToEnglish[hit.book] ?? hit.book,
              chapter: hit.chapter,
              verseStart: hit.verse,
              verseEnd: hit.verse,
            ),
          ),
        );

      case AnalysisTab.verseLists:
        final v = _analysisVerse(mp, verses);
        return VerseListPane(
          locale: locale,
          version: mp.currentVersion,
          verseByRef: wb.verseByRef,
          currentRef: v == null
              ? null
              : VerseRef(
                  bookNameToEnglish[v.book] ?? v.book, v.chapter, v.verse),
          searchResults: _searchResultRefs(wb),
          searchLimitActive: wb.hasSearchLimit,
          onOpenRef: (ref) => _onCrossRefTap(
            BibleReference(
              englishBook: ref.englishBook,
              chapter: ref.chapter,
              verseStart: ref.verse,
              verseEnd: ref.verse,
            ),
          ),
          onSetSearchLimit: (list) => list == null
              ? wb.setSearchLimit(null, null)
              : wb.setSearchLimit(verseListKeys(list),
                  list.name.isEmpty ? null : list.name),
        );

      case AnalysisTab.phrases:
        final v = _analysisVerse(mp, verses);
        if (v == null) return _analysisHint(context, locale);
        final base = mp.indexOfVerse(v);
        if (base < 0) return _analysisHint(context, locale);
        return PhraseMatchPane(
          key: ValueKey<String>('phrases-${v.id}-${mp.currentVersion}'),
          corpus: mp.wordKeys,
          verses: mp.verses,
          baseIndex: base,
          locale: locale,
          version: mp.currentVersion,
          scope: _phraseScope(mp, wb),
          scopeLabel: wb.searchLimitLabel,
          onOpenVerse: (hit) => _onCrossRefTap(
            BibleReference(
              englishBook: bookNameToEnglish[hit.book] ?? hit.book,
              chapter: hit.chapter,
              verseStart: hit.verse,
              verseEnd: hit.verse,
            ),
          ),
        );

      case AnalysisTab.vocabulary:
        final v = _analysisVerse(mp, verses);
        if (v == null) return _analysisHint(context, locale);
        final book = bookNameToEnglish[v.book] ?? v.book;
        // Keyed on the BOOK, not the verse: the deck follows the chapter
        // through `didUpdateWidget` so that scrolling a chapter-scoped
        // deck does not throw away a drill in progress.
        return VocabularyPane(
          key: ValueKey<String>('vocabulary-$book'),
          englishBook: book,
          chapter: v.chapter,
          locale: locale,
          onOpenVerse: (chapter, verse) => _onCrossRefTap(
            BibleReference(
              englishBook: book,
              chapter: chapter,
              verseStart: verse,
              verseEnd: verse,
            ),
          ),
        );

      case AnalysisTab.morphology:
        final v = _analysisVerse(mp, verses);
        if (v == null) return _analysisHint(context, locale);
        final book = bookNameToEnglish[v.book] ?? v.book;
        // Keyed on the BOOK rather than the verse: the query is the
        // reader's work, and rebuilding the pane every time the pointer
        // crosses a word would throw it away.
        return MorphSearchPane(
          key: ValueKey<String>('morphology-$book'),
          englishBook: book,
          chapter: v.chapter,
          locale: locale,
          version: mp.currentVersion,
          seedCode: _analysisWord?.word?.morph,
          onOpenRef: (openBook, chapter, verse) => _onCrossRefTap(
            BibleReference(
              englishBook: openBook,
              chapter: chapter,
              verseStart: verse,
              verseEnd: verse,
            ),
          ),
        );

      case AnalysisTab.context:
        final v = _analysisVerse(mp, verses);
        if (v == null) return _analysisHint(context, locale);
        final book = bookNameToEnglish[v.book] ?? v.book;
        // Keyed on the BOOK, not the verse: the pane's own state (scope,
        // sort, which row is expanded) is the reader's work, and the
        // pericope follows the verse through `didUpdateWidget` without
        // throwing that away.
        return ContextPane(
          key: ValueKey<String>('context-$book'),
          englishBook: book,
          chapter: v.chapter,
          verse: v.verse,
          locale: locale,
          version: mp.currentVersion,
          onOpenVerse: (chapter, verse) => _onCrossRefTap(
            BibleReference(
              englishBook: book,
              chapter: chapter,
              verseStart: verse,
              verseEnd: verse,
            ),
          ),
        );

      case AnalysisTab.places:
        final v = _analysisVerse(mp, verses);
        if (v == null) return _analysisHint(context, locale);
        final book = bookNameToEnglish[v.book] ?? v.book;
        final script = bookScriptFor(locale, mp.currentVersion);
        return PlacesPane(
          englishBook: book,
          chapter: v.chapter,
          verse: v.verse,
          locale: locale,
          script: script,
          onOpenAtlas: (places, id) => _openAtlas(
            places,
            id,
            '${bookNameInScript(book, script)} ${v.chapter}:${v.verse}',
          ),
        );

      case AnalysisTab.sermons:
        final v = _analysisVerse(mp, verses);
        if (v == null) return _analysisHint(context, locale);
        final book = bookNameToEnglish[v.book] ?? v.book;
        return SermonsPane(
          key: ValueKey<String>('sermons-${v.id}'),
          englishBook: book,
          chapter: v.chapter,
          verse: v.verse,
          displayBook: localeAwareBookName(book, locale, mp.currentVersion),
          locale: locale,
          onOpenSermon: (s) => pushPage(SermonDetailPage(sermon: s)),
        );
    }
  }

  /// The active search limit as corpus indices — bwh51's "use search
  /// limits from main window".
  ///
  /// The limit is stored as `'EnglishBook-chapter-verse'` keys because
  /// that survives a change of version; the scanner needs positions in
  /// the loaded corpus. Translating between them costs one map lookup
  /// per limited verse, so the result is cached until either the limit
  /// or the corpus changes.
  Set<int>? _phraseScope(MainProvider mp, WorkbenchProvider wb) {
    final keys = wb.searchLimit;
    if (keys == null || keys.isEmpty) return null;
    if (identical(_phraseScopeSource, keys) &&
        identical(_phraseScopeVerses, mp.verses)) {
      return _phraseScopeCache;
    }
    final byRef = wb.verseByRef;
    final out = <int>{};
    for (final k in keys) {
      final v = byRef[k];
      if (v == null) continue;
      final i = mp.indexOfVerse(v);
      if (i >= 0) out.add(i);
    }
    _phraseScopeSource = keys;
    _phraseScopeVerses = mp.verses;
    _phraseScopeCache = out;
    return out;
  }

  /// The command pane's current results as plain refs, so the Verse
  /// List pane can import them without knowing whether the last search
  /// was a text scan or a Strong's lookup.
  List<VerseRef> _searchResultRefs(WorkbenchProvider wb) {
    final strongs = wb.strongsRefs;
    if (strongs != null) {
      return [
        for (final r in strongs) VerseRef(r.englishBook, r.chapter, r.verse),
      ];
    }
    return [
      for (final v in wb.textResults)
        VerseRef(bookNameToEnglish[v.book] ?? v.book, v.chapter, v.verse),
    ];
  }

  /// KWIC reports on a WORD, so its empty state has to ask for a word.
  /// The generic analysis hint asks for a verse, which would send the
  /// reader to do the wrong thing.
  Widget _kwicHint(BuildContext context, String locale) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            uiStrings['kwicHint']?[locale] ??
                'Tap a tagged word in the text to see every place it '
                    'occurs, aligned on the word.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: WbMetrics.text,
              color: Theme.of(context).colorScheme.outline,
              height: 1.6,
            ),
          ),
        ),
      );

  /// The verse these tabs should report on.
  ///
  /// 2026-08-06: this exists because v1.5.4 broke the Workbench. The
  /// Analysis pane used to bail out to a hint whenever nothing was
  /// selected, which incidentally guaranteed `verses` was non-empty by
  /// the time these branches ran. Relaxing that guard — so a hovered
  /// word could reach the Word Study tab — let an EMPTY list through to
  /// `verses.first` here, and `List.first` throws on empty. In a
  /// release build the resulting ErrorWidget is a plain grey rectangle,
  /// so the whole workspace went blank while the menu bar and status
  /// bar (outside the failing subtree) kept painting and updating. The
  /// tab choice is persisted, so anyone left on Stats hit it on every
  /// reload.
  ///
  /// Falling back to the hovered verse is also simply better: these
  /// panes can now follow the pointer instead of needing a selection.
  Verse? _analysisVerse(MainProvider mp, List<Verse> verses) {
    final h = _analysisWord;
    return pickAnalysisVerse(
        verses, h == null ? null : _verseAt(mp, h.verse));
  }

  Widget _analysisHint(BuildContext context, String locale) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            uiStrings['analysisEmptyHint']?[locale] ??
                'Tap a verse in the Bible pane and its '
                    'original-language word study appears here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: WbMetrics.text,
              color: Theme.of(context).colorScheme.outline,
              height: 1.6,
            ),
          ),
        ),
      );

  // ── Chrome: headers, dividers, collapsed rails ────────────────────

  /// Draggable divider between panes — same visual pattern as
  /// HomePage's split-view divider. Drag resizes; double-tap or a fast
  /// outward fling collapses the pane.
  Widget _buildDivider(BuildContext context,
      {required Key key, required bool isLeft}) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          setState(() {
            if (isLeft) {
              _leftWidth = (_leftWidth + details.delta.dx)
                  .clamp(_minLeftWidth, _maxLeftWidth)
                  .toDouble();
            } else {
              _rightWidth = (_rightWidth - details.delta.dx)
                  .clamp(_minRightWidth, _maxRightWidth)
                  .toDouble();
            }
          });
        },
        onHorizontalDragEnd: (details) {
          // A fast outward fling collapses the pane (pad-friendly).
          final v = details.primaryVelocity ?? 0;
          if (isLeft && v < -600) {
            _setLeftOpen(false);
            return;
          }
          if (!isLeft && v > 600) {
            _setRightOpen(false);
            return;
          }
          _persistPrefs();
        },
        onDoubleTap: () {
          if (isLeft) {
            _setLeftOpen(false);
          } else {
            _setRightOpen(false);
          }
        },
        child: Container(
          width: _dividerWidth,
          height: double.infinity,
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.15),
          child: Center(
            child: Container(
              width: 2,
              height: 40,
              color: scheme.outline.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  /// Slim rail shown in place of a collapsed pane; tapping reopens it.
  /// 44 px wide to stay a comfortable touch target.
  Widget _buildCollapsedRail(BuildContext context,
      {required Key key, required bool isLeft}) {
    final scheme = Theme.of(context).colorScheme;
    final locale = context.read<AppSettings>().locale;
    return SizedBox(
      key: key,
      width: _railWidth,
      height: double.infinity,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        child: InkWell(
          onTap: () {
            if (isLeft) {
              _setLeftOpen(true);
            } else {
              _setRightOpen(true);
            }
          },
          child: Center(
            child: Tooltip(
              message: uiStrings['expandPanel']?[locale] ?? 'Expand panel',
              child: Icon(
                isLeft
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                size: 22,
                color: scheme.outline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything the distribution chart needs, gathered in one await so the
/// frame does not rebuild three times as three services land.
class _ChartData {
  const _ChartData({
    required this.lemma,
    required this.gloss,
    required this.distribution,
    required this.ranks,
  });

  final String lemma;
  final String gloss;
  final SearchDistribution distribution;

  /// Book name → this word's rank among that book's words. Empty for
  /// Hebrew, which no bundled profile ranks.
  final Map<String, int> ranks;
}
