#!/usr/bin/env python3
"""Compare this repo's 和合本雅偉版 繁體 with the official one, both ways.

2026-09-14. The question behind it was 「是不是最新的」, and the answer
turned out not to be a direction. There has never been a Traditional
master for this edition — the owner's own archive says so: 「繁体从来没有
人给过母本，是用 订正表与转换表/tc/ 转出来再逐节校的」. Both sides convert
the same Simplified text; they are two conversions, not an original and a
copy, and each has cases the other has not met.

THE ANCHOR. Where the two disagree at a Han character, the Simplified
verse is the witness: it is what both sides converted FROM. A conversion
that changed a character the other left alone has made a claim, and the
claim is checkable.

  * **We over-converted** where our 繁 differs from our own 简 and theirs
    matches it. 占卜 became 占蔔 — the radish of 蘿蔔 — 41 times; 制伏
    became 製伏 91 times; 借什么 became 藉什麽 199 times in the law about
    BORROWING (出埃及記 22:14); 凌辱 became 淩辱; 沉睡 became 沈睡.
  * **They over-converted** where theirs differs from the Simplified and
    ours matches. 准許 became 準許 (准 permits, 準 is accurate), 指證
    became 指証, 會堂裡 became 會堂里, and 乾瘦 — 創世記 41's lean cows —
    became 幹瘦.

Everything else in the list is a glyph-form house difference: 説/說,
着/著, 衞/衛, 户/戶, 羣/群, 卧/臥. Both forms are real Traditional and
neither is an error; they are reported and nothing is done about them,
because that is a decision about a house style and not about a word.

This script writes nothing. It produces the table to send.

Usage:
    tools/audit_cuv_tr_against_official.py [--report <path>] [--repo <p>]
"""
import json
import os
import re
import sqlite3
import sys
from collections import Counter

DB = os.path.expanduser(
    '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')
NOTE_APP = re.compile(r'<note:[^>]*>')
NOTE_DB = re.compile(r'〔[^〕]*〕')
MARK = re.compile(r'主\[(?:雅伟|雅偉|基督|耶稣|耶穌)\]')


def clean(text, from_db):
    return MARK.sub('主', (NOTE_DB if from_db else NOTE_APP).sub('', text))


def han(ch):
    return '㐀' <= ch <= '鿿'


def main():
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])
    report = None
    if '--report' in sys.argv:
        report = sys.argv[sys.argv.index('--report') + 1]

    con = sqlite3.connect('file:%s?mode=ro' % DB, uri=True)
    seq = {c: s for s, c in con.execute('select seq, code from books')}
    names = {c: n for c, n in con.execute('select code, name_en from books')}
    official = {}
    for b, c, v, p in con.execute(
            "select book, chapter, verse, plain from verses where version='cuvt'"):
        official['%03d%03d%03d' % (seq[b], c, v)] = (p, names[b], c, v)

    A = lambda n: os.path.join(repo, 'assets', n)
    ours_t = {r['id']: r['text']
              for r in json.load(open(A('cuvs-yhwh-tr.json'), encoding='utf-8'))}
    ours_s = {r['id']: r['text']
              for r in json.load(open(A('cuvs-yhwh.json'), encoding='utf-8'))}

    we_moved, they_moved, style = Counter(), Counter(), Counter()
    where = {}
    for vid, ours in ours_t.items():
        rec = official.get(vid)
        if rec is None:
            continue
        theirs, book, ch, vs = rec
        a, t = clean(ours, False), clean(theirs, True)
        s = clean(ours_s.get(vid, ''), False)
        if not (len(a) == len(t) == len(s)):
            continue
        for i, (x, y, z) in enumerate(zip(a, t, s)):
            if x == y or not (han(x) and han(y)):
                continue
            key = (z, x, y)  # simplified, ours, theirs
            ctx = (book, ch, vs, s[max(0, i - 4):i + 3],
                   a[max(0, i - 4):i + 3], t[max(0, i - 4):i + 3])
            if z == y:
                we_moved[key] += 1
            elif z == x:
                they_moved[key] += 1
            else:
                style[key] += 1
            where.setdefault(key, ctx)

    def table(counter, title, subject):
        out = ['## %s' % title, '']
        out.append('| 简体 | 我们作 | 他们作 | 次数 | 例 |')
        out.append('|---|---|---|---|---|')
        for (z, x, y), n in counter.most_common():
            b, c, v, cs, ca, ct = where[(z, x, y)]
            out.append('| %s | %s | %s | %d | %s %d:%d　简 %s ／ 我们 %s ／ 他们 %s |'
                       % (z, x, y, n, b, c, v, cs, ca, ct))
        out.append('')
        return out

    print('we converted, they did not : %d classes, %d positions'
          % (len(we_moved), sum(we_moved.values())))
    print('they converted, we did not : %d classes, %d positions'
          % (len(they_moved), sum(they_moved.values())))
    print('both moved, differently    : %d classes, %d positions'
          % (len(style), sum(style.values())))

    if report:
        doc = ['# 和合本雅偉版 繁體 — 两个转换的对照', '',
               '2026-09-14。', '',
               '这不是「谁比较新」的问题。这个译本**从来没有繁体母本**，',
               '两边都是从同一份简体转出来的，所以是两个转换在互相对照，',
               '不是原件和抄件。简体是证人：两边在哪个字上分歧，就看那个字',
               '在简体里本来是什么。', '']
        doc += table(we_moved, '一、我们转了，他们没转（简体保持原字）',
                     'ours')
        doc += ['这一类里明显是我们错的：占卜→占蔔（蔔是萝卜的蔔）、',
                '制伏→製伏（製是製造）、借→藉（出埃及记 22:14 讲的是借贷）、',
                '凌辱→淩辱、沉睡→沈睡。', '']
        doc += table(they_moved, '二、他们转了，我们没转（简体保持原字）',
                     'theirs')
        doc += ['这一类里明显是他们错的：准許→準許（准是允许，準是准确）、',
                '指證→指証、會堂裡→會堂里、乾瘦→幹瘦（创世记 41 的瘦母牛）。', '']
        doc += table(style, '三、两边都转了，但转成不同的字形', 'style')
        doc += ['这一类多半不是对错，是字形习惯：説／說、着／著、衞／衛、',
                '户／戶、羣／群、卧／臥。两种都是真的繁体字。', '']
        open(report, 'w', encoding='utf-8').write('\n'.join(doc) + '\n')
        print('REPORT %s' % report)


if __name__ == '__main__':
    main()
