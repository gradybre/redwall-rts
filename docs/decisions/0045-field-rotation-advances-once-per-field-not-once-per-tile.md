# 0045 — Field rotation advances once per field, on a caller-supplied participating set
Date: 2026-09-10 · Status: Accepted

## Decision

`scripts/core/field_policy.gd` implements GDD §4.2's `FieldPolicy` row and
R06-JOB-005's rotation advance. Nine things are settled here.

1. **There is no plot → field mapping in this build, and none is invented.** The
   participating set is a **validated caller-supplied group**: `open_cycle()`,
   then one `enrol_plot()` per plot.
2. **The eight §4.2 columns are implemented unchanged and unenlarged** — 128
   rows, six I32 (3072 B) and two B8 (256 B), exactly the
   `systems_architecture.md` §2.2 budget.
3. **The cycle state R06-JOB-005 needs is not in §4.2's row**, so it is budgeted:
   **40960 new bytes**, seven per-field I32 columns, four per-field B8 columns,
   and a plot-major enrolment ledger over `farming.gd`'s own 4096 FarmPlot rows.
4. **Three cursors now exist and none of them is another.** Decision 0040's
   per-plot sowing ordinal stays in `job_planner.gd` and is neither read, written
   nor duplicated here.
5. **"Exactly once" is enforced by four independent guards**, not one flag.
6. **A blocked entry is never skipped and no crop is ever substituted.** There is
   no loop over the other rotation entries anywhere in the file.
7. **Erasing a tile is a withdrawal, never a resolution**, and a field whose every
   participant is withdrawn closes **ABANDONED** — no advance, no completion.
8. **An explicit cancellation is recorded in its own durable per-field counter**,
   kept apart from the completion counter.
9. **REQ-SET-088's seed reserve is an unsatisfiable gate that refuses.** It
   answers `GATE_NOT_REQUIRED` or `GATE_UNAVAILABLE` and never `GATE_SATISFIED`.

## Why

### The plot → field mapping was checked, not assumed

Three places could have held it and none does.

* **GDD §5.6 says so in its own words**: "A plot records its own growth and soil;
  **field grouping is a UI/work aggregation**."
* **`farming.gd`'s FarmPlot row carries a tile**, a soil and a crop — no zone
  reference. `TileHistory.active_plot_row` is tile → plot, the opposite direction.
* **`forage.gd` owns a zone ↔ tile link store** and `create_zone()` does accept
  `ZONE_TYPE_FARM`. But it publishes only the *tile-major* walk
  (`tile_link_head_of()`, `next_tile_link()`, `zone_slot_of_link()`);
  `_zone_link_head` is private, so no caller can enumerate a zone's tiles. And
  nothing anywhere binds a FARM zone to a FarmPlot.

Composing those two stores into a field membership map would have required a new
public reader on `forage.gd` *and* an authored FARM-zone-to-plot binding that no
document specifies. So the set is caller-supplied, on the precedent
`farming.gd` sets by taking `pollination_factor` as a parameter and `fishing.gd`
by taking `base_catch_milli` as one. Everything that *can* be validated is: a live
FarmPlot row, an open cycle, no double enrolment across fields, a stamp matching
this cycle, and an outcome still unresolved.

### Why the enrolment ledger is stored at all

The ruling's first named failure mode is "advancing once per tile", and it says
that is the defect most likely to pass a naive test. **A counter alone cannot
close it**: without per-plot identity, one fast plot reporting twice is
indistinguishable from two plots reporting once. So the group the caller supplied
is recorded plot-major and stamped with the field's cycle ordinal.

It is an **enrolment ledger, not a membership map**. Outside an open cycle it
answers nothing — the stamp goes stale the moment the next cycle opens, and
`is_plot_enrolled()` reports false. It never groups anything on its own and it is
never consulted to decide which plots belong to a field.

### Three cursors, reconciled rather than merged

Decision 0040 gave sowing a field-cycle identity **because no `FieldPolicy`
existed**. That identity now meets this store, and the reconciliation is that the
three quantities count different things:

| Cursor | Owner | Domain | Purpose |
|---|---|---|---|
| `job_planner._cycle_cursor[plot]` | decision 0040 | per plot, monotonic, never wraps | third term of `(owner, SOW, field cycle)` |
| `FieldPolicy.rotation_cursor` | GDD §4.2 | per field, 0..2, **wraps** | which crop is next |
| `FieldPolicy._cycle_ordinal` | this decision | per field, monotonic, never wraps | stamps an enrolment |

A field of ten plots has ten independent per-plot cursors and one rotation, so
neither field-level quantity is derivable from decision 0040's per-plot one. The
ruling's "any non-derivable cycle intent must be included in the schema/budget"
therefore applies to both, and both are budgeted below. **Nothing was moved,
renumbered or duplicated**: `job_planner.gd` still owns its per-plot ordinal,
`field_policy.gd` never touches it, and no second per-plot cursor exists. Only
`job_planner.gd`'s header comment changed, to say all of this where a later reader
will look.

### "Exactly once" has four guards, so no single edit removes it

1. `_maybe_close_cycle()` closes only when `_resolved == _participants` with
   `_participants > 0`. A fast plot leaves `_resolved` below `_participants`.
2. Closing sets `CYCLE_CLOSED`; every resolution entry point requires
   `CYCLE_OPEN`, so a late resolution refuses with `NO_OPEN_FIELD_CYCLE`.
3. A plot whose outcome is not `UNRESOLVED` refuses, so one plot cannot count
   twice inside one cycle.
4. A stamp from a previous cycle is stale and refuses.

The advance itself is `(cursor + 1) % 3`, evaluated once inside
`_advance_rotation()`, which `_close_cycle()` reaches at most once per cycle.

### Withdrawal: two rules that had to be stated, not discovered

The ruling gives one sentence — "Erasing a tile is not successful harvest" — and
two consequences follow that it does not spell out.

**A resolved plot cannot be withdrawn.** A harvest that happened stays happened
when its tile is later erased. That is also the invariant that makes
`_resolved <= _participants` true, and therefore what makes `_participants == 0`
imply `_resolved == 0`.

**Withdrawing every participant closes the cycle ABANDONED, not COMPLETED.**
*This is an interpretation and is recorded as one.* The alternative readings were
both worse: counting an erased tile as resolved is exactly the fabrication the
ruling forbids, and leaving the cycle open on a field with no plots left is a
permanent stall that no later event can clear. ABANDONED refuses the completion
without deadlocking, advances nothing, and increments neither durable history
counter. Erasing a whole field can therefore never advance its rotation.

A withdrawal gets **its own refusal code**, `PLOT_WITHDRAWN`, rather than sharing
`PLOT_ALREADY_RESOLVED`. A caller cannot act on "this tile was erased" and "this
plot already harvested" the same way, and folding them together would report an
erasure as a recorded harvest — the very thing the ruling forbids.

### The window has three answers because the ruling names three

`_classify_window()` scans the year's 48 season-local days through
`farming.is_plant_window()` — §5.6's **owning** formula, never a copy of its
window table — and answers `READY`, `WINDOW_FUTURE` ("retain the request") or
`WINDOW_MISSED` ("show the existing warning and wait"). Both non-ready answers
retain the request; they differ in what the UI shows, which is the whole of the
distinction the ruling draws.

A fourth answer, `CROP_HAS_NO_LEGAL_WINDOW`, exists for a crop naming no legal day
at all. §5.6's table gives every crop at least one, so it is unreachable through
the compiled catalog; it is kept for the reason `forage.gd` keeps its malformed
`P > K` guard — a save/load path is coming and cannot be trusted to be well
formed — and it is exercised through a test subclass rather than pretended to be
covered. Reporting such a crop as a *missed* window would be a lie: "wait for its
next legal window" would never come true.

### REQ-SET-088 refuses because nothing can satisfy it

Every `reservations.gd` row is §4.2's `Reservation: job: EntityRef, lot:
EntityRef, ...` — **owned by a Job**. A standing seed reserve has no Job: the next
planting has not been confirmed, and decision 0040's sowing Job already carries
`inputs_gate = GATE_UNAVAILABLE` precisely because the seed supply cannot be
answered. There is also no export path and no "nonplanting use" path to gate.

So `seed_reserve_gate_of()` answers `GATE_UNAVAILABLE` while the policy is on and
`authorise_seed_release()` refuses with `SEED_RESERVE_UNANSWERABLE`. It never
answers `GATE_SATISFIED`; decisions 0039 and 0040 set that precedent for §5.6's
water and seed.

What *can* be computed honestly is the **quantity**:
`seed_requirement_milli_into()` multiplies §5.6's seed U/tile, read through
`farming.seed_milli_of()`, by a caller-supplied tile count, with a checked
multiply that refuses on overflow. The tile count is caller-supplied for the same
reason the participating set is. **The crop → seed item id join is not made
here**: §5.6 says only "corresponding seed", `item_definitions.json` holds
`seed_grain` and its four siblings, and nothing authors the join. The requirement
is a quantity, never an item.

## Storage added

| Group | Type | Width | Count | Rows | Bytes |
|---|---|---:|---:|---:|---:|
| `cycle_ordinal, participants, resolved, withdrawn, completed_cycles, cancelled_cycles, requested_crop` | I32 | 4 | 7 | 128 | 3584 |
| `field_present, cycle_state, close_reason, request_state` | B8 | 1 | 4 | 128 | 512 |
| `FieldPolicy.enrolment: plot_field_slot, plot_cycle` | I32 | 4 | 2 | 4096 | 32768 |
| `FieldPolicy.enrolment: plot_outcome` | B8 | 1 | 1 | 4096 | 4096 |
| **Total** | | | | | **40960** |

§4.2's own eight columns are unchanged at 3328 bytes. Every dependent total in
`systems_architecture.md` §2.3 is recomputed:

| Metric | Was | Now |
|---|---:|---:|
| Fixed registry payload | 24952146 | 24993106 |
| Planned allocated payload | 59321038 | 59361998 |
| One live world plus reserve | 67709646 | 67750606 |
| Headroom below decimal 100 MB | 32290354 | 32249394 |
| Additional candidate mutable state | 53105454 | 53146414 |
| Transactional peak plus same reserve | 120815100 | 120897020 |
| Transactional headroom | −20815100 | −20897020 |

`live = payload + reserve`, `headroom = 100000000 − live`,
`candidate = payload − 6215584`, `peak = live + candidate`,
`t-headroom = 100000000 − peak`. All five hold. ARCH-MEM-006's conclusion is
unchanged: the two-world design was already rejected and is rejected by a slightly
larger margin.

**A pre-existing bookkeeping gap of 437632 bytes was found and is reported, not
silently fixed.** `systems_architecture.md` §2.2's prose "Fixed-field payload sum"
(24514514 before this change) is 437632 below a mechanical sum of §2.2's own table
rows (24952146 before this change), which is exactly
`131072 + 306304 + 256` — the claim-ordering cache "declared separately per
R05-QUOTA-024", the decision 0026/0030 groups and the decision 0027 group, all
three of which §2.3's derivation line adds *back* on top of the prose sum while
they are also present as table rows. The same 437632 separates §2.3's allocation
column from its stated "Planned allocated payload". Both numbers were moved by
exactly +40960 here, preserving every stated relation; resolving which of the two
is canonical is a change to a document this work does not own. The row identity
`width * count * rows == bytes` holds on all 135 §2.2 groups and all 54 §3 groups
including the four added here. §2.2's stated group count is likewise carried
forward as 159 → 163, the honest delta of this change; a mechanical count of §2.2
gives 131 → 135, and that discrepancy is also pre-existing.

## Gates evaluated, and gates deferred with their blocking store

| Requirement / gate | Owner | Treatment |
|---|---|---|
| R06-JOB-005 advance-once | this module | **Implemented.** Four guards; `advance_count()` is observable |
| R06-JOB-005 no skip, no substitute | this module | **Implemented.** One entry read at the cursor; no loop exists |
| R06-JOB-005 future window retains | `farming.is_plant_window()` | **Implemented.** `PLANT_WINDOW_IS_FUTURE` |
| R06-JOB-005 missed window warns and waits | `farming.is_plant_window()` | **Implemented.** `PLANT_WINDOW_MISSED` |
| R06-JOB-005 `auto_rotation = false` | §4.2 column | **Implemented.** First statement of `_advance_rotation()` |
| REQ-SET-077 blocked reasons | this module | **Implemented.** One byte, one mapping, four reasons |
| Zone is FARM type | `forage.zone_type_of()` | **Evaluated.** `ZONE_TYPE_MISMATCH` |
| Plot is live | `farming.is_present()` | **Evaluated.** `PLOT_NOT_PRESENT` |
| Erasing ≠ harvest | this module | **Implemented.** `withdraw_plot()`, `PLOT_WITHDRAWN` |
| Cancellation recorded | this module | **Implemented.** Separate durable counter |
| REQ-SET-070/071 sowing gates and seed consumption | `job_planner.gd`, `farming.plant()` (decision 0040) | **Not duplicated here.** This module requests a crop; it sows nothing |
| REQ-SET-078 fallow fertility | `farming.apply_fallow_day()` | **Not duplicated here.** Already implemented with §5.6's 50/day and the 12-day LEGUME bonus |
| REQ-SET-073/085 harvest and clearing jobs | existing route | **Observed, not created.** `record_plot_resolved()` takes their outcome |
| **REQ-SET-088 seed reserve** | *none* — every `reservations.gd` row is Job-owned | Answers `GATE_UNAVAILABLE`; `authorise_seed_release()` **refuses** |
| **Crop → seed item id** | *none* — §5.6 says only "corresponding seed" | **Not invented.** The requirement is a quantity |
| **Field tile count** | *none* — no store groups tiles into a field | Caller-supplied parameter, validated |
| **Player command delivery (U2)** | *none* — ARCH-CMD-003 unimplemented | Five entry points exist; nothing calls them |

## Consequences

- **`create_policy()`, `set_rotation()`, `set_rotation_cursor()`,
  `set_auto_rotation()` and `set_seed_reserve()` exist and nothing calls them.**
  Blocker U2 stands. **No command kind is invented and ARCH-CMD-003 is not
  renumbered**: `SET_FIELD_ROTATION` and `SET_POLICY` already exist in
  `catalog_ids.json`, and the ruling's implementation boundary directs that their
  *payloads* be refined, which is a change to a document this work does not own.
- **Nothing opens, enrols or resolves a cycle in the running build.**
  `open_cycle()`, `enrol_plot()`, `record_plot_resolved()` and `withdraw_plot()`
  are the seams ARCH-SYS-006 (increment 10) drives; that orchestrator does not
  exist, so no rotation ever advances outside the tests.
- **`OrderMode` is untouched.** No field id and no zone id is written into a
  `recipe_id` and no `ProductionOrder` is created: the ruling says in its own
  words that "field rotation and daily hive care are not production recipes".
- **Nothing writes `JOB_STATE_WORK`, because nothing here writes a Job at all.**
  The module holds no reference to `jobs.gd`'s store; it preloads that script for
  two §4.2 gate values and nothing else.
- **No save round trip.** Persistence is in-process only, so the enrolment ledger,
  the two durable per-field counters and the rotation columns have no
  serialization and no load-time revalidation. `_cycle_ordinal` is deliberately
  monotonic across a row's whole lifetime — `create_policy()` does not reset it —
  so a row reused by a different zone cannot inherit a stale enrolment; that
  property is what a load repair would have to preserve.
- **`farming.gd`, `forage.gd`, `jobs.gd` and `reservations.gd` are untouched.** No
  column, refusal or contract in any of them changed. Only `job_planner.gd`'s
  header comment changed, and only to record the three-cursor reconciliation.
- **A destroyed FARM zone's policy row is reclaimed by the next zone that binds
  to it.** `destroy_policy()` cannot reach such a row — its own zone reference no
  longer resolves — so without reclamation a destroyed zone would block its row
  permanently. Found by writing the test, not by review.
- **Two allocations happen inside modules this work does not own**, each their
  published contract and each on a cold path: `forage.zone_type_of()` once per
  `create_policy()`, and `farming.seed_milli_of()` once per seed-requirement
  question. Neither publishes an `_into` form. Reported, not worked around by
  editing a file this work does not own.

## Mutation results

**48 mutants over 50 suite invocations, one mutation per run, each with a
300-second hard timeout, each restored from a pristine copy and sha256
byte-compared before the next was applied.** All 50 restores matched
`262198e7a04d340c5205007c7ff1124264efe761b675fd99f657fb38a9fb5315`. Targets
included the once-per-field guard (4 mutants), the cursor advance (3), the
`auto_rotation` gate (2), the blocked-entry rule (2), the window classifier (6),
each of the four §4.2 defaults (8, counting the paired write-site mutants below),
the withdrawal rules (4), the cancellation and abandonment paths (4), and the
REQ-SET-088 gate (3).

**47 killed, 1 equivalent.** Representative:

| Mutant | Killed by |
|---|---|
| once-per-field guard removed | `the fast plot advances nothing (expected 0, got 1)` |
| cursor advances two | `the last resolution advances the cursor by exactly one (expected 1, got 2)` |
| `auto_rotation` gate removed | `but the cursor did not advance (expected 0, got 1)` |
| blocked entry skipped | `no crop was substituted for the blocked entry (expected -1, got 4)` |
| erasing counts as a harvest | `the erase resolved nothing (expected 0, got 1)` |
| cancellation fabricates a completion | `and no completion was fabricated (expected 0, got 1)` |
| seed gate reads as satisfied | `it declares the requirement unanswerable (expected 3, got 1)` |
| `auto_rotation` default true | 76 failing assertions, starting `auto_rotation defaults false (expected false, got true)` |

### Two mutants died only on an `_init` assert, and both were paired

Changing `DEFAULT_AUTO_ROTATION` or `DEFAULT_SEED_RESERVE` trips
`_assert_borrowed_contracts()` at construction, so the whole suite dies in
`before_each` and the kill proves only that the assert exists. Both were therefore
**paired with a write-site mutant that leaves the constant alone** —
`_auto_rotation[field_slot] = 1` and `_seed_reserve[field_slot] = 0` inside
`_write_default_policy()`. Both die on real values:
`auto_rotation defaults false (expected false, got true)` and
`it declares the requirement unanswerable (expected 3, got 0)`. The other two
defaults (`DEFAULT_ROTATION`'s three entries and `DEFAULT_ROTATION_CURSOR`) are
not asserted in `_init` and were already killed behaviourally, with
`_rotation_cursor[field_slot] = 2` as the cursor's own paired write-site mutant.

### One real gap the run found

**`today` could have been off by one and no test would have noticed.** Mutating
`_classify_window()`'s `today = season * 12 + season_day - 1` to
`season * 12 + season_day` survived the whole suite. The reason is a property of
§5.6's own table: **every planting window there is at least three days long**
(the shortest are beans summer 1–3 and cabbage autumn 1–3), so a crop whose next
legal day is *tomorrow* always has a legal day the day after too, and an
off-by-one still finds one. No crop in the compiled catalog can distinguish the
two.

The fix is a test, not a declaration of equivalence:
`SingleDayWindowFarming` admits exactly one day of the year, and
`test_a_window_starting_tomorrow_is_future_and_not_missed` reads it on the day
before. The mutant now dies with
`spring day 12 is still ahead of spring day 11 (expected 2, got 3)`. Two more
assertions pin the same crop on its legal day (READY) and after it (MISSED), so
the new test cannot pass by reporting FUTURE for everything.

### The one equivalent mutant, with its proof

`_classify_window()`'s `if ordinal > today:` → `if ordinal >= today:` survives,
and it is **provably equivalent**. The loop is reached only after the early
`is_plant_window(crop_id, _calendar.season, _calendar.season_day)` returned false.
Inside the loop the comparison is reached only when
`is_plant_window(crop_id, ordinal / 12, ordinal % 12 + 1)` is true; at
`ordinal == today` those two calls have identical arguments, because
`today = season * 12 + season_day - 1`. So `ordinal == today` never reaches the
comparison and `>` and `>=` select the same set. No test can distinguish them
without first breaking `today` — which is a different mutant, and that one is now
killed.

### A harness defect worth naming

The first classifier read `"0 failure(s)" not in summary` and therefore reported
`1598 test(s), 40289 assertion(s), **10** failure(s)` as a survivor: `"0
failure(s)"` is a substring of `"10 failure(s)"`. One genuinely killed mutant
(the beans default) was misreported before the count was parsed as an integer
instead. A substring test on a mutation harness can manufacture a phantom
survivor on every multiple of ten.

## Alternatives rejected

- **Deriving the field from `forage.gd`'s zone ↔ tile links plus
  `TileHistory.active_plot_row`.** It needs a public zone → tile walk that does
  not exist and an authored FARM-zone-to-plot binding that no document specifies.
  That is inventing a grouping contract, not reading one.
- **A field-major membership array, 128 × 256 tiles.** 131072 bytes for a group
  that is only meaningful during an open cycle, against 36864 plot-major — and it
  would still not answer "is this plot already someone else's participant?"
  without a scan.
- **Counting resolutions without per-plot identity.** 4096 bytes cheaper and it
  leaves R06-JOB-005's first named failure mode wide open.
- **Folding `FieldPolicy.rotation_cursor` into decision 0040's per-plot ordinal.**
  They have different domains (0..2 wrapping versus monotonic never-wrapping),
  different owners (field versus plot) and different purposes (which crop versus
  which cycle). Merging them would have made a ten-plot field's rotation depend on
  which plot was confirmed last.
