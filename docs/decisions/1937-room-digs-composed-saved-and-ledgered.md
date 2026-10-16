# 1937 — Room digs composed, saved and ledgered (slice C2.3)

Date: 2026-10-16 · Status: Built, with three named gaps for the coordinator (§6). Build record of decision 1936
(Brendan, 2026-10-15: "Approve all").

Branch `feat/room-foreman-c2-3`, from `114e4acf`. Number range 1931–1949 (decision 1931).

## Decision

C2.3 is built as decision 1936 scoped it, with the choices and findings below. Everything Brendan ruled is (a):
contacts from the first ordered room's access (P-1936-1), one builder per room now (P-1936-2), the walk-out
(P-1936-3), save and load now (P-1936-4), the 512-box cap (P-1936-5) and ADR 1219's walk-in rule (P-1936-6).

## 1. The composite dispatcher (review H4)

`underground_dispatch.gd` is Jobs' one dispatcher from the mount on. It owns what either runtime owns and reserves
whom either reserves; it keeps no state but the host's two runtime readers. The entry's `_bind_dispatcher` (the one
cleared edit) leaves the composite in place. The room runtime owns every Job an excavation phase Project requests
(read from saved Jobs and Construction), so a dig's Jobs stay off the JobSelector between cubes, after a stop and
across a load. It reserves a builder while its dig runs and for as long as the builder is still underground.

## 2. Composition in the game and the demo

`compose_underground_room_owners` builds the runtime (its 475,136 B record allocated whole);
`compose_underground_entry_owners` binds the Session's owners it borrows. `order_underground_room` takes an
`UndergroundRoomComposer.Order` (room, access, retreat row, storage, spoil and staging containers). The composer:

- binds the room phases' contacts the first time, and refuses a room on another access (`ROOM_DIG_OTHER_ACCESS`)
  until a per-access binding exists;
- picks the first living adult mole by slot that holds no Job and no tool, is not seeking food or rest (DEC-059)
  and is reserved by no dispatcher (the entry's `_idle_mole` rule);
- queues the room, parks the builder and starts the dig. An order whose parking or start is refused forgets the
  queued record (`cancel_queued`), so no room is left QUEUED for good.

**No level has a way in yet (slice D),** so in the running game an order is refused by the contacts' own binding,
named and alerted, and nothing is bound or recorded. The demo mounts through the same host and needs no edit.
Nothing orders a dig until C3 (P-C2 (c)).

**Parking.** `underground_room_parking.gd` tries 2 and 3 quanta off the access in the four directions, ordered away
from the room's cells. A candidate's body must lie inside the access envelope and off the room's box, and its
point must be free. It reuses a TRANSIT or STORAGE endpoint already at the point; otherwise it publishes a new
TRANSIT endpoint (footing from the stance-support boxes) and two WALK spans through the staging calls, and keeps
it only if the travel rows reach it both ways. Published endpoints and spans are Locations' and Routes' own saved
state.

## 3. Walk-in, walk-out and resume

- **Walk-in (P-1933-1 (a), P-1936-6 (a)).** ADR 1219's timed teleport: `ceil_div(D × 30, v)` ticks at the
  builder's Movement speed, then placement on its parking and registration. No work moves until the whole crew has
  arrived: registering a second builder on a started phase is refused `ROOM_PHASE_WORKER`.
- **Walk-out (P-1936-3 (a)).** A finished or stopped dig's builders leave once they rest on an endpoint
  (`unregister_resting_actor`, or `unregister_lost_actor` for one that died or left: underground-ness is Routes'
  own `_lost_actor_row`, as the entry foreman reads it), then walk the timed walk in reverse. A builder stopped
  inside a WORK source first asks the source for READY and leaves when it gets there; until then it stays
  reserved. A builder still walking in when the dig stops never arrives (its body never moved).
- **Arrival out is a foreign pose change.** Placing the walked-out resident bumps Transforms' mutation revision, so
  the builder rebuilds Routes' occupancy roots at once (`refresh_occupancy`). Without it every builder still
  underground was held (`ROUTE_OCCUPANCY_STALE`) and never reached READY: a two-builder stop hung for good.
- **A finished or stopped dig forgets each builder once it is out** (`shed_crew`). It keeps only the builders still
  underground, exactly as the save writes them, so nothing it keeps can act on a resident another dig picks next.
  A STOPPED record stays until `release_room` (its code is the alert's, and a re-order resumes its paid phase). A
  DONE record releases itself once its crew is out (review M-b, the coordinator, 2026-10-16), so finished rooms
  never fill the 512 kept records. A re-order, including a new room on the same
  directory row, is refused `ROOM_DIG_CREW_OUT` while a builder is still underground.
- **Resume (P-1933-2 (a)).** A re-ordered room's cube with a live, started phase is taken first: the builder takes
  the Site's bound Job, walks to the station, and continues the paid work through Sites' `resume_phase_work`
  without a second payment. Frontier refuses a live project (`ROOM_FRONTIER_EXISTING_PROJECT`), so
  `underground_room_frontier.gd` gains `resume_contact_into`: the same contact search for that Site's own WORKING
  or WORK_DONE phase. **This file is outside the listed lane files; it has no active owner.**

## 4. Save and load (P-1936-4 (a))

- Section 6 owner `underground_room_progress`: registry v17 (`RWL-CANONICAL-REGISTRY-2026-10-15-RD1`), section 6
  schema 11, 26 owners, 812 canonical records. `progress_length` (u32) and `progress_record` (u8, at most
  `MAX_WIRE_BYTES` = 1,198,536) are hashed.
- **The twelve category-1 packed columns** (the runtime's five record columns and `_foreman_rows`, the foreman's
  `_cube` and `_blocked_at`, the builder's `_legs`, `_leg_profiles` and `_queue`, the footprint's `_body`) are
  declared hash-free inside the record, with a length each, as decision 1218 declared the hauler's `_queue`.
  Source contract C202; 706 packed source fields. The adapter refuses a block that carries any of them.
- The codec (`underground_room_progress.gd`, "RMDP" v1) writes only rows in use, each kept foreman (state, codes,
  ledgers, latch, epoch, context; while running its order rows and marks; the builders it keeps, each after its
  blocked epoch) and each builder (crew, cursor, the four
  leg lists, the cube plan, the walk, the haul plan and ADR 1218's unchanged hauler block). Footprints are swept
  again from the saved cube plan, so no box is saved; keys, extents and per-tick flags are re-derived.
- A decoded record must re-encode to the same bytes (`ROOM_SAVE_NONCANONICAL`). Restore goes into a fresh runtime
  whose owners the re-mount bound, after the entry's record, and then binds the contacts again.
- **Parity (ARCH-SAVE-006).** On the Kitchen, restoring before every tick ends byte-identical to the uninterrupted
  run for one builder, a haul, two builders, a stopped dig and a stopped pair whose builders leave one by one. Two
  row blocks swapped (each in range) are refused `ROOM_SAVE_NONCANONICAL`. Through the real save path, a queued record
  round-trips and the loaded settlement saves byte-identically. No migration (DEC-055 item 1): an older save loads
  with the owner canonical-empty.

## 5. Memory (DEC-053 gate, 150,000,000 B)

The current-source census counts `room_dig_runtime` from exact member sets at every bound at once:

| Row | Bytes |
|---|---:|
| Record, 16,384 rooms × 29 B | 475,136 |
| Runtime controls (512 foreman rows, scratch, work face) | 2,075 |
| 512 kept foremen | 49,664 |
| Every Site in an order, with its mark (73,909 × 13) | 960,817 |
| 256 builders, each with a full plan, 512-box footprint, 256 profile rows' extents, walk and haul (20,623 B each) | 5,279,488 |
| Two record images at `MAX_WIRE_BYTES` | 2,397,082 |
| **Total** | **9,164,262** |

With the declaration's +729 B, live is **109,415,598 B** and the **headroom is exactly 40,584,402 B** (it was
49,749,393). The 256 builders are a true bound because a resident builds in one dig and a finished or stopped dig
forgets each builder once it is out (§3). Decision 1936 estimated about 5.26 MB; the difference is the two record images (2.4 MB, charged as
ADR 1218's are) and extents charged at `MAX_PROFILES` = 256 rows rather than one content's 67.

**Decision 1880's columns are not folded:** this lane allocates none of them. Folded, the headroom would be
23,626,962 B. **Decision 1880 Q1's projection now overshoots.** It left 1,416,593 B after the painted-room budget
and the adopted projects and containers (23,265,280 + 8,110,080). With this runtime counted, that projection is over
the gate by **7,748,398 B**. `ready07_arithmetic.py` pins the shortfall; it is not an allowance. Slices C and G
cannot ledger that bound as it stands without a ruling (§6).

## 6. Named gaps for the coordinator

1. **Resume needs the cost lane.** The room bindings refuse a new worker on a started phase (`_ordinary_needs_worker`
   is true at STAGE_START and STAGE_WORK; `ROOM_PHASE_WORKER`). That check is in `worker_refusal`, which the cost
   lane owns. So a builder that replaces a lost or departed one cannot take its paid phase over until that lane
   admits it. `test_a_paid_phase_left_by_a_lost_builder_is_taken_over_up_to_the_room_bindings` pins the gap.
2. **The memory shortfall in §5** needs Brendan: shrink a bound (fewer kept records, a smaller box cap, extents at a
   content's own row count, one record image), or revisit decision 1880 Q1's projection.
3. **The Claw Kitchen fixture is not built.** The Kitchen loop fixture is content-6-specific in about fifteen
   places: the catalog wire and its five rows, the anchor and WORK rows, the 232 u step geometry and DEC-054's
   8-cube clamp. Content 11 is not runtime-admitted. So these cases stay deferred to a fixture of their own:
   - the turn after a haul;
   - a column haul;
   - two builders hauling;
   - the composer's claws builder digging end to end. On content 6 it is refused `PROFILE_VARIANT_UNAUTHORED`,
     and the composer tests run the pick mole to prove the dispatcher.

## 7. Other choices

- **Kept records are bounded** at `MAX_KEPT` = 2 × `MAX_DIGS` = 512. Ordering past it is refused
  `ROOM_DIG_CAPACITY`.
- **The footprint is capped** at 512 boxes (P-1936-5 (a)). A plan that overflows it, or a plan list over its save
  bound (16 legs, 32 trip edges), is refused `ROOM_BUILDER_FOOTPRINT_CAPACITY` before it sets off.
- **`release_room` waits** while the crew is out (`ROOM_DIG_CREW_OUT`).

## 8. Review and mutation testing

**Independent review** (code-reviewer agent, adversarial, on `2dbcb5c0`; re-checked on `b773173b`). No CRITICAL.
Seven HIGH, all fixed and confirmed:

| Finding | Fix |
|---|---|
| H1: a stopped dig's kept builder could unregister and move a resident another dig had picked | `shed_crew` (§3) |
| H2: re-ordering a reused row dropped a foreman whose crew was still underground | `ROOM_DIG_CREW_OUT` |
| H3: every resume leaked the taker's Job assignment | a refused Sites release first frees the Jobs assignment; only a `REFUSE_WORKER` refusal does so for a started phase (review M-c) |
| H4: a stopped two-builder dig could save a record that does not load | `shed_crew`: the save holds only builders still underground |
| H5: a departed builder's route actor was never removed | `_lost_actor_row` |
| H6: the census undercounted builders kept by stopped digs | `shed_crew` makes 256 a true bound |
| H7: a refused start left the room QUEUED for good | the composer's order is atomic (`cancel_queued`) |

Fixed with them: M2 (a builder walking in at the stop never arrives), M4 (a swapped-row record is refused
`ROOM_SAVE_NONCANONICAL`), M6 (`_blocked_at` and `_body` declared). The hang that the two-builder stop test exposed
(`ROUTE_OCCUPANCY_STALE` after the arrival out) is fixed by `refresh_occupancy` (§3).

**Open, MEDIUM and LOW (recorded, not fixed here):**

- **Fixed afterwards (the coordinator, 2026-10-16):** M-a (while a dig is kept the runtime retries one occupancy
  refresh each tick until Routes is current), M-b (a DONE record releases itself once its crew is out; STOPPED
  records still wait for `release_room`, and 512 of them would still refuse orders) and M1 (READY is requested and
  awaited under the Job and row the actor actually holds, and a wait to leave is named once,
  `ROOM_BUILDER_STUCK_UNDERGROUND`, at `STAGE_TICK_LIMIT`). Mutants N1-N3 are killed. The actor-Job change
  itself is deferred: it needs a stop between a hand-over and READY.
- **M3.** Load range-checks only some cursor fields (`_index`, `_operation`, profile rows). The cross-record
  invariants (a DIGGING row has a foreman, foreman state matches record state) are not re-proved.
- **M5.** A parking whose spans publish but never join adds two spans on every later order.
- **M7.** `reserves_resident` scans every kept foreman for each resident Jobs evaluates.
- **LOWs:** the contacts bind before the builder is picked; walk-out codes alert every tick; the haul queue's bound
  is implicit in today's bill; stale comments.

**Mutation testing.** A scratch runner applies one mutant at a time and runs its focused suites. 78 mutants over
the dispatcher, the runtime, the foreman, the builder, the walk, the cube plan, the parking, the composer, the codec,
the save adapter and apply, the host and the Frontier's resume contact. **68 are killed.** The first pass left 33
survivors; 23 of them were killed by new focused tests (`test_underground_room_parts.gd`, plus additions to the
composer, session, runtime, builder, crews and progress suites). **4 are equivalent and 6 deferred:**

| Mutant | Verdict |
|---|---|
| R9: `_crew_busy` without its skip of builders that are out | **Equivalent.** `shed_crew` runs on the tick a builder goes out, so a kept builder that is not underground belongs to a running dig |
| F2: `_all_parked` without its walking check | **Equivalent.** Walks happen only before the first cube, when `advance` returns before any other `_all_parked` call; on the first tick nobody walks yet |
| B2: `begin_walk_in` without its registered check | **Equivalent.** A registered builder's walk is then measured from its parking (no ticks), and `register()` returns at once for a registered builder |
| S2: `close` without its whole-record check | **Equivalent.** Trailing bytes fail the canonical re-encode |
| B5: a not-at-rest builder's leave reported, not awaited | **Deferred:** needs a builder travelling when its partner stops the dig; the Kitchen pair always waits at rest |
| B9: a resume beginning the phase instead of resuming it | **Deferred:** behind the room bindings' `ROOM_PHASE_WORKER` (§6 gap 1, the cost lane) |
| B13, B14: the 512-box and plan-list caps not enforced at set-off | **Deferred:** no Kitchen plan reaches either cap (the plan's bounds are unit-tested) |
| S3: `finish` without its overflow check | **Deferred:** no fixture writes a record near `MAX_WIRE_BYTES` |
| S7: the host's restore without its contact rebind | **Deferred:** no host fixture has a way in until slice D |

## 9. Final gates (at `d5bb446a`, after merging `origin/master` with #265 and #266, 2026-10-16)

- **Full suite, CI-style:** `godot/.godot` deleted, `godot --headless --path godot --editor --quit`, then
  `./tools/run_tests_parallel.sh`: 522 suite files executed exactly once across 10 shards, 12,677 tests,
  1,421,683 assertions, 0 failures, 0 unexpected errors or warnings, nothing leaked.
- **Analyzer:** `tools/gdscript_warnings.py --max 0 --port 6433`, 0 warnings in 1,576 files.
- **Contracts:** every validator CI runs passes, including the decision numbers, ledger arithmetic, joint memory
  pack and its tests, the merge gate, the save registry handoff, the generated tables, the capacity audit, both
  section schemas, the state registry coverage and the setting contract.
- **The resume gap stands after #265:** the room bindings still refuse a new worker on a started phase
  (`ROOM_PHASE_WORKER`, §6 gap 1).

## 10. Memory options for Brendan (P-1937-1)

The coordinator holds the PR until Brendan rules. `room_dig_runtime` is 9,164,262 B. Decision 1880 Q1's projection
is 7,748,398 B over the gate, so this row would have to fall to **1,415,864 B** or less for Q1 to fit. All figures
below come from the census's own formulas.

| Option | Saved | Cost in play |
|---|---:|---|
| **B. One row-extent table shared by all builders.** The extents are a per-profile-row cache derived from Profiles and identical for every builder; one 256-row table instead of 256 | 1,566,720 | None |
| **C. One record image instead of two.** The codec writes into, and checks against, the caller's buffer, with no second full copy | 1,198,536 | None (the codec gets a streaming compare) |
| **D. A 512-row record pool instead of a 16,384-row record.** Index kept records by room; `MAX_KEPT` already bounds them | 458,240 | None |
| **E. 5 B per Site in a dig order instead of 13.** Drop each Site's distance (only the planning sort reads it) and its key (read from Sites when needed) | 591,272 | None |
| B + C + D + E together | **3,814,768** | None. The row falls to 5,349,494 B and the headroom rises to 44,399,170 B. Q1 is still 3,933,630 B over |
| **A. Cap concurrent builders at 64** (`MAX_DIGS` 64, `MAX_KEPT` 128), alone | 4,909,248 | At most 64 builders digging at once: 64 one-builder rooms, or 16 rooms of 4. With 256 residents, a quarter of the settlement |
| **A + B + C + D + E** | **7,101,616** | The 64-builder cap. The row falls to 2,062,646 B and the headroom rises to 47,686,018 B. **Q1 is still 646,782 B over** |
| F. Footprint cap 256 boxes instead of 512 (P-1936-5), alone | 1,572,864 | Larger cube plans refused `ROOM_BUILDER_FOOTPRINT_CAPACITY` (the Kitchen's plans have not been measured against 256) |

Fitting Q1 by shrinking this row alone needs B through E plus a cap of **24 builders** (row 1,377,886 B, 37,978 B
spare), or **40 builders with 256 boxes** (row 1,406,030 B, 9,834 B spare). Both are severe in play. Q1 was tight
(1.42 MB) before any dig existed; any working dig runtime overshoots it.

**Recommendation:** build B, C, D and E now (3.81 MB, no play cost), and take A, the 64-builder cap, only if
Brendan wants it. Revisit Q1's projection rather than squeezing digs to fit it: its 8,110,080 B allowance for
painted store containers is an "up to" figure that slice G has not yet designed. The engineering options are about
a day of work with their own parity proof. The cap is a gameplay constant, so it is Brendan's to choose.

## Source

Decisions 1218, 1219, 1221, 1223, 1228, 1880, 1933, 1935, 1936; `underground_dispatch.gd`,
`underground_room_runtime.gd`, `underground_room_foreman.gd`, `underground_room_builder.gd`,
`underground_room_claim.gd`, `underground_room_walk.gd`, `underground_room_parking.gd`,
`underground_room_composer.gd`, `underground_room_progress.gd`, `underground_room_frontier.gd`
(`resume_contact_into`), `settlement_system.gd`, the save adapters and registry; `tools/underground_current_census.py`
(`room_dig_runtime`).
