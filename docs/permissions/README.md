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

## The other bundled texts

No document on file for these; their licence strings live in
`lib/constants/ui_strings.dart`.

| Text | Licence as shown to readers |
|---|---|
| KJV / KJVS | Public domain |
| LEB | Dedicated to the public domain by the publisher |
| NASB 2020 | © The Lockman Foundation · used under quotation provisions |
| BSB | Public domain |
| LXX / WH | Public domain · electronic edition from Eagle's View |
| CUVS-YHWH (简/繁) | © Yahweh De Hua Ministry · used with permission |
| CUVS-PLUS | Revised by 孙树民 · used with permission (yahwehdehua.net) |
| LJK1 / LJK2 | © Liang Jia-keng / Bible Exegesis Ministry · used with permission |
| Lexicons | Brown-Driver-Briggs (1906) & Thayer (1889) public domain · Chinese edition used with permission |

The NASB row is the one to be careful with: that text is frozen in this
repo, and `assets/nasb-ev.json` and `assets/nsn-plus.json` are neither
committed nor deployed. A defect in it gets reported, not corrected.
