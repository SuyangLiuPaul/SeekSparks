# 梁家鏗譯本 — where it comes from, and how to update it

The LJK New Testament (`biblexg-*`) is the one edition in this app that
is re-fetched from a live publisher rather than imported once from a
fixed file. This is the procedure for doing that, and the record of
what goes wrong when a step is skipped.

## Source

    https://mattwhatsup.github.io/ljk-nt-bible-webapp/resources/<lang>-<book>.json

`<lang>` is `cn` (简体) or `tw` (繁體); `<book>` is the publisher's own
abbreviation (`mt`, `mk`, `1co`, `rev` …). The 27 books × 2 scripts are
54 files. `tools/import_ljk2.py` holds the book table and the mapping to
this app's book names; nothing else needs the URL.

Shape of one file: a list of chapters, each `{verseList, nodeData}`.
Node types are `chapter | verse | comment | comment-list |
ul-comment-list`. A verse's `contents` are `{lineBreak, content}`
segments where `lineBreak` is `inline | line | paragraph | reference`,
and the content is HTML — `<cite>` for a translator's note, `<mark
class="greek|hebrew">` for original-language words, `<sup>` for a verse
number the publisher printed inside running text.

## The pipeline — five steps, in this order

```bash
python3 tools/import_ljk2.py            --code biblexg-v3 --force
python3 tools/repair_biblexg.py         --code biblexg-v3 --write
python3 tools/repair_verse_numbering.py --code biblexg-v3
python3 tools/repair_biblexg_v2_tr.py   --code biblexg-v3-tr
python3 tools/carry_forward_ljk.py      --code biblexg-v3 --from biblexg-v2 --write
```

`import_ljk2.py` prints this list at the end of every run, so the
authority is the tool, not this file.

**Each step is here because leaving it out shipped a defect**, and four
of the five were learned that way:

| # | Step | What it does | What happened when it was skipped |
|---|---|---|---|
| 1 | `import_ljk2` | Converts upstream HTML to our row shape | — |
| 2 | `repair_biblexg` | Splits verses the converter merged into one row | Rev 5:11-14 printed inside 5:10, notes and all |
| 3 | `repair_verse_numbering` | Re-keys rows numbered by the edition's own versification | The grace benediction answered 2 Cor **13:13**, beside a KJV column reading "All the saints salute you"; Acts **8:41** came back |
| 4 | `repair_biblexg_v2_tr` | Fixes the 30 characters the publisher's 繁體 conversion got wrong | 「在他們的會堂**里**」, 「耶穌**準**許」, 「渾身顫**斗**」 all returned |
| 5 | `carry_forward_ljk` | Fills what is STILL missing, from the previous snapshot | Ran early once: filled four verses with the OLD snapshot's wording when step 2 could have recovered them from the new fetch |

Step 5 should report **0 carried**. A non-zero number means the new
fetch genuinely lost something the old one had — read the list before
accepting it.

## Why the steps are named sites and not sweeps

Every repair is guarded on the text it expects to find and refuses
rather than guesses. This is not caution for its own sake:

* A blanket `opencc -c s2t` over a Traditional file invents a defect at
  以賽亞書 29:17 (「只有」 → 「隻有」). `assets/cuvs-yhwh-tr.json` was
  damaged exactly that way.
* The Traditional file is made FROM the Simplified one, so the
  conversion's own decisions are the witness against itself: where it
  decided one way 1,993 times and the other way 4 times, the 4 are the
  defect. That is a check with no outside source and no judgement call.

A guard firing is the system working. On 2026-09-14 step 4 refused
because 哥林多前書 15:3 no longer matched: the publisher had **rewritten
the verse** — 「我領受了的，第一重要的就是：基督按照聖經所記」 became
「我領受的，第一重要的是：正如聖經所記，基督」 — and had corrected the
舊字形 爲 → 為 themselves. The rule retired itself for that edition, and
`traditional_forms_test.dart` was changed to pin the character rather
than the sentence, so the next revision of the wording does not break it
again.

## Registering a new revision as its own edition

The owner's rule is 「现有的也留着但是隐藏」 — keep the old one, hide it.
A revision therefore ships as a NEW code and the old one stays in the
build. Ten places have to agree, and a test guards every one:

| Where | What | Test |
|---|---|---|
| `assets/biblexg-vN{,-tr}.json` | the two assets | `biblexg_verse_boundary_test` |
| `pubspec.yaml` | asset declaration | build fails without it |
| `bible_versions.dart` → `bibleVersions` | catalog rows, labels | `version_label_scheme_test` |
| `bible_versions.dart` → `disabledVersions` | the OLD pair, hidden | `hidden_version_test`, `bible_versions_language_test` |
| `bible_versions.dart` → `retiredVersionSuccessors` | old codes → new | `retired_version_test` |
| `version_attribution.dart` | licence line | `version_label_scheme_test` |
| `workbench_theme.dart` → `kVersionTagColors` | a hand-picked colour | `version_label_scheme_test` |
| `section_title_map.dart` | section-heading source | — |
| `workbench_warmup.dart` → `defaultParallelVersions` | the Browse stack | `workbench_warmup_test`, `retired_version_test` |
| `offline_pack_service.dart`, `main.dart` | offline pack + boot preload | `boot_warm_up_test`, `offline_pack_urls_test` |

Two labelling rules bite here. A Chinese edition's `shortLabel` **must
not contain a Latin letter** — 「梁简 v2」 fails; the hidden pair is
labelled 梁简旧 / 梁繁旧. And every label is also a typed handle at the
command bar, so labels must be unique and must resolve back to their own
code.

## What is NOT repaired, and why

**馬可福音 6:8-11 are absent from the SIMPLIFIED upstream file.** The
Traditional file has them. Restoring them would require a 繁→简
conversion this repository will not invent, so they stay measured rather
than fabricated. `import_ljk2.py` prints the gap on every run and
`biblexg_verse_boundary_test.dart` freezes it at exactly four verses.
**This should be reported upstream.**

**Twenty-one range labels** (`1-4`, `18-19`) are the publisher's own
honest labelling of verses they printed merged — not a defect. Two of
them overlap a verse that also has its own row, which IS a
contradiction; both are in 以弗所書 and both are frozen at that count.

**Acts 8:40/41.** The publisher splits this verse deliberately and says
so in a chapter-end note. We join it back, for a reason about the app
and not about the text: every edition here is keyed by its ENGLISH
reference, and no English reference `Acts 8:41` exists — left split, the
second half is reachable by no cross-reference, no parallel column and
no reference search. The reasoning is recorded in full at the top of
`tools/repair_verse_numbering.py`.

## Three claims that were made here and were WRONG

Recorded because each was stated confidently before being checked, and
each survived a first look:

1. **"The 13 gaps are the translation following the critical text."**
   No. 路 22:43-44, 23:17, 約 5:4 and 徒 15:34 are all PRESENT — printed
   inline inside the preceding verse, verse number and all. Step 2 pulls
   them out.
2. **"The Traditional upstream lost seven verses."** Only 啟 5:11-14, and
   those were inline too.
3. **"約翰福音 5:4 needs a split."** The `<sup>4</sup>` was inside a
   `<cite>` note (「有較後期抄本加插」). Splitting on it would have
   promoted the tail of a footnote into scripture. The repair was written
   and then removed.

The shape of all three: a missing key looks like missing text. It is
usually mis-filed text, and the file itself says where.
