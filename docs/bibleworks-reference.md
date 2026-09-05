# BibleWorks 10 — structural reference

Distilled from the official BibleWorks 10 help (`bw1000.chm`, on the
user's own install disc) on 2026-08-06. Recorded here because until now
every layout decision in the Workbench was guessed from a single
screenshot, and guessing produced a workspace that was repeatedly "still
far from it".

**Scope note.** This file records *how the interface is organised* —
window structure, tab names, interactions, keyboard behaviour. It
deliberately records nothing from the bundled lexicons, morphology
databases or Bible texts: those are licensed to the disc's owner and
SeekSparks deploys publicly, so its lexical data comes from
open-licensed corpora instead (see README → Data sources).

---

## 1. The three windows

Arranged **in the order you use them**, left to right:

| Window | Position | Role |
| --- | --- | --- |
| **Search** | left third | Enter a query, get a verse list |
| **Browse** | centre | Read the hit in context — one version, or many |
| **Analysis** | right third | Whatever the *mouse is over* in Browse |

> "When you move the mouse over a word in the Browse Window, information
> about the word or verse being examined will be shown in this window."

That sentence is the whole product. Analysis is not a click target; it
is a live readout of the pointer.

### Column chrome (all three)

- Each column has a **narrow title bar**.
- A button on it **collapses the column's option controls** (the
  dropdowns/buttons under the title), leaving just content. Clicking
  any empty part of the title bar does the same.
- Another button **hides the column entirely**.
- A menu button on the title bar opens that column's tools.
- A config menu at the top-right of the main window shows/hides the
  Search, Analysis and Secondary Analysis windows, plus the main menu,
  toolbar and status bar — "a very clean interface … yet all the
  controls you might need are just a click away."

---

## 2. Search window

- **Title bar** with collapse + options buttons.
- **Command line** — words, morphology, or a verse to look up. Typing a
  **version abbreviation** on it switches the search version.
- **Verse-history button** — verses recently *displayed in Browse* (they
  enter the list after being shown for a few seconds).
- **Results verse list**.
- **Successful-search history button**.
- **Command-line versions button**, Choose Search Version, Choose
  Display Version(s), Choose Search Limits, Edit Search/Display
  Favourites, Synchronize Results List.
- **Tabs** — several independent search workspaces.
- **Copy button**; right-click context menu on the verse list.

## 3. Browse window

**Header** (right-click it to choose what shows):

- **Outline List Box** — a dropdown of an outline of the whole Bible
  (Metzger's), describing the passage on screen; opening it shows the
  outline centred on the current verse and you can jump from it.
  Alternative outlines ship, incl. section headings from versions.
- **Browse List Boxes** — search version, book, chapter, verse. "Lookup
  various Bible references without doing any typing."
- **Popup CL** — a floating command line.

**Options button:**

- Toggle **Strong's numbers inline** with the text
- Toggle **difference highlighting** between same-language versions
- Clear hit highlighting (search hits are highlighted here)

**Text area:** single-version mode (verse in context) or
**multiple-version mode**. Additional Browse windows can be opened and
**synchronized**.

## 4. Analysis window

Tabs (16): Word Analysis · Resource Summary · User Notes · Editor ·
X-Refs · Search Statistics · Words · Context · Version Info · Browse ·
Verse · Mss · Use · User Lexicon · Leningradensis · EPUB.

- **Splittable into two columns**; tabs are **dragged** between them.
- Title-bar menu lists every tab, so you can switch with the tab bar
  hidden; a config dialog chooses which tabs live in which column.

**Word Analysis tab** — the default:

- Updates **automatically as the mouse moves** over Browse text.
- Greek → parsing + Greek dictionary entry. Hebrew → morphology +
  Hebrew lexicon entry. Strong's-tagged versions → the Strong's entry.
- **Hold Shift to freeze it** while you move the mouse elsewhere.
- Verse references inside it are hypertext; their text pops up on hover.

## 5. Status bar

Left-to-right: message area · current search version · search limits ·
Strong's codes · browse mode · word analysis · verse & chapter notes ·
translator notes · accents · vowels · Qere/Kethib · keyboard layout.

- The message area shows search statistics after a search.
- **Most items are double-click toggles / openers** (double-click the
  version to open the version chooser, the limits to open the limits
  window…).
- Disabled options render greyed; enabled render black.

---

## 6. Gap list against SeekSparks (as of v1.3.0)

> ⚠️ **STALE — this is a v1.3.0 snapshot, and the tree is at 1.6.236.**
> The left column (what BibleWorks does) is still good; the right column
> is a photograph of SeekSparks taken on 2026-08-06 and has not been
> maintained since. On 2026-09-05 a pass re-read the code for every row
> and found **six of the thirteen already closed** — marked ✅ below with
> the file and commit that closed them. The seven unmarked rows were
> **not** re-checked in that pass: treat them as v1.3.0 claims, and grep
> before believing any of them. `docs/PARITY-BACKLOG.md` is the
> maintained list; this table is kept for the BibleWorks column.

Ordered by how much each changes the feel, not by effort.

| # | BibleWorks behaviour | SeekSparks now |
| --- | --- | --- |
| 1 | Hover fills the **Analysis window** | ✅ **CLOSED.** `_analysisWord` (pinned word, else last hovered) feeds the Analysis column via `_browseFocus` — `lib/pages/workbench_page.dart:1900-1912`. `790fccb` 2026-08-06 |
| 2 | **Shift freezes** the analysis | ✅ **CLOSED**, and gone past: Shift still suspends the latch (`workbench_page.dart:1973`, `_analysisFrozen:381`), but a click *pins* a word instead, which works on a pad with no keyboard — `lib/utils/analysis_focus.dart`, `49c6932` 2026-08-07 |
| 3 | Browse **single vs multiple version** mode | multiple only *(v1.3.0 claim, not re-checked)* |
| 4 | **Inline Strong's numbers** toggle in Browse | ✅ **CLOSED.** `lib/utils/strongs_inline.dart`, drawn at `browse_window.dart:1822`, toggled from `workbench_page.dart:920`. `31b6946` 2026-08-06 |
| 5 | **Search hits highlighted** in Browse | ✅ **CLOSED.** `lib/utils/search_highlight.dart`, fed into Browse at `workbench_page.dart:835`, `:1869`. `5f96e64` 2026-08-06 |
| 6 | **Difference highlighting** between same-language versions | ✅ **CLOSED.** `lib/utils/version_diff.dart` (LCS, same-language, first version is the base — bwh30), setting at `workbench_page.dart:520`. `1bff852` 2026-08-18 |
| 7 | **Bible outline dropdown** in the Browse header | — (we have `SectionTitleService`) *(v1.3.0 claim, not re-checked)* |
| 8 | Analysis **split into two columns**, draggable tabs | single column, 3 tabs *(v1.3.0 claim, not re-checked)* |
| 9 | Status-bar items are **double-click toggles** | read-only *(v1.3.0 claim, not re-checked)* |
| 10 | Command line: bare **version abbreviation** switches version | ✅ **CLOSED.** `command_pane.dart:299-310` switches before reference-parsing or search; matcher in `lib/utils/version_abbreviation.dart`. `790fccb` 2026-08-06, abbreviations (`d nas` → NASB) `3cc3be7` 2026-08-09 |
| 11 | Search window **tabs** (multiple workspaces) | one *(v1.3.0 claim, not re-checked)* |
| 12 | Column chrome collapses in **two stages** (controls, then column) | one stage *(v1.3.0 claim, not re-checked)* |
| 13 | Verse-history and search-history dropdowns | search history exists elsewhere *(v1.3.0 claim, not re-checked)* |

Tabs backed by data we do not have — Mss, EPUB, Leningradensis, User
Lexicon, Resource Summary — are deliberately **not** on this list.
Shipping an empty shell of them would be decoration, not function.
