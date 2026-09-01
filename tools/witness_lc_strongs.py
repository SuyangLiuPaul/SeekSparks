#!/usr/bin/env python3
"""Compare our tagged Hebrew (assets/originals/*.json) against the
Yahwehdehua export's `lc` reading (the Leningrad Codex), verse by verse,
on Strong's number sequence.

Measures whether `lc` agrees with our own OSHB-derived tagging. It does
not prove our tagging correct — see docs/DATA-INTEGRITY.md check 52 for
why a high agreement rate here is a transmission check, not an
independent vote.

Usage: python3 tools/witness_lc_strongs.py [path-to-bible.sqlite]
"""
import json
import os
import sqlite3
import sys

DEFAULT_DB = os.path.expanduser(
    "~/Documents/New project/yahwehdehua_bible/output/bible.sqlite"
)

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIGINALS_DIR = os.path.join(REPO_ROOT, "assets", "originals")

sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))
from build_originals import OSIS_HEBREW  # noqa: E402  (needs sys.path set first)


def slug(english_book):
    """Matches OriginalsService._slug in lib/services/originals_service.dart."""
    return english_book.lower().replace(" ", "_").replace("'", "")


def load_book_map(conn):
    """OSIS code -> (slug, our parsed verse map). Verified against
    books.chapter_count so a bad join fails loudly instead of silently
    comparing the wrong book."""
    chapter_counts = dict(
        conn.execute(
            "select code, chapter_count from books where ordinal between 1 and 39"
        ).fetchall()
    )
    mapping = {}
    unresolved = []
    for code, english in OSIS_HEBREW:
        book_slug = slug(english)
        path = os.path.join(ORIGINALS_DIR, book_slug + ".json")
        if not os.path.exists(path):
            unresolved.append(f"{code} -> {book_slug} (asset file missing)")
            continue
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        expected_chapters = chapter_counts.get(code)
        if expected_chapters is None:
            unresolved.append(f"{code} -> {book_slug} (not in export's books table)")
            continue
        max_chapter = max(int(k.split(":")[0]) for k in data.keys())
        if max_chapter != expected_chapters:
            unresolved.append(
                f"{code} -> {book_slug} "
                f"(chapter_count mismatch: export says {expected_chapters}, "
                f"asset's highest chapter is {max_chapter})"
            )
            continue
        mapping[code] = (book_slug, data)
    return mapping, unresolved


def strongs_for_verse(conn, code, chapter, verse):
    rows = conn.execute(
        "select rs.strong_id from reading_segments rs "
        "join verse_readings vr on vr.id = rs.reading_id "
        "where vr.version='lc' and vr.book_code=? and vr.chapter=? "
        "and vr.verse=? and rs.type='strong' "
        "order by rs.segment_ordinal",
        (code, chapter, verse),
    ).fetchall()
    return [r[0] for r in rows]


def main():
    db_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DB
    if not os.path.exists(db_path):
        print(f"error: sqlite export not found at {db_path}", file=sys.stderr)
        return 2

    conn = sqlite3.connect(db_path)

    book_map, unresolved = load_book_map(conn)
    print(f"books joined: {len(book_map)} / {len(OSIS_HEBREW)}")
    print(f"books unresolved: {len(unresolved)}")
    if unresolved:
        print("UNRESOLVED (excluded from the sweep below, not silently skipped):")
        for u in unresolved:
            print(f"  {u}")
        print()
        print(
            "PARTIAL SWEEP: the two counts above are real. What follows "
            "covers only the resolved books and is not a claim about the "
            "whole Old Testament."
        )
        print()

    both = 0
    only_ours = 0
    only_theirs = 0
    identical = 0
    length_differs = 0
    value_differs = 0
    diffs = []

    for code, (book_slug, data) in book_map.items():
        their_verses = conn.execute(
            "select distinct chapter, verse from verse_readings "
            "where version='lc' and book_code=?",
            (code,),
        ).fetchall()
        their_keys = {f"{c}:{v}" for (c, v) in their_verses}
        our_keys = set(data.keys())

        only_ours += len(our_keys - their_keys)
        only_theirs += len(their_keys - our_keys)

        for key in sorted(our_keys & their_keys, key=lambda k: (
            int(k.split(":")[0]), int(k.split(":")[1])
        )):
            c_str, v_str = key.split(":")
            c, v = int(c_str), int(v_str)
            ours_seq = [w["s"] for w in data[key] if w.get("s")]
            theirs_seq = strongs_for_verse(conn, code, c, v)
            both += 1
            if ours_seq == theirs_seq:
                identical += 1
            else:
                if len(ours_seq) != len(theirs_seq):
                    length_differs += 1
                else:
                    value_differs += 1
                if len(diffs) < 20:
                    diffs.append((book_slug, c, v, ours_seq, theirs_seq))

    print()
    print(f"verses on both sides: {both}")
    print(f"verses only ours: {only_ours}")
    print(f"verses only theirs: {only_theirs}")
    print(f"identical Strong's sequence: {identical}")
    print(f"length differs: {length_differs}")
    print(f"same length, different values: {value_differs}")
    print()
    print(f"first {len(diffs)} differing verses:")
    for book_slug, c, v, ours_seq, theirs_seq in diffs:
        print(f"  {book_slug} {c}:{v}  ours={ours_seq}  theirs={theirs_seq}")

    return 1 if unresolved else 0


if __name__ == "__main__":
    sys.exit(main())
