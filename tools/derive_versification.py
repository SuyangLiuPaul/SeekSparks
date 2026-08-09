#!/usr/bin/env python3
"""Derive the reader->original verse map, and prove it from the text.

`assets/originals/*.json` is numbered in the ORIGINAL's own versification
-- Masoretic for the Hebrew Bible, the critical text for the Greek. Every
shipped edition, and so every reference a reader ever types, is numbered
in the English tradition. `OriginalsService` joined the two by the
reader's own `"chapter:verse"`, so wherever the two traditions disagree
the Word Study pane showed nothing, or another verse's Hebrew.

Nothing in the output table is asserted from memory. The map is DERIVED
by aligning the original's Strong's-number stream against the same stream
in three independent tagged translations, and a row only ships when all
three agree.

    kjvs        KJV + Strong's        English, Textus Receptus NT
    cuvs-yhwh   和合本雅伟版            Chinese, an unrelated translation
    bsb         Berean Standard Bible  English, critical-text NT

Three translations sharing a numbering mistake is far less likely than
one; and because BSB follows the critical text while KJV follows the
Received Text, their DISAGREEMENTS are informative too -- that is how the
verses absent from the Greek fall out (Matthew 17:21, Mark 9:44 ...).

Method
------
1. Per book and per layer, a banded monotone alignment over verses. The
   two sides carry the same words in the same order and differ only in
   where the verse boundaries fall, so the model is a monotone alignment
   with merge/split beads -- not per-word voting, which has no order
   constraint and left 10% noise when tried.
2. Keep a row only where all three layers produce the same answer.
3. Fill the remainder ONLY by interpolating between two confident
   anchors: same original chapter, same offset on both sides. If the
   interpolated key does not exist in the original, the verse is recorded
   as ABSENT rather than invented -- which is exactly right for the
   Received-Text-only verses.
4. Gate every changed row on the text: the mapped original must resemble
   the reader's verse at least as well as the identity mapping did,
   measured by Dice overlap of Strong's numbers, averaged over the three
   layers. A row that fails is reverted to identity and reported.

Usage:  python3 tools/derive_versification.py [--write]
"""

import collections
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYERS = ('kjvs', 'cuvs-yhwh', 'bsb')
OUT = os.path.join(ROOT, 'assets', 'versification.json')

# Beads the alignment may lay down, as (english verses, original verses).
# (1,2)/(1,3) are merges -- an English verse carrying a Psalm heading plus
# the first line. (2,1) is a split -- Psalm 13:5 and 13:6 both render
# Masoretic 13:6. (1,0)/(0,1) are gaps.
BEADS = ((1, 1), (1, 2), (2, 1), (1, 3), (1, 0), (0, 1))
GAP = -0.30
NON_ONE_TO_ONE = -0.08


def slug(book):
    return book.lower().replace(' ', '_').replace("'", '')


def vkey(key):
    chapter, verse = key.split(':')
    return int(chapter), int(verse)


def load_verses(path):
    """-> ([key...], [frozenset(strongs)...]) in canonical verse order."""
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    keys = sorted(data, key=vkey)
    return keys, [
        frozenset(w['s'] for w in data[k] if w.get('s')) for k in keys
    ]


def dice(a, b):
    if not a or not b:
        return 0.0
    return 2.0 * len(a & b) / (len(a) + len(b))


def _span(sets, i, n):
    out = set()
    for k in range(i, i + n):
        out |= sets[k]
    return out


def align(esets, hsets, band):
    """Banded monotone alignment. -> [(eng_i, de, orig_j, dh), ...]"""
    n, m = len(esets), len(hsets)
    best = [dict() for _ in range(n + 1)]
    back = [dict() for _ in range(n + 1)]
    best[0][0] = 0.0
    for i in range(n + 1):
        for j in list(best[i]):
            base = best[i][j]
            for de, dh in BEADS:
                ni, nj = i + de, j + dh
                if ni > n or nj > m:
                    continue
                if not max(0, ni - band) <= nj <= min(m, ni + band):
                    continue
                if de == 0 or dh == 0:
                    score = GAP
                else:
                    score = dice(_span(esets, i, de), _span(hsets, j, dh))
                    if (de, dh) != (1, 1):
                        score += NON_ONE_TO_ONE
                if base + score > best[ni].get(nj, -1e9):
                    best[ni][nj] = base + score
                    back[ni][nj] = (i, j, de, dh)
    i, j = n, m
    if j not in best[i]:
        return None
    path = []
    while (i, j) != (0, 0):
        pi, pj, de, dh = back[i][j]
        path.append((pi, de, pj, dh))
        i, j = pi, pj
    path.reverse()
    return path


def align_book(orig_path, layer_path):
    okeys, osets = load_verses(orig_path)
    ekeys, esets = load_verses(layer_path)
    path = align(esets, osets, band=25 + abs(len(ekeys) - len(okeys)))
    if path is None:
        return None, None
    mapped = {}
    for ei, de, oj, dh in path:
        for a in range(de):
            mapped.setdefault(ekeys[ei + a], [])
            for c in range(dh):
                mapped[ekeys[ei + a]].append(okeys[oj + c])
    return mapped, dict(zip(ekeys, esets))


def interpolate(book, book_map, ekeys, orig_keys, report):
    """Fill unresolved rows that lie between two anchors agreeing on offset.

    A run of unresolved verses is filled as a whole. Looking only at the
    immediately adjacent key leaves any run of two or more unfilled --
    which left Psalm 8:6-8 and 49:8-9 pointing a verse short, and their
    Masoretic counterparts unreachable from any reference at all.
    """
    resolved = dict(book_map)
    absent = []
    claimed = set()
    for v in resolved.values():
        claimed.update(v)

    def anchor(idx, step):
        """Nearest resolved row in direction [step], as (reader, original).

        A merge is a usable anchor as long as the right EDGE of its span
        is taken: looking back, a reader verse that swallowed a psalm's
        heading ends on the heading's second line, so the next verse
        continues from there. Refusing to anchor on a merge left every
        psalm whose run began at verse 2 unresolved.
        """
        i = idx + step
        while 0 <= i < len(ekeys):
            cand = resolved.get(ekeys[i])
            if cand:
                return ekeys[i], (cand[-1] if step < 0 else cand[0])
            if cand == []:
                return None
            i += step
        return None

    idx = 0
    while idx < len(ekeys):
        if ekeys[idx] in resolved:
            idx += 1
            continue
        end = idx
        while end < len(ekeys) and ekeys[end] not in resolved:
            end += 1
        run = ekeys[idx:end]
        before, after = anchor(idx, -1), anchor(end - 1, 1)
        if not (before and after):
            report['no_anchor'].extend(f'{book} {k}' for k in run)
            idx = end
            continue
        bhc, bhv = vkey(before[1])
        ahc, ahv = vkey(after[1])
        offset = bhv - vkey(before[0])[1]
        if bhc != ahc or offset != ahv - vkey(after[0])[1]:
            # A run that ends a chapter has no anchor after it inside
            # that chapter. Carry the offset forward instead, but only
            # when it CLOSES the chapter exactly: every target must
            # exist, be unclaimed, and the last of them must be the last
            # verse the original has in that chapter. Anything short of
            # that is a guess, and is left alone.
            targets = [f'{bhc}:{vkey(k)[1] + offset}' for k in run]
            last = max(
                (vkey(k)[1] for k in orig_keys if vkey(k)[0] == bhc),
                default=0)
            if (vkey(run[-1])[0] != ahc
                    and all(t in orig_keys for t in targets)
                    and not any(t in claimed for t in targets)
                    and vkey(targets[-1])[1] == last):
                for key, target in zip(run, targets):
                    resolved[key] = [target]
                    claimed.add(target)
                idx = end
                continue

            # The anchors can also disagree because the reader HAS verses
            # the original does not. Neh 7:68 ("their horses, 736") is in
            # the Septuagint and in Ezra 2:66 but not in BHS, so the
            # offset drops by one across it. Recognise that only when the
            # arithmetic closes exactly: the offset falls by precisely
            # the length of the run, and the two anchors are consecutive
            # in the original, so no original verse is being stepped
            # over. Then the run has no counterpart and is reported
            # absent — leaving it at identity would hand the reader the
            # NEXT verse's Hebrew, the very defect this table removes.
            if (bhc == ahc
                    and ahv - vkey(after[0])[1] - offset == -len(run)
                    and ahv == bhv + 1):
                for key in run:
                    resolved[key] = []
                    absent.append(key)
                idx = end
                continue

            report['anchors_disagree'].extend(f'{book} {k}' for k in run)
            idx = end
            continue
        for key in run:
            target = f'{bhc}:{vkey(key)[1] + offset}'
            if target not in orig_keys:
                # The interpolation lands on a verse the original does
                # not have. That is not a numbering difference, it is a
                # verse the critical text omits. Say so rather than
                # inventing a key.
                resolved[key] = []
                absent.append(key)
            elif target in claimed:
                report['would_double_claim'].append(f'{book} {key}')
            else:
                resolved[key] = [target]
                claimed.add(target)
        idx = end
    return resolved, absent


def reader_books():
    """Canonical book names, in canonical order, as the reader knows them."""
    path = os.path.join(ROOT, 'assets', 'kjv.json')
    out = []
    seen = set()
    for rec in json.load(open(path, encoding='utf-8')):
        book = rec['book']
        if book not in seen:
            seen.add(book)
            out.append(book)
    return out


def main():
    books = reader_books()
    report = collections.defaultdict(list)
    table = {}
    absent_all = {}
    stats = collections.Counter()
    support = collections.Counter()

    for book in books:
        s = slug(book)
        opath = os.path.join(ROOT, 'assets', 'originals', f'{s}.json')
        if not os.path.exists(opath):
            continue
        okeys = set(json.load(open(opath, encoding='utf-8')))
        per_layer = {}
        strongs = {}
        for layer in LAYERS:
            lpath = os.path.join(ROOT, 'assets', 'tagged', layer, f'{s}.json')
            if not os.path.exists(lpath):
                continue
            mapped, es = align_book(opath, lpath)
            if mapped is None:
                report['unalignable'].append(f'{book}/{layer}')
                continue
            per_layer[layer] = mapped
            strongs[layer] = es
        if len(per_layer) < 3:
            report['too_few_layers'].append(book)
            continue

        every_key = sorted(
            set().union(*(set(m) for m in per_layer.values())), key=vkey)
        unanimous = {}
        for key in every_key:
            vals = [m.get(key) for m in per_layer.values()]
            if vals[0] is not None and all(v == vals[0] for v in vals):
                unanimous[key] = vals[0]
            else:
                stats['not_unanimous'] += 1
        filled, absent = interpolate(
            book, unanimous, every_key, okeys, report)

        # Gate every change on the text itself.
        orig_words = {
            k: frozenset(w['s'] for w in v if w.get('s'))
            for k, v in json.load(open(opath, encoding='utf-8')).items()
        }
        # Which reader verse each original verse ended up under, so a
        # deletion can be judged by who else claims the verse it gives up.
        claimant = {}
        for reader_key, target in filled.items():
            for t in target:
                claimant.setdefault(t, reader_key)

        def support_for(reader_key, orig_key):
            """Mean Dice between a reader verse and an original one."""
            got = [es[reader_key] for es in strongs.values()
                   if reader_key in es]
            if not got:
                return None
            words = orig_words.get(orig_key, frozenset())
            return sum(dice(ev, words) for ev in got) / len(got)

        changed = {}
        for key, target in filled.items():
            if not target and key in orig_words:
                # The reader has a verse the original does not, and the
                # original's verse of that NUMBER belongs to a later
                # reference. Dice cannot judge this: "we now show
                # nothing" scores 0 against anything, so the ordinary
                # gate would always revert it and restore the wrong
                # Hebrew. The evidence is the rival claim instead —
                # accept the deletion only where the verse that takes
                # this original number resembles it better than the
                # reader verse giving it up.
                rival = claimant.get(key)
                mine = support_for(key, key)
                theirs = support_for(rival, key) if rival else None
                if rival is None or theirs is None or mine is None \
                        or theirs <= mine:
                    support['deletion_reverted'] += 1
                    report['deletion_unsupported'].append(f'{book} {key}')
                    continue
                support['deletion'] += 1
                changed[key] = target
                continue
            if target == [key]:
                continue
            new = set()
            for t in target:
                new |= orig_words.get(t, frozenset())
            old = orig_words.get(key, frozenset())
            scores = []
            for layer, es in strongs.items():
                ev = es.get(key)
                if ev is None:
                    continue
                scores.append((dice(ev, new), dice(ev, old)))
            if not scores:
                support['no_evidence'] += 1
                continue
            new_avg = sum(x for x, _ in scores) / len(scores)
            old_avg = sum(y for _, y in scores) / len(scores)
            if new_avg < old_avg - 1e-9:
                support['degraded_reverted'] += 1
                report['degraded'].append(f'{book} {key} {new_avg:.2f}<{old_avg:.2f}')
                continue
            support['improved' if new_avg > old_avg + 1e-9 else 'equal'] += 1
            changed[key] = target
        if changed:
            table[book] = {k: changed[k] for k in sorted(changed, key=vkey)}
        real_absent = [k for k in absent if k in changed]
        if real_absent:
            absent_all[book] = sorted(real_absent, key=vkey)
        stats['changed'] += len(changed)
        stats['verses'] += len(every_key)

    merges = sum(1 for b in table.values() for v in b.values() if len(v) > 1)
    splits = 0
    for b in table.values():
        seen = collections.Counter()
        for v in b.values():
            for t in v:
                seen[t] += 1
        splits += sum(1 for n in seen.values() if n > 1)
    absent_n = sum(len(v) for v in absent_all.values())

    print(f'books with a difference : {len(table)}')
    print(f'reader verses examined  : {stats["verses"]}')
    print(f'rows that change        : {stats["changed"]}')
    print(f'  of which merges       : {merges}  (one reader verse, several original)')
    print(f'  of which splits       : {splits}  (one original verse, several reader)')
    print(f'  of which absent       : {absent_n}  (no counterpart in the original)')
    print(f'not unanimous           : {stats["not_unanimous"]}')
    print('text support for changed rows:', dict(support))
    for k, v in report.items():
        print(f'  {k}: {len(v)}  {v[:20]}')

    if '--write' in sys.argv:
        payload = {
            'provenance': {
                'derived_by': 'tools/derive_versification.py',
                'method': (
                    'Banded monotone alignment of Strong\'s-number streams '
                    'between assets/originals and three independent tagged '
                    'translations; a row ships only where all three agree, '
                    'or where it interpolates between two anchors that agree '
                    'on offset. Every changed row is gated on Dice overlap '
                    'against the identity mapping.'),
                'layers': list(LAYERS),
                'original': 'assets/originals (OSHB Masoretic / MorphGNT)',
                'reader': 'English chapter-and-verse tradition',
                'rows': stats['changed'],
                'absent': absent_n,
            },
            'map': table,
            'absent': absent_all,
        }
        with open(OUT, 'w', encoding='utf-8') as f:
            json.dump(payload, f, ensure_ascii=False, separators=(',', ':'))
        print(f'wrote {OUT} ({os.path.getsize(OUT)} bytes)')


if __name__ == '__main__':
    main()
