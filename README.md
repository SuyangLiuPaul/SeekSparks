<h1 align="center">SeekSparks</h1>

<p align="center">
  <img src="brand/favicon-512.png" alt="SeekSparks App Icon" width="80"/>
</p>

<p align="center"><em>A bilingual Bible exegesis tool for bigger screens — structured original-language search, built for iPad web, Mac, and Windows.</em></p>

<p align="center">
  <a href="https://seeksparks.netlify.app">
    <img alt="Live demo" src="https://img.shields.io/badge/Live%20demo-seeksparks.netlify.app-3730A3?style=for-the-badge&logo=netlify&logoColor=white">
  </a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.44-02569B?style=for-the-badge&logo=flutter&logoColor=white">
  <img alt="License" src="https://img.shields.io/badge/License-See%20LICENSE-555?style=for-the-badge">
</p>

<p align="center">
  <img src="brand/og-image.png" alt="SeekSparks — structured Strong's search, original-language word study, docked side panels built for wide screens" width="640"/>
</p>

---

## What this is

SeekSparks is a sibling of [YsWords](https://github.com/SuyangLiuPaul/YsWords), forked to
serve a different reader: someone doing serious original-language Bible study on an iPad, a
Mac, or a Windows desktop — a bigger screen than a phone, used for longer. Where YsWords is
phone-first and general-audience, SeekSparks defaults to a wide-screen layout (Split View +
sidebar open from the first load) and adds a flagship capability neither YsWords nor most
mobile Bible apps offer: **structured Strong's-number search** — combine original-language
words with AND / OR / NOT and a word-proximity operator, evaluated against a real Strong's
concordance and the per-verse original-language word order, not a live text scan.

It's an homage to what made *BibleWorks* (discontinued 2018) beloved among Hebrew/Greek
students for over a decade — keyboard-first, no-frills, fast structured search — rebuilt on a
modern, free, cross-platform stack. SeekSparks does not use the BibleWorks name, logo, or any
of its code or data; the search grammar and UI here are an independent design.

---

## Quick start

### For users — nothing to install
Open **<https://seeksparks.netlify.app>** in a desktop or iPad browser. At tablet width and
above the reader opens in Split View with the sidebar already out. Tap "Original" on any
verse to open the word study — on desktop widths (≥1024px) it docks to the right instead of
covering the reader.

### For developers — clone, run, ship
```bash
git clone https://github.com/SuyangLiuPaul/SeekSparks
cd SeekSparks
flutter pub get
flutter run -d chrome
```

Requires **Flutter >= 3.22** and **Dart >= 3.2** (developed on Flutter 3.44.2 / Dart 3.12; the
SDK constraint in `pubspec.yaml` is `'>=3.2.3 <4.0.0'`). On Flutter 3.44 the iOS/macOS builds
stay on CocoaPods — run `flutter config --no-enable-swift-package-manager` once per machine.

---

## What v1 ships

| Category | Details |
| --- | --- |
| Structured search | Combine Strong's numbers with **AND** / **OR** / **NOT** / **NEAR*n*** (word-proximity, e.g. `G25 NEAR5 G26` = within 5 words of each other in the same verse) and a `*` prefix wildcard — evaluated over the bundled Strong's concordance, with NEAR narrowed further by the real per-verse word order in the original-language text. Operator chips + a focused "?" help dialog, EN/中文. |
| Wide-screen layout | Split View and the sidebar are open by default at tablet width (≥600px) and up — no extra tap needed on a bigger screen. |
| Docked side panels | The Original-language word study opens as a persistent right-hand panel at desktop widths (≥1024px) instead of covering the text with a bottom sheet; falls back to the familiar bottom sheet below that width. |
| Reading | 13 Bible translations across English and Chinese; Light / Dark / System theme; adjustable font, size, line spacing; paragraph or verse-by-verse mode. |
| Word Study | Word-by-word interlinear with Strong's number, transliteration, and gloss; tap a word for the full lexicon entry, word family, and concordance. |
| Highlights, bookmarks, notes | Same local-first tools as YsWords, persisted with `shared_preferences`. |
| Bible Evidence, Sermons, Timeline, Trivia, Family Tree | Ported as-is from YsWords — same bundled datasets. |

**Deliberately not in v1** (each independently shippable later):
- Cloud sync / Google sign-in — Firebase is left unconfigured on purpose (see below), so this
  is a local-only build for now.
- Native desktop/mobile builds — v1 is **web-only**, which is also literally the "iPad web +
  Mac/Windows browser" use case this app is built for; native builds can reuse YsWords'
  existing GitHub Actions release workflows once there's demand.
- English-word → original-language reverse lookup, a spaced-repetition vocabulary trainer,
  and morphology-tag colour styling — noted as good next steps, not built yet.

---

## Structured search examples

Type into Search — the AND / OR / NOT / NEAR / ✶ chips appear once the query contains a
Strong's-shaped token (`G` or `H` followed by digits):

| Query | Meaning |
| --- | --- |
| `G25 AND G26` | Verses containing **both** ἀγαπάω and ἀγάπη |
| `G25 OR G26` | Verses containing **either** |
| `G25 NOT G26` | Verses with ἀγαπάω but **without** ἀγάπη |
| `G25 NEAR5 G26` | The two words within **5 words** of each other in the same verse — e.g. this returns John 15:9, 1 John 4:7, 1 John 4:10 |
| `G25✶` | Every Strong's number whose digits start with `25` |

`NEAR` is the one that needs more than set membership: it re-checks candidate verses against
the actual word order in `assets/originals/`, so `G25 NEAR1 G26` (adjacent words) is a
materially different, stricter query than `G25 NEAR20 G26`.

---

## Why this fork is safe to run standalone

- **No shared Firebase project.** `lib/firebase_options.dart` here is a placeholder template
  (`FILL_ME_IN` everywhere) — the app's own `firebaseConfigured` check sees that and leaves
  cloud sync inert, so there's no risk of this build writing into YsWords' live user data.
- **Independent package name** (`seeksparks`, not `yswords`) and its own local storage keys —
  installing this alongside YsWords on the same device won't collide.
- **Own GitHub repo, own Netlify site** — no shared deploy target with YsWords.

---

## Architecture at a glance

Same shape as YsWords: a static Flutter web build with zero backend of its own. Bible text,
Strong's lexicons, and the concordance index all ship as bundled JSON in `assets/`; structured
search is pure Dart logic (`lib/utils/strongs_boolean_search.dart` +
`lib/utils/strongs_proximity.dart`) over that already-loaded data — no server round-trip, no
new indexing pipeline.

```
lib/
  pages/search_page.dart          Search UI: text/AI modes + the boolean-search operator bar
  utils/strongs_boolean_search.dart   Query parser + AND/OR/NOT/NEAR set algebra (pure, tested)
  utils/strongs_proximity.dart        Per-verse word-order proximity check (pure, tested)
  services/concordance_service.dart   Strong's-number → verse-refs reverse index
  services/originals_service.dart     Per-verse original-language word list (for NEAR)
  widgets/docked_panel.dart        Right-docked panel primitive for wide screens
```

---

## Data sources & licensing

SeekSparks bundles the same Bible texts and lexicon data as YsWords, inherited at fork time.
See YsWords' own [README](https://github.com/SuyangLiuPaul/YsWords#data-sources) and
[LICENSE](https://github.com/SuyangLiuPaul/YsWords/blob/main/LICENSE) for the full breakdown —
in short: KJV/LEB (public domain), NASB 2020 (© The Lockman Foundation, non-commercial use),
和合本 (public domain), 和合本雅伟版 / 原文释经圣经 (used with permission), and the Strong's
Greek/Hebrew concordance (public domain, 1890s). The **application code** in this repository
is released under the [MIT License](LICENSE); the bundled scripture texts and lexicon data are
licensed separately as above and take precedence over the MIT licence on the code.

This is a **non-commercial personal / community Bible-study tool**, not affiliated with or
endorsed by any publisher, ministry, or the original BibleWorks software.

---

## Contact / Takedown Requests

**paul.sy.liu@gmail.com** — I commit to responding within 24 hours and acting within 72 hours
on any rights-holder request.

---

> "Your word is a lamp to my feet and a light for my path." — Psalm 119:105
