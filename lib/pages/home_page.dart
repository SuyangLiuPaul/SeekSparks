/// The standalone reader route.
///
/// As of #276 this page holds no capability the Workbench lacks. Split
/// View — the one thing that used to live only here — is now
/// `WbCentreMode.split` in the Workbench's own centre pane, and the two
/// `Get.off(() => const HomePage())` escapes from `WorkbenchPage` are
/// gone: leaving the route destroyed the command line, the search
/// results and the Analysis pane, which is a steep price for a layout
/// change.
///
/// It is deliberately still here, but its callers have thinned. The
/// library, highlights, evidence, trivia, timeline, family-tree and
/// lexicon pages used to push it directly; every one of them now goes
/// through `navigateToReader`, which returns to the Workbench instead
/// — pushing this page landed the classic single-pane reader ON TOP of
/// the workspace. What remains is the deep-link entry in
/// `open_reader.dart`, the boot route in `loading_page.dart`, and
/// `navigateToReader`'s own fallback for a root that is not a reader.
/// Retiring it is a product decision about whether the app has one
/// reading surface or two — not cleanup.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seeksparks/constants/bible_versions.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/fetch_books.dart';
import 'package:seeksparks/services/fetch_verses.dart';
import 'package:seeksparks/utils/chapter_across_editions.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/navigate_to_reader.dart'
    show kWorkbenchRouteName;
import 'package:seeksparks/widgets/sidebar_panel.dart';
import 'package:seeksparks/widgets/bible_reading_pane.dart';
import 'package:seeksparks/utils/responsive.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _sidebarOpen = false;
  bool _splitViewActive = false;
  MainProvider? _secondaryProvider;
  double _splitRatio = 0.5;
  double _splitWidthRatio = 0.5;

  // SeekSparks is desktop/tablet-first: on first layout, if the screen
  // is already tablet-width or wider, open the sidebar and activate
  // Split View by default — the two power-user affordances SeekSparks
  // otherwise leaves off until the user asks for them. Applied exactly
  // once per HomePage lifetime so a manual close/deactivate afterward
  // sticks (this isn't a "always force wide layout" rule, just a
  // better starting point on a big screen).
  bool _appliedDesktopDefaults = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedDesktopDefaults) return;
    _appliedDesktopDefaults = true;
    final width = MediaQuery.of(context).size.width;
    if (!ResponsiveBreakpoints.isTabletOrWider(width)) return;
    _sidebarOpen = true;
    // The sidebar earns its place from 600px up, but Split View needs
    // room for two readable columns — see `shouldAutoSplit`. Below
    // that the user can still open it themselves; the app just
    // doesn't assume it.
    if (!ResponsiveBreakpoints.shouldAutoSplit(width)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activateSplitView();
    });
  }

  @override
  void dispose() {
    _secondaryProvider?.dispose();
    super.dispose();
  }

  // ── Sidebar ─────────────────────────────────────────────────────────

  void _toggleSidebar() {
    setState(() => _sidebarOpen = !_sidebarOpen);
  }

  void _onSidebarChapterSelected(String book, int chapter) {
    final provider = context.read<MainProvider>();
    final matched = provider.verses
        .where((v) => v.book == book && v.chapter == chapter)
        .toList();
    if (matched.isEmpty) return;
    provider.setCurrentChapter(book: book, chapter: chapter);
    provider.updateCurrentVerse(verse: matched.first);
    // Round 56 fix: don't clobber a pendingJump set by the picker's
    // verse-pick step. Only slam to chapter top when no specific
    // verse jump was queued.
    if (!provider.hasPendingJump) {
      provider.jumpToTop();
    }
    setState(() {
      _sidebarOpen = false;
    });
  }

  // ── Split view ──────────────────────────────────────────────────────

  Future<void> _activateSplitView() async {
    if (_splitViewActive) return;
    final primary = context.read<MainProvider>();
    // Round 56: capture primary's current verse position BEFORE
    // the layout switches to side-by-side. The pane's State gets
    // remounted (parent type changes from Center → Row), so its
    // `_visibleItemIndex` resets to 0 and the SPL would otherwise
    // slam back to chapter top. We restore primary AND seed
    // secondary at the same verse number so both panes start
    // looking at the verse the user was reading.
    final preservedVerseNum = jumper.captureCurrentVerseNum(primary);

    final sp = MainProvider(storagePrefix: 'secondary_');
    setState(() {
      _splitViewActive = true;
      _secondaryProvider = sp;
    });

    // 2026-08-06: this used to be `sp.currentVersion =
    // primary.currentVersion`, which made Split View show the same
    // chapter in the same translation twice — half the screen spent
    // saying nothing. A comparison view has to compare something, so
    // seed a DIFFERENT version by default — see
    // `defaultSecondaryVersion`.
    //
    // If the user already picked a version in this pane, that choice
    // wins: `_persist` has always written `secondary_version`, but
    // nothing ever read it back, so their pick was discarded on every
    // reopen.
    //
    // 2026-09-05: through `resolveSecondaryVersion` rather than an
    // inline `availableVersions.any(...)`. The inline test was a THIRD
    // answer to a question the app already answers twice — the
    // workbench's own split column (`workbench_page.dart`) and the boot
    // warm-up (`workbench_warmup.dart`) both call the shared function —
    // and it differed in two ways that reach a reader. It did not
    // lower-case, so a stored code that had ever been written in mixed
    // case was discarded; and it had no `retiredVersionSuccessors` step,
    // so a reader whose second column held an edition retired between
    // releases got the generic default here while the warm-up had
    // already fetched the successor. `resolveSecondaryVersion`'s own
    // doc names that exact hazard: the two answering differently means
    // warming the wrong Bible.
    final prefs = await SharedPreferences.getInstance();
    sp.currentVersion = resolveSecondaryVersion(
      primaryVersion: primary.currentVersion,
      stored: prefs.getString(kSecondaryVersionKey),
    );
    await FetchVerses.execute(mainProvider: sp);
    await FetchBooks.execute(mainProvider: sp);

    if (!mounted) return;
    if (_secondaryProvider != sp) return; // deactivated while loading

    // Populate secondary's highlights from shared storage so the menu
    // item appears and verse highlights render immediately.
    await sp.reloadHighlights();

    if (!mounted || _secondaryProvider != sp) return;

    // Bidirectional highlight sync: when either pane mutates highlights,
    // push the updated map to the other pane's in-memory store.
    primary.onHighlightsMutated = () {
      _secondaryProvider?.syncHighlights(primary.highlights);
    };
    sp.onHighlightsMutated = () {
      primary.syncHighlights(sp.highlights);
    };

    // MATCHED IN ENGLISH, NEVER ON THE RAW STRINGS. `Verse.book` carries
    // the name the EDITION uses — 创世纪 in `cuvs-yhwh`, Genesis in
    // `bsb`/`kjv`/`leb`, measured on the shipped assets — so the raw
    // comparison this used to make found nothing whenever the two
    // columns were in different languages, which is the case Split View
    // is FOR. The `orElse` then handed back `sp.verses.first`, so a
    // reader on John 3 opened a second column on Genesis 1, and the
    // verse-number restore below scrolled it to Genesis 1:16. The
    // workbench's own second column fixed this in `_followPrimary` at
    // v1.6.47; this surface kept the old shape. Same rule now, from one
    // place — see `firstVerseOfChapterAcrossEditions`.
    //
    // The fallback to the corpus's first verse SURVIVES, and it has to:
    // `sp` is a provider constructed moments ago, so its `currentBook`
    // and `currentChapter` are still null and `FetchVerses` does not set
    // them — unlike the workbench's column, which is already on a
    // chapter and can simply be left there. What changes is that the
    // fallback is now only reachable when the edition really cannot
    // carry the passage (LJK V2 is Matthew only), instead of on every
    // cross-language open. See `seedChapterForNewColumn`, which also
    // stops `verses.first` throwing `StateError` on an edition that
    // failed to load.
    final seed = seedChapterForNewColumn(
      sp.verses,
      primary.currentBook,
      primary.currentChapter,
    );
    if (seed != null) {
      sp.setCurrentChapter(book: seed.book, chapter: seed.chapter);
      sp.updateCurrentVerse(verse: seed);
    }

    if (mounted && _secondaryProvider == sp) setState(() {});

    // After both panes have remounted in the new side-by-side
    // layout, scroll each to the preserved verse number. The
    // scroll fires through `addPostFrameCallback` inside
    // `scrollToVerseNumInChapter`, so it lands after the SPLs
    // finish their first layout pass.
    if (preservedVerseNum != null) {
      jumper.scrollToVerseNumInChapter(primary, preservedVerseNum);
      jumper.scrollToVerseNumInChapter(sp, preservedVerseNum);
    }
  }

  void _deactivateSplitView() {
    // Clear the cross-pane sync callback so primary no longer pushes to
    // a secondary that no longer exists.
    context.read<MainProvider>().onHighlightsMutated = null;
    setState(() {
      _splitViewActive = false;
      _secondaryProvider?.dispose();
      _secondaryProvider = null;
      _splitRatio = 0.5;
      _splitWidthRatio = 0.5;
    });
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mainProvider = context.watch<MainProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = ResponsiveBreakpoints.isTabletOrWider(screenWidth);
    final dc = ResponsiveBreakpoints.classOf(screenWidth);

    final showSidebar = isWideScreen && !_splitViewActive;
    final sidebarW =
        showSidebar && _sidebarOpen ? ResponsiveBreakpoints.sidebarWidth : 0.0;

    Widget primaryPane = BibleReadingPane(
      key: const ValueKey('primary'),
      // When the sidebar is already open it shows its own close button,
      // so we don't need a duplicate toggle in the reading pane header.
      showSidebarToggle: showSidebar && !_sidebarOpen,
      sidebarOpen: _sidebarOpen,
      onToggleSidebar: showSidebar ? _toggleSidebar : null,
      // Toggle direction tracks current state — when split is active the
      // primary's menu shows "Close Split View" and tapping it deactivates.
      onToggleSplitView:
          _splitViewActive ? _deactivateSplitView : _activateSplitView,
      splitViewActive: _splitViewActive,
      onClose: null,
      showSearchAndSettings: true,
      // 2026-08-04 (Workbench): overflow-menu entry that swaps this
      // classic reader for the three-pane study workspace (Get.off —
      // the Workbench REPLACES HomePage on the stack so Back returns
      // to the Dashboard, not to a duplicate reader).
      onOpenWorkbench: () => Get.off(
        () => const WorkbenchPage(),
        routeName: kWorkbenchRouteName,
        transition: Transition.rightToLeft,
      ),
    );

    if (!_splitViewActive || _secondaryProvider == null) {
      return _buildSinglePane(
          primaryPane, sidebarW, showSidebar, mainProvider, dc);
    }

    Widget secondaryPane = ChangeNotifierProvider<MainProvider>.value(
      value: _secondaryProvider!,
      child: BibleReadingPane(
        key: const ValueKey('secondary'),
        showSidebarToggle: false,
        sidebarOpen: false,
        onToggleSidebar: null,
        onToggleSplitView: null,
        splitViewActive: true,
        onClose: _deactivateSplitView,
        showSearchAndSettings: false,
      ),
    );

    if (isWideScreen) {
      return _buildSideBySide(primaryPane, secondaryPane);
    }
    return _buildTopBottom(primaryPane, secondaryPane);
  }

  // ── Layout methods ──────────────────────────────────────────────────

  Widget _buildSinglePane(
    Widget primaryPane,
    double sidebarW,
    bool showSidebar,
    MainProvider mainProvider,
    DeviceClass dc,
  ) {
    final maxW = ResponsiveBreakpoints.maxContentWidth(dc);

    if (!showSidebar) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: primaryPane,
        ),
      );
    }

    // Stack + AnimatedPositioned is the most reliable way to give the
    // sidebar both a bounded height (top:0 + bottom:0) and an animated
    // width. Earlier attempts using AnimatedContainer in a Row left the
    // sidebar's inner Expanded book-list collapsing to zero height on
    // Flutter web's HTML renderer.
    return Stack(
      // Expand fills the parent's constraints so the AnimatedPositioned
      // sidebar (top:0/bottom:0) gets the screen height, not just the
      // intrinsic height of the primary pane.
      fit: StackFit.expand,
      children: [
        // Main reading pane fills the screen; we use AnimatedPadding
        // so it slides right when the sidebar opens.
        AnimatedPadding(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.only(left: sidebarW),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: primaryPane,
            ),
          ),
        ),
        // Sidebar — Positioned with top:0/bottom:0 guarantees full
        // screen height; animated width handles open/close transition.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          left: 0,
          top: 0,
          bottom: 0,
          width: sidebarW,
          child: ClipRect(
            child: _sidebarOpen
                ? SidebarPanel(
                    currentBook: mainProvider.currentBook ?? '',
                    currentChapter: mainProvider.currentChapter ?? 1,
                    onChapterSelected: _onSidebarChapterSelected,
                    onClose: _toggleSidebar,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildSideBySide(Widget primaryPane, Widget secondaryPane) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const dividerWidth = 16.0;
        final availableWidth = totalWidth - dividerWidth;
        final leftWidth = (availableWidth * _splitWidthRatio)
            .clamp(availableWidth * 0.25, availableWidth * 0.75);
        final rightWidth = availableWidth - leftWidth;

        return Row(
          children: [
            SizedBox(width: leftWidth, child: primaryPane),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _splitWidthRatio =
                      (_splitWidthRatio + details.delta.dx / availableWidth)
                          .clamp(0.25, 0.75);
                });
              },
              child: Container(
                width: dividerWidth,
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
            SizedBox(width: rightWidth, child: secondaryPane),
          ],
        );
      },
    );
  }

  Widget _buildTopBottom(Widget primaryPane, Widget secondaryPane) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        const dividerHeight = 20.0;
        final availableHeight = totalHeight - dividerHeight;
        final topHeight = (availableHeight * _splitRatio)
            .clamp(availableHeight * 0.25, availableHeight * 0.75);
        final bottomHeight = availableHeight - topHeight;

        return Column(
          children: [
            SizedBox(height: topHeight, child: primaryPane),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                setState(() {
                  _splitRatio =
                      (_splitRatio + details.delta.dy / availableHeight)
                          .clamp(0.25, 0.75);
                });
              },
              child: Container(
                height: dividerHeight,
                width: double.infinity,
                color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.15),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outline.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: bottomHeight, child: secondaryPane),
          ],
        );
      },
    );
  }
}
