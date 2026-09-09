extends "res://test/framework/test_case.gd"
## Coverage for the FishHabitat and FishStock stores and GDD §5.4's fishing arithmetic.
##
## Every expected number below is restated from the specification, never read back out of the
## module under test: §4.2's 32/3 cardinalities and systems_architecture.md §2.2's 96 rows,
## §5.4's nine-row species table transcribed independently here, §5.4's recovery, quota, floor
## and catch formulas evaluated by hand, §5.3's 0..10 skill range, and REQ-SET-047/048/050's
## stated thresholds. Season days are §5.1's 1..12 within a season, which is what
## `SimClock.Calendar.season_day` reports.
##
## §4.2 never states what catalog `FishStock.species_id` is drawn from, so the ids here are
## opaque small integers and no test asserts a meaning for them. `FishHabitat.type` is different:
## GDD §4.2's closing paragraph numbers it from its own domain's ascending ASCII keys, so the
## habitat ordinals below are restated from that contract rather than from the module.

const Fishing := preload("res://scripts/core/fishing.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## GDD §4.2: "One per marked water basin; up to 32" and "3 stocks/habitat".
## systems_architecture.md §2.2 gives FishStock 96 rows, annotated "32*3".
const EXPECTED_HABITAT_CAPACITY: int = 32
const EXPECTED_SPECIES_PER_HABITAT: int = 3
const EXPECTED_STOCK_CAPACITY: int = 96

## GDD §4.2's closing paragraph numbers `HabitatType` from its own ascending ASCII keys, and the
## 2026-09-09 READY_06 ruling §2 fixes those keys as COAST, LAKE, RIVER. Restated here from the
## contract, NOT read back out of catalog.gd or the module under test. Deliberately not §5.4's
## printed River/Lake/Coast table order, which numbers no enum.
const COAST: int = 0
const LAKE: int = 1
const RIVER: int = 2

## §5.4's nine table ROWS, grouped three per habitat in the document's own printed order. These
## are row indices into §5.4's table, not habitat ids and not catalog ids.
const TROUT: int = 0
const DACE: int = 1
const SALMON: int = 2
const PERCH: int = 3
const CARP: int = 4
const WHITEFISH: int = 5
const HERRING: int = 6
const MACKEREL: int = 7
const MUSSEL: int = 8

## GDD §4.3 Season, restated here rather than read from catalog.gd.
const SPRING: int = 0
const SUMMER: int = 1
const AUTUMN: int = 2
const WINTER: int = 3

## REQ-SET-006: "one season as 12 days".
const DAYS_PER_SEASON: int = 12

## §5.4's "Capacity U" column, in milli-U.
const TROUT_K: int = 600000
const DACE_K: int = 900000
const SALMON_K: int = 600000
const PERCH_K: int = 900000
const CARP_K: int = 700000
const WHITEFISH_K: int = 600000
const HERRING_K: int = 1200000
const MACKEREL_K: int = 900000
const MUSSEL_K: int = 1000000

## §5.4: "Initial stocks are 80% of capacity."
const TROUT_INITIAL: int = 480000
const DACE_INITIAL: int = 720000
const SALMON_INITIAL: int = 480000
const PERCH_INITIAL: int = 720000
const CARP_INITIAL: int = 560000
const WHITEFISH_INITIAL: int = 480000
const HERRING_INITIAL: int = 960000
const MACKEREL_INITIAL: int = 720000
const MUSSEL_INITIAL: int = 800000

## Summed capacities per habitat type, and §5.4's `floor(K_total_milli/40)` daily quota.
const RIVER_K_TOTAL: int = 2100000
const LAKE_K_TOTAL: int = 2200000
const COAST_K_TOTAL: int = 3100000
const RIVER_QUOTA: int = 52500
const LAKE_QUOTA: int = 55000
const COAST_QUOTA: int = 77500

## §5.4: "Habitat effort capacity: river 4, lake 6, coast 6."
const RIVER_EFFORT_SLOTS: int = 4
const LAKE_EFFORT_SLOTS: int = 6
const COAST_EFFORT_SLOTS: int = 6

## §5.4's "Spring/Summer/Autumn/Winter availability" column, transcribed independently.
const AVAILABILITY: Array[int] = [
	1000, 800, 1000, 500,
	1000, 1200, 800, 300,
	0, 0, 2000, 0,
	800, 1200, 1000, 600,
	1000, 1300, 1000, 200,
	800, 700, 1000, 1000,
	1200, 1000, 800, 500,
	500, 1500, 1000, 0,
	800, 1000, 1200, 500,
]
## §5.4's "Daily recovery r/1000" column.
const RECOVERY: Array[int] = [80, 120, 100, 100, 80, 90, 120, 100, 60]

## §5.4 conservation numbers.
const MIN_STOCK_PERCENT: int = 30
const HARD_FLOOR_PERCENT: int = 10
const REFUGE_PERCENT: int = 25
## REQ-SET-048's two thresholds.
const DEPLETION_PERCENT: int = 30
const RECOVERY_PERCENT: int = 40

## Trout's 30% minimum stock and 10% hard floor, in milli-U.
const TROUT_MIN_STOCK: int = 180000
const TROUT_HARD_FLOOR: int = 60000
const TROUT_DEPLETION_THRESHOLD: int = 180000
const TROUT_RECOVERY_THRESHOLD: int = 240000

## Opaque species ids: §4.2 never states their catalog (see the module header). These are
## functions rather than constants because `PackedInt32Array([...])` is not a constant
## expression in GDScript.

## §5.4's gear table "Base catch U/cycle": hand net 8, boat 36. In milli-U.
const HAND_NET_BASE_CATCH: int = 8000
const BOAT_BASE_CATCH: int = 36000

## §5.3: "Level=`min(10,floor_sqrt(floor(xp/5000)))`" -- FISH levels run 0..10.
const MAX_SKILL: int = 10

var _fishing: Fishing = null


func before_each() -> void:
	"""Give every test a fresh store with its own directory."""
	_fishing = Fishing.new()


func after_each() -> void:
	"""Drop the store so no directory slot survives into the next test."""
	_fishing = null


func _river_ids() -> PackedInt32Array:
	"""Three opaque species ids for a river habitat."""
	return PackedInt32Array([10, 11, 12])


func _lake_ids() -> PackedInt32Array:
	"""Three opaque species ids for a lake habitat."""
	return PackedInt32Array([20, 21, 22])


func _coast_ids() -> PackedInt32Array:
	"""Three opaque species ids for a coast habitat."""
	return PackedInt32Array([30, 31, 32])


func _river() -> Vector2i:
	"""Create the standard river habitat: type 0, no zone, danger 0, and return its reference."""
	var created: Fishing.OpResult = _fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		_river_ids(), 0, 0, 0)
	assert_true(created.ok, "the standard river habitat must be creatable")
	return created.ref


func _row(ref: Vector2i, species_index: int) -> int:
	"""Resolve one habitat's stock row, asserting the resolution succeeded first."""
	var resolved: IntMath.IntResult = _fishing.stock_row_of(ref, species_index)
	assert_true(resolved.ok, "stock row must resolve for a live habitat and species index")
	return resolved.value


func _population(row: int) -> int:
	"""Read one stock's population, asserting the read succeeded first."""
	var read: IntMath.IntResult = _fishing.population_milli_of(row)
	assert_true(read.ok, "population read must succeed for a live stock row")
	return read.value


# --- schema and the §5.4 species table ---------------------------------------------------------

func test_capacities_match_the_specification() -> void:
	"""GDD §4.2's 32 habitats and 3 stocks each, and systems_architecture.md §2.2's 96 rows."""
	assert_equal(Fishing.FISH_HABITAT_CAPACITY, EXPECTED_HABITAT_CAPACITY,
		"§4.2: FishHabitat is capped at 32 rows")
	assert_equal(Fishing.SPECIES_PER_HABITAT, EXPECTED_SPECIES_PER_HABITAT,
		"§4.2: 3 stocks/habitat")
	assert_equal(Fishing.FISH_STOCK_CAPACITY, EXPECTED_STOCK_CAPACITY,
		"systems_architecture.md §2.2: FishStock is 96 rows, 32*3")
	assert_equal(Fishing.SPECIES_COUNT, 9, "§5.4's table has nine species rows")
	assert_equal(Fishing.EFFORT_SLOTS_BY_TYPE[RIVER], RIVER_EFFORT_SLOTS,
		"§5.4: river effort capacity 4")
	assert_equal(Fishing.EFFORT_SLOTS_BY_TYPE[LAKE], LAKE_EFFORT_SLOTS,
		"§5.4: lake effort capacity 6")
	assert_equal(Fishing.EFFORT_SLOTS_BY_TYPE[COAST], COAST_EFFORT_SLOTS,
		"§5.4: coast effort capacity 6")


func test_habitat_ids_are_the_generated_ascii_order() -> void:
	"""GDD §4.2's closing paragraph and READY_06 §2: COAST=0, LAKE=1, RIVER=2, from the keys."""
	assert_equal(Fishing.HABITAT_COAST, COAST, "COAST sorts first of the three keys")
	assert_equal(Fishing.HABITAT_LAKE, LAKE, "LAKE sorts second")
	assert_equal(Fishing.HABITAT_RIVER, RIVER, "RIVER sorts third")
	assert_equal(Fishing.HABITAT_TYPE_COUNT, 3, "§5.4 defines three habitats")
	assert_false(_fishing.is_habitat_type(3), "there is no fourth habitat type")
	assert_false(_fishing.is_habitat_type(-1), "and no habitat type -1")


func test_species_capacities_transcribe_the_table() -> void:
	"""§5.4's "Capacity U" column, species by species, in milli-U."""
	var expected: Array[int] = [TROUT_K, DACE_K, SALMON_K, PERCH_K, CARP_K, WHITEFISH_K,
		HERRING_K, MACKEREL_K, MUSSEL_K]
	for species: int in Fishing.SPECIES_COUNT:
		var read: IntMath.IntResult = _fishing.species_capacity_milli(species)
		assert_true(read.ok, "every §5.4 species row must have a capacity")
		assert_equal(read.value, expected[species],
			"§5.4 capacity for species %d" % species)


func test_species_recovery_rates_transcribe_the_table() -> void:
	"""§5.4's "Daily recovery r/1000" column, species by species."""
	for species: int in Fishing.SPECIES_COUNT:
		var read: IntMath.IntResult = _fishing.species_recovery_per_1000(species)
		assert_true(read.ok, "every §5.4 species row must have a recovery rate")
		assert_equal(read.value, RECOVERY[species], "§5.4 r/1000 for species %d" % species)


func test_availability_transcribes_every_season() -> void:
	"""§5.4's four availability columns for all nine species, away from any special window."""
	var ordinary_day: int = 6
	for species: int in Fishing.SPECIES_COUNT:
		for season: int in 4:
			var read: IntMath.IntResult = _fishing.availability_per_1000(species, season,
				ordinary_day)
			assert_true(read.ok, "availability must resolve for every species and season")
			assert_equal(read.value, AVAILABILITY[species * 4 + season],
				"§5.4 availability for species %d in season %d" % [species, season])


func test_species_index_addresses_the_table_by_habitat() -> void:
	"""§5.4 groups three species under each habitat, through an EXPLICIT binding.

	The expectations are written per habitat and NEVER as `expected[habitat_type*3 + index]`:
	that expression is only correct while the habitat ids happen to match §5.4's printed row
	order, which the compiled ids do not. See the key-level test below.
	"""
	_assert_species_of(RIVER, [TROUT, DACE, SALMON])
	_assert_species_of(LAKE, [PERCH, CARP, WHITEFISH])
	_assert_species_of(COAST, [HERRING, MACKEREL, MUSSEL])


func _assert_species_of(habitat_type: int, expected: Array[int]) -> void:
	"""Assert one habitat's three §5.4 rows, and that each maps back to that same habitat."""
	for species_index: int in EXPECTED_SPECIES_PER_HABITAT:
		var resolved: IntMath.IntResult = _fishing.species_of(habitat_type, species_index)
		assert_true(resolved.ok, "every habitat type has three species")
		assert_equal(resolved.value, expected[species_index],
			"§5.4 species for habitat %d slot %d" % [habitat_type, species_index])
		var owner: IntMath.IntResult = _fishing.habitat_type_of_species(resolved.value)
		assert_equal(owner.value, habitat_type, "the species must map back to its habitat")


func test_a_river_habitats_species_are_trout_dace_and_salmon_by_key() -> void:
	"""§5.4's River row names trout, dace and salmon -- asserted by KEY, not by computed index.

	This is the test the old `species = habitat_type*3 + species_index` assumption fails: under
	the compiled ids (COAST=0, LAKE=1, RIVER=2) that formula hands a RIVER habitat the coast
	species herring/mackerel/mussel, silently and with no refusal anywhere.
	"""
	var expected: Array[StringName] = [&"trout", &"dace", &"salmon"]
	for species_index: int in EXPECTED_SPECIES_PER_HABITAT:
		var resolved: IntMath.IntResult = _fishing.species_of(RIVER, species_index)
		assert_true(resolved.ok, "a river habitat has three species")
		assert_equal(Fishing.SPECIES_KEYS[resolved.value], expected[species_index],
			"§5.4's river row %d is %s" % [species_index, expected[species_index]])
	var ref: Vector2i = _river()
	for species_index: int in EXPECTED_SPECIES_PER_HABITAT:
		var row: int = _row(ref, species_index)
		var species: int = _fishing.species_of_row(row).value
		assert_equal(Fishing.SPECIES_KEYS[species], expected[species_index],
			"a created river habitat's stock %d is %s" % [species_index, expected[species_index]])


func test_the_species_keys_transcribe_the_printed_table() -> void:
	"""§5.4's "Species" column in the document's printed order, transcribed independently here."""
	var expected: Array[StringName] = [&"trout", &"dace", &"salmon", &"perch", &"carp",
		&"whitefish", &"herring", &"mackerel", &"mussel"]
	assert_equal(Fishing.SPECIES_KEYS.size(), expected.size(), "§5.4 lists nine species")
	for species: int in expected.size():
		assert_equal(Fishing.SPECIES_KEYS[species], expected[species],
			"§5.4's species row %d" % species)


func test_species_lookups_refuse_out_of_range_arguments() -> void:
	"""An index outside §5.4's table is refused, never folded into a neighbouring row."""
	assert_false(_fishing.species_capacity_milli(9).ok, "there is no tenth species")
	assert_false(_fishing.species_capacity_milli(-1).ok, "there is no species -1")
	assert_false(_fishing.species_recovery_per_1000(9).ok, "there is no tenth recovery rate")
	assert_false(_fishing.species_of(3, 0).ok, "there is no fourth habitat type")
	assert_false(_fishing.species_of(0, 3).ok, "a habitat has three species, not four")
	assert_false(_fishing.habitat_type_of_species(9).ok, "there is no tenth species row")


func test_habitat_capacity_is_the_sum_of_its_three_species() -> void:
	"""`K_total_milli` per §5.4's quota clause: the summed capacity of a habitat's species."""
	var river: IntMath.IntResult = _fishing.capacity_milli_for_type(RIVER)
	var lake: IntMath.IntResult = _fishing.capacity_milli_for_type(LAKE)
	var coast: IntMath.IntResult = _fishing.capacity_milli_for_type(COAST)
	assert_equal(river.value, RIVER_K_TOTAL, "river: trout 600 + dace 900 + salmon 600 U")
	assert_equal(lake.value, LAKE_K_TOTAL, "lake: perch 900 + carp 700 + whitefish 600 U")
	assert_equal(coast.value, COAST_K_TOTAL, "coast: herring 1200 + mackerel 900 + mussel 1000 U")
	assert_false(_fishing.capacity_milli_for_type(3).ok, "there is no fourth habitat type")


# --- FishHabitat lifecycle ----------------------------------------------------------------------

func test_create_habitat_writes_every_field() -> void:
	"""Every §4.2 FishHabitat column is written, and none is left at a default."""
	var created: Fishing.OpResult = _fishing.create_habitat(LAKE, EntityDirectory.NULL_REF,
		_lake_ids(), 7, 2, 250)
	assert_true(created.ok, "a well formed lake habitat must be creatable")
	var slot: int = created.value
	assert_equal(_fishing.habitat_type_of(slot).value, LAKE, "the stored type is the lake")
	assert_equal(_fishing.pollution_of(slot).value, 7, "pollution is stored as given")
	assert_equal(_fishing.danger_of(slot).value, 2, "danger is stored as given")
	assert_equal(_fishing.protected_fraction_of(slot).value, 250,
		"protected_fraction is stored as given; its unit is unstated")
	assert_equal(_fishing.habitat_capacity_milli_of(slot).value, LAKE_K_TOTAL,
		"capacity_milli is the summed §5.4 capacity of the habitat's species")
	assert_equal(_fishing.habitat_ref_of(slot), created.ref,
		"the row hands back the reference that owns it")
	assert_equal(_fishing.habitat_count(), 1, "one habitat is live")


func test_effort_slots_come_from_the_habitat_type() -> void:
	"""§5.4 fixes effort capacity per habitat, so no caller can supply a different number."""
	var river_slot: int = _fishing.create_habitat(RIVER, EntityDirectory.NULL_REF, _river_ids(),
		0, 0, 0).value
	var lake_slot: int = _fishing.create_habitat(LAKE, EntityDirectory.NULL_REF, _lake_ids(),
		0, 0, 0).value
	var coast_slot: int = _fishing.create_habitat(COAST, EntityDirectory.NULL_REF, _coast_ids(),
		0, 0, 0).value
	assert_equal(_fishing.effort_slots_of(river_slot).value, RIVER_EFFORT_SLOTS,
		"§5.4: river 4")
	assert_equal(_fishing.effort_slots_of(lake_slot).value, LAKE_EFFORT_SLOTS, "§5.4: lake 6")
	assert_equal(_fishing.effort_slots_of(coast_slot).value, COAST_EFFORT_SLOTS,
		"§5.4: coast 6")


func test_create_habitat_stocks_start_at_eighty_percent() -> void:
	"""§5.4: "Initial stocks are 80% of capacity", per species and not per habitat."""
	var ref: Vector2i = _river()
	var expected_population: Array[int] = [TROUT_INITIAL, DACE_INITIAL, SALMON_INITIAL]
	var expected_capacity: Array[int] = [TROUT_K, DACE_K, SALMON_K]
	for species_index: int in EXPECTED_SPECIES_PER_HABITAT:
		var row: int = _row(ref, species_index)
		assert_equal(_population(row), expected_population[species_index],
			"§5.4: 80%% of capacity for river species %d" % species_index)
		assert_equal(_fishing.stock_capacity_milli_of(row).value,
			expected_capacity[species_index], "§5.4 capacity for river species %d"
			% species_index)
		assert_equal(_fishing.harvested_today_milli_of(row).value, 0,
			"§4.2: empty counters start at 0")
		assert_false(_fishing.is_closed_flag(row), "a new stock is not closed")


func test_stock_rows_are_owner_major() -> void:
	"""§4.2's "3 stocks/habitat" plus §2.2's 96 rows fix `habitat_slot*3 + species_index`."""
	var first: Vector2i = _river()
	var second: Vector2i = _fishing.create_habitat(COAST, EntityDirectory.NULL_REF,
		_coast_ids(), 0, 0, 0).ref
	var first_slot: int = _fishing.habitat_slot_of(first).value
	var second_slot: int = _fishing.habitat_slot_of(second).value
	for species_index: int in EXPECTED_SPECIES_PER_HABITAT:
		assert_equal(_row(first, species_index),
			first_slot * EXPECTED_SPECIES_PER_HABITAT + species_index,
			"the first habitat's rows are contiguous from its slot")
		assert_equal(_row(second, species_index),
			second_slot * EXPECTED_SPECIES_PER_HABITAT + species_index,
			"the second habitat's rows are contiguous from its slot")
	assert_equal(_fishing.species_of_row(_row(second, 2)).value, MUSSEL,
		"the coast habitat's third species is §5.4's mussel")


func test_create_habitat_refuses_bad_fields_without_allocating() -> void:
	"""A refused creation must leave the directory exactly as it found it."""
	var directory: EntityDirectory = _fishing.directory()
	var before: int = directory.live_count(EntityDirectory.KIND_FISH_HABITAT)
	assert_equal(_fishing.create_habitat(3, EntityDirectory.NULL_REF, _river_ids(), 0, 0, 0).error,
		Fishing.REFUSE_INVALID_HABITAT_TYPE, "there is no fourth habitat type")
	assert_equal(_fishing.create_habitat(RIVER, EntityDirectory.NULL_REF, _river_ids(), -1, 0,
		0).error, Fishing.REFUSE_INVALID_POLLUTION, "pollution cannot be negative")
	assert_equal(_fishing.create_habitat(RIVER, EntityDirectory.NULL_REF, _river_ids(), 0, 4,
		0).error, Fishing.REFUSE_INVALID_DANGER, "§5.4: danger 0-3")
	assert_equal(_fishing.create_habitat(RIVER, EntityDirectory.NULL_REF, _river_ids(), 0, -1,
		0).error, Fishing.REFUSE_INVALID_DANGER, "§5.4: danger 0-3")
	assert_equal(_fishing.create_habitat(RIVER, EntityDirectory.NULL_REF, _river_ids(), 0, 0,
		-1).error, Fishing.REFUSE_INVALID_PROTECTED_FRACTION,
		"protected_fraction cannot be negative")
	assert_equal(directory.live_count(EntityDirectory.KIND_FISH_HABITAT), before,
		"a refused creation allocates no directory slot")
	assert_equal(_fishing.habitat_count(), 0, "a refused creation creates no habitat")


func test_create_habitat_refuses_bad_species_ids() -> void:
	"""§4.2 gives a habitat three stocks; ids are range-checked and must be distinct."""
	assert_equal(_fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		PackedInt32Array([1, 2]), 0, 0, 0).error, Fishing.REFUSE_SPECIES_SET_SIZE,
		"a habitat needs exactly three stock ids")
	assert_equal(_fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		PackedInt32Array([1, 2, 3, 4]), 0, 0, 0).error, Fishing.REFUSE_SPECIES_SET_SIZE,
		"a habitat has no fourth stock")
	assert_equal(_fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		PackedInt32Array([1, -2, 3]), 0, 0, 0).error, Fishing.REFUSE_INVALID_SPECIES_ID,
		"no compiled catalog id is negative")
	assert_equal(_fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		PackedInt32Array([5, 6, 5]), 0, 0, 0).error, Fishing.REFUSE_DUPLICATE_SPECIES_ID,
		"two stocks of one habitat cannot carry the same species id")
	assert_equal(_fishing.habitat_count(), 0, "no refusal created a habitat")


func test_create_habitat_validates_its_zone_reference() -> void:
	"""§4.2's `zone: EntityRef` must address a live HarvestZone, or be the null reference."""
	var directory: EntityDirectory = _fishing.directory()
	var zone: Vector2i = directory.create(EntityDirectory.KIND_HARVEST_ZONE)
	var bound: Fishing.OpResult = _fishing.create_habitat(RIVER, zone, _river_ids(), 0, 0, 0)
	assert_true(bound.ok, "a live harvest-zone reference is accepted")
	assert_equal(_fishing.habitat_zone_ref_of(bound.value), zone, "the zone reference is stored")
	directory.destroy(zone)
	assert_equal(_fishing.create_habitat(LAKE, zone, _lake_ids(), 0, 0, 0).error,
		Fishing.REFUSE_INVALID_ZONE_REF, "a stale zone reference is refused")
	var resident: Vector2i = directory.create(EntityDirectory.KIND_RESIDENT)
	assert_equal(_fishing.create_habitat(LAKE, resident, _lake_ids(), 0, 0, 0).error,
		Fishing.REFUSE_INVALID_ZONE_REF, "a reference of the wrong kind is refused")


func test_unbound_habitat_keeps_the_null_zone_reference() -> void:
	"""§5.1 puts a basin of each type on the map whether or not a zone has been designated."""
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	assert_equal(_fishing.habitat_zone_ref_of(slot), EntityDirectory.NULL_REF,
		"§4.2: empty references are (-1, 0)")


func test_destroy_habitat_releases_its_stocks_and_slot() -> void:
	"""Destroying a habitat empties its three-row stock block and frees its directory slot."""
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	var row: int = _row(ref, 0)
	var destroyed: Fishing.OpResult = _fishing.destroy_habitat(ref)
	assert_true(destroyed.ok, "a live habitat can be destroyed")
	assert_equal(destroyed.value, EXPECTED_SPECIES_PER_HABITAT, "three stock rows are released")
	assert_false(_fishing.is_habitat_present(slot), "the habitat row is empty")
	assert_false(_fishing.is_stock_present(row), "its stock rows are empty")
	assert_equal(_fishing.habitat_count(), 0, "no habitat is live")
	assert_equal(_fishing.directory().live_count(EntityDirectory.KIND_FISH_HABITAT), 0,
		"the directory slot is freed")
	assert_false(_fishing.destroy_habitat(ref).ok, "the stale reference is refused afterwards")


func test_destroy_habitat_refuses_while_an_effort_slot_is_reserved() -> void:
	"""A live reservation would be stranded, so the destroy is refused rather than orphaning it."""
	var ref: Vector2i = _river()
	assert_true(_fishing.reserve_effort_slot(ref).ok, "the first effort slot is free")
	assert_equal(_fishing.destroy_habitat(ref).error, Fishing.REFUSE_EFFORT_SLOTS_RESERVED,
		"a habitat with a reserved effort slot cannot be destroyed")
	assert_true(_fishing.release_effort_slot(ref).ok, "the reservation can be released")
	assert_true(_fishing.destroy_habitat(ref).ok, "and then the habitat can be destroyed")


func test_habitat_capacity_is_thirty_two() -> void:
	"""§4.2's "up to 32" is enforced by the directory's own FISH_HABITAT capacity."""
	for index: int in EXPECTED_HABITAT_CAPACITY:
		assert_true(_fishing.create_habitat(RIVER, EntityDirectory.NULL_REF, _river_ids(),
			0, 0, 0).ok, "habitat %d fits" % index)
	assert_equal(_fishing.habitat_count(), EXPECTED_HABITAT_CAPACITY, "32 habitats are live")
	var overflow: Fishing.OpResult = _fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		_river_ids(), 0, 0, 0)
	assert_false(overflow.ok, "the thirty-third habitat is refused")
	assert_equal(overflow.error, &"CAPACITY_FISH_HABITAT",
		"ARCH-ID-004's per-store capacity refusal")


func test_clear_releases_every_directory_slot() -> void:
	"""Dropping the store must not strand allocated slots in a directory it shares."""
	var directory: EntityDirectory = EntityDirectory.new()
	var fishing: Fishing = Fishing.new(directory)
	fishing.create_habitat(RIVER, EntityDirectory.NULL_REF, _river_ids(), 0, 0, 0)
	fishing.create_habitat(LAKE, EntityDirectory.NULL_REF, _lake_ids(), 0, 0, 0)
	assert_equal(directory.live_count(EntityDirectory.KIND_FISH_HABITAT), 2, "two are live")
	fishing.clear()
	assert_equal(directory.live_count(EntityDirectory.KIND_FISH_HABITAT), 0,
		"clear() releases every habitat's directory slot")
	assert_equal(fishing.habitat_count(), 0, "and empties the live list")


func test_live_habitat_list_is_ascending_and_bounded() -> void:
	"""A daily sweep iterates habitats in slot order, not in creation or hash order."""
	var first: Vector2i = _river()
	var second: Vector2i = _fishing.create_habitat(LAKE, EntityDirectory.NULL_REF, _lake_ids(),
		0, 0, 0).ref
	_fishing.destroy_habitat(first)
	var third: Vector2i = _fishing.create_habitat(COAST, EntityDirectory.NULL_REF, _coast_ids(),
		0, 0, 0).ref
	assert_equal(_fishing.habitat_count(), 2, "two habitats remain live")
	var previous: int = -1
	for index: int in _fishing.habitat_count():
		var slot: IntMath.IntResult = _fishing.live_habitat_slot_at(index)
		assert_true(slot.value > previous, "live habitat slots ascend")
		previous = slot.value
	assert_false(_fishing.live_habitat_slot_at(2).ok, "an index past the end is refused")
	assert_false(_fishing.live_habitat_slot_at(-1).ok, "a negative index is refused")


func test_readers_refuse_absent_rows() -> void:
	"""No reader answers for a row that holds nothing; §4.2's defaults are not valid answers."""
	assert_false(_fishing.habitat_type_of(0).ok, "an empty habitat slot has no type")
	assert_false(_fishing.habitat_capacity_milli_of(0).ok, "and no capacity")
	assert_false(_fishing.effort_slots_of(EXPECTED_HABITAT_CAPACITY).ok, "nor does slot 32")
	assert_false(_fishing.population_milli_of(0).ok, "an empty stock row has no population")
	assert_false(_fishing.stock_capacity_milli_of(EXPECTED_STOCK_CAPACITY).ok,
		"nor does row 96")
	assert_false(_fishing.species_id_of(0).ok, "nor a species id")
	assert_false(_fishing.harvested_today_milli_of(0).ok, "nor a daily total")
	assert_equal(_fishing.habitat_ref_of(0), EntityDirectory.NULL_REF,
		"§4.2: an empty reference is (-1, 0)")
	assert_equal(_fishing.stock_habitat_ref_of(0), EntityDirectory.NULL_REF,
		"and so is an empty stock's owner")


# --- REQ-SET-050 effort slots -------------------------------------------------------------------

func test_effort_slots_reserve_and_release() -> void:
	"""Reservations count up to §5.4's capacity and back down again."""
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	assert_equal(_fishing.effort_slots_free_of(slot).value, RIVER_EFFORT_SLOTS,
		"a new river habitat has all four slots free")
	for taken: int in RIVER_EFFORT_SLOTS:
		var reserved: Fishing.OpResult = _fishing.reserve_effort_slot(ref)
		assert_equal(reserved.value, taken + 1, "each reservation takes one more slot")
	assert_equal(_fishing.effort_slots_used_of(slot).value, RIVER_EFFORT_SLOTS,
		"all four river slots are taken")
	assert_equal(_fishing.effort_slots_free_of(slot).value, 0, "none is free")
	assert_equal(_fishing.release_effort_slot(ref).value, RIVER_EFFORT_SLOTS - 1,
		"a release gives one back")


func test_occupied_effort_slots_queue_further_fishers() -> void:
	"""REQ-SET-050: a fifth river fisher is refused, so no extra worker multiplies the yield."""
	var ref: Vector2i = _river()
	for _taken: int in RIVER_EFFORT_SLOTS:
		assert_true(_fishing.reserve_effort_slot(ref).ok, "the first four river slots are free")
	assert_true(_fishing.must_queue(ref), "REQ-SET-050: a further fisher must queue")
	var refused: Fishing.OpResult = _fishing.reserve_effort_slot(ref)
	assert_false(refused.ok, "the fifth river reservation is refused, not granted")
	assert_equal(refused.error, Fishing.REFUSE_EFFORT_SLOTS_FULL, "and says why")
	assert_true(_fishing.release_effort_slot(ref).ok, "releasing one opens a slot")
	assert_false(_fishing.must_queue(ref), "so the queued fisher may now be admitted")
	assert_true(_fishing.reserve_effort_slot(ref).ok, "and its reservation succeeds")


func test_lake_and_coast_take_six_fishers() -> void:
	"""§5.4's per-habitat effort capacity really differs: lake 6 and coast 6, not river's 4."""
	var lake: Vector2i = _fishing.create_habitat(LAKE, EntityDirectory.NULL_REF, _lake_ids(),
		0, 0, 0).ref
	for _taken: int in LAKE_EFFORT_SLOTS:
		assert_true(_fishing.reserve_effort_slot(lake).ok, "each of the six lake slots is free")
	assert_false(_fishing.reserve_effort_slot(lake).ok, "the seventh lake fisher must queue")
	var coast: Vector2i = _fishing.create_habitat(COAST, EntityDirectory.NULL_REF, _coast_ids(),
		0, 0, 0).ref
	for _taken: int in COAST_EFFORT_SLOTS:
		assert_true(_fishing.reserve_effort_slot(coast).ok, "each coast slot is free")
	assert_false(_fishing.reserve_effort_slot(coast).ok, "the seventh coast fisher must queue")


func test_release_without_a_reservation_is_refused() -> void:
	"""A release with no matching reservation is a caller error, not something to absorb."""
	var ref: Vector2i = _river()
	var refused: Fishing.OpResult = _fishing.release_effort_slot(ref)
	assert_false(refused.ok, "nothing is reserved, so nothing can be released")
	assert_equal(refused.error, Fishing.REFUSE_NO_EFFORT_SLOT_RESERVED, "and it says so")
	_fishing.reserve_effort_slot(ref)
	_fishing.release_effort_slot(ref)
	assert_false(_fishing.release_effort_slot(ref).ok, "a double release is refused too")


func test_effort_operations_refuse_a_stale_habitat() -> void:
	"""A destroyed habitat cannot admit or release a fisher."""
	var ref: Vector2i = _river()
	_fishing.destroy_habitat(ref)
	assert_equal(_fishing.reserve_effort_slot(ref).error, Fishing.REFUSE_HABITAT_NOT_PRESENT,
		"a stale reference reserves nothing")
	assert_equal(_fishing.release_effort_slot(ref).error, Fishing.REFUSE_HABITAT_NOT_PRESENT,
		"and releases nothing")
	assert_true(_fishing.must_queue(ref), "and admits no fisher")


# --- §5.4 special windows -----------------------------------------------------------------------

func test_herring_spring_run_replaces_the_multiplier() -> void:
	"""§5.4: "Spring days 1-4 multiplier 1500 instead of 1200"."""
	for season_day: int in range(1, 5):
		assert_equal(_fishing.availability_per_1000(HERRING, SPRING, season_day).value, 1500,
			"herring spring day %d runs at 1500" % season_day)
	assert_equal(_fishing.availability_per_1000(HERRING, SPRING, 5).value, 1200,
		"spring day 5 returns to the table's 1200")
	assert_equal(_fishing.availability_per_1000(HERRING, SUMMER, 1).value, 1000,
		"the window is spring only")
	assert_equal(_fishing.availability_per_1000(MACKEREL, SPRING, 1).value, 500,
		"and herring only")


func test_mackerel_has_no_winter_harvest() -> void:
	"""§5.4: "No winter harvest" is the table's own winter 0 for mackerel."""
	assert_equal(_fishing.availability_per_1000(MACKEREL, WINTER, 1).value, 0,
		"mackerel is unavailable all winter")
	assert_equal(_fishing.availability_per_1000(MACKEREL, WINTER, DAYS_PER_SEASON).value, 0,
		"including the last winter day")
	assert_equal(_fishing.availability_per_1000(MACKEREL, SUMMER, 1).value, 1500,
		"but its summer multiplier is 1500")


func test_salmon_is_available_only_in_autumn() -> void:
	"""§5.4 gives salmon 0/0/2000/0, so three seasons yield nothing at all."""
	assert_equal(_fishing.availability_per_1000(SALMON, SPRING, 1).value, 0, "no spring salmon")
	assert_equal(_fishing.availability_per_1000(SALMON, SUMMER, 1).value, 0, "no summer salmon")
	assert_equal(_fishing.availability_per_1000(SALMON, WINTER, 1).value, 0, "no winter salmon")
	assert_equal(_fishing.availability_per_1000(SALMON, AUTUMN, 1).value, 2000,
		"and an autumn multiplier of 2000")


func test_closure_windows_are_exact() -> void:
	"""§5.4's three stated windows, checked on both edges and one day outside each."""
	assert_false(_fishing.is_closure_window(TROUT, SPRING, 4), "trout spring day 4 is open")
	for season_day: int in range(5, 8):
		assert_true(_fishing.is_closure_window(TROUT, SPRING, season_day),
			"trout spring days 5-7 are a spawning closure")
	assert_false(_fishing.is_closure_window(TROUT, SPRING, 8), "trout spring day 8 is open")
	assert_false(_fishing.is_closure_window(TROUT, AUTUMN, 6), "the window is spring only")
	assert_false(_fishing.is_closure_window(SALMON, AUTUMN, 4), "salmon autumn day 4 is the run")
	for season_day: int in range(5, 9):
		assert_true(_fishing.is_closure_window(SALMON, AUTUMN, season_day),
			"salmon autumn days 5-8 are a spawning closure")
	assert_false(_fishing.is_closure_window(SALMON, AUTUMN, 9), "day 9 reopens")
	assert_false(_fishing.is_closure_window(CARP, SPRING, 7), "carp spring day 7 is open")
	for season_day: int in range(8, 11):
		assert_true(_fishing.is_closure_window(CARP, SPRING, season_day),
			"carp spring days 8-10 are closed")
	assert_false(_fishing.is_closure_window(CARP, SPRING, 11), "day 11 reopens")


func test_unwindowed_species_are_never_closed_by_the_calendar() -> void:
	"""§5.4 gives dace "No closure", and no other species has a stated calendar window."""
	for season: int in 4:
		for season_day: int in range(1, DAYS_PER_SEASON + 1):
			assert_false(_fishing.is_closure_window(DACE, season, season_day),
				"dace has no closure in season %d day %d" % [season, season_day])
			assert_false(_fishing.is_closure_window(MUSSEL, season, season_day),
				"mussel's blight is an event, not a calendar window")


func test_salmon_harvest_run_window() -> void:
	"""§5.4: "Autumn days 1-4 harvest run", the only stated run window."""
	for season_day: int in range(1, 5):
		assert_true(_fishing.is_harvest_run(SALMON, AUTUMN, season_day),
			"salmon autumn day %d is the run" % season_day)
	assert_false(_fishing.is_harvest_run(SALMON, AUTUMN, 5), "day 5 is the closure, not the run")
	assert_false(_fishing.is_harvest_run(TROUT, AUTUMN, 1), "no other species has a run window")
	assert_false(_fishing.is_harvest_run(SALMON, SPRING, 1), "and no other season does")


func test_season_and_day_arguments_are_validated() -> void:
	"""§5.1's day numbering is 1..12 within a season; day 0 and day 13 name no day."""
	assert_false(_fishing.availability_per_1000(TROUT, 4, 1).ok, "there is no fifth season")
	assert_false(_fishing.availability_per_1000(TROUT, -1, 1).ok, "nor a season -1")
	assert_false(_fishing.availability_per_1000(TROUT, SPRING, 0).ok, "seasons start at day 1")
	assert_false(_fishing.availability_per_1000(TROUT, SPRING, DAYS_PER_SEASON + 1).ok,
		"and end at day 12")
	assert_true(_fishing.availability_per_1000(TROUT, SPRING, DAYS_PER_SEASON).ok,
		"day 12 is a real day")


func test_stored_closed_bit_and_calendar_window_are_separate() -> void:
	"""§4.2 stores `closed`; §5.4 also closes by calendar. is_harvest_closed() is their union."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_false(_fishing.is_closed_flag(trout_row), "a new stock's stored bit is clear")
	assert_false(_fishing.is_harvest_closed(trout_row, SPRING, 1), "and spring day 1 is open")
	assert_true(_fishing.is_harvest_closed(trout_row, SPRING, 6),
		"but §5.4's window closes spring day 6 without touching the bit")
	assert_false(_fishing.is_closed_flag(trout_row), "the stored bit is still clear")
	assert_true(_fishing.set_closed(ref, 0, true).ok, "the bit can be set explicitly")
	assert_true(_fishing.is_closed_flag(trout_row), "and it stays set")
	assert_true(_fishing.is_harvest_closed(trout_row, SPRING, 1),
		"so spring day 1 is now closed too")
	assert_true(_fishing.set_closed(ref, 0, false).ok, "and it can be cleared")
	assert_false(_fishing.is_harvest_closed(trout_row, SPRING, 1), "reopening the species")


func test_set_closed_refuses_bad_arguments() -> void:
	"""A stale habitat or an out-of-range species index writes no bit."""
	var ref: Vector2i = _river()
	assert_equal(_fishing.set_closed(ref, 3, true).error, Fishing.REFUSE_INVALID_SPECIES_INDEX,
		"a habitat has three species, not four")
	assert_equal(_fishing.set_closed(ref, -1, true).error, Fishing.REFUSE_INVALID_SPECIES_INDEX,
		"nor a species -1")
	_fishing.destroy_habitat(ref)
	assert_equal(_fishing.set_closed(ref, 0, true).error, Fishing.REFUSE_HABITAT_NOT_PRESENT,
		"a destroyed habitat has no stock to close")


func _harvest_repeatedly(ref: Vector2i, species_index: int, amount_milli: int, season: int,
		season_day: int, times: int) -> void:
	"""Take `amount_milli` on `times` separate days, resetting the daily quota between them."""
	for _day: int in times:
		var taken: Fishing.OpResult = _fishing.harvest(ref, species_index, amount_milli, season,
			season_day)
		assert_true(taken.ok, "each day's harvest must be legal: %s" % taken.error)
		_fishing.reset_harvested_today()


# --- §5.4 daily recovery ------------------------------------------------------------------------

func test_daily_recovery_matches_the_stated_formula() -> void:
	"""§5.4: `P'=min(K,P+floor(r*P*(K-P)/(1000*K))+floor(K/200))`, computed by hand.

	Trout: P=480000, K=600000, r=80. floor(80*480000*120000/(1000*600000))=7680, plus external
	recruitment floor(600000/200)=3000, so P' is 490680.
	Dace: P=720000, K=900000, r=120. floor(120*720000*180000/(1000*900000))=17280, plus
	floor(900000/200)=4500, so P' is 741780.
	"""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	var dace_row: int = _row(ref, 1)
	assert_equal(_fishing.daily_recovery_milli(trout_row, SPRING, 1).value, 7680 + 3000,
		"trout gains 7680 logistic plus 3000 recruitment")
	assert_equal(_fishing.recover_stock(trout_row, SPRING, 1).value, 490680,
		"and reaches 490680 milli-U")
	assert_equal(_fishing.daily_recovery_milli(dace_row, SPRING, 1).value, 17280 + 4500,
		"dace gains 17280 logistic plus 4500 recruitment")
	assert_equal(_fishing.recover_stock(dace_row, SPRING, 1).value, 741780,
		"and reaches 741780 milli-U")


func test_recovery_is_capped_at_capacity() -> void:
	"""§5.4's `min(K, ...)`: a full stock gains nothing, and salmon's restock cannot exceed K."""
	var ref: Vector2i = _river()
	var salmon_row: int = _row(ref, 2)
	assert_equal(_fishing.recover_stock(salmon_row, AUTUMN, 1).value, SALMON_K,
		"480000 + 300000 restock is capped at the 600000 capacity")
	assert_equal(_fishing.daily_recovery_milli(salmon_row, AUTUMN, 2).value, 0,
		"a full stock gains nothing")
	assert_equal(_fishing.recover_stock(salmon_row, AUTUMN, 2).value, SALMON_K,
		"and stays exactly at capacity")


func test_salmon_receives_three_hundred_units_at_autumn_day_one() -> void:
	"""§5.4: "Salmon additionally receive 300 U at autumn day 1, capped at K."

	Four days of quota-limited harvest leave P=270000, where the restock is not capped:
	logistic floor(100*270000*330000/(1000*600000))=14850, recruitment 3000, restock 300000.
	"""
	var ref: Vector2i = _river()
	var salmon_row: int = _row(ref, 2)
	_harvest_repeatedly(ref, 2, RIVER_QUOTA, AUTUMN, 1, 4)
	assert_equal(_population(salmon_row), 270000, "four days of quota harvest leave 270000")
	assert_equal(_fishing.daily_recovery_milli(salmon_row, AUTUMN, 2).value, 14850 + 3000,
		"autumn day 2 gains only the logistic and recruitment terms")
	assert_equal(_fishing.daily_recovery_milli(salmon_row, AUTUMN, 1).value,
		14850 + 3000 + 300000, "autumn day 1 adds exactly 300 U on top")
	assert_equal(_fishing.daily_recovery_milli(salmon_row, SPRING, 1).value, 14850 + 3000,
		"spring day 1 is not the salmon restock")


func test_closed_species_still_recover() -> void:
	"""§5.4: "Closed species still recover", by the stored bit and by the calendar alike."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	var salmon_row: int = _row(ref, 2)
	assert_true(_fishing.set_closed(ref, 0, true).ok, "close the trout explicitly")
	assert_true(_fishing.is_harvest_closed(trout_row, SPRING, 1), "the trout is closed")
	assert_equal(_fishing.recover_stock(trout_row, SPRING, 1).value, 490680,
		"and still recovers by the full formula")
	assert_true(_fishing.is_harvest_closed(salmon_row, AUTUMN, 6),
		"salmon autumn day 6 is a spawning closure")
	assert_equal(_fishing.daily_recovery_milli(salmon_row, AUTUMN, 6).value, 9600 + 3000,
		"and the closed salmon still gains 9600 logistic plus 3000 recruitment")


func test_recover_daily_sweeps_every_live_stock() -> void:
	"""The sweep ARCH-SYS-005 will call touches all three stocks of every live habitat."""
	var river: Vector2i = _river()
	var lake: Vector2i = _fishing.create_habitat(LAKE, EntityDirectory.NULL_REF, _lake_ids(),
		0, 0, 0).ref
	var swept: Fishing.OpResult = _fishing.recover_daily(SPRING, 1)
	assert_true(swept.ok, "the sweep runs")
	assert_equal(swept.value, 6, "two habitats of three stocks each recovered")
	assert_equal(_population(_row(river, 0)), 490680, "the river trout advanced")
	assert_equal(_population(_row(lake, 0)), PERCH_INITIAL + 14400 + 4500,
		"and the lake perch advanced by its own r=100 formula")


func test_recover_daily_refuses_an_invalid_calendar() -> void:
	"""A sweep with no real season or day changes nothing at all."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_equal(_fishing.recover_daily(4, 1).error, Fishing.REFUSE_INVALID_SEASON,
		"there is no fifth season")
	assert_equal(_fishing.recover_daily(SPRING, 0).error, Fishing.REFUSE_INVALID_SEASON_DAY,
		"seasons start at day 1")
	assert_equal(_fishing.recover_daily(SPRING, DAYS_PER_SEASON + 1).error,
		Fishing.REFUSE_INVALID_SEASON_DAY, "and end at day 12")
	assert_equal(_population(trout_row), TROUT_INITIAL, "no refused sweep moved a population")


func test_recovery_refuses_absent_rows_and_bad_days() -> void:
	"""Recovery answers only for a live stock on a real day."""
	assert_false(_fishing.daily_recovery_milli(0, SPRING, 1).ok, "row 0 holds no stock")
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_false(_fishing.daily_recovery_milli(trout_row, 4, 1).ok, "there is no fifth season")
	assert_false(_fishing.daily_recovery_milli(trout_row, SPRING, 13).ok, "nor a thirteenth day")
	assert_false(_fishing.recover_stock(trout_row, SPRING, 0).ok, "nor a day 0")
	assert_equal(_population(trout_row), TROUT_INITIAL, "and none of that moved the population")


# --- §5.4 daily quota ---------------------------------------------------------------------------

func test_daily_quota_is_capacity_over_forty() -> void:
	"""§5.4: "floor(K_total_milli/40) milli-U across species (2.5% of capacity)"."""
	var river_slot: int = _fishing.create_habitat(RIVER, EntityDirectory.NULL_REF, _river_ids(),
		0, 0, 0).value
	var lake_slot: int = _fishing.create_habitat(LAKE, EntityDirectory.NULL_REF, _lake_ids(),
		0, 0, 0).value
	var coast_slot: int = _fishing.create_habitat(COAST, EntityDirectory.NULL_REF, _coast_ids(),
		0, 0, 0).value
	assert_equal(_fishing.daily_quota_milli_of(river_slot).value, RIVER_QUOTA,
		"river: floor(2100000/40)")
	assert_equal(_fishing.daily_quota_milli_of(lake_slot).value, LAKE_QUOTA,
		"lake: floor(2200000/40)")
	assert_equal(_fishing.daily_quota_milli_of(coast_slot).value, COAST_QUOTA,
		"coast: floor(3100000/40)")
	assert_false(_fishing.daily_quota_milli_of(EXPECTED_HABITAT_CAPACITY).ok,
		"an absent habitat has no quota")


func test_quota_is_shared_across_a_habitats_species() -> void:
	"""§5.4's quota is the habitat's "across species", so one species can spend all of it."""
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	assert_equal(_fishing.remaining_quota_milli(slot).value, RIVER_QUOTA, "the full quota is free")
	assert_true(_fishing.harvest(ref, 0, RIVER_QUOTA, SPRING, 1).ok, "trout takes all of it")
	assert_equal(_fishing.harvested_today_total_of(slot).value, RIVER_QUOTA,
		"the habitat's daily total is the whole quota")
	assert_equal(_fishing.remaining_quota_milli(slot).value, 0, "nothing is left")
	assert_true(_fishing.is_quota_reached(slot), "so the habitat is done for the day")
	assert_equal(_fishing.harvest(ref, 1, 1, SPRING, 1).error, Fishing.REFUSE_QUOTA_REACHED,
		"and the dace cannot take even one milli-U")


func test_reset_harvested_today_reopens_the_quota() -> void:
	"""The daily counter is zeroed by an explicit sweep; nothing here reads a clock."""
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	var trout_row: int = _row(ref, 0)
	assert_true(_fishing.harvest(ref, 0, RIVER_QUOTA, SPRING, 1).ok, "spend the quota")
	assert_equal(_fishing.harvested_today_milli_of(trout_row).value, RIVER_QUOTA,
		"§4.2's harvested_today_milli accumulated it")
	_fishing.reset_harvested_today()
	assert_equal(_fishing.harvested_today_milli_of(trout_row).value, 0, "the counter is zeroed")
	assert_equal(_fishing.remaining_quota_milli(slot).value, RIVER_QUOTA, "the quota is whole")
	assert_false(_fishing.is_quota_reached(slot), "and the habitat may fish again")


func test_harvest_refuses_more_than_the_remaining_quota() -> void:
	"""A partial delivery would let a cycle book biomass the habitat never released."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	var refused: Fishing.OpResult = _fishing.harvest(ref, 0, RIVER_QUOTA + 1, SPRING, 1)
	assert_false(refused.ok, "one milli-U past the quota is refused, not clamped")
	assert_equal(refused.error, Fishing.REFUSE_QUOTA_REACHED, "with the quota reason")
	assert_equal(_population(trout_row), TROUT_INITIAL, "and nothing was debited")
	assert_equal(_fishing.harvested_today_milli_of(trout_row).value, 0,
		"nor accumulated into the daily total")


# --- §5.4 conservation floors and the intensive-harvest policy ------------------------------------

func test_floor_defaults_to_thirty_percent_of_capacity() -> void:
	"""§5.4: "Conservation defaults: ... minimum stock 30%K"."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_equal(_fishing.floor_percent_for(trout_row, SPRING, 1).value, MIN_STOCK_PERCENT,
		"the default floor is 30% of K")
	assert_equal(_fishing.harvest_floor_milli(trout_row, SPRING, 1).value, TROUT_MIN_STOCK,
		"which is 180000 milli-U for the trout")
	assert_equal(_fishing.allowed_stock_milli(trout_row, SPRING, 1).value,
		TROUT_INITIAL - TROUT_MIN_STOCK, "leaving 300000 milli-U legally takeable")
	assert_false(_fishing.is_intensive_harvest(_fishing.habitat_slot_of(ref).value),
		"a new habitat is not on the intensive policy")


func test_intensive_policy_lowers_the_floor_to_ten_percent() -> void:
	"""§5.4: "Hard harvest floor is 10%K", reachable only through the visible policy flag."""
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	var trout_row: int = _row(ref, 0)
	assert_true(_fishing.set_intensive_harvest(ref, true).ok, "the policy can be enabled")
	assert_true(_fishing.is_intensive_harvest(slot), "and it is visible on the habitat")
	assert_equal(_fishing.floor_percent_for(trout_row, SPRING, 1).value, HARD_FLOOR_PERCENT,
		"the floor becomes the 10% hard floor")
	assert_equal(_fishing.harvest_floor_milli(trout_row, SPRING, 1).value, TROUT_HARD_FLOOR,
		"which is 60000 milli-U for the trout")
	assert_true(_fishing.set_intensive_harvest(ref, false).ok, "and it can be turned off")
	assert_equal(_fishing.floor_percent_for(trout_row, SPRING, 1).value, MIN_STOCK_PERCENT,
		"restoring the 30% minimum stock")


func test_only_the_policy_flag_can_lower_the_floor() -> void:
	"""§5.4: the 30% limit is lowered "never by auto-fallback" -- no argument reaches it.

	The same harvest is refused, then permitted, then refused again, with the visible policy the
	only thing that changed.
	"""
	var ref: Vector2i = _river()
	_harvest_repeatedly(ref, 0, RIVER_QUOTA, SPRING, 1, 5)
	assert_equal(_population(_row(ref, 0)), 217500, "five days of quota leave 217500")
	var trout_row: int = _row(ref, 0)
	var refused: Fishing.OpResult = _fishing.harvest(ref, 0, 40000, SPRING, 1)
	assert_equal(refused.error, Fishing.REFUSE_BELOW_STOCK_FLOOR,
		"40000 would cross the 30% minimum stock")
	assert_true(_fishing.set_intensive_harvest(ref, true).ok, "enable the visible policy")
	assert_equal(_fishing.floor_percent_for(trout_row, SPRING, 1).value, HARD_FLOOR_PERCENT,
		"which is the only thing that changed")
	assert_true(_fishing.harvest(ref, 0, 40000, SPRING, 1).ok, "the same harvest is now legal")
	_fishing.reset_harvested_today()
	assert_true(_fishing.set_intensive_harvest(ref, false).ok, "turn the policy off again")
	assert_equal(_fishing.floor_percent_for(trout_row, SPRING, 1).value, MIN_STOCK_PERCENT,
		"and the floor is immediately back at 30%")
	assert_equal(_fishing.allowed_stock_milli(trout_row, SPRING, 1).value, 0,
		"leaving the stock at 177500 with nothing legally takeable")
	assert_false(_fishing.harvest(ref, 0, 40000, SPRING, 1).ok,
		"so the harvest is refused again with the policy off")


func test_intensive_override_is_prohibited_during_a_closure() -> void:
	"""REQ-SET-047: intensive-harvest override is prohibited while a closure is active."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_true(_fishing.set_intensive_harvest(ref, true).ok, "enable the visible policy")
	assert_equal(_fishing.floor_percent_for(trout_row, SPRING, 4).value, HARD_FLOOR_PERCENT,
		"spring day 4 is open, so the 10% floor applies")
	assert_equal(_fishing.floor_percent_for(trout_row, SPRING, 6).value, MIN_STOCK_PERCENT,
		"spring day 6 is the spawning closure, so the floor returns to 30%")
	assert_false(_fishing.intensive_permitted_for(TROUT, SPRING, 6),
		"REQ-SET-047 prohibits the override for the closed species")
	assert_true(_fishing.intensive_permitted_for(TROUT, SPRING, 4),
		"but not outside the window")
	assert_true(_fishing.intensive_permitted_for(DACE, SPRING, 6),
		"and not for a species that is not closed")


func test_habitat_refuge_is_twenty_five_percent_and_applies_to_nothing() -> void:
	"""§5.4's "25% habitat refuge" default; no harvest path consumes it (see the module header)."""
	var plain: Fishing.OpResult = _fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		_river_ids(), 0, 0, 0)
	var marked: Fishing.OpResult = _fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		_river_ids(), 0, 0, 999)
	assert_equal(_fishing.habitat_refuge_milli_of(plain.value).value,
		RIVER_K_TOTAL * REFUGE_PERCENT / 100, "25% of the river's 2100000 milli-U capacity")
	assert_equal(_fishing.habitat_refuge_milli_of(marked.value).value,
		RIVER_K_TOTAL * REFUGE_PERCENT / 100,
		"protected_fraction does not change it: its unit is unstated")
	assert_equal(_fishing.allowed_stock_milli(_row(marked.ref, 0), SPRING, 1).value,
		_fishing.allowed_stock_milli(_row(plain.ref, 0), SPRING, 1).value,
		"and the refuge takes nothing out of the legally takeable stock")


func test_pollution_changes_no_outcome() -> void:
	"""§4.2 types `pollution`; no clause in the GDD gives it an effect, so nothing reads it."""
	var clean: Fishing.OpResult = _fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		_river_ids(), 0, 0, 0)
	var dirty: Fishing.OpResult = _fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		_river_ids(), 5000, 0, 0)
	assert_equal(_fishing.pollution_of(dirty.value).value, 5000, "the column is stored")
	var clean_row: int = _row(clean.ref, 0)
	var dirty_row: int = _row(dirty.ref, 0)
	assert_equal(_fishing.daily_recovery_milli(dirty_row, SPRING, 1).value,
		_fishing.daily_recovery_milli(clean_row, SPRING, 1).value,
		"recovery is identical under any pollution")
	assert_equal(_fishing.catch_milli(dirty_row, HAND_NET_BASE_CATCH, 3, SPRING, 1).value,
		_fishing.catch_milli(clean_row, HAND_NET_BASE_CATCH, 3, SPRING, 1).value,
		"and so is the catch")


# --- REQ-SET-048 depletion and restocking ----------------------------------------------------------

func test_depletion_and_recovery_thresholds_are_thirty_and_forty() -> void:
	"""REQ-SET-048's two stated levels, deliberately not collapsed into one."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_equal(_fishing.depletion_threshold_milli(trout_row).value, TROUT_DEPLETION_THRESHOLD,
		"30% of the trout's 600000 milli-U capacity")
	assert_equal(_fishing.recovery_threshold_milli(trout_row).value, TROUT_RECOVERY_THRESHOLD,
		"40% of it")
	assert_true(_fishing.recovery_threshold_milli(trout_row).value
		> _fishing.depletion_threshold_milli(trout_row).value,
		"REQ-SET-048's band has two distinct edges")
	assert_false(_fishing.is_depleted(trout_row), "a stock at 80% is not depleted")
	assert_false(_fishing.is_restocking(trout_row), "and is not restocking")


func test_falling_below_thirty_percent_starts_restocking() -> void:
	"""REQ-SET-048: "When fishing stock falls below 30% capacity ... default to restocking"."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_true(_fishing.set_intensive_harvest(ref, true).ok, "the visible policy allows this")
	_harvest_repeatedly(ref, 0, RIVER_QUOTA, SPRING, 1, 5)
	assert_equal(_population(trout_row), 217500, "still above the 30% threshold")
	assert_false(_fishing.is_restocking(trout_row), "so restocking has not started")
	assert_true(_fishing.harvest(ref, 0, RIVER_QUOTA, SPRING, 1).ok, "one more day of quota")
	assert_equal(_population(trout_row), 165000, "takes the stock below 180000")
	assert_true(_fishing.is_depleted(trout_row), "REQ-SET-048's warning condition holds")
	assert_true(_fishing.is_restocking(trout_row), "and restocking is now the default")


func test_restocking_persists_through_the_thirty_to_forty_band() -> void:
	"""REQ-SET-048's hysteresis: set below 30%, cleared only above 40%, unchanged between.

	A single-threshold implementation clears the flag the moment the stock passes 30% again;
	this walks the recovery day by day and requires it to still be set inside the band.
	"""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	_fishing.set_intensive_harvest(ref, true)
	_harvest_repeatedly(ref, 0, RIVER_QUOTA, SPRING, 1, 6)
	assert_true(_fishing.is_restocking(trout_row), "165000 is below the 30% threshold")
	var seen_in_band: bool = false
	for _day: int in 40:
		_fishing.recover_stock(trout_row, SPRING, 1)
		var population: int = _population(trout_row)
		if population >= TROUT_DEPLETION_THRESHOLD and population <= TROUT_RECOVERY_THRESHOLD:
			seen_in_band = seen_in_band or _fishing.is_restocking(trout_row)
		if population > TROUT_RECOVERY_THRESHOLD:
			break
	assert_true(seen_in_band, "the flag stays set inside the 30..40% band")
	assert_true(_population(trout_row) > TROUT_RECOVERY_THRESHOLD, "the stock passed 40%")
	assert_false(_fishing.is_restocking(trout_row), "and only then was restocking cleared")


func test_restocking_blocks_harvest_unless_the_policy_is_visible() -> void:
	"""The interpretation recorded in the module header, stated as behaviour."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	_fishing.set_intensive_harvest(ref, true)
	_harvest_repeatedly(ref, 0, RIVER_QUOTA, SPRING, 1, 6)
	assert_true(_fishing.is_restocking(trout_row), "the stock is restocking")
	assert_true(_fishing.set_intensive_harvest(ref, false).ok, "drop the visible policy")
	var refused: Fishing.OpResult = _fishing.harvest(ref, 0, 1000, SPRING, 1)
	assert_equal(refused.error, Fishing.REFUSE_RESTOCKING, "harvest defaults to restocking")
	assert_equal(_fishing.catch_milli(trout_row, HAND_NET_BASE_CATCH, 3, SPRING, 1).value, 0,
		"and the cycle's catch is nothing")
	assert_true(_fishing.set_intensive_harvest(ref, true).ok, "re-enable the visible policy")
	assert_true(_fishing.harvest(ref, 0, 1000, SPRING, 1).ok, "which overrides the default")


func test_update_restocking_refuses_an_absent_row() -> void:
	"""The hysteresis sweep answers only for a live stock."""
	assert_false(_fishing.update_restocking(0).ok, "row 0 holds no stock")
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	var updated: Fishing.OpResult = _fishing.update_restocking(trout_row)
	assert_true(updated.ok, "a live stock can be re-evaluated")
	assert_equal(updated.value, 0, "and a full stock is not restocking")
	assert_false(_fishing.is_depleted(EXPECTED_STOCK_CAPACITY), "row 96 is not a stock")
	assert_false(_fishing.is_restocking(EXPECTED_STOCK_CAPACITY), "and is not restocking")


# --- §5.4 catch formula ---------------------------------------------------------------------------

func test_abundance_is_clamped_between_two_hundred_and_one_thousand() -> void:
	"""§5.4: `A=clamp(floor(1000*P/K),200,1000)`.

	A stock at 80% of capacity gives 800. Seven quota days under the intensive policy leave the
	trout at 112500, where floor(1000*112500/600000) is 187 and the clamp raises it to 200. A
	salmon restocked to capacity gives exactly 1000.
	"""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_equal(_fishing.abundance_per_1000(trout_row).value, 800, "480000/600000 is 800")
	_fishing.set_intensive_harvest(ref, true)
	_harvest_repeatedly(ref, 0, RIVER_QUOTA, SPRING, 1, 7)
	assert_equal(_population(trout_row), 112500, "seven quota days leave 112500")
	assert_equal(_fishing.abundance_per_1000(trout_row).value, 200,
		"floor(187.5) is clamped up to the stated minimum 200")
	var salmon_row: int = _row(ref, 2)
	_fishing.recover_stock(salmon_row, AUTUMN, 1)
	assert_equal(_population(salmon_row), SALMON_K, "the salmon is back at capacity")
	assert_equal(_fishing.abundance_per_1000(salmon_row).value, 1000, "which is the maximum")


func test_catch_formula_matches_the_gdd() -> void:
	"""§5.4: `floor(base_catch_milli*(1000+50*skill)*A*S/1000000000)`, computed by hand.

	Hand net 8 U, trout in spring: A=800, S=1000. Skill 0 gives 6400 milli-U, skill 3 gives
	floor(8000*1150*800*1000/1000000000)=7360, and skill 10 gives 9600.
	"""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_equal(_fishing.formula_catch_milli(trout_row, HAND_NET_BASE_CATCH, 0, SPRING, 1).value,
		6400, "skill 0 lands 6400 milli-U")
	assert_equal(_fishing.formula_catch_milli(trout_row, HAND_NET_BASE_CATCH, 3, SPRING, 1).value,
		7360, "skill 3 lands 7360 milli-U")
	assert_equal(_fishing.formula_catch_milli(trout_row, HAND_NET_BASE_CATCH, MAX_SKILL, SPRING,
		1).value, 9600, "skill 10 lands 9600 milli-U")
	assert_equal(_fishing.catch_milli(trout_row, HAND_NET_BASE_CATCH, 3, SPRING, 1).value, 7360,
		"and neither the quota nor the floor binds this cycle")


func test_catch_uses_the_seasonal_multiplier() -> void:
	"""`S` is the availability multiplier, so the same gear lands less in a poor season.

	Trout: spring S=1000 and winter S=500, so the winter catch is exactly half.
	"""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_equal(_fishing.formula_catch_milli(trout_row, HAND_NET_BASE_CATCH, 0, WINTER, 1).value,
		3200, "winter's 500 multiplier halves the 6400 spring catch")
	assert_equal(_fishing.formula_catch_milli(trout_row, HAND_NET_BASE_CATCH, 0, SUMMER, 1).value,
		5120, "and summer's 800 multiplier gives 5120")


func test_catch_is_limited_by_the_remaining_quota() -> void:
	"""§5.4: "Limit the result to remaining quota". A boat crew out-fishes the river's quota."""
	var ref: Vector2i = _river()
	var salmon_row: int = _row(ref, 2)
	assert_equal(_fishing.formula_catch_milli(salmon_row, BOAT_BASE_CATCH, MAX_SKILL, AUTUMN,
		1).value, 86400, "the formula alone would land 86400 milli-U")
	assert_equal(_fishing.catch_milli(salmon_row, BOAT_BASE_CATCH, MAX_SKILL, AUTUMN, 1).value,
		RIVER_QUOTA, "but the river's daily quota caps it at 52500")
	assert_true(_fishing.harvest(ref, 2, RIVER_QUOTA, AUTUMN, 1).ok, "spend the whole quota")
	assert_equal(_fishing.catch_milli(salmon_row, BOAT_BASE_CATCH, MAX_SKILL, AUTUMN, 1).value, 0,
		"and the next cycle that day lands nothing")


func test_catch_is_limited_by_the_policy_floor() -> void:
	"""§5.4: "Limit the result to ... allowed stock above policy floor"."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	_harvest_repeatedly(ref, 0, RIVER_QUOTA, SPRING, 1, 5)
	assert_true(_fishing.harvest(ref, 0, 37500, SPRING, 1).ok, "take the stock exactly to 30%")
	_fishing.reset_harvested_today()
	assert_equal(_population(trout_row), TROUT_MIN_STOCK, "the trout sits on its 30% floor")
	assert_equal(_fishing.formula_catch_milli(trout_row, HAND_NET_BASE_CATCH, 0, SPRING, 1).value,
		2400, "the formula alone would still land 2400 milli-U")
	assert_equal(_fishing.allowed_stock_milli(trout_row, SPRING, 1).value, 0,
		"but nothing sits above the floor")
	assert_equal(_fishing.catch_milli(trout_row, HAND_NET_BASE_CATCH, 0, SPRING, 1).value, 0,
		"so the cycle lands nothing")


func test_catch_is_zero_when_closed_or_unavailable() -> void:
	"""A closed or out-of-season species offers nothing; 0 is truthful, not a sentinel."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	var salmon_row: int = _row(ref, 2)
	assert_equal(_fishing.catch_milli(trout_row, HAND_NET_BASE_CATCH, 3, SPRING, 6).value, 0,
		"trout spring day 6 is a spawning closure")
	assert_equal(_fishing.catch_milli(salmon_row, HAND_NET_BASE_CATCH, 3, SPRING, 1).value, 0,
		"salmon has no spring availability at all")
	assert_true(_fishing.set_closed(ref, 0, true).ok, "close the trout explicitly")
	assert_equal(_fishing.catch_milli(trout_row, HAND_NET_BASE_CATCH, 3, SPRING, 1).value, 0,
		"the stored bit closes an otherwise open day")
	assert_true(_fishing.formula_catch_milli(trout_row, HAND_NET_BASE_CATCH, 3, SPRING,
		1).value > 0, "while the bare formula still reports what the gear could take")


func test_catch_refuses_a_skill_outside_zero_to_ten() -> void:
	"""§5.3 caps FISH levels at 10; a level outside 0..10 is refused, never scaled."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_true(_fishing.formula_catch_milli(trout_row, HAND_NET_BASE_CATCH, MAX_SKILL, SPRING,
		1).ok, "skill 10 is a real level")
	var too_high: IntMath.IntResult = _fishing.formula_catch_milli(trout_row,
		HAND_NET_BASE_CATCH, MAX_SKILL + 1, SPRING, 1)
	assert_false(too_high.ok, "skill 11 does not exist")
	assert_equal(StringName(too_high.error), Fishing.REFUSE_INVALID_SKILL_LEVEL, "and says so")
	assert_false(_fishing.formula_catch_milli(trout_row, HAND_NET_BASE_CATCH, -1, SPRING, 1).ok,
		"nor does skill -1")
	assert_false(_fishing.catch_milli(trout_row, HAND_NET_BASE_CATCH, 20, SPRING, 1).ok,
		"skills run 0..10, not 0..20")


func test_catch_refuses_an_unusable_base_catch() -> void:
	"""`base_catch_milli` comes from the gear table (blocker U5), so it is validated, not trusted."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	var negative: IntMath.IntResult = _fishing.formula_catch_milli(trout_row, -1, 3, SPRING, 1)
	assert_false(negative.ok, "a negative base catch is refused")
	assert_equal(StringName(negative.error), Fishing.REFUSE_INVALID_BASE_CATCH, "and says so")
	assert_equal(_fishing.formula_catch_milli(trout_row, 0, 3, SPRING, 1).value, 0,
		"a zero base catch is legal and lands nothing")
	assert_false(_fishing.formula_catch_milli(EXPECTED_STOCK_CAPACITY - 1, HAND_NET_BASE_CATCH,
		3, SPRING, 1).ok, "row 95 belongs to a habitat that was never created")


func test_catch_refuses_overflow_at_the_maximum_skill() -> void:
	"""ARCH-AUTH-003: an enormous base catch is refused, never wrapped into a plausible number."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	var overflowed: IntMath.IntResult = _fishing.formula_catch_milli(trout_row,
		IntMath.INT64_MAX, MAX_SKILL, SPRING, 1)
	assert_false(overflowed.ok, "int64 maximum times 1500 cannot be represented")
	assert_equal(overflowed.value, 0, "and a refusal carries no usable number")
	assert_false(_fishing.formula_catch_milli(trout_row, IntMath.INT64_MAX / 1000, MAX_SKILL,
		SPRING, 1).ok, "nor can a base catch a thousandth of that")
	var large: IntMath.IntResult = _fishing.formula_catch_milli(trout_row, 1000000000, MAX_SKILL,
		SPRING, 1)
	assert_true(large.ok, "a base catch of a million units still computes")
	assert_equal(large.value, 1000000000 * 1500 * 800 * 1000 / 1000000000,
		"exactly, with no wrap")


func test_catch_refuses_an_invalid_calendar() -> void:
	"""Catch answers only for a real season and a real day within it."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_false(_fishing.catch_milli(trout_row, HAND_NET_BASE_CATCH, 3, 4, 1).ok,
		"there is no fifth season")
	assert_false(_fishing.catch_milli(trout_row, HAND_NET_BASE_CATCH, 3, SPRING, 0).ok,
		"seasons start at day 1")
	assert_false(_fishing.catch_milli(trout_row, HAND_NET_BASE_CATCH, 3, SPRING,
		DAYS_PER_SEASON + 1).ok, "and end at day 12")
	assert_false(_fishing.abundance_per_1000(EXPECTED_STOCK_CAPACITY).ok, "row 96 is not a stock")


# --- harvest ---------------------------------------------------------------------------------------

func test_harvest_debits_the_population_and_the_daily_total() -> void:
	"""One debit, atomically, on the stock's own columns."""
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	var dace_row: int = _row(ref, 1)
	var taken: Fishing.OpResult = _fishing.harvest(ref, 1, 12000, SUMMER, 1)
	assert_true(taken.ok, "a legal summer dace harvest")
	assert_equal(taken.value, DACE_INITIAL - 12000, "returns the population left")
	assert_equal(_population(dace_row), DACE_INITIAL - 12000, "which is what the column holds")
	assert_equal(_fishing.harvested_today_milli_of(dace_row).value, 12000,
		"§4.2's harvested_today_milli accumulated the debit")
	assert_equal(_fishing.remaining_quota_milli(slot).value, RIVER_QUOTA - 12000,
		"and the habitat's daily quota shrank by the same amount")
	assert_equal(_population(_row(ref, 0)), TROUT_INITIAL, "no other species was touched")


func test_harvest_refuses_a_closed_species() -> void:
	"""§5.4: ""closed" means no harvest job", by calendar window and by the stored bit."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	var closed: Fishing.OpResult = _fishing.harvest(ref, 0, 1000, SPRING, 6)
	assert_false(closed.ok, "trout spring day 6 is a spawning closure")
	assert_equal(closed.error, Fishing.REFUSE_SPECIES_CLOSED, "with the closure reason")
	assert_equal(_population(trout_row), TROUT_INITIAL, "and nothing was debited")
	assert_true(_fishing.set_closed(ref, 0, true).ok, "close the species explicitly")
	assert_equal(_fishing.harvest(ref, 0, 1000, SPRING, 1).error, Fishing.REFUSE_SPECIES_CLOSED,
		"which closes an otherwise open day")


func test_harvest_refuses_an_unavailable_species() -> void:
	"""A zero seasonal multiplier means no catch at all: salmon out of autumn, mackerel in winter."""
	var ref: Vector2i = _river()
	var salmon: Fishing.OpResult = _fishing.harvest(ref, 2, 1000, SUMMER, 1)
	assert_false(salmon.ok, "salmon has no summer availability")
	assert_equal(salmon.error, Fishing.REFUSE_SPECIES_UNAVAILABLE, "with the availability reason")
	var coast: Vector2i = _fishing.create_habitat(COAST, EntityDirectory.NULL_REF, _coast_ids(),
		0, 0, 0).ref
	assert_equal(_fishing.harvest(coast, 1, 1000, WINTER, 1).error,
		Fishing.REFUSE_SPECIES_UNAVAILABLE, "§5.4: mackerel has no winter harvest")
	assert_true(_fishing.harvest(coast, 1, 1000, SUMMER, 1).ok, "but summer mackerel is fine")


func test_harvest_refuses_a_non_positive_amount() -> void:
	"""A zero or negative debit is a caller error, not a no-op to absorb silently."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_equal(_fishing.harvest(ref, 0, 0, SPRING, 1).error, Fishing.REFUSE_INVALID_AMOUNT,
		"zero is not a harvest")
	assert_equal(_fishing.harvest(ref, 0, -5000, SPRING, 1).error, Fishing.REFUSE_INVALID_AMOUNT,
		"and a negative debit would add biomass")
	assert_equal(_population(trout_row), TROUT_INITIAL, "neither moved the population")
	assert_equal(_fishing.harvested_today_milli_of(trout_row).value, 0,
		"nor the daily total")


func test_harvest_refuses_stale_and_out_of_range_targets() -> void:
	"""A refusal names the condition; no path writes to a row it could not validate."""
	var ref: Vector2i = _river()
	assert_equal(_fishing.harvest(ref, 3, 1000, SPRING, 1).error,
		Fishing.REFUSE_INVALID_SPECIES_INDEX, "a habitat has three species, not four")
	assert_equal(_fishing.harvest(ref, -1, 1000, SPRING, 1).error,
		Fishing.REFUSE_INVALID_SPECIES_INDEX, "nor a species -1")
	assert_equal(_fishing.harvest(ref, 0, 1000, 4, 1).error, Fishing.REFUSE_INVALID_SEASON,
		"there is no fifth season")
	assert_equal(_fishing.harvest(ref, 0, 1000, SPRING, 13).error,
		Fishing.REFUSE_INVALID_SEASON_DAY, "nor a thirteenth day of a season")
	_fishing.destroy_habitat(ref)
	assert_equal(_fishing.harvest(ref, 0, 1000, SPRING, 1).error,
		Fishing.REFUSE_HABITAT_NOT_PRESENT, "and a destroyed habitat holds no stock")


func test_harvest_block_code_explains_an_unavailable_species() -> void:
	"""The public block reason a UI needs, with every argument path naming a condition."""
	var ref: Vector2i = _river()
	var trout_row: int = _row(ref, 0)
	assert_equal(_fishing.harvest_block_code(trout_row, SPRING, 1), Fishing.REFUSE_NONE,
		"an open trout day blocks nothing")
	assert_equal(_fishing.harvest_block_code(trout_row, SPRING, 6),
		Fishing.REFUSE_SPECIES_CLOSED, "the spawning closure is named")
	assert_equal(_fishing.harvest_block_code(_row(ref, 2), SPRING, 1),
		Fishing.REFUSE_SPECIES_UNAVAILABLE, "and so is a zero seasonal multiplier")
	assert_equal(_fishing.harvest_block_code(EXPECTED_STOCK_CAPACITY - 1, SPRING, 1),
		Fishing.REFUSE_STOCK_NOT_PRESENT,
		"an absent row is named rather than reported as fine")
	assert_equal(_fishing.harvest_block_code(trout_row, 4, 1), Fishing.REFUSE_INVALID_SEASON,
		"and so is an impossible season")
	assert_equal(_fishing.harvest_block_code(trout_row, SPRING, 0),
		Fishing.REFUSE_INVALID_SEASON_DAY, "and an impossible day")
