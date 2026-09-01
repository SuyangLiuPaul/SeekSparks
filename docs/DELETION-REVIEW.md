# Deletion review

Things that look unnecessary but were **not** deleted, because the
deletion policy for task #281 reserves them for a human: any working
user-visible feature however marginal, anything holding user data,
anything reachable from a menu, and whole pages.

Each entry says what it is, where it lives, why it looks unnecessary,
**what breaks if it goes**, and a recommendation. Reasoning behind the
verdicts is in `PRODUCT-AUDIT.md`.

Also recorded at the bottom: what *was* deleted, and how unreachability
was proven — so a reviewer can check the work rather than trust it.

---

## 1. The Dashboard cluster — RESOLVED 2026-08-08, cluster deleted

**Decision (user, 2026-08-08).** *There is no home screen. The Workbench
is the app, and everything else is a Resource opened from it — the
BibleWorks shape, one workspace whose Resources/Tools menus open
standalone windows.*

**Deleted**, ~2,800 lines: `lib/pages/dashboard_page.dart` (1,420),
`lib/pages/feedback_page.dart` (468), `lib/services/feedback_service.dart`
(171) and its two platform halves `browser_info_stub.dart` /
`browser_info_web.dart`, `lib/widgets/liquid_glass.dart` (764, imported
only by the two pages above), `lib/models/dashboard_section.dart`, the
`_DashboardSectionsCard` section of `settings_page.dart` (235 lines) with
its `SettingsSection.dashboardLayout` deep-link target, the dashboard
order/visibility fields and the `resetDashboardLayout()` /
`setDashboardSectionOrder()` / `setDashboardSectionVisible()` API on
`AppSettings`, the now-unread `showBibleEvidence` flag behind it, and 18
`ui_strings` keys. `resetSettings()` still *purges* the SharedPreferences
keys by literal name, so an install from before this change does not
carry dead data forever — the same treatment `'offlineMode'` already got.

**Kept, and given a door.** The family tree survives whole —
`family_tree_page.dart`, `family_tree_service.dart`, `biblical_person`,
`biblical_role`, `person_detail_sheet`, `assets/family_tree.json`. It is
now a **Resource**, reached from the Workbench's Resources menu.

That placement is not arbitrary. `bwh07` splits Tools from Resources on
whether the item **operates on the current text** (Word List Manager,
KWIC, Phrase Matching, Related Verses) or is a **reference database you
consult** (maps, commentaries, grammars, Bible dictionaries, the Bible
Views picture set). `assets/family_tree.json` is the second kind.

**One thing the review missed, found while wiring it up.** The audit's
own test for whether a screen earns its place is *does it round-trip to
the text?* — and no Resource did. `person_detail_sheet.dart` and six
other pages each carried their own copy of "prepare the jump, then
`pushPage(const HomePage())`", which since the Workbench became the app
root landed the **classic single-pane reader on top of the workspace**
instead of returning to it. All seven now go through
`navigateToReader()`, whose route predicate had to learn that the root
route counts as a reader even though `MaterialApp.home:` gives it no
name. See `test/reader_round_trip_test.dart`.

**#279's chrome pass is unblocked** for `family_tree_page` (it stays) and
moot for the other two (they are gone).

---

## 2. Bundled NASB — the licence question (task #278)

**What.** `assets/nasb.json`, the full Lockman Foundation New American
Standard Bible, listed in `pubspec.yaml` and shipping on production.

**Why it is here.** The user's stated position is that NASB requires a
licence and that LEB does **not** (LEB is settled — it is not in
question and should not be re-raised).

**What breaks if it goes.** A shipping Bible version disappears for any
reader using it: `WbVersionTag` colours, saved parallel stacks
referencing `nasb`, and any shared link pinned to it. This is
user-visible and irreversible from the reader's side.

**Recommendation.** **Human decision required — no unilateral action
taken or recommended by an unattended run.** Either obtain a licence from
the Lockman Foundation or replace the slot with an openly-licensed
formal-equivalence English text; the LEB and BSB already bundled are the
obvious candidates. Flagging only.

**Decision (user, 2026-08-08): NASB stays blocked, and stays bundled.**
A supplied "Lockman Foundation certification" image was rejected as not
credible — the NASB seal reads "STAWNARD", the stamp reads "VERIFIEB",
Lockman does not issue per-person certifications, and the named
president is wrong. `assets/nasb.json` is left exactly as-is pending a
real permission from lockman.org, and is **not** to be removed either
without asking.

Related and *not* the same issue: `assets/nasb-ev.json` and
`assets/nsn-plus.json` (Eagle's View, all rights reserved) sit on disk
but are **not** listed in `pubspec.yaml`, so they are not bundled and not
deployed. That is correct and must stay that way.

---

## 3. Two search implementations

**What.** `lib/pages/search_page.dart` (2,877 lines) alongside the
Workbench's own search pane and command line.

**Why it looks unnecessary.** Both search the same corpus with the same
`SearchService`. They have already drifted: `search_page` has a scope
banner (whole Bible vs current book), AI mode and recent searches; the
Workbench pane has none of these, which is half of what task #280 is
about.

**What breaks if it goes.** AI search, recent searches (per-profile, in
SharedPreferences — minor user data), and the scope banner, unless each
is carried over. Reachable from the Reader mode and from the Dashboard.

**Recommendation.** Do not delete — **merge**, and do it *before* #280
rather than after, so the scope model is built once. Whichever survives
must keep AI mode and recent searches.

**Decision (user, 2026-08-08): one search.** Keep the workbench /
command-pane search, absorb whatever is worth keeping from the
standalone `search_page`, and remove the duplicate — improve the
survivor rather than maintain two. #280's scope filter folds into it.
Note for whoever takes it: `workbench_provider.dart` already carries
`Set<String>? searchLimit` + `searchLimitLabel`, so this is surfacing
and extending, not building from zero, and `bwh29` wants search limits
saveable **by name for later recall** — give the scope model a name
field up front.

---

## 4. Two map surfaces

**What.** `lib/pages/map_viewer_page.dart` (387 lines), reachable from
the Reader, versus the Places tab shipped in #277 (v1.6.51).

**Why it looks unnecessary.** Both put biblical geography on screen.

**What breaks if it goes.** The Reader's map entry point.

**Recommendation.** Hold. The Places tab is one release old; decide after
it has been used in anger. Low cost to wait, real cost to guess.

**Decision (user, 2026-08-08): one map surface, in Resources.** The map
is reached from the Resources menu, the same shape the family tree took
in §1 — which `bwh07` agrees with, since BibleWorks files Maps under
Resources too. #277's gazetteer feeds it. The verse-linked question
("which places does this passage mention") stays in the Analysis pane;
only the MAP moves.

**Resolved 2026-08-09 (v1.6.79).** `lib/pages/atlas_page.dart` is the one
map surface, in Resources. The Places tab no longer names a lens over the
centre pane; it hands the places it has already loaded to the Atlas, which
opens filtered to that passage with a chip the reader can dismiss to get
the whole gazetteer back. `_buildMapFrame` and the `_mapOpen` /
`_mapPlaceId` / `_baseMap` fields are gone from the workbench.

**`map_viewer_page.dart` STAYS, and the premise of this section was
wrong.** It reads `assets/maps_index.json`, which holds 1,192 entries of
which only **55** are bundled map images (`source: asset`); the other
1,136 are CDN illustrations tagged `scene`, `parable` or `teaching`. It
is an illustration viewer with 55 maps in it, not a second atlas — which
is also why its ui_strings key is `maps` = 插图 / Illustrations. Deleting
it to satisfy "one map surface" would have taken 1,136 pictures with it.
The two surfaces do not overlap: the Atlas draws the gazetteer's 1,266
named places from coordinates, the viewer shows pictures. Conservative
call, taken without a human in the loop, and recorded here so it is not
re-litigated from the name alone.

---

## 5. Repo weight that is not shipped

**What.** `assets/fonts_backup/` (149 MB), `assets/screenshots/` (15 MB),
`assets/build/` (136 KB), `assets/branding/` (8 KB),
`assets/app_icon_rounded.png` (240 KB). ~177 MB, none listed in
`pubspec.yaml`, none referenced by Dart, all committed.

**What breaks if it goes.** Nothing at runtime — these never enter a
build. But `fonts_backup/` may be somebody's source-of-truth copy of font
files, and git history keeps the bytes regardless, so deleting the
working-tree copy buys clone-time convenience, not repo size.

**Recommendation.** Confirm `fonts_backup/` is a backup of something that
still exists elsewhere before removing it. Not a code-health issue.

---

## 6. Reading-plan sync keys

**What.** `plan.activeId`, `plan.startMs`, `plan.useDate`,
`plan.completed.*` in `lib/services/cloud_sync_service.dart` (lines 109,
115, 118, 289, 291, 343, 354, 357, 419) and
`lib/services/profile_service.dart:153-158`.

**Why it looks unnecessary.** Reading plans were removed in v1.2.69.
Nothing writes these keys any more.

**What breaks if it goes.** Nothing visible — but this is **live code
that runs**, syncing and migrating stale SharedPreferences left on old
installs. Removing it is a data-compatibility decision, not dead-code
removal, and it is the one place in this audit where "unused" and "safe
to delete" come apart.

**Recommendation.** Leave until someone can say whether any installed
profile still carries these keys. The cost of keeping them is a few
strings in a list.

---

## Appendix — what *was* deleted in this pass, and the proof

All of the following were verified unreachable by grep across `lib/` and
`test/` before removal; `flutter analyze` exits 0 and 1,630 tests pass
afterwards. Nothing user-visible changes.

| Removed | Proof |
|---|---|
| `stats_page.dart` dead tabs `_OverviewTab`, `_BooksTab`, `_VocabularyTab`, their helpers `_LongestShortestList` / `_StatCard` / `_SectionHeader` / `_FrequencyBar`, and `_copyAllStats` (684 lines) | Already carried `// ignore: unused_element` and the note *"Round 56: dead — replaced by `_OriginalsOverviewTab`. Kept for reference; safe to remove in a future cleanup pass."* Every use of the four helpers was inside the dead region. |
| `lib/widgets/parallel_verse_view.dart` (500) | Only mention outside itself is a comment in `browse_window.dart:16`: *"This file replaces `parallel_verse_view.dart`."* No import anywhere. |
| `lib/services/bible_stats_service.dart` (207) | Sole importer was `stats_page.dart`, for the dead tabs. Superseded on purpose by `originals_stats_service` when stats moved to the original languages. |
| `lib/utils/version_colors.dart` (107) | Zero references, not even a comment. Created by 3cf2f0a for `parallel_verse_view`, orphaned when `browse_window` replaced it. **Its guarantee survived**: `kVersionTagColors` + `wbVersionColor()` in `workbench_theme.dart` are fully opaque (`0xFF…`) and keyed on the version code with a deterministic hash fallback — the two rules the file existed to enforce. Checked before deleting, because deleting a fix would be worse than keeping a dead file. |
| `lib/utils/greeting.dart` + `test/greeting_test.dart` (39) | Imported only by its own test. The Dashboard day-part greeting it served no longer calls it. |
| 28 `ui_strings` keys (139 lines): the 20-key reading-plan block, `dashboardSection_todayReading_{label,description}`, `settingsShowPlanHint`, `onboardPlans{Title,Body}`, `settingsSectionPlan`, `settingsPickVerseAfterChapter{,Hint}` | Each grepped individually across `lib/` + `test/`: 0 references. Not dynamically constructed. The one apparent hit — `todayReading` — is the tombstone comment at `dashboard_section.dart:33` recording that the enum value was already deleted. |
| `AppSettings.pickVerseAfterChapter` — field, getter, setter, prefs key, reset, sync snapshot and blob restore (38 lines) | No reader, no writer, no UI. A preference whose only effect was to be remembered. Costs one extra user-prefs upload per device on upgrade, since the sync blob's content changes. |
| `AppSettings.showBibleEvidence` getter + `setShowBibleEvidence()` | Superseded by the generic `isDashboardSectionVisible(DashboardSection.todayEvidence)`. The **private** `_showBibleEvidence` and its legacy-key migration were deliberately kept: they still upgrade old installs. |
| `AppSettings.notificationCategories` map getter | Zero callers; every site already uses the safe `notificationCategory(id)` lookup. |
| `path_provider`, `crypto` from `pubspec.yaml` | Added for the TTS audio cache removed in v1.3.19. The pubspec's own comment said *"Drop in a future cleanup if neither gets a second consumer."* Fifteen months on, `grep -rn "path_provider\|crypto\|sha256\|md5" lib test --include=*.dart` returns nothing. |
