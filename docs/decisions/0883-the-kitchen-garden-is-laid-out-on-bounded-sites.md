# 0883 — The kitchen garden: bounded sites the player lays out, one plan, a shelf, the well, and the cook
Date: 2026-10-01 · Status: Accepted

Brendan approved the review's **ECO-004** ("Player-designed kitchen gardens", REVIEW.md 2250) and, on 2026-10-01,
feature **#48** ("kitchen garden plots: small herb and salad beds by the kitchen, tended by the cook between meals").
ECO-004: "Offer small bed modules ... and mixed garden groups that share a plan. Let paths, a work shelf and one water
point form a functional group; show walking cost rather than imposing a rectangular 'perfect farm' bonus ...
Recommend bounded modules plus grouping before arbitrary polygon simulation." Its minimum prototype: "three
player-placed beds around a path". Numbering: see 0881.

## Decision

### Four bounded sites

`farm_catalog.gd` adds **four kitchen-garden sites** after the field beds (GARDEN_FIRST, GARDEN_AT; with decision 0886's
south field the field has twelve beds and the garden's are Bed 13–16) on open ground across the east road from the kitchen, between the square and the covered
store, round a cross of garden paths: (5.4, 5.4), (8.0, 5.4), (5.4, 8.0), (8.0, 8.0). A garden bed is **one GDD §5.6
tile, 2 m × 2 m** ("Fields use 2 m×2 m tiles"), drawn at that size (the field beds are the same one plot drawn 3 m:
`bed_half_m`). The sites are checked clear of every layout obstacle and field bed (`test_demo_garden.gd`); garden beds
are not walking obstacles (residents may cross them).

Each site is a real FarmPlot from the start, so its soil has a history, but it grows nothing until it is **laid out**
(`farm_sim.gd` THE KITCHEN GARDEN): sowing is refused NOT_LAID_OUT and so is every job (`farm_jobs.gd refusal_for`), and
its stage is STAGE_SITE -- not an empty bed -- so nothing that looks for an empty bed to plant (the Pantry's suggestion,
the guide) points at it.
**Laying out is a designation** -- at once and free, as GDD §5.6 field designation is; the work is the sowing. Taking
a bed up is refused while anything stands in it, and keeps the soil's fertility, last family and compost season
(BAL-SAFE-014). A bare site is drawn as four pegs and a string, labelled "Garden site · click to lay out a bed"; its
panel says what it is, what its place costs in walking, and offers "Lay out a bed here" (`farm_garden_box.gd`). The
planner overview, Compare, the soil plans' bed buttons, the "worn out" alert and the accessible target list leave bare
sites out.

### One group, one plan

The laid garden beds are one group (GDD §5.6: "field grouping is a UI/work aggregation") with one **plan**: the
garden's crop, stepped ◀ ▶ through what its loam takes, and **Sow every empty garden bed** -- one order
(`farm_garden.gd sow_all`). The tending policies (0885) hold per group too. The planner's **Kitchen garden** tab
(`farm_garden_page.gd`) lists the sites, the walking, the plan and the cook's hours.

### Service points, each an adopted rule

- **Paths**: a cross of dirt paths between the sites (§5.9's dirt path), drawn once the garden has a bed
  (`farm_garden_view.gd`); their +10% speed is not modelled.
- **Work shelf**: §5.9's Shelf furniture ("50000g pantry capacity") at the north end of the middle path, as a pantry
  store through the storage-provider API -- 200 U (50000 g at §5.7's 250 g a raw unit) at §5.8's pantry factor 750 --
  drawn as the store shelf prop and stocked as it fills (`farm_stock_view.gd add_shelf`). It goes up with the first bed
  and stays (food on it is never moved by a garden being taken up). It is an ordinary store: a harvest goes to the
  slowest-spoiling store with room, the nearest on a tie (`farm_pantry.gd`), so the garden's harvests go to it.
- **Water point**: the village well, the GDD's water building.
- **Walking cost** is shown, never a bonus: each bed's distance to the shelf and the well, and a round of the garden.

### The cook tends it between meals (#48)

From the end of breakfast's serving to the hour supper is cooked from (`meal_rules.gd` END_HOUR and COOK_FROM_HOUR:
09:00–15:00), a waiting job on a garden bed is **kept for the village cook** (the kitchen's `designated`) while the
cook could take it -- already on garden work, or free by **the work board's own test** (`work_board.gd idle`, and farm
work not forbidden to its crew; `demo_work.gd farm_claimable`) -- and for **at most one game hour**, after which it is
anyone's (`farm_garden.gd is_kept`, which allocates nothing: the board asks it per candidate). The routine crew passes
it by (`farm_crew.gd kept_from`) and the work board's farm source refuses others with the reason
(`demo/work/farm_work.gd eligibility`). Outside those hours, with the cook busy elsewhere, asleep or indoors, after the
hour, or with "The cook tends the garden" off, anyone may take it. A refused garden sowing (a full board) puts each
bed's own choice back. The salad beds are the farm's own ingredients (lettuce, spinach, radish
...).

## Why

Free placement needs general placement and field designation, which the demo does not have; the review itself ranks
bounded modules first. Four sites in a 2 × 2 give the player real choices -- a row along the path, a courtyard square,
beds near the well or near the shelf -- whose only difference is the walking, said in metres.

## Known gaps

- A room may be dug under a garden site nobody has laid out (a bare site grows nothing: `tunnel_control.gd bed_laid`);
  laying a bed out there afterwards is not refused, so a bed can stand over a room. Refusing lay-out over a room needs
  the rooms' footprint test from the tunnel lane.
- The shelf is free and permanent, and at the pantry's factor (750) it is preferred over the covered store (1000) for
  any harvest when it has room (proposals 3 and 4).

## Proposals for Brendan

1. **Free placement** on a tile grid instead of four authored sites. **Recommendation:** after the general building
   lifecycle (UX-013) and field designation exist.
2. **Laying out costs nothing.** Options: §5.9's dirt path cost (2 WU a tile) or a 6 WU digging job. **Recommendation:**
   keep free (fields are designations in the GDD).
3. **The shelf is free** (§5.9: wood 2, 16 WU). **Recommendation:** charge it when the construction lifecycle exists.
4. **Field harvests may use the garden shelf** when it is nearer than the kitchen pantry at the same factor. Restricting
   it would need an item or bed filter in the storage-provider API (the cellar lane's file). **Recommendation:** keep.
5. **Herb beds** are not offered: herbs are forage (§5.5) with no §5.6 row. Options: (a) none (built); (b) a garden
   herb patch run by §5.5's herb row (capacity, 80‰ daily regrowth, season multipliers) with a small demo capacity;
   (c) a new §5.6 herb row. **Recommendation:** (b) if herbs are wanted now; it needs a pantry `herb` item (the pantry
   lane).
6. **The cook's garden hours** (09:00–15:00) and "kept only while the cook is free" are demo choices.
   **Recommendation:** keep.
