#!/usr/bin/env python3
"""Repair the Septuagint's Strong's numbers against the witness inside its own file.

`assets/tagged/lxxwh/` holds two alignments in one asset: the Greek Old
Testament, and the Westcott-Hort New Testament. They are the same
language, so a word common to both is tagged twice by two different
processes — and that makes each half a witness to the other. The New
Testament half also has a third, independent witness in
`assets/originals/` (MorphGNT), which was checked in an earlier pass and
agrees with it on 95.79% of verses.

Asking the two halves to agree found two defects.

PASS 1 — 12,238 runs whose number names a DIFFERENT WORD.

The Septuagint half's numbers were assigned by a lookup that cannot see
accent, breathing or vowel length. It is not a subtle failure:

    γῆ    "earth"        G1093  ->  tagged G1065  γέ     "indeed"
    μή    "not"          G3361  ->  tagged G3165  μέ     "me"
    ὡς    "as"           G5613  ->  tagged G3739  ὅς     "who"
    ὧδε   "here"         G5602  ->  tagged G3592  ὅδε    "this"
    νῶτος "the back"     G3577  ->  tagged G3558  νότος  "the south"
    εἷς   "one"          G1520  ->  tagged G1519  εἰς    "into"

Fold η to ε and ω to ο, drop the breathings, and each wrong entry is what
is left. The same lookup also took the adjective for the adverb (καλός
for καλῶς, ὀρθός for ὀρθῶς) and the verb for the noun (οἰκέω for
οἰκουμένη, ἐργάζομαι for ἐργάτης).

A reader tapping 「γῆν」 in Genesis 1:1 — the earth, in the verse that
names it — was told the word means "indeed, at least". Nothing looked
broken: G1065 is a real number with a real entry, so every check that
asks whether a value is well-formed passed.

THE RULE, and it is deliberately narrow. Change a number only when

  1. the same surface form, accents stripped, is tagged in the New
     Testament half of this same file, and every one of those taggings
     gives the same number;
  2. there are at least MIN_WITNESS of them; and
  3. `assets/originals` — a third witness, made by other people from
     another source — names that same number for that form.

Two independent witnesses must agree before a number moves. Where they
do not, the number stays as it is even when it looks wrong.

That is why ἰδού keeps G2400 across 1,029 runs: the New Testament half
lemmatises it under ὁράω G3708, `assets/originals` does not confirm that,
and the Septuagint's own reading is the better one. The filter also
leaves alone the places where the two halves simply use different
conventions for the same word — ἐσθίω against φάγω, ἄρχω against
ἄρχομαι, μαρτύριον against μαρτυρία. A convention is not an error.

PASS 2 — 8,283 runs that answered nothing and did not have to.

49,635 runs carry an empty number. Most must: 41,000-odd are words the
New Testament never uses, and Σαλωμων, Μωαβ and Ιωαβ are spelled as the
Septuagint spells them, not as Matthew does. Inventing a number for those
would be a guess.

But `ειπεν` is tagged G3004 in 612 places and left empty in 2,550 others.
Same word, same edition, same parse, answering in one verse and not the
next. Where the edition's own tagging names a number unanimously — the
form tagged nowhere else with any other number, at least MIN_WITNESS
times, and the run's part of speech one the form is tagged under
elsewhere — the empty run takes it.

The part-of-speech guard is what makes unanimity safe. An unaccented text
loses the difference between ἐρεῖς "you will say" and ἔρεις "strifes", so
a form can look unanimous only because one of its two words never happens
to be tagged; 308 runs are refused on that ground and stay empty.

Nothing in either pass infers Greek. Both state what other copies of the
same word already say. That is why the suppletive cases come out right:
`ειπεν` takes λέγω G3004 because that is the number this edition uses for
it, not the G2036 another Strong's convention would use.

Pass 1 finishes before pass 2 begins, and pass 2 re-surveys the corpus
first. That ordering is load-bearing twice over. Correcting νωτοι's three
runs from G3558 to G3577 is what lets pass 2 fill the fourth one, in
1 Kings 7:33, with the right number instead of propagating the wrong one.
And μη is unanimous only after the correction: while its 2,263 Septuagint
runs still read G3165 and its New Testament runs read G3361, the form
carries two numbers, so every empty μη is refused a fill it should have.

WHAT IS LEFT ALONE, and why that is the honest state:
  * ~41,000 runs whose form is tagged nowhere in the file. No witness.
  * every Septuagint word that never occurs in the New Testament. The
    cross-testament witness cannot see them, so this repair says nothing
    about them and neither should anyone reading its numbers.
  * homographs the witnesses disagree about.
Under-attribution is recoverable. A wrong number is not, because it is
read as a fact about the text.

Idempotent: a second run reaches the same verdicts and writes the same
bytes.

Usage:  python3 tools/fix_lxx_strongs.py [--dry-run] [--report N]
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import sys
import unicodedata
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYER = os.path.join(ROOT, 'assets', 'tagged', 'lxxwh')
ORIGINALS = os.path.join(ROOT, 'assets', 'originals')

NEW_TESTAMENT = {
    'matthew', 'mark', 'luke', 'john', 'acts', 'romans', '1_corinthians',
    '2_corinthians', 'galatians', 'ephesians', 'philippians', 'colossians',
    '1_thessalonians', '2_thessalonians', '1_timothy', '2_timothy', 'titus',
    'philemon', 'hebrews', 'james', '1_peter', '2_peter', '1_john', '2_john',
    '3_john', 'jude', 'revelation',
}

# Three witnesses is where the list stops being dominated by forms seen
# once or twice. Two would add 917 fills in pass 2, all of them from a
# form with a single corroborating occurrence — which is a coincidence,
# not a corpus.
MIN_WITNESS = 3

# Reviewed one at a time and refused, even though both witnesses agree.
# εὐθύς is a Strong's entry in its own right (G2117) and serves as both
# adjective and adverb, so the Septuagint's reading is defensible and the
# New Testament's preference for εὐθέως G2112 is a house style, not a
# correction.
KEEP = {'ευθυσ'}

# The two halves label the closed classes differently — the Septuagint
# calls the negative ADV where Westcott-Hort calls it PRT, and ὡς is CONJ
# in one and ADV in the other. Those three labels are therefore treated
# as one class when comparing a run's parse with its witness's. Nothing
# else is merged: N, V, A, R, P, T and D stay distinct, which is what
# stops a noun being given a verb's number.
PARTICLE = {'ADV', 'PRT', 'CONJ'}


def norm(word: str) -> str:
    """Fold a surface form to its comparison key.

    The Septuagint half is unaccented and the New Testament half is not,
    so accents cannot be part of the key or the two halves could never
    witness each other. Final sigma folds for the same reason. Vowel
    length is NOT folded — η stays η — because confusing it is the very
    defect being repaired.
    """
    decomposed = unicodedata.normalize('NFD', word)
    stripped = ''.join(c for c in decomposed if not unicodedata.combining(c))
    return stripped.lower().replace('ς', 'σ').strip()


def pos(code: str) -> str:
    """The part of speech from a Robinson code: `V-2AAI-3S` -> `V`."""
    return (code or '').split('-')[0]


def load_layer():
    files = sorted(glob.glob(os.path.join(LAYER, '*.json')))
    if not files:
        sys.exit('no tagged files under %s' % LAYER)
    return [(p, os.path.basename(p)[:-5], json.load(open(p, encoding='utf-8')))
            for p in files]


def load_originals():
    """form -> Counter(strongs), from the third witness. New Testament only."""
    by_form = defaultdict(Counter)
    for path in glob.glob(os.path.join(ORIGINALS, '*.json')):
        if os.path.basename(path)[:-5] not in NEW_TESTAMENT:
            continue
        for words in json.load(open(path, encoding='utf-8')).values():
            for word in words:
                if word.get('s'):
                    by_form[norm(word.get('w', ''))][word['s']] += 1
    return by_form


def survey(books):
    """Witness pools: New Testament half, whole file, and tagged parts of speech."""
    nt = defaultdict(Counter)
    whole = defaultdict(Counter)
    tagged_pos = defaultdict(set)
    nt_pos = defaultdict(set)
    for _, book, verses in books:
        for runs in verses.values():
            for run in runs:
                code = run.get('s') or ''
                if not code:
                    continue
                key = norm(run.get('w', ''))
                if not key:
                    continue
                part = pos((run.get('g') or [''])[0])
                whole[key][code] += 1
                tagged_pos[key].add(part)
                if book in NEW_TESTAMENT:
                    nt[key][code] += 1
                    nt_pos[key].add(part)
    return nt, whole, tagged_pos, nt_pos


def corrections(nt, originals):
    """form -> the number both witnesses name for it."""
    table = {}
    for key, codes in nt.items():
        if key in KEEP or len(codes) != 1:
            continue
        code = next(iter(codes))
        if sum(codes.values()) < MIN_WITNESS:
            continue
        third = originals.get(key)
        if not third or third.most_common(1)[0][0] != code:
            continue
        table[key] = code
    return table


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--report', type=int, default=0)
    args = ap.parse_args()

    books = load_layer()
    nt, whole, tagged_pos, nt_pos = survey(books)
    table = corrections(nt, load_originals())

    corrected = Counter()
    filled = Counter()
    held = Counter()
    refused = 0
    unwitnessed = 0
    changed = set()

    # Pass 1, over the Old Testament half only: the New Testament half is
    # the witness and cannot correct itself, and `assets/originals`
    # already checks it.
    for path, book, verses in books:
        if book in NEW_TESTAMENT:
            continue
        for runs in verses.values():
            for run in runs:
                code = run.get('s') or ''
                if not code:
                    continue
                key = norm(run.get('w', ''))
                want = table.get(key)
                if not want or want == code:
                    continue
                # The run's own parse must agree with the witness's. This
                # is what keeps Leviticus's ἁφή "a plague-spot" (a noun,
                # G860) from being given the number of the identically
                # spelled ἀφῇ from ἀφίημι (a verb).
                part = pos((run.get('g') or [''])[0])
                if not (part in nt_pos[key]
                        or (part in PARTICLE and nt_pos[key] & PARTICLE)):
                    held[(key, code, want, part)] += 1
                    continue
                corrected[(key, code, want)] += 1
                run['s'] = want
                changed.add(path)

    # Re-survey. Pass 2 must read the corrected numbers, not the ones
    # pass 1 just replaced — otherwise μη is still split between G3165
    # and G3361, looks ambiguous, and its empty runs are refused a fill
    # they should get. This is also what makes the tool idempotent.
    _, whole, tagged_pos, _ = survey(books)

    # Pass 2, over the file as a whole.
    for path, book, verses in books:
        for runs in verses.values():
            for run in runs:
                if run.get('s'):
                    continue
                key = norm(run.get('w', ''))
                codes = whole.get(key) if key else None
                if (not codes or len(codes) != 1
                        or sum(codes.values()) < MIN_WITNESS):
                    unwitnessed += 1
                    continue
                if pos((run.get('g') or [''])[0]) not in tagged_pos[key]:
                    refused += 1
                    continue
                run['s'] = next(iter(codes))
                filled[(key, run['s'])] += 1
                changed.add(path)

    if not args.dry_run:
        for path, _, verses in books:
            if path in changed:
                with open(path, 'w', encoding='utf-8') as f:
                    json.dump(verses, f, ensure_ascii=False,
                              separators=(',', ':'))

    print('pass 1  corrected  %6d runs over %d forms'
          % (sum(corrected.values()), len(corrected)))
    print('        held       %6d runs whose own parse disagrees'
          % sum(held.values()))
    print('pass 2  filled     %6d runs over %d forms'
          % (sum(filled.values()), len(filled)))
    print('        refused    %6d on parse' % refused)
    print('        left empty %6d with no unanimous witness' % unwitnessed)
    if args.dry_run:
        print('\n(dry run — nothing written)')

    if args.report:
        lexicon = json.load(open(
            os.path.join(ROOT, 'assets', 'strongs', 'greek.json'),
            encoding='utf-8'))

        def lemma(code):
            return lexicon.get(code, {}).get('lemma', '?')

        print('\nlargest corrections:')
        for (key, was, now), n in corrected.most_common(args.report):
            print('  %6d x  %-16s %s %-12s -> %s %s'
                  % (n, key, was, lemma(was), now, lemma(now)))
        print('\nlargest fills:')
        for (key, code), n in filled.most_common(args.report):
            print('  %6d x  %-16s -> %s %s' % (n, key, code, lemma(code)))


if __name__ == '__main__':
    main()
