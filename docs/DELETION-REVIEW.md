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

## 1. The Dashboard cluster — three unreachable pages, one decision

**What.** `lib/pages/dashboard_page.dart` (1,420 lines) and the two pages
reachable only through it, `family_tree_page.dart` (2,620) and
`feedback_page.dart` (468). Plus what hangs off them:
`lib/services/family_tree_service.dart`, `lib/services/feedback_service.dart`,
`lib/models/biblical_person.dart`, `lib/utils/biblical_role.dart`,
`lib/widgets/person_detail_sheet.dart`, `lib/widgets/liquid_glass.dart`
(764 lines, imported only by `feedback_page`), `lib/models/dashboard_section.dart`,
`assets/family_tree.json`, the `_DashboardSectionsCard` section of
`settings_page.dart`, and the dashboard order/visibility fields on
`AppSettings`. Roughly **6,000 lines**.

**Why it looks unnecessary.** `main.dart` makes
`SmallScreenGate(WorkbenchPage)` the app root — deliberately; its own
comment says *"SeekSparks is a Bible STUDY tool, not a devotional…"*.
Nothing points at `DashboardPage` any more. It cannot be opened.

**Proof.** Import-graph walk from `lib/main.dart` over all 255 files in
`lib/`: 221 reached, and these three pages are not among them. Direct
grep agrees — `grep -rn "DashboardPage" lib/` matches only its own
declaration. Now enforced by `test/page_reachability_test.dart`.

**What breaks if it goes.** Nothing a user can currently see. No user
data is stored by these pages — the Dashboard *displayed* bookmarks and
reading position owned by `MainProvider`; the family tree renders a
bundled asset; feedback posts to a service and keeps nothing. Three real
costs: the family-tree content is good and genuinely has no other door;
`about_page` would become the only contact route (it already has one);
and `liquid_glass.dart`'s glass/blur widgets disappear, which is aligned
with `workbench_theme.dart:16` anyway ("*no shadows, no cards*").

**Recommendation.** Decide the question, not the files: *does SeekSparks
have a home screen?* If no, delete the cluster in one commit. If yes, the
Dashboard needs an entry point and a reason to exist beside the
Workbench. **Either answer is better than the current state**, where the
code is maintained, compiled, shipped in the bundle, and unreachable.
If the family tree is the part worth saving, it round-trips to verses
via `person_detail_sheet.dart:529` and would work as a Workbench menu
item without the Dashboard.

*Do not run #279's chrome pass on any of these three pages until this is
answered.*

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

---

## 4. Two map surfaces

**What.** `lib/pages/map_viewer_page.dart` (387 lines), reachable from
the Reader, versus the Places tab shipped in #277 (v1.6.51).

**Why it looks unnecessary.** Both put biblical geography on screen.

**What breaks if it goes.** The Reader's map entry point.

**Recommendation.** Hold. The Places tab is one release old; decide after
it has been used in anger. Low cost to wait, real cost to guess.

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
