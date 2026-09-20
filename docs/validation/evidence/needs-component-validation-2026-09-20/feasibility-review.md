# Needs section-4 semantic validation: feasibility review

Read-only. Planning only, no production edit is made or authorized here, nothing was run.
Scope: `needs` (section 4 owner index 9, owner version 2) only. Answers
`astra-source-questions.md` against `godot/scripts/core/needs.gd`,
`godot/scripts/core/save_component_columns_schema.gd`, `godot/test/test_needs_columns.gd`,
decision 0132, `docs/planning/component_columns_stream_contract.md`, and the supplied
`authority-excerpts.md` (GDD 302-330, persistence registry 487-509).

## 1. Purity of the restore validator

`_restore_column_refusal(columns)` reaches exactly eight helpers, in this order:
`_columns_are_capacity_sized` -> `_column_byte_domain_refusal` (-> `_byte_column_below`) ->
`_column_value_domain_refusal` (-> `_int32_column_within`, `_int64_column_within`) ->
`_column_free_row_refusal` (-> `_free_row_is_clear`) -> `_living_row_count`.

Every one of the nine functions reads only its arguments plus class constants
(`RESIDENT_CAPACITY`, `NEED_COUNT`, the `*_COUNT` bounds, `STATUS_DEAD`,
`NEED_DENOMINATOR`/`HEALTH_DENOMINATOR`/`COLD_DENOMINATOR`, `IntMath.INT32_MAX`,
`IntMath.INT64_MAX`). None touches `self`: not `_math`, not `_last_column_refusal`, not a
column, not a counter. So a public `static func columns_refusal(columns: Columns) -> StringName`
is feasible, and all eight helpers convert to `static` unchanged. `IntMath` is a script-level
`const preload`, which static functions may read; `Columns` is an inner class and may be a
static parameter type. `Columns._init()` already reads outer-class constants in shipped code,
so the inner-class constant scoping question is answered by the existing module, not assumed.

`restore_columns()` must then call the same static predicate and keep its own job (assign
`_last_column_refusal`, `_install_columns`, `_rebuild_counters`). Parity is then structural,
not asserted — but pin it with a test anyway (§4).

**Two real defects in the current code, both exposed by extraction.**

- **Null is a crash, not a refusal.** `_restore_column_refusal(null)` falls into
  `_columns_are_capacity_sized(null)`, whose first statement is `columns.need_value.size()`:
  a nil dereference. A public static entry point is reachable by offline callers, so it needs
  `if columns == null: return REFUSE_COLUMN_SHAPE` as statement one. This is **not**
  behaviour-preserving; it is a deliberate new refusal on an input the current API cannot
  legally be handed, and it must be recorded as such rather than described as extraction.
- **Shape must stay first.** `_int32_column_within` reads `sorted[0]` unguarded. Every
  declared extent is positive, so the existing order is safe; a future caller that invokes a
  domain helper directly would not be. Keep the helpers private except `columns_refusal`.

No other precedence change is needed: codes, order and values transfer verbatim.

## 2. The bridge for owner 9

Checked field-by-field against the generated table. `OWNER_KEYS[9] == "needs"`,
`OWNER_VERSIONS[9] == 2`, `OWNER_PRIMARY_COUNTS[9] == 512`, `OWNER_CHILD_COUNTS[9] == 0`,
`OWNER_FIELD_COUNTS[9] == 20`, `OWNER_FIELD_BEGIN[9] == 187`. `FIELD_KEYS[187..206]`,
`FIELD_TYPES` and `FIELD_COUNTS` over that span match `needs.gd`'s `COLUMN_KEYS`,
`COLUMN_TYPE_CODES` and `COLUMN_EXTENTS` ordinal for ordinal, including the 2560-element
`_need_value`/`_need_remainder` stride-5 pair. `OWNER_PAYLOAD_BYTES[9] == 57508`; minus the
4-byte child header and 20 x 8-byte field counts that is **57344 value bytes**.

Shape: `static func columns_from_framed(record) -> Columns` plus
`static func framed_refusal(record) -> StringName`. No live `Needs`, no install, no capture,
no barrier, no I/O, no signal. Read columns through the contract's owner-local ordinal
accessors (`u8_column(field)`, `i32_column(field)`, `i64_column(field)`), never through a
bucket index — a wrong-type ordinal returns an empty array, which the existing extent check
turns into `COLUMN_SHAPE`. Call `owner_shape_refusal(record)` and check `record.owner == 9`
first; a valid frame for another owner must refuse, not be validated by Needs rules.

**Explicit 20-line field assignment, no reflection.** Constructor defaults are actively
dangerous here: `Columns.clear()` writes `status = DEAD`, `clothing_tier = 1`,
`size_class = SIZE_SMALL`, `activity = AWAKE`, and the enum defaults. An omitted mapping
therefore produces a column that *passes* validation (a dropped `clothing_tier` reads as all
tier 1, never the zero the tier rule catches). Assert `COLUMN_COUNT == 20` and
`schema.field_count(9) == 20` in the bridge, and cover each of the twenty with a
per-field test (§4). Do not reuse `clear()` or `equals()` as a substitute for mapping.

**Memory.** A temporary `Columns.new()` allocates its own 57344 bytes; each COW field
assignment from the FramedOwner replaces one buffer with a shared reference and drops the
fresh one, so both sets are alive simultaneously only during the transition. Peak owned by
the bridge is therefore bounded by **2 x 57344 = 114688 bytes**, as proposed — conditional on
the caller keeping the FramedOwner alive across validation, which it must, since the Columns
fields alias it. The proposal's separately accounted largest sort copy is understated:
`_int64_column_within` duplicates and sorts, largest `_need_remainder` at 2560 x 8 =
**20480 bytes**; `_int32_column_within` duplicates `_need_value` at 2560 x 4 = **10240 bytes**.
They are sequential within a call but both overlap the 114688, so charge
**114688 + 20480 = 135168 bytes** conservatively, and 145408 if a reviewer refuses to rely on
call-scoped release ordering. Arithmetic only; no RSS measurement is claimed, and native
header overhead is unaccounted. (A min/max scan would remove both copies with identical
accept/refuse behaviour; that is a follow-up, not this slice.)

No generic validator. The bridge is `needs`-only and refuses the other seventeen owners.

## 3. `departure_days`

Three sources, and they do not conflict once read carefully.

- Decision 0132 clause 10 freezes reserved zeros for **five JobAgent columns only**
  (`_agent_path_id`, `_agent_path_cursor`, `_agent_lease_expiry`, `_agent_blocked_tick`,
  `_agent_manual_until`). `_departure_days` is not among them.
- The persistence registry (line 502) names it "Departure countdown — Days remaining before a
  resident leaves", null/unused `0`. That is a countdown with a real domain, not a reserved zero.
- GDD REQ-SET-021..024 define the mechanic (two consecutive midnights below mood 2000, warning,
  third midnight marks departure, cleared at 3500, blocked while incapacitated).
- The accepted restore rule today admits `0..INT32_MAX` via `REFUSE_COLUMN_NEGATIVE_COUNTER`.

What is wrong is only `needs.gd`'s prose: the header GAPS block ("The column exists, is
explicitly zero, and is never written") and `departure_days_of()`'s "Reserved and always 0"
overstate a lifecycle fact (no writer exists yet) into a saved-domain claim the restore rule
contradicts. **Behaviour-preserving extraction plus a comment correction is justified and
sufficient; no stronger ruling is required to land this slice.** Correct both sites to say the
column has no writer yet and restore accepts a non-negative countdown. Do **not** narrow the
saved domain (e.g. to 0..3 from the three-midnight rule) here — that is a tightening of an
accepted domain and needs its own decision. Do not implement departure, midnights, warnings,
map exit or `STATUS_LEAVING`.

## 4. Domains, first refusal, and missing tests

Precedence: **shape -> byte domains -> value domains -> free rows -> living cap.** First
refusal for a set with several faults is always `COLUMN_SHAPE`. Within byte domains the order
is present, flags, clothing tier, then the six enums; within value domains it is need, health,
departure, starving, cold-milli, then the three remainders.

| # | column | type | count | accepted domain | refusal |
|---|---|---|---|---|---|
| 0 | `_present` | u8 | 512 | 0..1 | `COLUMN_PRESENT_BYTE` |
| 1 | `_need_value` | i32 | 2560 | 0..10000 | `COLUMN_NEED_RANGE` |
| 2 | `_need_remainder` | i64 | 2560 | -749999..749999 | `COLUMN_REMAINDER` |
| 3 | `_health` | i32 | 512 | 0..100 | `COLUMN_HEALTH_RANGE` |
| 4 | `_health_remainder` | i64 | 512 | -749..749 | `COLUMN_REMAINDER` |
| 5 | `_cold_milli_hours` | i64 | 512 | 0..INT64_MAX | `COLUMN_NEGATIVE_COUNTER` |
| 6 | `_cold_remainder` | i64 | 512 | -749..749 | `COLUMN_REMAINDER` |
| 7 | `_starving_ticks` | i64 | 512 | 0..INT64_MAX | `COLUMN_NEGATIVE_COUNTER` |
| 8 | `_departure_days` | i32 | 512 | 0..INT32_MAX (see §3) | `COLUMN_NEGATIVE_COUNTER` |
| 9 | `_status` | u8 | 512 | 0..6 (`STATUS_COUNT` 7) | `COLUMN_ENUM_BYTE` |
| 10 | `_size_class` | u8 | 512 | 0..2 | `COLUMN_ENUM_BYTE` |
| 11 | `_activity` | u8 | 512 | 0..2 | `COLUMN_ENUM_BYTE` |
| 12 | `_comfort_environment` | u8 | 512 | 0..2 | `COLUMN_ENUM_BYTE` |
| 13 | `_social_paired` | u8 | 512 | 0..1 | `COLUMN_FLAG_BYTE` |
| 14 | `_purpose_source` | u8 | 512 | 0..2 | `COLUMN_ENUM_BYTE` |
| 15 | `_cold_environment` | u8 | 512 | 0..2 | `COLUMN_ENUM_BYTE` |
| 16 | `_clothing_tier` | u8 | 512 | 1..2, 0 refused | `COLUMN_CLOTHING_TIER` |
| 17 | `_infirmary` | u8 | 512 | 0..1 | `COLUMN_FLAG_BYTE` |
| 18 | `_injury_state` | u8 | 512 | 0..2 | `COLUMN_ENUM_BYTE` |
| 19 | `_airless` | u8 | 512 | 0..1 | `COLUMN_FLAG_BYTE` |

Cross-cutting: free rows (`_present == 0`) must carry `STATUS_DEAD` and zeroed health,
health remainder, cold milli-hours, cold remainder, starving ticks and both need columns
(`COLUMN_FREE_ROW`); `size_class` and the ten environment inputs are deliberately **not**
constrained on a free row, because `despawn()` leaves the last tenant's values — valid
retained inactive residue. Recomputed living rows (present and not dead) <= 256
(`COLUMN_LIVING_CAP`); capacity is 512 rows, so 512 present with >256 living must refuse.

`test_needs_columns.gd` already covers shape, the status enum, need high bound, the int32
health minimum, both need/health remainder edges, negative starving ticks, present byte 2,
`social_paired` 2, tier 0, two free-row cases, cap 256/257, namespace separation and a
post-restore 800-tick equivalence. **Missing:**

1. null `Columns`, and (via the bridge) null record, wrong owner index, wrong-type ordinal,
   short/long column.
2. Signed extrema not yet pinned: `need_value` at INT32_MIN and at -1; `departure_days` at -1
   and at INT32_MAX (accept); `cold_milli_hours` at -1; `cold_remainder` at both +/-750.
3. Enum bytes never individually exercised: `size_class`, `activity`, `comfort_environment`,
   `purpose_source`, `cold_environment`, `injury_state`.
4. Flag bytes `infirmary` and `airless` at 2; `clothing_tier` at 3.
5. Unpopulated-constructor test: for each of the twenty fields, omit exactly that mapping in
   the bridge and require the outcome to change (kills the default-substitution mutant).
6. Valid retained inactive residue beyond `size_class`/`clothing_tier`: a free row with a
   non-default `activity`/`cold_environment`/`injury_state` must be **accepted**.
7. Public-static-versus-owner parity: for a fixture matrix, `Needs.columns_refusal(c)` equals
   the code a live `restore_columns(c)` leaves in `last_column_refusal()`.
8. Non-mutation: the FramedOwner's columns and the input `Columns` are byte-identical after a
   refused and an accepted validation, and no live store is constructed (no world touched).
9. First-refusal precedence: a set faulty in shape, enum, value, free row and cap at once
   returns `COLUMN_SHAPE`; remove the shape fault and it returns the enum code; and so on.

## 5. Bounded ownership and acceptance

Proposed allowlist, nothing else:

- `godot/scripts/core/needs.gd` — add public `columns_refusal()`, make the eight helpers
  static, add the null guard, correct the two `departure_days` comments. No new column, no
  new refusal code, so no persistence-registry ledger row is owed (decision 0132 precedent).
- `godot/scripts/core/save_owner_needs.gd` (new) — the owner-9 bridge only.
- `godot/test/test_save_owner_needs.gd` (new); `godot/test/test_needs_columns.gd` (extend).
- `docs/decisions/` — one new numbered record (number allocated by `decision_numbers.py`).
- This evidence directory.

Acceptance: full suite, static gates, editor import and independent source review, plus the
per-field omission mutants in §4.5 and a precedence mutant per §4.9.

**This slice closes one of eighteen owners.** SAVE-S4-SEMANTICS stays incomplete;
SAVE-S4-CODEC stays incomplete (17 remaining validators, the missing bulk APIs, capture/apply
and the coupled-section compositions Needs is not part of). Nothing here certifies a
full-world restore, a release save, or any milestone flag. Do **not** infer from §1 that
`residents.gd` or `jobs.gd` validators are context-free: decision 0132 clause 4 states both
resolve through the entity directory and jobs additionally through section 3 and the resident
store, so both are order-dependent and neither is extractable by this pattern.
