extends RefCounted
## Owner 15 (`transforms`) framed-column validation bridge (TRANSFORMS-S4-VALIDATE-R01 v1,
## ADR 0173).
##
## ONE PUBLIC ENTRY POINT. `framed_refusal()` judges one already framed section 4 owner block
## against the Transform store's own column rules and returns a `SaveHeader.Refusal`. It never
## constructs a Transforms -- that constructor binds a live EntityDirectory -- or any other
## live owner, consults no Directory, captures nothing, applies nothing, and touches no clock,
## barrier, signal, callback, filesystem, projection, reflection API or per-row object.
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
## uniqueness is not a cross-world contamination detector. Full-file provenance, coordinator
## invocation, bulk capture/apply and the `bound_count` rebuild remain incomplete. AN ALL-ZERO
## FRAME IS A VALID EMPTY TRANSFORM IMAGE.
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
