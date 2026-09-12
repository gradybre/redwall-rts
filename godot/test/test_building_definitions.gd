extends "res://test/framework/test_case.gd"
## Coverage for the §4.1-§4.3 catalog facts and R-BUILD-DOM-002's Station provider binding.
##
## Every expected number below is restated from `gameplay_balance.md` §4.1/§4.2/§4.3 or GDD §5.9,
## never read back out of the module: the hall's 12x10 footprint and 2400000 milli-WU, the
## covered store's 1500000 g, the shelf's 50000 g pantry capacity, the eleven service keys and
## their ids from R-BUILD-DOM-002's own table.

const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const Milestones := preload("res://scripts/core/milestones.gd")

## Decision 0056's published counts.
const BUILDING_ROWS: int = 30
const FURNITURE_ROWS: int = 9
const STATION_ROWS: int = 11

## R-BUILD-DOM-002's worked example, spelled out.
const KITCHEN_STATION_ID: int = 3
const KITCHEN_BUILDING_ID: int = 14
const HALL_BUILDING_ID: int = 12
const KITCHEN_BENCH_FURNITURE_ID: int = 5

## GDD §5.9: "Kitchen ... Cook 2 ... Black box;2 cooking slots".
const EXTERIOR_KITCHEN_SLOTS: int = 2

## GDD §5.9: "Shelf |1x1 |wood 2 |16 |50000g pantry capacity".
const SHELF_CAPACITY_G: int = 50000

## §4.1's unlock column, transcribed key by key. BAL-CAT-002 encodes these as Milestone ids.
const EXPECTED_UNLOCKS: Dictionary = {
	"apiary": 2, "boathouse": 3, "brewery": 2, "cellar": 1, "composter": 0,
	"covered_store": 0, "dirt_path": 0, "dryer": 0, "fence": 0, "fisher_shelter": 0,
	"forester_lodge": 0, "gate": 0, "hall": 0, "infirmary": 1, "kitchen": 0,
	"lookout": 1, "memorial_garden": 0, "mill": 1, "nursery": 3, "open_stockpile": 0,
	"paved_path": 2, "preserver": 1, "quarry_shed": 0, "residence": 0, "saltpan": 1,
	"stone_wall": 2, "weir": 2, "well": 0, "workbench": 0, "workshop": 1,
}

## R-BUILD-DOM-002's Station table, transcribed.
const EXPECTED_STATIONS: Dictionary = {
	"brewery": 0, "composter": 1, "dryer": 2, "kitchen": 3, "mill": 4, "nursery": 5,
	"preserver": 6, "saltpan": 7, "well": 8, "workbench": 9, "workshop": 10,
}

var _defs: BuildingDefinitions = null


func before_each() -> void:
	"""A fresh fact table per test; it is immutable, so construction is the only state."""
	_defs = BuildingDefinitions.new()


func _building(key: String) -> int:
	"""The compiled BuildingDefinition id of one key, resolved through the catalog."""
	return int(CatalogScript.BUILDING_DEFINITION[key])


func _furniture(key: String) -> int:
	"""The compiled FurnitureDefinition id of one key, resolved through the catalog."""
	return int(CatalogScript.FURNITURE_DEFINITION[key])


func test_every_catalog_key_has_a_fact_row_and_vice_versa() -> void:
	"""A key in one table and not the other would leave a zero-capacity building that looks legal."""
	assert_equal(_defs.building_count(), BUILDING_ROWS, "thirty building definitions")
	assert_equal(_defs.furniture_count(), FURNITURE_ROWS, "nine furniture definitions")
	assert_equal(_defs.station_count(), STATION_ROWS, "eleven station services")
	assert_equal(BuildingDefinitions.BUILDING_FACTS.size(), BUILDING_ROWS, "thirty fact rows")
	assert_equal(BuildingDefinitions.FURNITURE_FACTS.size(), FURNITURE_ROWS, "nine fact rows")
	for key: String in CatalogScript.BUILDING_DEFINITION.keys():
		assert_true(BuildingDefinitions.BUILDING_FACTS.has(key), "'%s' has a fact row" % key)
	for key: String in CatalogScript.FURNITURE_DEFINITION.keys():
		assert_true(BuildingDefinitions.FURNITURE_FACTS.has(key), "'%s' has a fact row" % key)


func test_every_building_unlock_is_a_valid_milestone_id() -> void:
	"""R-BUILD-DOM-001's acceptance 2: "Every building and recipe unlock validates"."""
	for key: String in EXPECTED_UNLOCKS.keys():
		var type_id: int = _building(key)
		var unlock: int = _defs.unlock_of(type_id)
		assert_equal(unlock, int(EXPECTED_UNLOCKS[key]), "'%s' unlock" % key)
		assert_true(Milestones.is_milestone_id(unlock), "'%s' unlock is a Milestone id" % key)
	assert_equal(EXPECTED_UNLOCKS.size(), BUILDING_ROWS, "all thirty rows are checked")


func test_no_building_unlock_uses_minus_one_or_an_unknown_ordinal() -> void:
	"""R-BUILD-DOM-001: "No published definition may use -1 or an unknown ordinal to mean unlocked"."""
	for type_id: int in _defs.building_count():
		var unlock: int = _defs.unlock_of(type_id)
		assert_true(unlock >= 0 and unlock <= 4, "unlock %d of building %d is in M0..M4"
			% [unlock, type_id])
		assert_false(Milestones.is_unlocked(Milestones.INITIAL_MASK, unlock) and unlock != 0,
			"only an M0 definition may be unlocked by the starting mask")


func test_the_starting_mask_unlocks_exactly_the_start_buildings() -> void:
	"""§5.9 prints `Start` for sixteen rows; those and only those are buildable at mask 1."""
	var unlocked: int = 0
	for key: String in EXPECTED_UNLOCKS.keys():
		var gate: bool = Milestones.is_unlocked(Milestones.INITIAL_MASK, _defs.unlock_of(_building(key)))
		assert_equal(gate, int(EXPECTED_UNLOCKS[key]) == 0, "'%s' at mask 1" % key)
		if gate:
			unlocked += 1
	assert_equal(unlocked, 16, "sixteen §5.9 rows print Start")


func test_a_sparse_mask_still_locks_the_m1_buildings() -> void:
	"""Mask 9 is M0+M3. The mill, workshop, cellar, preserver, saltpan, infirmary and lookout
	are M1 rows and must stay locked, however high the earned ordinal goes."""
	var sparse: int = 9
	for key: String in ["mill", "workshop", "cellar", "preserver", "saltpan", "infirmary",
			"lookout"]:
		assert_false(Milestones.is_unlocked(sparse, _defs.unlock_of(_building(key))),
			"'%s' is an M1 row and must be locked at mask 9" % key)
	for key: String in ["boathouse", "nursery"]:
		assert_true(Milestones.is_unlocked(sparse, _defs.unlock_of(_building(key))),
			"'%s' is an M3 row and mask 9 earns M3" % key)


func test_the_eleven_station_keys_bind_to_their_own_ids() -> void:
	"""R-BUILD-DOM-002's table, checked through both domains rather than by shared spelling."""
	for key: String in EXPECTED_STATIONS.keys():
		assert_equal(int(CatalogScript.STATION[key]), int(EXPECTED_STATIONS[key]),
			"'%s' station id" % key)
		assert_equal(_defs.station_of_building(_building(key)), int(EXPECTED_STATIONS[key]),
			"'%s' building provides its own service" % key)
	assert_equal(EXPECTED_STATIONS.size(), STATION_ROWS, "all eleven services are checked")


func test_a_station_id_is_never_the_building_id_that_provides_it() -> void:
	"""BAL-CAT-011: station "indexes a service domain, not the BuildingDefinition index"."""
	for key: String in EXPECTED_STATIONS.keys():
		assert_true(int(CatalogScript.STATION[key]) != _building(key),
			"'%s' must carry different ids in the two domains" % key)
	assert_equal(_defs.station_of_building(KITCHEN_BUILDING_ID), KITCHEN_STATION_ID,
		"the ruling's example: exterior kitchen building 14 provides service 3")
	assert_equal(_building("kitchen"), KITCHEN_BUILDING_ID, "the kitchen building is 14")
	assert_equal(_building("hall"), HALL_BUILDING_ID, "the hall building is 12")
	assert_equal(_furniture("kitchen_bench"), KITCHEN_BENCH_FURNITURE_ID, "kitchen_bench is 5")


func test_a_building_with_no_service_answers_minus_one_and_not_zero() -> void:
	"""0 is `brewery`. Absence has to be -1 or a hall would read as a brewery."""
	for key: String in ["hall", "residence", "infirmary", "open_stockpile", "fence", "gate"]:
		assert_equal(_defs.station_of_building(_building(key)), BuildingDefinitions.NO_STATION,
			"'%s' provides no Station service" % key)
	assert_equal(BuildingDefinitions.NO_STATION, -1, "GDD §4.2's empty catalog id")
	assert_equal(_defs.station_of_building(-1), BuildingDefinitions.NO_STATION, "unknown id")
	assert_equal(_defs.station_of_building(BUILDING_ROWS), BuildingDefinitions.NO_STATION,
		"an id past the end")


func test_the_kitchen_service_has_two_provider_kinds() -> void:
	"""BAL-CAT-011: one exterior kitchen's 2 cooking slots, or each bench's 1 slot."""
	assert_equal(_defs.catalog_slots_for_station(KITCHEN_BUILDING_ID, KITCHEN_STATION_ID),
		EXTERIOR_KITCHEN_SLOTS, "an exterior kitchen offers two slots")
	assert_equal(_defs.station_of_furniture(KITCHEN_BENCH_FURNITURE_ID), KITCHEN_STATION_ID,
		"a kitchen_bench provides the kitchen service")
	assert_equal(_defs.furniture_station_slots_of(KITCHEN_BENCH_FURNITURE_ID), 1,
		"each 2x1 bench is one furniture instance, not two slots")
	assert_equal(_defs.catalog_slots_for_station(HALL_BUILDING_ID, KITCHEN_STATION_ID), 0,
		"the hall provides NO exterior kitchen service, so its slots are never added again")


func test_no_other_furniture_provides_a_station() -> void:
	"""The bench is the only interior provider the specification names."""
	for key: String in CatalogScript.FURNITURE_DEFINITION.keys():
		if key == "kitchen_bench":
			continue
		assert_equal(_defs.station_of_furniture(_furniture(key)),
			BuildingDefinitions.NO_STATION, "'%s' provides no service" % key)
		assert_equal(_defs.furniture_station_slots_of(_furniture(key)), 0, "and no slots")


func test_buildings_providing_lists_exactly_one_provider_per_service() -> void:
	"""Every service must have a provider, and no service two, or a gate silently never opens."""
	for key: String in EXPECTED_STATIONS.keys():
		var providers: PackedInt32Array = _defs.buildings_providing(int(EXPECTED_STATIONS[key]))
		assert_equal(providers.size(), 1, "'%s' has exactly one exterior provider" % key)
		if providers.size() == 1:
			assert_equal(providers[0], _building(key), "'%s' provides its own service" % key)
	assert_equal(_defs.buildings_providing(-1).size(), 0, "an unknown service has no providers")
	assert_equal(_defs.buildings_providing(STATION_ROWS).size(), 0, "nor an id past the end")


func test_catalog_slots_for_station_refuses_the_wrong_service() -> void:
	"""A mill offers mill slots and nothing else; a wrong-domain integer yields 0, not its slots."""
	assert_equal(_defs.catalog_slots_for_station(_building("mill"), int(EXPECTED_STATIONS["mill"])),
		2, "§4.1 gives the mill two slots")
	assert_equal(_defs.catalog_slots_for_station(_building("mill"), KITCHEN_STATION_ID), 0,
		"a mill offers no kitchen slots")
	assert_equal(_defs.catalog_slots_for_station(_building("workshop"),
		int(EXPECTED_STATIONS["workshop"])), 3, "§4.1 gives the workshop three slots")


func test_the_furniture_bit_is_one_shifted_by_the_definition_id() -> void:
	"""R-BUILD-DOM-003: `furniture_bit(i) = 1 << i`; the nine bits are 1..256 and the mask 511."""
	var expected: Dictionary = {
		"bed": 1, "decoration": 2, "hearth": 4, "interior_door": 8, "interior_partition": 16,
		"kitchen_bench": 32, "patient_bed": 64, "seat": 128, "shelf": 256,
	}
	for key: String in expected.keys():
		assert_equal(_defs.furniture_bit_of(_furniture(key)), int(expected[key]),
			"'%s' bit value" % key)
	assert_equal(_defs.known_furniture_mask(), 511, "the nine known bits are mask 511")
	assert_equal(_defs.furniture_bit_of(-1), 0, "an invalid id contributes no bit")
	assert_equal(_defs.furniture_bit_of(FURNITURE_ROWS), 0, "nor an id past the end")


func test_shelf_capacity_belongs_to_the_shelf_alone() -> void:
	"""BAL-CAT-006: "A shelf adds its 50000 g to the pantry service"."""
	assert_equal(_defs.shelf_capacity_g_of(_furniture("shelf")), SHELF_CAPACITY_G,
		"one shelf is 50000 g")
	assert_equal(SHELF_CAPACITY_G * 4, 200000, "R-BUILD-DOM-004's four pantry shelves")
	for key: String in ["bed", "hearth", "kitchen_bench", "seat", "decoration"]:
		assert_equal(_defs.shelf_capacity_g_of(_furniture(key)), 0,
			"'%s' adds no pantry capacity" % key)
	assert_equal(_defs.shelf_capacity_g_of(-1), 0, "an invalid id adds none")


func test_the_footprints_and_work_match_the_owning_rows() -> void:
	"""A spot check of §4.1 across the size range, including its largest and smallest rows."""
	assert_equal(_defs.footprint_x_of(_building("hall")), 12, "the hall is 12 across")
	assert_equal(_defs.footprint_z_of(_building("hall")), 10, "and 10 deep")
	assert_equal(_defs.work_mwu_of(_building("hall")), 2400000, "and costs 2400 WU")
	assert_equal(_defs.footprint_x_of(_building("fence")), 1, "a fence segment is 1x1")
	assert_equal(_defs.work_mwu_of(_building("dirt_path")), 2000, "a dirt path costs 2 WU")
	assert_equal(_defs.footprint_z_of(_building("weir")), 2, "the weir is 4x2")


func test_managed_interiors_and_room_tiles_agree_with_bal_cat_007() -> void:
	"""§4.1: only hall, residence and infirmary are managed; BAL-CAT-007 zeroes the rest."""
	var managed: int = 0
	for type_id: int in _defs.building_count():
		if _defs.has_managed_interior(type_id):
			managed += 1
			assert_true(_defs.room_tiles_of(type_id) > 0, "a managed interior has room tiles")
		else:
			assert_equal(_defs.room_tiles_of(type_id), 0, "a nonmanaged row has room_tiles=0")
	assert_equal(managed, 3, "three managed interiors")
	assert_equal(_defs.room_tiles_of(_building("hall")), 80, "the hall's interior is 10x8")
	assert_equal(_defs.room_tiles_of(_building("residence")), 48, "the residence's is 8x6")
	assert_equal(_defs.room_tiles_of(_building("infirmary")), 36, "the infirmary's is 6x6")


func test_base_store_capacities_are_the_section_4_2_values() -> void:
	"""BAL-CAT-007's zero-capacity policy and §4.2's explicit gram capacities."""
	assert_equal(_defs.base_store_g_of(_building("covered_store")), 1500000, "covered store")
	assert_equal(_defs.base_store_g_of(_building("open_stockpile")), 400000, "open stockpile")
	assert_equal(_defs.base_store_g_of(_building("cellar")), 1000000, "cellar")
	assert_equal(_defs.base_store_g_of(_building("fisher_shelter")), 200000, "gear locker")
	assert_equal(_defs.base_store_g_of(_building("kitchen")), 100000, "a production station")
	assert_equal(_defs.base_store_g_of(_building("hall")), 0,
		"BAL-CAT-007: no operational inventory need means zero capacity")
	assert_equal(_defs.base_store_g_of(_building("open_stockpile")) * 4, 1600000,
		"§5.9's four starter stockpiles provide 1600000 g")


func test_passive_and_worker_slots_are_separate_columns() -> void:
	"""BAL-CAT-006: "Station worker slots and passive batch slots are distinct"."""
	assert_equal(_defs.worker_slots_of(_building("dryer")), 1, "the dryer has one worker slot")
	assert_equal(_defs.passive_slots_of(_building("dryer")), 4, "and four passive batch slots")
	assert_equal(_defs.worker_slots_of(_building("workshop")), 3, "the workshop has three")
	assert_equal(_defs.passive_slots_of(_building("workshop")), 0, "and no passive slots")
	assert_equal(_defs.max_builders_of(_building("hall")), 4, "§5.9's maximum 4 builders")


func test_tier_two_is_restricted_to_the_four_upgradeable_keys() -> void:
	"""BAL-CAT-006: "Only residence, hall, covered_store, and workshop accept the tier-2 packages"."""
	for key: String in ["hall", "residence", "covered_store", "workshop"]:
		assert_true(_defs.accepts_tier(_building(key), 2), "'%s' accepts tier 2" % key)
	for key: String in ["mill", "kitchen", "cellar", "preserver", "well", "workbench"]:
		assert_false(_defs.accepts_tier(_building(key), 2), "'%s' has no tier-2 package" % key)
		assert_true(_defs.accepts_tier(_building(key), 1), "but it exists at tier 1")
	assert_false(_defs.accepts_tier(_building("hall"), 0), "tier 0 is not a tier")
	assert_false(_defs.accepts_tier(_building("hall"), 3), "there is no tier 3")
	assert_false(_defs.accepts_tier(-1, 1), "an unknown definition accepts nothing")


func test_furniture_floor_sizes_and_user_slots_match_section_4_3() -> void:
	"""§4.3's own rows, including its "0/0 means edge placement" note."""
	assert_equal(_defs.floor_x_of(_furniture("kitchen_bench")), 2, "a bench is 2x1")
	assert_equal(_defs.floor_z_of(_furniture("kitchen_bench")), 1, "a bench is 2x1")
	assert_equal(_defs.floor_x_of(_furniture("hearth")), 2, "a hearth is 2x1")
	assert_equal(_defs.user_slots_of(_furniture("bed")), 1, "a bed seats one")
	assert_equal(_defs.user_slots_of(_furniture("hearth")), 0, "a hearth seats none")
	assert_equal(_defs.furniture_work_mwu_of(_furniture("bed")), 20000, "a bed costs 20 WU")
	assert_true(_defs.is_edge_furniture(_furniture("interior_partition")), "a partition is edge")
	assert_true(_defs.is_edge_furniture(_furniture("interior_door")), "a door is edge")
	assert_false(_defs.is_edge_furniture(_furniture("shelf")), "a shelf occupies a floor tile")


func test_unknown_ids_answer_zero_and_never_another_row() -> void:
	"""An out-of-range id must not silently index the last row."""
	for bad: int in [-1, BUILDING_ROWS, BUILDING_ROWS + 100]:
		assert_false(_defs.is_building_id(bad), "%d is not a building id" % bad)
		assert_equal(_defs.footprint_x_of(bad), 0, "no footprint")
		assert_equal(_defs.worker_slots_of(bad), 0, "no slots")
		assert_equal(_defs.base_store_g_of(bad), 0, "no capacity")
		assert_false(_defs.has_managed_interior(bad), "no managed interior")
	for bad: int in [-1, FURNITURE_ROWS]:
		assert_false(_defs.is_furniture_id(bad), "%d is not a furniture id" % bad)
		assert_equal(_defs.user_slots_of(bad), 0, "no user slots")
		assert_false(_defs.is_edge_furniture(bad), "and it is not edge furniture")
