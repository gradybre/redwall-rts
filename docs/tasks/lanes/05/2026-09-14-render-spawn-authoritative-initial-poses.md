# RENDER-SPAWN — authoritative initial resident poses (INIT-POSE-R01)

Task: 05_movement_first_playable.md
Date: 2026-09-14
Base: `origin/master` at `127c8e4`
Engineering record: [decision 0138](../../../decisions/0138-the-settlement-owns-one-pose-store-and-places-the-cohort-on-the-hall-apron.md)
Contract: [INIT-POSE-R01](../../../rulings/2026-09-14_initial_resident_positions.md)

## What shipped

`settlement_system.gd` composes **one** `transforms.gd` over its own `EntityDirectory` and
publishes it through `transforms()`. The generation transaction validates every INIT-POSE-R01
input against the **prepared** world, places §5.1's twelve by persistent id ascending on the
refuge hall's south exterior apron, reads all twelve back, and only then publishes the world —
so world, cohort and poses are published together or not at all.

`resident_stage.gd` now takes that store as an argument to `attach()` and refuses
`STAGE_NO_TRANSFORM_STORE` rather than building one. `resident_pose_scaffold.gd` and its suite
are **deleted whole**, and the §2.3 ledger row they owned is gone with them.

| INIT-POSE-R01 §1 field | Implemented as | `i = persistent_id - 1`, ids 1..12 only |
|---|---|---|
| Exterior tile | `(58 + i, 69)` | hall origin (58,59), extent 12×10, so z=59..68 is the footprint |
| Tile index | `8890 + i` | `69*128 + 58 = 8890` |
| Root x | `119808 + 2048*i` | `tile_center_x_units(58) = 2048*58 + 1024` |
| Root y | `512` | `WorldInit.LAND_Y_UNITS`, §5.1's authored land elevation |
| Root z | `142336` | `tile_center_z_units(69) = 2048*69 + 1024` |
| Initial yaw | `0` | neutral authored model orientation, asset forward −Z |
| Previous root and yaw | equal to current | `place()` writes previous = current; verified by read-back |

`_assert_assembly_row()` re-derives every one of those seven from `world_init.gd` at composition
time, so the transcription and the geometry cannot drift apart silently.

## The clear mask already reserved the row — no generator change was needed

`world_init.gd` is **byte-untouched**. §5.1's `is_cleared_tile()` is
`is_cleared_loam_tile or is_starter_footprint_tile or is_starter_apron_tile`, and the hall's
one-tile apron ring covers x=57..70, z=58..69 minus the footprint — which contains the whole
assembly row (58..69, 69). `_stage_masks()` writes that into `_staged_cleared` and
`_stage_tree_plan()` then consults it, so the reservation already happens **before** resource
placement, with no extra RNG draw, no resource relocation and no new entity allocation.

That is asserted rather than assumed, from three directions:
`test_the_generated_map_reserves_the_assembly_row_before_resource_placement` reads the
**published** clear byte of each of the twelve tiles;
`test_nothing_static_or_generated_occupies_the_assembly_row` asserts
`resource_nodes.ref_at_tile()` is null for each; and mutation **M6** deletes the apron term from
`is_cleared_tile()` and is killed by 50 failing tests.

## The ledger: one row deleted, every identity recomputed

The scaffold's `87552 × 9 × 4 = 3151872` bytes are **removed, not moved**. §2.2's `Transform`
(8 I32 × 87552 = 2801664) and §3's `TransformBinding` (1 I32 × 87552 = 350208) already budget
the one directory-bound store, and `2801664 + 350208 = 3151872` exactly — so the private store
was a literal duplicate of rows already carried, and nothing compensates for its removal.

| §2.3 identity | Before | After | Arithmetic |
|---|---:|---:|---|
| Planned allocated payload | 72110995 | **68959123** | `72110995 − 3151872` |
| One live world plus reserve | 80499603 | **77347731** | `68959123 + 8388608` |
| Headroom below decimal 100 MB | 19500397 | **22652269** | `100000000 − 77347731` |
| Additional candidate mutable state | 65895411 | **62743539** | `68959123 − 6215584` |
| Transactional peak plus same reserve | 146395014 | **140091270** | `77347731 + 62743539` |
| Transactional headroom | −46395014 | **−40091270** | `100000000 − 140091270` |

Printed §2.3 allocation rows go from 31 to **30**. The ARCH-MEM-009 trail gains one row:

```
| Presentation-private pose scaffold deleted; the settlement composes ARCH-SYS-001
  and INIT-POSE-R01 places the cohort into it | decision 0138 | −3151872 | 68959123 | 77347731 |
```

Decision 0130's own `+3203072` trail step is historical and left exactly as recorded, as are the
0066-basis figures in the ARCH-MEM-010 paragraph and ARCH-MEM-006's two-world peak — both were
already stale against the current trail before this lane and re-basing them is its own task.
ARCH-MEM-006's conclusion is unchanged: the two-world peak is still over the gate.

### `docs/validation/ready07_arithmetic.py` — not in this lane's allowlist

Four pin changes are required. They were verified by running a patched copy from inside the
worktree, which printed
`{"status": "PASS", "field_rows": 144, "allocation_rows": 30, "scheduler_total_bytes": 8224, "checked_local_links": 122, "runtime_tests": "NOT_RUN"}`,
and then deleted. The integration lead applies them:

```diff
 DECISION_0131_ADDED=(2*1*82944)+(7*4*82944)+(1*8*331776)
 assert DECISION_0131_ADDED==5142528
-assert len(allocations)==31 and sum(allocations)==DECISION_0050_ROW_SUM+...+DECISION_0131_ADDED
+# decision 0138: the presentation-private pose scaffold row is DELETED, not moved. §2.2's
+# Transform (8 I32 x 87552 = 2801664) and §3's TransformBinding (1 I32 x 87552 = 350208) already
+# budget the one directory-bound store settlement_system.gd now composes, and they sum to exactly
+# the scaffold's 3151872. Decision 0130's own +3203072 trail step is historical and unchanged.
+DECISION_0138_REMOVED=-(87552*9*4)
+assert DECISION_0138_REMOVED==-3151872
+assert len(allocations)==30 and sum(allocations)==DECISION_0050_ROW_SUM+...+DECISION_0131_ADDED+DECISION_0138_REMOVED
 payload=sum(allocations);reserve=8388608;candidate=payload-6215584;live=payload+reserve
-assert payload==72110995
-assert live==80499603 and candidate==65895411 and live+candidate==146395014
+assert payload==68959123
+assert live==77347731 and candidate==62743539 and live+candidate==140091270
```

(The `+...+` above elides the unchanged middle of that one long sum; only `len(allocations)` and
the appended `+DECISION_0138_REMOVED` term change on that line. `DECISION_0130_ADDED==3203072`
stays as it is.)

## Files changed

| File | Change |
|---|---|
| `godot/scripts/systems/settlement_system.gd` | composes `transforms.gd`; INIT-POSE-R01 constants, validation, placement and read-back; published-world guard; header corrected where it claimed no Transform store exists |
| `godot/scripts/core/transforms.gd` | cold guarded `reset()` over all nine columns and the derived count; `state_bytes()` image |
| `godot/scripts/presentation/resident_stage.gd` | `attach(residents, transforms)`; borrows, never builds; `transforms()` reader |
| `godot/scripts/presentation/resident_crowd.gd` | `transforms()` reader for identity assertions; header records the new owner |
| `godot/scripts/main.gd` | passes `SettlementSystem.transforms()` to `attach()` |
| `godot/scripts/presentation/resident_pose_scaffold.gd` | **deleted whole** |
| `godot/test/test_settlement_system.gd` | 20 new tests and six fixture classes |
| `godot/test/test_transforms.gd` | 5 new tests for `reset()` and `state_bytes()` |
| `godot/test/test_resident_stage.gd` | rewritten for the borrowed store; explicit fixture poses |
| `godot/test/test_resident_crowd.gd` | whole-image write-back test and store-identity assertion |
| `godot/test/test_resident_pose_scaffold.gd` | **deleted whole** |
| `docs/systems_architecture.md` | scaffold row deleted; six §2.3 identities recomputed; ARCH-MEM-009 row added |
| `docs/decisions/0138-*.md` | new |
| `docs/tasks/05_movement_first_playable.md` | one checklist bullet under 05.2 |
| `docs/validation/evidence/resident-render-path/authoritative-spawn/` | new: README plus four native captures |

`godot/scenes/main.tscn` needed **no change** — `attach()` was already called from `main.gd`, not
from the scene. `godot/scripts/core/world_init.gd` is **byte-untouched**
(`664d7bbdd96456818f0e1baaf19af6081fac9dcd317df31b8770c0999c717130`, identical to `origin/master`).

## Retired tests, and why

`test_resident_pose_scaffold.gd` is deleted with the file it covered. Nothing in it was silently
dropped:

| Retired assertion | Where it went |
|---|---|
| the scaffold owns a private `transforms.gd` over the shared directory | **retired.** The ownership it asserted is exactly what INIT-POSE-R01 forbids |
| `place_all()` stands every LIVING resident up, in slot order | replaced by `test_the_generated_cohort_stands_on_the_authored_assembly_row`, which asserts by **persistent id** instead |
| `muster_tile_x/z()` wrap an arbitrary population across rows | **retired.** The ruling defines no placement for id 13+, so an arbitrary-population muster algorithm is exactly the invented contract it warns against |
| refuses an unwalkable tile | replaced and widened: `REFUSE_POSE_TERRAIN` now covers terrain, walkability AND elevation, checked for all twelve before any write |
| geometry derived from `world_init.gd` rather than transcribed | replaced by `_assert_assembly_row()`, which re-derives all seven authored fields at composition time |

## Verification

```
./tools/run_tests.sh
state_registry_coverage: PASS -- 54 modules, 352 rows, 681 packed columns checked
4353 test(s), 155505 assertion(s), 0 failure(s)
```

`godot --headless --path godot --editor --quit` was run FIRST in the fresh worktree; without it
the import step has not happened and phantom failures appear. Baseline on this worktree before
any change was `4336 test(s), 152719 assertion(s), 0 failure(s)`.

### Mutation testing: 17 mutations, one Godot invocation each, 17 killed

`perl -e 'alarm 900; exec @ARGV'` per run; the harness asserts the target is byte-identical to a
pristine copy **before** applying, restores from that copy afterwards, re-compares the SHA-256,
and parses the runner's failure count as an integer. Every row below ran against the final tree
in one uninterrupted sequence, and all five touched files hash identically to their pristine
copies afterwards (verified above).

| # | Mutation | File | Verdict | Failing tests |
|---|---|---|---|---:|
| M1 | root x drops the per-index tile pitch (all twelve stack on one tile) | `settlement_system.gd` | KILLED | 42 |
| M2 | authored tile index `8890` → `8891` (breaks `z*128+x`) | `settlement_system.gd` | KILLED | 164 |
| M3 | initial yaw `0` → `16384` | `settlement_system.gd` | KILLED | 1 |
| M4 | `place()` writes `prev_x = x + 1`, so previous ≠ current | `transforms.gd` | KILLED | 44 |
| M5 | row moved to z=68, INSIDE the hall footprint | `settlement_system.gd` | KILLED | 164 |
| M6 | `is_cleared_tile()` stops reserving the starter apron | `world_init.gd` | KILLED | 51 |
| M7 | the renderer writes back: `set_yaw()` inside `refresh_into()` | `resident_crowd.gd` | KILLED | 3 |
| M8 | assignment by resident row instead of persistent id | `settlement_system.gd` | KILLED | 1 |
| M9 | `reset()` leaves `_bound_persistent_id` behind | `transforms.gd` | KILLED | 6 |
| M10 | the published-empty-world guard removed | `settlement_system.gd` | KILLED | 1 |
| M12 | `_place_initial_cohort()` never called | `settlement_system.gd` | KILLED | 6 |
| M13 | `assembly_covers_tile()` covers nothing | `settlement_system.gd` | KILLED | 2 |
| M14 | `state_bytes()` omits the binding column | `transforms.gd` | KILLED | 1 |
| M15 | the stage builds its own pose store instead of borrowing | `resident_stage.gd` | KILLED | 2 |
| M16 | the planned-tree occupancy scan ignores the apron | `settlement_system.gd` | KILLED | 1 |
| M17 | the pre-placement binding check always passes | `settlement_system.gd` | KILLED | 1 |
| M18 | the post-placement previous=current read-back always passes | `settlement_system.gd` | KILLED | 1 |

**Three of these were killed only after tests were added for them, and both facts are recorded
rather than resolved by argument.**

* **M13 and M16 survived the first run.** The apron exclusion's refusing branch is unreachable
  through generation — the clear mask reserves the row and a planned tree requires uncleared
  ground — so the whole check could be replaced by `return false` with the suite green. Rather
  than declare it equivalent, `refuse_assembly_occupancy()` was made **static and
  world-injected** and `assembly_covers_tile()` public, and `PlannedApronWorld` now hands it a
  plan that DOES claim an apron tile, in both the centre and grove lists, plus an unreadable
  entry and a null generator.
* **M17 and M18 survived the first run.** The pre-placement binding check and the
  previous=current read-back cannot fail once identity resolution has passed. `OccupiedRowSettlement`
  and `HistoryBreakingSettlement` swap in Transform stores that break exactly those two
  properties and nothing else, which executes both branches.

A harness incident is disclosed: an earlier run was interrupted mid-mutation by an edit to a file
it had frozen, and one `world_init.gd` mutant was left applied when the process was killed. The
file was restored from git and SHA-256 compared before anything else ran, every verdict from the
contaminated sequence was discarded, and the seventeen rows above are from a single clean
sequence over a frozen tree.

## What this does NOT do

1. **No visual acceptance.** The cohort renders as one untextured white bind-pose mouse mesh.
   Species, material, rig and **facing** validation is a separate presentation lane, and the
   facing question needs a human eye — see the evidence README.
2. **No placement contract for persistent id 13 or above.** `i = persistent_id - 1` is defined
   for ids 1..12 and for nothing else. Immigration, births, rescue release, load, teleportation
   and scenario variants each need their own contract, and a later arrival belongs at §5.1's map
   exit (64,126), never on the assembly row. The resolver **refuses** a cohort carrying id 13.
3. **The §4 save codec round trip is BLOCKED**, not covered. A resident whose previous and
   current differ cannot be round-tripped because no Transform codec exists, and a store-only
   copy test is not a substitute. `state_bytes()` is a comparison image, not a save format.
4. **The rules identity input is not updated.** INIT-POSE-R01 §3 requires this starter-placement
   semantic revision recorded so an older generated settlement with unbound residents is not
   accepted as a valid new-format world. That lives in `docs/planning/canonical_state_registry.json`,
   which another lane owns right now, so it is reported here and not edited.
   `docs/validation/ready07_arithmetic.py` likewise: until the four pins above are applied its
   `assert len(allocations)==31` fails, so CI stays red on that one step even though every number
   it would check has been verified with a patched copy.
   `docs/planning/work_queue.json`, `docs/validation/memory_ledger_measurement.md` (whose
   "eleven core stores are not composed by SettlementSystem" sentence now counts ten) and
   `docs/planning/astra_cycles/cycle_01_evidence.json` all still name the deleted scaffold; all
   three are outside this allowlist.
5. **No clearance, spacing, route-admission, turning or qualification proof.** MOVE-G01–05 remain
   open to their existing extent, `tick_stage_count()` is still 8, and no mover exists.
6. **One cold-path allocation is named rather than removed.** `refuse_assembly_occupancy()`
   allocates one `IntMath.IntResult` per planned tile, because `world_init.gd` publishes no
   `_into` form of `planned_tree_centre_at()` and that file is another owner's. At most 3100 of
   them, once per generated world, on a path that is not the tick path. Closing it means adding
   `planned_tree_centre_into(index, out)` to `world_init.gd`.
