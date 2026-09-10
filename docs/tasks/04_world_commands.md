# Task 04 — World initialization and player commands

Planning package 2026-09-09. Status: **PLANNED; no implementation credited**.
Owner: implementation lead; independent technical and player QA review.

## Purpose and authority

Make a reproducible settlement inspectable and let player intent enter the real
simulation at a committed boundary. This recovers command/initialization work
from ARCH-MIG-006 steps 3–5 before extending later consumers. It does not reorder
ARCH-SYS stages or replace task 03's ecology work.

Owners: [GDD](../game_gdd.md) §4, §5.1 REQ-SET-001–010 and §5.3
REQ-SET-027–041; [architecture](../systems_architecture.md) ARCH-ID-001–004,
ARCH-CMD-001–003, ARCH-CLOCK-001–003, ARCH-TICK-001–003, ARCH-SYS-001/002/009/023,
§8 save/command schemas and ARCH-MIG-006; [UI](../ui_ux_controls.md) §1–5,
UI-SET-103 and the task-04 rows in [requirements.csv](../planning/requirements.csv).
The CSV allocates individual UI requirements; referenced ranges are reading
context, not a claim that this milestone implements every requirement therein.
DEC-001/002/028 require additional scenarios eventually. SET-MOVE-001 governs
spatial identity even while the first executable fixture uses ground access.

## Dependencies and work permitted now

- Re-read [STATUS](../STATUS.md), task 03 and the
  [READY_06 answers](../rulings/2026-09-09_ready06_open_item_answers.md) against
  current code. The snapshot at planning time is HEAD `4fb57b1`; catalog IDs and
  `catalog_ids.json` already exist (ADRs 0033/0034).
- 04.1/04.2 command infrastructure and UI layout may begin alongside task 03.
  The same integration file cannot have two writers: task 03 owns
  `settlement_system.gd` until its changes are handed to the integration lead.
- Runtime ecology commands depend on task 03's producers and stages 005/006.
  Reuse its job triggers only after verifying item-specific adoption in the owning
  specification/ADR; READY_06 recommendations alone are not blanket approval.
  Do not create a second competing planner.
- Complete the affected slice of MOVE-G01/G02 before publishing production
  Transform/spatial schema. Ground-only indices must not become universal IDs.
- Exact legal starter containers, beds, room assignments and equipped tools
  require a narrow piece of task 06's building/container/gear contracts. Pull
  those shared stores forward under 04.3 ownership. If the contracts remain
  open, mark full initialization blocked; do not substitute unlimited piles,
  fictional beds, duplicated tools or unregistered inventory owners.
- Work factors must include all BAL-WORK-001 factors with one final floor.
  Weather exists; darkness/workshop context must acquire a real owner before
  a gathering fixture is described as production-correct. A constant neutral
  factor in a synthetic arithmetic test does not settle runtime context.

## 04.1 — Close U2/U3 scheduler and command persistence contracts

- [ ] Audit `sim_clock.gd`, the existing immediate setters and recovery counters;
  preserve evidence of the earlier conservative reading in task 02 and its ADRs.
- [ ] Write a reviewed source amendment/ADR for the following **proposal** before
  implementation. ARCH-CMD-002 already requires a separate scheduler-event queue;
  retain ARCH-CMD-003's 24 stable command IDs unchanged. Do not insert speed/pause
  keys into the sorted catalog.
- [ ] Proposed envelope fields are boundary `completed_tick`, monotonic session
  event sequence, event kind, reason mask and requested value. Finite queue size,
  exact packed widths/stride, accepted enum values, exhaustion refusal, save
  subsection/version and memory accounting must be completed in the amendment.
  These are design deliverables, not unspecified values a coder may choose at
  runtime. Preserve scheduler state and pending events in the versioned world/
  pending-command format; reject unknown versions before mutating live state.
- [ ] Process admitted scheduler events between fixed ticks, even while paused;
  drain them in sequence before deciding whether another tick may start. Economic
  commands remain due at `completed_tick+1`. Settle duplicate/retry behavior and
  ordering when a pause request arrives during a catch-up frame. This prevents
  unpause waiting for the very tick that pause prevents.
- [ ] Recommended recovery policy: retain whole-tick debt and drain it on resume;
  disable debt-discard recovery unless the higher-priority no-skipped-ticks rule
  is explicitly reconciled. Record whether sub-tick presentation debt is retained
  or discarded. This recommendation is **not** a ratification of U3 or permission
  to erase existing counters/tests without a replacement ledger entry.

Acceptance: pause/menu/critical/load reasons compose; closing one never clears
another; speed 0/1/2/4 only; no elapsed-time accrual during pause; unpause works
with pending commands; 4→2→1→diagnostic behavior retains debt. Save/reload a paused
queue once task 09 supplies a production codec; before that, report the fixture
blocked, even if an independent envelope round-trip passes. Record updated
source IDs, binary layout/bytes and command/scheduler replay boundaries.

## 04.2 — Ordered command admission, commit and visible pending state

- [ ] Add proposed `scripts/core/commands.gd` and payload schema/validation helpers.
  Keep 64-byte records, queue 4096 and payload arena 1048576 bytes from ARCH-CMD/
  SAVE. Checked integer arithmetic validates ranges and offset+length before any
  mutation. Targets use generation-checked references. Sequence order compares
  unsigned high then low words. Define duplicate and sequence-exhaustion refusal
  without wraparound in 04.1's contract.
- [ ] Admission validates the envelope; commit revalidates current targets and
  availability. A preview is advisory. Whole command operations succeed or refuse
  atomically; later refusal cannot leave a policy half changed or reserve goods.
  Deterministic refusal result IDs must be documented and presented to the player.
- [ ] Implement the bounded task-04 command set: SET_MANUAL_TASK/CANCEL_MANUAL,
  CANCEL_JOB, DESIGNATE_ZONE, SET_POLICY, SET_JOB_PRIORITIES,
  SET_ACTIVITY_SCHEDULE and NAME_RESIDENT where their owning stores/contracts
  exist. Dispatch unavailable kinds to explicit unsupported-feature refusal,
  never silent success. Track the remaining catalog kinds under tasks 06–08.
- [ ] Append accepted economic commands while paused to the next-tick queue;
  immutable presentation projections show pending entries and cancellation state.
  No UI callback edits resident, ecology, jobs or inventory stores directly.
- [ ] Wire ARCH-SYS-002 once, through a named runtime handoff with task 03.
  Do not advance a RESERVED job to WORK to make a command appear successful.

Acceptance: permuted input arrival produces canonical order by the owning key;
multiple paused commands preserve sequence; target destruction/reuse between
preview and commit refuses; 4096 accepted records plus one refuses cleanly;
payload boundary, negative length, overflow, invalid IDs, generation and UTF-8
name limits are tested. Queue capacity tests are contract tests, not performance
claims. Hash unchanged authoritative state for refused admission; commit refusal
may change only the documented result/event state. Verify all ledgered columns.

## 04.3 — Transactional initializer and shared starter services

- [ ] Add proposed `scripts/core/world_init.gd` with prepare/validate/publish
  stages. Explicitly reset RNG, generation/free-slot state, child arenas, job and
  command state before exposing an active world. Failed initialization retains
  the previous valid world and reports the exact failed assertion.
- [ ] Reuse task 03's authored estuary masks, ore split and resource placement;
  do not recreate them. Validate GDD §5.1 and §5.9 layout, seed attempts ≤16,
  hall-to-exit/forest/water/loam/deposit reachability and mask precedence using
  task 05's topology once available. Before that mark topology assertions blocked.
- [ ] Initialize the 12-resident fixture exactly: IDs 1–12, Warden Rowan, species,
  needs/health, XP (including reserved index 3 zero), relationship pairs, priorities,
  beds and assignments; catalogs supply values. Quantities use milli-U and all
  STARTER sources are accounted. Verify 24 tools TOTAL: 12 equipped, 12 stored.
- [ ] Pull forward only the starter data slice of buildings/furniture/containers,
  bed references and gear from task 06, with a single shared implementation. Full
  construction, dynamic room detection, heat/service operations remain task 06.
  Every starter item fits a legal container under actual mass/filter limits.
- [ ] Scenario identity is an explicit versioned initialization input. First use
  the specified refuge as an engineering fixture; no other scenario gets the
  refuge's values by fallback. The release scenario roster remains a task-08
  authoring gate; all three setting and premise families remain in scope.

Acceptance: independently initialized worlds from the same validated scenario,
seed and catalog hash match every authoritative initializer field; invalid
catalog/topology/capacity leaves no partial settlement; restart has no residual
claims; ore totals are 1200000/300000 milli-U, not that quantity per deposit tile.
Required buildings and population fit real packed stores, no per-resident nodes.
This proves initialization, not a surviving or complete colony.

## 04.4 — Inspectable application and the intent-to-job handoff

- [ ] Wire New Settlement, initially paused world, time/calendar controls,
  camera/selection, resource summary, resident detail, zone tool, pending preview,
  cancellation and accessible refusal display to real state.
- [ ] Apply UI registry profiles, narrow/wide geometry, actual input rectangles,
  keyboard focus and Mac trackpad alternatives. Decorative UI must not consume
  world clicks. The generic rendered shell cannot claim unbuilt panels work.
- [ ] Connect accepted zone/policy commands to task 03's adopted standing-demand producer
  through ARCH-SYS-009. Record source intent/job identity so repeated evaluation
  cannot duplicate a job. Integrate task 05's route-ready/arrival callback later.
- [ ] Extract read-only UI/render snapshots at ARCH-SYS-023. Rendering floats
  interpolate committed integer state only; hiding layers does not change truth.
- [ ] Add/retain per-stage measurements and same-command replay input capture.
  List unimplemented stages honestly, including current CareHealth ordering debt;
  do not perpetuate stale comments saying three/five stages proves completeness.

Acceptance: launch the real main scene, make a next-tick zone/policy edit while
paused, see the ghost and unchanged stocks, resume and observe one real source
intent/job, then cancel. Capture Mac screenshots and a command/state trace.
No delivered output is expected until task 05's route/work/logistics integration.

## Ownership, verification and completion boundary

Game coder owns new core modules. Task 03 coder owns ecology stores/producers.
One integration lead owns `settlement_system.gd`, `game_manager.gd`, scene/autoload
changes and shared startup composition. UI coder owns UI scenes/scripts only.
Test runner owns focused fixtures and logs; reviewer owns findings, not concurrent
edits to coder files. Assign actual names/paths before dispatch, not two agents to
one store. Migrate obsolete assertions in `02_test_migration_ledger.md`.

Use `tools/run_tests.sh`, editor import and main-scene boot commands in
[ENVIRONMENT](../ENVIRONMENT.md); validate runner counts, not exit status alone.
Run affected standalone controls per [validation README](../validation/README.md)
where their shared contracts changed. Save logs with revision, engine, fixture,
commands, summaries and omitted mechanics. UI review requires visible execution;
headless tests alone do not establish ergonomics.

Task 04 is complete only when the above supported command and startup slice runs
through real stores and its open schema dependencies are resolved. Remaining
command kinds, full movement, survival, save parity and release performance are
explicitly outstanding. Continue to [task 05](05_movement_first_playable.md);
use [first-playable acceptance](../planning/first_playable_acceptance.md).
