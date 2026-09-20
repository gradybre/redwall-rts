# Feasibility audit — planner bulk capture/restore contract (read-only)

Date: 2026-09-19 · Status: **audit only**. No source file was edited, nothing was run,
nothing was tested, and no gate is claimed closed. Every statement below is read from
`godot/scripts/core/job_planner.gd`, `godot/scripts/core/save_section_job_indexes.gd`,
decision 0132, decision 0157 and the task 03 planner rulings as supplied.

## 1. Ground facts taken from the current sources

- Section 8 is schema 2 with **35 declared fields**, `CANONICAL_VALUE_BYTES = 383884`,
  `PAYLOAD_BYTES = 384164`, `SECTION_BYTES = 384203`, one owner key `job_planner`,
  `PRIMARY_COUNT = SERVICE_ROWS = 8192`.
- Five extents: `SERVICE_ROWS 8192`, `OWNER_ROWS 4096`, `ZONE_ROWS 128`,
  `DEMAND_ROWS 640`, `HIVE_ROWS 1024`, plus three extent-1 count fields (30, 32, 34).
- Preload direction today is **codec → owner only**: the codec preloads
  `JobPlannerScript`, `EntityDirectoryScript`, `FarmingScript`; `job_planner.gd`
  preloads `int_math`, `entity_directory`, `farming`, `forage`, `jobs`, `sim_clock`,
  `orchard_hive` and **does not** preload the codec. Any helper that both sides use must
  preserve that acyclicity.
- BLOCKER J2 is the whole hole: `capture_into()` and `apply()` refuse with
  `SAVE_JOB_STORE_NO_COLUMN_API` because the owner publishes no bulk reader/writer.
  `capture_record_into()` already works for a caller that holds 35 columns.

## 2. Source-owned cross-reference validity, per table

These are the rules the owner's own writers enforce; a restore contract must state them,
not invent them.

**Pending-service table (8192 rows, `_row_of(owner, operation)`).**
`_write_pending_row()` and `_retain_unmet_demand()` store both halves of
`_farming.ref_of(owner_slot)`; `_write_requested_row()` does the same for a confirmed
cycle. So every non-FREE row must name a `KIND_FARM_PLOT` reference, and only
`STATUS_PENDING` may name a `KIND_JOB` reference — the codec's
`_job_reference_refusal()` already asserts that biconditional. Operation discrimination
is structural: `_tend_row_refusal()` and `_sow_day_refusal()` encode that a TEND row
carries no cycle/crop/gate reason and a SOW row carries no day. `_sow_cycle_refusal()`
ties an outstanding request to `_cycle_cursor[owner]`.

**Forage demand (128 zones, 640 rows).** `_write_enabled_demand()` stores the
`HarvestZone` reference; `_clear_enabled_demand()` deliberately **keeps** it while any
of the five rows is non-FREE, so "disabled zone still holding an owner reference" is
legal state, and the codec already declines to assert the converse. `STATUS_REQUESTED`
is illegal here (`_no_requested_status_refusal()`).

**Hive service (1024 rows).** `_write_pending_hive_row()` / `_retain_unmet_hive_demand()`
store `_hives.hive_ref_of()`. There is **no** `_hive_serviced_day` column: completion
history lives in `orchard_hive.gd`'s `Hive.serviced_day`, so section 8 cannot validate
"once per day" alone and must not try.

**Cross-store claim coupling.** A demand row's `_demand_quantified_milli` is the mirror
of a `forage.gd` claim indexed by the owning Job's typed row (task 03 §4.7,
`claim_row = owning_job_typed_row`). Section 8 cannot verify that the claim exists;
section 8 can only assert that a `PENDING` demand row names a Job. The claim-side check
belongs to the forage owner's own restore.

## 3. Legitimate transitional stale references at committed boundaries

The owner contains **named settlement paths that exist precisely because a saved row may
name a destroyed owner or Job**:

- `_settle_existing()` → `_retire_unserved()` (owner ref or day mismatch)
- `_settle_pending_job()` (Job ref no longer `is_valid_of_kind`)
- `_settle_existing_sowing()` → `_abandon_sowing()`
- `_settle_pending_sowing()`
- `_release_abandoned_demand()` and `_settle_pending_harvest()`
- `_settle_existing_hive()` → `_retire_hive_unserved()`, `_settle_pending_hive_job()`
- `revalidate_after_load()` and `_revalidate_hive_rows()`

A tick boundary therefore can commit with, e.g., a `STATUS_PENDING` service row whose
plot was destroyed between `mark_plot_dirty()` and the next `_reconcile_owner()`, or
whose Job was destroyed by `retire_service()` on another path. **A strict restore that
refuses every unresolvable reference would refuse states the running simulation
legitimately produces.** Equally, silently running `revalidate_after_load()` as the
restore path is not a strict restore — it is a repair that changes state and moves
`_dropped_on_load_count`, and this audit does not propose it as one. This is decision
gap **D2** below.

## 4. Counters: category 2 versus diagnostics

**Derivable from the 35 persisted columns (category 2, rebuild, do not persist):**
`_pending_count`, `_unmet_count`, `_requested_count` (from `_status`);
`_demand_enabled_count` (from `_demand_enabled`); `_demand_pending_count`,
`_demand_unmet_count` (from `_demand_status`); `_hive_pending_count`,
`_hive_unmet_count` (from `_hive_status`); `_dirty_count`, `_dirty_zone_count`,
`_dirty_hive_count` (fields 30/32/34 carry them, and the three membership byte arrays
`_is_dirty`, `_is_zone_dirty`, `_is_hive_dirty` are rebuilt from the persisted prefixes
per SAVE-J2-R01 — the prefix order itself is authoritative and must be installed
verbatim with a zero tail, never re-pushed through `mark_*_dirty()`).

**Not derivable from any column (session diagnostics):** `_created_count`,
`_completed_count`, `_cancelled_count`, `_settled_unserved_count`, `_blocker_count`,
`_dropped_on_load_count`, `_last_blocker`, `_sowing_request_count`,
`_sowing_created_count`, `_sowing_started_count`, `_sowing_completed_count`,
`_sowing_cancelled_count`, `_seed_committed_milli`, `_forage_created_count`,
`_forage_completed_count`, `_forage_cancelled_count`, `_forage_claimed_milli`,
`_hive_created_count`, `_hive_completed_count`, `_hive_cancelled_count`,
`_hive_settled_unserved_count`.

All twenty-one are **publicly observable** (`created_count()`, `seed_committed_milli()`,
`forage_claimed_milli()`, …) and two of them — `_seed_committed_milli` and
`_forage_claimed_milli` — are the counters the no-consume tests watch. They are reset by
`clear()`, so `restore_job_index_columns()` would zero them unless told otherwise. None
of them feeds a future selection decision. Whether a restored world must reproduce them
is decision gap **D3**.

## 5. Restore dependencies

Order is a real dependency, not a convention, and follows decision 0132's precedent:

1. `entity_directory.gd` (§3) — every reference in section 8 resolves through it.
2. `farming.gd`, `forage.gd`, `orchard_hive.gd`, `jobs.gd` — the planner's validators
   call `_farming.ref_of()`, `_forage.zone_ref_of()`, `_hives.hive_ref_of()`,
   `_jobs.state_of()`, and `_assert_shared_contracts()` requires one shared directory.
3. `job_planner.gd` last.

A restore run before step 1 or 2 must refuse, not proceed.

## 6. Proposed bounded interface

**Helper (new, dependency-neutral):** a pure schema/Record/validation module, e.g.
`godot/scripts/core/job_index_schema.gd`. It publishes `COLUMN_KEYS`,
`COLUMN_TYPE_CODES`, `COLUMN_EXTENTS`, `COLUMN_COUNT`, `FIELD_UNUSED`, the inner
`Record`/`Columns` class with `clear()`, `copy_from()`, `equals()`, `value_of()`,
`set_value()`, `column_bytes()`, `assign_column()`, and the pure validators
(`record_refusal()` and its private table refusals). It must preload **no** owner and
**no** codec. This is exactly the constraint that creates decision gap **D1**: the
extents and domain counts are currently read from `JobPlannerScript` (and `CROP_COUNT`
from `FarmingScript`, `DIRECTORY_CAPACITY` from `EntityDirectoryScript`).

**Owner additions (0105/0132 shape):** `copy_job_index_columns_into(Columns)`,
`restore_job_index_columns(Columns)`, `last_column_refusal()`, `state_bytes()`, with a
separate `COLUMN_`-prefixed refusal namespace so a load never writes into an operational
`OpResult` channel, and a refused restore leaving the store byte-identical (decision
0059). The owner rebuilds every category-2 member listed in §4, including the three
membership byte arrays, and installs the dirty prefixes verbatim.

**Codec:** **wraps** the helper by composition. Every existing public symbol stays —
`SECTION_ID`, `OWNER_KEY`, `OWNER_SCHEMA_VERSION`, `SECTION_SCHEMA_VERSION`,
`PRIMARY_COUNT`, `FIELD_*`, `Record`, `EncodeResult`, `encode_payload()`,
`encode_section()`, `canonical_bytes_of()`, `decode_section_into()`,
`decode_section_with_schema_into()`, `extent_refusal()`, `record_refusal()`,
`capture_record_into()`, `capture_into()`, `apply()`, `primary_count_refusal()`,
`production_write_refusal()`, `section_length_refusal()`, `descriptor_row_count()`,
`field_width()`, `storage_index_of()`, `canonical_value_bytes()`, `payload_bytes()`,
`field_count_offset()`, `field_value_offset()`, `canonical_type_of()`,
`byte_order_refusal()`. Composition is preferred over `extends` because **no claim of
verified GDScript inheritance is made here** (§8).

## 7. Concrete gaps requiring an Astra decision

- **D1 — helper extent sourcing.** The helper cannot preload `job_planner.gd` without
  making the owner's own preload cyclic. Choose: (a) the helper declares the five
  extents and the domain counts as literals and `job_planner._assert_shared_contracts()`
  asserts equality; (b) the helper preloads only the leaf stores it already needs
  (`entity_directory.gd`, `farming.gd`) and takes extents as `Columns` constructor
  arguments; (c) the owner re-exports its constants and the helper stays literal.
  Option (a) or (c) keeps owner-preload dependencies out of the helper as required.
- **D2 — stale-reference legality.** Must `restore_job_index_columns()` refuse a row
  whose owner or Job reference does not resolve at install time, given that
  `_settle_existing()`, `_settle_existing_sowing()`, `_release_abandoned_demand()` and
  `_settle_existing_hive()` exist to handle exactly that at runtime? Silent
  `revalidate_after_load()` repair is **not** offered as the answer.
- **D3 — diagnostic counters.** Persist the twenty-one non-derivable counters (new
  fields, new schema version, new byte total), restore them to zero, or restore them via
  a separate owner API outside section 8?
- **D4 — `Record` identity.** If `Record` moves to the helper, does
  `SaveSectionJobIndexes.Record` remain a resolvable and type-compatible name for every
  existing caller, and does a `const Record := Helper.Record` alias satisfy GDScript
  static typing? Unprobed.
- **D5 — cross-store claim reconciliation.** Which owner verifies that a `PENDING`
  demand row's `_demand_quantified_milli` matches the forage claim at
  `claim_row = owning_job_typed_row`?

## 8. Probes required before any inheritance claim

No GDScript semantics below are asserted as verified. Before choosing `extends` over
composition, probe on the project's Godot build: (1) whether `const` members of a parent
script are visible unqualified in a child; (2) whether `static func` is inherited and
callable on the child; (3) whether a parent's inner class is addressable as
`Child.Inner`; (4) whether `const Alias := Other.Inner` type-checks in a `var x: Alias`
declaration; (5) whether `preload` cycles are a parse error or a silent null. Until
those five probes are recorded, the audit's recommendation stands at **composition**.

## 9. Scope statement

This is a feasibility audit. It does not implement the helper, the owner API or the
codec adapter; it does not close BLOCKER J2; it does not claim any suite passed; and it
does not modify `job_planner.gd` or `save_section_job_indexes.gd`.
