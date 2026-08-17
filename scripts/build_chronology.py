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

WHERE THE CHART STOPS, AND WHY
------------------------------
At the descent into Egypt. The next span the text offers is Exodus
12:40's 430 years, and the two traditions do not agree on what those
430 years cover: the Hebrew has Israel dwelling in Egypt, the Greek "in
the land of Egypt and in the land of Canaan". Continuing past the
descent would mean choosing, so the chart stops and says so. The script
verifies that divergence in the shipped text rather than asserting it.

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
    out, cur = [], []
    for i, t in enumerate(toks):
        numeric = t in words or (mult is not None and t == mult)
        if numeric:
            cur.append(t)
            continue
        if t in join and cur:
            nxt = toks[i + 1] if i + 1 < len(toks) else None
            if nxt is not None and (nxt in words or (mult is not None and nxt == mult)):
                continue
        if cur:
            out.append(_value(cur, words, mult))
            cur = []
    if cur:
        out.append(_value(cur, words, mult))
    return out


def _value(toks, words, mult):
    total = 0
    acc = 0
    for t in toks:
        if mult is not None and t == mult:
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


# ------------------------------------------------------------------ corpus


def load(name):
    verses = json.loads((ASSETS / name).read_text(encoding="utf-8"))
    return {(v["book"], v["chapter"], v["verse"]): v["text"] for v in verses}


def cite(chapter, verse, book="Genesis"):
    return f"{book} {chapter}:{verse}"


class Reader:
    """One tradition's Genesis, with the numeral parser it needs."""

    def __init__(self, tradition, asset, runs, famine_remaining_index,
                 famine_stated_index):
        self.tradition = tradition
        self.asset = asset
        self.text = load(asset)
        self.runs = runs
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

    def figure(self, chapter, verse, index=0):
        """The [index]th number stated in Genesis [chapter]:[verse]."""
        key = ("Genesis", str(chapter), str(verse))
        if key not in self.text:
            raise SystemExit(f"{self.asset}: missing {cite(chapter, verse)}")
        found = self.runs(self.text[key])
        if len(found) <= index:
            raise SystemExit(
                f"{self.asset}: {cite(chapter, verse)} states {len(found)} "
                f"numbers, wanted #{index + 1} — {self.text[key][:120]!r}"
            )
        return found[index], cite(chapter, verse)


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
LINE = {p[0]: "seth" for p in GEN5}
LINE.update({p[0]: "shem" for p in GEN11_LXX})
LINE["noah"] = "seth"
LINE["shem"] = "shem"
LINE.update({p[0]: "abraham" for p in ABRAHAMIC})

NAMES = {
    "adam":       ("Adam", "亚当", "亞當"),
    "seth":       ("Seth", "塞特", "塞特"),
    "enos":       ("Enos", "以挪士", "以挪士"),
    "cainan":     ("Cainan", "该南", "該南"),
    "mahalaleel": ("Mahalaleel", "玛勒列", "瑪勒列"),
    "jared":      ("Jared", "雅列", "雅列"),
    "enoch":      ("Enoch", "以诺", "以諾"),
    "methuselah": ("Methuselah", "玛土撒拉", "瑪土撒拉"),
    "lamech":     ("Lamech", "拉麦", "拉麥"),
    "noah":       ("Noah", "挪亚", "挪亞"),
    "shem":       ("Shem", "闪", "閃"),
    "arphaxad":   ("Arphaxad", "亚法撒", "亞法撒"),
    "kainan2":    ("Kainan", "该南", "該南"),
    "salah":      ("Salah", "沙拉", "沙拉"),
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

    # Genesis 7:6 puts the flood in Noah's 600th year. The same fact is in
    # 7:11, but as an ORDINAL — "the six hundredth year", "τω
    # εξακοσιοστω ετει" — and an ordinal is not a numeral this parser can
    # read: it took "six hundredth" for six. 7:6 states it as a cardinal
    # in both traditions, so the figure is taken there.
    flood_age, flood_ref = reader.figure(7, 6)
    flood = birth["noah"] + flood_age

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

    for pid in order:
        rows[pid]["birthAm"] = birth[pid]
        rows[pid]["deathAm"] = birth[pid] + rows[pid]["lifespan"]

    return order, rows, flood, flood_ref, flood_age, epochs


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


def main():
    problems = []
    mt = Reader("mt", "kjv.json", en_runs, 1, 0)
    lxx = Reader("lxx", "lxxwh.json", gk_runs, 0, None)

    (mt_order, mt_rows, mt_flood, flood_ref, mt_flood_age,
     mt_epochs) = build_tradition(mt, GEN11_MT, problems)
    (lxx_order, lxx_rows, lxx_flood, _, _,
     lxx_epochs) = build_tradition(lxx, GEN11_LXX, problems)

    if problems:
        for p in problems:
            print("PARSE DISAGREES WITH THE TEXT:", p, file=sys.stderr)
        raise SystemExit(1)

    # Second witness. family_tree.json carries Anno Mundi years for the
    # same people, put there by a different script from a different
    # reading. Where both speak they must agree; a disagreement is a bug
    # in one of them and is worth more than either number alone.
    tree = json.loads((ASSETS / "family_tree.json").read_text(encoding="utf-8"))
    by_id = {p["id"]: p for p in tree["people"]}
    agreed = checked = 0
    disagreements = []
    for pid in mt_order:
        person = by_id.get(pid)
        if person is None or person.get("birthYear") is None:
            continue
        if person.get("yearSystem") == "am":
            checked += 1
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
            span = person["deathYear"] - person["birthYear"]
            if span == mt_rows[pid]["lifespan"]:
                agreed += 1
            else:
                disagreements.append(
                    f"{pid}: family_tree.json spans {span} years, "
                    f"Genesis as read here says {mt_rows[pid]['lifespan']}")
    for parent, child in (("abraham", "isaac"), ("isaac", "jacob"),
                          ("jacob", "joseph")):
        a, b = by_id.get(parent), by_id.get(child)
        if a is None or b is None:
            continue
        if a.get("yearSystem") != b.get("yearSystem"):
            continue
        if a.get("birthYear") is None or b.get("birthYear") is None:
            continue
        checked += 1
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
    notes = []
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
                "zh-Hans": (f"创世记 11:26 记他拉{terah['begatAt']}岁生亚伯兰、"
                            f"拿鹤、哈兰，本图即以此年为亚伯兰的出生年。照此，"
                            f"亚伯兰{depart}岁离开哈兰（创世记 12:4）时，他拉"
                            f"尚有{gap}年才去世（创世记 11:32 记他拉活了"
                            f"{terah['lifespan']}岁）。使徒行传 7:4 说亚伯兰是"
                            f"在父亲死后才迁往迦南；采此读法的年代学把亚伯兰"
                            f"视为三子中最幼的，出生年定在创世纪元 {later} 年，"
                            f"他与其后各人都要往后推{gap}年。"),
                "zh-Hant": (f"創世記 11:26 記他拉{terah['begatAt']}歲生亞伯蘭、"
                            f"拿鶴、哈蘭，本圖即以此年為亞伯蘭的出生年。照此，"
                            f"亞伯蘭{depart}歲離開哈蘭（創世記 12:4）時，他拉"
                            f"尚有{gap}年才去世（創世記 11:32 記他拉活了"
                            f"{terah['lifespan']}歲）。使徒行傳 7:4 說亞伯蘭是"
                            f"在父親死後才遷往迦南；採此讀法的年代學把亞伯蘭"
                            f"視為三子中最幼的，出生年定在創世紀元 {later} 年，"
                            f"他與其後各人都要往後推{gap}年。"),
            },
        })

    # WHY THE CHART STOPS AT THE DESCENT. Measured in the shipped text,
    # not quoted from a commentary: the Greek of Exodus 12:40 names
    # Canaan inside the 430 years and the Authorised Version does not.
    # The note is emitted only while that is true of the assets, and the
    # two totals are compared as well, so a difference in the NUMBER
    # would be reported rather than folded into a difference of scope.
    ex_mt = mt.verse(12, 40, book="Exodus")
    ex_lxx = lxx.verse(12, 40, book="Exodus")
    years_mt = en_runs(ex_mt)[0]
    years_lxx = gk_runs(ex_lxx)[0]
    canaan_lxx = "χανααν" in ex_lxx.lower()
    canaan_mt = "canaan" in ex_mt.lower()
    sojourn = None
    if years_mt == years_lxx and canaan_lxx and not canaan_mt:
        sojourn = {
            "en": (f"The chart stops here. Exodus 12:40 puts {years_mt} years "
                   f"next in both texts, but not over the same ground: the "
                   f"Hebrew counts them in Egypt, the Greek “in the land "
                   f"of Egypt and in the land of Canaan” — which "
                   f"would begin them at Abraham, not at this line. Carrying "
                   f"the axis on to the exodus would mean choosing between "
                   f"them, so it is not carried."),
            "zh-Hans": (f"本图到此为止。出埃及记 12:40 在两种经文中都记"
                        f"{years_mt}年，所指却不是同一段：希伯来文把这些年数"
                        f"算在埃及，希腊文作「在埃及地和迦南地」——那样起点便"
                        f"在亚伯拉罕，而不在这条线上。若把时间轴延到出埃及，"
                        f"就必须在两者之间取舍，故不延。"),
            "zh-Hant": (f"本圖到此為止。出埃及記 12:40 在兩種經文中都記"
                        f"{years_mt}年，所指卻不是同一段：希伯來文把這些年數"
                        f"算在埃及，希臘文作「在埃及地和迦南地」——那樣起點便"
                        f"在亞伯拉罕，而不在這條線上。若把時間軸延到出埃及，"
                        f"就必須在兩者之間取捨，故不延。"),
        }
        for tid in ("mt", "lxx"):
            notes.append({"id": "sojourn_430", "tradition": tid,
                          "personId": None, "text": sojourn})

    patriarchs = []
    for pid in order:
        entry = {
            "id": pid,
            "name": names(pid),
            "line": LINE.get(pid, "seth"),
            "figures": {},
        }
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
    gen_same, gen_both = _agree(gen_ids)
    abr_same, abr_both = _agree(abr_ids)

    doc = {
        "schemaVersion": 1,
        "_meta": {
            "generator": "scripts/build_chronology.py",
            "unit": "am",
            "unitNote": (
                "Anno Mundi — years counted from the creation, as the ages "
                "in Genesis 5 and 11 accumulate them. The text supplies no "
                "absolute date, so no BC year is stated here. Ussher's "
                "4004 BC is one 17th-century reconstruction among several "
                "and is not adopted."),
            "derivedFrom": {
                "mt": "assets/kjv.json (Authorised Version, public domain), "
                      "which renders the Masoretic figures.",
                "lxx": "assets/lxxwh.json (Septuagint), read in Greek.",
            },
            "checks": {
                "sumsChecked": sum(
                    1 for p in patriarchs for f in p["figures"].values()
                    if f["checked"]),
                "note": (
                    "Genesis 5 states the age at begetting, the years lived "
                    "afterwards, and the total, so the parse of every "
                    "Genesis 5 figure is checked against the third number "
                    "the verse itself supplies. Genesis 11 states only the "
                    "first two, so those lifespans are sums and carry no "
                    "such check; they are marked checked: false. In Genesis "
                    "12-50 only Jacob has a third figure — 47:9's 130 plus "
                    "47:28's 17 years in Egypt against the 147 that same "
                    "verse states — and it checks the descent year as well "
                    "as the parse."),
                "traditionAgreement": (
                    f"Genesis 5 and 11: the two texts state the same "
                    f"begetting age and lifespan for {gen_same} of "
                    f"{gen_both} men. Genesis 12-50: {abr_same} of "
                    f"{abr_both}. The choice of text therefore moves the "
                    f"genealogies and leaves the patriarchs where they are."),
                "secondWitness": (
                    f"{agreed} of {checked} Anno Mundi birth years agree "
                    f"with assets/family_tree.json, which was built "
                    f"separately."),
                "disagreements": disagreements,
            },
            "traditions": (
                "The Masoretic Text and the Septuagint state different ages "
                "in Genesis 5 and 11, and both texts ship with this app, so "
                "both are charted. The Samaritan Pentateuch states a third "
                "set; this repo does not hold that text and it is therefore "
                "absent rather than estimated."),
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
                    "en": f"Genesis 7:6 puts the flood in Noah's {mt_flood_age}th year.",
                    "zh-Hans": f"创世记 7:6 记洪水在挪亚{mt_flood_age}岁那年。",
                    "zh-Hant": f"創世記 7:6 記洪水在挪亞{mt_flood_age}歲那年。",
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
                    "zh-Hans": (f"创世记 12:4 记亚伯兰离开哈兰时"
                                f"{mt_epochs['haran'][2]}岁。"),
                    "zh-Hant": (f"創世記 12:4 記亞伯蘭離開哈蘭時"
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
                                f"（创世记 47:9）；47:28 记他此后在埃及又活了"
                                f"17年，并记出总岁数，故此年另有第三个数字可核。"),
                    "zh-Hant": (f"雅各對法老說自己{mt_epochs['descent'][2]}歲"
                                f"（創世記 47:9）；47:28 記他此後在埃及又活了"
                                f"17年，並記出總歲數，故此年另有第三個數字可核。"),
                },
            },
        ],
        "notes": notes,
        "patriarchs": patriarchs,
    }

    OUT.write_text(
        json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    print(f"wrote {OUT.relative_to(ROOT)}: {len(patriarchs)} patriarchs")
    print(f"  sums checked against a third stated number: "
          f"{doc['_meta']['checks']['sumsChecked']}")
    print(f"  flood: MT AM {mt_flood} · LXX AM {lxx_flood} "
          f"(difference {lxx_flood - mt_flood})")
    print(f"  into Egypt: MT AM {mt_epochs['descent'][0]} · "
          f"LXX AM {lxx_epochs['descent'][0]}")
    print(f"  Joseph at the descent: {mt_epochs['josephAge'][0]} "
          f"(MT) / {lxx_epochs['josephAge'][0]} (LXX), from "
          f"{', '.join(mt_epochs['josephAge'][1])}")
    print(f"  figures identical between the texts: Genesis 5+11 "
          f"{gen_same}/{gen_both} · Genesis 12-50 {abr_same}/{abr_both}")
    print(f"  notes emitted: {', '.join(sorted({n['id'] for n in notes}))}")
    print(f"  second witness: {agreed}/{checked} agree with family_tree.json")
    for d in disagreements:
        print("  DISAGREES:", d)


if __name__ == "__main__":
    main()
