# FieldPolicy (owner 3) — independent feasibility review
Read-only discovery. No contract accepted, no implementation, nothing executed or measured.
Every statement is read from `godot/scripts/core/field_policy.gd`, `godot/test/test_field_policy.gd`,
ADR 0045, the R06-JOB-005 ruling and the compiled section-4 row.
## Confirmed layout
- Owner 3, version 1, primary 128, one child extent (4096), field span 60–79, payload 44460,
  block 44496, offset 8458852.
- Value bytes 44288 = 44460 − 12 wrapper (u32 child count + u64 extent) − 160 field counts.
  Source arithmetic, not a measurement.
- All twenty columns are `PackedInt32Array` / `PackedByteArray`. No float on any path.
## Verdict: partially provable through public readers
Public typed readers cover the seventeen per-field columns **only while `is_present`**, plus
`plot_outcome_of` (ungated). Three gaps are decisive:
- `_plot_cycle` has **no public reader at all**.
- `plot_field_slot_of` **refuses** unless `is_plot_enrolled` — exactly the stale stamps the
  retention hypotheses concern.
- Every per-field reader gates on `is_present`, so **no inactive row's retained history is
  publicly readable**.
Retained and stale state can therefore be evidenced by source reading plus pure synthetic
fixtures (construct → mutate → observe through the writers' own effects), not by public history
capture. There is no `columns()`, `state_bytes()`, capture or restore API, and private column
inspection must not be presented as public history.
## Counterexamples refuting the parent note's hypotheses
1. **"An inactive row is all zero."** False. `destroy_policy()` clears zone, presence, cycle
   state, request, requested crop, participants and resolved — and leaves rotation ids/cursor,
   auto, seed reserve, ordinal, withdrawn, completed, cancelled and close reason. An absent row
   can carry `close_reason = COMPLETED` and `withdrawn > 0` with `participants = 0`.
2. **"Recreate resets the ordinal."** False. `_write_default_policy()` deliberately never touches
   `_cycle_ordinal`; `_reclaim_stale_policy()` also retains it and walks no ledger.
3. **"A standing request implies `auto_rotation = 1`."** False. `set_auto_rotation(false)` writes
   only the flag; a request retained by an earlier completed close survives it.
4. **"`OPEN` implies participants > 0."** False. `open_cycle()` zeroes participants and
   `_maybe_close_cycle()` is reached only from a resolution or withdrawal, so a freshly opened,
   unenrolled cycle stays OPEN at zero.
5. **"A closed cycle's counters are reconstructible from the ledger."** False. Once closed, a plot
   may re-enrol under another field and overwrite all three ledger columns.
## Relations that do hold in source
- `completed + cancelled <= ordinal`, as a **bound only**: ABANDONED closes increment neither, and
  a recreate zeroes both counters while retaining the ordinal. It reconstructs nothing.
- A ledger stamp is `<=` the named field's ordinal within one snapshot (monotonic, reset only by
  `clear()`, which resets the ledger in the same call).
- While a request stands, `requested_crop == rotation_ids[field*3 + cursor]`, and
  `ENTRY_NOT_CONFIGURED` holds exactly when that entry is `NO_CROP`; `NONE` implies `NO_CROP`.
  Edits re-request at the unchanged cursor, so these cannot drift.
- For a **present, OPEN** field, stamps matching `(field, ordinal)` reconstruct all three live
  counters exactly: participants = matching non-withdrawn, resolved = matching harvested/cleared,
  withdrawn = matching withdrawn.
- ABANDONED implies participants and resolved zero with withdrawn >= 1; CANCELLED retains the
  unresolved counts, so resolved may be below participants.
## Window state is retained, not recomputable
`_classify_window()` runs only at close or edit and stores its answer; nothing refreshes it per
tick. A validator must treat READY / FUTURE / MISSED as opaque retained history and must not
re-derive it against the loaded tick. `NO_LEGAL_WINDOW` is unreachable through the current crop
catalogue but is a declared defensive ordinal; removing it needs authority, so accept 0–5.
## Deferred identity, and a gap that stays separate
Saved bindings defer Farming, Forage and Directory identity: the row index is the FARM zone's
typed row, and a ledger stamp can outlive the FarmPlot row it names because this module never
observes plot destruction. Validation must read same-file projections and never construct live
stores. The seed-reserve `GATE_UNAVAILABLE` remains a separate future game-integration gap, not a
defect for this owner to close.
## Shape and cost
Twenty positional arguments follows the ADR 0132 large-owner precedent; twenty typed cold
properties is more reviewable at the arithmetic cost of a second 44288-byte value set (88576 with
the caller's). A nested 128×4096 rescan needs no extra scratch; a single 4096-row pass
accumulating into three 128-entry scratch columns is better bounded and should be chosen only if
that scratch is explicitly budgeted.
## Decisions still missing
1. Evidence route for inactive-row retention: source plus synthetic fixtures only, or a new
   reader (out of scope here).
2. Cold columns type versus twenty positional arguments.
3. Whether one-scan scratch is budgeted.
4. Whether OPEN-cycle counters are enforced by equality or only bounded.
5. Confirmation that window state and `NO_LEGAL_WINDOW` are accepted as opaque.
