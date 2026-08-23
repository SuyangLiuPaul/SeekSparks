#!/usr/bin/env python3
"""Check 47 — five of the twenty-seven single-character sites check 46 left.

Check 46 read the 34 single-character sites `tools/sweep_flat_dropouts.py`
reports, repaired 7, and left 27 as "judged editorial" — judged, by its own
account, as a residue at the end of a long iteration, with no witness that
could vote. This check gives them a witness and reads them again.

THE WITNESS PROBLEM, AND HOW IT WAS SOLVED. Every 和合本 already in this repo
descends from the same publisher's export, so none of them can testify about a
loss the export already had. `cuvs-plus` agrees with the reading text on 99.70%
of characters (check 45g); the tagged layer, `cuvs-yhwh-tr` and the yahwehdehua
sqlite all reproduce our reading at all 27 sites. **The sqlite in particular is
our parent, not an external witness** — it reads 雅伟 in 申命记 32:19 — which
corrects check 26's description of it as "the first *external* witness".

Two witnesses that do NOT descend from our line were found and measured:

  1. ebible.org `cmn-cu89s` — 新标点和合本, simplified, Public Domain, digitised
     independently (Haiola). Verse-level agreement with our reading text 91.01%,
     character agreement 98.74% — well clear of cuvs-plus's disqualifying 99.70%.
  2. 信望愛 fhl.net `VERSION1=unv`, traditional, the witness check 46 used.

Admissibility was decided by a test, not by provenance alone: **does the witness
reproduce our defects?** Run against the twelve verses check 46 repaired
(`ad3764d`), ebible reads the *repaired* text at eleven and our defect at zero.
The twelfth, 以赛亚书 23:1, differs only because that edition writes 泰尔 for
推罗 — it still supplies the city our text had lost. bolls.life/CUV, by
contrast, reproduced seven of the twelve, which is what a descendant looks like.

THE HYPOTHESIS THAT NEARLY SANK THIS CHECK. Our edition is demonstrably an
*older* CUV recension than ebible's: 约但/约旦 is 200/1 in ours and 3/198 in
ebible; 推罗/泰尔 is 63/0 and 0/64. If the 27 sites were differences of that
kind, repairing them would falsify our edition rather than mend it. The
discriminator is that a recension difference is **systematic** (200 against 198)
and a transmission loss is a **singleton**. Every one of the fuller readings
below is already attested in our own text — 弟兄们 139 times, 心里 435, 因他们
92, 称为我名下 11 — and the site is the only place it is not written. That test
also *saved* several sites: ebible itself writes 约瑟手下 without 的 at 创世纪
39:23 one verse after writing it with 的 at 39:22, so that 的 is free variation
and 39:22 is left alone.

WHAT IS REPAIRED, AND ON WHAT. Three of the five need no external witness at
all — our own corpus contradicts itself:

  耶利米书 7:14  称我为名下 → 称为我名下. 耶利米书 7:10, 7:11 and 7:30 — the
      same chapter, the same temple — all read 称为我名下的殿. 称我为名下 is
      not Chinese and appears once in 31,102 verses.
  诗篇 102:26  天地就改变了 → 天地就都改变了. 希伯来书 1:12 quotes this verse
      and our own copy of the quotation reads 天地就都改变了. Two copies of one
      rendering, one of them short.
  约翰一书 4:2  成了肉身来 → 成了肉身来的. 约翰二书 1:7 carries the identical
      confession, 认耶稣基督是成了肉身来的, intact. Without 的 the 认…是…的
      frame has no nominaliser and 来 dangles.

Two more are impossible Chinese, and both witnesses supply the reading:

  使徒行传 26:16  特意向你我显现 → 我特意向你显现. 向你我 has no parse and the
      clause is left with no subject.
  俄巴底亚书 1:5  若到来你那里 → 若来到你那里. 到来 is intransitive and cannot
      govern 你那里; the same verse's first half already reads 若来在你那里.

WHAT IS NOT REPAIRED. Six of the 27 are the sweep's own false positives and are
now proved so: 申命记 5:5, 申命记 32:19 and 马可福音 1:24 are verse-boundary
placement — our *next* verse begins with the 说 the sibling puts at the end of
this one — and 创世纪 47:9, 那鸿书 3:8 and 使徒行传 28:18 are corruption in
cuvs-plus, where both external witnesses read exactly as we do.

The remaining sixteen are left deliberately. At each of them two independent
witnesses do supply a character our text lacks, but our reading is grammatical
and says the same thing (交在约瑟手下, 一场大的哀哭, 凡犯悖逆的, 在你前面/面前
吹号). §26's rule is that a witness supplies a reading; it does not vote on
whether the site is broken. Sixteen verses of shipped scripture are not worth
rewriting on witnesses whose independence *from each other* this check had no
way to measure — both may be 新标点和合本 digitisations, in which case their
agreement is one vote and not two. They are listed in DATA-INTEGRITY §47c with
the evidence attached, which is the state a human can act on.

IN THE TAGGED LAYER the rule is check 46's: repair the reading, do not re-cut
the tagging. Four of the five are character moves inside runs that already span
the site, and each happens to *improve* the Strong's fit — 为 moves from H8034
שֵׁם (name) to H7121 קרא (call) so that 称为/我名下 divide as the Hebrew does,
and 到 moves from H518 אִם (if) to H935 בּוֹא (come). 使徒行传 26:16 is the
exception and is argued rather than assumed: 我 has to cross a run boundary, and
folding it into the G5124 run would tag it τοῦτο, which is a new untruth. It
becomes its own run with an empty Strong's number, claiming nothing — the honest
statement, since the pronoun is carried by the person of ὤφθην and not by a
separate Greek word. 240 mid-verse runs in this layer already have an empty `s`.

Every edit is gated at the site: the fragment must occur **exactly once** in the
verse, the replacement must not already be present, and after the tagged runs
are rewritten they must concatenate character for character to the repaired flat
text. A failed gate aborts; it never falls through to writing something
unverified.

Usage:  python3 tools/repair_cuvs_yhwh_check47.py [--dry-run]
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

    The flat editions are pretty-printed at indent 2; everything under
    `assets/tagged/` is minified. Serialising with the wrong one reflows the
    file and buries the correction in hundreds of thousands of changed lines.
    """
    with open(path, encoding='utf-8') as fh:
        pretty = fh.read(3) == '[\n '
    with open(path, 'w', encoding='utf-8') as fh:
        if pretty:
            fh.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        else:
            json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))


# book, chapter, verse, old fragment, new fragment, what decides it
REPAIRS_SIMPLIFIED = [
    ('耶利米书', '7', '14', '称我为名下', '称为我名下',
     'H7121 קרא + H8034 שֵׁם. 耶利米书 7:10, 7:11 and 7:30 read 称为我名下的殿 '
     'of this same temple; 称为我名下 occurs 11 times in this file and '
     '称我为名下 once'),
    ('诗篇', '102', '26', '天地就改变了', '天地就都改变了',
     'H2498 חלף. 希伯来书 1:12 quotes this verse and our own copy of the '
     'quotation reads 天地就都改变了 — the same rendering, intact'),
    ('约翰一书', '4', '2', '肉身来，就是', '肉身来的，就是',
     'G2064 ἐληλυθότα, a perfect participle. 约翰二书 1:7 carries the identical '
     'confession 认耶稣基督是成了肉身来的; without 的 the 认…是…的 frame has no '
     'nominaliser'),
    ('使徒行传', '26', '16', '站着，特意向你我显现', '站着，我特意向你显现',
     'G3700 ὤφθην, 1st person. 向你我 has no parse and the clause is left with '
     'no subject; both external witnesses read 我特意向你显现'),
    ('俄巴底亚书', '1', '5', '的若到来你那里', '的若来到你那里',
     'H935 בּוֹא. 到来 is intransitive and cannot govern 你那里; this verse\'s '
     'own first half already reads 盗贼若来在你那里'),
]

# The same five in the traditional file's own orthography. It writes 裏.
REPAIRS_TRADITIONAL = [
    ('耶利米書', '7', '14', '稱我為名下', '稱為我名下'),
    ('詩篇', '102', '26', '天地就改變了', '天地就都改變了'),
    ('約翰一書', '4', '2', '肉身來，就是', '肉身來的，就是'),
    ('使徒行傳', '26', '16', '站著，特意向你我顯現', '站著，我特意向你顯現'),
    ('俄巴底亞書', '1', '5', '的若到來你那裏', '的若來到你那裏'),
]

# (book file, "ch:vs", run text, how many runs carry it, which one (1-based),
#  how, replacement, strongs). 'edit' rewrites that run's text; 'insert' adds a
# new run before it. `expect`/`which` exist because 俄巴底亚书 1:5 legitimately
# has two runs reading 来 and the edit belongs to the second.
TAGGED = [
    ('jeremiah', '7:14', '所以我要向这称', 1, 1, 'edit', '所以我要向这称为', None),
    ('jeremiah', '7:14', '我为名下、', 1, 1, 'edit', '我名下、', None),
    ('psalms', '102:26', '天地就改变', 1, 1, 'edit', '天地就都改变', None),
    ('1_john', '4:2', '来，', 1, 1, 'edit', '来的，', None),
    ('acts', '26:16', '我显现，', 1, 1, 'edit', '显现，', None),
    ('acts', '26:16', '特意', 1, 1, 'insert', '我', ''),
    ('obadiah', '1:5', '若到', 1, 1, 'edit', '若', None),
    ('obadiah', '1:5', '来', 2, 2, 'edit', '来到', None),
]

# What each touched tagged verse must read once every edit above has landed.
TAGGED_EXPECTED = {
    ('jeremiah', '7:14'),
    ('psalms', '102:26'),
    ('1_john', '4:2'),
    ('acts', '26:16'),
    ('obadiah', '1:5'),
}

# tagged book file -> the Chinese book name in the flat simplified edition
TAGGED_BOOK = {
    'jeremiah': '耶利米书',
    'psalms': '诗篇',
    '1_john': '约翰一书',
    'acts': '使徒行传',
    'obadiah': '俄巴底亚书',
}


def apply(path, edits, label):
    rows = json.load(open(path, encoding='utf-8'))
    index = {(r['book'], str(r['chapter']), str(r['verse'])): r for r in rows}

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


def apply_tagged(simplified_rows):
    """Rewrite the tagged runs, then prove they still spell the flat verse."""
    flat = {(r['book'], str(r['chapter']), str(r['verse'])): r['text']
            for r in simplified_rows}
    loaded, before = {}, {}
    for book, ref, needle, expect, which, how, replacement, strongs in TAGGED:
        rel = f'assets/tagged/cuvs-yhwh/{book}.json'
        if book not in loaded:
            loaded[book] = json.load(open(os.path.join(ROOT, rel),
                                          encoding='utf-8'))
        runs = loaded[book].get(ref)
        if runs is None:
            sys.exit(f'ABORT [tagged] {rel} {ref} is not in the tagged layer')
        before.setdefault((book, ref), ''.join(r['w'] for r in runs))
        matches = [i for i, r in enumerate(runs) if r['w'] == needle]
        if len(matches) != expect:
            sys.exit(f'ABORT [tagged] {rel} {ref}: run {needle!r} matched '
                     f'{len(matches)} times, expected {expect}')
        i = matches[which - 1]
        if how == 'edit':
            runs[i] = dict(runs[i], w=replacement)
            if strongs:
                runs[i]['s'] = strongs
        else:
            runs.insert(i, {'w': replacement, 's': strongs})

    changed = []
    for book, ref in sorted(TAGGED_EXPECTED):
        runs = loaded[book][ref]
        after = ''.join(r['w'] for r in runs)
        want = flat[(TAGGED_BOOK[book], *ref.split(':'))]
        if after != want:
            sys.exit(f'ABORT [tagged] cuvs-yhwh/{book} {ref} does not spell '
                     f'the repaired verse\n  runs {after!r}\n  flat {want!r}')
        changed.append((f'tagged/cuvs-yhwh/{book} {ref}',
                        before[(book, ref)], after))

    for book, data in loaded.items():
        write_like(os.path.join(ROOT, f'assets/tagged/cuvs-yhwh/{book}.json'),
                   data)
    return changed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    total = 0
    simplified_rows = None
    for path, edits, label in ((SIMPLIFIED, REPAIRS_SIMPLIFIED, '简'),
                               (TRADITIONAL, REPAIRS_TRADITIONAL, '繁')):
        rows, changed = apply(path, edits, label)
        if path == SIMPLIFIED:
            simplified_rows = rows
        print(f'== {label}  {os.path.relpath(path, ROOT)}')
        for ref, was, now in changed:
            print(f'   {ref}\n     -  {was}\n     +  {now}')
        total += len(changed)
        if not args.dry_run:
            write_like(path, rows)
            print('   written')
        print()

    if not args.dry_run:
        print('== tagged layer')
        for ref, was, now in apply_tagged(simplified_rows):
            print(f'   {ref}\n     -  {was}\n     +  {now}')
            total += 1
        print()

    print(f'{total} records repaired'
          + (' (dry run: the tagged layer is not previewed, and nothing was '
             'written)' if args.dry_run else ' across three asset groups'))


if __name__ == '__main__':
    main()
