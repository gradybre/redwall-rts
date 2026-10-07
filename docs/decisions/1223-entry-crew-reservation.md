# 1223 — The entry crew and its Jobs are reserved from the JobSelector (ADR 1197 G6)

Date: 2026-10-07 · Status: Accepted; implemented. Closes ADR 1197 G6's reservation half. The live chain now runs
past G6 and stops at a new gap (G12, below).

## The problem

ADR 1219 left the live `run_tick` chain stopped at tick 518 with `JOB_HAS_WORKER`. While the crew hauled, the
step's BUILD Job sat QUEUED with no worker (the crew held its HAUL Job; a resident holds one Job at a time,
ARCH-JOB-001). The JobSelector, which knows nothing about the entry, offered it to an idle surface mouse and bound
it. When the crew walked home, its own Job was taken.

The same hole exists on the crew side. The crew is idle on its 373-tick surface walk and while it waits for its hour
to resolve, so the JobSelector could give it ordinary surface work. The foreman's first commitment would then refuse
`JOB_AGENT_BUSY`.

## What already exists, and why it is not enough

- **Job-side gates** (GDD §5.3 step 4 station/tool/unlock, step 6 inputs) are per-Job columns. They say whether a
  Job can be worked, not *who* may work it. The entry's BUILD Job sets the tool gate SATISFIED, so every resident
  passes. Using step 6 (inputs BLOCKED while hauling) would be true only during the haul. It would still leave a
  Job with complete inputs takeable whenever a refusal interrupts the synchronous create-then-assign.
- **Decision 0017's coordinator exclusion** is the right shape: a categorical "cannot be selected by a resident",
  ahead of the six steps. But it is a property of the record and is permanent. The entry's Jobs must still be
  committed to one specific resident.
- **REQ-SET-030** ("atomically reserve its worker … before movement begins") names the concept of a reserved
  worker. Jobs has no column that can hold it: `worker` is the live 1:1 binding mirrored by `JobAgent.job`.
- **ManualTask "work here"** (`manual_until`) is a player preference with a 6-hour expiry. It is unimplemented
  (blocker U6), and it does not override the schedule. It is not this.
- Adding a per-Job "reserved worker" column would change Jobs' §4 codec. That is task 09's settlement-save
  territory, and it would duplicate facts that the entry record already holds.

## Decision: the entry runtime is a bound work dispatcher

`jobs.gd` gains one optional binding, `bind_dispatcher(owns, reserves)`: two Callables asked by eligibility.

- **`owns(job_slot)`**: the Job is the dispatcher's. The entry runtime answers *any Job whose requester is a live
  Construction Project of purpose `EXCAVATION` or `CONNECTOR_INSTALL`*. That covers:
  - the cut phases' BUILD Jobs;
  - the installations' Jobs;
  - every HAUL Job, which is requested and sourced by the step's Project.

  These are exactly the Jobs only a registered crew can do: ADR 1219 makes only crew moles route actors. The rule
  is derived from Jobs' `requester` column and Construction's `purpose`. Both are saved by their owners, so the rule
  holds after a stop and across a load with no new byte.
- **`reserves(resident_slot)`**: the resident is the dispatcher's crew. It is reserved while the chain can run (from
  the foreman's planning, through the walk). Once it is a route actor it stays reserved for good: ADR 1219 §4 keeps
  it registered underground, and there is no unregister. A chain stopped *before* registration releases it. Both
  facts come from the ADR 1218 record (crew, step, foreman stage) and the ADR 1221 Routes image.

Enforcement uses the existing selection path:

1. `evaluate()` refuses a reserved resident before any scan, with `JOB_AGENT_RESERVED_BY_DISPATCH`. It writes no
   continuation. The settlement still resolves the crew's activity first: resolution is fused with selection, and
   it is on `should_evaluate`, which is unchanged. So the crew's hour keeps being read while it is idle.
2. `_candidacy_refusal` gets a dispatch gate after the coordinator/worker/state exclusions and ahead of the six
   steps. A dispatched Job refuses `JOB_DISPATCHED_TO_CREW` to anyone but the crew, and the crew refuses
   `JOB_AGENT_RESERVED_BY_DISPATCH` for any other Job. Because the crew never reaches a scan (point 1), the
   JobSelector offers a dispatched Job to **nobody**. Only the dispatcher's own `assign_worker()` commits one, and
   that commitment still revalidates steps 1–6 (REQ-SET-030 unchanged, decision 0023).
3. Unbound, or with the dispatcher freed, every Job and resident is ordinary. Fixtures that drive `Foreman.advance`
   directly are unchanged.

The runtime binds itself when it plans the foreman, and again on every successful `restore`. The ADR 1218/1221
restore-every-tick test swaps in a fresh runtime each tick, and the binding follows it.

## Each case

| Case | Behaviour |
|---|---|
| BUILD Jobs of cut phases and installs | Dispatched. While parked during a haul they stay QUEUED with no worker and are refused to everyone; the crew takes its own back at the haul's end (`_go_home`). |
| HAUL Jobs | Dispatched. Created and committed to the crew in one synchronous call, never QUEUED-unbound at a selection boundary, and excluded anyway. |
| The gap between hauls | `_retire_job` → `_new_job` and `_go_home` all run inside one foreman tick, so there is no selection boundary in between. Test: at **every** tick from arrival to the stop, the crew holds an entry Job and no other resident holds one. |
| Crew selection | Picks only an *idle* tooled adult mole. A mole holding another Job is passed over and keeps it; if every tooled mole is busy the step refuses `JOB_AGENT_BUSY` (G6), and `start` can be retried. |
| Schedule/rest (STEP2) | An **idle** crew is committed only when its resolved hour is WORK/ANYTHING and step 1 passes. Otherwise the runtime waits, reserved and alert-free: the walk ends on H, and registration and the first commitment happen in the next work hour. So `STEP2_ACTIVITY_FORBIDS_WORK` no longer arises in the live chain; its alert row now names the wait. A crew already holding a dispatched Job carries on: no busy resident is re-resolved anywhere in the settlement, which is REQ-SET-034's unimplemented safe segment (`jobs.gd` GAPS). The crew follows the same rule; nothing new is invented for it. |
| Crew death | Checked by the runtime before every tick (walk included). A dead crew stops the chain with `STEP1_RESIDENT_DEAD` (G6 alert), and the foreman is failed with that code so the record carries it. |
| Crew leaves | Its row no longer names the crew (`get_typed_row` stale), so the chain stops with `ENTRY_CREW_LOST` (G6). |
| Incapacity/collapse mid-dispatch | Surfaces from the owners' own step-1 checks (Work, `assign_worker`) with the exact `STEP1_*` code, mapped to G6. An idle crew that is unfit waits instead. |
| Orphans | No Job is ever left offerable. After a crew loss, the in-flight Job stays bound to the dead crew, as every dead resident's Job does today (ARCH-SYS-019 Lifecycle is not composed). Any parked Job stays QUEUED, still the dispatcher's by its requester, and is refused to everyone. Test: after death, a capture and restore of the runtime, and three more selection windows, exactly two entry Jobs remain (the parked BUILD Job and the in-flight HAUL Job), neither held by another resident. Nothing is cancelled or rolled back (ADR 1197 alert rule). |

## Persistence

No new saved state.

- The reservation is derived from the ADR 1218 record, the Routes image (ADR 1221), and Jobs' and Construction's
  own columns.
- `jobs.gd`'s `_dispatch_owns`/`_dispatch_reserves` are category-3 composition, and `_scratch_reserved` is per-pass
  scratch. The runtime's `_scratch` IntResult is per-call scratch.
- The record format, `MAX_WIRE_BYTES` and the canonical registry are unchanged.
- `persistence_state_registry.md` gains the dispatcher-binding row and notes on the Jobs scratch row and the runtime
  row.

`ENTRY_SAVE_*` behaviour is unchanged. A runtime halted by `_halt` (crew loss, arrival placement) now fails its
foreman too, so a stopped chain's record is terminal and cannot resume half-stopped. Before this change, an arrival
failure left the foreman running.

## The live chain now (`test_underground_host.gd`)

`run_tick` alone, from the surface walk:

1. The walk takes 373 ticks. On every one, the crew holds no Job, and on its stagger tick `evaluate` refuses
   `JOB_AGENT_RESERVED_BY_DISPATCH`.
2. Arrival and registration on H, the retreat, the tooled walk to M, the tool put down, and both hauls through
   Delivery.
3. The walk home under the crew's own BUILD Job (no `JOB_HAS_WORKER`), re-equipping, travel to the first BRACE
   station, and entering WORK.
4. The paid BRACE START then refuses **`WORLD_COMPOSITION_BINDING`** at tick 619. This is G12. (The log's
   `stop_tick=620` is the loop's next tick, as ADR 1218's "tick 518" was.)

The ADR 1218/1221 variant reaches the same stop with byte-identical owner images, record and route images. It
restores the runtime before every tick (373 mid-walk, 246 after registration) and cold-restores the route owners
every 23 ticks.

### G12 (new): the live Session binds no phase-structure provider

The refusal comes from `underground_world_bindings.gd::_structure_binding_refusal`, reached via
`stage_physical_geometry` ← `UndergroundSpaceAuthority._prepare` ← `Sites._space_refusal` ← `begin_phase_work`.
`_structure` is null: nothing in the live composition calls `WorldBindings.bind_phase_structure(...)`. Only the
fixtures do it, with the entry's `underground_entry_structure.gd` provider and the World's level catalog
(`test_underground_entry_world_bindings.gd`, `test_underground_entry_structure.gd`). The fix is composition work in
`compose_underground_entry_owners` or the Session; it is not built here. `WORLD_COMPOSITION_BINDING` is a generic
code with many causes, so it is deliberately **not** mapped to G12 in `GAPS`. The live alert stays "unclassified
refusal", which is the honest reading until the cause is fixed.

## Tests

- `test_jobs.gd` (unit, fake dispatcher):
  - a dispatched Job outranking an ordinary one is passed over by selection, and other residents' commitments
    refuse;
  - the crew is never selected and leaves no continuation, is refused ordinary work, and is committed to its own
    Job;
  - the dispatcher's commitment still refuses STEP2 and a dead crew;
  - an invalid binding refuses, binding writes no state, and clearing it or freeing the dispatcher restores
    ordinary behaviour.
- `test_underground_host.gd` (live settlement):
  - the drive test (per-tick dispatch invariant, the next gap at tick 619);
  - no other resident can be committed to the parked BUILD Job mid-haul (some are refused by the dispatch rule
    itself), and the crew carries it home;
  - a crew whose arrival hour is SLEEP waits on H, reserved and unregistered with no refusal, and registers in the
    07:00 hour;
  - crew death mid-haul (above);
  - a crew that leaves on its walk gives `ENTRY_CREW_LOST` and is released;
  - a busy only-tooled mole is not taken and keeps its Job;
  - the restore-every-tick variant also asserts the restored runtime is the bound dispatcher.

## Cost

- **CPU.** One Callable call per examined candidate whose requester is set, only while a dispatcher is bound. The
  call does two O(1) reads (Jobs requester, Construction purpose by Directory row), within the existing
  32-candidate budget.
- **Memory.** +9 B: the runtime's IntResult. The first-entry chain goes from 8,338 to 8,347 B, and the joint pack
  from 100,209,892 to **100,209,901 B**, with 49,790,099 B of headroom under DEC-053's 150 MB gate.
  - `jobs.gd` is a manifest-3 reviewed input. Its reviewed bytes are archived in `projection.json` and its storage
    delta (two Callables, one bool; 0 B charged, native Variant overhead) is in `reviewed-deltas.json`.
  - The census ENTRY_RUNTIME member set, `systems_architecture.md` and `ready07_arithmetic.py` move with it.

## Rejected

- **Inputs gate BLOCKED while hauling.** It is true only for that window, and it leaves the Job takeable whenever a
  refusal falls between "inputs complete" and the crew's commitment.
- **A per-Job reserved-worker column.** It changes Jobs' §4 codec (task 09), and it duplicates facts the entry record
  already holds.
- **Skipping the crew in `SettlementSystem._resolve_and_select`.** It cannot keep dispatched Jobs out of other
  residents' candidate loops, and it touches the settlement file the task-09 worker owns.
- **Releasing the crew's surface Job at selection.** Generic release would break other owners' claims (tool claims,
  Sites worker bindings). An idle mole is chosen instead.
- **Cancelling the phase on crew loss.** That is GDD cancellation with refunds and WIP salvage: a gameplay choice,
  and a rollback the ADR 1197 alert rule forbids here.

## Open (Brendan's choices, not made here)

- **After crew loss:** choose a replacement crew to resume the dispatch, or cancel the open phase through its GDD
  refund path. Either needs a recall or unregister rule for the dead actor still registered in Routes (ADR 1219 §4).
- **REQ-SET-034 for the busy crew** (stop at a 30-WU safe segment for sleep, then resume) is settlement-wide
  unimplemented behaviour. The crew follows the settlement.
