# 1011 — Goods are counted in natural measures, and the U view is called Underground

Date: 2026-10-02 · Status: Accepted (Brendan's rulings, 2026-10-02; recorded as `DEC-049` in
`docs/setting_decisions.md`). Phase 2, the implementation, has not started.

## Rulings (Brendan, 2026-10-02, relayed by the coordinator)

- **The measures table (§1): approved** as written below. The rows marked *game catalogue* in §1a were added
  afterwards to cover the release game, and are **not yet approved** (see P9).
- **P1–P6 and P8: approved as recommended.** These are:
  - P1, Stone as a count in blocks;
  - P2, a plank is 5 kg;
  - P3, one fish per U for every species;
  - P4, onions counted;
  - P5, no weight on capacities;
  - P6, the five Wood words with no extra warning colour;
  - P8, water tooltips show litres and kg.
- **P7, changed from the recommendation: "Apply to demo and game spec".** The natural measures apply to the release
  game's UI too, not only to the demo. `docs/ui_ux_controls.md` is amended to match (its "Amounts are shown in
  natural measures" section, under DEC-049). The internal integer milli-U stays the simulation's unit in
  `docs/game_gdd.md` and `docs/gameplay_balance.md`; only the display wording changes.
- **The Underground rename (§5)**, which was Brendan's own ruling, stands.

## Context

Brendan ruled on 2026-10-02 that the demo stops showing the catalogue unit "U" to the player:

1. **Amounts in natural measures.** Each good is counted in its own measure — "40 logs", "12 sacks of barley",
   "5 bunches of herbs" — with its weight in the tooltip. The HUD's quick readouts use plain words ("plenty",
   "running low"). Heating fuel and Ready food stay in days.
2. **"The U view" becomes "Underground"** in all text. The U key stays.

This record is the design only. It changes no game code. Phase 2 implements it.

### What U is (the rules this keeps)

- GDD §4.1: an item quantity is `quantity_milli:int64`, where 1000 is one catalogue unit, abbreviated U. That stays.
  Every column, reservation, recipe, save field and test of the simulation keeps integer milli-U. **This change is
  display only.**
- GDD §5.7 weights per U, compiled as `mass_g` in `godot/data/item_definitions.json` and
  `docs/gameplay_balance.md` §3.1: all **raw food 250 g** (grain, flour, roots, beans, cabbage, berries, nuts,
  mushrooms, fruit, honey, herb, every fish, dried fish, spoiled food); **prepared meals and rations 500 g**; water
  1000 g; wood 5000 g; stone 5000 g; iron 2000 g; rope 500 g; cloth 250 g; wax 250 g; flax 250 g; compost 1000 g;
  excavated earth 1000 g (SET-MOVE-ECON-001); seed 100 g; mead 1000 g.
  - *Correction to the brief:* food is not 500 g a unit. Raw food, flour included, is 250 g. Only prepared portions
    are 500 g. So a 20 U sack of flour is 5 kg.
- **Planks have no GDD mass.** They are the demo's own stock: forestry saws 2 U of logs into 2 U of planks
  (`forest_rules.gd`). See PROPOSAL P2.
- GDD §5.2 / BAL-WORK-003 carry limits: small 12 kg, medium 16 kg, large 24 kg. The model scale is a 1.0 m mouse
  (AGENTS.md).

## Decision

### 1. The measures table

**Design rule: a measure is something one small resident can carry (12 kg or less).** For tools and work, prefer a
measure that equals a quantity the game already moves in one go: a log is a tree's twelfth (§5.1 "12 wood U"), a bucket
is one draw at the well (§5.9 "Draw water 10 U/10 WU"), and a basket of earth is the 2 U a digger or a bank job carries
(`SPOIL_PER_QUANTUM_MILLI_U`, `EARTH_PER_JOB_MILLI`).

Each good has an ordered list of measures, largest first. In the table, "½" means the measure is shown in halves
below ten ("1½ sacks"), and "from 2" means a container measure is used only from two of it upward. Below that, the
next measure takes over. Below the smallest measure, the amount shows as its weight.

**Materials and stores**

| Good (key) | GDD g/U | Measure (singular / plural) | U per measure | Weight of one | Below it |
|---|---:|---|---:|---:|---|
| Wood (`wood`) | 5000 | log / logs | 1 | 5 kg | bundle of kindling / bundles of kindling, 0.1 U = 500 g (the kitchen's 0.1 U a batch is "a bundle of kindling a batch") |
| Planks (demo stock) | 5000 *(P2)* | plank / planks | 1 | 5 kg | weight |
| Stone (`stone`) | 5000 | block / blocks (of stone) | 1 | 5 kg | weight (a rock quantum's 0.8 U is "4 kg of stone") |
| Earth (`excavated_earth`, spoil) | 1000 | basket / baskets of earth | 2 | 2 kg | weight |
| Compost (`compost`) | 1000 | basket / baskets of compost | 2 | 2 kg | spadeful / spadefuls, 0.25 U = 250 g (a sapling takes a spadeful; a cleared crop gives 2) |
| Water (`water`) | 1000 | bucket / buckets, from 2, ½ | 10 | 10 kg (10 L) | jug / jugs, 1 U = 1 L; then cup / cups, 0.25 U = 250 ml (tending a bed: "a cup of well water") |
| Cloth (`cloth`) | 250 | bolt / bolts, ½ | 8 | 2 kg | length / lengths, 0.5 U = 125 g, about an ell of linen (a treatment: "a length of cloth") |
| Rope (`rope`) | 500 | coil / coils | 1 | 500 g | length / lengths, 0.25 U = 125 g (mending: "a length of rope") |
| Iron (`iron`) | 2000 | bar / bars | 1 | 2 kg | weight |
| Flax (`flax`) — *not shown in the demo* | 250 | bundle / bundles, ½ | 4 | 1 kg | weight |
| Wax (`wax`) — *not shown in the demo* | 250 | cake / cakes, ½ | 1 | 250 g | weight |
| Mead (`mead`) — *not shown in the demo* | 1000 | cask / casks, from 2 | 20 | 20 kg (rolled, not carried) | jug / jugs, 1 U = 1 L |

**Food (all 250 g/U)**

| Good | Measure (singular / plural) | U per measure | Weight of one | Below it |
|---|---|---:|---:|---|
| Wheat, barley, oats | sack / sacks, from 2, ½ | 20 | 5 kg | scoop / scoops, 1 U = 250 g (porridge: "2 scoops of barley") |
| Flour | sack / sacks, from 2, ½ | 20 | 5 kg | scoop / scoops, 1 U |
| Pea, broad bean (dried pulses, 480 h) | sack / sacks, from 2, ½ | 20 | 5 kg | scoop / scoops, 1 U |
| Potato | sack / sacks, from 2, ½ | 20 | 5 kg | potato / potatoes, 1 U = 250 g |
| Radish, carrot, beetroot, spinach | basket / baskets, from 2, ½ | 5 | 1.25 kg | bunch / bunches, 1 U = 250 g |
| Turnip, parsnip, onion, leek, lettuce | counted: turnip(s), parsnip(s), onion(s), leek(s), lettuce(s) | 1 | 250 g | weight |
| Cabbage | counted: cabbage / cabbages | 2 | 500 g | weight |
| Celery | head / heads of celery | 2 | 500 g | weight |
| Apple, pear — *not in the demo; the catalogue item is `fruit`* | basket / baskets, from 2, ½ | 5 | 1.25 kg | counted apple(s) / pear(s), 1 U = 250 g |
| Trout, dace, salmon, perch, carp, whitefish | counted, same plural: "9 perch", "3 trout" | 1 | 250 g | weight *(P3)* |
| Dried fish | string / strings of dried fish | 1 | 250 g | weight (a rack batch: "3 strings of dried fish") |
| Honey | jar / jars, ½ | 1 | 250 g | weight (a tart: "half a jar of honey") |
| Nuts | sack / sacks, from 2, ½ | 20 | 5 kg | handful / handfuls, 0.5 U = 125 g |
| Mushrooms | basket / baskets, from 2, ½ | 5 | 1.25 kg | bowl / bowls, 1 U = 250 g |
| Berries | basket / baskets, from 2, ½ | 5 | 1.25 kg | bowl / bowls, 1 U = 250 g |
| Herbs (`herb`) | bunch / bunches | 1 | 250 g | handful / handfuls, 0.25 U = 62.5 g (a nut roast: "a handful of herbs"; a treatment: "a bunch of herbs") |
| Portions (meals, rations) | portion / portions: already whole counts, unchanged | 1 | 500 g | — |

**Kitchen categories, and mixed food.** Where an amount names a recipe category rather than one item, it uses the
category's measure:

- grain, flour and beans: sack and scoop;
- fresh fish: counted "fish";
- roots and greens: basket (5 U, from 2, ½) and bowl (1 U);
- every other category: its item's row.

**Mixed food** — the Pantry's total, spoiled food, and every food store's capacity or room — is counted in
**baskets of food** (5 U = 1.25 kg, ½), then bowls. Every capacity in the demo is a whole number of baskets:

- covered store 400 U = 80 baskets;
- cellar building 2000 U = 400;
- kitchen pantry 120 U = 24;
- kitchen garden shelf 200 U = 40;
- shelf 20 U = 4, pantry rack 30 U = 6, root bin 25 U = 5, hanging stores 10 U = 2.

**Why these sizes.**

- Fish count one fish per U. GDD §5.7's recipes already say "fish 2", "fish 4", so "2 fish (dace)" and "the rack
  takes 4 fish" read as the GDD writes them.
- A pond's stock of "about 720 perch" reads naturally.
- Grain, flour, pulses and nuts share the 5 kg sack: a mouse carries two of them.
- Every recipe input in `dish_book.gd`, and every rule quantity the demo states, is a whole number of a listed measure:
  - herb 0.25 / 0.5 / 1 U;
  - honey 0.5 U;
  - nuts 0.5 U;
  - water 0.25 U;
  - wood 0.1 U;
  - compost 0.25 / 0.5 / 2 U;
  - cloth 0.5 U;
  - rope 0.25 U.

  So no rule ever has to show a weight.

### 1a. The rest of the game catalogue (added after the ruling; awaiting approval, P9)

P7 extends the measures to the release game. Its catalogue (`gameplay_balance.md` §3.1, 61 items) has goods the
demo never shows, so they need rows too. These rows follow the approved table's rules: one small resident can carry
a measure, counted objects are counted, and anything below the smallest measure shows as its weight. **They are not
yet approved.**

| Good (key, g/U) | Measure | U each | Weight of one | Below it |
|---|---|---:|---:|---|
| `grain`, `beans` (250) | as the approved grain and pulse rows: sack, from 2, ½ | 20 | 5 kg | scoop, 1 U |
| `roots` (250) | as the approved roots category: basket, from 2, ½ | 5 | 1.25 kg | bowl, 1 U |
| `cabbage` (250) | counted cabbage(s), as approved | 2 | 500 g | weight |
| `fruit` (250) | basket, from 2, ½ | 5 | 1.25 kg | bowl, 1 U |
| `herring`, `mackerel` (250) | counted, same plural, as the other fish (P3) | 1 | 250 g | weight |
| `mussel` (250) | bowl / bowls of mussels | 1 | 250 g (about a dozen) | weight |
| `salted_fish` (250) | piece / pieces of salted fish | 1 | 250 g | weight |
| `dried_fruit` (250) | bag / bags of dried fruit | 1 | 250 g | weight |
| `ration` (500) | counted ration(s) | 1 | 500 g | — (whole outputs) |
| `meal_*` (500) | portion(s), as approved | 1 | 500 g | — |
| `brine` (1000) | as water: bucket, from 2, ½; jug; cup | 10 | 10 kg (10 L) | jug 1 U, cup 0.25 U |
| `salt` (250) | bag / bags of salt | 1 | 250 g | weight |
| `seed_grain`, `seed_roots`, `seed_beans`, `seed_cabbage`, `seed_flax` (100) | pouch / pouches of grain seed (and so on) | 4 | 400 g | handful / handfuls of seed, 0.25 U = 25 g |
| `sapling_apple`, `sapling_pear` (1000) | counted apple / pear sapling(s) | 1 | 1 kg | — |
| `spoiled_food` (250) | as mixed food: basket, from 2, ½ | 5 | 1.25 kg | bowl, 1 U |
| `candle` (125) | counted candle(s) | 1 | 125 g | — |
| `tool` (1000), `net` (1000), `trap` (3000), `ice_kit` (2000), `outfit_tier2` (500) | counted: tool(s), net(s), trap(s), ice kit(s), winter outfit(s) | 1 | their mass | — |

How the game's fixed quantities land in these rows:

- One seed separation gives a pouch of seed (§5.6: 1 U of crop gives 4 U of seed).
- A tile is sown with a handful of seed (0.25 U).
- The relief seed pouch holds 8 U, which is 2 pouches.

Three of the game's stated quantities are not a whole number of any approved measure, so `exact` prints their
weight. P9 offers smaller measures instead:

- a torch burns 0.25 U of wood every 6 hours: "1.25 kg of wood";
- a hive makes 0.25 U of wax a day: "62.5 g of wax";
- a candle takes 0.25 U of flax: "62.5 g of flax".

### 2. How an amount is worded

The amount helper takes **the good** as well as the milli-U. Today's helpers take only the milli-U, which is why they
can say nothing but "U". There are four renderings:

| Rendering | Used for | Rounding | Examples |
|---|---|---|---|
| `amount(good, milli)` | stock, harvest, yield, catch, production | **down** (never claims what is not there; decision 0222's rule kept) | "12 sacks of barley", "40 logs", "1½ sacks", "19 scoops", "150 g of barley" |
| `need(good, milli)` | a requirement, a cost, a consumption rate | **up** (never understates what is needed; BAL-NUM-001's direction) | planks for 4.7 m of deck: "5 planks" |
| `exact(good, milli)` | authored constants and player-set targets (recipes, rule text, standing-order targets) | none: picks the largest measure that divides the amount exactly; otherwise the exact weight | "2 scoops of grain", "a handful of herbs", "Keep 15 scoops of barley" |
| `have_need(good, have, need)` | a cost row with stock beside it | the need's measure for both; have down, need up; `have >= need` in milli-U reads "enough" | "Planks: 4 of 5" or "Planks: 5 — enough" |

The edge cases:

- **Zero:** "none" in a cell, or "no barley" in a sentence.
- **Something below the smallest measure:** its weight ("40 g of herbs"). It is never 0.
- **Under 1 g:** "a trace of herbs".
- **Counts:** "a" or "an" for exactly one in a sentence ("a bunch of herbs"), and the digit in a table cell
  ("1 bunch").
- **Halves:** "half a sack", "1½ sacks". From 10 measures upward, only whole measures are shown.
- **Accuracy:** `amount` is never above the true amount. From a container's "from 2" threshold upward, it is within
  20% of it, and the tooltip always has the exact weight.

**Weight for tooltips:** `weight(good, milli)`.

- It is computed as `milli * mass_g / 1000`, in integer grams.
- At 1 kg or more, it shows in kg, floored to 10 g, with trailing zeros dropped: "62.5 kg", "4.75 kg", "5 kg".
- Below 1 kg it shows in grams: "625 g".
- Water adds litres: "10 litres (10 kg)".

A tooltip reads "12 sacks of barley — 60 kg". A tooltip for a capacity does **not** add a weight; see PROPOSAL P5.

### 3. The HUD's plain-words bands

The top bar's six cells (`demo_hud_model.gd`):

| Cell | Becomes |
|---|---|
| Ready food | **unchanged**: days of meals (decision 0381). |
| Heating fuel | **unchanged**: "N days" / "No demand", with its warning under 2 days (decision 0571, UI-SET-003). |
| **Wood** | **words**, using the winter's thresholds that already exist (`demo_winter.gd`, decisions 0571/0411). No new constant. See the bands below. |
| **Stone** | **a count in blocks**, "20 blocks" *(P1)*. Stone has no use rate in the demo, so a word band would need invented thresholds. |
| Residents, Beds | unchanged counts. |

The Wood bands, checked in this order:

1. **none**: no wood.
2. **very low**: `firewood_urgent()`, meaning under 2 fuel-days or a hearth out. This is Heating fuel's own warning
   threshold (UI §7, `WARN_FUEL_HUNDREDTHS`).
3. **running low**: `firewood_wanted()`, meaning the Firewood order stands. Wood is below the twelve-day winter
   projection (REQ-SET-114, `projection_milli()`) in autumn or winter, or while heat is demanded.
4. **plenty**: wood is at or above `projection_milli()`, the full twelve winter days in store.
5. **enough**: everything else: below the projection, with no cold season and no demand yet.

With no winter bound (suites that build no village), the cell shows the count, "40 logs".

**The tooltip and the ledger keep the figures**:

- the Wood tooltip: "Wood: plenty — 40 logs (200 kg) in the village stores; winter needs 60 logs (planks: 3).
  Click for the ledger.";
- the Wood ledger line: "Wood: 40 logs · planks 3 in store";
- the Ready-food fallback with no kitchen (the Pantry's total): "6½ baskets of food";
- the Pantry headline: "6½ baskets of food in store", with the weight in its tooltip.

### 4. Implementation plan (phase 2)

**One formatting module:** `godot/scripts/ui/goods_measures.gd`, a new file.

- After P7 it serves both the settlement UI and the demo, so it lives under `scripts/ui/`. The demo already preloads
  `scripts/` code; the settlement layer must not depend on `demo/`.

- It is static and `RefCounted`, a pure function of `(good, milli)`.
- It holds the table above as `const` packed rows: noun singular, noun plural, milli per measure, the "from" count,
  the halves flag, and "of"-noun or counted.
- It provides `amount`, `need`, `exact`, `have_need`, `weight` and `tooltip`.
- Goods are keyed by the catalogue `StringName`, covering all 61 catalogue items (§1 and §1a). There are also demo
  keys for `planks`, `earth`, `food` and the kitchen categories.
- An unknown key calls `push_error` and returns "?". The suite's log gate (decision 0501) turns that into a test
  failure, so "U" can never come back as a fallback.
- The mass comes from `item_definitions.gd` (planks: P2), never retyped.

**The helpers it replaces.** Each helper is redirected to the module, given a `good` argument, and then deleted once
it has no callers:

- `farm/farm_text.gd` `units_text`: about 140 callers. It is the farm's one form (decision 0222), and
  `farm_plan_rows.units` and `farm_hud.food_text` wrap it.
- `forestry/forest_rules.gd` `units_text`: about 60 callers, with wrappers in `forage_rules`, `ferry_rules`,
  `swim_rules`, `regatta`, `regatta_menu`.
- `tunnel/tunnel_stores.gd` `units_text` and `stock_line`, with wrappers in `kitchen_text.units`, `winter_text.units`
  and `ui/action_card.gd` `amount_text`.
- `ui/action_card.gd` `need_text` and `add_cost` (the "have · need" row, which becomes `have_need`).
- Bare-number helpers: `stores/cellar_projects.gd` and `infirmary/infirmary_project.gd` `units_text`,
  `infirmary/care_text.gd` `units`.
- `fishery/fishery_text.gd` `units`.
- `farm/farm_tending.gd` `_units`.
- `burrow/room_fixtures.gd` `amounts_text`.
- The amount dispatchers' `UNIT_MILLI` branch, which gains the good: `goals/goal_book.gd` and `guide/projects.gd`
  `amount_text`, and `orders/standing_kinds.gd` `amount_text` (targets use `exact`).
- Float `%.1f U` sites: `work/spoil_work.gd:60`, `spoil/spoil_crew.gd:187`, `infirmary/care_tasks.gd:335,337`,
  `spoil/demo_spoil.gd:30`, `water/water_overlay.gd:167`. These also leave float formatting for integer formatting.
- **Literal-U strings** (about 40): `guide/field_guide.gd`, `guide/practice_stories.gd`,
  `guide/help_topics.gd:48`, `goals/village_goals.gd:86,102`, `farm/farm_tending_page.gd:16`,
  `farm/farm_crop_roles.gd:99`, `farm/farm_season.gd:347`, `forestry/forest_text.gd:127`,
  `forestry/forest_crew.gd:390,765`, `kitchen/kitchen.gd:2052,2067`, `kitchen/kitchen_text.gd:248`,
  `kitchen/kitchen_tab.gd:171`, `infirmary/care_text.gd:88,100,106,111`, `infirmary/care_desk.gd:582,608`,
  `burrow/room_text.gd:64`, `burrow/room_fixtures.gd:117`, `stores/cellar_bar.gd:16`,
  `stores/cellar_projects.gd:281`, `tunnel/dig_readout.gd:61,207`, `tunnel/tunnel_control.gd:112`,
  `waterplay/demo_waterplay.gd:108`.
  - Carry statements become weights. "a mouse carries 12 U, an otter 16, the badger 24" becomes "12 kg, 16 kg,
    24 kg": §5.2's carry is mass.
  - "NP a unit" in `field_guide.gd` becomes NP per the good's small measure.

In total, about 75 files under `godot/demo/` call a units helper, and about 280 call sites change. The HUD
(`ui/demo_hud_model.gd`) gains the Wood band through `bind_fuel`, from the winter's existing `firewood_wanted`,
`firewood_urgent` and `fuel.projection_milli`. `ui/demo_hud_counters.gd` needs a width check for "running low" at
the 104 px cell (1280×720).

**Order of work**, so the shared surface stays small. These are sequential slices, one owner each:

1. The module and its tests (new files only).
2. The HUD and the stores.
3. Farm and Pantry.
4. Kitchen and winter.
5. Woods: forestry, forage, ferry, regatta, waterplay.
6. Fishery and water.
7. Infirmary, hall, cellars, burrow, tunnel, spoil.
8. Guide, goals, orders, chronicle, practice stories.
9. The lint test switched on, `godot/demo/README.md`, and the old helpers deleted.

**Tests.**

- `godot/test/test_demo_measures.gd`, new:
  - a row for every good the demo shows, checked against `item_definitions.json`'s mass;
  - every measure is a whole number of milli-U;
  - boundaries at 0, at 1 milli, at each measure and each half, at the "from 2" threshold, at 10 measures, and
    just below each;
  - a deterministic sweep proving `amount` is never above the true amount and `need` is never below it, for every
    good;
  - `exact` round-trips every recipe input in `dish_book.gd` and every quantity listed in §1;
  - the `have_need` "enough" edge at `have == need`;
  - `weight` exact in grams.
- `godot/test/test_demo_no_u_text.gd`, new: a lint over `res://demo/**/*.gd` and its `.json` text tables. It fails
  on any string literal matching a number followed by " U", `%d U`, `%.1f U`, a bare `" U"`, or "U view", outside
  comments and docstrings. Until slice 9 it runs with a shrinking allowlist of files.
- **Existing tests keep asserting literal text**, as they do now:
  - about 40 of the roughly 67 test files that mention "U" assert a rendered string, for example
    `test_demo_hud_truth.gd` `"40.0 U"`, which becomes the Wood band or "40 logs";
  - their expected strings are rewritten by hand, never generated from the module under test, so a drift in the
    module still fails;
  - assertions on milli-U values do not change.
- **Conservation stays untouched.** `test_demo_conservation.gd` and every simulation, save and balance test pass
  without edits. A diff that touches any `*_milli` arithmetic, any `STEP`, or any `scripts/core/` file is out of
  scope for this change.

**Also check in phase 2:** the "½" glyph in the HUD body font, and the heading font (`ui/fonts/NotoSerif-SemiBold.ttf`).
If it is missing, write "1 and a half".

### 4a. The settlement UI code (phase 2, after P7)

There is player-facing "U" text in `godot/scripts/`. It changes in phase 2, through the same module; it is not
changed now.

| Where | Text now | Becomes (amended spec) |
|---|---|---|
| `godot/scripts/systems/ui_manager.gd:681` | `_hud.set_counter(&"Wood", EconomySystem.stock_units(&"wood"), "U")` → "Wood 180 U" | UI-SET-004: "Wood: 180 logs available; N reserved" |
| `godot/scripts/systems/ui_manager.gd:682` | the same for Stone → "Stone 100 U" | UI-SET-005: "Stone: 100 blocks available; N reserved" |
| `godot/scripts/ui/hud.gd:97` `set_counter(label, value, unit)` | appends a bare unit string to a comma-grouped integer | takes the good and the milli-U, and words it through the module. The "NP" counter keeps its own unit. |
| `godot/scripts/ui/ui_specimen.gd:38` `SYNTHETIC_COUNTER` | "1,234 U" (the specimen's synthetic counter) | "1,234 logs" |

Their tests assert the old text, and their expected strings are rewritten by hand:

- `godot/test/test_ui_manager.gd:60-61` (`"180 U"`, `"100 U"`) and `:194-195`;
- `godot/test/test_hud.gd:138`, `:181` (`set_counter(&"Wood", 180, "U")`).

Not player-facing, so left alone:

- `scripts/core/save_owner_fishing.gd:328`, a save refusal's diagnostic ("holds %d U");
- `assert` messages in `world_init.gd`, `resource_nodes.gd`, `fishing.gd` and `forage.gd`;
- docstrings throughout `scripts/core/`.

These are GDD-facing engineering text, and the GDD keeps U.

The UI refinement's reference renders also say "180 U" / "100 U":

- `docs/design/ui_refinement/render_targets.py:128`;
- `docs/design/ui_refinement/woodland_art_prompt.txt:10`.

They produce hashed reference visuals, so they are re-rendered under the art process, not hand-edited. That is
flagged for the UI art owner. The settlement HUD's plain-words band for Wood is not part of the ruling (see P10).

### 5. "Underground" replaces "the U view"

Brendan: rename it in all text; the U key stays. The player-facing strings, with the full list of what changes:

| File:line | Now | Becomes |
|---|---|---|
| `godot/demo/tunnel/tunnel_control.gd:132` `VIEW_ON` | "Underground view (U to return)" | "Underground (U to return to the surface)" |
| `godot/demo/tunnel/tunnel_control.gd:133` `LEVEL_SHOWN` | "Underground view: level %d of 2 -- PgUp / PgDn to switch, U to return" | "Underground: level %d of 2 -- PgUp / PgDn to switch, U to return" |
| `godot/demo/guide/help_topics.gd:80` | `["U", "Underground view"]` | `["U", "Underground"]` |
| `godot/demo/ui/demo_lens_picker.gd:53` `KEY_HINT` | "… · U switches the underground view" | "… · U switches to Underground" |
| `godot/demo/control/group_select.gd:73` `SEND_BELOW` | "In the underground view, right-click where to send them" | "Underground: right-click where to send them" |
| `godot/demo/control/demo_party_panel.gd:73` `HINT` | "… · U: underground" | "… · U: Underground" |
| `godot/demo/sound/sound_table.json:58` (`step_tunnel`'s muted-play equivalent) | "(U view)" | "(Underground)" |

Already correct, and left as they are:

- "Underground" (the lens, `demo_village.gd:1464`);
- "U: back to the surface" (`demo_village.gd:1467`);
- "Underground, level %d" (`demo_roster.gd:46`);
- "Underground · Level %d of %d …" (`tunnel_view.gd:67`);
- "Cutaway angle · Shift+U: your view back" (`camera_modes.gd:68`).

Tests read these strings through their constants (`test_demo_tunnel.gd` uses `ControlScript.VIEW_ON`), so no
expected strings change.

Beyond the player's screen:

- `godot/demo/README.md` has 14 "U view" mentions; they are renamed in the same change.
- Code comments and docstrings have 228 mentions across 57 `.gd` files. They are renamed when their file is touched
  by phase 2, and not swept separately.
- Earlier decision records are append-only and keep their wording.

## PROPOSALS — for Brendan's ruling

- **P1 — Stone in the top bar.**
  - (a) A count in blocks, "20 blocks". **Recommended:** stone has no use rate, so a word band would invent
    thresholds.
  - (b) Words against the outstanding stone needs of placed projects (hall, cellars, infirmary): "enough for
    planned work" or "short by 6 blocks".
  - (c) Words against fixed block counts. Not recommended: invented numbers.
- **P2 — The mass of a plank.** The GDD has no plank item. Sawing is 1 U of logs to 1 U of planks.
  - (a) 5 kg per plank, the same as wood. **Recommended:** sawing conserves U, and 1.5 m of 15 × 3 cm oak is about
    5 kg.
  - (b) Lighter, for offcuts lost to sawing (for example 4 kg). That would imply a mass the rules never apply.
- **P3 — Fish sizes.**
  - (a) Every species is one fish per U (250 g). **Recommended:** the GDD's recipes count "fish 2" and "fish 4",
    and all species share one mass. A 250 g salmon or carp is young, but believable.
  - (b) Per-species sizes (trout 2 U, carp 8 U, salmon 16 U). These read more true, but "2 fish" in a recipe would
    then mean less than one salmon.
- **P4 — Onions and other counted roots.**
  - (a) Counted: "12 onions". **Recommended.**
  - (b) Strings of onions (4 U = 1 kg): more Redwall, but halves of a string read badly.
- **P5 — No weight on capacities.** Decision 0612 counts a cellar building's 2000 U at 500 g a unit (1000 kg), while
  the food in it weighs 250 g a unit. A capacity tooltip in kg would show 500 kg for the GDD's 1000 kg cellar. Show
  capacity in baskets only (**recommended**), or reconcile 0612 first.
- **P6 — The Wood band's words.**
  - (a) none / very low / running low / enough / plenty. **Recommended.**
  - (b) Add Heating fuel's warning colour to Wood at "very low". This repeats the fuel cell's warning, so it is not
    recommended.
- **P7 — Scope against the settlement UI spec.** UI-SET-004/005 specify "Wood: "+available_U+" available;
  "+reserved_U+" reserved", and UI-SET-050/099 say "units". The demo already departs from 004/005 (decision 0251).
  The ruling as given was for the demo.
  - (a) Keep it demo-only, and record the ruling as a row in `docs/setting_decisions.md`.
  - (b) Also amend `docs/ui_ux_controls.md` for the release game.
  - **Ruled (b): "Apply to demo and game spec".** It is recorded as `DEC-049`. DEC-047 and DEC-048 are taken by the
    art-size rulings on other branches.
- **P8 — Liquids in tooltips.** Water shows litres and kg (**recommended**), or kg only. *Ruled as recommended.*

P1–P6 were ruled as recommended.

Two questions are still open:

- **P9 — The game-catalogue rows (§1a).** They were added after the ruling so that P7's spec amendment covers every
  good.
  - (a) Approve §1a as written. **Recommended.**
  - (b) Approve it with smaller measures for the three quantities that otherwise print a weight:
    - "a piece of wax" = 0.25 U;
    - "a handful of flax" = 0.25 U;
    - the torch's wood as "a quarter log".
- **P10 — The settlement HUD's Wood counter.**
  - (a) Use the amended UI-SET-004 as given: an available and reserved count in logs. **Recommended**, because that is
    what the ruling asked for.
  - (b) Also give it the demo's plain-words band.

  The game's fuel thresholds exist (UI §7 "fuel<2 cold-weather days" and REQ-SET-114's twelve-day projection), so (b)
  would need no new numbers. It would, though, change UI-SET-004's available/reserved readout, which the ruling did
  not ask for.

## Consequences

- Integer milli-U is unchanged everywhere: the simulation, saves, reservations, recipes, `STEP` constants and every
  balance figure. Only wording changes.
- One module owns every player-facing amount in the demo and in the settlement UI, and a lint test keeps "U" from
  coming back.
- `docs/ui_ux_controls.md` states the rule for the release game (DEC-049), so a later settlement UI change that
  prints "U" contradicts the spec.
- A good the demo begins to show needs a measures row first. Otherwise the module refuses it with an error, and the
  suite fails.
- Decision 0222's "tenths of a U, floored" form is superseded for display. Its rules are kept: amounts round down,
  and nothing present ever reads zero.

## Source

- Brendan's rulings, 2026-10-02 (via the coordinator's brief), and his ruling on this record the same day: the
  table approved, P1–P6 and P8 as recommended, and P7 "Apply to demo and game spec" (`DEC-049`).
- GDD §4.1 (U), §5.1, §5.2 (carry), §5.6, §5.7 (masses, recipes), §5.8 (fuel-days), §5.9 (well), REQ-SET-114;
  `docs/gameplay_balance.md` §3.1, BAL-NUM-001, BAL-WORK-003, BAL-SUPPLY-004;
  `docs/ui_ux_controls.md` UI-SET-002…006, 050, 099, §7.
- `godot/data/item_definitions.json`.
- Decisions 0222, 0251, 0381, 0411, 0571, 0612.
- The demo sources named above, at `origin/master` fd9b80a1.
- The decision tooling: `docs/validation/decision_numbers.py` takes any four-digit number (`^\d{4}-…\.md$`, with a
  matching `# NNNN` heading). 1011 passes it, so no tooling change is needed.
  - *Correction:* this record's first version said no tool parsed decision numbers. That checker was missed because
    it lives in `docs/validation/`.
