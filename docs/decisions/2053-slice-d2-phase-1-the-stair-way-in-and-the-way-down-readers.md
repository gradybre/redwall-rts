# 2053 — Slice D2 phase 1: the stair way in and the way-down readers

Date: 2026-10-20 · Status: Built (phase 1 of decision 2052; Brendan, 2026-10-20, "Approve, start phase 1"). Branch
`feat/slice-d2-phase1`, cut from `docs/slice-d2-scoping` (origin/master `d41269dd`). Number range 2052–2060 and
2062–2069 (decision 2052).

## Decision

Phase 1 builds, in new files only, the two pieces decision 2052 §5 names, and proves them on the claw Kitchen fixture
(decision 1939) through the real Confirm route (decision 1991). Nothing binds them in the game or the demo yet: the
host binding at the entry's completion and on load is phase 2 (after M5), and the demo switchover is phase 3 (after
stair-leg Delivery).

| Piece | File | Rule |
|---|---|---|
| `Foot`, `StairWayIn` (extends the seam's `WayIn`) | `scripts/core/underground_way_in.gd` (new) | 2052 §2.1; P-2052-2 (a) |
| The front station: geometry, publication, withdrawal | `scripts/core/underground_way_in_front.gd` (new) | P-2052-1 (a) |
| The landing and shape readers | `scripts/core/underground_way_landings.gd` (new) | 2052 §2.3 |
| Tests | `test/test_underground_way_in.gd`, `test/test_underground_way_landings.gd` (new) | |
| Registry rows (category 3, stateless) | `docs/persistence_state_registry.md` | C1 |

No file held by M5 (decisions 2044 and 2045), stair-leg Delivery, 2b-2 or Slice C is edited; `flight_geometry.gd`,
`underground_room_station_retirement.gd` and the confirm route are only read or called.

## 1. The way in

`StairWayIn.approach_into(request, order)`:

1. **Only the foot's level.** Any other level, or an unconfigured way in, returns the seam's own
   `ROOM_DIG_NO_WAY_IN` ("No way in: needs a way down to level N") before anything is touched.
2. **The front station** (P-2052-1 (a)), from `underground_way_in_front.gd`:
   - For each heading the Foot offers (a wall row and its forward travel row, which must walk at the wall row's yaw,
     the approach's own rule), the wall row's published CONTACT_PATCH gives the planar axis and its reach.
   - The room's cells are tried nearest the access first (by cell centre, ties by cell order). A cell is used when
     the cell on the station's side is not the room's, it is on the access's floor, the patch lies exactly on its
     face and inside the cube, the forward row's body at the station and at its corner lies in the access's surveyed
     air and off the room, and the station lies ahead of the corner.
   - The station stands on the cell's centre line, `reach` in front of the face. Its corner is the point on the
     access's own line (the access itself when they line up). This is exactly C3's hand-made fixture shape
     (decision 1991 E12): on the claw Kitchen the way in finds the Kitchen's existing station, and for the northern
     room publishes the station at `NORTH_STATION` and the corner at the corridor point C3 used.
   - Publication goes through Locations' and WorldRoutes' staging calls, as parking does. Any live endpoint of the
     same role at the point, and any span already joining two endpoints, is reused, so ordering the same room again
     publishes nothing. The forward row must then reach the station from the corner and the retreat row the corner
     from the station (`Itinerary.reachability_refusal`).
   - What one call published is listed (`pending()`). A refusal inside the call withdraws it at once, through
     decision 1942's two publications. After a successful call the caller **settles** it once RoomOrders has ruled
     (`settle(admitted)`): an admitted room keeps the front its approach stands on, a refused one's is withdrawn.
     Until then the next order is refused `WAY_IN_UNSETTLED`, so no published front is ever forgotten (review H2).
3. **The store and the spoil pile** (P-2052-2 (a)): one ground staging each on a STORAGE endpoint at the Foot's
   points, joined to the access by a straight span each way. Each of the endpoint, its spans and the container is
   made only when missing, so a new way in over the same Foot (as after a load) finds both.
4. **The order's way in is always the Foot's** access and retreat row, and its staging is the Foot's (the surface R;
   none in the fixture). The request's Space revision is read again after publication.

**Engineering choices.**

- **E1 — The station's footing holds the wall row too**, with both travel rows, as a planner's WORK station's does
  (decision 1161, `_records`). With the travel rows alone the first dig refused `WORLD_ROUTE_ENDPOINT_SUPPORT`.
- **E2 — The station stands on the cell's centre line**, not with the patch centred: the claw wall row's patch is
  asymmetric (z −225..211), and the centre line is where the Kitchen's own station stands.
- **E3 — No ground-row reachability check** for the corner, the store or the pile: `Itinerary` admits only a
  source family's rows (`ROOM_ITINERARY_SOURCE_FAMILY` for the all-yaw row 42). WorldRoutes' seal certifies which
  rows walk those spans, and the dig proves the route end to end.
- **E4 — The refusal codes** are `WAY_IN_SCOPE` (an incomplete Foot or owners, named apart from the confirm route's
  `REFUSE_SCOPE`, which the inner class would otherwise inherit through the `WayIn` base), `WAY_IN_NO_FRONT`,
  `WAY_IN_FRONT_UNJOINED`, `WAY_IN_CONTAINER` and `WAY_IN_UNSETTLED`. The panel's words for them are
  phase 3's.
- **E5 — Envelopes are the access's surveyed air**, as parking's are. At M5's foot the bottom F′'s envelope may not
  reach a room's front: that is decision 2052 §6's phase 2 probe (rows 4 and 8), and the station's envelope would
  then follow the planner's profile-air rule instead.

## 2. The readers

`underground_way_landings.gd` (stateless) derives, from the entry origin, the Sites datum and the mounted layout:
`landings_into` (level 1 only: the last row's two cells) and `shape_into` (the surface: the Stair-head's quad at turn
0). A layout whose last row is not one whole level down (the M2 interim) lands nowhere. A test holds the cells equal
to D1's `build_connector_families.gd` Stair-head at the derived anchor, and the flight's row count and width equal to
the panel's, so the two cannot drift apart.

## 3. What phase 2 inherits

- Deriving the Foot from the finished M5 entry (F′ at landing 5, the claw rows at the flight's heading, the store
  and pile points beside F′), binding it at completion and after the entry's restore, and calling
  `settle(result.admitted)` after every `UndergroundRoomConfirm.confirm` in the host's `order_painted_room`.
- **Reusing an endpoint by its point** (review M3): a corner or station at the point is reused whatever routes
  already touch it. On the claw Kitchen that is the Kitchen's own station, joined only to the access. At M5's foot
  a reused endpoint could be another chain's TRANSIT node, which decision 1942's retirement may later remove; phase 2
  adds parking's `_routed_elsewhere` guard (spans only to the access, the corner or the station) with the live
  probe, and lists the spans a call publishes as well as its endpoints.
- **One heading per World for now.** The room contacts bind one retreat row (P-1936-1 (a)), and the retreat row has
  a yaw; a Foot offers only headings whose rows go with it. More headings follow Slice C's multi-heading lane.
- A front station stays published after its room is dug; it is reused if the same front is asked for again. Its
  retirement with the room's own stations is phase 2's, measured against Locations' capacity.

## Review

One independent `code-reviewer` pass on the phase 1 diff: no CRITICAL, two HIGH, six MEDIUM, six LOW.

| Finding | Outcome |
|---|---|
| H1: HEAD at `c357df7f` did not load the test file | A misreading: the five-argument `place` and the tests calling it landed together in `e8c8af05`; `c357df7f`'s tests never called `place`. Every gate ran on the later heads |
| H2: a published front forgotten across calls, or after Confirm refuses past the way in | **Fixed**: `settle(admitted)`, `WAY_IN_UNSETTLED`, and a refused withdrawal is passed on. Tests: an unsettled front refuses the next order and `settle(false)` removes it; the real route with RoomOrders refusing the room after the front is published leaves nothing once settled |
| M1: a station could stand on its corner | **Fixed** (`<= 0`); tested, on and one unit behind |
| M2: refusals collapse into `WAY_IN_FRONT_UNJOINED` | **Answered**: the reason is the publication's (Locations, WorldRoutes or the lease), and none changes what the caller does. A test holds the cold lease and proves nothing is left. The unused `WAY_IN_POINT_TAKEN` was removed. Carrying the owner's code is phase 2 work if the panel needs it |
| M3: reuse by point without parking's route guard | **Deferred to phase 2**, recorded in §3 |
| M4: "leaves with the room's other stations" not built | **Recorded** in §3 (phase 2); the north dig test now asserts the station stays while its room is dug |
| M5: helpers copied from `underground_room_parking.gd` | **Answered**: parking is Slice C's file. Extracting a shared helper edits it, so it waits for a Slice C clearance; the copies are named and documented |
| M6: `owners` typed `RefCounted` | **Fixed**: `Builder.Owners` throughout. `foot` stays `RefCounted` there, because the way in preloads the front file |
| LOW: a cell past int32 | **Fixed**: `cell_in_range`, tested |
| LOW: `_floor_div`'s exact negative multiple | **Tested** (x -1,024 is cell -1) |
| LOW: `Foot.refusal`'s docstring; `span_pair`'s lease when both spans exist | **Fixed** |
| LOW: `space_revision` overwritten; `ClawWayIn` still in C3's suite | **Answered**: overwriting with the current revision is what admission needs. `ClawWayIn` is C3's test and stays; the production class is proved here |

## Gates

- **Full suite, CI-style** at `555599b5` (no demo art in this worktree; `godot/.godot` deleted and re-imported,
  exit 0; `./tools/run_tests_parallel.sh --jobs 4`, master's 10 shards): every shard and the verify passed,
  `ok: 568 suite files executed exactly once across 10 shards`; 13,150 tests, 1,544,779 assertions, 0 failures,
  0 unexpected errors or warnings (289 expected, 456 tolerated), 0 leaked objects or resources; 1,990 s. (A first run
  at `fa5d3aa2` passed every shard but its verify refused "shards used different manifests", because a test file
  was edited while it ran; it was rerun untouched.) The last commit after it reorders two assertions in one test,
  and its two suites pass: 33 tests, 249 assertions, 0 failures, nothing unexpected or leaked.
- **Analyzer** (`tools/gdscript_warnings.py --max 0 --port 6513`): `0 GDScript warning(s) in 0 of 1664 file(s)`.
- **Contracts:** `decision_numbers.py` PASS (583 records); `ready07_arithmetic.py`, `merge_gate.py`,
  `setting_contract.py`, `dispatch_plan.py --validate`, `astra_inbox.py --check`,
  `validate_save_registry_handoff.py`, `generate_canonical_state_table.py --check`, the cycle 1–3 handoffs,
  `audit_registry_capacities.py --check`, both schema checks, `lane_notes.py --check`,
  `state_registry_coverage.py` (211 modules) and `underground_memory_budget.py --check` pass;
  `test_underground_current_census.py` 15 tests OK. No byte is added to the census: every new store is category 3,
  and what the way in publishes lives in Locations', Routes' and Inventory's existing bounded banks.
- **Mutation testing** (`scratchpad/d2mut/run.py`, one mutant a run, against the two suites, in a separate
  worktree): 48 mutants over the way in, the front and the readers; **42 killed** (four first-pass survivors were
  killed by the tests added for them). **Six survive, each explained:**
  - F2, the WORK-mode check dropped: every content-12 row with a horizontal planar contact patch is a WORK row, so
    the patch check refuses the same rows;
  - F19, `span_pair`'s per-direction "already spanned" skip dropped: `span_pair` now returns early when both
    directions exist, and this file never publishes one direction alone;
  - F20, a corner sought even when the station lines up with the access: `existing` then returns the access itself
    (TRANSIT accepts the access's STORAGE role), so the result is the same;
  - F21, the forward and retreat reachability checks dropped: no fixture publishes spans that WorldRoutes' seal
    certifies but the rows cannot walk; the checks stay as the guard parking has;
  - W3, the request's Space revision not re-read: publishing Locations and Routes does not move the Space owner's
    revision in this fixture; the line keeps admission fresh if it ever does;
  - L1, `==` to `>=` in `reaches_level`: no published layout goes deeper than one level.
- **Independent review:** one `code-reviewer` pass; see "Review". Both HIGH answered (H1 a misreading, H2 fixed),
  MEDIUM fixed or answered.
- **Frames:** none; phase 1 draws nothing.

## Source

Decision 2052 and Brendan's rulings on it (2026-10-20); decisions 1161, 1936, 1939, 1942, 1991; SET-BUILD-001 §9;
the code cited at origin/master `d41269dd`.
