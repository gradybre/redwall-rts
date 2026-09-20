extends RefCounted
## Owner 13 (`resource_nodes`) framed-column validation bridge
## (RESOURCE-NODES-S4-VALIDATE-R01 v1, ADR 0176).
##
## ONE PUBLIC ENTRY POINT. `framed_refusal()` judges one already framed section 4 owner block
## against the ResourceNode store's own column rules and returns a `SaveHeader.Refusal`. It
## constructs no ResourceNodes, Directory, WorldTileMaps or catalog store, consults no live
## owner, reads no clock, captures nothing, applies nothing, normalises nothing and writes no
## diagnostic.
##
## GATE ORDER:
##   1. a null record                   -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 13   -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`       -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata and the pinned ResourceNodes source constants ->
##      SAVE_COMPONENT_METADATA, with a detail beginning `ResourceNodes owner13 metadata:`
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED
##   6. the ten explicit typed accessors: u8 at ordinals 0 and 6, i64 at 2 and 3, i32 elsewhere
##   7. `ResourceNodes.columns_refusal()` -> the EXACT unwrapped column code, for example
##      COLUMN_STOCK, in a detail naming owner 13 and carrying no row identity.
## Success carries an empty code and an empty detail.
##
## SECTION 1 IS A DIFFERENT BLOCK OF THE SAME NAME. `resource_nodes` also appears in §1 WORLD at
## owner schema version 2, primary count 16384, holding the single `_resource_slot` tile map.
## This bridge is the §4 owner at version 1 with 4096 rows and ten fields. Neither block is ever
## read in place of the other, and the version pin below is what makes confusing them a refusal.
##
## WHAT AN ACCEPTED RESULT DOES NOT CERTIFY. Owner-13 scalar-domain validation only. The saved
## §1 inverse in both directions, the Directory kind/typed-row/reference agreement, unique tile
## and unique reference placement, verified same-file catalog membership of every
## `_resource_id`, bulk restoration, derived counts and full-file provenance all remain
## downstream obligations under RESOURCE-NODES-SAVED-BINDINGS. Duplicate tiles and duplicate
## references are legal images here.
##
## THE METADATA GUARD compares the compiled schema to pinned contract literals and the
## ResourceNodes source constants to their pinned values. That is not an owner-publication-table
## parity claim; the independent schema generator and the source-capacity audit still prove the
## registry. A source mismatch refuses BEFORE any typed column is read.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const ResourceNodes := preload("res://scripts/core/resource_nodes.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 13
const OWNER_KEY: String = "resource_nodes"
const OWNER_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 4096
const OWNER_CHILD_EXTENT_COUNT: int = 0
const OWNER_FIELD_COUNT: int = 10
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "ResourceNodes owner13 metadata:"
## Gate 7's detail prefix. It names the owner and the code, and never a row.
const COLUMN_DETAIL_PREFIX: String = "ResourceNodes owner 13"

## Owner-local field ordinals, in the canonical order the predicate's arguments take.
const FIELD_PRESENT: int = 0
const FIELD_RESOURCE_ID: int = 1
const FIELD_QUANTITY_MILLI: int = 2
const FIELD_CAPACITY_MILLI: int = 3
const FIELD_REGROW_DAYS: int = 4
const FIELD_PLANTED_DAY: int = 5
const FIELD_EXHAUSTED: int = 6
const FIELD_TILE: int = 7
const FIELD_REF_SLOT: int = 8
const FIELD_REF_GENERATION: int = 9

## The pinned per-field contract: exact owner-local keys, and the one exact element count.
const FIELD_PRESENT_KEY: String = "_present"
const FIELD_RESOURCE_ID_KEY: String = "_resource_id"
const FIELD_QUANTITY_MILLI_KEY: String = "_quantity_milli"
const FIELD_CAPACITY_MILLI_KEY: String = "_capacity_milli"
const FIELD_REGROW_DAYS_KEY: String = "_regrow_days"
const FIELD_PLANTED_DAY_KEY: String = "_planted_day"
const FIELD_EXHAUSTED_KEY: String = "_exhausted"
const FIELD_TILE_KEY: String = "_tile"
const FIELD_REF_SLOT_KEY: String = "_ref_slot"
const FIELD_REF_GENERATION_KEY: String = "_ref_generation"
const ROW_ELEMENT_COUNT: int = 4096

## The ResourceNodes source constants this bridge pins as contract before it reads a column.
const SOURCE_ROW_CAPACITY: int = 4096
const SOURCE_MAP_TILES_X: int = 128
const SOURCE_MAP_TILES_Z: int = 128
const SOURCE_TILE_COUNT: int = 16384
const SOURCE_MIN_CALENDAR_DAY: int = 1
const SOURCE_NO_NODE: int = -1
const SOURCE_DIRECTORY_CAPACITY: int = 352418
const SOURCE_NULL_SLOT: int = -1
const SOURCE_NULL_GENERATION: int = 0


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 13 block against the ResourceNode store's own column rules.

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
	var code: StringName = ResourceNodes.columns_refusal(
		record.u8_column(FIELD_PRESENT), record.i32_column(FIELD_RESOURCE_ID),
		record.i64_column(FIELD_QUANTITY_MILLI), record.i64_column(FIELD_CAPACITY_MILLI),
		record.i32_column(FIELD_REGROW_DAYS), record.i32_column(FIELD_PLANTED_DAY),
		record.u8_column(FIELD_EXHAUSTED), record.i32_column(FIELD_TILE),
		record.i32_column(FIELD_REF_SLOT), record.i32_column(FIELD_REF_GENERATION))
	if code != ResourceNodes.REFUSE_NONE:
		return _refuse(code, "%s refuses this image with column code %s"
			% [COLUMN_DETAIL_PREFIX, String(code)])
	return _accept()


static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Gate 4: compiled owner identity and extents, then the pinned ResourceNodes constants."""
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
	"""Gate 4's source half: row capacity, the exterior grid, the calendar floor and the handles.

	Read as constant chains, which construct no collaborator. A mismatch refuses before any
	typed column is read; the independent capacity audit still owns the registry proof.
	"""
	if ResourceNodes.RESOURCE_NODE_CAPACITY != SOURCE_ROW_CAPACITY \
			or ResourceNodes.MAP_TILES_X != SOURCE_MAP_TILES_X \
			or ResourceNodes.MAP_TILES_Z != SOURCE_MAP_TILES_Z \
			or ResourceNodes.TILE_COUNT != SOURCE_TILE_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s ResourceNodes declares %d rows and a %dx%d grid of %d tiles"
				% [METADATA_DETAIL_PREFIX, ResourceNodes.RESOURCE_NODE_CAPACITY,
					ResourceNodes.MAP_TILES_X, ResourceNodes.MAP_TILES_Z,
					ResourceNodes.TILE_COUNT])
	if ResourceNodes.MIN_CALENDAR_DAY != SOURCE_MIN_CALENDAR_DAY \
			or ResourceNodes.NO_NODE != SOURCE_NO_NODE:
		return _refuse(Section.REFUSE_METADATA,
			"%s the calendar floor is %d and the empty tile is %d, not %d and %d"
				% [METADATA_DETAIL_PREFIX, ResourceNodes.MIN_CALENDAR_DAY,
					ResourceNodes.NO_NODE, SOURCE_MIN_CALENDAR_DAY, SOURCE_NO_NODE])
	if ResourceNodes.EntityDirectory.DIRECTORY_CAPACITY != SOURCE_DIRECTORY_CAPACITY:
		return _refuse(Section.REFUSE_METADATA,
			"%s the global directory holds %d slots, not %d"
				% [METADATA_DETAIL_PREFIX,
					ResourceNodes.EntityDirectory.DIRECTORY_CAPACITY, SOURCE_DIRECTORY_CAPACITY])
	if ResourceNodes.EntityDirectory.NULL_SLOT != SOURCE_NULL_SLOT \
			or ResourceNodes.EntityDirectory.NULL_GENERATION != SOURCE_NULL_GENERATION \
			or ResourceNodes.NULL_REF.x != SOURCE_NULL_SLOT \
			or ResourceNodes.NULL_REF.y != SOURCE_NULL_GENERATION:
		return _refuse(Section.REFUSE_METADATA, "%s the null handle is (%d, %d), not (%d, %d)"
			% [METADATA_DETAIL_PREFIX, ResourceNodes.NULL_REF.x, ResourceNodes.NULL_REF.y,
				SOURCE_NULL_SLOT, SOURCE_NULL_GENERATION])
	return _accept()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: ten explicit ordinals, two u8 columns, two i64 and six i32."""
	var head: SaveHeader.Refusal = _field_head_refusal()
	if not head.is_ok():
		return head
	return _field_tail_refusal()


static func _field_head_refusal() -> SaveHeader.Refusal:
	"""Ordinals 0..4: the occupancy byte, the resource id and the two i64 stock columns."""
	var present: SaveHeader.Refusal = _field_refusal(FIELD_PRESENT, FIELD_PRESENT_KEY,
		Schema.TYPE_U8, ROW_ELEMENT_COUNT)
	if not present.is_ok():
		return present
	var resource_id: SaveHeader.Refusal = _field_refusal(FIELD_RESOURCE_ID,
		FIELD_RESOURCE_ID_KEY, Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not resource_id.is_ok():
		return resource_id
	var quantity: SaveHeader.Refusal = _field_refusal(FIELD_QUANTITY_MILLI,
		FIELD_QUANTITY_MILLI_KEY, Schema.TYPE_I64, ROW_ELEMENT_COUNT)
	if not quantity.is_ok():
		return quantity
	var capacity: SaveHeader.Refusal = _field_refusal(FIELD_CAPACITY_MILLI,
		FIELD_CAPACITY_MILLI_KEY, Schema.TYPE_I64, ROW_ELEMENT_COUNT)
	if not capacity.is_ok():
		return capacity
	return _field_refusal(FIELD_REGROW_DAYS, FIELD_REGROW_DAYS_KEY, Schema.TYPE_I32,
		ROW_ELEMENT_COUNT)


static func _field_tail_refusal() -> SaveHeader.Refusal:
	"""Ordinals 5..9: the planting date, the exhaustion byte, the tile and the split reference."""
	var planted: SaveHeader.Refusal = _field_refusal(FIELD_PLANTED_DAY, FIELD_PLANTED_DAY_KEY,
		Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not planted.is_ok():
		return planted
	var exhausted: SaveHeader.Refusal = _field_refusal(FIELD_EXHAUSTED, FIELD_EXHAUSTED_KEY,
		Schema.TYPE_U8, ROW_ELEMENT_COUNT)
	if not exhausted.is_ok():
		return exhausted
	var tile: SaveHeader.Refusal = _field_refusal(FIELD_TILE, FIELD_TILE_KEY, Schema.TYPE_I32,
		ROW_ELEMENT_COUNT)
	if not tile.is_ok():
		return tile
	var ref_slot: SaveHeader.Refusal = _field_refusal(FIELD_REF_SLOT, FIELD_REF_SLOT_KEY,
		Schema.TYPE_I32, ROW_ELEMENT_COUNT)
	if not ref_slot.is_ok():
		return ref_slot
	return _field_refusal(FIELD_REF_GENERATION, FIELD_REF_GENERATION_KEY, Schema.TYPE_I32,
		ROW_ELEMENT_COUNT)


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
	"""Build a refusal carrying an exact code: a section code, or a raw ResourceNodes column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
