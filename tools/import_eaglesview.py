#!/usr/bin/env python3
"""Eagle's View (.bbl) → SeekSparks assets.

Eagle's View is the electronic statistical concordance written by Pastor
Ho (eaglesviewsoftware.com). Its Bible modules are MS Access databases
whose `Scripture` column is RTF-ish: literal text interleaved with
`{\\cf11\\super NNNN}` Strong's runs, every non-ASCII character written as
a raw CODEPAGE byte (`\\'e5`) whose meaning depends on the font in scope.

Only public-domain texts are imported. Eagle's View also ships NASB and
"NAS with Strong's", both of which state inside the database itself that
redistribution is not permitted; they are deliberately NOT handled here,
and neither are the RSV / NET modules distributed separately.

Usage (needs `brew install mdbtools`):

    python3 tools/import_eaglesview.py <module.mdb> <version> <outdir> \\
        [--greek] [--cjk]

Modules imported for v1.6.18, by their Details.Description:
    "King James Version (1769) w/ Strong's Numbers and Tense, Voice and
     Mood"                                   -> kjvs
    "LXX & Westcott Hort+"                   -> lxxwh   --greek
    "Chinese Union Version Bible with
     Strong's Number (Simplified Chinese)"   -> cuvs-plus --cjk
"""
import csv
import re
import subprocess
import sys

FONT_CODEC = {0: "cp1252", 1: "cp1253", 2: "cp1255", 7: "gbk"}

TOKEN = re.compile(
    r"""
      \\'(?P<byte>[0-9a-fA-F]{2})      # \'e5   raw codepage byte
    | \\u(?P<uni>-?\d+)\??             # \u1468?  unicode escape + fallback
    | \\f(?P<font>\d+)                 # \f7    font switch
    | \\(?P<ctrl>[a-zA-Z]+)(?P<arg>-?\d+)?\s?   # \super \cf11 \par ...
    | (?P<open>\{)
    | (?P<close>\})
    | (?P<text>[^\\{}]+)
    """,
    re.VERBOSE,
)

# A Strong's run: \cf11 \super followed by one or more numbers, e.g.
#   {\cf11\super 7225}          -> [7225]
#   {\cf11\Super  9002 7225}    -> [9002, 7225]
#   {\f0\cf11\super 1722 \cf2 PREP}  -> [1722] with morph "PREP"
NUMS = re.compile(r"\d+")


def decode_scripture(raw, default_font=0):
    """Return (plain_text, tags) where tags = [(offset, [strongs], morph)]."""
    out = []          # decoded text pieces
    pending = bytearray()
    font = default_font
    font_stack = []
    depth = 0
    tags = []
    # State for the Strong's group currently being read.
    # Inside `{\cf11\super 1722 \cf2 PREP}` the numbers and the morph code
    # are separated by a colour switch, NOT by punctuation — so a regex over
    # the whole blob would pull the `3` out of `V-AAI-3S` and call it a
    # Strong's number. Track the \cf argument and switch modes on it.
    grp_depth = None
    grp_nums = []
    grp_morph = []
    grp_mode = "nums"

    def flush():
        if pending:
            codec = FONT_CODEC.get(font, "cp1252")
            out.append(pending.decode(codec, errors="replace"))
            pending.clear()

    def text_len():
        return sum(len(p) for p in out)

    for m in TOKEN.finditer(raw):
        # NOT m.lastgroup: the control-word alternative has two groups, so
        # `\cf2` reports "arg" and `\super` reports "ctrl". Dispatching on
        # lastgroup silently dropped every control word that carried a
        # number — which is every colour switch, i.e. every morph code.
        g = m.groupdict()
        kind = next(k for k in ("byte", "uni", "font", "ctrl", "open",
                                "close", "text") if g[k] is not None)
        if kind == "byte":
            if grp_depth is not None:
                continue
            pending.append(int(m.group("byte"), 16))
        elif kind == "uni":
            if grp_depth is not None:
                continue
            flush()
            cp = int(m.group("uni"))
            out.append(chr(cp if cp >= 0 else cp + 65536))
        elif kind == "font":
            flush()
            font = int(m.group("font"))
        elif kind == "ctrl":
            ctrl = m.group("ctrl").lower()
            arg = m.group("arg")
            if ctrl == "super":
                # everything until the matching } is a Strong's/morph run
                if grp_depth is None:
                    flush()
                    grp_depth = depth
                    grp_nums, grp_morph, grp_mode = [], [], "nums"
            elif ctrl == "cf" and grp_depth is not None:
                # \cf11 opens the numbers, any other colour ends them
                grp_mode = "nums" if arg == "11" else "morph"
            elif ctrl == "par":
                flush()
                out.append("\n")
        elif kind == "open":
            depth += 1
            font_stack.append(font)
        elif kind == "close":
            if grp_depth is not None and depth == grp_depth:
                nums = [int(n) for n in NUMS.findall(" ".join(grp_nums))]
                morph = " ".join(grp_morph).strip()
                if nums or morph:
                    tags.append((text_len(), nums, morph))
                grp_depth = None
            # Flush BEFORE restoring the font: bytes emitted just inside a
            # group belong to that group's codepage. Popping first decoded
            # the CUV's trailing 。 (GBK a1 a3) as cp1252 "¡£".
            flush()
            depth -= 1
            if font_stack:
                font = font_stack.pop()
        elif kind == "text":
            if grp_depth is not None:
                (grp_nums if grp_mode == "nums" else grp_morph).append(
                    m.group("text")
                )
            else:
                flush()
                out.append(m.group("text"))
    flush()
    return "".join(out), tags


def rows(mdb, table="Bible"):
    p = subprocess.run(
        ["mdb-export", "-D", "%Y-%m-%d", mdb, table],
        capture_output=True, text=True, errors="replace",
    )
    if p.returncode != 0:
        raise SystemExit(f"mdb-export failed: {p.stderr[:300]}")
    return csv.DictReader(p.stdout.splitlines())


import json
import os
import re
import sys


# EV numbers books 1-66 in canonical order.
BOOKS_ZH = [
    "创世纪", "出埃及记", "利未记", "民数记", "申命记", "约书亚记", "士师记",
    "路得记", "撒母耳记上", "撒母耳记下", "列王纪上", "列王纪下", "历代志上",
    "历代志下", "以斯拉记", "尼希米记", "以斯帖记", "约伯记", "诗篇", "箴言",
    "传道书", "雅歌", "以赛亚书", "耶利米书", "耶利米哀歌", "以西结书",
    "但以理书", "何西阿书", "约珥书", "阿摩司书", "俄巴底亚书", "约拿书",
    "弥迦书", "那鸿书", "哈巴谷书", "西番雅书", "哈该书", "撒迦利亚书",
    "玛拉基书", "马太福音", "马可福音", "路加福音", "约翰福音", "使徒行传",
    "罗马书", "哥林多前书", "哥林多后书", "加拉太书", "以弗所书", "腓立比书",
    "歌罗西书", "帖撒罗尼迦前书", "帖撒罗尼迦后书", "提摩太前书", "提摩太后书",
    "提多书", "腓利门书", "希伯来书", "雅各书", "彼得前书", "彼得后书",
    "约翰一书", "约翰二书", "约翰三书", "犹大书", "启示录",
]

BOOKS = [
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
    "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
    "Jude", "Revelation",
]

WS = re.compile(r"\s+")


# Strong's itself stops at H8674 and G5624. The tense-voice-mood codes are
# numbered ABOVE each range so they can share one field without colliding,
# which is why a range test is safe here and a "high number means grammar"
# guess is not: H8064 (heaven) and G5207 (son) are ordinary words well
# inside their ranges, and an 8000-means-TVM rule silently mistags them.
MAX_STRONGS = {"H": 8674, "G": 5624}


def classify(nums, prefix):
    """-> (strongs, implied, grammar) as SeekSparks string lists."""
    top = MAX_STRONGS[prefix]
    grammar, implied, plain = [], [], []
    for n in nums:
        if n > top:
            grammar.append(str(n))       # tense / voice / mood
        else:
            plain.append(f"{prefix}{n}")
    strongs = plain[0] if plain else ""
    return strongs, plain[1:] + implied, grammar


def runs_for(text, tags, prefix):
    """Split `text` at tag offsets into TaggedRun-shaped dicts."""
    out = []
    cursor = 0
    for offset, nums, morph in tags:
        seg = text[cursor:offset]
        cursor = offset
        strongs, implied, grammar = classify(nums, prefix)
        if morph:
            grammar = grammar + [morph]
        if seg.strip() == "" and out:
            # Untranslated particle riding on whitespace: fold it into the
            # word before it instead of emitting a run with no text. Drop
            # the whitespace rather than appending it — the next run already
            # carries its own leading space, so keeping this one leaves a
            # double space at every TVM code ("loved  the world").
            if strongs:
                out[-1]["i"].append(strongs)
            out[-1]["i"].extend(implied)
            out[-1]["g"].extend(grammar)
            continue
        out.append({"w": seg, "s": strongs, "i": implied, "g": grammar})
    tail = text[cursor:]
    if tail:
        if out:
            out[-1]["w"] += tail
        else:
            out.append({"w": tail, "s": "", "i": [], "g": []})
    # Drop the empties the leading-tag case can produce.
    return [r for r in out if r["w"]]


def convert(mdb, version, outdir, greek=None, cjk=False):
    """`greek=None` means decide per book — the right call for a whole-Bible
    module, where books 1-39 carry Hebrew numbers and 40-66 Greek ones."""
    plain = []
    tagged = {}
    n = 0
    for r in rows(mdb):
        bi = int(r["Book ID"])
        if not 1 <= bi <= 66:
            continue
        book = BOOKS[bi - 1]
        ch, vs = r["Chapter"], r["Verse"]
        text, tags = decode_scripture(r["Scripture"] or "")
        # Normalise per RUN, never on the joined string: EV pads a space
        # around every tag, and collapsing those on the joined text would
        # shift every offset the runs were cut at. Build the runs first,
        # clean each one, then join — the verse text is whatever the runs
        # say it is, so the two can never disagree.
        prefix = "G" if (greek is True or (greek is None and bi >= 40)) else "H"
        raw_runs = runs_for(text, tags, prefix)
        norm = []
        for run in raw_runs:
            w = WS.sub("", run["w"]) if cjk else WS.sub(" ", run["w"])
            if not w:
                if norm and (run["s"] or run["i"] or run["g"]):
                    if run["s"]:
                        norm[-1]["i"].append(run["s"])
                    norm[-1]["i"].extend(run["i"])
                    norm[-1]["g"].extend(run["g"])
                continue
            # Collapse across the seam too: EV writes a space both before
            # and after a tag, so two runs that are each internally clean
            # still meet as "εν  αρχη".
            if norm and norm[-1]["w"].endswith(" ") and w.startswith(" "):
                w = w[1:]
                if not w:
                    continue
            norm.append({**run, "w": w})
        if norm and not cjk:
            norm[0]["w"] = norm[0]["w"].lstrip()
            norm[-1]["w"] = norm[-1]["w"].rstrip()
        norm = [r2 for r2 in norm if r2["w"]]

        text = "".join(r2["w"] for r2 in norm)
        if not text:
            continue
        # The app stores a Bible as a FLAT list of verse records keyed by a
        # BBBCCCVVV id, not a nested book/chapter/verse map — see
        # tools/import_bsb.py. Chinese editions carry Chinese book names;
        # English and Greek ones carry the English names, because that is
        # what every navigation path already resolves against.
        plain.append({
            "book": (BOOKS_ZH if cjk else BOOKS)[bi - 1],
            "chapter": ch,
            "verse": vs,
            "text": text,
            "id": f"{bi:03d}{int(ch):03d}{int(vs):03d}",
        })
        if any(r2["s"] for r2 in norm):
            tagged.setdefault(BOOKS[bi - 1], {})[f"{ch}:{vs}"] = norm
        n += 1

    os.makedirs(outdir, exist_ok=True)
    with open(f"{outdir}/{version}.json", "w", encoding="utf-8") as f:
        json.dump(plain, f, ensure_ascii=False, separators=(",", ":"))
    tdir = f"{outdir}/tagged/{version}"
    os.makedirs(tdir, exist_ok=True)
    for book, verses in tagged.items():
        slug = book.lower().replace(" ", "_")
        with open(f"{tdir}/{slug}.json", "w", encoding="utf-8") as f:
            json.dump(verses, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{version}: {n} verses, {len(tagged)} tagged books -> {outdir}")


if __name__ == "__main__":
    mdb, version, outdir = sys.argv[1:4]
    convert(mdb, version, outdir,
            greek=True if "--greek" in sys.argv else None,
            cjk="--cjk" in sys.argv)
