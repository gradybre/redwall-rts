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
| U2 | Speed/pause scheduler events have no command kind (ARCH-CMD-003 has 24 kinds, none for speed/pause), no ordering tiebreak, no save section (ARCH-SAVE-002 §12 is `PENDING_COMMANDS` only) | Task 2.4 queued pause determinism | Implement immediate speed/pause state; **defer** queued scheduler events. **Resolved 2026-09-11 in process** by R07-SCHED-001 / decision 0054: a separate queue with its own kind domain and its own unsigned sequence as the tiebreak, so ARCH-CMD-003's 24 ids stay stable. The save section is implemented and unwired; persistence stays blocked on task 09 |
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

**2.2a — `InjuryKind` published, 2026-09-12** ([decision 0108](../decisions/0108-injurykind-is-published-and-spoil-waits-for-its-authored-row.md)).
SET-MOVE-ECON-001 HAZ-001 requires the **existing** GDD §4.3 domain be reused, so
`catalog.gd` now carries `NONE=0, CUT=1, BITE=2, FALL=3, EXPOSURE=4, EXHAUSTION=5`
(`game_gdd.md:215`) in `PROTECTED_ENUM_DOMAINS` — five of those six disagree with
the ascending-ASCII regeneration, which is exactly why it is protected rather than
compiled. `catalog_ids.json` moved 4062 -> 4140 bytes, 28 -> 29 domains,
275 -> 281 rows, digest `3407b52e...c3e90` -> `4fdd24b8...b1e8a`: an intentional
catalog/schema change. The aggregate Injury store, severities, drains and care work
are **not** here and remain task 08's.

- [ ] **`excavated_earth` ItemDefinition — blocked, not started.** ECON-002 authors
  the row completely (MATERIAL, 1000 g/U, nutrition 0, shelf_hours 0, raw_edible
  false, seed false, NONE/0) and forbids aliasing `stone` or `compost`. It needs a
  `docs/gameplay_balance.md` §3.1 row and `EXPECTED_ROW_COUNT` 60 -> 61 in
  `tools/extract_item_definitions.py`; §3.1 is the catalog's single authored source
  and the suite runs that real extractor against that real document, so the key
  cannot be hand-inserted into the JSON or into `catalog.gd`.
- [x] **`InventoryLot.provenance` domain — unblocked and published** (decision 0113).
  PROV-R01 supplied the one thing this entry asked for: the domain name plus the
  complete member list. `catalog.gd` now carries `InventoryProvenance` in
  `PROTECTED_ENUM_DOMAINS` as `ORDINARY=0, STARTER=1, COASTAL_BRINE=2,
  EXCAVATION=3, BACKFILL_RECLAIM=4, SPOIL_RECLAIM=5` — protected, not compiled,
  because all six disagree with the ascending-ASCII regeneration.
  `catalog_ids.json` moved 4161 -> 4282 bytes, 29 -> 30 domains, 282 -> 288 rows,
  digest `d5bf21b4...cfd67` -> `4b25ab62...5677d`: an intentional catalog/schema
  change. `inventory.gd` refuses a non-member with `INVALID_PROVENANCE`, and
  `UNSET_PROVENANCE` is now the compatibility spelling of ORDINARY.
  **Still open, reported to their owners:** the saltpan recipe's input filter and
  EH-02's excavation/backfill/spoil transactions must call
  `Catalog.check_salt_brine_input()` / `check_lot_provenance()` /
  `check_earth_withdrawal()` before creating a lot; the embedded-ledger columns
  themselves are EH-02's and are not built here.

Neither remaining blocker closes or advances any MOVE gate, and task 05.1b remains
not started.

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
  - **U2 unblocked 2026-09-11** by `scripts/core/scheduler_events.gd`
    ([decision 0054](../decisions/0054-the-scheduler-event-queue-drains-before-every-tick.md)),
    implementing task 04.1's completed amendment R07-SCHED-001. The ordering
    tiebreak that was missing is this queue's own unsigned 64-bit sequence; the
    save section exists as an implemented, validated, UNWIRED `SCHQ0001` codec, so
    **persistence remains blocked on task 09's save module.** ARCH-CMD-003 still
    has exactly 24 kinds and none is a speed or pause kind, which is deliberate.
  - **The queue reached the running game 2026-09-11** under
    [decision 0084](../decisions/0084-the-running-game-drives-the-scheduler-event-queue.md).
    `game_manager.gd` now folds each host frame through
    `scheduler_events.advance_frame()`, which supplies both the `before_tick`
    barrier and the `on_overload` hook, and every speed and pause control submits
    a queue event instead of calling `set_pause()`/`set_speed()` itself. Decision
    0054 had recorded, correctly, that none of that happened in play.
    `scheduler_events.gd` is byte-unchanged by that work; `sim_clock.gd` changed
    in comments only. **Persistence is still blocked on task 09**, unchanged.
  - **U3 is NOT unblocked.** The conservative rule stands; decision 0054 records
    the explicit reconciliation of ARCH-CLOCK-002's recovery exception against GDD
    REQ-SET-008. `acknowledge_without_catchup()` and its tests are unchanged.

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

## Lane records

Dated write-ups from finished lanes live in [`lanes/02/`](lanes/02/), one file
each. **Do not append a dated section to this file** -- a shared append point made
five lanes conflict in a single round, and `tools/lane_notes.py --check` now
refuses it in CI. Tick the boxes above; write the record there. The convention is
in [`lanes/README.md`](lanes/README.md).
