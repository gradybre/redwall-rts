# 0040 — A sowing request is identified by its field cycle, not by a service day
Date: 2026-09-10 · Status: Accepted

## Decision

`scripts/core/job_planner.gd` gains R06-JOB-004's sowing first-plant producer.
The ruling separates the two identities in one sentence — "Pending service
identity is `(owner EntityRef, operation, absolute service day)`; sowing/rotation
identity includes the field cycle" — and that separation is the schema:

```text
service_row(owner typed row r, operation op) = r * OPERATION_COUNT + op
OPERATION_COUNT = 2      OPERATION_FARM_TEND = 0      OPERATION_FARM_SOW = 1
DAILY_SERVICE_OPERATION_COUNT = 1
```

Six things are settled here.

1. **The operation domain widens from one to two**, and the stride constant
   becomes `OPERATION_COUNT`. `DAILY_SERVICE_OPERATION_COUNT` stays **1** and now
   means what its name says: how many operations reopen at midnight.
   `is_daily_service_operation()` is the predicate.
2. **A sowing request is not a daily service.** Midnight neither reopens nor
   settles it, `record_service_completed()` refuses it, and `service_day_of()`
   and `last_serviced_day_of()` refuse it rather than answering `0`.
3. **The field cycle is a per-owner ordinal this module allocates**, and it
   assumes no `FieldPolicy`. `confirm_first_planting()` is its only writer.
4. **Two of REQ-SET-070's five gates are evaluated; three are named as having no
   store.** No gate is faked and none is clamped.
5. **A failed gate consumes nothing**, and the retained reason is a byte on the
   row rather than a return value that evaporates.
6. **212992 bytes** of new packed payload are added to `systems_architecture.md`
   §2.2 with every dependent total in §2.3 recomputed.

## Why

**The field cycle had to be invented as an ordinal, or not at all.** The ruling
names "the field cycle" as sowing's third identity term and adds that "any
non-derivable cycle intent must be included in the schema/budget". There is no
`FieldPolicy` store, so there is no rotation cursor to read a cycle number out
of, and R06-JOB-005 — the producer that would advance one — is explicitly out of
scope for want of that store. What is derivable without any policy is the
**order** of sowing cycles on a plot: cycle 1 is the first cycle confirmed there,
cycle 2 the next. `_cycle_cursor` holds the last ordinal allocated per owner and
`_completed_cycle` the last one that finished. Neither assumes a rotation list
exists, and when `FieldPolicy` lands its cursor binds to these ordinals rather
than replacing them. Deriving the cycle from the crop id was rejected: the same
crop can be sown twice on one plot, so a crop id is not an identity. Deriving it
from the sow day was rejected for the same reason the ruling separates the two
identities — a day is what a *service* is identified by, and a sowing cycle
crossing midnight must not be settled as yesterday's unserved work.

**Widening the stride cost 106496 bytes and buys structural separation.** The
alternative — a second, sowing-only table addressed by owner — was rejected
because `service_row()`, `status_of()`, `service_job_of()`, `retire_service()`
and `revalidate_after_load()` are already generic over the operation, and a
parallel table would have duplicated every one of them. What the widening forces
is that three functions must now say *which* operations they are for.
`_settle_preceding_day()`, `preceding_day_is_settled()` and
`record_service_completed()` each consult `is_daily_service_operation()`. That is
not decoration: without the skip in `preceding_day_is_settled()`, one plot
waiting to be sown carries `_service_day = NO_DAY`, which is less than every real
day, and **every subsequent midnight would refuse to open its day's demand.** A
mutation removing that skip is killed by a named test.

**Two gates are real; three have no owning store, and they are said so rather
than passed.** REQ-SET-070 lists field connectivity, crop soil, seed supply,
planting window and output capacity.

| Gate | Owner | Treatment here |
|---|---|---|
| Crop soil | `farming.is_soil_compatible()` | **Evaluated.** Refuses `SOIL_INCOMPATIBLE` |
| Planting window | `farming.is_plant_window()` + `sim_clock` calendar | **Evaluated.** Refuses `OUTSIDE_PLANT_WINDOW` |
| Seed supply | *none* — `inventory.gd` exposes no seed reservation here | Declared on the Job as `inputs_gate = GATE_UNAVAILABLE` |
| Output capacity | *none* — §4.2's Job row has no output gate | Same gate column, same refusal |
| Field connectivity | *none* — nothing groups plots into fields | **Not evaluated and not faked.** Named as an open gate |

The seed and output treatment follows decision 0039's precedent for §5.6's water
exactly: `jobs.gd` defines `GATE_UNAVAILABLE` as "the job declares this
requirement and the owning system cannot answer", and a job carrying it **refuses
at selection** — `assign_worker()` returns `STEP6_INPUTS_UNAVAILABLE`, which is a
named test. Writing `GATE_SATISFIED` would have fabricated a seed supply nothing
checked. `inventory.gd` was not weakened and is not called from here at all;
`farming.plant()` returns the 250 milli-U and the caller owns the lot.

Field connectivity is the one gate with no expression at all — there is no
field-grouping store *and* no reachability oracle for eligibility step 7. It is
recorded as an open gate rather than assumed to pass. Nothing can act on the
assumption either way, because the same Job is already ineligible on its inputs.

**A failed gate consumes nothing, and "nothing" is measurable.** The gate sweep
runs before `create_job()` and writes only the row's own reason byte, so twenty
refused reconciliations leave the plot EMPTY, its crop id −1, `job_count()` zero,
every planner counter unmoved and `seed_committed_milli()` at zero. Seed is
committed at exactly one place — `farming.plant()`, through
`record_sowing_started()` — and `plant()` re-applies both evaluable gates itself,
so a window that closed between publication and productive start refuses there
too and still commits nothing.

**The retained reason is a byte because a `StringName` cannot live in a packed
column.** R06-JOB-004 requires a failed plot to remain unsown *with an explicit
reason*; a reason that existed only in a return value would be gone by the next
reconcile. `REASON_REFUSALS` maps the byte back to the same `StringName` the
refusal carried, so the stored reason and the returned one cannot drift, and a
test asserts they are equal.

**Cancellation has two regimes and this module owns only the first.** Before
productive start the plot never left EMPTY, so `cancel_sowing_request()` retires
the row, cancels the Job — releasing the only reservation this build can hold,
its bound worker — and leaves the plot byte-identical with no seed loss. After
commitment the regime is `farming.cancel_sowing()`'s, which discards the seed
with no refund; `cancel_sowing_request()` **refuses** a SOWN plot with
`SOWING_SEED_ALREADY_COMMITTED` rather than silently applying the wrong one.
Applying the wrong regime would either refund seed the ruling says is gone or
destroy seed that was never committed.

**The cursor refuses at int32's maximum rather than wrapping.** A wrapped ordinal
could name a cycle a retained row still carries. `can_allocate_field_cycle()` is
public and static so the boundary is testable without 2^31 confirmations — the
alternative was an unreachable branch that any mutation would survive.

**Three design details exist only because a mutant survived without them.** Each
was a real gap, not an equivalence:

1. **`sowing_gate_for()` is public** because the `REASON_CROP_INVALID` and
   `REASON_OWNER_NOT_PRESENT` branches were unreachable through the producer —
   `confirm_first_planting()` refuses both before a row can hold one — so
   deleting either branch changed nothing observable. Exposing the gate sweep as
   a pure question makes every reason in the domain reachable *and* gives a UI
   panel the same answer the producer acts on, from the same code.
2. **`record_sowing_started()` refuses `SOWING_NOT_PENDING` and
   `SOWING_JOB_MISSING` separately** because deleting the status guard changed
   nothing: an unpublished row's Job reference is null anyway, so the second
   check caught it and returned the same code. An invisible guard is one a later
   edit deletes for free. Two different facts now produce two different answers.
3. **`service_row_is_clear()` is public** because dropping `_field_cycle[row] =
   NO_CYCLE` from `_retire_row()` was invisible — a FREE row's readers refuse, so
   the residue could not be seen until the row was reused. `jobs.gd` already
   publishes `inactive_job_row_is_clear()` for exactly this reason; this is the
   same predicate over the planner's own rows.

A fourth survivor was a real defect and was fixed rather than accepted:
`_owner_carries_a_record()` reads **every** operation, not just the daily ones.
Reading only the tending row let a sowing request on a **destroyed** plot survive
every idle sweep and every midnight, leaving its Job alive forever with nothing
recording that it existed. That is now a named test.

## Consequences

- **`confirm_first_planting()` exists and nothing calls it.** Blocker U2 stands:
  ARCH-CMD-003's command kinds are unimplemented, so R06-JOB-004's "when the
  player confirms" has no transport. **No command kind is invented and
  ARCH-CMD-003 is not renumbered**; the ruling's implementation boundary directs
  that at the existing `SET_FIELD_ROTATION`/`SET_POLICY` payloads, which is a
  change to a document this work does not own.
- **A published sowing job can never be selected in this build**, because its
  inputs gate is `GATE_UNAVAILABLE`. That is the honest state of a settlement
  with no inventory join, and it is the same state decision 0039 left a tending
  service that needs water.
- **Nothing writes `JOB_STATE_WORK`.** A published sowing job is QUEUED, or
  RESERVED if a worker is bound by some other path. The module's only other state
  write is CANCELLED.
- **The producer does not apply the work's effect.** Exactly as a completed
  tending service does not call `farming.tend()`, a completed sowing Job closes
  the *cycle* and leaves SOWN → GROWING to `farming.begin_growing()`.
  `record_sowing_started()` and `record_sowing_completed()` are the two seams
  ARCH-SYS-006 drives; neither is called from inside this module.
- **R06-JOB-005 stays unbuilt and this schema does not presume it.** The ruling's
  default is `auto_rotation = false`, and "changing a rotation list without
  confirming planting shall not start work" holds by construction: the only entry
  point that opens a cycle is `confirm_first_planting()`, and nothing else writes
  `_requested_crop`.
- **R06-JOB-001/002 forage demand is the next phase** and is untouched here.
  R06-JOB-003 still needs `Expedition`; R06-JOB-006 still needs `Hive`.
- One existing test changed behaviour and was updated, not weakened:
  `test_the_service_row_is_the_owner_major_index_of_the_ruling` asserted a stride
  of 1, `SERVICE_ROW_COUNT == 4096`, and that operation 1 refuses. It now asserts
  the stride of 2, 8192 rows, that operation 1 is sowing and that operation **2**
  refuses. Nothing was removed; four assertions were added.

## The byte cost, and the older discrepancy it does not touch

| Column group | Before | After | Delta |
|---|---:|---:|---:|
| `PendingService` I32 ×6 | 4096 rows, 98304 | 8192 rows, 196608 | +98304 |
| `PendingService` B8 ×2 | 4096 rows, 8192 | 8192 rows, 16384 | +8192 |
| `PendingService.field_cycle, requested_crop` I32 ×2 | — | 8192 rows, 65536 | +65536 |
| `PendingService.gate_reason` B8 | — | 8192 rows, 8192 | +8192 |
| `PendingService.cycle` I32 ×2 (per owner) | — | 4096 rows, 32768 | +32768 |
| **Total** | | | **+212992** |

`PendingService.dirty` is unchanged at 4096 entries: the dirty set is per owner,
not per operation. Scalar counters (`_seed_committed_milli` and the five sowing
counts) are module scalars, not columns, and are outside the field payload for
the same reason decision 0039's counters are.

Dependent totals, each recomputed rather than restated:

| Figure | Before | After |
|---|---:|---:|
| §2.2 fixed-field payload sum | 24288210 | 24501202 |
| §2.3 fixed registry payload | 24725842 | 24938834 |
| Planned allocated payload | 59078350 | 59291342 |
| One live world plus reserve | 67466958 | 67679950 |
| Headroom below decimal 100 MB | 32533042 | 32320050 |
| Additional candidate mutable state | 52862766 | 53075758 |
| Transactional peak plus same reserve | 120329724 | 120755708 |
| Transactional headroom | −20329724 | −20755708 |

**The 437632-byte discrepancy decision 0039 recorded is still there and is still
not corrected here.** Measured again on this checkout: §2.2's own `Payload bytes`
column now sums to **24938834**, which is exactly the ledger's *Fixed registry
payload* row, while §2.2's prose sentence states **24501202** — 437632 lower. The
same 437632 separates the ledger's `Bytes` column total (59728974) from the
stated *Planned allocated payload* (59291342). Removing this decision's +212992
reproduces the identical gap against the previous figures, so **the discrepancy
predates this change** and the +212992 is applied consistently to both sides of
it. It is left for whoever owns that arithmetic; guessing which figure is
authoritative would overwrite another decision's work.

## Source

- `docs/rulings/2026-09-09_ready06_open_item_answers.md` §1 — R06-JOB-004, the
  lifecycle/ordering paragraph ("sowing/rotation identity includes the field
  cycle"), the defaults paragraph (priority 3, `auto_rotation=false`), the
  OrderMode paragraph and the implementation boundary. §6.1 — the two sowing
  cancellation regimes and the seed-commitment instant.
- GDD §5.6 (crop table, sow/tend/harvest WU, seed 250 milli-U), REQ-SET-070
  (the five gates), REQ-SET-071 (seed consumption), §4.2 (the Job row), §4.3
  (JobKind/JobState/CropState), §5.1 (the offset calendar).
- `docs/systems_architecture.md` ARCH-SYS-009, ARCH-MEM-005, ARCH-MEM-009,
  §2.2, §2.3.
- Decisions 0015 (`_into` readers), 0017 (worker departure), 0022
  (`required_skill`), 0023 (gate semantics), 0024 (allocate-before-consume),
  0039 (the pending-service identity this extends).
