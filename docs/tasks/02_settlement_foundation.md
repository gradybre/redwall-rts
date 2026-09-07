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
| U5 | No allocator storage budgeted for non-directory child stores (Reservation, GearInstance, BatchState, LotEffect, NoticeCondition, ChildSliceIndex) | Tasks 2.3, 2.5 and the memory ledger | Directory-kind allocation only |
| U6 | Missing owner-major index formulas for MoodMemory, ManualTask, HivePollinationLinks, Feast.attendees, Feast.reserved_lots | Later tasks | Not required this milestone |
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
- **Blocked by U5** for non-directory child stores

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
- **Spec** GDD §5.3, §4.2/§4.3 (`Job`, `JobAgent`), ARCH-JOB-002, decision 0018
- Implements six of GDD §5.3's seven eligibility steps (health/rescue safety,
  activity permits work, job-kind priority nonzero, required station/tool/
  skill/unlock, dangerous consent, complete inputs), all five ascending
  urgency buckets, five of the six sort terms
  (`player_priority, job_priority, -skill_level, created_tick, job_id`), the
  30-tick reevaluation cadence staggered by persistent resident ID, and the
  32-candidate budget with a saved per-resident cursor that resumes rather
  than restarting. `evaluate()` selects but does not assign; it mutates only
  the resident's scan cursor and hazard latch, leaving atomic reservation
  (REQ-SET-030) to a caller composing this module with `reservations.gd`.
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
  differing in exactly one dimension at a time; the cursor is proven with a
  pass over more than 32 candidates.
- 50 tests, 21 mutations applied, none survived.
