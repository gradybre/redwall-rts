# 1218 — The first entry's progress is saved explicitly (ADR 1197 G10)

Date: 2026-10-07 · Status: Accepted (Brendan's decision); implemented for the entry chain. Whole-save wiring waits on
the other underground owners' codecs (see "What this does not do").

## Brendan's decision

> Save the entry's progress explicitly.

On 2026-10-07 Brendan chose to **save** the foreman, installer, hauler and entry-runtime cursor, so that a load
restores it exactly. He did not choose to re-derive it on load. This closes ADR 1197 G10's
"re-derive vs save" question. It also retires G10's "alert on save while dispatch is in flight": a dispatch in
flight is saved like any other state.

## Why saving, and not re-deriving, is also the only correct reading

A re-derivation would have to rebuild state that no longer exists in the world:

- **The Task list.** The plan resolves every station to a live Location when the foreman is configured. L0's START
  retires the first two station Locations (ADR 1191), so after that the plan can no longer be resolved.
- **The installer's Plan.** It is resolved when the installation starts, and its retired pair disappears at START.
- **The haul queue.** Re-deriving it from M's free stock in the middle of a haul would count the units already
  delivered twice.

## What is written

The record is one versioned, little-endian, fixed-width byte string. Each owner writes its own fields (`write_state`)
and validates them (`read_state`); `underground_entry_progress.gd` holds only the framing and the scalar codec.
There are no floats and no Variant encoding.

| Block | Bytes | Fields |
|---|---:|---|
| Header | 12 | Magic `ENTP`, version 1, kind (1 runtime, 2 foreman) |
| Runtime | 130 + 8 per endpoint | Step, retained refusal code (64-byte ASCII), origin, published section, 0 or 11 endpoints, M and R containers, ADR 1219 walk ticks left, arrival heading and H anchor point, crew/foreman presence |
| Crew | 40 | Worker, tool, storage, output, arrival (ADR 1219) |
| Foreman | 232 + 52 per Task | Delivery and paid wiring flags, content pin, Placement, every Task, index, stage, stage ticks, Job slot (+ handle while a stage reads it), refusal code, accepted/install/haul ledgers, last install marker, leg target/profile/revision, retreat and pending retreat, haul marker, ADR 1219's arrival profile/revision and arrival retreat with its profile/revision |
| Installer | 165 + 12 per quote line | The whole Plan, content pin, stage, Project, Job (+ handle), ledgers, quoted input lines (compiled item, milli) |
| Hauler | 88 + 4 per trip + 20 per leg | Project, home Job, queue, legs, leg and trip indexes, HAUL Job (+ handle), stage, content pin, M and both stands, ledgers |

`MAX_WIRE_BYTES` is 2,559 (a haul has at most three legs since ADR 1219: H, the retreat, M). At most one haul is live at a time: the foreman's own (STAGE_HAUL) or its
installation's, never both. The test `test_entry_progress_refuses_every_corrupt_or_stale_record_exactly` asserts that
the declared block sizes are the encoder's own.

**A terminal foreman** (DONE or FAILED) writes no installer or hauler block. Nothing reads the world again, so
their work is folded into the foreman's ledger getters. This keeps `accepted_mwu`, `install_mwu`, `haul_mwu` and
`haul_trips` exact.

**Not written, because each is derived or scratch:**

- `_math`, `_actor` and `_quote`. `_quote` is refilled from the restored Router and checked against the saved
  lines.
- The runtime's borrowed Jobs owner, crew row and Transforms handle (ADR 1219), which are re-derived from the Session.

**ADR 1219 walk state.** `_walk_left` is future-affecting and written. `_anchor` and `_arrival_yaw` are written and,
while a walk is under way, re-proved: the anchor must be the live H's own point (`ENTRY_SAVE_LOCATION`) and the
heading the foreman's `arrival_yaw()` (`ENTRY_SAVE_SHAPE`). While the crew is not yet a route actor, `Crew.arrival`
and the foreman's arrival retreat must be live Locations.

## Refusal codes on load

`restore` builds only a fresh foreman or runtime, and touches no owner. When it refuses, the foreman is left
FAILED with the refusal as its `error()`; a runtime is left at STEP_NONE holding the refusal.

| Code | When |
|---|---|
| `ENTRY_SAVE_VERSION` | Wrong magic, version or block kind |
| `ENTRY_SAVE_SHAPE` | The record is truncated or has trailing bytes. Or a value is out of range: a flag that is not 0/1, a null handle not spelled exactly (-1, 0), a stage or count out of bounds, or a non-zero byte in a code's padding. Or a stage and its sub-blocks or products disagree. |
| `ENTRY_SAVE_NONCANONICAL` | The decoded state does not re-encode to the very same bytes. This is a backstop: by construction every accepted field writes back as read. |
| `ENTRY_SAVE_TARGET` | Restore into a foreman or runtime that is not fresh, or capture from an unconfigured foreman |
| `ENTRY_SAVE_OWNERS` | The Delivery or paid-order wiring disagrees with the record, or required owners are missing |
| `ENTRY_SAVE_CONTENT` | A content pin is not the restored profile content revision |
| `ENTRY_SAVE_CREW` | The worker is not a live resident, the tool lot is not live, or a container has no spatial endpoint |
| `ENTRY_SAVE_PLACEMENT` | The entry Placement is not live |
| `ENTRY_SAVE_SITE` | An unsettled Task's excavation Site is not live |
| `ENTRY_SAVE_LOCATION` | A Location that will still be read is not live. This covers an unsettled Task's station, an unstarted L0's retired pair, the travel leg, the retreats, the installer's station, material, arrival and (before START) its retired pair, and the haul's M, stands and remaining legs. M must also be the storage container's own endpoint. |
| `ENTRY_SAVE_JOB` | A Job the cursor still reads is not live at the saved generation |
| `ENTRY_SAVE_PROJECT` | The haul's Project is not live, or the paid order does not quote the saved bill |
| `ENTRY_SAVE_ACTOR` | The innermost active dispatcher's worker is not a committed route actor under that dispatcher's Job |
| `ENTRY_SAVE_BUSY` | Capture while a synchronous Routes, Locations or WorldRoutes operation is open |

Handles are re-proved only while a later stage will still read them. A settled Task's station may already be retired,
and its handle is kept as recorded data.

## A dispatch in flight

**Decision: save at any quiescent fixed-tick boundary, in flight or not.** This follows the existing owner
convention: `Placements.capture_file` and `Workpieces.capture_into` refuse only while a synchronous cold operation is
open (`_quiescent`). They do not refuse while an order spans ticks. The entry chain does the same (`ENTRY_SAVE_BUSY`).

A route that is under way belongs to Routes. So do a lifted unit, the unequipped tool and the claims: they are Routes,
Delivery, Gear, Inventory and Reservations state. The cursor records only what the dispatcher itself reads next. A
mid-route or mid-haul save is therefore exact, as long as those owners are restored exactly too.

Rejected: refusing to save, or raising an alert, while a dispatch is in flight. That was ADR 1197's original G10 plan.
A player can save at any tick, and a phase lasts hundreds of ticks, so the alert would make saving fail almost all the
time. Brendan's decision supersedes it.

## Canonical declaration

`canonical_state_registry.json` declares a new section 6 owner, `underground_entry_progress` (schema 1):

- `progress_length` (u32), then `progress_record` (u8, `max_count` 2,559). Both are hashed.
- `queue_length`/`_queue`. These are the hauler's category-1 packed queue, declared with `hash: false` and a
  `hash_location` inside the record, so the queue is not hashed twice.

Contract C195 records the rules. The registry advances to version 12, with identity
`RWL-CANONICAL-REGISTRY-2026-10-07-EP1` and section 6 schema 6. Counts: 758 records, 672 packed source fields,
62 owners, 768 fields.

## What this does not do (a later choice)

> **Update (ADR 1221).** The owner codecs listed below now exist. Routes and WorldRoutes are saved, with both geometry
> journals. The Contacts scope is saved, and Delivery's admitted haul is saved as section 6 owner `haul_planner`.
> ConnectorWork and the Budget save nothing and require quiescence. Both goal chains cold-restore all of them every 41
> or 23 ticks and end byte-identical. What remains is the section-6 body and the orchestrator. A fresh-Session load
> also remains, and it needs the settlement's own save and load (task 09). ADR 1221 sets out those options for
> Brendan.

**A load into a fresh Session is not possible yet.** The record restores exactly against restored owners, but several
underground owners have no save codec at all:

- Routes: the edge bank and the actor/MotionBank are category 1 with "implementation in progress".
- WorldRoutes publication state.
- Contacts.
- Delivery: its admitted haul is haul_planner's UNRESOLVED row.
- ConnectorWork and the shared Budget.

No section 6 body or orchestrator exists for any underground owner either. The tests therefore restore the record into
fresh dispatchers over the same owners. That proves the record is complete: every tick of a hauled prefix continues
byte-identically. Restoring the owners themselves is their own work. Wiring `capture`/`restore` into the host's
whole-save path belongs to that orchestrator; SettlementSystem is unchanged.

## Memory

The record exists only during one capture or restore. `tools/underground_current_census.py` charges two whole images:
the writer's buffer and its returned copy, or the caller's input and the canonical re-encode. It also charges the
Writer/Reader packets: 2 × 2,559 + 10 = **5,128 B**, as a new `progress_record` row of the first-entry runtime chain
(now 8,338 B with ADR 1219's 3,210). The canonical declaration grows by **150 B** (1 owner, 4 fields, 74 key bytes).
The joint pack moves from 100,007,755 (after ADR 1219) to **100,013,033 B**, leaving 49,986,967 B under the 150 MB
gate (DEC-053). The ledger also gains ADR 1219's own +124 B row, which its commit had not entered in
`ready07_arithmetic.py` or `systems_architecture.md`.

## Evidence

- `test_underground_paid_assembly_handling.gd::test_entry_progress_restores_exactly_through_the_hauled_prefix`. The
  hauled complete prefix (4,751 ticks, 9 trips) runs uninterrupted, and then again with the foreman captured and
  replaced by a fresh restore **before every tick** (4,751 restores). Every resting stage is crossed:
  - foreman: OPEN, TRAVEL, ENTER, EARN, RECOVER, INSTALL, HAUL;
  - installer: HAUL, LEG_ARRIVAL, LEG_STATION, HANDLE, INSTALL_ENTER, EARN, RECOVER;
  - hauler: all six stages.

  The final Inventory, Reservations, Construction, Jobs, Work, Gear, Transforms, Sites, Router and Space state, the
  Placement bank, the terminal record, the finishing tick and the ledgers are byte-identical to the uninterrupted run.
  LEG_MATERIAL never rests at a tick boundary in the hauled prefix, because the walk to M happens inside the haul.
- `…::test_entry_progress_refuses_every_corrupt_or_stale_record_exactly`. Each of 13 kinds of damage, plus the
  wiring, target and busy cases, is refused with its exact code. No owner's state bytes change.
- `test_underground_host.gd::test_entry_runtime_progress_round_trips_at_a_stopped_step_and_resumes` round-trips the
  runtime at the G11 stop and again mid-walk, refusing a moved anchor and a wrong heading.
- `…::test_fixed_ticks_with_the_entry_restored_every_tick_end_byte_identical` runs the live settlement by `run_tick`
  alone from the surface walk, through arrival and registration on H, the retreat and both hauls, to the G6 stop
  (`JOB_HAS_WORKER`, tick 518), uninterrupted and then with the whole runtime restored before every tick (373 restores
  mid-walk, including the arrival tick, and 144 after registration). The stop tick, the refusal, the Directory,
  Inventory, Residents, Jobs, Transforms, Construction and Reservations state and the final record are byte-identical.
