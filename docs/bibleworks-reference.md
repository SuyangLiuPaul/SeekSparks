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

Ordered by how much each changes the feel, not by effort.

| # | BibleWorks behaviour | SeekSparks now |
| --- | --- | --- |
| 1 | Hover fills the **Analysis window** | hover fills popup + status bar only |
| 2 | **Shift freezes** the analysis | — |
| 3 | Browse **single vs multiple version** mode | multiple only |
| 4 | **Inline Strong's numbers** toggle in Browse | — |
| 5 | **Search hits highlighted** in Browse | — |
| 6 | **Difference highlighting** between same-language versions | — |
| 7 | **Bible outline dropdown** in the Browse header | — (we have `SectionTitleService`) |
| 8 | Analysis **split into two columns**, draggable tabs | single column, 3 tabs |
| 9 | Status-bar items are **double-click toggles** | read-only |
| 10 | Command line: bare **version abbreviation** switches version | — |
| 11 | Search window **tabs** (multiple workspaces) | one |
| 12 | Column chrome collapses in **two stages** (controls, then column) | one stage |
| 13 | Verse-history and search-history dropdowns | search history exists elsewhere |

Tabs backed by data we do not have — Mss, EPUB, Leningradensis, User
Lexicon, Resource Summary — are deliberately **not** on this list.
Shipping an empty shell of them would be decoration, not function.
