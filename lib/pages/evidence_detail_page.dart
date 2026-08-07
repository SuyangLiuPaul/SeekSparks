import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/bible_evidence.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:seeksparks/utils/jump_to_reference.dart';
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/widgets/confidence_badge.dart';
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/wb_surfaces.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/navigate_to_reader.dart';

/// Full-page view of one [BibleEvidence] entry.
///
/// Layout:
///   • Hero image (or icon fallback)
///   • Title + confidence badge
///   • Quick metadata (location, discovered, timeline, category)
///   • Summary
///   • Detailed description
///   • Scripture correlation block — tap the reference to jump
///     into the reader at that chapter
///   • Academic sources (copy-on-tap)
class EvidenceDetailPage extends StatefulWidget {
  final BibleEvidence evidence;
  const EvidenceDetailPage({super.key, required this.evidence});

  @override
  State<EvidenceDetailPage> createState() => _EvidenceDetailPageState();
}

class _EvidenceDetailPageState extends State<EvidenceDetailPage> {
  // 2026-05-23 (v1.2.80): hero is now a swipeable PageView showing all
  // images in the evidence.images array. Dot indicator below tracks
  // the current page so the user knows there are siblings to swipe to.
  late final PageController _imagePageController;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  BibleEvidence get evidence => widget.evidence;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final wb = WbColors.of(context);
    final locale = settings.locale;
    final fs = settings.fontSize;
    final images = evidence.images;
    final hasImage = images.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          evidence.localizedTitle(locale),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 2026-05-24 (v1.3.19): ListenButton (AI TTS) removed with
          // the rest of the 朗读 feature.
          IconButton(
            tooltip: uiStrings['share']?[locale] ?? 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context, locale),
          ),
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Hero image gallery — swipeable PageView showing every
              // image in `evidence.images`. v1.2.81: made discovery
              // much more obvious. User reported "iOS doesn't show
              // many images, web app also doesn't, like Hittite
              // Empire" — the data has 4 images, the gallery was
              // there, but the 6-px dot indicator was too subtle to
              // notice. Now: prominent counter chip + arrow hints
              // + thumbnail filmstrip below.
              if (hasImage)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 2026-08-08 (#279): was a 12px ClipRRect. The
                    // photograph is the artefact, so rounding it crops
                    // the evidence — it now sits flush in a hairline
                    // frame, which is how BibleWorks presents a
                    // manuscript image (bwh10 Mss tab).
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: wb.border, width: WbMetrics.hairline),
                      ),
                      child: Stack(
                        children: [
                          SizedBox(
                            height: 240,
                            width: double.infinity,
                            child: PageView.builder(
                              controller: _imagePageController,
                              itemCount: images.length,
                              physics: images.length > 1
                                  ? const PageScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              onPageChanged: (i) =>
                                  setState(() => _imageIndex = i),
                              itemBuilder: (_, i) => Image.network(
                                images[i],
                                fit: BoxFit.cover,
                                webHtmlElementStrategy:
                                    WebHtmlElementStrategy.prefer,
                                cacheWidth: 1200,
                                cacheHeight: 480,
                                errorBuilder: (_, __, ___) =>
                                    _HeroShimmer(
                                  category: evidence.category,
                                  showCategoryIcon: true,
                                ),
                                loadingBuilder: (_, child, p) {
                                  if (p == null) return child;
                                  return _HeroShimmer(
                                      category: evidence.category);
                                },
                              ),
                            ),
                          ),
                          // "N/total" counter chip — top-right of
                          // the hero, only when there's more than one
                          // image. Dark background + white text reads
                          // over any photo.
                          if (images.length > 1)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                // Square, not a stadium pill. It reads
                                // as a plate number on the frame rather
                                // than as a badge floating over it.
                                color: Colors.black.withValues(alpha: 0.55),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_library_outlined,
                                        size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_imageIndex + 1}/${images.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Side-arrow hints — make swipe affordance
                          // explicit. Tapping advances by one image
                          // (in case the user prefers tap-to-advance
                          // over swipe).
                          if (images.length > 1 && _imageIndex > 0)
                            Positioned(
                              left: 4,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _ArrowChip(
                                  icon: Icons.chevron_left_rounded,
                                  onTap: () => _imagePageController
                                      .previousPage(
                                    duration: const Duration(
                                        milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                              ),
                            ),
                          if (images.length > 1 &&
                              _imageIndex < images.length - 1)
                            Positioned(
                              right: 4,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _ArrowChip(
                                  icon: Icons.chevron_right_rounded,
                                  onTap: () => _imagePageController.nextPage(
                                    duration: const Duration(
                                        milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Below the hero: thumbnail filmstrip. Each
                    // thumbnail is tappable to jump directly to that
                    // page. Active thumbnail gets a colored ring.
                    if (images.length > 1) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 56,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final active = i == _imageIndex;
                            return InkWell(
                              onTap: () => _imagePageController.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                              ),
                              child: Container(
                                width: 72,
                                height: 56,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  // Hairline for the rest, 2px for the
                                  // one you are looking at — the same
                                  // way the workbench says "this one"
                                  // everywhere else.
                                  border: Border.all(
                                    color: active ? scheme.primary : wb.border,
                                    width: active ? 2 : WbMetrics.hairline,
                                  ),
                                ),
                                child: Image.network(
                                  images[i],
                                  fit: BoxFit.cover,
                                  webHtmlElementStrategy:
                                      WebHtmlElementStrategy.prefer,
                                  cacheWidth: 200,
                                  cacheHeight: 144,
                                  errorBuilder: (_, __, ___) =>
                                      _HeroShimmer(
                                    category: evidence.category,
                                    showCategoryIcon: true,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                )
              else
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: _HeroShimmer(
                    category: evidence.category,
                    showCategoryIcon: true,
                  ),
                ),
              const SizedBox(height: 16),

              // Title + confidence badge row.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      evidence.localizedTitle(locale),
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize: (fs + 6).clamp(20.0, 32.0).toDouble(),
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConfidenceBadge(
                    level: evidence.confidenceLevel,
                    color: evidence.confidenceColor(scheme),
                    prominent: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Metadata chips.
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (evidence.category.isNotEmpty)
                    _Meta(
                      icon: Icons.category_outlined,
                      // The category is stored in English and the list
                      // page has always translated it through this key;
                      // the detail page printed the raw value, so one
                      // screen said 考古 and the next said Archaeology.
                      label: uiStrings['category${evidence.category}']
                              ?[locale] ??
                          evidence.category,
                    ),
                  if (evidence.timeline.isNotEmpty)
                    _Meta(
                      icon: Icons.schedule,
                      label: evidence.timeline,
                    ),
                  if (evidence.discoveryDate.isNotEmpty)
                    _Meta(
                      icon: Icons.event_outlined,
                      label: evidence.discoveryDate,
                    ),
                  if (evidence.location.isNotEmpty)
                    _Meta(
                      icon: Icons.place_outlined,
                      label: evidence.location,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary.
              if (evidence.localizedSummary(locale).isNotEmpty) ...[
                Text(
                  evidence.localizedSummary(locale),
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: fs,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurface,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Description.
              if (evidence.localizedDescription(locale).isNotEmpty) ...[
                _Section(
                  label: uiStrings['evidenceDescription']?[locale] ??
                      'Description',
                  child: Text(
                    evidence.localizedDescription(locale),
                    style: TextStyle(
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      fontSize: fs,
                      color: scheme.onSurface,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Scripture correlation + tappable reference.
              _Section(
                label: uiStrings['scripturalCorrelation']?[locale] ??
                    'Scriptural correlation',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (evidence
                        .localizedCorrelation(locale)
                        .isNotEmpty) ...[
                      Text(
                        evidence.localizedCorrelation(locale),
                        style: TextStyle(
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          fontSize: fs,
                          color: scheme.onSurface,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (evidence.scriptureReference.isNotEmpty)
                      _ReferenceChip(
                        reference: evidence.scriptureReference,
                        locale: locale,
                        onTap: () => _openReference(context),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Academic sources.
              if (evidence.academicSources.isNotEmpty) ...[
                _Section(
                  label: uiStrings['academicSources']?[locale] ??
                      'Academic sources',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final src in evidence.academicSources)
                        _SourceTile(text: src),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, String locale) async {
    // Everything on screen is localised, so the text the reader pastes
    // out has to be too — otherwise a Chinese entry copies as
    // `— Strong | Archaeology | Genesis 1:1`.
    final version = context.read<MainProvider>().currentVersion;
    final category =
        uiStrings['category${evidence.category}']?[locale] ?? evidence.category;
    final confidence =
        uiStrings['confidence${evidence.confidenceLevel}']?[locale] ??
            evidence.confidenceLevel;
    final reference =
        localizedReferenceLabel(evidence.scriptureReference, locale, version);
    final body = StringBuffer()
      ..writeln(evidence.localizedTitle(locale))
      ..writeln('— $confidence | $category | $reference')
      ..writeln()
      ..writeln(evidence.localizedSummary(locale))
      ..writeln()
      ..writeln(evidence.localizedDescription(locale));
    await ClipboardHelper.shareOrCopy(context, body.toString().trim(),
        title: evidence.localizedTitle(locale));
  }

  /// Cross-link to the reader at the cited verse. Uses the
  /// `MainProvider.setPendingJump` handshake so the scroll +
  /// highlight fire whenever the reader is actually ready, instead
  /// of relying on a fragile timer. See
  /// `lib/widgets/bible_reading_pane.dart` for the consumer side.
  ///
  /// **Version fallback**: many evidence entries cite OT books
  /// (`2 Kings 25:27-30`, `1 Chronicles 29:1`, `Nehemiah 3:26-27`, …),
  /// but the user might be reading an NT-only translation like LJK1
  /// or LJK2. In that case the verse simply isn't in `mp.verses` and
  /// the previous version of this method silently returned with no
  /// navigation — looking like the link was dead.
  ///
  /// We now mirror the daily-verse fallback strategy: if the current
  /// version doesn't have the book, transparently switch to a
  /// full-canon companion (CUVS-YHWH for Simplified, CUVS-YHWH-TR
  /// for Traditional, ESV for English) for the duration of this jump,
  /// reload verses, retry the lookup, then navigate. A SnackBar tells
  /// the user we switched so they're not confused when the version
  /// label changes in the reader header.
  Future<void> _openReference(BuildContext context) async {
    // Handle multi-reference strings like "Isaiah 53; Psalm 22; Micah 5:2"
    // by trying the first semicolon-separated segment first, then the full
    // string, then each remaining segment until one parses.
    final raw = evidence.scriptureReference;
    BibleReference? ref = parseReference(raw);
    if (ref == null && raw.contains(';')) {
      for (final part in raw.split(';')) {
        ref = parseReference(part.trim());
        if (ref != null) break;
      }
    }
    if (ref == null) {
      final locale = context.read<AppSettings>().locale;
      final msg = (uiStrings['couldNotParseRef']?[locale] ??
              "Couldn't parse reference: {ref}")
          .replaceFirst('{ref}', raw);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    final mp = context.read<MainProvider>();
    final result = await resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted) return;
    final ok = await showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    navigateToReader(context);
  }
}

/// Navigation control overlaid on the hero gallery. The user can
/// tap-to-advance one image without having to swipe, which is the
/// standard discoverability pattern for image galleries on the web
/// (Instagram + Wikimedia Commons viewer both use it). Square, because
/// it sits ON the specimen plate and so belongs to its frame.
class _ArrowChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowChip({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

/// The empty plate at hero size — shown while the detail image loads
/// OR when there is no image / it errors out. Used in BOTH cases so
/// the user never sees the 80-px emoji that older builds emitted.
/// Same treatment as evidence_page.dart's `_ShimmerPlaceholder`, for
/// the same reason: a tinted gradient competes with the photographs,
/// which are the information on this page.
class _HeroShimmer extends StatelessWidget {
  final String category;
  final bool showCategoryIcon;
  const _HeroShimmer({
    required this.category,
    this.showCategoryIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    return Container(
      color: wb.paneAltBg,
      child: showCategoryIcon
          ? Center(
              child: Icon(
                evidenceCategoryIcon(category),
                size: 64,
                color: wb.mutedText,
              ),
            )
          : null,
    );
  }
}

// v1.2.78: `_IconHero` removed. Was the 80-px emoji hero shown when an
// entry had no image or when Image.network errored out; replaced by
// `_HeroShimmer(showCategoryIcon: true)` which uses a Material category
// icon over the gradient — no emoji.

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Meta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wb = WbColors.of(context);
    final settings = context.watch<AppSettings>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: wb.paneAltBg,
        border: Border.all(color: wb.border, width: WbMetrics.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          // 2026-08-08 (#279): unbounded, this ran off the right edge
          // at 320px — the location chip is a museum's full postal
          // name. It always did; a soft tinted pill just faded off
          // screen, where a hairline box that crosses the edge reads
          // as broken. Making the chrome honest made the layout bug
          // visible, so it gets fixed in the same pass.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize:
                    (settings.fontSize - 3).clamp(11.0, 15.0).toDouble(),
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled block — Description, Scriptural correlation, Academic
/// sources.
///
/// 2026-08-08 (#279): this was a 10px rounded box on
/// `surfaceContainerLow` with an uppercase letter-spaced label in
/// `scheme.primary`. It is now [WbPanel], the same primitive the rest
/// of the pass uses, which puts the label in a hairline-ruled header
/// strip instead of colouring it.
///
/// The label shrinks to the panel's chrome size and the body does NOT:
/// that is the split this pass is built on. A section heading is
/// chrome; the description under it is what the reader came for and
/// keeps `settings.fontSize`.
class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) =>
      WbPanel(title: label, child: child);
}

class _ReferenceChip extends StatelessWidget {
  final String reference;
  final String locale;
  final VoidCallback onTap;

  const _ReferenceChip({
    required this.reference,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wb = WbColors.of(context);
    final settings = context.watch<AppSettings>();
    final currentVersion =
        context.select<MainProvider, String>((m) => m.currentVersion);
    return Material(
      color: wb.paneAltBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: wb.border, width: WbMetrics.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        hoverColor: wb.hoverBg,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                // This widget has taken a `locale` since it was
                // written and never used it: the single most important
                // control on the page — the one that takes you back to
                // the text — printed `Genesis 1:1` to a reader on a
                // Chinese version. Same defect class as #283.
                localizedReferenceLabel(reference, locale, currentVersion),
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize: settings.fontSize,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward,
                  size: 14, color: scheme.primary),
              const SizedBox(width: 2),
              Text(
                uiStrings['readInBible']?[locale] ?? 'Read',
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize:
                      (settings.fontSize - 3).clamp(11.0, 15.0).toDouble(),
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String text;
  const _SourceTile({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    // No url_launcher dep yet — tap copies the citation. The user
    // can paste into a browser tab if there's a link in there.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await ClipboardHelper.copyWithFeedback(context, text);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 8),
                child: Icon(
                  Icons.format_quote,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: (settings.fontSize - 2)
                        .clamp(12.0, 17.0)
                        .toDouble(),
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
