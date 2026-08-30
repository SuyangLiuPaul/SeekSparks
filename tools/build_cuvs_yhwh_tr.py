#!/usr/bin/env python3
"""Rebuild `assets/cuvs-yhwh-tr.json` from the Simplified edition.

Run this AFTER tools/import_yahweh_ont.py has updated the Simplified
text, and BEFORE tools/repair_cuvs_yhwh_tr.py.

THE PROBLEM THIS SOLVES. The Traditional edition is not an independent
text — it is the Simplified one converted. But it is not a NAIVE
conversion any more: #323 corrected 1,607 characters in it that a
one-resolution-per-character conversion had got wrong (只/隻, 余/餘,
干/乾/幹, 凈/淨), and check 46 and check 47 corrected more. Regenerating
it with `opencc -c s2t` would throw all of that away and, per that
ticket's own measurement, invent a fresh defect at 以賽亞書 29:17.

SO DO NOT REGENERATE WHAT DID NOT CHANGE. The shipped Simplified and
Traditional editions align 1:1 on CJK characters in all 31,102 verses —
verified, not assumed. That makes the shipped Traditional text a
per-verse, per-position ANSWER KEY for what each Simplified character
became, with every hand correction already baked in. Where the new
Simplified text has not moved, carry the shipped Traditional character
across unchanged. Only genuinely new or changed characters need a
conversion, and those go through opencc and then through
repair_cuvs_yhwh_tr.py, which is rule-based, context-aware and
idempotent.

Alignment is done with difflib on the CJK stream, so an insertion or a
deletion shifts nothing after it.

Punctuation is converted by rule, measured off the shipped pair:
    “ -> 「   3,412      ‘ -> 『     625
    ” -> 」   3,084      ’ -> 』     599
and nothing else differs.

Run:
    python3 tools/build_cuvs_yhwh_tr.py          # report only
    python3 tools/build_cuvs_yhwh_tr.py --write
"""
import json
import os
import subprocess
import sys
import difflib
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUOTES = {"“": "「", "”": "」", "‘": "『", "’": "』"}
is_cjk = lambda c: "一" <= c <= "鿿"


def opencc(texts):
    """Simplified -> Traditional, one line per input. s2t, NOT s2twp:
    the edition is not Taiwan-localised and s2twp would rewrite
    vocabulary, not just characters."""
    if not texts:
        return []
    p = subprocess.run(["opencc", "-c", "s2t"], input="\n".join(texts),
                       capture_output=True, text=True)
    if p.returncode != 0:
        raise SystemExit(f"opencc failed: {p.stderr}")
    out = p.stdout.split("\n")
    while len(out) > len(texts) and out[-1] == "":
        out.pop()
    if len(out) != len(texts):
        raise SystemExit(f"opencc returned {len(out)} lines for {len(texts)}")
    return out


def main():
    write = "--write" in sys.argv
    S = json.load(open(os.path.join(ROOT, "assets", "cuvs-yhwh.json")))
    T = json.load(open(os.path.join(ROOT, "assets", "cuvs-yhwh-tr.json")))
    if [a["id"] for a in S] != [b["id"] for b in T]:
        raise SystemExit("FATAL: the two editions are not in the same order")

    # The shipped pair is the answer key. Rebuild it against the SHIPPED
    # Simplified text as committed in git, not the new one — that is what
    # its characters were the conversion of.
    old_S = json.loads(subprocess.run(
        ["git", "-C", ROOT, "show", "HEAD:assets/cuvs-yhwh.json"],
        capture_output=True, text=True).stdout)
    if len(old_S) != len(S):
        raise SystemExit("FATAL: HEAD's Simplified asset has a different length")

    stat = collections.Counter()
    need_cc = []          # (verse index, char) needing conversion
    plans = []

    for idx, (olds, news, oldt) in enumerate(zip(old_S, S, T)):
        a = [c for c in olds["text"] if is_cjk(c)]
        b = [c for c in news["text"] if is_cjk(c)]
        keyed = [c for c in oldt["text"] if is_cjk(c)]
        if len(keyed) != len(a):
            # shipped pair itself is out of step; convert the whole verse
            plans.append((idx, None))
            need_cc.append((idx, news["text"]))
            stat["whole verse converted (answer key unusable)"] += 1
            continue
        if a == b:
            plans.append((idx, list(keyed)))
            stat["carried over unchanged"] += 1
            continue
        out = []
        sm = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
        for tag, i1, i2, j1, j2 in sm.get_opcodes():
            if tag == "equal":
                out.extend(keyed[i1:i2])
            else:
                out.extend(None for _ in range(j2 - j1))   # placeholder
        plans.append((idx, out))
        need_cc.append((idx, "".join(b)))
        stat["partially reconverted"] += 1

    conv = dict(zip([i for i, _ in need_cc], opencc([t for _, t in need_cc])))

    out_rows = []
    n_holes = 0
    for (idx, plan), news, oldt in zip(plans, S, T):
        if plan is None:
            body = conv[idx]
            for q, r in QUOTES.items():
                body = body.replace(q, r)
            out_rows.append({**oldt, "text": body})
            continue
        fill = [c for c in conv.get(idx, "") if is_cjk(c)] if idx in conv else []
        k = 0
        res = []
        for c in plan:
            if c is None:
                res.append(fill[k] if k < len(fill) else "?")
                n_holes += 1
            else:
                res.append(c)
            k += 1
        it = iter(res)
        body = "".join(next(it) if is_cjk(ch) else QUOTES.get(ch, ch)
                       for ch in news["text"])
        out_rows.append({**oldt, "text": body})

    print(f"verses: {len(out_rows):,}")
    for k, n in stat.most_common():
        print(f"   {n:7,}  {k}")
    print(f"   characters filled from opencc: {n_holes:,}")

    for a, b in zip(S, out_rows):
        ca = sum(1 for c in a["text"] if is_cjk(c))
        cb = sum(1 for c in b["text"] if is_cjk(c))
        if ca != cb:
            raise SystemExit(f"FATAL: CJK length drift at {b['id']}: {ca} vs {cb}")
    print("   CJK 1:1 with the Simplified edition: OK")

    if not write:
        print("\n--check only. Re-run with --write to apply.")
        return 0
    with open(os.path.join(ROOT, "assets", "cuvs-yhwh-tr.json"), "w") as fh:
        json.dump(out_rows, fh, ensure_ascii=False, separators=(",", ":"))
        fh.write("\n")
    print("\nwritten: assets/cuvs-yhwh-tr.json")
    print("NEXT: python3 tools/repair_cuvs_yhwh_tr.py --write")
    return 0


if __name__ == "__main__":
    sys.exit(main())
