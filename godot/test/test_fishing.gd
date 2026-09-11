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
const ForageScript := preload("res://scripts/core/forage.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")

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

## Ruling §5's claim slice is one row per Expedition; §2.1 gives the Expedition store 512 rows.
## Its payload is six I32 columns plus one B8: 512*6*4 + 512 = 12800 bytes.
const EXPECTED_EFFORT_CLAIM_CAPACITY: int = 512
const EXPECTED_EFFORT_CLAIM_BYTES: int = 12800
## Decision 0027's ratified addition: effort_used 32*4, restocking 96*1, intensive_harvest 32*1.
const EXPECTED_FISHING_STATE_BYTES: int = 256

## §5.4's "Workers/effort slots" column, second number, restated here from the gear table.
const NET_EFFORT_SLOTS: int = 1
const TRAP_EFFORT_SLOTS: int = 1
const ICE_KIT_EFFORT_SLOTS: int = 1
const WEIR_EFFORT_SLOTS: int = 2
const BOAT_EFFORT_SLOTS: int = 2

## §5.4's "Initial stocks are 80% of capacity", summed per habitat over 2100/2200/3100 U.
const RIVER_INITIAL_BIOMASS: int = 1680000
const LAKE_INITIAL_BIOMASS: int = 1760000
const COAST_INITIAL_BIOMASS: int = 2480000
## Ruling §8B: the specified initial estuary is three habitats and nine stocks, and no more.
const EXPECTED_ESTUARY_HABITATS: int = 3
const EXPECTED_ESTUARY_STOCKS: int = 9

## GDD §4.3 ZoneType, restated here rather than read from catalog.gd.
const ZONE_FISH: int = 0
const ZONE_FORAGE: int = 2
## GDD §4.3 JobKind.FISH and JobState.CANCELLED, likewise restated.
const JOB_KIND_FISH: int = 2
const JOB_STATE_CANCELLED: int = 7

## Ruling §5's exact latch boundaries, worked by hand against mussel's 1000000 milli-U capacity:
## 30% of K is 300000 and 40% is 400000, and §5.4's midnight formula carries 380852 to exactly
## 400000 -- `380852 + floor(60*380852*619148/(1000*1000000)) + floor(1000000/200)` -- and 400000
## on to 419400.
const MUSSEL_DEPLETION_BOUNDARY: int = 300000
const MUSSEL_RECOVERY_BOUNDARY: int = 400000
const MUSSEL_ONE_DAY_BELOW_RECOVERY: int = 380852
const MUSSEL_ABOVE_RECOVERY: int = 419400
## Five §5.4 midnights from 299999 reach 391726; the drain back to 380852 is 10874 milli-U, well
## inside the coast habitat's 77500 daily quota.
const MUSSEL_DRAIN_START: int = 299999
const MUSSEL_AFTER_FIVE_RECOVERIES: int = 391726
## §5.4's coast species order under the compiled COAST=0 ordinal: herring, mackerel, mussel.
const MUSSEL_INDEX: int = 2

var _fishing: Fishing = null
var _zones: ForageScript = null
var _jobs: JobsScript = null
var _residents: ResidentsScript = null
var _priorities: PrioritiesScript = null
var _schedule: ScheduleScript = null


func before_each() -> void:
	"""Give every test a fresh store with its own directory."""
	_fishing = Fishing.new()


func after_each() -> void:
	"""Drop the store so no directory slot survives into the next test."""
	_fishing = null
	_zones = null
	_jobs = null
	_residents = null
	_priorities = null
	_schedule = null


func _use_owner_stores() -> void:
	"""Rebuild the fishery over live HarvestZone and Job stores sharing one entity directory.

	Effort claims validate an Expedition and its coordinator Job through the directory, and
	ruling §8B's designation binding walks forage.gd's HarvestZone rows, so all three stores must
	agree on one directory; the fishery adopts the Job store's.
	"""
	_residents = ResidentsScript.new()
	_priorities = PrioritiesScript.new()
	_schedule = ScheduleScript.new(_residents.needs())
	_jobs = JobsScript.new(_residents, _priorities, _schedule)
	_zones = ForageScript.new(null, _jobs)
	_fishing = Fishing.new(null, _zones, _jobs)


func _make_expedition() -> Vector2i:
	"""Allocate one Expedition reference through the shared directory.

	§4.2 declares the Expedition row and no module implements its columns; the directory does
	carry KIND_EXPEDITION and its typed rows, which is all an effort claim is indexed by.
	"""
	var ref: Vector2i = _fishing.directory().create(EntityDirectory.KIND_EXPEDITION)
	assert_true(ref != EntityDirectory.NULL_REF, "an expedition reference is allocated")
	return ref


func _make_job(remaining_mwu: int = 100) -> Vector2i:
	"""Create one FISH job that may own a claim, and hand back its reference."""
	var made: JobsScript.OpResult = _jobs.create_job(JOB_KIND_FISH, 0, 0, remaining_mwu, 10)
	assert_true(made.ok, "job creates (error: %s)" % made.error)
	return made.ref


func _make_fish_basin() -> Vector2i:
	"""Designate one enabled FISH HarvestZone, which owns itself and is therefore a basin."""
	var made: ForageScript.OpResult = _zones.create_zone(ZONE_FISH, 0, 0, false, true)
	assert_true(made.ok, "a FISH basin is designated (error: %s)" % made.error)
	return made.ref


func _make_designation(basin: Vector2i) -> Vector2i:
	"""Draw a player FISH designation over an existing basin and bind it there."""
	var designation: Vector2i = _make_fish_basin()
	assert_true(_zones.set_basin(designation, basin).ok, "the designation binds to the basin")
	return designation


func _coast() -> Vector2i:
	"""Create the standard coast habitat and hand back its reference."""
	var created: Fishing.OpResult = _fishing.create_habitat(COAST, EntityDirectory.NULL_REF,
		_coast_ids(), 0, 0, 0)
	assert_true(created.ok, "the standard coast habitat must be creatable")
	return created.ref


func _estuary_species_ids() -> PackedInt32Array:
	"""Nine opaque ids addressed `habitat_type * 3 + species_index` under COAST=0, LAKE=1, RIVER=2."""
	return PackedInt32Array([30, 31, 32, 20, 21, 22, 10, 11, 12])


func _drain_to(ref: Vector2i, species_index: int, target_milli: int, season: int,
		season_day: int) -> void:
	"""Harvest one stock down to exactly `target_milli`, reopening the daily quota between days.

	This DRIVES the store into a stated population; nothing about the expectation is read back
	out of it. The guard bounds the loop so a regression cannot turn this into a hang.
	"""
	var row: int = _row(ref, species_index)
	var habitat_slot: int = _fishing.habitat_slot_of(ref).value
	for _step: int in 64:
		var remaining: int = _population(row) - target_milli
		if remaining <= 0:
			break
		_fishing.reset_harvested_today()
		var take: int = mini(_fishing.remaining_quota_milli(habitat_slot).value, remaining)
		var taken: Fishing.OpResult = _fishing.harvest(ref, species_index, take, season,
			season_day)
		assert_true(taken.ok, "the drain step must be legal: %s" % taken.error)
	assert_equal(_population(row), target_milli, "the stock is drained to exactly the target")


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
	_use_owner_stores()
	var ref: Vector2i = _river()
	var expedition: Vector2i = _make_expedition()
	assert_true(_fishing.reserve_effort_slots(expedition, _make_job(), ref, 1).ok,
		"the first effort slot is free")
	assert_equal(_fishing.destroy_habitat(ref).error, Fishing.REFUSE_EFFORT_SLOTS_RESERVED,
		"a habitat with a reserved effort slot cannot be destroyed")
	assert_true(_fishing.release_effort_slots(expedition).ok, "the claim can be released")
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
	_use_owner_stores()
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	assert_equal(_fishing.effort_slots_free_of(slot).value, RIVER_EFFORT_SLOTS,
		"a new river habitat has all four slots free")
	var first: Vector2i = _make_expedition()
	for taken: int in RIVER_EFFORT_SLOTS:
		var crew: Vector2i = first if taken == 0 else _make_expedition()
		var reserved: Fishing.OpResult = _fishing.reserve_effort_slots(crew, _make_job(), ref, 1)
		assert_equal(reserved.value, taken + 1, "each reservation takes one more slot")
	assert_equal(_fishing.effort_slots_used_of(slot).value, RIVER_EFFORT_SLOTS,
		"all four river slots are taken")
	assert_equal(_fishing.effort_slots_free_of(slot).value, 0, "none is free")
	assert_equal(_fishing.release_effort_slots(first).value, RIVER_EFFORT_SLOTS - 1,
		"a release gives one back")


func test_occupied_effort_slots_queue_further_fishers() -> void:
	"""REQ-SET-050: a fifth river fisher is refused, so no extra worker multiplies the yield."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var last: Vector2i = EntityDirectory.NULL_REF
	for _taken: int in RIVER_EFFORT_SLOTS:
		last = _make_expedition()
		assert_true(_fishing.reserve_effort_slots(last, _make_job(), ref, 1).ok,
			"the first four river slots are free")
	assert_true(_fishing.must_queue(ref), "REQ-SET-050: a further fisher must queue")
	var refused: Fishing.OpResult = _fishing.reserve_effort_slots(_make_expedition(), _make_job(),
		ref, 1)
	assert_false(refused.ok, "the fifth river reservation is refused, not granted")
	assert_equal(refused.error, Fishing.REFUSE_EFFORT_SLOTS_FULL, "and says why")
	assert_true(_fishing.release_effort_slots(last).ok, "releasing one opens a slot")
	assert_false(_fishing.must_queue(ref), "so the queued fisher may now be admitted")
	assert_true(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), ref, 1).ok,
		"and its reservation succeeds")


func test_lake_and_coast_take_six_fishers() -> void:
	"""§5.4's per-habitat effort capacity really differs: lake 6 and coast 6, not river's 4."""
	_use_owner_stores()
	var lake: Vector2i = _fishing.create_habitat(LAKE, EntityDirectory.NULL_REF, _lake_ids(),
		0, 0, 0).ref
	for _taken: int in LAKE_EFFORT_SLOTS:
		assert_true(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), lake, 1).ok,
			"each of the six lake slots is free")
	assert_false(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), lake, 1).ok,
		"the seventh lake fisher must queue")
	var coast: Vector2i = _fishing.create_habitat(COAST, EntityDirectory.NULL_REF, _coast_ids(),
		0, 0, 0).ref
	for _taken: int in COAST_EFFORT_SLOTS:
		assert_true(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), coast, 1).ok,
			"each coast slot is free")
	assert_false(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), coast, 1).ok,
		"the seventh coast fisher must queue")


func test_release_without_a_reservation_is_refused() -> void:
	"""A release with no matching claim is a caller error, not something to absorb."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var expedition: Vector2i = _make_expedition()
	var refused: Fishing.OpResult = _fishing.release_effort_slots(expedition)
	assert_false(refused.ok, "nothing is claimed, so nothing can be released")
	assert_equal(refused.error, Fishing.REFUSE_NO_EFFORT_CLAIM, "and it says so")
	assert_true(_fishing.reserve_effort_slots(expedition, _make_job(), ref, 1).ok, "one slot")
	assert_true(_fishing.release_effort_slots(expedition).ok, "the claim releases once")
	assert_false(_fishing.release_effort_slots(expedition).ok, "a double release is refused too")
	assert_equal(_fishing.effort_slots_used_of(_fishing.habitat_slot_of(ref).value).value, 0,
		"and the habitat is left with the one release it was owed")


func test_effort_operations_refuse_a_stale_habitat() -> void:
	"""A destroyed habitat cannot admit a fisher."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	_fishing.destroy_habitat(ref)
	assert_equal(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), ref, 1).error,
		Fishing.REFUSE_HABITAT_NOT_PRESENT, "a stale reference reserves nothing")
	assert_true(_fishing.must_queue(ref), "and admits no fisher")


# --- ruling §5: the gear table's effort-slot column ------------------------------------------------

func test_gear_effort_slots_transcribe_the_table() -> void:
	"""§5.4's "Workers/effort slots": net/trap/ice kit take one slot, weir and boat take two."""
	assert_equal(_fishing.effort_slots_for_gear(Fishing.GEAR_HAND_NET).value, NET_EFFORT_SLOTS,
		"hand net 1/1")
	assert_equal(_fishing.effort_slots_for_gear(Fishing.GEAR_TRAP).value, TRAP_EFFORT_SLOTS,
		"trap 1/1")
	assert_equal(_fishing.effort_slots_for_gear(Fishing.GEAR_ICE_KIT).value, ICE_KIT_EFFORT_SLOTS,
		"the ice kit modifier is the same as the net")
	assert_equal(_fishing.effort_slots_for_gear(Fishing.GEAR_WEIR).value, WEIR_EFFORT_SLOTS,
		"weir 1/2")
	assert_equal(_fishing.effort_slots_for_gear(Fishing.GEAR_BOAT).value, BOAT_EFFORT_SLOTS,
		"boat 2/2")
	assert_equal(Fishing.GEAR_COUNT, 5, "§5.4's gear table has five rows")
	assert_false(_fishing.effort_slots_for_gear(5).ok, "a sixth gear row does not exist")
	assert_false(_fishing.effort_slots_for_gear(-1).ok, "and neither does a negative one")
	assert_equal(_fishing.effort_slots_for_gear(-1).error, String(Fishing.REFUSE_INVALID_GEAR),
		"which is refused by name")


func test_the_gear_keys_transcribe_the_printed_table() -> void:
	"""§5.4's five gear rows, held in the ascending ASCII order a compiled domain would use."""
	assert_equal(Fishing.GEAR_KEYS[Fishing.GEAR_BOAT], &"boat", "boat")
	assert_equal(Fishing.GEAR_KEYS[Fishing.GEAR_HAND_NET], &"hand_net", "hand net")
	assert_equal(Fishing.GEAR_KEYS[Fishing.GEAR_ICE_KIT], &"ice_kit", "ice kit modifier")
	assert_equal(Fishing.GEAR_KEYS[Fishing.GEAR_TRAP], &"trap", "trap")
	assert_equal(Fishing.GEAR_KEYS[Fishing.GEAR_WEIR], &"weir", "weir")
	var previous: String = ""
	for gear: int in Fishing.GEAR_COUNT:
		var key: String = String(Fishing.GEAR_KEYS[gear])
		assert_true(key > previous, "%s follows %s in ascending ASCII order" % [key, previous])
		previous = key


# --- ruling §5: atomic multi-slot admission ---------------------------------------------------------

func test_a_two_slot_cycle_refuses_without_changing_anything() -> void:
	"""Ruling §5's stated acceptance: three of four river slots used, a two-slot request refuses.

	It must refuse WITHOUT taking the one slot that is free -- two single-slot calls without
	rollback are exactly the unsafe admission API the ruling names -- and a one-slot request must
	then still succeed.
	"""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	for _taken: int in 3:
		assert_true(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), ref, 1).ok,
			"three of the four river slots are taken")
	assert_equal(_fishing.effort_slots_free_of(slot).value, 1, "one slot is left")
	var weir: Vector2i = _make_expedition()
	var refused: Fishing.OpResult = _fishing.reserve_effort_slots(weir, _make_job(), ref,
		WEIR_EFFORT_SLOTS)
	assert_false(refused.ok, "a weir cycle needs two slots and cannot have them")
	assert_equal(refused.error, Fishing.REFUSE_EFFORT_SLOTS_FULL, "and says why")
	assert_equal(_fishing.effort_slots_used_of(slot).value, 3, "nothing was taken by the refusal")
	assert_equal(_fishing.effort_claim_count(), 3, "and no claim was published")
	assert_false(_fishing.effort_claim_row_of(weir).ok, "the refused cycle owns no claim")
	assert_true(_fishing.reserve_effort_slots(weir, _make_job(), ref, 1).ok,
		"a one-slot request fits the same free slot")
	assert_equal(_fishing.effort_slots_used_of(slot).value, RIVER_EFFORT_SLOTS, "filling it")


func test_a_two_slot_cycle_takes_both_slots_together() -> void:
	"""A weir or boat cycle reserves its whole gear requirement in one committed step."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	var boat: Vector2i = _make_expedition()
	var reserved: Fishing.OpResult = _fishing.reserve_effort_slots(boat, _make_job(), ref,
		BOAT_EFFORT_SLOTS)
	assert_true(reserved.ok, "the boat cycle is admitted")
	assert_equal(reserved.value, BOAT_EFFORT_SLOTS, "holding both of its slots")
	assert_equal(_fishing.effort_slots_free_of(slot).value, 2, "two river slots remain")
	assert_equal(_fishing.effort_claim_slot_count_of(_fishing.effort_claim_row_of(boat).value)
		.value, BOAT_EFFORT_SLOTS, "and the claim records both")
	assert_true(_fishing.must_queue(ref, 3), "a three-slot cycle still would not fit")
	assert_false(_fishing.must_queue(ref, 2), "a second two-slot cycle would")
	assert_equal(_fishing.release_effort_slots(boat).value, 0,
		"releasing the claim gives back both slots at once")


func test_a_slot_count_outside_the_habitat_is_refused() -> void:
	"""A cycle cannot ask for no slots, and cannot ask for more than the habitat has."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	assert_equal(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), ref, 0).error,
		Fishing.REFUSE_INVALID_SLOT_COUNT, "zero slots is not a cycle")
	assert_equal(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), ref, -2).error,
		Fishing.REFUSE_INVALID_SLOT_COUNT, "and neither is a negative count")
	assert_equal(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), ref,
		RIVER_EFFORT_SLOTS + 1).error, Fishing.REFUSE_EFFORT_SLOTS_FULL,
		"five slots never fit a river habitat")
	assert_equal(_fishing.effort_slots_used_of(_fishing.habitat_slot_of(ref).value).value, 0,
		"and none of the three refusals took a slot")
	assert_true(_fishing.must_queue(ref, 0), "no cycle reserves nothing")


# --- ruling §5: claim ownership ---------------------------------------------------------------------

func test_an_effort_claim_needs_a_live_expedition_and_a_live_job() -> void:
	"""Ruling §5: validate the Expedition through the directory first, then its stored generation."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	assert_equal(_fishing.reserve_effort_slots(EntityDirectory.NULL_REF, _make_job(), ref, 1)
		.error, Fishing.REFUSE_EXPEDITION_NOT_PRESENT, "the null reference owns nothing")
	var dead: Vector2i = _make_expedition()
	_fishing.directory().destroy(dead)
	assert_equal(_fishing.reserve_effort_slots(dead, _make_job(), ref, 1).error,
		Fishing.REFUSE_EXPEDITION_NOT_PRESENT, "and neither does a destroyed expedition")
	assert_equal(_fishing.reserve_effort_slots(_make_expedition(), EntityDirectory.NULL_REF, ref,
		1).error, Fishing.REFUSE_JOB_NOT_PRESENT, "a claim needs a live owning Job")
	assert_equal(_fishing.effort_claim_count(), 0, "and none of that published a claim")


func test_only_a_coordinator_job_owns_an_effort_claim() -> void:
	"""Decision 0017: a member Job never owns the cycle, so it cannot own its effort slots."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var coordinator: Vector2i = _make_job()
	var member: Vector2i = _make_job(0)
	var coordinator_slot: int = _jobs.directory().get_typed_row(coordinator)
	var member_slot: int = _jobs.directory().get_typed_row(member)
	assert_true(_jobs.make_coordinator(coordinator_slot).ok, "the coordinator is marked")
	assert_true(_jobs.set_coordinator(member_slot, coordinator_slot).ok, "the member joins it")
	assert_equal(_fishing.reserve_effort_slots(_make_expedition(), member, ref, 1).error,
		Fishing.REFUSE_JOB_IS_MEMBER, "a party member may not claim the habitat's slots")
	assert_true(_fishing.reserve_effort_slots(_make_expedition(), coordinator, ref, 1).ok,
		"its coordinator may")


func test_cancelling_one_member_leaves_the_coordinators_claim_alone() -> void:
	"""Ruling §5's acceptance: one party member's cancellation must not end the whole cycle."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var coordinator: Vector2i = _make_job()
	var member: Vector2i = _make_job(0)
	var coordinator_slot: int = _jobs.directory().get_typed_row(coordinator)
	var member_slot: int = _jobs.directory().get_typed_row(member)
	assert_true(_jobs.make_coordinator(coordinator_slot).ok, "the coordinator is marked")
	assert_true(_jobs.set_coordinator(member_slot, coordinator_slot).ok, "the member joins it")
	var expedition: Vector2i = _make_expedition()
	assert_true(_fishing.reserve_effort_slots(expedition, coordinator, ref,
		BOAT_EFFORT_SLOTS).ok, "the boat cycle claims both slots")
	assert_true(_jobs.set_state(member_slot, JOB_STATE_CANCELLED).ok, "one member cancels")
	assert_equal(_fishing.release_cancelled_effort_claims().value, 0,
		"the sweep releases nothing: the member never owned the claim")
	assert_equal(_fishing.effort_slots_used_of(_fishing.habitat_slot_of(ref).value).value,
		BOAT_EFFORT_SLOTS, "and the coordinator still holds both slots")
	assert_true(_jobs.set_state(coordinator_slot, JOB_STATE_CANCELLED).ok, "now it cancels")
	assert_equal(_fishing.release_cancelled_effort_claims().value, 1, "which does release it")
	assert_equal(_fishing.effort_slots_used_of(_fishing.habitat_slot_of(ref).value).value, 0,
		"giving both slots back exactly once")
	assert_equal(_fishing.release_cancelled_effort_claims().value, 0, "and never twice")


func test_a_stale_release_cannot_free_someone_elses_slots() -> void:
	"""Ruling §5: a stale call releases exactly nothing, even when it reuses the same claim row."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	var first: Vector2i = _make_expedition()
	assert_true(_fishing.reserve_effort_slots(first, _make_job(), ref, 1).ok, "the first claims")
	var claim_row: int = _fishing.effort_claim_row_of(first).value
	assert_true(_fishing.release_effort_slots(first).ok, "and releases")
	_fishing.directory().destroy(first)
	var second: Vector2i = _make_expedition()
	assert_equal(_fishing.directory().get_typed_row(second), claim_row,
		"the next expedition reuses the freed typed row")
	assert_true(_fishing.reserve_effort_slots(second, _make_job(), ref,
		BOAT_EFFORT_SLOTS).ok, "and claims two slots on it")
	assert_false(_fishing.release_effort_slots(first).ok,
		"the first expedition's stale reference releases nothing")
	assert_equal(_fishing.effort_slots_used_of(slot).value, BOAT_EFFORT_SLOTS,
		"so the second expedition keeps both of its slots")


func test_a_second_claim_on_one_expedition_is_refused() -> void:
	"""One Expedition row holds one claim: a second would double-book the same cycle's slots."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var expedition: Vector2i = _make_expedition()
	assert_true(_fishing.reserve_effort_slots(expedition, _make_job(), ref, 1).ok, "the first")
	assert_equal(_fishing.reserve_effort_slots(expedition, _make_job(), ref, 1).error,
		Fishing.REFUSE_EFFORT_CLAIM_PRESENT, "the second is refused")
	assert_equal(_fishing.effort_slots_used_of(_fishing.habitat_slot_of(ref).value).value, 1,
		"and took no further slot")


func test_a_destroyed_expedition_leaves_a_claim_only_a_purge_can_release() -> void:
	"""A dead expedition cannot release its own slots, so the sweep is what frees them."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	var expedition: Vector2i = _make_expedition()
	assert_true(_fishing.reserve_effort_slots(expedition, _make_job(), ref,
		BOAT_EFFORT_SLOTS).ok, "two slots are claimed")
	_fishing.directory().destroy(expedition)
	assert_equal(_fishing.effort_slots_used_of(slot).value, BOAT_EFFORT_SLOTS,
		"destroying the expedition does not silently free them")
	assert_equal(_fishing.purge_stale_effort_claims().value, 1, "the sweep finds the one claim")
	assert_equal(_fishing.effort_slots_used_of(slot).value, 0, "and returns both slots")
	assert_equal(_fishing.effort_claim_count(), 0, "leaving no claim behind")
	assert_equal(_fishing.purge_stale_effort_claims().value, 0, "and nothing to find twice")


func test_a_reused_expedition_row_cannot_inherit_the_previous_claim() -> void:
	"""Ruling §5's second ownership step: the directory says live, the stored generation says whose.

	A destroyed expedition leaves an active claim on its typed row. The next expedition takes that
	same row, so the directory validates it -- and only the stored generation can tell that the
	claim on it was written by somebody else.
	"""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	var first: Vector2i = _make_expedition()
	assert_true(_fishing.reserve_effort_slots(first, _make_job(), ref, BOAT_EFFORT_SLOTS).ok,
		"the first expedition claims two slots")
	var claim_row: int = _fishing.effort_claim_row_of(first).value
	_fishing.directory().destroy(first)
	var second: Vector2i = _make_expedition()
	assert_equal(_fishing.directory().get_typed_row(second), claim_row,
		"the next expedition takes the same claim row")
	assert_equal(_fishing.release_effort_slots(second).error, Fishing.REFUSE_EFFORT_CLAIM_STALE,
		"which cannot release the claim it did not write")
	assert_equal(_fishing.reserve_effort_slots(second, _make_job(), ref, 1).error,
		Fishing.REFUSE_EFFORT_CLAIM_STALE, "nor overwrite it with one of its own")
	assert_equal(_fishing.effort_slots_used_of(slot).value, BOAT_EFFORT_SLOTS,
		"and the abandoned claim still holds both slots")
	assert_equal(_fishing.purge_stale_effort_claims().value, 1, "only the purge releases it")
	assert_true(_fishing.reserve_effort_slots(second, _make_job(), ref, 1).ok,
		"and then the row is the second expedition's to claim")


func test_effort_claims_need_the_owner_stores() -> void:
	"""Without a Job store there is no way to check decision 0017's ownership, so this refuses."""
	var ref: Vector2i = _river()
	assert_equal(_fishing.reserve_effort_slots(EntityDirectory.NULL_REF,
		EntityDirectory.NULL_REF, ref, 1).error, Fishing.REFUSE_NO_JOB_STORE,
		"a fishery with no Job store admits no cycle")
	assert_equal(_fishing.rebuild_effort_aggregates().error, Fishing.REFUSE_NO_JOB_STORE,
		"and rebuilds no aggregate")
	assert_equal(_fishing.release_cancelled_effort_claims().error, Fishing.REFUSE_NO_JOB_STORE,
		"and sweeps no cancellation")


# --- ruling §5: the load path -------------------------------------------------------------------------

func test_the_claim_slice_is_one_row_per_expedition() -> void:
	"""Ruling §5's 512-row slice and its 12800-byte payload, plus decision 0027's 256 bytes."""
	assert_equal(Fishing.FISHING_EFFORT_CLAIM_CAPACITY, EXPECTED_EFFORT_CLAIM_CAPACITY,
		"one claim row per §2.1 Expedition row")
	assert_equal(EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_EXPEDITION],
		EXPECTED_EFFORT_CLAIM_CAPACITY, "which the directory sizes at 512")
	assert_equal(_fishing.effort_claim_payload_bytes(), EXPECTED_EFFORT_CLAIM_BYTES,
		"six I32 columns plus one B8 over 512 rows")
	assert_equal(_fishing.fishing_state_addition_bytes(), EXPECTED_FISHING_STATE_BYTES,
		"decision 0027's effort_used, restocking and intensive_harvest columns")
	assert_false(_fishing.is_effort_claim_active(EXPECTED_EFFORT_CLAIM_CAPACITY),
		"row 512 is not a claim")
	assert_false(_fishing.is_effort_claim_active(-1), "and neither is row -1")


func test_restored_claims_rebuild_the_aggregate_they_cannot_prove() -> void:
	"""Ruling §5: restore the claims, then recompute the occupancy from them, never trust a total."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var slot: int = _fishing.habitat_slot_of(ref).value
	var first: Vector2i = _make_expedition()
	var second: Vector2i = _make_expedition()
	assert_true(_fishing.restore_effort_claim(first, _make_job(), ref, BOAT_EFFORT_SLOTS).ok,
		"a saved two-slot claim is restored")
	assert_true(_fishing.restore_effort_claim(second, _make_job(), ref, 1).ok,
		"and a saved one-slot claim")
	assert_equal(_fishing.effort_slots_used_of(slot).value, 0,
		"restoring deliberately leaves the derived occupancy alone")
	assert_false(_fishing.validate_effort_aggregates().ok, "so the snapshot does not validate")
	assert_equal(_fishing.rebuild_effort_aggregates().value, 2, "the rebuild counts both claims")
	assert_equal(_fishing.effort_slots_used_of(slot).value, BOAT_EFFORT_SLOTS + 1,
		"and totals three of the river's four slots")
	assert_true(_fishing.validate_effort_aggregates().ok, "which now validates")


func test_a_restored_claim_with_a_stale_owner_is_refused() -> void:
	"""A save whose owner generation disagrees is refused rather than loaded."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var expedition: Vector2i = _make_expedition()
	assert_true(_fishing.restore_effort_claim(expedition, _make_job(), ref, 1).ok, "restored")
	_fishing.directory().destroy(expedition)
	var refused: Fishing.OpResult = _fishing.rebuild_effort_aggregates()
	assert_false(refused.ok, "the rebuild refuses a claim whose expedition is gone")
	assert_equal(refused.error, Fishing.REFUSE_EXPEDITION_NOT_PRESENT, "and says why")
	assert_equal(_fishing.effort_slots_used_of(_fishing.habitat_slot_of(ref).value).value, 0,
		"leaving the authoritative column untouched")


func test_an_aggregate_no_claim_accounts_for_is_refused() -> void:
	"""Ruling §5: "a stored total alone cannot prove ownership"."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var expedition: Vector2i = _make_expedition()
	assert_true(_fishing.reserve_effort_slots(expedition, _make_job(), ref, 1).ok, "one claim")
	assert_true(_fishing.validate_effort_aggregates().ok, "which the total agrees with")
	assert_true(_fishing.restore_effort_claim(_make_expedition(), _make_job(), ref, 1).ok,
		"a second claim arrives without its occupancy")
	assert_false(_fishing.validate_effort_aggregates().ok, "so the two now disagree")
	assert_equal(_fishing.validate_effort_aggregates().error, Fishing.REFUSE_AGGREGATE_MISMATCH,
		"and the mismatch is named")
	assert_equal(_fishing.rebuild_effort_aggregates().value, 2, "the rebuild settles it")
	assert_true(_fishing.validate_effort_aggregates().ok, "and it validates afterwards")


func test_a_restored_claim_beyond_the_habitat_capacity_is_refused() -> void:
	"""Five river slots cannot be owed to anybody: §5.4 gives the habitat four."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	assert_equal(_fishing.restore_effort_claim(_make_expedition(), _make_job(), ref,
		RIVER_EFFORT_SLOTS + 1).error, Fishing.REFUSE_INVALID_SLOT_COUNT,
		"a claim larger than the habitat is refused on the way in")
	for _taken: int in RIVER_EFFORT_SLOTS:
		assert_true(_fishing.restore_effort_claim(_make_expedition(), _make_job(), ref, 1).ok,
			"four one-slot claims restore")
	assert_true(_fishing.restore_effort_claim(_make_expedition(), _make_job(), ref, 1).ok,
		"and a fifth restores, because restore applies no occupancy")
	var refused: Fishing.OpResult = _fishing.rebuild_effort_aggregates()
	assert_false(refused.ok, "but the rebuild refuses the over-capacity total")
	assert_equal(refused.error, Fishing.REFUSE_AGGREGATE_MISMATCH, "and names it")
	assert_equal(_fishing.effort_slots_used_of(_fishing.habitat_slot_of(ref).value).value, 0,
		"with the authoritative column still untouched")


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


# --- ruling §5: the depletion latch at its exact boundaries ---------------------------------------

func test_the_depletion_latch_does_not_flip_at_exactly_thirty_percent() -> void:
	"""Ruling §5: enter when `100*P < 30*K`, strictly. Equality at 30% flips nothing.

	Mussel's capacity is 1000000 milli-U, so 30% of K is exactly 300000. Drained to that number
	the stock is not depleted and not restocking; one further milli-unit is, which is the only
	difference a `<=` implementation would erase.
	"""
	var coast: Vector2i = _coast()
	assert_true(_fishing.set_intensive_harvest(coast, true).ok, "the visible policy allows this")
	var row: int = _row(coast, MUSSEL_INDEX)
	_drain_to(coast, MUSSEL_INDEX, MUSSEL_DEPLETION_BOUNDARY, SUMMER, 1)
	assert_false(_fishing.is_depleted(row), "exactly 30% of K is not BELOW 30% of K")
	assert_false(_fishing.is_restocking(row), "so the latch is not set")
	_fishing.reset_harvested_today()
	assert_true(_fishing.harvest(coast, MUSSEL_INDEX, 1, SUMMER, 1).ok, "one more milli-unit")
	assert_equal(_population(row), MUSSEL_DEPLETION_BOUNDARY - 1, "takes it below the boundary")
	assert_true(_fishing.is_depleted(row), "which IS below 30% of K")
	assert_true(_fishing.is_restocking(row), "and sets the latch")


func test_the_recovery_latch_does_not_clear_at_exactly_forty_percent() -> void:
	"""Ruling §5: clear when `100*P > 40*K`, strictly. Equality at 40% clears nothing.

	Mussel's 40% of K is exactly 400000, and §5.4's midnight formula carries 380852 to exactly
	that number and 400000 on to 419400. The latch must survive the landing and clear only on the
	step that passes it.
	"""
	var coast: Vector2i = _coast()
	assert_true(_fishing.set_intensive_harvest(coast, true).ok, "the visible policy allows this")
	var row: int = _row(coast, MUSSEL_INDEX)
	_drain_to(coast, MUSSEL_INDEX, MUSSEL_DRAIN_START, SUMMER, 1)
	assert_true(_fishing.is_restocking(row), "the latch is set below 30%")
	for _day: int in 5:
		assert_true(_fishing.recover_stock(row, SUMMER, 1).ok, "five midnights of recovery")
	assert_equal(_population(row), MUSSEL_AFTER_FIVE_RECOVERIES, "reach 391726")
	assert_true(_fishing.is_restocking(row), "still latched inside the 30..40% band")
	_drain_to(coast, MUSSEL_INDEX, MUSSEL_ONE_DAY_BELOW_RECOVERY, SUMMER, 1)
	assert_true(_fishing.is_restocking(row), "and still latched at 380852")
	assert_equal(_fishing.recover_stock(row, SUMMER, 1).value, MUSSEL_RECOVERY_BOUNDARY,
		"the next midnight lands on exactly 40% of K")
	assert_true(_fishing.is_restocking(row), "which does NOT clear the latch")
	assert_equal(_fishing.recover_stock(row, SUMMER, 1).value, MUSSEL_ABOVE_RECOVERY,
		"the midnight after it passes 40%")
	assert_false(_fishing.is_restocking(row), "and only then is the latch cleared")


func test_the_latch_moves_independently_of_the_intensive_override() -> void:
	"""Ruling §5: "Update the latch independently of the override."

	The override is a separate, player-owned switch: turning it off restores REQ-SET-048's
	restriction on the very next call, and the latch still clears on its own 40% crossing while
	the override is off the whole time.
	"""
	var coast: Vector2i = _coast()
	var row: int = _row(coast, MUSSEL_INDEX)
	_fishing.set_intensive_harvest(coast, true)
	_drain_to(coast, MUSSEL_INDEX, MUSSEL_DRAIN_START, SUMMER, 1)
	assert_true(_fishing.is_restocking(row), "the latch is set")
	assert_true(_fishing.set_intensive_harvest(coast, false).ok, "the player lowers the policy")
	_fishing.reset_harvested_today()
	assert_equal(_fishing.harvest(coast, MUSSEL_INDEX, 1000, SUMMER, 1).error,
		Fishing.REFUSE_RESTOCKING, "and the restriction applies immediately, not next cycle")
	assert_true(_fishing.is_restocking(row), "the latch itself is untouched by the switch")
	for _day: int in 8:
		_fishing.recover_stock(row, SUMMER, 1)
	assert_true(_population(row) > MUSSEL_RECOVERY_BOUNDARY, "recovery passes 40% of K")
	assert_false(_fishing.is_restocking(row), "so the latch clears with the override still off")
	assert_true(_fishing.harvest(coast, MUSSEL_INDEX, 1000, SUMMER, 1).ok, "and work resumes")


func test_the_explicit_intensive_choice_is_never_reset_automatically() -> void:
	"""Ruling §5: "Preserve the player's explicit intensive choice" -- no per-cycle confirmation."""
	var coast: Vector2i = _coast()
	var slot: int = _fishing.habitat_slot_of(coast).value
	var row: int = _row(coast, MUSSEL_INDEX)
	assert_true(_fishing.set_intensive_harvest(coast, true).ok, "the player enables it once")
	_harvest_repeatedly(coast, MUSSEL_INDEX, COAST_QUOTA, SUMMER, 1, 6)
	assert_true(_fishing.is_intensive_harvest(slot), "six cycles later it is still on")
	assert_equal(_fishing.floor_percent_for(row, SUMMER, 1).value, HARD_FLOOR_PERCENT,
		"and the floor is still the 10% hard floor")
	for _day: int in 20:
		_fishing.recover_stock(row, SUMMER, 1)
	assert_true(_fishing.is_intensive_harvest(slot), "recovery does not revoke it either")
	assert_true(_fishing.set_intensive_harvest(coast, false).ok, "only the player turns it off")
	assert_false(_fishing.is_intensive_harvest(slot), "and then it is off")


func test_restocking_never_bypasses_a_closure_or_an_unavailable_species() -> void:
	"""Ruling §5: intensive bypasses the soft stop, "but never closures, unavailable species"."""
	var ref: Vector2i = _river()
	assert_true(_fishing.set_intensive_harvest(ref, true).ok, "the policy is on")
	assert_equal(_fishing.harvest(ref, 0, 1000, SPRING, 6).error, Fishing.REFUSE_SPECIES_CLOSED,
		"trout's spring 5-7 spawning closure still refuses")
	assert_equal(_fishing.harvest(ref, 2, 1000, SPRING, 1).error,
		Fishing.REFUSE_SPECIES_UNAVAILABLE, "and salmon is still unavailable outside autumn")
	assert_true(_fishing.set_closed(ref, 1, true).ok, "close dace by the stored bit")
	assert_equal(_fishing.harvest(ref, 1, 1000, SPRING, 1).error, Fishing.REFUSE_SPECIES_CLOSED,
		"which the policy does not override either")


func test_revalidation_reports_a_lowered_policy_and_refunds_nothing() -> void:
	"""Ruling §5: lowering policy "revalidates uncommitted departures" and refunds no spent work."""
	_use_owner_stores()
	var coast: Vector2i = _coast()
	var habitat_slot: int = _fishing.habitat_slot_of(coast).value
	var row: int = _row(coast, MUSSEL_INDEX)
	_fishing.set_intensive_harvest(coast, true)
	_drain_to(coast, MUSSEL_INDEX, MUSSEL_DRAIN_START, SUMMER, 1)
	var expedition: Vector2i = _make_expedition()
	assert_true(_fishing.reserve_effort_slots(expedition, _make_job(), coast, 1).ok, "one slot")
	assert_true(_fishing.revalidate_effort_claim(expedition, MUSSEL_INDEX, SUMMER, 1).ok,
		"the departure is legal while the policy is on")
	_fishing.set_intensive_harvest(coast, false)
	var refused: Fishing.OpResult = _fishing.revalidate_effort_claim(expedition, MUSSEL_INDEX,
		SUMMER, 1)
	assert_false(refused.ok, "and illegal the moment it is lowered")
	assert_equal(refused.error, Fishing.REFUSE_RESTOCKING, "for the stated reason")
	assert_equal(_population(row), MUSSEL_DRAIN_START, "no consumed fish is recreated")
	assert_equal(_fishing.effort_slots_used_of(habitat_slot).value, 1,
		"and no spent effort is silently refunded")
	assert_true(_fishing.effort_claim_row_of(expedition).ok, "the claim is still the owner's")


func test_revalidation_refuses_without_a_claim_or_a_stock() -> void:
	"""Every path out of the revalidation names a condition rather than defaulting to legal."""
	_use_owner_stores()
	var ref: Vector2i = _river()
	var expedition: Vector2i = _make_expedition()
	assert_equal(_fishing.revalidate_effort_claim(expedition, 0, SPRING, 1).error,
		Fishing.REFUSE_NO_EFFORT_CLAIM, "an expedition with no claim revalidates nothing")
	assert_true(_fishing.reserve_effort_slots(expedition, _make_job(), ref, 1).ok, "one slot")
	assert_equal(_fishing.revalidate_effort_claim(expedition, 3, SPRING, 1).error,
		Fishing.REFUSE_INVALID_SPECIES_INDEX, "a fourth species does not exist")
	assert_equal(_fishing.revalidate_effort_claim(expedition, 0, SPRING, 6).error,
		Fishing.REFUSE_SPECIES_CLOSED, "and trout's closure is reported, not waived")
	assert_true(_fishing.revalidate_effort_claim(expedition, 0, SPRING, 1).ok,
		"an open trout day revalidates")


# --- ruling §8B: the initial estuary ----------------------------------------------------------------

func test_the_initial_estuary_is_three_habitats_and_nine_stocks() -> void:
	"""Ruling §8B: exactly one river, one lake and one coast basin -- not 32 copies of them.

	Capacities sum to §5.4's 2100/2200/3100 U and stocks start at its 80%, so the generated world
	holds 1680000, 1760000 and 2480000 milli-U of fish and nothing else.
	"""
	var made: Fishing.OpResult = _fishing.generate_initial_estuary(_estuary_species_ids())
	assert_true(made.ok, "the estuary generates (error: %s)" % made.error)
	assert_equal(made.value, EXPECTED_ESTUARY_STOCKS, "nine FishStock rows in total")
	assert_equal(_fishing.habitat_count(), EXPECTED_ESTUARY_HABITATS, "three habitats, not 32")
	var coast_slot: int = _fishing.live_habitat_slot_at(0).value
	var lake_slot: int = _fishing.live_habitat_slot_at(1).value
	var river_slot: int = _fishing.live_habitat_slot_at(2).value
	assert_equal(_fishing.habitat_type_of(coast_slot).value, COAST, "the first is the coast")
	assert_equal(_fishing.habitat_type_of(lake_slot).value, LAKE, "the second is the lake")
	assert_equal(_fishing.habitat_type_of(river_slot).value, RIVER, "the third is the river")
	assert_equal(_fishing.habitat_capacity_milli_of(river_slot).value, RIVER_K_TOTAL, "2100 U")
	assert_equal(_fishing.habitat_capacity_milli_of(lake_slot).value, LAKE_K_TOTAL, "2200 U")
	assert_equal(_fishing.habitat_capacity_milli_of(coast_slot).value, COAST_K_TOTAL, "3100 U")
	assert_equal(_fishing.population_total_milli_of(river_slot).value, RIVER_INITIAL_BIOMASS,
		"the river holds 80% of 2100 U")
	assert_equal(_fishing.population_total_milli_of(lake_slot).value, LAKE_INITIAL_BIOMASS,
		"the lake holds 80% of 2200 U")
	assert_equal(_fishing.population_total_milli_of(coast_slot).value, COAST_INITIAL_BIOMASS,
		"the coast holds 80% of 3100 U")
	assert_equal(_fishing.species_id_of(river_slot * EXPECTED_SPECIES_PER_HABITAT).value, 10,
		"the river's three ids come from its own slice of the nine")
	assert_equal(_fishing.species_id_of(lake_slot * EXPECTED_SPECIES_PER_HABITAT + 2).value, 22,
		"and so do the lake's")
	assert_equal(_fishing.species_id_of(coast_slot * EXPECTED_SPECIES_PER_HABITAT + 1).value, 31,
		"and the coast's")


func test_the_estuary_is_generated_once_and_never_multiplied() -> void:
	"""Ruling §8B: 32 habitats is a CEILING; a second generation is refused, not stacked."""
	assert_true(_fishing.generate_initial_estuary(_estuary_species_ids()).ok, "the first runs")
	var refused: Fishing.OpResult = _fishing.generate_initial_estuary(_estuary_species_ids())
	assert_false(refused.ok, "the second is refused")
	assert_equal(refused.error, Fishing.REFUSE_ESTUARY_PRESENT, "by name")
	assert_equal(_fishing.habitat_count(), EXPECTED_ESTUARY_HABITATS, "with three habitats left")
	var coast_slot: int = _fishing.live_habitat_slot_at(0).value
	assert_equal(_fishing.population_total_milli_of(coast_slot).value, COAST_INITIAL_BIOMASS,
		"and no extra biomass minted")


func test_an_estuary_with_an_unusable_species_set_creates_nothing() -> void:
	"""A refusal happens before the first habitat row is taken, so nothing partial survives."""
	assert_equal(_fishing.generate_initial_estuary(PackedInt32Array([1, 2, 3])).error,
		Fishing.REFUSE_SPECIES_SET_SIZE, "nine ids are required, not three")
	assert_equal(_fishing.generate_initial_estuary(
		PackedInt32Array([30, 31, 32, 20, 21, 22, 10, 11, 12, 40, 41, 42])).error,
		Fishing.REFUSE_SPECIES_SET_SIZE, "and not twelve either, however well they slice")
	assert_equal(_fishing.generate_initial_estuary(
		PackedInt32Array([30, 31, 32, 20, 21, 22, 10, 11, 11])).error,
		Fishing.REFUSE_DUPLICATE_SPECIES_ID, "and the river's three must differ")
	assert_equal(_fishing.generate_initial_estuary(
		PackedInt32Array([30, 31, 32, 20, 21, 22, 10, 11, -1])).error,
		Fishing.REFUSE_INVALID_SPECIES_ID, "and none may be negative")
	assert_equal(_fishing.habitat_count(), 0, "none of the three refusals created a habitat")
	assert_equal(_fishing.directory().live_count(EntityDirectory.KIND_FISH_HABITAT), 0,
		"nor took a directory slot")


func test_ecology_allocation_beyond_thirty_two_refuses_atomically() -> void:
	"""Ruling §8B: "ecology allocation beyond 32 refuses atomically"."""
	for index: int in EXPECTED_HABITAT_CAPACITY:
		assert_true(_fishing.create_habitat(RIVER, EntityDirectory.NULL_REF, _river_ids(),
			0, 0, 0).ok, "habitat %d fits inside the ceiling" % index)
	var last_slot: int = _fishing.live_habitat_slot_at(EXPECTED_HABITAT_CAPACITY - 1).value
	var refused: Fishing.OpResult = _fishing.create_habitat(LAKE, EntityDirectory.NULL_REF,
		_lake_ids(), 0, 0, 0)
	assert_false(refused.ok, "the thirty-third is refused")
	assert_equal(_fishing.habitat_count(), EXPECTED_HABITAT_CAPACITY, "with 32 still live")
	assert_equal(_fishing.population_total_milli_of(last_slot).value, RIVER_INITIAL_BIOMASS,
		"and the last habitat's stocks untouched")
	assert_true(_fishing.is_stock_present(EXPECTED_STOCK_CAPACITY - 1),
		"the ninety-sixth stock row belongs to the thirty-second habitat")
	assert_false(_fishing.is_stock_present(EXPECTED_STOCK_CAPACITY),
		"and the refusal created no ninety-seventh")
	assert_equal(refused.error, EntityDirectory.KIND_CAPACITY_REFUSAL[
		EntityDirectory.KIND_FISH_HABITAT], "the refusal carries the store's own capacity code")
	assert_equal(_fishing.generate_initial_estuary(_estuary_species_ids()).error,
		Fishing.REFUSE_ESTUARY_PRESENT, "and the world generator refuses a full store too")


# --- ruling §8B: designations bind, and never create -------------------------------------------------

func test_a_designation_binds_to_the_basins_existing_habitat() -> void:
	"""Ruling §8B: designation -> its existing HarvestZone.basin -> the unique habitat on it."""
	_use_owner_stores()
	var basin: Vector2i = _make_fish_basin()
	var habitat: Vector2i = _fishing.create_habitat(RIVER, basin, _river_ids(), 0, 0, 0).ref
	var first: Vector2i = _make_designation(basin)
	var second: Vector2i = _make_designation(basin)
	assert_equal(_fishing.habitat_ref_for_designation(first).ref, habitat, "the first resolves")
	assert_equal(_fishing.habitat_ref_for_designation(second).ref, habitat,
		"and the second resolves to the SAME habitat, sharing its totals")
	assert_equal(_fishing.habitat_ref_for_basin(basin).ref, habitat,
		"as does the basin the pair hang off")
	assert_equal(_fishing.habitat_count(), 1, "and two designations created no second habitat")


func test_designation_history_leaves_the_basins_ecology_identical() -> void:
	"""Ruling §8B: overlapping, splitting, deleting or protecting a designation resets nothing.

	Two different designation histories over one basin are compared against the same recorded
	stock, quota and effort occupancy: the acceptance is that neither history can change them.
	"""
	_use_owner_stores()
	var basin: Vector2i = _make_fish_basin()
	var habitat: Vector2i = _fishing.create_habitat(RIVER, basin, _river_ids(), 0, 0, 0).ref
	var habitat_slot: int = _fishing.habitat_slot_of(habitat).value
	assert_true(_fishing.harvest(habitat, 0, 20000, SPRING, 1).ok, "20 U of trout is taken")
	assert_true(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), habitat, 1).ok,
		"and one effort slot is held")
	var first: Vector2i = _make_designation(basin)
	var second: Vector2i = _make_designation(basin)
	assert_true(_zones.destroy_zone(first).ok, "the first designation is erased")
	assert_true(_zones.set_zone_protected(second, true).ok, "the second is protected")
	var third: Vector2i = _make_designation(basin)
	assert_equal(_fishing.habitat_ref_for_designation(third).ref, habitat, "and a third is drawn")
	assert_equal(_fishing.habitat_count(), 1, "still one habitat")
	assert_equal(_population(_row(habitat, 0)), TROUT_INITIAL - 20000, "the same trout stock")
	assert_equal(_fishing.harvested_today_total_of(habitat_slot).value, 20000,
		"the same daily quota history")
	assert_equal(_fishing.remaining_quota_milli(habitat_slot).value, RIVER_QUOTA - 20000,
		"the same quota left today")
	assert_equal(_fishing.effort_slots_used_of(habitat_slot).value, 1,
		"and the same effort occupancy")


func test_a_basin_with_no_habitat_refuses_rather_than_creating_one() -> void:
	"""Ruling §8B: a missing match refuses. Player designations cannot reach the creation path."""
	_use_owner_stores()
	var basin: Vector2i = _make_fish_basin()
	var designation: Vector2i = _make_designation(basin)
	var refused: Fishing.OpResult = _fishing.habitat_ref_for_designation(designation)
	assert_false(refused.ok, "an undesignated basin has no fish to bind to")
	assert_equal(refused.error, Fishing.REFUSE_NO_HABITAT_FOR_BASIN, "and says so")
	assert_equal(_fishing.habitat_count(), 0, "and no habitat was created to satisfy it")
	assert_equal(_fishing.habitat_ref_for_basin(basin).error,
		Fishing.REFUSE_NO_HABITAT_FOR_BASIN, "the basin scan agrees")


func test_a_stale_habitat_binding_does_not_answer_for_the_reused_slot() -> void:
	"""Ruling §8B: "Validate both generations." A slot match alone is not a basin match.

	The destroyed basin's directory slot is handed straight back to the next zone, so the two
	references differ only in their generation -- which is precisely the case a slot-only scan
	would answer wrongly, and would then see as a duplicate once a second habitat exists.
	"""
	_use_owner_stores()
	var first_basin: Vector2i = _make_fish_basin()
	var stale_habitat: Vector2i = _fishing.create_habitat(RIVER, first_basin, _river_ids(),
		0, 0, 0).ref
	assert_true(_zones.destroy_zone(first_basin).ok, "the basin zone is erased")
	var second_basin: Vector2i = _make_fish_basin()
	assert_equal(second_basin.x, first_basin.x, "the next zone reuses the freed directory slot")
	assert_true(second_basin.y != first_basin.y, "with a new generation")
	assert_equal(_fishing.habitat_ref_for_basin(second_basin).error,
		Fishing.REFUSE_NO_HABITAT_FOR_BASIN, "the stale binding does not answer for it")
	var made: Fishing.OpResult = _fishing.create_habitat(LAKE, second_basin, _lake_ids(), 0, 0, 0)
	assert_true(made.ok, "a habitat may still be created on the reused slot (error: %s)"
		% made.error)
	var live_habitat: Vector2i = made.ref
	assert_true(live_habitat != stale_habitat, "so a second habitat now exists")
	assert_equal(_fishing.habitat_count(), 2, "and both are live")
	assert_equal(_fishing.habitat_ref_for_basin(second_basin).ref, live_habitat,
		"and the scan finds exactly one match, not two")


func test_two_habitats_cannot_claim_one_basin() -> void:
	"""Ruling §8B requires exactly one match, so a duplicate is prevented at the binding."""
	_use_owner_stores()
	var basin: Vector2i = _make_fish_basin()
	var habitat: Vector2i = _fishing.create_habitat(RIVER, basin, _river_ids(), 0, 0, 0).ref
	assert_equal(_fishing.create_habitat(LAKE, basin, _lake_ids(), 0, 0, 0).error,
		Fishing.REFUSE_ZONE_ALREADY_BOUND, "a second habitat cannot be created on the basin")
	assert_equal(_fishing.habitat_count(), 1, "and none was allocated by the attempt")
	var unbound: Vector2i = _fishing.create_habitat(LAKE, EntityDirectory.NULL_REF, _lake_ids(),
		0, 0, 0).ref
	assert_equal(_fishing.bind_habitat_zone(unbound, basin).error,
		Fishing.REFUSE_ZONE_ALREADY_BOUND, "nor can an existing habitat be moved onto it")
	assert_equal(_fishing.habitat_ref_for_basin(basin).ref, habitat, "the owner is unchanged")
	assert_true(_fishing.bind_habitat_zone(habitat, basin).ok,
		"rebinding a habitat to the basin it already owns is not a duplicate")


func test_a_chained_basin_reference_refuses() -> void:
	"""Ruling §8B: a chained match refuses -- a chain would give two answers for one designation."""
	_use_owner_stores()
	var basin: Vector2i = _make_fish_basin()
	var habitat: Vector2i = _fishing.create_habitat(RIVER, basin, _river_ids(), 0, 0, 0).ref
	var designation: Vector2i = _make_designation(basin)
	assert_equal(_fishing.habitat_ref_for_designation(designation).ref, habitat, "it resolves")
	var other: Vector2i = _make_fish_basin()
	assert_true(_zones.set_basin(basin, other).ok, "the basin is itself bound onward")
	assert_equal(_fishing.habitat_ref_for_designation(designation).error,
		Fishing.REFUSE_BASIN_CHAIN, "so the designation now resolves through a chain, and refuses")
	assert_equal(_fishing.create_habitat(LAKE, designation, _lake_ids(), 0, 0, 0).error,
		Fishing.REFUSE_BASIN_CHAIN, "and no habitat may be created on a bound designation")


func test_binding_refuses_a_zone_that_is_not_a_fish_basin() -> void:
	"""§4.3's ZoneType.FISH is checked once the HarvestZone store is available (module header)."""
	_use_owner_stores()
	var forage_zone: Vector2i = _zones.create_zone(ZONE_FORAGE, 1, 1000, false, true).ref
	assert_equal(_fishing.create_habitat(RIVER, forage_zone, _river_ids(), 0, 0, 0).error,
		Fishing.REFUSE_ZONE_NOT_FISH, "a forage basin owns no fish")
	var habitat: Vector2i = _fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		_river_ids(), 0, 0, 0).ref
	assert_equal(_fishing.bind_habitat_zone(habitat, forage_zone).error,
		Fishing.REFUSE_ZONE_NOT_FISH, "and cannot be bound one afterwards")
	assert_equal(_fishing.habitat_zone_ref_of(_fishing.habitat_slot_of(habitat).value),
		EntityDirectory.NULL_REF, "the refused binding wrote nothing")


func test_binding_a_habitat_to_its_basin_creates_and_resets_nothing() -> void:
	"""Ruling §8B: binding is ownership bookkeeping, never a stock, quota or latch event."""
	_use_owner_stores()
	var habitat: Vector2i = _fishing.create_habitat(RIVER, EntityDirectory.NULL_REF,
		_river_ids(), 0, 0, 0).ref
	var slot: int = _fishing.habitat_slot_of(habitat).value
	assert_true(_fishing.harvest(habitat, 0, 20000, SPRING, 1).ok, "20 U of trout is taken first")
	assert_true(_fishing.reserve_effort_slots(_make_expedition(), _make_job(), habitat, 1).ok,
		"and one effort slot is held")
	var basin: Vector2i = _make_fish_basin()
	assert_true(_fishing.bind_habitat_zone(habitat, basin).ok, "the habitat binds to the basin")
	assert_equal(_fishing.habitat_zone_ref_of(slot), basin, "the reference is stored")
	assert_equal(_population(_row(habitat, 0)), TROUT_INITIAL - 20000, "the stock is unchanged")
	assert_equal(_fishing.harvested_today_total_of(slot).value, 20000, "the quota history too")
	assert_equal(_fishing.effort_slots_used_of(slot).value, 1, "and the effort occupancy")
	assert_equal(_fishing.population_total_milli_of(slot).value,
		RIVER_INITIAL_BIOMASS - 20000, "no fish were created by binding")


func test_designation_binding_needs_the_harvest_zone_store() -> void:
	"""Without forage.gd's HarvestZone rows the designation half cannot be answered at all."""
	var basin: Vector2i = _fishing.directory().create(EntityDirectory.KIND_HARVEST_ZONE)
	var habitat: Vector2i = _fishing.create_habitat(RIVER, basin, _river_ids(), 0, 0, 0).ref
	assert_equal(_fishing.habitat_ref_for_basin(basin).ref, habitat,
		"the basin scan needs no zone store")
	assert_equal(_fishing.habitat_ref_for_designation(basin).error, Fishing.REFUSE_NO_ZONE_STORE,
		"but the designation resolution refuses rather than guessing")
	assert_equal(_fishing.habitat_ref_for_basin(EntityDirectory.NULL_REF).error,
		Fishing.REFUSE_INVALID_ZONE_REF, "and the null reference names no basin")


# --- ruling 2026-09-11 §4.1: the event closure has ONE writer and ONE cause (decision 0055) -------
#
# §5.4 lists trout/dace/salmon under River and herring/mackerel/mussel under Coast, so within a
# habitat the species INDEX is 0/1/2 in that printed order. Transcribed rather than derived.

## River species indices: §5.4's printed trout, dace, salmon.
const INDEX_TROUT: int = 0
## Coast species indices: §5.4's printed herring, mackerel, mussel.
const INDEX_HERRING: int = 0
const INDEX_MACKEREL: int = 1


func _lake_habitat() -> Vector2i:
	"""Create the standard lake habitat and hand back its reference."""
	var created: Fishing.OpResult = _fishing.create_habitat(LAKE, EntityDirectory.NULL_REF,
		_lake_ids(), 0, 0, 0)
	assert_true(created.ok, "the standard lake habitat must be creatable")
	return created.ref


func test_the_mussel_event_closure_writes_every_present_mussel_stock() -> void:
	"""Ruling §4.1: ARCH-SYS-006 sets "each present mussel stock's event bit"."""
	var first: Vector2i = _coast()
	var second: Fishing.OpResult = _fishing.create_habitat(COAST, EntityDirectory.NULL_REF,
		_coast_ids(), 0, 0, 0)
	assert_true(second.ok, "a second coast habitat must be creatable")
	var mussel_a: int = _row(first, MUSSEL_INDEX)
	var mussel_b: int = _row(second.ref, MUSSEL_INDEX)
	assert_false(_fishing.is_event_closed(mussel_a), "both beds start open")
	assert_false(_fishing.is_event_closed(mussel_b), "including the second")
	var written: IntMath.IntResult = _fishing.apply_mussel_event_closure(true)
	assert_true(written.ok, "the sweep answers rather than refusing")
	assert_equal(written.value, 2, "two present mussel stocks were written")
	assert_true(_fishing.is_event_closed(mussel_a), "the first bed is closed")
	assert_true(_fishing.is_event_closed(mussel_b), "and so is the second")


func test_the_mussel_closure_reopens_when_it_is_written_false() -> void:
	"""Ruling §4.1: "Set it false otherwise" is a WRITE, not a step that is skipped."""
	var coast: Vector2i = _coast()
	var mussel: int = _row(coast, MUSSEL_INDEX)
	assert_equal(_fishing.apply_mussel_event_closure(true).value, 1, "one bed closes")
	assert_true(_fishing.is_event_closed(mussel), "and is closed")
	var reopened: IntMath.IntResult = _fishing.apply_mussel_event_closure(false)
	assert_true(reopened.ok, "the reopening sweep succeeds")
	assert_equal(reopened.value, 1, "writing the same one stock")
	assert_false(_fishing.is_event_closed(mussel), "which is open again")
	assert_false(_fishing.is_harvest_closed(mussel, SUMMER, 9), "and harvestable")


func test_the_mussel_closure_touches_no_other_species() -> void:
	"""Ruling §4.1 reserves the bit for one cause on one species; the sweep must stay narrow."""
	var coast: Vector2i = _coast()
	var river: Vector2i = _river()
	var lake: Vector2i = _lake_habitat()
	var untouched: Array[int] = [
		_row(coast, INDEX_HERRING), _row(coast, INDEX_MACKEREL),
		_row(river, 0), _row(river, 1), _row(river, 2),
		_row(lake, 0), _row(lake, 1), _row(lake, 2),
	]
	assert_equal(_fishing.apply_mussel_event_closure(true).value, 1,
		"only one mussel stock exists across three habitats, and only it is written")
	assert_true(_fishing.is_event_closed(_row(coast, MUSSEL_INDEX)), "the mussel bed is closed")
	for row: int in untouched:
		assert_false(_fishing.is_event_closed(row),
			"stock row %d is not a mussel bed and is untouched" % row)


func test_a_world_with_no_mussel_stock_writes_none_and_refuses_nothing() -> void:
	"""Zero present mussel stocks is an answer, not a refusal."""
	_river()
	_lake_habitat()
	var written: IntMath.IntResult = _fishing.apply_mussel_event_closure(true)
	assert_true(written.ok, "the sweep succeeds on a world with no coast")
	assert_equal(written.value, 0, "having written no stock")
	var empty: Fishing = Fishing.new()
	assert_equal(empty.apply_mussel_event_closure(true).value, 0,
		"and an empty store answers 0 as well")


func test_harvest_closed_is_the_union_of_the_calendar_and_the_event() -> void:
	"""Ruling §4.1: `harvest_closed = calendar_closed || event_closed`, as two named halves."""
	var river: Vector2i = _river()
	var trout: int = _row(river, INDEX_TROUT)
	assert_true(_fishing.is_calendar_closed(trout, SPRING, 5),
		"§5.4's trout spawning closure covers spring day 5")
	assert_false(_fishing.is_event_closed(trout), "which is a CALENDAR cause, not the event bit")
	assert_true(_fishing.is_harvest_closed(trout, SPRING, 5), "so the union is closed")
	assert_false(_fishing.is_calendar_closed(trout, SPRING, 8), "day 8 is outside the window")
	assert_false(_fishing.is_harvest_closed(trout, SPRING, 8), "and the union reopens")
	var coast: Vector2i = _coast()
	var mussel: int = _row(coast, MUSSEL_INDEX)
	_fishing.apply_mussel_event_closure(true)
	assert_true(_fishing.is_event_closed(mussel), "the mussel bed's EVENT bit is set")
	assert_false(_fishing.is_calendar_closed(mussel, SUMMER, 6),
		"§5.4 states no calendar window for mussels at all")
	assert_true(_fishing.is_harvest_closed(mussel, SUMMER, 6), "yet the union is closed")


func test_an_event_closed_mussel_bed_still_recovers() -> void:
	"""§5.4: ""closed" means no harvest job, not zero population" -- on the EVENT cause too."""
	var coast: Vector2i = _coast()
	var mussel: int = _row(coast, MUSSEL_INDEX)
	_drain_to(coast, MUSSEL_INDEX, MUSSEL_DEPLETION_BOUNDARY, SUMMER, 6)
	_fishing.apply_mussel_event_closure(true)
	assert_true(_fishing.is_event_closed(mussel), "the bed is closed by the event")
	var before: int = _population(mussel)
	assert_true(_fishing.recover_daily(SUMMER, 6).ok, "the daily recovery still runs")
	assert_true(_population(mussel) > before, "and the closed stock's population still grows")
	assert_true(_fishing.is_event_closed(mussel), "recovery does not clear the closure")


func test_the_habitat_catalog_is_verifiable_for_the_boundary_preflight() -> void:
	"""Ruling §4.1's preflight reads this before a boundary may commit anything."""
	assert_true(_fishing.catalog_is_verified(),
		"the compiled HabitatType ids are what HABITAT_SPECIES_ROWS is subscripted by")
