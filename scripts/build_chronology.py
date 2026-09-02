#!/usr/bin/env python3
"""Build assets/chronology.json — the Genesis lifespans, from Adam to
Joseph, read out of the Bible texts this app already ships.

WHY THE NUMBERS ARE NOT TYPED IN
--------------------------------
Every other chronology asset here states figures a scholar reconstructed:
`hebrew_kings.json` is Thiele, and it has to cite him because nothing in
the repo can check it. Genesis 5 and 11 are different in kind. The text
*states* the ages, so the honest source for "Adam lived 930 years" is
Genesis 5:5 itself — and this repo ships Genesis 5:5.

So this script reads the ages out of `assets/kjv.json` and
`assets/lxxwh.json` and never hard-codes a figure. A reader who doubts a
bar on the chart can open the verse the bar cites, in this app, and count
the words. That is a stronger provenance claim than a citation, and it is
the reason this file parses number-words instead of holding a table.

THE PARSE CHECKS ITSELF
-----------------------
Genesis 5 states three numbers per patriarch: the age at begetting, the
years lived afterwards, and the total. The third is the sum of the first
two, so a mis-parsed numeral cannot hide — `a + b == c` is asserted for
every patriarch in both traditions, twenty checks that a hand-typed table
would not get. Genesis 11 states only the first two, so there the total
is a sum by definition and carries no such check; the script says which
figures are checked and which are not, rather than implying the same
confidence for both.

GENESIS 12-50 IS A DIFFERENT KIND OF SOURCE
-------------------------------------------
Genesis 5 and 11 are formulae: every man gets the same three or two
numbers at a predictable address. From Terah on, the figures are
scattered through a narrative — Abraham's age at Isaac's birth is in
21:5, his death in 25:7, Jacob's age on reaching Egypt in 47:9 — and
some are not stated at all. Jacob's age when Joseph was born is nowhere
in the text; it follows from four other verses.

So this section is marked differently rather than being run together
with the first two. Where a figure is derived, `refs` has no entry for
it, which the app reads as "derived" and distinguishes from "stated".
Two of the new figures do carry a check the text supplies itself:
Jacob is 130 on reaching Egypt (47:9) and lived 17 years there (47:28),
and 47:28 states the total 147 — so 130 + 17 == 147 checks both the
parse and the descent year in each tradition.

EXODUS 12:40 IS NOT A CHOICE THIS CHART HAS TO MAKE
---------------------------------------------------
The next span after the descent is Exodus 12:40's 430 years, and the
two texts state the same number over different ground: the Hebrew has
Israel dwelling in Egypt, the Greek "in the land of Egypt and in the
land of Canaan". An earlier version of this script stopped at the
descent because continuing "would mean choosing between them". That was
wrong. The chart has never asked a reader to choose between the two
texts — it reads each on its own terms and draws both — and 12:40 is
that same thing one rung further on. So the count starts at the descent
for a text that names only Egypt and at Abram's departure for a text
that names Canaan too, and which it is, is read off the verse in front
of the reader rather than decided here.

The Greek's start is nevertheless the weakest link on the axis and is
shipped saying so. The verse states 430 and names two lands; it does
NOT state where the Canaan part begins. Putting it at Abram's departure
is a harmonisation, not a reading, and the fact that the chart's own
figures then divide the 430 into 215 and 215 is not a check — 430 minus
215 is subtraction from a number already used, not a third witness. The
asset marks it as a reading and the note says the words out loud.

WHERE THE CHART STOPS, AND WHY
------------------------------
At the death of Moses, and the boundary is a measured limit rather than
a taste. The verse that would carry the axis on to Solomon is 1 Kings
6:1, and this parser cannot read it in either language: the English
"four hundred and eightieth year" is an ORDINAL and comes back as 400,
and the Greek reads ἐξ "out of" as the numeral 6. On top of that the
two texts do not agree there — the Hebrew's 480 is 440 in the Greek. A
number this script cannot read correctly is a number it must not plot,
so the chart ends where its last cardinal does.

THE TWO TRADITIONS ARE NOT A SCHOLARLY DISPUTE
----------------------------------------------
The Masoretic Text and the Septuagint state *different ages*, and both
are in this repo. Genesis 5:3 is 130 years in the Hebrew and 230 in the
Greek; the pattern repeats down the chapter, so creation-to-flood comes
out ~600 years apart between the two. That is a fact about the
manuscripts, not a reconstruction someone published, which is why the
chart offers both rather than picking one and apologising in a footnote.

The Samaritan Pentateuch states a third set. This repo does not hold it,
so it is named in the asset and left absent — an unmeasured tradition is
recorded as unmeasured, never guessed.

THE ONE PLACE THIS CHART COULD BE 60 YEARS OUT
----------------------------------------------
Genesis 11:26 has Terah fathering Abram, Nahor and Haran at 70, and
this chart takes 70 as Abram's birth year because it is the figure the
text states at an address. But 11:26 is the same construction as 5:32,
where three sons are named at one age and the eldest is named first
without being the firstborn — and the code below already refuses to
date Shem from 5:32 for exactly that reason.

Read with Acts 7:4 (Abram moved on after his father died), Terah's 205
years (11:32) and Abram's 75 at leaving Haran (12:4) put Abram's birth
in Terah's 130th year instead, sixty years later, and most published
chronologies take that reading.

The chart draws the stated figure and emits a note carrying the other
number, computed from the same three verses rather than typed in. It
does not offer a switch: one crux does not justify a second axis of
state, and a reader who wants the later date can read it off the note.
This is a judgement, and it is written here so the next reader can
overturn it knowingly.

ANNO MUNDI, NOT BC
------------------
Years here count from the creation (AM), because that is the only frame
the text supplies. Turning AM into BC requires an absolute anchor the
text never gives, which is what Ussher's 4004 BC is — one 17th-century
reconstruction among several. The chart therefore plots AM and says so;
a BC overlay, if it is ever added, has to arrive with the system that
produced it named on the face of it, exactly as `hebrew_kings.json`
names Thiele.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
OUT = ASSETS / "chronology.json"

# ---------------------------------------------------------------- numerals

# KJV spells its numbers, and spells them in 1611 English: "threescore
# and five" is 65. `an`/`a` count as one so that "an hundred" is 100.
EN_WORDS = {
    "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
    "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
    "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
    "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
    "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60,
    "seventy": 70, "eighty": 80, "ninety": 90,
    "score": 20, "twoscore": 40, "threescore": 60, "fourscore": 80,
}
EN_JOIN = {"and"}
EN_MULT = "hundred"

# The Greek of the Septuagint needs no multiplier: each hundred is its own
# word. Both spellings of 900 occur in the editions, and the genitive
# forms appear where the number qualifies a noun in the genitive
# ("ετων πεντακοσιων", Genesis 5:32).
#
# `εν` IS DELIBERATELY ABSENT. Accented, ἕν "one" and ἐν "in" are two
# words; this corpus is unaccented, so they are one string and no parser
# can separate them. Reading it as a numeral made Genesis 7:11 —
# "εν τω εξακοσιοστω ετει" — yield the number 1 and put the flood in
# Anno Mundi 1643. Losing the handful of real "one"s costs nothing here,
# because no age in Genesis 5 or 11 is one year.
#
# `εις` HAS THE SAME AMBIGUITY AND IS STILL LISTED, so it produces
# spurious runs: εἷς "one" and εἰς "into" are one string here, and
# Genesis 47:9 ("εις τας ημερας") therefore parses as [130, 1]. Every
# figure taken below is at an index chosen against the actual verse, so
# a trailing phantom is harmless — but anything read at a NON-ZERO index
# must be checked against the printed verse first. The Authorised
# Version has the same trap from the other direction: "a" and "an" count
# as one, so Genesis 50:26 ("in a coffin") parses as [110, 1].
GK_WORDS = {
    "εις": 1, "μια": 1, "ενος": 1,
    "δυο": 2, "τρια": 3, "τρεις": 3, "τριων": 3,
    "τεσσαρα": 4, "τεσσαρες": 4, "τεσσαρων": 4,
    "πεντε": 5, "εξ": 6, "επτα": 7, "οκτω": 8, "εννεα": 9,
    "δεκα": 10, "ενδεκα": 11, "δωδεκα": 12,
    "εικοσι": 20, "τριακοντα": 30, "τεσσαρακοντα": 40,
    "πεντηκοντα": 50, "εξηκοντα": 60, "εβδομηκοντα": 70,
    "ογδοηκοντα": 80, "ενενηκοντα": 90,
    # Judges 10:8 writes eighteen as one word where 3:14 writes it as
    # two (δεκα οκτω). A compound the tokeniser cannot split has to be
    # listed whole or the verse states no number at all — which is what
    # it did, silently, until the periods were read.
    "οκτωκαιδεκα": 18,
    "εκατον": 100, "διακοσια": 200, "διακοσιων": 200,
    "τριακοσια": 300, "τριακοσιων": 300,
    "τετρακοσια": 400, "τετρακοσιων": 400,
    "πεντακοσια": 500, "πεντακοσιων": 500,
    "εξακοσια": 600, "εξακοσιων": 600,
    "επτακοσια": 700, "επτακοσιων": 700,
    "οκτακοσια": 800, "οκτακοσιων": 800,
    "εννακοσια": 900, "ενακοσια": 900, "εννακοσιων": 900,
}
GK_JOIN = {"και"}


def _runs(text, words, join, mult=None):
    """Every maximal run of number-words in [text], as integers.

    A run is a stretch of numerals, optionally joined by "and"/"και". The
    joiner only stays inside the run when a numeral follows it, so
    "eight hundred and seven years, and begat sons" yields 807 and stops
    at `years` instead of swallowing the next clause.
    """
    toks = re.findall(r"[^\W\d_]+", text.lower(), flags=re.UNICODE)
    mults = () if mult is None else (mult,)
    out, cur = [], []
    for i, t in enumerate(toks):
        numeric = t in words or t in mults
        if numeric:
            cur.append(t)
            continue
        if t in join and cur:
            nxt = toks[i + 1] if i + 1 < len(toks) else None
            if nxt is not None and (nxt in words or nxt in mults):
                continue
        if cur:
            out.append(_value(cur, words, mults))
            cur = []
    if cur:
        out.append(_value(cur, words, mults))
    return out


def _value(toks, words, mults):
    total = 0
    acc = 0
    for t in toks:
        if t in mults:
            acc = (acc or 1) * 100
            total += acc
            acc = 0
        else:
            acc += words[t]
    return total + acc


def en_runs(text):
    return _runs(text, EN_WORDS, EN_JOIN, EN_MULT)


def gk_runs(text):
    return _runs(text, GK_WORDS, GK_JOIN)


# ---------------------------------------------------------------- ordinals
#
# ORDINALS ARE READ BY A SEPARATE PARSER, ON PURPOSE. Every figure in
# Genesis and the exodus era is a cardinal, and folding ordinals into the
# tables above would re-read verses that are already checked against a
# third stated number — Genesis 7:11's ἑξακοστῷ, Numbers 33:38's "in the
# fortieth year" — and could move a year no test is watching. This reader
# is used at exactly one address, 1 Kings 6:1, and nothing already on the
# chart passes through it.
#
# A RUN COUNTS ONLY IF IT CONTAINS AN ORDINAL. "Four hundred and
# eightieth" is a cardinal ("four hundred") and an ordinal ("eightieth")
# in one breath, so the cardinals have to be admitted — but requiring at
# least one ordinal token is what keeps this parser from answering with
# the plain numbers standing elsewhere in the same verse.
#
# The tables hold the forms these verses actually print and no more. A
# speculative form is a silent invitation to read some other verse wrong.
EN_ORDINALS = {
    "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
    "sixth": 6, "seventh": 7, "eighth": 8, "ninth": 9, "tenth": 10,
    "eleventh": 11, "twelfth": 12, "twentieth": 20, "thirtieth": 30,
    "fortieth": 40, "fiftieth": 50, "sixtieth": 60, "seventieth": 70,
    "eightieth": 80, "ninetieth": 90,
}
# "hundredth" IS A MULTIPLIER, NOT A WORD WORTH 100. It behaves exactly
# as "hundred" does — "six hundredth" is 600, and standing alone it is
# 100 — so listing it beside "eightieth" read Genesis 7:11's "six
# hundredth year" as 6 + 100 = 106. It was unreachable while 1 Kings 6:1
# ("four hundred and eightieth", which spells the multiplier the
# ordinary way) was the only address this parser served, and it is
# reachable now that the flood's second verse is read.
EN_ORDINAL_MULT = "hundredth"
# ἐν "in" and ἕν "one" are one string unaccented and `εν` is therefore
# absent from GK_WORDS; the Greek ordinals carry their own endings and do
# not collide with it. `εκτος` IS a collision — sixth, and also "outside"
# — and is left out because no verse read here needs it.
GK_ORDINALS = {
    "πρωτω": 1, "δευτερω": 2, "τριτω": 3, "τεταρτω": 4, "πεμπτω": 5,
    "εβδομω": 7, "ογδοω": 8, "ενατω": 9, "δεκατω": 10,
    "εικοστω": 20, "τριακοστω": 30, "τεσσαρακοστω": 40,
    "πεντηκοστω": 50, "εξηκοστω": 60, "εβδομηκοστω": 70,
    "ογδοηκοστω": 80, "ενενηκοστω": 90,
    "εκατοστω": 100, "διακοσιοστω": 200, "τριακοσιοστω": 300,
    "τετρακοσιοστω": 400, "πεντακοσιοστω": 500, "εξακοσιοστω": 600,
}


def _ordinal_runs(text, cardinals, ordinals, join, mult=None,
                  ordinal_mult=None):
    words = dict(cardinals)
    words.update(ordinals)
    toks = re.findall(r"[^\W\d_]+", text.lower(), flags=re.UNICODE)
    mults = tuple(m for m in (mult, ordinal_mult) if m is not None)
    # An ordinal multiplier is what makes the run an ordinal one: "six
    # hundredth" carries no other ordinal token in it.
    marks = tuple(ordinals) + ((ordinal_mult,) if ordinal_mult else ())
    out, cur = [], []

    def flush():
        if cur and any(t in marks for t in cur):
            out.append(_value(cur, words, mults))
        cur.clear()

    for i, t in enumerate(toks):
        numeric = t in words or t in mults
        if numeric:
            cur.append(t)
            continue
        if t in join and cur:
            nxt = toks[i + 1] if i + 1 < len(toks) else None
            if nxt is not None and (nxt in words or nxt in mults):
                continue
        flush()
    flush()
    return out


def en_ordinal_runs(text):
    return _ordinal_runs(text, EN_WORDS, EN_ORDINALS, EN_JOIN, EN_MULT,
                         EN_ORDINAL_MULT)


def gk_ordinal_runs(text):
    return _ordinal_runs(text, GK_WORDS, GK_ORDINALS, GK_JOIN)


# ------------------------------------------------------------------ corpus


def load(name):
    verses = json.loads((ASSETS / name).read_text(encoding="utf-8"))
    return {(v["book"], v["chapter"], v["verse"]): v["text"] for v in verses}


def cite(chapter, verse, book="Genesis"):
    return f"{book} {chapter}:{verse}"


# The English book name is what `parseReference` needs, so every `ref`
# field stays English and the app localises it for display. A reference
# written into PROSE cannot be localised afterwards, and the Chinese
# notes here write every other address out in Chinese — 出埃及记 7:7,
# 民数记 14:33, 申命记 34:7 — so one interpolated English name is the
# single word in that sentence a Chinese reader cannot read. It shipped
# that way in the moses_death note.
#
# These are the app's names, copied from englishToChinese /
# englishToChineseTraditional in lib/constants/book_name_mapping.dart,
# and they have to stay copied from there: a note is printed inches from
# the same reference rendered by `localizedReferenceLabel`, which reads
# that table. Genesis is why this matters. The 和合本's own title is
# 創世記, but the shipped Chinese corpora file all 1,533 of Genesis's
# verses under 創世紀, so that is what the reading pane, the search
# results and the chip beside this prose say. Prose that disagreed put
# two spellings of one book in a single panel — the notes below said
# 創世記 while every chip on the page said 創世紀.
BOOK_ZH = {
    "Genesis": ("创世纪", "創世紀"),
    "Exodus": ("出埃及记", "出埃及記"),
    "Numbers": ("民数记", "民數記"),
    "Deuteronomy": ("申命记", "申命記"),
}


def cite_zh(ref, script):
    """`Deuteronomy 31:2` -> `申命记 31:2`.

    An unknown book fails the build. Falling back to the English name is
    exactly the defect this exists to stop, and it would fall back
    silently.
    """
    book, _, address = ref.rpartition(" ")
    return f"{book_zh(book, script)} {address}"


def book_zh(book, script):
    """`Deuteronomy` -> `申命记`, failing the build on an unknown book.

    A book named without an address — "Exodus to Deuteronomy" — cannot go
    through [cite_zh], and stripping the address back off its output is
    the kind of trick that works until someone cites chapter 10.
    """
    names = BOOK_ZH.get(book)
    if names is None:
        raise SystemExit(f"book_zh: no Chinese name for {book!r}")
    return names[0 if script == "zh-Hans" else 1]


class Reader:
    """One tradition's Genesis, with the numeral parser it needs."""

    def __init__(self, tradition, asset, runs, ordinal_runs,
                 famine_remaining_index, famine_stated_index):
        self.tradition = tradition
        self.asset = asset
        self.text = load(asset)
        self.runs = runs
        self.ordinal_runs = ordinal_runs
        self.famine_remaining_index = famine_remaining_index
        # Genesis 45:6 states how many famine years have passed AND how
        # many remain. The Hebrew gives both as cardinals ("these two
        # years ... yet there are five"); the Greek gives the first as an
        # ORDINAL, δευτερον, which this parser cannot read and must not
        # pretend to. So the elapsed years are computed from the
        # remainder in both traditions, and the stated figure is used as
        # a check only where the text supplies it as a number.
        self.famine_stated_index = famine_stated_index

    def verse(self, chapter, verse, book="Genesis"):
        key = (book, str(chapter), str(verse))
        if key not in self.text:
            raise SystemExit(f"{self.asset}: missing {cite(chapter, verse, book)}")
        return self.text[key]

    def figure(self, chapter, verse, index=0, book="Genesis"):
        """The [index]th number stated in [book] [chapter]:[verse].

        A negative index counts from the end, which is not a convenience:
        Exodus 6:20 states Amram's years last in both texts, but the
        Greek's εἰς γυναῖκα is read as the numeral 1 ahead of them and
        the English has nothing there, so the same figure sits at
        different offsets from the front. Counting from the back names
        the figure the verse actually ends on in either language.
        """
        key = (book, str(chapter), str(verse))
        if key not in self.text:
            raise SystemExit(f"{self.asset}: missing {cite(chapter, verse, book)}")
        found = self.runs(self.text[key])
        wanted = abs(index) if index < 0 else index + 1
        if len(found) < wanted:
            raise SystemExit(
                f"{self.asset}: {cite(chapter, verse, book)} states "
                f"{len(found)} numbers, wanted "
                f"{'#' + str(index + 1) if index >= 0 else str(-index) + ' from the end'}"
                f" — {self.text[key][:120]!r}"
            )
        return found[index], cite(chapter, verse, book)

    def ordinal(self, chapter, verse, index=0, book="Genesis"):
        """The [index]th ORDINAL stated in [book] [chapter]:[verse].

        Returned as the ordinal itself — the 480th year, not 479 years
        elapsed. Turning one into the other is a reading, and it is made
        once, in the open, where the era is assembled.
        """
        key = (book, str(chapter), str(verse))
        if key not in self.text:
            raise SystemExit(f"{self.asset}: missing {cite(chapter, verse, book)}")
        found = self.ordinal_runs(self.text[key])
        wanted = abs(index) if index < 0 else index + 1
        if len(found) < wanted:
            raise SystemExit(
                f"{self.asset}: {cite(chapter, verse, book)} states "
                f"{len(found)} ordinals, wanted {index} — "
                f"{self.text[key][:120]!r}")
        return found[index], cite(chapter, verse, book)


# ------------------------------------------------------------------ tables

# WHERE EACH FIGURE LIVES, not what it is. The verse addresses are the
# only thing hand-written in this file; the numbers at those addresses are
# read from the text. Genesis 5 runs begat/after/total, and the two
# traditions agree on the versification, so one table serves both.
#
# Genesis 5 is irregular in two places and the table says so rather than
# assuming a stride of three: Enoch is not said to have died (5:24 stands
# between his total and Methuselah), and Lamech's naming of Noah (5:29)
# falls between his begetting and his remainder.
GEN5 = [
    # id,           begat, after, total
    ("adam",        (5, 3), (5, 4), (5, 5)),
    ("seth",        (5, 6), (5, 7), (5, 8)),
    ("enos",        (5, 9), (5, 10), (5, 11)),
    ("cainan",      (5, 12), (5, 13), (5, 14)),
    ("mahalaleel",  (5, 15), (5, 16), (5, 17)),
    ("jared",       (5, 18), (5, 19), (5, 20)),
    ("enoch",       (5, 21), (5, 22), (5, 23)),
    ("methuselah",  (5, 25), (5, 26), (5, 27)),
    ("lamech",      (5, 28), (5, 30), (5, 31)),
]

# Genesis 11 states begetting age and remainder but never a total, so the
# lifespan below is a sum and is marked `checked: false` in the output.
#
# The two traditions genuinely differ in SHAPE here, not only in figures.
# The Septuagint has a patriarch the Hebrew does not — Kainan, between
# Arphaxad and Shelah — and Luke 3:36 has him too. In the edition shipped
# here the whole Kainan record is folded into 11:13 alongside Arphaxad's
# remainder, which is why that verse is read three times by index.
GEN11_MT = [
    ("arphaxad", (11, 12, 0), (11, 13, 0)),
    ("salah",    (11, 14, 0), (11, 15, 0)),
    ("eber",     (11, 16, 0), (11, 17, 0)),
    ("peleg",    (11, 18, 0), (11, 19, 0)),
    ("reu",      (11, 20, 0), (11, 21, 0)),
    ("serug",    (11, 22, 0), (11, 23, 0)),
    ("nahor",    (11, 24, 0), (11, 25, 0)),
    ("terah",    (11, 26, 0), None),
]
GEN11_LXX = [
    ("arphaxad", (11, 12, 0), (11, 13, 0)),
    ("kainan2",  (11, 13, 1), (11, 13, 2)),
    ("salah",    (11, 14, 0), (11, 15, 0)),
    ("eber",     (11, 16, 0), (11, 17, 0)),
    ("peleg",    (11, 18, 0), (11, 19, 0)),
    ("reu",      (11, 20, 0), (11, 21, 0)),
    ("serug",    (11, 22, 0), (11, 23, 0)),
    ("nahor",    (11, 24, 0), (11, 25, 0)),
    ("terah",    (11, 26, 0), None),
]

# GENESIS 12-50. Each entry is (id, begetting age, lifespan), and where
# the text states no begetting age the entry is None and the figure is
# derived below.
#
# Jacob's age at Joseph's birth is the one figure in this whole chart
# that no verse states. It follows from four that do: Joseph is 30 when
# he stands before Pharaoh (41:46), the seven years of plenty pass
# (41:53), and the family comes down in a famine year that 45:6 dates by
# saying five of the seven (41:30) are still to come. That makes Joseph
# 39 at the descent, and Jacob 130 (47:9), so Joseph was born in Jacob's
# 91st year. `refs` records no verse for it, because there is none.
ABRAHAMIC = [
    # id,        begat,     lifespan
    ("abraham",  (21, 5),   (25, 7)),
    ("isaac",    (25, 26),  (35, 28)),
    ("jacob",    None,      (47, 28, 1)),
    ("joseph",   None,      (50, 26)),
]

# Seth's line in Genesis 5, Shem's in Genesis 11, the patriarchs in
# Genesis 12-50. The chart colours by these, the way the printed
# chronologies have since the 17th century.
#
# `abraham` is NOT a fourth line of descent — Abraham is Shem's
# descendant through Terah, and the text says so. What the third group
# marks is the third of the three ways Genesis states an age: the
# formula of chapter 5, the shorter formula of chapter 11, and the
# figures scattered through the narrative from chapter 12 on, which are
# the ones that need derivation and carry the fewest self-checks. That
# distinction is worth a colour; the reader is told which it is.
#
# `levi` is the fourth, and it is a real descent as well: Exodus 6:16-20
# traces Moses and Aaron to Jacob through Levi, so they are not a new
# branch of the family but they ARE a new kind of source — the only two
# men here whose figures come from outside Genesis, read out of Exodus,
# Numbers and Deuteronomy and checked against each other across all
# three.
LINE = {p[0]: "seth" for p in GEN5}
LINE.update({p[0]: "shem" for p in GEN11_LXX})
LINE["noah"] = "seth"
LINE["shem"] = "shem"
LINE.update({p[0]: "abraham" for p in ABRAHAMIC})
LINE["moses"] = "levi"
LINE["aaron"] = "levi"

# THE SPELLING THIS CHART PRINTS, and why it is not the one the ids use.
#
# The wheel drew a birth spoke reading "Birth of Kenan" — that string
# comes from `bible_timeline.json`, which spells the line as modern
# versions do — beside a lifespan arc reading "Cainan", which came from
# here. One man, two spellings, touching on screen. The owner's ruling
# was the modern form: 现代的这样看得懂.
#
# So `name.en` is the modern spelling and `nameKjv` carries the
# Authorised Version's, for the four men where the two differ. NOT a
# note and NOT dropped: this app ships the KJV and `kjvs.json`, and a
# reader looking at Genesis 5:9 sees "Cainan" and will type "Cainan".
# The field is searched wherever a name is searched, and printed under
# the name on every sheet, so the older spelling stays findable and the
# reader can see the two forms are one man rather than guess it.
#
# Every value is read off the text, never invented: `kjv.json` reads
# Enos / Cainan / Mahalaleel / Salah at Genesis 5:9-15 and 10:24, and
# `bsb.json`, `nasb.json` and `leb.json` read Enosh / Kenan / Mahalalel
# / Shelah at those same verses. Pinned by
# `test/patriarch_spelling_test.dart`.
KJV_NAMES = {
    "enos": "Enos",
    "cainan": "Cainan",
    "mahalaleel": "Mahalaleel",
    "salah": "Salah",
}

NAMES = {
    "adam":       ("Adam", "亚当", "亞當"),
    "seth":       ("Seth", "塞特", "塞特"),
    "enos":       ("Enosh", "以挪士", "以挪士"),
    "cainan":     ("Kenan", "该南", "該南"),
    "mahalaleel": ("Mahalalel", "玛勒列", "瑪勒列"),
    "jared":      ("Jared", "雅列", "雅列"),
    "enoch":      ("Enoch", "以诺", "以諾"),
    "methuselah": ("Methuselah", "玛土撒拉", "瑪土撒拉"),
    "lamech":     ("Lamech", "拉麦", "拉麥"),
    "noah":       ("Noah", "挪亚", "挪亞"),
    "shem":       ("Shem", "闪", "閃"),
    "arphaxad":   ("Arphaxad", "亚法撒", "亞法撒"),
    "kainan2":    ("Kainan", "该南", "該南"),
    "salah":      ("Shelah", "沙拉", "沙拉"),
    "eber":       ("Eber", "希伯", "希伯"),
    "peleg":      ("Peleg", "法勒", "法勒"),
    "reu":        ("Reu", "拉吴", "拉吳"),
    "serug":      ("Serug", "西鹿", "西鹿"),
    "nahor":      ("Nahor", "拿鹤", "拿鶴"),
    "terah":      ("Terah", "他拉", "他拉"),
    # Abram is renamed Abraham in Genesis 17:5, before every figure the
    # chart reads for him, so the later name is the one used.
    "abraham":    ("Abraham", "亚伯拉罕", "亞伯拉罕"),
    "isaac":      ("Isaac", "以撒", "以撒"),
    "jacob":      ("Jacob", "雅各", "雅各"),
    "joseph":     ("Joseph", "约瑟", "約瑟"),
    "moses":      ("Moses", "摩西", "摩西"),
    "aaron":      ("Aaron", "亚伦", "亞倫"),
}


def names(pid):
    en, hans, hant = NAMES[pid]
    return {"en": en, "zh-Hans": hans, "zh-Hant": hant}


# ------------------------------------------------------------------- build


def build_tradition(reader, gen11, problems):
    """Every patriarch's figures and AM span for one tradition."""
    rows = {}
    order = []

    # Genesis 5. Three stated numbers, and the third checks the other two.
    for pid, begat_at, after_at, total_at in GEN5:
        begat, begat_ref = reader.figure(*begat_at)
        after, after_ref = reader.figure(*after_at)
        total, total_ref = reader.figure(*total_at)
        if begat + after != total:
            problems.append(
                f"{reader.tradition} {pid}: {cite(*begat_at)} states {begat} "
                f"and {cite(*after_at)} states {after}, which is "
                f"{begat + after}, but {cite(*total_at)} states {total}"
            )
        rows[pid] = {
            "begatAt": begat, "livedAfter": after, "lifespan": total,
            "checked": True,
            "refs": {"begatAt": begat_ref, "livedAfter": after_ref,
                     "lifespan": total_ref},
        }
        order.append(pid)

    # Noah. Genesis 5:32 gives his age at fathering, 9:29 his lifespan;
    # nothing states the years between, so the remainder is a difference.
    noah_begat, noah_begat_ref = reader.figure(5, 32)
    noah_total, noah_total_ref = reader.figure(9, 29)
    rows["noah"] = {
        "begatAt": noah_begat, "livedAfter": noah_total - noah_begat,
        "lifespan": noah_total, "checked": False,
        "refs": {"begatAt": noah_begat_ref, "livedAfter": None,
                 "lifespan": noah_total_ref},
    }
    order.append("noah")

    # Shem straddles the flood and is the one figure the text hands over
    # awkwardly. Genesis 11:10 dates him against the flood, not against
    # his father, so his birth is fixed there and not from 5:32.
    shem_age, shem_ref = reader.figure(11, 10)
    shem_after, shem_after_ref = reader.figure(11, 11)
    rows["shem"] = {
        "begatAt": shem_age, "livedAfter": shem_after,
        "lifespan": shem_age + shem_after, "checked": False,
        "refs": {"begatAt": shem_ref, "livedAfter": shem_after_ref,
                 "lifespan": None},
    }
    order.append("shem")

    for pid, begat_at, after_at in gen11:
        begat, begat_ref = reader.figure(*begat_at)
        if after_at is None:
            # Terah's remainder is never stated; Genesis 11:32 gives his
            # total instead, so the two are read the other way round.
            total, total_ref = reader.figure(11, 32)
            rows[pid] = {
                "begatAt": begat, "livedAfter": total - begat,
                "lifespan": total, "checked": False,
                "refs": {"begatAt": begat_ref, "livedAfter": None,
                         "lifespan": total_ref},
            }
        else:
            after, after_ref = reader.figure(*after_at)
            rows[pid] = {
                "begatAt": begat, "livedAfter": after,
                "lifespan": begat + after, "checked": False,
                "refs": {"begatAt": begat_ref, "livedAfter": after_ref,
                         "lifespan": None},
            }
        order.append(pid)

    # Anno Mundi. Adam is year 0 by construction — the text counts from
    # him — and each son is born in the year his father's begetting-age
    # names. The chain breaks twice and both breaks are anchored on a
    # verse rather than papered over.
    birth = {"adam": 0}
    chain5 = [p[0] for p in GEN5] + ["noah"]
    for i, pid in enumerate(chain5[:-1]):
        birth[chain5[i + 1]] = birth[pid] + rows[pid]["begatAt"]

    # THE FLOOD IS DATED TWICE, ONE YEAR APART. Genesis 7:6 states Noah
    # was 600 years old — a cardinal, 600 years complete — and 7:11 dates
    # the same day to "the six hundredth year" of his life, "τω
    # εξακοσιοστω ετει", an ordinal, which is 599 complete. The chart
    # takes 7:6, and that choice carries: Shem's birth is anchored on the
    # flood, so every year from here to the end of the axis would move
    # with it. The other reading is measured rather than dismissed and is
    # stated on the chart; it is the same subtraction the era ledger makes
    # at 1 Kings 6:1, where no cardinal is offered and there is no choice.
    flood_age, flood_ref = reader.figure(7, 6)
    flood = birth["noah"] + flood_age
    flood_ordinal, flood_ordinal_ref = reader.ordinal(7, 11)
    if flood_ordinal != flood_age:
        raise SystemExit(
            f"{reader.asset}: {flood_ref} states {flood_age} and "
            f"{flood_ordinal_ref} states the {flood_ordinal}th year — the "
            f"two verses no longer name the same year of Noah's life, so "
            f"the one-year note below would be describing something else")
    flood_alt = birth["noah"] + flood_ordinal - 1

    # Genesis 11:10 makes Shem 100 two years after the flood. Genesis
    # 5:32 has Noah fathering three sons at 500, so Shem's birth lands at
    # Noah's 502nd year, not his 500th: the three are not triplets and
    # 5:32 names the eldest first, not necessarily the firstborn. The
    # chart follows 11:10 because it is the verse that dates him.
    birth["shem"] = flood + 2 - rows["shem"]["begatAt"]

    chain11 = ["shem"] + [p[0] for p in gen11]
    for i, pid in enumerate(chain11[:-1]):
        birth[chain11[i + 1]] = birth[pid] + rows[pid]["begatAt"]

    # Genesis 12-50. Abram's birth comes off Terah's stated 70; see the
    # module docstring for the sixty years that reading may cost.
    epochs = build_abrahamic(reader, rows, order, birth, problems)

    # Exodus to Deuteronomy. The sojourn carries the axis on past the
    # descent, and where it starts is read off Exodus 12:40 in this
    # reader's own text; see build_exodus.
    epochs["exodusEra"] = build_exodus(
        reader, rows, order, birth,
        epochs["haran"][0], epochs["descent"][0], problems)

    for pid in order:
        rows[pid]["birthAm"] = birth[pid]
        rows[pid]["deathAm"] = birth[pid] + rows[pid]["lifespan"]

    return order, rows, flood, flood_ref, flood_age, flood_alt, epochs


def build_abrahamic(reader, rows, order, birth, problems):
    """Terah's line to Joseph, and the two epochs that section supplies.

    Returns the years of Abram's departure from Haran and of the descent
    into Egypt, plus the figures a caller needs to state the Terah crux.
    """
    birth["abraham"] = birth["terah"] + rows["terah"]["begatAt"]

    for pid, begat_at, span_at in ABRAHAMIC:
        span, span_ref = reader.figure(*span_at)
        if begat_at is None:
            rows[pid] = {
                "begatAt": None, "livedAfter": None, "lifespan": span,
                "checked": False,
                "refs": {"lifespan": span_ref},
            }
        else:
            begat, begat_ref = reader.figure(*begat_at)
            rows[pid] = {
                "begatAt": begat, "livedAfter": span - begat,
                "lifespan": span, "checked": False,
                "refs": {"begatAt": begat_ref, "livedAfter": None,
                         "lifespan": span_ref},
            }
        order.append(pid)

    birth["isaac"] = birth["abraham"] + rows["abraham"]["begatAt"]
    birth["jacob"] = birth["isaac"] + rows["isaac"]["begatAt"]

    # The descent into Egypt. Jacob gives Pharaoh his age (47:9), then
    # 47:28 states both the years he went on to live there and his total
    # — so 130 + 17 == 147 checks the parse AND this epoch's year, the
    # only self-check Genesis 12-50 offers.
    jacob_age, jacob_age_ref = reader.figure(47, 9)
    in_egypt, _ = reader.figure(47, 28, 0)
    if jacob_age + in_egypt != rows["jacob"]["lifespan"]:
        problems.append(
            f"{reader.tradition} jacob: {cite(47, 9)} states {jacob_age} and "
            f"{cite(47, 28)} states {in_egypt} years in Egypt, which is "
            f"{jacob_age + in_egypt}, but {cite(47, 28)} states a total of "
            f"{rows['jacob']['lifespan']}")
    else:
        rows["jacob"]["checked"] = True
    descent = birth["jacob"] + jacob_age

    # Joseph's age at the descent, from four verses; see ABRAHAMIC.
    at_pharaoh, at_pharaoh_ref = reader.figure(41, 46)
    plenty, plenty_ref = reader.figure(41, 53)
    famine_years, famine_ref = reader.figure(41, 30)
    remaining, remaining_ref = reader.figure(45, 6, reader.famine_remaining_index)
    elapsed = famine_years - remaining
    if reader.famine_stated_index is not None:
        stated, _ = reader.figure(45, 6, reader.famine_stated_index)
        if stated != elapsed:
            problems.append(
                f"{reader.tradition} joseph: {cite(41, 30)} has {famine_years} "
                f"famine years and {cite(45, 6)} leaves {remaining}, which is "
                f"{elapsed} elapsed, but {cite(45, 6)} states {stated}")
    joseph_age = at_pharaoh + plenty + elapsed
    birth["joseph"] = descent - joseph_age

    # Jacob's begetting age is this difference and nothing else states
    # it, so it carries no verse — the app reads a missing ref as
    # "derived" rather than as "unknown".
    rows["jacob"]["begatAt"] = birth["joseph"] - birth["jacob"]
    rows["jacob"]["livedAfter"] = (
        rows["jacob"]["lifespan"] - rows["jacob"]["begatAt"])

    depart, depart_ref = reader.figure(12, 4)
    return {
        "haran": (birth["abraham"] + depart, depart_ref, depart),
        "descent": (descent, jacob_age_ref, jacob_age),
        "josephAge": (joseph_age, [at_pharaoh_ref, plenty_ref, famine_ref,
                                   remaining_ref]),
    }


# EXODUS TO THE DEATH OF MOSES. Addresses only, as everywhere above.
#
# Every figure here is a CARDINAL, and that is a constraint rather than a
# convenience. The two dates this era is most often given by — Aaron's
# death "in the fortieth year" (Numbers 33:38) and Moses' last address
# "in the fortieth year" (Deuteronomy 1:3) — are ORDINALS, which this
# parser cannot read in either language and must not pretend to: it
# returns nothing at all from the English and the number 1 from the
# Greek, which is the day of the month standing next to the ordinal.
# That is the ἕν/ἐν trap of Genesis 7:11 in a second costume. So the
# forty years are taken from Numbers 14:33, where the text states them
# as a plain number, and the two ordinals are left unread.
EXODUS_SOJOURN = (12, 40, 0, "Exodus")           # the 430 years
EXODUS_MOSES_AT_PHARAOH = (7, 7, 0, "Exodus")    # Moses 80
EXODUS_AARON_AT_PHARAOH = (7, 7, 1, "Exodus")    # Aaron 83
EXODUS_WILDERNESS = (14, 33, 0, "Numbers")       # 40 years
EXODUS_MOSES_LIFE = (34, 7, 0, "Deuteronomy")    # Moses 120, at his death
EXODUS_MOSES_SAYS = (31, 2, 0, "Deuteronomy")    # Moses 120, in his own mouth
EXODUS_AARON_LIFE = (33, 39, 0, "Numbers")       # Aaron 123

# The two lives standing between Jacob's descent and Moses' birth, for
# the one test this era can be put to from outside itself; see
# build_exodus. Amram's figure is addressed from the END of the verse
# because the Greek reads εἰς γυναῖκα as the numeral 1 in front of it
# and the English has nothing there.
EXODUS_KOHATH_LIFE = (6, 18, 0, "Exodus")        # Kohath 133 / 130
EXODUS_AMRAM_LIFE = (6, 20, -1, "Exodus")        # Amram 137 / 132


def build_exodus(reader, rows, order, birth, haran, descent, problems):
    """The sojourn, the exodus, and the two lives that span the forty years.

    WHERE THE 430 YEARS BEGIN IS READ OFF THE VERSE, NOT DECIDED HERE.
    Exodus 12:40 states the same number in both texts and does not cover
    the same ground with it: the Hebrew has Israel dwelling in Egypt, the
    Greek "in the land of Egypt and in the land of Canaan". So the start
    of the count is taken from whether the verse in front of this reader
    names Canaan — from the descent when it does not, and from Abram's
    departure for Canaan when it does.

    An earlier version of this script stopped at the descent and said
    that carrying the axis further "would mean choosing between them".
    That was wrong, and the whole chart is the reason: it has never asked
    a reader to choose between the two texts, it reads each one on its
    own terms and draws both. Exodus 12:40 is that, one rung further on.

    THE CANAAN READING IS NOT CHECKED AND MUST NOT SAY IT IS. The verse
    names two lands and states one total; it does not say where the
    Canaan part starts. Putting the start at Abram's departure is a
    harmonisation. That the chart's own figures then split the 430 into
    215 and 215 proves nothing — the second 215 is the first subtracted
    from a total already in hand, and this script refuses that move
    everywhere else. So the era reports `startIsRead` and the asset
    carries the caveat.
    """
    sojourn, sojourn_ref = reader.figure(*EXODUS_SOJOURN[:3],
                                         book=EXODUS_SOJOURN[3])
    verse = reader.verse(12, 40, book="Exodus").lower()
    in_canaan_too = "χανααν" in verse or "canaan" in verse
    start = haran if in_canaan_too else descent
    exodus = start + sojourn

    # The Canaan reading divides the 430 at the descent, and the first
    # part is not asserted — it is what this chart already holds, from
    # Genesis 21:5, 25:26 and 47:9. Reporting both halves is what lets a
    # reader see that this text's own wording comes out 215 and 215.
    years_in_canaan = descent - haran
    years_in_egypt = exodus - descent

    moses_at_pharaoh, moses_ref = reader.figure(*EXODUS_MOSES_AT_PHARAOH[:3],
                                                book=EXODUS_MOSES_AT_PHARAOH[3])
    aaron_at_pharaoh, aaron_ref = reader.figure(*EXODUS_AARON_AT_PHARAOH[:3],
                                                book=EXODUS_AARON_AT_PHARAOH[3])
    wilderness, wilderness_ref = reader.figure(*EXODUS_WILDERNESS[:3],
                                               book=EXODUS_WILDERNESS[3])
    moses_life, moses_life_ref = reader.figure(*EXODUS_MOSES_LIFE[:3],
                                               book=EXODUS_MOSES_LIFE[3])
    moses_says, moses_says_ref = reader.figure(*EXODUS_MOSES_SAYS[:3],
                                               book=EXODUS_MOSES_SAYS[3])
    aaron_life, aaron_life_ref = reader.figure(*EXODUS_AARON_LIFE[:3],
                                               book=EXODUS_AARON_LIFE[3])

    # TWO CHECKS ON THE SAME FORTY YEARS, from two men in two books.
    # Moses is 80 before Pharaoh and dies at 120; Aaron is 83 at the same
    # moment and dies at 123. Each difference is the forty years Numbers
    # 14:33 states outright, so a mis-parse of any one of the five
    # figures cannot pass. This is the Genesis 5 check — a + b == c —
    # arriving from three separate books instead of one verse.
    #
    # Aaron's is corroboration and not a second independent witness: his
    # 83 comes from the same verse as Moses' 80, so a mis-parse of THAT
    # verse could in principle move both. What makes the pair worth
    # running anyway is that the two lifespans come from different books
    # and the same forty years has to bridge both gaps.
    for who, age, span, ref_a, ref_b in (
            ("moses", moses_at_pharaoh, moses_life, moses_ref, moses_life_ref),
            ("aaron", aaron_at_pharaoh, aaron_life, aaron_ref, aaron_life_ref)):
        if age + wilderness != span:
            problems.append(
                f"{reader.tradition} {who}: {ref_a} states {age} and "
                f"{wilderness_ref} states {wilderness} years in the "
                f"wilderness, which is {age + wilderness}, but {ref_b} "
                f"states a lifetime of {span}")

    # THE SECOND WITNESS TO MOSES' 120, and the reason his lifespan can
    # be marked checked at all. Deuteronomy 34:7 states it as narration
    # at his death; 31:2 has him say it himself on a different occasion
    # in a different chapter. Two statements of one number in two places
    # is what Genesis 5's third figure is, spread out.
    if moses_says != moses_life:
        problems.append(
            f"{reader.tradition} moses: {moses_says_ref} states "
            f"{moses_says} but {moses_life_ref} states {moses_life}")

    # THE ONE PLACE THE 430 CAN BE TESTED FROM OUTSIDE ITSELF. Exodus
    # 6:16-20 runs Levi to Kohath to Amram to Moses, and Genesis 46:11
    # names Kohath among those who went down into Egypt — so he was
    # already born at the descent. Read as father to son, the years from
    # the descent to the exodus cannot exceed what is left of Kohath's
    # life plus the whole of Amram's plus Moses' age before Pharaoh, and
    # that ceiling is computed here rather than asserted. Whether it
    # clears the gap is exactly what the two readings of 12:40 decide,
    # and the note reports which way this text falls.
    kohath, kohath_ref = reader.figure(*EXODUS_KOHATH_LIFE[:3],
                                       book=EXODUS_KOHATH_LIFE[3])
    amram, amram_ref = reader.figure(*EXODUS_AMRAM_LIFE[:3],
                                     book=EXODUS_AMRAM_LIFE[3])
    ceiling = kohath + amram + moses_at_pharaoh

    # THE ONE YEAR THIS ERA ASSUMES, said out loud. Exodus 7:7 gives the
    # two ages "when they spake unto Pharaoh", and the text states no
    # interval between that and the departure, so the confrontation is
    # placed in the exodus year. Everything else here is stated: Moses
    # dies at the end of the forty years, which is where 120 - 40 puts
    # his birth from the other direction.
    #
    # `checked` here says what it says everywhere else in this file: the
    # PARSE was confirmed against a further number the text states, not
    # that the year on the axis is beyond dispute. Moses' 120 is stated
    # twice and reached a third way (80 + 40); Aaron's 123 is reached the
    # same way from the verse he shares with Moses. Where they sit on the
    # axis depends on the sojourn, and that is disclosed separately —
    # conflating the two would let a firm parse vouch for a soft anchor.
    #
    # Aaron first: Exodus 7:7 makes him the elder, and every row above
    # him is in birth order. Two brothers are not a generation, but the
    # chart's one ordering rule is the year, and it holds here too.
    for pid, age, span, life_ref in (
            ("aaron", aaron_at_pharaoh, aaron_life, aaron_life_ref),
            ("moses", moses_at_pharaoh, moses_life, moses_life_ref)):
        birth[pid] = exodus - age
        rows[pid] = {
            "begatAt": None,
            "livedAfter": None,
            "lifespan": span,
            "checked": True,
            "refs": {"lifespan": life_ref},
        }
        order.append(pid)

    return {
        "sojourn": (sojourn, sojourn_ref),
        "inCanaanToo": in_canaan_too,
        # True when the start of the 430 had to be supplied rather than
        # read. See the docstring: this is the one soft joint on the axis.
        "startIsRead": in_canaan_too,
        "yearsInCanaan": years_in_canaan,
        "yearsInEgypt": years_in_egypt,
        "exodus": (exodus, sojourn_ref),
        "mosesDeath": (birth["moses"] + moses_life, moses_life_ref),
        "wilderness": (wilderness, wilderness_ref),
        "ages": {"moses": moses_at_pharaoh, "aaron": aaron_at_pharaoh},
        "atPharaohRef": moses_ref,
        "ceiling": ceiling,
        "ceilingParts": ((kohath, kohath_ref), (amram, amram_ref)),
        "mosesSaysRef": moses_says_ref,
    }


# ------------------------------------- from the exodus to the temple
#
# WHY THIS ERA IS COUNTED AND NOT PLACED.
#
# Genesis can be drawn because it hands over an unbroken chain: A lived
# x years and begat B. After Moses the chain stops. The text goes on
# stating numbers — this servitude lasted eight years, the land had rest
# forty — but it never says that one period begins where the last one
# ends, and at Judges 10:7 it has two oppressions running at once. So a
# chain of bars laid end to end from the exodus would be a
# reconstruction, and this module has refused reconstructions since its
# first line.
#
# What can be done without one is arithmetic. 1 Kings 6:1 states the
# whole span as a single number, and the periods inside it are stated
# individually. Adding the individual figures up and setting the total
# beside the stated one asks nothing of the reader's judgement and
# nothing of ours — and the answer is that they do not fit. That is a
# fact about the text, published for centuries, and it is the reason the
# era gets a ledger here instead of an axis.
#
# EVERY FIGURE IS READ AT THE LAST NUMBER IN ITS VERSE, because the
# duration is what these verses end on — "and he judged Israel eight
# years" — while the numbers standing in front of it are chariots, sons
# and daughters. Judges 12:7 is the exception in the English, where
# Jephthah is buried "in one of the cities of Gilead", so it is taken
# from the front.
PERIOD_LAST = -1
PERIODS = [
    # (id, kind, book, chapter, verse, index, en, zh-Hans, zh-Hant)
    ("wilderness", "wilderness", "Numbers", 14, 33, 0,
     "The wilderness", "旷野漂流", "曠野漂流"),
    ("cushan", "servitude", "Judges", 3, 8, PERIOD_LAST,
     "Servitude to Cushan-Rishathaim", "服事古珊利萨田", "服事古珊利薩田"),
    ("othniel", "rest", "Judges", 3, 11, PERIOD_LAST,
     "Rest under Othniel", "俄陀聂时的太平", "俄陀聶時的太平"),
    ("eglon", "servitude", "Judges", 3, 14, PERIOD_LAST,
     "Servitude to Eglon of Moab", "服事摩押王伊矶伦", "服事摩押王伊磯倫"),
    ("ehud", "rest", "Judges", 3, 30, PERIOD_LAST,
     "Rest under Ehud", "以笏时的太平", "以笏時的太平"),
    ("jabin", "servitude", "Judges", 4, 3, PERIOD_LAST,
     "Oppression by Jabin", "耶宾的欺压", "耶賓的欺壓"),
    ("deborah", "rest", "Judges", 5, 31, PERIOD_LAST,
     "Rest after Deborah", "底波拉之后的太平", "底波拉之後的太平"),
    ("midian", "servitude", "Judges", 6, 1, PERIOD_LAST,
     "Midian", "米甸的手下", "米甸的手下"),
    ("gideon", "rest", "Judges", 8, 28, PERIOD_LAST,
     "Quietness in Gideon's days", "基甸年间的安静", "基甸年間的安靜"),
    ("abimelech", "judge", "Judges", 9, 22, PERIOD_LAST,
     "Abimelech", "亚比米勒", "亞比米勒"),
    ("tola", "judge", "Judges", 10, 2, PERIOD_LAST,
     "Tola", "陀拉", "陀拉"),
    ("jair", "judge", "Judges", 10, 3, PERIOD_LAST,
     "Jair", "睚珥", "睚珥"),
    ("ammon", "servitude", "Judges", 10, 8, PERIOD_LAST,
     "Oppression from Ammon", "亚扪人的欺压", "亞捫人的欺壓"),
    ("jephthah", "judge", "Judges", 12, 7, 0,
     "Jephthah", "耶弗他", "耶弗他"),
    ("ibzan", "judge", "Judges", 12, 9, PERIOD_LAST,
     "Ibzan", "以比赞", "以比讚"),
    ("elon", "judge", "Judges", 12, 11, PERIOD_LAST,
     "Elon", "以伦", "以倫"),
    ("abdon", "judge", "Judges", 12, 14, PERIOD_LAST,
     "Abdon", "押顿", "押頓"),
    ("philistines", "servitude", "Judges", 13, 1, PERIOD_LAST,
     "The Philistines", "非利士人的手下", "非利士人的手下"),
    ("samson", "judge", "Judges", 15, 20, PERIOD_LAST,
     "Samson", "参孙", "參孫"),
    ("eli", "judge", "1 Samuel", 4, 18, PERIOD_LAST,
     "Eli", "以利", "以利"),
    ("david", "reign", "2 Samuel", 5, 4, PERIOD_LAST,
     "David's reign", "大卫作王", "大衛作王"),
]

# NAMED BECAUSE THEY ARE MISSING. Each of these stands inside the span 1
# Kings 6:1 measures and none is counted in the total below, so that
# total is short by all of them — which only widens the gap it already
# reports. An era that listed nothing here would read as complete.
# Four of them carry no number at all. The fifth, Solomon's years before
# the temple, does: 1 Kings 6:1 dates the founding in his fourth year.
# It is listed rather than counted on purpose, because the point of the
# ledger is the smallest overflow the text allows, and its own note says
# so — a reader who checks the verse must not find the ledger silent
# about a number that is plainly there.
PERIODS_UNNUMBERED = [
    ("joshua", "Joshua 24:29",
     "Joshua's leadership after the conquest — the verse gives his age at "
     "death, 110, not the length of his rule.",
     "约书亚得地之后带领以色列的年数——该节只记他去世时110岁，未记年数。",
     "約書亞得地之後帶領以色列的年數——該節只記他去世時110歲，未記年數。"),
    ("elders", "Judges 2:7",
     "The elders who outlived Joshua. No number of years is given.",
     "比约书亚长寿的众长老在世的年数，经文未记。",
     "比約書亞長壽的眾長老在世的年數，經文未記。"),
    ("samuel", "1 Samuel 7:15",
     "Samuel judged Israel all the days of his life; the days are not "
     "counted.",
     "撒母耳一生作以色列的士师，但未记年数。",
     "撒母耳一生作以色列的士師，但未記年數。"),
    ("saul", "1 Samuel 13:1",
     "Saul's reign. The figure in this verse is famously incomplete in "
     "the Hebrew, and the forty years usually given for it come from Acts "
     "13:21, not from the books this era is read out of.",
     "扫罗作王的年数。此节在希伯来文中数字残缺，通常所说的四十年出自使徒行传 "
     "13:21，并非出自本段所据的经卷。",
     "掃羅作王的年數。此節在希伯來文中數字殘缺，通常所說的四十年出自使徒行傳 "
     "13:21，並非出自本段所據的經卷。"),
    ("solomon", "1 Kings 6:1",
     "Solomon's years before the temple. The verse dates it in his fourth "
     "year — an ordinal, and one this total leaves out so that the "
     "overflow below is the smallest the text allows.",
     "所罗门在建殿之前作王的年数。该节记为他作王第四年——是序数；此处不计入总"
     "数，使下面的超出量取经文所容许的最小值。",
     "所羅門在建殿之前作王的年數。該節記為他作王第四年——是序數；此處不計入總"
     "數，使下面的超出量取經文所容許的最小值。"),
]

TEMPLE_ANCHOR = (6, 1, 0, "1 Kings")   # the 480th / 440th year

# THE ONE TOTAL THIS ERA HAS IS NOT STATED THE SAME WAY IN THE TWO TEXTS,
# and until this was read the asset printed the two figures side by side
# as though it were.
#
# The Hebrew's 1 Kings 6:1 is one sentence: the 480th year after the
# exodus, Solomon's fourth, the month Zif, "that he began to build the
# house of the LORD". Year and building in one clause, so the span it
# measures is stated whole.
#
# The Greek is a different edition of the chapter. 3 Kingdoms 6:1 gives
# the 440th year and the same regnal date and then STOPS — it never says
# what was done in that year. The founding stands in the Greek's own
# 6:1c, "εθεμελιωσεν τον οικον κυριου", which our records fold into the
# same verse because they are keyed on the Hebrew's numbering. So the
# Greek's total is read across two of the edition's own units.
#
# That is a fact about the text and it is recoverable from the text: the
# asset carries the edition's own numbering as `<vs:6:1c>` markers,
# printed to the reader as `(6:1c)` by build_verse_content_spans.dart.
# Splitting on them recovers the Greek's units without a second source,
# and the reader can check the finding on our own reading surface.
SUBVERSE = re.compile(r"<vs:([^>]+)>")

# THE ONLY WORDS TYPED INTO THIS FILE THAT ARE NOT A VERSE ADDRESS. They
# are a search key, not a figure: the question is which unit of the verse
# states the founding, and the answer is looked up rather than assumed.
# Both are the FINITE VERB of the founding clause, and the Greek one has
# to be, because 6:1a already speaks of stones hewn "εις τον θεμελιον
# του οικου" — the noun matches a unit that states no founding at all. If
# either key stops matching, the build stops.
FOUNDING_VERB = {"mt": "began to build", "lxx": "εθεμελιωσεν"}


def verse_units(raw, chapter, verse):
    """The edition's own verses inside one of ours, each with its label.

    The first unit carries our own reference; every later one carries the
    label the edition itself gives it.
    """
    parts = SUBVERSE.split(raw)
    units = [(f"{chapter}:{verse}", parts[0])]
    for i in range(1, len(parts), 2):
        units.append((parts[i], parts[i + 1]))
    return units


def build_periods(reader):
    """Every period this era states, plus the one total it states."""
    rows = []
    for (pid, kind, book, chapter, verse, index, en, zhs, zht) in PERIODS:
        years, ref = reader.figure(chapter, verse, index, book=book)
        rows.append({"id": pid, "kind": kind, "years": years, "ref": ref,
                     "names": {"en": en, "zh-Hans": zhs, "zh-Hant": zht}})
    chapter, verse, _index, book = TEMPLE_ANCHOR
    stated, stated_ref = reader.ordinal(*TEMPLE_ANCHOR[:3], book=book)

    # WHERE, inside that verse, each half of the claim stands.
    units = verse_units(reader.verse(chapter, verse, book=book), chapter, verse)
    # Not "a unit with some ordinal in it" — the unit that yields THIS
    # figure. A verse dated four ways over five units would otherwise
    # name whichever one came first.
    year_at = next(
        (label for label, body in units
         if reader.ordinal_runs(body)[:1] == [stated]), None)
    founding_at = next(
        (label for label, body in units
         if FOUNDING_VERB[reader.tradition] in body), None)
    if year_at is None:
        raise SystemExit(
            f"{reader.asset}: {stated_ref} parses an ordinal for the whole "
            f"verse but for none of its {len(units)} units — the split on "
            f"the edition's own numbering has gone wrong")
    if founding_at is None:
        raise SystemExit(
            f"{reader.asset}: {stated_ref} never states the founding — "
            f"{FOUNDING_VERB[reader.tradition]!r} matches none of its "
            f"{len(units)} units. The era's one total rests on this verse "
            f"measuring a span that ends at the temple; if the verb has "
            f"moved, the span has not been read.")

    return {
        "rows": rows,
        "counted": sum(r["years"] for r in rows),
        # "In the 480th year" is an ordinal: 479 years have run. The
        # subtraction is made here, once, and the asset says so in words.
        "statedOrdinal": stated,
        "statedElapsed": stated - 1,
        "statedRef": stated_ref,
        "yearAt": year_at,
        "foundingAt": founding_at,
        "units": len(units),
        "joined": year_at != founding_at,
    }


def main():
    problems = []
    mt = Reader("mt", "kjv.json", en_runs, en_ordinal_runs, 1, 0)
    lxx = Reader("lxx", "lxxwh.json", gk_runs, gk_ordinal_runs, 0, None)

    (mt_order, mt_rows, mt_flood, flood_ref, mt_flood_age, mt_flood_alt,
     mt_epochs) = build_tradition(mt, GEN11_MT, problems)
    (lxx_order, lxx_rows, lxx_flood, _, lxx_flood_age, lxx_flood_alt,
     lxx_epochs) = build_tradition(lxx, GEN11_LXX, problems)

    if problems:
        for p in problems:
            print("PARSE DISAGREES WITH THE TEXT:", p, file=sys.stderr)
        raise SystemExit(1)

    # Second witness. family_tree.json carries Anno Mundi years for the
    # same people, put there by a different script from a different
    # reading. Where both speak they must agree; a disagreement is a bug
    # in one of them and is worth more than either number alone.
    #
    # THREE DIFFERENT COMPARISONS ARE MADE HERE, AND THE SENTENCE THIS
    # BLOCK WRITES HAS TO SAY SO. It read "N of N Anno Mundi birth years
    # agree" from the day it was written, which is true of 14 of the 23
    # and false of the other 9: the tree dates the patriarchs BC, so
    # their rows are compared as intervals — a lifespan, or a
    # father-to-son gap — and an interval is not a birth year. Nothing
    # rendered the string, so nothing ever read it. Counting the kinds
    # separately is what lets the sentence be checked.
    #
    # AND THE JOIN KEY HAD TO BE PROVED BEFORE ANY OF IT COUNTED. The
    # IDS here are the Authorised Version's spellings (enos, cainan,
    # mahalaleel, salah) and family_tree.json's are the modern ones
    # (enosh, kenan, mahalalel, shelah), so five ids missed the lookup
    # and were dropped in silence — not compared, not reported, and not
    # able to fail the build no matter what they said. The DISPLAYED
    # names now agree across both assets; the ids still do not, and this
    # alias table is the whole of what holds them together.
    # The sentence's counts were true and its last clause was false for
    # those five. Every one of them agrees, so the witness only ever got
    # weaker, but a witness that skips a fifth of its rows without
    # saying so is the failure this project has already been bitten by.
    #
    # The aliases are written out one by one and never guessed from the
    # spelling: the tree holds BOTH `nahor_elder` (Terah's father, who is
    # on this chart) and `nahor_younger` (Abram's brother, who is not),
    # so a prefix match would have compared the wrong man and still
    # reported an agreement.
    TREE_ALIAS = {
        "enos": "enosh",
        "cainan": "kenan",
        "mahalaleel": "mahalalel",
        "salah": "shelah",
        "nahor": "nahor_elder",
    }
    tree = json.loads((ASSETS / "family_tree.json").read_text(encoding="utf-8"))
    by_id = {p["id"]: p for p in tree["people"]}
    unjoined = [pid for pid in mt_order
                if by_id.get(TREE_ALIAS.get(pid, pid)) is None]
    if unjoined:
        raise SystemExit(
            f"no family_tree.json record for {unjoined}; add the id to "
            f"TREE_ALIAS, or state in this message why that man cannot be "
            f"witnessed — a row that silently misses the join is not "
            f"checked by anything")
    agreed = checked = 0
    witness_kinds = {"birth": 0, "span": 0, "gap": 0}
    disagreements = []
    for pid in mt_order:
        person = by_id[TREE_ALIAS.get(pid, pid)]
        if person.get("birthYear") is None:
            continue
        if person.get("yearSystem") == "am":
            checked += 1
            witness_kinds["birth"] += 1
            if person["birthYear"] == mt_rows[pid]["birthAm"]:
                agreed += 1
            else:
                disagreements.append(
                    f"{pid}: family_tree.json says AM {person['birthYear']}, "
                    f"Genesis as read here says AM {mt_rows[pid]['birthAm']}")
            continue
        # THE PATRIARCHS ARE DATED BC THERE, SO THE YEARS CANNOT BE
        # COMPARED — BUT THE INTERVALS CAN. A lifespan and a father-to-son
        # gap are the same number in any era, so a BC-dated witness still
        # checks everything except the anchor. This is the only witness
        # the derived figure has: family_tree.json puts Joseph's birth 91
        # years after Jacob's, and it was built from a different source
        # by a different script, so it agreeing with the four-verse
        # derivation is real corroboration rather than a restatement.
        if person.get("deathYear") is not None:
            checked += 1
            witness_kinds["span"] += 1
            span = person["deathYear"] - person["birthYear"]
            if span == mt_rows[pid]["lifespan"]:
                agreed += 1
            else:
                disagreements.append(
                    f"{pid}: family_tree.json spans {span} years, "
                    f"Genesis as read here says {mt_rows[pid]['lifespan']}")
    for parent, child in (("abraham", "isaac"), ("isaac", "jacob"),
                          ("jacob", "joseph")):
        a = by_id.get(TREE_ALIAS.get(parent, parent))
        b = by_id.get(TREE_ALIAS.get(child, child))
        if a is None or b is None:
            continue
        if a.get("yearSystem") != b.get("yearSystem"):
            continue
        if a.get("birthYear") is None or b.get("birthYear") is None:
            continue
        checked += 1
        witness_kinds["gap"] += 1
        gap = b["birthYear"] - a["birthYear"]
        if gap == mt_rows[parent]["begatAt"]:
            agreed += 1
        else:
            disagreements.append(
                f"{parent}->{child}: family_tree.json puts {gap} years "
                f"between the births, Genesis as read here says "
                f"{mt_rows[parent]['begatAt']}")

    # The Septuagint's list is the Masoretic list plus Kainan, so it is the
    # spine that keeps everyone in generational order; anything only the
    # Hebrew has would be appended rather than silently dropped.
    order = list(dict.fromkeys(lxx_order + mt_order))

    # A NOTE THAT IS MEASURED, NOT ASSERTED. On the Septuagint's figures
    # Methuselah outlives the flood, which is a real and much-discussed
    # feature of that text and not an error in this arithmetic. A reader
    # who sees the bar cross the flood line will assume we miscounted, so
    # the chart has to say it — but the sentence is only emitted when the
    # numbers actually show it, so it can never outlive the data.
    # THE ERA AFTER MOSES, COUNTED. See build_periods for why it is not
    # drawn on the axis.
    mt_periods = build_periods(mt)
    lxx_periods = build_periods(lxx)
    period_rows = []
    for a, b in zip(mt_periods["rows"], lxx_periods["rows"]):
        if a["id"] != b["id"] or a["ref"] != b["ref"]:
            raise SystemExit("periods: the two readers disagree about which "
                             f"verse is being read — {a['id']} {a['ref']} vs "
                             f"{b['id']} {b['ref']}")
        period_rows.append({
            "id": a["id"],
            "kind": a["kind"],
            "name": a["names"],
            "ref": a["ref"],
            "years": {"mt": a["years"], "lxx": b["years"]},
        })
    period_splits = [r["id"] for r in period_rows
                     if r["years"]["mt"] != r["years"]["lxx"]]
    era_stated = {
        tid: {"ordinal": p["statedOrdinal"], "elapsed": p["statedElapsed"],
              # No "joined" key: it is yearAt != foundingAt, and a
              # stored duplicate of a derivable fact is a second thing
              # that can go out of step with the first. The model
              # derives it.
              "ref": p["statedRef"], "yearAt": p["yearAt"],
              "foundingAt": p["foundingAt"], "units": p["units"]}
        for tid, p in (("mt", mt_periods), ("lxx", lxx_periods))
    }
    era_counted = {"mt": mt_periods["counted"], "lxx": lxx_periods["counted"]}
    era_residue = {tid: era_counted[tid] - era_stated[tid]["elapsed"]
                   for tid in ("mt", "lxx")}
    # Every other citation this asset sets in Chinese prose names the book
    # in Chinese, so this one has to as well. Only the book name is typed:
    # the chapter and verse come off the same constant the number was read
    # at, so the prose cannot cite a verse the parser did not visit.
    era_ref_zh = {
        "zh-Hans": f"列王纪上 {TEMPLE_ANCHOR[0]}:{TEMPLE_ANCHOR[1]}",
        "zh-Hant": f"列王紀上 {TEMPLE_ANCHOR[0]}:{TEMPLE_ANCHOR[1]}",
    }
    if era_stated["mt"]["ordinal"] == era_stated["lxx"]["ordinal"]:
        raise SystemExit(
            "1 Kings 6:1 read the same in both texts — the Greek states the "
            "440th year where the Hebrew states the 480th, so an equal read "
            "means the ordinal parser has failed in one of them")

    notes = []
    # THE ONE YEAR THE WHOLE AXIS AFTER THE FLOOD RESTS ON. Both figures
    # are read out of the text — the cardinal at 7:6 and the ordinal at
    # 7:11 — and the gap between them is measured here rather than
    # asserted, so that if the two verses ever stopped being one year
    # apart the sentence would stop describing the data and the check in
    # build_tradition would have already stopped the build.
    for tid, flood_am, alt_am, age in (
            ("mt", mt_flood, mt_flood_alt, mt_flood_age),
            ("lxx", lxx_flood, lxx_flood_alt, lxx_flood_age)):
        shift = flood_am - alt_am
        notes.append({
            "id": "flood_two_datings",
            "tradition": tid,
            "personId": "noah",
            "text": {
                "en": (f"The flood is dated twice. Genesis 7:6 states Noah "
                       f"was {age} years old, and this chart takes "
                       f"that plain number, putting the flood at AM "
                       f"{flood_am}. Genesis 7:11 dates the same day to the "
                       f"{age}th year of his life, which is "
                       f"{age - 1} years complete; read that way "
                       f"the flood falls at AM {alt_am}, and because Shem's "
                       f"birth is counted from the flood every year after "
                       f"it on this chart moves {shift} year with it. That "
                       f"subtraction is the one the era below makes at "
                       f"1 Kings 6:1, where the text offers no plain number "
                       f"and there is no choice to make."),
                "zh-Hans": (f"洪水有两处纪年。创世纪 7:6 记挪亚"
                            f"{age}岁，本图取此明数，故洪水落在"
                            f"创世纪元{flood_am}年。创世纪 7:11 则记同一日在"
                            f"他一生的第{age}年，即已过"
                            f"{age - 1}年；照此读法洪水落在创世纪元"
                            f"{alt_am}年，而闪的出生是从洪水起算的，故本图"
                            f"洪水之后的每一年都随之移前{shift}年。下方"
                            f"世代总账在列王纪上 6:1 所作的正是这一减法，"
                            f"那里经文并未另给明数，别无选择。"),
                "zh-Hant": (f"洪水有兩處紀年。創世紀 7:6 記挪亞"
                            f"{age}歲，本圖取此明數，故洪水落在"
                            f"創世紀元{flood_am}年。創世紀 7:11 則記同一日在"
                            f"他一生的第{age}年，即已過"
                            f"{age - 1}年；照此讀法洪水落在創世紀元"
                            f"{alt_am}年，而閃的出生是從洪水起算的，故本圖"
                            f"洪水之後的每一年都隨之移前{shift}年。下方"
                            f"世代總賬在列王紀上 6:1 所作的正是這一減法，"
                            f"那裡經文並未另給明數，別無選擇。"),
            },
        })
    for tid, rows, flood_am in (("mt", mt_rows, mt_flood),
                                ("lxx", lxx_rows, lxx_flood)):
        over = rows["methuselah"]["deathAm"] - flood_am
        if over > 0:
            notes.append({
                "id": "methuselah_flood",
                "tradition": tid,
                "personId": "methuselah",
                "text": {
                    "en": (f"On these figures Methuselah dies {over} years "
                           f"after the flood. That follows from the ages "
                           f"this text states and is a long-discussed "
                           f"feature of it, not a slip in the arithmetic."),
                    "zh-Hans": (f"按此经文所记的岁数，玛土撒拉在洪水之后{over}"
                                f"年才去世。这是该经文自身数字推出的结果，"
                                f"历来多有讨论，并非此处计算有误。"),
                    "zh-Hant": (f"按此經文所記的歲數，瑪土撒拉在洪水之後{over}"
                                f"年才去世。這是該經文自身數字推出的結果，"
                                f"歷來多有討論，並非此處計算有誤。"),
                },
            })
    # THE SIXTY YEARS ABRAM'S BIRTH MAY BE OUT BY, computed rather than
    # asserted: Terah's total (11:32) less his age at begetting (11:26)
    # and Abram's age at leaving Haran (12:4). If the three verses ever
    # stopped conflicting the sentence would stop being emitted, which is
    # the only guarantee worth having that it still describes the data.
    for tid, rows, reader in (("mt", mt_rows, mt), ("lxx", lxx_rows, lxx)):
        depart, _ = reader.figure(12, 4)
        terah = rows["terah"]
        gap = terah["lifespan"] - terah["begatAt"] - depart
        if gap == 0:
            continue
        later = rows["terah"]["birthAm"] + terah["lifespan"] - depart
        notes.append({
            "id": "abram_birth",
            "tradition": tid,
            "personId": "abraham",
            "text": {
                "en": (f"Genesis 11:26 has Terah fathering Abram, Nahor and "
                       f"Haran at {terah['begatAt']}, and this chart takes "
                       f"that as Abram's year. On it Abram leaves Haran at "
                       f"{depart} (Genesis 12:4) {gap} years before Terah "
                       f"dies at {terah['lifespan']} (Genesis 11:32). Acts "
                       f"7:4 has Abram moving on after his father's death; "
                       f"chronologies that follow it make Abram the youngest "
                       f"of the three and put his birth at AM {later}, "
                       f"moving him and everyone after him {gap} years "
                       f"later."),
                "zh-Hans": (f"创世纪 11:26 记他拉{terah['begatAt']}岁生亚伯兰、"
                            f"拿鹤、哈兰，本图即以此年为亚伯兰的出生年。照此，"
                            f"亚伯兰{depart}岁离开哈兰（创世纪 12:4）时，他拉"
                            f"尚有{gap}年才去世（创世纪 11:32 记他拉活了"
                            f"{terah['lifespan']}岁）。使徒行传 7:4 说亚伯兰是"
                            f"在父亲死后才迁往迦南；采此读法的年代学把亚伯兰"
                            f"视为三子中最幼的，出生年定在创世纪元 {later} 年，"
                            f"他与其后各人都要往后推{gap}年。"),
                "zh-Hant": (f"創世紀 11:26 記他拉{terah['begatAt']}歲生亞伯蘭、"
                            f"拿鶴、哈蘭，本圖即以此年為亞伯蘭的出生年。照此，"
                            f"亞伯蘭{depart}歲離開哈蘭（創世紀 12:4）時，他拉"
                            f"尚有{gap}年才去世（創世紀 11:32 記他拉活了"
                            f"{terah['lifespan']}歲）。使徒行傳 7:4 說亞伯蘭是"
                            f"在父親死後才遷往迦南；採此讀法的年代學把亞伯蘭"
                            f"視為三子中最幼的，出生年定在創世紀元 {later} 年，"
                            f"他與其後各人都要往後推{gap}年。"),
            },
        })

    # WHAT THE 430 YEARS COVER, per text, measured in the shipped assets
    # rather than quoted from a commentary: the Greek of Exodus 12:40
    # names Canaan inside them and the Authorised Version does not. The
    # pair of notes is emitted only while that is true, and the two
    # totals are compared as well, so a difference in the NUMBER would be
    # reported rather than folded into a difference of scope.
    ex_mt = mt.verse(12, 40, book="Exodus")
    ex_lxx = lxx.verse(12, 40, book="Exodus")
    years_mt = en_runs(ex_mt)[0]
    years_lxx = gk_runs(ex_lxx)[0]
    canaan_lxx = "χανααν" in ex_lxx.lower()
    canaan_mt = "canaan" in ex_mt.lower()
    mt_era = mt_epochs["exodusEra"]
    lxx_era = lxx_epochs["exodusEra"]

    # THE EPOCH NOTES ARE WRITTEN ONCE AND READ UNDER EITHER TEXT, so
    # every figure they interpolate has to be the same figure in both.
    # They are written from the Masoretic variables, which is safe only
    # while that holds — and it is not a safe assumption in general: the
    # Septuagint gives Kohath 130 where the Hebrew gives 133, three
    # verses away from two of these. Measured 2026-08-25, all seven agree;
    # asserted here so that if one ever stops agreeing the build says so
    # rather than a Masoretic number quietly speaking for the Greek view
    # on a surface a reader is now reading. The `notes` list above is the
    # other shape available — per tradition — and is what a divergence
    # here should be turned into.
    for what, a, b in (
            ("Noah's age at the flood, Genesis 7:6",
             mt_flood_age, lxx_flood_age),
            ("Abram's age at Haran, Genesis 12:4",
             mt_epochs["haran"][2], lxx_epochs["haran"][2]),
            ("Jacob's age at the descent, Genesis 47:9",
             mt_epochs["descent"][2], lxx_epochs["descent"][2]),
            ("the sojourn, Exodus 12:40",
             mt_era["sojourn"][0], lxx_era["sojourn"][0]),
            ("Moses before Pharaoh, Exodus 7:7",
             mt_era["ages"]["moses"], lxx_era["ages"]["moses"]),
            ("the wilderness, Numbers 14:33",
             mt_era["wilderness"][0], lxx_era["wilderness"][0]),
            ("Moses' lifespan, Deuteronomy 34:7",
             mt_rows["moses"]["lifespan"], lxx_rows["moses"]["lifespan"])):
        if a != b:
            raise SystemExit(
                f"an epoch note interpolates {what}, which is {a} in the "
                f"Masoretic text and {b} in the Septuagint — the note can "
                f"no longer be written once for both texts")

    if years_mt == years_lxx and canaan_lxx and not canaan_mt:
        n = years_mt
        notes.append({
            "id": "sojourn_430",
            "tradition": "mt",
            "personId": None,
            "text": {
                "en": (f"Exodus 12:40 gives {n} years and this text counts "
                       f"them in Egypt, so the chart runs them from Jacob's "
                       f"descent and the exodus falls in AM "
                       f"{mt_era['exodus'][0]}. The Greek of the same verse "
                       f"counts them “in the land of Egypt and in the land "
                       f"of Canaan”, which begins them at Abraham instead; "
                       f"switch texts above to see where that puts the "
                       f"exodus."),
                "zh-Hans": (f"出埃及记 12:40 记{n}年，本经文把这些年数算在埃及，"
                            f"故本图自雅各下埃及起算，出埃及落在创世纪元 "
                            f"{mt_era['exodus'][0]} 年。希腊文同一节作「在埃及地"
                            f"和迦南地」，起点便移到亚伯拉罕；可在上方切换经文"
                            f"查看。"),
                "zh-Hant": (f"出埃及記 12:40 記{n}年，本經文把這些年數算在埃及，"
                            f"故本圖自雅各下埃及起算，出埃及落在創世紀元 "
                            f"{mt_era['exodus'][0]} 年。希臘文同一節作「在埃及地"
                            f"和迦南地」，起點便移到亞伯拉罕；可在上方切換經文"
                            f"查看。"),
            },
        })
        # THE ONE SOFT JOINT ON THIS AXIS, said in full. The verse names
        # two lands and states one total; it does not say where the
        # Canaan part starts. That the chart's own figures then divide the
        # 430 evenly is arithmetic, not corroboration, and the note says
        # so — the same refusal this script makes everywhere else.
        can, egy = lxx_era["yearsInCanaan"], lxx_era["yearsInEgypt"]
        notes.append({
            "id": "sojourn_430",
            "tradition": "lxx",
            "personId": None,
            "text": {
                "en": (f"Exodus 12:40 gives {n} years and this text counts "
                       f"them “in the land of Egypt and in the land of "
                       f"Canaan”. Where the Canaan part begins is not "
                       f"stated; this chart starts it at Abram's departure "
                       f"from Haran, which is a reading and not a figure the "
                       f"verse supplies — the one place on this axis where a "
                       f"year had to be supplied rather than read. On it the "
                       f"{n} divide into {can} years in Canaan and {egy} in "
                       f"Egypt, but the second is the first taken off the "
                       f"same total and is not an independent check. "
                       f"Galatians 3:17 puts {n} years between a promise to "
                       f"Abraham and the law without saying which promise, "
                       f"and is cited on both sides of this."),
                "zh-Hans": (f"出埃及记 12:40 记{n}年，本经文作「在埃及地和迦南"
                            f"地」。迦南那一段从何时起算，经文并未言明；本图以"
                            f"亚伯兰离开哈兰为起点，这是一种读法，并非该节所记"
                            f"的数字——也是本时间轴上唯一需要补入而非读出的年"
                            f"份。照此，{n}年分为迦南{can}年、埃及{egy}年，但后"
                            f"者是从同一总数中减出，并非独立的旁证。加拉太书 "
                            f"3:17 记神应许亚伯拉罕与律法相隔{n}年，却未指明是"
                            f"哪一次应许，故两种读法皆引之。"),
                "zh-Hant": (f"出埃及記 12:40 記{n}年，本經文作「在埃及地和迦南"
                            f"地」。迦南那一段從何時起算，經文並未言明；本圖以"
                            f"亞伯蘭離開哈蘭為起點，這是一種讀法，並非該節所記"
                            f"的數字——也是本時間軸上唯一需要補入而非讀出的年"
                            f"份。照此，{n}年分為迦南{can}年、埃及{egy}年，但後"
                            f"者是從同一總數中減出，並非獨立的旁證。加拉太書 "
                            f"3:17 記神應許亞伯拉罕與律法相隔{n}年，卻未指明是"
                            f"哪一次應許，故兩種讀法皆引之。"),
            },
        })

    # THE GENERATIONS AGAINST THE GAP. Exodus 6:18 and 6:20 cap how many
    # years can separate the descent from the exodus, and which way the
    # cap falls is the whole substance of the argument over 12:40 — so it
    # is computed here per text and reported either way, never asserted.
    for tid, era in (("mt", mt_era), ("lxx", lxx_era)):
        (kohath, kohath_ref), (amram, amram_ref) = era["ceilingParts"]
        ceiling, gap = era["ceiling"], era["yearsInEgypt"]
        pharaoh = era["ages"]["moses"]
        common_en = (
            f"{kohath_ref} gives Kohath {kohath} years and {amram_ref} gives "
            f"Amram {amram}, and Genesis 46:11 has Kohath already born when "
            f"Jacob went down. Read as father to son, what is left of "
            f"Kohath's life, the whole of Amram's and Moses' {pharaoh} years "
            f"before Pharaoh cannot exceed {ceiling} years")
        common_zhs = (
            f"{cite_zh(kohath_ref, 'zh-Hans')} 记哥辖活了{kohath}岁，"
            f"{cite_zh(amram_ref, 'zh-Hans')} 记暗兰活了"
            f"{amram}岁，而创世纪 46:11 已列哥辖在下埃及之人中。若按父子相承"
            f"来读，哥辖余下的年岁、暗兰的一生，加上摩西见法老时的{pharaoh}"
            f"岁，至多不过{ceiling}年")
        common_zht = (
            f"{cite_zh(kohath_ref, 'zh-Hant')} 記哥轄活了{kohath}歲，"
            f"{cite_zh(amram_ref, 'zh-Hant')} 記暗蘭活了"
            f"{amram}歲，而創世紀 46:11 已列哥轄在下埃及之人中。若按父子相承"
            f"來讀，哥轄餘下的年歲、暗蘭的一生，加上摩西見法老時的{pharaoh}"
            f"歲，至多不過{ceiling}年")
        if ceiling < gap:
            short = gap - ceiling
            text = {
                "en": (f"{common_en} — {short} short of the {gap} this text "
                       f"puts between the descent and the exodus. It is the "
                       f"oldest objection to counting all {gap} in Egypt, and "
                       f"it comes from these same verses rather than from "
                       f"outside them."),
                "zh-Hans": (f"{common_zhs}——比本经文所定下埃及至出埃及的{gap}"
                            f"年还少{short}年。这正是反对把{gap}年全算在埃及的"
                            f"最古老质疑，且出自这几节经文本身，而非外来之说。"),
                "zh-Hant": (f"{common_zht}——比本經文所定下埃及至出埃及的{gap}"
                            f"年還少{short}年。這正是反對把{gap}年全算在埃及的"
                            f"最古老質疑，且出自這幾節經文本身，而非外來之說。"),
            }
        else:
            spare = ceiling - gap
            text = {
                "en": (f"{common_en}, and this text puts {gap} years between "
                       f"the descent and the exodus — so the generations fit, "
                       f"with {spare} years to spare. On the other text's "
                       f"reading of Exodus 12:40 the same three lives fall "
                       f"short, which is what the argument over that verse "
                       f"is about."),
                "zh-Hans": (f"{common_zhs}；而本经文所定下埃及至出埃及为{gap}"
                            f"年，故三代人足以相接，尚余{spare}年。若照另一经文"
                            f"对出埃及记 12:40 的读法，这三人的年岁便不够——两"
                            f"种读法之争正在于此。"),
                "zh-Hant": (f"{common_zht}；而本經文所定下埃及至出埃及為{gap}"
                            f"年，故三代人足以相接，尚餘{spare}年。若照另一經文"
                            f"對出埃及記 12:40 的讀法，這三人的年歲便不夠——兩"
                            f"種讀法之爭正在於此。"),
            }
        notes.append({"id": "levi_ceiling", "tradition": tid,
                      "personId": "moses", "text": text})

    # WHY TWO BARS END IN THE SAME YEAR. Aaron dies in the fortieth year
    # after the exodus and Moses at the end of it, so at one-year
    # resolution both land together. A reader who sees that will suspect
    # the arithmetic, so it is stated — and only while the years actually
    # coincide, which is the only guarantee that the sentence still
    # describes the data.
    for tid, rows in (("mt", mt_rows), ("lxx", lxx_rows)):
        if rows["aaron"]["deathAm"] != rows["moses"]["deathAm"]:
            continue
        notes.append({
            "id": "same_year_deaths",
            "tradition": tid,
            "personId": "aaron",
            "text": {
                "en": ("Aaron's bar and Moses' end in the same year. Numbers "
                       "33:38 has Aaron die in the fortieth year after the "
                       "exodus and Moses dies at the close of those forty, so "
                       "at this chart's resolution of one year the two "
                       "coincide. Aaron dies first."),
                "zh-Hans": ("亚伦与摩西的横条结束于同一年。民数记 33:38 记亚伦"
                            "死于出埃及后第四十年，摩西则死于这四十年之末，按本"
                            "图以年为最小刻度，二者遂落在同一年。亚伦先死。"),
                "zh-Hant": ("亞倫與摩西的橫條結束於同一年。民數記 33:38 記亞倫"
                            "死於出埃及後第四十年，摩西則死於這四十年之末，按本"
                            "圖以年為最小刻度，二者遂落在同一年。亞倫先死。"),
            },
        })

    # ONE TOTAL, TWO WAYS OF STATING IT. Emitted only for a tradition
    # whose year and whose founding were found in different units of the
    # verse, so a text that states both together says nothing here. See
    # FOUNDING_VERB for how the two are located.
    for tid in ("mt", "lxx"):
        st = era_stated[tid]
        if st["yearAt"] == st["foundingAt"]:
            continue
        notes.append({
            "id": "era_join",
            "tradition": tid,
            # No `refs` key: ChronologyNote carries none, and a key
            # nothing renders is worse than a key nobody wrote. The
            # reference is named in the prose instead.
            "personId": None,
            "text": {
                "en": (f"This text does not state that span in one place. "
                       f"{st['ref']} in this app's numbering holds "
                       f"{st['units']} of the edition's own verses, and the "
                       f"reading text marks where each of them begins. "
                       f"The {st['ordinal']}th year stands in "
                       f"{st['yearAt']}, which dates it to Solomon's fourth "
                       f"year and the second month and then says nothing "
                       f"about what was done in it; the founding of the "
                       f"house is stated in {st['foundingAt']}. So this "
                       f"total is read across two units, and the ledger "
                       f"below says which. The other text states the year "
                       f"and the building in one sentence."),
                "zh-Hans": (f"本经文并非在一处记下这段年数。"
                            f"{era_ref_zh['zh-Hans']} 在本应用的编号之下，"
                            f"含该版本自己的 {st['units']} 节，阅读界面在"
                            f"每节起处均有标记。第"
                            f"{st['ordinal']}年记在 {st['yearAt']}，只把它"
                            f"系于所罗门作王第四年二月，并未说那一年作了什"
                            f"么；殿的奠基则记在 {st['foundingAt']}。故此"
                            f"总数是跨两节读出的，下方的统计表注明是哪两"
                            f"节。另一经文则在一句之内同记年份与建殿。"),
                "zh-Hant": (f"本經文並非在一處記下這段年數。"
                            f"{era_ref_zh['zh-Hant']} 在本應用的編號之下，"
                            f"含該版本自己的 {st['units']} 節，閱讀介面在"
                            f"每節起處均有標記。第"
                            f"{st['ordinal']}年記在 {st['yearAt']}，只把它"
                            f"繫於所羅門作王第四年二月，並未說那一年作了什"
                            f"麼；殿的奠基則記在 {st['foundingAt']}。故此"
                            f"總數是跨兩節讀出的，下方的統計表註明是哪兩"
                            f"節。另一經文則在一句之內同記年份與建殿。"),
            },
        })

    # WHERE THE CHART STOPS, AND WHY THE REASON CHANGED. Until the
    # ordinal reader existed this note said the chart stopped because the
    # parser could not read 1 Kings 6:1, and that was true. It is no
    # longer: the verse is read, in both languages, and the era it opens
    # is counted in `era` below. The chart still stops here, for a reason
    # that is about the TEXT rather than about us — after Moses it stops
    # handing over a chain, and the periods it does state overrun the one
    # total it states. So the note is emitted only while that overflow is
    # actually in the data, and it prints the measurement.
    for tid in ("mt", "lxx"):
        if era_residue[tid] <= 0:
            continue
        # "Carries the span on to Solomon's temple" is a plain claim
        # about a verse, and in the Greek it was not true of the verse
        # alone — that text names the year in one unit and the founding
        # in another. The clause is hedged from the reading, so a text
        # that states both together is not hedged for the sake of it.
        joined_en = (f" (read across its {era_stated[tid]['yearAt']} and "
                     f"{era_stated[tid]['foundingAt']}, see the note above)"
                     if era_stated[tid]["yearAt"]
                     != era_stated[tid]["foundingAt"] else "")
        joined_zh = (f"（跨该版本 {era_stated[tid]['yearAt']} 与 "
                     f"{era_stated[tid]['foundingAt']} 两节读出，见上）"
                     if era_stated[tid]["yearAt"]
                     != era_stated[tid]["foundingAt"] else " ")
        joined_zht = (f"（跨該版本 {era_stated[tid]['yearAt']} 與 "
                      f"{era_stated[tid]['foundingAt']} 兩節讀出，見上）"
                      if era_stated[tid]["yearAt"]
                     != era_stated[tid]["foundingAt"] else " ")
        notes.append({
            "id": "chart_end",
            "tradition": tid,
            # About the chart, not about Moses — he is merely the last
            # man on it — so it belongs in the header, where a reader who
            # has selected nobody is looking.
            "personId": None,
            "text": {
                "en": (f"The chart ends here, and not for want of "
                       f"numbers. {era_stated[tid]['ref']}{joined_en} "
                       f"carries the span on to Solomon's temple — the "
                       f"{era_stated[tid]['ordinal']}th year after the "
                       f"exodus, {era_stated[tid]['elapsed']} years — but "
                       f"the periods the text states inside it come to "
                       f"{era_counted[tid]}, over by {era_residue[tid]}, "
                       f"with more stretches it gives no number to at "
                       f"all. Laying those bars end to end would be a "
                       f"reconstruction, so this era is counted below "
                       f"instead of drawn."),
                "zh-Hans": (f"本图到此为止，并非因为经文没有数字。"
                            f"{era_ref_zh['zh-Hans']}{joined_zh}把年数一直带到所罗门建"
                            f"殿——出埃及后第{era_stated[tid]['ordinal']}年，"
                            f"即{era_stated[tid]['elapsed']}年——但其间经文逐"
                            f"条所记的各段年数合计{era_counted[tid]}年，多出"
                            f"{era_residue[tid]}年，还有几段全然未记年数。把这"
                            f"些年段一段接一段排在轴上，就成了重构；故本图不画"
                            f"这一段，只在下方作统计。"),
                "zh-Hant": (f"本圖到此為止，並非因為經文沒有數字。"
                            f"{era_ref_zh['zh-Hant']}{joined_zht}把年數一直帶到所羅門建"
                            f"殿——出埃及後第{era_stated[tid]['ordinal']}年，"
                            f"即{era_stated[tid]['elapsed']}年——但其間經文逐"
                            f"條所記的各段年數合計{era_counted[tid]}年，多出"
                            f"{era_residue[tid]}年，還有幾段全然未記年數。把這"
                            f"些年段一段接一段排在軸上，就成了重構；故本圖不畫"
                            f"這一段，只在下方作統計。"),
            },
        })

    patriarchs = []
    for pid in order:
        entry = {
            "id": pid,
            "name": names(pid),
            "line": LINE.get(pid, "seth"),
            "figures": {},
        }
        if pid in KJV_NAMES:
            # After "name", before "line" — the order the asset is in.
            entry = {"id": entry["id"], "name": entry["name"],
                     "nameKjv": KJV_NAMES[pid], "line": entry["line"],
                     "figures": entry["figures"]}
        for tid, rows in (("mt", mt_rows), ("lxx", lxx_rows)):
            if pid in rows:
                entry["figures"][tid] = rows[pid]
        patriarchs.append(entry)

    # HOW FAR THE TWO TEXTS ACTUALLY DIVERGE, counted rather than
    # described. The Septuagint runs some 1,250 years longer than the
    # Hebrew by Terah, which invites the assumption that its figures
    # differ everywhere. They do not: the divergence is confined to the
    # two genealogical formulae, and from Terah on the two texts state
    # the same numbers. Worth saying, because it tells a reader which
    # part of this chart the choice of text actually moves.
    #
    # "The same FIGURES", not "the same begetting age and lifespan": for
    # Joseph, Aaron and Moses the begetting age is null in both texts, so
    # the sentence was reporting an agreement of two absences as though
    # the texts had each stated an age. What is true of all 25 is that
    # every figure either text states, the other states alike.
    def _agree(pids):
        same = both = 0
        for pid in pids:
            if pid not in mt_rows or pid not in lxx_rows:
                continue
            both += 1
            if (mt_rows[pid]["begatAt"] == lxx_rows[pid]["begatAt"]
                    and mt_rows[pid]["lifespan"] == lxx_rows[pid]["lifespan"]):
                same += 1
        return same, both

    gen_ids = [p[0] for p in GEN5] + ["noah", "shem"] + [
        p[0] for p in GEN11_MT]
    abr_ids = [p[0] for p in ABRAHAMIC]
    # Moses and Aaron are the only rows read from outside Genesis, and
    # while the axis stopped at Joseph the sentence covered every man on
    # the chart. It no longer did: two rows were drawn that no group
    # counted, so a reader was being told how far the texts differ by a
    # sentence silently scoped to 23 of the 25 rows in front of them.
    exo_ids = ["aaron", "moses"]
    gen_same, gen_both = _agree(gen_ids)
    abr_same, abr_both = _agree(abr_ids)
    exo_same, exo_both = _agree(exo_ids)
    # Every row is in exactly one group, or is stated by one text only
    # (the Septuagint's second Kainan) and so cannot agree or disagree.
    single = sum(1 for p in patriarchs if len(p["figures"]) < 2)
    if gen_both + abr_both + exo_both + single != len(patriarchs):
        raise SystemExit(
            f"the agreement sentence covers {gen_both + abr_both + exo_both} "
            f"of {len(patriarchs) - single} comparable rows; every row on the "
            f"chart has to be in one of its groups")

    doc = {
        "schemaVersion": 1,
        "_meta": {
            "generator": "scripts/build_chronology.py",
            "unit": "am",
            # Localised, unlike its siblings in this block, because it is
            # the only one of them the app prints. It carries the Ussher
            # caveat — the sentence that keeps the axis from being read
            # as a BC dating — and it went to a Chinese reader in
            # English, which is to say it did not go to them at all.
            "unitNote": {
                "en": (
                    "Anno Mundi — years counted from the creation, as the "
                    "ages in Genesis 5 and 11 accumulate them. The text "
                    "supplies no absolute date, so no BC year is stated "
                    "here. Ussher's 4004 BC is one 17th-century "
                    "reconstruction among several and is not adopted."),
                "zh-Hans": (
                    "创世纪元——自创世起算的年数，按创世纪 5 章与 11 章"
                    "所记的岁数累加而得。经文并未给出可换算的绝对年代，"
                    "故此处不列公元前年份。Ussher 的公元前 4004 年只是"
                    "十七世纪诸多推算之一，本图未予采用。"),
                "zh-Hant": (
                    "創世紀元——自創世起算的年數，按創世紀 5 章與 11 章"
                    "所記的歲數累加而得。經文並未給出可換算的絕對年代，"
                    "故此處不列公元前年份。Ussher 的公元前 4004 年只是"
                    "十七世紀諸多推算之一，本圖未予採用。"),
            },
            # THE READER IS OWED THE EDITION, NOT OUR FILENAME. These
            # sentences are printed now, so they are written three times
            # like everything else on the page — and the asset path is a
            # sibling key rather than part of the prose. A path cannot be
            # translated, so putting one inside a Chinese paragraph
            # would reintroduce the exact defect phase 8 removed; and
            # naming the *edition* is the more useful sentence anyway,
            # because a reader can open 英王钦定本 in this app and check
            # the verse, which they cannot do with `assets/kjv.json`.
            "derivedFrom": {
                "mt": {
                    "asset": "assets/kjv.json",
                    "text": {
                        "en": (
                            "Every Masoretic figure on this chart is read "
                            "out of the Authorised Version bundled with "
                            "this app (public domain), which renders the "
                            "Masoretic numbers. Only the verse addresses "
                            "are written down; every number is taken from "
                            "the verse itself."),
                        "zh-Hans": (
                            "本图表中马所拉一系的每个数字，都是从本应用"
                            "所载的英王钦定本（公有领域）中读出的，该译本"
                            "所据即马所拉经文。写定的只有经文出处，数字"
                            "一概取自经文本身。"),
                        "zh-Hant": (
                            "本圖表中馬所拉一系的每個數字，都是從本應用"
                            "所載的英王欽定本（公有領域）中讀出的，該譯本"
                            "所據即馬所拉經文。寫定的只有經文出處，數字"
                            "一概取自經文本身。"),
                    },
                },
                "lxx": {
                    "asset": "assets/lxxwh.json",
                    "text": {
                        "en": (
                            "The Septuagint figures are read in Greek out "
                            "of the Septuagint bundled with this app, by "
                            "the same script and in the same way."),
                        "zh-Hans": (
                            "七十士一系的数字，则以希腊文从本应用所载的"
                            "七十士译本中读出，方法与上相同。"),
                        "zh-Hant": (
                            "七十士一系的數字，則以希臘文從本應用所載的"
                            "七十士譯本中讀出，方法與上相同。"),
                    },
                },
            },
            "checks": {
                "sumsChecked": sum(
                    1 for p in patriarchs for f in p["figures"].values()
                    if f["checked"]),
                "note": {
                    "en": (
                        "Genesis 5 states the age at begetting, the years "
                        "lived afterwards, and the total, so the parse of "
                        "every Genesis 5 figure is checked against the third "
                        "number the verse itself supplies. Genesis 11 states "
                        "only the first two, so those lifespans are sums and "
                        "carry no such check. In Genesis 12-50 only Jacob "
                        "has a third figure — Genesis 47:9's 130 plus "
                        "Genesis 47:28's 17 years in Egypt against the 147 "
                        "that same verse states — and it checks the descent "
                        "year as well as the parse. Moses and Aaron are "
                        "checked the same way across three books: an age "
                        "before Pharaoh (Exodus 7:7), the forty years of "
                        "Numbers 14:33, and a lifetime stated separately in "
                        "Deuteronomy 34:7 and Numbers 33:39. Checked "
                        "describes the parse, never the year on the axis; "
                        "where a year had to be supplied the note says so."),
                    **{
                        script: (
                            f"{cite_zh('Genesis 5', script)} 章同时记下生子"
                            f"时的岁数、生子之后所活的年数，以及一生的总"
                            f"年数，所以该章每个数字的解析，都可以用经文"
                            f"自己给出的第三个数来核对。"
                            f"{cite_zh('Genesis 11', script)} 章只记前两项，"
                            f"故那些寿数是相加所得，无从如此核对。"
                            f"{cite_zh('Genesis 12-50', script)} 章中只有"
                            f"雅各有第三个数——"
                            f"{cite_zh('Genesis 47:9', script)} 的 130 岁，"
                            f"加上{cite_zh('Genesis 47:28', script)} 在埃及"
                            f"的 17 年，正是同一节所说的 147 年——这不但"
                            f"核对了数字的解析，也核对了下埃及的那一年。"
                            f"摩西与亚伦则跨三卷书以同样方式核对：见法老"
                            f"前的岁数（{cite_zh('Exodus 7:7', script)}）、"
                            f"{cite_zh('Numbers 14:33', script)} 的四十年，"
                            f"以及{cite_zh('Deuteronomy 34:7', script)} 与"
                            f"{cite_zh('Numbers 33:39', script)} 分别记下的"
                            f"一生年数。所谓核对，说的是数字的解析，而非轴"
                            f"上的年份；凡年份须由推算补上之处，注中都会"
                            f"说明。"
                        ) if script == "zh-Hans" else (
                            f"{cite_zh('Genesis 5', script)} 章同時記下生子"
                            f"時的歲數、生子之後所活的年數，以及一生的總"
                            f"年數，所以該章每個數字的解析，都可以用經文"
                            f"自己給出的第三個數來核對。"
                            f"{cite_zh('Genesis 11', script)} 章只記前兩項，"
                            f"故那些壽數是相加所得，無從如此核對。"
                            f"{cite_zh('Genesis 12-50', script)} 章中只有"
                            f"雅各有第三個數——"
                            f"{cite_zh('Genesis 47:9', script)} 的 130 歲，"
                            f"加上{cite_zh('Genesis 47:28', script)} 在埃及"
                            f"的 17 年，正是同一節所說的 147 年——這不但"
                            f"核對了數字的解析，也核對了下埃及的那一年。"
                            f"摩西與亞倫則跨三卷書以同樣方式核對：見法老"
                            f"前的歲數（{cite_zh('Exodus 7:7', script)}）、"
                            f"{cite_zh('Numbers 14:33', script)} 的四十年，"
                            f"以及{cite_zh('Deuteronomy 34:7', script)} 與"
                            f"{cite_zh('Numbers 33:39', script)} 分別記下的"
                            f"一生年數。所謂核對，說的是數字的解析，而非軸"
                            f"上的年份；凡年份須由推算補上之處，註中都會"
                            f"說明。"
                        )
                        for script in ("zh-Hans", "zh-Hant")
                    },
                },
                "traditionAgreement": {
                    "en": (
                        f"Genesis 5 and 11: the two texts state the same "
                        f"figures for {gen_same} of "
                        f"{gen_both} men. Genesis 12-50: {abr_same} of "
                        f"{abr_both}. Exodus to Deuteronomy: {exo_same} of "
                        f"{exo_both}. The choice of text therefore moves the "
                        f"genealogies and leaves everyone after them where "
                        f"they are."),
                    "zh-Hans": (
                        f"{cite_zh('Genesis 5', 'zh-Hans')}、11 章："
                        f"两种经文对其中 {gen_both} 人里的 {gen_same} 人，"
                        f"所记数字相同。"
                        f"{cite_zh('Genesis 12-50', 'zh-Hans')} 章："
                        f"{abr_both} 人里 {abr_same} 人。"
                        f"{book_zh('Exodus', 'zh-Hans')}至"
                        f"{book_zh('Deuteronomy', 'zh-Hans')}："
                        f"{exo_both} 人里 {exo_same} 人。可见选用哪一种经文，"
                        f"动的是家谱，其后各人所在的年代并不改变。"),
                    "zh-Hant": (
                        f"{cite_zh('Genesis 5', 'zh-Hant')}、11 章："
                        f"兩種經文對其中 {gen_both} 人裡的 {gen_same} 人，"
                        f"所記數字相同。"
                        f"{cite_zh('Genesis 12-50', 'zh-Hant')} 章："
                        f"{abr_both} 人裡 {abr_same} 人。"
                        f"{book_zh('Exodus', 'zh-Hant')}至"
                        f"{book_zh('Deuteronomy', 'zh-Hant')}："
                        f"{exo_both} 人裡 {exo_same} 人。可見選用哪一種經文，"
                        f"動的是家譜，其後各人所在的年代並不改變。"),
                },
                # THE THREE KINDS ARE NAMED because they are not the same
                # claim. Comparing two Anno Mundi birth years tests the
                # anchor as well as the arithmetic; comparing an interval
                # tests only the arithmetic, and is all a BC-dated witness
                # can give. A sentence that called all 23 "birth years"
                # would overstate 9 of them.
                "secondWitness": {
                    "en": (
                        f"{agreed} of {checked} figures agree with this "
                        f"app's Family Tree, which was built separately, "
                        f"from a different source: "
                        f"{witness_kinds['birth']} Anno Mundi birth years "
                        f"compared directly, {witness_kinds['span']} "
                        f"lifespans compared as intervals because that "
                        f"record dates those men BC, and "
                        f"{witness_kinds['gap']} father-to-son gaps. A "
                        f"disagreement stops this chart being built."),
                    "zh-Hans": (
                        f"本图表有 {checked} 处可与本应用另行建立的圣经"
                        f"家谱对照，{agreed} 处相符。家谱是另据别的资料、"
                        f"由另一段程式建成的：其中 {witness_kinds['birth']} "
                        f"处直接比对创世纪元的出生年，"
                        f"{witness_kinds['span']} 处因家谱以公元前纪年，"
                        f"改以一生年数这一段年数比对，另有 "
                        f"{witness_kinds['gap']} 处比对父子出生相隔的年数。"
                        f"若有一处不合，本图表便不会生成。"),
                    "zh-Hant": (
                        f"本圖表有 {checked} 處可與本應用另行建立的聖經"
                        f"家譜對照，{agreed} 處相符。家譜是另據別的資料、"
                        f"由另一段程式建成的：其中 {witness_kinds['birth']} "
                        f"處直接比對創世紀元的出生年，"
                        f"{witness_kinds['span']} 處因家譜以公元前紀年，"
                        f"改以一生年數這一段年數比對，另有 "
                        f"{witness_kinds['gap']} 處比對父子出生相隔的年數。"
                        f"若有一處不合，本圖表便不會生成。"),
                },
                "disagreements": disagreements,
            },
            "traditions": {
                "en": (
                    "The Masoretic Text and the Septuagint state different "
                    "ages in Genesis 5 and 11, and both texts ship with this "
                    "app, so both are charted. The Samaritan Pentateuch "
                    "states a third set of figures; this app does not carry "
                    "that text, so it is absent here rather than estimated."),
                "zh-Hans": (
                    f"马所拉经文与七十士译本在"
                    f"{cite_zh('Genesis 5', 'zh-Hans')}、11 章所记的岁数"
                    f"并不相同，而本应用两种经文都有，故两种都绘出。"
                    f"撒玛利亚五经另记第三套数字；本应用未收录该经文，"
                    f"因此此处付之阙如，而不以推算补足。"),
                "zh-Hant": (
                    f"馬所拉經文與七十士譯本在"
                    f"{cite_zh('Genesis 5', 'zh-Hant')}、11 章所記的歲數"
                    f"並不相同，而本應用兩種經文都有，故兩種都繪出。"
                    f"撒瑪利亞五經另記第三套數字；本應用未收錄該經文，"
                    f"因此此處付之闕如，而不以推算補足。"),
            },
        },
        "traditions": [
            {
                "id": "mt",
                "name": {"en": "Masoretic", "zh-Hans": "马所拉", "zh-Hant": "馬所拉"},
                "longName": {
                    "en": "Masoretic Text (via the Authorised Version)",
                    "zh-Hans": "马所拉经文（据英王钦定本）",
                    "zh-Hant": "馬所拉經文（據英王欽定本）",
                },
                "floodAm": mt_flood,
                "endAm": max(r["deathAm"] for r in mt_rows.values()),
            },
            {
                "id": "lxx",
                "name": {"en": "Septuagint", "zh-Hans": "七十士", "zh-Hant": "七十士"},
                "longName": {
                    "en": "Septuagint (Greek Old Testament)",
                    "zh-Hans": "七十士译本（希腊文旧约）",
                    "zh-Hant": "七十士譯本（希臘文舊約）",
                },
                "floodAm": lxx_flood,
                "endAm": max(r["deathAm"] for r in lxx_rows.values()),
            },
        ],
        "epochs": [
            {
                "id": "flood",
                "name": {"en": "The Flood", "zh-Hans": "洪水", "zh-Hant": "洪水"},
                "ref": flood_ref,
                "years": {"mt": mt_flood, "lxx": lxx_flood},
                "note": {
                    # 7:6's wording, not 7:11's: this verse states an age,
                    # and "his 600th year" is the other verse's ordinal
                    # and a year earlier. See the note on Noah.
                    "en": f"Genesis 7:6 states Noah was {mt_flood_age} years old at the flood.",
                    "zh-Hans": f"创世纪 7:6 记洪水在挪亚{mt_flood_age}岁那年。",
                    "zh-Hant": f"創世紀 7:6 記洪水在挪亞{mt_flood_age}歲那年。",
                },
            },
            {
                "id": "haran",
                "name": {"en": "Abram leaves Haran", "zh-Hans": "亚伯兰离开哈兰",
                         "zh-Hant": "亞伯蘭離開哈蘭"},
                "ref": mt_epochs["haran"][1],
                "years": {"mt": mt_epochs["haran"][0],
                          "lxx": lxx_epochs["haran"][0]},
                "note": {
                    "en": (f"Genesis 12:4 has Abram {mt_epochs['haran'][2]} "
                           f"years old when he left Haran."),
                    "zh-Hans": (f"创世纪 12:4 记亚伯兰离开哈兰时"
                                f"{mt_epochs['haran'][2]}岁。"),
                    "zh-Hant": (f"創世紀 12:4 記亞伯蘭離開哈蘭時"
                                f"{mt_epochs['haran'][2]}歲。"),
                },
            },
            {
                "id": "descent",
                "name": {"en": "Into Egypt", "zh-Hans": "下埃及", "zh-Hant": "下埃及"},
                "ref": mt_epochs["descent"][1],
                "years": {"mt": mt_epochs["descent"][0],
                          "lxx": lxx_epochs["descent"][0]},
                "note": {
                    "en": (f"Jacob tells Pharaoh he is "
                           f"{mt_epochs['descent'][2]} (Genesis 47:9); 47:28 "
                           f"adds the 17 years he then lived in Egypt and "
                           f"states the total, so this year is checked "
                           f"against a third figure."),
                    "zh-Hans": (f"雅各对法老说自己{mt_epochs['descent'][2]}岁"
                                f"（创世纪 47:9）；47:28 记他此后在埃及又活了"
                                f"17年，并记出总岁数，故此年另有第三个数字可核。"),
                    "zh-Hant": (f"雅各對法老說自己{mt_epochs['descent'][2]}歲"
                                f"（創世紀 47:9）；47:28 記他此後在埃及又活了"
                                f"17年，並記出總歲數，故此年另有第三個數字可核。"),
                },
            },
            {
                "id": "exodus",
                "name": {"en": "The Exodus", "zh-Hans": "出埃及",
                         "zh-Hant": "出埃及"},
                "ref": mt_era["exodus"][1],
                "years": {"mt": mt_era["exodus"][0],
                          "lxx": lxx_era["exodus"][0]},
                "note": {
                    "en": (f"Exodus 12:40's {mt_era['sojourn'][0]} years. "
                           f"Each text is counted from where its own wording "
                           f"starts them, which is why this line moves when "
                           f"the text does; see the note on the sojourn."),
                    "zh-Hans": (f"出埃及记 12:40 所记的{mt_era['sojourn'][0]}"
                                f"年。两种经文各按自身措辞的起点起算，故切换经"
                                f"文时此线会移动；参寄居年数一条的说明。"),
                    "zh-Hant": (f"出埃及記 12:40 所記的{mt_era['sojourn'][0]}"
                                f"年。兩種經文各按自身措辭的起點起算，故切換經"
                                f"文時此線會移動；參寄居年數一條的說明。"),
                },
            },
            {
                "id": "moses_death",
                "name": {"en": "Moses dies", "zh-Hans": "摩西去世",
                         "zh-Hant": "摩西去世"},
                "ref": mt_era["mosesDeath"][1],
                "years": {"mt": mt_era["mosesDeath"][0],
                          "lxx": lxx_era["mosesDeath"][0]},
                "note": {
                    "en": (f"Moses is {mt_era['ages']['moses']} before "
                           f"Pharaoh (Exodus 7:7), the wilderness is "
                           f"{mt_era['wilderness'][0]} years (Numbers 14:33), "
                           f"and Deuteronomy 34:7 states the "
                           f"{mt_rows['moses']['lifespan']} those two add to "
                           f"— which he also says himself at "
                           f"{mt_era['mosesSaysRef']}."),
                    "zh-Hans": (f"摩西见法老时{mt_era['ages']['moses']}岁（出埃"
                                f"及记 7:7），旷野{mt_era['wilderness'][0]}年"
                                f"（民数记 14:33），申命记 34:7 所记的"
                                f"{mt_rows['moses']['lifespan']}岁正是二者之"
                                f"和；"
                                f"{cite_zh(mt_era['mosesSaysRef'], 'zh-Hans')}"
                                f" 他也亲口说出这个岁数。"),
                    "zh-Hant": (f"摩西見法老時{mt_era['ages']['moses']}歲（出埃"
                                f"及記 7:7），曠野{mt_era['wilderness'][0]}年"
                                f"（民數記 14:33），申命記 34:7 所記的"
                                f"{mt_rows['moses']['lifespan']}歲正是二者之"
                                f"和；"
                                f"{cite_zh(mt_era['mosesSaysRef'], 'zh-Hant')}"
                                f" 他也親口說出這個歲數。"),
                },
            },
        ],
        "notes": notes,
        "era": {
            "id": "exodus_to_temple",
            "name": {
                "en": "From the exodus to the temple",
                "zh-Hans": "从出埃及到建殿",
                "zh-Hant": "從出埃及到建殿",
            },
            "stated": era_stated,
            "counted": era_counted,
            "residue": era_residue,
            "splitIds": period_splits,
            "periods": period_rows,
            "unnumbered": [
                {"id": pid, "ref": ref,
                 "note": {"en": en, "zh-Hans": zhs, "zh-Hant": zht}}
                for (pid, ref, en, zhs, zht) in PERIODS_UNNUMBERED
            ],
            "summary": {
                "en": (
                    f"{era_stated['mt']['ref']} states the whole span from "
                    f"the exodus to the founding of the temple as one "
                    f"number — the {era_stated['mt']['ordinal']}th year, so "
                    f"{era_stated['mt']['elapsed']} years have run. The "
                    f"periods this era states one by one add up to "
                    f"{era_counted['mt']}, which is {era_residue['mt']} "
                    f"years more than the span containing them, and that is "
                    f"before {len(PERIODS_UNNUMBERED)} further stretches "
                    f"listed below that this total does not count. On "
                    f"the Greek the same two figures are "
                    f"{era_counted['lxx']} against "
                    f"{era_stated['lxx']['elapsed']}, over by "
                    f"{era_residue['lxx']}. Nothing here is reconciled: the "
                    f"text nowhere says these periods run one after "
                    f"another, and at Judges 10:7 two oppressions run at "
                    f"once. So this era is counted and not drawn — no "
                    f"arrangement of these figures on the chart's axis can "
                    f"be read out of the text alone."),
                "zh-Hans": (
                    f"{era_ref_zh['zh-Hans']} 把出埃及到建殿的整段年数记作一"
                    f"个数字——第{era_stated['mt']['ordinal']}年，即已过"
                    f"{era_stated['mt']['elapsed']}年。而本段逐条所记的各段年"
                    f"数相加共{era_counted['mt']}年，比容纳它们的总年数多出"
                    f"{era_residue['mt']}年；这还没算下列"
                    f"{len(PERIODS_UNNUMBERED)}段未计入此数的时期。按"
                    f"希腊文，这两个数字是{era_counted['lxx']}对"
                    f"{era_stated['lxx']['elapsed']}，多出"
                    f"{era_residue['lxx']}年。此处不作调和：经文从未说这些时期"
                    f"是一段接一段的，士师记 10:7 更记有两处欺压同时进行。故本"
                    f"段只作统计，不入图——单凭经文无法定出这些数字在年表轴上的"
                    f"位置。"),
                "zh-Hant": (
                    f"{era_ref_zh['zh-Hant']} 把出埃及到建殿的整段年數記作一"
                    f"個數字——第{era_stated['mt']['ordinal']}年，即已過"
                    f"{era_stated['mt']['elapsed']}年。而本段逐條所記的各段年"
                    f"數相加共{era_counted['mt']}年，比容納它們的總年數多出"
                    f"{era_residue['mt']}年；這還沒算下列"
                    f"{len(PERIODS_UNNUMBERED)}段未計入此數的時期。按"
                    f"希臘文，這兩個數字是{era_counted['lxx']}對"
                    f"{era_stated['lxx']['elapsed']}，多出"
                    f"{era_residue['lxx']}年。此處不作調和：經文從未說這些時期"
                    f"是一段接一段的，士師記 10:7 更記有兩處欺壓同時進行。故本"
                    f"段只作統計，不入圖——單憑經文無法定出這些數字在年表軸上的"
                    f"位置。"),
            },
            "divergence": {
                "en": (
                    f"The two texts do not state the same figures here. They "
                    f"differ at {len(period_splits)} of {len(period_rows)} "
                    f"periods, and at the total itself: the Hebrew's "
                    f"{era_stated['mt']['ordinal']}th year is the Greek's "
                    f"{era_stated['lxx']['ordinal']}th."),
                "zh-Hans": (
                    f"两种经文在此所记的数字并不相同：{len(period_rows)}段之中"
                    f"有{len(period_splits)}段不同，连总数也不同——希伯来文的第"
                    f"{era_stated['mt']['ordinal']}年，在希腊文是第"
                    f"{era_stated['lxx']['ordinal']}年。"),
                "zh-Hant": (
                    f"兩種經文在此所記的數字並不相同：{len(period_rows)}段之中"
                    f"有{len(period_splits)}段不同，連總數也不同——希伯來文的第"
                    f"{era_stated['mt']['ordinal']}年，在希臘文是第"
                    f"{era_stated['lxx']['ordinal']}年。"),
            },
        },
        "patriarchs": patriarchs,
    }

    OUT.write_text(
        json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    print(f"wrote {OUT.relative_to(ROOT)}: {len(patriarchs)} patriarchs")
    print(f"  sums checked against a third stated number: "
          f"{doc['_meta']['checks']['sumsChecked']}")
    print(f"  flood: MT AM {mt_flood} · LXX AM {lxx_flood} "
          f"(difference {lxx_flood - mt_flood})")
    print(f"    on Genesis 7:11's ordinal instead: MT AM {mt_flood_alt} · "
          f"LXX AM {lxx_flood_alt}")
    print(f"  into Egypt: MT AM {mt_epochs['descent'][0]} · "
          f"LXX AM {lxx_epochs['descent'][0]}")
    print(f"  the exodus: MT AM {mt_era['exodus'][0]} · "
          f"LXX AM {lxx_era['exodus'][0]} (the Greek's start is a reading: "
          f"{lxx_era['startIsRead']})")
    print(f"  Moses dies: MT AM {mt_era['mosesDeath'][0]} · "
          f"LXX AM {lxx_era['mosesDeath'][0]}")
    print(f"  descent to exodus against Exodus 6:18-20: MT {mt_era['ceiling']} "
          f"available vs {mt_era['yearsInEgypt']} needed · LXX "
          f"{lxx_era['ceiling']} vs {lxx_era['yearsInEgypt']}")
    print(f"  Joseph at the descent: {mt_epochs['josephAge'][0]} "
          f"(MT) / {lxx_epochs['josephAge'][0]} (LXX), from "
          f"{', '.join(mt_epochs['josephAge'][1])}")
    print(f"  figures identical between the texts: Genesis 5+11 "
          f"{gen_same}/{gen_both} · Genesis 12-50 {abr_same}/{abr_both}")
    print(f"  notes emitted: {', '.join(sorted({n['id'] for n in notes}))}")
    print(f"  second witness: {agreed}/{checked} agree with family_tree.json")
    print(f"  exodus to the temple: stated MT {era_stated['mt']['ordinal']}th "
          f"year / LXX {era_stated['lxx']['ordinal']}th; periods counted MT "
          f"{era_counted['mt']} / LXX {era_counted['lxx']}; over by MT "
          f"{era_residue['mt']} / LXX {era_residue['lxx']}; "
          f"{len(period_splits)} of {len(period_rows)} periods differ "
          f"between the texts ({', '.join(period_splits)})")
    for tid in ("mt", "lxx"):
        st = era_stated[tid]
        joined = st["yearAt"] != st["foundingAt"]
        print(f"    {tid} {st['ref']}: {st['units']} unit"
              f"{'' if st['units'] == 1 else 's'}, year at {st['yearAt']}, "
              f"founding at {st['foundingAt']}"
              f"{' — READ ACROSS TWO' if joined else ''}")
    # A DISAGREEMENT NOW STOPS THE BUILD, because the chart says so on
    # the reader's own screen. Until this slice nothing rendered the
    # second witness, so a disagreement could be printed here, scroll
    # past, and ship under bars a reader would read as settled. The two
    # artefacts must agree; if they ever do not, one of them is wrong and
    # a person has to decide which, rather than the loop emitting a
    # footnote about it.
    if disagreements:
        for d in disagreements:
            print("  DISAGREES:", d, file=sys.stderr)
        raise SystemExit(
            f"{len(disagreements)} of {checked} figures disagree with "
            f"family_tree.json; one of the two is wrong")


if __name__ == "__main__":
    main()
