#!/usr/bin/env python3
"""Check 25 — does every scripture reference the app SHOWS a reader resolve?

`docs/DATA-INTEGRITY.md` has checked the references that the *text* is
keyed by. It has never checked the references that sit in the app's
curated reference data: the synopsis tables, the section headings, the
family tree, the timeline, the archaeology gallery, the king list. Those
are strings a reader taps, and a string that names a verse which does not
exist is the same class of defect as a wrong transliteration — it states
something untrue about the text, and the reader cannot check it.

Canon frame: KJV versification, the same frame check 4 used. A reference
that resolves under KJV but is absent from a modern critical text is a
coverage question, not a broken reference, and is reported separately.

Usage:  python3 tools/audit_reference_assets.py [--json]
"""
from __future__ import annotations

import collections
import json
import re
import sys
from pathlib import Path

ASSETS = Path(__file__).resolve().parent.parent / 'assets'


# ---------------------------------------------------------------- canon

def load_canon() -> tuple[dict, dict]:
    """book -> {chapter -> last verse}, and the book-name alias table."""
    chapters: dict[str, dict[int, int]] = collections.defaultdict(dict)
    for v in json.loads((ASSETS / 'kjv.json').read_text()):
        b, c, n = v['book'], int(v['chapter']), int(v['verse'])
        chapters[b][c] = max(chapters[b].get(c, 0), n)
    alias = {b.lower(): b for b in chapters}
    # The spellings the curated assets actually use, checked by hand
    # against the canon keys rather than assumed.
    alias.update({
        'song of songs': 'Song of Solomon',
        'canticles': 'Song of Solomon',
        'psalm': 'Psalms',
        'revelations': 'Revelation',
    })
    return dict(chapters), alias


# --------------------------------------------------------------- parser

# The shapes `lib/utils/reference_parser.dart` accepts, in its order.
# Cross-chapter first: otherwise the trailing "2:11" of "1 Kings
# 1:1-2:11" absorbs into the book name. That is the shape the
# OT-synopsis importer could not express and therefore corrupted.
_XCHAPTER = re.compile(r'^(.*?)\s+(\d+)\s*[:：.]\s*(\d+)\s*[-–—]\s*(\d+)\s*[:：.]\s*(\d+)$')
# The book part is optional so a continuation segment ("37-38" in
# "John 18:31-33, 37-38") reaches the carry branch below.
_CRANGE = re.compile(r'^(.*?)\s*(\d+)\s*[-–—]\s*(\d+)$')
_MAIN = re.compile(r'^(.*?)\s*(\d+)(?:\s*[:：.]\s*(\d+)(?:\s*[-–—]\s*(\d+))?)?$')

# Books with one chapter: "Jude 14-15" means chapter 1, verses 14-15.
# Mirrors `_singleChapterBooks` in the Dart parser.
SINGLE_CHAPTER = {'Obadiah', 'Philemon', '2 John', '3 John', 'Jude'}


class Ref:
    __slots__ = ('book', 'c1', 'v1', 'c2', 'v2', 'raw')

    def __init__(self, book, c1, v1, c2, v2, raw):
        self.book, self.c1, self.v1, self.c2, self.v2, self.raw = \
            book, c1, v1, c2, v2, raw

    def __repr__(self):
        return f'<{self.raw}>'


def _book(part: str, alias: dict) -> str | None:
    return alias.get(re.sub(r'\s+', ' ', part).strip().lower())


def parse(text: str, alias: dict, carry: Ref | None = None) -> Ref | None:
    """One segment -> Ref. None when the string is not a reference.

    `carry` is the previous segment of a compound reference, supplying
    the book (and the chapter, for a bare "37-38") that the segment
    leaves implicit: "John 18:31-33, 37-38" and "Acts 9:36-43; 10:5-6".

    Whole-chapter ("Genesis 3") and chapter-range ("1 Chronicles 11-29")
    forms carry v1 = None, which the resolver reads as "the whole
    chapter" rather than inventing verse 1.
    """
    raw = text.strip()
    if not raw:
        return None

    # An end that precedes its start is kept, not clamped. The Dart
    # parser clamps it (`verseEnd >= verseStart ? verseEnd : verseStart`)
    # because a reader still has to be sent somewhere; an audit that did
    # the same would report the truncated `2Ki 23:35-24` as healthy,
    # which is how that defect survived its first pass.
    def end_of(v1, v2):
        return v2 if v2 is not None else v1

    def single(book, a, b):
        """'Jude 14-15' — both numbers are verses of the one chapter."""
        return Ref(book, 1, a, 1, end_of(a, b), raw)

    m = _XCHAPTER.match(raw)
    if m:
        book = _book(m[1], alias)
        if book:
            return Ref(book, int(m[2]), int(m[3]), int(m[4]), int(m[5]), raw)

    m = _CRANGE.match(raw)
    if m:
        book = _book(m[1], alias)
        if book in SINGLE_CHAPTER:
            return single(book, int(m[2]), int(m[3]))
        if book:
            return Ref(book, int(m[2]), None, int(m[3]), None, raw)
        # No book of its own: a continuation like ", 37-38" or ", 52".
        if carry is not None and not m[1].strip():
            return Ref(carry.book, carry.c1, int(m[2]), carry.c1, int(m[3]), raw)

    m = _MAIN.match(raw)
    if m:
        book = _book(m[1], alias)
        c, v1 = int(m[2]), (int(m[3]) if m[3] else None)
        v2 = int(m[4]) if m[4] else None
        if book in SINGLE_CHAPTER and c > 1:
            return single(book, c, v1)
        if book:
            return Ref(book, c, v1, c, end_of(v1, v2), raw)
        if carry is not None and not m[1].strip():
            # "Acts 9:36-43; 10:5-6" -> chapter 10 of Acts. A bare
            # number after a versed segment ("Genesis 4:19, 22") is a
            # verse of the carried chapter, not a chapter of its own.
            if v1 is None and carry.v1 is not None:
                return Ref(carry.book, carry.c1, c, carry.c1, c, raw)
            return Ref(carry.book, c, v1, c, end_of(v1, v2), raw)

    # Bare book name — the whole book. The Dart parser sends the reader
    # to chapter 1; either way it names nothing that does not exist.
    book = _book(raw, alias)
    if book:
        return Ref(book, 1, None, 1, None, raw)
    return None


def segments(text: str):
    """'Isaiah 53; Psalm 22' -> each part, in order.

    Production navigates to the first segment only, but a reader reads
    the whole string, so every segment is checked.
    """
    for chunk in re.split(r'\s*;\s*', text.strip()):
        for part in re.split(r'\s*,\s*', chunk):
            if part.strip():
                yield part.strip()


def resolve(r: Ref, canon: dict) -> str | None:
    """None when the reference names only verses that exist."""
    ch = canon.get(r.book)
    if ch is None:
        return f'no such book: {r.book}'
    if r.c1 not in ch:
        return f'{r.book} has no chapter {r.c1}'
    if r.c2 not in ch:
        return f'{r.book} has no chapter {r.c2}'
    if r.c2 < r.c1:
        return f'end chapter {r.c2} precedes start chapter {r.c1}'
    if r.v1 is not None and (r.v1 < 1 or r.v1 > ch[r.c1]):
        return f'{r.book} {r.c1} has {ch[r.c1]} verses, not {r.v1}'
    if r.v2 is not None and (r.v2 < 1 or r.v2 > ch[r.c2]):
        return f'{r.book} {r.c2} has {ch[r.c2]} verses, not {r.v2}'
    if r.c1 == r.c2 and r.v1 is not None and r.v2 is not None and r.v2 < r.v1:
        return f'end verse {r.v2} precedes start verse {r.v1}'
    return None


# ---------------------------------------------------------------- sweep

def sweep(canon, alias):
    """Yield (asset, where, raw, problem) for every reference that fails."""
    bad, prose = [], []
    counts = collections.Counter()

    def check(asset, where, raw):
        if raw is None or not str(raw).strip():
            return
        counts[asset] += 1
        carry = None
        for seg in segments(str(raw)):
            r = parse(seg, alias, carry)
            if r is None:
                # Names no book we ship: free text ("Various NT
                # references") or a deuterocanonical book (Sirach).
                # Reported apart from broken references — it states
                # nothing untrue about a verse we show.
                prose.append((asset, where, raw, seg))
                continue
            carry = r
            why = resolve(r, canon)
            if why:
                bad.append((asset, where, raw, f'{seg!r}: {why}'))

    # ot_synopsis — structured {book, chapter, start, end, endChapter?}
    d = json.loads((ASSETS / 'ot_synopsis.json').read_text())
    for g in d['groups']:
        for ref in g['refs']:
            end = str(ref['end'])
            if ref.get('endChapter', ref['chapter']) != ref['chapter']:
                end = f"{ref['endChapter']}:{end}"
            raw = f"{ref['book']} {ref['chapter']}:{ref['start']}-{end}"
            check('ot_synopsis.json', f"group {g['id']} {g['en']}", raw)

    # gospel_synopsis — free-text per gospel
    d = json.loads((ASSETS / 'gospel_synopsis.json').read_text())
    for e in d['events']:
        for k, raw in e['refs'].items():
            check('gospel_synopsis.json', f"{e['id']} / {k}", raw)

    # family_tree — refs[] per person
    d = json.loads((ASSETS / 'family_tree.json').read_text())
    for p in d['people']:
        for raw in p.get('refs') or []:
            check('family_tree.json', p['id'], raw)

    # bible_timeline — refs[] per event
    d = json.loads((ASSETS / 'bible_timeline.json').read_text())
    for e in d['events']:
        for raw in e.get('refs') or []:
            check('bible_timeline.json', e['id'], raw)

    # bible_evidence — one reference per record
    d = json.loads((ASSETS / 'bible_evidence.json').read_text())
    for e in d['evidences']:
        check('bible_evidence.json', e['id'], e.get('scriptureReference'))

    # hebrew_kings — three reference fields per king
    d = json.loads((ASSETS / 'hebrew_kings.json').read_text())
    for k in d['kings']:
        for f in ('kingsRef', 'chroniclesRef', 'accessionRef'):
            check('hebrew_kings.json', f"{k['id']} / {f}", k.get(f))

    # section_titles — an anchor is (book, chapter, verse)
    d = json.loads((ASSETS / 'section_titles.json').read_text())
    for set_name, books in d['sets'].items():
        for book, chapters in books.items():
            for chapter, titles in chapters.items():
                for t in titles:
                    raw = f"{book} {chapter}:{t['verse']}"
                    check('section_titles.json', f"{set_name} / {t['title']}", raw)

    return counts, bad, prose


def main() -> int:
    canon, alias = load_canon()
    counts, bad, prose = sweep(canon, alias)

    by_asset = collections.Counter(b[0] for b in bad)
    by_prose = collections.Counter(p[0] for p in prose)
    total = sum(counts.values())
    print(f'Check 25 — {total} references in {len(counts)} assets, '
          f'{len(bad)} do not resolve\n')
    print(f"{'asset':28} {'refs':>7} {'broken':>7} {'no book':>8}")
    for asset in sorted(counts):
        print(f'{asset:28} {counts[asset]:>7} {by_asset[asset]:>7} '
              f'{by_prose[asset]:>8}')
    if bad:
        print('\nBroken — names a chapter or verse that does not exist:')
        for asset, where, raw, why in bad:
            print(f'  {asset}  {where}\n      {raw!r} — {why}')
    if prose:
        print('\nNames no book we ship (free text, or outside the canon):')
        for asset, where, raw, seg in prose:
            print(f'  {asset}  {where}  {raw!r} — {seg!r}')

    if '--json' in sys.argv:
        Path('output/check25.json').parent.mkdir(exist_ok=True)
        Path('output/check25.json').write_text(json.dumps(
            {'counts': counts, 'bad': bad, 'prose': prose},
            ensure_ascii=False, indent=1))
    return 1 if bad else 0


if __name__ == '__main__':
    raise SystemExit(main())
