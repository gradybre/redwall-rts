# 1801 — Measures phase 2: natural measures replace "U" in the demo and the settlement UI
Date: 2026-10-09 · Status: In progress (MEAS-2; BACKLOG.md's printed range 1181–1190 is replaced by 1801–1819, as
`docs/handoff/README.md` §3.6 directs)

## Decision

Phase 2 of decision 1011 (Brendan's DEC-049): every player-facing amount in the live demo (`godot/demo/`), the tunnel
and burrow stores, and the settlement UI (`godot/scripts/ui/`, `godot/scripts/systems/ui_manager.gd`) is worded by one
module, `godot/scripts/ui/goods_measures.gd`, in each good's natural measure, with its weight in the tooltip. "The U
view" becomes "Underground" in player text; the U key stays. A lint (`test/test_demo_no_u_text.gd`) keeps "U" from
coming back. Display only: no `*_milli` arithmetic, no `STEP`, no `scripts/core/` file and no save changes.

This record holds what phase 2 found and chose, not 1011's rules again. 1011 §1/§1a (the table), §2 (wording), §3/§4b
(the Wood levels), §4 (the plan) and §5 (Underground) are the rules.

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
- **The 20% accuracy bound** (1011 §2) holds for every "from 2" measure with halves. The cask (mead, ale, cider) is the
  one "from 2" measure without halves, so 59 U of mead reads "2 casks of mead" (32% under) with "59 litres (59 kg)" in
  its tooltip. The sweep test exempts the cask and says why. See P-M3.
- **`exact` respects "from" and the ten-measure halves limit**, so 20 U of grain authored is "20 scoops of grain", not
  "a sack" (a sack is never shown below two), and 230 U is "230 scoops" (11½ sacks has no half shown).
- **have_need's have below one of the need's measure** reads "under 1 of 5 planks" (or "under ½ of ½ jar"), not "0",
  keeping "nothing present reads zero". A have of nothing reads "0 of 5 planks".
- **The weight of a trace** is "under 1 g" in a tooltip; an amount already shown as a weight ("40 g of herbs") gets no
  second weight in its tooltip.
- **A need's kilograms are raised** to the 10 g step (a stock's are floored), so "1.81 kg of iron" never understates.

## PROVISIONAL rows: goods 1011 has no row for

1011 was written before the 2026-10-07/08 lanes. These goods are now shown and had no measure; each is built so a
different ruling is a one-row change in `ROWS`.

| Good (demo key) | Weighs as (g/U) | Measure, then below | Why |
|---|---|---|---|
| Ale (`ale`), cider (`cider`) | mead (1000) | cask, from 2 (20 U); jug (1 U = 1 L) | Brewed drinks kept like mead (1011's approved mead row) |
| Cordial (`cordial`) | mead (1000) | jug (1 U = 1 L); cup (0.25 U) | A table drink, poured by the cup at supper; never casked |
| Apple vinegar (`vinegar`) | mead (1000) | jug (1 U); cup (0.25 U) | An ingredient measured like water |
| Berry jam (`jam`), pickles (`pickles`) | dried fruit (250) | jar, ½ (1 U = 250 g) | Kept in jars, as honey is |
| Nut cheese (`cheese`) | dried fruit (250) | round, ½ (1 U = 250 g) | A small pressed round |

Dried fruit (bag, 1 U), rations (counted), honey (jar, ½), wax (cake, ½; piece 0.25 U) and mead (cask from 2; jug)
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
- [ ] Slice 2: the HUD (demo and settlement) and the stores.
- [ ] Slice 3: farm and pantry (with orchard and hives).
- [ ] Slice 4: kitchen and winter (with preserving, brewing and feasts).
- [ ] Slice 5: the woods: forestry, forage, ferry, regatta, waterplay, bridges.
- [ ] Slice 6: fishery and water.
- [ ] Slice 7: infirmary, hall, cellars, burrow (and the digging revamp), tunnel, spoil.
- [ ] Slice 8: guide, goals, orders, chronicle, practice stories, and the Underground rename.
- [ ] Slice 9: the lint's allowlist empty, `godot/demo/README.md`, and the old helpers deleted.

## PROPOSALS — for Brendan's ruling

- **P-M1 — The measures for goods added since 1011** (the PROVISIONAL rows above). (a) As built. (b) Different
  measures for any of them. **Recommendation: (a).**
- **P-M3 — The cask.** (a) Keep it whole-only, as approved: 2.99 casks reads "2 casks". (b) Give it halves, so every
  "from 2" measure keeps 1011's 20% bound ("2½ casks of mead"). **Recommendation: (b)**; it is a one-flag change.

## Consequences

- One module words every player-facing amount; a new good needs its row first, or the suite fails.
- The lint fails on any new "N U", "%d U", "%.1f U", "%s U", bare " U", "U view", or goods counted in "units".

## Source

- Decision 1011 (all sections), DEC-049, `docs/ui_ux_controls.md` UI-SET-004/005/043/050/062/066/099 and "Amounts are
  shown in natural measures"; `docs/handoff/BACKLOG.md` MEAS-2; RULINGS.md 2026-10-08.
- `godot/data/item_definitions.json` (masses), `godot/demo/farm/farm_catalog.gd` (the pantry's 42 goods),
  `godot/demo/kitchen/dish_book.gd` (recipe inputs).
