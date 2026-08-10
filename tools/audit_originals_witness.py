#!/usr/bin/env python3
"""Ask an outside witness whether assets/originals tells the truth
(#304, check 24).

Every earlier check on this corpus was internal: that a Strong's number
resolves to a lexicon entry, that a morph code decodes to a label, that
counts add up. None of them could catch a row that is well-formed and
wrong — a real code and a real number sitting on a word they do not
describe. That needs a source outside the app.

THE WITNESSES
  MorphGNT / SBLGNT (CC BY-SA 3.0)   tools/src/gnt/*-morphgnt.txt
      Carries a morph code and a lemma, and NO Strong's numbers. Its
      lemma is therefore an independent opinion about what word this is.
  Open Scriptures Hebrew Bible (CC BY 4.0)   tools/src/hb/*.xml
      Carries morph and Strong's directly in the lemma attribute.

Fetch them with tools/fetch_morphology_sources.sh; without them this
script reports what is missing and exits 0, so it stays runnable on a
machine that has only the repo.

WHAT IT REPORTS
  1  morph        our `m` against the witness's code, on aligned words
  2  strongs      our `s` against OSHB's number (Hebrew, direct)
  3  lemma        our number's lexicon lemma against MorphGNT's lemma
                  (Greek, indirect — a difference here is usually
                  Strong's 1890 orthography, not an error, so this is
                  reported as a rate with samples and never as a verdict)
  4  pos          a row whose morph says NOUN carrying a number whose
                  every other occurrence is a VERB. The morph column is
                  proven by check 1 to reproduce MorphGNT exactly, which
                  makes it independent of the number beside it, so the
                  two contradicting each other means one of them is
                  wrong. Needs no external source.
  5  self         the same accented form with the same parse carrying
                  two different numbers, one of them almost never. Also
                  needs no external source, and between them 4 and 5
                  found most of the defects this audit repaired.

Checks 4 and 5 are heuristics, so both carry a table of adjudicated
hits with the reason each was left alone. Run against an older revision
to see them earn their keep:

    git archive HEAD assets/originals | tar -x -C /tmp/before
    python3 tools/audit_originals_witness.py --originals /tmp/before/assets/originals

Two findings are argued in tools/repair_originals_strongs.py rather than
here, because they are invisible to every check above — John 6:17
ἤρχοντο, where MorphGNT's lemma is wrong and ours is right, and the
feminine δούλη tagged G1401, which this corpus does consistently. Both
came out of check 3's lemma differences, which are reported as a rate
because 3,779 of them are Strong's 1890 spelling and reading them is a
human job.

Alignment is by difflib over accent-stripped (Greek) or consonant-only
(Hebrew) forms, never by position. Position was tried first and invented
883 Hebrew disagreements out of nothing: the editions differ on
Ketiv/Qere and maqqef, so 5,471 verses have different word counts and
every word after the first difference compares against its neighbour.

Exit code is 1 if anything unadjudicated is found, so this can gate CI
once the sources are vendored.
"""
from __future__ import annotations

import json
import os
import sys
import unicodedata
from collections import Counter, defaultdict
from xml.etree import ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from merge_morphology import (  # noqa: E402
    GNT_BOOKS, HB_BOOKS, _OSIS, align, load_hb, norm_greek, norm_hebrew,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# A one-element list so --originals can retarget it; pointing this at a
# checkout of an older revision is how the instrument is shown to catch
# the defects it was written for.
ORIGINALS = [os.path.join(ROOT, 'assets', 'originals')]
SRC = os.path.join(ROOT, 'tools', 'src')

# Greek morph codes open with a two-character part of speech. Pronoun
# subcategories are kept apart on purpose: G1473 ἐγώ is RP everywhere,
# and the one place it was parsed A- was a genuine mis-tag (John 16:15,
# where the word is ἐμοῦ G1699 "mine").
POS_NAMES = {
    'N-': 'noun', 'V-': 'verb', 'A-': 'adjective', 'RA': 'article',
    'RP': 'personal pron', 'RR': 'relative pron', 'RI': 'interrog/indef',
    'RD': 'demonstrative', 'C-': 'conjunction', 'P-': 'preposition',
    'D-': 'adverb', 'I-': 'interjection', 'X-': 'particle',
}

# I- and X- are left out. MorphGNT calls ἰδού an interjection twice and a
# particle 198 times, and since check 1 proves our morph column IS
# MorphGNT, a disagreement between those two labels is the witness
# disagreeing with itself about a category, not a number sitting on the
# wrong word. Everything below names a different lexeme if it is wrong.
POS_DECISIVE = frozenset((
    'N-', 'V-', 'A-', 'RA', 'RP', 'RR', 'RI', 'RD', 'C-', 'P-', 'D-'))

# Pairs where Greek routinely uses ONE lexeme in two syntactic
# functions, so Strong's — which has one entry per lexeme — is right to
# give them one number and the parser is right to label them apart.
#   A-/D-  neuter accusative of an adjective as an adverb: Luke 20:12
#          τρίτον "a third time", Mark 7:36 περισσότερον "the more",
#          1 Tim 5:4 πρῶτον, 2 Pet 2:18 ὀλίγως.
#   P-/D-  a preposition standing adverbially, and the improper
#          prepositions: 2 Cor 11:23 ὑπὲρ ἐγώ "I more so", John 11:18
#          ὡς ἀπὸ σταδίων δεκαπέντε, John 4:5 πλησίον τοῦ χωρίου,
#          John 20:7 χωρίς.
#   C-/D-, C-/P-  the indeclinables that are classified by what they
#          govern in the clause at hand: μέχρι, μήποτε, κἀκεῖ.
# C-/A- is NOT here, and that is the point of listing these rather than
# exempting the whole indeclinable block: John 6:23 ἀλλά "but" carried
# G243 ἄλλος "other", two different words, and only survives the filter
# if the exemption is written this narrowly.
POS_FUNCTION_PAIRS = frozenset((
    frozenset(('A-', 'D-')), frozenset(('P-', 'D-')),
    frozenset(('C-', 'D-')), frozenset(('C-', 'P-')),
))

# Rows where our column and the witness disagree and OURS IS RIGHT, or
# where the difference is two editors' convention rather than an error.
# Each needs a reason a reviewer can check, not a hash.
ADJUDICATED = {
    ('ephesians', '2:13', 'οἵ'):
        'Our edition accents a relative pronoun, SBLGNT an article. Both '
        'nominative plural masculine; only the category label differs.',
}

# Adjudicated hits of check 5, keyed (surface form, morph, our number).
SELF_ADJUDICATED = {
    ('τις', 'RI----NSM-', 'G5101'):
        'Romans 8:24. Both our columns agree with the witness — SBLGNT '
        'reads ⸀τίς here, marked as a variant point, and lemmatises it '
        'as the interrogative. Only our surface accent follows a '
        'different edition. That is a base-text question about which '
        'text we print, not a tagging error, and it is not settled by '
        'editing the tag.',
    ('τί', 'RI----NSN-', 'G5100'):
        'Acts 25:5 "εἴ τί ἐστιν", 1 Corinthians 10:19 "εἰδωλόθυτόν τί '
        'ἐστιν". The indefinite is right in all of them; they are '
        'flagged only because the identical spelling is far more often '
        'the interrogative. An enclitic takes an acute when another '
        'enclitic follows, which is the environment in every one of '
        'these, so the accent cannot decide and the sense must.',
    ('τίς', 'RI----NSM-', 'G5100'): 'Titus 1:6 "εἴ τίς ἐστιν". As above.',
}


def load_gnt_full(path):
    """{(ch, vs): [(word, morph, lemma)]} — load_gnt drops the lemma and
    the lemma is the whole point of this witness."""
    verses = {}
    with open(path, encoding='utf-8') as fh:
        for line in fh:
            parts = line.split()
            if len(parts) < 7:
                continue
            bcv = parts[0]
            verses.setdefault((int(bcv[2:4]), int(bcv[4:6])), []).append(
                (parts[4], parts[1] + parts[2], parts[6]))
    return verses


def _lemma_numbers(el):
    """Every Strong's number in an OSHB lemma attribute. A word carries
    several because the attribute spells out prefixes too ("b/7225"),
    while our asset keeps one number per word — so agreement means our
    number is among them. Homograph suffixes ("1254 a") are stripped."""
    lem = (el.get('lemma') or '').replace('/', ' ').replace('+', ' ')
    return [seg.rstrip('abcdefg') for seg in lem.split()
            if seg.rstrip('abcdefg').isdigit()]


def _qere_slot(children, i):
    """The <w> elements of the Qere replacing the Ketiv at [i], or None."""
    nxt = children[i + 1] if i + 1 < len(children) else None
    if nxt is None or nxt.tag != _OSIS + 'note':
        return None
    for rdg in nxt.findall(_OSIS + 'rdg'):
        if rdg.get('type') == 'x-qere':
            return rdg.findall(_OSIS + 'w')
    return None


def load_hb_full(path):
    """{(ch, vs): [(word, morph, [numbers])]}.

    Deliberately NOT reusing merge_morphology.load_hb. That function is
    half of what this script is auditing, and a witness that shares the
    accused's parsing cannot see the accused's parsing errors. The
    Ketiv/Qere handling below therefore mirrors it rather than calling
    it, and the aligned-word total is printed so the two can be compared.
    """
    verses = {}
    for v in ET.parse(path).iter(_OSIS + 'verse'):
        osis = (v.get('osisID') or '').split('.')
        if len(osis) < 3:
            continue
        try:
            key = (int(osis[1]), int(osis[2]))
        except ValueError:
            continue
        words = []
        children = list(v)
        for i, el in enumerate(children):
            prev = children[i - 1] if i else None
            after_ketiv = (prev is not None and prev.tag == _OSIS + 'w'
                           and prev.get('type') == 'x-ketiv')
            if el.tag == _OSIS + 'note':
                # A Qere with no Ketiv: read by the Masoretes, absent
                # from the consonantal text, so it has no <w> of its own.
                slot = [] if after_ketiv else (_qere_slot(children, i - 1) or [])
            elif el.tag == _OSIS + 'w':
                slot = [el]
                if el.get('type') == 'x-ketiv':
                    qere = _qere_slot(children, i)
                    if qere is not None:
                        slot = qere
            else:
                continue
            for w in slot:
                text = ''.join(w.itertext()).strip()
                if text:
                    words.append((text, w.get('morph') or '',
                                  _lemma_numbers(w)))
        verses[key] = words
    return verses


def load_book(slug):
    path = os.path.join(ORIGINALS[0], slug + '.json')
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def verse_key(ref):
    ch, _, vs = ref.partition(':')
    try:
        return int(ch), int(vs)
    except ValueError:
        return None


def audit_greek(report):
    lex = json.load(open(os.path.join(ROOT, 'assets', 'strongs', 'greek.json'),
                         encoding='utf-8'))
    aligned = morph_bad = lemma_diff = total_words = 0
    pos_by_strongs = defaultdict(Counter)
    rows = []

    for src, slug in GNT_BOOKS:
        path = os.path.join(SRC, 'gnt', src + '-morphgnt.txt')
        book = load_book(slug)
        if book is None or not os.path.exists(path):
            report.append('  ! %s: source or asset missing' % slug)
            continue
        witness = load_gnt_full(path)
        for ref, words in book.items():
            key = verse_key(ref)
            wit = witness.get(key)
            total_words += len(words)
            for i, w in enumerate(words):
                if not w.get('m'):
                    continue  # untagged word; it witnesses nothing
                pos_by_strongs[w.get('s')][w['m'][:2]] += 1
                rows.append((slug, ref, i, w))
            if not wit:
                continue
            amap = align([w['w'] for w in words], [t[0] for t in wit],
                         norm_greek)
            for ai, si in amap.items():
                aligned += 1
                ours, theirs = words[ai], wit[si]
                if (ours.get('m') or '') != theirs[1]:
                    morph_bad += 1
                    if morph_bad <= 20:
                        report.append('  morph %s %s %s: ours %s theirs %s'
                                      % (slug, ref, ours['w'],
                                         ours.get('m'), theirs[1]))
                entry = lex.get(ours.get('s') or '')
                if entry and norm_greek(entry['lemma']) != norm_greek(theirs[2]):
                    lemma_diff += 1

    report.append('')
    report.append('GREEK')
    report.append('  aligned against MorphGNT   %d of %d words (%.2f%%)'
                  % (aligned, total_words,
                     100.0 * aligned / max(total_words, 1)))
    report.append('  morph disagreements        %d' % morph_bad)
    report.append('  lexicon lemma != MorphGNT  %d (%.2f%%) — mostly '
                  'Strong\'s 1890 spelling (ἔπω/λέγω, Δαβίδ/Δαυίδ), '
                  'informational only'
                  % (lemma_diff, 100.0 * lemma_diff / max(aligned, 1)))

    # 4: the row's own two columns against each other. The rule is
    # deliberately the strictest one that still catches a wrong lexeme —
    # this part of speech appears with this Strong's number EXACTLY ONCE
    # in the whole corpus, and the number is otherwise a different major
    # category. A second occurrence means the corpus is doing it on
    # purpose, which is a convention to argue with, not a slip.
    suspects = []
    for slug, ref, _i, w in rows:
        s, pos = w.get('s'), (w.get('m') or '')[:2]
        if pos not in POS_DECISIVE:
            continue
        counts = pos_by_strongs[s]
        mine, total = counts[pos], sum(counts.values())
        if total < 10 or mine != 1:
            continue
        dom = counts.most_common(1)[0]
        if dom[0] == pos or dom[0] not in POS_DECISIVE:
            continue
        if frozenset((pos, dom[0])) in POS_FUNCTION_PAIRS:
            continue
        suspects.append((slug, ref, w['w'], s, pos, dom, total))
    return aligned, morph_bad, suspects, rows


def self_contradictions(rows):
    """Check 5: the corpus disagreeing with itself, which needs no
    external source and is what actually settled most of the repairs.

    The key is the EXACT accented form plus the full morph code, so the
    two sides are the same word parsed the same way — at which point two
    different Strong's numbers cannot both be right. A number is a
    suspect when it holds that slot at most 3 times and under a fifth of
    the time while another holds it at least 10.

    The thresholds are not tuned to taste. Below a fifth the check
    misses Luke 4:17 οὗ, a real and meaning-reversing defect that stands
    at 3 of 19; above it the yield is unchanged. Across the whole Greek
    corpus it returns four slots, which is few enough to adjudicate by
    hand and is the reason this heuristic is allowed to exist at all.
    """
    tally = defaultdict(Counter)
    where = defaultdict(list)
    for slug, ref, _i, w in rows:
        key = (unicodedata.normalize('NFC', w['w']), w['m'])
        tally[key][w.get('s')] += 1
        where[(key, w.get('s'))].append('%s %s' % (slug, ref))

    out = []
    for key, counts in tally.items():
        if len(counts) < 2:
            continue
        dom, dom_n = counts.most_common(1)[0]
        total = sum(counts.values())
        for s, n in counts.items():
            if s == dom or n > 3 or dom_n < 10 or n / total >= 0.20:
                continue
            out.append((key[0], key[1], s, n, dom, dom_n, where[(key, s)]))
    return sorted(out)


def audit_hebrew(report):
    aligned = morph_bad = strongs_bad = compared = total_words = 0
    unaligned = Counter()
    for src, slug in HB_BOOKS:
        path = os.path.join(SRC, 'hb', src + '.xml')
        book = load_book(slug)
        if book is None or not os.path.exists(path):
            report.append('  ! %s: source or asset missing' % slug)
            continue
        witness = load_hb_full(path)
        for ref, words in book.items():
            key = verse_key(ref)
            total_words += len(words)
            wit = witness.get(key)
            if not wit:
                continue
            amap = align([w['w'] for w in words], [t[0] for t in wit],
                         norm_hebrew)
            for i, w in enumerate(words):
                if i not in amap:
                    unaligned[slug] += 1
            for ai, si in amap.items():
                aligned += 1
                ours = words[ai]
                _text, their_morph, their_nums = wit[si]
                if (ours.get('m') or '') != their_morph:
                    morph_bad += 1
                    report.append('  morph %s %s %s: ours %s theirs %s'
                                  % (slug, ref, ours['w'], ours.get('m'),
                                     their_morph))
                want = (ours.get('s') or '')[1:]
                if not (want and their_nums):
                    continue
                compared += 1
                if want not in their_nums:
                    strongs_bad += 1
                    report.append(
                        '  strongs %s %s %s: ours %s theirs %s'
                        % (slug, ref, ours['w'], ours.get('s'),
                           '/'.join(their_nums)))
    report.append('')
    report.append('HEBREW')
    report.append('  aligned against OSHB       %d of %d words (%.2f%%)'
                  % (aligned, total_words, 100.0 * aligned / max(total_words, 1)))
    report.append('  morph disagreements        %d' % morph_bad)
    # Printed so a future reader can see the check had something to bite
    # on. "0 disagreements" out of 0 comparisons is not a clean result,
    # it is a broken instrument, and the first draft of this script was
    # exactly that.
    report.append('  Strong\'s compared          %d words' % compared)
    report.append('  Strong\'s disagreements     %d' % strongs_bad)
    if unaligned:
        # Not a defect on its own: our base text and the WLC differ in a
        # few places (1 Chr 9:4 carries an unpointed בנימן the WLC does
        # not have), and difflib deliberately refuses to pair words it
        # cannot prove equal. It is reported because "0 disagreements"
        # means nothing without knowing how much went unexamined.
        report.append('  unaligned (not examined)   %d words in %d books'
                      % (sum(unaligned.values()), len(unaligned)))
        for slug, n in unaligned.most_common(5):
            report.append('      %-18s %d' % (slug, n))
    return aligned, morph_bad + strongs_bad


def main() -> int:
    if '--originals' in sys.argv:
        ORIGINALS[0] = sys.argv[sys.argv.index('--originals') + 1]
        print('reading originals from %s' % ORIGINALS[0])
    report = []
    g_aligned, g_morph, suspects, rows = audit_greek(report)
    h_aligned, h_bad = audit_hebrew(report)

    report.append('')
    report.append('PART-OF-SPEECH CONFLICTS (Greek, row against itself)')
    open_ = 0
    for slug, ref, form, s, pos, dom, total in sorted(suspects):
        why = ADJUDICATED.get((slug, ref, form))
        mark = '  .' if why else '  !'
        report.append('%s %-16s %-8s %-14s %s morph %s but %s is %s in %d/%d'
                      % (mark, slug, ref, form, s, POS_NAMES.get(pos, pos),
                         s, POS_NAMES.get(dom[0], dom[0]), dom[1], total))
        if why:
            report.append('      adjudicated: %s' % why)
        else:
            open_ += 1
    if not suspects:
        report.append('  none')

    report.append('')
    report.append('SELF-CONTRADICTIONS (Greek, same form + same parse, '
                  'two numbers)')
    for form, morph, s, n, dom, dom_n, refs in self_contradictions(rows):
        why = SELF_ADJUDICATED.get((form, morph, s))
        report.append('%s %-14s %-11s %s x%d vs %s x%d   %s'
                      % ('  .' if why else '  !', form, morph, s, n,
                         dom, dom_n, ', '.join(refs[:3])))
        if why:
            report.append('      adjudicated: %s' % why)
        else:
            open_ += 1

    print('\n'.join(report))
    print('\n%d Greek + %d Hebrew words witnessed; %d open findings'
          % (g_aligned, h_aligned, g_morph + h_bad + open_))
    return 1 if (g_morph or h_bad or open_) else 0


if __name__ == '__main__':
    sys.exit(main())
