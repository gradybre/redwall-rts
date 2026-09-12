# 0081 — The first two save sections, and the split between saving and hashing

**Date:** 2026-09-11
**Status:** Accepted
**Task:** 09.2, partial. Builds on decision 0065 (ARCH-SAVE-001 primitives, ARCH-SAVE-002 header).
**Owns:** `godot/scripts/core/save_section_rng.gd`, `godot/scripts/core/save_section_world_runtime.gd`

## Context

Decision 0065 landed the version-independent layer — the canonical integer
primitives, the 256-byte header, CRC-32/ISO-HDLC, the body SHA-256 — and no
section body at all. ARCH-SAVE-002 names fifteen sections. Thirteen of them are
either owned by a module under live edit or have no owning module whatsoever.

Two are both fully specified and uncontended:

* **§10 RNG.** ARCH-RNG-002 states the contract in one sentence — "Store state
  plus int64 draw count" — over a fixed nine-key ASCII-ordered stream domain that
  `rng.gd` already implements, exposes (`stored_state_of()`, `draw_count_of()`)
  and validates on the way back in (`restore_stream()`).
* **§1 WORLD, the WorldRuntime block.** The READY_07 addendum's G3 ruling settles
  exactly which clock state it carries and, more importantly, what the digest
  does and does not cover.

This record covers those two and nothing else.

## Decision

### 1. Two section codecs, each a fixed-length payload with no framing

**§10 RNG is a fixed 108-byte payload.** Nine i32 stored states at offset 0, nine
i64 draw counts at offset 36. There is no count field and no framing: ARCH-RNG-002
fixes the domain at nine streams, so **the length is the validation**. Any other
length is refused outright, which also means a truncated section cannot be
mistaken for a short-but-valid one. Adding a redundant count field would have
created a second thing that can disagree with the data.

**§1's WorldRuntime block is a fixed 80 bytes** — completed tick (i64), world seed
(i32), RNG seeded flag (u8), three reserved zero bytes, requested speed (i32),
pause mask (i32), host debt (i64), then G3's six clock counters (i64 each).
ARCH-SAVE-007 states that "task 09.2 still owns its explicit field byte
offsets/schema", which is the authority for choosing this layout.

### 2. §1 is composed from blocks, not written whole

Section 1 WORLD is shared. `docs/persistence_state_registry.md` cites "§1 WORLD"
on rows belonging to `spatial_world.gd`, `world_init.gd`, `weather.gd`,
`crop_weather.gd`, `resource_nodes.gd`, `residents.gd`, `rng.gd` and
`sim_clock.gd`. Those stores are owned by other agents.

So this module encodes and decodes a **named block at a caller-given offset**,
reports `BLOCK_BYTES`, and assumes nothing about its neighbours. Whether §1's
blocks must be contiguous, and in what order, is not settled anywhere — and
ARCH-SAVE-004 requires only non-overlapping sections inside an exact file length,
not a tiling. Taking an explicit offset lets §1 compose either way without
deciding.

### 3. The hashed fields are the leading fields, so the exclusion is structural

The WorldRuntime layout puts the five ARCH-HASH-001 fields first and the eight
excluded host-metadata fields after. "What the digest covers" is then something a
reader can see in the offset table, rather than a rule kept in a comment in a
different file from the code it governs.

### 4. Persistence obligation and digest membership are separate dimensions

This is G3's central point and the reason both modules expose **two** encoders:

| | `encode_*` (save bytes) | `canonical_bytes_of` (ARCH-HASH-001) |
|---|---|---|
| §10 RNG | 108 bytes | the same 108 bytes |
| §1 WorldRuntime | 80 bytes, all thirteen fields | 21 bytes, five fields |

Debt and the six counters are **category 1** — genuinely saved, as host-continuation
and evidence metadata — and are excluded from ARCH-HASH-001 while remaining covered
by the section CRC-32 and the body SHA-256. The defect G3 fixes is a registry in
which category 3 meant both "not hashed" and "not saved".

§10 excludes nothing, and `canonical_bytes_of()` is implemented by *calling* the
payload encoder so that identity is executable rather than asserted in prose. The
two modules present the same interface to whatever eventually assembles §15.

The canonical contribution drops the three reserved padding bytes: it is a digest
over state, not a byte image of the file. Section 15 STATE_DIGEST still owns the
`RWL-STATE-1` domain string, the concatenation order and the final SHA-256, and
none of that is decided here.

### 5. Every validation bound is derived from an existing formula

No bound in either module is a chosen number:

* **Debt ≤ `INT64_MAX / 4`.** `sim_clock.gd::_is_overloaded()` implements
  ARCH-CLOCK-001's division-free comparison `4*debt > 30*speed*1000000`. A debt
  whose quadruple overflows int64 would make the first overload test after a load
  refuse arithmetic on a value the save had declared valid.
* **Completed tick ≤ `INT64_MAX - 4500`.** GDD §5.1's calendar is
  `(tick + 4500) mod 18000`.
* **Pause mask ⊆ 31.** `PLAYER|MENU|CRITICAL|VICTORY|LOAD` composed from
  `sim_clock.gd`'s own constants.
* **Requested speed ∈ {1, 2, 4}.** `sim_clock.gd::SELECTABLE_SPEEDS`. Not 0 —
  pause is the reason mask's job — and not 3, which does not exist.

Every one of these **rejects**; none saturates, clamps or masks. G3 is explicit:
"Validate representable arithmetic bounds before publication; an invalid value
rejects, never saturates."

### 6. A rule is enforced where it lives, not copied into the codec

`apply()` on §10 originally pre-checked the retired HUNTING stream's seed-dependent
canonicality before writing anything. Mutation testing showed this made the
transactional rollback **unreachable**, because the precondition had become a
second copy of a rule `rng.gd::restore_stream()` already enforces — and an
unreachable recovery path is an untested one.

So `apply()` now validates only what `rng.gd` cannot (the record's own shape, and
that a seed exists at all), lets `restore_stream()` enforce its own tombstone
rule, and **rolls the whole store back** on any refusal. The rollback path is now
reached by a real input, and a test proves the three streams written before the
refusal are put back. `tombstone_refusal()` stays public for a caller that wants
to validate a record before it owns a store.

### 7. The extent gate is public, because the layer below it would otherwise hide a bug

`extent_refusal()` is public in both modules. A mutation that loosened the extent
bound by one byte **survived the whole suite**: `save_codec.gd`'s `Reader` is
bounded too, so a slack extent check still ended in the same refusal code one
layer down. Testing only `decode_into()`'s refusal code cannot distinguish the
two. The gate is now callable and boundary-tested on its own, and a second test
asserts the refusal detail names the section's own requirement rather than the
Reader's leftover count. A load orchestrator can also use it to ask whether a
section fits before committing.

## Consequences

### What this does not do, and must not be read as doing

* **§1 WorldRuntime cannot be published into a live clock.** See BLOCKER W1 below.
  This ships the read side and a verifier, not a restore.
* **No orchestration.** No file I/O, no rollback load, no autosave rotation, no
  replay. Those are 09.3 and 09.4.
* **No schema version.** Both modules carry `schema_version` opaquely, exactly as
  `save_header.gd` does, and validate nothing about it. The version policy is
  recorded as unresolved at `docs/tasks/09_persistence_replay_reliability.md:17`
  ("do not silently repurpose v1 bytes") and inventing a number would be the
  silent repurposing that line forbids.
* **Thirteen sections remain unwritten**, including `scheduler_events.gd`'s
  `SCHQ0001` extension, which is §12.

### BLOCKER W1 — `sim_clock.gd` has no restore path, and adding one is not this work's to do

`sim_clock.gd` exposes a reader for every WorldRuntime field and a writer for one
and a half of them:

* `set_speed()` restores `_requested_speed`. Usable.
* `set_pause()` sets one reason bit at a time — but `set_pause(PLAYER, true)`
  **zeroes `_debt`** when `0 < _debt < TICK_COST` and increments
  `_subtick_debt_discards`. Restoring a saved PLAYER pause through it would
  subtract debt during restore and corrupt a counter, which is precisely what G3
  forbids. Not usable as a restore path.
* `_completed_tick`, `_debt` and all six counters have **no writer at all**.

What is needed is one accessor:

```gdscript
func restore_runtime(completed_tick: int, debt: int, requested_speed: int,
        pause_mask: int, counters: PackedInt64Array) -> bool
```

setting all nine fields together with **no side effects** — in particular without
`set_pause()`'s sub-tick discard — and resetting the host-time sampling origin so
time spent loading is not charged as debt. `sim_clock.gd` belongs to another
owner, so this is reported rather than added. Half-publishing through
`set_pause()` would be worse than refusing, so this module refuses: it stops at a
validated `Record`, plus `agrees_with_clock()`, which verifies a live clock
against one field by field and names the first that disagrees.

For whoever adds it: G3 requires the **logical saved pause mask restored before**
any transient LOAD guard is applied, and adding or removing that guard must not
erase PLAYER, MENU, CRITICAL or VICTORY. `pause_mask_without_load()` and
`pause_mask_with_load()` make that a pure bit operation on the saved value, and
both directions are tested.

### Open planner items that did not block, and one reading that had to be taken

Of decision 0065's four open items, three did not arise: **neither section
contains a string**, so the length-prefix width (S1) and the string cap (S2) are
untouched, and neither module computes a rules/map/lookup/engine hash (H2).
**Section contiguity (H4)** did arise and was handled by not depending on it — both
decoders take an explicit offset.

One reading had to be taken and is recorded here rather than buried.
ARCH-SAVE-002 says "serialize its occupancy and explicitly persisted fields **in
schema order by ascending slot**". That sentence is ambiguous between
column-major (each field's whole column, fields in schema order) and row-major
(each slot's fields, slots ascending). **§10 is written column-major** — all nine
states, then all nine draw counts — matching the architecture's own
structure-of-arrays mandate and the name of §4, COMPONENT_COLUMNS. This is a
reading of an ambiguous sentence, not a settled contract, and §3, §4 and §5 must
resolve it the same way or the format will be internally inconsistent.

### Evidence

`./tools/run_tests.sh`: **2626 tests, 95019 assertions, 0 failures**
(baseline before this work: 2546 tests, 94600 assertions, 0 failures).
`state_registry_coverage.py` PASS; `ready07_arithmetic.py` PASS.

Nineteen-mutation sweep, one mutation per invocation, each restored and
`shasum -a 256`-compared against a pristine copy. Seventeen killed on the first
pass. **Two survived and closed real gaps in the tests:**

1. **Extent bound +1** survived because `save_codec.gd`'s bounded `Reader` produced
   the same refusal code one layer down. Closed by making `extent_refusal()` public
   and boundary-testing it directly, plus asserting which gate reported the refusal.
2. **Commit-then-validate in `decode_into()`** survived in the §10 decoder because
   the "leaves the caller's record untouched" test only covered the truncation
   path, which the extent gate catches before anything is read. Closed by two tests
   that refuse a **full-length but invalid** section and assert the caller's markers
   survive. The equivalent mutation in the WorldRuntime decoder was already killed.

The hash exclusion was mutated specifically, as required: adding
`writer.write_i64(record.debt)` to `canonical_bytes_of()` fails
`test_changing_only_debt_does_not_change_the_arch_hash_001_contribution` and
`test_the_contribution_is_shorter_than_the_block_and_is_not_its_prefix_bytes`.
G3's central distinction is pinned by tests, not by a comment.
