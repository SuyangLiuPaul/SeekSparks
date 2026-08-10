#!/usr/bin/env python3
"""Build the Berean Standard Bible assets: plain text + Strong's tagging.

Why BSB: until now `assets/tagged/` held exactly one version, cuvs-yhwh,
so inline Strong's numbers were a Chinese-only feature — an English
reader hovering a word could only ever learn which *verse* they were in.
The BSB is public domain ("This text of God's Word has been dedicated to
the public domain", stated in bsb.txt itself) AND ships word-aligned to
the WLC/Nestle base with Strong's numbers, which is the rare combination
that lets us tag an English column without licensing anything.

Two inputs, both from bereanbible.com:

  bsb.txt           verse text, one `Book C:V<TAB>text` line per verse.
                    Used as the authority for the printed text.
  bsb_tables.xlsx   754k word rows on sheet `biblosinterlinear96`.
                    Used only for the word→Strong's alignment.

Run:  python3 tools/import_bsb.py /tmp/bsb.txt /tmp/bsb_tables.xlsx

Outputs `assets/bsb.json` and `assets/tagged/bsb/<book>.json`, matching
the shapes `fetch_bible_versions.py` and `import_yahweh_modules.py`
already produce — see those for the schemas.
"""
import json
import os
import re
import sys

import openpyxl

# The app's canonical book names and order (nasb.json / bible_books.dart).
BOOKS = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
    'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
    'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
    'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai',
    'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John', 'Acts',
    'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
    '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation',
]
BOOK_NO = {b: i + 1 for i, b in enumerate(BOOKS)}

# BSB's only naming difference from the app's list.
RENAME = {'Psalm': 'Psalms'}

# The tables use a middle dot for "no value in this cell".
EMPTY = {'', '·'}

# Three ways the BSB column says "this original word has no English of its
# own". `-` is an original with no rendering at all (the direct-object
# marker, some articles); `. . .` and `vvv` mark an original folded into a
# neighbouring English phrase — עֲשָׂה־אֵל is two rows and one name. None of
# them is text: the printed Bible contains no `vvv` and no spaced ellipsis.
PLACEHOLDERS = {'-', '. . .', 'vvv'}
PLACEHOLDER_RE = re.compile(r'^(?P<pre>[(\[“‘]*)\s*(?P<core>\. \. \.|vvv|-)'
                            r'\s*(?P<post>[^\w]*)$')

# The verse-number anchor and the paragraph/list markup ride in the same
# cells as the quotation marks. They are the source's typesetting, not the
# translation, and the app draws its own verse numbers.
HTML_RE = re.compile(r'<[^<>]{0,200}>')

# BSB sets the em dash tight against the words on both sides.
TIGHT_AFTER = ('—', '–')

# The tables mark words with no counterpart in the original two ways:
# `[were]` (18,689 cells) and `{will}` (1,270, almost all auxiliaries and
# negation — `{do} not`, `{has} not yet`). Both are the same claim about
# the text and the app has one convention for it, so the rarer form is
# folded into the commoner rather than printed raw. `12,000 {}` carries an
# empty pair; it marks nothing and goes.
BRACES_RE = re.compile(r'\{\s*(.*?)\s*\}')

# A closing quote in the trailing columns can be bracketed — `[’’]` — and
# the printed Bible does not carry it. Quotation marks are the editor's,
# not the original's, and bsb.txt is the authority for what is printed.
SUPPLIED_RE = re.compile(r'\[[^\]]*\]')

# Fourteen cells put a placeholder next to real text (`vvv him`,
# `. . . 40,500`) instead of alone in the cell.
LOOSE_PLACEHOLDER_RE = re.compile(r'(?:\. \. \.|(?<![\w])vvv(?![\w]))')


def cell(row, i):
    """A cell as a clean string, with the table's null marker removed."""
    if i >= len(row) or row[i] is None:
        return ''
    raw = row[i]
    # A count like 74,600 is stored as a number in some rows and as text in
    # others. str() on the number drops the separator the Bible prints.
    if isinstance(raw, int) and not isinstance(raw, bool) and abs(raw) >= 1000:
        return f'{raw:,}'
    v = str(raw).strip()
    return '' if v in EMPTY else v


def build_text(txt_path, out_path):
    """bsb.txt → assets/bsb.json."""
    verses = []
    line_re = re.compile(r'^(.+?) (\d+):(\d+)\t(.*)$')
    with open(txt_path, encoding='utf-8-sig') as fh:
        for line in fh:
            m = line_re.match(line.rstrip('\n'))
            if not m:
                continue  # the two-line copyright header and the column row
            book = RENAME.get(m.group(1), m.group(1))
            if book not in BOOK_NO:
                raise SystemExit(f'unknown book in bsb.txt: {m.group(1)!r}')
            chap, vs, text = m.group(2), m.group(3), m.group(4).strip()
            if not text:
                continue
            verses.append({
                'book': book,
                'chapter': chap,
                'verse': vs,
                'text': text,
                'id': f'{BOOK_NO[book]:03d}{int(chap):03d}{int(vs):03d}',
            })
    with open(out_path, 'w', encoding='utf-8') as fh:
        json.dump(verses, fh, ensure_ascii=False, separators=(',', ':'))
    return verses


def runs_for_verse(rows):
    """Word rows for one verse → the tagged runs the app renders.

    Two orders matter and they are not the same. The sheet lists rows in
    BSB (English) order, which is the order to PRINT. Which word an
    untranslated original attaches to is a question about the ORIGINAL's
    order — Hebrew אֵת precedes the noun it marks, and after the English
    reshuffle that noun can be several rows away, or behind it.

    So: walk the original order to decide attachment, emit in BSB order.
    This reproduces what the cuvs-yhwh data does, where H853 rides on 天
    rather than on whatever word English happened to put next.

    A row that renders no English still carries printed text. Its quotation
    mark, its comma, its closing bracket all belong to the verse, and the
    row they sit on is an accident of which Hebrew word the punctuation
    followed. Drop the row and its punctuation goes with it: that is how
    `1 Chronicles 1:12` lost the `)` of "(from whom the Philistines came)".
    """
    ordered = []
    for i, r in enumerate(rows):
        lang = cell(r, 4)
        num = cell(r, 10) if lang == 'Hebrew' else cell(r, 11)
        strongs = ''
        if num:
            # Some cells carry a trailing letter (e.g. 1254a) marking a
            # homograph split; the app's lexicon is keyed on the bare
            # number, so drop it.
            digits = re.match(r'\d+', num)
            if digits:
                strongs = ('H' if lang == 'Hebrew' else 'G') + digits.group(0)
        raw = BRACES_RE.sub(lambda m: f'[{m.group(1)}]' if m.group(1) else '',
                            cell(r, 18)).strip()
        lead = HTML_RE.sub('', cell(r, 17))
        # pnc, endQ and End text are three columns of trailing printed
        # characters. Reading only the first is what left 1,986 verses
        # short of their closing quotation mark or bracket.
        trail = (cell(r, 19)
                 + SUPPLIED_RE.sub('', cell(r, 20))
                 + SUPPLIED_RE.sub('', HTML_RE.sub('', cell(r, 22))))
        word = raw
        rendered = bool(raw)
        if rendered:
            m = PLACEHOLDER_RE.match(raw)
            if m:
                rendered = False
                word = ''
                lead += m.group('pre')
                trail = m.group('post') + trail
            else:
                word = LOOSE_PLACEHOLDER_RE.sub(' ', raw)
                word = re.sub(r'\s+', ' ', word).strip()
                rendered = bool(word)
        sort_raw = cell(r, 0) if lang == 'Hebrew' else cell(r, 1)
        try:
            sort_key = int(sort_raw)
        except ValueError:
            sort_key = 0
        ordered.append({
            'bsb_i': i,
            'sort': sort_key,
            'strongs': strongs,
            'word': word,
            'lead': lead,
            'trail': trail,
            'rendered': rendered,
        })

    # Attach each unrendered original to the next rendered word in the
    # ORIGINAL's order; anything still pending at the end rides on the
    # last rendered word rather than being dropped.
    implied = {}
    pending = []
    for item in sorted(ordered, key=lambda d: d['sort']):
        if item['rendered']:
            if pending:
                implied.setdefault(item['bsb_i'], []).extend(pending)
                pending = []
        elif item['strongs']:
            pending.append(item['strongs'])
    if pending:
        last = [d for d in ordered if d['rendered']]
        if last:
            implied.setdefault(last[-1]['bsb_i'], []).extend(pending)

    runs = []
    carried = ''
    for item in ordered:
        if not item['rendered']:
            carried += item['lead']
            if item['trail']:
                if runs:
                    runs[-1]['tail'] += item['trail']
                else:
                    carried += item['trail']
            continue
        runs.append({
            'lead': carried + item['lead'],
            'word': item['word'],
            'tail': item['trail'],
            'strongs': item['strongs'],
            'bsb_i': item['bsb_i'],
        })
        carried = ''
    if carried and runs:
        runs[-1]['tail'] += carried

    out = []
    for run in runs:
        # A trailing space is part of the run: browse_window lays runs
        # out in a Wrap with no separator between children, which is
        # right for Chinese and would glue English words together.
        text = f"{run['lead']}{run['word']}{run['tail']}"
        if not text.endswith(TIGHT_AFTER):
            text += ' '
        got = implied.get(run['bsb_i'])
        emitted = {'w': text, 's': run['strongs']}
        if got:
            emitted['i'] = got
        out.append(emitted)
    if out:
        out[-1]['w'] = out[-1]['w'].rstrip()
    return out


def build_tagged(xlsx_path, out_dir):
    """bsb_tables.xlsx → assets/tagged/bsb/<book>.json."""
    wb = openpyxl.load_workbook(xlsx_path, read_only=True, data_only=True)
    ws = wb['biblosinterlinear96']

    books = {}          # book → {"c:v": runs}
    cur_ref = None      # (book, chapter, verse)
    cur_rows = []
    ref_re = re.compile(r'^(.+?) (\d+):(\d+)$')

    def flush():
        if cur_ref and cur_rows:
            book, chap, vs = cur_ref
            runs = runs_for_verse(cur_rows)
            if runs:
                books.setdefault(book, {})[f'{chap}:{vs}'] = runs

    for n, row in enumerate(ws.iter_rows(values_only=True)):
        if n == 0:
            continue
        vid = cell(row, 12)
        if vid:
            m = ref_re.match(vid)
            if m:
                flush()
                book = RENAME.get(m.group(1), m.group(1))
                if book not in BOOK_NO:
                    raise SystemExit(f'unknown book in tables: {m.group(1)!r}')
                cur_ref = (book, int(m.group(2)), int(m.group(3)))
                cur_rows = []
        if cur_ref:
            cur_rows.append(row)
    flush()
    wb.close()

    os.makedirs(out_dir, exist_ok=True)
    for book, verses in books.items():
        name = book.lower().replace(' ', '_')
        with open(os.path.join(out_dir, f'{name}.json'), 'w',
                  encoding='utf-8') as fh:
            json.dump(verses, fh, ensure_ascii=False, separators=(',', ':'))
    return books


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    txt, xlsx = sys.argv[1], sys.argv[2]
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
    assets = os.path.join(root, 'assets')

    verses = build_text(txt, os.path.join(assets, 'bsb.json'))
    print(f'assets/bsb.json: {len(verses)} verses')

    books = build_tagged(xlsx, os.path.join(assets, 'tagged', 'bsb'))
    tagged = sum(len(v) for v in books.values())
    print(f'assets/tagged/bsb/: {len(books)} books, {tagged} verses tagged')

    for ref in ('Genesis 1:1', 'John 3:16'):
        b, cv = ref.rsplit(' ', 1)
        got = books.get(b, {}).get(cv)
        print(f'\n{ref}: {json.dumps(got, ensure_ascii=False)[:400]}')


if __name__ == '__main__':
    main()
