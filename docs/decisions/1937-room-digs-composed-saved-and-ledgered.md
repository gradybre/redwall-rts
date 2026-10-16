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
- parks it, then orders and starts the dig.

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
  (`unregister_resting_actor`, or `unregister_lost_actor` for a lost one), then walk the timed walk in reverse. A
  builder stopped inside a WORK source first asks the source for READY and leaves when it gets there; until then
  it stays reserved. A DONE record whose crew is out clears itself and drops its foreman.
- **Resume (P-1933-2 (a)).** A re-ordered room's cube with a live, started phase is taken first: the builder takes
  the Site's bound Job, walks to the station, and continues the paid work through Sites' `resume_phase_work`
  without a second payment. Frontier refuses a live project (`ROOM_FRONTIER_EXISTING_PROJECT`), so
  `underground_room_frontier.gd` gains `resume_contact_into`: the same contact search for that Site's own WORKING
  or WORK_DONE phase. **This file is outside the listed lane files; it has no active owner.**

## 4. Save and load (P-1936-4 (a))

- Section 6 owner `underground_room_progress`: registry v17 (`RWL-CANONICAL-REGISTRY-2026-10-15-RD1`), section 6
  schema 11, 26 owners, 812 canonical records. `progress_length` (u32) and `progress_record` (u8, at most
  `MAX_WIRE_BYTES` = 1,198,536) are hashed.
- **The ten category-1 packed columns** (the runtime's five record columns and `_foreman_rows`, the foreman's
  `_cube`, the builder's `_legs`, `_leg_profiles` and `_queue`) are declared hash-free inside the record, with a
  length each, as decision 1218 declared the hauler's `_queue`. Source contract C202; 704 packed source fields.
  The adapter refuses a block that carries any of them.
- The codec (`underground_room_progress.gd`, "RMDP" v1) writes only rows in use, each kept foreman (state, codes,
  ledgers, latch, epoch, context; while running its order rows and marks) and each builder (crew, cursor, the four
  leg lists, the cube plan, the walk, the haul plan and ADR 1218's unchanged hauler block). Footprints are swept
  again from the saved cube plan, so no box is saved; keys, extents and per-tick flags are re-derived.
- A decoded record must re-encode to the same bytes (`ROOM_SAVE_NONCANONICAL`). Restore goes into a fresh runtime
  whose owners the re-mount bound, after the entry's record, and then binds the contacts again.
- **Parity (ARCH-SAVE-006).** On the Kitchen, restoring before every tick ends byte-identical to the uninterrupted
  run for one builder, a haul, two builders and a stopped dig. Through the real save path, a queued record
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

With the declaration's +625 B, live is **109,415,494 B** and the **headroom is exactly 40,584,506 B** (it was
49,749,393). Decision 1936 estimated about 5.26 MB; the difference is the two record images (2.4 MB, charged as
ADR 1218's are) and extents charged at `MAX_PROFILES` = 256 rows rather than one content's 67.

**Decision 1880's columns are not folded:** this lane allocates none of them. Folded, the headroom would be
23,627,066 B. **Decision 1880 Q1's projection now overshoots.** It left 1,416,593 B after the painted-room budget
and the adopted projects and containers (23,265,280 + 8,110,080). With this runtime counted, that projection is over
the gate by **7,748,294 B**. `ready07_arithmetic.py` pins the shortfall; it is not an allowance. Slices C and G
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

## Source

Decisions 1218, 1219, 1221, 1223, 1228, 1880, 1933, 1935, 1936; `underground_dispatch.gd`,
`underground_room_runtime.gd`, `underground_room_foreman.gd`, `underground_room_builder.gd`,
`underground_room_claim.gd`, `underground_room_walk.gd`, `underground_room_parking.gd`,
`underground_room_composer.gd`, `underground_room_progress.gd`, `underground_room_frontier.gd`
(`resume_contact_into`), `settlement_system.gd`, the save adapters and registry; `tools/underground_current_census.py`
(`room_dig_runtime`).
