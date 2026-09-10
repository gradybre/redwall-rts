# Task 02 — Settlement foundation through the inventory transaction layer

Owning specifications: `docs/systems_architecture.md` §11 (ARCH-MIG-006),
`docs/game_gdd.md` §4.1–4.3 / §5.1, `docs/gameplay_balance.md` §1–2.
Ruleset: `settlement_rules_v2` with `SET-AMEND-001` and `SET-MOVE-001`.

## What this task is

The first four steps of ARCH-MIG-006, built as **new release modules beside the
prototype**, not by editing it in place. The prototype keeps running against its
own tests until each replacement passes, so a failure has a known cause
(ARCH-MIG-006 step 2).

## What completion does NOT establish

Not a playable colony. No needs, jobs, schedules, ecology, crops, buildings,
recipes, feasts, immigration, movement or saves. No performance claim on the
qualification hardware — development is on macOS and Windows testing is deferred
by user instruction; a 5090/64 GB machine does not establish the specified
minimum floor. No survival trajectory.

## Unresolved contracts blocking parts of this task

Found by audit of `docs/systems_architecture.md`, 2026-09-06. **Proposed values
are recorded here and are NOT promoted into approved constants.**

| ID | Blocker | Affects | Disposition |
|---|---|---|---|
| U1 | `catalog_ids.json` is named only in GDD §4.2 and BAL-CAT-001; the architecture document never specifies its document shape, canonical byte serialization, hash relationship to save-header offset 72, location, or whether it is built or shipped | Task 2.2 persistence | Compile and validate in memory; **do not** emit the file or claim hash verification |
| U2 | Speed/pause scheduler events have no command kind (ARCH-CMD-003 has 24 kinds, none for speed/pause), no ordering tiebreak, no save section (ARCH-SAVE-002 §12 is `PENDING_COMMANDS` only) | Task 2.4 queued pause determinism | Implement immediate speed/pause state; **defer** queued scheduler events |
| U3 | ARCH-CLOCK-001 "never discard completed or owed ticks" vs ARCH-CLOCK-002 "may clear scheduler debt"; GDD REQ-SET-008 says pause rather than skip | Task 2.4 debt rule | Follow the **conservative** rule: never discard implicitly. Explicit acknowledgement is counted, not silent |
| U4 | Reservation indexing unspecified: 32768 reservation rows against 8192 job rows is exactly 4×, implying owner-major `job*4+i`, which neither document states and which would cap a recipe at 4 input lots | Task 2.5 reservations | **Resolved by decision 0019 / task 2.11**: global lowest-free-index allocation, variable-length claim lists |
| U5 | No allocator storage budgeted for non-directory child stores (Reservation, GearInstance, BatchState, LotEffect, NoticeCondition, ChildSliceIndex) | Tasks 2.3, 2.5 and the memory ledger | **PARTLY CLOSED 2026-09-09.** Reservation has decision 0019's global pool; GearInstance has decision 0038's lowest-free pool. **`BatchState`, `LotEffect`, `NoticeCondition` and `ChildSliceIndex` still have no allocator budget** — do not tick U5 as a whole |
| U6 | Missing owner-major index formulas for MoodMemory, ManualTask, HivePollinationLinks, Feast.attendees, Feast.reserved_lots | Later tasks | Not required this milestone. **`HivePollinationLinks` closed 2026-09-10** by ruling 2026-09-09 §3 / decision 0044 / ARCH-STATE-008: `recipient_index(FarmPlot p)=p`, `recipient_index(OrchardPlot o)=4096+o`, `link_row=6*recipient+k`, 30720 references. The other four remain open |
| U7 | ARCH-MIG-006 step 2 requires "golden GDD fixtures" but never enumerates them | Task 2.1 acceptance | Use GDD §7.1 worked examples, the only worked arithmetic in the spec |

`MOVE-G01–05` are engineering gates on the movement scope. **No task in this
milestone depends on them** — movement is not implemented here. The existing
one-floor spatial bounds and memory ledger are *not* presented as sufficient for
the adopted underground/swimming/climbing scope (`SET-MOVE-001`); that ledger
must be re-derived before movement work, and this task does not do so.

## Tasks

### 2.1 — Integer arithmetic helpers
- **Owns** `godot/scripts/core/int_math.gd`, `godot/test/test_int_math.gd`
- **Spec** ARCH-AUTH-003, BAL-AUTH-002, BAL-NUM-001
- `floor_div` (nonnegative), `ceil_div(a,b)=(a+b-1)/b`, `trunc_div` (signed),
  positive-denominator enforcement, retained remainders, int64-before-narrowing
  with **refusal on overflow**, never silent truncation
- Rounding: nutrition/yield/material discounts **down**; trips, portions,
  batches, beds, stations **up**; capacity debit `ceil_div(quantity_milli*mass_g,1000)` per lot
- **Acceptance** GDD §7.1 fixtures reproduce exactly; overflow refuses rather
  than wraps; remainder carrying is lossless across many small steps
- **Does not establish** any gameplay behavior

### 2.2 — Catalog compilation and validation
- **Owns** `godot/scripts/core/catalog.gd`, `godot/test/test_catalog.gd`
- **Spec** BAL-CAT-001, GDD §4.2 closing paragraph, ARCH-STATE-004
- Compile each domain independently in **ascending ASCII key order**; preserve
  explicitly numbered enums unchanged (Speed 0/1/2/4, JobKind 0–11 with
  RESERVED_3, ZoneType with RESERVED_1, etc.); **reject** dictionary
  insertion-order enumeration; reject `ItemDefinition` catalogs over **256** keys
- **Acceptance** deterministic IDs across runs and insertion orders; explicit
  enums never renumbered; oversized catalog rejected at compile time
- **Blocked by U1**: no `catalog_ids.json` emission or hash verification

### 2.3 — Entity directory, refs, resident slots
- **Owns** `godot/scripts/core/entity_directory.gd`, `godot/test/test_entity_directory.gd`
- **Spec** ARCH-MEM-001/005, ARCH-ID-002, GDD §4.1
- Promote the verified `docs/validation/headless/resident_slots.gd` kernel into a
  release module: packed columns, `(slot, generation)` refs, null `(-1,0)`,
  lowest-free-slot min-heap, **512 slots / 256 living**, allocation once with no
  `resize()` in updates
- **Acceptance** stale-ref rejection after destroy; slot reuse increments
  generation; living cap refuses at 256 with explicit refusal not silent drop;
  generation exhaustion handled; no `Array` per row
- **Blocked by U5** for the four child stores still without an allocator budget (`BatchState`, `LotEffect`, `NoticeCondition`, `ChildSliceIndex`); Reservation and GearInstance are closed

### 2.4 — Fixed clock, calendar, pause
- **Owns** `godot/scripts/core/sim_clock.gd`, `godot/test/test_sim_clock.gd`
- **Spec** ARCH-CLOCK-001/002, REQ-SET-002/003/004/006/008
- Promote `docs/validation/headless/fixed_clock.gd`: 30 ticks/s, 750/hour,
  18000/day, 12 days/season, 48/year, tick 0 = 06:00, calendar
  `(tick+4500) mod 18000`, first midnight 13500; speeds **0/1/2/4**; pause
  reasons as a mask; **retained debt**
- **Acceptance** exact tick→calendar mapping at boundaries; 2x/4x produce exactly
  2x/4x ticks per unit time; debt retained not discarded; overload steps 4→2→1
  and pauses at 1x rather than skipping
- **Blocked by U2** (queued scheduler events), **U3** (documented, conservative rule taken)

### 2.5 — Inventory lots and transactions
- **Owns** `godot/scripts/core/inventory.gd`, `godot/test/test_inventory.gd`
- **Spec** GDD §4.2 (`InventoryContainer`, `InventoryLot`), §5.8, BAL-NUM-001
- `quantity_milli:int64` lots with item/quality/age/provenance; container
  `max_mass_g`; **all-or-nothing** transactions; split/merge only on identical
  attributes; source/sink accounting so total is conserved
- **Acceptance** all-or-nothing under partial failure; conservation across
  arbitrary operation sequences; capacity refusal is explicit; mass debit uses
  per-lot `ceil_div`
- **U4 resolved**: reservations implemented in task 2.11, see below

## Test migration ledger

Maintained in `docs/tasks/02_test_migration_ledger.md`. Every prototype test is
retained, replaced, or retired **with a reason**. Prototype behavior that
contradicts the specification is not preserved merely to keep an assertion green.

## Review outcome (2026-09-06)

Independent adversarial review (CLAUDE.md Phase 3A) of all five modules:
**0 CRITICAL, 7 HIGH**. Several findings were mutation-proven — the reviewer
broke the code and demonstrated the suite still passed — and two were executed
exploits rather than theory.

| Finding | Disposition |
|---|---|
| H1 `_fits()` int64 overflow; `audit()` blind to `used + reserved <= max` | **Fixed** + 4 regression tests |
| H2 silent int32 truncation; `narrow_to_int32()` had zero production callers | **Fixed** + 3 tests |
| H3 `compile_catalog()` threw and returned `null` on an untyped `Array` | **Fixed** + 2 tests |
| H4 `_age_hours_ceil()` `-1` sentinel bypassed the merge gate, wrote a negative age | **Fixed** + 3 tests |
| H5 ARCH-ID-003 reverse-owner clause had zero coverage (1.4 MB column nothing verified) | **Test added**; production code was correct |
| H6 transaction free-stack rollback uncovered on a load-bearing branch | **Tests added**; production code was correct |
| H7 per-frame/per-op `RefCounted` allocation, 17.2 µs/transfer | **Fixed** in task 2.7 — 60% faster, decision 0015 closed |
| MEDIUM invented `PROVENANCE_*`/`POLICY_DEFAULT` catalog numbers | **Fixed** — now opaque int32, blocker discipline restored |

Every fix carries a regression test verified to **fail against the pre-fix
behaviour**. No existing test was weakened to make a fix pass.

### 2.6 — Catalog to inventory item registry (**done**)
- `tools/extract_item_definitions.py`, `godot/data/item_definitions.json`,
  `godot/scripts/core/item_definitions.gd`, `godot/test/test_item_definitions.gd`
- The 60 authoritative rows are **extracted mechanically** from
  `docs/gameplay_balance.md` §3.1, never hand-copied, so the data has one source
  and is regenerable. Generator fails loudly on row-count drift, duplicate ids,
  non-integer fields, or a retired key.
- All 9 `SET-AMEND-001` retired keys refused per REQ-ADM-003; validation aborts
  the whole load before any registration (GDD §4.2).

### 2.7 — Remove hot-path allocation (**done**)
`transfer()` 21.13 -> 8.53 us/op (-60%), `advance()` 2.19 -> 1.06 us/frame
(-52%), zero objects allocated across 200 clock frames. Public API unchanged, so
no caller moved and no existing test was weakened. Decision 0015 is **closed**
with the measurements.

### 2.8 — Runtime integration (**done**)
ARCH-MIG-006 steps 4-5, verified between steps. `GameManager` is now a thin
adapter over `sim_clock.gd` — speeds 0/1/2/4, integer ticks, real calendar,
`Engine.time_scale` never written. `EconomySystem` and the HUD bindings moved
together onto `inventory.gd` + `item_definitions.gd`: integer `quantity_milli`,
container mass in grams, the real 60-item catalog, capacity **refusal** rather
than silent clamping. 257 tests, 0 failures. `project.godot` needed no change.

Decision 0006 divergence rows 1-8 are now closed on the release side. Rows 9
(`CombatSystem`) and 10 (input action IDs) remain open.

### 2.9 — Needs and health (**done**)
GDD §5.2 needs, health, cold and mood on one verified integrator. The §7.1 mood
fixture reproduces exactly (6200 -> 6500 with the meal memory -> 4700 with the
friend penalty). Remainder losslessness proven over 56,250 ticks against
closed-form integer arithmetic, and mutation-proven three ways. 311 tests.

Promoted from the verified `winter_world.gd` control where contracts matched;
divergences recorded in the implementation report, control left byte-identical.

**Raised a real concern — see decision 0016**: `tick_all()` costs 1.19 ms at 256
residents against a 2 ms whole-tick budget, and the residual is GDScript call
overhead rather than arithmetic.

### 2.10 — Residents store and food-days (**done**)
Allocate residents through `entity_directory.gd`, attach the needs columns, and
compute GDD §5.8 daily demand from each living resident's size and season
multiplier. That supplies food-days its missing divisor so the HUD counter can
populate honestly for the first time. It also produces the second per-resident
timing data point decision 0016 needs before its options can be judged.

### 2.11 — Reservation pool (**done**)
- **Owns** `godot/scripts/core/reservations.gd`, `godot/test/test_reservations.gd`
- **Spec** GDD §4.2 (`Reservation`), decision 0019, resolving **U4**
- 32768 rows allocated **globally from the lowest free index**, with
  variable-length claim lists per Job and per InventoryLot, rather than the
  owner-major `job*4+i` layout the 4:1 ratio superficially implied — that
  reading would have capped a recipe at four input lots.
  `test_recipe_reserves_across_five_or_more_lots` claims seven lots on one job
  and `test_one_job_may_claim_far_more_lots_than_four` claims twelve,
  precisely the case owner-major indexing would have made impossible.
  `claim_batch()` preflights the complete transaction — ref
  validity, per-lot availability, and free-row count after coalescing — so
  insufficient rows refuse explicitly (`CAPACITY_RESERVATION`) with no partial
  reservation left behind. Indexing overhead measures exactly the 786,436
  bytes decision 0019 budgets, and `indexing_bytes()` re-derives that figure
  from the live columns rather than asserting the literal, so a layout change
  cannot silently drift from the ledger. `reserved_milli` is changed only
  through `inventory.gd`'s public API; this module never reads an inventory
  column directly.
- **Acceptance** five-or-more-lot claim, pool exhaustion, spoiled-lot release,
  party-member replacement (decision 0017's coordinator, not a member, owns a
  shared claim) — met. Save/load of active claims is **not** covered; no save
  system exists yet.
- 38 tests. Mutation-tested against every load-bearing rule; three mutants
  survived the first pass and were closed with new tests rather than accepted.
- **U4 is resolved.** Task 2.5's inventory module is otherwise unchanged.

### 2.12 — Job store and selection (**done**)
- **Owns** `godot/scripts/core/jobs.gd`, `godot/test/test_jobs.gd`
- **Spec** GDD §5.3, §4.2/§4.3 (`Job`, `JobAgent`), ARCH-JOB-002, ARCH-STATE-005,
  decisions 0018, 0022, 0023
- Implements six of GDD §5.3's seven eligibility steps (health/rescue safety,
  activity permits work, job-kind priority nonzero, required station/tool/
  skill/unlock, dangerous consent, complete inputs), all five ascending
  urgency buckets, five of the six sort terms
  (`player_priority, job_priority, -skill_level, created_tick, job_id`), and
  the 30-tick reevaluation cadence staggered by persistent resident ID.
  `evaluate()` selects but does not assign; it mutates only the resident's
  continuation and hazard latch, leaving atomic reservation (REQ-SET-030) to
  a caller composing this module with `reservations.gd`.
- **Corrected by decision 0023.** The originally shipped selector (`48998c6`)
  examined its 32-candidate budget in ascending live-row order, so thirty-two
  cosmetic jobs could hide a rescue at position 33 — sorting the examined
  window did nothing for urgency outside it. Enumeration now walks urgency
  buckets 0→4 with one shared 32-candidate budget across the whole pass,
  descending to a lower bucket only after the higher ones are exhausted
  without an eligible candidate; ranking is approximate within a bucket and
  exact between buckets. The positional cursor is replaced with the
  `(bucket, job persistent_id)` continuation key decision 0023 requires,
  because positions shift under repeated insertion/deletion while persistent
  IDs are never reused. A newly available higher-urgency job invalidates any
  continuation that could otherwise walk past it. `assign_worker()` is the
  commitment point and re-runs the hazard latch and all six eligibility
  steps against freshly read gates before binding, so a nomination from
  `evaluate()` is never treated as an authorisation. `GATE_UNAVAILABLE` is a
  new fourth gate state: a declared requirement whose owning subsystem
  cannot answer refuses explicitly instead of reading as satisfied.
- **`required_skill` settled by decision 0022.** It is a minimum level
  (0–10) in the job's own kind, tested through one published
  `validate_job_definition()` used by both `create_job()` and the standalone
  reader; an out-of-range level or a `RESERVED_3` job kind is refused, never
  clamped, with boundary tests at one level below, exactly equal, and one
  level above the required minimum.
- **Named absences, not invented values.** Eligibility step 7 ("legal
  destination") and the `estimated_path_cells` sort term are both absent
  because no pathfinder exists this milestone; two candidates differing only
  in distance fall through to `created_tick` and then `job_id` rather than
  being ordered by a fabricated distance. Travel leases and the 900-tick
  blocked retry (ARCH-JOB-004), the WU/XP model, `ManualTask` (blocked by
  U6), and decision 0017's coordinator Job are all absent. The store does not
  itself prevent the coordinator: `worker` defaults to the null reference and
  `release_worker()` leaves `remaining_mwu` untouched, which is the exact
  separation 0017 needs from whichever module builds it.
- **Acceptance** each eligibility step has a test that fails when that step is
  deleted; the five implemented sort terms are proven with candidates
  differing in exactly one dimension at a time; a rescue behind more than 32
  cosmetic jobs is proven found; reverting enumeration to row order fails
  that rescue test and eight others, and does not fail any pre-existing
  bucket-ordering test — which is exactly why the defect shipped and why
  decision 0023 exists.
- 72 tests in `test_jobs.gd` (was 50 before the 0022/0023 correction).
  Ledger reconciled in `systems_architecture.md` §2.2/§2.3/§3 (ARCH-STATE-005)
  for the module's runtime columns.

### 2.13 — Allocation-free readers on `needs.gd` and `residents.gd` (**in progress**)

Owning decision: `docs/decisions/0016-needs-tick-consumes-most-of-the-budget.md`.
Authorised by Brendan 2026-09-06: *"add allocation-free `_into` readers to the
four owning modules, retain their existing convenience readers, and measure
again. This does not require deciding on GDExtension or changing needs timing."*

**Why this target and not another.** The WU tick was decomposed by measurement,
not inferred: at 256 residents the `work_factor_of()` reader chain is **45%** of
the tick and `resident_may_work()` **19%**, so **~64% is reader-call plumbing
across module boundaries**. `work.gd`'s own party walk, acceptance, split and
carries already allocate nothing, and `jobs.gd` already publishes `_into` forms.
The gap is precisely `needs.gd` and `residents.gd`.

#### Definition of done

**1. The new readers are tested.** As of this writing they are not — the suite
is unchanged at 624 tests, and `test_needs.gd` and `test_residents.gd` contain no
reference to `_into`. New public API with no test is the exact defect class this
project has been bitten by three times: `narrow_to_int32()` shipped with zero
production callers; the ARCH-ID-003 reverse-owner clause could be replaced with
`return true` while all 195 tests passed; the §5.8 seed exclusion could be
deleted with the suite green. CLAUDE.md requires a test per public function.

**2. Each `_into` form is proven equivalent to the convenience reader it
mirrors.** A test that calls only the new form proves it returns *something*, not
that it returns *the same thing*. Assert both forms agree across the input range,
including refusal cases — a refusal must remain a refusal, and must not surface a
stale value in the caller's `out` object. Both readers survive; the convenience
form is not deleted.

**3. Mutation evidence, one mutation per run.** Break each `_into` reader and
confirm a named test fails. A reader that can be broken silently is worse than no
reader, because the hot path now depends on it.

**4. The re-measurement — this is the point of the task.** Repeat the exact
benchmark from decision 0016's measurement section: needs alone, WU alone, and
combined, at 12 and 256 residents, p99 at 1x and p95 on the 4x aggregate, 300
warm-up ticks discarded and 3000 sampled, each configuration run twice in
independent processes. Report before and after side by side. **A change with no
re-measurement does not close this task** — the whole justification is a number.

**5. Determinism preserved.** The prior measurement produced byte-identical
FNV-1a hashes across independent processes over every authoritative column. Those
hashes must still match. An optimisation that changes state is not an
optimisation.

#### What this task does NOT establish
Not a release-build measurement — the export templates directory is empty and no
`export_presets.cfg` exists. Not a qualification-floor result — development is on
an M5 Pro, not the Ryzen 5 3600 / GTX 1660 Super / 16 GB reference. **Decision
0016 stays open regardless of the outcome**, and closing it needs a release build
on documented hardware.

If the measured gain is small, report the real number. An honest 20% is worth
more than a claimed 60%, and it is evidence for the remaining options in 0016 —
which include inlining compared against the retained reference integrator, and
GDExtension. Neither is decided.


### WU reader follow-up — ADR 0016 (done, 2026-09-07)

- [x] Add reusable needs/residents readers and migrate work-factor/eligibility/XP callers.
- [x] Preserve convenience-result ownership, exact refusal behavior and integer formulas.
- [x] Add regression coverage; 631 tests / 19,381 assertions / 0 failures.
- [x] Retain a benchmark harness and compare six fixtures twice before and after.
- **Owners:** REQ-SET-015/020/023, BAL-WORK-001, ARCH-AUTH-003, ARCH-MEM-001,
  ARCH-MIG-006; ADR 0015/0016. Depends on existing needs, residents, jobs and WU stores.
- **Evidence and exact next task:** [work reader report](../validation/work_reader_benchmark.md).
  No existing semantic test retired. The earlier 2.12 absences describe that milestone:
  WU/XP and coordinator subsequently landed in `a8e6e18`; movement, production and save
  limitations are not closed by this follow-up.
- **Does not establish:** release/minimum-hardware budgets, actual 4× rendered-frame CPU,
  complete colony gameplay, expanded movement gates, or missing environmental work factors.


### WU tick profiling and adversarial workloads — ADR 0016 (done, 2026-09-08)

- [x] Profile the remaining productive-WU cost with isolated per-part probes: persistent-ID
  reader, XP write, escaping tick result, plus the factor chain and eligibility gate for
  comparison.
- [x] Add adversarial mixed-band (`bands`) and party-structure (`party`, decision 0017
  coordinators sizes 1–8) workloads beyond the original single-job-per-resident fixture.
- [x] Re-measure; suite unchanged at 631 tests / 19,381 assertions / 0 failures because no
  `godot/scripts` file was modified.
- **Owners:** REQ-SET-015/020/023, BAL-WORK-001, ARCH-AUTH-003, ARCH-MEM-001, ARCH-MIG-006;
  ADR 0015/0016/0017. Depends on the retained benchmark harness from the reader follow-up above.
- **Evidence:** [WU tick profiling report](../validation/work_profile_2026-09-08.md) and
  `docs/decisions/0016-needs-tick-consumes-most-of-the-budget.md`'s 2026-09-08 entry. The
  three named suspects (pid/xp/result) are a smaller share of the tick than the reader
  follow-up's inferred ~64%; the factor chain and un-isolated call-graph work are larger.
  Party structure (256 progress rows vs. 59 coordinators) is the largest effect measured, found
  incidentally rather than by a workload built to isolate it.
- **Does not establish:** a choice among decision 0016's four architectural options, a release
  or qualification-floor measurement, or any change to work arithmetic, needs timing, or
  coordinator/member job structure.


### WU tick optimisation, step 1 — three-workload baseline and lazy persistent IDs (done, 2026-09-08)

- [x] Establish the three-workload baseline (bands/uniform/party, decision 0024) before changing
  any `godot/scripts` file.
- [x] Remove the routine per-contributor persistent-ID read; fetch each frozen contributor's
  identity at most once, only on a finishing tick with milli-WU left over after flooring.
- [x] Re-measure; suite at 644 tests / 20,118 assertions / 0 failures (baseline 631/19,381/0).
- **Owners:** REQ-SET-015/020/023, BAL-WORK-001, ARCH-AUTH-003, ARCH-MEM-001, ARCH-MIG-006;
  ADR 0015/0016/0017/0024. Depends on the benchmark harness from the profiling task above.
- **Evidence:** `docs/decisions/0024-work-tick-optimization-order.md` (the ruling this task
  follows) and `validation-results/work-lazy-id-2026-09-08/`. Raw p50 fell ~5% (bands), ~10%
  (uniform) and ~14% (party) at 256 residents; the needs control (byte-identical file, no code
  change) also fell ~3.6-3.7%, which is measurement drift rather than a code effect. Net of that
  drift the honest estimates are roughly +1.5% (bands), ~6% (uniform) and ~10.5% (party); bands
  is the ordinary-play reference and is the smallest of the three. Finishing-tick stress
  configurations were too noisy to carry a number; no post-change run exceeded its baseline on
  any workload. Every setup and final digest matches the baseline and the previously committed
  profile, so the change is bit-for-bit behaviour preserving on these fixtures.
- **Does not establish:** the `TickResult` `_into` step, release-build setup, the fused reader,
  or a choice among decision 0016's four architectural options. Decision 0016 stays open.


### WU tick optimisation, steps 4-5 — `TickResult` `_into` and re-measurement (done, 2026-09-08)

- [x] Add caller-owned `tick_solo_into()`/`tick_party_into()` alongside the allocating
  `tick_solo()`/`tick_party()` wrappers, retaining one canonical implementation per tick kind
  rather than forking it.
- [x] Overwrite every `TickResult` field on every call, refusals included, so a previous success
  cannot leak into a later failed operation; prove it with mutation evidence, one field-skip per
  run, and a leak test that ticks a success then a refusal into the same object.
- [x] Resolve the standing blocked measurement protocol, which had returned an inconclusive,
  order-dependent sign on two prior blocked runs, with ten interleaved runs per side and a seeded
  permutation test.
- [x] Re-measure; suite at 653 tests / 20,567 assertions / 0 failures (previous entry
  644/20,118/0).
- **Owners:** REQ-SET-015/020/023, BAL-WORK-001, ARCH-AUTH-003, ARCH-MEM-001, ARCH-MIG-006;
  ADR 0015/0016/0017/0024. Depends on the release-build benchmark harness from step 6 below,
  run out of execution order because the release harness already existed from prior work.
- **Evidence:** `validation-results/work-into-2026-09-08/`. Against the interleaved protocol the
  ordinary-play (mixed-bands) reference fell 4.85% and uniform 4.48%, both with permutation
  p < 0.0001; the byte-identical needs drift control moved within 0.5% with p between 0.19 and
  0.84, the first result in this series distinguishable from machine drift. The isolated
  persistent-ID-reader probe ceiling from the release-build entry was 6.4% on mixed bands; the
  realised 4.85% is about three-quarters of that ceiling, consistent with an isolated probe
  overstating a full-tick effect. Parties realised 1.68% against a corrected expectation of
  roughly 2%. The retained allocating wrappers measure 1-2% slower than calling the `_into` forms
  directly, from the added call indirection, so they remain a convenience for cold paths and
  retained results rather than the recommended hot-path call. Also recorded: `work.gd` has no
  production caller yet — it is not wired into any autoload, scene or system, so only the
  benchmark's call sites moved — and the release build manifest's executable hash is identical
  across differing builds because the exported Mach-O is the stock template with GDScript in the
  PCK, so only the packed-fixture and core-source hashes discriminate two builds' code; both
  fired correctly here.
- **Does not establish:** the fused reader (step 7) or a choice among decision 0016's four
  architectural options. Decision 0016 stays open.


### WU tick optimisation, step 6 — release-build setup and re-measurement (done, 2026-09-08)

- [x] Reach an exported release build from the benchmark driver at all, given that the official
  export templates are built with `disable_path_overrides=true` and reject `--path`,
  `--main-pack` and `-s/--script` outright.
- [x] Prove `assert()` is compiled out of the binary being timed, rather than assume it, with a
  three-way probe (editor, `template_debug`, `template_release`) so the result distinguishes
  release from debug templates and not merely editor from non-editor.
- [x] Re-measure editor vs. release across all three workloads at 12 and 256 residents; suite
  unchanged at 644 tests / 20,118 assertions / 0 failures because no `godot/scripts` file was
  touched.
- **Owners:** REQ-SET-015/020/023, BAL-WORK-001, ARCH-AUTH-003, ARCH-MEM-001, ARCH-MIG-006;
  ADR 0015/0016/0017/0024. Depends on the benchmark harness and lazy-ID change from step 1 above.
- **Evidence:** `docs/decisions/0016-needs-tick-consumes-most-of-the-budget.md`'s 2026-09-08
  release-build entry and `validation-results/work-release-2026-09-08/`. The cost ranking did
  not change: the factor chain remains the largest named cost at roughly 30% of the work tick on
  the ordinary-play (mixed-bands) reference, in the same order across all three workloads at
  both populations. Release mode is 28-31% faster across the board, well outside the 2.6-4.1%
  machine drift the byte-identical needs control measured over the session. Combined at 256
  residents is 2160-2700 microseconds at p99 in release, still above the 2000 microsecond tick
  budget, on an M5 Pro that is far faster than the qualification floor. All 58 determinism-digest
  triples present in both runs agree.
- **Does not establish:** a REQ-SET-163 qualification-floor measurement — the reference is a
  Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB machine at 1920x1080, and Windows remains deferred.
  Does not decide who owns the `textures/vram_compression/import_etc2_astc` project setting the
  macOS arm64 export requires: the export helper applies it only to a throwaway project copy and
  records the delta rather than modifying `godot/project.godot`. Does not establish the fused
  reader or a choice among decision 0016's four architectural options. Decision 0016 stays open.


### WU tick optimisation, step 7 — fused work-factor reader (done, 2026-09-08)

- [x] Add `needs.work_factor_for_resident_into()`, validating one resident row once and calling
  the two existing formula implementations (`_mood_of_checked_row_into()`, `work_factor_into()`)
  rather than copying either; `work._compute_factor()` now makes one needs call instead of three.
- [x] Keep exactly one implementation of the mood formula: `mood_into()` now delegates to the
  same private `_mood_of_checked_row_into()` the fused reader calls.
- [x] Prove it is a call-count reduction and NOT a cache — nothing retained, no dirty flag, no
  invalidation rule — in the module docstring, the function docstring and a test that changes a
  need and then health between two calls on the same resident and asserts both moves are seen.
- [x] Replace the `needs` drift control, which this change invalidates by editing `needs.gd`
  itself, with a pair of controls differing in one property: an allocation-free
  `entity_directory.gd` sweep (`dirctl`) and an allocating `priorities.gd` sweep (`prioctl`),
  both reading the same fixture and population as the configs under test.
- [x] Re-measure; suite at 662 tests / 24,689 assertions / 0 failures (previous entry
  653/20,567/0).
- **Owners:** REQ-SET-015/020/023, BAL-WORK-001, ARCH-AUTH-003, ARCH-MEM-001, ARCH-MIG-006;
  ADR 0016/0024 section 4. Depends on the release-build benchmark harness from step 6 above.
- **Evidence:** `validation-results/work-fused-2026-09-08/`. The realised effect is far below the
  expectation set from the isolated factor-chain probe (roughly a third to mid teens): 1.0-1.6%
  across the three workloads at 256 residents, permutation p between five and one hundred fifteen
  ten-thousandths. The factor chain is ~32% of the tick, but the fused reader removes only the
  duplicated presence validation and one call frame within it — about two of roughly fifteen call
  frames per resident — not the chain itself; treating the isolated probe's cost as the removable
  amount is exactly the error decision 0024 warns against, and it is the error the pre-change
  expectation made. The `prioctl` control moved +1.33% on the party workload (p = 0.0105) while
  `dirctl` stayed flat on the same runs; this does not explain the work-tick result, since the
  control moved up while the measured tick moved down on the same session, which is what the
  allocating/allocation-free pair exists to distinguish, and it is reported rather than absorbed
  into the headline number. A found cost: sharing one mood implementation means `mood_into()` now
  delegates, and the unfused factor probe measured 2.8-3.8% slower as a result, accepted because a
  duplicated §7.1-verified formula is the drift hazard decision 0024 section 4 forbids and neither
  `mood_into()` nor `mood_of()` has a production caller. Mutation evidence: six single-line
  mutations to the shared work-factor divisor, each restored and hash-verified before the next,
  were each caught — the per-path absolute-value tests fail (59 tests), while the fused/unfused
  equivalence test correctly stays green because both paths move together. Equivalence is swept
  across 660 mood/health/skill-level combinations plus memory-total extremes, and refusal parity
  is checked for 7 invalid-input cases. Determinism held exactly: all three `wu` digests match the
  values already committed in the step-4/5 and step-6 entries. The full 20-run interleaved series
  was discarded and re-run once, after a harness docstring was found to disagree with its own code
  following a control resize; the repeated series agreed with the discarded one.
- **Does not establish:** a choice among decision 0016's four architectural options, or whether a
  cache is justified — decision 0024 section 4 requires any cache's invalidation contract to cover
  every mutation before one may be authorised, and none is proposed here. Decision 0016 stays
  open.


### ARCH-MIG-006 step 6 wiring — SettlementSystem production caller (done, 2026-09-08)

Every core module measured across the WU-tick optimisation entries above —
needs, schedule, priorities, jobs, work, reservations, and the entity directory
beneath them — was built, tested and benchmarked with **no production caller**.
The running game never invoked any of them, so every one of those figures
described a benchmark fixture, not the game. This entry wires them in.

- [x] Add the `SettlementSystem` autoload: compose the six stores once in
  `_init()`, bind to `GameManager` as its simulation via a direct call rather
  than a signal, and run the §5 stages that have an implemented owner —
  interval integration, activity resolution immediately before the pass that
  reads it, job selection, then productive work over live jobs — once per
  completed tick, plus the season handover at the daily boundary.
- [x] Give `GameManager` a `bind_simulation()`/`unbind_simulation()` pair that
  refuses a second binding, forwards `completed_tick() + 1` so no second tick
  counter can drift, and runs the day-boundary callback before the existing
  `day_advanced` UI signal so the HUD never observes an uncommitted day.
- [x] Point `main.gd` at `SettlementSystem.create_initial_settlement()` for the
  §5.1 cohort instead of constructing `residents.gd` locally, and reset
  `EconomySystem` before `SettlementSystem` on boot so the borrowed residents
  binding is dropped before the store it points at is cleared.
- [x] Name every one of the remaining 18 of 23 `systems_architecture.md` §5
  stages in the new file's header, with the store each is blocked on, rather
  than leaving the gap implicit.
- [x] Mutation-test the new file: sixteen single-line mutations, one per run,
  each restored and hash-verified. Fifteen killed; the one survivor was a
  redundant emptiness guard duplicating a refusal `residents.gd` already owns
  and was fixed by deleting the duplicate, not by adding a test that defends
  duplicated logic (decision 0025).
- [x] Re-measure; suite at 696 tests / 24,800 assertions / 0 failures (previous
  entry 662/24,689/0), verified twice independently with identical numbers, plus
  a clean editor import and a 300-frame boot with zero ERROR lines.
- **Owners:** REQ-SET-003/004/007/011/143, ARCH-SYS-003/008/010/013/017,
  ARCH-MIG-006 step 6. Depends on every store built and measured in the WU-tick
  optimisation entries above.
- **Evidence:** decision `0025-settlement-system-wiring.md`. First real
  measurement of the actual autoload composition rather than a fixture: a
  settlement tick costs a mean of 82 microseconds and a maximum of 135 at the
  twelve-resident starting cohort, debug editor binary, macOS. This is not
  REQ-SET-163 evidence — twelve residents is not 256, and qualification needs
  an exported release build on the Windows reference floor. The job queue is
  empty and stays empty: nothing creates a job (no production orders, recipes,
  construction, care requests, hauling policy or harvest zones exist), and no
  job source was invented to make the loop look busy. Known coverage gap:
  `needs.tick_all()`'s refusal branch is unreachable from this suite without
  corrupting needs state through a file this task does not own, so it is
  untested and not claimed otherwise.
- **Does not establish:** a playable colony, movement, a job source of any
  kind, the remaining 18 §5 stages, or any REQ-SET-163 qualification claim. Two
  further gaps block job completion even once a source exists: `jobs.gd`
  eligibility implements 6 of 7 steps (no pathfinder), and `assign_worker()`
  leaves a job at `JOB_STATE_RESERVED` because `RESERVED -> TRAVEL -> WORK` is
  movement's responsibility and movement does not exist yet.
