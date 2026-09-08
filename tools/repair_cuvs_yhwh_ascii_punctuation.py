#!/usr/bin/env python3
"""Remove ASCII punctuation and stray spaces that our importer wedged into
`assets/cuvs-yhwh.json`.

WHY THIS IS NOT AN EMENDATION
-----------------------------
和合本雅偉版 is not ours to edit. This script does not decide a reading.
It repairs characters that no Chinese typesetting of any edition can
contain -- a half-width ':' between two Chinese words, a doubled
terminator '.。', a space inside a sentence -- and it repairs them ONLY
where the publisher's own current text, read out of Yahwehdehua's
`app/build/bible.db` (built from `bsapp_bible_cuvs`, the table the
edition is maintained in), differs from ours by nothing else.

That last clause is the whole safety argument, so it is enforced
mechanically rather than promised: a verse is rewritten only when every
single difference between our text and the publisher's falls in
ALLOWED below. One extra word, one different character, and the verse
is skipped and reported. That is what keeps 使徒行傳 26:16 -- where the
publisher's current text reads 「特意向你我显现」 and ours reads
「我特意向你显现」 -- out of this pass. Deciding which of those is right
is the publisher's job, not a repair script's.

Conventions are preserved, not normalised: our `<note: ...>` rendering
of the publisher's 〔...〕, and our `主[基督]` / `主[耶稣]` rendering of
`主#` / `主*`, are this app's. The comparison folds them rather than
overwriting them.

Usage:  tools/repair_cuvs_yhwh_ascii_punctuation.py [--write]
"""
import difflib
import json
import os
import re
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')
DB = os.path.expanduser(
    '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')

# A difference is repairable only if BOTH sides of it are drawn from
# here: the publisher's side is a Chinese mark or nothing, ours is the
# ASCII look-alike or a stray space. Anything else -- a word, a
# different hanzi, a missing 的 -- disqualifies the whole verse.
ALLOWED = {
    ('', ' '),        # a space wedged into Chinese running text
    ('：', ':'), ('；', ';'), ('；', '; '), ('，', ','), ('、', ','),
    ('。', '.'), ('！', '!'), ('！', '! '), ('？', '?'),
    ('', '.'), ('', '!'), ('', '?'), ('', ';'), ('', ','),
    ('', ', '), ('', ': '), ('', '. '), ('', '; '),
    ('”', '"'), ('“', '"'),
    ('（', '('), ('）', ')'),
    ('，', ', '), ('：', ': '), ('。', '. '), ('、', ', '),
    ('', '}'),        # a stray brace, 以斯帖记 8:9
}

# Deliberately NOT here, and the reason is the same for all of them:
# they are real characters, so "no typesetting can contain this" -- the
# argument that licenses everything above -- does not apply, and what
# is left is an editorial judgement that belongs to the publisher.
#
#   复 / 覆     26 verses, all 回复 vs 回覆
#   䍁 / 繸      9 verses (the tassels of 民數記 15)
#   糟 / 蹧      4 verses
#   𨱔 / 鐏      1 verse (撒母耳記下 2:23)
#   暇 / 瑕      1 verse (撒母耳記下 14:25)
#   秸, 列, 都, 上   single words present on one side only
#
# In every one of these the publisher's current text and ours differ in
# a way a reader would notice, and several look like our Traditional
# glyphs leaking into a Simplified file -- but that is a hypothesis, and
# a hypothesis is not a licence to rewrite someone else's Bible. They
# are listed by the script's own report so they can be asked about.


def fold(text):
    """Our rendering -> the publisher's own notation, so the comparison
    is about characters rather than about house style."""
    text = re.sub(r'<note:\s*([^>]*)>',
                  lambda m: '〔' + m.group(1).strip() + '〕', text)
    return text.replace('主[耶稣]', '主*').replace(
        '主[基督]', '主#')


def unfold(text):
    """The publisher's notation -> our rendering."""
    text = text.replace('主*', '主[耶稣]').replace(
        '主#', '主[基督]')
    return re.sub(r'〔([^〕]*)〕',
                  lambda m: '<note: ' + m.group(1) + '>', text)


def main():
    write = '--write' in sys.argv
    con = sqlite3.connect(DB)
    seq = {code: s for s, code in con.execute('select seq, code from books')}
    pub = {'%03d%03d%03d' % (seq[b], c, v): p
           for b, c, v, p in con.execute(
               "select book, chapter, verse, plain from verses "
               "where version='cuvs'")}

    rows = json.load(open(ASSET, encoding='utf-8'))

    # A doubled terminator is the one repair that needs no witness at
    # all: an ASCII '.' sitting immediately in front of a full stop is
    # not a reading, in this edition or any other, and it stays broken
    # otherwise -- 使徒行傳 5:12 carries one in a verse the gate below
    # rightly refuses to touch, because we also print 主[雅伟] there
    # where the publisher's current text has a bare 主. That second
    # difference is theirs to settle; this one is ours to clean, and
    # conflating them would leave the typo in place for as long as the
    # question stays open.
    doubled = 0
    for r in rows:
        fixed = r['text'].replace('.。', '。').replace('.，', '，')
        if fixed != r['text']:
            doubled += r['text'].count('.。') + r['text'].count('.，')
            r['text'] = fixed

    repaired, skipped, marks = 0, [], 0
    for r in rows:
        theirs = pub.get(r['id'])
        if theirs is None:
            continue
        ours = fold(r['text'])
        if ours == theirs:
            continue
        deltas = [(theirs[i1:i2], ours[j1:j2]) for tag, i1, i2, j1, j2
                  in difflib.SequenceMatcher(None, theirs, ours,
                                             autojunk=False).get_opcodes()
                  if tag != 'equal']
        if all(d in ALLOWED for d in deltas):
            r['text'] = unfold(theirs)
            repaired += 1
            marks += len(deltas)
        else:
            skipped.append((r['id'], r['book'], r['chapter'], r['verse'],
                            [d for d in deltas if d not in ALLOWED]))

    print('doubled terminators removed (no witness needed): %d' % doubled)
    print('repairable verses: %d  (%d marks)' % (repaired, marks))
    print('left alone (a real textual difference): %d' % len(skipped))
    for sid, b, c, v, ds in sorted(skipped)[:40]:
        print('  %s %s %s:%s  %s' % (sid, b, c, v, ds[:3]))
    if write:
        with open(ASSET, 'w', encoding='utf-8') as f:
            # No trailing newline and these exact separators: verified
            # to round-trip the untouched file byte for byte, so the
            # diff shows the 203 verses and nothing else.
            json.dump(rows, f, ensure_ascii=False, separators=(',', ':'))
        print('WROTE %s' % ASSET)
    else:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
