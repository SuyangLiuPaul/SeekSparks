import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/bible_versions.dart' show bibleVersions;
import 'package:seeksparks/constants/book_names.dart' show bookNameToEnglish;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/home_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/navigate_to_reader.dart'
    show kHomePageRouteName;
import 'package:seeksparks/utils/responsive.dart';
import 'package:seeksparks/widgets/bible_reading_pane.dart';
import 'package:seeksparks/widgets/command_pane.dart';
import 'package:seeksparks/pages/strongs_entry_page.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/widgets/originals_sheet.dart';
import 'package:seeksparks/widgets/parallel_verse_view.dart';

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
  bool _parallelMode = false;
  static const _kParallelKey = 'workbench.parallelMode';
  static const _kParallelVersionsKey = 'workbench.parallelVersions';
  List<String> _parallelVersions = const ['kjv', 'nasb', 'leb'];

  @override
  void initState() {
    super.initState();
    _wb = WorkbenchProvider(mainProvider: context.read<MainProvider>());
    _restorePrefs();
  }

  @override
  void dispose() {
    _wb.dispose();
    super.dispose();
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
      _parallelMode = prefs.getBool(_kParallelKey) ?? false;
      final saved = prefs.getStringList(_kParallelVersionsKey);
      if (saved != null && saved.isNotEmpty) _parallelVersions = saved;
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

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WorkbenchProvider>.value(
      value: _wb,
      child: Builder(
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

          return Scaffold(
            body: SafeArea(
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
                    child: _parallelMode
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
            ),
          );
        },
      ),
    );
  }

  // ── Centre: BibleWorks-style parallel Browse ──────────────────────

  /// Stacks the current verse across every selected version plus the
  /// original-language line — the BibleWorks Browse-window idiom. Falls
  /// back to verse 1 of the current chapter when nothing is selected.
  Widget _buildParallelFrame(BuildContext context) {
    final mp = context.watch<MainProvider>();
    final wb = context.watch<WorkbenchProvider>();
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;

    final sel = wb.analysisVerses.isNotEmpty ? wb.analysisVerses.first : null;
    final book = sel != null
        ? (bookNameToEnglish[sel.book] ?? sel.book)
        : (bookNameToEnglish[mp.currentBook ?? ''] ?? mp.currentBook);
    final chapter = sel?.chapter ?? mp.currentChapter;
    final verse = sel?.verse ?? 1;

    // Always include the reader's own version first, then the configured
    // comparison stack (deduplicated, order preserved).
    final codes = <String>[
      mp.currentVersion,
      ...
          _parallelVersions.where((c) => c != mp.currentVersion),
    ];

    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          _paneHeader(
            context,
            icon: Icons.view_agenda_rounded,
            title: uiStrings['parallelBrowse']?[locale] ?? 'Parallel',
            collapseIcon: Icons.menu_book_rounded,
            onCollapse: () {
              setState(() => _parallelMode = false);
              _persistPrefs();
            },
            settings: settings,
          ),
          const Divider(height: 1),
          Expanded(
            child: (book == null || chapter == null)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        uiStrings['parallelEmptyHint']?[locale] ??
                            'Open a chapter to compare versions side by side.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.outline, height: 1.6),
                      ),
                    ),
                  )
                : ParallelVerseView(
                    key: ValueKey('parallel-$book-$chapter-$verse-'
                        '${codes.join(",")}'),
                    book: book,
                    chapter: chapter,
                    verse: verse,
                    versionCodes: codes,
                    onWordTap: (w) => pushPage(StrongsEntryPage(number: w.strongs)),
                    onEditVersions: () => _pickParallelVersions(context),
                  ),
          ),
        ],
      ),
    );
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
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          _paneHeader(
            context,
            icon: Icons.manage_search_rounded,
            title: uiStrings['search']?[locale] ?? 'Search',
            collapseIcon: Icons.chevron_left_rounded,
            onCollapse: () => _setLeftOpen(false),
            settings: settings,
          ),
          const Divider(height: 1),
          const Expanded(child: CommandPane()),
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
      child: verses.isEmpty
          ? Column(
              children: [
                _paneHeader(
                  context,
                  icon: Icons.translate_rounded,
                  title: uiStrings['wordStudyTitle']?[locale] ?? 'Word Study',
                  collapseIcon: Icons.chevron_right_rounded,
                  onCollapse: () => _setRightOpen(false),
                  settings: settings,
                ),
                const Divider(height: 1),
                Expanded(
                  child: Center(
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
                  ),
                ),
              ],
            )
          // Key forces OriginalsSheet to re-run its load Future when
          // the selection changes (the sheet caches its Future in
          // initState, so a bare field swap wouldn't reload).
          : OriginalsSheet(
              key: ValueKey<String>(
                  'analysis-${verses.map((v) => v.id).join('|')}'),
              verses: verses,
              allVerses: mp.verses,
              locale: locale,
              currentVersion: mp.currentVersion,
              embedded: true,
              onCollapse: () => _setRightOpen(false),
              onNavigateRef: _onAnalysisNavigateRef,
            ),
    );
  }

  // ── Chrome: headers, dividers, collapsed rails ────────────────────

  Widget _paneHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required IconData collapseIcon,
    required VoidCallback onCollapse,
    required AppSettings settings,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: settings.fontSize,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: Icon(collapseIcon, size: 20),
            tooltip: uiStrings['collapsePanel']?[locale] ?? 'Collapse panel',
            onPressed: onCollapse,
          ),
        ],
      ),
    );
  }

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
