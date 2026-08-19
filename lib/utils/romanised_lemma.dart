/// 2026-08-19 (SeekSparks): romanised Greek and Hebrew search input —
/// BibleWorks help topic bwh45/bwh24, and PARITY-BACKLOG §3.7.
///
/// ── What BibleWorks actually does, and why we do something else ──
///
/// bwh24 ("Keyboards") is not a transliteration feature. BibleWorks
/// binds an INPUT MODE to the search version: select a Greek version and
/// the command line starts reading your keystrokes through the `Bwgrkl`
/// font, so pressing `a` puts α on the screen because the glyph at
/// ASCII 0x61 in that font IS alpha. Hebrew works the same way through
/// `Bwhebb`, right-to-left, with a second table for the points. There is
/// an INS-key escape for typing a codepoint directly. Nothing anywhere
/// in it converts `agape` into ἀγάπη — the help's own key charts are
/// ASCII rendered in a font we do not have, which is also why the
/// mapping is not recoverable from the help text.
///
/// A font keyboard is the right answer for a 2003 desktop with a
/// hardware keyboard and a licensed font. It is the wrong answer here:
/// this app targets a tablet, ships no Greek font keyboard, and its
/// reader is more likely to know the WORD than the layout. So the parity
/// item is met from the other side — accept what the reader can already
/// type. `agape`, `hesed`, `shalom`, `elohim` reach G26, H2617, H7965,
/// H430, and from there the whole Strong's machinery (concordance, KWIC,
/// word family, distribution) is already built.
///
/// ── The romanisation is Strong's, and Strong's is archaic ──
///
/// The transliterations live in `assets/strongs/{greek,hebrew}.json` and
/// are the 1890 forms. They are not what a modern student writes:
///
///   H7965 `shâlôwm`   reader types `shalom`
///   H2617 `chêçêd`    reader types `hesed` or `chesed`
///   H430  `ʼĕlôhîym`  reader types `elohim`
///   H136  `ʼĂdônây`   reader types `adonai`
///   G5590 `psuchḗ`    reader types `psyche`
///
/// So one fold is not enough. Every entry is indexed under two keys:
///
///   * **strict** — accents off, lowercase, non-`a-z` dropped. This is
///     the romanisation as printed, and a strict hit is a strong signal.
///   * **loose** — the strict key put through the collapse rules below,
///     which were derived from the data rather than guessed: they are
///     the differences that actually separate the 1890 spellings from
///     the modern ones across ~60 reader-plausible test words.
///
/// The query is folded exactly the same way on the way in, both keys,
/// and both tiers are consulted. Strict matches rank above loose ones,
/// then by corpus frequency. Nothing is auto-resolved: over 13,964
/// entries there are 21,147 spellings a reader could type, 2,757 of
/// which (13.0%) reach more than one entry, and the worst reaches
/// eight. (Counted per spelling, not per tier — the two maps hold
/// 27,288 keys between them but share thousands of strings, and a
/// spelling in both reaches the union of what they hold.) So the reader
/// is shown the candidates and picks — `ruach` is three words and `torah`
/// is three, and choosing silently would hide a claim about which lemma
/// she meant inside a search she thought she wrote.
///
/// ── Deliberately NOT here ──
///
///   * **Greek/Hebrew SCRIPT input.** Typing ἀγάπη works already — the
///     text scan finds it in a Greek edition, and #321 fixed the accent
///     fold that used to stop it. This file rejects non-Latin input on
///     purpose rather than competing with that.
///   * **A new command verb.** `agape` is a word; asking the reader to
///     learn a prefix for it defeats the point.
///   * **Multi-word romanised phrases**, and romanised terms inside the
///     Strong's boolean grammar (`agape NEAR5 pistis`). Both need a
///     resolution step INSIDE the parser, where an ambiguous term has
///     nobody to ask. Single word only.
///   * **Strong's `pron`** (`shaw-lome'`, `el-o-heem'`). It is a
///     syllabified English pronunciation, present on all 8,674 Hebrew
///     entries and none of the Greek, and folding it produces spellings
///     (`shawlome`, `eloheem`) nobody types. Indexing it would add
///     collisions and reach nothing.
///   * **Degemination** (`hattaah` → `hataah`). Measured: it costs
///     ~1.1% more ambiguity across the index and did not rescue a single
///     test word.
///
/// ── The 76 unreachable numbers ──
///
/// The index is the JOIN of the concordance and the lexicons, so a
/// Strong's number with no lexicon entry has no transliteration and
/// cannot be typed. There are 76 (the extended `G6xxx`/`G9xxx` tagging
/// numbers). Equally, 233 lexicon entries occur nowhere in the bundled
/// text and are excluded on purpose — offering one would be a candidate
/// that leads to an empty verse list, which is the exact failure
/// `search_broadening.dart` exists to prevent.
///
/// Flutter-free and synchronous so it can be tested against the real
/// assets without a widget tree.
library;

import 'package:seeksparks/utils/diacritics.dart' show foldDiacritics;
import 'package:seeksparks/utils/vocabulary.dart' show VocabWord;

/// One entry the reader's spelling reached.
class LemmaCandidate {
  const LemmaCandidate({
    required this.word,
    required this.exact,
  });

  final VocabWord word;

  /// The reader's spelling matched the printed romanisation, not just
  /// its collapsed form. Ranked first, and worth saying: `charis` is a
  /// strict hit on G5485 χάρις and a loose hit on H2757 chârîyts, and
  /// only the tier tells them apart.
  final bool exact;

  String get strongs => word.strongs;

  @override
  String toString() => 'LemmaCandidate(${word.strongs} ${word.translit}'
      '${exact ? '' : ' ~'})';
}

/// One candidate, with the verse count it really returns.
class LemmaHit {
  const LemmaHit({required this.candidate, required this.verses});

  final LemmaCandidate candidate;

  /// Verses the reader will land on, counted from the concordance under
  /// the same search limit the search that produced this offer ran
  /// under. Never a corpus-wide occurrence total: `VocabWord.corpusCount`
  /// counts OCCURRENCES and the list is VERSES, and advertising one to
  /// deliver the other is how a count stops being trusted.
  final int verses;
}

/// What the reader is offered when a word finds nothing in the text.
class LemmaOffer {
  const LemmaOffer({required this.query, required this.hits});

  /// The line as typed, so the row can name it back.
  final String query;

  /// Best first. Never empty — a null offer is used for "nothing to
  /// say" rather than an empty one.
  final List<LemmaHit> hits;
}

/// Reader spelling → Strong's numbers.
///
/// Built once from the same [VocabWord] list the Vocabulary tab uses, so
/// there is no second copy of "lexicon joined to concordance" to drift.
class RomanisedLemmaIndex {
  RomanisedLemmaIndex._(this._strict, this._loose, this._byNumber);

  factory RomanisedLemmaIndex.fromWords(Iterable<VocabWord> words) {
    final strict = <String, List<VocabWord>>{};
    final loose = <String, List<VocabWord>>{};
    final byNumber = <String, VocabWord>{};
    for (final w in words) {
      byNumber[w.strongs] = w;
      for (final key in _entryKeys(w.translit)) {
        (strict[key] ??= <VocabWord>[]).add(w);
        final collapsed = w.isHebrew ? collapseHebrew(key) : collapseGreek(key);
        (loose[collapsed] ??= <VocabWord>[]).add(w);
      }
    }
    return RomanisedLemmaIndex._(strict, loose, byNumber);
  }

  final Map<String, List<VocabWord>> _strict;
  final Map<String, List<VocabWord>> _loose;
  final Map<String, VocabWord> _byNumber;

  int get strictKeyCount => _strict.length;
  int get looseKeyCount => _loose.length;

  /// The spellings a reader can actually type, counted once each.
  ///
  /// NOT `strictKeyCount + looseKeyCount`: thousands of strings are
  /// filed in both tiers (`shalom` is one), and the reader types a
  /// string rather than a tier, so the sum would flatter every ratio
  /// below it. Keys the input rules refuse — under three letters, or a
  /// merged two-word lexicon headword — are excluded for the same
  /// reason: they are not spellings anyone can reach.
  Set<String> get _typableKeys => <String>{
        for (final k in <String>[..._strict.keys, ..._loose.keys])
          if (romanisedKey(k) != null) k,
      };

  int get typableKeyCount => _typableKeys.length;

  /// The most candidates any one typable spelling reaches.
  ///
  /// Measured through [resolve] and not by walking the maps, because a
  /// spelling filed in both tiers reaches the UNION and that union is
  /// what the reader would be shown. It is the number that decides
  /// whether the collapse rules were worth their cost: a regenerated
  /// lexicon that pushed this into the dozens would turn the offer into
  /// a wall. (The pane shows at most [resolve]'s default four.)
  int get worstCollision {
    var worst = 0;
    for (final k in _typableKeys) {
      final n = resolve(k, limit: 1 << 30).length;
      if (n > worst) worst = n;
    }
    return worst;
  }

  /// Typable spellings reaching more than one entry.
  int get ambiguousKeyCount => _typableKeys
      .where((k) => resolve(k, limit: 1 << 30).length > 1)
      .length;

  /// Candidates for [query], best first, or empty when the line is not a
  /// romanised word at all.
  ///
  /// Ordering is tier, then corpus frequency, then Strong's number. The
  /// frequency tiebreak is what makes the top row right in practice —
  /// `torah` reaches H8451 tôwrâh (222×), H2960 ṭôrach (2×) and H8452
  /// tôwrâh (1×), and the reader means the first.
  List<LemmaCandidate> resolve(String query, {int limit = 4}) {
    final strictKey = romanisedKey(query);
    if (strictKey == null) return const <LemmaCandidate>[];

    final pinned = _tetragrammaton[strictKey];
    final seen = <String>{};
    final out = <LemmaCandidate>[];

    void take(Iterable<VocabWord> words, bool exact) {
      final batch = <VocabWord>[
        for (final w in words)
          if (seen.add(w.strongs)) w,
      ]..sort(_byFrequencyThenNumber);
      for (final w in batch) {
        out.add(LemmaCandidate(word: w, exact: exact));
      }
    }

    final pin = pinned == null ? null : _byNumber[pinned];
    if (pin != null) take(<VocabWord>[pin], true);
    take(_strict[strictKey] ?? const <VocabWord>[], true);
    // Both collapses on the way in: the query does not say which
    // language it is, and running the wrong one is harmless — it simply
    // lands on a key nothing was filed under.
    // Not minus `strictKey`: a modern spelling is usually already
    // collapsed (`shalom` collapses to itself), and the entry it wants
    // is filed under that string in the LOOSE map only. `seen` is what
    // stops an entry both maps hold from being listed twice.
    final looseKeys = <String>{
      collapseHebrew(strictKey),
      collapseGreek(strictKey),
    };
    take(
      <VocabWord>[
        for (final k in looseKeys) ...?_loose[k],
      ],
      false,
    );

    return out.length > limit ? out.sublist(0, limit) : out;
  }
}

int _byFrequencyThenNumber(VocabWord a, VocabWord b) {
  final c = b.corpusCount.compareTo(a.corpusCount);
  if (c != 0) return c;
  if (a.strongs[0] != b.strongs[0]) return a.strongs[0].compareTo(b.strongs[0]);
  final na = int.tryParse(a.strongs.substring(1)) ?? 0;
  final nb = int.tryParse(b.strongs.substring(1)) ?? 0;
  return na.compareTo(nb);
}

/// The one word whose English spelling is a convention rather than a
/// romanisation.
///
/// `Yᵉhôvâh` folds to `yehovah`, which nobody types; the tetragrammaton
/// is written `YHWH`, `Yahweh` or `Jehovah` in English by tradition, and
/// none of the three is derivable from the lexicon's own string.
/// `strongs_service.dart` already made this exact pin for the same
/// reason. `adonai` needs no pin — the `y`→`i` rule reaches it.
const Map<String, String> _tetragrammaton = <String, String>{
  'yhwh': 'H3068',
  'yahweh': 'H3068',
  'jehovah': 'H3068',
};

/// The keys one lexicon entry is filed under.
///
/// Usually one. Hebrew entries carrying the superscript shewa `ᵉ`
/// (U+1D49, 1,417 of them) get a second key with it dropped, because the
/// reduced vowel is exactly the thing modern spellings disagree about —
/// `bᵉrîyth` is written both `berit` and `brit`.
Set<String> _entryKeys(String translit) {
  final full = romanisedKey(translit, fromLexicon: true);
  if (full == null) return const <String>{};
  final keys = <String>{full};
  if (translit.contains('ᵉ') || translit.contains('ˢ')) {
    final dropped = romanisedKey(
      translit.replaceAll('ᵉ', '').replaceAll('ˢ', ''),
      fromLexicon: true,
    );
    if (dropped != null) keys.add(dropped);
  }
  return keys;
}

/// A romanised word reduced to bare lowercase `a-z`, or null when the
/// input is not one.
///
/// [fromLexicon] relaxes the input test: a lexicon headword may be two
/// words (`ʼĕlôhîym ʼăchêrîym`) or hyphenated, and it is trusted data.
/// A READER'S line is held to a single token, because a space means the
/// reader asked for a phrase and this file has nothing to say about
/// phrases.
///
/// Rejected on the reader's side: anything under three letters (`el`,
/// `ab` and `ha` would fire on half the index), anything containing a
/// character that is neither a Latin letter that folds into `a-z` nor
/// one of the apostrophes the romanisations use. That last test is what
/// turns away Greek script, Hebrew script and CJK explicitly, rather
/// than letting them fall through the length check by accident.
String? romanisedKey(String input, {bool fromLexicon = false}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final folded = foldDiacritics(trimmed).toLowerCase();
  final buf = StringBuffer();
  for (var i = 0; i < folded.length; i++) {
    final c = folded.codeUnitAt(i);
    if (c >= 0x61 && c <= 0x7A) {
      buf.writeCharCode(c);
      continue;
    }
    // `foldDiacritics` covers Latin-1 through Latin Extended Additional,
    // which is every accented character in either lexicon — but not the
    // two modifier letters Strong's uses for the reduced vowels, which
    // are letters in their own right rather than marks on one.
    if (c == 0x1D49) {
      buf.write('e');
      continue;
    }
    if (c == 0x02E2) {
      buf.write('s');
      continue;
    }
    if (_droppable.contains(c)) continue;
    if (fromLexicon && (c == 0x20 || c == 0x2D)) continue;
    return null;
  }
  final key = buf.toString();
  if (key.isEmpty) return null;
  if (!fromLexicon && key.length < 3) return null;
  return key;
}

/// Aleph, ayin and the stray typographic apostrophe — pronunciation the
/// romanisation marks and no English speaker types.
const Set<int> _droppable = <int>{0x02BB, 0x02BC, 0x2019, 0x0027};

/// Collapse a Hebrew romanisation to the distinctions a modern reader
/// actually makes.
///
/// Every rule below is one place the 1890 romanisation and the modern
/// one disagree, and the whole set was checked against ~30 words a
/// student would type. Order matters and is not decorative:
///
///   * The mater lectionis first (`ow`→`o`, `uw`→`u`, `iy`→`i`), because
///     `shâlôwm`→`shalom` and `ʼĕlôhîym`→`elohim` depend on it, and
///     because the later `w`→`b` rule would otherwise eat the `w`.
///   * `kh`→`ch`→`h` collapses the three ways heth and kaph get written
///     (`ruach`/`ruakh`/`ruah`, `chesed`/`hesed`).
///   * Every surviving `c` is samekh written the old way (`chêçêd`,
///     `çûwph`), so it becomes `s` — safely, since no `ch` is left.
///   * `tz`→`ts`→`s` for tsade (`mitzvah`/`mitsvah`), `q`→`k` for qoph
///     (`qadosh`/`kadosh`), `th`→`t` for spirantised tav, `ph`→`f`
///     (`nephesh`/`nefesh`, `sepher`/`sefer`).
///   * `w`→`v`→`b` for the two readings of bet and vav (`davar`/`dabar`,
///     `avon`/`awon`).
///   * `y`→`i` last, for consonantal yod written either way
///     (`ʼĂdônây`/`adonai`, `yowm`/`iom`).
///
/// It is aggressive on purpose, and the cost was measured rather than
/// assumed: the loose tier has 13,353 keys for 13,964 entries and its
/// worst collision is 8. That is what the strict tier is for.
String collapseHebrew(String key) => key
    .replaceAll('ow', 'o')
    .replaceAll('uw', 'u')
    .replaceAll('iy', 'i')
    .replaceAll('kh', 'ch')
    .replaceAll('ch', 'h')
    .replaceAll('c', 's')
    .replaceAll('tz', 'ts')
    .replaceAll('ts', 's')
    .replaceAll('q', 'k')
    .replaceAll('th', 't')
    .replaceAll('ph', 'f')
    .replaceAll('w', 'v')
    .replaceAll('v', 'b')
    .replaceAll('y', 'i');

/// The Greek equivalent, and much smaller — the 1890 Greek romanisation
/// is close to the modern academic one.
///
///   * `gg`→`ng`: γγ is pronounced and normally written `ng`
///     (`euaggelion` in the lexicon, `euangelion` everywhere else).
///   * `kh`→`ch` for chi, which both spellings survive for.
///   * `y`→`u` for upsilon: Strong's writes `psuchḗ` and `kurios`, a
///     student writes `psyche` and `kyrios`.
///   * `ph`→`f`, for symmetry with Hebrew and at no measured cost.
String collapseGreek(String key) => key
    .replaceAll('gg', 'ng')
    .replaceAll('kh', 'ch')
    .replaceAll('y', 'u')
    .replaceAll('ph', 'f');
