#!/usr/bin/env python3
"""Put the second half of 馬可福音 9:43 and 9:45 back where it belongs.

`assets/cuvs-plus.json` is 和合本简体+ — the same Union Version base as
`assets/cuvs-yhwh.json`, differing only in how the edition prints the
translators' notes (inline in （）rather than wrapped in `<note: …>`).
At two places it does not differ in notes at all; it differs in where a
verse ends.

    9:43  倘若你一只手叫你跌倒，就把它砍下来；
    9:44  你缺了肢体进入永生，强如有两只手落到地狱，入那不灭的火里去。

Both lines are verse 43. The KJV settles it — "if thy hand offend thee,
cut it off: it is better for thee to enter into life maimed, than having
two hands to go into hell" is one verse — and so do the two sibling
和合本 editions, which hold the whole sentence at 9:43 and print the
disputed verse 44 as a note. 9:45/9:46 carries the identical split.

Why it matters more than a misplaced clause usually would: reference
9:44 is one of the sixteen verses the critical text does not contain, so
in every other edition we ship it holds a note, an `OMIT`, or nothing.
和简+ was the one edition answering 馬可福音 9:44 with scripture — words
that are real, that no other edition puts there, and that a reader could
quote as verse 44 on our authority alone. `assets/tagged/cuvs-plus/
mark.json` carries the same split, so Word Study, search, KWIC and the
concordance all agreed with it.

Found by `tools/audit_verse_alignment.py` (docs/DATA-INTEGRITY.md check
20), which compares each reference against its neighbours in the other
editions of the same language — the only check that can see an error
that leaves the key set intact.

What this script does NOT do: fill 9:44 and 9:46 back in. The words the
siblings print there are *their* editorial note, in *their* house style,
and 和简+ states such things differently (「（有古卷无此节）」 against
`<note: 有古卷无此节>`). Copying one would be putting a sentence in this
edition's mouth. The records are kept, emptied, and left to
`VerseAbsence.blank`, which renders 「本版本此处没有经文」 — true, and
the conservative reading of a slot whose real contents we do not have.

Guarded on the exact text it expects and on the sibling edition
agreeing, and skips when the file already carries the result.

Usage: tools/repair_cuvs_plus_mark.py [--write]
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEXT = os.path.join(ROOT, 'assets', 'cuvs-plus.json')
TAGGED = os.path.join(ROOT, 'assets', 'tagged', 'cuvs-plus', 'mark.json')
SIBLING = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')

BOOK = '马可福音'

# (head verse, stray verse, text stored at each). Verbatim from the
# shipped file; a byte of drift means this script must not run.
SPLITS = [
    (
        43, 44,
        '倘若你一只手叫你跌倒，就把它砍下来；',
        '你缺了肢体进入永生，强如有两只手落到地狱，入那不灭的火里去。',
    ),
    (
        45, 46,
        '倘若你一只脚叫你跌倒，就把它砍下来；',
        '你瘸腿进入永生，强如有两只脚被丢在地狱里。',
    ),
]


class Skipped(Exception):
    """The file does not hold what this repair expects — leave it alone."""


def write_like(path, original, data):
    """Re-serialises [data] in whatever layout [original] used."""
    indented = original.startswith('[\n') or original.startswith('{\n')
    if indented:
        text = json.dumps(data, ensure_ascii=False, indent=2)
    else:
        text = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    if original.endswith('\n'):
        text += '\n'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def find(verses, chapter, verse):
    return [
        i for i, r in enumerate(verses)
        if r['book'] == BOOK
        and str(r['chapter']) == str(chapter)
        and str(r['verse']) == str(verse)
    ]


def one(verses, chapter, verse):
    hits = find(verses, chapter, verse)
    if len(hits) != 1:
        raise Skipped('%s %s:%s is %d records, expected 1'
                      % (BOOK, chapter, verse, len(hits)))
    return hits[0]


def sibling_text(chapter, verse):
    with open(SIBLING, encoding='utf-8') as f:
        for r in json.load(f):
            if (r['book'] == BOOK and str(r['chapter']) == str(chapter)
                    and str(r['verse']) == str(verse)):
                return r['text']
    raise Skipped('cuvs-yhwh has no %s %s:%s' % (BOOK, chapter, verse))


def runs_text(runs):
    return ''.join(r['w'] for r in runs)


def repair_split(verses, tagged, head_no, stray_no, head, tail, log):
    """Move [tail] out of 9:[stray_no] and back onto the end of 9:[head_no]."""
    whole = head + tail
    at_head = one(verses, 9, head_no)
    at_stray = one(verses, 9, stray_no)
    if verses[at_head]['text'] == whole and not verses[at_stray]['text']:
        return 0
    if verses[at_head]['text'] != head:
        raise Skipped('%s 9:%d is not the head half' % (BOOK, head_no))
    if verses[at_stray]['text'] != tail:
        raise Skipped('%s 9:%d is not the stray half' % (BOOK, stray_no))
    if at_stray != at_head + 1:
        raise Skipped('%s 9:%d does not follow 9:%d' % (BOOK, stray_no,
                                                        head_no))

    # Independent witness: the sibling 和合本 holds the whole sentence at
    # the head reference. Same base text, same script — unlike the two
    # 梁家鏗譯本 files, these two agree word for word here — so a
    # mismatch means the premise of this repair has moved.
    witness = sibling_text(9, head_no)
    if witness != whole:
        raise Skipped('cuvs-yhwh %s 9:%d is not the rejoined sentence'
                      % (BOOK, head_no))

    head_key, stray_key = '9:%d' % head_no, '9:%d' % stray_no
    if head_key not in tagged or stray_key not in tagged:
        raise Skipped('tagged mark.json is missing %s or %s'
                      % (head_key, stray_key))
    if runs_text(tagged[head_key]) != head:
        raise Skipped('tagged %s does not spell the head half' % head_key)
    if runs_text(tagged[stray_key]) != tail:
        raise Skipped('tagged %s does not spell the stray half' % stray_key)

    verses[at_head] = dict(verses[at_head], text=whole)
    verses[at_stray] = dict(verses[at_stray], text='')
    tagged[head_key] = tagged[head_key] + tagged[stray_key]
    del tagged[stray_key]
    log('  %s 9:%d rejoined (%d chars moved back from 9:%d); 9:%d emptied, '
        'tagged runs merged' % (BOOK, head_no, len(tail), stray_no, stray_no))
    return 1


def main():
    write = '--write' in sys.argv
    if not write:
        print('dry run — pass --write to save\n')

    with open(TEXT, encoding='utf-8') as f:
        text_raw = f.read()
    verses = json.loads(text_raw)
    with open(TAGGED, encoding='utf-8') as f:
        tagged_raw = f.read()
    tagged = json.loads(tagged_raw)

    print('cuvs-plus.json (%d records), tagged/cuvs-plus/mark.json (%d refs)'
          % (len(verses), len(tagged)))
    lines = []
    skipped = 0
    for head_no, stray_no, head, tail in SPLITS:
        name = '%s 9:%d split across 9:%d/9:%d' % (BOOK, head_no, head_no,
                                                   stray_no)
        try:
            made = repair_split(verses, tagged, head_no, stray_no, head, tail,
                                lines.append)
        except Skipped as why:
            print('  SKIP %s — %s' % (name, why))
            skipped += 1
            continue
        if made == 0:
            print('  ok   %s — already applied' % name)
    for line in lines:
        print(line)

    # The tagged layer describes words. Every reference that has words
    # must have runs, and no reference may have runs without words.
    marks = {'%s:%s' % (r['chapter'], r['verse']): r['text']
             for r in verses if r['book'] == BOOK}
    worded = {k for k, t in marks.items() if t.strip()}
    if worded != set(tagged):
        print('  REFUSING TO WRITE — tagged keys no longer match the '
              'text-bearing references: %s'
              % sorted(worded.symmetric_difference(set(tagged)))[:8])
        return 1
    if len(verses) != len(json.loads(text_raw)):
        print('  REFUSING TO WRITE — record count moved')
        return 1

    changed = (verses != json.loads(text_raw)
               or tagged != json.loads(tagged_raw))
    if write and changed:
        write_like(TEXT, text_raw, verses)
        write_like(TAGGED, tagged_raw, tagged)
        print('  written')
    elif write:
        print('  unchanged, not written')
    return 1 if skipped else 0


if __name__ == '__main__':
    sys.exit(main())
