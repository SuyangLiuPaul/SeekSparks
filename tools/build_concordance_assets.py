#!/usr/bin/env python3
"""Eagle's View Modern Concordance -> SeekSparks assets.

Second stage. `import_eaglesview_modern_concordance.py` decodes MC.dct into
one 12.4 MB blob under build/restricted/; this reshapes that blob into
something an app can actually load.

Why two stages: the blob is five flat relational tables (topics, sections,
subsections, verses, stats) that only mean anything joined. Shipping it
as-is would make the app hold 12.4 MB and re-join it on every lookup. So
the join happens here, once, offline.

Layout mirrors assets/tagged/ — a small index that is always loaded, and
per-topic files pulled on demand:

    assets/concordance/index.json     341 topics + their section headings
    assets/concordance/greek.json     StrongGk -> transliteration + type
    assets/concordance/t/<id>.json    one topic, fully joined

Rights: the topic/section/subsection scheme, the verse links and the
corpus statistics are Eagle's View's own editorial work, following
*Modern Concordance to the New Testament* (Darton, 1976). Reuse here is
by the permission the ministry granted; that is why the first stage
refuses to write under assets/ without --acknowledge-rights, and why
this stage records the attribution in the index it writes.
"""
from __future__ import annotations

import argparse
import json
import shutil
from collections import defaultdict
from pathlib import Path

SRC = Path('build/restricted/eaglesview-modern-concordance.json')
OUT = Path('assets/concordance')

# The Modern Concordance is a New Testament Greek concordance, so BookID
# runs 40..66 and nothing else — the first stage asserts exactly that.
NT_BOOKS = [
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
    '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
    '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude',
    'Revelation',
]
BOOK_BY_ID = {40 + i: name for i, name in enumerate(NT_BOOKS)}

# Columns in `stats` that are corpus totals rather than per-book counts.
# Kept separate because they are the concordance's own editorial
# groupings — the reason it calls itself *statistical* — and the UI shows
# them differently from a book row.
TOTALS = {
    'NT': 'nt',
    'G&A T': 'gospelsActs',
    'Paul T': 'paul',
    'John T': 'john',
    'OA T': 'otherAuthors',
}


def _clean(row: dict) -> dict:
    """Drop nulls. mdb-export emits every column for every row, and the
    stats table is mostly empty — a Greek word occurring only in Luke has
    26 null book columns. Dropping them cuts the payload roughly in half
    and lets the UI treat 'absent' as 'zero' without a null check."""
    return {k: v for k, v in row.items() if v not in (None, '', 0)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', type=Path, default=SRC)
    ap.add_argument('--out', type=Path, default=OUT)
    args = ap.parse_args()

    if not args.src.is_file():
        ap.error(f'run import_eaglesview_modern_concordance.py first: {args.src}')
    data = json.loads(args.src.read_text(encoding='utf-8'))

    # ---- joins -------------------------------------------------------
    # StrongGk is PART OF THE KEY, not a payload field. A subsection
    # covers a whole word family — "Abomination" §1 carries G946 BDELUGMA,
    # G947 BDELUSSO and G948 BDELUKTOS — as three rows sharing one
    # (topic, section, subsection, part). Keying without the Greek number
    # collapses them: 7,750 stat rows fall to 3,883, the surviving row
    # wins by insertion order, and every reference for the family piles
    # onto whichever word came last. It spot-checks clean, because the
    # topic and the headings are still right; only the numbers underneath
    # are another word's.
    def key(r):
        return (r['TopicID'], r['SectionID'], r['SubsectionID'],
                r['PartID'], r['StrongGk'])

    verses_by_sub = defaultdict(list)
    for r in data['verses']:
        book = BOOK_BY_ID.get(int(r['BookID']))
        ch, vs = int(r['Chapter']), int(r['Verse'])
        # The first stage documents 5 links with a zero chapter or verse.
        # They cannot be navigated to, so they are dropped rather than
        # rendered as a reference that goes nowhere when tapped.
        if book is None or ch == 0 or vs == 0:
            continue
        verses_by_sub[key(r)].append([book, ch, vs])

    stats_by_sub = {}
    for r in data['stats']:
        totals = {out: r[col] for col, out in TOTALS.items() if r.get(col)}
        books = {k: v for k, v in r.items()
                 if k not in TOTALS and v
                 and k not in ('TopicID', 'SectionID', 'SubsectionID',
                               'PartID', 'StrongGk')}
        if totals or books:
            stats_by_sub[key(r)] = {'totals': totals, 'books': books}

    subsection_keys = {key(r) for r in data['subsections']}
    orphan_refs = sum(len(v) for k, v in verses_by_sub.items()
                      if k not in subsection_keys)

    subs_by_section = defaultdict(list)
    mismatched = 0
    for r in data['subsections']:
        k = key(r)
        refs = verses_by_sub.get(k) or None
        stats = stats_by_sub.get(k) or None
        # Invariant: a word's reference list should be as long as its own
        # NT total says. This is what catches a bad join — under the old
        # 4-part key the whole family's references landed on one word and
        # this ran ~3x over. Counted, not asserted: the source has a
        # handful of genuine disagreements, and the run reports them.
        if refs and stats:
            nt = stats['totals'].get('nt')
            if nt and nt != len(refs):
                mismatched += 1
        subs_by_section[(r['TopicID'], r['SectionID'])].append(_clean({
            'id': r['SubsectionID'],
            'part': r['PartID'],
            'en': r.get('SubsectionDesc_Eng'),
            'zh': r.get('SubsectionDesc_Chs'),
            'g': r.get('StrongGk'),
            'refs': refs,
            'stats': stats,
        }))

    sections_by_topic = defaultdict(list)
    for r in data['sections']:
        sections_by_topic[r['TopicID']].append({
            'id': r['SectionID'],
            'en': r.get('SectionDesc_Eng'),
            'zh': r.get('SectionDesc_Chs'),
            'subsections': subs_by_section.get((r['TopicID'], r['SectionID']), []),
        })

    # ---- write -------------------------------------------------------
    out = args.out
    if out.exists():
        shutil.rmtree(out)
    (out / 't').mkdir(parents=True)

    index = {
        'schemaVersion': 1,
        'source': data.get('source'),
        # Carried into the asset so the attribution travels with the data
        # rather than living only in a tool nobody reads at runtime.
        'attribution': "Eagle's View (eaglesviewsoftware.com), following "
                       'Modern Concordance to the New Testament '
                       '(Darton, Longman & Todd, 1976). Used by permission.',
        'wordTypes': {r['TypeID']: r.get('TypeDesc_Eng') for r in data['wordTypes']},
        'topics': [
            {
                'id': t['TopicID'],
                'en': t.get('TopicDesc_Eng'),
                'zh': t.get('TopicDesc_Chs'),
                'sections': len(sections_by_topic.get(t['TopicID'], [])),
            }
            for t in sorted(data['topics'], key=lambda r: (r.get('TopicDesc_Eng') or ''))
        ],
    }
    (out / 'index.json').write_text(
        json.dumps(index, ensure_ascii=False, separators=(',', ':')) + '\n',
        encoding='utf-8')

    (out / 'greek.json').write_text(
        json.dumps({r['StrongGk']: [r.get('EngGk'), r.get('TypeID')]
                    for r in data['greekWords']},
                   ensure_ascii=False, separators=(',', ':')) + '\n',
        encoding='utf-8')

    # Reverse index: verse -> the concordance entries that cite it. Without
    # this the feature is a separate browser you go to; with it the reader
    # sitting on Matthew 24:15 is told that the Modern Concordance files
    # this verse under "Abomination", which is the question they actually
    # have. One file per book, loaded on the same lazy terms as tagged/.
    #
    # Built from the SAME keys the topic files were built from, not from
    # data['verses'] again. 88 verse links name a (subsection, Greek word)
    # pair that has no row in the subsections table — they are dropped
    # from the topic files as unreachable, and indexing them here anyway
    # would put a topic in the pane that expands to nothing.
    by_verse = defaultdict(lambda: defaultdict(list))
    for k, refs in verses_by_sub.items():
        if k not in subsection_keys:
            continue
        topic_id, section_id, sub_id, part_id, strongs = k
        for book, ch, vs in refs:
            by_verse[book][f'{ch}:{vs}'].append(
                [topic_id, section_id, sub_id, part_id, strongs])
    (out / 'v').mkdir(parents=True)
    for book, refs in by_verse.items():
        (out / 'v' / f'{book.lower().replace(" ", "_")}.json').write_text(
            json.dumps(refs, ensure_ascii=False, separators=(',', ':')) + '\n',
            encoding='utf-8')

    for t in data['topics']:
        tid = t['TopicID']
        (out / 't' / f'{tid}.json').write_text(
            json.dumps({
                'id': tid,
                'en': t.get('TopicDesc_Eng'),
                'zh': t.get('TopicDesc_Chs'),
                'sections': sections_by_topic.get(tid, []),
            }, ensure_ascii=False, separators=(',', ':')) + '\n',
            encoding='utf-8')

    # ---- report ------------------------------------------------------
    kept = sum(len(v) for v in verses_by_sub.values())
    dropped = len(data['verses']) - kept
    size = sum(f.stat().st_size for f in out.rglob('*.json'))
    print(f'topics       {len(data["topics"])}')
    print(f'sections     {len(data["sections"])}')
    print(f'subsections  {len(data["subsections"])}')
    print(f'verse links  {kept} kept, {dropped} dropped (unnavigable)')
    print(f'stat rows    {len(stats_by_sub)}')
    print(f'refs vs NT-total mismatches: {mismatched}')
    print(f'orphan refs  {orphan_refs} (no matching subsection row; dropped)')
    print(f'greek words  {len(data["greekWords"])}')
    print(f'written      {out} ({size/1e6:.1f} MB across '
          f'{len(list(out.rglob("*.json")))} files)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
