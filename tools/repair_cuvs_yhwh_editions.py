#!/usr/bin/env python3
"""Check 50 — the two 和合本雅伟版 editions witness each other.

`assets/cuvs-yhwh.json` (Simplified) and `assets/cuvs-yhwh-tr.json`
(Traditional) are the same edition in two scripts, regenerated together by
`49af9be` — and nothing had ever asked them to agree. Deriving a
traditional->simplified character map from the corpus itself (every
equal-length verse pair, majority vote per character) and converting every
traditional verse found 7 disagreements out of 31,102.

Two are transmission artefacts, singletons against the file's own
overwhelming pattern, and are repaired here:

  038001003  撒迦利亞書 1:3   万军之雅伟說 -> 万军之雅伟说, inside the
      Simplified Bible. That file writes 说 9,538 times and 說 exactly
      once — the Traditional twin reads 說 correctly at the matching site,
      so the two files were telling one sentence two ways.
  040025020  馬太福音 25:20  那另外的的五來 -> 那另外的五千來, inside the
      Traditional Bible: 的 doubled, 千 dropped. The Simplified twin reads
      那另外的五千来, and the same verse writes 五千 three more times.

Five are NOT repaired — 凋 (simplified) / 雕 (traditional) at 023033009,
023040007, 023040008, 059001011, 060001024. The traditional edition writes
雕 at all 83 of its sites, including these five, where the simplified
edition's modernisation spells 凋. That is systematic (83 against 5), not a
singleton, and is the traditional edition's own orthography — repairing it
would fabricate a house-style spelling onto the other script, the same
error `biblexg-v2-tr`'s entry in DATA-INTEGRITY exists to warn against.

Usage:  python3 tools/repair_cuvs_yhwh_editions.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIMPLIFIED = os.path.join(ROOT, 'assets/cuvs-yhwh.json')
TRADITIONAL = os.path.join(ROOT, 'assets/cuvs-yhwh-tr.json')

LEFT_DELIBERATELY = [
    '023033009', '023040007', '023040008', '059001011', '060001024',
]

REPAIRS = [
    (SIMPLIFIED, '038001003', '万军之雅伟說，', '万军之雅伟说，'),
    (TRADITIONAL, '040025020', '那另外的的五來', '那另外的五千來'),
]


def write_like(path, data):
    """Rewrite `path` in the layout it already had.

    Both flat editions are pretty-printed at indent 2. Serialising with a
    different layout reflows the file and buries a one-character correction
    in a multi-megabyte diff.
    """
    with open(path, encoding='utf-8') as fh:
        pretty = fh.read(3) == '[\n '
    with open(path, 'w', encoding='utf-8') as fh:
        if pretty:
            fh.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        else:
            json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))


def apply_repairs():
    by_path = {}
    total = 0
    for path, rid, old, new in REPAIRS:
        if path not in by_path:
            by_path[path] = json.load(open(path, encoding='utf-8'))
        rows = by_path[path]
        row = next((r for r in rows if r['id'] == rid), None)
        if row is None:
            sys.exit(f'ABORT {os.path.relpath(path, ROOT)}: id {rid} not found')
        text = row['text']
        if new in text and old not in text:
            print(f'{os.path.relpath(path, ROOT)} {rid}: already applied')
            continue
        n = text.count(old)
        if n != 1:
            sys.exit(f'ABORT {os.path.relpath(path, ROOT)} {rid}: {old!r} '
                      f'occurs {n} times, expected exactly 1\n  {text}')
        row['text'] = text.replace(old, new)
        print(f'{os.path.relpath(path, ROOT)} {rid}:\n  -  {text}\n  '
              f'+  {row["text"]}')
        total += 1

    for path, rows in by_path.items():
        write_like(path, rows)

    return total


def measure():
    s = {r['id']: r['text'] for r in json.load(open(SIMPLIFIED, encoding='utf-8'))}
    t = {r['id']: r['text'] for r in json.load(open(TRADITIONAL, encoding='utf-8'))}

    lenmis = sum(1 for i in s if len(s[i]) != len(t[i]))

    votes = {}
    for i in s:
        if len(s[i]) != len(t[i]):
            continue
        for a, b in zip(s[i], t[i]):
            votes.setdefault(b, {}).setdefault(a, 0)
            votes[b][a] += 1
    tmap = {k: max(v, key=v.get) for k, v in votes.items()}
    bad = sorted(i for i in s if ''.join(tmap.get(c, c) for c in t[i]) != s[i])

    print(f'\nlenmis {lenmis}')
    print(f'bad {len(bad)} {bad}')
    if bad != LEFT_DELIBERATELY:
        print('WARNING: disagreement set is not exactly the five sites left '
              'deliberately — investigate before trusting this measurement.')


def main():
    total = apply_repairs()
    print(f'\n{total} edit(s) applied')
    measure()


if __name__ == '__main__':
    main()
