# Independent review — SAVE-W1-R02 clock/RNG install join

2026-09-19 · Independent Opus reviewer, not the author. Subject: exact
`godot/scripts/core/save_world_runtime_install.gd` and
`godot/test/test_save_world_runtime_install.gd` as supplied, read against
`save_section_world_runtime.gd`, `save_section_rng.gd`, `rng.gd`, `sim_clock.gd`,
`game_manager.gd`, RESTORE-R01/SAVE-LAYOUT-R01, SAVE-W1-R02 and decision 0153.

**SAVE-W1-R02 is acknowledged as the governing contract.** The prior technical audit's
three rejected findings are not revived: a differing old live seed is a legal
replacement rather than evidence of the wrong world; refusing an unseeded incoming
release save is the ruling's own rule, not an invented one; and no nonexistent
"manager unrecoverable setter" is assumed anywhere — the adapter only *reads*
`is_load_unrecoverable()` (`_barrier_refusal`) and leaves the whole-world recovery
gate to SAVE-ORCHESTRATOR.

I ran nothing. No suite execution, no Godot invocation, no file mutation is claimed;
test execution is the parent's.

## Verdict

**No blocking issue.** Five advisories below, none of which gate this bounded packet.

## Checks performed

### Complete preflight before any write

`install()` calls `_preflight_refusal()` first and returns on refusal before any
mutation. That helper is pure: null guard on all four objects, then
`_barrier_refusal()` (`is_loading()` **and** `is_load_barrier_held()`, then
not-published, then not-unrecoverable), then `SaveSectionWorldRuntime.record_refusal`,
then the explicit `IntMathScript.fits_int32` seed check, then
`header_tick_refusal`, then the `rng_seeded` gate, then `_stream_refusal`
(`SaveSectionRng.record_refusal`, seed-dependent `tombstone_refusal`, and the clock
owner's static `SimClockScript.restore_refusal` over all ten scalars). Ordering is
safe: `record_refusal` validates `counters.size()` first, so the later
`world.counters[...]` indexing in `_stream_refusal` and `_install_clock` cannot
over-index. `_capture_prior()` is next and is read-only.

Both barrier halves are genuinely required. `is_loading()` alone is the coordinator
flag; `is_load_barrier_held()` alone could be an outsider's raw grant. The suite
pins that distinction in `test_a_manager_with_no_open_load_is_refused`, which takes
a real outsider grant and still gets `SAVE_WORLD_NOT_LOADING`.

### RNG first, clock last

`_install_streams()` (seed then `SaveSectionRng.apply`) precedes `_install_clock()`
(`manager.restore_clock_runtime`). The clock write is the manager's single validated
assignment boundary, atomic on refusal, and **no fallible step follows a successful
clock install** — `install()` goes straight to `_ok()`. That satisfies the ruling's
ordering requirement and is why a clock refusal can be recovered by RNG rollback
alone.

### Every failed step result checked, recovery included

- `_capture_prior`: `store.world_seed_value().ok` checked; `capture_into` refusal checked.
- `_install_streams`: `seed_world().ok` checked; `apply()` refusal checked.
- `_install_clock`: bool return checked at the call site.
- `_restore_prior`: `seed_world().ok` checked; **each** of the nine
  `restore_stream()` results checked in the loop with the stream id named.

No result object is discarded anywhere in the module.

### Explicit rollback-failed, barrier retained

`_recover()` returns the *original* cause when recovery succeeds and
`SAVE_WORLD_ROLLBACK_FAILED` — naming both the original refusal and the failing
recovery operation — when it does not. The module contains no
`release()`, `end_load()`, `rollback_load()`, `publish_restored_world()` or
`acquire_load_barrier()` call, so a failed recovery provably leaves the barrier up
for the coordinator. `test_a_failed_rollback_is_reported_explicitly_and_keeps_the_barrier`
forces exactly that state (clock refusal plus a one-shot seed refusal during
recovery) and asserts the code, the named cause, still-loading, still-barred and
still-unpublished. No byte-identical recovery is claimed on that path.

### No false success on any path

`_ok()` is reached only after both owners succeed. `_carry()` substitutes
`SAVE_WORLD_UNNAMED_REFUSAL` when a foreign owner reports failure with an empty
code, closing the one route by which a caller testing `.code` could read a failure
as success. `_recover()` is only ever invoked with an already-failed refusal, so it
cannot launder one.

### Source/target arrays not aliased

The adapter writes only through `store`/`manager` public APIs and reads only from
`world`/`streams`. `PriorStreams.record` is freshly allocated in `_init`, and
`SaveSectionRng.capture_into` stages into a local then `copy_from`s element-wise, so
the prior image shares no buffer with the live columns or with the incoming record.
`test_install_retains_no_alias_of_either_input_record` mutates both decoded records
after a successful install and confirms neither the clock nor the RNG image moves.

### Real codecs, next-draw parity, meaningful fault injection

Every fixture goes through the production codecs: `_world()` runs
`encode_block`→`decode_into`, `_streams()` runs `encode_store`→`decode_into`. The
suite uses a real `GameManager`, a real `RngScript`, a real `SimClock`.
`test_restored_streams_continue_the_sources_sequence` takes eight further draws per
live stream from both target and uninterrupted source and compares values — this is
the assertion that catches a stream resumed at a plausible-but-wrong offset, which
is the silent failure section 10 exists to prevent. The tombstone is separately
checked canonical and undrawn against the *new* seed.

Fault injection is by bounded test subclasses (`FaultRng`, `FaultManager`) that
override the public `seed_world`, `restore_stream` and `restore_clock_runtime` and
otherwise `super`-delegate. They are not mirror implementations, and no fault switch
exists in production code. Three distinct recovery branches are genuinely executed:
mid-stream refusal with seeded prior, clock refusal with seeded prior, and clock
refusal with **unseeded** prior (asserting `clear()` semantics via `is_seeded()`
false and a refused state read).

### Parent's integration changes, inspected

- Preflight is private; `install()` is the only public operation. Confirmed.
- Header trimmed; it no longer over-claims and defers world association, other
  sections, disk rollback and publication to the coordinator. Confirmed.
- Recovery restores and checks each prior stream directly (`_restore_prior`) rather
  than re-entering `SaveSectionRng.apply` with its own inner rollback. Confirmed;
  this removes the nested-rollback ambiguity, and the surviving inner rollback inside
  `apply()` on the *forward* path is still correct because `_restore_prior` then
  re-seeds and overwrites all nine pairs from the pre-call image.
- Test RNG image includes the actual prior seed (`_rng_image` appends
  `world_seed_value()`), so a rollback that restored states under the wrong seed
  would now fail. Reader, draw and seed successes are asserted inside the helpers.
- The false-seeded refusal test snapshots clock and image **before** the call.
  Confirmed.
- Seed-range (`2147483648`, `-2147483649`) and column-shape (`states.resize(1)`)
  cases and the released-manager case are present and assert no mutation.

Tests exceeding soft length targets to cover real boundaries is appropriate here;
no claim is made that all protocol or hardware release paths are covered.

## Advisories (non-blocking)

1. `save_world_runtime_install.gd` preloads `res://scripts/systems/game_manager.gd`
   from `scripts/core/`, inverting the usual core→systems direction. There is no
   preload cycle, and the ruling fixes the signature, so this is a layering note for
   SAVE-ORCHESTRATOR to revisit, not a defect.
2. The new suite has no ARCH-AUTH-002 no-float source grep, unlike
   `test_save_section_rng.gd` and `test_save_section_world_runtime.gd`. The module is
   float-free today; the guard is missing.
3. The ruling asks that input records be verified unchanged. The alias test mutates
   them after the call, so post-install field equality is never asserted. Reading a
   couple of fields before mutating would close it.
4. `_restore_prior`'s docstring line exceeds the file's prevailing width.
5. `docs/persistence_state_registry.md` was not supplied, so the category-3 entry and
   residual W1 prose could not be verified here.

## Scope

This review covers only the bounded join. The full disk/world coordinator remains
open: binding the correct world's clock, directory and RNG object, same-capture
section provenance, the remaining sections, disk-backed rollback and publication are
all unaddressed by this adapter and are not claimed by it. `release_save_ready`
remains **false**.
