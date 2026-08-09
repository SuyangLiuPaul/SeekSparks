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
| 9 | Tagged layers agree with `assets/originals` | 5 layers × 66 books | 152 keys / 204+ verses each | **open, worst finding** |

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
| leb | 30,552 | **64** | 32 | 2 | **Judges and Obadiah absent entirely** |
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

*Not legitimate, and unfixable here.* **`assets/leb.json` is missing
Judges (618 verses) and Obadiah (21) outright** — an import gap, not a
versification choice. A reader on LEB cannot reach either book. This is
not repaired because repairing it means obtaining the Lexham text, and
**scripture is never invented to close a gap**. Filed as a task, not a
fix. `assets/cuvs-plus.json`'s remaining 60 gaps (Numbers 16,
Deuteronomy 7, Psalms 4, Job 3, Jeremiah 3 …) are the same shape and
need the same treatment: check them against 和合本 before assuming
either way.

**Check 9 — `assets/originals` is numbered in Hebrew versification and
every display surface asks it in English. This is the worst thing the
audit found, and it is not fixed.**

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

Not repaired here, deliberately. The fix is a Hebrew↔English
versification mapping for the affected books, taken from a citable
source and recorded in the asset — the same sourcing rule #292 applies
to dates. Deriving it by arithmetic from the verse counts would be
guessing at scripture, which is the one thing this document exists to
prevent. It is the next slice, and it is larger than one book.

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

1. **Check 9** — the Hebrew/English versification mismatch. Wrong Hebrew
   is shown today, in Joel above all.
2. `assets/leb.json`'s missing Judges and Obadiah.
3. The 2,203 words with no morphology code.
4. Per-record date sourcing (#292 owns `hebrew_kings.json`).
5. `assets/cuvs-plus.json`'s remaining 60 gaps, checked against 和合本.
