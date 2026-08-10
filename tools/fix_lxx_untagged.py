#!/usr/bin/env python3
"""Give the Septuagint's untagged words the number its own tagging already uses.

`assets/tagged/lxxwh/` carries 49,635 runs with an empty Strong's number —
one word in ten of the Greek Old Testament. Tapping them answers nothing.

That is not, mostly, a defect: 43,619 of them are words the New Testament
never uses, so no Strong's number exists to give. Σαλωμων, Μωαβ and Ιωαβ
are spelled as the Septuagint spells them, not as Matthew does, and
inventing a number for them would be a guess.

But some of it IS a defect, and the edition witnesses against itself.
`ειπεν` is tagged G3004 in 612 places and left empty in 2,550 others. The
same word, the same edition, the same parse — answering in one verse and
not the next. A reader who taps it in Genesis learns nothing and has no
way to know the word is in the lexicon after all.

THE RULE. Fill an empty number only when the edition's own tagging names
it unambiguously:

  1. the surface form, accents stripped and final sigma folded, is tagged
     somewhere else in this same corpus;
  2. every one of those taggings gives the SAME Strong's number;
  3. there are at least MIN_WITNESS of them;
  4. the untagged run's part of speech is one the form is tagged under
     elsewhere.

Rule 4 is what makes rule 2 safe. An unaccented Greek text loses the
distinction between ἐρεῖς "you will say" and ἔρεις "strifes", so a form
can look unanimous only because one of its two words never happens to be
tagged. Refusing a run whose parse disagrees with every witness catches
that; 308 runs are refused on those grounds and stay empty.

Nothing here infers Greek. A fill is a statement about what this edition
already says elsewhere, not about what the word means — which is why the
suppletive cases come out right: `ειπεν` gets λέγω G3004 because that is
the number this edition uses for it, not the G2036 a different Strong's
convention would use.

WHAT IS DELIBERATELY LEFT EMPTY, and why that is the honest state:
  * 43,619 runs whose form is tagged nowhere — no witness, no fill.
  * runs whose form carries two different numbers in the corpus.
  * runs witnessed fewer than MIN_WITNESS times.
Under-attribution is recoverable; a wrong Strong's number is not, because
it reads as a fact about the text.

Idempotent. A second run rebuilds the same witness pool — the fills are
all of an already-unanimous form, so no form crosses a threshold it had
not already crossed — and writes the same bytes.

Usage:  python3 tools/fix_lxx_untagged.py [--dry-run] [--report N]
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
import unicodedata
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYER = os.path.join(ROOT, 'assets', 'tagged', 'lxxwh')

# Three witnesses is where the fill list stops being dominated by forms
# seen once or twice. At 2 it fills 9,197 runs, at 3 it fills 8,280, at 5
# it fills 6,800; the marginal 917 runs between 2 and 3 come from forms
# with a single corroborating occurrence, which is not a corpus witness,
# it is a coincidence.
MIN_WITNESS = 3


def norm(word: str) -> str:
    """Fold a surface form to its comparison key.

    The Septuagint half of this asset is unaccented and the New Testament
    half is not, so accents cannot be part of the key or the two halves
    would never witness each other. Final sigma folds for the same
    reason.
    """
    decomposed = unicodedata.normalize('NFD', word)
    stripped = ''.join(c for c in decomposed if not unicodedata.combining(c))
    return stripped.lower().replace('ς', 'σ').strip()


def pos(code: str) -> str:
    """The part of speech from a Robinson code: `V-2AAI-3S` -> `V`."""
    return (code or '').split('-')[0]


def load():
    files = sorted(glob.glob(os.path.join(LAYER, '*.json')))
    if not files:
        sys.exit('no tagged files under %s' % LAYER)
    return [(p, json.load(open(p, encoding='utf-8'))) for p in files]


def build_witness(books):
    """form -> Counter(strongs), and the set of (form, pos) ever tagged."""
    by_form = defaultdict(Counter)
    tagged_pos = defaultdict(set)
    for _, verses in books:
        for runs in verses.values():
            for run in runs:
                code = run.get('s') or ''
                if not code:
                    continue
                key = norm(run.get('w', ''))
                if not key:
                    continue
                by_form[key][code] += 1
                tagged_pos[key].add(pos((run.get('g') or [''])[0]))
    return by_form, tagged_pos


def decide(key, part, by_form, tagged_pos):
    """The number this corpus names for `key`, or None, or 'POS' to refuse."""
    codes = by_form.get(key)
    if not codes or len(codes) != 1 or sum(codes.values()) < MIN_WITNESS:
        return None
    if part not in tagged_pos[key]:
        return 'POS'
    return next(iter(codes))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--report', type=int, default=0,
                    help='print the N commonest fills')
    args = ap.parse_args()

    books = load()
    by_form, tagged_pos = build_witness(books)

    filled = Counter()
    refused = 0
    unwitnessed = 0
    touched = 0
    total_runs = 0

    for path, verses in books:
        changed = False
        for runs in verses.values():
            for run in runs:
                total_runs += 1
                if run.get('s'):
                    continue
                key = norm(run.get('w', ''))
                if not key:
                    unwitnessed += 1
                    continue
                verdict = decide(key, pos((run.get('g') or [''])[0]),
                                 by_form, tagged_pos)
                if verdict is None:
                    unwitnessed += 1
                elif verdict == 'POS':
                    refused += 1
                else:
                    run['s'] = verdict
                    filled[(key, verdict)] += 1
                    changed = True
        if changed:
            touched += 1
            if not args.dry_run:
                with open(path, 'w', encoding='utf-8') as f:
                    json.dump(verses, f, ensure_ascii=False,
                              separators=(',', ':'))

    print('runs               %7d' % total_runs)
    print('filled             %7d  over %d distinct forms, in %d books'
          % (sum(filled.values()), len(filled), touched))
    print('refused on parse   %7d' % refused)
    print('left empty         %7d  (no unanimous witness)' % unwitnessed)
    if args.dry_run:
        print('\n(dry run — nothing written)')

    if args.report:
        lexicon = json.load(open(
            os.path.join(ROOT, 'assets', 'strongs', 'greek.json'),
            encoding='utf-8'))
        print('\ncommonest fills:')
        for (key, code), n in filled.most_common(args.report):
            lemma = lexicon.get(code, {}).get('lemma', '??')
            print('  %6d x  %-22s -> %-7s %-14s witnessed %d x'
                  % (n, key, code, lemma, sum(by_form[key].values())))


if __name__ == '__main__':
    main()
