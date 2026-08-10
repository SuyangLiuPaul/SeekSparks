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
| 24d | Does `assets/forms/` carry the parse the corpus carries | 136,067 form triples | **1,243 blank where the corpus has one** → **0** | **fixed**, now a test |

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

## Not checked yet

- Verse **text** itself, against an *external* witness — for the
  **translations**. Check 24 closed this for the original languages
  almost by accident: aligning against MorphGNT and OSHB matched 99.31%
  of Greek and 99.59% of Hebrew words *by surface form*, which is an
  external witness to the text and not only to its codes. The 951 + 1,240
  words that did not align are the honest residue and are listed there.
  For the English and Chinese editions this remains open: a verse that is
  wrong *and* well-formed *and* agrees with our own second copy is still
  unchecked. `test/cuvs_yhwh_integrity_test.dart` does this for two
  verses; there is no general method without an external source.
- `section_titles.json`, `book_introductions.json`, `bible_evidence.json`,
  `maps_index.json` (see #300 for its provenance gap), `family_tree.json`
  relationships, `ot_synopsis.json` alignments.
- The Septuagint's **verse text**, as opposed to its Strong's numbers.
  Check 23 measured the numbers and repaired them; nothing has asked
  whether the Greek itself is complete. Nehemiah 10 is known to be
  missing 15 of its 39 verses from the tagged import (check 21), and that
  gap has never been chased across the other books.
- The **41,032 Septuagint runs that still answer nothing** (check 23).
  Most cannot be answered — they are words the New Testament never uses —
  but nobody has separated "no Strong's number exists" from "a number
  exists and this edition does not know it". An LXX-specific lexicon
  would settle it; the repo has none.

## Next, in order

1. The 4 references the two 梁家鏗譯本 editions still disagree about —
   马可福音 6:8–11, all that is left of the original 8. Needs a witness that is the
   same edition in the missing script; a 简/繁 conversion table derived
   from the 7,645 length-equal verse pairs the two files already share
   would be one, and would be witnessed by the corpus rather than
   invented — but it must be derived and checked before a character of
   it is trusted.
2. The four verses that print both the Ketiv and the Qere. Probably a
   reader-side marker, not a data deletion.
3. Per-record date sourcing (#292 owns `hebrew_kings.json`).
4. The LEB's `{…}` idiom braces in the 660 imported verses, if a witness
   that preserves them can be found.
5. The ten summarised Chinese sermons (check 19). Not an engineering
   task — ~85,000 English words need translating, and whether that
   happens, and by whom, is the owner's call. Until it does, the marking
   is the honest state.
6. The remaining verse-rendering surfaces, audited but not exhaustively:
   check 14 covers the reader, Browse, the sermon-citation popup, the
   two search-key caches and the clipboard. Strong's-driven surfaces
   (KWIC, concordance) read the tagged layer, which a placeholder has no
   entry in, so they cannot show one — reasoned, not measured.

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
