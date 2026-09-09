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
