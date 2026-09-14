# INIT-POSE-R01 — initial resident positions and one authoritative Transform owner

2026-09-14 · Accepted planning contract; implementation and runtime acceptance pending.

<a id="resident-spawn-positions-and-the-pose-scaffold"></a>
## Answer to #resident-spawn-positions-and-the-pose-scaffold

**Compose one `transforms.gd` instance in `settlement_system.gd`, using the same
EntityDirectory as the resident store. The renderer borrows this instance. For
the initial twelve residents, adopt the south apron of the refuge hall as the
authored assembly row. Delete the presentation-private Transform store once
that integration passes its acceptance tests.**

Owning contracts: GDD §5.1 / REQ-SET-009 initial-world transaction and §5.9
footprints; ARCH-SYS-001 positioned state and tick ownership; ARCH-AUTH-002
integer coordinates; ARCH-SAVE-002 / REG-R01 persisted Transform fields;
SET-MOVE-001 presentation/placement separation. This adds a starter placement
choice to §5.1; it does not reinterpret bed allocation as a spawn algorithm.

## 1. Exact starter placement

Order the initial cohort by **persistent ID ascending**, IDs 1 through 12 under
R-INIT-ID-001. For index `i = persistent_id - 1`, use:

| Field | Authored value |
|---|---|
| Exterior tile | `(58 + i, 69)`, for `i=0..11` only |
| Tile index | `8890 + i` (`z*128+x`) |
| Root x | `119808 + 2048*i` simulation units |
| Root y | `512` simulation units, the authored land elevation |
| Root z | `142336` simulation units |
| Initial yaw | `0`, neutral authored model orientation, asset forward −Z |
| Previous root and yaw | Equal to current on this new spawn |

The row is the hall's **south exterior apron**, one tile after its footprint:
hall origin `(58,59)`, extent `12×10`, occupied z=59..68. It is not inside a bed,
room, floor slab or building, and it grants no home assignment. The inherited
2 m tile pitch puts adjacent roots 2048 units apart. The map generation clear
mask must reserve these tiles before resource placement; no extra RNG draw,
resource relocation or entity allocation is introduced by this rule.

The position choice and initial neutral orientation are **new authored starter
values**. Tile scale, axes, land elevation, hall bounds and twelve initial IDs
are inherited. Do not infer a positive-yaw rotation convention for moving actors
from this initial yaw value. Do not assign species from slot order: use the
existing cohort's identities and species data.

This formula has **no definition for ID 13 or above**. Immigration, births,
rescue release, load, teleportation and scenario variants need their owning
placement contracts. In particular, later arrivals must not reuse the assembly
row instead of the already specified map exit `(64,126)`.

## 2. Ownership and publication

1. The settlement owns the single directory-bound Transform store. Presentation
   may read it through existing permitted extraction APIs; it cannot construct
   another authoritative-size pose store or write simulation poses. Movement
   later receives that same instance as its sole pose writer.
2. Validate all twelve candidate identities, transform bindings, unique tiles,
   terrain/elevation, cleared mask and static footprint/resource exclusions
   against the **prepared** world before publishing any generated settlement.
   Validate all inputs before the first placement; a failure on resident twelve
   cannot expose eleven placements. No dynamic-growth fallback.
3. Keep the existing cohort-first directory allocation. Place the prepared
   cohort within the generation transaction and publish world/cohort/poses
   together. A stale identity or capacity/refusal aborts the complete transaction.
4. Add a cold, guarded reset for all nine Transform columns and derived counts.
   New-world reset may restart persistent IDs at 1; consequently leaving old
   `_bound_persistent_id` bytes behind is unsafe even though within-world IDs
   never repeat. Reset poses along with the directory and stores. Load is not
   new-world reset followed by spawning.
5. Preserve a previously valid world on failure as R-INIT-ID-001 already requires.
   Until replacement rollback is implemented, reject creation **before mutation**
   when any world is already published, even when its resident count is zero.
   The existing `resident_count > 0` guard alone is insufficient. An initially
   empty transaction may return to its empty state. Do not allocate a second
   full live world as an undocumented rollback shortcut.
6. `create_initial_settlement()` remains usable as a cohort-only test fixture.
   It does not, by itself, claim a generated map or positioned world. The composed
   generated-world path owns this placement contract and its integration tests.

Use the existing fixed packed layout and generation-checked EntityRefs.
Transform rows remain `base(kind)+typed_row`, not persistent-ID-indexed rows;
IDs order the spawn assignment only. The current `_bound_persistent_id` check
must still reject reused typed rows belonging to a different entity.

For the static initial world, previous=current is sufficient. Preserve
ARCH-SYS-001's tick-start history and single-writer discipline when movement is
composed; this ruling does not add a second `_process` movement loop. Rendering
interpolation can use `Transforms.presentation_interpolate_into()`; the scalar
settlement summary in `presentation_extract.gd` is not the only existing legal
presentation API. Float extraction never feeds an authoritative writer.

## 3. Save and memory consequences

The existing Transform current/previous fields and binding identity are real
simulation state, persisted through their registered owners. Capture reads the
shared store. Restore validates and installs the saved current **and previous**
fields; it must not call `place()` for restored residents, because that destroys
saved history. A presentation-only load snap may display current immediately
without rewriting saved previous state.

Record the starter placement semantic revision in the rules identity inputs;
do not silently accept an older generated settlement with unbound residents as
a valid new-format world. This ruling introduces no new packed field and assigns
no unrelated global save-schema version. Existing format compatibility checks
must reject mismatched rules identities until an explicit migration exists.

The private scaffold owns `87552 × 9 × 4 = 3151872` bytes of packed payload.
That duplicate row may be removed from the allocation ledger **only after the
private allocation is removed**. The simulation Transform allocation already
has its own budget: reconcile actual allocations rather than adding it again.
Retain the crowd instance buffers. Recompute the current complete live and
transactional ledger, including scratch and engine copies. This is a payload
calculation, not a measured RSS improvement or minimum-hardware qualification.

## 4. Acceptance and test migration

- Initial generated world: exactly twelve living residents with IDs 1..12;
  each has the fixture pose above, valid binding and previous=current. Validate
  real prepared terrain/clear/resource ownership, not just copied constants.
- Vary allocation slots and iteration order in isolated fixtures while keeping
  persistent IDs: assignment remains by persistent ID. Generic rendering tests
  supply explicit valid transforms rather than invoke a production muster
  algorithm for arbitrary populations.
- Invalid last candidate, stale reference, occupied tile and published-empty-
  world replacement attempts leave prior authoritative bytes unchanged.
- New-world reset, destruction and typed-slot reuse cannot leak an old pose;
  the reused entity stays unplaced until explicitly placed. A second world
  reusing persistent ID 1 receives only its own newly initialized pose.
- Main scene and renderer read the exact settlement-owned store. A controlled
  authoritative pose change changes rendered origin; camera/LOD changes and
  repeated render frames leave authoritative bytes unchanged. No renderer
  `Transforms.new()` or full-size substitute allocation remains.
- When the §4 codec exists, round-trip a resident whose previous and current
  differ; preserve both and its binding. Until then, label this codec test
  BLOCKED, not covered by a store-only copy test.
- Migrate useful tests from `test_resident_pose_scaffold.gd` to composed-world
  placement tests; retire only the private-store ownership and arbitrary-population
  muster assertions, with reasons in the task's old-test ledger.
- Capture the actual main scene at supported profiles. Record the remaining
  white bind-pose/species-material limitations rather than call this art complete.

No physics body, NavigationAgent or AnimationTree per resident is introduced.

## 5. What remains open

Root placement on cleared terrain is not a measured body/gear envelope or a
swept-placement proof. MOVE-G01–05 remain open to their existing extent;
swimming, diving, tunnels and connected canopy access remain adopted scope.
This ground starter fixture cannot certify physical clearance, two-metre crowd
spacing, route admission, collision avoidance, turning, rigs or work contacts.
Do not use it as a successful clearance query while profile readers still refuse.

The repository already has Building, Room and Furniture stores. Their absence
is not a valid blocker description; missing **starter instances and integration**
are. This change does not create the hall, beds, pantry, initial lots, work jobs,
arrivals, playable colony, save orchestrator or production creature art.

Implementation task: `RENDER-SPAWN`, after `BASELINE-INTEGRATION`; see the
[Cycle 1 handoff](../planning/astra_cycles/cycle_01.md).
