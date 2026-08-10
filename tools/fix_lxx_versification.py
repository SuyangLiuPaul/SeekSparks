#!/usr/bin/env python3
"""Lift the Septuagint's own verse numbers out of its scripture text.

`assets/lxxwh.json` carries 4,687 markers of the form `(102:12)` — the
edition's own chapter-and-verse for the words that follow, printed
because the Greek Psalter numbers Psalm 103 as 102 and Jeremiah barely
agrees with the Hebrew at all. They were shipping as scripture.

The tagged layer had it worse: the marker was glued onto the FIRST WORD
of the run, so `(102:12) καθ ` carried καθ's Strong's number and parse.
Tapping the marker answered G2596, a preposition.

Both become `<vs:REF>`, the token `ScriptureSpanKind.versification`
parses, and in the tagged layer the marker gets a run of its own with no
Strong's and no grammar.

Idempotent: a file already converted has no `(N:N)` left to match.
"""

import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Every marker in the file is `(digits:digits)` with an optional Greek
# letter for a sub-verse — `(30:28α)`. Verified exact: a scan for any
# parenthesised run at all finds the same 4,687, and no digit anywhere
# in the edition sits outside one. An unaccented Greek text writes its
# own numerals as letters, so a digit cannot be scripture here.
MARKER = re.compile(r'\(\s*(\d+:\d+[α-ω]?)\s*\)\s*')


def convert(text):
    """`(102:12) καθ` -> `<vs:102:12>καθ`. Returns (text, count)."""
    return MARKER.subn(lambda m: '<vs:%s>' % m.group(1), text)


def fix_verses(path):
    with open(path, encoding='utf-8') as f:
        rows = json.load(f)
    total = 0
    verses = 0
    for row in rows:
        text, n = convert(row['text'])
        if n:
            row['text'] = text
            total += n
            verses += 1
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(rows, f, ensure_ascii=False, separators=(',', ':'))
    return total, verses


def fix_tagged(path):
    with open(path, encoding='utf-8') as f:
        refs = json.load(f)
    total = 0
    for ref, runs in refs.items():
        out = []
        for run in runs:
            w = run.get('w', '')
            if not MARKER.search(w):
                out.append(run)
                continue
            # Split into alternating marker / word segments. A marker
            # run carries no Strong's and no grammar — that is the whole
            # point — and the word segments keep the run's own tagging,
            # which is theirs and was never the marker's.
            pos = 0
            for m in MARKER.finditer(w):
                before = w[pos:m.start()]
                if before:
                    out.append(dict(run, w=before))
                out.append({'w': '<vs:%s>' % m.group(1), 's': '',
                            'i': [], 'g': []})
                total += 1
                pos = m.end()
            rest = w[pos:]
            if rest:
                out.append(dict(run, w=rest))
        refs[ref] = out
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(refs, f, ensure_ascii=False, separators=(',', ':'))
    return total


def main():
    verses_path = os.path.join(ROOT, 'assets', 'lxxwh.json')
    n, v = fix_verses(verses_path)
    print('lxxwh.json: %d markers in %d verses' % (n, v))

    tagged = sorted(glob.glob(os.path.join(ROOT, 'assets', 'tagged',
                                           'lxxwh', '*.json')))
    t = sum(fix_tagged(p) for p in tagged)
    print('tagged/lxxwh: %d markers over %d books' % (t, len(tagged)))

    # The two layers are built from the same source and must agree. They
    # do not have to be equal — a verse absent from the tagged layer
    # takes its markers with it — so report rather than assert.
    if t != n:
        print('NOTE: %d markers in the text layer have no tagged '
              'counterpart' % (n - t), file=sys.stderr)


if __name__ == '__main__':
    main()
