# HANDOFF

Running log of what each autonomous iteration shipped. Newest entry on
top. One line per ship — describe what changed and why, not how.

The launchd prompt that drives these iterations expects this file to
exist and to be appended to as the last step of every run. It was
deleted by mistake in `be8176f` (the YsWords-remnant audit, 2026-07-23)
and silently missing until 2026-08-06. Recreated then with everything
back to v1.5.0 reconstructed from `git log`, plus a single new entry
for that day's ship. From here on, each run appends one line.

---

- **v1.6.15** — Phrase Matching (BibleWorks bwh51) as the seventh Analysis tab. Related Verses shipped two days earlier asks which verses share the most *words*; this asks which repeat the same *sequence*, because a bag of words cannot tell "thus says the LORD of hosts" from a verse that merely contains those five words scattered about — and finding who *quotes* a verse is a question only word order can answer. The gap is the feature rather than a tolerance: 1..G words may be inserted between phrase words, which is what lets Matthew's "and they shall call" still read as Isaiah's "and shall call", and G bounds each step rather than the whole phrase so a 3-word phrase cannot spread across half a verse. A dropped word is allowed too, but only an interior one — dropping an end word would silently turn a length-3 phrase into a length-2 one. Chopping a verse into 3-word windows leaves mostly filler and BibleWorks offers no answer to that, so phrases in more than 1% of what was scanned start unchecked with their verse count on the chip; Accordance's ">50% common words" rule was rejected because it discards "a virgin shall", which is the whole point of Isaiah 7:14. Verified against the real 31,102-verse KJV, not just fixtures: Jer 31:33 → Heb 8:10 then Heb 10:16, Ps 22:1 → Matt 27:46 and Mark 15:34, Isa 7:14 → Matt 1:23, each top of the list; worst case Esther 8:9 at 319ms. Logic in `utils/phrase_match.dart`, Flutter-free; 64 core + 6 real-corpus + 14 widget tests.
- **v1.6.14** — Verse List Manager (BibleWorks bwh27) as the sixth Analysis tab, plus the search-limit plumbing that is the point of it: every tool here already produces or consumes a set of verses, and there was nowhere to keep one. Two lists with an active-list radio, selection modelled as a composable *layer* (select-common + delete = difference, select-unique + delete = intersection) rather than a filter, and import that appends verbatim while `Sort list` is what dedupes. The filter toggle makes the active list the limit for subsequent searches (bwh29/bwh44 `l test.vls`), with a tappable banner in the command pane so results are never silently filtered. Versification remapping is deliberately absent — it needs licensed `.VMF` maps, so version is stored as provenance only and kept out of `VerseRef` identity. `Import ▸ From Document` scans prose for embedded references, which exposed and fixed a real pre-existing `reference_parser` defect where `Jude 14-15` yielded only Jude 1:14. Logic in `utils/verse_list.dart`, Flutter-free; 60 core tests + 11 widget tests.
- **v1.6.13** — Related Verses (BibleWorks bwh50) reaches the Analysis pane. The app already shipped curated cross-references, which is precisely why the *computed* version is new: it takes the words of the verse you are on, lets you uncheck the ones that carry no sense or weight one ×3, and counts how many each of the other 31,101 verses shares — so it finds the parallels no editor listed. Chinese gets overlapping character bigrams instead of a bundled segmenter. All the logic sits in `utils/related_verses.dart` with no Flutter import; 49 new tests, including a cross-check that the fast scanner agrees with the readable reference tokenizer.
- **v1.6.12** — removed the U+25A1 missing-glyph markers from 士师记 13:7 and 18:10 (and the mirrored traditional verses in 士師記). The two □ glyphs were a corruption of the reverence space CUV prints before 神 — every other occurrence in the file is normalised away. Added a regression test that verifies both CUVS-YHWH editions have exactly 31,102 verses with no U+25A1, and spot-checks the two fixed verses carry the canonical text.
- **v1.6.11** — 护眼纸质 reaches the workbench. The paper theme used to stop at BibleReadingPane's content subtree; chrome, the parallel Browse window, and every `WbColors.of` call site stayed on the neutral desktop palette. Added `WbColors.paper` + a `paper:` flag on `workbenchTheme`, watched `AppSettings.readingPaperTheme` in `WorkbenchPage.build`. Also added value equality to `WbColors`.
- **v1.6.10** — search hits are now marked in the Browse text itself, not only in the verse list. A hit list without marked hits is a table of contents.
- **v1.6.9** — the chrome (menu/toolbar/status bars) is present at every width. Phones read as the same tool with side panes collapsed, not as a different app.
- **v1.6.8** — finished the `WbType` migration: 82 hardcoded size call sites reduced to 5. Settings sliders (Font Size, Menu Size, Line Spacing) now drive the workbench.
- **v1.6.7** — Settings actually reach the workbench: 2 of 10 user settings honoured before, now all of them through `WbType.of(context)`.
- **v1.6.6** — stripped the NASB pilcrow (¶) that was being printed as scripture, without touching the actual verse text.
- **v1.6.5** — stopped printing publisher markup (StripePosition tags etc.) as if it were scripture.
- **v1.6.4** — Word List Manager + search-hit distribution. Two BibleWorks analysis tabs backed by real data.
- **v1.6.3** — Key Word In Context (KWIC), straight from the BibleWorks feature set.
- **v1.6.2 (BSB)** — added the Berean Standard Bible, the only English translation here with Strong's tagging. Closes the gap that left the English parallel row untagged.
- **v1.6.1** — release plumbing fix.
- **v1.5.2** — fix: Compare-two-versions actually compared two versions instead of duplicating one.
- **v1.5.1** — release plumbing fix.
- **v1.5.0** — per-word Strong's on the Chinese line (和合本雅伟版 + BDB/Thayer).
