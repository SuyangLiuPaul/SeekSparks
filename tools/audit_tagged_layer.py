#!/usr/bin/env python3
"""Witness every tagged layer against the flat edition it claims to tag.

`assets/tagged/<edition>/<book>.json` and `assets/<edition>.json` are two
records of the same verse, made by different processes. Nothing has ever
asked whether they agree, and they are the two halves of what a reader
sees: the flat file is the text on the page, the tagged file is what the
word under their finger answers.

Two questions, both answerable without an outside source, because each
layer witnesses the other:

  COVERAGE  — is every verse of the flat edition present in the tagged
              layer? A verse that is absent falls back to plain text
              (`TaggedTextService.forVerse` returns null and the caller
              renders the string), so the reader still sees scripture and
              simply cannot tap it. Under-coverage, not a false
              statement — but it is invisible, and nobody had counted it.

  AGREEMENT — do the tagged runs, concatenated, say what the flat verse
              says? This is the one that would catch a layer drifting
              off its own text: a dropped word, or a whole book filed one
              verse out. Check 40 found `cuvs-plus` numbering the whole
              of 1 Chronicles 22 one verse low, and nothing threw.

WHAT THIS INSTRUMENT CANNOT SEE, stated because check 44's lesson is that
a detector reports its own reach and not the defect's size:

  * A shift present in BOTH layers. Check 40's 1 Chronicles 22 defect is
    exactly that — the text and its Strong's tags carried the identical
    shift, so they agreed with each other and this screen would have
    passed them. Catching that needed a third layer (`assets/originals/`).
  * A wrong Strong's number or a wrong parse. This compares WORDS only.
  * Whether the flat text itself is right. Checks 24/26/27/31 own that.

The comparison is reported per edition and never summed, because
`cuvs-yhwh`'s two layers differ partly for editorial reasons: the tagged
layer keeps the 和合本's 〔…〕 marginal notes that the reading text moves
into `<note: …>`, and the two files were normalised on different dates
(阿/啊, 复/覆, 它/他/她, 吗/么).

BUT DO NOT READ THAT AS AN EXPLANATION OF THE WHOLE GAP. It was, in the
first draft of check 45, and it was wrong. Of the 372 verses: 161 are
orthography alone, 116 are where a gloss sits, 16 are the same
characters reordered — and **79 are a real word difference, in BOTH
files**. About twenty are wrong in the flat text the reader reads
(Judges 12:7 has lost the 六 of 六年; Isaiah 23:1 no longer names 推罗)
and about as many in the tagged layer (若若 at Leviticus 5:7). A
plausible editorial story covered 293 of 372 and hid the rest. Covering
most of a set is not explaining it.

A further blind spot in this script, named rather than fixed: `_TAG`
deletes `<note: …>` CONTENT from the flat side, and in `cuvs-yhwh` that
content is real 和合本 text. Note-content loss is invisible here.

Usage:  python3 tools/audit_tagged_layer.py [--edition CODE] [--examples N]
"""

from __future__ import annotations

import argparse
import collections
import difflib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CANON = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua",
    "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
    "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
    "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah",
    "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel",
    "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah",
    "Haggai", "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John",
    "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians",
    "Ephesians", "Philippians", "Colossians", "1 Thessalonians",
    "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon",
    "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John",
    "3 John", "Jude", "Revelation",
]

# The editions that ship a tagged layer, from
# `TaggedTextService.taggedVersions`. `nsn-plus` is deliberately absent:
# the Eagle's View NASB is licensed, never committed and never deployed,
# so an audit that reads it would pass here and fail everywhere else.
EDITIONS = ["bsb", "kjvs", "lxxwh", "cuvs-yhwh", "cuvs-plus"]

# Mirrors `kVerseAbsenceMarkers` in lib/utils/verse_text_absence.dart.
# A verse whose whole text is one of these is a placeholder for words
# that are not there, so having no tagged record is CORRECT, not a gap.
ABSENCE_MARKERS = {
    "见上节", "見上節", "合和译本并入上一节", "合和譯本並入上一節",
    "见下节", "見下節", "OMIT",
}

_NOTE_WRAP = re.compile(r"^<note:\s*(.*?)\s*>$")
_TAG = re.compile(r"<[^>]*>")
_MARGINAL = re.compile(r"〔[^〕]*〕")
_PUNCT = re.compile(r"[，。、；：？！「」『』（）〔〕,.;:?!()'\"“”‘’—\-–\[\]]")


def slug(book: str) -> str:
    return book.lower().replace(" ", "_")


def is_placeholder(text: str) -> bool:
    """True when the stored string stands in for absent words."""
    t = text.strip()
    if not t:
        return True  # an empty record has no words to tag
    m = _NOTE_WRAP.match(t)
    if m:
        t = m.group(1).strip()
    return t in ABSENCE_MARKERS


def normalise(text: str) -> str:
    """Reduce a verse to the stream both layers should agree on."""
    t = _TAG.sub("", text)
    t = _PUNCT.sub("", t)
    return re.sub(r"\s+", "", t)


def han_stream(text: str) -> str:
    """The Han characters only, with marginal notes removed.

    The Chinese comparison needs this second, coarser reduction: the
    tagged layer keeps the 和合本's 〔…〕 notes and the reading text drops
    them, which is an editorial difference between two editions of one
    text and swamps everything else if it is left in.
    """
    t = _MARGINAL.sub("", _TAG.sub("", text))
    return "".join(ch for ch in t if "一" <= ch <= "鿿")


def load_flat(edition: str):
    path = os.path.join(ROOT, "assets", f"{edition}.json")
    by_book = collections.defaultdict(dict)
    for v in json.load(open(path, encoding="utf-8")):
        ref = f"{int(v['chapter'])}:{int(v['verse'])}"
        by_book[int(v["id"][:3])][ref] = v["text"]
    return by_book


def audit(edition: str, examples: int):
    flat = load_flat(edition)
    chinese = edition.startswith("cuvs")

    missing_real, missing_placeholder, extra = [], [], []
    compared = 0
    disagree = []

    for num, book in enumerate(CANON, start=1):
        path = os.path.join(ROOT, "assets", "tagged", edition, f"{slug(book)}.json")
        if not os.path.exists(path):
            missing_real.extend((book, r) for r in flat[num])
            continue
        tagged = json.load(open(path, encoding="utf-8"))
        keys = {}
        for k, runs in tagged.items():
            c, v = k.split(":")
            keys[f"{int(c)}:{int(v)}"] = runs

        for ref, text in flat[num].items():
            if ref in keys:
                compared += 1
                left = normalise(text)
                right = normalise("".join(r["w"] for r in keys[ref]))
                if left != right:
                    if chinese and han_stream(text) == han_stream(
                            "".join(r["w"] for r in keys[ref])):
                        continue  # marginal notes / punctuation only
                    disagree.append((book, ref, text, "".join(
                        r["w"] for r in keys[ref])))
            elif is_placeholder(text):
                missing_placeholder.append((book, ref))
            else:
                missing_real.append((book, ref))

        for ref in keys.keys() - flat[num].keys():
            extra.append((book, ref))

    print(f"== {edition}")
    print(f"   flat verses            {sum(len(b) for b in flat.values()):6d}")
    print(f"   compared               {compared:6d}")
    print(f"   absent — placeholder   {len(missing_placeholder):6d}   (correct: no words to tag)")
    print(f"   absent — REAL TEXT     {len(missing_real):6d}")
    print(f"   tagged with no verse   {len(extra):6d}")
    rate = 100.0 * (compared - len(disagree)) / compared if compared else 0.0
    print(f"   text disagreements     {len(disagree):6d}   ({rate:.4f}% agree)")

    for book, ref in missing_real[:examples]:
        print(f"      absent: {book} {ref}")
    if len(missing_real) > examples:
        print(f"      … {len(missing_real) - examples} more")
    for book, ref, left, right in disagree[:examples]:
        print(f"      differs: {book} {ref}")
        print(f"        flat   {left[:100]}")
        print(f"        tagged {right[:100]}")
    if len(disagree) > examples:
        print(f"      … {len(disagree) - examples} more")
    return missing_real, disagree


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--edition", help="audit one edition only")
    ap.add_argument("--examples", type=int, default=8)
    args = ap.parse_args()

    editions = [args.edition] if args.edition else EDITIONS
    for edition in editions:
        audit(edition, args.examples)
    return 0


if __name__ == "__main__":
    sys.exit(main())
