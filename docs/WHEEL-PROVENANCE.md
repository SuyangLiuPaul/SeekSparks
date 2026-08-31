# Where the chronology wheel's dates come from

Written 2026-09-01, covering the 76 events added to
`assets/wheel_history.json` in commits `7446e4e`, `1496fef` and `b4013fa`.

> "Every power, and every event after the close of scripture, carries a
> conventional, widely published date; **none was taken from any copyrighted
> chart.** The whole file was audited entry by entry before it shipped."
> — `wheel_history.json`, `_meta.provenance`, shipped in three languages

## Why this document exists

That sentence is a promise to the reader, and until this file existed it was
**asserted and not evidenced.** The wheel's schema has no per-entry source
field — `basis: "conventional"` says only *what kind* of date it is, never
*whose*. So for seventy-six new records the audit trail lived in a session
transcript and two temporary files, and would have been gone by the time anyone
thought to check.

The occasion was specific. This work began as an extraction of a **printed,
in-copyright world-history chart** (© 2012 Bible Charts and Maps, LLC), which
was read out in full and then checked fact by fact. It was used as a **checklist
of topics and for nothing else**; every date here was sourced independently. But
"we didn't copy it" is exactly the kind of claim that has to be demonstrable
rather than remembered, and the chart itself is the argument for why: checked
against the KJV and against general references, **it carries sixteen errors**,
including a pope numbered VII where the man was IX, Quebec founded in 1609 by
Hudson, and St. Augustine marked French. Two of the records below exist
specifically to state those correctly.

## What was checked, and how

Each of the four groups was audited by a reader working only from the shipped
record — its year, its English title, its English description, its
`approximate` flag — and required to find each fact in a general reference it
actually fetched: Britannica, national archives, national parliaments,
university and institute document editions, museum and UNESCO pages, and the
public-domain Catholic Encyclopedia. **A chart, a timeline poster or an
aggregated "history timeline" site was not an acceptable source for anything.**

Three things were checked per record, not one:

1. **the year** — does the reference give it;
2. **every claim in the description** — names, figures, nationalities, and the
   further dates that appear in second clauses;
3. **the `approximate` flag** — `false` on a genuinely disputed date is a defect,
   and so is `true` used to hedge a firm one.

Disagreements are recorded below as disagreements. An audit that reports
everything correct is worth nothing unless it was capable of reporting
otherwise.

## The eight corrections the audit produced

The audit was run **after** these records shipped, by readers who had only the
shipped text, and it refuted eight claims. All eight are now fixed in the asset;
they are listed here rather than quietly corrected, because a provenance
document that records only successes is not evidence of anything.

| Record | What it said | What the reference says |
|---|---|---|
| `haiti_independence` | "the second **republic** in the Americas" | Dessalines proclaimed independence in January 1804 as governor-general and took the title Emperor in September. **The second independent country**, not republic. |
| `desoto_mississippi` | "the first Europeans to **record** the great river" | Alvarez de Pineda named and mapped its mouth in 1519, twenty-two years earlier. De Soto's party were the first to **see and cross it inland**. |
| `us_constitution_signed` | "a bill of rights that opens with **the free exercise of** religion" | The First Amendment opens with the establishment clause; free exercise is the second. Now simply "opens with religion". |
| `balboa_pacific` | "learns that the new land is **not the edge of Asia**" | Unsupported, and anachronistic beside our own 1507 entry. Now "finds that a further ocean lies between the new land and Asia". |
| `battle_of_vouille` | "the Visigothic kingdom **withdraws beyond the Pyrenees**" | It kept Septimania, on the Gaulish side, until 719-720. |
| `charlemagne_takes_lombardy` | "now rules **Italy** as well as Gaul" | Northern and central Italy. Benevento stayed effectively independent; the far south and Sicily stayed Byzantine. |
| `augustine_mission_to_kent` | "**forty** monks" | Bede says "nearly forty"; Britannica and Canterbury Cathedral say "about 40". The figure is right, the certainty was not. |
| `providence_founded`, `ostrogothic_italy` | *(not a fact error)* | Their Chinese labels were too long for the wheel to draw whole; shortened, with the detail moved into `desc`. See `b4013fa`. |

**Not corrected, but recorded.** Judgements the auditors raised and left standing,
so a later reader can revisit them rather than rediscover them:

* `pippin_king_of_franks` (751) is not flagged approximate, and it is the weakest
  such flag here: Britannica's main article and the *New Catholic Encyclopedia*
  both give November 751 at Soissons, but Britannica's own summary page for
  Pippin III gives 752.
* `battle_of_ayacucho` says the battle completed the independence of Spanish
  South America, where Britannica says it "ensured" it; the last Spanish troops
  left Callao in January 1826.
* The **site** of Vouille (Vouille or Voulon) is genuinely disputed; the year is
  not. The 911 grant of Normandy has no contemporary documentation - Dudo of
  Saint-Quentin, about 1015, and a charter of 918 referring back to it.

## Two chart corrections, verified from scratch

Two records exist because the printed chart is wrong about them, so they were
re-checked from the sources rather than from the correction:

* **Quebec, 1608, Samuel de Champlain.** The chart has "1609 Quebec founded by
  Hudson". Confirmed against Britannica, the Canadian Museum of History and
  UNESCO; Hudson's 1609 voyage was a different expedition on a different river.
* **St. Augustine, 1565, Spanish.** The chart marks it "(Fr.)". Confirmed against
  the National Park Service: Pedro Menendez de Aviles founded it under the
  Spanish crown, and the French presence in Florida was the rival Fort Caroline
  he had been sent to destroy. "Forty-two years before Jamestown" is the NPS's
  own figure.

---

# Group 1 - the Americas (27 records, commit 7446e4e)

## Americas — source list and factual audit

**27 records** from `assets/wheel_history.json` (Americas track), audited 2026-09-01.

Every record below was checked against a general reference that was actually fetched and read: UNESCO World Heritage Centre nomination texts, the US National Park Service, the US National Archives, the US Department of State Office of the Historian, the Library of Congress, the City of New York (DCAS), Pilgrim Hall Museum, the Florida Museum of Natural History (University of Florida), the University of Virginia Salem Witch Trials Documentary Archive, the Canadian Museum of History / Virtual Museum of New France, the Texas State Historical Association's *Handbook of Texas*, and Encyclopaedia Britannica. No chart, timeline poster or aggregated "history timeline" site was used as a source for any date or figure.

Three checks were made per record: the **year**, **every factual claim in the description** (names, numbers, nationalities, consequences, and any second clause carrying a further date or figure), and the honesty of the **`approximate` flag**.

---

### Disagreements found

Four claims do not survive checking, and are stated plainly here:

1. **`haiti_independence` (1804) — "the second republic in the Americas" is wrong.** Haiti was not a republic in 1804. Dessalines proclaimed independence on 1 January 1804 as *governor-general*, and in September 1804 took the title of Emperor Jacques I (Britannica). The US State Department's own formulation is "the second independent country in the Americas." **Correct value: "the second independent country in the Americas."**

2. **`desoto_mississippi` (1541) — "The first Europeans to record the great river" is overstated.** Alonso Álvarez de Pineda registered and named the river Río del Espíritu Santo on 2 June 1519 and his pilots produced the first known map of the Gulf coast (*Handbook of Texas*) — 22 years earlier. De Soto's party were the first Europeans known to have *seen the river inland and crossed it*. **Correct value: "the first Europeans to see and cross the great river inland."**

3. **`us_constitution_signed` (1787) — "a bill of rights that opens with the free exercise of religion" is inaccurate.** The First Amendment opens with the establishment clause; free exercise is the *second* clause: "Congress shall make no law respecting an establishment of religion, or prohibiting the free exercise thereof" (National Archives transcript). **Correct value: "…that opens with religion" or "…with the establishment and free exercise of religion."**

4. **`balboa_pacific` (1513) — "learns that the new land is not the edge of Asia" is unsupported and anachronistic.** Britannica records only that Balboa sighted and took possession of the Mar del Sur; it makes no such inference. And the record's own 1507 entry already credits Vespucci and Waldseemüller with separating America from Asia six years earlier — the Waldseemüller map showed South America separated from Asia *before* any European reached the Pacific. **Correct value: "and finds that a further ocean lies between the new land and Asia."**

#### Reference divergences (record is defensible; flagged for the record)

- **`chavin_de_huantar`** — the record's "900 to 200 BC" is Britannica's periodization. UNESCO gives **1500–300 BC** for the same culture. Both are widely published; `approximate: true` covers it.
- **`new_amsterdam_founded`** — NYC.gov gives **1625**; NPS gives **1624**. The record uses 1625 and is marked approximate, which is the honest handling.

#### Smaller imprecisions (not defects, noted for completeness)

- `nazca_lines` — per UNESCO it is the *geometric figures and lines* that run several kilometres; the animal and plant figures are large but far shorter.
- `salem_witch_trials` — the conventional total of twenty put to death is 19 hanged plus Giles Corey pressed to death; Britannica and UVA phrase these as nineteen executions plus one death under torture.
- `battle_of_ayacucho` — Britannica says Ayacucho "ensured" independence; the last Spanish forces did not leave Callao until January 1826.

*(Note on the source file, not on the data: the entries list `haiti_independence` (1804) before `louisiana_purchase` (1803). Sections below are in year order.)*

---

#### -900 · chavin_de_huantar
- https://whc.unesco.org/en/list/330/
- https://www.britannica.com/topic/Chavin

**Year** DISPUTED between references, record defensible — Britannica: Chavín "flourished between about 900 and 200 bc," so -900 is the start of Britannica's range. UNESCO instead dates the culture "between 1500 and 300 B.C." (and "between the 15th and the 5th century BC"). The record follows Britannica; both are conventional and widely published.

**Claims**
- "A stone temple complex" — confirmed. UNESCO: "This former place of worship… complex of terraces and squares, surrounded by structures of dressed stone."
- "in the northern Peruvian highlands" — confirmed. Britannica: "Chavín de Huántar in the northern highlands of the Peruvian Andes." UNESCO locates it in the province of Huari, department of Áncash.
- "anchors the earliest widely shared culture of the Andes" — confirmed. UNESCO: "one of the earliest and best known pre-Columbian sites"; "an important centre of ideological, cultural and religious convergence and dissemination around a cult spread over a wide territory of the Andes."
- "about 900 to 200 BC" — Britannica confirms; UNESCO gives 1500–300 BC (see above).

**approximate: true** — correct, and necessary. The references disagree by six centuries on the start date.

---

#### -500 · nazca_lines
- https://whc.unesco.org/en/list/700/

**Year** confirmed — UNESCO: the lines "were scratched on the surface of the ground between 500 B.C. and A.D. 500." -500 is the start of the range UNESCO states.

**Claims**
- "Animals, plants and figures kilometres long" — partly imprecise. UNESCO: the geoglyphs "depict living creatures, stylized plants and imaginary beings, as well as **geometric figures several kilometres long**." The kilometre scale belongs to the lines and geometric figures, not to the animal and plant figures.
- "scratched into the desert floor" — confirmed, UNESCO's own verb ("scratched on the surface of the ground"), on the arid Peruvian coastal plain.
- "between 500 BC and AD 500" — confirmed verbatim.
- "still not fully explained" — confirmed. UNESCO: "among archaeology's greatest enigmas"; "They are believed to have had ritual astronomical functions."

**approximate: true** — correct. A single year is being taken from a thousand-year range.

---

#### 1050 · cahokia_rises
- https://whc.unesco.org/en/list/198/

**Year** confirmed — UNESCO: the population peak was "between 1050 and 1150." 1050 is the start of the peak UNESCO names.

**Claims**
- "Largest city north of Mexico" (title) / "A mound city" — confirmed. UNESCO: "the largest pre-Columbian settlement north of Mexico"; some 120 mounds over more than 1,600 hectares.
- "on the Mississippi" — loose but conventional; UNESCO places it in Collinsville, Illinois, "some 13 km north-east of St Louis, Missouri," in the Mississippi floodplain.
- "perhaps twenty thousand people at its height" — confirmed as the top of UNESCO's range: "may have had a population of 10,000–20,000 at its peak." The record's "perhaps" correctly hedges an upper bound.
- "the size of a large European city of the day" — confirmed, slightly strengthened. UNESCO: "equivalent to the population of many European cities at that time."

**approximate: true** — correct. UNESCO gives a hundred-year peak window and a two-to-one population range.

---

#### 1500 · cabral_brazil
- https://www.britannica.com/biography/Pedro-Alvares-Cabral

**Year** confirmed — Britannica: Cabral is "generally credited as the first European to reach Brazil (April 22, 1500)."

**Claims**
- "A Portuguese fleet" — confirmed. Cabral was Portuguese, "named admiral in supreme command of 13 ships, which set out from Lisbon on March 9, 1500."
- "bound for India" — confirmed: "the second major expedition to India," following da Gama's route around the Cape of Good Hope.
- "makes landfall in the west and claims the coast" — confirmed: "on April 22 Cabral sighted the land he named Island of the True Cross… he took formal possession of the country."
- "dividing the continent's future between two crowns" — confirmed. Britannica: the lands "belonged to them in accordance with the Treaty of Tordesillas (1494), which divided the still almost completely unknown New World between Spain and Portugal."
- *Caveat noted, not a defect:* Britannica adds that Vicente Yáñez Pinzón "may have reached Brazil slightly earlier in 1500." The record does not claim priority, only landfall and claim.

**approximate: false** — correct. 22 April 1500 is a firm, conventionally published date.

---

#### 1507 · waldseemuller_map
- https://www.britannica.com/biography/Martin-Waldseemuller
- https://www.britannica.com/biography/Amerigo-Vespucci

**Year** confirmed — Britannica: Waldseemüller "in 1507 published the first map with the name America for the New World."

**Claims**
- "Waldseemuller's world map prints the name America" — confirmed: "in 1507 he published 1,000 copies of a woodcut world map, made with 12 blocks"; "in which the name America appears for the first time."
- "after Amerigo Vespucci" — confirmed: "he named the New World in Vespucci's honour," proposing "ab Americo Inventore… quasi Americi terram sive Americam."
- "who had argued the land was a continent and not Asia" — confirmed. Britannica: "Vespucci himself, and scholars as well, became convinced that the newly discovered lands were not part of Asia but a 'New World.'"
- *Caveat noted, not a defect:* Britannica adds the name was at first "applied only to South America." The record does not claim otherwise.

**approximate: false** — correct. 1507 is the firm imprint date of the map.

---

#### 1513 · balboa_pacific
- https://www.britannica.com/biography/Vasco-Nunez-de-Balboa

**Year** confirmed — Britannica: Balboa was "the first European to sight the eastern shore of the Pacific Ocean (on September 25 [or 27], 1513, from 'a peak in Darién')."

**Claims**
- "Crossing the isthmus" — confirmed: Darién, on the Isthmus of Panama; he "return[ed] across the isthmus to Santa María in January 1514."
- "a Spanish party" — confirmed: Balboa was a Spanish conquistador; he "took possession of the Mar del Sur (South Sea) and the adjacent lands for the king of Castile."
- "sees the ocean on the far side" — confirmed.
- **"and learns that the new land is not the edge of Asia" — DISAGREEMENT.** Britannica makes no such claim for Balboa; it records only the sighting and the claiming of the Mar del Sur. The inference is also anachronistic within this record set: Waldseemüller's 1507 map (the previous entry) already showed South America separated from Asia, six years before anyone reached the Pacific. **Correct value: the sighting showed that a further ocean lay between the new land and Asia.**

**approximate: false** — correct on the year; Britannica's only uncertainty is between 25 and 27 September, which does not affect the year.

---

#### 1541 · desoto_mississippi
- https://www.britannica.com/biography/Hernando-de-Soto
- https://www.tshaonline.org/handbook/entries/alvarez-de-pineda-alonso
- https://encyclopediaofarkansas.net/entries/mississippian-period-544/

**Year** confirmed — Britannica: "On May 21, 1541, the Spaniards saw for the first time the Mississippi River… south of Memphis, Tennessee. They crossed the river."

**Claims**
- **"The first Europeans to record the great river" — DISAGREEMENT.** Britannica credits de Soto with the European discovery, but the *Handbook of Texas* records that Alonso Álvarez de Pineda "registered a mighty river and named it Río del Espíritu Santo (the Mississippi River)" on 2 June 1519, and that his pilots produced "the first known map of the Gulf." De Soto's party were the first Europeans known to see and cross the river inland. **Correct value: "the first Europeans to see and cross the great river inland."**
- "cross it in the south" — confirmed: they crossed south of Memphis and "made their way through Arkansas and Louisiana."
- "the expedition leaves disease behind it that reshapes the interior" — confirmed. Encyclopedia of Arkansas: Mississippian culture "was in full flower in Arkansas when the de Soto expedition traveled through eastern Arkansas in 1541. By the time the next Europeans arrived… the flourishing Mississippian towns were gone. European diseases and severe, long-lasting drought in the 1500s both undoubtedly played roles." Note the reference names drought as a co-factor alongside disease.

**approximate: false** — correct. 21 May 1541 is a firm date.

---

#### 1565 · st_augustine_founded
*(Written to correct a printed chart that marked this settlement French. Verified from scratch: it is Spanish.)*
- https://www.nps.gov/places/st-augustine-town-plan-historic-district-st-augustine-florida.htm
- https://www.nps.gov/foma/learn/historyculture/index.htm
- https://www.floridamuseum.ufl.edu/staugustine/

**Year** confirmed — NPS: "On a September day in 1565, Spanish Explorer Don Pedro Menéndez de Avilés sailed into Matanzas Bay and established the colony of St. Augustine." NPS (Fort Matanzas) independently: "1565, the year of the founding of St. Augustine."

**Claims**
- **"A Spanish expedition" — confirmed, and the chart's "French" is wrong.** NPS names Menéndez de Avilés, sailing under orders from the Spanish crown; NPS elsewhere calls St. Augustine and the Castillo de San Marcos "outstanding reminders of the might of the early Spanish empire." (The French presence in Florida was the rival Huguenot Fort Caroline, which Menéndez was sent to destroy.)
- "the oldest continuously occupied European settlement in what is now the United States" — confirmed verbatim. NPS: "The city is the oldest continuously occupied European settlement in the continental United States."
- **"forty-two years before Jamestown" — confirmed, and arithmetically exact.** NPS: St. Augustine "predates English colonization at Jamestown (1607) by 42 years." 1607 − 1565 = 42.

**approximate: false** — correct. 8 September 1565 is a firm, documented founding date.

---

#### 1607 · jamestown_founded
- https://www.nps.gov/jame/learn/historyculture/a-short-history-of-jamestown.htm
- https://historicjamestowne.org/history/jamestown-timeline/

**Year** confirmed — NPS: "In 1607, 104 English men and boys arrived in North America to start a settlement," landing on Jamestown Island on 14 May 1607.

**Claims**
- "The first lasting English settlement in North America" — confirmed. NPS: "The settlement became the first permanent English settlement in North America." (Roanoke, 1587, had failed.)
- "most of its first colonists died within a year" — confirmed. 104 arrived; the Historic Jamestowne timeline records that "the number of English settlers in Virginia falls to 38" by the winter of 1607–08 — about 63% dead inside the first year. "Most" is correct and, if anything, understated.

**approximate: false** — correct. 14 May 1607 is a firm date.

---

#### 1608 · quebec_founded
*(Written to correct a printed chart that gave 1609 and credited Hudson. Verified from scratch: 1608, and Champlain — 1609 was Henry Hudson's Dutch-sponsored voyage up the river that bears his name, a different event on a different river.)*
- https://www.britannica.com/place/Quebec-province/History
- https://www.historymuseum.ca/virtual-museum-of-new-france/the-explorers/samuel-de-champlain-1604-1616/
- https://whc.unesco.org/en/list/300/

**Year** confirmed — Britannica: "Permanent European settlement of the region began only in 1608, when Samuel de Champlain established a fort at Cape Diamond, the site of present-day Quebec city." Virtual Museum of New France (Canadian Museum of History): "on the third of July, 1608, he founded what was to become Quebec City."

**Claims**
- **"Champlain" — confirmed, and the chart's "Hudson" is wrong.** All three references name Samuel de Champlain.
- "A fur-trading post" — confirmed. Virtual Museum of New France: "He immediately set about building his Habitation (residence)," established "as a strategic center for the fur trade and as a base for exploring westward."
- "below the cliff at Cape Diamond" — confirmed. Britannica: "a fort at Cape Diamond." UNESCO: the Upper Town sits "atop Cap Diamant," while "the Lower Town… grew up around Place Royale and the harbour" — the Habitation site, at the foot of the cliff.
- "becomes the base of New France" — confirmed. Britannica: "New France began with the founding of three cities—Quebec city in 1608, Trois-Rivières in 1616, and Montreal in 1642." UNESCO: "it was the capital of New France."
- "the oldest French city in the Americas" — defensible. The Canadian Encyclopedia calls Quebec "the first permanent French settlement in Canada" and "the oldest city in Canada." *Caveat:* Champlain's Port-Royal (1605, Nova Scotia) is an older French *settlement*; the word "city" is doing the work in this claim, and correctly so — Port-Royal never became one.

**approximate: false** — correct. 3 July 1608 is a firm, documented date.

---

#### 1620 · mayflower_compact
- https://www.pilgrimhall.org/the-mayflower-compact/
- https://www.britannica.com/topic/Mayflower-Compact

**Year** confirmed — signed 21 November 1620 New Style (11 November Old Style). The year is 1620 either way.

**Claims**
- "Before landing" — confirmed. Pilgrim Hall Museum: signed aboard ship, anchored in Provincetown Harbor off Cape Cod, "before the Pilgrims landed and established Plymouth."
- "the passengers bind themselves by signed agreement" — confirmed: 41 signatures appear on the document. Britannica: signed by 41 adult male passengers, drafted because the colonists "were no longer within the jurisdiction of their charter."
- "into a civil body politic" — confirmed as the document's own words: they would "combine our selves together into a civil body politic, for our better ordering and preservation."
- "an early written basis for self-government" — confirmed. Britannica: it "served as the foundation for Plymouth's government until 1691 and is viewed as a key step in the evolution of American democratic government."

**approximate: false** — correct. The date is firm; only the Old Style/New Style day differs, not the year.

---

#### 1625 · new_amsterdam_founded
- https://www.nyc.gov/site/dcas/about/green-book-important-nyc-dates.page
- https://www.nps.gov/mava/learn/historyculture/new-netherland.htm

**Year** DISPUTED between references, record defensible — **the City of New York's own official date list gives 1625**: "1625 Town of Nieuw Amsterdam becomes seat of government for Nieuw Netherlands. Peter Minuit appointed first Director-General by Dutch West India Company." **The National Park Service gives 1624**: "The first 31 families arrived in the harbor of the North River in 1623… and by 1624, the colony of 'New Amsterdam' began to be formed." The record uses 1625, which is NYC's figure.

**Claims**
- "The Dutch West India Company settles the tip of the island" — confirmed. NYC.gov names the Dutch West India Company and its first Director-General in the 1625 entry; the New Netherland Institute locates Fort Amsterdam "in the south point of Manhattan island."
- "the town is surrendered to England in 1664" — confirmed. NYC.gov: "1664 Peter Stuyvesant turns town and fort over to British." NPS: "Peter Stuyvesant surrendered the colony to English forces in 1664 without anyone firing a shot in anger."
- "and renamed New York" — confirmed. NYC.gov, same entry: "Nieuw Amsterdam renamed New York."

**approximate: true** — correct, and this is exactly the case the flag exists for. References genuinely split between 1624 and 1625.

---

#### 1636 · providence_founded
- https://www.nps.gov/articles/000/roger-williams-rebel-revolutionary-radical.htm
- https://www.britannica.com/biography/Roger-Williams-American-religious-leader

**Year** confirmed — Britannica: Williams "established the settlement of Providence on Narragansett Bay in June 1636." NPS: in the spring after his winter with the Wampanoag, "Williams and some of his followers moved to the land that would become Providence."

**Claims**
- "Banished from Massachusetts" — confirmed. Britannica: in 1635 Williams "was tried by the General Court of the Massachusetts Bay Colony and found guilty of holding four dangerous opinions… resulting in his sentence of banishment." NPS: he "fled Massachusetts in October 1635 to avoid arrest." *Note:* the sentence fell in 1635; the founding of Providence is 1636. The record dates the founding, correctly.
- "for holding that the magistrate has no authority over conscience" — confirmed, closely. NPS: he was accused of "new and dangerous opinions against the authority of the magistrates" because he argued certain religious laws "were not to be enforced by the government. Instead, they were matters of individual conscience, or liberty." Britannica: he was banished for "holding that magistrates had no right to interfere in matters of religion."
- "he founds a colony on that principle" — confirmed. Britannica: Providence "soon became a haven for religious dissidents"; Williams later published *The Bloudy Tenent of Persecution* setting out "his influential views on religious liberty and the separation of church and state."

**approximate: false** — correct. June 1636 is the conventionally published founding.

---

#### 1682 · la_salle_louisiana
- https://www.loc.gov/item/2021668651
- https://www.britannica.com/biography/Rene-Robert-Cavelier-sieur-de-La-Salle
- https://64parishes.org/entry/la-salle-expeditions

**Year** confirmed — Library of Congress item title: "Taking Possession of Louisiana and the Mississippi River, in the Name of Louis XIVth, by Cavelier de La Salle… on April 9, 1682." His party planted a post reading "Louis the Great, King of France and of Navarre, Reigns Here, April 9, 1682."

**Claims**
- "Reaching the river's mouth" — confirmed: on 9 April 1682 La Salle and Tonti reached the Gulf of Mexico at the bird-foot delta.
- "he claims the whole watershed for France" — confirmed. Britannica: he "claimed all the region watered by the Mississippi and its tributaries for Louis XIV of France."
- "and names it Louisiana" — confirmed. Britannica, same sentence: "naming the region 'Louisiana.'"

**approximate: false** — correct. 9 April 1682 is a firm, documented date.

---

#### 1692 · salem_witch_trials
- https://www.britannica.com/event/Salem-witch-trials
- https://salem.lib.virginia.edu/overview.html

**Year** confirmed — Britannica: "Salem witch trials, (June 1692–May 1693)." UVA: "began in late February 1692 and lasted through April, 1693." All executions took place in 1692; 1692 is the correct anchor year.

**Claims**
- "Twenty people are executed" — confirmed as the conventional total, with a precision note. Britannica: "Nineteen persons had been hanged," and Giles Corey, refusing to plead, "had been subjected to *peine forte et dure*… and pressed beneath heavy stones for two days until he died." UVA: "nineteen were executed by hanging, one was tortured to death." Nineteen hangings plus Corey gives the standard figure of twenty put to death; both references phrase the two categories separately. At least five more died in jail and are not counted.
- "in Massachusetts" — confirmed: Salem Village, Massachusetts Bay Colony (now Danvers).
- "on spectral evidence" — confirmed. Britannica: "Most damning for them was the admission of 'spectral evidence'—that is, claims by the victims that they had seen and been attacked… by specters of the accused."
- "the colony later called the trials a wrong" — confirmed. Britannica: "In 1702 the General Court declared that the trials had been unlawful."
- "and kept a day of fasting for them" — confirmed. Britannica: "In January 1697 the General Court of Massachusetts declared a day of fasting and contemplation for the tragedy that had resulted from the trials." *(The fasting, 1697, actually preceded the unlawfulness declaration, 1702; the record does not assert an order.)*

**approximate: false** — correct. 1692 is firm.

---

#### 1787 · us_constitution_signed
- https://www.archives.gov/founding-docs/more-perfect-union
- https://www.archives.gov/founding-docs/bill-of-rights-transcript

**Year** confirmed — National Archives: "On September 17 the members met for the last time" and "the other delegates in the hall formally signed the Constitution" — 17 September 1787.

**Claims**
- "A written frame of government with separated powers" — confirmed by the document itself (Articles I, II and III vesting legislative, executive and judicial power separately).
- "ratified in 1788" — confirmed. National Archives: New Hampshire, the ninth state, ratified on 21 June 1788; the Confederation Congress received word on 2 July 1788.
- "amended in 1791 by a bill of rights" — confirmed. National Archives: "By December 15, 1791, three-fourths of the states had ratified the 10 amendments now so familiar to Americans as the 'Bill of Rights.'"
- **"that opens with the free exercise of religion" — DISAGREEMENT.** The National Archives transcript of the First Amendment reads: "Congress shall make no law respecting an establishment of religion, or prohibiting the free exercise thereof; or abridging the freedom of speech, or of the press…" The Bill of Rights opens with the **establishment** clause; free exercise is the second clause. **Correct value: "…that opens with religion," or "…with the establishment and free exercise of religion."**

**approximate: false** — correct. All three dates (1787, 1788, 1791) are firm and documented.

---

#### 1803 · louisiana_purchase
- https://www.archives.gov/milestone-documents/louisiana-purchase-treaty

**Year** confirmed — National Archives: the treaty was signed 30 April 1803.

**Claims**
- "France sells its claim to the Mississippi basin" — confirmed. The treaty text: "The First Consul of the French Republic… doth hereby cede to the United States… the said territory with all its rights and appurtenances." 828,000 square miles west of the Mississippi, for $15 million.
- "the United States doubles in size overnight" — confirmed verbatim. National Archives: "For roughly 4 cents an acre, the United States doubled its size, expanding the nation westward."
- "at the cost of the nations already living there" — an interpretive but uncontroversial clause; the ceded territory was inhabited by many Native nations whose claims France did not hold and did not extinguish. The National Archives page does not make this statement, and it is not asserted here as a sourced fact.

**approximate: false** — correct. 30 April 1803 is a firm, documented date.

---

#### 1804 · haiti_independence
- https://history.state.gov/milestones/1784-1800/haitian-rev
- https://www.britannica.com/biography/Jean-Jacques-Dessalines

**Year** confirmed — Britannica: "on January 1, 1804, Dessalines, as governor-general, proclaimed the entire island of Hispaniola an independent country under the Arawak-derived name Haiti." State Department: Haiti declared independence in 1804 (US recognition did not follow until 1862).

**Claims**
- "The only state founded by a successful revolt of the enslaved" — confirmed in substance. State Department: the Haitian Revolution emerged "out of a slave revolt." Britannica: Dessalines "was brought to the French West Indian colony of Saint-Domingue (Haiti) as a slave… in 1791… he joined the slave rebellion."
- **"and the second republic in the Americas" — DISAGREEMENT.** Haiti was not a republic in 1804. Britannica: Dessalines proclaimed independence as *governor-general*, and "The following September he adopted the title of emperor as Jacques I." The State Department's formulation is "the second independent country in the Americas after the United States became independent in 1783." **Correct value: "the second independent country in the Americas."**

**approximate: false** — correct. 1 January 1804 is a firm date.

---

#### 1810 · hidalgo_grito
- https://www.britannica.com/biography/Miguel-Hidalgo-y-Costilla
- https://www.britannica.com/topic/Treaty-of-Cordoba
- https://www.loc.gov/exhibits/mexican-revolution-and-the-united-states/independence-from-spain.html

**Year** confirmed — Britannica: "On September 16, 1810, he rang the church bell in Dolores to call his parishioners to an announcement of revolution against the Spanish… It became known as the Grito de Dolores."

**Claims**
- "A parish priest" — confirmed. Britannica: "a Roman Catholic priest and revolutionary leader who is called the father of Mexican independence"; from 1803 "parish priest in Dolores."
- "rings his church bell and calls his people to rise" — confirmed verbatim in substance (see the quoted sentence above); Britannica adds his speech "was not only an encouragement to revolt but a cry for racial equality and the redistribution of land."
- "Mexico's independence is secured in 1821" — confirmed. Juan O'Donojú signed the Treaty of Córdoba recognising Mexican independence on 24 August 1821, and independence "was consummated after Iturbide entered Mexico City at the head of his troops on September 27, 1821."

**approximate: false** — correct. Both 16 September 1810 and 1821 are firm.

---

#### 1822 · brazil_independence
- https://guides.loc.gov/brazil-us-relations/empire-of-brazil
- https://www.britannica.com/biography/Pedro-I

**Year** confirmed — Library of Congress research guide, "Empire of Brazil (1822–1889)": Dom Pedro declared Brazilian independence on 7 September 1822.

**Claims**
- "The heir to the Portuguese throne" — confirmed. Pedro was the son of King John VI of Portugal and remained in Brazil as regent when John returned to Lisbon in 1821; he later briefly reigned in Portugal as Pedro IV.
- "declares the colony independent" — confirmed: the declaration followed the Portuguese parliament's demand that he return to Lisbon.
- "and is crowned its emperor" — confirmed. Britannica: Pedro I was "first emperor of Brazil, from December 1, 1822, to April 7, 1831."
- **"an empire that lasts until 1889" — confirmed exactly.** The Library of Congress guide is titled "Empire of Brazil (1822–1889)"; Pedro II reigned until 15 November 1889, when Marshal Deodoro da Fonseca's coup proclaimed a republic that same day.

**approximate: false** — correct. 7 September 1822 and 15 November 1889 are both firm.

---

#### 1823 · monroe_doctrine
- https://history.state.gov/milestones/1801-1829/monroe

**Year** confirmed — State Department: the doctrine was announced on 2 December 1823, in President Monroe's annual message to Congress.

**Claims**
- "The United States tells Europe that the Americas are closed to further colonisation" — confirmed, in Monroe's own words as quoted: "The American continents… are henceforth not to be considered as subjects for future colonization by any European powers."
- "a claim it could not yet enforce" — confirmed. State Department: the doctrine "was little noted by the Great Powers of Europe" at the time, and only "In the late 1800s, U.S. economic and military power enabled it to enforce the Monroe Doctrine."

**approximate: false** — correct. 2 December 1823 is firm.

---

#### 1824 · battle_of_ayacucho
- https://www.britannica.com/event/Battle-of-Ayacucho

**Year** confirmed — Britannica: "Battle of Ayacucho, (Dec. 9, 1824)… revolutionary victory over royalists on the high plateau near Ayacucho, Peru."

**Claims**
- "The last royalist army in the Andes is defeated" — confirmed. Britannica: the Spanish army of about 9,000 "had been routed, with about 2,000 men killed. The Spanish viceroy and his generals were taken prisoner."
- "completing the independence of Spanish South America" — confirmed in substance, with a caveat. Britannica: "It freed Peru and **ensured** the independence of the nascent South American republics from Spain." Strictly, the surrender terms required withdrawal from Peru and Charcas (Bolivia), and "the last of them departed from Callao, the port of Lima, in January 1826." Ayacucho decided the outcome; the physical completion ran into 1826.

**approximate: false** — correct. 9 December 1824 is firm.

---

#### 1848 · guadalupe_hidalgo
- https://history.state.gov/milestones/1830-1860/texas-annexation

**Year** confirmed — the Treaty of Guadalupe Hidalgo was signed 2 February 1848.

**Claims**
- "The treaty ending the Mexican-American War" — confirmed; it is the settlement of that war, with a $15 million payment plus assumption of up to $3.25 million in Mexican debts to US citizens.
- **"transfers about half of Mexico's territory" — confirmed, and if anything conservative.** State Department: "Mexico ceded to the United States approximately 525,000 square miles (55% of its prewar territory)."
- "including California" — confirmed; the cession included the future states of California, Nevada, Utah, New Mexico and Arizona, plus parts of Colorado, Kansas, Wyoming and Oklahoma.

**approximate: false** — correct. 2 February 1848 is firm.

---

#### 1861 · american_civil_war
- https://www.nps.gov/fosu/learn/historyculture/index.htm
- https://www.nps.gov/civilwar/death-and-dying.htm
- https://www.nps.gov/features/waso/cw150th/reflections/legacy/page2.html

**Year** confirmed — NPS: "Confederate forces fired the first shots of the Civil War upon Federal troops at Fort Sumter at 4:30 a.m. on April 12, 1861."

**Claims**
- "Four years of war" — confirmed: 1861–1865 (NPS Civil War facts page).
- "over slavery and union" — confirmed. NPS: "The institutions and ideology of a plantation society and a slave system that had dominated half the country before 1861 and sought to dominate more went down with a great crash in 1865."
- **"about six hundred thousand die" — confirmed as the conventional figure.** NPS: "The number of soldiers who died between 1861 and 1865, generally estimated at 620,000… were 2 percent of the total American population… two thirds of them from disease." *Note:* more recent demographic work (Hacker, 2011) puts the toll nearer 750,000; the record's "about six hundred thousand" tracks the figure NPS itself publishes and is the conservative reading.
- "it ends with emancipation" — confirmed. NPS: "more than four million men, women, and children who had known no other life than slavery suddenly found themselves freed."

**approximate: false** — correct. 12 April 1861 is firm.

---

#### 1869 · transcontinental_railroad
- https://www.nps.gov/articles/goldenspike.htm
- https://www.nps.gov/gosp/learn/historyculture/chinese-labor-and-the-iron-road.htm

**Year** confirmed — NPS: "On May 10, 1869, a Golden Spike was ceremoniously driven into a polished laurel tie at Promontory Summit, Utah."

**Claims**
- "Rails joined in Utah" — confirmed: Promontory Summit, Utah, after 1,800 miles of new track.
- **"cut a journey of months to a week" — confirmed almost verbatim.** NPS: the completion "reduced a journey of four months or more to just one week."
- "largely built by Chinese and Irish labour" — confirmed. NPS: "An estimated 10,000 to 20,000 Chinese immigrants were recruited by the Central Pacific Railroad"; "The crew of the Union Pacific… was composed largely of Irish immigrants and Civil War veterans," roughly 10,000 Irish workers.

**approximate: false** — correct. 10 May 1869 is firm.

---

#### 1898 · spanish_american_war
- https://history.state.gov/milestones/1866-1898/spanish-american-war

**Year** confirmed — State Department: the war and the Treaty of Paris both fall in 1898.

**Claims**
- "Spain loses Cuba, Puerto Rico, Guam and the Philippines" — confirmed. The Treaty of Paris transferred Puerto Rico, Guam and the Philippines (the Philippines purchased for $20 million) and guaranteed the independence of Cuba, which Congress had already foresworn annexing. Cuba was relinquished rather than ceded to the US — the record's verb, "loses," is accurate for all four.
- "the United States becomes a power beyond its own hemisphere" — confirmed. State Department: the war "secured the position of the United States as a Pacific power" and enabled it "to pursue its strategic and economic interests in Asia."

**approximate: false** — correct. 1898 is firm.

---

#### 1914 · panama_canal_opens
- https://www.britannica.com/topic/Panama-Canal
- https://wwwnc.cdc.gov/eid/article/27/8/ac-2708_article
- https://pancanal.com/en/american-canal-construction/

**Year** confirmed — Britannica: "The canal, which was completed in August 1914" (it opened to traffic on 15 August 1914).

**Claims**
- "Ships pass between the oceans without rounding South America" — confirmed. Britannica: ships between the US east and west coasts, "which otherwise would be obliged to round Cape Horn in South America, shorten their voyage by about 8,000 nautical miles (15,000 km) by using the canal."
- **"the work cost tens of thousands of lives" — confirmed.** CDC: "During the effort to build the canal in the 1880s, more than 22,000 workers from France died." Panama Canal Authority: during the US construction "more than 55,000 people were employed and an estimated 5,600 died of injury and disease" (5,609 in the ACP's count). Combined, roughly 28,000 — "tens of thousands," correctly.
- **"most of them to disease" — confirmed.** CDC: the French dead were lost "many from malaria and yellow fever, before the etiologies of those tropical diseases were understood." Gorgas's mosquito-control programme "virtually eliminated yellow fever and greatly reduced the toll of malaria" before the American phase, which is why the later death toll is a small fraction of the French one.

**approximate: false** — correct. 15 August 1914 is firm.

---

# Group 2 - the migration period (13 records, commit 1496fef)

## Migration-period records — source audit

13 records (406–911) from `assets/wheel_history.json`, checked one by one against general
references actually fetched or quoted in search results: Britannica, the *Catholic Encyclopedia*
(public domain, via New Advent), the *New Catholic Encyclopedia* (via Encyclopedia.com), the
Internet Encyclopedia of Philosophy, the *Yale Historical Review*, the University of Illinois
Department of History, Canterbury Cathedral's own learning pages, the Our Migration Story project
(Runnymede Trust + UK universities), UNESCO's World Heritage listing, World History Encyclopedia,
and Bede's *Historia Ecclesiastica* itself (CCEL, public domain).

No chart, timeline poster or aggregated "history timeline" site was used as evidence.
Britannica returns HTTP 403 to direct fetching; where Britannica is cited it is via search
results that quote its text, which is the intended fallback.

### Disagreements found

Four. None of them is a wrong `year`, and none of them requires an `approximate` flag to flip.
Three are wrong or overstated claims inside descriptions; one is a divergence between references.

1. **507 `battle_of_vouille` — "the Visigothic kingdom withdraws beyond the Pyrenees" is not
   accurate.** The kingdom kept Septimania, the Mediterranean strip around Narbonne on the
   *Gaulish* side of the Pyrenees, from 507 until the Muslim conquest of the province in 719–720.
   It never withdrew wholly beyond the mountains. The rest of the sentence ("lasts there until
   711") is correct for Spain.
2. **774 `charlemagne_takes_lombardy` — "the Frankish king now rules Italy as well as Gaul"
   overstates the conquest.** Charlemagne took the Lombard *kingdom* (the north and the centre)
   and the title *rex Langobardorum*. The Lombard Duchy of Benevento in the south remained
   effectively independent, and the far south and Sicily remained Byzantine. He ruled northern
   Italy, not Italy.
3. **597 `augustine_mission_to_kent` — "forty monks" is stated flatly where every reference
   hedges.** Bede says "nearly forty"; Britannica and Canterbury Cathedral both say "about 40".
   The number is a round approximation in the sources, not a count.
4. **751 `pippin_king_of_franks` — the references disagree with each other.** Britannica's
   *Pippin III summary* page dates the deposition of Childeric III and Pippin's accession to
   **752**; Britannica's main *Pippin III* article and the *New Catholic Encyclopedia* both give
   **November 751** at Soissons. 751 is the conventional and better-attested date, so the record's
   year stands — but this is the weakest of the eight `approximate: false` records and it is worth
   knowing the divergence exists.

Two further notes that are not disagreements but are load-bearing if the wording is ever revised:
the *site* of the 507 battle (Vouillé vs. Voulon) is genuinely disputed even though the year is
not; and the 911 grant of Normandy has no contemporary documentation at all — the narrative comes
from Dudo of Saint-Quentin writing c. 1015, corroborated only by a royal charter of 14 March 918
that refers back to a grant already made.

---

#### 406 · rhine_crossing_406
- https://yalehistoricalreview.ghost.io/barbarians-at-the-open-gates/
- https://www.cambridge.org/core/journals/britannia/article/abs/barbarians-in-gaul-usurpers-in-britain/8080D88478659D1DD17BF98EACE6E592

**Year** confirmed — the traditional date is 31 December 406, fixed by the chronicle of Prosper of
Aquitaine. The *Yale Historical Review* study states that current scholarly consensus leans to 406,
naming Heather, Ward-Perkins and Wickham as holding the traditional date.

**Claims** —
- "Vandals, Alans and Suevi": correct; the sources describe a mixed group of these three peoples.
- "The river frontier gives way and whole peoples move into Gaul": correct — the crossing put the
  groups into Gaul and the Rhine frontier was not restored.
- "the western provinces are never again governed as before": correct as a summary; the crossing is
  followed by the usurpations in Britain and the permanent loss of effective imperial control in
  the north-west.
- "Sources place it in 406, a few in 405": fair, and precisely calibrated. Kulikowski,
  *Barbarians in Gaul, Usurpers in Britain*, *Britannia* 31 (2000), argued for 31 December 405 on
  the ground that the British usurpations of 406 were a reaction to the crossing and so must
  postdate it. The Yale piece says his conclusion "has by no means found universal acceptance" —
  i.e. a minority, which is what "a few" claims.

**approximate: true** — correct. The Yale study calls the debate "fundamentally unresolved".

---

#### 429 · vandals_cross_to_africa
- https://www.britannica.com/place/North-Africa/The-Vandal-conquest (quoted via search; direct fetch 403)
- https://www.worldhistory.org/Vandals/
- https://www.worldhistory.org/article/1331/north-africas-place-in-the-mediterranean-economy-o/

**Year** confirmed — Britannica: "Led by their king, Gaiseric, the whole people, 80,000 in all,
crossed into Africa in 429." World History Encyclopedia gives the same year.

**Claims** —
- "They take Carthage in 439": confirmed. Britannica: "on Oct. 19, 439, Gaiseric captured
  Carthage."
- "and with it Rome's grain": confirmed. Africa Proconsularis was the centre of the grain and oil
  *annona* for Rome, especially after Egyptian grain was diverted to Constantinople; Gaiseric used
  the supply as leverage against the western empire.
- "Augustine died at Hippo as their army besieged it": confirmed, and the antecedent is right —
  Augustine died at Hippo Regius on 28 August 430, some three months into the Vandal siege, which
  lasted fourteen months and ended with the city's fall. Britannica: the Vandals "advanced ... to
  Hippo Regius, which they took after a siege during which Augustine died." Note the description
  gives no year for Augustine's death, which is correct practice — it is 430, not 439.

**approximate: false** — correct. 429 for the crossing is firm in every reference consulted.

---

#### 449 · anglo_saxon_settlement
- https://www.ccel.org/ccel/bede/history.v.i.xiv.html (Bede, *Historia Ecclesiastica* I.15, public domain)
- https://www.ourmigrationstory.org.uk/oms/anglo-saxon-migrations

**Year** confirmed as Bede's, which is what the record claims. Bede: "In the year of our Lord 449,
Marcian ... being made emperor with Valentinian ... Then the nation of the Angles, or Saxons, being
invited by the aforesaid king, arrived in Britain with three ships of war."

**Claims** —
- "Bede dates the coming of the English to 449": correct, and Bede is correctly credited. The date
  is his, from the *Historia Ecclesiastica* (completed 731), not a modern reconstruction.
- "Angles, Saxons and Jutes" (title): correct — Bede names "the three most powerful nations of
  Germany — Saxons, Angles, and Jutes."
- "the settlement was in fact gradual": correct and well supported. Our Migration Story: any
  version presenting this as a rapid, complete replacement "shortens a process that took
  centuries, and a different course in different parts of Britain"; Bede "was explaining regional
  differences that existed in his own day ... centuries after the migration had actually taken
  place." Irish and Welsh annals place the *adventus* in the 450s or 460s.
- "it made the island's language and its later kingdoms": correct — the British and/or Latin of
  lowland Britain was replaced by Old English, and the later English kingdoms grew out of the
  settlement.

**approximate: true** — correct, and necessary. This is one author's date for a process spanning
generations.

---

#### 493 · ostrogothic_italy
- https://www.encyclopedia.com/people/history/italian-history-biographies/theodoric-great
- https://iep.utm.edu/boethius/
- https://www.britannica.com/biography/Theodoric-king-of-Italy (quoted via search; direct fetch 403)

**Year** confirmed — Theodoric was commissioned by Zeno in 488, won at the Adda in 490, "but only
in 493 did he capture Ravenna and murder Odoacer." Odoacer was killed at the reconciliation banquet
in Ravenna on 15 March 493; Theodoric was king of Italy 493–526 with his capital at Ravenna.

**Claims** —
- "Theodoric Rules Italy from Ravenna" (title): correct; Ravenna was his capital.
- "governs Italy with Roman law and Roman officials": correct. He preserved the Roman
  administrative system, and Romans continued to run civil administration, taxation and law;
  Cassiodorus served as *quaestor* and later praetorian prefect, and the *Variae* are the record of
  it.
- "an Arian ruling a Catholic people": correct. The Ostrogoths were Arian, the Roman population
  Nicene; Theodoric enforced tolerance for most of his reign.
- "Boethius wrote under him": correct. Boethius held the office of *magister officiorum*, "the
  highest political rank that could be exercised in the reign of Theodoric," and produced his
  logical, theological and scientific works in that period.
- "and died by his order": correct. IEP: "Around 524 AD, Boethius was accused of treason by
  Theodoric himself"; he was imprisoned near Pavia and executed there. Some references give 525 or
  526 for the execution — but the record makes no claim about that year, only about the agency,
  which is right.

**approximate: false** — correct. 493 is firm to the day.

---

#### 496 · clovis_baptised
- https://www.newadvent.org/cathen/04066a.htm (*Catholic Encyclopedia*, "Clovis")
- https://www.touchstonemag.com/archives/article.php?id=37-06-001-a
- https://www.academia.edu/12646288/Dating_the_baptism_of_Clovis_1886-1993

**Year** confirmed as the traditional one — the *Catholic Encyclopedia* gives 496 for the baptism at
Reims by St Remigius, with no alternative offered.

**Claims** —
- "Baptised at Reims" (title): correct; Reims, by Remigius.
- "Alone among the Germanic kings he takes the Catholic faith rather than the Arian": correct as
  the standard formulation — Clovis is the first Germanic king to accept Nicene rather than Arian
  Christianity, the other Germanic royal houses of the period being Arian. (The Franks were pagan
  before, not Arian; the sentence does not claim otherwise.)
- "which allied the Franks with the bishops of Gaul": correct — the conversion is universally
  presented as establishing the political and religious alliance between the Franks and the
  Catholic episcopate.
- "The year is given as 496, 498 or 508": fair, and the three candidates are the real ones. 496 is
  traditional; a substantial line of scholarship argues 498/499 on the evidence of Avitus of
  Vienne; and the late dating of 506/508 is the third proposal, though it commands markedly less
  support than the other two. The record's phrasing does not rank them, which slightly flatters
  508 — but it does not claim they are equally held.

**approximate: true** — correct, and clearly right; this is one of the most argued dates in the
period.

---

#### 507 · battle_of_vouille
- https://history.illinois.edu/spotlight/publication/battle-vouille-507-ce-where-france-began (University of Illinois Dept. of History)
- https://www.newadvent.org/cathen/15476b.htm (*Catholic Encyclopedia*, "Visigoths")
- https://www.britannica.com/place/Spain/The-Visigothic-kingdom (quoted via search)

**Year** confirmed — the battle was fought in late spring 507 between Clovis and Alaric II. The
Illinois page dates it 507 CE without qualification.

**Claims** —
- "Clovis defeats Alaric II": correct; Illinois: "the Frankish King Clovis defeated Alaric II, the
  King of the Visigoths."
- "and takes Aquitaine": correct; the victory gave him Aquitaine from the Visigothic kingdom of
  Toulouse.
- "the Visigothic kingdom withdraws beyond the Pyrenees": **DISPUTED — overstated.** The centre of
  gravity did move to Spain and Toledo became the capital, and the *Catholic Encyclopedia* says
  "almost all of Visigothic Gaul now fell to the Franks." But "almost" is doing real work: the
  Visigoths retained Septimania, the coastal province around Narbonne on the Gaulish side of the
  Pyrenees, continuously from 507 until the Muslim conquest of the province in 719–720. The
  kingdom did not withdraw wholly beyond the mountains.
- "and lasts there until 711": correct. Roderic was defeated by Ṭāriq ibn Ziyād near the Guadalete
  in July 711, opening the way to Toledo; the *Catholic Encyclopedia* likewise dates the Arab
  invasion and Roderic's defeat to 711. (The conquest of the peninsula ran on to about 720, but
  711 is the conventional end of the kingdom.)

**approximate: false** — correct for the *year*. Note separately that the *site* is genuinely
disputed — Vouillé near Poitiers versus Voulon — so the title's place-name is the conventional but
not the certain one.

---

#### 568 · lombards_enter_italy
- https://whc.unesco.org/en/list/1318/ — UNESCO World Heritage List, "Longobards in Italy. Places of the Power (568-774 A.D.)" (title quoted via search; direct fetch 403)
- https://www.worldhistory.org/Lombards/
- https://www.britannica.com/place/Italy/Lombards-and-Byzantines (quoted via search)

**Year** confirmed — "in 568 CE, Alboin led the Lombards out of Pannonia and into northern Italy."
UNESCO's inscription is dated 568–774 in its own title. Britannica writes "In 568–569 ... the
Lombards invaded Italy under their king, Alboin," the range reflecting the length of the campaign,
not doubt about when it began.

**Claims** —
- "The last great migration into the peninsula": correct in the conventional sense — the Lombards
  are the last of the migration-period peoples to enter and settle Italy.
- "leaves Italy divided between Lombard dukes and Byzantine Ravenna": correct. Alboin divided the
  conquest into some 36 duchies each under a duke; Ravenna and Rome stayed Byzantine, and Tiberius
  II created the Exarchate of Ravenna in 582/584 to hold them. After Alboin's and Cleph's murders
  the Lombards had no king at all for a decade (574–584) and the dukes ruled — so "Lombard dukes"
  is exactly the right term.
- "for two centuries": correct to the nearest century. The Exarchate of Ravenna lasted until 751
  (183 years) and the Lombard kingdom until 774 (206 years).

**approximate: false** — correct. 568 is firm.

---

#### 589 · third_council_of_toledo
- https://www.newadvent.org/cathen/14755a.htm (*Catholic Encyclopedia*, "Toledo (Spain)")
- https://www.newadvent.org/cathen/15476b.htm (*Catholic Encyclopedia*, "Visigoths")
- https://www.encyclopedia.com/history/ancient-greece-and-rome/ancient-history-late-roman-and-byzantine/visigoths (quoted via search)

**Year** confirmed — the *Catholic Encyclopedia*: "The most famous of all the councils of Toledo was
the third national council (held in 589)."

**Claims** —
- "King Reccared and his nobles renounce the Arian confession": confirmed almost word for word.
  *Catholic Encyclopedia*: "in which King Reccared, the prelates, and grandees, proclaimed their
  abjuration of the Arian heresy and made a profession of faith according to the doctrine of the
  Council of Nicæa." The council was convoked by Reccared, presided over by Leander of Seville, and
  attended by 72 bishops. One nuance the record does not misstate but does compress: Reccared had
  personally renounced Arianism in 587; 589 is the formal, public, conciliar abjuration by the king
  together with the Arian bishops and nobles, which is what the record describes.
- "At the Third Council of Toledo": correct.
- "ending two centuries of a divided kingdom": defensible. The Goths converted to Arianism en masse
  in the 370s under the influence of Ulfilas and remained Arian until 589 — roughly 215 years. Read
  as "two centuries of Arian rule over a Nicene population", it is accurate; read strictly as the
  age of the *kingdom*, it is generous, since the Spanish kingdom dates from 507/418.
- Worth knowing but not claimed by the record: the abjuration was not universally accepted, and
  Arian revolts followed, notably in Septimania.

**approximate: false** — correct. 589 is firm.

---

#### 597 · augustine_mission_to_kent
- https://learning.canterbury-cathedral.org/a-walk-through-time/st-augustine/ (Canterbury Cathedral)
- https://www.britannica.com/biography/Saint-Augustine-of-Canterbury (quoted via search)

**Year** confirmed — Canterbury Cathedral gives 597; Britannica: the party "landed in the spring of
597 on the Isle of Thanet." (The mission set out in June 596 and was interrupted in Gaul; 597 is
the landing, which is what the record dates.)

**Claims** —
- "Sent by Gregory the Great": correct. Britannica: Augustine was prior of St Andrew's in Rome
  "when Pope Gregory I the Great chose him to lead" the mission; Canterbury Cathedral names Gregory
  the Great as sender.
- "forty monks": **imprecise.** Every reference hedges the number. Britannica: "about 40 monks."
  Canterbury Cathedral: "approximately 40 monks." Bede's own figure is "nearly forty." The record
  states it as a flat count. The number itself is right; the certainty is not.
- "King Ethelbert receives them": correct. Britannica: the party "was well received by King
  Aethelberht (Ethelbert) I of Kent, who gave the missionaries a dwelling place in Canterbury and
  the old St. Martin church." (Bede's detail that he received them outdoors for fear of witchcraft
  does not contradict "receives them".)
- "Canterbury begins from this": correct — Ethelbert gave them a residence in Canterbury and the
  land on which the cathedral stands; Augustine became the first archbishop.

**approximate: false** — correct for the year. 597 is firm.

---

#### 751 · pippin_king_of_franks
- https://www.encyclopedia.com/religion/encyclopedias-almanacs-transcripts-and-maps/pepin-iii-king-franks (*New Catholic Encyclopedia*)
- https://www.britannica.com/biography/Pippin-III (quoted via search)
- https://www.britannica.com/summary/Pippin-III (quoted via search)

**Year** confirmed but **the references diverge.** The *New Catholic Encyclopedia*: "In 751, he was
elected king of the Franks, anointed, and raised to the throne at Soissons." Britannica's main
article agrees: Childeric III "was deposed and sent to a monastery, and Pippin was anointed as king
at Soissons in November 751 by Archbishop Boniface and other prelates." But Britannica's own
*summary* page dates the deposition and accession to **752**. 751 is the better-attested and
conventional date and the record is right to use it; the divergence is recorded here because it is
real.

**Claims** —
- "The Carolingians replace the Merovingian line": correct. Childeric III was the last Merovingian;
  Pippin III is the first Carolingian king, reigning 751–768.
- "with the pope's assent": correct, and "assent" is the right word rather than "command". Pippin
  sent envoys to Pope Zacharias in 750 asking whether the man who held the power should hold the
  title; Zacharias approved. The *New Catholic Encyclopedia* explicitly warns that in later,
  pro-Carolingian retellings "papal approval becomes a papal command" and Zacharias is replaced by
  Stephen II — the record avoids both distortions.
- "binding the Frankish crown to Rome": correct — Stephen II later re-anointed Pippin and
  consecrated his sons, and the alliance with the papacy follows from this.

**approximate: false** — defensible, and I would leave it. But this is the weakest of the eight
`false` flags in the set, given Britannica's internal inconsistency and a real if minor 751/752
discussion in the literature.

---

#### 774 · charlemagne_takes_lombardy
- https://www.britannica.com/biography/Desiderius (quoted via search)
- https://www.worldhistory.org/Lombards/
- https://whc.unesco.org/en/list/1318/ — UNESCO dates the Lombard period 568–774

**Year** confirmed — the siege of Pavia ran from September 773 to June 774; Desiderius opened the
gates in June 774. UNESCO's inscription closes the Lombard period at 774.

**Claims** —
- "Pavia falls": correct, June 774, after roughly nine to ten months of siege and famine.
- "the Lombard kingdom ends": correct. Desiderius, the last Lombard king (756–774), was deposed and
  sent to the abbey of Corbie; Charlemagne had himself declared *rex Langobardorum* and thereafter
  styled himself king of the Franks and of the Lombards.
- "the Frankish king now rules Italy as well as Gaul": **overstated.** He acquired the Lombard
  kingdom — the north and centre. The Lombard Duchy of Benevento in the south remained effectively
  independent, and the far south and Sicily remained Byzantine. "Northern Italy", or "the Lombard
  kingdom", would be right; "Italy" is not.

**approximate: false** — correct. 774 is firm.

---

#### 843 · treaty_of_verdun
- https://www.britannica.com/event/Treaty-of-Verdun (quoted via search)
- https://www.oxfordreference.com/display/10.1093/oi/authority.20110803115500937

**Year** confirmed — Britannica: the treaty was signed in August 843.

**Claims** —
- "Charlemagne's empire is split": correct — the empire Charlemagne built, inherited undivided by
  Louis the Pious and bequeathed to his sons in 840.
- "among three grandsons": correct on both counts — three, and grandsons. Britannica describes the
  partition "among the three surviving sons of the emperor Louis I (the Pious)" and calls Lothar,
  Louis and Charles "the grandsons of Charlemagne". So the record's relationship is the right one:
  Lothair I, Louis the German and Charles the Bald were Charlemagne's grandsons.
- "the western and eastern shares grow into France and Germany": correct. Britannica: "Charles and
  Louis received West and East Francia (roughly, present-day France and Germany)," Lothair holding
  the middle kingdom, and the treaty "foreshadowed the formation of the modern countries of western
  Europe."

**approximate: false** — correct. August 843 is firm and documented.

---

#### 911 · normandy_granted
- https://www.britannica.com/topic/Treaty-of-Saint-Clair-sur-Epte (quoted via search)
- https://www.worldhistory.org/Rollo_of_Normandy/

**Year** confirmed — the Treaty of Saint-Clair-sur-Epte between Charles III (the Simple) and Rollo
is dated to autumn 911 by Britannica and World History Encyclopedia alike.

**Claims** —
- "A Viking band is settled on the lower Seine": correct. Charles granted Rollo land "from the
  River Andelle to the sea", centred on Rouen — the lower Seine.
- "as vassals rather than driven off": correct, and this is the point of the treaty. Rollo agreed
  to cease raiding, to convert to Christianity, and to become Charles's vassal, defending the
  kingdom against further Norse attack; the king's counsellors describe him as "a constant and
  amenable vassal in all things."
- "within six generations their descendants take England": correct, and the count checks out.
  World History Encyclopedia states Rollo was "the great-great-great grandfather of William the
  Conqueror" — Rollo, William Longsword, Richard I, Richard II, Robert I, William. William is the
  sixth generation, and 1066 is 155 years after 911. "Within six generations" is exact rather than
  loose.

**approximate: false** — defensible, and the conventional date is firm at 911. One caveat worth
recording: no contemporary document of the grant survives. The narrative comes from Dudo of
Saint-Quentin writing about a century later, and the only near-contemporary corroboration is a
royal charter of 14 March 918 referring back to a grant already made to Rollo and his companions.
Historians have occasionally doubted the meeting itself. The published date is nonetheless
uniformly 911, so `false` is the honest reading of "conventional, widely published date".

---

# Group 3 - the papal succession (18 records, commit b4013fa)

```
SOURCES — papal succession entries for the SeekSparks chronology wheel
18 entries, 452 to 2025. All era "church", all stream "church", all basis
"conventional", all approximate: false.

No date, name or numeral in this file was taken from any chart, timeline poster
or aggregated "history timeline" site. Every entry was checked against
Britannica and/or the Catholic Encyclopedia (public domain, newadvent.org).

REGNAL-NUMERAL AUDIT
--------------------
Every numeral below was checked against the Catholic Encyclopedia's List of
Popes, https://www.newadvent.org/cathen/12272b.htm , which was fetched and read
for this purpose. Reign dates as that list gives them:

  Leo I           440-461
  Gelasius I      492-496
  Stephen II      752-757   (see note 1 — not named in the entry)
  Nicholas I      858-867
  Nicholas II     1058-1061 (see note 2)
  Gregory VII     1073-1085
  Innocent III    1198-1216
  Gregory IX      1227-1241
  Boniface VIII   1294-1303
  Clement V       1305-1314
  Gregory XI      1370-1378
  Martin V        1417-1431
  Alexander VI    1492-1503
  Pius VI         1775-1799
  Pius VII        1800-1823
  Pius IX         1846-1878
  Leo XII         1823-1829   (checked only to guard against the known chart error)
  Leo XIII        1878-1903   (checked only to guard against the known chart error)
  Callixtus II    1119-1124   (checked because the Canossa entry cites the
                               Concordat of Worms; the pope himself is not named
                               in any entry, so no numeral is used for him)

No numeral appears twice for two different popes, and no pope appears under two
numerals. Specifically, the two errors in the printed chart this work replaces
were checked and are NOT reproduced here:
  * Gregory VII is used only at 1077 (Canossa). The 1231 Inquisition entry names
    Gregory IX, per the Catholic Encyclopedia (1227-1241) and Britannica.
  * Leo XIII is not used at all. Leo appears only as Leo I (452) and Leo XIV
    (2025). The 1823 accession the chart mislabels is Leo XII; no entry here
    covers it.

Note 1: the pope who received the Donation of Pippin is numbered Stephen II by
the Catholic Encyclopedia but Stephen II (or III) by Britannica, because of the
disputed Stephen of 752. Rather than pick a side, the 756 entry does not give
him a numeral at all; it says "the pope".

Note 2: the Catholic Encyclopedia dates Nicholas II 1058-1061 (election) and
Britannica 1059-1061 (enthronement). The entry is dated to the election decree
itself, issued at the Lateran synod at Easter 1059, on which both agree.

PER-ENTRY SOURCES
-----------------
452  leo_i_attila
     https://www.britannica.com/biography/Saint-Leo-I
     https://www.britannica.com/topic/Meeting-of-Attila-and-Pope-Leo
     https://www.britannica.com/topic/Tome-by-Leo-I
     Meeting with Attila 452; the Tome (c. 449) affirmed at Chalcedon 451.

494  gelasius_two_powers
     https://www.britannica.com/biography/Saint-Gelasius-I  (letter of 494 to
       Anastasius I; Gelasius reigned 492-496)
     https://www.newadvent.org/cathen/06406a.htm  (Catholic Encyclopedia,
       pontificate 1 Mar 492 - 19 Nov 496; text of the "two powers" sentence)

756  papal_states_begin
     https://www.britannica.com/event/Donation-of-Pippin
     https://www.britannica.com/place/Papal-States
     https://www.britannica.com/biography/Stephen-II-or-III
     Pippin defeated Aistulf and conferred the exarchate of Ravenna and the
     duchy of Rome on the pope in 756, founding the Papal States.

863  nicholas_i_deposes_archbishops
     https://www.britannica.com/biography/Saint-Nicholas-I
     https://www.britannica.com/biography/Lothar-II-king-of-Lotharingia
     https://www.britannica.com/biography/Theutberga
     Nicholas I (858-867) quashed the Aachen synods' dissolution of Lothar II's
     marriage and deposed Gunther of Cologne and Theutgaud of Trier, October 863.
     The wheel year is the deposition, not the accession, because the entry is
     about what the office did.

1059 papal_election_decree_1059
     https://www.britannica.com/biography/Nicholas-II-pope
     https://www.britannica.com/topic/papal-conclave
     https://www.britannica.com/topic/Sacred-College-of-Cardinals
     Lateran synod, Easter 1059: election vested in the cardinal bishops.

1077 canossa_1077
     https://www.britannica.com/topic/Canossa
     https://www.britannica.com/event/Investiture-Controversy
     https://www.britannica.com/event/Concordat-of-Worms
     Henry IV submitted at Canossa 28 January 1077; the controversy was settled
     by the Concordat of Worms, 1122 (Callixtus II and Henry V) — cited in the
     entry as an event, not under a papal numeral.

1198 innocent_iii_height
     https://www.britannica.com/biography/Innocent-III-pope
     https://www.britannica.com/topic/papacy/The-medieval-papacy-from-590-to-1303
     Elected 8 January 1198; "vicar of Christ"; England, Bulgaria and Portugal
     became papal fiefs.

1231 papal_inquisition_1231
     https://www.britannica.com/biography/Gregory-IX
     https://www.britannica.com/topic/inquisition
     Gregory IX (1227-1241) ordered heretics handed to the civil power in 1231
     and appointed papal judges delegate, largely Dominican and Franciscan.
     (Some references date the founding of the papal Inquisition 1231-1233. The
     entry is written around the 1231 order specifically, which is firmly dated,
     so approximate is false.)

1302 unam_sanctam
     https://www.britannica.com/topic/Unam-Sanctam
     https://www.britannica.com/biography/Boniface-VIII
     https://www.britannica.com/biography/Boniface-VIII/Bonifaces-capture-and-death
     Bull of 1302; Nogaret and Sciarra Colonna seized Boniface at Anagni on
     7 September 1303; he died soon after. The entry states the bull's claim as
     a claim and gives no verdict on it.

1309 avignon_papacy
     https://www.britannica.com/event/Avignon-papacy
     https://www.britannica.com/biography/Clement-V
     Clement V (elected 1305) moved the papal residence to Avignon in 1309;
     seven popes, nearly seventy years, return to Rome 1377.

1417 constance_elects_martin_v
     https://www.britannica.com/event/Council-of-Constance
     https://www.britannica.com/biography/Martin-V
     https://www.britannica.com/topic/conciliarism
     https://www.britannica.com/event/Western-Schism
     Oddone Colonna elected Martin V, November 1417, ending the schism of
     1378-1417; the council's conciliarist decree was not confirmed by the popes.
     Deliberately written about the schism's END and the conciliar claim, since
     western_schism (1378) and hus_burned (1415) already exist.

1493 alexander_vi_line
     https://www.britannica.com/biography/Alexander-VI
     https://www.britannica.com/event/Treaty-of-Tordesillas
     Inter caetera, May 1493, line 100 leagues west of the Cape Verde Islands;
     Spain west, Portugal east; the crowns moved the line at Tordesillas in 1494.

1799 pius_vi_dies_captive
     https://www.britannica.com/biography/Pius-VI
     https://www.britannica.com/biography/Pius-VII
     https://www.britannica.com/topic/papacy/The-modern-papacy-from-1775-to-the-21st-century
     Pius VI seized March 1799, died at Valence 29 August 1799; the conclave met
     at Venice under Austrian protection and elected Pius VII, 14 March 1800.

1870 rome_taken_1870
     https://www.britannica.com/place/Papal-States
     https://www.britannica.com/biography/Pius-IX
     https://www.britannica.com/topic/Roman-question
     Breach of the Porta Pia, 20 September 1870; plebiscite; Pius IX declared
     himself a prisoner in the Vatican, a position held until 1929.
     Distinct from the existing vatican_i (1869).

1929 lateran_treaty
     https://www.britannica.com/event/Lateran-Treaty
     https://www.britannica.com/biography/Pius-XI
     https://www.britannica.com/topic/Roman-question
     Signed 11 February 1929, effective 7 June 1929; Vatican City, 44 hectares
     (about 109 acres). The entry states the two mutual recognitions only.

1978 john_paul_ii_elected
     https://www.britannica.com/biography/Saint-John-Paul-II
     Elected 16 October 1978; first non-Italian since Adrian VI (1522-23), i.e.
     455 years; 104 journeys abroad; visit to Poland June 1979.

2013 benedict_resigns_francis
     https://www.britannica.com/biography/Benedict-XVI
     https://www.britannica.com/biography/Francis-I-pope
     https://www.britannica.com/biography/Gregory-XII
     Benedict XVI resigned February 2013, the first resignation since Gregory XII
     in 1415; Jorge Mario Bergoglio elected, first from the Americas, first Jesuit.

2025 leo_xiv_elected
     https://www.britannica.com/biography/Leo-XIV
     https://www.britannica.com/topic/Why-Hasnt-There-Been-an-American-Pope
     https://www.britannica.com/topic/Augustinians
     Robert Prevost elected 8 May 2025 after the death of Francis; Augustinian,
     long ministry in Peru; first pope born in the United States.

CANDIDATES CONSIDERED AND REJECTED
----------------------------------
Urban II / the summons to crusade, 1095 — rejected: first_crusade (1095, stream
  europe) already exists and its desc already names Urban II.
Leo XIII — rejected: rerum_novarum (1891) already exists, and no second angle
  (Aeterni Patris 1879, opening the Vatican archives 1883) is strong enough to
  earn a place on a six-thousand-year wheel.
John XXIII — rejected: vatican_ii (1962) already exists and carries him.
Gregory the Great, 590 — already on the wheel (gregory_great).
Fourth Lateran Council, 1215 — rejected: the wheel already carries councils in
  depth, and the brief is the succession, not another council.
Concordat of Worms, 1122 — rejected as a separate record to stay inside the
  entry budget; folded into the second clause of the 1077 Canossa entry, which
  is where a reader needs it.
Index of Prohibited Books, 1559 — rejected: it falls inside the 1525-1689 window
  a second agent is working, and it is a weaker change to the office than the
  entries kept.
Return of Gregory XI to Rome, 1377 — rejected: covered by the Avignon entry's
  closing clause and by the existing western_schism (1378).
Sack of Rome 1527, Peace of Augsburg, St Bartholomew's Day, Nantes, Westphalia,
  the Toleration Act — out of scope; that period's politics belongs to the other
  agent.

EVEN-HANDEDNESS
---------------
Claims are stated as claims and attributed ("declared that submission to the
Roman pontiff is necessary to salvation", "decreed that a general council holds
authority over the pope, a claim later popes did not accept"). Conflicts are
narrated without a verdict on either party (Canossa, Anagni, 1870). No entry
praises or condemns the office.
```

---

# Group 4 - Europe's religious settlement (18 records, commit b4013fa)

```
SOURCES — reformation.json (the Reformation settlement of Europe, 1525-1689)
18 entries. One or more general-reference URLs per entry, all consulted directly
in this session (WebFetch, or WebSearch returning the page's own text). No date
was taken from a chart, poster or aggregated timeline site.

NOTE ON BRITANNICA: britannica.com returned HTTP 403 to every automated request
in this session (WebFetch and curl alike), so nothing here rests on it. The
substitutes used are national archives (The National Archives, UK; Nationaal
Archief, NL), a national parliament (UK Parliament / Parliamentary Archives),
university- and institute-run document editions (German History in Documents
and Images, a project of the German Historical Institute, Washington DC), and
two scholarly reference encyclopedias (GAMEO, the Global Anabaptist Mennonite
Encyclopedia Online; Musée protestant, the online museum of French Protestantism).

--------------------------------------------------------------------------------

zurich_anabaptist_baptisms — 1525
  https://gameo.org/index.php?title=Z%C3%BCrich_(Switzerland)
  https://gameo.org/index.php?title=Grebel%2C_Conrad_%28ca._1498-1526%29
  https://gameo.org/index.php?title=Manz%2C_Felix_%28ca._1498-1527%29
  Confirms: baptism on confession of faith performed on the night of 21 January
  1525 in the house of Felix Manz's mother, Neustadt, Zurich; break with
  Zwingli's church; Manz executed at Zurich in January 1527; Blaurock executed
  1529 in Tyrol.

protestation_at_speyer — 1529
  https://gameo.org/index.php?title=Diet_of_Speyer_(1529)
  https://gameo.org/index.php?title=Mandates
  https://gameo.org/index.php?title=Reformation,_Protestant
  Confirms: the protestation of 19-20 April 1529 by the evangelical estates
  against the withdrawal of the 1526 recess, from which the name "Protestant"
  derives; the imperial mandate of 23 April 1529 making rebaptism a capital
  offence throughout the empire. (GAMEO also records that the protesting
  estates assented to the measure against the Anabaptists; the desc states the
  two facts side by side without comment.)

act_of_supremacy — 1534
  https://www.parliament.uk/about/living-heritage/transformingsociety/private-lives/religion/collections/common-prayer/act-of-supremacy/
  https://www.parliament.uk/about/living-heritage/transformingsociety/private-lives/religion/overview/reformation/
  https://www.nationalarchives.gov.uk/explore-the-collection/explore-by-time-period/early-modern/the-dissolution-of-the-monasteries/
  Confirms: 1534 act declaring Henry VIII supreme head on earth of the Church of
  England; severance from Rome; denial of the supremacy made treason.

dissolution_of_monasteries — 1536
  https://www.nationalarchives.gov.uk/help-with-your-research/research-guides/dissolution-monasteries-1536-1540/
  https://www.nationalarchives.gov.uk/explore-the-collection/explore-by-time-period/early-modern/the-dissolution-of-the-monasteries/
  Confirms: the period 1536-1540; the crown's authority over houses in England,
  Wales and Ireland; the Court of Augmentations set up to manage the confiscated
  estates; pensions granted to former monks and nuns. No total house count is
  given by these sources, so none is stated in the desc.

schmalkaldic_war — 1546
  https://germanhistorydocs.org/en/from-the-reformations-to-the-thirty-years-war-1500-1648/battle-of-muehlberg-on-april-24-1547-1547
  https://germanhistorydocs.org/en/from-the-reformations-to-the-thirty-years-war-1500-1648/emperor-charles-v-in-1547-1548
  https://germanhistorydocs.org/en/from-the-reformations-to-the-thirty-years-war-1500-1648/the-religious-peace-of-augsburg-september-25-1555
  Confirms: the war of 1546/47; Charles V and Moritz of Saxony defeat the
  Schmalkaldic League at Mühlberg on 24 April 1547; the settlement Charles then
  pressed at the 1548 Diet of Augsburg met resistance and the matter was only
  put to rest in 1555. Entry year 1546 = the outbreak, per GHDI's "1546/47".
  (Place name written "Muhlberg" in the English desc, following the file's
  existing practice with "Waldseemuller".)

book_of_common_prayer — 1549
  https://www.nationalarchives.gov.uk/education/resources/the-english-reformation-c1527-1590/book-of-common-prayer/
  https://www.parliament.uk/about/living-heritage/transformingsociety/private-lives/religion/overview/reformation/
  https://www.parliament.uk/about/living-heritage/transformingsociety/private-lives/religion/key-dates1/key-dates/
  Confirms: Cranmer's book, drafted by a commission appointed 1548; the Act of
  Uniformity of March 1549 ordering its exclusive use from Whitsunday 1549;
  communion in English for the first time.

peace_of_augsburg — 1555
  https://germanhistorydocs.org/en/from-the-reformations-to-the-thirty-years-war-1500-1648/the-religious-peace-of-augsburg-september-25-1555
  https://ghdi.ghi-dc.org/pdf/eng/Doc.67-ENG-ReligPeace-1555_en.pdf
  Confirms: 25 September 1555; the estate fixes the religion of its land and
  dissenting subjects conform or emigrate; toleration extended only to the
  Catholic religion and to adherents of the Augsburg Confession, "all others who
  are not adherents of either of the aforementioned religions are not included
  in this peace" — i.e. the Reformed and the Anabaptists excluded; the
  ecclesiastical reservation added by Ferdinand I.

elizabethan_settlement — 1559
  https://www.nationalarchives.gov.uk/education/resources/the-english-reformation-c1527-1590/elizabethan-settlement/
  https://www.parliament.uk/about/living-heritage/transformingsociety/private-lives/religion/collections/common-prayer/act-of-uniformity-1559/
  https://www.rmg.co.uk/stories/topics/elizabeth-religious-settlement
  Confirms: the 1559 Act of Supremacy titling Elizabeth supreme governor (not
  supreme head); the 1559 Act of Uniformity restoring the 1552 prayer book and
  leaving the communion wording open to a Catholic and a Protestant reading.

french_wars_of_religion — 1562
  https://museeprotestant.org/en/notice/the-massacre-of-wassy-1562/
  https://museeprotestant.org/en/notice/the-eight-wars-of-religion-1562-1598/
  https://museeprotestant.org/en/notice/premiere-guerre-de-religion-1562-1563/
  Confirms: 1 March 1562, about a hundred Protestants at worship in a barn at
  Wassy killed by the duke of Guise's troops; eight wars over thirty-six years,
  1562-1598. The museum itself records that Catholic accounts date the outbreak
  instead to Condé's seizure of Orléans on 2 April 1562 — both datings are given
  in the desc, which is the reason this entry could be written even-handedly.

st_bartholomews_massacre — 1572
  https://museeprotestant.org/en/notice/st-bartholomews-day-24th-august-1572/
  https://museeprotestant.org/en/notice/quatrieme-guerre-de-religion-et-la-saint-barthelemy-1572-1573/
  Confirms: night of 23-24 August 1572; the killing of Coligny and other Huguenot
  leaders in Paris; three days of killing in the city, spreading to the
  provinces over following weeks. Figures: about 4,000 dead in Paris; total
  estimates range 7,000-21,000 including the provinces (Orléans 1,200, Meaux
  600, Roanne 300, Lyon 500-3,000). Because the wider total is a range and
  disputed, the desc gives "about four thousand in Paris and several thousand
  more elsewhere" rather than a single figure.

union_of_utrecht — 1579
  https://www.nationaalarchief.nl/beleven/onderwijs/bronnenbox/de-unie-van-utrecht-1579
  https://www.rijksmuseum.nl/en/collection/object/The-Union-of-Utrecht--ae7dff2ae9dd096b2f1195e65dd78d8e
  Confirms: 1579; alliance of the northern provinces against Spain in 26
  articles; article 13 — no one to be persecuted or examined over his faith,
  with Holland and Zeeland free to order religion as they chose and the other
  provinces leaving Catholic worship in place. NOTE: the day differs between
  references (23 January 1579 is the date usually given for Utrecht; the
  Nationaal Archief page dates the signing 29 January 1579 at Ghent, with the
  copy in The Hague signed 2-3 February 1579). The year is not in dispute and
  the wheel stores only the year, so approximate is left false.

edict_of_nantes — 1598
  https://museeprotestant.org/en/notice/the-edict-of-nantes-1598/
  https://museeprotestant.org/en/notice/the-eight-wars-of-religion-1562-1598/
  Confirms: 1598; freedom of conscience; worship in specified places only, and
  forbidden at court, in Paris and within five leagues of it, and in the armed
  forces; equality before the law with mixed Catholic-Protestant courts; access
  to public office; a separate warrant granting 150 places of refuge, 51 of them
  garrisoned strongholds, for eight years. NOTE: the museum's pages give both
  3 April 1598 and 30 April 1598 for the signature; only the year is stored.

thirty_years_war — 1618
  https://germanhistorydocs.org/en/from-the-reformations-to-the-thirty-years-war-1500-1648/the-war-begins-the-defenestration-of-prague-may-1618
  https://germanhistorydocs.org/en/from-the-reformations-to-the-thirty-years-war-1500-1648/prager-fenstersturz-am-23-mai-1618-1646
  Confirms: May 1618 (23 May); Protestant and Hussite estates meeting at Prague;
  two royal regents (Martinicz and Slawata) and a secretary thrown from a window
  of Prague Castle; the act begins the Bohemian revolt and is the catalyst of
  the Thirty Years' War; first battle at White Mountain, 8 November 1620.

english_civil_war — 1642
  https://www.parliament.uk/about/living-heritage/evolutionofparliament/parliamentaryauthority/civilwar/key-dates/1640-1660/
  https://www.parliament.uk/about/living-heritage/evolutionofparliament/parliamentaryauthority/civilwar/overview/the-breakdown/
  https://www.nam.ac.uk/explore/british-civil-wars
  https://www.english-heritage.org.uk/learn/histories/the-english-civil-wars-history-and-stories/the-english-civil-wars/
  Confirms: war began 22 August 1642 when Charles I raised his standard at
  Nottingham; causes given as the struggle with Parliament, taxation and the
  attempt to impose religious uniformity; trial and execution of Charles I in
  1649 and the years 1640-1660 treated as the period without a king.

peace_of_westphalia — 1648
  https://germanhistorydocs.org/en/from-the-reformations-to-the-thirty-years-war-1500-1648/peace-treaties-of-westphalia-october-14-24-1648
  Confirms: signed 14/24 October 1648; two treaties, at Osnabrück (emperor and
  Sweden) and Münster (emperor and France); ends the Thirty Years' War; Article
  VII extends to "those who call themselves the Reformed" the rights held by
  Catholics and by adherents of the Augsburg Confession; Article V §2 sets
  1 January 1624 as the determining date for ecclesiastical affairs; Article
  VIII §2 grants the imperial estates the right of making alliances.
  (Place names written "Munster" and "Osnabruck" in the English desc, following
  the file's existing practice with "Waldseemuller".)

revocation_edict_nantes — 1685
  https://museeprotestant.org/en/notice/the-edict-of-fontainebleau-or-the-revocation-1685/
  https://museeprotestant.org/en/notice/the-huguenot-refuge/
  https://museeprotestant.org/en/notice/the-period-of-the-revocation-of-the-edict-of-nantes-1661-1700/
  Confirms: October 1685, Edict of Fontainebleau; article 1 the demolition of
  the remaining Protestant churches; articles 2-3 the ban on Reformed worship;
  article 4 pastors given two weeks to convert or be banished; article 10 the
  ban on Reformed emigration; article 8 children to be baptised and raised
  Catholic. Emigration figure: 160,000 to 200,000 left France, going chiefly to
  the United Provinces (c. 70,000), England (40,000-50,000), the German states
  (c. 40,000) and Switzerland.

glorious_revolution — 1688
  https://www.nationalarchives.gov.uk/education/resources/significant-events/glorious-revolution-1688/
  https://www.nationalarchives.gov.uk/explore-the-collection/stories/declaration-of-rights/
  https://www.parliament.uk/about/living-heritage/evolutionofparliament/parliamentaryauthority/revolution/overview/
  Confirms: William of Orange landed at Torbay 5 November 1688; James II left
  London in December; Convention Parliament of 22 January 1689; the Declaration
  and then the Bill of Rights of 1689, in which Parliament declared that no
  future monarch could be a Catholic or married to a Catholic.

toleration_act_1689 — 1689
  https://www.parliament.uk/about/living-heritage/transformingsociety/private-lives/religion/key-dates1/1689-to-1829/
  https://www.parliament.uk/about/living-heritage/transformingsociety/private-lives/religion/overview/catholicsnonconformists-/
  https://www.parliament.uk/about/living-heritage/transformingsociety/private-lives/religion/case-study-charles-stanhope-and-freedom-of-religion/charles-stanhope-and-freedom-of-religion-/background-to-religious-discrimination/
  https://www.legislation.gov.uk/aep/WillandMar/1/18/enacted
  Confirms: 1689 act allowing most dissenters to worship publicly on taking a
  simplified oath of allegiance, in meeting houses licensed by Justices of the
  Peace; Roman Catholics excepted by name; Unitarians excepted in effect by the
  required declaration of belief in the Trinity; dissenters remaining under
  other restrictions. NOTE: legislation.gov.uk files the statute under its
  regnal-year title "Toleration Act 1688"; UK Parliament's own pages, and
  general usage, date it 1689, which is the year used.
```
