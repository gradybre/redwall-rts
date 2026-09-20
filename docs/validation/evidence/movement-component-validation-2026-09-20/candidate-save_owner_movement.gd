extends RefCounted
## Owner 8 (`movement`) column validation bridge (MOVEMENT-S4-VALIDATE-R01 v1, ADR 0182).
##
## ONE PUBLIC ENTRY POINT. `framed_refusal()` judges one already framed section 4 owner block
## against the Movement store's own cold column predicate and returns a `SaveHeader.Refusal`.
## It constructs no live Movement, SpatialWorld, Navigation, Residents, Transforms or
## Directory instance, captures nothing, restores nothing, reads no clock, fires no callback,
## emits no diagnostic, mutates no caller input and contains no float.
##
## GATE ORDER:
##   1. a null record                   -> SAVE_COMPONENT_SHAPE
##   2. an owner index that is not 8    -> SAVE_COMPONENT_OWNER
##   3. `Schema.schema_refusal()`       -> forwarded UNCHANGED, both code and detail
##   4. this owner's compiled metadata and the pinned Movement source constants ->
##      SAVE_COMPONENT_METADATA, with a detail beginning `Movement owner8 metadata:`
##   5. `Section.owner_shape_refusal()` -> forwarded UNCHANGED
##   6. one cold `Movement.Columns` whose SIXTEEN canonical columns are all assigned
##      explicitly, in canonical `Schema.FIELD_KEYS[171..186]` order
##   7. `Movement.columns_refusal()`    -> the EXACT unwrapped column code, for example
##      COLUMN_STATE, in a detail naming owner 8 and carrying no row identity.
## Success carries an empty code and an empty detail.
##
## CANONICAL ORDER IS NOT DECLARATION ORDER: `movement.gd` declares `_grid_next`/`_grid_cell`
## ahead of `_radius_u`/`_speed_u_per_s`, and the saved field window does not. Reordering
## either list to match the other renumbers a persisted field.
##
## LOCAL ACCEPTANCE IS NOT PUBLICATION. An accepted result certifies owner-8 local motion
## column domains only. Saved Residents identity, the section 2 cursor/profile/load and
## destination terms, navigation request and route generations, Transforms pose, the loaded
## tick phase and common provenance remain MOVEMENT-SAVED-BINDINGS obligations; bulk capture
## and apply, connected tunnels, swimming, diving and canopy access all stay open.
##
## MEMORY, CONDITIONALLY. The projection SHARES the caller's packed buffers by assignment: no
## `duplicate()` runs here. The contract's conservative figure is 65536 logical packed bytes
## -- the 32768-byte caller image plus the 32768-byte cold constructor defaults -- below the
## 6417408-byte stream allowance. Immutable metadata, Movement's transitive script preloads
## and native overhead are accounted separately; that figure is allocation arithmetic and not
## a measured resident set.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Movement := preload("res://scripts/core/movement.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## The section-local owner this bridge accepts, and the compiled metadata it demands of it.
const OWNER_INDEX: int = 8
const OWNER_KEY: String = "movement"
const OWNER_VERSION: int = 1
const OWNER_PRIMARY_COUNT: int = 512
## Owner 8 declares NO independent child extent: every column covers the 512 primary rows.
const OWNER_CHILD_EXTENT_COUNT: int = 0
const OWNER_FIELD_COUNT: int = 16
## Gate 4's detail prefix. Gate 3 forwards the schema module's own detail unchanged.
const METADATA_DETAIL_PREFIX: String = "Movement owner8 metadata:"
## Gate 7's detail prefix. It names the owner and the exact code, and never a row.
const COLUMN_DETAIL_PREFIX: String = "Movement owner 8 "

## The canonical owner-local field declarations, `Schema.FIELD_KEYS[171..186]` in order.
const FIELD_KEYS: Array[StringName] = [
	&"_vx", &"_vz", &"_remainder_x", &"_remainder_z",
	&"_next_x", &"_next_z", &"_correction_x", &"_correction_z",
	&"_radius_u", &"_desired_yaw", &"_next_yaw", &"_grid_next",
	&"_grid_cell", &"_speed_u_per_s", &"_movement_phase", &"_blocked_ticks",
]
const FIELD_TYPES: Array[int] = [
	Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
	Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32, Schema.TYPE_I32,
]
const FIELD_COUNTS: Array[int] = [
	512, 512, 512, 512, 512, 512, 512, 512,
	512, 512, 512, 512, 512, 512, 512, 512,
]

## Owner-local field ordinals, in the order the canonical registry publishes them.
const FIELD_VX: int = 0
const FIELD_VZ: int = 1
const FIELD_REMAINDER_X: int = 2
const FIELD_REMAINDER_Z: int = 3
const FIELD_NEXT_X: int = 4
const FIELD_NEXT_Z: int = 5
const FIELD_CORRECTION_X: int = 6
const FIELD_CORRECTION_Z: int = 7
const FIELD_RADIUS_U: int = 8
const FIELD_DESIRED_YAW: int = 9
const FIELD_NEXT_YAW: int = 10
const FIELD_GRID_NEXT: int = 11
const FIELD_GRID_CELL: int = 12
const FIELD_SPEED_U_PER_S: int = 13
const FIELD_MOVEMENT_PHASE: int = 14
const FIELD_BLOCKED_TICKS: int = 15

## The Movement source constants this bridge pins as contract before it reads a column.
const SOURCE_MOTION_CAPACITY: int = 512
const SOURCE_MOTION_IDLE: int = 0
const SOURCE_MOTION_TRAVELLING: int = 1
const SOURCE_MOTION_ARRIVED: int = 2
const SOURCE_MOTION_ROUTE_LOST: int = 3
const SOURCE_MOTION_PROFILE_STALE: int = 4
const SOURCE_MOTION_CONTACT_STALE: int = 5
const SOURCE_MOTION_PHASE_COUNT: int = 6
const SOURCE_NO_REQUEST: int = -1
const SOURCE_TICKS_PER_SECOND: int = 30
const SOURCE_REMAINDER_DENOMINATOR: int = 420
const SOURCE_ORTHOGONAL_NUMERATOR_FACTOR: int = 14
const SOURCE_DIAGONAL_NUMERATOR_FACTOR: int = 10
const SOURCE_COST_ORTHOGONAL: int = 10
const SOURCE_COST_DIAGONAL: int = 14
## BOTH axis counts are pinned: the centre helper reads CELLS_X for BOTH axes, so a nonsquare
## map would move the Z domain without touching the constant that helper reads.
const SOURCE_CELLS_X: int = 512
const SOURCE_CELLS_Z: int = 512
const SOURCE_CELL_COUNT: int = 262144
const SOURCE_CELL_SIZE_UNITS: int = 512
const SOURCE_CELL_CENTRE_OFFSET_UNITS: int = 256
const SOURCE_RESIDENT_CAPACITY: int = 512
## The speed table the speed gate searches. Its LENGTH is pinned before any entry is read.
const SOURCE_SPEED_TABLE_LENGTH: int = 3
const SOURCE_SIZE_MOVEMENT_U_PER_S: Array[int] = [3277, 4096, 3072]


static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal:
	"""Judge one framed owner 8 block against the Movement store's own cold column rules."""
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
	var columns: Movement.Columns = Movement.Columns.new()
	_project_columns(record, columns)
	var code: StringName = Movement.columns_refusal(columns)
	if code != Movement.REFUSE_NONE:
		return _refuse(code, "%srefuses this image with column code %s"
			% [COLUMN_DETAIL_PREFIX, String(code)])
	return _accept()


static func _metadata_refusal() -> SaveHeader.Refusal:
	"""Gate 4: compiled owner identity and extents, then the pinned Movement constants."""
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
			"%s %d primaries, %d child extents and %d fields are not %d/%d/%d"
				% [METADATA_DETAIL_PREFIX, Schema.primary_count(OWNER_INDEX),
					Schema.child_extent_count(OWNER_INDEX), Schema.field_count(OWNER_INDEX),
					OWNER_PRIMARY_COUNT, OWNER_CHILD_EXTENT_COUNT, OWNER_FIELD_COUNT])
	if FIELD_KEYS.size() != OWNER_FIELD_COUNT or FIELD_TYPES.size() != OWNER_FIELD_COUNT \
			or FIELD_COUNTS.size() != OWNER_FIELD_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s this bridge pins %d/%d/%d field declarations, not %d"
				% [METADATA_DETAIL_PREFIX, FIELD_KEYS.size(), FIELD_TYPES.size(),
					FIELD_COUNTS.size(), OWNER_FIELD_COUNT])
	var source: SaveHeader.Refusal = _source_refusal()
	if not source.is_ok():
		return source
	return _field_parity_refusal()


static func _source_refusal() -> SaveHeader.Refusal:
	"""Gate 4's source half: the motion capacity, the sentinel and the whole phase domain."""
	if Movement.MOTION_CAPACITY != SOURCE_MOTION_CAPACITY \
			or Movement.NO_REQUEST != SOURCE_NO_REQUEST:
		return _refuse(Section.REFUSE_METADATA,
			"%s Movement declares %d motion rows with sentinel %d, not %d/%d"
				% [METADATA_DETAIL_PREFIX, Movement.MOTION_CAPACITY, Movement.NO_REQUEST,
					SOURCE_MOTION_CAPACITY, SOURCE_NO_REQUEST])
	if Movement.MOTION_IDLE != SOURCE_MOTION_IDLE \
			or Movement.MOTION_TRAVELLING != SOURCE_MOTION_TRAVELLING \
			or Movement.MOTION_ARRIVED != SOURCE_MOTION_ARRIVED \
			or Movement.MOTION_ROUTE_LOST != SOURCE_MOTION_ROUTE_LOST \
			or Movement.MOTION_PROFILE_STALE != SOURCE_MOTION_PROFILE_STALE \
			or Movement.MOTION_CONTACT_STALE != SOURCE_MOTION_CONTACT_STALE \
			or Movement.MOTION_PHASE_COUNT != SOURCE_MOTION_PHASE_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the phase domain is not the pinned 0..%d numbering bounded by %d"
				% [METADATA_DETAIL_PREFIX, SOURCE_MOTION_CONTACT_STALE,
					SOURCE_MOTION_PHASE_COUNT])
	return _source_rate_refusal()


static func _source_rate_refusal() -> SaveHeader.Refusal:
	"""Gate 4: the tick rate, the shared remainder denominator and both octile factors."""
	if Movement.TICKS_PER_SECOND != SOURCE_TICKS_PER_SECOND \
			or Movement.REMAINDER_DENOMINATOR != SOURCE_REMAINDER_DENOMINATOR:
		return _refuse(Section.REFUSE_METADATA,
			"%s %d ticks a second over denominator %d is not %d/%d"
				% [METADATA_DETAIL_PREFIX, Movement.TICKS_PER_SECOND,
					Movement.REMAINDER_DENOMINATOR, SOURCE_TICKS_PER_SECOND,
					SOURCE_REMAINDER_DENOMINATOR])
	if Movement.ORTHOGONAL_NUMERATOR_FACTOR != SOURCE_ORTHOGONAL_NUMERATOR_FACTOR \
			or Movement.DIAGONAL_NUMERATOR_FACTOR != SOURCE_DIAGONAL_NUMERATOR_FACTOR \
			or Movement.Navigation.COST_ORTHOGONAL != SOURCE_COST_ORTHOGONAL \
			or Movement.Navigation.COST_DIAGONAL != SOURCE_COST_DIAGONAL:
		return _refuse(Section.REFUSE_METADATA,
			"%s numerator factors %d/%d and octile costs %d/%d are not the pinned values"
				% [METADATA_DETAIL_PREFIX, Movement.ORTHOGONAL_NUMERATOR_FACTOR,
					Movement.DIAGONAL_NUMERATOR_FACTOR, Movement.Navigation.COST_ORTHOGONAL,
					Movement.Navigation.COST_DIAGONAL])
	return _source_geometry_refusal()


static func _source_geometry_refusal() -> SaveHeader.Refusal:
	"""Gate 4: the cell grid that bounds the cell and target gates, both axis counts pinned."""
	if Movement.SpatialWorld.CELLS_X != SOURCE_CELLS_X \
			or Movement.SpatialWorld.CELLS_Z != SOURCE_CELLS_Z \
			or Movement.SpatialWorld.CELL_COUNT != SOURCE_CELL_COUNT:
		return _refuse(Section.REFUSE_METADATA,
			"%s the grid is %dx%d over %d cells, not %dx%d over %d"
				% [METADATA_DETAIL_PREFIX, Movement.SpatialWorld.CELLS_X,
					Movement.SpatialWorld.CELLS_Z, Movement.SpatialWorld.CELL_COUNT,
					SOURCE_CELLS_X, SOURCE_CELLS_Z, SOURCE_CELL_COUNT])
	if Movement.SpatialWorld.CELL_SIZE_UNITS != SOURCE_CELL_SIZE_UNITS \
			or Movement.SpatialWorld.CELL_CENTRE_OFFSET_UNITS \
				!= SOURCE_CELL_CENTRE_OFFSET_UNITS:
		return _refuse(Section.REFUSE_METADATA,
			"%s a cell is %d units wide with centre offset %d, not %d/%d"
				% [METADATA_DETAIL_PREFIX, Movement.SpatialWorld.CELL_SIZE_UNITS,
					Movement.SpatialWorld.CELL_CENTRE_OFFSET_UNITS, SOURCE_CELL_SIZE_UNITS,
					SOURCE_CELL_CENTRE_OFFSET_UNITS])
	return _source_speed_refusal()


static func _source_speed_refusal() -> SaveHeader.Refusal:
	"""Gate 4's last half: the resident capacity, then the speed table, LENGTH before entries."""
	if Movement.ResidentsScript.RESIDENT_CAPACITY != SOURCE_RESIDENT_CAPACITY:
		return _refuse(Section.REFUSE_METADATA,
			"%s Residents declares %d rows, not %d"
				% [METADATA_DETAIL_PREFIX, Movement.ResidentsScript.RESIDENT_CAPACITY,
					SOURCE_RESIDENT_CAPACITY])
	if Movement.ResidentsScript.SIZE_MOVEMENT_U_PER_S.size() != SOURCE_SPEED_TABLE_LENGTH:
		return _refuse(Section.REFUSE_METADATA,
			"%s the speed table holds %d entries, not %d"
				% [METADATA_DETAIL_PREFIX,
					Movement.ResidentsScript.SIZE_MOVEMENT_U_PER_S.size(),
					SOURCE_SPEED_TABLE_LENGTH])
	for size_class: int in SOURCE_SPEED_TABLE_LENGTH:
		if int(Movement.ResidentsScript.SIZE_MOVEMENT_U_PER_S[size_class]) \
				!= int(SOURCE_SIZE_MOVEMENT_U_PER_S[size_class]):
			return _refuse(Section.REFUSE_METADATA, "%s size class %d travels at %d u/s, not %d"
				% [METADATA_DETAIL_PREFIX, size_class,
					int(Movement.ResidentsScript.SIZE_MOVEMENT_U_PER_S[size_class]),
					int(SOURCE_SIZE_MOVEMENT_U_PER_S[size_class])])
	return _accept()


static func _field_parity_refusal() -> SaveHeader.Refusal:
	"""Gate 4's per-field half: key, type code and element count, ordinal by ordinal."""
	for field: int in OWNER_FIELD_COUNT:
		if Schema.field_key(OWNER_INDEX, field) != String(FIELD_KEYS[field]):
			return _refuse(Section.REFUSE_METADATA, "%s field %d is '%s'; owner 8 declares '%s'"
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


static func _project_columns(record: Section.FramedOwner, columns: Movement.Columns) -> void:
	"""Ordinals 0..15: the 512-row motion image, every canonical column assigned explicitly.

	The packed buffers are SHARED with the caller's record, not duplicated: the predicate this
	feeds reads only its argument and writes nothing anywhere.
	"""
	columns.vx = record.i32_column(FIELD_VX)
	columns.vz = record.i32_column(FIELD_VZ)
	columns.remainder_x = record.i32_column(FIELD_REMAINDER_X)
	columns.remainder_z = record.i32_column(FIELD_REMAINDER_Z)
	columns.next_x = record.i32_column(FIELD_NEXT_X)
	columns.next_z = record.i32_column(FIELD_NEXT_Z)
	columns.correction_x = record.i32_column(FIELD_CORRECTION_X)
	columns.correction_z = record.i32_column(FIELD_CORRECTION_Z)
	columns.radius_u = record.i32_column(FIELD_RADIUS_U)
	columns.desired_yaw = record.i32_column(FIELD_DESIRED_YAW)
	columns.next_yaw = record.i32_column(FIELD_NEXT_YAW)
	columns.grid_next = record.i32_column(FIELD_GRID_NEXT)
	columns.grid_cell = record.i32_column(FIELD_GRID_CELL)
	columns.speed_u_per_s = record.i32_column(FIELD_SPEED_U_PER_S)
	columns.movement_phase = record.i32_column(FIELD_MOVEMENT_PHASE)
	columns.blocked_ticks = record.i32_column(FIELD_BLOCKED_TICKS)


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build a refusal carrying an exact code: a section code, or a raw Movement column code."""
	return SaveHeader.Refusal.new(code, detail)


static func _accept() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
