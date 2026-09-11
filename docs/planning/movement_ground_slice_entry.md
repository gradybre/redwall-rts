# Movement ground slice — task 05.1a entry artifact

Status: **implemented and tested for the baseline surface fixture only.** Prepared 2026-09-11.
Authority: [READY_07 §1.1–§1.3](../rulings/2026-09-11_ready07_open_item_answers.md),
[ADR0020](../decisions/0020-movement-gates-close-in-dependency-order.md),
[movement contracts](movement_contracts.md), [task 05](../tasks/05_movement_first_playable.md) §05.1a.
Engineering record: [decision 0053](../decisions/0053-movement-ground-slice-identity-and-storage.md).

**This closes no MOVE gate.** Task 05.1a asks for a reviewed ground/shared-interface slice that
records its adopted inputs, typed handles and sentinels, supported ground profiles and contacts,
baseline-only capacities and bytes, transaction and refusal semantics, and save obligations. That is
what follows. Full G01 still precedes full G02 binding and closure, and the
[G01 parameter pack](../rulings/2026-09-11_ready07_open_item_answers.md) (§1.3) is still owed.

## 1. Adopted inputs, unchanged

| Input | Source | Used as |
|---|---|---|
| 256 m square, 128×128 exterior tiles | GDD §5.1 | 512×512 half-metre cells, `cell ID = z*512+x` |
| Coast z=0..15, river x=76..78 z=16..127, lake `(x-100)²+(z-66)²≤14²` | GDD §5.1 via `world_init.gd` | Static walkability, read not copied |
| **The ford, river tiles z=48..51** | GDD §5.1 | **Walkable, y=−128, and in no fish basin — it is not a fishing work tile** |
| Surface heights 512 land / −128 ford / 0 water | GDD §5.1 | The `y` a travelling body is given each tick |
| N,E,S,W,NE,SE,SW,NW; 10/14; corner blocking; `10*(dx+dz)−6*min(dx,dz)` | ARCH-PATH-002 | The ground A* exactly |
| 2048 finalized expansions per tick, shared | ARCH-PATH-002/004 | One global budget across local-entry, exact-route and reference-start searches |
| 16×16 macro cells, bucket key `(start_macro, goal_cell, clearance_class, map_revision)` | ARCH-PATH-003 | The route cache, including exact-start variants |
| 256 descriptors, 1048576 route cells, `(last_use_tick, cache_id)` eviction | ARCH-PATH-005 | The bounded arena; referenced routes are never evicted |
| `EntityRef = (slot:i32, generation:i32)`, null `(-1,0)` | GDD §4.1 | Every contact owner and requester |
| Positions int32 in 1/1024 m; yaw 65536 units per turn | GDD §4.2, ARCH-AUTH-002 | Transform storage |
| Speed caps 3277 / 4096 / 3072 u/s by size | GDD §5.2 via `residents.gd` | Read, including the deliberate large-is-slower anomaly |
| `a = remainder + speed; distance = floor(a/30); remainder = a mod 30` | SET-MOVE-001 §5 | Retained-remainder integration, on a uniform `30×14` scale |
| Speeds 0/1/2/4, 30 ticks/second | GDD §5.1 | Tick cadence only; a tick's content never depends on the speed |

Nothing in the list above was invented here. §6 lists what was refused.

## 2. Ground location identity — the facts READY_07 §1.2 requires stated

**A ground location ID is a baseline cell index associated with a declared domain, a declared layer
and the world/map revision it was minted against. It is NOT a universal multi-level location.**

- The public record is `spatial_world.Location`: `domain, layer, revision, cell, owner_slot,
  owner_generation`. Both owner halves travel together and are compared together.
- **No public API in this slice takes a bare X/Z pair as a destination.** `submit_request_into()`
  takes two `Location` records and a requester reference. Two floors, a submerged column and a
  canopy branch can share an X/Z, so a cell names a destination only inside
  `(DOMAIN_GROUND, LAYER_SURFACE)`.
- `DOMAIN_GROUND` and `LAYER_SURFACE` are the only contracted values. Any other refuses
  `DOMAIN_NOT_CONTRACTED` or `LAYER_NOT_CONTRACTED`. **One floor is not a substitute for multilevel
  scope**; depth, elevation and per-domain cell budgets are MOVE-G01 outputs.
- The field shape is the one SET-MOVE-001 §2 proposes for dynamic Location/Connection directory
  kinds, so the shared boundary is preserved for later domains rather than rebuilt.
- The map revision is positive and monotonic. This fixture carries it in an int32-width record and
  **refuses `MAP_REVISION_EXHAUSTED` rather than wrapping**; widening to SET-MOVE-001's i64 is a
  MOVE-G02 output.

## 3. Supported ground profiles and contacts

**There are no production profiles, and this slice does not create any.**

- Static legality is derived per cell from the authored terrain. Clearance is **map geometry only**:
  the side of the largest all-passable square anchored at the cell, in half-metre cells.
- A **clearance class is a caller input** on every routing call. `spatial_world.gd` publishes no
  body, posture or gear clearance number, and nothing here is written into an active gameplay
  catalog.
- **Exact production body and gear clearances remain a profile decision.** Neither the 1.0 m mouse
  scale anchor nor a size-speed category determines them. Therefore: **reference routing with a
  declared synthetic clearance class is unblocked; ordinary resident travel cannot be declared
  correct until starter profiles and contact clearances are specified.** The suite uses synthetic
  classes (1, 4, and the map-width class as a negative) and publishes none of them.
- A contact is `(Location, owner EntityRef)`. Owners are validated at submission and **revalidated
  at service time**, both halves together, into distinct `STALE_START` / `STALE_GOAL` /
  `STALE_REQUESTER` phases.
- **Work arrival, contact reservation and the 30/300/900-tick lease rules are not implemented.**
  READY_07 §1.2 places them after starter profiles, services and WU context. Nothing in this slice
  writes a job state, and `JOB_STATE_WORK` appears nowhere in it.

## 4. Baseline-only capacities and bytes

Reused from the existing ledger, for this bounded fixture only:

| Allocation | Rows | Bytes | Ledger row |
|---|---:|---:|---|
| Static navigation map (walkable, layer bytes; terrain, height, clearance i32) | 262144 | 3670016 | §2.3 existing |
| Active A* builder (g, parent, heap, heap_position, stamp i32; state byte) | 262144 | 5505024 | §2.3 existing |
| Route cell arena | 1048576 | 4194304 | §2.3 existing |
| Route descriptors (16 i32) | 256 | 16384 | §2.3 existing |
| Path request records (16 i32) | 8192 | 524288 | §2.3 existing |
| Resident motion scratch (16 i32) | 512 | 32768 | §2.3 existing |
| Transform, eight i32 including previous | 87552 | 2801664 | §2.2 existing |

**Every new identity, index and revision field, enumerated:**

| New §3 table | Columns | Rows | Bytes |
|---|---|---:|---:|
| TransformBinding | `bound_persistent_id` | 87552 | 350208 |
| PathRequestContact | `start_owner_slot, start_owner_generation, goal_owner_slot, goal_owner_generation, requester_persistent_id` | 8192 | 163840 |
| ResidentRouteCursor | `request_row, route_generation, route_cell_index` | 512 | 6144 |

Total **+520192**. Planned payload 60256806 → **60776998**; one world plus reserve **69165606**;
headroom **30834394**; rejected two-world peak **123727020**, over by **23727020**. Applied to
`systems_architecture.md` §2.3, §3, ARCH-MEM-006, ARCH-MEM-009, ARCH-MEM-010, §3.1 and
ARCH-CONFLICT-011, and pinned in `docs/validation/ready07_arithmetic.py`.

**No duplicate full world and no silently resized array is hidden in a temporary navigation layer.**
Every packed column is allocated once in `_init()`; nothing calls `resize()` afterwards; the A*
builder is self-clearing by search stamp rather than by reallocation; and the route arena is
compacted in place, never grown.

## 5. Transaction and refusal semantics

- **Nothing returns a sentinel to signal failure.** Reads use `int_math.gd`'s `IntResult` `_into`
  form and refuse with a `StringName`; predicates such as `is_walkable_cell()` are predicates, not
  error channels. `-1` appears only as an internal absence inside a module, never across a public
  boundary.
- Request states are distinct and non-overlapping: `QUEUED`, `SEARCHING_LOCAL/FULL/VARIANT`,
  `READY`, `UNREACHABLE`, `BLOCKED_ROUTE_STORAGE`, `STALE_REQUESTER/START/GOAL/REVISION`,
  `CANCELLED`. **A quota-interrupted search is pending and has proved nothing**; only an emptied
  open set is `UNREACHABLE`; a found route with nowhere to live is `BLOCKED_ROUTE_STORAGE`.
- An incomplete search exposes no traversable prefix: reading a route from a non-`READY` request
  refuses `REQUEST_NOT_READY`.
- A new map revision retires every route built before it, settles its holders as `STALE_REVISION`
  and compacts the arena at the service boundary. The endpoint records carry the old revision, so
  re-approving them is their owner's act, not a silent re-search.
- `override_static_legality()` is the fixture's **only** legality mutator: whole-map, immediate,
  non-transactional, and sufficient only to exercise revision invalidation. The production edit
  path — bounded overlay, reserve, evaluate, stage, publish together at a tick boundary, refuse on
  occupied exits — is `topology_edits.gd` under task 05.6 and is **not** implemented.

## 6. Values deliberately refused

| Refused | Why | Owner |
|---|---|---|
| Any body/posture/gear clearance value | READY_07 §1.2: a profile decision, not derivable from scale or size class | MOVE-G01 |
| Yaw zero direction and turn handedness | ARCH-AUTH-002 fixes the scale only; movement derives no facing and carries yaw through | MOVE-G01/G04 |
| Turn and segment entry/exit costs | Would be needed to absorb the per-tick budget a mid-tick turn leaves unusable | MOVE-G01 |
| Body radius and separation strength | `radius_u` and `correction_*` stay zero | MOVE-G01 |
| Any second domain, layer, depth or elevation bound | Diving, canopy and underground each need their own completed contract | MOVE-G01 |
| A short-trip threshold to avoid the macro anchor detour | Fixing it requires a policy and a number; the detour is measured instead | ARCH-PATH-003 |
| A save schema version number | No canonical serializer exists to version against | Save owner |

## 7. Save obligations — recorded, and **BLOCKED**

ARCH-PATH-006 and SET-MOVE-001 §7 require the following to be serialized. **None of it is written
to disk, because there is no canonical serializer to add a versioned section to, and an in-memory
clone cannot substitute. The round trip is blocked, not deferred quietly.**

- The complete in-progress search: heap contents and size, parents, g-scores, state stamps, the
  search serial, the active request, its stage, its macro constraint and its consumed quota.
- Every request record and its contact row, its phase, and the queue linkage order.
- Every route descriptor: ID, generation, all key fields, arena offset and count, reference count,
  last-use tick halves, flags and variant links — plus the exact route cells and the arena's
  committed extent, so eviction and readiness decisions are restored rather than recomputed.
- The map revision, and the derived clearance column's dirty state.
- Every Transform row's current **and previous** eight fields, plus `bound_persistent_id`.
- Every motion row's sixteen fields, **including both retained displacement remainders**, and the
  route cursor. Losing a remainder is a silent speed change, not a rounding difference.

`authoritative_digest()` exists on the Transform store so a future parity test compares whole
committed state rather than a handful of fields.

## 8. What this artifact does not claim

- It is **not** FP-01–12 acceptance. A headless routing fixture is not the first-playable checkpoint
  and is not described as one.
- It closes **no** MOVE gate, and grants no expanded capacity.
- It reports no measured performance. The 0.25-real-second route-ready target and REQ-SET-163
  belong to MOVE-G05 with real hardware evidence.
- It does not replace multilevel scope with one floor.
