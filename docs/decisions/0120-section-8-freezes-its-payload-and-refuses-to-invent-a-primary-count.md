# 0120 — Section 8 JOB_INDEXES freezes its payload and refuses to invent a primary count
Date: 2026-09-12 · Status: Accepted

## Decision

`godot/scripts/core/save_section_job_indexes.gd` implements ARCH-SAVE-002
section 8 under [REG-R01 and SAVE-LAYOUT-R01](../rulings/2026-09-12_save_registry_answers.md),
with two deliberate holes that are refusals rather than guesses.

1. **The payload is frozen.** 29 columns in the registry artifact's declared
   ordinal order, column-major, each prefixed by its own `element_count:u64`:
   **363112 payload bytes**, **362880 canonical value bytes**, **363151 section
   bytes** including the 39-byte owner wrapper (`store_count:u32`=1,
   `owner_key`="job_planner" (11 bytes), `owner_schema_version:u32`=1,
   `primary_count:u64`, `payload_byte_length:u64`=363112).
2. **Each of the five child extents is read from the owning schema**, never from
   the first column: `SERVICE_ROW_COUNT`=8192 (ordinals 0–10),
   `OWNER_CAPACITY`=4096 (11–12), `ZONE_OWNER_CAPACITY`=128 (13–15),
   `DEMAND_ROW_COUNT`=640 (16–20), `HIVE_OWNER_CAPACITY`=1024 (21–28).
3. **BLOCKER J1: `primary_count`'s VALUE is unruled, so this module does not
   choose it.** `encode_section()` takes it as a required argument,
   `decode_section_into()` takes the value it must match, and
   `production_write_refusal()` refuses `SAVE_JOB_PRIMARY_COUNT_UNRULED` so that
   a save owner wiring section 8 into a real file gets a refusal instead of a
   plausible number.
4. **BLOCKER J2: `job_planner.gd` publishes no bulk column API**, so
   `capture_into()` and `apply()` refuse `SAVE_JOB_STORE_NO_COLUMN_API` and name
   the pair the planner owner must add. `capture_record_into()` is the
   column-level capture that works today.

`release_save_ready` stays false. This closes no section 15 work, certifies no
release save, and adds no authoritative packed column.

## Why

### The extents are determinable; the primary count is not

REG-R01 is explicit: *"Module owners containing several differently sized logical
tables need an explicitly validated primary count and child extents before their
wire body is frozen; the logical registry does not authorize guessing these from
the first column."*

The child extents **are** determinable. `job_planner.gd` publishes all five as
public constants, `docs/persistence_state_registry.md` states the same five
capacities per field group, and the registry artifact repeats each one in
`shape.declared_capacity`. Three independent sources agree, so the module reads
them from the owning schema and validates every `element_count` prefix against
the field's own extent.

The primary count is a different matter. SAVE-LAYOUT-R01 fixes it for a
single-table owner — section 3's is the directory capacity, section 4's is "its
full physical capacity", section 5's is the owner or arena count — and REG-R01
names 1, 1, 512 and 4 for `world_runtime`, `entity_directory`, `residents` and
`movement`. Section 8's owner has **three independent owner capacities** (4096
farm plots, 128 designations, 1024 hives) and two derived child tables above
them, and the artifact carries **no `primary_count` key** for `job_planner`.

Taking 8192 because it happens to be ordinal 0's extent is precisely the guess
the ruling forbids. Taking 4096, or the 14080 sum, would be an invented constant
in a file nobody would re-derive. So the module carries the number instead of
choosing it, and refuses production writes while it is unruled: two writers
picking differently would produce two incompatible section 8s that **both
decode**, which is worse than a refusal and much harder to find later.

### Why capture and apply refuse instead of reading underscore columns

The planner's public readers are gated for the simulation's own use, correctly:
`service_day_into()` refuses a non-daily operation and refuses a FREE row rather
than answering 0; `service_job_of()` answers `NULL_REF` unless the row is
PENDING; the sowing readers address only an owner's SOW row;
`service_requires_water()` collapses a byte to a bool. A capture built on them
would have to synthesise the values it cannot read — "a sowing row's
`_service_day` is NO_DAY by construction" is true today and is exactly the
assumption a save must not encode.

Reaching into `store._owner_slot` was rejected: no module here reads another's
underscore-prefixed columns, and doing it would put the planner's invariants in
two files. Section 3 hit the same wall (its BLOCKER D1, closed by
[decision 0105](0105-the-directory-publishes-its-columns-and-rebuilds-the-rest-on-restore.md)'s
`copy_columns_into()`/`restore_columns()`) and
`save_section_world_runtime.gd` hit it against `sim_clock.gd`, where Astra ruled
`restore_runtime()` into existence as RESTORE-R01. The same resolution belongs
here, and the signature is the planner owner's to publish.

### What the validator checks, and why each rule has a source

Every cross-column rule is read off a writer in `job_planner.gd`, not invented:

* FREE-row hygiene mirrors `service_row_is_clear()`, `demand_row_is_clear()` and
  `hive_service_row_is_clear()` **field for field**, including the three fields
  those predicates deliberately exclude — `_serviced_day` (the completion
  history `_retire_row()` keeps), `_demand_blocker` and
  `_hive_feed_demand_milli` (retained reason-like state written onto a free row).
  A validator that swept those out would refuse a save the planner produces
  every midnight.
* Operation parity: `_write_requested_row()` writes the cycle, crop and
  REQUESTED status only onto an owner's SOW row, and both writers of
  `_serviced_day` refuse a non-daily operation, so a TEND row carrying a field
  cycle and a SOW row carrying a day are each refused.
* Cycle agreement: `_write_requested_row()` sets the cursor to the cycle it
  writes and `_outstanding_request_code()` refuses a second confirm while the row
  is not FREE, so an open request must name the cursor's current cycle. This is
  what "never reuse a field cycle" looks like on the wire.
* Job binding: exactly the PENDING rows carry a Job. A PENDING row with no Job is
  work nothing records; a retired row still holding one is a Job nothing cancels.

### All six generations here are DIRECTORY generations

There are four generation namespaces in this codebase — directory slot,
inventory container, inventory lot, navigation route descriptor — and
`gear.gd`/`reservations.gd` rows are bare indices with none. Section 8's
`_owner_generation`, `_job_generation`, `_demand_owner_generation`,
`_demand_job_generation`, `_hive_owner_generation` and `_hive_job_generation` are
all the **directory** one: each is the `y` of an `EntityRef` produced by
`farming.ref_of()`, `orchard_hive.hive_ref_of()`, a designation reference or
`jobs.create_job()`. They are validated against `DIRECTORY_CAPACITY` and the
`(-1, 0)` null pair, and the matching slot columns are directory slots, never the
typed row that names the same entity inside its own store.

### The int32 sign trap

GDScript ints are 64-bit, so `0x80000000` is a positive 2147483648 and
`-2147483648` is the same four bytes read as int32. Every four-byte field is read
signed and every generation, day and cycle column then refuses a negative value.
The test builds the bit pattern through `save_codec.gd`'s own
`u32_bits_to_int32()`/`int32_bits_to_u32()` and asserts the pair agrees, because
a real bug has hidden inside the test written to catch this.

## What was rejected

* **Streaming the section in 65536-byte chunks**, as section 3 does. Section 8 is
  363151 bytes, roughly one seventeenth of section 3, and a 29-branch chunk
  dispatcher would have cost more clarity than it bought. `Record.column_bytes()`
  is the per-column split a future cursor would need. Measured cold-path encode:
  ~4.4 ms for a whole section.
* **A second block for `jobs.gd`.** The persistence registry files `_live_slots`,
  `_bucket_begin`, `_job_persistent_id`, `_agent_persistent_id` and the job
  counters under §8, but every one is category 2 — rebuilt, never written — and
  the registry artifact declares exactly one section-8 owner. A second block
  would need a registry row first and would change `store_count` and the owner
  schema version together.
* **Inferring the extents from ordinal 0.** Explicitly forbidden, and mutation
  tested: deriving either the encoded or the decoded `element_count` from
  `FIELD_EXTENTS[0]` kills 8 and 7 tests respectively.

## Rows owed to documents this lane does not own

`docs/systems_architecture.md` and `docs/persistence_state_registry.md` are not
this lane's files, and `docs/validation/state_registry_coverage.py` fails C1
until the registry gains a section for the new module. The exact rows are
reported with the lane's handoff: one
`### \`godot/scripts/core/save_section_job_indexes.gd\`` section with a
category-3 codec row (the module holds no module-level `var`; `Record` is
362880 bytes of bounded codec scratch) and a category-3 scratch row. No
authoritative column is added by this work, so no ledger row changes size.
