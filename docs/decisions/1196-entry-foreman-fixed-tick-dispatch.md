# 1196 — Entry foreman: fixed-tick dispatch of the first entry

Date: 2026-10-06 · Status: Accepted (increment 1 of 3)

## Decision

`godot/scripts/core/underground_entry_foreman.gd` drives the first-entry work
on fixed ticks. Until now only test fixtures did this, step by step. The
foreman calls only real owner methods, and every guard stays with its owner.
It grants no permission of its own.

- **Plan.** `configure(owners, crew, placement)` derives every task from the
  immutable Frontier and the original Placement:
  - Episode rows give the cube, which resolves to a Site through
    `Sites.site_at`, plus its station.
  - Station rows give the endpoint selector, heading and exact work profile and
    revision.
  - `endpoint_travel_into` gives the travel profile.
  - The selector point resolves to the one live Location with the same
    transformed point and role. Aliases refuse.
  - Rotation 0 only, for now.
- **Stages per phase.**
  1. OPEN: `open_phase`, BUILD Job, requester and tool gate, Site job and
     containers, worker assignment and tool claim.
  2. Placement of the actor:
     - first arrival calls the real `admit_work_actor` where the worker
       stands;
     - a worker already on the station refreshes WORK;
     - otherwise travel: `refresh_travel_actor`, `request_route`, ticks, then
       `turn_actor` on source-ready arrival.
  3. ENTER: ticks until `source_work_leaf_refusal` passes.
  4. START: exact input claims, `record_deliveries`, `bind_worker`,
     `begin_phase_work`.
  5. EARN: one `Work.tick_solo` per tick.
  6. RECOVER: `request_source_ready`, ticks, then `settle_phase`.
- **Failure.** The first refusal stops the foreman with that exact code.
  Nothing is retried or rolled back. A stage that makes no progress for 1,200
  ticks refuses `ENTRY_FOREMAN_STALLED`.
- **Crew.** The caller supplies the worker, the tool, the source-selected
  storage and output containers, and the stock lots by input key.

## Evidence

`test_underground_entry_work_area.gd::test_entry_foreman_drives_all_twelve_l0_phases_from_the_frontier`:
only `advance(tick)` runs the four cubes on the real ADR 1191 work-area world.
The ledgers equal the hand-driven fixture's: wood 5,500, stone 500, spoil
8,000, both conservations balanced, all Projects retired.

## Next increments

2. Paid L0 installation: material delivery, first-pair retirement, START,
   handling, INSTALL, commit.
3. Live use in the demo:
   - Surface arrival: walk the resident to the first station before
     admission. This increment admits only where the worker already stands.
   - Hauling wood and stone to storage through the Host's HaulPlanner instead
     of claiming lots in place.
   - Crew selection.
   - Saving and restoring the cursor. Its registry row is UNRESOLVED.
