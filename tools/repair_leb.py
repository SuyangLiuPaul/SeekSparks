#!/usr/bin/env python3
"""Repair assets/leb.json against a second witness of the same edition.

`assets/leb.json` arrived with the initial commit, inherited from YsWords,
and was never checked. Cross-checked verse by verse against an independent
copy of the LEB it agrees on 30,276 of 30,431 shared verses space-blind
(99.49%) — so it is unquestionably the same edition — and the disagreements
are all one shape: a scraper that stopped at a block boundary.

Five defects, in descending order of how much a reader loses:

  R1  Judges (618 verses) and Obadiah (21) are absent entirely. A reader on
      LEB cannot open either book.
  R2  Eleven verses were merged into the one before them, because the LEB
      sets a quoted or poetic line as its own block. The text is present but
      the reference is not: Hebrews 1:10, Revelation 7:12 and nine others
      resolve to nothing, while Hebrews 1:9 prints two verses. The merge also
      swallowed the word that introduces the quotation — "saying," in nine of
      the eleven, "and" in Luke 4:11, "And," in Hebrews 1:10 — so the second
      half has to be taken from the witness, not merely cut loose.
  R3  Twelve verses lost their closing clause at the same kind of block
      boundary, and this text is gone rather than misplaced — checked
      against the following verse in every case. Mark 6:6b, Isaiah 5:25b,
      Nahum 3:15b, Philippians 3:4b, 1 John 5:4b and eight more.
  R4  Eight books end with the NEXT book's name glued to the last verse —
      "My love [be] with all of you in Christ Jesus. Corinthians". The
      affected books are exactly those whose successor begins with a
      numeral, so the scraper's heading split ate the numeral and kept the
      rest.
  R5  Three records are book titles wearing a verse number: verse "The",
      text "First Letter of John".

Every guard is a containment check, so no word we already print can change —
it can only be added to. R2 asserts our merged text opens with the witness's
first half and that what remains is a tail of its second; R3 asserts our text
is a prefix of the witness before appending the remainder.

Idempotent — re-running finds nothing to do.

Usage: tools/repair_leb.py [--write] [path/to/verse_readings.jsonl.gz]
"""
import gzip
import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET = os.path.join(ROOT, 'assets', 'leb.json')
DEFAULT_EXPORT = os.path.expanduser(
    '~/Documents/New project/yahwehdehua_bible/output/data/verse_readings.jsonl.gz')

BOOKS = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua",
    "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
    "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
    "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah",
    "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
    "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai",
    "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John", "Acts",
    "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
    "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
    "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James",
    "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation",
]
BOOK_NUM = {b: i + 1 for i, b in enumerate(BOOKS)}

# KJV verse counts, used only to prove the restored books are canonical.
JUDGES_CHAPTERS = [36, 23, 31, 24, 31, 40, 25, 35, 57, 18, 40, 15, 25, 20,
                   20, 31, 13, 31, 30, 48, 25]
OBADIAH_CHAPTERS = [21]

MERGED = [  # R2 — the following verse is inside this one
    ('Matthew', 11, 16), ('Luke', 4, 10), ('Luke', 19, 37), ('Acts', 28, 25),
    ('Hebrews', 1, 9), ('Hebrews', 2, 11), ('Hebrews', 6, 13),
    ('Hebrews', 9, 19), ('Revelation', 7, 11), ('Revelation', 11, 16),
    ('Revelation', 18, 15),
]
TRUNCATED = [  # R3 — this verse lost its closing clause
    ('Genesis', 35, 22), ('Isaiah', 5, 25), ('Nahum', 3, 15), ('Mark', 6, 6),
    ('Mark', 16, 8), ('Luke', 9, 43), ('John', 16, 4), ('John', 19, 16),
    ('Acts', 10, 24), ('Philippians', 3, 4), ('1 Timothy', 6, 2),
    ('1 John', 5, 4),
]


def note_body(x):
    """The witness keeps bracket markup inside a note; the house style does
    not, and an angle bracket there would truncate `<note: …>` on parse."""
    x = x.replace('[', '').replace(']', '').replace('<', '').replace('>', '')
    return re.sub(r'\s+', ' ', x).strip()


def to_house(s):
    """Witness markup -> the convention the other 64 books are written in.

    Verified by applying it to the witness for every shared verse and
    comparing with what we ship: 30,151 of 30,431 reproduce exactly. The
    residue is 125 Psalm superscriptions, which we store as separate
    records, and inconsistent spacing around a note in our own copy.
    """
    s = unicodedata.normalize('NFC', s or '')
    for a, b in [(' ', ' '), (' ', ' '), (' ', ' '),
                 ('​', ''), ('〖', '[['), ('〗', ']]'),
                 ('“', '"'), ('”', '"'), ('‘', "'"),
                 ('’', "'"), ('—', '--'), ('–', '-'),
                 ('…', '...')]:
        s = s.replace(a, b)
    s = re.sub(r'\s*\{Note:\s*(.*?)\}\s*',
               lambda m: '\x01%s\x02 ' % note_body(m.group(1)), s, flags=re.S)
    s = re.sub(r'\s+', ' ', s)
    s = re.sub(r'\s*--\s*', '--', s)
    s = re.sub(r'\s+([,.;:!?])', r'\1', s)
    s = re.sub(r'\x02 (?=[,.;:!?)\]])', '\x02', s)
    s = s.replace('\x01', '<note: ').replace('\x02', '>')
    s = re.sub(r'(["\'])\s+(["\'])', r'\1\2', s)
    return s.strip()


_NOTE = re.compile(r'<note:.*?>')


def canon(house):
    """Scripture only: no notes, no idiom braces, no whitespace.

    Two strings with the same canon differ in nothing a reader would call a
    word, which is what every guard below needs to assert.
    """
    return _NOTE.sub('', house or '').replace('{', '').replace('}', '') \
        .replace(' ', '').replace('\n', '').replace('\t', '')


def split_house_at(house, k):
    """Cut a house-style string where its canon reaches length k.

    Walks rather than slices because notes, braces and spaces occupy raw
    characters and no canonical ones, so a canonical offset is not a raw
    offset.
    """
    seen = i = 0
    while i < len(house):
        if seen == k:
            break
        m = _NOTE.match(house, i)
        if m:
            i = m.end()
            continue
        ch = house[i]
        if ch not in '{} \n\t':
            seen += 1
        i += 1
    if seen != k:
        raise AssertionError('canon shorter than %d' % k)
    # A note or space sitting exactly on the seam belongs to the left half.
    while i < len(house):
        m = _NOTE.match(house, i)
        if m:
            i = m.end()
        elif house[i] in ' \n\t':
            i += 1
        else:
            break
    return house[:i], house[i:]


def load_witness(path):
    out = {}
    with gzip.open(path, 'rt', encoding='utf-8') as fh:
        for line in fh:
            o = json.loads(line)
            if o.get('version') != 'leb':
                continue
            key = (BOOKS[o['book_ordinal'] - 1], o['chapter'], o['verse'])
            out[key] = to_house(o.get('text_with_notes'))
    return out


def verse_id(book, chapter, verse):
    return '%03d%03d%03d' % (BOOK_NUM[book], chapter, verse)


def main():
    args = [a for a in sys.argv[1:] if a != '--write']
    write = '--write' in sys.argv
    export = args[0] if args else DEFAULT_EXPORT
    if not os.path.exists(export):
        sys.exit('witness not found: %s\n'
                 'This repair needs the second copy of the LEB; pass its path.'
                 % export)

    wit = load_witness(export)
    print('witness: %d LEB verses' % len(wit))

    with open(ASSET, encoding='utf-8') as fh:
        records = json.load(fh)
    ours = {}
    for r in records:
        if str(r['verse']).isdigit():
            ours[(r['book'], int(r['chapter']), int(r['verse']))] = r

    counts = dict(r1=0, r2=0, r3=0, r4=0, r5=0)

    # ---- R1: the two absent books ----------------------------------------
    restored = {}
    for book, chapters in (('Judges', JUDGES_CHAPTERS),
                           ('Obadiah', OBADIAH_CHAPTERS)):
        if any(k[0] == book for k in ours):
            print('R1 %s already present, skipping' % book)
            continue
        rows = []
        for ci, expected in enumerate(chapters, start=1):
            got = [k[2] for k in wit if k[0] == book and k[1] == ci]
            assert sorted(got) == list(range(1, expected + 1)), \
                '%s %d: witness has %d verses, canon has %d' % (
                    book, ci, len(got), expected)
            for vi in range(1, expected + 1):
                text = wit[(book, ci, vi)]
                assert text.strip(), '%s %d:%d empty in witness' % (book, ci, vi)
                rows.append({'book': book, 'chapter': str(ci),
                             'verse': str(vi), 'text': text + '\n',
                             'id': verse_id(book, ci, vi)})
        restored[book] = rows
        counts['r1'] += len(rows)

    # ---- R2: verses merged into the one before them ----------------------
    splits = {}
    for key in MERGED:
        book, ch, vs = key
        rec = ours.get(key)
        nxt = (book, ch, vs + 1)
        if rec is None or nxt in ours:
            print('R2 %s %d:%d already split, skipping' % key)
            continue
        a, b = wit.get(key), wit.get(nxt)
        assert a and b, 'R2 %s %d:%d: witness lacks a half' % key
        have = canon(rec['text'])
        assert have.startswith(canon(a)), \
            'R2 %s %d:%d: our text does not open with the first half' % key
        rest = have[len(canon(a)):]
        assert rest and canon(b).endswith(rest), \
            'R2 %s %d:%d: what we hold is not the tail of the second half' % key
        left, _ = split_house_at(rec['text'], len(canon(a)))
        assert canon(left) == canon(a)
        rec['text'] = left.rstrip() + '\n'
        splits[nxt] = {'book': book, 'chapter': str(ch), 'verse': str(vs + 1),
                       'text': b.strip() + '\n',
                       'id': verse_id(book, ch, vs + 1)}
        counts['r2'] += 1

    # ---- R3: verses that lost their closing clause -----------------------
    for key in TRUNCATED:
        rec = ours.get(key)
        assert rec is not None, 'R3 %s %d:%d absent' % key
        full = wit.get(key)
        assert full, 'R3 %s %d:%d: witness empty' % key
        mine, theirs = canon(rec['text']), canon(full)
        if mine == theirs:
            print('R3 %s %d:%d already whole, skipping' % key)
            continue
        assert theirs.startswith(mine), \
            'R3 %s %d:%d: ours is not a prefix of the witness' % key
        _, tail = split_house_at(full, len(mine))
        tail = tail.strip()
        assert tail, 'R3 %s %d:%d: empty tail' % key
        rec['text'] = rec['text'].rstrip() + ' ' + tail + '\n'
        assert canon(rec['text']) == theirs
        counts['r3'] += 1

    # ---- R4: the next book's name glued to the last verse ----------------
    for i, book in enumerate(BOOKS[:-1]):
        rows = [k for k in ours if k[0] == book]
        if not rows:
            continue
        last = ours[max(rows, key=lambda k: (k[1], k[2]))]
        token = re.sub(r'^\d+\s+', '', BOOKS[i + 1])
        body = last['text'].rstrip()
        if not body.endswith(' ' + token):
            continue
        trimmed = body[:-(len(token) + 1)].rstrip()
        assert re.search(r'[.!?"\'>\]]$', trimmed), \
            'R4 %s: would cut into a sentence' % book
        last['text'] = trimmed + '\n'
        counts['r4'] += 1
        print('R4 %-16s %s:%s  removed trailing %r'
              % (book, last['chapter'], last['verse'], token))

    # ---- R5: book titles wearing a verse number --------------------------
    kept = []
    for r in records:
        if str(r['verse']) == 'The':
            assert re.match(r'^(First|Second|Third) Letter of John\s*$',
                            r['text']), 'R5 unexpected: %r' % r['text'][:60]
            counts['r5'] += 1
            continue
        kept.append(r)
    records = kept

    # ---- reassemble, preserving canonical file order ---------------------
    out = []
    for idx, r in enumerate(records):
        out.append(r)
        key = (r['book'], r['chapter'], r['verse'])
        if str(r['verse']).isdigit():
            k = (r['book'], int(r['chapter']), int(r['verse']))
            if k[0] == r['book'] and (r['book'], k[1], k[2] + 1) in splits:
                nxt = (r['book'], k[1], k[2] + 1)
                out.append(splits.pop(nxt))
        nextbook = records[idx + 1]['book'] if idx + 1 < len(records) else None
        if r['book'] == 'Joshua' and nextbook != 'Joshua':
            out.extend(restored.get('Judges', []))
        if r['book'] == 'Amos' and nextbook != 'Amos':
            out.extend(restored.get('Obadiah', []))
    assert not splits, 'unplaced splits: %s' % list(splits)

    books = []
    for r in out:
        if not books or books[-1] != r['book']:
            books.append(r['book'])
    assert len(books) == len(set(books)), 'a book got split across the file'
    assert books == [b for b in BOOKS if b in set(books)], 'book order broken'

    print('\nR1 restored books      %5d verses' % counts['r1'])
    print('R2 merged verses split %5d' % counts['r2'])
    print('R3 clauses restored    %5d' % counts['r3'])
    print('R4 glued names removed %5d' % counts['r4'])
    print('R5 title records cut   %5d' % counts['r5'])
    print('records %d -> %d, books %d' % (len(json.load(open(ASSET))), len(out),
                                          len(books)))
    if not write:
        print('\ndry run; pass --write to save')
        return 0
    # Match the file's existing shape exactly -- two-space indent, real
    # UTF-8, no trailing newline. A compact rewrite is the same data but
    # turns a 660-verse repair into a 213,865-line diff that no reviewer
    # can read, which defeats the point of repairing by script.
    with open(ASSET, 'w', encoding='utf-8') as fh:
        json.dump(out, fh, ensure_ascii=False, indent=2)
    print('wrote %s' % ASSET)
    return 0


if __name__ == '__main__':
    sys.exit(main())
