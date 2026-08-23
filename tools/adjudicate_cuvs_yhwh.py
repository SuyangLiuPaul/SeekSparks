#!/usr/bin/env python3
"""Adjudicate the `cuvs-yhwh` word-level disagreements with a third witness.

Check 45d compared `assets/cuvs-yhwh.json` (the reading text) against
`assets/tagged/cuvs-yhwh/*.json` (what a tapped word answers) and found
**79 verses where a word is added, dropped or substituted**. It could not
say which side was wrong, and said so:

    "Neither layer is the authority; each caught the other."

This script was written to break that deadlock with a third file and
**the attempt failed. The failure is the finding, and it is why the
script still exists.**

The idea was that `assets/cuvs-plus.json` — a second 和合本 edition
already in this repository, 和合本+Strong's, imported from a different
source — could adjudicate. It has the right shape for a witness: folded
for the divine-name restoration and reduced to Han characters it matches
the reading text verse-for-verse in **29,790 of 31,102 (95.78%)**.

That number is the disproof, not the credential. Character-for-character
the two run to **99.70% identity (917,572 of 920,316)**, which no pair of
independent translations reaches. `docs/DATA-INTEGRITY.md` already said
so in prose — "the same base text as cuvs-yhwh but imported separately"
— and the measurement is what that sentence means quantitatively.

**It is descent, not independence.** At Judges 12:7 the reading text
prints 「作以色列的士师年」 and `cuvs-plus` prints the same — while the
tagged layer has 「士师六年」, and the 和合本 says Jephthah judged Israel
**six** years. At Judges 9:57 both flat editions read 「咒诅归到们身上」
and only the tagged layer has the 他. In both places the two flats carry
one defect and the odd file out is the correct one.

So a 2-of-3 agreement here is worth nothing, and a first version of this
script — which trusted it — proposed **deleting the 六 from Judges
12:7**, making the app worse in exactly the way the accuracy rule warns
about. This is check 26's lesson a second time: there an external
witness carried 44 of the same 丶 we did, and a majority would have
entrenched three defects.

WHAT IT THEREFORE DOES. It repairs only the two classes that need no
vote at all, because neither is a *reading* any edition holds:

  A. the literal `#` — not a Chinese character, standing in all 17
     places where the reading text prints the supplied 「[基督]」;
  B. a character DOUBLED against itself in the tagged layer (若若, 箭箭,
     未未曾) where both flat editions read it once — a duplication
     artefact, not a variant.

Everything else is printed with its verdict and left alone. `cuvs-plus`
is still consulted, but only to say which class a difference falls in
and never to decide a reading. An undecided verse is a result; a guessed
one is a defect that will be believed.

WHAT THE FAILED ADJUDICATION FOUND ANYWAY, which is the reason to keep
the report: **21 word-level defects in the reading text** — scripture as
the reader sees it, not the tagged layer.

  * 12 where the reading text stands alone against both other files
    (Isaiah 23:1 has lost the 推 of 推罗 and no longer names Tyre;
    Lamentations 3:1 has gained a 神 the other two lack).
  * 9 where BOTH flat editions have lost a word the tagged layer keeps.
    These are the ones a majority vote destroys, and they are only
    findable once you stop trusting the majority.

Their direction is NOT decided by this script. It groups them; each was
then read against the Strong's number the characters carry, and the
verdicts are written down in `ADJUDICATED` so they can be re-checked.
Nine of those ten went against the reading text and **one went the other
way** — Job 31:36's 「愿那敌我敌」 is a single H7379 run with a doubled
character, so there the reading text is right. A rule that had been
applied to all ten would have damaged that verse.

BLIND SPOTS, named rather than discovered later:

  * Note CONTENT is removed from all three sides before comparing
    (`<note: …>` in the reading text, `〔…〕` and `（…）` in the other
    two). A real word difference living inside a note is invisible here.
    Check 45's own list of 47 such verses is untouched by this.
  * 13 verses reach the comparison with a 〔 or 〕 that does not pair
    WITHIN THE VERSE, so note content leaks in as though it were
    scripture. They are bucketed apart and never repaired. Note that
    this is a comparability guard and not a defect count: 和合本 opens a
    note in one verse and closes it in a later one, and over the whole
    edition the brackets run 12 〔 to 13 〕 — only 士师记 8:24, 耶利米书
    10:11 and 路加福音 8:45 are truly unmatched.
  * Where all three files inherit the same wrong character nothing here
    objects — and Judges 12:7 shows two of the three routinely do.

Usage:
    python3 tools/adjudicate_cuvs_yhwh.py             # report only
    python3 tools/adjudicate_cuvs_yhwh.py --apply     # write the repairs
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

ABSENCE_MARKERS = {
    "见上节", "見上節", "合和译本并入上一节", "合和譯本並入上一節",
    "见下节", "見下節", "OMIT",
}

_NOTE_TAG = re.compile(r"<[^>]*>")
_MARGINAL = re.compile(r"〔[^〕]*〕")
_PAREN = re.compile(r"（[^）]*）")

# The pairs check 45d measured as two normalisation dates of one word,
# plus the divine-name restoration that distinguishes the two editions.
# Folding these is what lets a real word difference be seen at all.
_ORTHO = str.maketrans({
    "阿": "啊", "它": "他", "她": "他", "覆": "复", "么": "吗",
    "蹧": "糟", "作": "做", "罢": "吧", "藉": "借", "馀": "余",
})


def _kept(text: str):
    """Indices of the characters that survive into the Han stream.

    Returned as a list of positions into `text`, so a difference found in
    the stream can be carried back to the exact character that produced
    it. Every reduction here DELETES; none substitutes, so the mapping
    stays exact.
    """
    masked = [False] * len(text)
    for pat in (_NOTE_TAG, _MARGINAL, _PAREN):
        for m in pat.finditer(text):
            for i in range(m.start(), m.end()):
                masked[i] = True
    return [i for i, c in enumerate(text)
            if not masked[i] and "一" <= c <= "鿿"]


def han(text: str) -> str:
    """The Han characters of the verse, with every note wrapper's
    CONTENT removed, in whichever of the three notations it is written."""
    return "".join(text[i] for i in _kept(text))


def fold(text: str) -> str:
    """Offset-preserving fold, for comparing the two layers of ONE
    edition. Every mapping is character-for-character, so a position in
    the result is a position in `han(text)`."""
    return han(text).translate(_ORTHO)


def fold_witness(text: str) -> str:
    """The fold used against `cuvs-plus`, which additionally undoes the
    divine-name restoration. 雅伟 → 耶和华 is 2 characters for 3, so this
    one does NOT preserve offsets and is only ever compared, never
    located into."""
    return han(text).replace("雅伟", "耶和华").translate(_ORTHO)


def unbalanced_note(text: str) -> bool:
    """A verse whose 〔 does not meet its 〕. `cuvs-yhwh` has 25 of them —
    some are one note running across two verses, some simply stop. Either
    way the wrapper cannot be removed cleanly, so note content leaks into
    the comparison looking like scripture, and no verdict about the words
    is trustworthy."""
    return text.count("〔") != text.count("〕") or text.count("（") != text.count("）")


def is_placeholder(text: str) -> bool:
    t = _NOTE_TAG.sub("", text).strip().strip("〔〕（）")
    return not t or t in ABSENCE_MARKERS


def load_flat(code: str):
    path = os.path.join(ROOT, "assets", f"{code}.json")
    out = {}
    for v in json.load(open(path, encoding="utf-8")):
        out[(int(v["id"][:3]), int(v["chapter"]), int(v["verse"]))] = v["text"]
    return out


def single_edit(a: str, b: str):
    """The one contiguous difference between a and b, or None.

    Returns (i1, i2, j1, j2). A verse with two independent differences is
    refused: each would need its own adjudication and the witness may be
    right about one and wrong about the other.
    """
    ops = [o for o in difflib.SequenceMatcher(None, a, b, autojunk=False)
           .get_opcodes() if o[0] != "equal"]
    if len(ops) != 1:
        return None
    _, i1, i2, j1, j2 = ops[0]
    return i1, i2, j1, j2


def classify_flat(rows):
    """Split the verses where the reading text stands alone.

    Two of the classes are NOT defects and must not be counted as though
    they were: the 雅伟/基督 restorations are this edition's whole reason
    for existing, and a difference the length of a clause is a verse
    boundary, not a wrong word.
    """
    restoration, clause, word = [], [], []
    for book, key, edit, ftext, ttext, W in rows:
        reading, other = edit
        if reading in ("雅伟", "基督") and f"[{reading}]" in ftext:
            restoration.append((book, key, edit))
        elif max(len(reading), len(other)) >= 8:
            clause.append((book, key, edit))
        else:
            word.append((book, key, edit))
    return [
        ("WORD-LEVEL DEFECT in the reading text", word),
        ("the edition's own [雅伟]/[基督] restoration — not a defect", restoration),
        ("a whole clause — a verse-division difference, not a wrong word", clause),
    ]


_NOTE_BODY = re.compile(r"<note:\s*([^>]*)>|〔([^〕]*)〕|（([^）]*)）")

# The ten verses where the tagged layer holds Han characters BOTH flat
# editions lack. Which side is wrong is NOT decided mechanically — the
# script can only say the three files disagree. Each was read against the
# Strong's number the characters carry, and the verdicts are recorded here
# so the reasoning is re-checkable rather than asserted:
#
# Nine are words the reading text has lost. In every one the number is a
# real Hebrew word and the page without it is ungrammatical or wrong:
# Judges 9:57 prints 「咒诅归到们身上」 — 们 is a plural suffix and cannot
# stand alone; Judges 12:7 loses H8337 六 and says Jephthah judged Israel
# "_ years"; Malachi 2:3 prints 「粪抹你们的脸上」 without H2219's 在.
#
# ONE goes the other way, and it is why this table is not a rule. Job
# 31:36's tagged run is 「愿那敌我敌」 under a SINGLE H7379 (רִיב) — one
# word with a duplicated character, so the reading text's 「愿那敌我者」
# is correct and the tagged layer is wrong. It is a dittography like the
# seven class-B repairs, but a NON-ADJACENT one, so the doubled-character
# gate could not see it. Left alone rather than guessed at.
ADJUDICATED = {
    ("Judges", 9, 57): "reading text lost H413's 他 — 们 cannot stand alone",
    ("Judges", 12, 7): "reading text lost H8337 六 — 'judged Israel _ years'",
    ("Judges", 15, 2): "reading text lost H4994 נָא 我请求",
    ("Judges", 15, 5): "reading text lost H3754 葡萄园 (vineyard)",
    ("Judges", 15, 18): "reading text lost H6258 现在 (now)",
    ("2 Samuel", 5, 17): "reading text lost H3605 众 (all the Philistines)",
    ("2 Samuel", 21, 2): "reading text lost the 大 of H7065 大发热心",
    ("Esther", 6, 7): "reading text lost H376 人",
    ("Malachi", 2, 3): "reading text lost the 在 of H2219 抹在",
    ("Job", 31, 36): "TAGGED IS WRONG — 愿那敌我敌 is one H7379 run, "
                     "a non-adjacent dittography; the reading text is right",
}


def note_bodies(text: str) -> str:
    """The Han stream of everything the reading text files as a note.

    Needed because `han()` DELETES note content, so a verse whose note the
    tagged layer prints inline looks, after reduction, exactly like a verse
    that has lost words. The two are opposite findings and had to be told
    apart mechanically.

    Two things this must not be. A raw substring test against the whole
    verse fails both ways: the notes carry punctuation the tagged runs
    drop (1 Samuel 1:24 files 〔那时，孩子还小。〕 against tagged 那时孩子还
    小), and a one-character fragment matches somewhere in almost any verse
    — Judges 9:57's genuinely missing 他 is 'found' in 报应在他们头上 three
    clauses away. So: note bodies only, and reduced the same way both
    sides are.
    """
    return "".join(han(m.group(1) or m.group(2) or m.group(3) or "")
                   for m in _NOTE_BODY.finditer(text))


def split_flats_agree(rows):
    """Sub-classify the bucket a majority vote would have swept away.

    "Both flat editions agree against the tagged layer" is one verdict but
    two very different situations, and lumping them is what made the first
    draft of this script dangerous:

      * a SUBSTITUTION is almost always one of the orthographic pairs
        (阿/啊, 它/他, 复/覆 …) — two normalisation dates of one word, no
        word lost either way, nothing to repair.

      * a verse where the tagged layer holds characters BOTH flat editions
        lack is a word missing from scripture on the page. Shared ancestry
        means the two flats can inherit one omission, so their agreement
        does not clear it — this is exactly Judges 12:7's 六.

    Reported and never repaired: the fix belongs in the reading text, and
    this script does not write to the reading text.
    """
    subst, lost, noted, tagged_short = [], [], [], []
    for book, key, edit, ftext in rows:
        reading, tagged_read = edit
        if reading and tagged_read:
            subst.append((book, key, edit))
        elif tagged_read:
            if tagged_read in note_bodies(ftext):
                noted.append((book, key, edit))
            else:
                lost.append((book, key, edit))
        else:
            tagged_short.append((book, key, edit))
    return [
        ("the tagged layer holds characters BOTH flat editions lack "
         "— adjudicated by hand, see ADJUDICATED", lost),
        ("the reading text files it as a note — placement, not loss", noted),
        ("a one-for-one substitution — undecidable without an outside source",
         subst),
        ("the tagged layer is missing what both flat editions have",
         tagged_short),
    ]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true",
                    help="write the repairs the gate allows")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    flat = load_flat("cuvs-yhwh")
    witness = load_flat("cuvs-plus")

    verdicts = collections.Counter()
    repairs_tagged = collections.defaultdict(dict)   # book slug -> ref -> new runs
    hash_fixes = collections.defaultdict(dict)
    undecided = []
    decided_flat = []
    flats_agree = []
    fixes_tagged = []

    for num, book in enumerate(CANON, start=1):
        slug = book.lower().replace(" ", "_")
        path = os.path.join(ROOT, "assets", "tagged", "cuvs-yhwh", f"{slug}.json")
        if not os.path.exists(path):
            continue
        tagged = json.load(open(path, encoding="utf-8"))
        by_ref = {}
        for k, runs in tagged.items():
            c, v = k.split(":")
            by_ref[(num, int(c), int(v))] = (k, runs)

        for key, (raw_ref, runs) in sorted(by_ref.items()):
            if key not in flat:
                continue
            ftext = flat[key]
            ttext = "".join(r.get("w") or "" for r in runs)
            if is_placeholder(ftext) or is_placeholder(ttext):
                continue

            # The literal `#` is settled before the witness is consulted:
            # it is not a Chinese character, so the tagged layer cannot be
            # right about it whatever any edition says. Every one of the
            # 17 stands where the reading text prints the supplied [基督].
            if "#" in ttext:
                repl = []
                ok = True
                for r in runs:
                    w = r.get("w") or ""
                    if "#" in w:
                        if ftext.count("[基督]") < w.count("#"):
                            ok = False
                        w = w.replace("#", "[基督]")
                    nr = dict(r)
                    nr["w"] = w
                    repl.append(nr)
                if ok:
                    hash_fixes[slug][raw_ref] = repl
                    verdicts["# → [基督] (supplied word lost in the tagged layer)"] += 1
                else:
                    undecided.append((book, key, "hash without a bracket in the reading text",
                                      ftext, ttext, witness.get(key)))
                    verdicts["undecided"] += 1
                continue

            F, T = fold(ftext), fold(ttext)
            if F == T:
                continue
            if sorted(F) == sorted(T):
                verdicts["same characters, reordered — not a word difference"] += 1
                continue

            W = witness.get(key)
            if W is None or is_placeholder(W):
                undecided.append((book, key, "no witness", ftext, ttext, W))
                verdicts["undecided"] += 1
                continue
            WF = fold_witness(W)
            FW, TW = fold_witness(ftext), fold_witness(ttext)

            edit = single_edit(F, T)
            if edit is None:
                undecided.append((book, key, "more than one difference",
                                  ftext, ttext, W))
                verdicts["undecided"] += 1
                continue
            i1, i2, j1, j2 = edit
            reading, tagged_read = han(ftext)[i1:i2], han(ttext)[j1:j2]

            # Class B — a character doubled against itself in the tagged
            # layer. It is a pure insertion relative to the reading text,
            # and the inserted characters repeat what sits immediately
            # beside them. No edition reads 若若; this is mechanical.
            doubled = (
                not reading and tagged_read
                and (T[max(0, j1 - len(tagged_read)):j1] == fold(tagged_read)
                     or T[j2:j2 + len(tagged_read)] == fold(tagged_read))
                and WF == FW)
            if doubled:
                new = repair_runs(runs, "", j1, j2)
                if new is None:
                    undecided.append((book, key, "doubled, but spanning two runs",
                                      ftext, ttext, W))
                    verdicts["undecided — doubled but not localisable"] += 1
                else:
                    repairs_tagged[slug][raw_ref] = new
                    fixes_tagged.append((book, key, tagged_read + tagged_read,
                                         tagged_read))
                    verdicts["B. doubled character in the tagged layer"] += 1
                continue

            if unbalanced_note(ftext) or unbalanced_note(ttext):
                verdicts["note wrapper does not close — not comparable"] += 1
                undecided.append((book, key, "unbalanced 〔〕", ftext, ttext, W))
                continue

            if WF == FW and WF != TW:
                verdicts["the two flat editions agree against the tagged "
                         "layer — NOT decisive, see Judges 12:7"] += 1
                flats_agree.append((book, key, (reading, tagged_read), ftext))
                undecided.append((book, key, "flat editions agree — undecidable",
                                  ftext, ttext, W))
            elif WF == TW and WF != FW:
                decided_flat.append((book, key, (reading, tagged_read),
                                     ftext, ttext, W))
                verdicts["the reading text stands alone — a defect in it, "
                         "reported not repaired"] += 1
            else:
                undecided.append((book, key, "witness reads a third thing",
                                  ftext, ttext, W))
                verdicts["undecided — three readings"] += 1

    if not args.quiet:
        print("== cuvs-yhwh, adjudicated against cuvs-plus")
        for k, v in verdicts.most_common():
            print(f"   {v:5d}  {k}")
        print()
        print("-- tagged layer repaired (mechanical; no vote taken)")
        for book, key, was, now in fixes_tagged:
            print(f"   {book} {key[1]}:{key[2]}   tagged '{was}' → '{now}'")
        print()
        print("-- the reading text stands alone against BOTH other files")
        print("   (reported, never repaired here: this is scripture on the page)")
        for label, rows in classify_flat(decided_flat):
            print(f"   {label}  [{len(rows)}]")
            for book, key, edit in rows:
                print(f"      {book} {key[1]}:{key[2]}   "
                      f"reading '{edit[0]}' → both others '{edit[1]}'")
        print()
        print("-- both flat editions agree against the tagged layer")
        print("   (shared ancestry, so agreement cannot clear an inherited loss)")
        buckets = split_flats_agree(flats_agree)
        # A hand-written verdict table drifts away from the data it
        # describes unless something says so out loud.
        found = {(b, k[1], k[2]) for b, k, _ in buckets[0][1]}
        if found != set(ADJUDICATED):
            print(f"   !! ADJUDICATED is stale: "
                  f"unlisted {sorted(found - set(ADJUDICATED))} "
                  f"gone {sorted(set(ADJUDICATED) - found)}")
        for label, rows in buckets:
            print(f"   {label}  [{len(rows)}]")
            for book, key, edit in rows:
                seen = ADJUDICATED.get((book, key[1], key[2]))
                print(f"      {book} {key[1]}:{key[2]}   "
                      f"both flats '{edit[0]}' → tagged '{edit[1]}'"
                      + (f"\n         {seen}" if seen else ""))
        print()
        print("-- undecided, left alone")
        for book, key, why, ftext, ttext, W in undecided:
            print(f"   {book} {key[1]}:{key[2]}   ({why})")

    if args.apply:
        written = 0
        for slug in sorted(set(hash_fixes) | set(repairs_tagged)):
            path = os.path.join(ROOT, "assets", "tagged", "cuvs-yhwh", f"{slug}.json")
            doc = json.load(open(path, encoding="utf-8"))
            for ref, runs in hash_fixes.get(slug, {}).items():
                doc[ref] = runs
                written += 1
            for ref, runs in repairs_tagged.get(slug, {}).items():
                doc[ref] = runs
                written += 1
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(doc, fh, ensure_ascii=False, separators=(",", ":"))
                fh.write("\n")
        print(f"\nwrote {written} verses across "
              f"{len(set(hash_fixes) | set(repairs_tagged))} tagged files")

    return 0


def concat_runs(runs):
    """The tagged verse as one string, plus which run owns each
    character. The diff is done on the whole verse and carried back to a
    run afterwards, because a difference does not respect run
    boundaries — 若若 at Leviticus 5:7 is one doubled character sitting
    across two runs."""
    text, owner = [], []
    for i, r in enumerate(runs):
        w = r.get("w") or ""
        text.append(w)
        owner.extend([i] * len(w))
    return "".join(text), owner


def repair_runs(runs, replacement: str, j1: int, j2: int):
    """Put `replacement` where the tagged stream's [j1, j2) sits.

    `j1`/`j2` index the Han stream of the concatenated runs; they are
    carried back to raw offsets through `_kept`, and the edit is refused
    unless every character it touches belongs to ONE run. A difference
    spanning a run boundary would have to guess which run the words
    belong to, and that guess decides which Strong's number the reader is
    shown when they tap it.
    """
    text, owner = concat_runs(runs)
    keep = _kept(text)
    if j1 == j2:
        # A pure insertion: the reading text has a character the tagged
        # layer dropped. Nothing owns the gap, so it is attached to the
        # run holding the character BEFORE it — which is where the words
        # belong grammatically (Leviticus 8:14's 上 belongs with 头).
        if j1 == 0 or j1 > len(keep):
            return None
        at = keep[j1 - 1] + 1
        run = owner[keep[j1 - 1]]
        span = (at, at)
    else:
        if j2 > len(keep):
            return None
        raw = keep[j1:j2]
        run = owner[raw[0]]
        if any(owner[i] != run for i in raw):
            return None
        # Refuse a non-contiguous raw span: characters dropped by _kept
        # (punctuation, note wrappers) sitting inside the edit would be
        # silently deleted with it.
        if raw[-1] - raw[0] != len(raw) - 1:
            return None
        span = (raw[0], raw[-1] + 1)

    before = sum(len(r.get("w") or "") for r in runs[:run])
    out = []
    for i, r in enumerate(runs):
        nr = dict(r)
        if i == run:
            w = r.get("w") or ""
            a, b = span[0] - before, span[1] - before
            if a < 0 or b > len(w):
                return None
            nr["w"] = w[:a] + replacement + w[b:]
        out.append(nr)
    return out


if __name__ == "__main__":
    sys.exit(main())
