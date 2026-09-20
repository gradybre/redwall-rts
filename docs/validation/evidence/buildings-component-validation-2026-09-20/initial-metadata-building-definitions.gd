extends RefCounted
## The immutable BuildingDefinition / FurnitureDefinition facts, and the Station provider binding.
##
## Decision 0056 published the two domains' IDENTITY -- thirty building keys and nine furniture
## keys -- and said in terms that "Footprints, materials, work, slots, `managed_interior`,
## `room_tiles`, `unlock`, `base_store_g`, `passive_slots` and `max_builders` are NOT transcribed
## here. They stay in §4.1/§4.2's rows and belong to §7.2 step 2's packed Building/Furniture/Room
## stores." This module is where they land: the numeric half of the catalog, read by `buildings.gd`
## and by anything that needs a capacity rather than an id.
##
## NO SECOND KEY LIST. Every table below is keyed by the SAME StringName keys `catalog.gd` owns,
## and the packed columns are indexed by the id `Catalog.BUILDING_DEFINITION` /
## `Catalog.FURNITURE_DEFINITION` assigns. `_init()` refuses unless the two key sets are exactly
## equal in both directions, so a key added to one and not the other fails loudly instead of
## leaving a zero-filled row that reads as a legal 0-slot, 0-capacity building. Decision 0056
## rejected a second identity file for exactly this drift; keying the facts by the catalog's own
## keys is what keeps that rejection intact while still storing the facts somewhere.
##
## SOURCES, ROW BY ROW. `gameplay_balance.md` §4.1 gives footprint_x, footprint_z, work_mwu,
## slots, managed_interior, room_tiles and unlock; §4.2 gives base_store_g, passive_slots and
## max_builders; §4.3 gives the furniture floor_x, floor_z, work_mwu and user_slots. Those tables
## are themselves derived from GDD §5.9 with `[GDD §5.9; NEW normalized key]` provenance on every
## row, and BAL-CAT-006 is what joins a base row to its upgrade and furniture rows.
##
## UNLOCK IS A MILESTONE ID (R-BUILD-DOM-001, decision 0074). §4.1's unlock column carries 0..3
## and BAL-CAT-002 states the encoding outright: "Unlock values are M0=0, M1=1, M2=2, M3=3,
## M4=4". `unlock_of()` returns that id and `milestones.gd` owns the earned-bit gate; nothing
## here compares ordinals. No current building row carries M4 -- §5.11 gives M4 a victory
## presentation and a cosmetic monument, not a building -- and publishing the fifth milestone
## creates no M4 production entry, which the ruling states explicitly.
##
## THE STATION PROVIDER BINDING (R-BUILD-DOM-002). Eleven building keys are spelled identically
## to the eleven Station service keys and carry DIFFERENT ids; `station_of_building()` is the
## explicit mapping between them, built by key lookup through both catalogs rather than by
## assuming the spellings line up positionally. `kitchen_bench` furniture additionally provides
## the `kitchen` service at one slot per bench. The ruling's own worked example is asserted in
## `_assert_station_binding()`: "kitchen service=3, exterior kitchen building=14, hall
## building=12, and kitchen_bench furniture=5".
##
## A SERVICE ID IS NOT A READY STATION. The ruling is emphatic and this module obeys it: these
## tables give a definition's CATALOG capacity. Whether a particular building can actually run a
## recipe depends on its state, condition, occupancy, room validity, access, inputs, output space
## and -- for well and saltpan -- a bound physical source. None of those is knowable from a
## definition row, so nothing here returns "ready"; `buildings.gd` answers only about live rows,
## and even there the topology gates remain open work.
##
## WHAT IS DELIBERATELY ABSENT:
##   * MATERIALS. §4.1's `materials_milli` and §4.3's are typed pair lists (`wood:100000;
##     stone:60000;cloth:12000`), and they are consumed by the Construction delivery/refund
##     contract in task 06.2 -- REQ-SET-124/125/126 -- which does not exist. A pair list is not
##     an int32 column and transcribing it into one here would fix a representation the store
##     that needs it has not chosen. `work_mwu` IS carried, because it is a single integer that
##     the same rows state and the Construction row will hold as `remaining_mwu`.
##   * THE TIER-2 UPGRADE PACKAGES. §4.2's second table (materials, work, fuel_num/den,
##     capacity_num/den, craft_num/den, added_comfort) belongs with the upgrade command in 06.2.
##     What IS carried is the fact BAL-CAT-006 states as a restriction -- "Only residence, hall,
##     covered_store, and workshop accept the GDD tier-2 packages" -- because `Building.tier` is
##     a stored column and a store that accepts tier 2 on a mill would persist an impossible row.
##   * PASSIVE-SLOT AND WORKER-SLOT SEMANTICS BEYOND THE COUNTS. BAL-CAT-006: "Station worker
##     slots and passive batch slots are distinct", so they are two separate columns here and
##     neither is derived from the other.

const Catalog := preload("res://scripts/core/catalog.gd")
const Milestones := preload("res://scripts/core/milestones.gd")

## Column order of every BUILDING_FACTS row. Named so a transcription cannot be read positionally
## by mistake, and so `_fill_building_columns()` reads like the source table.
const B_FOOTPRINT_X: int = 0
const B_FOOTPRINT_Z: int = 1
const B_WORK_MWU: int = 2
const B_SLOTS: int = 3
const B_MANAGED_INTERIOR: int = 4
const B_ROOM_TILES: int = 5
const B_UNLOCK: int = 6
const B_BASE_STORE_G: int = 7
const B_PASSIVE_SLOTS: int = 8
const B_MAX_BUILDERS: int = 9
const B_FIELD_COUNT: int = 10

## Column order of every FURNITURE_FACTS row, from `gameplay_balance.md` §4.3.
const F_FLOOR_X: int = 0
const F_FLOOR_Z: int = 1
const F_WORK_MWU: int = 2
const F_USER_SLOTS: int = 3
const F_FIELD_COUNT: int = 4

## Compile-time lengths for the two fact arenas, so `_allocate_columns()` states a constant the
## registry checker can resolve. Decision 0056 fixes both counts -- thirty BuildingDefinition and
## nine FurnitureDefinition rows -- and `_assert_key_sets()` re-checks them against the live
## catalogs on every construction, so a catalog edit cannot leave these stale.
const BUILDING_DEFINITION_COUNT: int = 30
const FURNITURE_DEFINITION_COUNT: int = 9

## `gameplay_balance.md` §4.1 joined with §4.2, one row per BuildingDefinition key. Order within
## this literal is irrelevant: every row is placed by `Catalog.BUILDING_DEFINITION[key]`, so the
## ids come from the compiler and never from this file's layout.
##
## footprint_x, footprint_z, work_mwu, slots, managed_interior, room_tiles, unlock,
## base_store_g, passive_slots, max_builders
const BUILDING_FACTS: Dictionary = {
	"apiary": [3, 3, 180000, 1, 0, 0, 2, 100000, 0, 4],
	"boathouse": [6, 4, 720000, 4, 0, 0, 3, 200000, 0, 4],
	"brewery": [5, 4, 480000, 1, 0, 0, 2, 100000, 4, 4],
	"cellar": [6, 6, 900000, 2, 0, 0, 1, 1000000, 0, 4],
	"composter": [3, 3, 120000, 1, 0, 0, 0, 100000, 4, 4],
	"covered_store": [6, 6, 480000, 2, 0, 0, 0, 1500000, 0, 4],
	"dirt_path": [1, 1, 2000, 0, 0, 0, 0, 0, 0, 4],
	"dryer": [4, 3, 240000, 1, 0, 0, 0, 100000, 4, 4],
	"fence": [1, 1, 12000, 0, 0, 0, 0, 0, 0, 4],
	"fisher_shelter": [4, 3, 240000, 2, 0, 0, 0, 200000, 0, 4],
	"forester_lodge": [4, 4, 240000, 3, 0, 0, 0, 100000, 0, 4],
	"gate": [2, 1, 90000, 0, 0, 0, 0, 0, 0, 4],
	"hall": [12, 10, 2400000, 2, 1, 80, 0, 0, 0, 4],
	"infirmary": [8, 8, 1000000, 2, 1, 36, 1, 0, 0, 4],
	"kitchen": [6, 6, 600000, 2, 0, 0, 0, 100000, 0, 4],
	"lookout": [2, 2, 180000, 1, 0, 0, 1, 0, 0, 4],
	"memorial_garden": [4, 4, 240000, 1, 0, 0, 0, 0, 0, 4],
	"mill": [5, 5, 720000, 2, 0, 0, 1, 100000, 0, 4],
	"nursery": [4, 4, 300000, 2, 0, 0, 3, 100000, 4, 4],
	"open_stockpile": [4, 4, 60000, 0, 0, 0, 0, 400000, 0, 4],
	"paved_path": [1, 1, 6000, 0, 0, 0, 2, 0, 0, 4],
	"preserver": [5, 4, 480000, 2, 0, 0, 1, 100000, 4, 4],
	"quarry_shed": [4, 4, 240000, 3, 0, 0, 0, 100000, 0, 4],
	"residence": [10, 8, 1200000, 0, 1, 48, 0, 0, 0, 4],
	"saltpan": [4, 4, 240000, 1, 0, 0, 1, 100000, 4, 4],
	"stone_wall": [1, 1, 30000, 0, 0, 0, 2, 0, 0, 4],
	"weir": [4, 2, 480000, 1, 0, 0, 2, 100000, 0, 4],
	"well": [2, 2, 240000, 2, 0, 0, 0, 100000, 0, 4],
	"workbench": [3, 3, 180000, 2, 0, 0, 0, 100000, 0, 4],
	"workshop": [6, 6, 720000, 3, 0, 0, 1, 100000, 0, 4],
}

## `gameplay_balance.md` §4.3: floor_x, floor_z, work_mwu, user_slots. A 0x0 floor is §4.3's own
## "0/0 means edge placement" -- the partition and the door occupy a tile EDGE, not a tile.
const FURNITURE_FACTS: Dictionary = {
	"bed": [1, 1, 20000, 1],
	"decoration": [1, 1, 12000, 0],
	"hearth": [2, 1, 60000, 0],
	"interior_door": [0, 0, 12000, 0],
	"interior_partition": [0, 0, 8000, 0],
	"kitchen_bench": [2, 1, 60000, 1],
	"patient_bed": [1, 1, 24000, 1],
	"seat": [1, 1, 10000, 1],
	"shelf": [1, 1, 16000, 0],
}

## BAL-CAT-006: "Only residence, hall, covered_store, and workshop accept the GDD tier-2
## packages". §4.2's upgrade table lists exactly these four rows and no others.
const TIER_TWO_KEYS: Array[String] = ["covered_store", "hall", "residence", "workshop"]

## GDD §5.9 and §4.1's minimum: every building exists at tier 1.
const MIN_TIER: int = 1
const TIER_TWO: int = 2

## The eleven exterior buildings whose key is also a Station key. R-BUILD-DOM-002: "The eleven
## same-named exterior building definitions provide their corresponding Station service only when
## their actual owning building/service conditions pass." Stored as KEYS, resolved to the two
## different id spaces in `_init()`, because the whole point of the ruling is that the ids differ.
const STATION_PROVIDER_KEYS: Array[String] = [
	"brewery", "composter", "dryer", "kitchen", "mill", "nursery",
	"preserver", "saltpan", "well", "workbench", "workshop",
]

## BAL-CAT-011: "each valid interior kitchen_bench's 1 slot". One bench is one furniture
## instance providing one kitchen worker slot -- the ruling adds "Each 2x1 bench is one furniture
## instance, not two slots", so this is 1 and not the bench's 2x1 footprint.
const KITCHEN_BENCH_KEY: String = "kitchen_bench"
const KITCHEN_STATION_KEY: String = "kitchen"
const KITCHEN_BENCH_SLOTS: int = 1

## GDD §5.9's furniture table: "Shelf |1x1 |wood 2 |16 |50000g pantry capacity". BAL-CAT-006:
## "A shelf adds its 50000 g to the pantry service, not to an unrelated building's industrial
## buffer." R-BUILD-DOM-004 keeps all five starter shelves and lets only the four in the valid
## PANTRY room contribute: 4 x 50000 = 200000 g.
const SHELF_KEY: String = "shelf"
const SHELF_PANTRY_CAPACITY_G: int = 50000

## GDD §5.9: "Hearth |2x1 |stone 6 |60 |Heat up to 120 interior tiles", repeated in §5.9's
## managed-heat paragraph as "up to 120 total interior tiles per hearth".
const HEARTH_KEY: String = "hearth"
const HEARTH_HEATED_TILE_CAPACITY: int = 120

## The empty catalog id, GDD §4.2: "empty catalog IDs are -1". Absence, never a refusal channel.
const NO_STATION: int = Catalog.EMPTY_CATALOG_ID

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_BUILDING: StringName = &"UNKNOWN_BUILDING_DEFINITION"
const REFUSE_UNKNOWN_FURNITURE: StringName = &"UNKNOWN_FURNITURE_DEFINITION"
const REFUSE_NO_STATION_SERVICE: StringName = &"NO_STATION_SERVICE"
const REFUSE_INVALID_TIER: StringName = &"INVALID_TIER"

# --- compiled fact columns, indexed by compiled definition id (allocated once) -----------------

var _b_footprint_x: PackedInt32Array = PackedInt32Array()
var _b_footprint_z: PackedInt32Array = PackedInt32Array()
var _b_work_mwu: PackedInt64Array = PackedInt64Array()
var _b_slots: PackedInt32Array = PackedInt32Array()
var _b_room_tiles: PackedInt32Array = PackedInt32Array()
var _b_unlock: PackedInt32Array = PackedInt32Array()
var _b_base_store_g: PackedInt64Array = PackedInt64Array()
var _b_passive_slots: PackedInt32Array = PackedInt32Array()
var _b_max_builders: PackedInt32Array = PackedInt32Array()
var _b_managed_interior: PackedByteArray = PackedByteArray()
var _b_tier_two_allowed: PackedByteArray = PackedByteArray()

## Building id -> Station id, or NO_STATION. The explicit provider mapping R-BUILD-DOM-002
## requires: "Import by the field's named domain and bind through explicit provider mappings."
var _b_station: PackedInt32Array = PackedInt32Array()

var _f_floor_x: PackedInt32Array = PackedInt32Array()
var _f_floor_z: PackedInt32Array = PackedInt32Array()
var _f_work_mwu: PackedInt64Array = PackedInt64Array()
var _f_user_slots: PackedInt32Array = PackedInt32Array()

## Furniture id -> the Station service one instance provides, or NO_STATION. Only kitchen_bench
## has an entry today; a furniture kind with no service entry provides none, and a zero here
## would be `brewery` rather than "nothing", which is why the empty value is -1.
var _f_station: PackedInt32Array = PackedInt32Array()
var _f_station_slots: PackedInt32Array = PackedInt32Array()

var _building_count: int = 0
var _furniture_count: int = 0
var _station_count: int = 0


func _init() -> void:
	"""Compile the fact columns from the two catalogs, asserting the key sets match exactly."""
	_building_count = Catalog.BUILDING_DEFINITION.size()
	_furniture_count = Catalog.FURNITURE_DEFINITION.size()
	_station_count = Catalog.STATION.size()
	_assert_key_sets()
	_allocate_columns()
	_fill_building_columns()
	_fill_furniture_columns()
	_bind_stations()
	_assert_station_binding()


func _assert_key_sets() -> void:
	"""Refuse to construct unless every catalog key has a fact row and every fact row a key."""
	assert(_building_count == BUILDING_DEFINITION_COUNT,
		"BUILDING_DEFINITION_COUNT must equal the compiled BuildingDefinition row count")
	assert(_furniture_count == FURNITURE_DEFINITION_COUNT,
		"FURNITURE_DEFINITION_COUNT must equal the compiled FurnitureDefinition row count")
	assert(BUILDING_FACTS.size() == _building_count,
		"BUILDING_FACTS must carry exactly one row per compiled BuildingDefinition key")
	assert(FURNITURE_FACTS.size() == _furniture_count,
		"FURNITURE_FACTS must carry exactly one row per compiled FurnitureDefinition key")
	for key: String in BUILDING_FACTS.keys():
		assert(Catalog.BUILDING_DEFINITION.has(key),
			"BUILDING_FACTS names '%s', which is not a BuildingDefinition key" % key)
		assert((BUILDING_FACTS[key] as Array).size() == B_FIELD_COUNT,
			"building row '%s' must carry exactly %d fields" % [key, B_FIELD_COUNT])
	for key: String in FURNITURE_FACTS.keys():
		assert(Catalog.FURNITURE_DEFINITION.has(key),
			"FURNITURE_FACTS names '%s', which is not a FurnitureDefinition key" % key)
		assert((FURNITURE_FACTS[key] as Array).size() == F_FIELD_COUNT,
			"furniture row '%s' must carry exactly %d fields" % [key, F_FIELD_COUNT])


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_b_footprint_x.resize(BUILDING_DEFINITION_COUNT)
	_b_footprint_z.resize(BUILDING_DEFINITION_COUNT)
	_b_work_mwu.resize(BUILDING_DEFINITION_COUNT)
	_b_slots.resize(BUILDING_DEFINITION_COUNT)
	_b_room_tiles.resize(BUILDING_DEFINITION_COUNT)
	_b_unlock.resize(BUILDING_DEFINITION_COUNT)
	_b_base_store_g.resize(BUILDING_DEFINITION_COUNT)
	_b_passive_slots.resize(BUILDING_DEFINITION_COUNT)
	_b_max_builders.resize(BUILDING_DEFINITION_COUNT)
	_b_managed_interior.resize(BUILDING_DEFINITION_COUNT)
	_b_tier_two_allowed.resize(BUILDING_DEFINITION_COUNT)
	_b_station.resize(BUILDING_DEFINITION_COUNT)
	_f_floor_x.resize(FURNITURE_DEFINITION_COUNT)
	_f_floor_z.resize(FURNITURE_DEFINITION_COUNT)
	_f_work_mwu.resize(FURNITURE_DEFINITION_COUNT)
	_f_user_slots.resize(FURNITURE_DEFINITION_COUNT)
	_f_station.resize(FURNITURE_DEFINITION_COUNT)
	_f_station_slots.resize(FURNITURE_DEFINITION_COUNT)


func _fill_building_columns() -> void:
	"""Place every §4.1/§4.2 row at the id `Catalog.BUILDING_DEFINITION` assigns to its key."""
	for key: String in BUILDING_FACTS.keys():
		var row: Array = BUILDING_FACTS[key]
		var id: int = int(Catalog.BUILDING_DEFINITION[key])
		_b_footprint_x[id] = int(row[B_FOOTPRINT_X])
		_b_footprint_z[id] = int(row[B_FOOTPRINT_Z])
		_b_work_mwu[id] = int(row[B_WORK_MWU])
		_b_slots[id] = int(row[B_SLOTS])
		_b_room_tiles[id] = int(row[B_ROOM_TILES])
		_b_unlock[id] = int(row[B_UNLOCK])
		_b_base_store_g[id] = int(row[B_BASE_STORE_G])
		_b_passive_slots[id] = int(row[B_PASSIVE_SLOTS])
		_b_max_builders[id] = int(row[B_MAX_BUILDERS])
		_b_managed_interior[id] = 1 if int(row[B_MANAGED_INTERIOR]) != 0 else 0
		_b_tier_two_allowed[id] = 1 if TIER_TWO_KEYS.has(key) else 0
		assert(Milestones.is_milestone_id(_b_unlock[id]),
			"building '%s' unlock %d is not a Milestone id" % [key, _b_unlock[id]])


func _fill_furniture_columns() -> void:
	"""Place every §4.3 furniture row at its compiled FurnitureDefinition id."""
	for key: String in FURNITURE_FACTS.keys():
		var row: Array = FURNITURE_FACTS[key]
		var id: int = int(Catalog.FURNITURE_DEFINITION[key])
		_f_floor_x[id] = int(row[F_FLOOR_X])
		_f_floor_z[id] = int(row[F_FLOOR_Z])
		_f_work_mwu[id] = int(row[F_WORK_MWU])
		_f_user_slots[id] = int(row[F_USER_SLOTS])


func _bind_stations() -> void:
	"""Resolve the provider mappings through BOTH catalogs, never by assuming a shared id."""
	_b_station.fill(NO_STATION)
	_f_station.fill(NO_STATION)
	_f_station_slots.fill(0)
	for key: String in STATION_PROVIDER_KEYS:
		assert(Catalog.BUILDING_DEFINITION.has(key), "'%s' is not a building key" % key)
		assert(Catalog.STATION.has(key), "'%s' is not a Station key" % key)
		_b_station[int(Catalog.BUILDING_DEFINITION[key])] = int(Catalog.STATION[key])
	var bench_id: int = int(Catalog.FURNITURE_DEFINITION[KITCHEN_BENCH_KEY])
	_f_station[bench_id] = int(Catalog.STATION[KITCHEN_STATION_KEY])
	_f_station_slots[bench_id] = KITCHEN_BENCH_SLOTS


func _assert_station_binding() -> void:
	"""Pin R-BUILD-DOM-002's own worked example, which is the whole point of the two domains.

	"For example kitchen service=3, exterior kitchen building=14, hall building=12, and
	kitchen_bench furniture=5." Every station key must also be provided by exactly one building,
	so a renamed key cannot leave a service with no provider and no error.
	"""
	assert(STATION_PROVIDER_KEYS.size() == _station_count,
		"every Station key must have exactly one exterior building provider")
	assert(int(Catalog.STATION[KITCHEN_STATION_KEY]) == 3, "kitchen service must be 3")
	assert(int(Catalog.BUILDING_DEFINITION[KITCHEN_STATION_KEY]) == 14,
		"the exterior kitchen building must be 14")
	assert(int(Catalog.BUILDING_DEFINITION["hall"]) == 12, "the hall building must be 12")
	assert(int(Catalog.FURNITURE_DEFINITION[KITCHEN_BENCH_KEY]) == 5,
		"kitchen_bench furniture must be 5")


# --- building facts ----------------------------------------------------------------------------

func is_building_id(type_id: int) -> bool:
	"""True when `type_id` addresses one of the thirty compiled BuildingDefinition rows."""
	return type_id >= 0 and type_id < _building_count


func is_furniture_id(type_id: int) -> bool:
	"""True when `type_id` addresses one of the nine compiled FurnitureDefinition rows."""
	return type_id >= 0 and type_id < _furniture_count


func building_count() -> int:
	"""How many BuildingDefinition rows the compiled catalog carries."""
	return _building_count


func furniture_count() -> int:
	"""How many FurnitureDefinition rows the compiled catalog carries."""
	return _furniture_count


func station_count() -> int:
	"""How many Station service keys the compiled catalog carries."""
	return _station_count


func footprint_x_of(type_id: int) -> int:
	"""§4.1 footprint_x in 2 m tiles. Returns 0 for an id no definition carries."""
	return _b_footprint_x[type_id] if is_building_id(type_id) else 0


func footprint_z_of(type_id: int) -> int:
	"""§4.1 footprint_z in 2 m tiles. Returns 0 for an id no definition carries."""
	return _b_footprint_z[type_id] if is_building_id(type_id) else 0


func work_mwu_of(type_id: int) -> int:
	"""§4.1 total construction work in milli-WU. Returns 0 for an unknown id."""
	return _b_work_mwu[type_id] if is_building_id(type_id) else 0


func worker_slots_of(type_id: int) -> int:
	"""§4.1 operational worker slots. BAL-CAT-006 keeps these distinct from passive slots."""
	return _b_slots[type_id] if is_building_id(type_id) else 0


func passive_slots_of(type_id: int) -> int:
	"""§4.2 passive batch slots. A separate constraint from `worker_slots_of()`."""
	return _b_passive_slots[type_id] if is_building_id(type_id) else 0


func max_builders_of(type_id: int) -> int:
	"""§4.2 max_builders; GDD §5.9's "Maximum 4 builders/project unless listed"."""
	return _b_max_builders[type_id] if is_building_id(type_id) else 0


func base_store_g_of(type_id: int) -> int:
	"""§4.2 base_store_g, the main container's capacity in grams.

	BAL-CAT-007: "An exterior building with no operational inventory need has a main container of
	zero capacity until an explicit service needs it", which is why hall and residence are 0 --
	their storage comes from furniture, not from the exterior row.
	"""
	return _b_base_store_g[type_id] if is_building_id(type_id) else 0


func room_tiles_of(type_id: int) -> int:
	"""§4.1 room_tiles: the managed interior's tile count. BAL-CAT-007: nonmanaged rows are 0."""
	return _b_room_tiles[type_id] if is_building_id(type_id) else 0


func has_managed_interior(type_id: int) -> bool:
	"""§4.1 managed_interior as a boolean: hall, residence and infirmary only."""
	return is_building_id(type_id) and _b_managed_interior[type_id] == 1


func unlock_of(type_id: int) -> int:
	"""§4.1's unlock column as a Milestone id (BAL-CAT-002, R-BUILD-DOM-001).

	Returns M0 for an unknown id -- which is why callers gate with `is_building_id()` first and
	`buildings.gd` refuses an unknown type before ever reaching the gate. There is no sentinel
	here to misread: R-BUILD-DOM-001 forbids -1 or an unknown ordinal meaning "unlocked".
	"""
	return _b_unlock[type_id] if is_building_id(type_id) else 0


func accepts_tier(type_id: int, tier: int) -> bool:
	"""True when this definition may exist at `tier`. BAL-CAT-006 restricts tier 2 to four keys."""
	if not is_building_id(type_id) or tier < MIN_TIER:
		return false
	if tier == MIN_TIER:
		return true
	return tier == TIER_TWO and _b_tier_two_allowed[type_id] == 1


# --- furniture facts ---------------------------------------------------------------------------

func floor_x_of(type_id: int) -> int:
	"""§4.3 floor_x. Zero on an edge-placed partition or door, per §4.3's own 0/0 note."""
	return _f_floor_x[type_id] if is_furniture_id(type_id) else 0


func floor_z_of(type_id: int) -> int:
	"""§4.3 floor_z. Zero on an edge-placed partition or door, per §4.3's own 0/0 note."""
	return _f_floor_z[type_id] if is_furniture_id(type_id) else 0


func furniture_work_mwu_of(type_id: int) -> int:
	"""§4.3 work_mwu for one furniture instance, in milli-WU."""
	return _f_work_mwu[type_id] if is_furniture_id(type_id) else 0


func user_slots_of(type_id: int) -> int:
	"""§4.3 user_slots: 1 for bed, patient_bed, seat and kitchen_bench, 0 for the rest."""
	return _f_user_slots[type_id] if is_furniture_id(type_id) else 0


func is_edge_furniture(type_id: int) -> bool:
	"""True for §4.3's edge-placed kinds, whose floor footprint is 0x0 by that table's own note."""
	return is_furniture_id(type_id) and _f_floor_x[type_id] == 0 and _f_floor_z[type_id] == 0


func furniture_bit_of(type_id: int) -> int:
	"""R-BUILD-DOM-003: `furniture_bit(i) = 1 << i` for a VALIDATED FurnitureDefinition id.

	Returns 0 -- no bit -- for an id outside 0..8, which is why `buildings.gd` validates the id
	before it ever contributes to a room mask. 0 is also "contributes nothing", so the two
	readings agree and no invalid id can set a bit.
	"""
	return (1 << type_id) if is_furniture_id(type_id) else 0


func known_furniture_mask() -> int:
	"""Every bit a `Room.furniture_mask` may legally carry: 511 for the nine published kinds."""
	return (1 << _furniture_count) - 1


func shelf_capacity_g_of(type_id: int) -> int:
	"""The pantry capacity one instance adds, in grams. 50000 for a shelf, 0 for anything else.

	BAL-CAT-006 binds that 50000 g to the PANTRY SERVICE specifically, and R-BUILD-DOM-004 keeps
	the starter's fifth, kitchen-owned shelf out of the pantry total. This function answers only
	"what does one shelf contribute"; which shelves count is a room-membership question that
	`buildings.gd`'s `pantry_capacity_g_of_room()` answers from real rows.
	"""
	if not is_furniture_id(type_id):
		return 0
	return SHELF_PANTRY_CAPACITY_G if type_id == int(Catalog.FURNITURE_DEFINITION[SHELF_KEY]) else 0


# --- the Station provider binding ---------------------------------------------------------------

func station_of_building(type_id: int) -> int:
	"""The Station service one exterior building definition provides, or NO_STATION (-1).

	NOT the building id. R-BUILD-DOM-002: eight keys are spelled the same in both domains and
	carry different ids, so `station_of_building(Catalog.BUILDING_DEFINITION["kitchen"])` is 3
	and not 14. A definition with no service returns -1, never 0, because 0 is `brewery`.
	"""
	return _b_station[type_id] if is_building_id(type_id) else NO_STATION


func station_of_furniture(type_id: int) -> int:
	"""The Station service one furniture instance provides, or NO_STATION (-1).

	Only `kitchen_bench` has one today: BAL-CAT-011's second kitchen provider.
	"""
	return _f_station[type_id] if is_furniture_id(type_id) else NO_STATION


func furniture_station_slots_of(type_id: int) -> int:
	"""Worker slots one furniture instance contributes to its service. One per kitchen_bench."""
	return _f_station_slots[type_id] if is_furniture_id(type_id) else 0


func buildings_providing(station_id: int) -> PackedInt32Array:
	"""Every BuildingDefinition id that provides `station_id`, ascending. Cold path; allocates.

	Empty for an unknown station id, and empty is the honest answer: no definition provides a
	service that does not exist. Callers that need readiness must still check live rows.
	"""
	var providers: PackedInt32Array = PackedInt32Array()
	if station_id < 0 or station_id >= _station_count:
		return providers
	for type_id: int in _building_count:
		if _b_station[type_id] == station_id:
			providers.append(type_id)
	return providers


func catalog_slots_for_station(type_id: int, station_id: int) -> int:
	"""Worker slots one exterior building definition offers to `station_id`, 0 when it offers none.

	This is the CATALOG capacity of §4.1's slots column, not availability: R-BUILD-DOM-002's
	"Worker capacities and buffers remain the keyed balance §4.1/4.2 values", with occupancy,
	state, access and inputs enforced elsewhere. An exterior kitchen answers 2, matching GDD
	§5.9's "Cook 2" and its "2 cooking slots".
	"""
	if not is_building_id(type_id) or _b_station[type_id] != station_id:
		return 0
	return _b_slots[type_id]

