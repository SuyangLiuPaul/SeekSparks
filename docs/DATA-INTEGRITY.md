# Data integrity audit

Task #304. First run 2026-08-10, against v1.6.88.

> "accuracy is the most critical and important thing" — the user, 2026-08-09

## Why this document exists

#303 found that the Word List printed a romanisation of a *different
word* than the row it sat beside. It surfaced because one reader
happened to look at one row. Measured out, it was **8,030 rows across 66
books**, and **2,043 tests passed with it live** — because the suite
tests that code *runs*, not that data is *true*.

The question this document answers is not "is that one fixed" but **how
many more has nobody looked at**. A pane that is missing is an
annoyance. A pane that reads plausibly and is wrong will be believed and
quoted, and a reader of a Bible study tool cannot check our Greek
against anything except us.

## Method

Cross-check assets that describe the **same fact from different
directions** and report every disagreement with a count. Where two
sources must agree, a mismatch is a bug in one of them. Where only one
source exists, spot-check it and say plainly that it is unverified.

Two runners, deliberately split:

| | |
|---|---|
| `tools/audit_data_integrity.py` | the wide sweep; reports, does not gate. Runs in ~4s. |
| `test/data_integrity_test.dart` | the subset cheap enough for every commit. Runs in ~5s. |

Checks needing the app's own logic (morphology decoding, the book-name
table) are in the Dart test rather than the Python script:
re-implementing a decoder in Python would only prove the Python agrees
with itself.

## Results

Counts are reported **even when zero** — "checked 31,102 references,
found 0 gaps" is a real result, and it is the difference between "we
believe it is fine" and "we looked".

| # | Check | Examined | Disagreements | Outcome |
|---|-------|---------:|--------------:|---------|
| 1 | Strong's numbers resolve to a lexicon entry | 438,821 words | 86 words / 76 numbers | known & bounded |
| 2a | Morphology codes present | 438,821 words | 2,203 → **869** words | **fixed**, residual is genuine |
| 2b | Morphology codes decode to a parse | 4,037 distinct codes | **0** | clean, now a test |
| 3a | concordance.json per-book counts sum to `n` | 14,039 entries | **0** | clean, now a test |
| 3b | concordance.json agrees with `assets/originals` | 14,039 numbers | **0** | clean |
| 4 | Verse coverage per edition | 294,820 verses | 515 | **3 fixed**, rest documented |
| 5 | cross_references.json targets resolve | 279,597 refs | 1 source | upstream versification |
| 6 | Book names resolve for every edition | 13 editions | **3 fixed** | now a test |
| 7a | bible_places.json verse links resolve | 9,856 links | **0** | clean |
| 7b | bible_names.json verse links | 2,622 names | n/a | unverifiable by construction |
| 8 | Dates carry a recorded source | 196 records | 1 file | **fixed** by check 32 |
| 9 | Reader references resolve to the right original verse | 31,102 references | 1,823 wrong + 152 empty → **1** | **fixed**, was the worst finding |
| 10 | Character repertoire of the shipped text | 45,877,885 chars | 129 → **0** | **fixed**, now a test |
| 11 | Invisible format/control characters | 45,877,885 chars | 3 → **0** | **fixed**, now a test |
| 12 | 和合本 merge markers present in all three editions | 213 slots | 71 → **0** | **fixed**, now a test |
| 13 | The two 梁家鏗譯本 editions cover the same references | 15,843 refs | 8 → **4** | **fixed but for 馬可福音 6:8-11**, now a test |
| 14 | References carrying a typographic instruction instead of scripture | 295,527 records | 233 shown as scripture → **0** | **fixed**, now a test |
| 15 | Every reference appears exactly once, and no verse is empty | 15,850 records | 3 duplicated + 1 empty → **0** | **fixed**, now a test |
| 16 | Verse numbers left inline, printing as scripture | 15,850 records | 6 in 5 verses → **0** | **fixed**, now a test |
| 17 | Range labels (`1-4`) that overlap a verse with its own row | 42 range labels | 4 | **open**, frozen by a test |
| 18 | Traditional sermon bodies shorter than the Simplified they convert | 289 pairs | 3 → **0** | **fixed**, now a test |
| 19 | Chinese sermon bodies that are a summary, not a translation | 289 sermons | **10** | **not repairable**, marked and disclosed, now a test |
| 20 | Does a reference hold the right verse, or its neighbour's | 399,256 comparisons | 4 refs in 2 places → **0** | **fixed**, now a test |
| 21 | An edition's own verse markers printed as scripture (lxxwh) | 31,102 verses | 4,687 markers in 4,541 verses → **0** | **fixed**, now a test |
| 22a | Source alignment codes printed as scripture (cuvs-yhwh) | 533,914 codes | 329 stray chars in 169 verses → **0** | **fixed**, now a test |
| 22b | Table markup and non-word placeholders printed as scripture (bsb) | 386,063 runs | 726 tags + 25,357 placeholders → **0** | **fixed**, now a test |
| 22c | Do a word's Strong's digits survive the import (bsb) | 386,063 runs | **311,267 truncated** → **0** | **fixed**, now a test |
| 23a | Does any other tagged layer carry a bsb-style corruption | 10 layer pairs / 31,102 verses | **0** | clean, deficits are coverage |
| 23b | Does a word's Strong's number name that word (lxxwh Septuagint) | 479,989 runs | **12,099 name a different word** → **0** | **fixed**, now a test |
| 23c | Runs answering nothing where the edition already knows the answer | 49,614 empty runs | 8,295 → **0** | **fixed**, 41,032 honestly unanswerable |
| 24a | Morphology codes vs MorphGNT + OSHB (first *external* witness) | 436,630 words | **0** | clean, and the reason 24c is findable |
| 24b | Hebrew Strong's numbers vs OSHB | 299,567 words | **0** | clean |
| 24c | Does a Greek word's Strong's number name that word | 137,062 words | **15 name a different word** → **0** | **fixed**, now a test |
| 25a | Do the references the app *shows* resolve | 5,933 refs / 7 assets | 14 in ot_synopsis → **0** | **fixed**, now a test |
| 25b | Does the reader ever reach them | 139 OT groups | **0 reachable** → **139** | **fixed** |
| 25c | Passages dropped by a book-keyed map | 313 passages | **37 never rendered** → **0** | **fixed**, now a test |
| 24d | Does `assets/forms/` carry the parse the corpus carries | 136,067 form triples | **1,243 blank where the corpus has one** → **0** | **fixed**, now a test |
| 26a | Characters that render but cannot be read (和合本, 5 files) | 5,295,770 chars | **206 in 6 classes** → **0** | **fixed**, now a test |
| 26b | Verse ids well-formed and unique within an edition | 93,307 records | **1,764 malformed / 562 collisions** → **0** | **fixed**, now a test |
| 26c | 和合本 verse text vs an *external* witness | 31,102 verses | 392 → **383** | measured; residue is variants, listed |
| 27a | `bsb.json` verse text vs bereanbible.com | 31,086 verses | **0** | clean, 100.0000% |
| 27b | `kjv.json` verse text vs three *external* KJV witnesses | 31,102 verses | 851 → **749** | **101 fixed**, residue is this edition's orthography |
| 27c | Typographic damage in the English editions | 62,204 verses + 66 tagged books | **42,510 in 3 classes**, and 11,409 again in the tagged layer → **0** | **fixed**, now a test |
| 27d | Verses truncated by a length cap | 62,204 verses | **1** → **0** | **fixed**, now a test |
| 28a | The Chinese lexicon's scripture citations parse | 39,749 markup sites | **46,052 citations read**, 60 sites unreadable | grammar shipped, residue listed |
| 28b | Citations name a book the app can resolve | 44,221 book tokens | **2,304 unresolvable** → **9** | **fixed** (Traditional table completed), 9 ambiguous |
| 28c | Delimiters reaching the reader | 39,749 `#`/orphan-`\|` sites | **all of them** → **0 readable ones** | **fixed**, now a test |
| 28d | Mojibake in the Chinese lexicon | 14,696 entries | **3** | surfaced, not repaired — see below |
| 29a | References an edition does not carry, and what the reader saw there | 295,418 records / 31,102 refs | **426 rendered as nothing** → **0** | **fixed**, now a test |
| 29b | Are the Septuagint's absences its own text, or our loss | 304 absences vs an *external* LXX | **2 were our loss** → **0** | **fixed** by `tools/repair_lxx_transposed_verses.py` |
| 29c | Every absence sits in a chapter the edition otherwise carries | 424 absences / 11 editions | **0** | clean, now a test — the display rule depends on it |
| 31a | `assets/kjvs.json` against three external KJV witnesses | 30,708 unanimous verses | **0 departures** | clean — and it sharpens check 27's finding about `kjv.json` |
| 31b | Verse records the loader silently discards | 357,738 records / 13 editions | **116 psalm titles, unreachable since import** → **0** | **fixed**, now a test |
| 31c | Verse text padded with whitespace | 357,738 records / 13 editions | **31,199, all of them `leb`** → **0** | **fixed** by `tools/repair_verse_whitespace.py`, now a test |
| 32a | The Anno Mundi chain against the text that states it | 19 records | **0** | clean, now a test |
| 32b | Intervals scripture states, against the years we show | 11 intervals | **1** (creation→flood: text 1656, asset 1652) | disclosed, both ends marked approximate |
| 32c | What is actually in `birthYear` for the kings | 16 kings of Judah | **13 were reign starts shown as births** → **0** | **fixed**, now a test |
| 32d | A birth year no one could hold alone | 242 BC records | **121 share a year with someone else** | hedged with "c.", 44-man cohort disclosed |
| 32e | Each date asset's claim about its own source | 3 assets | **3 wrong or absent** → **0** | **fixed**, now a test |
| 33a | Psalm titles the reader displays and the search corpus lacked | 116 titles / 3 editions | **116 unsearchable, 11 words findable in no other verse** → **0** | **fixed**, witnessed by `bsb` + `kjvs`, now a test |
| 33b | Verses unfindable by the phrase they print (`[supplied]` brackets in the key) | 295,416 verses / 6 editions | **17,932**, of them **16,975 in `leb`** (54.6%) → **0** | **fixed**, now a test |
| 36a | The family tree's graph: reciprocal edges, live ids, no cycles | 312 edges / 26 marriages | **0** | clean, now a test |
| 36b | Years against each other and against the tree | 290 comparable edges | **8** (4 impossible gaps, 1 parent died first, 3 cross the am/bc seam) | reported, not repaired — every replacement year would be invented |
| 36c1 | Each printed name against the passages that record cites | 277 English + 277 Chinese | **3 English in no shipped edition** → **0**; **10 Chinese absent from the CUV** | English **fixed**, now a test; Chinese reported |
| 36c2 | Each parent-child and marriage claim against a passage that states it | 338 claims / 5 editions | **9 stated by no passage** → **5** | 4 were the name defect; the 5 are inferred links, reported |

| 39a | Septuagint absences whose words are in an earlier record (merges) | 302 absences, 55 read | **7** | named, and the row now says so — was "found by example, count unknown" |
| 39b | Source verses the edition's own `<vs:>` markers name and we do not carry | 30,800 records / 31,004 source refs | **153, at 32 sites** | reported, not repaired — importing Greek is the owner's call |
| 39c | Check 29c's two worked examples of a merge | 2 | **1 false** | corrected in place |
| 40a | Mojibake in the evidence archive (UTF-8 read back as Latin-1) | 225 records / every string | **152 strings in 111 records** → **0** | **fixed**, now a test |
| 40b | Does the `zh-Hant` slot hold Traditional, or Simplified wearing the label | 900 localized fields | **836 fields in 209 records were Simplified** → **0** | **fixed**, now a test |
| 40c | `_meta.confidenceCounts` against the records present | 225 records | summed to **209** | **fixed**, now a test |
| 40d | Does the Chinese title mean what the English title means | 225 title pairs | **2 defects, 8 occurrences** → **0** | **fixed**, now a test; 900 body fields unread |
| 40e | Image URLs, ids, references, icons | 716 URLs / 225 records | **0** (real bytes at all 206 hosts, 0 SPA fallbacks) | clean |
| 40f | The same Simplified-in-a-Traditional-slot screen on the two 繁體 Bibles | 2 editions / 62,204 verses | `cuvs-yhwh-tr` **0**; `biblexg-v2-tr` **207 flagged, mixed** | **open** — see "Next, in order" |
| 45a | Is every verse of a flat edition present in its tagged layer | 155,193 verses / 5 editions | **111 untagged**: 90 placeholders (correct) + **21 real Greek verses** | reported, **not** repaired — frozen by name, a fabricated run is worse |
| 45b | Do the tagged runs, concatenated, say what the flat verse says | 92,894 verses / kjvs, lxxwh, cuvs-plus | **0** | clean, now a test |
| 45c | The same question of `bsb` | 31,086 verses | **2** (Exodus 38:28 drops "of silver"; Judges 16:14 drops "it") | reported, pinned at exactly 2 |
| 45d | The same question of `cuvs-yhwh` | 31,102 verses | **372** = 161 orthographic + 116 note placement + 16 reordering + **79 real word differences** | superseded by 45g — 22 repaired, **350** remain; the reading-text half is the "Next, in order" item |
| 45f | Does the tagged layer print a character that is not text | 5 editions | **15** `cuvs-yhwh` verses render a literal `#` where the flat prints `[基督]` | **closed** by 45g — 17 marks in 15 verses now read `[基督]`; a test forbids the character |
| 45e | Tagged records naming a verse their edition does not have | 5 editions | **0** | clean, now a test |
| 45g | Can a third 和合本 edition adjudicate 45d's 79 | 31,102 verses × 3 files | **no** — `cuvs-plus` matches the reading text on **99.70% of characters**, so it is descent, not a witness; a majority vote proposed deleting the 六 of Judges 12:7 | the failure is the finding. 22 verses repaired without a vote; **21 word-level defects in the reading text** listed, not repaired |

*(Checks 34, 35, 37, 38 and 41–44 have full sections below but were never
given rows here; the omission is noted rather than guessed at.)*

---

### Fixed in this pass

Three defects, all of them a **label**, none of them a word of
scripture. Repaired reproducibly by `tools/repair_reference_defects.py`
so the change to 254 verses of Bible text is reviewable rather than an
unexplained diff.

**1. `assets/cuvs-plus.json` numbered all of 1 Chronicles 22 one verse
low.** What every other edition calls 22:1 (「大卫说：这就是耶和华神的殿，
为以色列人献燔祭的坛。」) was filed as **21:31**, so chapter 21 carried 31
verses and chapter 22 carried 18.

This is the worst of the three, because the text and its Strong's tags
agreed with *each other* — `assets/tagged/cuvs-plus/1_chronicles.json`
carried the identical shift — while `assets/originals/1_chronicles.json`
(the Hebrew corpus) is canonical at 30 and 19. So a 和简+ reader's Word
Study pane was showing **the Hebrew of the next verse** for the whole of
1 Chronicles 22, and nothing at all for 21:31. Every cross-reference and
commentary pointing into that chapter landed one verse off. Nothing
threw; no count looked odd.

Verified before repairing, not assumed: normalising away the 雅伟/耶和华
divine-name restoration and the 藉/借 and 么/吗 orthography, cuvs-plus
21:31 is character-identical to cuvs-yhwh 22:1, and cuvs-plus 22:N is
cuvs-yhwh 22:N+1 for all eighteen. Both cuvs-plus files were renumbered
together.

**2. `assets/leb.json` labelled Micah "Mic" and Nahum "Nah"** (152
verses). Neither string is a key in `bookNameToEnglish`, and `Verse.id`
is `bookNameToEnglish[book] ?? book` — so an LEB highlight in Micah was
keyed `Mic-1-1` while the same verse under every other edition is keyed
`Micah-1-1`. The comment on `Verse.id` says the English name is used
precisely to "enable cross-version highlight persistence"; for these two
books it silently did not. They are also absent from `standardBookOrder`,
so they sorted and localised wrongly — a Chinese UI printed the raw
"Mic", the #283 defect class. Their `id` fields additionally began `000`,
book zero; corrected to `033`/`034`.

*Carried forward:* a highlight made on LEB Micah or Nahum before this
fix stays keyed to the old string and will not follow the reader to
another edition. No migration was written — that would be speculative
repair of data that is probably empty, and the pre-fix state was already
broken in the same way.

**3. `assets/cuvs-yhwh-tr.json` labelled 2 Timothy 提摩太后書** (83
verses) — simplified 后 inside an otherwise traditional name.
`bookNameToEnglish` carries 提摩太后书 and 提摩太後書 but not the mixed
form, so the traditional edition's 2 Timothy resolved to no English book
at all. It was the only unmapped book name across all five Chinese
editions.

All three would now fail `test/data_integrity_test.dart`. That was
checked the only way it can be — by stashing the repaired assets and
watching the test name all three.

---

### Open, with the reason

**Check 2a — 2,203 tagged words carry no morphology code.** Fixed in
v1.6.92, down to 869; see "The parsing gap was mostly the Qere" below.

*Note for the next reader:* the #304 brief predicted "undecodable codes
are rendering blank in Word Study NOW". That prediction is **false** —
zero codes are undecodable, and an unrecognised one would fall through
to the raw string, not to blank. The blanks came from absent codes.

**~~Four verses print the Ketiv and the Qere as two consecutive words~~
— it was 1,103. FIXED in v1.6.147; see "The Ketiv and the Qere were
1,103 verses, not four" below.**

The four named here — 2 Samuel 18:20, Jeremiah 51:3, Ezekiel 48:16,
Proverbs 8:35 — were the four the *instrument* could see, not the four
that existed. And this entry's own second sentence was the tell: it
said the 1,257 unpointed Hebrew words corpus-wide are "the ordinary
Ketiv-unpointed convention and are correct". They are indeed the Ketiv.
That is the size of the defect, not evidence against it.

**Check 4 — verse coverage.** Measured per edition against KJV
versification, and only over the books an edition claims to carry, so a
NT-only edition is not "missing" the Hebrew Bible.

| Edition | Verses | Books | Gaps | Beyond canon | Note |
|---|---:|---:|---:|---:|---|
| kjv, kjvs | 31,102 | 66 | 0 | 0 | reference |
| cuvs-yhwh, cuvs-yhwh-tr | 31,102 | 66 | 0 | 0 | clean after fix 3 |
| cuvs-plus | 31,043 → **31,103** | 66 | 60 → **0** | 1 | the 60 were 和合本's merged verses; **fixed v1.6.93** |
| bsb | 31,086 | 66 | 16 | 0 | modern critical text |
| nasb | 31,090 | 66 | 13 | 1 | modern critical text |
| leb | 31,199 | 66 | 21 | 2 | 64 books and 32 gaps before the v1.6.91 repair |
| lxxwh | 30,798 | 66 | 304 | 0 | LXX/WH versification differs by design |
| biblexg-v2(-tr) | 7,920 / 7,923 | 27 | 40 | 3 | NT only, by design |

Two classes hide in that table and must not be conflated:

*Legitimate.* The "beyond canon" verses are all deliberate: 3 John 1:15
and Revelation 12:18 are modern splits/restorations, and biblexg-v2's
own block note on Acts 8:40 states it splits that verse "遵从最新希腊文
新约底本 NA28、UBS5". The gaps in bsb/nasb/leb are overwhelmingly verses
the critical text omits (Matthew 17:21, Mark 9:44, Acts 8:37 and
company). lxxwh's 304 are the LXX's own arrangement, Jeremiah above all.
None of these is a defect.

*Not legitimate.* **`assets/leb.json` was missing Judges (618 verses)
and Obadiah (21) outright** — an import gap, not a versification choice.
**FIXED in v1.6.91**; see "The LEB was a bad scrape" below, which also
covers four further defect classes the same investigation turned up.
After the repair, LEB's 21 remaining gaps are *all* known critical-text
omissions (Matthew 17:21, 18:11, 23:14; Mark 7:16, 9:44, 9:46, 11:26,
15:28; Luke 17:36, 23:17; John 5:4; Acts 8:37, 15:34, 19:41, 24:7,
28:29; Romans 16:25-27; 2 Corinthians 13:14; Nehemiah 7:68) — checked
one by one, nothing left over.

**`assets/cuvs-plus.json`'s 60 gaps were not omissions at all — and
checking them is what found eight other things.** This entry previously
said "60 real omissions remain". That was wrong, and the way it was
wrong is worth keeping: the gaps were counted against KJV versification,
which is the right frame for an English edition and the wrong one for
和合本, whose printed text **merges 71 verses into a neighbour** and sets
見上節 in the verse-number column. cuvs-yhwh and cuvs-yhwh-tr ship that
marker at all 71. cuvs-plus shipped it at **none**: 60 references were
simply absent from the file and the other 11 held ad-hoc junk in six
phrasings — three of them the bare letter `a`, two of them mojibake. So
a 和简+ reader on 民数记 1:21 got a blank, and on 诗篇 105:6 got
`5-6½ÚºÏ²¢`. **Zero words of scripture were ever missing.**
See "The 和合本 editions had eight defect classes" below.

**Check 9 — `assets/originals` is numbered in Hebrew versification and
every display surface asks it in English. This was the worst thing the
audit found. FIXED in v1.6.90 by a derived mapping table.**

Found by asking the fix-1 question of the whole corpus instead of one
book: does each tagged layer's key set match `assets/originals`? All
five layers disagree **identically** — 152 keys present in the tagged
layer and absent from originals, 204+ the other way, concentrated in
Joel 21, Numbers 16, 1 Chronicles 15, 1 Kings 14, Job 8. The uniformity
is the tell: this is not five separate import bugs, it is one systematic
difference, in exactly the books where the Masoretic and English chapter
divisions are known to part company.

`OriginalsService` looks up `'$chapter:$verse'` using **the reader's**
chapter and verse (`originals_service.dart:49`). So where the two
numbering systems diverge, the Word Study pane either shows nothing or
shows **the wrong verse's Hebrew**.

Joel, verified end to end:

- `assets/originals/joel.json` has four chapters — 20, 27, 5, 21 verses.
  That is the Hebrew book.
- Every shipped edition has three — 20, 32, 21. That is the English book.
- English Joel **2:28** ("I will pour out my spirit") asks for
  `originals['2:28']`. Hebrew Joel 2 ends at 27, so the lookup returns
  **null** and the pane is empty.
- English Joel **3:1** ("in those days … I shall bring again the
  captivity") asks for `originals['3:1']` and is handed
  וְהָיָ֣ה אַֽחֲרֵי כֵ֗ן אֶשְׁפּ֤וֹךְ אֶת רוּחִי֙ — which is the Hebrew of
  **2:28**. The reader is shown authoritative-looking Hebrew for a verse
  they are not reading.

**The full extent, measured before fixing.** The 152/204 figures above
are an undercount: they compare *key sets*, so they see only verses that
exist on one side and not the other. Walking every reader reference
against the original it would be handed shows **1,823 references
resolving to a different verse's original text and 152 to none** —
across **36 books**, not the five the key-set comparison named. Worst:
Psalms 979, 1 Chronicles 103, Deuteronomy 65, Daniel 62, Nehemiah 60,
Exodus 58, Hosea 46, 2 Samuel 43, 1 Samuel 38, Genesis 32.

**The fix: `assets/versification.json`, derived rather than asserted.**
`tools/derive_versification.py` reproduces it from the shipped data
alone. Arithmetic on verse counts would be guessing at scripture, so
instead the table is read out of the text: for each book, the original
is aligned against three independent Strong's-tagged translations
(KJV+S, 和合本雅伟版, BSB) by a banded monotone alignment over verses —
beads (1,1), (1,2), (2,1), (1,3), (1,0), (0,1), scored by Dice
similarity on each verse's set of Strong's numbers. A row ships only
where **all three layers agree**; 110 rows failed unanimity and were
dropped. Runs the layers left unresolved are filled by carrying the
offset between the nearest resolved anchors on either side, and only
when every target exists and none is already claimed.

Three independent confirmations that the result is true, not merely
self-consistent:

1. **It reproduces the documented Masoretic table it was never given.**
   Genesis 31:55→32:1, Leviticus 6:1→5:20, Numbers 16:36→17:1,
   1 Kings 4:21→5:1, 1 Chronicles 6:1→5:27, Job 41:1→40:25,
   Joel 2:28→3:1, Malachi 4:1→3:19, and every psalm superscription
   including the four two-line ones (51, 52, 54, 60).
2. **The `absent` list came out of the data as exactly the sixteen
   Received-Text verses** — Matthew 17:21/18:11/23:14, Mark
   7:16/9:44/9:46/11:26/15:28, Luke 17:36/23:17, John 5:4, Acts
   8:37/15:34/24:7/28:29, Romans 16:24 — and no others. Nothing in the
   pipeline knows that list; it falls out of KJV-vs-BSB disagreement.
   The Hebrew Bible adds exactly one, also unprompted: **Nehemiah
   7:68**, the horses and mules, which BHS does not carry (its 7:68 is
   the camels and donkeys the reader numbers 7:69). Before this, a
   reader on Nehemiah 7:68 was shown the Hebrew for camels.
3. **A text-support gate on every changed row.** Each row must resemble
   the reader's own tagged verse at least as well as the identity
   mapping it replaces, by Dice over Strong's numbers. Result over the
   1,991 rows: **1,971 improved, 19 equal, 0 degraded**. A deletion
   cannot be scored that way — "we now show nothing" scores zero against
   everything — so it is gated differently: the reader verse must be
   giving up an original number that a *rival* reference resembles more
   closely. Re-proved from the shipped assets in
   `test/versification_test.dart`, so a regression in the data fails the
   suite.

Consumers are fixed at one join point. `OriginalsService` now translates
the reference before the lookup, so all fifteen callers are corrected
together. Two directions are deliberately distinct: `originalKeys` is
**coverage** (a reference returns every original verse it renders, so a
merged psalm heading displays in full), while `rekeyBook` is a
**partition** (each original verse lands under exactly one reference, so
statistics and search cannot double-count). Verified across the whole
corpus: **438,821 original words before the re-key and 438,821 after**.

*Known residue, stated rather than papered over.* Exactly one original
verse remains unreachable: **Revelation 12:18** (7 words), and it is
genuinely translation-dependent. KJV+S renders it inside reader 13:1
("And I stood upon the sand of the sea" — Dice 0.973 against that verse
versus 0.914 for identity) while BSB renders it inside 12:17 (1.000
versus 0.927). No single table can serve both editions, so identity is
kept and the verse is simply not displayed. That is under-coverage, not
a false statement, which is the trade this document prefers.

Ten reader verses stayed at identity because the layers did not reach
unanimity — Psalms 135:1–2, Zephaniah 2:1–2, John 7:53–8:1, Revelation
12:17 and 13:1, Luke 1:1–2. Each was checked afterwards and identity is
right in every case: it scores 0.86–1.00 against the original on at
least two of the three layers. The disagreements are gaps in the Chinese
tagging, not numbering differences.

Fix 1 (cuvs-plus 1 Chronicles) is a *different* defect and stays fixed:
there, cuvs-plus disagreed with every other **English-versification**
edition, which no mapping table would excuse.

**Check 5 — one unresolved cross-reference source: `3 John 1:15`.** TSK
/ OpenBible are keyed to a versification that splits 3 John 14; KJV does
not. Consequence: a reader on 3 John 14 does not get those cross-refs.
Upstream, not ours, and not worth inventing a mapping for one verse.

**Check 8 — no date shown to a reader carries a per-record source —
CLOSED by check 32.** The brief was "add provenance". Measuring first
found something worse: 13 kings of Judah were showing an *accession*
year in a field named `birthYear`, so the app told the reader Asa was
born in 911 BC. Every record now carries a `dating` block naming what
its year is and what it rests on. See check 32 below.

---

### The LEB was a bad scrape — FIXED in v1.6.91

The missing Judges and Obadiah were the visible symptom of one cause:
`assets/leb.json` arrived at `6f13365 Initial commit`, inherited from
YsWords, and had never been checked. Chasing the two absent books turned
up **five** defect classes, all with the same signature — a scrape that
lost page boundaries. `tools/repair_leb.py` fixes all five reproducibly;
run it with no flags to re-verify, `--write` to apply.

| | Defect | Records |
|---|---|---:|
| R1 | Judges and Obadiah absent entirely | 639 restored |
| R2 | Two verses merged into one record, so the second reference did not exist | 11 split |
| R3 | A clause of the verse simply gone | 12 restored |
| R4 | The **next book's title** glued onto a book's last verse | 8 trimmed |
| R5 | Records filed under the book label `"The"` | 3 refiled |

R2 and R4 are the ones that matter most, because they read as scripture
and are not. `Hebrews 1:10` did not exist — 1:9 held both verses — so
every cross-reference to it resolved to nothing or to the wrong verse.
`Romans 16:24` ended "…Amen. Corinthians" and `1 Peter 5:14` ended
"…in Christ. Peter": a reader quoting the verse quotes a word no edition
of the Bible contains.

**The witness, and why it can be trusted.** The repair takes its text
from an independently obtained copy of the same edition
(`~/Documents/New project/yahwehdehua_bible/output/`, whose
`manifest.json` records site-owner authorization; 31,102 LEB records).
Nothing was invented. Two measurements were made *before* trusting it
for a single word:

1. **It is the same edition.** Over the 30,431 verses both copies hold,
   they agree on **30,276 (99.491%)** once whitespace is ignored.
2. **The markup transform is faithful.** Converting the witness's HTML
   conventions into this repo's house style (`<note: …>`, `[supplied]`,
   `--`) reproduces our own text **exactly** in 30,151 of those 30,431
   (**99.080%**). The residue is 125 Psalms structural differences and
   ~155 verses where *our* copy is itself inconsistent about the space
   before a note marker. That 99.08% is the honest error bar on the
   imported material.

Every repair is additionally a **containment** check, not a replacement:
R3 asserts our text is a prefix of the witness's and appends only the
tail; R4 asserts the trailing token equals the next book's name *and*
that what remains ends in sentence-final punctuation; R2 asserts our
record opens with the witness's first half and that what we hold is a
suffix of the second. A repair can only add text it has proven missing.

**Two hypotheses this investigation killed**, recorded so they are not
re-run:

- *"The witness truncates block quotations, so importing poetic Judges 5
  would corrupt it."* Disproved by calibration: the 11 suspect verses
  score 0.89–1.25 on a word-count ratio against BSB (median over 30,169
  verses: 1.062), and Judges/Obadiah score a median 1.050. The witness
  is the correct copy; **ours** is the side that merges verses.
- *"Romans 16:25-27, 2 Corinthians 13:14 and Acts 19:41 are missing."*
  They are not defects. The LEB carries the Romans doxology **inside**
  `<note: Some manuscripts include vv. 25-27, …>` on 16:24, so those
  verses genuinely do not exist in this edition.

**Known residue, stated plainly.** The witness drops the LEB's `{…}`
idiom braces entirely (0 of 31,102 records), whereas our 64 original
books carry them in 8,041 verses (26%). So **Judges, Obadiah and the 11
R2 second halves ship without that notation.** This is under-coverage of
a marker, not a false statement about the text — the same category as
the Revelation 12:18 mapping limit above. Recovering it needs a witness
that preserves the braces.

### The parsing gap was mostly the Qere — FIXED in v1.6.92

**2,203 → 869 untagged words** of 438,821 (0.50% → 0.20%). The Hebrew
Bible went **1,252 → 1**. Regenerated by `tools/merge_morphology.py`
against the same MorphGNT and OSHB releases as before; the gap was never
upstream, it was in how we read them.

**The Hebrew cause — 1,235 of the 1,334 recovered words.** OSHB does not
put the Qere where a direct-children read can see it. The verse's own
`<w>` is the **Ketiv**, and the word actually read aloud is nested one
level down in a following sibling: `<note type="variant"><rdg
type="x-qere"><w>`. Our loader iterated the verse's `<w>` children, so
for every Ketiv/Qere slot it took the written form's morphology — and
where the two differ, that is the wrong parse for the word the reader
sees. It also never saw the 10 "Qere without Ketiv" words, which exist
only inside the note.

That the old code left them blank rather than borrowing is the only
reason this was a coverage bug and not a wrongness bug: **653 of the
1,244 K/Q slots carry a different parse on the Qere than on the Ketiv**,
so a borrow would have printed a false parsing for over half of them.
The merge now reads the Qere as authoritative and lets the Ketiv
gap-fill only.

**The Greek cause — the movable nu, ~85 words.** ἀπέχουσιν and ἀπέχουσι
are one word with one parse; SBLGNT may carry either. Matching `X` to
`Xν` unconditionally is not safe, so the guard is environment-scoped:
only after `-σι`, `-ε` or `-τι`, and for a non-verb only when MorphGNT's
own slots say dative plural (code index 6 = `D`, index 7 = `P`).

**A fallback that was measured, then rejected.** "If the untagged form
appears elsewhere in the same verse with exactly one code, reuse it"
would have closed 179 more Greek words. It is wrong. SBLGNT's only τοῦ
at Matthew 3:16 is the neuter of ἀπὸ τοῦ ὕδατος; the received text's
second τοῦ is the masculine of τοῦ Θεοῦ. The rule is plausible, prints
a confident wrong gender, and nothing in the app would have flagged it.
It is written into the tool's docstring so the next person does not
rediscover it as a good idea.

**Proved safe, not merely effective.** A structural fingerprint over all
66 regenerated files: **0** words of text changed, **0** Strong's numbers
changed, **0** transliterations changed, **0** parses lost. Two parses
changed, both corrections — 1 Chronicles 9:4 `בָּנִי` (H1137, the proper
name Bani) had been parsed as a common-noun construct, and Proverbs 8:35
recovered a dropped 1cs suffix.

**The 869 that remain are not a bug to fix.** 868 are Greek: the shipped
originals are a received-text edition and SBLGNT is a critical one, so
readings SBLGNT does not carry have nothing to take a parse from. 222 of
them are the 15 verses of John 7:53–8:11 and Romans 16:25–27, which are
wholly unparsed and are pinned as such by a test. The 1 Hebrew survivor
is the doubled Qere at 2 Samuel 18:20 — the doubling itself is fixed in
v1.6.147, immediately below.

Word Study now **says so** instead of rendering nothing: a missing parse
prints a bordered line naming the corpus it was measured against
(SBLGNT for Greek, Open Scriptures/WLC for Hebrew). A blank that
explains itself is information; a blank that does not is a bug report.

### The Ketiv and the Qere were 1,103 verses, not four — FIXED in v1.6.147

**The defect.** `tools/build_originals.py` read the WLC with
`verse.iter(f'{NS_OSIS}w')`. `iter` is a **descendant** walk, and the
WLC keeps the Qere inside an apparatus note:

```xml
<w type="x-ketiv" lemma="5921 b" morph="HR">על</w>
<note type="variant">
  <catchWord>על</catchWord>
  <rdg type="x-qere">
    <w lemma="5921 b" morph="HR">עַל</w>
    <w lemma="3651 b" morph="HTm">כֵּן</w>
  </rdg>
</note>
```

So the marginal reading was lifted out of the apparatus and printed as
running text, immediately after the written one, with nothing to say
where it came from. **1,103 verses and 2,509 words** — 1,260 sites in
the WLC apparatus, 1,255 of them visible in this corpus. Genesis 30:11
shipped as `בגד בָּא גָד` — Leah naming Gad, one word written and two
read, all three printed as if the Hebrew said them. Genesis 24:33 opens
on `ויישם וַיּוּשַׂם`, which is not even the same verb: H3455 and H7760.
**206 of the 1,255 sites carry a different set of Strong's numbers on
the two sides**, so this was not a cosmetic doubling; it put a word in
the Hebrew Bible that no manuscript reads there.

**Why the recorded scope was four.** The old instrument scanned for a
word repeated adjacently. That finds a Ketiv/Qere pair only where the
two readings are spelled the *same* — `על על`, `ידרך ידרך`, `חמש חמש`,
`מצאי מצאי`. The other ~1,100 are spelled differently, which is the
whole reason the Masoretes wrote a note, and were invisible to it. A
defect measured by an instrument that can only see one of its shapes
will report the size of the instrument, not the size of the defect.

**The join, proved before it was trusted.** The role cannot be read off
the shipped asset — a Qere is an ordinary pointed word — so it comes
from the WLC, and a wrong join would mislabel scripture. Replaying the
importer's own filter (a `<w>` is kept iff `_hebrew_strongs(lemma)` is
non-empty) reproduces the shipped word sequence in **23,213 of 23,213
verses**, word for word, 0 mismatches. Two independent counts agree:
the WLC marks 1,268 Ketiv words and every one is unpointed, and the
shipped asset holds exactly 1,257 unpointed Hebrew words in 300,808 —
the 11 missing are Ketiv forms whose lemma carries no Strong's number,
which this corpus drops for every word, not only these. After the
repair those two sets coincide exactly: **1,257 words are marked Ketiv
and 1,257 Hebrew words are unpointed, and they are the same 1,257.**

**Marked, not deleted, and that is the reference behaviour.** Every
affected word carries a `kq` field; nothing was removed. BibleWorks
does the same: every WTM morphology code ends in `Rk`, `Rq` or `Rx`,
and "if you end forms with a wildcard asterisk … all forms will be
matched, including Qere, Kethib, and neither" (help topic bwh17), with
two separate settings — "Include qere readings", "Include kethib
readings" — to drop either from a search (bwh29). So SeekSparks' counts
include both readings, exactly as BibleWorks' do by default. Deleting a
word from shipped scripture would have been a text-editorial decision
and is not one an unattended run may take.

**Four roles, because two would have lied at fourteen sites.** Once the
apparatus is read properly it says three different things, not one:

| role | meaning | words |
|---|---|---|
| `k` | Ketiv, with a Qere directing what to read instead | 1,251 |
| `q` | that Qere | 1,244 |
| `kx` | *Ketiv velo Qere* — written, and marked not to be read at all (an **empty** `<rdg type="x-qere"/>`) | 6 |
| `qx` | *Qere velo Ketiv* — read though the text writes nothing | 8 |

The `kx` six are 2 Kings 5:18, Jeremiah 38:16, 39:12, 51:3, Ezekiel
48:16, Ruth 3:12. Telling a reader of Ezekiel 48:16 to "read the Qere
instead" would invent a Qere the Masoretes did not write — the
direction there is to read nothing. This is why the reader-side note is
phrased about the **text** and never promises a word "beside it": the
role is decided on the raw apparatus, before the Strong's-number filter
drops anything, so it stays true even where the counterpart never
entered this corpus.

**What is still missing, and why.** The WLC has nine *Qere velo Ketiv*
sites; eight are here. Jeremiah 50:29's is absent because its lemma
carries no Strong's number. Likewise ~19 Ketiv words stand with their
Qere absent — Exodus 21:8's לא/לו crux is the clearest, where the Qere
לוֹ has lemma `l` and no number. This is the corpus-wide
Strong's-filter limitation, not a Ketiv/Qere one: those words are
missing everywhere. *(The v1.6.92 note above says "10 Qere without
Ketiv"; measured here on site structure it is 9 in the WLC and 8
shipped. The two were counted by different rules and the discrepancy
has not been chased.)*

**The generator was fixed too, and proved against the asset.**
`build_originals.wlc_verse_words` now descends explicitly and assigns
the role; `tools/repair_originals_qere.py` **imports** that function
rather than restating it, so the two cannot drift. Replaying the fixed
generator over the cached WLC reproduces all 39 shipped Hebrew books —
23,213 verses, every word, every Strong's number, every `kq`, in the
same key order — with 0 mismatches. The repair is idempotent: a second
`--check` reports 0 files would change, and Jonah and Malachi (no
Ketiv) round-trip byte-for-byte identical.

**What the reader now sees.** Both readings, with the Ketiv set in the
muted ink so the Qere reads as the running text, a `K`/`Q` letter after
each — printed always, not behind the Strong's-numbers toggle, because
it is the only thing explaining why two words stand where the text has
one — and, in the hover popup and in Word Study, the role's name and a
sentence saying what the Masoretes directed, in English, 简体 and 繁體.
`test/ketiv_qere_test.dart` freezes the counts, the four named verses,
both unpaired lists, and the invariant that every Ketiv is unpointed
and every Qere is pointed.

### The 和合本 editions had eight defect classes — FIXED in v1.6.93

The assigned item was "check cuvs-plus's 60 gaps against 和合本". The
premise turned out to be false in the reader's favour — nothing was
missing — and chasing it anyway surfaced **eight** corruption classes
across four Chinese editions. All eight are repaired reproducibly by
`tools/repair_chinese_text_defects.py`, which is idempotent, refuses any
site a witness does not corroborate, and prints what it skipped.

Every repair is gated on a witness **already in this repository**, and
the repaired string must match that witness exactly, not approximately:

- `assets/cuvs-plus.json` — 和合本+Strong's, the same base text as
  cuvs-yhwh but imported separately.
- `assets/tagged/cuvs-yhwh/` — a **second copy of cuvs-yhwh's own text**,
  carried alongside the Strong's tags. Where the two copies of one
  edition disagree, one of them is wrong, and this is what localises the
  error rather than merely detecting it.
- `assets/originals/` — the Hebrew, for the one verse-boundary question.

| # | Where | Defect | Repaired to |
|---|---|---|---|
| R1 | cuvs-plus 申命记 28:52 | a **whole verse** of Deuteronomy as GBK bytes decoded as Latin-1: 「他们必将你困在你各³ÇÀï£¬Ö±µ½」. The tagged layer carried the identical corruption. | 「…你各城里，直到…」 |
| R1 | cuvs-plus 诗篇 105:6, 116:19 | two merge markers corrupt the same way (`5-6½ÚºÏ²¢`) | 见上节 |
| R2 | cuvs-plus 士师记 13:7, 18:10 | a stray U+25A1 `□` **inside** the single token carrying H430 | 神 |
| R3 | cuvs-yhwh + -tr 士师记 8:15 | `ㄤ萑` — a Bopomofo letter and a second character where one belongs | 现 / 現 |
| R4 | cuvs-yhwh + -tr 撒母耳记下 2:23 | `𨱔` (U+28C54, plane 2) | 鐏 |
| R5 | cuvs-plus, 71 sites | 60 merge markers absent, 11 replaced by junk | the marker cuvs-yhwh already ships, copied verbatim |
| R6 | cuvs-plus 申命记 4:32–33 | 和合本's merged block split **at the wrong point** | merged, matching cuvs-yhwh |
| R7 | cuvs-yhwh + -tr, 8 verses | `䍁` (U+4341) for `繸` — Numbers 15:38's tassels and the hem of Jesus' cloak | 繸 |
| R8 | biblexg-v2, 3 verses | invisible U+00AD SOFT HYPHENs inside the text | removed |

Three of these deserve their reasoning stated, because the evidence, not
the reading, is what decided them:

**R6 is the only verse-BOUNDARY defect, and the Strong's tags proved it.**
和合本 merges Deuteronomy 4:32–33 because the Chinese inverts the two
clauses of the Hebrew. cuvs-yhwh does that. cuvs-plus split the block by
**position** instead, which lands the clauses under the wrong numbers:
its 4:33 是「这样的大事何曾有、何曾听见呢？」, the *tail* of Hebrew 4:32,
while Hebrew 4:33 sits inside its 4:32. cuvs-plus 4:32 scores Dice
**0.615** against Hebrew 4:33 and **0.513** against Hebrew 4:32. A
cross-reference to Deuteronomy 4:33 landed on the wrong clause, and Word
Study offered Hebrew that did not match the Chinese beside it. The repair
is gated on cuvs-plus 4:32+4:33 concatenated being character-identical to
cuvs-yhwh 4:32.

**That the TRADITIONAL edition carries R3, R4 and R7 too is the tell.**
A traditional text does not simplify a character. Both files inherited
one corrupt source, so the corruption is not an orthographic choice and
the traditional repair may be gated on its simplified sibling's having
been proved — which is stated in the code rather than implied.

**R7 was found by a sweep, not by reading.** `䍁` was the only CJK
Extension A character in the entire Chinese corpus. That is the general
lesson of this pass:

> **The character-repertoire check is the one that works.** A wrong
> character throws nothing, breaks no key, and **renders** — CanvasKit
> only drops a glyph it has no font for, and the bundled subsets were
> measured at **0 missing code points** across the shipped Chinese
> scripture. So 申命记 28:52 drew its garbage perfectly legibly. A
> tagged-vs-plain text comparison was tried first and abandoned: it
> returns 22,817 raw disagreements on bsb alone, all of them markup
> convention, and it would not have caught the mojibake anyway because
> **both copies were identically corrupt**.

Both new checks are now permanent, in `tools/audit_data_integrity.py` and in
`test/data_integrity_test.dart`:

| Check | Examined | Before | After |
|---|---:|---:|---:|
| Character repertoire (every edition, every tagged layer, originals) | 45,877,885 chars | 129 | **0** |
| Invisible format/control characters, whole corpus | 45,877,885 chars | 3 | **0** |
| 和合本 merge markers present in all three editions | 213 slots | 71 | **0** |

Counts after the repair, all measured rather than assumed: cuvs-plus
31,103 verses / cuvs-yhwh 31,102 / cuvs-yhwh-tr 31,102; the only
reference cuvs-plus holds that cuvs-yhwh does not is 3 John 1:15, and
there are none the other way.

**The merge marker's presentation — deferred here, FIXED as check 14
below.** This entry previously read "left alone, deliberately", on the
grounds that 见上节 is at least *true* where `a` and `5-6½ÚºÏ²¢` were
not, and that presentation is not accuracy. The second half of that was
wrong. A sentence the app sets in scripture type **is** a claim about
what the verse says, and "见上节" is not what 詩篇 8:8 says.

### Check 14 — 233 references printed the edition's instruction as scripture. FIXED in v1.6.93

Found by asking check 12's question the other way round. Check 12 proved
the marker is *present* in all three 和合本 editions; it says nothing
about what the app then *does* with it. It rendered it as the verse.

Swept across all 11 shipped editions, **295,527 records**, and the whole
set is **233** — small, bounded, and entirely placeholders:

| Kind | Count | Where |
|------|------:|-------|
| `merged` — printed under an earlier verse | 213 | 见上节/見上節 ×210 in the three 和合本 editions, plus 詩篇 63:6's 合和譯本並入上一節 ×3 |
| `mergedNext` — printed with the verse that follows | 3 | 約翰福音 7:53, whose words open a pericope the edition sets from 8:1 |
| `omitted` — not in this edition's base text | 16 | `assets/lxxwh.json`, the literal string `OMIT` |
| `blank` — no text at all | 1 | `biblexg-v2-tr` 馬太福音 16:1 |

Both later checks moved the last row and nothing else. Check 13 deleted
that 馬太福音 16:1 husk, and check 20 emptied 和简+ 馬可福音 9:44 and 9:46,
so the corpus is **295,532 records** and **234** placeholders today —
`blank` 2, the rest unchanged. `test/data_integrity_test.dart` carries
the live census; this table is what v1.6.93 measured.

Three things decided the shape of the fix, and each is a test rather
than an assertion:

- **The marker is matched WHOLE, never as a substring.** A `contains`
  rule on 上节 would blank real scripture — the corpus holds verses like
  除酵节，又名逾越节，近了。 A wider regex over every short verse that
  mentions the verse above or below finds **0** the recogniser misses,
  so the whole-match rule loses nothing.
- **The merge CHAINS, so the head is not `verse - 1`.** 詩篇 8:7 *and*
  8:8 are both markers; 8:8's "verse above" is itself a placeholder and
  both resolve to **8:6**. Resolution therefore happens once per edition
  in `FetchVerses`, where the whole chapter is in hand, rather than at
  the twenty-odd surfaces that render a verse and are handed one. All
  **213** resolve to a verse that has words; **0** are unresolvable.
- **An unresolvable head would be left unnamed, not guessed.** The
  reader would get "printed with an earlier verse" rather than a wrong
  verse number. The shipped corpus needs it nowhere, which is itself
  asserted.

The instruction stays in the assets. It is what the printed page says,
and the honest presentation is to *explain* the edition's convention —
「与第 6 节合并印行」 in the reader's own UI language — not to hide it.
`assets/lxxwh.json`'s sixteen `OMIT`s matter most: that is the Greek
column, the one a reader cannot check against anything except us. That
those sixteen are exactly the set check 9 derived independently in
v1.6.90, from KJV-vs-BSB disagreement and knowing nothing about this
file, is two unrelated sources agreeing.

Reaches the reader, Browse, the sermon-citation popup, search and the
clipboard: a placeholder is now excluded from both search-key caches
(so a search for 上节 cannot report hits that are not scripture) and
dropped from copied output entirely.

### The 梁家鏗譯本 verse boundaries — 7 of 8 repaired, and 3 more found

**The earlier verdict on this was wrong, and the way it was wrong is
worth recording.** Checks 13 and 15–17 compared the two files *by key
set* and concluded that filling either gap needed a 简/繁 conversion this
repository cannot perform without inventing characters. Re-reading the
same two files **in record order** shows the text is present in every
case but one — filed under the wrong number, merged into its neighbour,
or split across two rows. A key-set comparison cannot see any of that,
because a misfiled verse still occupies a key.

Repaired reproducibly by `tools/repair_biblexg.py`, which is idempotent
and guards every cut on the text it expects to find. No repair creates a
character the file did not already contain, and none reads text out of
the other script's file: the two editions were **independently revised**,
not merely transliterated — 使徒行傳 15:17 is 為了人類中餘下的人 in
traditional against 为了人类其他成员 in simplified — so the sibling file
is a witness to **structure only**, never to wording. That is a
correction to the earlier note as well, which treated them as one text in
two scripts.

Traditional file only, in descending order of what a reader lost:

- **馬太福音 16:13 was filed as 16:3**, colliding with the real 16:3. Not
  "gone outright". The source read `13` and the converter cut it into an
  empty verse `1` and a verse `3` carrying the text, so the edition
  answered 馬太福音 16:3 with either the weather-signs saying or the
  Caesarea Philippi question depending on which row the index kept. This
  is the worst kind of defect in the file: plausible, wrong, and
  unfalsifiable by a reader.
- **使徒行傳 15:16 was two rows** with the same reference — the prose
  「如經上所記：」 and the Amos quotation it introduces, which the
  converter promoted to its own block. Lookup kept one, so the reader
  lost half a verse. The simplified file holds both halves in one row,
  which is the structure followed.
- **以弗所書 3:16's verse number was swallowed by the preceding
  footnote**, which read `參4.6、16`. A trailing separator is house style
  (`參2.18註，加4.6註，` ends the same way and loses nothing) and the
  simplified file carries `参4.6，` with no 16 while holding 3:16
  separately, so the `16` was the verse marker rather than a second
  cross-reference.
- **彼得前書 3:11 and 3:12 were merged into 3:10** with their numbers
  left inline, so 3:10 printed 「⋯不沾詭詐。11還要避惡行善⋯」.

Both files, and these were **not previously known** — a key-set
comparison cannot find a defect the two files share:

- **路加福音 22:43-44** sat inline inside 22:42, **23:17** inside 23:16,
  and **23:34a** at the end of 23:33 while the row numbered 34 held only
  34b. So this edition answered 路加福音 23:34 with 「然後，他們抓鬮分了
  耶穌的衣袍。」 and never with 「父親啊，赦免他們」 — one of the most
  quoted verses in the Gospels, unreachable at its own reference.

**The one judgement call**, flagged because it is the only inference
here. Those three are the passages NA28/UBS5 double-bracket, so their
inline placement could be deliberate critical-text marking rather than a
converter failure. Read as a failure, because the same converter
demonstrably loses verse numbers into adjacent markup (以弗所書 3:16) and
cuts them in half (馬太福音 16:13), and because the digits carry no
bracket, no footnote and no other signal a reader could act on — this
edition annotates such things explicitly when it means to, as 羅馬書 16:24
shows with 「按 NA28 及 UBS5，在此羅馬書完」. Splitting them makes the
verses findable and stops a bare number reading as scripture; it does
flatten the publisher's 34a/34b distinction, which the schema has no way
to express. Reversible from `tools/repair_biblexg.py` if a human decides
otherwise.

**Not repaired**, and the original reasoning still holds for it:
馬可福音 6:8-11 are absent from the simplified file, whose 6:7 also stops
mid-clause at 「并授予他们权能」. Only the traditional file has them, so
restoring them needs a 繁→简 conversion. Frozen by name in
`test/biblexg_verse_boundary_test.dart`.

**Also measured, not repaired.** Twenty-one records in each file carry a
range label — `1-4`, `18-19`, `74-75` — because the publisher printed
those verses merged. That is honest labelling and not a defect; a reader
sees 「1-4」 and knows. But two of the forty-two ranges name a verse that
**also exists as its own row**: 以弗所書 2:20 labelled `20-21` and 3:10
labelled `10-11`. 2:20 is defensible, since it genuinely pulls 2:21's
「在主內的一座聖所」 forward; 3:10 carries nothing of verse 11 and looks
like a stray label. Left alone rather than corrected, because changing a
publisher's label on a reading of the Greek is exactly the kind of guess
this document exists to prevent, and the cost to a reader is a wrong
number beside a verse rather than wrong text. Frozen at 2 per file.

### Clean, and worth saying so

- **Every one of 4,037 distinct morphology codes decodes** to a human
  parse. Frozen as a test, because the corpus is merged offline and an
  upstream scheme change would otherwise land silently.
- **concordance.json is internally consistent** — all 14,039 per-book
  maps sum to their stated total — **and agrees exactly with
  `assets/originals`**: 0 numbers in one source and not the other, 0
  totals disagreeing, 0 book-level cells disagreeing. Stats and the Word
  List cannot give a reader two different numbers for the same word.
- **All 9,856 verse links in `bible_places.json` resolve**, with 0
  unmapped book abbreviations. (43 of 1,276 places have no coordinates,
  which is an absence, not an error. Bethlehem — flagged in the brief as
  possibly missing — is present.)
- **0 Strong's numbers appear in the wrong testament**: no G-number in
  an OT book, no H-number in the NT. The language prefix is a safe
  router, which several panes already assume.
- The 76 lexicon-less Strong's numbers are all extended-MorphGNT
  (G6000–G6095 with gaps, plus G6897, G6986, G7013, G7530, G9577,
  G9992), covering **86 words** — 0.02% of the corpus. Enumerated in the
  test rather than pattern-matched, so a 77th cannot appear unnoticed.

### Unverifiable, and why

`bible_names.json` is 2,622 name → meaning pairs from Hitchcock (1869)
with no verse links, so there is nothing to cross-check it against. The
etymologies are a 19th-century work of reference and the app presents
them as such; the attribution field is present and correct. Nothing here
can be verified from within the repo.

---

### Check 15 — the concordance's verse list was a 500-entry PREFIX, and a scoped search read it as the whole. FIXED v1.6.96

Found while fixing #308. `assets/strongs/concordance.json` describes each
Strong's number twice, and the two are not the same kind of fact:

* **`b`** — occurrences per book. Uncapped, and it sums exactly to `n`
  for all 14,039 entries (there is already a test for that).
* **`r`** — the verse list. The build pipeline stops it at **500 entries,
  in canonical order**, and nothing in the file marks where the cut fell.

**123 entries reach the cap.** For those, `r` is not a sample of the
word — it is a prefix of the canon. H3068 (יהוה, 6,521 occurrences in 36
books) has an `r` that ends at Leviticus 2:14: Genesis 141 verses,
Exodus 341, Leviticus 18, and then nothing. Jeremiah, where the name
actually peaks at 712, is not in the list at all.

#308 fixed what this did to the **chart** — the distribution is now
tallied from `b` whenever `r` is capped, and refused outright where
neither source is a census. It did **not** fix what it does to
**results**, because that cannot be fixed from the reader side:

> A search limit filters `r`. So `l jer` followed by `H3068` returns
> **zero verses**, in a book that contains the divine name 712 times.
> The pane says "no results in this scope" and it is wrong.

The same applies to any of the 123 under any limit that falls outside
the prefix, and to every composed expression over them: `G3588 AND
G2532` intersects two prefixes that both end inside Matthew, so its 335
results are *all* in Matthew and it presents that as an answer about the
New Testament.

**The repair is to regenerate `r` without a cap, from
`assets/originals/`**, which carries the per-verse Strong's tagging the
concordance was built from. Rebuilding three entries from the tagged
corpus and comparing (2026-08-10):

| | corpus occurrences | asset `n` | `b` matches | corpus verses | asset `r` |
|---|---|---|---|---|---|
| G25 | 143 | 143 | yes | 110 | 110, and the verse sets are **identical** |
| H3068 | 6,521 | 6,521 | yes | 5,522 | 500, a strict **prefix** of them |
| G3588 | 19,859 | 19,859 | yes | 6,977 | 500, a strict **prefix** of them |

So the source is sound and the generator is faithful — the cap was a
size decision, not a data limitation, and the uncapped list was
recoverable exactly.

**Repaired 2026-08-10 (v1.6.96).** The size decision was settled by
measuring it rather than deferring it: removing the cap costs **1.75 MB
raw / 307 KB gzipped**, which is what a correct answer to `l jer` +
`H3068` costs. The regenerated asset was proved a pure superset before
shipping — 13,916 entries byte-identical, 123 strict extensions, zero
regressions, and `n` and `b` untouched everywhere — so the fix cannot
have changed any answer that was already right.

The alternative, a compact ordinal or delta re-encoding of `r`, was
rejected as the *less* conservative option: it would have introduced a
canon-ordinal table between the generator and every consumer, and this
repo has already been bitten once by a versification assumption
(check 9).

Uncapping also made #308's truncation apparatus a liability rather than
a safeguard. It inferred "the list was cut" from a list that reached the
cap, so left in place it would have fired on all 123 formerly capped
entries and said *"first 500 verses listed"* about a complete list — the
fix manufacturing its own untruth. The signal is repointed at the one
incompleteness that survives: a **wildcard expansion** stopped at its
300-number limit (`G1✶` matches 1,067 numbers). Measured: exactly 13
prefixes exceed it, all single-digit. The Stats tab's `≥N` prefix is
gone, because nothing it drew from is a sample any more.

Frozen by five tests in `test/data_integrity_test.dart` — including two
that need no named number and would have caught the cap the day it
landed: **every entry must list a verse in every book `b` counts a hit
in** (121 entries fail under the cap), and **no long list length may be
shared by more than 20 entries**, since a cap looks exactly like 123
words that coincidentally appear 500 times.

---

### Check 18 — three Traditional sermon bodies stopped mid-sermon. FIXED v1.6.97

The audit that produced checks 1–17 never looked at `assets/sermons/`.
It holds 289 sermons with a Chinese body and 286 with all three
languages — about 45 MB of preaching that the app presents exactly as it
presents scripture, with no marking to say it is anything less than the
whole.

Measured over all 289 pairs: Han characters in the Traditional body
divided by Han characters in the Simplified it came from. **Median
1.000, maximum 1.0058** — Traditional is a character-for-character
conversion, so the ratio should be 1 and essentially always is. Three
were not:

| id | zh-CN Han | zh-TW Han | ratio | paragraphs kept |
|---|---:|---:|---:|---|
| 100 | 15,433 | 5,453 | **0.353** | 35 of 66 |
| 369 | 12,184 | 5,178 | **0.425** | 38 of 62 |
| 370 | 15,904 | 11,712 | **0.736** | 65 of 87 |

In all three the Traditional text tracks the Simplified for two
paragraphs and then goes its own way — it is not a tail truncation, it
is a condensation running the whole length of the file.

The fourth-lowest ratio is **0.9949**. There is no gradient between the three
and the rest, which is what makes them a defect and not a translation
style.

They do not read as broken. Each stops at a paragraph boundary, mid
exposition, with no marker — sermon 100 ends its Traditional text while
still setting up the parable it is named for. A reader in Traditional
Chinese got a third of a sermon and no way to know it.

**Where the defect is.** Not in the app's ingest. In the source corpus
every `<id>.zh-TW.txt` is byte-identical to `<id>.zh-proofread.txt`, so
the pipeline is en → zh-CN → proofread-and-convert → zh-TW, and for
these three the proofreading step condensed instead of proofread. Sermon
370 is the proof: it is two parts, and part **a** is abridged (8,427
Han against 22,507) while part **b** is intact (30,807 against 30,695).
That is exactly why 370 kept 73% and not a third.

**The conversion was derived, not assumed.** Regenerating with the wrong
OpenCC config would have silently rewritten three files into a variant
system the other 286 do not use. So it was settled by counting what the
shipped Traditional corpus actually contains:

| form | s2t | s2tw / s2twp | corpus uses |
|---|---|---|---:|
| 爲 / 為 | 爲 | 為 | **爲 23,701** vs 為 635 |
| 裏 / 裡 | 裏 | 裡 | **裏 10,262** vs 裡 311 |
| 着 / 著 | 着 | 著 | **着 6,915** vs 著 375 |
| 喫 / 吃 | 喫 | 吃 | **喫 728** vs 吃 11 |

The corpus is raw **`opencc -c s2t`**: byte-exact on 192 of the 286
healthy pairs and agreeing to **99.866%** of characters overall
(2,852,268 of 2,856,103). The 0.134% residue is human proofreading, and
it includes genuine content edits (`'access'` → 「進入的途徑」,
`' precede 它的'` → 「先兆」) that a regeneration must not invent and does
not have to: the reverse direction, `t2s(zh-TW) == zh-CN`, holds for only
100 of 286, so the Traditional files are downstream of the Simplified and
regenerating them forward is the faithful move.

An earlier reading of the same evidence — a positional character diff —
produced a "substitution table" that looked like a second conversion
stage. It was an artefact: one insertion misaligns every character after
it. Re-run through `difflib.SequenceMatcher`, the table dissolved into
the proofreading edits above. **The first conclusion was wrong and was
overturned by measurement before anything was written.**

**Repaired 2026-08-10 by `tools/repair_sermon_corpus.py`** (dry-run by
default). Post-repair the minimum ratio across all 289 is **0.9949** (sermon 372, a
proofread variant) and
the divergence list is **empty**. The index's `titles` were deliberately
left untouched: `titles['zh-TW']` is s2t of `titles['zh-CN']` in 285 of
289 records, all four exceptions are benign proofread touches (「vs.」 set
as 「對比」, 爲 as 為) that still name the right sermon, and the body's H1
agrees with the index in only 153 — so re-deriving titles from bodies
would have churned correct data on worse evidence.

Frozen by a test that fails if any Traditional body falls below **85%**
of its Simplified. The threshold is not a guess: everything healthy is
≥ 0.9949 and everything defective was ≤ 0.736. Proven to fail by
restoring the pre-repair `zh-TW/100.txt`.

---

### Check 19 — ten Chinese sermon bodies are summaries, not translations. MARKED, not repairable

Check 18's rule — "how many more of these are there?" — applied to the
other axis. Han characters in the Simplified body per English word of the
same sermon, over all 289:

**Median 1.403. Ten files sit at 0.097–0.194. Then nothing at all
until 0.933.** A clean empty band, four-fifths of the range wide.

Reading them confirms what the number says. They are not truncated and
not broken; they are competent summary prose, roughly a tenth of the
length, in ordinary paragraphs, ending with a proper closing line.
Sermon 126 is **51,480 bytes** of English against **3,342** of Chinese,
and the Chinese opens 「讓我們先回顧這個診斷性比喻的核心信息」 — a
recap, written *about* the sermon. Their Traditional bodies are faithful
conversions **of the summary**, so both Chinese locales are affected.

The ten: **117, 125, 126, 133, 134, 135, 156, 157, 158, 901.** Nine are
from the topic "The Parables of Jesus" — one failed batch, not ten
independent accidents.

**This one cannot be repaired here, and pretending otherwise would be
the defect.** No full Chinese text exists anywhere in the sources — the
per-part files upstream are the same summaries. Repair means translating
~85,000 words of English, which is generating content, not fixing data,
and is the owner's decision to make.

So the conservative option was taken and is named as such: **the corpus
is marked and the app says what the text is.** `index.json` carries
`"condensed": ["zh-CN","zh-TW"]` on exactly those ten records; the
sermon page shows a hairline notice above the body naming it a summary
and pointing at the language that holds the whole sermon; and **the
notice is prepended to the clipboard copy**, because a summary pasted
into someone's notes without it is indistinguishable from the preaching
and will be quoted as the preaching.

Frozen by a test that re-measures the ratio and requires the marked set
and the measured set to be **identical** — so a future mark that is not
earned fails just as loudly as an unmarked summary. Proven to fail by
removing sermon 126's marker. Eight further tests cover the notice
itself, including that it follows the **UI** locale rather than the body
language, and that it does not promise a full text when every language
is condensed.

*Noted and deliberately not "fixed":* `zh-CN/421.txt` carries a stray
English word (`precede`) inside a Chinese sentence — a proofreading
miss in one word, not a data defect. Latin and transliterated Greek
inside the Chinese bodies is intentional.

---

### Check 20 — four references held the verse next door. FIXED v1.6.98

Every check up to here asks whether a reference **exists**. Check 4
counts them, check 9 compares key sets, check 13 pairs the two 梁家鏗譯本
files, check 15 asks that each appears once. An edition can pass all
four while printing verse 43's second half under 44: nothing is missing,
nothing is duplicated, no count moves. The reader is simply told that a
sentence sits somewhere it does not, and — this is the part that makes
it worse than a gap — the app says it fluently, so it will be believed
and quoted.

That is not hypothetical. It is the shape of the worst finding in this
document: cuvs-plus numbered all of 1 Chronicles 22 one verse low
(check 9's "Fixed in this pass"), and the only reason that one was
catchable by a key set is that the shift ran off the end of the chapter.
A shift of one verse in the *middle* of a chapter leaves the key set
perfect.

**The instrument** is `tools/audit_verse_alignment.py`. It scores every
reference against its own text in other editions and against its two
canonical neighbours, and flags a reference that resembles a neighbour
better than itself. Similarity is the Dice coefficient over token sets —
lowercased words for English, Han **bigrams** for Chinese (the rule
`phrase_match.dart` already uses, lifted one order up), NFD-folded
Greek. Neighbours are stepped through the canonical KJV sequence rather
than by verse number, so a flag can cross a chapter boundary. The 234
placeholder references from check 14 are excluded — comparing 见上节
against anything is comparing nothing.

Three passes, because each covers what the last cannot:

- **Pass A, within-family.** Two files that are *the same text* — KJV
  and KJV+S, the three 和合本, the two 梁家鏗譯本 scripts (compared
  through opencc, which is used here only to make two texts comparable
  and never to generate a shipped word). A disagreement here is decisive
  rather than statistical.
- **Pass B, pool consensus.** Each edition against the median of its
  language pool: 5 English, 5 Chinese, and lxxwh's New Testament against
  `assets/originals`. Catches an edition that is alone in being wrong.
- **Pass C, cross-language, on Strong's numbers.** A number is the same
  token in three languages, so KJV+S, BSB, 和简+, 雅简+ and LXX/WH can be
  asked one question about one reference. Same pivot `Versification`
  uses (v1.6.90). Catches a shift that a whole language pool shares.

| Pass | Compared | Runs of 2+ | Isolated |
|------|---------:|-----------:|---------:|
| A — kjv/kjvs | 30,649 | — | **0** |
| A — cuvs-yhwh/cuvs-plus | 30,983 | — | 2 → **0** |
| A — cuvs-yhwh/cuvs-yhwh-tr | 30,985 | — | **0** |
| A — biblexg-v2/-tr | 7,916 | — | **0** |
| B — English pool | 152,440 | **0** | 22 |
| B — Chinese pool | 108,754 | **0** | 12 → **8** |
| B — Greek NT | 7,910 | **0** | 3 |
| C — cross-language | 130,152 | **0** | 25 |

**399,256 comparisons, and every systematic finding is zero.** No run of
two or more consecutive verses anywhere prefers the same neighbour — the
1 Chronicles 22 class does not exist a second time. Loosening the margin
from 0.12 to 0.05 raises the English flags from 22 to 103 and the
Chinese from 12 to 51 and still produces only two runs in the whole
corpus: KJV/KJV+S Philippians 1:16–17, which is Textus Receptus verse
*order* against the critical text, and biblexg 2 Corinthians 13:12–13,
which is the NA28 merge. Both are textual traditions, not defects.

**The four defects were all isolated flags** — which is what a one-verse
error looks like, so the isolated list is now printed and written to
`build/verse_alignment.json` rather than only counted.

**1. 和简+ 馬可福音 9:43 and 9:45 each stopped at the semicolon.** The
half that follows — 「你缺了肢体进入永生，强如有两只手落到地狱，入那不灭
的火里去。」 — was filed as 9:44. Pass A found it twice over (9:43 scored
0.54 against itself and 0.78 against 9:44) and pass B flagged 9:44 and
9:46 from the other direction. It is one verse: the KJV reads "if thy
hand offend thee, cut it off: it is better for thee to enter into life
maimed, than having two hands to go into hell," and both sibling 和合本
editions hold the whole sentence at 9:43.

What makes this worse than a misplaced clause is *which* references it
filled. 9:44 and 9:46 are two of the sixteen verses the critical text
does not contain — check 14's `OMIT` set, derived independently in
v1.6.90. Every other edition we ship answers them with a note, an
`OMIT`, or nothing. 和简+ was the one edition answering them with
scripture, and `assets/tagged/cuvs-plus/mark.json` carried the same
split, so Word Study, search, KWIC and the concordance all agreed with
it.

**2. 梁家鏗譯本 腓立比書 1:1 was printed as two blocks** — the senders,
then the people addressed — and the second was numbered 2. It is not
verse 2: Philippians names its readers *inside* verse 1, and this
edition's real verse 2, the grace, is in neither file. So both files
answered 腓立比書 1:2 with 「致在腓立比⋯各位監督及執事：」 and never with
「願恩惠平安⋯」. Pass A could not see it — the two files share the defect,
which is exactly what pass B exists for; it flagged 1:2 in both at
self=0.10 against prev=0.46.

Five other letters open with the identical em-dash typography — 羅馬書,
哥林多前書, 歌羅西書, 提摩太前書, 提摩太後書 — and in every one of them the
second block really *is* verse 2. The shape was never the signal, which
is why this needed a measurement and not a reading.

**Both repairs are conservative, and one of them deliberately leaves a
reference emptier than it could be.** `tools/repair_cuvs_plus_mark.py`
rejoins the Mark halves and empties 9:44 and 9:46. It does **not** copy
the note the sibling editions print there: that note is their wording in
their house style (和简+ writes 「（有古卷无此节）」 where 雅简+ writes
`<note: 有古卷无此节>`), and putting one edition's sentence in another's
mouth is the defect this check exists to catch, pointed the other way.
The emptied references fall to `VerseAbsence.blank`, which renders
「本版本此处没有经文」 — true, and all we actually know. Same reasoning in
`tools/repair_biblexg.py` B8: the two blocks are merged into 1:1 and 1:2
is left absent, joining the 40 gaps the edition already has, because the
grace's words are in neither file and writing them in from another
edition would be inventing this translator's wording. Under-coverage,
not a false statement.

**Adjudicated as not defects**, each for a stated reason: the eight
remaining Chinese flags are the publisher's own merges (1 Corinthians
15:51, 2 Corinthians 13:13, 2 Thessalonians 1:11, Luke 9:30 — the merged
verse's words are present, only the second reference is absent, among
the documented 40); 3 John 1:14/15 is a real versification split, the
documented "beyond canon 1"; KJV/KJV+S Philippians 1:16–17 is TR verse
order; and the fifteen note-only Old Testament verses have words and are
left alone on purpose.

One flag was **my instrument's fault and not the data's**: 歷代志上 6:10,
a genealogy where every verse reads 「X生Y」, scored higher against verse
9 than itself because `<note: …>` was stripped and full-width （…）was
not — so one edition's translators' note was compared against the
other's silence. The stripper now takes all four wrappers in every
language, and the flag is gone. Worth recording because the failure mode
is general: **an asymmetric normaliser invents disagreements**, and on a
repetitive text it invents them convincingly.

**What this check cannot see**, stated so nobody reads its zeros as
wider than they are:

- lxxwh's Septuagint half has no same-language witness in the repo. Its
  New Testament is checked against `assets/originals`; its Old Testament
  is not checked here at all.
- A shift shared by *every* edition in a pool and by the Strong's layers
  too. Pass C narrows this to a shift shared across three languages,
  which would be an upstream versification convention rather than our
  error, but it is not zero.
- A verse that is wrong without being a neighbour's verse. Nothing in
  this repo can see that; it needs an external witness, which is still
  the first item under "Not checked yet".

Frozen by `test/verse_alignment_test.dart` — on the asset bytes, because
the suite stayed green through both defects for the project's whole
life. Seven of its nine tests fail against the pre-repair assets.

---

### Check 21 — the Septuagint's own verse numbers were shipping as scripture. FIXED v1.6.100

`assets/lxxwh.json` carried **4,687 markers of the form `(102:12)` in
4,541 verses** — one verse in seven of the Greek Old Testament. They are
not scripture and not a footnote: they are the edition's own
chapter-and-verse for the words that follow, printed because the Greek
Psalter numbers Psalm 103 as 102 and Jeremiah barely agrees with the
Hebrew at all. Rendered raw, they read as text.

**The tagged layer was worse.** The marker was glued onto the first word
of the run, so `(102:12) καθ ` carried καθ's Strong's number and parse:
**4,400 of the 4,672** markers answered a lexicon lookup with the entry
for the word *after* them. Tapping `(5:27)` in 1 Chronicles 6:1 returned
G5207 υἱοί, a masculine plural noun. That is the app stating something
untrue about the text, which is why this went ahead of the rest of the
queue.

Both layers now carry `<vs:REF>`, and the marker has its own run with no
Strong's and no grammar. It is typed as its own `ScriptureSpanKind` for
the same reason `[雅伟]` is — a reference is not a footnote and not a
supplied word, and typing it as either states something the edition does
not say. It renders muted and smaller in the reader and in Browse,
leaves the search index and the reading text entirely, and travels with
the apparatus on paste rather than with the verse.

**The detection was exact rather than heuristic.** An unaccented Greek
text writes its numerals as letters, so no digit in the edition can be
scripture; a strict scan and a loose scan for *any* parenthesised run
both returned the same 4,687. `test/lxx_versification_test.dart` holds
that property down, so the next import cannot quietly need a different
method.

Repaired by `tools/fix_lxx_versification.py`, which is idempotent.

**Two things found on the way, neither repaired here:**

- `assets/tagged/lxxwh/nehemiah.json` is **missing 15 of Nehemiah 10's
  39 verses** (10:3, 4, 5, 11, 12, 15, 16, 18, 19, 20, 21, 22, 24, 25,
  27). This is a pre-existing coverage gap in the tagged import, not a
  loss from this repair, and it is the whole of the 4,687 vs 4,672
  difference between the two layers. Under-coverage, not a false
  statement.
- The same defect class, in two other editions — see check 22.

### Check 22 — two more tagged layers print their source's markup as scripture. FIXED in v1.6.101

Found by asking check 21's question of every edition rather than only
the one that raised it. The **text** layers are all clean: outside
lxxwh's new `<vs:>` tokens, the only angle-bracket token anywhere in
`assets/*.json` is the legitimate `<note: …>`. Two **tagged** layers
were not, and chasing the second one down turned up a far larger defect
that the markup question would never have asked about.

**22a — `assets/tagged/cuvs-yhwh/*.json`, the leaked alignment codes.**
The importer's `TAG_RE` recognised only the well-formed shape
`<W([HG])(\d+)(x?)>`. The MySword module it reads is hand-edited, and
**133 of its 533,914 codes are damaged** — a dropped bracket, a doubled
`W`, a character typed into the middle of the code. Unrecognised, they
were treated as TEXT, which did two things: it drew them on screen
(「他若`<H518>`行恶」) and, because a code that is text does not split the
run, it left 他若 carrying **H4672 — the number of a word further on**.
The stray-character count is **329 across 169 verses in 29 books**, not
the 133/126/27 first reported here; that first figure came from a
paired-token regex and could not see a fragment like `<WH3808怜恤` or
`以色列>人` whose partner bracket was gone.

Repaired by widening the tokenizer to recognise every damaged shape, and
then deciding, per shape, whether the *number* survives:

- **Kept** where pure normalisation recovers it — case, `X`→`x`, a
  doubled or missing `W`, bare digits taking their language from the
  testament.
- **Dropped, deliberately**, where the digits are in doubt: `3WH808`,
  `WH85x3`, `WH448x0`, `WG358x8`, and any prefix that is not W/H/G
  (`V3808`, `WJ3808`, `MWH8802`). The run still prints; it simply
  answers nothing. **Under-attribution is recoverable, a wrong Strong's
  is not.**
- Five codes with a Chinese character inside them were decided one at a
  time against the printed edition and written into a documented
  `DAMAGED` table, because each is a different question: in `<你们WH935>`
   你们 is scripture (Nu 15:18 「我所领你们进去的那地」), in `<WH的8687>`
  the 的 is not (1Ch 21:17). **Two characters are dropped on purpose**,
  both checked against the printed text, both absent from it.
- The `s` suffix (`<WH1288s>`) was not guessed. A corpus-witness script
  asked how the same Chinese word is tagged everywhere the tags are well
  formed — 厚待/H3190, H3318 出来, H7925 清早, H2421 救 — and it reads as
  a plain lexical tag.

Verified: stray angle characters **329 → 0**, Latin letters **→ 0**,
agreement with the printed edition **27,448 → 27,592 verses (88.71%)**,
**2** Chinese characters dropped and both accounted for above, the two
Chinese lexicons regenerated **byte-identical**.

**22b — `assets/tagged/bsb/*.json`, the markup, and then the numbers.**
The markup half was as described: **726 raw HTML tags across 145 verses
in 8 books**, mostly the verse-number anchor
`<span class=|reftext|><a href=|#|><b>1</b></a></span>`, plus **25,357
runs that are not words at all** — 20,508 `. . .` and 4,849 `vvv`, the
tables' two ways of writing "this original is folded into a neighbouring
English phrase". **24,586 of those carried a Strong's number**, so a tap
on a spaced ellipsis answered with a lexicon entry for a word that was
never printed.

Fixing that meant re-reading the tables, and the re-read is what exposed
the real defect. **311,267 of the BSB tagged layer's 386,063 runs —
80.6% — carried a Strong's number that was the first digit of the right
one.** H7225 בְּרֵאשִׁית "in the beginning" shipped as **H7**; H6870
Zeruiah as **H6**; H8352 Seth as **H8**. The cause is one helper doing
two jobs: `cell()` groups thousands, correctly, because the tables store
a count like 74,600 as a number in some rows and as text in others and
the Bible prints the comma. Fed the Strong's column it turned 7225 into
`"7,225"`, and `re.match(r'\d+', …)` stopped at the comma. The same
helper fed the column that orders the original words, where the grouped
string failed `int()` and fell back to `0` — so **970,285 rows shared
one sort key**, and the walk that decides which untranslated original
attaches to which English word was running on nothing. Both columns now
go through a `code()` reader that never groups; the sort key is a float,
because 72 rows carry a fractional one to place a split word between two
whole-numbered originals.

**Why nothing caught it, which is the part worth keeping.** A truncated
Strong's number is still a real Strong's number. All **432,859** of them
resolved against `assets/strongs/` before the fix as well as after — H7
has an entry, and it is a plausible-looking one. Every internal test
that could be written about the shape of the data passed. What catches
it is the **second witness**: `assets/tagged/cuvs-yhwh/` is an
independent alignment of the same originals, made by different people
from the other side of the language, and the two agreed on **13.36%** of
each verse's numbers. They now agree on **92.79%** across the 30,746
verses both cover, and that ratio is the regression test. The residue is
genuine alignment difference — the two editions disagree about which
word an article or a particle rides on.

Verified: **31,086 of 31,086** verses tagged; **30,838** reconstruct the
printed text of `assets/bsb.json` exactly (was 8,269), the remaining 248
bounded by test; **0** runs carry markup or a placeholder; **0** runs
lost or gained a number, so the repair only ever corrected a value; the
distinct lexicon entries the layer can reach went from **1,861 to
13,115**.

**Left alone, named as such.** In cuvs-yhwh a run's primary number also
appears in its own implied list in **858 of 367,650** runs (844 before
this pass). That is pre-existing, it is a duplicate rather than a false
statement, and untangling it is a separate question about what the
implied list means.

---

## 23. The other five tagged layers, and the Septuagint's own two halves

Check 22 found a corruption in `assets/tagged/bsb/` that every internal
test had passed, and it found it by asking a second layer to agree. The
obvious next question is whether the same class of defect is sitting in
any of the other layers. It is not. The less obvious question — whether
the Septuagint, which the previous edition of this document listed under
"Not checked yet" because it has no same-language witness for the Old
Testament, really has none — turned out to be answerable, and the answer
was 12,099 wrong Strong's numbers.

### The negative result first, because it is a result

Per-verse Jaccard over the Strong's sets of every pair of tagged layers,
across the verses both cover:

| | cuvs-yhwh | kjvs | cuvs-plus | nsn-plus |
|---|---|---|---|---|
| **bsb** | 92.79% | 76.86% | 79.61% | 72.61% |
| **cuvs-yhwh** | — | 80.09% | 84.43% | 71.44% |
| **kjvs** | | — | 92.48% | 70.58% |
| **cuvs-plus** | | | — | 70.62% |

Read alone, the 70s look alarming. They are not, and the measure that
settles it is **containment** rather than overlap — of the numbers layer
A gives a verse, how many does layer B also give? Across all ten pairs,
in both directions, the answer never falls below **87.36%**, and for the
smaller layer against a larger one it runs **94–98%**. nsn-plus sits at
**97.82%** inside bsb while bsb sits at only **73.81%** inside nsn-plus.

That asymmetry is the whole explanation. The layers are not disagreeing
about what a word is; the smaller ones are **saying less**. bsb and
cuvs-yhwh tag 369,042 and 369,529 numbers per verse summed; kjvs 313,477
and cuvs-plus 327,661, both of which leave untranslated Hebrew function
words alone; nsn-plus 282,053, roughly two words in three. The two pairs
that score above 92% are exactly the two pairs with matching coverage.

A corruption of the BSB kind cannot hide behind that. While bsb's numbers
were truncated to their first digit its containment collapsed in *both*
directions, because a layer that says H7 where another says H7225 is not
saying less, it is saying something else. **No layer here does that.**
0 defects found, 5 layers checked, 10 pairs measured.

### The Septuagint half of `assets/tagged/lxxwh/`

The pivot this document said did not exist was inside the file. `lxxwh`
carries two alignments in one asset — the Greek Old Testament and the
Westcott-Hort New Testament — produced by two different processes. They
are the **same language**, so a word common to both is tagged twice, and
each half witnesses the other.

Asked to agree, they did not, on **4.23%** of the shared vocabulary. The
Septuagint half's numbers had been assigned by a lookup blind to accent,
breathing and vowel length:

| form | means | should be | was tagged |
|---|---|---|---|
| γῆ | earth | G1093 | G1065 γέ "indeed" |
| μή | not | G3361 | G3165 μέ "me" |
| ὡς | as | G5613 | G3739 ὅς "who" |
| εἷς | one | G1520 | G1519 εἰς "into" |
| ὧδε | here | G5602 | G3592 ὅδε "this" |
| νῶτος | the back | G3577 | G3558 νότος "the south" |

Fold η to ε and ω to ο, drop the breathings, and each wrong entry is what
is left. The same lookup took the adjective for the adverb (καλός for
καλῶς) and the verb for the noun (οἰκέω for οἰκουμένη).

**A reader tapping 「γην」 in Genesis 1:1 — the earth, in the verse that
names it — was told the word means "indeed, at least".** Nothing looked
broken. G1065 is a real number with a real entry, which is check 22's
lesson arriving a second time: *a plausible wrong value is invisible from
inside the data.*

### The rule, and what it refused

`tools/fix_lxx_strongs.py`. A number moves only when the New Testament
half tags the same form (accents stripped, final sigma folded, **vowel
length kept**) with one number and no other, at least 3 times, **and**
`assets/originals/` — MorphGNT, made by other people from another source
— names that same number, **and** the run's own part of speech agrees
with the witness's. Two independent witnesses, or nothing moves.

A second pass fills runs that carry no number at all, on the edition's
own unanimous testimony: `ειπεν` was tagged G3004 in 612 places and left
empty in 2,550 others, same word, same edition, same parse. Pass 1
finishes and the corpus is **re-surveyed** before pass 2 begins, which is
load-bearing twice: correcting νωτοι's three runs lets the fourth fill
with G3577 rather than propagating G3558, and μη only becomes unanimous
once its 2,263 Septuagint runs stop reading G3165.

What it refused is the part worth keeping:

- **234 runs held** where both witnesses agree and the answer is still
  wrong. Leviticus's ἁφή "a plague-spot" is a noun, G860, spelled exactly
  like ἀφῇ from ἀφίημι, which the New Testament tags G863 unanimously.
  The run's own parse is what saves it. Every one of the 234 is a
  word-class disagreement, not a tagset naming difference.
- **ἰδού keeps G2400 across 1,018 runs.** The New Testament half
  lemmatises it under ὁράω G3708 and does so unanimously — but
  `assets/originals` does not confirm that, so the second witness is
  missing and the Septuagint's own reading stands.
- **εὐθύς keeps G2117**, a legitimate entry in its own right; the New
  Testament's preference for εὐθέως G2112 is house style, not a
  correction.
- **308 runs refused on parse** in pass 2. An unaccented text loses the
  difference between ἐρεῖς "you will say" and ἔρεις "strifes", so a form
  can look unanimous only because one of its two words is never tagged.
- **41,032 runs left empty.** Some 41,000 are words the New Testament
  never uses — Σαλωμων, Μωαβ and Ιωαβ are spelled as the Septuagint
  spells them, not as Matthew does — so no Strong's number exists to give
  and inventing one would be a guess. Under-attribution is recoverable; a
  wrong number is not, because it reads as a fact about the text.

Verified: **12,099** runs corrected and **8,295** filled, over 479,989
Old Testament runs; **0** New Testament runs touched, since that half is
the witness and is already checked against `assets/originals`; **0**
numbers cleared, so no run stopped answering; verse text, run counts,
morphology and implied lists **byte-identical** before and after; all
4,672 `<vs:…>` markers still carry no number (check 21). Agreement with
the unanimous half of the witness went from **95.77% to 99.36%**, and the
share of Old Testament runs that answer nothing from **10.34% to 8.61%**.
The tool is idempotent — a second run writes the same bytes — and
`test/lxx_tagged_layer_test.dart` holds all of it down; it fails on the
pre-repair asset in four of its seven tests.

`assets/strongs/concordance.json` is built from `assets/originals/`, not
from the tagged layers, so no concordance count moves.

---

## 24. The first outside witness: does a code describe the word it sits on

Every check up to here has been **internal**. Check 1 proved a Strong's
number resolves to a lexicon entry. Check 2b proved a morphology code
decodes to a parse. Check 3b proved the concordance agrees with the text
it indexes. Not one of them could catch a row that is **well-formed and
wrong** — a real number and a real code sitting on a word they do not
describe. Nothing inside the file can tell you that. It needs a source
outside the app, and until now this corpus had never been shown one.

`assets/originals` is the largest thing the app ships and the most
load-bearing: 438,821 words, each carrying a Strong's number the Word
List and the concordance are built from and a morphology code the
analysis pane prints as a parse. It is also the column set nobody had
ever checked for **truth**.

### The witnesses

Both were already in the repo, cached beside the merge tool that built
this corpus, and both are separately licensed and credited:

- **MorphGNT / SBLGNT** (CC BY-SA 3.0), `tools/src/gnt/*-morphgnt.txt`.
  Carries a morph code and a lemma, and **no Strong's numbers at all**.
  Its lemma is therefore a genuinely independent opinion about what word
  this is.
- **Open Scriptures Hebrew Bible** (CC BY 4.0), `tools/src/hb/*.xml`.
  Carries morph and Strong's directly in the `lemma` attribute.

The instrument is `tools/audit_originals_witness.py`, and it deliberately
**does not reuse** `merge_morphology.load_hb` — that function is half of
what is being audited, and a witness that shares the accused's parsing
cannot see the accused's parsing errors.

### What it found

| | Examined | Disagreements |
|---|---:|---:|
| Greek morphology vs MorphGNT | 137,062 of 138,013 words (99.31%) | **0** |
| Hebrew morphology vs OSHB | 299,568 of 300,808 words (99.59%) | **0** |
| Hebrew Strong's vs OSHB | 299,567 words | **0** |
| Greek Strong's | 137,062 words | **15 wrong** |

The morphology column is **exact**. Not "close" — 436,630 words compared
against two independent editions and zero disagreements. That result is
worth stating plainly because it is what makes the fourth row findable:
a morph code that reproduces MorphGNT exactly is **independent of the
Strong's number sitting next to it**, so a row where the two contradict
each other is a row where one of them is wrong.

### The 15 Greek words, and why each one is a fault

All are repaired by `tools/repair_originals_strongs.py`, which is
idempotent and carries the argument for each change inline. Several
**reverse the meaning** of a well-known verse:

- **Luke 4:17, Luke 23:53, Romans 9:26** — οὗ "where" tagged G3756 οὐ
  "not". A reader tapping the word in "the place **where** it was
  written" was told the passage says "not". Luke 23:53 holds both words
  in one clause, οὗ οὐκ ἦν, and tagged them identically.
- **Acts 5:28** — and the same confusion pointing the other way, Οὐ
  "did we **not** charge you" tagged G3757 "where", which is why the
  three above are a fault and not a house convention.
- **2 Corinthians 11:1** — ἀνείχεσθέ "**bear with** me" tagged G337
  ἀναιρέω, "**kill**". The same verse tags ἀνέχεσθε correctly two words
  later.
- **Acts 8:2** — Στέφανον, in the verse that buries him, tagged G4735
  "a **crown**" instead of G4736 **Stephen**. Acts spells the name six
  times and got the other five right.
- **Matthew 5:32, Luke 16:18** — ἀπολελυμένην "a **divorced** woman"
  tagged G620 ἀπολείπω "left behind". Both verses tag ἀπολύων correctly
  a few words earlier, so one sentence carried two numbers for one verb.
- **James 1:25** — ποιήσει tagged G4160, a **verb**, where the row's own
  morph column reads `N-----DSF-`, a feminine dative **noun**. G4162
  ποίησις occurs once in the New Testament and this is it.
- **John 6:23** — ἀλλὰ "**but**" tagged G243 ἄλλος "**other**". The same
  form with the same parse is G235 in 389 other places.
- **John 16:15** — ἐμοῦ "what is **mine**" tagged G1473 ἐγώ "**I**".
- **Acts 18:23** — στηρίζων tagged G1991 ἐπιστηρίζω, the compound the
  Received Text reads here and our edition does not.
- **Mark 1:5** — Ἰουδαία in "all the **Judean** country" tagged G2449
  the province instead of G2453 the adjective. The corpus follows
  exactly this rule everywhere else: morph `A` → G2453, morph `N` → G2449.
- **Galatians 6:15, Titus 1:6** — the weakest pair, and worth naming as
  such. τί/τίς are spelled identically for the interrogative G5101 and
  the enclitic indefinite G5100, and an enclitic takes an acute when
  another enclitic follows — exactly the environment in both verses. So
  the accent does not decide and the corpus is mute. This rests on
  MorphGNT's lemma plus sense: "neither is circumcision **what?**" and
  "if **who** is blameless" are not Greek.

### What was deliberately NOT changed

A check that only reports what it changed is not reportable.

- **John 6:17** ἤρχοντο — MorphGNT lemmatises ἄρχω; the verse is "they
  were **going** across the sea". Ours is right and the witness is wrong.
- **1 Timothy 5:4** πρῶτον, adverbial, where Strong's has G4412 — but
  this corpus uses G4412 **nowhere**, so changing one of 61 occurrences
  would create an inconsistency rather than remove one.
- **Ephesians 2:13** οἵ — we accent a relative pronoun, SBLGNT an
  article. Both nominative plural masculine; only the category label
  differs. Two editors disagreeing, not our error.
- **Luke 1:38, 1:48, Acts 2:18** — the feminine δούλη under G1401
  δοῦλος. The corpus does this every time and never uses G1399, so it is
  this tagging's convention.
- **Romans 8:24** τις — the one surviving hit of the self-contradiction
  check, and a **base-text** question rather than a tagging one. SBLGNT
  prints ⸀τίς at that variant point and lemmatises it as the
  interrogative, so both our columns agree with the witness and with
  each other; only our surface accent follows a different edition. It is
  not settled by editing a tag, so it is recorded and left.
- **3,779 places (2.76%)** where MorphGNT's lemma differs from the lemma
  of our Strong's number. These are overwhelmingly Strong's 1890
  orthography against a modern critical text — ἔπω/λέγω, εἴδω/ὁράω,
  Δαβίδ/Δαυίδ, Καπερναούμ/Καφαρναούμ. Lexicographic conventions;
  changing them would be inventing a third one.
- **951 Greek and 1,240 Hebrew words (0.69% / 0.41%) that do not align
  at all**, and so were never examined. Our base text and the WLC differ
  in places — 1 Chronicles 9:4 carries an unpointed בנימן the WLC does
  not have. This is reported because "0 disagreements" means nothing
  without knowing how much went unlooked-at.

### Two instrument errors, recorded because they nearly became findings

- Comparing Hebrew **by position** invented **883 Strong's and 1,082
  morph disagreements out of nothing**. The editions differ on Ketiv/Qere
  and maqqef, so 5,471 verses have different word counts and every word
  after the first difference compares against its neighbour. Re-run with
  `difflib` over consonant-only forms: 1,965 findings → **0**. An earlier
  draft of this section reported a disagreement at 1 Chronicles 9:4 that
  does not exist.
- The Hebrew POS extractor took the **last** `/`-segment, which is the
  pronominal suffix rather than the head, and treated legitimate verb-stem
  variation (Vq/VN/Vp/Vh/VH/Vt) as outliers: **586 false positives**.

Both had the same signature — findings clustered inside single verses,
and a plausible-looking count. It is the failure mode named at the top of
this document, and it is why every number here carries its denominator.

### A second finding, from rebuilding the indexes rather than from the audit

Repairing 15 Greek words obliges a rebuild of the two derived indexes, or
the Word List and the concordance would disagree with the text they
index. The rebuild changed **749** entries in `assets/forms/` — far more
than 15 words can explain.

Rebuilding `assets/forms/` from **HEAD's own, unrepaired** originals
changed **729** entries, which settles it: the shipped index was already
stale, and had been since before this run. The difference is always the
same and always in one direction — **1,243 form entries carried an empty
morphology code where the corpus has one, and 0 lost a code**. The index
was built before check 2a filled 2,203 words' missing morphology and was
never rebuilt afterwards, so the Word List has been showing those 1,243
word-forms with **no parse at all** while the parse sat in
`assets/originals` the whole time.

This is check 3b — "does the concordance agree with the text it indexes"
— asked of the *other* derived index, where it had never been asked. It
is now `test/originals_witness_test.dart`, which fails against the
shipped index and passes against the rebuilt one.

The general lesson is the one this document keeps relearning: **a derived
asset is a claim about a source, and nothing checks it unless something
is written to check it.** Both indexes are now covered.

### Frozen

`test/originals_witness_test.dart` holds the 15 words on the asset bytes
and re-implements the two source-free checks in Dart. It fails on the
pre-repair data in all three tests, and the Dart implementation
independently reproduces the Python instrument's exact findings
(`ephesians 2:13 οἵ`, `τις|RI----NSM-`), which is the only reason to
trust a transcription. `assets/strongs/concordance.json` and
`assets/forms/` were both rebuilt: G4162 goes 0 → 1 use, G1991 4 → 3,
G4736 6 → 7, and the token total stays 438,821 because only `s` changed.

---

## 25. The references the app writes itself

Checks 1–24 all asked about the corpus the app *reads*: the verse text,
the tagged layers, the lexicon, the concordance. None of them asked
about the references the app *writes* — the strings in its own curated
reference data. The synopsis tables, the section headings, the family
tree, the timeline, the archaeology gallery, the king list all print
scripture references a reader taps. A reference naming a verse that does
not exist is the same class of defect as a wrong parsing code: it states
something untrue about the text, and the reader cannot check it.

`tools/audit_reference_assets.py` is the sweep. Canon frame is KJV
versification, the frame check 4 used.

| asset | references | broken |
|-------|-----------:|-------:|
| section_titles.json | 4,329 | 0 |
| family_tree.json | 665 | 0 |
| ot_synopsis.json | 313 | **14** |
| bible_evidence.json | 225 | 0 |
| gospel_synopsis.json | 174 | 0 |
| bible_timeline.json | 123 | 0 |
| hebrew_kings.json | 104 | 0 |
| **total** | **5,933** | **14** |

Six of the seven assets are clean, and that is a result worth recording:
4,329 hand-written section headings anchor to a verse that exists.

### 25a. Fourteen references, and why twelve of them looked healthy

Every one of the fourteen is in `assets/ot_synopsis.json`, imported from
Eagle's View on 2026-08-07. The importer read a reference with
`(\d+):(\d+)(?:-(\d+))?`, which **cannot express a range that crosses a
chapter boundary**. The source has sixteen such ranges; twelve are in
groups we keep, and each was silently truncated:

| source | imported as | what happened |
|--------|-------------|---------------|
| `2Ki 23:35-24:7` | 2 Kings 23:35-24 | end verse precedes start |
| `2Ch 29:1-31:21` | 2 Chronicles 29:1-31 | Hezekiah's three chapters → 31 verses |
| `1Ch 21:1-22:1` | 1 Chronicles 21:1-22 | David's census → 22 verses |

Seven of the twelve named a verse that cannot exist and are the visible
half. **The other five resolve and are simply wrong** — a plausible
range that quietly claims a fraction of the passage. Those five are the
reason the count is fourteen and not seven: a check that only asks "does
it resolve" finds seven, and a reader would never learn that the other
five had lost four fifths of their text.

The remaining two are upstream errors, corrected here rather than
copied, each with its reason recorded in the asset's own `corrections`
block so a reader of the data can see where we differ from the source:

- **Group 30** reads `2Ch 1:32-33`. 2 Chronicles 1 ends at verse 17, so
  the reference cannot be read at all. 1 Chronicles 1:32-33 is the
  passage meant: it names Keturah, Zimran, Jokshan, Medan, Midian,
  Ishbak and Shuah, which is the group's other passage (Genesis 25:1-4)
  almost word for word. Checked against `assets/kjv.json`, not assumed.
- **Group 207** reads `Psa 18:0-50`. Verse 0 is the superscription,
  which the Hebrew numbers as verse 1 and which every edition we ship
  folds into the heading. Starting at 1 under-claims by a line rather
  than printing a verse number no edition has.

The schema now carries `endChapter`, emitted only when a range actually
crosses a chapter, so a reader of the JSON can see at a glance which
twelve passages span. `assets/ot_synopsis.json` is schema 2.

The same blindness was in the app's own parser: `parseReference` matched
the cross-chapter shape and then **discarded the end**, so
`John 18:28-19:16` — the thirty-verse trial before Pilate — was indexed
as the single verse John 18:28. Two gospel entries were affected.
`BibleReference` now carries `endChapter`/`endVerse`; `chapter`,
`verseStart` and `verseEnd` are unchanged, so navigation lands exactly
where it did and only callers that need the extent read the new fields.

### 25b. Nobody could have seen any of it

Measuring the data was the smaller half. The 139 groups had been
shipping for five days and **not one of them was reachable**. The reader
menu gated the Synopsis item on `isGospel`, so no Old Testament book
ever offered it. `hasSynopsis`, written for exactly this, had no
callers. The menu is built synchronously, which is why the gate is now
`hasSynopsisSync` with a 27 KB preload when the reader mounts.

This is the more useful finding of the two. A defect in data that
nothing displays is invisible to every test that exercises the app, and
the suite stayed green through all of it.

### 25c. A map keyed by book is a silent de-duplicator

The service turned each group's passages into a `Map` keyed by lowercase
book name. Any group naming the same book twice kept only the last one.
**35 of 139 groups did**, and **37 of 313 passages were dropped** —
"Benjamin's Descendants" is 1 Chronicles 8:1-9:1 *and* 9:34-44, and only
the second survived. Passages are now an ordered list, which is also
what lets the row render an OT group at all: it built its chips by
looking up `['Matthew','Mark','Luke','John']`, so an OT group yielded
zero chips.

This is the same shape as the lesson in
`feedback_capped_ordered_data.md`: a container that silently discards
what does not fit is a `WHERE` clause nobody wrote.

### The tests

`test/data_integrity_test.dart` walks all 5,933 references on every
commit. It deliberately does **not** trust `parseReference` to judge a
range: the parser clamps an end that precedes its start, because a
reader still has to be sent somewhere, and an audit that inherited that
clamp would have reported `2Ki 23:35-24` as healthy — which is precisely
how the defect survived its first pass. The test checks the raw shape
first, then resolves.

Verified by perturbation, not by assumption: injecting a too-large verse,
a backwards range and a nonexistent chapter makes the test fail with all
three named.

### Two references that name no book we ship

Reported separately because neither states anything untrue:
`bible_evidence.json` cites `Ecclesiasticus (Sirach) 39:1` for the Cairo
Genizah, which is genuinely what was found there and is outside the
canon of every edition we ship, and `Various NT references` for Strabo's
Geography, which is prose rather than a citation.

---

## 26. Characters that render perfectly and cannot be read

This is the first comparison of this repository's **Chinese scripture**
against a witness obtained outside it, and it is the check the "Not
checked yet" list has carried since the beginning: *a verse that is wrong
and well-formed and agrees with our own second copy.*

The defect class is the dangerous one. A wrong character throws nothing,
breaks no key and renders perfectly — CanvasKit only drops a glyph it has
no font for, and every character repaired here is an ordinary CJK Unified
Ideograph. Check 10 asked which Unicode **blocks** the shipped text uses
and found 129 offenders; it could never have found these, because they
sit in the same block as the words around them. Nothing is missing,
nothing is malformed, and the sentence is simply not the sentence.

### The six classes, and why each one cannot be read

| Reading | Should be | Sites | Where |
|---|---|---:|---|
| 丶 U+4E36 | 、 U+3001 | 150 | cuvs-yhwh 53, -tr 53, tagged/cuvs-yhwh 44 |
| 恉 zhǐ "purport" | 腮 sāi "jaw" | 8 | all three plain files, tagged/cuvs-plus |
| 逿 dàng | 趟 tāng "to wade" | 36 | all three plain files, tagged/cuvs-plus |
| 承巡菇业 / 承巡产业 | 承受产业 | 5 | 耶利米書 12:14 |
| 扔菏丑恶 | 凶淫丑恶 | 4 | 士師記 20:6 |
| 毫无暇疵 | 毫无瑕疵 | 3 | 撒母耳記下 14:25 |

**丶 is the one that matters most**, at 150 of the 206 sites. U+4E36 is
the *dot stroke* — the character used to NAME a piece of a glyph, as one
would name a radical. It is not punctuation, it cannot occur in running
prose, and it is visually identical to the enumeration comma 、 that
belongs at every one of these sites. 詩篇 146:6 shipped as
`雅伟造天丶地丶海`.

恉 and 逿 are ordinary words in the wrong place. 逿 differs from 趟 only
in the radical — 辶 against 走 beneath a shared 尚 — and every site is
someone wading through water, which 逿 cannot mean. 士師記 15:16 is the
neatest case: it uses 恉 and 腮 in the same sentence, so the verse
witnesses against itself.

暇 is "leisure"; 毫无暇疵 is not a word, and 毫无瑕疵 "without blemish" is
the idiom Absalom's description ends on.

### Four witnesses, none of them sufficient alone

- `assets/cuvs-plus.json` and `assets/tagged/cuvs-plus/` — 和合本+Strong's,
  the same base text imported separately. Clean of 丶.
- `assets/tagged/cuvs-yhwh/` — **our own tagged layer**, which reads 腮,
  趟 and 凶淫 correctly at every site where the plain layer does not.
- the yahwehdehua export (`~/Documents/New project/yahwehdehua_bible`),
  whose `manifest.json` records site-owner authorization, and which the
  LEB repair (check 24) already trusted.

The reason all four were needed is that each is corrupt where another is
clean. cuvs-plus carries 恉 and 逿. The tagged layer carries 丶. **The
external witness carries 44 丶 of its own across 25 verses**, and reads
毫无暇疵 and 承巡产业 exactly as we did. So no single comparison would
have found all six classes, and a majority vote would have entrenched
three of them.

Jeremiah 12:14 is the sharpest illustration: the plain layer read
承巡**菇**业 and the tagged layer read 承巡**产**业 — the same verse,
corrupt to *different depths* in two copies that ship together. Neither
is 承受产业, and neither could be derived from the other.

### The rule, stated so a later reader can disagree with it

Repair only where our reading is **semantically impossible in context**
AND a witness reads a sensible alternative. A witness that is corrupt at
the same site **abstains**; it does not veto. That asymmetry is
deliberate and is the load-bearing decision in `tools/repair_cuvs_defects.py`:
the witness is not voting on whether the site is broken — the character
settles that by being unreadable — it is supplying the reading.

Every substitution is gated at the **site**, not merely on a witness
existing: the witness must read the replacement between the same two Han
words, with the divine name normalised (cuvs-plus prints 耶和华 where this
edition prints 雅伟) and punctuation ignored (the editions punctuate
differently). A failed gate skips that site and reports it; it never
falls back to applying the edit. The traditional file is never matched
against a simplified witness directly — it is chained off its own
simplified sibling, with which it is aligned character for character at
all 42 defect records, and every traditional character introduced must
already be attested elsewhere in the traditional file. That check is what
puts 兇 and 產 into 兇淫醜惡 and 承受產業 rather than the simplified 凶 and
产, which the file contains **zero** of.

### What was deliberately NOT changed

383 verses still disagree with the external witness, and they are left
alone. The largest classes are 阿/啊 ×43 (two spellings of the same
interjection), the pronouns 他/她/它 ×44 (an editorial choice about
gender and animacy, not a reading), 繸/䍁 ×7, 做/作 ×4, 吗/么 ×3.
Elsewhere the two texts differ in length (194 verses), almost always
because this edition carries an inline note the witness does not.

None of these is repaired, because *"a witness spells it differently"* is
a weaker claim than *"this cannot be read"* — and only the second one
licenses editing scripture. 辊/滚, 幌/晃, 锨/杴 and the proper name
犰多/朵多 were examined individually and left for the same reason.

### The measurement, and an instrument error inside it

Agreement between `assets/cuvs-yhwh.json` and the external witness on the
Han-character stream: **30,710 of 31,102 verses (98.7396%) before the
repair, 30,719 (98.7686%) after.**

The first time this was measured it appeared to go **down**, from 30,706
to 30,696. That was the measuring script, not the data: 丶 lives in the
Han block, so a reduction that keeps "all Han characters" keeps 丶 too.
Removing ours while the witness kept its own 44 shifted the two streams
by one character and turned 24 verses into total mismatches. Recorded
here because it is the third instrument error in this document
(check 24 has two) and because it very nearly became a finding — the
number was real, reproducible, and completely wrong.

A fourth, from the same session and also not a finding: a character
census reported 203 Private Use Area characters (`U+E000`) in
`assets/cuvs-yhwh.json`. Direct inspection found **zero** — none in the
raw bytes, none across any field of any record, and an isolated re-run
found none. An artifact of the sweep, not of the file.

### Verse ids: 562 collisions nobody would have seen

Separately, every 歷代志上/下 record in `assets/cuvs-yhwh-tr.json` carried
id `000CCCVVV` — 1,764 records colliding with 創世記 and with each other,
562 collisions in all. The simplified file has 013 and 014 at the same
two positions in the same book order.

This was **latent, not live**, and the distinction is worth stating
plainly rather than quietly fixing: `Verse.fromJson` never reads the
asset's `id` field, and `Verse.id` is computed from the book name and
verse label. So nothing a reader has ever seen was wrong. It is repaired
because the field is the join key any future cross-edition work would
reach for, and a silently duplicated key is exactly the kind of defect
that surfaces only once something depends on it — which is how check 25c
happened.

The repair takes each ordinal from the sibling file at the same position
in the same book order, and refuses any id the simplified file does not
actually hold.

### Frozen

`test/cuvs_yhwh_integrity_test.dart` asserts that none of the six
unreadable readings appears in any of the three plain editions, and that
every id is a well-formed, unique BBBCCCVVV.
`test/cuvs_yhwh_tagged_layer_test.dart` does the same across both tagged
layers — searching the reconstructed verse rather than the individual
runs, because a two-character defect can straddle a word boundary — and
pins the five repaired verses to the readings the witnesses gave.

`tools/repair_cuvs_defects.py` verifies by default and applies with
`--write`; it is idempotent and exits 0 when there is nothing left to
repair. It preserves each file's on-disk formatting, which is not a
detail: cuvs-yhwh is indent-2 and cuvs-plus is a single compact line, and
writing either one the other way buries a 69-character repair in a
217,000-line diff.

---

## Check 27 — the English editions against an external witness

This was item 0 of "Next, in order", and that entry said the obstacle
was the witness, not the method: *"nothing outside this repository has
yet been found that holds BSB or KJV under terms we can use."*

That was wrong, and it had never been tested. Four public-domain texts
answered on the first attempt:

  * `bereanbible.com/bsb.txt` — the BSB, dedicated to the public domain
    by its publisher, in a two-column reference/text file
  * `api.getbible.net/v2/kjv` — the CrossWire/Blayney 1769 line
  * `openbible.com`'s Pure Cambridge Edition, which brackets the words
    the translators supplied
  * scrollmapper's `bible_databases` export

A false blocker in a document is worse than a blank, because it stops
the next reader from trying. The cost of disproving it was one command.

### The witnesses check each other first

The three KJV texts agree with each other in **30,058 of 31,102**
verses. Where they do not, they are not used: every repair below is
gated on all three reading the same thing. This is check 26's lesson
applied in advance — there the external witness carried 44 of the same
丶 we did, and a majority vote would have entrenched three defects. A
witness that is corrupt at the same site must abstain, and the cheapest
way to make it abstain is to require unanimity.

Comparison is on a reduced stream: NFKC, curly quotes folded to
straight, everything outside `[a-z0-9 ]` dropped, whitespace collapsed.
So `Beth–aven` and `Bethaven`, `LORD` and `Lord`, `[is]` and `is` all
compare equal, and the residue is words rather than typography. Book
names needed aliasing in both directions (Psalm↔Psalms, Song of
Songs↔Song of Solomon, I/II/III↔1/2/3, Revelation of John↔Revelation);
before that was done scrollmapper appeared to be missing 6,532 verses,
which is what a naming mismatch looks like when you do not check it.

### BSB: clean, and the count is the result

**31,086 verses, 100.0000% agreement.** No formatting artifacts. The 16
references present upstream and absent here are empty rows upstream —
the verses the BSB's textual basis omits (Matthew 17:21, 18:11, 23:14,
Mark 7:16 and the rest). They are absent, not wrong, and whether the
reader should be *told* they are absent is a product question, not a
data one. It is recorded here and owned by nobody yet.

A clean result on 31,086 verses is not a wasted check. It is the control
that makes the KJV finding legible: the same instrument, the same
reduction, the same witness terms, and one file came back at 100% and
the other did not.

### `assets/kjv.json` is not the King James Version

851 verses depart from all three witnesses. The first question was
whether the file is a KJV at all, and it is not — it is an
**Americanised, modernised revision**: shew→show (66), neighbour→neighbor
(57), honour→honor, carcase→carcass, jubile→jubilee, musick→music,
brasen→brazen, aul→awl, rie→rye, ringstraked→ring-streaked,
intreat→entreat, firstborn→first born, plus some forty proper-name
respellings (Malchi-shua→Melchishua, Adoni-zedek→Adonizedec,
Ezion-geber→Eziongaber). It also drops the Psalm superscriptions and
the Psalm 119 acrostic letters that `kjvs.json` keeps.

It is not a named revision either: 34.1% agreement with the AKJV and
39.0% with Webster rule out the two obvious candidates. **The label
"KJV" is therefore a provenance claim the file does not support, and
naming it is the owner's call (#285), not this audit's.** Flagged, not
changed.

### A systematic difference is an edition; a one-off difference is an error

That is the rule this check ran on, and it is the reason the 851 could
be split without guessing. The modernisation is inconsistent — `show`
appears 68 times and `shew` survives 160 — so "the witness's word never
appears in our file" is too crude a test and was discarded after it
misfiled `intreat`. What separates the two classes is whether the pair
is a *spelling of the same word* or a *different word*, and 257 distinct
difference shapes is few enough to adjudicate by hand rather than by
heuristic.

**748 departures are the edition, and are left exactly as they are.**
Revising them back would invent a fourth edition of a text three
witnesses already agree on.

**101 are errors**, repaired by `tools/repair_kjv_defects.py`. The
instructive thing about them is how few a reader could ever have caught:

| Reading | Should be | Where |
|---|---|---|
| `Three items in the year` | `Three times` | Exodus 23:17 |
| `And Bezaleel the son Uri` | `the son of Uri` | Exodus 38:22 |
| `left of the door of the poor of the land` | `left of the poor` | 2 Kings 25:12 |
| `who spoken good for the king` | `who had spoken good` | Esther 7:9 |
| `he that c\|alleth for the waters` | `calleth` | Amos 9:6 |
| `So they look up Jonah` | `took up` | Jonah 1:15 |
| `there was certain of the scribes` | `there were certain` | Mark 2:6 |
| `Thou are righteous` | `Thou art` | Proverbs 24:24 |
| **`Cushy`** ×8 | **`Cushi`**, the messenger | 2 Samuel 18:21–32 |
| `in the land of their enemies` | `in the hand` | Nehemiah 9:28 |
| `unto the tribes of Levi` | `the tribe` — Levi is one | Joshua 13:14 |
| `in the candlesticks shall be four bowls` | `the candlestick` | Exodus 25:34 |
| `And Pilate asked him … said unto them` | `unto him` | Mark 15:2 |

The top half of that table is visibly broken. The bottom half is not:
"Cushy" is a legible English word, "the land of their enemies" reads
without a stumble, and "the tribes of Levi" is wrong about a fact while
being perfect English. **Nothing below the midpoint would ever have been
found by reading the app**, which is the whole argument for holding a
text against something outside itself.

The full 101 are listed site by site in `tools/repair_kjv_defects.py`,
each as an exact old→new substring so the diff can be argued with.

### Typographic damage: 42,510 verses in three classes

  * **31,101 of 31,102 verses in `kjv.json` end in a trailing `" \n"`.**
    Invisible in the reader — and inside the string the app searches,
    copies to the clipboard, and hands to the concordance.
  * **11,409 verses in `kjvs.json` print a space before their
    punctuation**: *"and was sick : and he sent"*. 11,084 of those are
    before a colon, which the KJV uses more than any other edition we
    ship. This one the reader can see, and it is the largest purely
    cosmetic defect ever measured in this repository.
  * **10 verses in `kjv.json` carry a stray `|`** left by a conversion.
    Six sit harmlessly at a verse end, two at a verse start, and two
    land inside a word: `he that c|alleth`, `hide nothing from m|e`.

None of these three would fail a schema check, a repertoire check, or a
coverage check. The file is well-formed JSON with the right number of
verses throughout.

**And the spacing defect is in the tagged layer too.** `assets/tagged/kjvs/`
holds the same verse split into runs, and the loader renders runs where
the search pane reads plain text — so repairing one and not the other
makes the same verse look different in two panes. Repairing the plain
file alone is what surfaced it: `eaglesview_versions_test.dart` failed on
John 21:18 while comparing 50 verses of one book. All 66 books carried
it, in the same 11,409 verses, and nothing else — the tagged layer and
the plain text agreed on every other character of all 31,102 verses,
which is how the repair could be trusted rather than guessed.

The tagged repair is a **character mask** rather than a rewrite. Every
repair in this class is a deletion, so the mask that fixes the plain
string can be sliced across the runs — which matters, because a space can
sit in one run with the colon it precedes in the next, and a per-run
regex would miss exactly those. It also means the two paths cannot drift:
`normalise()` is defined as the mask applied to a string.

### One verse truncated, and why exactly one

**Esther 8:9** is the longest verse in the Bible. `kjvs.json` carries it
at 528 characters; `kjv.json` stopped at **499**, mid-clause, dropping
*"according to their language."*

The interesting part is the bound. The next-longest verse in the file is
2 Kings 16:15 at 443 characters, and it is the only other verse over
430 — so a 500-character cap upstream could only ever have shown itself
in one verse of the whole Bible, and did. That is why "how many more are
there?" has to be asked as a measurement rather than a worry: the honest
answer here is one, and it is provable rather than hopeful.

`kjvs.json` having the verse whole is what made the loss demonstrable
at all. Two imports of the same text, damaged differently, witness each
other.

### What was deliberately NOT changed

  * **The edition's orthography** — all 748 systematic departures, listed
    above. Including the proper-name spellings, which are the most
    tempting: `Shimrom` for `Shimron` (1 Chronicles 7:1), `Gaba` for
    `Geba`, `Pharah` for `Parah`, `Mizpar` for `Mispar`. Each *looks*
    like a one-off error, and each belongs to a class of some forty
    name respellings that runs through the whole file. A class is an
    edition even when its members are individually suspicious.
  * **The archaic possessives** `your's`, `their's`, `our's`, `her's`,
    which our file keeps and all three witnesses modernise. We are less
    modernised than the witnesses there, which is evidence the
    modernisation was applied by hand and unevenly — and no reason to
    touch it.
  * **`wit's end`** for `wits' end` (Psalm 107:27). Apostrophe
    convention, not a word.
  * **The 16 BSB omissions.** Absent upstream, and disclosing them is a
    product decision.
  * **The file's name and label.** See above; #285 owns it.

### Frozen

`test/kjv_integrity_test.dart` asserts that no English edition carries a
conversion pipe, a padded verse, or a space before its punctuation
— across `kjv.json`, `kjvs.json` and `bsb.json`, so a re-import of any
of the three trips it — and pins nine repaired verses to the readings
the three witnesses gave, including the whole of Esther 8:9 and the
absence of "Cushy". It also reassembles **all 31,102 verses** of
`assets/tagged/kjvs/` and requires each to equal its plain verse
character for character; the existing Eagle's View test compared 50
verses of John, which was enough to catch this defect but only because
John 21:18 happened to be inside the window.

`tools/repair_kjv_defects.py` verifies by default and applies with
`--write`; it is idempotent and exits 0 when there is nothing left to
repair, and it preserves each file's on-disk formatting (kjv is indent-2,
kjvs is a single compact line). Its first draft was *not* idempotent —
three deletion sites and the Esther 8:9 append re-matched themselves on
a second run, and the append would have doubled the restored clause.
Running the tool twice is the only reason that was caught, which is the
argument for the tool being a tool rather than a one-off script.

---

## Check 28 — the references the Chinese lexicon makes

Every check so far has asked whether the app's *own* claims are true.
This one asks about a column the app merely relays: the scripture
citations inside the bundled Chinese lexicon. A Chinese reader leans on
that column harder than an English reader leans on Strong's, because it
is the deeper of the two — and cannot check it, because the references
were not readable.

Four assets carry it:

| asset | entries | entries citing scripture |
|---|---:|---:|
| `assets/strongs/greek.json` (CBOL `glossZh`/`defZh` + the Traditional pair) | 5,523 | 3,744 |
| `assets/strongs/hebrew.json` (same) | 8,674 | 4,853 |
| `assets/strongs/bdb_zh.json` (BDB in Chinese, behind `ChineseLexiconService`) | 8,853 | 2,450 |
| `assets/strongs/thayer_zh.json` (Thayer in Chinese, same service) | 5,843 | 290 |

**39,106 `#` sites, and 643 more that had lost their `#`** — 39,749
citation blocks in 11,337 of 28,893 entries. Every one of them printed
its delimiters verbatim. The median Greek `glossZh` was **62% markup by
character** (Hebrew 53%); the worst, H1791, was one character of meaning
behind 44 of notation. G1615 reached the reader as
`结束, 完成 (#路 14:19-30|)`.

### The grammar, derived rather than assumed

CBOL writes `(#<citations>|<optional note>)`, but the corpus uses six
variants of it and only the first is documented anywhere:

| shape | example | where |
|---|---|---|
| parenthesised, closed | `(#路 14:19-30\|)` | greek/hebrew |
| bare, closed | `1) 犹大境内地方 #代上 2:51 \|` | bdb_zh |
| parenthesised, unclosed | `(#书19:27)` | bdb_zh |
| inside prose, twice | `#可 5:2 \| 和 #路 8:27 \| 则用…` | thayer_zh |
| with a note after the pipe | `(#代上 3:5\|译作 拔书亚)` | greek/hebrew, 140 blocks |
| **opener lost in import** | `持有人 (徒 4:34\|)` | 643 sites, 627 entries |

Three properties matter for correctness and none of them is guessable
from the notation:

- **The book token is inherited.** `(#提后 1:16-18; 4:19|)` cites
  2 Timothy twice, not 2 Timothy and then an unnamed book. A block that
  opens with no book at all is malformed, not inheriting from the
  previous block.
- **A hyphen is a passage span, not a verse pair.** Established over the
  156 hyphen blocks: `路 14:19-30` is one parable. A link therefore
  opens the span's **first verse** and is never expanded into a list —
  the opposite choice would have manufactured 30 citations where CBOL
  made one.
- **A comma stays inside the chapter; a semicolon starts a citation.**
  `太 1:13, 14` is one reference; `徒 25:15; 帖后 1:9` is two. A verse
  list may itself change chapter — `伯 8:12,9:11` — which a naive
  verse-list regex splits into `8:12,9` and a stray `:11`. That is the
  first instrument error recorded below.

### 28b — 2,304 citations named a book the app could not resolve

The finding that would not have been visible without cross-checking the
data against the *code*: `_chineseShortAliases` in
`lib/utils/reference_parser.dart` had a Traditional half that stopped at
the twelve abbreviations which happen to be short. Missing were
**創 傳 約 林後 帖後 提後 彼後 啓** and the 約壹/約貳/約參 numerals —
Genesis, Ecclesiastes and John among them.

Measured over the corpus's 44,221 explicit book tokens: **2,304 (5.2%)
named a book the parser returned null for**, 2,281 of them because of
that gap. The same gap meant a 繁體 reader typing `約 3:16` into the jump
box got nothing, which is a user-facing defect that had nothing to do
with the lexicon.

Completing the table leaves **9 unresolvable tokens, and they are left
that way on purpose**: `代` (8 sites) is either 1 or 2 Chronicles and
`撒` (1 site) either book of Samuel. Every one of the nine cites a
chapter that exists in both candidates, so nothing in the data decides
it. Content makes 1 Chronicles overwhelmingly likely for all eight, but
"overwhelmingly likely" is how a fabricated fact gets shipped. They stay
unlinked and unrepaired.

### 28a — what the parser refuses to read

`lib/utils/cbol_references.dart` reads **46,052 citations**. **60 `#`
sites do not parse** — 36 distinct defects, the rest the same defect
repeated in the Traditional column. Every one is passed through as plain
text, `#` and all: an unreadable reference must *look* unreadable rather
than vanish or link somewhere plausible.

| class | count | example |
|---|---:|---|
| no book token at all | 12 | `1b3) 认同, 赞同 (#119:128\|)` |
| `:` where the chapter should be | 6 | `(#结:26:9\|)`, `(#赛:19)`, `(#诗:13\|)` |
| ambiguous abbreviation (`代`, `撒`) | 12 | `9) 暗利的父亲或先祖 (#代 27:18\|)` |
| a book with no numbers | 4 | `1) 年岁, 一生的时间 (#路 )`, `(#雅)` |
| prose behind the hash | 8 | `1) 重担, 担负 (#喻意用法)`, `(#)` |
| doubled book token | 2 | `#徒 徒 12:23; 启 12:23, 19:1` |
| pipe inside the citation | 1 | `1a) (Niphal) 使留在其上 (#哀\|41:1)` |
| mojibake (28d) | 1 | `4) 广熔(c8fe)(95f8)腔彶陓(c8cb) (#广(c8fe)1)` |
| lost `#` *and* prose | 14 | `#; 参 '基苏律' 03694 #书 19:12\|` |

Most look repairable — `赛:19` is plainly `赛 19` and `结:26:9` plainly
`结 26:9`. They are **not** repaired here, and the reason is check 27's
lesson stated the other way round: repairing licensed third-party data
in place is a claim about what the source *meant*, and 36 sites is not
worth making 36 such claims for. They are listed so the claim can be
made deliberately later, entry by entry, by someone willing to sign it.

### 28c — nothing readable still wears its delimiters

Two defect classes had to be handled before the delimiters could go:

- **643 blocks lost their opening `#` but kept the closing `|`** —
  `持有人 (徒 4:34|)`, in 627 entries. The parser restores the opener,
  but only when the parenthesis contains a citation list and **nothing
  else**, so a note that happens to sit beside a pipe is never promoted
  to a reference.
- Four one-off malformations that each account for exactly one entry: a
  doubled closer (`西 3:13||`), a closer outside its parenthesis
  (`(#箴6:28)|`), a closer between two citations (`(#罗 9:20|; 提前
  2:13|)`), and a half-verse letter separated from its number
  (`创 16:13 a`).

After all of it, **0 readable citations reach the reader carrying a `#`
or a `|`**, down from 39,749 sites.

### What the reader gets instead

- **A one-line gloss drops its citations entirely.** Safe because it is
  measurably lossless: every citation in a `glossZh` also appears in the
  same entry's `defZh` (Greek 3,542/3,542; Hebrew 3,440/3,441). G1615
  now reads `结束, 完成`.
- **A definition keeps its citations** — they are the evidence for the
  sense — and loses only the delimiters.
- **In the Word Analysis pane the citation is a link.** This is the
  BibleWorks rule for references inside a resource (help topics bwh46,
  bwh10a: hovering previews, clicking moves the browse window), applied
  to the deepest resource the app bundles for a Chinese reader and the
  only one whose references were inert punctuation. A span links to its
  **first** verse.

### 28d — three entries of mojibake, surfaced and left

`thayer_zh` **G1050** (Γάϊος), **G1389** (δολόω) and **G1926**
(ἐπιδέχομαι) are not Chinese. They are a Big5/GB mis-decode:
`埭赻岭间恅; 篣俶(8ca3)衄靡啅` where the etymology should read `源自…`.
The hex-in-parentheses artefact (`(c8fe)`, `(84d3)`) is the signature of
the failed conversion.

Measured across all four assets: a naive `\([0-9a-f]{4}\)` search flags
10 entries, and **7 of those are false positives** — `(668b)` is a TWOT
number, `(a) little 7` is the KJV usage line, `(destroy, lea…` is
English prose. Recording that here because it is exactly the kind of
count that becomes a "finding" if the instrument is not checked first.
The true figure is **3 entries of 14,696**.

They are not repaired. The correct fix is to re-decode from the module's
original bytes, which the repo does not have; inventing three Chinese
lexicon entries would be worse than leaving three visibly broken ones.

### Two instrument errors, recorded because they nearly became findings

- **The verse-list regex.** An early pass reported residues like `':11'`
  across the corpus. They were not in the data: the regex swallowed
  `12,9` in `伯 8:12,9:11` and left the rest behind. A `c:v` item inside
  a verse list is legal CBOL.
- **The alias map, twice.** The first measurement reported 630
  unparseable Greek blocks and 503 + 342 damaged Traditional ones. Both
  were the measuring script's own incomplete Traditional book table.
  Proving the data innocent took a block-by-block comparison of the
  Simplified and Traditional digit/punctuation skeletons — **zero
  mismatches**. The irony is that the same gap turned out to be real in
  the *app's* table (28b); an instrument error and a genuine finding
  wearing the same face.

Also recorded: an earlier off-by-one probe — "does a Strong's number
adjacent to this one occur at the cited verse" — flagged 98 of 620
sampled citations. It is **not evidence of misfiling** and is not
reported as a finding, because cognates cluster: G907/G908/G909 co-occur
naturally, so the probe cannot separate a misfiled citation from a
correctly filed one near its relatives.

### What was deliberately NOT changed

- The four lexicon assets are untouched. Every repair in this check is
  in the reader, not in the data, so a re-import cannot silently undo it
  and no claim is made about what CBOL meant.
- The 9 ambiguous book tokens and the 36 distinct malformed sites stay
  as they are, listed above.
- The three mojibake entries stay as they are.
- `stripCbolReferences` is applied to one-line glosses only. Running it
  over a definition would delete the evidence for the sense.

### Frozen

`test/cbol_lexicon_data_test.dart` walks all four assets and pins the
three numbers: **46,052 citations parse**, **60 sites do not**, in
**32 entries** — and asserts that no string the parser *can* read still
carries a delimiter. A re-import that widens the hole trips it; one that
narrows it should be pinned to its new value.

`test/cbol_references_test.dart` covers the grammar itself. Every input
in it is copied verbatim from the assets, including the malformed ones,
so the tests describe what CBOL wrote rather than what its notation
looks like it ought to be.

---

## Check 29 — the verses an edition does not have

Every check before this one asks whether what the app *shows* is true.
This one asks about the references where it showed **nothing at all**.

`browse_window.dart` built its rows by walking the chapter's verse
numbers and, for each edition, looking the verse up. A reference the
edition did not carry produced `null`, and the loop did what looked
obviously correct: `continue`. No row. So a reader with the Septuagint
and the KJV side by side at Jeremiah 33 saw the Greek column simply stop
after verse 13, with nothing to say whether that is what the Septuagint
does or what our importer did. **426 references across six editions were
in that state**, and the two are not the same thing — as this check
found out the hard way.

BibleWorks was asked first, as always. `bwh29_Setup.htm`, on
recompiling a version: *"If missing verses are found, a blank verse will
be inserted… Normally you should leave this setting on."* Twenty years
of use settled on **the row must exist**. We can do better than blank,
because `verse_text_absence.dart` already argued — about a different
defect, in v1.6.98 — that an empty line "reads as a layout bug rather
than as information".

### 29a — where the 426 are, and the property that makes a row safe

| edition | absent | biggest books |
|---|---:|---|
| `lxxwh` | 304 → **302** | Jeremiah 68, 1 Kings 58, Exodus 56, 1 Samuel 39, Proverbs 21 |
| `biblexg-v2` | 38 | Luke 6, Mark 6, Acts 5 |
| `biblexg-v2-tr` | 34 | Luke 6, Acts 5, 2 Corinthians 3 |
| `leb` | 21 | Mark 5, Acts 5, Romans 3 |
| `bsb` | 16 | Mark 5, Acts 4, Matthew 3 |
| `nasb` | 13 | Mark 4, Acts 4, Matthew 3 |

An edition is only measured against the books it claims to carry, the
same scoping check 4 uses: a New-Testament-only edition is not "missing"
the Hebrew Bible.

The number that decides the design is a different one. **All 426 sit
inside a chapter the edition otherwise carries — none at all in a
chapter it has none of.** That is what makes "this edition has no verse
here" the right sentence: the edition is demonstrably present and
working in that chapter, so a gap in it is information about the
edition. Had even one absence been a whole missing chapter, the rule
would have had to distinguish the two cases, because "no verse here" and
"this edition does not include this book" are different facts with
different remedies. `test/data_integrity_test.dart` freezes the zero, so
the day an import creates the other kind, the test fails instead of the
reader being misled.

### 29b — and then: is the Septuagint's silence its own, or ours?

Making a gap visible is only worth doing if the gap is honest. A row
saying "this edition has no verse here" over a verse the edition *does*
have, which our importer lost, would be a confident lie — worse than the
blank it replaced. So the 304 Septuagint absences were classified
against an **external witness**: the Göttingen-tradition LXX published
at `api.getbible.net/v2/lxx`, 39 Old-Testament books, downloaded whole
and compared after NFD-stripping accents, lowercasing, folding final
sigma and keeping only `[α-ω ]`.

Reference-to-reference comparison is not enough and knowing why is the
whole method. The witness numbers verses in the **Septuagint's own**
versification — Psalms runs to 151 chapters, LXX Jeremiah 33 is MT
Jeremiah 26, LXX Exodus 36 is MT Exodus 39 — while `lxxwh.json` is keyed
by the **English** reference and carries the Greek's own number inline as
`<vs:c:v>`. Comparing the two by reference produces confident nonsense.
Three passes were needed:

1. **Reference agreement.** 229 of the 304 are references the witness
   also lacks. Confirmed minus — the Septuagint does not have the verse.
2. **Content alignment.** 74 the witness has at that reference; 72 of
   them proved *verbatim* to be a verse we carry somewhere else (the
   witness's Exodus 36:10 is our Exodus 39:3). Numbering, not loss.
3. **Global containment**, because pass 2 proves a numbering offset and
   not the absence itself. For each book: does the witness hold any
   Greek with no counterpart anywhere in our file? **33 of 39 books
   returned zero** — including Jeremiah, where 68 references are absent,
   and 1 Samuel, Nehemiah, Isaiah, Ezekiel, Job, 1 Chronicles and
   Lamentations. The 1,116-verse residue is Judges 614 and Daniel 397
   (the A/B and OG/Theodotion recensions — an instrument limit, not a
   finding), Joshua 93, Esther 5 (the Greek Additions), 1 Kings 4 (the
   miscellanies), Exodus 2, Proverbs 1. Then the decisive intersection:
   **residue verses sitting at one of our 304 absences: 0.**

An instrument error nearly became a finding on the way and is recorded
because this document has a habit of recording them: the witness names
the book *Song of Songs* where our canon says *Song of Solomon*, which
reported the whole book as a 117-verse gap until a name remap was added.
Nothing was concluded from it, but nothing in the method would have
stopped it either.

**Verdict: 301 of the 303 Old-Testament absences are the Septuagint's
own text. Two were ours**, and both had the same three-part shape:

```
Numbers 10                        Deuteronomy 23
10:34  absent                     23:24  absent
10:35  = LXX 10:34 + 10:35        23:23  = LXX 23:24 + 23:25
10:36  = the cloud verse          23:25  = the vineyard verse
       (which is English 10:34)          (which is English 23:24)
```

Both books transpose a pair of verses relative to the Hebrew — the
Septuagint prints Numbers' cloud verse *after* "Rise up, O Lord" instead
of before it, and Deuteronomy's standing-corn law *before* the vineyard
law instead of after. Whoever keyed the file followed the Greek's order
instead of translating it into the English one, glued together the pair
that straddled the seam, and left a hole where the displaced verse
belonged.

The hole is the visible half. The **neighbour holding the wrong verse**
is the serious one: real Septuagint text under an English reference that
means something else, in the Greek column — the one a reader cannot
check against anything except us. A reader at Numbers 10:36 was shown
the cloud, which is verse 34.

`tools/repair_lxx_transposed_verses.py` splits and reassigns all six
references in both the flat asset and the tagged layer, and it is
idempotent. Three witnesses fix the answer and none of them is the file
being repaired: `assets/kjv.json` for what each English reference means,
the external LXX for what each Greek verse number means, and — the
reason the split point is not a guess — **the file's own `<vs:c:v>`
markers**, which agree with the witness exactly, so the edition itself
marks where one Greek verse ends and the next begins. Afterwards the two
layers still rejoin to identical text, and `lxxwh.json` holds 30,800
records where it held 30,798.

### 29c — what was measured and left open

- **Merges, as opposed to minuses.** Some absences are references the
  *English* tradition creates by dividing a verse the Greek does not:
  English Psalm 13:6's Greek is present in our file, inside 13:5, and
  Psalm 116:14's inside 116:13. Nothing is lost and nothing is wrong,
  but the honest sentence for those would be the stronger "printed with
  verse 5" rather than "no verse here". Separating this class from a
  true minus needs content alignment against an English text, which is a
  bounded piece of work and was not done. **Found by example, not
  measured** — two known, count unknown. The shipped row makes the
  weakest true claim, which is correct for both classes.
  *(**Measured by check 39**: the count is **7** of 302, and the second
  example above is **false**. English Psalm 116:14's Greek is not inside
  our 116:13 — the edition's own markers name a Greek 115:5 there that
  no record in the file carries, which makes it a gap in our copy rather
  than a merge. The other seven now say "printed with verse …".)*
- **`biblexg-v2` and `-tr`, 38 and 34 absences, unclassified.** These
  are mixed and need their own check: Luke 1:1 demonstrably contains the
  whole 1:1-4 prologue, which is a *merge*, while Philippians 1:1 ends
  in a colon and 1:2 is genuinely gone, which is a *loss*. No witness in
  the same edition has been looked for yet.
- **`nasb`'s 13 and `leb`'s 21** are the classic critical-text
  omissions by reference, and LEB witnesses itself in two places —
  Romans 16:24 carries the note "Some manuscripts include vv. 25-27",
  and Nehemiah 7:69 carries "Nehemiah 7:69-73 in the English Bible is
  7:68-72 in the Hebrew Bible". `bsb`'s 16 were confirmed absent
  upstream by check 27. None of the three was re-verified here.
- **Matthew 12:47**, the one New-Testament absence in `lxxwh`, is
  outside the Septuagint witness's scope. The Westcott-Hort text is
  available from the same source and would settle it in one pass.

### What the reader sees now

The row exists, in the version's own gutter column, with the reference
printed as on every other row and the explanation set in the muted
italic already used for the four *present-but-placeholder* kinds. The
sentence is localised to the **UI** language, not the edition's script,
on the same reasoning as v1.6.93: it is the app speaking, not the
edition.

`VerseAbsence.absent` deliberately does **not** say "not in this
edition's base text", which is what the evidence above would mostly
support. 301 of 303 is not 303 of 303, and the two that were not the
base text were our own defect — precisely the case where the stronger
sentence would have been a confident lie. The row says what it can
prove: our file has no verse here.

---

## Check 30 — *why* each of those verses is absent

Check 29 gave every absent reference a row and one sentence: *this
edition has no verse here*. True of all 426, and the weakest thing that
is true of any of them. It is the right sentence for a reference nobody
can account for. It is a poor one for 路加福音 1:2, whose words are on
the page one line higher under a number the reader can see, and it is
actively misleading for 2 Corinthians 13:13, where three editions have
the verse and the app was telling the reader they did not.

That check named its own gap: *"`biblexg-v2` and `-tr`, 38 and 34
absences, unclassified. These are mixed and need their own check."*
This is that check. It classifies the 122 absences of the five editions
in the English versification frame, using three kinds of evidence
already in the repository, and finds **two live defects** on the way.

`lxxwh`'s 302 are deliberately out of scope: a different canon in a
different base text, already answered by check 29 against an independent
LXX witness. Running an English-tradition rule over them would report
302 defects that are not defects.

### 30a — three derivations, no table

The rule this check set itself is that a classification asserted by hand
is a **second copy of a fact**, and a second copy rots. Each of the
three is read off something the repository already has, at display time:

| evidence | what it proves | reach |
|---|---|---:|
| the edition's own `verseLabel` | the publisher printed these verses as one block | 42 |
| `versification.json`'s `absent` set | no original-language file has words at this reference | 67 |
| `versification.json`'s `map`, read for overlap | the *original* numbers two reader verses as one | 4 |

**The label.** 梁家鏗譯本 files a merged block under its first number and
prints the range: 路加福音 1:1 carries `verseLabel: "1-4"` and the whole
prologue. So 1:2, 1:3 and 1:4 have no record and are not lost. 21 such
references per file, 42 in all — the largest single class in the corpus,
and the only one where the **edition itself** is the witness. Eighteen
of the twenty-one come from two-verse blocks; the Luke prologue supplies
the other three and is the only run longer than a pair.

**The `absent` set.** The seventeen reader keys `derive_versification.py`
found no original-language words for, aligned in v1.6.90 from three
independent tagged translations and knowing nothing about which edition
carries what. Every absence of BSB (16 of 16) and NASB (13 of 13) is in
it, 16 of LEB's 21, and 11 of the 13 the 梁家鏗譯本 labels do not
explain — Matthew 17:21, 18:11, 23:14; Mark 11:26, 15:28; Luke 17:36;
John 5:4; Acts 8:37, 15:34, 24:7, 28:29. Four editions and a table
derived for an unrelated purpose agreeing on the same set is the
strongest agreement in this document that was not designed for.

**The `map`, read the other way.** The half of that table nobody had
used for this: where two reader keys resolve to the *same* original key,
the original has one verse there. 2 Corinthians 13:13 and 13:12 both
resolve to original 13:12, so an edition following the original's
numbering prints them together — and if it carries 13:12 and has no
13:13, 13:13's words are in that record. The claim is safe because an
unmapped key resolves to itself: two unmapped references can never
appear to share, so the sentence is only ever spoken where the table
says something.

Reach: **113 of the 122**, and so 113 of the corpus's 424 absence rows
now say *why* they are empty instead of only *that* they are. 46 of them
name the verse the words are in.

### 30b — 2 Corinthians 13:13 answered with 13:14's words

Found by the third derivation before it was written, while reading why
2 Cor 13:14 was absent from three editions and 13:13 was not.

The critical text prints the chapter in **thirteen** verses: what the
English tradition numbers 12 and 13 — 「Greet one another with a holy
kiss」 and 「All the saints salute you」 — are one verse there, so the
grace benediction the English tradition calls 13:14 is its verse 13.
`leb`, `biblexg-v2` and `biblexg-v2-tr` follow that numbering. The app
keys every edition by the English reference. So all three answered
**2 Corinthians 13:13 with the grace benediction**, beside a KJV column
reading "All the saints salute you", with nothing to say the two are
different verses.

This is the defect class that outranks everything in this document:
plausible, wrong, and unfalsifiable by a reader. Repaired by
`tools/repair_verse_numbering.py`, which moves the record to 13:14 and
rewrites `verse`, `verseLabel` and the last three digits of `id`.

The verse **before** it is untouched and needs no repair. 13:12 holds
canonical 12 and 13 together, which is a *superset*, not a displacement:
a reader sees all the words, in order, in that column. The third
derivation is what now tells them so.

### 30c — 使徒行傳 8:40 stopped at a comma

The absence sweep runs one direction; the same pass run the other way
asks which references exist **beyond** the canon, because a reference
the canon does not have is compared against nothing, and that is where a
converter's off-by-one hides.

Three distinct references turned up across the corpus. Two are real:
`3 John 1:15` (four editions) and `Revelation 12:18` (three) are NA28
splits, confirmed by content. The third was not. Both 梁家鏗譯本
files had 使徒行傳 **8:41**, a reference no versification tradition
gives — and the row numbered 40 stopped mid-clause at 「腓利卻出現在亞鎖
城，」 with the rest of the verse underneath it. Same failure as
使徒行傳 15:16, which `repair_biblexg.py` found as two rows under one
number; here the converter gave the second row the *next* number instead
of repeating it, which is why a key-set comparison reported an extra
verse rather than a lost one, and why check 29 never saw it.

`test/data_integrity_test.dart` had been carrying `Acts 8:41` in its
`_knownBeyondCanon` set since #304, on the stated belief that the
edition's own block note declared an NA28 split there. **It does not.**
The chapter contains no NA28 note at all; the only note in verse 40 is
the geographical gloss 「即向北沿海，」. A hand-written exception had
grown an explanation nobody had checked, which is the argument for
keeping such sets as short as this one now is.

Repaired by joining the rows. The join **adds no character**: the first
row already ended in the comma that separates the clauses.

### What was deliberately NOT changed

- **The 42 range merges.** The publisher's labelling is honest and the
  words are all on the page. Nothing is rewritten; the label is *read*.
- **`leb` Acts 19:41 and Romans 16:25-27.** The edition declares both in
  its own notes. 19:41 is now explained by the third derivation; the
  Romans doxology is **left unexplained** — it is in the edition, inside
  the note at 16:24, but no derivation reaches it and inventing one to
  cover three references would be the hand-written table this check
  exists to avoid.
- **`3 John 1:15` and `Revelation 12:18`.** Legitimate NA28 splits,
  confirmed by content, carried by several editions.
- **馬可福音 6:8-11.** Simplified file only; restoring them needs a
  繁→简 conversion this repository will not invent. Already frozen in
  `test/biblexg_verse_boundary_test.dart` and unchanged by this check.
- **A merge table for the four displaced references.** Considered and
  rejected: the third derivation covers all four from data already
  shipped, and a table would have been a second place for the same fact
  to rot.

### The residue: 9

What no derivation reaches, and the number that must not grow.

| reference | editions | what it is |
|---|---|---|
| Philippians 1:2 | both 梁家鏗譯本 | a real loss — 1:1 ends on a dangling 「：」 and the grace-and-peace greeting is nowhere |
| 馬可福音 6:8-11 | simplified only | the known 繁→简 gap |
| Romans 16:25-27 | `leb` | in the edition, inside the note at 16:24 |

Philippians 1:2 is the only thing this check found that was not already
known, and it is a loss, not a defect of ours to repair: the words are
not in the file to move.

### Frozen

- `test/data_integrity_test.dart` — the four-way classification counts
  for all five editions, computed by the *shipped* `rangeLabelHeads`,
  `sharedOriginalHeads` and `Versification` rather than by a copy, so
  the test fails if the display rule drifts from the measurement; the
  residue as an exact list; the grace benediction at 13:14 with 13:12
  still holding the saints' greeting; and 使徒行傳 8:40 whole and not
  ending in a comma.
- `test/verse_text_absence_test.dart` — `rangeLabelHeads` and
  `sharedOriginalHeads` at the unit level, including the two 以弗所書
  labels that name a verse which also holds its own row.
- `tools/audit_data_integrity.py` check 30 — the wide sweep, in Python,
  reaching the same counts by a different route.

---

## Check 31 — the last English editions, and what the loader was throwing away

2026-08-12, against v1.6.118. "Next, in order" item 1: the English
editions check 27 could not reach, because it had witnesses for BSB and
`kjv.json` and stopped there. `assets/kjvs.json` — the edition the app
labels **KJV+S** — had never been held against anything outside this
repository.

The witnesses were already cached from check 27 and cost nothing to
reuse: `api.getbible.net/v2/kjv` (CrossWire, Blayney 1769),
openbible.com's Pure Cambridge Edition, and scrollmapper's
`bible_databases`. Same normalisation as check 27 — NFKC, curly quotes
folded, lowercased, everything outside `[a-z0-9 ]` dropped, whitespace
collapsed — so the comparison is about words, not typography.

### 31a — `kjvs.json` is the King James Version, and that is the finding

Of 31,102 comparable verses the three witnesses are **unanimous on
30,708**. On those:

| edition | departures from the unanimous reading |
|---|---:|
| `assets/kjvs.json` | **0** |
| `assets/kjv.json` | 699 |

Zero is the whole result. There is nothing to repair and nothing to
freeze beyond what check 27 already froze — but a negative result here
answers a question the previous check left standing, because the two
files disagree with **each other** in **894 verses**, and now we know
which one is departing:

| class | verses | examples |
|---|---:|---|
| orthography | 757 | show/shew ×67, showed/shewed ×57, cherubim/cherubims ×41, neighbor/neighbour ×40, savor/savour ×40, valor/valour ×36, honor/honour ×34, carcass/carcase ×32, brazen/brasen ×23, jubilee/jubile ×22, inquired/enquired ×21 — 185 distinct shapes |
| psalm superscriptions | 117 | `kjv.json` has no *"To the chief Musician, A Psalm of David"* anywhere |
| Psalm 119 acrostic letters | 20 | `kjv.json` has no *ALEPH*, *BETH*, *CAPH*… |

Every one of the 757 is Americanised spelling, which check 27 already
ruled to be this edition's own and left alone. The other 137 are not
spelling: they are **words the edition does not have**, and the three
witnesses all have them.

So the app ships two editions labelled from the King James tradition,
and the one labelled **KJV+S** is the King James Version while the one
labelled **KJV** is the revision. That is not a new decision — it is
item 0 of "Next, in order" (#285), the owner's call, and stated here
only because this check makes it sharper than check 27 could: the
correct text is *already in the repository*, under the other name.

**Deliberately not done:** the superscriptions and acrostic letters were
not restored to `kjv.json`. A systematic absence is an edition; 117 of
150 psalms is systematic. Restoring them would produce a fourth text
that is neither the file we imported nor the KJV.

### 31b — 116 psalm titles nobody has ever seen

Asking a different question of the same corpus — *what does the loader
refuse to load?* — found the defect.

`assets/leb.json` ships **116 records whose `verse` field is the string
`title`**:

```json
{ "book": "Psalms", "chapter": "3", "verse": "title",
  "text": "A psalm of David at his fleeing from the presence of Absalom,
           his son.<note: The Hebrew Bible counts the superscription as
           the first verse of the psalm; the English verse number is
           reduced by one>" }
```

They are the **only** non-integer verse numbers anywhere in the
repository — measured, across all 13 editions and 357,738 records, not
assumed — and `FetchVerses` discarded every one of them at load:

```dart
// Filter out entries where verse is non-numeric
rawList = rawList.where((m) => int.tryParse(...) != null)
```

So **no reader has ever seen one**. This is the same shape as check 25b,
where 139 Old-Testament synopsis groups existed in the assets and
nothing in the app could open them: the data is present, correct and
complete, and unreachable.

That it is complete is checkable without trusting the import. 116 titled
psalms leaves 34 untitled, and the 34 are **exactly** the traditional
list of psalms that carry no Hebrew superscription — 1, 2, 10, 33, 43,
71, 91, 93–97, 99, 104–107, 111–119, 135–137, 146–150. A dropped title
would appear there as an extra number, so the outside witness costs
nothing and the import passes it.

There is a second thing in those records. The footnote each one carries
— *"The Hebrew Bible counts the superscription as the first verse of the
psalm; the English verse number is reduced by one"* — is the fact
`assets/versification.json` had to be **derived** for check 9, the check
that found the reader's verse number is not the original's. The LEB says
it plainly, inside data we were discarding.

**Why it attaches to verse 1 rather than becoming a verse.** The obvious
alternative is to number the record 0 and let it flow through as an
ordinary verse. Browse makes that wrong visible: no other edition has a
reference there, so every other column would print 116 rows of *"this
edition does not carry this verse"* — and `kjvs`, `bsb` and `lxxwh` all
**do** carry the superscription, merged into their verse 1 (that is what
31a's 117 are). Inventing a reference to hold it would make the app
state something untrue about three editions in order to render one
correctly.

The other alternative — prepending it to `text` — makes it reachable
everywhere at once and is what those three editions' publishers did. It
was rejected for the reader and Browse and **taken for the clipboard**,
which is the distinction worth recording: in the app the title is a
typed field, set apart the way a printed Bible sets it; on the
clipboard, a plain-text artifact with no type system, it runs into verse
1 exactly as `kjvs` prints it. `scripture_markup.dart` argues at length
that the answer to "two different things in one string" is a type rather
than a flattening; a flattening is still the right answer at the one
boundary where types cannot survive.

`foldSuperscriptions` is deliberately narrow: anything non-numeric that
is *not* a superscription is left for the loader's own filter to reject,
so the fold cannot quietly widen what the app accepts. The test asserts
that too.

### 31c — 31,199 verses padded with whitespace

`assets/leb.json` is the only edition whose verses end in whitespace,
and it is not a few of them — **all 31,199** close with a newline
(`"…the heavens and the earth--\n"`). Every other edition: **0**. Check
27c already ruled this class a defect rather than an editorial choice;
the reason it survived is that `test/kjv_integrity_test.dart` asserted it
over three of the eleven bundled editions, because check 27 was a KJV
investigation.

The reader never showed it — `buildAnnotatedSpans` calls `trimRight()`
and every sanitiser in `text_patterns.dart` ends in `.trim()`. **Browse
did.** It hands the raw string to `parseScripture`, which strips markup
and nothing else, so every LEB row in the compare pane stood a blank
line taller than the editions beside it.

Repaired by `tools/repair_verse_whitespace.py` — verify by default,
`--write` to apply, idempotent, and re-serialising to the byte-identical
`json.dumps(indent=2, ensure_ascii=False)` shape the file already had, so
the 31,199-line diff contains nothing but the repair. Proved before
committing: every record's non-`text` fields are unchanged and every
changed `text` differs from its original by exactly `strip()`.

Internal newlines are untouched. LJK2 and biblexg-v2 mark OT-quote
poetry with them and `build_verse_content_spans.dart` documents that
they must survive.

### Two verses that look like the same defect and are not

Running check 27's "a space before its punctuation" pattern over the
whole corpus rather than three files finds exactly two more, and neither
is check 27's defect. Both are recorded in the test by id rather than
repaired, which is what stops a third from arriving unnoticed:

- **LEB Judges 14:6** — `( he was bare-handed )`, padding inside the
  publisher's own parenthesis. Typography, not wording; and this
  repository holds no external LEB witness to check a repair against.
- **NASB Jeremiah 29:28** — `’ ?” ’ ”`. Those are U+2009 THIN SPACEs
  holding four nested closing quotes apart, which is correct
  typesetting. `scripture_markup.dart` already documents the same 608
  thin spaces as deliberate, and a blunt repair would have deleted them.

### What was deliberately NOT changed

- **`kjv.json`'s missing superscriptions and acrostic letters.** See 31a.
- **`kjv.json`'s label.** Item 0 of "Next, in order", #285, the owner's
  call, and not a thing to decide unattended.
- **`assets/nasb.json` against a witness.** No public-domain NASB exists
  and the Eagle's View edition is licensed. Item 1 closes for every
  edition that *can* be witnessed; NASB is not one of them, and saying so
  is the honest state rather than a gap.
- **Search.** The superscription renders, and it is **not indexed** —
  `MainProvider.searchKeys` and `wordKeys` still read `verse.text` alone,
  so a reader searching *"Nathan the prophet"* finds 2 Samuel and not
  Psalm 51's title. This is a gap and it was left open on purpose: a hit
  reported against a verse whose visible words do not contain the query
  reads as a bug, and doing it properly means teaching the result rows
  and the KWIC snippet where the extra text lives. Recorded in "Next, in
  order".
- **LEB Judges 14:6's parenthesis.** See above.

### Frozen

- `test/psalm_superscription_test.dart` — `foldSuperscriptions` at the
  unit level (attach, no cross-chapter attach, orphan counted rather than
  guessed at, identity passthrough when an edition has no titles,
  duplicate titles kept in order); and against the asset: 116 titles all
  in Psalms, the 34 untitled psalms as an exact list, all 116 attaching
  with 0 orphans, nothing non-numeric surviving the fold, Psalm 51's
  title naming Nathan, and **no other edition writing a non-numeric verse
  number** — so a second edition's convention cannot start attaching
  silently.
- `test/edition_text_integrity_test.dart` — no padded verse, no
  conversion pipe, over **every** committed edition rather than three;
  and the space-before-punctuation pattern over the whole corpus with the
  two verses above named.
- `tools/repair_verse_whitespace.py` — the repair, re-runnable.

---

## Check 32 — every date the app shows a reader, and what it rests on

Check 8 asked for provenance on dates. Provenance turned out to be the
smaller half of the problem.

Three assets put a year in front of a reader: `assets/family_tree.json`
(277 people), `assets/bible_timeline.json` (98 events) and
`assets/hebrew_kings.json` (42 kings). Only the third cited anything.

The house method does not need a ruling on which chronology is right,
which is just as well, because there isn't one. It asks a narrower
question that has an answer: **for each number we display, can it be
derived from something we ship and cite?** Two things can be — the ages
Genesis 5 and 11 state outright, and `hebrew_kings.json`, which follows
Thiele and cites him. `tools/audit_dates.py` does the derivation, and
**probes all 20 scriptural figures against the shipped Berean text
before it is allowed to classify anything**, aborting if one is not
where it is cited. (It aborted nine times while being written: the
Berean prints Genesis 25:7 as "175 years" and Deuteronomy 34:7 as "a
hundred and twenty", so a probe that hard-codes one spelling tests the
typography and not the figure.)

### 32a — the Anno Mundi chain is exactly right (0 of 19)

Every Genesis 5 and 11 figure in `family_tree.json` matches the ages the
Masoretic text states, read out of `assets/bsb.json`: **19 records, 0
disagreements**, births and lifespans both. This is the one part of the
dataset that was already beyond reproach, and it is worth reporting for
the same reason a zero is always worth reporting.

One record deserved the scrutiny it got. **Shem** is the only man in the
line whose birth the text fixes twice and not identically: Genesis 5:32
has Noah fathering Shem, Ham and Japheth after his 500th year, which
dates the first of three sons rather than Shem; Genesis 11:10 speaks of
Shem alone and puts him at 100 two years after the flood. The asset
follows 11:10 (AM 1558, not 1556) and is right to. The tool reports both
rather than silently preferring one.

The flood falls in **AM 1656** on this chain. Remember that number.

### 32b — one interval out of eleven disagrees, and it is the famous one

Measuring the timeline's own events against intervals scripture states:

| From → to | Text | Asset |
|---|---:|---:|
| creation → flood | 1656 | **1652** |
| creation → Seth born | 130 | 130 |
| Abram called → Isaac born | 25 | 25 |
| Isaac born → Jacob born | 60 | 60 |
| Jacob born → Egypt | 130 | 130 |
| Egypt → exodus | 430 | 430 |
| Moses born → exodus | 80 | 80 |
| exodus → Moses dies | 40 | 40 |
| exodus → temple | 480 | 480 |
| David king → Solomon king | 40 | 40 |
| Solomon king → temple | 4 | 4 |

**11 intervals tested, 1 disagreement.** Ten exact matches is a strong
result and says the file was built carefully. The eleventh is a seam
between two sources: **−4000 is a rounding of Ussher's 4004 BC while
−2348 is Ussher's flood taken as printed**, so rounding one end and not
the other lost four years and put the app four years out of step with a
chain it derives correctly everywhere else. Neither figure is
scriptural, so both events are now marked `approximate` rather than
re-dated.

### 32c — 13 kings of Judah were showing an accession year as a birth

This is the defect. `family_tree.json` gives each king a `birthYear`,
and the UI printed it in the same slot it printed Abraham's, so a reader
saw **"Asa · 911 BC"** beside **"Abraham · 2166 BC – 1991 BC"** and had
no way to know the first is the year Asa came to the throne.

Joining on `hebrew_kings.json` and on the accession ages Kings and
Chronicles state — which witness each other, and are dropped where they
disagree — classifies all 16 without residue:

| | Count | |
|---|---:|---|
| a **reign** start in `birthYear` | **13** | Abijah, Asa, Jehoshaphat, Jehoram, Ahaziah, Joash, Amaziah, Uzziah, Jotham, Ahaz, Manasseh (coregency), Amon, Jehoiakim |
| a genuine **birth** | 3 | Rehoboam (41 at accession, 1 Kings 14:21), Hezekiah (25, 2 Kings 18:2), Josiah (8, 2 Kings 22:1) |
| unexplained | **0** | |

Note that **five** of the thirteen — Jehoshaphat, Jehoram, Uzziah,
Jotham and Ahaz — hold a **sole**-reign start where Thiele's `reignStart`
is a coregency years earlier. Uzziah's −767 is therefore neither his
birth nor the start of his reign as the same app's kings chart draws it
(−792). A number can be wrong in kind in more than one way at once.

A fourteenth record is a reign for a different reason. **Solomon**'s
`birthYear` is −1010, which is neither a birth any stated age gives nor
his accession, which Thiele puts at −970: −1010 is *David's* accession,
shared with ten other people in 32d below. He now shows his reign.

Two id collisions had to be got out of the way first, and both would
have produced confident nonsense: `family_tree.json`'s `manasseh` is
**Joseph's son**, not the king (the king is `manasseh_king`), and its
`nadab` is **Aaron's son**, not Jeroboam's. Joining these files by id
alone dates Joseph's son to −1880 as a king of Judah. Matching on the
`era` as well is what stops it.

### 32d — a year 44 people share is not a birth year

Of **242** BC-dated people, **121 — exactly half — share their year with
someone else**, across 20 collision years; **152 of 242** are round to
the decade. The largest cohort:

| Year | People |
|---:|---:|
| −1690 | **44** |
| −1990 | 12 |
| −1010 | 11 |
| −1030 | 9 |
| −2030 | 6 |

The −1690 cohort settles what these numbers are. It is Jacob's
grandsons — Reuben's four sons, Simeon's six, and so on down Genesis 46,
**the men that chapter names as going down into Egypt with Jacob**. The
same app's timeline dates that descent to **−1876**. So 44 people are
dated 186 years after the event they took part in. No chronology is
needed to see it; the two assets contradict each other.

### 32e — what each asset said about where its numbers came from

- `family_tree.json` credited **"Ussher baseline for patriarchs"**.
  Ussher puts Abraham's birth at **1996 BC**; the file says **2166**,
  and 32b's chain *derives* 2166 exactly from 1 Kings 6:1. The file
  follows the early-date chain and was crediting the wrong man.
- `bible_timeline.json` declared `"count": 97` over **98** events, and
  `"source": "SeekSparks curated"`, which names no chronology at all.
- `hebrew_kings.json` cited 3 sources and named its system. It remains
  the model the other two are now held to.

### What shipped

Every person carries `dating: {kind, basis, refs}` and, where
`hebrew_kings.json` has him, `reignStart`/`reignEnd`. `displayYears` in
`lib/models/biblical_person.dart` is the single join point all eight
year-rendering call sites already funnelled through, so the rule is
stated once:

| kind | count | shown as |
|---|---:|---|
| `birth` | **27** | exactly, e.g. `2166 BC – 1991 BC`, with the verses it derives from |
| `reign` | **14** | `reigned 911 BC – 870 BC` — the birth year is **not** shown |
| `approximate` | **236** | `c. 2030 BC – 1900 BC` / `约 公元前 2030 年` |

The 27 exact births are the 19 of Genesis 5 and 11, plus Abraham, Isaac,
Jacob, Moses and David derived from the anchor chain, plus the three
kings whose accession age scripture states.

**What was deliberately not done.** The first design blanked all 240
underivable years outright. That was rejected: withdrawing a reader's
only sense of when a man lived, for 87% of the dataset, is a bigger
claim than the overstatement it fixes, and it is a product decision
rather than an accuracy one. `c.` withdraws the false precision and
nothing else, and **every original number stays in the file**, so the
decision is still open. Re-dating the 44 would have meant inventing 44
dates, which is worse than either.

### Still open

- **The −1690 cohort contradicts the app's own −1876.** Hedged, not
  resolved. Resolving it means either re-dating 44 people or dropping
  their years, and both are calls for a human.
- **Levi's −1923…−1716 implies 207 years**; Exodus 6:16 states 137.
- **Moses is −1525 in `family_tree.json` and −1526 in
  `bible_timeline.json`.** Within the one year of slack the tool allows
  for regnal reckoning, but the two files should not disagree at all.
- 236 records still rest on nothing citable. `c.` says so honestly; it
  does not make them sourced.

### Frozen

`test/person_dating_test.dart` — the formatter for all three kinds in
English and both Chinese scripts; and against the assets: every record
has a known kind and basis, every `birth` cites a verse, every `reign`
carries the span `hebrew_kings.json` cites, **no `birth` sits on a year
that file calls a reign start**, the legend no longer names Ussher, the
`_meta` counts match the records, and the timeline's count is honest
with creation and flood marked approximate while the exodus stays exact.

### Check 32f (v1.6.146) — the timeline's basis was a list, not a measurement

The `basis` on all 98 events came from **thirteen ids typed into
`tools/audit_dates.py`**. It never looked at a year. So it could not
notice a shipped year drifting from what scripture gives, and — the half
a reader actually saw — it called the other 85 `conventional`, which the
page printed as *"the text fixes no year for this"*. **That sentence was
false for nine events.** Genesis 16:16 states Abram's age at Ishmael's
birth outright.

Every year is now **computed** from a table of steps, each naming the
verse that states its interval, and **a step may only stamp an event when
its arithmetic reproduces the year already in the asset**. Nothing is
re-dated: a step that disagrees abstains and is reported, because moving
a published date is a decision and this tool does not make decisions.

| basis | before | after |
|---|---:|---:|
| derived from the anchor | 8 | **18** |
| `thiele` | 5 | 5 |
| `conventional` | 85 | **75** |

**Three things the derivation forced into the open.**

1. **`scripture` was over-claiming, on both surfaces' shared vocabulary.**
   Scripture states intervals; it never states a BC year. Every derived
   year here is measured from Thiele's Solomon accession, so the basis is
   now `scripture+thiele` — what `family_tree.json` already called the
   same shape. Two assets, one generator, one word for it.
2. **The narrative refs are not the dating verses.** On nine of the 18
   the two sets do not overlap at all: the Jordan crossing is narrated in
   Joshua 3–4, which gives no number, while its year comes from
   Deuteronomy 1:3 and Joshua 5:6. Events now carry a separate
   `datingRefs` — the whole chain back to the anchor, not just the last
   link, because the last link alone does not tell a reader the year
   rests on Thiele too.
3. **Eight of the 18 are Masoretic-only.** Their chain runs through
   Exodus 12:40, whose Greek counts the 430 years in Egypt *and* Canaan.
   Those events carry a `septuagintYear` **215 years later** — a shift
   derived from stated figures and cross-checked against
   `chronology.json`'s Greek-read epochs, which the tool aborts without.
   It ships with the caveat `chronology.json` already carries for the
   same verse: **where the Greek's Canaan portion begins is supplied, not
   read** — the one place on that axis where a year had to be.

**Refused, and why** — the tool derives from *stated intervals* only:

- `joseph_sold`: Genesis 37:2's "seventeen" attaches to tending the
  flock and the bad report. The sale is 37:28 and no interval is stated
  between them. A refuter caught this one after it had been promoted.
- `red_sea`, `jericho`'s neighbours, `plagues`, `burning_bush`: placed by
  narrative order. The Red Sea's year *is* bracketed by two stated dates
  (Numbers 33:3, Exodus 16:1), but a bracket is a different argument and
  this instrument does not make it. The plagues additionally straddle a
  year boundary on Exodus 12:2's calendar.
- the three Jacob events: not, as previously recorded, because his age is
  unstated — `build_chronology.py` derives 91 from the same chain used
  for Joseph. The real gap is Genesis 30:25/31:41, which do not say
  Joseph was born at the end of the fourteen years.

**`abrahamic_covenant` is a genuine internal inconsistency, abstained on
rather than repaired.** It ships at **−2080**, Abram's 86th year — the
year of Ishmael's birth — while its own refs include Genesis 17, which
states 99 (**−2067**). Genesis 16:3 caps Genesis 15 at Abram ≤85
(−2081), so −2080 matches neither ref. Splitting the event or dropping a
ref is a content call.

Also fixed here: the count line read **「1 events」** on a one-match
search.

Frozen in `test/person_dating_test.dart` (every derived event carries a
parseable `datingRefs` chain ending at 1 Kings 6:1; `septuagintYear`
present exactly where the chain contains Exodus 12:40 and equal to
`year + 215`; the ten refusals stay `conventional`) and in
`test/bible_timeline_page_test.dart`, which mounts the page and checks a
promoted row drops its hedge and shows its dating verses — an asset test
and a formatter test still do not compose into a claim about the screen.

### A note on the parity target

BibleWorks ships timelines too, and its help file describes them as a
construction kit — eras, events, jump-to-verse — under a blanket
`Bible timelines Copyright © 1996-2015 BibleWorks, LLC`. It names no
chronology and carries no per-event source. This is one of the few
places where the thing we are chasing has the same gap, so naming the
basis puts SeekSparks ahead rather than level.

---

## Check 33 — the words the app was showing and could not find

Every check before this one asked whether a word we print is the right
word. This one asks a question that had never been put: **of the words
the app is already printing, how many can it not find?**

It is the same class of defect. A search that returns nothing is the app
answering *"this Bible does not contain that phrase"* — a statement
about the text, made in the only way most readers will ever query it,
and it was untrue in two independent ways at once.

### 33a — the 116 psalm titles were on screen and outside the corpus

Check 31b gave `assets/leb.json`'s 116 superscriptions a typed home:
they arrive as records with `verse: "title"`, `foldSuperscriptions`
attaches each to its psalm's verse 1, and v1.6.119 made them visible in
the reader, in Browse and on the clipboard. It stopped there.
`MainProvider`'s two caches — `searchKeys` (whitespace-stripped, for the
substring scan) and `wordKeys` (spaces intact, for the tokenizers) —
were built from `Verse.text`, which by construction is the psalm without
its title.

So the LEB's search corpus was missing 116 lines of scripture that the
LEB's reader was displaying.

The size of that is not 116 verses; it is every word those lines are the
*only* home of. Eleven words occur in an LEB title and nowhere in its
31,083 verses — `director`, `ascents`, `maskil`, `miktam`, `gittith`,
`shiggaion`, `muth-labben`, `shushan`, `eduth`, `leannoth`, `crazy` (of
Psalm 34's superscription). For those, "not found" was the app's whole
answer about the edition.

### 33b — and the answer differed by edition, which is the witness

The three editions carry the same psalm titles by different routes:
`kjvs` and `bsb` merge them into verse 1's own text, so theirs have
always been searchable; the LEB types them apart. The two arrangements
therefore had to disagree, and did:

| query | LEB before | LEB after | BSB | KJV+S |
|---|---:|---:|---:|---:|
| Nathan the prophet | 15 | **16** | 16 | 16 |
| Jeduthun | 11 | **14** | 14 | 14 |
| Gittith | 0 | **3** | 3 | 3 |
| Shiggaion | 0 | **1** | 1 | 1 |
| maskil | 0 | **13** | 13 | 13 *(Maschil)* |
| miktam | 0 | **6** | 6 | 6 *(Michtam)* |
| ascents | 0 | **15** | 15 | 15 *(songs of degrees)* |
| music director | 0 | **55** | — | 55 *(chief Musician)* |

Every row is the same psalms counted three times by three editions
produced independently of each other and of us. A count that agrees with
two outside texts is evidence; a count that only agrees with itself is
not, which is why the fix is measured this way rather than by asserting
the 116.

The last three rows are the same Hebrew word under three English
spellings, and the KJV's `maskil` returns **0** — the spelling really is
the only difference between the editions, so the agreement is not an
artefact of one text having been derived from another.

### 33c — the larger defect, found one layer down

Asking *why* `music director` still failed after the titles were in the
corpus found a second defect that has nothing to do with psalms.

`[supplied]` words — the translator's words, which a printed Bible sets
in italic — are rendered to the reader **without their brackets**
(`bracketSpanKind` in `lib/utils/scripture_markup.dart`: only divineName
and gloss keep them). `sanitizeForSearch` does not strip square
brackets, so the corpus key kept them. LEB Genesis 1:2 prints

> darkness was over the face of the deep

and its search key held `darkness[was]over…`. The verse was
unreachable by the phrase it displays.

**16,975 of the LEB's 31,083 verses carry at least one bracket** —
54.6% — and 17,932 across the six shipped editions. Any phrase crossing
a supplied word failed, silently, in more than half of that edition.
This is the answer to *"how many more of these are there"*: two orders
of magnitude more than the thing that surfaced it.

### What shipped

One flattening, defined once, and one sanitiser:

- **`Verse.scriptureText`** — `superscription + ' ' + text`, or `text`
  alone. Every boundary that must reduce the pair to a single string now
  goes through it: the search corpus, the verse-number copy handler, the
  Copy Centre, the command pane's result preview and its "copy all".
  Four call sites had each written the concatenation themselves; a
  boundary that flattens differently from the corpus is how an app
  searches one string and shows another.
- **`sanitizeForSearchKey`** — `sanitizeForSearch` plus the square
  brackets removed, contents kept. It is a **new** function rather than
  a change to `sanitizeForSearch`, because that one also feeds result
  previews and copy paths, where the brackets still tell a reader which
  words the translator supplied. A corpus key is the one place with no
  reader to inform.
- **Browse highlights the superscription line.** A hit whose words the
  result row cannot show reads as a bug, so `_SuperscriptionLine` now
  takes the same `SearchHighlight` the verse body does.

Removing a delimiter cannot invent a hit: every character left in the
key is a character on screen.

### What was deliberately not changed

- **`sanitizeForSearch` itself.** See above.
- **KWIC and the concordance.** Both are driven by Strong's numbers
  through the tagged layer, which holds no superscription, so a hit
  there can never be in one. The queue item assumed KWIC needed the same
  work; checked, and it does not.
- **The Strong's result preview in the command pane** keeps `.text` for
  the same reason, and now says so.
- **The reading pane's highlight.** It does not highlight search hits at
  all — `highlightsForQuery` reaches Browse only. Making it do so is a
  feature, not this defect.
- **`related_verses_pane` and `phrase_match_pane`** render the corpus
  string itself, so they were already self-consistent.
- **The `absence` guard.** Placeholder verses stay out of the corpus;
  `absence` is a property of `text` alone and a title cannot make a
  missing verse present. Measured: the LEB has 0 absence records, so
  this changes nothing today and states the rule for the editions where
  it would.

### Still open

- **The other five bracket-bearing editions were fixed by the same
  line but not separately witnessed.** `lxxwh` (490 verses),
  `cuvs-yhwh` and its Traditional twin (212 each), `nasb` (13),
  `cuvs-plus` (2). The change is uniform and the LEB is the hard case;
  a per-edition witness would be a further check, not this one.
- **The 和合本's `主[雅伟]` keeps its brackets on screen and loses them
  in the key.** Deliberate — a reader typing 主雅伟 should reach the
  verse that prints those words adjacent — but it is the one place where
  key and display diverge on purpose, and it is recorded here rather
  than left to be rediscovered.
- **A supplied word is never highlighted, even when it is part of the
  hit.** Browse splits only `ScriptureSpanKind.plain` on the search
  terms; `supplied` renders whole. So `music director` now *finds* the
  55 psalms and marks only `director`. Verified on screen at v1.6.121
  and left alone: it is **pre-existing** — the old key held
  `the[music]director`, so a one-word `music` query already matched and
  already went unmarked — and closing it changes verse rendering for
  all 17,932 bracket-bearing verses, which is a wider blast radius than
  a cosmetic gap earns in the same pass as the correctness fix.

### Frozen

`test/psalm_superscription_search_test.dart` — the flattening in all
three of its cases; `sanitizeForSearchKey` against brackets, notes and
the 和合本 name; a seeded corpus proving the title reaches both caches
without its footnote; and, against the shipped assets, **every row of
the table above**, built through the loader's own path
(`foldSuperscriptions` → drop non-numeric → `Verse.fromJson` →
`MainProvider.setVerses`) and queried through `SearchService.scanText`.
Plus Genesis 1:2 by the phrase it prints.

---

## Check 34 — the small number in brackets, which nobody had ever read

`assets/lxxwh.json` is keyed by the **English** reference, so a reader
who types Joshua 8:30 finds the verse an English Bible calls Joshua
8:30. Where the Septuagint numbers that verse differently the record
carries the edition's own chapter-and-verse inline as `<vs:c:v>`, and
since v1.6.117 the app **renders** it — a muted `(9:2)` in front of the
Greek.

Three checks have now been through this column and none of them read it.
Check 23 measured its Strong's numbers. Check 29 asked whether the Greek
is complete. Check 31 gave the marker a type of its own so it would stop
being set in scripture face. Every one of them treated the marker as a
token to be *handled*. It is a **claim** — a second fact about the
verse, stored once, in the one column a reader cannot check against
anything except us — and 4,687 of them had shipped unread.

`tools/audit_lxx_versification.py` puts every marker to an outside
witness: `api.getbible.net/v2/lxx` (the same LXX check 29 used) and
`api.getbible.net/v2/westcotthort`. A marker says "these words are what
the edition numbers c:v". Look up c:v in the witness and compare.

**4,200 of the 4,247 the witness can resolve are verbatim right**, and
another 47 are contained in a longer witness verse (the recension cases
check 29 declared). The residue is three defects, and each is repaired
in a way that keeps more than it removes.

### 34a — 144 markers in Proverbs, every chapter off by exactly seven

English Proverbs 25:1 claimed `32:1`. 29:27 claimed `36:27`. **The
Septuagint's Proverbs has 31 chapters**, so 32–36 are not numbers that
book has, and the claim is false before the words are even consulted.

Every one of the 144 is the record's own chapter **plus seven**, with
the verse unchanged — not a scattering of errors but one mechanical
offset applied to a block. And the words say exactly where the block
belongs: **all 138 records are verbatim the witness at their own English
number, 138 of 138.**

So the repair is a **subtraction, not a deletion**. Seven comes off the
chapter. 138 markers then name the record's own number and are dropped
as saying nothing (see 34c); the **6 that carry a sub-verse letter
survive** as `25:10a`, `26:11a`, `27:20a`, `27:21a`, `28:17a` — which is
what the rest of the book already looks like, since Proverbs has 42
other lettered sub-verses. Deleting the 144 outright was simpler and
would have thrown those six away.

Where the seven came from is **not recoverable from the file**. Rahlfs
prints Proverbs out of order — 24:22, then 30:1-14, then 24:23-34,
30:15-33, 31:1-9, and only then 25–29 — so a count of printed blocks
rather than of chapter numbers is where an error of this shape would
come from. That is a guess and is recorded as one.

The reader-facing size: 138 verses of Proverbs printed a chapter number
that does not exist, in the muted type that means *this is what the
Greek calls it*.

### 34b — 129 sub-verse letters in the wrong alphabet

Rahlfs letters his sub-verses in **Latin**: Joshua 9:2a-f, 3 Kingdoms
16:28a-h, the Greek Additions to Esther. Ours were Greek — α β χ δ ε φ
γ η σ — so the app printed `(9:2χ)` where the page says `9:2c`.

No witness exists for this (the witness numbers verses, not sub-verses)
and none is needed. **1 Kings 16:28 settles it alone.** It carries eight
markers in one record, in this order:

> α β χ δ ε φ **γ** η

γ stands **seventh**. In Greek it is third. In Adobe Symbol it is `g`,
which is seventh in Latin — and every other letter lands where Latin
puts it too. Ten more records run α β χ δ, which is `a b c d` and is not
any ordering of the Greek alphabet. The frequencies say the same thing
independently:

| suffix | α | β | χ | δ | ε | φ | γ | η | σ |
|---|---|---|---|---|---|---|---|---|---|
| count | 65 | 23 | 17 | 12 | 6 | 3 | 1 | 1 | 1 |
| Latin | a | b | c | d | e | f | g | h | s |

A clean descent through `a b c d e f g h`. Read as Greek it is
unaccountable: γ third-most-common letter of the alphabet, once; χ
twenty-second, seventeen times.

This is **Adobe Symbol font mojibake** — the source typed `a b c d`, the
Symbol font drew Greek, and the import read the drawn glyphs as Unicode.

Esther 1:1's lone **σ** is the one case resting on the encoding argument
alone: it has no run to sit in. σ is Symbol `s`, and Rahlfs letters the
Additions to Esther past `r`, so `1:1s` is the reading. **Whether Rahlfs
has a sub-verse there at all is the source's claim and this repository
cannot check it** — recorded rather than resolved.

### 34c — 6 markers that say nothing, mid-verse

Matthew 26:61, Mark 6:28, Mark 12:15, Acts 13:39, Ephesians 1:11 and
Ephesians 3:18 each carried a marker naming the record's **own** number,
placed in the middle of the verse. A reader of Matthew 26:61 saw:

> Later two came forward **(26:61)** and said…

A marker exists to record a **difference** from the reference the record
is keyed on; one that repeats the key is empty by definition. And there
is no second verse it could have been introducing: each of the six
records is the witness's verse at that same number, entire (5 exact, 1
contained — Acts 13:39, where the witness's own text reads `και και`).

Two other identity markers are **not** touched and must not be:
Lamentations 1:1 runs `1:0` then `1:1`, and Revelation 13:1 runs `12:18`
then `13:1`. Those resume the record's own number after a genuinely
different one, and are doing work.

### 34d — Matthew 12:47, which was item 1 on this list

Item 1 said the Westcott-Hort text "would settle it in one pass". It
does, and not in the direction the item expected.

**The witness has Matthew 12:47 and brackets it whole** — `[ειπεν δε τις
αυτω ιδου η μητηρ σου…]` — which is Westcott and Hort's own mark for a
reading they doubted. That looked like an explanation for our absence,
so it was measured rather than assumed: **the witness wholly brackets
exactly 2 NT verses, and we carry the other one** (Matthew 21:44). One
of two is not a policy. The absence looks like ours.

It is **reported and not repaired**, and the reasons are worth stating
because the opposite call was available:

* The Greek would have to come from a witness that **inlines UBS4
  variants as duplicated words** — Matthew 12:46 reads `ιστηκεισαν
  ειστηκεισαν`, 2 Corinthians 13:14 `χριστου χριστου`. That instrument
  is fit to answer *which references exist* and unfit to supply *words*.
* `assets/tagged/lxxwh/matthew.json` has no `12:47` either, so importing
  the flat verse alone would create a reference the second witness of
  check 31 cannot see — trading a known absence for an unknown
  disagreement between our own two layers.
* The app already makes the **weakest true claim** there.
  `VerseAbsence.absent` renders "this edition has no verse here", which
  is true of our file whatever the reason.

Adding a verse to a shipped scripture asset is a decision about what the
product **contains**. It is left open.

### The two instrument limits, recorded because they nearly produced findings

1. **The `westcotthort` witness is keyed by the ENGLISH reference,
   exactly as our file is.** So the NT marker column **cannot be tested
   by it at all**: looking up the marked number fetches a different
   verse. Run naively this produces 12 confident "disagreements" —
   Luke 6:17, Acts 3:19, Romans 9:11, 2 Corinthians 13:13–14,
   1 Thessalonians 2:6 and 2:11, Revelation 2:27 and the rest — every
   one of which is a **genuine and correct** Westcott-Hort division that
   the instrument is blind to. The tell is that 12 of the 19 NT marked
   records are verbatim the witness **at their own number**. The audit
   reports the two halves separately and draws nothing from the NT one.
2. **The same witness inlines UBS4 variants as duplicated words**, so it
   cannot witness NT *wording* either. Two independent reasons, one
   conclusion: in the New Testament this witness is a reference list and
   nothing more.

### Negative results, which are results

* **There is no missing-marker class.** The absence of a marker is
  itself a claim — "the Septuagint numbers this verse the way English
  does" — made 18,000 times and never tested. **17,295 unmarked Old
  Testament records are verbatim the witness at their own number**
  (17,427 after 34a), 1,025 more are contained in a longer witness
  verse, and exactly **one** differs: Numbers 32:30, a wording variant
  and not a numbering one.
* **Joshua 19:47 and 19:48 are not transposed.** They carry each other's
  numbers (`<vs:19:48>` on 47, `<vs:19:47>` on 48), which is the exact
  shape check 29 repaired in Numbers 10 and Deuteronomy 23. The witness
  confirms **both markers are right**: the Septuagint really does print
  those two verses in the opposite order. A defect this audit had
  already seen once was the wrong template for it.
* **The app's own pattern was already correct.** `versificationPattern`
  is `<vs:([^>]+)>`, so it handled lettered markers before anyone
  checked that it needed to.
* **The 1,289 Old-Testament references the witness has and we lack** are
  check 29's declared territory — the Esther Additions, the 3 Kingdoms
  miscellanies, the Daniel OG and Judges A/B recensions — not a new
  finding, and counted here only so the number is not mistaken for one
  later.

### What shipped

`tools/repair_lxx_versification_markers.py`, idempotent, applied to
**both layers**: 213 records of `assets/lxxwh.json` and 273 runs across
15 files of `assets/tagged/lxxwh/`. 144 Proverbs markers un-offset (138
then dropped as identity), 129 sub-verse letters transliterated, 6
vacuous markers dropped. Marker count 4,687 → **4,543**, in 4,543 → 
**4,405** verses.

**No Greek moved.** Verified directly: with every `<vs:…>` stripped,
all 30,800 records are byte-identical before and after.

### Still open

- **Matthew 12:47** — see 34d. A decision about the product, not about
  accuracy.
- **The New Testament's 19 markers are unverified**, and cannot be
  verified by the witness this repository has. They look right (they
  name the well-known Westcott-Hort divisions) but "looks right" is what
  this document exists to refuse. A WH text keyed by **its own**
  numbering would settle them.
- **Rahlfs' sub-verse letters are unwitnessed.** 34b establishes what
  our source *meant*; it does not establish that Rahlfs has a sub-verse
  at each of those 129 places.
- **A tagged run with a Strong's number and no word.** Matthew 26:61's
  tagged layer carries `{"w": " ", "s": "G3004"}` where ειπαν should be
  — noticed while reading 34c's records and **not** measured across the
  corpus. *Measured by check 35: 18 shipped runs, and Matthew 26:61 is a
  double count rather than a missing word. See check 35's "Still open".*

### Frozen

`test/lxx_versification_test.dart` — the counts (4,543 markers, 4,405
verses, 4,528 in the tagged layer, still exactly 15 fewer for
Nehemiah 10's known gap) and **two ratchets that need no witness**: a
marker's suffix must be Latin, and a marker may not name its own
reference unless a different one precedes it in the same record. Plus:
no marker anywhere in Proverbs may name a chapter above 31.
`test/lxx_tagged_layer_test.dart`'s OT run total moves 479,989 →
479,851, which is the 138 dropped Proverbs runs and confirms the repair
reached the tagged layer identically.

---

## Check 35 — 139 claims that two passages tell the same thing

`assets/ot_synopsis.json` holds 139 groups of 2–4 Old Testament
passages imported from Eagle's View, reachable from the reader since
v1.6.113. Every group is two claims at once: *these passages are
parallel*, and *this title names them*. Check 25 proved the 313
references resolve to verses that exist. It never asked either
question — a reference can be perfectly well-formed and point at the
wrong chapter, and a title can be printed over a passage that
contradicts it.

`tools/audit_ot_synopsis.py` asks both.

### The instrument for the alignments, and why raw overlap will not do

Two accounts of Uzziah's reign share their Hebrew vocabulary whatever
translation renders them, so a passage reduces to the multiset of
Strong's numbers behind it. `assets/tagged/kjvs/` and
`assets/tagged/cuvs-yhwh/` tag an English and a Chinese translation with
the same Hebrew numbers over the same 23,145 verses, so a pair judged
dissimilar by both is dissimilar in the **Hebrew** and not in one
translator's word choice.

Raw overlap measures nothing: every Old Testament passage shares H853,
H3605, H1961 and H559 with every other. Each number is weighted by
inverse verse frequency over the whole tagged Old Testament and
passages are compared by cosine, so a shared H4428 ("king", ~2,500
verses) is worth almost nothing and a shared H5818 ("Uzziah", 24) a
great deal.

**A score means nothing without a null.** 3,994 random contiguous
passage pairs are drawn matched on the length distribution of the real
pairs, from the same books, same-chapter pairs discarded:

| layer | median | p90 | p98 | p99.5 | max |
|---|---|---|---|---|---|
| kjvs | 0.037 | 0.101 | 0.157 | 0.218 | 0.438 |
| cuvs-yhwh | 0.052 | 0.126 | 0.188 | 0.250 | 0.472 |

### The scoring rule that had to be corrected before it was believed

The first version scored a group by its **worst** pair, and group 41
"David's Children" came out at 0.000 in the English layer — a group
that is obviously right. Reading it showed why: 1 Chronicles 3:1-9 and
2 Samuel 3:2-5 are the sons born in Hebron, 2 Samuel 5:14-15 and
1 Chronicles 14:4-7 the sons born in Jerusalem. Two disjoint name
lists, one subject, and the group is correct.

So a group of four may legitimately hold two passages unlike each
other. What cannot happen is a passage that resembles **nothing else in
its group**. Each passage is therefore scored by its best sibling match
and the group by its loneliest passage. Flags fell 15 → 11 and group 41
left the list, which is the instrument being calibrated against a case
whose answer was already known.

### 35a — the alignments: 11 flagged, 10 read as correct

11 of 139 groups sit below the 98th percentile of the null in either
layer. Every one was read. **Ten are Eagle's View doing something on
purpose that the instrument cannot see**: including a one-verse
synchronism next to a long narrative. Isaiah 6:1 ("In the year that
king Uzziah died") is one verse against two 2-verse death notices;
Isaiah 1:1 names Uzziah's reign; Isaiah 20:1 dates Sennacherib;
Jeremiah 1:1-3 dates Josiah's eighth year; 1 Kings 2:46 is the half
verse that says the kingdom was established in Solomon's hand;
Psalm 132:8-10 is quoted at the end of Solomon's prayer. A single verse
carries almost no vocabulary, so it scores low **because it is short**,
not because it is wrong. That is an instrument limit and it is recorded
as one.

**The eleventh is reported and deliberately not repaired.** Group 4
"Hebrew Servants" is Leviticus 25:8-38 | Deuteronomy 15:1-11, and the
Hebrew-servant law begins one verse *after* both ranges end —
Leviticus 25:39-55 and Deuteronomy 15:12-18 — while Exodus 21:1-11, the
primary passage, is absent. Both ranges are instead the sabbatical-year
and jubilee release, which is a real parallel under a different title.
Whether Eagle's View meant the release or the servant law is a question
about their source, which this repository does not have; re-scoping the
group would be inventing an editor's intent. Stated, not changed.

### 35b — the titles: 7 of 139 misspelled, every one self-witnessed

The passage a title labels is the witness for the title. A title word
of five letters or more that is **absent** from its own passages while
a word **in** those passages sits within two edits of it is the shape
of a misspelling, and the corpus answers it without a dictionary:

| group | title, as imported | as repaired | the witness |
|---|---|---|---|
| 27 | Jepheth's Descendants | **Japheth**'s Descendants | 1 Chronicles 1:4 "Shem, Ham, and Japheth"; CUV 雅弗 |
| 165 | Johoash's Death | **Jehoash**'s Death | 2 Kings 14:15-16, the group's own two verses, twice; CUV 约阿施 |
| 188 | Manesseh's Reign | **Manasseh**'s Reign | 2 Chronicles 33:1, 2 Kings 21:1; CUV 玛拿西 |
| 17 | Bezalel and Oholiah | Bezalel and **Oholiab** | Exodus 31:6, 35:34 "Aholiab"; CUV 亚何利亚伯, a final *b* |
| 157 | Athaliah's Assasination | Athaliah's **Assassination** | plain English |
| 186 | Hezekiah's Illneess | Hezekiah's **Illness** | plain English |
| 57 | Settler's in Jerusalem after Exile | **Settlers** in Jerusalem after Exile | a possessive apostrophe followed by a preposition |

Four of the seven are proper names, and in each the correct spelling is
carried by the group's own verses in **two** translations. Nothing
outside this repository was consulted and nothing was guessed. `Oholiah`
is not a name in any tradition; both witnesses give the final consonant
independently.

**`Bezalel` is deliberately not repaired.** The KJV spells him
`Bezaleel` and the audit flags the one-edit difference, but Bezalel is
the spelling every modern version uses. It is a translation convention,
not an error, and repairing it would be the instrument overruling the
editor. The same reasoning protects `Oholiab` after repair.

### 35c — the same question asked of every other title in the corpus

A defect found in one asset is worth nothing until it is measured
everywhere it could occur. The same instrument was run over every other
shipped title that labels a passage:

| asset | titles checked | real defects |
|---|---|---|
| `ot_synopsis.json` | 139 | **7** |
| `section_titles.json` (`english-classic`) | 1,443 | 0 |
| `gospel_synopsis.json` | 70 of 71 resolved | 0 |

The 1,513 other titles produced 23 raw hits and **all 23 are
artifacts**: modern spellings against the KJV (Malta/Melita,
Melchizedek/Melchisedec, Pergamum/Pergamos, Hagar/Agar,
Arameans/Syrians), British inflections `/usr/share/dict/words` does not
carry (Baptised, Sympathises, Returnees), and possessive tokens
(`Jesus'`, `Cyrus'`). The defect is confined to the Eagle's View import.

### 35d — the Chinese titles, and how hard the check looked

The Chinese half cannot be done the English way. Chinese has no spaces
to segment a name on, and over a long passage every 2-gram of a title
sits one character from something: the naive form of this test returned
**334 findings of which none was an error** (会幕 vs 帐幕 and 麻风 vs
麻疯 are word choice and orthography, not mistakes). It was discarded
rather than tuned.

The Strong's numbers are the way across. A name the English title gets
right resolves, in the group's own verses, to a Hebrew number; the same
number in the Chinese layer over the same verses gives the CUV's own
spelling; and the Chinese title is then asked for that exact string.
**50 title names carried through, and the Chinese title uses all 50.**

A check that finds nothing has to say how hard it looked. Corrupting
one character at a time inside each of the resolved names: **137 of 143
single-character corruptions caught, 95.8%**, over the 42 of 139 titles
that carry a resolvable name. Across *all* 904 title characters the
rate is 15.2%, which is the honest number for "would this catch any
error in a Chinese title" — it would not. It catches errors in names,
and there are no errors in names.

### What shipped

`tools/audit_ot_synopsis.py` — the instrument, structure + vocabulary +
titles, with `--all` and `--titles`.
`tools/repair_ot_synopsis_titles.py` — the seven titles, idempotent,
each with its evidence in the source.
`assets/ot_synopsis.json` — 7 `en` titles repaired, each recorded in the
asset's own `corrections` block with `field: "en"` and a reason, which
is the mechanism the two schema-2 reference corrections already used.
The groups are re-sorted by title because the importer sorts by title
and two first letters changed; the app indexes by book, so file order is
not read.
`tools/import_eaglesview_ot_synopsis.py` — `TITLE_CORRECTIONS`, so a
re-import from the Eagle's View source does not undo the repair.

### Negative results, which are results

- **0 structural problems** beyond one duplicate: 2 Chronicles 1:14-17
  appears in both group 94 ("Solomon's Wealth") and group 108
  ("Solomon's Riches"). Read, and legitimate — 2 Chronicles 1:14-17 is a
  genuine doublet of 2 Chronicles 9:25-28, so the same passage is
  correctly parallel to two different things. No group has a missing
  title, an empty expansion, or two passages that overlap each other.
- **0 of 1,513 titles outside this asset** carry the defect (35c).
- **0 of 50 checkable Chinese names** disagree with the CUV (35d).
- 128 of 139 groups sit above the 98th percentile of the null in both
  layers, and 10 of the remaining 11 read as correct.

### Still open

- **Group 4 "Hebrew Servants"** — reported above, not repaired. Needs
  the Eagle's View source, which this repository does not carry.
- **97 of 139 Chinese titles carry no name the instrument can resolve**,
  and are therefore unchecked. A Chinese-language witness for the titles
  themselves would be needed, and the source ships none.
- **The alignments are checked only for vocabulary.** A group whose two
  passages share a great deal of vocabulary but are not the same event
  would pass. Nothing in the repository distinguishes those.
- **`lxxwh`'s blank tagged runs**, carried over from check 34's list and
  now measured rather than guessed: **18 shipped runs** carry a Strong's
  number with no word. Matthew 26:61's `{"w": " ", "s": "G3004"}` is not
  a missing word — the import split one word around the `<vs:26:61>`
  marker into two runs *both* carrying G3004, so it is a **double count**
  in the concordance, not a loss of text. 3,981 more are in the unshipped
  `nsn-plus`. The adjacent class — 7,039 shipped runs whose word is
  punctuation only — is largely *legitimate*: a Strong's number for an
  original word the translation does not render, attached to the
  punctuation at that point (CUV `"，"` = H3027 "hand", which the CUV
  genuinely omits at 1 Chronicles 4:10). 18 runs is too thin to be a
  check of its own and too easy to "fix" wrongly; the numbers are here so
  the next reader does not have to measure them again.

### Frozen

`test/ot_synopsis_titles_test.dart` — the seven repaired titles by exact
value; the asset's `corrections` block must record all seven; and the
standing rule of 35b, which needs no dictionary and no external witness.
Against the pre-repair asset all three tests fail and the third names
exactly Oholiah, Jepheth, Johoash and Manesseh.

---

## Check 36 — 277 people, and whether the text says what the tree draws

`assets/family_tree.json` is the one curated asset this document has
listed as unchecked since the list was written. It states **312
parent-child links, 26 marriages and 277 lives**, and it draws the same
solid line for "Adam begat Seth", which Genesis 5:3 states in as many
words, and for "Heli was the father of Mary", which no verse states at
all.

Check 25 proved the file's **665 references resolve**. That is a
strictly weaker claim than the one the tree makes on screen, and it is
the same gap check 35 found in `ot_synopsis.json`: a label can point at
a real passage and still be contradicted by it. So the question here is
check 35's question asked of a different asset — **is the passage a
record cites a witness to what the record says?**

Nothing outside this repository is consulted. Five English editions
(`bsb`, `kjv`, `kjvs`, `nasb`, `leb`) and the CUV are the witnesses, and
the instrument is `tools/audit_family_tree.py`.

### The instrument, and the alias problem that had to be solved first

A name the KJV spells `Methusael` and the NASB spells `Methushael` must
not be scored as a missing person. But a supplied list of spelling
variants would be a second unaudited asset, so the variants are
**derived from each person's own cited verses**: a capitalised token
standing in a verse the record itself points at, within one edit for a
short name or two for a long one, is that edition's spelling.

The first version of that rule was far too permissive — it offered `Lot`
the aliases *But, For, God, LORD, Let, Look, Lord, Now* — and 136 of 277
people carried something. Four rules, all derived from the corpus rather
than from a dictionary, cut it to **67 people with 76 aliases, every one
readable as a genuine variant** (Booz/Boaz, Sem/Shem, Zabulon/Zebulun,
Naasson/Nahshon, Coniah/Jechoniah/Jechonias):

1. **A proper name is a token the corpus never lowercases.** This is
   what separates `Job` from `God`, `Lord` and `Let`, with no word list.
2. **Another person in the tree is a different man, not a spelling.**
   Athaliah is not a variant of Ahaziah.
3. **Edit distance scaled to length** — one edit for five letters or
   fewer, two above.
4. **Two spellings of one name do not share a verse.** If both tokens
   stand in the same verse of the same edition they are two people.

### 36a — the graph itself: 0 issues, which is a result

Every one of the 312 parent-child edges is reciprocal — the parent lists
the child and the child names the parent. All 26 marriages are recorded
on both sides. No id points at a person who is not in the file, no id is
duplicated, nobody is their own parent, and no chain of `fatherId`
closes into a cycle. **0 of 277 people and 0 of 338 relationship
records carry a structural fault.** The file is internally sound; every
finding below is about what the *text* says, not about the graph.

### 36b — the years: 8 findings in 290 comparable edges

Reported second because the first run of it produced **325 findings and
every one was an artifact**, described under instrument errors below.

Of the 312 edges, **290 are comparable**: 19 are skipped because one end
is a `reign` record, whose `birthYear` is an accession year and not a
birth (check 32c established this and `_meta.dating.kinds` says so), and
3 are skipped because the two ends use different year systems. No record
is missing a year — all 277 carry one.

- **3 edges cross the seam between the two year systems**, all of them
  Terah's: Terah is dated `am 1878` and his sons Abraham, Haran and
  Nahor are dated `bc`. Both systems are documented in `_meta.yearLegend`
  and neither is wrong, but a reader looking at the tree sees a father
  numbered 1878 above sons numbered 2166, 2200 and 2180, with nothing on
  screen saying the numbers are on different axes. Converting one to the
  other requires fixing a year for the creation, which this repository
  deliberately does not do — Ussher's 4004 BC is **not** this repo's
  chronology — so nothing is converted. Recorded, not repaired.
- **4 parent-child gaps are biologically impossible**, out of 290:
  Eliphaz → Amalek **0 years**, Heli → Mary 5, Hagar → Ishmael 10, and
  Nathan → Mattatha 10. All four are `approximate`/`conventional` at
  both ends, meaning both years are reconstructions the app already
  hedges with "c.".
- **1 parent died before the child was born**: Levi `d = 1716 BC`,
  Jochebed `b = 1550 BC`, a gap of 166 years — and Numbers 26:59, which
  Jochebed's own record cites, states that she was born to Levi. This is
  the file contradicting a verse it points at, and it is the classic
  compression problem in the Egyptian genealogies rather than a typo.

The distribution is the reason none of this is repaired. The 290 gaps
cluster hard at 20, 25, 26, 30, 35, 40 and 90, with genuine Genesis 5
and 11 gaps running to 500. Only **4 fall below 15**. This is a small
set of outliers in a reconstruction, not a broken generator, and any
replacement year would be invented — which is the one thing this
document has never done.

### 36c1 — three names that appear in no Bible we ship

The first real defect. Of 277 printed English names, **274 stood in a
passage the record itself cited**. Three did not, and the reason is not
a spelling variant:

| Printed | `bsb` | `nasb` | `leb` | `kjv` | `kjv+s` | Occurrences of the printed form in all five |
| --- | --- | --- | --- | --- | --- | --- |
| `Melki` | Melchi | Melchi | Melchi | Melchi | Melchi | **0** |
| `Josek` | Josech | Josech | Josech | Joseph | Joseph | **0** |
| `Joshua / Jose` | Joshua | Joshua | Joshua | Jose | Jose | **0** |

`Joshua / Jose` is not a misspelling at all — it is **two editions'
spellings of one man joined by a slash**, an editorial note left in a
field the app prints verbatim.

Which spelling to keep was measured, not chosen. Of the **39 people in
the Lukan chain, 11 carry a name only `bsb`/`nasb`/`leb` print and
exactly 1 carries a name only the `kjv` prints**. The file's English is
the modern critical text, 11 to 1, so `Melchi`, `Josech` and `Joshua`
follow the file's own convention rather than this reader's taste.

`Melki` had a second witness inside the file. The other man of that name
is already called **`Melchi (II)`** — so the record being repaired is
the `(I)` that convention was written for, and an English reader
previously could not see that the two entries were the same name. The
Chinese had it right all along: 麦基 and 麦基（二）.

`Janna` is the one KJV-only name, and it is **deliberately not touched**.
The `kjv` and `kjv+s` do read "Janna" at Luke 3:24, so the name is
witnessed by a Bible the app ships. Changing it would be a consistency
preference, not an accuracy repair, and the standing rule is about what
is true.

### 36c1, the Chinese half — 10 absences, reported and not repaired

The app prints two names for every person and its readers are Chinese,
so checking only the English would be checking the smaller half. The
witness is the CUV, joined to the English editions on the numeric `id`
every shipped record carries — a join proved before it was believed:
**31,086 of 31,086** `bsb` verses join, and John 3:16, Luke 3:24 and
Genesis 5:3 land exactly.

**Exact containment only.** An edit-distance test over two- and
three-character names is known in this repository to produce
overwhelming noise; either the characters are in the verse or they are
not. **267 of 277** Chinese names stand in a verse their own record
cites. The 10 that do not:

| Person | Tree | CUV at the cited verse |
| --- | --- | --- |
| Reuben | 吕便 | 流便 (Genesis 29:32 and 84 more; 吕便 occurs **0** times) |
| Hezron (Reuben's son) | 希斯仑 | 希斯伦 (Genesis 46:9) |
| Ziphion | 洗非芬 | 洗非 (Genesis 46:16) |
| Muppim | 姆平 | 母平 (Genesis 46:21) |
| Semein | 西美音 | 西美 (Luke 3:26) |
| Josech | 约瑟克 | 约瑟 (Luke 3:26) |
| Joda | 约大 | 犹大 (Luke 3:26) |
| Elmadam | 以摩太 | 以摩当 (Luke 3:28) |
| Eliezer (Lukan) | 以列以谢 | 以利以谢 (Luke 3:29, and 13 more) |
| Menna | 米拿 | 买南 (Luke 3:31) |

**None of these is repaired**, and the reason is that eight of them are
an editorial *policy* rather than an error. The CUV follows the Textus
Receptus through Luke 3 and therefore reads a **different name** at
those verses, not a different spelling of the same one; the tree
transliterates the modern critical name instead, which is exactly what
its English does. Telling those apart from the two that look like slips
is a translation judgement, and two were taken as far as they can be
taken without one:

- **Reuben 吕便.** 吕便 occurs **0 times** in the CUV and 流便 occurs
  **85**. But 吕便 is a real rendering in other Chinese versions, and it
  is the file's own majority — 6 occurrences against 2. The 2 are the
  sharp part: `hezron_reuben` is named 希斯仑（**流**便之子） while its own
  summary reads 吕便的儿子. **One record says both.** Whichever way that
  is settled, it is a translation-tradition call and the highest-value
  minute a human could spend on this file.
- **Eliezer (Lukan) 以列以谢.** 0 occurrences in the CUV, against 14 for
  以利以谢 — which is the standard rendering, is what Luke 3:29 (this
  man's only reference) actually reads, and is already carried by the
  file's other Eliezer. It looks like a one-character slip, 列 for 利.
  It was left alone anyway, because the file does **not** disambiguate
  duplicate Chinese names elsewhere (玛拿西 and 以利亚撒 each appear twice,
  identical), so "it must be a deliberate coinage" cannot be ruled out
  from inside the file.

### 36c2 — 338 relationship claims, graded by what states them

Each parent-child and marriage claim was scored by the strongest passage
that supports it, across all five editions:

| Tier | Rule | Before repair | After |
| --- | --- | --- | --- |
| 1 | one verse names both people **and** carries a kinship word | 298 | **302** |
| 2 | same chapter, both named within 4 verses, kinship word in the span | 31 | **31** |
| 3 | no passage in five editions states it | 9 | **5** |

The four that moved were **predicted before the repair was applied**:
they were the `Melki`/`Josek` edges, invisible to the instrument only
because the name it was searching for existed nowhere. Repairing the
names witnessed them. That the count moved by exactly four, and by those
four, is the check on the instrument rather than a separate finding.

The 5 that remain are **not** a list of errors. They are the tree's
inferred links, and they are the most interesting thing in this check:

- **Heli → Mary.** The record's own summary already says "the
  traditional reading where Heli is the father-in-law of Joseph and
  biological father of Mary". Luke 3:23 does not say it.
- **Eve → Seth.** Genesis 4:25 says Adam knew "his wife" and she bore
  Seth. It does not name her in that verse.
- **Ahinoam → Ish-bosheth**, **Maacah → Tamar** — inferred from
  "sister", "his son", and the surrounding lists.
- **Bathsheba → Shammua** is a different thing and belongs under
  instrument limits: 2 Samuel 5:14 and 1 Chronicles 3:5 spell the same
  son **Shammua** and **Shimea**, and no single verse names mother and
  son together in either spelling.

**The finding is not the five links. It is that the data model has no
way to mark a link as inferred.** `mary.fatherId = "heli"` renders as a
solid line indistinguishable from Adam → Seth, and the qualification
that exists lives in a prose summary the tree view does not show. This
is a product decision — a new field, and a way to draw it — and it is
reported rather than taken.

### Instrument errors, recorded because they nearly became findings

1. **The sign convention, which produced 325 false findings.** `bc`
   years are stored **negative** and AD positive (Jesus is `b = -4,
   d = 30`), so both year systems run in the same direction and a
   lifespan is `death - birth` under both. The first chronology run used
   `birth - death` for `bc` and inverted every comparison, reporting **35
   lifespan or death-before-birth issues, 218 parent/child order issues
   and 72 parent-died-first issues**. All 325 were artifacts. Nothing
   from that run reached this document; the real numbers are the 8 above.
2. **A throwaway probe used `rstrip("'s")`**, which strips any trailing
   apostrophe or `s` rather than the suffix, and reported that "Judas"
   appears in no edition. The tool's own `norm_token` was correct; only
   the probe was wrong. The probe was not the instrument, which is the
   only reason it did no damage.
3. **Multi-word names could never match a token.** `Ahinoam of Jezreel`
   and `Joshua / Jose` are descriptions, not words a verse prints, and
   made 5 people look unnamed. Dropping trailing `of …` / `the …`
   phrases and splitting on the slash took the unnamed count from 5 to 3
   — and the slash, which the fix was written to tolerate, turned out to
   be one of the defects.
4. **The first version read 2 editions and required one verse**, which
   produced **48 tier-3 claims**. Calibrating against Genesis 4:18,
   4:20-21 and 4:25 showed the misses were a genealogy naming the father
   once and listing his children over the following verses, so the
   instrument was widened to five editions and a ±4-verse same-chapter
   window. Tier 3 fell from 48 to 9.
5. **Exact containment can match inside a longer name.** 米拿 occurs 25
   times in the CUV, but as a substring of 亚米拿达 (Amminadab), not as a
   name. So **267 of 277 is an upper bound** on the Chinese names
   witnessed, not an exact count. The 10 absences are exact; the 267 is
   not.

### The instrument limit that matters most

The check surfaces only claims that **no passage states within the
window**. An inferred link whose two people happen to be named a few
verses apart in a chapter with a kinship word in it scores tier 2 and is
invisible here. **A complete census of the tree's inferred links is
therefore not possible with this instrument**, and the 5 above are a
lower bound, not the total. Anyone acting on the "mark inferred links"
finding should treat the tier-2 set of 31 as unreviewed.

### What was deliberately NOT changed

- **Every year.** The 4 impossible gaps, the Levi/Jochebed
  contradiction and the 3 seam edges are all reported and none is
  repaired, because every replacement value would be invented.
- **Every Chinese name**, for the reason given in 36c1 above.
- **`Janna`**, which a shipped edition witnesses.
- **The five inferred links**, which are the model's gap and not the
  data's error.
- **`_meta.description`'s coverage claim** — "the canonical Adam → Jesus
  line per Matthew 1 + Luke 3" — was read and not tested. The Lukan
  chain's 39 names were read against Luke 3:23-31 in all five editions
  and are in the right order; Matthew 1 was not put through the same
  programmatic comparison and should not be assumed.

### Frozen

`test/family_tree_names_test.dart` — six tests. The three repaired names
by exact value; the asset's `corrections` block must record all three;
no displayed name may contain a slash; every record's references must
still resolve to at least one verse; **every English name must appear as
a whole word in some shipped edition of some verse the record itself
cites**; and the set of 10 Chinese names absent from the CUV is frozen
by id, so the debt can shrink but cannot grow or move.

The English rule is the one with a future — it fails on a name nobody
has thought of yet — and it is enforced with no help at all: no spelling
aliases, no near-miss allowance, and no credit from a verse the record
does not point at. **276 of 277 pass it.** The single exemption is
`Jude`, whose only two references (Matthew 13:55, Mark 6:3) list the
brothers of Jesus and spell him "Judas" or "Juda"; every English Bible
calls the epistle's author Jude, and renaming him Judas would put him
next to Iscariot.

The references are resolved with the app's own `parseReference`, not a
reimplementation of it, so the test asks the question the app asks. That
also made it an independent second instrument: it reproduced the Python
tool's counts exactly, including all 10 Chinese absences.

Against the pre-repair asset three of the six tests fail, and the
general rule names `Melki` and `Joshua / Jose` without being told to.

### Still open

- **The tree has no way to say "inferred".** Reported above; a product
  decision.
- **The 31 tier-2 claims are unreviewed**, and the inferred links among
  them cannot be separated by this instrument.
- **The 10 Chinese names**, of which Reuben's 吕便/流便 split — present in
  a single record — is the one worth a human minute.
- **Matthew 1's chain** has not been compared programmatically the way
  Luke 3's was.
- **The 4 impossible gaps and the Levi/Jochebed contradiction**, which
  need a chronology decision rather than a repair.

---

## Check 37 — the claims the book-intro card makes *above* the text

`assets/book_introductions.json` is the last curated asset this document
listed as unchecked. It holds **66 records**, and when a book opens at
chapter 1 the reading pane renders one of them as a collapsible card
*above the first verse* — subtitle, summary, author, date, audience,
themes, and a key-passage spotlight, in English, 简体 and 繁體.

That position is the whole problem. Everything else this document has
checked is a label on a passage; this is a paragraph a reader meets
**before** the text, in the app's own voice, and most of its sentences
are not devotional. They are countable: *five acrostics*, *fourteen
times*, *the shortest book*, *the longest prophetic book*, *the only
book that never names God*. Each of those is a claim the shipped corpus
can answer, and a reader has no way to check any of them without leaving
the card.

Two instruments, both read-only: `tools/audit_book_intros.py` for the
structural and numeric claims, `tools/audit_book_intro_quotes.py` for the
quotations. Neither consults anything outside this repository. The first
reads the app's own `lib/constants/book_name_mapping.dart` for the book
table, so it cannot disagree with the app about what a book is called.

### 37a–37c — the references: 0 findings in 66 records

Every `keyPassage` **resolves** to a passage that exists; every one names
**its own book**; no chapter number **overruns** the book. Reported first
because zero is the result: the spotlight reference is sound in all 66,
and check 25 had already proved the weaker claim that the string parses.

One flag is raised and is not a finding. Lamentations' spotlight is
3:22-23, and `lxxwh` has no verse there — its chapter 3 carries 62 of 66,
missing 22, 23, 24 and 29. That is one of the 302 Septuagint absences
check 29 catalogued and check 30 classified, and since v1.6.116 the row
says "this edition has no verse here" rather than rendering as nothing.
The reference is sound in every edition that has the passage.

### 37d — the quotations, against the passage they are attributed to

59 of the 66 records print a **quotation of scripture** inside
`keyPassageDescription` and name the `keyPassage` as its source. The card
renders both, one under the other, so every one of those screens asserts
*these words are in that passage*.

The test cannot be string equality — the quotations elide with `…` and
are the author's own rendering, not any one edition. It is a **ranking**:
score the quotation against every verse of five English editions (`bsb`,
`kjv`, `kjvs`, `leb`, `nasb`) or the three CUV-family editions, IDF-
weighted cosine over tokens and bigrams, one token per Han character;
then ask what the **named** passage scores. Scoring against five editions
is what makes a low score mean "no edition we ship says this" rather than
"this edition words it differently".

**137 quotations scored, 0 misattributed.** The weakest reading is 2
Samuel's "Son of David", which scores 0.000 and is not a defect: it is an
epithet the card names, not a sentence it quotes.

The rule that had to be corrected before any of this was believed:

> A quotation is **not** suspect merely because some other verse scores
> higher. Scripture quotes itself. Matthew 21:5 *is* Zechariah 9:9;
> Romans 1:17 and Hebrews 10:38 both quote Habakkuk 2:4. The only
> evidence of misattribution is that the **named** passage does not
> contain the words, in absolute terms. The best-scoring verse elsewhere
> is context for a human reading a flag, never the trigger.

### 37e — the countable claims: 5 false, all fixed

These are the findings. Each was verified against the shipped corpus
directly, and each is now pinned by a test that derives the number from
the text rather than restating the string.

- **Lamentations — "Five Acrostic Dirges".** Chapter 5 is not an
  acrostic. Its 22 verses open with only **11 distinct letters** (ז נ י
  מ ע מ א ע ב ע נ ש ב ז ש נ ע ע א ל ה כ), missing 11 of the 22; chapters
  1–4 each walk the full alphabet. The app **already contradicted
  itself** — `bible_trivia_page.dart` ships "Five poems, four are
  alphabetic acrostics" with `brokenChapters: [5]`. Now: "Five Dirges
  Over Fallen Jerusalem, Four of Them Acrostics".
- **Philippians — "the word 'joy' appears 14 times".** No edition the app
  ships prints it more than **7** (bsb 5, kjv 6, kjvs 6, leb 5, nasb 7);
  Chinese 喜乐/喜樂 is 12. 14 is reachable only in the Greek, and only by
  counting χαρά (5) and χαίρω (9) while dropping συγχαίρω (2) without
  saying so. The whole family is **16**, which a reader can confirm in
  the app's own concordance. Now stated as the Greek, at 16.
- **Obadiah — "The Bible's Shortest Book".** False on every metric. 2
  John has 13 verses to Obadiah's 21; 3 John has **218** original-language
  words to Obadiah's **285**. Obadiah *is* the shortest book of the
  Hebrew Bible, and the subtitle now says so.
- **3 John — "The shortest book in the Bible".** Directly contradicted
  the Obadiah card, so one of the two was wrong on any reading. This one
  is true, but only by original-language word count, which the card did
  not state. Now: "Counted in the original languages…".
- **Isaiah — "the longest and most quoted prophetic book".** Jeremiah is
  longer on all three measures: **1,364 verses to 1,292**, 39,741 BSB
  words to 34,089, and **21,580 Hebrew words to 16,672**. Isaiah leads
  only on chapters (66), which is what the summary now says. *"Most
  quoted" was checked separately and is true* — in
  `assets/cross_references.json`, New Testament verses point at Isaiah
  **2,601** times against Jeremiah's 1,041, and Isaiah is the most-cited
  prophetic book by a wide margin — so that half is kept.

### The claim that survived, and why it is recorded

**Esther — "the only book in the Bible that never explicitly names
God".** A subagent reported this false. It is true, and the measurement
is why the verdict was reversed: across `assets/originals`, counting the
divine names in the Hebrew itself by Strong's number, **Esther is 0**.
Song of Songs has exactly **1** — the `יָה` inside שַׁלְהֶבֶתְיָה at
8:6 — and the next book up is Obadiah at **8**, so the gap between
Esther and the rest of the Hebrew Bible is not a near miss. The claim
stands unchanged. Recorded here because the next person to read that
sentence will doubt it too.

### The regression trap found on the way out

`scripts/build_book_introductions.py` is the declared source of the
asset, so the five corrections were mirrored into it. Comparing the two
structurally then showed the generator had **already drifted from the
shipped asset in 36 fields across 21 books** — 34 occurrences of the
divine name (`耶和华` where the asset ships `雅伟`) and a partial pronoun
pass (`祂`→`他`) in 4 fields. Running the generator would have silently
reverted every one of those house-policy corrections. It was brought back
into step, verbatim, preserving the asset's own choices rather than
imposing new ones — including the Colossians summary, which keeps `祂` in
one clause and not the other. The generator now reproduces all 66 records
exactly, and a test pins that.

### Instrument limits, stated rather than counted as findings

The tool ends on **48 flags**, and after the repairs above **47 of them
are one sub-check that cannot discriminate**:

- **The locale number-parity sub-check.** It compares the digits in each
  locale of a field and raises 47 flags, nearly all English number-
  *words* ("one", "seven") with no digit in the Chinese. Reported as a
  limit, not as 47 findings. The 48th is the `lxxwh` absence above.
- **Five instrument defects were fixed before any result was believed**,
  and every one had produced confident false findings. A missing 兩 in
  the Chinese numeral table produced 7; a careless `(\d+)\s+verses?`
  produced 3 false Lamentations findings; an English possessive of a
  name ending in *s* (`Jesus'`) opened a quotation span that closed at
  the next real opening quote, handing the scorer 38 words of the
  author's own prose to score against Acts 1:8. Two more were found by
  re-running the tool against the *corrected* asset, which is the only
  way they could have surfaced:
  - the word-frequency check counted a claim the card **scopes to the
    Greek** against the Chinese editions, where the quoted term is a
    gloss — 「喜乐、欢喜」 for χαρά/χαίρω/συγχαίρω — that no Chinese
    edition contains as written. It now skips claims scoped to the
    original language, which `assets/originals` witnesses instead;
  - the acrostic check flagged any book containing a non-acrostic
    chapter, so it could not tell "Five Acrostic Dirges" from "Four of
    Them Acrostics". It now reads the number the card claims and
    compares it with the number the Hebrew has.
- **The histogram in the quotation tool double-counted.** Its bins
  overlapped above 0.5; they are contiguous now and sum to 137.

### Still open

- **1 Peter's "sojourners"** appears in no shipped edition of 1 Peter
  except the KJV's "sojourning" at 1:17. Defensible about the Greek,
  unverifiable in the app; left.
- **Mark's "favorite word is 'immediately'"** ranges 13–40 by edition.
  Defensible about the Greek εὐθύς; left.
- **Jeremiah's "forty years"** against its own date field of 627–582
  BCE. A round number in normal usage, not a false claim; left.
- **The un-countable claims are unchecked.** "The most detailed prophetic
  portrait of the suffering Servant" is not the kind of sentence any
  instrument here can weigh, and roughly half of every summary is that
  kind of sentence.

---

## Check 38 — the ordinal that was said to separate two cities

This one was not on any list. It came out of #320, which asked whether
the picture database could be joined to the gazetteer, and the join's
first question — *what exactly is a place record allowed to claim?* —
turned out to have a false answer already shipped in the app's own source.

Two files said it. `lib/pages/atlas_page.dart` opened by naming the thing
the Atlas does better than BibleWorks' Find Place window:

> It cannot tell Syrian Antioch from Pisidian Antioch. […] The gazetteer
> carries a curated per-site reference list with the disambiguating
> ordinal, so `Antioch 1` and `Antioch 2` answer separately and correctly.

`lib/utils/atlas_index.dart` made the same claim in its own words. Both
were written from the *shape* of the data — the ordinal exists, each
entry has its own `refs` array — and neither was ever measured.

### What the gazetteer actually carries

Measured through `parseGazetteer`, so every repair the app applies is
applied first. **80** groups of entries share a name and carry a
disambiguating ordinal. Of those:

- **66 groups, 131 entries, carry byte-identical reference lists.** Not
  similar — identical. `Antioch 1` and `Antioch 2` have **18 references
  each and they are the same 18**. Bethany 1 and Bethany 2 likewise.
- **14 groups differ**, and **all 14 still overlap** — every one has at
  least one reference filed under two of its own members. They are
  Aphek, Aroer, Beth-shemesh, Debir, Etam, Hazor, Kedesh, Mizpah,
  Mizpeh, Ramah, Ramoth, Rehob, Rimmon and Tabor.

So **not one of the 80 groups partitions its references cleanly**, and
the sentence "answer separately and correctly" was false for all of them.
What the ordinal records is that two *sites* exist. It does not record
which verse belongs to which, and no amount of reading the asset will
make it.

### Why nothing was repaired

Deciding that Acts 11:19 means Syrian Antioch and Acts 13:14 means
Pisidian is real scholarship, and hand-filing 131 entries' worth of it
would be inventing a source the app does not have. The claim is withdrawn
instead — see check 27's rule, which this is the fourth instance of.
`atlas_page.dart` and `atlas_index.dart` now say what is true: the
gazetteer separates the *sites*, prints both, and leaves the reference
list shared, which is still strictly more than a text search for the
spelling can offer.

### 38b — the #320 join, measured before it was promised

The ticket made the feature conditional on the measurement, so: of four
candidate joins, the one that shipped is *the place's English name as a
whole word in the plate's English title or description, gated by the
plate's declared chapter range covering a verse that names the place*. It
reaches **79 of 1,271 places, 218 pairs, 149 distinct plates** — a join
rate of **6.2%**, and all 218 pairs were read by hand.

The rejected alternatives are worth the space, because three of them look
better on paper:

- **Chapter overlap alone** reaches 100% of the gazetteer and 17,177
  pairs, and is nonsense: it puts four *Valley of Hinnom* plates on
  **Ziph**, *The Creation of Eve* on the **Tigris**, and *Peter's Vision
  at Joppa* on **Caesarea**.
- **Matching the Chinese names** would add 13 places and 80 pairs and
  cannot be made safe: Han text has no word boundary, 撒冷 (Salem) is
  inside 耶路撒冷 (Jerusalem), and 埃及 (Egypt) is inside 出埃及记, which
  is simply the Chinese name of Exodus.
- **Adjectival forms** (`-n`/`-an`/`-ian`) would catch "a Samaritan
  woman" and would also turn `Cana` into `Canaan`.

Because the ordinal does not survive the join, the strip's header reads
"illustrations naming it" and not "pictures of it". That wording is the
finding above, spent.

### The guard the measurement forced

Running the name rule with the chapter gate **removed** showed how much
the gate was silently carrying. The gazetteer's **On** — the Egyptian
city of Genesis 41 — is a whole word in **51** captions, because `on` is
an English preposition. **Adam** is a town in Joshua 3:16 and a man in 10
captions; **Ham**, **Esau**, **Laban**, **Rahab**, **Abel** and **Tamar**
are all towns and all people. Today the gate rejects every one of those
matches, which means the feature was correct *by luck*, and one new plate
covering Genesis 41 with the word "on" in its caption would have ended
that. 21 such names are now refused outright by
`kAmbiguousPlaceNames`, which costs nothing — the shipped 79/218/149 is
unchanged — and `test/place_illustrations_test.dart` pins both facts.

Deriving that set from the app's people data was rejected: Midian,
Ephraim, Canaan and Sheba are each a person in scripture as well as a
place, and all four are in the verified 218 with plates that plainly mean
the place.

### Instrument errors, recorded because they nearly became findings

- **The ASCII word boundary.** The first matcher used
  `(?<![A-Za-z])…(?![A-Za-z])`, under which the town of **Dor** is a
  whole word inside **Doré** — `é` is not in `[A-Za-z]`. That single slip
  attached **145** Doré plates to one small town. The rule is now
  `\p{L}`/`\p{N}` with `unicode: true`.
- **Python over the raw asset, twice.** A throwaway probe reported 151
  distinct plates where the Dart says **149**, and reported that 9 of the
  14 differing ordinal groups overlap where the Dart says **all 14**.
  Both were run again through `parseGazetteer` and `BibleMap.fromJson`
  and both python numbers were wrong, in the direction that would have
  understated the finding. This is the third check to record the same
  lesson: rules live in the parser, not in the asset.
- **Counting places by name where the join counts ids.** The scope
  measurement below first came back **48** and was written down as such;
  the same measurement keyed on `id` — the unit the 79 uses — is **56**.
  Nothing was wrong with either count, only with reporting one in the
  other's denominator. It is the same ordinal collision this check is
  about: `Ai 1` and `Ai 2` are two entries and one name.

### 38c — a scope could empty the strip in silence

Found on the deployed build while verifying 38b, and fixed in the same
release. The strip rendered nothing when the join was empty, which is
right for the 1,192 places that have no plate — but `atlasIndex`'s book
scope also empties it, and there the same silence says "no picture of
this place exists" about a place that has several.

The size of it: **292** (place, book) pairs across **56 of the 79**
joined places have a scope under which every plate falls away. So more
than two thirds of the feature's surface had a filter that could make it
lie by omission. `Ai` scoped to Genesis, Ezra, Nehemiah or Jeremiah
showed nothing while three plates existed; `Asia` scoped to Romans hid
four.

The panel now prints the header alone, reading `0 / 3`, and drops only
the thumbnails. That is the #319 rule the file's own doc comment had
already committed to — *a scope that silently subtracts leaves a reader
unable to tell "no plate in Obadiah" from "no plate anywhere"* — applied
to the surface that introduced it.

### Frozen

`test/place_illustrations_test.dart` holds the join rate (79/218/149),
the name and chapter halves as separate rules, the Doré boundary, the
scope partition, the 292/56 the `0 / n` header exists for, and the
assertion that `Antioch 1` and `Antioch 2` get identical strips — so the
day the gazetteer learns to tell them apart, that test fails and the
prose above gets revisited.

### Still open

- **Which Antioch is which** — and the same for 79 other names. Needs a
  source the repo does not have.
- **The join's recall is unmeasured.** 6.2% is what the rule *finds*; how
  many plates genuinely depict a gazetteer place and go unjoined because
  the caption names a person instead ("The Woman at the Well") is not
  something any instrument here can count.
- **Chinese captions are not searched at all**, so a reader in 简体 sees
  a strip built entirely from English text. Correct, but asymmetric.

---

## Check 39 — the Septuagint's 302 absences, and which of them are not absent

This is "Next, in order" item 2. Check 29c had found the class by
example and said so out loud — *"found by example, not measured — two
known, count unknown"* — and named two: English Psalm 13:6's Greek
inside our 13:5, and Psalm 116:14's inside our 116:13. A merge is a
reference the *English* tradition creates by dividing a verse the Greek
does not; nothing is lost, and the row saying "this edition has no
verse here" is pointing a reader away from words that are one line
higher.

**One of the two named examples is false**, and the file itself says so.
Our Psalm 116:13 is `<vs:115:4>ποτηριον σωτηριου λημψομαι…` and nothing
else; 116:15 opens at `<vs:115:6>`. The edition's own numbering names a
Greek 115:5 between them and **no record in the file carries it**. The
Septuagint has that verse. Our copy of it does not. That is not a merge
and not a minus — it is a gap, and it is the one kind of finding the
markers can establish without any outside text at all.

### The instrument, and the two ways it was wrong first

`assets/lxxwh.json` is keyed in **English** versification and carries
4,543 `<vs:c:v>` markers giving the edition's own number wherever the
two disagree. That is an internal witness to the Greek's numbering, and
the first attempt read it as a witness to the Greek's *content*. It is
not, and the error was made twice.

1. **The parser dropped implicit numbers.** A record whose text does not
   *open* with a marker carries its own reader key as its first source
   verse; a marker later in the text begins a **new** source verse
   mid-record. Taking only the markers manufactured phantom holes —
   Acts 3:19, 3 John 1:14, Acts 13:32, Acts 24:2, 1 Thessalonians 2:6
   and 2:11, 2 Chronicles 27:8. With the implicit key restored the New
   Testament has exactly **one** hole, Matthew 12:47, which check 34d
   already knew about. Corpus totals: 30,800 records, **31,004** distinct
   source references, **11** claimed twice.
2. **Continuity of numbering does not prove a merge.** 19 absences had
   the Greek's numbers running straight across them, and reading the
   Greek refuted **18**. Greek Exodus 36–40 is a shorter, *reordered*
   tabernacle account: reader 37:3 is `<vs:38:3>`, reader 37:5 is
   `<vs:38:4>`, and English 37:4 — "he made staves of shittim wood, and
   overlaid them with gold" — is simply not in the Greek. The same for
   Exodus 28 and 38, 1 Kings 7 and 9. Contiguous numbering proves *our
   file lost nothing from the edition*. It says nothing about whether
   the English verse's words are next door.

So the class cannot be measured from numbering at all, which is exactly
what check 29c meant by "needs content alignment against an English
text". No such alignment exists here: the external LXX witness check 29
used is keyed by the **English** reference, so it shares the collapse
and cannot see through it, and the tagged layers cannot be joined
because the Septuagint's Strong's numbers are Greek and the Old
Testament's English witnesses are tagged in Hebrew.

### What was done instead

Length. A merged record holds two English verses' worth of Greek. For
each absence, the preceding record it would have to be hiding in was
measured against what its **own** English verse predicts, at that book's
Greek:English character ratio, and against what its own verse *plus* the
absent one predicts. Three independent nets, and their union read one
at a time against the KJV:

| Net | Fires | |
|---|---|---|
| Per-**book** ratio, merged fits better than single | 31 | |
| Per-**chapter** ratio, same test | 32 | contaminated by the merges themselves, which is why it is a second look and not the primary |
| Preceding record carries an **interior** `<vs:>` marker | 5 | the record explicitly holds two Greek verses |

**55 references read. 7 are merges.** They are now
`kEditionMergedHeads` in `lib/utils/verse_text_absence.dart` — a list,
because a rule that found them would be a rule that guessed:

| Absent | Printed inside | The clause |
|---|---|---|
| Exodus 38:5 | Exodus 38:4 | και επεθηκεν αυτω τεσσαρας δακτυλιους εκ των τεσσαρων μερων |
| Exodus 40:31 | Exodus 40:30 | μωυσης και ααρων και οι υιοι αυτου τας χειρας αυτων και τους ποδας |
| Exodus 40:32 | Exodus 40:30 | εισπορευομενων αυτων εις την σκηνην του μαρτυριου … καθαπερ συνεταξεν κυριος τω μωυση |
| 1 Kings 4:28 | 1 Kings 4:27 | και τας κριθας και το αχυρον τοις ιπποις |
| 1 Kings 9:21 | 1 Kings 9:20 | τα τεκνα αυτων τα υπολελειμμενα μετ αυτους εν τη γη — verbatim |
| Psalms 13:6 | Psalms 13:5 | ασω τω κυριω τω ευεργετησαντι με |
| Isaiah 64:1 | Isaiah **63**:19 | εαν ανοιξης τον ουρανον … ορη και τακησονται |

Isaiah 64:1 is the cleanest of the seven and the only one a marker
attests: our Isaiah 64:2 opens `<vs:64:1>`, so the Greek's chapter 64
begins one verse later than the English one, and English 64:1 can only
be the tail of Greek 63:19 — which is where it is. It is also the only
head in a **different chapter**, so the row says "printed with an
earlier verse" and refuses to print "19" beside a 64:1 reference.

The bar is the **whole** English verse. Eight more absences have part of
theirs in the preceding record and are deliberately not claimed —
Exodus 28:24, 28:25, 37:14, 37:22, 38:7, 39:35, Joshua 20:6 and
1 Kings 9:19. Greek Exodus 39:14 has the ark of the covenant and its
staves but not the mercy seat, so "printed with verse 34" is a promise
the row cannot keep for English 39:35.

### What the instrument cannot see, stated as a number

167 of the 302 have a preceding record **no longer** than its own
English predicts; a merge cannot hide in those. 135 are longer, and the
55 where a merge fits the length better than a minus were read. The
remaining 80 sit in a band where the excess is smaller than the absent
verse would need — real, but not large enough to be a second verse. A
merge whose Greek is compressed enough to fall in that band would be
missed, and nothing here rules one out.

Nothing was repaired. Psalm 115:5 could be *written* — the Septuagint's
115:5 and 115:9 are the same line, and we carry 115:9 at English 116:18
— and that is precisely why it was not. Check 34d set the precedent for
the New Testament's Matthew 12:47: importing Greek into one layer of two
is a decision about what the product contains, and is the owner's.

### Results

| Question | Measured over | Found | State |
|---|---|---|---|
| Absences of `lxxwh` against the KJV extent | 30,800 records | **302** (301 OT + Matthew 12:47) | unchanged since check 29's repair |
| Merges — the English verse's words are in an earlier record | 302 absences, 55 read | **7** | now named, and the row says so |
| Partial — some of the verse is there | 302 | **8** | reported, deliberately **not** claimed |
| Source verses the edition's own markers name and we do not carry | 30,800 records | **153**, at 32 sites | reported, not repaired |
| Source references claimed by two reader records (a Greek verse split across two English ones) | 31,004 | **11** | correct, the reverse of a merge |
| Check 29c's second worked example | 1 | **false** | corrected below |

`test/lxx_merged_reference_test.dart` holds all of it down: each entry
must name a reference we lack and a head we have, each head must still
contain the clause quoted above, the eight partials and the refuted
candidates must stay unclaimed, and the corpus must still hold exactly
302 absences of which 7 are explained.

### Correction to check 29c

Its first example stands: English Psalm 13:6's Greek is in our 13:5. Its
second does not — English Psalm 116:14's Greek is **not** in our 116:13,
and the reference is a gap in our file rather than a feature of the
Greek. Its closing sentence, "the shipped row makes the weakest true
claim, which is correct for both classes", is now wrong for 7 of the
302 by design and remains right for the other 295.

---

## Check 40 — the Biblical Evidence Archive's own words

`assets/bible_evidence.json` is 225 archaeological, manuscript,
scientific and historical entries, migrated from a standalone
Vite/React/TS project (bible-evidence.netlify.app) and refreshed at
runtime from yswords-data. It was one of the two assets still named
under "Not checked yet". Check 25 had already verified that its 225
scripture references resolve; nothing had ever read what it *says*.

Repaired by `tools/repair_evidence_archive.py` (idempotent; it converts
nothing by default and asserts a count for every rule it applies), and
guarded by `test/bible_evidence_language_test.dart`.

### 40a — 152 strings that were UTF-8 read back as Latin-1

The migration wrote UTF-8 bytes and read them back as Latin-1, so every
non-ASCII character became two or three wrong ones. **152 strings in
111 of the 225 records**, all in fields the detail page prints as fact:

| field | strings | what a reader saw |
|---|---:|---|
| `academicSources` | 93 | `AndrÃ© Parrot`; `IEJ 35 (1985): 22â<80><93>27` |
| `timeline` | 27 | `9thâ<80><93>8th Century BCE` |
| `discoveryDate` | 26 | `1868â<80><93>1870` |
| `location` | 6 | `MusÃ©e du Louvre` |

The largest share is inside `academicSources` — the archive's own
evidence for its claims, so its scholars' names and page ranges were
the least readable part of it.

**The gate matters more than the repair.** The damage is deterministic
and exactly reversible (`s.encode('latin-1').decode('utf-8')`), but a
blanket attempt would corrupt legitimate text. Decoding is attempted
only for a signature that cannot occur in real text: a **C1 control**
(U+0080–U+009F, unassigned in any legitimate string; shown as
`<80>` above) or `Ã`/`Â`
followed by a UTF-8 continuation byte. **131** of the 152 carry a C1
control; the other **21** are the `Ã`-mangled accented Latin with no
control byte. Every repair is asserted to remove the signature, so
nothing is double-decoded — measured, **0** strings needed a second
round and **0** were unfixable.

### 40b — 209 of 225 records served Simplified Chinese as Traditional

Each record carries `{en, zh-Hans, zh-Hant}` for title, summary,
description and scripturalCorrelation, and `BibleEvidence.localizedTitle`
serves the locale key straight through. **209 of the 225 records held
the Simplified string in the `zh-Hant` slot** — 207 of them in all four
fields, byte for byte. A 繁體 reader was reading 簡體 and being told it
was their edition. **836 fields** were regenerated.

**The detector is byte identity, not a character test.** If `zh-Hant`
holds the very same string as `zh-Hans`, no conversion ever ran. That
splits the corpus exactly — 209 records, and the other 16 (a contiguous
block, added later) have no identical field at all. A per-character
detector gets this wrong, because opencc maps 里 to 裡 *by default*
while 里 is perfectly good Traditional in 公里 and in every
transliterated name; the same is true of 占 岩 征 托 干 后 准 游 岳. Two
of the 209 have one field that is not identical, and the difference is
a single character — 雅偉 for 雅伟, the divine name patched by hand into
otherwise Simplified prose. They are converted whole, so no record ends
up half in each script.

The 16 already-Traditional records are **left alone**: they were
machine-converted too, but where their text differs from what the
conversion would produce, the existing reading is the better one
(卷 not 捲, 讚 not 贊, 鏟除 not 剷除).

**Why `s2tw`.** It is the Taiwan character standard *without* vocabulary
substitution; `s2twp` would also rewrite the author's word choices,
which is not ours to do. It leaked no 舊字形 into this corpus (麪 裏 説
喫 衆 爲 all zero), and it matches the app's own 繁體 voice (`ui_strings`
writes 裡 16 times and 裏 none).

**The instrument that finds opencc's wrong choices.** A round trip
cannot see them: `t2s(隻有) == 只有`, so a wrong choice round-trips
perfectly. What does see them is an **override diff** — convert the
corpus's 2,313 distinct Han characters *one at a time* to get opencc's
context-free opinion, then diff that against the full-text conversion.
Every difference is a phrase-dictionary decision, and that is where the
errors live. It found **792 overrides in ~70 classes**. Each class was
read with its contexts, and **42 rules** were written, each one refuted
by the app's own shipped Traditional editions (`cuvs-yhwh-tr.json` +
`biblexg-v2-tr.json`, 32k verses):

| what opencc wrote | what it has to be | n | the witness |
|---|---|---:|---|
| 髮掘 髮明 髮生 髮表 | 發掘 發明 發生 發表 | 11 | only 髮型/頭髮 are hair |
| 昇天 | 升天 | 11 | 升天 18 / 昇天 0 |
| 闡明瞭 | 闡明了 | 10 | 了 is the aspect particle |
| 馬裡 泰勒裡邁 瑪裡卜 …9 names | 馬里 … | 28 | 里 is every transliteration |
| 曆史 | 歷史 | 6 | 歷史 6 / 曆史 0 (曆法/日曆/回曆 stay) |
| 併為給 | 並為給 | 5 | Rev 1:9, 1 / 0 |
| 瞭解 | 了解 | 5 | 了解 54 / 瞭解 1 |
| 燒燬 焚燬 銷燬 | 燒毀 焚毀 銷毀 | 6 | 燒毀 14 / 燒燬 0 |
| 倖存 倖免 | 幸存 幸免 | 5 | 幸存 1 / 倖存 0 |
| 覆活 | 復活 | 3 | 復活 374 / 覆活 0 |
| 繫住昴 | 系住昴 | 3 | Job 38:31, 1 / 0 |
| 迴避 迴歸 迴響 | 回避 回歸 回響 | 3 | 回避 2, 回歸 4 / 迴* 0 |
| 幹河 斐勒幹 | 乾河 斐勒干 | 4 | a wadi is dry; Phlegon is a name |
| 託房 | 托房 | 2 | Judg 16:29, 1 / 0 |
| 傢俱 | 家具 | 2 | 家具 8 / 傢俱 0 |
| 麵向 羊皮捲 綵衣 餬口 情慾生 揹著 藉助 鉅款 一齣會堂 一箇中央 | … | 10 | one each |

The other half of the rule is written down too, because a future
over-eager pass could undo it: **彷彿** (102 / 0), **饑荒** (108 / 0),
**細緻**, **簽名**, **岳母**, **鐘乳石**, **沖積** are opencc's phrase
dictionary getting it *right*, and they are asserted to survive.

### 40c — `_meta.confidenceCounts` described a smaller archive

It said `{Definitive 80, Strong 90, Circumstantial 39}`, which sums to
**209**. The file holds **225**, and the live counts are
`{Strong 96, Definitive 90, Circumstantial 39}`. It is not read by the
app, so no reader saw the wrong number, but it is the kind of stale
summary that a later feature reads and believes. Recomputed, and the
test now derives it from the records.

### 40d — the Chinese that says something untrue

225 English/Chinese title pairs were read one at a time. **Two defects,
8 occurrences, in 3 records** — neither of them a script question:

- **`但以理石碑`** (4 occurrences) for "Tel Dan Stele". 但以理 is Daniel
  the prophet. Tel Dan is the **city of Dan**, and the stele is
  9th-century Aramaic with nothing to do with the book of Daniel. The
  record's own description already says 「以色列北部的但（Dan）遺址」, and
  **但丘** appears 6 times elsewhere in this same archive — the archive
  had the right word and the title did not use it. Now **但丘石碑**.
- **`骨灰罐` / `骨灰盒`** (2 + 6). An ossuary is a stone box for
  **bones**; 骨灰 is cremated ash, and Second Temple Jews did not
  cremate. The same records say so themselves —
  「十二具藏骨罐（石制藏骨匣）」 — and the archive writes 藏骨罐 22 times
  and 骸骨箱 12 times elsewhere. Only these three records implied a
  cremation the entries themselves deny.

**A third candidate was withdrawn.** The Magdalen Papyrus is titled
`馬大拉紙莎草殘片`, and the Magdalen it is named for is Magdalen College,
Oxford, not Magdala. But the archive renders Magdala as **抹大拉** in all
18 places and uses 馬大拉 only for the college — so it does not confuse
them, and 馬大拉學院 is a defensible transliteration, not an error.

**Instrument limit.** Only the 225 **titles** were read against their
English. The 900 body fields — about 440 KB of Chinese — were not, so
the body-level translation error rate is unmeasured, and the ossuary
class was only found because a title led to it.

### 40e — the images, and what was clean

A negative result, recorded because it is one. Netlify's SPA fallback
answers a missing asset with HTTP 200 and `index.html`, so existence was
checked by **content**, not status: a range request for the first 64
bytes of each URL and a magic-number test.

- **716 image URLs, 716 distinct, all 206 with real image bytes**
  (jpeg 652, png 55, webp 8, gif 1). **0** SPA-fallback HTML.
  Re-verified on a 15-URL sample after the repair.
- **0** duplicate ids, **0** records with an empty image list, an empty
  source list or a blank scripture reference, and every `icon` is a
  single emoji.

### 40f — the same screen, pointed at the Traditional Bible editions

Cheap to run once the instrument existed, so it was run. The screen: a
character is suspect when opencc would map it to a *different*
character that the same file already uses at least 5× more often — the
file's own house form is the witness.

- **`cuvs-yhwh-tr.json`: 0 defects.** It flags only 仆 (74) and 后 (51),
  and every one is correct — all 74 仆 are 仆倒 (to fall prostrate) and
  all 51 后 are 王后/太后. The edition repaired under #323 survives its
  own screen.
- **`biblexg-v2-tr.json`: 207 occurrences across 45 characters,
  unadjudicated.** Some are certainly defects (稣 9 against 穌 1456;
  爱 2 against 愛 459; 话 3 against 話 529 — 「上了年纪的婦女」 is in the
  text of 提多書 2:3). Others are certainly false positives (里 87, 征 4,
  干 3, 于 1, 云 1 are valid Traditional) or 舊字形 variants the edition
  uses on purpose (内 11, 啓 9, 着 10, 没 12, 麽 2). **The true count is
  not 207 and is not yet known** — it needs the same one-at-a-time
  reading this check gave the archive. New open item.

### What the instrument got wrong, recorded so the next run does not

Three of this check's own guesses were refuted by the corpus, and each
would have shipped a defect:

1. **希伯崙 for Hebron.** Guessed from intuition. Our own Traditional
   editions have 希伯崙 **0** and 希伯侖 **69**. opencc was right.
2. **臺 → 台 as an exception**, reasoned from 12 already-converted
   records that use 台. The corpus refutes it: 金燈臺 **15** / 金燈台
   **0**, and all 25 臺 sites (平臺 燈臺 臺基 舞臺 天文臺 燭臺 臺階) are
   legitimate. No exception added.
3. **A corpus-witnessed auto-override** — take every case where the
   Bible editions prefer a different character, and apply it. It
   produced **175 changes**; reading them showed it fixes ~10 real
   opencc errors and would introduce ~**15 new ones**, because the Bible
   edition uses 舊字形 (墻 裏 麽 内 説 啓) and because biblical vocabulary
   is not modern prose — it would have written 復製品, 關系, 恒星, 斗爭,
   盡管, 采用, 松開, 銀制, 谷物, 征收, 周期. **Demoted from an override to
   a detector**, and every candidate read one at a time. This is the
   same discipline check 39 used, and the same reason.

---

## Not checked yet

- Verse **text** itself, against an *external* witness — for the
  **translations**. Check 24 closed this for the original languages
  almost by accident: aligning against MorphGNT and OSHB matched 99.31%
  of Greek and 99.59% of Hebrew words *by surface form*, which is an
  external witness to the text and not only to its codes. The 951 + 1,240
  words that did not align are the honest residue and are listed there.
  Check 26 closes the **Chinese** half: `assets/cuvs-yhwh.json` is now
  measured against the yahwehdehua export verse by verse (98.77% of
  31,102 agree on the Han stream), six unreadable classes were repaired
  and the 383-verse residue is listed there. Check 27 closes the
  **English** half for the two editions that had a public-domain witness:
  BSB is clean at 100.0000% and `kjv.json` is measured against three
  independent KJV texts, 101 errors repaired and 748 orthographic
  departures documented as this edition's own. Check 31 closes it for the
  last English edition that could be witnessed: `kjvs.json` departs from
  the three unanimous KJV witnesses in **0 of 30,708** verses. **What
  remains unchecked is `assets/nasb.json`**, and it is not a gap that
  effort closes — no public-domain NASB exists and the Eagle's View
  edition is licensed. A verse there that is wrong and well-formed and
  agrees with our own second copy would still not be found.
- `maps_index.json`
  (see #300 for its provenance gap). Check 40 closes
  **`bible_evidence.json`'s language and bookkeeping**: 152 mojibake
  strings repaired, 836 fields that served Simplified under a `zh-Hant`
  key regenerated, a stale `_meta` count corrected and two mistranslated
  titles fixed. What it does **not** close is the archive's *claims* —
  225 title pairs were read against their English, but the 900 body
  fields (~440 KB of summary, description and scriptural correlation)
  were not, and no instrument here can weigh "the stratum is consistent
  with a 9th-century destruction". Its 716 images resolve to real bytes;
  whether an image is *of* what its record says remains unasked.
  Check 37 closes
  **`book_introductions.json`'s checkable claims**: all 66 key-passage
  references are sound, 137 quotations are attributed to a passage that
  contains them, and the 5 countable claims that were false are fixed.
  What it does **not** close is the other half of every summary — "the
  most detailed prophetic portrait of the suffering Servant" is not a
  sentence any instrument in this repository can weigh. Check 36 closes
  **`family_tree.json`'s relationships**: the graph is sound in all 312
  edges, 3 printed names existed in no Bible the app ships and are
  fixed, and 333 of 338 relationship claims are stated by a passage the
  record itself cites. What it does **not** close is the tree's inferred
  links — 5 are named, but an inferred link whose two people happen to
  be named a few verses apart is invisible to that instrument, so the 31
  tier-2 claims are unreviewed and the model still has no way to draw a
  link as inferred. Its years are measured and reported, not repaired.
  Check 35 closes `ot_synopsis.json`'s **alignments** — 139 groups
  against a 3,994-pair null in two independent tagged layers, 11 flagged
  and read, 10 correct and the eleventh reported — and closes the
  **titles** of `section_titles.json` and `gospel_synopsis.json` at the
  same time, 1,513 of them, 0 defects. What remains unchecked in
  `section_titles.json` is whether a heading is in the *right place*, as
  opposed to spelled right: nothing here has asked whether "创造人类" at
  Genesis 1:26 divides the chapter where an editor would.
- The Septuagint's **verse text**, as opposed to its Strong's numbers.
  Check 23 measured the numbers and repaired them. Check 29 has now
  asked whether the Greek is **complete** and answered it against an
  external LXX: 301 of the 303 Old-Testament absences are the
  Septuagint's own text, 2 were our defect and are fixed, and 33 of 39
  books hold every verse the witness has. What that check did *not* ask
  is whether the Greek we do carry is the **right words** — it compared
  what is present against what is present, and a wrong-but-well-formed
  verse would survive it. The *tagged* coverage gap check 21 found in
  Nehemiah 10 **has now been chased across every book** — check 45: the
  whole corpus holds 21 untagged Greek verses, the 15 in Nehemiah 10 and
  six more, all of them inside lists of names. They are reported and
  frozen by name rather than repaired, because a guessed Strong's number
  is worse than a verse the reader cannot tap.
- The **41,032 Septuagint runs that still answer nothing** (check 23).
  Most cannot be answered — they are words the New Testament never uses —
  but nobody has separated "no Strong's number exists" from "a number
  exists and this edition does not know it". An LXX-specific lexicon
  would settle it; the repo has none.

## Check 41 — 梁家鏗繁體, judged by its own Simplified twin

Item 9 of "Next, in order" said `biblexg-v2-tr.json` "flags **207
occurrences across 45 characters**" and that "the true count is unknown
and is deliberately not written down as a finding." It is now known.
**30 characters in 28 verses are wrong**, and they are wrong in five
different ways, only one of which the 207 screen could see.

Repaired by `tools/repair_biblexg_v2_tr.py` (idempotent; converts
nothing by default, every rule is a verse id plus a context string, and
a second run early-returns "already repaired" with exit 0). Guarded by
`test/traditional_forms_test.dart`, which now runs 17 tests over both
繁體 editions.

### 41a — the instrument: the edition is a witness against itself

Every previous attempt at this file needed an outside authority for
"what is correct Traditional", and there isn't one that agrees with
itself. This edition does not need one. **It ships in BOTH scripts** —
`biblexg-v2.json` (Simplified, 7,921 records) and `biblexg-v2-tr.json`
(Traditional, 7,925) — so for any character the conversion touched, the
edition has already voted thousands of times on what it should become.
Align the two by verse id (**7,651** of the 7,921 shared ids are
length-equal, so the alignment is positional and needs no diff) and
count the substitutions. 说 becomes 說 **1,898** times and 説 **4**
times; the 4 are the defect. Likewise 为→為 1,987 against 为→爲 **1**,
and 启→啟 116 against 启→啓 **6**.

**The premise has a measured limit, and it has to be stated.** These
are not two mechanical renderings of one string. `opencc -c t2s` over
the Traditional file reproduces the shipped Simplified text exactly in
**6,181 of 7,921 verses — 78.0%**. The other 22% differ *editorially*,
not by conversion: the Simplified edition prefers 着 over 著 (1,012×),
什 over 甚 (456×), 借 over 藉 (105×) and 它 over 牠 (24×), and there are
outright wording differences (但/旦 36, 伸/申 9, 逼/迫 7) and changed
punctuation. So "every position where they differ is a converter
decision" would be **false**, and any screen built on that sentence
would drown in editorial noise. What survives the limit is narrower,
and is all this check uses: for a *specific* pair like 说/說, where one
Simplified character maps to two Traditional glyphs of the **same
word**, the tally is a conversion decision, and 1,898-to-4 is not an
editorial preference.

This is the same shape as check 40's byte-identity split: a
**structural** signature, not a semantic one. It required no external
Traditional corpus, no opencc verdict, and no judgement about house
style — only the file's own arithmetic.

**Aligning the two editions also found something bigger than the 30,
and it is in the other file — see 41f.**

Three screens were run, because the first two each have a blind spot
the third covers:

| screen | asks | blind to |
|---|---|---|
| 1. kept vs converted | at this position, did the converter act? | positions it converted *wrongly but consistently* |
| 2. opencc-mappable but never converted | is a Simplified form still here? | 舊字形 — 説 爲 啓 証 are not Simplified, so `s2t(c) == c` |
| 3. both forms of one char co-present | group by `t2s(c)`; which form is the house form? | forms that occur only once, in only one shape |

Screen 2 is check 40b's screen and is the one that produced "207". It
yields 12 of the 30 outright, and flags the characters behind two more
(里, 斗) inside a crowd of correct ones. **Screen 3 is what a refuter
added** after pointing
out that screen 2 structurally cannot see 舊字形, and it independently
re-derived every finding: 為 2,066 / 爲 1, 說 1,993 / 説 4, 啟 139 /
啓 6, 證 245 / 証 1, 蒙 142 / 矇 1.

### 41b — the 30, in five classes

| class | n | what happened |
|---|---:|---|
| A | 12 | a Simplified character **survived** the conversion |
| B | 1 | the converter picked the **wrong Traditional word** |
| C | 4 | the converter went **too far** |
| D | 12 | 舊字形 stragglers — a **search** defect, not a meaning one |
| E | 1 | the file had already **settled it one book earlier** |

**Class A** is the class the 207 screen was built to see. The file converts
稣→穌 1,123×, 话→話 468×, 满→滿 167× — and missed one each. 提多書 2:3
printed 「上了年纪的婦女」 with 纪 and 婦 in the same clause. One of the
twelve is inside a `<note:>` payload (啟示錄 1:1, 指耶稣基督), which is
verse text a reader sees and which a screen over `text` alone would
have to reach inside deliberately.

**Class B** is 馬可福音 1:23, 「在他們的會堂里有」, which wants 裡. This
is the one that must not become a sweep: the file's other **45** 里 are
all correct — 公里 ×8, 里拉琴 ×3, and 34 occurrences of eleven proper
names (提比里亞,
克里特, 吉里吉亞, 貝里亞, 亞里達古, 堅革里, 以利里古, 亞里斯多博, 居里,
希里, 亞里達王). 里 itself is not the problem.

**Class C is a defect class nobody had named, and the "Simplified
survivor" screen structurally cannot see it** — the output is a real
Traditional character, so nothing looks wrong. 准 is to permit
(允准, 批准); 準 is accurate/standard (標準, 準備). **準許 is not a
word**, in Taiwan's MOE dictionary or in Hong Kong usage, which is why
this is a defect and not a spelling preference. The count corroborates
but does not carry it: the Simplified twin writes 准许 **9** times and
the converter produced 准許 **6** and 準許 **3** from it.

(The character-level count 准→準 49 is *not* the witness: 32 of those
are 准备→準備 and 2 are 标准→標準, both correct. The word is the unit,
not the character — the lesson #323 was repaired on.)

**矇住 is the one case in this check the twin alone does not settle.**
Simplified 蒙住 ×2 became 蒙住 ×1 and 矇住 ×1 — a 1–1 split, no
majority. It is repaired on two other witnesses: 矇 is for eyes and
deception where a covered face is 蒙, and `cuvs-yhwh-tr` reads 蒙住 3 /
矇住 0. Recorded explicitly because it is the only edit here resting on
something outside the file.

**Class D** is not a meaning error — 説 and 說 are the same character —
but it is a real defect in *this* app, because search is literal: a
reader who types 開啟 finds **1** of this file's 4, and 他說過 misses
馬可福音 14:58.

**Class E** is 使徒行傳 7:32, 「摩西渾身顫斗」. 颤斗 is an upstream typo
present in **both** editions, so it is not a conversion defect — but
this same Traditional file already writes 顫抖 at 馬可福音 16:8 from the
identical Simplified string. The file contradicts itself, so it is
repaired on its own precedent. **The Simplified edition is not
touched**: correcting a translator's text is the owner's call, and
`biblexg-v2.json` still reads 颤斗 at Mk 16:8 and Acts 7:32.

### 41c — what "207" was actually counting

The whole-file screen over all 2,778 distinct Han characters flags
**694 occurrences across 32 characters**, not 207 across 45. Both
numbers are right about what they measured and **neither is a defect
count**. Only **14** of the 694 are defects — classes A, B and E — and
the rest were read one word at a time:

- **499 are opencc over-reaching.** 吃 234, 群 182, 秘 49, 床 21,
  唇 6, 岳 4, 熏 3 — opencc maps each to a 舊字形 (喫 羣 祕 牀 脣 嶽 燻)
  and **this file converts them zero times**. When the file has made
  the same choice 499 times, the file is the authority and the
  converter's output is what would be the defect.
- **The homograph pairs are correct as they stand**: 占星/占卜 ×8
  (against 佔據), 仆倒 ×6 (against 僕人), 干犯 and 王干大基 — Candace —
  ×3, 征服 ×3, 興高采烈/風采 ×3, 游泳 ×2 and 魂游象外 ×3,
  斗篷/三斗麵/在斗下 ×11, 模仿 ×1, plus 巡迴, 跡象, 複數, 嚮導/嚮往,
  贊同, 希斯侖, 簽字, 御營.
- **4 are neither**: 游手好閒 ×4 is left unrepaired for want of a
  witness (41d), so it is not being claimed correct — only unproven.
  The honest split of the 694 is therefore **14 defects, 676 read and
  kept, 4 undecided**.

After the repair the same screen reads **21 characters / 683
occurrences**, and the arithmetic of the difference is a check on the
work: 内 2, and 别 审 毁 没 温 满 稣 纪 脱 话 one each, all go to zero —
**12 occurrences across 11 characters**, exactly class A — 里 goes
46 → 45 (class B), 斗 goes 12 → 11 (class E, 顫斗), and 准 goes **up**,
14 → 17, because class C put three 準許 back to 准許. Net −12 −1 −1 +3
= **−11**, and 694 − 683 = 11.

**What is missing from the 32 is the strongest evidence that this
screen was never enough.** 説, 爲, 啓, 証 and 矇 do not appear in it at
any count, because they are not Simplified characters — `s2t(說) == 說`,
so the screen cannot flag what it cannot distinguish. Those account for
**16 of the 30 defects** — 説 4, 啓 6, 爲 1, 証 1, 矇 1 and 準 3, which
is classes C and D entire, more than half the check.
"207" was never a defect count; it was the reach of one instrument.

**The 隻/餘/淨 check that #323 ran on this file is confirmed by a
stronger test**, though the rule needs its exceptions named rather than
absorbed into it. Of the 50 隻, **46 directly follow a numeral** (一 37,
九 3, 百 2, 兩 1, 五 1, 六 1, 十 1) — positionally, the rule that made
只 tractable in #323. The other 4 are not classifier uses and are
correct anyway: 船隻 ×3, where 隻 is the second half of a noun compound,
and 約翰福音 10:3's 「一隻隻」, a classifier reduplication. The test puts
船 and 隻 in the determiner set, so what it asserts is "every 隻 is
accounted for", not "every 隻 is a classifier" — recorded so the
assertion is not read as stronger than it is.

### 41d — reported, not repaired

Standing rule for this check: **repair only what the corpus witnesses.**
Ten things fail that test and are left alone, deliberately:

- **一台戲 (哥林多前書 4:9).** A refuter killed this edit and was right:
  the file's *single* 台 **is** the site proposed for change, so its own
  29 臺 are not independent evidence, and MOE keeps 台 as a classifier
  (一台機器).
- **游手好閒 ×4 and 包紥 ×1.** The standard forms 遊手好閒 and 包紮
  occur **zero** times in this file and **zero** times in
  `cuvs-yhwh-tr.json`. A refuter wanted both fixed; overridden on the
  witness rule, and recorded here instead. This is the conservative
  option and may well be wrong — it is the owner's call.
- **Both forms attested, so neither is a defect**: 托付 28 / 託付 2,
  凶惡 2 / 兇惡 1, 一伙 6 / 一夥 3, 了解 13 / 瞭解 1, 污 56 / 汙 1,
  嘗 15 / 嚐 1.

  **This looks like it contradicts class C and does not, but the
  distinction is worth stating because a majority argument alone would
  not survive it.** 一伙 6 / 一夥 3 is the same 2-to-1 split as
  准許 6 / 準許 3, and 托付 28 / 託付 2 is far more lopsided than
  either. The difference is not the ratio. 準許 is **not a word**;
  一夥, 託付, 兇惡, 瞭解, 汙 and 嚐 are all standard Traditional
  spellings that a dictionary will confirm. A split only identifies a
  defect once one side is independently known to be wrong — the count
  says *which* reading the edition prefers, never *whether* the other
  one is legal. Every class C repair rests on the first test and passes
  the second; these six fail the first, so the count is not evidence
  about them at all.
- **颤斗 ×2 in the Simplified edition** (class E above).

### 41e — the test's negative needles were checked for teeth

Per check 40's lesson, every `isNot(contains(...))` was counted in the
**unfixed** file first. The test has two kinds of negative and they
needed different evidence. The **20 repair needles** (the 12 of class A, plus 會堂里, 準許, 矇,
説, 爲, 啓, 証 and 顫斗) each occur ≥1× before the repair and 0× after
— those have teeth. The **freeze needles** (佔星 僕倒 幹犯 遊泳
公裡 喫 羣 祕 …) are 0× in both files by construction: they are
counterfactual guards against a conversion nobody has run yet, and they
are honest only because the *positive* half of each pair was measured
present (占星 7, 仆倒 6, 游泳 2, 公里 8, 吃 234 …). One candidate,
不相干, was dropped from the freeze list for having no occurrences at
all. Run against the pre-repair file the five repair-class tests fail
and the freeze tests pass, which is the split they should have. The asset is
compact single-line JSON with no trailing newline, so it is rewritten
with `separators=(",", ":")`: `git diff --stat` reads **1 insertion, 1
deletion** for 30 real edits, rather than burying them in a reformat.

### 41f — the Simplified edition is missing 馬可福音 6:8-11

**This is a worse defect than the 30 characters, and it was found by
accident** — in the parenthesis "(Simplified, 7,921 records) and
(Traditional, 7,925)". Nothing in this check set out to ask why those
two numbers differ. They differ because `biblexg-v2.json` **has no
馬可福音 6:8, 6:9, 6:10 or 6:11**. Its ids run `41006007` → `41006012`.

It is not a merge and not a versification choice. The Traditional
edition carries all four with ordinary single-verse labels, and the
Simplified 6:7 is **truncated in the middle of a clause**:

| | 6:7 ends | next verse |
|---|---|---|
| Traditional | …並授予他們權能**制服不潔的靈。** | 6:8 他叮囑他們說… |
| Simplified | …并授予他们权能 | 6:12 于是，他们分头出发… |

A reader of the Simplified edition sees a sentence stop dead and four
verses vanish — the instructions to the Twelve: the staff, the sandals,
the shaking of dust from the feet.

**Measured across the corpus, this is the only one.** Every Bible asset
was scanned for verse numbers absent from their own chapter's 1..max
range. Nearly every hit is a standard critical-text omission that
modern translations drop by design and that all our editions drop
together — Mt 17:21, 18:11, 23:14, Mk 7:16, 9:44, 9:46, 11:26, 15:28.
Comparing the two 梁家鏗 editions *to each other* rather than to a
versification table isolates the real signal: **Simplified-only gaps =
Mk 6:8-11; Traditional-only gaps = none.** (路加福音 1's apparent gaps
at 2-4 and 75 are merged verses, correctly labelled `1-4` and `74-75`
in *both* editions, and are not defects.)

**Not repaired, deliberately.** The text exists in the Traditional
twin, so a mechanical `t2s` looks like a free fix, and it is not one.
`opencc -c t2s` reproduces the shipped Simplified text exactly in only
**78.0%** of verses (41a), and the missing passage sits squarely on the
fault line: Traditional 6:8 reads 「其餘甚麼都不帶」, while this
Simplified edition writes 什么 for 甚麼 456 times and 着 for 著 1,012
times. Restoring it by conversion would mean **inventing a
translator's house-style choices inside a translator's own Bible** —
the same call the sermon corpus was left alone for. It needs the
upstream source or the owner.

## Check 42 — Nave's Topical Bible, and the five books its tagger cannot read

`assets/nave/` was imported this round by `tools/import_naves.py` from
CCEL's ThML edition of Nave's *Topical Bible* (1896, public domain):
**5,322 topics, 29,379 lines, 77,974 references** — 75,804 of them
verse-or-range, 2,170 chapter-level — with a per-book reverse index so a
verse pane reads one 90 KB index plus the one book in view.

None of those numbers were trustworthy when the import first produced
them. **Two defect classes were found before the feature shipped, both
upstream, and neither is visible in the shape of the file.** Every
count above is post-repair. Guarded by `test/naves_test.dart` (18 tests,
including one that resolves all 77,974 references against
`assets/kjv.json`) and `test/naves_pane_test.dart` (6).

### 42a — the instrument, and why the obvious witness is not one

CrossWire ships a SWORD module called `Nave`. It is **not** an
independent witness: its conf names
`TextSource=https://ccel.org/ccel/n/nave/bible.xml` — the same file we
imported. Checking our import against it would only prove the two
converters agree.

The witness that worked is **inside the file**. CCEL's tagger emits both
a machine reference and the printed text, and where the two disagree the
printed text is the original and the tag is the derived thing. That
asymmetry is what both classes below rest on, and it needed no outside
source.

The screen that found class A was not a search for defects at all. It
was a **sizing question** — what is the worst-case citation count for
one verse, so the pane can choose between a lazy list and an eager one.
The answer was **Jude 1:1 = 115 topics**, which is not a plausible thing
for a topical index to say about a doxology's opening line.

### 42b — class A: a one-chapter book has no chapter number to parse

Obadiah, Philemon, 2 John, 3 John and Jude are printed without a
chapter, so Nave writes "Jude 14". The tagger reads the 14 as the
chapter, fails, and emits the book's first verse — leaving the real
number stranded in the prose *after* the closing tag:

```
<scripRef osisRef="Bible:Jude.1.1">Jude 1</scripRef>:14,15
```

**All 250 sites referring to those five books arrived as `BOOK.1.1`.**
Jude 1:1 carried 115 unrelated topics; Jude 1:14 — the Enoch prophecy,
the one verse of Jude every topical index files — carried **none**.

`repair_single_chapter` reads the orphan text. 246 sites resolve
directly; 2 are re-read as class B ("Obadiah 1 Ki 18:12" — the printed 1
was not Obadiah's verse, it began the *next* book's reference); 2 have
no verse to recover ("See the EPISTLES OF JOHN 1Jo 1; 2Jo 1; 3Jo 1") and
are emitted as **chapter citations**, which the reader sees marked
"whole chapter" rather than as a false verse claim.

The repair is checkable against the books' own lengths, and it checks
out. The 250 sites became 298 references, every one inside its book, and
three of the five reach their **exact last verse**:

| book | sites | distinct verses | highest cited | book ends |
|---|---:|---:|---:|---:|
| Jude | 145 | 40 | 25 | 25 |
| Philemon | 51 | 27 | 25 | 25 |
| 2 John | 42 | 18 | 13 | 13 |
| 3 John | 28 | 13 | 14 | 14 |
| Obadiah | 32 | 18 | 21 | 21 |

Jude 1:1 now carries **6** entries and Jude 1:14 carries **14**,
including "ANTEDILUVIANS › Enoch prophesies to".

### 42c — class B: the tagger swallows the first digit

A smaller version of the same failure, in ordinary multi-chapter books:
the tag closes after a partial number and the rest sits in the prose.
**40 sites**, repaired from the orphan text, **30 of the 40 confirmed by
reading the KJV text of the repaired target** and checking it against
the topic line's own wording.

Chasing the *drop* list then found a second defect inside the first
repair: the class-B fix stopped at the first continuation, so
"Co 8:16,17" kept the 16 and shipped the 17 against a **Colossians 8 and
12 that do not exist**. `eat_continuations` follows the comma, under a
deliberately narrow guard — it consumes a following `scripRef` only if
it carries the *same wrong* osisRef book and its printed text is bare
digits — so a genuine Colossians reference standing next to a repair is
never swallowed. That recovered **4** references and took the
unresolvable drops from 9 to 5.

### 42d — what was dropped rather than guessed

**12 apocrypha references** (Nave cites Bel, Tobit, Ecclesiasticus; we
ship 66 books) and **5 unresolvable**: Exodus 3:29, Mark 18:42, Mark
18:43, 1 Chronicles 22:27, 1 Chronicles 22:30. Each names a chapter or
verse that does not exist and each has more than one plausible
correction, so each is dropped. The importer prints them by name every
run; they are not silent.

**1,047 "see" targets do not resolve** to a topic in the index. That is
not repaired and not a data defect on our side — Nave cross-references
headings he did not always write. The verse pane does not render "see"
links at all, on measurement: only **1 of 22,249** cited lines carries
one, so the single case is folded into the line's text.

### 42e — the defect our own test found, in our own code

`NaveTopic.ancestorsOf` walked up looking for a line at exactly
`depth - 1`. Nave skips levels. When the parent was two levels
shallower, the walk **stepped over it and kept going into the previous
topic's subtree**, so the pane printed a path the author never wrote —
"HOSPITALITY › INSTANCES OF › Gaius" for a line Nave filed under
"HOSPITALITY › REWARDED". Fixed to accept any line shallower than the
one being sought. Measured before the fix: **63 of 22,249 cited lines**
carried a false path.

This one is worth recording because it is the only defect here that was
**ours**, it was invisible on every verse anyone would think to spot-check,
and it was found by a unit test written for the walk's ordinary case.

### 42f — what is still not checked

The 5,322 headwords and 29,379 line texts are **not** verified against
anything. This check verifies that every *reference* resolves to a verse
that exists and that the citations sit where Nave put them; it does not
verify that Nave was right, and it does not verify that CCEL's
transcription of his prose is faithful. The second would need a scan of
the 1896 printing.

## Check 43 — the four lexicons, measured because a picker was going to promise coverage

Run 2026-08-23 while building the Lexicon Browser's second lexicon
(bwh35, backlog 1a). The backlog's instruction was to measure coverage
*before* designing the picker, "since a picker that offers a lexicon
with holes in it will state something untrue by omission". The
instrument is trivial — join every Strong's headword against each
lexicon and count what comes back empty — and it is the *join* that
matters: a first pass counted **keys** and reported 100% coverage in
both directions. Presence of a key is not presence of an article.
`test/lexicon_browse_test.dart` now pins the numbers below.

### 43a — G190 ἀκολουθέω was shipped and unreachable

Two of `assets/thayer.json`'s 5,799 keys are zero-padded to four digits
where every other one is bare: `G0190` and `G0446`. Nothing else in the
app pads a Strong's number, so `ThayerService.lookup('G190')` returned
null for **ἀκολουθέω** — the New Testament's verb for *following*
Jesus, 90 occurrences — and for `G446` ἀνθύπατος with it. The articles
were in the bundle, shipped, and could not be reached from any surface.

Fixed at the boundary rather than the call site: `canonicalKey` strips
the padding both when the table is built and when it is queried, so the
defect is unreachable by construction instead of fixed twice and
forgotten a third time. Measured: exactly 2 padded keys, and neither
has an unpadded twin, so nothing collides. English Thayer coverage is
now **5,523 of 5,523**, no holes.

### 43b — 19 headwords whose work never defines them

| work | side | headwords with no article |
|---|---|---|
| Strong's (English) | both | 0 |
| Strong's (Chinese gloss) | Hebrew | 5 — H4084, H4092, H7427, H7627, H7665 |
| Strong's (Chinese gloss) | Greek | 9 — incl. G4191, G2304, G302, G4236 |
| Thayer's (English) | Greek | 0 |
| BDB 中文 | Hebrew | 4 — H2775, H7418, H7427, H8556 |
| Thayer 中文 | Greek | 1 — G4191 πονηρότερος |

All 19 carry a lemma and a transliteration; none is a wholly empty
record. Nineteen rows in 14,197 is small enough to keep offering the
work — but not small enough to leave blank, because a blank cell is
indistinguishable from a failed load, and filling it from another work
would credit the wrong lexicographer. The row says
`lexiconWorkSilent` instead. Note the 14 Strong's-side holes were
**already blank** for a Chinese reader the day the browser shipped;
this check found them by asking the question about a different work.

### 43c — 28 truncated etymologies, which belong to #301

**This section's count and its diagnosis were both wrong. Check 44
supersedes it; the text is kept because the way it was wrong is the
lesson.** The defect was real, the repair is shipped, and the scope
was 468 etymologies and 1,635 usage fields, not 28.

Not this feature's defect, and not repaired here. In the Chinese
module, **28 of 14,696 entries have an `etymology` that stops
mid-clause** — 9 in `bdb_zh`, 19 in `thayer_zh` — detectable by an
unbalanced parenthesis:

- H2775 → `charcah (khar'- saw`
- H205 → `字根已不使用, 可能的意思为喘气(由此,使尽浑身解数`
- G1537 → `原型的介系词, 表示起源 (一个动作的启始处), 源自, 出自 (某个地点,`
- H3203 → the same clause repeated five times with different closers

The shape says the importer split a field on a delimiter that also
occurs *inside* the parentheses. These render today in the word-study
entry pane, not only in the browser. The fix is in
`tools/import_yahweh_modules.py`, which is ticket **#301** — the same
import already re-opened for a different reason. The parenthesis test
is the detector; it must be run against the regenerated asset, not
against a hand-corrected one.

*(A per-sense parenthesis count is **not** a detector: 30,508 sense
lines are "unbalanced" because a parenthetical legitimately opens on
one numbered sense and closes on the next. Only the single-line
`etymology` field can be judged this way.)*

## Check 44 — the Chinese lexicon's fields, cut wherever the printed page broke

Check 43c reported 28 truncated etymologies and named the cause: "the
importer split a field on a delimiter that also occurs inside the
parentheses." Both halves were wrong, and the way they were wrong is
worth more than the repair.

**The module stores one `<p>` per VISUAL LINE, not one per field.** The
importer read `lines[2]` as the etymology, `lines[3]` as the KJV usage
if it began 钦定本, and everything after as senses. That is correct only
for an entry whose every field happened to fit on one printed line. A
field that wrapped arrived as two, three — up to nine — `<p>` elements,
and the positional reading kept the first and misfiled the rest.

What the reader saw, in H205 אָוֶן:

| | shipped | after |
|---|---|---|
| etymology | `字根已不使用, 可能的意思为喘气(由此,使尽浑身解数` | …`, 通常是徒劳的); TWOT - 48a; 阳性名词` |
| usage | *(absent)* | `钦定本 - iniquity 47, wicked(ness) 8, … vain 1; 78` |
| sense 1 | `, 通常是徒劳的); TWOT - 48a; 阳性名词` | `1) 苦恼, 邪恶, 哀伤` |

A definition that stops mid-clause, no KJV counts at all, and the
missing half of the etymology served to the reader as **a numbered sense
of the word**. It rendered perfectly, threw nothing, and the suite was
green throughout.

### 44a — why the parenthesis test found only 28

Because a parenthesis test can only see a break that lands *between a
bracket and its partner*. Every other wrap — the overwhelming majority —
is invisible to it. The published figure was not an undercount by a
margin; it was a different quantity, measured by an instrument that
could not reach the defect. **28 of 14,197 is 0.2%. The real figure is
11.5%.**

The working detector is the module's own convention: a KJV usage block
reads `钦定本 - word N, word M, …; TOTAL`. The trailing total makes the
block **self-terminating** — you can tell a wrapped continuation from
the next real field because the field is not finished until the total
arrives. Sense markers (`1)`, `1a)`, `1a1a)`, and six rare bare `a)`
forms) close the other end.

### 44b — measured, on the regenerated asset

14,197 lexical entries across `bdb_zh` and `thayer_zh`, grammar codes
excluded.

| | before | after |
|---|---|---|
| etymologies repaired | — | **468** |
| usage fields repaired | — | **1,635** |
| …of those, entirely absent before | — | **468** |
| sense lists cleaned of misfiled prose | — | **1,631** |
| entries carrying a usage field | 13,721 | **14,189** |
| etymologies with unbalanced brackets | 26 | **13** |

The 13 residual unbalanced brackets are damage in the module itself
(H2775 ships as `charcah (khar'- saw` and nothing follows it), correctly
left alone rather than invented. The 8 entries with no usage field are
the same kind: H2059, H2194, H2540, H2775, H7418, H7427, H8556, G4191
carry no 钦定本 line at all.

**The strongest verification is conservation, not the counts above.**
Whitespace-flattened `etymology + usage + senses` was compared per entry,
old against new: **0 entries lost text and 0 gained text.** Every one of
these changes is a redistribution between fields. Nothing was written
that the lexicographer did not write.

### 44c — the two failures on the way, both instructive

**A sense-marker regex is a data question, not a guess.** The first
attempt, `^\d+[a-z]?\d*\)`, does not match `1a1d)`, `1c2d)` or a bare
`a)`. About 1,900 real senses would have been read as continuation prose
and glued into the line above — *worse than the defect being repaired,
and equally silent*. The shapes were enumerated from the data (14
distinct) and the 6 letter-initial cases read individually before the
pattern was settled.

**The tidier branch was the wrong one.** For the 8 entries with no
钦定本 line there is nothing to say where the etymology stops. Joining
the whole body into the etymology looked cleaner and emptied H2194's
five numbered senses, H2059's three and H2540's five —
`test/lexicon_browse_test.dart` caught it, because check 43b had pinned
the set of article-less headwords and it had grown from 5 to 8. The
branch now falls back to the exact shipping behaviour. **A pinned set
from an earlier check is what made a silent regression loud.**

### 44d — what was deliberately NOT repaired

1,514 non-marker lines sit inside sense blocks. Some are wraps; some are
standalone annotations (`专有名词, 阳性`, `其同义词, 见 5859`) that were
always their own line. **Nothing in the markup separates the two.**
Senses render one per line, so an unjoined wrap is cosmetic — while a
wrong join would state a sense the lexicon does not. Left alone, and
recorded in `split_entry`'s docstring so the next reader does not
mistake it for an oversight.

The same reasoning chose the failure direction for the usage block: stop
early and the old truncation survives; run on and a proper-name gloss is
glued into a word-frequency list, which reads as a KJV count and is not.
**A truncated count claim is worse than an absent one.**

### 44e — a green test that was green because of the defect

`test/lexicon_page_test.dart`'s "picking a work changes the rows"
asserted that Thayer 中文's summary for G26 ἀγάπη differs from
Strong's. It passed for the wrong reason: Thayer 中文's first "sense"
was the truncated KJV fragment `feast of charity 1; 116`. Repairing the
import put the real sense back — and the two works say **the same
thing**: `重视,喜欢,爱上` in both.

Measured across the Greek side: **4,875 of 5,514 headwords (88.4%)
carry a Chinese summary identical to Strong's but for punctuation**;
2,274 are identical character for character. The Chinese Strong's gloss
comes from CBOL and the module's senses share its lineage, so *the
browser's second Chinese work mostly repeats the first in the row
summary*. The works differ in the article body — etymology, the 钦定本
counts, the sub-senses — which is what the article-tier search reads,
so the feature is not empty; but the row is not the place to look for
the difference. Proper names are where they genuinely part: Strong's
describes the person (`亚当, 第一个被造之人, 全人类的始祖`), the module
gives the name's meaning (`亚当 = "红土"`). The test now uses G76 Ἀδάμ
and says why in full.

**A test that asserts two things differ is only as good as the reason
they differ.** This one would have gone on passing through any repair
that left the fragment in place.

### 44f — the same cut, in the Strong's asset (repaired in 44g)

Found by the comparison above and measured, not fixed in the same
iteration — it is a different asset and a different generator, and one
repair per iteration is the rule that keeps a conservation proof
meaningful. **Closed by check 44g below**, which also found that the
scope stated here is 2.1× low.

`tools/build_originals.py:244` builds the Chinese gloss with
`re.search(r'^\s*1\)\s*(.+?)\s*$', body, re.MULTILINE)` — **the first
physical LINE of sense 1**, where CBOL wraps sense 1 across several. The
docstring calls it "short but accurate". It is short, and for **279
entries it is not accurate**: 193 Hebrew and 86 Greek glosses end on a
comma or semicolon, mid-clause.

- H204 → `…崇拜太阳神的中心,` — `defZh` continues `波提非拉 (安城的祭司, 约瑟的岳父) 居住之地`
- H218 → `在南巴比伦的城市, 迦勒底的城市, 崇拜月神的中心地,` — the next line names Abraham's home town
- G4102 πίστις → `对任何真理的坚信, 相信;` — the clause that says the New Testament sense is on line two

`glossZh` is the row summary in the Lexicon Browser and the gloss in
word study, so these are on screen. 279 is a floor, not a total: it
counts only glosses whose cut happens to land on a separator, which is
**exactly the mistake check 43c made** — an unbalanced-bracket test
found 28 of 468. The true figure is however many of the CBOL glosses
(8,669 Hebrew + 5,514 Greek) have a multi-line sense 1, and it must be
measured from `defZh`, not guessed.

The repair needs no network: `defZh` ships complete, so the joined gloss
is derivable from the asset already in the tree. Fix the generator
function and apply the identical rule to the shipped file in the same
change, or the two drift apart.

Regression tests: `test/chinese_lexicon_test.dart` — three worked
examples (H205, G1537, G3588) plus two corpus-wide detectors, one
asserting no sense begins `钦定本 -` and one pinning 14,189/14,183. Fix
in `tools/import_yahweh_modules.py` (`split_entry`), ticket **#301**.

*(**Re-running that importer regresses the tagged Bible text.**
`tools/repair_chinese_lookalikes.py` runs after it and replaces 丶
U+4E36 with 、 U+3001 at 27 sites in 15 books that check 26 arbitrated
against two outside witnesses. A plain re-run puts the lookalike back,
renders perfectly and throws nothing. It happened during this check and
was caught by `git status` showing 15 files nobody meant to touch. The
warning is now in the importer's own docstring.)*

### 44g — the Strong's Chinese gloss, repaired (closes 44f)

Fixed 2026-08-23, on `main` and undeployed at the time of writing — it
reaches dev with the next release. `tools/build_originals.py` now has
`sense_one_gloss`,
which reads sense 1 across the lines CBOL wrapped it on;
`tools/repair_zh_gloss_linebreaks.py` **imports that same function** and
applies it to the shipped assets, so the generator and the asset cannot
give different answers. No network was needed — `defZh`/`defZhTw` ship
whole, and `glossZhTw` is parsed out of `defZhTw` rather than converted
from the repaired `glossZh`, so every Traditional character is one that
already shipped.

**The scope, measured from `defZh` as 44f demanded: 593 entries have a
multi-line sense 1**, against the 279 the separator test reported —
2.1×, the check-43c failure mode again. 488 of those needed rewriting;
the remaining 105 are the deliberate breaks below.

| | Hebrew | Greek |
|---|---|---|
| entries rewritten | 367 of 8,674 | 121 of 5,523 |
| characters restored | +19,389 | +5,736 |
| glosses ending on a separator | 386 → 0 | 172 → 0 |

675 scripture citations became reachable from the gloss that were
previously only in the body (`test/cbol_lexicon_data_test.dart`, 46,052
→ 46,727 — the *unreadable* count did not move).

**CBOL's newline is not always a wrap, and that is the whole difficulty.**
The corpus has no single column width: sense-1 line widths run
continuously from 5 to 99 with no gap to cut at. But within one entry the
wrap is visible, so a break counts as a wrap only when the line it ends
could not have held more — it dangles on a separator, or it is
unterminated and reaches 70% of the widest line in **its own entry**.

The refuting example is G749 ἀρχιερεύς: `祭司长, 大祭司` on a 17-column
line in a 90-column entry, with a fresh article on the next line. Joining
them produced `大祭司在祭司中最大的一`, **a reading found in no
lexicon** — a fabricated gloss is worse than a truncated one. Same class:
G5330, G5019, G200, G2769, G3567, G4950, G205, G2884, G1537, G1722,
G1519, G3684.

Three sub-rules, each paid for by a specific entry:

- **A plain bracket is not a terminator; a CBOL citation is.** `|`, alone
  or inside the bracket that `(#` opened, ends an item. A bare `)` does
  not: H1374 closes `(今 Anata 亚拿塔)` mid-sentence, and reading that as
  the end says the village is *at* Anathoth rather than between the
  ridges of Anathoth and Nob. Also H5683 `别是巴[884]`, H6048
  `摩洛神(见 [4432])`, H6489, G1359 `与莉达(Leda)`.
- **A space is not a word boundary in Chinese.** Join directly between
  two wide characters; H1841 otherwise reads `神所赐 解梦的恩赐`, H3038
  `他的后 裔`, H6540 `里 海和`. Join tight before punctuation too, or
  G5330 gets `自豪 , 相对之下`.
- **CBOL nests four levels deep.** `_ZH_NUMBERED` matched `1a)` but not
  `1a1)`, so ~3,900 sub-sense markers read as ordinary prose — H7293's
  sense 1 was continuing into `1a1) 神话中的海怪`. A second defect in the
  same function, found only because the wrap rule made it visible.

Grammatical part-of-speech lines still end sense 1, by a closed
vocabulary and **not** by indentation or length: CBOL indents three tags
(H369, H4616, H8478) and leaves 107 at column zero, while real definition
text runs as short as `的手上` (H2078) and `地名` is a two-character tag.

The trailing separator is dropped only after joining. Verified safe
before doing it: every gloss still ending on one is followed by a
sub-sense (26), the next sense (16) or the end of the body (19), and
**never** by text the rule declined to take.

Regression tests: `test/cbol_lexicon_data_test.dart` — four worked joins
(H204, H218, G4102, H1374), three worked refusals (G749, G5208, and
G1537's stub colon, which `StrongsEntry.localizedGloss` still needs),
plus two corpus detectors: no gloss ends on a separator, and **all 28,368
glosses appear verbatim in their own body once line breaks are removed**.
That last one is what separates reflowing from paraphrasing. The repair
is idempotent and re-serialises byte-identically outside the two fields
it touches — confirmed by a structural diff against `HEAD`.

## Check 45 — every tagged layer against the flat edition it claims to tag

`assets/tagged/<edition>/<book>.json` and `assets/<edition>.json` are two
records of the same verse, made by different processes, and nothing had
ever asked whether they agree. They are the two halves of what a reader
sees: the flat file is the text on the page, the tagged file is what the
word under their finger answers. Neither needs an outside source to
witness it, because each witnesses the other.

`tools/audit_tagged_layer.py` asks the two questions that follow from
that, over all five committed tagged editions — `bsb`, `kjvs`, `lxxwh`,
`cuvs-yhwh`, `cuvs-plus`. (`nsn-plus` is deliberately excluded: the
Eagle's View NASB is licensed and never committed, so an audit that read
it would pass here and fail in CI.)

| | rows | disagreements |
|---|---|---|
| coverage — flat verses with a tagged record | 155,193 | **111 absent**: 90 placeholders, **21 real Greek verses** |
| agreement — `kjvs`, `lxxwh`, `cuvs-plus` | 92,894 | **0** — 100.0000% |
| agreement — `bsb` | 31,086 | **2** — 99.9936% |
| agreement — `cuvs-yhwh` | 31,102 | **350** — 372 before 45g repaired 22; see 45d and 45g |
| orphans — tagged records naming a verse the edition lacks | 5 editions | **0** |

### 45a — the 21 untagged verses, and why they were not repaired

Of the 111 flat verses with no tagged record, 90 are placeholders —
`见上节`, `OMIT` and the rest of `kVerseAbsenceMarkers` — where having no
tagged record is *correct*, because there are no words to tag: 74 in
`cuvs-plus`, 16 in `lxxwh`. The remaining **21 are real Greek text in
`lxxwh`**, and this closes the "never chased across the other books" note
that check 21 left open. The whole corpus holds exactly these:

> 1 Chronicles 1:30 · Ezra 10:35, 10:36, 10:40 · Nehemiah 10:3, 10:4,
> 10:5, 10:11, 10:12, 10:15, 10:16, 10:18, 10:19, 10:20, 10:21, 10:22,
> 10:24, 10:25, 10:27 · Nehemiah 12:2, 12:3

Check 21's count of **15 in Nehemiah 10 was exactly right** — this is the
rarer result, a published scope that survived re-measurement from the
source. What it could not know is that **six more sit in three other
books**: Nehemiah 12:2–3, Ezra 10:35/36/40, and 1 Chronicles 1:30. Every
one of the 21 falls inside a list of names.

The worst hypothesis was ruled out before anything else: this is *not* a
check-40-class one-verse shift that would make the tap layer answer for
the neighbouring verse. The tagged records that *are* present in
`nehemiah`, `ezra` and `1_chronicles` reconstruct their own flat verses
exactly — 0 mismatches in 375, 277 and 928 — so the 21 are genuine
under-coverage, not misalignment.

**Not repaired, and that is the conservative reading, not the lazy one.**
`TaggedTextService.forVerse` returns null for a verse it has no record
of, and the caller renders the plain string, so the reader sees the Greek
and simply cannot tap it — `browse_window.dart:1036` falls to
`_TranslationLine`, `phrasing_page.dart:381` falls through to
`phrasingTokens`.

**With one exception, found by refutation and confirmed here.**
`kwic_pane.dart:127` does `if (runs == null) continue;` while
`_totalRefs = refs.length` at line 136 still counts the reference, and
the footer at line 389 prints "All $_totalRefs references". So a KWIC
over `lxxwh` whose hits include any of the 21 shows fewer lines than the
number it asserts, silently. That is a small **false statement**, not
under-coverage, and it is the reason the blanket phrase "the callers
degrade gracefully" was wrong. It is filed with the 79 below.

Under-attribution is recoverable and visible; a
fabricated run — a Strong's number guessed for a Hebrew name — is
neither, and would be the app stating something untrue about the text in
order to remove a blank. The 21 are frozen **by name** in
`test/tagged_layer_coverage_test.dart` so a future import cannot quietly
add a twenty-second.

### 45b — three layers reconstruct their printed text exactly

`kjvs` (31,102), `lxxwh` (30,763) and `cuvs-plus` (31,029) — **92,894 of
92,894 verses, 100.0000%** — say through their runs exactly what their
flat file prints, once markup, punctuation and whitespace are removed.
That is the result this check was built to be able to fail, and it did
not.

The normalisation is not carrying that result. Concatenate the runs and
compare the **raw strings with no stripping at all**: kjvs is
31,102/31,102 byte-identical, cuvs-plus 31,029/31,029, lxxwh
30,761/30,763 — the two exceptions being a single trailing space on the
tagged side at Numbers 10:35 and Deuteronomy 23:23. **92,892 of 92,894
verses are byte-identical between the two layers**, which is the stronger
statement and the true one.

`bsb` departs in **2 of 31,086**. Both drop a word from the tap layer
while the printed verse is correct:

- **Exodus 38:28** — flat "the 1,775 shekels **of silver**", tagged
  "the 1,775 [shekels]".
- **Judges 16:14** — flat "she tightened **it** with the pin", tagged
  drops the pronoun.

This is a **different question from `test/bsb_tagged_layer_test.dart`,
not a better one.** That test compares under a stricter reduction and
bounds its residue at 248 verses, nearly all punctuation; these two were
inside that residue and invisible for it. Coarsening the comparison until
only whole words survive is what made two dropped words separable from
248 dropped commas. The count is now pinned at exactly 2.

### 45d — the Chinese layers disagree in 372 verses, and 79 are real

**This subsection was written twice.** The first draft called all 372 an
editorial difference between two editions and named two defects inside
it. A refutation pass broke that, and the second measurement agrees with
the refutation: **most of the 372 is editorial, but 79 verses are a real
word-level difference and about twenty of them are wrong in the flat file
— the text the reader reads.** The first framing is left described here
rather than deleted, because the way it failed is the finding: a
plausible editorial explanation covered 293 of 372 verses, and covering
most of a set is not the same as explaining it. The remaining 21% was
where all the damage was.

The gross gap is 2,220 verses, because the tagged layer keeps the 和合本's
`〔…〕` marginal notes that the reading text moved into `<note: …>`.
Removing those takes it to 372, which then decomposes — measured, not
estimated:

| class | verses | what it is |
|---|---|---|
| settled orthographic pairs, and nothing else | **161** | 阿/啊, 它/他/她, 复/覆, 吗/么, 糟/蹧, 做/作, 吧/罢 — the same word, two normalisation dates |
| note or clause placement | **116** | a gloss inline on one side and in `<note:>` on the other |
| the same characters, reordered | **16** | an alignment artefact of removing the note, not a difference |
| **real word difference** | **79** | **a word is added, dropped or substituted** |

Of the 79, **15 are one defect**: the tagged layer prints a literal `#`
where the flat prints `[基督]` — 「算不得吃主**#**的晚餐」 (1 Cor 11:20),
「主**#** 说」 (Mt 22:44 and seven more). `browse_window.dart`'s
`_TaggedLine` renders the run verbatim, so **a 和雅 reader sees the hash
on screen**. The full set is Matthew 22:43/44/45, Mark 12:36/37, Luke
20:42/44, Acts 2:34, Romans 14:9, 1 Corinthians 11:20/26/27,
1 Thessalonians 4:15/16/17.

The other **64 are genuine textual defects, and they are in both files.**
Neither layer is the authority; each caught the other. Verified by eye:

**Wrong in the flat file — this is scripture the app displays.**
Judges 12:7 「作以色列的士师**年**」 has lost the 六 and no longer says how
long Jephthah judged · Isaiah 23:1 「因为**罗**变为荒场」 has lost the 推 of
推罗, so Tyre is not named · Judges 9:57 「咒诅归到**们**身上」 lost 他 ·
Judges 15:5 lost 葡萄园 from the list of what burned · 1 Samuel 15:12
「立了**记**纪念碑」 and Jeremiah 50:32 「城邑**中里**」 carry a spurious
character · Lamentations 3:1 has a spurious 神 · Numbers 13:5
「何利的儿子**的**沙法」 · Malachi 2:3 lost 在 · Isaiah 44:19 木**丕**子 for
木墩子 · Jeremiah 4:31 挓**抄**手 for 挓挲手 · Isaiah 64:3 and Acts 25:18
**意**料 for 逆料 · Jeremiah 7:20 and 20:2 地**着** for 地里.

**Wrong in the tagged layer — the reader sees the right verse and taps a
wrong one.** Doubled characters at Leviticus 5:7 (若若), 1 Samuel 20:37
(箭箭), 1 Kings 19:18 (未未曾), 2 Kings 10:5 (我们我们), Isaiah 41:16
(以以色列), Ezekiel 36:1 (你要要), Matthew 9:28 (耶稣说说); dropped
characters at Leviticus 8:14 (头**上**), 1 Kings 15:31, 2 Kings 13:10,
2 Chronicles 18:18, Ezekiel 10:1, Jeremiah 4:22, 11:2, Nehemiah 2:19.

**None of this is repaired here.** Each one needs its 和合本 reading read
individually — the discipline check 26 established and
`tools/repair_chinese_text_defects.py` already follows — and doing 64 of
them properly is a job of its own, not a coda to an audit. The complete
list is regenerable from `tools/audit_tagged_layer.py`. It is now the
leading numbered item under "Next, in order".

The test therefore **bounds this at ≤ 372 rather than pinning it**, so
normalising 阿 to 啊 does not fail the suite — but the bound is a holding
position over a known defect, not a clean result, and must not be cited
as one.

### What this instrument cannot see

Stated because check 44's lesson is that a detector reports its own reach
and not the defect's size:

- **A shift present in BOTH layers.** Check 40's `cuvs-plus` 1 Chronicles
  22 defect is exactly that: the text and its Strong's tags carried the
  identical one-verse shift, so they agreed with each other and this
  screen would have passed them at 100.0000%. Catching that needed a
  third layer. **This check guards against one layer drifting off the
  other, never against both drifting together, and it must not be cited
  as though it did.**
- **A wrong Strong's number or a wrong parse.** It compares WORDS only.
- **The content of a `<note: …>`.** `_TAG` deletes the whole tag from the
  flat side, and in `cuvs-yhwh` that content is real 和合本 parenthetical
  text. Beyond the 372 there are **47 further verses this audit passes**
  where the note's words are absent from or differently worded in the
  tagged layer (Deuteronomy 6:4, 1 Kings 8:20, 10:5, 10:15, Numbers
  35:33, Leviticus 25:25 among them). Unmeasured, and named so the pass
  is not read as covering it. `cuvs-plus`: 0.
- **The string the reader is actually shown for `cuvs-yhwh`.**
  `TaggedTextService._load` runs `reuniteGlossRuns`, which rewrites 198
  verses at load time. This audit and its test both read the **raw
  asset**, so for that edition they measure the file and not the screen.
- **Whether the flat text itself is right** — in general. 45d found 79
  cases only because a second layer disagreed; where both layers hold the
  same wrong word, nothing here objects. Checks 24, 26, 27 and 31 own
  that question.

Regression test: `test/tagged_layer_coverage_test.dart`, seven tests. It
re-derives every figure above from the assets rather than restating them,
and it reads `verseAbsenceOf` from `lib/utils/verse_text_absence.dart`,
so it also witnesses that table from the other direction.

---

### 45g — the third witness failed, 22 verses repaired anyway, and 21 defects in the reading text

*2026-08-23.* `tools/adjudicate_cuvs_yhwh.py`. Check 45d ended on a
deadlock it stated honestly — "neither layer is the authority; each
caught the other" — and the obvious way out was a third file.
`assets/cuvs-plus.json` is a second 和合本 already in this repository,
imported separately. **It does not work, and that is the first finding.**

**`cuvs-plus` is descent, not independence.** Folded for the divine-name
restoration and reduced to Han characters, it matches the reading text in
**29,790 of 31,102 verses (95.78%)** and, character for character, in
**917,572 of 920,316 (99.70%)**. No two independent translations of the
Bible agree to 99.7% of characters. The doc already said this in prose
— "the same base text as cuvs-yhwh but imported separately" — and the
measurement is what that sentence means.

So a 2-of-3 majority is worthless here, and this is not theoretical: the
first version of the script trusted it and proposed **deleting the 六
from Judges 12:7**, where both flat editions read 「作以色列的士师年」 —
Jephthah judged Israel "_ years" — and only the tagged layer keeps the
six. That is check 26's lesson a second time, and the reason the script
survives as a *report* with a deliberately narrow repair gate.

**What was repaired: 22 verses, in the two classes that need no vote,**
because neither is a reading any edition holds.

| class | verses | what it was |
| --- | --- | --- |
| A. a literal `#` drawn as scripture | 15 (17 marks) | the MySword module's stand-in for a supplied word; the reading text prints `[基督]` at all 17 |
| B. a character doubled against itself | 7 | 若若, 箭箭, 未未曾, 我们我们, 你要要, 以以色列, 耶稣说说 |

Both were settled without consulting any witness: `#` is not a Chinese
character, and a character doubled where **both** flat editions read it
once is a duplication artefact rather than a variant. Confirmation from
an instrument that knows nothing about this script — `audit_tagged_layer.py`
went from **372 disagreements to 350**, exactly the 22 touched.

**What was found and NOT repaired: 21 word-level defects in the reading
text** — scripture as the reader sees it, which this script does not
write to.

- **12 where the reading text stands alone** against both other files:
  Joshua 5:9 辊/滚, 1 Samuel 15:12 a spurious 纪, 2 Kings 3:2 至/致,
  Nehemiah 2:19 and 3:3 spurious pronouns, **Isaiah 23:1 missing the 推
  of 推罗, so the verse no longer names Tyre**, Isaiah 30:24 锨/杴,
  Isaiah 64:3 and Acts 25:18 意/逆, Jeremiah 7:20 着/里, Jeremiah 50:32
  a spurious 里, **Lamentations 3:1 a 神 the 和合本 does not have**.
- **9 where BOTH flat editions have lost a word the tagged layer keeps**:
  Judges 9:57 (他 — the page reads 「咒诅归到们身上」, and 们 cannot stand
  alone), 12:7 (六), 15:2 (我请求, H4994 נָא), 15:5 (葡萄园), 15:18
  (现在, H6258), 2 Samuel 5:17 (众), 21:2 (the 大 of 大发热心), Esther
  6:7 (人), Malachi 2:3 (the 在 of 抹在). **These are exactly the verses
  a majority vote destroys**, and they became findable only by refusing
  the majority.

Their direction is not mechanical and the script does not pretend it is.
It groups them; each was then read against the Strong's number its
characters carry, and the ten verdicts are written into `ADJUDICATED` so
they can be re-checked rather than believed. A guard prints a warning if
that table ever drifts from what the script finds.

**One of the ten went the other way, and it is the reason the table is
not a rule.** Job 31:36's tagged run is 「愿那敌我敌」 under a *single*
H7379 (רִיב) — one word with a duplicated character — so there the
reading text 「愿那敌我者」 is correct and the tagged layer is wrong. It
is the same defect as the seven class-B repairs but **non-adjacent**, so
the doubled-character gate could not see it. Had the nine-of-ten pattern
been applied as a rule, this verse would have been damaged.

Two further groups are named because they are *not* the same finding:
**15** verses where the tagged layer prints inline what the reading text
files as a `<note: …>` (placement, not loss — separated by testing the
note bodies specifically, since a raw substring test both misses
1 Samuel 1:24's punctuated note and falsely "finds" Judges 9:57's 他
three clauses away), and **10** one-for-one substitutions (嗐/咳, 丕/墩,
抄/挲) that remain undecidable without a source outside this repository.

**Side finding, and the count in it was wrong twice before it was right.**
`cuvs-yhwh` has **25 verses whose 〔 and 〕 counts differ** (`cuvs-yhwh-tr`
the same 25; `cuvs-plus` and `biblexg-v2` have 0), and the first draft of
this section called all 25 a defect and cited Matthew 18:10 "ending on a
dangling 〔有古卷在此有". **That was wrong.** 和合本 opens a textual note
in one verse and closes it in a later one, so 22 of the 25 are **11
correct cross-verse pairs** — Matthew 18:10 opens the note that 18:11
closes, which is the convention working, not failing.

Counting the brackets over the whole edition is what settles it: **12 〔
against 13 〕**. Exactly three are genuinely unmatched, and all three are
reader-visible:

| verse | what is on the page |
| --- | --- |
| 士师记 8:24 | ends 「都是戴金耳环的。〕」 — a closing bracket nothing opened |
| 耶利米书 10:11 | ends 「必从地上从天下被除灭！〕」 — the same |
| 路加福音 8:45 | opens 〔 and closes with an **ASCII `)`** — 「你还问摸我的是谁吗？)」 |

Reported, not fixed: the first two need the 和合本 consulted for where the
〔 belongs, and none of the three is a wrong *word*.

Blind spots: note **content** is stripped from all three sides, so a word
difference living inside a note is invisible here; and where all three
files inherit the same wrong character nothing objects — Judges 12:7
shows two of the three routinely do.

Regression test: `test/cuvs_yhwh_tagged_layer_test.dart`, two new tests.
Each of their eight assertions was checked to **fail against the
pre-repair asset** — the doubled-character ones needed the character
*before* the stutter in the fragment, because a doubled character
otherwise just shifts the match one place right and the assertion passes
on the damaged text.

---

## Check 46 — the twenty-one the last check refused to vote on

Check 45g ended by naming **21 word-level defects in the reading text**
— the layer the app actually prints — and deliberately not repairing
them, because the only available tiebreaker was a majority and the
majority was wrong. This check reads them one at a time.

| | verses | note |
|---|---|---|
| candidates from `adjudicate_cuvs_yhwh.py` | 21 | 12 standing alone, 9 where both flat editions lost a word |
| **repaired** from that 21 | **6** | |
| reported, deliberately not repaired | **15** | attested variants, archaisms, supplied words |
| **found by a new sweep, repaired** | **6** | invisible to the adjudicator by construction |
| drafted as a repair and **withdrawn** | **1** | 瑪拉基書 2:3 |
| records written | **38** | across 5 asset groups, both scripts |
| `audit_tagged_layer.py` `cuvs-yhwh` | 350 → **345** | |

### 46a — the criterion, because the value is the line not the list

> **REPAIR only where the reading text is not a possible reading of
> Chinese at all, or where the original-language text we already ship
> names a word that is absent.** Orthographic variants, archaisms,
> supplied words, word order and editorial expansions are REPORTED and
> left alone.

Every repair is carried by `assets/originals/` — the OSHB/MorphGNT
layer, from outside this line of transmission — or by the text not
being readable. **Not** by a vote: `cuvs-plus` matches the reading text
on 99.70% of characters, so its agreement can only inherit a loss, and
the tagged layer invents text twice in this very sample (Judges 15:5
splits the construct chain כֶּרֶם זַיִת into 葡萄园橄榄园, conjuring a
vineyard; Job 31:36 doubles an H7379 run against itself).

**Fifteen left alone, and the reasons are the useful part**: Joshua 5:9
辊 is directly attested in the old spaced 和合本; 2 Kings 3:2 不至 —
this file writes 不至 60 times and 不致 55; Isaiah 30:24 锨/杴 — H7371 is
a hapax, so there is no internal witness either way; Isaiah 64:3 and
Acts 25:18 意料 — used in **2 of 2** places and 逆料 in none, which is a
consistent lexical choice, not a slip; Lamentations 3:1 雅伟神 — the
Hebrew has **no divine name here at all** and the tagged layer marks it
H0, supplied; and seven (Nehemiah 2:19, Nehemiah 3:3, 2 Samuel 5:17,
2 Samuel 21:2, Esther 6:7, Judges 15:2, Judges 15:18) that read
correctly with or without the disputed word.

### 46b — six more the adjudicator could not see, and why

Its rule was "the reading text stands alone against both other files",
which by construction finds nothing where the tagged layer inherited
the same loss. `test/tagged_layer_coverage_test.dart` had already
named this blind spot in its own header — *a shift present in BOTH
layers passes at 100%* — and this is that blind spot paying out.

Asking the question the other way round (strip every mark of
punctuation and every note from both flat editions, diff on Han
characters alone) gives **89 sites where the sibling holds 1–3
characters we lack**. Almost all are noise: inline note markers the
sibling renders as text (或译/或作/原文), its own dittographies
(1 John 4:2 出于神的**的**, Acts 28:18 该死的罪。**罪。**), word order,
and places where **our** text is the better reading — Jeremiah 7:14
称我为名下 is genuine 和合本 which the sibling modernised, and
Deuteronomy 32:19's 说 is not missing at all: our flat text *and* our
tagged layer put it at the head of 32:20 under H559 וַיֹּאמֶר, where the
Hebrew has it, while the sibling moved it back a verse and left H559
with no Chinese.

**Six meet the criterion**, and the reader was seeing all six:

> 出埃及記 15:7 烧灭他们像烧碎**一样** — the thing they burn *like*
> (H7179 קַשׁ, stubble) is gone · 士師記 12:13 作**以色**的士师 — 以色
> names nothing · 尼希米記 8:4 木台上。**站**玛他提雅…和玛西雅在他的右边
> — 站 displaced to the head of the name list · 箴言 22:11 因他**嘴**的
> 恩言…王必与他为**上友** — the 上 of 嘴上 displaced across the verse ·
> 詩篇 78:44 江河并**河**的水 · 撒迦利亞書 11:15 愚昧**人**所用的器具 —
> the chapter is about the foolish *shepherd*, H7462 רֹעֶה

Two of those are **transpositions, not dropouts**, and they matter
because a detector looking for missing characters cannot see them: the
verse has the right number of characters, one of them in the wrong
place. Our own tagged layer carries five of the six; 尼希米記 8:4 is the
exception and reads correctly — but that is corroboration and not
proof, since across the 16 places where the flat text and its tagged
layer differ by a pure transposition, **the tagged layer is the corrupt
side in 15**.

### 46c — one Strong's number corrected, and the measurement that let it be

At 出埃及記 15:7 the tagged layer read `像烧碎` tagged **H1** — אָב,
*father*. It is now H7179, which is what OSHB puts at that position.
Re-tagging is a bigger claim than inserting a character, so H1 was
measured first: it occurs **1,078 times** and is not a sentinel — every
other one is a real sense of אָב (父亲, 之祖, 族长, 先人, 继母, 伯叔,
姑母). Of the **33** whose text contains no 父/祖/宗, 出埃及記 15:7 is the
only one unrelated to fatherhood. **A singleton, not a class.**

### 46d — the repair that was drafted and withdrawn

瑪拉基書 2:3 was going to become 把你们牺牲的粪抹**在**你们的脸上, on the
grounds that *抹 cannot take a location without 在* and that H5921 עַל
was unrendered. **Both halves are false.** This edition writes 抹 with a
bare object eight times — 抹他的舌头, 抹我的脚, 抹墙, 又用油抹你 — and
the tagged layer puts H5921 on the run 你们的脸**上**, so 上 *is* עַל
and the proposed 在 renders nothing. A published 和合本 reads it exactly
as we ship it. The 在 exists in **one file of five**, our own tagged
layer, where it is an intrusion; left there rather than re-cut, because
re-cutting another layer's boundaries on our own authority is the thing
this check exists to avoid.

### 46e — a witness that was really a copy, for the second time

An earlier pass checked these against `bolls.life/CUV`, found it
reproduced them character for character, and concluded the reading text
was a faithful copy of an already-defective ancestor. **Withdrawn.**
That text carries our 燒滅他們像燒碎一樣 and our 作以色列的士師年 *and* a
defect of its own we do not have — 以便之後 for 以倫之後 at Judges
12:13. It is a fellow descendant of the same corrupt e-text, so its
agreement was never evidence. 信望愛 (fhl.net, `VERSION1=unv`) reads all
twelve as this check writes them.

That is the same shape as check 45g's finding about `cuvs-plus`, and as
check 26's about its external export, three times now: **ask what a
witness descends from before counting its vote.** Where the corruption
entered is *not established* and the record should not pretend
otherwise. It does not change the decision — an app printing
归到们身上 tells its reader something scripture does not say, whoever
introduced it — but it is a smaller claim than the draft made.

### 46f — eleven characters that were rendering as nothing on web

Incidental, found by obeying the rule that new data means re-running
`tools/build_font_subsets.py`. The regenerated CJK subset gained **11
code points** — 勳 橈 氫 蝨 軒 轅 鈣 鉑 鉚 鎬 鏃 — and **none of them
were the 秸/汊 this check added**, which were already covered. All
eleven are in `assets/bible_evidence.json`. On Flutter web an uncovered
code point renders as **absent text, not tofu**, so they were silently
missing from the Biblical Evidence Archive.

`test/bundled_font_coverage_test.dart` did not catch this because it
scans only `assets/originals` and `assets/strongs` — **the guard is
narrower than the generator it guards.** Fixed by regenerating; the
test's reach is recorded here rather than widened in passing, because
widening it is a separate change with its own verification.

### 46g — the repair was written in a layout that hid it

Check 46 was interrupted before it committed, and the tree it left
behind reported **435,535 deleted lines** across the two flat editions.
Nothing was lost — both files still held **155,510 leaves**, the same as
`HEAD`, with 0 added and 0 removed and exactly 12 values changed — but
`repair_cuvs_yhwh_reading_text.py` wrote them with
`separators=(',', ':')` while the shipped files are pretty-printed at
indent 2. The whole edition reflowed onto one line, and the twelve-verse
correction went with it.

**The cost is not disk, it is review.** A twelve-line diff can be read
against the 和合本 by a person; a 435,535-line one cannot, and every
verse in both books loses its `git blame`. Re-serialising at indent 2
reproduces `HEAD` byte for byte, so the change is now 24 lines — the
twelve verses, twice.

This is the **second** time this trap has been paid for; the first
buried a 19-verse correction the same way, which is why
`tools/repair_reference_defects.py` already carries a `write_like()`.
The repair script now carries one too: it reads the first bytes of the
file back and follows the layout it finds, so the flat editions stay
pretty-printed and `cuvs-plus` and the tagged layers stay minified.
Verified by round-tripping all nine assets this check touched —
**9 of 9 byte-identical**.

**Pretty-printing is not free, but it is nearly free.** Minified saves
1,119,674 bytes raw and only **40,392 gzipped** — 2.7% — and these
assets are served compressed. ~80 KB across both files is the price of a
diff a human can check, on a corpus whose whole purpose is being
checkable.

**Not fixed here, and worth an iteration:**
`tools/import_yahwehdehua_export.py`, `tools/import_yahweh_modules.py`
and `tools/repair_biblexg_v2_tr.py` all write Bible JSON with no layout
detection. They are the same loaded gun; they were not touched because
verifying each one needs its own asset round-trip.

*(Also reverted here: `NotoSansExt-Sub.ttf` and `NotoSansHebrew-Sub.ttf`
came back from the font rebuild with identical size and **identical
code-point coverage**, differing only in the `head` table's `modified`
timestamp. Two binaries of pure rebuild noise. Only the CJK subset,
which genuinely gained the 11 code points above, was kept.)*

---

## Next, in order

**First, and deliberately unnumbered so the citations below stay
true: `assets/biblexg-v2.json` is missing 馬可福音 6:8-11, and 6:7 is
truncated mid-clause.** Check 41f. Four verses of a shipped New
Testament are absent and a fifth stops in the middle of a sentence.
The corpus has been measured and this is the *only* such gap — every
other missing verse in every Bible asset is a critical-text omission
shared by all editions. The text is present in `biblexg-v2-tr.json`,
but the two editions agree only 78.0% under `t2s`, so recovering it by
conversion would fabricate house-style spellings. This needs the
upstream source or an owner's decision and must not be taken
unattended. **By the accuracy rule it outranks everything below**: a
missing verse is the strongest form of the app saying something untrue
about the text.

*(The second unnumbered item — the 21 word-level defects in `cuvs-yhwh`'s
reading text — is **closed by check 46**: 6 of the 21 repaired, 15
reported and left alone, 1 drafted and withdrawn, and 6 more found by a
sweep the adjudicator was structurally unable to run. 38 records
written; the tagged-layer disagreement fell 350 → 345.)*

**Second, and the one to take next: the 27 remaining single-character
sites `tools/sweep_flat_dropouts.py` reports.** Check 46 read the 34 that
existed before it and repaired 7; the rest were left because a short
difference between two editions is usually editorial, not a defect. But
they were adjudicated as a residue, quickly, at the end of a long
iteration — three 说, three 们, three 的 — and the 们 sites in particular
are the same shape as 士師記 9:57 归到们, which *was* a defect. Re-read
them individually.

**The conditions from 45g still bind, and check 46 strengthened them.**
Do not resolve by majority: `cuvs-plus` agrees with the reading text on
99.70% of characters, so it is a *descendant*, not a witness. Neither is
`bolls.life/CUV`, which reproduces seven of our defects **and carries one
we do not have** (以便之後 for 以倫之後 at 士師記 12:13) — a shared error
is evidence of shared ancestry, not of correctness. And our own tagged
layer is inadmissible on word order: across the 16 pure transpositions
measured in check 46, it is the corrupt side in 15.

Still open beneath it, and much smaller than it first looked: **three
broken note delimiters** in `cuvs-yhwh` — 士师记 8:24 and 耶利米书 10:11
end on a 〕 nothing opened, and 路加福音 8:45 closes its 〔 with an ASCII
`)`. The other 22 of the 25 verses that fail a per-verse bracket count
are legitimate notes spanning a verse boundary; see 45g.

Also here, and small: `kwic_pane.dart:127` drops a line whose runs are
null while still counting the reference, so its "All N references" footer
overstates on `lxxwh`.

And one raised by check 46 but deliberately not fixed in it:
**`test/bundled_font_coverage_test.dart` is narrower than the generator
it guards.** It scans `assets/originals` and `assets/strongs`;
`tools/build_font_subsets.py` ingests far more, which is how 11 code
points in `assets/bible_evidence.json` came to be rendering as nothing at
all on web. The subset was rebuilt; the guard was not widened, because
widening it is its own change with its own ratchet. See 46f.

   *(This list's item 0, "the Strong's Chinese gloss, cut at the printed
   line break", is closed by check 44g — 488 entries repaired, the real
   scope 593 against the 279 a separator test reported.)*
0. **What `assets/kjv.json` actually is.** Check 27 established that it
   is not the King James Version but an unidentified Americanised
   revision of it — not the AKJV (34.1%) and not Webster (39.0%). The
   app labels it "KJV", which is a provenance claim the file does not
   support. This is a naming decision (#285), so it is stated and left.
   Either relabel it, or replace it with a text that is what the label
   says; both are the owner's call and neither should be taken
   unattended.
   *(This list's item 1, "the psalm superscriptions are not searchable",
   is closed by check 33 — and asking why one of its own queries still
   failed afterwards found a defect 146× larger, in 16,975 verses that
   have no superscription. Its predecessor as item 1, "the remaining
   English editions against an external witness", is closed by check 31a
   for every edition that can be witnessed. `assets/nasb.json` cannot
   be — no public-domain NASB exists — so it moved to "Not checked yet"
   as a standing limitation rather than a task.)*
1. **A Westcott-Hort text keyed by its OWN numbering.** Check 34 tested
   every one of `lxxwh`'s own-verse-number markers against an outside
   witness — 4,687 then, **4,543** now that its vacuous ones are
   dropped — and repaired three defects, but the New Testament's
   19 are still unverified and cannot be verified by the witness this
   repository has: `api.getbible.net/v2/westcotthort` is keyed by the
   **English** reference, so the marked number cannot be looked up in
   it. A source that numbers the verses the way WH does would close
   this in one pass, the way check 29's LXX closed the Old Testament's
   4,528.
   *(Its predecessor as item 1, "Matthew 12:47", is settled by check
   34d: the WH witness has it and brackets it, but we carry the only
   other verse it brackets, so the absence is ours and not the
   edition's. It is reported and deliberately not repaired — importing
   Greek from a variant-inlining witness into one layer of two is a
   decision about what the product contains, and is the owner's.)*
2. **The 153 Greek verses our Septuagint names and does not carry.**
   Check 39 found them with no outside source at all: the edition's own
   `<vs:>` markers number a verse at 32 sites where the file has no
   record, English Psalm 116:14 (Greek 115:5) among them. They are
   reported and deliberately not repaired, on check 34d's precedent —
   Greek would have to go into the flat asset *and* the tagged layer,
   and what the product contains is the owner's call. Whoever takes it
   needs a witness numbered the Greek's way, which is the same thing
   item 1 needs.
   *(Its predecessor, "the English tradition's merges in the
   Septuagint's 302", is closed by check 39: the count is 7, they are
   named in `kEditionMergedHeads`, and check 29c's second example was
   false. What that check could **not** rule out is a merge whose Greek
   is compressed enough to leave the preceding record no longer than its
   own English predicts — 80 of the 302 sit in that band.)*
3. The 4 references the two 梁家鏗譯本 editions still disagree about —
   马可福音 6:8–11, all that is left of the original 8. Needs a witness that is the
   same edition in the missing script; a 简/繁 conversion table derived
   from the 7,645 length-equal verse pairs the two files already share
   would be one, and would be witnessed by the corpus rather than
   invented — but it must be derived and checked before a character of
   it is trusted.
4. Per-record date sourcing (#292 owns `hebrew_kings.json`).
5. **The family tree's two decisions, from check 36.** Neither is an
   engineering task and neither should be taken unattended. *(a)* The
   tree draws an inferred link — Heli → Mary, Eve → Seth — with the same
   solid line as Genesis 5:3, because the model has no field for it;
   adding one, and deciding how to draw it, is a product call, and the
   5 named links are a lower bound because the instrument cannot see an
   inferred link whose two people are named a few verses apart. *(b)*
   Reuben is 吕便 in six places in the file and 流便 in two, one of them
   inside a record whose own summary says the other; the CUV the app
   ships reads 流便 85 times and 吕便 never. One minute of a Chinese
   reader's judgement settles it and nothing else can.
6. The LEB's `{…}` idiom braces in the 660 imported verses, if a witness
   that preserves them can be found.
7. The ten summarised Chinese sermons (check 19). Not an engineering
   task — ~85,000 English words need translating, and whether that
   happens, and by whom, is the owner's call. Until it does, the marking
   is the honest state.
7b. **The 28 truncated etymologies in the Chinese lexicons** (check
   43c). A field the importer cut mid-clause, rendering today in the
   word-study pane. Owned by #301, which already re-opens that import;
   the detector is written and the fix belongs in the generator, not in
   the shipped asset.
8. The remaining verse-rendering surfaces, audited but not exhaustively:
   check 14 covers the reader, Browse, the sermon-citation popup, the
   two search-key caches and the clipboard. Strong's-driven surfaces
   (KWIC, concordance) read the tagged layer, which a placeholder has no
   entry in, so they cannot show one — reasoned, not measured.
9. ~~**The 207 Simplified-looking characters in `biblexg-v2-tr.json`.**~~
   **Closed by check 41.** The true count was "unknown and deliberately
   not written down"; it is **30 characters in 28 verses**, in five
   classes, and only 12 of them were visible to the screen that produced
   the 207. The instrument was the edition's own Simplified twin — where
   the converter made the same decision 1,993 times and the opposite one
   4 times, the 4 are the defect — so no outside Traditional authority
   was needed. It also named a defect class that screen structurally
   cannot see: **over**-conversion (準許→准許, 矇住→蒙住), where the
   wrong output is still a real Traditional character.

   What remains open from this item is a **product decision, not a
   measurement**: 一台戲, 游手好閒 ×4 and 包紥 ×1 are left as they stand
   because the standard forms occur zero times in either 繁體 edition,
   and the Simplified `biblexg-v2.json` still prints the upstream typo
   颤斗 at 馬可福音 16:8 and 使徒行傳 7:32. See 41d.

   *(This ranked above item 3 by the accuracy rule — a wrong character
   in a printed verse, not a label or a missing pane. The numbers above
   are left as they are because five closed sections cite them by
   number, and renumbering would make those citations false.)*

*(Check 26 came off the "Not checked yet" list rather than this one, and
it is the clearest case yet for the rule that a witness must come from
outside: 恉 and 逿 are in every plain Chinese file we ship, and only the
tagged layer and an external export read them correctly. Its own lesson
is narrower and sharper — the witness carried 44 of the same 丶 we did,
so "both copies agree" and "the reading is right" are different claims,
and a majority vote across four texts would have entrenched three of the
six defects.)*

*(Check 24 was not on this list at all. It came from re-reading the
standing rule "a wrong parsing code jumps ahead of every feature" against
the results table and noticing that check 2b proved codes **decode** and
never that they are **true** — the largest column in the app, never
checked for truth. The lesson generalises: this list is made of questions
already asked, and the most valuable check may be one nobody has phrased
yet. The Septuagint half of `lxxwh` was the third bullet under "Not
checked yet", on the grounds that it had no same-language witness. It had one —
its own New Testament half — and check 23 is what that witness said.
Check 20, "does any other book carry a cuvs-plus-style shift", was the
first bullet under "Not checked yet" and is now measured: no, and four
references of a narrower defect were found and fixed on the way. Check
15, the concordance's 500-entry verse cap, was fifth here and is
now fixed. The merge-marker presentation was second here and is now
check 14. Check 9, the Hebrew/English versification mismatch, was first
here and is now fixed. `assets/leb.json`'s missing books were second and are now
fixed. The 2,203 words with no morphology code were third and are now
869. cuvs-plus's "60 gaps" were fourth, and turned out not to be gaps at
all — see check 4 — but chasing them found eight other classes that
were.)*
