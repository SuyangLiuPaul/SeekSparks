/// 2026-09-08 (SeekSparks): the words the fuzzy search says out loud.
///
/// Shaped exactly like `stripStrings` and `wheelStrings` — a
/// `Map<String, Map<String, String>>` keyed by string-key then by
/// locale, every key carrying all three of `zh-Hans`, `zh-Hant` and
/// `en`. Kept in its own file rather than folded into `ui_strings.dart`
/// for the reason `strip_strings.dart` states in its own header: more
/// than one agent is appending to that file this week, and a shared file
/// is where two of them collide.
///
/// A NOTE ON THE TWO CHINESE COLUMNS, which this project has got wrong
/// before: `zh-Hant` is not `zh-Hans` with the characters swapped one
/// for one. Where a string uses no character that differs between the
/// scripts (`'分词'` does differ; `'同名'` does not) the same text
/// appears in both columns on purpose, because forcing a difference
/// where none exists is noise rather than correctness. Where a character
/// does differ (词/詞, 异/異, 体/體, 开/開, 见/見, 结/結, 设/設, 关/關,
/// 变/變) the Traditional column uses the Traditional form throughout.
///
/// ## Why every one of these is short
///
/// Four of them are appended to a verse reference in the result list —
/// `创世纪 1:1 · 异体字` — in a row that is already carrying a book name,
/// a chapter, a verse and a line of scripture. A label that wraps that
/// row to two lines costs more than it explains. So each is two or three
/// characters in Chinese and two words in English, and each names WHICH
/// looser reading found the row rather than saying "approximate" four
/// different ways: a reader who can see that 磯法 matched 矶法 has been
/// told something, and a reader who is told "fuzzy" has not.
library;

const Map<String, Map<String, String>> fuzzySearchStrings = {
  // ── The setting itself ──────────────────────────────────────────────
  //
  // Written for the Settings row that will sit beside "Ignore vowel
  // points and accents" (`searchIgnoresPointing` in `ui_strings.dart`),
  // whose switch this one is modelled on. The strings are here before
  // that row exists so the page that builds it reads a string instead of
  // inventing one.

  /// Deliberately not the word "fuzzy". BibleWorks calls its own version
  /// fuzzy and its help calls that "more of a curiosity than a refined
  /// tool"; what this switch actually does is let a search fall back to
  /// a looser reading when the exact one runs out, which is what the
  /// label says.
  'fuzzySearchSetting': {
    'zh-Hans': '找不到时放宽搜索',
    'zh-Hant': '找不到時放寬搜尋',
    'en': 'Broaden a search that finds nothing',
  },

  /// The subtitle carries the two facts a reader needs before flipping
  /// it: what gets added, and that they will be able to tell which rows
  /// those are. The examples are real — 耶和华 finds 0 verses in either
  /// Chinese edition this app ships, and 6,102 once this is on.
  'fuzzySearchSettingSubtitle': {
    'zh-Hans': '耶和华 也找 雅伟，磯法 也找 矶法，loved 也找 love。'
        '放宽找到的经文会另外标示。',
    'zh-Hant': '耶和華 也找 雅偉，磯法 也找 矶法，loved 也找 love。'
        '放寬找到的經文會另外標示。',
    'en': 'Lets 耶和华 reach 雅伟, 磯法 reach 矶法 and "loved" reach '
        '"love". Rows found this way are labelled.',
  },

  // ── Row labels, one per rung ────────────────────────────────────────
  //
  // `fuzzy_search.dart` names five rungs; only four appear here, because
  // the literal rung is the one that needs no label. A row with no label
  // contains what the reader typed. That is the whole contract, and it
  // is why these are per-rung rather than one shared "approximate": an
  // unlabelled row and a labelled one have to mean different things at a
  // glance, and four labels that name their reason are still a glance.

  /// The same word in the other Chinese script — 磯法 matching 矶法.
  /// Nothing about the query's meaning changed; only which keyboard the
  /// reader was typing on.
  'fuzzyLabelScript': {
    'zh-Hans': '异体字',
    'zh-Hant': '異體字',
    'en': 'other script',
  },

  /// Another spelling of the same name or word, from the synonym groups
  /// in `search_synonyms.dart` — 耶和华 matching 雅伟, 弥赛亚 matching
  /// 基督. The English reads "other spelling" and not "synonym" because
  /// every group in that file is one thing under two names, never two
  /// things that mean roughly the same.
  'fuzzyLabelSynonym': {
    'zh-Hans': '同名异写',
    'zh-Hant': '同名異寫',
    'en': 'other spelling',
  },

  /// English inflection — `loved` matching "love". Named for what
  /// changed (the form of the word) rather than for the algorithm that
  /// found it; "Porter stem" is true and tells a reader nothing.
  'fuzzyLabelStem': {
    'zh-Hans': '词形',
    'zh-Hant': '詞形',
    'en': 'word form',
  },

  /// The loosest rung: the query's own words, found in the verse but not
  /// side by side. This is the only label that has to warn as well as
  /// explain, because it is the only rung where the verse may not say
  /// what the reader asked — 信心的祷告 finds four verses that hold 信,
  /// 心, 祷 and 告 in separate places.
  'fuzzyLabelSegmented': {
    'zh-Hans': '词分开',
    'zh-Hant': '詞分開',
    'en': 'words apart',
  },
};
