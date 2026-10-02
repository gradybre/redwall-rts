# 0671 — Orchards and berry bushes in the demo: real orchard rows, two groups, a hedge, a nursery and a grove
Date: 2026-10-01 · Status: Accepted; **all nine PROPOSALS approved as built by Brendan on 2026-10-01, with one change**
(the hedge's berries are the one generic `berries` item; see "The rulings")

**Numbering.** Other agents write decisions in parallel; this work was given the block 0671–0679 and takes 0671–0677
(checked free on this branch and in the sibling worktrees). 0672–0677 record its parts; this record is the whole
and holds every proposal.

Brendan approved feature **#20, orchards and berry bushes**, on 2026-10-01 ("Perennial crops that take years to mature,
with fruit seasons"), and the external review's **group Y** on 2026-09-30 (decision 0493's log). Group Y's orchard items
are built here: **ECO-008** (an inherited old orchard and an early yield; decision 0672, which is also the "M3 orchard
timing change" group Y asked to be recorded), **ECO-009** (nursery plans; 0673), **ECO-010** (harvest groups; 0674) and
**ECO-015** (protected groves; 0675). Hives, honey and wax (ECO-011, ECO-012) and gathering outings (ECO-014) are other
lanes and are not built. Presentation only throughout: nothing here is the settlement's simulation.

## The rulings (Brendan, 2026-10-01)

Brendan approved proposals 1–9 below **as built**, with one change:

- **The hedge yields the generic `berries` item**, the same pantry item (key `berries`) the foraging lane defines under
  his ruling on foraging's general items -- not three items of its own. Raspberries, blackberries and strawberries
  are all `berries` in the pantry; the three bushes stay three bushes (decision 0676). `apple` and `pear` stay their
  own items. On this branch `berries` is **item 26** (apple 24, pear 25; `PANTRY_ITEM_COUNT` 27) and **CAT_BERRIES 11**
  -- the foraging branch's own category number for it -- with **CAT_FRUIT 12**. The foraging branch has `berries` at
  item 27 (after nuts 24, mushrooms 25, herb 26): the key and the category agree, and the integration renumbers the
  items (the orchard reads them through `ORCHARD_ITEMS`, a list, so it follows wherever `berries` lands).
- **Proposal 2** means the GDD's §5.6 sentence and §5.10's M3 row are to be reworded to match: decision 0672 carries
  the drafted text for the docs owner. The GDD itself is not edited here.
- **Proposal 9** is built on this branch: the kitchen's raw table (`meal_rules.gd RAW_NP_PER_U`) has §5.7's fruit
  (900 NP a unit) and berries (700) rows, so a hungry resident with no portion eats them raw. A raw meal never takes
  a lot waiting at a basket stand (`kitchen.gd _raw_candidate`), as the kitchen's recipes never do (decision 0674).

### The rules used, as written

- **GDD §5.6's orchard rows**, through `scripts/core/orchard_hive.gd` (called, never retyped): one modelled fruit tree a
  4x4-tile block; apple 96 days to maturity and 80 fruit U a year in Autumn 1–6, pear 144 days and 110 U in Autumn 3–8;
  planting costs the sapling and compost 4 U; care 20 WU a day in spring and summer, water 2 U a day during drought;
  untended spring/summer days remove 100 health, tended ones restore 50; fewer than 6 winter chill days give 75%;
  REQ-SET-079/080 (the next legal harvest, once a year), REQ-SET-081 (the first eligible harvest shown before a
  planting); nursery propagation fruit 4 + compost 2 + water 2, 120 WU and 12 days.
- **gameplay_balance.md BAL-CAT-010**: planting a block 40 WU, harvesting a mature block 80 WU, a haul payload 2 WU to
  load and 2 to unload, a new tree's health 10000.
- **GDD §5.5's Berries forage row** for the hedge (decision 0676), **§5.7's `fruit` and `berries` rows** for the pantry
  items, **§5.8's covered-store factor** for the basket stands, **§5.2's** work rate (80 milli-WU a tick at the base).
- **Decision 0222's conservation**: room first, a load in hand is a delivery, nothing credited from afar.

### What is built (`godot/demo/orchard/`)

- **The trees are real OrchardPlot rows** (`orchard_model.gd` over `orchard_hive.gd`); each midnight closes the day
  just ended at the one weather's temperature (`apply_orchard_day`).
- **Four sites**, tile-aligned 8 m blocks: the **old orchard** south of the field beds (an old apple and an old pear)
  and the **east orchard**'s two empty planting sites by the south road. Pegs mark an empty block; a planting there is
  the player's (the panel or a right click) or a nursery plan's.
- **The pantry items** (`farm_catalog.gd`): `apple` and `pear` (§5.7 `fruit`, 144 h, CAT_FRUIT), the content library's
  own LEAF keys, and the generic `berries` (§5.7 `berries`, 48 h, CAT_BERRIES; the compiled catalogue's
  `data/item_definitions.json` row, the foraging lane's key) for everything the hedge gives (the ruling above).
- **The work** (`orchard_jobs.gd`, `orchard_task.gd`): tend, harvest, pick, haul, plant, propagate and observe, each a
  short program of walk-work-carry steps worked by real residents. **On the work board as source 11**
  (`work_ids.gd SOURCE_ORCHARD`, `work/orchard_work.gd`): sources 8 and 9 are taken on other lanes' branches (the ferry,
  the stores and the hall at 8; foraging at 9), so 11 leaves room; 8–10 stay unused here (the board skips a null
  source) and the merge fills them. Field work is the Field crew's activity, hauls the Haulers'.
- **The panel** (`orchard_panel.gd`, `orchard_cards.gd`): the right column's fifth panel, **with no tab** -- the strip's
  four tabs and its "×" are all the 336 px zone holds at 1280x720 -- brought by clicking a tree, a site, a bush, the
  baskets, the nursery or the grove's stone (`demo_detail_zone.gd PANEL_ORCHARD`). Every verb's tooltip is its action
  card (decision 0332), filled from the order's own check. No new key.
- **The drawing** (`orchard_view.gd`): **no new art**. A fruit tree is the staged oak drawn at about a third of a woods
  oak (the oak sapling model for its first half-year); the canes and the bramble are the oak's crown drawn knee-high and
  let into the ground; the strawberry bed is the staged strawberry plant; baskets, sapling baskets and a mossy boulder
  are staged props. Blossom and fruit are the tree shader's speckles (decision 0677).

### PROPOSALS (demo values no document states; all approved as built by Brendan on 2026-10-01)

1. **The early yield's numbers** (decision 0672): 20% (the middle of ECO-008's 15–25%), from a tree's first full year
   (48 days), once a year in its window, until §5.6's maturity. An early picking's work is the same share of 80 WU
   (16 WU). *Recommendation: confirm.* Options: 15% (more patience), 25% (more reward).
2. **The restoration start** (0672): the old apple 10 years and the pear 13, health 35%, last winter cold enough; the
   M3 grant (2 apple + 2 pear saplings) held in the nursery from the start. *Recommendation: confirm; the GDD's M3 row
   and §5.6's sentence to be reworded by 0672's text once confirmed.*
3. **Where they stand**: the old orchard on (-20..-4, 26..34), the east sites on (6..14, 22..38), the hedge east of
   them, the nursery by the south road, the North hollow in the North stand. *Recommendation: confirm; the forage lane's
   herb bank at (-12, 23.6) is 2.4 m north of the old orchard and untouched.*
4. **The basket stands** (0674): 120 U each, §5.8's covered-store factor, a haul 10 U a trip, the old orchard keeping
   4 U of each fruit for the nursery by default. *Recommendation: confirm.*
5. **The hedge** (0676): three bushes sharing ONE §5.5 Berries patch (300 U), a picking 5 U, no new bushes planted.
   *Recommendation: confirm; a planted soft-fruit row (strawberry, currants) needs a §5.6-style row of its own -- ask.*
6. **Inputs taken when the work is done, not when it starts** (planting, propagation, drought tending): a cancelled
   job owes nothing back. §5.7 production takes its inputs at the start (REQ-SET-094's half-spoiled refund on a
   cancel). *Recommendation: keep for the demo; the settlement's job model does it the GDD's way.*
7. **The grove** (0675): one protected grove, its trees never felled while protected, observed once a season with an
   insect sighting; no yield buff. *Recommendation: confirm; more groves by marking a woods tree later.*
8. **The tree's drawn size** (0677): a fruit tree about 4.7 m tall (0.36 of the 13 m woods oak), old trees 5.2 m.
   *Recommendation: confirm, or ask for a fruit-tree model (see the art gap).*
9. **Raw fruit is not yet an emergency meal**: the kitchen's raw-food table (`meal_rules.gd RAW_NP_PER_U`) has no
   fruit or berry row, so a hungry resident does not eat them raw though §5.7 says they may be. *Recommendation: the
   kitchen lane adds §5.7's 900 and 700 NP rows.* **Approved; built here** (the rulings above).

### Not built, and why

- **Relocating a young sapling** (ECO-009, "a new mechanic", its own ruling): not built.
- **Carts** (ECO-010's "optional harvest carts"): baskets only; the staged handcart is not wired.
- **"Fresh table / preserve / seedling" shares as percentages** (ECO-010): built as a destination choice and a nursery
  share in units; the preserving lane decides what preserving takes.
- **Hives and pollination**: `orchard_hive.gd`'s links are left empty, so every tree's pollination factor is 1000.
- **Canopy clearance**: the camera does not thin a fruit tree's crown (they are not the woods' stand rows); at 4.7 m
  they rarely stand in its way.
- **Saving**: the orchard is presentation state, like every demo system; nothing is saved.

### The art gap (reported)

No fruit tree, berry bush or loose fruit is staged. The stand-ins above read as an orchard at the RTS camera; a proper
apple/pear tree (with a blossom and fruit texture), a bramble and a raspberry-cane model, and a basket of apples would
replace them without code changes (the view takes models by key). That art is being made separately (2026-10-01); nothing
here changes the visuals.

## Consequences

- Other lanes name the fruit and berries by key (`apple`, `pear`, `berries`); the dishes lane's cordial takes its
  raspberries as `berries` (from the hedge or a foraging trip), so it deletes `raspberry` from its PENDING_SOURCES
  (its honey still waits for the hives).
- CAT_BERRIES 11 is the foraging lane's number for the same item, so the two branches' `berries` reconcile as one
  item and one category; CAT_FRUIT 12 sits past every other lane's categories (8–11). The item indices (apple 24,
  pear 25, berries 26 here; berries 27 on the foraging branch) are renumbered by whichever lane merges second.
- The pantry has two new hooks for any gathering place (0674): a store marked `staging` is never chosen as a
  destination, `reserve_at_into` holds room at a named store, `move_upto_into` moves food keeping its age.
- The kitchen never reserves a lot at a gathering place (`ingredient_takes.gd _staged`): food waiting at a stand is not
  yet stored, and neither does a raw meal (`kitchen.gd _raw_candidate`). The dishes lane, whose cordial takes
  berries, inherits this when it merges.
- The independent review (code-reviewer) found three HIGH issues, all fixed before commit: a haul cached its store's
  index (stale once a cellar is dug) -- it now reads the store from its held room; the kitchen's reservations could land
  on a stand's lots -- they no longer can, and the nursery takes its fruit from the stands only; the tests could not see
  a leaked reservation row -- they now check the rows themselves.

## Source

Feature #20 (Brendan, 2026-10-01); review group Y (decision 0493; REVIEW.md ECO-008 2380, ECO-009 2404, ECO-010 2426,
ECO-015 2561); GDD §5.5–5.8, §5.10, REQ-SET-079–081; gameplay_balance.md BAL-CAT-010; decision 0222.
