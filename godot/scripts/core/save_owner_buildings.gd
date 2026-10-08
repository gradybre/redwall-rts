extends RefCounted
## Owner 0 (`buildings`) column validation bridge (BUILDINGS-S4-VALIDATE-R01 v1, ADR 0183).
##
## `framed_refusal()` judges one already framed section 4 owner block against the Buildings
## store's own cold column predicate and returns a `SaveHeader.Refusal`. It constructs no live
## Buildings store, BuildingDefinitions catalog or EntityDirectory, reads no clock, takes no
## callback, captures nothing, restores nothing and writes no diagnostic.
##
## ADR 1222 step 3 adds the JOINT pair at the end of this file: `capture_into()` / `apply()` move
## the section 4 record, the section 5 Block and the section 6 flag Block through ONE
## `Buildings.copy_columns_into()` / `restore_columns()` call, so the three never half-apply.
##
## GATE ORDER:
##   1. a null record                   -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 0    -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`       -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata and the pinned Buildings source facts ->
##      SAVE_COMPONENT_METADATA, with a detail beginning `Buildings owner0 metadata:`
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED, so the 29 column extents and
##      the 1024/16384/81920 row bounds are proven BEFORE any projection or indexing
##   6. one cold `Buildings.Columns.new(false)` whose TWENTY-NINE canonical typed columns are
##      all assigned explicitly, in declared ordinal order, from the caller's own buffers
##   7. `Buildings.columns_refusal()`   -> the EXACT unwrapped column code, for example
##      COLUMN_ROOM_STATE, wrapped in a detail naming owner 0 and carrying no row identity.
## Success carries an empty code and an empty detail.
##
## THE TWO PREFIXES ARE DELIBERATELY SPELLED DIFFERENTLY. Gate 4 writes
## `Buildings owner0 metadata:` and gate 7 writes `Buildings owner 0 `; ADR 0183's disposition
## M2 states both literals and forbids normalising their spacing. Do not "tidy" either one.
##
## BORROWED, NOT COPIED. `Buildings.Columns.new(false)` returns before a single resize or fill,
## so this bridge assigns the record's already-shaped buffers over the 29 empty members instead
## of allocating a second 3298304-byte owner image beside the one it is judging. Nothing here
## calls `duplicate()`, resizes a packed array, serialises a byte or builds a per-row object.
## The contract's logical envelope -- 3298304 owner value bytes, two 327680-byte largest-field
## allowances and three 65536-byte windows, 4150272 in total -- stays inside the existing
## 6417408 stream allowance. That is allocation arithmetic, not a measured resident set.
##
## SECTION 4 IS NOT SECTIONS 1 OR 5. Local acceptance is not publication: Directory self
## identity, section 5 parent/child chains, the room tile arena, kind counts, section 1 tile
## maps and overlap, mask equality, construction and user links, the loaded tick and common file
## provenance all remain BUILDINGS-SAVED-BINDINGS obligations of `framed_refusal()` alone; the
## joint `apply()` adds the section 5 chains, arena, masks and Directory resolution through
## `Buildings.restore_columns()`. Gameplay occupancy policy and live construction are separate.
##
## ONLY FOUR DIRECT PRELOADS. Catalog, BuildingDefinitions and EntityDirectory are reached
## through the existing Buildings preloads, so this file adds no second path to a catalog.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Buildings := preload("res://scripts/core/buildings.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const ChildSection := preload("res://scripts/core/save_section_child_arenas.gd")
const ChildSchema := preload("res://scripts/core/save_child_arenas_schema.gd")
const AuxSection := preload("res://scripts/core/save_section_auxiliary.gd")
const AuxSchema := preload("res://scripts/core/save_auxiliary_state_schema.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 0
const OWNER_KEY: String = "buildings"
const OWNER_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 1024
## Owner 0 declares TWO independent child extents: 16384 rooms and 81920 furniture rows.
const OWNER_CHILD_EXTENT_COUNT: int = 2
const OWNER_FIELD_COUNT: int = 29
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "Buildings owner0 metadata:"
## Gate 7's detail prefix. It names the owner and the code, and never a row.
const COLUMN_DETAIL_PREFIX: String = "Buildings owner 0 "

## The canonical owner-local field declarations, in registry ordinal order.
const FIELD_KEYS: Array[StringName] = [
	&"_b_present", &"_r_present", &"_f_present", &"_b_type_id",
	&"_b_tier", &"_b_origin_tile", &"_b_rotation", &"_b_state",
	&"_b_condition", &"_b_construction_slot", &"_b_construction_generation", &"_b_interior_id",
	&"_r_type", &"_r_building_slot", &"_r_building_generation", &"_r_tile_offset",
	&"_r_tile_count", &"_r_temperature_tenths", &"_r_furniture_mask", &"_r_occupants",
	&"_r_valid", &"_f_type_id", &"_f_room_slot", &"_f_room_generation",
	&"_f_origin_tile", &"_f_rotation", &"_f_user_slot", &"_f_user_generation",
	&"_f_condition",
]
const FIELD_TYPES: Array[int] = [
	Schema.TYPE_U8, Schema.TYPE_U8, Schema.TYPE_U8, Schema.TYPE_I32,
	Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_U8, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_I32,
]
const FIELD_COUNTS: Array[int] = [
	1024, 16384, 81920, 1024, 1024, 1024, 1024, 1024, 1024, 1024,
	1024, 1024, 16384, 16384, 16384, 16384, 16384, 16384, 16384, 16384,
	16384, 81920, 81920, 81920, 81920, 81920, 81920, 81920, 81920,
]

## Owner-local field ordinals, in the order the canonical registry publishes them.
const FIELD_B_PRESENT: int = 0
const FIELD_R_PRESENT: int = 1
const FIELD_F_PRESENT: int = 2
const FIELD_B_TYPE_ID: int = 3
const FIELD_B_TIER: int = 4
const FIELD_B_ORIGIN_TILE: int = 5
const FIELD_B_ROTATION: int = 6
const FIELD_B_STATE: int = 7
const FIELD_B_CONDITION: int = 8
const FIELD_B_CONSTRUCTION_SLOT: int = 9
const FIELD_B_CONSTRUCTION_GENERATION: int = 10
const FIELD_B_INTERIOR_ID: int = 11
const FIELD_R_TYPE: int = 12
const FIELD_R_BUILDING_SLOT: int = 13
const FIELD_R_BUILDING_GENERATION: int = 14
const FIELD_R_TILE_OFFSET: int = 15
const FIELD_R_TILE_COUNT: int = 16
const FIELD_R_TEMPERATURE_TENTHS: int = 17
const FIELD_R_FURNITURE_MASK: int = 18
const FIELD_R_OCCUPANTS: int = 19
const FIELD_R_VALID: int = 20
const FIELD_F_TYPE_ID: int = 21
const FIELD_F_ROOM_SLOT: int = 22
const FIELD_F_ROOM_GENERATION: int = 23
const FIELD_F_ORIGIN_TILE: int = 24
const FIELD_F_ROTATION: int = 25
const FIELD_F_USER_SLOT: int = 26
const FIELD_F_USER_GENERATION: int = 27
const FIELD_F_CONDITION: int = 28

## The Buildings source constants this bridge pins as contract before it reads a column.
const SOURCE_BUILDING_CAPACITY: int = 1024
const SOURCE_ROOM_CAPACITY: int = 16384
const SOURCE_FURNITURE_CAPACITY: int = 81920
const SOURCE_MAP_TILES_X: int = 128
const SOURCE_MAP_TILES_Z: int = 128
const SOURCE_TILE_COUNT: int = 16384
const SOURCE_ROOM_TILE_LINK_CAPACITY: int = 16384
const SOURCE_ROTATION_COUNT: int = 4
const SOURCE_STATE_COUNT: int = 6
const SOURCE_ROOM_TYPE_COUNT: int = 8
const SOURCE_FURNITURE_KIND_COUNT: int = 9
const SOURCE_NO_ROW: int = -1
const SOURCE_NO_LINK: int = -1
const SOURCE_NO_INTERIOR: int = -1
const SOURCE_NULL_SLOT: int = -1
const SOURCE_NULL_GENERATION: int = 0
const SOURCE_DIRECTORY_CAPACITY: int = 352418
const SOURCE_RESIDENT_LIVING_CAP: int = 256
const SOURCE_BUILDING_DEFINITION_COUNT: int = 30
const SOURCE_FURNITURE_DEFINITION_COUNT: int = 9
const SOURCE_MIN_TIER: int = 1
const SOURCE_TIER_TWO: int = 2
const SOURCE_EMPTY_CATALOG_ID: int = -1
## GDD 4.3's protected BuildingState and RoomType ordinals, pinned exactly.
const SOURCE_STATE_BLUEPRINT: int = 0
const SOURCE_STATE_KEYS: Array[String] = [
	"BLUEPRINT", "BUILDING", "ACTIVE", "PAUSED", "DAMAGED", "DEMOLISHING",
]
const SOURCE_ROOM_TYPE_DORMITORY: int = 0
const SOURCE_ROOM_TYPE_PRIVATE_ROOM: int = 1
const SOURCE_ROOM_TYPE_KITCHEN: int = 2
const SOURCE_ROOM_TYPE_DINING: int = 3
const SOURCE_ROOM_TYPE_COMMON: int = 4
const SOURCE_ROOM_TYPE_INFIRMARY: int = 5
const SOURCE_ROOM_TYPE_PANTRY: int = 6
const SOURCE_ROOM_TYPE_CORRIDOR: int = 7
const SOURCE_ROOM_TYPE_KEYS: Array[String] = [
	"DORMITORY", "PRIVATE_ROOM", "KITCHEN", "DINING",
	"COMMON", "INFIRMARY", "PANTRY", "CORRIDOR",
]
## The fact-row column ordinals and tier-two key order this bridge indexes through.
const SOURCE_B_FOOTPRINT_X: int = 0
const SOURCE_B_FOOTPRINT_Z: int = 1
const SOURCE_B_FIELD_COUNT: int = 10
const SOURCE_F_FLOOR_X: int = 0
const SOURCE_F_FLOOR_Z: int = 1
const SOURCE_F_FIELD_COUNT: int = 4
const SOURCE_TIER_TWO_KEY_COUNT: int = 4
const SOURCE_TIER_TWO_KEYS: Array[String] = ["covered_store", "hall", "residence", "workshop"]

## The immutable source facts, frozen in frozen-source-facts.json and derived by canonical
## catalog ID. Their lengths are pinned before any entry of any of them is read.
const SOURCE_BUILDING_KEY_COUNT: int = 30
const SOURCE_FURNITURE_KEY_COUNT: int = 9
const SOURCE_BUILDING_KEYS: Array[String] = [
	"apiary", "boathouse", "brewery", "cellar", "composter", "covered_store",
	"dirt_path", "dryer", "fence", "fisher_shelter", "forester_lodge", "gate",
	"hall", "infirmary", "kitchen", "lookout", "memorial_garden", "mill",
	"nursery", "open_stockpile", "paved_path", "preserver", "quarry_shed", "residence",
	"saltpan", "stone_wall", "weir", "well", "workbench", "workshop",
]
const SOURCE_BUILDING_FOOTPRINT_X: Array[int] = [
	3, 6, 5, 6, 3, 6, 1, 4, 1, 4, 4, 2, 12, 8, 6,
	2, 4, 5, 4, 4, 1, 5, 4, 10, 4, 1, 4, 2, 3, 6,
]
const SOURCE_BUILDING_FOOTPRINT_Z: Array[int] = [
	3, 4, 4, 6, 3, 6, 1, 3, 1, 3, 4, 1, 10, 8, 6,
	2, 4, 5, 4, 4, 1, 4, 4, 8, 4, 1, 2, 2, 3, 6,
]
const SOURCE_FURNITURE_KEYS: Array[String] = [
	"bed", "decoration", "hearth", "interior_door", "interior_partition",
	"kitchen_bench", "patient_bed", "seat", "shelf",
]
const SOURCE_FURNITURE_FLOOR_X: Array[int] = [1, 1, 2, 0, 0, 2, 1, 1, 1]
const SOURCE_FURNITURE_FLOOR_Z: Array[int] = [1, 1, 1, 0, 0, 1, 1, 1, 1]
const SOURCE_TIER_TWO_TYPE_ID_COUNT: int = 4
const SOURCE_TIER_TWO_TYPE_IDS: Array[int] = [5, 12, 23, 29]


static func framed_refusal(record: Section.FramedOwner,
		flags: AuxSection.Block = null) -> SaveHeader.Refusal:
	"""Judge one framed owner 0 block against the Buildings store's own cold column rules. With
	the section 6 flags block, a present underground Room takes the spatial predicate (ADR 1228)."""
	var preflight: SaveHeader.Refusal = _record_preflight(record)
	if not preflight.is_ok():
		return preflight
	var columns: Buildings.Columns = Buildings.Columns.new(false)
	_project_columns(record, columns)
	var spatial: PackedByteArray = flags.u8_column(AUX_R_SPATIAL_KIND) if flags != null \
		else PackedByteArray()
	var code: StringName = Buildings.columns_refusal(columns, spatial)
	if code != Buildings.REFUSE_NONE:
		return _refuse(code, "%srefuses this image with column code %s"
			% [COLUMN_DETAIL_PREFIX, String(code)])
	return _accept()


static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Gate 4: compiled owner identity and extents, then the pinned Buildings source facts."""
	if Schema.owner_key(OWNER_INDEX) != OWNER_KEY:
		return _refuse(Section.REFUSE_METADATA, "%s compiled owner '%s' is not '%s'"
			% [METADATA_DETAIL_PREFIX, Schema.owner_key(OWNER_INDEX), OWNER_KEY])
	if Schema.owner_version(OWNER_INDEX) != OWNER_VERSION:
		return _refuse(Section.REFUSE_METADATA, "%s compiled owner version %d is not %d"
			% [METADATA_DETAIL_PREFIX, Schema.owner_version(OWNER_INDEX), OWNER_VERSION])
	if Schema.primary_count(OWNER_INDEX) != OWNER_PRIMARY_COUNT:
		return _refuse(Section.REFUSE_METADATA, "%s %d primaries are not %d"
			% [METADATA_DETAIL_PREFIX, Schema.primary_count(OWNER_INDEX), OWNER_PRIMARY_COUNT])
	if Schema.child_extent_count(OWNER_INDEX) != OWNER_CHILD_EXTENT_COUNT:
		return _refuse(Section.REFUSE_METADATA, "%s %d child extents are not %d"
			% [METADATA_DETAIL_PREFIX, Schema.child_extent_count(OWNER_INDEX),
				OWNER_CHILD_EXTENT_COUNT])
	if Schema.child_extent(OWNER_INDEX, 0) != 16384:
		return _refuse(Section.REFUSE_METADATA, "%s the room child extent %d is not %d"
			% [METADATA_DETAIL_PREFIX, Schema.child_extent(OWNER_INDEX, 0), SOURCE_ROOM_CAPACITY])
	if Schema.child_extent(OWNER_INDEX, 1) != 81920:
		return _refuse(Section.REFUSE_METADATA, "%s the furniture child extent %d is not %d"
			% [METADATA_DETAIL_PREFIX, Schema.child_extent(OWNER_INDEX, 1),
				SOURCE_FURNITURE_CAPACITY])
	if Schema.field_count(OWNER_INDEX) != OWNER_FIELD_COUNT:
		return _refuse(Section.REFUSE_METADATA, "%s %d fields are not %d"
			% [METADATA_DETAIL_PREFIX, Schema.field_count(OWNER_INDEX), OWNER_FIELD_COUNT])
	if FIELD_KEYS.size() != OWNER_FIELD_COUNT or FIELD_TYPES.size() != OWNER_FIELD_COUNT \
			or FIELD_COUNTS.size() != OWNER_FIELD_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s this bridge pins %d/%d/%d field declarations, not %d"
				% [METADATA_DETAIL_PREFIX, FIELD_KEYS.size(), FIELD_TYPES.size(),
					FIELD_COUNTS.size(), OWNER_FIELD_COUNT])
	var parity: SaveHeader.Refusal = _field_parity_refusal()
	if not parity.is_ok():
		return parity
	return _source_refusal()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: key, type code and element count, ordinal by ordinal."""
	for field: int in OWNER_FIELD_COUNT:
		if Schema.field_key(OWNER_INDEX, field) != String(FIELD_KEYS[field]):
			return _refuse(Section.REFUSE_METADATA, "%s field %d is '%s'; owner 0 declares '%s'"
				% [METADATA_DETAIL_PREFIX, field, Schema.field_key(OWNER_INDEX, field),
					String(FIELD_KEYS[field])])
		if Schema.field_type(OWNER_INDEX, field) != int(FIELD_TYPES[field]):
			return _refuse(Section.REFUSE_METADATA, "%s field %d has type %d; %d is declared"
				% [METADATA_DETAIL_PREFIX, field, Schema.field_type(OWNER_INDEX, field),
					int(FIELD_TYPES[field])])
		if Schema.element_count(OWNER_INDEX, field) != int(FIELD_COUNTS[field]):
			return _refuse(Section.REFUSE_METADATA, "%s field %d holds %d values; %d are declared"
				% [METADATA_DETAIL_PREFIX, field, Schema.element_count(OWNER_INDEX, field),
					int(FIELD_COUNTS[field])])
	return _accept()


static func _source_refusal() -> SaveHeader.Refusal:
	"""Gate 4's source half: the three capacities and the grid this predicate indexes."""
	if Buildings.BUILDING_CAPACITY != SOURCE_BUILDING_CAPACITY \
			or Buildings.ROOM_CAPACITY != SOURCE_ROOM_CAPACITY \
			or Buildings.FURNITURE_CAPACITY != SOURCE_FURNITURE_CAPACITY:
		return _refuse(Section.REFUSE_METADATA,
			"%s Buildings declares %d/%d/%d rows, not %d/%d/%d"
				% [METADATA_DETAIL_PREFIX, Buildings.BUILDING_CAPACITY, Buildings.ROOM_CAPACITY,
					Buildings.FURNITURE_CAPACITY, SOURCE_BUILDING_CAPACITY, SOURCE_ROOM_CAPACITY,
					SOURCE_FURNITURE_CAPACITY])
	if Buildings.MAP_TILES_X != SOURCE_MAP_TILES_X or Buildings.MAP_TILES_Z != SOURCE_MAP_TILES_Z \
			or Buildings.TILE_COUNT != SOURCE_TILE_COUNT \
			or Buildings.ROOM_TILE_LINK_CAPACITY != SOURCE_ROOM_TILE_LINK_CAPACITY:
		return _refuse(Section.REFUSE_METADATA,
			"%s the %dx%d map, %d tiles and %d room tile links are not %d/%d/%d/%d"
				% [METADATA_DETAIL_PREFIX, Buildings.MAP_TILES_X, Buildings.MAP_TILES_Z,
					Buildings.TILE_COUNT, Buildings.ROOM_TILE_LINK_CAPACITY, SOURCE_MAP_TILES_X,
					SOURCE_MAP_TILES_Z, SOURCE_TILE_COUNT, SOURCE_ROOM_TILE_LINK_CAPACITY])
	if Buildings.ROTATION_COUNT != SOURCE_ROTATION_COUNT \
			or Buildings.STATE_COUNT != SOURCE_STATE_COUNT \
			or Buildings.ROOM_TYPE_COUNT != SOURCE_ROOM_TYPE_COUNT \
			or Buildings.FURNITURE_KIND_COUNT != SOURCE_FURNITURE_KIND_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the rotation, state, room type and furniture kind domains are not %d/%d/%d/%d"
				% [METADATA_DETAIL_PREFIX, SOURCE_ROTATION_COUNT, SOURCE_STATE_COUNT,
					SOURCE_ROOM_TYPE_COUNT, SOURCE_FURNITURE_KIND_COUNT])
	return _source_sentinel_refusal()


static func _source_sentinel_refusal() -> SaveHeader.Refusal:
	"""Gate 4: the owner's sentinels, the global Directory handle and the definition counts."""
	if Buildings.NO_ROW != SOURCE_NO_ROW or Buildings.NO_LINK != SOURCE_NO_LINK \
			or Buildings.NO_INTERIOR != SOURCE_NO_INTERIOR:
		return _refuse(Section.REFUSE_METADATA,
			"%s the row, link and interior sentinels are not %d/%d/%d"
				% [METADATA_DETAIL_PREFIX, SOURCE_NO_ROW, SOURCE_NO_LINK, SOURCE_NO_INTERIOR])
	if Buildings.EntityDirectory.NULL_SLOT != SOURCE_NULL_SLOT \
			or Buildings.EntityDirectory.NULL_GENERATION != SOURCE_NULL_GENERATION \
			or Buildings.EntityDirectory.DIRECTORY_CAPACITY != SOURCE_DIRECTORY_CAPACITY \
			or Buildings.EntityDirectory.RESIDENT_LIVING_CAP != SOURCE_RESIDENT_LIVING_CAP:
		return _refuse(Section.REFUSE_METADATA,
			"%s the null handle is not (%d, %d) over a %d-row Directory capped at %d residents"
				% [METADATA_DETAIL_PREFIX, SOURCE_NULL_SLOT, SOURCE_NULL_GENERATION,
					SOURCE_DIRECTORY_CAPACITY, SOURCE_RESIDENT_LIVING_CAP])
	var definitions_ok: bool = (Buildings.BuildingDefinitions.BUILDING_DEFINITION_COUNT
		== SOURCE_BUILDING_DEFINITION_COUNT
		and Buildings.BuildingDefinitions.FURNITURE_DEFINITION_COUNT
			== SOURCE_FURNITURE_DEFINITION_COUNT
		and Buildings.BuildingDefinitions.MIN_TIER == SOURCE_MIN_TIER
		and Buildings.BuildingDefinitions.TIER_TWO == SOURCE_TIER_TWO)
	if not definitions_ok:
		return _refuse(Section.REFUSE_METADATA,
			"%s the definition counts and tier band are not %d/%d bounded by %d..%d"
				% [METADATA_DETAIL_PREFIX, SOURCE_BUILDING_DEFINITION_COUNT,
					SOURCE_FURNITURE_DEFINITION_COUNT, SOURCE_MIN_TIER, SOURCE_TIER_TWO])
	if Buildings.Catalog.EMPTY_CATALOG_ID != SOURCE_EMPTY_CATALOG_ID:
		return _refuse(Section.REFUSE_METADATA,
			"%s the empty catalog id is %d, not %d"
				% [METADATA_DETAIL_PREFIX, Buildings.Catalog.EMPTY_CATALOG_ID,
					SOURCE_EMPTY_CATALOG_ID])
	return _source_ordinal_refusal()


static func _source_ordinal_refusal() -> SaveHeader.Refusal:
	"""Gate 4: the protected state and room ordinals, and the fact-row columns indexed below."""
	if Buildings.STATE_BLUEPRINT != SOURCE_STATE_BLUEPRINT:
		return _refuse(Section.REFUSE_METADATA, "%s BLUEPRINT is ordinal %d, not %d"
			% [METADATA_DETAIL_PREFIX, Buildings.STATE_BLUEPRINT, SOURCE_STATE_BLUEPRINT])
	var rooms_ok: bool = (Buildings.ROOM_TYPE_DORMITORY == SOURCE_ROOM_TYPE_DORMITORY
		and Buildings.ROOM_TYPE_PRIVATE_ROOM == SOURCE_ROOM_TYPE_PRIVATE_ROOM
		and Buildings.ROOM_TYPE_KITCHEN == SOURCE_ROOM_TYPE_KITCHEN
		and Buildings.ROOM_TYPE_DINING == SOURCE_ROOM_TYPE_DINING
		and Buildings.ROOM_TYPE_COMMON == SOURCE_ROOM_TYPE_COMMON
		and Buildings.ROOM_TYPE_INFIRMARY == SOURCE_ROOM_TYPE_INFIRMARY
		and Buildings.ROOM_TYPE_PANTRY == SOURCE_ROOM_TYPE_PANTRY
		and Buildings.ROOM_TYPE_CORRIDOR == SOURCE_ROOM_TYPE_CORRIDOR)
	if not rooms_ok:
		return _refuse(Section.REFUSE_METADATA,
			"%s the eight protected room ordinals are not the pinned 0..%d numbering"
				% [METADATA_DETAIL_PREFIX, SOURCE_ROOM_TYPE_COUNT - 1])
	var columns_ok: bool = (Buildings.BuildingDefinitions.B_FOOTPRINT_X == SOURCE_B_FOOTPRINT_X
		and Buildings.BuildingDefinitions.B_FOOTPRINT_Z == SOURCE_B_FOOTPRINT_Z
		and Buildings.BuildingDefinitions.B_FIELD_COUNT == SOURCE_B_FIELD_COUNT
		and Buildings.BuildingDefinitions.F_FLOOR_X == SOURCE_F_FLOOR_X
		and Buildings.BuildingDefinitions.F_FLOOR_Z == SOURCE_F_FLOOR_Z
		and Buildings.BuildingDefinitions.F_FIELD_COUNT == SOURCE_F_FIELD_COUNT)
	if not columns_ok:
		return _refuse(Section.REFUSE_METADATA,
			"%s the fact-row columns are not x=%d/z=%d of %d and x=%d/z=%d of %d"
				% [METADATA_DETAIL_PREFIX, SOURCE_B_FOOTPRINT_X, SOURCE_B_FOOTPRINT_Z,
					SOURCE_B_FIELD_COUNT, SOURCE_F_FLOOR_X, SOURCE_F_FLOOR_Z,
					SOURCE_F_FIELD_COUNT])
	return _source_state_refusal()


static func _source_state_refusal() -> SaveHeader.Refusal:
	"""Gate 4: ALL SIX protected BuildingState ordinals, from the compiled catalog dictionary.

	The BLUEPRINT pin above stays. Size, key existence and integer type are proven before any
	id is coerced, so a renumbered or truncated BUILDING_STATE refuses METADATA before gate 5.
	"""
	if SOURCE_STATE_KEYS.size() != SOURCE_STATE_COUNT:
		return _refuse(Section.REFUSE_METADATA, "%s this bridge pins %d state keys, not %d"
			% [METADATA_DETAIL_PREFIX, SOURCE_STATE_KEYS.size(), SOURCE_STATE_COUNT])
	if Buildings.Catalog.BUILDING_STATE.size() != SOURCE_STATE_COUNT:
		return _refuse(Section.REFUSE_METADATA, "%s BUILDING_STATE holds %d states, not %d"
			% [METADATA_DETAIL_PREFIX, Buildings.Catalog.BUILDING_STATE.size(),
				SOURCE_STATE_COUNT])
	for ordinal: int in SOURCE_STATE_COUNT:
		var key: String = SOURCE_STATE_KEYS[ordinal]
		if not Buildings.Catalog.BUILDING_STATE.has(key):
			return _refuse(Section.REFUSE_METADATA, "%s BUILDING_STATE has no '%s' key"
				% [METADATA_DETAIL_PREFIX, key])
		var state_id: Variant = Buildings.Catalog.BUILDING_STATE[key]
		if typeof(state_id) != TYPE_INT or int(state_id) != ordinal:
			return _refuse(Section.REFUSE_METADATA, "%s '%s' is not integer state ordinal %d"
				% [METADATA_DETAIL_PREFIX, key, ordinal])
	return _source_room_type_refusal()


static func _source_room_type_refusal() -> SaveHeader.Refusal:
	"""Gate 4: ALL EIGHT protected RoomType ordinals, from the compiled catalog dictionary.

	The ROOM_TYPE_* alias pins above stay. Size, key existence and integer type are proven
	before any id is coerced, so a renumbered or truncated ROOM_TYPE refuses METADATA here,
	before gate 5 projects or indexes a single column.
	"""
	if SOURCE_ROOM_TYPE_KEYS.size() != SOURCE_ROOM_TYPE_COUNT:
		return _refuse(Section.REFUSE_METADATA, "%s this bridge pins %d room type keys, not %d"
			% [METADATA_DETAIL_PREFIX, SOURCE_ROOM_TYPE_KEYS.size(), SOURCE_ROOM_TYPE_COUNT])
	if Buildings.Catalog.ROOM_TYPE.size() != SOURCE_ROOM_TYPE_COUNT:
		return _refuse(Section.REFUSE_METADATA, "%s ROOM_TYPE holds %d room types, not %d"
			% [METADATA_DETAIL_PREFIX, Buildings.Catalog.ROOM_TYPE.size(),
				SOURCE_ROOM_TYPE_COUNT])
	for ordinal: int in SOURCE_ROOM_TYPE_COUNT:
		var key: String = SOURCE_ROOM_TYPE_KEYS[ordinal]
		if not Buildings.Catalog.ROOM_TYPE.has(key):
			return _refuse(Section.REFUSE_METADATA, "%s ROOM_TYPE has no '%s' key"
				% [METADATA_DETAIL_PREFIX, key])
		var room_id: Variant = Buildings.Catalog.ROOM_TYPE[key]
		if typeof(room_id) != TYPE_INT or int(room_id) != ordinal:
			return _refuse(Section.REFUSE_METADATA, "%s '%s' is not integer room ordinal %d"
				% [METADATA_DETAIL_PREFIX, key, ordinal])
	return _tier_two_refusal()


static func _tier_two_refusal() -> SaveHeader.Refusal:
	"""Gate 4: BAL-CAT-006's four upgradable keys, in order, then every fact-array LENGTH.

	Lengths are pinned before any entry of any array or dictionary is read, so a shortened
	source table refuses METADATA instead of being indexed out of range.
	"""
	if Buildings.BuildingDefinitions.TIER_TWO_KEYS.size() != SOURCE_TIER_TWO_KEY_COUNT:
		return _refuse(Section.REFUSE_METADATA, "%s TIER_TWO_KEYS holds %d keys, not %d"
			% [METADATA_DETAIL_PREFIX, Buildings.BuildingDefinitions.TIER_TWO_KEYS.size(),
				SOURCE_TIER_TWO_KEY_COUNT])
	for entry: int in SOURCE_TIER_TWO_KEY_COUNT:
		if String(Buildings.BuildingDefinitions.TIER_TWO_KEYS[entry]) \
				!= String(SOURCE_TIER_TWO_KEYS[entry]):
			return _refuse(Section.REFUSE_METADATA, "%s tier two key %d is '%s', not '%s'"
				% [METADATA_DETAIL_PREFIX, entry,
					String(Buildings.BuildingDefinitions.TIER_TWO_KEYS[entry]),
					String(SOURCE_TIER_TWO_KEYS[entry])])
	var lengths_ok: bool = (Buildings.COLUMN_BUILDING_KEYS.size() == SOURCE_BUILDING_KEY_COUNT
		and Buildings.COLUMN_BUILDING_FOOTPRINT_X.size() == SOURCE_BUILDING_KEY_COUNT
		and Buildings.COLUMN_BUILDING_FOOTPRINT_Z.size() == SOURCE_BUILDING_KEY_COUNT
		and Buildings.COLUMN_FURNITURE_KEYS.size() == SOURCE_FURNITURE_KEY_COUNT
		and Buildings.COLUMN_FURNITURE_FLOOR_X.size() == SOURCE_FURNITURE_KEY_COUNT
		and Buildings.COLUMN_FURNITURE_FLOOR_Z.size() == SOURCE_FURNITURE_KEY_COUNT
		and Buildings.COLUMN_TIER_TWO_TYPE_IDS.size() == SOURCE_TIER_TWO_TYPE_ID_COUNT)
	if not lengths_ok:
		return _refuse(Section.REFUSE_METADATA,
			"%s the owner fact arrays are not %d/%d/%d/%d/%d/%d/%d entries"
				% [METADATA_DETAIL_PREFIX, SOURCE_BUILDING_KEY_COUNT, SOURCE_BUILDING_KEY_COUNT,
					SOURCE_BUILDING_KEY_COUNT, SOURCE_FURNITURE_KEY_COUNT,
					SOURCE_FURNITURE_KEY_COUNT, SOURCE_FURNITURE_KEY_COUNT,
					SOURCE_TIER_TWO_TYPE_ID_COUNT])
	var dictionaries: SaveHeader.Refusal = _dictionary_size_refusal()
	if not dictionaries.is_ok():
		return dictionaries
	return _building_fact_refusal()


static func _dictionary_size_refusal() -> SaveHeader.Refusal:
	"""Gate 4: the two immutable catalog and fact dictionaries hold exactly 30 and 9 rows."""
	if Buildings.Catalog.BUILDING_DEFINITION.size() != SOURCE_BUILDING_DEFINITION_COUNT \
			or Buildings.BuildingDefinitions.BUILDING_FACTS.size() \
				!= SOURCE_BUILDING_DEFINITION_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the building catalog and fact dictionaries hold %d/%d rows, not %d"
				% [METADATA_DETAIL_PREFIX, Buildings.Catalog.BUILDING_DEFINITION.size(),
					Buildings.BuildingDefinitions.BUILDING_FACTS.size(),
					SOURCE_BUILDING_DEFINITION_COUNT])
	if Buildings.Catalog.FURNITURE_DEFINITION.size() != SOURCE_FURNITURE_DEFINITION_COUNT \
			or Buildings.BuildingDefinitions.FURNITURE_FACTS.size() \
				!= SOURCE_FURNITURE_DEFINITION_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the furniture catalog and fact dictionaries hold %d/%d rows, not %d"
				% [METADATA_DETAIL_PREFIX, Buildings.Catalog.FURNITURE_DEFINITION.size(),
					Buildings.BuildingDefinitions.FURNITURE_FACTS.size(),
					SOURCE_FURNITURE_DEFINITION_COUNT])
	return _accept()


static func _building_fact_refusal() -> SaveHeader.Refusal:
	"""Gate 4: every building key, its canonical id, its fact row and both frozen dimensions."""
	for id: int in SOURCE_BUILDING_KEY_COUNT:
		var key: String = String(SOURCE_BUILDING_KEYS[id])
		if String(Buildings.COLUMN_BUILDING_KEYS[id]) != key:
			return _refuse(Section.REFUSE_METADATA, "%s building key %d is '%s', not '%s'"
				% [METADATA_DETAIL_PREFIX, id, String(Buildings.COLUMN_BUILDING_KEYS[id]), key])
		if not Buildings.Catalog.BUILDING_DEFINITION.has(key) \
				or not Buildings.BuildingDefinitions.BUILDING_FACTS.has(key):
			return _refuse(Section.REFUSE_METADATA,
				"%s '%s' is not both a catalog key and a fact row" % [METADATA_DETAIL_PREFIX, key])
		var catalog_id: Variant = Buildings.Catalog.BUILDING_DEFINITION[key]
		if typeof(catalog_id) != TYPE_INT or int(catalog_id) != id:
			return _refuse(Section.REFUSE_METADATA, "%s '%s' is not integer catalog id %d"
				% [METADATA_DETAIL_PREFIX, key, id])
		var facts: Variant = Buildings.BuildingDefinitions.BUILDING_FACTS[key]
		if typeof(facts) != TYPE_ARRAY or (facts as Array).size() != SOURCE_B_FIELD_COUNT:
			return _refuse(Section.REFUSE_METADATA, "%s '%s' is not a %d-field fact row"
				% [METADATA_DETAIL_PREFIX, key, SOURCE_B_FIELD_COUNT])
		var row: Array = facts as Array
		var size_x: Variant = row[SOURCE_B_FOOTPRINT_X]
		var size_z: Variant = row[SOURCE_B_FOOTPRINT_Z]
		if typeof(size_x) != TYPE_INT or typeof(size_z) != TYPE_INT \
				or int(size_x) != int(SOURCE_BUILDING_FOOTPRINT_X[id]) \
				or int(size_z) != int(SOURCE_BUILDING_FOOTPRINT_Z[id]):
			return _refuse(Section.REFUSE_METADATA,
				"%s '%s' is not the frozen %dx%d integer footprint"
					% [METADATA_DETAIL_PREFIX, key, int(SOURCE_BUILDING_FOOTPRINT_X[id]),
						int(SOURCE_BUILDING_FOOTPRINT_Z[id])])
		if int(Buildings.COLUMN_BUILDING_FOOTPRINT_X[id]) \
				!= int(SOURCE_BUILDING_FOOTPRINT_X[id]) \
				or int(Buildings.COLUMN_BUILDING_FOOTPRINT_Z[id]) \
					!= int(SOURCE_BUILDING_FOOTPRINT_Z[id]):
			return _refuse(Section.REFUSE_METADATA,
				"%s owner footprint %d is not the frozen %dx%d"
					% [METADATA_DETAIL_PREFIX, id, int(SOURCE_BUILDING_FOOTPRINT_X[id]),
						int(SOURCE_BUILDING_FOOTPRINT_Z[id])])
	return _furniture_fact_refusal()


static func _furniture_fact_refusal() -> SaveHeader.Refusal:
	"""Gate 4: every furniture key, id, fact row, frozen floor extent, and the four tier ids."""
	for id: int in SOURCE_FURNITURE_KEY_COUNT:
		var key: String = String(SOURCE_FURNITURE_KEYS[id])
		if String(Buildings.COLUMN_FURNITURE_KEYS[id]) != key:
			return _refuse(Section.REFUSE_METADATA, "%s furniture key %d is '%s', not '%s'"
				% [METADATA_DETAIL_PREFIX, id, String(Buildings.COLUMN_FURNITURE_KEYS[id]), key])
		if not Buildings.Catalog.FURNITURE_DEFINITION.has(key) \
				or not Buildings.BuildingDefinitions.FURNITURE_FACTS.has(key):
			return _refuse(Section.REFUSE_METADATA,
				"%s '%s' is not both a catalog key and a fact row" % [METADATA_DETAIL_PREFIX, key])
		var catalog_id: Variant = Buildings.Catalog.FURNITURE_DEFINITION[key]
		if typeof(catalog_id) != TYPE_INT or int(catalog_id) != id:
			return _refuse(Section.REFUSE_METADATA, "%s '%s' is not integer catalog id %d"
				% [METADATA_DETAIL_PREFIX, key, id])
		var facts: Variant = Buildings.BuildingDefinitions.FURNITURE_FACTS[key]
		if typeof(facts) != TYPE_ARRAY or (facts as Array).size() != SOURCE_F_FIELD_COUNT:
			return _refuse(Section.REFUSE_METADATA, "%s '%s' is not a %d-field fact row"
				% [METADATA_DETAIL_PREFIX, key, SOURCE_F_FIELD_COUNT])
		var row: Array = facts as Array
		var floor_x: Variant = row[SOURCE_F_FLOOR_X]
		var floor_z: Variant = row[SOURCE_F_FLOOR_Z]
		if typeof(floor_x) != TYPE_INT or typeof(floor_z) != TYPE_INT \
				or int(floor_x) != int(SOURCE_FURNITURE_FLOOR_X[id]) \
				or int(floor_z) != int(SOURCE_FURNITURE_FLOOR_Z[id]):
			return _refuse(Section.REFUSE_METADATA,
				"%s '%s' is not the frozen %dx%d integer floor footprint"
					% [METADATA_DETAIL_PREFIX, key, int(SOURCE_FURNITURE_FLOOR_X[id]),
						int(SOURCE_FURNITURE_FLOOR_Z[id])])
		if int(Buildings.COLUMN_FURNITURE_FLOOR_X[id]) != int(SOURCE_FURNITURE_FLOOR_X[id]) \
				or int(Buildings.COLUMN_FURNITURE_FLOOR_Z[id]) \
					!= int(SOURCE_FURNITURE_FLOOR_Z[id]):
			return _refuse(Section.REFUSE_METADATA,
				"%s owner floor footprint %d is not the frozen %dx%d"
					% [METADATA_DETAIL_PREFIX, id, int(SOURCE_FURNITURE_FLOOR_X[id]),
						int(SOURCE_FURNITURE_FLOOR_Z[id])])
	for entry: int in SOURCE_TIER_TWO_TYPE_ID_COUNT:
		if int(Buildings.COLUMN_TIER_TWO_TYPE_IDS[entry]) \
				!= int(SOURCE_TIER_TWO_TYPE_IDS[entry]):
			return _refuse(Section.REFUSE_METADATA, "%s tier two id %d is %d, not %d"
				% [METADATA_DETAIL_PREFIX, entry, int(Buildings.COLUMN_TIER_TWO_TYPE_IDS[entry]),
					int(SOURCE_TIER_TWO_TYPE_IDS[entry])])
	return _accept()


static func _project_columns(record: Section.FramedOwner, out: Buildings.Columns) -> void:
	"""Ordinals 0..28: the borrowed 1024/16384/81920 image, every column assigned explicitly.

	`out` arrives from `Buildings.Columns.new(false)`, so all 29 members are empty typed arrays
	until this function binds the record's own buffers. No duplicate, resize, fill or new
	buffer happens here, and no live Buildings, Definitions or Directory is ever constructed.
	"""
	out.b_present = record.u8_column(FIELD_B_PRESENT)
	out.r_present = record.u8_column(FIELD_R_PRESENT)
	out.f_present = record.u8_column(FIELD_F_PRESENT)
	out.b_type_id = record.i32_column(FIELD_B_TYPE_ID)
	out.b_tier = record.i32_column(FIELD_B_TIER)
	out.b_origin_tile = record.i32_column(FIELD_B_ORIGIN_TILE)
	out.b_rotation = record.i32_column(FIELD_B_ROTATION)
	out.b_state = record.i32_column(FIELD_B_STATE)
	out.b_condition = record.i32_column(FIELD_B_CONDITION)
	out.b_construction_slot = record.i32_column(FIELD_B_CONSTRUCTION_SLOT)
	out.b_construction_generation = record.i32_column(FIELD_B_CONSTRUCTION_GENERATION)
	out.b_interior_id = record.i32_column(FIELD_B_INTERIOR_ID)
	out.r_type = record.i32_column(FIELD_R_TYPE)
	out.r_building_slot = record.i32_column(FIELD_R_BUILDING_SLOT)
	out.r_building_generation = record.i32_column(FIELD_R_BUILDING_GENERATION)
	out.r_tile_offset = record.i32_column(FIELD_R_TILE_OFFSET)
	out.r_tile_count = record.i32_column(FIELD_R_TILE_COUNT)
	out.r_temperature_tenths = record.i32_column(FIELD_R_TEMPERATURE_TENTHS)
	out.r_furniture_mask = record.i32_column(FIELD_R_FURNITURE_MASK)
	out.r_occupants = record.i32_column(FIELD_R_OCCUPANTS)
	out.r_valid = record.u8_column(FIELD_R_VALID)
	out.f_type_id = record.i32_column(FIELD_F_TYPE_ID)
	out.f_room_slot = record.i32_column(FIELD_F_ROOM_SLOT)
	out.f_room_generation = record.i32_column(FIELD_F_ROOM_GENERATION)
	out.f_origin_tile = record.i32_column(FIELD_F_ORIGIN_TILE)
	out.f_rotation = record.i32_column(FIELD_F_ROTATION)
	out.f_user_slot = record.i32_column(FIELD_F_USER_SLOT)
	out.f_user_generation = record.i32_column(FIELD_F_USER_GENERATION)
	out.f_condition = record.i32_column(FIELD_F_CONDITION)


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build a refusal carrying an exact code: a section code, or a raw Buildings column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")


# --- ADR 1222 step 3: the joint section 4 + 5 + section-6-flag capture/apply pair ----------------

## A capture or apply called without a live store.
const REFUSE_NULL_STORE: StringName = &"SAVE_COMPONENT_NULL_STORE"
## A section 5 or section 6 block that is missing, another owner's, or misshaped.
const REFUSE_BLOCK_SHAPE: StringName = &"SAVE_BUILDINGS_BLOCK_SHAPE"
## The section-5 owner index of `buildings` and the section-6 owner index of `buildings`.
const CHILD_OWNER_INDEX: int = 0
const AUX_OWNER_INDEX: int = 0
## Section 6 ordinals of the two Buildings flag columns.
const AUX_R_SPATIAL_KIND: int = 0
const AUX_F_INSTALLED: int = 1


static func blocks_refusal(record: Section.FramedOwner, links: ChildSection.Block,
		flags: AuxSection.Block) -> SaveHeader.Refusal:
	"""The section 4 record passes gates 1-5; both other blocks are this owner's, well shaped."""
	var framed: SaveHeader.Refusal = _record_preflight(record)
	if not framed.is_ok():
		return framed
	if links == null or links.owner != CHILD_OWNER_INDEX \
			or ChildSchema.OWNER_KEYS[CHILD_OWNER_INDEX] != OWNER_KEY or links.shape_detail() != "":
		return _refuse(REFUSE_BLOCK_SHAPE, "a well-shaped section 5 '%s' block is required"
			% OWNER_KEY)
	if flags == null or flags.owner != AUX_OWNER_INDEX \
			or AuxSchema.OWNER_KEYS[AUX_OWNER_INDEX] != OWNER_KEY or flags.shape_detail() != "":
		return _refuse(REFUSE_BLOCK_SHAPE, "a well-shaped section 6 '%s' block is required"
			% OWNER_KEY)
	return _accept()


static func _record_preflight(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Gates 1-5 of `framed_refusal()`, without the column predicate."""
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
	return Section.owner_shape_refusal(record)


static func capture_into(store: Buildings, record: Section.FramedOwner,
		links: ChildSection.Block, flags: AuxSection.Block) -> SaveHeader.Refusal:
	"""Capture all three halves once, then judge the written section-4 record."""
	var target: SaveHeader.Refusal = blocks_refusal(record, links, flags)
	if not target.is_ok():
		return target
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Buildings store was supplied")
	var columns: Buildings.Columns = Buildings.Columns.new()
	var image: Buildings.Links = Buildings.Links.new()
	if not store.copy_columns_into(columns, image):
		return _refuse(store.last_column_refusal(), "%scapture refused with %s"
			% [COLUMN_DETAIL_PREFIX, String(store.last_column_refusal())])
	if not (_write_building_fields(columns, record) and _write_child_fields(columns, record)):
		return _refuse(Section.REFUSE_SHAPE, "%scapture could not write a column"
			% COLUMN_DETAIL_PREFIX)
	var written: SaveHeader.Refusal = _write_links(image, links, flags)
	if not written.is_ok():
		return written
	return framed_refusal(record, flags)


static func apply(record: Section.FramedOwner, links: ChildSection.Block,
		flags: AuxSection.Block, store: Buildings) -> SaveHeader.Refusal:
	"""Install sections 4, 5 and the section-6 flags in one `restore_columns()` call."""
	var target: SaveHeader.Refusal = blocks_refusal(record, links, flags)
	if not target.is_ok():
		return target
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no Buildings store was supplied")
	var columns: Buildings.Columns = Buildings.Columns.new(false)
	_project_columns(record, columns)
	var image: Buildings.Links = Buildings.Links.new()
	_read_links(links, flags, image)
	if not store.restore_columns(columns, image):
		return _refuse(store.last_column_refusal(), "%srestore refused with %s"
			% [COLUMN_DETAIL_PREFIX, String(store.last_column_refusal())])
	return _accept()


static func _write_building_fields(c: Buildings.Columns, r: Section.FramedOwner) -> bool:
	"""Ordinals 0..11: the three presence flags and the Building columns."""
	return (r.set_u8(FIELD_B_PRESENT, c.b_present) and r.set_u8(FIELD_R_PRESENT, c.r_present)
		and r.set_u8(FIELD_F_PRESENT, c.f_present) and r.set_i32(FIELD_B_TYPE_ID, c.b_type_id)
		and r.set_i32(FIELD_B_TIER, c.b_tier) and r.set_i32(FIELD_B_ORIGIN_TILE, c.b_origin_tile)
		and r.set_i32(FIELD_B_ROTATION, c.b_rotation) and r.set_i32(FIELD_B_STATE, c.b_state)
		and r.set_i32(FIELD_B_CONDITION, c.b_condition)
		and r.set_i32(FIELD_B_CONSTRUCTION_SLOT, c.b_construction_slot)
		and r.set_i32(FIELD_B_CONSTRUCTION_GENERATION, c.b_construction_generation)
		and r.set_i32(FIELD_B_INTERIOR_ID, c.b_interior_id))


static func _write_child_fields(c: Buildings.Columns, r: Section.FramedOwner) -> bool:
	"""Ordinals 12..28: the Room and Furniture columns."""
	return (r.set_i32(FIELD_R_TYPE, c.r_type)
		and r.set_i32(FIELD_R_BUILDING_SLOT, c.r_building_slot)
		and r.set_i32(FIELD_R_BUILDING_GENERATION, c.r_building_generation)
		and r.set_i32(FIELD_R_TILE_OFFSET, c.r_tile_offset)
		and r.set_i32(FIELD_R_TILE_COUNT, c.r_tile_count)
		and r.set_i32(FIELD_R_TEMPERATURE_TENTHS, c.r_temperature_tenths)
		and r.set_i32(FIELD_R_FURNITURE_MASK, c.r_furniture_mask)
		and r.set_i32(FIELD_R_OCCUPANTS, c.r_occupants) and r.set_u8(FIELD_R_VALID, c.r_valid)
		and r.set_i32(FIELD_F_TYPE_ID, c.f_type_id)
		and r.set_i32(FIELD_F_ROOM_SLOT, c.f_room_slot)
		and r.set_i32(FIELD_F_ROOM_GENERATION, c.f_room_generation)
		and r.set_i32(FIELD_F_ORIGIN_TILE, c.f_origin_tile)
		and r.set_i32(FIELD_F_ROTATION, c.f_rotation)
		and r.set_i32(FIELD_F_USER_SLOT, c.f_user_slot)
		and r.set_i32(FIELD_F_USER_GENERATION, c.f_user_generation)
		and r.set_i32(FIELD_F_CONDITION, c.f_condition))


static func _link_columns(image: Buildings.Links) -> Array[PackedInt32Array]:
	"""The fifteen section 5 columns in that section's ordinal order (shared, not copied)."""
	return [image.b_ref_slot, image.b_ref_generation, image.b_room_head, image.b_room_count,
		image.r_ref_slot, image.r_ref_generation, image.r_building_next, image.r_building_prev,
		image.r_furniture_head, image.r_furniture_count, image.f_ref_slot, image.f_ref_generation,
		image.f_room_next, image.f_room_prev, image.room_tile_id]


static func _write_links(image: Buildings.Links, links: ChildSection.Block,
		flags: AuxSection.Block) -> SaveHeader.Refusal:
	"""Write the fifteen section 5 columns and the two section 6 flags through checked setters."""
	var columns: Array[PackedInt32Array] = _link_columns(image)
	for ordinal: int in columns.size():
		var refusal: SaveHeader.Refusal = links.set_i32_column(ordinal, columns[ordinal])
		if not refusal.is_ok():
			return refusal
	var spatial: SaveHeader.Refusal = flags.set_u8_column(AUX_R_SPATIAL_KIND, image.r_spatial_kind)
	if not spatial.is_ok():
		return spatial
	return flags.set_u8_column(AUX_F_INSTALLED, image.f_installed)


static func _read_links(links: ChildSection.Block, flags: AuxSection.Block,
		image: Buildings.Links) -> void:
	"""Decode both blocks into `image`, assigning every member by name (fresh arrays)."""
	image.b_ref_slot = links.i32_column(0)
	image.b_ref_generation = links.i32_column(1)
	image.b_room_head = links.i32_column(2)
	image.b_room_count = links.i32_column(3)
	image.r_ref_slot = links.i32_column(4)
	image.r_ref_generation = links.i32_column(5)
	image.r_building_next = links.i32_column(6)
	image.r_building_prev = links.i32_column(7)
	image.r_furniture_head = links.i32_column(8)
	image.r_furniture_count = links.i32_column(9)
	image.f_ref_slot = links.i32_column(10)
	image.f_ref_generation = links.i32_column(11)
	image.f_room_next = links.i32_column(12)
	image.f_room_prev = links.i32_column(13)
	image.room_tile_id = links.i32_column(14)
	image.r_spatial_kind = flags.u8_column(AUX_R_SPATIAL_KIND)
	image.f_installed = flags.u8_column(AUX_F_INSTALLED)
