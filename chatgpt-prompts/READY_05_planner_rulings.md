# Ruling request — task 03 open contracts

**Status 2026-09-09, revision 2.** Rulings 1, 2 and 3 have been **answered**
and are implemented — the handoff is stored at
`docs/rulings/2026-09-09_task03_planner_rulings.md` and folded into §5.10, §5.1,
§4.2 and ARCH-RNG-002. Decisions 0028, 0029, 0030 record them; 0026 is now
Accepted with the five ownership constraints.

**Still open: rulings 4, 5 and 6 below. Ruling 4 the handoff did not answer** (it responded to
the three-ruling version at head `90739ef`, written before the fishing module
existed), **and ruling 5, which the weather implementation newly surfaced.**

**To:** Astra (planner / GDD + systems_architecture owner)
**From:** Claude Code (executor)
**Date:** 2026-09-09 · Branch `feat/ecology-rng` · Head `90739ef`

Task 03 (ecology, crops, weather) has 10 increments. **1, 3, 4 and the stock
half of 5 are done** — 926 tests, 27550 assertions, 0 failures. Everything
unblocked in the group is now finished. The four items below are the whole
remaining set, and each is a **contract you own**, not an implementation choice
I can make.

Rulings 1 and 2 **block work**. Rulings 3 and 4 cover schema that is already
implemented and shipped as provisional, standing on my judgement rather than
yours — which is not where it belongs.

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

## Ruling 4 — Fishing needs two state columns §4.2 does not provide

**Already implemented and shipped as provisional** (decision 0027). Same class
as ruling 3, but simpler: these are not contradictions. Nothing in the GDD
*denies* these columns. They are absent, and the requirement text is
unimplementable without them.

### Column 1 — effort-slot occupancy

§5.4 states the capacities ("Habitat effort capacity: river 4, lake 6, coast 6")
and REQ-SET-044 says a starting cycle "shall reserve its effort slots". §4.2's
`FishHabitat` row carries only `effort_slots` — **a capacity, with nowhere to
record how many are taken.** REQ-SET-050 then requires occupied slots to queue
further fishers "rather than multiply yield with unbounded workers", which
cannot be enforced without the count.

An occupancy counter is added, and **it is state a save must carry.**
REQ-SET-050's *queue* is deliberately not added here — `JobState` already has
`QUEUED=0` and §4.2 sizes the Job store at 8192 rows, so the queue lives there.

### Column 2 — REQ-SET-048's hysteresis bit

> When fishing stock falls below 30% capacity, the system shall warn of
> depletion and default to restocking until stock recovers above 40%.

Two thresholds, 30 down and 40 up. **Between them the required behaviour depends
on which was crossed last, and population alone cannot answer that.** A
`restocking` bit is added to `FishStock`; §4.2 gives that row only `closed`.

I did not collapse this to one threshold. A single-threshold reading needs no
column at all — which is exactly why "it would be simpler" is not a reason to
choose it.

### The interpretation this forces — and where I may have it wrong

Below 30% the minimum-stock floor already refuses every harvest, so the
restocking flag **can only bite in the 30–40% band.** I read it there as blocking
harvest unless the visible intensive-harvest policy is on. "Default to" implies
something overridable, and that policy is the only override §5.4 offers.

**The alternative is warning-only**, and it is three lines away. If REQ-SET-048
was meant to warn rather than block, say so and column 2 disappears entirely.

### Also worth your attention

- **There is no `HabitatType` enum.** §4.2 types `FishHabitat.type` as `enum`;
  §4.3 does not list one; and the ordinal is genuinely ambiguous, since §5.1
  orders the terrain masks "coast, river, lake" while §5.4's table orders them
  "River, Lake, Coast". Held as module-local constants and deliberately **not**
  added to the protected catalog table, because protecting a guess would give it
  the standing of a specified value. **`type` is persisted, so renumbering it
  later breaks saves** — this one is worth answering early.
- **`pollution` has no stated effect** anywhere in the GDD, and **§5.4 gives the
  25% refuge no mechanical effect** either. Both columns are stored and
  range-validated, and tests assert that neither currently changes recovery,
  catch, or allowed stock. If they are meant to do something, they do not yet.
- **Carp's window is not labelled a spawning closure** while trout's and salmon's
  are, leaving REQ-SET-047's override prohibition ambiguous in scope. Treated as
  a closure, which is strictly the safer reading — it can only hold the floor at
  30%, never lower it.

---

## Ruling 5 — `WeatherEvent` has no enum, and two orderings contradict each other

**New, found while implementing the now-unblocked weather module.** This is the
same class as fishing's `HabitatType`, but **sharper, and it affects saves.**

§4.2's `Weather` row types `event: enum`. §4.3 lists no `WeatherEvent` — the
enum table runs Season through Severity with nothing weather-related.

The sharper part: **§4.3 *does* list an `EventDefinition` catalog** with
`id: StringName`, and `catalog.gd` compiles every catalog domain's keys in
**ascending ASCII order** (that is its stated, tested contract — it exists so ids
are independent of insertion order). Compiling the seven weather events that way
would number them:

| ASCII order | Value | §5.10 table order | Value |
|---|---:|---|---:|
| blight | 0 | ideal_spell | 0 |
| calm_days | 1 | heavy_rain | 1 |
| drought | 2 | drought | 2 |
| early_frost | 3 | blight | 3 |
| hard_freeze | 4 | early_frost | 4 |
| heavy_rain | 5 | hard_freeze | 5 |
| ideal_spell | 6 | calm_days | 6 |

**The two orders agree on `drought` alone.** They cannot both be right, and
`event` is persisted in the `Weather` row, so choosing wrong later renumbers a
saved field.

The implementation uses §5.10's printed order as module-local constants and
deliberately does **not** add them to `PROTECTED_ENUM_DOMAINS`, for the reason
given under ruling 4 — protecting a guess lends it the standing of a specified
value.

**What I need:** either add `WeatherEvent` to §4.3 with explicit values, or say
the events are an `EventDefinition` catalog and therefore ASCII-numbered. Please
also confirm whether `HabitatType` should be handled the same way, since the two
questions now have the same shape.

### Two related gaps, recorded but not blocking
- **`EventDefinition.modifiers` is "a fixed int32 vector" with no stated width or
  field order.** No modifier vector is emitted; each stated quantity has its own
  named constant instead.
- **The `Weather` row has no column naming the season its `start_day` belongs
  to.** The caller supplies it, so the eligibility guard is only partial, and
  §5.10's "exactly one major event per season" **cannot be enforced inside the
  module** — ARCH-SYS-006 will own it. A test asserts that limit explicitly
  rather than hiding it.

### One interpretation worth a second opinion
§5.10 writes "Temperature−3°C from baseline" for heavy rain but bare
"Temperature−3°C" for early frost and "−12°C" for hard freeze. **"From baseline"
appears exactly once**, so the bare forms are implemented as absolute. There is
mechanical corroboration: BAL-CROP-001 makes `frost_tolerance` damage accrue per
subzero hour, and the relative reading would put early frost at autumn 10 − 3 =
**+7°C**, leaving "frost effects" with no mechanism at all. Confirm if you agree.

---

## Ruling 6 — Farming's five open contracts, and one ARCH-STATE-003 shortfall

From increment 6 (`farming.gd`), now implemented. **1161 tests, 34543
assertions, 0 failures.** §5.6 is unusually complete on arithmetic and unusually
silent on state transitions — every number transcribed cleanly; these five did
not.

**Three govern persisted columns**, so a later change breaks saves rather than
just behaviour.

1. **`SOWN` vs `GROWING`.** §4.3 numbers both; §5.6 never says what separates
   them. Read as SOWN = seed committed with the 4 WU outstanding, GROWING =
   REQ-SET-072 integrating. `state` is persisted.
2. **`family_streak` counts harvests, not sowings** — from "a second consecutive
   same-family *harvest*", so a withered crop does not advance it.
3. **What `FarmPlot.compost_milli` holds.** `TileHistory.compost_season` is
   already the once-per-season gate, leaving the §4.2 column without an obvious
   job. Used as a quantity ledger (0, then 2000).
4. **Do the 48-hour grace and the 5-day withering share one instant?** They do in
   the implementation. The alternative starts the five days *after* the grace
   expires. **The two differ by two whole days of yield decay** — the largest
   balance consequence of anything in this list.
5. **No crop-family enum exists.** `last_family` is persisted, and `FAMILY_*` are
   module-local ordinals in §5.6's printed order. **This is the third instance of
   the same gap**, after `HabitatType` and `WeatherEvent` — worth one general
   ruling rather than three.

### The shortfall is the architecture's, not the implementation's
ARCH-STATE-003 is otherwise satisfied and tested verbatim: a redraw does not
restore fertility and does not reset compost eligibility.

But **`family_streak` has no `TileHistory` column.** §4.2 puts the streak *length*
on the `FarmPlot` row; §2's `TileHistory` carries only `last_family`. A redraw
restores the family but not the count.

The direction of the error was checked and is the safe one: a restored family
with a zero count reads as a **second** consecutive harvest (850), never a first
(1000), so **a redraw can never fabricate a rotation bonus** — BAL-SAFE-014's
actual concern. It can still *lose* a penalty, turning a third-or-later 700 into
850. Closing it needs a seventh I32 column, **+65536 bytes** over the budgeted
393216. Your call whether that is worth spending.

---

## One gap I am *not* asking you to rule on yet

**`quota_milli` has no stated period.** No clause says daily, seasonal or
annual, and the only accumulator in the forage schema is
`harvested_year_milli`.

Increment 5 has now made this concrete rather than theoretical. §5.4 states its
quota is daily **and** §4.2 supplies `harvested_today_milli` — the same mechanism,
fully specified. `HarvestZone.quota_milli` has neither, and `ForagePatch` has no
daily accumulator at all. **So if a daily forage quota was intended, that schema
has nowhere to keep the counter**, and fishing shows exactly what the complete
version looks like. Seven further undefined contracts are named in the module header of
`godot/scripts/core/forage.gd` rather than silently filled.
