# Permissions on file / 授权文件

Originals live here. Anything a reader is shown — the licence strings in
`lib/constants/ui_strings.dart` that the About screen renders per text —
must match a document in this directory.

A document being on file is **not** the same as the app using it. The
index below says, for each one, whether this app ships the text.

---

## CSB — Christian Standard Bible (2017)

**Original:** [CSB Holman permissions grant 2017-04-04.pdf](CSB%20Holman%20permissions%20grant%202017-04-04.pdf)
(SHA-256 `643e11a8…14997`. The same original is filed in the 雅伟的话
repo and in yswords; all three are byte-identical, so this is one
document in three places, not three documents.)

| | |
|---|---|
| Date of grant | 2017-04-04 |
| Licensee | **Raymond Suen, personally** — a named individual, not an organisation |
| Grantor | Jean Eckenrode, LifeWay Resources / Holman Bible Publishers |
| Grant | NON-EXCLUSIVE ebook/app — CSB text **with Strong's Numbers** |
| Title of the work | **CUV/CSB w/Strong's Numbers bilingual Bible** |
| Territory | **Hong Kong / Mainland China** |
| Fee | GRATIS **provided the work is distributed free**; if it becomes a salable product the permission terminates |
| Termination | When the Work is no longer available |

### This app ships the CSB — since 2026-09-07

The eleven bundled texts became twelve. The other eleven are KJV, KJVS,
LEB, NASB 2020, BSB, LXX/WH, CUVS-YHWH (简/繁), CUVS-PLUS and LJK1/LJK2.
(Fourteen since 2026-09-08, when BSB-Y and ASV-Y were added — see the
section below. The sentence above is left as it was written, because it
is dated and is a record of what was true when the CSB went in.)

Both gates below were answered before it was added — read them, then the
2026-09-07 sections that close them.

**The two gates, as they stood:**

1. **Territory.** The grant is Hong Kong / Mainland China. This app
   ships to the App Store, Play and the web without a territory fence.
2. **Licensee and work.** It names Raymond Suen personally, for one
   named work — "CUV/CSB w/Strong's Numbers bilingual Bible". This app
   is a different work by a different publisher of record, so the grant
   does not reach it on its face.

Neither was ours to decide, and neither was decided here.

**What shipping it involved.** `tools/import_csb.py`, its own importer
rather than the YsWords one, because what was licensed is the CSB *with
Strong's Numbers* and this app has a tagged layer to put them in:
`assets/csb.json` plus `assets/tagged/csb/`. The credit line below is
rendered on the About screen, verbatim, in all three locales, and
`test/csb_asset_test.dart` quotes it in full so a paraphrase fails the
build. Copying verses out carries that line and is capped at 500 like
the other licensed editions — the grant is gratis only while the work is
distributed free.

**One thing the reader should be told plainly:** the text is not the
module as received. 967 verses had lost CSB's own small-caps LORD and
read a bare "Lord"; the importer restores the divine name in them, on
the module's own typographic evidence and against two independent
witnesses. The 雅伟的话 note records the same kind of edit — its 5,041
verses — as an editorial change the grant does not mention either way.

### 2026-09-07 — gate 2 is lifted, and it reaches this app

In the Yahwehdehua Work Group, Pastor Raymond — the Raymond Suen named
as licensee above — sent this PDF and said "we can stretch this
permission to cover your Yahwehword.com".

That names the site, not this app, and this note first recorded it as
covering yswords only. **The owner then corrected that: this app is one
of the Yahweh's Words products, so the extension reaches it too.** He is
the publisher of both and that is his to say — and the repo says the
same thing on its own:

  * `pubspec.yaml` describes SeekSparks as "**forked from YsWords**"
  * the iOS display name in `ios/Runner/Info.plist` is **Yahweh's Sword**
  * the bundle id is `com.example.yahwehswords`

So gate 2 no longer stands here. **Gate 1 — territory — was put to the
owner and answered on 2026-09-07: worldwide distribution is fine**, the
CSB being freely readable online and these apps being free.

Recorded as what it is — the owner's decision, not a variation of the
written grant, which still reads Hong Kong / Mainland China on its face.
The yswords copy of this file says the same. Anyone reading later should
know which of the two they are looking at.

The yswords copy of this file records the exchange in full.

Note the shape of the grant while reading it: what was licensed is the
CSB **with Strong's numbers**, for a bilingual CUV/CSB work. That
question — **whose** Strong's data ships with the text — is answered by
using the module's own: `assets/tagged/csb/` is built from the tags
inside the licensed module itself, not by grafting this repo's Eagle's
View alignment onto it. Word-level tagging has to travel with the exact
text it was aligned against; the note on `kjvs` in
`lib/constants/bible_versions.dart` records what happens when it does
not.

### The credit line, verbatim

The grant requires this on the copyright or title page — which in this
app is the About screen — word for word:

> Scripture quotations marked CSB®, are taken from the Christian
> Standard Bible®, Copyright © 2017 by Holman Bible Publishers. Used by
> permission. Christian Standard Bible®, and CSB® are federally
> registered trademarks of Holman Bible Publishers.

Holman's naming rule: use **CSB** in running text and in Scripture
references; the ® is needed on the copyright page and on first mention
in promotional copy, not in ordinary running text.

### Cross-reference — the analysis is not repeated here

`CodingProject/Yahwehdehua/docs/授权 permissions/README.md` carries the
work this note deliberately does not duplicate: the verse-by-verse check
confirming that project's `bsapp_bible_hcsbs` table really is CSB 2017
rather than HCSB, the note that its table name is a legacy key, and the
record of its 5,041-verse `the LORD` → `Yahweh` edit — an editorial
change the grant does not mention either way.

---

## Eagle's View — a spoken grant, recorded here because nothing else was

**Original: none.** There is no document for this one, and that is the
point of this section: six attribution strings in the app say *"used by
permission"*, and until 2026-09-08 the only record of that permission was
a note in another repository's memory directory. This section is not a
grant. It is the record of what was said, by whom, and when, so the
claim on the About screen has a file behind it and the gap is visible
rather than assumed away.

| | |
|---|---|
| Date | 2026-08-07 |
| Grantor | The owner's pastor, author of Eagle's View (eaglesviewsoftware.com; the binaries name **AO Survey Pty Ltd**) |
| Form | **Spoken / relayed by the owner.** Not a signed document, not an email on file |
| Asked | Two questions, put explicitly, both answered "with permission" |

**What was asked and granted, verbatim from the record of the exchange:**

1. reusing and publicly distributing **AOSurvey's verse-to-Strong's
   tagging and alignment** — not merely the underlying public-domain
   text;
2. reusing and publicly distributing the **Modern Concordance's**
   bilingual topic / section / subsection scheme, its verse links and
   its corpus statistics — despite that scheme following the
   copyrighted *Modern Concordance to the New Testament* (Darton,
   Longman & Todd, 1976).

### What rests on it

Eight datasets ship from Eagle's View, and the app's own wording splits
them in two. **The split is load-bearing and must not be flattened.**

| Asset | Credit as shown | Rests on the grant? |
|---|---|---|
| `assets/greek_stats/` | AOSurvey © 2007 · **used by permission** | yes |
| `assets/concordance/` (341 topics) | Eagle's View, following *Modern Concordance* 1976 · **used by permission** | yes |
| `assets/ot_synopsis.json` | **used by permission** | yes |
| `assets/bible_places.json` (1,276 places) | **used by permission** | yes |
| `assets/bible_names.json` | Hitchcock's Bible Names, 1869, public domain · **supplied with** Eagle's View | no — PD in its own right |
| `assets/thayer.json` | Thayer 1889, public domain · **supplied with** Eagle's View | no — PD in its own right |
| `kjvs`, `lxxwh`, `cuvs-plus` | "Public domain text · electronic edition from Eagle's View" | the *alignment* does; the text is PD |

*"Used by permission"* marks AOSurvey's own labour — the statistics, the
verse-to-Strong's alignment, the topic scheme. *"Supplied with"* marks a
public-domain reference work that merely travelled on the same disc.
`lib/constants/version_attribution.dart` states the same distinction for
the three texts: *"the texts themselves are public domain, the electronic
edition and its Strong's alignment are not."*

### What was deliberately NOT taken

- **The NASB modules** (`NASB`, `nsn+`). The database carries the
  *publisher's* own notice — "you do not have permission to redistribute,
  modify, or profit from this text in any way" — which is Lockman's to
  waive and not the ministry's. `assets/nasb-ev.json`,
  `assets/nsn-plus.json` and `assets/tagged/nsn-plus/` are gitignored so
  a stray `git add -A` cannot publish them; `git ls-files` returns zero
  rows for all three.
- **RSV and NET** (in the vendor's `Bibles.zip`) — under active
  copyright, never touched.
- **The pinyin index** (22,991 entries, `Index.mdb`). Not named in either
  question above, so it is outside the grant as recorded. Not imported.

### What is still missing

A document. The grant is real and was given directly to the owner, but
it exists here as a note of a conversation. The CSB above shows what the
same claim looks like when it is on file. If the pastor is willing to put
the two answers in writing — even a one-paragraph email — it belongs in
this directory beside the CSB PDF, and this section should then say so
and cite it.

---

## The 雅伟的话 divine-name editions — BSB-Y, ASV-Y, and the one that was not imported

**Original: none needed for the two that ship, and that is the finding
rather than an omission.** This section exists because three texts were
looked at together on 2026-09-08 and only two of them were imported; a
directory that records permissions should also record why a text with
no permission problem was still left out.

All three come from `CodingProject/Yahwehdehua/app/build/bible.db`, the
plain SQLite the 雅伟的话 project exports for its own Flutter app. No
credential is involved: `tools/import_yahwehdehua_texts.py` reads that
file directly, which is the reason it is a separate script from
`tools/import_csb.py` rather than a flag on it.

| Source | Ships as | Base text | Whose is the divine-name reading |
|---|---|---|---|
| `bsbys` "BSB (Yahweh)" | `bsb-yhwh` · **BSB-Y** | Berean Standard Bible, public domain by dedication | the ministry's own |
| `asvs` "ASV (Yahweh)" | `asv-yhwh` · **ASV-Y** | American Standard Version 1901, public domain by age | the ministry's own |
| `hcsbs` "CSB (Yahweh)" | **not imported** | CSB 2017, licensed — see the CSB section above | — |

### Why the two that ship need no document

Two separate questions, and both have to be answered separately for each
text, because "public domain" answers only the first:

1. **The base translation.** The BSB is dedicated to the public domain
   by its publisher; the ASV is public domain because 1901 is long past
   copyright. Those are different reasons and the About screen says
   them differently — `aboutLicenseBsbYhwh` and `aboutLicenseAsvYhwh`
   are two sentences, not one shared line.
2. **The divine-name reading.** In both, it is the ministry's own
   editorial work, not a third party's. There is no publisher to ask,
   which is exactly the difference between these and the CSB. Both
   licence lines credit it anyway — a reader copying a verse out is
   copying that work as well as the translation — and both editions are
   therefore **outside** `unrestrictedCopyVersions`, so they fall under
   `kLicensedCopyVerseLimit` like `cuvs-yhwh` does and unlike `bsb`.

Note what ASV-Y is and is not. The 1901 ASV is the one major English
Bible that already **printed** the divine name, as *Jehovah*. This
edition respells a name the translators had already chosen to print. It
is a smaller claim than the BSB one and the licence line says so rather
than reusing the same wording.

### CSB (Yahweh) — the one that was not imported

The CSB is licensed and that licence already reaches this app (the CSB
section above: gate 2 lifted 2026-09-07, gate 1 answered the same day).
So the question was never whether it *may* ship. It was whether the
database holds a **different edition** from the `csb` this app already
bundles — because shipping one licensed text as two editions, with no
way for a reader to tell them apart, is a claim about the publisher's
text that nothing here supports.

It does not. Recompute it in about twenty seconds:

```
python3 tools/import_yahwehdehua_texts.py --audit-csb
```

```
verses where the DATABASE reads Yahweh more often than assets/csb.json :   0
verses where the ASSET reads it more often                             : 967
differences not explained by whitespace or by that repair              :   5
```

The first number decides it. **There is not one verse in 31,102 where
the database's "CSB (Yahweh)" reads the divine name and the CSB this app
already ships does not.** The 967 run the other way — they are precisely
the small-caps-LORD repair `tools/import_csb.py` performs and this
database's copy has not had done — and the five left over are that
importer's possessive repair ("sat in the Lord ’s presence" → "sat in
Yahweh’s presence", 2 Sam 7:18), the bundled text again being the more
correct of the two.

So `hcsbs` is the same module `assets/csb.json` was built from, one
repair pass behind. Importing it would have added a second CSB row whose
only distinguishing property is that it spells the divine name two
ways — *"The Lord  our God, the Lord  is one"* as the Shema — which is
the outcome `tools/import_csb.py` exists to prevent.

**What this corrects.** The task that produced this section was written
on the understanding that the database's CSB reads Yahweh in 5,753
places *that the bundled `csb` does not* — that they were two editions
and had to be presented as two. The count is real (5,748 occurrences in
5,041 verses) but it is not additional: those readings are already in
`assets/csb.json`, which reads Yahweh 6,785 times across 5,805 verses
because it starts from the same module and then repairs it.

`lib/constants/bible_versions.dart` ends with the note on `cuv-yhwd`,
which is the same mistake made the other way round — imported, tagged,
committed and deployed before anyone compared it to the catalog — and
`test/no_duplicate_version_text_test.dart` is what exists because of it.

### An open question about BSB-Y, recorded rather than decided

`bsb-yhwh` is a genuinely different edition from `bsb`, but the
reader-visible difference is smaller than the assets suggest.
`assets/bsb.json` stores "the LORD" in 13,172 verses and
`text_patterns.dart::_normalizeDivineNames` already rewrites all-caps
LORD to Yahweh on the way to the screen. Measured reference by reference
**after** that normalisation, 636 of the 31,086 shared verses still
differ — 2.0%: 299 where "Lord GOD" reads "Lord Yahweh", 27 where the
short form יָהּ is printed "Yah", and 310 in the New Testament where
κύριος is restored as `Lord [Yahweh]` (188 verses) or flagged with an
asterisk (113). Plus 237 translator's footnotes the plain BSB does not
carry.

On the same day, the owner hid `cuvs-plus` with 「有雅+ 就不用和合本+了」 —
and the relation there is exactly this one: one base text, one row
restoring the divine name. Applied here that would mean hiding `bsb`,
not BSB-Y. It was not done, because `bsb` is the English locale default
and the only English row that is both tagged and unrestricted to copy,
and taking the English default off the interface is the owner's call.
The catalog comment on the row says the same and names the two lines it
would take.

---

## The other bundled texts

No document on file for these; their licence strings live in
`lib/constants/ui_strings.dart`.

| Text | Licence as shown to readers |
|---|---|
| KJV / KJVS | Public domain |
| LEB | Dedicated to the public domain by the publisher |
| NASB 2020 | © The Lockman Foundation · used under quotation provisions |
| BSB | Public domain |
| BSB-Y (`bsb-yhwh`) | Public domain translation · divine-name restoration © Yahweh De Hua Ministry, used with permission |
| ASV-Y (`asv-yhwh`) | Public domain (1901) · Jehovah respelt Yahweh, © Yahweh De Hua Ministry, used with permission |
| LXX / WH | Public domain · electronic edition from Eagle's View |
| CUVS-YHWH (简/繁) | © Yahweh De Hua Ministry · used with permission |
| CUVS-PLUS | Revised by 孙树民 · used with permission (yahwehdehua.net) |
| LJK1 / LJK2 | © Liang Jia-keng / Bible Exegesis Ministry · used with permission |
| Lexicons | Brown-Driver-Briggs (1906) & Thayer (1889) public domain · Chinese edition used with permission |

The NASB row is the one to be careful with: that text is frozen in this
repo, and `assets/nasb-ev.json` and `assets/nsn-plus.json` are neither
committed nor deployed. A defect in it gets reported, not corrected.
