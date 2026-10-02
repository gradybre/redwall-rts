# 0681 — Foraging trips: a small party into the woods, through the real forage store
Date: 2026-10-01 · Status: Accepted (its choices ruled by Brendan, 2026-10-01: approved as built)

**Brendan, 2026-10-01, feature #22: "send a small party into the woods for nuts, mushrooms and herbs; they come back hours
later with a haul".** Review ECO-013 (lasting roles for foraged foods: nuts for loaves, herbs for infusions) and the
smallest slice of ECO-014 (a planned outing). Built on `feat/water-ferry-regatta` (decisions 0437–0439). Everything here
is the demo's presentation layer over the settlement's own forage store; nothing writes into the simulation.
Companion: **0682** (the regatta feast's full menu, which these items make possible).

## Decision

### 1. The items are the catalogue's own keys

Four pantry items, `farm_catalog.gd` THE WOODS' FORAGE: `nuts`, `mushrooms`, `herb`, `berries` — the compiled
catalogue's ids (`data/item_definitions.json`) and `scripts/core/forage.gd` PATCH_KEYS, never a generic "forage" item.
§5.7's rows: nuts 1600 NP, raw edible, 720 h; mushrooms 600 NP, not raw, 72 h; herb 0 NP, not raw, 480 h ("care
ingredient"); berries 700 NP, raw edible, 48 h. Each is its own category (`CAT_NUTS 8`, `CAT_MUSHROOMS 9`, `CAT_HERB 10`,
`CAT_BERRIES 11`) so a recipe can name it. `PANTRY_ITEM_COUNT` 24 → 28 (items 24–27, after flour); `item_of_patch` maps
the store's patch rows to them. Raw nuts and berries join the emergency raw food (REQ-SET-013). Roots — §5.5's fifth
patch — exist in the basin but are not gathered (the farm grows roots). Brendan's approval named nuts, mushrooms and
herbs; **berries were added at the dishes lane's request** (its cordial's raspberries are forage; §5.5 has berries as a
patch). **This lane owns these four item definitions**; the dishes lane references their keys.

**The dishes lane's keys** (decision 0603 on `feat/demo-dishes`) are the content library's LEAVES — `hazelnut`, `mushroom`,
`raspberry` — while this lane uses the compiled catalogue's keys, as the task asked. For integration:
`hazelnut` → `nuts`, `mushroom` → `mushrooms`, `raspberry` → `berries`. Forage stays generic, the leaves mapped at integration (ruling 3 below).

### 2. The ecology is the real forage store's

`demo/forage/forage_driver.gd` runs `scripts/core/forage.gd` unforked, as the fishing driver runs `fishing.gd`
(decision 0431): one FORAGE HarvestZone, its own basin, with its five patches created at §5.1's 80% with the compiled
ids (resolved through `resource_catalog_binding.gd`), Automatic daily quota (decision 0030), and at each offset-calendar
midnight ecology.gd's order — year reset on spring day 1, `regrow_daily` (decision 0036's additive regrowth), then
`run_midnight`. So every bound the trip obeys is the GDD's:

| Rule | Source |
|---|---|
| Season: nuts summer/autumn/winter (dormant in spring), mushrooms spring–autumn, herb all year, berries summer/autumn | §5.5 availability table |
| Daily aggregate quota: spring 10.72 U, summer 21.128, autumn 22.232, winter 6.056 | decision 0030 automatic quota |
| Stock never drawn below 20% of capacity (the sustainable floor) | §5.5 |
| Regrowth `min(K−P, floor((K−P)·r·S/10⁶) + 1000)` a day | §5.5, decision 0036 |
| Work per U `ceil(base·10⁶ / ((1000+40·FORAGE)(1000+100·danger)))` | §5.5 |
| Natural danger 1: "remaining land within 64 m of the central hall" (no lookout) | §5.5 danger zones |
| Injury chance `max(1, 8·danger − FORAGE)`/10000 per 60 WU — **shown, never rolled** | REQ-SET-068 (the demo has no FORAGE RNG owner or injury store; the fishery's precedent) |

A forager's share is **claimed** by a real coordinator FORAGE Job (`claim_forage`), collected (`collect_claim`) when its
work is done, and the Job closed; a claim midnight released is collected through the store's unclaimed `harvest` of what
it still admits.

### 3. The trip (`demo/forage/forage_trips.gd`)

- **Authorise** (Woods panel ▸ Foraging): Gather ▸ nuts / mushrooms / herbs, Party ▸ 1–3, Authorise trip, Cancel trip —
  each order with its action card (decision 0332). Refused, with words, when the kind is dormant, when nothing is left
  today (the quota, or the floor), when three trips are out or the board has no rows.
- **Each forager is a seat**, a work-board task (`work/forage_work.gd`, **SOURCE_FORAGE = 9**; `SOURCE_WALK` moves to 10,
  past every source, as decision 0431 moved it), the **Woods** activity, to the selected residents first.
- **At the spot** the seat is checked again (in season, its share still admitted, room held in a store — decision 0222)
  and claims; gathers at §5.2's base step (80% on a heavy-rain day, §5.10, the woods' rule), FORAGE XP 10 a WU (§5.3);
  collects into its hands, carries the haul home in the fishery's basket model, shelves it as its item.
- **Nothing is lost**: called away (an order, the night, a meal), the seat goes back on the board with its claim, room
  and work kept; a haul in hand is delivered before the night or a meal takes its forager; Cancel ends the seats not
  carrying and gives their claims and room back. THE BOOKS — collected == in hand + stored — are checked every frame in
  the suite.

### 4. The player's view

The Woods panel's **Foraging** section (added through a new additive hook, `forest_panel.gd add_section`); the work
board and Work screen ("Forage nuts — the hazel brake"); the party panel's doing words and a "Foraging N" skill line;
the Pantry's Stocks (the items' rows, swatch icons); the Routes layer's public ways gain **the forage grounds** (a work
place in `routes/work_trips.gd`); the field guide gains the four goods, the nut loaf and a "Foraging trips" station.

## Brendan's rulings (2026-10-01): every choice below approved as built

These were put to Brendan as proposals; **he approved all of them as built on 2026-10-01**. They are now his rulings, and
the demo values below stand as recorded. (Rulings 7 and 8 are decision 0682's; ruling 9 is berries, §1.)

1. **The basket: 4 U a forager** — ruled: (a) (`forage_rules.gd BASKET_MILLI`), so a trip of two brings ~8 U and leaves the day's
   quota for another kind. Options: (a) 4 U a forager — *recommended*; (b) a forager's §5.2 carry capacity (48 U small),
   so the daily quota alone bounds a trip and one trip a day takes it all; (c) the player sets the haul.
2. **The spots** — ruled: keep them: the hazel brake (north woods, −7.5, −29.4) for nuts, the beech hollow (north-east, 10.4, −30.4) for
   mushrooms, the herb bank (sunny south-west edge, −12.0, 23.6) for herbs, the bramble edge (south woods by the road,
   8.0, 25.5) for berries — all one basin (§5.1). Options: keep; or one
   spot for every kind.
3. **Generic items, not leaves** — ruled: (a), generic, the dishes lane's leaves mapped onto them at integration. The farm splits crops into pantry leaves ("a radish is a radish"); forage uses the
   GDD's generic `nuts` / `mushrooms` / `herb` because those are the catalogue's keys and the store's patches. Options:
   (a) keep generic — *recommended* for now, with the dishes lane's leaves mapped onto them at integration; (b) split
   into library leaves (hazelnut, beechnut, chestnut; mushroom; mint, thyme, sage; raspberry, blackberry) as the farm
   does, which needs a leaf→patch mapping no document states.
4. **No FORAGE skill seed** — ruled as built: everyone starts at 0 and learns (no document names a forager's trade).
5. **Trips at most three at once**, a party at most three (DEMO) — ruled as built.
6. **Herbs in winter** follow the GDD (availability 200), though the task brief said "spring to autumn"; nuts follow the
   GDD's summer–winter (not only autumn) and mushrooms its spring–autumn (not only late summer). The GDD table wins — ruled as built.
7. and 8. are decision 0682's (a feast with a course the pantry can't make is still held, without the buff; Shared
   Warmth is a readout) — both ruled as built.
9. **Berries as a fourth forage item** (added at the dishes lane's request, beyond the approval's three kinds) — ruled:
   keep (Brendan, 2026-10-01).

## Why

- **The real store.** Its seasons, quota, floor and regrowth are exactly the "bound by season and a regrowth or
  depletion rule" the feature needs, already ruled (decisions 0026, 0030, 0036); forking them would invent a second
  ecology.
- **Claimed at the spot, not at authorisation**: as the fishery opens its cycle at the water (0431), so quota and stock
  are not held hostage by foragers still walking, and a quota spent meanwhile stops the seat before anything is taken.
- **Rejected**: an abstract timer that adds stock to the pantry (no walk, no claim) — the approval asks for a party that
  goes and comes back; a fourth "forage" item — forbidden by READY_07 §2.

## Consequences

- `PANTRY_ITEM_COUNT` is 28; anything with a per-item table must cover items 24–27 (the field guide's goods do).
- A new work-board source joins below `SOURCE_WALK` (now 10). Concurrent lanes adding a source must renumber.
- The kitchen's raw emergency food includes unreserved nuts.
- No hazard roll or injury: REQ-SET-067/068's consent and roll wait on the FORAGE RNG owner and an injury store.

## Shared files touched (additive hooks)

`farm_catalog.gd` (four items), `meal_rules.gd` (raw nuts and berries), `work_ids.gd` (SOURCE_FORAGE 9, SOURCE_WALK 10),
`demo_work.gd` (`add_forage`), `demo_village.gd` (`_build_forage`, the board), `forest_panel.gd` (`add_section`,
`content_width`), `routes/work_trips.gd` (the forage grounds), `guide/field_guide.gd` (entries).

## Source

GDD §5.5 (the forage table, REQ-SET-066..069), §5.7 (the items), §5.2, §5.3, §5.10; `scripts/core/forage.gd`;
decisions 0026, 0030, 0036, 0052, 0222, 0332, 0411, 0431; review ECO-013, ECO-014; Brendan's approval of feature #22
(2026-10-01).
