# 0537 — Demolition work is a BUILD Job, and "evacuate, then demolish" waits for hauling
Date: 2026-10-02 · Status: Accepted (D6 of DEMO-CONTAIN-R01; the HAUL half refused and waiting on task 06.4). Brendan ruled on P1–P6 and the tool question on 2026-10-02 (below)

Numbered 0537 because the brief named it. No record numbered 0537 exists on any branch
(`git ls-tree` over every local and remote ref), in any registered worktree or in the main
checkout when this was written; `docs/validation/decision_numbers.py` refuses a collision at
merge.

## Brendan's rulings, 2026-10-02 (relayed by the coordinator)

- **P1, P2, P4, P5 and P6: approved as recommended.** The cadence is the hour crossing (P1); one
  builder per removal until a party owner exists (P2); CANCEL_JOB cancels the Job, not the
  demolition, and the hour offers a fresh Job (P4); an order with nothing to evacuate simply
  admits (P5); a claim-only refusal is evacuable (P6). No behaviour changed: each was built as
  recommended.
- **Tools: no wear for now.** Demolition BUILD work binds and wears no tool, as built.
- **P3, hauling: "Build hauling (06.4) next."** A separate lane scopes and builds task 06.4. D6
  stays as built: the evacuation HAUL jobs remain refused and are recorded as waiting on 06.4.
  The intent and its hourly retry need no change when hauls arrive; they are what will empty
  the sources.

## Decision

**Step D6 of [DEMO-CONTAIN-R01](../rulings/2026-10-01_demolition_containment.md) lands in part.**
Its row reads: "Evacuation hauling: demolition work under BUILD, evacuation HAUL jobs from a
persisted evacuate-then-demolish intent, retry *admit* once sources report empty." It depends
on D5 and on task 06.4. Two of its three clauses are built; the HAUL clause is refused by name
(item 4), because task 06.4 does not exist and building it here would mean inventing it.

1. **Demolition work is a BUILD Job** (blocker 4: "add demolition work under BUILD").
   - Every admitted removal -- a building's demolition, or one piece's removal recorded on its
     building's admission row (decision 0536's R2) -- gets exactly one `JOB_KIND_BUILD` Job,
     linked by its building's row in the new store `godot/scripts/core/demolition_work.gd`.
     Its `requester` is the project, its `destination` the subject (building or piece), its
     `remaining_mwu` the project's own outstanding milli-WU. Priority is the planner's ruled
     ORDINARY_JOB_PRIORITY (3), urgency the ordinary bucket ("3 ordinary
     production/construction"), minimum skill 0 (decision 0022; no document states one).
   - **Posting.** `request_demolition()` and `request_furniture_removal()` write no Job; on
     success they mark the coordinator dirty, and `_reconcile_removal_work()` posts the Job in
     ARCH-SYS-009's slot -- before selection, so it can be offered that tick. A Job the store
     refuses (its 8192 rows full) is simply posted later.
   - **The productive tick.** ARCH-SYS-013's walk recognises a linked work Job
     (`project_of_job()`, allocation-free) and runs it through `_tick_removal_work()`:
     validate, then consume (decision 0059). Before `work.gd` consumes anything the project must
     take the credit (READY or WORKING, not paused, its subject standing) and the Job and the
     project must hold the same outstanding milli-WU (`work_refusal()`); then `tick_solo_into()`
     runs and the milli-WU the Job's own remainder lost are credited with
     `construction.add_work_mwu_into()` (new, the non-allocating form `add_work_mwu()` now
     delegates to) -- the measured loss, not the tick result, so a tick `work.gd` refused after
     consuming still reaches the project (review L-2).
   - **A BUILD Job is worked only through this bridge.** REQ-SET-124's build jobs for new
     construction do not exist, so `_tick_one_activity()` never ticks a BUILD Job as ordinary
     work: one the bridge cannot resolve to its row's linked project (its building removed, its
     project retired around the coordinator, a stray) earns nothing, and the hourly reconcile
     retires it (`is_orphaned_removal_job()`; a BUILD Job requested by a live non-removal project
     is left for REQ-SET-124's future owner -- never ticked, never swept; the selector may bind a
     resident to one, who then sits idle until that owner exists, and nothing produces one
     today). Review H1: before this, such a Job fell through to the ordinary solo tick and earned
     XP for work no project took. A Job spent to 0 is marked COMPLETE by the coordinator even
     when `work.gd` refused after its consume, so its commit is never lost (second review L1). REQ-SET-125's `begin_work()` runs
     on the first tick that produced work ("as progress begins"), never at admission. The
     project is the authority; the Job is how a resident is offered the work.
   - **Completion.** A Job that completes is counted, and once the walk ends (the commit retires
     the Job's row, and the walk is over the live-row index) `_finish_removal_jobs()` retires it
     -- worker released, row destroyed -- and commits through the coordinator's own door:
     `complete_demolition()` or `complete_furniture_removal()`. No store door is called
     (decision 0536's P3 and readings). A commit that refuses leaves the project
     PHASE_WORK_DONE: commit-pending, retried on the hour (item 3), at no cost (ECON-003).
   - **Every way out retires the Job.** `cancel_demolition()`, `cancel_furniture_removal()`,
     `release_stranded_reservation()` and a successful `complete_*()` called by any caller each
     retire the linked Job; the hourly reconcile also retires a Job whose building is gone,
     whose admission is gone, whose project is paused (REQ-SET-137: "release workers"), whose
     project is done, that a player's CANCEL_JOB cancelled, or that is out of step -- and posts a
     fresh one carrying the project's remainder where the project is still workable.
2. **The evacuate-then-demolish intent** (blocker 4: "a persisted 'evacuate then demolish'
   intent in the coordinator").
   - `settlement_system.gd::order_evacuate_then_demolish(building)` runs `request_demolition()`.
     If it admits, the order is satisfied. If it refuses at a goods stage -- stage 3 or 5,
     `DEMOLITION_BLOCKED_STORED_GOODS` or `DEMOLITION_BLOCKED_CAPACITY_CLAIM`
     (`is_evacuable_refusal()`) -- the building's full directory ref is recorded on its row
     (`DemolitionReport.evacuation_ordered`), and the refusal stays in the report with its exact
     stranded lots for REQ-SET-128's notice. Any other refusal records nothing.
   - `cancel_evacuation()` withdraws it; `has_evacuation_intent()` reads it; any admission of
     the building (by either door) spends it; a building gone or a reused row forgets it.
   - **The retry.** On every hour crossing, for every waiting order, the coordinator asks the
     sources: every container anchored on the building's footprint (one bounded anchor scan,
     `_evacuation_sources_empty()`) must hold no lot and no claim. Stage 5 requires every
     container the gate's owner scan reaches to be anchored on the footprint, so this sees a
     superset of the gate's sources; only an empty answer pays for the full `request_demolition()`.
     A retry refused for any other reason (a resident now uses a bed, say) keeps the order.
   - **Persistence.** The order is future-affecting state and is classified, not yet saved:
     `persistence_state_registry.md` gives `_intent_slot`/`_intent_generation` an UNRESOLVED row
     whose question is which §4 owner carries it (the building owner, BUILDINGS-SAVED-BINDINGS, or
     the construction owner beside the admission record, CONSTRUCTION-SAVED-BINDINGS). That is the
     precedent of the admission record and the paid ledger (decisions 0534, 0536); nothing open
     in a demolition survives a load yet (CONSTRUCTION-SAVED-BINDINGS).
3. **The cadence.** The two cold retries -- a commit-pending removal's commit and a waiting
   order's source check -- run on the hour crossing (ARCH-TICK-002's `(k+4500) mod 750`, the
   same predicate ARCH-SYS-004 uses). Both scan stores (the commit re-proves stages 2-5; the
   source check walks the anchor column), so neither runs per tick. No document fixes this
   cadence: it is **P1**. Posting a Job is not on the cadence: it happens on the planner tick
   after any admission, and on every hour. The reconcile runs before the job planner, so a
   deferred admit or commit lands where a player's command would; a row with no order, no Job
   link and no admission record costs three array reads (`is_quiet_row()`,
   `demolition_admissions.is_recorded_at()`, new), so the walk over the 1024 Building rows is
   cheap on the hour (review M-2). Two diagnostic counters, `evacuation_retry_count()` and
   `removal_commit_retry_count()`, make the cadence and the source check testable (review M-1).
4. **The evacuation HAUL jobs are refused, by name.** Physical hauling is task 06.4 and it does
   not exist in the settlement layer, so the ruling's "evacuation HAUL jobs" cannot be built
   without inventing it. What is missing, each verified:
   - **No carried container.** GDD §4.2 gives every resident "one carried container"
     (`Equipment.satchel`) and ARCH-MEM-002 budgets 512 satchels, but no production code
     creates one and no document says when one is made; `residents.set_satchel()` has no
     production caller.
   - **No arrival.** Nothing in the running game moves a Job out of RESERVED: movement is not
     composed into the settlement, and the movement ruling says "work arrival requires the real
     contact; before arrival no productive WU" (2026-09-11 READY_07 answers).
   - **No teleports.** INV-GOODS-R01 forbids the gate moving goods itself ("It does not
     teleport goods to another container. Real jobs haul and commit each transfer first"), and
     the CONSTRUCTION-EVACUATION-INTEGRATION and DEMOLITION-D6 acceptance lines repeat "no
     teleports". A HAUL Job that moved a lot straight from the store to its destination when
     its work finished would be exactly that.
   - **Unruled haul phases.** BAL-CAT-010 prices "handling a haul payload 2000 milli-WU to load
     plus 2000 to unload", REQ-SET-111 limits a payload by the hauler's species carry "when a
     haul job begins", and BAL-SAFE-002 keeps a lot in transit in exactly one container. Which
     JobState the unload runs in (ARCH §6's lifecycle has WORK then HAUL_OUTPUT, and `work.gd`
     ticks only WORK), and where evacuated goods go (decision 0534's R1 store rule was ruled for
     the RETURN, not for evacuation), are not ruled.
   So no HAUL Job is posted and nothing reserves the building's goods for one: a reservation
   for a haul that can never run would take a pantry's food out of ready food-days for nothing.
   The order and its retry work with whatever empties the stores today -- meals drawn from a
   pantry, spoiled food removed as waste -- and will work unchanged once
   06.4's hauls are the thing that empties them. **P3.**

## Proposals for Brendan (ruled 2026-10-02 -- see "Brendan's rulings" above)

- **P1 -- the retry cadence.** Options: (a) the hour crossing, as built; (b) every tick with a
  cheaper precheck, which needs an Inventory change counter nobody publishes; (c) only on an
  event (a haul's completion), which does not exist yet. Recommendation **(a)**: bounded cost,
  and a commit-pending removal or an order waits at most 750 ticks (25 s at 1x).
  Measured after the review fixes, on the loaded build machine (a scratch probe, not a test):
  one order's source check 25 us; a dirty reconcile with nothing waiting 289 us; the hourly
  reconcile with 40 waiting orders 1499 us; a plain settlement tick 204 us. The hour tick with
  many waiting orders is the costly one; if that matters, the alternative is to spread the
  orders over the hour's ticks (round-robin), which changes when, not whether, an order retries.
- **P2 -- one builder or a party.** GDD §5.9 says "Maximum 4 builders/project" and "Build rate
  sums up to 4 workers' actual work rates". A solo Job honours the cap with one builder. A party
  of up to `max_workers` needs decision 0017's coordinator in JOB_STATE_WORK, and no document
  says who writes that. Options: (a) solo until a party owner exists, as built; (b) rule that a
  removal's coordinator is WORK while any member is, and post `max_workers` member Jobs.
  Recommendation **(a)** now and (b) when movement composes, since no Job reaches WORK before.
- **P3 -- evacuation hauling.** Options: (a) wait for task 06.4 and settlement movement, then a
  D6b adds the HAUL Jobs on top of this intent; (b) authorise a D6b haul slice now, answering:
  who creates a resident's satchel and when; that a haul is RESERVED -> TRAVEL -> WORK (load,
  2000 milli-WU, source debited into the satchel) -> HAUL_OUTPUT (travel) -> unload 2000 milli-WU
  -> COMPLETE, and in which JobState the unload is worked; that evacuated goods go to the lowest
  surviving store with room off the footprint owned by another ACTIVE building (0534's R1), else
  ground piles from the refund seeds (R2); and that the payload is sized at assignment by the
  hauler's carry (REQ-SET-111). Recommendation **(a)**, with PLAN-LIVE-CONSTRUCTION (which owns
  "job admission/source/destination reservations/hauling/arrival") writing that packet first.
- **P4 -- CANCEL_JOB on a removal's Job.** Read here as cancelling the Job, not the demolition:
  the worker is released, the hour retires the cancelled row and offers a fresh Job, and the
  demolition stands (it is cancelled through `cancel_demolition()`). Alternative: CANCEL_JOB on a
  removal Job cancels the removal. Recommendation: keep the reading; D7's UI offers the real
  cancel.
- **P5 -- an order with nothing to evacuate.** Read here as "demolish now": the door admits and
  records no order. Alternative: refuse `EVACUATION_NOT_NEEDED` and let the UI call the plain
  request. Recommendation: keep.
- **P6 -- a claim-only refusal is evacuable.** A capacity claim (stage 3/5
  `DEMOLITION_BLOCKED_CAPACITY_CLAIM`) is waited out like goods, though a claim is released by
  its owner, not hauled. Alternative: accept only stored goods. Recommendation: keep; the order
  waits for "sources empty", and a claimed store is not empty.

A question rather than a proposal (ruled 2026-10-02: no wear for now): GDD §5.9's "Generic BUILD/CRAFT/FARM/KEEP extraction work
consumes 1 equipped tool durability per completed 10 WU". Demolition work is BUILD, but no
production code binds a tool to any Job yet (`work.claim_tool_for_work()` has no production
caller; EH-03's gap, decision 0110), so it wears none. Whether demolition counts as "extraction
work" is for whoever wires tool claims.

## Why -- the executor's readings, stated so they can be overruled

- **The Job is not posted inside `request_demolition()`.** Admit's every check runs before its
  first write (decision 0534) and its refusals are pinned byte-identical across Building,
  Construction, Inventory, the directory and the admission record; a Job written there would be
  a sixth store in that proof and a new way for admit to fail after writing. Posting on the next
  planner tick costs nothing: selection runs after the planner in the same tick.
- **Job and project are kept in step rather than the Job reading the project.** `work.gd`
  consumes a Job's own `remaining_mwu` and decides completion from it; the project's is
  construction's. Two counters are reconciled by refusing any tick on which they differ (before
  anything is consumed) and by replacing a Job out of step on the hour.
- **The source check is the footprint, not the stranded-lot list.** The order is recorded
  against a refusal whose lot list is a snapshot; new goods can arrive and old ones leave. The
  anchor scan reads the stores as they are, and *admit* re-proves everything anyway.
- **No rule was reinterpreted.** The HAUL clause is refused where the ruling says a step that
  "finds a rule unimplementable refuses and asks"; no Alternative column was taken.

## Consequences -- what D7, D8 and D9 must know

- **D7 (dispatch, notice, quicksave).**
  - Offer "evacuate, then demolish" when `is_evacuable_refusal(report.error)`; the door is
    `order_evacuate_then_demolish()`, which returns the gate's report with `evacuation_ordered`
    and the exact stranded lots. `cancel_evacuation()` withdraws it. It needs its own command
    arm (or a payload flag on DEMOLISH); none exists.
  - **The notice must not promise hauling**: nothing moves the goods until 06.4 lands (P3).
  - **REQ-SET-158's pre-major-demolition quicksave**: a waiting order is admitted later by the
    hourly reconcile, inside a tick, with nobody pressing anything. D7 must decide whether the
    quicksave is taken when the order is placed or when the deferred admit happens; the deferred
    admit is a plain `request_demolition()` call inside `_reconcile_removal_row()`.
  - The work Job shows in `job_queue_length()` from the planner tick after admission. A player's
    CANCEL_JOB on it is undone on the hour (P4); the demolition is cancelled through
    `cancel_demolition()` / `cancel_furniture_removal()`, which retire the Job.
  - **The `DemolitionReport` is shared scratch.** Every door returns the same object, and the
    coordinator now calls `request_demolition()` and `complete_*()` inside the tick -- on the
    hour, and at the end of the work stage on any tick a removal Job completes -- so a report a
    UI holds is overwritten without any call of its own (review M-3). Copy the
    fields a notice needs when the door returns.
  - **An order may never converge.** Nothing stops goods flowing INTO an ordered building's
    stores. And an order recorded for goods in an owned container off the footprint (which stage
    5 later refuses) is invisible to the anchor scan, so the sources read empty and the full gate
    reruns -- and refuses -- every hour until the order is withdrawn (review L-4).
    The notice should say the order waits, and offer `cancel_evacuation()`.
- **D8 (movement).**
  - The destination revision now also advances at a deferred admit (planner slot, hourly) and at
    a commit run from the work stage (end of ARCH-SYS-013's walk) or from the hourly retry
    (planner slot). The footprint is freed inside that commit (`_remove_structure()`), so the
    topology revision and route re-check belong there, wherever the commit was called from.
  - A removal Job's `destination` is its subject (the building or the piece): the contact a
    builder must reach before JOB_STATE_WORK. Movement is what will write TRAVEL -> WORK; until
    then the bridge is reached only by tests that stand in for arrival.
- **D9 (acceptance).** In the running game a removal Job is posted, offered and reserved, but
  never worked (no arrival); the bridge, the commit and the retries are proven by tests that
  write WORK, as `test_settlement_system.gd`'s productive-work tests do. CONSTRUCTION-EVACUATION-
  INTEGRATION cannot close while P3 is open: REQ-SET-127's "first evacuate residents and move
  stored goods" needs real hauls.
- **Saving.** The order and the Job link are UNRESOLVED-classified (registry rows above);
  CONSTRUCTION-SAVED-BINDINGS must save them with the admission record.

## Memory

+16384 B: `demolition_work.gd`'s four I32 columns per Building row (1024): the order's building
ref and the work Job's ref, folded into the Auxiliary payload row as decisions 0534/0536 folded
the admission record. No scratch is allocated: the hourly source check borrows the
coordinator's decision 0534 footprint mask and seed buffer and decision 0145's pair buffer.
Live total 79112852, headroom 20887148; the rejected two-world peak a further 32768 B worse
(−43591899). `ready07_arithmetic.py` checks it; the capacity audit is regenerated because
the source hashes of `construction.gd` and `jobs.gd` changed. Shared files touched beyond the
new store: `construction.gd` (`add_work_mwu_into()`), `jobs.gd` (`live_job_at_into()`),
`demolition_admissions.gd` (`is_recorded_at()`), `settlement_system.gd` (the coordinator).

## Evidence

- **Suite, CI-style** (a copy of the final tree with `godot/.godot` deleted and re-imported, no
  `godot/demo/assets`): `8131 test(s), 587707 assertion(s), 0 failure(s)`; diagnostics
  `0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit:
  0 object(s), 0 resource(s)`.
- **Contracts.** 29 contract and preflight scripts from `.github/workflows/tests.yml` pass,
  including `ready07_arithmetic.py` (+16384), `state_registry_coverage.py` (the new store's
  rows), `audit_registry_capacities.py --check` (regenerated) and the construction preflights.
  `gdscript_warnings.py` reports 0 on the 7 changed `.gd` files. A 600-frame boot of
  `scenes/main.tscn` exits 0 with no error line. No demo file changed and no demo assets are
  staged in this worktree, so the demo's live harnesses were not run.
- **Mutation testing: 86 mutants** over `demolition_work.gd`, the coordinator's D6 code and
  hooks in `settlement_system.gd`, and `construction.add_work_mwu_into()`, each in a cloned tree
  against the focused suites (`test_demolition_work`, `test_settlement_demolition_work`,
  `test_settlement_demolition_complete`, `test_settlement_demolition_admit`,
  `test_settlement_furniture_removal`, `test_construction_demolition_completion`,
  `test_construction`), on the final code. **81 killed.** The first run (72 mutants on the
  pre-review code) killed 56; its survivors became tests (a FURNITURE project names no
  building, the dirty-tick cadence, the source counters, the flag reset, a direct piece
  completion, work finished around the Job, a stale link admitting nothing) or went with the code
  the review replaced. The five survivors are equivalent:
  - a cleared link left in place reads as none, because `job_at()` validates the generation;
  - links only ever name BUILD Jobs and `_tick_one_activity()` reads the kind first, so
    `project_of_job()`'s own kind check is a fast path;
  - the bridge's WORK-state check is a fast path, since `work_refusal()` and `work.gd` refuse
    a non-WORK Job and the measured loss is then 0;
  - the quiet-row skip saves cost only;
  - clearing a link on a refused destroy is unreachable after `retire_job()`'s presence check.
- **Tests added.** `test_demolition_work.gd` (34): every public function of the store,
  `add_work_mwu_into()` against `add_work_mwu()`, `is_recorded_at()`, an allocation census of
  the per-tick reads. `test_settlement_demolition_work.gd` (42): posting on the planner tick,
  selection reserving a builder, the productive tick in step, completion committed in the same
  tick for a building and a piece, the commit-pending retry, every way out retiring the Job,
  orphans never worked and swept, the order on goods, a claim, nothing to evacuate and other
  refusals, the hourly source check (store, claim, a room's store), withdrawal, reset.
- **Independent `code-reviewer`, one pass** (it ran its own 12 mutants on a copy). No CRITICAL.
  - **HIGH H1** (an unresolvable removal Job fell through to the ordinary solo tick, consuming
    and earning XP for work no project took; reproduced with a building removed around D6 and
    with a project retired around the coordinator): fixed -- BUILD Jobs are ticked only through
    the bridge, and the hourly sweep retires orphans. Tests: the building gone, the admission
    gone, a stray BUILD Job.
  - **HIGH H2** (the building-gone and admission-gone retire guards had no effective test; one
    test could not fail because `cancel_demolition()` already retired the Job): both tests
    rewritten without the cancel, each asserting no work, the Job retired and the worker freed.
  - **MEDIUM:** M-1 (the source pre-check and the hourly cadence were unpinned) fixed with the
    two retry counters and off-hour ticks made dirty on purpose; M-2 (the 1024-row walk cost
    about 0.7 ms per hour and per dirty tick) fixed by the quiet-row skip; M-3 (the shared report
    overwritten inside the tick) recorded for D7 above.
  - **Second pass: no CRITICAL or HIGH**; all first-pass findings verified fixed (its own 28
    mutants: 22 killed, three equivalent). MEDIUM M1 (crediting the measured loss had no test;
    an XP overflow after `work.gd`'s consume reproduces the difference): tested. LOW L1 (a Job
    spent to 0 by such a tick stayed in WORK and never committed): fixed by
    `_finish_spent_job()`, tested. L2 (the sweep's backward walk untested): two-orphan test. L3
    (the sweep allocated per live Job): `jobs.live_job_at_into()`, new. L4, L6: recorded above.
    L5 (the reconcile's order against the planner is unobservable today) left for D8. L7: test
    names corrected; `release_worker()`'s result is now checked.
  - **LOW:** L-1 the CANCELLED write before a destroy was dead and a refused destroy cleared the
    link -- the write is gone and the link now survives a refused destroy; L-2 credit by the
    measured loss; L-3 the reconcile moved before the planner; L-4 recorded for D7; L-5 the reset
    test now posts a Job first and compares every column; L-6 one row reader (`row_of()`); L-7
    docstrings corrected.


## Source

DEMO-CONTAIN-R01 blocker 4 and the D6 row (Brendan, 2026-10-01, DEC-043); decisions 0534
(R1–R5), 0535 and 0536 (P1–P3, R1–R8) and their "What D6 must know"; INV-GOODS-R01
(`docs/rulings/2026-09-14_cycle02_construction_goods.md`); the READY_07 movement answers
(`docs/rulings/2026-09-11_ready07_open_item_answers.md`); GDD §4.2, §5.2, §5.3, §5.7, §5.9,
REQ-SET-111/125/127/128/137/158; BAL-CAT-010, BAL-WORK-003, BAL-SAFE-002; ARCH §6
(ARCH-JOB-001..005); decisions 0017, 0022, 0059, 0110.
