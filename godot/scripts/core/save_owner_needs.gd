extends RefCounted
## Owner 9 (`needs`) framed-column validation bridge (NEEDS-S4-VALIDATE-R01 v2, decision 0170).
##
## THREE PUBLIC ENTRY POINTS (ADR 1222 build step 2).
##   * `framed_refusal()` judges one already framed section 4 owner block against the Needs
##     store's own restore rules and returns a `SaveHeader.Refusal`. It constructs no live Needs
##     owner, calls no store, captures nothing and applies nothing.
##   * `capture_into(store, record)` copies the live store's twenty columns through
##     `Needs.copy_columns_into()` and projects them into the record's typed buckets in ordinal
##     order -- the exact inverse of `_project_values()`/`_project_bytes()` below -- then judges
##     the written record with `framed_refusal()`, so a capture can never emit an image apply
##     would refuse. A refused capture leaves the record's contents unspecified.
##   * `apply(record, store)` runs `framed_refusal()` FIRST, then projects the record and calls
##     `Needs.restore_columns()`, which re-runs `columns_refusal()`, writes nothing on refusal and
##     rebuilds both counters. A false maps to a Refusal carrying the store's exact
##     `last_column_refusal()` code.
## None of the three touches a clock, barrier, signal, callback, filesystem, JSON text,
## reflection API or per-row object; the caller owns barrier and restore-order discipline.
##
## GATE ORDER, and what each gate owns:
##   1. a null record                 -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 9  -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`     -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata -> SAVE_COMPONENT_METADATA, with a detail beginning
##      `Needs owner9 metadata:` so gate 4 is distinguishable from gate 3, which shares the
##      code. THE CODE ALONE DOES NOT IDENTIFY WHICH METADATA GATE FIRED.
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED
##   6. explicit projection of all twenty framed columns into one temporary `Needs.Columns`
##   7. `Needs.columns_refusal()`     -> the EXACT unwrapped column code, for example
##      COLUMN_HEALTH_STATUS, with a detail naming owner 9 and that same code.
## Success carries an empty code and an empty detail. The projection is neither returned nor
## retained.
##
## WHAT AN ACCEPTED RESULT DOES NOT CERTIFY. Common-file provenance, agreement with the entity
## directory or the Resident store, Injury agreement, cross-owner saved consistency, complete
## world validity, or permission to install anything into a live store. Bulk capture/apply are
## the two entry points above; the other seventeen owners, total nonfatal status precedence and
## departure production remain outstanding elsewhere.
##
## MEMORY, CONDITIONALLY. The projection SHARES the caller's packed buffers by assignment: no
## `duplicate()` is called here, `_install_columns()` is never reached, and nothing is captured
## from a live owner. Only the existing Needs range helpers duplicate and sort their own private
## temporary copies, so both accepted and refused calls leave every caller array untouched. The
## contract's conservative figure is 135168 bytes; that is allocation arithmetic, not a measured
## resident set. The caller keeps and freezes its record for this synchronous call.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Needs := preload("res://scripts/core/needs.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 9
const OWNER_KEY: String = "needs"
const OWNER_VERSION: int = 2
const OWNER_PRIMARY_COUNT: int = 512
const OWNER_CHILD_EXTENT_COUNT: int = 0
const OWNER_FIELD_COUNT: int = 20
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "Needs owner9 metadata:"

## Owner-local field ordinals, in the registry order `Needs.COLUMN_KEYS` publishes.
const FIELD_PRESENT: int = 0
const FIELD_NEED_VALUE: int = 1
const FIELD_NEED_REMAINDER: int = 2
const FIELD_HEALTH: int = 3
const FIELD_HEALTH_REMAINDER: int = 4
const FIELD_COLD_MILLI_HOURS: int = 5
const FIELD_COLD_REMAINDER: int = 6
const FIELD_STARVING_TICKS: int = 7
const FIELD_DEPARTURE_DAYS: int = 8
const FIELD_STATUS: int = 9
const FIELD_SIZE_CLASS: int = 10
const FIELD_ACTIVITY: int = 11
const FIELD_COMFORT_ENVIRONMENT: int = 12
const FIELD_SOCIAL_PAIRED: int = 13
const FIELD_PURPOSE_SOURCE: int = 14
const FIELD_COLD_ENVIRONMENT: int = 15
const FIELD_CLOTHING_TIER: int = 16
const FIELD_INFIRMARY: int = 17
const FIELD_INJURY_STATE: int = 18
const FIELD_AIRLESS: int = 19
## A capture or apply called without a live store. Bridge-local: no column code applies.
const REFUSE_NULL_STORE: StringName = &"SAVE_COMPONENT_NULL_STORE"


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 9 block against the Needs store's own column rules.

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
	var columns: Needs.Columns = Needs.Columns.new()
	_project_values(record, columns)
	_project_bytes(record, columns)
	var code: StringName = Needs.columns_refusal(columns)
	if code != Needs.REFUSE_NONE:
		return _refuse(code,
			"Needs owner %d refuses this image with column code %s" % [OWNER_INDEX, String(code)])
	return _accept()


static func capture_into(store: Needs, record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Capture the live store's twenty columns into one owner 9 record, then judge the result.

	Gates: a null record, a wrong owner, a null store, the schema and metadata guards, then the
	store's own `copy_columns_into()` (its column code is forwarded), then a typed setter refusal
	(SAVE_COMPONENT_SHAPE), and last `framed_refusal()` over what was written.
	"""
	var target: SaveHeader.Refusal = _target_refusal(record, store)
	if not target.is_ok():
		return target
	var columns: Needs.Columns = Needs.Columns.new()
	if not store.copy_columns_into(columns):
		return _refuse(store.last_column_refusal(), "Needs owner %d capture refused with %s"
			% [OWNER_INDEX, String(store.last_column_refusal())])
	if not _write_values(record, columns) or not _write_bytes(record, columns):
		return _refuse(Section.REFUSE_SHAPE,
			"Needs owner %d capture could not write a column" % OWNER_INDEX)
	return framed_refusal(record)


static func apply(record: Section.FramedOwner, store: Needs) -> SaveHeader.Refusal:
	"""Validate one owner 9 record, then install it into `store`. Refusal writes nothing.

	`framed_refusal()` runs first and its refusal is returned unchanged. The projection shares the
	record's buffers by assignment; `restore_columns()` takes its own private copies.
	"""
	var framed: SaveHeader.Refusal = framed_refusal(record)
	if not framed.is_ok():
		return framed
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Needs store was supplied for owner %d" % OWNER_INDEX)
	var columns: Needs.Columns = Needs.Columns.new()
	_project_values(record, columns)
	_project_bytes(record, columns)
	if not store.restore_columns(columns):
		return _refuse(store.last_column_refusal(), "Needs owner %d restore refused with %s"
			% [OWNER_INDEX, String(store.last_column_refusal())])
	return _accept()


static func _target_refusal(record: Section.FramedOwner, store: Needs) -> SaveHeader.Refusal:
	"""Capture's preflight: record, owner index, store, then the schema and metadata guards."""
	if record == null:
		return _refuse(Section.REFUSE_SHAPE,
			"no framed owner was supplied for owner %d ('%s')" % [OWNER_INDEX, OWNER_KEY])
	if record.owner != OWNER_INDEX:
		return _refuse(Section.REFUSE_OWNER,
			"owner %d was supplied where owner %d ('%s') is required"
				% [record.owner, OWNER_INDEX, OWNER_KEY])
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Needs store was supplied for owner %d" % OWNER_INDEX)
	var schema: SaveHeader.Refusal = Schema.schema_refusal()
	if not schema.is_ok():
		return schema
	return _metadata_refusal()


static func _write_values(record: Section.FramedOwner, columns: Needs.Columns) -> bool:
	"""Ordinals 0-8: write the present flag and every i32/i64 value column into the record."""
	return record.set_u8(FIELD_PRESENT, columns.present) \
		and record.set_i32(FIELD_NEED_VALUE, columns.need_value) \
		and record.set_i64(FIELD_NEED_REMAINDER, columns.need_remainder) \
		and record.set_i32(FIELD_HEALTH, columns.health) \
		and record.set_i64(FIELD_HEALTH_REMAINDER, columns.health_remainder) \
		and record.set_i64(FIELD_COLD_MILLI_HOURS, columns.cold_milli_hours) \
		and record.set_i64(FIELD_COLD_REMAINDER, columns.cold_remainder) \
		and record.set_i64(FIELD_STARVING_TICKS, columns.starving_ticks) \
		and record.set_i32(FIELD_DEPARTURE_DAYS, columns.departure_days)


static func _write_bytes(record: Section.FramedOwner, columns: Needs.Columns) -> bool:
	"""Ordinals 9-19: write the status enum and the ten byte input columns into the record."""
	return record.set_u8(FIELD_STATUS, columns.status) \
		and record.set_u8(FIELD_SIZE_CLASS, columns.size_class) \
		and record.set_u8(FIELD_ACTIVITY, columns.activity) \
		and record.set_u8(FIELD_COMFORT_ENVIRONMENT, columns.comfort_environment) \
		and record.set_u8(FIELD_SOCIAL_PAIRED, columns.social_paired) \
		and record.set_u8(FIELD_PURPOSE_SOURCE, columns.purpose_source) \
		and record.set_u8(FIELD_COLD_ENVIRONMENT, columns.cold_environment) \
		and record.set_u8(FIELD_CLOTHING_TIER, columns.clothing_tier) \
		and record.set_u8(FIELD_INFIRMARY, columns.infirmary) \
		and record.set_u8(FIELD_INJURY_STATE, columns.injury_state) \
		and record.set_u8(FIELD_AIRLESS, columns.airless)


static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Gate 4: this owner's compiled identity and extents, before any per-field comparison."""
	if Schema.owner_key(OWNER_INDEX) != OWNER_KEY \
			or Schema.owner_version(OWNER_INDEX) != OWNER_VERSION:
		return _refuse(Section.REFUSE_METADATA,
			"%s compiled owner '%s' version %d is not '%s' version %d"
				% [METADATA_DETAIL_PREFIX, Schema.owner_key(OWNER_INDEX),
					Schema.owner_version(OWNER_INDEX), OWNER_KEY, OWNER_VERSION])
	if Schema.primary_count(OWNER_INDEX) != OWNER_PRIMARY_COUNT \
			or Schema.child_extent_count(OWNER_INDEX) != OWNER_CHILD_EXTENT_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s %d primaries and %d child extents are not %d and %d"
				% [METADATA_DETAIL_PREFIX, Schema.primary_count(OWNER_INDEX),
					Schema.child_extent_count(OWNER_INDEX), OWNER_PRIMARY_COUNT,
					OWNER_CHILD_EXTENT_COUNT])
	if Schema.field_count(OWNER_INDEX) != OWNER_FIELD_COUNT \
			or Needs.COLUMN_COUNT != OWNER_FIELD_COUNT \
			or Needs.COLUMN_KEYS.size() != OWNER_FIELD_COUNT \
			or Needs.COLUMN_TYPE_CODES.size() != OWNER_FIELD_COUNT \
			or Needs.COLUMN_EXTENTS.size() != OWNER_FIELD_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the schema declares %d fields and Needs publishes %d/%d/%d/%d, not %d"
				% [METADATA_DETAIL_PREFIX, Schema.field_count(OWNER_INDEX), Needs.COLUMN_COUNT,
					Needs.COLUMN_KEYS.size(), Needs.COLUMN_TYPE_CODES.size(),
					Needs.COLUMN_EXTENTS.size(), OWNER_FIELD_COUNT])
	return _field_parity_refusal()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: key, type code and element count, ordinal by ordinal."""
	for field: int in OWNER_FIELD_COUNT:
		if Schema.field_key(OWNER_INDEX, field) != String(Needs.COLUMN_KEYS[field]):
			return _refuse(Section.REFUSE_METADATA, "%s field %d is '%s'; Needs declares '%s'"
				% [METADATA_DETAIL_PREFIX, field, Schema.field_key(OWNER_INDEX, field),
					String(Needs.COLUMN_KEYS[field])])
		if Schema.field_type(OWNER_INDEX, field) != int(Needs.COLUMN_TYPE_CODES[field]):
			return _refuse(Section.REFUSE_METADATA, "%s field %d has type %d; Needs declares %d"
				% [METADATA_DETAIL_PREFIX, field, Schema.field_type(OWNER_INDEX, field),
					int(Needs.COLUMN_TYPE_CODES[field])])
		if Schema.element_count(OWNER_INDEX, field) != int(Needs.COLUMN_EXTENTS[field]):
			return _refuse(Section.REFUSE_METADATA, "%s field %d holds %d values; Needs declares %d"
				% [METADATA_DETAIL_PREFIX, field, Schema.element_count(OWNER_INDEX, field),
					int(Needs.COLUMN_EXTENTS[field])])
	return _accept()


static func _project_values(record: Section.FramedOwner, columns: Needs.Columns) -> void:
	"""Ordinals 0-8: the present flag and every i32/i64 value column, by exact declared type.

	Assignment, never `duplicate()`: the packed buffers stay shared copy-on-write with the
	caller's frozen record, and validation only reads them.
	"""
	columns.present = record.u8_column(FIELD_PRESENT)
	columns.need_value = record.i32_column(FIELD_NEED_VALUE)
	columns.need_remainder = record.i64_column(FIELD_NEED_REMAINDER)
	columns.health = record.i32_column(FIELD_HEALTH)
	columns.health_remainder = record.i64_column(FIELD_HEALTH_REMAINDER)
	columns.cold_milli_hours = record.i64_column(FIELD_COLD_MILLI_HOURS)
	columns.cold_remainder = record.i64_column(FIELD_COLD_REMAINDER)
	columns.starving_ticks = record.i64_column(FIELD_STARVING_TICKS)
	columns.departure_days = record.i32_column(FIELD_DEPARTURE_DAYS)


static func _project_bytes(record: Section.FramedOwner, columns: Needs.Columns) -> void:
	"""Ordinals 9-19: the status enum and the ten byte input columns.

	Every one is assigned explicitly, so an omitted field cannot fall back to a constructor
	default and pass as arbitrary legal wire data.
	"""
	columns.status = record.u8_column(FIELD_STATUS)
	columns.size_class = record.u8_column(FIELD_SIZE_CLASS)
	columns.activity = record.u8_column(FIELD_ACTIVITY)
	columns.comfort_environment = record.u8_column(FIELD_COMFORT_ENVIRONMENT)
	columns.social_paired = record.u8_column(FIELD_SOCIAL_PAIRED)
	columns.purpose_source = record.u8_column(FIELD_PURPOSE_SOURCE)
	columns.cold_environment = record.u8_column(FIELD_COLD_ENVIRONMENT)
	columns.clothing_tier = record.u8_column(FIELD_CLOTHING_TIER)
	columns.infirmary = record.u8_column(FIELD_INFIRMARY)
	columns.injury_state = record.u8_column(FIELD_INJURY_STATE)
	columns.airless = record.u8_column(FIELD_AIRLESS)


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build a refusal carrying an exact code: a section code, or an unwrapped Needs column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
