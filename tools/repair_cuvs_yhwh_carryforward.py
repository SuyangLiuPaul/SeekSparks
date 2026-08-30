#!/usr/bin/env python3
"""Carry the verified 和合本雅伟版 readings forward across a re-import.

WHY THIS EXISTS. The publisher's 2026-08-29 Online Bible export is a
better text in most respects — 42 那->哪 corrections, 他->她 fixes,
1,786 more punctuation marks — but it REINTRODUCES defects this app had
already found and repaired, because those repairs were never sent
upstream. Measured on that file:

    詩篇 102:26   天地就改变了        should be 天地就都改变了
    耶利米書 7:14 称我为名下          should be 称为我名下
    俄巴底亞書 1:5 若到来你那里        should be 若来到你那里
    使徒行傳 26:16 特意向你我显现      should be 我特意向你显现
    約翰一書 4:2  成了肉身来，        should be 成了肉身来的，

Four of the five are transpositions and one is a dropped character —
the signature of check 46 and check 47. Those checks did not settle them
by taste: the edition contradicts ITSELF elsewhere (耶利米書 7:10, 7:11
and 7:30 all read 稱為我名下的殿; 希伯來書 1:12 quotes 詩篇 102:26 and
keeps the 都; 約翰二書 1:7 carries the same confession as 約翰一書 4:2),
and two outside witnesses that do not descend from our line — ebible.org
cmn-cu89s and 信望愛 unv — reproduce none of the defects. The reasoning
is written out in test/cuvs_yhwh_integrity_test.dart, which is also
where the verified readings live and where this script reads them from.
One source of truth, not two.

WHAT IT DOES NOT DO. It repairs CHARACTERS, never punctuation. The new
edition's punctuation is adopted deliberately (the owner's call), and
the pinned readings predate it — so 士師記 13:7, whose only difference
from its pinned text is a pair of quotation marks the new edition adds,
is correctly left alone. Only the CJK stream is compared and only the
CJK stream is written.

Run:
    python3 tools/repair_cuvs_yhwh_carryforward.py           # report
    python3 tools/repair_cuvs_yhwh_carryforward.py --write
"""
import json
import os
import re
import sys
import difflib
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST = os.path.join(ROOT, "test", "cuvs_yhwh_integrity_test.dart")
is_cjk = lambda c: "一" <= c <= "鿿"
CJK = lambda s: "".join(c for c in s if is_cjk(c))

# Restoring a verse's text without restoring its runs leaves the tagged
# layer describing the defective reading — audit_tagged_layer.py flags it,
# and the Browse window would still show the old words. Whenever we take
# HEAD's verse we take HEAD's runs with it.
TAGGED_DIR = "assets/tagged/cuvs-yhwh"

BOOK_FILES = [
    'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
    'judges', 'ruth', '1_samuel', '2_samuel', '1_kings', '2_kings',
    '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job',
    'psalms', 'proverbs', 'ecclesiastes', 'song_of_solomon', 'isaiah',
    'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel',
    'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah',
    'haggai', 'zechariah', 'malachi',
    'matthew', 'mark', 'luke', 'john', 'acts', 'romans', '1_corinthians',
    '2_corinthians', 'galatians', 'ephesians', 'philippians', 'colossians',
    '1_thessalonians', '2_thessalonians', '1_timothy', '2_timothy', 'titus',
    'philemon', 'hebrews', 'james', '1_peter', '2_peter', '1_john', '2_john',
    '3_john', 'jude', 'revelation',
]


def git_show(path):
    return json.loads(subprocess.run(
        ["git", "-C", ROOT, "show", f"HEAD:{path}"],
        capture_output=True, text=True).stdout)


def restore_tagged(ids, write):
    """Put HEAD's runs back for every verse id whose text we reverted.

    Resolve each id to its BOOK first. A chapter:verse key like '12:13'
    exists in most of the 66 files, so matching on the key alone would
    revert that verse in every book — the first draft of this did exactly
    that and it is why the book map below is explicit.
    """
    if not ids:
        return 0
    rows = git_show("assets/cuvs-yhwh.json")
    books = []
    for r in rows:
        if not books or books[-1] != r["book"]:
            books.append(r["book"])
    bfile = dict(zip(books, BOOK_FILES))
    where = {r["id"]: (r["book"], f"{r['chapter']}:{r['verse']}") for r in rows}

    by_file = {}
    for vid in ids:
        book, key = where[vid]
        by_file.setdefault(bfile[book], []).append(key)

    n = 0
    for fname, keys in by_file.items():
        rel = f"{TAGGED_DIR}/{fname}.json"
        headtags = git_show(rel)
        path = os.path.join(ROOT, rel)
        cur = json.load(open(path))
        touched = False
        for key in keys:
            if key in headtags and cur.get(key) != headtags[key]:
                cur[key] = headtags[key]
                touched = True
                n += 1
        if touched and write:
            with open(path, "w") as fh:
                json.dump(cur, fh, ensure_ascii=False, separators=(",", ":"))
                fh.write("\n")
    return n


REPAIRED = set()


def load_specs():
    """Parse the pinned readings out of the integrity test."""
    src = open(TEST, encoding="utf-8").read()
    specs = []
    for m in re.finditer(r"_Spec\(\s*'([^']+)',\s*'([^']*)',\s*\{(.*?)\},\s*\)",
                         src, re.S):
        asset, label, body = m.group(1), m.group(2), m.group(3)
        entries = {}
        for e in re.finditer(r"'(\d{9})':\s*((?:\s*'(?:[^'\\]|\\.)*')+)", body):
            text = "".join(re.findall(r"'((?:[^'\\]|\\.)*)'", e.group(2)))
            entries[e.group(1)] = text
        if entries:
            specs.append((asset, label, entries))
    return specs


def repair(text, pinned):
    """Return the pinned reading when the CJK stream differs, else `text`.

    WHY THIS IS BLUNT, AND STAYS BLUNT. Two earlier versions tried to be
    clever — keep the new edition's punctuation and move only the Chinese
    characters — and both produced wrong text:

      * walking a flattened edit plan dragged punctuation along with the
        characters (摘葡萄的若来到你那，里岂不剩下些葡萄？呢);
      * a position map fixed that, but then an inserted character has to
        be anchored to a neighbour, and the two cases want OPPOSITE
        neighbours. 約翰一書 4:2 needs 的 before the comma
        (成了肉身來的，就是); 使徒行傳 26:16 needs 我 after it
        (你起來站著，我特意向你顯現). Anchoring backward fixed the first
        and broke the second.

    Punctuation placement is not recoverable from a character-level diff,
    because the comma's correct side depends on the clause, not on the
    characters either side of it. So when the words differ, take the
    verified verse whole. The cost is exact and small: five verses out of
    31,102 keep the previous edition's punctuation. The alternative was
    five verses with the words in the wrong places.

    Verses that differ from their pinned reading ONLY in punctuation are
    left alone — that is the new edition's punctuation being adopted, and
    it is not this script's business.
    """
    if CJK(text) == CJK(pinned):
        return text, 0
    return pinned, 1


STUTTER_TEST = os.path.join(ROOT, "test", "cuvs_yhwh_tagged_layer_test.dart")


def load_stutter_expectations():
    """The seven verses check 46 de-stuttered, pinned in the tagged-layer
    test as `joined(book, 'ch:v')` contains a fragment.

    以賽亞書 41:16 is the reason these need carrying forward: the new
    edition writes 以雅偉為喜樂，以以色列的聖者為誇耀. The doubled 以 looks
    defensible — 以…為… is the construction and the two halves are
    parallel — but cuvs-plus, the public-domain 和合本 1919 and an
    independent witness, reads 以耶和華為喜樂，以色列的聖者為誇耀 with one
    以. The received text governs a 和合本-derived edition, so the second
    以 is a stutter, exactly as check 46 found."""
    src = open(STUTTER_TEST, encoding="utf-8").read()
    m = re.search(r"a doubled character no longer stutters.*?\n  \}\);", src, re.S)
    if not m:
        return []
    return re.findall(r"joined\('([^']+)',\s*'([^']+)'\),\s*contains\('([^']+)'\)",
                      m.group(0))


def apply_stutters(write):
    rows_s = json.load(open(os.path.join(ROOT, "assets", "cuvs-yhwh.json")))
    books = []
    for r in rows_s:
        if not books or books[-1] != r["book"]:
            books.append(r["book"])
    file_book = {f: b for b, f in zip(books, BOOK_FILES)}
    want = {}
    for bfile, ref, frag in load_stutter_expectations():
        ch, vs = ref.split(":")
        book = file_book[bfile]
        vid = next((r["id"] for r in rows_s
                    if r["book"] == book and r["chapter"] == ch and r["verse"] == vs), None)
        if vid:
            want[vid] = frag
    # The pinned fragments are SIMPLIFIED. Testing them against the
    # Traditional file never matches, so every pinned verse looked like a
    # stutter there and was reverted to HEAD — which silently undid the
    # 主* expansion at 馬太福音 9:28 and left one bare marker in 繁體 only.
    # Decide from the Simplified text for both files; the defect is a
    # property of the verse, not of the script it is written in.
    simp_by_id = {r["id"]: r["text"] for r in rows_s}

    total = 0
    for asset in ("assets/cuvs-yhwh.json", "assets/cuvs-yhwh-tr.json"):
        path = os.path.join(ROOT, asset)
        rows = json.load(open(path))
        head = {r["id"]: r["text"] for r in git_show(asset)}
        n = 0
        for r in rows:
            frag = want.get(r["id"])
            if frag is None:
                continue
            # compare on CJK so the new punctuation is not what decides it
            if CJK(frag) in CJK(simp_by_id[r["id"]]):
                continue
            print(f"  {r['book']} {r['chapter']}:{r['verse']}  stutters")
            r["text"] = head[r["id"]]
            REPAIRED.add(r["id"])
            n += 1
        if n:
            print(f"  -> {n} verse(s) in {asset}")
            total += n
            if write:
                with open(path, "w") as fh:
                    json.dump(rows, fh, ensure_ascii=False, separators=(",", ":"))
                    fh.write("\n")
    return total


def load_guards():
    """The `unreadable` map from the integrity test: corrupt fragments
    that cannot occur in Chinese. Each is a defect this app already found
    and repaired; the publisher's newer export reintroduces some of them
    because the repairs were never sent upstream."""
    src = open(TEST, encoding="utf-8").read()
    m = re.search(r"const unreadable = <String, String>\{(.*?)\n  \};", src, re.S)
    if not m:
        return []
    return re.findall(r"^\s*'([^']+)':", m.group(1), re.M)


def apply_guards(write):
    """Any verse tripping a guard takes HEAD's verified reading.

    HEAD is the right source: every one of these fragments was repaired
    there against outside witnesses and pinned by the test. Taking the
    whole verse (rather than splicing the fragment) costs that verse the
    new edition's punctuation, which is the same trade `repair` makes and
    for the same reason — a fragment-level splice cannot know which side
    of a comma a restored character belongs on.
    """
    guards = load_guards()
    total = 0
    for asset in ("assets/cuvs-yhwh.json", "assets/cuvs-yhwh-tr.json"):
        path = os.path.join(ROOT, asset)
        rows = json.load(open(path))
        head = {r["id"]: r["text"] for r in json.loads(subprocess.run(
            ["git", "-C", ROOT, "show", f"HEAD:{asset}"],
            capture_output=True, text=True).stdout)}
        n = 0
        for r in rows:
            hit = next((g for g in guards if g in r["text"]), None)
            if hit is None:
                continue
            fixed = head.get(r["id"])
            if fixed is None or any(g in fixed for g in guards):
                print(f"  !! {asset} {r['id']} trips {hit!r} and HEAD cannot help")
                continue
            print(f"  {r['book']} {r['chapter']}:{r['verse']}  trips {hit!r}")
            r["text"] = fixed
            REPAIRED.add(r["id"])
            n += 1
        if n:
            print(f"  -> {n} verse(s) in {asset}\n")
            total += n
            if write:
                with open(path, "w") as fh:
                    json.dump(rows, fh, ensure_ascii=False, separators=(",", ":"))
                    fh.write("\n")
    return total


def main():
    write = "--write" in sys.argv
    total = 0
    for asset, label, entries in load_specs():
        path = os.path.join(ROOT, asset)
        if not os.path.exists(path):
            continue
        rows = json.load(open(path))
        by = {r["id"]: r for r in rows}
        changed = 0
        for vid, pinned in entries.items():
            r = by.get(vid)
            if r is None:
                print(f"  !! {asset} {vid}: not in the asset")
                continue
            new, n = repair(r["text"], pinned)
            if n and new != r["text"]:
                REPAIRED.add(vid)
                print(f"  {asset} {vid}")
                print(f"     was: {r['text'][:88]}")
                print(f"     now: {new[:88]}")
                r["text"] = new
                changed += 1
        if changed:
            print(f"  -> {changed} verse(s) in {asset}\n")
            total += changed
            if write:
                with open(path, "w") as fh:
                    json.dump(rows, fh, ensure_ascii=False, separators=(",", ":"))
                    fh.write("\n")
    print("\n== guarded fragments ==")
    total += apply_guards(write)
    print("== stutters ==")
    total += apply_stutters(write)
    nt = restore_tagged(sorted(REPAIRED), write)
    print(f"\n== tagged layer ==\n  {nt} run-set(s) restored from HEAD "
          f"for the {len(REPAIRED)} reverted verse(s)")
    print(f"{total} verse(s) {'repaired' if write else 'would be repaired'}.")
    if total and not write:
        print("Re-run with --write to apply.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
