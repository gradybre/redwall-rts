# 0533 — The starter colony is materialised, and the stores are owned by it
Date: 2026-10-01 · Status: Accepted

Numbered 0533 because the brief asked for 0533–0539. No record numbered 0533–0599 exists on any
branch (`git log --all`) or in any sibling worktree when this was written. Parallel branches may
also allocate in the 053x range; `docs/validation/decision_numbers.py` will refuse a collision at
merge.

## Decision

**Step D3 of [DEMO-CONTAIN-R01](../rulings/2026-10-01_demolition_containment.md) lands with this
record.** It covers answers #3a, #3b and #7 and blocker 6 ("nothing to demolish in real play"),
plus the two obligations decision 0532 handed to D3: create the World row and bind the composer,
and refuse a footprint over a live pile (0532's M4).

1. **INIT-C live apply: `godot/scripts/core/starter_colony.gd`.** A narrow translator from
   `starter_structures.gd`'s validated plan (decision 0184) to `buildings.gd`'s ordinary public
   doors. It writes no column itself.
   - `preflight_refusal(buildings, plan, mask)` proves, writing nothing: the plan
     (`StarterStructures.plan_refusal()`), every building placement through the new
     `buildings.placement_refusal()` preview, and the free Building, Room and Furniture directory
     rows.
   - `apply_into()` then places, in plan order: the 7 buildings (each set to the plan's desired
     state, ACTIVE), the hall's 4 rooms from their runs of the plan's 80 room tiles, and the 31
     floor furniture at their global origins (interior origin = hall origin + (1,1), §5.9).
   - `plan_mismatch_refusal()` re-reads every placed row against the plan: building type, origin,
     rotation, tier, state and its origin tile's owner; room parent, type and exact tile run;
     furniture type, origin, rotation and room.
   - After the preflight every remaining door is deterministic over an empty hall, so a refusal
     inside the apply means the store changed under it. Buildings has no transaction, so the
     **caller owns rollback**: the settlement resets to empty, as it does for every other
     in-transaction generation failure (decision 0075).
2. **`settlement_system.gd` runs it inside the generation transaction, after the world.**
   `create_generated_settlement()` preflights the plan with everything else, then, after
   `publish_prepared()`: creates the **World directory row** (`KIND_WORLD`), binds it to the
   ground-pile composer, applies the colony and verifies it. A failure abandons the transaction.
   - The order keeps R-INIT-ID-001 intact: residents 1–12, the world from 13, then the World row
     and the 42 colony rows. `test_the_world_entities_continue_the_same_counter_from_thirteen`
     now counts 1705 + 43 non-resident rows and still finds 13 first.
   - **UI-SET-103's Create** publishes through its own session, so `ui_manager.gd` calls the new
     public `materialize_starter_colony()` after it. It refuses `STARTER_COLONY_ALREADY_PRESENT`
     on a site with a live building or a World row, writing nothing. A failure after its first
     write resets the settlement, as a cohort refusal does; `ui_manager.gd` also resets on a
     refusal caught before the first write, so Create never leaves a world without its colony.
   - `ui_world_session.gd` declares the four new kinds its `reset` Callable clears (Building,
     Room, Furniture, World; decision 0094), or Create after a boot would refuse
     WORLD_FOREIGN_LIVE_ROWS.
   - The colony's unlock mask is §5.11's "Active new worlds start with M0=0 and both masks=1",
     `Milestones.INITIAL_MASK`, named once as `STARTER_UNLOCKED_MASK`.
3. **The ground-pile composer is composed and kept alive (0532's obligation).** `_init()` builds
   `ground_piles.gd` over the settlement's inventory, buildings and stock age, binds it as
   Inventory's site authority, and holds it strongly in `_ground_piles` for the node's life,
   because Inventory and Buildings hold it weakly. Its World binding is made each time the
   colony is materialised. `world_ref()` reads the World row back from the directory (typed row 0
   of a capacity-1 kind), so it also answers after a future load.
4. **Placement over a live pile is refused by name (0532's M4).**
   - `buildings.gd` gains `set_placement_authority(authority)`. The authority publishes
     `building_tile_refusal(tile) -> StringName`. `_refuse_footprint()` shows it every footprint
     tile **after** its own grid and overlap checks, and returns the first refusal unchanged.
   - Held weakly; kept by `clear()`; a released authority fails closed
     (`INVALID_PLACEMENT_AUTHORITY`). A standalone store with none bound has no piles to cover.
   - `ground_piles.gd::building_tile_refusal()` answers `BUILDING_FOOTPRINT_OVER_GROUND_PILE` for
     a tile with a live pile (one read of Inventory's derived tile map), and
     `GROUND_PILE_STORES_NOT_BOUND` before `bind_stores()`.
   - `bind_stores()` does not make this binding itself; the settlement does. That keeps D2's
     "a pile on a tile that later becomes illegal" test meaningful.
   - Evacuating the pile is D6's. This step only refuses.
5. **Answer #7: the stores are owned and anchored.** `economy_system.gd` no longer opens anything
   in `reset()`.
   - `open_starter_stores(binding)` creates, in **one inventory transaction**: the pantry
     (200000 g, owned by the hall, anchored at the hall's origin tile) and **four** material stores
     (400000 g each, owned by one open stockpile each, anchored at its origin), in plan order,
     which is ascending container order. It refuses `STORES_ALREADY_OPEN`,
     `INVALID_STORE_BINDING` (null, incomplete, malformed owner or off-grid anchor),
     `CATALOG_UNAVAILABLE`, and `NESTED_TRANSACTION` when a caller holds a transaction open on
     `inventory()`, writing nothing. Deposit and withdraw refuse that nesting too, so an economy
     operation never commits or aborts a transaction it did not open.
   - The binding is `StarterColony.StoreBinding`, read back from the **live** Building rows at the
     plan's origin tiles by `settlement.starter_store_binding_into()`. It is never remembered.
   - **#3b:** pantry shelves are not containers. The hall-owned pantry holds the four shelves'
     200000 g; the kitchen's fifth shelf adds nothing (R-BUILD-DOM-004).
   - **Then `inventory.gd::create_container()` refuses an ownerless container**:
     `is_well_formed_owner()` (slot ≥ 0, generation > 0) or `INVALID_OWNER_REF`, checked first,
     before mass. It checks shape, not liveness; Inventory holds no directory.
     `containers_by_owner_into()` uses the same predicate.
6. **§5.9's fill order is implemented, because four stores make it observable.** "All initial
   items are assigned to legal containers by food first, then item ID, filling container IDs
   ascending."
   - A deposit fills its legal stores in ascending container order, splitting at
     `floor(free_g * 1000 / mass_g)` — the largest part whose per-lot ceiling charge fits, the
     same split `ground_piles.gd` uses. It is all-or-nothing in one transaction:
     `CAPACITY_EXCEEDED` writes nothing.
   - `seed_initial_inventory()` deposits GDD §5.1's list food first, then by compiled item id.
     The list moved from `main.gd` to `EconomySystem.INITIAL_INVENTORY_U` so boot and Create seed
     one list. The result is pantry 179200 g and stockpiles 400000 / 400000 / 400000 / 312000 g.
   - `material_store()` is gone; `stockpile(index)`, `stores_open()` and
     `material_used_mass_g()` replace it. `stock_units()`, `food_days_text()` and the HUD figures
     are unchanged (408000 NP, 5.48 days, wood 180, stone 100).
7. **Boot and Create.** `main.gd` generates first, then opens the stores on the colony and seeds
   them; a refused generation leaves them closed. `ui_manager.create_world()` resets the
   economy, reopens it on the new colony and reseeds §5.1's inventory, because Create discards
   the settlement that owned the previous stores. It does so BEFORE the HUD repaint, so the
   first figures after Create are the new settlement's (the review's H1). A refused Create
   keeps the stores only while their owner still lives; once the session's reset has destroyed
   the colony, the stores are closed rather than left with stale owners (#7).
8. **Save: no schema bump.**
   - The colony's rows persist through the existing owners. Directory section 3 and §1's cursor
     carry the World row and the 42 structure rows with their persistent ids. Section 1's
     `buildings` block carries the 197 footprint, 80 room and 33 furniture-floor tiles and
     cross-checks against the live rows. Section 4 owner 0's column predicate accepts the
     colony's 29 columns; Buildings has no bulk capture or apply yet (BUILDINGS-SAVED-BINDINGS),
     so that is a predicate check, not a round trip.
   - **The starter stock itself is not saved.** EconomySystem's inventory is in no save path;
     section 7 captures the settlement's. What is shown is that the section 7 codec carries the
     five owned, anchored containers and their lots exactly (capture, encode, decode, apply,
     re-encode byte-identical), so nothing in the format stands in the way once the stores are
     merged or captured.
   - Nothing new is saved: the binding is re-read from live rows, the composer's World binding is
     re-made from the directory, and the placement authority is wiring.
   - So DEMO-CONTAIN-R01 #8's refuse-older semantics are not triggered. Section 7 stays schema 5,
     inventory owner schema 4, registry version 7.
9. **Memory: no ledger change.**
   - The composer's 86020 B of scratch was already ledgered by decision 0532 as resident; it is
     now actually allocated in the running game.
   - The World row uses the directory's budgeted capacity-1 kind.
   - The apply's records are cold transients: one or two 2480-byte Plans per generation or binding
     read, the 336-byte `Applied` record and the 60-byte binding. None is resident between calls
     or saved; `persistence_state_registry.md` classifies them (category 3).
   - EconomySystem's store columns are 2 × 5 × I32 = 40 B in place of two 8-byte refs.
     EconomySystem has no ARCH §2 row at all, a pre-existing gap this does not close.

## Why — the executor's readings, stated so they can be overruled

- **After the world, not before it.** R-INIT-ID-001 fixes the cohort at 1–12 and the world from
  13. The colony therefore takes the ids after the world. §5.9's "clear these footprints before
  resource placement" is satisfied by `world_init.gd` clearing them (decision 0060); the
  structures need nothing from the resource layer.
- **The edges, room validity, building condition and bed assignment are not applied.**
  - The eight partition/door edges have no defined `origin_tile` + `rotation` encoding of an
    undirected edge (decision 0080; decision 0087 blocker 4). Placing them would invent one.
  - §5.9's validity rules need connectivity, enclosure and heat, which nothing evaluates, so every
    room stays `valid = 0`.
  - Building condition has no stated scale.
  - The plan's bed order is data for a future assignment owner.
  The brief asked for "the 31 furniture"; these four are the named remainder.
- **The tier is not written.** `place_building()` writes tier 1, and the authored plan's tier is 1
  everywhere; `plan_refusal()`'s exact-fixture gate pins it. The verification still re-reads the
  tier (a tier-2 hall is caught in the tests), so relaxing that pin would surface as
  `STARTER_COLONY_PLAN_MISMATCH` rather than a silently wrong colony.
- **Create reseeds the inventory.** Before this step Create kept the booted economy's lots. Those
  lots now live in stores owned by rows the reset just destroyed. Moving them would need an owner
  setter that Inventory deliberately lacks, and would keep a stock that belongs to a discarded
  settlement. §5.1's initial inventory belongs to every new settlement.
- **"Food first" is unobservable today, and is kept anyway.** Pantry and material categories are
  disjoint, so food-first versus material-first cannot change where anything lands. Item-id order
  within the four stockpiles does change it, and is tested to the gram. The food-first clause stays
  because it is the specification's sentence and becomes observable if a category ever routes to
  both.
- **The placement authority is a binding, not an Inventory dependency in Buildings.**
  R-BUILD-DOM-004 keeps containers out of Buildings, and decision 0531 kept Inventory free of a
  Buildings dependency. The authority pattern is the one already used for the equipment,
  seed-expiry and ground-pile authorities. Each footprint tile is checked through one cold call.
- **Rejected alternatives:**
  - Opening the stores with a placeholder owner, or with the World row (#7's "Alternative" column).
    The ruling chose the Buildings, and the exclusions forbid picking the Alternative.
  - Keeping one 1600000 g material container owned by one stockpile. #7 names "the four stockpile
    Buildings (400,000 g each)".
  - A settlement-level `place_building()` wrapper for M4. A second door can be bypassed; the
    authority sits behind the only door.
  - Merging EconomySystem's inventory into the settlement's. It is the right long-term direction
    (decision 0087), but it would start aging the starter food, put it in saves, and change what
    the stock-integrity pause sees. That is not part of D3, and it is D4's first question (below).

## Consequences

- **D4 must know that the starter stores live in a DIFFERENT inventory from the one its gate
  reads.**
  - `request_demolition()` scans `settlement.inventory()`. The hall's pantry and the stockpiles'
    stores are in `EconomySystem.inventory()`.
  - Their owners and anchors are correct, but an owner scan or anchor query over the settlement's
    inventory will **not see them**. A stockpile full of wood would read as empty.
  - D4 must either scan both stores, or first make EconomySystem adopt the settlement's inventory
    (decision 0087's `bind_inventory()`, with a reset that drops rather than clears a borrowed
    store). The second is the only way one transaction can cover a demolition.
  - Until then, demolishing a starter stockpile or the hall must not reach a success path.
- **D4 reads placement through `container_anchor_tile_into()`** (decision 0531). The five starter
  containers are anchored: the hall's at tile 7610, the stockpiles' at 7730, 8370, 7750 and 8390.
- **A building-owned container's anchor is its building's origin tile**, inside the footprint as
  answer #5 requires. An anchored container owned by something else that sits on a footprint is
  D4's refusal case.
- **`materialize_starter_colony()` is the only path that makes a World row.** After a future load
  the World row comes back through the directory, but the composer's binding does not. The load
  owner must call `ground_piles().bind_world(world_ref())`; a failed rebind leaves every pile
  request refused NO_WORLD, which is fail-closed.
- **Nothing evacuates a pile** that a later placement would cover; that is still D6.
- **`test_every_starter_building_still_refuses_demolition_at_stage_5`** pins the gate's current
  refusal on the real hall, a stockpile, the well and the workbench, so D4 changes it on purpose.
- **D4's admit will create KIND_CONSTRUCTION rows**, which the settlement's reset also clears.
  `ui_world_session.gd`'s `_caller_cleared_kinds` must then declare that kind too, or Create
  during a demolition refuses WORLD_FOREIGN_LIVE_ROWS.
- **Section 7's restore still accepts a live non-pile container with a malformed owner.**
  `create_container()` can no longer write one, so a restore could refuse it; that is a format
  tightening left to whoever next touches section 7 (D4's anchored-NULL_REF refusal covers the
  gate meanwhile).
- **The demo is untouched.** Its village keeps its own presentation buildings and
  `tunnel_stores` (decision 0251). The autoloaded EconomySystem now boots with closed stores in
  the demo scene, which never reads them.
- `docs/planning/registry_capacity_audit.json` is regenerated, because `inventory.gd` and
  `buildings.gd` changed.

## Evidence

(Filled in below as the runs complete.)

## Source

DEMO-CONTAIN-R01 #3a, #3b, #5, #7, #8, blocker 6 (Brendan, 2026-10-01, DEC-043); decisions 0531
and 0532 (D1, D2, and 0532's M4 and World-row obligations); decision 0184 / INIT-C-PREP-R01v1;
decisions 0060, 0075, 0080, 0087, 0094, 0145, 0251; R-INIT-ID-001; R-BUILD-DOM-004; GDD §5.1,
§5.9, §5.11; ARCH-MEM-002.
