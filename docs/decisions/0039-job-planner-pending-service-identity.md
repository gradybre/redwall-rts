# 0039 — The JobPlanner's pending-service row is saved state, not a derived index
Date: 2026-09-10 · Status: Accepted

## Decision

`scripts/core/job_planner.gd` implements ARCH-SYS-009's dirty/reconcile mechanism
(R06-JOB-008) and the daily FARM tending producer (R06-JOB-007). Its
pending-service identity is the ruling's own
`(owner EntityRef, operation, absolute service day)`, stored as an owner-major
child index

```text
service_row(owner typed row r, operation op) = r * DAILY_SERVICE_OPERATION_COUNT + op
```

with `DAILY_SERVICE_OPERATION_COUNT = 1`, `OWNER_CAPACITY = 4096` FarmPlot rows,
and **126976 bytes** of new packed payload added to `systems_architecture.md`
§2.2 with every dependent total updated.

Four things are settled here:

1. **The pending row is saved state.** It is not reconstructed from live jobs on
   load, because a Job row carries no operation discriminator.
2. **`serviced_day` is durable completion history.** It is an absolute day, never
   a boolean, and it is what keeps "once per day" true across a load, a rebuild
   and a worker replacement.
3. **The planner does not read `TileHistory.tended_today`.**
4. **The operation stride is one**, not three.

## Why

**The identity is not derivable, so it must be stored.** The ruling permits
rebuilding "indexes derived from live jobs" and forbids discarding completion or
policy history. GDD §4.2's Job row has kind, three references, priority,
required skill, state, worker, `remaining_mwu` and `created_tick` — and no
operation field. "This FARM job is R06-JOB-007's tending service rather than
REQ-SET-073's ripe harvest" is therefore not recoverable from the Job store.
Matching on `remaining_mwu == 1000` was rejected: it is a coincidence of the
current balance table, not an identity. Adding a discriminator to §4.2's Job row
would be inventing a schema field. So the row is saved, budgeted, and
`revalidate_after_load()` only *repairs* it — dropping rows whose Job reference
no longer resolves — which is the permitted rebuild, not a reconstruction.

**The completed day is a day, not a flag.** `farming.gd` already carries
`TileHistory.tended_today`, and reusing it was the obvious move. It is wrong
here for a specific reason: its midnight reset is owned by ARCH-SYS-006
(increment 10), which does not exist. A boolean nobody resets reads as "already
tended" forever and would suppress every subsequent day's service — silently,
because the planner would simply create nothing. An absolute day cannot fail that
way: `serviced_day == today` is false on the next day whether or not anyone ran a
reset. `tended_today` remains authoritative for what it is actually for, the
per-day effect that halves REQ-SET-087 blight loss and REQ-SET-084 cabbage frost.
`record_service_completed()` is the seam through which a tend performed outside a
planner Job is recorded when ARCH-SYS-006 lands.

**All three parts of the identity are checked, and each one earned its keep by a
surviving mutant.** Dropping the service-day comparison let yesterday's pending
record absorb today's demand whenever a midnight boundary was missed — a silently
skipped day of service. Dropping the owner-generation comparison handed a redrawn
plot the previous owner's Job, whose `source` pointed at a destroyed reference.
Both mutants survived the first test suite and both now have a named test.

**The stride is one because two of the three daily-service owner stores do not
exist.** R06-JOB-006's 20-WU hive KEEP service needs `Hive` and REQ-SET-079/080's
orchard care needs `OrchardPlot`; neither is in `scripts/core/`. Budgeting a
stride of three would reserve 253952 bytes for stores nobody can write to.
Adding an operation later changes that one constant and nothing else.

**Midnight ordering is a checked precondition, not a comment.** The ruling says
midnight settles the preceding day before opening the new day's demand.
`run_day_boundary()` settles, then consults the public
`preceding_day_is_settled()`, then opens. Reversing the two statements produces a
refusal rather than a day of demand layered on an unsettled one.

**Capacity exhaustion is bounded by construction.** A refused `create_job()`
writes STATUS_UNMET into the owner's own fixed row, carrying the owner and the
service day, and records the refusing store's own code as the blocker. Two
hundred refusals retain one row. That is why the ruling's "shall not create a
hidden unbounded queue" needed no separate queue-length cap: there is no queue.

## Consequences

- **Something in this project creates a job for the first time.**
  `settlement_system.gd`'s "NOTHING CREATES JOBS" claim is corrected there; the
  running settlement still creates none, because that node composes no farming
  store and this phase deliberately did not wire ARCH-SYS-006's orchestration.
- A tending service that requires water is created with
  `inputs_gate = GATE_UNAVAILABLE` and is therefore ineligible for selection.
  That is the honest state of a settlement with no inventory join, not a bug to
  paper over with GATE_SATISFIED.
- Nothing here writes `JOB_STATE_WORK`. A created job stays QUEUED, or RESERVED
  once a worker binds. The only other state this module writes is CANCELLED, on
  a service its own settlement is retiring.
- Five producers stay unbuilt and each names its blocking store: R06-JOB-003
  (Expedition), R06-JOB-005 (FieldPolicy), R06-JOB-006 (Hive), and R06-JOB-001/002
  and R06-JOB-004 deferred by scope. REQ-SET-073 ripe harvest and REQ-SET-085
  withered clearing are **not** rerouted through this module.
- Blocker U2 stands: no command delivery exists, so the ruling's confirm-driven
  producers have no transport. This module owns no player enable/confirm entry
  point — daily tending is condition-driven — and the entry points a command
  handler would call when U2 closes are `mark_plot_dirty()`,
  `mark_all_owners_dirty()`, `mark_capacity_released()` and
  `record_service_completed()`. No command kind is invented and ARCH-CMD-003 is
  not renumbered.
- `OrderMode` is untouched. No plot id is written into a `recipe_id` and no
  `ProductionOrder` is created: daily care is not a production recipe.

## Observed, not fixed: §2.3's ledger column does not equal its stated sum

While updating the budget, the ledger's own `Bytes` column was totalled: it sums
to **59224650**, while "Planned allocated payload" states **58787018** — a
**437632-byte** discrepancy. Removing this decision's +126976 reproduces the same
gap against the previous 58660042, so **the discrepancy predates this change**.
It is recorded here rather than silently corrected, because guessing which of the
two figures is authoritative would overwrite another decision's arithmetic. The
+126976 delta itself is applied consistently to every dependent total, so this
change is checkable on its own regardless of how that older gap is resolved.

## Source

- `docs/rulings/2026-09-09_ready06_open_item_answers.md` §1 — R06-JOB-007,
  R06-JOB-008, the lifecycle/ordering paragraph, the defaults, the OrderMode
  paragraph and the implementation boundary. Adopted by Brendan as a whole.
- `docs/systems_architecture.md` ARCH-SYS-009, ARCH-MEM-005, §2.2, §2.3.
- GDD §4.2 (Job and FarmPlot rows), §4.3 (JobKind/JobState/CropState), §5.1 (the
  offset calendar), §5.3 (selection), §5.6 (crop arithmetic and tending).
- Decisions 0015 (`_into` readers), 0017 (coordinator Job), 0022
  (`required_skill`), 0023 (urgency buckets and gate semantics), 0024
  (allocate-before-consume).
