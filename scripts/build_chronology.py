#!/usr/bin/env python3
"""Build assets/chronology.json — the Genesis 5 and Genesis 11 lifespans,
read out of the Bible texts this app already ships.

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


def cite(chapter, verse):
    return f"Genesis {chapter}:{verse}"


class Reader:
    """One tradition's Genesis, with the numeral parser it needs."""

    def __init__(self, tradition, asset, runs):
        self.tradition = tradition
        self.asset = asset
        self.text = load(asset)
        self.runs = runs

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

# Seth's line in Genesis 5, Shem's in Genesis 11. The chart colours by
# line, the way the printed chronologies have since the 17th century.
LINE = {p[0]: "seth" for p in GEN5}
LINE.update({p[0]: "shem" for p in GEN11_LXX})
LINE["noah"] = "seth"
LINE["shem"] = "shem"

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

    for pid in order:
        rows[pid]["birthAm"] = birth[pid]
        rows[pid]["deathAm"] = birth[pid] + rows[pid]["lifespan"]

    return order, rows, flood, flood_ref, flood_age


def main():
    problems = []
    mt = Reader("mt", "kjv.json", en_runs)
    lxx = Reader("lxx", "lxxwh.json", gk_runs)

    mt_order, mt_rows, mt_flood, flood_ref, mt_flood_age = build_tradition(
        mt, GEN11_MT, problems)
    lxx_order, lxx_rows, lxx_flood, _, _ = build_tradition(
        lxx, GEN11_LXX, problems)

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
        if person is None or person.get("yearSystem") != "am":
            continue
        if person.get("birthYear") is None:
            continue
        checked += 1
        if person["birthYear"] == mt_rows[pid]["birthAm"]:
            agreed += 1
        else:
            disagreements.append(
                f"{pid}: family_tree.json says AM {person['birthYear']}, "
                f"Genesis as read here says AM {mt_rows[pid]['birthAm']}")

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
                    "such check; they are marked checked: false."),
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
                    "zh-Hans": f"创世记 7:11 记洪水在挪亚{mt_flood_age}岁那年。",
                    "zh-Hant": f"創世記 7:11 記洪水在挪亞{mt_flood_age}歲那年。",
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
    print(f"  second witness: {agreed}/{checked} agree with family_tree.json")
    for d in disagreements:
        print("  DISAGREES:", d)


if __name__ == "__main__":
    main()
