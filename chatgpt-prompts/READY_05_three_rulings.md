# Ruling request — three open contracts blocking task 03

**To:** Astra (planner / GDD + systems_architecture owner)
**From:** Claude Code (executor)
**Date:** 2026-09-09 · Branch `feat/ecology-rng` · Head `90739ef`

Task 03 (ecology, crops, weather) has 10 increments. **1, 3 and 4 are done**
— 853 tests, 26753 assertions, 0 failures, 24 mutations with no survivors.
Everything unblocked in the group is now finished. The three items below are
the whole remaining blocking set, and each is a **contract you own**, not an
implementation choice I can make.

For each I give the exact clauses, why the gap is decision-shaped rather than
guessable, the options with their measured consequences, and my recommendation.
**A one-line answer to each is enough** — the implementation follows in a day.

---

## Ruling 1 — The WEATHER stream has no roll-to-row mapping

**Blocks:** increment 2 (Weather), and transitively 6, 7, 8, 10 — six of the
ten increments, including the only one that creates a job.

### What is already fixed

`systems_architecture.md:528` (ARCH-RNG-002):

> WEATHER | One weighted event-selection roll per new season after the forced
> first spring | Season index; forced onboarding event consumes zero draws

`game_gdd.md:707` and its event table (§5.10):

> Exactly one major event occurs per season, selected by an isolated RNG
> stream … Weights are normalized within the season's eligible rows.

So the draw **count** (one), the **seeding** (season index), the **forced first
spring** (zero draws) and the **weights** are all settled.

### What is missing

**Nothing states how a `uint32` draw becomes a table row.** Four sub-decisions
are unstated, and every one of them changes which event a given seed produces:

1. **Row order.** A cumulative scan needs a canonical order. Is it §5.10's
   table order as printed (Ideal spell, Heavy rain/storm, Drought, Blight,
   Early frost, Hard freeze, Calm days), filtered to eligible rows?
2. **Range reduction.** ARCH-RNG-002 forbids rejection sampling, so this is
   `draw mod weight_sum` with disclosed bias. The eligible sums are
   **spring 85, summer 120, autumn 135, winter 110** — none is a power of two,
   so the bias is real and differs per season. Confirm that is accepted.
3. **Boundary comparison.** Strict `roll < cumulative` (first row whose running
   total exceeds the roll) or `roll <= cumulative`? With integer weights this
   shifts exactly one roll value per row boundary.
4. **"Normalized" — numeric or descriptive?** If weights are actually converted
   to percentages, the rounding rule matters and 85/135/110 do not divide
   cleanly. If it just means "eligible rows only", no arithmetic happens.

This is conspicuous because **the sibling streams do state their mappings.**
QUALITY gives `R=(draw mod 21)-10` outright; IMMIGRATION states "duplicate
second skill maps to next skill modulo 12". WEATHER states neither. I read that
as an omission rather than a deliberate silence, but it is yours to confirm.

I wrote **no** weighted picker. Inventing the scan order would be inventing a
contract, and it would be invisible: the code would look correct and produce a
different world from the one you specified.

### Recommendation

Rule all four at once as: **§5.10 table order top to bottom, filtered to
eligible; `draw mod weight_sum` with the bias disclosed in the module header;
strict `<` against the running cumulative; no numeric normalization** — scan
raw integer weights, since converting to percentages only adds rounding.

Under that rule, spring's mapping is exactly:
`0–29` Ideal spell, `30–64` Heavy rain/storm, `65–84` Calm days.

### If you defer

Increment 2 stays blocked, and with it 6, 7, 8 and 10. Increment 5's unblocked
half (fish stock/quota/recovery, deferring gear wear) is the only work left in
the group.

---

## Ruling 2 — §5.1's 4×4 deposit footprints have no schema

**Blocks:** REQ-SET-009 world generation. Not the ResourceNode store itself,
which is built and tested.

### The conflict

`game_gdd.md:243` (§5.1) specifies:

> Guaranteed stone deposit origin (44,70), footprint 4×4, quantity 1200 U;
> renewable bedrock access (48,70); iron origin (32,60), footprint 4×4,
> quantity 300 U. Ore footprints replace tree nodes.

`game_gdd.md:150` (§4.2) types the row that must hold it:

> ResourceNode | resource_id: int32, quantity_milli: int64, capacity_milli:
> int64, regrow_days: int32, planted_day: int32, exhausted: bool

**There is no footprint field, no origin, and no extent.** `WorldTileMaps` has
one `resource_slot` per tile. So a 4×4 deposit of 1200 U cannot be represented
as §5.1 describes it without a decision.

### The two readings

**Option A — sixteen nodes, one per tile.** No schema change whatsoever. The
split is exact in milli for both deposits: stone `1200/16 = 75 U`, iron
`300/16 = 18.75 U = 18750 milli`. Costs 32 of the 4096-node budget.
*Consequence:* §5.1's "quantity 1200 U" becomes a sum across sixteen rows
rather than a field value, and exhaustion becomes sixteen separate per-tile
events — a quarry visibly works out one tile at a time.

**Option B — one node spanning sixteen tiles.** The stated 1200 U sits on one
row exactly as written, and exhaustion is one event. *Consequence:* this needs
a schema change. The store keeps a reverse node→tile map that is currently 1:1;
Option B makes it one-to-many and requires either a footprint field on the §4.2
row or an origin-plus-implied-extent in the store.

### Recommendation

**Option A**, on the grounds that it needs no schema change, divides exactly in
the units the schema actually stores, and matches the already-implemented and
documented invariant "a tile holds at most one resource node". The cost is that
per-tile exhaustion becomes player-visible — which is a design question, not a
technical one, and therefore yours.

If you prefer B, the field to add is a footprint on the §4.2 `ResourceNode` row;
tell me its name and type and I will make the store change with it.

---

## Ruling 3 — Confirm or reject decision 0026 (provisional)

**Already implemented and shipped as provisional** in `90739ef`. This is a
confirm/reject, not a blocker — but it is a schema addition standing on my
judgement rather than yours, which is not where it belongs.

### A contradiction *inside* `game_gdd.md`

- **§4.2 (`game_gdd.md:149`)** gives `ForagePatch` the field `zone: EntityRef`
  with cardinality "5 patches/forest zone".
- **§5.1** says *"There is one stock basin of each habitat type; dividing a
  player zone never creates extra ecology stock"* and *"Player harvest zones
  reference basin IDs; all intersecting zones share its quotas and do not
  multiply capacity."*

Read literally and in isolation, §4.2 gives **every designated zone** its own
five patches. **A player could then double a forest's yield by drawing two
overlapping zones over it** — precisely the capacity multiplication §5.1 exists
to forbid.

### What was implemented

`ForagePatch.zone` points at the **basin** that owns the stock, not at the
player's designation. Every harvest path resolves zone → basin → patch row, so
overlapping designations debit one `stock_milli` and accumulate one
`harvested_year_milli`. Four guards make drawing twice unprofitable: a zone
bound elsewhere is refused its own patches; a basin already owning patches is
refused a rebind; chains are refused; and the effective quota is
`min(basin quota, harvesting zone quota)` — §5.1 gives the quota to the basin
and §4.2 gives each zone one, and the minimum honours both while only ever
being stricter.

**§4.2's field shape is preserved byte for byte.** The addition is a **basin
reference on `HarvestZone`** — a column that appears in neither section's field
list. That is a schema change, and schema is yours.

### The alternative, stated fairly

**Correcting my own earlier framing:** I first recorded the geometric reading as
rejected because no store owns a tile→basin mask. That overstates it. `game_gdd.md:241`
*does* define the basins geometrically — west `x=8..49,z=20..105`, east
`x=82..119,z=20..105` — so membership can be computed by a predicate with no
storage at all, and the 16384-link-budget objection applies only to the variant
that registers ~6880 tiles as zone links, not to a pure test.

The real objections to the geometric reading are narrower, and you should weigh
them rather than my first version:

1. It is not a plain rectangle test. The rectangles exclude water, so the
   predicate also has to apply `game_gdd.md:239`'s coast/river/lake terrain-mask
   priority, and each basin splits at `z=62` into north/south migration partners
   — four regions, not two.
2. It hardcodes one authored preset's geometry into the ecology store. §5.1 calls
   the shipping map "a deterministic authored estuary preset", which implies it
   is not the only possible map; a stored reference answers for any map, a
   predicate answers only for this one.

Neither objection is fatal. If you want basins derived rather than stored, say
so and it is a contained change.

### What I need

Confirm the basin reference on `HarvestZone` as a GDD schema addition, or name
the reading you intended. The third possibility is that patches genuinely are
per-designation and §5.1's rule is enforced somewhere else entirely — if so,
say where, because nothing in the current schema can enforce it.

---

## One gap I am *not* asking you to rule on yet

**`quota_milli` has no stated period.** No clause says daily, seasonal or
annual, and the only accumulator in the forage schema is
`harvested_year_milli`. Worth your attention because §5.4's `FishStock` *does*
carry `harvested_today_milli` and `ForagePatch` pointedly does not — so if a
daily forage quota was intended, **this schema has nowhere to keep the
counter.** Seven further undefined contracts are named in the module header of
`godot/scripts/core/forage.gd` rather than silently filled.
