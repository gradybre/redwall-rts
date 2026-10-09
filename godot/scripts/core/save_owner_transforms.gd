extends RefCounted
## Owner 15 (`transforms`) framed-column validation bridge (TRANSFORMS-S4-VALIDATE-R01 v1,
## ADR 0173).
##
## THREE PUBLIC ENTRY POINTS (ADR 1222 build step 2).
##   * `framed_refusal()` judges one already framed section 4 owner block against the Transform
##     store's own column rules and returns a `SaveHeader.Refusal`. It never constructs a
##     Transforms -- that constructor binds a live EntityDirectory -- consults no Directory,
##     captures nothing and applies nothing.
##   * `capture_into(store, record)` copies the live store's nine columns through
##     `Transforms.copy_columns_into()` and projects them into the record's i32 bucket in
##     canonical stamp-first order -- the exact inverse of the projection below -- then judges the
##     written record with `framed_refusal()`, so a capture can never emit an image apply would
##     refuse. A refused capture leaves the record's contents unspecified; the caller discards it.
##   * `apply(record, store)` runs `framed_refusal()` FIRST, then projects the record and calls
##     `Transforms.restore_columns()`, which re-runs the same predicate, writes nothing on
##     refusal and rebuilds `bound_count`. A false maps to a Refusal carrying the store's exact
##     `last_column_refusal()` code. Saved binding IDs are carried exactly: their cross-owner
##     identity agreement with the saved Directory is a later whole-world step, not this call's.
## None of the three touches a clock, barrier, signal, callback, filesystem, JSON text,
## reflection API or per-row object; the caller owns barrier and restore-order discipline.
##
## GATE ORDER, and what each gate owns:
##   1. a null record                   -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 15   -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`       -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata  -> SAVE_COMPONENT_METADATA, with a detail beginning
##      `Transforms owner15 metadata:`, because gate 3 shares the code and keeps its own detail.
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED
##   6. the nine explicit i32 accessors, in the predicate's canonical argument order
##   7. `Transforms.columns_refusal()`  -> the EXACT unwrapped column code, for example
##      COLUMN_FREE_ROW, with a detail naming owner 15 and that same code and no row identity.
## Success carries an empty code and an empty detail.
##
## CANONICAL ORDER IS STAMP FIRST. The nine accessors are read in owner-local ordinal order --
## `_bound_persistent_id`, then the eight pose fields. `Transforms.state_bytes()` is an existing
## diagnostic whose stamp comes LAST; it is not a save codec, it is not read here, and its order
## is not changed. A fixture built from it must be remapped explicitly.
##
## NO PROJECTION IS ALLOCATED. The nine accessor values are passed straight into the static
## predicate and share the caller's frozen copy-on-write buffers; only the predicate's single
## private binding copy is duplicated and sorted, and the caller's arrays are never reordered.
## The caller must hold its record frozen for this synchronous read. One framed image is
## 9 * 87552 * 4 = 3151872 logical packed bytes; with that 350208-byte scratch and three
## 65536-byte stream windows the conservative bound is 3698688, inside the existing 6417408
## one-owner allowance. That is arithmetic, not a measured resident set, and no new resident
## allocation row follows from it.
##
## WHAT AN ACCEPTED RESULT DOES NOT CERTIFY. TRANSFORMS-SAVED-IDENTITY separately owns the
## saved section 1 Directory cursor upper bound on positive stamps and same-file saved Directory
## identity; neither is checked here, and legitimate stale stamps must stay acceptable. Local
## uniqueness is not a cross-world contamination detector. Full-file provenance and coordinator
## invocation remain incomplete. Bulk capture/apply and the `bound_count` rebuild are the two
## entry points above; the other owners remain elsewhere. AN ALL-ZERO FRAME IS A VALID EMPTY
## TRANSFORM IMAGE.
##
## THE METADATA GUARD compares the compiled schema to pinned contract literals and to the owner's
## own capacity constant. That is not an owner-publication-table parity claim; the independent
## schema generator and the source-capacity audit still prove the registry.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Transforms := preload("res://scripts/core/transforms.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 15
const OWNER_KEY: String = "transforms"
const OWNER_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 87552
const OWNER_CHILD_EXTENT_COUNT: int = 0
const OWNER_FIELD_COUNT: int = 9
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "Transforms owner15 metadata:"

## Owner-local field ordinals, in the canonical order the predicate's arguments take.
const FIELD_BOUND_PERSISTENT_ID: int = 0
const FIELD_X: int = 1
const FIELD_Y: int = 2
const FIELD_Z: int = 3
const FIELD_YAW: int = 4
const FIELD_PREV_X: int = 5
const FIELD_PREV_Y: int = 6
const FIELD_PREV_Z: int = 7
const FIELD_PREV_YAW: int = 8

## The pinned per-field contract: exact owner-local key, and one shared i32 type and extent.
const FIELD_BOUND_PERSISTENT_ID_KEY: String = "_bound_persistent_id"
const FIELD_X_KEY: String = "_x"
const FIELD_Y_KEY: String = "_y"
const FIELD_Z_KEY: String = "_z"
const FIELD_YAW_KEY: String = "_yaw"
const FIELD_PREV_X_KEY: String = "_prev_x"
const FIELD_PREV_Y_KEY: String = "_prev_y"
const FIELD_PREV_Z_KEY: String = "_prev_z"
const FIELD_PREV_YAW_KEY: String = "_prev_yaw"
const ROW_ELEMENT_COUNT: int = 87552
## A capture or apply called without a live store. Bridge-local: no column code applies.
const REFUSE_NULL_STORE: StringName = &"SAVE_COMPONENT_NULL_STORE"


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 15 block against the Transform store's own column rules.

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
	var code: StringName = Transforms.columns_refusal(
		record.i32_column(FIELD_BOUND_PERSISTENT_ID), record.i32_column(FIELD_X),
		record.i32_column(FIELD_Y), record.i32_column(FIELD_Z),
		record.i32_column(FIELD_YAW), record.i32_column(FIELD_PREV_X),
		record.i32_column(FIELD_PREV_Y), record.i32_column(FIELD_PREV_Z),
		record.i32_column(FIELD_PREV_YAW))
	if code != Transforms.REFUSE_NONE:
		return _refuse(code, "Transforms owner %d refuses this image with column code %s"
			% [OWNER_INDEX, String(code)])
	return _accept()


static func capture_into(store: Transforms, record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Capture the live store's nine columns into one owner 15 record, then judge the result.

	Gates: a null record, a wrong owner, a null store, the schema and metadata guards, then the
	store's own `copy_columns_into()` (its column code is forwarded), then a typed setter refusal
	(SAVE_COMPONENT_SHAPE), and last `framed_refusal()` over what was written.
	"""
	var target: SaveHeader.Refusal = _target_refusal(record, store)
	if not target.is_ok():
		return target
	var columns: Transforms.Columns = Transforms.Columns.new()
	if not store.copy_columns_into(columns):
		return _refuse(store.last_column_refusal(), "Transforms owner %d capture refused with %s"
			% [OWNER_INDEX, String(store.last_column_refusal())])
	if not (record.set_i32(FIELD_BOUND_PERSISTENT_ID, columns.bound_persistent_id)
			and record.set_i32(FIELD_X, columns.x) and record.set_i32(FIELD_Y, columns.y)
			and record.set_i32(FIELD_Z, columns.z) and record.set_i32(FIELD_YAW, columns.yaw)
			and record.set_i32(FIELD_PREV_X, columns.prev_x)
			and record.set_i32(FIELD_PREV_Y, columns.prev_y)
			and record.set_i32(FIELD_PREV_Z, columns.prev_z)
			and record.set_i32(FIELD_PREV_YAW, columns.prev_yaw)):
		return _refuse(Section.REFUSE_SHAPE,
			"Transforms owner %d capture could not write a column" % OWNER_INDEX)
	return framed_refusal(record)


static func apply(record: Section.FramedOwner, store: Transforms) -> SaveHeader.Refusal:
	"""Validate one owner 15 record, then install it into `store`. Refusal writes nothing.

	`framed_refusal()` runs first and its refusal is returned unchanged. The projection shares the
	record's buffers by assignment; `restore_columns()` takes its own private copies.
	"""
	var framed: SaveHeader.Refusal = framed_refusal(record)
	if not framed.is_ok():
		return framed
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Transforms store was supplied for owner %d"
			% OWNER_INDEX)
	var columns: Transforms.Columns = Transforms.Columns.new()
	columns.bound_persistent_id = record.i32_column(FIELD_BOUND_PERSISTENT_ID)
	columns.x = record.i32_column(FIELD_X)
	columns.y = record.i32_column(FIELD_Y)
	columns.z = record.i32_column(FIELD_Z)
	columns.yaw = record.i32_column(FIELD_YAW)
	columns.prev_x = record.i32_column(FIELD_PREV_X)
	columns.prev_y = record.i32_column(FIELD_PREV_Y)
	columns.prev_z = record.i32_column(FIELD_PREV_Z)
	columns.prev_yaw = record.i32_column(FIELD_PREV_YAW)
	if not store.restore_columns(columns):
		return _refuse(store.last_column_refusal(), "Transforms owner %d restore refused with %s"
			% [OWNER_INDEX, String(store.last_column_refusal())])
	return _accept()


static func _target_refusal(record: Section.FramedOwner, store: Transforms) -> SaveHeader.Refusal:
	"""Capture's preflight: record, owner index, store, then the schema and metadata guards."""
	if record == null:
		return _refuse(Section.REFUSE_SHAPE,
			"no framed owner was supplied for owner %d ('%s')" % [OWNER_INDEX, OWNER_KEY])
	if record.owner != OWNER_INDEX:
		return _refuse(Section.REFUSE_OWNER,
			"owner %d was supplied where owner %d ('%s') is required"
				% [record.owner, OWNER_INDEX, OWNER_KEY])
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Transforms store was supplied for owner %d"
			% OWNER_INDEX)
	var schema: SaveHeader.Refusal = Schema.schema_refusal()
	if not schema.is_ok():
		return schema
	return _metadata_refusal()


static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Gate 4: compiled identity and extents, then the owner's own pinned capacity constant."""
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
	if Transforms.TRANSFORM_CAPACITY != OWNER_PRIMARY_COUNT \
			or ROW_ELEMENT_COUNT != OWNER_PRIMARY_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s Transforms declares %d derived rows, not %d"
				% [METADATA_DETAIL_PREFIX, Transforms.TRANSFORM_CAPACITY, OWNER_PRIMARY_COUNT])
	return _field_parity_refusal()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: nine explicit ordinals, each i32 at the exact 87552 extent."""
	var stamp: SaveHeader.Refusal = _field_refusal(FIELD_BOUND_PERSISTENT_ID,
		FIELD_BOUND_PERSISTENT_ID_KEY)
	if not stamp.is_ok():
		return stamp
	var x: SaveHeader.Refusal = _field_refusal(FIELD_X, FIELD_X_KEY)
	if not x.is_ok():
		return x
	var y: SaveHeader.Refusal = _field_refusal(FIELD_Y, FIELD_Y_KEY)
	if not y.is_ok():
		return y
	var z: SaveHeader.Refusal = _field_refusal(FIELD_Z, FIELD_Z_KEY)
	if not z.is_ok():
		return z
	var yaw: SaveHeader.Refusal = _field_refusal(FIELD_YAW, FIELD_YAW_KEY)
	if not yaw.is_ok():
		return yaw
	var prev_x: SaveHeader.Refusal = _field_refusal(FIELD_PREV_X, FIELD_PREV_X_KEY)
	if not prev_x.is_ok():
		return prev_x
	var prev_y: SaveHeader.Refusal = _field_refusal(FIELD_PREV_Y, FIELD_PREV_Y_KEY)
	if not prev_y.is_ok():
		return prev_y
	var prev_z: SaveHeader.Refusal = _field_refusal(FIELD_PREV_Z, FIELD_PREV_Z_KEY)
	if not prev_z.is_ok():
		return prev_z
	return _field_refusal(FIELD_PREV_YAW, FIELD_PREV_YAW_KEY)


static func _field_refusal(field: int, key: String) -> SaveHeader.Refusal:
	"""One pinned field: its owner-local key, its declared i32 type and its exact extent."""
	if Schema.field_key(OWNER_INDEX, field) != key:
		return _refuse(Section.REFUSE_METADATA, "%s field %d is '%s'; the contract fixes '%s'"
			% [METADATA_DETAIL_PREFIX, field, Schema.field_key(OWNER_INDEX, field), key])
	if Schema.field_type(OWNER_INDEX, field) != Schema.TYPE_I32:
		return _refuse(Section.REFUSE_METADATA, "%s field %d has type %d; the contract fixes %d"
			% [METADATA_DETAIL_PREFIX, field, Schema.field_type(OWNER_INDEX, field),
				Schema.TYPE_I32])
	if Schema.element_count(OWNER_INDEX, field) != ROW_ELEMENT_COUNT:
		return _refuse(Section.REFUSE_METADATA, "%s field %d holds %d values; the contract fixes %d"
			% [METADATA_DETAIL_PREFIX, field, Schema.element_count(OWNER_INDEX, field),
				ROW_ELEMENT_COUNT])
	return _accept()


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build a refusal carrying an exact code: a section code, or a raw Transforms column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
