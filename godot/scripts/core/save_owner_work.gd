extends RefCounted
## Owner 16 (`work`) framed-column validation bridge (WORK-S4-VALIDATE-R01 v1, ADR 0175).
##
## THREE PUBLIC ENTRY POINTS (ADR 1222 build step 2).
##   * `framed_refusal()` judges one already framed section 4 owner block against the Work
##     store's own column rules and returns a `SaveHeader.Refusal`. It builds no live Work owner,
##     calls no store, captures nothing and applies nothing.
##   * `capture_into(store, record)` copies the live store's nine columns through
##     `Work.copy_columns_into()` and projects them into the record's typed buckets in ordinal
##     order, then judges the written record with `framed_refusal()`, so a capture can never emit
##     an image apply would refuse. A refused capture leaves the record's contents unspecified.
##   * `apply(record, store)` runs `framed_refusal()` FIRST, then projects the record and calls
##     `Work.restore_columns()`, which re-runs the same predicate, writes nothing on refusal and
##     rebuilds `_bound_tool_count`. A false maps to a Refusal carrying the store's exact
##     `last_column_refusal()` code.
## None of the three touches a clock, callback, filesystem, projection or per-row object, nor the
## store's WeakRef authorities; the caller owns barrier and restore-order discipline.
##
## GATE ORDER:
##   1. a null record                   -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 16   -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`       -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata and the pinned Work source constants ->
##      SAVE_COMPONENT_METADATA, with a detail beginning `Work owner16 metadata:`
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED
##   6. the nine explicit typed accessors, ordinals 0..7 i32 and ordinal 8 u8
##   7. `Work.columns_refusal()`        -> the EXACT unwrapped column code, for example
##      COLUMN_TOOL_BINDING, in a detail naming owner 16 and carrying no row identity.
## Success carries an empty code and an empty detail.
##
## CANONICAL ORDER PUTS XP BEFORE MEMORY. `Work.state_bytes()` is an existing diagnostic that
## emits memory before XP; it is not a save codec, it is not read here, and its order is not
## changed. A fixture built from it must be remapped explicitly.
##
## WHAT AN ACCEPTED RESULT DOES NOT CERTIFY. This is owner-16 local-domain validation only.
## Saved Work/Gear/Jobs/Inventory/resident identity, claim coherence and duplicate lot or Job
## handles remain downstream obligations. Unbound retained carries, stale saved job history and
## broken bound tools are legal images here. Bulk capture/apply and the `_bound_tool_count`
## rebuild are the two entry points above.
##
## THE METADATA GUARD compares the compiled schema to pinned contract literals and the Work
## source constants to their pinned values. That is not an owner-publication-table parity
## claim; the independent schema generator and the source-capacity audit still prove the
## registry.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Work := preload("res://scripts/core/work.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 16
const OWNER_KEY: String = "work"
const OWNER_VERSION: int = 2
const OWNER_PRIMARY_COUNT: int = 512
const OWNER_CHILD_EXTENT_COUNT: int = 0
const OWNER_FIELD_COUNT: int = 9
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "Work owner16 metadata:"

## Owner-local field ordinals, in the canonical order the predicate's arguments take.
const FIELD_POTENTIAL_REMAINDER: int = 0
const FIELD_XP_REMAINDER: int = 1
const FIELD_MEMORY_TOTAL: int = 2
const FIELD_WEAR_REMAINDER: int = 3
const FIELD_TOOL_LOT_SLOT: int = 4
const FIELD_TOOL_LOT_GENERATION: int = 5
const FIELD_TOOL_JOB_SLOT: int = 6
const FIELD_TOOL_JOB_GENERATION: int = 7
const FIELD_TOOL_BROKEN: int = 8

## The pinned per-field contract: exact owner-local keys and exact element counts.
const FIELD_POTENTIAL_REMAINDER_KEY: String = "_potential_remainder"
const FIELD_XP_REMAINDER_KEY: String = "_xp_remainder"
const FIELD_MEMORY_TOTAL_KEY: String = "_memory_total"
const FIELD_WEAR_REMAINDER_KEY: String = "_wear_remainder"
const FIELD_TOOL_LOT_SLOT_KEY: String = "_tool_lot_slot"
const FIELD_TOOL_LOT_GENERATION_KEY: String = "_tool_lot_generation"
const FIELD_TOOL_JOB_SLOT_KEY: String = "_tool_job_slot"
const FIELD_TOOL_JOB_GENERATION_KEY: String = "_tool_job_generation"
const FIELD_TOOL_BROKEN_KEY: String = "_tool_broken"
const RESIDENT_ELEMENT_COUNT: int = 512
const XP_ELEMENT_COUNT: int = 6144
## A capture or apply called without a live store. Bridge-local: no column code applies.
const REFUSE_NULL_STORE: StringName = &"SAVE_COMPONENT_NULL_STORE"

## The Work source constants this bridge pins as contract before it reads a typed column.
const SOURCE_RESIDENT_CAPACITY: int = 512
const SOURCE_SKILL_COUNT: int = 12
const SOURCE_SKILL_RESERVED_INDEX: int = 3
const SOURCE_WORK_FACTOR_DENOMINATOR: int = 1000
const SOURCE_MILLI_WU_PER_WU: int = 1000
const SOURCE_WEAR_MWU_PER_POINT: int = 10000
const SOURCE_LOT_CAPACITY: int = 16384
const SOURCE_JOB_CAPACITY: int = 8192
const SOURCE_NULL_SLOT: int = -1
const SOURCE_NULL_GENERATION: int = 0


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 16 block against the Work store's own column rules.

	Pure over its argument. See the header for the seven gates, and for everything an accepted
	result deliberately does not certify.
	"""
	if record == null:
		return _refuse(Section.REFUSE_SHAPE,
			"no framed owner was supplied for owner %d ('%s')" % [OWNER_INDEX, OWNER_KEY])
	if record.owner != OWNER_INDEX:
		return _refuse(Section.REFUSE_OWNER,
			"owner %d was supplied where owner %d ('%s') is required"
				% [record.owner, OWNER_INDEX, OWNER_KEY])
	var schema: SaveHeader.Refusal = Schema.schema_refusal()
	if not schema.is_ok():
		return schema
	var metadata: SaveHeader.Refusal = _metadata_refusal()
	if not metadata.is_ok():
		return metadata
	var shape: SaveHeader.Refusal = Section.owner_shape_refusal(record)
	if not shape.is_ok():
		return shape
	var code: StringName = Work.columns_refusal(
		record.i32_column(FIELD_POTENTIAL_REMAINDER), record.i32_column(FIELD_XP_REMAINDER),
		record.i32_column(FIELD_MEMORY_TOTAL), record.i32_column(FIELD_WEAR_REMAINDER),
		record.i32_column(FIELD_TOOL_LOT_SLOT), record.i32_column(FIELD_TOOL_LOT_GENERATION),
		record.i32_column(FIELD_TOOL_JOB_SLOT), record.i32_column(FIELD_TOOL_JOB_GENERATION),
		record.u8_column(FIELD_TOOL_BROKEN))
	if code != Work.REFUSE_NONE:
		return _refuse(code, "Work owner %d refuses this image with column code %s"
			% [OWNER_INDEX, String(code)])
	return _accept()


static func capture_into(store: Work, record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Capture the live store's nine columns into one owner 16 record, then judge the result.

	Gates: a null record, a wrong owner, a null store, the schema and metadata guards, then the
	store's own `copy_columns_into()` (its column code is forwarded), then a typed setter refusal
	(SAVE_COMPONENT_SHAPE), and last `framed_refusal()` over what was written.
	"""
	var target: SaveHeader.Refusal = _target_refusal(record, store)
	if not target.is_ok():
		return target
	var columns: Work.Columns = Work.Columns.new()
	if not store.copy_columns_into(columns):
		return _refuse(store.last_column_refusal(), "Work owner %d capture refused with %s"
			% [OWNER_INDEX, String(store.last_column_refusal())])
	if not (record.set_i32(FIELD_POTENTIAL_REMAINDER, columns.potential_remainder)
			and record.set_i32(FIELD_XP_REMAINDER, columns.xp_remainder)
			and record.set_i32(FIELD_MEMORY_TOTAL, columns.memory_total)
			and record.set_i32(FIELD_WEAR_REMAINDER, columns.wear_remainder)
			and record.set_i32(FIELD_TOOL_LOT_SLOT, columns.tool_lot_slot)
			and record.set_i32(FIELD_TOOL_LOT_GENERATION, columns.tool_lot_generation)
			and record.set_i32(FIELD_TOOL_JOB_SLOT, columns.tool_job_slot)
			and record.set_i32(FIELD_TOOL_JOB_GENERATION, columns.tool_job_generation)
			and record.set_u8(FIELD_TOOL_BROKEN, columns.tool_broken)):
		return _refuse(Section.REFUSE_SHAPE,
			"Work owner %d capture could not write a column" % OWNER_INDEX)
	return framed_refusal(record)


static func apply(record: Section.FramedOwner, store: Work) -> SaveHeader.Refusal:
	"""Validate one owner 16 record, then install it into `store`. Refusal writes nothing.

	`framed_refusal()` runs first and its refusal is returned unchanged. The projection shares the
	record's buffers by assignment; `restore_columns()` takes its own private copies.
	"""
	var framed: SaveHeader.Refusal = framed_refusal(record)
	if not framed.is_ok():
		return framed
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Work store was supplied for owner %d" % OWNER_INDEX)
	var columns: Work.Columns = Work.Columns.new()
	columns.potential_remainder = record.i32_column(FIELD_POTENTIAL_REMAINDER)
	columns.xp_remainder = record.i32_column(FIELD_XP_REMAINDER)
	columns.memory_total = record.i32_column(FIELD_MEMORY_TOTAL)
	columns.wear_remainder = record.i32_column(FIELD_WEAR_REMAINDER)
	columns.tool_lot_slot = record.i32_column(FIELD_TOOL_LOT_SLOT)
	columns.tool_lot_generation = record.i32_column(FIELD_TOOL_LOT_GENERATION)
	columns.tool_job_slot = record.i32_column(FIELD_TOOL_JOB_SLOT)
	columns.tool_job_generation = record.i32_column(FIELD_TOOL_JOB_GENERATION)
	columns.tool_broken = record.u8_column(FIELD_TOOL_BROKEN)
	if not store.restore_columns(columns):
		return _refuse(store.last_column_refusal(), "Work owner %d restore refused with %s"
			% [OWNER_INDEX, String(store.last_column_refusal())])
	return _accept()


static func _target_refusal(record: Section.FramedOwner, store: Work) -> SaveHeader.Refusal:
	"""Capture's preflight: record, owner index, store, then the schema and metadata guards."""
	if record == null:
		return _refuse(Section.REFUSE_SHAPE,
			"no framed owner was supplied for owner %d ('%s')" % [OWNER_INDEX, OWNER_KEY])
	if record.owner != OWNER_INDEX:
		return _refuse(Section.REFUSE_OWNER,
			"owner %d was supplied where owner %d ('%s') is required"
				% [record.owner, OWNER_INDEX, OWNER_KEY])
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Work store was supplied for owner %d" % OWNER_INDEX)
	var schema: SaveHeader.Refusal = Schema.schema_refusal()
	if not schema.is_ok():
		return schema
	return _metadata_refusal()


static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Gate 4: compiled owner identity and extents, then the pinned Work source constants."""
	if Schema.owner_key(OWNER_INDEX) != OWNER_KEY \
			or Schema.owner_version(OWNER_INDEX) != OWNER_VERSION:
		return _refuse(Section.REFUSE_METADATA,
			"%s compiled owner '%s' version %d is not '%s' version %d"
				% [METADATA_DETAIL_PREFIX, Schema.owner_key(OWNER_INDEX),
					Schema.owner_version(OWNER_INDEX), OWNER_KEY, OWNER_VERSION])
	if Schema.primary_count(OWNER_INDEX) != OWNER_PRIMARY_COUNT \
			or Schema.child_extent_count(OWNER_INDEX) != OWNER_CHILD_EXTENT_COUNT \
			or Schema.field_count(OWNER_INDEX) != OWNER_FIELD_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s %d primaries, %d child extents and %d fields are not %d, %d and %d"
				% [METADATA_DETAIL_PREFIX, Schema.primary_count(OWNER_INDEX),
					Schema.child_extent_count(OWNER_INDEX), Schema.field_count(OWNER_INDEX),
					OWNER_PRIMARY_COUNT, OWNER_CHILD_EXTENT_COUNT, OWNER_FIELD_COUNT])
	var source: SaveHeader.Refusal = _source_refusal()
	if not source.is_ok():
		return source
	return _field_parity_refusal()


static func _source_refusal() -> SaveHeader.Refusal:
	"""Gate 4's source half: Work's own capacities, denominators and typed-store bounds.

	Read as constant chains, which construct no collaborator. A source mismatch refuses before
	any typed column is read; the independent capacity audit still owns the registry proof.
	"""
	if Work.RESIDENT_CAPACITY != SOURCE_RESIDENT_CAPACITY \
			or Work.SKILL_COUNT != SOURCE_SKILL_COUNT \
			or Work.SKILL_RESERVED_INDEX != SOURCE_SKILL_RESERVED_INDEX:
		return _refuse(Section.REFUSE_METADATA,
			"%s Work declares %d residents, %d skills and reserved index %d"
				% [METADATA_DETAIL_PREFIX, Work.RESIDENT_CAPACITY, Work.SKILL_COUNT,
					Work.SKILL_RESERVED_INDEX])
	if Work.WORK_FACTOR_DENOMINATOR != SOURCE_WORK_FACTOR_DENOMINATOR \
			or Work.MILLI_WU_PER_WU != SOURCE_MILLI_WU_PER_WU \
			or Work.WEAR_MWU_PER_DURABILITY_POINT != SOURCE_WEAR_MWU_PER_POINT:
		return _refuse(Section.REFUSE_METADATA,
			"%s Work declares denominators %d, %d and %d"
				% [METADATA_DETAIL_PREFIX, Work.WORK_FACTOR_DENOMINATOR, Work.MILLI_WU_PER_WU,
					Work.WEAR_MWU_PER_DURABILITY_POINT])
	if Work.GearScript.LOT_CAPACITY != SOURCE_LOT_CAPACITY \
			or Work.InventoryScript.LOT_CAPACITY != SOURCE_LOT_CAPACITY \
			or Work.GearScript.JOB_CAPACITY != SOURCE_JOB_CAPACITY \
			or Work.JobsScript.JOB_CAPACITY != SOURCE_JOB_CAPACITY:
		return _refuse(Section.REFUSE_METADATA,
			"%s the typed lot/Job bounds are %d/%d, not %d/%d"
				% [METADATA_DETAIL_PREFIX, Work.GearScript.LOT_CAPACITY,
					Work.GearScript.JOB_CAPACITY, SOURCE_LOT_CAPACITY, SOURCE_JOB_CAPACITY])
	if Work.NULL_SLOT != SOURCE_NULL_SLOT \
			or Work.EntityDirectory.NULL_GENERATION != SOURCE_NULL_GENERATION:
		return _refuse(Section.REFUSE_METADATA, "%s the null handle is (%d, %d), not (%d, %d)"
			% [METADATA_DETAIL_PREFIX, Work.NULL_SLOT, Work.EntityDirectory.NULL_GENERATION,
				SOURCE_NULL_SLOT, SOURCE_NULL_GENERATION])
	return _accept()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: nine explicit ordinals, eight i32 columns and one u8 column."""
	var potential: SaveHeader.Refusal = _field_refusal(FIELD_POTENTIAL_REMAINDER,
		FIELD_POTENTIAL_REMAINDER_KEY, Schema.TYPE_I32, RESIDENT_ELEMENT_COUNT)
	if not potential.is_ok():
		return potential
	var xp: SaveHeader.Refusal = _field_refusal(FIELD_XP_REMAINDER, FIELD_XP_REMAINDER_KEY,
		Schema.TYPE_I32, XP_ELEMENT_COUNT)
	if not xp.is_ok():
		return xp
	var memory: SaveHeader.Refusal = _field_refusal(FIELD_MEMORY_TOTAL, FIELD_MEMORY_TOTAL_KEY,
		Schema.TYPE_I32, RESIDENT_ELEMENT_COUNT)
	if not memory.is_ok():
		return memory
	var wear: SaveHeader.Refusal = _field_refusal(FIELD_WEAR_REMAINDER, FIELD_WEAR_REMAINDER_KEY,
		Schema.TYPE_I32, RESIDENT_ELEMENT_COUNT)
	if not wear.is_ok():
		return wear
	var lot_slot: SaveHeader.Refusal = _field_refusal(FIELD_TOOL_LOT_SLOT,
		FIELD_TOOL_LOT_SLOT_KEY, Schema.TYPE_I32, RESIDENT_ELEMENT_COUNT)
	if not lot_slot.is_ok():
		return lot_slot
	var lot_generation: SaveHeader.Refusal = _field_refusal(FIELD_TOOL_LOT_GENERATION,
		FIELD_TOOL_LOT_GENERATION_KEY, Schema.TYPE_I32, RESIDENT_ELEMENT_COUNT)
	if not lot_generation.is_ok():
		return lot_generation
	var job_slot: SaveHeader.Refusal = _field_refusal(FIELD_TOOL_JOB_SLOT,
		FIELD_TOOL_JOB_SLOT_KEY, Schema.TYPE_I32, RESIDENT_ELEMENT_COUNT)
	if not job_slot.is_ok():
		return job_slot
	var job_generation: SaveHeader.Refusal = _field_refusal(FIELD_TOOL_JOB_GENERATION,
		FIELD_TOOL_JOB_GENERATION_KEY, Schema.TYPE_I32, RESIDENT_ELEMENT_COUNT)
	if not job_generation.is_ok():
		return job_generation
	return _field_refusal(FIELD_TOOL_BROKEN, FIELD_TOOL_BROKEN_KEY, Schema.TYPE_U8,
		RESIDENT_ELEMENT_COUNT)


static func _field_refusal(field: int, key: String, type_code: int,
		count: int) -> SaveHeader.Refusal:
	"""One pinned field: its owner-local key, its declared type and its exact extent."""
	if Schema.field_key(OWNER_INDEX, field) != key:
		return _refuse(Section.REFUSE_METADATA, "%s field %d is '%s'; the contract fixes '%s'"
			% [METADATA_DETAIL_PREFIX, field, Schema.field_key(OWNER_INDEX, field), key])
	if Schema.field_type(OWNER_INDEX, field) != type_code:
		return _refuse(Section.REFUSE_METADATA, "%s field %d has type %d; the contract fixes %d"
			% [METADATA_DETAIL_PREFIX, field, Schema.field_type(OWNER_INDEX, field), type_code])
	if Schema.element_count(OWNER_INDEX, field) != count:
		return _refuse(Section.REFUSE_METADATA, "%s field %d holds %d values; the contract fixes %d"
			% [METADATA_DETAIL_PREFIX, field, Schema.element_count(OWNER_INDEX, field), count])
	return _accept()


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build a refusal carrying an exact code: a section code, or a raw Work column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
