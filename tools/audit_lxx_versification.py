#!/usr/bin/env python3
"""Check 34 — the Septuagint prints its OWN verse numbers on 4,543
verses. Is that column true?

`assets/lxxwh.json` is keyed by the ENGLISH reference, so a reader who
types Joshua 8:30 finds the verse an English Bible calls Joshua 8:30.
Where the Septuagint numbers that verse differently the record carries
the edition's own chapter-and-verse inline as `<vs:c:v>`, and
`lib/utils/build_verse_content_spans.dart` RENDERS it — a muted "(9:2)"
in front of the Greek. It is not metadata. It is a printed claim, in the
one column a reader cannot check against anything except us.

Every check before this one asked whether the WORDS at a reference are
right (checks 20, 29, 31) or whether a reference EXISTS (checks 9, 29,
30). None has asked whether the small number in brackets is right. It is
a second fact about the same verse, stored once, so nothing else in the
repository contradicts it when it is wrong — which is the shape of every
defect this audit has found.

THE WITNESS, and it must come from outside (check 24's rule):

  * `api.getbible.net/v2/lxx` — "OT LXX Accented", the Göttingen
    tradition, 39 Old-Testament books. The same witness check 29 used,
    so its behaviour here is already characterised.
  * `api.getbible.net/v2/westcotthort` — "NT Westcott Hort UBS4
    variants Parsed", 27 books.

Downloaded whole and cached outside the repository; nothing fetched here
is committed.

THE METHOD. A marker is a claim of the form "the words in this record
are what the Septuagint numbers c:v". That is directly checkable: look
up c:v in the witness and compare, after stripping accents, case and
spacing. Five passes, and they answer different questions.

  A. MARKED, one numeric marker. The marker names exactly one verse and
     the record holds one verse's words. Decisive: if the witness's c:v
     is our text, the claim is true.
  B. UNMARKED. The file's convention is that a marker is written only
     where the two numbers DIFFER, so the ABSENCE of a marker is itself
     a claim — "the Septuagint numbers this verse the way English does".
     That claim has never been tested either, and it is made 18,000
     times. This pass is what would catch a MISSING marker, the failure
     mode pass A is blind to.
  C. RANGE. A marker naming a chapter the witness's book does not have
     cannot be true whatever the words say, and needs no alignment to
     detect.
  D. IDENTITY. A marker naming the record's OWN chapter and verse says
     nothing the key does not already say, and needs no witness at all
     to condemn — except where an earlier marker in the same record
     named a different verse, in which case it legitimately resumes.
  E. LETTERED. Rahlfs gives sub-verses letters — Joshua 9:2a-f, 3
     Kingdoms 16:28a-h, the Greek Additions to Esther. The witness
     numbers verses only, so it cannot confirm a letter. What it CAN do
     is nothing; this pass reads the letters themselves and reports what
     alphabet they are in, which turns out to be the question.
  F. REFERENCE SETS. Which references the witness has and we do not, and
     the reverse. Check 29 did this for the Old Testament; the New
     Testament half has never been done, and item 1 of this document's
     "Next, in order" list asks for it by name.

WHAT THIS CANNOT SEE, stated rather than left implied:

  * THE NEW TESTAMENT MARKER COLUMN, entirely. The `westcotthort`
    witness is keyed by the ENGLISH reference, exactly as our file is —
    12 of the 19 NT marked records are verbatim the witness AT THEIR OWN
    NUMBER. So looking up the marked number fetches a different verse and
    proves nothing in either direction. Pass A reports the two halves
    separately for that reason and draws no conclusion from the NT one.
  * NT WORDING, for a second and independent reason: the witness inlines
    UBS4 variants as duplicated words in the running text — Matthew
    12:46 reads "ιστηκεισαν ειστηκεισαν", Acts 13:39 "και και", 2
    Corinthians 13:14 "χριστου χριστου".
  * Rahlfs' sub-verse LETTERS. See pass E.
  * Passages where the Septuagint's arrangement differs so far from the
    Hebrew that one record holds several Greek verses, or none — the
    Esther Additions, the 3 Kingdoms miscellanies, the Daniel OG and
    Judges A/B recensions. Check 29 declared these; they surface here as
    "contained" and as the 132 marked verses the witness does not have,
    and are counted separately from both agreement and defect.

Usage:  python3 tools/audit_lxx_versification.py [--witness DIR] [--json]

The witness cache defaults to
~/Library/Application Support/seeksparks-loop/witness and is downloaded
if absent.
"""

import argparse
import json
import os
import re
import sys
import unicodedata
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FLAT = os.path.join(ROOT, "assets", "lxxwh.json")
DEFAULT_WITNESS = os.path.expanduser(
    "~/Library/Application Support/seeksparks-loop/witness"
)

MARKER = re.compile(r"<vs:([^>]+)>")
NUMERIC = re.compile(r"^(\d+):(\d+)$")
LETTERED = re.compile(r"^(\d+):(\d+)(\D+)$")

# The 66 books in canonical order; the witness's OT files carry these
# English names, its NT files carry Greek ones and are matched by index.
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
    "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John",
    "3 John", "Jude", "Revelation",
]
OT = 39

GREEK_LETTERS = set("αβγδεζηθικλμνξοπρστυφχψω")


def norm(text: str) -> str:
    """Accent-stripped, lowercased, sigma-folded Greek letters only.

    The two texts are the same tradition set by different houses, so
    comparing them raw compares typography. Breath marks, punctuation
    and final sigma are house style and go. So does WORD DIVISION: the
    two disagree on whether to write γαβηρωθχαμααμ or γαβηρωθ χαμααμ in
    six places, which is a spacing decision about a transliterated
    Hebrew name and not a claim about anything.
    """
    text = MARKER.sub(" ", text)
    text = unicodedata.normalize("NFD", text).lower()
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.replace("ς", "σ")
    return "".join(c for c in text if c in GREEK_LETTERS)


def compare(ours: str, theirs: str) -> str:
    a, b = norm(ours), norm(theirs)
    if a == b:
        return "exact"
    if a in b or b in a:
        return "contained"
    return "different"


def fetch_witness(cache: str) -> None:
    os.makedirs(cache, exist_ok=True)
    for i, book in enumerate(BOOKS, start=1):
        version = "lxx" if i <= OT else "westcotthort"
        path = os.path.join(cache, f"{'lxx' if i <= OT else 'wh'}_{i}.json")
        if os.path.exists(path):
            continue
        print(f"  fetching {book} ...", file=sys.stderr)
        url = f"https://api.getbible.net/v2/{version}/{i}.json"
        with urllib.request.urlopen(url, timeout=60) as resp:
            data = resp.read()
        with open(path, "wb") as f:
            f.write(data)


def load_witness(cache: str):
    """(book, chapter, verse) -> raw text, for all 66 books."""
    out = {}
    for i, book in enumerate(BOOKS, start=1):
        path = os.path.join(cache, f"{'lxx' if i <= OT else 'wh'}_{i}.json")
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for chapter in data["chapters"]:
            c = int(chapter["chapter"])
            for verse in chapter["verses"]:
                out[(book, c, int(verse["verse"]))] = verse["text"]
    return out


def load_ours():
    with open(FLAT, encoding="utf-8") as f:
        records = json.load(f)
    return {
        (r["book"], int(r["chapter"]), int(r["verse"])): r["text"]
        for r in records
    }


def is_ot(key) -> bool:
    return BOOKS.index(key[0]) < OT


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--witness", default=DEFAULT_WITNESS)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    fetch_witness(args.witness)
    witness = load_witness(args.witness)
    chapters = {}
    for (book, c, _v) in witness:
        chapters[book] = max(chapters.get(book, 0), c)
    ours = load_ours()
    marked = {k: MARKER.findall(t) for k, t in ours.items()
              if MARKER.search(t)}

    report = {}
    print(f"{len(ours):,} records in assets/lxxwh.json; "
          f"{len(witness):,} in the witness\n")

    all_markers = [m for ms in marked.values() for m in ms]
    lettered = [m for m in all_markers if LETTERED.match(m)]
    numeric = [m for m in all_markers if NUMERIC.match(m)]
    print(f"{len(marked):,} records carry {len(all_markers):,} markers "
          f"({len(numeric):,} numeric, {len(lettered):,} lettered, "
          f"{len(all_markers) - len(numeric) - len(lettered)} other)\n")
    report["inventory"] = {
        "records": len(marked), "markers": len(all_markers),
        "numeric": len(numeric), "lettered": len(lettered),
    }

    # ---------------------------------------------------------------- A
    print("A. MARKED — is the number the marker names the number the "
          "witness gives these words?")
    report["A"] = {}
    for half, keep in (("OT", is_ot), ("NT", lambda k: not is_ot(k))):
        tally = {"exact": 0, "contained": 0, "different": 0}
        unwitnessed = 0
        bad = []
        for key, ms in sorted(marked.items()):
            if not keep(key) or len(ms) != 1 or not NUMERIC.match(ms[0]):
                continue
            c, v = (int(x) for x in ms[0].split(":"))
            wit = witness.get((key[0], c, v))
            if wit is None:
                unwitnessed += 1
                continue
            verdict = compare(ours[key], wit)
            tally[verdict] += 1
            if verdict == "different":
                bad.append((key, ms[0]))
        print(f"   {half}: {tally['exact']:,} EXACT, "
              f"{tally['contained']:,} contained, "
              f"{tally['different']:,} different, "
              f"{unwitnessed:,} the witness has no such verse")
        for key, m in bad:
            print(f"      {key[0]} {key[1]}:{key[2]} claims {m}")
        report["A"][half] = dict(tally, unwitnessed=unwitnessed)
    print("   The NT half is NOT evidence: the witness is keyed by the "
          "English reference,\n   so the marked number cannot be looked "
          "up in it. See the header.")

    # ---------------------------------------------------------------- B
    tally = {"exact": 0, "contained": 0, "different": 0}
    bad = []
    for key, text in sorted(ours.items()):
        if not is_ot(key) or MARKER.search(text) or key not in witness:
            continue
        verdict = compare(text, witness[key])
        tally[verdict] += 1
        if verdict == "different":
            bad.append(key)
    print(f"\nB. UNMARKED OT — the silent claim that English and Greek "
          f"agree here")
    print(f"   {tally['exact']:,} EXACT, {tally['contained']:,} contained, "
          f"{tally['different']:,} different")
    for key in bad:
        print(f"      {key[0]} {key[1]}:{key[2]}")
    report["B"] = tally

    # ---------------------------------------------------------------- C
    out_of_range = {}
    for key, ms in sorted(marked.items()):
        for m in ms:
            hit = NUMERIC.match(m) or LETTERED.match(m)
            if hit and int(hit.group(1)) > chapters.get(key[0], 0):
                out_of_range.setdefault(key[0], []).append((key, m))
    total = sum(len(v) for v in out_of_range.values())
    print(f"\nC. RANGE — markers naming a chapter the book does not have: "
          f"{total}")
    for book, hits in sorted(out_of_range.items()):
        keys = sorted({k for k, _ in hits})
        agree = sum(1 for k in keys if k in witness
                    and compare(ours[k], witness[k]) == "exact")
        print(f"   {book} {keys[0][1]}:{keys[0][2]}–{keys[-1][1]}:"
              f"{keys[-1][2]}: {len(hits)} markers in {len(keys)} records, "
              f"claiming chapters "
              f"{min(int((NUMERIC.match(m) or LETTERED.match(m)).group(1)) for _, m in hits)}"
              f"–{max(int((NUMERIC.match(m) or LETTERED.match(m)).group(1)) for _, m in hits)}"
              f" of a book with {chapters.get(book, 0)}")
        print(f"     {agree} of those {len(keys)} records are verbatim the "
              f"witness AT THEIR OWN ENGLISH NUMBER")
    report["C"] = {b: len(v) for b, v in out_of_range.items()}

    # ---------------------------------------------------------------- D
    vacuous, resumed = [], []
    for key, ms in sorted(marked.items()):
        for i, m in enumerate(ms):
            hit = NUMERIC.match(m)
            if not hit:
                continue
            if (int(hit.group(1)), int(hit.group(2))) != (key[1], key[2]):
                continue
            (resumed if i else vacuous).append((key, ms))
    print(f"\nD. IDENTITY — markers naming the record's own number: "
          f"{len(vacuous) + len(resumed)}")
    print(f"   {len(resumed)} resume after an earlier different marker "
          f"(legitimate):")
    for key, ms in resumed:
        print(f"      {key[0]} {key[1]}:{key[2]}  {' '.join(ms)}")
    print(f"   {len(vacuous)} say nothing the key does not already say:")
    for key, ms in vacuous:
        witnessed = key in witness and compare(ours[key], witness[key])
        print(f"      {key[0]} {key[1]}:{key[2]}  {' '.join(ms)}"
              f"   (record vs witness at its own number: {witnessed})")
    report["D"] = {"resumed": len(resumed), "vacuous": len(vacuous)}

    # ---------------------------------------------------------------- E
    letters = {}
    for m in lettered:
        suffix = LETTERED.match(m).group(3)
        letters[suffix] = letters.get(suffix, 0) + 1
    print(f"\nE. LETTERED — {len(lettered)} sub-verse markers, "
          f"{len(letters)} distinct suffixes, by frequency:")
    print("   " + "  ".join(f"{k}={n}" for k, n in
                            sorted(letters.items(), key=lambda kv: -kv[1])))
    print("   Greek alphabetical order is α β γ δ ε ζ η θ. Any run below "
          "that is not\n   in that order is not Greek letters.")
    for key, ms in sorted(marked.items()):
        suffixes = [LETTERED.match(m).group(3) for m in ms
                    if LETTERED.match(m)]
        if len(suffixes) >= 4:
            print(f"      {key[0]} {key[1]}:{key[2]}: {' '.join(suffixes)}")
    report["E"] = {"markers": len(lettered), "suffixes": letters}

    # ---------------------------------------------------------------- F
    missing = sorted(k for k in witness if k not in ours)
    nt_missing = [k for k in missing if not is_ot(k)]
    ot_missing = [k for k in missing if is_ot(k)]
    wholly = []
    for key, raw in witness.items():
        if is_ot(key):
            continue
        t = raw.strip()
        core = t.strip("[] ").strip()
        if t.startswith("[") and t.endswith("]") \
                and "[" not in core and "]" not in core:
            wholly.append(key)
    kept = sorted(k for k in wholly if k in ours)
    print(f"\nF. REFERENCE SETS — the witness has and we do not: "
          f"{len(ot_missing):,} OT (check 29), {len(nt_missing)} NT")
    for k in nt_missing:
        t = witness[k].strip()
        print(f"      {k[0]} {k[1]}:{k[2]}"
              + ("  — WHOLLY BRACKETED by the witness"
                 if t.startswith("[") and t.endswith("]") else ""))
    print(f"   the witness wholly brackets {len(wholly)} NT verses and we "
          f"carry {len(kept)} of them "
          f"({', '.join(f'{k[0]} {k[1]}:{k[2]}' for k in kept)}),")
    print(f"   so dropping a bracketed verse is not this edition's policy.")
    report["F"] = {
        "ot_missing": len(ot_missing),
        "nt_missing": [f"{k[0]} {k[1]}:{k[2]}" for k in nt_missing],
        "nt_wholly_bracketed": len(wholly),
        "nt_bracketed_kept": [f"{k[0]} {k[1]}:{k[2]}" for k in kept],
    }

    findings = (sum(len(v) for v in out_of_range.values())
                + len(vacuous) + len(nt_missing))
    print(f"\n{findings} open findings")

    if args.json:
        path = os.path.join(ROOT, "build", "lxx_versification.json")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
