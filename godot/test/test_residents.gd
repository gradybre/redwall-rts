extends "res://test/framework/test_case.gd"
## Coverage for the residents store: species, slots, skills, and the GDD §5.8 demand divisor.
##
## Every fixture value below is restated from the specification, never read back out of the
## module under test. The two GDD §7.1 population fixtures are reproduced by actually spawning
## the residents, not by calling a projection helper, so the spawn path and the demand path are
## both on the hook for the numbers.

const Residents := preload("res://scripts/core/residents.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## GDD §4.3, ascending ASCII order over the 16 release-1 species keys. Restated as a literal so
## a change to the module's compile step cannot quietly renumber a species and stay green.
const SPECIES_ASCENDING: Array[StringName] = [
	&"badger", &"ferret", &"fox", &"hare", &"hedgehog", &"kestrel", &"mole", &"mouse",
	&"otter", &"rat", &"shrew", &"sparrow", &"squirrel", &"weasel", &"wildcat", &"wolverine",
]

## GDD §4.3: "Small species are the first six, medium the next six, large the last four" of the
## sentence order mouse, shrew, mole, rat, squirrel, sparrow, otter, ... wolverine.
const EXPECTED_SIZE_OF: Dictionary = {
	&"mouse": 0, &"shrew": 0, &"mole": 0, &"rat": 0, &"squirrel": 0, &"sparrow": 0,
	&"otter": 1, &"hare": 1, &"ferret": 1, &"weasel": 1, &"hedgehog": 1, &"kestrel": 1,
	&"badger": 2, &"fox": 2, &"wildcat": 2, &"wolverine": 2,
}

## GDD §5.3: "cumulative XP at levels 0-10 is 0,5000,20000,45000,80000,125000,180000,245000,
## 320000,405000,500000".
const LEVEL_XP: Array[int] = [
	0, 5000, 20000, 45000, 80000, 125000, 180000, 245000, 320000, 405000, 500000,
]

## GDD §7.1 starter fixture: "10 small and 2 medium residents consume 74400 NP/day".
const STARTER_DEMAND_NP: int = 74400

## GDD §7.1 population demand fixture.
const DEMAND_200_SMALL: int = 1200000
const DEMAND_200_SMALL_WINTER: int = 1440000
const DEMAND_MIXED: int = 1344000
const DEMAND_MIXED_WINTER: int = 1612800

const TICKS_PER_DAY: int = 18000
const HOURS_PER_DAY: int = 24
const MILLI_PER_POINT: int = 1000

var _residents: Residents = null


func before_each() -> void:
	"""Build a residents store owning a private directory and needs pair."""
	_residents = Residents.new()


func after_each() -> void:
	"""Drop the store built for the test."""
	_residents = null


func _spawn_many(species_key: StringName, count: int) -> void:
	"""Spawn `count` residents of one species, failing the test on the first refusal."""
	for index: int in count:
		var result: Residents.OpResult = _residents.spawn(species_key)
		if not result.ok:
			fail("spawn %d of %s refused: %s" % [index, species_key, result.error])
			return


# --- species catalog ---------------------------------------------------------------------------

func test_species_catalog_compiles_in_ascending_ascii_order() -> void:
	"""GDD §4.2: unlisted enum values come from ascending ASCII keys, not the §4.3 sentence order."""
	assert_equal(_residents.catalog_error(), "", "the species catalog compiled")
	assert_equal(_residents.species_count(), 16, "release 1 has 16 species")
	for index: int in SPECIES_ASCENDING.size():
		var key: StringName = SPECIES_ASCENDING[index]
		assert_equal(_residents.species_id(key).value, index, "%s compiles to id %d" % [key, index])
		assert_equal(_residents.species_key(index), key, "id %d reads back as %s" % [index, key])


func test_sentence_order_is_not_the_id_order() -> void:
	"""mouse is the first species named in §4.3 but is not species id 0; badger is."""
	assert_equal(_residents.species_id(&"mouse").value, 7, "mouse is id 7, not id 0")
	assert_equal(_residents.species_id(&"badger").value, 0, "badger sorts first")


func test_species_size_classes_follow_the_six_six_four_split() -> void:
	"""GDD §4.3: small is the first six species, medium the next six, large the last four."""
	var counts: Array[int] = [0, 0, 0]
	for key: StringName in EXPECTED_SIZE_OF:
		var size: IntMath.IntResult = _residents.species_size_class(key)
		assert_true(size.ok, "%s has a size class" % key)
		assert_equal(size.value, int(EXPECTED_SIZE_OF[key]), "%s size class" % key)
		counts[size.value] += 1
	assert_equal(counts[0], 6, "six small species")
	assert_equal(counts[1], 6, "six medium species")
	assert_equal(counts[2], 4, "four large species")


func test_unknown_species_is_refused_not_defaulted() -> void:
	"""A key outside the catalog refuses explicitly and spawns nothing."""
	assert_false(_residents.has_species(&"dragon"), "dragon is not a release-1 species")
	var id_result: IntMath.IntResult = _residents.species_id(&"dragon")
	assert_false(id_result.ok, "an unknown species id is refused")
	assert_equal(id_result.value, 0, "a refusal carries no usable value")
	var spawned: Residents.OpResult = _residents.spawn(&"dragon")
	assert_false(spawned.ok, "an unknown species cannot be spawned")
	assert_equal(spawned.error, Residents.REFUSE_UNKNOWN_SPECIES, "the refusal names the cause")
	assert_equal(_residents.population(), 0, "nothing was allocated")


func test_size_tables_match_the_specification() -> void:
	"""GDD §5.2: multipliers 1000/1200/1600, carry 12000/16000/24000 g, caps 3277/4096/3072 u/s."""
	var multipliers: Array[int] = [1000, 1200, 1600]
	var carry: Array[int] = [12000, 16000, 24000]
	var movement: Array[int] = [3277, 4096, 3072]
	for size: int in 3:
		assert_equal(_residents.size_multiplier(size).value, multipliers[size], "multiplier %d" % size)
		assert_equal(_residents.size_carry_g(size).value, carry[size], "carry %d" % size)
		assert_equal(_residents.size_movement_u_per_s(size).value, movement[size], "movement %d" % size)
	assert_false(_residents.size_multiplier(3).ok, "an out-of-range size class is refused")
	assert_false(_residents.size_carry_g(-1).ok, "a negative size class is refused")


# --- allocation through the directory ------------------------------------------------------------

func test_spawn_allocates_through_the_entity_directory() -> void:
	"""A spawned resident holds a live RESIDENT reference the directory itself validates."""
	var spawned: Residents.OpResult = _residents.spawn(&"mouse")
	assert_true(spawned.ok, "the mouse spawned")
	var directory: EntityDirectory = _residents.directory()
	assert_true(directory.is_valid_of_kind(spawned.ref, EntityDirectory.KIND_RESIDENT),
		"the reference validates as a RESIDENT")
	assert_equal(directory.live_count(EntityDirectory.KIND_RESIDENT), 1, "the directory counts it")
	assert_equal(directory.get_typed_row(spawned.ref), spawned.value, "the row is the typed row")
	assert_equal(_residents.ref_of(spawned.value), spawned.ref, "the row hands back its own ref")


func test_spawn_attaches_the_needs_columns() -> void:
	"""GDD §5.1 start state comes from needs.gd, at the same typed slot, with the right size."""
	var spawned: Residents.OpResult = _residents.spawn(&"otter")
	var slot: int = spawned.value
	var needs: NeedsScript = _residents.needs()
	assert_true(needs.is_present(slot), "a needs row exists at the same slot")
	assert_equal(needs.health_of(slot).value, 100, "health starts at 100")
	for need: int in NeedsScript.NEED_COUNT:
		assert_equal(needs.need_of(slot, need).value, 7500, "need %d starts at 7500" % need)
	assert_equal(needs.size_class_of(slot).value, 1, "the otter is medium in the needs store too")
	assert_equal(_residents.size_class_of(slot).value, 1, "and medium in the resident row")


func test_persistent_ids_are_monotonic_and_never_reused() -> void:
	"""GDD §4.1: persistent IDs are monotonically allocated and never reused; slots ARE reused."""
	var first: Residents.OpResult = _residents.spawn(&"mouse")
	var second: Residents.OpResult = _residents.spawn(&"mouse")
	assert_equal(_residents.persistent_id_of(first.value).value, 1, "the first resident is id 1")
	assert_equal(_residents.persistent_id_of(second.value).value, 2, "the second is id 2")
	assert_true(_residents.despawn(first.ref).ok, "the first resident leaves")
	var third: Residents.OpResult = _residents.spawn(&"mole")
	assert_equal(third.ref.x, first.ref.x, "the runtime slot was reused")
	assert_true(third.ref.y > first.ref.y, "the generation advanced on reuse")
	assert_equal(_residents.persistent_id_of(third.value).value, 3, "the persistent id did not")


func test_stale_reference_is_rejected_after_despawn() -> void:
	"""A reference to a released slot never resolves, even once the slot is reused."""
	var first: Residents.OpResult = _residents.spawn(&"mouse")
	_residents.despawn(first.ref)
	_residents.spawn(&"mouse")
	assert_false(_residents.directory().is_valid(first.ref), "the old reference is stale")
	var again: Residents.OpResult = _residents.despawn(first.ref)
	assert_false(again.ok, "a stale reference cannot despawn the row that replaced it")
	assert_equal(again.error, Residents.REFUSE_NOT_PRESENT, "the refusal is explicit")
	assert_equal(_residents.population(), 1, "the live resident survived")


func test_living_population_caps_at_256_with_an_explicit_refusal() -> void:
	"""GDD §4.1: storage is 512 rows but living population never exceeds 256."""
	_spawn_many(&"mouse", Residents.RESIDENT_LIVING_CAP)
	assert_equal(_residents.population(), 256, "256 residents are alive")
	var over: Residents.OpResult = _residents.spawn(&"mouse")
	assert_false(over.ok, "the 257th living resident is refused")
	assert_equal(over.error, EntityDirectory.REFUSAL_LIVING_CAP, "the living cap refuses, not storage")
	assert_equal(_residents.population(), 256, "nothing was silently dropped")


func test_a_freed_slot_reopens_the_living_cap() -> void:
	"""Refusal at the cap is a live-population limit, not a permanent exhaustion of the store."""
	_spawn_many(&"mouse", Residents.RESIDENT_LIVING_CAP)
	var last: Vector2i = _residents.ref_of(Residents.RESIDENT_LIVING_CAP - 1)
	assert_true(_residents.despawn(last).ok, "one resident leaves")
	var replacement: Residents.OpResult = _residents.spawn(&"mouse")
	assert_true(replacement.ok, "a replacement is admitted")
	assert_equal(_residents.population(), 256, "the population returns to the cap")


func test_clear_returns_the_store_to_empty() -> void:
	"""clear() releases every row and its directory slot without reallocating columns."""
	_residents.spawn_initial_settlement()
	_residents.clear()
	assert_equal(_residents.population(), 0, "no residents remain")
	assert_equal(_residents.living_count(), 0, "the needs store is empty too")
	assert_equal(_residents.directory().live_count(EntityDirectory.KIND_RESIDENT), 0,
		"the directory released every resident slot")
	assert_false(_residents.is_present(0), "row 0 is empty")


# --- GDD §5.1 initial settlement -----------------------------------------------------------------

func test_initial_settlement_is_twelve_adults_of_the_specified_species() -> void:
	"""GDD §5.1: "12 adults (6 mice, 2 moles, 2 otters, 2 squirrels); IDs 1-12"."""
	var spawned: Residents.OpResult = _residents.spawn_initial_settlement()
	assert_true(spawned.ok, "the settlement spawned")
	assert_equal(spawned.value, 12, "twelve adults arrived")
	var by_key: Dictionary = {}
	for slot: int in 12:
		var key: StringName = _residents.species_key(_residents.species_of(slot).value)
		by_key[key] = int(by_key.get(key, 0)) + 1
		assert_equal(_residents.persistent_id_of(slot).value, slot + 1, "IDs run 1-12 in row order")
	assert_equal(int(by_key.get(&"mouse", 0)), 6, "six mice")
	assert_equal(int(by_key.get(&"mole", 0)), 2, "two moles")
	assert_equal(int(by_key.get(&"otter", 0)), 2, "two otters")
	assert_equal(int(by_key.get(&"squirrel", 0)), 2, "two squirrels")


func test_initial_settlement_is_ten_small_and_two_medium() -> void:
	"""The §7.1 starter fixture's cohort: the only size fact its arithmetic depends on."""
	_residents.spawn_initial_settlement()
	var small: int = 0
	var medium: int = 0
	for slot: int in 12:
		if _residents.size_class_of(slot).value == Residents.SIZE_SMALL:
			small += 1
		elif _residents.size_class_of(slot).value == Residents.SIZE_MEDIUM:
			medium += 1
	assert_equal(small, 10, "ten small residents")
	assert_equal(medium, 2, "two medium residents")


func test_initial_settlement_needs_and_health() -> void:
	"""GDD §5.1: "all five needs 7500, health 100"."""
	_residents.spawn_initial_settlement()
	var needs: NeedsScript = _residents.needs()
	for slot: int in 12:
		assert_equal(needs.health_of(slot).value, 100, "resident %d starts at health 100" % slot)
		for need: int in NeedsScript.NEED_COUNT:
			assert_equal(needs.need_of(slot, need).value, 7500, "resident %d need %d" % [slot, need])


func test_rowan_is_the_warden_and_the_only_named_resident() -> void:
	"""GDD §5.1: "ID 1 named Warden Rowan"; nobody else is named at start."""
	_residents.spawn_initial_settlement()
	assert_equal(_residents.role_of(0).value, Residents.ROLE_WARDEN, "ID 1 is the Warden")
	assert_true(_residents.is_named(0), "the Warden is named")
	assert_equal(_residents.name_key_of(0), &"Warden Rowan", "the authored name is Warden Rowan")
	for slot: int in range(1, 12):
		assert_equal(_residents.role_of(slot).value, Residents.ROLE_RESIDENT, "row %d is a resident" % slot)
		assert_false(_residents.is_named(slot), "row %d is unnamed" % slot)


func test_initial_skill_levels_and_xp() -> void:
	"""GDD §5.1: level 2 everywhere except Rowan KEEP 3, reserved index 3 at zero."""
	_residents.spawn_initial_settlement()
	for skill: int in Residents.SKILL_COUNT:
		var expected_xp: int = 0 if skill == Residents.SKILL_RESERVED_INDEX else 20000
		var expected_level: int = 0 if skill == Residents.SKILL_RESERVED_INDEX else 2
		assert_equal(_residents.skill_xp_of(1, skill).value, expected_xp, "resident 2 skill %d XP" % skill)
		assert_equal(_residents.skill_level_of(1, skill).value, expected_level, "resident 2 skill %d" % skill)
	assert_equal(_residents.skill_xp_of(0, Residents.SKILL_KEEP).value, 45000, "Warden KEEP XP is 45000")
	assert_equal(_residents.skill_level_of(0, Residents.SKILL_KEEP).value, 3, "Warden KEEP is level 3")
	assert_equal(_residents.skill_xp_of(0, 0).value, 20000, "the Warden's other skills are 20000 XP")
	assert_equal(_residents.skill_xp_of(0, Residents.SKILL_RESERVED_INDEX).value, 0, "index 3 is 0 XP")


func test_initial_settlement_refuses_a_second_cohort() -> void:
	"""A double call would break the §5.1 "IDs 1-12" contract, so it is refused explicitly."""
	assert_true(_residents.spawn_initial_settlement().ok, "the first cohort spawns")
	var again: Residents.OpResult = _residents.spawn_initial_settlement()
	assert_false(again.ok, "a second cohort is refused")
	assert_equal(again.error, Residents.REFUSE_SETTLEMENT_NOT_EMPTY, "the refusal is explicit")
	assert_equal(_residents.population(), 12, "the population is unchanged")


func test_a_refused_cohort_leaves_no_resident_behind() -> void:
	"""OpResult promises a refusal carries no partially applied effect; the cohort must honour it.

	The refusal is provoked from outside: a shared needs store already holds a row at the typed
	slot the sixth spawn will be handed, so `needs.spawn()` refuses mid-cohort. Without a
	rollback the caller is told nothing was created while five residents stand in the store,
	unreachable because the call returned no references.
	"""
	var directory: EntityDirectory = EntityDirectory.new()
	var needs: NeedsScript = NeedsScript.new()
	var shared: Residents = Residents.new(directory, needs)
	var blocked_slot: int = _reserve_needs_row(directory, needs, 5)
	var spawned: Residents.OpResult = shared.spawn_initial_settlement()
	assert_false(spawned.ok, "the cohort is refused at the blocked slot")
	assert_equal(spawned.error, NeedsScript.REFUSE_ALREADY_PRESENT, "the needs refusal travels out")
	assert_equal(spawned.value, 0, "a refusal carries no count")
	assert_equal(shared.population(), 0, "no resident row survives the refusal")
	assert_equal(directory.live_count(EntityDirectory.KIND_RESIDENT), 0,
		"no directory slot survives the refusal")
	assert_equal(needs.present_count(), 1, "only the pre-existing blocking row remains")
	assert_true(needs.is_present(blocked_slot), "and it is untouched")
	var occupied: int = 0
	for slot: int in Residents.RESIDENT_CAPACITY:
		if shared.is_present(slot):
			occupied += 1
	assert_equal(occupied, 0, "not one of the 512 resident rows is occupied")


func _reserve_needs_row(directory: EntityDirectory, needs: NeedsScript, ordinal: int) -> int:
	"""Occupy the needs row the `ordinal`-th spawn will be handed, and return that slot.

	The typed row is learned from the directory rather than assumed: `ordinal` refs are created
	to walk the allocator forward, the next one is taken and immediately destroyed so the row
	returns to the free heap, and only the needs row is left occupied.
	"""
	var held: Array[Vector2i] = []
	for index: int in ordinal:
		held.append(directory.create(EntityDirectory.KIND_RESIDENT))
	var probe: Vector2i = directory.create(EntityDirectory.KIND_RESIDENT)
	var slot: int = directory.get_typed_row(probe)
	directory.destroy(probe)
	for ref: Vector2i in held:
		directory.destroy(ref)
	assert_true(needs.spawn(slot, Residents.SIZE_SMALL).ok, "the blocking needs row is written")
	return slot


func test_a_refused_spawn_does_not_burn_a_directory_slot() -> void:
	"""spawn() must roll its directory allocation back when the needs row is refused.

	Without the rollback every such refusal permanently consumes a RESIDENT row and a
	never-reused persistent id while telling the caller nothing was allocated -- 512 refusals
	would exhaust the settlement's capacity with an empty store.
	"""
	var directory: EntityDirectory = EntityDirectory.new()
	var needs: NeedsScript = NeedsScript.new()
	var shared: Residents = Residents.new(directory, needs)
	var blocked_slot: int = _reserve_needs_row(directory, needs, 0)
	var free_rows_before: int = directory.free_row_count(EntityDirectory.KIND_RESIDENT)
	var refused: Residents.OpResult = shared.spawn(&"mouse")
	assert_false(refused.ok, "the spawn is refused at the occupied needs row")
	assert_equal(refused.error, NeedsScript.REFUSE_ALREADY_PRESENT, "the refusal is explicit")
	assert_equal(refused.ref, EntityDirectory.NULL_REF, "a refusal hands back the null reference")
	assert_equal(directory.live_count(EntityDirectory.KIND_RESIDENT), 0,
		"the directory allocation was rolled back")
	assert_equal(directory.free_row_count(EntityDirectory.KIND_RESIDENT), free_rows_before,
		"the typed row was returned to the free heap, not burned")
	assert_equal(shared.population(), 0, "no resident row was written")
	assert_true(needs.is_present(blocked_slot), "the blocking needs row is left alone")


func test_home_and_bed_stay_null_because_no_building_store_exists() -> void:
	"""GDD §5.1 assigns 12 beds, but no Building/Room/Furniture store exists in this milestone."""
	_residents.spawn_initial_settlement()
	for slot: int in 12:
		assert_equal(_residents.home_of(slot), EntityDirectory.NULL_REF, "row %d has no home" % slot)
		assert_equal(_residents.bed_of(slot), EntityDirectory.NULL_REF, "row %d has no bed" % slot)


# --- skills ---------------------------------------------------------------------------------------

func test_skill_level_curve_matches_the_cumulative_table() -> void:
	"""GDD §5.3: level = min(10, floor_sqrt(floor(xp/5000))), tabulated 0..500000."""
	for level: int in LEVEL_XP.size():
		assert_equal(_residents.skill_level_for_xp(LEVEL_XP[level]), level, "%d XP is level %d" % [LEVEL_XP[level], level])
		if level > 0:
			assert_equal(_residents.skill_level_for_xp(LEVEL_XP[level] - 1), level - 1,
				"one XP short of level %d is level %d" % [level, level - 1])
	assert_equal(_residents.skill_level_for_xp(999999), 10, "level caps at 10")
	assert_equal(_residents.skill_level_for_xp(0), 0, "no XP is level 0")


func test_setting_skill_xp_rederives_the_level() -> void:
	"""Level is never stored independently of XP; writing XP recomputes it."""
	var spawned: Residents.OpResult = _residents.spawn(&"mouse")
	var slot: int = spawned.value
	assert_true(_residents.set_skill_xp(slot, 6, 125000).ok, "COOK XP is written")
	assert_equal(_residents.skill_level_of(slot, 6).value, 5, "125000 XP is level 5")
	assert_equal(_residents.skill_xp_of(slot, 6).value, 125000, "the XP reads back")


func test_skill_into_readers_match_wrappers_at_the_level_cap() -> void:
	"""The work-facing readers preserve XP and level exactly at level 10's boundary."""
	var slot: int = _residents.spawn(&"mouse").value
	assert_true(_residents.set_skill_xp(slot, 6, 500000).ok, "level-10 XP is written")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_residents.skill_xp_into(slot, 6, out), "XP reads into caller scratch")
	assert_equal(out.value, _residents.skill_xp_of(slot, 6).value, "XP wrapper parity")
	assert_equal(out.value, 500000, "the level-10 threshold is exact")
	assert_true(_residents.skill_level_into(slot, 6, out), "level reuses the scratch")
	assert_equal(out.value, _residents.skill_level_of(slot, 6).value, "level wrapper parity")
	assert_equal(out.value, 10, "500000 XP reads as level 10")


func test_skill_into_reuse_clears_refusals_and_stale_values() -> void:
	"""A failed skill address zeroes a reused output, and a later success clears its error."""
	var slot: int = _residents.spawn(&"mouse").value
	assert_true(_residents.set_skill_xp(slot, 6, 125000).ok, "skill XP is written")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_residents.skill_xp_into(slot, 6, out), "seed the scratch with XP")
	assert_false(_residents.skill_level_into(slot, Residents.SKILL_COUNT, out), "bad skill refuses")
	assert_equal(out.error, String(Residents.REFUSE_INVALID_SKILL), "the exact refusal survives")
	assert_equal(out.value, 0, "the old XP is cleared")
	assert_true(_residents.skill_level_into(slot, 6, out), "the output can be reused")
	assert_equal(out.value, 5, "the later level is correct")
	assert_equal(out.error, "", "the old refusal is cleared")
	assert_false(_residents.skill_xp_into(1, 6, out), "an absent row refuses")
	assert_equal(out.error, String(Residents.REFUSE_NOT_PRESENT), "absence keeps its public code")
	assert_equal(out.value, 0, "absence cannot leak level 5")


func test_skill_allocating_wrappers_stay_fresh() -> void:
	"""Retainable convenience reads return distinct objects while sharing the `_into` logic."""
	var slot: int = _residents.spawn(&"mouse").value
	assert_false(_residents.skill_xp_of(slot, 0) == _residents.skill_xp_of(slot, 0),
		"XP wrappers are fresh")
	assert_false(_residents.skill_level_of(slot, 0) == _residents.skill_level_of(slot, 0),
		"level wrappers are fresh")


func test_reserved_skill_index_and_bad_input_are_refused() -> void:
	"""GDD §5.1 fixes reserved index 3 at zero; negative XP and unknown columns are refused."""
	var slot: int = _residents.spawn(&"mouse").value
	var reserved: Residents.OpResult = _residents.set_skill_xp(slot, Residents.SKILL_RESERVED_INDEX, 5000)
	assert_false(reserved.ok, "the reserved skill index cannot be given XP")
	assert_equal(reserved.error, Residents.REFUSE_RESERVED_SKILL, "the refusal names the reserved index")
	assert_false(_residents.set_skill_xp(slot, 0, -1).ok, "negative XP is refused")
	assert_false(_residents.set_skill_xp(slot, 12, 5000).ok, "an out-of-range skill is refused")
	assert_equal(_residents.skill_xp_of(slot, Residents.SKILL_RESERVED_INDEX).value, 0, "index 3 is still 0")


func test_readers_refuse_an_absent_row_instead_of_returning_zero() -> void:
	"""An empty row is a refusal, never a plausible looking default."""
	assert_false(_residents.species_of(0).ok, "an empty row has no species")
	assert_false(_residents.size_class_of(0).ok, "an empty row has no size class")
	assert_false(_residents.persistent_id_of(0).ok, "an empty row has no persistent id")
	assert_false(_residents.skill_xp_of(0, 0).ok, "an empty row has no skills")
	assert_false(_residents.resident_daily_demand_np(0).ok, "an empty row has no demand")
	assert_equal(_residents.name_key_of(0), &"", "an empty row has no name")


# --- GDD §5.8 daily demand -------------------------------------------------------------------------

func test_starter_cohort_daily_demand_reproduces_the_gdd_fixture() -> void:
	"""GDD §7.1 starter fixture: "10 small and 2 medium residents consume 74400 NP/day"."""
	_residents.spawn_initial_settlement()
	var demand: IntMath.IntResult = _residents.daily_demand_np()
	assert_true(demand.ok, "the starting settlement has a demand")
	assert_equal(demand.value, STARTER_DEMAND_NP, "the starting cohort needs 74400 NP/day")


func test_population_demand_fixture_two_hundred_small_residents() -> void:
	"""GDD §7.1: "200 small residents require 1,200,000 NP/day ... Winter 1,440,000"."""
	_spawn_many(&"mouse", 200)
	assert_equal(_residents.daily_demand_np().value, DEMAND_200_SMALL, "200 small need 1,200,000 NP/day")
	_residents.set_winter(true)
	assert_equal(_residents.daily_demand_np().value, DEMAND_200_SMALL_WINTER, "winter needs 1,440,000")


func test_population_demand_fixture_mixed_cohort() -> void:
	"""GDD §7.1: "(120+60*1.2+20*1.6)*6000=1,344,000 NP/day; winter 1,612,800"."""
	_spawn_many(&"mouse", 120)
	_spawn_many(&"otter", 60)
	_spawn_many(&"badger", 20)
	assert_equal(_residents.population(), 200, "the mixed cohort is 200 residents")
	assert_equal(_residents.daily_demand_np().value, DEMAND_MIXED, "the mixed cohort needs 1,344,000")
	_residents.set_winter(true)
	assert_equal(_residents.daily_demand_np().value, DEMAND_MIXED_WINTER, "winter needs 1,612,800")


func test_projected_cohort_demand_matches_the_spawned_cohort() -> void:
	"""The forecast helper and the live population path must not drift apart."""
	_spawn_many(&"mouse", 120)
	_spawn_many(&"otter", 60)
	_spawn_many(&"badger", 20)
	assert_equal(_residents.daily_demand_for_cohort(120, 60, 20).value, DEMAND_MIXED, "projection agrees")
	_residents.set_winter(true)
	assert_equal(_residents.daily_demand_for_cohort(120, 60, 20).value, DEMAND_MIXED_WINTER, "in winter too")
	var empty: IntMath.IntResult = _residents.daily_demand_for_cohort(0, 0, 0)
	assert_false(empty.ok, "an empty cohort is refused")
	assert_equal(empty.error, String(Residents.REFUSE_NO_LIVING_RESIDENTS),
		"an empty cohort is refused for having no residents")
	for negative: Array in [[-1, 0, 0], [0, -1, 0], [0, 0, -1]]:
		var refused: IntMath.IntResult = _residents.daily_demand_for_cohort(
			negative[0], negative[1], negative[2])
		assert_false(refused.ok, "a negative count %s is refused" % [negative])
		assert_equal(refused.error, String(Residents.REFUSE_INVALID_COUNT),
			"the refusal names the bad count, not a skill XP value")
		assert_equal(refused.value, 0, "a refusal carries no usable number")


func test_per_resident_demand_matches_the_size_multipliers() -> void:
	"""GDD §4.1's 6000 NP/day baseline scaled by the §5.2 size multipliers, exactly."""
	var small: int = _residents.spawn(&"mouse").value
	var medium: int = _residents.spawn(&"otter").value
	var large: int = _residents.spawn(&"badger").value
	assert_equal(_residents.resident_daily_demand_np(small).value, 6000, "a small resident needs 6000")
	assert_equal(_residents.resident_daily_demand_np(medium).value, 7200, "a medium resident needs 7200")
	assert_equal(_residents.resident_daily_demand_np(large).value, 9600, "a large resident needs 9600")
	_residents.set_winter(true)
	assert_equal(_residents.resident_daily_demand_np(small).value, 7200, "winter small needs 7200")
	assert_equal(_residents.resident_daily_demand_np(medium).value, 8640, "winter medium needs 8640")
	assert_equal(_residents.resident_daily_demand_np(large).value, 11520, "winter large needs 11520")


func test_daily_demand_agrees_with_the_needs_hunger_rate() -> void:
	"""Independent derivation: §5.2's 250/hour x size x season over 24 hours is the same NP/day.

	The two paths share no arithmetic -- needs.gd folds the multipliers into a milli-need-point
	hourly rate at each season change, this module multiplies a daily baseline -- so agreement is
	a real cross-check on both, not a restatement.
	"""
	for winter: bool in [false, true]:
		_residents.set_winter(winter)
		for size: int in 3:
			var hourly: IntMath.IntResult = _residents.needs().hunger_rate_milli_per_hour(size)
			assert_true(hourly.ok, "needs publishes an hourly rate for size %d" % size)
			var per_day: int = hourly.value * HOURS_PER_DAY / MILLI_PER_POINT
			var demand: int = _residents.daily_demand_for_cohort(
				1 if size == 0 else 0, 1 if size == 1 else 0, 1 if size == 2 else 0).value
			assert_equal(demand, per_day, "size %d demand equals 24h of hunger decay" % size)


func test_demand_is_refused_when_no_resident_is_alive() -> void:
	"""GDD §5.8 gives no food-days value for zero demand, so the divisor refuses instead."""
	var empty: IntMath.IntResult = _residents.daily_demand_np()
	assert_false(empty.ok, "an empty settlement has no demand")
	assert_equal(empty.error, String(Residents.REFUSE_NO_LIVING_RESIDENTS), "the refusal is explicit")
	assert_equal(empty.value, 0, "a refusal carries no usable value")


func test_wounded_residents_count_and_dead_residents_do_not() -> void:
	"""GDD §5.8: "wounded residents still count". A dead row leaves the demand."""
	_spawn_many(&"mouse", 3)
	var needs: NeedsScript = _residents.needs()
	assert_true(needs.apply_health_event(1, -80).ok, "resident 1 is badly wounded")
	assert_equal(_residents.daily_demand_np().value, 18000, "three residents including the wounded one")
	assert_true(needs.apply_health_event(2, -100).ok, "resident 2 dies")
	assert_false(_residents.is_alive(2), "resident 2 is dead")
	assert_equal(_residents.daily_demand_np().value, 12000, "the dead resident leaves the demand")
	assert_equal(_residents.population(), 3, "the row is still present, it is simply not living")


func test_season_multiplier_follows_the_shared_needs_store() -> void:
	"""One winter flag drives both the hunger integrator and the demand divisor."""
	assert_equal(_residents.season_multiplier(), 1000, "spring/summer/autumn do not scale demand")
	assert_false(_residents.is_winter(), "the store starts outside winter")
	assert_true(_residents.set_winter(true).ok, "winter is set")
	assert_true(_residents.needs().is_winter(), "the needs store saw it")
	assert_equal(_residents.season_multiplier(), 1200, "GDD §5.2 winter is x1.20")


func test_despawned_residents_leave_the_demand() -> void:
	"""Demand tracks the live population, not the high-water mark."""
	var first: Residents.OpResult = _residents.spawn(&"mouse")
	_residents.spawn(&"badger")
	assert_equal(_residents.daily_demand_np().value, 15600, "one small plus one large")
	assert_true(_residents.despawn(first.ref).ok, "the mouse leaves")
	assert_equal(_residents.daily_demand_np().value, 9600, "only the badger remains")
# --- GDD §4.2 Equipment mirror (decision 0061) -------------------------------------------------
#
# Four of the ledgered Equipment row's five I32 columns live here; `clothing_tier` stays in
# `needs.gd`, which already applies tier 1 at spawn. The tool columns MIRROR the authoritative
# GearInstance row in `gear.gd`, which is the only legitimate writer -- `test_gear.gd` owns the
# cross-store behaviour. What is pinned here is the store's own contract.


func _spawn_one() -> int:
	"""Spawn one mouse and return its typed row."""
	var spawned: Residents.OpResult = _residents.spawn(&"mouse")
	assert_true(spawned.ok, "spawning a resident must succeed: %s" % spawned.error)
	return spawned.value


func test_the_equipment_mirror_occupies_its_ledgered_columns_and_no_more() -> void:
	"""systems_architecture.md §3 bills Equipment as 4 bytes x 5 columns x 512 = 10240.

	Four of those columns are allocated here: 8192 bytes. The fifth, `clothing_tier`, is
	`needs.gd`'s existing column, and billing it a second time is exactly what READY_07 §7.2
	step 2 forbids -- so the ledger total does not move for this increment.
	"""
	assert_equal(_residents.equipment_payload_bytes(), 8192,
		"four I32 columns at 512 rows are 8192 bytes")
	assert_equal(Residents.EQUIPMENT_MIRROR_BYTES, 8192, "and the published constant agrees")
	assert_equal(Residents.EQUIPMENT_MIRROR_COLUMNS, 4, "over four columns")
	assert_equal(4 * 5 * Residents.RESIDENT_CAPACITY, 10240,
		"against a ledgered five-column row of 10240 bytes, the fifth being clothing_tier")
	assert_equal(NeedsScript.CLOTHING_TIER_MIN, 1,
		"which needs.gd already applies as §5.9's tier-1 spawn equipment")


func test_a_spawned_resident_carries_no_tool_and_no_satchel() -> void:
	"""The §4.2 defaults: an empty mirror, not a plausible-looking zero."""
	var slot: int = _spawn_one()
	assert_false(_residents.has_equipped_tool(slot), "no tool is equipped at spawn")
	assert_equal(_residents.satchel_of(slot), Residents.NULL_REF, "and no satchel is bound")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_false(_residents.equipped_tool_item_id_into(slot, out),
		"reading the item id refuses rather than returning a plausible number")
	assert_equal(out.error, String(Residents.REFUSE_NO_EQUIPPED_TOOL), "with an explicit reason")
	assert_false(_residents.equipped_tool_durability_into(slot, out),
		"and so does reading the durability")
	assert_equal(out.value, 0, "a refusal carries no usable value")


func test_the_mirror_records_an_equipped_tool_and_gives_it_back() -> void:
	"""The write and the two readers agree, and the readers refuse for an absent row."""
	var slot: int = _spawn_one()
	assert_true(_residents.set_equipped_tool(slot, 8, 1000).ok, "the mirror takes a tool")
	assert_true(_residents.has_equipped_tool(slot), "which it then reports")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_residents.equipped_tool_item_id_into(slot, out), "the item id reads back")
	assert_equal(out.value, 8, "exactly as written")
	assert_true(_residents.equipped_tool_durability_into(slot, out), "and so does the durability")
	assert_equal(out.value, 1000, "exactly as written")
	assert_false(_residents.equipped_tool_item_id_into(Residents.RESIDENT_CAPACITY - 1, out),
		"an unspawned row refuses")
	assert_equal(out.error, String(Residents.REFUSE_NOT_PRESENT), "naming the absent row")


func test_the_mirror_refuses_a_second_tool_for_one_resident() -> void:
	"""§4.2 gives a resident exactly one `tool_item_id`, so this is a refusal, not a replacement."""
	var slot: int = _spawn_one()
	assert_true(_residents.set_equipped_tool(slot, 8, 1000).ok, "the first tool goes on")
	var second: Residents.OpResult = _residents.set_equipped_tool(slot, 8, 400)
	assert_false(second.ok, "the second refuses")
	assert_equal(second.error, Residents.REFUSE_TOOL_ALREADY_EQUIPPED, "named explicitly")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_residents.equipped_tool_durability_into(slot, out), "and the first is intact")
	assert_equal(out.value, 1000, "at the durability it was written with")


func test_refreshing_or_clearing_a_mirror_that_holds_no_tool_refuses() -> void:
	"""Neither writer may invent an equipped tool out of an empty row."""
	var slot: int = _spawn_one()
	var refreshed: Residents.OpResult = _residents.set_equipped_tool_durability(slot, 500)
	assert_false(refreshed.ok, "there is no durability to refresh")
	assert_equal(refreshed.error, Residents.REFUSE_NO_EQUIPPED_TOOL, "named explicitly")
	var cleared: Residents.OpResult = _residents.clear_equipped_tool(slot)
	assert_false(cleared.ok, "and nothing to clear")
	assert_equal(cleared.error, Residents.REFUSE_NO_EQUIPPED_TOOL, "named explicitly")
	assert_false(_residents.has_equipped_tool(slot), "the row is still empty")


func test_the_mirror_refuses_a_negative_item_id_or_durability() -> void:
	"""An out-of-range write is refused rather than truncated into a plausible column value."""
	var slot: int = _spawn_one()
	assert_equal(_residents.set_equipped_tool(slot, -1, 1000).error,
		Residents.REFUSE_INVALID_ITEM_ID, "a negative item id is not a tool")
	assert_equal(_residents.set_equipped_tool(slot, 8, -1).error,
		Residents.REFUSE_INVALID_DURABILITY, "and negative durability is not durability")
	assert_false(_residents.has_equipped_tool(slot), "neither refusal wrote anything")


func test_despawning_a_resident_empties_its_equipment_mirror() -> void:
	"""A reused row must never inherit the previous resident's tool.

	MUTATION GAP: `has_equipped_tool()` is false for an absent row whatever the columns hold, and
	a fresh spawn rewrites them anyway, so neither reader can tell whether despawn cleared
	anything. The byte image can, and does.
	"""
	var slot: int = _spawn_one()
	var ref: Vector2i = _residents.ref_of(slot)
	var empty: PackedByteArray = _residents.equipment_state_bytes()
	assert_true(_residents.set_equipped_tool(slot, 8, 1000).ok, "the resident carries a tool")
	assert_true(_residents.set_satchel(slot, Vector2i(3, 1)).ok, "and a satchel")
	assert_true(_residents.equipment_state_bytes() != empty, "which the image shows")
	assert_true(_residents.despawn(ref).ok, "the resident leaves")
	assert_equal(_residents.equipment_state_bytes(), empty,
		"and despawn cleared both columns, byte for byte, not merely hid them")
	assert_false(_residents.has_equipped_tool(slot), "the mirror is emptied on despawn")
	var next: int = _spawn_one()
	assert_equal(next, slot, "the row is reused")
	assert_false(_residents.has_equipped_tool(next), "and the new resident inherits no tool")
	assert_equal(_residents.satchel_of(next), Residents.NULL_REF, "nor a satchel")


func test_a_satchel_reference_is_stored_and_cleared_but_never_guessed() -> void:
	"""The container itself belongs to inventory.gd; only the §4.2 reference lives here."""
	var slot: int = _spawn_one()
	assert_true(_residents.set_satchel(slot, Vector2i(5, 2)).ok, "a valid reference is taken")
	assert_equal(_residents.satchel_of(slot), Vector2i(5, 2), "and read back exactly")
	assert_true(_residents.set_satchel(slot, Residents.NULL_REF).ok, "the null ref clears it")
	assert_equal(_residents.satchel_of(slot), Residents.NULL_REF, "leaving no satchel")
	var bad: Residents.OpResult = _residents.set_satchel(slot, Vector2i(5, 0))
	assert_false(bad.ok, "a slot with a null generation is not a usable reference")
	assert_equal(bad.error, Residents.REFUSE_INVALID_CONTAINER, "named explicitly")


func test_the_equipment_image_changes_with_the_mirror_and_only_with_it() -> void:
	"""The byte image the equip rollback checks is sensitive to every column it covers."""
	var slot: int = _spawn_one()
	var empty: PackedByteArray = _residents.equipment_state_bytes()
	assert_true(_residents.set_equipped_tool(slot, 8, 1000).ok, "equip in the mirror")
	assert_true(_residents.equipment_state_bytes() != empty, "the image moved")
	assert_true(_residents.clear_equipped_tool(slot).ok, "clear it again")
	assert_equal(_residents.equipment_state_bytes(), empty, "and the image came back exactly")
	assert_true(_residents.set_skill_xp(slot, 0, 5000).ok, "an unrelated column changes")
	assert_equal(_residents.equipment_state_bytes(), empty, "without moving the equipment image")




# --- MOVE-DEP-R02 life stage --------------------------------------------------------------------
#
# Every value below is restated from `docs/rulings/2026-09-12_movement_dependency_rulings.md` and
# `docs/planning/species_rig_identity.json`, never read back out of the module under test.

## MOVE-DEP-R02: "Stable `LifeStage` encoding: ADULT 0, CHILD 1, ELDER 2; COUNT 3 is a bound,
## never a stored stage."
const EXPECTED_ADULT: int = 0
const EXPECTED_CHILD: int = 1
const EXPECTED_ELDER: int = 2
const EXPECTED_STAGE_COUNT: int = 3


func test_the_life_stage_domain_is_exactly_the_three_ruled_values() -> void:
	"""MOVE-DEP-R02's encoding, transcribed from the ruling rather than read from the module."""
	assert_equal(Residents.LIFE_STAGE_ADULT, EXPECTED_ADULT, "ADULT is 0")
	assert_equal(Residents.LIFE_STAGE_CHILD, EXPECTED_CHILD, "CHILD is 1")
	assert_equal(Residents.LIFE_STAGE_ELDER, EXPECTED_ELDER, "ELDER is 2")
	assert_equal(Residents.LIFE_STAGE_COUNT, EXPECTED_STAGE_COUNT, "COUNT is the bound 3")
	assert_equal(Residents.LIFE_STAGE_KEYS.size(), EXPECTED_STAGE_COUNT, "three names, no more")
	assert_equal(_residents.life_stage_key(EXPECTED_ADULT), &"ADULT", "stage 0 names ADULT")
	assert_equal(_residents.life_stage_key(EXPECTED_CHILD), &"CHILD", "stage 1 names CHILD")
	assert_equal(_residents.life_stage_key(EXPECTED_ELDER), &"ELDER", "stage 2 names ELDER")


func test_the_bound_is_not_itself_a_stage() -> void:
	"""COUNT is a bound: it is not storable and it has no name."""
	assert_true(_residents.is_life_stage(EXPECTED_ADULT), "ADULT is a stage")
	assert_true(_residents.is_life_stage(EXPECTED_CHILD), "CHILD is a stage")
	assert_true(_residents.is_life_stage(EXPECTED_ELDER), "ELDER is a stage")
	assert_false(_residents.is_life_stage(EXPECTED_STAGE_COUNT), "COUNT is never a stage")
	assert_false(_residents.is_life_stage(-1), "no negative stage exists")
	assert_equal(_residents.life_stage_key(EXPECTED_STAGE_COUNT), &"",
		"the bound has no report name")
	assert_equal(_residents.life_stage_key(-1), &"", "nor does a negative value")


func test_a_plain_spawn_is_adult_and_names_the_stage_it_uses() -> void:
	"""`spawn()` preserves movement.gd's adult 0; nothing is left to an implicit default."""
	var spawned: Residents.OpResult = _residents.spawn(&"mouse")
	assert_true(spawned.ok, "a mouse spawns")
	var stage: IntMath.IntResult = _residents.life_stage_of(spawned.value)
	assert_true(stage.ok, "the row carries a stage")
	assert_equal(stage.value, EXPECTED_ADULT, "and it is ADULT")


func test_every_ruled_stage_is_storable_and_reads_back_exactly() -> void:
	"""MOVE-DEP-R02 permits isolated fixtures to exercise all three values."""
	var stages: Array[int] = [EXPECTED_ADULT, EXPECTED_CHILD, EXPECTED_ELDER]
	for stage: int in stages:
		var spawned: Residents.OpResult = _residents.spawn_with_stage(&"mouse", stage)
		assert_true(spawned.ok, "stage %d spawns: %s" % [stage, spawned.error])
		assert_equal(_residents.life_stage_of(spawned.value).value, stage,
			"stage %d reads back unchanged" % stage)
	assert_equal(_residents.population(), 3, "three rows exist")


func test_an_out_of_domain_stage_refuses_and_allocates_nothing() -> void:
	"""Refused, never clamped: a clamp would write ADULT and lose the caller's error."""
	var rejected: Array[int] = [-1, EXPECTED_STAGE_COUNT, 4, 255]
	for stage: int in rejected:
		var spawned: Residents.OpResult = _residents.spawn_with_stage(&"mouse", stage)
		assert_false(spawned.ok, "stage %d is refused" % stage)
		assert_equal(spawned.error, Residents.REFUSE_INVALID_LIFE_STAGE, "the refusal names it")
		assert_equal(spawned.value, 0, "a refusal carries no usable value")
	assert_equal(_residents.population(), 0, "no directory slot was consumed")
	assert_equal(_residents.directory().live_count(EntityDirectory.KIND_RESIDENT), 0,
		"and the directory allocated nothing either")


func test_a_stage_that_would_truncate_into_a_byte_is_refused() -> void:
	"""256 is 0 modulo a PackedByteArray element: an unchecked store would read back as ADULT.

	Same defect class as the int32/int64 sign trap below -- a value that is wrong but lands on a
	plausible-looking stage is worse than one that lands on an obviously broken one.
	"""
	var spawned: Residents.OpResult = _residents.spawn_with_stage(&"mouse", 256)
	assert_false(spawned.ok, "256 is not ADULT")
	assert_equal(spawned.error, Residents.REFUSE_INVALID_LIFE_STAGE, "it is refused by name")
	assert_equal(_residents.population(), 0, "and nothing was written")


func test_the_int32_sign_trap_does_not_smuggle_a_stage_through() -> void:
	"""GDScript ints are 64-bit, so 0x80000000 is POSITIVE and a naive `stage < 0` misses it.

	Its int32 reading is -2147483648. Both spellings must refuse, and so must the unsigned
	all-ones pattern, which is -1 read as int32.
	"""
	var traps: Array[int] = [0x80000000, -2147483648, 0xFFFFFFFF, 0x100000000]
	for stage: int in traps:
		var spawned: Residents.OpResult = _residents.spawn_with_stage(&"mouse", stage)
		assert_false(spawned.ok, "0x%X is refused" % stage)
		assert_equal(spawned.error, Residents.REFUSE_INVALID_LIFE_STAGE, "by name")
	assert_true(0x80000000 > 0, "the trap itself: this literal is positive in GDScript")
	assert_equal(_residents.population(), 0, "no trap value reached a column")


func test_the_twelve_starters_are_all_adults() -> void:
	"""GDD §5.1 "12 adults"; MOVE-DEP-R02 "the twelve starters pass ADULT"."""
	assert_true(_residents.spawn_initial_settlement().ok, "the cohort spawns")
	assert_equal(_residents.population(), 12, "twelve rows")
	for index: int in 12:
		var stage: IntMath.IntResult = _residents.life_stage_of(index)
		assert_true(stage.ok, "starter row %d exists" % index)
		assert_equal(stage.value, EXPECTED_ADULT, "starter row %d is ADULT" % index)


func test_a_reused_slot_initializes_its_stage_explicitly() -> void:
	"""MOVE-DEP-R02: "free-slot reuse explicitly initializes stage"."""
	var elder: Residents.OpResult = _residents.spawn_with_stage(&"mouse", EXPECTED_ELDER)
	assert_equal(_residents.life_stage_of(elder.value).value, EXPECTED_ELDER, "an elder first")
	assert_true(_residents.despawn(elder.ref).ok, "the elder retires")
	var reused: Residents.OpResult = _residents.spawn(&"mouse")
	assert_equal(reused.value, elder.value, "the same typed row is handed out again")
	assert_equal(_residents.life_stage_of(reused.value).value, EXPECTED_ADULT,
		"and the new adult is not wearing the previous tenant's stage")


func test_a_retired_row_holds_the_canonical_unused_zero() -> void:
	"""MOVE-DEP-R02: "Unused rows use 0 and remain distinguished by occupancy/generation"."""
	var child: Residents.OpResult = _residents.spawn_with_stage(&"mouse", EXPECTED_CHILD)
	assert_true(_residents.despawn(child.ref).ok, "the child retires")
	var stage: IntMath.IntResult = _residents.life_stage_of(child.value)
	assert_false(stage.ok, "a free row has no stage to read")
	assert_equal(stage.error, String(Residents.REFUSE_NOT_PRESENT),
		"occupancy is what distinguishes it, not the byte")
	assert_false(_residents.is_present(child.value), "and the row is free")


func test_a_dead_resident_keeps_the_stage_it_was_given() -> void:
	"""MOVE-DEP-R02: live AND dead occupied rows retain their stage until retirement."""
	var elder: Residents.OpResult = _residents.spawn_with_stage(&"otter", EXPECTED_ELDER)
	var needs_store: NeedsScript = _residents.needs()
	assert_true(needs_store.apply_health_event(elder.value, -NeedsScript.HEALTH_MAX).ok,
		"the elder's health reaches 0")
	assert_false(_residents.is_alive(elder.value), "and is no longer living")
	assert_true(_residents.is_present(elder.value), "but the row is still occupied")
	assert_equal(_residents.life_stage_of(elder.value).value, EXPECTED_ELDER,
		"a dead elder is still an elder")


func test_a_stale_reference_is_refused_rather_than_answered() -> void:
	"""MOVE-DEP-R02: "Generation-checked readers reject stale refs"."""
	var first: Residents.OpResult = _residents.spawn_with_stage(&"mouse", EXPECTED_CHILD)
	var stale: Vector2i = first.ref
	assert_true(_residents.despawn(stale).ok, "the child retires")
	var second: Residents.OpResult = _residents.spawn_with_stage(&"mouse", EXPECTED_ELDER)
	assert_equal(second.value, first.value, "the slot is reused")
	assert_true(second.ref != stale, "with a fresh generation")
	var by_stale: IntMath.IntResult = _residents.life_stage_of_ref(stale)
	assert_false(by_stale.ok, "the old reference is refused")
	assert_equal(by_stale.error, String(Residents.REFUSE_STALE_REF), "as a stale ref")
	assert_equal(by_stale.value, 0, "carrying no usable stage")
	assert_equal(_residents.life_stage_of_ref(second.ref).value, EXPECTED_ELDER,
		"while the live reference answers the elder")


func test_the_null_reference_is_not_a_resident() -> void:
	"""Null `(-1, 0)` must refuse like any other unusable reference."""
	var by_null: IntMath.IntResult = _residents.life_stage_of_ref(Residents.NULL_REF)
	assert_false(by_null.ok, "the null reference reads no stage")
	assert_equal(by_null.error, String(Residents.REFUSE_STALE_REF), "it is not valid of kind")


func test_a_reference_of_another_kind_is_refused() -> void:
	"""A directory ref with a matching slot number but a different kind is not a resident."""
	var building: Vector2i = _residents.directory().create(EntityDirectory.KIND_BUILDING)
	assert_true(building != Residents.NULL_REF, "a building slot was allocated")
	var read: IntMath.IntResult = _residents.life_stage_of_ref(building)
	assert_false(read.ok, "a building is not a resident")
	assert_equal(read.error, String(Residents.REFUSE_STALE_REF), "and is refused by kind")


func test_the_life_stage_column_costs_the_ruled_512_bytes() -> void:
	"""MOVE-DEP-R02 bills `Resident.life_stage:B8[512]` at exactly 512 new bytes."""
	assert_equal(_residents.life_stage_payload_bytes(), 512, "one byte per resident row")
	assert_equal(Residents.RESIDENT_CAPACITY, 512, "over the 512 typed rows")


func test_there_is_no_way_to_change_a_stage_after_creation() -> void:
	"""Release 1 has no birth, aging timer or adulthood transition, so it has no stage setter.

	DEC-032 via MOVE-DEP-R02. A setter would be the API surface for a rule that does not exist.
	"""
	assert_false(_residents.has_method("set_life_stage"), "no stage setter exists")
	assert_false(_residents.has_method("age_resident"), "and nothing ages a resident")


# --- MOVE-DEP-R03 logical rig identity ----------------------------------------------------------

## The manifest table, transcribed from `docs/planning/species_rig_identity.json`. Keyed by the
## §4.3 species key exactly as the ruling prints it.
const EXPECTED_RIG_OF: Dictionary = {
	&"badger": &"rig_badger_v1", &"ferret": &"rig_ferret_v1", &"fox": &"rig_fox_v1",
	&"hare": &"rig_hare_v1", &"hedgehog": &"rig_hedgehog_v1", &"kestrel": &"rig_kestrel_v1",
	&"mole": &"rig_mole_v1", &"mouse": &"rig_mouse_v1", &"otter": &"rig_otter_v1",
	&"rat": &"rig_rat_v1", &"shrew": &"rig_shrew_v1", &"sparrow": &"rig_sparrow_v1",
	&"squirrel": &"rig_squirrel_v1", &"weasel": &"rig_weasel_v1", &"wildcat": &"rig_wildcat_v1",
	&"wolverine": &"rig_wolverine_v1",
}


func test_all_sixteen_species_bind_the_ruled_rig_key() -> void:
	"""MOVE-DEP-R03's table, species by species, against the transcribed manifest."""
	assert_equal(_residents.rig_catalog_error(), "", "the rig domain compiled")
	assert_equal(_residents.rig_count(), 16, "sixteen logical rig identities")
	assert_equal(EXPECTED_RIG_OF.size(), 16, "and the fixture covers all sixteen")
	for species: StringName in SPECIES_ASCENDING:
		var bound: Residents.OpResult = _residents.rig_binding(species, EXPECTED_ADULT)
		assert_true(bound.ok, "%s binds a rig: %s" % [species, bound.error])
		assert_equal(_residents.rig_key_of(bound.value), EXPECTED_RIG_OF[species] as StringName,
			"%s binds its own rig key" % species)


func test_rig_ids_are_ascending_ascii_over_the_rig_keys() -> void:
	"""MOVE-DEP-R03: "Compile a RigDefinition key domain in ASCII order"."""
	var keys: Array[String] = []
	for species: StringName in EXPECTED_RIG_OF:
		keys.append(String(EXPECTED_RIG_OF[species] as StringName))
	keys.sort()
	for index: int in keys.size():
		var key: StringName = StringName(keys[index])
		assert_true(_residents.has_rig(key), "%s is a compiled rig identity" % key)
		assert_equal(_residents.rig_id(key).value, index, "%s compiles to id %d" % [key, index])
		assert_equal(_residents.rig_key_of(index), key, "id %d reads back as %s" % [index, key])
	assert_equal(keys[0], "rig_badger_v1", "badger sorts first among the rig keys")
	assert_equal(keys[15], "rig_wolverine_v1", "and wolverine sorts last")


func test_no_species_shares_another_species_rig() -> void:
	"""MOVE-DEP-R03 refuses aliasing: sixteen species, sixteen distinct identities."""
	var seen: Dictionary = {}
	for species: StringName in SPECIES_ASCENDING:
		var bound: Residents.OpResult = _residents.rig_binding(species, EXPECTED_ADULT)
		assert_false(seen.has(bound.value), "%s does not reuse another species' rig" % species)
		seen[bound.value] = species
	assert_equal(seen.size(), 16, "sixteen distinct rig ids")


func test_an_unknown_rig_key_refuses_rather_than_resolving() -> void:
	"""Neither a made-up key nor an out-of-range id may produce a plausible identity."""
	assert_false(_residents.has_rig(&"rig_dragon_v1"), "no dragon rig exists")
	var refused: IntMath.IntResult = _residents.rig_id(&"rig_dragon_v1")
	assert_false(refused.ok, "an unknown rig key is refused")
	assert_equal(refused.error, String(Residents.REFUSE_UNKNOWN_RIG), "by name")
	assert_equal(refused.value, 0, "carrying no usable id")
	assert_equal(_residents.rig_key_of(16), &"", "id 16 is past the domain")
	assert_equal(_residents.rig_key_of(-1), &"", "and -1 is not an id")


func test_child_and_elder_rig_variants_refuse_instead_of_inheriting_the_adult_rig() -> void:
	"""MOVE-DEP-R03: a stage override "cannot silently inherit adult proportions".

	No `(species, life_stage)` variant is authored anywhere in this repository, so the binding
	is refused and the adult rig is NOT handed back in its place.
	"""
	for stage: int in [EXPECTED_CHILD, EXPECTED_ELDER]:
		var bound: Residents.OpResult = _residents.rig_binding(&"mouse", stage)
		assert_false(bound.ok, "stage %d has no authored mouse rig variant" % stage)
		assert_equal(bound.error, Residents.REFUSE_RIG_STAGE_UNBOUND, "and says exactly why")
		assert_equal(bound.value, 0, "a refusal never carries the adult rig id")
		assert_false(_residents.has_rig_binding(&"mouse", stage), "and reports no binding")
	assert_true(_residents.has_rig_binding(&"mouse", EXPECTED_ADULT), "the adult rig is bound")


func test_a_missing_rig_does_not_deny_a_legal_resident() -> void:
	"""The executor follow-up: "a missing rig is a presentation/export gap, not authority to
	deny legal simulation"."""
	assert_false(_residents.has_rig_binding(&"otter", EXPECTED_CHILD), "no child otter rig")
	var spawned: Residents.OpResult = _residents.spawn_with_stage(&"otter", EXPECTED_CHILD)
	assert_true(spawned.ok, "the child otter spawns anyway: %s" % spawned.error)
	assert_equal(_residents.life_stage_of(spawned.value).value, EXPECTED_CHILD,
		"and is authoritative state")
	assert_equal(_residents.living_count(), 1, "counted among the living")
	assert_true(_residents.daily_demand_np().ok, "and it feeds into the §5.8 denominator")


func test_rig_binding_refuses_an_unknown_species_and_an_invalid_stage_separately() -> void:
	"""Two different causes must not collapse into one code."""
	var unknown: Residents.OpResult = _residents.rig_binding(&"dragon", EXPECTED_ADULT)
	assert_false(unknown.ok, "dragon has no rig")
	assert_equal(unknown.error, Residents.REFUSE_UNKNOWN_SPECIES, "because it is not a species")
	var bad_stage: Residents.OpResult = _residents.rig_binding(&"mouse", EXPECTED_STAGE_COUNT)
	assert_false(bad_stage.ok, "COUNT is not a stage")
	assert_equal(bad_stage.error, Residents.REFUSE_INVALID_LIFE_STAGE, "and says so")


func test_binding_by_species_id_agrees_with_binding_by_key() -> void:
	"""The id form resolves back through the species key, so the two cannot diverge."""
	for index: int in SPECIES_ASCENDING.size():
		var species: StringName = SPECIES_ASCENDING[index]
		var by_key: Residents.OpResult = _residents.rig_binding(species, EXPECTED_ADULT)
		var by_id: Residents.OpResult = _residents.rig_binding_by_species_id(index, EXPECTED_ADULT)
		assert_true(by_id.ok, "species id %d binds a rig" % index)
		assert_equal(by_id.value, by_key.value, "%s agrees through both forms" % species)
	var past: Residents.OpResult = _residents.rig_binding_by_species_id(16, EXPECTED_ADULT)
	assert_false(past.ok, "species id 16 is past the catalog")
	assert_equal(past.error, Residents.REFUSE_UNKNOWN_SPECIES, "and is refused by name")


func test_no_per_resident_rig_column_exists() -> void:
	"""MOVE-DEP-R03: "No per-resident mutable rig column is needed"; a rig is a species fact."""
	assert_false(_residents.has_method("set_rig"), "nothing binds a rig to an individual")
	assert_false(_residents.has_method("rig_of"), "and no row-addressed rig reader exists")


# --- MOVE-DEP-R05 generation-safe identity, the part this store owns -----------------------------

func test_a_reference_resolves_to_its_row_only_while_it_is_valid() -> void:
	"""The directory generation is what makes a resident reference safe to consume."""
	var spawned: Residents.OpResult = _residents.spawn(&"mouse")
	var resolved: IntMath.IntResult = _residents.slot_of_ref(spawned.ref)
	assert_true(resolved.ok, "a live reference resolves")
	assert_equal(resolved.value, spawned.value, "to its own typed row")
	assert_true(_residents.despawn(spawned.ref).ok, "the resident retires")
	var after: IntMath.IntResult = _residents.slot_of_ref(spawned.ref)
	assert_false(after.ok, "the reference no longer resolves")
	assert_equal(after.error, String(Residents.REFUSE_STALE_REF), "and names the reason")


func test_row_zero_is_never_mistaken_for_a_refusal() -> void:
	"""A resolved slot 0 and a refusal must be distinguishable; this is the sentinel rule."""
	var spawned: Residents.OpResult = _residents.spawn(&"mouse")
	assert_equal(spawned.value, 0, "the first resident takes typed row 0")
	var resolved: IntMath.IntResult = _residents.slot_of_ref(spawned.ref)
	assert_true(resolved.ok, "and row 0 resolves successfully")
	assert_equal(resolved.value, 0, "with the value 0 on the success channel")
	assert_equal(_residents.slot_of_ref(Residents.NULL_REF).value, 0,
		"a refusal also carries 0, which is why `ok` is the channel that decides")
	assert_false(_residents.slot_of_ref(Residents.NULL_REF).ok, "and it is false here")


func test_a_malformed_home_or_bed_reference_is_refused_not_stored() -> void:
	"""MOVE-DEP-R05 makes the owner ref half of a destination's identity; `(5, 0)` is neither
	null nor validatable, so storing it would create an unrecognisable destination."""
	var slot: int = _residents.spawn(&"mouse").value
	var malformed: Array[Vector2i] = [Vector2i(5, 0), Vector2i(-1, 3), Vector2i(-2, 1)]
	for bad: Vector2i in malformed:
		var home: Residents.OpResult = _residents.set_home(slot, bad)
		assert_false(home.ok, "home %s is refused" % bad)
		assert_equal(home.error, Residents.REFUSE_INVALID_REF, "by name")
		var bed: Residents.OpResult = _residents.set_bed(slot, bad)
		assert_false(bed.ok, "bed %s is refused" % bad)
		assert_equal(bed.error, Residents.REFUSE_INVALID_REF, "by name")
	assert_equal(_residents.home_of(slot), Residents.NULL_REF, "home stayed null")
	assert_equal(_residents.bed_of(slot), Residents.NULL_REF, "and so did bed")


func test_the_null_reference_still_clears_a_home_or_bed() -> void:
	"""Clearing is a legal operation and must not be caught by the malformed-ref check."""
	var slot: int = _residents.spawn(&"mouse").value
	assert_true(_residents.set_home(slot, Residents.NULL_REF).ok, "null home is accepted")
	assert_true(_residents.set_bed(slot, Residents.NULL_REF).ok, "null bed is accepted")
	assert_false(_residents.home_is_live(slot), "a null home is not a live destination")
	assert_false(_residents.bed_is_live(slot), "nor is a null bed")


func test_a_stored_destination_stops_being_live_when_its_owner_retires() -> void:
	"""MOVE-DEP-R05: owner retirement invalidates the generation-checked identity."""
	var slot: int = _residents.spawn(&"mouse").value
	var directory: EntityDirectory = _residents.directory()
	var furniture: Vector2i = directory.create(EntityDirectory.KIND_FURNITURE)
	assert_true(furniture != Residents.NULL_REF, "a bed owner was allocated")
	assert_true(_residents.set_bed(slot, furniture).ok, "the bed reference is stored")
	assert_true(_residents.bed_is_live(slot), "and validates while its owner lives")
	assert_true(directory.destroy(furniture), "the furniture is removed")
	assert_false(_residents.bed_is_live(slot), "the stored reference is no longer live")
	assert_equal(_residents.bed_of(slot), furniture,
		"though the pair itself is unchanged: liveness is asked, never inferred from the bytes")


func test_a_replacement_owner_does_not_inherit_the_stored_reference() -> void:
	"""A new owner in the same slot is a new identity, not permission to reuse the old one."""
	var slot: int = _residents.spawn(&"mouse").value
	var directory: EntityDirectory = _residents.directory()
	var first: Vector2i = directory.create(EntityDirectory.KIND_FURNITURE)
	assert_true(_residents.set_bed(slot, first).ok, "the first bed is stored")
	assert_true(directory.destroy(first), "it is demolished")
	var replacement: Vector2i = directory.create(EntityDirectory.KIND_FURNITURE)
	assert_equal(replacement.x, first.x, "the replacement takes the same slot")
	assert_true(replacement.y != first.y, "with a different generation")
	assert_false(_residents.bed_is_live(slot),
		"so the resident's stored bed does not silently become the replacement")


func test_a_retired_row_leaves_a_canonical_zero_byte_behind() -> void:
	"""MOVE-DEP-R02: unused rows hold 0. A retired elder that left a 2 would be a nonzero byte
	in a future section-4 hash that no occupancy-checked reader could ever see."""
	var elder: Residents.OpResult = _residents.spawn_with_stage(&"badger", EXPECTED_ELDER)
	var image_live: PackedByteArray = _residents.life_stage_column_image()
	assert_equal(image_live.size(), 512, "the image covers every typed row")
	assert_equal(image_live[elder.value], EXPECTED_ELDER, "the live row holds ELDER")
	assert_true(_residents.despawn(elder.ref).ok, "the elder retires")
	var image_free: PackedByteArray = _residents.life_stage_column_image()
	assert_equal(image_free[elder.value], EXPECTED_ADULT, "and the free row is back to 0")
	for index: int in image_free.size():
		assert_equal(image_free[index], 0, "row %d is canonical zero" % index)
