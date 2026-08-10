#!/usr/bin/env python3
"""Repair the Greek New Testament words in assets/originals/ whose Strong's
number names a different word than the one it sits on (#304, check 24).

Idempotent: re-running reports "already correct" and writes nothing.

WHY THIS IS A SCRIPT AND NOT FIFTEEN HAND EDITS
Each of these changes what the app TELLS A READER a word of scripture
means. Every one is written down here with the witness that decided it,
so the diff can be reviewed as an argument rather than trusted as an
edit.

HOW THEY WERE FOUND
`tools/audit_originals_witness.py` compares assets/originals against the
two upstream sources it was built beside — MorphGNT (SBLGNT, CC BY-SA
3.0) for the Greek and the Open Scriptures Hebrew Bible (CC BY 4.0) for
the Hebrew — and against the corpus's own internal agreement. Three
witnesses, and a word is only listed here when at least two of them say
the same thing:

  W1  the shipped morphology code, which the audit proves reproduces
      MorphGNT exactly for all 137,044 aligned Greek words. It is
      therefore independent of the Strong's number sitting next to it,
      and a row where the two contradict each other is a row where one
      of them is wrong.
  W2  MorphGNT's own lemma for the same word. MorphGNT carries no
      Strong's numbers, so this is a genuinely separate opinion about
      what word this is.
  W3  the corpus contradicting itself: the identical accented form,
      often in the identical verse, already carrying the other number.

NOT LISTED HERE, and the reasons, because a check that only reports what
it changed is not reportable:

  * John 6:17 ἤρχοντο is tagged G2064 ἔρχομαι and MorphGNT lemmatises it
    ἄρχω. The two verbs share the imperfect ἠρχ-, and the verse is
    "ἤρχοντο πέραν τῆς θαλάσσης" — they were GOING across the sea. Ours
    is right and the witness is wrong. Left alone.
  * 1 Timothy 5:4 πρῶτον carries morph D (adverb) where the other 60
    occurrences carry A. Strong's has G4412 for the adverb, but this
    corpus uses G4412 nowhere at all, so changing one occurrence would
    create an inconsistency rather than remove one. Left alone.
  * Ephesians 2:13 οἵ is tagged G3739 ὅς while its morph reads RA
    (article). Our edition accents it as a relative pronoun and SBLGNT
    accents it as an article; both are nominative plural masculine, and
    only the category label differs. That is two editors disagreeing,
    not our error. Left alone.
  * Luke 1:38, 1:48 and Acts 2:18 use G1401 δοῦλος for the feminine
    δούλη, where Strong's has G1399. The corpus does this every time it
    meets the feminine and never uses G1399, so it is this tagging's
    convention, not a slip. Left alone.
  * The 3,867 places where MorphGNT's lemma differs from the lemma of
    our Strong's number are overwhelmingly Strong's 1890 orthography
    against a modern critical text — ἔπω/λέγω, εἴδω/ὁράω, Δαβίδ/Δαυίδ,
    Καπερναούμ/Καφαρναούμ. Those are lexicographic conventions and
    changing them would be inventing a third one.

AFTER RUNNING THIS, REBUILD THE DERIVED ASSETS:
    python3 -c "import tools.build_originals as b; b.build_concordance()"
    python3 tools/build_forms_index.py
`assets/strongs/concordance.json` and `assets/forms/` are both inverted
indexes over these same words, so leaving them stale would make the
Word List and the concordance disagree with the text they index — which
is the class of defect this whole audit exists to catch.
"""
from __future__ import annotations

import json
import os
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIGINALS = os.path.join(ROOT, 'assets', 'originals')

# (book slug, chapter:verse, exact surface form, from, to, why)
CORRECTIONS = [
    # ── οὗ "where" told as οὐ "not" ────────────────────────────────────
    # G3757 οὗ is the relative adverb "at which place"; G3756 οὐ is the
    # absolute negative. Three verses hang their whole sense on the
    # first and were tagged with the second, so a reader tapping the
    # word was told the passage says "not" where it says "where".
    # W1 morph D--------- matches G3757's adverbial use (16 of its 22
    # occurrences) and cannot distinguish it from οὐ, but W3 is decisive:
    # the identical accented form οὗ carries G3757 twenty-one other times
    # and G3756 nowhere else in the corpus. Luke 23:53 holds both words
    # in one clause — οὗ οὐκ ἦν — and tagged them the same.
    ('luke', '4:17', 'οὗ', 'G3756', 'G3757',
     'εὗρεν τὸν τόπον οὗ ἦν γεγραμμένον — the place WHERE it was written'),
    ('luke', '23:53', 'οὗ', 'G3756', 'G3757',
     'μνήματι λαξευτῷ οὗ οὐκ ἦν οὐδεὶς — a tomb WHERE no one had lain'),
    ('romans', '9:26', 'οὗ', 'G3756', 'G3757',
     'ἐν τῷ τόπῳ οὗ ἐρρέθη αὐτοῖς — the place WHERE it was said'),
    # ...and the same confusion pointing the other way, which is why the
    # three above are a fault and not a house convention.
    ('acts', '5:28', 'Οὐ', 'G3757', 'G3756',
     'Οὐ παραγγελίᾳ παρηγγείλαμεν — did we NOT strictly charge you'),

    # ── "bear with me" told as "kill" ─────────────────────────────────
    # W3 alone settles it: the same verse says ἀνέχεσθέ two words later
    # and tags it G430. ἀνέχομαι's imperfect is ἀνείχεσθε; ἀναιρέω's
    # would be ἀνῃρεῖσθε. W1 (V-2IMI-P--) and W2 (lemma ἀνέχομαι) agree.
    ('2_corinthians', '11:1', 'ἀνείχεσθέ', 'G337', 'G430',
     'Ὄφελον ἀνείχεσθέ μου μικρόν — would that you BORE WITH me'),

    # ── Stephen told as "a crown" ─────────────────────────────────────
    # G4736 is the man, G4735 the wreath. Acts spells the name six times
    # and tags five of them G4736; this one, in the verse that buries
    # him, took the common noun.
    ('acts', '8:2', 'Στέφανον', 'G4735', 'G4736',
     'συνεκόμισαν τὸν Στέφανον ἄνδρες εὐλαβεῖς — they buried STEPHEN'),

    # ── the divorced woman told as "left behind" ──────────────────────
    # ἀπολελυμένην is the perfect passive participle of ἀπολύω (G630);
    # ἀπολείπω (G620) would give ἀπολελειμμένην. Both verses put ἀπολύων
    # a few words earlier and tag THAT G630, so the same verb in one
    # sentence carried two numbers.
    ('matthew', '5:32', 'ἀπολελυμένην', 'G620', 'G630',
     'ὃς ἐὰν ἀπολελυμένην γαμήσῃ — whoever marries a DIVORCED woman'),
    ('luke', '16:18', 'ἀπολελυμένην', 'G620', 'G630',
     'ὁ ἀπολελυμένην ἀπὸ ἀνδρὸς γαμῶν — marries a woman DIVORCED'),

    # ── "anything" told as "what?" ────────────────────────────────────
    # The weakest pair in this list and the reason is worth stating: the
    # spellings τί and τίς are shared by the interrogative (G5101) and
    # the enclitic indefinite (G5100), which takes an acute when another
    # enclitic follows it — which is exactly the environment in both
    # verses (τί ἐστιν, τίς ἐστιν). So the accent does not decide, and
    # W3 is mute; this rests on W2 (MorphGNT lemmatises both as the
    # indefinite τις) and on sense. "Neither is circumcision WHAT?" and
    # "if WHO is blameless" are not Greek.
    ('galatians', '6:15', 'τί', 'G5101', 'G5100',
     'οὔτε περιτομή τί ἐστιν — neither circumcision is ANYTHING'),
    ('titus', '1:6', 'τίς', 'G5101', 'G5100',
     'εἴ τίς ἐστιν ἀνέγκλητος — if ANYONE is blameless'),

    # ── a noun told as a verb, by the row's own other column ──────────
    # W1 standing alone and unanswerable: the morph reads N-----DSF-, a
    # feminine dative NOUN, beside a Strong's number for a verb. ποίησις
    # G4162 occurs once in the New Testament and this is it; the other
    # seventeen ποιήσει in the corpus are the future of ποιέω and are
    # correctly tagged.
    ('james', '1:25', 'ποιήσει', 'G4160', 'G4162',
     'μακάριος ἐν τῇ ποιήσει αὐτοῦ — blessed in his DOING'),

    # ── "but" told as "other" ─────────────────────────────────────────
    # W1 says C (conjunction) where G243 ἄλλος is an adjective, and W3
    # is overwhelming: this exact form with this exact parse is G235 in
    # 389 other places.
    ('john', '6:23', 'ἀλλὰ', 'G243', 'G235',
     'ἀλλὰ ἦλθεν πλοιάρια ἐκ Τιβεριάδος — BUT boats came from Tiberias'),

    # ── "what is mine" told as "I" ────────────────────────────────────
    # W1 reads A-----GSN-, an adjective; G1473 ἐγώ is a pronoun and its
    # other 109 occurrences of this form are parsed RP. The corpus tags
    # ἐμοῦ + A-----GSN- as G1699 three other times.
    ('john', '16:15', 'ἐμοῦ', 'G1473', 'G1699',
     'ἐκ τοῦ ἐμοῦ λαμβάνει — he takes from what is MINE'),

    # ── the compound's entry on the simple verb ───────────────────────
    # The word on the page is στηρίζων. G1991 is ἐπιστηρίζω, the
    # compound the Received Text reads here; our edition does not read
    # it. The corpus spells ἐπιστηρίζων separately elsewhere and tags
    # that G1991, so this is not a policy of folding the two together.
    ('acts', '18:23', 'στηρίζων', 'G1991', 'G4741',
     'στηρίζων πάντας τοὺς μαθητάς — STRENGTHENING all the disciples'),

    # ── the region's entry on the adjective ───────────────────────────
    # ἡ Ἰουδαία χώρα is "the JUDEAN country" — the adjective Ἰουδαῖος
    # agreeing with χώρα, not the province Ἰουδαία standing alone. The
    # corpus already follows exactly this rule: where the morph reads A
    # the number is G2453, where it reads N the number is G2449. This
    # one word reads A and took G2449.
    ('mark', '1:5', 'Ἰουδαία', 'G2449', 'G2453',
     'πᾶσα ἡ Ἰουδαία χώρα — all the JUDEAN country'),
]


def main() -> int:
    changed = 0
    already = 0
    failed = 0
    for slug, ref, form, old, new, why in CORRECTIONS:
        path = os.path.join(ORIGINALS, slug + '.json')
        with open(path, encoding='utf-8') as f:
            book = json.load(f)
        words = book.get(ref)
        if words is None:
            print('  ! %s %s missing' % (slug, ref))
            failed += 1
            continue
        target = unicodedata.normalize('NFC', form)

        def matches(w, s):
            return (unicodedata.normalize('NFC', w['w']) == target
                    and w.get('s') == s)

        hits = [i for i, w in enumerate(words) if matches(w, old)]
        done = [i for i, w in enumerate(words) if matches(w, new)]
        if not hits and done:
            print('  = %-16s %-8s %-14s already %s' % (slug, ref, form, new))
            already += 1
            continue
        if len(hits) != 1:
            # Refuse to guess. Two identical forms with the same wrong
            # number in one verse would need the audit re-run to say
            # which, and a wrong repair here is the defect it is fixing.
            print('  ! %-16s %-8s %-14s %d candidates for %s, skipped'
                  % (slug, ref, form, len(hits), old))
            failed += 1
            continue
        words[hits[0]]['s'] = new
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(book, f, ensure_ascii=False, separators=(',', ':'))
        print('  ~ %-16s %-8s %-14s %s -> %s   %s'
              % (slug, ref, form, old, new, why))
        changed += 1

    print('\n%d corrected, %d already correct, %d could not be applied'
          % (changed, already, failed))
    if changed:
        print('Now rebuild the derived indexes — see this file\'s docstring.')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
