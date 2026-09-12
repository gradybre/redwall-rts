# 0089 — The clock's one validated restore boundary, and SAVE-LAYOUT-R01 is still an empty heading

Date: 2026-09-12 · Status: **Accepted**

RESTORE-R01 is implemented in `godot/scripts/core/sim_clock.gd`. SAVE-LAYOUT-R01
is **not**, and this record says why: the ruling that names it contains no ruling.

## Decision

1. **One public assignment operation, and it is not a command.**
   `SimClock.restore_runtime(completed_tick, debt, requested_speed, pause_mask,
   fallback_count, diagnostic_pause_count, acknowledged_catchup_resets,
   acknowledged_ticks_discarded, subtick_debt_discards, day_boundaries_crossed)
   -> bool` is the only way a saved runtime reaches the ten fields from outside.
   It calls no setter, runs no tick, pumps no queue, emits no signal and replays
   nothing. The ruling's signature is reproduced exactly, argument for argument.

2. **`set_pause()` is unusable for restore, which is the whole reason this
   exists.** `set_pause(PLAYER, true)` ZEROES `_debt` when `0 < _debt < TICK_COST`
   and increments `_subtick_debt_discards` — ARCH-CLOCK-002 permits that as a
   *command*, and G3 forbids it during a *restore*. A saved PLAYER pause with
   999999 debt manufactured through that setter would come back as 0 debt and one
   extra discard. `test_restoring_a_player_pause_keeps_subtick_debt_and_counts_no_discard`
   pins the difference.

3. **Every argument is validated before the first assignment**, by a pure static
   helper `restore_refusal(...)` with the identical ten-argument order, returning
   a `RestoreRefusal` (`code`, `detail`, `is_ok()`). A refused call changes
   nothing — not the ten fields, not the callbacks, and **not `_last_error` or
   `_last_diagnostic` either**. The reason travels in the validator's return
   value, so a save owner reports it through its own result instead of reading it
   back off a clock it just failed to write. Decision 0059, allocate before
   consume, applied to a scalar record.

4. **The bounds are read off arithmetic that already exists.**
   `RESTORE_COMPLETED_TICK_MAX = INT64_MAX - CALENDAR_OFFSET_TICKS` is the
   headroom of `Calendar.set_tick()`'s unchecked `tick + 4500`; it is an
   overflow guard, not a new calendar. Debt and the six counters are
   `0..INT64_MAX`, whose upper end IS the GDScript int, so the rule a value can
   violate is the lower one. Requested speed is exactly 1, 2 or 4: **0 is derived
   from the mask by `effective_speed()` and is never stored**, and 3 does not
   exist. `KNOWN_PAUSE_BITS` is `PLAYER|MENU|CRITICAL|VICTORY|LOAD` = 31;
   composites and zero are legal, an unknown bit is refused rather than masked
   away.

5. **Debt is NOT capped at the codec's tighter `INT64_MAX/4`.** The ruling says
   `0..INT64_MAX` here, and `save_section_world_runtime.gd` may keep its stricter
   file-level bound derived from `_is_overloaded()`'s `4*debt`. A restorable
   value is not permission to overflow: the next frame's arithmetic still refuses
   rather than wrapping, which `test_restore_accepts_the_whole_representable_counter_domain`
   checks at `INT64_MAX` exactly.

6. **Restore is not a second debt-discard path.** Blocker U3's conservative
   reading stands unchanged: `acknowledge_without_catchup()` remains the only
   counted path that drops owed ticks. Restore installs the recorded counters
   verbatim, recomputes none of them from the tick, and imposes no cross-counter
   relationship.

7. **SAVE-LAYOUT-R01 is not implemented, because it has not been ruled.** The
   heading in `docs/rulings/2026-09-12_clock_restore_and_layout_followup.md`
   contains exactly one sentence: "The packed-store byte-order ruling is appended
   after independent codec review." No byte order was invented to fill it.

## Why

The agent that built section 1's WorldRuntime block stopped at a validated
`Record` and an `agrees_with_clock()` verifier, recording BLOCKER W1: the clock
had readers for all ten fields and writers for one and a half, and the one it had
corrupts debt. Half-publishing through `set_pause()` would have produced a world
that loads, passes its digest, and silently owes the wrong number of ticks. That
refusal was correct, and this is the API it asked for.

Returning `false` without a reason, rather than setting `_last_error`, looks
unhelpful until you state the refusal contract precisely: the clock must be
**byte-identical** after a refused restore. `_last_error` is part of that state.
The pure validator is therefore not a convenience for the codec — it is the only
place a reason can live without violating the guarantee.

The validation helper is deliberately static and dependency-free. It does not
return `save_header.gd`'s `Refusal`, because the clock sits below the codec and
an import in that direction would make the scheduler depend on the save format.
A codec that wants one vocabulary maps `CLOCK_RESTORE_*` into its own.

## Consequences

- **No new state, so no new ledger row and no new registry row.** This adds
  constants, one inner class and methods; `sim_clock.gd` gains no `var`. The four
  existing registry rows under `godot/scripts/core/sim_clock.gd` already describe
  every field it writes. `state_registry_coverage.py` passes unchanged.
- **§1 WORLD's WorldRuntime block can now round-trip in full**: capture →
  encode → decode → `restore_runtime()` → `agrees_with_clock()`. Section 10 RNG
  already had `apply()`. Both of those modules live on the unmerged
  `feat/save-sections-rng-world` branch; nothing here depends on them, and
  nothing there is edited by this work.
- **The load coordinator is still missing and is not the clock owner's.** Nobody
  holds the load/restore barrier, nobody resets `game_manager.gd`'s host sample
  origin at release, and nobody calls this function in the running game.
  `restore_runtime()` never opens or closes a barrier and cannot check that it
  was called under one; that obligation stays with task 09's integration owner,
  as does §12's pending-queue restoration.
- **A caller must compare the header's completed tick with section 1's before
  invoking this.** The clock sees one tick and cannot perform that comparison;
  `save_section_world_runtime.gd::header_tick_refusal()` already exists for it.
- **SAVE-LAYOUT-R01 blocks nothing that is built and settles nothing.** In
  particular the question section 10 raised — whether a multi-field packed store
  writes all of column A then all of column B (what `save_section_rng.gd` chose:
  nine i32 states at offset 0, then nine i64 draw counts at offset 36) or
  interleaves per row — remains open. SAVE-R09-002's "flatten row-major" governs
  multidimensional *lookup tables* in `lookup_identity.bin`, not packed store
  sections, and must not be stretched into an answer for them.

## Source

- `docs/rulings/2026-09-12_clock_restore_and_layout_followup.md` — RESTORE-R01,
  its required signature, validation list and acceptance list; SAVE-LAYOUT-R01's
  deferral.
- `docs/rulings/2026-09-11_ready07_save_ui_addendum.md` §G3 — persistence
  obligation versus digest membership; "do not scale, zero, clamp or subtract
  debt during restore"; debt `2500001` restores exactly.
- `docs/rulings/2026-09-11_save_codec_contract.md` — SAVE-R09-001–005, the
  surrounding codec contract this API must not contradict.
- `docs/decisions/0059-*` (allocate before consume), `0054`/`0084` (blocker U3
  and the scheduler queue), `0081` (the first two save sections, unmerged).
