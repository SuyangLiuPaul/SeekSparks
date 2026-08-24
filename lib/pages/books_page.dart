import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:provider/provider.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/book_chapter_picker.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/responsive.dart';

/// 2026-08-09 (task #279): the page shell around [BookChapterPicker].
///
/// The picker themes its own subtree — it has a second host — but the
/// AppBar and the ground the centred column sits on are this page's, so
/// the theme is applied here too. Re-applying is idempotent: it reads
/// brightness off the parent and the paper flag off settings, both
/// unchanged by the inner call.
class BooksPage extends StatelessWidget {
  final int chapterIdx;
  final String bookIdx;
  final MainProvider? providerOverride;

  const BooksPage({
    super.key,
    required this.chapterIdx,
    required this.bookIdx,
    this.providerOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (providerOverride != null) {
      return ChangeNotifierProvider<MainProvider>.value(
        value: providerOverride!,
        child: _buildContent(context, providerOverride!),
      );
    }
    return Consumer<MainProvider>(
      builder: (context, mainProvider, _) => _buildContent(context, mainProvider),
    );
  }

  Widget _buildContent(BuildContext context, MainProvider mainProvider) {
    final settings = Provider.of<AppSettings>(context);

    return Theme(
      data: workbenchTheme(
        Theme.of(context),
        paper: settings.readingPaperTheme,
        textScale: WbType.scaleFor(settings.fontSize),
      ),
      child: Builder(
        builder: (context) =>
            _buildScaffold(context, mainProvider, settings),
      ),
    );
  }

  Widget _buildScaffold(
      BuildContext context, MainProvider mainProvider, AppSettings settings) {
    final wb = WbColors.of(context);
    final wide = ResponsiveBreakpoints.isTabletOrWider(
        MediaQuery.of(context).size.width);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 300) {
          Get.back();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          title: Text(
              uiStrings['bibleBooks']?[settings.locale] ?? 'Bible Books'),
          actions: const [LanguageSwitcherButton(), HomeIconButton()],
        ),
        body: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: wide ? 800 : double.infinity,
            ),
            // The 800px cap has always been here; until the ground went
            // neutral there was nothing to see it against. Hairline sides
            // turn the gutters into a margin around a panel instead of two
            // unexplained empty strips.
            decoration: wide
                ? BoxDecoration(
                    border: Border.symmetric(
                      vertical: BorderSide(
                          color: wb.border, width: WbMetrics.hairline),
                    ),
                  )
                : null,
            child: BookChapterPicker(
              currentBook: bookIdx,
              currentChapter: chapterIdx,
              onChapterSelected: (book, chapter) {
                final matched = mainProvider.verses
                    .where((v) => v.book == book && v.chapter == chapter)
                    .toList();
                if (matched.isEmpty) return;
                mainProvider.setCurrentChapter(book: book, chapter: chapter);
                mainProvider.updateCurrentVerse(verse: matched.first);
                // Round 56 fix: don't slam to top if a pendingJump
                // was set by the picker's verse-pick step. The
                // previous unconditional jumpToTop was clobbering
                // the user's verse-level pick. Only jump-to-top when
                // there's nothing more specific queued.
                if (!mainProvider.hasPendingJump) {
                  mainProvider.jumpToTop();
                }
                Get.back();
              },
            ),
          ),
        ),
      ),
    );
  }
}
