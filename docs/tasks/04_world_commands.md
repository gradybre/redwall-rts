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

- [x] Audit `sim_clock.gd`, the existing immediate setters and recovery counters;
  preserve evidence of the earlier conservative reading in task 02 and its ADRs.
- [x] Write a reviewed source amendment/ADR for the following **proposal** before
  implementation. ARCH-CMD-002 already requires a separate scheduler-event queue;
  retain ARCH-CMD-003's 24 stable command IDs unchanged. Do not insert speed/pause
  keys into the sorted catalog.
- [x] Proposed envelope fields are boundary `completed_tick`, monotonic session
  event sequence, event kind, reason mask and requested value. Finite queue size,
  exact packed widths/stride, accepted enum values, exhaustion refusal, save
  subsection/version and memory accounting must be completed in the amendment.
  These are design deliverables, not unspecified values a coder may choose at
  runtime. Preserve scheduler state and pending events in the versioned world/
  pending-command format; reject unknown versions before mutating live state.
- [x] Process admitted scheduler events between fixed ticks, even while paused;
  drain them in sequence before deciding whether another tick may start. Economic
  commands remain due at `completed_tick+1`. Settle duplicate/retry behavior and
  ordering when a pause request arrives during a catch-up frame. This prevents
  unpause waiting for the very tick that pause prevents.
- [x] Recommended recovery policy: retain whole-tick debt and drain it on resume;
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

Implemented 2026-09-11 by `scripts/core/scheduler_events.gd`
([decision 0054](../decisions/0054-the-scheduler-event-queue-drains-before-every-tick.md)),
against the completed amendment
[R07-SCHED-001](../planning/ready07_scheduler_contract.md): 32-byte record, 256
records, 32-byte control header, **8224 bytes** added once to ARCH-MEM-010's
basis (60256806 → 60265030 on this work's base; 60812854 → **60821078** once
merged on top of decisions 0051, 0053 and 0055). ARCH-CMD-003's 24 economic kinds are
unchanged and `catalog_ids.json` is byte-identical. `sim_clock.advance()` gained
an optional `before_tick` barrier and an optional `on_overload` hook; with
neither supplied it behaves exactly as before. Every acceptance clause above is a
named test in `test/test_scheduler_events.gd`, together with the contract's own
list. **`acknowledge_without_catchup()` is byte-unchanged and so are its tests.**

**Still outstanding within 04.1: SAVE/RELOAD OF A PAUSED QUEUE IS BLOCKED**, and
is reported blocked rather than passing. The `SCHQ0001` subsection is implemented
as encode, decode and validation and is unwired, because no save module exists;
task 09 owns the codec. The container-version-2 section-12 prefix is implemented
only as its pure arithmetic and bounds, since wiring it needs both that codec and
`commands.gd`'s economic records. **U2 is closed in process and open on disk.**
U3 is NOT closed: the conservative rule stands, now with ARCH-CLOCK-002's
recovery exception explicitly reconciled against GDD REQ-SET-008 in decision
0054.

## 04.2 — Ordered command admission, commit and visible pending state

- [x] Add proposed `scripts/core/commands.gd` and payload schema/validation helpers.
  Keep 64-byte records, queue 4096 and payload arena 1048576 bytes from ARCH-CMD/
  SAVE. Checked integer arithmetic validates ranges and offset+length before any
  mutation. Targets use generation-checked references. Sequence order compares
  unsigned high then low words. Define duplicate and sequence-exhaustion refusal
  without wraparound in 04.1's contract.
- [x] Admission validates the envelope; commit revalidates current targets and
  availability. A preview is advisory. Whole command operations succeed or refuse
  atomically; later refusal cannot leave a policy half changed or reserve goods.
  Deterministic refusal result IDs must be documented and presented to the player.
- [x] Implement the bounded task-04 command set: SET_MANUAL_TASK/CANCEL_MANUAL,
  CANCEL_JOB, DESIGNATE_ZONE, SET_POLICY, SET_JOB_PRIORITIES,
  SET_ACTIVITY_SCHEDULE and NAME_RESIDENT where their owning stores/contracts
  exist. Dispatch unavailable kinds to explicit unsupported-feature refusal,
  never silent success. Track the remaining catalog kinds under tasks 06–08.
- [x] Append accepted economic commands while paused to the next-tick queue;
  immutable presentation projections show pending entries and cancellation state.
  No UI callback edits resident, ecology, jobs or inventory stores directly.
- [x] Wire ARCH-SYS-002 once, through a named runtime handoff with task 03.
  Do not advance a RESERVED job to WORK to make a command appear successful.

Implemented 2026-09-10 by `scripts/core/command_dispatch.gd`
([decision 0043](../decisions/0043-command-dispatch-commits-per-kind-schemas.md)),
run as `settlement_system.gd`'s first stage. **Six of the 24 kinds commit**
(CANCEL_JOB, DESIGNATE_ZONE, NAME_RESIDENT, SET_ACTIVITY_SCHEDULE,
SET_JOB_PRIORITIES, SET_POLICY); the other eighteen refuse
`COMMAND_UNSUPPORTED_FEATURE` and name the missing owner. **SET_MANUAL_TASK and
CANCEL_MANUAL are among the eighteen: there is no ManualTask store (blocker U6).**
Still outstanding within 04.2: pending-command PERSISTENCE (no save module, task
09 owns the codec). The named handoff is **closed**: `settlement_system.gd` calls
`command_dispatch.bind_ecology()` during composition as of 04.4 below, so all six
implemented kinds commit in the running game and `COMMAND_STORE_NOT_BOUND` is now
produced only by a composition that genuinely lacks the stores. ARCH-CMD-002's
speed/pause scheduler queue remains 04.1's and is untouched.

Acceptance: permuted input arrival produces canonical order by the owning key;
multiple paused commands preserve sequence; target destruction/reuse between
preview and commit refuses; 4096 accepted records plus one refuses cleanly;
payload boundary, negative length, overflow, invalid IDs, generation and UTF-8
name limits are tested. Queue capacity tests are contract tests, not performance
claims. Hash unchanged authoritative state for refused admission; commit refusal
may change only the documented result/event state. Verify all ledgered columns.

## 04.3 — Transactional initializer and shared starter services

- [x] Add proposed `scripts/core/world_init.gd` with prepare/validate/publish
  stages. Explicitly reset RNG, generation/free-slot state, child arenas, job and
  command state before exposing an active world. Failed initialization retains
  the previous valid world and reports the exact failed assertion.
- [x] Reuse task 03's authored estuary masks, ore split and resource placement;
  do not recreate them. Validate GDD §5.1 and §5.9 layout, seed attempts ≤16,
  hall-to-exit/forest/water/loam/deposit reachability and mask precedence using
  task 05's topology once available. Before that mark topology assertions blocked.
Terrain and ecology implemented 2026-09-10 by `scripts/core/world_init.gd`
([decision 0048](../decisions/0048-world-generation-anchors-and-what-it-refuses-to-invent.md)).
`generate()` publishes §5.1's authored estuary: the four masks in their stated
precedence, the three soil bands, the cleared loam rectangle, 1571 capped tree
centres and the 100-node guaranteed grove, both decision-0029 ore deposits
through `resource_nodes.gd`'s own operations, four forest and three fish ecology
basins with decision 0037 §8B's nine stocks at 80%, `FaunaStockReserved`'s
canonical empty 384 rows, and the seeded world RNG §5.1 fixes at 20260905.
**1695 resource nodes, 7 basins, 9 stocks.** A `DESIGNATE_ZONE` targeting a
generated forest basin now commits and yields one real ARCH-SYS-009 FORAGE job.
Every §5.1 generator guarantee is validated in a STRAIGHT LINE; **every
reachability half is BLOCKED on task 05's topology**, as this checklist requires.
**Still outstanding within 04.3:** the resident/building/container/gear fixture
below (no Building, Furniture or **Room** store exists — full initialization is
BLOCKED, and nothing was substituted), the save round trip (task 09 owns the
codec), and composition into `settlement_system.gd`, which belongs to the
integration lead.

**Starter footprint clearing closed 2026-09-11 (READY_07 §7.1,
[decision 0060](../decisions/0060-starter-footprints-are-cleared-ground-not-buildings.md)).**
`world_init.gd` now clears GDD §5.9's seven authored footprints — hall 12×10 at
(58,59), four 4×4 stockpiles, the 2×2 well, the 3×3 workbench shelter — and
§5.1's one-tile apron, before placing any resource node. **376 cleared tiles**
(197 footprint + 122 apron ring + 57 loam rectangle). No authored footprint
overlaps another; shared aprons do overlap and that is legal. The node census was
**recalculated from the geometry rather than protected** and comes back to 1695:
no cleared tile is an even/even forest tile, and the five grove tiles the apron
takes at (49,59..63) relocate inside §5.1's replacement window, so the grove is
still exactly 100 (70 in the rectangle, 30 relocated). **Still ground only** —
no Building, Furniture or Room store is created; those remain §7.2 step 2.

**Catalog binding closed 2026-09-11 (READY_07 §2,
[decision 0052](../decisions/0052-resource-ids-are-compiled-item-definition-keys.md)).** The
`Request`'s item ids DO now have an authored source: `scripts/core/resource_catalog_binding.gd`
resolves all **seventeen** — `wood`/`stone`/`iron`, the five `PATCH_KEYS` and the nine
`SPECIES_KEYS` — by key against the compiled `ItemDefinition` catalog, verifying
`catalog_ids.json` before it reads one, and `WorldInit.bound_request(items)` builds the whole
request from a loaded registry alone. `_item_id_is_storable()` is demoted to a shape check; a
missing, retired, wrong, wrongly ordered, wrongly counted or stale-artifact binding refuses with
its own code and leaves every store byte-identical. **This does not compose the generator into
`settlement_system.gd`** — that remains the integration lead's, with the starter fixture. It also
exposed and fixed a real defect: `fishing.gd`'s habitat-major `species_ids` argument order is not
`SPECIES_KEYS` order, so the coast had been receiving the river's three item ids and vice versa.

**Two claims here were wrong and are corrected 2026-09-11 (READY_07 §7.1),
preserved rather than deleted.** (1) "No Container store exists" — `inventory.gd`
already owns packed `InventoryContainer` rows with capacity and generation
allocation, `create_container`, reserved/used mass, filters and reachability. The
missing part is Building/Furniture/Room **ownership and composition**, not
containers; a competing container store must not be created. (2) "§5.1 gives no
coordinates" for the starter footprints — GDD **§5.9** authors them exactly: hall
(58,59) 12×10, stockpiles (50,60),(50,65),(70,60),(70,65) 4×4, well (64,54) 2×2,
workbench shelter (58,54) 3×3, all rotation 0.

- [ ] Initialize the 12-resident fixture exactly: IDs 1–12, Warden Rowan, species,
  needs/health, XP (including reserved index 3 zero), relationship pairs, priorities,
  beds and assignments; catalogs supply values. Quantities use milli-U and all
  STARTER sources are accounted. Verify 24 tools TOTAL: 12 equipped, 12 stored.

**Composed 2026-09-11 ([decision 0071](../decisions/0071-world-generation-creates-the-cohort.md)),
and NOT closed.** `SettlementSystem.create_generated_settlement()` now runs REQ-SET-009's
generation and §5.1's cohort as ONE all-or-nothing operation, and `main.gd` boots through it, so
generating a world produces a world with **twelve residents in it** instead of an empty one.
Species mix, Warden Rowan, needs 7500, health 100, skill levels 2 / Rowan KEEP 3, the reserved
index-3 zero, priorities, schedules and job agents are all satisfied and asserted. **Four parts of
GDD:235 are NOT:** (1) the relationship edges at affinity 20 — **there is no relationship store
anywhere in the repository** and 08.3 owns it, so none was invented; (2) the hall, beds, bench,
seats, hearth, pantry, well, stockpiles and workbench — no Building/Furniture/Room store, which is
the bullet below; (3) the 24 tools and durability 1000 — `gear.gd` exists but has no container
owner and is not composed; (4) **"IDs 1–12" is not satisfied and cannot be** while §4.2's single
id space is consumed by 1713 world entities first — the cohort receives 1714–1725. That
contradiction is arithmetic, not an implementation choice, and decision 0064 sets out both
readings that would close it and which document each one breaks. **It needs a ruling.**
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

**2026-09-11 visual follow-through:** [task04.5](04_5_ui_visual_refinement.md)
now specifies the required refinement and fixes to gates, roster ownership,
formatting, focus and responsive behavior. Read the active UI worktree/evidence
before relying on historical completion notes below. The owning
[SET-UX-VIS-002](../ui_visual_refinement_amendment.md) separates functional,
structural visual and user-review status.

- [ ] Wire New Settlement, initially paused world, time/calendar controls,
  camera/selection, resource summary, resident detail, zone tool, pending preview,
  cancellation and accessible refusal display to real state.
- [x] Apply UI registry profiles, narrow/wide geometry, actual input rectangles,
  keyboard focus and Mac trackpad alternatives. Decorative UI must not consume
  world clicks. The generic rendered shell cannot claim unbuilt panels work.
- [x] Connect accepted zone/policy commands to task 03's adopted standing-demand producer
  through ARCH-SYS-009. Record source intent/job identity so repeated evaluation
  cannot duplicate a job. Integrate task 05's route-ready/arrival callback later.
- [x] Extract read-only UI/render snapshots at ARCH-SYS-023. Rendering floats
  interpolate committed integer state only; hiding layers does not change truth.
- [x] Add/retain per-stage measurements and same-command replay input capture.
  List unimplemented stages honestly, including current CareHealth ordering debt;
  do not perpetuate stale comments saying three/five stages proves completeness.

Bullets 1 and 2 implemented 2026-09-11 by `scripts/ui/` and `scripts/systems/ui_manager.gd`
([decision 0057](../decisions/0057-the-ui-shell-renders-the-registry-and-refuses-to-imply-more.md)),
following [the visual direction](../planning/ui_visual_direction.md). **42 of UI §4's 103
elements are driven by real state; the other 61 are drawn DISABLED with the name of the owner
they wait for** -- that split is a table in `ui_availability.gd` and both halves are tested.
The world opens PAUSED with the PLAYER reason and an empty command queue; New Settlement runs
`world_init.gd` against the running settlement's own stores (1695 nodes, 7 basins, 9 stocks,
seed 20260905); a minimap tile pick resolves a real basin; a painted stroke commits as a
DESIGNATE_ZONE COMMAND that sits pending while paused; cancellation, SET_POLICY and
NAME_RESIDENT travel the same queue; refusals reach UI-SET-085 with a severity icon, plain
words and the exact code. §2.1's palette, the four vendored Noto Sans weights and an original
24x24 icon set are applied through one generated Theme at the UI root.
**Still outstanding within these two bullets:** Mac TRACKPAD alternatives are unbound (§5's
pointer gestures still have no input router); the NARROW composition cannot be reached at
runtime because `project.godot`'s `stretch/mode="canvas_items"` gives the HUD a 1920x1080
canvas in any window (decision 0057 §7 -- the integration lead owns that file); screen-reader
qualification is NOT executed; and 3840x2160 was deferred when the OS granted 3456x1986.
Screenshots, the state trace, the exact commands and the pass/fail/blocked table are in
[docs/validation/evidence/ui-first-playable/](../validation/evidence/ui-first-playable/README.md).

Bullets 3–5 implemented 2026-09-10
([decision 0049](../decisions/0049-source-intent-is-recorded-on-what-it-produced.md)).
`settlement_system.gd` calls `bind_ecology()` in composition and dispatches **nine**
§5 stages, adding ARCH-SYS-009 JobPlanner (per tick, plus its own midnight) and
ARCH-SYS-023 PresentationExtract (`scripts/core/presentation_extract.gd`, last).
A paused `DESIGNATE_ZONE` over a generated forest basin leaves stocks untouched and the
command pending; the resumed tick commits it, ARCH-SYS-009 publishes **one** QUEUED FORAGE
job, `source_intent_count()` reports **one** intent, and a `CANCEL_JOB` command cancels it.
**Source intent identity was the gap and it is now closed**: the producer's
`(designation, kind)` idempotence is the PRODUCER's, and a replayed envelope re-admitted at a
later tick committed a SECOND designation and a SECOND standing demand for one intent — measured,
then fixed by recording ARCH-CMD-001's `(player_id, sequence_high, sequence_low)` plus the
produced zone's generation on the zone itself and refusing `COMMAND_DUPLICATE_INTENT`.
Per-stage microsecond and measurement counts are published; **no budget is asserted and no
qualification is claimed**. The header now states the CareHealth ordering debt in full and that
ARCH-SYS-009 runs one place ahead of ARCH-SYS-008's fused resolve/select pass.
**Still outstanding within 04.4:** bullets 1 and 2 — the entire UI shell — are NOT built and
nothing here claims an unbuilt panel works; `world_init.gd` is NOT composed into
`settlement_system.gd` (the New Settlement control that would compose it is bullet 1's; its
Request's item ids DO have an authored source as of 2026-09-11 — see 04.3's catalog-binding note),
so the acceptance runs through the accessors that file publishes for a generator; Mac screenshots and the command/state trace are
not captured; and the save round trip is blocked on task 09's codec.

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

## 2026-09-11 identity ruling — implementation remains open

[R-INIT-ID-001](../rulings/2026-09-11_initial_ids_and_narrow_alerts.md) resolves
the historical 1714–1725 divergence above: reset the composed transaction once
before allocation, allocate the cohort first as global IDs 1–12, then allocate
world entities without clearing that cohort. The previous “needs a ruling”
statement is historical. Replace its diagnostic test deliberately; retain the
derived world census and add the ruling’s uniqueness/failure/determinism evidence.

## 2026-09-11 building-domain ruling — definitions resolved

Read [R-BUILD-DOM-001–004](../rulings/2026-09-11_building_room_domains.md)
and its adjacent JSON specification fixtures. Decision 0056's unlock domain,
Station domain, furniture-mask assignment and fifth-shelf interpretation are
resolved. Publish Milestone/Station through the existing registry, then implement
packed stores and dependency-ready starter composition; do not reopen these as
undefined fields or declare absent service/topology owners complete. Run the
ruling's exact mapping, mask, ownership, capacity and failure tests.

## F6 and asset integration follow-up — 2026-09-11

[UI-FOCUS-R01](../rulings/2026-09-11_focus_and_rollback_state.md) corrects F6's
shortcut/panel confusion. UI owner wires open_world_list, removes hidden087
from HUD focus and replaces the obsolete test expectation, including edit/modal
input guards and focus restoration. Document changes do not certify runtime.
[ART-GAP-R03/05](../planning/asset_dimensions_and_budgets.md) supplies camera
obstacle authoring envelopes and settlement L0 admission; verify actual exported
bounds/cutaway behavior at real camera profiles before claiming visual acceptance.
