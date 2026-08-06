import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show bibleVersions, shortBibleVersionLabel;
import 'package:seeksparks/constants/book_names.dart' show bookNameToEnglish;
import 'package:seeksparks/constants/app_version.dart'
    show kAppVersion, formatReleaseTimeLocal;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/about_page.dart';
import 'package:seeksparks/pages/bible_timeline_page.dart';
import 'package:seeksparks/pages/bible_trivia_page.dart';
import 'package:seeksparks/pages/books_page.dart';
import 'package:seeksparks/pages/evidence_page.dart';
import 'package:seeksparks/pages/home_page.dart';
import 'package:seeksparks/pages/library_page.dart';
import 'package:seeksparks/pages/sermons_page.dart';
import 'package:seeksparks/pages/settings_page.dart';
import 'package:seeksparks/pages/word_list_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/fetch_verses.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/utils/navigate_to_reader.dart'
    show kHomePageRouteName;
import 'package:seeksparks/utils/morphology.dart' show describeMorphology;
import 'package:seeksparks/utils/responsive.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/widgets/bible_reading_pane.dart';
import 'package:seeksparks/widgets/command_pane.dart';
import 'package:seeksparks/pages/strongs_entry_page.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/utils/strongs_inline.dart';
import 'package:seeksparks/utils/search_highlight.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/verse_list_pane.dart';
import 'package:seeksparks/utils/verse_list.dart' show VerseRef, verseListKeys;
import 'package:seeksparks/widgets/kwic_pane.dart';
import 'package:seeksparks/widgets/related_verses_pane.dart';
import 'package:seeksparks/widgets/phrase_match_pane.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/browse_nav_strip.dart';
import 'package:seeksparks/widgets/browse_window.dart';
import 'package:seeksparks/widgets/word_analysis_pane.dart';
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
///  * <600 px: reader alone (the standalone SearchPage still covers
///    phones).
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
  static const double _minLeftWidth = 240;
  static const double _maxLeftWidth = 480;
  static const double _minRightWidth = 320;
  static const double _maxRightWidth = 560;
  static const double _dividerWidth = 16;

  /// Owns the workbench state. Created here (not globally in main.dart)
  /// so its MainProvider listener and search state only live while the
  /// workbench is open.
  late final WorkbenchProvider _wb;

  double _leftWidth = _defaultLeftWidth;
  double _rightWidth = _defaultRightWidth;
  bool _leftOpen = true;
  bool _rightOpen = true;

  /// 2026-08 (SeekSparks): BibleWorks-style parallel Browse mode. When
  /// on, the centre pane stacks the same verse in every selected version
  /// plus the original-language line, instead of the chapter reader.
  bool _parallelMode = true;
  // Deliberately a NEW key. v1.1.0 defaulted this off and persisted the
  // value on any pane interaction, so every existing install had `false`
  // stored and never saw the Browse window even after it became the
  // default. Renaming re-applies the new default exactly once.
  static const _kParallelKey = 'workbench.browseMode.v2';
  static const _kParallelVersionsKey = 'workbench.parallelVersions';
  /// Empty until [_restorePrefs] picks a default for the reader's
  /// language — an English-only stack is the wrong first impression for
  /// a Chinese reader.
  List<String> _parallelVersions = const [];

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
  /// Only a default. It seeds `_parallelVersions` on first run and a
  /// reader's own selection is persisted over it.
  List<String> _defaultParallelVersions(String locale) {
    switch (locale) {
      case 'zh-Hans':
        return const ['cuvs-yhwh', 'biblexg-v2', 'bsb'];
      case 'zh-Hant':
        return const ['cuvs-yhwh-tr', 'biblexg-v2-tr', 'bsb'];
      default:
        return const ['bsb', 'nasb', 'kjv'];
    }
  }

  /// Which Analysis tab the right pane is showing. Persisted, because
  /// a reader who works in cross-references expects to still be there
  /// after a reload.
  AnalysisTab _analysisTab = AnalysisTab.wordStudy;
  static const _kAnalysisTabKey = 'workbench.analysisTab';

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
    _restorePrefs();
  }

  @override
  void dispose() {
    _commandFocus.dispose();
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

    return [
      WbMenu(s('menuFile', 'File'), [
        WbMenuItem(s('settings', 'Settings…'),
            () => pushPage(const SettingsPage())),
        const WbMenuItem.separator(),
        WbMenuItem(s('menuClassicReader', 'Exit to reader'), () => Get.off(
              () => const HomePage(),
              routeName: kHomePageRouteName,
              transition: Transition.leftToRight,
            )),
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
          () {
            setState(() => _parallelMode = true);
            _persistPrefs();
          },
          checked: _parallelMode,
        ),
        WbMenuItem(
          s('classicReader', 'Chapter reader'),
          () {
            setState(() => _parallelMode = false);
            _persistPrefs();
          },
          checked: !_parallelMode,
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
        WbMenuItem(s('menuFocusCommandLine', 'Command line'),
            () => _commandFocus.requestFocus(),
            shortcut: 'Ctrl+L'),
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
        WbMenuItem('${mp.currentVersion.toUpperCase()} · v$kAppVersion', null),
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
          active: _parallelMode,
          onPressed: () {
            setState(() => _parallelMode = true);
            _persistPrefs();
          },
        ),
        WbToolButton(
          icon: Icons.menu_book_outlined,
          label: s('classicReaderShort', 'Reader'),
          tooltip: s('classicReader', 'Chapter reader'),
          active: !_parallelMode,
          onPressed: () {
            setState(() => _parallelMode = false);
            _persistPrefs();
          },
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
          onPressed: () {
            if (!_leftOpen) _setLeftOpen(true);
            _commandFocus.requestFocus();
          },
        ),
        WbToolButton(
          icon: Icons.settings_outlined,
          tooltip: s('settings', 'Settings'),
          onPressed: () => pushPage(const SettingsPage()),
        ),
      ],
    ];
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
        mp.currentVersion.toUpperCase(),
        onTap: () => _pickParallelVersions(context),
      ),
      WbStatusField(
        s(_parallelMode ? 'parallelBrowseShort' : 'classicReaderShort',
            _parallelMode ? 'Browse' : 'Reader'),
        onTap: () {
          setState(() => _parallelMode = !_parallelMode);
          _persistPrefs();
        },
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
      _parallelMode = prefs.getBool(_kParallelKey) ?? true;
      final saved = prefs.getStringList(_kParallelVersionsKey);
      _parallelVersions = (saved != null && saved.isNotEmpty)
          ? saved
          : _defaultParallelVersions(context.read<AppSettings>().locale);
      final tab = prefs.getInt(_kAnalysisTabKey);
      if (tab != null && tab >= 0 && tab < AnalysisTab.values.length) {
        _analysisTab = AnalysisTab.values[tab];
      }
    });
  }

  Future<void> _persistPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLeftWidthKey, _leftWidth);
    await prefs.setDouble(_kRightWidthKey, _rightWidth);
    await prefs.setBool(_kLeftOpenKey, _leftOpen);
    await prefs.setBool(_kRightOpenKey, _rightOpen);
    await prefs.setBool(_kParallelKey, _parallelMode);
    await prefs.setStringList(_kParallelVersionsKey, _parallelVersions);
    await prefs.setInt(_kAnalysisTabKey, _analysisTab.index);
  }

  // ── Pane open/collapse ────────────────────────────────────────────

  void _setLeftOpen(bool open) {
    setState(() => _leftOpen = open);
    _persistPrefs();
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
    final compact = !ResponsiveBreakpoints.isDesktopOrWider(width);

    return Scaffold(
      backgroundColor: wb.chromeBg,
      body: SafeArea(
        child: Column(
          children: [
            ...[
              WorkbenchMenuBar(
                menus: _buildMenus(context, locale),
                // The version label is the first thing to go when the
                // menu titles need the room.
                // Language first, then the build. The switcher stays even
                // on a narrow window — changing interface language must
                // not require hunting through Settings — while the build
                // label is what drops when the menu titles need the room.
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (width >= 1200)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          'SeekSparks $kAppVersion · '
                          '${formatReleaseTimeLocal()}',
                          style: TextStyle(
                              fontSize: WbMetrics.chrome,
                              color: wb.mutedText),
                        ),
                      ),
                    const SizedBox(
                      height: 26,
                      child: LanguageSwitcherButton(dense: true),
                    ),
                  ],
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
          final threePane = ResponsiveBreakpoints.isDesktopOrWider(width);
          final showLeft = _leftOpen && width >= 600;
          final showRight = _rightOpen && threePane;
          // Cap side panes at 32% of the total width each so the
          // reader never gets squeezed to nothing on a just-barely-
          // desktop screen (e.g. iPad Pro 11" portrait = 1024).
          final maxSide = width * 0.32;
          final leftW = showLeft
              ? (_leftWidth > maxSide ? maxSide : _leftWidth)
              : 0.0;
          final rightW = showRight
              ? (_rightWidth > maxSide ? maxSide : _rightWidth)
              : 0.0;

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
                    // Browse only makes sense with room for it: three
                    // translations plus an originals line on a phone is
                    // unreadable, so below the three-pane breakpoint the
                    // centre is always the chapter reader regardless of
                    // the persisted preference.
                    child: (_parallelMode && threePane)
                        ? _buildParallelFrame(context)
                        : BibleReadingPane(
                      key: const ValueKey('workbench-reader'),
                      showSidebarToggle: false,
                      sidebarOpen: false,
                      onToggleSidebar: null,
                      // Split View is superseded by the workbench
                      // itself; the menu entry is hidden (null).
                      onToggleSplitView: null,
                      splitViewActive: false,
                      onClose: null,
                      showSearchAndSettings: true,
                      // 2026-08-04: the overflow menu's way back to
                      // the classic single-pane reader (and its Split
                      // View, which the workbench supersedes).
                      // 2026-08 (SeekSparks): switch this pane to the
                      // BibleWorks-style parallel Browse stack.
                      onOpenParallel: () {
                        setState(() => _parallelMode = true);
                        _persistPrefs();
                      },
                      onOpenClassicReader: () => Get.off(
                        () => const HomePage(),
                        routeName: kHomePageRouteName,
                        transition: Transition.leftToRight,
                      ),
                    ),
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
      ..._parallelVersions.where((c) => c != mp.currentVersion),
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
                onPressed: () {
                  setState(() => _parallelMode = false);
                  _persistPrefs();
                },
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
                    onWordTap: (w, g) => _selectWord(w, g, book, verse),
                    onWordHover: _onWordHover,
                    onVerseTap: (n) =>
                        _moveBrowseCursor(localBook!, chapter, n),
                  ),
          ),
        ],
      ),
    );
  }

  /// A word was tapped. On a pad there is no hover at all, so tap has to
  /// do hover's whole job: latch the word AND bring the Word Study tab
  /// forward, since a readout behind an unselected tab looks broken.
  /// The full lexicon entry stays one click further in, from the pane.
  void _selectWord(
      OriginalWord w, List<String> grammar, String? book, int verse) {
    final locale = context.read<AppSettings>().locale;
    final label = book == null
        ? ''
        : '${localeAwareBookName(book, locale, context.read<MainProvider>().currentVersion)} '
            '${context.read<MainProvider>().currentChapter}:$verse';
    setState(() {
      _analysisWord = BrowseHover(
          word: w, reference: label, verse: verse, grammar: grammar);
      _analysisFrozen = false;
      _analysisTab = AnalysisTab.wordStudy;
      _rightOpen = true;
    });
    _persistPrefs();
  }

  /// The pointer moved onto (or off) an original-language word.
  ///
  /// One event, two lifetimes: the status bar tracks the pointer exactly
  /// and clears on exit, while the Analysis window latches the last
  /// word. Shift suspends the latch.
  void _onWordHover(BrowseHover? h) {
    final frozen = HardwareKeyboard.instance.isShiftPressed;
    final next = (h != null && !frozen) ? h : _analysisWord;
    bool same(BrowseHover? a, BrowseHover? b) =>
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

  /// Lets the reader choose which translations sit in the parallel stack.
  Future<void> _pickParallelVersions(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final current = _parallelVersions.toSet();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Versions in the parallel stack',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              for (final v in bibleVersions)
                CheckboxListTile(
                  dense: true,
                  value: current.contains(v.value),
                  title: Text(v.menuLabel),
                  subtitle: Text(v.shortLabel),
                  onChanged: (on) => setSheet(() {
                    if (on == true) {
                      current.add(v.value);
                    } else {
                      current.remove(v.value);
                    }
                  }),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _parallelVersions =
        bibleVersions.map((v) => v.value).where(current.contains).toList());
    _persistPrefs();
  }

  // ── Left: command pane ────────────────────────────────────────────

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
          Expanded(child: CommandPane(focusNode: _commandFocus)),
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

    // The word-study tab keeps OriginalsSheet's own header (it carries
    // the collapse chevron, and when embedded there is no `_paneHeader`
    // above it). The other two tabs are plain panes, so they get one.
    final needsHeader = _analysisTab != AnalysisTab.wordStudy;

    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          if (needsHeader)
            WbPaneTitle(
              title: uiStrings['analysisTitle']?[locale] ?? 'Analysis',
              trailing: [
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
            onChanged: (t) {
              setState(() => _analysisTab = t);
              _persistPrefs();
            },
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
            frozen: _analysisFrozen,
            grammar: hovered.grammar,
            onOpenFullEntry: () =>
                pushPage(StrongsEntryPage(number: hoveredWord.strongs)),
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
              onCollapse: () => _setRightOpen(false),
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
          onCollapse: () => _setRightOpen(false),
          onNavigateRef: _onAnalysisNavigateRef,
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
            return WordStatsPane(
              words: snap.data ?? const <OriginalWord>[],
              locale: locale,
              onOpenStrongs: (n) => pushPage(StrongsEntryPage(number: n)),
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
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
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
      width: 44,
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
