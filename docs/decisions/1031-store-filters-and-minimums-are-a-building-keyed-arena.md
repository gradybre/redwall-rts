# 1031 — Store filters and minimums are a building-keyed arena
Date: 2026-10-02 · Status: Accepted. Brendan ruled on P1–P8 on 2026-10-02, all as recommended (below)

## Brendan's rulings, 2026-10-02 (relayed by the coordinator)

**P1–P8 are approved as recommended.** P1, P3, P5 and P6 confirm what was built, so no behaviour
changed. P2, P4, P7 and P8 set the direction for later work:

- **P1.** No command edits the category mask. SET_STORE_FILTER edits per-item bytes only.
- **P2.** Disallowed stock stays where it is for now. Once physical hauling (H0–H2) lands,
  disallowing an item raises haul-out demand.
- **P3.** The inventory does not refuse placement on the per-item byte. Destination selection
  asks `store_admits()`.
- **P4.** The save owner will be a separate `store_policy` owner in §5 CHILD_ARENAS, whose codec
  writes stale rows as the defaults. The registry rows stay UNRESOLVED until that owner and its
  ordinals are written into `canonical_state_registry.json`. The store must not be bound into a
  saving game before then.
- **P5.** A minimum is only a withdrawal floor for ordinary production, never a fill target.
- **P6.** An empty group is refused, both arguments must be 0, and a building with no store may
  still hold a policy.
- **P7.** No store-policy UI is built until `ui_ux_controls.md` gains UI-SET rows for it.
- **P8.** `store_policy.gd` keeps applying the policy to every store a building owns at its
  origin. The composer will ask `store_policy` instead of keeping its own #3a test, and the
  two-store case should be refused where stores are created.

The **Proposals** section below is kept as the reasoning the rulings answered.

## Decision

Task 06.4 slice H6. REQ-SET-117's per-item store filters and minimum reserves are implemented as
`godot/scripts/core/store_policy.gd`, and the two player commands that edit them,
SET_STORE_FILTER and SET_STORE_MINIMUM, now commit through `command_dispatch.gd`.

- **Storage.** `systems_architecture.md` §3's two already-budgeted rows, exactly:
  BuildingItemAllow (`_allowed`, B8 × 262144) and BuildingItemMinimum (`_minimum_milli`,
  I64 × 262144). One cell per (Building typed row, item id), `building_row * 256 + item_id`:
  ARCH-STATE-004's "1024 exterior main stores" times its 256-key envelope. Defaults: allowed,
  minimum 0.
- **One new column, +4096 B.** `_bound_persistent_id` (I32 × 1024) stamps each row with the
  directory's never-reused persistent ID of the building that wrote it. A reused Building row
  whose stamp names a demolished building reads as the defaults, and its first write resets all
  256 cells before stamping. A generation would not do, because a per-slot generation repeats
  across slots, which is the reason `TransformBinding` gives. The store is not told about
  demolition, so the guard has to sit on the read side. The composer that would tell it,
  `settlement_system.gd`, was outside this lane.
- **The allow byte only restricts.** `store_admits(container, item)` returns the container's
  64-bit category mask (the same test `inventory.gd` applies on placement) AND, for a main store,
  its building's byte. Setting a byte to allowed cannot admit an item the mask excludes. That is
  ARCH-STATE-004's "further restricts".
- **What counts as a main store.** Under DEMO-CONTAIN-R01 #3a it is a container owned by a live
  Building and anchored at that building's origin tile. Any other container answers by its mask
  alone. That covers satchels, ground piles, WIP and project stores, and an owned store placed off
  the origin, which matches ARCH-STATE-004's "inherit their owning job's permitted contents".
- **The minimum is a floor for ordinary production.** `ordinary_withdrawable_milli()` returns
  the container's unreserved stock of the item minus its minimum, never below 0. REQ-SET-117
  names one override, emergency meal access, and an emergency meal consumer does not call this
  query. The minimum is not seed protection. REQ-SET-117's "never seed classification" refers to
  BAL-SAFE-009: no meal counts a seed item as food. The meal selector owns that rule, so setting a
  minimum can neither strengthen nor weaken it.
- **Command schemas.** These follow ARCH-CMD-003's "count first followed by owner-ID-sorted
  rows". The minimum travels as the component's own I64. The B8 allow byte travels as an i32, as
  SET_JOB_PRIORITIES already carries its byte priority:
  - The target is the BUILDING.
  - `arg0` and `arg1` must be 0.
  - The payload is an i32 count from 1 to 256, followed by rows in ascending item order.
  - A SET_STORE_FILTER row is `(item_id:i32, allowed:i32 0/1)`.
  - A SET_STORE_MINIMUM row is `(item_id:i32, minimum_milli:i64)`.
  - Every row is validated before the first write, so the group is atomic.
  - A store refusal is ledgered as COMMAND_STORE_REFUSED, carrying `store_policy.gd`'s own code:
    `STORE_POLICY_STALE_BUILDING`, `_UNKNOWN_ITEM`, `_ALLOWED_DOMAIN` or `_NEGATIVE_MINIMUM`.
  - A refused group records the value 0. Nine kinds are now supported, and fifteen are refused.
- **Binding.** `command_dispatch.bind_store_policy()` is the runtime handoff and has the same
  shape as `bind_ecology()`. It refuses a store built over another directory. Until a composer
  calls it, both kinds refuse COMMAND_STORE_NOT_BOUND. That is the explicit refusal task 04.2
  requires, never a silent success.
- **The shared instance allocator already exists.** Task 06.4 names a "shared instance
  allocator" and gives it no further definition. The adopted contract under that name is
  ARCH-STATE-007's GearInstance lowest-free-row pool, from ruling 2026-09-09 §4. It is already
  implemented in `gear.gd` (decision 0038). Nothing new was built, and nothing in the task text
  defines a second allocator.
- **Mass limits need no new state.** They are the inventory's existing `max_mass_g` capacity
  rule (BAL-SAFE-002), and `store_admits()` deliberately does not answer capacity.

## Why

The arena shape, its size and its scope are all stated in §3 and ARCH-STATE-004, so the only
real choices concerned identity and semantics:

- **Keyed by Building rather than by container.** Inventory containers are not directory
  entities, and ARCH-STATE-004 counts 1024 policy rows. A command target is a directory
  reference, and "1024" is the Building capacity.
- **A read-side stamp rather than a demolition hook.** A hook lives in a composer this lane could
  not touch, and a stamp cannot be forgotten by a future demolition path.
- **A selection predicate rather than placement enforcement.** The haul lane (H0–H2) selects
  destinations by "filters admit". Enforcing the byte inside `inventory.gd` would have meant
  changing its placement contract while that lane is editing the same file. See P3.

`buildings.gd` gains `origin_tile_or_none()`, an allocation-free twin of
`origin_tile_of_building()`, so that the main-store test allocates no OpResult on a selector's
path. `test_store_policy.gd` asserts that the published queries allocate zero objects.

## Proposals for Brendan (ruled 2026-10-02, above)

The documents are silent on each of these. The smallest behaviour was built and is listed first
in each.

- **P1. Who edits the category mask?**
  - (a) Built: no command edits it. The mask is set when the container is created, and
    SET_STORE_FILTER edits per-item bytes only.
  - (b) Add category rows to SET_STORE_FILTER.

  *Recommend (a).* A UI can express a category toggle as a batch of item rows.
- **P2. What happens to stock already in a store when its item is disallowed?**
  - (a) Built: it stays where it is until it is consumed.
  - (b) Disallowing raises haul-out demand.

  *Recommend (b)* once physical hauling (H0–H2) lands, and (a) until then.
- **P3. Should the inventory refuse to place a disallowed item?**
  - (a) Built: no. Destination selection asks `store_admits()`, and `inventory.gd` enforces only
    the category mask.
  - (b) Bind an authority so that `create_lot`, `move` and `transfer` refuse.

  *Recommend (a)* for now. Demolition returns and spill placement would otherwise need their own
  policy exceptions.
- **P4. Save owner.** No codec writes the three columns, and `canonical_state_registry.json` has
  no record for them. The persistence registry reads them as category 1 under §5 CHILD_ARENAS
  and lists them as UNRESOLVED until an owner is chosen, as decision 0534 did for its record.
  - (a) Add a separate `store_policy` owner in §5, whose codec writes stale rows as the defaults.
  - (b) Fold the columns into the buildings owner.

  *Recommend (a).*
- **P5. Is the minimum also a fill target?**
  - (a) Built: no. It is only a withdrawal floor.
  - (b) A store below its minimum raises haul-in demand.

  *Recommend (a).* REQ-SET-117 calls it a "reserve".
- **P6. Schema details.**
  - An empty group is refused.
  - The arguments must be 0.
  - A building with no main store may still hold a policy, which has no effect until a store
    exists. BAL-CAT-007 gives every exterior building a main container, so no check was added.

  *Recommend keeping all three.*
- **P8. Two stores at one origin.** #3a gives a building one main store.
  - (a) Built: `store_policy.gd` applies the policy to every container the building owns at its
    origin, without counting them. `settlement_system.gd::_main_store_of()` instead refuses a
    building with two.
  - (b) Make `store_policy.gd` refuse the ambiguous building too. That costs a bounded owner scan
    on every read.

  *Recommend (a), with the composer's own #3a test replaced by a call into `store_policy`*, so
  that one rule remains. Either way the two-store case should be refused where stores are
  created.
- **P7. UI.** `ui_ux_controls.md` has no UI-SET row for a store-filter or store-minimum panel, so
  no UI was built and no key was added. A panel needs spec rows first.

## Consequences

- The live game cannot use either command until `settlement_system.gd` takes three steps:
  1. construct `StorePolicy.new(_buildings, _inventory)`;
  2. call `_dispatch.bind_store_policy()`;
  3. hand the same instance to destination selection.

  Until that composition lands, both kinds refuse COMMAND_STORE_NOT_BOUND by name.
- **Every reset and every load must `clear()` this store.** The stamp is a persistent ID, and
  persistent IDs are unique within one world only. `entity_directory.clear()` restarts them at 1,
  and a load rewinds the cursor. Without a `clear()` alongside the directory's, a new world's
  building at the same row inherits the old world's policy. Review H1 reproduced this, and
  `test_store_policy.gd` now pins it in both directions. This is decision 0094's rule: the caller
  declares what its reset clears.
- **The composer must not bind the store into a saving game until P4's codec exists.** Without the
  codec, a player's filters and minimums would be lost or wrong after a load, and they would sit
  outside the canonical hash.
- `settlement_system.gd::_main_store_of()` and `store_policy.gd::_main_store_cell()` both encode
  #3a, and they disagree on a building with two stores at its origin (P8). The composer should
  ask `store_policy` instead, so that one test remains.
- `store_admits()` re-derives the inventory's private category test (`inventory.gd`'s
  `_accepts_item()`). Once the haul lane's `inventory.gd` work lands, a public, allocation-free
  `container_accepts_item()` should replace the copy, so that placement and selection cannot
  drift apart.
- A later save codec must project stale rows as the defaults. Otherwise two equivalent worlds
  hash differently.

## Source

REQ-SET-117 (GDD §5.8); ARCH-STATE-004 and §3's BuildingItemAllow/BuildingItemMinimum rows
(`systems_architecture.md`); ARCH-CMD-003; DEMO-CONTAIN-R01 #3a
(`rulings/2026-10-01_demolition_containment.md`); BAL-SAFE-009 and BAL-CAT-007
(`gameplay_balance.md`); ARCH-STATE-007 and decision 0038 for the allocator; task 06.4.
