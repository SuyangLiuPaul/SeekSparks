/// 2026-08-07 (SeekSparks): the Phrasing surface — SeekSparks' answer
/// to BibleWorks' Diagramming Module (bwh25). See `utils/phrasing.dart`
/// for why this is an indented text structure and not a vector canvas.
///
/// Interaction grammar, deliberately the same one v1.6.28 established
/// in the Browse window: **hover previews, click commits.** Pointing at
/// a word parses it in the footer and changes nothing; clicking it
/// breaks the line. A reader who has learned one surface has learned
/// both.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show shortBibleVersionLabel;
import 'package:seeksparks/constants/book_names.dart' show bookNameToEnglish;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart' show WbMetrics;
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/fetch_verses.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/phrasing_store.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/services/tagged_text_service.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:seeksparks/utils/morphology.dart';
import 'package:seeksparks/utils/phrasing.dart';
import 'package:seeksparks/utils/scripture_markup.dart'
    show scriptureReadingText;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

/// Reader-facing label for a relation, in [locale].
String phrasingRelationLabel(PhrasingRelation r, String locale) {
  const fallbacks = <PhrasingRelation, String>{
    PhrasingRelation.series: 'series',
    PhrasingRelation.progression: 'progression',
    PhrasingRelation.contrast: 'contrast',
    PhrasingRelation.alternative: 'alternative',
    PhrasingRelation.comparison: 'comparison',
    PhrasingRelation.purpose: 'purpose',
    PhrasingRelation.result: 'result',
    PhrasingRelation.ground: 'ground',
    PhrasingRelation.inference: 'inference',
    PhrasingRelation.means: 'means',
    PhrasingRelation.manner: 'manner',
    PhrasingRelation.condition: 'condition',
    PhrasingRelation.concession: 'concession',
    PhrasingRelation.temporal: 'time',
    PhrasingRelation.place: 'place',
    PhrasingRelation.content: 'content',
    PhrasingRelation.apposition: 'apposition',
    PhrasingRelation.relative: 'relative',
  };
  final key = 'phrasingRel${r.name[0].toUpperCase()}${r.name.substring(1)}';
  return uiStrings[key]?[locale] ?? fallbacks[r] ?? r.name;
}

/// The four level chips: enum, string key, English fallback.
///
/// One list, because [phrasingLevelNote] names the same levels the chips
/// do and two lists would let a rename drift them apart.
const phrasingLevelChips = <(PhrasingLevel, String, String)>[
  (PhrasingLevel.verses, 'phrasingLevelVerses', 'Verses'),
  (PhrasingLevel.clauses, 'phrasingLevelClauses', 'Clauses'),
  (PhrasingLevel.verbals, 'phrasingLevelVerbals', '+ Verbals'),
  (PhrasingLevel.phrases, 'phrasingLevelPhrases', '+ Phrases'),
];

String phrasingLevelName(PhrasingLevel l, String locale) {
  final e = phrasingLevelChips.firstWhere((e) => e.$1 == l);
  return uiStrings[e.$2]?[locale] ?? e.$3;
}

/// What the chosen level cuts at, and what that costs on this page.
///
/// The chip numbers let the reader COMPARE without committing; this says
/// what the number means for the one they are on. The overlap is
/// deliberate — it is what teaches them to read the chips at all.
///
/// The second sentence is the one that earns the widget. Measured over
/// the bundled corpus, `+ Verbals` draws the identical page in 20.9% of
/// three-verse windows (see [phrasingLevelLineCounts]), and until now the
/// reader tapped it, saw nothing move, and concluded the tool was broken.
/// Naming it turns a dead control into a fact about the passage.
///
/// Top-level and locale-taking, like [phrasingRelationLabel], so the copy
/// can be asserted per locale without pumping the page: the web build is
/// skwasm, where rendered text is not in the DOM and a screenshot cannot
/// read it back.
///
/// Null when the level carries no count — a level this edition cannot
/// support is disabled, and describing a page nobody can reach is #299's
/// defect in a sentence.
String? phrasingLevelNote(
  Phrasing p,
  Map<PhrasingLevel, int> counts,
  String locale,
) {
  final n = counts[p.level];
  if (n == null) return null;
  String s(String k, String fallback) => uiStrings[k]?[locale] ?? fallback;
  const what = {
    PhrasingLevel.verses: (
      'phrasingLevelWhatVerses',
      'cut at verse starts only, with no grammatical claim',
    ),
    PhrasingLevel.clauses: (
      'phrasingLevelWhatClauses',
      'cut at verse starts, conjunctions and relative pronouns',
    ),
    PhrasingLevel.verbals: (
      'phrasingLevelWhatVerbals',
      'also cut at participles and infinitives',
    ),
    PhrasingLevel.phrases: (
      'phrasingLevelWhatPhrases',
      'also cut at prepositions — the finest level, and in Hebrew a '
          'very fine one',
    ),
  };
  final w = what[p.level]!;
  final parts = <String>[
    s('phrasingLevelCount', '{name}: {n} lines in verses {a}–{b} — {what}.')
        .replaceAll('{name}', phrasingLevelName(p.level, locale))
        .replaceAll('{n}', '$n')
        .replaceAll('{a}', '${p.startVerse}')
        .replaceAll('{b}', '${p.endVerse}')
        .replaceAll('{what}', s(w.$1, w.$2)),
  ];
  final coarser = coarserPhrasingLevel(p.level, counts.keys.toSet());
  if (coarser != null && counts[coarser] == n) {
    parts.add(s('phrasingLevelSameAs',
            'Same lines as {b} — nothing new is cut inside this window.')
        .replaceAll('{b}', phrasingLevelName(coarser, locale)));
  }
  // Only for a reader who has something to lose. Someone who has drawn no
  // lines does not need reassuring about lines they have not drawn, and
  // the header is already the tallest thing on this screen.
  if (p.isTouched) {
    parts.add(s('phrasingLevelKeepsWork',
        'Changing level keeps your own breaks, indents and labels.'));
  }
  return parts.join(' ');
}

class PhrasingPage extends StatefulWidget {
  const PhrasingPage({
    super.key,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.locale,
    required this.version,
  });

  /// Book as the reader sees it; mapped to English for the lookup.
  final String book;
  final int chapter;

  /// Where the workbench cursor was. Seeds the verse window.
  final int verse;
  final String locale;
  final String version;

  @override
  State<PhrasingPage> createState() => _PhrasingPageState();
}

/// Where the words being phrased come from.
///
/// Two, not a version list: the reader has already chosen an edition in
/// the workbench, and a second version picker here would ask them to
/// choose again for no reason. The real question is only whether they
/// are phrasing *their* text or *the* text.
enum PhrasingSource {
  /// The edition open in the workbench. The default, because it is what
  /// the reader is looking at, and because a tool only usable on Greek
  /// is a tool for almost nobody.
  translation,

  /// The bundled Hebrew/Greek corpus. Still the more precise exercise,
  /// and the only source that carries a full parse.
  originals,
}

/// The one thing this screen cannot be read without.
///
/// Phrasing is an act of interpretation — the reader decides where a
/// clause ends and what is subordinate to what — and that judgement is
/// impossible without the meaning of the words in front of them. Until
/// v1.6.106 the meaning was reachable only by HOVERING one word at a
/// time, which on a tablet is not reachable at all.
enum _GlossMode {
  /// The counterpart word printed under each word, always visible.
  on,

  /// Off, for a reader who knows the language and wants the bare text.
  off,
}

/// Every type size on this page, derived from the reader's own font
/// setting rather than written down.
///
/// Nothing here used to move: the words were `fontSize: 17` and the rest
/// were 10–13, so the Settings slider did not reach this screen at all
/// (#315). Pointed Hebrew and accented Greek are the worst case for
/// that, because their diacritics carry meaning and are the first thing
/// to disappear as size falls.
class _PhrasingType {
  const _PhrasingType({
    required this.word,
    required this.gloss,
    required this.chrome,
    required this.indent,
  });

  /// The original languages are given the same head start over Latin
  /// that the workbench already grants them, expressed as the ratio
  /// between the two constants so the two cannot drift apart.
  static const double _originalBoost = WbMetrics.original / WbMetrics.text;

  /// [WbMetrics.original] is the size at which the workbench already
  /// accepts pointing and accents as separable, in a layout far denser
  /// than this one, so nothing on this page may fall below it while it
  /// is carrying Hebrew or Greek. A reader who sets 12 pt is asking the
  /// rest of the app to be dense; they are not asking for an
  /// unreadable qamats.
  ///
  /// The word line reaches it on its own — the smallest setting the
  /// slider offers, times the boost, is exactly [WbMetrics.original] —
  /// so only the gloss line needs the floor stated.
  static const double _pointedFloor = WbMetrics.original;

  factory _PhrasingType.of(double fontSize, PhrasingSource source) {
    final original = source == PhrasingSource.originals;
    final word = original ? fontSize * _originalBoost : fontSize;
    // The gloss line always carries the OTHER script, so which of the
    // two is the pointed one flips with the source. Shrinking Hebrew to
    // 0.62 of a 12 pt setting puts a qamats at 7 px, which is not a
    // faint gloss but an absent one.
    final gloss = original
        ? (fontSize * 0.62).clamp(11.0, double.infinity)
        : (fontSize * 0.62 * _originalBoost)
            .clamp(_pointedFloor, double.infinity);
    return _PhrasingType(
      word: word.toDouble(),
      gloss: gloss.toDouble(),
      chrome: (fontSize * 0.6).clamp(11.0, double.infinity).toDouble(),
      // One indent step is a little over one word-width, which is what
      // makes a subordinate line read as subordinate at any size.
      indent: word.toDouble() * 1.4,
    );
  }

  final double word;
  final double gloss;
  final double chrome;
  final double indent;
}

class _PhrasingPageState extends State<PhrasingPage> {
  List<PhrasingWord> _words = const [];
  Phrasing? _p;
  bool _loading = true;
  int? _hover;

  /// The word whose parse the footer is holding. Set by a long press,
  /// which is the only route a touch device has — `_hover` never fires
  /// there, and this app is tablet-first.
  int? _pinned;
  _GlossMode _gloss = _GlossMode.on;

  /// What the gloss line is quoting: the reader's own edition, the
  /// original corpus, or nothing. Drives the legend, because "this is
  /// how 雅简+ renders the word" and "this is what the lexicon says the
  /// lemma means" are different claims.
  String? _glossSource;
  bool _glossHasLexicon = false;
  PhrasingSource _source = PhrasingSource.translation;

  /// The chapter as `(verse, text)`, used for nothing but finding where
  /// the sentences end. Held rather than recomputed so the ⤢ button can
  /// answer instantly — and held SEPARATELY from `_words` because the
  /// two are not always the same text: `assets/originals` prints no
  /// stops, so a reader phrasing the Hebrew has the bounds read off the
  /// edition they came from instead.
  List<({int verse, String text})> _punctuation = const [];
  PhrasingWindowSource _punctuationSource = PhrasingWindowSource.none;

  /// How many lines each level would draw, right now, in this window.
  ///
  /// Held rather than computed in `build` because `build` also runs on
  /// every hover, and this is four whole layouts of the chapter. It
  /// depends only on the words and on the [Phrasing] itself, and every
  /// mutation of the latter goes through [_update], so those two places
  /// are the whole of it.
  Map<PhrasingLevel, int> _levelCounts = const {};

  /// Whose punctuation drew the window, when it was not the phrased text
  /// itself. Printed, never assumed: LEB makes Ephesians 1:3-14 one
  /// sentence, the KJV makes it three and the BSB makes it seven, and a
  /// pane that showed a range without saying which edition decided it
  /// would be passing off an editor's judgement as the text's.
  String? _punctuationEdition;

  String get _englishBook => bookNameToEnglish[widget.book] ?? widget.book;

  /// The key a phrasing is stored under.
  ///
  /// The originals keep the bare version code they have always used, so
  /// work saved before this screen could read a translation still loads
  /// against the words it was made from. Breaks, depths and relations
  /// are all word INDICES, so a key collision between two different
  /// tokenizations would not fail loudly — it would silently reattach a
  /// reader's analysis to the wrong words.
  String get _storeKey => _source == PhrasingSource.originals
      ? widget.version
      : '${widget.version}.txt';

  /// Every verse number present in the chapter, ascending. Drives the
  /// window steppers, so a chapter with a gap in the tagged corpus
  /// cannot offer a verse that is not there.
  List<int> get _verseNumbers {
    final seen = <int>{};
    for (final w in _words) {
      seen.add(w.verse);
    }
    return seen.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // The word list is the WHOLE chapter, always — see
    // [visiblePhrasingLines] for why the window must not affect indices.
    final bare = _source == PhrasingSource.originals
        ? await _originalWords()
        : await _translationWords();
    final words = await _withGlosses(bare);
    final stored =
        await PhrasingStore.load(_storeKey, _englishBook, widget.chapter);
    if (!mounted) return;
    final present = {for (final w in words) w.verse}.toList()..sort();
    final levels = availablePhrasingLevels(words);
    final seed = present.contains(widget.verse)
        ? widget.verse
        : (present.isEmpty ? 1 : present.first);
    await _readPunctuation(words);
    if (!mounted) return;
    final window = _sentenceWindow(seed);
    // Only a FRESH phrasing opens on the sentence. A stored one carries
    // a range the reader chose, and widening it under them would move
    // the lines they drew out from under their own decision.
    var p = stored ??
        Phrasing(
          version: _storeKey,
          book: _englishBook,
          chapter: widget.chapter,
          startVerse: window.start,
          endVerse: window.end,
        );
    // A level the source cannot support would propose nothing and read
    // as a dead control. Fall back to the finest one it CAN support
    // rather than to `verses`, so switching to a translation keeps as
    // much of the reader's chosen granularity as the text allows.
    if (!levels.contains(p.level)) {
      final usable = [
        for (final l in PhrasingLevel.values)
          if (levels.contains(l) && l.index <= p.level.index) l,
      ];
      p = p.copyWith(
          level: usable.isEmpty ? PhrasingLevel.verses : usable.last);
    }
    setState(() {
      _words = words;
      _p = p;
      _levelCounts = phrasingLevelLineCounts(p, words);
      _loading = false;
    });
  }

  /// Find a text for this chapter that punctuates, and remember which.
  ///
  /// The phrased words come first, because an edition's own stops are
  /// the only ones that are a claim about the text being phrased. They
  /// answer for every translation the app ships — measured, all 1,189
  /// chapters of KJV, LEB, BSB and 和合本雅伟版 punctuate — and for none
  /// of the originals: `assets/originals` carries **0 sentence marks in
  /// 438,821 words**, and `assets/lxxwh.json` carries none either, the
  /// same editorial decision that left it unaccented.
  Future<void> _readPunctuation(List<PhrasingWord> words) async {
    _punctuationEdition = null;
    final own = [for (final w in words) (verse: w.verse, text: w.text)];
    if (own.any((t) => phrasingEndsSentence(t.text))) {
      _punctuation = own;
      _punctuationSource = PhrasingWindowSource.phrased;
      return;
    }
    // Borrowed, and therefore named. This is the reader's OWN edition —
    // the one they were reading when they opened the pane — so the
    // question it answers is "where does my Bible put the full stop",
    // which is a question they can check.
    final verses = await FetchVerses.loadVerseList(widget.version) ?? const [];
    final inChapter = [
      for (final v in verses)
        if (v.chapter == widget.chapter &&
            (bookNameToEnglish[v.book] ?? v.book) == _englishBook)
          (verse: v.verse, text: scriptureReadingText(v.text)),
    ]..sort((a, b) => a.verse.compareTo(b.verse));
    if (inChapter.any((t) => phrasingEndsSentence(t.text))) {
      _punctuation = inChapter;
      _punctuationSource = PhrasingWindowSource.edition;
      _punctuationEdition = shortBibleVersionLabel(widget.version);
      return;
    }
    _punctuation = const [];
    _punctuationSource = PhrasingWindowSource.none;
  }

  PhrasingWindow _sentenceWindow(int verse) => phrasingSentenceWindow(
        _punctuation,
        verse,
        source: _punctuationSource,
      );

  Future<List<PhrasingWord>> _originalWords() async {
    final words = <PhrasingWord>[];
    final byVerse = await OriginalsService.versesOfBook(_englishBook);
    final keys = byVerse.keys
        .where((k) => k.split(':').first == '${widget.chapter}')
        .toList()
      ..sort((a, b) => (int.tryParse(a.split(':').last) ?? 0)
          .compareTo(int.tryParse(b.split(':').last) ?? 0));
    var verse = 0;
    for (final k in keys) {
      verse = int.tryParse(k.split(':').last) ?? verse;
      for (final w in byVerse[k] ?? const []) {
        words.add(PhrasingWord(
          text: w.text,
          strongs: w.strongs,
          verse: verse,
          morph: w.morph,
          translit: w.translit,
        ));
      }
    }
    return words;
  }

  /// The chapter as the reader's own edition prints it.
  ///
  /// Two roads, and which one is taken decides how much the pane can
  /// propose. A **tagged** edition (雅简+, 和简+, BSB, KJV+S, LXX+WH) is
  /// already cut into runs aligned to the original, so its own word
  /// boundaries are used and every run arrives carrying the Strong's
  /// number of the word behind it — which is what lets the clause level
  /// keep working in English or Chinese. An **untagged** edition is cut
  /// by [phrasingTokens] and carries no numbers, so it gets verse
  /// breaks and the reader's own hands.
  Future<List<PhrasingWord>> _translationWords() async {
    final verses = await FetchVerses.loadVerseList(widget.version) ?? const [];
    final inChapter = [
      for (final v in verses)
        if (v.chapter == widget.chapter &&
            (bookNameToEnglish[v.book] ?? v.book) == _englishBook)
          v,
    ]..sort((a, b) => a.verse.compareTo(b.verse));
    if (inChapter.isEmpty) return const [];

    final tagged = TaggedTextService.supports(widget.version);
    final words = <PhrasingWord>[];
    for (final v in inChapter) {
      if (tagged) {
        final runs = await TaggedTextService.forVerse(
          version: widget.version,
          englishBook: _englishBook,
          chapter: widget.chapter,
          verse: v.verse,
        );
        if (runs != null && runs.isNotEmpty) {
          for (final r in runs) {
            final text = r.text.trim();
            if (text.isEmpty) continue;
            words.add(PhrasingWord(
              text: text,
              strongs: r.strongs,
              verse: v.verse,
            ));
          }
          continue;
        }
        // Falls through: a tagged edition can still be missing a verse,
        // and a hole in the middle of the chapter would shift every
        // index after it.
      }
      for (final t in phrasingTokens(scriptureReadingText(v.text))) {
        final text = t.trim();
        if (text.isEmpty) continue;
        words.add(PhrasingWord(text: text, strongs: '', verse: v.verse));
      }
    }
    return words;
  }

  /// Print the other side of the text under every word.
  ///
  /// **This is the pairing the screen used to forbid.** The source
  /// switch made Original and Translation exclusive, so a reader
  /// phrasing the Hebrew saw no meaning anywhere — which is precisely
  /// the judgement phrasing requires. The alignment needed for it was
  /// already in the file: a tagged edition's runs each carry the
  /// Strong's number of the word behind them, so pairing the two
  /// renderings is [alignByStrongs] and nothing more.
  ///
  /// The lexicon is a FALLBACK, never the first answer. What 雅简+
  /// actually wrote at 1 Kings 21:1 is a fact about this verse; what
  /// the lexicon says H1961 means is a fact about the lemma. The second
  /// is worth showing when the first is unavailable, but the reader is
  /// told which they are looking at — the gloss is drawn in italic and
  /// the legend says so.
  Future<List<PhrasingWord>> _withGlosses(List<PhrasingWord> words) async {
    _glossSource = null;
    _glossHasLexicon = false;
    if (words.isEmpty || words.every((w) => w.strongs.isEmpty)) return words;

    final verses = {for (final w in words) w.verse};
    final counterpart = await _counterpartByVerse(verses);
    final out = List<PhrasingWord>.of(words);

    // Align verse by verse: a counterpart from the wrong verse would be
    // a confident, well-formed lie about the text.
    var i = 0;
    while (i < out.length) {
      final verse = out[i].verse;
      var end = i;
      while (end < out.length && out[end].verse == verse) {
        end++;
      }
      final source = counterpart[verse];
      if (source != null && source.isNotEmpty) {
        final paired = alignByStrongs(
          [for (var k = i; k < end; k++) out[k].strongs],
          source,
        );
        for (var k = i; k < end; k++) {
          out[k] = out[k].withGloss(paired[k - i]);
        }
      }
      i = end;
    }

    // Whatever the counterpart could not answer, the lexicon may.
    final unanswered = <String>{
      for (final w in out)
        if (w.gloss == null && w.strongs.isNotEmpty) w.strongs,
    };
    if (unanswered.isNotEmpty) {
      final lex = await StrongsService.lookupAll(unanswered);
      if (lex.isNotEmpty) {
        for (var k = 0; k < out.length; k++) {
          if (out[k].gloss != null) continue;
          final entry = lex[out[k].strongs.trim().toUpperCase()];
          if (entry == null) continue;
          // Which side of the pairing the reader is on decides what the
          // lexicon is asked for: a reader phrasing Hebrew wants the
          // sense, a reader phrasing their own edition wants the word.
          final text = _source == PhrasingSource.originals
              ? briefGloss(entry.localizedGloss(widget.locale))
              : entry.lemma.trim();
          if (text.isEmpty) continue;
          _glossHasLexicon = true;
          out[k] = out[k].withGloss(text.trim(), fromLexicon: true);
        }
      }
    }
    if (out.every((w) => w.gloss == null)) _glossSource = null;
    return out;
  }

  /// The other rendering of each verse, as `(strongs, text)` pairs.
  Future<Map<int, List<({String strongs, String text})>>> _counterpartByVerse(
      Set<int> verses) async {
    final out = <int, List<({String strongs, String text})>>{};
    if (_source == PhrasingSource.originals) {
      if (!TaggedTextService.supports(widget.version)) return out;
      for (final v in verses) {
        final runs = await TaggedTextService.forVerse(
          version: widget.version,
          englishBook: _englishBook,
          chapter: widget.chapter,
          verse: v,
        );
        if (runs == null || runs.isEmpty) continue;
        out[v] = [
          for (final r in runs) (strongs: r.strongs, text: r.text.trim()),
        ];
      }
      if (out.isNotEmpty) {
        _glossSource = shortBibleVersionLabel(widget.version);
      }
      return out;
    }
    final byKey = await OriginalsService.versesOfBook(_englishBook);
    for (final v in verses) {
      final ws = byKey['${widget.chapter}:$v'];
      if (ws == null || ws.isEmpty) continue;
      out[v] = [for (final w in ws) (strongs: w.strongs, text: w.text)];
    }
    if (out.isNotEmpty) {
      _glossSource = _s('phrasingSourceOriginals', 'Original');
    }
    return out;
  }

  Future<void> _setSource(PhrasingSource source) async {
    if (source == _source) return;
    setState(() {
      _source = source;
      _loading = true;
      _hover = null;
      _words = const [];
    });
    await _load();
  }

  void _update(Phrasing next) {
    setState(() {
      _p = next;
      // Recomputed here and not in `build`: widening the window or
      // drawing a break by hand both change what every level would
      // produce, and a stale count is worse than none — it is a promise
      // about a page the reader is about to be given.
      _levelCounts = phrasingLevelLineCounts(next, _words);
    });
    PhrasingStore.save(next);
  }

  String _s(String k, String fallback) =>
      uiStrings[k]?[widget.locale] ?? fallback;

  bool get _rtl => phrasingIsRtl(_words);

  bool get _cjk => phrasingIsCjk(_words);

  Future<void> _copy() async {
    final p = _p;
    if (p == null) return;
    final head =
        '${localeAwareBookName(widget.book, widget.locale, widget.version)} '
        '${widget.chapter}:${p.startVerse}-${p.endVerse}';
    final text = exportPhrasing(
      p,
      _words,
      label: (r) => phrasingRelationLabel(r, widget.locale),
      verseMark: (v) => '$v',
    );
    final html = exportPhrasingHtml(
      p,
      _words,
      label: (r) => phrasingRelationLabel(r, widget.locale),
      heading: head,
      verseMark: (v) => '$v',
      rtl: _rtl,
    );
    final r = await ClipboardHelper.copyRich(html, '$head\n$text');
    if (!mounted) return;
    // Three outcomes, three sentences: a phrasing that pasted as plain
    // text has lost its indentation and its underlines, which is most of
    // what the reader built, so saying only "Copied" would be a small lie
    // they discover in the document.
    final message = !r.copied
        ? _s('shareLinkFailed', 'Copy failed — clipboard unavailable')
        : r.formatted
            ? _s('phrasingCopiedRich', 'Copied with its formatting')
            : _s('phrasingCopiedPlain',
                'Copied as plain text — the indentation was lost');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = _p;
    // `watch`, so dragging the Settings slider repaints this screen —
    // the point of routing the sizes through the setting at all.
    final t = _PhrasingType.of(context.watch<AppSettings>().fontSize, _source);

    return Scaffold(
      appBar: AppBar(
        title: Text(_s('phrasingTitle', 'Phrasing')),
        actions: [
          if (_words.any((w) => w.gloss != null))
            IconButton(
              tooltip: _gloss == _GlossMode.on
                  ? _s('phrasingGlossHide', 'Hide the gloss line')
                  : _s('phrasingGlossShow', 'Show the gloss line'),
              icon: Icon(_gloss == _GlossMode.on
                  ? Icons.subtitles_outlined
                  : Icons.subtitles_off_outlined),
              onPressed: () => setState(() => _gloss =
                  _gloss == _GlossMode.on ? _GlossMode.off : _GlossMode.on),
            ),
          IconButton(
            tooltip: _s('phrasingReset', 'Start over'),
            icon: const Icon(Icons.restart_alt),
            onPressed: p == null || !p.isTouched
                ? null
                : () => _update(resetPhrasing(p)),
          ),
          IconButton(
            tooltip: _s('kwicCopy', 'Copy all'),
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _words.isEmpty ? null : _copy,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (p == null || _words.isEmpty)
              ? _empty(scheme)
              : LayoutBuilder(
                  builder: (context, box) => Column(
                    children: [
                      // The header is capped and scrolls past the cap.
                      //
                      // Left to its natural height it takes whatever it
                      // wants and the diagram gets the remainder, which
                      // at the reader's largest font on a short window
                      // was a RenderFlex overflow — 20px before the
                      // level note was added and 68px after. #312 item 4
                      // was a complaint about this header's height, so
                      // making it able to squeeze the text out entirely
                      // is not a trade this page may make.
                      //
                      // `SingleChildScrollView` still shrink-wraps under
                      // a bounded maxHeight, so a short header is not
                      // padded out to the cap.
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: box.maxHeight * 0.55),
                        child: SingleChildScrollView(
                          child: _controls(p, scheme, t),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(child: _diagram(p, scheme, t)),
                      const Divider(height: 1),
                      _footer(scheme, t),
                    ],
                  ),
                ),
    );
  }

  Widget _empty(ColorScheme scheme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _s(
                'phrasingNone',
                'No original-language text is bundled for this chapter, so '
                    'there is nothing to phrase.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.outline),
          ),
        ),
      );

  // ── Controls ──────────────────────────────────────────────────────

  Widget _controls(Phrasing p, ColorScheme scheme, _PhrasingType t) {
    final verses = _verseNumbers;
    final levels = availablePhrasingLevels(_words);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final e in [
                (
                  PhrasingSource.translation,
                  _s('phrasingSourceVersion', 'Translation'),
                ),
                (
                  PhrasingSource.originals,
                  _s('phrasingSourceOriginals', 'Original'),
                ),
              ])
                ChoiceChip(
                  label: Text(e.$2, style: TextStyle(fontSize: t.chrome)),
                  selected: _source == e.$1,
                  onSelected: (_) => _setSource(e.$1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final e in phrasingLevelChips)
                ChoiceChip(
                  // The count rides on the chip, not in a tooltip: this
                  // app is tablet-first and a tablet has no hover, which
                  // is the same reason #312 gave for the parse being
                  // unreachable. A number the reader has to earn with a
                  // pointer is a number half of them cannot have.
                  label: Text(
                    _levelCounts[e.$1] == null
                        ? _s(e.$2, e.$3)
                        : '${_s(e.$2, e.$3)} · ${_levelCounts[e.$1]}',
                    style: TextStyle(fontSize: t.chrome),
                  ),
                  selected: p.level == e.$1,
                  // A level this text cannot support is disabled rather
                  // than left tappable and inert — see
                  // [availablePhrasingLevels]. It carries no count
                  // either: a number beside a chip that cannot be
                  // pressed is a promise about a page nobody can reach.
                  onSelected: levels.contains(e.$1)
                      ? (_) => _update(setPhrasingLevel(p, e.$1))
                      : null,
                ),
            ],
          ),
          _levelNote(p, scheme, t),
          if (!levels.contains(PhrasingLevel.verbals)) ...[
            const SizedBox(height: 6),
            Text(
              // Two different facts, and saying the wrong one is a claim
              // about the reader's edition that is not true. A TAGGED
              // translation proposes the joints its Strong's numbers can
              // name; an untagged one proposes nothing at all, and
              // telling that reader what "is proposed" would have them
              // looking for lines the pane never drew.
              levels.contains(PhrasingLevel.clauses)
                  ? _s(
                      'phrasingNoParse',
                      'This edition carries no grammatical parse, so only '
                          'the joints a Strong’s number can name are '
                          'proposed. Switch to the original for participles '
                          'and infinitives.',
                    )
                  : _s(
                      'phrasingNoTags',
                      'This edition carries no grammar and no Strong’s '
                          'numbers, so only verse breaks are proposed — the '
                          'lines are yours to draw. Switch to the original '
                          'for a grammatical proposal.',
                    ),
              style: TextStyle(fontSize: t.chrome, color: scheme.outline),
            ),
          ],
          _glossLegend(scheme, t),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_s('phrasingRange', 'Verses'),
                  style: TextStyle(fontSize: t.chrome, color: scheme.outline)),
              _verseDrop(verses, p.startVerse, (v) {
                _update(p.copyWith(
                  startVerse: v,
                  endVerse: v > p.endVerse ? v : p.endVerse,
                ));
              }),
              Text('–', style: TextStyle(color: scheme.outline)),
              _verseDrop(verses, p.endVerse, (v) {
                _update(p.copyWith(
                  endVerse: v,
                  startVerse: v < p.startVerse ? v : p.startVerse,
                ));
              }),
              _sentenceButton(p, scheme, t),
            ],
          ),
          _sentenceNote(p, scheme, t),
          const SizedBox(height: 6),
          Text(
            _s(
              'phrasingHint',
              'Tap a word to start a new line before it; tap the first word '
                  'of a line to join it back up. Use ◀ ▶ to indent — an '
                  'indented line is subordinate to the line above it. '
                  'Long-press a word for its full parse.',
            ),
            style: TextStyle(fontSize: t.chrome, color: scheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _levelNote(Phrasing p, ColorScheme scheme, _PhrasingType t) {
    final note = phrasingLevelNote(p, _levelCounts, widget.locale);
    if (note == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        note,
        style: TextStyle(fontSize: t.chrome, color: scheme.outline),
      ),
    );
  }

  /// Name where the gloss line comes from.
  ///
  /// Without this the reader cannot tell an edition's actual rendering
  /// of *this verse* from a dictionary sense of the *lemma*, and those
  /// are different claims about the text. The italic marks each case on
  /// the word; this says what the two markings mean.
  Widget _glossLegend(ColorScheme scheme, _PhrasingType t) {
    if (_gloss == _GlossMode.off) return const SizedBox.shrink();
    final source = _glossSource;
    if (source == null && !_glossHasLexicon) return const SizedBox.shrink();
    final lexicon =
        _s('phrasingGlossLexicon', 'the lexicon’s sense for the lemma');
    final text = source == null
        ? _s('phrasingGlossFrom', 'Gloss line: %s').replaceFirst('%s', lexicon)
        : _s('phrasingGlossFrom', 'Gloss line: %s').replaceFirst('%s', source) +
            (_glossHasLexicon
                ? ' · ${_s('phrasingGlossItalic', 'italic is %s').replaceFirst('%s', lexicon)}'
                : '');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(fontSize: t.chrome, color: scheme.outline),
      ),
    );
  }

  /// Snap the window to the sentence the start verse is inside.
  ///
  /// Present as a control and not only as a default, because a default
  /// nobody can invoke is a default nobody knows about: the reader who
  /// narrows the range to one verse to concentrate on it needs the way
  /// back, and the reader whose stored phrasing predates this button has
  /// never seen the sentence at all.
  void _snapToSentence(Phrasing p, {bool whole = false}) {
    final w = _sentenceWindow(p.startVerse);
    _update(p.copyWith(
      startVerse: whole ? w.sentenceStart : w.start,
      endVerse: whole ? w.sentenceEnd : w.end,
    ));
  }

  Widget _sentenceButton(Phrasing p, ColorScheme scheme, _PhrasingType t) {
    final w = _sentenceWindow(p.startVerse);
    final dead = w.source == PhrasingWindowSource.none ||
        (w.start == p.startVerse && w.end == p.endVerse);
    return ActionChip(
      avatar: Icon(Icons.unfold_more, size: t.chrome * 1.15),
      label: Text(_s('phrasingSnapSentence', 'Sentence'),
          style: TextStyle(fontSize: t.chrome)),
      tooltip: _s('phrasingSnapSentenceTip',
          'Widen the window to the whole sentence the first verse is in'),
      onPressed: dead ? null : () => _snapToSentence(p),
    );
  }

  /// One line saying where the window came from — or why there is none.
  ///
  /// Everything printed here is an *edition's* claim, so the edition is
  /// named. The same chapter is punctuated differently by every
  /// translation we ship, and the pane that hides that is the one that
  /// makes a reader think the text settled it.
  Widget _sentenceNote(Phrasing p, ColorScheme scheme, _PhrasingType t) {
    final w = _sentenceWindow(p.startVerse);
    final style = TextStyle(fontSize: t.chrome, color: scheme.outline);
    final label = _punctuationEdition ?? shortBibleVersionLabel(widget.version);
    Widget line(String s) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(s, style: style),
        );

    if (w.source == PhrasingWindowSource.none) {
      return line(_s(
        'phrasingNoStops',
        'This text prints no sentence punctuation, so the window cannot be '
            'widened past one verse.',
      ));
    }
    // A cap that is not printed is a silent filter. The sentence is
    // still named, still measured, and still one tap away.
    if (w.capped && (p.startVerse != w.sentenceStart ||
        p.endVerse != w.sentenceEnd)) {
      final n = w.sentenceEnd - w.sentenceStart + 1;
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _s('phrasingSentenceLong',
                      'Verse {v} is inside a {n}-verse sentence in {e} '
                          '({a}–{b}) — long enough that it is a list, not a '
                          'period.')
                  .replaceAll('{v}', '${p.startVerse}')
                  .replaceAll('{n}', '$n')
                  .replaceAll('{e}', label)
                  .replaceAll('{a}', '${w.sentenceStart}')
                  .replaceAll('{b}', '${w.sentenceEnd}'),
              style: style,
            ),
            InkWell(
              onTap: () => _snapToSentence(p, whole: true),
              child: Text(
                _s('phrasingSentenceOpenAnyway', 'Open it anyway'),
                style: style.copyWith(
                    color: scheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    if (w.start == p.startVerse && w.end == p.endVerse && w.widensVerse) {
      final key = w.source == PhrasingWindowSource.edition
          ? 'phrasingSentenceBorrowed'
          : 'phrasingSentenceOwn';
      return line(_s(
        key,
        w.source == PhrasingWindowSource.edition
            ? 'Verses {a}–{b} are one sentence in {e}. The original prints '
                'no stops, so the bounds are that edition’s.'
            : 'Verses {a}–{b} are one sentence in {e}.',
      )
          .replaceAll('{a}', '${w.start}')
          .replaceAll('{b}', '${w.end}')
          .replaceAll('{e}', label));
    }
    return const SizedBox.shrink();
  }

  Widget _verseDrop(List<int> verses, int value, ValueChanged<int> onChanged) =>
      DropdownButton<int>(
        value: verses.contains(value)
            ? value
            : (verses.isEmpty ? null : verses.first),
        isDense: true,
        underline: const SizedBox.shrink(),
        items: [
          for (final v in verses)
            DropdownMenuItem<int>(value: v, child: Text('$v')),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );

  // ── The diagram ───────────────────────────────────────────────────

  Widget _diagram(Phrasing p, ColorScheme scheme, _PhrasingType t) {
    final all = layoutPhrasing(p, _words);
    final lines = visiblePhrasingLines(all, _words, p.startVerse, p.endVerse);
    if (lines.isEmpty) {
      return Center(
        child: Text(_s('phrasingEmptyWindow', 'No verses in this range.'),
            style: TextStyle(color: scheme.outline)),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
      itemCount: lines.length,
      itemBuilder: (context, i) => _lineRow(p, lines[i], scheme, t),
    );
  }

  Widget _lineRow(
      Phrasing p, PhrasingLine line, ColorScheme scheme, _PhrasingType t) {
    final row = Padding(
      padding: EdgeInsetsDirectional.only(
        start: 8.0 + line.depth * t.indent,
        top: t.word * 0.22,
        bottom: t.word * 0.22,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _depthButton(Icons.chevron_left, line.depth == 0, t,
              () => _update(outdentPhrasingLine(p, _words, line.start))),
          _depthButton(Icons.chevron_right, false, t,
              () => _update(indentPhrasingLine(p, _words, line.start))),
          const SizedBox(width: 4),
          _relationChip(p, line, scheme, t),
          const SizedBox(width: 6),
          // The letter sits before the member at the member's own
          // indent, which is where the request's document puts it —
          // near enough to the words to read as belonging to them, and
          // outside the text so it is never mistaken for scripture.
          if (line.memberLabel != null)
            Padding(
              padding: EdgeInsetsDirectional.only(end: 4, top: t.word * 0.12),
              child: Text(
                '(${line.memberLabel})',
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
          Expanded(child: _words_(line, scheme, t)),
        ],
      ),
    );
    // Hebrew reads right to left, and indentation is a flow direction
    // rather than a symbol, so the whole structure mirrors for free —
    // this is the single biggest reason a text model beat a canvas.
    return _rtl
        ? Directionality(textDirection: TextDirection.rtl, child: row)
        : row;
  }

  Widget _depthButton(
          IconData icon, bool disabled, _PhrasingType t, VoidCallback onTap) =>
      SizedBox(
        width: t.chrome * 2.2,
        height: t.chrome * 2.2,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: t.chrome * 1.45,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon),
          onPressed: disabled ? null : onTap,
        ),
      );

  Widget _relationChip(
      Phrasing p, PhrasingLine line, ColorScheme scheme, _PhrasingType t) {
    final chosen = line.relation;
    final suggested = line.suggested;
    if (chosen == null && suggested == null) {
      return _chipShell(
        onTap: () => _pickRelation(p, line),
        border: scheme.outlineVariant,
        child: Icon(Icons.add, size: 12, color: scheme.outline),
      );
    }
    final label = phrasingRelationLabel((chosen ?? suggested)!, widget.locale);
    // A SUGGESTION MUST NOT LOOK LIKE A DECISION. The grammar's guess is
    // drawn muted and italic with no fill; the reader's own choice is
    // filled and upright. If those two read the same, a reader cannot
    // tell which labels in their own diagram they actually chose, and
    // the whole analysis becomes untrustworthy at exactly the point it
    // is supposed to be their work.
    return _chipShell(
      onTap: () => _pickRelation(p, line),
      border: chosen != null ? scheme.primary : scheme.outlineVariant,
      fill: chosen != null ? scheme.primaryContainer : null,
      child: Text(
        label,
        style: TextStyle(
          fontSize: t.chrome,
          fontStyle: chosen != null ? FontStyle.normal : FontStyle.italic,
          color: chosen != null ? scheme.onPrimaryContainer : scheme.outline,
        ),
      ),
    );
  }

  Widget _chipShell({
    required VoidCallback onTap,
    required Color border,
    Color? fill,
    required Widget child,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 22),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(widthFactor: 1, child: child),
        ),
      );

  Future<void> _pickRelation(Phrasing p, PhrasingLine line) async {
    final suggestions = line.start < _words.length
        ? suggestRelations(_words[line.start])
        : const <PhrasingRelation>[];
    final rest = [
      for (final r in PhrasingRelation.values)
        if (!suggestions.contains(r)) r,
    ];
    final t = _PhrasingType.of(context.read<AppSettings>().fontSize, _source);
    // A sheet, and correctly so: this is a DECISION about one line, not
    // content that a docked pane could hold — the distinction #313
    // settled for the workbench.
    final picked = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The line's two MARKS, above its relation. They belong on
              // the same sheet because they are all answers to "what is
              // this line", and giving each its own control in the row
              // would put three buttons in front of every line of
              // scripture on the page.
              SwitchListTile(
                dense: true,
                secondary: const Icon(Icons.format_list_bulleted, size: 18),
                title: Text(_s('phrasingMember', 'Parallel member (a) (b)')),
                subtitle: Text(
                  _s(
                    'phrasingMemberHint',
                    'Letters run in order down each run of members at the '
                        'same indent.',
                  ),
                  style: TextStyle(fontSize: t.chrome),
                ),
                value: p.members.contains(line.start),
                onChanged: (_) => Navigator.pop(context, 'member'),
              ),
              SwitchListTile(
                dense: true,
                secondary: const Icon(Icons.format_underlined, size: 18),
                title: Text(_s('phrasingEmphasis', 'Underline this line')),
                value: p.emphasis.contains(line.start),
                onChanged: (_) => Navigator.pop(context, 'emphasis'),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.clear, size: 18),
                title: Text(_s('phrasingRelNone', 'No label')),
                onTap: () => Navigator.pop(context, 'none'),
              ),
              if (suggestions.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _s('phrasingSuggested', 'Suggested by the grammar'),
                      style: TextStyle(fontSize: t.chrome),
                    ),
                  ),
                ),
                for (final r in suggestions)
                  ListTile(
                    dense: true,
                    title: Text(phrasingRelationLabel(r, widget.locale)),
                    onTap: () => Navigator.pop(context, r),
                  ),
              ],
              const Divider(height: 1),
              for (final r in rest)
                ListTile(
                  dense: true,
                  title: Text(phrasingRelationLabel(r, widget.locale)),
                  onTap: () => Navigator.pop(context, r),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    if (picked == 'member') {
      _update(togglePhrasingMember(p, line.start));
      return;
    }
    if (picked == 'emphasis') {
      _update(togglePhrasingEmphasis(p, line.start));
      return;
    }
    _update(setPhrasingRelation(
      p,
      line.start,
      picked is PhrasingRelation ? picked : null,
    ));
  }

  Widget _words_(PhrasingLine line, ColorScheme scheme, _PhrasingType t) {
    final spans = <Widget>[];
    var lastVerse = line.start > 0 ? _words[line.start - 1].verse : -1;
    for (var i = line.start; i < line.end && i < _words.length; i++) {
      final w = _words[i];
      if (w.verse != lastVerse) {
        spans.add(Padding(
          padding: EdgeInsetsDirectional.only(end: 3, top: t.word * 0.14),
          child: Text('${w.verse}',
              style: TextStyle(
                  fontSize: t.chrome * 0.9,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary)),
        ));
        lastVerse = w.verse;
      }
      spans.add(_word(i, w, i == line.start, line.emphasised, scheme, t));
    }
    return Wrap(
      spacing: _cjk ? 0 : 5,
      runSpacing: 2,
      // Top, not centre: the words of the line must share a baseline
      // even though only some of them carry a gloss underneath.
      crossAxisAlignment: WrapCrossAlignment.start,
      children: spans,
    );
  }

  Widget _word(int i, PhrasingWord w, bool isLineStart, bool emphasised,
      ColorScheme scheme, _PhrasingType t) {
    final hovered = _hover == i;
    final pinned = _pinned == i;
    final gloss = _gloss == _GlossMode.on ? w.gloss : null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = i),
      onExit: (_) => setState(() => _hover = _hover == i ? null : _hover),
      child: GestureDetector(
        onTap: () {
          final p = _p;
          if (p != null) _update(togglePhrasingBreak(p, _words, i));
        },
        // The parse used to be reachable only by hovering, which a
        // tablet cannot do at all. A long press is the touch idiom for
        // "tell me about this without acting on it", and it leaves the
        // tap free for the break, which is the primary action here.
        onLongPress: () => setState(() => _pinned = pinned ? null : i),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: _cjk ? 1 : 2, vertical: 1),
          decoration: BoxDecoration(
            color: pinned
                ? scheme.secondaryContainer
                : (hovered ? scheme.surfaceContainerHighest : null),
            borderRadius: BorderRadius.circular(3),
            // The first word of a line carries the break it stands on,
            // so the reader can see what their next tap would undo.
            border: BorderDirectional(
              start: isLineStart
                  ? BorderSide(color: scheme.primary, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The underline is the reader's emphasis on the LINE, so
              // it goes on the scripture and never on the gloss — the
              // gloss is this app's annotation, and underlining it
              // would put the reader's mark on words they did not
              // choose.
              Text(
                w.text,
                style: TextStyle(
                  fontSize: t.word,
                  decoration: emphasised ? TextDecoration.underline : null,
                  decorationThickness: 1.5,
                ),
              ),
              if (gloss != null)
                // The gloss carries the other script, so it gets its own
                // direction from its own text — the ambient RTL of a
                // Hebrew diagram must not mirror a Chinese gloss, and an
                // LTR diagram must not straighten a Hebrew one.
                Directionality(
                  textDirection:
                      isRtlText(gloss) ? TextDirection.rtl : TextDirection.ltr,
                  child: ConstrainedBox(
                    // A tagged run can be a whole clause — 雅简+ puts
                    // 又有一事。耶斯列人 on one Strong's number. Left
                    // unbounded it stretches its column until the
                    // diagram is one word per line and the indentation,
                    // which is the entire point, stops being visible.
                    constraints: BoxConstraints(maxWidth: t.gloss * 7),
                    child: Text(
                      gloss,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: t.gloss,
                        height: 1.1,
                        color: scheme.onSurfaceVariant,
                        // Italic marks the lexicon's sense for the LEMMA,
                        // as against what this verse actually says.
                        fontStyle: w.glossFromLexicon
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Footer: the parse of whatever the pointer is on ───────────────

  Widget _footer(ColorScheme scheme, _PhrasingType t) {
    // A pinned word outranks the pointer, so reaching for the footer
    // does not empty it — the same reason the Browse window pins.
    final i = _pinned ?? _hover;
    final w = (i != null && i < _words.length) ? _words[i] : null;
    final parse = w == null ? null : describeMorphology(w.morph, widget.locale);
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: t.chrome * 2.5),
      alignment: AlignmentDirectional.centerStart,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: t.chrome * 0.35),
      color: _pinned != null
          ? scheme.secondaryContainer
          : scheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: Text(
              w == null
                  ? _s('phrasingFooterIdle', 'Long-press a word for its parse.')
                  : [
                      w.text,
                      if (w.translit != null && w.translit!.isNotEmpty)
                        w.translit!,
                      if (w.gloss != null) w.gloss!,
                      if (w.strongs.isNotEmpty) w.strongs,
                      if (parse != null) parse,
                    ].join('  ·  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: t.chrome, color: scheme.onSurfaceVariant),
            ),
          ),
          if (_pinned != null)
            SizedBox(
              width: t.chrome * 2.2,
              height: t.chrome * 2.2,
              child: IconButton(
                tooltip: _s('phrasingUnpin', 'Release'),
                padding: EdgeInsets.zero,
                iconSize: t.chrome * 1.3,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _pinned = null),
              ),
            ),
        ],
      ),
    );
  }
}
