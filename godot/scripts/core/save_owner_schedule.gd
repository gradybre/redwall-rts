extends RefCounted
## Owner 14 (`schedule`) framed-column validation bridge (SCHEDULE-S4-VALIDATE-R01 v1, ADR 0172).
##
## THREE PUBLIC ENTRY POINTS (ADR 1222 build step 2).
##   * `framed_refusal()` judges one already framed section 4 owner block against the Schedule
##     store's own column rules and returns a `SaveHeader.Refusal`. It captures nothing and
##     applies nothing.
##   * `capture_into(store, record)` copies the live store's six columns through
##     `Schedule.copy_columns_into()` and projects them into the record's typed buckets in
##     ordinal order -- the exact inverse of the projection below -- then judges the written
##     record with `framed_refusal()`, so a capture can never emit an image apply would refuse. A
##     refused capture leaves the record's contents unspecified; the caller discards it.
##   * `apply(record, store)` runs `framed_refusal()` FIRST, then projects the record and calls
##     `Schedule.restore_columns()`, which re-runs the same predicate, writes nothing on refusal
##     and rebuilds `present_count`. A false maps to a Refusal carrying the store's exact
##     `last_column_refusal()` code.
## None of the three constructs a Schedule itself -- its constructor allocates a private Needs --
## except the caller's own supplied `store`; none touches a clock, barrier, signal, callback,
## filesystem, catalog compiler, reflection API or per-row object. CatalogIds is deliberately NOT
## preloaded: it already preloads Schedule, and the reverse edge would cycle.
##
## GATE ORDER, and what each gate owns:
##   1. a null record                  -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 14  -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`      -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata -> SAVE_COMPONENT_METADATA, with a detail beginning
##      `Schedule owner14 metadata:`, because gate 3 shares the code and keeps its own detail.
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED
##   6. the six explicit typed accessors, in the predicate's canonical argument order
##   7. `Schedule.columns_refusal()`    -> the EXACT unwrapped column code, for example
##      COLUMN_FREE_ROW, with a detail naming owner 14 and that same code and no row identity.
## Success carries an empty code and an empty detail.
##
## NO PROJECTION IS ALLOCATED. The six accessor values are passed straight into the static
## predicate and share the caller's frozen copy-on-write buffers; nothing is duplicated, sorted,
## substituted or retained, so an accepted and a refused call alike leave every caller array
## untouched. The caller must hold its record frozen for this synchronous read. One framed image
## is 512 + 12288 + 2048 + 2048 + 512 + 512 = 17920 logical packed bytes, already inside the
## caller's streamed owner allowance; native and wrapper overhead is unmeasured.
##
## WHAT AN ACCEPTED RESULT DOES NOT CERTIFY. Section 2 catalog key/ID identity, which
## `catalog_ids.gd` verifies separately and rejects on mismatch; agreement with Needs, the clock
## or any live timetable; lifecycle or barrier publication; migration, which is unwritten;
## full-file provenance; or permission to install anything into a live store. AN ARBITRARY ZERO
## FRAME IS NOT A VALID EMPTY SCHEDULE: an empty image fills hourly and current with ANYTHING,
## so a zero image is refused rather than filled in with defaults. Bulk capture/apply and the
## present_count rebuild are the two entry points above; the other owners remain elsewhere.
##
## THE METADATA GUARD compares the compiled schema to pinned contract literals and to the
## owner's own capacity, hour, activity and template constants. That is not an
## owner-publication-table parity check; the independent schema generator and the
## source-capacity audit still prove the registry against the actual owner declarations.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Schedule := preload("res://scripts/core/schedule.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 14
const OWNER_KEY: String = "schedule"
const OWNER_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 512
const OWNER_CHILD_EXTENT_COUNT: int = 0
const OWNER_FIELD_COUNT: int = 6
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "Schedule owner14 metadata:"

## Owner-local field ordinals, in the canonical order the predicate's arguments take.
const FIELD_PRESENT: int = 0
const FIELD_HOURLY_ACTIVITY: int = 1
const FIELD_TEMPLATE: int = 2
const FIELD_CURRENT_ACTIVITY: int = 3
const FIELD_SLEEP_SATISFIED: int = 4
const FIELD_RESOLVED: int = 5

## The pinned per-field contract: exact owner-local key, type code and element count.
const FIELD_PRESENT_KEY: String = "_present"
const FIELD_HOURLY_ACTIVITY_KEY: String = "_hourly_activity"
const FIELD_TEMPLATE_KEY: String = "_template"
const FIELD_CURRENT_ACTIVITY_KEY: String = "_current_activity"
const FIELD_SLEEP_SATISFIED_KEY: String = "_sleep_satisfied"
const FIELD_RESOLVED_KEY: String = "_resolved"
const ROW_ELEMENT_COUNT: int = 512
const HOURLY_ELEMENT_COUNT: int = 12288
## The owner's own source constants this bridge cross-checks, per the contract.
const OWNER_HOURS_PER_DAY: int = 24
const OWNER_ACTIVITY_COUNT: int = 4
const OWNER_TEMPLATE_COUNT: int = 3
const OWNER_ACTIVITY_ANYTHING: int = 1
## A capture or apply called without a live store. Bridge-local: no column code applies.
const REFUSE_NULL_STORE: StringName = &"SAVE_COMPONENT_NULL_STORE"


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 14 block against the Schedule store's own column rules.

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
	var code: StringName = Schedule.columns_refusal(record.u8_column(FIELD_PRESENT),
		record.u8_column(FIELD_HOURLY_ACTIVITY), record.i32_column(FIELD_TEMPLATE),
		record.i32_column(FIELD_CURRENT_ACTIVITY), record.u8_column(FIELD_SLEEP_SATISFIED),
		record.u8_column(FIELD_RESOLVED))
	if code != Schedule.REFUSE_NONE:
		return _refuse(code, "Schedule owner %d refuses this image with column code %s"
			% [OWNER_INDEX, String(code)])
	return _accept()


static func capture_into(store: Schedule, record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Capture the live store's six columns into one owner 14 record, then judge the result.

	Gates: a null record, a wrong owner, a null store, the schema and metadata guards, then the
	store's own `copy_columns_into()` (its column code is forwarded), then a typed setter refusal
	(SAVE_COMPONENT_SHAPE), and last `framed_refusal()` over what was written.
	"""
	var target: SaveHeader.Refusal = _target_refusal(record, store)
	if not target.is_ok():
		return target
	var columns: Schedule.Columns = Schedule.Columns.new()
	if not store.copy_columns_into(columns):
		return _refuse(store.last_column_refusal(), "Schedule owner %d capture refused with %s"
			% [OWNER_INDEX, String(store.last_column_refusal())])
	if not (record.set_u8(FIELD_PRESENT, columns.present)
			and record.set_u8(FIELD_HOURLY_ACTIVITY, columns.hourly_activity)
			and record.set_i32(FIELD_TEMPLATE, columns.template)
			and record.set_i32(FIELD_CURRENT_ACTIVITY, columns.current_activity)
			and record.set_u8(FIELD_SLEEP_SATISFIED, columns.sleep_satisfied)
			and record.set_u8(FIELD_RESOLVED, columns.resolved)):
		return _refuse(Section.REFUSE_SHAPE,
			"Schedule owner %d capture could not write a column" % OWNER_INDEX)
	return framed_refusal(record)


static func apply(record: Section.FramedOwner, store: Schedule) -> SaveHeader.Refusal:
	"""Validate one owner 14 record, then install it into `store`. Refusal writes nothing.

	`framed_refusal()` runs first and its refusal is returned unchanged. The projection shares the
	record's buffers by assignment; `restore_columns()` takes its own private copies.
	"""
	var framed: SaveHeader.Refusal = framed_refusal(record)
	if not framed.is_ok():
		return framed
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Schedule store was supplied for owner %d"
			% OWNER_INDEX)
	var columns: Schedule.Columns = Schedule.Columns.new()
	columns.present = record.u8_column(FIELD_PRESENT)
	columns.hourly_activity = record.u8_column(FIELD_HOURLY_ACTIVITY)
	columns.template = record.i32_column(FIELD_TEMPLATE)
	columns.current_activity = record.i32_column(FIELD_CURRENT_ACTIVITY)
	columns.sleep_satisfied = record.u8_column(FIELD_SLEEP_SATISFIED)
	columns.resolved = record.u8_column(FIELD_RESOLVED)
	if not store.restore_columns(columns):
		return _refuse(store.last_column_refusal(), "Schedule owner %d restore refused with %s"
			% [OWNER_INDEX, String(store.last_column_refusal())])
	return _accept()


static func _target_refusal(record: Section.FramedOwner, store: Schedule) -> SaveHeader.Refusal:
	"""Capture's preflight: record, owner index, store, then the schema and metadata guards."""
	if record == null:
		return _refuse(Section.REFUSE_SHAPE,
			"no framed owner was supplied for owner %d ('%s')" % [OWNER_INDEX, OWNER_KEY])
	if record.owner != OWNER_INDEX:
		return _refuse(Section.REFUSE_OWNER,
			"owner %d was supplied where owner %d ('%s') is required"
				% [record.owner, OWNER_INDEX, OWNER_KEY])
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Schedule store was supplied for owner %d"
			% OWNER_INDEX)
	var schema: SaveHeader.Refusal = Schema.schema_refusal()
	if not schema.is_ok():
		return schema
	return _metadata_refusal()


static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Gate 4: compiled identity and extents, then the owner's own pinned source constants."""
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
	if Schedule.SCHEDULE_CAPACITY != OWNER_PRIMARY_COUNT \
			or Schedule.HOURS_PER_DAY != OWNER_HOURS_PER_DAY \
			or Schedule.ACTIVITY_COUNT != OWNER_ACTIVITY_COUNT \
			or Schedule.TEMPLATE_COUNT != OWNER_TEMPLATE_COUNT \
			or Schedule.ACTIVITY_ANYTHING != OWNER_ACTIVITY_ANYTHING \
			or HOURLY_ELEMENT_COUNT != OWNER_PRIMARY_COUNT * OWNER_HOURS_PER_DAY:
		return _refuse(Section.REFUSE_METADATA,
			"%s Schedule declares %d rows of %d hours, %d activities and %d templates"
				% [METADATA_DETAIL_PREFIX, Schedule.SCHEDULE_CAPACITY, Schedule.HOURS_PER_DAY,
					Schedule.ACTIVITY_COUNT, Schedule.TEMPLATE_COUNT])
	return _field_parity_refusal()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: six explicit ordinals, each at its exact type and extent."""
	var present: SaveHeader.Refusal = _field_refusal(FIELD_PRESENT, FIELD_PRESENT_KEY,
		Schema.TYPE_U8, ROW_ELEMENT_COUNT)
	if not present.is_ok():
		return present
	var hourly: SaveHeader.Refusal = _field_refusal(FIELD_HOURLY_ACTIVITY,
		FIELD_HOURLY_ACTIVITY_KEY, Schema.TYPE_U8, HOURLY_ELEMENT_COUNT)
	if not hourly.is_ok():
		return hourly
	var template: SaveHeader.Refusal = _field_refusal(FIELD_TEMPLATE, FIELD_TEMPLATE_KEY,
		Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not template.is_ok():
		return template
	var current: SaveHeader.Refusal = _field_refusal(FIELD_CURRENT_ACTIVITY,
		FIELD_CURRENT_ACTIVITY_KEY, Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not current.is_ok():
		return current
	var latch: SaveHeader.Refusal = _field_refusal(FIELD_SLEEP_SATISFIED,
		FIELD_SLEEP_SATISFIED_KEY, Schema.TYPE_U8, ROW_ELEMENT_COUNT)
	if not latch.is_ok():
		return latch
	return _field_refusal(FIELD_RESOLVED, FIELD_RESOLVED_KEY, Schema.TYPE_U8, ROW_ELEMENT_COUNT)


static func _field_refusal(field: int, key: String, type_code: int,
		count: int) -> SaveHeader.Refusal:
	"""One pinned field: its owner-local key, its declared type code and its exact extent."""
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
	"""Build a refusal carrying an exact code: a section code, or a raw Schedule column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
