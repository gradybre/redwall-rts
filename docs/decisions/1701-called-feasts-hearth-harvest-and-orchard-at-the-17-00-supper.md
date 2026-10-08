# 1701 — Called feasts: the GDD's Hearth, Harvest and Orchard feasts, called by the player, at the 17:00 supper

Date: 2026-10-07 · Status: Accepted (engineering); the PROPOSALS below await Brendan's ruling

Handoff packet FEAST (`docs/handoff/BACKLOG.md`, "## FEAST — Feasts (#9)"). Branch `feat/demo-feasts`.

**Numbering.** BACKLOG.md assigns FEAST 1261–1270; that range collides with the parallel digging branch (0991–1217 on
its `codex/underground-*` and some `claude/*` branches), so the lead allocated **1701–1709** to this packet, superseding
the BACKLOG range (README §3.6's note of 2026-10-07). 1701 was checked free on every local and remote ref
(`git ls-tree` over `git for-each-ref refs/heads refs/remotes`); `docs/validation/decision_numbers.py` passes.

## Approval and Brendan's ruling (2026-10-07)

Feature #9, feasts (Brendan, 2026-10-01, "NEW 2"; tracker only, first recorded in `RULINGS.md`), with group AE's
SOC-023, feasts with occasion and memory (decision 0493).

**Q-D11, the hour of a feast. Brendan, 2026-10-07: "All at 17:00 supper".** Every feast, called or the regatta's, is
served at the kitchen's 17:00 supper. This is a **DEVIATION from REQ-SET-103's hour** ("When a ready feast begins at
18:00 ..."), by his ruling; the rest of REQ-SET-103 (waves, consumption on attendance) stands. Q-D11 is CLOSED in
`docs/handoff/OPEN_QUESTIONS.md` and indexed in `RULINGS.md`. The regatta was already served at that supper (decision
0438; the 2026-10-01 tracker ruling), so it is unchanged.

## Decision

The HUD's **Feast** command (UI-SET-032) now opens a **Feasts panel** (`demo/feast/`), where the player calls one of
GDD §5.7's three feasts for one of the next suppers, with a keeper (the host). The feast is cooked as the kitchen's
existing **occasion** (decision 0438's API, both courses), served at 17:00, tallied at the kitchen's MEAL FINALIZED event
(decision 0997's reading), and its buff granted and **applied** where the demo models the thing it changes.

### The rules used, as written

- **§5.7's feast table** (and SET-AMEND-001 §4.2 for the Orchard main course): Hearth ceil(E/3) bean_hotpot + ceil(E/3)
  nut_loaf + the warm infusion (water ceil(E/4) U, herb 0.25 x ceil(E/12) U, "prepared during service"); Harvest
  ceil(E/6) feast_fish + ceil(E/3) berry_tart + mead ceil(E/4) U; Orchard ceil(E/4) nut_roast + ceil(E/3)
  orchard_crumble + mead ceil(E/4) U. Each attendee one portion of each course; the beverage "consumed proportionally to
  attended/E with milli-unit rounding at the last attendee"; staffing 2 cooks + 1 keeper; seats >= ceil(E/3); service
  wood ceil(E/12) U reserved at confirmation; at most one feast may start in any 72 game hours.
- **§3's Feast row**: "At most 1 scheduled/active feast" -- a called feast and a held regatta never coexist.
- **REQ-SET-099/100**: the plan shows E, every course's food and portions, the seatings, staffing and the reserves after
  it; a refusal names the specific input and the missing quantity ("needs mead: 2.0 U (0.0 U free) — the brewery's mead").
- **REQ-SET-101**: refused under 3 food-days or 3 fuel-days after the feast unless the player overrides it for this
  feast. Ready food after it leaves the feast's reservation out ("locked feast reservations" are not food-days, §5.8):
  `kitchen.gd days_of_meals_after_milli`, an additive hook. Fuel-days after it are **§5.8's** -- the wood left after the
  service and the batches over the hearths' heating demand plus the cooking mean (`winter/hearth_fuel.gd`), as the
  packet's pitfall asked, not the kitchen's wood alone; the regatta now reads both figures through the same hooks.
- **REQ-SET-102**: held, everything is reserved; cancelled, everything goes back untouched. A feast may be cancelled
  until the kitchen starts cooking its supper (15:00 on its day): after that its batches are under way, the kitchen never
  undoes cooking, and an uncooked remainder would stay with that supper (the review's H1, below).
- **REQ-SET-104/105**: the theme's buff when at least 80% of E ate every course and the beverage was poured; once, 48 h,
  never stacked or extended. The regatta's Shared Warmth is the same Hearth buff (a called Hearth feast does not stack on
  it), and the readers count either.
- **The new courses are §5.7's rows exactly** (SET-AMEND-001 §4.1 for `nut_roast`), appended to the recipe book as
  OCCASION dishes (`dish_book.gd` rows 20–23, never renumbering; added to `ADOPTED_ROWS`): `feast_fish` (fish 4, roots 2,
  herb 0.5, water 2 → 6 x 2500, 48 WU, 36 h; the GDD's own dish), `berry_tart` (flour 2, berries 2, honey 0.5, water 1 →
  3 x 2200, 28 WU, 48 h; the library's `triss::TRI_recipe_feast_tarts`), `nut_roast` (beans 3, roots 2, nuts 1, herb
  0.25 → 4 x 2400, 30 WU, 36 h, no water; the GDD's own), `orchard_crumble` (fruit 3, flour 2, honey 0.5 → 3 x 2300,
  28 WU, 48 h, no water; the library's `rakkety_tam::RAK_recipe_banquet_crumbles`). No pantry item or work-board source
  is added.
- **Buffs applied**: Shared Warmth's cold exposure −25% is **wired** into `winter/cold_exposure.gd` (`gain_permille`,
  scaling exposure gained, never clearing; §5.2's 2000 → 1500 and 1000 → 750 exact; clamped at §5.7's 40% cap) -- the
  packet's pitfall: the regatta published it but nothing read it. Abundant Tables' work +5% is a factor ("feast", 1050)
  on the village's work pace (`work_pace.gd add_factor`). Mood +400, purpose +20%, social decay −20% and the two extra
  newcomers are shown, not applied: the demo models no mood, purpose or social need and no arrivals.
- **M4's "12 completed feasts"** is bound (`goal_book.gd bind_measure`; 0901 left it unbound): the called feasts
  completed plus the regatta's `feasts_served`.

### Numbers chosen that the GDD does not give (PROVISIONAL)

| Number | Value | Source |
|---|---|---|
| Suppers offered | the next 3 (`DAY_CHOICES`) | this decision; three suppers fit inside one 72-h interval |
| The day's cut | today's supper only before 15:00 | `meal_rules.gd COOK_FROM_HOUR` (the supper's cooking starts then, decision 0421) |
| Seatings | ceil(E / seats), at most 3, inside the supper's 17:00–18:59 | REQ-SET-103's "up to three one-hour waves", at Brendan's 17:00 |
| "Completed" | at least one resident ate the main course | Brendan's 2026-10-07 reading of "Regatta day" (decision 1651), applied to every feast |
| Work-pace factor name | "feast" | display only |

### Shared files touched (all additive hooks)

| File | Hook |
|---|---|
| `godot/demo/demo_village.gd` | `_build_feasts()` after the weather effects (the feasts node, its people hook, the Feast command, the cards, guide and people card give way while its panel is open, M4's `feasts` bound); `feasts()`; one `add_planning("the feasts", ...)` line |
| `godot/demo/kitchen/kitchen.gd` | `days_of_meals_after_milli(set_aside)` and its `_set_aside` pool deduction (empty: no change); a **fix**: a batch of a dish with no water no longer calls `take_water(0)`, which refused and raised "a batch's water or wood was gone" |
| `godot/demo/kitchen/dish_book.gd` | four OCCASION rows appended; three category constants; `ADOPTED_ROWS` |
| `godot/demo/regatta/regatta.gd` | three optional Callables (`feast_clash`, `food_days_after`, `fuel_days_after`); unbound, the regatta's own figures as before; FEAST_CLASH refusal first in `_feast_refusal` |
| `godot/demo/regatta/demo_regatta.gd` | header words only (the Feast command is the feasts' now) |
| `godot/demo/winter/cold_exposure.gd` | `gain_permille` (1000 by default: no change) and `gained_rate` |
| `godot/demo/README.md` | "Called feasts" section; Layout row; the regatta's line |

Not touched: `godot/scripts/core/`, `demo/burrow/`, `demo/tunnel/`, `demo/cast/`, the settlement UI, and the files
#234 changes (`kitchen/meal_rules.gd`, `preserve/*`, `regatta_menu.gd`, `fishery.gd`). **No key added**: the panel is
behind the existing Feast command.

## PROPOSALS for Brendan

- **P1. Which suppers a feast may be called for.** Built: the next three (today's before 15:00). (a) as built; (b) any
  day of the season, as the regatta; (c) tomorrow's only. Recommendation: (a).
- **P2. A called feast needs every course.** Built: the plan is refused naming what is short (REQ-SET-100: "complete
  ingredient/portion requirements"); the regatta keeps your 2026-10-01 ruling to hold with a missing course. (a) as
  built; (b) called feasts follow the regatta's rule (held, no buff). Recommendation: (a).
- **P3. Drinks at a called Hearth feast.** Built: only the Hearth row's infusion; the regatta alone pours mead and the
  cordial (decision 1621) and, once #234 lands, ale and cider. (a) as built; (b) pour whatever the brewery has at every
  feast, as the regatta does. Recommendation: (a).
- **P4. What "completed" means** for M4 and the 72-h interval. Built: at least one resident ate the main course (your
  "Regatta day" reading). (a) as built; (b) only feasts that earned their buff. Recommendation: (a).
- **P5. REQ-SET-106 (a critical emergency pauses serving).** Not built: the demo's threats do not interrupt meals.
  (a) leave it; (b) build it with the incidents (pause serving, keep the unserved portions, cancel after 24 h).
  Recommendation: (a) for now.
- **P6. Food today's supper already holds.** Built as the regatta: only food nobody holds is "free", so a feast called
  for today's supper cannot count the food the kitchen has set aside for that very supper, though the feast replaces it.
  (a) as built; (b) count it (a small kitchen hook, shared with the regatta). Recommendation: (b), as a follow-up.
- **P7. Abundant Tables' +5% work** applied to every resident's work pace for 48 h. (a) as built; (b) a readout only.
  Recommendation: (a).
- **P8. Dish art for the four new courses** (they show the fallback swatch). (a) leave them; (b) add the four dish
  icons to the next costed art list. Recommendation: (b), with the cost itemised then; nothing is spent now.
- **P9. Recording Q-D11 in the specification.** (a) a `DEC-nnn` in `setting_decisions.md` and REQ-SET-103 amended to
  "17:00" at the next integration; (b) leave the GDD's 18:00 and keep the deviation recorded here and in `RULINGS.md`.
  Recommendation: (a).

## Tests and gates

GATES_PLACEHOLDER

## Source

GDD §3 (Feast row), §5.7 (feast table and rules; REQ-SET-099–106), §5.8 (food-days and fuel-days), §5.11 (M4);
SET-AMEND-001 §4; decisions 0438, 0682, 0997, 1601, 1611, 1621, 1625 (on `feat/demo-new-recipes`), 1651; DEC-007;
Brendan's ruling on Q-D11 (2026-10-07).
