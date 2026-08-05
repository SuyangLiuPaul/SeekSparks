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
library;

/// Human-readable parse of a morphology code, or null when [code] is
/// absent/empty. [locale] is one of `en`, `zh-Hans`, `zh-Hant`.
String? describeMorphology(String? code, String locale) {
  if (code == null) return null;
  final c = code.trim();
  if (c.isEmpty) return null;
  return _isGreek(c) ? _greek(c, locale) : _hebrew(c, locale);
}

/// The two schemes overlap on one letter: `A` opens every Aramaic code
/// AND is Greek's adjective part of speech (`A-----NSM-`). Length
/// settles it — every MorphGNT code is exactly 10 characters (2-char
/// part of speech + 8 dash-padded parse slots), while Open Scriptures
/// codes are variable-length and contain no dashes.
bool _isGreek(String c) =>
    c.length == 10 && _gkPos.containsKey(c.substring(0, 2));

/// Short one-word part of speech (for a compact chip next to the word).
String? morphologyPartOfSpeech(String? code, String locale) {
  if (code == null) return null;
  final c = code.trim();
  if (c.isEmpty) return null;
  if (_isGreek(c)) return _pick(_gkPos[c.substring(0, 2)], locale);
  final first = c.length > 1 ? c.substring(1).split('/').first : '';
  if (first.isEmpty) return null;
  return _pick(_hebPos[first[0]], locale);
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
String _greek(String code, String locale) {
  final pos = _pick(_gkPos[code.substring(0, 2)], locale);
  // The 8 parse slots are fixed-width and dash-padded; a short code just
  // means trailing slots were dropped, so read defensively.
  String slot(int i) {
    final idx = 2 + i;
    if (idx >= code.length) return '-';
    return code[idx];
  }

  final person = _pick(_gkPerson[slot(0)], locale);
  final tense = _pick(_gkTense[slot(1)], locale);
  final voice = _pick(_gkVoice[slot(2)], locale);
  final mood = _pick(_gkMood[slot(3)], locale);
  final kase = _pick(_gkCase[slot(4)], locale);
  final number = _pick(_gkNumber[slot(5)], locale);
  final gender = _pick(_gkGender[slot(6)], locale);
  final degree = _pick(_gkDegree[slot(7)], locale);

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
  if (groups.isEmpty) return code;
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

/// Hebrew binyanim + the Aramaic stems that share the slot.
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
String _hebrew(String code, String locale) {
  final isAramaic = code.startsWith('A');
  final body = code.substring(1);
  if (body.isEmpty) return code;
  final parts = body
      .split('/')
      .where((p) => p.isNotEmpty)
      .map((p) => _hebMorpheme(p, locale))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return code;
  final text = parts.join(' + ');
  if (!isAramaic) return text;
  final tag = _pick(const ['Aramaic', '亚兰文', '亞蘭文'], locale)!;
  return '$tag · $text';
}

String _hebMorpheme(String m, String locale) {
  final pos = m[0];
  String at(int i) => i < m.length ? m[i] : '';

  switch (pos) {
    case 'V':
      // V + stem + conjugation + (person gender number | gender number state)
      final stem = _pick(_hebStem[at(1)], locale);
      final conj = at(2);
      final conjLabel = _pick(_hebConj[conj], locale);
      final bits = <String>[
        if (stem != null) stem,
        if (conjLabel != null) conjLabel,
      ];
      // Participles and infinitives inflect for gender/number/state;
      // finite forms inflect for person/gender/number.
      if (conj == 'r' || conj == 's') {
        final g = _pick(_hebGender[at(3)], locale);
        final n = _pick(_hebNumber[at(4)], locale);
        final s = _pick(_hebState[at(5)], locale);
        bits.addAll([if (g != null) g, if (n != null) n, if (s != null) s]);
      } else {
        final p = _pick(_hebPerson[at(3)], locale);
        final g = _pick(_hebGender[at(4)], locale);
        final n = _pick(_hebNumber[at(5)], locale);
        bits.addAll([if (p != null) p, if (g != null) g, if (n != null) n]);
      }
      return bits.isEmpty ? '' : _join(bits, locale);

    case 'N':
      final type = _pick(_hebNounType[at(1)], locale);
      final g = _pick(_hebGender[at(2)], locale);
      final n = _pick(_hebNumber[at(3)], locale);
      final s = _pick(_hebState[at(4)], locale);
      final noun = _pick(_hebPos['N'], locale)!;
      return _join([
        noun,
        if (type != null) type,
        if (g != null) g,
        if (n != null) n,
        if (s != null) s,
      ], locale);

    case 'A':
      final type = _pick(_hebAdjType[at(1)], locale);
      final g = _pick(_hebGender[at(2)], locale);
      final n = _pick(_hebNumber[at(3)], locale);
      final s = _pick(_hebState[at(4)], locale);
      return _join([
        if (type != null) type else _pick(_hebPos['A'], locale)!,
        if (g != null) g,
        if (n != null) n,
        if (s != null) s,
      ], locale);

    case 'P':
      final type = _pick(_hebPronType[at(1)], locale);
      final p = _pick(_hebPerson[at(2)], locale);
      final g = _pick(_hebGender[at(3)], locale);
      final n = _pick(_hebNumber[at(4)], locale);
      return _join([
        if (type != null) type,
        _pick(_hebPos['P'], locale)!,
        if (p != null) p,
        if (g != null) g,
        if (n != null) n,
      ], locale);

    case 'S':
      final type = _pick(_hebSuffixType[at(1)], locale);
      final p = _pick(_hebPerson[at(2)], locale);
      final g = _pick(_hebGender[at(3)], locale);
      final n = _pick(_hebNumber[at(4)], locale);
      return _join([
        if (type != null) type else _pick(_hebPos['S'], locale)!,
        if (p != null) p,
        if (g != null) g,
        if (n != null) n,
      ], locale);

    case 'T':
      final type = _pick(_hebPartType[at(1)], locale);
      return type ?? _pick(_hebPos['T'], locale)!;

    case 'R':
      // `Rd` is a preposition that has swallowed the article.
      if (at(1) == 'd') {
        return _join([
          _pick(_hebPos['R'], locale)!,
          _pick(_hebPartType['d'], locale)!,
        ], locale);
      }
      return _pick(_hebPos['R'], locale)!;

    case 'C':
    case 'D':
      return _pick(_hebPos[pos], locale)!;

    default:
      // Empty, not the raw morpheme — an undecodable part is dropped so
      // `_hebrew` can fall back to showing the whole original code.
      return _pick(_hebPos[pos], locale) ?? '';
  }
}
