# Schedule semantic validator — source-backed feasibility review

Research only. Not a contract, not a decision, and nothing here was executed.
Sources: `godot/scripts/core/schedule.gd`, `godot/test/test_schedule.gd`,
`godot/scripts/core/catalog.gd`, `godot/scripts/core/save_component_columns_schema.gd`,
and the two planning notes in this directory.

## 1. Frame: order, types, extents

The canonical entry in `source-leads.md` fixes ordinals 0..5 as `_present` u8,
`_hourly_activity` u8, `_template` i32, `_current_activity` i32, `_sleep_satisfied` u8,
`_resolved` u8. The generated section-4 metadata agrees independently: owner `schedule`
is index 14, `OWNER_PRIMARY_COUNTS[14] = 512`, `OWNER_CHILD_COUNTS[14] = 0`,
`OWNER_FIELD_COUNTS[14] = 6`, and its six `FIELD_COUNTS` run 512, 12288, 512, 512, 512, 512.
Value bytes: 512 + 12288 + 2048 + 2048 + 512 + 512 = **17920**. `OWNER_PAYLOAD_BYTES[14]`
is 17972 = 17920 + 4 (child_extent_count) + 6*8 (per-field element_count), which
corroborates the widths without assuming them. All 512 physical rows are addressable and
every column covers full capacity; there is no compaction and no child extent.

## 2. Invariants over the public producer set

`_current_activity` is written in exactly four places: `clear()`, `spawn()`, `despawn()`
(all ANYTHING) and `resolve_into()`, which sets `_resolved[slot] = 1` on the same path.
`_sleep_satisfied` is written in exactly three: `clear()`, `despawn()`,
`_write_template_hours()` (all 0) and `_resolve_activity()` (0 or 1). `_write_template_hours`
is reached from both `spawn()` and `assign_template()`. Refusals return before any write —
every mutator validates completely first.

**`_resolved == 0` on a present row implies `_current_activity == ANYTHING` and
`_sleep_satisfied == 0`.** Yes, over every public path. Nothing can set the latch or move
`current` without passing through `resolve_into`, which sets `_resolved = 1`; `spawn` seeds
ANYTHING/0/0.

**`_sleep_satisfied == 1` implies `_resolved == 1`.** Yes, for the same reason: the latch is
only raised inside `_resolve_activity`, called only by `resolve_into`.

**`_sleep_satisfied == 1` implies `_current_activity == ANYTHING`.** True today. The latch
is raised only on the scheduled-SLEEP branch, which then returns ANYTHING because the latch
is now 1; the collapse branch and the non-SLEEP branch both clear it before returning a
possibly non-ANYTHING value. `assign_template` lowers the latch (weakening the antecedent)
and does not touch `current`; `set_hour_activity` touches neither. So no valid public
lifecycle output violates either implication.

## 3. What must not be tightened, and what must not be required

- `assign_template` and `set_hour_activity` deliberately leave `_current_activity` and
  `_resolved` alone (see their docstrings and the header's no-sentinel note). A saved row may
  therefore legitimately hold `current = SOCIAL` under an all-ANYTHING flexible template, or
  customized hours that match no template. **Do not require agreement** between `current`,
  `hourly_activity[h]`, `template`, live Needs, or any hour. There is no clock column in this
  owner, so no hour-consistency check is even expressible.
- `sleep1 -> current == ANYTHING` is a coupling of a §5.3 window latch to a resolved value,
  not a rule GDD §5.3 states. It is the one genuinely **unsafe proposed tightening** here:
  recommend a warning-level witness, not a hard refusal, and keep the two safe implications
  (`resolved0` frame, `sleep1 -> resolved1`) as gates.
- A failure must refuse. It must never normalize a latch, substitute a default, or construct
  a Needs store to judge a row.

## 4. Inactive rows: ANYTHING=1, not zero

`Catalog.ACTIVITY` gives SLEEP=0, ANYTHING=1. `clear()`/`despawn()` fill hourly and current
with ANYTHING and set `_template = 0`, so **an all-zero frame is not a valid empty Schedule** —
its 12288 hourly bytes would read as SLEEP. `_template = 0` is the compiled `default` ID, not
absence; `EMPTY_CATALOG_ID = -1` is not used by this owner. `inactive_row_is_clear()` already
encodes the exact frame and should gain **one shared argument-only definition** that the
existing reader calls, so the validator and the reader cannot drift.

Flag bytes must be strictly 0 or 1: `is_present` tests `== 1` while `_check_present_slot`
tests `== 0`, and `_resolve_activity` tests `_sleep_satisfied[slot] == 1`. A byte of 2 would
be present to one reader and absent to the other, so it must refuse with its own code.
Activities are 0..3 (`ACTIVITY_COUNT`, contiguity asserted in `_assert_activity_is_contiguous`).

## 5. Template domain: local range vs installed catalog

`_check_template` does two things: refuse on `_catalog_error`, then bound `0 <= id < 3`.
`TEMPLATE_COUNT = 3` and `TEMPLATE_KEYS` are file constants, so a static predicate can check
`0..TEMPLATE_COUNT-1` with **no live Schedule and no Needs** — construction would otherwise
build a private Needs (`_init`) and compile the domain, which the offline path must not do.
Key-to-ID identity is a different question and is not local: `ScheduleTemplate` is compiled
via `Catalog.compile_domain` at construction and is absent from `catalog.gd`'s
`COMPILED_ENUM_DOMAINS`, so `verify_compiled_enum` does not cover it. Section 2 identity is
coordinator-owned through `CatalogIds.verify_embedded`, which refuses a mismatch before any
world mutation; migration is separately unwritten and must not be improvised. A
`Schedule -> CatalogIds` preload would cycle (`catalog_ids.gd` preloads `ScheduleScript`),
so the numeric bound must stay local.

## 6. Registry wording mismatch

`docs/persistence_state_registry.md` line 714 says `_resolved` "records that this hour's
activity has been applied". The flag is set on any successful resolve and cleared only by
`spawn`/`despawn`/`clear`; `assign_template` does not clear it and the owner carries no hour.
Suggested correction: "`_resolved` records that at least one resolve has produced a
`current_activity` for this row; it gates the no-sentinel reader and is not derived from the
clock." Do not invent a per-hour reset.

## 7. Bounded API sketch, if justified

One static, argument-only predicate over the six columns plus a slot — same shape as the
Priorities validator — returning distinct codes so a mapping test can witness each:
extent mismatch; present flag not 0/1; latch/resolved flag not 0/1; hourly activity out of
0..3; current activity out of 0..3; template out of 0..2 on a present row; inactive-row
residue; `resolved0` with non-default current or raised latch; latch raised with `resolved0`.
Bounded loops over 24 hours and 512 rows need no packed projection or sort for the i32 checks.
Witnesses worth pinning: the all-zero frame refuses; template 3 refuses; present byte 2
refuses; a customized row whose `current` disagrees with its template **accepts**; a row
resolved then re-templated **accepts**.

Owner capture/apply, `_present_count` rebuild, Needs presence/status agreement and catalog
provenance remain downstream and are not proposed here.
