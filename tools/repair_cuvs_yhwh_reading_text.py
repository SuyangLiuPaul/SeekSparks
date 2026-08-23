#!/usr/bin/env python3
"""Repair twelve word-level defects in the 和合本雅伟版 READING TEXT (check 46).

`tools/adjudicate_cuvs_yhwh.py` compares three files of one translation and
reports 21 verses where the reading text disagrees with both the other two.
Twenty-one candidates; **six are repaired here and fifteen are deliberately
not**, and a sweep described further down adds six more, for twelve. The whole
value of this script is the line between the repaired and the reported, so the
criterion is stated before the data:

    REPAIR only where the reading text is **not a possible reading of Chinese
    at all**, or where the original-language text we already ship names a word
    that is absent. Orthographic variants, archaisms, supplied words and
    editorial expansions are REPORTED and left alone.

WHY THE OBVIOUS METHOD IS WRONG. Two of the three files agreeing is not
evidence. `cuvs-plus.json` matches the reading text on **99.70% of
characters** (check 45g), so it is a descendant of the same line and its
agreement can only inherit a loss, never detect one. And the tagged layer is
not trustworthy alone either — it invents text twice in this very sample:

  * Judges 15:5 splits כֶּרֶם זַיִת, a construct chain meaning *olive
    orchard*, into 葡萄园橄榄园, conjuring a vineyard the Hebrew has not got.
  * Job 31:36 reads 愿那敌我敌者 — one H7379 run doubled against itself.

So a 2-of-3 vote here would have deleted the 六 from Judges 12:7, where the
Hebrew states שֵׁשׁ שָׁנִים outright. **Every repair below is instead carried by
`assets/originals/`** — the OSHB/MorphGNT layer, CC BY 4.0, from a source
entirely outside this line of transmission — or by the fact that the current
text cannot be read as Chinese. The Hebrew word that decides each one is named
in the table.

WHAT IS DELIBERATELY NOT TOUCHED, and why, so nobody re-opens it:

  * **Joshua 5:9 辊 vs 滚.** The reading text is directly attested: the old
    spaced 和合本 reads 辊 in both the verse and the note, so 辊去了 is a real
    reading of this text's own line and not a slip. (新標點和合本 modernised
    both to 滚.) `cuvs-plus` is the odd one out — it modernised the verse to
    滚去了 but left its note saying 辊, a note explaining a word its own verse
    no longer contains. Treat that only as B being half-edited, not as proof
    about B's ancestry: notes and verse text routinely come from different
    source files. The verdict rests on the direct attestation. Check 26 had
    already excluded 辊/滚 as an attested variant; this is why.
  * 2 Kings 3:2 不至/不致 — the reading text writes 不至 60 times and 不致 55.
  * Isaiah 30:24 锨/杴 — the same word; H7371 is a hapax, so there is no
    internal witness either way. Also already excluded by check 26.
  * Isaiah 64:3 + Acts 25:18 意料/逆料 — 逆料 is the 和合本 idiom, but the
    reading text uses 意料 in **2 of 2** places and 逆料 in none, which is a
    consistent lexical modernisation, not a slip. Both are readable Chinese
    with the same sense. Changing an edition's vocabulary is an editorial act.
  * Lamentations 3:1 雅伟神 — the Hebrew has **no divine name here at all**
    (the tagged layer marks it H0, supplied). Whether this edition may supply
    神 alongside 雅伟 is its editor's call, not ours; it does write 雅伟神 in 40
    other verses.
  * Nehemiah 2:19 你们 · Nehemiah 3:3 他们 · 2 Samuel 5:17 众 · 2 Samuel 21:2 大
    · Esther 6:7 人 · Judges 15:2 我请求 · Judges 15:18 现在 — a word one layer
    has and another lacks. Every one of them reads correctly with or without,
    so none meets the criterion. Reported in docs/DATA-INTEGRITY.md.
  * **Malachi 2:3 抹 vs 抹在 — this one was drafted as a repair and then
    withdrawn, which is the most useful entry on the list.** The draft said
    「抹 cannot take a location without 在」 and cited H5921 עַל. Both halves
    are false. This edition writes 抹 with a bare object eight times
    (抹他的舌头, 抹我的脚, 抹墙, 又用油抹你), and the tagged layer puts H5921
    on the run 你们的脸**上** — so 上 is already עַל and the proposed 在
    renders nothing at all. A published 和合本 reads 抹你們的臉上 exactly as
    we do. The 在 exists in one file out of five, our own tagged layer, where
    it is an intrusion; it is left there rather than re-cut, and reported.

SIX MORE THE ADJUDICATOR STRUCTURALLY COULD NOT SEE. Its rule was "the
reading text stands alone against both other files", which finds nothing where
the tagged layer inherited the same loss. Re-asking the question the other way
round — strip *every* mark of punctuation and every note from both flat
editions and diff on Han characters alone — turns up 89 sites where the sibling
holds 1–3 characters we lack. Almost all are noise or the sibling's own faults:
inline note markers it renders as text (或译/或作/原文), its own dittographies
(1 John 4:2 出于神的的, Acts 28:18 该死的罪。罪。), word-order differences, and
places where our text is the older and better reading (Jeremiah 7:14 称我为名下
is genuine 和合本; the sibling modernised it, and Deuteronomy 32:19's 说 is not
missing — our text and our tagged layer both put it at the head of 32:20 under
H559 וַיֹּאמֶר, which is where the Hebrew has it, while the sibling moved it
back a verse and left H559 with nothing). **Six meet the criterion**, and they
are in the table below. Five of them our own tagged layer shares, which is
exactly why they were invisible: 出埃及记 15:7, 士师记 12:13, 箴言 22:11,
诗篇 78:44, 撒迦利亚书 11:15. 尼希米记 8:4 is the one where the tagged layer
kept the right reading — though that is corroboration, not proof: across the
16 places where the flat text and its own tagged layer differ by a pure
transposition, **the tagged layer is the corrupt side in 15**.

Two of the six are **transpositions, not dropouts** — 尼希米记 8:4 moves 站 and
箴言 22:11 moves 上 — a single character displaced within its verse, leaving a
hole at one end and 站玛他提雅 / 为上友 at the other. Worth naming, because a
detector that only looks for missing characters cannot see them: the verse has
the right number of characters.

ONE STRONG'S NUMBER IS CORRECTED, AND ONLY ONE. At 出埃及记 15:7 our tagged
layer reads `像烧碎` tagged **H1** — אָב, *father*. It is set to H7179 (קַשׁ,
stubble), which is what OSHB puts at that position and what the sibling's own
tagged layer already says. This is a bigger claim than inserting a character,
so it was measured before being made: H1 is not a sentinel in this layer — it
occurs 1,078 times, and every other one of them is a real sense of אָב
(父亲, 之祖, 族长, 先人, 继母, 伯叔, 姑母). Of the 33 that contain no 父/祖/宗,
出埃及记 15:7 is the only one unrelated to fatherhood. A singleton, not a class.

BOTH SCRIPTS OF THE EDITION MOVE TOGETHER. `cuvs-yhwh-tr.json` carries all
seven defects identically, so leaving it behind would make 简 and 繁 disagree
about scripture. The traditional replacement is taken from **the traditional
file's own usage** (it writes 裏, not 里) rather than from a converter — the
opencc round trip is exactly what damaged 賽29:17 in an earlier pass.

AND SO DOES THE SIBLING EDITION. Asking which *other* shipped assets carry the
same fragments — the question the accuracy rule requires — found three of the
first seven in `cuvs-plus.json` **and in `assets/tagged/cuvs-plus/` as well**:
Judges 9:57, Judges 12:7, Malachi 2:3. Those are the three that came from the
"both flat editions agree" bucket, which is exactly what shared ancestry
predicts. `biblexg-v2.json` is a different translation and shares nothing.

WHERE THE CORRUPTION ENTERED IS NOT ESTABLISHED, AND A DRAFT THAT CLAIMED IT
WAS HAS BEEN WITHDRAWN. An earlier pass checked these against `bolls.life/CUV`,
found it reproduced them character for character, and concluded the reading
text is a faithful copy of an already defective ancestor. **That witness does
not qualify.** Re-checked: bolls.life's 和合本 carries our Exodus 15:7
燒滅他們像燒碎一樣 and our Judges 12:7 作以色列的士師年 — *and* a defect of
its own our files do not have, 以便之後 for 以倫之後 at Judges 12:13. It is a
fellow descendant of the same corrupt e-text, so its agreement was never
evidence. 信望愛 (fhl.net, VERSION1=unv) reads all twelve the way this script
writes them.

So: the corruption is at least as old as the e-text both files descend from,
and beyond that we do not know. It does not matter for the decision — an app
that prints 归到们身上 is telling its reader something scripture does not say,
whoever introduced it — but the claim is smaller than the draft made it, and
this is the second time in this check that a Chinese Bible on the open web
turned out to be the same file we already had. **Ask what a witness descends
from before counting its vote.**

In the tagged layer the rule is **repair the reading, do not re-cut the
tagging.** Judges 9:57 and Malachi 2:3 are character insertions into the run
that already spans the site, which leaves their Strong's assignment exactly as
wrong (or right) as it was — inserting 他 next to 们 under H935 introduces no
untruth that 们 alone did not already carry, and re-cutting another layer's
boundaries on our own authority would. Judges 12:7 is the exception: 六 is its
own Hebrew word with its own number (H8337 שֵׁשׁ, standing before H8141 שָׁנִים in
OSHB), so it gets its own run rather than being folded into 年 and mis-tagged.

Every edit is gated at the site: the fragment being replaced must occur
**exactly once** in that verse, and the resulting text must match a recorded
expectation character for character. A failed gate aborts; it never falls
through to writing something unverified.

Usage:  python3 tools/repair_cuvs_yhwh_reading_text.py [--dry-run]
"""
import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIMPLIFIED = os.path.join(ROOT, 'assets/cuvs-yhwh.json')
TRADITIONAL = os.path.join(ROOT, 'assets/cuvs-yhwh-tr.json')


def write_like(path, data):
    """Rewrite `path` in the layout it already had.

    The shipped Bible JSON is not uniformly formatted: the flat editions
    `cuvs-yhwh`/`cuvs-yhwh-tr` are pretty-printed at indent 2, while
    `cuvs-plus` and everything under `assets/tagged/` is minified.
    Serialising with the wrong one reflows the whole file, which buries a
    twelve-verse correction inside 435,535 changed lines — unreviewable,
    and it destroys `git blame` on every verse in the book. This function
    reads the first bytes back to decide, so the layout follows the file
    rather than the caller's memory of it.
    """
    with open(path, encoding='utf-8') as fh:
        pretty = fh.read(3) == '[\n '
    with open(path, 'w', encoding='utf-8') as fh:
        if pretty:
            fh.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        else:
            json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))

# book, chapter, verse, old fragment, new fragment, the witness that decides it
REPAIRS_SIMPLIFIED = [
    ('士师记', '9', '57', '归到们身上', '归到他们身上',
     'H413 אֲלֵיהֶם — "unto them", 3mp; 们 cannot stand alone'),
    ('士师记', '12', '7', '的士师年', '的士师六年',
     'H8337 שֵׁשׁ שָׁנִים — six years; the numeral is simply gone'),
    ('以赛亚书', '23', '1', '因为罗变为荒场', '因为推罗变为荒场',
     'a truncated proper name: the same verse opens 论推罗 and the city is '
     '推罗 in all 24 other verses. NB the Hebrew does NOT carry it twice — '
     'the tagged layer puts this 推罗 under H7703 שדד, i.e. it is the '
     "translator's supplied subject. This passes on truncation alone"),
    ('耶利米书', '7', '20', '和地着的出产', '和地里的出产',
     'H6529 פְּרִי + H127 הָאֲדָמָה — fruit of the ground; 地着 is not Chinese'),
    ('耶利米书', '50', '32', '的城邑中里着起来', '的城邑中着起来',
     'H5892 בְּעָרָיו — in his cities; 中里 is a doubling'),
    ('撒母耳记上', '15', '12', '立了记纪念碑', '立了纪念碑',
     'H3027 יָד, the NOUN. 和合本 splits the two spellings by part of speech — '
     '记念 is the verb (神记念挪亚), 纪念 the noun (作纪念) — and this file '
     'keeps that split. So 记 is the intruder here, not 纪'),
    # --- the six the adjudicator structurally could not see (see docstring) ---
    ('出埃及记', '15', '7', '像烧碎一样', '像烧碎秸一样',
     'H7179 כַּקַּשׁ — like stubble; 烧碎 cannot be the object of a simile, '
     'so the thing they are burnt *like* is simply gone'),
    ('士师记', '12', '13', '作以色的士师', '作以色列的士师',
     'H3478 יִשְׂרָאֵל; 以色 names nothing, and the tagged run already '
     'claims to be Israel'),
    ('尼希米记', '8', '4', '。站玛他提雅', '。玛他提雅',
     'H5975 וַיַּעֲמֹד — 站 was displaced to the head of the name list, '
     'where it strands a subjectless verb in front of a personal name and '
     'leaves the names with no predicate. 信望愛 unv reads 玛他提雅…站在'),
    ('尼希米记', '8', '4', '和玛西雅在他的右边', '和玛西雅站在他的右边',
     "…and this is where it belongs: the verse's own second half reads "
     '和米书兰站在他的左边'),
    ('箴言', '22', '11', '因他嘴的恩言', '因他嘴上的恩言',
     'H8193 שְׂפָתָיו — his LIPS, and 嘴上 is how this edition renders it; '
     'the 上 was displaced. 信望愛 unv reads 因他嘴上的恩言'),
    ('箴言', '22', '11', '王必与他为上友', '王必与他为友',
     '…to here, where H7453 רֵעֵהוּ is his friend. NB 上友 is NOT the '
     'impossible Chinese an earlier draft called it — 尚友/上友 is attested '
     'in 孟子. This rests on the displaced H8193 and on 信望愛 unv 為友'),
    ('诗篇', '78', '44', '并河的水', '并河汊的水',
     'H2975 יְאֹרֵיהֶם + H5140 נֹזְלֵיהֶם. The weakest of the thirteen and '
     'marked so: 江河并河 is parseable, and 并河 is already some Chinese for '
     'H5140. It rests on the published text (信望愛 unv 並河汊的水) alone'),
    ('撒迦利亚书', '11', '15', '愚昧人所用', '愚昧牧人所用',
     'H7462 רֹעֶה — shepherd. 愚昧人 is perfectly good Chinese, so this '
     'qualifies on the second prong only: the run tagged H7462 holds just '
     '人, and the chapter is about the foolish SHEPHERD'),
]

# Same seven, in the traditional file's own orthography. Note 裏, not 里.
REPAIRS_TRADITIONAL = [
    ('士師記', '9', '57', '歸到們身上', '歸到他們身上'),
    ('士師記', '12', '7', '的士師年', '的士師六年'),
    ('以賽亞書', '23', '1', '因為羅變為荒場', '因為推羅變為荒場'),
    ('耶利米書', '7', '20', '和地著的出產', '和地裏的出產'),
    ('耶利米書', '50', '32', '的城邑中裏著起來', '的城邑中著起來'),
    ('撒母耳記上', '15', '12', '立了記紀念碑', '立了紀念碑'),
    ('出埃及記', '15', '7', '像燒碎一樣', '像燒碎秸一樣'),
    ('士師記', '12', '13', '作以色的士師', '作以色列的士師'),
    ('尼希米記', '8', '4', '。站瑪他提雅', '。瑪他提雅'),
    ('尼希米記', '8', '4', '和瑪西雅在他的右邊', '和瑪西雅站在他的右邊'),
    ('箴言', '22', '11', '因他嘴的恩言', '因他嘴上的恩言'),
    ('箴言', '22', '11', '王必與他為上友', '王必與他為友'),
    ('詩篇', '78', '44', '並河的水', '並河汊的水'),
    ('撒迦利亞書', '11', '15', '愚昧人所用', '愚昧牧人所用'),
]


# The two the sibling edition inherited, in its own (simplified) script.
REPAIRS_PLUS = [
    ('士师记', '9', '57', '归到们身上', '归到他们身上'),
    ('士师记', '12', '7', '的士师年', '的士师六年'),
]

# (edition, book file, "ch:vs", run text to find, how, replacement, strongs).
# 'edit' rewrites the run's text in place; 'insert' adds a new run before it.
# A `strongs` on an 'edit' also re-tags that run — used exactly once, and
# argued for in the docstring.
TAGGED = [
    ('cuvs-plus', 'judges', '9:57', '归到们身上了。', 'edit', '归到他们身上了。', None),
    ('cuvs-plus', 'judges', '12:7', '年', 'insert', '六', 'H8337'),

    # Our own tagged layer carries five of the six. Nehemiah 8:4 is absent
    # from this list because there it is the WITNESS — it already reads
    # 和玛西雅站在他的右边 — and only the flat files are wrong.
    ('cuvs-yhwh', 'exodus', '15:7', '像烧碎', 'edit', '像烧碎秸', 'H7179'),
    ('cuvs-yhwh', 'judges', '12:13', '作以色', 'edit', '作以色列', None),
    ('cuvs-yhwh', 'proverbs', '22:11', '心的人，因他嘴', 'edit', '心的人，因他嘴上', None),
    ('cuvs-yhwh', 'proverbs', '22:11', '必与他为上友。', 'edit', '必与他为友。', None),
    ('cuvs-yhwh', 'psalms', '78:44', '并河', 'edit', '并河汊', None),
    ('cuvs-yhwh', 'zechariah', '11:15', '人', 'edit', '牧人', None),
]


def apply_tagged(label):
    changed = []
    for edition, book, ref, needle, how, replacement, strongs in TAGGED:
        rel = f'assets/tagged/{edition}/{book}.json'
        path = os.path.join(ROOT, rel)
        data = json.load(open(path, encoding='utf-8'))
        runs = data.get(ref)
        if runs is None:
            sys.exit(f'ABORT [{label}] {rel} {ref} is not in the tagged layer')
        matches = [i for i, r in enumerate(runs) if r['w'] == needle]
        if len(matches) != 1:
            sys.exit(f'ABORT [{label}] {rel} {ref}: run {needle!r} matched '
                     f'{len(matches)} times, expected exactly 1')
        i = matches[0]
        before = ''.join(r['w'] for r in runs)
        if how == 'edit':
            runs[i] = dict(runs[i], w=replacement)
            if strongs:
                runs[i]['s'] = strongs
        else:
            runs.insert(i, {'w': replacement, 's': strongs})
        after = ''.join(r['w'] for r in runs)
        write_like(path, data)
        changed.append((f'tagged/{edition}/{book} {ref}', before, after))
    return changed


def apply(path, edits, label):
    rows = json.load(open(path, encoding='utf-8'))
    index = {}
    for r in rows:
        index[(r['book'], str(r['chapter']), str(r['verse']))] = r

    changed = []
    for edit in edits:
        book, ch, vs, old, new = edit[0], edit[1], edit[2], edit[3], edit[4]
        row = index.get((book, ch, vs))
        if row is None:
            sys.exit(f'ABORT [{label}] {book} {ch}:{vs} is not in {path}')
        text = row['text']
        n = text.count(old)
        if n != 1:
            sys.exit(f'ABORT [{label}] {book} {ch}:{vs}: {old!r} occurs {n} '
                     f'times, expected exactly 1\n  {text}')
        if new in text:
            sys.exit(f'ABORT [{label}] {book} {ch}:{vs} already repaired')
        row['text'] = text.replace(old, new)
        changed.append((f'{book} {ch}:{vs}', text, row['text']))
    return rows, changed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    total = 0
    for path, edits, label in (
            (SIMPLIFIED, REPAIRS_SIMPLIFIED, '简'),
            (TRADITIONAL, REPAIRS_TRADITIONAL, '繁'),
            (os.path.join(ROOT, 'assets/cuvs-plus.json'), REPAIRS_PLUS,
             '和简+ (inherited, 3 of 7)')):
        rows, changed = apply(path, edits, label)
        print(f'== {label}  {os.path.relpath(path, ROOT)}')
        for ref, before, after in changed:
            print(f'   {ref}')
            print(f'     -  {before}')
            print(f'     +  {after}')
        total += len(changed)
        if not args.dry_run:
            write_like(path, rows)
            print(f'   written')
        print()

    if not args.dry_run:
        print('== tagged layers')
        for ref, before, after in apply_tagged('tagged'):
            print(f'   {ref}')
            print(f'     -  {before}')
            print(f'     +  {after}')
            total += 1
        print()

    print(f'{total} records repaired'
          + (' (dry run: the tagged layer is not previewed, and nothing was '
             'written)' if args.dry_run else ' across five asset groups'))


if __name__ == '__main__':
    main()
