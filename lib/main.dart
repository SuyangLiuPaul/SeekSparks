import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/utils/page_links.dart' show pageForUrlPath;
import 'package:seeksparks/utils/app_scroll_behavior.dart';
import 'package:seeksparks/models/sermon.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/pages/loading_page.dart';
import 'package:seeksparks/pages/sermon_detail_page.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/sermon_service.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/open_reader.dart';
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/services/daily_verse_service.dart';
import 'package:seeksparks/services/error_reporter.dart';
import 'package:seeksparks/utils/breadcrumb_observer.dart';
import 'package:seeksparks/services/notification_scheduler.dart'
    as notif_scheduler;
import 'package:seeksparks/services/offline_pack_service.dart';
import 'package:seeksparks/services/fetch_books.dart';
import 'package:seeksparks/services/fetch_verses.dart';
import 'package:seeksparks/services/profile_service.dart';
import 'package:seeksparks/services/book_intro_service.dart';
import 'package:seeksparks/services/section_title_service.dart';
import 'package:seeksparks/services/url_sync_service.dart';
import 'package:seeksparks/services/workbench_warmup.dart'
    show warmWorkbenchFirstPaint;
import 'package:provider/provider.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/widgets/retired_version_notice.dart'
    show RetiredVersionNotice;
import 'package:seeksparks/widgets/small_screen_advisory.dart'
    show SmallScreenGate;
import 'package:seeksparks/utils/theme_accent.dart'
    show darkReadingAccent, onAccentColor;

void main() {
  // 2026-06-11 audit: silence debugPrint in release builds. ~100
  // callsites across services/pages log sync + auth detail; debugPrint
  // is NOT stripped from release builds, so on web all of it landed in
  // the browser console (information disclosure + log spam). One
  // global no-op here beats guarding every callsite. ErrorReporter is
  // unaffected — it reports via its own pipeline, not debugPrint.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // 2026-06-11 (v1.3.61): snapshot the deep-link hash before the
  // engine boots — by first frame, Flutter web reports the initial
  // route and overwrites the URL fragment, losing any shared link
  // (`#/revelation/17:1?v=biblexg-v2`) before UrlSyncService.init
  // gets to read it. Native targets no-op.
  UrlSyncService.captureBootHash();

  // 2026-08-08 (task #296): and clear any history bookkeeping the
  // browser restored from a previous document, before the engine can
  // act on it. Same deadline as the hash snapshot — the engine builds
  // its history object during the first frame.
  UrlSyncService.repairBootHistoryState();

  // 2026-05-24 (v1.3.21): wrap the whole entrypoint in
  // runZonedGuarded so uncaught zone errors (async work that
  // bubbles past PlatformDispatcher) still reach the reporter.
  // ErrorReporter.init() inside the zone installs the
  // FlutterError.onError + PlatformDispatcher hooks itself, so
  // we don't pre-set them here — ErrorReporter chains them
  // properly.
  runZonedGuarded<void>(() {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorReporter.init();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => MainProvider()),
          ChangeNotifierProvider(create: (context) => AppSettings()),
        ],
        child: const MainApp(),
      ),
    );
  }, (error, stack) {
    ErrorReporter.report(error, stack, source: 'Zone');
  });
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  bool _loading = true;

  /// Watchdog that forces the splash off after 4 s even if bootstrap
  /// is still grinding. Stored in a field (Round 56 audit fix) so we
  /// can cancel it on dispose — without this, hot-restart in dev or
  /// a fast unmount in prod would still tick and try to call
  /// setState on a disposed State.
  Timer? _splashWatchdog;

  @override
  void initState() {
    super.initState();
    // 2026-05-24 (v1.3.22): subscribe to lifecycle events so we can
    // receive `didHaveMemoryPressure()` callbacks from iOS / Android.
    // See the override below for the cache-drop behaviour.
    WidgetsBinding.instance.addObserver(this);
    _splashWatchdog = Timer(const Duration(seconds: 4), () {
      if (_loading && mounted) {
        setState(() {
          _loading = false;
        });
      }
    });
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _splashWatchdog?.cancel();
    super.dispose();
  }

  /// 2026-05-24 (v1.3.22): OS low-memory hook.
  ///
  /// Triggered by iOS `UIApplicationDidReceiveMemoryWarningNotification`
  /// or Android `onTrimMemory(TRIM_MEMORY_RUNNING_LOW)` /
  /// `TRIM_MEMORY_RUNNING_CRITICAL`. Before we shipped this hook the
  /// app held 13 parsed verse lists (~78 MB) + the paragraph LRU
  /// (~30 MB) + the Flutter image cache in RAM at all times. On
  /// iPhone-SE-class devices and mid-range Android the OS could
  /// silently terminate us with no chance to clean up — the user
  /// would just see the app "crash" when they backgrounded it.
  ///
  /// We now respond by dropping the three caches the OS most wants
  /// us to surrender. The reading pane's CURRENT verse list and
  /// paragraph map are unaffected — they're held via reference in
  /// the active providers, not the LRU.
  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    debugPrint('[v1.3.22] OS memory pressure — dropping caches');
    try {
      // Tier 1: Flutter image cache (avatars, evidence images, news
      // thumbs, illustrations).
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {/* ignore */}
    try {
      // Tier 2: verse + paragraph LRU caches on MainProvider.
      // Provider's dropCachesOnMemoryPressure() preserves the
      // currently-active version (drop only inactive entries).
      if (mounted) {
        context.read<MainProvider>().dropCachesOnMemoryPressure();
      }
    } catch (_) {/* ignore */}
    // Leave a breadcrumb so the error monitor knows we cleared
    // caches — useful context if a crash follows shortly after.
    ErrorReporter.breadcrumb('memory:pressure', data: 'caches dropped');
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final mainProvider = context.read<MainProvider>();
    final appSettings = context.read<AppSettings>();

    try {
      // Profiles must be initialised before MainProvider.restoreState
      // because that step reads highlights / notes / bookmarks under
      // the active profile's namespace. Same goes for ReadingPlanService
      // calls that fire while the home page builds.
      await ProfileService.instance.init();
      // 2026-08-08 (v1.6.62 — one worldwide build): boot reaches no
      // Google host, by construction. Firebase Auth + Realtime
      // Database sync used to be awaited here behind an 8 s cap,
      // because `Firebase.initializeApp()` and
      // `auth.getRedirectResult()` both talk to `*.googleapis.com` —
      // unreachable from mainland China, so a reader there paid the
      // whole timeout before a single verse was parsed. The old
      // answer was a second CHINA_MODE build that skipped this
      // branch; the new answer is that the branch is gone.
      //
      // INVARIANT: nothing between here and the first painted verse
      // may touch the network. Anything added below must be
      // bundled-asset work or explicitly unawaited.
      // 2026-05-07 (v18 audit): the three pre-warm calls below are
      // intentionally unawaited (best-effort hydration that should
      // not block the splash → home transition). But silently
      // dropping their failures meant a stuck cache in production
      // never surfaced. We attach a debug-only catchError so the
      // failure shows up in the browser console without escalating
      // to a user-facing error.
      // Restore "what's been pre-downloaded for offline" so the
      // Settings → Offline Pack card can render an accurate label
      // on first paint instead of flickering "Not downloaded".
      // ignore: unawaited_futures
      OfflinePackService.instance.hydrate().catchError((Object e, StackTrace st) {
        debugPrint('OfflinePackService.hydrate failed: $e\n$st');
      });
      // Pre-warm the section-titles cache so the first chapter
      // render already has paragraph headings ready.
      // ignore: unawaited_futures
      SectionTitleService.ensureLoaded().catchError((Object e, StackTrace st) {
        debugPrint('SectionTitleService.ensureLoaded failed: $e\n$st');
      });
      // ignore: unawaited_futures
      BookIntroService.ensureLoaded().catchError((Object e, StackTrace st) {
        debugPrint('BookIntroService.ensureLoaded failed: $e\n$st');
      });
      // 2026-05-19 (v1.2.55): reverted the v1.2.53 cross-version
      // LEB translator-insights overlay. User feedback: "remove
      // that LEB notes format from all other versions" — LEB's
      // notes are tied to LEB's specific phrasing, so projecting
      // them into KJV / CUV / CNV pages was noisy and tonally
      // off. The inline `[supplied]` / `{clarification}` +
      // `<note:>` format that's NATIVELY in LEB + biblexg-v2
      // continues to render as before; only the cross-version
      // overlay layer was dropped.
      await appSettings.loadSettings();
      await mainProvider.restoreState();

      if (mainProvider.verses.isEmpty) {
        // 2026-05-10 (v1.2.10): pass an onAttempt callback so the
        // loading splash can show "Retrying… (2/3)" instead of just
        // sitting on the logo while a transient asset-fetch failure
        // gets retried. The default 3 attempts × 12 s timeout means
        // up to ~37 s wall-clock before we bail to the manual
        // error scaffold — but in practice the first attempt
        // succeeds within a couple seconds.
        await FetchVerses.execute(
          mainProvider: mainProvider,
          onAttempt: (attempt, _) =>
              mainProvider.setLoadProgress(attempt, 3),
        );
      }
      await FetchBooks.execute(mainProvider: mainProvider);
      // Clear the in-flight progress now that the load settled
      // (whether it succeeded or threw — the catch block below also
      // resets it). Splash subtitle disappears.
      mainProvider.setLoadProgress(0, 0);

      if (mainProvider.verses.isEmpty) {
        mainProvider.setLoadError('empty');
      } else {
        mainProvider.setLoadError(null);
      }

      // Validate restored state or fallback
      if (mainProvider.currentBook != null &&
          mainProvider.currentChapter != null &&
          mainProvider.verses.any((v) =>
              v.book == mainProvider.currentBook &&
              v.chapter == mainProvider.currentChapter)) {
        final match = mainProvider.verses.firstWhere(
          (v) =>
              v.book == mainProvider.currentBook &&
              v.chapter == mainProvider.currentChapter,
          orElse: () => mainProvider.verses.first,
        );
        mainProvider.updateCurrentVerse(verse: match);
      } else if (mainProvider.verses.isNotEmpty) {
        final firstVerse = mainProvider.verses.first;
        mainProvider.setCurrentChapter(
            book: firstVerse.book, chapter: firstVerse.chapter);
        mainProvider.updateCurrentVerse(verse: firstVerse);
      }
    } catch (e, st) {
      debugPrint('Bootstrap failed: $e\n$st');
      mainProvider.setLoadError(e.toString());
      // Clear the splash subtitle on failure too — the load-error
      // scaffold takes over from here.
      mainProvider.setLoadProgress(0, 0);
    }

    // 2026-05-10 (v1.2.25 — restored eager-all-13): user noticed
    // the splash showed "Loading versions: 4/4" instead of all 13
    // and chose option B (slower boot, splash shows full 1/13 →
    // 13/13 progress, every post-boot switch is instant for the
    // entire session). Reverts the v1.2.22 hybrid split back to
    // v1.2.18's all-eager pattern but inherits the v1.2.19+
    // bug fixes (paragraph-cache LRU evict on version switch,
    // pendingJump clear, etc).
    //
    // 2026-05-24 (v1.3.4) PERF: NON-BLOCKING version preload.
    // v1.2.25 made this `await`-blocking, so splash sat for ~25 s
    // until all 13 Bible versions had been json.decode'd into the
    // in-memory LRU. User: "performance improve entirely". The
    // cold-start wait was by far the most visible perf cost.
    //
    // New: fire-and-forget. The user's active version is already
    // loaded above (via setVerses from FetchVerses). All OTHER
    // versions stream into the LRU in the background, one at a
    // time, after splash dismisses. The user can read / navigate /
    // search immediately; if they switch to an un-loaded version
    // before its background load completes, the on-demand
    // FetchVerses path (already wired for this case) loads it
    // synchronously in ~1 s. Most users stay on one or two
    // versions and never notice.
    //
    // Memory parity: same final state (~78 MB across all
    // versions); only the timing of when the slots fill changes.
    // 2026-06-11 (v1.3.61) PERF: web no longer eager-preloads the other
    // 12 versions. On native that loop reads local asset files — cheap,
    // and it's what makes version switches instant. On WEB each version
    // is a network download (0.5–1.4 MB brotli each, ~10 MB+ per cold
    // session in total) plus a main-thread json.decode of a 2–9 MB
    // string — real mobile data cost and visible jank while the user is
    // already reading. The on-demand switch path (FetchVerses) loads a
    // version in ~1–2 s when actually requested, and the service worker
    // caches each fetched bundle so later sessions are instant anyway.
    if (mainProvider.verses.isNotEmpty && !kIsWeb) {
      // ignore: unawaited_futures
      _eagerPreloadAllVersions(mainProvider).catchError(
          (Object e, StackTrace st) =>
              debugPrint('background version preload failed: $e'));
    }

    // 2026-08-08 (#274): warm the centre pane while the splash is idle.
    // Measured on the deployed dev build: every boot asset settles by
    // ~1 s, the splash then holds for its fixed 3 s, and only after it
    // dismisses does the Browse stack begin fetching the comparison
    // editions — ~4.3 MB on a cold cache, downloaded while the reader
    // is already staring at an empty column. This does that work in the
    // three seconds nobody was using. Fire-and-forget: boot never waits
    // on it, and anything it misses the pane still loads itself.
    // ignore: unawaited_futures
    warmWorkbenchFirstPaint(
      mainProvider: mainProvider,
      locale: appSettings.locale,
    ).catchError((Object e, StackTrace st) =>
        debugPrint('workbench warm-up failed: $e\n$st'));

    // 2026-05-24 (v1.3.2): eager-preload the daily-verses pool so
    // the splash's todayRef() lookup is synchronous-fast and
    // doesn't race with the splash's fallback timer. Fire-and-
    // forget — the result is cached inside DailyVerseService and
    // any callers that arrive before the load completes await on
    // the same in-flight Future via the service's internal
    // `_loading` guard.
    // ignore: unawaited_futures
    DailyVerseService.preload();

    // 2026-05-19 (v1.2.54): URL sync layer — keep the browser URL
    // in lockstep with the reader state (book / chapter / verse /
    // version). Web-only: native targets dispatch to the no-op
    // stub. Runs AFTER restoreState + FetchVerses so the boot URL
    // (if any) sees a populated `mp.verses` and can find the
    // referenced book + chapter / verse. On native, this is a
    // single function call that returns immediately.
    // ignore: unawaited_futures
    UrlSyncService.init(
      mainProvider: mainProvider,
      appSettings: appSettings,
    ).catchError((Object e, StackTrace st) {
      debugPrint('UrlSyncService.init failed: $e\n$st');
    });

    // 2026-05-24 (v1.3.0): refresh scheduled notification content on
    // every cold start. Cancels stale fires and re-creates the
    // enabled categories with today's verse / evidence / sermon.
    // Fire-and-forget — scheduler init is internally guarded so it
    // can't block app launch.
    // ignore: unawaited_futures
    notif_scheduler.rescheduleAll(appSettings).catchError(
      (Object e, StackTrace st) =>
          debugPrint('notif scheduler init failed: $e'),
    );

    // Clears the false-positive "Failed to load" window — see
    // MainProvider.bootInFlight doc comment. Set before the `_loading`
    // setState so LoadingPage's very next build already sees the
    // accurate state, regardless of which listener rebuilds first.
    mainProvider.setBootInFlight(false);

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  /// 2026-05-10 (v1.2.25 — restored from v1.2.18): eager pre-load
  /// of ALL bundled Bible versions before the splash dismisses. User
  /// chose this trade ("反正第一次用才 load version") again after
  /// noticing v1.2.22's hybrid stopped at "4/4" in the splash
  /// progress.
  ///
  /// Sequential, no-gap parse of the non-active versions. Updates
  /// `MainProvider.versionPreloadProgress` so the splash paints
  /// "Loading versions: n/total" while the user waits.
  ///
  /// 2026-08 (ported from YsWords v1.4.0): CUV / CUV-tr / CNV / CNV-tr /
  /// biblexg (LJK1) / biblexg-tr were REMOVED from the candidate list —
  /// those versions were deleted outright (superseded by cuvs-yhwh /
  /// biblexg-v2; see lib/constants/bible_versions.dart). This also cuts
  /// real boot time: cuv/cuv-tr/cnv/cnv-tr were among the largest bundled
  /// assets (~6.7-7 MB each), so the splash now has noticeably less to
  /// parse.
  ///
  /// Order: simplified Chinese staples (largest user base) →
  /// English → traditional Chinese → LJK2 NT-only specialty.
  /// Most-likely-next picks land in the LRU first, so even if
  /// the user is impatient and force-quits during pre-load,
  /// the first session-start switches still hit the cache.
  ///
  /// `preloadVersion` is best-effort — swallows failures so a
  /// single missing asset doesn't block boot.
  Future<void> _eagerPreloadAllVersions(MainProvider mainProvider) async {
    if (!mounted) return;
    const candidates = <String>[
      // Simplified Chinese staple — largest user base.
      'cuvs-yhwh',
      // English flagships.
      'kjv',
      'nasb',
      'leb',
      // Traditional Chinese variant.
      'cuvs-yhwh-tr',
      // LJK2 — NT-only specialty translation.
      'biblexg-v2',
      'biblexg-v2-tr',
    ];
    final toLoad =
        candidates.where((v) => v != mainProvider.currentVersion).toList();
    final total = toLoad.length;
    for (int i = 0; i < total; i++) {
      if (!mounted) return;
      mainProvider.setVersionPreloadProgress(i + 1, total);
      // Yield once per iteration so the splash actually repaints
      // before the next ~1 s json.decode hogs the main thread.
      await Future<void>.delayed(Duration.zero);
      await mainProvider.preloadVersion(toLoad[i]);
    }
    if (!mounted) return;
    mainProvider.setVersionPreloadProgress(0, 0);
    debugPrint('Eager pre-load complete: $total versions');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
        // v1.3.21: keep ErrorReporter informed of the current
        // locale so crash reports show which language string was
        // on screen. Cheap call — early-returns when unchanged.
        ErrorReporter.setLocale(settings.locale);
        // Round 56: switched from `colorSchemeSeed` (default
        // tonal-palette variant) to an explicit
        // `ColorScheme.fromSeed(... vibrant ...)`. The default
        // Material-3 mapping desaturates the seed quite hard, so a
        // user picking pure red would see a muted brick on the app —
        // the user's complaint of "the color doesn't seem to affect
        // the app much". The `vibrant` variant pushes primary much
        // closer to the seed, with high-chroma accents on every
        // Material widget that uses `scheme.primary`.
        final lightScheme = ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        );
        // 2026-06-13 (v1.3.68): dark mode now tracks the user's chosen
        // theme colour like light mode does. Material-3's
        // `fromSeed(... dark ...)` maps `primary` to a pale, low-chroma
        // tone-80 of the seed — so verse numbers, note/bookmark glyphs,
        // and section headers (all of which read `colorScheme.primary`,
        // see lib/utils/build_verse_content_spans.dart) looked washed-out
        // and generic in dark mode, NOT the hue the user picked (user
        // report: "dark mode 没有根据 theme color"). We keep the seeded
        // palette for every container / surface / error tone (the dark
        // AppBar deliberately stays on `primaryContainer`, which is the
        // low-chroma tint that reads well at the top of the screen), and
        // only override `primary` (+ its contrast `onPrimary`) with a
        // hue-faithful, dark-legible derivation of the seed. That keeps
        // the chosen colour recognisable on every accent without making
        // the AppBar garish.
        final seededDark = ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        );
        final darkAccent = darkReadingAccent(settings.primaryColor);
        final darkScheme = seededDark.copyWith(
          primary: darkAccent,
          onPrimary: onAccentColor(darkAccent),
        );
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          // 2026-06-28 (v1.3.111): graceful fallback for UNKNOWN named routes.
          // Diagnosed by source-map-deobfuscating a prod (v1.3.102) crash
          // report ("Null check operator used on a null value", Android web):
          // on Flutter web a browser/back/deep-link navigation to a URL path
          // the app doesn't register reaches the Navigator with an unknown
          // route name. The app sets only `home:` (no routes/onGenerateRoute),
          // so Flutter fell through to `onUnknownRoute` — which was null —
          // crashing inside `_WidgetsAppState._onUnknownRoute`. Answering
          // every unknown route means a stray URL never crashes. What it
          // gets answered WITH is [appUnknownRoute] — see there for why
          // "the app root, always" was itself a bug.
          onUnknownRoute: appUnknownRoute,
          themeMode: settings.themeMode,
          // 2026-08-06: SeekSparks is a study tool, not a reading app,
          // and the whole product should read as one, so the Workbench's
          // dense BibleWorks theme is the app's only theme.
          //
          // 2026-08-24 (#315): this comment used to say the workbench
          // theme was "layered OVER the app's own ThemeData rather than
          // replacing it, so the font settings … still apply". It
          // replaces it. `workbenchTheme` builds from a fresh
          // `ThemeData.light/dark` and reads exactly two things off the
          // theme passed in — brightness and `fontFamilyFallback` — so
          // the sizes set below were overwritten one line later, and the
          // reader's Font Size reached no Material text anywhere in the
          // app. The scale is passed in explicitly now; the measurement
          // and the rest of the story are on `workbenchTheme` itself.
          theme: workbenchTheme(
              textScale: WbType.scaleFor(settings.fontSize),
              ThemeData(
            fontFamily: settings.fontFamily,
            // 2026-05-08 (v1.1.0 — Liquid Glass / v1.1.2 — system
            // defaults): a comprehensive OS-native font fallback
            // chain. Each entry tries the next platform's
            // canonical UI font; the first one Flutter / the
            // browser can resolve wins. Order:
            //   • CJK fallback (bundled) → NotoSansSC-Sub — added
            //     2026-05-24 v1.3.31; works on Flutter web CanvasKit
            //     where the CSS-only system fonts below are invisible
            //     to Skia. See `lib/utils/font_catalog.dart` for the
            //     full rationale.
            //   • Apple devices → -apple-system / SF Pro
            //   • Windows → Segoe UI
            //   • Android → Roboto
            //   • Linux GNOME → Cantarell
            //   • Linux KDE / generic → Noto Sans
            //   • CJK fallback → 微软雅黑 / 思源黑体
            //   • Universal → Arial / Helvetica / sans-serif
            // The 'system' font option in the catalogue routes to
            // the leading -apple-system token, which on every
            // non-Apple platform falls through this list naturally.
            fontFamilyFallback: const [
              '-apple-system',
              'BlinkMacSystemFont',
              'SF Pro Text',
              'SF Pro',
              'Segoe UI',
              'Helvetica Neue',
              'Cantarell',
              'Noto Sans',
              // 2026-05-24 (v1.3.31): bundled CJK subset goes here in
              // the global theme so EVERY widget (AppBar titles, menu
              // labels, dialog text, etc.) gets CJK coverage on web.
              // Verse text + word spans already use kCjkFontFallback
              // which has the same entry. Cheap to list twice — the
              // engine just walks until it finds a glyph.
              'NotoSansSC-Sub',
              // 2026-08-08 (v1.6.73): the same argument for Hebrew,
              // polytonic Greek and transliteration diacritics. Without
              // a registered face the engine fetches one from
              // fonts.gstatic.com, and CanvasKit draws a font it could
              // not fetch as nothing at all.
              'NotoSansHebrew-Sub',
              'NotoSansExt-Sub',
              'NotoSansSymbols2-Sub',
              'Microsoft YaHei',
              '微软雅黑',
              'Source Han Sans SC',
              '思源黑体',
              'PingFang SC',
              'Roboto',
              'Arial',
              'Helvetica',
              'sans-serif',
            ],
            textTheme: ThemeData.light().textTheme.copyWith(
                  bodyLarge: ThemeData.light().textTheme.bodyLarge?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      ),
                  bodyMedium: ThemeData.light().textTheme.bodyMedium?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      ),
                  titleLarge: ThemeData.light().textTheme.titleLarge?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      ),
                ),
            colorScheme: lightScheme,
            // 2026-08 (ported from YsWords v1.4.5): one ripple on every
            // platform. Flutter's own Material 3 default only uses
            // InkSparkle off-web (its fragment shader isn't supported on
            // every web renderer), so leaving it to the default gives web
            // a different ripple than native. Pinning InkRipple — which
            // is web-safe and what web already falls back to — makes the
            // press feedback identical everywhere.
            splashFactory: InkRipple.splashFactory,
            // 2026-05-08 (v1.1.0): Card & Dialog corner radii bumped
            // to 18 to match Apple's iOS 26 shape language (concentric
            // with the new 24-radius outer surfaces). The app's bespoke
            // Container-backed cards (welcome disclaimer, feedback
            // intro, etc) get the LiquidGlassCard primitive directly;
            // every Card(...) inherits from this theme.
            cardTheme: CardThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            // Tint the AppBar with primary so the user's chosen color
            // is immediately visible at the top of every page, not
            // just on FAB / Switch / Slider accents. Foreground is
            // `onPrimary` (white on saturated colors, dark on light
            // pastels — ColorScheme.fromSeed picks the right contrast).
            appBarTheme: AppBarTheme(
              backgroundColor: lightScheme.primary,
              foregroundColor: lightScheme.onPrimary,
              elevation: 0,
            ),
            // Round 56: explicit TabBar colours so tabs hosted in
            // a primary-coloured AppBar stay readable. Default
            // labelColor inherits AppBar foreground but unselected
            // tabs get a low-opacity treatment that user reported
            // as "看不清". Force selected = full onPrimary,
            // unselected = onPrimary @ 78% — clearly distinct
            // states without sacrificing contrast.
            tabBarTheme: TabBarThemeData(
              labelColor: lightScheme.onPrimary,
              unselectedLabelColor:
                  lightScheme.onPrimary.withValues(alpha: 0.78),
              indicatorColor: lightScheme.onPrimary,
            ),
          )),
          darkTheme: workbenchTheme(
              textScale: WbType.scaleFor(settings.fontSize),
              ThemeData(
            fontFamily: settings.fontFamily,
            // 2026-05-08 (v1.1.0 / v1.1.2): same comprehensive OS-
            // native font fallback chain as light theme. See light
            // theme above for the rationale + per-platform mapping.
            // 2026-05-24 (v1.3.31): bundled NotoSansSC-Sub added
            // for CanvasKit CJK coverage (see light theme comment).
            fontFamilyFallback: const [
              '-apple-system',
              'BlinkMacSystemFont',
              'SF Pro Text',
              'SF Pro',
              'Segoe UI',
              'Helvetica Neue',
              'Cantarell',
              'Noto Sans',
              'NotoSansSC-Sub',
              'NotoSansHebrew-Sub',
              'NotoSansExt-Sub',
              'NotoSansSymbols2-Sub',
              'Microsoft YaHei',
              '微软雅黑',
              'Source Han Sans SC',
              '思源黑体',
              'PingFang SC',
              'Roboto',
              'Arial',
              'Helvetica',
              'sans-serif',
            ],
            textTheme: ThemeData.dark().textTheme.copyWith(
                  bodyLarge: ThemeData.dark().textTheme.bodyLarge?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        color: Color(0xFFCCCCCC),
                      ),
                  bodyMedium: ThemeData.dark().textTheme.bodyMedium?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        color: Color(0xFFCCCCCC),
                      ),
                  titleLarge: ThemeData.dark().textTheme.titleLarge?.copyWith(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        color: Color(0xFFCCCCCC),
                      ),
                ),
            inputDecorationTheme: InputDecorationTheme(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF888888)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFCCCCCC), width: 2),
              ),
              hintStyle: TextStyle(color: Color(0xFFAAAAAA)),
            ),
            colorScheme: darkScheme,
            brightness: Brightness.dark,
            // 2026-08 (ported from YsWords v1.4.5): mirror of the light
            // theme — see the InkRipple rationale there.
            splashFactory: InkRipple.splashFactory,
            cardTheme: CardThemeData(
              color: Color(0xFF1F1F1F),
              elevation: 2,
              // 2026-05-08 (v1.1.0): bumped from 8 to 18 to match
              // light theme's new concentric-with-Liquid-Glass radii.
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            // Dark AppBar uses primaryContainer (a low-chroma dark
            // tint of the user's color) instead of primary itself —
            // a saturated AppBar bg in dark mode reads as garish. The
            // primary still shows up on FAB / Switch / Slider /
            // selected chips / section headers via scheme.primary.
            appBarTheme: AppBarTheme(
              backgroundColor: darkScheme.primaryContainer,
              foregroundColor: darkScheme.onPrimaryContainer,
              elevation: 0,
            ),
            tabBarTheme: TabBarThemeData(
              labelColor: darkScheme.onPrimaryContainer,
              unselectedLabelColor:
                  darkScheme.onPrimaryContainer.withValues(alpha: 0.78),
              indicatorColor: darkScheme.onPrimaryContainer,
            ),
            sliderTheme: const SliderThemeData(
              inactiveTrackColor: Color(0xFF424242),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF333333),
                foregroundColor: Color(0xFFCCCCCC),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFFCCCCCC),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFFCCCCCC),
                side: BorderSide(color: Color(0xFFCCCCCC)),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Color(0xFF1E1E1E),
              titleTextStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: settings.fontSize + 2,
                fontWeight: FontWeight.bold,
              ),
              contentTextStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: settings.fontSize,
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: Color(0xFF2C2C2C),
              contentTextStyle: TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: settings.fontSize * 0.85,
              ),
            ),
            dividerColor: Color(0xFF424242),
            iconTheme: const IconThemeData(
              color: Color(0xFFCCCCCC),
            ),
          )),
          builder: (context, child) {
            return ScrollConfiguration(
              // 2026-08 (ported from YsWords v1.4.5): AppScrollBehavior
              // adds bouncy physics to EVERY scrollable app-wide (see its
              // doc comment) instead of a per-widget opt-in that only
              // covers a fraction of the list files. `scrollbars: true`
              // is preserved.
              behavior: const AppScrollBehavior().copyWith(scrollbars: true),
              child: child!,
            );
          },
          // 2026-05-24 (v1.3.21): BreadcrumbObserver auto-records
          // every push/pop so error reports include the navigation
          // trail leading up to the crash.
          navigatorObservers: [BreadcrumbObserver(), _UrlRestoreObserver()],
          // 2026-08-08: the gate sits ABOVE the splash, not below it.
          // It used to wrap only WorkbenchPage, three screens deep —
          // past the boot watchdog, past LoadingPage's 3 s auto-advance
          // — so a phone reader watched the full cold boot (every
          // bundled Bible parsed) before being told SeekSparks needs a
          // tablet, and any boot that failed to advance meant they were
          // never told at all. That is the v1.6.56 "stuck on the splash"
          // report. Whether this viewport can carry the workbench is
          // known on the first frame and depends on nothing the boot
          // produces, so it is answered on the first frame.
          home: SmallScreenGate(
            // Above the router and below the gate: boot may have
            // substituted a retired reading version, and the reader is
            // owed that fact wherever they land. Renders its child
            // untouched until there is something to say.
            child: RetiredVersionNotice(
              child: _loading
                  ? const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _RootRouter(
                      initialVerses: Provider.of<MainProvider>(context,
                              listen: false)
                          .verses,
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// The route the app answers a name it does not register with.
///
/// 2026-09-02: a name it does not register is not the same thing as a
/// name it does not KNOW. `#/wheel` is a real page — the chronology
/// wheel claims that path while it is open, so it is what a shared wheel
/// link says and what a wheel history entry holds — but it is not a
/// registered route, because the app declares no `routes` map at all.
///
/// On the web that difference is the whole bug. A COLD open is fine:
/// `main()` snapshots the fragment and `_RootRouter` opens the page on
/// its first post-splash frame. But a fragment that changes in a LIVE
/// tab — the reader edits the address bar, or presses Back / Forward
/// onto a `#/wheel` entry — is a same-document navigation, so the engine
/// does not restart the app; it hands the framework
/// `pushRoute('/wheel')`, which lands here. This handler used to answer
/// every unknown name with the app root, so what it pushed was a SECOND
/// `_RootRouter` — another workbench, freshly mounted at Genesis 1, on
/// top of whatever was showing, while the address bar read `#/wheel` and
/// the wheel never opened. That is exactly the report this fixes;
/// verified against the release build with the route logged.
///
/// So: ask [pageForUrlPath] first, and fall back to the app root only
/// for a name that really is stray. (Get.to(...) pushes anonymous
/// routes and is unaffected by this handler.)
@visibleForTesting
Route<dynamic> appUnknownRoute(RouteSettings settings) {
  final page = pageForUrlPath(settings.name);
  if (page != null) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => page,
    );
  }
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (ctx) => _RootRouter(
      initialVerses: Provider.of<MainProvider>(ctx, listen: false).verses,
    ),
  );
}

/// v1.3.62 UX: the web engine writes the pushed route's minified name
/// into the URL fragment (`#/minified:Xt`), clobbering the canonical
/// share link. This observer asks the URL-sync layer to restore the
/// proper `#/<book>/<chapter>?v=` fragment shortly after every
/// push/pop. No-op on native (stub dispatch).
class _UrlRestoreObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      UrlSyncService.onRouteChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      UrlSyncService.onRouteChanged();
}

class _RootRouter extends StatefulWidget {
  final List<Verse> initialVerses;
  const _RootRouter({required this.initialVerses});

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  /// The splash is a cold-start affordance, and as of 2026-08-08 this
  /// router can be torn down mid-session: SmallScreenGate wraps `home:`,
  /// so dragging a desktop window below the workbench's width and back
  /// unmounts and remounts this subtree. Replaying the splash on the way
  /// back would be a regression introduced by that move, so "the splash
  /// has been shown" is session state rather than widget state.
  static bool _splashDone = false;

  bool _showHome = _splashDone;
  bool _deepLinkHandled = false;

  /// v1.3.62 UX: set (via the UrlSyncService callback) when a boot
  /// hash deep link (`#/<book>/<ch>?v=`) was applied — the next home
  /// build pushes the reader so shared links open the verse directly
  /// instead of parking the user on the Dashboard. A flag + rebuild
  /// (rather than navigating from the callback) because the apply can
  /// finish before OR after the home page appears.
  bool _bootHashLandingPending = false;

  /// A shared page link is opened once and only once.
  bool _bootPageOpened = false;

  @override
  void initState() {
    super.initState();
    UrlSyncService.setBootDeepLinkCallback(() {
      if (!mounted) return;
      setState(() => _bootHashLandingPending = true);
    });
  }

  void _advance() {
    if (!mounted || _showHome) return;
    _splashDone = true;
    setState(() => _showHome = true);
    _handleDeepLink();
  }

  /// On first show of the home page, inspect the URL for share
  /// query parameters (`?sermon=ID` or
  /// `?verse=Book:Chapter:Verse`) and auto-navigate to the
  /// referenced content. Lets shared links from the app's share
  /// buttons actually open what they promise.
  Future<void> _handleDeepLink() async {
    if (_deepLinkHandled) return;
    _deepLinkHandled = true;

    Uri? uri;
    try {
      uri = Uri.base;
    } catch (_) {
      return;
    }
    final params = uri.queryParameters;
    final sermonId = params['sermon'];
    if (sermonId != null && sermonId.isNotEmpty) {
      // Deferred so the dashboard finishes building first.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final svc = SermonService.instance;
        final all = await svc.loadIndex();
        Sermon? s;
        for (final c in all) {
          if (c.id == sermonId) {
            s = c;
            break;
          }
        }
        if (s != null && mounted) {
          pushPage(SermonDetailPage(sermon: s));
        }
      });
      return;
    }
    final verse = params['verse'];
    if (verse != null && verse.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final parts = verse.split(':');
        if (parts.length != 3) return;
        final book = parts[0];
        final ch = int.tryParse(parts[1]);
        final v = int.tryParse(parts[2]);
        if (ch == null || v == null || !mounted) return;
        final ref = BibleReference(
            englishBook: book, chapter: ch, verseStart: v, verseEnd: v);
        final mp = context.read<MainProvider>();
        final result = await jumper.resolveAndPrepareJump(
            reference: ref, mp: mp);
        if (!mounted) return;
        await jumper.showJumpResultSnackBar(context, result);
        if (!mounted) return;
        // 2026-05-24 (v1.3.6): explicit routeName so the
        // verse_popup_sheet "Open in Reader" path can detect an
        // existing reader in the stack and pop to it instead of
        // pushing a duplicate. Get's auto-name resolves the
        // closure's runtimeType to something unpredictable like
        // `/_Closure` — explicit route names are the only reliable
        // detection key. 2026-08-04: openReader picks Workbench vs
        // HomePage by width and passes the right routeName itself.
        openReader(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2026-08 (SeekSparks): the boot deep link used to push the reader
    // on top of the dashboard root. The root IS the reader now, so that
    // push stacked a SECOND Workbench over the first — two Search panes
    // side by side. URL-sync has already applied the book/chapter by
    // this point, so simply consuming the flag is enough.
    if (_showHome && _bootHashLandingPending) {
      _bootHashLandingPending = false;
    }

    // 2026-08-24: a shared PAGE link — a full-screen page that owned
    // the URL while it was open, e.g. `#/wheel`.
    //
    // Opened HERE, after the first frame, rather than from
    // _handleDeepLink: the root of this app IS the workbench, so at
    // deep-link time there is no Navigator above it to push onto and
    // the push was silently doing nothing — a shared wheel link kept
    // landing people on Genesis 1, which is the whole bug.
    //
    // 2026-09-02: this covers the COLD open only, and reading it as the
    // whole fix is what let the same symptom survive it. A fragment that
    // changes in a live tab never restarts the app, so it never reaches
    // this branch — it arrives as a named route instead. See
    // [appUnknownRoute], which answers the other door with the same
    // [pageForUrlPath] lookup used here.
    if (_showHome && !_bootPageOpened) {
      final page = pageForUrlPath(UrlSyncService.bootPagePath());
      if (page != null) {
        _bootPageOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => page));
        });
      }
    }
    // 2026-08 (SeekSparks): the study workspace is the root, not a
    // dashboard. SeekSparks is a Bible STUDY tool, not a devotional
    // reader — landing on a greeting + verse-of-the-day + bookmark
    // counts made it feel like the wrong product, and put a page
    // between the user and the thing they opened the app for.
    // BibleWorks opens straight into its panes; so does this.
    //
    // 2026-08-06: EVERY width lands on the Workbench now.
    //
    // It used to route phones to HomePage and only desktops to the
    // Workbench, which meant SeekSparks looked like two different apps
    // depending on the screen — the complaint that prompted this. The
    // Workbench already degrades correctly on its own: below 1024 it
    // drops the Analysis pane, below 600 the Search pane too, leaving
    // exactly the centre reading pane. So a phone gets the same shell
    // and the same typography as the desktop, just with the side panes
    // collapsed — one app, one identity, fewer panes.
    //
    // HomePage is not gone; it stays reachable from the Reader control
    // as a MODE within the workspace rather than a separate front door.
    //
    // 2026-08-07: routing phones here made the app visually consistent
    // and thereby made a real problem worse — consistency with a
    // workbench you cannot show is a menu bar over one column, which
    // is YsWords with extra steps. SmallScreenGate says so instead, and
    // as of 2026-08-08 it wraps `home:` rather than this line, so a
    // viewport that cannot carry the workbench never reaches the splash.
    return _showHome
        ? const WorkbenchPage()
        : LoadingPage(
            verses: widget.initialVerses,
            onAdvance: _advance,
          );
  }
}
