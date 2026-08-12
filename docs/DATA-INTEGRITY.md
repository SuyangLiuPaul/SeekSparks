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
| 8 | Dates carry a recorded source | 196 records | 1 file | **open** |
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

**Four verses print the Ketiv and the Qere as two consecutive words** —
2 Samuel 18:20, Jeremiah 51:3, Ezekiel 48:16, Proverbs 8:35. A reader of
2 Samuel 18:20 sees `כי על על כן`, a doubled word. This is a defect of
the shipped `assets/originals`, found while fixing check 2a, and it is
**not** the same thing as the 1,257 unpointed Hebrew words corpus-wide —
those are the ordinary Ketiv-unpointed convention and are correct.

Left open deliberately. Deleting a word from shipped scripture is a
text-editorial decision, and the right repair is almost certainly a
Ketiv/Qere marker in the reader rather than a deletion, which is a UI
slice, not a data one.

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

**Check 8 — no date shown to a reader carries a per-record source.**
`bible_timeline.json` (98 dated records) and `hebrew_kings.json` (97)
have file-level provenance; `family_tree.json` has none at all. Per
#292, `hebrew_kings.json` should name Thiele on the record. This is the
weakest area in the audit and the one where a wrong number is least
checkable by a reader — see #292 and #300, which already own it.

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
is the doubled Qere at 2 Samuel 18:20, listed under "Open" above.

Word Study now **says so** instead of rendering nothing: a missing parse
prints a bordered line naming the corpus it was measured against
(SBLGNT for Greek, Open Scriptures/WLC for Hebrew). A blank that
explains itself is information; a blank that does not is a bug report.

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
- `section_titles.json`, `book_introductions.json`, `bible_evidence.json`,
  `maps_index.json` (see #300 for its provenance gap), `family_tree.json`
  relationships, `ot_synopsis.json` alignments.
- The Septuagint's **verse text**, as opposed to its Strong's numbers.
  Check 23 measured the numbers and repaired them. Check 29 has now
  asked whether the Greek is **complete** and answered it against an
  external LXX: 301 of the 303 Old-Testament absences are the
  Septuagint's own text, 2 were our defect and are fixed, and 33 of 39
  books hold every verse the witness has. What that check did *not* ask
  is whether the Greek we do carry is the **right words** — it compared
  what is present against what is present, and a wrong-but-well-formed
  verse would survive it. Nehemiah 10 is still known to be missing 15 of
  its 39 verses from the *tagged* import (check 21), which is a coverage
  gap in the tagging rather than in the text, and has never been chased
  across the other books.
- The **41,032 Septuagint runs that still answer nothing** (check 23).
  Most cannot be answered — they are words the New Testament never uses —
  but nobody has separated "no Strong's number exists" from "a number
  exists and this edition does not know it". An LXX-specific lexicon
  would settle it; the repo has none.

## Next, in order

0. **What `assets/kjv.json` actually is.** Check 27 established that it
   is not the King James Version but an unidentified Americanised
   revision of it — not the AKJV (34.1%) and not Webster (39.0%). The
   app labels it "KJV", which is a provenance claim the file does not
   support. This is a naming decision (#285), so it is stated and left.
   Either relabel it, or replace it with a text that is what the label
   says; both are the owner's call and neither should be taken
   unattended.
1. **The psalm superscriptions are not searchable.** Check 31b made 116
   psalm titles visible in the reader, in Browse and on the clipboard,
   and stopped at search: `MainProvider.searchKeys` and `wordKeys` read
   `verse.text` alone, so *"Nathan the prophet"* does not find Psalm 51.
   Including them in the key is one line and is **not** the work — a hit
   whose words the result row cannot show reads as a bug, so the result
   rows, the KWIC snippet and the jump-to-verse highlight all have to
   learn where the extra text lives. Left open deliberately rather than
   half-done.

   *(This list's previous item 1, "the remaining English editions against
   an external witness", is closed by check 31a for every edition that
   can be witnessed. `assets/nasb.json` cannot be — no public-domain NASB
   exists — so it moved to "Not checked yet" as a standing limitation
   rather than a task.)*
2. **Matthew 12:47**, the one New-Testament absence in `lxxwh` and all
   that is left of check 29's item 2 — the 梁家鏗譯本 editions' 38 and
   34 are classified in check 30, which found and repaired two live
   defects doing it. The Westcott-Hort text from the same source as
   check 29's witness would settle 12:47 in one pass.
3. **The English tradition's merges, in the Septuagint's 302.** Check
   29c found these by example and never measured them: English Psalm
   13:6's Greek is present, inside 13:5. Check 30's third derivation is
   exactly the instrument for it — `versification.json`'s `map` read for
   overlap — but the Septuagint is numbered in its *own* frame, not the
   original's, so the table does not apply unmodified and the work is
   deriving the equivalent, not reusing it.
4. The 4 references the two 梁家鏗譯本 editions still disagree about —
   马可福音 6:8–11, all that is left of the original 8. Needs a witness that is the
   same edition in the missing script; a 简/繁 conversion table derived
   from the 7,645 length-equal verse pairs the two files already share
   would be one, and would be witnessed by the corpus rather than
   invented — but it must be derived and checked before a character of
   it is trusted.
5. The four verses that print both the Ketiv and the Qere. Probably a
   reader-side marker, not a data deletion.
6. Per-record date sourcing (#292 owns `hebrew_kings.json`).
7. The LEB's `{…}` idiom braces in the 660 imported verses, if a witness
   that preserves them can be found.
8. The ten summarised Chinese sermons (check 19). Not an engineering
   task — ~85,000 English words need translating, and whether that
   happens, and by whom, is the owner's call. Until it does, the marking
   is the honest state.
8. The remaining verse-rendering surfaces, audited but not exhaustively:
   check 14 covers the reader, Browse, the sermon-citation popup, the
   two search-key caches and the clipboard. Strong's-driven surfaces
   (KWIC, concordance) read the tagged layer, which a placeholder has no
   entry in, so they cannot show one — reasoned, not measured.

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
