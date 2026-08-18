/// The Masoretic Ketiv/Qere, in words a reader can use.
///
/// The Hebrew Bible carries, in 1,103 verses, two readings of one word:
/// the *Ketiv* (כְּתִיב, "what is written") stands in the consonantal
/// text, and the *Qere* (קְרֵי, "what is read") is what the Masoretes
/// direct be said aloud instead. The Leningrad Codex prints the Ketiv
/// unpointed — its vowels were lent to the Qere in the margin — and all
/// 1,257 Ketiv words in this corpus are unpointed, without exception.
///
/// Four roles, not two, because two would make the app say something
/// false at fourteen sites:
///
///   * `k` / `q` — the ordinary pair. 1,251 and 1,244 words.
///   * `kx` — *Ketiv velo Qere*, written and marked NOT to be read at
///     all. Six words: 2 Kings 5:18, Jeremiah 38:16, 39:12, 51:3,
///     Ezekiel 48:16, Ruth 3:12. Telling a reader to "read the Qere
///     instead" here would invent a Qere the Masoretes did not write.
///   * `qx` — *Qere velo Ketiv*, read though the text writes nothing.
///     Eight words, among them 2 Samuel 8:3 and Ruth 3:5, 3:17.
///
/// SeekSparks ships all of them, marked, and deletes none. BibleWorks
/// does the same: every WTM morphology code ends in `Rk`, `Rq` or `Rx`,
/// and a wildcard "will [match] all forms … including Qere, Kethib, and
/// neither" (help topic bwh17), with two separate settings to exclude
/// either from searches (bwh29). So our counts include both readings,
/// exactly as BibleWorks' do by default.
library;

/// The one-letter inline mark printed after the word. Deliberately the
/// same in every locale — it labels a Hebrew editorial category, and a
/// translated letter beside a Hebrew word would read as part of it.
///
/// `kx`/`qx` take the same letter as their ordinary kind. The letter's
/// job in the running text is to say which side of the distinction the
/// word falls on; what is unusual about these fourteen is a sentence,
/// not a glyph, and it is in [ketivQereNote].
String? ketivQereMark(String? kq) => switch (kq) {
      'k' || 'kx' => 'K',
      'q' || 'qx' => 'Q',
      _ => null,
    };

/// The full name, for a popup or an analysis line. [locale] is one of
/// `en`, `zh-Hans`, `zh-Hant`.
String? ketivQereLabel(String? kq, String locale) => switch (kq) {
      'k' => switch (locale) {
          'zh-Hans' => 'Ketiv 所写的',
          'zh-Hant' => 'Ketiv 所寫的',
          _ => 'Ketiv (written)',
        },
      'q' => switch (locale) {
          'zh-Hans' => 'Qere 所读的',
          'zh-Hant' => 'Qere 所讀的',
          _ => 'Qere (read)',
        },
      'kx' => switch (locale) {
          'zh-Hans' => 'Ketiv velo Qere 写而不读',
          'zh-Hant' => 'Ketiv velo Qere 寫而不讀',
          _ => 'Ketiv velo Qere (written, not read)',
        },
      'qx' => switch (locale) {
          'zh-Hans' => 'Qere velo Ketiv 读而不写',
          'zh-Hant' => 'Qere velo Ketiv 讀而不寫',
          _ => 'Qere velo Ketiv (read, not written)',
        },
      _ => null,
    };

/// One sentence saying why this word is marked. Phrased about the TEXT,
/// not about the screen: at a handful of sites the counterpart's lemma
/// carries no Strong's number and so never entered this corpus, and a
/// note promising a word "beside it" would then point at nothing.
String? ketivQereNote(String? kq, String locale) => switch (kq) {
      'k' => switch (locale) {
          'zh-Hans' => '经文所写的形式。马所拉学者指示改读 Qere；'
              '因为元音已借给 Qere，这个字不带元音符号。',
          'zh-Hant' => '經文所寫的形式。馬所拉學者指示改讀 Qere；'
              '因為母音已借給 Qere，這個字不帶母音符號。',
          _ => 'The form written in the text. The Masoretes direct that '
              'the Qere be read in its place, and leave this word '
              'unpointed because its vowels were lent to that Qere.',
        },
      'q' => switch (locale) {
          'zh-Hans' => '马所拉学者指示诵读的形式，取代经文所写的 Ketiv。',
          'zh-Hant' => '馬所拉學者指示誦讀的形式，取代經文所寫的 Ketiv。',
          _ => 'The form the Masoretes direct be read aloud in place of '
              'the written Ketiv.',
        },
      'kx' => switch (locale) {
          'zh-Hans' => '经文写下这个字，马所拉学者却指示完全不诵读它，'
              '也没有给出替代的读法。全书仅六处。',
          'zh-Hant' => '經文寫下這個字，馬所拉學者卻指示完全不誦讀它，'
              '也沒有給出替代的讀法。全書僅六處。',
          _ => 'The text writes this word, but the Masoretes direct that '
              'it not be read at all, and offer no reading in its '
              'place. Six words in the whole Hebrew Bible.',
        },
      'qx' => switch (locale) {
          'zh-Hans' => '马所拉学者指示诵读这个字，但经文并没有写下它。',
          'zh-Hant' => '馬所拉學者指示誦讀這個字，但經文並沒有寫下它。',
          _ => 'The Masoretes direct that this word be read, though the '
              'text does not write it.',
        },
      _ => null,
    };
