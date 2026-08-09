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
| 2a | Morphology codes present | 438,821 words | 2,203 words | **open**, upstream gap |
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

**Check 2a — 2,203 tagged words carry no morphology code**, across 63 of
66 books; worst John 238, Jeremiah 138, Ezekiel 136, Daniel 116, Luke
106. Those words show a blank parsing line in Word Study. This is a gap
in the offline merge (`tools/merge_morphology.py`) against MorphGNT and
OSHB, not a decoding failure — every one of the 4,037 codes that *is*
present decodes. Fixing it means going back to the upstream corpora and
is its own slice.

*Note for the next reader:* the #304 brief predicted "undecodable codes
are rendering blank in Word Study NOW". That prediction is **false** —
zero codes are undecodable, and an unrecognised one would fall through
to the raw string, not to blank. The blanks come from absent codes.

**Check 4 — verse coverage.** Measured per edition against KJV
versification, and only over the books an edition claims to carry, so a
NT-only edition is not "missing" the Hebrew Bible.

| Edition | Verses | Books | Gaps | Beyond canon | Note |
|---|---:|---:|---:|---:|---|
| kjv, kjvs | 31,102 | 66 | 0 | 0 | reference |
| cuvs-yhwh, cuvs-yhwh-tr | 31,102 | 66 | 0 | 0 | clean after fix 3 |
| cuvs-plus | 31,043 | 66 | 60 | 1 | clean after fix 1; 60 real omissions remain |
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

`assets/cuvs-plus.json`'s remaining 60 gaps (Numbers 16, Deuteronomy 7,
Psalms 4, Job 3, Jeremiah 3 …) are the same shape as the LEB's was and
need the same treatment: check them against 和合本 before assuming
either way.

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

## Not checked yet

- Verse **text** itself. Every check above is structural — references,
  counts, labels. Nothing compares a shipped verse against an external
  witness. `test/cuvs_yhwh_integrity_test.dart` does this for two verses;
  there is no general method that does not require an external source.
- `section_titles.json`, `book_introductions.json`, `bible_evidence.json`,
  `maps_index.json` (see #300 for its provenance gap), `family_tree.json`
  relationships, `ot_synopsis.json` alignments.
- Whether any book **other** than the ones named in check 9 carries a
  cuvs-plus-style shift. Check 9 compares key sets, so it catches a book
  where the *count* moves; it would not catch an edition that renumbered
  a chapter while keeping the same total.

## Next, in order

1. The 2,203 words with no morphology code.
2. `assets/cuvs-plus.json`'s remaining 60 gaps, checked against 和合本.
   The LEB repair is the worked example: find a second witness, prove it
   is the same edition before trusting a word of it, and repair by
   containment.
3. Per-record date sourcing (#292 owns `hebrew_kings.json`).
4. The LEB's `{…}` idiom braces in the 660 imported verses, if a witness
   that preserves them can be found.

*(Check 9, the Hebrew/English versification mismatch, was first here and
is now fixed. `assets/leb.json`'s missing books were second and are now
fixed — see above.)*
