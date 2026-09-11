# 0064 — World generation creates the §5.1 cohort, and that costs "IDs 1–12"

Date: 2026-09-11 · Status: **Accepted** for the composition; **Open** for the
persistent-ID contradiction, which is the specification owner's ruling to make.

## The gap

Generating a world produced a world with nobody in it.

`godot/scripts/core/world_init.gd` implemented REQ-SET-009's terrain, resource
nodes and ecology. `SettlementSystem.create_initial_settlement()` implemented
GDD §5.1's twelve-resident cohort. **Nothing called both.** The boot scene called
only the second, so the running game had twelve residents standing on no terrain,
with no trees, no basins, no estuary and an unseeded RNG; anything that called
the generator got the reverse. `docs/tasks/04_world_commands.md`'s open item
("Initialize the 12-resident fixture exactly") and `world_init.gd`'s own header
("FULL INITIALIZATION IS THEREFORE BLOCKED") both described one half of this.

GDD §5.1 states **one** initialization contract, not two.

## Decision

`SettlementSystem.create_generated_settlement(items, world_seed)` is that one
operation. It lives in `settlement_system.gd` because that file already composes
every store the generator writes into; no new module was created.

It runs, in order:

1. Refuse `SETTLEMENT_NOT_EMPTY` if residents already exist — checked before
   anything is touched, so the standing settlement is byte-identical.
2. `WorldInit.bound_request(items, world_seed)` — the seventeen resource ids are
   resolved by key against the compiled catalog (decision 0052). A refusal here
   has touched nothing.
3. `WorldInit.generate(request)` — a refusal leaves every store byte-identical
   by that module's own contract, and its code is propagated unchanged.
4. `create_initial_settlement()` — §5.1's cohort, its needs, health, skills,
   priorities, schedule and job agents, plus the opening day's weather.

**Order is forced, not preferred.** `WorldInit._publish()` calls
`EntityDirectory.clear()` (task 04.3: "explicitly reset RNG, generation/free-slot
state ... before exposing an active world"), so a cohort spawned first would be
destroyed by its own world. Generation runs first.

**Allocate before consume (decision 0059) at world scale.** Only step 4 can fail
with a world already standing, and it takes the whole settlement back to empty
rather than leaving a generated world with nobody in it — the exact failure this
whole task exists to remove. `test_a_cohort_that_refuses_leaves_no_half_settlement_standing`
covers it through a subclass whose cohort creation always refuses.

`WorldInit` gained two public readers for this: `directory()`, so a composing
system can *prove* at composition time that it shares one allocator instead of
discovering a mismatch at generation, and `clear()`, so `SettlementSystem.reset()`
discards the published map at the same moment it empties the stores that map
describes. Neither allocates and neither resizes a column.

The boot scene (`godot/scripts/main.gd`) now calls the single operation with
`EconomySystem.definitions()` and §5.1's own fixed tutorial seed 20260905 — the
only seed §5.1 authors. A player-chosen seed belongs to the New Settlement form,
which does not exist; **no substitute default was invented.**

## The contradiction this exposes, unresolved

§5.1 says the starting residents are **"IDs 1–12"**. §4.2 says `EntityIdentity`
is "One per runtime entity; **IDs unique across kinds**" — one persistent-ID
space for the whole world. §5.1 *also* authors the world content that shares it.

With generation first, the counter (restarted at 1 by the directory clear) is
consumed by, in creation order:

| Source | ids |
|---|---|
| Published `ResourceNode` rows (1663 tree + 32 ore) | 1695 |
| Tree nodes the ore footprints replace — created, then destroyed, and §4.2 never reuses an id | 8 |
| `HarvestZone` basins (4 forest + 3 fish) | 7 |
| `FishHabitat` rows | 3 |
| **Total consumed by the world** | **1713** |

so the cohort receives **1714–1725**, not 1–12.

Exactly two readings would close it, and each contradicts a different document:

- **Spawn the residents first and do not reset the persistent-ID counter.**
  Contradicts task 04.3's explicit requirement to reset generation/free-slot
  state before exposing an active world — and resetting it *with* residents
  holding 1–12 would issue those same ids to tree nodes, breaking §4.2's
  uniqueness. It also requires `world_init.gd` to stop clearing the directory,
  which is what its `WORLD_FOREIGN_LIVE_ROWS` refusal exists to protect.
- **Read "IDs 1–12" as resident ordinals rather than persistent ids.**
  Contradicts §4.2's single id space and §5.3's `hash(persistent_id, world_seed)`
  name generation, which treats the resident's ID as its persistent id.

**No id is forced and no constant is invented.** The behaviour is asserted as it
actually is, in `test_the_generated_cohorts_persistent_ids_are_not_gdd_5_1s_one_to_twelve`,
which derives 1714 from the census above rather than hard-coding it, so a future
ruling either changes that assertion deliberately or is caught leaving it wrong.
Nothing observable depends on the value today: `jobs.gd`'s stagger is
`persistent_id % 30` and twelve consecutive ids still produce twelve distinct
offsets.

## What GDD §5.1 still does not get, and why

- **The relationship edges (1,2),(3,4),(5,6),(7,8),(9,10),(11,12) at affinity 20
  are not created. There is no relationship store anywhere in the repository** —
  `grep -ri relationship godot/scripts/` finds only comments naming its absence,
  and `docs/persistence_state_registry.md` has no row for one.
  `docs/tasks/08_community_scenarios_progression.md:26` places "implement real
  relationships" in task 08. §5.3 additionally specifies the degree-8 cap,
  midnight decay toward 0, the conflict chance formula and the pair-ID sort that
  a store would have to satisfy. Inventing a two-column edge list here would
  create a second, wrong owner for all of that. **Reported, not substituted.**
- **The starter hall, 12 beds, kitchen bench, twelve seat places, hearth, pantry,
  well, four stockpiles and outdoor workbench are not created.** No Building,
  Furniture or Room store exists (decision 0060: the footprints are cleared
  ground, and clearing ground is geometry). Bed assignment "resident ID ascending
  and bed ID ascending" therefore has nothing to assign.
- **Equipped tools and tool durability 1000 are not applied.** `gear.gd` exists
  but is not composed into `settlement_system.gd`; the twelve equipped and twelve
  stored tools need a container owner, which is the same missing Building work.
  Clothing tier 1 *is* applied, because `needs.gd` owns that column.
- **The initial inventory is deposited by the boot scene into `EconomySystem`,
  not by this operation.** That was already true and is unchanged here; the two
  are not yet one transaction, so a refused generation leaves the starting stores
  deposited. Named rather than quietly restructured — `economy_system.gd` is
  outside this change's ownership.

## Consequences

- The running game boots into a generated world with twelve residents in it.
- A settlement that was never generated is still legal and still empty, and its
  RNG is still unseeded — `create_initial_settlement()` is unchanged and remains
  the cohort-only path the existing suite uses.
- `SettlementSystem.reset()` now also discards the published map, so "reset then
  generate again" is a supported cycle rather than a generator left claiming a
  world whose stores are gone.
