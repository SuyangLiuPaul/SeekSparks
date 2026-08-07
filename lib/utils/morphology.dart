/// 2026-08 (SeekSparks): decodes the morphology codes carried in
/// `assets/originals/*.json` under each word's `m` key.
///
/// BibleWorks' Analysis window puts a parsing line under every original
/// word — "noun accusative feminine singular", "aorist active
/// indicative 3rd singular". That line is the single most-used thing in
/// the whole program, and until now SeekSparks had no morphology at all:
/// the shipped originals carried only the pointed word and its Strong's
/// number.
///
/// The data now comes from two open-licensed corpora, merged offline by
/// `tools/merge_morphology.py`:
///
///   * Greek NT  — MorphGNT / SBLGNT, CC BY-SA 3.0.
///     Code = 2-char part of speech + 8-char parse, e.g. `V-3AAI-S--`.
///   * Hebrew OT — Open Scriptures Hebrew Bible (WLC), CC BY 4.0.
///     Code = language char + `/`-separated morphemes, e.g.
///     `HR/Ncfsa` (preposition + feminine singular absolute noun).
///
/// Only the raw code is stored, so the assets stay compact and the
/// labels stay translatable — decoding happens here, per locale.
///
/// Anything unrecognised degrades to the raw code rather than throwing
/// or silently vanishing: an unfamiliar tag is still information, and a
/// wrong parse would be worse than none.
///
/// 2026-08-07: the positional logic moved into [parseMorphology], one
/// parser shared by this file's reader-facing labels AND by
/// `utils/morph_query.dart`'s matcher. Where a slot sits in a code is
/// part-of-speech dependent in both schemes, and writing that switch
/// twice is how a search comes to disagree with the parse line printed
/// directly above it.
library;

/// Human-readable parse of a morphology code, or null when [code] is
/// absent/empty. [locale] is one of `en`, `zh-Hans`, `zh-Hant`.
String? describeMorphology(String? code, String locale) {
  if (code == null) return null;
  final c = code.trim();
  if (c.isEmpty) return null;
  final parsed = parseMorphology(c);
  if (parsed == null) return c;
  return parsed.scheme == MorphScheme.greek
      ? _greek(parsed, locale)
      : _semitic(parsed, locale);
}

/// The two schemes overlap on one letter: `A` opens every Aramaic code
/// AND is Greek's adjective part of speech (`A-----NSM-`). Length alone
/// does NOT settle it — 4,889 Open Scriptures codes are also exactly 10
/// characters (`HTd/Vhrmsa`, `HR/R/Sp3mp`). What settles it is the
/// second clause: no Semitic code's first two characters (`HT`, `HR`,
/// `HV`, `AC`, …) are keys in [_gkPos]. Do not "simplify" this test to
/// the length check.
bool _isGreek(String c) =>
    c.length == 10 && _gkPos.containsKey(c.substring(0, 2));

/// Short one-word part of speech (for a compact chip next to the word).
String? morphologyPartOfSpeech(String? code, String locale) {
  final parsed = parseMorphology(code);
  final head = parsed?.morphemes.isNotEmpty == true
      ? parsed!.morphemes.first
      : null;
  if (head == null) return null;
  return morphSlotLabel(parsed!.scheme, head.pos, MorphSlot.pos, head.pos,
      locale, aramaic: parsed.aramaic);
}

// ── The shared parser ───────────────────────────────────────────────

/// Which coding scheme a word is written in. Aramaic shares the Semitic
/// scheme's shape but not all of its labels — see [MorphWord.aramaic].
enum MorphScheme { greek, semitic }

/// One grammatical feature a code can carry. Greek and Semitic overlap
/// on [pos], [person], [gender], [number]; the rest belong to one
/// scheme or the other.
enum MorphSlot {
  pos,
  // Greek
  tense,
  voice,
  mood,
  grammaticalCase,
  degree,
  // Semitic
  subtype,
  stem,
  conjugation,
  state,
  // Shared
  person,
  gender,
  number,
}

/// One morpheme of a word. Greek words have exactly one; a Semitic word
/// is a stack (conjunction + article + preposition + stem + suffix) that
/// Open Scriptures writes `/`-separated, and 32% of the Hebrew Bible has
/// more than one.
class MorphMorpheme {
  const MorphMorpheme({
    required this.raw,
    required this.pos,
    required this.slots,
  });

  /// The morpheme's own substring of the code (`Ncfsa`, `V-3AAI-S--`).
  final String raw;

  /// `N`/`V`/… for Semitic, `N-`/`RA`/… for Greek.
  final String pos;

  /// Feature → raw code character. A slot the morpheme does not carry is
  /// absent rather than present-and-empty, so "no gender" and "gender we
  /// could not read" are the same thing to a matcher: not a match.
  ///
  /// Open Scriptures writes `x` for "unknown or unnecessary" (the spec's
  /// own words) — `Pdxms`, `ANxxxa`. Those are dropped here for the same
  /// reason a `-` is dropped in Greek: they are the absence of a value,
  /// not a value, and 2,684 words in the shipped corpus carry one.
  final Map<MorphSlot, String> slots;
}

/// A fully parsed morphology code.
class MorphWord {
  const MorphWord({
    required this.raw,
    required this.scheme,
    required this.aramaic,
    required this.morphemes,
  });

  final String raw;
  final MorphScheme scheme;

  /// Aramaic uses the same code SHAPE as Hebrew but a different stem
  /// vocabulary — `q` is Qal in Hebrew and Peal in Aramaic, `t` is
  /// Hithpael in Hebrew and Hishtaphel in Aramaic. 1,068 verbs in the
  /// shipped corpus depend on this flag reaching the label lookup.
  final bool aramaic;

  final List<MorphMorpheme> morphemes;

  /// Which morpheme the word is "about" — the last one that is not a
  /// pronominal/paragogic suffix, since Semitic prefixes (conjunction,
  /// article, preposition) precede the head and suffixes follow it.
  /// Verified against all 123 morpheme sequences in the corpus.
  int get headIndex {
    for (var i = morphemes.length - 1; i >= 0; i--) {
      if (morphemes[i].pos != 'S') return i;
    }
    return morphemes.isEmpty ? 0 : morphemes.length - 1;
  }
}

/// Parse [code] into its morphemes and their feature slots, or null when
/// there is nothing to parse. Unrecognised parts yield a morpheme with
/// an empty slot map rather than being dropped, so callers can still see
/// that something was there.
MorphWord? parseMorphology(String? code) {
  if (code == null) return null;
  final c = code.trim();
  if (c.isEmpty) return null;

  if (_isGreek(c)) {
    return MorphWord(
      raw: c,
      scheme: MorphScheme.greek,
      aramaic: false,
      morphemes: [_parseGreek(c)],
    );
  }

  final aramaic = c.startsWith('A');
  final body = c.length > 1 ? c.substring(1) : '';
  final morphemes = <MorphMorpheme>[
    for (final part in body.split('/'))
      if (part.isNotEmpty) _parseSemitic(part),
  ];
  if (morphemes.isEmpty) return null;
  return MorphWord(
    raw: c,
    scheme: MorphScheme.semitic,
    aramaic: aramaic,
    morphemes: morphemes,
  );
}

/// A slot value that is present in the code but means "no value".
bool _blank(String ch) => ch == '-' || ch == 'x' || ch.isEmpty;

MorphMorpheme _parseGreek(String c) {
  String at(int i) => i < c.length ? c[i] : '-';
  final slots = <MorphSlot, String>{};
  void put(MorphSlot slot, int index) {
    final ch = at(index);
    if (!_blank(ch)) slots[slot] = ch;
  }

  final pos = c.substring(0, 2);
  slots[MorphSlot.pos] = pos;
  put(MorphSlot.person, 2);
  put(MorphSlot.tense, 3);
  put(MorphSlot.voice, 4);
  put(MorphSlot.mood, 5);
  put(MorphSlot.grammaticalCase, 6);
  put(MorphSlot.number, 7);
  put(MorphSlot.gender, 8);
  put(MorphSlot.degree, 9);
  return MorphMorpheme(raw: c, pos: pos, slots: slots);
}

MorphMorpheme _parseSemitic(String m) {
  final pos = m[0];
  final slots = <MorphSlot, String>{MorphSlot.pos: pos};
  String at(int i) => i < m.length ? m[i] : '';
  void put(MorphSlot slot, int index) {
    final ch = at(index);
    if (!_blank(ch)) slots[slot] = ch;
  }

  switch (pos) {
    case 'V':
      put(MorphSlot.stem, 1);
      put(MorphSlot.conjugation, 2);
      // Participles decline (gender number state); every other finite
      // form conjugates (person gender number); infinitives — `Vqa`,
      // `Vqc`, 7,489 words — stop after the conjugation and so pick up
      // neither set, which the length guard in `at` already gives us.
      final conj = at(2);
      if (conj == 'r' || conj == 's') {
        put(MorphSlot.gender, 3);
        put(MorphSlot.number, 4);
        put(MorphSlot.state, 5);
      } else {
        put(MorphSlot.person, 3);
        put(MorphSlot.gender, 4);
        put(MorphSlot.number, 5);
      }
    case 'N':
    case 'A':
      put(MorphSlot.subtype, 1);
      put(MorphSlot.gender, 2);
      put(MorphSlot.number, 3);
      put(MorphSlot.state, 4);
    case 'P':
    case 'S':
      put(MorphSlot.subtype, 1);
      put(MorphSlot.person, 2);
      put(MorphSlot.gender, 3);
      put(MorphSlot.number, 4);
    case 'T':
    case 'R':
      put(MorphSlot.subtype, 1);
    default:
      break;
  }
  return MorphMorpheme(raw: m, pos: pos, slots: slots);
}

// ── Localisation helper ─────────────────────────────────────────────

/// Table entries are `[en, zh-Hans, zh-Hant]`.
String? _pick(List<String>? row, String locale) {
  if (row == null) return null;
  switch (locale) {
    case 'zh-Hans':
      return row[1];
    case 'zh-Hant':
      return row[2];
    default:
      return row[0];
  }
}

/// Chinese joins grammatical terms without spaces; English needs them.
String _join(List<String> parts, String locale) =>
    parts.join(locale == 'en' ? ' ' : '');

// ── Greek (MorphGNT) ────────────────────────────────────────────────

const _gkPos = <String, List<String>>{
  'N-': ['noun', '名词', '名詞'],
  'A-': ['adjective', '形容词', '形容詞'],
  'RA': ['article', '冠词', '冠詞'],
  'RD': ['demonstrative pronoun', '指示代词', '指示代詞'],
  'RI': ['interrogative pronoun', '疑问代词', '疑問代詞'],
  'RP': ['personal pronoun', '人称代词', '人稱代詞'],
  'RR': ['relative pronoun', '关系代词', '關係代詞'],
  'C-': ['conjunction', '连词', '連詞'],
  'D-': ['adverb', '副词', '副詞'],
  'I-': ['interjection', '感叹词', '感嘆詞'],
  'P-': ['preposition', '介词', '介詞'],
  'V-': ['verb', '动词', '動詞'],
  'X-': ['particle', '语助词', '語助詞'],
};

const _gkPerson = <String, List<String>>{
  '1': ['1st person', '第一人称', '第一人稱'],
  '2': ['2nd person', '第二人称', '第二人稱'],
  '3': ['3rd person', '第三人称', '第三人稱'],
};

const _gkTense = <String, List<String>>{
  'P': ['present', '现在时', '現在時'],
  'I': ['imperfect', '未完成时', '未完成時'],
  'F': ['future', '将来时', '將來時'],
  'A': ['aorist', '简单过去时', '簡單過去時'],
  'X': ['perfect', '完成时', '完成時'],
  'Y': ['pluperfect', '过去完成时', '過去完成時'],
};

const _gkVoice = <String, List<String>>{
  'A': ['active', '主动', '主動'],
  'M': ['middle', '关身', '關身'],
  'P': ['passive', '被动', '被動'],
};

const _gkMood = <String, List<String>>{
  'I': ['indicative', '直说语气', '直說語氣'],
  'D': ['imperative', '命令语气', '命令語氣'],
  'S': ['subjunctive', '假设语气', '假設語氣'],
  'O': ['optative', '祈愿语气', '祈願語氣'],
  'N': ['infinitive', '不定式', '不定式'],
  'P': ['participle', '分词', '分詞'],
};

const _gkCase = <String, List<String>>{
  'N': ['nominative', '主格', '主格'],
  'G': ['genitive', '所有格', '所有格'],
  'D': ['dative', '间接受格', '間接受格'],
  'A': ['accusative', '直接受格', '直接受格'],
  'V': ['vocative', '呼格', '呼格'],
};

const _gkNumber = <String, List<String>>{
  'S': ['singular', '单数', '單數'],
  'P': ['plural', '复数', '複數'],
};

const _gkGender = <String, List<String>>{
  'M': ['masculine', '阳性', '陽性'],
  'F': ['feminine', '阴性', '陰性'],
  'N': ['neuter', '中性', '中性'],
};

const _gkDegree = <String, List<String>>{
  'C': ['comparative', '比较级', '比較級'],
  'S': ['superlative', '最高级', '最高級'],
};

/// `V-3AAI-S--` → "verb · aorist active indicative · 3rd person singular".
String _greek(MorphWord word, String locale) {
  final m = word.morphemes.first;
  String? label(MorphSlot slot) {
    final code = m.slots[slot];
    if (code == null) return null;
    return morphSlotLabel(word.scheme, m.pos, slot, code, locale,
        aramaic: word.aramaic);
  }

  final pos = label(MorphSlot.pos);
  final person = label(MorphSlot.person);
  final tense = label(MorphSlot.tense);
  final voice = label(MorphSlot.voice);
  final mood = label(MorphSlot.mood);
  final kase = label(MorphSlot.grammaticalCase);
  final number = label(MorphSlot.number);
  final gender = label(MorphSlot.gender);
  final degree = label(MorphSlot.degree);

  // Verb parse reads tense-voice-mood, the order every Greek grammar —
  // and BibleWorks itself — uses.
  final verbal = <String>[
    if (tense != null) tense,
    if (voice != null) voice,
    if (mood != null) mood,
  ];
  // A person means a FINITE verb, whose number belongs with the person
  // ("3rd person singular"). Everything else — nouns, adjectives,
  // articles, and participles, which decline — takes the nominal parse
  // "case number gender".
  final List<String> agreement;
  final List<String> nominal;
  if (person != null) {
    agreement = [person, if (number != null) number];
    nominal = const [];
  } else {
    agreement = const [];
    nominal = [
      if (kase != null) kase,
      if (number != null) number,
      if (gender != null) gender,
    ];
  }

  final groups = <String>[
    if (pos != null) pos,
    if (verbal.isNotEmpty) _join(verbal, locale),
    if (agreement.isNotEmpty) _join(agreement, locale),
    if (nominal.isNotEmpty) _join(nominal, locale),
    if (degree != null) degree,
  ];
  if (groups.isEmpty) return word.raw;
  return groups.join(' · ');
}

// ── Hebrew / Aramaic (Open Scriptures) ──────────────────────────────

const _hebPos = <String, List<String>>{
  'A': ['adjective', '形容词', '形容詞'],
  'C': ['conjunction', '连词', '連詞'],
  'D': ['adverb', '副词', '副詞'],
  'N': ['noun', '名词', '名詞'],
  'P': ['pronoun', '代词', '代詞'],
  'R': ['preposition', '介词', '介詞'],
  'S': ['suffix', '词尾', '詞尾'],
  'T': ['particle', '语助词', '語助詞'],
  'V': ['verb', '动词', '動詞'],
};

const _hebNounType = <String, List<String>>{
  'c': ['common', '普通', '普通'],
  'g': ['gentilic', '族名', '族名'],
  'p': ['proper name', '专有名词', '專有名詞'],
};

const _hebAdjType = <String, List<String>>{
  'a': ['adjective', '形容词', '形容詞'],
  'c': ['cardinal number', '基数词', '基數詞'],
  'g': ['gentilic', '族名', '族名'],
  'o': ['ordinal number', '序数词', '序數詞'],
};

const _hebPronType = <String, List<String>>{
  'd': ['demonstrative', '指示', '指示'],
  'f': ['indefinite', '不定', '不定'],
  'i': ['interrogative', '疑问', '疑問'],
  'p': ['personal', '人称', '人稱'],
  'r': ['relative', '关系', '關係'],
};

const _hebPartType = <String, List<String>>{
  'a': ['affirmation', '肯定', '肯定'],
  'd': ['definite article', '定冠词', '定冠詞'],
  'e': ['exhortation', '劝勉', '勸勉'],
  'i': ['interrogative', '疑问', '疑問'],
  'j': ['interjection', '感叹', '感嘆'],
  'm': ['demonstrative', '指示', '指示'],
  'n': ['negative', '否定', '否定'],
  'o': ['object marker', '受词记号', '受詞記號'],
  'r': ['relative', '关系', '關係'],
};

const _hebSuffixType = <String, List<String>>{
  'd': ['directional he', '方向 he', '方向 he'],
  'h': ['paragogic he', '词尾 he', '詞尾 he'],
  'n': ['paragogic nun', '词尾 nun', '詞尾 nun'],
  'p': ['pronominal', '代词后缀', '代詞後綴'],
};

/// The preposition subtype slot has exactly one value in the whole
/// corpus: a preposition that has swallowed the article.
const _hebPrepType = <String, List<String>>{
  'd': ['definite article', '定冠词', '定冠詞'],
};

/// Hebrew binyanim.
///
/// These letters are NOT shared with Aramaic — see [_arStem]. Open
/// Scriptures reuses the same slot with a different vocabulary, so `q`
/// is Qal here and Peal there, and `t` is Hithpael here and Hishtaphel
/// there.
const _hebStem = <String, List<String>>{
  'q': ['Qal', 'Qal 简单主动', 'Qal 簡單主動'],
  'N': ['Niphal', 'Niphal 简单被动', 'Niphal 簡單被動'],
  'p': ['Piel', 'Piel 加强主动', 'Piel 加強主動'],
  'P': ['Pual', 'Pual 加强被动', 'Pual 加強被動'],
  'h': ['Hiphil', 'Hiphil 使役主动', 'Hiphil 使役主動'],
  'H': ['Hophal', 'Hophal 使役被动', 'Hophal 使役被動'],
  't': ['Hithpael', 'Hithpael 反身', 'Hithpael 反身'],
  'o': ['Polel', 'Polel', 'Polel'],
  'O': ['Polal', 'Polal', 'Polal'],
  'r': ['Hithpolel', 'Hithpolel', 'Hithpolel'],
  'm': ['Poel', 'Poel', 'Poel'],
  'M': ['Poal', 'Poal', 'Poal'],
  'k': ['Palel', 'Palel', 'Palel'],
  'K': ['Pulal', 'Pulal', 'Pulal'],
  'Q': ['Qal passive', 'Qal 被动', 'Qal 被動'],
  'l': ['Pilpel', 'Pilpel', 'Pilpel'],
  'L': ['Polpal', 'Polpal', 'Polpal'],
  'f': ['Hithpalpel', 'Hithpalpel', 'Hithpalpel'],
  'D': ['Nithpael', 'Nithpael', 'Nithpael'],
  'j': ['Pealal', 'Pealal', 'Pealal'],
  'i': ['Pilel', 'Pilel', 'Pilel'],
  'u': ['Hothpaal', 'Hothpaal', 'Hothpaal'],
  'c': ['Tiphil', 'Tiphil', 'Tiphil'],
  'v': ['Hishtaphel', 'Hishtaphel', 'Hishtaphel'],
  'w': ['Nithpalel', 'Nithpalel', 'Nithpalel'],
  'y': ['Nithpoel', 'Nithpoel', 'Nithpoel'],
  'z': ['Hithpoel', 'Hithpoel', 'Hithpoel'],
};

/// Aramaic verb stems, from the Open Scriptures morphology spec
/// (`hb.openscriptures.org/parsing/HebrewMorphologyCodes.html`).
///
/// 2026-08-07: until now Aramaic verbs were labelled from [_hebStem],
/// which shares the slot but not the vocabulary. Every one of the 1,068
/// Aramaic verbs in the shipped corpus was therefore given a Hebrew
/// binyan's name: 634 Peals read "Qal", 144 Haphels read "Hiphil", 50
/// Hithpeels read "Hothpaal", and the 39 Aphel/Shaphel/Saphel forms —
/// stems Hebrew does not have at all — lost their stem entirely.
const _arStem = <String, List<String>>{
  'q': ['Peal', 'Peal 简单主动', 'Peal 簡單主動'],
  'Q': ['Peil', 'Peil 简单被动', 'Peil 簡單被動'],
  'u': ['Hithpeel', 'Hithpeel 反身', 'Hithpeel 反身'],
  'i': ['Ithpeel', 'Ithpeel 反身', 'Ithpeel 反身'],
  'p': ['Pael', 'Pael 加强主动', 'Pael 加強主動'],
  'P': ['Ithpaal', 'Ithpaal', 'Ithpaal'],
  'M': ['Hithpaal', 'Hithpaal', 'Hithpaal'],
  'a': ['Aphel', 'Aphel 使役主动', 'Aphel 使役主動'],
  'h': ['Haphel', 'Haphel 使役主动', 'Haphel 使役主動'],
  's': ['Saphel', 'Saphel', 'Saphel'],
  'e': ['Shaphel', 'Shaphel', 'Shaphel'],
  'H': ['Hophal', 'Hophal 使役被动', 'Hophal 使役被動'],
  't': ['Hishtaphel', 'Hishtaphel', 'Hishtaphel'],
  'v': ['Ishtaphel', 'Ishtaphel', 'Ishtaphel'],
  'w': ['Hithaphel', 'Hithaphel', 'Hithaphel'],
  'o': ['Polel', 'Polel', 'Polel'],
  'z': ['Ithpoel', 'Ithpoel', 'Ithpoel'],
  'r': ['Hithpolel', 'Hithpolel', 'Hithpolel'],
  'f': ['Hithpalpel', 'Hithpalpel', 'Hithpalpel'],
  'b': ['Hephal', 'Hephal', 'Hephal'],
  'c': ['Tiphel', 'Tiphel', 'Tiphel'],
  'm': ['Poel', 'Poel', 'Poel'],
  'l': ['Palpel', 'Palpel', 'Palpel'],
  'L': ['Ithpalpel', 'Ithpalpel', 'Ithpalpel'],
  'O': ['Ithpolel', 'Ithpolel', 'Ithpolel'],
  'G': ['Ittaphal', 'Ittaphal', 'Ittaphal'],
};

const _hebConj = <String, List<String>>{
  'p': ['perfect', '完成式', '完成式'],
  'q': ['sequential perfect', '连续完成式', '連續完成式'],
  'i': ['imperfect', '未完成式', '未完成式'],
  'w': ['sequential imperfect', '连续未完成式', '連續未完成式'],
  'h': ['cohortative', '劝勉式', '勸勉式'],
  'j': ['jussive', '祈使式', '祈使式'],
  'v': ['imperative', '命令式', '命令式'],
  'r': ['active participle', '主动分词', '主動分詞'],
  's': ['passive participle', '被动分词', '被動分詞'],
  'a': ['infinitive absolute', '独立不定词', '獨立不定詞'],
  'c': ['infinitive construct', '附属不定词', '附屬不定詞'],
};

const _hebPerson = <String, List<String>>{
  '1': ['1st person', '第一人称', '第一人稱'],
  '2': ['2nd person', '第二人称', '第二人稱'],
  '3': ['3rd person', '第三人称', '第三人稱'],
};

const _hebGender = <String, List<String>>{
  'm': ['masculine', '阳性', '陽性'],
  'f': ['feminine', '阴性', '陰性'],
  'b': ['common gender', '通性', '通性'],
  'c': ['common gender', '通性', '通性'],
};

const _hebNumber = <String, List<String>>{
  's': ['singular', '单数', '單數'],
  'p': ['plural', '复数', '複數'],
  'd': ['dual', '双数', '雙數'],
};

const _hebState = <String, List<String>>{
  'a': ['absolute', '独立式', '獨立式'],
  'c': ['construct', '附属式', '附屬式'],
  'd': ['determined', '限定式', '限定式'],
};

/// `HR/Ncfsa` → "preposition + noun common feminine singular absolute".
///
/// A Hebrew word is a stack of morphemes (conjunction + article +
/// preposition + stem + suffix), which OSHB writes `/`-separated. The
/// whole stack is shown, joined with `+`, because that IS the parse —
/// dropping the prefixes would misrepresent the word.
List<String> _some(List<String?> parts) =>
    [for (final p in parts) if (p != null) p];

String _semitic(MorphWord word, String locale) {
  final parts = <String>[];
  for (final m in word.morphemes) {
    final text = _semiticMorpheme(word, m, locale);
    if (text.isNotEmpty) parts.add(text);
  }
  if (parts.isEmpty) return word.raw;
  final text = parts.join(' + ');
  if (!word.aramaic) return text;
  final tag = _pick(const ['Aramaic', '亚兰文', '亞蘭文'], locale)!;
  return '$tag · $text';
}

String _semiticMorpheme(MorphWord word, MorphMorpheme m, String locale) {
  String? at(MorphSlot slot) {
    final code = m.slots[slot];
    if (code == null) return null;
    return morphSlotLabel(word.scheme, m.pos, slot, code, locale,
        aramaic: word.aramaic);
  }

  final subtype = at(MorphSlot.subtype);
  final person = at(MorphSlot.person);
  final gender = at(MorphSlot.gender);
  final number = at(MorphSlot.number);
  final state = at(MorphSlot.state);
  final posLabel = _pick(_hebPos[m.pos], locale);

  switch (m.pos) {
    case 'V':
      // Slot MEANING is settled by the parser; this only orders the
      // labels. Participles come out gender-number-state and finite
      // forms person-gender-number because that is how the parser filled
      // them, not because of a second copy of the rule.
      final bits = _some([
        at(MorphSlot.stem),
        at(MorphSlot.conjugation),
        person,
        gender,
        number,
        state,
      ]);
      return bits.isEmpty ? '' : _join(bits, locale);

    case 'N':
      return _join(
          _some([posLabel, subtype, gender, number, state]), locale);

    case 'A':
      return _join(
          _some([subtype ?? posLabel, gender, number, state]), locale);

    case 'P':
      // The type qualifies the noun ("demonstrative pronoun"), so it
      // leads rather than trails.
      return _join(
          _some([subtype, posLabel, person, gender, number]), locale);

    case 'S':
      return _join(
          _some([subtype ?? posLabel, person, gender, number]), locale);

    case 'T':
      return subtype ?? posLabel!;

    case 'R':
      // `Rd` is a preposition that has swallowed the article.
      return _join(_some([posLabel, subtype]), locale);

    default:
      // Empty, not the raw morpheme — an undecodable part is dropped so
      // `_semitic` can fall back to showing the whole original code.
      return posLabel ?? '';
  }
}

// ── Slot catalogue ──────────────────────────────────────────────────
//
// The query surface in `utils/morph_query.dart` is built from these,
// which is why they are exposed as functions over the private tables
// rather than by making the tables public: the labels a chip shows and
// the labels the parse line shows come from one lookup, so they cannot
// drift.

/// Which table a (scheme, part of speech, slot) triple reads from.
///
/// [pos] matters because the Semitic subtype slot is a different
/// vocabulary for every part of speech, and [aramaic] matters because the
/// stem slot is.
Map<String, List<String>>? _tableFor(
  MorphScheme scheme,
  String pos,
  MorphSlot slot, {
  required bool aramaic,
}) {
  if (scheme == MorphScheme.greek) {
    return switch (slot) {
      MorphSlot.pos => _gkPos,
      MorphSlot.person => _gkPerson,
      MorphSlot.tense => _gkTense,
      MorphSlot.voice => _gkVoice,
      MorphSlot.mood => _gkMood,
      MorphSlot.grammaticalCase => _gkCase,
      MorphSlot.number => _gkNumber,
      MorphSlot.gender => _gkGender,
      MorphSlot.degree => _gkDegree,
      _ => null,
    };
  }
  return switch (slot) {
    MorphSlot.pos => _hebPos,
    MorphSlot.stem => aramaic ? _arStem : _hebStem,
    MorphSlot.conjugation => _hebConj,
    MorphSlot.person => _hebPerson,
    MorphSlot.gender => _hebGender,
    MorphSlot.number => _hebNumber,
    MorphSlot.state => _hebState,
    MorphSlot.subtype => switch (pos) {
        'N' => _hebNounType,
        'A' => _hebAdjType,
        'P' => _hebPronType,
        'T' => _hebPartType,
        'S' => _hebSuffixType,
        'R' => _hebPrepType,
        _ => null,
      },
    _ => null,
  };
}

/// The localised label for one slot value, or null when the corpus
/// carries a code no published table names. Callers show the raw code in
/// that case — an unnamed tag is still a real distinction in the data.
String? morphSlotLabel(
  MorphScheme scheme,
  String pos,
  MorphSlot slot,
  String code,
  String locale, {
  bool aramaic = false,
}) =>
    _pick(_tableFor(scheme, pos, slot, aramaic: aramaic)?[code], locale);

/// Every value [slot] can take for a word of this scheme and part of
/// speech, in grammatical rather than alphabetical order (present,
/// imperfect, future, aorist… — the order the tables are written in,
/// which is the order a grammar teaches them).
///
/// Returns the empty list for a slot that does not apply.
List<String> morphSlotOptions(
  MorphScheme scheme,
  String pos,
  MorphSlot slot, {
  bool aramaic = false,
}) {
  if (slot != MorphSlot.pos && !morphSlotsFor(scheme, pos).contains(slot)) {
    return const <String>[];
  }
  return _tableFor(scheme, pos, slot, aramaic: aramaic)
          ?.keys
          .toList(growable: false) ??
      const <String>[];
}

/// The slots a word of this part of speech can carry, in the order a
/// grammar presents them.
///
/// Measured against the whole bundled corpus rather than copied from the
/// spec: MorphGNT, for one, leaves person blank on personal pronouns even
/// though the slot exists, so offering it would be offering a filter that
/// can never match.
/// The parse of ONE morpheme of an already-parsed word.
///
/// A search result has to say which part of `HC/Vqv2mp/Sp3fs` answered
/// the query; printing the whole word's parse and letting the reader
/// guess is how "feminine verb" comes to look like a wrong hit when it
/// is a right one.
String? describeMorphologyAt(MorphWord word, int index, String locale) {
  if (index < 0 || index >= word.morphemes.length) return null;
  final text = word.scheme == MorphScheme.greek
      ? _greek(word, locale)
      : _semiticMorpheme(word, word.morphemes[index], locale);
  return text.isEmpty ? null : text;
}

/// Every part of speech a scheme codes, in the order its table lists it.
List<String> morphPartsOfSpeech(MorphScheme scheme) =>
    (scheme == MorphScheme.greek ? _gkPos : _hebPos)
        .keys
        .toList(growable: false);

List<MorphSlot> morphSlotsFor(MorphScheme scheme, String pos) =>
    (scheme == MorphScheme.greek ? _gkSlots : _semSlots)[pos] ??
    const <MorphSlot>[];

const _gkSlots = <String, List<MorphSlot>>{
  'V-': [
    MorphSlot.tense,
    MorphSlot.voice,
    MorphSlot.mood,
    MorphSlot.person,
    MorphSlot.grammaticalCase,
    MorphSlot.number,
    MorphSlot.gender,
  ],
  'N-': [MorphSlot.grammaticalCase, MorphSlot.number, MorphSlot.gender],
  'A-': [
    MorphSlot.grammaticalCase,
    MorphSlot.number,
    MorphSlot.gender,
    MorphSlot.degree,
  ],
  'RA': [MorphSlot.grammaticalCase, MorphSlot.number, MorphSlot.gender],
  'RD': [MorphSlot.grammaticalCase, MorphSlot.number, MorphSlot.gender],
  'RI': [MorphSlot.grammaticalCase, MorphSlot.number, MorphSlot.gender],
  'RP': [MorphSlot.grammaticalCase, MorphSlot.number, MorphSlot.gender],
  'RR': [MorphSlot.grammaticalCase, MorphSlot.number, MorphSlot.gender],
  'D-': [MorphSlot.degree],
};

const _semSlots = <String, List<MorphSlot>>{
  'V': [
    MorphSlot.stem,
    MorphSlot.conjugation,
    MorphSlot.person,
    MorphSlot.gender,
    MorphSlot.number,
    MorphSlot.state,
  ],
  'N': [
    MorphSlot.subtype,
    MorphSlot.gender,
    MorphSlot.number,
    MorphSlot.state,
  ],
  'A': [
    MorphSlot.subtype,
    MorphSlot.gender,
    MorphSlot.number,
    MorphSlot.state,
  ],
  'P': [
    MorphSlot.subtype,
    MorphSlot.person,
    MorphSlot.gender,
    MorphSlot.number,
  ],
  'S': [
    MorphSlot.subtype,
    MorphSlot.person,
    MorphSlot.gender,
    MorphSlot.number,
  ],
  'T': [MorphSlot.subtype],
  'R': [MorphSlot.subtype],
};

/// A localised name for the slot itself ("Tense", "Stem", "State").
String morphSlotName(MorphSlot slot, String locale) =>
    _pick(_slotNames[slot], locale) ?? slot.name;

const _slotNames = <MorphSlot, List<String>>{
  MorphSlot.pos: ['Part of speech', '词类', '詞類'],
  MorphSlot.tense: ['Tense', '时态', '時態'],
  MorphSlot.voice: ['Voice', '语态', '語態'],
  MorphSlot.mood: ['Mood', '语气', '語氣'],
  MorphSlot.grammaticalCase: ['Case', '格', '格'],
  MorphSlot.degree: ['Degree', '级', '級'],
  MorphSlot.subtype: ['Type', '类别', '類別'],
  MorphSlot.stem: ['Stem', '语干', '語幹'],
  MorphSlot.conjugation: ['Conjugation', '动词形式', '動詞形式'],
  MorphSlot.state: ['State', '状态', '狀態'],
  MorphSlot.person: ['Person', '人称', '人稱'],
  MorphSlot.gender: ['Gender', '性', '性'],
  MorphSlot.number: ['Number', '数', '數'],
};
