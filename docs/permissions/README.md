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

### This app does not ship the CSB

Filed on 2026-09-07 at the owner's request. Nothing a reader sees
changed, and no licence string moved. The eleven bundled texts are KJV,
KJVS, LEB, NASB 2020, BSB, LXX/WH, CUVS-YHWH (简/繁), CUVS-PLUS and
LJK1/LJK2 — none of them is the CSB.

It is here so the paperwork sits in the same repo as the app it would
govern, if it ever does.

**Two things gate ever using it here, and neither is ours to decide:**

1. **Territory.** The grant is Hong Kong / Mainland China. This app
   ships to the App Store, Play and the web without a territory fence.
2. **Licensee and work.** It names Raymond Suen personally, for one
   named work — "CUV/CSB w/Strong's Numbers bilingual Bible". This app
   is a different work by a different publisher of record, so the grant
   does not reach it on its face.

Both belong to Raymond / Paul. The 雅伟的话 note raises the same two
against *that* project, which is the only one of the three that ships
the text.

**2026-09-07 — the extension names yahwehword.com, not this app.** In
the Yahwehdehua Work Group, Pastor Raymond — the Raymond Suen named as
licensee above — sent this PDF and said "we can stretch this permission
to cover your Yahwehword.com". That lifts gate 2 for *that* site. It
says nothing about SeekSparks / Yahweh's Swords, so gate 2 still stands
here and is one question away from being answered. (The territory line
is Holman's term, not Raymond's, and is untouched for either.) The
yswords copy of this file records the exchange in full.

Note the shape of the grant while reading it: what was licensed is the
CSB **with Strong's numbers**, for a bilingual CUV/CSB work. This repo
already carries Strong's tagging of its own (`kjvs`, and the tagged
data under `assets/tagged/`), so a future CSB here would be a question
about **whose** Strong's data ships with it, not only about the verse
text.

### The credit line, verbatim

If the CSB is ever added, the grant requires this on the copyright or
title page — which in this app is the About screen — word for word:

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
