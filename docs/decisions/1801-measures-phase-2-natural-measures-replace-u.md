# 1801 — Measures phase 2: natural measures replace "U" in the demo and the settlement UI
Date: 2026-10-09 · Status: Accepted (built; Brendan's rulings of 2026-10-09 below) (MEAS-2; BACKLOG.md's printed range 1181–1190 is replaced by 1801–1819, as
`docs/handoff/README.md` §3.6 directs)

## Decision

Phase 2 of decision 1011 (Brendan's DEC-049): every player-facing amount in the live demo (`godot/demo/`), the tunnel
and burrow stores, and the settlement UI (`godot/scripts/ui/`, `godot/scripts/systems/ui_manager.gd`) is worded by one
module, `godot/scripts/ui/goods_measures.gd`, in each good's natural measure, with its weight in the tooltip. "The U
view" becomes "Underground" in player text; the U key stays. A lint (`test/test_demo_no_u_text.gd`) keeps "U" from
coming back. Display only: no `*_milli` arithmetic, no `STEP`, no `scripts/core/` file and no save changes.

This record holds what phase 2 found and chose, not 1011's rules again. 1011 §1/§1a (the table), §2 (wording), §3/§4b
(the Wood levels), §4 (the plan) and §5 (Underground) are the rules.

## Brendan's rulings (2026-10-09, relayed by the coordinator)

- **B1 (a), "Update the pin":** the ADR 1212 projection update for `godot/scripts/systems/ui_manager.gd` is authorised
  -- master's bytes archived, a reviewed-delta row, `PROJECTION_SHA` / `REVIEWED_SHA` bumped, the pack regenerated.
  Done (see "The memory pack's pin on ui_manager.gd").
- **P-M1 (a)** (the new goods' measures, as built) **with P-M3 (b)**: the cask shows halves. Done: `M_CASK`'s halves
  flag, and the sweep's cask exemption removed (every "from 2" measure now keeps 1011's 20% bound).
- **P-M2, P-M5, P-M7, P-M8: (a)**, as recommended (as built).
- **P-M4 (b) and P-M6 (b)**, as recommended, **as follow-ups, not on this branch**: `docs/handoff/BACKLOG.md`
  MEAS-FOLLOWUPS, with the Cellar bar's unseen Build tooltip and the UI reference renders.

## Rulings this runs under

- Brendan, 2026-10-02: 1011's table, P1–P6, P8, P7 "Apply to demo and game spec", P9 (b), P10 (b) (DEC-049).
- Brendan, 2026-10-08 (relayed by the coordinator, RULINGS.md): MEAS-2 runs after the digging revamp lands, as **one
  pass** over the demo, the tunnel and burrow stores and the settlement UI. Everything is in scope: the U strings the
  2026-10-07/08 lanes added (hives, preserving, brewing, new recipes, feasts, fishing, orchard outings, the ration
  reserve, balance tuning) and the digging revamp's own. Docs, decision records and balance reports keep U; only
  player-facing text changes.

## The module (slice 1)

`godot/scripts/ui/goods_measures.gd`: static, `RefCounted`, const rows compiled once into packed columns.

- `amount` / `amount_cell` (round down), `need` / `need_cell` (round up), `exact` / `exact_cell` (largest dividing
  measure, else the exact weight), `have_need` ("4 of 5 planks", "5 planks — enough"), `grams` (integer),
  `weight` ("62.5 kg", "10 litres (10 kg)"), `tooltip` ("12 sacks of barley — 60 kg"), `noun`, `knows`,
  `wood_level` / `level_words`.
- **Sentence and cell forms.** 1011 §2 asks for "a" in a sentence and the digit in a cell, "no barley" in a sentence
  and "none" in a cell. So each rendering has both: the sentence names the good ("12 sacks of barley"); the cell drops
  the name and the article ("12 sacks", "1 sack", "½ jar", "none") for a row whose label already names the good.
- **Masses** are read through `item_definitions.gd` into a one-slot inventory, never retyped. A demo good names the
  catalogue row it weighs as (radish as `roots`, wheat as `grain`, planks as `wood`: P2).
- **An unknown good** `push_error`s and returns "?"; the log gate fails the suite on it.
- **The Wood level** is a pure function of the owner's flags (`very_low`, `running_low`) and projection: no threshold
  is made in the module, the demo HUD passes the winter's `firewood_urgent()` / `firewood_wanted()` /
  `projection_milli()`, and the settlement HUD the economy's §5.8 figures.
- **The "½" glyph** is in all four NotoSans faces and `NotoSerif-SemiBold.ttf` (checked by
  `test_the_half_glyph_is_in_every_ui_font`), so halves print as "½", not "1 and a half".

### Readings, recorded

- **"From 2" against halves.** 1011 §2's examples include "1½ sacks", but the sack is "from 2": a container measure
  is used only from two of it upward. The table wins: 30 U of barley reads "30 scoops of barley"; halves of a sack
  show from "2½ sacks" to "9½ sacks". "1½ jars of honey" (the jar is not "from 2") is the halves example that occurs.
- **Mixed food has no "from 2"** (§1: "baskets of food (5 U = 1.25 kg, ½), then bowls"), while `spoiled_food` (§1a:
  "as mixed food: basket, from 2, ½") has. Both are built as written: "a basket of food", "5 bowls of spoiled food".
- **The 20% accuracy bound** (1011 §2) holds for every "from 2" measure. The cask was the one without halves (59 U of
  mead read "2 casks", 32% under) until Brendan's P-M3 (b) gave it halves: "2½ casks of mead". The sweep checks every
  "from 2" measure, the cask included.
- **`exact` respects "from" and the ten-measure halves limit**, so 20 U of grain authored is "20 scoops of grain", not
  "a sack" (a sack is never shown below two), and 230 U is "230 scoops" (11½ sacks has no half shown).
- **have_need's have below one of the need's measure** reads "under 1 of 5 planks" (or "under ½ of ½ jar"), not "0",
  keeping "nothing present reads zero". A have of nothing reads "0 of 5 planks".
- **The weight of a trace** is "under 1 g" in a tooltip; an amount already shown as a weight ("40 g of herbs") gets no
  second weight in its tooltip.
- **A need's kilograms are raised** to the 10 g step (a stock's are floored), so "1.81 kg of iron" never understates.

## Slice 2: the HUD, the stores and the settlement UI

- **The demo's Wood cell** (`demo_hud_model.gd`) is the level when the winter is bound (`bind_fuel` now also reads
  `firewood_urgent`, `firewood_wanted` and the fuel's `projection_milli`), else the count ("40 logs"). The level is a
  **state in words**, drawn in the 16 px disclosure role as Heating fuel's "No demand" is: measured at 1280x720,
  "running low" is 106 px in the 18 px value face against the cell's 101 px, and 91 px at 16 px. So it never turns
  into "See ledger" (`test_running_low_fits_the_narrowest_wood_cell`). The model's `stamp` carries the level, so a
  season turning repaints the cell with no change in the wood.
- **Stone** is "20 blocks"; **Ready food's fallback** (no kitchen) is "6½ baskets" in the cell. The tooltips add the
  weight ("Wood: 40 logs (200 kg) in the village stores (and 3 planks)"); with the level, 1011 §3's form: "Wood: enough
  — 40 logs (200 kg) in the village stores; winter needs 60 logs (and 3 planks)". The ledger keeps the counts: "Wood:
  40 logs · 3 planks in store".
- **The stores' line** (`tunnel_stores.gd stock_line`) is "Village stores: 40 logs · 20 blocks of stone · 3 planks · no
  earth". It stays (it is no longer a U helper); `units_text` beside it is deleted in slice 9.
- **Cost rows** (`action_card.gd add_cost`) take the good: `add_cost(what, good, have, need)`, and read through
  `have_need`: "Planks: 0 of 5 planks", "Wood: 2 logs — enough". *Reading, recorded:* the measure noun stays after
  the count even where the row's name repeats it ("Planks: ... planks"), because for a container measure the count
  alone would be ambiguous ("Barley: 1½ of 2½ sacks"); 1011's "Planks: 4 of 5" example drops it. A new
  `short_text(k)` says what a row lacks as a need ("5 planks"); the bridge's shortage line uses it. All 33 `add_cost`
  callers pass their good now, including those in later slices' files (only those lines). The kitchen's and the
  preserving rows' recipe categories map to goods through the new `meal_rules.gd CATEGORY_GOODS` and `selector_good`
  (a single-item selector is that item; several items in one category, that category; anything, mixed food).
- **The settlement HUD** (`scripts/systems/ui_manager.gd`): Wood and Stone are UI-SET-004/005's amended readout,
  "180 logs available; none reserved" and "100 blocks available; none reserved" (available is §5.8's unreserved
  stock, reserved the rest). *Reading, recorded:* §4a says `hud.gd set_counter` takes the good; but hud.gd's contract
  is to render byte for byte and never derive, so ui_manager composes the readout through the module and hands it to
  `set_counter_text`, as it already does for Food-days. `set_counter` keeps its unit for the NP counter.
- **The settlement Wood level.** §4b's levels after "none" all read fuel-days or REQ-SET-114's projection, and the
  economy has no heating-demand input for either (`EconomySystem.fuel_days_missing_input`). So the level is shown as
  "none" with no available wood ("none — none available; 4 logs reserved") and is otherwise omitted, not guessed. See
  P-M2.
- **The specimen's** synthetic counter reads "1,234 logs".

## PROVISIONAL rows: goods 1011 has no row for

1011 was written before the 2026-10-07/08 lanes. These goods are now shown and had no measure; each is built so a
different ruling is a one-row change in `ROWS`.

| Good (demo key) | Weighs as (g/U) | Measure, then below | Why |
|---|---|---|---|
| Ale (`ale`), cider (`cider`) | mead (1000) | cask, from 2, ½ (20 U); jug (1 U = 1 L) | Brewed drinks kept like mead (1011's approved mead row) |
| Cordial (`cordial`) | mead (1000) | jug (1 U = 1 L); cup (0.25 U) | A table drink, poured by the cup at supper; never casked |
| Apple vinegar (`vinegar`) | mead (1000) | jug (1 U); cup (0.25 U) | An ingredient measured like water |
| Berry jam (`jam`), pickles (`pickles`) | dried fruit (250) | jar, ½ (1 U = 250 g) | Kept in jars, as honey is |
| Nut cheese (`cheese`) | dried fruit (250) | round, ½ (1 U = 250 g) | A small pressed round |

Dried fruit (bag, 1 U), rations (counted), honey (jar, ½), wax (cake, ½; piece 0.25 U) and mead (cask from 2, ½ since P-M3 (b); jug)
already have approved rows (1011 §1, §1a). Apples and pears use §1's "Apple, pear" row (basket from 2, ½; counted).

## Inventory (slice 1, at `0727350a`)

Found by grepping `godot/demo/`, `godot/scripts/ui/` and `godot/scripts/systems/` for the U helpers' calls
(`units_text`, `units`, `_units`, `amount_text`, `need_text`, `add_cost`, `stock_line`, `amounts_text`, `food_text`; a
regular-expression count, which includes a few same-named calls that are not amounts) and by the lint's own scan for
literal-U strings outside comments and docstrings. 1011's figures (about 75 files and 280 call sites) were taken at
`fd9b80a1`; the 2026-10-07/08 lanes and the digging revamp brought it to **103 files, about 520 helper calls and 84
literal-U strings**. Each file is assigned to 1011 §4's slice by its directory; the lanes added since go to the slice
nearest their subject (orchard and hives with the farm and pantry; preserving, brewing and feasts with the kitchen;
the digging revamp's `burrow/modular_*` with the burrow).

The helpers themselves (deleted in slice 9): `farm/farm_text.gd units_text`, `forestry/forest_rules.gd units_text`,
`tunnel/tunnel_stores.gd units_text` and `stock_line`, `ui/action_card.gd amount_text`, `need_text` and `add_cost`,
`stores/cellar_projects.gd units_text`, `infirmary/infirmary_project.gd units_text`, `infirmary/care_text.gd units`,
`fishery/fishery_text.gd units`, `farm/farm_tending.gd _units`, `burrow/room_fixtures.gd amounts_text`, and the
wrappers `farm/farm_plan_rows.gd units`, `farm/farm_hud.gd food_text`, `kitchen/kitchen_text.gd units`,
`winter/winter_text.gd units`, `hives/hive_rules.gd units`, `orchard/orchard_text.gd units`, `feast/feast_menu.gd
units`, `forage/forage_rules.gd units_text`, `ferry/ferry_rules.gd units_text`, `waterplay/swim_rules.gd units_text`,
`regatta/regatta.gd _units`, `regatta/regatta_menu.gd _units`; the dispatchers `goals/goal_book.gd amount_text`,
`guide/projects.gd amount_text`, `orders/standing_kinds.gd amount_text`.

The "underground view" strings to rename (1011 §5): `tunnel/tunnel_control.gd` VIEW_ON and LEVEL_SHOWN,
`guide/help_topics.gd` ["U", "Underground view"], `ui/demo_lens_picker.gd` KEY_HINT, `control/group_select.gd`
SEND_BELOW, `control/demo_party_panel.gd` HINT, `sound/sound_table.json` "(U view)", and 14 mentions in
`godot/demo/README.md`.


**Slice 2** — 5 files, 13 helper calls, 3 literal-U strings

| File | Helper calls | Literal U |
|---|---:|---:|
| `demo/tunnel/tunnel_stores.gd` | 4 | 1 |
| `demo/ui/action_card.gd` | 4 | 1 |
| `demo/ui/demo_hud_model.gd` | 4 | 0 |
| `demo/work/stores_work.gd` | 1 | 0 |
| `scripts/ui/ui_specimen.gd` | 0 | 1 |

**Slice 3** — 23 files, 131 helper calls, 17 literal-U strings

| File | Helper calls | Literal U |
|---|---:|---:|
| `demo/farm/farm_bed_panel.gd` | 1 | 0 |
| `demo/farm/farm_card.gd` | 5 | 0 |
| `demo/farm/farm_crew.gd` | 12 | 0 |
| `demo/farm/farm_crop_roles.gd` | 0 | 1 |
| `demo/farm/farm_harvest_page.gd` | 3 | 0 |
| `demo/farm/farm_harvest_plan.gd` | 2 | 0 |
| `demo/farm/farm_hud.gd` | 1 | 0 |
| `demo/farm/farm_pantry_panel.gd` | 3 | 0 |
| `demo/farm/farm_pantry_rows.gd` | 8 | 0 |
| `demo/farm/farm_plan_rows.gd` | 5 | 2 |
| `demo/farm/farm_record_text.gd` | 13 | 0 |
| `demo/farm/farm_season.gd` | 3 | 1 |
| `demo/farm/farm_soil_plan_text.gd` | 4 | 0 |
| `demo/farm/farm_soil_plans.gd` | 2 | 0 |
| `demo/farm/farm_tending.gd` | 1 | 1 |
| `demo/farm/farm_tending_page.gd` | 0 | 1 |
| `demo/farm/farm_text.gd` | 7 | 3 |
| `demo/hives/apiary_model.gd` | 1 | 0 |
| `demo/hives/hive_rules.gd` | 1 | 0 |
| `demo/hives/hive_text.gd` | 16 | 2 |
| `demo/orchard/orchard_cards.gd` | 24 | 3 |
| `demo/orchard/orchard_jobs.gd` | 12 | 0 |
| `demo/orchard/orchard_text.gd` | 7 | 3 |

**Slice 4** — 11 files, 65 helper calls, 10 literal-U strings

| File | Helper calls | Literal U |
|---|---:|---:|
| `demo/feast/called_feast.gd` | 1 | 0 |
| `demo/feast/feast_menu.gd` | 7 | 1 |
| `demo/feast/feast_panel.gd` | 1 | 0 |
| `demo/feast/feast_text.gd` | 8 | 0 |
| `demo/kitchen/kitchen.gd` | 12 | 4 |
| `demo/kitchen/kitchen_tab.gd` | 5 | 1 |
| `demo/kitchen/kitchen_text.gd` | 17 | 1 |
| `demo/preserve/preserve_text.gd` | 3 | 3 |
| `demo/winter/demo_winter.gd` | 2 | 0 |
| `demo/winter/fuel_panel.gd` | 1 | 0 |
| `demo/winter/winter_text.gd` | 8 | 0 |

**Slice 5** — 19 files, 117 helper calls, 8 literal-U strings

| File | Helper calls | Literal U |
|---|---:|---:|
| `demo/ferry/demo_ferry.gd` | 13 | 0 |
| `demo/ferry/ferry.gd` | 7 | 0 |
| `demo/ferry/ferry_rules.gd` | 1 | 0 |
| `demo/forage/demo_forage.gd` | 10 | 1 |
| `demo/forage/forage_rules.gd` | 1 | 0 |
| `demo/forage/forage_trips.gd` | 12 | 0 |
| `demo/forestry/demo_forestry.gd` | 1 | 0 |
| `demo/forestry/forest_card.gd` | 5 | 0 |
| `demo/forestry/forest_crew.gd` | 10 | 2 |
| `demo/forestry/forest_rules.gd` | 0 | 1 |
| `demo/forestry/forest_text.gd` | 6 | 1 |
| `demo/regatta/demo_regatta.gd` | 3 | 0 |
| `demo/regatta/regatta.gd` | 12 | 0 |
| `demo/regatta/regatta_menu.gd` | 19 | 0 |
| `demo/routes/bridge_project.gd` | 4 | 0 |
| `demo/waterplay/demo_waterplay.gd` | 5 | 1 |
| `demo/waterplay/swim_rules.gd` | 1 | 0 |
| `demo/waterplay/water_panel.gd` | 0 | 2 |
| `demo/waterplay/waterplay_text.gd` | 7 | 0 |

**Slice 6** — 5 files, 68 helper calls, 1 literal-U strings

| File | Helper calls | Literal U |
|---|---:|---:|
| `demo/fishery/demo_fishery.gd` | 41 | 0 |
| `demo/fishery/fishery.gd` | 20 | 0 |
| `demo/fishery/fishery_stewardship.gd` | 1 | 0 |
| `demo/fishery/fishery_text.gd` | 6 | 0 |
| `demo/water/water_overlay.gd` | 0 | 1 |

**Slice 7** — 22 files, 43 helper calls, 21 literal-U strings

| File | Helper calls | Literal U |
|---|---:|---:|
| `demo/burrow/fixture_card.gd` | 4 | 0 |
| `demo/burrow/modular_demo_mode.gd` | 0 | 1 |
| `demo/burrow/room_fixtures.gd` | 1 | 1 |
| `demo/burrow/room_text.gd` | 2 | 1 |
| `demo/hall/hall_crew.gd` | 1 | 0 |
| `demo/hall/hall_panel.gd` | 5 | 2 |
| `demo/hall/hall_projects.gd` | 1 | 0 |
| `demo/infirmary/care_desk.gd` | 4 | 2 |
| `demo/infirmary/care_tasks.gd` | 0 | 2 |
| `demo/infirmary/care_text.gd` | 4 | 4 |
| `demo/infirmary/infirmary_place.gd` | 3 | 0 |
| `demo/infirmary/infirmary_project.gd` | 3 | 0 |
| `demo/spoil/demo_spoil.gd` | 0 | 1 |
| `demo/spoil/spoil_crew.gd` | 0 | 1 |
| `demo/stores/cellar_bar.gd` | 2 | 1 |
| `demo/stores/cellar_place.gd` | 2 | 0 |
| `demo/stores/cellar_projects.gd` | 6 | 1 |
| `demo/tunnel/dig_readout.gd` | 0 | 2 |
| `demo/tunnel/tunnel_actions.gd` | 4 | 0 |
| `demo/tunnel/tunnel_control.gd` | 0 | 1 |
| `demo/tunnel/tunnel_ext.gd` | 1 | 0 |
| `demo/work/spoil_work.gd` | 0 | 1 |

**Slice 8** — 18 files, 96 helper calls, 24 literal-U strings

| File | Helper calls | Literal U |
|---|---:|---:|
| `demo/chronicle/chronicle_writer.gd` | 2 | 0 |
| `demo/goals/goal_book.gd` | 0 | 1 |
| `demo/goals/goals_page.gd` | 4 | 0 |
| `demo/goals/village_goals.gd` | 0 | 2 |
| `demo/guide/field_guide.gd` | 49 | 11 |
| `demo/guide/guide_status.gd` | 2 | 0 |
| `demo/guide/help_topics.gd` | 0 | 1 |
| `demo/guide/practice_stories.gd` | 20 | 8 |
| `demo/guide/projects.gd` | 5 | 0 |
| `demo/guide/projects_page.gd` | 3 | 0 |
| `demo/orders/goal_meals.gd` | 1 | 0 |
| `demo/orders/goal_planks.gd` | 2 | 0 |
| `demo/orders/standing_kinds.gd` | 2 | 0 |
| `demo/orders/standing_orders.gd` | 1 | 0 |
| `demo/orders/standing_row.gd` | 1 | 0 |
| `demo/orders/standing_text.gd` | 3 | 0 |
| `demo/orders/standing_view.gd` | 1 | 0 |
| `demo/sound/sound_table.json` | 0 | 1 |



## How a call site is converted (the house style, for every slice)

- **Name the good.** Every call takes the good's key: a pantry item's `Catalog.ITEM_KEYS[item]`, a store's `&"wood"`,
  `&"stone"`, `&"planks"`, `&"earth"`, `&"water"`, `&"compost"`, `&"cloth"`, `&"rope"`; a recipe category's
  `&"grain"`, `&"roots"`, `&"greens"`, `&"beans"`, `&"fish"`, `&"flour"`, ...; mixed food `&"food"`.
- **Pick the rounding by what the number is.** Stock, a harvest, a catch, a yield, what was carried or delivered:
  `amount`. A cost, a requirement, a rate, what is still needed: `need`. A rule constant or a player's target:
  `exact`. A cost row with stock beside it: `have_need`.
- **Sentence or cell.** In running text use the sentence form, and drop the now-doubled good name: "Carrying %s of
  %s to the pantry" with `units_text` and the item word becomes "Carrying %s to the pantry" with
  `amount(key, milli)` ("Carrying 3 bunches of carrots to the pantry"). In a labelled cell or a "Wood: …" row use the
  cell form ("Wood: 40 logs", "Barley: 12 sacks").
- **Carry statements are weights** (§5.2's carry is mass): "a mouse carries 12 U" becomes "a mouse carries 12 kg".
- **Floats leave**: a `%.1f U` site takes the milli-U integer and the module.
- **Tests are rewritten by hand** from 1011's table, never generated from the module; assertions on milli-U values do
  not change.

## Progress

- [x] Slice 1: the module, `test_demo_measures.gd` (19 tests), and the lint `test_demo_no_u_text.gd` switched on with
  an exact, shrinking allowlist (44 files, 84 strings).
- [x] Slice 2: the HUD (demo and settlement) and the stores (and every `add_cost` caller).
- [x] Slice 3: farm and pantry, with the orchard and the hives (built in its own worktree, cherry-picked).
- [x] Slice 4: kitchen and winter, with preserving, brewing and feasts.
- [x] Slice 5: the woods: forestry, forage, ferry, regatta, waterplay, bridges.
- [x] Slice 6: fishery and water.
- [x] Slice 7: infirmary, hall, cellars, burrow (and the digging revamp), tunnel, spoil; tunnel_control's VIEW_ON and
  LEVEL_SHOWN renamed.
- [x] Slice 8: guide, goals, orders, chronicle, practice stories, and the Underground rename.
- [x] Slice 9: the lint's allowlist empty, `godot/demo/README.md` (a "Natural measures" section; 16 "U view" mentions
  renamed; 13 quoted amounts updated), and the 23 old helpers deleted.
- [x] Gates: see Gates.

## How slices 3–8 were built

Slices 3–8 touch disjoint directories, so each was built in parallel by a subagent in its own worktree branched from
slice 2 (`b34a1153`), on the house style above, then cherry-picked here in the order 6, 7, 8, 4, 5, 3. The only
conflicts were the lint's ALLOWLIST (each slice removed its own entries: resolved to the entries both sides kept) and
two test files where two slices changed one assertion line (`test_demo_kitchen_ui.gd`'s stock rows, slice 3's stock
and slice 4's reserved part; `test_demo_orchard_ui.gd`'s raw-NP check, slice 8's berries and slice 3's apples).

## Readings the slices made (recorded; none changes a rule)

- **Rounding by role, everywhere.** Stock, catches, harvests, what is carried or held: `amount`. Costs, rates, room
  needed, refusals' shortfalls: `need`. Recipe inputs and outputs of one batch, doses, hearth rates, the reserve
  target, standing-order targets: `exact` (a tier-2 hall's hearth rate reads "6 quarter logs", where `need` would round
  it to the tier-1 hearth's "2 logs" and hide the saving).
- **"NP a unit"** became NP for the good's smallest whole measure: "1200 NP a jar" (honey), "900 NP an apple", "700 NP
  for a bowl of berries", "1400 NP for a bag of dried fruit", "2400 NP for a ration". The figure does not change where
  the measure is 1 U; for goods whose smallest whole measure is not 1 U (the guide's crops) the NP is scaled to that
  measure ("800 NP for a bunch of carrots").
- **Loads and limits are weights** ("a mouse carries 12 kg, an otter 16 kg, the badger 24 kg"; the orchard's cart "10
  kg a haul"; a forager "at most 8 handfuls each"). A forager's 4 U basket was no longer called a basket, so it does
  not clash with the table's 5 U basket.
- **Sentences reshaped, not padded.** A count with its own article cannot follow "the other" or start a capitalised
  sentence, so: "the rest (3 bunches of carrots)"; "The village brought %s into store: ..."; "Stock: about 720 perch
  (80% of 900 perch) · quota 52 fish a day, 25 fish left".
- **Quotas are fish.** A water's quota is every species', so it counts "fish"; a stock is its species ("about 720
  perch"). The forage basin's shared quota is worded in the chosen kind's measure (all forage is 250 g a U).
- **A food store's fill** reads "Holds 4 baskets of food (up to 10 baskets)", not `have_need` (which would say
  "enough" for a full store). Capacities carry no weight (P5); the Cellar building's 500 g/U capacity (decision 0612,
  Q-D6) is left alone and shown in baskets.
- **Bare numbers** the lint could not see were converted too (the hall's and infirmary's costs, "Holds %d of %d",
  the cellar bar, the hall tapestry).
- **The prewarm step name "underground view"** (`demo_village.gd`) is never shown to a player, so it was left.
- **farm_text.gd's "Needs:" line** (`need_text`, a bed's need) is not an amount helper and stays.

## Deviations from the packet, declared

- **`test_demo_conservation.gd` was edited, text-only.** The packet says conservation tests pass unedited. That suite
  also asserts player text (the farm's refusal "no store has room for ...", the Pantry's stock cells and header, and
  F28's units-form test of the deleted `units_text`/`food_text`). Those assertions were rewritten by hand to the new
  words; every milli-U, conservation and arithmetic assertion is unchanged. F28's test now checks the same rule through
  the module ("12 g" of carrot is never "none"; 5.1 U is "5 bunches", floored).
- **Slices 3–8 were built in parallel**, not one after another (see above); each was tested on its own and the
  integration run here.
## PROPOSALS — ruled 2026-10-09 (see Brendan's rulings above)

- **P-M1 — The measures for goods added since 1011** (the PROVISIONAL rows above: ale and cider in casks and jugs;
  cordial and vinegar in jugs and cups; jam and pickles in jars; nut cheese in rounds). (a) As built. (b) Different
  measures for any of them. **Recommendation: (a).**
- **P-M2 — The settlement HUD's Wood level before §5.8 has heating demand.** (a) As built: "none" with no wood,
  otherwise no level until fuel-days and the winter projection exist. (b) "enough" whenever there is wood.
  **Recommendation: (a)**: (b) would be a reading nobody derived.
- **P-M3 — The cask.** (a) Keep it whole-only, as approved: 2.99 casks reads "2 casks". (b) Give it halves, so every
  "from 2" measure keeps 1011's 20% bound ("2½ casks of mead"). **Recommendation: (b)**; a one-flag change.
- **P-M4 — The settlement Wood and Stone cells.** UI-SET-004/005's amended readout ("180 logs available; none
  reserved") is far wider than the 104–144 px cell, so the cell draws the shell's "See ledger" and the ledger line
  carries the readout (UI-C3-R01 §2's own rule). (a) Keep it. (b) Let a counter carry a short cell value ("180 logs",
  or the level) beside its full ledger readout, a change to hud.gd's one-string contract. **Recommendation: (b)**, in
  a settlement UI lane; the demo's top bar already shows the short form.
- **P-M5 — Logs have no halves.** A 1.5 U deadfall pile reads "a log", 2.75 U "2 logs". (a) Keep it, as approved.
  (b) Give the log halves. **Recommendation: (a)**: the tooltips and ledger keep the weight.
- **P-M6 — The crossing story's load** (`guide/practice_stories.gd`): each carrier takes "6 logs" a trip, 30 kg,
  while a mouse carries 12 kg. "6 U" hid this. (a) Keep the story's fixture. (b) Make it 2 logs (10 kg) a trip and
  recompute the rounds (a story fixture, not a balance figure). **Recommendation: (b)**, in a follow-up.
- **P-M7 — The orchard's Keep button** reads "Keep: 4 apples, 4 pears" (the keep is per fruit). (a) As built. (b)
  "Keep: 4 of each". **Recommendation: (a)** unless the frames show it clipping.
- **P-M8 — The feast preview's free food** reads "beans 4 scoops — enough" / "mead 0 of 2 jugs free". (a) As built
  (`have_need`). (b) The old "need (free X)" layout, each in its own measure, which can mix measures ("2½ sacks (free
  39 scoops)"). **Recommendation: (a).**
- **Follow-ups** (BACKLOG MEAS-FOLLOWUPS): P-M4 (b); P-M6 (b); and these two:
- **Found, not fixed (UI behaviour, outside this lane):** the Cellar bar's Build tooltip is set in `configure()` and
  cleared at once by `refresh()` (`FarmUi.set_enabled(_build, true, "")`), so a player never sees it. A small
  follow-up.
- **For the UI art owner (1011 §4a):** the reference renders still say "180 U" / "100 U"
  (`docs/design/ui_refinement/render_targets.py`, `woodland_art_prompt.txt`); they are re-rendered under the art
  process, not hand-edited here.

## The memory pack's pin on ui_manager.gd (was BLOCKED; resolved by B1 (a))

`godot/scripts/systems/ui_manager.gd` is a **pinned reviewed witness** of the underground memory pack (manifest 3,
`docs/validation/evidence/underground-entry-source-phases-2026-10-05/memory-manifest-3.json`; checked by
`tools/underground_room_memory.py`, `docs/validation/ready07_arithmetic.py` and `tools/underground_memory_budget.py
--check`). Slice 2's change to its Wood and Stone counters changed its bytes, so four contracts failed with "reviewed
witness changed: godot/scripts/systems/ui_manager.gd". The lane's first attempt at the ADR 1212 update was refused by
the session's permission system (and so was reverting the file); it waited for Brendan's ruling.

Under B1 (a), the established path (ADR 1212, as `b51ae5bd` did for `excavation_contract.gd`):
- master's bytes (`0727350a`, sha256 `4d64b299…`) archived as
  `docs/validation/evidence/underground-memory-census-2026-10-06/reviewed-sources/ui_manager.gd-4d64b299a4d6.txt`, and
  its row added to that census's `projection.json`;
- a reviewed-delta row in `reviewed-deltas.json`: 0 bytes, "the Wood and Stone counters worded in natural measures;
  two static text helpers, no member, packet or resize". `underground_current_census.delta` of the change is `{}` (no
  member, resize, integer constant or allocation site);
- `PROJECTION_SHA` (`tools/underground_room_memory.py`) and `REVIEWED_SHA` (`tools/underground_current_census.py`)
  bumped to the two files' new digests;
- `docs/planning/underground_memory_pack.json` regenerated by `python3 tools/underground_memory_budget.py`: only the
  file's current source hash, its place among the projected inputs and the reviewed row change. No byte figure moves.

## Gates

- **The full suite, CI-style** (a fresh worktree at `f14d8a86` with no staged art, `.godot` deleted, re-imported,
  eight shards, `tools/ci_test_shards.py verify --count 8`: "ok: 479 suite files executed exactly once across 8
  shards"): 12,141 tests, 1,241,630 assertions, 0 failures; 0 unexpected errors, 0 unexpected warnings; 0 leaked
  objects, 0 leaked resources (each shard's `diagnostics:` and `log:` lines both clean).
- **The analyzer** (`tools/gdscript_warnings.py --max 0 --port 6311`): "0 GDScript warning(s) in 0 of 1476 file(s)".
- **The contracts**: 30 of 34 passed before B1; the 4 that read the underground memory pack failed on
  `ui_manager.gd`. After the pin's update: see "After the rulings" below.
- **Live harnesses** at 1280x720 and 1920x1080 (windowed, captured): food 71/71, winter 44/44, hall 43/43, care 37/37,
  Underground (modular world) 42/42, feasts 18/18, orchard 22/22 (one capture run timed out on a game-time wait under
  load and passed on its rerun), layout 159/159 and 230/230 without capture (two capture-mode timing failures that
  the uncaptured runs, here and on master, do not show); routes and layout headless in the suite.
- **Mutation testing.** `goods_measures.gd`: 57 mutants, all killed (52 first, then 2 survivors killed by new tests,
  then 3 on `divides()`, whose one equivalent survivor was removed by deleting the redundant guard). The lint
  (`test_demo_no_u_text.gd`): 22 mutants over two rounds, all killed (survivors closed by self-tests of the walk, the
  allowance, the docstring rule and no-break spaces).
- **Independent review** (`code-reviewer`, waited for): no CRITICAL, no HIGH. MEDIUM M1–M5 and the lint's structural
  miss fixed (`c348f1af`). LOWs fixed: unused preloads, doubled "of", the double dashes, README quotes, the counters'
  per-frame note, `exact`'s docstring, `level_words(-1)`, `weight(0)`. LOWs answered, not changed: `ferry.gd` reaches
  the module through `StoresScript.Measures` (no new preload in a file the boat lane edits); the `ITEM_KEYS ... else
  &"food"` pattern in five files and the goals/projects text duplication are left for a later tidy; `field_guide.gd
  small_measure_milli` reads the module's cell output (a public "smallest measure" call would be cleaner); the module's
  first call builds its table (one-time, a few ms); `farm_crew` words a load down and the room it needs up (both by
  role); the lint's allowlist machinery stays, empty, for the next lane; the settlement readout's "none — none
  available" is UI-SET-004's own form.
- **Frames looked at** (`scratchpad/meas_check/`, 1280x720 and 1920x1080): the HUD (Wood "enough" / "none", Stone in
  blocks), the Water panel, the preserves, brewing and reserve rows, the Ready-food ledger, the hall, the infirmary
  section, the feasts panel, the orchard, the winter's HUD, Underground (modular world), and the settlement HUD
  (main scene: Wood and Stone draw "See ledger", P-M4). They found one regression, fixed: the Ready-food ledger line
  wrapped and pushed Beds out of the fixed eight-line ledger (`2c250549`; the food harness now checks no ledger line
  wraps).

## After the rulings (2026-10-09)

- **The pin** (B1 (a)): done as recorded above. Two auditor self-tests asserted that an injected change to
  `ui_manager.gd` is refused by the room census itself, which is true only of an unprojected input. They now follow
  ADR 1212's projected-input semantics, as for every other projected input (`refuses_current_change`): the injected
  text is replaced by the reviewed bytes before anything runs, a storage change is refused by the current census
  ("current census: unreviewed storage delta: godot/scripts/systems/ui_manager.gd"), and a method with no storage is
  admitted there (`tools/test_underground_room_memory.py`, `tools/test_underground_memory_budget.py`).
- **The contracts: 34 of 34 pass**, among them `ready07_arithmetic` ("status": "PASS"), `underground_memory_budget
  --check`, `test_underground_memory_budget` (285 tests, OK), `test_underground_current_census` (OK) and
  `decision_numbers` ("PASS -- 538 records, 0 problem(s)").
- **The cask's halves** (P-M3 (b)): `goods_measures.gd`'s mutants rerun with the change, 56 of 56 killed (three new
  ones on the cask's row: its halves flag, its "from 2", its size).

## Consequences

- One module words every player-facing amount; a new good needs its row first, or the suite fails.
- The lint fails on any new "N U", "%d U", "%.1f U", "%s U", bare " U", "U view", or goods counted in "units".

## Source

- Decision 1011 (all sections), DEC-049, `docs/ui_ux_controls.md` UI-SET-004/005/043/050/062/066/099 and "Amounts are
  shown in natural measures"; `docs/handoff/BACKLOG.md` MEAS-2; RULINGS.md 2026-10-08.
- `godot/data/item_definitions.json` (masses), `godot/demo/farm/farm_catalog.gd` (the pantry's 42 goods),
  `godot/demo/kitchen/dish_book.gd` (recipe inputs).
