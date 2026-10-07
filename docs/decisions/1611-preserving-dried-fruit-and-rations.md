# 1611 — Preserving in the demo: dried fruit on the rack, rations at a preserving table
Date: 2026-10-07 · Status: Accepted (engineering); **PROPOSALS P1–P7 wait on Brendan**

**Numbering.** BACKLOG.md's PRESERVE packet assigns 1241–1250; that range collides with a parallel digging branch
(0991–1217 and growing), so the lead remapped the food packets to 1601–1629 and PRESERVE takes **1611–1619** (1611
here). Checked free on every local and remote ref; `docs/validation/decision_numbers.py` passes.

## Approval

Feature #18, preserving (Brendan, 2026-10-01; tracker only, first recorded in `docs/handoff/RULINGS.md`), and group W's
ECO-028 preservation trade-offs (decision 0493). Art pass 3's preserving props and icons were approved 2026-10-02
(decision 0971). The scope is derived from GDD §5.7; what goes past it is a PROPOSAL.

## Decision

The demo makes **§5.7's two preserving rows it can**: `dry_fruit` on the existing smoking rack (which decision 0434 made
§5.9's Dryer) and `ration` at a new **preserving table** beside the kitchen. Both run through the fishery's station-job
machinery -- the rack's and the mill's -- now generalised to **recipe rows** (`demo/preserve/preserve_rules.gd`): each
row names its §5.7 inputs by category, its water, output, work, passive wait and station. The rack's slots carry a
recipe (`s_recipe`), so fish and fruit share the Dryer's four slots; a batch without a passive wait (rations) is a new
job kind, `KIND_BATCH`, with the mill's fetch → work → carry program. Two pantry items are **appended**: `dried_fruit`
(item 32, `CAT_DRIED_FRUIT` 14) and `ration` (item 33, `CAT_RATION` 15).

### The rules used, as written

- **GDD §5.7** `dry_fruit`: fruit 4 → dried_fruit 3 × 1400 NP, 20 WU + 12 h passive, Dryer/PRESERVE, 720 h;
  `ration`: flour 2, dried_fish 1, nuts 1, water 1 → ration 3 × 2400 NP, 24 WU, Kitchen/PRESERVE, 1440 h; "dried fruit is
  directly edible ... rations are directly edible".
- **§5.9 Dryer**: four passive batch slots (shared by its rows). `dry_fish` is unchanged (decision 0434), now row 0.
- **REQ-SET-093/094/112/118** as decision 0434 applies them: inputs set aside at the order, withdrawn when the work
  starts (all or nothing), room held for the output, the worker free during the passive wait, half the food spoiled on
  a cancel after the start.
- **§5.8 storage ageing**: the pantry's existing store factors (pile 1500, covered 1000, pantry 750, cellar 350; decision
  0611) apply to the new items unchanged.
- **REQ-SET-013** with §5.7's "directly edible": `meal_rules.gd RAW_NP_PER_U` gains dried fruit 1400 and rations 2400,
  so a hungry resident with no portion eats them -- after anything that spoils sooner (ECO-028: fresh food keeps its
  role; the kitchen cooks fresh food first).
- **Decision 0903 ruling 9**: icons by key -- `item_dried_fruit` is picked up by its key; rations have no icon (swatch).

### Shared files touched

| File | Hook |
|---|---|
| `godot/demo/farm/farm_catalog.gd` | items 32–33 and categories 14–15 **appended**; `PANTRY_ITEM_COUNT` 34 |
| `godot/demo/kitchen/meal_rules.gd` | two `CATEGORY_WORDS`, two `RAW_NP_PER_U` rows |
| `godot/demo/fishery/fishery.gd`, `fishery_tables.gd`, `demo_fishery.gd`, `fishery_view.gd` | recipe rows for the station jobs; `KIND_BATCH`; `order_batch` / `batch_refusal`; the cards; the table's props |
| `godot/demo/work/fishery_work.gd` | the Work screen's words come from `fishery.job_words` |
| `godot/demo/waterplay/water_panel.gd` | a **Preserves** heading, line and row (Dry fruit, Pack rations) |
| `godot/demo/props/demo_props.gd` | `jar_shelf` 0.95 m and `crock_stoneware` 0.5 m (DEC-048) |
| `godot/demo/demo_village.gd` | one line: the table's props among the cast's obstacles |
| `godot/demo/guide/field_guide.gd` | the preserves' entries |
| `tools/make_demo_pantry_index.py`, `godot/demo/farm/pantry_index.json` | the two keys; dried fruit is the library's `COMPONENT_shared_dried_apple`; rations have no library leaf |

No work-board source and no key is added; nothing is renumbered. Nothing under `scripts/core/`, `demo/burrow/`,
`demo/tunnel/`, `demo/cast/` or the settlement UI is edited.

## PROPOSALS (for Brendan)

1. **Dried fruit shares the rack's slots** (the packet's pitfall). §5.9's Dryer has four slots for whatever it dries,
   and decision 0434 made the rack the Dryer. *Options:* (a) as built; (b) a separate fruit dryer (wood 16 + rope 4,
   which waits on Q-D3). *Recommendation: (a).*
2. **The preserving table** stands from the start west of the kitchen (Q-D4 (a)); §5.7's Kitchen/PRESERVE row needs no
   new building. *Recommendation: confirm.*
3. **Ordered by the player** from the Water panel's Preserves, as the rack and the mill are; no routine packs rations on
   its own (the GDD's WorldPolicy `ration_reserve_milli` defaults to 0). *Options:* (a) as built; (b) a reserve target
   the cook keeps topped up. *Recommendation: (a) now, (b) with the winter-planning work.*
4. **Rations are eaten as a reserve**, not served as a meal: the kitchen's meals stay fresh dishes; a hungry resident
   with no portion eats rations (or dried fruit) under REQ-SET-013. *Recommendation: confirm.*
5. **A ration weighs 500 g in the GDD** but the demo's stores count units, not mass (as every pantry item; Q-D6 asks the
   same of the Cellar building). *Recommendation: leave it with Q-D6.*
6. **Simplifications, named**: a batch's fetch walks to the store of its first input only (rations: the flour's); the
   other inputs are withdrawn from wherever their lots are, as the books never move with a carry. Water is checked when a
   batch is ordered but not reserved (as the kitchen's): two orders against the last unit of water both go through and
   the second is given up when its work would start. *Recommendation: confirm.*
7. **Not built**: `salt_fish` (no coast, so no salt); jam, pickles and a plant-milk cheese have no GDD row -- they wait on
   Q-D5, with honey jam possible now that the apiary makes honey (decision 1601). *Recommendation: Q-D5 (a) now, (b) and
   (c) asked together.*

## Gates

Filled in by the branch's gate record at the end of the lane.

## Source

GDD §5.7 (`dry_fruit`, `ration`, the item table), §5.8, §5.9 (Dryer); REQ-SET-013/093/094/112/118; review ECO-028
(decision 0493); decisions 0434, 0611, 0612, 0903, 0971; `docs/handoff/BACKLOG.md` PRESERVE; open questions Q-D3–Q-D6.
