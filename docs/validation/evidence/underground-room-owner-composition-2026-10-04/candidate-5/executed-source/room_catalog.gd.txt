extends RefCounted
## Cold read-only room-purpose adapter. No room, furniture, project or service is created here.
## Identities and numeric furniture facts remain owned by Catalog, BuildingDefinitions and
## Construction. Returned records are copies; counts/compatibility never attest live readiness.

const Catalog := preload("res://scripts/core/catalog.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")

const TILE_UNITS: int = 2048 # GDD 5.9: one footprint tile is two metres.
const TILE_AREA_UNITS2: int = TILE_UNITS * TILE_UNITS
const FURNITURE_COUNT: int = BuildingDefinitions.FURNITURE_DEFINITION_COUNT
const NO_MAXIMUM: int = -1
const REFUSE_ROOM: StringName = &"UNKNOWN_ROOM_TYPE"
const REFUSE_PRESET: StringName = &"UNKNOWN_OR_AMBIGUOUS_ROOM_PRESET"
const REFUSE_FURNITURE: StringName = &"UNKNOWN_FURNITURE_DEFINITION"
const REFUSE_PURPOSE: StringName = &"FURNITURE_WRONG_ROOM_PURPOSE"
const REFUSE_RETYPE: StringName = &"ROOM_TYPE_REQUIRES_REMOVAL_AND_REBUILD"
const REFUSE_COUNTS: StringName = &"INVALID_INSTALLED_FURNITURE_COUNTS"
const REFUSE_AREA_INPUT: StringName = &"INVALID_ROOM_AREA"
const REFUSE_AREA: StringName = &"ROOM_MINIMUM_AREA"
const REFUSE_REQUIRED: StringName = &"ROOM_REQUIRED_FURNITURE"
const REFUSE_EXCESS: StringName = &"ROOM_MAXIMUM_FURNITURE"
const REFUSE_ROTATION: StringName = &"INVALID_FURNITURE_ROTATION"

## Display/selection aliases only: no ninth room type, saved ordinal or economic recipe.
const ROOM_LABELS: Dictionary = {
	"DORMITORY": "Dormitory", "PRIVATE_ROOM": "Bedroom", "KITCHEN": "Kitchen",
	"DINING": "Dining room", "COMMON": "Common room", "INFIRMARY": "Infirmary",
	"PANTRY": "Pantry", "CORRIDOR": "Corridor",
}
const ROOM_PRESETS: Dictionary = {
	"Bedroom": "PRIVATE_ROOM", "Dormitory": "DORMITORY", "Kitchen": "KITCHEN",
	"Dining room": "DINING", "Common room": "COMMON", "Infirmary": "INFIRMARY",
	"Pantry": "PANTRY", "Corridor": "CORRIDOR", "Tunnel": "CORRIDOR", "Root cellar": "PANTRY",
}
## GDD's generic room comfort, heat and boundary functions do not become cooking equipment.
const COMMON_FITTINGS: Array[String] = ["decoration", "hearth", "interior_door", "interior_partition", "seat", "shelf"]
## User-directed purpose specialization; GDD requires ordinary beds in both sleeping types.
## Service-only prerequisites are NOT an exhaustive placement ban on shared chairs/shelves.
const PURPOSE_FITTINGS: Dictionary = {
	"bed": ["DORMITORY", "PRIVATE_ROOM"], "patient_bed": ["INFIRMARY"],
	"kitchen_bench": ["KITCHEN"],
}


class RoomPurpose extends RefCounted:

	var ok: bool = false
	var error: StringName = &"UNKNOWN_ROOM_TYPE"
	var type_id: int = -1
	var key: StringName = &""
	var label: String = ""
	var allowed_types_mask: int = -1


class FurnitureFacts extends RefCounted:

	## Recipe and floor footprint facts only. Edge 0x0 means an opening/boundary profile is needed.
	## There are deliberately no invented height, access offset, handling or finish-default values.
	var ok: bool = false
	var error: StringName = &"UNKNOWN_FURNITURE_DEFINITION"
	var type_id: int = -1
	var key: StringName = &""
	var footprint_units: Vector2i = Vector2i.ZERO
	var edge_placement: bool = false
	var work_mwu: int = 0
	var user_slots: int = 0
	var material_keys: PackedStringArray = PackedStringArray()
	var quantity_milli: PackedInt64Array = PackedInt64Array()
	var station_id: int = Catalog.EMPTY_CATALOG_ID
	var station_slots: int = 0
	var geometry_profile_required: bool = true


class ServiceRequirements extends RefCounted:

	## Necessary conditions, not a ready/valid-room result; actual owners must establish every gate.
	var ok: bool = false
	var error: StringName = &"UNKNOWN_ROOM_TYPE"
	var minimum_tiles: int = 0
	var minimum_counts: PackedInt32Array = PackedInt32Array()
	var maximum_counts: PackedInt32Array = PackedInt32Array()
	var area_per_kind: int = -1
	var tiles_per_piece: int = 0
	var minimum_corridor_width_units: int = 0
	var owner_gates: PackedStringArray = PackedStringArray()


class ScopedServiceFacts extends RefCounted:

	## Per-piece catalog contributions, never availability. All live-owner gates still apply.
	var ok: bool = false
	var error: StringName = &"UNKNOWN_ROOM_TYPE"
	var pantry_capacity_g: int = 0
	var kitchen_station_id: int = Catalog.EMPTY_CATALOG_ID
	var kitchen_worker_slots: int = 0


var _definitions: BuildingDefinitions = null


func _init(definitions: BuildingDefinitions = null) -> void:
	"""Borrow an existing immutable fact owner when supplied; standalone queries retain their original catalog."""
	_definitions = definitions if definitions != null else BuildingDefinitions.new()


static func is_room_type(type_id: int) -> bool:
	"""Validate against the protected RoomType domain, not a display alias or building ordinal."""
	return Catalog.ROOM_TYPE.values().has(type_id)


static func room_types() -> PackedInt32Array:
	"""Return every existing room id in deterministic ascending order; no preset adds an id."""
	var ids: PackedInt32Array = PackedInt32Array(Catalog.ROOM_TYPE.values())
	ids.sort()
	return ids


func purpose(type_id: int) -> RoomPurpose:
	"""Read one permanent purpose and its modular placement palette; neither grants any service."""
	var result: RoomPurpose = RoomPurpose.new()
	if not is_room_type(type_id):
		return result
	result.ok = true
	result.error = &""
	result.type_id = type_id
	result.key = StringName(Catalog.ROOM_TYPE.find_key(type_id))
	result.label = ROOM_LABELS[String(result.key)]
	result.allowed_types_mask = allowed_types_mask(type_id)
	return result


func resolve_preset(label_or_key: StringName) -> RoomPurpose:
	"""Resolve exact display aliases or existing keys; ambiguous 'Burrow'/'Cellar' refuses."""
	var key: String = String(label_or_key)
	if ROOM_PRESETS.has(key):
		key = ROOM_PRESETS[key]
	if Catalog.ROOM_TYPE.has(key):
		return purpose(int(Catalog.ROOM_TYPE[key]))
	var result: RoomPurpose = RoomPurpose.new()
	result.error = REFUSE_PRESET
	return result


func allowed_types_mask(room_type: int) -> int:
	"""Produce RoomLayout.Snapshot's explicit eligibility mask; -1 means unknown, never all items."""
	if not is_room_type(room_type):
		return -1
	var mask: int = 0
	for type_id: int in range(FURNITURE_COUNT):
		if compatibility_error(room_type, type_id) == &"":
			mask |= _definitions.furniture_bit_of(type_id)
	return mask


func compatibility_error(room_type: int, furniture_type: int) -> StringName:
	"""Room purpose is independent of its current contents, shell validity, shape and theme."""
	if not is_room_type(room_type):
		return REFUSE_ROOM
	if not _definitions.is_furniture_id(furniture_type):
		return REFUSE_FURNITURE
	var key: String = Catalog.FURNITURE_DEFINITION.find_key(furniture_type)
	if COMMON_FITTINGS.has(key):
		return &""
	var room_key: String = Catalog.ROOM_TYPE.find_key(room_type)
	return &"" if PURPOSE_FITTINGS[key].has(room_key) else REFUSE_PURPOSE


static func retained_type_error(built_type: int, requested_type: int) -> StringName:
	"""A room identity keeps its purpose even when empty; only real removal/rebuild creates another."""
	if not is_room_type(built_type) or not is_room_type(requested_type):
		return REFUSE_ROOM
	return &"" if built_type == requested_type else REFUSE_RETYPE


func furniture_by_key(key: StringName, rotation: int = 0) -> FurnitureFacts:
	"""Only real FurnitureDefinition keys resolve; oven/stove never silently alias a cooking bench."""
	return furniture(int(Catalog.FURNITURE_DEFINITION.get(String(key), -1)), rotation)


func furniture(type_id: int, rotation: int = 0) -> FurnitureFacts:
	"""Copy existing two-metre footprint, milli-WU and bill facts without instantiating Construction."""
	var result: FurnitureFacts = FurnitureFacts.new()
	if not _definitions.is_furniture_id(type_id):
		return result
	if rotation < 0 or rotation > 3:
		result.error = REFUSE_ROTATION
		return result
	result.type_id = type_id
	result.key = StringName(Catalog.FURNITURE_DEFINITION.find_key(type_id))
	var x: int = _definitions.floor_x_of(type_id) * TILE_UNITS
	var z: int = _definitions.floor_z_of(type_id) * TILE_UNITS
	result.footprint_units = Vector2i(z, x) if rotation % 2 == 1 else Vector2i(x, z)
	result.edge_placement = _definitions.is_edge_furniture(type_id)
	result.work_mwu = _definitions.furniture_work_mwu_of(type_id)
	result.user_slots = _definitions.user_slots_of(type_id)
	result.station_id = _definitions.station_of_furniture(type_id)
	result.station_slots = _definitions.furniture_station_slots_of(type_id)
	_copy_material_bill(result)
	result.ok = true
	result.error = &""
	return result


static func _copy_material_bill(result: FurnitureFacts) -> void:
	"""Copy Construction's bill keys; the real item registry binding resolves ids at admission."""
	var pairs: Array = Construction.FURNITURE_MATERIALS[String(result.key)]
	for at: int in range(0, pairs.size(), 2):
		result.material_keys.append(String(pairs[at]))
		result.quantity_milli.append(int(pairs[at + 1]))


func scoped_service_facts(room_type: int, furniture_type: int) -> ScopedServiceFacts:
	"""A shelf in a Bedroom/Kitchen is legal but gains no Pantry capacity or industrial buffer."""
	var result: ScopedServiceFacts = ScopedServiceFacts.new()
	result.error = compatibility_error(room_type, furniture_type)
	if result.error != &"":
		return result
	result.ok = true
	if room_type == Buildings.ROOM_TYPE_PANTRY:
		result.pantry_capacity_g = _definitions.shelf_capacity_g_of(furniture_type)
	if room_type == Buildings.ROOM_TYPE_KITCHEN:
		result.kitchen_station_id = _definitions.station_of_furniture(furniture_type)
		result.kitchen_worker_slots = _definitions.furniture_station_slots_of(furniture_type)
	return result


func service_requirements(room_type: int) -> ServiceRequirements:
	"""Describe GDD 5.9 prerequisites; no supplied count, bitmask or label establishes readiness."""
	var result: ServiceRequirements = ServiceRequirements.new()
	if not is_room_type(room_type):
		return result
	result.ok = true
	result.error = &""
	result.minimum_counts.resize(FURNITURE_COUNT)
	result.maximum_counts.resize(FURNITURE_COUNT)
	result.maximum_counts.fill(NO_MAXIMUM)
	result.owner_gates = PackedStringArray(["COMPLETED_ROOM_SHELL", "LIVE_ROOM_AND_BUILDING",
		"INSTALLED_SERVICE_ELIGIBLE_FURNITURE", "NONOVERLAPPING_SUPPORTED_GEOMETRY",
		"CONNECTED_FURNITURE_ACCESS", "OWNING_SERVICE_OPERATIONAL_GATES"])
	_set_count_requirements(room_type, result)
	_set_spatial_requirements(room_type, result)
	return result


static func _set_count_requirements(room_type: int, result: ServiceRequirements) -> void:
	"""Use the existing Buildings constants for its exact countable GDD rules."""
	match room_type:
		Buildings.ROOM_TYPE_DORMITORY:
			_set_count(result, "bed", 1, Buildings.TILES_PER_BED)
		Buildings.ROOM_TYPE_PRIVATE_ROOM:
			result.minimum_tiles = Buildings.PRIVATE_ROOM_MIN_TILES
			_set_count(result, "bed", Buildings.PRIVATE_ROOM_BEDS)
			result.maximum_counts[int(Catalog.FURNITURE_DEFINITION["bed"])] = Buildings.PRIVATE_ROOM_BEDS
		Buildings.ROOM_TYPE_KITCHEN:
			result.minimum_tiles = Buildings.KITCHEN_MIN_TILES
			_set_count(result, "kitchen_bench", 1)
			_set_count(result, "hearth", 1)
		Buildings.ROOM_TYPE_DINING:
			_set_count(result, "seat", Buildings.DINING_MIN_SEATS, Buildings.TILES_PER_SEAT)
		Buildings.ROOM_TYPE_COMMON:
			result.minimum_tiles = Buildings.COMMON_MIN_TILES
			_set_count(result, "seat", Buildings.COMMON_MIN_SEATS)
		Buildings.ROOM_TYPE_INFIRMARY:
			_set_count(result, "patient_bed", 1, Buildings.TILES_PER_PATIENT_BED)
			_set_count(result, "shelf", 1)
		Buildings.ROOM_TYPE_PANTRY:
			result.minimum_tiles = Buildings.PANTRY_MIN_TILES
			_set_count(result, "shelf", 1)


static func _set_count(result: ServiceRequirements, key: String, minimum: int, ratio: int = 0) -> void:
	"""Set an existing FurnitureDefinition's minimum and optional GDD area-per-piece ratio."""
	var type_id: int = int(Catalog.FURNITURE_DEFINITION[key])
	result.minimum_counts[type_id] = minimum
	if ratio > 0:
		result.area_per_kind = type_id
		result.tiles_per_piece = ratio


static func _set_spatial_requirements(room_type: int, result: ServiceRequirements) -> void:
	"""Keep heat, enclosure, corridor width and exterior connectivity as explicit live-owner gates."""
	match room_type:
		Buildings.ROOM_TYPE_DORMITORY:
			result.owner_gates.append("BED_ACCESS_CONNECTED_TO_EXTERIOR")
		Buildings.ROOM_TYPE_PRIVATE_ROOM:
			result.owner_gates.append("PARTITIONED_ENCLOSURE")
		Buildings.ROOM_TYPE_INFIRMARY:
			result.owner_gates.append("HEATED_COMPONENT")
		Buildings.ROOM_TYPE_CORRIDOR:
			result.minimum_corridor_width_units = TILE_UNITS
			result.owner_gates.append("CORRIDOR_WIDTH_AND_EXTERIOR_LINK")


func countable_error(room_type: int, floor_area_units2: int, installed_counts: PackedInt32Array) -> StringName:
	"""Check necessary area/count prerequisites only, using exact area rather than rounded-up tiles."""
	if not is_room_type(room_type):
		return REFUSE_ROOM
	if not _valid_counts(installed_counts):
		return REFUSE_COUNTS
	if floor_area_units2 < 0:
		return REFUSE_AREA_INPUT
	var requirements: ServiceRequirements = service_requirements(room_type)
	var tiles: int = requirements.minimum_tiles
	if requirements.area_per_kind >= 0:
		tiles = maxi(tiles, installed_counts[requirements.area_per_kind] * requirements.tiles_per_piece)
	if floor_area_units2 < tiles * TILE_AREA_UNITS2:
		return REFUSE_AREA
	return _count_limits_error(room_type, installed_counts, requirements)


static func _valid_counts(counts: PackedInt32Array) -> bool:
	"""Reject malformed/overflowing census input before multiplication; reuse the existing arena bound."""
	if counts.size() != FURNITURE_COUNT:
		return false
	var total: int = 0
	for count: int in counts:
		if count < 0 or count > Buildings.FURNITURE_CAPACITY:
			return false
		total += count
	return total <= Buildings.FURNITURE_CAPACITY


func _count_limits_error(room_type: int, counts: PackedInt32Array,
		requirements: ServiceRequirements) -> StringName:
	"""Count actual installed eligible pieces, never popcount the structural presence mask."""
	for type_id: int in range(FURNITURE_COUNT):
		if counts[type_id] > 0 and compatibility_error(room_type, type_id) != &"":
			return REFUSE_PURPOSE
		if counts[type_id] < requirements.minimum_counts[type_id]:
			return REFUSE_REQUIRED
		var maximum: int = requirements.maximum_counts[type_id]
		if maximum != NO_MAXIMUM and counts[type_id] > maximum:
			return REFUSE_EXCESS
	return &""
