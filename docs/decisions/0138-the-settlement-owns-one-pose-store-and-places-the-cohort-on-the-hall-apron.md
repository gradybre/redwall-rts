# 0138 — The settlement owns one pose store, and places the cohort on the hall apron

Date: 2026-09-14 · Status: **Accepted**

## Decision

1. **`settlement_system.gd` composes exactly one `transforms.gd`**, built over the SAME
   `EntityDirectory` the resident store owns, cleared with every other store in `_clear_stores()`,
   and published through `transforms()`. The renderer BORROWS that object: `resident_stage.gd`
   takes it as an argument to `attach()` and refuses `STAGE_NO_TRANSFORM_STORE` rather than
   building one. `resident_pose_scaffold.gd` and its suite are **deleted whole**.

2. **INIT-POSE-R01's authored row is implemented literally and re-derived.** Ordered by persistent
   id ascending, `i = persistent_id - 1` for ids 1..12: tile `(58 + i, 69)`, tile index `8890 + i`,
   root `(119808 + 2048*i, 512, 142336)` simulation units, yaw `0`, previous = current.
   `_assert_assembly_row()` re-derives every one of those numbers from `world_init.gd` — hall
   origin, hall extent, tile pitch, tile centre, land elevation — so the transcription and the
   geometry cannot drift apart silently.

3. **Everything is validated before the first write.** `_refuse_assembly_row()` decides identity,
   binding, tile, terrain, elevation, clearing, footprint and PLANNED-resource occupancy for all
   twelve candidates; only then does `_place_initial_cohort()` call `place()` twelve times, and
   `_verify_assembly_poses()` reads all twelve back. A failure on resident twelve cannot expose
   eleven placements, and there is no dynamic-growth fallback.

4. **Placement happens inside the generation transaction, against the PREPARED world.** It runs
   after the cohort takes ids 1-12 and before `publish_prepared()`, so world, cohort and poses are
   published together and any failure abandons the whole transaction.

5. **A published world is never overwritten, even an empty one.** `create_generated_settlement()`
   now refuses `SETTLEMENT_WORLD_ALREADY_PUBLISHED` before mutation. The old
   `residents.population() != 0` guard was insufficient: replacement rollback does not exist, so a
   world with nobody standing in it would be destroyed by the transaction's reset and could not be
   rebuilt.

6. **`transforms.gd` gains a cold, guarded `reset()` and a `state_bytes()` image.** The reset
   zeroes all nine columns INCLUDING `_bound_persistent_id` and the derived count, and is called
   only from `settlement_system.reset()` alongside the directory and resident clears. Load is
   explicitly NOT reset-then-spawn: a restore installs saved current AND previous fields, and
   calling `place()` for a restored resident would flatten its saved history.

## Why

### The store was allocated twice and owned by the wrong layer

Decision 0130 shipped a working `MultiMeshInstance3D` crowd over a presentation-private
`transforms.gd` instance, because nothing in the running game gave a resident a position and GDD
§5.1 authored no spawn coordinates. That scaffold cost **3151872 bytes** — nine `PackedInt32Array`
columns at `TRANSFORM_CAPACITY` = 87552 — which was 98% of the render path's whole ledger delta,
and it was a second answer to where a resident is.

INIT-POSE-R01 authored the missing row, so the scaffold's reason to exist is gone. The renderer
needed no change to accept the real store: `bind_stores()` already took it as an argument.

### The ledger delta is a removal, not a move

The simulation Transform allocation was **already budgeted** and did not need adding again:
§2.2's `Transform` row is 2801664 bytes (8 × I32 × 87552) and §3's `TransformBinding` row is
350208 bytes (1 × I32 × 87552). `2801664 + 350208 = 3151872` — exactly the scaffold's figure. So
the private store was a literal duplicate of rows already carried, and deleting it is a clean
`−3151872` with no compensating addition.

Recomputed mechanically from the 30 printed §2.3 allocation rows:

| Identity | Before | After | Arithmetic |
|---|---:|---:|---|
| Planned allocated payload | 72110995 | **68959123** | 72110995 − 3151872 |
| One live world plus reserve | 80499603 | **77347731** | 68959123 + 8388608 |
| Headroom below decimal 100 MB | 19500397 | **22652269** | 100000000 − 77347731 |
| Additional candidate mutable state | 65895411 | **62743539** | 68959123 − 6215584 |
| Transactional peak plus same reserve | 146395014 | **140091270** | 77347731 + 62743539 |
| Transactional headroom | −46395014 | **−40091270** | 100000000 − 140091270 |

The ARCH-MEM-009 trail gains one row at `−3151872`. Decision 0130's own `+3203072` step is
historical and is left exactly as recorded. ARCH-MEM-006's conclusion is unchanged: the two-world
peak is still over the gate, which is why disk-backed rollback was selected.

`docs/validation/ready07_arithmetic.py` is not this lane's file; the exact pin changes it needs
are reported in the lane record and applied by the integration lead.

### Why assignment is by persistent id even though slot order would work today

On a fresh directory the two agree on every row: ids are minted in slot-allocation order, so
`out[persistent_id - 1] = slot` and `out[slot] = slot` are indistinguishable from any production
world. The ruling orders the cohort by id, and the row an entity occupies is an allocation detail
that a later lifecycle path is free to change. `resolve_assembly_order_into()` is therefore
**static and store-injected**, so a fixture whose ids run backwards against its slots can execute
the rule: `test_assignment_follows_the_persistent_id_and_not_the_resident_row` reverses them and
requires apron index 0 to go to the LAST row. Without that fixture the rule is untestable, and the
mutation that replaces it with slot order survives.

The same reasoning applies to `refuse_assembly_occupancy()`. The authored map can never plan a
resource node on the apron — the clear mask reserves the row before resource placement, and a
planned tree requires uncleared ground — so its refusing branch is unreachable through generation.
It is static and world-injected so a fixture plan can execute it, rather than being argued
equivalent to doing nothing.

### What the row is, and what it deliberately is not

It is the hall's **south exterior apron**: hall origin (58,59), extent 12×10, occupied z=59..68,
so z=69 is one tile clear of the footprint. It is not a bed, a room, a floor slab or a building,
and it grants **no home assignment** — `live_building_count()`, `live_room_count()` and
`live_furniture_count()` are still 0 after generation, and no resident has a live home or bed.

## Consequences

* **Forbidden.** Inferring a positive-yaw rotation convention for moving actors from the initial
  yaw of 0; assigning species from slot order; extending `i = persistent_id - 1` to id 13 or above.
  Immigration, births, rescue release, load, teleportation and scenario variants each need their
  own placement contract, and a later arrival uses §5.1's map exit (64,126), not this row.
* **Owed.** The §4 save codec round trip for a resident whose previous and current differ is
  **BLOCKED**: no Transform codec exists, and a store-only copy test is not a substitute. The
  rules identity inputs must record this starter-placement semantic revision so an older generated
  settlement with unbound residents is not accepted as a valid new-format world; that registry is
  another lane's file and is reported, not edited here.
* **Not claimed.** Species, material, rig and facing validation is a separate presentation lane.
  The cohort still renders as one untextured bind-pose mouse mesh. This work fixes ownership and
  placement only; it is not visual acceptance, and it is not a clearance, spacing, route-admission
  or qualification proof. MOVE-G01–05 remain open to their existing extent.
* **Movement.** When ARCH-SYS-012 is composed it receives THIS instance as its sole pose writer,
  under ARCH-SYS-001's single-writer discipline. No second `_process` movement loop is added here.

## Source

INIT-POSE-R01 (`docs/rulings/2026-09-14_initial_resident_positions.md`); GDD §5.1 / REQ-SET-009
and §5.9's authored footprints; ARCH-SYS-001 (`transforms.gd`) and ARCH-AUTH-002; ARCH-SAVE-002 /
REG-R01; SET-MOVE-001; R-INIT-ID-001 and decision 0075 (the transaction order); decision 0059
(allocate before consume); decision 0130 (the render path this replaces the scaffold in);
ARCH-MEM-001 and the ARCH-MEM-009/010 ledger trail.
