# 0133 — Section 11 gets the store the registry already declared
Date: 2026-09-12 · Status: Accepted

## Decision

`godot/scripts/core/event_schedule.gd` implements the §11 EVENT_SCHEDULE **store** — the
bounded timed-event schedule that `docs/planning/canonical_state_registry.json` declares as
`section_id 11`, `owner_key "event_schedule"`, `owner_schema_version 1` with eight fields at
fixed ordinals, and that `docs/persistence_state_registry.md:82` recorded as having "no owning
module at all yet".

Its shape is transcribed, not chosen. Six packed columns at `CAPACITY = 64` in the declared
ordinal order — `_kind`, `_source_id`, `_arg0`, `_arg1` (i32) and `_due_tick`, `_sequence`
(i64) — plus the two declared scalars `_next_sequence` (i64, ordinal 0) and `_count` (u32,
ordinal 1). Rows are dense from row 0 and sorted `(due_tick, sequence)`, which is REG-R01's
declared `shape.order` and SAVE-R09-005's record order. `_assert_contracts()` proves the eight
keys, their ordinals, their type codes and the 32-byte stride at construction, so a future edit
that renumbers or retypes a field fails at `_init()` rather than at a save.

**This is the store only.** No §11 codec, no producer, no consumer.

## Why

**`event_schedule` is not `scheduler_events`, and the names are one character apart.**
`scheduler_events.gd` is R07-SCHED-001's speed/pause queue: a 256-slot ring with a movable
`_head`, keyed by `(boundary_tick, unsigned sequence)`, owning a clock and applying events to
it, and persisted in **§12 PENDING_COMMANDS** as the `SCHQ0001` extension after the economic
records. `docs/planning/ready07_scheduler_contract.md:116-124` puts it there; REG-R01 keeps it
there; SAVE-R09-005 says in terms that "Scheduler pause/speed commands stay in section 12,
never here." §11 is a different thing: at most 64 timed game events, dense, no ring, no head,
no clock, no speed and no pause. The confusion is cheap to make and expensive to find, so the
module header states the distinction before it states anything else.

**The declaration arrived before the module on purpose.** REG-R01's "Registry growth / absent
owners" paragraph requires unimplemented stores to be registered on arrival, "except the
explicit EventSchedule and Chronicle declarations already provided by SAVE-R09-005". That
forward declaration is therefore the contract, and building a differently shaped store — even
a better one — would have invalidated a published artifact that §15's digest is specified
against. Nothing here was designed; it was read.

**Three invariants came straight from SAVE-R09-005 and are what the tests mostly assert.**
Initial `next_sequence` 1, issued 1..I64_MAX, never reused, and **zero means exhausted** rather
than empty or null. "Capacity failure must not consume a sequence", so `_advance_sequence()` is
the last statement of `schedule_into()` and never the first: every refusal — full, exhausted,
non-int32 argument, non-future due tick — leaves the store byte-identical, which the suite
asserts by comparing `state_bytes()` images rather than by trusting a `false` return
(ADR 0059's allocate-before-consume). And "no silently expired rows": a due row is not dropped
by the store, it stays until a consumer pops it, so `due_count()` and `has_due()` are queries
that remove nothing.

**Rows beyond `_count` are held byte zero.** Decision 0103 declined to serialize the directory's
free-heap permutation, and §12's ring serializes no unused row, for one shared reason: two
observationally identical worlds must not produce different bytes. `_remove_row()` zeroes the
vacated last row, and the suite proves it by building the same live state two ways — cancel a
row, or restore it directly — and requiring identical images.

**The int32/int64 sign trap is real here.** A GDScript int is 64-bit, so `0x80000000` is
positive and a `PackedInt32Array` would silently store it as `-2147483648`. All four i32 fields
are `IntMath.fits_int32()`-checked before any column is written, and an out-of-range argument
refuses rather than arriving sign-flipped.

**The calendar is offset and this is exactly the store where that bites.** A midnight is
`(tick + 4500) mod 18000 == 0`, the first is tick 13500, and `tick % 18000 == 0` is 06:00.
`next_day_boundary_after_into()` is the one place this module computes a boundary; it gates its
own answer through `SimClock.is_day_boundary()` before returning it, the inverse-checking
pattern `ecology.gd:416` established, so a wrong inverse refuses instead of travelling.
`due_day_index_into()` delegates to `SimClock.day_index_at()` and never divides a raw tick.

**What was refused rather than invented.** SAVE-R09-005 requires the event owner to "register
concrete kind/argument domains and event production/consumption rules before real events are
activated." No such domain is ruled anywhere in this repository. `_kind`, `_source_id`, `_arg0`
and `_arg1` are therefore validated as int32 **storage** and assigned no meaning; no event enum,
no cadence and no payload reading was invented to fill the hole. The module names the blocker
in place.

## Consequences

* §11 has a store. It **does not have a codec**, and nothing in this work may be read as
  release-save completeness. The frozen payload is `next_sequence:i64` followed by N 32-byte
  records, length `8 + 32*N`; the `OFFSET_*` constants transcribe that layout for whoever writes
  the encoder, and `state_bytes()` is a deliberately different test image, not that payload.
  `restore_rows()` takes decoded typed columns, never bytes, and is the validation gate the
  codec will have to pass through.
* `_next_sequence` is SAVE-R09-005's "ALREADY BUDGETED `WorldRuntime.next_event_sequence` i64
  reassigned to EventSchedule ownership/section 11". It is 8 bytes changing owner, **not** 8
  bytes added: `docs/systems_architecture.md:425` must drop `next_event_sequence` from the
  WorldRuntime I64 row as this owner gains it, and the total must not move.
* The two `EventSchedule` rows already budgeted at `docs/systems_architecture.md:417-418` —
  4 x 4 B x 64 = 1024 B and 2 x 8 B x 64 = 1024 B — are now real allocations rather than a
  forward budget. 2048 bytes of new packed columns, matching the existing ledger exactly.
* `docs/persistence_state_registry.md` owes a `### godot/scripts/core/event_schedule.gd`
  section; `state_registry_coverage.py` fails C1 until it is applied, and that failure is the
  expected consequence of a store landing before its registry row, not a defect to work around.
* `canonical_state_registry.json` needs a narrow amendment, which belongs to the integration
  lead: the eight fields' `implementation: REQUIRED_NOT_PRESENT_IN_SNAPSHOT` is now stale, the
  six row-shaped fields need a `source_contract` key so the source cross-check can bind them,
  and `packed_source_field_count` moves 530 -> 536. `record_count` does **not** move: the eight
  records were already declared.
* Milestone-style asserts in `_init()` mean the module refuses to construct if a future edit
  diverges from the declaration. That is intentional: a §11 field silently renumbered against a
  published registry would corrupt every save written afterwards.

## Source

* `docs/planning/canonical_state_registry.json`, `section_id 11` / `owner_key "event_schedule"`
  — the eight field keys, types, type codes, ordinals, `shape.max_count` 64 and
  `shape.order "due_tick_then_sequence"`.
* [SAVE-R09-005](../rulings/2026-09-11_save_codec_contract.md), "Missing owners and payloads",
  Section 11 paragraph — the 64-record maximum, the 32-byte record field order, dense and
  sorted, the payload form `8 + 32*N`, the reassigned allocator, initial 1 / zero-is-exhausted,
  "Capacity failure must not consume a sequence", "no silently expired rows", scheduler
  pause/speed staying in §12, and the unregistered kind/argument domain.
* [REG-R01](../rulings/2026-09-12_save_registry_answers.md), "Registry growth / absent owners"
  and "Other framing, versions and remaining work" — the forward declaration's standing, the
  ban on regenerating field order at runtime, and "EventSchedule owns §11".
* `docs/planning/ready07_scheduler_contract.md:116-124` and
  `docs/persistence_state_registry.md:569` — `scheduler_events.gd` is §12's `SCHQ0001`, not §11.
* `godot/scripts/core/sim_clock.gd` — `CALENDAR_OFFSET_TICKS` 4500, `TICKS_PER_DAY` 18000,
  `is_day_boundary()` and `day_index_at()`, the single definition of a day crossing.
* Decision 0103 (an arbitrary non-live permutation is rebuilt, not serialized) and decision
  0059 (allocate before consume: "A refusal leaves every collaborating store byte-identical").
