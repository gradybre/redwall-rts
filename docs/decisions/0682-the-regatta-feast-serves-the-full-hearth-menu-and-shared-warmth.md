# 0682 — The regatta feast serves the full Hearth menu, and earns Shared Warmth
Date: 2026-10-01 · Status: Accepted (its two readings ruled by Brendan, 2026-10-01: approved as built)

**Brendan's ruling, 2026-10-01: "add nuts & herbs now"** — the regatta feast gets its nuts and herbs now, so its full GDD
menu (the nut loaf and the warm infusion) and the feast buff work. This answers decision 0438's open question (its
"missing courses" reading); 0438's follow-up section points here. Nuts and herb come from foraging trips (decision 0681),
flour from the mill (0434).

## Decision

**The second course** — §5.7's `nut_loaf` row exactly (flour 2, nuts 2, water 1 → 3 × 2600 NP, 24 WU, 72 h, M1), cooked
as the content library's `redwall::RW-RECIPE-nutbread` (meal_rules.gd `DISH_NUT_LOAF`, index 4; an occasion-only dish,
like the hotpot, never in the alternation). ceil(E/3) batches. At confirmation, when the pantry holds every batch's
flour and nuts free, both are reserved in the regatta's own take beside the hotpot's beans and cabbage.

**The kitchen's two-course occasion** (kitchen.gd AN OCCASION's second course): `set_occasion(key, dish, batches, take,
second, second_batches)` — the main course's batches cooked first, then the second's, from the one take (the cook
fetches both together); at the table each diner of the occasion eats one portion of each course (§5.7: "Each attendee
receives one main and one second-course portion"), reserving the course it has not had (`meal_store.gd reserve_one`'s
new `dish`); the kitchen records which courses each ate (`occasion_courses`). A single-course occasion and every
ordinary meal are unchanged.

**The warm infusion** — water ceil(E/4) U + herb 0.25 × ceil(E/12) U, "prepared during service from its reserved
water/herb; no stored output item or extra work". At confirmation the herb is reserved in its own take and the water
counted as owed (the butt is not drawn down days ahead: the kitchen keeps it full); at the supper's end both are consumed
"proportionally to attended/E" (floor) -- the herb from its take, the water drawn from the butt through the kitchen's
own ledger (`kitchen.gd draw_service_water`) -- and the rest of the herb given back. An infusion whose herb or water was
not there to pour was not served, and earns no buff. Skipped before the feast, everything goes back untouched.

**Shared Warmth** (REQ-SET-104/105; §5.7's Hearth row "cold-exposure accumulation −25% and mood +400 for 48 h"): granted
at the supper's end when the second course and the infusion were both served and at least 80% of E ate every course;
applied once — a second Hearth feast while it lasts neither stacks nor extends it. Shown in the chronicle line, the
village news and the Regatta section ("Shared Warmth: 31 h left").

**The preview reflects real stock** (REQ-SET-099's "specific blocking reason and the missing quantity"): "Second: nut
loaf x3 … — can't be made: short of nuts: 6.0 U needed, 2.0 U free — a foraging trip (Woods ▸ Foraging)"; flour names
Mill grain; the infusion names herb or the butt's water; the buff line says "Shared Warmth if 8 of 9 eat every course"
or why none.

The code is `demo/regatta/regatta_menu.gd` (owned by the regatta); `regatta.gd` calls it at the preview, the hold, the
skip and the tally — `_feast_refusal` itself is unchanged: the main course stays the requirement to hold.

## Brendan's rulings (2026-10-01): both readings approved as built

Put to Brendan as proposals (decision 0681's rulings 7 and 8); **he approved both as built on 2026-10-01**.

1. **A course the pantry can't make.** Kept from 0438: the feast is still held, serves what it can and grants no buff
   (REQ-SET-104's "otherwise"), the preview naming the exact shortfall. Alternative: refuse the whole feast until every
   course can be made (a strict REQ-SET-100 reading). Ruled: keep — the occasion still happens.
2. **Shared Warmth's effects are a readout.** The demo models no mood and no cold exposure (meal_rules.gd: "the demo
   models no mood"), so the buff is a settlement state with public readers (`regatta_menu.gd cold_exposure_permille`
   750 while active, `mood_bonus` 400) that nothing consumes yet. When the winter-fuel lane's cold work lands, it can
   read them. Ruled: keep as a readout.

## Why

Brendan ruled the courses in; the GDD gives every number. Holding the courses' food in the same take as the main course
keeps the kitchen's fetch, cook and cancel rules (REQ-SET-091/094) working unchanged for both courses; a separate herb
take keeps the infusion's herb at its store (it is consumed at service, not cooked).

## The independent review (2026-10-01)

Its two HIGH findings were fixed before merge, each with a test: **(H1)** a guest who had eaten one course of a
two-course feast could take a second portion of the same course, and waited at the table for a second course whose food
was gone -- now `_reserve_for` only ever offers the course not yet eaten, and a guest waits only while that course is
really coming (portions held, a batch at the cauldron, or its food reserved); **(H2)** the infusion's water was drawn from
the butt at confirmation and lost when given back to a full butt, outside the kitchen's water ledger -- now it is only
owed until the service draws it through the kitchen's ledger. MEDIUMs fixed: the cook kept on duty by half a course's food
at the cauldron, the Cook card's per-course numbers, an `assert` as the only guard on the forage store's creation.

## Consequences

- The kitchen has five dishes; two cook only for an occasion (`is_occasion_dish`).
- A dishes lane that adds `nut_loaf` as an everyday dish must reuse `DISH_NUT_LOAF` (4), not add a second row.
- The regatta's tally counts attendance from the kitchen's `occasion_courses`, not `fed.last_dish`.

## Source

GDD §5.7 (the nut_loaf row, the Hearth feast row and rules), REQ-SET-099..106; decisions 0381, 0434, 0438, 0681;
Brendan's ruling of 2026-10-01 ("add nuts & herbs now").
