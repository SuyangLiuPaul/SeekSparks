# SEARCH-AUDIT

Every syntax the command line accepts, driven once, with the number it
returned and a verdict.

The user asked on 2026-08-08: *"is the search function all functional?"*
The ticket (#295) is explicit about what does **not** answer that
question — "'447 tests pass' is a DIFFERENT claim and must not be
substituted for it." So this is a table of queries and counts, and where
a count was wrong it says which one and what it is now.

2026-08-24. A first pass on #295 drove the deployed build over CDP and
fixed three defects in the surrounding chrome — the Strong's header's
count claims, bare-wildcard promotion, and version abbreviations like
`d nas`. Those are pinned in `test/search_audit_295_test.dart` and are
not repeated here. **This is the second pass: the grammar itself,**
pinned in `test/command_grammar_audit_test.dart`.

Counts are KJV verses (31,102 verses) unless a row says otherwise. They
are verse counts, never occurrence counts — see
`project_seeksparks_concordance_units`.

---

## 1. The short answer

Of 60-odd distinct syntaxes driven, **four returned a wrong number and
none of them threw**. That is the whole finding. A reader had no way to
tell any of the four apart from a correct answer, because in each case
the app printed a plausible count and moved on.

| # | What was wrong | Reader saw | Status |
|---|---|---|---|
| A | `;N`, `*N` and a compound join distance parsed with `int.parse` | native only: "no results" for a search that never ran | **fixed** |
| B | Greek final sigma is not folded, so `.ΘΕΌΣ` = 0 while `.θεός` = 1611 | a true word reported absent | **withdrawn — see §5** |
| C | An apostrophe at a word's edge could never match | `.sons'` = 0 for a word printed in 212 KJV verses | **fixed** |
| D | `*N` above 50 was clamped, silently | Esther 8:9 unreachable by a query naming its true distance | **fixed** |

Three of the four are in this release. The fourth was implemented,
measured, and reverted; §5 says why, with both numbers.

---

## 2. The sweep

### 2.1 The operators

| Query | Count | Verdict |
|---|---|---|
| `.god` | 3877 | ✅ |
| `.GOD` | 3877 | ✅ case-blind |
| `.the son of man` | 244 | ✅ a bag of words |
| `'the son of man` | 94 | ✅ a sequence, and a subset of the above |
| `'in the beginning` | 17 | ✅ incl. Genesis 1:1, John 1:1, Judges 7:19 |
| `'saith the preacher vanity of vanities` | 1 | ✅ Ecclesiastes 1:2 — steps over a comma and a semicolon |
| `.melchizedek abram` | 0 | ✅ honest: they never share a verse |
| `.melchizedek abram;2` | 2 | ✅ Genesis 14:18–19 — both verses reported |
| `;the earth and the earth;2` | 3 | ✅ first hit Genesis 1:1, which is bwh16's own stated answer |
| `.paul silas` | 10 | ✅ |
| `.paul silas;10` | 35 | ✅ a context widens |
| `.paul silas !barnabas` | 9 | ✅ an exclusion narrows |
| `.curse generation;3` | >0, without Malachi 4:6 | ✅ a window never crosses a book boundary |

### 2.2 The wildcards

| Query | Count | Verdict |
|---|---|---|
| `.heaven` | 550 | ✅ |
| `.heaven?` | 127 | ✅ `?` is exactly one character, so it can only narrow |
| `.faith` | 231 | ✅ |
| `.faith*` | 336 | ✅ `*` is zero or more, so it can only widen |
| `.wom?n` | 503 | ✅ |
| `.wom[ae]n` | 503 | ✅ |
| `.wom{ae}n` | 503 | ✅ all three spellings agree to the verse |
| `.*eous` | >0, incl. Genesis 7:1 | ✅ a leading wildcard still prefilters on `eous` |
| `.?` | 11538 | ✅ no literal to filter on, so the whole corpus is scanned |

### 2.3 Gaps inside a phrase

| Query | Count | Verdict |
|---|---|---|
| `'faith * christ` | 6 | ✅ |
| `'faith *3 christ` | 10 | ✅ monotonic in the width |
| `'jesus * * christ` | 3 | ✅ two independent gaps |
| `'* and * of god` | 9 | ✅ a gap may open the phrase |
| `'grace *5 faith` | 1 | ✅ Ephesians 2:8 |
| `'the lord *0 god` | = `'the lord god` | ✅ `*0` is a ceiling, not a floor |
| `'and *1 shall call his name` | incl. Isaiah 7:14 + Matthew 1:23 | ✅ the quotation survives an inserted word |
| `'then *50 language` | 5 | ❌ **defect D** — misses Esther 8:9 |
| `'then *89 language` | 7 | ✅ after the fix; before it, refused nothing and searched 50 |

### 2.4 Compound searches (bwh16's own worked example)

| Query | Count | Verdict |
|---|---|---|
| `(.grac* work*;5).(/jesus christ)` | 24 | ✅ |
| `(.grac* work*;5).15(/jesus christ)` | 159, groups `[116, 1208]` | ✅ the 135 extra share no word with the other group |
| `(/jesus christ).15(.grac* work*;5)` | 82 | ✅ order matters, and the echo says which side it lists |
| `(.grac* work*;5)/(/jesus christ)` | 1300 | ✅ = 116 + 1208 − 24, exactly |
| `(.grace).(.nonexistentword)` | 0, groups `[159, 0]` | ✅ an empty half is nameable |

### 2.5 Non-ASCII

| Query | Edition | Count | Verdict |
|---|---|---|---|
| `.爱 神` | cuvs-plus | 159 | ✅ two Chinese words |
| `.爱神` | cuvs-plus | 14 | ✅ and the compound is not the same query |
| `'神说要有光` | cuvs-plus | 1 | ✅ 创世纪 1:3 |
| `.θεός` | lxxwh | 1611 | ✅ |
| `.θεος` | lxxwh | 1611 | ✅ #321's fold works from the accented side |
| `'ὁ θεός` | lxxwh | 1473 | ✅ |
| `'ο θεος` | lxxwh | 1473 | ✅ and from the unaccented side |
| `.ΘΕΌΣ` | lxxwh | **0** | ❌ **defect B** — see §5 |

### 2.6 Malformed input gets a sentence, not an empty list

Ticket #295 names this as a silent-lie case in its own right. All of
these produce a named issue rendered in the reader's locale; none returns
an empty result list.

| Query | Issue |
|---|---|
| `.` `'` `;` `/` | `emptyBody` |
| `~word` | `regexUnsupported` |
| `=word` | `fuzzyUnsupported` |
| `.@G25` | `strongsTagUnsupported` |
| `'a !神爱 b` | `phraseNotMultiToken` — two tokens, no single slot to invert |
| `;a b;177` | `contextTooLarge` |
| `'a *203 b` | `gapTooLarge` (new — see §4) |
| `(.a).177(.b)` | `contextTooLarge` |
| `(.a` | `compoundUnclosed` |
| `(.a)(.b)` | `compoundSeparator` |
| `(a b).(.c)` | `compoundGroupOperator` |
| `(.a)…(.g)` | `compoundTooManyGroups` |

Two rows in this table were wrong when first written, from memory of the
sweep rather than from a run, and the test caught both. A bare `@G25` is
**not** `strongsTagUnsupported` — `@` is a tag *within* a word list, so
it is caught in the body of a command and a bare `@G25` was never a
command at all. And `'a !b c` parses fine: `phraseNotMultiToken` fires
only when the negated term is more than one token.

Every `CommandIssue` except `notACommand` now has a finished sentence in
`en`, `zh-Hans` and `zh-Hant`, asserted by test — including that no
`{max}` placeholder survives unsubstituted, which is the mistake the new
`gapTooLarge` string would otherwise have shipped with. `notACommand` is
null on purpose: the line was never a command, so the plain substring
scan takes it.

### 2.7 Punctuation the grammar does not own

Worth writing down because it looks like a bug and is not.

| Query | Count | Why |
|---|---|---|
| `.god$` `.god+` `.(god)` `.^god` | 3877 each | punctuation is transparent to the tokenizer on **both** sides, so these read as `.god` |
| `.g$d` `.go+d` | 0 | but a term is a run of word characters, so an *interior* symbol splits it rather than vanishing |
| `.\bgod` | 0 | the `b` fuses into `bgod` |
| `.[]` `.{}` `.g[]d` | 0 | `[` and `{` *are* grammar; an empty character set matches nothing, and does not throw |

No regex is ever compiled from reader input.

---

## 3. Defect C: an apostrophe at the edge of a word

`phraseTokens` strips apostrophes from a token's edges, so the corpus
token behind the printed word `sons'` is `sons`. The query side kept its
apostrophe. The two could never meet.

`.sons'` returned **0**. The KJV prints `sons'` in 24 verses.

Measured across the shipped editions, by verses containing at least one
word with an edge apostrophe:

| Edition | Verses | Distinct forms |
|---|---|---|
| kjv | 212 | 68 |
| kjvs | 214 | 69 |
| nasb | 428 | 60 |
| nasb-ev | 936 | 59 |
| nsn-plus | 936 | 59 |
| leb | 158 | 42 |
| bsb | 82 | 26 |

Fixed by trimming edge apostrophes on the query side, which is what the
corpus side already did. It is **not** a widening: the 24 verses were
always inside the answer and were being withheld, and `hits(".sons'")`
is now equal to `hits('.sons')` element for element (956).

The trim is edges only, so a singular possessive does not collapse into
its stem: `.god's` = 25 and `.lord's` = 26, both unchanged.

---

## 4. Defect D: a clamp is not a refusal

`*N` above 50 was rewritten to 50 and nothing was said. Its sibling `;N`
above 176 returns a named issue. The reader could not tell the two apart
because only one of them told them anything.

I first probed eight queries, found no difference, and wrote that the
clamp never bit. **That was wrong**, and a refuter found the
counterexample: KJV **Esther 8:9**, 90 tokens, `then` at position 0 and
`language` at position 89.

```
'then *50 language  → 5 verses, no Esther 8:9
'then *89 language  → 7 verses, including Esther 8:9
```

782 KJV verses are longer than 50 tokens, so the clamp was well inside
real text.

The new ceiling is **202**, the longest verse in any shipped edition
(`lxxwh` 1 Kings 16:28, measured with the real tokenizer across every
edition in `assets/`). Above that the number cannot change an answer, so
it is refused by name — the new `CommandIssue.gapTooLarge` — rather than
rewritten.

Width is free, which is what makes the real number affordable:
`_matchFrom` clamps each gap to the tokens actually remaining in the
verse, so a wide gap buys reach and not work. Measured on the worst
multi-gap phrase (the commonest word three times, two gaps) over
`lxxwh`'s 30,800 verses: **350 ms at `*400`, 355 ms at `*50`.** Flat.

---

## 5. Defect B: the Greek final sigma — found, fixed, withdrawn

**The finding stands. The fix does not ship.** This section is the record
of why, because the finding will be re-found.

`foldDiacritics` does not map `ς` (U+03C2) to `σ` (U+03C3). Every caller
then lower-cases, and Dart's simple case mapping sends `Σ` to `σ` and
never to `ς`. So an all-caps Greek word ending in sigma can never match a
corpus word ending in final sigma:

```
.θεός   → 1611        .ΘΕΌΣ   → 0
.κύριος → 3219        .ΚΎΡΙΟΣ → 0
```

Reach of the problem: `lxxwh` contains **115,332 word-final ς** across
**9,411 of its 42,952 distinct forms.**

A fix in `scripts/build_diacritics_table.py` works — with `ς→σ` in the
table, every uppercase form above returns its correct count.

It was reverted for two reasons, in order of weight:

1. **It introduces 48 new false positives** in the reader-facing plain
   substring scan. Folding final sigma to medial makes `Ἰησοῦς` match
   inside `ποιησουσιν` ("they shall make"), which contains the letter
   sequence `ιησουσ` in the middle of the word — Exodus 18:20, 21:31,
   28:3, 28:4 and 28:6 among them. A reader searching for *Jesus* would
   be shown verses about making furniture for the tabernacle.
2. **The benefit's reach is near zero in practice.** A refuter checked
   `assets/strongs/greek.json`, `assets/lxxwh.json` and
   `assets/thayer.json`: **there is no all-caps Greek anywhere in any of
   them**, nothing in the app displays majuscule Greek, and the
   title-case form a reader would actually type (`.Θεός`) already
   worked.

Two narrower fixes were considered and rejected. Folding only at a word's
end still collides, because `ποιησουσιν` has the sequence medially.
Folding only on the token path breaks the prefilter, which is a superset
by contract, and would lose hits.

#321's rule holds and decided this: over-matching shows a reader a verse
they can check; under-matching tells them a word is not in the Bible. But
here the under-match is a form nothing displays and the over-match is a
wrong verse in the reading text, so the sign flips.

The conservative option was taken and is being reported rather than
guessed at, per the standing instruction for unattended runs.

---

## 6. The live pass — everything §6 used to defer

2026-09-03, driven against **dev v1.6.223** in a real browser at
1400x900, in both English and Simplified Chinese. Every row below is a
thing this document previously said "needs a human at a browser". All
seven were driven; none of them needed a code change.

| What | Driven | Result |
|---|---|---|
| Reference navigation, qualified | `3:16` from John 3 | ✅ went to **John 3:16**, URL became `#/john/3:16?v=bsb`, and the Analysis pane opened that verse's word study unasked |
| Reference navigation, bare | `17` from John 3 | ✅ **John 3:17** — completed from where the reader was, exactly as `goToReference` claims |
| `l gen` narrowing | `l gen`, then `.god` | ✅ **199 verses, all Genesis** (unscoped BSB is 3866) |
| …and the narrowing being VISIBLE | same | ✅ **twice**: a banner over the results reading "Limited to Genesis (1533)", and the status bar's `Limits` chip changing from grey to **`Limits: Genesis`** |
| Lifting it | bare `l` | ✅ banner gone, chip grey again, and the search **re-ran unscoped by itself** — 3866 |
| `d nas` | `d nas` | ✅ **refused by name**: "No edition called \"nas\". Available: KJV · LEB · BSB · KJV+S · …". Not a silent literal search. (NASB is in `disabledVersions`; LEB is listed, which is the state after it was restored.) |
| `d leb` / `d c` | both | ✅ stack became `BSB · KJV · KJV+S · LEB` with a "Loading edition · LEB" line, then `d c` returned it to `BSB` |
| `p a b c` | `p kjv bsb leb` | ✅ stack set — **but it came back `BSB · KJV · LEB`, not the typed order.** See below. |
| Strong's proximity | `G25 NEAR5 G26` | ✅ **6 verses, and the right six**: John 15:9, John 17:26, Ephesians 2:4, Ephesians 5:2, 1 John 4:7, 1 John 4:10 |
| A capped list admitting the cap | `.the` | ✅ nothing to admit — **22,406 verses, all of them listed and scrollable.** The plain text path has no cap; the cap this row was written about is the Strong's one, already pinned by test |
| The same under a Chinese UI | `G25 NEAR5 G26` in zh-Hans | ✅ header renders **「G25 NEAR5 G26 — 共 6 节」** un-truncated; menus, operator hints, word-card glosses and status bar all render, no absent text |
| Operator-strip caret sequencing | `.god`, then the `OR` button, then typing | ✅ produced `.god OR love` — **focus and caret return to the field**, so typing continues where the reader expects |

### One thing to check, and one non-finding

**`p kjv bsb leb` returned `BSB · KJV · LEB`.** `CommandVerbKind.displaySet`
is documented as "replace the stack with exactly these, **in this
order**", and BSB — the search version — came back first regardless.
That is probably the always-displayed invariant putting the search
version at the head, which would make the doc comment imprecise rather
than the code wrong. **Not investigated, not filed as a defect**: it is
recorded here so the next reader checks it against
`displaySet` rather than re-discovering it.

**The Enter key is NOT a finding.** Pressing Return via the automation
never submitted, while the magnifier button always did — and
`command_pane.dart:769` wires `textInputAction: TextInputAction.search`
with `onSubmitted: (_) => _submit()`. Synthetic key events do not reach
Flutter web's hidden text input reliably, so this is an artifact of the
instrument. It is written down because the raw observation looks exactly
like a real defect, and the next person to drive this box will see it
too.

**How the instrument was checked.** The first three queries appeared to
do nothing, which looked like broken reference navigation. A control —
`.melchizedek`, a query with a known answer — also did nothing, which is
what proved the fault was the harness and not the app. With the button
instead of Return, `.melchizedek` returned **14 verses** and every row
above followed.

## 7. Where the claims live

- `test/command_grammar_audit_test.dart` — this pass: the sweep's counts,
  and the three fixes.
- `test/search_audit_295_test.dart` — the first pass's three fixes.
- `test/command_query_corpus_test.dart` — the whole-KJV answers the
  grammar is expected to give, including the prefilter's "never costs a
  hit" contract.
- `test/command_query_test.dart` — the mechanics, on a six-verse fixture.
- `test/strongs_query_diagnosis_test.dart` — #295's other half: a
  malformed Strong's expression (`G25 NEAR G26`, a missing distance, an
  out-of-range number, a trailing operator) is now named as a refusal
  instead of silently running as a literal text search that finds
  nothing.
