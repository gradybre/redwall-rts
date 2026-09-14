extends RefCounted
## ARCH-SAVE-002 section 8 JOB_INDEXES: `job_planner.gd`'s five ledgers, encoded through
## `save_codec.gd`'s ARCH-SAVE-001 primitives under SAVE-LAYOUT-R01's owner-block wrapper.
##
## ## Which generation namespace this is: DIRECTORY, all of it
##
## The 2026-09-11 addendum records FOUR distinct generation spaces -- `entity_directory.gd`'s slot
## generation, `inventory.gd`'s container generation `_c_generation`, `inventory.gd`'s lot
## generation `_l_generation`, and `navigation.gd`'s route-descriptor generation -- and
## `gear.gd`/`reservations.gd` rows carry NO generation and are addressed by bare row index.
##
## EVERY generation column in section 8 is the DIRECTORY one, and that is a finding, not an
## assumption: `_owner_generation` is the `y` of `farming.ref_of()`, `_job_generation` and
## `_demand_job_generation` are the `y` of the `EntityRef` `jobs.create_job()` returns through the
## directory, `_demand_owner_generation` is the `y` of a designation's zone `EntityRef`, and
## `_hive_owner_generation`/`_hive_job_generation` are the `y` of `orchard_hive.hive_ref_of()` and
## of a hive-service Job. All six are validated against `entity_directory.gd`'s DIRECTORY_CAPACITY
## and its `(-1, 0)` null pair. There is no container, lot or route generation in this section, and
## `_owner_slot`, `_demand_owner_slot`, `_hive_owner_slot`, `_job_slot`, `_demand_job_slot` and
## `_hive_job_slot` are DIRECTORY SLOTS, never the typed row index that names them inside
## `farming.gd`, `forage.gd`, `orchard_hive.gd` or `jobs.gd`.
##
## ## What section 8's bytes are
##
## REG-R01 (2026-09-12): "Use the standard owner wrapper for sections 4/5/6/7/8/9." SAVE-LAYOUT-R01
## fixes that wrapper: `section = store_count:u32, store blocks in registered order`;
## `store = owner_key:utf8-u32, owner_schema_version:u32, primary_count:u64,
## payload_byte_length:u64, payload`; `ordinary column payload = for each schema field:
## element_count:u64, tightly packed LE values`. Blocks tile the section with no gaps.
##
##   | Offset | Type   | Field                                       | Bytes |
##   |-------:|--------|---------------------------------------------|------:|
##   |      0 | u32    | store_count = 1                             |     4 |
##   |      4 | u32    | owner_key byte length = 11                  |     4 |
##   |      8 | utf8   | owner_key = "job_planner"                   |    11 |
##   |     19 | u32    | owner_schema_version = 1                    |     4 |
##   |     23 | u64    | primary_count = 8192 -- SAVE-C3-R01         |     8 |
##   |     31 | u64    | payload_byte_length = 363112                |     8 |
##   |     39 |        | payload: 29 x (element_count:u64 + values)  |363112 |
##   | 363151 |        | end of section                              |       |
##
## `store_count` is 1 because REG-R01's artifact registers exactly one section-8 owner. The other
## module the persistence registry files under section 8, `jobs.gd`, contributes `_live_slots`,
## `_bucket_begin`, `_job_persistent_id`, `_agent_persistent_id` and three counters -- and every
## one of them is CATEGORY 2, rebuilt and never written. A second block here would need a registry
## row first, and would change both `store_count` and OWNER_SCHEMA_VERSION.
##
## COLUMN-MAJOR, BY RULING AND NOT BY INFERENCE. SAVE-LAYOUT-R01: "Packed stores use column-major
## bytes. Field schema order is the outer loop; ascending physical slot is the inner loop. SoA does
## not mathematically force a wire order; this ruling explicitly chooses it."
##
## FIELD ORDER IS THE REGISTRY'S DECLARED ORDINAL, NOT GDSCRIPT DECLARATION ORDER. REG-R01:
## "Do not regenerate order from GDScript declaration order, dictionaries, display labels,
## directory iteration or this document at runtime." FIELD_KEYS below is transcribed from
## `docs/planning/canonical_state_registry.json`'s `section_id 8, owner_key "job_planner"` group in
## its declared `ordinal` order; `test_save_section_job_indexes.gd` reads that JSON and asserts the
## transcription, so a reordering here fails against the artifact rather than against a comment.
## The two orders happen to coincide for the first eleven fields and DIVERGE nowhere -- but they
## are not the same list, and only one of them is authoritative.
##
## ## FIVE DIFFERENTLY SIZED TABLES, FIVE EXPLICIT EXTENTS
##
## REG-R01: "Explicit field extents come from the owning schema, not the descriptor's row_count.
## Module owners containing several differently sized logical tables need an explicitly validated
## primary count and child extents before their wire body is frozen; the logical registry does not
## authorize guessing these from the first column."
##
## Section 8 is exactly such an owner. Its five tables are:
##
##   | Table                      | Extent constant                            | Rows |
##   |----------------------------|--------------------------------------------|-----:|
##   | Pending service rows       | `job_planner.SERVICE_ROW_COUNT`            | 8192 |
##   | Per-plot cycle history     | `job_planner.OWNER_CAPACITY`               | 4096 |
##   | Per-designation enablement | `job_planner.ZONE_OWNER_CAPACITY`          |  128 |
##   | Forage demand rows         | `job_planner.DEMAND_ROW_COUNT`             |  640 |
##   | Hive service rows          | `job_planner.HIVE_OWNER_CAPACITY`          | 1024 |
##
## NOT ONE of those is inferred from the first column. FIELD_EXTENTS names the owning constant for
## every one of the 29 fields, `docs/persistence_state_registry.md` states the same five capacities
## per field group, and the registry artifact's `shape.declared_capacity` string names the same
## constant again. A field whose extent were taken from `_owner_slot`'s 8192 would make the 128-row
## zone table read 8192 zones and consume the hive table's bytes; the suite mutates exactly that.
##
## ## BLOCKER J1 IS CLOSED: `primary_count` = 8192, THE DESIGNATED PENDING-SERVICE TABLE
##
## SAVE-C3-R01 (2026-09-14) supplies the number decision 0120 refused to invent, and -- more
## importantly than the digits -- it supplies the MEANING, which is what two sections disagreed
## about. `primary_count` is "a DECLARED PRIMARY PHYSICAL ROW EXTENT for that owner block, not a
## total of every field's extents and not an occupancy count". For a multi-table owner the section
## contract must NAME the primary table; section 8 names the PENDING-SERVICE ROW TABLE.
##
## THE REASON IS OPERATIONAL, NOT ARITHMETIC. Section 8 is the job planner's index. What that index
## IS, as a thing a load has to reconstitute, is the pending service ledger: rows 0..8191 of
## `SERVICE_ROW_COUNT`, carrying the status, the Job binding, the service day and the sowing gate.
## The other four extents describe that ledger's inputs and edges -- 4096 rows of per-plot cycle
## history, 128 designation enablement flags, 640 forage demand rows, 1024 hive service rows.
## `primary_count` names the block's principal table so a reader knows WHICH physical extent the
## framing word refers to; it is not a census of the block. That is exactly why:
##
##   * 14080, the sum of all five extents, is REFUSED. It is not any table's row extent, so no
##     decode could ever check a column against it; a "sum" reading makes the word describe
##     nothing, and it is the reading section 9 already rejected for itself.
##   * 5248, the sum of the three independent OWNER capacities (4096 + 128 + 1024), is REFUSED for
##     the same reason, with the extra defect of being a sum over an arbitrary subset.
##   * 4096 is REFUSED: the per-plot cycle history is a secondary table keyed by farm plot, not the
##     ledger this section exists to carry.
##   * 7 is REFUSED. It was this suite's old fixture, chosen precisely BECAUSE it was not any real
##     extent, back when the count was carried rather than chosen. It is evidence of the gap that
##     SAVE-C3-R01 closed and is never a compatibility precedent.
##
## SAVE-C3-R01 also fixes HOW it is enforced: "Writer and decoder must validate against the
## compiled constant rather than a caller-supplied positive number." So `encode_section()` no
## longer takes the count and `decode_section_into()` no longer takes an expectation; both use
## PRIMARY_COUNT, and `primary_count_refusal()` is the public gate that refuses every other value
## including all four named above. A caller cannot pick, so two writers cannot disagree.
##
## THIS DOES NOT REINTERPRET A RELEASED SAVE. Production writing was refused while the count was
## unruled, so no file carries a section 8 with a different word there. Section and owner schema
## versions therefore BOTH STAY 1 (SAVE-C3-R01, "Version/field disposition"); no gratuitous bump.
## The 363112-byte payload and the 363151-byte section length are unchanged, as are all 29 field
## ordinals, types and extents.
##
## THE DESCRIPTOR IS 8192 TOO, and for a stated reason rather than by coincidence: SAVE-LAYOUT-R01
## makes a multi-block section's descriptor `row_count` the checked SUM of its blocks' primary
## counts, and section 8 holds exactly ONE block, so the sum of one term is that term.
## `descriptor_row_count()` takes no argument, exactly as section 9's does.
##
## ## BLOCKER J2 -- `job_planner.gd` PUBLISHES NO BULK COLUMN API, SO THERE IS NO LIVE ROUND TRIP
##
## `capture_into()` and `apply()` are the two halves section 3 has, and section 8 cannot have them
## yet. The planner's public readers are GATED, deliberately and correctly, for the simulation's
## own use: `service_day_into()` refuses a non-daily operation and refuses a FREE row rather than
## answering 0; `service_job_of()` answers NULL_REF unless the row is PENDING; `sowing_crop_of()`,
## `sowing_field_cycle_of()` and `sowing_gate_reason_of()` address only the SOW row of an owner;
## `service_requires_water()` collapses a byte to a bool. A capture built from them would have to
## SYNTHESISE the values it cannot read -- "a sowing row's `_service_day` is NO_DAY by
## construction" is true today and is exactly the assumption a save must not encode.
##
## This module therefore does not reach into `store._owner_slot`: no module in this repository
## reads another's underscore-prefixed columns, and doing it here would put the planner's
## invariants in two files. Section 3 hit the same wall (its BLOCKER D1) and it was closed by the
## directory owner adding `copy_columns_into()`/`restore_columns()` under decision 0105;
## `save_section_world_runtime.gd` hit it against `sim_clock.gd` and Astra ruled `restore_runtime()`
## into existence as RESTORE-R01. Section 8 needs the same pair from the planner owner:
##
##     func copy_job_index_columns_into(out: Array) -> bool     # 29 columns, registry ordinal order
##     func restore_job_index_columns(columns: Array) -> bool   # validating, transactional
##
## The exact signature is the PLANNER OWNER'S to publish, not this module's to guess, which is why
## `capture_into()` and `apply()` below refuse with REFUSE_STORE_NO_COLUMN_API and name the gap
## instead of calling a method that does not exist. `capture_record_into()` is the column-level
## capture that works TODAY, exactly as section 3's `capture_columns_into()` does: a caller holding
## 29 validated columns -- a fixture, a migration, the planner owner once the reader lands -- gets
## the same validation and the same all-or-nothing publication.
##
## ## What is written and what is rebuilt
##
## `docs/persistence_state_registry.md`'s `job_planner.gd` rows classify every member and this
## module follows that classification exactly:
##
##   * CATEGORY 1, WRITTEN: the 29 columns below. The registry's argument for each is recorded
##     there; the sharpest are `_serviced_day` ("losing them re-requests or silently skips a day's
##     tending"), `_demand_quantified_milli` ("dropping it re-issues a forage job for goods already
##     claimed") and the cycle cursors, which are what keeps "never reuse a field cycle" true.
##   * CATEGORY 2, REBUILT AND NEVER WRITTEN: `_dirty_rows`/`_is_dirty`/`_dirty_count` and their
##     zone and hive twins -- "a sweep accelerator, not state: a load that marks every owner dirty
##     produces the same evaluations in the same order". Only `[0, _dirty_count)` of each list is
##     meaningful, so persisting the stale tail would make two identical worlds produce different
##     bytes. The twenty-odd observable counters are counts of the columns above them.
##   * CATEGORY 3, NOT STATE: `_last_blocker`, `_math` and `_calendar` scratch.
##
## `Record` is category 3 too, and is this module's own: 362880 bytes of BOUNDED CODEC SCRATCH that
## exists only between a capture and an apply. It is NOT a new authoritative column and owes no
## ledger row of its own beyond that classification.
##
## ## Allocate before consume
##
## Decision 0059. `decode_section_into()` proves the whole extent is present, reads into a LOCAL
## Record, validates every framing field, every column domain and every cross-column invariant, and
## only then copies into the caller's Record. A refusal -- truncated, or FULL-LENGTH AND INVALID --
## leaves the caller's Record byte-identical, and the suite asserts that by byte comparison rather
## than by eye. Validate-then-commit, never commit-then-validate.
##
## ## The int32 sign trap
##
## GDScript ints are 64-bit, so `0x80000000` is a POSITIVE 2147483648 while `-2147483648` is the
## same four bytes read as int32. Every four-byte field here is read SIGNED, through
## `PackedByteArray.to_int32_array()`, and every generation, day and cycle column is then refused
## if it is negative. A generation whose bytes are `00 00 00 80` therefore decodes as -2147483648
## and is REFUSED, rather than being accepted as a plausible 2147483648 that no i32 column could
## hold. A real bug has hidden inside the test written to catch this, so the suite builds those
## values through `save_codec.gd`'s explicit bit helpers instead of typing a signed literal.
##
## ## COLD PATH, NO FLOAT
##
## ARCH-SAVE-003 saves at a completed boundary and loads at a load boundary, so this module
## allocates Records and buffers freely; ARCH-MEM-001's per-tick allocation ban applies to
## `job_planner.gd`'s columns, which this module only mirrors. ARCH-AUTH-002: there is no float in
## this file and there must never be one; the suite greps this source to enforce it.
##
## ## OPEN, NOT INVENTED
##
##   * `owner_key` is `"job_planner"`, read off REG-R01's artifact (`owner_key: "job_planner"`),
##     not chosen. OWNER_SCHEMA_VERSION is 1, from that artifact's `owner_schema_version` and from
##     the baseline section vector `[2,2,1,2,1,1,2,1,2,1,1,2,1,2,1]`, whose eighth entry is 1.
##   * The 64-byte DESCRIPTOR is `save_header.gd`'s to write and its CRC-32 is `save_header.gd`'s
##     to compute. This module supplies only the one word the header cannot know,
##     `descriptor_row_count()`, and produces the bytes the rest protect.
##   * `release_save_ready` stays false. SAVE-C3-R01 binds two COUNTS and nothing else: BLOCKER J2
##     is open, there is no section 8 capture or restore adapter, and no release-save completeness
##     follows. Section 15 is not this module's, and nothing here claims section 8 completes a
##     release save.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")

# --- ARCH-SAVE-002 identity and layout ------------------------------------------------------------

## ARCH-SAVE-002's section order: "... 7 INVENTORIES_AND_LEASE_INDEXES, 8 JOB_INDEXES, 9 NAVIGATION".
const SECTION_ID: int = 8

## REG-R01 registers exactly one section-8 owner; `jobs.gd`'s section-8 rows are all category 2.
const STORE_COUNT: int = 1
const OWNER_KEY: String = "job_planner"
const OWNER_KEY_BYTES: int = 11
## SAVE-LAYOUT-R01: "nonempty ASCII, max 256 bytes".
const OWNER_KEY_MAX_BYTES: int = 256
const OWNER_SCHEMA_VERSION: int = 1

# --- the five table extents, taken from the owning schema -----------------------------------------

## Read from `job_planner.gd` rather than restated, so the two cannot drift. Every one of the five
## is named by the registry artifact's `shape.declared_capacity` for the fields that use it.
const SERVICE_ROWS: int = JobPlannerScript.SERVICE_ROW_COUNT
const OWNER_ROWS: int = JobPlannerScript.OWNER_CAPACITY
const ZONE_ROWS: int = JobPlannerScript.ZONE_OWNER_CAPACITY
const DEMAND_ROWS: int = JobPlannerScript.DEMAND_ROW_COUNT
const HIVE_ROWS: int = JobPlannerScript.HIVE_OWNER_CAPACITY

## SAVE-C3-R01's designated primary count for this block: the PENDING-SERVICE row table.
##
## Written as `SERVICE_ROWS` and not as the literal 8192 because the ruling designates a TABLE, not
## a number -- "designate the pending-service row table, SERVICE_ROW_COUNT, as the primary
## operational table". If `job_planner.gd` ever resized that ledger, this word must move with it,
## and the owner schema version must move too. It is emphatically NOT "whatever ordinal 0's extent
## happens to be": the four other extents are read from their own constants and checked separately,
## and 14080 (all five summed), 5248 (the three owner capacities summed), 4096 (the secondary
## per-plot cycle table) and 7 (the retired test fixture) are each refused by name below.
const PRIMARY_COUNT: int = SERVICE_ROWS

## The planner's own domains, likewise read and never restated.
const OPERATION_COUNT: int = JobPlannerScript.OPERATION_COUNT
const OPERATION_FARM_TEND: int = JobPlannerScript.OPERATION_FARM_TEND
const OPERATION_FARM_SOW: int = JobPlannerScript.OPERATION_FARM_SOW
const PATCH_KIND_COUNT: int = JobPlannerScript.PATCH_KIND_COUNT
const STATUS_FREE: int = JobPlannerScript.STATUS_FREE
const STATUS_PENDING: int = JobPlannerScript.STATUS_PENDING
const STATUS_REQUESTED: int = JobPlannerScript.STATUS_REQUESTED
const STATUS_COUNT: int = JobPlannerScript.STATUS_COUNT
const REASON_COUNT: int = JobPlannerScript.REASON_COUNT
const BLOCKER_COUNT: int = JobPlannerScript.BLOCKER_COUNT
const HIVE_BLOCKER_COUNT: int = JobPlannerScript.HIVE_BLOCKER_COUNT
const NO_DAY: int = JobPlannerScript.NO_DAY
const NO_CYCLE: int = JobPlannerScript.NO_CYCLE
const NO_CROP: int = JobPlannerScript.NO_CROP
const MAX_FIELD_CYCLE: int = JobPlannerScript.MAX_FIELD_CYCLE
const CROP_COUNT: int = FarmingScript.CROP_COUNT

## The directory domain every slot/generation pair in this section belongs to.
const DIRECTORY_CAPACITY: int = EntityDirectoryScript.DIRECTORY_CAPACITY
const NULL_SLOT: int = EntityDirectoryScript.NULL_SLOT
const NULL_GENERATION: int = EntityDirectoryScript.NULL_GENERATION
const MAX_INT32: int = EntityDirectoryScript.MAX_INT32

# --- the 29 declared fields, in REG-R01's ordinal order -------------------------------------------

const FIELD_OWNER_SLOT: int = 0
const FIELD_OWNER_GENERATION: int = 1
const FIELD_SERVICE_DAY: int = 2
const FIELD_JOB_SLOT: int = 3
const FIELD_JOB_GENERATION: int = 4
const FIELD_SERVICED_DAY: int = 5
const FIELD_STATUS: int = 6
const FIELD_REQUIRES_WATER: int = 7
const FIELD_FIELD_CYCLE: int = 8
const FIELD_REQUESTED_CROP: int = 9
const FIELD_GATE_REASON: int = 10
const FIELD_CYCLE_CURSOR: int = 11
const FIELD_COMPLETED_CYCLE: int = 12
const FIELD_DEMAND_ENABLED: int = 13
const FIELD_DEMAND_OWNER_SLOT: int = 14
const FIELD_DEMAND_OWNER_GENERATION: int = 15
const FIELD_DEMAND_STATUS: int = 16
const FIELD_DEMAND_BLOCKER: int = 17
const FIELD_DEMAND_JOB_SLOT: int = 18
const FIELD_DEMAND_JOB_GENERATION: int = 19
const FIELD_DEMAND_QUANTIFIED_MILLI: int = 20
const FIELD_HIVE_OWNER_SLOT: int = 21
const FIELD_HIVE_OWNER_GENERATION: int = 22
const FIELD_HIVE_SERVICE_DAY: int = 23
const FIELD_HIVE_JOB_SLOT: int = 24
const FIELD_HIVE_JOB_GENERATION: int = 25
const FIELD_HIVE_FEED_DEMAND_MILLI: int = 26
const FIELD_HIVE_STATUS: int = 27
const FIELD_HIVE_BLOCKER: int = 28
const FIELD_COUNT: int = 29

## SAVE-R09 canonical type codes: 0 = u8, 2 = i32, 4 = i64.
const CANONICAL_TYPE_U8: int = 0
const CANONICAL_TYPE_I32: int = 2
const CANONICAL_TYPE_I64: int = 4

## Transcribed from the registry artifact's declared ordinals. NOT GDScript declaration order.
const FIELD_KEYS: Array[StringName] = [
	&"_owner_slot", &"_owner_generation", &"_service_day", &"_job_slot", &"_job_generation",
	&"_serviced_day", &"_status", &"_requires_water", &"_field_cycle", &"_requested_crop",
	&"_gate_reason", &"_cycle_cursor", &"_completed_cycle", &"_demand_enabled",
	&"_demand_owner_slot", &"_demand_owner_generation", &"_demand_status", &"_demand_blocker",
	&"_demand_job_slot", &"_demand_job_generation", &"_demand_quantified_milli",
	&"_hive_owner_slot", &"_hive_owner_generation", &"_hive_service_day", &"_hive_job_slot",
	&"_hive_job_generation", &"_hive_feed_demand_milli", &"_hive_status", &"_hive_blocker",
]

## Canonical type code per ordinal, from the artifact's `type_code`.
const FIELD_TYPES: Array[int] = [
	CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32,
	CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_U8, CANONICAL_TYPE_U8,
	CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_U8, CANONICAL_TYPE_I32,
	CANONICAL_TYPE_I32, CANONICAL_TYPE_U8, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32,
	CANONICAL_TYPE_U8, CANONICAL_TYPE_U8, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32,
	CANONICAL_TYPE_I64, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32,
	CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I64, CANONICAL_TYPE_U8,
	CANONICAL_TYPE_U8,
]

## Element width in bytes per ordinal. Equals the type code's width; `field_width()` recomputes it.
const FIELD_WIDTHS: Array[int] = [
	4, 4, 4, 4, 4, 4, 1, 1, 4, 4, 1, 4, 4, 1, 4, 4, 1, 1, 4, 4, 8, 4, 4, 4, 4, 4, 8, 1, 1,
]

## Row count per ordinal, from the owning schema's five table constants. NEVER from column zero.
const FIELD_EXTENTS: Array[int] = [
	SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS,
	SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS,
	OWNER_ROWS, OWNER_ROWS,
	ZONE_ROWS, ZONE_ROWS, ZONE_ROWS,
	DEMAND_ROWS, DEMAND_ROWS, DEMAND_ROWS, DEMAND_ROWS, DEMAND_ROWS,
	HIVE_ROWS, HIVE_ROWS, HIVE_ROWS, HIVE_ROWS, HIVE_ROWS, HIVE_ROWS, HIVE_ROWS, HIVE_ROWS,
]

## SAVE-LAYOUT-R01's DECLARED canonical unused value per ordinal: "Use zero only where the owner
## declares zero". `job_planner.gd::clear()` declares every one of these; the six slot columns and
## `_requested_crop` are -1, and every null reference generation is 0.
const FIELD_UNUSED: Array[int] = [
	NULL_SLOT, NULL_GENERATION, NO_DAY, NULL_SLOT, NULL_GENERATION, NO_DAY, STATUS_FREE, 0,
	NO_CYCLE, NO_CROP, 0, NO_CYCLE, NO_CYCLE, 0, NULL_SLOT, NULL_GENERATION, STATUS_FREE, 0,
	NULL_SLOT, NULL_GENERATION, 0, NULL_SLOT, NULL_GENERATION, NO_DAY, NULL_SLOT,
	NULL_GENERATION, 0, STATUS_FREE, 0,
]

## Index of each field within its own type group, in ordinal order. `Record._init()` produces this
## layout by construction and `storage_index_of()` recomputes it, so the table cannot drift.
const FIELD_STORAGE: Array[int] = [
	0, 1, 2, 3, 4, 5, 0, 1, 6, 7, 2, 8, 9, 3, 10, 11, 4, 5, 12, 13, 0, 14, 15, 16, 17, 18, 1, 6, 7,
]

## Fields whose value must be a DIRECTORY slot: -1, or in `[0, DIRECTORY_CAPACITY)`.
const SLOT_FIELDS: Array[int] = [
	FIELD_OWNER_SLOT, FIELD_JOB_SLOT, FIELD_DEMAND_OWNER_SLOT, FIELD_DEMAND_JOB_SLOT,
	FIELD_HIVE_OWNER_SLOT, FIELD_HIVE_JOB_SLOT,
]

## Fields that can never hold a negative value. This is the int32 sign trap's guard: the six
## DIRECTORY generations, the three day columns and the three cycle columns.
const NON_NEGATIVE_FIELDS: Array[int] = [
	FIELD_OWNER_GENERATION, FIELD_SERVICE_DAY, FIELD_JOB_GENERATION, FIELD_SERVICED_DAY,
	FIELD_FIELD_CYCLE, FIELD_CYCLE_CURSOR, FIELD_COMPLETED_CYCLE,
	FIELD_DEMAND_OWNER_GENERATION, FIELD_DEMAND_JOB_GENERATION, FIELD_HIVE_OWNER_GENERATION,
	FIELD_HIVE_SERVICE_DAY, FIELD_HIVE_JOB_GENERATION,
]

## The i64 quantity columns, both of which are milli-unit amounts and neither of which may be
## negative: `quantity_milli` is the GDD's unit and a negative claim is not a smaller claim.
const QUANTITY_FIELDS: Array[int] = [
	FIELD_DEMAND_QUANTIFIED_MILLI, FIELD_HIVE_FEED_DEMAND_MILLI,
]

## What `job_planner.gd::service_row_is_clear()` requires of a FREE service row, field by field.
## `_serviced_day` is deliberately absent: `_retire_row()` keeps it, because it is the completion
## history "the ruling forbids discarding".
const SERVICE_CLEAR_FIELDS: Array[int] = [
	FIELD_OWNER_SLOT, FIELD_OWNER_GENERATION, FIELD_SERVICE_DAY, FIELD_JOB_SLOT,
	FIELD_JOB_GENERATION, FIELD_REQUIRES_WATER, FIELD_FIELD_CYCLE, FIELD_REQUESTED_CROP,
	FIELD_GATE_REASON,
]

## What `demand_row_is_clear()` requires of a FREE demand row. `_demand_blocker` is deliberately
## absent: it is "the row's retained REASON, written by the gate sweep onto a free row".
const DEMAND_CLEAR_FIELDS: Array[int] = [
	FIELD_DEMAND_JOB_SLOT, FIELD_DEMAND_JOB_GENERATION, FIELD_DEMAND_QUANTIFIED_MILLI,
]

## What `hive_service_row_is_clear()` requires of a FREE hive row. The blocker byte AND the winter
## feed demand are deliberately absent, for the reason that predicate states.
const HIVE_CLEAR_FIELDS: Array[int] = [
	FIELD_HIVE_OWNER_SLOT, FIELD_HIVE_OWNER_GENERATION, FIELD_HIVE_SERVICE_DAY,
	FIELD_HIVE_JOB_SLOT, FIELD_HIVE_JOB_GENERATION,
]

# --- byte arithmetic -------------------------------------------------------------------------------

const OFFSET_STORE_COUNT: int = 0
const OFFSET_OWNER_KEY_LENGTH: int = 4
const OFFSET_OWNER_KEY: int = 8
const OFFSET_OWNER_SCHEMA_VERSION: int = 19
const OFFSET_PRIMARY_COUNT: int = 23
const OFFSET_PAYLOAD_BYTE_LENGTH: int = 31
const FRAMING_BYTES: int = 39

## Each field's payload is `element_count:u64` then its tightly packed LE values.
const ELEMENT_COUNT_BYTES: int = 8

## 29 * 8 element counts + the summed column widths. Stated as a constant because a const cannot
## hold a loop; `payload_bytes()` recomputes it from FIELD_WIDTHS and FIELD_EXTENTS and the suite
## asserts the two agree, so a changed extent cannot leave this literal behind.
const CANONICAL_VALUE_BYTES: int = 362880
const PAYLOAD_BYTES: int = 363112
const SECTION_BYTES: int = 363151

## `save_header.gd`'s endian sentinel, reused as the little-endian probe constant. 0x01020304.
const BYTE_ORDER_PROBE: int = SaveHeader.ENDIAN_SENTINEL

# --- refusal codes ---------------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_BYTE_ORDER: StringName = &"SAVE_JOB_BYTE_ORDER"
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_JOB_NEGATIVE_OFFSET"
const REFUSE_TRUNCATED: StringName = &"SAVE_JOB_TRUNCATED"
const REFUSE_LENGTH: StringName = &"SAVE_JOB_LENGTH"
const REFUSE_RECORD_SHAPE: StringName = &"SAVE_JOB_RECORD_SHAPE"
const REFUSE_STORE_COUNT: StringName = &"SAVE_JOB_STORE_COUNT"
const REFUSE_OWNER_KEY: StringName = &"SAVE_JOB_OWNER_KEY"
const REFUSE_OWNER_SCHEMA_VERSION: StringName = &"SAVE_JOB_OWNER_SCHEMA_VERSION"
## SAVE-C3-R01 retired SAVE_JOB_PRIMARY_COUNT_UNRULED: the count is ruled, so an unruled-count
## refusal can no longer be raised. The production refusal below now stands on BLOCKER J2 alone.
const REFUSE_PRIMARY_COUNT: StringName = &"SAVE_JOB_PRIMARY_COUNT"
const REFUSE_PAYLOAD_LENGTH: StringName = &"SAVE_JOB_PAYLOAD_LENGTH"
const REFUSE_ELEMENT_COUNT: StringName = &"SAVE_JOB_ELEMENT_COUNT"
const REFUSE_FIELD_ORDINAL: StringName = &"SAVE_JOB_FIELD_ORDINAL"
const REFUSE_STATUS_DOMAIN: StringName = &"SAVE_JOB_STATUS_DOMAIN"
const REFUSE_REASON_DOMAIN: StringName = &"SAVE_JOB_REASON_DOMAIN"
const REFUSE_FLAG_DOMAIN: StringName = &"SAVE_JOB_FLAG_DOMAIN"
const REFUSE_SLOT_DOMAIN: StringName = &"SAVE_JOB_SLOT_DOMAIN"
const REFUSE_NEGATIVE_VALUE: StringName = &"SAVE_JOB_NEGATIVE_VALUE"
const REFUSE_CROP_DOMAIN: StringName = &"SAVE_JOB_CROP_DOMAIN"
const REFUSE_CYCLE_RANGE: StringName = &"SAVE_JOB_CYCLE_RANGE"
const REFUSE_ROW_NOT_CLEAR: StringName = &"SAVE_JOB_ROW_NOT_CLEAR"
const REFUSE_OPERATION_MISMATCH: StringName = &"SAVE_JOB_OPERATION_MISMATCH"
const REFUSE_REFERENCE_SHAPE: StringName = &"SAVE_JOB_REFERENCE_SHAPE"
const REFUSE_JOB_BINDING: StringName = &"SAVE_JOB_JOB_BINDING"
const REFUSE_OWNER_MISSING: StringName = &"SAVE_JOB_OWNER_MISSING"
const REFUSE_CYCLE_DISAGREES: StringName = &"SAVE_JOB_CYCLE_DISAGREES"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_JOB_ENCODE_FAILED"
const REFUSE_STORE_NO_COLUMN_API: StringName = &"SAVE_JOB_STORE_NO_COLUMN_API"


class Record:
	"""One decoded section 8: the 29 category-1 columns, each at its own declared extent.

	The columns are held in three typed groups rather than 29 named members, because the wire
	format walks them by ORDINAL and a named member cannot be indexed by one. `FIELD_STORAGE` maps
	an ordinal to its index within its group; `_init()` produces that layout by construction.

	Allocated once in `_init()`, which is the only place this class resizes anything. There is no
	dirty list and no counter here, and that absence is the design: only `[0, _dirty_count)` of a
	dirty list is meaningful, so persisting one would make two identical worlds produce different
	bytes.
	"""
	var u8_columns: Array[PackedByteArray] = []
	var i32_columns: Array[PackedInt32Array] = []
	var i64_columns: Array[PackedInt64Array] = []

	func _init() -> void:
		"""Allocate all 29 columns at their declared extents, then fill the canonical empty state."""
		for field: int in FIELD_COUNT:
			if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
				var bytes: PackedByteArray = PackedByteArray()
				bytes.resize(FIELD_EXTENTS[field])
				u8_columns.append(bytes)
			elif FIELD_TYPES[field] == CANONICAL_TYPE_I32:
				var words: PackedInt32Array = PackedInt32Array()
				words.resize(FIELD_EXTENTS[field])
				i32_columns.append(words)
			else:
				var longs: PackedInt64Array = PackedInt64Array()
				longs.resize(FIELD_EXTENTS[field])
				i64_columns.append(longs)
		clear()

	func clear() -> void:
		"""Refill every column with SAVE-LAYOUT-R01's DECLARED canonical unused value.

		This is `job_planner.gd::clear()`'s state exactly: every slot -1, every generation 0, every
		day and cycle 0, every status FREE and every requested crop NO_CROP.

		Each column is read out, filled and written back rather than filled in place: a packed
		array read out of an `Array` is a copy-on-write handle, and mutating it through the
		subscript would fill a temporary and leave the stored column untouched.
		"""
		for field: int in FIELD_COUNT:
			var index: int = FIELD_STORAGE[field]
			if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
				var bytes: PackedByteArray = u8_columns[index]
				bytes.fill(FIELD_UNUSED[field])
				u8_columns[index] = bytes
			elif FIELD_TYPES[field] == CANONICAL_TYPE_I32:
				var words: PackedInt32Array = i32_columns[index]
				words.fill(FIELD_UNUSED[field])
				i32_columns[index] = words
			else:
				var longs: PackedInt64Array = i64_columns[index]
				longs.fill(FIELD_UNUSED[field])
				i64_columns[index] = longs

	func copy_from(other: Record) -> void:
		"""Overwrite all 29 columns from `other`. C++ copies, one per column, no element loop."""
		for index: int in other.u8_columns.size():
			u8_columns[index] = other.u8_columns[index].duplicate()
		for index: int in other.i32_columns.size():
			i32_columns[index] = other.i32_columns[index].duplicate()
		for index: int in other.i64_columns.size():
			i64_columns[index] = other.i64_columns[index].duplicate()

	func equals(other: Record) -> bool:
		"""True when all 29 columns are byte-identical. Proves a refusal changed nothing."""
		return u8_columns == other.u8_columns and i32_columns == other.i32_columns \
			and i64_columns == other.i64_columns

	func u8_column(field: int) -> PackedByteArray:
		"""One u8 column by ordinal. Refuses nothing: an ordinal of the wrong type is a code bug."""
		return u8_columns[FIELD_STORAGE[field]]

	func i32_column(field: int) -> PackedInt32Array:
		"""One i32 column by ordinal."""
		return i32_columns[FIELD_STORAGE[field]]

	func i64_column(field: int) -> PackedInt64Array:
		"""One i64 column by ordinal."""
		return i64_columns[FIELD_STORAGE[field]]

	func value_of(field: int, row: int) -> int:
		"""One value of one column, whatever its width. For validators that walk mixed tables."""
		if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
			return u8_columns[FIELD_STORAGE[field]][row]
		if FIELD_TYPES[field] == CANONICAL_TYPE_I32:
			return i32_columns[FIELD_STORAGE[field]][row]
		return i64_columns[FIELD_STORAGE[field]][row]

	func set_value(field: int, row: int, value: int) -> void:
		"""Write one value of one column, whatever its width. Read out, write, store back.

		The same copy-on-write rule `clear()` documents: the column is written back explicitly
		rather than mutated through a subscript chain.
		"""
		var index: int = FIELD_STORAGE[field]
		if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
			var bytes: PackedByteArray = u8_columns[index]
			bytes[row] = value
			u8_columns[index] = bytes
		elif FIELD_TYPES[field] == CANONICAL_TYPE_I32:
			var words: PackedInt32Array = i32_columns[index]
			words[row] = value
			i32_columns[index] = words
		else:
			var longs: PackedInt64Array = i64_columns[index]
			longs[row] = value
			i64_columns[index] = longs

	func assign_column(field: int, raw: PackedByteArray) -> void:
		"""Reinterpret one column's little-endian bytes into its packed array. C++, no loop."""
		if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
			u8_columns[FIELD_STORAGE[field]] = raw
		elif FIELD_TYPES[field] == CANONICAL_TYPE_I32:
			i32_columns[FIELD_STORAGE[field]] = raw.to_int32_array()
		else:
			i64_columns[FIELD_STORAGE[field]] = raw.to_int64_array()

	func column_size(field: int) -> int:
		"""The number of values one column currently holds. `_shape_refusal()`'s input."""
		if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
			return u8_columns[FIELD_STORAGE[field]].size()
		if FIELD_TYPES[field] == CANONICAL_TYPE_I32:
			return i32_columns[FIELD_STORAGE[field]].size()
		return i64_columns[FIELD_STORAGE[field]].size()

	func column_bytes(field: int) -> PackedByteArray:
		"""One column's little-endian wire bytes. C++ conversions, never a per-element loop."""
		if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
			return u8_columns[FIELD_STORAGE[field]].duplicate()
		if FIELD_TYPES[field] == CANONICAL_TYPE_I32:
			return i32_columns[FIELD_STORAGE[field]].to_byte_array()
		return i64_columns[FIELD_STORAGE[field]].to_byte_array()


class EncodeResult:
	"""Outcome of materialising bytes: the buffer, or a refusal and no bytes."""
	var ok: bool = false
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_bytes: PackedByteArray) -> bool:
		"""Record the encoded bytes; always returns true."""
		ok = true
		bytes = p_bytes
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with an empty buffer; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


# --- layout arithmetic ----------------------------------------------------------------------------

static func byte_order_refusal() -> SaveHeader.Refusal:
	"""Prove `Packed*Array.to_byte_array()` is little-endian on this build, for BOTH widths.

	The bulk conversions in `Record.column_bytes()` and `Record.assign_column()` are C++ memory
	copies, not `save_codec.gd` writes, so they inherit the host's byte order instead of the
	codec's explicit little-endian. Every Godot target is little-endian, but an assumption that is
	never checked is how a save written on one machine silently transposes every generation on
	another. Section 8 carries i64 columns as well as i32 ones, so both are probed.
	"""
	var word: PackedByteArray = PackedInt32Array([BYTE_ORDER_PROBE]).to_byte_array()
	var invalid: SaveHeader.Refusal = _probe_refusal(word, SaveCodec.I32_BYTES)
	if not invalid.is_ok():
		return invalid
	var long: PackedByteArray = PackedInt64Array([BYTE_ORDER_PROBE]).to_byte_array()
	return _probe_refusal(long, SaveCodec.I64_BYTES)


static func _probe_refusal(probe: PackedByteArray, width: int) -> SaveHeader.Refusal:
	"""Check one converted sentinel byte by byte against its little-endian reading."""
	if probe.size() != width:
		return SaveHeader.Refusal.new(REFUSE_BYTE_ORDER,
			"a %d-byte value converted to %d bytes" % [width, probe.size()])
	for index: int in width:
		var expected: int = (BYTE_ORDER_PROBE >> (index * 8)) & SaveCodec.UINT8_MAX
		if probe[index] != expected:
			return SaveHeader.Refusal.new(REFUSE_BYTE_ORDER,
				"byte %d of the sentinel is %d, not the little-endian %d"
					% [index, probe[index], expected])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func field_width(field: int) -> int:
	"""Element width of one field, recomputed from its canonical type code."""
	if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
		return SaveCodec.U8_BYTES
	if FIELD_TYPES[field] == CANONICAL_TYPE_I32:
		return SaveCodec.I32_BYTES
	return SaveCodec.I64_BYTES


static func storage_index_of(field: int) -> int:
	"""Recompute one field's index within its type group, so FIELD_STORAGE cannot drift."""
	var index: int = 0
	for earlier: int in field:
		if FIELD_TYPES[earlier] == FIELD_TYPES[field]:
			index += 1
	return index


static func canonical_value_bytes() -> int:
	"""Total VALUE bytes of all 29 columns: the section's ARCH-HASH-001 contribution length."""
	var total: int = 0
	for field: int in FIELD_COUNT:
		total += FIELD_WIDTHS[field] * FIELD_EXTENTS[field]
	return total


static func payload_bytes() -> int:
	"""Total payload length: 29 element counts plus every column's values."""
	return FIELD_COUNT * ELEMENT_COUNT_BYTES + canonical_value_bytes()


static func field_count_offset(field: int) -> int:
	"""Byte offset, from the start of the section, of one field's `element_count:u64`."""
	var offset: int = FRAMING_BYTES
	for earlier: int in field:
		offset += ELEMENT_COUNT_BYTES + FIELD_WIDTHS[earlier] * FIELD_EXTENTS[earlier]
	return offset


static func field_value_offset(field: int) -> int:
	"""Byte offset, from the start of the section, of one field's first value."""
	return field_count_offset(field) + ELEMENT_COUNT_BYTES


static func canonical_type_of(field: int) -> int:
	"""SAVE-R09's type code for one field: 0 for u8, 2 for i32, 4 for i64."""
	return FIELD_TYPES[field]


static func descriptor_row_count() -> int:
	"""The 64-byte descriptor's `row_count` for section 8: the one block's designated primary.

	SAVE-LAYOUT-R01 makes a multi-block section's descriptor row count "the checked sum of block
	primary_count values". Section 8 holds exactly ONE block, so that sum has one term and the
	descriptor is PRIMARY_COUNT. It takes no argument, because SAVE-C3-R01 gives a caller nothing
	to choose; section 9's `descriptor_row_count()` has the same shape for the same reason.
	"""
	return PRIMARY_COUNT


static func primary_count_refusal(primary_count: int) -> SaveHeader.Refusal:
	"""Refuse any `primary_count` but SAVE-C3-R01's designated pending-service extent.

	SAVE-C3-R01: "Writer and decoder must validate against the compiled constant rather than a
	caller-supplied positive number." A positive-and-representable check is NOT enough -- 4096,
	5248 and 14080 are all positive, all representable, and all wrong -- so the comparison is
	against PRIMARY_COUNT itself and the detail names why the plausible alternatives are not it.
	"""
	if primary_count == PRIMARY_COUNT:
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	return SaveHeader.Refusal.new(REFUSE_PRIMARY_COUNT,
		("primary_count %d is not section 8's designated %d pending-service rows. SAVE-C3-R01 "
			+ "designates one primary TABLE per owner block; it is not a sum (%d over all five "
			+ "extents, %d over the three owner capacities), not the secondary %d-row per-plot "
			+ "cycle table, and not the retired 7-row fixture.")
			% [primary_count, PRIMARY_COUNT, SERVICE_ROWS + OWNER_ROWS + ZONE_ROWS + DEMAND_ROWS
				+ HIVE_ROWS, OWNER_ROWS + ZONE_ROWS + HIVE_ROWS, OWNER_ROWS])


static func production_write_refusal() -> SaveHeader.Refusal:
	"""BLOCKER J2, as an explicit refusal a save orchestrator can call before writing a file.

	SAVE-C3-R01 closed BLOCKER J1 and told this lane to "keep production refusal until J2 is
	actually implemented and tested, even after the J1-specific refusal is retired". So the
	refusal stands on the remaining hole and nothing else: the planner publishes no bulk column
	reader or writer, so no live planner state can reach this codec and no section 8 written from
	one would be faithful. Binding the count is not a save.
	"""
	return SaveHeader.Refusal.new(REFUSE_STORE_NO_COLUMN_API,
		("section 8's primary_count is settled at %d, but BLOCKER J2 is not: owner '%s' publishes "
			+ "no copy_job_index_columns_into()/restore_job_index_columns() pair, so its %d "
			+ "service, %d cycle, %d zone, %d demand and %d hive rows cannot be captured from or "
			+ "restored into a live store. Do not write this block into a save file.")
			% [PRIMARY_COUNT, OWNER_KEY, SERVICE_ROWS, OWNER_ROWS, ZONE_ROWS, DEMAND_ROWS,
				HIVE_ROWS])


static func section_length_refusal(byte_length: int) -> SaveHeader.Refusal:
	"""Check a descriptor's declared section length against this schema's fixed size.

	SAVE-R09-004 requires exact block consumption and no trailing bytes; section 8 has one fixed
	length, so a descriptor that disagrees is wrong before a single payload byte is read.
	"""
	if byte_length != SECTION_BYTES:
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"section 8 declares %d bytes, not the fixed %d" % [byte_length, SECTION_BYTES])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- capture --------------------------------------------------------------------------------------

static func capture_record_into(staged: Record, out: Record) -> SaveHeader.Refusal:
	"""Validate a caller-built Record and copy it into `out`, or leave `out` byte-identical.

	The column-level capture, for a caller that already holds 29 columns rather than a live store:
	a fixture, a migration, or the planner owner once BLOCKER J2's bulk reader lands.
	`capture_into()` is the same step against a live planner and is what a save should call.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(staged)
	if not invalid.is_ok():
		return invalid
	out.copy_from(staged)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func capture_into(store: JobPlannerScript, out: Record) -> SaveHeader.Refusal:
	"""BLOCKER J2: refuse, because `job_planner.gd` publishes no faithful bulk column reader.

	Its public readers are gated for the simulation's use -- `service_day_into()` refuses a
	non-daily operation and refuses a FREE row, `service_job_of()` answers NULL_REF unless the row
	is PENDING, the sowing readers address only an owner's SOW row -- so a capture built from them
	would have to SYNTHESISE values it cannot read. This module does not read another module's
	underscore-prefixed columns either. `out` is not touched.
	"""
	return SaveHeader.Refusal.new(REFUSE_STORE_NO_COLUMN_API,
		("job_planner.gd publishes no bulk column reader, so section 8 cannot capture its %d "
			+ "service, %d cycle, %d zone, %d demand and %d hive rows (the store currently holds "
			+ "%d pending services). The planner owner must add a validated "
			+ "copy_job_index_columns_into()/restore_job_index_columns() pair, as entity_directory "
			+ "did under decision 0105 and sim_clock did under RESTORE-R01.")
			% [SERVICE_ROWS, OWNER_ROWS, ZONE_ROWS, DEMAND_ROWS, HIVE_ROWS,
				store.pending_service_count()])


static func apply(record: Record, store: JobPlannerScript) -> SaveHeader.Refusal:
	"""BLOCKER J2: refuse, because `job_planner.gd` publishes no transactional column writer.

	The planner's only mutators are operational -- `confirm_first_planting()`,
	`enable_forage_demand()`, the reconcile and sweep paths -- and every one of them creates Jobs,
	moves counters and consumes gates. None of them can install a saved row, and driving them to
	reach a saved state would re-run the simulation rather than restore it. `record` is validated
	first so a caller learns about an invalid Record before it learns about the blocker.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return invalid
	return SaveHeader.Refusal.new(REFUSE_STORE_NO_COLUMN_API,
		("job_planner.gd publishes no transactional restore_job_index_columns(): its %d operational "
			+ "mutators create Jobs and move counters, so none can publish a saved row into a store "
			+ "currently holding %d pending services. Nothing was written.")
			% [FIELD_COUNT, store.pending_service_count()])


# --- encode ----------------------------------------------------------------------------------------

static func encode_payload(record: Record, out: EncodeResult) -> bool:
	"""Materialise the 363112-byte payload: 29 `element_count:u64` prefixes and their columns.

	Column-major by SAVE-LAYOUT-R01 and in REG-R01's declared ordinal order. Each column is
	appended as one C++ byte-array copy; nothing here walks values one at a time.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var buffer: PackedByteArray = PackedByteArray()
	for field: int in FIELD_COUNT:
		var writer: SaveCodec.Writer = SaveCodec.Writer.new(ELEMENT_COUNT_BYTES)
		writer.write_u64(FIELD_EXTENTS[field])
		if writer.failed():
			return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
		buffer.append_array(writer.to_bytes())
		buffer.append_array(record.column_bytes(field))
	if buffer.size() != PAYLOAD_BYTES:
		return out.refuse(REFUSE_LENGTH,
			"payload encoded %d bytes, not the fixed %d" % [buffer.size(), PAYLOAD_BYTES])
	return out.succeed(buffer)


static func encode_section(record: Record, out: EncodeResult) -> bool:
	"""Materialise a whole section 8: the 39-byte owner wrapper, then the payload.

	The wrapper's `primary_count` is PRIMARY_COUNT and a caller cannot supply another, per
	SAVE-C3-R01. There is deliberately NO `primary_count_refusal(PRIMARY_COUNT)` call here: against
	a compiled constant it could never refuse, and a guard that cannot fire is a guard a mutation
	test cannot kill. A PRIMARY_COUNT outside the u64 domain fails in `writer.write_u64()` instead.
	The `payload_byte_length` field is the ACTUAL encoded body length, measured from the bytes this
	call produced, so the wrapper cannot claim a length the body does not have.
	"""
	var order: SaveHeader.Refusal = byte_order_refusal()
	if not order.is_ok():
		return out.refuse(order.code, order.detail)
	var payload: EncodeResult = EncodeResult.new()
	if not encode_payload(record, payload):
		return out.refuse(payload.refusal, payload.detail)
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(FRAMING_BYTES)
	writer.write_u32(STORE_COUNT)
	writer.write_utf8_u32(OWNER_KEY, OWNER_KEY_MAX_BYTES)
	writer.write_u32(OWNER_SCHEMA_VERSION)
	writer.write_u64(PRIMARY_COUNT)
	writer.write_u64(payload.bytes.size())
	if writer.failed():
		return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
	var buffer: PackedByteArray = writer.to_bytes()
	buffer.append_array(payload.bytes)
	if buffer.size() != SECTION_BYTES:
		return out.refuse(REFUSE_LENGTH,
			"section 8 encoded %d bytes, not the fixed %d" % [buffer.size(), SECTION_BYTES])
	return out.succeed(buffer)


static func canonical_bytes_of(record: Record, out: EncodeResult) -> bool:
	"""This section's contribution to ARCH-HASH-001: 29 columns of VALUES and nothing else.

	Every section-8 field carries `hash: true` in REG-R01's artifact, so no column is saved-but-
	not-hashed the way section 1's host debt is. What the digest does NOT include is framing: the
	store count, the owner wrapper and the 29 `element_count` prefixes are wire shape, not state.
	SAVE-R09's canonical record is `section_id, owner_key, field_key, type, value_count, values`
	and this produces exactly the `values` half of all 29; section 15 owns the record prefixes,
	the concatenation order and the final SHA-256, and none of those is decided here.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var buffer: PackedByteArray = PackedByteArray()
	for field: int in FIELD_COUNT:
		buffer.append_array(record.column_bytes(field))
	if buffer.size() != CANONICAL_VALUE_BYTES:
		return out.refuse(REFUSE_LENGTH,
			"canonical values are %d bytes, not %d" % [buffer.size(), CANONICAL_VALUE_BYTES])
	return out.succeed(buffer)


# --- decode ----------------------------------------------------------------------------------------

static func decode_section_into(bytes: PackedByteArray, offset: int,
		out: Record) -> SaveHeader.Refusal:
	"""Decode section 8 from `offset`, validating everything before `out` is written at all.

	Allocate before consume (decision 0059): the extent is proved, the framing is checked, the 29
	columns land in a LOCAL Record, and every domain and cross-column invariant runs against that
	local. Only then is `out` overwritten. A FULL-LENGTH section carrying a negative generation, a
	PENDING row with no Job or a sowing cycle that disagrees with its cursor therefore leaves `out`
	byte-identical -- the extent gate would catch a truncation long before any of those.

	SAVE-C3-R01: the expectation is the COMPILED CONSTANT, never a caller-supplied number and
	never a column's extent read back out of the body. A wrapper whose `primary_count` word at
	byte 23 disagrees with PRIMARY_COUNT is refused before any column is published, so a section 8
	written under a different reading of the field cannot load as if it agreed.
	"""
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset)
	if not extent.is_ok():
		return extent
	var order: SaveHeader.Refusal = byte_order_refusal()
	if not order.is_ok():
		return order
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var framing: SaveHeader.Refusal = _read_framing(reader)
	if not framing.is_ok():
		return framing
	return _decode_columns_into(bytes, reader, out)


static func _decode_columns_into(bytes: PackedByteArray, reader: SaveCodec.Reader,
		out: Record) -> SaveHeader.Refusal:
	"""Read the 29 columns into a LOCAL Record, validate it, and only then publish it to `out`."""
	var parsed: Record = Record.new()
	var columns: SaveHeader.Refusal = _read_columns(bytes, reader, parsed)
	if not columns.is_ok():
		return columns
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func extent_refusal(bytes: PackedByteArray, offset: int) -> SaveHeader.Refusal:
	"""Prove `SECTION_BYTES` are readable at `offset` without overflowing the addition.

	Public because it is the PRIMARY gate and must be testable on its own, exactly as
	`save_section_directory.gd::extent_refusal()` is: the Reader is bounded too, so a slack extent
	check would still end in a refusal and hide. A load orchestrator can also ask before committing.
	"""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if bytes.size() < SECTION_BYTES or offset > bytes.size() - SECTION_BYTES:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 8 needs %d bytes at offset %d, buffer holds %d"
				% [SECTION_BYTES, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_framing(reader: SaveCodec.Reader) -> SaveHeader.Refusal:
	"""Read and check the 39-byte block header: store count, owner, schema, counts, length."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != STORE_COUNT:
		return SaveHeader.Refusal.new(REFUSE_STORE_COUNT,
			"section 8 declares %d stores, not %d" % [scalar.value, STORE_COUNT])
	var owner: SaveHeader.Refusal = _read_owner(reader)
	if not owner.is_ok():
		return owner
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var count: SaveHeader.Refusal = primary_count_refusal(scalar.value)
	if not count.is_ok():
		return count
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != PAYLOAD_BYTES:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"payload_byte_length %d is not the fixed %d" % [scalar.value, PAYLOAD_BYTES])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_owner(reader: SaveCodec.Reader) -> SaveHeader.Refusal:
	"""Read the owner key and its schema version, refusing any owner but this one."""
	var text: SaveCodec.Text = SaveCodec.Text.new()
	if not reader.read_utf8_u32_into(OWNER_KEY_MAX_BYTES, text):
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY, text.detail)
	if text.value != OWNER_KEY:
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY,
			"section 8 block is owned by '%s', not '%s'" % [text.value, OWNER_KEY])
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != OWNER_SCHEMA_VERSION:
		return SaveHeader.Refusal.new(REFUSE_OWNER_SCHEMA_VERSION,
			"owner schema %d is not the supported %d" % [scalar.value, OWNER_SCHEMA_VERSION])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_columns(bytes: PackedByteArray, reader: SaveCodec.Reader,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read all 29 `element_count` prefixes and their value runs into `parsed`.

	Each prefix is checked against the OWNING SCHEMA'S extent for that field, never against the
	first column's or against whatever the previous prefix said.
	"""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	for field: int in FIELD_COUNT:
		if not reader.read_u64_into(scalar):
			return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
		if scalar.value != FIELD_EXTENTS[field]:
			return SaveHeader.Refusal.new(REFUSE_ELEMENT_COUNT,
				"field %d (%s) declares %d elements, not the schema's %d"
					% [field, FIELD_KEYS[field], scalar.value, FIELD_EXTENTS[field]])
		var start: int = reader.position()
		var end: int = start + FIELD_WIDTHS[field] * FIELD_EXTENTS[field]
		parsed.assign_column(field, bytes.slice(start, end))
		if not reader.seek(end):
			return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- validation -------------------------------------------------------------------------------------

static func record_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every section 8 rule: shape, then column domains, then each table's own invariants."""
	var shape: SaveHeader.Refusal = _shape_refusal(record)
	if not shape.is_ok():
		return shape
	var domain: SaveHeader.Refusal = _domain_refusal(record)
	if not domain.is_ok():
		return domain
	var service: SaveHeader.Refusal = _service_table_refusal(record)
	if not service.is_ok():
		return service
	var demand: SaveHeader.Refusal = _demand_table_refusal(record)
	if not demand.is_ok():
		return demand
	return _hive_table_refusal(record)


static func _shape_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every column must hold exactly its OWN declared extent before anything indexes into it.

	This is where an extent guessed from the first column dies: a `_demand_enabled` column holding
	8192 values instead of the zone table's 128 is refused here, not silently walked.
	"""
	for field: int in FIELD_COUNT:
		if record.column_size(field) != FIELD_EXTENTS[field]:
			return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE,
				"column %s holds %d values, not its declared %d"
					% [FIELD_KEYS[field], record.column_size(field), FIELD_EXTENTS[field]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _domain_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every column's own value domain, independent of any other column."""
	var bytes_invalid: SaveHeader.Refusal = _byte_domain_refusal(record)
	if not bytes_invalid.is_ok():
		return bytes_invalid
	var slots: SaveHeader.Refusal = _slot_domain_refusal(record)
	if not slots.is_ok():
		return slots
	var signs: SaveHeader.Refusal = _non_negative_refusal(record)
	if not signs.is_ok():
		return signs
	var crop: SaveHeader.Refusal = _i32_range_refusal(
		record.i32_column(FIELD_REQUESTED_CROP), NO_CROP, CROP_COUNT - 1,
		FIELD_REQUESTED_CROP, REFUSE_CROP_DOMAIN)
	if not crop.is_ok():
		return crop
	return _quantity_refusal(record)


static func _byte_domain_refusal(record: Record) -> SaveHeader.Refusal:
	"""The eight u8 columns are bounded enums or flags, each by its OWN owning domain count."""
	var fields: Array[int] = [FIELD_STATUS, FIELD_DEMAND_STATUS, FIELD_HIVE_STATUS,
		FIELD_GATE_REASON, FIELD_DEMAND_BLOCKER, FIELD_HIVE_BLOCKER, FIELD_REQUIRES_WATER,
		FIELD_DEMAND_ENABLED]
	var limits: Array[int] = [STATUS_COUNT, STATUS_COUNT, STATUS_COUNT, REASON_COUNT,
		BLOCKER_COUNT, HIVE_BLOCKER_COUNT, 2, 2]
	var codes: Array[StringName] = [REFUSE_STATUS_DOMAIN, REFUSE_STATUS_DOMAIN,
		REFUSE_STATUS_DOMAIN, REFUSE_REASON_DOMAIN, REFUSE_REASON_DOMAIN, REFUSE_REASON_DOMAIN,
		REFUSE_FLAG_DOMAIN, REFUSE_FLAG_DOMAIN]
	for index: int in fields.size():
		var invalid: SaveHeader.Refusal = _byte_range_refusal(record.u8_column(fields[index]),
			limits[index], fields[index], codes[index])
		if not invalid.is_ok():
			return invalid
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _byte_range_refusal(column: PackedByteArray, limit: int, field: int,
		code: StringName) -> SaveHeader.Refusal:
	"""Refuse unless every byte of `column` is below `limit`. `count()` is one C++ pass per value."""
	var counted: int = 0
	for value: int in limit:
		counted += column.count(value)
	if counted != column.size():
		return SaveHeader.Refusal.new(code,
			"%s holds %d of %d bytes outside [0, %d)"
				% [FIELD_KEYS[field], column.size() - counted, column.size(), limit])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _slot_domain_refusal(record: Record) -> SaveHeader.Refusal:
	"""The six DIRECTORY slot columns hold -1 or a slot inside the directory's capacity.

	DIRECTORY, not typed row: these are the `x` of an `EntityRef`, and a value of 4096 would be a
	plausible farm-plot row and an implausible directory slot.
	"""
	for field: int in SLOT_FIELDS:
		var invalid: SaveHeader.Refusal = _i32_range_refusal(record.i32_column(field), NULL_SLOT,
			DIRECTORY_CAPACITY - 1, field, REFUSE_SLOT_DOMAIN)
		if not invalid.is_ok():
			return invalid
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _non_negative_refusal(record: Record) -> SaveHeader.Refusal:
	"""No generation, day or cycle is negative. THE INT32 SIGN TRAP'S GUARD.

	Bytes `00 00 00 80` read as int32 are -2147483648, which no generation, absolute day or field
	cycle can ever be; read as u32 they are a plausible 2147483648. They are read signed and
	refused here. The upper bound needs no separate check: `MAX_FIELD_CYCLE` is 2147483647, which
	is also the largest value an i32 column can hold.
	"""
	for field: int in NON_NEGATIVE_FIELDS:
		var invalid: SaveHeader.Refusal = _i32_range_refusal(record.i32_column(field), 0,
			MAX_INT32, field, REFUSE_NEGATIVE_VALUE)
		if not invalid.is_ok():
			return invalid
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _quantity_refusal(record: Record) -> SaveHeader.Refusal:
	"""Neither milli-unit quantity column may be negative: a negative claim is not a small one."""
	for field: int in QUANTITY_FIELDS:
		var sorted: PackedInt64Array = record.i64_column(field).duplicate()
		sorted.sort()
		if sorted[0] < 0:
			return SaveHeader.Refusal.new(REFUSE_NEGATIVE_VALUE,
				"%s holds %d milli-units; quantities are never negative"
					% [FIELD_KEYS[field], sorted[0]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _i32_range_refusal(column: PackedInt32Array, minimum: int, maximum: int, field: int,
		code: StringName) -> SaveHeader.Refusal:
	"""Refuse unless every value of one i32 column lies in `[minimum, maximum]`.

	Sorting a copy is one C++ call and only the two endpoints matter, so this costs one sort
	instead of a GDScript walk over as many as 8192 values.
	"""
	var sorted: PackedInt32Array = column.duplicate()
	sorted.sort()
	if sorted[0] < minimum:
		return SaveHeader.Refusal.new(code,
			"%s holds %d, below the declared minimum %d" % [FIELD_KEYS[field], sorted[0], minimum])
	if sorted[sorted.size() - 1] > maximum:
		return SaveHeader.Refusal.new(code,
			"%s holds %d, above the declared maximum %d"
				% [FIELD_KEYS[field], sorted[sorted.size() - 1], maximum])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- the pending-service table (8192 rows) and its per-plot cycle history (4096) ---------------------

static func _service_table_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every rule the 8192-row service table and the 4096-row cycle history carry between them."""
	var clear: SaveHeader.Refusal = _clear_table_refusal(record, FIELD_STATUS,
		SERVICE_CLEAR_FIELDS)
	if not clear.is_ok():
		return clear
	var tend: SaveHeader.Refusal = _tend_row_refusal(record)
	if not tend.is_ok():
		return tend
	var days: SaveHeader.Refusal = _sow_day_refusal(record)
	if not days.is_ok():
		return days
	var cycles: SaveHeader.Refusal = _sow_cycle_refusal(record)
	if not cycles.is_ok():
		return cycles
	var references: SaveHeader.Refusal = _service_reference_refusal(record)
	if not references.is_ok():
		return references
	return _cycle_history_refusal(record)


static func _tend_row_refusal(record: Record) -> SaveHeader.Refusal:
	"""A TEND row carries no sowing state, and STATUS_REQUESTED is R06-JOB-004's, never a tend's.

	`_write_requested_row()` writes the cycle, the crop and the REQUESTED status only onto the SOW
	row of an owner, and `_reconcile_sow()` is the only writer of the gate reason. A tend row
	carrying a field cycle is a row whose two operations have been transposed.
	"""
	var status: PackedByteArray = record.u8_column(FIELD_STATUS)
	var cycle: PackedInt32Array = record.i32_column(FIELD_FIELD_CYCLE)
	var crop: PackedInt32Array = record.i32_column(FIELD_REQUESTED_CROP)
	var reason: PackedByteArray = record.u8_column(FIELD_GATE_REASON)
	for owner: int in OWNER_ROWS:
		var row: int = owner * OPERATION_COUNT + OPERATION_FARM_TEND
		if status[row] == STATUS_REQUESTED:
			return SaveHeader.Refusal.new(REFUSE_OPERATION_MISMATCH,
				"tend row %d holds STATUS_REQUESTED, which only a sowing row takes" % row)
		if cycle[row] != NO_CYCLE or crop[row] != NO_CROP:
			return SaveHeader.Refusal.new(REFUSE_OPERATION_MISMATCH,
				"tend row %d holds field cycle %d and crop %d" % [row, cycle[row], crop[row]])
		if reason[row] != 0:
			return SaveHeader.Refusal.new(REFUSE_OPERATION_MISMATCH,
				"tend row %d holds sowing gate reason %d" % [row, reason[row]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _sow_day_refusal(record: Record) -> SaveHeader.Refusal:
	"""A SOW row carries no day: sowing is not a daily service and midnight never settles one.

	`_write_requested_row()` writes NO_DAY explicitly, and both writers of `_serviced_day`
	(`_record_completion()` and `record_service_completed()`) refuse a non-daily operation. A SOW
	row holding a day would be read by a once-per-day test that sowing does not take part in.
	"""
	var service_day: PackedInt32Array = record.i32_column(FIELD_SERVICE_DAY)
	var serviced_day: PackedInt32Array = record.i32_column(FIELD_SERVICED_DAY)
	for owner: int in OWNER_ROWS:
		var row: int = owner * OPERATION_COUNT + OPERATION_FARM_SOW
		if service_day[row] != NO_DAY or serviced_day[row] != NO_DAY:
			return SaveHeader.Refusal.new(REFUSE_OPERATION_MISMATCH,
				"sowing row %d holds service day %d and serviced day %d"
					% [row, service_day[row], serviced_day[row]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _sow_cycle_refusal(record: Record) -> SaveHeader.Refusal:
	"""An outstanding sowing request names the cycle its owner's cursor most recently allocated.

	`_write_requested_row()` sets `_cycle_cursor[owner]` to the cycle it writes, and
	`_outstanding_request_code()` refuses a second confirm while the row is not FREE, so the cursor
	can only advance while the row is free. A non-free row naming an older cycle is a row whose
	cycle was reused -- exactly what "never reuse a field cycle" forbids.
	"""
	var status: PackedByteArray = record.u8_column(FIELD_STATUS)
	var cycle: PackedInt32Array = record.i32_column(FIELD_FIELD_CYCLE)
	var crop: PackedInt32Array = record.i32_column(FIELD_REQUESTED_CROP)
	var cursor: PackedInt32Array = record.i32_column(FIELD_CYCLE_CURSOR)
	for owner: int in OWNER_ROWS:
		var row: int = owner * OPERATION_COUNT + OPERATION_FARM_SOW
		if status[row] == STATUS_FREE:
			continue
		if cycle[row] < JobPlannerScript.FIRST_CYCLE or cycle[row] != cursor[owner]:
			return SaveHeader.Refusal.new(REFUSE_CYCLE_DISAGREES,
				"sowing row %d holds cycle %d, its owner's cursor %d"
					% [row, cycle[row], cursor[owner]])
		if crop[row] < 0 or crop[row] >= CROP_COUNT:
			return SaveHeader.Refusal.new(REFUSE_CROP_DOMAIN,
				"outstanding sowing row %d requests crop %d" % [row, crop[row]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _cycle_history_refusal(record: Record) -> SaveHeader.Refusal:
	"""No plot has completed a cycle its cursor never allocated.

	`_close_sowing_cycle()` copies the row's `_field_cycle` into `_completed_cycle`, and that cycle
	came from the cursor, so completion can never run ahead of allocation.
	"""
	var cursor: PackedInt32Array = record.i32_column(FIELD_CYCLE_CURSOR)
	var completed: PackedInt32Array = record.i32_column(FIELD_COMPLETED_CYCLE)
	for owner: int in OWNER_ROWS:
		if completed[owner] > cursor[owner]:
			return SaveHeader.Refusal.new(REFUSE_CYCLE_RANGE,
				"plot %d completed cycle %d but allocated only %d"
					% [owner, completed[owner], cursor[owner]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _service_reference_refusal(record: Record) -> SaveHeader.Refusal:
	"""Both DIRECTORY references on every service row: shape, presence and Job binding."""
	var status: PackedByteArray = record.u8_column(FIELD_STATUS)
	var owner: SaveHeader.Refusal = _owner_reference_refusal(record, status, FIELD_OWNER_SLOT,
		FIELD_OWNER_GENERATION)
	if not owner.is_ok():
		return owner
	return _job_reference_refusal(record, status, FIELD_JOB_SLOT, FIELD_JOB_GENERATION)


# --- the forage demand tables (128 designations, 640 rows) ------------------------------------------

static func _demand_table_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every rule the 640-row demand table and the 128-row enablement table carry."""
	var clear: SaveHeader.Refusal = _clear_table_refusal(record, FIELD_DEMAND_STATUS,
		DEMAND_CLEAR_FIELDS)
	if not clear.is_ok():
		return clear
	var status: PackedByteArray = record.u8_column(FIELD_DEMAND_STATUS)
	var jobs: SaveHeader.Refusal = _job_reference_refusal(record, status, FIELD_DEMAND_JOB_SLOT,
		FIELD_DEMAND_JOB_GENERATION)
	if not jobs.is_ok():
		return jobs
	var requested: SaveHeader.Refusal = _no_requested_status_refusal(status, FIELD_DEMAND_STATUS)
	if not requested.is_ok():
		return requested
	return _zone_reference_refusal(record)


static func _zone_reference_refusal(record: Record) -> SaveHeader.Refusal:
	"""An enabled designation names the zone `EntityRef` its enablement was recorded against.

	`_write_enabled_demand()` stores both halves, and `_clear_enabled_demand()` keeps them while
	any of the zone's five rows still holds a record. The reverse implication is deliberately NOT
	asserted: a disabled zone may legitimately retain its owner reference.
	"""
	var enabled: PackedByteArray = record.u8_column(FIELD_DEMAND_ENABLED)
	var slot: PackedInt32Array = record.i32_column(FIELD_DEMAND_OWNER_SLOT)
	var generation: PackedInt32Array = record.i32_column(FIELD_DEMAND_OWNER_GENERATION)
	for zone: int in ZONE_ROWS:
		if not _pair_is_shaped(slot[zone], generation[zone]):
			return SaveHeader.Refusal.new(REFUSE_REFERENCE_SHAPE,
				"zone %d holds designation reference (%d, %d)"
					% [zone, slot[zone], generation[zone]])
		if enabled[zone] == 1 and slot[zone] == NULL_SLOT:
			return SaveHeader.Refusal.new(REFUSE_OWNER_MISSING,
				"zone %d has demand enabled with no designation reference" % zone)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- the hive service table (1024 rows) --------------------------------------------------------------

static func _hive_table_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every rule the 1024-row hive service table carries."""
	var clear: SaveHeader.Refusal = _clear_table_refusal(record, FIELD_HIVE_STATUS,
		HIVE_CLEAR_FIELDS)
	if not clear.is_ok():
		return clear
	var status: PackedByteArray = record.u8_column(FIELD_HIVE_STATUS)
	var owner: SaveHeader.Refusal = _owner_reference_refusal(record, status, FIELD_HIVE_OWNER_SLOT,
		FIELD_HIVE_OWNER_GENERATION)
	if not owner.is_ok():
		return owner
	var jobs: SaveHeader.Refusal = _job_reference_refusal(record, status, FIELD_HIVE_JOB_SLOT,
		FIELD_HIVE_JOB_GENERATION)
	if not jobs.is_ok():
		return jobs
	return _no_requested_status_refusal(status, FIELD_HIVE_STATUS)


# --- shared row rules ---------------------------------------------------------------------------------

static func _clear_table_refusal(record: Record, status_field: int,
		clear_fields: Array[int]) -> SaveHeader.Refusal:
	"""Every FREE row of one table holds its declared unused value in every hygiene field.

	`job_planner.gd` publishes this predicate three times -- `service_row_is_clear()`,
	`demand_row_is_clear()`, `hive_service_row_is_clear()` -- for one reason: "a retired row that
	kept a field cycle, an owner reference or a gate reason would hand the row's next occupant
	someone else's identity". The fields each of them deliberately EXCLUDES (the durable
	`_serviced_day`, the retained blocker bytes, the winter feed demand) are excluded here too.
	"""
	var status: PackedByteArray = record.u8_column(status_field)
	for field: int in clear_fields:
		var invalid: SaveHeader.Refusal = _clear_column_refusal(record, status, field)
		if not invalid.is_ok():
			return invalid
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _clear_column_refusal(record: Record, status: PackedByteArray,
		field: int) -> SaveHeader.Refusal:
	"""Route one hygiene column to the loop for its own width."""
	var unused: int = FIELD_UNUSED[field]
	if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
		return _clear_u8_refusal(record.u8_column(field), status, unused, field)
	if FIELD_TYPES[field] == CANONICAL_TYPE_I32:
		return _clear_i32_refusal(record.i32_column(field), status, unused, field)
	return _clear_i64_refusal(record.i64_column(field), status, unused, field)


static func _clear_u8_refusal(column: PackedByteArray, status: PackedByteArray, unused: int,
		field: int) -> SaveHeader.Refusal:
	"""Refuse when a FREE row's u8 hygiene column holds anything but its declared unused value."""
	for row: int in status.size():
		if status[row] == STATUS_FREE and column[row] != unused:
			return SaveHeader.Refusal.new(REFUSE_ROW_NOT_CLEAR,
				"free row %d holds %s = %d, not %d" % [row, FIELD_KEYS[field], column[row], unused])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _clear_i32_refusal(column: PackedInt32Array, status: PackedByteArray, unused: int,
		field: int) -> SaveHeader.Refusal:
	"""Refuse when a FREE row's i32 hygiene column holds anything but its declared unused value."""
	for row: int in status.size():
		if status[row] == STATUS_FREE and column[row] != unused:
			return SaveHeader.Refusal.new(REFUSE_ROW_NOT_CLEAR,
				"free row %d holds %s = %d, not %d" % [row, FIELD_KEYS[field], column[row], unused])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _clear_i64_refusal(column: PackedInt64Array, status: PackedByteArray, unused: int,
		field: int) -> SaveHeader.Refusal:
	"""Refuse when a FREE row's i64 hygiene column holds anything but its declared unused value."""
	for row: int in status.size():
		if status[row] == STATUS_FREE and column[row] != unused:
			return SaveHeader.Refusal.new(REFUSE_ROW_NOT_CLEAR,
				"free row %d holds %s = %d, not %d" % [row, FIELD_KEYS[field], column[row], unused])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _owner_reference_refusal(record: Record, status: PackedByteArray, slot_field: int,
		generation_field: int) -> SaveHeader.Refusal:
	"""A row that is not FREE names the live owner it was written against, in both halves.

	Every writer of a used row stores the owner's full `EntityRef` -- `_write_pending_row()`,
	`_retain_unmet_demand()`, `_write_requested_row()`, `_write_pending_hive_row()` and
	`_retain_unmet_hive_demand()` all call `ref_of()` after the owner was found present -- because
	"a reused typed row can be republished under a different slot carrying the SAME generation
	number", so half a reference is worse than none.
	"""
	var slot: PackedInt32Array = record.i32_column(slot_field)
	var generation: PackedInt32Array = record.i32_column(generation_field)
	for row: int in status.size():
		if not _pair_is_shaped(slot[row], generation[row]):
			return SaveHeader.Refusal.new(REFUSE_REFERENCE_SHAPE,
				"row %d holds %s reference (%d, %d)"
					% [row, FIELD_KEYS[slot_field], slot[row], generation[row]])
		if status[row] != STATUS_FREE and slot[row] == NULL_SLOT:
			return SaveHeader.Refusal.new(REFUSE_OWNER_MISSING,
				"row %d holds status %d with no owner reference" % [row, status[row]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _job_reference_refusal(record: Record, status: PackedByteArray, slot_field: int,
		generation_field: int) -> SaveHeader.Refusal:
	"""Exactly the PENDING rows carry a Job. Every other status carries the null reference.

	PENDING is the only status any writer pairs with a created Job; `_retain_unmet_demand()` and
	`_retain_unmet_demand_row()` null the pair explicitly, and `_write_requested_row()` opens a
	cycle with no Job at all. A PENDING row with no Job is work nothing records; a retired row
	still holding one is a Job nothing will ever cancel.
	"""
	var slot: PackedInt32Array = record.i32_column(slot_field)
	var generation: PackedInt32Array = record.i32_column(generation_field)
	for row: int in status.size():
		if not _pair_is_shaped(slot[row], generation[row]):
			return SaveHeader.Refusal.new(REFUSE_REFERENCE_SHAPE,
				"row %d holds %s reference (%d, %d)"
					% [row, FIELD_KEYS[slot_field], slot[row], generation[row]])
		if (status[row] == STATUS_PENDING) != (slot[row] != NULL_SLOT):
			return SaveHeader.Refusal.new(REFUSE_JOB_BINDING,
				"row %d holds status %d with %s = %d"
					% [row, status[row], FIELD_KEYS[slot_field], slot[row]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _no_requested_status_refusal(status: PackedByteArray,
		field: int) -> SaveHeader.Refusal:
	"""STATUS_REQUESTED belongs to R06-JOB-004's sowing rows and to no other table.

	The demand and hive tables' writers use FREE, PENDING and UNMET only; a REQUESTED byte in
	either would be read by `_settle_existing_demand()` as a status it has no branch for.
	"""
	if status.count(STATUS_REQUESTED) != 0:
		return SaveHeader.Refusal.new(REFUSE_STATUS_DOMAIN,
			"%s holds %d STATUS_REQUESTED bytes, which only a sowing row takes"
				% [FIELD_KEYS[field], status.count(STATUS_REQUESTED)])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _pair_is_shaped(slot: int, generation: int) -> bool:
	"""True when a DIRECTORY reference is either the null pair (-1, 0) or a live (slot, >= 1).

	The domain pass has already bounded the slot to `[-1, DIRECTORY_CAPACITY)` and the generation
	to `[0, 2147483647]`, so agreement between the two halves is all that is left: a slot of -1
	with generation 4, or a real slot with generation 0, is a reference that validates against
	nothing and resolves to something.
	"""
	return (slot == NULL_SLOT) == (generation == NULL_GENERATION)
