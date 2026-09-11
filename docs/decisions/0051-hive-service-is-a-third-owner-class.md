# 0051 — The hive service is a third owner class, and rotation is not a daily service

Date: 2026-09-11
Status: adopted
Scope: `godot/scripts/core/job_planner.gd`, `docs/systems_architecture.md` §2.2 / ARCH-MEM-009 /
ARCH-MEM-010, `godot/scripts/systems/settlement_system.gd` composition.
Governing contracts: `docs/rulings/2026-09-09_ready06_open_item_answers.md` §1, R06-JOB-005 and
R06-JOB-006, with that section's lifecycle/ordering paragraph, its defaults paragraph and its
`OrderMode` paragraph.

Builds on decisions 0039 (pending-service identity), 0040 (the sowing cycle), 0041 (forage demand),
0044 (the `Hive` store) and 0045 (the rotation advance). Numbered 0051 because 0050 was taken by
the planner's READY_07 source audit while this work was in flight.

## 1. What was found before anything was written

**R06-JOB-005 was already implemented, in full, by decision 0045.** The brief for this increment
described it as blocked on the missing `FieldPolicy` store. That store landed in task 03 increment
7 and the same increment implemented the contract: `field_policy._advance_rotation()` advances the
cursor once per COMPLETED cycle, `_request_crop_at_cursor()` reads the single entry at the cursor
and neither skips nor substitutes, `auto_rotation == 0` returns before the advance, and
`_classify_window()` distinguishes READY / WINDOW_FUTURE / WINDOW_MISSED with both non-ready
answers retaining the request. `test_field_policy.gd` already carried a named test for every one
of those. **Nothing in that file was rewritten, and its behaviour is unchanged by this decision.**

What was genuinely missing for R06-JOB-005 was two things, and both are added here:

1. `is_daily_service_operation()` could not answer for rotation at all, because JobPlanner's
   operation domain did not name it. "Rotation is event-driven on cycle completion, not a daily
   service" existed only as prose. It is now a checked answer (§3).
2. Nothing recorded, as a test, **what actually closes a cycle in this build**. See §5.

## 2. The hive service does not fit the pending-service table, and the capacity was checked

`service_row(owner, operation) = owner_typed_row * OPERATION_COUNT + operation` is owner-major over
farming.gd's 4096 `FarmPlot` rows. `Hive` has 1024 rows (`entity_directory.KIND_HIVE`, restated by
`orchard_hive.HIVE_CAPACITY`).

1024 ≤ 4096, so the arithmetic *fits*. **It is still wrong**, and that was checked rather than
assumed: row `r` of that table is FARM PLOT `r`. A hive addressed there would inherit that plot's
owner reference, its service day, its `serviced_day` history and its gate reason. An owner-major
table is shareable only between owners of the same class. This is the same argument decision 0041
made for `HarvestZone`, applied to a third class.

**Decision: a separate 1024-row slice, `hive_service_row(h) = h`**, because the hive class has
exactly one operation. Budgeted in §4.

**There is no `_hive_serviced_day` column.** `orchard_hive.gd` already owns `Hive.serviced_day`,
`record_hive_service()` writes it and `is_service_due()` reads it — and §5.6's own daily step reads
the same column. A copy here would give "once per day" two answers that could disagree after a
load. The producer gates on the owning store's predicate instead.

## 3. `is_daily_service_operation()` becomes an explicit table, not a range

It answered `operation < DAILY_SERVICE_OPERATION_COUNT`, which worked while every daily operation
happened to hold a low ordinal. R06-JOB-006's hive service **is** a daily service and belongs to a
different owner class. It could only take a low ordinal by either

* renumbering `OPERATION_FARM_SOW`, which is a **stored identity term** on live sowing rows, or
* widening the 4096-row FarmPlot table by an operation no farm plot owns (+65536 bytes of dead
  columns).

**Decision: `DAILY_SERVICE_OPERATIONS: Array[bool]` names the answer per ordinal.**
`DAILY_SERVICE_OPERATION_COUNT` is now asserted to equal the number of `true` entries rather than
defining them, and the stored ordinals do not move. The four places where "daily" is structural
already consulted the predicate rather than a hard-coded ordinal, exactly as decision 0040's header
promised, so the change reached no call site.

The domain, and only two of its five ordinals address `service_row()`:

| ordinal | operation | owner class | daily | table |
|---|---|---|---|---|
| 0 | `OPERATION_FARM_TEND` | FarmPlot | yes | `service_row()`, 4096 owners |
| 1 | `OPERATION_FARM_SOW` | FarmPlot | no | `service_row()`, 4096 owners |
| 2 | `OPERATION_FORAGE_HARVEST` | HarvestZone | no | `demand_row()`, 128 owners |
| 3 | `OPERATION_FIELD_ROTATION` | FieldPolicy | **no** | **none** — `field_policy.gd` |
| 4 | `OPERATION_HIVE_KEEP` | Hive | **yes** | `hive_service_row()`, 1024 |

**Ordinal 3 owns no row here and that is the point.** R06-JOB-005's advance creates no Job, so
there is nothing for a pending-service row to hold and none is allocated. It is named so the
answer is checkable: `_init()` asserts it, a test asserts it, and `is_operation()` refuses it so no
row can ever be addressed by it. This is exactly the seam `OPERATION_FORAGE_HARVEST` already set.

**Two existing tests were updated, and this is the record of that.** `test_the_service_row_is_the_
owner_major_index_of_the_ruling` asserted `DAILY_SERVICE_OPERATION_COUNT == 1` and
`test_the_forage_operation_is_not_a_daily_service_operation` asserted `OPERATION_DOMAIN_COUNT == 3`.
Both numbers legitimately changed. Neither test was weakened: the first now pins the property that
actually matters — the FarmPlot stride stayed at 2 and `SERVICE_ROW_COUNT` stayed at 8192 **while a
daily operation was added** — and the second gained the hive and rotation answers.

## 4. The budget: 35840 bytes, one ARCH-MEM-009 step

Five §2.2 field rows over 1024 rows, each checked individually against
`element_width * column_count * allocated_length = payload_bytes`:

| columns | kind | width | count | length | bytes |
|---|---|---:|---:|---:|---:|
| `owner_slot, owner_generation, service_day, job_slot, job_generation` | I32 | 4 | 5 | 1024 | 20480 |
| `feed_demand_milli` | I64 | 8 | 1 | 1024 | 8192 |
| `status, blocker` | B8 | 1 | 2 | 1024 | 2048 |
| `dirty_hive` | I32 | 4 | 1 | 1024 | 4096 |
| `is_hive_dirty` | B8 | 1 | 1 | 1024 | 1024 |

Total **35840**. Fixed-field payload sum 24555474 → **24591314**. ARCH-MEM-009 carried total
59819174 → **59855014**; with the unchanged 8388608 reserve, **68243622**; headroom **31756378**.
The memory-field product count moves 159 → **164**.

**ARCH-MEM-010's 437632-byte gap is REPRODUCED, not moved.** The printed rows now sum to 60292646
and the carried total is 59855014; the difference is 437632 for the third consecutive check. Both
halves moved by the same +35840, so this slice can neither shrink the discrepancy nor hide inside
it. Every ARCH-MEM-009 row was re-added individually, one at a time — rows have been silently
dropped there three times and every total stayed correct each time.

`ARCH-CONFLICT-011` had never picked up decisions 0044/0045/0048/0049 and is reconciled here to
121883052 / 21883052, with its earlier dated figures left standing as the record of when each
reconciliation happened. That is the convention decision 0049 set.

## 5. What actually closes a field cycle today — and therefore what R06-JOB-005 waits on

`field_policy.record_plot_resolved()` accepts only `OUTCOME_HARVESTED` and `OUTCOME_CLEARED`, and
**both are job completions**: REQ-SET-073's ripe harvest and REQ-SET-085's withered clearing. A
crop reaching `RIPE` is not a harvest; a crop reaching `WITHERED` is not a clearing. Nothing in
this build completes either job, because selection and movement do not exist and no path writes
`JOB_STATE_WORK`.

**So R06-JOB-005's trigger cannot fire end to end.** The producer is complete; it has no caller.
Four tests now pin this instead of leaving it as prose: a crop driven to `RIPE` resolves nothing
and moves no cursor; a crop driven to `WITHERED` and then actually cleared through
`farming.clear_withered()` **still** resolves nothing; the same plot resolved through the explicit
`record_plot_resolved()` path advances exactly one step and requests the second configured entry;
and `record_plot_resolved()` still refuses every outcome that is not one of the two job
completions, so no caller can widen the trigger with an in-range ordinal.

What it needs: ARCH-SYS-006's increment-10 join, which needs the movement layer. No shortcut was
taken and no crop was allowed to resolve itself.

## 6. A defect found while writing this: the owner reference was compared by generation alone

`_settle_existing()` and `_settle_existing_sowing()` both compared `_owner_generation[row]` against
`_farming.ref_of(owner_slot).y` while their docstrings claimed "BOTH HALVES OF THE OWNER EntityRef
ARE CHECKED". §4.1's generation lives on the **directory slot**, not on the typed row. When a plot
is destroyed and any other store allocates in between, the typed row is reused under a **fresh**
directory slot whose first generation is 1 — the same number the previous occupant carried. The
comparison then reported "same owner" for a completely different plot, and the new plot would
inherit the old one's pending service and its Job, or its confirmed sowing crop.

It was found because the new hive producer, written to the same pattern, failed its own
row-reuse test. All three settle paths now compare the full `Vector2i`. Two named regression tests
reproduce the collision explicitly — they destroy the owner, let an unrelated directory allocation
take the freed slot, and assert the generations are equal while only the slot half differs.

## 7. What this decision refuses to invent

* **R06-JOB-003 fishing cycles.** No `Expedition` store. Not stubbed.
* **A winter feed-delivery JOB.** The demand is recorded as state. **The blocker is not a missing
  container store** — `inventory.gd` already owns InventoryContainer rows, `create_container()`,
  reserved/used mass, filters and reachability, and honey is an authored item. What is missing is
  (a) anything that gives a hive a destination container, since `create_container()` takes an owner
  EntityRef and no Building/Furniture/Room ownership layer exists to bind one to an apiary, and
  (b) a hauling producer and the movement layer to run it. `hive_feed_demand_milli_of()` is the
  reader that producer consumes.
* **A command kind.** `ARCH-CMD-003` is not renumbered. The six implemented kinds are
  `CANCEL_JOB`(3), `DESIGNATE_ZONE`(8), `NAME_RESIDENT`(11), `SET_ACTIVITY_SCHEDULE`(15),
  `SET_JOB_PRIORITIES`(18) and `SET_POLICY`(20); `SET_FIELD_ROTATION`(17) is **not** among them, so
  `field_policy.gd`'s five edit entry points still have no transport. The hive producer needs none:
  it is condition-driven.

  **Reported, not fixed here:** `command_dispatch.UNSUPPORTED_REASON[17]` still reads
  `NO_FIELD_POLICY_STORE`, which became **stale** when decision 0045 built that store. The kind is
  still unimplemented, but the reason it gives is no longer the true blocker — what is missing now
  is the payload schema and the preflight, not the store. Correcting it belongs to whoever owns
  `command_dispatch.gd`'s kind table; this increment was told not to deliver the player-edit paths
  and did not touch that file.
* **An "operational" flag on `Hive`.** §4.2 gives the row no such column and §5.6 names none. A
  colonised, non-abandoned row is the operational one.
* **`OrderMode`.** No hive id or field id is written into a `recipe_id` and no `ProductionOrder` is
  created. The ruling says in its own words that field rotation and daily hive care are not
  production recipes.
* **`JOB_STATE_WORK`.** Nothing here writes it.
* **A save round trip.** There is no save module. `revalidate_after_load()` repairs the hive slice
  the same way it repairs the other two — dropping rows whose Job no longer resolves — but no
  cross-process round trip of any of it has been exercised, and completion history lives in
  `orchard_hive.gd` where a loader would have to preserve it.
* **REQ-SET-079/080's orchard daily care.** Its store exists, but R06-JOB-007 routes it through the
  "one-service-period/one-harvest-year pattern" and the harvest half needs an output binding that
  does not. Adding it later is one more ordinal, one more table and one more budget row.

## 8. Verification

`./tools/run_tests.sh` in this worktree. Baseline on `master` at `16e1efc`, measured rather than
assumed: **1999 test(s), 56972 assertion(s), 0 failure(s)**. Final: **2044 test(s), 57659
assertion(s), 0 failure(s)** — 45 new tests. The two `Unicode parsing error` lines the runner
prints are pre-existing and unrelated. `godot --headless --path godot --editor --quit` imports
clean.

## 9. Producer count

Six of the eight R06-JOB producers are now built: 001, 002, 004, 005 (in `field_policy.gd`), 006
and 007, with 008's dirty/reconcile machinery spanning all three owner classes. **003 remains**,
blocked on the `Expedition` store.

## 10. Mutation evidence

**41 mutations, one per `godot` invocation**, each applied to a production file, run against the
full suite with a 900-second timeout, restored from a private pristine copy and **byte-compared by
SHA-256** afterwards. The failure count is parsed as an INTEGER out of the runner's own summary
line; a substring test such as `"0 failure(s)" not in summary` matches `"10 failure(s)"` and
manufactures a phantom survivor. Both production files ended byte-identical to their pristine
copies, and `field_policy.gd` is byte-identical to `HEAD`
(`262198e7a04d340c5205007c7ff1124264efe761b675fd99f657fb38a9fb5315`).

**First pass: 37 killed, 4 survived. After the four missing tests were added: 41 of 41 killed.**
No mutant was declared equivalent.

The four survivors were real gaps, and all four are the kind a job-count test walks straight past:

1. **`_settle_preceding_hive_day`'s `>= day` relaxed to `> day`.** Midnight would have retired a
   service belonging to the day it was opening — destroying a live Job and its work in progress if
   a boundary ran twice or ran after the day's first reconcile.
2. **The `_hive_service_day != day` term dropped from the hive settle path.** A day-2 row left
   standing by a missed boundary would have answered SERVICE_ALREADY_PENDING on day 3, and day 3
   would have gone unserviced for as long as the boundary stayed missed.
3. **`hive_service_row_is_clear()` short-circuited to `true`.** Every test that called it called it
   on a row that really was clear, so the predicate could never be caught saying yes wrongly. This
   is the same shape as the 352418-entry validation that could be replaced with `return true`.
4. **The idle sweep's stride widened from `STAGGER_MODULUS` to three times it.** Every sweep test
   used a single hive on row 0, which any stride still reaches. Rows beyond the first stagger
   period are what distinguish the strides; thirty-six hives are now walked and each must be
   serviced exactly once per period.

| # | mutation | file | result |
|---|---|---|---|
| 0 | season gate inverted | `job_planner.gd` | KILLED |
| 1 | season gate never fires | `job_planner.gd` | KILLED |
| 2 | winter blocker becomes already-serviced | `job_planner.gd` | KILLED |
| 3 | hive service work halved at the create site | `job_planner.gd` | KILLED |
| 4 | hive service work takes farming's 1-WU tending total | `job_planner.gd` | KILLED |
| 5 | hive service published as a FARM job | `job_planner.gd` | KILLED |
| 6 | hive service published at priority 2 | `job_planner.gd` | KILLED |
| 7 | rotation reported as a daily service | `job_planner.gd` | KILLED |
| 8 | hive service reported as NOT a daily service | `job_planner.gd` | KILLED |
| 9 | daily predicate bounded by the FarmPlot stride | `job_planner.gd` | KILLED |
| 10 | rotation ordinal addresses the FarmPlot table | `job_planner.gd` | KILLED |
| 11 | preceding hive day settles only strictly-future rows | `job_planner.gd` | KILLED -- survived the first pass; killed once the missing test was added |
| 12 | preceding hive day always reports settled | `job_planner.gd` | KILLED |
| 13 | hive settlement leg dropped from the day boundary | `job_planner.gd` | KILLED |
| 14 | midnight stops reopening hive demand | `job_planner.gd` | KILLED |
| 15 | hive service row records tomorrow's day | `job_planner.gd` | KILLED |
| 16 | the settled row's day term is not compared | `job_planner.gd` | KILLED -- survived the first pass; killed once the missing test was added |
| 17 | hive owner compared by generation alone | `job_planner.gd` | KILLED |
| 18 | tending owner compared by generation alone | `job_planner.gd` | KILLED |
| 19 | sowing owner compared by generation alone | `job_planner.gd` | KILLED |
| 20 | abandoned hives are serviced | `job_planner.gd` | KILLED |
| 21 | already-serviced hives are serviced again | `job_planner.gd` | KILLED |
| 22 | absent hive rows pass the presence gate | `job_planner.gd` | KILLED |
| 23 | winter feed demand always recorded as zero | `job_planner.gd` | KILLED |
| 24 | a retired hive keeps its withdrawn feed demand | `job_planner.gd` | KILLED |
| 25 | an outstanding feed demand is not a record | `job_planner.gd` | KILLED |
| 26 | hive service declares an unanswerable input | `job_planner.gd` | KILLED |
| 27 | hive service job is bound to no source | `job_planner.gd` | KILLED |
| 28 | retired hive row keeps a service day | `job_planner.gd` | KILLED |
| 29 | the hive row hygiene predicate always agrees | `job_planner.gd` | KILLED -- survived the first pass; killed once the missing test was added |
| 30 | repeated hive dirty marks stack | `job_planner.gd` | KILLED |
| 31 | exhausted hive demand is not retained | `job_planner.gd` | KILLED |
| 32 | released capacity never re-marks a hive | `job_planner.gd` | KILLED |
| 33 | a load never repairs the hive slice | `job_planner.gd` | KILLED |
| 34 | the hive sweep skips two thirds of its slice | `job_planner.gd` | KILLED -- survived the first pass; killed once the missing test was added |
| 35 | the completion is recorded against the wrong day | `job_planner.gd` | KILLED |
| 36 | a COMPLETE hive job is read as still live | `job_planner.gd` | KILLED |
| 37 | cycle closes on the FIRST resolution, once per tile | `field_policy.gd` | KILLED |
| 38 | the cursor advances two entries per cycle | `field_policy.gd` | KILLED |
| 39 | auto_rotation false no longer stops the advance | `field_policy.gd` | KILLED |
| 40 | a blocked rotation entry is skipped and a crop substituted | `field_policy.gd` | KILLED |

Mutations 7–10 (the `is_daily_service_operation()` answers) are killed partly by `_init()`'s own
assertions, which abort every test that builds a planner. That is recorded rather than glossed:
the named predicate test kills them too, but the large failure counts come from the assertions.
