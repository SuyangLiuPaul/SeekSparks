/// Gathers a [PassageReport] — bwh28's Report Generator.
///
/// The entry said we had "all the parts … and no assembly"; this is the
/// gathering half of the assembly and `passage_report.dart` is the
/// shaping half. Split so the shaping is testable without assets and the
/// gathering can be slow without making the renderers async.
///
/// Everything it reads is already bundled and already shown elsewhere:
/// `assets/originals/` for the word and its parse, the Strong's lexicon
/// for the gloss, the bundled concordance for the corpus count. It adds
/// no fact of its own.
library;

import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/utils/morphology.dart'
    show describeMorphology, parseMorphology;
import 'package:seeksparks/utils/passage_report.dart';

class PassageReportService {
  PassageReportService._();

  /// Corpus counts are looked up once per NUMBER, not once per word.
  ///
  /// A chapter of Genesis is ~700 words over ~200 distinct numbers, and
  /// the concordance lookup is an asset read behind a cache; without
  /// this the report would ask for וְ five hundred times.
  static final Map<String, int?> _countCache = {};

  static Future<int?> _countOf(String number) async {
    if (_countCache.containsKey(number)) return _countCache[number];
    final r = await ConcordanceService.lookup(number);
    final total = r?.total;
    _countCache[number] = total;
    return total;
  }

  /// Build a report for [verses], which the caller has already scoped.
  ///
  /// [englishBook] is passed separately because `assets/originals` is
  /// keyed in English while a verse from a Chinese edition names its
  /// book in Chinese — the same seam `chapter_across_editions.dart`
  /// exists to hold, and the reason this takes the resolved name instead
  /// of resolving one itself.
  static Future<PassageReport> build({
    required String title,
    required String versionLabel,
    required String englishBook,
    required List<Verse> verses,
    required String locale,
    ReportOptions options = const ReportOptions(),
    String? licence,
  }) async {
    final originals = options.words
        ? await OriginalsService.versesOfBook(englishBook)
        : const <String, List<dynamic>>{};

    final out = <ReportVerse>[];
    var before = 0;

    for (final v in verses) {
      final ref = '${v.book} ${v.chapter}:${v.verse}';
      final words = <ReportWord>[];
      if (options.words) {
        final key = '${v.chapter}:${v.verse}';
        for (final w in (originals[key] ?? const []) ) {
          final number = (w.strongs as String?) ?? '';
          final code = w.morph as String?;
          final parsed = parseMorphology(code);
          final entry =
              number.isEmpty ? null : await StrongsService.lookup(number);
          words.add(ReportWord(
            surface: (w.text as String?) ?? '',
            strongs: number,
            lemma: entry?.lemma,
            transliteration: entry?.translit,
            gloss: _glossFor(entry, locale),
            parse: code == null ? null : describeMorphology(code, locale),
            pos: parsed == null || parsed.morphemes.isEmpty
                ? null
                : parsed.morphemes[parsed.headIndex].pos,
            corpusCount:
                number.isEmpty || !options.frequency
                    ? null
                    : await _countOf(number),
          ));
        }
      }
      before += words.length;
      out.add(ReportVerse(
        reference: ref,
        text: v.scriptureText,
        words: filterWords(words, options),
      ));
    }

    return PassageReport(
      title: title,
      versionLabel: versionLabel,
      verses: out,
      options: options,
      licence: licence,
      wordsBeforeFilter: before,
    );
  }

  /// The reader's own language first, the English gloss as the fallback.
  ///
  /// Null rather than an empty string when neither exists, so the
  /// renderers can leave the dash off instead of printing "— ".
  static String? _glossFor(dynamic entry, String locale) {
    if (entry == null) return null;
    final zh = locale == 'zh-Hant'
        ? (entry.glossZhTw as String?) ?? (entry.glossZh as String?)
        : locale == 'zh-Hans'
            ? entry.glossZh as String?
            : null;
    final pick = (zh != null && zh.trim().isNotEmpty)
        ? zh
        : entry.gloss as String?;
    if (pick == null || pick.trim().isEmpty) return null;
    return pick.trim();
  }
}
