#!/usr/bin/env python3
"""Eagle's View's Greek New Testament statistics -> SeekSparks assets.

`Default.cdb` is the database the program is named for. Its `Data` table
profiles all 6,221 distinct Greek words of the Westcott-Hort text: for
each one, how often it occurs in every one of the 27 New Testament books,
where it ranks within each of those books, its totals across the Gospels
& Acts / Paul / John / the other authors, and its absolute and relative
rank in the corpus as a whole. `SumStat` sits above that with a 27-row
comparative profile of the books themselves.

This is the part BibleWorks has no equivalent for. BibleWorks will count
what you ask it to count; it does not ship a precomputed table telling you
that Mark uses 1,342 distinct words across 11,275 running words, or that a
given word is the 12th most common in Luke and absent from Jude.

Rights: "Copyright 2007 AOSurvey Co., Ltd.", stated in the database's own
Details table. Used by the permission the ministry granted for AOSurvey's
tagging and corpus statistics. `attribution` carries that into the asset.

Output mirrors assets/concordance/:

    assets/greek_stats/index.json   the 27-book SumStat table + POS list
    assets/greek_stats/w/<n>.json   words bucketed by Strong's thousand

Bucketed because the Stats pane looks up one word at a time: a reader on
G946 should pull ~400 KB, not the whole 2 MB.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import shutil
import subprocess
from pathlib import Path

SRC = Path('/private/tmp/seeksparks-eaglesview.WWxd2D/msiextracted/Default.cdb')
OUT = Path('assets/greek_stats')

# Book abbreviations as the database spells them, in canonical order. The
# per-book columns are "<abbr>" for the count and "<abbr> RC" for the rank
# within that book.
BOOKS = [
    'Mat', 'Mar', 'Luk', 'Joh', 'Act', 'Rom', '1Co', '2Co', 'Gal', 'Eph',
    'Phi', 'Col', '1Th', '2Th', '1Ti', '2Ti', 'Tit', 'Phm', 'Heb', 'Jam',
    '1Pe', '2Pe', '1Jo', '2Jo', '3Jo', 'Jud', 'Rev',
]
ENGLISH = [
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans', '1 Corinthians',
    '2 Corinthians', 'Galatians', 'Ephesians', 'Philippians', 'Colossians',
    '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus',
    'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John',
    '3 John', 'Jude', 'Revelation',
]
TOTALS = {'NT': 'nt', 'G&A T': 'gospelsActs', 'Paul T': 'paul',
          'John T': 'john', 'OA T': 'otherAuthors'}


def export(db: Path, table: str) -> list[dict]:
    out = subprocess.run(['mdb-export', str(db), table],
                         capture_output=True, text=True, check=True).stdout
    return list(csv.DictReader(io.StringIO(out)))


def num(v):
    """'' and 'NULL' both mean absent here; mdb-export emits both."""
    if v is None:
        return None
    v = v.strip()
    if not v or v == 'NULL':
        return None
    try:
        return int(v)
    except ValueError:
        try:
            return float(v)
        except ValueError:
            return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', type=Path, default=SRC)
    ap.add_argument('--out', type=Path, default=OUT)
    args = ap.parse_args()
    if not args.src.is_file():
        ap.error(f'database not found: {args.src}')

    data = export(args.src, 'Data')
    summary = export(args.src, 'SumStat')

    out = args.out
    if out.exists():
        shutil.rmtree(out)
    (out / 'w').mkdir(parents=True)

    buckets: dict[int, dict] = {}
    kept = skipped = 0
    for r in data:
        sid = num(r.get('Strong_Gk'))
        if sid is None:
            skipped += 1
            continue
        kept += 1
        # Per-book: [count, rankInThatBook]. Absent books are omitted
        # entirely rather than stored as zero — most words appear in only
        # a handful of the 27, so this is the difference between a 2 MB
        # asset and a 9 MB one.
        books = {}
        for abbr, name in zip(BOOKS, ENGLISH):
            c = num(r.get(abbr))
            if c:
                books[name] = [c, num(r.get(f'{abbr} RC'))]
        entry = {
            'g': f'G{sid}',
            'w': (r.get('Greek') or '').strip(),
            'd': (r.get('Description') or '').strip(),
            # Root Strong's numbers this word is built from — the
            # etymology WordFam.mdb also holds, which is why that module
            # is not imported separately.
            'r': [f'G{x.strip()}' for x in (r.get('Root') or '').split(',')
                  if x.strip().isdigit()],
            'p': (r.get('Mood') or '').strip(),
            'totals': {out_k: num(r[col])
                       for col, out_k in TOTALS.items() if num(r.get(col))},
            'rank': {k: v for k, v in
                     (('abs', num(r.get('R(A)'))), ('rel', num(r.get('R(R)'))))
                     if v is not None},
            'books': books,
        }
        buckets.setdefault(sid // 1000, {})[entry['g']] = {
            k: v for k, v in entry.items() if v not in (None, '', [], {})
        }

    for b, words in sorted(buckets.items()):
        (out / 'w' / f'{b}.json').write_text(
            json.dumps(words, ensure_ascii=False, separators=(',', ':')) + '\n',
            encoding='utf-8')

    index = {
        'schemaVersion': 1,
        'source': "Eagle's View 2.0 / Westcott-Hort Greek New Testament",
        'attribution': 'Greek New Testament corpus statistics © 2007 '
                       "AOSurvey Co., Ltd., supplied with Eagle's View "
                       '(eaglesviewsoftware.com). Used by permission.',
        'buckets': sorted(buckets),
        # The 27-book comparative profile, verbatim but with the columns
        # named rather than positional.
        'books': [
            {
                'no': num(r.get('Book no')),
                'abbr': (r.get('Book name') or '').strip(),
                'name': ENGLISH[num(r['Book no']) - 1]
                        if num(r.get('Book no')) and
                        1 <= num(r['Book no']) <= 27 else None,
                'totalWords': num(r.get('Total words')),
                'distinctWords': num(r.get('Total distinct Greek words')),
                'meanOccurrence': num(r.get('Mean word occurrence')),
                # The concordance's own yardstick: each book's vocabulary
                # richness expressed against Luke, the largest NT book.
                'ratioVsLuke': num(
                    r.get('Relative Ranking Ratio(Gospel of Luke)')),
                'wordsRankedA12': num(r.get('Number of words in R(A) 1-2')),
                'wordsRankedR12': num(r.get('Number of words in R(R) 1-2')),
            }
            for r in summary
        ],
    }
    (out / 'index.json').write_text(
        json.dumps(index, ensure_ascii=False, separators=(',', ':')) + '\n',
        encoding='utf-8')

    size = sum(f.stat().st_size for f in out.rglob('*.json'))
    print(f'words        {kept} kept, {skipped} skipped (no Strong number)')
    print(f'buckets      {len(buckets)} ({", ".join(str(b) for b in sorted(buckets))})')
    print(f'book profile {len(index["books"])} rows')
    print(f'written      {out} ({size/1e6:.1f} MB)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
